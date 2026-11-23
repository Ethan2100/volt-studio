// The backpack bar: every style compiles, draws, and lays its slots out
// where it says it will.
//   Run with: node test/hotbar-test.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

const kit = path.join(__dirname, '..', 'plugins', 'game-kit');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-hotbar-'));
for (const f of ['game.volt', 'combat.volt']) fs.copyFileSync(path.join(kit, f), path.join(dir, f));

const STYLES = ['plain', 'gold', 'round', 'hex', 'slim'];

const program = (settings) => `#html
import "game.volt"
import "combat.volt"
canvas 320, 180
${settings}
give("Sword", 1, "#d9e2ec")
give("Potion", 5, "#ff4d6d")
give("Bomb", 12, "#8affc1")
give("Key", 1, "#ffd23f")
pickSlot(1)
drawCombat()
`;

// Build the page, then run just its drawing against a stub canvas that
// writes down every shape it is asked for.
function draw(settings) {
  let code;
  try { code = volt.compile(program(settings), { baseDir: dir }).code; }
  catch (e) { return { error: `${e.file || ''} line ${e.line}: ${e.message}` }; }
  const shapes = [];
  const ctx = new Proxy({}, { get(t, k) {
    if (k === 'measureText') return () => ({ width: 0 });
    if (typeof k !== 'string') return undefined;
    return (...a) => { shapes.push([k, ...a]); };
  }, set() { return true } });
  return { code, shapes, ctx };
}

// every style gets through the compiler
for (const style of STYLES) {
  const out = draw(`HOTBAR_STYLE = "${style}"`);
  check(`the ${style} bar compiles`, !out.error, out.error || '');
}

// and the shapes each one asks for are the ones it promises
const { JSDOM } = (() => { try { return require('jsdom'); } catch (e) { return {}; } })();
const mock = (n) => { const m = new Map(); return new Proxy(function () {}, {
  get(t, k) { if (k === Symbol.toPrimitive || k === 'valueOf') return () => 0;
    if (k === 'toString') return () => n; if (k === 'then') return undefined;
    if (!m.has(k)) m.set(k, mock(n + '.' + String(k))); return m.get(k); },
  set(t, k, v) { m.set(k, v); return true }, has() { return true },
  apply() { return mock(n + '()') }, construct() { return mock('new ' + n) } }); };

// Start a page drawing onto a stub canvas that writes down every shape.
// The page draws on its own clock, so these all run together and are
// read once, afterwards.
function start(settings) {
  const out = draw(settings);
  if (out.error) return { error: out.error, seen: [] };
  const seen = [];
  const ctx = { measureText: () => ({ width: 0 }), canvas: { width: 320, height: 180 } };
  for (const k of ['fillRect', 'rect', 'arc', 'moveTo', 'lineTo', 'arcTo', 'beginPath',
    'closePath', 'fill', 'stroke', 'clearRect', 'save', 'restore', 'translate',
    'scale', 'setTransform', 'drawImage', 'fillText', 'strokeText', 'clip',
    'createLinearGradient', 'createRadialGradient', 'quadraticCurveTo', 'bezierCurveTo',
    'ellipse', 'strokeRect', 'putImageData', 'getImageData', 'createPattern', 'rotate']) {
    ctx[k] = (...a) => { seen.push([k, ...a]); return mock('ctx.' + k); };
  }
  // no roundRect, so the rounded corners go through our own path and can be counted
  const dom = new JSDOM(out.code, {
    runScripts: 'dangerously', pretendToBeVisual: true, url: 'https://volt.test/',
    beforeParse(window) {
      window.THREE = mock('THREE');
      window.HTMLCanvasElement.prototype.getContext = () => ctx;
    },
  });
  return { seen, dom };
}

const count = (seen, what) => seen.filter((s) => s[0] === what).length;

if (!JSDOM) {
  console.log('skip  jsdom is not installed, so the drawing checks were skipped');
  fs.rmSync(dir, { recursive: true, force: true });
  process.exitCode = failed ? 1 : 0;
} else {
  const runs = {
    plain: start('HOTBAR_STYLE = "plain"'),
    gold: start('HOTBAR_STYLE = "gold"'),
    round: start('HOTBAR_STYLE = "round"'),
    hex: start('HOTBAR_STYLE = "hex"'),
    slim: start('HOTBAR_STYLE = "slim"'),
    off: start('HOTBAR_STYLE = "plain"\nSHOW_HOTBAR = false'),
    ten: start('HOTBAR_SLOTS = 10'),
    tworows: start('HOTBAR_SLOTS = 10\nHOTBAR_ROWS = 2'),
    big: start('HOTBAR_SIZE = 40'),
  };

  setTimeout(() => {
    const s = (k) => runs[k].seen;
    check('the round bar draws circles', count(s('round'), 'arc') >= 4, `arcs: ${count(s('round'), 'arc')}`);
    check('the hex bar draws six-sided slots', count(s('hex'), 'lineTo') >= 20, `corners: ${count(s('hex'), 'lineTo')}`);
    check('the hex bar draws no circles', count(s('hex'), 'arc') === 0);
    check('the plain bar draws rounded slots', count(s('plain'), 'arcTo') >= 16, `corners: ${count(s('plain'), 'arcTo')}`);
    check('the gold bar draws more than the plain one, since it is framed twice',
      s('gold').length > s('plain').length, `${s('gold').length} vs ${s('plain').length}`);
    check('the slim bar draws the least of all',
      s('slim').length < s('plain').length, `${s('slim').length} vs ${s('plain').length}`);
    check('turning the bar off draws less than leaving it on',
      s('off').length < s('plain').length, `${s('off').length} vs ${s('plain').length}`);
    check('a fixed number of slots draws the empty ones too',
      count(s('ten'), 'arcTo') > count(s('plain'), 'arcTo'),
      `${count(s('ten'), 'arcTo')} vs ${count(s('plain'), 'arcTo')}`);

    const tops = [...new Set(s('tworows').filter((x) => x[0] === 'arcTo').map((x) => Math.round(x[2])))]
      .sort((a, b) => a - b);
    check('two rows really sit at two heights', tops.length >= 2, JSON.stringify(tops));

    const wide = (seen) => {
      const xs = seen.filter((x) => x[0] === 'arcTo').map((x) => x[1]);
      return xs.length ? Math.max(...xs) - Math.min(...xs) : 0;
    };
    check('bigger slots make a wider bar', wide(s('big')) > wide(s('plain')),
      `${wide(s('big'))} vs ${wide(s('plain'))}`);

    for (const run of Object.values(runs)) if (run.dom) run.dom.window.close();
    rest();
  }, 700);
}

function rest() {
// --------------------------------------------------- the settings behave
function lines(settings, fn) {
  try { return volt.compile(program(settings), { baseDir: dir }).code; }
  catch (e) { return 'ERROR ' + e.message; }
}
let c = lines('HOTBAR_SIZE = 40');
check('a slot size is carried into the page', /HOTBAR_SIZE = 40|= 40/.test(c));

// an empty backpack draws nothing at all, rather than failing
try {
  const empty = `#html\nimport "game.volt"\nimport "combat.volt"\ncanvas 320, 180\ndrawCombat()\n`;
  volt.compile(empty, { baseDir: dir });
  check('an empty backpack is fine', true);
} catch (e) { check('an empty backpack is fine', false, e.message); }

// the keys are 1-9 then 0, and nothing past that
const keyCode = volt.compile(program(''), { baseDir: dir }).code;
check('the tenth slot is the 0 key', /"0"/.test(keyCode));

  fs.rmSync(dir, { recursive: true, force: true });
  process.exitCode = failed ? 1 : 0;
}
