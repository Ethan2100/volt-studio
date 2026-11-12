// =====================================================================
//  Instruction list -> Minecraft commands.
//
//  The machine is the scoreboard. One objective, `volt`, holds every
//  register: #pc is the program counter, one holder per variable, #t0..
//  for working space. Running the tick function once runs exactly one
//  instruction of the program, so Minecraft's own game loop is the clock.
//
//  Every command is guarded by the program counter:
//
//      execute if score #pc volt matches 7 run scoreboard players ...
//
//  so the whole program is one flat function and only the lines belonging
//  to the current instruction do anything on a given tick. The next
//  counter value is worked out into #npc and only copied into #pc at the
//  very end - otherwise a jump would land on a later instruction's lines
//  and run them in the same tick.
//
//  Scoreboards hold whole numbers and nothing else, so text exists only
//  at the moment it is printed, as tellraw components.
// =====================================================================

const { CompileError } = require('./lower');

const OBJ = 'volt';
const PC = '#pc', NPC = '#npc';

// --- types ------------------------------------------------------------
// Only three: a whole number, a true/false, or text. Text can never be
// stored, so it only has to survive long enough to reach a tellraw.
const BOOL_OPS = new Set(['==', '!=', '<', '>', '<=', '>=', '&&', '||']);

function inferTypes(prog, vars) {
  const t = new Map(vars.map((v) => [v, null]));
  const join = (a, b) => (a === null ? b : b === null ? a : a === b ? a : 'any');

  const typeOf = (n) => {
    switch (n.kind) {
      case 'String': return 'text';
      case 'Number': return 'num';
      case 'Bool': return 'bool';
      case 'Var': return t.get(n.name) ?? null;
      case 'Unary': return n.op === '!' ? 'bool' : 'num';
      case 'Call': return n.name === 'contains' ? 'bool' : 'num';
      case 'Binary': {
        if (BOOL_OPS.has(n.op)) return 'bool';
        if (n.op !== '+') return 'num';
        const a = typeOf(n.left), b = typeOf(n.right);
        if (a === 'text' || b === 'text') return 'text';
        if (a === null || b === null) return null;
        if (a === 'any' || b === 'any') return 'any';
        return 'num';
      }
      default: return 'any';
    }
  };

  for (let pass = 0; pass < vars.length + 3; pass++) {
    let changed = false;
    for (const ins of prog) {
      if (ins.op !== 'SET' || ins.init) continue;
      const merged = join(t.get(ins.name), typeOf(ins.expr));
      if (merged !== t.get(ins.name)) { t.set(ins.name, merged); changed = true; }
    }
    if (!changed) break;
  }
  for (const v of vars) if (t.get(v) === null) t.set(v, 'num');
  return { types: t, typeOf };
}

const json = (s) => JSON.stringify(String(s));

function emit({ prog, vars }, opts = {}) {
  const ns = opts.namespace || 'volt';
  const { types, typeOf } = inferTypes(prog, vars);

  // A variable that would have to hold text has nowhere to live.
  for (const v of vars) {
    if (types.get(v) === 'text' || types.get(v) === 'any') {
      if (v.startsWith('__')) {
        throw new CompileError(
          `A function returns text, and a scoreboard holds only whole numbers. ` +
          `In the #minecraft target text can be printed but not stored.`);
      }
      throw new CompileError(
        `'${v}' would have to hold text, and a scoreboard holds only whole numbers. ` +
        `In the #minecraft target text can be printed but not stored.`);
    }
  }

  const reg = (name) => `#${name}`;
  const lines = [];
  let maxTemp = 0;

  // Each emitted command is gated on the program counter, plus whatever
  // extra conditions the instruction itself needs.
  const makeEmitter = (pc) => (conds, cmd) =>
    lines.push(`execute if score ${PC} ${OBJ} matches ${pc}${conds.map((c) => ' ' + c).join('')} run ${cmd}`);

  // ---------------------------------------------------------------
  //  Expressions. Each one leaves its result in a register and
  //  returns that register's name.
  // ---------------------------------------------------------------
  function makeExpr(em) {
    let n = 0;
    const alloc = () => { const r = `#t${n++}`; if (n > maxTemp) maxTemp = n; return r; };
    const set = (r, v) => em([], `scoreboard players set ${r} ${OBJ} ${v}`);
    const mov = (d, s) => em([], `scoreboard players operation ${d} ${OBJ} = ${s} ${OBJ}`);
    const op  = (d, o, s) => em([], `scoreboard players operation ${d} ${OBJ} ${o} ${s} ${OBJ}`);

    // Minecraft divides by flooring; Volt divides towards zero. They only
    // disagree when the signs differ and it does not divide evenly, so
    // work out the floor and nudge it back by one in exactly that case.
    function truncDiv(ra, rb) {
      const q = alloc(), r = alloc();
      mov(q, ra); op(q, '/=', rb);
      mov(r, ra); op(r, '%=', rb);
      const bump = `scoreboard players add ${q} ${OBJ} 1`;
      em([`unless score ${r} ${OBJ} matches 0`, `if score ${ra} ${OBJ} matches ..-1`, `if score ${rb} ${OBJ} matches 1..`], bump);
      em([`unless score ${r} ${OBJ} matches 0`, `if score ${ra} ${OBJ} matches 1..`, `if score ${rb} ${OBJ} matches ..-1`], bump);
      return q;
    }

    function ex(node) {
      switch (node.kind) {
        case 'Number': { const d = alloc(); set(d, Math.trunc(Number(node.value))); return d; }
        case 'Bool':   { const d = alloc(); set(d, node.value ? 1 : 0); return d; }
        case 'Var':    { const d = alloc(); mov(d, reg(node.name)); return d; }

        case 'Unary': {
          const a = ex(node.operand), d = alloc();
          if (node.op === '-') { set(d, 0); op(d, '-=', a); return d; }
          set(d, 1);
          em([`unless score ${a} ${OBJ} matches 0`], `scoreboard players set ${d} ${OBJ} 0`);
          return d;
        }

        case 'Binary': {
          const a = ex(node.left), b = ex(node.right);
          switch (node.op) {
            case '+': { const d = alloc(); mov(d, a); op(d, '+=', b); return d; }
            case '-': { const d = alloc(); mov(d, a); op(d, '-=', b); return d; }
            case '*': { const d = alloc(); mov(d, a); op(d, '*=', b); return d; }
            case '/': return truncDiv(a, b);
            // Volt's remainder takes the sign of the dividend; Minecraft's
            // %= takes the sign of the divisor. Rebuild it from the
            // truncating quotient instead: a - (a/b)*b.
            case '%': {
              const q = truncDiv(a, b), m = alloc(), s = alloc();
              mov(s, q); op(s, '*=', b);
              mov(m, a); op(m, '-=', s);
              return m;
            }
            case '&&': {
              const d = alloc(); set(d, 0);
              em([`unless score ${a} ${OBJ} matches 0`, `unless score ${b} ${OBJ} matches 0`],
                 `scoreboard players set ${d} ${OBJ} 1`);
              return d;
            }
            case '||': {
              const d = alloc(); set(d, 0);
              em([`unless score ${a} ${OBJ} matches 0`], `scoreboard players set ${d} ${OBJ} 1`);
              em([`unless score ${b} ${OBJ} matches 0`], `scoreboard players set ${d} ${OBJ} 1`);
              return d;
            }
            default: {
              const CMP = { '==': '=', '<': '<', '>': '>', '<=': '<=', '>=': '>=' };
              const d = alloc(); set(d, 0);
              if (node.op === '!=') {
                em([`unless score ${a} ${OBJ} = ${b} ${OBJ}`], `scoreboard players set ${d} ${OBJ} 1`);
              } else if (CMP[node.op]) {
                em([`if score ${a} ${OBJ} ${CMP[node.op]} ${b} ${OBJ}`], `scoreboard players set ${d} ${OBJ} 1`);
              } else {
                throw new CompileError(`Unknown operator '${node.op}'.`);
              }
              return d;
            }
          }
        }

        case 'Call': return call(node);
        default: throw new CompileError(`The #minecraft target cannot work out '${node.kind}'.`);
      }
    }

    function call(node) {
      const name = node.name;
      const TEXTY = ['text', 'upper', 'lower', 'part', 'length', 'contains'];
      if (TEXTY.includes(name))
        throw new CompileError(
          `'${name}' works on text, and a scoreboard holds only whole numbers (line ${node.line}).`);
      if (name === 'sin' || name === 'cos')
        throw new CompileError(`'${name}' needs decimals, which scoreboards do not have (line ${node.line}).`);
      if (name === 'sqrt')
        throw new CompileError(`'sqrt' has no scoreboard equivalent (line ${node.line}).`);
      if (name === 'random')
        throw new CompileError(
          `'random' is not available here (line ${node.line}). Minecraft can roll dice, but not ` +
          `inside a score expression - set the value from a loot table or a command block instead.`);

      const need = (k) => {
        if ((node.args || []).length !== k)
          throw new CompileError(`'${name}' takes ${k} value(s), got ${(node.args || []).length} (line ${node.line}).`);
      };
      switch (name) {
        case 'number': need(1); return ex(node.args[0]);   // already a whole number here
        case 'abs': {
          need(1);
          const a = ex(node.args[0]), d = alloc(), neg = alloc();
          mov(d, a); set(neg, 0); op(neg, '-=', a); op(d, '>', neg);   // max(x, -x)
          return d;
        }
        case 'min': case 'max': {
          need(2);
          const a = ex(node.args[0]), b = ex(node.args[1]), d = alloc();
          mov(d, a); op(d, name === 'min' ? '<' : '>', b);
          return d;
        }
        case 'constrain': {
          need(3);
          const v = ex(node.args[0]), lo = ex(node.args[1]), hi = ex(node.args[2]), d = alloc();
          mov(d, v); op(d, '>', lo); op(d, '<', hi);
          return d;
        }
        case 'sign': {
          need(1);
          const a = ex(node.args[0]), d = alloc();
          set(d, 0);
          em([`if score ${a} ${OBJ} matches 1..`], `scoreboard players set ${d} ${OBJ} 1`);
          em([`if score ${a} ${OBJ} matches ..-1`], `scoreboard players set ${d} ${OBJ} -1`);
          return d;
        }
        case 'map': {
          need(5);
          const [v, lo, hi, olo, ohi] = node.args.map(ex);
          const num = alloc(), den = alloc();
          mov(num, v); op(num, '-=', lo);
          const span = alloc(); mov(span, ohi); op(span, '-=', olo);
          op(num, '*=', span);
          mov(den, hi); op(den, '-=', lo);
          const q = truncDiv(num, den);
          op(q, '+=', olo);
          return q;
        }
        default:
          throw new CompileError(`The #minecraft target has no '${name}' (line ${node.line}).`);
      }
    }

    return { ex, alloc };
  }

  // ---------------------------------------------------------------
  //  print -> tellraw
  //
  //  Flatten a chain of + into components. Text stays as text; anything
  //  numeric is worked out into a register and shown as a score. A
  //  true/false has no score form, so the line is emitted once per
  //  combination, each guarded on the value.
  // ---------------------------------------------------------------
  function emitPrint(node, em, E) {
    const parts = [];
    (function flatten(n) {
      if (n.kind === 'Binary' && n.op === '+' && typeOf(n) === 'text') { flatten(n.left); flatten(n.right); }
      else parts.push(n);
    })(node);

    const bools = parts.filter((p) => typeOf(p) === 'bool');
    if (bools.length > 2)
      throw new CompileError(
        `This print mixes ${bools.length} true/false values into one line; the #minecraft ` +
        `target can manage two. Print them separately.`);

    // Work out every non-text component up front, once.
    const slot = new Map();
    for (const p of parts) if (p.kind !== 'String') slot.set(p, E.ex(p));

    const combos = [];
    const build = (i, conds, chosen) => {
      if (i === bools.length) { combos.push([conds, chosen]); return; }
      const r = slot.get(bools[i]);
      build(i + 1, [...conds, `unless score ${r} ${OBJ} matches 0`], new Map(chosen).set(bools[i], 'true'));
      build(i + 1, [...conds, `if score ${r} ${OBJ} matches 0`], new Map(chosen).set(bools[i], 'false'));
    };
    build(0, [], new Map());

    for (const [conds, chosen] of combos) {
      const comps = parts.map((p) => {
        if (p.kind === 'String') return `{"text":${json(p.value)}}`;
        if (chosen.has(p)) return `{"text":${json(chosen.get(p))}}`;
        return `{"score":{"name":"${slot.get(p)}","objective":"${OBJ}"}}`;
      });
      em(conds, `tellraw @a [${comps.join(',')}]`);
    }
  }

  // ---------------------------------------------------------------
  //  The program, one instruction at a time
  // ---------------------------------------------------------------
  prog.forEach((ins, i) => {
    const em = makeEmitter(i);
    const E = makeExpr(em);
    lines.push(`# ${i}: ${describe(ins)}`);
    switch (ins.op) {
      case 'SET': {
        const r = E.ex(ins.expr);
        em([], `scoreboard players operation ${reg(ins.name)} ${OBJ} = ${r} ${OBJ}`);
        break;
      }
      case 'PRINT': emitPrint(ins.expr, em, E); break;
      case 'JMP':   em([], `scoreboard players set ${NPC} ${OBJ} ${ins.target}`); break;
      case 'JZ': {
        const r = E.ex(ins.expr);
        em([`if score ${r} ${OBJ} matches 0`], `scoreboard players set ${NPC} ${OBJ} ${ins.target}`);
        break;
      }
      case 'HALT':  em([], `scoreboard players set ${NPC} ${OBJ} ${i}`); break;
      case 'NOP':   break;
      default: throw new CompileError(`Unknown instruction ${ins.op}.`);
    }
  });

  // ---------------------------------------------------------------
  //  Assemble the two functions
  // ---------------------------------------------------------------
  const temps = Array.from({ length: maxTemp }, (_, k) => `#t${k}`);
  const holders = [PC, NPC, ...vars.map(reg), ...temps];

  const setup = [
    `# ${ns}:setup - run once to load the program.`,
    `#   /function ${ns}:setup`,
    `scoreboard objectives add ${OBJ} dummy`,
    ...holders.map((h) => `scoreboard players set ${h} ${OBJ} 0`),
    `tellraw @a {"text":"[volt] loaded - run ${ns}:tick to step the program.","color":"gray"}`,
  ];

  const tick = [
    `# ${ns}:tick - one instruction per call.`,
    `#   Put this on a repeating command block, or:`,
    `#   /schedule function ${ns}:tick 1t replace`,
    '',
    '# Work the next counter out separately, so a jump cannot land on a',
    '# later instruction and have it run in this same tick.',
    `scoreboard players operation ${NPC} ${OBJ} = ${PC} ${OBJ}`,
    `scoreboard players add ${NPC} ${OBJ} 1`,
    '',
    ...lines,
    '',
    `scoreboard players operation ${PC} ${OBJ} = ${NPC} ${OBJ}`,
  ];

  return [
    `# Compiled from Volt by the #minecraft target.`,
    `# ${prog.length} instructions, ${vars.length} variables, ${maxTemp} working registers.`,
    `# Two functions follow; make-datapack.js turns this into a datapack.`,
    '',
    `#=== ${ns}:setup ===`,
    ...setup,
    '',
    `#=== ${ns}:tick ===`,
    ...tick,
    '',
  ].join('\n');
}

function describe(ins) {
  switch (ins.op) {
    case 'SET':   return `${ins.name} = ...`;
    case 'PRINT': return 'print';
    case 'JMP':   return `go to ${ins.target}`;
    case 'JZ':    return `if false go to ${ins.target}`;
    case 'HALT':  return 'stop';
    default:      return ins.op;
  }
}

module.exports = { emit };
