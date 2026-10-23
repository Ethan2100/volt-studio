// Volt syntax colours and autocomplete for the CodeMirror editor
/* global CodeMirror */

(function () {
  const KEYWORDS = ['pin', 'let', 'fn', 'return', 'if', 'else', 'repeat', 'while', 'break',
    'forever', 'every', 'when', 'wait', 'print', 'show', 'clear', 'stop'];
  const QUALIFIERS = ['input', 'output', 'analog', 'pwm', 'servo', 'pressed', 'to', 'over', 'for'];
  const ACTIONS = ['on', 'off', 'toggle', 'set', 'fade', 'tone', 'read'];
  const ATOMS = ['true', 'false', 'uptime'];
  const INPUTS = ['ask'];
  const LOGIC = ['and', 'or', 'not'];
  const BUILTINS = ['random', 'abs', 'min', 'max', 'constrain', 'map', 'number', 'text', 'length', 'upper', 'lower', 'contains'];
  const word = (list) => new RegExp(`\\b(?:${list.join('|')})\\b`);

  CodeMirror.defineSimpleMode('volt', {
    start: [
      { regex: /\/\/.*/, token: 'comment' },
      { regex: /#(?:c\+\+|cpp|arduino|python|py|micropython|ruby|rb|js|javascript|node|html|web)\s*$/i, token: 'meta', sol: true },
      { regex: /(\s*)(button|title|html)(?=\s+[^=\s(])/, token: [null, 'keyword'], sol: true },
      { regex: /(when)(\s+)(key)(?=\s+")/, token: ['keyword', null, 'qualifier'] },
      { regex: /(for)(\s+)([A-Za-z_]\w*)(\s+)(from)\b/, token: ['keyword', null, 'variable', null, 'qualifier'], sol: false },
      { regex: /(\s*)(input)(?=\s*[("])/, token: [null, 'builtin'] },
      { regex: /##.*/, token: 'raw' },
      { regex: /#.*/, token: 'raw' },
      { regex: /"(?:[^\\"]|\\.)*"?/, token: 'string' },
      { regex: /\d+(?:\.\d+)?(?:ms|s)\b/, token: 'number duration' },
      { regex: /\d+/, token: 'number' },
      { regex: /(fn)(\s+)([A-Za-z_]\w*)/, token: ['keyword', null, 'def'] },
      { regex: /(pin)(\s+)([A-Za-z_]\w*)/, token: ['keyword', null, 'pinname'] },
      { regex: word(KEYWORDS), token: 'keyword' },
      { regex: word(QUALIFIERS), token: 'qualifier' },
      { regex: word(ACTIONS), token: 'builtin' },
      { regex: word(INPUTS), token: 'builtin' },
      { regex: word(ATOMS), token: 'atom' },
      { regex: word(LOGIC), token: 'operator' },
      { regex: new RegExp(`\\b(?:${BUILTINS.join('|')})(?=\\s*\\()`), token: 'variable-2' },
      { regex: /\b[A-Z]\d+\b/, token: 'number' },
      { regex: /[A-Za-z_]\w*(?=\s*\()/, token: 'variable-3' },
      { regex: /[A-Za-z_]\w*/, token: 'variable' },
      { regex: /[-+*/%=<>!]+/, token: 'operator' },
      { regex: /\{/, indent: true },
      { regex: /\}/, dedent: true },
    ],
    meta: { lineComment: '//', electricChars: '}' },
  });

  // Snippets that appear in autocomplete (Ctrl+Space)
  const SNIPPETS = [
    { text: 'pin led = 13', label: 'pin … output' },
    { text: 'pin button = 2 input', label: 'pin … input' },
    { text: 'pin knob = A0 analog', label: 'pin … analog' },
    { text: 'pin glow = 9 pwm', label: 'pin … pwm' },
    { text: 'pin arm = 6 servo', label: 'pin … servo' },
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
  ];

  CodeMirror.registerHelper('hint', 'volt', (cm) => {
    const cur = cm.getCursor();
    const token = cm.getTokenAt(cur);
    const start = /\w/.test(token.string) ? token.start : cur.ch;
    const prefix = cm.getLine(cur.line).slice(start, cur.ch).toLowerCase();

    // Names already used in this file
    const names = new Set();
    cm.getValue().replace(/\b(?:pin|let|fn)\s+([A-Za-z_]\w*)/g, (m, n) => names.add(n));

    const words = [
      ...[...names].map((n) => ({ text: n, displayText: n, className: 'hint-name' })),
      ...[...KEYWORDS, ...ACTIONS, ...QUALIFIERS, ...ATOMS, ...LOGIC, ...INPUTS].map((k) => ({ text: k, displayText: k, className: 'hint-keyword' })),
      ...BUILTINS.map((b) => ({ text: `${b}(`, displayText: `${b}(…)`, className: 'hint-builtin' })),
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
