// =====================================================================
//  Ghost text: a faded suggestion after the cursor. Press Tab to accept.
//    fade g|        -> fade g[low]        (only pwm pins after "fade")
//    fade glow |    -> fade glow [to 100 over 1s]
//    every |        -> every [1s { … }]
// =====================================================================
/* global CodeMirror */

(function () {
  const KEYWORDS = ['pin', 'let', 'fn', 'return', 'if', 'else', 'repeat', 'while', 'break',
    'forever', 'every', 'when', 'wait', 'print', 'on', 'off', 'toggle', 'set', 'fade', 'tone',
    'read', 'input', 'output', 'analog', 'pwm', 'servo', 'pressed', 'true', 'false', 'uptime',
    'and', 'or', 'not', 'ask', 'input', 'show', 'clear', 'stop', 'for'];
  const BUILTINS = ['random', 'abs', 'min', 'max', 'constrain', 'map', 'number', 'text', 'length', 'upper', 'lower', 'contains'];
  const BOARD_WORDS = ['pin', 'on', 'off', 'toggle', 'set', 'fade', 'tone', 'read', 'step', 'turn', 'input', 'output', 'analog', 'pwm', 'servo', 'stepper'];
  const BOARD_OR_PAGE = ['when', 'pressed'];
  const PAGE_WORDS = ['button', 'title', 'html'];
  const BOARD_TARGETS = ['cpp', 'micropython'];
  // Words that can start a line
  const STATEMENTS = ['pin', 'let', 'fn', 'for', 'return', 'if', 'else', 'repeat', 'while', 'break',
    'forever', 'every', 'when', 'wait', 'print', 'show', 'clear', 'stop',
    'on', 'off', 'toggle', 'set', 'fade', 'tone', 'turn', 'step', ...PAGE_WORDS];

  // Only suggest words that work for the chosen language
  function fitsTarget(word, target) {
    if (!target) return true;
    if (BOARD_WORDS.includes(word)) return BOARD_TARGETS.includes(target);
    if (BOARD_OR_PAGE.includes(word)) return BOARD_TARGETS.includes(target) || target === 'html';
    if (PAGE_WORDS.includes(word)) return target === 'html';
    if (word === 'clear') return !BOARD_TARGETS.includes(target);
    return true;
  }

  // Which pin modes make sense after each action word
  const PIN_MODES_FOR = {
    fade: ['pwm'],
    set: ['output', 'pwm', 'servo', 'stepper'],
    on: ['output', 'pwm'],
    off: ['output', 'pwm', 'stepper'],
    step: ['stepper'],
    turn: ['stepper'],
    toggle: ['output', 'pwm'],
    tone: ['output'],
    when: ['input'],
    read: ['input', 'output', 'analog', 'pwm', 'servo', 'stepper'],
  };

  // What to suggest after "set <pin> " for each pin mode
  const SET_VALUE = { pwm: 'to 50', servo: 'to 90', output: 'to 1', stepper: 'to 90' };

  // Everything the file has declared: pins (with their mode), variables, functions
  function scan(cm) {
    const text = cm.getValue();
    const pins = [];
    const vars = [];
    const funcs = [];
    text.replace(/\bpin\s+([A-Za-z_]\w*)\s*=\s*\w+(?:\s*,\s*\w+)*(?:\s+(input|output|analog|pwm|servo|stepper))?/g, (m, name, mode) => {
      pins.push({ name, mode: mode || 'output' });
    });
    text.replace(/\blet\s+([A-Za-z_]\w*)/g, (m, name) => vars.push(name));
    text.replace(/\bfn\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/g, (m, name, params) => {
      funcs.push(name);
      params.split(',').map((p) => p.trim()).filter(Boolean).forEach((p) => vars.push(p));
    });
    return { pins, vars: [...new Set(vars)], funcs: [...new Set(funcs)] };
  }

  const pinsFor = (pins, action) => pins.filter((p) => PIN_MODES_FOR[action].includes(p.mode)).map((p) => p.name);

  // Works out the suggestion for the text before the cursor
  function suggest(before, info, target) {
    // --- 1. Finishing a word that's being typed ---
    // (a letter right after a number, like the s in 1s, isn't a word)
    const wordMatch = before.match(/(?:^|[^\w])([A-Za-z_]\w*)$/);
    if (wordMatch) {
      const word = wordMatch[1];
      const rest = before.slice(0, before.length - word.length);
      const prev = (rest.match(/([A-Za-z_]\w*)\s+$/) || [])[1];

      // Don't suggest while naming something new
      if (prev === 'pin' || prev === 'let' || prev === 'fn') return null;

      let candidates;
      if (prev && PIN_MODES_FOR[prev]) {
        candidates = pinsFor(info.pins, prev);              // fade g -> glow
      } else if (/^\s*$/.test(rest)) {
        // Start of a line: statements first, then names
        candidates = [...STATEMENTS, ...info.vars, ...info.funcs.map((f) => `${f}(`)];
      } else {
        // Inside an expression: values first
        candidates = [...info.vars, ...info.funcs.map((f) => `${f}(`), ...BUILTINS.map((b) => `${b}(`),
          ...info.pins.map((p) => p.name), ...KEYWORDS];
      }
      const hit = candidates.find((c) => c.startsWith(word) && c.length > word.length && fitsTarget(c, target));
      return hit ? hit.slice(word.length) : null;
    }

    // --- 2. After a space: suggest what usually comes next ---
    if (!/\s$/.test(before)) return null;
    const t = before.replace(/\s+$/, ' ');
    let m;
    if (/^\s*when\s$/.test(t) && target === 'html') return 'key "k" pressed {';
    if (/^\s*when\s+key\s$/.test(t)) return '"k" pressed {';
    if (/^\s*when\s+key\s+"[^"]*"\s$/.test(t)) return 'pressed {';
    if ((m = t.match(/\b(fade|set|on|off|toggle|tone|when|step|turn)\s$/))) {
      return pinsFor(info.pins, m[1])[0] || null;
    }
    if (/\bread\s$/.test(t)) return info.pins[0] ? info.pins[0].name : null;
    if (/\bfade\s+\w+\s$/.test(t)) return 'to 100 over 1s';
    if ((m = t.match(/\bset\s+(\w+)\s$/))) {
      const pin = info.pins.find((p) => p.name === m[1]);
      return pin ? SET_VALUE[pin.mode] || null : null;
    }
    if (/\btone\s+\w+\s$/.test(t)) return '440 for 200ms';
    if (/\bwhen\s+\w+\s$/.test(t)) return 'pressed {';
    if (/^\s*every\s$/.test(t)) return '1s {';
    if (/^\s*repeat\s$/.test(t)) return '3 {';
    if (/^\s*forever\s$/.test(t)) return '{';
    if (/\bwait\s$/.test(t)) return '500ms';
    if (/^\s*for\s$/.test(t)) return 'i from 1 to 10 {';
    if (/^\s*for\s+\w+\s$/.test(t)) return 'from 1 to 10 {';
    if (/^\s*for\s+\w+\s+from\s+\S+\s$/.test(t)) return 'to 10 {';
    if (/^\s*\w+\s\+$/.test(t) || /^\s*\w+\s$/.test(t) && info.vars.includes(t.trim())) return t.trim().endsWith('+') ? '= 1' : '+= 1';
    if (/\binput\s$/.test(t)) return '"What\'s your name?"';
    if (/^\s*button\s$/.test(t) && target === 'html') return '"Click me" {';
    if (/^\s*title\s$/.test(t) && target === 'html') return '"My page"';
    if (/\bask\s$/.test(t)) return '"What\'s your name?"';
    if (/^\s*pin\s+\w+\s$/.test(t)) return '= 13';
    if (/^\s*let\s+\w+\s$/.test(t)) return '= 0';
    if (/\bpin\s+\w+\s*=\s*\w+\s$/.test(t)) return 'input';
    if (/\bpin\s+\w+\s*=\s*\w+(\s*,\s*\w+){3}\s$/.test(t)) return 'stepper';
    if (/^\s*step\s+\w+\s$/.test(t)) return '512';
    if (/^\s*turn\s+\w+\s$/.test(t)) return '90';
    return null;
  }

  function attach(cm, getTarget = () => null) {
    let ghost = null;   // { text, mark }

    function clear() {
      if (ghost) { ghost.mark.clear(); ghost = null; }
    }

    function update() {
      clear();
      if (cm.somethingSelected() || (cm.state.completionActive && cm.state.completionActive.widget)) return;
      const cur = cm.getCursor();
      const line = cm.getLine(cur.line);
      // Only at the end of what's on the line (spaces or a closing bracket after are fine)
      if (!/^\s*\}?\s*$/.test(line.slice(cur.ch))) return;
      const type = cm.getTokenTypeAt(cur) || '';
      if (/comment|string|raw|meta/.test(type)) return;
      const before = line.slice(0, cur.ch);
      if (before.trim() === '' || before.includes('//')) return;

      const text = suggest(before, scan(cm), getTarget());
      if (!text) return;

      const el = document.createElement('span');
      el.className = 'cm-ghost';
      el.textContent = text.endsWith('{') ? `${text} … }` : text;
      const key = document.createElement('kbd');
      key.className = 'cm-ghost-key';
      key.textContent = 'Tab';
      el.appendChild(key);
      ghost = { text, mark: cm.setBookmark(cur, { widget: el, insertLeft: true }) };
    }

    // Tab: accept the suggestion. Blocks ({) get their closing } and an indented empty line.
    function accept() {
      if (!ghost) return false;
      const { text } = ghost;
      clear();
      const cur = cm.getCursor();
      if (text.endsWith('{')) {
        const indent = cm.getLine(cur.line).match(/^\s*/)[0];
        cm.replaceRange(`${text}\n${indent}  \n${indent}}`, cur);
        cm.setCursor({ line: cur.line + 1, ch: indent.length + 2 });
      } else {
        cm.replaceRange(text, cur);
      }
      return true;
    }

    let timer = null;
    const schedule = () => { clearTimeout(timer); clear(); timer = setTimeout(update, 60); };
    cm.on('change', (inst, change) => {
      // Only suggest while typing, not after pasting, undoing or loading a file
      if (change.origin === '+input' || change.origin === '+delete') schedule();
      else clear();
    });
    cm.on('cursorActivity', () => {
      if (ghost && ghost.mark.find() && !CodeMirror.cmpPos(ghost.mark.find(), cm.getCursor())) return;
      clear();
    });
    cm.on('blur', clear);
    cm.on('keydown', (inst, e) => { if (e.key === 'Escape') clear(); });

    return { accept, clear, update, has: () => !!ghost };
  }

  window.VoltGhost = { attach, suggest };
}());
