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
  grabConst('CHAR_ANIMS'), grabConst('WHENS'), grabConst('VFX_PRESETS'), grabConst('FX_FIELDS'), grabConst('fxKind'), grabConst('playerDefaults'), grabConst('worldDefaults'),
  'let S = { world: worldDefaults(), objects: [], player: playerDefaults() };', 'let nextId = 1;', 'const modelCache = new Map();',
  grabConst('byId'), grabConst('childrenOf'), grabFn('descendants'), grabFn('depthOf'), grabFn('canParent'),
  grabFn('setParent'), grabFn('treeSnapshot'), grabFn('treeApply'), grabFn('withTree'),
  grabConst('charKey'), grabConst('identish'),
  grabFn('uniqueName'), grabFn('makeObj'), grabFn('roomScene'), grabFn('makeObjQuiet'),
  grabConst('RESERVED'), grabFn('identFor'),
  'const q = (c) => \'"\' + hex6(c, \'#999999\') + \'"\';', 'const r = (v) => Math.round(num(v));',
  grabConst('KIT'), grabFn('solidBoxes'), grabConst('spawnOf'),
  grabConst('MARK_OPEN'), grabConst('MARK_CLOSE'),
  grabFn('compactObj'), grabFn('worldLines'), grabFn('genGameFile'), grabFn('spliceWorld'), grabFn('genVolt'), grabFn('importSource'),
  'return { get S() { return S; }, set S(v) { S = Object.assign({ player: playerDefaults() }, v); if (!Array.isArray(S.player.hotbar)) S.player.hotbar = playerDefaults().hotbar; S.player.hotbar = Array.from({ length: 10 }, (_, i) => Object.assign({ name: \'\', count: 0 }, S.player.hotbar[i] || {})); }, get nextId() { return nextId; }, set nextId(v) { nextId = v; },',
  '         roomScene, makeObj, genGameFile, spliceWorld, genVolt, importSource, setParent, childrenOf, withTree, MARK_OPEN, MARK_CLOSE };',
].join('\n\n'))();

// ---- 1. the game file it writes ----
W.roomScene();
W.S.player.hotbar[0] = { name: 'SWORD', count: 1 };
W.S.player.hotbar[1] = { name: 'POTION', count: 4 };
const file = W.genGameFile({ hud: true });
check('the game file is an #html program', file.startsWith('#html\n') && file.includes('canvas 320, 180'));
check('it imports the player kit', file.includes('import "game.volt"'));
check('it includes the configured ten-slot hotbar', file.includes('HOTBAR_ITEMS = ["SWORD","POTION","","","","","","","",""]') && file.includes('HOTBAR_COUNTS = [1,4,0,0,0,0,0,0,0,0]') && file.includes('hotbarStep()') && file.includes('hotbarDraw()'));
check('it has settings you can change', /^WALK_SPEED = \d+/m.test(file) && /^JUMP_POWER = \d+/m.test(file));
check('the world sits between the markers', file.indexOf(W.MARK_OPEN) < file.indexOf(W.MARK_CLOSE));
check('it builds the world', /let Floor = block3d\(/.test(file));
check('it lists what stops the player', /^clearSolids\(\)$/m.test(file) && /^solid\(-?\d+, -?\d+, \d+, \d+, -?\d+, -?\d+\)$/m.test(file));
check('it starts the player somewhere', /^playerStart\(-?\d+, -?\d+, -?\d+\)$/m.test(file));
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
check('player hotbar data survives a save and reload', W.S.player.hotbar[0].name === 'SWORD' && W.S.player.hotbar[1].count === 4);
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
const decorFolder = add('folder', { name: 'Decor' });
const weaponFolder = add('folder', { name: 'Weapons' });
const swordModel = add('group', { name: 'SwordModel', x: 20, y: 30, z: 40 });
const pommel = add('block', { name: 'Pommel', x: 20, y: 30, z: 40, w: 12, h: 12, d: 12 });
W.setParent(weaponFolder, decorFolder.id);
W.setParent(swordModel, weaponFolder.id);
W.setParent(pommel, swordModel.id);
add('spawn', { name: 'Spawn', x: 0, y: 0, z: 400 });
W.setParent(gem, sword.id);
W.setParent(slash, sword.id);
W.setParent(swing, sword.id);
W.setParent(embers, sword.id);
W.setParent(circle, sword.id);
W.setParent(wave, sword.id);
const built = W.genGameFile({ hud: true });

check('a part with things inside gets a group', /let Sword_group = group3d\(100, 90, -200\)/.test(built));
check('Folders are organizational and do not become runtime parts', !built.includes('let Decor =') && !built.includes('let Weapons ='));
check('a Model is emitted as a real group3d container', /let SwordModel = group3d\(20, 30, 40\)/.test(built) && built.includes('join3d Pommel, SwordModel'));
check('the part and its child part join the group', built.includes('join3d Sword, Sword_group') && built.includes('join3d Gem, Sword_group'));
check('scripts and effects are not joined to groups', !/join3d (Swing|Slash|Embers)/.test(built));
check('a script becomes a function', /fn script_Swing\(\) \{[\s\S]*vfx_Slash\(\)[\s\S]*print "swing"[\s\S]*\}/.test(built));
check('a slash becomes a real sword arc', /fn vfx_Slash\(\) \{\n  slash3d 100, 170, -200, \d+, \d+, "#dff3ff"\n\}/.test(built), (built.match(/fn vfx_Slash[\s\S]{0,90}/) || [''])[0]);
check('a magic circle becomes magic3d', /fn vfx_Circle\(\) \{\n  magic3d 100, 90, -200, \d+, "#9d6bff", \d+\n\}/.test(built), (built.match(/fn vfx_Circle[\s\S]{0,90}/) || [''])[0]);
check('a shockwave becomes shock3d', /fn vfx_Wave\(\) \{\n  shock3d 100, 90, -200, \d+, "#ffd23f"\n\}/.test(built), (built.match(/fn vfx_Wave[\s\S]{0,90}/) || [''])[0]);
check('an embers effect is still a burst', /fn vfx_Embers\(\) \{\n  burst3d 100, 120, -200, "#ff6a2a", \d+, \d+\n\}/.test(built), (built.match(/fn vfx_Embers[\s\S]{0,90}/) || [''])[0]);
check('"when the player presses E" is wired up', /if playerNear\(100, -200, 150\) and held\("e"\) \{\n    script_Swing\(\)/.test(built));
check('a repeating effect runs on its own beat', /if ws_tick % 6 == 0 \{\n    vfx_Embers\(\)/.test(built));
// Stable object IDs keep nested Folder / Model parents intact after reloads,
// even when earlier scene objects have been deleted and IDs contain gaps.
const savedHierarchyState = W.S, savedHierarchyNextId = W.nextId;
decorFolder.id = 101; weaponFolder.id = 102; swordModel.id = 103; pommel.id = 104;
weaponFolder.parent = 101; swordModel.parent = 102; pommel.parent = 103;
const gapBuilt = W.genGameFile({ hud: true });
const hierarchyRead = W.importSource(gapBuilt);
const readDecor = W.S.objects.find((o) => o.name === 'Decor');
const readWeapons = W.S.objects.find((o) => o.name === 'Weapons');
const readSwordModel = W.S.objects.find((o) => o.name === 'SwordModel');
const readPommel = W.S.objects.find((o) => o.name === 'Pommel');
check('nested Folder / Model IDs survive save and reload with gaps', hierarchyRead.ok && readDecor.id === 101 && readWeapons.parent === 101 && readSwordModel.parent === 102 && readPommel.parent === 103);
W.S = savedHierarchyState; W.nextId = savedHierarchyNextId;

const runBlock = built.slice(built.indexOf('fn worldStart()'));
check('"only when called" effects are not run on their own', !/^  vfx_Slash\(\)$/m.test(runBlock));
check('the character is loaded and placed', /model3d hunter_model = "hunter.glb"/.test(built) && /let Guard = put3d\(hunter_model, 0, 0, -400, 0, 100\)/.test(built));
check('the character plays its animation', built.includes('anim3d Guard, "sprint"'));
check('the character is turned', built.includes('turn3d Guard, 900'));
check('the game file calls worldStart and worldStep', built.includes('worldStart()') && /^  worldStep\(\)/m.test(built));
check('the game loop draws the player hotbar after the 3D world', /hotbarStep\(\)[\s\S]*render3d[\s\S]*hotbarDraw\(\)/.test(built));
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
  const mock = (name) => new Proxy(function () {}, {
    get(t, k) {
      if (k === Symbol.toPrimitive || k === 'valueOf') return () => 0;
      if (k === 'toString') return () => name;
      if (k === 'then') return undefined;
      if (!t[k]) t[k] = mock(name + '.' + String(k));
      return t[k];
    },
    set(t, k, v) { t[k] = v; return true; },
    apply() { return mock(name + '()'); },
    construct() { return mock('new ' + name); },
  });
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
  check('the parts strip includes Folder and Model containers', $('#tools').children.length === 13, 'got ' + $('#tools').children.length);
  check('characters, scripts, effects, folders and Models are in the strip', ['char', 'script', 'vfx', 'folder', 'group'].every((k) => $(`#tools [data-add="${k}"]`)));
  check('the Player > Backpack > Hotbar section exists', $('#explorer').textContent.includes('Player') && $('#explorer').textContent.includes('Backpack') && $('#explorer').textContent.includes('Hotbar'));
  click('#explorer [data-player-section="hotbar"]');
  check('selecting Hotbar opens ten-slot player properties', $('#props').textContent.includes('Default Hotbar') && $('#props').textContent.includes('10 quick slots'));
  click('#explorer [data-player-section="slot"][data-player-slot="0"]');
  check('individual hotbar slots can be configured', $('#props').textContent.includes('Hotbar slot 1') && $('#props').textContent.includes('Item name'));
  check('hotbar slots can be drag-reordered in the Player tree', studio.includes('dragPlayerSlot') && studio.includes('Hotbar slots reordered'));
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
  const count = win.__worldStudio.scene.objects.length;
  click('#tools [data-add="wall"]');
  check('clicking a part adds one', win.__worldStudio.scene.objects.length === count + 1);
  click('#bSave');
  check('saving outside Volt Studio shows the code instead', $('#code') && $('#code').value.includes('import "game.volt"'));
  check('nothing threw along the way', errors.length === 0, errors[0] || '');
}

process.exitCode = failed ? 1 : 0;
