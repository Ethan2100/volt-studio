// =====================================================================
//  World Studio - a Roblox-Studio-style 3D world editor for Volt Studio.
//
//  Runs inside Volt Studio as a "panel" plugin (sandboxed iframe, no Node).
//  Units match Volt's 3D runtime exactly: 1 unit = 1 cm, y is up, yaw 0
//  looks along -z and turning right makes yaw bigger. The viewport is built
//  in metres (cm / 100), like lib/volt3d.js, so what you see here is what
//  block3d / ball3d / cyl3d / lamp3d will make in the game.
//
//  The world lives inside your .volt file: Export writes the Volt code plus
//  one "// world-studio: {...}" comment line that this editor can load back.
// =====================================================================
(() => {
'use strict';

const D2R = Math.PI / 180;
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const num = (v, d = 0) => { v = Number(v); return Number.isFinite(v) ? v : d; };
const hex6 = (c, d = '#8a8f99') => (/^#[0-9a-f]{6}$/i.test(c || '') ? c.toLowerCase() : d);

// ---------------------------------------------------------------------
//  The scene model (plain data - this is what gets undone / saved)
// ---------------------------------------------------------------------
const KIND = {
  block: { label: 'Part', icon: '▣' },
  folder: { label: 'Folder', icon: '📁' },
  group: { label: 'Model', icon: '◆' },
  ball: { label: 'Ball', icon: '●' },
  cyl: { label: 'Pillar', icon: '▮' },
  lamp: { label: 'Light', icon: '✦' },
  spawn: { label: 'Spawn', icon: '⚑' },
  model: { label: '3D Model', icon: '▧' },
  char: { label: 'Character', icon: '☻' },
  script: { label: 'Script', icon: '✎' },
  vfx: { label: 'Effect', icon: '✺' },
};
// Scripts and effects have no size and no place in the world of their own -
// they belong to whatever they sit under, like a Script inside a Part.
const ATTACHED = new Set(['script', 'vfx']);

// The characters the character-pack plugin ships, and what they can do.
// The panel can't read files itself, so the bytes are fetched through the
// editor (see askHostForModel).
const CHAR_PACK = 'character-pack';
// Whatever .glb files the character-pack plugin holds - ask the editor for
// the list at startup, so dropping another pack's models into that folder
// is all it takes to get them here. These are the ones that ship with it.
let CHARACTERS = ['coworker_cyan', 'coworker_gold', 'coworker_red', 'hunter', 'raider', 'raider2', 'ninja', 'wolf', 'bear', 'deer'];
// What a model can do is read from the model itself once it loads; this is
// only what the Properties panel offers before then.
const CHAR_ANIMS = ['idle', 'walk', 'sprint', 'static', 'sit', 'die', 'pick-up', 'emote-yes', 'emote-no',
  'holding-right', 'holding-left', 'holding-both', 'holding-right-shoot', 'holding-both-shoot',
  'attack-melee-right', 'attack-melee-left', 'attack-kick-right', 'interact-right', 'drive'];
// A model with no animations in it (the animals, and most scenery packs)
// can still be placed - it just stands there.
const animsOf = (name) => { const c = modelCache.get(charKey(name)); return c ? c.anims : null; };
const isAnimal = (name) => { const a = animsOf(name); return a ? a.length === 0 : ['wolf', 'bear', 'deer'].includes(name); };

// When a script or an effect runs.
const WHENS = {
  start: 'When the game starts',
  frame: 'Every frame',
  near: 'When the player is close',
  use: 'When the player presses E close by',
  fired: 'Only when something else calls it',
};
// Effects are bursts of glowing specks (burst3d), which is what Volt has in
// 3D. A preset is just a set of numbers, so people can make their own.
const VFX_PRESETS = {
  sparks: { label: 'Sparks', kind: 'burst', color: '#ffb84d', count: 40, speed: 320, up: 60, rate: 0 },
  fire: { label: 'Fire', kind: 'burst', color: '#ff6a2a', count: 26, speed: 150, up: 30, rate: 6 },
  smoke: { label: 'Smoke', kind: 'burst', color: '#8c8f99', count: 18, speed: 90, up: 70, rate: 10 },
  magic: { label: 'Magic dust', kind: 'burst', color: '#9d6bff', count: 50, speed: 260, up: 90, rate: 0 },
  blood: { label: 'Impact', kind: 'burst', color: '#c0392b', count: 34, speed: 420, up: 50, rate: 0 },
  heal: { label: 'Heal', kind: 'burst', color: '#5fe0a0', count: 30, speed: 180, up: 20, rate: 0 },
  dust: { label: 'Dust', kind: 'burst', color: '#b8a888', count: 22, speed: 120, up: 10, rate: 0 },
  slash: { label: 'Slash (sword arc)', kind: 'slash', color: '#dff3ff', size: 220, up: 120, rate: 0 },
  circle: { label: 'Magic circle', kind: 'magic', color: '#9d6bff', size: 320, ms: 1400, up: 0, rate: 0 },
  shock: { label: 'Shockwave', kind: 'shock', color: '#ffd23f', size: 420, up: 0, rate: 0 },
  beam: { label: 'Beam', kind: 'beam', color: '#ff5a4d', len: 900, thick: 26, up: 120, rate: 0 },
};
const FX_FIELDS = {   // what each kind lets you change
  burst: ['count', 'speed', 'up'],
  slash: ['size', 'up'],
  magic: ['size', 'ms'],
  shock: ['size', 'up'],
  beam: ['len', 'thick', 'up'],
};
const fxKind = (o) => (VFX_PRESETS[o.effect] || VFX_PRESETS.sparks).kind;// Loaded .glb bytes never live on a scene object (S.objects must stay small,
// JSON-serializable data - it's undone, autosaved and exported as text).
// This cache holds the actual THREE.Group + measured size per filename, for
// this session only. A world loaded back from a .volt file knows the
// filename but has no mesh until the person re-attaches that file.
const modelCache = new Map();   // filename -> { scene, box:{x,y,z}, center:{x,y,z} }
const charKey = (name) => 'pack:' + name + '.glb';
const identish = (name) => String(name || '').replace(/[^A-Za-z0-9_]+/g, '_').replace(/^_+|_+$/g, '') || 'thing';
const charAsked = new Set();   // characters already requested from the editor this session
const playerDefaults = () => ({ hotbarEnabled: true, hotbar: Array.from({ length: 10 }, () => ({ name: '', count: 0 })) });
const worldDefaults = () => ({
  title: 'My 3D world', bg: '#05060a', fog: 1600, ambient: 8, fov: 75, shadows: true,
  torch: 60, torchRange: 1800, sky: -1, bloom: 0, vignette: 0, grain: 0,
});
let S = { world: worldDefaults(), objects: [], player: playerDefaults() };
let nextId = 1;
const byId = (id) => S.objects.find((o) => o.id === id);

// ---------------------------------------------------------------------
//  The tree: anything can sit inside anything else, like Roblox's
//  Explorer. parent 0 means "straight in the world". Moving or turning a
//  thing carries everything under it, and the code it writes uses
//  group3d / join3d so the finished game does the same.
// ---------------------------------------------------------------------
const childrenOf = (id) => S.objects.filter((o) => o.parent === id);
function descendants(id, out = []) {
  for (const c of childrenOf(id)) { out.push(c); descendants(c.id, out); }
  return out;
}
function depthOf(o) {
  let d = 0, p = o.parent;
  while (p) { const up = byId(p); if (!up) break; d++; p = up.parent; }
  return d;
}
// Stops someone dropping a thing inside itself (or inside its own child).
function canParent(child, parentId) {
  if (!parentId) return true;
  if (child.id === parentId) return false;
  return !descendants(child.id).some((d) => d.id === parentId);
}
function setParent(child, parentId) {
  if (!canParent(child, parentId)) { toast('A thing can\'t go inside itself.', true); return false; }
  child.parent = parentId || 0;
  return true;
}
// Everything under `o`, with where it sits relative to `o` right now.
function treeSnapshot(o) {
  return descendants(o.id).map((c) => ({ c, dx: c.x - o.x, dy: c.y - o.y, dz: c.z - o.z, yaw: c.yaw || 0 }));
}
// Puts them back in the same spot relative to `o` after it has moved or
// turned (turning swings them around it, the way a group does in game).
function treeApply(o, snap, wasYaw) {
  if (!snap.length) return;
  const spin = ((o.yaw || 0) - wasYaw) * D2R, cos = Math.cos(spin), sin = Math.sin(spin);
  for (const s of snap) {
    s.c.x = Math.round(o.x + s.dx * cos + s.dz * sin);
    s.c.z = Math.round(o.z - s.dx * sin + s.dz * cos);
    s.c.y = Math.round(o.y + s.dy);
    s.c.yaw = Math.round(s.yaw + ((o.yaw || 0) - wasYaw));
    refreshNode(s.c);
  }
}
// Does something to `o` and carries its children along.
function withTree(o, change) {
  const snap = treeSnapshot(o), wasYaw = o.yaw || 0;
  change();
  treeApply(o, snap, wasYaw);
}

function uniqueName(base) {
  base = base.replace(/\s+/g, '');
  const used = new Set(S.objects.map((o) => o.name.toLowerCase()));
  if (!used.has(base.toLowerCase())) return base;
  let i = 2;
  while (used.has((base + i).toLowerCase())) i++;
  return base + i;
}
function makeObj(kind, over = {}) {
  const o = { id: nextId++, kind, name: '', x: 0, y: 0, z: 0, yaw: 0, visible: true, parent: 0 };
  if (kind === 'folder' || kind === 'group') Object.assign(o, { x: 0, y: 0, z: 0, yaw: 0 });
  if (kind === 'block') Object.assign(o, { w: 100, h: 100, d: 100, y: 50, color: '#8a8f99', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'ball') Object.assign(o, { r: 50, y: 50, color: '#c8ccd4', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'cyl') Object.assign(o, { r: 30, h: 300, y: 150, color: '#8a8f99', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'lamp') Object.assign(o, { y: 200, color: '#ffcc88', power: 40, range: 700 });
  if (kind === 'model') Object.assign(o, { file: '', scale: 100, solid: true });
  if (kind === 'char') Object.assign(o, { file: 'hunter', anim: 'idle', scale: 100, solid: true });
  if (kind === 'script') Object.assign(o, { when: 'frame', code: '', file: '', fn: '' });
  if (kind === 'vfx') {
    const preset = VFX_PRESETS[over.effect] || VFX_PRESETS.sparks;
    Object.assign(o, { effect: over.effect || 'sparks', when: 'start', color: preset.color, up: preset.up || 0, rate: preset.rate || 0,
      count: preset.count || 40, speed: preset.speed || 300, size: preset.size || 240, ms: preset.ms || 1200, len: preset.len || 900, thick: preset.thick || 24 });
  }
  Object.assign(o, over);
  if (!o.name) o.name = uniqueName(KIND[kind].label);
  return o;
}
function roomScene() {
  S = { world: worldDefaults(), objects: [], player: playerDefaults() };
  nextId = 1;
  const add = (kind, name, over) => { S.objects.push(makeObj(kind, Object.assign({ name }, over))); };
  add('block', 'Floor', { x: 0, y: -5, z: 0, w: 1200, h: 10, d: 1200, color: '#6a6f78' });
  add('block', 'Ceiling', { x: 0, y: 300, z: 0, w: 1200, h: 10, d: 1200, color: '#4a4d55' });
  add('block', 'WallNorth', { x: 0, y: 150, z: -600, w: 1200, h: 300, d: 20, color: '#7b808a' });
  add('block', 'WallSouth', { x: 0, y: 150, z: 600, w: 1200, h: 300, d: 20, color: '#7b808a' });
  add('block', 'WallWest', { x: -600, y: 150, z: 0, w: 20, h: 300, d: 1200, color: '#7b808a' });
  add('block', 'WallEast', { x: 600, y: 150, z: 0, w: 20, h: 300, d: 1200, color: '#7b808a' });
  add('block', 'Pillar', { x: 150, y: 150, z: -200, w: 60, h: 300, d: 60, color: '#555a63' });
  add('block', 'Crate', { x: -200, y: 40, z: -250, w: 80, h: 80, d: 80, color: '#8a6a3a' });
  add('block', 'Cell', { x: 300, y: 120, z: 100, w: 20, h: 30, d: 20, color: '#4de1ff', glow: '#4de1ff', solid: false });
  add('lamp', 'CellLight', { x: 300, y: 140, z: 100, color: '#4de1ff', power: 20, range: 500 });
  add('spawn', 'Spawn', { x: 0, y: 0, z: 400 });
}

// ---------------------------------------------------------------------
//  Undo / redo (whole-scene snapshots) + light local autosave
// ---------------------------------------------------------------------
let hist = [], hpos = -1;
const snapshot = () => JSON.stringify({ world: S.world, objects: S.objects, player: S.player, nextId });
function commit() {
  const s = snapshot();
  if (hist[hpos] === s) return;
  hist = hist.slice(0, hpos + 1);
  hist.push(s);
  if (hist.length > 200) hist.shift();
  hpos = hist.length - 1;
  try { localStorage.setItem('voltWorldStudio.scene', s); } catch (e) { /* sandboxed: no storage - the .volt file is the save */ }
  updateButtons();
}
function restore(s) {
  const d = JSON.parse(s);
  S = { world: Object.assign(worldDefaults(), d.world), objects: d.objects, player: Object.assign(playerDefaults(), d.player || {}) };
  if (!Array.isArray(S.player.hotbar)) S.player.hotbar = playerDefaults().hotbar;
  S.player.hotbar = Array.from({ length: 10 }, (_, i) => Object.assign({ name: '', count: 0 }, S.player.hotbar[i] || {}));
  nextId = d.nextId || (Math.max(0, ...S.objects.map((o) => o.id)) + 1);
  if (sel != null && !byId(sel)) sel = null;
  rebuildAll(); renderExplorer(); renderProps(); updateGizmo(); applyWorld(); updateStatus();
}
function undo() { if (hpos > 0) { hpos--; restore(hist[hpos]); updateButtons(); } }
function redo() { if (hpos < hist.length - 1) { hpos++; restore(hist[hpos]); updateButtons(); } }

// ---------------------------------------------------------------------
//  Three.js world
// ---------------------------------------------------------------------
const cv = $('#cv'), vp = $('#vp');
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: true, powerPreference: 'high-performance' });
} catch (error) {
  console.error('[World Studio] WebGL could not start:', error);
  const panel = document.createElement('div');
  panel.className = 'render-error';
  panel.innerHTML = '<strong>3D viewport could not start</strong><span>Volt could not create a WebGL graphics context. Update your graphics driver, enable hardware acceleration, then restart Volt Studio.</span><small>Technical detail: ' + esc(error && error.message ? error.message : 'WebGL initialisation failed') + '</small>';
  vp.replaceChildren(panel);
  return;
}
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
renderer.autoClear = false;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
cv.addEventListener('webglcontextlost', (event) => {
  event.preventDefault();
  toast('The 3D graphics context was lost. Try reopening World Studio.', true);
});

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, 1, 0.05, 400);
camera.rotation.order = 'YXZ';
const worldGroup = new THREE.Group(); scene.add(worldGroup);

// Editing light: bright and even so you can see what you're building
const editorRig = new THREE.Group();
editorRig.add(new THREE.HemisphereLight(0xffffff, 0x8f99b3, 1.7));
const editSun = new THREE.DirectionalLight(0xffffff, 1.4); editSun.position.set(3, 8, 5); editorRig.add(editSun);
const editFill = new THREE.DirectionalLight(0xbfd0ff, 0.9); editFill.position.set(-4, -6, -3); editorRig.add(editFill);   // lights undersides (ceilings)
scene.add(editorRig);

// Game light: the same lights the Volt runtime makes (ambient, sun for sky3d, flashlight)
const gameRig = new THREE.Group();
const ambient = new THREE.AmbientLight(0x8890b0, 0.08); gameRig.add(ambient);
const sunLight = new THREE.DirectionalLight(0xfff0d0, 0); sunLight.position.set(40, 80, 30); gameRig.add(sunLight);
const torch = new THREE.SpotLight(0xe6f2ff, 0, 20, 0.72, 0.7, 1.3);
torch.shadow.mapSize.set(1024, 1024); torch.shadow.bias = -0.0008;
const halo = new THREE.PointLight(0xc8e0ff, 0, 5.5, 1.4);
gameRig.add(torch, torch.target, halo);
gameRig.visible = false;
scene.add(gameRig);

const grid = new THREE.GridHelper(100, 100, 0x3d4660, 0x252b3c); grid.position.y = 0.001; scene.add(grid);
let showGrid = true, showAxes = true;
const axisLines = new THREE.Group();
[[0xff4d4d, 1, 0, 0], [0x4d8bff, 0, 0, 1]].forEach(([c, x, , z]) => {
  const g = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(-50 * x, 0.002, -50 * z), new THREE.Vector3(50 * x, 0.002, 50 * z)]);
  axisLines.add(new THREE.Line(g, new THREE.LineBasicMaterial({ color: c })));
});
scene.add(axisLines);

// ---- the grimy panel texture + reflection map, same recipe as lib/volt3d.js ----
let grimeTex = null, envTex = null;
function grime() {
  if (grimeTex) return grimeTex;
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = '#bdbdbd'; g.fillRect(0, 0, 256, 256);
  for (let i = 0; i < 6000; i++) {
    const v = 110 + Math.floor(Math.random() * 110);
    g.fillStyle = 'rgba(' + v + ',' + v + ',' + v + ',0.22)';
    g.fillRect(Math.random() * 256, Math.random() * 256, 1 + Math.random() * 3, 1 + Math.random() * 3);
  }
  for (let i = 0; i < 16; i++) {
    const x = Math.random() * 256, y = Math.random() * 256, r = 14 + Math.random() * 42;
    const gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, 'rgba(0,0,0,0.30)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  g.strokeStyle = 'rgba(0,0,0,0.6)'; g.lineWidth = 3; g.strokeRect(1, 1, 254, 254);
  g.strokeStyle = 'rgba(0,0,0,0.28)'; g.lineWidth = 1;
  g.beginPath(); g.moveTo(128, 0); g.lineTo(128, 256); g.moveTo(0, 128); g.lineTo(256, 128); g.stroke();
  g.fillStyle = 'rgba(0,0,0,0.55)';
  for (const p of [[9, 9], [247, 9], [9, 247], [247, 247]]) { g.beginPath(); g.arc(p[0], p[1], 2.2, 0, 6.3); g.fill(); }
  grimeTex = new THREE.CanvasTexture(c);
  grimeTex.wrapS = grimeTex.wrapT = THREE.RepeatWrapping; grimeTex.colorSpace = THREE.SRGBColorSpace; grimeTex.anisotropy = 4;
  return grimeTex;
}
function env() {
  if (envTex) return envTex;
  const pm = new THREE.PMREMGenerator(renderer);
  const s = new THREE.Scene();
  const sky = new THREE.Mesh(new THREE.SphereGeometry(10, 24, 16), new THREE.MeshBasicMaterial({ side: THREE.BackSide, vertexColors: true }));
  const p = sky.geometry.attributes.position, cols = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    const t = (p.getY(i) / 10 + 1) / 2;
    const a = t < 0.5 ? [0.01, 0.012, 0.018] : [0.09, 0.11, 0.16], b = t < 0.5 ? [0.09, 0.11, 0.16] : [0.45, 0.55, 0.75], q = t < 0.5 ? t * 2 : (t - 0.5) * 2;
    for (let j = 0; j < 3; j++) cols[i * 3 + j] = a[j] + (b[j] - a[j]) * q;
  }
  sky.geometry.setAttribute('color', new THREE.BufferAttribute(cols, 3));
  s.add(sky);
  const box = (x, y, z, w, h, c) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: c, side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); s.add(m); };
  box(4, 6, 3, 5, 3, new THREE.Color(6, 6, 5.5)); box(-6, 3, -2, 3, 4, new THREE.Color(1.5, 2.2, 3.5)); box(1, -3, 6, 6, 1.5, new THREE.Color(1.2, 1, 0.9));
  envTex = pm.fromScene(s, 0.02).texture;
  pm.dispose();
  return envTex;
}

// geometry with texture coordinates scaled so a panel is always about 2 m wide (as in the runtime)
function boxGeo(w, h, d) {
  w = Math.max(1, w | 0); h = Math.max(1, h | 0); d = Math.max(1, d | 0);
  const g = new THREE.BoxGeometry(w / 100, h / 100, d / 100), uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) { const i = f * 4 + v; uv.setXY(i, uv.getX(i) * dims[f][0] / 200, uv.getY(i) * dims[f][1] / 200); }
  return g;
}
function ballGeo(r) {
  r = Math.max(1, r | 0);
  const g = new THREE.SphereGeometry(r / 100, 32, 22), uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.max(1, r * 6.2832 / 200), uv.getY(i) * Math.max(1, r * 3.1416 / 200));
  return g;
}
function cylGeo(r, h) {
  r = Math.max(1, r | 0); h = Math.max(1, h | 0);
  const g = new THREE.CylinderGeometry(r / 100, r / 100, h / 100, 32), uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.max(1, r * 6.2832 / 200), uv.getY(i) * Math.max(1, h / 200));
  return g;
}

// ---- one three.js node per scene object ----
const nodes = new Map();
const outlineMat = new THREE.LineBasicMaterial({ color: 0xffc400, depthTest: false, transparent: true });
function boundsOf(o) {   // [w, h, d] in metres, plus a y offset, for the selection outline
  switch (o.kind) {
    case 'block': return [o.w / 100, o.h / 100, o.d / 100, 0];
    case 'ball': return [o.r / 50, o.r / 50, o.r / 50, 0];
    case 'cyl': return [o.r / 50, o.h / 100, o.r / 50, 0];
    case 'lamp': return [0.3, 0.3, 0.3, 0];
    case 'group': return [0.34, 0.34, 0.34, 0];
    case 'folder': return [0.01, 0.01, 0.01, 0];
    case 'script': case 'vfx': return [0.26, 0.32, 0.26, 0.62];
    case 'char':
    case 'model': {
      const c = modelCache.get(o.kind === 'char' ? charKey(o.file) : o.file), sc = (o.scale || 100) / 100;
      if (c && c.box) return [Math.max(0.05, c.box.x * sc), Math.max(0.05, c.box.y * sc), Math.max(0.05, c.box.z * sc), c.center.y * sc];
      return [0.6, 1.2, 0.6, 0.6];
    }
    default: return [0.5, 1.7, 0.5, 0.85];
  }
}
function buildNode(o) {
  let n;
  const material = () => {
    const m = new THREE.MeshStandardMaterial({ color: hex6(o.color), map: grime(), roughness: 0.92, metalness: 0.04 });
    if (o.glow) { m.emissive.set(hex6(o.glow)); m.emissiveIntensity = 1.4; }
    if (o.shine) { m.roughness = clamp(o.rough, 0, 100) / 100; m.metalness = clamp(o.metal, 0, 100) / 100; if (o.metal > 5) { m.envMap = env(); m.envMapIntensity = 1; } }
    return m;
  };
  if (o.kind === 'block' || o.kind === 'ball' || o.kind === 'cyl') {
    const g = o.kind === 'block' ? boxGeo(o.w, o.h, o.d) : o.kind === 'ball' ? ballGeo(o.r) : cylGeo(o.r, o.h);
    n = new THREE.Mesh(g, material());
    n.castShadow = n.receiveShadow = true;
  } else if (o.kind === 'folder') {
    n = new THREE.Group(); n.userData.hiddenContainer = true; n.visible = false;
  } else if (o.kind === 'group') {
    n = new THREE.Group();
    const marker = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.28, 0.28), new THREE.MeshBasicMaterial({ color: 0x55c7ff, wireframe: true, transparent: true, opacity: 0.7 }));
    n.add(marker); n.userData.marker = true;
  } else if (o.kind === 'lamp') {
    n = new THREE.Group();
    n.add(new THREE.Mesh(new THREE.SphereGeometry(0.1, 14, 10), new THREE.MeshBasicMaterial({ color: hex6(o.color, '#ffcc88') })));
    const l = new THREE.PointLight(hex6(o.color, '#ffcc88'), clamp(o.power, 0, 100) * 0.5, Math.max(1, o.range) / 100, 1.6);
    l.visible = false; n.add(l); n.userData.light = l;
  } else if (o.kind === 'model' || o.kind === 'char') {
    n = new THREE.Group();
    const key = o.kind === 'char' ? charKey(o.file) : o.file;
    if (o.kind === 'char' && o.file && !modelCache.has(key)) askHostForModel(o.file);
    const cached = key ? modelCache.get(key) : null;
    const sc = (o.scale || 100) / 100;
    if (cached && cached.scene) {
      const inst = cached.scene.clone(true);
      inst.scale.setScalar(sc);
      inst.traverse((c) => { if (c.isMesh) { c.castShadow = c.receiveShadow = true; } });
      n.add(inst);
    } else {
      const ph = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshBasicMaterial({ color: 0x5bd1ff, wireframe: true, transparent: true, opacity: 0.6 }));
      ph.position.y = 0.5; n.add(ph);
      n.userData.placeholder = true;
    }
  } else if (ATTACHED.has(o.kind)) {
    // a script or an effect has no body - a small floating tag shows where
    // it is attached, and you mostly pick it from the Things list
    n = new THREE.Group();
    const tint = o.kind === 'script' ? 0xffd23f : 0x9d6bff;
    const card = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.28, 0.04), new THREE.MeshBasicMaterial({ color: tint, transparent: true, opacity: 0.85 }));
    const stalk = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.5, 6), new THREE.MeshBasicMaterial({ color: tint, transparent: true, opacity: 0.45 }));
    stalk.position.y = 0.25; card.position.y = 0.62;
    n.add(stalk, card);
    n.userData.marker = true;
  } else {
    n = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.25, 1.65, 18), new THREE.MeshBasicMaterial({ color: 0x5bd1ff, transparent: true, opacity: 0.22, depthWrite: false }));
    body.position.y = 0.825;
    const arrow = new THREE.Mesh(new THREE.ConeGeometry(0.2, 0.55, 14), new THREE.MeshBasicMaterial({ color: 0x5bd1ff }));
    arrow.rotation.x = -Math.PI / 2; arrow.position.set(0, 1.0, -0.5);
    n.add(body, arrow);
    n.userData.marker = true;
  }
  const b = boundsOf(o);
  const outline = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(b[0] * 1.004, b[1] * 1.004, b[2] * 1.004)), outlineMat);
  outline.position.y = b[3]; outline.visible = false; outline.renderOrder = 998; outline.raycast = () => {};
  n.add(outline);
  n.userData.outline = outline;
  n.traverse((c) => { if (c !== outline) c.userData.rootId = o.id; });
  n.position.set(o.x / 100, o.y / 100, o.z / 100);
  n.rotation.y = -(o.yaw || 0) * D2R;
  n.visible = o.visible;
  return n;
}
function disposeNode(n) {
  n.traverse((c) => {
    if (c.geometry) c.geometry.dispose();
    if (c.material && c.material.dispose && c.material !== outlineMat) c.material.dispose();
  });
}
function refreshNode(o) {
  const old = nodes.get(o.id);
  if (old) { worldGroup.remove(old); disposeNode(old); }
  const n = buildNode(o);
  nodes.set(o.id, n); worldGroup.add(n);
  n.userData.outline.visible = (o.id === sel) && mode !== 'play';
  applyNodeMode(n);
  dirty = true;
}
function rebuildAll() {
  for (const n of nodes.values()) { worldGroup.remove(n); disposeNode(n); }
  nodes.clear();
  for (const o of S.objects) {
    const n = buildNode(o); nodes.set(o.id, n); worldGroup.add(n);
    n.userData.outline.visible = (o.id === sel) && mode !== 'play';
    applyNodeMode(n);
  }
  dirty = true;
}
function applyNodeMode(n) {
  const game = mode !== 'edit';
  if (n.userData.light) n.userData.light.visible = game;
  const o = S.objects.find((x) => x.id === n.userData.rootId);
  if (n.userData.hiddenContainer) n.visible = false;
  else if (n.userData.marker || n.userData.placeholder) n.visible = mode !== 'play' && !!o && o.visible !== false;
  n.userData.outline.visible = !!o && o.id === sel && mode !== 'play';
}

// ---- world settings -> scene (edit look vs. real in-game look) ----
let mode = 'edit';   // 'edit' | 'preview' | 'play'
let dirty = true;
const EDIT_BG = new THREE.Color(0x1c2231);
function skyLook(level, w) {   // mirrors __sky3d in lib/volt3d.js
  const k = clamp(level, 0, 100) / 100;
  const night = new THREE.Color('#04060d'), dusk = new THREE.Color('#2a2438'), day = new THREE.Color('#9cc4e0');
  const c = k < 0.5 ? night.clone().lerp(dusk, k * 2) : dusk.clone().lerp(day, (k - 0.5) * 2);
  return { bg: c, fogFar: (w.fog / 100) * (0.35 + 0.65 * k), amb: 0.05 + 0.75 * k, ambCol: k > 0.5 ? 0xdfe8ff : 0x7078a0, sun: 1.2 * k * k };
}
function applyWorld() {
  const w = S.world, game = mode !== 'edit';
  editorRig.visible = !game; gameRig.visible = game;
  grid.visible = showGrid && !game; axisLines.visible = showAxes && !game;
  if (!game) { scene.background = EDIT_BG; scene.fog = null; }
  else {
    let bg = new THREE.Color(hex6(w.bg, '#05060a')), far = w.fog / 100, amb = w.ambient / 100, ambCol = 0x8890b0, sun = 0;
    if (w.sky >= 0) { const s = skyLook(w.sky, w); bg = s.bg; far = s.fogFar; amb = s.amb; ambCol = s.ambCol; sun = s.sun; }
    scene.background = bg;
    scene.fog = w.fog > 0 ? new THREE.Fog(bg, 0.4, Math.max(0.5, far)) : null;
    ambient.intensity = amb; ambient.color.setHex(ambCol); sunLight.intensity = sun;
    const p = clamp(w.torch, 0, 100);
    torch.intensity = p * 1.3; torch.distance = Math.max(1, w.torchRange) / 100; halo.intensity = p * 0.3;
    torch.visible = halo.visible = p > 0;
    torch.castShadow = !!w.shadows;
  }
  const v = clamp(w.vignette, 0, 100) / 100;
  const vig = $('#vig');
  vig.style.display = game && v > 0 ? 'block' : 'none';
  vig.style.background = 'radial-gradient(ellipse at center, rgba(0,0,0,0) ' + Math.round(55 - v * 25) + '%, rgba(0,0,0,' + (0.25 + v * 0.7).toFixed(2) + ') 100%)';
  camera.fov = mode === 'play' ? w.fov : 60;
  camera.far = mode === 'play' ? 80 : 400;
  camera.updateProjectionMatrix();
  for (const n of nodes.values()) applyNodeMode(n);
  dirty = true;
}

// ---------------------------------------------------------------------
//  Editor camera (Roblox-style fly: right-drag to look, WASD/Q/E to move)
// ---------------------------------------------------------------------
const cam = { x: 4.5, y: 2.1, z: 5.2, yaw: -0.5, pitch: -0.15 };   // metres / radians; forward = (sin yaw, 0, -cos yaw)
function applyCam() {
  camera.position.set(cam.x, cam.y, cam.z);
  camera.rotation.set(cam.pitch, -cam.yaw, 0, 'YXZ');
  dirty = true;
}
function lookAtPoint(x, y, z) {
  const dx = x - cam.x, dy = y - cam.y, dz = z - cam.z;
  cam.yaw = Math.atan2(dx, -dz); cam.pitch = Math.atan2(dy, Math.hypot(dx, dz));
}
const fwd3 = () => new THREE.Vector3(Math.sin(cam.yaw) * Math.cos(cam.pitch), Math.sin(cam.pitch), -Math.cos(cam.yaw) * Math.cos(cam.pitch));
applyCam();

function sceneBounds() {
  if (!S.objects.length) return { min: new THREE.Vector3(-2, 0, -2), max: new THREE.Vector3(2, 2, 2) };
  const min = new THREE.Vector3(Infinity, Infinity, Infinity), max = new THREE.Vector3(-Infinity, -Infinity, -Infinity);
  for (const o of S.objects) {
    const b = boundsOf(o), x = o.x / 100, y = o.y / 100 + b[3], z = o.z / 100;
    min.x = Math.min(min.x, x - b[0] / 2); max.x = Math.max(max.x, x + b[0] / 2);
    min.y = Math.min(min.y, y - b[1] / 2); max.y = Math.max(max.y, y + b[1] / 2);
    min.z = Math.min(min.z, z - b[2] / 2); max.z = Math.max(max.z, z + b[2] / 2);
  }
  return { min, max };
}
function frameAll() {
  const bounds = sceneBounds(), target = bounds.min.clone().add(bounds.max).multiplyScalar(0.5);
  const span = bounds.max.clone().sub(bounds.min), aspect = Math.max(0.1, camera.aspect || 1);
  const radius = Math.max(0.5, span.length() / 2);
  const vfov = Math.max(0.1, camera.fov * D2R), hfov = 2 * Math.atan(Math.tan(vfov / 2) * aspect);
  const distance = Math.max(3, radius / Math.sin(Math.min(vfov, hfov) / 2)) * 1.15;
  cam.yaw = -0.62; cam.pitch = -0.38;
  const f = fwd3();
  cam.x = target.x - f.x * distance; cam.y = target.y - f.y * distance; cam.z = target.z - f.z * distance;
  lookAtPoint(target.x, target.y, target.z);
  applyCam();
}
function focusSelection() {
  const o = byId(sel);
  if (!o) { frameAll(); return; }
  const b = boundsOf(o), target = new THREE.Vector3(o.x / 100, o.y / 100 + b[3], o.z / 100);
  const size = Math.max(b[0], b[1], b[2], 0.4), aspect = Math.max(0.1, camera.aspect || 1);
  const vfov = Math.max(0.1, camera.fov * D2R), hfov = 2 * Math.atan(Math.tan(vfov / 2) * aspect);
  const distance = Math.max(1.5, size * Math.sqrt(3) / 2 / Math.sin(Math.min(vfov, hfov) / 2) * 1.15);
  const f = fwd3();
  cam.x = target.x - f.x * distance; cam.y = target.y - f.y * distance; cam.z = target.z - f.z * distance;
  lookAtPoint(target.x, target.y, target.z);
  applyCam();
}
function viewPreset(view) {
  const bounds = sceneBounds(), selected = byId(sel);
  const point = selected ? new THREE.Vector3(selected.x / 100, selected.y / 100 + boundsOf(selected)[3], selected.z / 100) : bounds.min.clone().add(bounds.max).multiplyScalar(0.5);
  const span = bounds.max.clone().sub(bounds.min).length(), distance = selected ? Math.max(3, focusDist()) : Math.max(4, span * 0.9);
  const angles = { front: [0, -0.08], back: [Math.PI, -0.08], left: [-Math.PI / 2, -0.08], right: [Math.PI / 2, -0.08], top: [0, -Math.PI / 2 + 0.02] };
  const a = angles[view] || angles.front;
  cam.yaw = a[0]; cam.pitch = a[1];
  const f = fwd3();
  cam.x = point.x - f.x * distance; cam.y = point.y - f.y * distance; cam.z = point.z - f.z * distance;
  applyCam(); updateGizmo();
}
const focusDist = () => { const o = byId(sel); return o ? Math.max(1.5, Math.hypot(o.x / 100 - cam.x, o.y / 100 - cam.y, o.z / 100 - cam.z)) : 10; };

// ---------------------------------------------------------------------
//  Selection, snapping, mutation helpers
// ---------------------------------------------------------------------
let sel = null, selWorld = false, selPlayer = '', selPlayerSlot = -1, tool = 'select';
const collapsedNodes = new Set();
const collapsedPlayerNodes = new Set();
const snapStep = () => num($('#snap').value, 0);
const sn = (v) => { const s = snapStep(); return s > 0 ? Math.round(v / s) * s : Math.round(v); };
const snRot = (d) => (snapStep() > 0 ? Math.round(d / 15) * 15 : Math.round(d));

function select(id) {
  sel = id; selWorld = false; selPlayer = ''; selPlayerSlot = -1;
  for (const [nid, n] of nodes) n.userData.outline.visible = (nid === id) && mode !== 'play';
  renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); dirty = true;
  if (narrow() && id != null) setDock('props');
}
function selectWorld() { sel = null; selWorld = true; selPlayer = ''; selPlayerSlot = -1; for (const n of nodes.values()) n.userData.outline.visible = false; renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); dirty = true; if (narrow()) setDock('props'); }
function selectPlayer(section, slot = -1) { sel = null; selWorld = false; selPlayer = section; selPlayerSlot = slot; for (const n of nodes.values()) n.userData.outline.visible = false; renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); dirty = true; if (narrow()) setDock('props'); }
function touch(o) { refreshNode(o); updateGizmo(); }

// ---------------------------------------------------------------------
//  Gizmos (drawn on top of everything)
// ---------------------------------------------------------------------
const gscene = new THREE.Scene();
const gizmoRoot = new THREE.Group(); gscene.add(gizmoRoot);
const AXC = { x: 0xff5252, y: 0x55e07a, z: 0x5a92ff };
const hitMat = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthTest: false, depthWrite: false });
const mkMat = (c) => new THREE.MeshBasicMaterial({ color: c, depthTest: false, transparent: true, opacity: 0.95 });
function orientAxis(g, axis) { if (axis === 'x') g.rotation.z = -Math.PI / 2; if (axis === 'z') g.rotation.x = Math.PI / 2; }
function tagged(group, axis, parts) { parts.forEach((m) => { m.renderOrder = 999; m.userData.axis = axis; group.add(m); }); return group; }
function mkArrow(axis) {
  const mat = mkMat(AXC[axis]), g = new THREE.Group();
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.8, 8), mat); shaft.position.y = 0.4;
  const cone = new THREE.Mesh(new THREE.ConeGeometry(0.1, 0.3, 14), mat); cone.position.y = 0.95;
  const hit = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 1.2, 6), hitMat); hit.position.y = 0.65;
  tagged(g, axis, [shaft, cone, hit]); orientAxis(g, axis); return g;
}
function mkScaleHandle(axis) {
  const mat = mkMat(AXC[axis]), g = new THREE.Group();
  const stalk = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.8, 8), mat); stalk.position.y = 0.4;
  const cube = new THREE.Mesh(new THREE.BoxGeometry(0.17, 0.17, 0.17), mat); cube.position.y = 0.9;
  const hit = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.55, 0.3), hitMat); hit.position.y = 0.78;
  tagged(g, axis, [stalk, cube, hit]); orientAxis(g, axis); return g;
}
const moveG = new THREE.Group(), scaleG = new THREE.Group(), rotG = new THREE.Group();
['x', 'y', 'z'].forEach((a) => { moveG.add(mkArrow(a)); scaleG.add(mkScaleHandle(a)); });
{
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1, 0.025, 8, 72), mkMat(0xffd23f));
  const hit = new THREE.Mesh(new THREE.TorusGeometry(1, 0.13, 6, 40), hitMat);
  tagged(rotG, 'yaw', [ring, hit]); rotG.rotation.x = Math.PI / 2;
}
const rotHolder = new THREE.Group(); rotHolder.add(rotG);
gizmoRoot.add(moveG, scaleG, rotHolder);
gizmoRoot.visible = false;

function gizmoSupports(o) {
  if (!o || mode === 'play') return null;
  if (tool === 'move') return moveG;
  if (tool === 'rotate') return (o.kind === 'lamp' || o.kind === 'ball') ? null : rotHolder;
  if (tool === 'scale') return (o.kind === 'lamp' || o.kind === 'spawn') ? null : scaleG;
  return null;
}
function activeGizmo() { const g = gizmoSupports(byId(sel)); return g && gizmoRoot.visible ? g : null; }
function updateGizmo() {
  const o = byId(sel), g = gizmoSupports(o) && o.kind !== 'folder';
  moveG.visible = scaleG.visible = rotHolder.visible = false;
  gizmoRoot.visible = !!g;
  if (!g) { dirty = true; return; }
  g.visible = true;
  gizmoRoot.position.set(o.x / 100, o.y / 100, o.z / 100);
  gizmoRoot.rotation.set(0, tool === 'scale' ? -(o.yaw || 0) * D2R : 0, 0);
  gizmoRoot.updateMatrixWorld(true);
  dirty = true;
}
function gizmoScaleFor() { return Math.max(0.35, gizmoRoot.position.distanceTo(camera.position) * 0.15); }

// ---------------------------------------------------------------------
//  Pointer interaction
// ---------------------------------------------------------------------
const raycaster = new THREE.Raycaster();
const ndc = new THREE.Vector2();
function setRay(e) {
  const r = cv.getBoundingClientRect();
  ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  camera.updateMatrixWorld(true);
  raycaster.setFromCamera(ndc, camera);
  return raycaster.ray;
}
function pickObject(e) {
  setRay(e);
  const hits = raycaster.intersectObjects(worldGroup.children.filter((n) => n.visible), true).filter((h) => h.object.userData.rootId != null);
  return hits.length ? hits[0] : null;
}
function pickGizmo(e) {
  const g = activeGizmo(); if (!g) return null;
  gizmoRoot.scale.setScalar(gizmoScaleFor()); gizmoRoot.updateMatrixWorld(true);
  setRay(e);
  const hits = raycaster.intersectObject(g, true).filter((h) => h.object.userData.axis);
  return hits.length ? hits[0].object.userData.axis : null;
}
// parameter t of the point on the line (o + t*d) that is closest to the ray
function axisParam(ray, o, d) {
  const w0 = new THREE.Vector3().subVectors(o, ray.origin);   // axis point minus ray point
  const b = d.dot(ray.direction), dd = d.dot(w0), ee = ray.direction.dot(w0);
  const den = 1 - b * b;
  return Math.abs(den) < 1e-5 ? 0 : (b * ee - dd) / den;
}
const AX = { x: new THREE.Vector3(1, 0, 0), y: new THREE.Vector3(0, 1, 0), z: new THREE.Vector3(0, 0, 1) };
const YUP = new THREE.Vector3(0, 1, 0);
let drag = null, keys = new Set(), dragMoved = false;

cv.addEventListener('contextmenu', (e) => e.preventDefault());
cv.addEventListener('pointerdown', (e) => {
  cv.focus(); cv.setPointerCapture(e.pointerId); dragMoved = false;
  if (mode === 'play') { if (e.button === 0 || e.button === 2) drag = { type: 'playlook', x: e.clientX, y: e.clientY }; return; }
  if (e.button === 2) { drag = { type: 'look', x: e.clientX, y: e.clientY }; return; }
  if (e.button === 1) { e.preventDefault(); drag = { type: 'pan', x: e.clientX, y: e.clientY }; return; }
  if (e.button !== 0) return;
  if (e.altKey) {
    const o = byId(sel); const f = fwd3(); const d = focusDist();
    const piv = o ? new THREE.Vector3(o.x / 100, o.y / 100, o.z / 100) : new THREE.Vector3(cam.x + f.x * d, cam.y + f.y * d, cam.z + f.z * d);
    drag = { type: 'orbit', x: e.clientX, y: e.clientY, piv, dist: piv.distanceTo(new THREE.Vector3(cam.x, cam.y, cam.z)) };
    return;
  }
  const axis = pickGizmo(e);
  const o = byId(sel);
  if (axis && o) { beginGizmoDrag(e, axis, o); if (drag) { drag.x = e.clientX; drag.y = e.clientY; } return; }
  const hit = pickObject(e);
  if (!hit) { drag = { type: 'click-empty', x: e.clientX, y: e.clientY }; return; }
  const id = hit.object.userData.rootId, ob = byId(id);
  if (id !== sel) select(id);
  if (tool === 'select' || tool === 'move') {
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -ob.y / 100);
    const p0 = new THREE.Vector3();
    if (setRay(e).intersectPlane(plane, p0)) drag = { type: 'body', plane, p0, start: { x: ob.x, z: ob.z }, id, x: e.clientX, y: e.clientY, tree: treeSnapshot(ob), treeYaw: ob.yaw || 0 };
  }
});
function beginGizmoDrag(e, axis, o) {
  const ray = setRay(e);
  const origin = new THREE.Vector3(o.x / 100, o.y / 100, o.z / 100);
  if (axis === 'yaw') {
    const plane = new THREE.Plane(YUP, -origin.y), p = new THREE.Vector3();
    if (!ray.intersectPlane(plane, p)) return;
    drag = { type: 'rot', id: o.id, plane, origin, a0: Math.atan2(p.x - origin.x, -(p.z - origin.z)), yaw0: o.yaw || 0, tree: treeSnapshot(o), treeYaw: o.yaw || 0 };
    return;
  }
  const dir = tool === 'scale' ? AX[axis].clone().applyAxisAngle(YUP, -(o.yaw || 0) * D2R) : AX[axis].clone();
  drag = { type: tool === 'scale' ? 'scale' : 'move', id: o.id, axis, dir, origin, t0: axisParam(ray, origin, dir), start: Object.assign({}, o), tree: treeSnapshot(o), treeYaw: o.yaw || 0 };
}
cv.addEventListener('pointermove', (e) => {
  if (!drag) { hoverCursor(e); return; }
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  if (Math.abs(dx) + Math.abs(dy) > 2) dragMoved = true;
  switch (drag.type) {
    case 'look': cam.yaw += dx * 0.005; cam.pitch = clamp(cam.pitch - dy * 0.005, -1.5, 1.5); drag.x = e.clientX; drag.y = e.clientY; applyCam(); updateGizmo(); break;
    case 'playlook': play.yaw += dx * 0.3; play.pitch = clamp(play.pitch - dy * 0.3, -80, 80); drag.x = e.clientX; drag.y = e.clientY; break;
    case 'pan': {
      const s = 0.0016 * focusDist() * 3;
      const right = new THREE.Vector3(Math.cos(cam.yaw), 0, Math.sin(cam.yaw)), up = new THREE.Vector3(0, 1, 0);
      cam.x += (-right.x * dx + up.x * dy) * s; cam.y += (dy * s); cam.z += (-right.z * dx) * s;
      drag.x = e.clientX; drag.y = e.clientY; applyCam(); updateGizmo(); break;
    }
    case 'orbit': {
      cam.yaw += dx * 0.006; cam.pitch = clamp(cam.pitch - dy * 0.006, -1.5, 1.5);
      const f = fwd3();
      cam.x = drag.piv.x - f.x * drag.dist; cam.y = drag.piv.y - f.y * drag.dist; cam.z = drag.piv.z - f.z * drag.dist;
      drag.x = e.clientX; drag.y = e.clientY; applyCam(); updateGizmo(); break;
    }
    case 'body': {
      const o = byId(drag.id); if (!o || !dragMoved) break;
      const p = new THREE.Vector3();
      if (!setRay(e).intersectPlane(drag.plane, p)) break;
      o.x = sn(drag.start.x + (p.x - drag.p0.x) * 100); o.z = sn(drag.start.z + (p.z - drag.p0.z) * 100);
      nodes.get(o.id).position.set(o.x / 100, o.y / 100, o.z / 100);
      afterTransform(o); break;
    }
    case 'move': {
      const o = byId(drag.id); if (!o) break;
      const t = axisParam(setRay(e), drag.origin, drag.dir);
      o[drag.axis] = sn(drag.start[drag.axis] + (t - drag.t0) * 100);
      nodes.get(o.id).position.set(o.x / 100, o.y / 100, o.z / 100);
      afterTransform(o); break;
    }
    case 'rot': {
      const o = byId(drag.id); if (!o) break;
      const p = new THREE.Vector3();
      if (!setRay(e).intersectPlane(drag.plane, p)) break;
      const a = Math.atan2(p.x - drag.origin.x, -(p.z - drag.origin.z));
      let d = (a - drag.a0) / D2R; d = ((d + 540) % 360) - 180;
      o.yaw = snRot(drag.yaw0 + d); o.yaw = ((o.yaw + 540) % 360) - 180 || 0;
      nodes.get(o.id).rotation.y = -o.yaw * D2R;
      afterTransform(o); break;
    }
    case 'scale': {
      const o = byId(drag.id); if (!o) break;
      const t = axisParam(setRay(e), drag.origin, drag.dir);
      scaleObject(o, drag, (t - drag.t0) * 100);
      refreshNode(o); afterTransform(o); break;
    }
  }
});
function scaleObject(o, d, delta) {
  const s = d.start;
  if (o.kind === 'model') {   // one uniform scale %, not a per-axis size
    o.scale = Math.max(1, Math.round(s.scale + delta));
    o.x = s.x; o.y = s.y; o.z = s.z;
    return;
  }
  const key = o.kind === 'block' ? { x: 'w', y: 'h', z: 'd' }[d.axis] : o.kind === 'ball' ? 'r' : (d.axis === 'y' ? 'h' : 'r');
  const nv = Math.max(1, sn(s[key] + delta)), applied = nv - s[key];
  o[key] = nv;
  o.x = s.x; o.y = s.y; o.z = s.z;
  if (o.kind === 'block' || (o.kind === 'cyl' && d.axis === 'y')) {   // keep the opposite face where it was
    o.x = Math.round(s.x + d.dir.x * applied / 2); o.y = Math.round(s.y + d.dir.y * applied / 2); o.z = Math.round(s.z + d.dir.z * applied / 2);
  }
}
function afterTransform(o) {
  if (drag && drag.tree && drag.id === o.id) treeApply(o, drag.tree, drag.treeYaw);
  updateGizmo(); syncPropValues(); updateStatus(); dirty = true;
}
function endDrag(e) {
  if (!drag) return;
  const t = drag.type;
  if (t === 'click-empty' && !dragMoved) { select(null); }
  if (['body', 'move', 'rot', 'scale'].includes(t) && dragMoved) commit();
  drag = null;
  try { cv.releasePointerCapture(e.pointerId); } catch (err) { /* already released */ }
}
cv.addEventListener('pointerup', endDrag);
cv.addEventListener('pointercancel', endDrag);
function hoverCursor(e) {
  if (mode === 'play') { cv.style.cursor = 'grab'; return; }
  cv.style.cursor = pickGizmo(e) ? 'pointer' : 'default';
}
cv.addEventListener('wheel', (e) => {
  if (mode === 'play') return;
  e.preventDefault();
  const f = fwd3(), step = clamp(focusDist() * 0.12, 0.3, 8) * (e.deltaY > 0 ? -1 : 1);
  cam.x += f.x * step; cam.y += f.y * step; cam.z += f.z * step;
  applyCam(); updateGizmo();
}, { passive: false });

// drag a toolbox item into the world
cv.addEventListener('dragover', (e) => { e.preventDefault(); });
cv.addEventListener('drop', (e) => {
  e.preventDefault();
  const k = e.dataTransfer.getData('text/plain');
  if (!PRESETS[k]) return;
  const p = new THREE.Vector3();
  const ok = setRay(e).intersectPlane(new THREE.Plane(YUP, 0), p) && p.distanceTo(camera.position) < 120;
  addPreset(k, ok ? [p.x * 100, p.z * 100] : null);
});

// ---------------------------------------------------------------------
//  Adding / deleting objects
// ---------------------------------------------------------------------
const PRESETS = {
  block: { kind: 'block', label: 'Part', glyph: '▣', over: { w: 100, h: 100, d: 100 }, base: 'Part' },
  folder: { kind: 'folder', label: 'Folder', glyph: '📁', over: {}, base: 'Folder' },
  group: { kind: 'group', label: 'Model', glyph: '◆', over: {}, base: 'Model' },
  wall: { kind: 'block', label: 'Wall', glyph: '▬', over: { w: 400, h: 300, d: 20, color: '#7b808a' }, base: 'Wall' },
  floor: { kind: 'block', label: 'Floor', glyph: '▱', over: { w: 800, h: 10, d: 800, color: '#6a6f78' }, base: 'Floor' },
  pillar: { kind: 'cyl', label: 'Pillar', glyph: '▮', over: { r: 30, h: 300 }, base: 'Pillar' },
  ball: { kind: 'ball', label: 'Ball', glyph: '●', over: { r: 50 }, base: 'Ball' },
  lamp: { kind: 'lamp', label: 'Light', glyph: '✦', over: {}, base: 'Light' },
  spawn: { kind: 'spawn', label: 'Spawn', glyph: '⚑', over: {}, base: 'Spawn' },
  model: { kind: 'model', label: 'Import 3D', glyph: '▧', over: {}, base: 'Model' },
  char: { kind: 'char', label: 'Character', glyph: '☻', over: {}, base: 'Character' },
  script: { kind: 'script', label: 'Script', glyph: '✎', over: {}, base: 'Script' },
  vfx: { kind: 'vfx', label: 'Effect', glyph: '✺', over: {}, base: 'Effect' },
};
function dropPoint(at) {   // where a new object should land: the drop point, or ~6m ahead of the camera
  let x, z;
  if (at) { x = at[0]; z = at[1]; }
  else {
    const f = fwd3(), ray = new THREE.Ray(new THREE.Vector3(cam.x, cam.y, cam.z), f), p = new THREE.Vector3();
    const flat = { x: Math.sin(cam.yaw), z: -Math.cos(cam.yaw) };
    if (ray.intersectPlane(new THREE.Plane(YUP, 0), p) && Math.hypot(p.x - cam.x, p.z - cam.z) < 6) { x = p.x * 100; z = p.z * 100; }
    else { x = (cam.x + flat.x * 6) * 100; z = (cam.z + flat.z * 6) * 100; }
  }
  return [x, z];
}
function addPreset(key, at) {
  const P = PRESETS[key];
  if (key === 'spawn') { const old = S.objects.filter((o) => o.kind === 'spawn'); if (old.length >= 1) { toast('Only the first Spawn is used by the game - moved it here instead.'); const o = old[0]; if (at) { o.x = sn(at[0]); o.z = sn(at[1]); touch(o); select(o.id); commit(); syncPropValues(); } return; } }
  if (key === 'model') { pickModelFile(at); return; }
  const o = makeObj(P.kind, Object.assign({ name: uniqueName(P.base) }, P.over));
  const selectedOwner = byId(sel);
  const containerOwner = selectedOwner && ['folder', 'group'].includes(selectedOwner.kind) ? selectedOwner : null;
  if (P.kind === 'folder' || P.kind === 'group') {
    o.parent = containerOwner ? containerOwner.id : 0;
    if (P.kind === 'group' && containerOwner) { o.x = containerOwner.x; o.y = containerOwner.y; o.z = containerOwner.z; }
    S.objects.push(o); refreshNode(o); select(o.id); renderExplorer(); commit();
    toast(containerOwner ? `${o.name} added inside ${containerOwner.name}` : `${o.name} added to the World`);
    return;
  }
  if (ATTACHED.has(P.kind)) {
    // like Roblox's "insert into the thing you have selected"
    const owner = byId(sel);
    const host_ = owner && !ATTACHED.has(owner.kind) ? owner : null;
    o.parent = host_ ? host_.id : (containerOwner ? containerOwner.id : 0);
    o.x = host_ ? host_.x : 0; o.y = host_ ? host_.y : 0; o.z = host_ ? host_.z : 0;
    S.objects.push(o); refreshNode(o); select(o.id); renderExplorer(); commit();
    toast(host_ ? `${o.name} added inside ${host_.name}` : `${o.name} added - drop it inside a part in the Things list to tie it to one`);
    return;
  }
  const [x, z] = dropPoint(at);
  o.x = sn(x); o.z = sn(z);
  if (containerOwner) { o.parent = containerOwner.id; o.x = containerOwner.x; o.y = containerOwner.y; o.z = containerOwner.z; }
  if (P.kind === 'char') { o.y = 0; askHostForModel(o.file); }
  if (P.kind === 'block') o.y = key === 'floor' ? -o.h / 2 : o.h / 2;
  else if (P.kind === 'cyl') o.y = o.h / 2;
  else if (P.kind === 'ball') o.y = o.r;
  else if (P.kind === 'spawn') o.y = 0;
  S.objects.push(o); refreshNode(o); select(o.id); commit();
}
// ---------------------------------------------------------------------
//  Model (.glb) import - the sandboxed panel has no filesystem access, so
//  this reads the file with the browser's own file picker, straight into
//  memory; nothing is sent anywhere. Only the filename is ever stored on
//  the scene object - the real asset has to sit next to the .volt file
//  for `model3d name = "file.glb"` to find it at compile time.
// ---------------------------------------------------------------------
function loadModelBytes(file, onLoaded, onFail) {
  const reader = new FileReader();
  reader.onerror = () => onFail(new Error('Could not read the file'));
  reader.onload = () => {
    new THREE.GLTFLoader().parse(reader.result, '', (g) => {
      const box = new THREE.Box3().setFromObject(g.scene);
      const fin1 = (v) => (Number.isFinite(v) && v > 0 ? v : 0.1), fin0 = (v) => (Number.isFinite(v) ? v : 0);
      const size = box.getSize(new THREE.Vector3()), center = box.getCenter(new THREE.Vector3());
      modelCache.set(file.name, { scene: g.scene, box: { x: fin1(size.x), y: fin1(size.y), z: fin1(size.z) }, center: { x: fin0(center.x), y: fin0(center.y), z: fin0(center.z) } });
      onLoaded(file.name);
    }, () => onFail(new Error("Couldn't read \"" + file.name + "\" - use a .glb file with its textures packed inside.")));
  };
  reader.readAsArrayBuffer(file);
}
// The panel is sandboxed, so it can't open the character pack's .glb files
// itself - it asks Volt Studio for the bytes (see docs/PLUGINS.md) and
// parses them here. Nothing is stored on the scene but the name.
// Which characters are in the pack right now. Anything dropped into the
// plugin's folder - another Quaternius or Kenney pack, your own export -
// turns up in the Character list next time the panel opens.
function askHostForCharacters() {
  if (!host.ok) return;
  const req = host.req++;
  host.waiting.set(req, (files) => {
    if (!files || !files.length) return;
    CHARACTERS = files.map((f) => f.replace(/\.glb$/i, ''));
    const picked = byId(sel);
    if (picked && picked.kind === 'char') renderProps();
  });
  toHost('assetList', { req, plugin: CHAR_PACK });
}

function askHostForModel(name) {
  const key = charKey(name);
  if (!name || charAsked.has(key) || modelCache.has(key)) return;
  if (!host.ok) return;   // no editor to ask: the placeholder box stands in
  charAsked.add(key);
  const req = host.req++;
  host.waiting.set(req, (base64) => {
    if (!base64) { toast(`Couldn't load the character "${name}" - is the character-pack plugin there?`, true); return; }
    try {
      const bin = atob(base64), bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      new THREE.GLTFLoader().parse(bytes.buffer, '', (g) => {
        const box = new THREE.Box3().setFromObject(g.scene);
        const size = box.getSize(new THREE.Vector3()), center = box.getCenter(new THREE.Vector3());
        const fin1 = (v) => (Number.isFinite(v) && v > 0 ? v : 0.1), fin0 = (v) => (Number.isFinite(v) ? v : 0);
        modelCache.set(key, {
          scene: g.scene,
          anims: (g.animations || []).map((a) => a.name),
          box: { x: fin1(size.x), y: fin1(size.y), z: fin1(size.z) },
          center: { x: fin0(center.x), y: fin0(center.y), z: fin0(center.z) },
        });
        for (const o of S.objects) if (o.kind === 'char' && o.file === name) refreshNode(o);
        const picked = byId(sel);
        if (picked && picked.kind === 'char' && picked.file === name) renderProps();
        updateGizmo(); dirty = true;
      }, () => toast(`"${name}" could not be read as a model.`, true));
    } catch (e) { toast('That character could not be unpacked.', true); }
  });
  toHost('asset', { req, plugin: CHAR_PACK, file: name + '.glb' });
}

function pickModelFile(at) {
  const inp = document.createElement('input');
  inp.type = 'file'; inp.accept = '.glb,.gltf,model/gltf-binary';
  inp.addEventListener('change', () => {
    const file = inp.files && inp.files[0]; if (!file) return;
    loadModelBytes(file, (name) => {
      const [x, z] = dropPoint(at);
      const parent = byId(sel), container = parent && ['folder', 'group'].includes(parent.kind) ? parent : null;
      const o = makeObj('model', { name: uniqueName('Model'), file: name, scale: 100 });
      o.parent = container ? container.id : 0;
      o.x = container ? container.x : sn(x); o.y = container ? container.y : 0; o.z = container ? container.z : sn(z);
      S.objects.push(o); refreshNode(o); select(o.id); commit();
    }, (err) => toast(err.message, true));
  });
  inp.click();
}
function rebrowseModel(o) {
  if (!o || o.kind !== 'model') return;
  const inp = document.createElement('input');
  inp.type = 'file'; inp.accept = '.glb,.gltf,model/gltf-binary';
  inp.addEventListener('change', () => {
    const file = inp.files && inp.files[0]; if (!file) return;
    loadModelBytes(file, (name) => { o.file = name; refreshNode(o); renderProps(); commit(); toast('Loaded "' + name + '"'); },
      (err) => toast(err.message, true));
  });
  inp.click();
}
function deleteSelected() {
  const o = byId(sel); if (!o) return;
  const going = [o, ...descendants(o.id)];
  for (const g of going) {
    const n = nodes.get(g.id);
    if (n) { worldGroup.remove(n); disposeNode(n); nodes.delete(g.id); }
  }
  const ids = new Set(going.map((g) => g.id));
  S.objects = S.objects.filter((x) => !ids.has(x.id));
  if (going.length > 1) toast(`Deleted ${o.name} and the ${going.length - 1} thing${going.length > 2 ? 's' : ''} inside it.`);
  sel = null; renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); commit(); dirty = true;
}
function duplicateSelected() {
  const o = byId(sel); if (!o) return;
  if (o.kind === 'spawn') { toast('A world only needs one Spawn.'); return; }
  const c = JSON.parse(JSON.stringify(o));
  c.id = nextId++; c.name = uniqueName(o.name.replace(/\d+$/, '') || KIND[o.kind].label);
  c.x += snapStep() || 100;
  S.objects.push(c); refreshNode(c);
  // whatever was inside comes along, sitting the same way inside the copy
  const copyKids = (fromId, toId, shiftX) => {
    for (const k of childrenOf(fromId)) {
      const kc = JSON.parse(JSON.stringify(k));
      kc.id = nextId++; kc.parent = toId; kc.name = uniqueName(k.name.replace(/\d+$/, '') || KIND[k.kind].label);
      kc.x += shiftX;
      S.objects.push(kc); refreshNode(kc);
      copyKids(k.id, kc.id, shiftX);
    }
  };
  copyKids(o.id, c.id, snapStep() || 100);
  select(c.id); renderExplorer(); commit();
}

// ---------------------------------------------------------------------
//  Explorer + parts + properties panels
// ---------------------------------------------------------------------
function renderExplorer() {
  const box = $('#explorer');
  const twist = (id, has, collapsed) => has ? `<button class="twisty" data-toggle="${id}" title="Expand / collapse">${collapsed ? '▸' : '▾'}</button>` : '<span class="twisty blank"></span>';
  let h = `<div class="row world${selWorld ? ' sel' : ''}" data-world="1" data-drop="0">${twist('0', true, collapsedNodes.has(0))}<span class="ic">🌐</span><span class="nm">World</span></div>`;
  if (!collapsedNodes.has(0)) {
    if (!S.objects.length) h += '<div class="empty">Nothing here yet. Add a part from the left.</div>';
    const draw = (parentId, depth) => {
      for (const o of S.objects) {
        if ((o.parent || 0) !== parentId) continue;
        const kids = childrenOf(o.id).length, collapsed = collapsedNodes.has(o.id);
        h += `<div class="row${o.id === sel ? ' sel' : ''}${o.visible ? '' : ' hidden'}" data-id="${o.id}" data-drop="${o.id}" draggable="true" style="padding-left:${8 + depth * 14}px">` +
          twist(String(o.id), kids > 0, collapsed) +
          `<span class="ic">${KIND[o.kind].icon}</span><span class="nm">${esc(o.name)}</span>` +
          (kids ? `<span class="kids" title="${kids} inside">${kids}</span>` : '') +
          (ATTACHED.has(o.kind) || o.kind === 'folder' ? '' : `<span class="eye" data-eye="${o.id}" title="Show / hide">${o.visible ? '👁' : '◌'}</span>`) +
          '</div>';
        if (!collapsed) draw(o.id, depth + 1);
      }
    };
    draw(0, 0);
  }
  const playerRow = (id, label, icon, depth, collapsed) => `<div class="row player-row${selPlayer === id ? ' sel' : ''}" data-player-section="${id}" style="padding-left:${8 + depth * 14}px"><button class="twisty" data-player-toggle="${id}">${collapsed ? '▸' : '▾'}</button><span class="ic">${icon}</span><span class="nm">${label}</span></div>`;
  h += playerRow('player', 'Player', '♙', 0, collapsedPlayerNodes.has('player'));
  if (!collapsedPlayerNodes.has('player')) {
    h += playerRow('backpack', 'Backpack', '▣', 1, collapsedPlayerNodes.has('backpack'));
    if (!collapsedPlayerNodes.has('backpack')) {
      h += playerRow('hotbar', 'Hotbar', '▤', 2, collapsedPlayerNodes.has('hotbar'));
      if (!collapsedPlayerNodes.has('hotbar')) {
        for (let i = 0; i < 10; i++) {
          const item = S.player.hotbar[i] || { name: '', count: 0 };
          h += `<div class="row player-slot${selPlayer === 'slot' && selPlayerSlot === i ? ' sel' : ''}" data-player-section="slot" data-player-slot="${i}" data-player-drop="${i}" draggable="true" style="padding-left:50px"><span class="twisty blank"></span><span class="ic">${i === 9 ? '0' : i + 1}</span><span class="nm">${esc(item.name || 'Empty slot')}</span>${item.count > 0 ? `<span class="kids">${item.count}</span>` : ''}</div>`;
        }
      }
    }
  }
  box.innerHTML = h;
}
$('#explorer').addEventListener('click', (e) => {
  const toggle = e.target.closest('[data-toggle]');
  if (toggle) { const id = Number(toggle.dataset.toggle); collapsedNodes.has(id) ? collapsedNodes.delete(id) : collapsedNodes.add(id); renderExplorer(); return; }
  const ptoggle = e.target.closest('[data-player-toggle]');
  if (ptoggle) { const id = ptoggle.dataset.playerToggle; collapsedPlayerNodes.has(id) ? collapsedPlayerNodes.delete(id) : collapsedPlayerNodes.add(id); renderExplorer(); return; }
  const eye = e.target.closest('[data-eye]');
  if (eye) { const o = byId(Number(eye.dataset.eye)); o.visible = !o.visible; refreshNode(o); renderExplorer(); renderProps(); commit(); return; }
  const row = e.target.closest('.row'); if (!row) return;
  if (row.dataset.playerSection) selectPlayer(row.dataset.playerSection, row.dataset.playerSlot == null ? -1 : Number(row.dataset.playerSlot));
  else if (row.dataset.world) selectWorld(); else select(Number(row.dataset.id));
});

let dragRow = null, dragPlayerSlot = null;
$('#explorer').addEventListener('dragstart', (e) => {
  const slot = e.target.closest('.player-slot[data-player-slot]');
  if (slot) {
    dragPlayerSlot = Number(slot.dataset.playerSlot);
    e.dataTransfer.effectAllowed = 'move';
    try { e.dataTransfer.setData('text/plain', 'player-slot:' + dragPlayerSlot); } catch (err) { /* some browsers */ }
    return;
  }
  const row = e.target.closest('.row[data-id]');
  if (!row) return;
  dragRow = Number(row.dataset.id);
  e.dataTransfer.effectAllowed = 'move';
  try { e.dataTransfer.setData('text/plain', 'row:' + dragRow); } catch (err) { /* some browsers */ }
});
$('#explorer').addEventListener('dragover', (e) => {
  $$('#explorer .row.drop').forEach((r) => r.classList.remove('drop'));
  if (dragPlayerSlot != null) {
    const slot = e.target.closest('.player-slot[data-player-drop]');
    if (slot) { e.preventDefault(); slot.classList.add('drop'); }
    return;
  }
  if (dragRow == null) return;
  const row = e.target.closest('[data-drop]');
  if (!row) return;
  e.preventDefault();
  row.classList.add('drop');
});
$('#explorer').addEventListener('dragleave', (e) => { const row = e.target.closest('[data-drop], .player-slot'); if (row) row.classList.remove('drop'); });
$('#explorer').addEventListener('drop', (e) => {
  $$('#explorer .row.drop').forEach((r) => r.classList.remove('drop'));
  if (dragPlayerSlot != null) {
    const slot = e.target.closest('.player-slot[data-player-drop]');
    const from = dragPlayerSlot; dragPlayerSlot = null;
    if (!slot) return;
    e.preventDefault();
    const to = Number(slot.dataset.playerDrop);
    if (from === to) return;
    const item = S.player.hotbar[from];
    S.player.hotbar[from] = S.player.hotbar[to];
    S.player.hotbar[to] = item;
    renderExplorer(); renderProps(); commit();
    toast('Hotbar slots reordered');
    return;
  }
  const row = e.target.closest('[data-drop]');
  if (dragRow == null || !row) return;
  e.preventDefault();
  const child = byId(dragRow), into = Number(row.dataset.drop);
  dragRow = null;
  if (!child || child.parent === into) return;
  if (!setParent(child, into)) return;
  renderExplorer(); renderProps(); commit();
  toast(into ? `${child.name} is now inside ${byId(into).name}` : `${child.name} moved out into the world`);
});
$('#explorer').addEventListener('dragend', () => { dragRow = null; dragPlayerSlot = null; $$('#explorer .row.drop').forEach((r) => r.classList.remove('drop')); });
$('#explorer').addEventListener('dblclick', (e) => { const row = e.target.closest('.row[data-id]'); if (row) { select(Number(row.dataset.id)); focusSelection(); } });

function renderTools() {
  $('#tools').innerHTML = Object.entries(PRESETS).map(([k, p]) => `<div class="tool" draggable="true" data-add="${k}"><span class="g">${p.glyph}</span>${p.label}</div>`).join('');
}
$('#tools').addEventListener('click', (e) => { const t = e.target.closest('[data-add]'); if (t) addPreset(t.dataset.add, null); });
$('#tools').addEventListener('dragstart', (e) => { const t = e.target.closest('[data-add]'); if (t) e.dataTransfer.setData('text/plain', t.dataset.add); });

// ---- property forms ----
const fNum = (k, l, v, o = {}) => `<label class="f"><span>${l}</span><input type="number" data-k="${k}" value="${v}" step="${o.step || 1}"${o.min != null ? ` min="${o.min}"` : ''}${o.max != null ? ` max="${o.max}"` : ''}></label>`;
const fText = (k, l, v) => `<label class="f"><span>${l}</span><input type="text" data-k="${k}" value="${esc(v)}" spellcheck="false"></label>`;
const fColor = (k, l, v) => `<label class="f"><span>${l}</span><span class="colorpair"><input type="color" data-k="${k}" value="${hex6(v)}"><input type="text" data-k="${k}" data-hex="1" value="${hex6(v)}" maxlength="7" spellcheck="false"></span></label>`;
const fCheck = (k, l, v) => `<label class="f"><span>${l}</span><input type="checkbox" data-k="${k}"${v ? ' checked' : ''}></label>`;
const fSelect = (k, l, v, opts) => `<label class="f"><span>${l}</span><select data-k="${k}">${opts.map((op) => { const [val, text] = Array.isArray(op) ? op : [op, op]; return `<option value="${esc(val)}"${String(val) === String(v) ? ' selected' : ''}>${esc(text)}</option>`; }).join('')}</select></label>`;
const fCode = (k, v) => `<div class="codewrap"><textarea class="code" data-k="${k}" spellcheck="false" rows="9" placeholder="Volt code, like:\n\nscore += 1\nburst3d 0, 100, 0, \"#ffd23f\", 30, 300">${esc(v)}</textarea></div>`;
const fRange = (k, l, v, min, max) => `<label class="f"><span>${l}</span><input type="range" data-k="${k}" min="${min}" max="${max}" value="${v}"><span class="val">${v}</span></label>`;
let showAdvanced = false;
const advSection = (inner) => (inner ? `<div class="sec adv" data-adv>${showAdvanced ? '▾' : '▸'} Advanced</div>` + (showAdvanced ? inner : '') : '');

function parentOptions(o) {
  const out = [['0', 'the World']];
  for (const p of S.objects) {
    if (p.id === o.id || ATTACHED.has(p.kind) || !canParent(o, p.id)) continue;
    out.push([String(p.id), '— '.repeat(Math.min(3, depthOf(p))) + p.name]);
  }
  return out;
}

function objForm(o) {
  const kids = childrenOf(o.id);
  if (o.kind === 'folder') return `<div class="sec">Folder</div>` + fText('name', 'Name', o.name) + fSelect('parent', 'Inside', String(o.parent || 0), parentOptions(o)) + `<div class="note">A Folder is organizational only. Put parts, models, scripts and effects inside it. It does not change positions or create a game object.</div>`;
  if (o.kind === 'group') return `<div class="sec">Model</div>` + fText('name', 'Name', o.name) + fSelect('parent', 'Inside', String(o.parent || 0), parentOptions(o)) + `<div class="note">A Model groups everything inside it. Move or rotate the Model to move its descendants together in the game.</div>` + '<div class="sec">Pivot</div>' + fNum('x', 'Position X (cm)', o.x) + fNum('y', 'Position Y (cm)', o.y) + fNum('z', 'Position Z (cm)', o.z) + fNum('yaw', 'Rotation Y (°)', o.yaw);
  let h = `<div class="sec">${KIND[o.kind].label}</div>` + fText('name', 'Name', o.name) +
    fSelect('parent', 'Inside', String(o.parent || 0), parentOptions(o));
  if (kids.length) h += `<div class="note">${kids.length} thing${kids.length > 1 ? 's' : ''} inside: ${kids.map((k) => esc(k.name)).join(', ')}. Moving or turning this one takes them along.</div>`;

  if (o.kind === 'script') {
    h += '<div class="sec">Runs</div>' + fSelect('when', 'When', o.when, Object.entries(WHENS));
    const owner = o.parent ? byId(o.parent) : null;
    h += `<div class="note">${owner ? `This script belongs to <b>${esc(owner.name)}</b>, which your code can use by that name (it is the part's number in the game).` : 'This script is loose in the world. Drop it inside a part in the Things list to tie it to that part.'}</div>`;
    h += '<div class="sec">Source</div><div class="btnrow"><button type="button" class="tb" data-act="script-open">' + (o.file ? 'Open script file' : 'Create script file') + '</button></div>';
    h += `<div class="note">${o.file ? `Linked to <b>${esc(o.file)}</b>${o.fn ? ` · function <b>${esc(o.fn)}</b>` : ''}.` : 'Creates a real .volt file under Scripts/ and opens it in the main code editor.'} Effects and other game code stay in the game file.</div>`;
    return h;
  }

  if (o.kind === 'vfx') {
    const owner = o.parent ? byId(o.parent) : null;
    const LABELS = {
      count: ['How many specks', { min: 1, max: 300 }],
      speed: ['How fast (cm/s)', { min: 10, step: 10 }],
      size: ['How big (cm)', { min: 10, step: 10 }],
      ms: ['How long (ms)', { min: 100, step: 100 }],
      len: ['How long (cm)', { min: 20, step: 50 }],
      thick: ['How thick (cm)', { min: 1 }],
      up: ['Height above it (cm)', { step: 10 }],
    };
    h += '<div class="sec">Effect</div>' +
      fSelect('effect', 'Looks like', o.effect, Object.entries(VFX_PRESETS).map(([k, v]) => [k, v.label])) +
      fColor('color', 'Colour', o.color);
    for (const f of FX_FIELDS[fxKind(o)]) h += fNum(f, LABELS[f][0], o[f], LABELS[f][1]);
    if (fxKind(o) === 'slash') h += '<div class="note">The arc faces the way the part it sits in is turned, so turn the part to aim the slash.</div>';
    if (fxKind(o) === 'beam') h += '<div class="note">The beam fires the way the part it sits in is turned.</div>';
    h += '<div class="sec">Runs</div>' + fSelect('when', 'When', o.when, Object.entries(WHENS));
    if (o.when === 'frame') h += fNum('rate', 'Every N frames', Math.max(1, o.rate || 1), { min: 1, max: 600 });
    h += `<div class="note">${owner ? `Goes off at <b>${esc(owner.name)}</b>.` : 'Not inside anything, so it goes off where it stands.'} A script can set it off by name: <b>vfx_${esc(identish(o.name))}()</b>.</div>`;
    h += '<div class="sec">Preset</div><div class="btnrow"><button type="button" class="tb" data-act="vfx-import">⭳ Import…</button><button type="button" class="tb" data-act="vfx-copy">⎘ Copy</button><button type="button" class="tb" data-act="vfx-paste">⎙ Paste</button></div>' +
      '<div class="note">Presets are small .voltfx files - share one, or keep your own set.</div>';
    return h;
  }

  h += '<div class="sec">Position (cm)</div>' + fNum('x', 'Left / right', o.x) + fNum('z', 'Back / front', o.z) + fNum('y', 'Up', o.y);
  if (o.kind !== 'lamp' && o.kind !== 'ball') h += fNum('yaw', 'Turn (°)', o.yaw || 0, { step: 5 });

  if (o.kind === 'char') {
    const known = animsOf(o.file);
    const list = CHARACTERS.includes(o.file) ? CHARACTERS : [o.file, ...CHARACTERS];
    h += '<div class="sec">Character</div>' + fSelect('file', 'Who', o.file, list.map((c) => [c, c.replace(/_/g, ' ')]));
    if (known && !known.length) h += '<div class="note">This model has no animations in it - place it, move it and turn it like anything else.</div>';
    else h += fSelect('anim', 'Doing', o.anim, (known && known.length ? known : CHAR_ANIMS));
    if (!known) h += '<div class="note">Showing the usual animation names until the model has loaded - once it has, this list is read from the model itself.</div>';
    h += fNum('scale', 'Size (%)', o.scale, { min: 1 });
    h += '<div class="sec">Game</div>' + fCheck('solid', 'Solid', o.solid);
    h += advSection(fCheck('visible', 'Visible', o.visible));
    return h;
  }

  if (o.kind === 'block') h += '<div class="sec">Size (cm)</div>' + fNum('w', 'Width', o.w, { min: 1 }) + fNum('h', 'Height', o.h, { min: 1 }) + fNum('d', 'Depth', o.d, { min: 1 });
  if (o.kind === 'ball') h += '<div class="sec">Size (cm)</div>' + fNum('r', 'Radius', o.r, { min: 1 });
  if (o.kind === 'cyl') h += '<div class="sec">Size (cm)</div>' + fNum('r', 'Radius', o.r, { min: 1 }) + fNum('h', 'Height', o.h, { min: 1 });
  if (o.kind === 'block' || o.kind === 'ball' || o.kind === 'cyl') {
    h += '<div class="sec">Look</div>' + fColor('color', 'Colour', o.color);
    h += '<div class="sec">Game</div>' + fCheck('solid', 'Solid', o.solid) +
      '<div class="note">Solid things stop the player - and the player can stand on top of them, or walk under them if they are high enough.</div>';
    let adv = fCheck('visible', 'Visible', o.visible) + fCheck('glowOn', 'Glows in the dark', !!o.glow);
    if (o.glow) adv += fColor('glow', 'Glow colour', o.glow);
    adv += fCheck('shine', 'Shiny / metal', o.shine);
    if (o.shine) adv += fRange('rough', 'Roughness', o.rough, 0, 100) + fRange('metal', 'Metal', o.metal, 0, 100);
    h += advSection(adv);
  }
  if (o.kind === 'lamp') {
    h += '<div class="sec">Light</div>' + fColor('color', 'Colour', o.color) + fRange('power', 'Brightness', o.power, 0, 100) + fNum('range', 'How far it reaches (cm)', o.range, { min: 1, step: 50 });
    h += advSection(fCheck('visible', 'Visible', o.visible));
  }
  if (o.kind === 'model') {
    const cached = o.file ? modelCache.get(o.file) : null;
    h += '<div class="sec">Model</div>' +
      `<div class="note">${o.file ? esc(o.file) : 'No file chosen yet.'}${o.file && !cached ? ' <b>- not loaded this session.</b> Choose it again to see it and to use Play.' : ''}</div>` +
      `<button type="button" class="tb" data-act="rebrowse" style="margin:2px 10px 8px">${o.file ? '⭱ Change file…' : '⭱ Choose a .glb file…'}</button>` +
      fNum('scale', 'Size (%)', o.scale, { min: 1 }) +
      '<div class="sec">Game</div>' + fCheck('solid', 'Solid', o.solid);
    h += advSection(fCheck('visible', 'Visible', o.visible));
  }
  if (o.kind === 'spawn') h += '<div class="note">The player starts here, looking the way the arrow points. Turn it to change the first thing they see.</div>';
  return h;
}

function worldForm() {
  const w = S.world;
  let h = '<div class="sec">World</div>' + fText('title', 'Name', w.title) + fColor('bg', 'Sky colour', w.bg) +
    fRange('ambient', 'Brightness', w.ambient, 0, 100) + fNum('fog', 'How far you can see (cm, 0 = forever)', w.fog, { min: 0, step: 100 }) +
    '<div class="sec">Flashlight</div>' + fRange('torch', 'Brightness', w.torch, 0, 100);
  let adv = fNum('fov', 'Field of view', w.fov, { min: 30, max: 120 }) + fNum('torchRange', 'Flashlight reach (cm)', w.torchRange, { min: 100, step: 100 }) + fCheck('shadows', 'Casts shadows', w.shadows) +
    '<div class="sec">Time of day</div>' + fCheck('skyOn', 'Use a real sky', w.sky >= 0) + (w.sky >= 0 ? fRange('sky', 'Night → Day', w.sky, 0, 100) : '') +
    '<div class="sec">Cinematic</div>' + fRange('bloom', 'Glow', w.bloom, 0, 100) + fRange('vignette', 'Dark edges', w.vignette, 0, 100) + fRange('grain', 'Film grain', w.grain, 0, 100);
  h += advSection(adv);
  h += '<div class="note">Turn on <b>Game lighting</b> in the ⋯ menu to see the fog and the flashlight as the game shows them.</div>';
  return h;
}

function playerForm(section, slotIndex) {
  if (section === 'slot' && slotIndex >= 0) {
    const item = S.player.hotbar[slotIndex] || { name: '', count: 0 };
    return `<div class="sec">Hotbar slot ${slotIndex === 9 ? '0' : slotIndex + 1}</div>` +
      fText('slotName_' + slotIndex, 'Item name', item.name) +
      fNum('slotCount_' + slotIndex, 'Stack count', item.count, { min: 0, max: 999 }) +
      '<div class="note">This item appears in the matching numbered quick slot when the game starts. Leave the name empty for an empty slot.</div>';
  }
  if (section === 'backpack') return '<div class="sec">Player Backpack</div><div class="note">The Backpack is the player inventory container. Items assigned to the Hotbar appear in the numbered quick slots at the bottom of the game.</div><div class="btnrow"><button class="tb" type="button" data-player-open="hotbar">Configure Hotbar</button></div>';
  if (section === 'hotbar') {
    const rows = S.player.hotbar.map((item, i) => `<div class="note" style="display:flex;gap:8px;align-items:center"><b style="min-width:24px">${i === 9 ? '0' : i + 1}</b><span style="flex:1">${esc(item.name || 'Empty slot')}</span><span>${item.count > 0 ? item.count : ''}</span><button class="tb" type="button" data-player-slot="${i}">Edit</button></div>`).join('');
    return '<div class="sec">Default Hotbar</div>' + fCheck('hotbarEnabled', 'Show hotbar in game', S.player.hotbarEnabled) +
      '<div class="note">10 quick slots · keys 1–9 and 0 · configure the starter items below.</div>' + rows;
  }
  return '<div class="sec">Player</div><div class="note">Volt single-player profile. The Backpack contains the default Hotbar. Configure the items that appear when the player starts.</div>' +
    fCheck('hotbarEnabled', 'Enable default hotbar', S.player.hotbarEnabled) +
    '<div class="btnrow"><button class="tb" type="button" data-player-open="hotbar">Configure Hotbar</button></div>';
}
function setPlayerProp(k, v) {
  if (k === 'hotbarEnabled') S.player.hotbarEnabled = !!v;
  else {
    const m = /^(slotName|slotCount)_(\d+)$/.exec(k);
    if (!m) return;
    const i = Number(m[2]); if (i < 0 || i >= 10) return;
    if (m[1] === 'slotName') S.player.hotbar[i].name = String(v).slice(0, 18);
    else S.player.hotbar[i].count = clamp(Math.round(num(v)), 0, 999);
    renderExplorer();
  }
}
function renderProps() {
  const box = $('#props');
  if (selPlayer) { box.innerHTML = playerForm(selPlayer, selPlayerSlot); return; }
  if (selWorld) { box.innerHTML = worldForm(); return; }
  const o = byId(sel);
  box.innerHTML = o ? objForm(o) : '<div class="empty">Nothing picked.<br>Click something in the world, or add a part from the left.</div>';
}
function syncPropValues() {
  const o = byId(sel); if (!o || selWorld) return;
  $$('#props [data-k]').forEach((i) => {
    if (document.activeElement === i) return;
    const k = i.dataset.k; if (!(k in o) || i.type === 'checkbox') return;
    i.value = (i.type === 'number') ? o[k] : (i.type === 'range' ? o[k] : o[k]);
  });
}
function readVal(t) {
  if (t.type === 'checkbox') return t.checked;
  if (t.type === 'number' || t.type === 'range') { const v = parseFloat(t.value); return Number.isFinite(v) ? v : undefined; }
  if (t.dataset.hex) return /^#[0-9a-f]{6}$/i.test(t.value) ? t.value.toLowerCase() : undefined;
  return t.value;
}
$('#props').addEventListener('input', (e) => {
  const t = e.target, k = t.dataset.k; if (!k) return;
  const v = readVal(t); if (v === undefined) return;
  if (t.type === 'color' || t.dataset.hex) $$(`#props [data-k="${k}"]`).forEach((s) => { if (s !== t) s.value = v; });
  if (t.type === 'range') { const out = t.parentElement.querySelector('.val'); if (out) out.textContent = v; }
  if (selPlayer) setPlayerProp(k, v); else if (selWorld) setWorldProp(k, v); else setObjProp(k, v);
});
$('#props').addEventListener('change', () => commit());
$('#props').addEventListener('click', (e) => {
  const playerOpen = e.target.closest('[data-player-open]'); if (playerOpen) { selectPlayer(playerOpen.dataset.playerOpen); return; }
  const playerSlot = e.target.closest('button[data-player-slot]'); if (playerSlot) { selectPlayer('slot', Number(playerSlot.dataset.playerSlot)); return; }
  if (e.target.closest('[data-act="rebrowse"]')) rebrowseModel(byId(sel));
  if (e.target.closest('[data-act="script-open"]')) { const o = byId(sel); if (o && o.kind === 'script') toHost('openScript', { req: host.req++, objectId: o.id, name: o.name, file: o.file || '', fn: o.fn || '', code: o.code || '' }); }
  if (e.target.closest('[data-adv]')) { showAdvanced = !showAdvanced; renderProps(); }
  if (e.target.closest('[data-act="vfx-copy"]')) copyPreset(byId(sel));
  if (e.target.closest('[data-act="vfx-paste"]')) pastePreset(byId(sel));
  if (e.target.closest('[data-act="vfx-import"]')) importPreset(byId(sel));
});

// ---------------------------------------------------------------------
//  Effect presets: a handful of numbers, so one can be shared as a tiny
//  .voltfx file or just pasted between projects.
// ---------------------------------------------------------------------
const presetOf = (o) => {
  const out = { voltfx: 1, name: o.name, effect: o.effect, color: o.color, up: o.up, rate: o.rate };
  for (const f of FX_FIELDS[fxKind(o)]) out[f] = o[f];
  return out;
};
function applyPreset(o, d) {
  if (!d || !d.effect) { toast('That is not an effect preset.', true); return false; }
  const preset = VFX_PRESETS[String(d.effect)] || VFX_PRESETS.sparks;
  Object.assign(o, {
    effect: String(d.effect), color: hex6(d.color, preset.color),
    count: clamp(Math.round(num(d.count, preset.count || 30)), 1, 300),
    speed: Math.max(10, Math.round(num(d.speed, preset.speed || 300))),
    size: Math.max(10, Math.round(num(d.size, preset.size || 240))),
    ms: Math.max(100, Math.round(num(d.ms, preset.ms || 1200))),
    len: Math.max(20, Math.round(num(d.len, preset.len || 900))),
    thick: Math.max(1, Math.round(num(d.thick, preset.thick || 24))),
    up: Math.round(num(d.up, preset.up || 0)), rate: Math.max(0, Math.round(num(d.rate, 0))),
  });
  refreshNode(o); renderProps(); commit();
  return true;
}
function copyPreset(o) {
  if (!o) return;
  toast(copyText(JSON.stringify(presetOf(o), null, 2)) ? 'Copied the preset - paste it into a .voltfx file or another effect' : 'Could not copy', !copyText);
}
function pastePreset(o) {
  if (!o) return;
  openDialog('Paste an effect preset', '<p style="margin:2px 0 8px;color:var(--muted)">Paste the preset text here.</p><textarea id="code" spellcheck="false" style="height:150px"></textarea>', [
    { label: 'Use it', primary: true, click: () => { try { if (applyPreset(o, JSON.parse($('#code').value))) { closeDialog(); toast('Effect updated'); } } catch (e) { toast('That is not a preset - it should look like {"effect":"fire", ...}', true); } } },
  ]);
}
function importPreset(o) {
  if (!o) return;
  const inp = document.createElement('input');
  inp.type = 'file'; inp.accept = '.voltfx,.json,application/json';
  inp.onchange = () => {
    const f = inp.files && inp.files[0]; if (!f) return;
    const reader = new FileReader();
    reader.onload = () => { try { if (applyPreset(o, JSON.parse(String(reader.result)))) toast('Imported ' + f.name); } catch (e) { toast("That file isn't an effect preset.", true); } };
    reader.onerror = () => toast('Could not read that file.', true);
    reader.readAsText(f);
  };
  inp.click();
}
const INT_MIN1 = new Set(['w', 'h', 'd', 'r', 'range', 'scale']);
function setObjProp(k, v) {
  const o = byId(sel); if (!o) return;
  let again = false;
  if (k === 'x' || k === 'y' || k === 'z' || k === 'yaw') {
    withTree(o, () => {
      if (k === 'yaw') o.yaw = ((Math.round(v) + 540) % 360) - 180;
      else o[k] = Math.round(v);
    });
    touch(o); updateStatus();
    return;
  }
  if (k === 'parent') {
    const into = Number(v) || 0;
    if (!setParent(o, into)) { renderProps(); return; }
    renderExplorer(); renderProps(); commit(); return;
  }
  if (k === 'effect') {
    const preset = VFX_PRESETS[v] || VFX_PRESETS.sparks;
    Object.assign(o, { effect: v, color: preset.color, up: preset.up || 0, rate: preset.rate || 0 });
    for (const f of ['count', 'speed', 'size', 'ms', 'len', 'thick']) if (preset[f] != null) o[f] = preset[f];
    renderProps(); touch(o); return;
  }
  if (k === 'when') { o.when = v; renderProps(); return; }
  if (k === 'file' && o.kind === 'char') {
    o.file = v;
    const can = animsOf(v);
    if (can && !can.length) o.anim = '';
    else if (can && !can.includes(o.anim)) o.anim = can.includes('idle') ? 'idle' : can[0];
    else if (!o.anim) o.anim = 'idle';
    askHostForModel(v); refreshNode(o); renderProps(); renderExplorer(); return;
  }
  if (['count', 'speed', 'rate', 'up', 'size', 'ms', 'len', 'thick'].includes(k)) { o[k] = Math.round(v); touch(o); return; }
  if (k === 'code') { o.code = v; dirty = true; return; }
  if (k === 'glowOn') { o.glow = v ? hex6(o.color, '#ffffff') : ''; again = true; }
  else if (k === 'shine') { o.shine = v; again = true; }
  else if (INT_MIN1.has(k)) o[k] = Math.max(1, Math.round(v));
  else if (k === 'x' || k === 'y' || k === 'z') o[k] = Math.round(v);
  else if (k === 'rough' || k === 'metal' || k === 'power') o[k] = clamp(Math.round(v), 0, 100);
  else if (k === 'yaw') o.yaw = ((Math.round(v) + 540) % 360) - 180;
  else if (k === 'color' && o.glow && o.glow === o.color) { o.color = v; o.glow = v; }
  else o[k] = v;
  touch(o);
  if (k === 'name' || k === 'visible') renderExplorer();
  if (k === 'name') renderStatus();
  if (again || k === 'visible') { const keep = document.activeElement; renderProps(); if (keep && keep.dataset && keep.dataset.k) { const el = $(`#props [data-k="${keep.dataset.k}"]`); if (el) el.focus(); } }
  updateStatus();
}
function setWorldProp(k, v) {
  const w = S.world;
  if (k === 'skyOn') { w.sky = v ? 60 : -1; renderProps(); }
  else if (['fog', 'torchRange'].includes(k)) w[k] = Math.max(0, Math.round(v));
  else if (k === 'fov') w.fov = clamp(Math.round(v), 30, 120);
  else if (['ambient', 'torch', 'sky', 'bloom', 'vignette', 'grain'].includes(k)) w[k] = clamp(Math.round(v), 0, 100);
  else w[k] = (typeof v === 'string' && k === 'title') ? v.replace(/["\\\r\n]/g, '') : v;
  applyWorld();
}
function renderStatus() { /* placeholder so name edits refresh the footer */ updateStatus(); }

// ---------------------------------------------------------------------
//  Toolbar
// ---------------------------------------------------------------------
$('#gTools').addEventListener('click', (e) => { const b = e.target.closest('[data-tool]'); if (b) setTool(b.dataset.tool); });
function setTool(t) {
  tool = t;
  $$('#gTools .tb').forEach((b) => b.classList.toggle('on', b.dataset.tool === t));
  updateGizmo(); updateStatus();
}
function updateButtons() {
  $('#bUndo').disabled = hpos <= 0; $('#bRedo').disabled = hpos >= hist.length - 1;
  $('#bDup').disabled = $('#bDel').disabled = !byId(sel);
}
$('#bUndo').onclick = undo; $('#bRedo').onclick = redo;
$('#bDup').onclick = duplicateSelected; $('#bDel').onclick = deleteSelected;
$('#snap').addEventListener('change', () => { cv.focus(); updateStatus(); });
$('#bLight').onclick = () => { setMode(mode === 'preview' ? 'edit' : 'preview'); };
$('#vFrame').onclick = () => { frameAll(); cv.focus(); };
$('#vFocus').onclick = () => { focusSelection(); cv.focus(); };
$('#vGrid').onclick = () => { showGrid = !showGrid; $('#vGrid').classList.toggle('on', showGrid); applyWorld(); };
$('#vAxes').onclick = () => { showAxes = !showAxes; $('#vAxes').classList.toggle('on', showAxes); applyWorld(); };
$$('[data-view]').forEach((b) => b.addEventListener('click', () => { viewPreset(b.dataset.view); cv.focus(); }));
$('#vZoomIn').onclick = () => { const f = fwd3(), d = clamp(focusDist() * 0.18, 0.25, 4); cam.x += f.x * d; cam.y += f.y * d; cam.z += f.z * d; applyCam(); updateGizmo(); };
$('#vZoomOut').onclick = () => { const f = fwd3(), d = clamp(focusDist() * 0.18, 0.25, 4); cam.x -= f.x * d; cam.y -= f.y * d; cam.z -= f.z * d; applyCam(); updateGizmo(); };
$('#bPlay').onclick = () => { if (mode === 'play') stopPlay(); else startPlay(); };
function setMode(m) {
  mode = m;
  $('#bLight').classList.toggle('on', m === 'preview');
  $('#bPlay').textContent = m === 'play' ? '■ Stop' : '▶ Play';
  $('#bPlay').classList.toggle('stop', m === 'play'); $('#bPlay').classList.toggle('primary', m !== 'play');
  $('#badge').textContent = m === 'edit' ? 'Edit' : m === 'preview' ? 'Game lighting' : 'Playing';
  $('#hud').style.display = m === 'play' ? 'block' : 'none';
  applyWorld(); updateGizmo(); updateStatus();
}

// ---- docked panels on narrow widths ----
let dockTab = 'props';
const narrow = () => window.innerWidth <= 800;
function setDock(t) { dockTab = t; $('#app').dataset.dock = t; $$('#dockTabs button').forEach((b) => b.classList.toggle('on', b.dataset.dock === t)); }
$('#dockTabs').addEventListener('click', (e) => { const b = e.target.closest('[data-dock]'); if (b) setDock(b.dataset.dock); });

// ---------------------------------------------------------------------
//  Play mode: walk around the world (same speed + collision as the export)
// ---------------------------------------------------------------------
const play = { x: 0, y: 0, z: 0, vy: 0, yaw: 0, pitch: 0, grounded: true, crouch: false, cols: [], saved: null };
// Shared defaults - these mirror the game kit's own settings (game.volt),
// so Play here behaves like the finished game does.
const KIT = { WALK: 400, RUN: 750, CROUCH: 180, EYE: 165, CROUCH_EYE: 95, JUMP: 430, GRAV: 1500, STEP: 45, WIDE: 25 };

// Every solid thing in the world as a box: the middle of its footprint,
// half its width and depth, and the height of its bottom and top faces.
// The game kit takes exactly this (see `solid` in game.volt) - knowing
// the top means you can stand on a crate, and knowing the bottom means a
// ceiling is something you walk under instead of a wall.
function solidBoxes() {
  const out = [];
  for (const o of S.objects) {
    if (!o.visible || !o.solid) continue;
    let hx, hz, bot, top;
    if (o.kind === 'block') { const a = (o.yaw || 0) * D2R, c = Math.abs(Math.cos(a)), si = Math.abs(Math.sin(a)); hx = (o.w * c + o.d * si) / 2; hz = (o.w * si + o.d * c) / 2; bot = o.y - o.h / 2; top = o.y + o.h / 2; }
    else if (o.kind === 'cyl') { hx = hz = o.r; bot = o.y - o.h / 2; top = o.y + o.h / 2; }
    else if (o.kind === 'ball') { hx = hz = o.r; bot = o.y - o.r; top = o.y + o.r; }
    else if (o.kind === 'model' || o.kind === 'char') {
      const c = modelCache.get(o.kind === 'char' ? charKey(o.file) : o.file), sc = (o.scale || 100) / 100;
      const bx = (c ? c.box.x * 100 : 100) * sc, by = (c ? c.box.y * 100 : 150) * sc, bz = (c ? c.box.z * 100 : 100) * sc;
      hx = bx / 2; hz = bz / 2; bot = o.y; top = o.y + by;
    }
    else continue;
    out.push({ x: Math.round(o.x), z: Math.round(o.z), hx: Math.round(hx), hz: Math.round(hz), bot: Math.round(bot), top: Math.round(top) });
  }
  return out;
}
const spawnOf = () => S.objects.find((o) => o.kind === 'spawn' && o.visible) || S.objects.find((o) => o.kind === 'spawn');
function startPlay() {
  const sp = spawnOf();
  play.x = sp ? sp.x : 0; play.z = sp ? sp.z : 400; play.yaw = sp ? sp.yaw || 0 : 0; play.pitch = 0;
  play.cols = solidBoxes();
  play.y = groundUnder(play.x, play.z, 1e9); play.vy = 0; play.grounded = true; play.crouch = false;
  play.saved = { x: cam.x, y: cam.y, z: cam.z, yaw: cam.yaw, pitch: cam.pitch };
  select(sel);
  setMode('play');
  $('#hud').innerHTML = '<b>WASD</b> walk &nbsp; <b>Shift</b> run &nbsp; <b>Space</b> jump &nbsp; <b>Ctrl</b> crouch &nbsp; <b>drag</b> look &nbsp; <b>Esc</b> stop' + (sp ? '' : ' &nbsp; <i>(no Spawn placed - starting at the middle)</i>');
  cv.focus();
}
function stopPlay() {
  if (mode !== 'play') return;
  Object.assign(cam, play.saved);
  setMode('edit'); applyCam(); updateGizmo();
}
// The same two questions the game kit asks every frame (see game.volt):
// is there something in the way, and how high is the floor here?
function blockedAt(x, z, feet, head) {
  return play.cols.some((c) => Math.abs(x - c.x) < c.hx + KIT.WIDE && Math.abs(z - c.z) < c.hz + KIT.WIDE && c.top > feet + KIT.STEP && c.bot < head);
}
function groundUnder(x, z, feet) {
  let best = 0;
  for (const c of play.cols) {
    if (Math.abs(x - c.x) < c.hx + KIT.WIDE && Math.abs(z - c.z) < c.hz + KIT.WIDE && c.top <= feet + KIT.STEP && c.top > best) best = c.top;
  }
  return best;
}
function updatePlay(dt) {
  const P = play;
  if (keys.has('ArrowLeft')) P.yaw -= 110 * dt;
  if (keys.has('ArrowRight')) P.yaw += 110 * dt;
  if (keys.has('ArrowUp')) P.pitch = clamp(P.pitch + 80 * dt, -80, 80);
  if (keys.has('ArrowDown')) P.pitch = clamp(P.pitch - 80 * dt, -80, 80);
  const yr = P.yaw * D2R, fx = Math.sin(yr), fz = -Math.cos(yr), rx = Math.cos(yr), rz = Math.sin(yr);
  let mx = 0, mz = 0;
  if (keys.has('KeyW')) { mx += fx; mz += fz; }
  if (keys.has('KeyS')) { mx -= fx; mz -= fz; }
  if (keys.has('KeyA')) { mx -= rx; mz -= rz; }
  if (keys.has('KeyD')) { mx += rx; mz += rz; }
  P.crouch = keys.has('ControlLeft') || keys.has('ControlRight');
  const running = (keys.has('ShiftLeft') || keys.has('ShiftRight')) && !P.crouch;
  const eye = P.crouch ? KIT.CROUCH_EYE : KIT.EYE;
  const head = P.y + eye;
  if (mx || mz) {
    const len = Math.hypot(mx, mz), sp = (P.crouch ? KIT.CROUCH : running ? KIT.RUN : KIT.WALK) * dt;
    const nx = P.x + (mx / len) * sp, nz = P.z + (mz / len) * sp;
    if (!blockedAt(nx, P.z, P.y, head)) P.x = nx;
    if (!blockedAt(P.x, nz, P.y, head)) P.z = nz;
  }
  if (P.grounded && keys.has('Space')) { P.vy = KIT.JUMP; P.grounded = false; }
  P.vy -= KIT.GRAV * dt;
  P.y += P.vy * dt;
  const floorY = groundUnder(P.x, P.z, P.y);
  if (P.y <= floorY) { P.y = floorY; P.vy = 0; P.grounded = true; } else P.grounded = false;
  camera.position.set(P.x / 100, (P.y + eye) / 100, P.z / 100);
  camera.rotation.set(P.pitch * D2R, -P.yaw * D2R, 0, 'YXZ');
}
function flyEditorCamera(dt) {
  const sp = (keys.has('ShiftLeft') || keys.has('ShiftRight') ? 14 : 5) * dt;
  const f = new THREE.Vector3(Math.sin(cam.yaw), 0, -Math.cos(cam.yaw)), r = new THREE.Vector3(Math.cos(cam.yaw), 0, Math.sin(cam.yaw));
  let moved = false;
  const go = (v, s) => { cam.x += v.x * s; cam.y += v.y * s; cam.z += v.z * s; moved = true; };
  if (keys.has('KeyW')) go(f, sp); if (keys.has('KeyS')) go(f, -sp);
  if (keys.has('KeyD')) go(r, sp); if (keys.has('KeyA')) go(r, -sp);
  if (keys.has('KeyE')) go(AX.y, sp); if (keys.has('KeyQ')) go(AX.y, -sp);
  if (moved) { applyCam(); updateGizmo(); }
}

// ---------------------------------------------------------------------
//  Keyboard
// ---------------------------------------------------------------------
const typing = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName) && !(e.target.type === 'checkbox' || e.target.type === 'range');
window.addEventListener('keydown', (e) => {
  if ($('#modal').classList.contains('show')) { if (e.key === 'Escape') closeDialog(); return; }
  if (typing(e)) { if (e.key === 'Escape') e.target.blur(); return; }
  keys.add(e.code);
  if (mode === 'play') {
    if (e.key === 'Escape') stopPlay();
    if (e.code.startsWith('Arrow') || e.code === 'Space') e.preventDefault();
    return;
  }
  const ctrl = e.ctrlKey || e.metaKey;
  if (ctrl && e.code === 'KeyZ') { e.preventDefault(); e.shiftKey ? redo() : undo(); return; }
  if (ctrl && e.code === 'KeyY') { e.preventDefault(); redo(); return; }
  if (ctrl && e.code === 'KeyD') { e.preventDefault(); duplicateSelected(); return; }
  if (e.code === 'Delete' || e.code === 'Backspace') { e.preventDefault(); deleteSelected(); return; }
  if (e.code === 'KeyF') { focusSelection(); return; }
  if (drag && drag.type === 'look') return;   // WASD/QE fly the camera while the right button is held
  if (ctrl || e.altKey) return;
  if (e.code === 'KeyQ') setTool('select'); else if (e.code === 'KeyW') setTool('move'); else if (e.code === 'KeyE') setTool('rotate'); else if (e.code === 'KeyR') setTool('scale');
});
window.addEventListener('keyup', (e) => keys.delete(e.code));
window.addEventListener('blur', () => keys.clear());

// ---------------------------------------------------------------------
//  Status line, toast, dialog
// ---------------------------------------------------------------------
function updateStatus() {
  const o = byId(sel), el = $('#status');
  if (mode === 'play') { el.textContent = 'Playing - walk with WASD, drag the mouse to look, Esc to stop. Walls with "Blocks player" stop you.'; return; }
  const t = { select: 'Select: click things, drag to slide them', move: 'Move: drag an arrow', rotate: 'Rotate: drag the ring', scale: 'Scale: drag a handle' }[tool];
  el.textContent = o ? `${o.name}  (${o.x}, ${o.y}, ${o.z}) cm   ·   ${t}   ·   ${S.objects.length} objects` : `${t}   ·   ${S.objects.length} objects   ·   right-drag to look, W/A/S/D + Q/E to fly, F to focus`;
}
let toastTimer = 0;
function toast(msg, err) {
  const t = $('#toast'); t.textContent = msg; t.className = err ? 'err' : ''; t.style.display = 'block';
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.style.display = 'none'; }, err ? 5500 : 3200);
}
function openDialog(title, bodyHtml, buttons) {
  $('#dlgTitle').textContent = title; $('#dlgBody').innerHTML = bodyHtml;
  const foot = $('#dlgFoot'); foot.innerHTML = '';
  for (const b of buttons) {
    const el = document.createElement('button'); el.className = 'tb' + (b.primary ? ' primary' : ''); el.textContent = b.label;
    if (b.disabled) el.disabled = true; if (b.title) el.title = b.title;
    el.onclick = () => b.click(el); foot.appendChild(el);
  }
  $('#modal').classList.add('show');
}
function closeDialog() { $('#modal').classList.remove('show'); cv.focus(); }
$('#dlgX').onclick = closeDialog;
$('#modal').addEventListener('mousedown', (e) => { if (e.target === $('#modal')) closeDialog(); });
function copyText(text) {
  try {
    const ta = document.createElement('textarea'); ta.value = text; ta.style.cssText = 'position:fixed;left:-999px;top:0;opacity:0';
    document.body.appendChild(ta); ta.select(); const ok = document.execCommand('copy'); ta.remove();
    if (ok) return true;
  } catch (e) { /* fall through */ }
  try { navigator.clipboard.writeText(text); return true; } catch (e) { return false; }
}

// ---------------------------------------------------------------------
//  Volt Studio bridge (postMessage - see docs/PLUGINS.md)
// ---------------------------------------------------------------------
const host = { ok: false, req: 1, waiting: new Map() };
function toHost(type, extra) { try { window.parent.postMessage(Object.assign({ voltPanel: 1, type }, extra || {}), '*'); } catch (e) { /* no host */ } }
window.addEventListener('message', (e) => {
  const m = e.data; if (!m || m.voltHost !== 1) return;
  if (m.type === 'hello') {
    host.ok = true;
    if (!host.greeted) { host.greeted = true; autoLoadFromFile(); askHostForCharacters(); }
    for (const o of S.objects) if (o.kind === 'char' && o.file) askHostForModel(o.file);
  }
  if (m.type === 'source' && host.waiting.has(m.req)) { const cb = host.waiting.get(m.req); host.waiting.delete(m.req); cb(m.source || ''); }
  if (m.type === 'asset' && host.waiting.has(m.req)) { const cb = host.waiting.get(m.req); host.waiting.delete(m.req); cb(m.base64 || null); }
  if (m.type === 'assetList' && host.waiting.has(m.req)) { const cb = host.waiting.get(m.req); host.waiting.delete(m.req); cb(m.files || []); }
  if (m.type === 'scriptOpened') {
    const o = byId(Number(m.objectId));
    if (o && o.kind === 'script') { o.file = String(m.file || ''); o.fn = String(m.fn || ''); o.code = ''; renderProps(); dirty = true; commit(); }
  }
  if (m.type === 'scriptOpenFailed') toast(m.message || 'Could not open script file.', true);
  if (m.type === 'scriptSaved') {
    for (const o of S.objects) if (o.kind === 'script' && o.file === m.file && m.fn) o.fn = m.fn;
    renderProps(); dirty = true;
  }
});
function getSource() {
  return new Promise((ok, fail) => {
    if (!host.ok) { fail(new Error('not-hosted')); return; }
    const req = host.req++; host.waiting.set(req, ok); toHost('getSource', { req });
    setTimeout(() => { if (host.waiting.has(req)) { host.waiting.delete(req); fail(new Error('timeout')); } }, 2500);
  });
}
let wide = false;
function toggleWide() { wide = !wide; toHost('wide', { on: wide }); }

// ---------------------------------------------------------------------
//  Export: scene -> Volt code
// ---------------------------------------------------------------------
const RESERVED = new Set(('let fn if else while for each in repeat every frame forever when key pressed wait print show clear stop return break true false and or not pin on off toggle set fade tone button title html image draw write box canvas add remove to from at length contains part sign abs sin cos sqrt atan2 min max random constrain map held mousedx mousedy mousescroll locked3d clicked3d hot3d sky3d px pz yaw pitch fx fz mx mz nx nz i t ws_blocked world3d block3d ball3d cyl3d lamp3d put3d model3d anim3d camera3d move3d turn3d show3d glow3d torch3d shine3d burst3d fx3d look3d render3d clear3d music sound round floor ceil int str ask uptime centered shadow flipped').split(' '));
function identFor(name, used) {
  let s = String(name).replace(/[^A-Za-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
  if (!s || /^[0-9]/.test(s)) s = 'obj' + s;
  if (RESERVED.has(s)) s += '_';
  let base = s, n = 2;
  while (used.has(s)) s = base + n++;
  used.add(s);
  return s;
}
const q = (c) => '"' + hex6(c, '#999999') + '"';
const r = (v) => Math.round(num(v));
// The world lives between these two lines in your .volt file. Saving the
// world rewrites only what is between them, so the settings above and the
// game you wrote below are never touched.
const MARK_OPEN = '// >>> world-studio';
const MARK_CLOSE = '// <<< world-studio';

// Only the fields that differ from a fresh object of that kind, so the
// reload line at the bottom of the world block stays short. importSource
// fills the rest back in from the same defaults.
function compactObj(o) {
  const d = makeObjQuiet(o.kind, '', {});
  const out = { kind: o.kind, name: o.name };
  for (const k of Object.keys(o)) {
    if (k === 'id' || k === 'kind' || k === 'name') continue;
    if (JSON.stringify(o[k]) !== JSON.stringify(d[k])) out[k] = o[k];
  }
  return out;
}

// The World Studio part of a game file: the sky, the things in it, and
// the solid boxes the player walks into.
function worldLines() {
  const w = S.world, L = [], used = new Set(), idn = new Map();
  const shapes = S.objects.filter((o) => o.kind !== 'spawn' && o.kind !== 'folder' && !ATTACHED.has(o.kind));
  for (const o of shapes) idn.set(o.id, identFor(o.name, used));
  for (const o of S.objects) if (ATTACHED.has(o.kind)) idn.set(o.id, identFor(o.name, used));

  L.push(MARK_OPEN + '  (World Studio writes this part - press "Save world" to update it)');
  const scriptFiles = [...new Set(S.objects.filter((o) => o.kind === 'script' && o.file).map((o) => o.file))];
  for (const file of scriptFiles) L.push('import ' + JSON.stringify(file));
  if (scriptFiles.length) L.push('');
  let wl = 'world3d ' + q(w.bg);
  if (w.fog > 0) wl += ' fog ' + r(w.fog);
  wl += ' ambient ' + r(w.ambient) + ' fov ' + r(w.fov);
  if (w.shadows) wl += ' shadows';
  L.push(wl);

  // ---- models: one load per file, characters included ----
  const modelIdent = new Map();   // filename -> ident
  for (const o of shapes) {
    const file = o.kind === 'char' ? o.file + '.glb' : (o.kind === 'model' ? o.file : null);
    if (file && !modelIdent.has(file)) modelIdent.set(file, identFor((file.replace(/\.[^.]+$/, '') || 'model') + '_model', used));
  }
  if (modelIdent.size) {
    L.push('');
    for (const [file, mi] of modelIdent) L.push(`model3d ${mi} = ${JSON.stringify(file)}`);
  }

  // ---- the things themselves ----
  L.push('');
  for (const o of shapes) {
    if (o.kind === 'model' && !o.file) continue;   // nothing to place without a file
    if (o.kind === 'group') continue;   // emitted as a group3d container below
    const n = idn.get(o.id);
    if (o.kind === 'block') L.push(`let ${n} = block3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.w)}, ${r(o.h)}, ${r(o.d)}, ${q(o.color)})`);
    else if (o.kind === 'ball') L.push(`let ${n} = ball3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.r)}, ${q(o.color)})`);
    else if (o.kind === 'cyl') L.push(`let ${n} = cyl3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.r)}, ${r(o.h)}, ${q(o.color)})`);
    else if (o.kind === 'lamp') L.push(`let ${n} = lamp3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${q(o.color)}, ${r(o.power)}, ${r(o.range)})`);
    else if (o.kind === 'model') L.push(`let ${n} = put3d(${modelIdent.get(o.file)}, ${r(o.x)}, ${r(o.y)}, ${r(o.z)}, 0, ${r(o.scale)})`);
    else if (o.kind === 'char') {
      L.push(`let ${n} = put3d(${modelIdent.get(o.file + '.glb')}, ${r(o.x)}, ${r(o.y)}, ${r(o.z)}, 0, ${r(o.scale)})`);
      if (o.anim && !isAnimal(o.file)) L.push(`anim3d ${n}, ${JSON.stringify(o.anim)}`);
    }
    if (o.kind !== 'lamp') {
      if (o.yaw) L.push(`turn3d ${n}, ${r(o.yaw * 10)}`);
      if (o.glow) L.push(`glow3d ${n}, ${q(o.glow)}`);
      if (o.shine) L.push(`shine3d ${n}, ${r(o.rough)}, ${r(o.metal)}`);
    }
    if (!o.visible) L.push(`show3d ${n}, 0`);
  }

  // ---- Model groups and parented parts ----
  const groupIdent = new Map();
  const spatialChildren = (parentId, out = []) => {
    for (const c of childrenOf(parentId)) {
      if (c.kind === 'folder') spatialChildren(c.id, out);
      else if (!ATTACHED.has(c.kind) && c.kind !== 'spawn') out.push(c);
    }
    return out;
  };
  const parents = shapes.filter((o) => o.kind === 'group' || spatialChildren(o.id).length > 0);
  if (parents.length) {
    L.push('');
    L.push('// Models and nested parts: each Model is a real group in the game.');
    const byDept = parents.slice().sort((a, b) => depthOf(b) - depthOf(a));
    for (const o of byDept) {
      let g;
      if (o.kind === 'group') {
        g = idn.get(o.id);
        L.push(`let ${g} = group3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)})`);
        // Descendant transforms already include the Model's pivot rotation.
        if (!o.visible) L.push(`show3d ${g}, 0`);
      } else {
        g = identFor(identish(o.name) + '_group', used);
        L.push(`let ${g} = group3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)})`);
        L.push(`join3d ${idn.get(o.id)}, ${g}`);
      }
      groupIdent.set(o.id, g);
      for (const c of spatialChildren(o.id)) L.push(`join3d ${groupIdent.get(c.id) || idn.get(c.id)}, ${g}`);
    }
  }

  if (w.bloom + w.vignette + w.grain > 0) { L.push(''); L.push(`fx3d ${r(w.bloom)}, ${r(w.vignette)}, ${r(w.grain)}`); }
  if (w.sky >= 0) L.push(`sky3d(${r(w.sky)})`);
  if (w.torch > 0) L.push(`torch3d ${r(w.torch)}, ${r(w.torchRange)}`);

  // ---- what the player bumps into ----
  const boxes = solidBoxes();
  L.push('');
  L.push('// What the player bumps into: middle, half-width, half-depth, bottom, top (cm).');
  L.push('// Anything with "Solid" turned off is left out of this list.');
  L.push('clearSolids()');
  for (const b of boxes) L.push(`solid(${b.x}, ${b.z}, ${b.hx}, ${b.hz}, ${b.bot}, ${b.top})`);

  const sp = spawnOf();
  L.push('');
  L.push('// Where the player starts (move the Spawn in World Studio to change it)');
  L.push(`playerStart(${sp ? r(sp.x) : 0}, ${sp ? r(sp.z) : 400}, ${sp ? r((sp.yaw || 0) * 10) : 0})`);

  // ---- effects ----
  const spatialOwner = (o) => { let up = o.parent ? byId(o.parent) : null; while (up && up.kind === 'folder') up = up.parent ? byId(up.parent) : null; return up; };
  const where = (o) => { const up = spatialOwner(o); return up ? { x: r(up.x), y: r(up.y) + r(o.up || 0), z: r(up.z) } : { x: r(o.x), y: r(o.y) + r(o.up || 0), z: r(o.z) }; };
  const effects = S.objects.filter((o) => o.kind === 'vfx');
  const fxName = new Map();
  if (effects.length) {
    L.push('');
    L.push('// ---- effects ----');
    for (const o of effects) {
      const f = 'vfx_' + idn.get(o.id);
      fxName.set(o.id, f);
      const at = where(o);
      const owner = spatialOwner(o);
      L.push(`// ${o.name}${owner ? ' (inside ' + owner.name + ')' : ''} - ${(VFX_PRESETS[o.effect] || {}).label || o.effect}`);
      L.push(`fn ${f}() {`);
      const kind = fxKind(o), aim = r((owner ? (owner.yaw || 0) : (o.yaw || 0)) * 10);
      if (kind === 'slash') L.push(`  slash3d ${at.x}, ${at.y}, ${at.z}, ${aim}, ${Math.max(10, r(o.size))}, ${q(o.color)}`);
      else if (kind === 'magic') L.push(`  magic3d ${at.x}, ${at.y}, ${at.z}, ${Math.max(10, r(o.size))}, ${q(o.color)}, ${Math.max(100, r(o.ms))}`);
      else if (kind === 'shock') L.push(`  shock3d ${at.x}, ${at.y}, ${at.z}, ${Math.max(10, r(o.size))}, ${q(o.color)}`);
      else if (kind === 'beam') {
        const rad = (owner ? (owner.yaw || 0) : (o.yaw || 0)) * D2R, far = Math.max(20, r(o.len));
        const tx = at.x + Math.round(Math.sin(rad) * far), tz = at.z - Math.round(Math.cos(rad) * far);
        L.push(`  beam3d ${at.x}, ${at.y}, ${at.z}, ${tx}, ${at.y}, ${tz}, ${Math.max(1, r(o.thick))}, ${q(o.color)}`);
      } else L.push(`  burst3d ${at.x}, ${at.y}, ${at.z}, ${q(o.color)}, ${clamp(r(o.count), 1, 300)}, ${Math.max(10, r(o.speed))}`);
      L.push('}');
    }
  }

  // ---- scripts ----
  const scripts = S.objects.filter((o) => o.kind === 'script');
  const scName = new Map();
  if (scripts.length) {
    L.push('');
    L.push('// ---- scripts ----');
    for (const o of scripts) {
      const f = 'script_' + idn.get(o.id);
      scName.set(o.id, f);
      const owner = spatialOwner(o);
      L.push(`// ${o.name}${owner ? ' (inside ' + owner.name + ')' : ''} - ${WHENS[o.when] || o.when}`);
      L.push(`fn ${f}() {`);
      if (o.file) {
        const fn = String(o.fn || '').trim();
        if (/^[A-Za-z_]\w*$/.test(fn)) L.push('  ' + fn + '()');
        else L.push('  // Open the linked file and choose its function name.');
        L.push('}');
      } else {
      const body = String(o.code || '').replace(/\r/g, '').split('\n').filter((l, i, a) => !(i === a.length - 1 && !l.trim()));
      if (!body.length || !body.some((l) => l.trim())) L.push('  // (nothing in this script yet)');
      else for (const line of body) L.push(line.trim() ? '  ' + line : '');
      L.push('}');
      }
    }
  }

  // ---- when they run ----
  const atStart = [...effects, ...scripts].filter((o) => o.when === 'start');
  const running = [...effects, ...scripts].filter((o) => o.when === 'frame' || o.when === 'near' || o.when === 'use');
  const nameOf = (o) => (o.kind === 'vfx' ? fxName.get(o.id) : scName.get(o.id));
  L.push('');
  L.push('// ---- when the scripts and effects run ----');
  L.push('// worldStart() runs once, worldStep() runs every frame - the game file');
  L.push('// below calls both for you.');
  L.push('let ws_tick = 0');
  L.push('fn worldStart() {');
  if (!atStart.length) L.push('  // nothing is set to run at the start yet');
  for (const o of atStart) L.push(`  ${nameOf(o)}()`);
  L.push('}');
  L.push('fn worldStep() {');
  L.push('  ws_tick += 1');
  if (!running.length) L.push('  // nothing is set to run while the game is on yet');
  for (const o of running) {
    const up = spatialOwner(o) || o;
    const call = `${nameOf(o)}()`;
    if (o.when === 'frame') {
      const every = o.kind === 'vfx' ? Math.max(0, r(o.rate || 0)) : 0;
      if (every > 1) { L.push(`  if ws_tick % ${every} == 0 {`); L.push(`    ${call}`); L.push('  }'); }
      else L.push('  ' + call);
    } else if (o.when === 'near') {
      L.push(`  if playerNear(${r(up.x)}, ${r(up.z)}, 150) {`);
      L.push(`    ${call}`);
      L.push('  }');
    } else if (o.when === 'use') {
      L.push(`  if playerNear(${r(up.x)}, ${r(up.z)}, 150) and held("e") {`);
      L.push(`    ${call}`);
      L.push('  }');
    }
  }
  L.push('}');

  L.push('');
  L.push('// How World Studio reads this world back in - leave this line to it.');
  L.push('HOTBAR_ENABLED = ' + (S.player.hotbarEnabled ? 'true' : 'false'));
  L.push('HOTBAR_ITEMS = ' + JSON.stringify(S.player.hotbar.map((slot) => (slot.name || '').slice(0, 4))));
  L.push('HOTBAR_COUNTS = ' + JSON.stringify(S.player.hotbar.map((slot) => Math.max(0, Math.round(num(slot.count))))));
  L.push('// world-studio: ' + JSON.stringify({ v: 2, world: S.world, player: S.player, objects: S.objects.map(compactObj) }));
  L.push(MARK_CLOSE);
  return L.join('\n');
}

// A whole new game file: the bits Volt needs, the settings worth changing,
// the world, and an `every frame` block to grow a game in.
function genGameFile(opt) {
  const title = S.world.title || 'My 3D world';
  const L = [];
  L.push('#html');
  L.push('// ' + title + ' - a Volt game, built in World Studio.');
  L.push('//');
  L.push('// World Studio owns the part between the >>> and <<< lines and rewrites it');
  L.push('// every time you save the world. Everything else here is yours to change.');
  L.push(`title ${JSON.stringify(title)}`);
  L.push('canvas 320, 180');
  L.push('');
  L.push('import "game.volt"   // the player: looking, walking, running, jumping, gravity');
  L.push('');
  L.push('// ============================ SETTINGS ============================');
  L.push('// Change a number, run the game again. (Library tab -> Game kit lists the rest.)');
  L.push('WALK_SPEED = 400       // how fast you walk, in cm a second');
  L.push('RUN_SPEED = 750        // ... while holding Shift');
  L.push('CROUCH_SPEED = 180     // ... while holding Ctrl');
  L.push('JUMP_POWER = 430       // how high you jump (CAN_JUMP = false turns jumping off)');
  L.push('GRAVITY = 1500         // how hard you fall');
  L.push('EYE_HEIGHT = 165       // how tall the player is');
  L.push('MOUSE_SPEED = 3        // how fast the mouse turns you');
  L.push('HEAD_BOB = 3           // how much the view bounces as you walk (0 = off)');
  L.push('');
  L.push(worldLines());
  L.push('');
  L.push('// ============================ YOUR GAME ============================');
  L.push('// Anything below here is yours - saving the world never touches it.');
  L.push('worldStart()           // the scripts and effects set to run at the start');
  L.push('');
  L.push('every frame {');
  L.push('  playerStep()         // look, walk, jump, fall');
  L.push('  worldStep()          // the scripts and effects in the world above');
  L.push('  hotbarStep()         // select a tool with 1-9 or 0');
  L.push('  render3d             // draw the world - your own drawing goes after this');
  L.push('  hotbarDraw()         // draw the player\'s default quick-slot bar');
  if (opt.hud) L.push('  write "WASD + mouse  ·  Shift run  ·  Space jump" at 160, 6 centered shadow');
  L.push('}');
  return L.join('\n') + '\n';
}

// Puts a freshly built world back into a file that already has the two
// marker lines, leaving every other line exactly as the person wrote it.
// Gives back null when the file has no markers (nothing safe to replace).
function spliceWorld(src) {
  const lines = src.split('\n');
  const open = lines.findIndex((l) => l.trim().startsWith(MARK_OPEN));
  if (open < 0) return null;
  const close = lines.findIndex((l, i) => i > open && l.trim().startsWith(MARK_CLOSE));
  if (close < 0) return null;
  return lines.slice(0, open).concat(worldLines().split('\n'), lines.slice(close + 1)).join('\n');
}

// What the person gets when they ask for code: a whole game, or just the
// world to paste into a game they already have.
function genVolt(opt) {
  if (opt && opt.mode === 'scene') return worldLines() + '\n';
  return genGameFile(opt || { hud: true });
}

// ---------------------------------------------------------------------
//  Import: .volt source -> scene (our own data line, or a best-effort read of block3d/lamp3d lines)
// ---------------------------------------------------------------------
function importSource(src) {
  const m = /^\s*\/\/\s*world-studio:\s*(\{.*\})\s*$/m.exec(src);
  if (m) {
    try {
      const d = JSON.parse(m[1]);
      if (d && Array.isArray(d.objects)) {
        S = { world: Object.assign(worldDefaults(), d.world || {}), objects: d.objects.filter((o) => o && KIND[o.kind]).map((o) => Object.assign(makeObjQuiet(o.kind, o.name || '', {}), o)), player: Object.assign(playerDefaults(), d.player || {}) };
        if (!Array.isArray(S.player.hotbar)) S.player.hotbar = playerDefaults().hotbar;
        S.player.hotbar = Array.from({ length: 10 }, (_, i) => Object.assign({ name: '', count: 0 }, S.player.hotbar[i] || {}));
        S.objects.forEach((o, i) => { o.id = i + 1; if (!o.name) o.name = KIND[o.kind].label + (i + 1); });
        nextId = S.objects.length + 1;
        return { ok: true, how: 'saved world', count: S.objects.length };
      }
    } catch (e) { /* fall through to the best-effort reader */ }
  }
  const objs = [], byName = {};
  const nextI = () => objs.length + 1;
  const argsOf = (s) => s.split(',').map((a) => a.trim());
  const strv = (a) => { const mm = /^"(.*)"$/.exec(a); return mm ? mm[1] : null; };
  let world = worldDefaults(), foundWorld = false;
  const wm = /world3d\s+"([^"]+)"([^\n]*)/.exec(src);
  if (wm) {
    foundWorld = true; world.bg = hex6(wm[1], world.bg);
    const rest = wm[2], g = (k) => { const x = new RegExp(k + '\\s+(-?\\d+)').exec(rest); return x ? Number(x[1]) : null; };
    world.fog = g('fog') != null ? g('fog') : 0; world.ambient = g('ambient') != null ? g('ambient') : world.ambient;
    if (g('fov') != null) world.fov = g('fov'); world.shadows = /\bshadows\b/.test(rest);
  }
  const modelByIdent = {};   // model3d ident -> filename, for resolving put3d's first arg
  for (const dm of src.matchAll(/^\s*model3d\s+([A-Za-z_]\w*)\s*=\s*"([^"]+)"/gm)) modelByIdent[dm[1]] = dm[2];
  const lineRe = /^\s*let\s+([A-Za-z_]\w*)\s*=\s*(block3d|ball3d|cyl3d|lamp3d|put3d)\(([^)]*)\)/gm;
  let mm;
  while ((mm = lineRe.exec(src))) {
    const a = argsOf(mm[3]), nm = mm[1], k = mm[2];
    if (k !== 'put3d' && a.some((v, i) => !(strv(v) != null) && !Number.isFinite(Number(v)) && i < a.length)) continue;   // skip lines that use variables
    const n = (i) => Number(a[i]);
    let o = null;
    if (k === 'block3d' && a.length >= 6) o = makeObjQuiet('block', nm, { x: n(0), y: n(1), z: n(2), w: n(3), h: n(4), d: n(5), color: hex6(strv(a[6]) || '#8a8f99') });
    if (k === 'ball3d' && a.length >= 4) o = makeObjQuiet('ball', nm, { x: n(0), y: n(1), z: n(2), r: n(3), color: hex6(strv(a[4]) || '#c8ccd4') });
    if (k === 'cyl3d' && a.length >= 5) o = makeObjQuiet('cyl', nm, { x: n(0), y: n(1), z: n(2), r: n(3), h: n(4), color: hex6(strv(a[5]) || '#8a8f99') });
    if (k === 'lamp3d' && a.length >= 3) o = makeObjQuiet('lamp', nm, { x: n(0), y: n(1), z: n(2), color: hex6(strv(a[3]) || '#ffcc88'), power: a[4] != null ? n(4) : 40, range: a[5] != null ? n(5) : 600 });
    if (k === 'put3d' && a.length >= 4 && modelByIdent[a[0]] && Number.isFinite(n(1)) && Number.isFinite(n(2)) && Number.isFinite(n(3))) {
      o = makeObjQuiet('model', nm, { file: modelByIdent[a[0]], x: n(1), y: n(2), z: n(3), yaw: a[4] != null && Number.isFinite(n(4)) ? n(4) / 10 : 0, scale: a[5] != null && Number.isFinite(n(5)) ? n(5) : 100 });
    }
    if (o) { o.id = nextI(); objs.push(o); byName[nm] = o; }
  }
  for (const gm of src.matchAll(/^\s*glow3d\s+([A-Za-z_]\w*)\s*,\s*"([^"]+)"/gm)) if (byName[gm[1]]) byName[gm[1]].glow = hex6(gm[2], '#ffffff');
  for (const sm of src.matchAll(/^\s*shine3d\s+([A-Za-z_]\w*)\s*,\s*(\d+)\s*,\s*(\d+)/gm)) if (byName[sm[1]]) Object.assign(byName[sm[1]], { shine: true, rough: Number(sm[2]), metal: Number(sm[3]) });
  for (const tm of src.matchAll(/^\s*turn3d\s+([A-Za-z_]\w*)\s*,\s*(-?\d+)/gm)) if (byName[tm[1]]) byName[tm[1]].yaw = Number(tm[2]) / 10;
  // a game-kit file lists what the player bumps into; anything whose
  // footprint isn't in that list was built with "Solid" turned off
  const solidLines = [...src.matchAll(/^\s*solid\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,/gm)];
  if (solidLines.length) {
    const at = new Set(solidLines.map((m) => m.slice(1, 5).join(',')));
    for (const o of objs) {
      if (o.kind === 'lamp' || o.kind === 'spawn') continue;
      let hx, hz;
      if (o.kind === 'block') { const a = (o.yaw || 0) * D2R, c = Math.abs(Math.cos(a)), si = Math.abs(Math.sin(a)); hx = (o.w * c + o.d * si) / 2; hz = (o.w * si + o.d * c) / 2; }
      else hx = hz = o.r || 0;
      o.solid = at.has([Math.round(o.x), Math.round(o.z), Math.round(hx), Math.round(hz)].join(','));
    }
  }
  if (!objs.length) return { ok: false };
  S = { world, objects: objs }; nextId = objs.length + 1;
  // where the player starts: a game-kit file says playerStart(x, z, yaw);
  // older hand-written ones set px / pz / yaw variables instead
  const startM = /^\s*playerStart\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/m.exec(src);
  if (startM) S.objects.push(makeObjQuiet('spawn', 'Spawn', { id: nextId++, x: Number(startM[1]), z: Number(startM[2]), yaw: Number(startM[3]) / 10 }));
  else {
    const spawnM = /let\s+px\s*=\s*(-?\d+)[\s\S]{0,40}?let\s+pz\s*=\s*(-?\d+)/.exec(src);
    if (spawnM) { const yw = /let\s+yaw\s*=\s*(-?\d+)/.exec(src); S.objects.push(makeObjQuiet('spawn', 'Spawn', { id: nextId++, x: Number(spawnM[1]), z: Number(spawnM[2]), yaw: yw ? Number(yw[1]) / 10 : 0 })); }
  }
  return { ok: true, how: foundWorld ? 'block3d / lamp3d lines' : 'block3d / lamp3d lines (no world3d line found)', count: objs.length, partial: true };
}
function makeObjQuiet(kind, name, over) {
  const keep = S;   // makeObj reads S for unique names; use a throwaway
  S = { world: keep.world, objects: [] };
  const o = makeObj(kind, Object.assign({ name }, over));
  S = keep;
  nextId--;   // makeObj bumped the counter; ids are reassigned by the importer
  return o;
}
function adoptImported(res, label) {
  sel = null; selWorld = false;
  rebuildAll(); renderExplorer(); renderProps(); applyWorld(); updateGizmo(); updateStatus();
  commit(); updateButtons();
  const sp = spawnOf();
  frameAll();
  const needReattach = S.objects.filter((o) => o.kind === 'model' && o.file && !modelCache.has(o.file)).length;
  toast(`Loaded ${res.count} objects from the ${res.how}${res.partial ? ' - only plain block3d/ball3d/cyl3d/lamp3d/put3d lines could be read' : ''}.` +
    (needReattach ? ` ${needReattach} model${needReattach > 1 ? 's' : ''} need their .glb file re-attached (see Properties) to preview or Play.` : ''));
}
function autoLoadFromFile() {
  getSource().then((src) => {
    if (/^\s*\/\/\s*world-studio:\s*\{/m.test(src)) { const res = importSource(src); if (res.ok) adoptImported(res); }
  }).catch(() => {});
}
function loadFromFile() {
  if (!host.ok) { toast('Open this panel inside Volt Studio to load from the current file (an older Volt Studio has no bridge).', true); return; }
  getSource().then((src) => {
    const res = importSource(src);
    if (!res.ok) { toast('No world found in the file in the editor. Build one here and press Save world first.', true); return; }
    adoptImported(res);
  }).catch(() => toast('Volt Studio did not answer. Try again.', true));
}

// ---- saving the world into the .volt file ----
const expOpt = { hud: true };

function worldSummary() {
  const n = S.objects.filter((o) => o.kind !== 'spawn').length;
  return n + (n === 1 ? ' thing' : ' things');
}

// The ordinary case: the file already has the markers, so only the world
// between them changes and the person's own code is left alone.
function saveWorld(run) {
  if (!host.ok) { showCode(); return; }
  getSource().then((src) => {
    const merged = spliceWorld(src);
    if (merged != null) {
      toHost('replace', { code: merged, run: !!run });
      toast('Saved the world into your file - ' + worldSummary() + ', and your own code is untouched.');
      return;
    }
    askToCreate(src, run);
  }).catch(() => toast('Volt Studio did not answer. Try again.', true));
}

// No markers in the file yet - offer to start a game file (or to take the
// world as code and place it by hand).
function askToCreate(src, run) {
  const hasCode = src.trim().length > 0;
  openDialog('Start a game file?',
    '<p style="margin:2px 0 10px">This file has no World Studio block yet.</p>' +
    '<p style="margin:2px 0 10px;color:var(--muted)">A game file is a normal <b>.volt</b> file with three parts: <b>settings</b> you can change, the <b>world</b> you build here, and <b>your game</b> underneath. From then on, saving the world only rewrites the world part.</p>' +
    (hasCode ? '<p style="margin:2px 0 10px;color:var(--danger)">The file already has something in it. Making a game file replaces all of it - Ctrl+Z in the code editor puts it back.</p>' : ''),
    [
      { label: 'Just show me the code', click: () => { closeDialog(); showCode(); } },
      { label: 'Make a game file', primary: true, click: () => {
        toHost('replace', { code: genGameFile(expOpt), run: !!run });
        closeDialog();
        toast('Made a game file - ' + worldSummary() + '. Press Play in Volt Studio to run it.');
      } },
    ]);
}

// The escape hatch: the code itself, to copy or drop in by hand.
function showCode() {
  const mode = { v: 'game' };
  const modelFiles = [...new Set(S.objects.filter((o) => o.kind === 'model' && o.file).map((o) => o.file))];
  openDialog('The Volt code',
    '<div class="opts">' +
      '<label><input type="radio" name="m" data-o="game" checked> A whole game file</label>' +
      '<label><input type="radio" name="m" data-o="scene"> Just the world, to paste into a game I already have</label>' +
    '</div>' +
    (modelFiles.length ? `<p style="margin:2px 0 8px;color:var(--muted)">Keep ${modelFiles.length > 1 ? 'these model files' : 'this model file'} next to your .volt file: <b>${modelFiles.map(esc).join(', ')}</b></p>` : '') +
    '<textarea id="code" readonly spellcheck="false"></textarea>' +
    '<p style="margin:6px 0 2px;color:var(--muted)">The player comes from <b>import "game.volt"</b>, which Volt Studio finds on its own. To run the file somewhere else, open the Library tab, copy the <b>Game kit</b> snippet into the file, and delete the import line.</p>',
    [
      { label: 'Copy', click: () => { toast(copyText($('#code').value) ? 'Copied' : 'Could not copy - select the text and press Ctrl+C', false); } },
      { label: 'Insert at cursor', disabled: !host.ok, click: () => { toHost('insert', { code: $('#code').value }); closeDialog(); toast('Inserted into the editor'); } },
      { label: 'Replace the file', primary: true, disabled: !host.ok, click: () => { toHost('replace', { code: $('#code').value }); closeDialog(); toast('Sent to the editor'); } },
    ]);
  const refresh = () => {
    mode.v = $('[data-o="game"]').checked ? 'game' : 'scene';
    $('#code').value = genVolt({ mode: mode.v, hud: expOpt.hud });
  };
  $('#dlgBody').addEventListener('change', refresh);
  refresh();
}

$('#bSave').onclick = () => saveWorld(false);
$('#bSavePlay').onclick = () => saveWorld(true);

// ---- the "more" menu: everything that isn't needed every minute ----
$('#bMore').onclick = () => {
  const item = (act, label, note) => `<button class="menuitem" data-act="${act}"><b>${label}</b><small>${note}</small></button>`;
  openDialog('More',
    '<div class="menu">' +
      item('lighting', mode === 'preview' ? 'Turn off game lighting' : 'Game lighting', 'See the world with its real fog, darkness and flashlight') +
      item('load', 'Load the world from the file', 'Read the world back out of the .volt file in the editor') +
      item('code', 'Show the Volt code', 'Copy it, insert it, or paste just the world into another game') +
      item('room', 'Start again: a small room', 'Four walls, a floor, a light and a spawn point') +
      item('empty', 'Start again: empty', 'Nothing but a spawn point') +
      item('wide', wide ? 'Make the panel narrow' : 'Make the panel wide', 'More room for the viewport') +
      item('help', 'How do I...?', 'The short version of everything in here') +
    '</div>', []);
  $('#dlgBody').onclick = (e) => {
    const b = e.target.closest('[data-act]'); if (!b) return;
    const act = b.dataset.act;
    closeDialog();
    if (act === 'lighting') setMode(mode === 'preview' ? 'edit' : 'preview');
    if (act === 'load') loadFromFile();
    if (act === 'code') showCode();
    if (act === 'room') { roomScene(); adoptImported({ count: S.objects.length, how: 'a fresh room' }); }
    if (act === 'empty') { S = { world: worldDefaults(), objects: [] }; nextId = 1; addPreset('spawn', [0, 0]); adoptImported({ count: 1, how: 'an empty world' }); }
    if (act === 'wide') toggleWide();
    if (act === 'help') showHelp();
  };
};

function showHelp() {
  openDialog('How do I...?',
    '<div class="help">' +
    '<p><b>Build something</b> - click a part on the left to drop it in front of the camera, or drag it into the world. Click it again to pick it up; Properties on the right changes its size, colour and whether the player can walk through it.</p>' +
    '<p><b>Move around</b> - hold the right mouse button and drag to look; W A S D fly, Q and E go down and up, F jumps to whatever is selected.</p>' +
    '<p><b>Move a part</b> - pick it, then drag an arrow (W to move, E to turn, R to resize, Q to just select). <b>Grid</b> at the top rounds everything off so walls line up.</p>' +
    '<p><b>Put things inside things</b> - drag a row onto another row in the <b>Things</b> list, the way you would in Roblox. Move or turn the outer one and everything inside comes along; in the game they become a <b>group3d</b>.</p>' +
    '<p><b>Add a character</b> - the <b>Character</b> part places one of the rigged people that come with Volt Studio (or a wolf, bear or deer). Pick who it is and what it is doing - idle, walk, sprint, attack, carrying something - and it does that in the game.</p>' +
    '<p><b>Scripts and effects</b> - pick a part, then click <b>Script</b> or <b>Effect</b>: it goes inside that part. A script is plain Volt that runs when you say - at the start, every frame, when the player is close, or when they press E close by. An effect is a burst of glowing specks; a script can set one off by name, like <b>vfx_Slash()</b>.</p>' +
    '<p><b>Try it</b> - press <b>Play</b>: W A S D to walk, Shift to run, Space to jump, Ctrl to crouch, Esc to stop. Play walks the world the way the game does; scripts and effects run once the game itself is running.</p>' +
    '<p><b>Put it in the game</b> - press <b>Save world</b>. The first time it offers to make a game file; after that it only rewrites the world part and leaves your own code alone.</p>' +
    '<p><b>Change how the game feels</b> - the settings at the top of that file (walking speed, jump height, how tall the player is) are plain numbers.</p>' +
    '</div>', [{ label: 'Got it', primary: true, click: closeDialog }]);
}

// ---------------------------------------------------------------------
//  Frame loop + resize
// ---------------------------------------------------------------------
function resize() {
  const w = Math.max(2, vp.clientWidth), h = Math.max(2, vp.clientHeight);
  renderer.setSize(w, h, false);
  camera.aspect = w / h; camera.updateProjectionMatrix();
  if (narrow() !== resize.wasNarrow) { resize.wasNarrow = narrow(); }
  dirty = true;
}
if (typeof ResizeObserver !== 'undefined') new ResizeObserver(resize).observe(vp);
window.addEventListener('resize', resize);

let last = performance.now();
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  if (mode === 'play') { updatePlay(dt); dirty = true; }
  else if (drag && drag.type === 'look') flyEditorCamera(dt);
  if (mode !== 'edit' && torch.visible) {
    const d = new THREE.Vector3(); camera.getWorldDirection(d);
    torch.position.copy(camera.position); torch.target.position.copy(camera.position).add(d); halo.position.copy(camera.position);
  }
  if (!dirty) return;
  dirty = false;
  renderer.clear();
  renderer.render(scene, camera);
  if (gizmoRoot.visible && mode !== 'play') {
    gizmoRoot.scale.setScalar(gizmoScaleFor());
    renderer.clearDepth();
    renderer.render(gscene, camera);
  }
}

// ---------------------------------------------------------------------
//  Start
// ---------------------------------------------------------------------
function init() {
  renderTools();
  let loaded = false;
  try {
    const saved = localStorage.getItem('voltWorldStudio.scene');
    if (saved) { const d = JSON.parse(saved); S = { world: Object.assign(worldDefaults(), d.world), objects: d.objects }; nextId = d.nextId || (S.objects.length + 1); loaded = true; }
  } catch (e) { /* no storage in the sandbox - that's fine */ }
  if (!loaded) roomScene();
  rebuildAll(); renderExplorer(); renderProps(); applyWorld(); updateGizmo(); updateStatus();
  hist = [snapshot()]; hpos = 0; updateButtons();
  if (narrow()) setDock('props');
  resize();
  frameAll();
  requestAnimationFrame(frame);
  toHost('hello');
  setTimeout(() => { if (!host.ok) toHost('hello'); }, 700);
  select(null);
}
window.__worldStudio = {
  project(x, y, z) { camera.updateMatrixWorld(true); const v = new THREE.Vector3(x, y, z).project(camera), r = cv.getBoundingClientRect(); return [(v.x + 1) / 2 * r.width + r.left, (1 - v.y) / 2 * r.height + r.top]; },
  get gizmoK() { return gizmoScaleFor(); }, get cam() { return cam; }, get sel() { return sel; }, get scene() { return S; }, genVolt, importSource, startPlay, stopPlay, select, setTool, addPreset, get mode() { return mode; }, get play() { return play; }, snapshot, setMode };
init();
})();
