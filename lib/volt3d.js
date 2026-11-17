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
    // Filmic response curve. Without this every bright pixel clips to flat
    // white and the picture reads as a toy renderer no matter how good the
    // lighting is. Exposure is nudged up to make up for the curve's rolloff.
    __r3.toneMapping = THREE.ACESFilmicToneMapping;
    __r3.toneMappingExposure = 1.15;
    __r3.outputColorSpace = THREE.SRGBColorSpace;
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
  // Every surface now picks up sky and bounce light, not just the metal ones
  // that asked for it through shine3d. Flat ambient on everything is the main
  // reason an untouched scene looks like plastic.
  try { __sc3.environment = __env3(); __sc3.environmentIntensity = 0.55; } catch (e) {}
  __torch3 = __halo3 = null;
  __cam3.fov = fov == null ? 75 : fov;
  __r3.shadowMap.enabled = !!shadows;
  __r3.shadowMap.type = __fxOn3 ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  __pts3 = null;
  __size3();
}
function __need3() { if (!__r3 || !__sc3) throw new Error('Make the 3D world first, like: world3d "#05060a" fog 1400'); }

function __clear3d() {
  __solDirty3 = true; __sol3 = []; __grid3 = null; __lastHit3 = -1; __phys3 = [];
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
  __solDirty3 = true;
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
function __move3d(id, x, y, z) { const o = __o3(id); (o.mesh || o.light).position.set(x / 100, y / 100, z / 100); __solDirty3 = true; }
function __turn3d(id, yaw) { const o = __o3(id); if (o.mesh) o.mesh.rotation.y = -yaw * __D2R; __solDirty3 = true; }
function __show3d(id, on) { const o = __o3(id); (o.mesh || o.light).visible = !!on; __solDirty3 = true; }
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
  __physStep3(dt);
  for (const o of __objs3) if (o && o.mixer) o.mixer.update(dt);
  __boneApply3();      // after the mixer, or the clip would overwrite it
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
  __solDirty3 = true;
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
  if (!__sun3) {
    __sun3 = new THREE.DirectionalLight(0xfff0d0, 0);
    __sun3.position.set(40, 80, 30);
    // The sun has been in the scene all along with castShadow never set, so
    // daylight scenes had no shadows at all - only the torch did.
    __sun3.castShadow = true;
    __sun3.shadow.mapSize.set(2048, 2048);
    __sun3.shadow.bias = -0.0008;
    __sun3.shadow.normalBias = 0.02;
    const sc = __sun3.shadow.camera;
    sc.near = 1; sc.far = 260;
    sc.left = -60; sc.right = 60; sc.top = 60; sc.bottom = -60;
    sc.updateProjectionMatrix();
    __sc3.add(__sun3);
    __sc3.add(__sun3.target);
  }
  // Keep the shadow box around the camera, or distant ground loses its shadows.
  if (__cam3) {
    __sun3.position.set(__cam3.position.x + 40, 80, __cam3.position.z + 30);
    __sun3.target.position.set(__cam3.position.x, 0, __cam3.position.z);
    __sun3.target.updateMatrixWorld();
  }
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
  __solDirty3 = true;
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
  __solDirty3 = true;
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

// =====================================================================
// SOLIDS, COLLISION AND RAYCASTING
//
// Every shape and model is solid by default; lights never are. Nothing
// here costs a frame unless a program actually asks a question, and the
// answers come out of a coarse grid so a big world stays cheap.
//
//   solid3d id, 0            turn collision off for one object
//   bump3d(x, y, z, r)       1 if a ball of radius r there hits something
//   ground3d(x, z, drop)     the y of the floor under that spot, or -99999
//   hit3d(x,y,z, dx,dy,dz, range)   distance to what the ray hits, or -1
//   hitid3d()                which object that last hit3d found
//   aim3d(range)             what the camera is looking at, or -1
//
// All distances are in cm, like the rest of Volt's 3D.
// =====================================================================
let __sol3 = [], __solDirty3 = true, __grid3 = null, __lastHit3 = -1;
const __CELL3 = 4;                                  // grid cell size in metres
const __vA3 = new THREE.Vector3(), __vB3 = new THREE.Vector3();
const __ray3 = new THREE.Raycaster();

function __solid3d(id, on) { const o = __o3(id); o.solid = !!on; __solDirty3 = true; return 0; }

// Rebuilt lazily: only the first question after something moved pays for it.
function __solBuild3() {
  __sol3 = []; __grid3 = new Map();
  for (let i = 0; i < __objs3.length; i++) {
    const o = __objs3[i];
    if (!o || !o.mesh || !o.mesh.visible || o.socket) continue;
    if (o.solid === undefined) o.solid = true;      // shapes and models collide; lights have no .mesh
    if (!o.solid) continue;
    const b = new THREE.Box3().setFromObject(o.mesh);
    if (!isFinite(b.min.x) || b.isEmpty()) continue;
    const rec = { id: i, b, mesh: o.mesh };
    __sol3.push(rec);
    const x0 = Math.floor(b.min.x / __CELL3), x1 = Math.floor(b.max.x / __CELL3);
    const z0 = Math.floor(b.min.z / __CELL3), z1 = Math.floor(b.max.z / __CELL3);
    for (let cx = x0; cx <= x1; cx++) for (let cz = z0; cz <= z1; cz++) {
      const k = cx + ',' + cz;
      let cell = __grid3.get(k);
      if (!cell) { cell = []; __grid3.set(k, cell); }
      cell.push(rec);
    }
  }
  __solDirty3 = false;
}

// Every solid whose cell the given world-space box touches, each one once.
function __near3(minx, minz, maxx, maxz) {
  if (__solDirty3) __solBuild3();
  const out = [], seen = new Set();
  const x0 = Math.floor(minx / __CELL3), x1 = Math.floor(maxx / __CELL3);
  const z0 = Math.floor(minz / __CELL3), z1 = Math.floor(maxz / __CELL3);
  for (let cx = x0; cx <= x1; cx++) for (let cz = z0; cz <= z1; cz++) {
    const cell = __grid3.get(cx + ',' + cz);
    if (!cell) continue;
    for (const rec of cell) if (!seen.has(rec.id)) { seen.add(rec.id); out.push(rec); }
  }
  return out;
}

// bump3d(x, y, z, r) -> 1 if a ball of radius r centred there overlaps a solid.
// Test one axis at a time against this and you get walls you slide along
// instead of sticking to:
//   if bump3d(nx, y, z, 30) == 0 { x = nx }
//   if bump3d(x, y, nz, 30) == 0 { z = nz }
function __bump3d(x, y, z, r) {
  __need3();
  const px = x / 100, py = y / 100, pz = z / 100, pr = (r == null ? 30 : r) / 100;
  const cands = __near3(px - pr, pz - pr, px + pr, pz + pr);
  for (const rec of cands) {
    const b = rec.b;
    const cx = Math.max(b.min.x, Math.min(px, b.max.x));
    const cy = Math.max(b.min.y, Math.min(py, b.max.y));
    const cz = Math.max(b.min.z, Math.min(pz, b.max.z));
    const dx = px - cx, dy = py - cy, dz = pz - cz;
    if (dx * dx + dy * dy + dz * dz < pr * pr) { __lastHit3 = rec.id; return 1; }
  }
  __lastHit3 = -1;
  return 0;
}

// ground3d(x, z, drop) -> the top of the highest solid under that spot, in cm.
// Returns -99999 when there is nothing below within 'drop' cm, so a fall off
// the edge of the world reads as "no floor" instead of as solid ground.
function __ground3d(x, z, drop) {
  __need3();
  const px = x / 100, pz = z / 100, maxDrop = (drop == null ? 400 : drop) / 100;
  const cands = __near3(px, pz, px, pz);
  let best = -Infinity;
  for (const rec of cands) {
    const b = rec.b;
    if (px < b.min.x || px > b.max.x || pz < b.min.z || pz > b.max.z) continue;
    if (b.max.y > best) best = b.max.y;
  }
  if (best === -Infinity) return -99999;
  const y = Math.round(best * 100);
  return y < Math.round(-maxDrop * 100) ? -99999 : y;
}

// hit3d(x,y,z, dx,dy,dz, range) -> distance in cm to the first solid the ray
// meets, or -1. The direction does not need to be a unit vector. This hits the
// real triangles, not the box, so a model's shape is respected.
function __hit3d(x, y, z, dx, dy, dz, range) {
  __need3();
  if (__solDirty3) __solBuild3();
  __vA3.set(x / 100, y / 100, z / 100);
  __vB3.set(dx, dy, dz);
  if (__vB3.lengthSq() < 1e-12) { __lastHit3 = -1; return -1; }
  __vB3.normalize();
  const far = (range == null ? 5000 : range) / 100;
  __ray3.set(__vA3, __vB3);
  __ray3.near = 0; __ray3.far = far;
  const meshes = [];
  for (const rec of __sol3) meshes.push(rec.mesh);
  const hits = __ray3.intersectObjects(meshes, true);
  if (!hits.length) { __lastHit3 = -1; return -1; }
  // Walk up from the triangle that was hit to the object the program knows about.
  let node = hits[0].object, id = -1;
  while (node && id < 0) {
    for (const rec of __sol3) if (rec.mesh === node) { id = rec.id; break; }
    node = node.parent;
  }
  __lastHit3 = id;
  return Math.round(hits[0].distance * 100);
}

// hitid3d() -> the object the last hit3d, bump3d or aim3d found, or -1.
function __hitid3d() { return __lastHit3; }

// aim3d(range) -> what the camera is pointing at right now, or -1.
// The whole of "what am I looking at" for a first-person game, in one call.
function __aim3d(range) {
  __need3();
  const d = new THREE.Vector3();
  __cam3.getWorldDirection(d);
  const p = __cam3.position;
  const hit = __hit3d(p.x * 100, p.y * 100, p.z * 100, d.x, d.y, d.z, range);
  return hit < 0 ? -1 : __lastHit3;
}

// =====================================================================
// ANIMATION: BLENDING, ONE-SHOTS AND BONE SOCKETS
// =====================================================================

// Finds a clip by name the way anim3d does: exact match first, then partial.
function __clip3(o, name) {
  const want = String(name).toLowerCase();
  const clips = o.src.clips;
  return clips.find((c) => c.name.toLowerCase() === want)
      || clips.find((c) => c.name.toLowerCase().indexOf(want) >= 0) || null;
}
function __noClip3(o, name) {
  return new Error("The model '" + o.src.name + "' has no animation called '" + name
    + "'. It has: " + (o.src.clips.map((c) => c.name).join(', ') || 'none'));
}
function __mixer3(o) {
  if (!o.mixer) o.mixer = new THREE.AnimationMixer(o.mesh);
  return o.mixer;
}

// blend3d id, "walk", "run", amount
// Mixes two looping clips: 0 is all the first, 100 is all the second, and the
// values between are a real blend, not a cut. The two are kept in step with
// each other, so a walk blended into a run does not scissor its legs.
function __blend3d(id, nameA, nameB, amount) {
  const o = __o3(id);
  if (!o.model) return 0;
  const a = __clip3(o, nameA); if (!a) throw __noClip3(o, nameA);
  const b = __clip3(o, nameB); if (!b) throw __noClip3(o, nameB);
  const k = Math.max(0, Math.min(100, amount == null ? 0 : amount)) / 100;
  const mx = __mixer3(o);
  const actA = mx.clipAction(a), actB = mx.clipAction(b);

  // Stop whatever anim3d/once3d left running, so weights always add up to 1.
  if (o.action && o.action !== actA && o.action !== actB) { o.action.fadeOut(0.15); o.action = null; }
  if (o.blend) for (const old of o.blend) if (old !== actA && old !== actB) old.stop();

  // Phase lock: both clips are stretched towards the blended length, so the
  // footfalls of the two line up instead of drifting apart.
  const dur = a.duration + (b.duration - a.duration) * k;
  actA.setEffectiveTimeScale(a.duration > 0 ? dur / a.duration : 1);
  actB.setEffectiveTimeScale(b.duration > 0 ? dur / b.duration : 1);
  actA.setLoop(THREE.LoopRepeat, Infinity); actB.setLoop(THREE.LoopRepeat, Infinity);
  actA.setEffectiveWeight(1 - k); actB.setEffectiveWeight(k);
  if (!actA.isRunning()) { actA.play(); actA.time = actB.time || 0; }
  if (!actB.isRunning()) { actB.play(); actB.time = actA.time || 0; }
  o.blend = [actA, actB];
  return 0;
}

// once3d id, "swing"
// Plays a clip a single time, all the way through, and can be fired again
// while it is still running - which is what an attack button needs. The old
// anim3d refused to restart a clip that was already playing.
function __once3d(id, name) {
  const o = __o3(id);
  if (!o.model) return 0;
  const clip = __clip3(o, name); if (!clip) throw __noClip3(o, name);
  const mx = __mixer3(o);
  const act = mx.clipAction(clip);
  act.setLoop(THREE.LoopOnce, 1);
  act.clampWhenFinished = true;
  act.setEffectiveTimeScale(1);
  act.setEffectiveWeight(1);
  act.reset().play();                      // reset() is what allows the re-trigger
  if (o.action && o.action !== act) o.action.fadeOut(0.12);
  if (o.blend) for (const old of o.blend) if (old !== act) old.fadeOut(0.12);
  o.blend = null;
  o.action = act;
  return 0;
}

// socket3d parentId, "hand.R", childId
// Hangs one object off a bone of another, so a sword stays in a fist through
// every frame of every animation. Part of the name is enough: "hand" will
// find "mixamorig:RightHand". The child keeps the size it was placed at.
function __socket3d(parentId, boneName, childId) {
  const p = __o3(parentId), c = __o3(childId);
  if (!p.mesh || !c.mesh) return 0;
  const want = String(boneName).toLowerCase();
  let bone = null, names = [];
  p.mesh.traverse((n) => {
    if (!n.isBone) return;
    names.push(n.name);
    if (!bone && n.name.toLowerCase() === want) bone = n;
  });
  if (!bone) p.mesh.traverse((n) => { if (!bone && n.isBone && n.name.toLowerCase().indexOf(want) >= 0) bone = n; });
  if (!bone) {
    throw new Error("That model has no bone called '" + boneName + "'. Its bones are: "
      + (names.slice(0, 14).join(', ') || 'none - this model has no skeleton')
      + (names.length > 14 ? ', ...' : ''));
  }
  // The bone carries the parent's scale down to anything under it, so undo it
  // here or a sword put on a 2x character comes out 2x too big.
  bone.updateWorldMatrix(true, false);
  const ps = new THREE.Vector3();
  bone.matrixWorld.decompose(new THREE.Vector3(), new THREE.Quaternion(), ps);
  const keep = c.mesh.scale.clone();
  bone.add(c.mesh);
  c.mesh.position.set(0, 0, 0);
  c.mesh.rotation.set(0, 0, 0);
  c.mesh.scale.set(
    keep.x / (ps.x || 1),
    keep.y / (ps.y || 1),
    keep.z / (ps.z || 1)
  );
  c.socket = true;                 // socketed things ride the bone; they are not world solids
  __solDirty3 = true;
  return 0;
}

// =====================================================================
// PHYSICS: A BALL THAT BEHAVES LIKE ONE
//
// Volt could move things but never simulate them. This gives any object
// a velocity, gravity, a bounce and a spin that bends its flight, and
// steps it against the same solids collision uses. render3d advances it,
// so a program never deals with timesteps.
//
//   phys3d id, bounce, friction      make it physical (both 0-100)
//   kick3d id, vx, vy, vz            set its speed, in cm per second
//   spin3d id, sx, sy, sz            spin, which curves the flight
//   where3d(id, axis)                where it is now: 0=x 1=y 2=z, in cm
//   vel3d(id, axis)                  how fast, per axis, in cm per second
//   rest3d(id)                       1 once it has settled and stopped
// =====================================================================
const __GRAV3 = 9.8;                 // metres per second squared
const __MAGNUS3 = 0.00022;           // how hard spin bends a flight
const __SLEEP3 = 0.12;               // below this speed a resting ball stops
let __phys3 = [];

function __phys3d(id, bounce, friction) {
  const o = __o3(id);
  if (!o.mesh) return 0;
  o.phys = {
    v: new THREE.Vector3(),
    spin: new THREE.Vector3(),
    bounce: Math.max(0, Math.min(100, bounce == null ? 55 : bounce)) / 100,
    fric: Math.max(0, Math.min(100, friction == null ? 30 : friction)) / 100,
    r: 0,
    rest: false
  };
  // Radius comes from the object's own size, so a ball3d of any size works.
  const b = new THREE.Box3().setFromObject(o.mesh), s = new THREE.Vector3();
  b.getSize(s);
  o.phys.r = Math.max(0.02, Math.max(s.x, s.y, s.z) / 2);
  o.solid = false;                   // a moving ball is not part of the static world
  __solDirty3 = true;
  if (__phys3.indexOf(id) < 0) __phys3.push(id);
  return 0;
}
function __kick3d(id, vx, vy, vz) {
  const o = __o3(id);
  if (!o.phys) __phys3d(id, null, null);
  o.phys.v.set(vx / 100, vy / 100, vz / 100);
  o.phys.rest = false;
  return 0;
}
function __spin3d(id, sx, sy, sz) {
  const o = __o3(id);
  if (!o.phys) __phys3d(id, null, null);
  o.phys.spin.set(sx, sy, sz);
  return 0;
}
function __where3d(id, axis) {
  const o = __o3(id);
  const p = (o.mesh || o.light).position;
  return Math.round((axis === 0 ? p.x : axis === 1 ? p.y : p.z) * 100);
}
function __vel3d(id, axis) {
  const o = __o3(id);
  if (!o.phys) return 0;
  const v = o.phys.v;
  return Math.round((axis === 0 ? v.x : axis === 1 ? v.y : v.z) * 100);
}
function __rest3d(id) { const o = __o3(id); return o.phys && o.phys.rest ? 1 : 0; }

// One physics tick. Split into substeps so a ball kicked hard cannot pass
// through a wall between two frames, which is the classic way fast objects
// escape a world.
function __physStep3(dt) {
  if (!__phys3.length) return;
  if (__solDirty3) __solBuild3();
  for (const id of __phys3) {
    const o = __objs3[id];
    if (!o || !o.phys || !o.mesh) continue;
    const ph = o.phys;
    if (ph.rest) continue;
    const speed = ph.v.length();
    // Never move more than a third of the radius in one substep.
    const steps = Math.max(1, Math.min(8, Math.ceil(speed * dt / (ph.r * 0.6))));
    const h = dt / steps;
    for (let s = 0; s < steps; s++) {
      ph.v.y -= __GRAV3 * h;
      // Magnus: spin across the direction of travel pushes the ball sideways,
      // which is what makes a struck ball curve instead of flying straight.
      if (ph.spin.lengthSq() > 0) {
        const m = new THREE.Vector3().crossVectors(ph.spin, ph.v).multiplyScalar(__MAGNUS3);
        ph.v.addScaledVector(m, h * 60);
      }
      const p = o.mesh.position;
      p.addScaledVector(ph.v, h);
      __physResolve3(ph, p);
    }
    // Settled: sitting on something and barely moving.
    if (ph.grounded && ph.v.lengthSq() < __SLEEP3 * __SLEEP3) { ph.v.set(0, 0, 0); ph.rest = true; }
    o.mesh.rotation.x += ph.v.z * dt * 2.2 / ph.r;   // roll the ball as it travels
    o.mesh.rotation.z -= ph.v.x * dt * 2.2 / ph.r;
  }
}

// Push the ball back out of anything it has entered and reflect its velocity.
function __physResolve3(ph, p) {
  ph.grounded = false;
  const r = ph.r;
  const cands = __near3(p.x - r, p.z - r, p.x + r, p.z + r);
  for (const rec of cands) {
    const b = rec.b;
    const cx = Math.max(b.min.x, Math.min(p.x, b.max.x));
    const cy = Math.max(b.min.y, Math.min(p.y, b.max.y));
    const cz = Math.max(b.min.z, Math.min(p.z, b.max.z));
    let nx = p.x - cx, ny = p.y - cy, nz = p.z - cz;
    let d2 = nx * nx + ny * ny + nz * nz;
    if (d2 >= r * r) continue;
    let d = Math.sqrt(d2);
    if (d < 1e-6) {
      // Dead centre inside the box: push out along whichever face is nearest.
      const ex = Math.min(p.x - b.min.x, b.max.x - p.x);
      const ey = Math.min(p.y - b.min.y, b.max.y - p.y);
      const ez = Math.min(p.z - b.min.z, b.max.z - p.z);
      if (ey <= ex && ey <= ez) { nx = 0; ny = p.y > (b.min.y + b.max.y) / 2 ? 1 : -1; nz = 0; }
      else if (ex <= ez) { nx = p.x > (b.min.x + b.max.x) / 2 ? 1 : -1; ny = 0; nz = 0; }
      else { nx = 0; ny = 0; nz = p.z > (b.min.z + b.max.z) / 2 ? 1 : -1; }
      d = 1;
    } else { nx /= d; ny /= d; nz /= d; }
    p.x += nx * (r - d); p.y += ny * (r - d); p.z += nz * (r - d);
    const dot = ph.v.x * nx + ph.v.y * ny + ph.v.z * nz;
    if (dot < 0) {
      // Split into the part going into the surface and the part sliding along
      // it: the first bounces, the second is slowed by friction.
      ph.v.x -= (1 + ph.bounce) * dot * nx;
      ph.v.y -= (1 + ph.bounce) * dot * ny;
      ph.v.z -= (1 + ph.bounce) * dot * nz;
      const keep = 1 - ph.fric * 0.25;
      ph.v.x *= keep; ph.v.z *= keep;
      ph.spin.multiplyScalar(0.78);          // contact scrubs spin off
    }
    if (ny > 0.5) ph.grounded = true;
  }
}

// =====================================================================
// DIRECTIONAL BLEND SPACE AND ADDITIVE LAYERS
// =====================================================================

// blend4d id, "fwd", "back", "left", "right", dx, dy
// A real 2D blend space: the four clips are mixed by which way the character
// is actually moving, so running forward while drifting left is a genuine mix
// of two clips rather than a snap to the nearest one. dx and dy run -100..100.
function __blend4d(id, fwd, back, left, right, dx, dy) {
  const o = __o3(id);
  if (!o.model) return 0;
  const names = [fwd, back, left, right];
  const clips = names.map((n) => { const c = __clip3(o, n); if (!c) throw __noClip3(o, n); return c; });
  const mx = __mixer3(o);
  const x = Math.max(-100, Math.min(100, dx || 0)) / 100;
  const y = Math.max(-100, Math.min(100, dy || 0)) / 100;
  // Weight each corner by how much of the direction points at it.
  const w = [Math.max(0, y), Math.max(0, -y), Math.max(0, -x), Math.max(0, x)];
  let sum = w[0] + w[1] + w[2] + w[3];
  if (sum < 1e-4) { w[0] = 1; sum = 1; }            // standing still reads as forward
  if (o.action) { o.action.fadeOut(0.15); o.action = null; }
  const acts = [];
  for (let i = 0; i < 4; i++) {
    const a = mx.clipAction(clips[i]);
    a.setLoop(THREE.LoopRepeat, Infinity);
    a.setEffectiveTimeScale(1);
    a.setEffectiveWeight(w[i] / sum);
    if (!a.isRunning()) a.play();
    acts.push(a);
  }
  if (o.blend) for (const old of o.blend) if (acts.indexOf(old) < 0) old.stop();
  o.blend = acts;
  return 0;
}

// layer3d id, "aim", weight
// Plays a clip on top of whatever is already running instead of replacing it,
// so a character can keep running while the upper body does something else.
// The clip is converted to an additive one against its own first frame, which
// is what makes "on top of" mean a difference rather than an override.
function __layer3d(id, name, weight) {
  const o = __o3(id);
  if (!o.model) return 0;
  const clip = __clip3(o, name); if (!clip) throw __noClip3(o, name);
  const mx = __mixer3(o);
  if (!o.additive) o.additive = new Map();
  let add = o.additive.get(clip.name);
  if (!add) {
    add = clip.clone();
    THREE.AnimationUtils.makeClipAdditive(add);
    o.additive.set(clip.name, add);
  }
  const k = Math.max(0, Math.min(100, weight == null ? 100 : weight)) / 100;
  const a = mx.clipAction(add);
  a.blendMode = THREE.AdditiveAnimationBlendMode;
  a.setLoop(THREE.LoopRepeat, Infinity);
  a.setEffectiveWeight(k);
  if (!a.isRunning()) a.play();
  if (k <= 0) a.stop();
  return 0;
}

// bone3d id, "thigh_r", pitch, yaw, roll
// Points one bone of a model wherever you like, on top of whatever animation
// is playing. The library that ships with Volt has no kicking clip, so a
// football game drives the leg itself; the same call aims a head at a target
// or tilts a spine into a lean. Angles are in tenths of a degree, like the
// rest of Volt's 3D maths. Pass the bone name a model actually has - socket3d
// lists them in its error if you get it wrong.
function __bone3d(id, name, pitch, yaw, roll) {
  const o = __o3(id);
  if (!o.mesh) return 0;
  if (!o.bones) o.bones = new Map();
  const want = String(name).toLowerCase();
  let bone = o.bones.get(want);
  if (bone === undefined) {
    bone = null;
    o.mesh.traverse((n) => { if (!bone && n.isBone && n.name.toLowerCase() === want) bone = n; });
    if (!bone) o.mesh.traverse((n) => { if (!bone && n.isBone && n.name.toLowerCase().indexOf(want) >= 0) bone = n; });
    o.bones.set(want, bone);
  }
  if (!bone) return 0;
  // The mixer writes the clip's pose every frame, so this has to be applied
  // after it. Recording the offset here and letting render3d re-apply it is
  // what makes the bone hold its angle instead of flickering.
  if (!o.boneFix) o.boneFix = [];
  let rec = o.boneFix.find((r) => r.bone === bone);
  if (!rec) { rec = { bone }; o.boneFix.push(rec); }
  rec.x = (pitch || 0) * __D2R / 10;
  rec.y = (yaw || 0) * __D2R / 10;
  rec.z = (roll || 0) * __D2R / 10;
  return 0;
}
// Re-applied every frame once the animation mixer has written its pose.
function __boneApply3() {
  for (const o of __objs3) {
    if (!o || !o.boneFix) continue;
    for (const r of o.boneFix) {
      if (!r.x && !r.y && !r.z) continue;
      r.bone.rotation.x += r.x; r.bone.rotation.y += r.y; r.bone.rotation.z += r.z;
    }
  }
}
