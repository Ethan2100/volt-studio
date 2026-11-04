// =====================================================================
// POLYGLOT - server/tutor-server.volt
// The AI tutor's backend. A browser cannot hold an API key safely, so the
// app talks to THIS small Node server, which holds the key and forwards
// each request to the model.
//
// Run:    ANTHROPIC_API_KEY=sk-... node compiler/volt.js projects/polyglot/server/tutor-server.volt
// Deploy: any Node host (for example Render). Set the environment variables
//         below, then paste the server's URL + /api/tutor into Polyglot's
//         Settings -> AI tutor.
//
// Environment variables
//   ANTHROPIC_API_KEY  (required) your Anthropic API key
//   TUTOR_MODEL        model name (default claude-sonnet-5-5)
//   PORT               port to listen on (default 8787)
//   ALLOWED_ORIGIN     the site allowed to call this server (default * = any)
//   TUTOR_UPSTREAM     model endpoint (default https://api.anthropic.com/v1/messages)
//
// Safety: requests are size-limited, validated, and rate-limited per client
// (30 per minute). Nothing is stored or logged.
// =====================================================================
#js

let apiKey = envVar("ANTHROPIC_API_KEY")
let model = envVar("TUTOR_MODEL")
let upstream = envVar("TUTOR_UPSTREAM")
let origin = envVar("ALLOWED_ORIGIN")
let port = number(envVar("PORT"))
if model == "" {
  model = "claude-sonnet-5-5"
}
if upstream == "" {
  upstream = "https://api.anthropic.com/v1/messages"
}
if origin == "" {
  origin = "*"
}
if port <= 0 {
  port = 8787
}

# globalThis.__hits = new Map();

// True if this client may make another request (30 per rolling minute).
fn allowed(client) {
  # const now = Date.now(); const list = (__hits.get(client) || []).filter((t) => now - t < 60000); if (list.length >= 30) { __hits.set(client, list); return false; } list.push(now); __hits.set(client, list); return true;
}

// Sends the conversation to the model. Returns { reply } or { error }.
fn askModel(system, messages) {
  # try { const r = await fetch(upstream, { method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' }, body: JSON.stringify({ model: model, max_tokens: 600, system: system, messages: messages }) }); const j = await r.json().catch(() => ({})); if (!r.ok) { return { error: (j.error && j.error.message) || ('The model returned status ' + r.status + '.') }; } return { reply: (j.content || []).map((c) => c.text || '').join('') }; } catch (e) { return { error: 'The server could not reach the model.' }; }
}

// Checks the request body. Returns an error message or "" if it is fine.
fn checkRequest(body) {
  # if (!body || typeof body.system !== 'string' || body.system.length > 4000) { return 'Missing or oversized system prompt.'; }
  # if (!Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > 12) { return 'Send between 1 and 12 messages.'; }
  # for (const m of body.messages) { if (!m || (m.role !== 'user' && m.role !== 'assistant') || typeof m.content !== 'string' || m.content.length < 1 || m.content.length > 2000) { return 'Each message needs a role and 1 to 2000 characters of content.'; } }
  # if (body.messages[body.messages.length - 1].role !== 'user') { return 'The last message must be from the user.'; }
  # return '';
}

// Handles one HTTP request: validates, rate-limits, asks the model, replies.
fn handle(req, res, raw) {
  # const send = (code, obj) => { res.writeHead(code, { 'content-type': 'application/json', 'access-control-allow-origin': origin, 'access-control-allow-headers': 'content-type', 'access-control-allow-methods': 'POST, GET, OPTIONS' }); res.end(JSON.stringify(obj)); };
  # if (req.method === 'OPTIONS') { return send(204, {}); }
  # if (req.method === 'GET' && req.url === '/health') { return send(200, { ok: true, configured: apiKey !== '' }); }
  # if (req.method !== 'POST' || req.url !== '/api/tutor') { return send(404, { error: 'Not found.' }); }
  # if (apiKey === '') { return send(503, { error: 'The tutor server has no ANTHROPIC_API_KEY set.' }); }
  # const client = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown').split(',')[0].trim();
  # if (!(await allowed(client))) { return send(429, { error: 'Too many requests. Wait a minute and try again.' }); }
  # let body; try { body = JSON.parse(raw); } catch (e) { return send(400, { error: 'The request was not valid JSON.' }); }
  # const problem = await checkRequest(body);
  # if (problem) { return send(400, { error: problem }); }
  # const out = await askModel(body.system, body.messages);
  # return out.error ? send(502, out) : send(200, out);
}

# require('http').createServer((req, res) => { let raw = ''; let tooBig = false; req.on('data', (c) => { raw += c; if (raw.length > 40000) { tooBig = true; req.destroy(); } }); req.on('end', () => { if (!tooBig) { handle(req, res, raw).catch(() => { res.writeHead(500); res.end('{"error":"Server error."}'); }); } }); }).listen(port, () => console.log('Polyglot tutor server listening on port ' + port));
