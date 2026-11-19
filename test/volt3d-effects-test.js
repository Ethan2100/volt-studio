// Checks the 3D effects in lib/volt3d.js - slash3d, magic3d, shock3d and
// beam3d - by running the real code against a stand-in for three.js: they
// have to build the right shapes, be driven by the update loop, fade, and
// be cleaned up when they finish. Also compiles a program that uses all
// four, so the compiler wiring stays in step.
// Run with: node test/volt3d-effects-test.js
const fs = require('fs');
const path = require('path');
const volt = require('../compiler/volt.js');
const src = fs.readFileSync(path.join(__dirname, '..', 'lib', 'volt3d.js'), 'utf8');
const grab = (name) => {
  const i = src.indexOf('function ' + name + '(');
  if (i < 0) throw new Error('missing ' + name);
  let pd = 0, after = src.indexOf('(', i);
  for (let k = after; k < src.length; k++) { if (src[k] === '(') pd++; else if (src[k] === ')') { pd--; if (!pd) { after = k; break; } } }
  let d = 0;
  for (let k = src.indexOf('{', after); k < src.length; k++) { if (src[k] === '{') d++; else if (src[k] === '}') { d--; if (!d) return src.slice(i, k + 1); } }
};
const V3 = class { constructor(x = 0, y = 0, z = 0) { this.x = x; this.y = y; this.z = z; }
  set(x, y, z) { this.x = x; this.y = y; this.z = z; return this; }
  copy(v) { return this.set(v.x, v.y, v.z); } clone() { return new V3(this.x, this.y, this.z); }
  add(v) { return this.set(this.x + v.x, this.y + v.y, this.z + v.z); }
  sub(v) { return this.set(this.x - v.x, this.y - v.y, this.z - v.z); }
  multiplyScalar(k) { return this.set(this.x * k, this.y * k, this.z * k); }
  distanceTo(v) { return Math.hypot(this.x - v.x, this.y - v.y, this.z - v.z); }
  normalize() { const l = Math.hypot(this.x, this.y, this.z) || 1; return this.multiplyScalar(1 / l); } };
class Obj { constructor() { this.children = []; this.position = new V3(); this.rotation = { x: 0, y: 0, z: 0, set(a, b, c) { this.x = a; this.y = b; this.z = c; } };
    this.quaternion = { setFromUnitVectors() {} }; this.scale = { x: 1, y: 1, z: 1, setScalar(v) { this.x = this.y = this.z = v; }, set(a, b, c) { this.x = a; this.y = b; this.z = c; } }; }
  add(...k) { this.children.push(...k); return this; }
  remove(k) { this.children = this.children.filter((c) => c !== k); }
  traverse(fn) { fn(this); for (const c of this.children) c.traverse ? c.traverse(fn) : fn(c); } }
class Mesh extends Obj { constructor(geometry, material) { super(); this.geometry = geometry; this.material = material; } }
const disposed = { geo: 0, mat: 0 };
const THREE = {
  Group: Obj, Mesh, Vector3: V3,
  Color: class { constructor(c) { this.c = c; } },
  RingGeometry: class { dispose() { disposed.geo++; } }, PlaneGeometry: class { dispose() { disposed.geo++; } },
  CylinderGeometry: class { dispose() { disposed.geo++; } },
  MeshBasicMaterial: class { constructor(o) { Object.assign(this, o); } dispose() { disposed.mat++; } },
  AdditiveBlending: 2, DoubleSide: 2,
};
const scene = new Obj();
const body = `
const THREE = ARG.THREE; const __sc3 = ARG.scene; function __need3() {}
${grab('__fxMat3')}
${grab('__fxAdd3')}
${grab('__fxUpdate3')}
${grab('__slash3d')}
${grab('__magic3d')}
${grab('__shock3d')}
${grab('__beam3d')}
return { __slash3d, __magic3d, __shock3d, __beam3d, __fxUpdate3, live: () => __fxLive3.length };`;
const fx = new Function('ARG', 'let __fxLive3 = []; const __D2R3 = Math.PI / 180;' + body)({ THREE, scene });

let failed = 0;
const ok = (n, c, e = '') => { if (!c) failed++; console.log(`${c ? 'pass' : 'FAIL'}  ${n}${c ? '' : '  ' + e}`); };

fx.__slash3d(0, 120, -200, 900, 220, '#9fe8ff');
ok('a slash goes into the scene', scene.children.length === 1 && fx.live() === 1);
const slash = scene.children[0];
ok('the slash is an arc plus a bright edge', slash.children.length === 2);
ok('it faces the yaw it was given', Math.abs(slash.rotation.y - (-90 * Math.PI / 180)) < 1e-9, 'y=' + slash.rotation.y);
fx.__fxUpdate3(0.05);
ok('it grows as it plays', slash.scale.x > 0.55);
ok('it fades in first', slash.children[0].material.opacity > 0 && slash.children[0].material.opacity <= 1);
for (let i = 0; i < 10; i++) fx.__fxUpdate3(0.05);
ok('the slash is gone by the end', fx.live() === 0 && scene.children.length === 0);
ok('its geometry and material were thrown away', disposed.geo >= 2 && disposed.mat >= 2);

fx.__magic3d(0, 0, -200, 320, '#9d6bff', 1000);
const circle = scene.children[0];
ok('a magic circle lies flat', Math.abs(circle.rotation.x + Math.PI / 2) < 1e-9);
ok('it has two rings, a core and twelve ticks', circle.children.length === 4 && circle.children[3].children.length === 12);
fx.__fxUpdate3(0.2);
ok('its rings turn opposite ways', circle.children[0].rotation.z > 0 && circle.children[1].rotation.z < 0);
for (let i = 0; i < 12; i++) fx.__fxUpdate3(0.1);
ok('the circle ends after the time it was given', fx.live() === 0);

fx.__shock3d(0, 0, 0, 400, '#ffd23f');
const ring = scene.children[0];
const small = ring.scale.x;
fx.__fxUpdate3(0.2);
ok('a shockwave races outwards', ring.scale.x > small + 1, `${small} -> ${ring.scale.x}`);
ok('and fades as it goes', ring.material.opacity < 1);
for (let i = 0; i < 6; i++) fx.__fxUpdate3(0.1);

fx.__beam3d(0, 150, 0, 0, 150, -600, 24, '#ff5a4d');
const beam = scene.children[0];
ok('a beam sits between its two points', Math.abs(beam.position.z + 3) < 1e-9, 'z=' + beam.position.z);
fx.__fxUpdate3(0.15);
ok('the beam thins as it fades', beam.scale.x < 1 && beam.material.opacity < 1);
for (let i = 0; i < 6; i++) fx.__fxUpdate3(0.1);
ok('everything is cleaned up at the end', fx.live() === 0 && scene.children.length === 0);

// the commands themselves have to compile
const program = `#html
canvas 320, 180
world3d "#05060a" ambient 10
let floor = block3d(0, -5, 0, 800, 10, 800, "#55585f")
every frame {
  slash3d 0, 120, -200, 900, 220, "#9fe8ff"
  magic3d 0, 0, -200, 320, "#9d6bff", 1400
  shock3d 0, 0, -200, 400, "#ffd23f"
  beam3d 0, 150, 0, 0, 150, -600, 24, "#ff5a4d"
  camera3d 0, 165, 300, 0, 0
  render3d
}
`;
try {
  const { code } = volt.compile(program);
  const missing = ['__slash3d(', '__magic3d(', '__shock3d(', '__beam3d('].filter((f) => !code.includes(f));
  ok('all four commands compile and reach the runtime', missing.length === 0, 'missing ' + missing.join(', '));
} catch (e) { ok('all four commands compile and reach the runtime', false, e.message); }

for (const bad of ['slash3d 0, 0, 0', 'magic3d 1, 2, 3, 4, "#fff"', 'beam3d 1, 2, 3']) {
  let threw = false;
  try { volt.compile('#html\ncanvas 320, 180\nworld3d "#000"\n' + bad + '\n'); } catch (e) { threw = /needs \d+ values/.test(e.message); }
  ok('too few values are caught: ' + bad.split(' ')[0], threw);
}

process.exitCode = failed ? 1 : 0;
