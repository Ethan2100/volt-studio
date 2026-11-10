// Volt syntax colours and autocomplete for the CodeMirror editor.
//
// The word lists come from the compiler itself (lib/language-service.js -> highlightWords),
// so a new built-in or command is coloured without anyone editing this file. The lists below
// are only a fallback for the moment before the real ones have been fetched.
/* global CodeMirror */

(function () {
  const FALLBACK = {
    keywords: ['pin', 'let', 'fn', 'return', 'if', 'else', 'repeat', 'while', 'break', 'continue', 'match',
      'forever', 'every', 'when', 'wait', 'print', 'show', 'clear', 'stop', 'import'],
    qualifiers: ['input', 'output', 'analog', 'pwm', 'servo', 'stepper', 'pressed', 'to', 'over', 'for'],
    builtins: ['random', 'abs', 'min', 'max', 'constrain', 'map', 'number', 'text', 'length', 'upper', 'lower', 'contains', 'part', 'sign'],
    commands: ['canvas', 'image', 'sprite', 'draw', 'paint', 'box', 'write', 'camera', 'world3d', 'render3d'],
    pageWords: ['button', 'title', 'html'],
    targets: ['c++', 'cpp', 'arduino', 'python', 'py', 'micropython', 'ruby', 'rb', 'js', 'javascript', 'node', 'html', 'web'],
  };
  const ACTIONS = ['on', 'off', 'toggle', 'set', 'fade', 'tone', 'read', 'step', 'turn'];
  const ATOMS = ['true', 'false', 'uptime'];
  const INPUTS = ['ask'];
  const LOGIC = ['and', 'or', 'not'];
  const word = (list) => new RegExp(`\\b(?:${list.join('|')})\\b`);
  const escape = (list) => list.map((w) => w.replace(/[+*?.^$()[\]{}|\\]/g, '\\$&'));

  let WORDS = FALLBACK;
  const KEYWORDS = () => WORDS.keywords;
  const QUALIFIERS = () => WORDS.qualifiers;
  const BUILTINS = () => WORDS.builtins;

  // Builds the mode from a set of word lists. Called once with the fallback, and again with the
  // real lists once the editor has them; CodeMirror picks the new one up on setOption('mode').
  function define(words) {
    WORDS = Object.assign({}, FALLBACK, words || {});
    const keywordsOnly = WORDS.keywords.filter((k) => !ACTIONS.includes(k) && !ATOMS.includes(k) && !LOGIC.includes(k) && !INPUTS.includes(k) && !WORDS.qualifiers.includes(k));
    CodeMirror.defineSimpleMode('volt', {
    start: [
      { regex: /\/\/.*/, token: 'comment' },
      { regex: new RegExp(`#(?:${escape(WORDS.targets).join('|')})\\s*$`, 'i'), token: 'meta', sol: true },
      { regex: new RegExp(`(\\s*)(${WORDS.pageWords.join('|')})(?=\\s+[^=\\s(])`), token: [null, 'keyword'], sol: true },
      { regex: new RegExp(`(\\s*)(${WORDS.commands.join('|')})(?=\\s+[^=\\s([+\\-*/])`), token: [null, 'keyword'], sol: true },
      { regex: /(every)(\s+)(frame)\b/, token: ['keyword', null, 'qualifier'] },
      { regex: /(for)(\s+)(each)(\s+)([A-Za-z_]\w*)(\s+)(in)\b/, token: ['keyword', null, 'qualifier', null, 'variable', null, 'qualifier'] },
      { regex: /\b(?:at|size|frames|frame|flip|flipped|angle|alpha|flash|color|centered|shadow|tempo|volume|tint|glow|scale|stick|icons)\b(?=\s)/, token: 'qualifier' },
      { regex: /(when)(\s+)(key)(?=\s+")/, token: ['keyword', null, 'qualifier'] },
      { regex: /(set)(\s+)([A-Za-z_]\w*)(\s+)(speed)\b/, token: ['builtin', null, 'variable', null, 'qualifier'] },
      { regex: /(for)(\s+)([A-Za-z_]\w*)(\s+)(from)\b/, token: ['keyword', null, 'variable', null, 'qualifier'], sol: false },
      { regex: /(\s*)(input)(?=\s*[("])/, token: [null, 'builtin'] },
      { regex: /##.*/, token: 'raw' },
      { regex: /#.*/, token: 'raw' },
      { regex: /"(?:[^\\"]|\\.)*"?/, token: 'string' },
      { regex: /\d+(?:\.\d+)?(?:ms|s)\b/, token: 'number duration' },
      { regex: /\d+/, token: 'number' },
      { regex: /(fn)(\s+)([A-Za-z_]\w*)/, token: ['keyword', null, 'def'] },
      { regex: /(pin)(\s+)([A-Za-z_]\w*)/, token: ['keyword', null, 'pinname'] },
      { regex: /([A-Za-z_]\w*)(\s*)(=)(\s*)(type)\b/, token: ['def', null, 'operator', null, 'keyword'] },
      { regex: /([A-Za-z_]\w*)(\.)([A-Za-z_]\w*)/, token: ['variable', 'punctuation', 'property'] },
      { regex: word(keywordsOnly), token: 'keyword' },
      { regex: word(WORDS.qualifiers), token: 'qualifier' },
      { regex: word(ACTIONS), token: 'builtin' },
      { regex: word(INPUTS), token: 'builtin' },
      { regex: word(ATOMS), token: 'atom' },
      { regex: word(LOGIC), token: 'operator' },
      { regex: new RegExp(`\\b(?:${WORDS.builtins.join('|')})(?=\\s*\\()`), token: 'variable-2' },
      { regex: /\b[A-Z]\d+\b/, token: 'number' },
      { regex: /[A-Za-z_]\w*(?=\s*\()/, token: 'variable-3' },
      { regex: /[A-Za-z_]\w*/, token: 'variable' },
      { regex: /[-+*/%=<>!]+/, token: 'operator' },
      { regex: /[.:,]/, token: 'punctuation' },
      { regex: /\{/, indent: true },
      { regex: /\}/, dedent: true },
    ],
    meta: { lineComment: '//', electricChars: '}' },
    });
  }
  define(FALLBACK);
  window.VoltMode = { define };

  // The simple word-list autocomplete below is only a fallback: the editor normally asks
  // lib/language-service.js, which also knows the file's own names and the current target.
  // Snippets that appear in autocomplete (Ctrl+Space)
  const SNIPPETS = [
    { text: 'pin led = 13', label: 'pin … output' },
    { text: 'pin button = 2 input', label: 'pin … input' },
    { text: 'pin knob = A0 analog', label: 'pin … analog' },
    { text: 'pin glow = 9 pwm', label: 'pin … pwm' },
    { text: 'pin arm = 6 servo', label: 'pin … servo' },
    { text: 'pin motor = 8, 9, 10, 11 stepper', label: 'pin … stepper (4 pins)' },
    { text: 'turn motor 90', label: 'turn … (degrees)' },
    { text: 'set motor speed to 12', label: 'set … speed to …' },
    { text: 'every 1s {\n  \n}', label: 'every 1s { }' },
    { text: 'when button pressed {\n  \n}', label: 'when … pressed { }' },
    { text: 'forever {\n  \n}', label: 'forever { }' },
    { text: 'repeat 3 {\n  \n}', label: 'repeat 3 { }' },
    { text: 'for i from 1 to 10 {\n  \n}', label: 'for i from 1 to 10 { }' },
    { text: 'show "Score: " + score', label: 'show … (updates in place)' },
    { text: 'while x < 10 {\n  \n}', label: 'while … { }' },
    { text: 'if x > 5 {\n  \n} else {\n  \n}', label: 'if … else' },
    { text: 'fn name(value) {\n  return value\n}', label: 'fn name(…) { }' },
    { text: 'fade glow to 100 over 1s', label: 'fade … to … over …' },
    { text: 'tone buzzer 440 for 200ms', label: 'tone … for …' },
    { text: 'set arm to 90', label: 'set … to …' },
    { text: 'let name = ask "What\'s your name?"', label: 'let … = ask …' },
    { text: 'button "Click me" {\n  \n}', label: 'button "…" { } (html)' },
    { text: 'when key "k" pressed {\n  \n}', label: 'when key "…" pressed { } (html)' },
    { text: 'title "My page"', label: 'title "…" (html)' },
    { text: 'html "<b>bold</b>"', label: 'html "…" (html)' },
    { text: 'import "lib.volt"', label: 'import "…" (reuse another .volt file)' },
    { text: 'Player = type { name: string, health: int, speed: float }', label: 'Name = type { field: kind } (html)' },
    { text: 'let hero = Player { name: "Hero", health: 100, speed: 2 }', label: 'Name { field: value } (html)' },
  ];

  CodeMirror.registerHelper('hint', 'volt', (cm) => {
    const cur = cm.getCursor();
    const token = cm.getTokenAt(cur);
    const start = /\w/.test(token.string) ? token.start : cur.ch;
    const prefix = cm.getLine(cur.line).slice(start, cur.ch).toLowerCase();

    // Names already used in this file
    const names = new Set();
    cm.getValue().replace(/\b(?:pin|let|fn)\s+([A-Za-z_]\w*)/g, (m, n) => names.add(n));
    cm.getValue().replace(/\b([A-Za-z_]\w*)\s*=\s*type\s*\{/g, (m, n) => names.add(n));

    const words = [
      ...[...names].map((n) => ({ text: n, displayText: n, className: 'hint-name' })),
      ...[...KEYWORDS(), ...ACTIONS, ...QUALIFIERS(), ...ATOMS, ...LOGIC, ...INPUTS].map((k) => ({ text: k, displayText: k, className: 'hint-keyword' })),
      ...BUILTINS().map((b) => ({ text: `${b}(`, displayText: `${b}(…)`, className: 'hint-builtin' })),
      ...SNIPPETS.map((s) => ({ text: s.text, displayText: s.label, className: 'hint-snippet' })),
    ];
    const seen = new Set();
    const list = words.filter((w) => {
      const key = w.displayText;
      if (seen.has(key)) return false;
      seen.add(key);
      return w.displayText.toLowerCase().startsWith(prefix);
    });
    return { list, from: CodeMirror.Pos(cur.line, start), to: cur };
  });
}());
