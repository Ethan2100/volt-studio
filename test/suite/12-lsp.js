// The language server, driven the way a real editor drives it: LSP messages over stdin/stdout.
const path = require('path');
const { spawn } = require('child_process');

function client(root) {
  const proc = spawn(process.execPath, [path.join(root, 'lsp', 'server.js'), '--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
  let buffer = Buffer.alloc(0);
  const waiting = new Map();          // id -> resolve
  const notes = [];                   // messages the server sent us unasked, like diagnostics
  const noteWaiters = [];
  proc.stdout.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    for (;;) {
      const split = buffer.indexOf('\r\n\r\n');
      if (split < 0) return;
      const length = Number(/Content-Length:\s*(\d+)/i.exec(buffer.slice(0, split).toString())[1]);
      if (buffer.length < split + 4 + length) return;
      const message = JSON.parse(buffer.slice(split + 4, split + 4 + length).toString('utf8'));
      buffer = buffer.slice(split + 4 + length);
      if (message.id !== undefined && waiting.has(message.id)) { waiting.get(message.id)(message.result); waiting.delete(message.id); }
      else if (message.method) { notes.push(message); noteWaiters.splice(0).forEach((f) => f()); }
    }
  });
  let next = 1;
  const write = (m) => proc.stdin.write(`Content-Length: ${Buffer.byteLength(JSON.stringify(m))}\r\n\r\n${JSON.stringify(m)}`);
  return {
    proc,
    notes,
    ask(method, params) {
      const id = next++;
      return new Promise((done) => { waiting.set(id, done); write({ jsonrpc: '2.0', id, method, params }); });
    },
    tell(method, params) { write({ jsonrpc: '2.0', method, params }); },
    // waits for the next diagnostics message about a file
    diagnostics(uri) {
      const found = () => notes.filter((n) => n.method === 'textDocument/publishDiagnostics' && n.params.uri === uri).pop();
      return new Promise((done, fail) => {
        const timer = setTimeout(() => fail(new Error('the server sent no diagnostics')), 10000);
        const check = () => { const d = found(); if (d) { clearTimeout(timer); done(d.params.diagnostics); } else noteWaiters.push(check); };
        check();
      });
    },
    stop() { proc.kill(); },
  };
}

module.exports = (t) => {
  const uri = 'file:///tmp/volt-lsp-test/game.volt';
  const open = async (c, text) => {
    c.notes.length = 0;
    c.tell('textDocument/didOpen', { textDocument: { uri, languageId: 'volt', version: 1, text } });
    return c.diagnostics(uri);
  };

  t.test('the server starts, says what it can do, and answers an editor', async () => {
    const c = client(t.ROOT);
    try {
      const init = await c.ask('initialize', { processId: process.pid, rootUri: null, capabilities: {} });
      t.assert.strictEqual(init.capabilities.hoverProvider, true);
      t.assert.strictEqual(init.capabilities.definitionProvider, true);
      t.assert.strictEqual(init.capabilities.documentSymbolProvider, true);
      t.assert.ok(init.capabilities.completionProvider);
      t.assert.strictEqual(init.serverInfo.name, 'Volt');

      // ---- diagnostics, with the right ranges and severities ----
      const problems = await open(c, '#js\nlet score = 0\nprint scroe\nfn spare() {\n  return 1\n}\n');
      t.assert.deepStrictEqual(problems.map((d) => d.severity), [1, 2], 'one error then one warning');
      t.assert.match(problems[0].message, /Did you mean 'score'/);
      t.assert.deepStrictEqual(problems[0].range, { start: { line: 2, character: 6 }, end: { line: 2, character: 11 } },
        'underlines scroe, counting lines and characters from 0');

      // ---- a clean file clears them ----
      c.notes.length = 0;
      c.tell('textDocument/didChange', { textDocument: { uri, version: 2 }, contentChanges: [{ text: '#html\ncanvas 320, 180\nlet hp = 10\nfn hurt(amount) {\n  hp -= amount\n}\nevery frame {\n  hurt(1)\n  render3d\n}\n' }] });
      t.assert.deepStrictEqual(await c.diagnostics(uri), []);

      // ---- completion ----
      // line 8 is '  render3d': with nothing typed yet, everything that fits here is offered
      const done = await c.ask('textDocument/completion', { textDocument: { uri }, position: { line: 8, character: 2 } });
      t.assert.ok(done.items.length > 5, `expected plenty of suggestions, got ${done.items.length}`);
      const labels = done.items.map((i) => i.label);
      t.assert.ok(labels.includes('hurt') && labels.includes('hp'), `offers the file's own names: ${labels.slice(0, 8)}`);
      t.assert.strictEqual(labels[0], 'hp', 'the file\'s own names come first');

      // half a word only offers what matches it, and replaces that word
      const partial = await c.ask('textDocument/completion', { textDocument: { uri }, position: { line: 7, character: 5 } });
      t.assert.deepStrictEqual(partial.items.map((i) => i.label), ['hurt']);
      t.assert.deepStrictEqual(partial.items[0].textEdit.range, { start: { line: 7, character: 2 }, end: { line: 7, character: 6 } });
      const snippet = done.items.find((i) => i.kind === 15);
      if (snippet) t.assert.strictEqual(snippet.insertTextFormat, 2, 'snippets are marked as snippets');

      // ---- hover ----
      const hover = await c.ask('textDocument/hover', { textDocument: { uri }, position: { line: 3, character: 4 } });
      t.assert.match(hover.contents.value, /fn hurt\(amount\)/);

      // ---- go to definition ----
      const at = await c.ask('textDocument/definition', { textDocument: { uri }, position: { line: 7, character: 3 } });
      t.assert.strictEqual(at.range.start.line, 3, 'hurt is made on the fourth line');
      t.assert.strictEqual(at.uri, uri);

      // ---- outline ----
      const outline = await c.ask('textDocument/documentSymbol', { textDocument: { uri } });
      t.assert.deepStrictEqual(outline.map((s) => s.name), ['hp', 'hurt']);

      // ---- a request it doesn't handle is answered, not ignored ----
      t.assert.strictEqual(await c.ask('textDocument/formatting', { textDocument: { uri } }), null);

      // ---- closing clears the problems ----
      c.notes.length = 0;
      c.tell('textDocument/didClose', { textDocument: { uri } });
      t.assert.deepStrictEqual(await c.diagnostics(uri), []);
    } finally {
      c.stop();
    }
  });

  t.test('the server survives nonsense without dying', async () => {
    const c = client(t.ROOT);
    try {
      await c.ask('initialize', { capabilities: {} });
      c.proc.stdin.write('Content-Length: 9\r\n\r\nnot-json!');
      c.tell('textDocument/didChange', { textDocument: { uri }, contentChanges: [] });
      await open(c, '#js\nlet a = ');
      // after all that, it still answers
      const hover = await c.ask('textDocument/hover', { textDocument: { uri }, position: { line: 1, character: 5 } });
      t.assert.ok(hover === null || typeof hover === 'object');
      const still = await c.ask('textDocument/documentSymbol', { textDocument: { uri } });
      t.assert.ok(Array.isArray(still));
    } finally {
      c.stop();
    }
  });
};
