// =====================================================================
//  The Volt AI chat's backend: a real call to the Google Gemini API, made
//  from the main process (not the renderer) so the API key never has to
//  touch the sandboxed, contextIsolated web page - consistent with how
//  everything else sensitive in this app (uploading, the serial port)
//  stays in main.js and talks to the page only over IPC.
// =====================================================================

const https = require('https');

// Google's current general-purpose Flash model. Override it in
// Settings -> AI, or with the GEMINI_MODEL environment variable.
const DEFAULT_MODEL = 'gemini-3.8-flash';

// Several keys can be given at once - separated by commas, semicolons,
// newlines or just spaces - so a key that has hit its limit for the day
// doesn't stop the AI tab. Order is kept, blanks and repeats are dropped.
function parseKeys(value) {
  if (Array.isArray(value)) value = value.join(',');
  const seen = new Set();
  return String(value || '')
    .split(/[\s,;]+/)
    .map((k) => k.trim())
    .filter((k) => k && !seen.has(k) && seen.add(k));
}

// Would a different key do any better? Only for problems that belong to
// the key itself - a quota, a bad key, a key without access. A model name
// typo or a server fault follows us to every key, so we stop on those
// instead of burning through the whole list to show the same message.
function worthAnotherKey(status, message) {
  if (status === 429 || status === 401 || status === 403) return true;
  if (status === 400 && /api[ _-]?key|credential|expired/i.test(message || '')) return true;
  return false;
}

// Never let a key reach a log, a toast or an error message.
const hideKeys = (text, keys) => keys.reduce((t, k) => (k ? t.split(k).join('\u2026') : t), String(text || ''));

// Builds the system prompt that keeps the assistant grounded in the REAL
// Volt reference instead of guessing at syntax from general programming
// knowledge (Volt is a small, unusual language - a generic LLM left to
// its own devices will confidently invent plausible-looking syntax that
// doesn't exist). referenceMd is docs/REFERENCE.md's actual current
// content, so this never drifts out of sync with the real compiler.
function buildSystemPrompt(referenceMd) {
  return [
    'You are the Volt assistant, built into Volt Studio (a desktop editor for the Volt programming language).',
    '',
    "Volt is a small language that compiles to other languages (Arduino C++, MicroPython, Python, Ruby, JavaScript, or an HTML page), chosen by the file's first line. It is NOT any of those languages itself, and most general programming knowledge about syntax does not carry over - only what is documented below is real Volt syntax.",
    '',
    'Hard rules:',
    '- Only use syntax, keywords and built-in functions that appear in the reference below. Never invent a construct because it would be convenient or because another language has it.',
    "- If something the person wants isn't expressible in plain Volt syntax, say so plainly, and if it's the kind of thing raw-code escapes are for (see the \"Raw code\" section below), offer that instead of pretending there's a clean built-in way.",
    '- If unsure whether a specific construct is valid Volt, say so rather than guessing - a wrong answer here means code that fails to compile.',
    '- Keep answers focused and practical: working Volt code first, explanation after, not before.',
    '',
    '=== BEGIN docs/REFERENCE.md (the complete, authoritative Volt reference) ===',
    referenceMd,
    '=== END docs/REFERENCE.md ===',
  ].join('\n');
}

// messages: [{ role: 'user'|'assistant', content: string }]
// Returns a Promise<string> (the assistant's reply text).
//
// timeoutMs is a HARD cap on the whole request, enforced with an
// AbortController rather than the request's socket-inactivity `timeout`
// option. The inactivity option only fires when the socket goes quiet
// after something has already started happening on it - it does nothing
// for a connection that never truly completes or that a flaky network,
// proxy or firewall keeps "alive" without ever delivering a response, so
// a request stuck that way could otherwise hang indefinitely with the
// "Thinking…" indicator never clearing. The abort-based timer fires on
// the clock alone, independent of what the socket is doing, so the
// request always resolves or fails within timeoutMs no matter what.
function askOnce({ apiKey, model, systemPrompt, messages, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const name = model || DEFAULT_MODEL;
    // Gemini calls the assistant's turns "model", not "assistant", and takes
    // the system prompt in a field of its own rather than as a message.
    const body = JSON.stringify({
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: messages.map((m) => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content }],
      })),
      generationConfig: { maxOutputTokens: 1536 },
    });

    const controller = new AbortController();
    const hardTimer = setTimeout(() => controller.abort(), timeoutMs);

    const req = https.request(
      {
        hostname: 'generativelanguage.googleapis.com',
        // the key goes in a header, never in the URL - a query string ends up
        // in proxy logs and crash reports
        path: `/v1beta/models/${encodeURIComponent(name)}:generateContent`,
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': apiKey,
          'content-length': Buffer.byteLength(body),
        },
        signal: controller.signal,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          clearTimeout(hardTimer);
          let json;
          try {
            json = JSON.parse(data);
          } catch {
            return reject(new Error(`Gemini sent back something that wasn't JSON (status ${res.statusCode}): ${data.slice(0, 200)}`));
          }
          if (res.statusCode !== 200) {
            let msg = (json.error && json.error.message) || `Gemini API error (status ${res.statusCode})`;
            if (res.statusCode === 404 && /model/i.test(msg)) {
              msg += ` - check the model name in Settings \u2192 AI (the default is ${DEFAULT_MODEL}).`;
            }
            const err = new Error(msg);
            err.status = res.statusCode;
            return reject(err);
          }
          // A request can come back 200 with nothing in it: the prompt was
          // blocked, or the answer was cut off before any text was produced.
          const blocked = json.promptFeedback && json.promptFeedback.blockReason;
          if (blocked) return reject(new Error(`Gemini refused the prompt (${blocked}).`));
          const candidate = (json.candidates || [])[0];
          if (!candidate) return reject(new Error('Gemini returned no answer at all. Try asking again.'));
          const text = (((candidate.content || {}).parts) || [])
            .filter((part) => typeof part.text === 'string' && !part.thought)   // skip the model's private thinking
            .map((part) => part.text)
            .join('');
          if (!text) {
            const why = candidate.finishReason;
            if (why === 'MAX_TOKENS') return reject(new Error('Gemini ran out of room before writing an answer. Ask for something smaller.'));
            return reject(new Error(`Gemini returned an empty answer${why ? ` (${why})` : ''}. Try asking again.`));
          }
          resolve(text);
        });
      },
    );
    req.on('error', (e) => {
      clearTimeout(hardTimer);
      if (e.name === 'AbortError' || controller.signal.aborted) {
        reject(new Error(`The Gemini API didn't respond within ${Math.round(timeoutMs / 1000)}s. Check your internet connection (or a firewall/proxy blocking generativelanguage.googleapis.com) and try again.`));
      } else {
        reject(new Error(`Could not reach the Gemini API: ${e.message}`));
      }
    });
    req.write(body);
    req.end();
  });
}


// Asks Gemini, moving on to the next key when the one being used is out of
// quota or isn't accepted. startAt is where to begin - the caller keeps the
// index of whichever key last worked, so a dead first key isn't retried on
// every single message. onKeyUsed(index) reports which key answered.
function askGemini({ apiKey, apiKeys, model, systemPrompt, messages, timeoutMs = 25000, startAt = 0, onKeyUsed }) {
  const keys = parseKeys(apiKeys != null ? apiKeys : apiKey);
  if (!keys.length) return Promise.reject(new Error('No Gemini API key set. Add one in Settings \u2192 AI.'));

  // start at the key that last worked, then wrap round through the rest
  const begin = (((Number(startAt) || 0) % keys.length) + keys.length) % keys.length;
  const order = keys.slice(begin).concat(keys.slice(0, begin));

  return (async () => {
    let last = null, tried = 0;
    for (let n = 0; n < order.length; n++) {
      tried++;
      try {
        const text = await askOnce({ apiKey: order[n], model, systemPrompt, messages, timeoutMs });
        if (typeof onKeyUsed === 'function') onKeyUsed(keys.indexOf(order[n]));
        return text;
      } catch (e) {
        last = e;
        // stop early on anything a different key would hit too
        if (n === order.length - 1 || !worthAnotherKey(e.status, e.message)) break;
      }
    }
    const why = hideKeys(last ? last.message : 'unknown error', keys);
    if (tried === keys.length && keys.length > 1 && worthAnotherKey(last && last.status, last && last.message)) {
      throw new Error(`All ${keys.length} Gemini keys were refused or out of quota. The last one said: ${why}`);
    }
    throw new Error(tried > 1 ? `Tried ${tried} of ${keys.length} Gemini keys. ${why}` : why);
  })();
}

module.exports = { buildSystemPrompt, askGemini, parseKeys, DEFAULT_MODEL };
