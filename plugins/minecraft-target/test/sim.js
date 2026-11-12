// =====================================================================
//  A small Minecraft command interpreter, for testing this target.
//
//  It understands only the handful of command forms the generator emits
//  and it reads the generated text, not some internal structure - so it
//  checks the commands that would actually be pasted into the game.
//
//  What it proves: the program's logic and arithmetic are right.
//  What it does NOT prove: that Minecraft accepts the syntax. Only
//  Minecraft can tell you that.
//
//  Scoreboard arithmetic follows Minecraft: /= floors and %= takes the
//  sign of the divisor, which is exactly why the generator goes to the
//  trouble of rebuilding Volt's truncating division on top of them.
// =====================================================================

const floorDiv = (a, b) => Math.floor(a / b);
const floorMod = (a, b) => a - floorDiv(a, b) * b;

function parseSections(text) {
  const out = {};
  let cur = null;
  for (const raw of text.split('\n')) {
    const m = raw.match(/^#===\s*\S+:(\w+)\s*===$/);
    if (m) { cur = m[1]; out[cur] = []; continue; }
    if (cur) out[cur].push(raw);
  }
  return out;
}

// `matches` ranges: "5", "1..", "..-1", "2..7"
function matchesRange(v, spec) {
  if (spec.includes('..')) {
    const [lo, hi] = spec.split('..');
    if (lo !== '' && v < Number(lo)) return false;
    if (hi !== '' && v > Number(hi)) return false;
    return true;
  }
  return v === Number(spec);
}

function makeMachine(onSay) {
  const S = new Map();
  const get = (n) => S.get(n) ?? 0;

  function condHolds(tokens) {
    // if|unless score <A> <obj> ( matches <range> | <op> <B> <obj> )
    const neg = tokens[0] === 'unless';
    if (tokens[1] !== 'score') throw new Error('unsupported condition: ' + tokens.join(' '));
    const a = tokens[2];
    let ok;
    if (tokens[4] === 'matches') {
      ok = matchesRange(get(a), tokens[5]);
    } else {
      const op = tokens[4], b = tokens[5];
      const x = get(a), y = get(b);
      ok = op === '=' ? x === y : op === '<' ? x < y : op === '>' ? x > y
         : op === '<=' ? x <= y : op === '>=' ? x >= y
         : (() => { throw new Error('unsupported compare: ' + op); })();
    }
    return neg ? !ok : ok;
  }

  // Split an `execute` prefix into its conditions and the command it runs.
  function splitExecute(parts) {
    const conds = [];
    let i = 1;
    while (i < parts.length) {
      if (parts[i] === 'run') return { conds, cmd: parts.slice(i + 1) };
      if (parts[i] !== 'if' && parts[i] !== 'unless') throw new Error('unsupported execute: ' + parts.join(' '));
      // "if score A obj matches R" is 6 tokens; "if score A obj < B obj" is 7.
      const len = parts[i + 4] === 'matches' ? 6 : 7;
      conds.push(parts.slice(i, i + len));
      i += len;
    }
    throw new Error('execute with no run: ' + parts.join(' '));
  }

  function runCommand(parts) {
    if (parts[0] === 'execute') {
      const { conds, cmd } = splitExecute(parts);
      if (conds.every(condHolds)) runCommand(cmd);
      return;
    }
    if (parts[0] === 'scoreboard') {
      if (parts[1] === 'objectives') return;                       // nothing to model
      if (parts[1] !== 'players') throw new Error('unsupported: ' + parts.join(' '));
      const verb = parts[2], a = parts[3];
      if (verb === 'set') return void S.set(a, Number(parts[5]));
      if (verb === 'add') return void S.set(a, get(a) + Number(parts[5]));
      if (verb === 'operation') {
        const op = parts[5], b = parts[6];
        const x = get(a), y = get(b);
        const r = op === '=' ? y : op === '+=' ? x + y : op === '-=' ? x - y
          : op === '*=' ? x * y
          : op === '/=' ? (y === 0 ? x : floorDiv(x, y))   // Minecraft leaves it alone on /0
          : op === '%=' ? (y === 0 ? x : floorMod(x, y))
          : op === '<' ? Math.min(x, y) : op === '>' ? Math.max(x, y)
          : (() => { throw new Error('unsupported operation: ' + op); })();
        return void S.set(a, r | 0);
      }
      throw new Error('unsupported scoreboard verb: ' + verb);
    }
    if (parts[0] === 'tellraw') {
      const payload = parts.slice(2).join(' ');
      const comps = JSON.parse(payload);
      const text = (Array.isArray(comps) ? comps : [comps]).map((c) => {
        if (c.text !== undefined) return c.text;
        if (c.score) return String(get(c.score.name));
        throw new Error('unsupported tellraw component: ' + JSON.stringify(c));
      }).join('');
      onSay(text);
      return;
    }
    throw new Error('unsupported command: ' + parts.join(' '));
  }

  const runLines = (lines) => {
    for (const raw of lines) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      runCommand(line.split(/\s+/));
    }
  };

  return { get, runLines };
}

// Run the program until the counter stops moving, or we run out of ticks.
function run(text, maxTicks = 5000) {
  const said = [];
  const say = (t) => said.push(t);
  const m = makeMachine(say);
  const sec = parseSections(text);
  if (!sec.setup || !sec.tick) throw new Error('expected a setup and a tick section');

  m.runLines(sec.setup);
  said.length = 0;                       // drop the loader's banner

  for (let i = 0; i < maxTicks; i++) {
    const before = m.get('#pc');
    m.runLines(sec.tick);
    if (m.get('#pc') === before) break;   // HALT keeps the counter still
  }
  return said;
}

module.exports = { run };

if (require.main === module) {
  const fs = require('fs');
  process.stdout.write(run(fs.readFileSync(process.argv[2], 'utf8')).join('\n') + '\n');
}
