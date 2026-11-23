// Tests the combat kit (plugins/game-kit/combat.volt) the way a game
// actually uses it: a real Volt program is compiled by the real
// compiler, run, and its own printed results are read back. That way a
// change to the kit, the compiler or the 3D builtins it leans on all
// show up here.
//   Run with: node test/combat-kit-test.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

let JSDOM;
try { ({ JSDOM } = require('jsdom')); } catch {
  console.log('skip  combat kit (jsdom not installed - npm install)');
  process.exit(0);
}

const kit = path.join(__dirname, '..', 'plugins', 'game-kit');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-combat-'));
for (const f of ['game.volt', 'combat.volt']) fs.copyFileSync(path.join(kit, f), path.join(dir, f));

// The Volt program under test. It prints one line per check; anything
// starting "FAIL" fails the run.
const program = `#html
canvas 320, 180
import "game.volt"
import "combat.volt"

// no renderer in this harness, so no sparks (the logic is what is under test)
DEATH_SPARKS = false

fn say(label, got, want) {
  if got == want {
    print "ok " + label
  } else {
    print "FAIL " + label + " (got " + got + ", wanted " + want + ")"
  }
}

// ---- things that can be hurt ----
let g = target("Goblin", 0, 60, -400, 40, 90)
let b = target("Barrel", 300, 30, -400, 20, 50)
say("two targets exist", length(TARGET_HP), 2)
say("a target starts at full health", TARGET_HP[g], 40)
say("a new target is alive", alive(g), true)

hurtTarget(g, 15)
say("hurting takes the health off", TARGET_HP[g], 25)
say("and it is still alive", alive(g), true)

let killed = hurtTarget(g, 25)
say("the killing blow says so", killed, true)
say("health never goes below zero", TARGET_HP[g], 0)
say("and it is dead", alive(g), false)
say("hurting a dead thing does nothing", hurtTarget(g, 10), false)
say("one left standing", aliveCount(), 1)

// ---- area damage ----
let hit = damageArea(300, -400, 100, 5)
say("area damage hits what is in reach", hit, 1)
say("and takes the health off", TARGET_HP[b], 15)
say("it leaves the dead alone", damageArea(0, -400, 100, 5), 0)
say("nothing in reach means nothing hit", damageArea(9000, 9000, 50, 5), 0)
say("the nearest target is found", nearestTarget(280, -400, 500), b)
say("nothing near means -1", nearestTarget(9000, 9000, 10), -1)

// ---- the player ----
say("the player starts whole", PLAYER_HP, 100)
hurtPlayer(30)
say("the player can be hurt", PLAYER_HP, 70)
say("being hurt starts the flash", PLAYER_HURT > 0, true)
healPlayer(10)
say("the player can be healed", PLAYER_HP, 80)
healPlayer(999)
say("healing stops at full", PLAYER_HP, 100)
hurtPlayer(250)
say("too much damage kills", PLAYER_DEAD, true)
say("health stops at zero", PLAYER_HP, 0)
say("the dead cannot walk", CAN_MOVE, false)
hurtPlayer(10)
say("hurting the dead changes nothing", PLAYER_HP, 0)
revivePlayer()
say("reviving puts them back", PLAYER_HP, 100)
say("and lets them walk", CAN_MOVE, true)

// ---- cooldowns ----
say("an unused ability is ready", ready("Zap"), true)
startCooldown("Zap", 500)
say("using it stops it being ready", ready("Zap"), false)
say("the dial starts low", coolPercent("Zap", 500) < 50, true)
let n = 0
while n < 40 {
  stepCombat()
  n += 1
}
say("waiting makes it ready again", ready("Zap"), true)

// ---- the backpack ----
say("the bag starts empty", length(BAG_NAME), 0)
say("nothing is held", holding(), "")
give("Potion", 3, "#ff6b6b")
give("Bomb", 2, "#ffd23f")
say("two kinds of thing are in the bag", length(BAG_NAME), 2)
say("the first slot is held", holding(), "Potion")
give("Potion", 2, "#ff6b6b")
say("the same thing stacks up", countOf("Potion"), 5)
say("it does not take a new slot", length(BAG_NAME), 2)
pickSlot(1)
say("picking a slot changes what is held", holding(), "Bomb")
pickSlot(7)
say("picking an empty slot changes nothing", holding(), "Bomb")
say("using one works", takeOne("Bomb"), true)
say("and takes one off", countOf("Bomb"), 1)
takeOne("Bomb")
say("the last one leaves the bag", countOf("Bomb"), 0)
say("and its slot goes with it", length(BAG_NAME), 1)
say("the hand falls back to a real slot", holding(), "Potion")
say("using what you do not have fails", takeOne("Sword"), false)

// ---- damage numbers ----
say("hits leave a number behind", length(DMG_TEXT) > 0, true)
let before = length(DMG_TEXT)
let m = 0
while m < 70 {
  stepCombat()
  m += 1
}
say("numbers fade away on their own", length(DMG_TEXT) < before, true)
print "DONE"
`;
fs.writeFileSync(path.join(dir, 'combat-demo.volt'), program);

let html;
try {
  const out = volt.compile(program, { baseDir: dir });
  html = out.code;
  check('the combat kit compiles', true);
} catch (e) {
  check('the combat kit compiles', false, `${e.file || ''} line ${e.line}: ${e.message}`);
  fs.rmSync(dir, { recursive: true, force: true });
  process.exit(1);
}

// three.js and a 2D canvas are only needed for the spark burst a kill
// sets off and for the HUD layer; stand-ins are enough to run the logic.
const mock = (n) => { const m = new Map(); return new Proxy(function () {}, {
  get(t, k) { if (k === Symbol.toPrimitive || k === 'valueOf') return () => 0;
    if (k === 'toString') return () => n; if (k === 'then') return undefined;
    if (!m.has(k)) m.set(k, mock(n + '.' + String(k))); return m.get(k); },
  set(t, k, v) { m.set(k, v); return true }, has() { return true },
  apply() { return mock(n + '()') }, construct() { return mock('new ' + n) } }); };

// The page runs while JSDOM is still building it, so the stand-ins have
// to be in place before parsing rather than after.
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'https://volt.test/',
  beforeParse(window) {
    window.THREE = mock('THREE');
    window.HTMLCanvasElement.prototype.getContext = () => mock('ctx');
  },
});
const win = dom.window;

setTimeout(() => {
  const lines = [...win.document.querySelectorAll('.volt-line')].map((d) => d.textContent);
  const errors = [...win.document.querySelectorAll('.volt-error')].map((d) => d.textContent);
  check('the program ran to the end without an error', errors.length === 0 && lines.includes('DONE'),
    errors[0] || `${lines.length} lines, last: ${lines[lines.length - 1] || '(none)'}`);
  for (const line of lines) {
    if (line === 'DONE') continue;
    if (line.startsWith('ok ')) check(line.slice(3), true);
    else if (line.startsWith('FAIL ')) check(line.slice(5), false);
  }
  fs.rmSync(dir, { recursive: true, force: true });
  process.exitCode = failed ? 1 : 0;
}, 600);
