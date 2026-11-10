#!/usr/bin/env node
// =====================================================================
//  A Language Server for Volt, speaking LSP over stdin/stdout.
//
//  It is a thin shell around lib/language-service.js - the same code Volt
//  Studio uses - so an editor that speaks LSP gets exactly what Volt Studio
//  has: every problem at once, autocomplete that knows the file, hover,
//  go to definition and an outline.
//
//  No packages to install: the protocol is simple enough to write out.
//
//    node lsp/server.js --stdio
//
//  The VS Code extension in vscode-volt/ starts this automatically. For any
//  other editor, point it at this file as a stdio language server for .volt.
// =====================================================================

const path = require('path');
const ls = require(path.join(__dirname, '..', 'lib', 'language-service.js'));

const docs = new Map();           // uri -> text

// ---------------------------------------------------------------------
//  Talking LSP: messages are a header, a blank line, then JSON
// ---------------------------------------------------------------------
function send(message) {
  const body = Buffer.from(JSON.stringify(message), 'utf8');
  process.stdout.write(`Content-Length: ${body.length}\r\n\r\n`);
  process.stdout.write(body);
}

const reply = (id, result) => send({ jsonrpc: '2.0', id, result });
const notify = (method, params) => send({ jsonrpc: '2.0', method, params });

// A file:// address as a path this computer understands
function filePath(uri) {
  if (!uri || !uri.startsWith('file://')) return null;
  let p = decodeURIComponent(uri.slice('file://'.length));
  if (/^\/[A-Za-z]:/.test(p)) p = p.slice(1);          // Windows: /C:/... -> C:/...
  return path.normalize(p);
}

// LSP counts lines and characters from 0; the language service counts from 1
const toLsp = (line, col) => ({ line: Math.max(0, line - 1), character: Math.max(0, (col || 1) - 1) });
function range(line, col, endCol, text) {
  if (!col) {
    const whole = (text || '').split('\n')[line - 1] || '';
    return { start: toLsp(line, 1), end: toLsp(line, whole.length + 1) };
  }
  return { start: toLsp(line, col), end: toLsp(line, endCol || col + 1) };
}

// ---------------------------------------------------------------------
//  Diagnostics
// ---------------------------------------------------------------------
function publish(uri) {
  const text = docs.get(uri);
  if (text === undefined) return;
  const file = filePath(uri);
  const found = ls.diagnostics(text, { baseDir: file ? path.dirname(file) : null });
  const diagnostics = found
    // a problem inside an imported file belongs to that file, not this one
    .filter((d) => !d.file)
    .map((d) => ({
      range: range(d.line, d.col, d.endCol, text),
      severity: d.severity === 'warning' ? 2 : 1,
      source: 'volt',
      message: d.hint ? `${d.message}\n${d.hint}` : d.message,
    }));
  // the ones from imported files are still worth showing, pinned to line 1
  for (const d of found.filter((x) => x.file)) {
    diagnostics.push({
      range: range(d.importedAt || 1, null, null, text),
      severity: d.severity === 'warning' ? 2 : 1,
      source: 'volt',
      message: `${path.basename(d.file)}, line ${d.line}: ${d.message}`,
    });
  }
  notify('textDocument/publishDiagnostics', { uri, diagnostics });
}

// ---------------------------------------------------------------------
//  What the editor asks for
// ---------------------------------------------------------------------
const COMPLETION_KIND = {
  variable: 6, function: 3, parameter: 6, pin: 6, type: 22, sprite: 6, image: 6, audio: 6,
  model3d: 6, builtin: 3, statement: 14, keyword: 14, target: 14, snippet: 15,
};
const SYMBOL_KIND = {
  function: 12, variable: 13, pin: 8, type: 23, sprite: 8, image: 8, audio: 8, model3d: 8,
};

function onCompletion(params) {
  const text = docs.get(params.textDocument.uri) || '';
  const { line, character } = params.position;
  const r = ls.completions(text, line + 1, character + 1);
  const replace = r.replace || {};
  return {
    isIncomplete: false,
    items: r.items.map((c, i) => {
      const item = {
        label: c.label,
        kind: COMPLETION_KIND[c.kind] || 1,
        detail: c.detail || undefined,
        documentation: c.doc || undefined,
        sortText: String(i).padStart(4, '0'),           // keep the service's own order
      };
      const insert = c.kind === 'snippet' ? c.insert.replace(/\$(?!\d)/g, '\\$') : c.insert;
      if (c.kind === 'snippet') item.insertTextFormat = 2;  // 2 = snippet, so $1 is a tab stop
      if (replace.startCol) {
        item.textEdit = {
          range: { start: toLsp(line + 1, replace.startCol), end: toLsp(line + 1, replace.endCol) },
          newText: insert,
        };
      } else {
        item.insertText = insert;
      }
      return item;
    }),
  };
}

function onHover(params) {
  const text = docs.get(params.textDocument.uri) || '';
  const { line, character } = params.position;
  const info = ls.hover(text, line + 1, character + 1);
  if (!info) return null;
  return {
    contents: { kind: 'markdown', value: `\`\`\`volt\n${info.signature}\n\`\`\`\n\n${info.doc}` },
    range: range(info.range.line, info.range.startCol, info.range.endCol, text),
  };
}

function onDefinition(params) {
  const text = docs.get(params.textDocument.uri) || '';
  const { line, character } = params.position;
  const at = ls.definition(text, line + 1, character + 1);
  if (!at) return null;
  return { uri: params.textDocument.uri, range: range(at.line, at.col, at.endCol, text) };
}

function onSymbols(params) {
  const text = docs.get(params.textDocument.uri) || '';
  return ls.symbols(text).map((s) => ({
    name: s.name,
    detail: s.detail || undefined,
    kind: SYMBOL_KIND[s.kind] || 13,
    range: range(s.line, s.col, s.col + s.name.length, text),
    selectionRange: range(s.line, s.col, s.col + s.name.length, text),
  }));
}

// ---------------------------------------------------------------------
//  The main loop
// ---------------------------------------------------------------------
function handle(message) {
  const { id, method, params } = message;
  switch (method) {
    case 'initialize':
      return reply(id, {
        capabilities: {
          textDocumentSync: 1,                       // 1 = send the whole file on every change
          completionProvider: { triggerCharacters: ['#', '.', '"'], resolveProvider: false },
          hoverProvider: true,
          definitionProvider: true,
          documentSymbolProvider: true,
        },
        serverInfo: { name: 'Volt', version: require(path.join(__dirname, '..', 'compiler', 'volt.js')).VERSION },
      });
    case 'initialized':
    case '$/setTrace':
      return undefined;
    case 'shutdown':
      return reply(id, null);
    case 'exit':
      return process.exit(0);
    case 'textDocument/didOpen':
      docs.set(params.textDocument.uri, params.textDocument.text);
      return publish(params.textDocument.uri);
    case 'textDocument/didChange':
      if (params.contentChanges && params.contentChanges.length) {
        docs.set(params.textDocument.uri, params.contentChanges[params.contentChanges.length - 1].text);
      }
      return publish(params.textDocument.uri);
    case 'textDocument/didSave':
      return publish(params.textDocument.uri);
    case 'textDocument/didClose':
      docs.delete(params.textDocument.uri);
      return notify('textDocument/publishDiagnostics', { uri: params.textDocument.uri, diagnostics: [] });
    case 'textDocument/completion':
      return reply(id, onCompletion(params));
    case 'textDocument/hover':
      return reply(id, onHover(params));
    case 'textDocument/definition':
      return reply(id, onDefinition(params));
    case 'textDocument/documentSymbol':
      return reply(id, onSymbols(params));
    default:
      // an editor may ask for things this server doesn't do; answer politely rather than hang
      if (id !== undefined) reply(id, null);
      return undefined;
  }
}

let buffer = Buffer.alloc(0);
process.stdin.on('data', (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  for (;;) {
    const split = buffer.indexOf('\r\n\r\n');
    if (split < 0) return;
    const header = buffer.slice(0, split).toString('ascii');
    const match = /Content-Length:\s*(\d+)/i.exec(header);
    if (!match) { buffer = buffer.slice(split + 4); continue; }
    const length = Number(match[1]);
    const start = split + 4;
    if (buffer.length < start + length) return;        // the rest hasn't arrived yet
    const body = buffer.slice(start, start + length).toString('utf8');
    buffer = buffer.slice(start + length);
    let message = null;
    try { message = JSON.parse(body); } catch (e) { continue; }
    try {
      handle(message);
    } catch (e) {
      // one bad request must never take the server down with it
      if (message.id !== undefined) reply(message.id, null);
      process.stderr.write(`volt language server: ${e && e.stack ? e.stack : e}\n`);
    }
  }
});
process.stdin.on('end', () => process.exit(0));
