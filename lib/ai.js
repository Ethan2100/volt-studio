// =====================================================================
//  The Volt AI chat's backend: a real call to the Anthropic API, made
//  from the main process (not the renderer) so the API key never has to
//  touch the sandboxed, contextIsolated web page - consistent with how
//  everything else sensitive in this app (uploading, the serial port)
//  stays in main.js and talks to the page only over IPC.
// =====================================================================

const https = require('https');

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
function askClaude({ apiKey, model, systemPrompt, messages, timeoutMs = 25000 }) {
  return new Promise((resolve, reject) => {
    if (!apiKey) return reject(new Error('No Anthropic API key set. Add one in Settings → AI.'));
    const body = JSON.stringify({
      model: model || 'claude-sonnet-5',
      max_tokens: 1536,
      system: systemPrompt,
      messages,
    });

    const controller = new AbortController();
    const hardTimer = setTimeout(() => controller.abort(), timeoutMs);

    const req = https.request(
      {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
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
            return reject(new Error(`Anthropic sent back something that wasn't JSON (status ${res.statusCode}): ${data.slice(0, 200)}`));
          }
          if (res.statusCode !== 200) {
            const msg = (json.error && json.error.message) || `Anthropic API error (status ${res.statusCode})`;
            return reject(new Error(msg));
          }
          const text = (json.content || [])
            .filter((block) => block.type === 'text')
            .map((block) => block.text)
            .join('');
          resolve(text);
        });
      },
    );
    req.on('error', (e) => {
      clearTimeout(hardTimer);
      if (e.name === 'AbortError' || controller.signal.aborted) {
        reject(new Error(`The Anthropic API didn't respond within ${Math.round(timeoutMs / 1000)}s. Check your internet connection (or a firewall/proxy blocking api.anthropic.com) and try again.`));
      } else {
        reject(new Error(`Could not reach the Anthropic API: ${e.message}`));
      }
    });
    req.write(body);
    req.end();
  });
}

module.exports = { buildSystemPrompt, askClaude };
