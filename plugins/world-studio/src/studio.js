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
  block: { label: 'Block', icon: '▣' },
  ball: { label: 'Ball', icon: '●' },
  cyl: { label: 'Cylinder', icon: '▮' },
  lamp: { label: 'Lamp', icon: '✦' },
  spawn: { label: 'Spawn', icon: '⚑' },
};
const worldDefaults = () => ({
  title: 'My 3D world', bg: '#05060a', fog: 1600, ambient: 8, fov: 75, shadows: true,
  torch: 60, torchRange: 1800, sky: -1, bloom: 0, vignette: 0, grain: 0,
});
let S = { world: worldDefaults(), objects: [] };
let nextId = 1;
const byId = (id) => S.objects.find((o) => o.id === id);

function uniqueName(base) {
  base = base.replace(/\s+/g, '');
  const used = new Set(S.objects.map((o) => o.name.toLowerCase()));
  if (!used.has(base.toLowerCase())) return base;
  let i = 2;
  while (used.has((base + i).toLowerCase())) i++;
  return base + i;
}
function makeObj(kind, over = {}) {
  const o = { id: nextId++, kind, name: '', x: 0, y: 0, z: 0, yaw: 0, visible: true };
  if (kind === 'block') Object.assign(o, { w: 100, h: 100, d: 100, y: 50, color: '#8a8f99', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'ball') Object.assign(o, { r: 50, y: 50, color: '#c8ccd4', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'cyl') Object.assign(o, { r: 30, h: 300, y: 150, color: '#8a8f99', glow: '', shine: false, rough: 40, metal: 0, solid: true });
  if (kind === 'lamp') Object.assign(o, { y: 200, color: '#ffcc88', power: 40, range: 700 });
  Object.assign(o, over);
  if (!o.name) o.name = uniqueName(KIND[kind].label);
  return o;
}
function roomScene() {
  S = { world: worldDefaults(), objects: [] };
  nextId = 1;
  const add = (kind, name, over) => { S.objects.push(makeObj(kind, Object.assign({ name }, over))); };
  add('block', 'Floor', { x: 0, y: -5, z: 0, w: 1200, h: 10, d: 1200, color: '#6a6f78', solid: false });
  add('block', 'Ceiling', { x: 0, y: 300, z: 0, w: 1200, h: 10, d: 1200, color: '#4a4d55', solid: false });
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
const snapshot = () => JSON.stringify({ world: S.world, objects: S.objects, nextId });
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
  S = { world: Object.assign(worldDefaults(), d.world), objects: d.objects };
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
const renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.autoClear = false;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;

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
  } else if (o.kind === 'lamp') {
    n = new THREE.Group();
    n.add(new THREE.Mesh(new THREE.SphereGeometry(0.1, 14, 10), new THREE.MeshBasicMaterial({ color: hex6(o.color, '#ffcc88') })));
    const l = new THREE.PointLight(hex6(o.color, '#ffcc88'), clamp(o.power, 0, 100) * 0.5, Math.max(1, o.range) / 100, 1.6);
    l.visible = false; n.add(l); n.userData.light = l;
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
  if (n.userData.marker) n.visible = mode !== 'play' && !!o && o.visible !== false;
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
  grid.visible = axisLines.visible = !game;
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

function frameAll() {   // put the camera back so the whole world is in view
  let minx = 1e9, maxx = -1e9, minz = 1e9, maxz = -1e9;
  for (const o of S.objects) { minx = Math.min(minx, o.x); maxx = Math.max(maxx, o.x); minz = Math.min(minz, o.z); maxz = Math.max(maxz, o.z); }
  if (minx > maxx) { minx = maxx = minz = maxz = 0; }
  const cx = (minx + maxx) / 200, cz = (minz + maxz) / 200, span = Math.max(4, Math.max(maxx - minx, maxz - minz) / 100);
  cam.yaw = -0.5; cam.pitch = -0.5;
  const f = fwd3(), dist = span * 0.9 + 4;
  cam.x = cx - f.x * dist; cam.y = 1 - f.y * dist; cam.z = cz - f.z * dist;
  applyCam();
}
function focusSelection() {
  const o = byId(sel);
  let tx = 0, ty = 1, tz = 0, size = 6;
  if (o) { tx = o.x / 100; ty = o.y / 100; tz = o.z / 100; const b = boundsOf(o); size = Math.max(b[0], b[1], b[2], 0.6) * 1.6; }
  const f = fwd3(), dist = Math.max(2.2, size * 1.7);
  cam.x = tx - f.x * dist; cam.y = ty - f.y * dist; cam.z = tz - f.z * dist;
  applyCam();
}
const focusDist = () => { const o = byId(sel); return o ? Math.max(1.5, Math.hypot(o.x / 100 - cam.x, o.y / 100 - cam.y, o.z / 100 - cam.z)) : 10; };

// ---------------------------------------------------------------------
//  Selection, snapping, mutation helpers
// ---------------------------------------------------------------------
let sel = null, selWorld = false, tool = 'select';
const snapStep = () => num($('#snap').value, 0);
const sn = (v) => { const s = snapStep(); return s > 0 ? Math.round(v / s) * s : Math.round(v); };
const snRot = (d) => (snapStep() > 0 ? Math.round(d / 15) * 15 : Math.round(d));

function select(id) {
  sel = id; selWorld = false;
  for (const [nid, n] of nodes) n.userData.outline.visible = (nid === id) && mode !== 'play';
  renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); dirty = true;
  if (narrow() && id != null && dockTab === 'toolbox') setDock('props');
}
function selectWorld() { sel = null; selWorld = true; for (const n of nodes.values()) n.userData.outline.visible = false; renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); dirty = true; if (narrow()) setDock('props'); }
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
  const o = byId(sel), g = gizmoSupports(o);
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
    if (setRay(e).intersectPlane(plane, p0)) drag = { type: 'body', plane, p0, start: { x: ob.x, z: ob.z }, id, x: e.clientX, y: e.clientY };
  }
});
function beginGizmoDrag(e, axis, o) {
  const ray = setRay(e);
  const origin = new THREE.Vector3(o.x / 100, o.y / 100, o.z / 100);
  if (axis === 'yaw') {
    const plane = new THREE.Plane(YUP, -origin.y), p = new THREE.Vector3();
    if (!ray.intersectPlane(plane, p)) return;
    drag = { type: 'rot', id: o.id, plane, origin, a0: Math.atan2(p.x - origin.x, -(p.z - origin.z)), yaw0: o.yaw || 0 };
    return;
  }
  const dir = tool === 'scale' ? AX[axis].clone().applyAxisAngle(YUP, -(o.yaw || 0) * D2R) : AX[axis].clone();
  drag = { type: tool === 'scale' ? 'scale' : 'move', id: o.id, axis, dir, origin, t0: axisParam(ray, origin, dir), start: Object.assign({}, o) };
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
  const s = d.start, key = o.kind === 'block' ? { x: 'w', y: 'h', z: 'd' }[d.axis] : o.kind === 'ball' ? 'r' : (d.axis === 'y' ? 'h' : 'r');
  const nv = Math.max(1, sn(s[key] + delta)), applied = nv - s[key];
  o[key] = nv;
  o.x = s.x; o.y = s.y; o.z = s.z;
  if (o.kind === 'block' || (o.kind === 'cyl' && d.axis === 'y')) {   // keep the opposite face where it was
    o.x = Math.round(s.x + d.dir.x * applied / 2); o.y = Math.round(s.y + d.dir.y * applied / 2); o.z = Math.round(s.z + d.dir.z * applied / 2);
  }
}
function afterTransform(o) { updateGizmo(); syncPropValues(); updateStatus(); dirty = true; }
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
  block: { kind: 'block', label: 'Block', glyph: '▣', over: { w: 100, h: 100, d: 100 }, base: 'Block' },
  wall: { kind: 'block', label: 'Wall', glyph: '▬', over: { w: 400, h: 300, d: 20, color: '#7b808a' }, base: 'Wall' },
  floor: { kind: 'block', label: 'Floor', glyph: '▱', over: { w: 800, h: 10, d: 800, color: '#6a6f78', solid: false }, base: 'Floor' },
  pillar: { kind: 'cyl', label: 'Pillar', glyph: '▮', over: { r: 30, h: 300 }, base: 'Pillar' },
  ball: { kind: 'ball', label: 'Ball', glyph: '●', over: { r: 50 }, base: 'Ball' },
  lamp: { kind: 'lamp', label: 'Lamp', glyph: '✦', over: {}, base: 'Lamp' },
  spawn: { kind: 'spawn', label: 'Spawn', glyph: '⚑', over: {}, base: 'Spawn' },
};
function addPreset(key, at) {
  const P = PRESETS[key];
  if (key === 'spawn') { const old = S.objects.filter((o) => o.kind === 'spawn'); if (old.length >= 1) { toast('Only the first Spawn is used by the game - moved it here instead.'); const o = old[0]; if (at) { o.x = sn(at[0]); o.z = sn(at[1]); touch(o); select(o.id); commit(); syncPropValues(); } return; } }
  let x, z;
  if (at) { x = at[0]; z = at[1]; }
  else {
    const f = fwd3(), ray = new THREE.Ray(new THREE.Vector3(cam.x, cam.y, cam.z), f), p = new THREE.Vector3();
    const flat = { x: Math.sin(cam.yaw), z: -Math.cos(cam.yaw) };   // never further than ~6 m ahead of you
    if (ray.intersectPlane(new THREE.Plane(YUP, 0), p) && Math.hypot(p.x - cam.x, p.z - cam.z) < 6) { x = p.x * 100; z = p.z * 100; }
    else { x = (cam.x + flat.x * 6) * 100; z = (cam.z + flat.z * 6) * 100; }
  }
  const o = makeObj(P.kind, Object.assign({ name: uniqueName(P.base) }, P.over));
  o.x = sn(x); o.z = sn(z);
  if (P.kind === 'block') o.y = key === 'floor' ? -o.h / 2 : o.h / 2;
  else if (P.kind === 'cyl') o.y = o.h / 2;
  else if (P.kind === 'ball') o.y = o.r;
  else if (P.kind === 'spawn') o.y = 0;
  S.objects.push(o); refreshNode(o); select(o.id); commit();
}
function deleteSelected() {
  const o = byId(sel); if (!o) return;
  const n = nodes.get(o.id); if (n) { worldGroup.remove(n); disposeNode(n); nodes.delete(o.id); }
  S.objects = S.objects.filter((x) => x.id !== o.id);
  sel = null; renderExplorer(); renderProps(); updateGizmo(); updateStatus(); updateButtons(); commit(); dirty = true;
}
function duplicateSelected() {
  const o = byId(sel); if (!o) return;
  if (o.kind === 'spawn') { toast('A world only needs one Spawn.'); return; }
  const c = JSON.parse(JSON.stringify(o));
  c.id = nextId++; c.name = uniqueName(o.name.replace(/\d+$/, '') || KIND[o.kind].label);
  c.x += snapStep() || 100;
  S.objects.push(c); refreshNode(c); select(c.id); commit();
}

// ---------------------------------------------------------------------
//  Explorer + Toolbox + Properties panels
// ---------------------------------------------------------------------
function renderExplorer() {
  const box = $('#explorer');
  let h = `<div class="row world${selWorld ? ' sel' : ''}" data-world="1"><span class="ic">🌐</span><span class="nm">World settings</span></div>`;
  if (!S.objects.length) h += '<div class="empty">Empty world. Add things from the Toolbox.</div>';
  for (const o of S.objects) {
    h += `<div class="row${o.id === sel ? ' sel' : ''}${o.visible ? '' : ' hidden'}" data-id="${o.id}"><span class="ic">${KIND[o.kind].icon}</span><span class="nm">${esc(o.name)}</span><span class="eye" data-eye="${o.id}" title="Show / hide">${o.visible ? '👁' : '◌'}</span></div>`;
  }
  box.innerHTML = h;
}
$('#explorer').addEventListener('click', (e) => {
  const eye = e.target.closest('[data-eye]');
  if (eye) { const o = byId(Number(eye.dataset.eye)); o.visible = !o.visible; refreshNode(o); renderExplorer(); renderProps(); commit(); return; }
  const row = e.target.closest('.row'); if (!row) return;
  if (row.dataset.world) selectWorld(); else select(Number(row.dataset.id));
});
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
const fRange = (k, l, v, min, max) => `<label class="f"><span>${l}</span><input type="range" data-k="${k}" min="${min}" max="${max}" value="${v}"><span class="val">${v}</span></label>`;
function objForm(o) {
  let h = `<div class="sec">${KIND[o.kind].label}</div>` + fText('name', 'Name', o.name) + fCheck('visible', 'Visible', o.visible);
  h += '<div class="sec">Position</div>' + fNum('x', 'X (cm)', o.x) + fNum('y', 'Y (up)', o.y) + fNum('z', 'Z (cm)', o.z);
  if (o.kind !== 'lamp' && o.kind !== 'ball') h += fNum('yaw', 'Yaw (°)', o.yaw || 0, { step: 5 });
  if (o.kind === 'block') h += '<div class="sec">Size (cm)</div>' + fNum('w', 'Width', o.w, { min: 1 }) + fNum('h', 'Height', o.h, { min: 1 }) + fNum('d', 'Depth', o.d, { min: 1 });
  if (o.kind === 'ball') h += '<div class="sec">Size (cm)</div>' + fNum('r', 'Radius', o.r, { min: 1 });
  if (o.kind === 'cyl') h += '<div class="sec">Size (cm)</div>' + fNum('r', 'Radius', o.r, { min: 1 }) + fNum('h', 'Height', o.h, { min: 1 });
  if (o.kind === 'block' || o.kind === 'ball' || o.kind === 'cyl') {
    h += '<div class="sec">Look</div>' + fColor('color', 'Colour', o.color) + fCheck('glowOn', 'Glows', !!o.glow);
    if (o.glow) h += fColor('glow', 'Glow colour', o.glow);
    h += fCheck('shine', 'Shiny / metal', o.shine);
    if (o.shine) h += fRange('rough', 'Roughness', o.rough, 0, 100) + fRange('metal', 'Metal', o.metal, 0, 100);
    h += '<div class="sec">Game</div>' + fCheck('solid', 'Blocks player', o.solid);
  }
  if (o.kind === 'lamp') h += '<div class="sec">Light</div>' + fColor('color', 'Colour', o.color) + fRange('power', 'Power', o.power, 0, 100) + fNum('range', 'Range (cm)', o.range, { min: 1, step: 50 });
  if (o.kind === 'spawn') h += '<div class="note">The player starts here, 165 cm up, looking the way the arrow points. Rotate it to turn the start view.</div>';
  return h;
}
function worldForm() {
  const w = S.world;
  return '<div class="sec">World</div>' + fText('title', 'Title', w.title) + fColor('bg', 'Sky colour', w.bg) +
    fNum('fog', 'Fog (cm, 0=off)', w.fog, { min: 0, step: 100 }) + fRange('ambient', 'Ambient', w.ambient, 0, 100) + fNum('fov', 'Field of view', w.fov, { min: 30, max: 120 }) +
    '<div class="sec">Flashlight</div>' + fRange('torch', 'Power', w.torch, 0, 100) + fNum('torchRange', 'Range (cm)', w.torchRange, { min: 100, step: 100 }) + fCheck('shadows', 'Casts shadows', w.shadows) +
    '<div class="sec">Time of day</div>' + fCheck('skyOn', 'Use sky3d', w.sky >= 0) + (w.sky >= 0 ? fRange('sky', 'Night → Day', w.sky, 0, 100) : '') +
    '<div class="sec">Cinematic (fx3d)</div>' + fRange('bloom', 'Bloom', w.bloom, 0, 100) + fRange('vignette', 'Vignette', w.vignette, 0, 100) + fRange('grain', 'Film grain', w.grain, 0, 100) +
    '<div class="note">Bloom and grain show up in the finished game; here you get a preview of the vignette. Turn on <b>Game lighting</b> to see fog, ambient and flashlight.</div>';
}
function renderProps() {
  const box = $('#props');
  if (selWorld) { box.innerHTML = worldForm(); return; }
  const o = byId(sel);
  box.innerHTML = o ? objForm(o) : '<div class="empty">Nothing selected.<br>Click something in the world or in the Explorer, or add one from the Toolbox.</div>';
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
  if (selWorld) setWorldProp(k, v); else setObjProp(k, v);
});
$('#props').addEventListener('change', () => commit());
const INT_MIN1 = new Set(['w', 'h', 'd', 'r', 'range']);
function setObjProp(k, v) {
  const o = byId(sel); if (!o) return;
  let again = false;
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
$('#bPreview').onclick = () => { setMode(mode === 'preview' ? 'edit' : 'preview'); };
$('#bPlay').onclick = () => { if (mode === 'play') stopPlay(); else startPlay(); };
function setMode(m) {
  mode = m;
  $('#bPreview').classList.toggle('on', m === 'preview');
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
const play = { x: 0, z: 0, yaw: 0, pitch: 0, cols: [], saved: null };
function colliders(rad) {
  const out = [];
  for (const o of S.objects) {
    if (!o.visible || !o.solid) continue;
    let hx, hz, bot, top;
    if (o.kind === 'block') { const a = (o.yaw || 0) * D2R, c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a)); hx = (o.w * c + o.d * s) / 2; hz = (o.w * s + o.d * c) / 2; bot = o.y - o.h / 2; top = o.y + o.h / 2; }
    else if (o.kind === 'cyl') { hx = hz = o.r; bot = o.y - o.h / 2; top = o.y + o.h / 2; }
    else if (o.kind === 'ball') { hx = hz = o.r; bot = o.y - o.r; top = o.y + o.r; }
    else continue;
    if (top < 15 || bot > 160) continue;   // can't touch a standing player
    out.push([Math.round(o.x), Math.round(o.z), Math.round(hx + rad), Math.round(hz + rad)]);
  }
  return out;
}
const spawnOf = () => S.objects.find((o) => o.kind === 'spawn' && o.visible) || S.objects.find((o) => o.kind === 'spawn');
function startPlay() {
  const sp = spawnOf();
  play.x = sp ? sp.x : 0; play.z = sp ? sp.z : 400; play.yaw = sp ? sp.yaw || 0 : 0; play.pitch = 0;
  play.cols = colliders(25);
  play.saved = { x: cam.x, y: cam.y, z: cam.z, yaw: cam.yaw, pitch: cam.pitch };
  select(sel);
  setMode('play');
  $('#hud').innerHTML = '<b>WASD</b> walk &nbsp; <b>drag</b> look &nbsp; <b>Esc</b> stop' + (sp ? '' : ' &nbsp; <i>(no Spawn placed - starting at the middle)</i>');
  cv.focus();
}
function stopPlay() {
  if (mode !== 'play') return;
  Object.assign(cam, play.saved);
  setMode('edit'); applyCam(); updateGizmo();
}
const blocked = (x, z) => play.cols.some((c) => Math.abs(x - c[0]) < c[2] && Math.abs(z - c[1]) < c[3]);
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
  const sp = 240 * dt;   // the exported game moves 4 cm a frame at 60 fps
  const nx = P.x + mx * sp, nz = P.z + mz * sp;
  if (!blocked(nx, P.z)) P.x = nx;
  if (!blocked(P.x, nz)) P.z = nz;
  camera.position.set(P.x / 100, 1.65, P.z / 100);
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
  if (m.type === 'hello') { host.ok = true; if (!host.greeted) { host.greeted = true; autoLoadFromFile(); } }
  if (m.type === 'source' && host.waiting.has(m.req)) { const cb = host.waiting.get(m.req); host.waiting.delete(m.req); cb(m.source || ''); }
});
function getSource() {
  return new Promise((ok, fail) => {
    if (!host.ok) { fail(new Error('not-hosted')); return; }
    const req = host.req++; host.waiting.set(req, ok); toHost('getSource', { req });
    setTimeout(() => { if (host.waiting.has(req)) { host.waiting.delete(req); fail(new Error('timeout')); } }, 2500);
  });
}
let wide = false;
$('#bWide').onclick = () => { wide = !wide; toHost('wide', { on: wide }); $('#bWide').classList.toggle('on', wide); $('#bWide').textContent = wide ? '⤡ Narrow' : '⤢ Wide'; };

// ---------------------------------------------------------------------
//  Export: scene -> Volt code
// ---------------------------------------------------------------------
const RESERVED = new Set(('let fn if else while for each in repeat every frame forever when key pressed wait print show clear stop return break true false and or not pin on off toggle set fade tone button title html image draw write box canvas add remove to from at length contains part sign abs sin cos sqrt atan2 min max random constrain map held mousedx mousedy locked3d clicked3d hot3d sky3d px pz yaw pitch fx fz mx mz nx nz i t ws_blocked world3d block3d ball3d cyl3d lamp3d put3d model3d anim3d camera3d move3d turn3d show3d glow3d torch3d shine3d burst3d fx3d look3d render3d clear3d music sound round floor ceil int str ask uptime centered shadow flipped').split(' '));
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
function genVolt(opt) {
  const w = S.world, L = [], used = new Set(), idn = new Map();
  const game = opt.mode === 'game';
  S.objects.forEach((o) => { if (o.kind !== 'spawn') idn.set(o.id, identFor(o.name, used)); });
  if (game) {
    L.push('#html');
    L.push('// ' + (w.title || 'My 3D world') + ' - built with World Studio. Open the World Studio tab and press "Load from file" to keep editing the world.');
    L.push('// WASD to walk, mouse to look (click first)');
    L.push('title "' + (w.title || 'My 3D world') + '"');
    L.push('canvas 320, 180');
  } else {
    L.push('// ---- World Studio scene: ' + (w.title || 'My 3D world') + ' ----');
  }
  let wl = 'world3d ' + q(w.bg);
  if (w.fog > 0) wl += ' fog ' + r(w.fog);
  wl += ' ambient ' + r(w.ambient) + ' fov ' + r(w.fov);
  if (w.shadows) wl += ' shadows';
  L.push(wl);
  L.push('');
  for (const o of S.objects) {
    if (o.kind === 'spawn') continue;
    const n = idn.get(o.id);
    if (o.kind === 'block') L.push(`let ${n} = block3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.w)}, ${r(o.h)}, ${r(o.d)}, ${q(o.color)})`);
    else if (o.kind === 'ball') L.push(`let ${n} = ball3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.r)}, ${q(o.color)})`);
    else if (o.kind === 'cyl') L.push(`let ${n} = cyl3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${r(o.r)}, ${r(o.h)}, ${q(o.color)})`);
    else if (o.kind === 'lamp') L.push(`let ${n} = lamp3d(${r(o.x)}, ${r(o.y)}, ${r(o.z)}, ${q(o.color)}, ${r(o.power)}, ${r(o.range)})`);
    if (o.kind !== 'lamp') {
      if (o.yaw) L.push(`turn3d ${n}, ${r(o.yaw * 10)}`);
      if (o.glow) L.push(`glow3d ${n}, ${q(o.glow)}`);
      if (o.shine) L.push(`shine3d ${n}, ${r(o.rough)}, ${r(o.metal)}`);
    }
    if (!o.visible) L.push(`show3d ${n}, 0`);
  }
  if (w.bloom + w.vignette + w.grain > 0) { L.push(''); L.push(`fx3d ${r(w.bloom)}, ${r(w.vignette)}, ${r(w.grain)}`); }
  if (w.sky >= 0) L.push(`sky3d(${r(w.sky)})`);
  if (w.torch > 0) L.push(`torch3d ${r(w.torch)}, ${r(w.torchRange)}`);

  if (game) {
    const sp = spawnOf();
    L.push('');
    L.push(`let px = ${sp ? r(sp.x) : 0}`);
    L.push(`let pz = ${sp ? r(sp.z) : 400}`);
    L.push(`let yaw = ${sp ? r((sp.yaw || 0) * 10) : 0}`);
    L.push('let pitch = 0');
    const cols = opt.collide ? colliders(25) : [];
    if (opt.collide) {
      L.push('');
      L.push('// walls and pillars that stop the player: centre x, centre z, half-width, half-depth (in cm, already padded by the player\'s size)');
      L.push(`let ws_cx = [${cols.map((c) => c[0]).join(', ')}]`);
      L.push(`let ws_cz = [${cols.map((c) => c[1]).join(', ')}]`);
      L.push(`let ws_hx = [${cols.map((c) => c[2]).join(', ')}]`);
      L.push(`let ws_hz = [${cols.map((c) => c[3]).join(', ')}]`);
      L.push('');
      L.push('fn ws_blocked(x, z) {');
      L.push('  let i = 0');
      L.push('  while i < length(ws_cx) {');
      L.push('    if abs(x - ws_cx[i]) < ws_hx[i] and abs(z - ws_cz[i]) < ws_hz[i] {');
      L.push('      return true');
      L.push('    }');
      L.push('    i += 1');
      L.push('  }');
      L.push('  return false');
      L.push('}');
    }
    L.push('');
    L.push('every frame {');
    L.push('  yaw += mousedx() * 3');
    L.push('  pitch -= mousedy() * 3');
    L.push('  pitch = constrain(pitch, -800, 800)');
    L.push('  let fx = sin(yaw)');
    L.push('  let fz = 0 - cos(yaw)');
    L.push('  let mx = 0');
    L.push('  let mz = 0');
    L.push('  if held("w") {'); L.push('    mx += fx'); L.push('    mz += fz'); L.push('  }');
    L.push('  if held("s") {'); L.push('    mx -= fx'); L.push('    mz -= fz'); L.push('  }');
    L.push('  if held("a") {'); L.push('    mx -= cos(yaw)'); L.push('    mz -= sin(yaw)'); L.push('  }');
    L.push('  if held("d") {'); L.push('    mx += cos(yaw)'); L.push('    mz += sin(yaw)'); L.push('  }');
    L.push('  let nx = px + mx * 4 / 1000');
    L.push('  let nz = pz + mz * 4 / 1000');
    if (opt.collide) { L.push('  if not ws_blocked(nx, pz) { px = nx }'); L.push('  if not ws_blocked(px, nz) { pz = nz }'); }
    else { L.push('  px = nx'); L.push('  pz = nz'); }
    L.push('  camera3d px, 165, pz, yaw, pitch');
    L.push('  render3d');
    if (opt.hud) L.push('  write "WASD + mouse (click to capture)" at 160, 6 centered shadow');
    L.push('}');
  }
  L.push('');
  L.push('// world-studio: ' + JSON.stringify({ v: 1, world: S.world, objects: S.objects }));
  return L.join('\n') + '\n';
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
        S = { world: Object.assign(worldDefaults(), d.world || {}), objects: d.objects.filter((o) => o && KIND[o.kind]).map((o) => Object.assign({ id: 0, name: '', x: 0, y: 0, z: 0, yaw: 0, visible: true }, o)) };
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
  const lineRe = /^\s*let\s+([A-Za-z_]\w*)\s*=\s*(block3d|ball3d|cyl3d|lamp3d)\(([^)]*)\)/gm;
  let mm;
  while ((mm = lineRe.exec(src))) {
    const a = argsOf(mm[3]), nm = mm[1], k = mm[2];
    if (a.some((v, i) => !(strv(v) != null) && !Number.isFinite(Number(v)) && i < a.length)) continue;   // skip lines that use variables
    const n = (i) => Number(a[i]);
    let o = null;
    if (k === 'block3d' && a.length >= 6) o = makeObjQuiet('block', nm, { x: n(0), y: n(1), z: n(2), w: n(3), h: n(4), d: n(5), color: hex6(strv(a[6]) || '#8a8f99') });
    if (k === 'ball3d' && a.length >= 4) o = makeObjQuiet('ball', nm, { x: n(0), y: n(1), z: n(2), r: n(3), color: hex6(strv(a[4]) || '#c8ccd4') });
    if (k === 'cyl3d' && a.length >= 5) o = makeObjQuiet('cyl', nm, { x: n(0), y: n(1), z: n(2), r: n(3), h: n(4), color: hex6(strv(a[5]) || '#8a8f99') });
    if (k === 'lamp3d' && a.length >= 3) o = makeObjQuiet('lamp', nm, { x: n(0), y: n(1), z: n(2), color: hex6(strv(a[3]) || '#ffcc88'), power: a[4] != null ? n(4) : 40, range: a[5] != null ? n(5) : 600 });
    if (o) { o.id = nextI(); objs.push(o); byName[nm] = o; }
  }
  for (const gm of src.matchAll(/^\s*glow3d\s+([A-Za-z_]\w*)\s*,\s*"([^"]+)"/gm)) if (byName[gm[1]]) byName[gm[1]].glow = hex6(gm[2], '#ffffff');
  for (const sm of src.matchAll(/^\s*shine3d\s+([A-Za-z_]\w*)\s*,\s*(\d+)\s*,\s*(\d+)/gm)) if (byName[sm[1]]) Object.assign(byName[sm[1]], { shine: true, rough: Number(sm[2]), metal: Number(sm[3]) });
  for (const tm of src.matchAll(/^\s*turn3d\s+([A-Za-z_]\w*)\s*,\s*(-?\d+)/gm)) if (byName[tm[1]]) byName[tm[1]].yaw = Number(tm[2]) / 10;
  if (!objs.length) return { ok: false };
  S = { world, objects: objs }; nextId = objs.length + 1;
  const spawnM = /let\s+px\s*=\s*(-?\d+)[\s\S]{0,40}?let\s+pz\s*=\s*(-?\d+)/.exec(src);
  if (spawnM) { const yw = /let\s+yaw\s*=\s*(-?\d+)/.exec(src); S.objects.push(makeObjQuiet('spawn', 'Spawn', { id: nextId++, x: Number(spawnM[1]), z: Number(spawnM[2]), yaw: yw ? Number(yw[1]) / 10 : 0 })); }
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
  toast(`Loaded ${res.count} objects from the ${res.how}${res.partial ? ' - only plain block3d/ball3d/cyl3d/lamp3d lines could be read' : ''}.`);
}
function autoLoadFromFile() {
  getSource().then((src) => {
    if (/^\s*\/\/\s*world-studio:\s*\{/m.test(src)) { const res = importSource(src); if (res.ok) adoptImported(res); }
  }).catch(() => {});
}
$('#bLoad').onclick = () => {
  if (!host.ok) { toast('Open this panel inside Volt Studio to load from the current file (an older Volt Studio has no bridge).', true); return; }
  getSource().then((src) => {
    const res = importSource(src);
    if (!res.ok) { toast('No World Studio world found in the current file. Export one first, or use a file with block3d / lamp3d lines.', true); return; }
    adoptImported(res);
  }).catch(() => toast('Volt Studio did not answer. Try again.', true));
};

// ---- export dialog ----
const expOpt = { mode: 'game', collide: true, hud: true };
$('#bExport').onclick = () => {
  const opts = (k) => `<label><input type="${k[0]}" name="${k[1]}" data-o="${k[2]}"${k[3] ? ' checked' : ''}> ${k[4]}</label>`;
  openDialog('Export to Volt',
    '<p style="margin:2px 0 8px;color:var(--muted)">Turns your world into <b>#html</b> Volt 3D code. <b>Replace file</b> swaps the whole .volt file in the editor (Ctrl+Z in the code editor undoes it).</p>' +
    '<div class="opts">' +
      opts(['radio', 'mode', 'mode=game', expOpt.mode === 'game', 'Complete walk-around game']) +
      opts(['radio', 'mode', 'mode=scene', expOpt.mode === 'scene', 'Just the world (paste into my own game)']) +
    '</div><div class="opts" id="gameOpts">' +
      opts(['checkbox', 'c', 'collide', expOpt.collide, 'Walls stop the player']) +
      opts(['checkbox', 'h', 'hud', expOpt.hud, 'Controls hint on screen']) +
    '</div><textarea id="code" readonly spellcheck="false"></textarea>',
    [
      { label: 'Copy code', click: () => { toast(copyText($('#code').value) ? 'Copied the Volt code' : 'Could not copy - select the text and press Ctrl+C', false); } },
      { label: 'Insert at cursor', disabled: !host.ok, title: host.ok ? 'Pastes into the Volt editor where the cursor is' : 'Needs Volt Studio', click: () => { toHost('insert', { code: $('#code').value }); closeDialog(); toast('Inserted into the editor'); } },
      { label: 'Replace file', primary: true, disabled: !host.ok, title: host.ok ? 'Replaces everything in the Volt editor' : 'Needs Volt Studio', click: () => { toHost('replace', { code: $('#code').value }); closeDialog(); toast('Sent to the editor'); } },
      { label: 'Replace file & run', primary: true, disabled: !host.ok, click: () => { toHost('replace', { code: $('#code').value, run: true }); closeDialog(); toast('Sent to the editor - starting the game'); } },
    ]);
  const refresh = () => {
    expOpt.mode = $('[data-o="mode=game"]').checked ? 'game' : 'scene';
    expOpt.collide = $('[data-o="collide"]').checked; expOpt.hud = $('[data-o="hud"]').checked;
    $('#gameOpts').style.opacity = expOpt.mode === 'game' ? 1 : 0.4;
    $('#code').value = genVolt(expOpt);
  };
  $('#dlgBody').addEventListener('change', refresh);
  refresh();
};

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
new ResizeObserver(resize).observe(vp);
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
