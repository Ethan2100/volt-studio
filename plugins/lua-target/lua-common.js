// =====================================================================
// Shared codegen engine for the #lua and #luau target addons.
//
// Both targets compile the SAME Lua-family language (Luau is a superset
// of Lua 5.1-ish syntax), so nearly everything - variables, functions,
// if/while/for/repeat, lists, the built-in functions (random, contains,
// length, ...) - is identical between them. This file implements all of
// that once; generate.js in plugins/lua-target and plugins/luau-target
// are thin wrappers that call generate(ast, { luau: false|true }).
//
// Design notes (see docs/PLUGINS.md for the AST shape this walks):
//
// - Volt lists are 0-indexed (scores[0] is the first item); Lua tables
//   are 1-indexed. Every list op (Index, IndexAssign, ListAdd, ListRemove)
//   converts with +1 at the point of use, rather than trying to keep a
//   whole shadow "0-indexed table" convention.
//
// - Volt's '+' operator does text-or-number concatenation depending on
//   the VALUES at runtime (join if either side is text, add otherwise) -
//   the built-in C++/Python/Ruby/JS generators work this out with a real
//   static type-checker. An addon target doesn't get that checker, so
//   instead of rebuilding one, '+' always compiles to a tiny runtime
//   helper (__add) that asks Lua's own type() at runtime. Same trick for
//   length()/contains() (list vs text) and for list/string indexing - it
//   is simpler and just as correct as static inference for a dynamically
//   typed target language like Lua.
//
// - Forward references: Lua closures capture a `local` as an upvalue at
//   the moment a function literal is created, not by name lookup later -
//   so if function A is defined (and thus closes over its upvalues)
//   before variable or function B exists as a local, A's use of B
//   silently binds to a global (usually nil) instead. To avoid that, every
//   top-level `let` and `fn` name is forward-declared as a bare `local`
//   first (so every function is a valid upvalue to every other, in any
//   order), and only then does a second pass fill in the actual values/
//   bodies, in the program's own source order (so a `let` that calls a
//   function still runs after that function's body has been assigned).
// =====================================================================

const path = require('path');
const { VoltError, BUILTINS } = require(path.join(__dirname, '..', '..', 'compiler', 'volt.js'));

const LUA_RESERVED = new Set([
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
  'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true',
  'until', 'while',
  // Luau adds a couple of contextual/soft keywords worth steering clear of too
  'continue', 'type', 'export',
]);

// Node kinds that only make sense on hardware (#c++/#micropython) or in a
// browser page (#html) - rejected with a message pointing somewhere useful,
// the same way the built-in compiler rejects e.g. 'ask' inside #c++.
const HARDWARE_KINDS = new Set(['Pin', 'Write', 'SetSpeed', 'Set', 'Fade', 'Tone', 'When', 'WhenKey']);
const WEB_KINDS = new Set([
  'Button', 'Title', 'Html', 'Canvas', 'Image', 'Audio', 'Sprite', 'Draw',
  'Box', 'Paint', 'WriteText', 'Camera', 'Touchpad', 'Volume', 'Sound',
  'Music', 'Save', 'EveryFrame',
]);
const WEB_ONLY_BUILTINS = new Set(['held', 'saved', 'touchscreen']);

function generate(ast, opts) {
  opts = opts || {};
  const luau = !!opts.luau;
  const self = luau ? '#luau' : '#lua';
  const hint = luau
    ? "Try #lua for a plain script, or #c++/#python/#ruby/#js/#html for hardware/web programs."
    : "Try #luau for Roblox, or #c++/#python/#ruby/#js/#html for hardware/web programs.";

  let uid = 0;
  const usedHelpers = new Set();
  const extraGlobals = [];   // hoisted 'local __everyN = ...' lines for Every/timers
  let usesRandom = false;

  function need(name) {
    if (usedHelpers.has(name)) return;
    usedHelpers.add(name);
    if (name === 'add' || name === 'contains' || name === 'len' || name === 'part' || name === 'ask') need('tostr');
    if (name === 'map') need('idiv');
  }
  function hidden(base) { return `__${base}${uid++}`; }
  function safeName(name) { return LUA_RESERVED.has(name) ? name + '_' : name; }
  function unsupported(what, line) {
    throw new VoltError(`'${what}' doesn't work in ${self} programs. ${hint}`, line);
  }

  function pad(depth) { return '  '.repeat(depth); }

  // ----------------------------- expressions ------------------------------
  function luaStringLit(s) {
    let out = '"';
    for (const ch of s) {
      if (ch === '\\') out += '\\\\';
      else if (ch === '"') out += '\\"';
      else if (ch === '\n') out += '\\n';
      else if (ch === '\r') out += '\\r';
      else if (ch === '\t') out += '\\t';
      else if (ch === '\0') out += '\\0';
      else out += ch;
    }
    return out + '"';
  }

  function expr(e) {
    switch (e.kind) {
      case 'Number': return e.value;
      case 'String': return luaStringLit(e.value);
      case 'Bool': return e.value ? 'true' : 'false';
      case 'Var': return safeName(e.name);
      case 'Uptime': return '(os.clock() * 1000)';
      case 'Ask': {
        if (luau) unsupported("ask (a Roblox script has no keyboard to read - use UserInputService via raw code instead)", e.line);
        need('ask');
        return `__ask(${expr(e.prompt)})`;
      }
      case 'Read':
        unsupported('read', e.line);
        return '';
      case 'Call':
        return call(e);
      case 'List':
        return `{${e.items.map(expr).join(', ')}}`;
      case 'Index': {
        need('index');
        return `__index(${expr(e.target)}, ${expr(e.index)})`;
      }
      case 'Unary':
        if (e.op === 'not') return `(not ${expr(e.operand)})`;
        return `(-(${expr(e.operand)}))`;
      case 'Binary':
        return binary(e);
      default:
        throw new VoltError(`The ${self} target doesn't support '${e.kind}' yet`, e.line);
    }
  }

  function binary(e) {
    const L = expr(e.left);
    const R = expr(e.right);
    if (e.op === '+') { need('add'); return `__add(${L}, ${R})`; }
    if (e.op === 'and' || e.op === 'or') return `(${L} ${e.op} ${R})`;
    if (e.op === '==') return `(${L} == ${R})`;
    if (e.op === '!=') return `(${L} ~= ${R})`;
    if (['<', '>', '<=', '>='].includes(e.op)) return `(${L} ${e.op} ${R})`;
    if (e.op === '/') { need('idiv'); return `__idiv(${L}, ${R})`; }
    if (e.op === '%') { need('mod'); return `__mod(${L}, ${R})`; }
    // '-' and '*'
    return `(${L} ${e.op} ${R})`;
  }

  function call(e) {
    const name = e.name;
    if (BUILTINS[name] !== undefined) {
      const want = BUILTINS[name];
      if (e.args.length !== want) {
        throw new VoltError(`'${name}' needs ${want} value${want === 1 ? '' : 's'}, got ${e.args.length}`, e.line);
      }
      if (WEB_ONLY_BUILTINS.has(name)) unsupported(`${name}() (that's for #html pages)`, e.line);
      const a = e.args.map(expr);
      switch (name) {
        case 'random': usesRandom = true; return `math.random(${a[0]}, ${a[1]})`;
        case 'abs': return `math.abs(${a[0]})`;
        case 'min': return `math.min(${a[0]}, ${a[1]})`;
        case 'max': return `math.max(${a[0]}, ${a[1]})`;
        case 'constrain': need('constrain'); return `__constrain(${a[0]}, ${a[1]}, ${a[2]})`;
        case 'map': need('map'); return `__map(${a[0]}, ${a[1]}, ${a[2]}, ${a[3]}, ${a[4]})`;
        case 'number': need('tonum'); return `__tonum(${a[0]})`;
        case 'text': need('tostr'); return `__tostr(${a[0]})`;
        case 'upper': need('tostr'); return `string.upper(__tostr(${a[0]}))`;
        case 'lower': need('tostr'); return `string.lower(__tostr(${a[0]}))`;
        case 'contains': need('contains'); return `__contains(${a[0]}, ${a[1]})`;
        case 'length': need('len'); return `__len(${a[0]})`;
        case 'part': need('part'); return `__part(${a[0]}, ${a[1]}, ${a[2]})`;
        case 'sign': need('sign'); return `__sign(${a[0]})`;
      }
    }
    const args = e.args.map(expr).join(', ');
    return `${safeName(name)}(${args})`;
  }

  // ------------------------------ statements -------------------------------
  function block(stmts, depth) {
    if (!stmts || stmts.length === 0) return [];
    const out = [];
    for (const s of stmts) out.push(...stmt(s, depth));
    return out;
  }

  function stmt(s, depth) {
    const p = pad(depth);
    if (HARDWARE_KINDS.has(s.kind)) unsupported(s.kind.toLowerCase(), s.line);
    if (WEB_KINDS.has(s.kind)) unsupported(s.kind.toLowerCase(), s.line);

    switch (s.kind) {
      case 'Let':
        return [`${p}local ${safeName(s.name)} = ${expr(s.value)}`];

      case 'Assign':
        return [`${p}${safeName(s.name)} = ${expr(s.value)}`];

      case 'IndexAssign':
        return [`${p}${safeName(s.name)}[(${expr(s.index)}) + 1] = ${expr(s.value)}`];

      case 'ListAdd':
        return [`${p}table.insert(${safeName(s.list)}, ${expr(s.value)})`];

      case 'ListRemove':
        return [`${p}table.remove(${safeName(s.list)}, (${expr(s.index)}) + 1)`];

      case 'ForEach': {
        const v = safeName(s.name);
        const listVar = hidden('each');
        need('copylist');
        return [
          `${p}local ${listVar} = __copylist(${expr(s.list)})`,   // iterate a snapshot, like the built-in targets
          `${p}for _, ${v} in ipairs(${listVar}) do`,
          ...block(s.body, depth + 1),
          `${p}end`,
        ];
      }

      case 'Fn':
        // Only reachable for a nested fn (top-level Fn is handled in generate()).
        return [`${p}local function ${safeName(s.name)}(${s.params.map(safeName).join(', ')})`, ...block(s.body, depth + 1), `${p}end`];

      case 'Return':
        return [`${p}return${s.value ? ' ' + expr(s.value) : ''}`];

      case 'Forever':
        return [`${p}while true do`, ...block(s.body, depth + 1), `${p}end`];

      case 'Repeat': {
        const n = hidden('n');
        return [
          `${p}local ${n} = ${expr(s.count)}`,
          `${p}for __i = 1, ${n} do`,
          ...block(s.body, depth + 1),
          `${p}end`,
        ];
      }

      case 'While':
        return [`${p}while ${expr(s.cond)} do`, ...block(s.body, depth + 1), `${p}end`];

      case 'For': {
        const a = hidden('a');
        const b = hidden('b');
        const st = hidden('s');
        const v = safeName(s.name);
        return [
          `${p}local ${a}, ${b} = ${expr(s.start)}, ${expr(s.end)}`,
          `${p}local ${st} = (${a} <= ${b}) and 1 or -1`,
          `${p}for ${v} = ${a}, ${b}, ${st} do`,
          ...block(s.body, depth + 1),
          `${p}end`,
        ];
      }

      case 'Break':
        return [`${p}break`];

      case 'If': {
        const lines = [`${p}if ${expr(s.cond)} then`, ...block(s.then, depth + 1)];
        if (s.otherwise) {
          lines.push(`${p}else`, ...block(s.otherwise, depth + 1));
        }
        lines.push(`${p}end`);
        return lines;
      }

      case 'CallStmt':
        return [`${p}${expr(s.call)}`];

      case 'Raw':
      case 'RawTop':
        return [`${p}${s.code}`];

      case 'Print':
      case 'Show':
        return [`${p}print(${expr(s.value)})`];

      case 'Clear':
        return luau ? [] : [`${p}io.write("\\27[2J\\27[H")`];

      case 'Stop':
        return luau ? [`${p}return`] : [`${p}os.exit(0)`];

      case 'Wait': {
        const ms = expr(s.time);
        if (luau) return [`${p}task.wait((${ms}) / 1000)`];
        need('sleep');
        return [`${p}__sleep(${ms})`];
      }

      case 'Every': {
        // A timer re-checked every time control reaches this line (so it's
        // normally nested inside a 'forever' loop) - never blocks on its own.
        const t = hidden('every');
        extraGlobals.push(`local ${t} = -1e9`);
        return [
          `${p}-- every ${s.ms}ms (line ${s.line})`,
          `${p}if (os.clock() * 1000) - ${t} >= ${s.ms} then`,
          `${pad(depth + 1)}${t} = os.clock() * 1000`,
          ...block(s.body, depth + 1),
          `${p}end`,
        ];
      }

      default:
        throw new VoltError(`The ${self} target doesn't support '${s.kind}' yet`, s.line);
    }
  }

  // ------------------------------- helpers ---------------------------------
  const HELPER_SRC = {
    tostr: [
      'local function __tostr(v)',
      '  if type(v) == "boolean" then return v and "true" or "false" end',
      '  return tostring(v)',
      'end',
    ],
    add: [
      'local function __add(a, b)',
      '  if type(a) == "string" or type(b) == "string" then',
      '    return __tostr(a) .. __tostr(b)',
      '  end',
      '  return a + b',
      'end',
    ],
    idiv: [
      'local function __idiv(a, b)',
      '  local q = a / b',
      '  if q >= 0 then return math.floor(q) end',
      '  return math.ceil(q)',
      'end',
    ],
    mod: [
      'local function __mod(a, b)',
      '  local r = a % b',
      '  if r ~= 0 and (r < 0) ~= (a < 0) then r = r - b end',
      '  return r',
      'end',
    ],
    index: [
      'local function __index(t, i)',
      '  if type(t) == "string" then return string.sub(t, i + 1, i + 1) end',
      '  return t[i + 1]',
      'end',
    ],
    contains: [
      'local function __contains(a, b)',
      '  if type(a) == "table" then',
      '    for _, v in ipairs(a) do if v == b then return true end end',
      '    return false',
      '  end',
      '  return string.find(__tostr(a), __tostr(b), 1, true) ~= nil',
      'end',
    ],
    len: [
      'local function __len(a)',
      '  if type(a) == "table" then return #a end',
      '  return string.len(__tostr(a))',
      'end',
    ],
    part: [
      'local function __part(s, start, count)',
      '  s = __tostr(s)',
      '  return string.sub(s, start + 1, start + count)',
      'end',
    ],
    tonum: [
      'local function __tonum(v)',
      '  if type(v) == "number" then return v end',
      '  return tonumber(v) or 0',
      'end',
    ],
    sign: [
      'local function __sign(n)',
      '  if n > 0 then return 1 elseif n < 0 then return -1 else return 0 end',
      'end',
    ],
    constrain: [
      'local function __constrain(v, lo, hi)',
      '  if v < lo then return lo elseif v > hi then return hi else return v end',
      'end',
    ],
    map: [
      'local function __map(x, a, b, c, d)',
      '  return __idiv((x - a) * (d - c), (b - a)) + c',
      'end',
    ],
    sleep: [
      // Plain Lua has no portable sleep in the standard library - this is a
      // CPU-spinning wait, fine for scripts/game logic, not for tight timing.
      'local function __sleep(ms)',
      '  local target = os.clock() + (ms / 1000)',
      '  while os.clock() < target do end',
      'end',
    ],
    ask: [
      'local function __ask(prompt)',
      '  io.write(__tostr(prompt), " ")',
      '  io.flush()',
      '  return io.read("l") or ""',
      'end',
    ],
    copylist: [
      'local function __copylist(t)',
      '  local out = {}',
      '  for i, v in ipairs(t) do out[i] = v end',
      '  return out',
      'end',
    ],
  };
  // Emit in an order where every helper's own dependencies come first.
  const HELPER_ORDER = ['tostr', 'add', 'idiv', 'mod', 'index', 'contains', 'len', 'part', 'tonum', 'sign', 'constrain', 'map', 'sleep', 'ask', 'copylist'];

  // --------------------------------- top level ------------------------------
  function topLevelName(n) {
    if (n.kind === 'Let' && n.topLevel) return n.name;
    if (n.kind === 'Fn') return n.name;
    return null;
  }

  function generateProgram() {
    // Reject anything hardware/web-only right away, even before the two-pass
    // emission below, so the error points at the real offending line.
    const scan = (nodes) => {
      for (const n of nodes) {
        if (HARDWARE_KINDS.has(n.kind) || WEB_KINDS.has(n.kind)) unsupported(n.kind.toLowerCase(), n.line);
        if (n.body) scan(n.body);
        if (n.then) scan(n.then);
        if (n.otherwise) scan(n.otherwise);
      }
    };
    scan(ast);

    // Phase 1: forward-declare every top-level let/fn name as a bare local,
    // so every function is a valid upvalue to every other regardless of order.
    const names = ast.map(topLevelName).filter(Boolean).map(safeName);
    const forwardDecl = names.length ? [`local ${names.join(', ')}`] : [];

    // Phase 2: fill in values/bodies, in the program's own order; anything
    // that isn't a top-level let/fn (raw lines, the actual "start" code -
    // calls, a forever loop, etc.) is emitted in place via the normal stmt().
    const body = [];
    for (const n of ast) {
      if (n.kind === 'Let' && n.topLevel) {
        body.push(`${safeName(n.name)} = ${expr(n.value)}`);
      } else if (n.kind === 'Fn') {
        body.push(`${safeName(n.name)} = function(${n.params.map(safeName).join(', ')})`, ...block(n.body, 1), `end`);
      } else if (n.kind === 'RawTop') {
        body.push(...n.code.split('\n'));
      } else {
        body.push(...stmt(n, 0));
      }
    }

    const helperLines = HELPER_ORDER.filter((h) => usedHelpers.has(h)).flatMap((h) => HELPER_SRC[h]);
    const preamble = [];
    if (usesRandom) preamble.push('math.randomseed(math.floor(os.clock() * 1000000))');

    const header = luau
      ? [
          '-- Compiled from Volt (#luau target) - https://github.com/Ethan2100/volt-studio',
          '-- Logic (variables, functions, if/while/for, lists) is plain Volt, compiled to',
          "-- real Luau. Anything Roblox-specific - Instance.new, game:GetService(...),",
          "-- CFrame/Vector3, :Connect(...) events - comes from this file's own # / ##",
          '-- raw-code lines, same escape hatch Volt uses for Arduino-only C++ calls.',
        ]
      : [
          '-- Compiled from Volt (#lua target) - https://github.com/Ethan2100/volt-studio',
          '-- Run with: lua thisfile.lua',
        ];

    const sections = [header, helperLines, extraGlobals, preamble, forwardDecl, body].filter((s) => s.length);
    return sections.map((s) => s.join('\n')).join('\n\n') + '\n';
  }

  return generateProgram();
}

module.exports = { generate };
