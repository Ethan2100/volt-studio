// Checks the World Studio panel: the game file it writes, saving a world back
// into a file without disturbing the code around it, reading a world out of a
// file again, and (if jsdom is installed) that the panel itself starts up and
// its buttons are wired to something.
// Run with: node test/world-studio-test.js
const fs = require('fs');
const path = require('path');
const volt = require('../compiler/volt.js');
const plugins = require('../lib/plugins.js');

const root = path.join(__dirname, '..');
const srcDir = path.join(root, 'plugins', 'world-studio', 'src');
const studio = fs.readFileSync(path.join(srcDir, 'studio.js'), 'utf8');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };
const shellSource = fs.readFileSync(path.join(srcDir, 'shell.html'), 'utf8');
check('the editor has viewport framing and navigation controls', studio.includes('function frameAll()') && studio.includes('function sceneBounds()') && ['vFrame','vFocus','vGrid','vAxes','vZoomIn','vZoomOut'].every((id) => shellSource.includes('id="' + id + '"')));
check('the first launch frames the current scene', /resize\(\);\s*frameAll\(\);\s*requestAnimationFrame\(frame\);/.test(studio));
check('the viewport reports WebGL startup failures', studio.includes('3D viewport could not start') && studio.includes('new THREE.WebGLRenderer') && studio.includes('catch (error)'));
check('grid and axes can be toggled independently', studio.includes('grid.visible = showGrid && !game; axisLines.visible = showAxes && !game;'));

// ---- pull the pieces we want to test out of the panel's own source ----
function grabFn(name) {
  const i = studio.indexOf('function ' + name + '(');
  if (i < 0) throw new Error('no function ' + name + ' in studio.js');
  if (name === 'worldLines') {
    const end = studio.indexOf('\nfunction genGameFile', i);
    if (end < 0) throw new Error('no end of worldLines');
    return studio.slice(i, end).trimEnd();
  }
  let pd = 0, after = studio.indexOf('(', i);
  for (let k = after; k < studio.length; k++) {
    if (studio[k] === '(') pd++;
    else if (studio[k] === ')') { pd--; if (!pd) { after = k; break; } }
  }
  let depth = 0;
  for (let k = studio.indexOf('{', after); k < studio.length; k++) {
    if (studio[k] === '{') depth++;
    else if (studio[k] === '}') { depth--; if (!depth) return studio.slice(i, k + 1); }
  }
  throw new Error('unbalanced ' + name);
}
function grabConst(name) {
  const lines = studio.split('\n');
  const start = lines.findIndex((l) => l.trim().startsWith('const ' + name + ' =') || l.trim().startsWith('let ' + name + ' ='));
  if (start < 0) throw new Error('no ' + name + ' in studio.js');
  const out = [];
  let depth = 0;
  for (let i = start; i < lines.length; i++) {
    out.push(lines[i]);
    for (const ch of lines[i]) { if ('([{'.includes(ch)) depth++; else if (')]}'.includes(ch)) depth--; }
    if (depth <= 0) break;
  }
  return out.join('\n');
}
const W = new Function([
  'const D2R = Math.PI / 180;',
  'const toast = () => {};',   // the panel's own toast needs a DOM
  'const refreshNode = () => {};',
  grabConst('esc'), grabConst('clamp'), grabConst('num'), grabConst('hex6'),
  grabConst('KIND'), grabConst('ATTACHED'), grabConst('CHAR_PACK'), grabConst('CHARACTERS'), grabConst('animsOf'), grabConst('isAnimal'),
  grabConst('CHAR_ANIMS'), grabConst('WHENS'), grabConst('VFX_PRESETS'), grabConst('FX_FIELDS'), grabConst('fxKind'), grabConst('worldDefaults'),
  'let S = { world: worldDefaults(), objects: [] };', 'let nextId = 1;', 'const modelCache = new Map();',
  grabConst('byId'), grabConst('childrenOf'), grabFn('descendants'), grabFn('depthOf'), grabFn('canParent'),
  grabFn('setParent'), grabFn('treeSnapshot'), grabFn('treeApply'), grabFn('withTree'),
  grabConst('charKey'), grabConst('identish'),
  grabFn('uniqueName'), grabFn('makeObj'), grabFn('roomScene'), grabFn('makeObjQuiet'),
  grabConst('RESERVED'), grabFn('identFor'),
  'const q = (c) => \'"\' + hex6(c, \'#999999\') + \'"\';', 'const r = (v) => Math.round(num(v));',
  grabConst('KIT'), grabFn('solidBoxes'), grabConst('spawnOf'),
  grabConst('MARK_OPEN'), grabConst('MARK_CLOSE'),
  grabFn('plainWhere'), grabFn('plainWhat'), grabFn('plainIntro'),
  grabFn('vfxWhere'), grabFn('vfxStatement'), grabFn('vfxFnLines'), grabFn('vfxTriggerLines'),
  grabFn('compactObj'), grabFn('worldLines'), grabFn('genGameFile'), grabFn('spliceWorld'), grabFn('genVolt'), grabFn('importSource'),
  'return { get S() { return S; }, set S(v) { S = v; }, get nextId() { return nextId; }, set nextId(v) { nextId = v; },',
  '         roomScene, makeObj, genGameFile, spliceWorld, genVolt, importSource, setParent, childrenOf, withTree, MARK_OPEN, MARK_CLOSE };',
].join('\n\n'))();

// ---- 1. the game file it writes ----
W.roomScene();
const file = W.genGameFile({ hud: true });
check('the game file is an #html program', file.startsWith('#html\n') && file.includes('canvas 320, 180'));
check('it imports the player kit', file.includes('import "game.volt"'));
check('it has settings you can change', /^WALK_SPEED = \d+/m.test(file) && /^JUMP_POWER = \d+/m.test(file));
check('the world sits between the markers', file.indexOf(W.MARK_OPEN) < file.indexOf(W.MARK_CLOSE));
check('it builds the world', /let Floor = block3d\(/.test(file));
check('it lists what stops the player', /^clearSolids\(\)$/m.test(file) && /^solid\(-?\d+, -?\d+, \d+, \d+, -?\d+, -?\d+\)(\s+\/\/.*)?$/m.test(file));
// ---- the generated file explains itself in plain English ----
check('it says what the measurements mean', /x is left\/right, y is up, z is back\/front/.test(file));
check('every placed thing is introduced in words', /\/\/ Floor - a box \d+ wide, \d+ tall and \d+ deep/.test(file), (file.match(/\/\/ Floor[^\n]*/) || [''])[0]);
check('a walk-through thing is marked as one', /\/\/ Cell - .*walk-through/.test(file), (file.match(/\/\/ Cell[^\n]*/) || [''])[0]);
check('each solid line names the thing it came from', /^solid\([^)]*\)\s+\/\/ Floor - /m.test(file), (file.match(/^solid[^\n]*/m) || [''])[0]);
check('a ceiling says you walk under it, not that you stand on it',
  /^solid\([^)]*\)\s+\/\/ Ceiling - .*walk under it/m.test(file), (file.match(/^solid[^\n]*Ceiling[^\n]*/m) || [''])[0]);
check('a crate says you can step onto it',
  /^solid\([^)]*\)\s+\/\/ Crate - .*step onto it at 80cm/m.test(file), (file.match(/^solid[^\n]*Crate[^\n]*/m) || [''])[0]);
check('where the player starts is said in words', /^playerStart\([^)]*\)\s+\/\/ .*facing \d+ degrees/m.test(file), (file.match(/^playerStart[^\n]*/m) || [''])[0]);
check('nothing in the generated file has trailing whitespace', !/[ \t]+$/m.test(file), JSON.stringify((file.match(/^.*[ \t]+$/m) || [''])[0]));
check('it starts the player somewhere', /^playerStart\(-?\d+, -?\d+, -?\d+\)(\s+\/\/.*)?$/m.test(file));
check('it ends with a game loop', /every frame \{[\s\S]*playerStep\(\)[\s\S]*render3d/.test(file));

const list = plugins.scanPlugins(path.join(root, 'plugins'), path.join(root, '.no-user-plugins'));
try {
  volt.compile(file, { baseDir: null, extraDirs: plugins.libraryDirs(list) });
  console.log('pass  the game file it writes actually compiles');
} catch (e) { failed++; console.log('FAIL  the game file does not compile: ' + e.message); }

const linked = W.makeObj('script', { name: 'Arcane Spell', when: 'frame', file: 'Scripts/spell.volt', fn: 'arcaneSpell' });
W.S.objects.push(linked);
const linkedGame = W.genGameFile({ hud: true });
check('a linked World Studio script is imported and called', linkedGame.includes('import "Scripts/spell.volt"') && /fn script_Arcane_Spell\(\) \{\n  arcaneSpell\(\)/.test(linkedGame));
const tempProject = fs.mkdtempSync(path.join(require('os').tmpdir(), 'volt-world-script-'));
try {
  fs.mkdirSync(path.join(tempProject, 'Scripts'));
  fs.writeFileSync(path.join(tempProject, 'Scripts', 'spell.volt'), 'fn arcaneSpell() {\n  magic3d 0, 100, 0, 180, "#9d6bff", 500\n}\n');
  volt.compile(linkedGame, { baseDir: tempProject, extraDirs: plugins.libraryDirs(list) });
  console.log('pass  a game with a linked World Studio script compiles');
} catch (e) { failed++; console.log('FAIL  a linked World Studio script does not compile: ' + e.message); }
finally { fs.rmSync(tempProject, { recursive: true, force: true }); }
W.roomScene();

// ---- 2. saving again keeps everything around the world ----
const edited = file
  .replace('WALK_SPEED = 400', 'WALK_SPEED = 900')
  .replace('every frame {', 'let score = 0\n\nevery frame {')
  .replace('  render3d', '  render3d\n  write "Score: " + text(score) at 10, 10 shadow');
W.S.objects.push(Object.assign(JSON.parse(JSON.stringify(W.S.objects[0])), { id: 99, name: 'Mezzanine', y: 400 }));
const saved = W.spliceWorld(edited);
check('a file with the markers can be saved into', saved != null);
check('a changed setting survives', saved.includes('WALK_SPEED = 900'));
check('hand-written code survives', saved.includes('let score = 0') && saved.includes('write "Score: "'));
check('the world is brought up to date', saved.includes('Mezzanine'));
check('nothing is duplicated', saved.split(W.MARK_OPEN).length === 2 && saved.split('import "game.volt"').length === 2);
check('a file without the markers is left alone', W.spliceWorld('#html\nprint "hi"\n') === null);
try {
  volt.compile(saved, { baseDir: null, extraDirs: plugins.libraryDirs(list) });
  console.log('pass  the saved-over file still compiles');
} catch (e) { failed++; console.log('FAIL  the saved-over file does not compile: ' + e.message); }

// ---- 3. reading a world back in ----
const tidy = (l) => JSON.stringify(l.map((o) => { const c = { ...o }; delete c.id; return Object.fromEntries(Object.keys(c).sort().map((k) => [k, c[k]])); }));
const before = tidy(W.S.objects);
W.S = { world: W.S.world, objects: [] };
const res = W.importSource(saved);
check('the saved world is found', res.ok && res.how === 'saved world', JSON.stringify(res));
check('every thing comes back, field for field', tidy(W.S.objects) === before);

const example = fs.readFileSync(path.join(root, 'examples', '30_world_studio_game.volt'), 'utf8');
W.S = { world: W.S.world, objects: [] };
const read = W.importSource(example);
check('a hand-written game file can be read too', read.ok);
check('its spawn comes from playerStart', W.S.objects.some((o) => o.kind === 'spawn' && o.z === 600));
check('solid and scenery are told apart', W.S.objects.find((o) => o.name === 'Floor').solid === true && W.S.objects.find((o) => o.name === 'CellA').solid === false);

const scene = W.genVolt({ mode: 'scene' });
check('"just the world" leaves the game out', scene.includes('block3d') && !/^every frame \{/m.test(scene));

// ---- 3b. a part with a script, an effect, a child part and a character ----
W.S = { world: W.S.world, objects: [] };
W.nextId = 1;
const add = (kind, over) => { const o = W.makeObj(kind, over); W.S.objects.push(o); return o; };
const floor = add('block', { name: 'Floor', x: 0, y: -5, z: 0, w: 1200, h: 10, d: 1200 });
const sword = add('block', { name: 'Sword', x: 100, y: 90, z: -200, w: 10, h: 120, d: 10, color: '#c0c6d0' });
const gem = add('ball', { name: 'Gem', x: 100, y: 160, z: -200, r: 12, color: '#4de1ff' });
const slash = add('vfx', { name: 'Slash', effect: 'slash', when: 'fired', up: 80 });
const circle = add('vfx', { name: 'Circle', effect: 'circle', when: 'start' });
const wave = add('vfx', { name: 'Wave', effect: 'shock', when: 'near' });
const swing = add('script', { name: 'Swing', when: 'use', code: 'vfx_Slash()\nprint "swing"' });
const embers = add('vfx', { name: 'Embers', effect: 'fire', when: 'frame', rate: 6 });
const guard = add('char', { name: 'Guard', file: 'hunter', anim: 'sprint', x: 0, y: 0, z: -400, yaw: 90 });
add('spawn', { name: 'Spawn', x: 0, y: 0, z: 400 });
W.setParent(gem, sword.id);
W.setParent(slash, sword.id);
W.setParent(swing, sword.id);
W.setParent(embers, sword.id);
W.setParent(circle, sword.id);
W.setParent(wave, sword.id);
const built = W.genGameFile({ hud: true });

check('a part with things inside gets a group', /let Sword_group = group3d\(100, 90, -200\)/.test(built));
check('the part and its child part join the group', built.includes('join3d Sword, Sword_group') && built.includes('join3d Gem, Sword_group'));
check('scripts and effects are not joined to groups', !/join3d (Swing|Slash|Embers)/.test(built));
check('a script becomes a function', /fn script_Swing\(\) \{[\s\S]*vfx_Slash\(\)[\s\S]*print "swing"[\s\S]*\}/.test(built));
check('a slash becomes a real sword arc', /fn vfx_Slash\(\) \{\n  slash3d 100, 170, -200, \d+, \d+, "#dff3ff"\n\}/.test(built), (built.match(/fn vfx_Slash[\s\S]{0,90}/) || [''])[0]);
check('a magic circle becomes magic3d', /fn vfx_Circle\(\) \{\n  magic3d 100, 90, -200, \d+, "#9d6bff", \d+\n\}/.test(built), (built.match(/fn vfx_Circle[\s\S]{0,90}/) || [''])[0]);
check('a shockwave becomes shock3d', /fn vfx_Wave\(\) \{\n  shock3d 100, 90, -200, \d+, "#ffd23f"\n\}/.test(built), (built.match(/fn vfx_Wave[\s\S]{0,90}/) || [''])[0]);
check('an embers effect is still a burst', /fn vfx_Embers\(\) \{\n  burst3d 100, 120, -200, "#ff6a2a", \d+, \d+\n\}/.test(built), (built.match(/fn vfx_Embers[\s\S]{0,90}/) || [''])[0]);
check('"when the player presses E" is wired up', /if playerNear\(100, -200, 150\) and held\("e"\) \{\n    script_Swing\(\)/.test(built));
check('a repeating effect runs on its own beat', /if ws_tick % 6 == 0 \{\n    vfx_Embers\(\)/.test(built));
const runBlock = built.slice(built.indexOf('fn worldStart()'));
check('"only when called" effects are not run on their own', !/^  vfx_Slash\(\)$/m.test(runBlock));
check('the character is loaded and placed', /model3d hunter_model = "hunter.glb"/.test(built) && /let Guard = put3d\(hunter_model, 0, 0, -400, 0, 100\)/.test(built));
check('the character plays its animation', built.includes('anim3d Guard, "sprint"'));
check('the character is turned', built.includes('turn3d Guard, 900'));
check('the game file calls worldStart and worldStep', built.includes('worldStart()') && /^  worldStep\(\)/m.test(built));
try {
  volt.compile(built, { baseDir: null, extraDirs: plugins.libraryDirs(list) });
  console.log('pass  a world with scripts, effects and a character compiles');
} catch (e) { failed++; console.log('FAIL  that world does not compile: ' + e.message); }

// moving the parent carries everything inside it
W.withTree(sword, () => { sword.x += 50; sword.z -= 30; });
check('moving a part moves what is inside it', gem.x === 150 && gem.z === -230);
W.withTree(sword, () => { sword.yaw = 90; });
check('turning a part swings what is inside it', Math.abs(gem.x - 150) < 2 && Math.abs(gem.z - -230) < 2 && gem.yaw === 90, `gem at ${gem.x},${gem.z} yaw ${gem.yaw}`);

// the tree survives a save and a reload
const withTreeFile = W.genGameFile({ hud: true });
const beforeTree = tidy(W.S.objects);
W.S = { world: W.S.world, objects: [] };
W.importSource(withTreeFile);
check('the tree comes back after a reload', tidy(W.S.objects) === beforeTree);
check('script code survives the round trip', W.S.objects.find((o) => o.kind === 'script').code.includes('vfx_Slash()'));
check('a thing cannot be put inside itself', W.setParent(W.S.objects[1], W.S.objects[1].id) === false);

// ---- 4. does the panel start up? (needs jsdom: npm i -D jsdom) ----
let JSDOM = null;
try { ({ JSDOM } = require('jsdom')); } catch (e) { /* not installed */ }
if (!JSDOM) {
  console.log('skip  starting the panel up (install jsdom to run this part)');
} else {
  const shell = fs.readFileSync(path.join(srcDir, 'shell.html'), 'utf8')
    .replace('<script>/*THREE*/</script>', '').replace('<script>/*STUDIO*/</script>', '');
  const dom = new JSDOM(shell, { runScripts: 'outside-only', pretendToBeVisual: true, url: 'https://world.studio/' });
  const win = dom.window;
  // a stand-in for three.js and for the 2D canvas jsdom doesn't have
  // Properties are kept in a Map, not on the stand-in function itself: a
  // function's own "length" and "name" are read-only, so stashing there made
  // THREE.Vector3().length() come back as the number 0 and blow up.
  const mock = (name) => {
    const store = new Map();
    return new Proxy(function () {}, {
      get(t, k) {
        if (k === Symbol.toPrimitive || k === 'valueOf') return () => 0;
        if (k === 'toString') return () => name;
        if (k === 'then') return undefined;
        if (!store.has(k)) store.set(k, mock(name + '.' + String(k)));
        return store.get(k);
      },
      set(t, k, v) { store.set(k, v); return true; },
      has() { return true; },
      apply() { return mock(name + '()'); },
      construct() { return mock('new ' + name); },
    });
  };
  win.THREE = mock('THREE');
  win.ResizeObserver = class { observe() {} disconnect() {} };
  win.requestAnimationFrame = () => 0;
  win.HTMLCanvasElement.prototype.getContext = () => mock('ctx2d');
  const errors = [];
  win.addEventListener('error', (e) => errors.push(String(e.error || e.message)));
  try { win.eval(studio); } catch (e) { errors.push(e.message); }
  const $ = (s) => win.document.querySelector(s);
  const click = (s) => $(s).dispatchEvent(new win.Event('click', { bubbles: true }));

  check('the panel starts without errors', errors.length === 0, errors[0] || '');
  check('every toolbar button is there', ['#bUndo', '#bRedo', '#bDup', '#bDel', '#bPlay', '#bSave', '#bSavePlay', '#bMore', '#bLight', '#snap'].every((id) => $(id)));
  check('the parts strip is filled in', $('#tools').children.length === 15, 'got ' + $('#tools').children.length);
  check('characters, scripts and effects are in the strip', ['char', 'script', 'vfx'].every((k) => $(`#tools [data-add="${k}"]`)));
  check('the world is listed', $('#explorer').querySelectorAll('.row').length >= 10);
  win.__worldStudio.select(win.__worldStudio.scene.objects[7].id);
  check('properties start simple', $('#props').textContent.includes('Advanced') && !$('#props').textContent.includes('Roughness'));
  click('#props [data-adv]');
  check('advanced opens when asked', $('#props').textContent.includes('Shiny'));
  click('#bMore');
  check('the more menu opens', $('#modal').classList.contains('show') && $('#dlgBody').textContent.includes('Game lighting'));
  click('#dlgBody [data-act="help"]');
  check('the help page is there', $('#dlgBody').textContent.includes('Save world'));
  click('#dlgX');
  // ---- the Roblox-style ribbon, Output pane, fold-away tree and foldable
  // ---- property categories
  const fire = (el, type, opts = {}) => el.dispatchEvent(new win.MouseEvent(type, Object.assign({ bubbles: true, cancelable: true }, opts)));
  const all = (sel) => [...win.document.querySelectorAll(sel)];
  // ---- an Effect writes its own script as you set it up ----
  const vfxHost = win.__worldStudio.scene.objects.find((o) => o.kind === 'block');
  win.__worldStudio.select(vfxHost.id);
  win.__worldStudio.addPreset('vfx', null);
  const fx = win.__worldStudio.scene.objects.find((o) => o.kind === 'vfx');
  win.__worldStudio.select(fx.id);
  const fxFn = () => $('#vfxScriptFn');
  const fxCall = () => $('#vfxScriptCall');
  const setField = (k, v) => { const el = $(`#props [data-k="${k}"]`); el.value = v; el.dispatchEvent(new win.Event('input', { bubbles: true })); };
  check('an Effect shows the effect function on its own', !!fxFn() && fxFn().value.includes('fn vfx_') && fxFn().value.includes('burst3d'));
  check('and the way it is set off in a separate box', !!fxCall() && !fxCall().value.includes('fn vfx_'),
    'the call box must never carry the function - that is what caused "already exists"');
  setField('color', '#00ff00');
  check('changing the colour rewrites the script', fxFn().value.includes('#00ff00'));
  setField('effect', 'slash');
  check('changing the type rewrites the script', fxFn().value.includes('slash3d'));
  setField('when', 'use');
  check('changing the trigger rewrites the wiring', fxCall().value.includes('held("e")') && fxCall().value.includes('playerNear('));
  check('the trigger is shown as lines for worldStep, not a second worldStep',
    fxCall().value.includes('go inside worldStep()') && !/^fn worldStep\(\)/m.test(fxCall().value), fxCall().value);
  check('the effect function is still shown whole', /^fn vfx_\w+\(\) \{$/m.test(fxFn().value));
  setField('when', 'start');
  check('"at the start" points at worldStart, without redefining it',
    fxCall().value.includes('inside worldStart()') && !/^fn worldStart\(\)/m.test(fxCall().value), fxCall().value);
  setField('when', 'fired');
  check('"only when called" says so instead of wiring it up', fxCall().value.includes('Nothing sets') && !fxCall().value.includes('worldStep'));
  setField('when', 'start');
  const shown = fxFn().value.split('\n').find((l) => l.trim().startsWith('slash3d')).trim();
  check('the file gets exactly the line the panel showed', win.__worldStudio.genVolt({ mode: 'scene' }).includes(shown), shown);
  win.__worldStudio.select(fx.id);
  fire($(`#explorer .row[data-id="${fx.id}"]`), 'contextmenu', { clientX: 20, clientY: 20 });
  click('#ctx [data-cact="del"]');
  check('the test effect is cleared away again', !win.__worldStudio.scene.objects.some((o) => o.id === fx.id));

  // ---- picking several things at once ----
  const WS = win.__worldStudio;
  const blocks = WS.scene.objects.filter((o) => o.kind === 'block').slice(0, 3);
  const rowOf2 = (id) => $(`#explorer .row[data-id="${id}"]`);
  WS.select(blocks[0].id);
  check('one thing picked looks like it always did', win.document.querySelectorAll('#explorer .row.sel').length === 1);
  fire(rowOf2(blocks[1].id), 'click', { ctrlKey: true });
  check('ctrl-click adds a second', win.document.querySelectorAll('#explorer .row.sel').length === 2);
  fire(rowOf2(blocks[1].id), 'click', { ctrlKey: true });
  check('ctrl-clicking it again takes it back out', win.document.querySelectorAll('#explorer .row.sel').length === 1);
  fire(rowOf2(blocks[2].id), 'click', { shiftKey: true });
  const run = win.document.querySelectorAll('#explorer .row.sel').length;
  check('shift-click picks the whole run between the two', run >= 3, `${run} rows`);
  check('Properties switches to the many-things panel', /things picked/.test($('#props').textContent), $('#props').textContent.slice(0, 60));
  check('it says what the mix is', /\u00d7 Part|\u00d7 Wall|\u00d7 Floor/.test($('#props').textContent));

  // one colour change reaches all of them
  const chosen = [...win.document.querySelectorAll('#explorer .row.sel')].map((r) => Number(r.dataset.id)).filter(Boolean);
  const colourable = chosen.map((id) => WS.scene.objects.find((o) => o.id === id)).filter((o) => o && o.color !== undefined);
  const el = $('#props [data-k="multiColor"][type="color"]');
  el.value = '#aa3311'; el.dispatchEvent(new win.Event('input', { bubbles: true }));
  check('setting the colour sets it on every one of them',
    colourable.every((o) => o.color === '#aa3311'), colourable.map((o) => o.color).join(','));

  // and they copy, group and delete together
  const before = WS.scene.objects.length;
  click('#props [data-act="multi-dup"]');
  check('Copy all copies every one of them', WS.scene.objects.length >= before + chosen.length, `${before} -> ${WS.scene.objects.length}`);
  check('the copies end up picked, ready to move', win.document.querySelectorAll('#explorer .row.sel').length >= chosen.length);
  const afterCopy = WS.scene.objects.length;
  click('#props [data-act="multi-del"]');
  check('Delete all removes just those', WS.scene.objects.length === before, `${afterCopy} -> ${WS.scene.objects.length}`);
  check('nothing is picked afterwards', win.document.querySelectorAll('#explorer .row.sel').length === 0);

  // one folder for the lot
  WS.select(blocks[0].id);
  fire(rowOf2(blocks[1].id), 'click', { ctrlKey: true });
  click('#bFolder');
  const newFolder = WS.scene.objects.filter((o) => o.kind === 'folder').pop();
  check('Put all in a folder makes one folder holding them all',
    blocks[0].parent === newFolder.id && blocks[1].parent === newFolder.id, `${blocks[0].parent} / ${blocks[1].parent}`);
  check('grouping leaves the folder picked, not its contents', WS.sel === newFolder.id);
  // pick the two again to take them back out - "move out" on the folder
  // itself would do nothing, since the folder is already in the World
  WS.select(blocks[0].id);
  fire(rowOf2(blocks[1].id), 'click', { ctrlKey: true });
  click('#bUnparent');
  check('and they can all come back out', !blocks[0].parent && !blocks[1].parent);
  // tidy the empty folder away so later checks see the scene they expect
  WS.select(newFolder.id);
  click('#bDel');
  check('the empty folder can be deleted again', !WS.scene.objects.some((o) => o.id === newFolder.id));
  WS.select(null);
  check('clicking nothing drops the selection', win.document.querySelectorAll('#explorer .row.sel').length === 0);

  // ---- fighting: health, abilities, the backpack ----
  // a property is applied on 'input' but only committed to history on
  // 'change' - the real editor fires both
  const editField = (k, v) => {
    const el = $(`#props [data-k="${k}"]`);
    el.value = v;
    el.dispatchEvent(new win.Event('input', { bubbles: true }));
    el.dispatchEvent(new win.Event('change', { bubbles: true }));
  };
  const plain = win.__worldStudio.genVolt({ mode: 'game' });
  check('a world with no fighting in it does not drag the combat kit in',
    !plain.includes('combat.volt'), 'imported combat.volt for nothing');

  const victim = win.__worldStudio.scene.objects.find((o) => o.name === 'Crate');
  win.__worldStudio.select(victim.id);
  editField('hp', '60');
  const withHp = win.__worldStudio.genVolt({ mode: 'game' });
  check('giving a part health brings the combat kit in', withHp.includes('import "combat.volt"'));
  check('and makes it something that can be hurt',
    /let hp_Crate = target\("Crate", -?\d+, -?\d+, -?\d+, 60, \d+\)/.test(withHp),
    (withHp.match(/.*target\(.*/) || [''])[0]);
  check('the name is written as a name, not turned into a colour',
    !/target\("#/.test(withHp), (withHp.match(/.*target\(.*/) || [''])[0]);

  win.__worldStudio.select(null);
  win.__worldStudio.addPreset('ability', [0, 0]);
  const abil = win.__worldStudio.scene.objects.find((o) => o.kind === 'ability');
  win.__worldStudio.select(abil.id);
  editField('name', 'Fireball');
  win.__worldStudio.select(abil.id);
  editField('does', 'both');
  editField('damage', '25');
  editField('reach', '450');
  editField('heal', '10');   // only shown once "does" includes healing
  const abilFn = () => $('#abilityFn');
  check('an ability shows the code it turns into', !!abilFn() && /^fn ability_Fireball\(\) \{$/m.test(abilFn().value), abilFn() && abilFn().value);
  check('it waits between uses', /if not ready\("Fireball"\)/.test(abilFn().value) && /startCooldown\("Fireball", \d+\)/.test(abilFn().value));
  check('it hurts what is in reach', /damageArea\(PLAYER_X, PLAYER_Z, 450, 25\)/.test(abilFn().value), abilFn().value);
  check('and heals the player too', /healPlayer\(10\)/.test(abilFn().value));
  check('the way it is set off is a separate box, with no function in it',
    !!$('#abilityCall') && !$('#abilityCall').value.includes('fn ability_'));
  check('its key is written as a key, not a colour', /held\("e"\)/.test($('#abilityCall').value), $('#abilityCall').value);
  editField('does', 'nothing');
  check('an ability that only looks pretty does no damage', !/damageArea/.test(abilFn().value), abilFn().value);
  win.__worldStudio.select(abil.id);
  editField('does', 'damage');
  editField('key', 'none');   // redraws the form
  check('"nothing sets it off" says so instead of wiring a key',
    /Nothing sets/.test($('#abilityCall').value) && !/held\(/.test($('#abilityCall').value));
  win.__worldStudio.select(abil.id);
  editField('key', 'q');

  win.__worldStudio.addPreset('item', [300, 150]);
  const item = win.__worldStudio.scene.objects.find((o) => o.kind === 'item');
  win.__worldStudio.select(item.id);
  editField('name', 'Potion');
  win.__worldStudio.select(item.id);
  editField('count', '2');
  editField('heals', '30');
  check('an item shows its code', !!$('#itemCode') && /give\("Potion", 2, "#/.test($('#itemCode').value), $('#itemCode').value);
  check('and how it is used', /holding\(\) == "Potion"/.test($('#itemCode').value) && /healPlayer\(30\)/.test($('#itemCode').value));

  const full = win.__worldStudio.genVolt({ mode: 'game' });
  check('the ability is written into the game file', /fn ability_Fireball\(\) \{/.test(full));
  check('its key is checked every frame', /if held\("q\"\)/.test(full) || /if held\("q"\)/.test(full), (full.match(/.*held\("q.*/) || [''])[0]);
  check('the backpack is filled at the start', /give\("Potion", 2, "#/.test(full));
  check('the combat tick runs every frame', /stepCombat\(\)/.test(full));
  check('the HUD is drawn after the world', full.indexOf('render3d') < full.indexOf('worldDraw()') && /fn worldDraw\(\) \{/.test(full));
  check('drawCombat is what worldDraw does', /fn worldDraw\(\) \{\n  drawCombat\(\)/.test(full), (full.match(/fn worldDraw[\s\S]{0,40}/) || [''])[0]);

  // an item lying in the world gets something to walk into
  win.__worldStudio.select(item.id);
  const pk = $('#props [data-k="pickup"]');
  pk.checked = true;
  pk.dispatchEvent(new win.Event('input', { bubbles: true }));
  pk.dispatchEvent(new win.Event('change', { bubbles: true }));
  const withPick = win.__worldStudio.genVolt({ mode: 'game' });
  check('a dropped item is something you can see', /let pick_Potion = ball3d\(300, \d+, 150, 12, "#/.test(withPick), (withPick.match(/.*pick_Potion.*/) || [''])[0]);
  check('walking into it picks it up', /playerNear\(300, 150, 120\)/.test(withPick));
  check('and it disappears when you do', /show3d pick_Potion, 0/.test(withPick));

  // put the scene back for the checks that follow
  for (const o of [abil, item]) {
    win.__worldStudio.select(o.id);
    fire($(`#explorer .row[data-id="${o.id}"]`), 'contextmenu', { clientX: 20, clientY: 20 });
    click('#ctx [data-cact="del"]');
  }
  win.__worldStudio.select(victim.id);
  editField('hp', '0');
  check('taking the health away drops the combat kit again',
    !win.__worldStudio.genVolt({ mode: 'game' }).includes('combat.volt'));
  win.__worldStudio.select(null);

  // ---- StarterGui, StarterPack, StarterPlayer and the HUD ----
  const rows = () => [...win.document.querySelectorAll('#explorer .row')].map((r) => r.textContent.replace(/[\u25be\u25b8\u25cf]/g, '').trim());
  check('the Explorer has the three containers Roblox has',
    rows().some((t) => /StarterGui/.test(t)) && rows().some((t) => /StarterPack/.test(t)) && rows().some((t) => /StarterPlayer/.test(t)),
    rows().slice(-4).join(' | '));

  click('#explorer .row[data-player]');
  check('StarterPlayer opens the player settings', /StarterPlayer/.test($('#props').textContent) && !!$('#props [data-k="maxHp"]'));
  editField('maxHp', '150');
  editField('walk', '520');
  const playerVolt = win.__worldStudio.genVolt({ mode: 'game' });
  check('changed player settings are written out', /PLAYER_MAX_HP = 150/.test(playerVolt) && /WALK_SPEED = 520/.test(playerVolt),
    (playerVolt.match(/.*PLAYER_MAX_HP.*/) || [''])[0]);
  // only inside the StarterPlayer block - the file's own settings list at
  // the top names every one of them, changed or not
  const starterBlock = (playerVolt.split('StarterPlayer: how the player starts out')[1] || '').split('// ---')[0];
  check('and the ones left alone are not', !!starterBlock && !/RUN_SPEED|JUMP_POWER|RESPAWN_MS/.test(starterBlock), JSON.stringify(starterBlock));

  win.__worldStudio.addPreset('hud', [0, 0]);
  const hud = win.__worldStudio.scene.objects.find((o) => o.kind === 'hud');
  check('a HUD piece is filed under StarterGui, not loose in the world',
    !!win.document.querySelector(`#explorer .row[data-id="${hud.id}"]`) && !win.__worldStudio.genVolt({ mode: 'game' }).includes('block3d(0, 0, 0'));
  win.__worldStudio.select(hud.id);
  editField('name', 'Health');
  win.__worldStudio.select(hud.id);
  editField('anchor', 'bl');
  editField('hx', '10'); editField('hy', '14'); editField('w', '110'); editField('h', '10');
  editField('color', '#ff4d5e'); editField('back', '#000000'); editField('fade', '70');
  const hudBox = () => $('#hudCode');
  check('a HUD piece shows the code it turns into', !!hudBox() && /^box /m.test(hudBox().value), hudBox() && hudBox().value);
  check('it hangs off the corner you picked', /HUD_H - 24/.test(hudBox().value), hudBox().value);
  check('see-through is kept as a colour with eight digits', /#000000b3/.test(hudBox().value), hudBox().value);
  check('the bar fills from the health', /PLAYER_HP \* 108\) \/ PLAYER_MAX_HP/.test(hudBox().value), hudBox().value);

  const hudVolt = win.__worldStudio.genVolt({ mode: 'game' });
  check('the HUD is drawn in worldDraw', /fn worldDraw\(\) \{[\s\S]*?box 10, HUD_H - 24/.test(hudVolt));
  check('drawing your own health bar turns the kit\'s one off', /SHOW_HEALTH_BAR = false/.test(hudVolt));

  // words, with a font
  win.__worldStudio.addPreset('hud', [0, 0]);
  const label = win.__worldStudio.scene.objects.filter((o) => o.kind === 'hud').pop();
  win.__worldStudio.select(label.id);
  editField('name', 'Title');
  win.__worldStudio.select(label.id);
  editField('look', 'text');
  win.__worldStudio.select(label.id);
  editField('shows', 'words');
  win.__worldStudio.select(label.id);
  editField('words', 'DUNGEON');
  editField('anchor', 'tc');
  win.__worldStudio.select(label.id);
  editField('font', 'fancy');
  editField('size', '2');
  check('words are written with the font you picked',
    /write "DUNGEON" at HUD_W \/ 2/.test($('#hudCode').value) && /font "fancy"/.test($('#hudCode').value) && /size 2/.test($('#hudCode').value),
    $('#hudCode').value);
  check('and centred, because it hangs off the middle', /centered/.test($('#hudCode').value));
  win.__worldStudio.select(label.id);
  editField('anchor', 'tr');
  check('a right-hand corner ends the words at the edge instead',
    /right/.test($('#hudCode').value) && /HUD_W - /.test($('#hudCode').value), $('#hudCode').value);

  // tidy up so the checks after this see what they expect
  for (const o of [hud, label]) {
    win.__worldStudio.select(o.id);
    click('#bDel');
  }
  click('#explorer .row[data-player]');
  editField('maxHp', '100');
  editField('walk', '400');
  win.__worldStudio.select(null);

  // ---- the history list says what each step was ----
  // the button toggles, so shut it before reopening or the list goes stale
  const histShown = () => $('#histMenu').classList.contains('show');
  const histLabels = () => {
    if (histShown()) click('#bHist');
    click('#bHist');
    return [...win.document.querySelectorAll('#histMenu [data-hist]')]
      .map((b) => b.textContent.replace(/[\u25cf]/g, '').replace(/now$/, '').trim());
  };
  const beforeHist = win.__worldStudio.scene.objects.length;
  win.__worldStudio.addPreset('wall', [300, 300]);
  const added = win.__worldStudio.scene.objects[win.__worldStudio.scene.objects.length - 1];
  check('adding something is recorded by name', histLabels()[0] === `Added ${added.name}`, histLabels()[0]);
  win.__worldStudio.select(added.id);
  editField('name', 'BackWall');
  check('renaming says what it was and what it is now', /^Renamed .+ to BackWall$/.test(histLabels()[0]), histLabels()[0]);
  editField('color', '#123456');
  check('a colour change is recorded as one', histLabels()[0] === 'Recoloured BackWall', histLabels()[0]);
  editField('x', '450');
  check('a move is recorded as a move', histLabels()[0] === 'Moved BackWall', histLabels()[0]);
  editField('w', '275');
  check('a resize is told apart from a move', histLabels()[0] === 'Resized BackWall', histLabels()[0]);

  histLabels();
  check('the newest step is first and the current one is marked',
    !!win.document.querySelector('#histMenu .now'), 'no current step marked');
  check('undo names what it would undo', /^Undo: Resized BackWall/.test($('#bUndo').title), $('#bUndo').title);

  // jump three steps back in one click
  const target = [...win.document.querySelectorAll('#histMenu [data-hist]')].find((b) => /Recoloured BackWall/.test(b.textContent));
  fire(target, 'click');
  check('clicking a step goes straight there', win.__worldStudio.scene.objects.find((o) => o.id === added.id).x !== 450,
    'x should be back to what it was before the move');
  check('the steps after it are still there to go forward to', $('#bRedo').disabled === false);
  check('redo names what it would redo', /^Redo: Moved BackWall/.test($('#bRedo').title), $('#bRedo').title);
  check('the menu closes once a step is picked', !win.document.querySelector('#histMenu').classList.contains('show'));

  // and deleting is recorded too
  win.__worldStudio.select(added.id);
  fire($(`#explorer .row[data-id="${added.id}"]`), 'contextmenu', { clientX: 20, clientY: 20 });
  click('#ctx [data-cact="del"]');
  check('deleting is recorded by name', histLabels()[0] === 'Deleted BackWall', histLabels()[0]);
  if (histShown()) click('#bHist');   // close it again
  check('the world is back to what it was', win.__worldStudio.scene.objects.length === beforeHist, `${beforeHist} -> ${win.__worldStudio.scene.objects.length}`);

  // ---- model folders ----
  const toGroup = win.__worldStudio.scene.objects.find((o) => o.kind === 'block');
  win.__worldStudio.select(toGroup.id);
  fire($(`#explorer .row[data-id="${toGroup.id}"]`), 'contextmenu', { clientX: 20, clientY: 20 });
  check('a row offers "Put in a new folder"', !!$('#ctx [data-cact="folder"]'));
  click('#ctx [data-cact="folder"]');
  const folder = win.__worldStudio.scene.objects.find((o) => o.kind === 'folder');
  check('the folder is made and the part goes inside it', folder && toGroup.parent === folder.id);
  check('the folder is what is now picked', win.__worldStudio.sel === folder.id);
  const withFolder = win.__worldStudio.genVolt({ world: true });
  check('a folder becomes a group3d in the generated code', new RegExp('let \\w+ = group3d\\(').test(withFolder));
  check('the folder itself places nothing', !new RegExp('let \\w*[Ff]older\\w* = (block3d|ball3d|cyl3d|put3d|lamp3d)').test(withFolder));
  check('the part inside joins the group', /join3d \w+, \w+/.test(withFolder));
  // put it back where the later checks expect it
  fire($(`#explorer .row[data-id="${toGroup.id}"]`), 'contextmenu', { clientX: 20, clientY: 20 });
  click('#ctx [data-cact="out"]');
  check('a part can be taken back out of its folder', !toGroup.parent);

  check('the ribbon opens on Home', $('.rpage[data-rpage="home"]').classList.contains('on') && all('.rtab').length === 3);
  click('.rtab[data-rtab="view"]');
  check('the View tab holds the camera and show buttons',
    $('.rpage[data-rpage="view"]').classList.contains('on') &&
    ['#vFrame', '#vFocus', '#vGrid', '#vAxes', '#vZoomIn', '#vZoomOut'].every((id) => $('.rpage[data-rpage="view"] ' + id)));
  click('.rtab[data-rtab="build"]');
  check('the Build tab holds starting over and the game file',
    ['#bRoom', '#bEmpty', '#bUnparent', '#bLoad', '#bCode'].every((id) => $('.rpage[data-rpage="build"] ' + id)));
  click('.rtab[data-rtab="home"]');
  check('every ribbon group is captioned', all('.rpage .grp').every((g) => g.querySelector('.gcap')));
  check('no ribbon button is a bare glyph with nothing to read',
    all('.rpage .tb').every((b) => (b.textContent || '').trim().length > 2 || b.title));

  check('Output starts folded away and already has a line in it',
    $('#pOutput').dataset.open === '0' && $('#outLog').textContent.includes('World Studio ready'));
  const logs = all('#outLog .logline').length;
  win.__worldStudio.addPreset('spawn', [0, 0]);   // refused, with a toast
  check('a toast is kept in Output instead of only flashing past',
    all('#outLog .logline').length === logs + 1 && $('#outCount').textContent.includes('new'));
  click('#bOutput');
  check('the Output button opens it and clears the unseen count',
    $('#pOutput').dataset.open === '1' && $('#outCount').textContent === '');

  const host = win.__worldStudio.scene.objects[0];
  win.__worldStudio.select(host.id);
  win.__worldStudio.addPreset('script', null);
  const hostRow = () => $(`#explorer .row[data-id="${host.id}"]`);
  const openRows = all('#explorer .row').length;
  check('a thing with something inside it gets a fold arrow', !hostRow().querySelector('.caret').classList.contains('leaf'));
  fire(hostRow().querySelector('[data-fold]'), 'click');
  check('folding a row hides what is inside it', all('#explorer .row').length === openRows - 1);
  fire(hostRow().querySelector('[data-fold]'), 'click');
  check('unfolding brings it back', all('#explorer .row').length === openRows);

  fire(hostRow(), 'contextmenu', { clientX: 30, clientY: 30 });
  check('right-clicking a row opens a menu',
    $('#ctx').classList.contains('show') &&
    ['script', 'vfx', 'dup', 'rename', 'out', 'focus', 'del'].every((a) => $(`#ctx [data-cact="${a}"]`)));
  check('"Move out to World" is off for something already in the World', $('#ctx [data-cact="out"]').disabled);
  const inside = win.__worldStudio.scene.objects.find((o) => o.parent === host.id);
  click('#ctx [data-cact="focus"]');
  fire($(`#explorer .row[data-id="${inside.id}"]`), 'contextmenu', { clientX: 30, clientY: 30 });
  check('"Move out to World" is live for something inside a part', !$('#ctx [data-cact="out"]').disabled);
  click('#ctx [data-cact="out"]');
  check('it moves the thing out', !inside.parent);

  win.__worldStudio.select(host.id);
  check('properties are grouped under foldable headings', all('#props .cathead').length >= 2 && all('#props .cat').every((c) => c.querySelector('.catbody')));
  const firstCat = all('#props .cathead')[0].dataset.cat;
  fire($(`#props [data-cat="${firstCat}"]`), 'click');
  check('clicking a heading folds that category', $(`#props [data-cat="${firstCat}"]`).closest('.cat').classList.contains('shut'));
  fire($(`#props [data-cat="${firstCat}"]`), 'click');
  check('clicking it again opens it', !$(`#props [data-cat="${firstCat}"]`).closest('.cat').classList.contains('shut'));

  const count = win.__worldStudio.scene.objects.length;
  click('#tools [data-add="wall"]');
  check('clicking a part adds one', win.__worldStudio.scene.objects.length === count + 1);
  click('#bSave');
  check('saving outside Volt Studio shows the code instead', $('#code') && $('#code').value.includes('import "game.volt"'));
  check('nothing threw along the way', errors.length === 0, errors[0] || '');
}

process.exitCode = failed ? 1 : 0;
