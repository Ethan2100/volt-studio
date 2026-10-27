#!/usr/bin/env node
// =====================================================================
//  VOLT - a small language that compiles to many languages
//
//  The first line of a .volt file picks the output:
//    #c++          Arduino C++        (Uno, Nano, Mega, ESP32 ...)   -> name/name.ino
//    #micropython  MicroPython        (ESP32, Raspberry Pi Pico)     -> name/main.py
//    #python       Python script      (MicroPython if it uses pins)  -> name/name.py
//    #ruby         Ruby script                                       -> name/name.rb
//    #js           JavaScript (Node)                                 -> name/name.js
//    #html         Web page (HTML + CSS + JavaScript)                -> name/index.html
//
//  Usage:   node volt.js program.volt
//
//  The compiler has three parts, each in its own section below:
//    1. LEXER      text    -> tokens
//    2. PARSER     tokens  -> tree (AST)
//    3. GENERATOR  tree    -> code for the chosen language
//
//  It can also be used as a library (Volt Studio does this):
//    const volt = require('./volt.js');
//    const { target, code } = volt.compile(sourceText);
// =====================================================================

const fs = require('fs');
const path = require('path');

const VERSION = '3.3.0';

// Errors that are the Volt programmer's fault (not a bug in the compiler)
class VoltError extends Error {
  constructor(message, line) {
    super(message);
    this.line = line;
  }
}

// =====================================================================
//  1. LEXER - chops source text into tokens
// =====================================================================

const KEYWORDS = new Set([
  // pins (boards)
  'pin', 'input', 'output', 'analog', 'pwm', 'servo', 'stepper', 'read', 'pressed',
  'step', 'turn',
  'on', 'off', 'toggle', 'set', 'to', 'fade', 'over', 'tone', 'for',
  // variables, input and output
  'let', 'print', 'uptime', 'ask',
  // control flow
  'if', 'else', 'repeat', 'while', 'break', 'wait', 'stop',
  // output
  'show', 'clear',
  'forever', 'every', 'when', 'fn', 'return',
  // values and logic
  'true', 'false', 'and', 'or', 'not',
]);

function lex(src) {
  const tokens = [];
  let i = 0;
  let line = 1;
  const add = (type, value) => tokens.push({ type, value, line });
  const isWordChar = (ch) => ch !== undefined && /[a-zA-Z0-9_]/.test(ch);

  while (i < src.length) {
    const c = src[i];

    // Newlines (count them so errors can say which line)
    if (c === '\n') { line++; i++; continue; }

    // Other whitespace
    if (/\s/.test(c)) { i++; continue; }

    // Comments: // until end of line
    if (c === '/' && src[i + 1] === '/') {
      while (i < src.length && src[i] !== '\n') i++;
      continue;
    }

    // Raw code: the rest of the line is copied into the output as-is
    //   # code          -> goes right here
    //   ## code         -> goes at the top of the file (CSS in #html programs)
    //   #include <x.h>  -> goes at the top of the file (#c++ only)
    if (c === '#') {
      let text = '';
      while (i < src.length && src[i] !== '\n') text += src[i++];
      if (text.startsWith('##')) {
        add('rawtop', text.slice(2).trim());
      } else if (/^#[a-zA-Z]/.test(text)) {
        add('rawtop', text.trim());          // a C++ directive like #include
      } else {
        add('raw', text.slice(1).trim());
      }
      continue;
    }

    // Numbers, and durations like 500ms or 1.5s
    if (/[0-9]/.test(c)) {
      let num = '';
      while (i < src.length && /[0-9.]/.test(src[i])) num += src[i++];

      if (src.startsWith('ms', i) && !isWordChar(src[i + 2])) {
        i += 2;
        add('duration', Math.round(parseFloat(num)));
      } else if (src[i] === 's' && !isWordChar(src[i + 1])) {
        i += 1;
        add('duration', Math.round(parseFloat(num) * 1000));
      } else {
        if (num.includes('.')) {
          throw new VoltError(
            `Volt only supports whole numbers (decimals are allowed in times like 1.5s), found ${num}`, line);
        }
        add('number', num);
      }
      continue;
    }

    // Words: either keywords (let, every, ...) or names (led, count, ...)
    if (/[a-zA-Z_]/.test(c)) {
      let word = '';
      while (isWordChar(src[i])) word += src[i++];
      add(KEYWORDS.has(word) ? word : 'ident', word);
      continue;
    }

    // Text: "hello"
    if (c === '"') {
      const startLine = line;
      let str = '';
      i++; // skip opening quote
      while (i < src.length && src[i] !== '"') {
        if (src[i] === '\n') throw new VoltError('Text in quotes must end on the same line', startLine);
        if (src[i] === '\\') {
          // \" quote   \\ backslash   \n new line   \t tab
          const esc = { '"': '"', '\\': '\\', n: '\n', t: '\t' }[src[i + 1]];
          if (esc === undefined) throw new VoltError(`Unknown escape '\\${src[i + 1] || ''}' in text. Use \\" \\\\ \\n or \\t`, line);
          str += esc;
          i += 2;
          continue;
        }
        str += src[i++];
      }
      if (i >= src.length) throw new VoltError('Missing closing " on text', startLine);
      i++; // skip closing quote
      add('string', str);
      continue;
    }

    // Two-character symbols
    const two = src.slice(i, i + 2);
    if (['==', '!=', '<=', '>=', '+=', '-=', '*=', '/='].includes(two)) { add(two, two); i += 2; continue; }

    // One-character symbols
    if ('=+-*/%<>{}(),[]'.includes(c)) { add(c, c); i++; continue; }

    throw new VoltError(`I don't understand the character '${c}'`, line);
  }

  add('eof', null);
  return tokens;
}

// =====================================================================
//  2. PARSER - arranges tokens into a tree (AST)
// =====================================================================

const PIN_MODES = ['input', 'output', 'analog', 'pwm', 'servo', 'stepper'];
const PAGE_WORDS = ['button', 'title', 'html'];
// Game commands (#html canvas games) and list commands. Like the page words they
// aren't keywords, so 'let box = 3' or 'fn draw()' in older programs still work.
const GAME_WORDS = ['canvas', 'image', 'sprite', 'draw', 'paint', 'box', 'write', 'camera', 'touchpad', 'music', 'save', 'audio', 'sound', 'volume'];
const LIST_WORDS = ['add', 'remove'];
const NOT_A_COMMAND = ['=', '(', '[', '+=', '-=', '*=', '/=', 'eof'];

function parse(tokens) {
  let pos = 0;

  const peek = (ahead = 0) => tokens[Math.min(pos + ahead, tokens.length - 1)];
  const next = () => tokens[pos++];
  const check = (type) => peek().type === type;
  const match = (type) => (check(type) ? next() : null);
  const describe = (t) => (t.type === 'eof' ? 'the end of the file' : `'${t.value}'`);

  function expect(type, what) {
    if (check(type)) return next();
    const t = peek();
    if (type === 'ident' && KEYWORDS.has(t.type)) {
      throw new VoltError(`'${t.value}' is a Volt word, so it can't be used as a name. Pick another, like '${t.value}1' or 'my${t.value[0].toUpperCase()}${t.value.slice(1)}'`, t.line);
    }
    throw new VoltError(`Expected ${what} but found ${describe(t)}`, t.line);
  }

  // program := statement*
  function program() {
    const body = [];
    while (!check('eof')) body.push(statement(true));
    return body;
  }

  // block := '{' statement* '}'
  function block() {
    const open = expect('{', "'{'");
    const body = [];
    while (!check('}')) {
      if (check('eof')) throw new VoltError("This '{' is never closed with '}'", open.line);
      body.push(statement(false));
    }
    expect('}', "'}'");
    return body;
  }

  function topLevelOnly(t) {
    throw new VoltError(`'${t.value}' can only be used at the top level, not inside { }`, t.line);
  }

  // A time: either 500ms / 2s, or an expression followed by ms or s ("wait gap ms")
  function duration(what) {
    const t = peek();
    if (t.type === 'duration') {
      next();
      return { kind: 'Number', value: String(t.value), line: t.line };
    }
    const value = expression();
    const unit = peek();
    if (unit.type === 'ident' && (unit.value === 'ms' || unit.value === 's')) {
      next();
      if (unit.value === 'ms') return value;
      return { kind: 'Binary', op: '*', left: value, right: { kind: 'Number', value: '1000', line: unit.line }, line: unit.line };
    }
    throw new VoltError(`Expected 'ms' or 's' after the time for ${what}, found ${describe(unit)}`, unit.line);
  }

  function statement(topLevel) {
    const t = peek();
    const line = t.line;

    switch (t.type) {
      // pin led = 13     pin button = 2 input     pin knob = A0 analog
      case 'pin': {
        if (!topLevel) topLevelOnly(t);
        next();
        const name = expect('ident', 'a pin name').value;
        expect('=', "'='");
        const pinNumber = () => {
          const numTok = next();
          if (numTok.type === 'number') return numTok.value;
          if (numTok.type === 'ident' && /^A\d+$/.test(numTok.value)) return numTok.value;
          throw new VoltError(`Expected a pin number like 13 or A0 but found ${describe(numTok)}`, numTok.line);
        };
        // pin motor = 8, 9, 10, 11 stepper      (a stepper uses 4 pins: IN1, IN2, IN3, IN4)
        const nums = [pinNumber()];
        while (match(',')) nums.push(pinNumber());
        let mode = 'output';
        if (PIN_MODES.includes(peek().type)) mode = next().type;
        if (mode === 'stepper' && nums.length !== 4) {
          throw new VoltError(`A stepper needs 4 pins (IN1, IN2, IN3, IN4), like: pin ${name} = 8, 9, 10, 11 stepper`, line);
        }
        if (mode !== 'stepper' && nums.length > 1) {
          throw new VoltError(`Only stepper pins use more than one number. Did you mean: pin ${name} = ${nums.join(', ')} stepper`, line);
        }
        return { kind: 'Pin', name, num: nums[0], nums, mode, line };
      }

      // let count = 0      let name = "Ethan"
      case 'let': {
        next();
        const name = expect('ident', 'a variable name').value;
        expect('=', "'='");
        return { kind: 'Let', name, value: expression(), topLevel, line };
      }

      // fn add(a, b) { return a + b }
      case 'fn': {
        if (!topLevel) topLevelOnly(t);
        next();
        const name = expect('ident', 'a function name').value;
        expect('(', "'('");
        const params = [];
        if (!check(')')) {
          do { params.push(expect('ident', 'a parameter name').value); } while (match(','));
        }
        expect(')', "')'");
        return { kind: 'Fn', name, params, body: block(), line };
      }

      // return x
      case 'return': {
        next();
        const value = check('}') ? null : expression();
        return { kind: 'Return', value, line };
      }

      // forever { ... }
      case 'forever': {
        if (!topLevel) topLevelOnly(t);
        next();
        return { kind: 'Forever', body: block(), line };
      }

      // every 500ms { ... }
      case 'every': {
        if (!topLevel) topLevelOnly(t);
        next();
        // every frame { ... }      (#html games: 60 times a second, in step with the screen)
        if (peek().type === 'ident' && peek().value === 'frame') {
          next();
          return { kind: 'EveryFrame', body: block(), line };
        }
        const ms = expect('duration', 'a time like 500ms or 2s (or the word frame)').value;
        return { kind: 'Every', ms, body: block(), line };
      }

      // when button pressed { ... }
      case 'when': {
        if (!topLevel) topLevelOnly(t);
        next();
        // when key "k" pressed { ... }      (web pages)
        if (peek().type === 'ident' && peek().value === 'key' && peek(1).type === 'string') {
          next();
          const key = next().value;
          expect('pressed', "'pressed'");
          return { kind: 'WhenKey', key, body: block(), line };
        }
        const pin = expect('ident', 'a pin name').value;
        expect('pressed', "'pressed'");
        return { kind: 'When', pin, body: block(), line };
      }

      // on led / off led / toggle led
      case 'on':
      case 'off':
      case 'toggle': {
        next();
        const pin = expect('ident', 'a pin name').value;
        return { kind: 'Write', action: t.type, pin, line };
      }

      // set led to 50      (pwm: 0-100%, servo: 0-180 degrees, output: on if not 0)
      case 'set': {
        next();
        const pin = expect('ident', 'a pin name').value;
        // set motor speed to 10      (stepper speed, in turns per minute)
        if (peek().type === 'ident' && peek().value === 'speed') {
          next();
          expect('to', "'to'");
          return { kind: 'SetSpeed', pin, value: expression(), line };
        }
        expect('to', "'to'");
        return { kind: 'Set', pin, value: expression(), line };
      }

      // step motor 512      (2048 steps = one full turn; negative goes the other way)
      // turn motor 90       (degrees; negative goes the other way)
      case 'step':
      case 'turn': {
        next();
        const pin = expect('ident', 'a stepper pin name').value;
        return { kind: t.type === 'step' ? 'Step' : 'Turn', pin, value: expression(), line };
      }

      // fade led to 100 over 2s
      case 'fade': {
        next();
        const pin = expect('ident', 'a pin name').value;
        expect('to', "'to'");
        const value = expression();
        expect('over', "'over'");
        return { kind: 'Fade', pin, value, time: duration("'fade'"), line };
      }

      // tone buzzer 440 for 200ms          (boards: a buzzer on a pin)
      // tone 440 for 200ms                 (#html: a retro beep through the speakers)
      // tone 880 to 220 for 150ms          (#html: slides from one pitch to another)
      case 'tone': {
        next();
        let pin = null;
        let freq = expression();
        if (!check('for') && !check('to')) {
          // the first value was the pin: tone buzzer 440 for 200ms
          if (freq.kind !== 'Var') throw new VoltError("Expected 'for' after the pitch, like: tone 440 for 200ms", peek().line);
          pin = freq.name;
          freq = expression();
        }
        let toFreq = null;
        if (match('to')) toFreq = expression();
        expect('for', "'for'");
        return { kind: 'Tone', pin, freq, toFreq, time: duration("'tone'"), line };
      }

      // wait 200ms     wait gap ms
      case 'wait':
        next();
        return { kind: 'Wait', time: duration("'wait'"), line };

      // print "hello"
      case 'print':
        next();
        return { kind: 'Print', value: expression(), line };

      // show "Score: " + score      (on a page: one line that updates; elsewhere: like print)
      case 'show':
        next();
        return { kind: 'Show', value: expression(), line };

      // clear      (wipes printed text)
      case 'clear':
        next();
        return { kind: 'Clear', line };

      // stop      (ends the program)
      case 'stop':
        next();
        return { kind: 'Stop', line };

      // for i from 1 to 10 { ... }      (counts down too: for i from 10 to 1)
      case 'for': {
        next();
        // for each enemy in enemies { ... }      (every value in a list)
        if (peek().type === 'ident' && peek().value === 'each' && peek(1).type === 'ident' && peek(2).type === 'ident' && peek(2).value === 'in') {
          next();
          const item = next().value;
          next();
          return { kind: 'ForEach', name: item, list: expression(), body: block(), line };
        }
        const name = expect('ident', 'a name for the counter, like i').value;
        const from = peek();
        if (!(from.type === 'ident' && from.value === 'from')) {
          throw new VoltError(`Expected 'from' after '${name}', like: for ${name} from 1 to 10 { }`, from.line);
        }
        next();
        const start = expression();
        expect('to', "'to'");
        const end = expression();
        return { kind: 'For', name, start, end, body: block(), line };
      }

      // if cond { ... } else { ... }
      case 'if':
        return ifStatement();

      // repeat 3 { ... }
      case 'repeat': {
        next();
        const count = expression();
        return { kind: 'Repeat', count, body: block(), line };
      }

      // while cond { ... }
      case 'while': {
        next();
        const cond = expression();
        return { kind: 'While', cond, body: block(), line };
      }

      // break
      case 'break':
        next();
        return { kind: 'Break', line };

      // # raw code line
      case 'raw':
        next();
        return { kind: 'Raw', code: t.value, line };

      // ## raw code for the top of the file, or #include
      case 'rawtop':
        if (!topLevel) {
          throw new VoltError("'##' and '#include' lines must be at the top level, not inside { }. Use a single '#' here", line);
        }
        next();
        return { kind: 'RawTop', code: t.value, line };

      // count = count + 1     or     beep(3)     or     score += 1
      case 'ident': {
        if (['+=', '-=', '*=', '/='].includes(peek(1).type)) {
          next();
          const opTok = next();
          const value = expression();
          const target = { kind: 'Var', name: t.value, line };
          return { kind: 'Assign', name: t.value, value: { kind: 'Binary', op: opTok.type[0], left: target, right: value, line }, line };
        }
        // Changing one value in a list: scores[2] = 10     hp[i] -= 1
        if (peek(1).type === '[') {
          next();
          next();
          const index = expression();
          expect(']', "']'");
          const opTok = next();
          if (!['=', '+=', '-=', '*=', '/='].includes(opTok.type)) {
            throw new VoltError(`Expected '=' after ${t.value}[...], like: ${t.value}[0] = 5`, opTok.line);
          }
          let value = expression();
          if (opTok.type !== '=') {
            const current = { kind: 'Index', target: { kind: 'Var', name: t.value, line }, index, line };
            value = { kind: 'Binary', op: opTok.type[0], left: current, right: value, line };
          }
          return { kind: 'IndexAssign', name: t.value, index, value, line };
        }
        // Game and list commands
        if ((GAME_WORDS.includes(t.value) || LIST_WORDS.includes(t.value)) && !NOT_A_COMMAND.includes(peek(1).type)) {
          next();
          return gameStatement(t, topLevel);
        }
        // Web page commands. They aren't keywords, so 'pin button = 2' still works:
        //   button "Click me" { ... }      title "My page"      html "<b>bold</b>"
        if (PAGE_WORDS.includes(t.value) && !['=', '(', 'eof'].includes(peek(1).type)) {
          next();
          if (t.value === 'button') {
            if (!topLevel) topLevelOnly(t);
            const label = expression();
            return { kind: 'Button', label, body: block(), line };
          }
          return { kind: t.value === 'title' ? 'Title' : 'Html', value: expression(), line };
        }
        if (peek(1).type === '(') {
          return { kind: 'CallStmt', call: primary(), line };
        }
        next();
        expect('=', `'=' after '${t.value}'`);
        return { kind: 'Assign', name: t.value, value: expression(), line };
      }

      default:
        throw new VoltError(`A line can't start with ${describe(t)}`, line);
    }
  }

  function ifStatement() {
    const line = expect('if', "'if'").line;
    const cond = expression();
    const then = block();
    let otherwise = null;
    if (match('else')) {
      otherwise = check('if') ? [ifStatement()] : block();   // supports "else if"
    }
    return { kind: 'If', cond, then, otherwise, line };
  }

  // Little words inside game commands (at, size, frame, color ...) aren't keywords either
  // (an option word only counts on the same line, so 'color = 3' on the next line is still its own statement)
  const isWord = (w) => peek().type === 'ident' && peek().value === w && peek().line === tokens[pos - 1].line;
  function word(w, example) {
    if (isWord(w)) return next();
    throw new VoltError(`Expected '${w}' but found ${describe(peek())}. Like this: ${example}`, peek().line);
  }
  function pair() {
    const a = expression();
    expect(',', "','");
    return [a, expression()];
  }

  function gameStatement(t, topLevel) {
    const line = t.line;
    switch (t.value) {
      // canvas 320, 180      (makes a pixel screen, 320 pixels wide and 180 tall)
      case 'canvas': {
        const [w, h] = pair();
        return { kind: 'Canvas', w, h, line };
      }
      // image tiles = "dungeon.png"
      case 'image': {
        if (!topLevel) topLevelOnly(t);
        const name = expect('ident', 'a name for the image').value;
        expect('=', "'='");
        const file = expect('string', 'the image file in quotes, like "tiles.png"').value;
        return { kind: 'Image', name, file, line };
      }
      // sprite hero = tiles at 128, 106 size 16, 22 frames 4
      case 'sprite': {
        if (!topLevel) topLevelOnly(t);
        const name = expect('ident', 'a name for the sprite').value;
        expect('=', "'='");
        const image = expect('ident', 'the name of an image').value;
        const ex = `sprite ${name} = ${image} at 0, 0 size 16, 16 frames 4`;
        word('at', ex);
        const [x, y] = pair();
        word('size', ex);
        const [w, h] = pair();
        let frames = { kind: 'Number', value: '1', line };
        if (isWord('frames')) { next(); frames = expression(); }
        return { kind: 'Sprite', name, image, x, y, w, h, frames, line };
      }
      // draw hero at x, y frame f flip left angle 90 size 2 alpha 50 flash hurt
      case 'draw': {
        const sprite = expect('ident', 'a sprite name').value;
        word('at', `draw ${sprite} at x, y`);
        const [x, y] = pair();
        const opts = {};
        for (;;) {
          if (isWord('flipped')) { next(); opts.flip = { kind: 'Bool', value: true, line }; continue; }
          if (isWord('glow')) { next(); opts.glow = true; continue; }
          const o = ['frame', 'flip', 'angle', 'size', 'alpha', 'flash', 'tint', 'scale'].find(isWord);
          if (!o) break;
          next();
          opts[o] = expression();
        }
        return { kind: 'Draw', sprite, x, y, opts, line };
      }
      // paint "#14111a"      (fills the whole screen)
      case 'paint':
        return { kind: 'Paint', color: expression(), line };
      // box x, y, 40, 8 color "#ff4d6d"
      case 'box': {
        const [x, y] = pair();
        expect(',', "','");
        const [w, h] = pair();
        let color = null;
        if (isWord('color')) { next(); color = expression(); }
        return { kind: 'Box', x, y, w, h, color, line };
      }
      // write "Hello" at 10, 10 color "#ffd23f" size 2 centered shadow
      case 'write': {
        const value = expression();
        word('at', 'write "Hello" at 10, 10');
        const [x, y] = pair();
        const opts = {};
        for (;;) {
          if (isWord('centered')) { next(); opts.centered = true; continue; }
          if (isWord('shadow')) { next(); opts.shadow = true; continue; }
          const o = ['color', 'size'].find(isWord);
          if (!o) break;
          next();
          opts[o] = expression();
        }
        return { kind: 'WriteText', value, x, y, opts, line };
      }
      // camera x, y      (moves the view; HUD things go after camera 0, 0)
      case 'camera': {
        const [x, y] = pair();
        return { kind: 'Camera', x, y, line };
      }
      // audio hit = "hit1.mp3", "hit2.mp3"      (several files: one is picked at random each time)
      case 'audio': {
        if (!topLevel) topLevelOnly(t);
        const name = expect('ident', 'a name for the sound').value;
        expect('=', "'='");
        const files = [expect('string', 'the sound file in quotes, like "hit.mp3"').value];
        while (match(',')) files.push(expect('string', 'another sound file in quotes').value);
        return { kind: 'Audio', name, files, line };
      }
      // sound hit      sound hit volume 40
      case 'sound': {
        const name = expect('ident', 'the name of a sound (made with audio)').value;
        let volume = null;
        if (isWord('volume')) { next(); volume = expression(); }
        return { kind: 'Sound', name, volume, line };
      }
      // volume 50      (how loud everything is, 0 to 100)
      case 'volume':
        return { kind: 'Volume', value: expression(), line };
      // touchpad "x", "z"      (on phones: arrow pad plus buttons for these keys)
      case 'touchpad': {
        const keys = [expect('string', 'a key in quotes, like "x"').value];
        while (match(',')) keys.push(expect('string', 'a key in quotes, like "x"').value);
        // optional pictures: stick "pad.png", "nub.png"   button "button.png"   icons "a.png", "b.png"
        const art = {};
        const files = () => {
          const list = [expect('string', 'a picture file in quotes').value];
          while (match(',')) list.push(expect('string', 'a picture file in quotes').value);
          return list;
        };
        for (;;) {
          const o = ['stick', 'button', 'icons'].find(isWord);
          if (!o) break;
          next();
          art[o] = files();
        }
        if (art.icons && art.icons.length !== keys.length) {
          throw new VoltError(`Give one icon per key: ${keys.length} key${keys.length === 1 ? '' : 's'}, ${art.icons.length} icon${art.icons.length === 1 ? '' : 's'}`, line);
        }
        return { kind: 'Touchpad', keys, art, line };
      }
      // music "e5 g5 a5 _", "a2 - e2 -" tempo 140      music off
      case 'music': {
        if (match('off')) return { kind: 'Music', melody: null, line };
        const melody = expression();
        const bass = match(',') ? expression() : null;
        let tempo = { kind: 'Number', value: '140', line };
        if (isWord('tempo')) { next(); tempo = expression(); }
        return { kind: 'Music', melody, bass, tempo, line };
      }
      // save "best", score      (kept in this browser; read it back with saved("best", 0))
      case 'save': {
        const key = expression();
        expect(',', "',' between the name and the value, like: save \"best\", score");
        return { kind: 'Save', key, value: expression(), line };
      }
      // add 5 to scores
      case 'add': {
        const value = expression();
        expect('to', "'to'");
        const list = expect('ident', 'a list name').value;
        return { kind: 'ListAdd', list, value, line };
      }
      // remove scores[0]
      case 'remove': {
        const list = expect('ident', 'a list name').value;
        if (!check('[')) throw new VoltError(`Say which item to remove, like: remove ${list}[0]`, line);
        next();
        const index = expression();
        expect(']', "']'");
        return { kind: 'ListRemove', list, index, line };
      }
    }
    throw new Error(`Compiler bug: game word ${t.value}`);
  }

  // ---- Expressions, lowest precedence first ----
  // or -> and -> comparison -> add/subtract -> multiply/divide -> unary -> primary

  function binaryLevel(nextLevel, ops) {
    return function () {
      let left = nextLevel();
      while (ops.includes(peek().type)) {
        const op = next();
        const right = nextLevel();
        left = { kind: 'Binary', op: op.type, left, right, line: op.line };
      }
      return left;
    };
  }

  function unary() {
    if (check('not') || check('-')) {
      const op = next();
      return { kind: 'Unary', op: op.type, operand: unary(), line: op.line };
    }
    return primary();
  }

  // A value, then any number of [index] after it: rows[y][x]
  function primary() {
    let e = atom();
    while (check('[') && (e.kind === 'Var' || e.kind === 'Index' || e.kind === 'List' || e.kind === 'Call')) {
      const line = next().line;
      const index = expression();
      expect(']', "']'");
      e = { kind: 'Index', target: e, index, line };
    }
    return e;
  }

  function atom() {
    const t = next();
    switch (t.type) {
      case 'number': return { kind: 'Number', value: t.value, line: t.line };
      case 'string': return { kind: 'String', value: t.value, line: t.line };
      case 'true':   return { kind: 'Bool', value: true, line: t.line };
      case 'false':  return { kind: 'Bool', value: false, line: t.line };
      case 'uptime': return { kind: 'Uptime', line: t.line };
      // ask "What's your name?"  (everything up to a comparison is the question)
      // input works the same, like Python: input "Name?" or input("Name?")
      case 'ask':
      case 'input':  return { kind: 'Ask', prompt: additive(), line: t.line };
      case 'ident': {
        if (match('(')) {
          const args = [];
          if (!check(')')) {
            do { args.push(expression()); } while (match(','));
          }
          expect(')', "')'");
          return { kind: 'Call', name: t.value, args, line: t.line };
        }
        return { kind: 'Var', name: t.value, line: t.line };
      }
      case 'read': {
        const pin = expect('ident', 'a pin name').value;
        return { kind: 'Read', pin, line: t.line };
      }
      case '(': {
        const e = expression();
        expect(')', "')'");
        return e;
      }
      // A list: [3, 5, 8]     [] is an empty list
      case '[': {
        const items = [];
        if (!check(']')) {
          do {
            if (check(']')) break;     // allows a comma after the last item
            items.push(expression());
          } while (match(','));
        }
        expect(']', "']' to close the list");
        return { kind: 'List', items, line: t.line };
      }
      default:
        throw new VoltError(`Expected a value but found ${describe(t)}`, t.line);
    }
  }

  const multiplicative = binaryLevel(unary, ['*', '/', '%']);
  const additive = binaryLevel(multiplicative, ['+', '-']);
  const comparison = binaryLevel(additive, ['==', '!=', '<', '>', '<=', '>=']);
  const andExpr = binaryLevel(comparison, ['and']);
  const expression = binaryLevel(andExpr, ['or']);

  return program();
}

// =====================================================================
//  3. GENERATOR - turns the tree into code for the chosen language
// =====================================================================

// Every output Volt can make
const TARGETS = {
  cpp:         { label: 'Arduino C++', board: true,  lang: 'cpp', file: (n) => `${n}.ino` },
  micropython: { label: 'MicroPython', board: true,  lang: 'py',  file: () => 'main.py' },
  python:      { label: 'Python',      board: false, lang: 'py',  file: (n) => `${n}.py` },
  ruby:        { label: 'Ruby',        board: false, lang: 'rb',  file: (n) => `${n}.rb` },
  js:          { label: 'JavaScript',  board: false, lang: 'js',  file: (n) => `${n}.js` },
  html:        { label: 'HTML page',   board: false, lang: 'js',  file: () => 'index.html' },
};

// Addon-registered targets: id -> generate(ast) => string. Populated only
// by registerTarget() below; the four built-in targets never go through
// this - they're handled by the generate() function directly.
const EXTRA_GENERATORS = {};

// Lets an addon add a brand new output language without touching the
// generator above (which is tightly woven together for the 4 built-in
// targets and isn't meant to be forked). An addon target reuses Volt's
// real lexer and parser - so addon authors get real Volt syntax for free
// and never have to write their own parser - and supplies only its own
// backend: a generate(ast) function that walks the same AST shape the
// built-in targets use (see the full list of node .kind values in
// docs/PLUGINS.md) and returns the output source as a string.
//   registerTarget('rust', {
//     label: 'Rust',
//     file: (name) => `${name}.rs`,
//     generate(ast) { ... return rustSourceString; },
//   });
// After that, a .volt file starting with "#rust" compiles through this
// generator instead of one of the built-ins.
function registerTarget(firstLineWord, def) {
  const id = firstLineWord.toLowerCase();
  if (TARGET_NAMES[id] || EXTRA_GENERATORS[id]) {
    throw new Error(`A target called '${id}' is already registered`);
  }
  TARGET_NAMES[id] = id;
  TARGETS[id] = { label: def.label || id, board: !!def.board, lang: def.lang || 'text', file: def.file || ((n) => `${n}.${id}.txt`) };
  EXTRA_GENERATORS[id] = def.generate;
}

// What can go on the first line. 'python?' means: MicroPython if the program uses pins
const TARGET_NAMES = {
  'c++': 'cpp', cpp: 'cpp', arduino: 'cpp',
  micropython: 'micropython',
  python: 'python?', py: 'python?',
  ruby: 'ruby', rb: 'ruby',
  js: 'js', javascript: 'js', node: 'js',
  html: 'html', web: 'html',
};

// Built-in functions: name -> number of values they take
const BUILTINS = { random: 2, abs: 1, min: 2, max: 2, constrain: 3, map: 5, number: 1, text: 1, length: 1, upper: 1, lower: 1, contains: 2, part: 3, sign: 1, held: 1, saved: 2 };

// Names that would clash with Volt, C++, Python, Ruby or JavaScript.
// All of them are checked for every program, so a Volt file can switch languages freely.
const RESERVED = new Set([
  // C++ / Arduino
  'int', 'long', 'float', 'double', 'char', 'bool', 'void', 'byte', 'short',
  'unsigned', 'signed', 'const', 'static', 'auto', 'return', 'for', 'while',
  'do', 'switch', 'case', 'break', 'continue', 'class', 'struct', 'new',
  'delete', 'this', 'default', 'goto', 'setup', 'loop', 'delay', 'millis',
  'micros', 'pinMode', 'digitalWrite', 'digitalRead', 'analogRead', 'analogWrite',
  'Serial', 'String', 'Servo', 'HIGH', 'LOW', 'INPUT', 'OUTPUT', 'INPUT_PULLUP',
  'LED_BUILTIN', 'randomSeed', 'noTone',
  // Python / MicroPython
  'def', 'import', 'from', 'in', 'is', 'None', 'True', 'False', 'lambda',
  'pass', 'yield', 'with', 'as', 'try', 'except', 'raise', 'global', 'del',
  'elif', 'assert', 'finally', 'nonlocal', 'async', 'await', 'Pin', 'PWM',
  'ADC', 'time', 'machine', 'range', 'str', 'len', 'list', 'dict', 'type', 'sum',
  'int', 'float', 'id', 'open', 'format', 'object',
  // Ruby
  'alias', 'begin', 'defined', 'end', 'ensure', 'module', 'next', 'nil', 'redo',
  'rescue', 'retry', 'self', 'super', 'then', 'undef', 'unless', 'until', 'puts',
  'gets', 'rand', 'sleep', 'require', 'p', 'elsif',
  // JavaScript
  'var', 'function', 'typeof', 'instanceof', 'null', 'undefined', 'throw', 'catch',
  'export', 'extends', 'debugger', 'of', 'document', 'window', 'console', 'Math',
  'Date', 'prompt', 'alert', 'setTimeout', 'setInterval', 'parseInt', 'arguments',
  'eval', 'Number', 'Object', 'Array', 'process', 'require', 'NaN', 'Infinity',
  // Volt built-in functions
  ...Object.keys(BUILTINS),
]);

// C++ helper functions, added to the output only when used.
// (Arduino's min/max/abs/constrain are macros that can run an argument twice,
//  which breaks things like min(random(1, 6), 3), so Volt uses its own.)
const CPP_HELPERS = {
  clamp: 'long __clamp(long v, long lo, long hi) { return v < lo ? lo : (v > hi ? hi : v); }',
  min: 'long __min(long a, long b) { return a < b ? a : b; }',
  max: 'long __max(long a, long b) { return a > b ? a : b; }',
  abs: 'long __abs(long v) { return v < 0 ? -v : v; }',
  upper: 'String __upper(String s) { s.toUpperCase(); return s; }',
  lower: 'String __lower(String s) { s.toLowerCase(); return s; }',
};

// Stepper driver (28BYJ-48 + ULN2003): half-steps, 4096 per turn, coils on IN1..IN4
const CPP_STEPPER = [
  'const byte __half[8][4] = {{1,0,0,0},{1,1,0,0},{0,1,0,0},{0,1,1,0},{0,0,1,0},{0,0,1,1},{0,0,0,1},{1,0,0,1}};',
  'void __stepper_coils(const int *p, long pos) { int s = ((pos % 8) + 8) % 8; for (int i = 0; i < 4; i++) digitalWrite(p[i], __half[s][i]); }',
  'void __stepper_move(const int *p, long &pos, long rpm, long halfSteps) {',
  '  unsigned long wait = 60000000UL / (4096UL * (unsigned long)(rpm < 1 ? 1 : rpm));',
  '  long dir = halfSteps > 0 ? 1 : -1;',
  '  for (long i = 0; i < halfSteps * dir; i++) { pos += dir; __stepper_coils(p, pos); delayMicroseconds(wait); }',
  '}',
  'long __round_div(long a, long b) { return a >= 0 ? (a + b / 2) / b : -((-a + b / 2) / b); }',
  'void __stepper_to(const int *p, long &pos, long rpm, long angle) {',
  '  long now = ((pos % 4096) + 4096) % 4096;',
  '  long target = __round_div(((angle % 360) + 360) % 360 * 4096L, 360);',
  '  long diff = target - now;',
  '  if (diff > 2048) diff -= 4096;',
  '  if (diff < -2048) diff += 4096;',
  '  __stepper_move(p, pos, rpm, diff);',
  '}',
  'void __stepper_off(const int *p) { for (int i = 0; i < 4; i++) digitalWrite(p[i], LOW); }',
];
const PY_STEPPER = [
  '_HALF = ((1,0,0,0),(1,1,0,0),(0,1,0,0),(0,1,1,0),(0,0,1,0),(0,0,1,1),(0,0,0,1),(1,0,0,1))',
  'def _stepper_move(pins, pos, rpm, half_steps):',
  '    wait = 60000000 // (4096 * max(1, rpm))',
  '    d = 1 if half_steps > 0 else -1',
  '    for _ in range(abs(half_steps)):',
  '        pos += d',
  '        s = _HALF[pos % 8]',
  '        for i in range(4):',
  '            pins[i].value(s[i])',
  '        time.sleep_us(wait)',
  '    return pos',
  'def _stepper_to(pins, pos, rpm, angle):',
  '    diff = round((angle % 360) * 4096 / 360) - pos % 4096',
  '    if diff > 2048:',
  '        diff -= 4096',
  '    if diff < -2048:',
  '        diff += 4096',
  '    return _stepper_move(pins, pos, rpm, diff)',
  'def _stepper_off(pins):',
  '    for p in pins:',
  '        p.value(0)',
];

// Python helpers (desktop Python and MicroPython)
const PY_HELPERS = {
  ms: ['_start = time.monotonic()', 'def _ms():', '    return int((time.monotonic() - _start) * 1000)'],
  add: ['def _add(a, b):', '    if isinstance(a, str) or isinstance(b, str):', '        return str(a) + str(b)', '    return a + b'],
  num: ['def _num(v):', '    try:', '        return int(str(v).strip())', '    except ValueError:', '        return 0'],
};

const RB_HELPERS = {
  ms: ['$_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)', 'def _ms', '  ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - $_start) * 1000).to_i', 'end'],
  truthy: ['def _truthy(v)', '  !(v.nil? || v == false || v == 0 || v == "")', 'end'],
  add: ['def _add(a, b)', '  (a.is_a?(String) || b.is_a?(String)) ? a.to_s + b.to_s : a + b', 'end'],
  ask: ['def _ask(q)', '  print(q.to_s + " ")', '  ($stdin.gets || "").chomp', 'end'],
};

const JS_HELPERS = {
  random: ['function __random(a, b) { return Math.floor(Math.random() * (b - a + 1)) + a; }'],
  len: ['function __len(v) { return Array.isArray(v) ? v.length : String(v).length; }'],
  has: ['function __has(v, x) { return Array.isArray(v) ? v.includes(x) : String(v).includes(String(x)); }'],
  ask: [
    "const __rl = require('readline').createInterface({ input: process.stdin });",
    'const __lines = __rl[Symbol.asyncIterator]();',
    "async function __ask(q) { process.stdout.write(String(q) + ' '); const r = await __lines.next(); return r.done ? '' : r.value; }",
  ],
};

// The look of #html pages before any of your own CSS
const HTML_CSS = `  :root { color-scheme: light dark; }
  body { margin: 0; font: 17px/1.55 system-ui, "Segoe UI", sans-serif; background: #f6f7fb; color: #1d2130; }
  #volt { max-width: 760px; margin: 0 auto; padding: 32px 22px 60px; }
  h1 { font-size: 2em; margin: 0 0 16px; }
  .volt-line { margin: 4px 0; white-space: pre-wrap; }
  .volt-error { margin: 12px 0; padding: 10px 14px; border-radius: 8px; background: #ffe3e3; color: #a1121a; font-family: monospace; }
  button { font: inherit; margin: 6px 8px 6px 0; padding: 9px 18px; border: 0; border-radius: 9px; background: #ffd23f; color: #1b1600; font-weight: 600; cursor: pointer; }
  button:hover { filter: brightness(1.06); }
  button:active { transform: translateY(1px); }
  .volt-ask { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 10px 0; }
  .volt-ask input { font: inherit; padding: 8px 12px; border-radius: 9px; border: 1px solid #b9bfcc; min-width: 220px; background: transparent; color: inherit; }
  .volt-answer { opacity: 0.75; }
  .volt-show { font-size: 1.6em; font-weight: 700; margin: 10px 0; }
  @media (prefers-color-scheme: dark) {
    body { background: #14161c; color: #e2e5ee; }
    .volt-error { background: #3a1518; color: #ffb3b3; }
  }`;

// Helpers for #html games, added to the page only when it uses canvas
const GAME_RUNTIME = [
  "// ---- Volt game runtime: canvas, images, sprites, text, keys, sound ----",
  "let __cv = null, __cx = null, __W = 0, __H = 0, __camX = 0, __camY = 0;",
  "function __fit() {",
  "  if (!__cv) return;",
  "  let s = Math.min(window.innerWidth / __W, window.innerHeight / __H);",
  "  if (s >= 2) s = Math.floor(s);",
  "  __cv.style.width = Math.floor(__W * s) + 'px';",
  "  __cv.style.height = Math.floor(__H * s) + 'px';",
  "}",
  "function __canvas(w, h) {",
  "  __W = Math.max(1, w | 0); __H = Math.max(1, h | 0);",
  "  if (!__cv) {",
  "    __cv = document.createElement('canvas'); __cv.className = 'volt-canvas'; __cv.tabIndex = 0;",
  "    document.body.classList.add('volt-game'); __add(__cv);",
  "    window.addEventListener('resize', __fit);",
  "  }",
  "  __cv.width = __W; __cv.height = __H;",
  "  __cx = __cv.getContext('2d'); __cx.imageSmoothingEnabled = false;",
  "  __fit(); __cv.focus();",
  "}",
  "function __need() { if (!__cx) throw new Error('Make a screen first, like: canvas 320, 180'); }",
  "function __paint(c) { __need(); __cx.fillStyle = String(c); __cx.fillRect(0, 0, __W, __H); }",
  "function __camera(x, y) { __camX = Math.round(x); __camY = Math.round(y); }",
  "function __box(x, y, w, h, c) {",
  "  __need(); __cx.fillStyle = c == null ? '#fff' : String(c);",
  "  __cx.fillRect(Math.round(x) - __camX, Math.round(y) - __camY, Math.round(w), Math.round(h));",
  "}",
  "// 5x7 pixel font (Adafruit-GFX classic font, BSD licence): 5 columns per letter, ASCII 32-126",
  "const __FONT = '000000000000005f00000007000700147f147f14242a7f2a12231308646236495620500008070300001c2241000041221c002a1c7f1c2a08083e080800807030000808080808000060600020100804023e5149453e00427f400072494949462141494d331814127f1027454545393c4a49493141211109073649494936464949291e0000140000004034000000081422411414141414004122140802015909063e415d594e7c1211127c7f494949363e414141227f4141413e7f494949417f090909013e414151737f0808087f00417f41002040413f017f081422417f404040407f021c027f7f0408107f3e4141413e7f090909063e4151215e7f09192946264949493203017f01033f4040403f1f2040201f3f4038403f631408146303047804036159494d43007f4141410204081020004141417f04020102044040404040000307080020545478407f284444383844444428384444287f385454541800087e090218a4a49c787f0804047800447d40002040403d007f1028440000417f40007c047804787c080404783844444438fc1824241818242418fc7c08040408485454542404043f44243c4040207c1c2040201c3c4030403c44281028444c9090907c4464544c440008364100000077000000413608000201020402';",
  "const __glyphs = {};",
  "function __fontFor(c) {",
  "  if (__glyphs[c]) return __glyphs[c];",
  "  const g = document.createElement('canvas'); g.width = 95 * 6; g.height = 8;",
  "  const x = g.getContext('2d'); x.fillStyle = c;",
  "  for (let ch = 0; ch < 95; ch++) for (let col = 0; col < 5; col++) {",
  "    const b = parseInt(__FONT.substr((ch * 5 + col) * 2, 2), 16);",
  "    for (let row = 0; row < 8; row++) if ((b >> row) & 1) x.fillRect(ch * 6 + col, row, 1, 1);",
  "  }",
  "  return (__glyphs[c] = g);",
  "}",
  "function __text(t, x, y, c, s, center) {",
  "  const g = __fontFor(c);",
  "  String(t).split('\\n').forEach((ln, row) => {",
  "    let px = Math.round(x) - __camX;",
  "    if (center) px -= Math.floor((ln.length * 6 - 1) * s / 2);",
  "    const py = Math.round(y) - __camY + row * 9 * s;",
  "    for (let i = 0; i < ln.length; i++) {",
  "      let k = ln.charCodeAt(i) - 32;",
  "      if (k < 0 || k > 94) k = 31;",
  "      if (k) __cx.drawImage(g, k * 6, 0, 6, 8, px + i * 6 * s, py, 6 * s, 8 * s);",
  "    }",
  "  });",
  "}",
  "function __write(t, x, y, c, size, center, shadow) {",
  "  __need();",
  "  const s = Math.max(1, size | 0);",
  "  if (shadow) __text(t, x + s, y + s, '#000', s, center);",
  "  __text(t, x, y, c == null ? '#fff' : String(c), s, center);",
  "}",
  "// Images load before the program starts; sprites are rectangles cut out of them",
  "const __imgs = [];",
  "function __image(src, name) {",
  "  const im = new Image();",
  "  __imgs.push(new Promise((ok, fail) => {",
  "    im.onload = ok;",
  "    im.onerror = () => fail(new Error(\"Couldn't load the image '\" + name + \"'. Keep the picture next to your .volt file\"));",
  "  }));",
  "  im.src = src;",
  "  return im;",
  "}",
  "function __sprite(img, x, y, w, h, n) { return { img, x, y, w, h, n: Math.max(1, n | 0) }; }",
  "// draw options: frame, flip, angle, size (whole times), scale (percent, around the centre),",
  "// alpha, flash (pure white), tint (a colour, for white sprites like glows and smoke), glow (adds light)",
  "function __tinted(s, sx, sy, color) {",
  "  const cache = s.img.__tints || (s.img.__tints = new Map());",
  "  const key = sx + ',' + sy + ',' + s.w + ',' + s.h + ',' + color;",
  "  let t = cache.get(key);",
  "  if (!t) {",
  "    t = document.createElement('canvas'); t.width = s.w; t.height = s.h;",
  "    const g = t.getContext('2d');",
  "    g.drawImage(s.img, sx, sy, s.w, s.h, 0, 0, s.w, s.h);",
  "    g.globalCompositeOperation = 'source-atop'; g.fillStyle = color; g.fillRect(0, 0, s.w, s.h);",
  "    if (cache.size > 400) cache.clear();",
  "    cache.set(key, t);",
  "  }",
  "  return t;",
  "}",
  "function __draw(s, x, y, f, flip, ang, size, alpha, flash, tint, glow, scale) {",
  "  __need();",
  "  const sz = size == null ? 1 : Math.max(0, size);",
  "  const w0 = s.w * sz, h0 = s.h * sz, sc = scale == null ? 1 : Math.max(0, scale / 100);",
  "  const w = w0 * sc, h = h0 * sc;",
  "  const cx = Math.round(x) - __camX + w0 / 2, cy = Math.round(y) - __camY + h0 / 2, m = Math.max(w, h);",
  "  if (cx - m > __W || cy - m > __H || cx + m < 0 || cy + m < 0) return;",
  "  const k = (((f | 0) % s.n) + s.n) % s.n;",
  "  let src = s.img, sx = s.x + k * s.w, sy = s.y;",
  "  const color = flash ? '#fff' : tint;",
  "  if (color != null) { src = __tinted(s, sx, sy, String(color)); sx = 0; sy = 0; }",
  "  const c = __cx;",
  "  c.save();",
  "  if (alpha != null) c.globalAlpha = Math.max(0, Math.min(1, alpha / 100));",
  "  if (glow) c.globalCompositeOperation = 'lighter';",
  "  c.translate(cx, cy);",
  "  if (ang) c.rotate(ang * Math.PI / 180);",
  "  if (flip) c.scale(-1, 1);",
  "  c.drawImage(src, sx, sy, s.w, s.h, -w / 2, -h / 2, w, h);",
  "  c.restore();",
  "}",
  "// Keys that are held down right now: held(\"left\"), held(\"x\") ...",
  "const __down = new Set();",
  "function __keyOf(name) { const k = String(name).toLowerCase(); return __keyNames[k] || k; }",
  "function __held(name) { return __down.has(__keyOf(name)); }",
  "document.addEventListener('keydown', (e) => {",
  "  const k = e.key.toLowerCase();",
  "  __down.add(k);",
  "  if (__cv && (k === ' ' || k.startsWith('arrow'))) e.preventDefault();",
  "});",
  "document.addEventListener('keyup', (e) => { __down.delete(e.key.toLowerCase()); });",
  "window.addEventListener('blur', () => __down.clear());",
  "// every frame { }: runs 60 times a second, whatever the screen's refresh rate",
  "function __onFrame(fn) {",
  "  let last = performance.now(), acc = 0, busy = false;",
  "  const step = 1000 / 60;",
  "  const tick = async (now) => {",
  "    if (__stopped) return;",
  "    acc = Math.min(acc + (now - last), step * 4); last = now;",
  "    if (!busy && acc >= step) {",
  "      busy = true;",
  "      try { while (acc >= step) { acc -= step; await fn(); } } catch (e) { __error(e); return; } finally { busy = false; }",
  "    }",
  "    requestAnimationFrame(tick);",
  "  };",
  "  requestAnimationFrame(tick);",
  "}",
  "// tone 440 for 100ms (and tone 880 to 220 for 150ms): a little square-wave beep",
  "let __ac = null;",
  "function __beep(f1, f2, ms) {",
  "  if (!__gesture) return;",
  "  try {",
  "    __ac = __ac || new (window.AudioContext || window.webkitAudioContext)();",
  "    if (__ac.state === 'suspended') __ac.resume();",
  "    const o = __ac.createOscillator(), g = __ac.createGain(), t = __ac.currentTime, d = Math.max(10, ms) / 1000;",
  "    o.type = 'square';",
  "    o.frequency.setValueAtTime(Math.max(20, f1), t);",
  "    if (f2 != null) o.frequency.exponentialRampToValueAtTime(Math.max(20, f2), t + d);",
  "    g.gain.setValueAtTime(0.05, t);",
  "    g.gain.exponentialRampToValueAtTime(0.0001, t + d);",
  "    o.connect(g); g.connect(__dest());",
  "    o.start(t); o.stop(t + d + 0.02);",
  "  } catch (e) { /* no sound card: stay quiet */ }",
  "}",
  "// touchpad \"x\", \"z\": on touch screens, an arrow pad (or a joystick) plus a button for each key",
  "// art (optional): { pad, nub } for a joystick, button for the button background, icons for each key",
  "function __touchpad(keys, art) {",
  "  if (!window.matchMedia('(pointer: coarse)').matches) return;",
  "  art = art || {};",
  "  const pad = document.createElement('div'); pad.className = 'volt-touch';",
  "  const press = (k) => {",
  "    if (__down.has(k)) return;",
  "    __down.add(k);",
  "    if (!__stopped) __keys.filter((h) => h.key === k || h.key === 'any').forEach((h) => h.fn().catch(__error));",
  "  };",
  "  const btn = (label, key, cls, icon) => {",
  "    const b = document.createElement('button'); b.className = cls;",
  "    if (art.button) { b.classList.add('volt-art'); b.style.backgroundImage = 'url(\"' + art.button + '\")'; }",
  "    if (icon) { const i = document.createElement('img'); i.src = icon; i.alt = label; b.append(i); } else b.textContent = label;",
  "    const k = __keyOf(key);",
  "    const down = (e) => { e.preventDefault(); b.classList.add('volt-down'); press(k); };",
  "    const up = (e) => { e.preventDefault(); b.classList.remove('volt-down'); __down.delete(k); };",
  "    b.addEventListener('pointerdown', down); b.addEventListener('pointerup', up);",
  "    b.addEventListener('pointercancel', up); b.addEventListener('pointerleave', up);",
  "    return b;",
  "  };",
  "  let left;",
  "  if (art.pad) {",
  "    // a joystick: drag the nub; it holds the arrow keys for that direction (8 ways)",
  "    left = document.createElement('div'); left.className = 'volt-stick';",
  "    left.style.backgroundImage = 'url(\"' + art.pad + '\")';",
  "    const nub = document.createElement('img'); nub.className = 'volt-nub'; nub.src = art.nub || art.pad; nub.alt = '';",
  "    left.append(nub);",
  "    const dirs = ['arrowleft', 'arrowright', 'arrowup', 'arrowdown'];",
  "    let id = null;",
  "    const move = (e) => {",
  "      const r = left.getBoundingClientRect(), rad = r.width / 2;",
  "      let dx = e.clientX - (r.left + rad), dy = e.clientY - (r.top + rad);",
  "      const len = Math.hypot(dx, dy), max = rad * 0.55;",
  "      if (len > max) { dx = dx * max / len; dy = dy * max / len; }",
  "      nub.style.transform = 'translate(' + dx + 'px, ' + dy + 'px)';",
  "      const t = max * 0.4, want = new Set();",
  "      if (dx < -t) want.add('arrowleft'); if (dx > t) want.add('arrowright');",
  "      if (dy < -t) want.add('arrowup'); if (dy > t) want.add('arrowdown');",
  "      dirs.forEach((d) => { if (want.has(d)) press(d); else __down.delete(d); });",
  "    };",
  "    const end = (e) => {",
  "      if (e.pointerId !== id) return;",
  "      id = null; nub.style.transform = ''; dirs.forEach((d) => __down.delete(d));",
  "    };",
  "    left.addEventListener('pointerdown', (e) => { e.preventDefault(); id = e.pointerId; left.setPointerCapture(id); move(e); });",
  "    left.addEventListener('pointermove', (e) => { if (e.pointerId === id) move(e); });",
  "    left.addEventListener('pointerup', end); left.addEventListener('pointercancel', end);",
  "  } else {",
  "    left = document.createElement('div'); left.className = 'volt-dpad';",
  "    left.append(btn('\u25b2', 'up', 'u'), btn('\u25c0', 'left', 'l'), btn('\u25b6', 'right', 'r'), btn('\u25bc', 'down', 'd'));",
  "  }",
  "  const acts = document.createElement('div'); acts.className = 'volt-acts';",
  "  keys.forEach((k, i) => acts.append(btn(String(k).toUpperCase(), k, 'a', art.icons && art.icons[i])));",
  "  pad.append(left, acts);",
  "  document.body.appendChild(pad);",
  "}",
  "// volume 50: loudness of everything (0 is silent). audio/sound: sound files, picked at random when there are several",
  "let __vol = 1, __master = null;",
  "function __dest() {",
  "  if (!__master) { __master = __ac.createGain(); __master.gain.value = __vol; __master.connect(__ac.destination); }",
  "  return __master;",
  "}",
  "function __volume(v) { __vol = Math.max(0, Math.min(1, v / 100)); if (__master) __master.gain.value = __vol; }",
  "const __sounds = [];",
  "function __audio(srcs, name) { const a = { srcs, name, bufs: null, busy: false }; __sounds.push(a); return a; }",
  "function __bytes(src) {",
  "  if (src.startsWith('data:')) {",
  "    const bin = atob(src.slice(src.indexOf(',') + 1)), out = new Uint8Array(bin.length);",
  "    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);",
  "    return Promise.resolve(out.buffer);",
  "  }",
  "  return fetch(src).then((r) => r.arrayBuffer());",
  "}",
  "function __decode(buf) { return new Promise((ok, fail) => { const p = __ac.decodeAudioData(buf, ok, fail); if (p && p.catch) p.catch(fail); }); }",
  "function __loadSounds() {",
  "  if (!__ac) return;",
  "  __sounds.forEach((a) => {",
  "    if (a.busy) return;",
  "    a.busy = true;",
  "    Promise.all(a.srcs.map((s) => __bytes(s).then(__decode)))",
  "      .then((bufs) => { a.bufs = bufs; })",
  "      .catch(() => { a.bufs = []; console.warn(\"Couldn't play the sound '\" + a.name + \"'. Try an .mp3 file\"); });",
  "  });",
  "}",
  "function __sound(a, vol) {",
  "  if (!__gesture) return;",
  "  try { __ac = __ac || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }",
  "  if (!a.busy) __loadSounds();",
  "  if (!a.bufs || !a.bufs.length) return;",
  "  const s = __ac.createBufferSource(), g = __ac.createGain();",
  "  s.buffer = a.bufs[Math.floor(Math.random() * a.bufs.length)];",
  "  g.gain.value = vol == null ? 1 : Math.max(0, vol / 100);",
  "  s.connect(g); g.connect(__dest());",
  "  s.start();",
  "}",
  "// save \"best\", 120 and saved(\"best\", 0): values kept in this browser between visits",
  "function __saveKey(k) { return 'volt:' + location.pathname + ':' + String(k); }",
  "function __save(k, v) { try { localStorage.setItem(__saveKey(k), JSON.stringify(v)); } catch (e) { /* storage blocked: skip */ } }",
  "function __saved(k, d) {",
  "  try { const s = localStorage.getItem(__saveKey(k)); return s == null ? d : JSON.parse(s); } catch (e) { return d; }",
  "}",
  "// music \"e5 g5 a5 _ -\", \"a2 - e2 -\" tempo 140: a looping chiptune (square melody, triangle bass)",
  "// each word is one step (an eighth note): a note like c4 or f#5, - for a rest, _ to hold the note before",
  "const __NOTE = { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 };",
  "function __freq(n) {",
  "  const m = /^([a-g])(#|b)?(\\d)$/.exec(n);",
  "  if (!m) return 0;",
  "  const semis = __NOTE[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);",
  "  return 440 * Math.pow(2, (semis - 9) / 12 + (Number(m[3]) - 4));",
  "}",
  "let __song = null, __wantSong = null, __gesture = false;",
  "['keydown', 'pointerdown'].forEach((t) => document.addEventListener(t, () => { if (__gesture) return; __gesture = true; try { __ac = __ac || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; } __loadSounds(); if (__wantSong) { const w = __wantSong; __wantSong = null; __music(w[0], w[1], w[2]); } }, true));",
  "function __music(mel, bass, tempo) {",
  "  if (!__gesture) { __wantSong = mel == null ? null : [mel, bass, tempo]; return; }  // browsers need a key press or click first",
  "  const key = mel == null ? '' : String(mel) + '|' + String(bass) + '|' + tempo;",
  "  if (__song && __song.key === key) return;",
  "  if (__song) {",
  "    clearInterval(__song.timer);",
  "    try { __song.out.gain.setTargetAtTime(0, __ac.currentTime, 0.05); } catch (e) { /* ignore */ }",
  "    __song = null;",
  "  }",
  "  if (mel == null) return;",
  "  try { __ac = __ac || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }",
  "  const words = (t) => String(t == null ? '' : t).trim().toLowerCase().split(/\\s+/).filter(Boolean);",
  "  const voices = [words(mel), words(bass)];",
  "  const out = __ac.createGain(); out.connect(__dest());",
  "  const s = { key, out, step: 0, next: __ac.currentTime + 0.08, dur: 60 / Math.max(30, tempo || 140) / 2 };",
  "  s.timer = setInterval(() => {",
  "    if (__stopped) { clearInterval(s.timer); return; }",
  "    if (__ac.state === 'suspended') __ac.resume();",
  "    if (s.next < __ac.currentTime - 0.1) s.next = __ac.currentTime + 0.05;",
  "    while (s.next < __ac.currentTime + 0.25) {",
  "      voices.forEach((v, vi) => {",
  "        if (!v.length) return;",
  "        const n = v[s.step % v.length];",
  "        const f = __freq(n);",
  "        if (!f) return;",
  "        let len = 1;",
  "        while (len < v.length && v[(s.step + len) % v.length] === '_') len++;",
  "        const o = __ac.createOscillator(), g = __ac.createGain();",
  "        const t = s.next, d = s.dur * len * 0.9, vol = vi === 0 ? 0.022 : 0.05;",
  "        o.type = vi === 0 ? 'square' : 'triangle';",
  "        o.frequency.value = f;",
  "        g.gain.setValueAtTime(0, t);",
  "        g.gain.linearRampToValueAtTime(vol, t + 0.01);",
  "        g.gain.setValueAtTime(vol, t + d * 0.6);",
  "        g.gain.linearRampToValueAtTime(0, t + d);",
  "        o.connect(g); g.connect(out);",
  "        o.start(t); o.stop(t + d + 0.02);",
  "      });",
  "      s.step++;",
  "      s.next += s.dur;",
  "    }",
  "  }, 50);",
  "  __song = s;",
  "}",
];

// Extra CSS for pages that use 'canvas' (games): full window, crisp pixels
const GAME_CSS = `  body.volt-game { background: #000; overflow: hidden; }
  body.volt-game #volt { max-width: none; padding: 0; height: 100vh; display: grid; place-items: center; align-content: center; }
  body.volt-game #volt > h1 { display: none; }
  body.volt-game .volt-error { position: fixed; top: 10px; left: 10px; right: 10px; z-index: 5; }
  .volt-canvas { display: block; image-rendering: pixelated; image-rendering: crisp-edges; outline: none; touch-action: none; }
  .volt-touch { position: fixed; inset: auto 0 0 0; display: flex; justify-content: space-between; align-items: end; padding: 18px max(18px, env(safe-area-inset-right, 0px)) max(18px, env(safe-area-inset-bottom, 0px)) max(18px, env(safe-area-inset-left, 0px)); pointer-events: none; z-index: 4; user-select: none; -webkit-user-select: none; }
  .volt-touch button { pointer-events: auto; margin: 0; padding: 0; border-radius: 50%; background: rgba(255,255,255,0.10); color: rgba(255,255,255,0.75); font: 700 18px system-ui, sans-serif; touch-action: none; border: 2px solid rgba(255,255,255,0.25); }
  .volt-touch button:active { background: rgba(255,255,255,0.35); transform: none; }
  .volt-dpad { display: grid; grid-template-columns: repeat(3, 44px); grid-template-rows: repeat(3, 44px); }
  .volt-dpad .u { grid-area: 1 / 2; } .volt-dpad .l { grid-area: 2 / 1; } .volt-dpad .r { grid-area: 2 / 3; } .volt-dpad .d { grid-area: 3 / 2; }
  .volt-dpad button { border-radius: 12px; }
  .volt-acts { display: flex; gap: 14px; align-items: end; }
  .volt-acts button { width: 56px; height: 56px; }
  .volt-acts button:nth-child(2) { margin-bottom: 34px; }
  .volt-touch button.volt-art { background: center / contain no-repeat; border: 0; display: grid; place-items: center; }
  .volt-touch button img { width: 46%; height: 46%; pointer-events: none; }
  .volt-touch button.volt-down { transform: scale(0.92); filter: brightness(1.35); }
  .volt-stick { position: relative; width: 132px; height: 132px; display: grid; place-items: center; background: center / contain no-repeat; pointer-events: auto; touch-action: none; }
  .volt-nub { width: 48%; height: 48%; pointer-events: none; }`;

// Removes one pair of outer brackets: "(a + b)" -> "a + b" (but not "(a) + (b)")
function bare(code) {
  if (!code.startsWith('(') || !code.endsWith(')')) return code;
  let depth = 0;
  let inStr = false;
  for (let i = 0; i < code.length; i++) {
    const ch = code[i];
    if (inStr) {
      if (ch === '\\') i++;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') inStr = true;
    else if (ch === '(') depth++;
    else if (ch === ')') {
      depth--;
      if (depth === 0 && i < code.length - 1) return code;   // closed before the end
    }
  }
  return code.slice(1, -1);
}

function generate(ast, target = 'cpp', options = {}) {
  const T = TARGETS[target];
  if (!T) throw new Error(`Compiler bug: unknown target ${target}`);
  const lang = T.lang;
  const cpp = lang === 'cpp';
  const py = lang === 'py';
  const rb = lang === 'rb';
  const js = lang === 'js';
  const micro = target === 'micropython';
  const html = target === 'html';
  const node = target === 'js';

  const IND = py ? '    ' : '  ';                  // Python uses 4 spaces
  const END = cpp || js ? ';' : '';                 // C++ and JS lines end with ;
  const CMT = cpp || js ? '//' : '#';               // comment marker in the output

  const pins = new Map();       // name -> Pin node
  const funcs = new Map();      // name -> Fn node
  const topLines = [];          // raw code for the very top (#include, ## lines)
  const cssLines = [];          // ## lines in #html programs
  const globals = [];           // variables declared before the program starts
  const setupExtra = [];        // things C++ setup() needs (servo attach, random seed)
  const setupLines = [];        // statements that run once
  const loopLines = [];         // statements that run forever
  const funcLines = [];         // function definitions
  const scopes = [new Map()];   // visible variables: name -> type ('num' | 'text' | 'any')
  const helpers = new Set();    // helper functions used
  let usesSerial = false;
  let usesRandom = false;
  let usesServo = false;
  let usesStepper = false;
  let usesForever = false;
  let usesGame = false;         // canvas, sprites, held keys ... (#html)
  const images = new Map();     // name -> Image node
  const sprites = new Map();    // name -> Sprite node
  const audios = new Map();     // name -> Audio node
  let uid = 0;                  // makes hidden helper names unique
  let loopDepth = 0;            // inside repeat/while?
  let inFunction = false;       // inside fn?

  // ---------- small helpers ----------
  const pad = (depth) => IND.repeat(depth);
  const hidden = (name) => (py || rb ? `_${name}` : `__${name}`);
  const levelVar = (pin) => hidden(`level_${pin}`);   // pwm brightness 0-100
  const angleVar = (pin) => hidden(`angle_${pin}`);   // servo angle 0-180
  const servoObj = (pin) => `__servo_${pin}`;         // C++ Servo object
  const posVar = (pin) => hidden(`pos_${pin}`);       // stepper position in half-steps (4096 per turn)
  const rpmVar = (pin) => hidden(`rpm_${pin}`);       // stepper speed in turns per minute
  const global = (name) => (rb ? `$${name}` : name);  // Ruby top-level variables need $

  const help = (name) => { helpers.add(name); };
  function cppHelper(name) { helpers.add(name); return `__${name}`; }

  function boardOnly(what, line) {
    if (!T.board) {
      throw new VoltError(`${what} only works when Volt compiles for a board (#c++ or #micropython)`, line);
    }
  }
  function htmlOnly(what, line) {
    if (!html) throw new VoltError(`${what} only works in #html programs (web pages)`, line);
  }
  function gameOnly(what, line) {
    if (!html) throw new VoltError(`${what} is for games, so it only works in #html programs`, line);
    usesGame = true;
  }
  function listsOk(line) {
    if (T.board) throw new VoltError('Lists work in #python, #ruby, #js and #html programs, not on boards (yet)', line);
  }

  // Text in quotes, written safely for the output language
  function strLit(s) {
    let out = JSON.stringify(s);
    if (rb) out = out.replace(/#/g, '\\#');               // Ruby would treat #{ } as code
    if (html) out = out.replace(/</g, '\\u003c');          // keep </script> from ending the page script
    return out;
  }

  // Where an image comes from. When Volt knows the .volt file's folder (Volt Studio's
  // Run/Build and the command line), the picture is packed into the page itself,
  // so the finished index.html works anywhere - even uploaded on its own.
  const MIME = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml' };
  const SOUND_MIME = { mp3: 'audio/mpeg', ogg: 'audio/ogg', wav: 'audio/wav', m4a: 'audio/mp4' };
  function imageSource(node) { return embedFile(node.file, node.line, MIME, "a picture", '.png, .jpg, .gif, .webp or .svg'); }
  function soundSource(f, line) { return embedFile(f, line, SOUND_MIME, "a sound", '.mp3, .ogg, .wav or .m4a'); }
  function embedFile(f, line, types, what, list) {
    if (/^(https?:|data:)/.test(f)) return f;
    const ext = (f.split('.').pop() || '').toLowerCase();
    if (!types[ext]) throw new VoltError(`'${f}' isn't ${what} Volt knows. Use a ${list} file`, line);
    // options.baseDir is the .volt file's folder; options.extraDirs are other places to look
    // (Volt Studio passes an example's own folder, so a saved copy still finds its pictures)
    const dirs = [options.baseDir, ...(options.extraDirs || [])].filter(Boolean);
    if (dirs.length) {
      const full = dirs.map((d) => path.resolve(d, f)).find((x) => fs.existsSync(x));
      if (!full) throw new VoltError(`Can't find the ${what === 'a sound' ? 'sound' : 'image'} '${f}'. Put it in the same folder as your .volt file`, line);
      return `data:${types[ext]};base64,${fs.readFileSync(full).toString('base64')}`;
    }
    return `../${f.replace(/\\/g, '/')}`;   // the page sits one folder down, in name/index.html
  }

  function clamp(code, lo, hi) {
    if (py) return `max(${lo}, min(${hi}, ${code}))`;
    if (rb) return `(${code}).clamp(${lo}, ${hi})`;
    if (js) return `Math.min(Math.max(${code}, ${lo}), ${hi})`;
    return `${cppHelper('clamp')}(${code}, ${lo}, ${hi})`;
  }

  function lookupVar(name) {
    for (let i = scopes.length - 1; i >= 0; i--) {
      if (scopes[i].has(name)) return { type: scopes[i].get(name), top: i === 0 };
    }
    return null;
  }

  function checkName(name, line, isParam = false) {
    if (RESERVED.has(name) || name.startsWith('_')) {
      throw new VoltError(`'${name}' is a reserved name (Volt or one of its languages already uses it), please pick another`, line);
    }
    if (rb && /^[A-Z]/.test(name)) {
      throw new VoltError(`In #ruby, names must start with a lowercase letter ('${name}' would be a Ruby constant)`, line);
    }
    // (a function parameter may share its name with a top-level variable; inside the function it means the parameter)
    if (pins.has(name) || funcs.has(name) || images.has(name) || sprites.has(name) || audios.has(name) || (!isParam && lookupVar(name))) {
      throw new VoltError(`'${name}' already exists`, line);
    }
  }

  function getPin(name, line, allowed, action) {
    const p = pins.get(name);
    if (!p) {
      if (lookupVar(name)) throw new VoltError(`'${name}' is a variable, not a pin`, line);
      if (!T.board) boardOnly(`${action || 'Using pins'}`, line);
      throw new VoltError(`There is no pin called '${name}'`, line);
    }
    if (allowed && !allowed.includes(p.mode)) {
      const a = (m) => (/^[aeiou]/.test(m) ? 'an' : 'a');
      const list = allowed.length === 1 ? allowed[0] : `${allowed.slice(0, -1).join(', ')} or ${allowed[allowed.length - 1]}`;
      throw new VoltError(`Can't use ${action} on '${name}': it's ${a(p.mode)} ${p.mode} pin, but this needs ${a(allowed[0])} ${list} pin`, line);
    }
    return p;
  }

  // A rough guess of an expression's type, used to declare top-level variables
  function staticType(e) {
    switch (e.kind) {
      case 'String': case 'Ask': return 'text';
      case 'List': return 'list';
      case 'Index': return 'any';
      case 'Call':
        if (['text', 'upper', 'lower', 'part'].includes(e.name)) return 'text';
        if (e.name === 'saved') return e.args[1] && e.args[1].kind === 'List' ? 'list' : 'any';
        if (BUILTINS[e.name] !== undefined) return 'num';
        return cpp ? 'num' : 'any';
      case 'Var': { const v = lookupVar(e.name); return v ? v.type : 'any'; }
      case 'Binary':
        if (e.op === '+') {
          const l = staticType(e.left);
          const r = staticType(e.right);
          if (l === 'text' || r === 'text') return 'text';
          if (l === 'any' || r === 'any') return 'any';
        }
        return 'num';
      default: return 'num';
    }
  }

  // ---------- pass 1: collect pins, functions, top-level variables, top-of-file code ----------
  for (const node of ast) {
    if (node.kind === 'Pin') {
      boardOnly('Using pins', node.line);
      checkName(node.name, node.line);
      if (micro && /^A/.test(node.num)) {
        throw new VoltError(`Pins like ${node.num} only work in #c++. On ESP32/Pico, use the GPIO number instead`, node.line);
      }
      pins.set(node.name, node);
      const { name, num, mode } = node;
      if (mode === 'stepper') {
        usesStepper = true;
        if (micro) {
          globals.push(`${name} = [${node.nums.map((n) => `Pin(${n}, Pin.OUT)`).join(', ')}]`);
          globals.push(`${posVar(name)} = 0`, `${rpmVar(name)} = 10`);
        } else {
          globals.push(`const int ${name}[4] = {${node.nums.join(', ')}};`);
          globals.push(`long ${posVar(name)} = 0;`, `long ${rpmVar(name)} = 10;`);
          setupExtra.push(`  for (int __p = 0; __p < 4; __p++) pinMode(${name}[__p], OUTPUT);`);
        }
        continue;
      }
      if (micro) {
        globals.push({
          output: `${name} = Pin(${num}, Pin.OUT)`,
          input: `${name} = Pin(${num}, Pin.IN, Pin.PULL_UP)`,
          analog: `${name} = ADC(Pin(${num}))`,
          pwm: `${name} = PWM(Pin(${num}), freq=1000, duty_u16=0)`,
          servo: `${name} = PWM(Pin(${num}), freq=50)`,
        }[mode]);
        if (mode === 'pwm') globals.push(`${levelVar(name)} = 0`);
        if (mode === 'servo') globals.push(`${angleVar(name)} = 0`);
      } else {
        globals.push(`const int ${name} = ${num};`);
        if (mode === 'pwm') globals.push(`long ${levelVar(name)} = 0;`);
        if (mode === 'servo') {
          usesServo = true;
          globals.push(`Servo ${servoObj(name)};`, `long ${angleVar(name)} = 0;`);
          setupExtra.push(`  ${servoObj(name)}.attach(${name});`);
        }
      }
    } else if (node.kind === 'Fn') {
      checkName(node.name, node.line);
      funcs.set(node.name, node);
    } else if (node.kind === 'Image') {
      gameOnly("'image'", node.line);
      checkName(node.name, node.line);
      images.set(node.name, node);
      globals.push(`const ${node.name} = __image(${strLit(imageSource(node))}, ${strLit(node.file)});`);
    } else if (node.kind === 'Audio') {
      gameOnly("'audio'", node.line);
      checkName(node.name, node.line);
      audios.set(node.name, node);
      globals.push(`const ${node.name} = __audio([${node.files.map((f) => strLit(soundSource(f, node.line))).join(', ')}], ${strLit(node.name)});`);
    } else if (node.kind === 'Sprite') {
      gameOnly("'sprite'", node.line);
      checkName(node.name, node.line);
      if (!images.has(node.image)) {
        throw new VoltError(`There is no image called '${node.image}'. Load it first, like: image ${node.image} = "tiles.png"`, node.line);
      }
      sprites.set(node.name, node);
      globals.push(`let ${node.name} = null;`);
    } else if (node.kind === 'RawTop') {
      if (!cpp && node.code.startsWith('#')) {
        throw new VoltError(`'${node.code.split(/\s/)[0]}' only works in #c++ programs`, node.line);
      }
      if (html) cssLines.push(node.code);
      else topLines.push(node.code);
      if (node.code.includes('Serial.')) usesSerial = true;
    }
  }
  // Top-level variables (after functions, so 'let x = f(1)' knows f is a function)
  for (const node of ast) {
    if (node.kind !== 'Let' || !node.topLevel) continue;
    checkName(node.name, node.line);
    let type = staticType(node.value);
    if (type === 'bool' || (cpp && type === 'any')) type = 'num';
    if (type === 'list') listsOk(node.line);
    scopes[0].set(node.name, type);
    const empty = type === 'text' ? '""' : type === 'list' ? '[]' : '0';
    if (cpp) globals.push(type === 'text' ? `String ${node.name} = "";` : `long ${node.name} = 0;`);
    else if (js) globals.push(`let ${node.name} = ${empty};`);
    else globals.push(`${global(node.name)} = ${empty}`);
  }

  // ---------- expressions ----------
  // Each returns { code, type } where type is 'num', 'text', 'bool' or 'any' (unknown until it runs).
  // In C++, 'obj' marks a String object (so '+' joins text instead of adding pointers).
  function genExpr(e) {
    switch (e.kind) {
      case 'Number':
        return { code: e.value, type: 'num' };

      case 'Bool':
        if (py) return { code: e.value ? 'True' : 'False', type: 'bool' };
        return { code: String(e.value), type: 'bool' };

      case 'String':
        return { code: strLit(e.value), type: 'text' };

      case 'Uptime':
        if (cpp) return { code: '(long)millis()', type: 'num' };
        if (micro) return { code: 'time.ticks_ms()', type: 'num' };
        if (js) return { code: '(Date.now() - __start)', type: 'num' };
        help('ms');
        return { code: '_ms()', type: 'num' };

      case 'Ask': {
        if (cpp) throw new VoltError("'ask' needs a keyboard, so it doesn't work in #c++. Try #python, #ruby, #js or #html", e.line);
        const q = genExpr(e.prompt).code;
        if (py) return { code: `input(str(${bare(q)}) + " ")`, type: 'text' };
        if (rb) { help('ask'); return { code: `_ask(${bare(q)})`, type: 'text' }; }
        if (!html) help('ask');   // web pages have their own __ask (an in-page question box)
        return { code: `(await __ask(${bare(q)}))`, type: 'text' };
      }

      case 'Var': {
        if (pins.has(e.name)) {
          throw new VoltError(`'${e.name}' is a pin. Use 'read ${e.name}' to get its value`, e.line);
        }
        if (funcs.has(e.name)) {
          throw new VoltError(`'${e.name}' is a function. Call it with ${e.name}(...)`, e.line);
        }
        if (sprites.has(e.name)) throw new VoltError(`'${e.name}' is a sprite. Show it with: draw ${e.name} at x, y`, e.line);
        if (audios.has(e.name)) throw new VoltError(`'${e.name}' is a sound. Play it with: sound ${e.name}`, e.line);
        if (images.has(e.name)) throw new VoltError(`'${e.name}' is an image. Cut sprites out of it with: sprite name = ${e.name} at x, y size w, h`, e.line);
        const v = lookupVar(e.name);
        if (!v) throw new VoltError(`Unknown variable '${e.name}'. Did you forget 'let ${e.name} = ...'?`, e.line);
        return { code: v.top ? global(e.name) : e.name, type: v.type, obj: cpp && v.type === 'text' };
      }

      case 'Read': {
        const p = getPin(e.pin, e.line, null, "'read'");
        const n = e.pin;
        let code;
        switch (p.mode) {
          // Input pins use the pull-up resistor, so "pressed" reads LOW.
          // We flip it so 'read button' is 1 when pressed - more natural.
          case 'input': code = micro ? `(${n}.value() == 0)` : `(digitalRead(${n}) == LOW)`; break;
          case 'output': code = micro ? `${n}.value()` : `digitalRead(${n})`; break;
          // 0-1023 on both targets (MicroPython gives 0-65535, so shift it down)
          case 'analog': code = micro ? `(${n}.read_u16() >> 6)` : `analogRead(${n})`; break;
          case 'pwm': code = levelVar(n); break;
          case 'servo': code = angleVar(n); break;
          // stepper: its angle, 0-359
          case 'stepper':
            code = micro ? `((${posVar(n)} % 4096 * 360 + 2048) // 4096 % 360)` : `(((${posVar(n)} % 4096 + 4096) % 4096 * 360 + 2048) / 4096 % 360)`;
            break;
        }
        return { code, type: 'num' };
      }

      case 'Call':
        return genCall(e);

      // [1, 2, 3]
      case 'List': {
        listsOk(e.line);
        const items = e.items.map((x) => bare(genExpr(x).code));
        return { code: `[${items.join(', ')}]`, type: 'list' };
      }

      // scores[0]     rows[y][x]      (counting starts at 0)
      case 'Index': {
        listsOk(e.line);
        const target = genExpr(e.target);
        if (target.type === 'num' || target.type === 'bool') {
          throw new VoltError("Only lists and text can be read with [ ], like scores[0] or name[0]", e.line);
        }
        const i = genNumber(e.index, "A list position");
        return { code: `${target.code}[${bare(i)}]`, type: target.type === 'text' ? 'text' : 'any' };
      }

      case 'Unary': {
        if (e.op === 'not') {
          const inner = genExpr(e.operand);
          if (py) return { code: `(not ${inner.code})`, type: 'bool' };
          if (rb) return { code: `!${truthy(inner)}`, type: 'bool' };
          return { code: `!(${bare(inner.code)})`, type: 'bool' };
        }
        const inner = genNumber(e.operand, "'-'");
        return { code: `-(${bare(inner)})`, type: 'num' };
      }

      case 'Binary':
        return genBinary(e);

      default:
        throw new Error(`Compiler bug: unknown expression ${e.kind}`);
    }
  }

  // Ruby treats 0 and "" as true, so conditions go through _truthy() unless already true/false
  function truthy(r) {
    if (!rb || r.type === 'bool') return r.code;
    help('truthy');
    return `_truthy(${bare(r.code)})`;
  }
  function genCond(e) {
    return bare(truthy(genExpr(e)));
  }

  function genNumber(e, where) {
    const r = genExpr(e);
    if (r.type === 'text') throw new VoltError(`${where} needs a number, not text. Use number(...) to turn text into a number`, e.line);
    return r.code;
  }

  function genBinary(e) {
    const left = genExpr(e.left);
    const right = genExpr(e.right);
    const L = left.code;
    const R = right.code;
    const anyText = left.type === 'text' || right.type === 'text';
    const anyUnknown = left.type === 'any' || right.type === 'any';

    // Joining text: "Count: " + count
    if (e.op === '+' && anyText) {
      if (js) return { code: `(${L} + ${R})`, type: 'text' };
      if (py) {
        // true/false print as lowercase, like the other languages
        const toStr = (x) => (x.type === 'bool' ? `("true" if ${bare(x.code)} else "false")` : `str(${bare(x.code)})`);
        const l = left.type === 'text' ? L : toStr(left);
        const r = right.type === 'text' ? R : toStr(right);
        return { code: `${l} + ${r}`, type: 'text' };
      }
      if (rb) {
        const l = left.type === 'text' ? L : `(${bare(L)}).to_s`;
        const r = right.type === 'text' ? R : `(${bare(R)}).to_s`;
        return { code: `${l} + ${r}`, type: 'text' };
      }
      // C++: the left side must be a String object so '+' joins instead of adding pointers
      const l = left.obj ? L : `String(${bare(L)})`;
      const r = right.type === 'text' ? R : `String(${bare(R)})`;
      return { code: `${l} + ${r}`, type: 'text', obj: true };
    }

    // '+' where one side's type is only known when the program runs (function results, parameters)
    if (e.op === '+' && anyUnknown && !js) {
      help('add');
      return { code: `_add(${bare(L)}, ${bare(R)})`, type: 'any' };
    }

    if (['and', 'or'].includes(e.op)) {
      if (py) return { code: `(${L} ${e.op} ${R})`, type: 'bool' };
      const op = e.op === 'and' ? '&&' : '||';
      return { code: `(${truthy(left)} ${op} ${truthy(right)})`, type: 'bool' };
    }

    if (['==', '!=', '<', '>', '<=', '>='].includes(e.op)) {
      const textVsNumber = (left.type === 'text' && right.type === 'num') || (left.type === 'num' && right.type === 'text');
      if (textVsNumber && !['==', '!='].includes(e.op)) {
        throw new VoltError(`Can't compare text and a number with '${e.op}'. Use number(...) to turn the text into a number`, e.line);
      }
      let op = e.op;
      if (js && op === '==') op = '===';
      if (js && op === '!=') op = '!==';
      // C++: comparing text needs a String object on the left
      const l = cpp && anyText && !left.obj ? `String(${bare(L)})` : L;
      return { code: `(${l} ${op} ${R})`, type: 'bool' };
    }

    // Arithmetic: - * / %
    if (anyText) {
      throw new VoltError(`Can't use '${e.op}' with text, only with numbers. Use number(...) to turn text into a number`, e.line);
    }
    const type = anyUnknown ? 'any' : 'num';
    if (e.op === '/') {
      // Volt numbers are whole numbers, so division drops the remainder
      if (py) return { code: `(${L} // ${R})`, type };
      if (js) return { code: `Math.trunc(${L} / ${R})`, type };
    }
    return { code: `(${L} ${e.op} ${R})`, type };
  }

  function genCall(e) {
    const args = e.args.map((a) => genExpr(a));

    if (BUILTINS[e.name] !== undefined) {
      const need = BUILTINS[e.name];
      if (args.length !== need) {
        throw new VoltError(`'${e.name}' needs ${need} value${need === 1 ? '' : 's'}, got ${args.length}`, e.line);
      }
      const numeric = ['random', 'abs', 'min', 'max', 'constrain', 'map', 'sign'];
      if (numeric.includes(e.name)) {
        args.forEach((a, i) => {
          if (a.type === 'text') throw new VoltError(`'${e.name}' needs numbers, not text. Use number(...) to turn text into a number`, e.args[i].line);
        });
      }
      const c = args.map((a) => bare(a.code));
      const [a, b, x, d, f] = c;
      switch (e.name) {
        case 'random':
          usesRandom = true;
          if (py) return { code: `random.randint(${a}, ${b})`, type: 'num' };
          if (rb) return { code: `rand((${a})..(${b}))`, type: 'num' };
          if (js) { help('random'); return { code: `__random(${a}, ${b})`, type: 'num' }; }
          return { code: `random(${a}, (${b}) + 1)`, type: 'num' };
        case 'abs':
          if (py) return { code: `abs(${a})`, type: 'num' };
          if (rb) return { code: `(${a}).abs`, type: 'num' };
          if (js) return { code: `Math.abs(${a})`, type: 'num' };
          return { code: `${cppHelper('abs')}(${a})`, type: 'num' };
        case 'min':
        case 'max':
          if (py) return { code: `${e.name}(${a}, ${b})`, type: 'num' };
          if (rb) return { code: `[${a}, ${b}].${e.name}`, type: 'num' };
          if (js) return { code: `Math.${e.name}(${a}, ${b})`, type: 'num' };
          return { code: `${cppHelper(e.name)}(${a}, ${b})`, type: 'num' };
        case 'constrain':
          return { code: clamp(a, b, x), type: 'num' };
        case 'map':
          if (py) return { code: `((${a} - ${b}) * (${f} - ${d}) // (${x} - ${b}) + ${d})`, type: 'num' };
          if (rb) return { code: `((${a} - ${b}) * (${f} - ${d}) / (${x} - ${b}) + ${d})`, type: 'num' };
          if (js) return { code: `(Math.trunc((${a} - ${b}) * (${f} - ${d}) / (${x} - ${b})) + ${d})`, type: 'num' };
          return { code: `map(${a}, ${b}, ${x}, ${d}, ${f})`, type: 'num' };
        case 'number':
          if (args[0].type === 'num') return { code: args[0].code, type: 'num' };
          if (py) { help('num'); return { code: `_num(${a})`, type: 'num' }; }
          if (rb) return { code: `(${a}).to_s.to_i`, type: 'num' };
          if (js) return { code: `(parseInt(${a}, 10) || 0)`, type: 'num' };
          return { code: `String(${a}).toInt()`, type: 'num' };
        case 'text':
          if (py) return { code: `str(${a})`, type: 'text' };
          if (rb) return { code: `(${a}).to_s`, type: 'text' };
          return { code: `String(${a})`, type: 'text', obj: cpp };
        case 'upper':
        case 'lower': {
          if (py) return { code: `str(${a}).${e.name}()`, type: 'text' };
          if (rb) return { code: `(${a}).to_s.${e.name === 'upper' ? 'upcase' : 'downcase'}`, type: 'text' };
          if (js) return { code: `String(${a}).to${e.name === 'upper' ? 'Upper' : 'Lower'}Case()`, type: 'text' };
          return { code: `${cppHelper(e.name)}(String(${a}))`, type: 'text', obj: true };
        }
        case 'contains':
          if (args[0].type === 'list') {
            if (py) return { code: `(${b} in ${a})`, type: 'bool' };
            if (rb) return { code: `${a}.include?(${b})`, type: 'bool' };
            return { code: `${a}.includes(${b})`, type: 'bool' };
          }
          if (args[0].type === 'any' && js) { help('has'); return { code: `__has(${a}, ${b})`, type: 'bool' }; }
          if (py) return { code: `(str(${b}) in str(${a}))`, type: 'bool' };
          if (rb) return { code: `(${a}).to_s.include?((${b}).to_s)`, type: 'bool' };
          if (js) return { code: `String(${a}).includes(String(${b}))`, type: 'bool' };
          return { code: `(String(${a}).indexOf(String(${b})) >= 0)`, type: 'bool' };
        case 'length':
          if (args[0].type === 'list') {
            if (py) return { code: `len(${a})`, type: 'num' };
            return { code: `${a}.length`, type: 'num' };
          }
          if (args[0].type === 'any' && !T.board) {
            // could be a list or text: only known when the program runs
            if (py) return { code: `len(${a} if isinstance(${a}, list) else str(${a}))`, type: 'num' };
            if (rb) return { code: `(${a}.is_a?(Array) ? ${a} : ${a}.to_s).length`, type: 'num' };
            help('len');
            return { code: `__len(${a})`, type: 'num' };
          }
          if (py) return { code: `len(str(${a}))`, type: 'num' };
          if (rb) return { code: `(${a}).to_s.length`, type: 'num' };
          if (js) return { code: `String(${a}).length`, type: 'num' };
          return { code: `String(${a}).length()`, type: 'num' };
        // part("Hello", 1, 3) -> "ell"      (from position 1, 3 letters)
        case 'part':
          if (py) return { code: `str(${a})[${b}:(${b}) + (${x})]`, type: 'text' };
          if (rb) return { code: `((${a}).to_s[${b}, ${x}] || "")`, type: 'text' };
          if (js) return { code: `String(${a}).substr(${b}, ${x})`, type: 'text' };
          return { code: `String(${a}).substring(${b}, (${b}) + (${x}))`, type: 'text', obj: true };
        // sign(x) -> -1, 0 or 1
        case 'sign':
          if (py) return { code: `((${a} > 0) - (${a} < 0))`, type: 'num' };
          if (rb) return { code: `((${a}) <=> 0)`, type: 'num' };
          if (js) return { code: `Math.sign(${a})`, type: 'num' };
          return { code: `(((${a}) > 0) - ((${a}) < 0))`, type: 'num' };
        // saved("best", 0) -> what 'save' stored, or the default      (#html)
        case 'saved':
          gameOnly("'saved'", e.line);
          return { code: `__saved(${a}, ${b})`, type: args[1].type === 'list' ? 'list' : 'any' };
        // held("left") -> true while the key is down      (#html)
        case 'held':
          gameOnly("'held'", e.line);
          return { code: `__held(${a})`, type: 'bool' };
      }
    }

    const fn = funcs.get(e.name);
    if (!fn) {
      if (pins.has(e.name) || lookupVar(e.name)) {
        throw new VoltError(`'${e.name}' is not a function`, e.line);
      }
      throw new VoltError(`Unknown function '${e.name}'. Make it with 'fn ${e.name}(...) { }'`, e.line);
    }
    if (args.length !== fn.params.length) {
      throw new VoltError(`'${e.name}' needs ${fn.params.length} value${fn.params.length === 1 ? '' : 's'}, got ${args.length}`, e.line);
    }
    if (cpp) {
      args.forEach((a, i) => {
        if (a.type === 'text') throw new VoltError("In #c++, functions can only be given numbers, not text", e.args[i].line);
      });
    }
    const call = `${e.name}(${args.map((a) => bare(a.code)).join(', ')})`;
    if (js) return { code: `(await ${call})`, type: 'any' };
    return { code: call, type: cpp ? 'num' : 'any' };
  }

  // ---------- pin output (boards) ----------
  function genSetPin(p, valueCode, depth) {
    const pd = pad(depth);
    const n = p.name;
    switch (p.mode) {
      case 'output':
        return [micro ? `${pd}${n}.value(1 if ${valueCode} else 0)` : `${pd}digitalWrite(${n}, (${valueCode}) ? HIGH : LOW);`];
      case 'pwm':
        return micro
          ? [`${pd}${levelVar(n)} = ${clamp(valueCode, 0, 100)}`, `${pd}${n}.duty_u16(${levelVar(n)} * 65535 // 100)`]
          : [`${pd}${levelVar(n)} = ${clamp(valueCode, 0, 100)};`, `${pd}analogWrite(${n}, ${levelVar(n)} * 255 / 100);`];
      case 'servo':
        return micro
          ? [`${pd}${angleVar(n)} = ${clamp(valueCode, 0, 180)}`, `${pd}${n}.duty_ns(500000 + ${angleVar(n)} * 2000000 // 180)`]
          : [`${pd}${angleVar(n)} = ${clamp(valueCode, 0, 180)};`, `${pd}${servoObj(n)}.write(${angleVar(n)});`];
    }
    throw new Error('Compiler bug: genSetPin');
  }

  // ---------- statements ----------
  // Block syntax for each language
  const open = (depth, header) => {
    if (py) return `${pad(depth)}${header}:`;
    if (rb) return `${pad(depth)}${header}`;
    return `${pad(depth)}${header} {`;
  };
  const close = (depth) => (py ? [] : [`${pad(depth)}${rb ? 'end' : '}'}`]);

  function genBlock(stmts, depth, params = [], paramType = null) {
    scopes.push(new Map(params.map((p) => [p, paramType || (cpp ? 'num' : 'any')])));
    const out = [];
    for (const s of stmts) out.push(...genStmt(s, depth));
    scopes.pop();
    if (py && out.length === 0) out.push(`${pad(depth)}pass`);
    return out;
  }

  function genLoopBlock(stmts, depth) {
    loopDepth++;
    const out = genBlock(stmts, depth);
    loopDepth--;
    return out;
  }

  function checkAssignType(name, varType, valueType, line) {
    if (varType === 'any' || valueType === 'any') return;
    if ((varType === 'list') !== (valueType === 'list')) {
      throw new VoltError(varType === 'list' ? `'${name}' is a list, so it can only be given another list` : `'${name}' isn't a list, so it can't be given one. Make a new variable for the list`, line);
    }
    const isText = (t) => t === 'text';
    if (isText(varType) !== isText(valueType)) {
      throw new VoltError(varType === 'text'
        ? `'${name}' holds text, so it can't be given a number. Use text(...) to turn the number into text`
        : `'${name}' holds a number, so it can't be given text. Use number(...) to turn text into a number`, line);
    }
  }

  function genStmt(s, depth) {
    const p = pad(depth);

    switch (s.kind) {
      case 'Let': {
        const value = genExpr(s.value);
        const code = bare(value.code);
        if (s.topLevel) {
          // already declared in pass 1
          checkAssignType(s.name, scopes[0].get(s.name), value.type, s.line);
          return [`${p}${global(s.name)} = ${code}${END}`];
        }
        checkName(s.name, s.line);
        const type = value.type === 'bool' ? 'num' : value.type;
        scopes[scopes.length - 1].set(s.name, type);
        if (cpp) return [`${p}${type === 'text' ? 'String' : 'long'} ${s.name} = ${code};`];
        if (js) return [`${p}let ${s.name} = ${code};`];
        return [`${p}${s.name} = ${code}`];
      }

      case 'Assign': {
        if (pins.has(s.name)) throw new VoltError(`Can't change pin '${s.name}' with '='. Use set, on, off or toggle`, s.line);
        if (funcs.has(s.name)) throw new VoltError(`Can't change function '${s.name}' with '='`, s.line);
        const v = lookupVar(s.name);
        if (!v) throw new VoltError(`Unknown variable '${s.name}'. Did you mean 'let ${s.name} = ...'?`, s.line);
        const value = genExpr(s.value);
        checkAssignType(s.name, v.type, value.type, s.line);
        return [`${p}${v.top ? global(s.name) : s.name} = ${bare(value.code)}${END}`];
      }

      case 'Write': {
        if (s.action !== 'off' && pins.has(s.pin) && pins.get(s.pin).mode === 'stepper') {
          throw new VoltError(`'${s.action}' doesn't work on a stepper. Use turn ${s.pin} 90, step ${s.pin} 100 or set ${s.pin} to 180`, s.line);
        }
        const pin = getPin(s.pin, s.line, s.action === 'off' ? ['output', 'pwm', 'stepper'] : ['output', 'pwm'], `'${s.action}'`);
        if (pin.mode === 'stepper') {
          // Switch the coils off so the motor and driver don't get warm while resting
          return [micro ? `${p}_stepper_off(${s.pin})` : `${p}__stepper_off(${s.pin});`];
        }
        if (pin.mode === 'pwm') {
          const v = { on: '100', off: '0' }[s.action]
            || (micro ? `(0 if ${levelVar(pin.name)} else 100)` : `(${levelVar(pin.name)} ? 0 : 100)`);
          return genSetPin(pin, v, depth);
        }
        if (micro) {
          if (s.action === 'on') return [`${p}${s.pin}.value(1)`];
          if (s.action === 'off') return [`${p}${s.pin}.value(0)`];
          return [`${p}${s.pin}.value(not ${s.pin}.value())`];
        }
        if (s.action === 'on') return [`${p}digitalWrite(${s.pin}, HIGH);`];
        if (s.action === 'off') return [`${p}digitalWrite(${s.pin}, LOW);`];
        return [`${p}digitalWrite(${s.pin}, !digitalRead(${s.pin}));`];
      }

      case 'Set': {
        const pin = getPin(s.pin, s.line, ['output', 'pwm', 'servo', 'stepper'], "'set'");
        if (pin.mode === 'stepper') {
          // Go to an exact angle, the short way round
          const target = bare(genNumber(s.value, "'set'"));
          const n = s.pin;
          if (micro) return [`${p}${posVar(n)} = _stepper_to(${n}, ${posVar(n)}, ${rpmVar(n)}, ${target})`];
          return [`${p}__stepper_to(${n}, ${posVar(n)}, ${rpmVar(n)}, ${target});`];
        }
        return genSetPin(pin, bare(genNumber(s.value, "'set'")), depth);
      }

      case 'SetSpeed': {
        getPin(s.pin, s.line, ['stepper'], "'set … speed'");
        const v = bare(genNumber(s.value, "'speed'"));
        // 28BYJ-48 motors stall above about 15 turns per minute
        return [`${p}${rpmVar(s.pin)} = ${clamp(v, 1, 15)}${END}`];
      }

      case 'Step':
      case 'Turn': {
        getPin(s.pin, s.line, ['stepper'], `'${s.kind.toLowerCase()}'`);
        const v = bare(genNumber(s.value, `'${s.kind.toLowerCase()}'`));
        const n = s.pin;
        // Volt steps: 2048 per turn. Moved as half-steps (4096 per turn) for smoothness.
        const half = s.kind === 'Step' ? `(${v}) * 2` : (micro ? `round((${v}) * 4096 / 360)` : `__round_div((${v}) * 4096L, 360)`);
        if (micro) return [`${p}${posVar(n)} = _stepper_move(${n}, ${posVar(n)}, ${rpmVar(n)}, ${half})`];
        return [`${p}__stepper_move(${n}, ${posVar(n)}, ${rpmVar(n)}, ${half});`];
      }

      case 'Fade': {
        // Smoothly change brightness in 50 small steps
        const pin = getPin(s.pin, s.line, ['pwm'], "'fade'");
        const n = pin.name;
        const lv = levelVar(n);
        const k = uid++;
        const to = genNumber(s.value, "'fade'");
        const ms = genNumber(s.time, "'fade'");
        if (micro) {
          const [from, goal, step, wait] = [`_from${k}`, `_to${k}`, `_s${k}`, `_ms${k}`];
          return [
            `${p}${from} = ${lv}`,
            `${p}${goal} = ${clamp(to, 0, 100)}`,
            `${p}${wait} = ${ms}`,
            `${p}for ${step} in range(1, 51):`,
            `${pad(depth + 1)}${lv} = ${from} + (${goal} - ${from}) * ${step} // 50`,
            `${pad(depth + 1)}${n}.duty_u16(${lv} * 65535 // 100)`,
            `${pad(depth + 1)}time.sleep_ms(${wait} // 50)`,
          ];
        }
        const [from, goal, step, wait] = [`__from${k}`, `__to${k}`, `__s${k}`, `__ms${k}`];
        return [
          `${p}{`,
          `${p}  long ${from} = ${lv};`,
          `${p}  long ${goal} = ${clamp(to, 0, 100)};`,
          `${p}  long ${wait} = ${ms};`,
          `${p}  for (int ${step} = 1; ${step} <= 50; ${step}++) {`,
          `${p}    ${lv} = ${from} + (${goal} - ${from}) * ${step} / 50;`,
          `${p}    analogWrite(${n}, ${lv} * 255 / 100);`,
          `${p}    delay(${wait} / 50);`,
          `${p}  }`,
          `${p}}`,
        ];
      }

      case 'Tone': {
        if (!s.pin) {
          // tone 440 for 100ms: a beep from the speakers on web pages (doesn't wait)
          if (!html) {
            throw new VoltError(T.board
              ? "On a board, 'tone' needs the buzzer's pin, like: tone buzzer 440 for 200ms"
              : "A 'tone' without a pin only works in #html pages", s.line);
          }
          usesGame = true;
          const f2 = s.toFreq ? bare(genNumber(s.toFreq, "'tone'")) : 'null';
          return [`${p}__beep(${bare(genNumber(s.freq, "'tone'"))}, ${f2}, ${bare(genNumber(s.time, "'tone'"))});`];
        }
        if (s.toFreq) throw new VoltError("Sliding tones ('to') only work in #html pages", s.line);
        getPin(s.pin, s.line, ['output'], "'tone'");
        const freq = genNumber(s.freq, "'tone'");
        const ms = genNumber(s.time, "'tone'");
        const k = uid++;
        if (micro) {
          const pw = `_pw${k}`;
          return [
            `${p}${pw} = PWM(${s.pin}, freq=${freq}, duty_u16=32768)`,
            `${p}time.sleep_ms(${ms})`,
            `${p}${pw}.deinit()`,
            `${p}${s.pin}.init(Pin.OUT)`,
          ];
        }
        return [`${p}{ long __ms${k} = ${ms}; tone(${s.pin}, ${freq}, __ms${k}); delay(__ms${k}); }`];
      }

      case 'Wait': {
        const ms = bare(genNumber(s.time, "'wait'"));
        if (cpp) return [`${p}delay(${ms});`];
        if (micro) return [`${p}time.sleep_ms(${ms})`];
        if (py) return [`${p}time.sleep((${ms}) / 1000)`];
        if (rb) return [`${p}sleep((${ms}) / 1000.0)`];
        return [`${p}await __sleep(${ms});`];
      }

      case 'Print': {
        const printed = genExpr(s.value);
        let value = bare(printed.code);
        if (py && printed.type === 'bool') value = `"true" if ${value} else "false"`;
        if (cpp) { usesSerial = true; return [`${p}Serial.println(${value});`]; }
        if (micro) return [`${p}print(${value})`];
        if (py) return [`${p}print(${value}, flush=True)`];
        if (rb) return [`${p}puts(${value})`];
        if (html) return [`${p}__print(${value});`];
        return [`${p}console.log(${value});`];
      }

      case 'Show': {
        if (!html) return genStmt({ kind: 'Print', value: s.value, line: s.line }, depth);
        return [`${p}__show(${bare(genExpr(s.value).code)});`];
      }

      case 'Clear': {
        if (T.board) throw new VoltError("'clear' doesn't work on boards. It's for scripts and #html pages", s.line);
        if (html) return [`${p}__clear();`];
        if (py) return [`${p}print("\\x1b[2J\\x1b[H", end="", flush=True)`];
        if (rb) return [`${p}print("\\e[2J\\e[H")`];
        return [`${p}process.stdout.write("\\x1b[2J\\x1b[H");`];
      }

      case 'Stop': {
        if (cpp) return [`${p}while (true) { delay(1000); }   // stop`];
        if (py) return [`${p}raise SystemExit`];
        if (rb) return [`${p}exit`];
        if (html) return [`${p}__stop();`];
        return [`${p}process.exit(0);`];
      }

      case 'For': {
        const k = uid++;
        const a = bare(genNumber(s.start, "'for'"));
        const b = bare(genNumber(s.end, "'for'"));
        const v = s.name;
        scopes.push(new Map());
        checkName(v, s.line);
        scopes.pop();
        loopDepth++;
        const bodyLines = genBlock(s.body, depth + 1, [v], 'num');
        loopDepth--;
        // (genBlock gives parameters the type 'any' in scripts; a counter is always a number)
        if (cpp) {
          const [A, B, S] = [`__a${k}`, `__b${k}`, `__s${k}`];
          return [
            `${p}{`,
            `${p}  long ${A} = ${a}, ${B} = ${b}, ${S} = ${A} <= ${B} ? 1 : -1;`,
            `${p}  for (long ${v} = ${A}; ${S} > 0 ? ${v} <= ${B} : ${v} >= ${B}; ${v} += ${S}) {`,
            ...bodyLines.map((l) => `  ${l}`),
            `${p}  }`,
            `${p}}`,
          ];
        }
        if (py) {
          const [A, B] = [`_a${k}`, `_b${k}`];
          return [
            `${p}${A}, ${B} = ${a}, ${b}`,
            `${p}for ${v} in (range(${A}, ${B} + 1) if ${A} <= ${B} else range(${A}, ${B} - 1, -1)):`,
            ...bodyLines,
          ];
        }
        if (rb) {
          const [A, B] = [`_a${k}`, `_b${k}`];
          return [
            `${p}${A}, ${B} = ${a}, ${b}`,
            `${p}${A}.step(${B}, ${A} <= ${B} ? 1 : -1).each do |${v}|`,
            ...bodyLines,
            `${p}end`,
          ];
        }
        const [A, B, S] = [`__a${k}`, `__b${k}`, `__s${k}`];
        return [
          `${p}for (let ${A} = ${a}, ${B} = ${b}, ${S} = ${A} <= ${B} ? 1 : -1, ${v} = ${A}; ${S} > 0 ? ${v} <= ${B} : ${v} >= ${B}; ${v} += ${S}) {`,
          ...bodyLines,
          `${p}}`,
        ];
      }

      case 'Title':
      case 'Html': {
        htmlOnly(`'${s.kind.toLowerCase()}'`, s.line);
        return [`${p}__${s.kind.toLowerCase()}(${bare(genExpr(s.value).code)});`];
      }

      case 'WhenKey': {
        if (!html) {
          throw new VoltError(T.board
            ? "'when key' is for #html pages. On a board, use a button: pin button = 2 input, then when button pressed { }"
            : "'when key' only works in #html pages. Scripts read the keyboard one line at a time with ask", s.line);
        }
        if (!s.key.trim()) throw new VoltError('Put a key name in the quotes, like "k", "space" or "up"', s.line);
        const saved = loopDepth;
        loopDepth = 0;
        const body = genBlock(s.body, depth + 1);
        loopDepth = saved;
        return [`${p}__onKey(${strLit(s.key)}, async () => {`, ...body, `${p}});`];
      }

      case 'Button': {
        htmlOnly("'button'", s.line);
        const label = bare(genExpr(s.label).code);
        const saved = loopDepth;
        loopDepth = 0;
        const body = genBlock(s.body, depth + 1);
        loopDepth = saved;
        return [`${p}__button(${label}, async () => {`, ...body, `${p}});`];
      }

      case 'If': {
        // else-if chains become elif / elsif / else if
        const out = [];
        let node = s;
        let first = true;
        while (node) {
          const cond = genCond(node.cond);
          if (first) out.push(open(depth, py || rb ? `if ${cond}` : `if (${cond})`));
          else if (py) out.push(`${p}elif ${cond}:`);
          else if (rb) out.push(`${p}elsif ${cond}`);
          else out.push(`${p}} else if (${cond}) {`);
          out.push(...genBlock(node.then, depth + 1));
          first = false;
          const other = node.otherwise;
          if (other && other.length === 1 && other[0].kind === 'If') {
            node = other[0];
          } else {
            if (other) {
              out.push(py ? `${p}else:` : rb ? `${p}else` : `${p}} else {`);
              out.push(...genBlock(other, depth + 1));
            }
            node = null;
          }
        }
        out.push(...close(depth));
        return out;
      }

      case 'Repeat': {
        const n = bare(genNumber(s.count, "'repeat'"));
        const i = hidden(`i${uid++}`);
        let header;
        if (cpp) header = `${p}for (long ${i} = 0; ${i} < ${n}; ${i}++) {`;
        else if (js) header = `${p}for (let ${i} = 0; ${i} < ${n}; ${i}++) {`;
        else if (py) header = `${p}for ${i} in range(${n}):`;
        else header = `${p}(${n}).times do`;
        return [header, ...genLoopBlock(s.body, depth + 1), ...close(depth)];
      }

      case 'While': {
        const cond = genCond(s.cond);
        return [open(depth, py || rb ? `while ${cond}` : `while (${cond})`), ...genLoopBlock(s.body, depth + 1), ...close(depth)];
      }

      case 'Break':
        if (loopDepth === 0) throw new VoltError("'break' only works inside 'repeat' or 'while'", s.line);
        return [`${p}break${END}`];

      case 'Return': {
        if (!inFunction) throw new VoltError("'return' only works inside a function (fn)", s.line);
        const value = s.value ? genExpr(s.value) : { code: '0', type: 'num' };
        if (cpp && value.type === 'text') throw new VoltError('In #c++, functions can only return numbers, not text', s.line);
        return [`${p}return ${bare(value.code)}${END}`];
      }

      case 'CallStmt': {
        const call = genCall(s.call).code;
        return [`${p}${js ? `await ${bare(call).replace(/^await /, '')}` : call}${END}`];
      }

      case 'Forever':
        usesForever = true;
        return [`${p}${CMT} forever (line ${s.line})`, ...genBlock(s.body, depth)];

      case 'Every': {
        // A timer checked on every pass of the main loop, so several can run side by side
        const t = hidden(`every${uid++}`);
        if (cpp) {
          globals.push(`unsigned long ${t} = 0;`);
          return [
            `${p}// every ${s.ms}ms (line ${s.line})`,
            open(depth, `if (millis() - ${t} >= ${s.ms}UL)`),
            `${pad(depth + 1)}${t} = millis();`,
            ...genBlock(s.body, depth + 1),
            ...close(depth),
          ];
        }
        if (micro) {
          globals.push(`${t} = 0`);
          return [
            `${p}# every ${s.ms}ms (line ${s.line})`,
            open(depth, `if time.ticks_diff(time.ticks_ms(), ${t}) >= ${s.ms}`),
            `${pad(depth + 1)}${t} = time.ticks_ms()`,
            ...genBlock(s.body, depth + 1),
          ];
        }
        if (js) {
          globals.push(`let ${t} = 0;`);
          return [
            `${p}// every ${s.ms}ms (line ${s.line})`,
            open(depth, `if (Date.now() - ${t} >= ${s.ms})`),
            `${pad(depth + 1)}${t} = Date.now();`,
            ...genBlock(s.body, depth + 1),
            ...close(depth),
          ];
        }
        help('ms');
        const g = global(t);
        globals.push(`${g} = -1000000`);
        return [
          `${p}# every ${s.ms}ms (line ${s.line})`,
          open(depth, `if _ms() - ${g} >= ${s.ms}`),
          `${pad(depth + 1)}${g} = _ms()`,
          ...genBlock(s.body, depth + 1),
          ...close(depth),
        ];
      }

      case 'When': {
        // Debounced button: the reading must stay the same for 30ms before we trust it
        getPin(s.pin, s.line, ['input'], "'when ... pressed'");
        const n = uid++;
        const lastRaw = hidden(`lastRaw${n}`);
        const stable = hidden(`stable${n}`);
        const changedAt = hidden(`changedAt${n}`);
        const p1 = pad(depth + 1);
        const p2 = pad(depth + 2);

        if (micro) {
          const raw = hidden(`raw${n}`);
          globals.push(`${lastRaw} = False`, `${stable} = False`, `${changedAt} = 0`);
          return [
            `${p}# when ${s.pin} pressed (line ${s.line})`,
            `${p}${raw} = (${s.pin}.value() == 0)`,
            `${p}if ${raw} != ${lastRaw}:`,
            `${p1}${lastRaw} = ${raw}`,
            `${p1}${changedAt} = time.ticks_ms()`,
            `${p}if time.ticks_diff(time.ticks_ms(), ${changedAt}) > 30 and ${raw} != ${stable}:`,
            `${p1}${stable} = ${raw}`,
            `${p1}if ${stable}:`,
            ...genBlock(s.body, depth + 2),
          ];
        }

        globals.push(`bool ${lastRaw} = false;`, `bool ${stable} = false;`, `unsigned long ${changedAt} = 0;`);
        return [
          `${p}// when ${s.pin} pressed (line ${s.line})`,
          `${p}{`,
          `${p1}bool raw = (digitalRead(${s.pin}) == LOW);`,
          `${p1}if (raw != ${lastRaw}) { ${lastRaw} = raw; ${changedAt} = millis(); }`,
          `${p1}if (millis() - ${changedAt} > 30 && raw != ${stable}) {`,
          `${p2}${stable} = raw;`,
          `${p2}if (${stable}) {`,
          ...genBlock(s.body, depth + 3),
          `${p2}}`,
          `${p1}}`,
          `${p}}`,
        ];
      }

      // ---------- lists ----------
      case 'IndexAssign': {
        listsOk(s.line);
        const v = lookupVar(s.name);
        if (!v) throw new VoltError(`Unknown list '${s.name}'. Make it first, like: let ${s.name} = []`, s.line);
        if (v.type !== 'list' && v.type !== 'any') throw new VoltError(`'${s.name}' isn't a list, so it can't use [ ]`, s.line);
        const name = v.top ? global(s.name) : s.name;
        const i = bare(genNumber(s.index, 'A list position'));
        return [`${p}${name}[${i}] = ${bare(genExpr(s.value).code)}${END}`];
      }

      case 'ListAdd':
      case 'ListRemove': {
        listsOk(s.line);
        const v = lookupVar(s.list);
        if (!v) throw new VoltError(`Unknown list '${s.list}'. Make it first, like: let ${s.list} = []`, s.line);
        if (v.type !== 'list' && v.type !== 'any') throw new VoltError(`'${s.list}' isn't a list`, s.line);
        const name = v.top ? global(s.list) : s.list;
        if (s.kind === 'ListAdd') {
          const value = bare(genExpr(s.value).code);
          if (py) return [`${p}${name}.append(${value})`];
          return [`${p}${name}.push(${value})${END}`];
        }
        const i = bare(genNumber(s.index, 'A list position'));
        if (py) return [`${p}del ${name}[${i}]`];
        if (rb) return [`${p}${name}.delete_at(${i})`];
        return [`${p}${name}.splice(${i}, 1);`];
      }

      case 'ForEach': {
        listsOk(s.line);
        const list = bare(genExpr(s.list).code);
        scopes.push(new Map());
        checkName(s.name, s.line);
        scopes.pop();
        loopDepth++;
        const body = genBlock(s.body, depth + 1, [s.name], 'any');
        loopDepth--;
        // (loops over a copy, so removing items inside the loop is safe)
        if (py) return [`${p}for ${s.name} in list(${list}):`, ...body];
        if (rb) return [`${p}(${list}).dup.each do |${s.name}|`, ...body, `${p}end`];
        return [`${p}for (const ${s.name} of [...${list}]) {`, ...body, `${p}}`];
      }

      // ---------- games (#html) ----------
      case 'Canvas':
        gameOnly("'canvas'", s.line);
        return [`${p}__canvas(${bare(genNumber(s.w, "'canvas'"))}, ${bare(genNumber(s.h, "'canvas'"))});`];

      case 'Image':
      case 'Audio':
        return [];  // loaded in pass 1

      case 'Sound': {
        gameOnly("'sound'", s.line);
        if (!audios.has(s.name)) throw new VoltError(`There is no sound called '${s.name}'. Load it first, like: audio ${s.name} = "${s.name}.mp3"`, s.line);
        const vol = s.volume ? `, ${bare(genNumber(s.volume, "'volume'"))}` : '';
        return [`${p}__sound(${s.name}${vol});`];
      }

      case 'Volume':
        gameOnly("'volume'", s.line);
        return [`${p}__volume(${bare(genNumber(s.value, "'volume'"))});`];

      case 'Sprite': {
        const n = (e, what) => bare(genNumber(e, `The sprite's ${what}`));
        return [`${p}${s.name} = __sprite(${s.image}, ${n(s.x, 'x')}, ${n(s.y, 'y')}, ${n(s.w, 'width')}, ${n(s.h, 'height')}, ${n(s.frames, 'frames')});`];
      }

      case 'Draw': {
        gameOnly("'draw'", s.line);
        if (!sprites.has(s.sprite)) {
          if (images.has(s.sprite)) throw new VoltError(`'${s.sprite}' is a whole image. Cut a sprite out of it first: sprite name = ${s.sprite} at x, y size w, h`, s.line);
          throw new VoltError(`There is no sprite called '${s.sprite}'. Make it with: sprite ${s.sprite} = image at x, y size w, h`, s.line);
        }
        const o = s.opts;
        const num = (e, what) => (e ? bare(genNumber(e, what)) : 'null');
        const cond = (e) => (e ? genCond(e) : 'false');
        const args = [
          s.sprite, bare(genNumber(s.x, "'draw'")), bare(genNumber(s.y, "'draw'")),
          num(o.frame, "'frame'"), cond(o.flip), num(o.angle, "'angle'"), num(o.size, "'size'"), num(o.alpha, "'alpha'"), cond(o.flash),
          o.tint ? bare(genExpr(o.tint).code) : 'null', String(!!o.glow), num(o.scale, "'scale'"),
        ];
        while (args.length > 3 && (args[args.length - 1] === 'null' || args[args.length - 1] === 'false')) args.pop();
        return [`${p}__draw(${args.join(', ')});`];
      }

      case 'Paint':
        gameOnly("'paint'", s.line);
        return [`${p}__paint(${bare(genExpr(s.color).code)});`];

      case 'Box': {
        gameOnly("'box'", s.line);
        const n = (e) => bare(genNumber(e, "'box'"));
        const color = s.color ? bare(genExpr(s.color).code) : '"#fff"';
        return [`${p}__box(${n(s.x)}, ${n(s.y)}, ${n(s.w)}, ${n(s.h)}, ${color});`];
      }

      case 'WriteText': {
        gameOnly("'write'", s.line);
        const o = s.opts;
        const args = [
          bare(genExpr(s.value).code), bare(genNumber(s.x, "'write'")), bare(genNumber(s.y, "'write'")),
          o.color ? bare(genExpr(o.color).code) : 'null', o.size ? bare(genNumber(o.size, "'size'")) : '1',
          String(!!o.centered), String(!!o.shadow),
        ];
        const defaults = [null, null, null, 'null', '1', 'false', 'false'];
        while (args.length > 3 && args[args.length - 1] === defaults[args.length - 1]) args.pop();
        return [`${p}__write(${args.join(', ')});`];
      }

      case 'Camera':
        gameOnly("'camera'", s.line);
        return [`${p}__camera(${bare(genNumber(s.x, "'camera'"))}, ${bare(genNumber(s.y, "'camera'"))});`];

      case 'Music': {
        gameOnly("'music'", s.line);
        if (!s.melody) return [`${p}__music(null);`];
        const bass = s.bass ? bare(genExpr(s.bass).code) : 'null';
        return [`${p}__music(${bare(genExpr(s.melody).code)}, ${bass}, ${bare(genNumber(s.tempo, "'tempo'"))});`];
      }

      case 'Save':
        gameOnly("'save'", s.line);
        return [`${p}__save(${bare(genExpr(s.key).code)}, ${bare(genExpr(s.value).code)});`];

      case 'Touchpad': {
        gameOnly("'touchpad'", s.line);
        const pic = (f) => strLit(embedFile(f, s.line, MIME, 'a picture', '.png, .jpg, .gif, .webp or .svg'));
        const parts = [];
        if (s.art.stick) {
          parts.push(`pad: ${pic(s.art.stick[0])}`);
          if (s.art.stick[1]) parts.push(`nub: ${pic(s.art.stick[1])}`);
        }
        if (s.art.button) parts.push(`button: ${pic(s.art.button[0])}`);
        if (s.art.icons) parts.push(`icons: [${s.art.icons.map(pic).join(', ')}]`);
        const art = parts.length ? `, { ${parts.join(', ')} }` : '';
        return [`${p}__touchpad([${s.keys.map(strLit).join(', ')}]${art});`];
      }

      case 'EveryFrame': {
        if (!html) {
          throw new VoltError("'every frame' is for #html games. Use a time instead, like: every 20ms { }", s.line);
        }
        usesGame = true;
        const saved = loopDepth;
        loopDepth = 0;
        const body = genBlock(s.body, depth + 1);
        loopDepth = saved;
        return [`${p}// every frame (line ${s.line})`, `${p}__onFrame(async () => {`, ...body, `${p}});`];
      }

      case 'Raw':
        // Volt doesn't check raw code - the language's own compiler or interpreter will
        if (s.code.includes('Serial.')) usesSerial = true;
        return [`${p}${s.code}`];

      case 'Pin':
      case 'RawTop':
      case 'Fn':
        return []; // handled separately

      default:
        throw new Error(`Compiler bug: unknown statement ${s.kind}`);
    }
  }

  // ---------- functions ----------
  // Python functions need 'global' to change top-level variables (and pin levels on boards)
  const pyGlobals = () => [
    ...scopes[0].keys(),
    ...[...pins.values()].filter((q) => q.mode === 'pwm').map((q) => levelVar(q.name)),
    ...[...pins.values()].filter((q) => q.mode === 'servo').map((q) => angleVar(q.name)),
    ...[...pins.values()].filter((q) => q.mode === 'stepper').flatMap((q) => [posVar(q.name), rpmVar(q.name)]),
  ];

  const prototypes = [];
  for (const fn of funcs.values()) {
    for (const param of fn.params) {
      checkName(param, fn.line, true);
      if (fn.params.filter((x) => x === param).length > 1) {
        throw new VoltError(`'${fn.name}' has two parameters called '${param}'`, fn.line);
      }
    }
    inFunction = true;
    const bodyLines = genBlock(fn.body, 1, fn.params);
    inFunction = false;
    const params = fn.params.join(', ');
    const body = py && bodyLines.length === 1 && bodyLines[0].trim() === 'pass' ? [] : bodyLines;

    if (py) {
      const g = pyGlobals().filter((name) => !fn.params.includes(name));
      funcLines.push(`# fn ${fn.name} (line ${fn.line})`, `def ${fn.name}(${params}):`,
        ...(g.length ? [`    global ${g.join(', ')}`] : []), ...body, '    return 0', '');
    } else if (rb) {
      funcLines.push(`# fn ${fn.name} (line ${fn.line})`, `def ${fn.name}(${params})`, ...body, '  return 0', 'end', '');
    } else if (js) {
      funcLines.push(`// fn ${fn.name} (line ${fn.line})`, `async function ${fn.name}(${params}) {`, ...body, '  return 0;', '}', '');
    } else {
      const sig = `long ${fn.name}(${fn.params.map((x) => `long ${x}`).join(', ')})`;
      prototypes.push(`${sig};`);
      funcLines.push(`// fn ${fn.name} (line ${fn.line})`, `${sig} {`, ...body, '  return 0;', '}', '');
    }
  }

  // ---------- pass 2: the main program in source order ----------
  const setupDepth = cpp || js ? 1 : 0;      // Python/Ruby "runs once" code sits at the top level
  const loopBodyDepth = js ? 2 : 1;
  for (const node of ast) {
    if (node.kind === 'Forever' || node.kind === 'Every' || node.kind === 'When') {
      loopLines.push(...genStmt(node, loopBodyDepth));
    } else {
      // Anything outside forever/every/when runs once at the start
      setupLines.push(...genStmt(node, setupDepth));
    }
  }

  // ---------- assemble the final file ----------
  const helperLines = (table) => [...helpers].filter((h) => table[h]).flatMap((h) => table[h]);
  const block = (lines) => (lines.length ? [...lines, ''] : []);

  // C++ (Arduino)
  if (cpp) {
    const includes = [];
    if (usesServo && !topLines.some((l) => /#include\s*<Servo\.h>/.test(l))) includes.push('#include <Servo.h>');
    const pinModes = [...pins.values()]
      .filter((q) => q.mode === 'output' || q.mode === 'pwm' || q.mode === 'input')
      .map((q) => `  pinMode(${q.name}, ${q.mode === 'input' ? 'INPUT_PULLUP' : 'OUTPUT'});`);
    if (usesRandom) setupExtra.push('  randomSeed(analogRead(A0));');
    return [
      '// Generated by Volt. Edit the .volt file, not this one.',
      '',
      ...block([...includes, ...topLines]),
      ...globals,
      '',
      ...block([...[...helpers].filter((h) => CPP_HELPERS[h]).map((h) => CPP_HELPERS[h]), ...(usesStepper ? CPP_STEPPER : []), ...prototypes]),
      ...funcLines,
      'void setup() {',
      ...(usesSerial ? ['  Serial.begin(9600);'] : []),
      ...pinModes,
      ...setupExtra,
      ...setupLines,
      '}',
      '',
      'void loop() {',
      ...loopLines,
      '}',
      '',
    ].join('\n');
  }

  // MicroPython (boards)
  if (micro) {
    const imports = ['from machine import Pin, PWM, ADC', 'import time'];
    if (usesRandom) imports.push('import random');
    return [
      '# Generated by Volt (MicroPython). Edit the .volt file, not this one.',
      ...imports,
      '',
      ...block(topLines),
      ...block([...helperLines(PY_HELPERS), ...(usesStepper ? PY_STEPPER : [])]),
      ...globals,
      '',
      ...funcLines,
      '# ---- runs once ----',
      ...setupLines,
      ...(loopLines.length ? ['', '# ---- runs forever ----', 'while True:', ...loopLines] : []),
      '',
    ].join('\n');
  }

  // Python (desktop)
  if (py) {
    const imports = ['import time'];
    if (usesRandom) imports.push('import random');
    return [
      '# Generated by Volt (Python). Edit the .volt file, not this one.',
      ...imports,
      '',
      ...block(topLines),
      ...block(helperLines(PY_HELPERS)),
      ...block(globals),
      ...funcLines,
      '# ---- runs once ----',
      ...setupLines,
      ...(loopLines.length
        ? ['', '# ---- runs forever ----', 'while True:', ...loopLines, `    time.sleep(${usesForever ? '0.001' : '0.005'})`]
        : []),
      '',
    ].join('\n');
  }

  // Ruby
  if (rb) {
    return [
      '# Generated by Volt (Ruby). Edit the .volt file, not this one.',
      '$stdout.sync = true',
      '',
      ...block(topLines),
      ...block(helperLines(RB_HELPERS)),
      ...block(globals),
      ...funcLines,
      '# ---- runs once ----',
      ...setupLines,
      ...(loopLines.length
        ? ['', '# ---- runs forever ----', 'loop do', ...loopLines, `  sleep(${usesForever ? '0.001' : '0.005'})`, 'end']
        : []),
      '',
    ].join('\n');
  }

  // JavaScript (Node.js) and web pages share the program part
  const program = [
    ...block(helperLines(JS_HELPERS)),
    ...block(globals),
    ...funcLines,
    'async function __main() {',
    ...(images.size ? ['  await Promise.all(__imgs);   // wait for the pictures to load'] : []),
    ...setupLines,
    ...(loopLines.length
      ? ['  // runs forever', '  while (true) {', ...loopLines, `    await __sleep(${usesForever ? 0 : 5});`, '  }']
      : []),
    '}',
  ];

  if (node) {
    return [
      '// Generated by Volt (JavaScript for Node.js). Edit the .volt file, not this one.',
      "'use strict';",
      '',
      ...block(topLines),
      'const __start = Date.now();',
      'const __sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));',
      '',
      ...program,
      '',
      '__main()',
      '  .catch((e) => { console.error(e && e.message ? e.message : e); process.exitCode = 1; })',
      `  .finally(() => { ${helpers.has('ask') ? '__rl.close(); ' : ''}});`,
      '',
    ].join('\n');
  }

  // Web page
  return [
    '<!doctype html>',
    '<!-- Generated by Volt. Edit the .volt file, not this one. -->',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>Volt page</title>',
    '<style>',
    HTML_CSS,
    ...(usesGame ? [GAME_CSS] : []),
    ...(cssLines.length ? ['  /* your CSS (## lines) */', ...cssLines.map((l) => `  ${l}`)] : []),
    '</style>',
    '</head>',
    '<body>',
    '<main id="volt"></main>',
    '<script>',
    "'use strict';",
    "const __out = document.getElementById('volt');",
    'const __start = Date.now();',
    "const __sleep = (ms) => new Promise((resolve, reject) => setTimeout(() => (__stopped ? reject(__STOP) : resolve()), ms));",
    "function __add(el) { __out.appendChild(el); return el; }",
    "function __print(v) { const d = document.createElement('div'); d.className = 'volt-line'; d.textContent = String(v); __add(d); }",
    "function __html(v) { const d = document.createElement('div'); d.className = 'volt-html'; d.innerHTML = String(v); __add(d); }",
    "let __showEl = null;",
    "function __show(v) { if (!__showEl) { __showEl = document.createElement('div'); __showEl.className = 'volt-show'; __add(__showEl); } __showEl.textContent = String(v); }",
    "function __clear() { __out.querySelectorAll('.volt-line, .volt-html, .volt-answer, .volt-error').forEach((el) => el.remove()); }",
    "let __stopped = false;",
    "const __STOP = { stop: true };",
    "function __stop() { __stopped = true; throw __STOP; }",
    "function __title(v) { document.title = String(v); const h = document.createElement('h1'); h.textContent = String(v); __add(h); }",
    "function __error(e) { if (e === __STOP) return; console.error(e); const d = document.createElement('div'); d.className = 'volt-error'; d.textContent = 'Error: ' + (e && e.message ? e.message : e); __add(d); }",
    '// Key presses: "k", "space", "up", "enter" ... ("any" means every key)',
    "const __keys = [];",
    "const __keyNames = { space: ' ', spacebar: ' ', up: 'arrowup', down: 'arrowdown', left: 'arrowleft', right: 'arrowright', esc: 'escape', return: 'enter' };",
    "function __onKey(name, fn) { const k = String(name).toLowerCase(); __keys.push({ key: __keyNames[k] || k, fn }); }",
    "document.addEventListener('keydown', (e) => {",
    "  if (e.repeat || /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;",
    "  const pressed = e.key.toLowerCase();",
    "  const hits = __keys.filter((h) => h.key === pressed || h.key === 'any');",
    "  if (hits.length && (pressed === ' ' || pressed.startsWith('arrow'))) e.preventDefault();",
    "  if (__stopped) return;",
    "  hits.forEach((h) => h.fn().catch(__error));",
    "});",
    "function __button(label, fn) { const b = document.createElement('button'); b.textContent = String(label); b.onclick = () => { if (!__stopped) fn().catch(__error); }; __add(b); }",
    'function __ask(q) {',
    '  return new Promise((resolve) => {',
    "    const f = document.createElement('form'); f.className = 'volt-ask';",
    "    const l = document.createElement('label'); l.textContent = String(q);",
    "    const i = document.createElement('input'); i.autocomplete = 'off';",
    "    const b = document.createElement('button'); b.textContent = 'OK';",
    '    f.append(l, i, b);',
    "    f.onsubmit = (e) => { e.preventDefault(); const d = document.createElement('div'); d.className = 'volt-line volt-answer'; d.textContent = String(q) + ' ' + i.value; f.replaceWith(d); resolve(i.value); };",
    '    __add(f); i.focus();',
    '  });',
    '}',
    ...(usesGame ? GAME_RUNTIME : []),
    ...block(topLines),
    ...program,
    '',
    '__main().catch(__error);',
    '</script>',
    '</body>',
    '</html>',
    '',
  ].join('\n');
}

// =====================================================================
//  Putting it together
// =====================================================================

// The first real line picks the output language: #c++, #python, #ruby, #js, #html ...
function detectTarget(src) {
  const lines = src.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const text = lines[i].trim();
    if (text === '' || text.startsWith('//')) continue;    // skip blank lines and comments

    const m = text.match(/^#(\S+)$/);
    if (!m) break;                                         // first line is normal code
    const name = m[1].toLowerCase();
    if (/^(include|define|ifdef|ifndef|endif|pragma|undef)$/.test(name)) break;   // C++ directive
    if (name === 'css') {
      throw new VoltError('CSS goes inside a web page: start the file with #html and put your CSS on ## lines', i + 1);
    }
    if (!TARGET_NAMES[name]) {
      throw new VoltError(`Volt can't make '${m[1]}' yet. Use #c++, #micropython, #python, #ruby, #js or #html`, i + 1);
    }
    lines[i] = '';                                         // blank it out, keeping line numbers
    return { target: TARGET_NAMES[name], src: lines.join('\n') };
  }
  return { target: 'cpp', src };
}

// options.baseDir: the .volt file's folder, so 'image' can pack pictures into the page
function compile(source, options = {}) {
  const detected = detectTarget(source.replace(/\r\n?/g, '\n'));
  const tokens = lex(detected.src);
  const ast = parse(tokens);
  // #python means a board (MicroPython) when the program uses pins, otherwise a normal script
  let target = detected.target;
  if (target === 'python?') target = ast.some((n) => n.kind === 'Pin') ? 'micropython' : 'python';
  if (EXTRA_GENERATORS[target]) return { target, code: EXTRA_GENERATORS[target](ast) };
  return { target, code: generate(ast, target, options) };
}

// Where the compiled file goes for a given .volt file
function outputPath(voltFile, target) {
  const name = path.basename(voltFile, path.extname(voltFile));
  const outDir = path.join(path.dirname(voltFile), name);
  const t = TARGETS[target] || TARGETS.cpp;
  return { outDir, outFile: path.join(outDir, t.file(name)) };
}

const HINTS = {
  cpp: 'Arduino: open it in the Arduino IDE',
  micropython: 'MicroPython: copy main.py to your board',
  python: 'run it with: python',
  ruby: 'run it with: ruby',
  js: 'run it with: node',
  html: 'open it in a web browser',
};

function main() {
  const file = process.argv[2];
  if (!file || file === '--help' || file === '-h') {
    console.log(`Volt ${VERSION}\nUsage: node volt.js <program.volt>`);
    process.exit(file ? 0 : 1);
  }

  if (!fs.existsSync(file)) {
    console.error(`Can't find '${file}' in ${path.resolve(path.dirname(file))}`);
    if (fs.existsSync(file + '.txt')) {
      console.error(`Found '${file}.txt' instead. Your editor added .txt - rename it to '${path.basename(file)}'.`);
    } else if (fs.existsSync(path.join('..', path.basename(file)))) {
      console.error(`It's in the folder one level up. Move it here, or run: node volt.js ..${path.sep}${path.basename(file)}`);
    } else {
      console.error('Check the spelling, and make sure the file is in this folder.');
    }
    process.exit(1);
  }

  const src = fs.readFileSync(file, 'utf8');
  try {
    const { target, code } = compile(src, { baseDir: path.dirname(path.resolve(file)) });
    const { outDir, outFile } = outputPath(file, target);
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(outFile, code);
    console.log(`Compiled ${file} -> ${outFile}  (${HINTS[target] || 'see the addon that provides this target'})`);
  } catch (e) {
    if (e instanceof VoltError) {
      console.error(`${file}, line ${e.line}: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
}

module.exports = { VERSION, lex, parse, generate, compile, outputPath, VoltError, KEYWORDS, BUILTINS, TARGETS, registerTarget };
if (require.main === module) main();
