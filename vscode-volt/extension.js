// The Volt extension for VS Code. It starts lsp/server.js and lets VS Code talk to it, so
// everything clever lives in lib/language-service.js and is shared with Volt Studio.
//
// No npm packages: the extension speaks to the server over stdio itself, through VS Code's
// own APIs, rather than pulling in vscode-languageclient.
const cp = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const vscode = require('vscode');

// Where Volt lives. The setting wins; otherwise look in the usual places.
function findVolt() {
  const configured = vscode.workspace.getConfiguration('volt').get('path');
  const places = [
    configured,
    // the extension sitting inside a checkout of the Volt Studio repo
    path.join(__dirname, '..'),
    path.join(os.homedir(), 'AppData', 'Local', 'Programs', 'Volt Studio', 'resources', 'app'),
    path.join(os.homedir(), 'Projects', 'volt-studio'),
    '/Applications/Volt Studio.app/Contents/Resources/app',
  ].filter(Boolean);
  for (const place of places) {
    if (fs.existsSync(path.join(place, 'lsp', 'server.js'))) return place;
  }
  return null;
}

let server = null;
let channel = null;

function activate(context) {
  channel = vscode.window.createOutputChannel('Volt');
  const root = findVolt();
  if (!root) {
    vscode.window.showWarningMessage(
      'Volt: I could not find Volt Studio, so mistakes, autocomplete and hover are off. Set "volt.path" to where it is installed.',
    );
    return;
  }
  channel.appendLine(`Using Volt from ${root}`);

  // ---- the language server ----
  const diagnostics = vscode.languages.createDiagnosticCollection('volt');
  context.subscriptions.push(diagnostics, channel);
  server = startServer(root, diagnostics, context);

  // ---- commands ----
  const runVolt = (command) => {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== 'volt') {
      vscode.window.showInformationMessage('Open a .volt file first.');
      return;
    }
    editor.document.save().then(() => {
      const terminal = vscode.window.terminals.find((t) => t.name === 'Volt') || vscode.window.createTerminal('Volt');
      terminal.show(true);
      terminal.sendText(`node "${path.join(root, 'bin', 'volt.js')}" ${command} "${editor.document.fileName}"`);
    });
  };
  context.subscriptions.push(
    vscode.commands.registerCommand('volt.build', () => runVolt('build')),
    vscode.commands.registerCommand('volt.run', () => runVolt('run')),
  );
}

// Starts lsp/server.js and wires VS Code's requests to it. Written out by hand so the
// extension has no dependencies to install.
function startServer(root, diagnostics, context) {
  const proc = cp.spawn(process.execPath, [path.join(root, 'lsp', 'server.js'), '--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
  proc.stderr.on('data', (d) => channel.appendLine(String(d).trimEnd()));
  proc.on('exit', (code) => channel.appendLine(`The Volt language server stopped (${code}).`));

  let buffer = Buffer.alloc(0);
  let next = 1;
  const waiting = new Map();
  const send = (message) => {
    const body = Buffer.from(JSON.stringify(message), 'utf8');
    proc.stdin.write(`Content-Length: ${body.length}\r\n\r\n`);
    proc.stdin.write(body);
  };
  const ask = (method, params) => new Promise((done) => {
    const id = next++;
    waiting.set(id, done);
    send({ jsonrpc: '2.0', id, method, params });
    setTimeout(() => { if (waiting.delete(id)) done(null); }, 5000);
  });
  const tell = (method, params) => send({ jsonrpc: '2.0', method, params });

  proc.stdout.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    for (;;) {
      const split = buffer.indexOf('\r\n\r\n');
      if (split < 0) return;
      const match = /Content-Length:\s*(\d+)/i.exec(buffer.slice(0, split).toString('ascii'));
      if (!match) { buffer = buffer.slice(split + 4); continue; }
      const length = Number(match[1]);
      if (buffer.length < split + 4 + length) return;
      let message = null;
      try { message = JSON.parse(buffer.slice(split + 4, split + 4 + length).toString('utf8')); } catch (e) { message = null; }
      buffer = buffer.slice(split + 4 + length);
      if (!message) continue;
      if (message.id !== undefined && waiting.has(message.id)) { waiting.get(message.id)(message.result); waiting.delete(message.id); }
      else if (message.method === 'textDocument/publishDiagnostics') showProblems(diagnostics, message.params);
    }
  });

  ask('initialize', { processId: process.pid, rootUri: null, capabilities: {} }).then(() => tell('initialized', {}));

  const opened = new Set();
  const openIt = (doc) => {
    if (doc.languageId !== 'volt') return;
    opened.add(doc.uri.toString());
    tell('textDocument/didOpen', { textDocument: { uri: doc.uri.toString(), languageId: 'volt', version: doc.version, text: doc.getText() } });
  };
  vscode.workspace.textDocuments.forEach(openIt);
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(openIt),
    vscode.workspace.onDidChangeTextDocument((e) => {
      if (!opened.has(e.document.uri.toString())) return;
      tell('textDocument/didChange', { textDocument: { uri: e.document.uri.toString(), version: e.document.version }, contentChanges: [{ text: e.document.getText() }] });
    }),
    vscode.workspace.onDidCloseTextDocument((doc) => {
      if (!opened.delete(doc.uri.toString())) return;
      tell('textDocument/didClose', { textDocument: { uri: doc.uri.toString() } });
      diagnostics.delete(doc.uri);
    }),
  );

  const at = (position) => ({ line: position.line, character: position.character });
  const toRange = (r) => new vscode.Range(r.start.line, r.start.character, r.end.line, r.end.character);

  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider('volt', {
      async provideCompletionItems(document, position) {
        const result = await ask('textDocument/completion', { textDocument: { uri: document.uri.toString() }, position: at(position) });
        if (!result) return [];
        return result.items.map((item) => {
          const made = new vscode.CompletionItem(item.label, (item.kind || 1) - 1);
          made.detail = item.detail;
          made.documentation = item.documentation;
          made.sortText = item.sortText;
          const text = item.textEdit ? item.textEdit.newText : (item.insertText || item.label);
          made.insertText = item.insertTextFormat === 2 ? new vscode.SnippetString(text) : text;
          if (item.textEdit) made.range = toRange(item.textEdit.range);
          return made;
        });
      },
    }, '#', '.'),
    vscode.languages.registerHoverProvider('volt', {
      async provideHover(document, position) {
        const result = await ask('textDocument/hover', { textDocument: { uri: document.uri.toString() }, position: at(position) });
        if (!result) return null;
        return new vscode.Hover(new vscode.MarkdownString(result.contents.value), result.range ? toRange(result.range) : undefined);
      },
    }),
    vscode.languages.registerDefinitionProvider('volt', {
      async provideDefinition(document, position) {
        const result = await ask('textDocument/definition', { textDocument: { uri: document.uri.toString() }, position: at(position) });
        if (!result) return null;
        return new vscode.Location(vscode.Uri.parse(result.uri), toRange(result.range));
      },
    }),
    vscode.languages.registerDocumentSymbolProvider('volt', {
      async provideDocumentSymbols(document) {
        const result = await ask('textDocument/documentSymbol', { textDocument: { uri: document.uri.toString() } });
        if (!result) return [];
        return result.map((s) => new vscode.DocumentSymbol(s.name, s.detail || '', (s.kind || 13) - 1, toRange(s.range), toRange(s.selectionRange)));
      },
    }),
  );
  return proc;
}

function showProblems(diagnostics, params) {
  const uri = vscode.Uri.parse(params.uri);
  diagnostics.set(uri, params.diagnostics.map((d) => {
    const made = new vscode.Diagnostic(
      new vscode.Range(d.range.start.line, d.range.start.character, d.range.end.line, d.range.end.character),
      d.message,
      d.severity === 2 ? vscode.DiagnosticSeverity.Warning : vscode.DiagnosticSeverity.Error,
    );
    made.source = 'volt';
    return made;
  }));
}

function deactivate() {
  if (server) server.kill();
}

module.exports = { activate, deactivate };
