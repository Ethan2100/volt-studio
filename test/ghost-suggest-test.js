// Checks the inline suggestions (renderer/ghost.js) against the REAL
// docs/REFERENCE.md: that it reads every built-in's signature out of the
// document, and that what it offers to type for you is code that matches
// what the reference says.
//   Run with: node test/ghost-suggest-test.js
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'renderer', 'ghost.js'), 'utf8');
const referenceMd = fs.readFileSync(path.join(root, 'docs', 'REFERENCE.md'), 'utf8');

// ghost.js only needs a window to hang itself on; suggest() and learn()
// touch neither the DOM nor CodeMirror.
const win = {};
new Function('window', src)(win);
const G = win.VoltGhost;

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

const sigs = G.learn(referenceMd);
const info = { pins: [], vars: ['floor'], funcs: [] };
const say = (before, target = 'html') => G.suggest(before, info, target, sigs);

// ---- reading the reference ----
check('it reads signatures out of the real reference',
  Object.keys(sigs.call).length > 25 && Object.keys(sigs.cmd).length > 15,
  `${Object.keys(sigs.call).length} calls, ${Object.keys(sigs.cmd).length} commands`);
check('block3d is read with all seven arguments',
  (sigs.call.block3d || []).length === 7, JSON.stringify(sigs.call.block3d));
check('solid is read with its six arguments',
  (sigs.call.solid || []).join(',') === 'x,z,halfWidth,halfDepth,bottom,top', JSON.stringify(sigs.call.solid));
check('a statement-form built-in is read as one', (sigs.cmd.turn3d || []).join(',') === 'id,yaw', JSON.stringify(sigs.cmd.turn3d));
check('burst3d keeps its quoted colour as one argument',
  (sigs.cmd.burst3d || []).length === 6 && sigs.cmd.burst3d[3] === '"#ff8844"', JSON.stringify(sigs.cmd.burst3d));
check('a comma inside quotes does not split an argument',
  G.splitArgs('a, "x, y", b').join('|') === 'a|"x, y"|b', G.splitArgs('a, "x, y", b').join('|'));
check('3D built-ins are marked as belonging to web pages', sigs.targetOf.block3d === 'html', sigs.targetOf.block3d);

// ---- filling a call in ----
check('opening a built-in fills the whole call in',
  say('let wall = block3d(') === '0, 0, 0, 100, 100, 100, "#8a8f99")', JSON.stringify(say('let wall = block3d(')));
check('every value it inserts is a literal or a name, never a placeholder',
  !/\b(x|y|z|w|h|d|halfWidth|yaw)\b/.test(say('let wall = block3d(')), say('let wall = block3d('));
check('solid is filled in from its own argument names',
  say('solid(') === '0, 0, 100, 100, 0, 200)', JSON.stringify(say('solid(')));
check('an "id" argument uses something the file already has',
  say('turn3d ') === 'floor, 0', JSON.stringify(say('turn3d ')));
check('a statement-form built-in is filled in after a space',
  say('burst3d ') === '0, 0, 0, "#ff8844", 30, 300', JSON.stringify(say('burst3d ')));

// ---- finishing a word ----
check('a 3D word is finished from the reference', say('  block3') === 'd(', JSON.stringify(say('  block3')));
check('a word is not offered for the wrong output',
  say('  block3', 'cpp') === null, JSON.stringify(say('  block3', 'cpp')));
check('a board word is still offered on a board', typeof G.suggest('  fad', { pins: [], vars: [], funcs: [] }, 'cpp', sigs) === 'string');

// ---- whole blocks ----
check('"every " opens a frame loop on a web page', say('every ') === 'frame {', JSON.stringify(say('every ')));
check('"every " is still a timer on a board',
  G.suggest('every ', info, 'cpp', sigs) === '1s {', JSON.stringify(G.suggest('every ', info, 'cpp', sigs)));
check('"if " proposes a condition and a block', say('if ') === 'floor > 0 {', JSON.stringify(say('if ')));
check('"while " proposes a condition and a block', say('while ') === 'floor > 0 {', JSON.stringify(say('while ')));
check('a finished fn header opens its block', say('fn start() ') === '{', JSON.stringify(say('fn start() ')));

// ---- it keeps its mouth shut when it should ----
check('nothing is offered for a word that is not real', say('  zzzq') === null, JSON.stringify(say('  zzzq')));
check('nothing is offered while naming something new', say('let ') === '= 0' || say('let ') === null);
check('a made-up function gets no call filled in', say('wobble3d(') === null, JSON.stringify(say('wobble3d(')));
check('it works before the reference arrives',
  typeof G.suggest('every ', info, 'html', { call: {}, cmd: {}, targetOf: {} }) === 'string');

process.exitCode = failed ? 1 : 0;
