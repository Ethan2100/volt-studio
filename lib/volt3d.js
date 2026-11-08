// ---- Volt 3D runtime (uses Three.js): world3d, block3d, lamp3d, camera3d, render3d ... ----
// In your program 1 unit = 1 cm (a 2 m wide corridor is 200). Angles are tenths of a degree (900 = a quarter turn).
// Yaw 0 looks "north" (towards -z); turning right makes the yaw bigger. Pitch above 0 looks up.
let __r3 = null, __sc3 = null, __cam3 = null, __amb3 = null, __torch3 = null, __halo3 = null;
let __objs3 = [], __mdx = 0, __mdy = 0, __tex3 = null;
const __geo3 = new Map(), __mat3 = new Map();
let __last3 = performance.now();

// a procedural grimy metal-panel texture (so flat colours still look like surfaces)
function __grime3() {
  if (__tex3) return __tex3;
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
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return (__tex3 = t);
}

// boxes share geometry; their texture coordinates are scaled so a panel is always about 2 m wide
function __geo(w, h, d) {
  const k = w + 'x' + h + 'x' + d;
  let g = __geo3.get(k);
  if (g) return g;
  g = new THREE.BoxGeometry(w / 100, h / 100, d / 100);
  const uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];   // +x -x +y -y +z -z
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) {
    const i = f * 4 + v;
    uv.setXY(i, uv.getX(i) * dims[f][0] / 200, uv.getY(i) * dims[f][1] / 200);
  }
  __geo3.set(k, g);
  return g;
}
let __flat3 = 0, __dayHex3 = '#9cc4e0';
function __look3d(flat, dayHex) { __flat3 = flat ? 1 : 0; __dayHex3 = String(dayHex); __mat3.clear(); return 0; }
function __mat(color, own) {
  const key = String(color);
  if (!own && __mat3.has(key)) return __mat3.get(key);
  const m = new THREE.MeshStandardMaterial({ color: key, map: __flat3 ? null : __grime3(), roughness: __flat3 ? 1 : 0.92, metalness: 0.04 });
  if (!own) __mat3.set(key, m);
  return m;
}

function __size3() {
  if (!__r3) return;
  __r3.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.25));
  __r3.setSize(window.innerWidth, window.innerHeight, false);
  __cam3.aspect = window.innerWidth / window.innerHeight;
  __cam3.updateProjectionMatrix();
  __fxResize3();
}

// world3d "#05060a" fog 1400 ambient 8 fov 75 shadows
let __fogFar = 0, __sun3 = null;
function __world3d(bg, fog, ambient, fov, shadows) {
  const col = new THREE.Color(String(bg == null ? '#000' : bg));
  if (!__r3) {
    __r3 = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
    __r3.domElement.className = 'volt-3d';
    document.body.classList.add('volt-game', 'volt-has3d');
    document.body.insertBefore(__r3.domElement, document.body.firstChild);
    __cam3 = new THREE.PerspectiveCamera(75, 1, 0.05, 80);
    __cam3.rotation.order = 'YXZ';
    window.addEventListener('resize', __size3);
    document.addEventListener('mousemove', (e) => { if (document.pointerLockElement) { __mdx += e.movementX; __mdy += e.movementY; } });
    document.addEventListener('mousedown', (e) => {
      if (!document.pointerLockElement && __cv && __hot3) {
        const rc = __cv.getBoundingClientRect();
        const gx = (e.clientX - rc.left) * __W / rc.width, gy = (e.clientY - rc.top) * __H / rc.height;
        if (gx >= __hot3[0] && gy >= __hot3[1] && gx < __hot3[0] + __hot3[2] && gy < __hot3[1] + __hot3[3]) { __clk3 = true; return; }
      }
      if (document.pointerLockElement || /^(BUTTON|INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;
      try { const r = (__cv || __r3.domElement).requestPointerLock(); if (r && r.catch) r.catch(() => {}); } catch (err) {}
    });
  }
  __clear3d();
  __sc3 = new THREE.Scene();
  __sc3.background = col;
  __fogFar = fog != null && fog > 0 ? fog / 100 : 0; __sun3 = null;
  if (fog != null && fog > 0) __sc3.fog = new THREE.Fog(col, 0.4, fog / 100);
  __amb3 = new THREE.AmbientLight(0x8890b0, (ambient == null ? 6 : ambient) / 100);
  __sc3.add(__amb3);
  __torch3 = __halo3 = null;
  __cam3.fov = fov == null ? 75 : fov;
  __r3.shadowMap.enabled = !!shadows;
  __r3.shadowMap.type = __fxOn3 ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  __pts3 = null;
  __size3();
}
function __need3() { if (!__r3 || !__sc3) throw new Error('Make the 3D world first, like: world3d "#05060a" fog 1400'); }

function __clear3d() {
  for (const o of __objs3) {
    if (!o) continue;
    if (o.mesh && o.own && !o.model) o.mesh.material.dispose();
    const n = o.mesh || o.light;
    if (n && n.parent) n.parent.remove(n);
    if (o.light && o.light.shadow && o.light.shadow.map) o.light.shadow.map.dispose();
  }
  __objs3 = [];
}

// block3d(x, y, z, w, h, d, "#8a8f99") -> an id. x, y, z is the middle of the box; y is up.
function __block3d(x, y, z, w, h, d, color) {
  __need3();
  const m = new THREE.Mesh(__geo(Math.max(1, w | 0), Math.max(1, h | 0), Math.max(1, d | 0)), __mat(color == null ? '#999' : color, false));
  m.position.set(x / 100, y / 100, z / 100);
  m.castShadow = m.receiveShadow = true;
  __sc3.add(m);
  __objs3.push({ mesh: m, color: color == null ? '#999' : color, own: false });
  return __objs3.length - 1;
}
// lamp3d(x, y, z, "#ffcc88", 40, 700) -> an id (a point light: power 0-100, range in cm)
function __lamp3d(x, y, z, color, power, range) {
  __need3();
  const l = new THREE.PointLight(String(color == null ? '#fff' : color), (power == null ? 40 : power) * 0.5, (range == null ? 600 : range) / 100, 1.6);
  l.position.set(x / 100, y / 100, z / 100);
  __sc3.add(l);
  __objs3.push({ light: l });
  return __objs3.length - 1;
}
function __o3(id) { const o = __objs3[id]; if (!o) throw new Error('There is no 3D object number ' + id); return o; }
function __move3d(id, x, y, z) { const o = __o3(id); (o.mesh || o.light).position.set(x / 100, y / 100, z / 100); }
function __turn3d(id, yaw) { const o = __o3(id); if (o.mesh) o.mesh.rotation.y = -yaw * __D2R; }
function __show3d(id, on) { const o = __o3(id); (o.mesh || o.light).visible = !!on; }
function __glow3d(id, color) {
  const o = __o3(id);
  if (!o.mesh) return;
  if (o.model) {   // a 3D model: give it its own materials, then light them
    if (!o.own) { o.mesh.traverse((c) => { if (c.isMesh) c.material = c.material.clone(); }); o.own = true; }
    o.mesh.traverse((c) => { if (c.isMesh && c.material.emissive) { c.material.emissive.set(String(color)); c.material.emissiveIntensity = 1.4; } });
    return;
  }
  if (!o.own) { o.mesh.material = __mat(o.color, true); o.own = true; }
  o.mesh.material.emissive.set(String(color));
  o.mesh.material.emissiveIntensity = 1.4;
}

// camera3d x, y, z, yaw, pitch
function __camera3d(x, y, z, yaw, pitch) {
  __need3();
  __cam3.position.set(x / 100, y / 100, z / 100);
  __cam3.rotation.set(Math.max(-1.5, Math.min(1.5, pitch * __D2R)), -yaw * __D2R, 0, 'YXZ');
}
// torch3d 60, 1800     (a flashlight on the camera: power 0 turns it off; range in cm)
function __torch3d(power, range) {
  __need3();
  if (!__torch3) {
    __torch3 = new THREE.SpotLight(0xe6f2ff, 0, 20, 0.72, 0.7, 1.3);
    __torch3.castShadow = __r3.shadowMap.enabled;
    __torch3.shadow.mapSize.set(1024, 1024);
    __torch3.shadow.bias = -0.0008;
    __halo3 = new THREE.PointLight(0xc8e0ff, 0, 5.5, 1.4);
    __sc3.add(__torch3, __torch3.target, __halo3);
  }
  __torch3.intensity = power * 1.3;
  __torch3.distance = range / 100;
  __halo3.intensity = power * 0.3;
  __torch3.visible = __halo3.visible = power > 0;
}
function __render3d() {
  __need3();
  const __now3 = performance.now(); const dt = Math.min(0.1, (__now3 - __last3) / 1000); __last3 = __now3;
  for (const o of __objs3) if (o && o.mixer) o.mixer.update(dt);
  if (__torch3) {
    const d = new THREE.Vector3(); __cam3.getWorldDirection(d);
    __torch3.position.copy(__cam3.position);
    __torch3.target.position.copy(__cam3.position).add(d);
    __halo3.position.copy(__cam3.position);
  }
  __fxRender3(dt);
  if (__cx) __cx.clearRect(0, 0, __W, __H);   // the 2D layer (box, write) is the HUD on top, redrawn every frame
}
function __mousedx() { const v = __mdx; __mdx = 0; return Math.round(v); }
function __mousedy() { const v = __mdy; __mdy = 0; return Math.round(v); }
let __hot3 = null, __clk3 = false;
function __hot3d(x, y, w, h) { __hot3 = [x, y, w, h]; return 0; }
function __clicked3d() { const v = __clk3; __clk3 = false; __hot3 = null; return v ? 1 : 0; }
function __locked3d() { return document.pointerLockElement ? 1 : 0; }

// model3d hunter = "hunter.glb" loads a .glb model before the program starts (it is packed into the page)
function __model3d(src, name) {
  const m = { scene: null, clips: [], name };
  __imgs.push(fetch(src).then((r) => r.arrayBuffer()).then((buf) => new Promise((ok, fail) => {
    new THREE.GLTFLoader().parse(buf, '', (g) => { m.scene = g.scene; m.clips = g.animations || []; ok(); },
      () => fail(new Error("Couldn't read the 3D model '" + name + "'. Use a .glb file with its textures packed inside")));
  })));
  return m;
}
// put3d(hunter, x, y, z, yaw, scale) -> an id. x, y, z is where the model's own origin goes; scale is a percent (100 = as made, 1 unit = 1 metre)
function __put3d(m, x, y, z, yaw, scale) {
  __need3();
  if (!m || !m.scene) throw new Error('put3d needs a model loaded with: model3d name = "file.glb"');
  const g = __clone3(m.scene);
  g.position.set(x / 100, y / 100, z / 100);
  g.rotation.y = -(yaw || 0) * __D2R;
  const k = (scale == null ? 100 : scale) / 100;
  g.scale.set(k, k, k);
  g.traverse((c) => { if (c.isMesh) { c.castShadow = c.receiveShadow = true; if (__flat3 && c.material && !c.material.__styled) { c.material.roughness = 1; c.material.metalness = 0; c.material.__styled = true; } } });
  __sc3.add(g);
  const o = { mesh: g, model: true, own: false, src: m, mixer: null, action: null };
  __objs3.push(o);
  return __objs3.length - 1;
}
// anim3d id, "walk"     (plays a model's animation on a loop; a name that is only part of the real one is fine)
function __anim3d(id, name) {
  const o = __o3(id);
  if (!o.model) return;
  const want = String(name).toLowerCase();
  const clips = o.src.clips;
  const clip = clips.find((c) => c.name.toLowerCase() === want) || clips.find((c) => c.name.toLowerCase().indexOf(want) >= 0);
  if (!clip) {
    if (want === '' || want === 'none') { if (o.action) o.action.fadeOut(0.2); o.action = null; return; }
    throw new Error("The model '" + o.src.name + "' has no animation called '" + name + "'. It has: " + (clips.map((c) => c.name).join(', ') || 'none'));
  }
  if (!o.mixer) o.mixer = new THREE.AnimationMixer(o.mesh);
  const a = o.mixer.clipAction(clip);
  if (o.action === a) return;
  if (/^(open|close|die|pick-up)$/.test(clip.name)) { a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; } else { a.setLoop(THREE.LoopRepeat, Infinity); }
  a.reset().fadeIn(0.2).play();
  if (o.action) o.action.fadeOut(0.2);
  o.action = a;
}

// sky3d(level): 0 = black night, 100 = bright day. Changes sky colour, fog, ambient light and the sun.
function __sky3d(level) {
  if (!__sc3) return 0;
  const k = Math.max(0, Math.min(100, level)) / 100;
  const night = new THREE.Color(__flat3 ? '#0b1032' : '#04060d'), dusk = new THREE.Color(__flat3 ? '#3a3568' : '#2a2438'), day = new THREE.Color(__dayHex3);
  const c = k < 0.5 ? night.clone().lerp(dusk, k * 2) : dusk.clone().lerp(day, (k - 0.5) * 2);
  __sc3.background = c;
  if (__sc3.fog) { __sc3.fog.color.copy(c); __sc3.fog.far = __fogFar * (0.35 + 0.65 * k); }
  if (__amb3) { __amb3.intensity = 0.05 + 0.75 * k; __amb3.color.setHex(k > 0.5 ? 0xdfe8ff : 0x7078a0); }
  if (!__sun3) { __sun3 = new THREE.DirectionalLight(0xfff0d0, 0); __sun3.position.set(40, 80, 30); __sc3.add(__sun3); }
  __sun3.intensity = 1.2 * k * k;
  return 0;
}

// ================= Volt 3D graphics upgrade =================
// fx3d bloom 60, vignette 40, grain 12   cinematic look: HDR bloom, film tone-mapping, vignette, film grain, soft shadows (all 0 = off)
// ball3d / cyl3d  spheres and cylinders      shine3d id, rough, metal  shiny and metal surfaces      burst3d  glowing particle bursts
let __fx3 = null, __fxOn3 = false, __pts3 = null, __envTex3 = null;
const __PMAX3 = 3000;
const __FXV3 = 'varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }';
const __FXBRIGHT3 = `
uniform sampler2D tDiffuse; uniform float thr; varying vec2 vUv;
void main() {
  vec3 c = texture2D(tDiffuse, vUv).rgb;
  float l = max(c.r, max(c.g, c.b));
  gl_FragColor = vec4(c * smoothstep(thr, thr + 0.6, l), 1.0);
}`;
const __FXBLUR3 = `
uniform sampler2D tDiffuse; uniform vec2 dir; varying vec2 vUv;
void main() {
  vec3 s = texture2D(tDiffuse, vUv).rgb * 0.2270270270;
  s += (texture2D(tDiffuse, vUv + dir * 1.3846153846).rgb + texture2D(tDiffuse, vUv - dir * 1.3846153846).rgb) * 0.3162162162;
  s += (texture2D(tDiffuse, vUv + dir * 3.2307692308).rgb + texture2D(tDiffuse, vUv - dir * 3.2307692308).rgb) * 0.0702702703;
  gl_FragColor = vec4(s, 1.0);
}`;
const __FXMIX3 = `
uniform sampler2D tScene; uniform sampler2D tB0; uniform sampler2D tB1; uniform sampler2D tB2;
uniform float sat; uniform float bloom; uniform float vig; uniform float grain; uniform float time; uniform vec2 res;
varying vec2 vUv;
vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }
vec3 toSRGB(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
void main() {
  vec2 d = vUv - 0.5;
  vec2 off = d * dot(d, d) * vig * 0.025;
  vec3 c;
  c.r = texture2D(tScene, vUv + off).r;
  c.g = texture2D(tScene, vUv).g;
  c.b = texture2D(tScene, vUv - off).b;
  c += (texture2D(tB0, vUv).rgb * 0.45 + texture2D(tB1, vUv).rgb * 0.35 + texture2D(tB2, vUv).rgb * 0.30) * bloom * 1.6;
  float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = max(mix(vec3(lum), c, sat), 0.0);
  c = toSRGB(aces(c * 1.05));
  c *= mix(1.0, 1.0 - smoothstep(0.25, 0.95, length(d) * 1.25), vig);
  float n = fract(sin(dot(vUv * res + time, vec2(12.9898, 78.233))) * 43758.5453);
  c += (n - 0.5) * grain * 0.14;
  gl_FragColor = vec4(c, 1.0);
}`;

function __fxBuild3() {
  const rt = (w, h, samples) => new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: samples || 0, depthBuffer: !!samples });
  const sm = (frag, u) => new THREE.ShaderMaterial({ vertexShader: __FXV3, fragmentShader: frag, uniforms: u, depthTest: false, depthWrite: false });
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(new Float32Array([-1, -1, 0, 3, -1, 0, -1, 3, 0]), 3));
  g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array([0, 0, 2, 0, 0, 2]), 2));
  const quad = new THREE.Mesh(g, null); quad.frustumCulled = false;
  const scene = new THREE.Scene(); scene.add(quad);
  const f = {
    quad, scene, cam: new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1),
    rt: rt(4, 4, 4), bright: rt(4, 4), h: [rt(4, 4), rt(4, 4), rt(4, 4)], v: [rt(4, 4), rt(4, 4), rt(4, 4)],
    mBright: sm(__FXBRIGHT3, { tDiffuse: { value: null }, thr: { value: 0.8 } }),
    mBlur: sm(__FXBLUR3, { tDiffuse: { value: null }, dir: { value: new THREE.Vector2() } }),
    mMix: sm(__FXMIX3, { tScene: { value: null }, tB0: { value: null }, tB1: { value: null }, tB2: { value: null },
      sat: { value: 1 }, bloom: { value: 0 }, vig: { value: 0 }, grain: { value: 0 }, time: { value: 0 }, res: { value: new THREE.Vector2(1, 1) } }),
    sizes: []
  };
  return f;
}
function __fxResize3() {
  if (!__fx3 || !__r3) return;
  const f = __fx3, s = __r3.getDrawingBufferSize(new THREE.Vector2());
  f.rt.setSize(s.x, s.y);
  f.mMix.uniforms.res.value.set(s.x, s.y);
  f.sizes = [];
  for (let i = 0; i < 3; i++) {
    const w = Math.max(2, s.x >> (i + 1)), h = Math.max(2, s.y >> (i + 1));
    f.h[i].setSize(w, h); f.v[i].setSize(w, h); f.sizes.push([w, h]);
    if (i === 0) f.bright.setSize(w, h);
  }
}
// fx3d bloom, vignette, grain   (each 0-100; all 0 turns the cinematic look off)
function __fx3d(bloom, vignette, grain) {
  __need3();
  const k = (v) => Math.max(0, Math.min(100, v || 0)) / 100;
  const b = k(bloom), v = k(vignette), g = k(grain);
  __fxOn3 = (b + v + g) > 0;
  __r3.shadowMap.type = __fxOn3 ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  if (!__fxOn3) return;
  if (!__fx3) { __fx3 = __fxBuild3(); __fxResize3(); }
  const u = __fx3.mMix.uniforms;
  u.bloom.value = b; u.vig.value = v; u.grain.value = g; u.sat.value = __flat3 ? 1.35 : 1;
}
function __fxPass3(mat, target) {
  __fx3.quad.material = mat;
  __r3.setRenderTarget(target);
  __r3.render(__fx3.scene, __fx3.cam);
}
function __fxRender3(dt) {
  __ptsUpdate3(dt);
  if (!__fxOn3 || !__fx3) { __r3.render(__sc3, __cam3); return; }
  const f = __fx3, u = f.mMix.uniforms;
  __r3.setRenderTarget(f.rt);
  __r3.render(__sc3, __cam3);
  if (u.bloom.value > 0) {
    f.mBright.uniforms.tDiffuse.value = f.rt.texture;
    __fxPass3(f.mBright, f.bright);
    let src = f.bright.texture;
    for (let i = 0; i < 3; i++) {
      const w = f.sizes[i][0], h = f.sizes[i][1];
      f.mBlur.uniforms.tDiffuse.value = src; f.mBlur.uniforms.dir.value.set(1 / w, 0);
      __fxPass3(f.mBlur, f.h[i]);
      f.mBlur.uniforms.tDiffuse.value = f.h[i].texture; f.mBlur.uniforms.dir.value.set(0, 1 / h);
      __fxPass3(f.mBlur, f.v[i]);
      src = f.v[i].texture;
    }
  }
  u.tScene.value = f.rt.texture; u.tB0.value = f.v[0].texture; u.tB1.value = f.v[1].texture; u.tB2.value = f.v[2].texture;
  u.time.value = (performance.now() % 100000) / 1000;
  __fxPass3(f.mMix, null);
}

// ball3d(x, y, z, radius, "#color") -> an id        cyl3d(x, y, z, radius, height, "#color") -> an id   (x, y, z is the middle)
function __ball3d(x, y, z, r, color) {
  __need3();
  const rr = Math.max(1, r | 0), k = 'ball' + rr;
  let g = __geo3.get(k);
  if (!g) {
    g = new THREE.SphereGeometry(rr / 100, 32, 22);
    const uv = g.attributes.uv;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.max(1, rr * 6.2832 / 200), uv.getY(i) * Math.max(1, rr * 3.1416 / 200));
    __geo3.set(k, g);
  }
  const m = new THREE.Mesh(g, __mat(color == null ? '#999' : color, false));
  m.position.set(x / 100, y / 100, z / 100);
  m.castShadow = m.receiveShadow = true;
  __sc3.add(m);
  __objs3.push({ mesh: m, color: color == null ? '#999' : color, own: false });
  return __objs3.length - 1;
}
function __cyl3d(x, y, z, r, h, color) {
  __need3();
  const rr = Math.max(1, r | 0), hh = Math.max(1, h | 0), k = 'cyl' + rr + 'x' + hh;
  let g = __geo3.get(k);
  if (!g) {
    g = new THREE.CylinderGeometry(rr / 100, rr / 100, hh / 100, 32);
    const uv = g.attributes.uv;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.max(1, rr * 6.2832 / 200), uv.getY(i) * Math.max(1, hh / 200));
    __geo3.set(k, g);
  }
  const m = new THREE.Mesh(g, __mat(color == null ? '#999' : color, false));
  m.position.set(x / 100, y / 100, z / 100);
  m.castShadow = m.receiveShadow = true;
  __sc3.add(m);
  __objs3.push({ mesh: m, color: color == null ? '#999' : color, own: false });
  return __objs3.length - 1;
}

// a soft studio-style reflection map, made once, so metal has something to reflect
function __env3() {
  if (__envTex3) return __envTex3;
  const pm = new THREE.PMREMGenerator(__r3);
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
  __envTex3 = pm.fromScene(s, 0.02).texture;
  pm.dispose();
  return __envTex3;
}
// shine3d id, rough, metal      (both 0-100: rough 0 is a mirror, 100 is chalk; metal 100 is solid metal)
function __shine3d(id, rough, metal) {
  const o = __o3(id);
  if (!o.mesh) return;
  const cl = (v) => Math.max(0, Math.min(100, v == null ? 50 : v)) / 100;
  const set = (m) => { if (!m || m.roughness === undefined) return; m.roughness = cl(rough); m.metalness = cl(metal); if (cl(metal) > 0.05) { m.envMap = __env3(); m.envMapIntensity = 1; } else m.envMap = null; m.needsUpdate = true; };
  if (o.model) {
    if (!o.own) { o.mesh.traverse((c) => { if (c.isMesh) c.material = c.material.clone(); }); o.own = true; }
    o.mesh.traverse((c) => { if (c.isMesh) set(c.material); });
    return;
  }
  if (!o.own) { o.mesh.material = __mat(o.color, true); o.own = true; }
  set(o.mesh.material);
}

// burst3d x, y, z, "#ff8844", 60, 350     (glowing sparks fly out and fall: count up to 300, speed in cm per second)
function __ptsInit3() {
  const g = new THREE.BufferGeometry();
  const pos = new Float32Array(__PMAX3 * 3), col = new Float32Array(__PMAX3 * 3);
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const c = document.createElement('canvas'); c.width = c.height = 64;
  const x = c.getContext('2d'), gr = x.createRadialGradient(32, 32, 0, 32, 32, 32);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.35, 'rgba(255,255,255,0.55)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = gr; x.fillRect(0, 0, 64, 64);
  const m = new THREE.PointsMaterial({ size: 0.09, map: new THREE.CanvasTexture(c), vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, sizeAttenuation: true });
  const p = new THREE.Points(g, m); p.frustumCulled = false;
  __sc3.add(p);
  __pts3 = { p, pos, col, vel: new Float32Array(__PMAX3 * 3), base: new Float32Array(__PMAX3 * 3), life: new Float32Array(__PMAX3), max: new Float32Array(__PMAX3), next: 0, live: 0 };
}
function __burst3d(x, y, z, color, count, speed) {
  __need3();
  if (!__pts3) __ptsInit3();
  const P = __pts3, c = new THREE.Color(String(color == null ? '#ffffff' : color));
  const n = Math.min(300, Math.max(1, (count == null ? 40 : count) | 0)), sp = (speed == null ? 300 : speed) / 100;
  for (let i = 0; i < n; i++) {
    const k = P.next; P.next = (k + 1) % __PMAX3;
    const u = Math.random() * 2 - 1, a = Math.random() * 6.2832, s = Math.sqrt(1 - u * u), v = sp * (0.3 + Math.random() * 0.7);
    P.pos[k * 3] = x / 100; P.pos[k * 3 + 1] = y / 100; P.pos[k * 3 + 2] = z / 100;
    P.vel[k * 3] = s * Math.cos(a) * v; P.vel[k * 3 + 1] = u * v + sp * 0.25; P.vel[k * 3 + 2] = s * Math.sin(a) * v;
    P.base[k * 3] = c.r * 2.4; P.base[k * 3 + 1] = c.g * 2.4; P.base[k * 3 + 2] = c.b * 2.4;
    P.max[k] = P.life[k] = 0.6 + Math.random() * 0.9;
  }
  P.live = __PMAX3;
}
function __ptsUpdate3(dt) {
  const P = __pts3;
  if (!P || !P.live) return;
  let any = 0;
  for (let k = 0; k < __PMAX3; k++) {
    if (P.life[k] <= 0) continue;
    P.life[k] -= dt;
    if (P.life[k] <= 0) { P.col[k * 3] = P.col[k * 3 + 1] = P.col[k * 3 + 2] = 0; continue; }
    any = 1;
    P.vel[k * 3 + 1] -= 4.2 * dt;
    const dr = Math.max(0, 1 - 1.4 * dt);
    P.vel[k * 3] *= dr; P.vel[k * 3 + 2] *= dr;
    P.pos[k * 3] += P.vel[k * 3] * dt; P.pos[k * 3 + 1] += P.vel[k * 3 + 1] * dt; P.pos[k * 3 + 2] += P.vel[k * 3 + 2] * dt;
    const f = P.life[k] / P.max[k], f2 = f * f;
    P.col[k * 3] = P.base[k * 3] * f2; P.col[k * 3 + 1] = P.base[k * 3 + 1] * f2; P.col[k * 3 + 2] = P.base[k * 3 + 2] * f2;
  }
  P.live = any;
  P.p.geometry.attributes.position.needsUpdate = true;
  P.p.geometry.attributes.color.needsUpdate = true;
}

// A copy of a model that has its OWN skeleton (a plain Object3D.clone shares one skeleton between every
// copy of a rigged model, so they would all stay frozen in the bind pose). Same idea as three's SkeletonUtils.clone.
function __clone3(src) {
  const clone = src.clone(true);
  const toSrc = new Map(), toClone = new Map();
  (function walk(a, b) { toSrc.set(b, a); toClone.set(a, b); for (let i = 0; i < a.children.length; i++) walk(a.children[i], b.children[i]); })(src, clone);
  clone.traverse((n) => {
    if (!n.isSkinnedMesh) return;
    const s = toSrc.get(n);
    n.skeleton = s.skeleton.clone();
    n.bindMatrix.copy(s.bindMatrix);
    n.skeleton.bones = s.skeleton.bones.map((b) => toClone.get(b));
    n.bind(n.skeleton, n.bindMatrix);
    n.frustumCulled = false;   // animated limbs can leave the bind-pose bounds
  });
  return clone;
}
