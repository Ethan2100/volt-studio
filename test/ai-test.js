// Checks the AI backend: that a question is turned into a real Gemini
// request, and that every way the API can answer turns into something
// readable instead of an exception.
//   Run with: node test/ai-test.js
const https = require('https');
const { EventEmitter } = require('events');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

// Stand in for one HTTPS round trip: remember what was sent, reply with
// whatever the test asks for.
let sent = null;
const realRequest = https.request;
function fakeApi(status, payload) {
  https.request = (opts, cb) => {
    const req = new EventEmitter();
    req.write = (body) => { sent = { opts, body: JSON.parse(body) }; };
    req.end = () => {
      const res = new EventEmitter();
      res.statusCode = status;
      cb(res);
      process.nextTick(() => {
        res.emit('data', typeof payload === 'string' ? payload : JSON.stringify(payload));
        res.emit('end');
      });
    };
    return req;
  };
}
const ai = require('../lib/ai.js');
const ask = (over = {}) => ai.askGemini(Object.assign({
  apiKey: 'AIza-test-key', systemPrompt: 'be helpful', messages: [{ role: 'user', content: 'hi' }],
}, over));
const reply = (text) => ({ candidates: [{ content: { parts: [{ text }] } }] });

(async () => {
  // ---- the request ----
  fakeApi(200, reply('ok'));
  await ask({ messages: [{ role: 'user', content: 'one' }, { role: 'assistant', content: 'two' }, { role: 'user', content: 'three' }] });
  check('it calls Google, not anyone else', sent.opts.hostname === 'generativelanguage.googleapis.com', sent.opts.hostname);
  check('it posts to generateContent for the default model',
    sent.opts.method === 'POST' && sent.opts.path === `/v1beta/models/${ai.DEFAULT_MODEL}:generateContent`, sent.opts.path);
  check('the key travels in the header, never in the URL',
    sent.opts.headers['x-goog-api-key'] === 'AIza-test-key' && !sent.opts.path.includes('AIza'), sent.opts.path);
  check('the system prompt goes in its own field', sent.body.system_instruction.parts[0].text === 'be helpful');
  check("the assistant's turns are relabelled as Gemini's \"model\"",
    sent.body.contents.map((c) => c.role).join(',') === 'user,model,user', sent.body.contents.map((c) => c.role).join(','));
  check('the turns keep their text and their order',
    sent.body.contents.map((c) => c.parts[0].text).join(',') === 'one,two,three');

  fakeApi(200, reply('ok'));
  await ask({ model: 'gemini-3.6-flash' });
  check('a model from Settings is used instead of the default', sent.opts.path.includes('gemini-3.6-flash'), sent.opts.path);

  // ---- the answers ----
  fakeApi(200, reply('here is some Volt'));
  check('a normal answer comes back as text', (await ask()) === 'here is some Volt');

  fakeApi(200, { candidates: [{ content: { parts: [{ text: 'secret reasoning', thought: true }, { text: 'the answer' }] } }] });
  check("the model's private thinking is left out", (await ask()) === 'the answer');

  fakeApi(200, { candidates: [{ content: { parts: [{ text: 'part one. ' }, { text: 'part two.' }] } }] });
  check('an answer split over several parts is joined up', (await ask()) === 'part one. part two.');

  // ---- the failures ----
  const fails = async (what, setup, wants) => {
    setup();
    try { await ask(); check(what, false, 'it succeeded instead'); }
    catch (e) { check(what, wants.test(e.message), e.message); }
  };
  https.request = () => { throw new Error('the network should not be touched without a key'); };
  try {
    await ai.askGemini({ apiKey: '', systemPrompt: 's', messages: [{ role: 'user', content: 'hi' }] });
    check('a missing key is explained without calling anyone', false, 'it succeeded instead');
  } catch (e) {
    check('a missing key is explained without calling anyone', /No Gemini API key/.test(e.message), e.message);
  }

  await fails('an API error shows what Google said', () => fakeApi(400, { error: { message: 'API key not valid' } }), /API key not valid/);
  await fails('an unknown model points at the setting', () => fakeApi(404, { error: { message: 'model not found' } }), /Settings .* AI|default is gemini/);
  await fails('a non-JSON reply says so with the status', () => fakeApi(502, '<html>bad gateway</html>'), /wasn't JSON \(status 502\)/);
  await fails('a blocked prompt says it was blocked', () => fakeApi(200, { promptFeedback: { blockReason: 'SAFETY' } }), /refused the prompt \(SAFETY\)/);
  await fails('an answer with no candidates is explained', () => fakeApi(200, {}), /no answer at all/);
  await fails('running out of room is explained', () => fakeApi(200, { candidates: [{ content: { parts: [] }, finishReason: 'MAX_TOKENS' }] }), /ran out of room/);
  await fails('an empty answer is explained', () => fakeApi(200, { candidates: [{ content: { parts: [] }, finishReason: 'OTHER' }] }), /empty answer \(OTHER\)/);

  // ---- the timeout is on the clock, not on socket chatter ----
  https.request = (opts, cb) => {   // a connection that never answers
    const req = new EventEmitter();
    req.write = () => {}; req.end = () => {};
    if (opts.signal) opts.signal.addEventListener('abort', () => { const e = new Error('aborted'); e.name = 'AbortError'; req.emit('error', e); });
    return req;
  };
  const started = Date.now();
  try { await ask({ timeoutMs: 120 }); check('a silent connection gives up on its own', false, 'it resolved'); }
  catch (e) { check('a silent connection gives up on its own', /didn't respond within/.test(e.message) && Date.now() - started < 3000, e.message); }

  // ---- the system prompt still carries the real reference ----
  const prompt = ai.buildSystemPrompt('## Volt reference\nblock3d(x, y, z, w, h, d, "#colour")');
  check('the system prompt embeds the real reference', prompt.includes('block3d(x, y, z, w, h, d'));
  check('it tells the model not to invent syntax', /[Nn]ever invent/.test(prompt));

  // ---- several keys ----
  check('a list of keys is split on commas, spaces and newlines',
    ai.parseKeys('AIza-1, AIza-2\nAIza-3 AIza-4;AIza-5').join('|') === 'AIza-1|AIza-2|AIza-3|AIza-4|AIza-5',
    ai.parseKeys('AIza-1, AIza-2\nAIza-3 AIza-4;AIza-5').join('|'));
  check('blanks and repeats are dropped', ai.parseKeys('a,,b, a ,b').join('|') === 'a|b', ai.parseKeys('a,,b, a ,b').join('|'));
  check('an array of keys is accepted too', ai.parseKeys(['a', 'b']).join('|') === 'a|b');

  // a fake API where each key behaves differently
  let seen = [];
  function fakeKeyed(behaviour) {
    seen = [];
    https.request = (opts, cb) => {
      const key = opts.headers['x-goog-api-key'];
      seen.push(key);
      const req = new EventEmitter();
      req.write = () => {}; 
      req.end = () => {
        const out = behaviour(key);
        const res = new EventEmitter();
        res.statusCode = out.status;
        cb(res);
        process.nextTick(() => { res.emit('data', JSON.stringify(out.body)); res.emit('end'); });
      };
      return req;
    };
  }
  const outOfQuota = { status: 429, body: { error: { message: 'Quota exceeded for this key' } } };

  fakeKeyed((k) => (k === 'k1' ? outOfQuota : { status: 200, body: reply('from k2') }));
  check('a key that is out of quota falls through to the next one',
    (await ask({ apiKeys: 'k1,k2' })) === 'from k2' && seen.join(',') === 'k1,k2', seen.join(','));

  fakeKeyed((k) => (k === 'k3' ? { status: 200, body: reply('from k3') } : outOfQuota));
  check('it keeps going past several dead keys',
    (await ask({ apiKeys: 'k1,k2,k3' })) === 'from k3' && seen.join(',') === 'k1,k2,k3', seen.join(','));

  let landedOn = -1;
  fakeKeyed((k) => (k === 'k1' ? outOfQuota : { status: 200, body: reply('ok') }));
  await ask({ apiKeys: 'k1,k2,k3', onKeyUsed: (i) => { landedOn = i; } });
  check('it reports which key answered, so the next question starts there', landedOn === 1, String(landedOn));

  fakeKeyed(() => ({ status: 200, body: reply('ok') }));
  await ask({ apiKeys: 'k1,k2,k3', startAt: 2 });
  check('starting part-way along does not retry the dead ones', seen.join(',') === 'k3', seen.join(','));

  fakeKeyed((k) => (k === 'k1' ? { status: 200, body: reply('ok') } : outOfQuota));
  await ask({ apiKeys: 'k1,k2,k3', startAt: 2 });
  check('it wraps round to the start of the list', seen.join(',') === 'k3,k1', seen.join(','));

  fakeKeyed(() => ({ status: 404, body: { error: { message: 'model gemini-9 not found' } } }));
  await (async () => {
    try { await ask({ apiKeys: 'k1,k2,k3' }); check('a bad model name does not burn through every key', false, 'it succeeded'); }
    catch (e) { check('a bad model name does not burn through every key', seen.length === 1, `tried ${seen.length}`); }
  })();

  fakeKeyed(() => outOfQuota);
  try {
    await ask({ apiKeys: 'k1,k2' });
    check('when every key is spent it says so', false, 'it succeeded');
  } catch (e) {
    check('when every key is spent it says so', /All 2 Gemini keys were refused or out of quota/.test(e.message), e.message);
  }

  fakeKeyed(() => ({ status: 400, body: { error: { message: 'API key not valid: supersecretkey123' } } }));
  try {
    await ai.askGemini({ apiKeys: 'supersecretkey123,other', systemPrompt: 's', messages: [{ role: 'user', content: 'hi' }] });
    check('a key is never repeated back in an error', false, 'it succeeded');
  } catch (e) {
    check('a key is never repeated back in an error', !e.message.includes('supersecretkey123'), e.message);
  }

  https.request = realRequest;
  process.exitCode = failed ? 1 : 0;
})();
