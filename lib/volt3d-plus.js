// ---- Volt 3D, part 2: scene graph, collision, a ready-made player, ray casts, static batching,
// ambient occlusion and 3D sound. Only added to pages that use one of these commands, so games
// written before it existed are byte-for-byte unchanged. Units match the rest of Volt 3D:
// 1 = 1 cm, angles in tenths of a degree, percentages 0-100. Decimals are fine everywhere. ----
let __pl3 = null, __frozen3 = [], __hit3 = { id: -1, dist: 0, x: 0, y: 0, z: 0 }, __ao3 = null;

function __live3(id, what) {
  const o = __o3(id);
  if (o.frozen) throw new Error("3D object " + id + " was joined into the level by freeze3d, so " + what + " can't change it. Make it after freeze3d, or don't freeze it");
  return o;
}
function __n3(o) { return o.mesh || o.light; }
function __touch3(id) { const o = __objs3[id]; if (o) o.box = null; }

// ---------- scene graph ----------
// scale3d id, 100, 200, 100     (percent of its made size: wide, tall, deep)
function __scale3d(id, sx, sy, sz) {
  const o = __live3(id, 'scale3d');
  __n3(o).scale.set(Math.max(0.001, sx / 100), Math.max(0.001, sy / 100), Math.max(0.001, sz / 100));
  o.box = null;
}
// tilt3d id, pitch, roll     (leans an object forward/back and side to side; turn3d still spins it)
function __tilt3d(id, pitch, roll) {
  const o = __live3(id, 'tilt3d'), n = __n3(o);
  n.rotation.order = 'YXZ';
  n.rotation.x = pitch * __D2R; n.rotation.z = roll * __D2R;
  o.box = null;
}
// color3d id, "#ff4d6d"
function __color3d(id, color) {
  const o = __live3(id, 'color3d');
  if (o.light) { o.light.color.set(String(color)); return; }
  if (o.model) {
    if (!o.own) { o.mesh.traverse((c) => { if (c.isMesh) c.material = c.material.clone(); }); o.own = true; }
    o.mesh.traverse((c) => { if (c.isMesh && c.material.color) c.material.color.set(String(color)); });
    return;
  }
  o.color = String(color);
  if (o.own) o.mesh.material.color.set(o.color); else o.mesh.material = __mat(o.color, false);
}
// remove3d id     (takes it out of the world for good; anything attached to it goes too)
function __remove3d(id) {
  const o = __live3(id, 'remove3d'), n = __n3(o);
  __objs3.forEach((c, i) => {
    if (!c || c === o) return;
    for (let p = __n3(c).parent; p; p = p.parent) if (p === n) { __objs3[i] = null; break; }
  });
  if (n.parent) n.parent.remove(n);
  if (o.mesh && o.own && !o.model) o.mesh.material.dispose();
  if (o.light && o.light.shadow && o.light.shadow.map) o.light.shadow.map.dispose();
  __objs3[id] = null;
}
// attach3d child, parent     (glues child to parent where it is now: it then moves, turns and scales with it)
// attach3d child, -1         (lets go again)
function __attach3d(child, parent) {
  const c = __live3(child, 'attach3d');
  if (parent == null || parent < 0) { __sc3.attach(__n3(c)); c.box = null; return; }
  if (parent === child) throw new Error("A 3D object can't be attached to itself");
  __n3(__live3(parent, 'attach3d')).attach(__n3(c));
  c.box = null;
}
// far3d 12000     (how far the camera sees, in cm: things beyond it aren't drawn)
function __far3d(cm) {
  __need3();
  __cam3.far = Math.max(1, cm / 100);
  __cam3.updateProjectionMatrix();
}

// ---------- collision ----------
// Blocks, balls and cylinders are solid; lamps never are; models are solid once you say so.
// solid3d id, false   lets the player walk through it       solid3d modelId, true   makes a model solid
function __solid3d(id, on) { const o = __o3(id); o.solid = !!on; }
function __isSolid3(o) { return !!o && !!o.mesh && (o.solid === undefined ? !o.model : o.solid) && (o.frozen || o.mesh.visible); }
// The space an object takes up, as a box in cm (worked out once, until it moves)
function __box3(o) {
  if (o.box) return o.box;
  const b = new THREE.Box3();
  if (o.mesh.parent) o.mesh.parent.updateWorldMatrix(true, false);
  o.mesh.updateWorldMatrix(false, true);
  b.setFromObject(o.mesh);
  o.box = [b.min.x * 100, b.min.y * 100, b.min.z * 100, b.max.x * 100, b.max.y * 100, b.max.z * 100];
  return o.box;
}
// touching3d(a, b) -> true when the two objects' boxes overlap
function __touching3d(a, b) {
  const A = __box3(__o3(a)), B = __box3(__o3(b));
  return A[0] < B[3] && A[3] > B[0] && A[1] < B[4] && A[4] > B[1] && A[2] < B[5] && A[5] > B[2];
}
// Is a standing box (feet at x, y, z; radius r; height h) inside something solid? Returns the object or null.
function __blocked3(x, y, z, r, h, skip) {
  for (let i = 0; i < __objs3.length; i++) {
    const o = __objs3[i];
    if (!__isSolid3(o) || i === skip) continue;
    const b = __box3(o);
    if (x + r > b[0] && x - r < b[3] && y + h > b[1] && y < b[4] && z + r > b[2] && z - r < b[5]) return o;
  }
  return null;
}

// ---------- a ready-made first-person player ----------
// player3d x, y, z                              puts the player's feet there (and makes the player the first time)
// player3d x, y, z speed 450 jump 420 height 170
// walk3d                                        once per frame: WASD / arrows / gamepad to move, mouse or right stick
//                                               to look, Space to jump, Shift to run. Walls, floors and steps just work.
function __player3d(x, y, z, speed, jump, height) {
  __need3();
  const p = __pl3 || { yaw: 0, pitch: 0, vy: 0, ground: false, r: 28, step: 32, gravity: 1500, speed: 380, jump: 430, h: 170 };
  p.x = x; p.y = y; p.z = z; p.vy = 0;
  if (speed != null) p.speed = Math.max(0, speed);
  if (jump != null) p.jump = Math.max(0, jump);
  if (height != null) p.h = Math.max(20, height);
  __pl3 = p;
  __camera3d(p.x, p.y + p.h - 10, p.z, p.yaw, p.pitch);
}
function __needPlayer3() { if (!__pl3) throw new Error('Make the player first, like: player3d 0, 0, 0'); return __pl3; }
function __padAxis3(i) {
  const g = (navigator.getGamepads ? Array.from(navigator.getGamepads()) : []).find((x) => x && x.connected);
  const v = g && g.axes[i] ? g.axes[i] : 0;
  return Math.abs(v) < 0.18 ? 0 : v;
}
function __padBtn3(i) {
  const g = (navigator.getGamepads ? Array.from(navigator.getGamepads()) : []).find((x) => x && x.connected);
  return !!(g && g.buttons[i] && g.buttons[i].pressed);
}
function __walk3d() {
  const p = __needPlayer3();
  const dt = 1 / 60;        // 'every frame' always runs 60 steps a second, however fast the screen is
  // look
  p.yaw += __mdx * 3 + __padAxis3(2) * 1800 * dt;
  p.pitch -= __mdy * 3 + __padAxis3(3) * 1400 * dt;
  __mdx = 0; __mdy = 0;
  p.pitch = Math.max(-850, Math.min(850, p.pitch));
  // move
  let f = (__held('w') || __held('up') ? 1 : 0) - (__held('s') || __held('down') ? 1 : 0) - __padAxis3(1);
  let s = (__held('d') || __held('right') ? 1 : 0) - (__held('a') || __held('left') ? 1 : 0) + __padAxis3(0);
  const len = Math.hypot(f, s);
  if (len > 1) { f /= len; s /= len; }
  const run = __held('shift') || __padBtn3(10) ? 1.6 : 1;
  const sn = Math.sin(p.yaw * __D2R), cs = Math.cos(p.yaw * __D2R);
  const dx = (sn * f + cs * s) * p.speed * run * dt, dz = (-cs * f + sn * s) * p.speed * run * dt;
  // one axis at a time, so you slide along a wall instead of sticking to it
  const tryMove = (mx, mz, depth) => {
    const nx = p.x + mx, nz = p.z + mz;
    const hit = __blocked3(nx, p.y, nz, p.r, p.h, -1);
    if (!hit) { p.x = nx; p.z = nz; return; }
    // a low edge (a stair, a kerb): step up onto it if there is room
    const top = __box3(hit)[4];
    if (p.ground && top - p.y > 0 && top - p.y <= p.step && !__blocked3(nx, top + 0.01, nz, p.r, p.h, -1)) { p.x = nx; p.z = nz; p.y = top + 0.01; return; }
    // otherwise get as close as possible, so you end up right against the wall
    if (depth < 3) tryMove(mx / 2, mz / 2, depth + 1);
  };
  if (dx) tryMove(dx, 0, 0);
  if (dz) tryMove(0, dz, 0);
  // jump and fall
  if ((__held('space') || __padBtn3(0)) && p.ground) { p.vy = p.jump; p.ground = false; }
  p.vy -= p.gravity * dt;
  const ny = p.y + p.vy * dt;
  const under = __blocked3(p.x, ny, p.z, p.r, p.h, -1);
  if (under && p.vy <= 0) { p.y = __box3(under)[4] + 0.01; p.vy = 0; p.ground = true; }      // landed
  else if (under) { p.vy = 0; }                                                                // bumped a ceiling
  else {
    p.y = ny;
    p.ground = p.vy <= 0 && !!__blocked3(p.x, ny - 1, p.z, p.r, p.h, -1);                      // still standing on something
    if (p.ground) p.vy = 0;
  }
  if (p.y < -5000) { p.y = 300; p.vy = 0; }             // fell out of the world: drop back in
  __camera3d(p.x, p.y + p.h - 10, p.z, p.yaw, p.pitch);
}
function __playerx() { return __needPlayer3().x; }
function __playery() { return __needPlayer3().y; }
function __playerz() { return __needPlayer3().z; }
function __playeryaw() { return __needPlayer3().yaw; }
function __playerpitch() { return __needPlayer3().pitch; }
function __onground() { return __needPlayer3().ground; }

// ---------- ray casts ----------
// ray3d(x, y, z, yaw, pitch, range) -> the id of the first thing in the way, or -1
// aim3d(range) -> the id of what the middle of the screen points at, or -1
// hitdist() -> how far away that was, in cm      hitx() hity() hitz() -> the exact spot
function __cast3(ox, oy, oz, dx, dy, dz, range) {
  let best = -1, bestT = range;
  const inv = [1 / (dx || 1e-9), 1 / (dy || 1e-9), 1 / (dz || 1e-9)], org = [ox, oy, oz];
  for (let i = 0; i < __objs3.length; i++) {
    const o = __objs3[i];
    if (!o || !o.mesh || !(o.frozen || o.mesh.visible)) continue;
    const b = __box3(o);
    let t0 = 0, t1 = bestT;
    for (let a = 0; a < 3 && t0 <= t1; a++) {
      let n = (b[a] - org[a]) * inv[a], f = (b[a + 3] - org[a]) * inv[a];
      if (n > f) { const s = n; n = f; f = s; }
      if (n > t0) t0 = n;
      if (f < t1) t1 = f;
    }
    if (t0 <= t1 && t0 < bestT) { bestT = t0; best = i; }
  }
  __hit3 = { id: best, dist: best < 0 ? range : bestT, x: ox + dx * bestT, y: oy + dy * bestT, z: oz + dz * bestT };
  return best;
}
function __ray3d(x, y, z, yaw, pitch, range) {
  const cp = Math.cos(pitch * __D2R);
  return __cast3(x, y, z, Math.sin(yaw * __D2R) * cp, Math.sin(pitch * __D2R), -Math.cos(yaw * __D2R) * cp, Math.max(0, range));
}
function __aim3d(range) {
  __need3();
  const d = new THREE.Vector3(); __cam3.getWorldDirection(d);
  return __cast3(__cam3.position.x * 100, __cam3.position.y * 100, __cam3.position.z * 100, d.x, d.y, d.z, Math.max(0, range));
}
function __hitdist() { return __hit3.dist; }
function __hitx() { return __hit3.x; }
function __hity() { return __hit3.y; }
function __hitz() { return __hit3.z; }

// ---------- static batching ----------
// freeze3d     Call it once after building a level. Every plain block, ball and cylinder made so
// far is joined into one mesh per colour, so 2,000 wall blocks draw as fast as one. Frozen things
// stay solid and can still be hit by rays, but can't be moved, hidden, recoloured or removed.
function __freeze3d() {
  __need3();
  const groups = new Map();
  __objs3.forEach((o) => {
    if (!o || !o.mesh || o.model || o.own || o.frozen || !o.mesh.visible || o.mesh.parent !== __sc3) return;
    const list = groups.get(o.mesh.material) || [];
    list.push(o); groups.set(o.mesh.material, list);
  });
  let joined = 0;
  const v = new THREE.Vector3(), nm = new THREE.Matrix3();
  groups.forEach((list, material) => {
    if (list.length < 2) return;
    let nv = 0, ni = 0;
    for (const o of list) { nv += o.mesh.geometry.attributes.position.count; ni += o.mesh.geometry.index.count; }
    const pos = new Float32Array(nv * 3), nor = new Float32Array(nv * 3), uv = new Float32Array(nv * 2);
    const idx = nv > 65535 ? new Uint32Array(ni) : new Uint16Array(ni);
    let vo = 0, io = 0;
    for (const o of list) {
      const g = o.mesh.geometry, P = g.attributes.position, N = g.attributes.normal, U = g.attributes.uv;
      o.mesh.updateMatrixWorld(true);
      nm.getNormalMatrix(o.mesh.matrixWorld);
      for (let i = 0; i < P.count; i++) {
        v.fromBufferAttribute(P, i).applyMatrix4(o.mesh.matrixWorld);
        pos[(vo + i) * 3] = v.x; pos[(vo + i) * 3 + 1] = v.y; pos[(vo + i) * 3 + 2] = v.z;
        v.fromBufferAttribute(N, i).applyMatrix3(nm).normalize();
        nor[(vo + i) * 3] = v.x; nor[(vo + i) * 3 + 1] = v.y; nor[(vo + i) * 3 + 2] = v.z;
        uv[(vo + i) * 2] = U.getX(i); uv[(vo + i) * 2 + 1] = U.getY(i);
      }
      for (let i = 0; i < g.index.count; i++) idx[io + i] = g.index.getX(i) + vo;
      vo += P.count; io += g.index.count;
      __box3(o);                       // remember where it was, for collisions and rays
      __sc3.remove(o.mesh);
      o.frozen = true;
      joined++;
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
    geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    geo.setIndex(new THREE.BufferAttribute(idx, 1));
    const mesh = new THREE.Mesh(geo, material);
    mesh.castShadow = mesh.receiveShadow = true;
    __sc3.add(mesh);
    __frozen3.push(mesh);
  });
  return joined;
}

// Moving, turning, hiding or clearing things must keep the collision boxes right. The original
// commands live in the first part of the runtime; these wrap them.
const __move3dBase = __move3d, __turn3dBase = __turn3d, __show3dBase = __show3d, __clear3dBase = __clear3d, __glow3dBase = __glow3d;
__move3d = function (id, x, y, z) { __live3(id, 'move3d'); __move3dBase(id, x, y, z); __touch3(id); };
__turn3d = function (id, yaw) { __live3(id, 'turn3d'); __turn3dBase(id, yaw); __touch3(id); };
__show3d = function (id, on) { __live3(id, 'show3d'); __show3dBase(id, on); };
__glow3d = function (id, color) { __live3(id, 'glow3d'); __glow3dBase(id, color); };
__clear3d = function () {
  __clear3dBase();
  for (const m of __frozen3) { if (m.parent) m.parent.remove(m); m.geometry.dispose(); }
  __frozen3 = []; __pl3 = null;
};

// ---------- ambient occlusion ----------
// ao3d 60     Soft shading in corners and where things meet (0 turns it off). It uses the same
// film pipeline as fx3d, so switching it on also switches on fx3d's tone mapping.
const __AODEPTH3 = `
#include <packing>
uniform sampler2D tDepth; uniform vec2 px; uniform float near; uniform float far; uniform float radius; varying vec2 vUv;
float viewZ(vec2 uv) { return -perspectiveDepthToViewZ(unpackRGBAToDepth(texture2D(tDepth, uv)), near, far); }
void main() {
  float z = viewZ(vUv);
  if (z > far * 0.98) { gl_FragColor = vec4(1.0); return; }
  float r = radius / z, occ = 0.0;
  float spin = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2832;
  for (int i = 0; i < 6; i++) {
    float a = spin + float(i) * 0.5236;
    vec2 o = vec2(cos(a), sin(a)) * r * (0.35 + 0.65 * float(i + 1) / 6.0) * px;
    // a pair of opposite points: on a flat wall they cancel out, in a corner both are nearer.
    // A big jump in distance is the edge of an object in front of something far away, not a corner.
    float d1 = z - viewZ(vUv + o), d2 = z - viewZ(vUv - o);
    float d = 0.5 * (d1 + d2);
    occ += smoothstep(0.015, 0.16, d) * (1.0 - smoothstep(0.22, 0.45, max(abs(d1), abs(d2))));
  }
  gl_FragColor = vec4(vec3(1.0 - occ / 6.0), 1.0);
}`;
const __AOBLUR3 = `
uniform sampler2D tDiffuse; uniform vec2 px; varying vec2 vUv;
void main() {
  float s = 0.0;
  for (int x = -2; x <= 1; x++) for (int y = -2; y <= 1; y++) s += texture2D(tDiffuse, vUv + (vec2(float(x), float(y)) + 0.5) * px).r;
  gl_FragColor = vec4(vec3(s / 16.0), 1.0);
}`;
function __ao3d(strength) {
  __need3();
  const k = Math.max(0, Math.min(100, strength || 0)) / 100;
  if (!__ao3) {
    if (k <= 0) return;
    if (!__fx3) { __fx3 = __fxBuild3(); }
    const f = __fx3;
    const sm = (frag, u) => new THREE.ShaderMaterial({ vertexShader: __FXV3, fragmentShader: frag, uniforms: u, depthTest: false, depthWrite: false });
    // the final mix, with one more input: the occlusion picture
    const mix = sm(__FXMIX3
      .replace('uniform float sat;', 'uniform sampler2D tAO; uniform float ao; uniform float sat;')
      .replace('c += (texture2D(tB0', 'c *= mix(1.0, texture2D(tAO, vUv).r, ao);\n  c += (texture2D(tB0'), {});
    mix.uniforms = Object.assign({}, f.mMix.uniforms, { tAO: { value: null }, ao: { value: 0 } });
    f.mMix = mix;
    __ao3 = {
      depth: new THREE.WebGLRenderTarget(4, 4, { minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter }),
      a: new THREE.WebGLRenderTarget(4, 4), b: new THREE.WebGLRenderTarget(4, 4),
      mDepth: new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking }),
      mAO: sm(__AODEPTH3, { tDepth: { value: null }, px: { value: new THREE.Vector2() }, near: { value: 0.05 }, far: { value: 80 }, radius: { value: 60 } }),
      mBlur: sm(__AOBLUR3, { tDiffuse: { value: null }, px: { value: new THREE.Vector2() } }),
      w: 0, h: 0, k: 0,
    };
    __fxResize3();
  }
  __ao3.k = k;
  __fx3.mMix.uniforms.ao.value = k;
  __aoKeep3();
}
// ao3d needs the film pipeline running even when bloom, vignette and grain are all 0
function __aoKeep3() { if (__ao3 && __ao3.k > 0) { __fxOn3 = true; __r3.shadowMap.type = THREE.PCFSoftShadowMap; } }
const __fx3dBase = __fx3d, __fxRender3Base = __fxRender3;
__fx3d = function (bloom, vignette, grain) { __fx3dBase(bloom, vignette, grain); __aoKeep3(); };
__fxRender3 = function (dt) {
  const a = __ao3;
  if (a && a.k > 0 && __fxOn3) {
    const s = __r3.getDrawingBufferSize(new THREE.Vector2()), w = Math.max(2, s.x >> 1), h = Math.max(2, s.y >> 1);
    if (w !== a.w || h !== a.h) { a.w = w; a.h = h; a.depth.setSize(w, h); a.a.setSize(w, h); a.b.setSize(w, h); }
    // 1. how far away everything is  2. where corners and creases are  3. soften it
    const pts = __pts3 && __pts3.visible;
    if (pts) __pts3.visible = false;
    __sc3.overrideMaterial = a.mDepth;
    const bg = __sc3.background, cc = __r3.getClearColor(new THREE.Color()), ca = __r3.getClearAlpha(), au = __r3.shadowMap.autoUpdate;
    __sc3.background = null; __r3.shadowMap.autoUpdate = false;
    __r3.setRenderTarget(a.depth); __r3.setClearColor(0xffffff, 1); __r3.clear(); __r3.render(__sc3, __cam3);
    __sc3.overrideMaterial = null; __sc3.background = bg; __r3.setClearColor(cc, ca); __r3.shadowMap.autoUpdate = au;
    if (pts) __pts3.visible = true;
    a.mAO.uniforms.tDepth.value = a.depth.texture; a.mAO.uniforms.px.value.set(1 / w, 1 / h);
    a.mAO.uniforms.near.value = __cam3.near; a.mAO.uniforms.far.value = __cam3.far;
    __fxPass3(a.mAO, a.a);
    a.mBlur.uniforms.tDiffuse.value = a.a.texture; a.mBlur.uniforms.px.value.set(1 / w, 1 / h);
    __fxPass3(a.mBlur, a.b);
    __fx3.mMix.uniforms.tAO.value = a.b.texture;
  }
  __fxRender3Base(dt);
};

// ---------- 3D sound ----------
// sound hit at x, y, z     Quieter the further it is from the camera, and panned left or right.
function __sound3d(a, x, y, z, vol) {
  if (!__gesture || !__cam3) return;
  try { __ac = __ac || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
  if (!a.busy) __loadSounds();
  if (!a.bufs || !a.bufs.length) return;
  const dx = x / 100 - __cam3.position.x, dy = y / 100 - __cam3.position.y, dz = z / 100 - __cam3.position.z;
  const d = Math.hypot(dx, dy, dz);
  const loud = (vol == null ? 1 : Math.max(0, vol / 100)) / (1 + (d / 4) * (d / 4));
  if (loud < 0.004) return;
  const right = new THREE.Vector3(1, 0, 0).applyQuaternion(__cam3.quaternion);
  const s = __ac.createBufferSource(), g = __ac.createGain();
  s.buffer = a.bufs[Math.floor(Math.random() * a.bufs.length)];
  g.gain.value = loud;
  s.connect(g);
  if (__ac.createStereoPanner && d > 0.01) {
    const pan = __ac.createStereoPanner();
    pan.pan.value = Math.max(-1, Math.min(1, (dx * right.x + dy * right.y + dz * right.z) / d));
    g.connect(pan); pan.connect(__sfxBus());
  } else g.connect(__sfxBus());
  s.start();
}
