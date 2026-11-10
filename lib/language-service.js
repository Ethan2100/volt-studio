// =====================================================================
//  The Volt language service: everything an editor needs to know about a
//  .volt file. Plain Node, no Electron and no editor libraries, so the same
//  code serves Volt Studio and the VS Code extension (through lsp/server.js).
//
//    const ls = require('./lib/language-service.js');
//    ls.diagnostics(source, { baseDir })   every error and warning, with ranges
//    ls.completions(source, line, col)     what can be typed here
//    ls.hover(source, line, col)           what the thing under the cursor is
//    ls.definition(source, line, col)      where that name is made
//    ls.symbols(source)                    an outline of the file
//
//  Lines and columns are 1-based, the same as the compiler's errors.
//
//  Everything here must survive half-written code - an editor asks between
//  every keystroke - so nothing throws: a file that cannot be parsed still
//  gets completions and symbols, worked out from the text itself.
// =====================================================================

const path = require('path');
const volt = require(path.join(__dirname, '..', 'compiler', 'volt.js'));
const { BUILTIN_DOCS, STATEMENT_DOCS } = require(path.join(__dirname, 'builtin-docs.js'));

// Which targets each 'where' in builtin-docs.js covers
const WHERE_TARGETS = {
  all: null,                                            // everywhere
  script: ['python', 'ruby', 'js', 'html'],
  js: ['js', 'html'],
  node: ['js'],
  web: ['html'],
  game: ['html'],
  '3d': ['html'],
};

const KEYWORDS = [
  'let', 'fn', 'return', 'if', 'else', 'repeat', 'while', 'break', 'continue', 'match',
  'forever', 'every', 'when', 'wait', 'print', 'show', 'clear', 'stop', 'import', 'for',
  'pin', 'on', 'off', 'toggle', 'set', 'fade', 'tone', 'read', 'step', 'turn',
  'true', 'false', 'uptime', 'ask', 'and', 'or', 'not', 'add', 'remove',
];

// Things worth offering as a whole line rather than a word
const SNIPPETS = [
  ['if … else', 'if $1 {\n  \n} else {\n  \n}'],
  ['match … { }', 'match $1 {\n  $2 {\n    \n  }\n  else {\n    \n  }\n}'],
  ['for … from … to', 'for i from 1 to 10 {\n  \n}'],
  ['for each … in', 'for each item in list {\n  \n}'],
  ['for each … , i in', 'for each item, i in list {\n  \n}'],
  ['while … { }', 'while $1 {\n  \n}'],
  ['repeat … { }', 'repeat 3 {\n  \n}'],
  ['fn … ( ) { }', 'fn name(value) {\n  return value\n}'],
  ['fn with a default', 'fn name(value, extra = 2) {\n  return value + extra\n}'],
  ['every … { }', 'every 500ms {\n  \n}'],
  ['every frame { }', 'every frame {\n  \n}'],
  ['forever { }', 'forever {\n  \n}'],
  ['when … pressed { }', 'when button pressed {\n  \n}'],
  ['when key … pressed { }', 'when key "space" pressed {\n  \n}'],
  ['Name = type { }', 'Player = type { name: string, health: int, speed: float }'],
  ['first-person 3D starter', 'canvas 320, 180\nworld3d "#0a0d14" fog 2600 ambient 9 shadows\nblock3d(0, -10, 0, 2000, 20, 2000, "#5c6470")\nfreeze3d\nplayer3d 0, 0, 400\n\nevery frame {\n  walk3d\n  render3d\n}'],
];

// ---------------------------------------------------------------------
//  Reading the document
// ---------------------------------------------------------------------

function lines(source) { return String(source).replace(/\r\n?/g, '\n').split('\n'); }

// The target a file compiles to, from its first real line. 'cpp' when it says nothing.
function targetOf(source) {
  for (const raw of lines(source)) {
    const text = raw.trim();
    if (!text || text.startsWith('//')) continue;
    const m = /^#(\S+)$/.exec(text);
    if (!m) break;
    const name = volt.TARGET_NAMES[m[1].toLowerCase()];
    if (!name) break;
    return name === 'python?' ? 'python' : name;
  }
  return 'cpp';
}

function fits(where, target) {
  const list = WHERE_TARGETS[where];
  return !list || list.includes(target);
}

// The word being typed, and what comes before it on the line
function wordAt(source, line, col) {
  const text = lines(source)[line - 1] || '';
  const upto = text.slice(0, Math.max(0, col - 1));
  const before = /([A-Za-z_][A-Za-z0-9_]*)$/.exec(upto);
  const after = /^([A-Za-z0-9_]*)/.exec(text.slice(Math.max(0, col - 1)));
  const start = before ? col - before[1].length : col;
  return {
    prefix: before ? before[1] : '',
    word: (before ? before[1] : '') + (after ? after[1] : ''),
    startCol: start,
    endCol: start + ((before ? before[1].length : 0) + (after ? after[1].length : 0)),
    lineText: text,
    beforeWord: upto.slice(0, (before ? -before[1].length : undefined) || undefined),
  };
}

// Everything the file makes: functions, variables, pins, types, sprites ... Read from the
// text with patterns rather than the tree, so it still works while the file is half-written.
function scanSymbols(source) {
  const out = [];
  const seen = new Set();
  const add = (kind, name, line, col, detail) => {
    const key = `${kind}:${name}`;
    if (!name || seen.has(key)) return;
    seen.add(key);
    out.push({ kind, name, line, col, detail: detail || '' });
  };
  lines(source).forEach((text, i) => {
    const line = i + 1;
    const at = (name) => text.indexOf(name) + 1;
    let m;
    if ((m = /^\s*fn\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/.exec(text))) add('function', m[1], line, at(m[1]), `fn ${m[1]}(${m[2].trim()})`);
    else if ((m = /^\s*let\s+([A-Za-z_]\w*)\s*=\s*(.*)$/.exec(text))) add('variable', m[1], line, at(m[1]), m[2].trim().slice(0, 40));
    else if ((m = /^\s*pin\s+([A-Za-z_]\w*)\s*=\s*(.*)$/.exec(text))) add('pin', m[1], line, at(m[1]), `pin = ${m[2].trim()}`);
    else if ((m = /^\s*([A-Za-z_]\w*)\s*=\s*type\s*\{(.*)$/.exec(text))) add('type', m[1], line, at(m[1]), `type { ${m[2].replace(/\}.*$/, '').trim()} }`);
    else if ((m = /^\s*(sprite|image|audio|model3d)\s+([A-Za-z_]\w*)\s*=/.exec(text))) add(m[1], m[2], line, text.indexOf(m[2]) + 1, m[1]);
    // a loop or function may introduce names too
    if ((m = /^\s*for\s+each\s+([A-Za-z_]\w*)(?:\s*,\s*([A-Za-z_]\w*))?\s+in\b/.exec(text))) {
      add('variable', m[1], line, at(m[1]), 'each item in the list');
      if (m[2]) add('variable', m[2], line, text.indexOf(m[2], text.indexOf(m[1]) + 1) + 1, 'the position, from 0');
    } else if ((m = /^\s*for\s+([A-Za-z_]\w*)\s+from\b/.exec(text))) add('variable', m[1], line, at(m[1]), 'the counter');
  });
  return out;
}

// The parameters of the function the cursor is inside, if any
function paramsAround(source, line) {
  const all = lines(source);
  let depth = 0;
  for (let i = line - 1; i >= 0; i--) {
    const text = all[i] || '';
    for (const ch of [...text].reverse()) {
      if (ch === '}') depth++;
      else if (ch === '{') depth--;
    }
    const m = /^\s*fn\s+[A-Za-z_]\w*\s*\(([^)]*)\)/.exec(text);
    if (m && depth < 0) {
      return m[1].split(',').map((p) => p.split('=')[0].trim()).filter(Boolean);
    }
    if (depth < 0) depth = 0;       // a block that isn't a function
  }
  return [];
}

// ---------------------------------------------------------------------
//  What an editor asks for
// ---------------------------------------------------------------------

// Every problem in the file, each with a range an editor can underline.
function diagnostics(source, options = {}) {
  try {
    return volt.check(source, options).diagnostics;
  } catch (e) {
    // check() only throws when something is wrong with Volt itself, never for a bad program
    return [{ severity: 'error', message: `Volt had a problem reading this file: ${e.message}`, line: 1, col: null, endCol: null, hint: null, file: null }];
  }
}

// Everything the editor wants after a keystroke, from one pass over the file:
// the problems, what it compiles to, and the output code. Asking for the
// diagnostics and the compiled code separately meant compiling the file twice
// on every keystroke - about 150 ms of blocked main process on the larger
// examples, which is felt as lag while typing.
function review(source, options = {}) {
  try {
    const r = volt.check(source, options);
    const firstError = r.diagnostics.find((d) => d.severity !== 'warning') || null;
    return {
      ok: !!r.code && !firstError,
      target: r.target,
      code: r.code,
      diagnostics: r.diagnostics,
      line: firstError ? firstError.line : 0,
      message: firstError ? firstError.message : null,
    };
  } catch (e) {
    return {
      ok: false, target: null, code: null, line: 1, message: `Volt had a problem reading this file: ${e.message}`,
      diagnostics: [{ severity: 'error', message: `Volt had a problem reading this file: ${e.message}`, line: 1, col: null, endCol: null, hint: null, file: null }],
    };
  }
}

function completions(source, line, col, options = {}) {
  const target = options.target || targetOf(source);
  const here = wordAt(source, line, col);
  const out = [];
  const push = (label, insert, kind, detail, doc) => out.push({ label, insert: insert === undefined ? label : insert, kind, detail: detail || '', doc: doc || '' });

  // On the first line, offer the targets. The '#' is part of what is being typed here, so this
  // branch matches and replaces it itself instead of going through the usual word handling.
  const firstLine = /^(\s*)(#\w*)$/.exec(here.lineText);
  if (firstLine && line <= 3) {
    const typed = firstLine[2].toLowerCase();
    const startCol = firstLine[1].length + 1;
    for (const name of Object.keys(volt.TARGET_NAMES)) {
      const label = `#${name}`;
      if (!label.startsWith(typed)) continue;
      const spec = volt.TARGETS[volt.TARGET_NAMES[name].replace('?', '')];
      push(label, label, 'target', spec ? spec.label : '');
    }
    return { items: out, replace: { startCol, endCol: startCol + firstLine[2].length } };
  }

  // Names the file itself makes
  for (const s of scanSymbols(source)) {
    if (s.line === line) continue;              // not the line being typed
    push(s.name, s.name, s.kind, s.detail);
  }
  for (const p of paramsAround(source, line)) push(p, p, 'parameter', 'a value this function was given');

  // Built-in functions that work in this target
  for (const [name, [sig, doc, where]] of Object.entries(BUILTIN_DOCS)) {
    if (!fits(where, target)) continue;
    const takesNothing = /\(\s*\)$/.test(sig);
    push(name, takesNothing ? `${name}()` : `${name}(`, 'builtin', sig, doc);
  }
  // Statements that are really commands
  for (const [name, [sig, doc, where]] of Object.entries(STATEMENT_DOCS)) {
    if (!fits(where, target)) continue;
    push(name, sig.includes(' ') ? sig : name, 'statement', sig, doc);
  }
  for (const k of KEYWORDS) push(k, k, 'keyword');
  for (const [label, body] of SNIPPETS) push(label, body, 'snippet', 'snippet');

  return finish(out, here);
}

function finish(out, here) {
  const prefix = here.prefix.toLowerCase();
  const seen = new Set();
  const list = out.filter((c) => {
    if (seen.has(c.kind + c.label)) return false;
    seen.add(c.kind + c.label);
    return !prefix || c.label.toLowerCase().startsWith(prefix);
  });
  // the file's own names first, then built-ins, then the rest
  const rank = { variable: 0, function: 0, parameter: 0, pin: 0, type: 0, sprite: 0, image: 0, audio: 0, model3d: 0, builtin: 1, statement: 1, keyword: 2, target: 2, snippet: 3 };
  list.sort((a, b) => (rank[a.kind] ?? 9) - (rank[b.kind] ?? 9) || a.label.localeCompare(b.label));
  return { items: list, replace: { line: here.startCol === here.endCol ? null : undefined, startCol: here.startCol, endCol: here.endCol } };
}

function hover(source, line, col) {
  const here = wordAt(source, line, col);
  const name = here.word;
  if (!name) return null;
  const range = { line, startCol: here.startCol, endCol: here.endCol };
  if (BUILTIN_DOCS[name]) {
    const [sig, doc, where] = BUILTIN_DOCS[name];
    return { name, signature: sig, doc, where, kind: 'builtin', range };
  }
  if (STATEMENT_DOCS[name]) {
    const [sig, doc, where] = STATEMENT_DOCS[name];
    return { name, signature: sig, doc, where, kind: 'statement', range };
  }
  const mine = scanSymbols(source).find((s) => s.name === name);
  if (mine) {
    return {
      name,
      signature: mine.kind === 'function' ? mine.detail : `${mine.kind} ${name}`,
      doc: mine.kind === 'function' ? `Made on line ${mine.line}.` : `${mine.detail ? `${mine.detail}. ` : ''}Made on line ${mine.line}.`,
      kind: mine.kind,
      range,
    };
  }
  return null;
}

function definition(source, line, col) {
  const here = wordAt(source, line, col);
  if (!here.word) return null;
  const mine = scanSymbols(source).find((s) => s.name === here.word);
  if (!mine || mine.line === line) return null;
  return { line: mine.line, col: mine.col, endCol: mine.col + here.word.length, name: here.word, kind: mine.kind };
}

function symbols(source) {
  return scanSymbols(source).sort((a, b) => a.line - b.line);
}

// The words an editor colours. Built from the compiler and this file, so a new
// built-in or keyword is highlighted without anyone editing the editor.
function highlightWords() {
  return {
    keywords: [...new Set([...volt.KEYWORDS, 'continue', 'match', 'import'])].sort(),
    builtins: Object.keys(BUILTIN_DOCS).sort(),
    // words that can start a line but are not keywords: canvas, draw, world3d, player3d ...
    commands: [...new Set([...volt.GAME_WORDS, ...volt.LIST_WORDS, ...Object.keys(STATEMENT_DOCS)])].sort(),
    pageWords: [...volt.PAGE_WORDS].sort(),
    qualifiers: [...new Set([...volt.PIN_MODES, 'pressed', 'to', 'over', 'for', 'frame', 'each', 'in', 'from', 'speed', 'jump', 'height', 'type'])].sort(),
    targets: Object.keys(volt.TARGET_NAMES).sort(),
  };
}

module.exports = { diagnostics, review, completions, hover, definition, symbols, targetOf, highlightWords, BUILTIN_DOCS, STATEMENT_DOCS };
