// Checks the game kit (plugins/game-kit/game.volt): walking, running,
// crouching, walls, steps, jumping, standing on crates, ceilings and beams.
// Run with: node test/game-kit-test.js
//
// It compiles a real program that imports the kit, pulls the generated
// JavaScript for the kit's own functions back out, and runs them against
// stand-ins for the browser bits (held, mousedx, sin3, camera3d). So it tests
// the code that actually ships, not a copy of it.
const fs = require('fs');
const path = require('path');
const volt = require('../compiler/volt.js');
const plugins = require('../lib/plugins.js');

const root = path.join(__dirname, '..');
const list = plugins.scanPlugins(path.join(root, 'plugins'), path.join(root, '.no-user-plugins'));
const program = `#html
title "kit test"
canvas 320, 180
import "game.volt"
world3d "#05060a" ambient 8
let Floor = block3d(0, -5, 0, 1200, 10, 1200, "#6a6f78")
playerStart(0, 400, 0)
every frame {
  playerStep()
  render3d
}
`;
const { code } = volt.compile(program, { baseDir: null, extraDirs: plugins.libraryDirs(list) });
const from = code.indexOf('let WALK_SPEED');
const to = code.indexOf('async function __main');
if (from < 0 || to < 0) { console.log('FAIL  could not find the kit in the compiled page'); process.exit(1); }

const keys = new Set();
const stubs = `
function __held(k) { return KEYS.has(k); }
let __mdx = 0, __mdy = 0;
function __mousedx() { const v = __mdx; __mdx = 0; return v; }
function __mousedy() { const v = __mdy; __mdy = 0; return v; }
function __sin3(a) { return Math.round(Math.sin(a / 10 * Math.PI / 180) * 1000); }
function __cos3(a) { return Math.round(Math.cos(a / 10 * Math.PI / 180) * 1000); }
function __atan23(y, x) { return ((Math.round(Math.atan2(y, x) * 1800 / Math.PI) % 3600) + 3600) % 3600; }
function __dist(x1, y1, x2, y2) { return Math.trunc(Math.hypot(x2 - x1, y2 - y1)); }
function __camera3d() {}
`;
const kit = new Function('KEYS', stubs + code.slice(from, to) + `
return { api: { solid, clearSolids, playerStart, playerLook, playerWalk, playerFall, eyeLevel, playerNear, playerFacing },
         get: (n) => eval(n), set: (n, v) => { eval(n + ' = ' + JSON.stringify(v)); } };`)(keys);

// the settings the kit declares are assigned in __main, which never runs here
for (const [k, v] of Object.entries({ WALK_SPEED: 400, RUN_SPEED: 750, CROUCH_SPEED: 180, MOUSE_SPEED: 3,
  INVERT_LOOK: false, LOOK_LIMIT: 850, EYE_HEIGHT: 165, CROUCH_HEIGHT: 95, JUMP_POWER: 430, GRAVITY: 1500,
  STEP_HEIGHT: 45, PLAYER_WIDTH: 25, HEAD_BOB: 3, CAN_RUN: true, CAN_JUMP: true, CAN_CROUCH: true, CAN_MOVE: true })) kit.set(k, v);

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };
const g = (n) => kit.get(n);
const FLOOR = [0, 0, 600, 600, -10, 0];
async function world(boxes) {
  await kit.api.clearSolids();
  for (const b of boxes) await kit.api.solid(...b);
  keys.clear();
  kit.set('PLAYER_BOB', 0);
}
async function frames(n) { for (let i = 0; i < n; i++) { await kit.api.playerWalk(); await kit.api.playerFall(); } }

(async () => {
  await world([FLOOR]);
  await kit.api.playerStart(0, 400, 0);
  await frames(60);
  check('stands still on the floor', g('PLAYER_Y') === 0 && g('PLAYER_Z') === 400 && g('PLAYER_GROUNDED'));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); await frames(60);
  check('walks about WALK_SPEED in a second', Math.abs((400 - g('PLAYER_Z')) - 400) < 12, 'moved ' + (400 - g('PLAYER_Z')));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); keys.add('shift'); await frames(60);
  check('runs about RUN_SPEED with Shift', Math.abs((400 - g('PLAYER_Z')) - 750) < 20, 'moved ' + (400 - g('PLAYER_Z')));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); keys.add('control'); await frames(60);
  check('crouch-walks with Ctrl', Math.abs((400 - g('PLAYER_Z')) - 180) < 12, 'moved ' + (400 - g('PLAYER_Z')));
  check('the view drops while crouching', (await kit.api.eyeLevel()) <= 98);

  await world([FLOOR, [0, 0, 200, 10, 0, 300]]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); await frames(120);
  check('a wall stops you', g('PLAYER_Z') > 10 && g('PLAYER_Z') < 60, 'Z=' + g('PLAYER_Z'));

  await world([FLOOR, [0, 0, 100, 100, 0, 30]]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); await frames(60);
  check('a low step is walked onto', g('PLAYER_Y') === 30, 'Y=' + g('PLAYER_Y'));

  await world([FLOOR, [0, 0, 100, 100, 0, 80]]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); await frames(120);
  check('a tall crate is not', g('PLAYER_Y') === 0 && g('PLAYER_Z') > 100, 'Y=' + g('PLAYER_Y') + ' Z=' + g('PLAYER_Z'));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  keys.add('space');
  let peak = 0;
  for (let i = 0; i < 80; i++) { await frames(1); peak = Math.max(peak, g('PLAYER_Y')); if (i === 0) keys.delete('space'); }
  check('jumps about 60cm and lands', peak > 40 && peak < 90 && Math.abs(g('PLAYER_Y')) < 0.5, 'peak=' + Math.round(peak));

  await world([FLOOR, [0, 200, 100, 100, 0, 80]]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); keys.add('space');
  for (let i = 0; i < 120; i++) { await frames(1); if (g('PLAYER_GROUNDED') && g('PLAYER_Y') > 0) break; }
  check('you can jump onto a crate', g('PLAYER_Y') === 80, 'Y=' + g('PLAYER_Y'));

  await world([FLOOR, [0, 0, 600, 600, 300, 310]]); await kit.api.playerStart(0, 400, 0);
  keys.add('w'); await frames(30);
  check('a ceiling is walked under', g('PLAYER_Z') < 350, 'Z=' + g('PLAYER_Z'));

  await world([FLOOR, [0, 0, 300, 15, 100, 150]]); await kit.api.playerStart(0, 200, 0);
  keys.add('w'); await frames(60);
  const stopped = g('PLAYER_Z') > 10;
  await world([FLOOR, [0, 0, 300, 15, 100, 150]]); await kit.api.playerStart(0, 200, 0);
  keys.add('w'); keys.add('control'); await frames(200);
  check('a low beam needs crouching', stopped && g('PLAYER_Z') < -20, 'crouched to Z=' + g('PLAYER_Z'));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  kit.set('CAN_MOVE', false); keys.add('w'); await frames(30);
  check('CAN_MOVE false freezes the player', g('PLAYER_Z') === 400, 'Z=' + g('PLAYER_Z'));
  kit.set('CAN_MOVE', true);

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  kit.set('PLAYER_PITCH', 0);
  for (let i = 0; i < 50; i++) { kit.set('__mdy', -100); await kit.api.playerLook(); }
  check('looking up stops at LOOK_LIMIT', g('PLAYER_PITCH') === 850, 'pitch=' + g('PLAYER_PITCH'));

  await world([FLOOR]); await kit.api.playerStart(0, 400, 0);
  check('playerNear / playerFacing answer sensibly',
    (await kit.api.playerNear(0, 350, 100)) === true && (await kit.api.playerNear(0, 0, 100)) === false &&
    (await kit.api.playerFacing(0, 0, 300)) === true && (await kit.api.playerFacing(0, 900, 300)) === false);

  // the examples ship in this shape - they have to keep compiling
  for (const name of ['30_world_studio_game.volt', '31_characters_and_scripts.volt', '32_anime_effects.volt']) {
    const example = path.join(root, 'examples', name);
    try {
      volt.compile(fs.readFileSync(example, 'utf8'), { baseDir: path.dirname(example), extraDirs: plugins.libraryDirs(list) });
      console.log('pass  examples/' + name + ' compiles');
    } catch (e) { failed++; console.log('FAIL  examples/' + name + ': ' + e.message); }
  }
  // the characters are where the character pack says they are
  const pack = path.join(root, 'plugins', 'character-pack');
  const missing = ['coworker_cyan', 'coworker_gold', 'coworker_red', 'hunter', 'raider', 'raider2', 'ninja', 'wolf', 'bear', 'deer']
    .filter((c) => !fs.existsSync(path.join(pack, c + '.glb')));
  check('every character in the pack is there', missing.length === 0, 'missing: ' + missing.join(', '));

  process.exitCode = failed ? 1 : 0;
})();
