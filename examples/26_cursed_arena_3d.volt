#html

// Cursed Arena - 3D anime action fighter (Volt gameplay + Three.js engine)
# ;(function () {
# const window_ = window;
# const G3 = window.G3 = {};
# const TAU = Math.PI * 2;
# const rand = (a, b) => a + Math.random() * (b - a);
# const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
# const lerp = (a, b, t) => a + (b - a) * t;
# const damp = (a, b, l, dt) => a + (b - a) * (1 - Math.exp(-l * dt));
# const ease = (t) => t * t * (3 - 2 * t);
# const easeOut = (t) => 1 - Math.pow(1 - clamp(t, 0, 1), 3);
# let THREE = null, renderer, scene, camera, composer, bloomPass, fxPass, moon, hemi, pointPool = [];
# const S = G3.S = {
#   t: 0, ts: 1, hs: 0, slowT: 0, slowS: 1, shakeAmt: 0, shakeT: 0, shakeMax: 1, fov: 62, fovKick: 0,
#   yaw: 0, pitch: 0.32, dist: 6.4, quality: 2, cine: null, flash: 0, ab: 0, warp: 0, inv: 0, invT: 0, bars: 0, barsTo: 0,
#   warpC: { x: 0.5, y: 0.5 }, vig: 0.28, tint: 0, tintTo: 0, tintColor: [1, 1, 1], ctr: { x: 0, y: 1.4, z: 0 }, lookX: 0, lookY: 0, focus: null
# };
# const QUALITY = [
#   { pr: 1, shadows: false, bloom: false, parts: 0.35, name: 'Low' },
#   { pr: 1.25, shadows: true, bloom: true, parts: 0.7, name: 'Medium' },
#   { pr: 1.75, shadows: true, bloom: true, parts: 1, name: 'High' }
# ];
# G3.quality = () => QUALITY[S.quality];
# 
# // ---------------------------------------------------------------------
# // Loading Three.js (+ bloom / screen-FX passes) from a CDN
# // ---------------------------------------------------------------------
# G3.load = async function () {
#   const base = 'https://unpkg.com/three@0.158.0/';
#   try {
#     const im = document.createElement('script'); im.type = 'importmap';
#     im.textContent = JSON.stringify({ imports: { three: base + 'build/three.module.js' } });
#     document.head.appendChild(im);
#     THREE = await import(base + 'build/three.module.js');
#     window.THREE = THREE;
#   } catch (e) { G3.ok = false; G3.err = String(e); console.error(e); return false; }
#   try {
#     const pp = base + 'examples/jsm/postprocessing/';
#     const m = await Promise.all(['EffectComposer', 'RenderPass', 'UnrealBloomPass', 'ShaderPass', 'OutputPass'].map((n) => import(pp + n + '.js')));
#     G3.pp = { EffectComposer: m[0].EffectComposer, RenderPass: m[1].RenderPass, UnrealBloomPass: m[2].UnrealBloomPass, ShaderPass: m[3].ShaderPass, OutputPass: m[4].OutputPass };
#   } catch (e) { G3.pp = null; console.warn('post-processing unavailable', e); }
#   G3.ok = true; return true;
# };
# 
# const FX_SHADER = {
#   uniforms: {
#     tDiffuse: { value: null }, uAb: { value: 0 }, uWarp: { value: 0 }, uCenter: { value: null }, uInv: { value: 0 }, uVig: { value: 0.28 },
#     uTint: { value: null }, uTintA: { value: 0 }, uSat: { value: 1 }, uCon: { value: 1 }, uBars: { value: 0 }, uFlash: { value: 0 }
#   },
#   vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
#   fragmentShader: [
#     'uniform sampler2D tDiffuse; uniform float uAb, uWarp, uInv, uVig, uTintA, uSat, uCon, uBars, uFlash; uniform vec2 uCenter; uniform vec3 uTint; varying vec2 vUv;',
#     'void main(){',
#     '  vec2 d = vUv - uCenter; float r = length(d);',
#     '  float pinch = uWarp * (1.0 - smoothstep(0.0, 0.75, r));',
#     '  vec2 uv = uCenter + d * (1.0 - pinch);',
#     '  vec2 off = d * uAb * (0.35 + r);',
#     '  vec3 c = vec3(texture2D(tDiffuse, uv + off).r, texture2D(tDiffuse, uv).g, texture2D(tDiffuse, uv - off).b);',
#     '  float l = dot(c, vec3(0.299, 0.587, 0.114));',
#     '  c = mix(vec3(l), c, uSat);',
#     '  c = (c - 0.5) * uCon + 0.5;',
#     '  c = mix(c, uTint * (l * 1.5 + 0.04), uTintA);',
#     '  c = mix(c, 1.0 - c, uInv);',
#     '  c += uFlash;',
#     '  float v = smoothstep(0.32, 0.98, length((vUv - 0.5) * vec2(1.0, 0.85)));',
#     '  c *= 1.0 - uVig * v;',
#     '  gl_FragColor = vec4(c, 1.0);',
#     '}'
#   ].join('\n')
# };
# 
# // ---------------------------------------------------------------------
# // Toon materials (3-band cel shading) with inverted-hull outlines
# // ---------------------------------------------------------------------
# let GRAD = null;
# function toonGrad() {
#   if (GRAD) return GRAD;
#   const d = new Uint8Array([60, 60, 60, 255, 150, 150, 150, 255, 255, 255, 255, 255]);
#   GRAD = new THREE.DataTexture(d, 3, 1, THREE.RGBAFormat); GRAD.minFilter = GRAD.magFilter = THREE.NearestFilter; GRAD.needsUpdate = true;
#   return GRAD;
# }
# G3.toon = (color, o) => new THREE.MeshToonMaterial(Object.assign({ color, gradientMap: toonGrad() }, o || {}));
# function outlineMat(th, color) {
#   const m = new THREE.MeshBasicMaterial({ color: color == null ? 0x07040f : color, side: THREE.BackSide });
#   m.onBeforeCompile = (sh) => { sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * ' + th.toFixed(4) + ';'); };
#   return m;
# }
# G3.tmesh = function (geo, color, o) {
#   o = o || {};
#   const m = new THREE.Mesh(geo, o.mat || G3.toon(color, o.mo));
#   m.castShadow = o.cast !== false; m.receiveShadow = !!o.recv;
#   if (o.outline !== false) { const ol = new THREE.Mesh(geo, outlineMat(o.th || 0.022, o.oc)); ol.userData.ol = true; m.add(ol); }
#   return m;
# };
# 
# // ---------------------------------------------------------------------
# // Init: renderer, scene, camera, lights, post
# // ---------------------------------------------------------------------
# G3.init = function () {
#   const el = document.createElement('div'); el.id = 'world3d'; document.body.insertBefore(el, document.body.firstChild);
#   const q = QUALITY[S.quality];
#   renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
#   renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, q.pr));
#   renderer.setSize(window.innerWidth, window.innerHeight);
#   renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
#   renderer.shadowMap.enabled = q.shadows; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
#   el.appendChild(renderer.domElement);
#   scene = new THREE.Scene(); scene.background = new THREE.Color(0x070817); scene.fog = new THREE.FogExp2(0x0a0c1e, 0.018);
#   camera = new THREE.PerspectiveCamera(S.fov, window.innerWidth / window.innerHeight, 0.1, 500);
#   hemi = new THREE.HemisphereLight(0x6f7fc8, 0x1a1020, 0.9); scene.add(hemi);
#   moon = new THREE.DirectionalLight(0x9fb4ff, 1.5); moon.position.set(-18, 34, -12); moon.castShadow = q.shadows;
#   moon.shadow.mapSize.set(2048, 2048); const sc = moon.shadow.camera; sc.left = -34; sc.right = 34; sc.top = 34; sc.bottom = -34; sc.near = 1; sc.far = 120; moon.shadow.bias = -0.0006;
#   scene.add(moon); scene.add(moon.target);
#   for (let i = 0; i < 4; i++) { const p = new THREE.PointLight(0xffffff, 0, 16, 2); p.userData = { life: 0, max: 1, i0: 0 }; scene.add(p); pointPool.push(p); }
#   if (G3.pp) {
#     const P = G3.pp;
#     composer = new P.EffectComposer(renderer);
#     composer.addPass(new P.RenderPass(scene, camera));
#     bloomPass = new P.UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.55, 0.55, 0.82); bloomPass.enabled = q.bloom;
#     composer.addPass(bloomPass);
#     composer.addPass(new P.OutputPass());
#     fxPass = new P.ShaderPass({ uniforms: THREE.UniformsUtils.clone(FX_SHADER.uniforms), vertexShader: FX_SHADER.vertexShader, fragmentShader: FX_SHADER.fragmentShader });
#     fxPass.uniforms.uCenter.value = new THREE.Vector2(0.5, 0.5); fxPass.uniforms.uTint.value = new THREE.Color(1, 1, 1);
#     composer.addPass(fxPass);
#   }
#   window.addEventListener('resize', () => {
#     camera.aspect = window.innerWidth / window.innerHeight; camera.updateProjectionMatrix();
#     renderer.setSize(window.innerWidth, window.innerHeight); if (composer) composer.setSize(window.innerWidth, window.innerHeight);
#     if (G3.overlayResize) G3.overlayResize();
#   });
#   // input: pointer lock + mouse buttons
#   const cv = renderer.domElement;
#   G3.mouse = { l: 0, r: 0, hl: false, hr: false };
#   cv.addEventListener('contextmenu', (e) => e.preventDefault());
#   document.addEventListener('contextmenu', (e) => { if (S.started) e.preventDefault(); });
#   document.addEventListener('mousemove', (e) => { if (document.pointerLockElement || G3.noLock) { S.lookX += e.movementX; S.lookY += e.movementY; } });
#   document.addEventListener('mousedown', (e) => {
#     if (!S.started || !(document.pointerLockElement || G3.noLock)) return;
#     if (e.button === 0) { G3.mouse.l++; G3.mouse.hl = true; } else if (e.button === 2) { G3.mouse.r++; G3.mouse.hr = true; }
#   });
#   document.addEventListener('mouseup', (e) => { if (e.button === 0) G3.mouse.hl = false; else if (e.button === 2) G3.mouse.hr = false; });
#   G3.lock = () => { try { cv.requestPointerLock(); } catch (e) { } };
#   G3.setQuality = (n) => {
#     S.quality = clamp(n | 0, 0, 2); const qq = QUALITY[S.quality];
#     renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, qq.pr)); renderer.setSize(window.innerWidth, window.innerHeight);
#     renderer.shadowMap.enabled = qq.shadows; moon.castShadow = qq.shadows; if (bloomPass) bloomPass.enabled = qq.bloom;
#     scene.traverse((o) => { if (o.material) { const ms = Array.isArray(o.material) ? o.material : [o.material]; ms.forEach((m) => m.needsUpdate = true); } });
#   };
#   G3.scene = scene; G3.camera = camera; G3.renderer = renderer;
#   G3.THREE = THREE;
# };
# G3.takeClick = (b) => { const m = G3.mouse; if (b === 0) { const n = m.l; m.l = 0; return n; } const n = m.r; m.r = 0; return n; };
# G3.heldBtn = (b) => (b === 0 ? G3.mouse.hl : G3.mouse.hr);
# G3.takeLook = () => { const x = S.lookX, y = S.lookY; S.lookX = 0; S.lookY = 0; S.yaw -= x * 0.0028; S.pitch = clamp(S.pitch + y * 0.0024, -0.35, 1.05); return 0; };
# G3.camYaw = () => S.yaw;
# 
# // ---------------------------------------------------------------------
# // Time control, shake, screen effects
# // ---------------------------------------------------------------------
# G3.hitstop = (ms) => { S.hs = Math.max(S.hs, ms / 1000); };
# G3.slowmo = (pct, ms) => { S.slowS = clamp(pct / 100, 0.05, 1); S.slowT = ms / 1000; };
# G3.shake = (amt, ms) => { S.shakeAmt = Math.max(S.shakeAmt * 0.6, amt); S.shakeT = ms / 1000; S.shakeMax = Math.max(0.05, ms / 1000); };
# G3.fovKick = (d) => { S.fovKick = Math.max(S.fovKick, d); };
# G3.aberr = (a) => { S.ab = Math.max(S.ab, a); };
# G3.warpAt = (wx, wy, wz, amt) => {
#   const v = new THREE.Vector3(wx, wy, wz).project(camera); S.warpC.x = v.x * 0.5 + 0.5; S.warpC.y = v.y * 0.5 + 0.5; S.warp = Math.max(S.warp, amt);
# };
# G3.invert = (ms) => { S.invT = Math.max(S.invT, ms / 1000); };
# G3.flashScreen = (a) => { S.flash = Math.max(S.flash, a); };
# G3.bars = (on) => { S.barsTo = on ? 1 : 0; };
# G3.grade = (hex, a) => { S.tintColor = [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255]; S.tintTo = a; };
# G3.frozen = () => S.hs > 0;
# G3.timeScale = () => (S.hs > 0 ? 0.04 : (S.slowT > 0 ? S.slowS : 1));
# 
# G3.pointFlash = function (x, y, z, hex, power, life) {
#   let best = pointPool[0];
#   for (const p of pointPool) { if (p.userData.life <= 0) { best = p; break; } if (p.userData.life < best.userData.life) best = p; }
#   best.position.set(x, y, z); best.color.setHex(hex); best.userData.life = life; best.userData.max = life; best.userData.i0 = power;
# };
# 
# // ---------------------------------------------------------------------
# // Camera
# // ---------------------------------------------------------------------
# const _v = () => new THREE.Vector3();
# let camPos = null, camLook = null;
# G3.cine = function (kind, x, y, z, dur, a0, a1, rad, h) { S.cine = { kind, x, y, z, t: 0, dur, a0: a0 || 0, a1: a1 == null ? 1.6 : a1, rad: rad || 7, h: h == null ? 2.2 : h }; };
# G3.cineEnd = function () { S.cine = null; };
# G3.camTarget = function (x, y, z) { S.ctr.x = x; S.ctr.y = y; S.ctr.z = z; };
# G3.camFocus = function (x, z, w) { S.focus = w > 0 ? { x, z, w } : null; };
# 
# function updateCamera(rdt) {
#   if (!camPos) { camPos = _v(); camLook = _v(); camPos.set(0, 3, 8); }
#   let fovT = S.fov + S.fovKick; S.fovKick = damp(S.fovKick, 0, 8, rdt);
#   const c = S.cine;
#   let pos = _v(), look = _v();
#   if (c) {
#     c.t += rdt; const u = clamp(c.t / c.dur, 0, 1), a = lerp(c.a0, c.a1, ease(u));
#     if (c.kind === 'orbit') { pos.set(c.x + Math.sin(a) * c.rad, c.y + c.h + u * 0.4, c.z + Math.cos(a) * c.rad); look.set(c.x, c.y + 1.3, c.z); }
#     else if (c.kind === 'push') { const rr = lerp(c.rad, c.rad * 0.42, ease(u)); pos.set(c.x + Math.sin(c.a0) * rr, c.y + c.h * (1 - 0.4 * u), c.z + Math.cos(c.a0) * rr); look.set(c.x, c.y + 1.5, c.z); fovT += u * -10; }
#     else if (c.kind === 'low') { pos.set(c.x + Math.sin(a) * c.rad, c.y + 0.5, c.z + Math.cos(a) * c.rad); look.set(c.x, c.y + 2.2, c.z); }
#     if (c.t >= c.dur + 0.001 && c.dur > 0) { S.cine = null; }
#     camPos.lerp(pos, 1 - Math.exp(-14 * rdt)); camLook.lerp(look, 1 - Math.exp(-14 * rdt));
#   } else {
#     const cp = Math.cos(S.pitch), sp = Math.sin(S.pitch);
#     let yaw = S.yaw;
#     const tx = S.ctr.x, ty = S.ctr.y + 0.4, tz = S.ctr.z;
#     const sx = Math.cos(yaw) * 0.85, sz = -Math.sin(yaw) * 0.85; // over-the-shoulder offset
#     pos.set(tx + Math.sin(yaw) * cp * S.dist + sx, ty + sp * S.dist + 0.6, tz + Math.cos(yaw) * cp * S.dist + sz);
#     if (pos.y < 0.5) pos.y = 0.5;
#     look.set(tx + sx * 0.5, ty + 0.55, tz + sz * 0.5);
#     camPos.lerp(pos, 1 - Math.exp(-18 * rdt)); camLook.lerp(look, 1 - Math.exp(-22 * rdt));
#   }
#   camera.position.copy(camPos);
#   if (S.shakeT > 0) {
#     S.shakeT -= rdt; const f = clamp(S.shakeT / S.shakeMax, 0, 1) * S.shakeAmt;
#     camera.position.x += rand(-f, f) * 0.35; camera.position.y += rand(-f, f) * 0.35; camera.position.z += rand(-f, f) * 0.35;
#   } else S.shakeAmt = 0;
#   camera.lookAt(camLook);
#   if (S.shakeT > 0) camera.rotation.z += rand(-1, 1) * S.shakeAmt * 0.004 * clamp(S.shakeT / S.shakeMax, 0, 1);
#   if (Math.abs(camera.fov - fovT) > 0.01) { camera.fov = damp(camera.fov, fovT, 12, rdt); camera.updateProjectionMatrix(); }
# }
# // ---------------------------------------------------------------------
# // VFX foundation: particles, sparks, debris, decals, shader materials
# // ---------------------------------------------------------------------
# const UT = { value: 0 };
# const GLSL_NOISE = [
#   'float hash(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }',
#   'float vnoise(vec3 x){ vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);',
#   '  return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),',
#   '             mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z); }'
# ].join('\n');
# const hexRGB = (h, g) => { g = g == null ? 1 : g; return [((h >> 16) & 255) / 255 * g, ((h >> 8) & 255) / 255 * g, (h & 255) / 255 * g]; };
# const V3 = () => new THREE.Vector3();
# 
# let addSys = null, nrmSys = null, sparkSys = null, debrisSys = null;
# const fxList = [];
# const decals = [];
# let ringGeo = null;
# 
# function makePointSys(n, blending) {
#   const geo = new THREE.BufferGeometry();
#   const pos = new Float32Array(n * 3), col = new Float32Array(n * 4), siz = new Float32Array(n);
#   geo.setAttribute('position', new THREE.BufferAttribute(pos, 3).setUsage(THREE.DynamicDrawUsage));
#   geo.setAttribute('aCol', new THREE.BufferAttribute(col, 4).setUsage(THREE.DynamicDrawUsage));
#   geo.setAttribute('aSize', new THREE.BufferAttribute(siz, 1).setUsage(THREE.DynamicDrawUsage));
#   const mat = new THREE.ShaderMaterial({
#     transparent: true, depthWrite: false, blending,
#     uniforms: { uScale: { value: 600 } },
#     vertexShader: 'attribute vec4 aCol; attribute float aSize; varying vec4 vC; uniform float uScale; void main(){ vC = aCol; vec4 mv = modelViewMatrix * vec4(position, 1.0); gl_PointSize = aSize * uScale / max(0.1, -mv.z); gl_Position = projectionMatrix * mv; }',
#     fragmentShader: 'varying vec4 vC; void main(){ float d = length(gl_PointCoord - 0.5) * 2.0; float a = 1.0 - smoothstep(0.0, 1.0, d); a *= a; gl_FragColor = vec4(vC.rgb, vC.a * a); }'
#   });
#   const pts = new THREE.Points(geo, mat); pts.frustumCulled = false; pts.renderOrder = 5; scene.add(pts);
#   return { n, pos, col, siz, geo, pts, mat, list: [], free: [] };
# }
# function makeSparkSys(n) {
#   const geo = new THREE.BufferGeometry();
#   const pos = new Float32Array(n * 6), col = new Float32Array(n * 8);
#   geo.setAttribute('position', new THREE.BufferAttribute(pos, 3).setUsage(THREE.DynamicDrawUsage));
#   geo.setAttribute('aCol', new THREE.BufferAttribute(col, 4).setUsage(THREE.DynamicDrawUsage));
#   const mat = new THREE.ShaderMaterial({
#     transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
#     vertexShader: 'attribute vec4 aCol; varying vec4 vC; void main(){ vC = aCol; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
#     fragmentShader: 'varying vec4 vC; void main(){ gl_FragColor = vC; }'
#   });
#   const ls = new THREE.LineSegments(geo, mat); ls.frustumCulled = false; ls.renderOrder = 6; scene.add(ls);
#   return { n, pos, col, geo, ls, list: [], free: [] };
# }
# 
# // spawn a soft particle. o: x,y,z, vx,vy,vz, life, s0,s1 (world size), c0,c1 (hex), g (HDR gain), a0,a1, grav, drag, add (default true)
# function P(o) {
#   const sys = o.add === false ? nrmSys : addSys;
#   if (!sys || sys.list.length >= sys.n) return;
#   const q = QUALITY[S.quality]; if (q.parts < 1 && Math.random() > q.parts) return;
#   const p = sys.free.pop() || {};
#   p.x = o.x; p.y = o.y; p.z = o.z; p.vx = o.vx || 0; p.vy = o.vy || 0; p.vz = o.vz || 0;
#   p.life = 0; p.max = o.life || 0.6; p.s0 = o.s0 == null ? 0.3 : o.s0; p.s1 = o.s1 == null ? 0 : o.s1;
#   const g = o.g == null ? 1.4 : o.g;
#   p.c0 = hexRGB(o.c0 == null ? 0xffffff : o.c0, g); p.c1 = hexRGB(o.c1 == null ? (o.c0 == null ? 0xffffff : o.c0) : o.c1, g);
#   p.a0 = o.a0 == null ? 1 : o.a0; p.a1 = o.a1 == null ? 0 : o.a1; p.grav = o.grav || 0; p.drag = o.drag == null ? 0.5 : o.drag;
#   p.swirl = o.swirl || 0; p.ox = o.ox || 0; p.oy = o.oy || 0; p.oz = o.oz || 0;
#   sys.list.push(p);
# }
# G3.P = P;
# function sparkAdd(x, y, z, vx, vy, vz, life, hex, g) {
#   const s = sparkSys; if (!s || s.list.length >= s.n) return;
#   const q = QUALITY[S.quality]; if (q.parts < 1 && Math.random() > q.parts) return;
#   const p = s.free.pop() || {};
#   p.x = x; p.y = y; p.z = z; p.vx = vx; p.vy = vy; p.vz = vz; p.life = 0; p.max = life; p.c = hexRGB(hex, g == null ? 1.6 : g);
#   s.list.push(p);
# }
# function sparkBurst(x, y, z, n, speed, hex, life) {
#   for (let i = 0; i < n; i++) {
#     const a = rand(0, TAU), b = rand(-0.4, 1), s = rand(0.35, 1) * speed, h = Math.sqrt(Math.max(0, 1 - b * b));
#     sparkAdd(x, y, z, Math.cos(a) * h * s, b * s, Math.sin(a) * h * s, (life || 0.45) * rand(0.6, 1.2), hex);
#   }
# }
# G3.sparkBurst = sparkBurst;
# 
# function updateParticles(dt) {
#   for (const s of [addSys, nrmSys]) {
#     if (!s) continue;
#     let w = 0; const L = s.list;
#     for (let i = 0; i < L.length; i++) {
#       const p = L[i]; p.life += dt;
#       if (p.life >= p.max) { s.free.push(p); L[i] = null; continue; }
#       const u = p.life / p.max, dr = Math.exp(-p.drag * dt);
#       p.vy += p.grav * dt; p.vx *= dr; p.vy *= dr; p.vz *= dr;
#       if (p.swirl) { const sx = p.vx, sz = p.vz; const c = Math.cos(p.swirl * dt), sn = Math.sin(p.swirl * dt); p.vx = sx * c - sz * sn; p.vz = sx * sn + sz * c; }
#       p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
#       if (s === nrmSys && p.y < 0.05) { p.y = 0.05; p.vy = 0; }
#       const k = w * 3, k4 = w * 4;
#       s.pos[k] = p.x; s.pos[k + 1] = p.y; s.pos[k + 2] = p.z;
#       s.col[k4] = lerp(p.c0[0], p.c1[0], u); s.col[k4 + 1] = lerp(p.c0[1], p.c1[1], u); s.col[k4 + 2] = lerp(p.c0[2], p.c1[2], u); s.col[k4 + 3] = lerp(p.a0, p.a1, u);
#       s.siz[w] = lerp(p.s0, p.s1, u);
#       L[w] = p; w++;
#     }
#     L.length = w;
#     s.geo.setDrawRange(0, w);
#     s.geo.attributes.position.needsUpdate = true; s.geo.attributes.aCol.needsUpdate = true; s.geo.attributes.aSize.needsUpdate = true;
#     s.mat.uniforms.uScale.value = renderer.domElement.height / (2 * Math.tan(camera.fov * Math.PI / 360)) / renderer.getPixelRatio() * renderer.getPixelRatio();
#   }
#   const s = sparkSys; if (s) {
#     let w = 0; const L = s.list;
#     for (let i = 0; i < L.length; i++) {
#       const p = L[i]; p.life += dt;
#       if (p.life >= p.max) { s.free.push(p); L[i] = null; continue; }
#       p.vy -= 9 * dt; p.vx *= 0.985; p.vz *= 0.985;
#       p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
#       if (p.y < 0.02) { p.y = 0.02; p.vy = Math.abs(p.vy) * 0.3; }
#       const u = 1 - p.life / p.max, k = w * 6, k4 = w * 8, tl = 0.045;
#       s.pos[k] = p.x; s.pos[k + 1] = p.y; s.pos[k + 2] = p.z; s.pos[k + 3] = p.x - p.vx * tl; s.pos[k + 4] = p.y - p.vy * tl; s.pos[k + 5] = p.z - p.vz * tl;
#       s.col[k4] = p.c[0]; s.col[k4 + 1] = p.c[1]; s.col[k4 + 2] = p.c[2]; s.col[k4 + 3] = u;
#       s.col[k4 + 4] = p.c[0]; s.col[k4 + 5] = p.c[1]; s.col[k4 + 6] = p.c[2]; s.col[k4 + 7] = 0;
#       L[w] = p; w++;
#     }
#     L.length = w;
#     s.geo.setDrawRange(0, w * 2);
#     s.geo.attributes.position.needsUpdate = true; s.geo.attributes.aCol.needsUpdate = true;
#   }
# }
# 
# // ---- debris (instanced chunks with bounce physics) ----
# const DEB_N = 320; const _dm = null;
# function initDebris() {
#   const geo = new THREE.BoxGeometry(1, 1, 1);
#   const mesh = new THREE.InstancedMesh(geo, G3.toon(0xffffff), DEB_N);
#   mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage); mesh.castShadow = true; mesh.frustumCulled = false;
#   mesh.setColorAt(0, new THREE.Color(1, 1, 1));
#   const z = new THREE.Matrix4().makeScale(0, 0, 0); for (let i = 0; i < DEB_N; i++) mesh.setMatrixAt(i, z);
#   scene.add(mesh);
#   debrisSys = { mesh, list: [], dummy: new THREE.Object3D(), col: new THREE.Color() };
# }
# function debris(x, y, z, n, power, hex, size) {
#   const d = debrisSys; if (!d) return;
#   const q = QUALITY[S.quality];
#   n = Math.ceil(n * Math.max(0.4, q.parts));
#   for (let i = 0; i < n && d.list.length < DEB_N; i++) {
#     const a = rand(0, TAU), sp = rand(0.3, 1) * power;
#     d.list.push({
#       x: x + rand(-0.3, 0.3), y: y + rand(0, 0.3), z: z + rand(-0.3, 0.3), vx: Math.cos(a) * sp, vy: rand(0.5, 1.2) * power * 0.9, vz: Math.sin(a) * sp,
#       rx: rand(0, TAU), ry: rand(0, TAU), rz: rand(0, TAU), vrx: rand(-9, 9), vry: rand(-9, 9), vrz: rand(-9, 9),
#       s: (size || 0.2) * rand(0.5, 1.5), life: 0, max: rand(1.6, 3.2), c: hex == null ? 0x3a3a46 : hex
#     });
#   }
# }
# G3.debris = debris;
# function updateDebris(dt) {
#   const d = debrisSys; if (!d) return;
#   const L = d.list; let w = 0;
#   for (let i = 0; i < L.length; i++) {
#     const p = L[i]; p.life += dt;
#     if (p.life >= p.max) continue;
#     p.vy -= 22 * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
#     if (p.y < p.s * 0.5) { p.y = p.s * 0.5; if (Math.abs(p.vy) > 1.2) p.vy = -p.vy * 0.38; else p.vy = 0; p.vx *= 0.78; p.vz *= 0.78; p.vrx *= 0.7; p.vry *= 0.7; p.vrz *= 0.7; }
#     p.rx += p.vrx * dt; p.ry += p.vry * dt; p.rz += p.vrz * dt;
#     L[w++] = p;
#   }
#   L.length = w;
#   for (let i = 0; i < DEB_N; i++) {
#     if (i < w) {
#       const p = L[i], u = p.life / p.max, sc = p.s * (u > 0.75 ? (1 - u) * 4 : 1);
#       d.dummy.position.set(p.x, p.y, p.z); d.dummy.rotation.set(p.rx, p.ry, p.rz); d.dummy.scale.set(sc, sc * 0.8, sc * 1.1); d.dummy.updateMatrix();
#       d.mesh.setMatrixAt(i, d.dummy.matrix); d.col.setHex(p.c); d.mesh.setColorAt(i, d.col);
#     } else { d.dummy.scale.set(0, 0, 0); d.dummy.updateMatrix(); d.mesh.setMatrixAt(i, d.dummy.matrix); }
#   }
#   d.mesh.instanceMatrix.needsUpdate = true; if (d.mesh.instanceColor) d.mesh.instanceColor.needsUpdate = true;
# }
# 
# // ---- ground decals ----
# let crackTex = null, scorchTex = null, glowTex = null;
# function canvasTex(w, draw) {
#   const c = document.createElement('canvas'); c.width = c.height = w; draw(c.getContext('2d'), w);
#   const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
# }
# function initDecals() {
#   crackTex = canvasTex(256, (g, w) => {
#     g.translate(w / 2, w / 2); g.strokeStyle = '#fff'; g.lineCap = 'round';
#     const branch = (x, y, a, len, wd, depth) => {
#       g.lineWidth = wd; g.beginPath(); g.moveTo(x, y);
#       let cx = x, cy = y; const seg = 5;
#       for (let i = 0; i < seg; i++) { a += rand(-0.45, 0.45); cx += Math.cos(a) * len / seg; cy += Math.sin(a) * len / seg; g.lineTo(cx, cy); }
#       g.stroke();
#       if (depth > 0 && len > 14) { branch(cx, cy, a + rand(0.4, 0.9), len * 0.55, wd * 0.6, depth - 1); if (Math.random() < 0.7) branch(cx, cy, a - rand(0.4, 0.9), len * 0.5, wd * 0.6, depth - 1); }
#     };
#     const n = 9; for (let i = 0; i < n; i++) branch(0, 0, (i / n) * TAU + rand(-0.2, 0.2), rand(50, 118), 4.2, 3);
#     const gr = g.createRadialGradient(0, 0, 0, 0, 0, 32); gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.beginPath(); g.arc(0, 0, 32, 0, TAU); g.fill();
#   });
#   scorchTex = canvasTex(128, (g, w) => {
#     const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2); gr.addColorStop(0, 'rgba(0,0,0,0.85)'); gr.addColorStop(0.55, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
#     g.fillStyle = gr; g.fillRect(0, 0, w, w);
#     for (let i = 0; i < 40; i++) { g.fillStyle = 'rgba(0,0,0,' + rand(0.1, 0.4) + ')'; g.beginPath(); g.arc(w / 2 + rand(-w * 0.36, w * 0.36), w / 2 + rand(-w * 0.36, w * 0.36), rand(1, 7), 0, TAU); g.fill(); }
#   });
#   glowTex = canvasTex(128, (g, w) => { const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.4, 'rgba(255,255,255,0.35)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); });
#   const geo = new THREE.PlaneGeometry(1, 1); geo.rotateX(-Math.PI / 2);
#   for (let i = 0; i < 36; i++) {
#     const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: crackTex, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }));
#     m.visible = false; m.renderOrder = 2; m.userData = { life: 0, max: 1, op: 1 }; scene.add(m); decals.push(m);
#   }
# }
# // kind: 'crack' (glowing, additive) | 'scorch' (dark) | 'glow' (soft pool of light)
# function decal(kind, x, z, size, hex, life, op) {
#   let d = decals.find((m) => !m.visible) || decals.reduce((a, b) => (a.userData.life / a.userData.max > b.userData.life / b.userData.max ? a : b));
#   const mat = d.material;
#   mat.map = kind === 'crack' ? crackTex : (kind === 'scorch' ? scorchTex : glowTex);
#   mat.blending = kind === 'scorch' ? THREE.NormalBlending : THREE.AdditiveBlending;
#   mat.color.setHex(kind === 'scorch' ? 0x000000 : hex); mat.needsUpdate = true;
#   d.position.set(x, 0.03 + Math.random() * 0.01, z); d.rotation.y = rand(0, TAU); d.scale.set(size, 1, size);
#   d.visible = true; d.userData.life = 0; d.userData.max = life || 6; d.userData.op = op == null ? 1 : op; d.userData.kind = kind;
#   return d;
# }
# G3.decal = decal;
# function updateDecals(dt) {
#   for (const d of decals) {
#     if (!d.visible) continue;
#     const u = d.userData; u.life += dt;
#     if (u.life >= u.max) { d.visible = false; continue; }
#     const k = u.life / u.max; d.material.opacity = u.op * (k < 0.04 ? k / 0.04 : (k > 0.55 ? 1 - (k - 0.55) / 0.45 : 1)) * (u.kind === 'crack' ? (1 - k * 0.5) : 1);
#   }
# }
# 
# // ---- generic timed effect list ----
# function addFx(dur, update, done) { const f = { t: 0, dur, update, done }; fxList.push(f); return f; }
# function updateFx(dt) {
#   for (let i = fxList.length - 1; i >= 0; i--) {
#     const f = fxList[i]; f.t += dt; const u = clamp(f.t / f.dur, 0, 1);
#     f.update(u, dt, f);
#     if (f.t >= f.dur) { if (f.done) f.done(f); fxList.splice(i, 1); }
#   }
# }
# function disposeObj(o) { scene.remove(o); o.traverse((c) => { if (c.geometry && !c.geometry.userData.keep) c.geometry.dispose(); if (c.material && !c.material.userData.keep) c.material.dispose(); }); }
# 
# // ---- shader materials ----
# function addMat(frag, uniforms, vert, extra) {
#   const m = new THREE.ShaderMaterial(Object.assign({
#     transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
#     uniforms: Object.assign({ uTime: UT }, uniforms),
#     vertexShader: vert || 'varying vec2 vUv; varying vec3 vN; varying vec3 vP; void main(){ vUv = uv; vN = normalize(normalMatrix * normal); vec4 mv = modelViewMatrix * vec4(position, 1.0); vP = mv.xyz; gl_Position = projectionMatrix * mv; }',
#     fragmentShader: 'uniform float uTime;\n' + GLSL_NOISE + '\n' + frag
#   }, extra || {}));
#   m.userData.keep = false; return m;
# }
# const col3 = (h, g) => new THREE.Color().setRGB(...hexRGB(h, g));
# 
# // expanding ring on the ground or facing a normal
# function ring(x, y, z, R, hex, dur, thick, orient, g) {
#   if (!ringGeo) { ringGeo = new THREE.RingGeometry(0.82, 1, 56, 1); ringGeo.userData.keep = true; }
#   const m = new THREE.Mesh(ringGeo, addMat('uniform vec3 uC; uniform float uA; varying vec2 vUv; void main(){ gl_FragColor = vec4(uC, uA); }', { uC: { value: col3(hex, g == null ? 2 : g) }, uA: { value: 1 } }));
#   m.position.set(x, y, z);
#   if (orient) m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), new THREE.Vector3(orient[0], orient[1], orient[2]).normalize()); else m.rotation.x = -Math.PI / 2;
#   m.renderOrder = 4; scene.add(m);
#   addFx(dur, (u) => { const e = easeOut(u), r = Math.max(0.01, R * e); m.scale.set(r, r, r); const th = (thick || 0.35) * (1 - u * 0.8); m.scale.z = 1; m.material.uniforms.uA.value = (1 - u) * (1 - u); m.geometry.userData.keep = true; }, () => { scene.remove(m); m.material.dispose(); });
# }
# G3.ring = ring;
# 
# // glowing shell sphere (red-burst, black-flash dome, domain flash)
# function shell(x, y, z, R, hex, dur, g, noisy) {
#   const geo = new THREE.SphereGeometry(1, 28, 20);
#   const m = new THREE.Mesh(geo, addMat('uniform vec3 uC; uniform float uA, uN; varying vec3 vN; varying vec3 vP; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(-vP))), 1.6); float n = uN > 0.0 ? vnoise(vP * 3.0 + vec3(0, uTime * 6.0, 0)) : 1.0; gl_FragColor = vec4(uC * (0.4 + f * 1.8) * (0.6 + n * 0.8), uA * (0.25 + f)); }', { uC: { value: col3(hex, g == null ? 1.6 : g) }, uA: { value: 1 }, uN: { value: noisy ? 1 : 0 } }));
#   m.position.set(x, y, z); m.renderOrder = 4; scene.add(m);
#   addFx(dur, (u) => { const r = Math.max(0.01, R * easeOut(u)); m.scale.set(r, r, r); m.material.uniforms.uA.value = Math.pow(1 - u, 1.5); }, () => disposeObj(m));
# }
# G3.shell = shell;
# // ---------------------------------------------------------------------
# // Maps. "street" = an abandoned Tokyo crossroads at night.
# // ---------------------------------------------------------------------
# const MAP = { group: null, boxes: [], circles: [], props: [], lamps: [], name: '', arm: 30, half: 9.5 };
# G3.MAP = MAP;
# const seedRand = (() => { let s = 1337; return () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; }; })();
# const sr = (a, b) => a + seedRand() * (b - a);
# 
# function wallTextures(style) {
#   const W = 256, H = 256;
#   const base = document.createElement('canvas'); base.width = W; base.height = H;
#   const em = document.createElement('canvas'); em.width = W; em.height = H;
#   const g = base.getContext('2d'), e = em.getContext('2d');
#   const wallCols = [['#4a4c63', '#3f4157'], ['#58505f', '#4a4353'], ['#3e4a5b', '#344052']][style % 3];
#   g.fillStyle = wallCols[0]; g.fillRect(0, 0, W, H);
#   for (let i = 0; i < 600; i++) { g.fillStyle = 'rgba(0,0,0,' + sr(0.02, 0.1) + ')'; g.fillRect(sr(0, W), sr(0, H), sr(1, 14), sr(1, 3)); }
#   e.fillStyle = '#000'; e.fillRect(0, 0, W, H);
#   const cols = 4, rows = 8, cw = W / cols, rh = H / rows;
#   for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
#     const x = c * cw + 9, y = r * rh + 8, w = cw - 18, h = rh - 18;
#     g.fillStyle = '#0d1020'; g.fillRect(x - 3, y - 3, w + 6, h + 6);
#     const lit = seedRand();
#     if (lit < 0.14) { const warm = seedRand() < 0.7; g.fillStyle = warm ? '#ffd9a0' : '#9fd6ff'; g.fillRect(x, y, w, h); e.fillStyle = warm ? '#d9a050' : '#4a86b8'; e.fillRect(x, y, w, h); g.fillStyle = 'rgba(0,0,0,0.35)'; g.fillRect(x, y + h / 2 - 1, w, 2); }
#     else if (lit < 0.2) { g.fillStyle = '#1b2036'; g.fillRect(x, y, w, h); g.strokeStyle = '#05060c'; g.lineWidth = 2; g.beginPath(); g.moveTo(x, y); g.lineTo(x + w, y + h); g.moveTo(x + w * 0.6, y); g.lineTo(x + w * 0.2, y + h); g.stroke(); }
#     else { g.fillStyle = seedRand() < 0.5 ? '#161b2e' : '#1e2540'; g.fillRect(x, y, w, h); g.fillStyle = 'rgba(160,190,255,0.08)'; g.fillRect(x, y, w * 0.4, h); }
#   }
#   for (let i = 0; i < 5; i++) { g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(sr(0, W), 0, sr(2, 6), H); }
#   const t = (c) => { const x = new THREE.CanvasTexture(c); x.wrapS = x.wrapT = THREE.RepeatWrapping; x.colorSpace = THREE.SRGBColorSpace; x.anisotropy = 4; return x; };
#   return { map: t(base), em: t(em) };
# }
# 
# function groundTexture() {
#   const N = 2048, WORLD = 100, k = N / WORLD;
#   const c = document.createElement('canvas'); c.width = c.height = N; const g = c.getContext('2d');
#   g.fillStyle = '#1b1d28'; g.fillRect(0, 0, N, N);
#   for (let i = 0; i < 9000; i++) { g.fillStyle = 'rgba(' + (seedRand() < 0.5 ? '255,255,255' : '0,0,0') + ',' + sr(0.015, 0.05) + ')'; g.fillRect(sr(0, N), sr(0, N), sr(1, 5), sr(1, 5)); }
#   const X = (x) => (x + WORLD / 2) * k;
#   const H = MAP.half;
#   // sidewalks (corner slabs are drawn lighter, they are raised meshes too)
#   g.fillStyle = '#2c2f3e';
#   for (const sx of [-1, 1]) for (const sz of [-1, 1]) g.fillRect(X(sx > 0 ? 7.5 : -50), X(sz > 0 ? 7.5 : -50), (sx > 0 ? 42.5 : 42.5) * k, 42.5 * k);
#   // lane lines
#   g.fillStyle = '#c9a93a';
#   for (let z = -48; z < 48; z += 3) { if (Math.abs(z) < H + 1) continue; g.fillRect(X(-0.12), X(z), 0.24 * k, 1.6 * k); }
#   for (let x = -48; x < 48; x += 3) { if (Math.abs(x) < H + 1) continue; g.fillRect(X(x), X(-0.12), 1.6 * k, 0.24 * k); }
#   g.fillStyle = '#d8dbe6';
#   for (const s of [-1, 1]) {
#     for (let i = -6; i <= 6; i++) { g.fillRect(X(i * 1.3 - 0.45), X(s * (H + 1.4)) - 1.2 * k, 0.9 * k, 2.4 * k); g.fillRect(X(s * (H + 1.4)) - 1.2 * k, X(i * 1.3 - 0.45), 2.4 * k, 0.9 * k); }
#     g.fillRect(X(-H), X(s * (H + 3.2)), H * 2 * k, 0.3 * k); g.fillRect(X(s * (H + 3.2)), X(-H), 0.3 * k, H * 2 * k);
#   }
#   // wear, puddles, manhole, tyre marks
#   for (let i = 0; i < 22; i++) { const px = sr(-26, 26), pz = sr(-26, 26); if (Math.abs(px) > 9 && Math.abs(pz) > 9) continue; const r = sr(0.8, 2.6) * k; const gr = g.createRadialGradient(X(px), X(pz), 0, X(px), X(pz), r); gr.addColorStop(0, 'rgba(60,80,140,0.45)'); gr.addColorStop(1, 'rgba(60,80,140,0)'); g.fillStyle = gr; g.fillRect(X(px) - r, X(pz) - r, r * 2, r * 2); }
#   g.strokeStyle = 'rgba(0,0,0,0.3)'; g.lineWidth = 0.35 * k; for (let i = 0; i < 6; i++) { g.beginPath(); const x0 = sr(-8, 8); g.moveTo(X(x0), X(-30)); g.bezierCurveTo(X(x0 + sr(-3, 3)), X(-10), X(x0 + sr(-3, 3)), X(10), X(x0 + sr(-2, 2)), X(30)); g.stroke(); }
#   g.strokeStyle = 'rgba(0,0,0,0.55)'; g.lineWidth = 0.12 * k; for (let i = 0; i < 26; i++) { let x = sr(-24, 24), z = sr(-24, 24); if (Math.abs(x) > 9 && Math.abs(z) > 9) continue; g.beginPath(); g.moveTo(X(x), X(z)); for (let j = 0; j < 6; j++) { x += sr(-1.2, 1.2); z += sr(-1.2, 1.2); g.lineTo(X(x), X(z)); } g.stroke(); }
#   g.fillStyle = '#12131b'; g.beginPath(); g.arc(X(0), X(0), 0.8 * k, 0, TAU); g.fill(); g.strokeStyle = '#3a3d4f'; g.lineWidth = 0.1 * k; g.stroke();
#   const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t;
# }
# 
# function boxCollider(x0, x1, z0, z1) { MAP.boxes.push({ x0, x1, z0, z1 }); }
# function mkBuilding(cx, cz, w, d, h, style, tex) {
#   const geo = new THREE.BoxGeometry(w, h, d);
#   const uv = geo.attributes.uv, nr = geo.attributes.normal;
#   for (let i = 0; i < uv.count; i++) {
#     if (Math.abs(nr.getY(i)) > 0.5) { uv.setXY(i, 0.01, 0.01); continue; }
#     const span = Math.abs(nr.getX(i)) > 0.5 ? d : w;
#     uv.setXY(i, uv.getX(i) * span / 6, uv.getY(i) * h / 6);
#   }
#   const mat = G3.toon(0xffffff, { map: tex.map, emissiveMap: tex.em, emissive: 0xffffff, emissiveIntensity: 1.6 });
#   const m = G3.tmesh(geo, 0xffffff, { mat, th: 0.06, recv: true });
#   m.position.set(cx, h / 2, cz);
#   MAP.group.add(m);
#   // roof clutter
#   const nR = 1 + Math.floor(seedRand() * 3);
#   for (let i = 0; i < nR; i++) {
#     const rw = sr(1.2, 2.6), rh = sr(0.8, 1.8), rd = sr(1.2, 2.6);
#     const r = G3.tmesh(new THREE.BoxGeometry(rw, rh, rd), 0x30323f, { th: 0.04 });
#     r.position.set(cx + sr(-w / 2 + 1.5, w / 2 - 1.5), h + rh / 2, cz + sr(-d / 2 + 1.5, d / 2 - 1.5)); MAP.group.add(r);
#   }
#   if (seedRand() < 0.5 && h > 22) {
#     const a = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 5, 5), new THREE.MeshBasicMaterial({ color: 0x20222c })); a.position.set(cx + sr(-w / 3, w / 3), h + 2.5, cz + sr(-d / 3, d / 3)); MAP.group.add(a);
#     const l = new THREE.Mesh(new THREE.SphereGeometry(0.22, 8, 6), new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 0.2, 0.2) })); l.position.set(a.position.x, h + 5, a.position.z); l.userData.blink = seedRand() * 6; MAP.group.add(l); MAP.lamps.push({ mesh: l, kind: 'blink' });
#   }
#   return m;
# }
# 
# function mkCar(x, z, ry, color) {
#   const g = new THREE.Group();
#   const body = G3.tmesh(new THREE.BoxGeometry(1.9, 0.75, 4.3), color); body.position.y = 0.72; g.add(body);
#   const cab = G3.tmesh(new THREE.BoxGeometry(1.7, 0.7, 2.2), color); cab.position.set(0, 1.4, -0.15); g.add(cab);
#   const glass = new THREE.Mesh(new THREE.BoxGeometry(1.74, 0.5, 2.0), new THREE.MeshBasicMaterial({ color: 0x0a0e1c })); glass.position.set(0, 1.42, -0.15); g.add(glass);
#   for (const wx of [-1, 1]) for (const wz of [-1.4, 1.4]) { const w = G3.tmesh(new THREE.CylinderGeometry(0.38, 0.38, 0.3, 12), 0x14141a, { th: 0.02 }); w.rotation.z = Math.PI / 2; w.position.set(wx * 0.95, 0.38, wz); g.add(w); }
#   g.position.set(x, 0, z); g.rotation.y = ry; g.rotation.z = sr(-0.04, 0.04); MAP.group.add(g);
#   const c1 = { x: x + Math.sin(ry) * 1.3, z: z + Math.cos(ry) * 1.3, r: 1.25 }, c2 = { x: x - Math.sin(ry) * 1.3, z: z - Math.cos(ry) * 1.3, r: 1.25 };
#   MAP.circles.push(c1, c2);
#   MAP.props.push({ kind: 'car', mesh: g, x, z, r: 2.3, hp: 70, cols: [c1, c2], color: 0x555a6e, big: true });
# }
# 
# function mkProp(kind, x, z) {
#   let m, r = 0.6, hp = 18, color = 0x6a5a48, col = true;
#   if (kind === 'crate') { m = G3.tmesh(new THREE.BoxGeometry(1.1, 1.1, 1.1), 0x7a5c3a); m.position.y = 0.55; m.rotation.y = sr(0, 3); r = 0.75; color = 0x7a5c3a; }
#   else if (kind === 'barrel') { m = G3.tmesh(new THREE.CylinderGeometry(0.45, 0.45, 1.1, 10), 0x3f6a8c); m.position.y = 0.55; r = 0.55; color = 0x3f6a8c; hp = 14; }
#   else if (kind === 'vending') { m = G3.tmesh(new THREE.BoxGeometry(1.1, 2, 0.9), 0xb8323a); m.position.y = 1; const f = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 1.2), new THREE.MeshBasicMaterial({ color: new THREE.Color(1.2, 1.5, 2.2) })); f.position.set(0, 0.2, 0.46); m.add(f); r = 0.9; hp = 30; color = 0xb8323a; MAP.lamps.push({ mesh: f, kind: 'flick' }); }
#   else if (kind === 'sign') { m = new THREE.Group(); const p = G3.tmesh(new THREE.CylinderGeometry(0.07, 0.07, 3, 6), 0x555a66); p.position.y = 1.5; const s = G3.tmesh(new THREE.BoxGeometry(1.0, 0.7, 0.08), 0x2b6f4a); s.position.y = 2.9; m.add(p, s); r = 0.5; hp = 12; color = 0x2b6f4a; }
#   else if (kind === 'cone') { m = G3.tmesh(new THREE.ConeGeometry(0.28, 0.7, 8), 0xe8651f); m.position.y = 0.35; r = 0.3; hp = 4; color = 0xe8651f; col = false; }
#   else if (kind === 'barrier') { m = G3.tmesh(new THREE.BoxGeometry(2.6, 0.95, 0.55), 0x8a8d99); m.position.y = 0.48; m.rotation.y = sr(-0.3, 0.3); r = 1.3; hp = 40; color = 0x8a8d99; }
#   m.position.x = x; m.position.z = z; MAP.group.add(m);
#   const c = col ? { x, z, r: r * (kind === 'barrier' ? 0.9 : 0.8) } : null; if (c) MAP.circles.push(c);
#   MAP.props.push({ kind, mesh: m, x, z, r: r + 0.4, hp, maxhp: hp, cols: c ? [c] : [], color });
# }
# 
# function mkLamp(x, z, flick) {
#   const g = new THREE.Group();
#   const pole = G3.tmesh(new THREE.CylinderGeometry(0.1, 0.14, 6.2, 8), 0x2a2c38, { th: 0.03 }); pole.position.y = 3.1; g.add(pole);
#   const arm = G3.tmesh(new THREE.BoxGeometry(1.4, 0.1, 0.1), 0x2a2c38, { th: 0.02 }); arm.position.set(x > 0 ? -0.7 : 0.7, 6.1, 0); g.add(arm);
#   const head = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.14, 0.3), new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 2.4, 1.3) })); head.position.set(x > 0 ? -1.3 : 1.3, 6.0, 0); g.add(head);
#   g.position.set(x, 0, z); MAP.group.add(g);
#   const pool = decal('glow', x + (x > 0 ? -1.3 : 1.3), z, 11, 0xffc67a, 9999, 0.5); pool.userData.static = true;
#   MAP.lamps.push({ mesh: head, kind: flick ? 'flick' : 'steady', pool });
#   MAP.circles.push({ x, z, r: 0.3 });
# }
# 
# G3.buildMap = function (name) {
#   if (MAP.group) { scene.remove(MAP.group); }
#   MAP.group = new THREE.Group(); scene.add(MAP.group);
#   MAP.boxes.length = 0; MAP.circles.length = 0; MAP.props.length = 0; MAP.lamps.length = 0; MAP.name = name || 'street';
#   scene.background = new THREE.Color(0x070817); scene.fog = new THREE.FogExp2(0x0b0d22, 0.019);
#   hemi.color.setHex(0x6f7fc8); hemi.groundColor.setHex(0x1a1020); hemi.intensity = 0.95; moon.color.setHex(0x9fb4ff); moon.intensity = 1.5;
#   const H = MAP.half;
#   // ground
#   const gt = groundTexture();
#   const ground = new THREE.Mesh(new THREE.PlaneGeometry(100, 100), new THREE.MeshLambertMaterial({ map: gt }));
#   ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; MAP.group.add(ground);
#   const far = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshBasicMaterial({ color: 0x0b0c14 })); far.rotation.x = -Math.PI / 2; far.position.y = -0.02; MAP.group.add(far);
#   // raised sidewalks in the four corners
#   for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
#     const s = G3.tmesh(new THREE.BoxGeometry(42.5, 0.16, 42.5), 0x3b3e52, { th: 0.02, recv: true });
#     s.position.set(sx * (7.5 + 21.25), 0.08, sz * (7.5 + 21.25)); MAP.group.add(s);
#   }
#   // buildings on a 14-unit grid either side of the roads
#   const tex = [wallTextures(0), wallTextures(1), wallTextures(2)];
#   const cells = [16, 30, 44];
#   for (const sx of [-1, 1]) for (const sz of [-1, 1]) for (const ax of cells) for (const az of cells) {
#     const cx = sx * ax, cz = sz * az, w = sr(10.5, 12.6), d = sr(10.5, 12.6), h = (ax === 16 && az === 16) ? sr(13, 24) : sr(16, 52);
#     mkBuilding(cx, cz, w, d, h, 0, tex[Math.floor(seedRand() * 3)]);
#   }
#   // collision: the four building blocks + barricaded road ends
#   for (const sx of [-1, 1]) for (const sz of [-1, 1]) boxCollider(sx > 0 ? H : -80, sx > 0 ? 80 : -H, sz > 0 ? H : -80, sz > 0 ? 80 : -H);
#   boxCollider(-H, H, MAP.arm, 80); boxCollider(-H, H, -80, -MAP.arm); boxCollider(MAP.arm, 80, -H, H); boxCollider(-80, -MAP.arm, -H, H);
#   // road-end barricades: toppled bus + rubble + barriers
#   const bus = new THREE.Group();
#   const bb = G3.tmesh(new THREE.BoxGeometry(2.6, 3.0, 11), 0x2f5f6b, { th: 0.05 }); bb.position.y = 1.5; bus.add(bb);
#   const bs = new THREE.Mesh(new THREE.BoxGeometry(2.64, 0.9, 9.6), new THREE.MeshBasicMaterial({ color: 0x0a0e1c })); bs.position.y = 2.1; bus.add(bs);
#   bus.position.set(2, 0, MAP.arm + 0.4); bus.rotation.y = Math.PI / 2 + 0.18; bus.rotation.z = 0.12; MAP.group.add(bus);
#   for (const ang of [0, Math.PI / 2, Math.PI, Math.PI * 1.5]) {
#     for (let i = -3; i <= 3; i++) { const px = Math.sin(ang) * (MAP.arm - 0.8) + Math.cos(ang) * i * 2.6, pz = Math.cos(ang) * (MAP.arm - 0.8) - Math.sin(ang) * i * 2.6; if (ang === 0 && Math.abs(i) < 2) continue; mkProp('barrier', px, pz); }
#   }
#   // street lamps at the plaza corners and along the arms
#   const lampSpots = [[8.7, 8.7], [-8.7, 8.7], [8.7, -8.7], [-8.7, -8.7], [8.7, 20], [-8.7, -20], [20, -8.7], [-20, 8.7]];
#   lampSpots.forEach((p, i) => mkLamp(p[0], p[1], i === 2 || i === 5));
#   // wrecked cars
#   const carCols = [0x4b5666, 0x6a3b3b, 0x3d5c4a, 0x5b5b6a, 0x7a6a3a];
#   [[-4.5, 14, 0.2], [5.5, -15, -0.15], [14, 4.5, 1.6], [-16, -5, 1.45], [-5.8, -22, 0.05], [4, 24, 3.0]].forEach((c, i) => mkCar(c[0], c[1], c[2], carCols[i % 5]));
#   // destructible props
#   const rp = [['crate', 3, 6], ['crate', 4.2, 6.6], ['crate', 3.5, 7.4], ['barrel', -6, 5], ['barrel', -6.9, 5.8], ['vending', 8.1, -3], ['vending', -8.1, 3.5], ['sign', 7.4, 7.4], ['sign', -7.4, -7.4], ['barrel', 6, -6.2],
#     ['crate', -3, -7], ['barrel', 2, -12], ['cone', 1, 9], ['cone', 2.2, 9.4], ['cone', -2, 10], ['crate', 12, 5], ['barrel', 18, -4], ['crate', -12, -4.5], ['barrel', -18, 4.5], ['vending', 4, 26], ['crate', -4, 18], ['barrel', -3.5, 19]];
#   rp.forEach((p) => mkProp(p[0], p[1], p[2]));
#   // sky: moon + stars
#   const sky = new THREE.Group();
#   const moonM = new THREE.Mesh(new THREE.CircleGeometry(9, 40), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.4, 2.5, 3), fog: false })); moonM.position.set(-70, 85, -150); moonM.lookAt(0, 0, 0); sky.add(moonM);
#   const halo = new THREE.Mesh(new THREE.CircleGeometry(34, 40), new THREE.MeshBasicMaterial({ map: glowTex, color: 0x5a6aa8, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false })); halo.position.copy(moonM.position).multiplyScalar(0.995); halo.lookAt(0, 0, 0); sky.add(halo);
#   const sg = new THREE.BufferGeometry(), sp = new Float32Array(900 * 3);
#   for (let i = 0; i < 900; i++) { const a = seedRand() * TAU, e = Math.acos(seedRand() * 0.95 + 0.05), R = 320; sp[i * 3] = Math.sin(e) * Math.cos(a) * R; sp[i * 3 + 1] = Math.cos(e) * R; sp[i * 3 + 2] = Math.sin(e) * Math.sin(a) * R; }
#   sg.setAttribute('position', new THREE.BufferAttribute(sp, 3));
#   sky.add(new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xcfd8ff, size: 1.6, sizeAttenuation: false, fog: false, transparent: true, opacity: 0.8 })));
#   MAP.group.add(sky); MAP.sky = sky;
#   G3.mapReady = true;
# };
# 
# // push a circle (x,z,r) out of walls and obstacles; returns {x,z}
# G3.clampPos = function (x, z, r) {
#   for (let pass = 0; pass < 2; pass++) {
#     for (const b of MAP.boxes) {
#       const nx = clamp(x, b.x0, b.x1), nz = clamp(z, b.z0, b.z1); let dx = x - nx, dz = z - nz, d2 = dx * dx + dz * dz;
#       if (d2 < r * r) {
#         if (d2 > 1e-6) { const d = Math.sqrt(d2), k = (r - d) / d; x += dx * k; z += dz * k; }
#         else { const l = x - b.x0, rr = b.x1 - x, t = z - b.z0, bt = b.z1 - z, m = Math.min(l, rr, t, bt); if (m === l) x = b.x0 - r; else if (m === rr) x = b.x1 + r; else if (m === t) z = b.z0 - r; else z = b.z1 + r; }
#       }
#     }
#     for (const c of MAP.circles) { const dx = x - c.x, dz = z - c.z, rr = r + c.r, d2 = dx * dx + dz * dz; if (d2 < rr * rr && d2 > 1e-8) { const d = Math.sqrt(d2), k = (rr - d) / d; x += dx * k; z += dz * k; } }
#   }
#   return { x, z };
# };
# G3.inArena = (x, z) => (Math.abs(x) < MAP.half && Math.abs(z) < MAP.arm) || (Math.abs(z) < MAP.half && Math.abs(x) < MAP.arm);
# 
# // destructibles ---------------------------------------------------------
# function breakProp(p) {
#   const i = MAP.props.indexOf(p); if (i < 0) return; MAP.props.splice(i, 1);
#   for (const c of p.cols) { const k = MAP.circles.indexOf(c); if (k >= 0) MAP.circles.splice(k, 1); }
#   MAP.group.remove(p.mesh);
#   const px = p.mesh.position.x + (p.kind === 'car' ? 0 : 0), pz = p.mesh.position.z;
#   debris(p.x, 0.6, p.z, p.big ? 22 : 10, p.big ? 8 : 5.5, p.color, p.big ? 0.42 : 0.24);
#   for (let i = 0; i < (p.big ? 14 : 6); i++) P({ x: p.x + rand(-0.8, 0.8), y: rand(0.2, 1.2), z: p.z + rand(-0.8, 0.8), vx: rand(-1.5, 1.5), vy: rand(0.4, 2), vz: rand(-1.5, 1.5), life: rand(0.9, 1.6), s0: rand(0.8, 1.6), s1: 3, c0: 0x5a5a66, c1: 0x22222a, g: 1, a0: 0.45, a1: 0, add: false, drag: 1.5 });
#   if (p.kind === 'barrel' || p.kind === 'car') { P({ x: p.x, y: 0.8, z: p.z, life: 0.35, s0: 3, s1: 6, c0: 0xffa040, c1: 0xff4010, g: 2, a0: 0.9, a1: 0 }); sparkBurst(p.x, 0.8, p.z, 14, 9, 0xffb050); G3.pointFlash(p.x, 1.2, p.z, 0xff9040, 3, 0.35); }
#   G3.sfx && G3.sfx('break');
#   if (G3.onBreak) G3.onBreak(p.kind);
# }
# G3.hitProps = function (x, z, r, dmg) {
#   let n = 0;
#   for (const p of MAP.props.slice()) { const dx = p.x - x, dz = p.z - z; if (dx * dx + dz * dz < (r + p.r) * (r + p.r)) { p.hp -= dmg; n++; if (p.mesh.position) { p.mesh.rotation.z = (p.mesh.rotation.z || 0) + rand(-0.06, 0.06); } if (p.hp <= 0) breakProp(p); } }
#   return n;
# };
# G3.propsInLine = function (x1, z1, x2, z2, w, dmg) {
#   const dx = x2 - x1, dz = z2 - z1, L = Math.hypot(dx, dz) || 1;
#   for (const p of MAP.props.slice()) {
#     const t = clamp(((p.x - x1) * dx + (p.z - z1) * dz) / (L * L), 0, 1), cx = x1 + dx * t, cz = z1 + dz * t;
#     if (Math.hypot(p.x - cx, p.z - cz) < w + p.r) { p.hp -= dmg; if (p.hp <= 0) breakProp(p); }
#   }
# };
# 
# function updateMap(dt) {
#   if (!MAP.group) return;
#   for (const l of MAP.lamps) {
#     if (l.kind === 'blink') { l.mesh.visible = Math.sin(S.t * 2.2 + l.mesh.userData.blink) > 0.6; }
#     else if (l.kind === 'flick') { const f = Math.sin(S.t * 31) * Math.sin(S.t * 7.3) > 0.55 ? 0.15 : 1; l.mesh.material.color.setRGB(3.2 * f, 2.4 * f, 1.3 * f); if (l.pool) l.pool.userData.op = 0.5 * f; if (l.mesh.parent && l.mesh.material.color.r < 0.6 && !l.pool) l.mesh.material.color.setRGB(1.2 * f + 0.1, 1.5 * f + 0.1, 2.2 * f + 0.1); }
#   }
# }
# // ---------------------------------------------------------------------
# // Character rigs + animation (procedural cel-shaded humanoids)
# // Characters face +Z. Arm/leg "forward" = negative X rotation; knee/elbow bend: knee +X, elbow -X.
# // ---------------------------------------------------------------------
# const D2R = Math.PI / 180;
# const JN = ['hips', 'torso', 'head', 'shL', 'elL', 'shR', 'elR', 'hpL', 'knL', 'hpR', 'knR'];
# const LOOKS = {
#   haru: { skin: 0xf1d2b5, hair: 0xb9e3ff, hairStyle: 'spiky', jacket: 0x1c2548, trim: 0x6fb4ff, pants: 0x141a30, shoes: 0xdde6ff, eye: 0x7fe6ff, goggles: true, aura: 'haru' },
#   kage: { skin: 0xe9c8b6, hair: 0x15101e, hairStyle: 'long', jacket: 0x1a1424, trim: 0x9a5cff, pants: 0x0e0a16, shoes: 0x241a34, eye: 0xc08cff, hood: true, scarf: 0x40205f, aura: 'kage' },
#   akai: { skin: 0xe9b999, hair: 0x7c1022, hairStyle: 'spiky2', jacket: 0x2d0d14, trim: 0xff3a4a, pants: 0x1a1217, shoes: 0x120a0c, eye: 0xff5a50, bandages: true, aura: 'akai' },
#   grunt: { skin: 0x7b6a98, scale: 0.98, mask: 0xe9e4d8, eye: 0xff3040, jacket: 0x2a2236, pants: 0x1e1a28, shoes: 0x16121e, longArms: 1.12, hunch: 1, aura: null },
#   fang: { skin: 0x5d7a6a, scale: 1.02, mask: 0xd8e6dc, eye: 0xffa020, jacket: 0x1f2e2a, pants: 0x18221f, shoes: 0x101815, longArms: 1.08, hunch: 1, aura: null },
#   caster: { skin: 0x4a3a78, scale: 1.0, mask: 0xcfc8e8, eye: 0xd060ff, jacket: 0x241a46, pants: 0x241a46, shoes: 0x241a46, robe: true, hood: true, aura: null },
#   boss: { skin: 0x3c2c58, scale: 2.1, mask: 0xd9d0c4, eye: 0xff2a3a, jacket: 0x160f26, pants: 0x120c1e, shoes: 0x0c0814, horns: true, extraArms: true, veins: 0xb040ff, longArms: 1.1, hunch: 1, aura: null }
# };
# G3.LOOKS = LOOKS;
# 
# function newPose() { const p = { hy: 0, fwd: 0, lean: 0, lat: 0, lie: 0, spin: 0 }; for (const j of JN) p[j] = [0, 0, 0]; return p; }
# const STANCE = {
#   hy: -0.07, fwd: 0, lean: 0, lat: 0, lie: 0, spin: 0,
#   hips: [0, 6, 0], torso: [6, -8, 0], head: [-4, 4, 0], shL: [-52, 0, 14], elL: [-105, 0, 0], shR: [-46, 0, -14], elR: [-108, 0, 0],
#   hpL: [-12, 0, 4], knL: [22, 0, 0], hpR: [14, 0, -4], knR: [28, 0, 0]
# };
# const K = (t, o) => Object.assign({ t }, o);
# const ANIMS = {
#   idle: [K(0, {})],
#   light1: [K(0, {}), K(0.22, { torso: [8, -34, 0], hips: [0, -12, 0], shR: [-30, 0, -20], elR: [-150, 0, 0], hy: -0.1, fwd: -0.06 }),
#     K(0.42, { torso: [10, 40, 0], hips: [0, 18, 0], shR: [-92, 0, -6], elR: [-3, 0, 0], shL: [-60, 0, 18], elL: [-125, 0, 0], hpL: [-40, 0, 4], knL: [38, 0, 0], hpR: [24, 0, -4], knR: [12, 0, 0], hy: -0.14, fwd: 0.26, head: [-2, -8, 0] }),
#     K(0.62, { torso: [10, 34, 0], hips: [0, 14, 0], shR: [-90, 0, -6], elR: [-8, 0, 0], hpL: [-38, 0, 4], knL: [36, 0, 0], hy: -0.14, fwd: 0.24 }), K(1, {})],
#   light2: [K(0, {}), K(0.22, { torso: [8, 34, 0], hips: [0, 14, 0], shL: [-30, 0, 20], elL: [-150, 0, 0], shR: [-60, 0, -16], elR: [-125, 0, 0], hy: -0.1, fwd: -0.06 }),
#     K(0.42, { torso: [10, -42, 0], hips: [0, -18, 0], shL: [-92, 0, 6], elL: [-3, 0, 0], shR: [-60, 0, -18], elR: [-125, 0, 0], hpR: [-38, 0, -4], knR: [36, 0, 0], hpL: [18, 0, 4], knL: [12, 0, 0], hy: -0.14, fwd: 0.26 }),
#     K(0.62, { torso: [10, -36, 0], hips: [0, -14, 0], shL: [-90, 0, 6], elL: [-8, 0, 0], hpR: [-36, 0, -4], knR: [34, 0, 0], hy: -0.14, fwd: 0.24 }), K(1, {})],
#   light3: [K(0, {}), K(0.24, { torso: [6, -48, 0], hips: [0, -22, 0], shR: [-80, -75, -55], elR: [-100, 0, 0], hy: -0.12, fwd: -0.08 }),
#     K(0.44, { torso: [8, 52, 0], hips: [0, 26, 0], shR: [-86, 62, -30], elR: [-75, 0, 0], hpL: [-30, 0, 6], knL: [30, 0, 0], hpR: [20, 0, -6], hy: -0.16, fwd: 0.22, lat: 0.06 }),
#     K(0.66, { torso: [8, 46, 0], hips: [0, 22, 0], shR: [-86, 56, -30], elR: [-80, 0, 0], hy: -0.16, fwd: 0.2 }), K(1, {})],
#   light4: [K(0, {}), K(0.26, { torso: [-14, -22, 0], hpR: [-20, 0, -10], knR: [95, 0, 0], hy: -0.16, shL: [-70, 0, 30], elL: [-80, 0, 0], shR: [-30, 0, -40], elR: [-90, 0, 0], lean: -6, hpL: [-6, 0, 4], knL: [34, 0, 0] }),
#     K(0.46, { torso: [-22, 36, 0], hips: [0, 28, 0], hpR: [-96, 22, -14], knR: [6, 0, 0], hy: -0.12, shL: [-40, 0, 50], elL: [-50, 0, 0], shR: [-30, 0, -60], elR: [-70, 0, 0], lean: -10, fwd: 0.16, hpL: [8, 0, 4], knL: [30, 0, 0] }),
#     K(0.7, { torso: [-18, 30, 0], hips: [0, 22, 0], hpR: [-80, 14, -10], knR: [40, 0, 0], hy: -0.12, shL: [-40, 0, 50], shR: [-30, 0, -60], elR: [-70, 0, 0], lean: -8, fwd: 0.12 }), K(1, {})],
#   light5: [K(0, {}), K(0.28, { torso: [22, -30, 0], hips: [0, -14, 0], hy: -0.34, shR: [-12, 0, -22], elR: [-110, 0, 0], shL: [-60, 0, 18], elL: [-110, 0, 0], hpL: [-30, 0, 6], knL: [70, 0, 0], hpR: [30, 0, -6], knR: [50, 0, 0], fwd: 0.04 }),
#     K(0.5, { torso: [-18, 30, 0], hips: [0, 14, 0], hy: 0.18, shR: [-165, 0, -10], elR: [-8, 0, 0], shL: [-50, 0, 20], elL: [-115, 0, 0], hpL: [-52, 0, 6], knL: [64, 0, 0], hpR: [-8, 0, -6], knR: [38, 0, 0], fwd: 0.3, head: [-14, 0, 0], lean: -6 }),
#     K(0.72, { torso: [-14, 24, 0], hy: 0.12, shR: [-160, 0, -10], elR: [-12, 0, 0], hpL: [-48, 0, 6], knL: [60, 0, 0], fwd: 0.26, lean: -4 }), K(1, {})],
#   heavy: [K(0, {}), K(0.34, { torso: [-26, 0, 0], hy: -0.12, shL: [-168, 0, 16], elL: [-14, 0, 0], shR: [-168, 0, -16], elR: [-14, 0, 0], hpL: [-10, 0, 8], knL: [30, 0, 0], hpR: [14, 0, -8], knR: [40, 0, 0], head: [-14, 0, 0], fwd: -0.1 }),
#     K(0.52, { torso: [42, 0, 0], hy: -0.26, shL: [-70, 0, 12], elL: [-8, 0, 0], shR: [-70, 0, -12], elR: [-8, 0, 0], hpL: [-44, 0, 8], knL: [58, 0, 0], hpR: [20, 0, -8], knR: [50, 0, 0], head: [20, 0, 0], fwd: 0.38, lean: 6 }),
#     K(0.78, { torso: [38, 0, 0], hy: -0.26, shL: [-68, 0, 12], shR: [-68, 0, -12], fwd: 0.36, lean: 6, hpL: [-44, 0, 8], knL: [58, 0, 0] }), K(1, {})],
#   air1: [K(0, { hy: 0.1, hpL: [-36, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] }),
#     K(0.3, { torso: [10, -36, 0], shR: [-30, 0, -20], elR: [-150, 0, 0], hy: 0.1, hpL: [-36, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] }),
#     K(0.5, { torso: [12, 42, 0], shR: [-92, 0, -6], elR: [-3, 0, 0], hy: 0.1, fwd: 0.22, hpL: [-36, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0], shL: [-60, 0, 18], elL: [-125, 0, 0] }), K(1, { hy: 0.1, hpL: [-36, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] })],
#   air2: [K(0, { hy: 0.1, hpL: [-30, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] }),
#     K(0.3, { torso: [-10, 34, 0], hpR: [-30, 0, -10], knR: [100, 0, 0], hy: 0.1, hpL: [-20, 0, 6], knL: [60, 0, 0] }),
#     K(0.52, { torso: [-24, -40, 0], hpR: [-100, -20, -14], knR: [6, 0, 0], hy: 0.12, hpL: [-20, 0, 6], knL: [60, 0, 0], fwd: 0.18, shL: [-40, 0, 50], shR: [-30, 0, -60] }), K(1, { hy: 0.1, hpL: [-30, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] })],
#   airslam: [K(0, { hy: 0.12, hpL: [-30, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] }),
#     K(0.4, { torso: [-24, 0, 0], shL: [-170, 0, 14], elL: [-12, 0, 0], shR: [-170, 0, -14], elR: [-12, 0, 0], hy: 0.12, head: [-14, 0, 0], hpL: [-30, 0, 6], knL: [70, 0, 0], hpR: [-10, 0, -6], knR: [80, 0, 0] }),
#     K(0.62, { torso: [50, 0, 0], shL: [-80, 0, 10], elL: [-6, 0, 0], shR: [-80, 0, -10], elR: [-6, 0, 0], hy: 0.05, lean: 30, hpL: [-30, 0, 6], knL: [50, 0, 0], hpR: [10, 0, -6], knR: [40, 0, 0], head: [20, 0, 0] }), K(1, { torso: [40, 0, 0], lean: 22, shL: [-80, 0, 10], shR: [-80, 0, -10] })],
#   block: [K(0, {}), K(0.25, { torso: [14, 0, 0], hy: -0.12, shL: [-112, -34, 40], elL: [-135, 0, 0], shR: [-112, 34, -40], elR: [-135, 0, 0], hpL: [-16, 0, 6], knL: [38, 0, 0], hpR: [18, 0, -6], knR: [42, 0, 0], head: [10, 0, 0] }), K(1, { torso: [14, 0, 0], hy: -0.12, shL: [-112, -34, 40], elL: [-135, 0, 0], shR: [-112, 34, -40], elR: [-135, 0, 0], hpL: [-16, 0, 6], knL: [38, 0, 0], hpR: [18, 0, -6], knR: [42, 0, 0], head: [10, 0, 0] })],
#   counter: [K(0, { torso: [14, 0, 0], hy: -0.12, shL: [-112, -34, 40], elL: [-135, 0, 0], shR: [-112, 34, -40], elR: [-135, 0, 0] }),
#     K(0.3, { torso: [-6, -42, 0], hy: -0.14, shR: [-40, 0, -22], elR: [-150, 0, 0], shL: [-60, 0, 18], elL: [-120, 0, 0] }),
#     K(0.5, { torso: [12, 48, 0], hips: [0, 22, 0], shR: [-94, 0, -6], elR: [-2, 0, 0], hpL: [-44, 0, 4], knL: [40, 0, 0], hy: -0.16, fwd: 0.3, lean: 4 }), K(1, {})],
#   hit: [K(0, { torso: [-22, 8, 0], head: [-22, 0, 0], hy: -0.05, shL: [-20, 0, 30], elL: [-40, 0, 0], shR: [-20, 0, -30], elR: [-40, 0, 0], fwd: -0.22, lean: -8 }), K(0.5, { torso: [-10, 4, 0], head: [-10, 0, 0], fwd: -0.1, lean: -4 }), K(1, {})],
#   stun: [K(0, { torso: [16, 0, 8], head: [24, 0, 12], hy: -0.08, shL: [-8, 0, 16], elL: [-20, 0, 0], shR: [-8, 0, -16], elR: [-20, 0, 0], knL: [20, 0, 0], knR: [20, 0, 0] })],
#   down: [K(0, { lie: 1, hy: 0, torso: [0, 0, 0], head: [-8, 0, 0], shL: [-10, 0, 40], elL: [-20, 0, 0], shR: [-10, 0, -40], elR: [-20, 0, 0], hpL: [-12, 0, 6], knL: [18, 0, 0], hpR: [6, 0, -6], knR: [22, 0, 0] })],
#   getup: [K(0, { lie: 1 }), K(0.5, { lie: 0.35, hy: -0.45, torso: [24, 0, 0], shL: [-60, 0, 20], shR: [-60, 0, -20], hpL: [-60, 0, 6], knL: [90, 0, 0], hpR: [-20, 0, -6], knR: [100, 0, 0] }), K(1, {})],
#   cast: [K(0, {}), K(0.3, { torso: [4, 0, 0], shL: [-94, -10, 8], elL: [-4, 0, 0], shR: [-94, 10, -8], elR: [-4, 0, 0], hy: -0.1, hpL: [-24, 0, 6], knL: [30, 0, 0], hpR: [18, 0, -6], knR: [34, 0, 0], fwd: 0.05 }), K(1, { torso: [4, 0, 0], shL: [-94, -10, 8], elL: [-4, 0, 0], shR: [-94, 10, -8], elR: [-4, 0, 0], hy: -0.1, hpL: [-24, 0, 6], knL: [30, 0, 0], hpR: [18, 0, -6], knR: [34, 0, 0], fwd: 0.05 })],
#   charge: [K(0, {}), K(0.35, { torso: [-10, 0, 0], shL: [-165, 0, 22], elL: [-16, 0, 0], shR: [-165, 0, -22], elR: [-16, 0, 0], head: [-16, 0, 0], hy: -0.08 }), K(1, { torso: [-12, 0, 0], shL: [-168, 0, 26], elL: [-12, 0, 0], shR: [-168, 0, -26], elR: [-12, 0, 0], head: [-18, 0, 0], hy: -0.08 })],
#   release: [K(0, { torso: [-12, 0, 0], shL: [-168, 0, 26], shR: [-168, 0, -26], head: [-18, 0, 0] }), K(0.25, { torso: [20, 0, 0], shL: [-92, 0, 6], elL: [-2, 0, 0], shR: [-92, 0, -6], elR: [-2, 0, 0], hy: -0.18, fwd: 0.22, head: [8, 0, 0], hpL: [-36, 0, 6], knL: [36, 0, 0], hpR: [20, 0, -6], knR: [34, 0, 0] }), K(1, { torso: [18, 0, 0], shL: [-92, 0, 6], elL: [-2, 0, 0], shR: [-92, 0, -6], elR: [-2, 0, 0], hy: -0.18, fwd: 0.2, hpL: [-36, 0, 6], knL: [36, 0, 0], hpR: [20, 0, -6], knR: [34, 0, 0] })],
#   ult: [K(0, {}), K(0.4, { torso: [-18, 0, 0], head: [-26, 0, 0], shL: [-20, 0, 78], elL: [-12, 0, 0], shR: [-20, 0, -78], elR: [-12, 0, 0], hy: 0.04, hpL: [-8, 0, 10], knL: [14, 0, 0], hpR: [8, 0, -10], knR: [14, 0, 0] }), K(1, { torso: [-20, 0, 0], head: [-28, 0, 0], shL: [-20, 0, 82], elL: [-12, 0, 0], shR: [-20, 0, -82], elR: [-12, 0, 0], hy: 0.06, hpL: [-8, 0, 10], knL: [14, 0, 0], hpR: [8, 0, -10], knR: [14, 0, 0] })],
#   domain: [K(0, {}), K(0.4, { torso: [6, 0, 0], head: [10, 0, 0], shL: [-78, -38, 6], elL: [-108, 0, 0], shR: [-78, 38, -6], elR: [-108, 0, 0], hy: -0.05 }), K(1, { torso: [6, 0, 0], head: [12, 0, 0], shL: [-78, -38, 6], elL: [-108, 0, 0], shR: [-78, 38, -6], elR: [-108, 0, 0], hy: -0.05 })],
#   teleport: [K(0, {}), K(0.5, { hy: -0.4, torso: [28, 0, 0], shL: [-24, 0, 24], elL: [-30, 0, 0], shR: [-24, 0, -24], elR: [-30, 0, 0], hpL: [-60, 0, 6], knL: [100, 0, 0], hpR: [-20, 0, -6], knR: [110, 0, 0] }), K(1, { hy: -0.4, torso: [28, 0, 0], hpL: [-60, 0, 6], knL: [100, 0, 0], hpR: [-20, 0, -6], knR: [110, 0, 0] })],
#   summon: [K(0, {}), K(0.4, { torso: [14, 0, 0], head: [14, 0, 0], shL: [-30, 0, 30], elL: [-40, 0, 0], shR: [-30, 0, -30], elR: [-40, 0, 0], hy: -0.2, hpL: [-30, 0, 8], knL: [50, 0, 0], hpR: [10, 0, -8], knR: [50, 0, 0] }),
#     K(0.75, { torso: [-14, 0, 0], head: [-20, 0, 0], shL: [-130, 0, 40], elL: [-20, 0, 0], shR: [-130, 0, -40], elR: [-20, 0, 0], hy: 0.02 }), K(1, { torso: [-14, 0, 0], head: [-20, 0, 0], shL: [-130, 0, 40], shR: [-130, 0, -40], hy: 0.02 })],
#   swipe: [K(0, {}), K(0.3, { torso: [6, -36, 0], shR: [-60, -60, -70], elR: [-40, 0, 0], hy: -0.12, fwd: -0.06 }), K(0.5, { torso: [8, 44, 0], shR: [-86, 60, -30], elR: [-10, 0, 0], hy: -0.14, fwd: 0.26 }), K(1, {})],
#   victory: [K(0, {}), K(0.5, { shR: [-170, 0, -20], elR: [-10, 0, 0], torso: [-6, 0, 0], head: [-12, 0, 0] }), K(1, { shR: [-170, 0, -20], elR: [-10, 0, 0], torso: [-6, 0, 0], head: [-12, 0, 0] })],
#   jump: [K(0, { hy: 0.06, shL: [-40, 0, 40], shR: [-40, 0, -40], elL: [-30, 0, 0], elR: [-30, 0, 0], hpL: [-40, 0, 4], knL: [60, 0, 0], hpR: [-10, 0, -4], knR: [70, 0, 0], torso: [4, 0, 0] })],
#   fall: [K(0, { hy: 0.0, shL: [-20, 0, 70], shR: [-20, 0, -70], elL: [-20, 0, 0], elR: [-20, 0, 0], hpL: [-30, 0, 8], knL: [40, 0, 0], hpR: [-6, 0, -8], knR: [50, 0, 0], torso: [8, 0, 0] })]
# };
# // keyframes -> radians + defaults filled from STANCE, with carry-forward
# for (const name in ANIMS) {
#   const frames = ANIMS[name];
#   for (const f of frames) {
#     for (const k in f) if (Array.isArray(f[k])) f[k] = f[k].map((v) => v * D2R);
#     for (const k in STANCE) if (f[k] === undefined) f[k] = Array.isArray(STANCE[k]) ? STANCE[k].map((v) => v * D2R) : STANCE[k];
#   }
# }
# const IDLE_POSE = (() => { const p = newPose(); for (const k in STANCE) p[k] = Array.isArray(STANCE[k]) ? STANCE[k].map((v) => v * D2R) : STANCE[k]; return p; })();
# 
# function sampleAnim(name, u, out) {
#   const fr = ANIMS[name] || ANIMS.idle;
#   let a = fr[0], b = fr[fr.length - 1];
#   for (let i = 0; i < fr.length - 1; i++) if (u >= fr[i].t && u <= fr[i + 1].t) { a = fr[i]; b = fr[i + 1]; break; }
#   const k = b.t === a.t ? 1 : ease(clamp((u - a.t) / (b.t - a.t), 0, 1));
#   for (const key of Object.keys(STANCE)) {
#     const av = a[key], bv = b[key];
#     if (Array.isArray(av)) { out[key][0] = lerp(av[0], bv[0], k); out[key][1] = lerp(av[1], bv[1], k); out[key][2] = lerp(av[2], bv[2], k); }
#     else out[key] = lerp(av, bv, k);
#   }
# }
# 
# // ---- builders ----
# const RIGS = new Map(); let rigId = 1;
# function capsule(r, len) { return new THREE.CapsuleGeometry(r, len, 4, 10); }
# function buildHumanoid(look) {
#   const L = look, s = L.scale || 1, arm = L.longArms || 1;
#   const root = new THREE.Group(), body = new THREE.Group(); root.add(body); body.scale.setScalar(s);
#   const mats = [];
#   const M = (c, o) => { const m = G3.toon(c, Object.assign({ emissive: 0x000000 }, o || {})); mats.push(m); return m; };
#   const part = (geo, mat, th) => G3.tmesh(geo, 0, { mat, th: th || 0.022 });
#   const skin = M(L.skin), jacket = M(L.jacket), trim = M(L.trim || L.jacket), pants = M(L.pants), shoes = M(L.shoes);
#   const J = {};
#   J.hips = new THREE.Group(); J.hips.position.y = 0.96; body.add(J.hips);
#   const pelvis = part(capsule(0.19, 0.12), pants); pelvis.rotation.z = Math.PI / 2; pelvis.scale.set(1, 1, 0.8); J.hips.add(pelvis);
#   J.torso = new THREE.Group(); J.torso.position.y = 0.06; J.hips.add(J.torso);
#   const chest = part(capsule(0.2, 0.34), jacket, 0.026); chest.position.y = 0.3; chest.scale.set(1.12, 1, 0.82); J.torso.add(chest);
#   if (L.trim) { const belt = part(new THREE.CylinderGeometry(0.205, 0.2, 0.06, 12), trim, 0.015); belt.position.y = 0.05; belt.scale.set(1.12, 1, 0.82); J.torso.add(belt); }
#   if (L.robe) { const robe = part(new THREE.ConeGeometry(0.5, 1.2, 10, 1, true), jacket, 0.03); robe.position.set(0, -0.35, 0); robe.material.side = THREE.DoubleSide; J.hips.add(robe); }
#   J.head = new THREE.Group(); J.head.position.y = 0.66; J.torso.add(J.head);
#   const hs = L.mask ? 1.15 : 1;
#   const head = part(new THREE.SphereGeometry(0.19 * hs, 16, 12), skin, 0.02); head.position.y = 0.17 * hs; head.scale.set(1, 1.04, 1); J.head.add(head);
#   const eyeMat = new THREE.MeshBasicMaterial({ color: new THREE.Color().setRGB(...hexRGB(L.eye || 0xffffff, 2.2)) });
#   for (const ex of [-1, 1]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.06, L.mask ? 0.02 : 0.035, 0.02), eyeMat); e.position.set(ex * 0.075 * hs, 0.19 * hs, 0.17 * hs); if (L.mask) e.rotation.z = -ex * 0.4; J.head.add(e); }
#   if (L.mask) { const mk = part(new THREE.SphereGeometry(0.2 * hs, 14, 10, 0, TAU, 0, Math.PI * 0.62), M(L.mask), 0.018); mk.position.y = 0.17 * hs; mk.rotation.x = 0.2; J.head.add(mk); }
#   const hairM = M(L.hair || 0x222222);
#   if (L.hairStyle === 'spiky' || L.hairStyle === 'spiky2') {
#     const n = L.hairStyle === 'spiky' ? 11 : 9;
#     for (let i = 0; i < n; i++) { const a = (i / n) * TAU, tilt = 0.55 + (i % 3) * 0.2; const c = part(new THREE.ConeGeometry(0.075, L.hairStyle === 'spiky' ? 0.26 : 0.32, 5), hairM, 0.014); c.position.set(Math.sin(a) * 0.12, 0.3 + (i % 2) * 0.02, Math.cos(a) * 0.1 - 0.02); c.rotation.set(Math.cos(a) * tilt, 0, -Math.sin(a) * tilt); J.head.add(c); }
#     const cap = part(new THREE.SphereGeometry(0.2, 14, 10, 0, TAU, 0, Math.PI * 0.5), hairM, 0.016); cap.position.y = 0.19; J.head.add(cap);
#     if (L.goggles) { const gb = new THREE.Mesh(new THREE.TorusGeometry(0.19, 0.022, 6, 18, Math.PI * 1.2), new THREE.MeshBasicMaterial({ color: 0x0b1020 })); gb.position.set(0, 0.25, 0); gb.rotation.set(Math.PI / 2, 0, Math.PI * 0.4); J.head.add(gb); const gl = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.07, 0.04), new THREE.MeshBasicMaterial({ color: new THREE.Color().setRGB(...hexRGB(L.trim, 1.8)) })); gl.position.set(0, 0.31, 0.17); J.head.add(gl); }
#   } else if (L.hairStyle === 'long') {
#     const cap = part(new THREE.SphereGeometry(0.205, 14, 10, 0, TAU, 0, Math.PI * 0.55), hairM, 0.016); cap.position.y = 0.19; cap.rotation.x = -0.15; J.head.add(cap);
#     const back = part(capsule(0.12, 0.34), hairM, 0.016); back.position.set(0, 0.0, -0.13); back.scale.set(1.3, 1, 0.8); J.head.add(back);
#     for (const sx of [-1, 1]) { const lock = part(capsule(0.04, 0.22), hairM, 0.012); lock.position.set(sx * 0.17, 0.1, 0.1); J.head.add(lock); }
#   }
#   if (L.hood) { const hd = part(new THREE.SphereGeometry(0.255, 14, 10, 0, TAU, 0, Math.PI * 0.72), jacket, 0.02); hd.position.set(0, 0.14, -0.03); hd.rotation.x = -0.35; J.head.add(hd); }
#   if (L.scarf) { const sc = part(new THREE.TorusGeometry(0.19, 0.07, 6, 14), M(L.scarf), 0.015); sc.rotation.x = Math.PI / 2; sc.position.y = 0.58; J.torso.add(sc); const tail = part(capsule(0.05, 0.4), M(L.scarf), 0.012); tail.position.set(-0.1, 0.38, -0.2); tail.rotation.x = 0.25; J.torso.add(tail); J.scarfTail = tail; }
#   if (L.horns) { for (const hx of [-1, 1]) { const h = part(new THREE.ConeGeometry(0.09, 0.5, 6), M(0xe8e0d0), 0.02); h.position.set(hx * 0.16, 0.38, 0.0); h.rotation.set(-0.3, 0, -hx * 0.7); J.head.add(h); } }
#   // arms
#   const mkArm = (sx) => {
#     const sh = new THREE.Group(); sh.position.set(sx * 0.3, 0.52, 0); J.torso.add(sh);
#     const upper = part(capsule(0.065, 0.24 * arm), L.bandages || L.mask ? skin : jacket, 0.02); upper.position.y = -0.18 * arm; sh.add(upper);
#     const el = new THREE.Group(); el.position.y = -0.36 * arm; sh.add(el);
#     const fore = part(capsule(0.06, 0.24 * arm), L.bandages ? M(0xd8d0c8) : skin, 0.02); fore.position.y = -0.17 * arm; el.add(fore);
#     const fist = part(new THREE.SphereGeometry(0.085, 10, 8), L.bandages ? M(0xd8d0c8) : (L.mask ? M(L.skin) : skin), 0.02); fist.position.y = -0.37 * arm; el.add(fist);
#     if (L.veins) { const gl = new THREE.Mesh(new THREE.SphereGeometry(0.1, 8, 6), new THREE.MeshBasicMaterial({ color: new THREE.Color().setRGB(...hexRGB(L.veins, 1.4)) })); gl.position.y = -0.37 * arm; el.add(gl); }
#     return { sh, el, fist };
#   };
#   const aL = mkArm(1), aR = mkArm(-1); J.shL = aL.sh; J.elL = aL.el; J.shR = aR.sh; J.elR = aR.el;
#   if (L.extraArms) for (const sx of [-1, 1]) { const ex = new THREE.Group(); ex.position.set(sx * 0.26, 0.36, 0); J.torso.add(ex); const u = part(capsule(0.06, 0.34), skin, 0.02); u.position.y = -0.22; ex.add(u); const f = part(capsule(0.055, 0.3), skin, 0.02); f.position.set(0, -0.5, 0.06); ex.add(f); ex.rotation.set(-0.7, 0, sx * 0.5); }
#   // legs
#   const mkLeg = (sx) => {
#     const hp = new THREE.Group(); hp.position.set(sx * 0.13, -0.02, 0); J.hips.add(hp);
#     const th = part(capsule(0.085, 0.3), pants, 0.022); th.position.y = -0.23; hp.add(th);
#     const kn = new THREE.Group(); kn.position.y = -0.46; hp.add(kn);
#     const sn = part(capsule(0.07, 0.3), pants, 0.022); sn.position.y = -0.23; kn.add(sn);
#     const ft = part(new THREE.BoxGeometry(0.14, 0.09, 0.28), shoes, 0.02); ft.position.set(0, -0.46, 0.05); kn.add(ft);
#     return { hp, kn, ft };
#   };
#   const lL = mkLeg(1), lR = mkLeg(-1); J.hpL = lL.hp; J.knL = lL.kn; J.hpR = lR.hp; J.knR = lR.kn;
#   if (L.robe) { lL.hp.visible = lR.hp.visible = false; }
#   if (L.horns || L.hunch) J.hunch = true;
#   body.traverse((o) => { if (o.isMesh) o.castShadow = true; });
#   const rig = { id: 0, root, body, J, mats, look: L, kind: 'human', cur: newPose(), tar: newPose(), anim: { name: 'idle', t: 0, dur: 1, loop: true }, runPh: 0, runSpd: 0, flash: 0, trailL: null, trailR: null, fistL: aL.fist, fistR: aR.fist, footL: lL.ft, footR: lR.ft, headM: head, chestM: chest, s, vis: true, extra: {} };
#   for (const k in IDLE_POSE) rig.cur[k] = Array.isArray(IDLE_POSE[k]) ? IDLE_POSE[k].slice() : IDLE_POSE[k];
#   return rig;
# }
# 
# function buildBeast() {
#   const root = new THREE.Group(), body = new THREE.Group(); root.add(body);
#   const mats = []; const M = (c) => { const m = G3.toon(c, { emissive: 0x000000 }); mats.push(m); return m; };
#   const dark = M(0x1a1226), purple = M(0x3a2160);
#   const J = {}; const part = (g, m, th) => G3.tmesh(g, 0, { mat: m, th: th || 0.03, oc: 0x6a3ad0 });
#   J.hips = new THREE.Group(); J.hips.position.y = 0.62; body.add(J.hips);
#   const torso = part(capsule(0.28, 0.7), dark); torso.rotation.x = Math.PI / 2; J.hips.add(torso);
#   J.head = new THREE.Group(); J.head.position.set(0, 0.16, 0.62); J.hips.add(J.head);
#   const hd = part(new THREE.BoxGeometry(0.34, 0.3, 0.46), dark); hd.position.z = 0.1; J.head.add(hd);
#   const jaw = part(new THREE.BoxGeometry(0.28, 0.1, 0.36), purple); jaw.position.set(0, -0.15, 0.12); J.head.add(jaw); J.jaw = jaw;
#   for (const ex of [-1, 1]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.04, 0.03), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.2, 0.5, 3) })); e.position.set(ex * 0.1, 0.07, 0.34); J.head.add(e); const ear = part(new THREE.ConeGeometry(0.07, 0.24, 4), dark, 0.02); ear.position.set(ex * 0.12, 0.24, 0.0); J.head.add(ear); }
#   const tail = part(capsule(0.05, 0.5), purple); tail.rotation.x = 1.0; tail.position.set(0, 0.1, -0.7); J.hips.add(tail); J.tail = tail;
#   J.legs = [];
#   for (const lz of [0.38, -0.38]) for (const lx of [-1, 1]) { const hp = new THREE.Group(); hp.position.set(lx * 0.2, -0.1, lz); J.hips.add(hp); const l = part(capsule(0.07, 0.4), dark, 0.02); l.position.y = -0.28; hp.add(l); J.legs.push(hp); }
#   body.traverse((o) => { if (o.isMesh) o.castShadow = true; });
#   return { id: 0, root, body, J, mats, kind: 'beast', cur: newPose(), anim: { name: 'idle', t: 0, dur: 1, loop: true }, runPh: 0, runSpd: 0, flash: 0, s: 1, vis: true, extra: {}, headM: hd };
# }
# 
# // ---- public rig API ----
# G3.rigNew = function (kind, lookName) {
#   const rig = kind === 'beast' ? buildBeast() : buildHumanoid(LOOKS[lookName] || LOOKS.grunt);
#   rig.id = rigId++; rig.lookName = lookName; scene.add(rig.root); RIGS.set(rig.id, rig);
#   if (rig.look && LOOKS[lookName] && LOOKS[lookName].aura) G3.auraAttach && G3.auraAttach(rig, LOOKS[lookName].aura);
#   return rig.id;
# };
# G3.rigDel = function (id) { const r = RIGS.get(id); if (!r) return; if (r.aura) { r.aura.dispose && r.aura.dispose(); } scene.remove(r.root); r.root.traverse((c) => { if (c.geometry && !c.geometry.userData.keep) c.geometry.dispose(); }); RIGS.delete(id); };
# G3.rigSet = function (id, x, y, z, yawDeg) { const r = RIGS.get(id); if (!r) return; r.root.position.set(x, y, z); r.root.rotation.y = yawDeg * D2R; };
# G3.rigPlay = function (id, name, dur, loop) { const r = RIGS.get(id); if (!r) return; const a = r.anim; if (a.name === name && loop && a.loop) return; a.name = name; a.t = 0; a.dur = Math.max(0.05, dur || 0.5); a.loop = !!loop; };
# G3.rigRun = function (id, spd) { const r = RIGS.get(id); if (r) r.runSpd = spd; };
# G3.rigFlash = function (id, v) { const r = RIGS.get(id); if (r) r.flash = v == null ? 1 : v; };
# G3.rigScale = function (id, s) { const r = RIGS.get(id); if (r) r.body.scale.setScalar((r.look ? (r.look.scale || 1) : 1) * s); };
# G3.rigVis = function (id, v) { const r = RIGS.get(id); if (r) { r.root.visible = !!v; r.vis = !!v; } };
# G3.rigAnimName = function (id) { const r = RIGS.get(id); return r ? r.anim.name : ''; };
# G3.rigDone = function (id) { const r = RIGS.get(id); return r ? (r.anim.loop || r.anim.t >= r.anim.dur) : true; };
# let _hp = null;
# G3.rigPart = function (id, what) {
#   const r = RIGS.get(id); if (!r) return { x: 0, y: 0, z: 0 }; if (!_hp) _hp = new THREE.Vector3();
#   const m = what === 'fistL' ? r.fistL : what === 'fistR' ? r.fistR : what === 'footR' ? r.footR : what === 'footL' ? r.footL : what === 'head' ? r.headM : r.chestM || r.headM;
#   if (!m) { _hp.copy(r.root.position); _hp.y += 1.2; } else { r.root.updateMatrixWorld(true); m.getWorldPosition(_hp); }
#   return { x: _hp.x, y: _hp.y, z: _hp.z };
# };
# G3.rigAt = function (id, what) { return G3.rigPart(id, what); };
# 
# 
# function updateRigs(dt) {
#   const tmp = newPose();
#   for (const r of RIGS.values()) {
#     if (!r.vis) continue;
#     const a = r.anim;
#     a.t += dt;
#     if (r.kind === 'beast') { updateBeast(r, dt); continue; }
#     const u = a.loop ? (a.t / a.dur) % 1 : clamp(a.t / a.dur, 0, 1);
#     const t = tmp; for (const k of JN) { t[k][0] = t[k][1] = t[k][2] = 0; }
#     if (a.name === 'idle' || a.name === 'run') {
#       sampleAnim('idle', 0, t);
#       const br = Math.sin(S.t * 2.6 + r.id) * 0.5 + 0.5;
#       t.torso[0] += br * 0.03; t.shL[0] += br * 0.04; t.shR[0] += br * 0.04; t.hy += br * 0.012;
#       if (r.runSpd > 0.05) {
#         r.runPh += dt * (6 + r.runSpd * 3.2); const p = r.runPh, sp = clamp(r.runSpd, 0.3, 2.2), amp = 0.55 + sp * 0.28;
#         t.hpL[0] = Math.sin(p) * amp - 0.1; t.hpR[0] = -Math.sin(p) * amp + 0.1;
#         t.knL[0] = 0.25 + Math.max(0, Math.sin(p + 1.6)) * (0.9 + sp * 0.4); t.knR[0] = 0.25 + Math.max(0, -Math.sin(p + 1.6)) * (0.9 + sp * 0.4);
#         t.shL[0] = -0.4 - Math.sin(p) * amp * 0.9; t.shR[0] = -0.4 + Math.sin(p) * amp * 0.9; t.elL[0] = -1.3; t.elR[0] = -1.3; t.shL[2] = 0.18; t.shR[2] = -0.18;
#         t.torso[0] = 0.12 + sp * 0.1; t.torso[1] = Math.sin(p) * 0.18; t.hips[1] = -Math.sin(p) * 0.12; t.hy = -0.03 + Math.abs(Math.cos(p)) * 0.06; t.lean = 4 + sp * 4;
#         t.shL[1] = 0; t.shR[1] = 0; t.head[0] = -0.1;
#       }
#     } else if (a.name === 'stun') {
#       sampleAnim('stun', 0, t); t.head[2] += Math.sin(S.t * 6) * 0.18; t.torso[2] += Math.sin(S.t * 4) * 0.08;
#     } else if (a.name === 'dash') {
#       sampleAnim('idle', 0, t); t.lean = 24; t.torso[0] = 0.5; t.hpL[0] = -0.9; t.knL[0] = 1.2; t.hpR[0] = 0.8; t.knR[0] = 0.3; t.shL[0] = 0.8; t.shR[0] = 0.9; t.elL[0] = -0.4; t.elR[0] = -0.4; t.shL[2] = 0.15; t.shR[2] = -0.15; t.hy = -0.1; t.head[0] = -0.3;
#     } else if (a.name === 'ragdoll') {
#       sampleAnim('hit', 0.2, t); const f = S.t * 11 + r.id;
#       t.shL[0] = -1.2 + Math.sin(f) * 0.9; t.shR[0] = -1.2 + Math.sin(f + 2) * 0.9; t.shL[2] = 1.0; t.shR[2] = -1.0; t.hpL[0] = -0.6 + Math.sin(f + 1) * 0.7; t.hpR[0] = -0.6 + Math.sin(f + 3) * 0.7; t.knL[0] = 0.8; t.knR[0] = 0.7; t.head[0] = -0.3 + Math.sin(f) * 0.3; t.torso[0] = 0.2;
#     } else sampleAnim(a.name, u, t);
#     // blend
#     const rate = Math.min(1, dt * (a.name === 'idle' || a.name === 'run' ? 14 : (a.name.startsWith('light') || a.name === 'heavy' || a.name.startsWith('air') || a.name === 'counter' ? 34 : 20)));
#     const c = r.cur;
#     for (const k of JN) { c[k][0] += (t[k][0] - c[k][0]) * rate; c[k][1] += (t[k][1] - c[k][1]) * rate; c[k][2] += (t[k][2] - c[k][2]) * rate; }
#     for (const k of ['hy', 'fwd', 'lean', 'lat', 'lie']) c[k] += (t[k] - c[k]) * rate;
#     const J = r.J;
#     for (const k of JN) J[k].rotation.set(c[k][0], c[k][1], c[k][2]);
#     J.hips.position.y = 0.96 + c.hy; J.hips.position.z = c.fwd; J.hips.position.x = c.lat;
#     if (r.look && r.look.hunch) J.torso.rotation.x += 0.22;
#     r.body.rotation.x = -c.lean * D2R * 1.0 - c.lie * Math.PI / 2; r.body.position.y = c.lie * (0.28 * r.s);
#     if (J.scarfTail) J.scarfTail.rotation.x = 0.25 + Math.sin(S.t * 5 + r.id) * 0.12 + r.runSpd * 0.3;
#     if (r.flash > 0) { r.flash = Math.max(0, r.flash - dt * 7); const e = r.flash; for (const m of r.mats) m.emissive.setRGB(e, e, e); }
#     else if (r.flashed) { for (const m of r.mats) m.emissive.setRGB(0, 0, 0); }
#     r.flashed = r.flash > 0;
#   }
# }
# function updateBeast(r, dt) {
#   const J = r.J, a = r.anim, p = (r.runPh += dt * (8 + r.runSpd * 3));
#   const run = r.runSpd > 0.05;
#   J.hips.position.y = 0.62 + (run ? Math.abs(Math.sin(p)) * 0.08 : 0);
#   J.hips.rotation.x = run ? Math.sin(p) * 0.08 : 0;
#   J.legs.forEach((l, i) => { l.rotation.x = run ? Math.sin(p + (i % 2) * 2.4 + (i > 1 ? 1.2 : 0)) * 0.9 : 0; });
#   J.tail.rotation.z = Math.sin(S.t * 6 + r.id) * 0.3;
#   const biting = a.name === 'bite' && a.t < a.dur;
#   J.head.rotation.x = biting ? 0.5 * Math.sin(Math.min(1, a.t / a.dur) * Math.PI) : 0; J.jaw.rotation.x = biting ? Math.sin(Math.min(1, a.t / a.dur) * Math.PI * 2) * 0.6 : 0;
#   r.body.position.z = biting ? Math.sin(Math.min(1, a.t / a.dur) * Math.PI) * 0.4 : 0;
#   if (r.flash > 0) { r.flash = Math.max(0, r.flash - dt * 7); for (const m of r.mats) m.emissive.setRGB(r.flash, r.flash, r.flash); }
# }
# // ---------------------------------------------------------------------
# // Cursed-energy VFX: per-character auras, strikes, abilities, domains
# // ---------------------------------------------------------------------
# // Palettes: each character's cursed energy looks different.
# const PAL = {
#   haru: { a: 0x3fa8ff, b: 0xa070ff, core: 0xdff4ff, dark: 0x0a1c50 },   // Limitless-style: clean blue flame, violet at the edges
#   kage: { a: 0x2a1250, b: 0xa05cff, core: 0xe0c8ff, dark: 0x05020c },   // shadow: ink-black smoke with violet rim
#   akai: { a: 0xff2236, b: 0xff8a3a, core: 0xfff0e0, dark: 0x2a0008 },   // blood lightning: red/black arcs
#   curse: { a: 0x7a3cff, b: 0xff40c0, core: 0xffffff, dark: 0x10061c }
# };
# G3.PAL = PAL;
# const palOf = (s) => PAL[s] || PAL.curse;
# const camDir = () => { const v = new THREE.Vector3(); camera.getWorldDirection(v); return v; };
# 
# function initFxSystems() {
#   addSys = makePointSys(1800, THREE.AdditiveBlending);
#   nrmSys = makePointSys(500, THREE.NormalBlending);
#   sparkSys = makeSparkSys(700);
#   initDebris(); initDecals();
# }
# 
# // ---- arc strip geometry (slash crescent) ----
# function arcStrip(r0, r1, a0, a1, seg) {
#   const pos = [], uv = [], idx = [];
#   for (let i = 0; i <= seg; i++) {
#     const u = i / seg, a = a0 + (a1 - a0) * u;
#     pos.push(Math.sin(a) * r0, 0, Math.cos(a) * r0, Math.sin(a) * r1, 0, Math.cos(a) * r1); uv.push(u, 0, u, 1);
#     if (i < seg) { const k = i * 2; idx.push(k, k + 1, k + 2, k + 1, k + 3, k + 2); }
#   }
#   const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx); return g;
# }
# const SLASH_FRAG = 'uniform vec3 uC, uC2; uniform float uP, uA; varying vec2 vUv; void main(){ float head = uP; float d = head - vUv.x; float tail = smoothstep(0.0, 0.7, d) * (1.0 - smoothstep(0.7, 1.4, d)); float vis = step(vUv.x, head) * pow(1.0 - clamp(d / 0.9, 0.0, 1.0), 1.4);'
#   + ' float w = 1.0 - abs(vUv.y - 0.5) * 2.0; w = pow(max(w, 0.0), 0.8); float core = pow(w, 4.0);'
#   + ' vec3 c = mix(uC, uC2, core); gl_FragColor = vec4(c * (0.6 + core * 1.6), (vis * w + core * vis) * uA); }';
# // x,y,z: origin; yawDeg: facing; tiltDeg: roll of the arc plane; reach: radius; sweepDeg: arc length
# function slash(x, y, z, yawDeg, tiltDeg, reach, style, dur, sweepDeg, flip) {
#   const p = palOf(style), sw = (sweepDeg || 150) * D2R;
#   const geo = arcStrip(reach * 0.55, reach, -sw / 2, sw / 2, 24);
#   const m = new THREE.Mesh(geo, addMat(SLASH_FRAG, { uC: { value: col3(p.a, 2.4) }, uC2: { value: col3(p.core, 3) }, uP: { value: 0 }, uA: { value: 1 } }));
#   const g = new THREE.Group(); g.add(m); g.position.set(x, y, z); g.rotation.order = 'YZX'; g.rotation.y = yawDeg * D2R; g.rotation.z = (tiltDeg || 0) * D2R * (flip ? -1 : 1); m.renderOrder = 5; scene.add(g);
#   if (flip) m.scale.x = -1;
#   addFx(dur || 0.22, (u) => { m.material.uniforms.uP.value = easeOut(u) * 1.5; m.material.uniforms.uA.value = 1 - Math.pow(u, 3); }, () => disposeObj(g));
# }
# G3.slash = slash;
# 
# // ---- bolts (lightning) ----
# function bolt(x1, y1, z1, x2, y2, z2, hex, life, jag, g) {
#   const n = 9, pts = [], dx = x2 - x1, dy = y2 - y1, dz = z2 - z1, L = Math.hypot(dx, dy, dz), j = (jag == null ? 0.18 : jag) * L * 0.5;
#   for (let i = 0; i <= n; i++) {
#     const t = i / n, f = Math.sin(t * Math.PI);
#     pts.push(new THREE.Vector3(x1 + dx * t + rand(-j, j) * f, y1 + dy * t + rand(-j, j) * f, z1 + dz * t + rand(-j, j) * f));
#   }
#   const geo = new THREE.BufferGeometry().setFromPoints(pts);
#   const mat = new THREE.LineBasicMaterial({ color: col3(hex, g == null ? 3 : g), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
#   const ln = new THREE.Line(geo, mat); ln.frustumCulled = false; ln.renderOrder = 6; scene.add(ln);
#   addFx(life || 0.12, (u) => { mat.opacity = 1 - u; }, () => disposeObj(ln));
# }
# G3.bolt = bolt;
# function arcCloud(x, y, z, R, n, hex, life) { for (let i = 0; i < n; i++) { const a = rand(0, TAU), b = rand(-0.5, 0.9), h = Math.sqrt(1 - b * b), r2 = R * rand(0.5, 1); bolt(x, y, z, x + Math.cos(a) * h * r2, y + b * r2, z + Math.sin(a) * h * r2, hex, life || rand(0.08, 0.18), 0.35); } }
# G3.arcCloud = arcCloud;
# 
# // ---- auras ----
# const AURA_FRAG = 'uniform vec3 uA, uB; uniform float uLvl, uStyle; varying vec2 vUv; varying vec3 vN; varying vec3 vP; void main(){'
#   + ' float f = 1.0 - abs(dot(normalize(vN), normalize(-vP))); float t = uTime; vec3 c; float a;'
#   + ' if (uStyle < 0.5) { float n = vnoise(vec3(vUv.x * 7.0, vUv.y * 4.0 - t * 2.6, t * 0.4)); float e = pow(f, 2.6) * (0.25 + n * 1.1); c = mix(uA, uB, clamp(f * 0.8 + n * 0.3, 0.0, 1.0)) * (0.45 + f * 0.5); a = e * uLvl * 0.8; }'
#   + ' else if (uStyle < 1.5) { float n = vnoise(vec3(vUv.x * 5.0, vUv.y * 3.0 - t * 1.1, t * 0.5)); float n2 = vnoise(vec3(vUv.x * 11.0 + t, vUv.y * 6.0 - t * 1.8, 2.0)); c = mix(vec3(0.01, 0.0, 0.03), uB * 2.0, smoothstep(0.62, 1.0, f) * n2); a = (0.04 + pow(f, 2.2) * 0.7) * (0.4 + n * 0.8) * uLvl; }'
#   + ' else { float j = step(0.5, vnoise(vec3(vUv.x * 9.0, vUv.y * 5.0 - t * 7.0, t * 3.0))); float j2 = step(0.62, vnoise(vec3(vUv.x * 18.0 - t * 4.0, vUv.y * 9.0, t * 6.0))); c = mix(uA, vec3(1.0, 0.85, 0.7), pow(f, 3.0) + j2 * 0.7) * 2.0; a = pow(f, 2.0) * (0.1 + j * 0.9) * uLvl; }'
#   + ' a *= (1.0 - smoothstep(0.5, 1.0, vUv.y)) * smoothstep(0.0, 0.12, vUv.y); gl_FragColor = vec4(c, clamp(a, 0.0, 1.0)); }';
# const AURA_VERT = 'varying vec2 vUv; varying vec3 vN; varying vec3 vP; uniform float uTime; uniform float uLvl; void main(){ vUv = uv; vec3 p = position; float an = atan(p.z, p.x); float fl = sin(p.y * 7.0 - uTime * 6.0 + an * 3.0) * 0.5 + sin(p.y * 13.0 - uTime * 9.0 - an * 5.0) * 0.5; float up = smoothstep(-0.2, 0.95, p.y); p.xz *= 1.0 - up * 0.55; p += normal * fl * 0.07 * (0.4 + up); p.y += up * (0.15 + 0.12 * sin(an * 4.0 + uTime * 8.0)) * (0.6 + uLvl * 0.3); vN = normalize(normalMatrix * normal); vec4 mv = modelViewMatrix * vec4(p, 1.0); vP = mv.xyz; gl_Position = projectionMatrix * mv; }';
# G3.auraAttach = function (rig, style) {
#   const p = palOf(style), sid = style === 'haru' ? 0 : style === 'kage' ? 1 : 2;
#   const geo = new THREE.CapsuleGeometry(0.46, 0.95, 6, 14);
#   const m = new THREE.Mesh(geo, addMat(AURA_FRAG, { uA: { value: col3(p.a, 1.6) }, uB: { value: col3(p.b, 1.6) }, uLvl: { value: 0 }, uStyle: { value: sid } }, AURA_VERT, sid === 1 ? { blending: THREE.NormalBlending } : {}));
#   m.position.y = 1.0; m.scale.set(1.35, 1.25, 1.35); m.renderOrder = 4; m.visible = false; rig.body.add(m);
#   rig.aura = { style, sid, p, mesh: m, lvl: 0, to: 0, em: 0, arc: 0, dispose() { } };
# };
# G3.aura = function (id, lvl) { const r = RIGS.get(id); if (r && r.aura) r.aura.to = lvl; };
# G3.auraBurst = function (id, power) { // flare: aura blooms and sends out a ring
#   const r = RIGS.get(id); if (!r || !r.aura) return; const a = r.aura; a.lvl = Math.max(a.lvl, 2.6); const pp = r.root.position;
#   ring(pp.x, 0.08, pp.z, 3.2 * (power || 1), a.p.a, 0.5, 0.3, null, 2.2); ring(pp.x, 0.08, pp.z, 5 * (power || 1), a.p.b, 0.7, 0.2, null, 1.6);
#   decal('glow', pp.x, pp.z, 6 * (power || 1), a.p.a, 1.2, 0.8); G3.pointFlash(pp.x, 1.2, pp.z, a.p.a, 2.6, 0.4);
#   for (let i = 0; i < 26 * (power || 1); i++) { const an = rand(0, TAU); P({ x: pp.x + Math.cos(an) * 0.6, y: 0.15, z: pp.z + Math.sin(an) * 0.6, vx: Math.cos(an) * rand(3, 8), vy: rand(0.5, 3), vz: Math.sin(an) * rand(3, 8), life: rand(0.4, 0.8), s0: 0.4, s1: 0, c0: a.p.core, c1: a.p.a, g: 2 }); }
# };
# G3.trail = function (id, sec) { const r = RIGS.get(id); if (r) r.trail = sec; };
# function hexLerp(a, b, t) { const A = hexRGB(a), B = hexRGB(b); return (Math.round(lerp(A[0], B[0], t) * 255) << 16) | (Math.round(lerp(A[1], B[1], t) * 255) << 8) | Math.round(lerp(A[2], B[2], t) * 255); }
# function updateAuras(dt) {
#   for (const r of RIGS.values()) {
#     const a = r.aura; if (!a) continue;
#     a.lvl = damp(a.lvl, a.to, 6, dt); const L = a.lvl;
#     a.mesh.visible = L > 0.03 && r.vis; a.mesh.material.uniforms.uLvl.value = L;
#     a.mesh.scale.set(1.35 + Math.sin(S.t * 3) * 0.04, 1.25 + L * 0.08, 1.35 + Math.sin(S.t * 3) * 0.04);
#     const pp = r.root.position, p = a.p;
#     if (L > 0.05 && r.vis) {
#       a.em += dt * (34 + L * 60) * QUALITY[S.quality].parts;
#       while (a.em > 1) {
#         a.em -= 1;
#         const an = rand(0, TAU), rr = rand(0.25, 0.6), h = rand(0.05, 1.9);
#         const x = pp.x + Math.cos(an) * rr, z = pp.z + Math.sin(an) * rr;
#         if (a.sid === 0) { // Haru: rising blue flame + orbiting motes
#           P({ x, y: pp.y + h, z, vx: Math.cos(an) * 0.2, vy: rand(1.2, 2.6) * (0.7 + L * 0.4), vz: Math.sin(an) * 0.2, life: rand(0.5, 0.9), s0: rand(0.16, 0.3), s1: 0, c0: p.core, c1: hexLerp(p.a, p.b, Math.random()), g: 1.1, a0: 0.5, drag: 0.9, swirl: 2.5 });
#           if (Math.random() < 0.18) P({ x: pp.x + Math.cos(an) * 1.0, y: pp.y + rand(0.2, 1.8), z: pp.z + Math.sin(an) * 1.0, vx: -Math.sin(an) * 1.6, vy: 0.3, vz: Math.cos(an) * 1.6, life: rand(0.7, 1.2), s0: 0.09, s1: 0.02, c0: 0xffffff, c1: p.a, g: 2.4, drag: 0.1, swirl: 3 });
#         } else if (a.sid === 1) { // Kage: ink smoke + violet wisps + ground tendrils
#           if (Math.random() < 0.55) P({ x, y: pp.y + h * 0.7, z, vx: Math.cos(an) * 0.3, vy: rand(0.5, 1.4), vz: Math.sin(an) * 0.3, life: rand(0.9, 1.5), s0: 0.3, s1: 1.0, c0: 0x120824, c1: 0x000000, a0: 0.55, a1: 0, add: false, drag: 0.6 });
#           if (Math.random() < 0.3) P({ x, y: pp.y + h, z, vx: 0, vy: rand(0.6, 1.4), vz: 0, life: rand(0.5, 0.9), s0: 0.12, s1: 0, c0: p.core, c1: p.b, g: 1.8, drag: 0.8, swirl: -2 });
#           if (Math.random() < 0.2) P({ x: pp.x + Math.cos(an) * 0.4, y: 0.12, z: pp.z + Math.sin(an) * 0.4, vx: Math.cos(an) * rand(1.5, 3), vy: 0, vz: Math.sin(an) * rand(1.5, 3), life: rand(0.6, 1), s0: 0.22, s1: 0.05, c0: 0x6a30c0, c1: 0x120824, g: 1.2, a0: 0.8, drag: 1.6 });
#         } else { // Akai: red embers + black-red arcs
#           P({ x, y: pp.y + h, z, vx: rand(-0.6, 0.6), vy: rand(1.6, 3.4), vz: rand(-0.6, 0.6), life: rand(0.35, 0.7), s0: rand(0.07, 0.15), s1: 0, c0: 0xffd0a0, c1: p.a, g: 2.2, drag: 0.4 });
#         }
#       }
#       if (a.sid === 2) { a.arc -= dt; if (a.arc <= 0) { a.arc = rand(0.05, 0.16) / Math.max(0.5, L); const an = rand(0, TAU), y0 = pp.y + rand(0.2, 1.8); bolt(pp.x + Math.cos(an) * 0.5, y0, pp.z + Math.sin(an) * 0.5, pp.x + Math.cos(an + rand(-0.8, 0.8)) * rand(1.1, 2.0), y0 + rand(-0.6, 0.9), pp.z + Math.sin(an + rand(-0.8, 0.8)) * rand(1.1, 2.0), Math.random() < 0.6 ? p.a : 0xffffff, 0.09, 0.3, 2.6); } }
#       if (a.sid === 0 && Math.random() < dt * 4) pointLightWisp(pp, p.a);
#       if (a.sid === 1 && L > 1.5) { a.arc -= dt; if (a.arc <= 0) { a.arc = 0.12; const an = rand(0, TAU); P({ x: pp.x + Math.cos(an) * 1.6, y: 0.1, z: pp.z + Math.sin(an) * 1.6, vx: -Math.cos(an) * 2.4, vy: 2.4, vz: -Math.sin(an) * 2.4, life: 0.6, s0: 0.3, s1: 0, c0: p.b, c1: p.a, g: 1.6, drag: 0.5 }); } }
#     }
#     if (r.trail > 0) {
#       r.trail -= dt; const c0 = p ? p.core : 0xffffff;
#       for (const w of ['fistL', 'fistR', 'footR']) {
#         const q = G3.rigPart(r.id, w);
#         P({ x: q.x, y: q.y, z: q.z, life: 0.28, s0: w === 'footR' ? 0.2 : 0.26, s1: 0, c0: c0, c1: (a.p.a), g: 2.2, a0: 0.9, drag: 4 });
#         P({ x: q.x, y: q.y, z: q.z, vx: rand(-.4, .4), vy: rand(-.2, .6), vz: rand(-.4, .4), life: 0.4, s0: 0.12, s1: 0, c0: a.p.b, c1: a.p.a, g: 2, drag: 3 });
#       }
#     }
#   }
# }
# const _wp = [];
# function pointLightWisp(pp, hex) { G3.pointFlash(pp.x, pp.y + 1.2, pp.z, hex, 1.6, 0.35); }
# 
# // ---- impact language ----
# // style: haru | kage | akai | curse.   power 1 (light) .. 3 (heavy) .. 4 (finisher)
# G3.hit = function (x, y, z, power, style) {
#   const p = palOf(style), n = power;
#   const cd = camDir();
#   P({ x, y, z, life: 0.12 + n * 0.02, s0: 1.2 + n * 0.7, s1: 2 + n, c0: 0xffffff, c1: p.a, g: 3, a0: 1 });
#   P({ x, y, z, life: 0.22, s0: 0.5 + n * 0.3, s1: 2.2 + n * 1.4, c0: p.core, c1: p.b, g: 2, a0: 0.8, drag: 6 });
#   sparkBurst(x, y, z, 10 + n * 8, 7 + n * 3, p.a, 0.4 + n * 0.08); sparkBurst(x, y, z, 6 + n * 3, 9 + n * 3, 0xffffff, 0.3);
#   ring(x, y, z, 1.4 + n * 0.8, p.core, 0.28, 0.2, [cd.x, cd.y, cd.z], 2.4);
#   if (n >= 2) { ring(x, 0.1, z, 2 + n * 1.2, p.a, 0.5, 0.25, null, 1.6); debris(x, 0.3, z, 4 + n * 3, 4 + n, 0x3a3a46, 0.15); G3.shake(0.25 + n * 0.12, 160 + n * 40); }
#   if (n >= 3) { decal('crack', x, z, 3 + n, p.a, 6, 0.9); decal('scorch', x, z, 3.5 + n, 0, 8, 1); }
#   G3.pointFlash(x, y, z, p.a, 1.6 + n * 0.7, 0.18); G3.hitstop(36 + n * 22); G3.aberr(0.003 * n);
# };
# G3.crit = function (x, y, z, style) {
#   const p = palOf(style); G3.invert(60); G3.hit(x, y, z, 4, style); G3.warpAt(x, y, z, 0.28); shell(x, y, z, 3.4, p.core, 0.3, 2.4, false);
#   for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; bolt(x, y, z, x + Math.cos(a) * 3, y + rand(-0.8, 1.2), z + Math.sin(a) * 3, p.a, 0.14, 0.2, 2.6); }
#   G3.aberr(0.01);
# };
# G3.blackFlash = function (x, y, z) { // universal timing mechanic: black/red spatial distortion + impact frame
#   G3.invert(110); G3.hitstop(150); G3.slowmo(18, 380); G3.warpAt(x, y, z, 0.5); G3.aberr(0.016); G3.shake(0.9, 420); G3.fovKick(-9);
#   shell(x, y, z, 4.5, 0xff1830, 0.5, 2.6, true); shell(x, y, z, 2.4, 0x000000, 0.4, 0.2, false);
#   ring(x, y, z, 7, 0xff2038, 0.55, 0.3, [0, 1, 0], 2.8); ring(x, 0.1, z, 9, 0xff2038, 0.7, 0.3, null, 2.4);
#   for (let i = 0; i < 16; i++) { const a = rand(0, TAU), b = rand(-0.6, 0.8); bolt(x, y, z, x + Math.cos(a) * rand(2.4, 4.5), y + b * 3, z + Math.sin(a) * rand(2.4, 4.5), i % 3 ? 0xff2038 : 0xffffff, rand(0.12, 0.3), 0.3, 3.2); }
#   sparkBurst(x, y, z, 50, 15, 0xff2038, 0.7); sparkBurst(x, y, z, 24, 18, 0xffffff, 0.5);
#   for (let i = 0; i < 18; i++) P({ x, y, z, vx: rand(-5, 5), vy: rand(-2, 5), vz: rand(-5, 5), life: rand(0.5, 0.9), s0: 0.5, s1: 1.4, c0: 0x000000, c1: 0x000000, a0: 0.9, a1: 0, add: false, drag: 3 });
#   decal('crack', x, z, 7, 0xff2038, 9, 1); decal('scorch', x, z, 6.5, 0, 10, 1); debris(x, 0.3, z, 18, 9, 0x2a2430, 0.28); G3.pointFlash(x, y, z, 0xff2038, 4, 0.35);
#   G3.sfx && G3.sfx('blackflash'); G3.flashScreen(0.35);
# };
# G3.guardBreak = function (x, y, z, style) { const p = palOf(style); ring(x, y, z, 4, 0xffffff, 0.35, 0.3, [0, 1, 0], 3); sparkBurst(x, y, z, 40, 12, 0xfff0c0, 0.5); shell(x, y, z, 2.2, 0xffe0a0, 0.3, 2, false); G3.shake(0.8, 300); G3.hitstop(140); G3.aberr(0.01); G3.invert(50); };
# G3.parry = function (x, y, z) { ring(x, y, z, 3, 0xaee8ff, 0.3, 0.2, [0, 1, 0], 3); sparkBurst(x, y, z, 30, 10, 0xaee8ff, 0.45); P({ x, y, z, life: 0.2, s0: 2, s1: 4, c0: 0xffffff, c1: 0x7fd0ff, g: 3 }); G3.hitstop(110); G3.shake(0.4, 160); G3.pointFlash(x, y, z, 0x8fdcff, 3, 0.2); };
# G3.blockSpark = function (x, y, z) { sparkBurst(x, y, z, 14, 8, 0xffe8b0, 0.35); P({ x, y, z, life: 0.1, s0: 0.8, s1: 1.4, c0: 0xffffff, c1: 0xffd080, g: 2.4 }); G3.hitstop(40); };
# G3.dashTrail = function (x, z, dx, dz, style) {
#   const p = palOf(style); for (let i = 0; i < 10; i++) { const t = i / 10; P({ x: x - dx * t * 3, y: rand(0.3, 1.8), z: z - dz * t * 3, vx: -dx * 2, vz: -dz * 2, life: rand(0.25, 0.5), s0: 0.35, s1: 0, c0: p.core, c1: p.a, g: 1.8, drag: 4 }); }
#   sparkBurst(x, 0.1, z, 8, 5, p.a, 0.3);
# };
# G3.footDust = function (x, z, amt) { for (let i = 0; i < (amt || 3); i++) P({ x: x + rand(-0.2, 0.2), y: 0.1, z: z + rand(-0.2, 0.2), vx: rand(-0.8, 0.8), vy: rand(0.2, 1), vz: rand(-0.8, 0.8), life: rand(0.4, 0.7), s0: 0.25, s1: 0.8, c0: 0x6a6a78, c1: 0x30303a, a0: 0.35, a1: 0, add: false, drag: 2 }); };
# G3.land = function (x, z, power) { G3.footDust(x, z, 8); ring(x, 0.06, z, 1.6 + (power || 1), 0x9aa0c0, 0.4, 0.2, null, 0.8); if ((power || 1) > 2) { debris(x, 0.2, z, 8, 4, 0x3a3a46, 0.15); G3.shake(0.5, 200); decal('crack', x, z, 3.5, 0x8090ff, 5, 0.6); } };
# G3.death = function (x, y, z, style) { const p = palOf(style); sparkBurst(x, y, z, 30, 8, p.b, 0.7); for (let i = 0; i < 22; i++) P({ x: x + rand(-0.4, 0.4), y: y + rand(-0.8, 0.8), z: z + rand(-0.4, 0.4), vx: rand(-1, 1), vy: rand(1, 3.5), vz: rand(-1, 1), life: rand(0.7, 1.3), s0: 0.35, s1: 0, c0: 0xffffff, c1: 0x9a50ff, g: 2, drag: 0.4 }); ring(x, 0.1, z, 3, 0xb070ff, 0.5, 0.2, null, 1.6); G3.pointFlash(x, y, z, 0xa060ff, 2, 0.3); };
# 
# // ======== HARU — Limitless-style: Blue / Red / Purple ========
# // Blue: concentrated point that pulls (Volt does the physics; this is the visual)
# G3.blue = function (x, y, z, dur, R) {
#   R = R || 7;
#   const core = new THREE.Mesh(new THREE.SphereGeometry(0.5, 20, 14), addMat('uniform float uA; varying vec3 vN; varying vec3 vP; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(-vP))), 1.4); gl_FragColor = vec4(mix(vec3(0.1, 0.5, 3.0), vec3(3.0), pow(1.0 - f, 3.0)) , uA); }', { uA: { value: 1 } }));
#   core.position.set(x, y, z); core.renderOrder = 6; scene.add(core);
#   const halo = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), addMat('uniform float uA; varying vec3 vN; varying vec3 vP; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(-vP))), 2.4); float n = vnoise(vP * 4.0 + vec3(0.0, uTime * 5.0, 0.0)); gl_FragColor = vec4(vec3(0.15, 0.6, 3.0) * (0.3 + n), f * uA); }', { uA: { value: 1 } }));
#   halo.position.set(x, y, z); halo.renderOrder = 5; scene.add(halo);
#   G3.pointFlash(x, y, z, 0x3a9cff, 4, dur); G3.sfx && G3.sfx('blue');
#   addFx(dur, (u, dt) => {
#     const grow = easeOut(Math.min(1, u * 5)), pul = 1 + Math.sin(S.t * 28) * 0.06, fade = u > 0.85 ? (1 - u) / 0.15 : 1;
#     core.scale.setScalar(grow * pul); halo.scale.setScalar(grow * 1.45 * pul); core.material.uniforms.uA.value = fade; halo.material.uniforms.uA.value = fade * 0.9;
#     for (let i = 0; i < 5; i++) { const a = rand(0, TAU), rr = rand(R * 0.35, R), yy = rand(-1.2, 1.8); const px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr, py = y + yy; const d = Math.hypot(px - x, py - y, pz - z) || 1; const sp = 11 + (R - rr) * 0.5; P({ x: px, y: py, z: pz, vx: (x - px) / d * sp - Math.sin(a) * 4, vy: (y - py) / d * sp, vz: (z - pz) / d * sp + Math.cos(a) * 4, life: rr / sp * 0.95, s0: 0.2, s1: 0.02, c0: 0xffffff, c1: 0x2a8cff, g: 2.4, drag: 0, a0: 0.9 }); }
#     if (Math.random() < 0.35) { const a = rand(0, TAU); decal('glow', x, z, R * 1.6 * Math.random() + 1, 0x2a8cff, 0.2, 0.25); bolt(x + Math.cos(a) * 1.2, y + rand(-1, 1), z + Math.sin(a) * 1.2, x, y, z, 0x66bbff, 0.07, 0.25, 2.4); }
#     G3.warpAt(x, y, z, 0.1 + Math.sin(u * Math.PI) * 0.12);
#     if (Math.random() < 0.3) G3.debrisLift && 0;
#   }, () => { disposeObj(core); disposeObj(halo); ring(x, y, z, 6, 0x66bbff, 0.35, 0.3, [0, 1, 0], 2.4); sparkBurst(x, y, z, 30, 9, 0x66bbff, 0.5); });
# };
# // Red: explosive repulsion
# G3.red = function (x, y, z, R) {
#   R = R || 7; const c = 0xff2a40;
#   G3.invert(70); G3.hitstop(120); G3.shake(1.1, 420); G3.fovKick(8); G3.aberr(0.014); G3.warpAt(x, y, z, -0.0 + 0.4); G3.flashScreen(0.25); G3.sfx && G3.sfx('red');
#   P({ x, y, z, life: 0.18, s0: 3, s1: 11, c0: 0xffffff, c1: c, g: 3.2, a0: 1 }); shell(x, y, z, R * 0.8, c, 0.5, 2.6, true); shell(x, y, z, R * 0.4, 0xffffff, 0.22, 3, false);
#   ring(x, 0.12, z, R * 1.5, c, 0.65, 0.35, null, 2.8); ring(x, 0.12, z, R * 0.9, 0xffb0a0, 0.45, 0.3, null, 2.4); ring(x, y, z, R, 0xff6070, 0.45, 0.3, [0, 1, 0], 2.2);
#   sparkBurst(x, y, z, 60, R * 2, c, 0.8); sparkBurst(x, y, z, 30, R * 2.4, 0xffffff, 0.5);
#   debris(x, 0.4, z, 30, 11, 0x3a3340, 0.3); decal('crack', x, z, R * 1.6, c, 10, 1); decal('scorch', x, z, R * 1.5, 0, 14, 1); decal('glow', x, z, R * 2.2, c, 1.5, 0.9);
#   for (let i = 0; i < 28; i++) { const a = rand(0, TAU), s = rand(5, R * 2.2); P({ x, y: y + rand(-0.4, 0.4), z, vx: Math.cos(a) * s, vy: rand(0, 3), vz: Math.sin(a) * s, life: rand(0.4, 0.9), s0: rand(0.5, 1.2), s1: 2, c0: 0x4a1018, c1: 0x120508, a0: 0.6, a1: 0, add: false, drag: 2 }); }
#   G3.pointFlash(x, y + 1, z, c, 5, 0.5); arcCloud(x, y, z, R * 0.8, 10, 0xff6070, 0.2);
#   G3.hitProps(x, z, R, 60);
# };
# // Purple: hollow-technique beam that tears through the environment
# G3.purpleCharge = function (id, dur) {
#   const r = RIGS.get(id); if (!r) return; G3.sfx && G3.sfx('charge');
#   const mkOrb = (hex) => { const m = new THREE.Mesh(new THREE.SphereGeometry(0.34, 14, 10), new THREE.MeshBasicMaterial({ color: col3(hex, 3) })); m.renderOrder = 6; scene.add(m); return m; };
#   const ob = mkOrb(0x2a8cff), or = mkOrb(0xff2a40);
#   addFx(dur, (u) => {
#     const pp = r.root.position, yaw = r.root.rotation.y, fx = Math.sin(yaw), fz = Math.cos(yaw), cy = pp.y + 1.55;
#     const sep = (1 - easeOut(u)) * 1.7 + 0.04, rx = Math.cos(yaw), rz = -Math.sin(yaw), rot = u * 14;
#     const off = 0.9 + u * 0.5;
#     ob.position.set(pp.x + fx * off + rx * sep * Math.cos(rot), cy + sep * Math.sin(rot) * 0.8, pp.z + fz * off + rz * sep * Math.cos(rot));
#     or.position.set(pp.x + fx * off - rx * sep * Math.cos(rot), cy - sep * Math.sin(rot) * 0.8, pp.z + fz * off - rz * sep * Math.cos(rot));
#     const sc = 1 + u * 1.3; ob.scale.setScalar(sc); or.scale.setScalar(sc);
#     P({ x: ob.position.x, y: ob.position.y, z: ob.position.z, life: 0.25, s0: 0.35, s1: 0, c0: 0xffffff, c1: 0x2a8cff, g: 2.5, drag: 5 }); P({ x: or.position.x, y: or.position.y, z: or.position.z, life: 0.25, s0: 0.35, s1: 0, c0: 0xffffff, c1: 0xff2a40, g: 2.5, drag: 5 });
#     if (u > 0.7) { const q = (u - 0.7) / 0.3; P({ x: pp.x + fx * off, y: cy, z: pp.z + fz * off, life: 0.2, s0: 0.8 + q, s1: 0, c0: 0xffffff, c1: 0xb060ff, g: 3 }); }
#     G3.shake(0.05 + u * 0.25, 60);
#     for (let i = 0; i < 2; i++) { const a = rand(0, TAU), rr = rand(2, 4); P({ x: pp.x + Math.cos(a) * rr, y: cy + rand(-1, 1), z: pp.z + Math.sin(a) * rr, vx: -Math.cos(a) * 6, vz: -Math.sin(a) * 6, life: 0.4, s0: 0.14, s1: 0, c0: 0xffffff, c1: 0xb060ff, g: 2.4, drag: 0 }); }
#     pointLightWisp({ x: pp.x, y: cy - 1.2, z: pp.z }, 0xa060ff);
#   }, () => { scene.remove(ob); scene.remove(or); ob.geometry.dispose(); or.geometry.dispose(); });
# };
# const BEAM_FRAG = 'uniform float uA; uniform vec3 uC, uC2; varying vec2 vUv; varying vec3 vN; varying vec3 vP; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(-vP))), 0.9); float n = vnoise(vec3(vUv.y * 22.0 - uTime * 26.0, vUv.x * 8.0, uTime * 3.0)); float n2 = vnoise(vec3(vUv.y * 60.0 - uTime * 50.0, vUv.x * 14.0, 4.0));'
#   + ' vec3 c = mix(uC, uC2, (1.0 - f) * 0.9 + n * 0.3); gl_FragColor = vec4(c * (1.1 + n2 * 0.9), uA * (0.35 + f * 0.7) * (0.6 + n * 0.6)); }';
# G3.purple = function (x, y, z, yawDeg, len, dur) {
#   len = len || 46; const yaw = yawDeg * D2R, fx = Math.sin(yaw), fz = Math.cos(yaw); dur = dur || 1.1;
#   G3.invert(80); G3.hitstop(110); G3.shake(1.2, dur * 1000 + 300); G3.fovKick(10); G3.aberr(0.018); G3.flashScreen(0.45); G3.sfx && G3.sfx('purple');
#   const mk = (r, c1, c2, a) => { const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, 1, 20, 1, true), addMat(BEAM_FRAG, { uA: { value: a }, uC: { value: col3(c1, 1.8) }, uC2: { value: col3(c2, 2.2) } })); m.renderOrder = 6; m.rotation.order = 'YXZ'; return m; };
#   const outer = mk(1, 0x7a2cff, 0xd070ff, 1), inner = mk(0.45, 0xd0a0ff, 0xffffff, 1);
#   const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = yaw; scene.add(g);
#   for (const m of [outer, inner]) { m.rotation.x = Math.PI / 2; m.position.z = 0; g.add(m); }
#   const head = new THREE.Mesh(new THREE.SphereGeometry(1, 18, 14), new THREE.MeshBasicMaterial({ color: col3(0xffffff, 3) })); head.renderOrder = 7; g.add(head);
#   G3.hitProps(x + fx * len * 0.5, z + fz * len * 0.5, len * 0.5, 999); G3.propsInLine(x, z, x + fx * len, z + fz * len, 2.4, 999);
#   let lastScorch = 0;
#   addFx(dur, (u, dt) => {
#     const ex = easeOut(Math.min(1, u * 7)), L = len * ex, rad = (u < 0.15 ? u / 0.15 : (u > 0.7 ? Math.max(0, (1 - u) / 0.3) : 1)) * (1.9 + Math.sin(S.t * 40) * 0.12);
#     for (const [m, k] of [[outer, 1], [inner, 0.42]]) { m.scale.set(rad * k, Math.max(0.01, L), rad * k); m.position.z = L / 2; m.material.uniforms.uA.value = 1; }
#     head.scale.setScalar(rad * 1.5); head.position.z = 0.3;
#     const wx = x + fx * L, wz = z + fz * L;
#     for (let i = 0; i < 8; i++) { const t = Math.random() * L, a = rand(0, TAU); P({ x: x + fx * t + Math.cos(a) * rad, y: y + Math.sin(a) * rad, z: z + fz * t, vx: fx * 12 + rand(-2, 2), vy: rand(-1, 1), vz: fz * 12, life: 0.35, s0: 0.25, s1: 0, c0: 0xffffff, c1: 0xa050ff, g: 2.4, drag: 1 }); }
#     for (let i = 0; i < 3; i++) { const t = Math.random() * L; sparkAdd(x + fx * t, y, z + fz * t, rand(-4, 4), rand(2, 7), rand(-4, 4), 0.4, 0xd090ff); }
#     if (L > 3 && u - lastScorch > 0.05) { lastScorch = u; const t = rand(2, L); decal('scorch', x + fx * t, z + fz * t, 4, 0, 10, 1); decal('glow', x + fx * t, z + fz * t, 6, 0xa050ff, 0.8, 0.8); debris(x + fx * t, 0.2, z + fz * t, 3, 8, 0x30303c, 0.25); ring(x + fx * t, 0.1, z + fz * t, 3, 0xc080ff, 0.3, 0.2, null, 1.8); }
#     G3.pointFlash(x + fx * 3, y, z + fz * 3, 0xa050ff, 6, 0.1); G3.warpAt(x + fx * 4, y, z + fz * 4, 0.08);
#     if (Math.random() < 0.5) { const t = Math.random() * L; bolt(x + fx * t, y + rand(-0.5, 0.5), z + fz * t, x + fx * t + rand(-4, 4), y + rand(-3, 3), z + fz * t + rand(-4, 4), 0xe0b0ff, 0.1, 0.3, 3); }
#   }, () => { disposeObj(g); const ex2 = x + fx * len * 0.9, ez = z + fz * len * 0.9; shell(ex2, 1, ez, 6, 0xa050ff, 0.5, 2.2, true); ring(ex2, 0.1, ez, 12, 0xc080ff, 0.6, 0.3, null, 2.4); sparkBurst(ex2, 1, ez, 40, 12, 0xd090ff, 0.7); });
# };
# 
# // ======== KAGE — shadow summons ========
# const POOL_FRAG = 'uniform float uA; uniform vec3 uC; varying vec2 vUv; void main(){ vec2 d = vUv - 0.5; float r = length(d) * 2.0; float a = atan(d.y, d.x); float n = vnoise(vec3(cos(a) * 2.0 + uTime * 0.6, sin(a) * 2.0 - uTime * 0.4, r * 3.0 - uTime * 1.6)); float edge = smoothstep(1.0, 0.82 + n * 0.12, r); float rim = smoothstep(0.55, 1.0, r) * edge; '
#   + 'vec3 c = mix(vec3(0.01, 0.0, 0.03), uC * 2.0, rim * 0.9); gl_FragColor = vec4(c, edge * uA * 0.95); }';
# G3.shadowPool = function (x, z, R, dur, up) {
#   const m = new THREE.Mesh(new THREE.PlaneGeometry(2, 2).rotateX(-Math.PI / 2), addMat(POOL_FRAG, { uA: { value: 0 }, uC: { value: col3(0x9a50ff, 1.2) } }, 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }', { blending: THREE.NormalBlending, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3 }));
#   m.position.set(x, 0.045, z); m.renderOrder = 3; scene.add(m);
#   addFx(dur, (u) => { const k = Math.min(1, u * 6) * (u > 0.8 ? (1 - u) / 0.2 : 1); m.scale.setScalar(Math.max(0.01, R * easeOut(Math.min(1, u * 5)))); m.material.uniforms.uA.value = k;
#     if (up !== false && Math.random() < 0.6) P({ x: x + rand(-R, R) * 0.6, y: 0.1, z: z + rand(-R, R) * 0.6, vx: 0, vy: rand(1, 3), vz: 0, life: rand(0.5, 0.9), s0: 0.2, s1: 0.04, c0: 0xe0c8ff, c1: 0x7a30d0, g: 1.8, drag: 0.5, swirl: 2 }); }, () => disposeObj(m));
# };
# G3.shadowSpike = function (x, z, h, hex) { // spear of shadow erupts from the ground
#   const m = G3.tmesh(new THREE.ConeGeometry(0.5, 1, 7), 0x0a0614, { th: 0.03, oc: 0x9a50ff }); m.position.set(x, 0, z); m.rotation.y = rand(0, TAU); scene.add(m); m.scale.set(1, 0.01, 1);
#   P({ x, y: 0.2, z, life: 0.25, s0: 1.2, s1: 3, c0: 0xe0c8ff, c1: 0x7a30d0, g: 2.2 }); debris(x, 0.2, z, 5, 5, 0x30303c, 0.14); ring(x, 0.08, z, 2.2, 0xa060ff, 0.35, 0.2, null, 2); G3.pointFlash(x, 0.8, z, 0xa060ff, 2, 0.2);
#   addFx(0.7, (u) => { const e = u < 0.2 ? easeOut(u / 0.2) : (u > 0.7 ? 1 - (u - 0.7) / 0.3 : 1); m.scale.set(1, Math.max(0.01, h * e), 1); m.position.y = h * e * 0.5; }, () => disposeObj(m));
# };
# G3.shadowOut = function (x, z) { // teleport: sink into shadow
#   G3.shadowPool(x, z, 2.2, 0.7, true); shell(x, 1, z, 1.6, 0x6a30c0, 0.25, 1.6, true); G3.sfx && G3.sfx('shadow');
#   for (let i = 0; i < 24; i++) { const a = rand(0, TAU); P({ x: x + Math.cos(a) * 1.1, y: rand(0.1, 1.9), z: z + Math.sin(a) * 1.1, vx: -Math.cos(a) * 3, vy: rand(-2, 1), vz: -Math.sin(a) * 3, life: 0.35, s0: 0.3, s1: 0, c0: 0xe0c8ff, c1: 0x5a20a0, g: 2, drag: 1 }); }
#   for (let i = 0; i < 10; i++) P({ x: x + rand(-.4, .4), y: rand(0.2, 1.8), z: z + rand(-.4, .4), vy: rand(0.5, 2), life: 0.8, s0: 0.5, s1: 1.2, c0: 0x0a0414, c1: 0x000000, a0: 0.7, a1: 0, add: false });
# };
# G3.shadowIn = function (x, z) { // emerge: shadow erupts upward
#   G3.shadowPool(x, z, 2.6, 0.9, true); shell(x, 1, z, 2.4, 0x9a50ff, 0.35, 2, true); ring(x, 0.08, z, 4.2, 0xa060ff, 0.45, 0.25, null, 2.2); G3.shake(0.5, 200); G3.aberr(0.006);
#   for (let i = 0; i < 30; i++) { const a = rand(0, TAU); P({ x: x + Math.cos(a) * 0.4, y: 0.1, z: z + Math.sin(a) * 0.4, vx: Math.cos(a) * rand(1, 3.5), vy: rand(2, 6), vz: Math.sin(a) * rand(1, 3.5), life: rand(0.5, 0.9), s0: 0.35, s1: 0, c0: 0xffffff, c1: 0x7a30d0, g: 2.2, drag: 0.6 }); }
#   for (let i = 0; i < 8; i++) P({ x: x + rand(-.5, .5), y: rand(0.2, 1), z: z + rand(-.5, .5), vy: rand(1, 3), life: 1, s0: 0.6, s1: 1.6, c0: 0x0a0414, c1: 0x000000, a0: 0.7, a1: 0, add: false });
#   sparkBurst(x, 0.5, z, 24, 8, 0xc090ff, 0.6);
# };
# G3.summon = function (x, z, big) { // a shadow beast tears up out of the ground
#   G3.shadowPool(x, z, big ? 3.2 : 1.9, 1.0, true); G3.shadowSpike(x + rand(-.7, .7), z + rand(-.7, .7), big ? 4 : 2.5); G3.sfx && G3.sfx('summon');
#   ring(x, 0.08, z, big ? 6 : 3.4, 0xa060ff, 0.5, 0.25, null, 2.2); sparkBurst(x, 0.4, z, 18, 7, 0xb070ff, 0.55);
# };
# 
# // ======== AKAI — blood lightning ========
# G3.lightningLine = function (x1, y1, z1, x2, y2, z2, n, hex) {
#   hex = hex || 0xff2236; for (let i = 0; i < (n || 5); i++) bolt(x1 + rand(-.2, .2), y1 + rand(-.2, .2), z1 + rand(-.2, .2), x2, y2 + rand(-.3, .3), z2, i % 3 === 0 ? 0xffffff : hex, rand(0.12, 0.28), 0.12, 3);
#   const d = Math.hypot(x2 - x1, z2 - z1) || 1; for (let i = 0; i < 14; i++) { const t = Math.random(); sparkAdd(lerp(x1, x2, t), y1, lerp(z1, z2, t), rand(-3, 3), rand(1, 5), rand(-3, 3), 0.4, hex); }
#   propsLine(x1, z1, x2, z2);
# };
# function propsLine(x1, z1, x2, z2) { G3.propsInLine(x1, z1, x2, z2, 1.1, 30); }
# G3.crimsonBlast = function (x, z, R) { // meteor-like slam: red shockwave with black lightning
#   G3.red(x, 0.6, z, R || 8); for (let i = 0; i < 14; i++) { const a = i / 14 * TAU; bolt(x, 0.3, z, x + Math.cos(a) * (R || 8) * 1.1, 0.3, z + Math.sin(a) * (R || 8) * 1.1, i % 2 ? 0xff2236 : 0xffffff, 0.3, 0.3, 3); }
#   for (let i = 0; i < 40; i++) { const a = rand(0, TAU), s = rand(4, 14); P({ x, y: 0.3, z, vx: Math.cos(a) * s, vy: rand(2, 8), vz: Math.sin(a) * s, life: rand(0.6, 1.2), s0: 0.3, s1: 0.05, c0: 0xffd0a0, c1: 0xff2236, g: 2.4, grav: -6, drag: 0.4 }); }
# };
# G3.meteorFall = function (x, z, delay, cb) { // telegraph circle then an impact
#   decal('glow', x, z, 6, 0xff2236, delay, 0.9); ring(x, 0.1, z, 3.2, 0xff2236, delay, 0.2, null, 2);
#   const m = new THREE.Mesh(new THREE.SphereGeometry(0.6, 10, 8), new THREE.MeshBasicMaterial({ color: col3(0xff4a30, 3) })); scene.add(m);
#   addFx(delay, (u) => { m.position.set(x, 26 * (1 - u * u) + 0.6, z); P({ x: m.position.x, y: m.position.y, z: m.position.z, life: 0.3, s0: 0.9, s1: 0, c0: 0xffd0a0, c1: 0xff2236, g: 2.4, drag: 2 }); }, () => { scene.remove(m); m.geometry.dispose(); G3.crimsonBlast(x, z, 4.5); if (cb) cb(); });
# };
# 
# // ======== DOMAIN EXPANSION ========
# const DOM = { on: false, kind: 0, group: null, saved: null, t: 0, x: 0, z: 0, stars: null, mats: [] };
# const DOMAINS = {
#   1: { name: 'Boundless Expanse', sub: 'Infinite Void', col: 0x5ab4ff, col2: 0xa070ff, fog: 0x050b24, fogD: 0.012, bg: 0x02040e, hemi: [0x5a80ff, 0x120a30, 1.1], key: [0xa0c0ff, 1.2] },
#   2: { name: 'Hollow Garden', sub: 'Garden of a Thousand Shadows', col: 0xb070ff, col2: 0x4a1a90, fog: 0x07030f, fogD: 0.03, bg: 0x030108, hemi: [0x6a30b0, 0x05020a, 0.8], key: [0x8a50e0, 0.9] },
#   3: { name: 'Crimson Colosseum', sub: 'Arena of Blood Lightning', col: 0xff2a3a, col2: 0xff9a40, fog: 0x1a0306, fogD: 0.016, bg: 0x0a0104, hemi: [0xff4a50, 0x200508, 1.0], key: [0xff6a50, 1.3] }
# };
# G3.DOMAINS = DOMAINS;
# const DOME_FRAG = 'uniform float uK; uniform vec3 uC, uC2; varying vec3 vW; void main(){ vec3 d = normalize(vW); float h = d.y; vec3 c = vec3(0.0);'
#   + ' if (uK < 1.5) { float n = vnoise(d * 3.0 + vec3(0, 0, uTime * 0.06)) * 0.6 + vnoise(d * 7.0 - uTime * 0.04) * 0.4; float band = exp(-pow((h - 0.18) * 3.2, 2.0)); float neb = smoothstep(0.35, 0.85, n) * (0.35 + band * 1.1);'
#   + '   float st = step(0.985, hash(floor(d * 220.0))) * (0.5 + 0.5 * sin(uTime * 3.0 + hash(floor(d * 220.0)) * 40.0)); float st2 = step(0.9965, hash(floor(d * 90.0 + 7.0))) * 2.0;'
#   + '   c = mix(vec3(0.01, 0.02, 0.08), mix(uC2, uC, n) * 0.7, neb) + vec3(st + st2) * 1.2; float gx = exp(-pow((h - 0.02) * 9.0, 2.0)) * 0.6; c += uC * gx * 0.5; }'
#   + ' else if (uK < 2.5) { float n = vnoise(d * 4.0 + vec3(uTime * 0.1, 0, 0)); float moon = smoothstep(0.994, 0.997, dot(d, normalize(vec3(0.25, 0.55, -0.8)))); float trees = step(h, 0.1 + 0.12 * sin(atan(d.x, d.z) * 14.0 + sin(atan(d.x, d.z) * 31.0)) * 0.6 + n * 0.1);'
#   + '   c = mix(vec3(0.02, 0.005, 0.05), uC2 * 0.55, pow(1.0 - clamp(h, 0.0, 1.0), 3.0) * (0.4 + n)) ; c += vec3(moon) * vec3(2.0, 1.6, 3.0); c = mix(c, vec3(0.0), trees * 0.92); c += uC * pow(max(0.0, 1.0 - abs(h - 0.1) * 5.0), 3.0) * 0.18; }'
#   + ' else { float n = vnoise(d * 5.0 + vec3(0.0, -uTime * 0.25, 0.0)); float sunD = dot(d, normalize(vec3(-0.3, 0.45, -0.85))); float sun = smoothstep(0.985, 0.992, sunD); float glow = pow(max(0.0, sunD), 14.0);'
#   + '   c = mix(vec3(0.12, 0.01, 0.02), vec3(0.55, 0.05, 0.05), pow(1.0 - clamp(h, 0.0, 1.0), 2.0)) * (0.5 + n * 0.9); c += vec3(sun) * vec3(3.0, 0.7, 0.4) + uC * glow * 1.4; float bolt = step(0.93, vnoise(vec3(d.x * 14.0, d.z * 14.0, uTime * 8.0))) * step(0.3, h); c += vec3(1.0, 0.2, 0.2) * bolt * 1.5; }'
#   + ' gl_FragColor = vec4(c, 1.0); }';
# function domainFloor(kind) {
#   const w = 512, cv = document.createElement('canvas'); cv.width = cv.height = w; const g = cv.getContext('2d');
#   if (kind === 1) { g.fillStyle = '#04081c'; g.fillRect(0, 0, w, w); g.strokeStyle = 'rgba(90,170,255,0.55)'; g.lineWidth = 2; for (let i = 0; i <= 16; i++) { g.beginPath(); g.moveTo(i * w / 16, 0); g.lineTo(i * w / 16, w); g.moveTo(0, i * w / 16); g.lineTo(w, i * w / 16); g.stroke(); } for (let i = 0; i < 160; i++) { g.fillStyle = 'rgba(160,220,255,' + rand(0.2, 0.9) + ')'; g.fillRect(rand(0, w), rand(0, w), 2, 2); } }
#   else if (kind === 2) { g.fillStyle = '#07030f'; g.fillRect(0, 0, w, w); for (let i = 0; i < 400; i++) { g.fillStyle = 'rgba(' + (60 + rand(0, 60) | 0) + ',20,' + (110 + rand(0, 90) | 0) + ',' + rand(0.08, 0.35) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, w), rand(2, 14), rand(1, 6), rand(0, 3), 0, TAU); g.fill(); } }
#   else { g.fillStyle = '#1a0507'; g.fillRect(0, 0, w, w); for (let i = 0; i < 90; i++) { g.strokeStyle = 'rgba(255,60,60,' + rand(0.1, 0.5) + ')'; g.lineWidth = rand(1, 3); g.beginPath(); let x = rand(0, w), y = rand(0, w); g.moveTo(x, y); for (let k = 0; k < 6; k++) { x += rand(-40, 40); y += rand(-40, 40); g.lineTo(x, y); } g.stroke(); } g.strokeStyle = 'rgba(255,60,70,0.6)'; g.lineWidth = 5; g.beginPath(); g.arc(w / 2, w / 2, w * 0.33, 0, TAU); g.stroke(); g.beginPath(); g.arc(w / 2, w / 2, w * 0.12, 0, TAU); g.stroke(); }
#   const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
# }
# G3.domainOn = function (kind, x, z) {
#   if (DOM.on) G3.domainOff(true);
#   const d = DOMAINS[kind]; DOM.on = true; DOM.kind = kind; DOM.x = x; DOM.z = z; DOM.t = 0;
#   DOM.saved = { bg: scene.background.getHex(), fog: scene.fog.color.getHex(), fd: scene.fog.density, hemi: [hemi.color.getHex(), hemi.groundColor.getHex(), hemi.intensity], moon: [moon.color.getHex(), moon.intensity], vis: MAP.group ? MAP.group.visible : true };
#   if (MAP.group) MAP.group.visible = false;
#   const gp = new THREE.Group(); gp.position.set(x, 0, z); scene.add(gp); DOM.group = gp;
#   const dome = new THREE.Mesh(new THREE.SphereGeometry(180, 32, 20), new THREE.ShaderMaterial({ side: THREE.BackSide, depthWrite: false, fog: false, uniforms: { uTime: UT, uK: { value: kind }, uC: { value: col3(d.col, 1) }, uC2: { value: col3(d.col2, 1) } }, vertexShader: 'varying vec3 vW; void main(){ vW = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }', fragmentShader: 'uniform float uTime;\n' + GLSL_NOISE + '\n' + DOME_FRAG }));
#   dome.renderOrder = -10; gp.add(dome); DOM.dome = dome;
#   const ft = domainFloor(kind); ft.repeat.set(kind === 3 ? 1 : 9, kind === 3 ? 1 : 9);
#   const floor = new THREE.Mesh(new THREE.CircleGeometry(kind === 3 ? 34 : 120, 64).rotateX(-Math.PI / 2), G3.toon(0xffffff, { map: ft, emissive: kind === 1 ? 0x112244 : 0x000000, emissiveMap: kind === 1 ? ft : null })); floor.receiveShadow = true; gp.add(floor);
#   const near = (hex, a) => { const m = new THREE.Mesh(new THREE.CircleGeometry(30, 48).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: glowTex, color: hex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: a })); m.position.y = 0.04; gp.add(m); };
#   if (kind === 1) { // floating crystal shards + orbiting rings
#     near(0x3a80ff, 0.6);
#     for (let i = 0; i < 26; i++) { const a = rand(0, TAU), r = rand(10, 42); const s = G3.tmesh(new THREE.OctahedronGeometry(rand(0.5, 1.8)), 0x1a2a6a, { th: 0.03, oc: 0x6ab0ff, mo: { emissive: 0x2a50c0 } }); s.position.set(Math.cos(a) * r, rand(1, 12), Math.sin(a) * r); s.scale.y = rand(1.6, 3); s.userData = { by: s.position.y, ph: rand(0, 9), sp: rand(0.2, 0.7) }; gp.add(s); DOM.mats.push(s); }
#     for (let i = 0; i < 3; i++) { const rg = new THREE.Mesh(new THREE.TorusGeometry(26 + i * 8, 0.12, 6, 90), new THREE.MeshBasicMaterial({ color: col3(i % 2 ? 0xa070ff : 0x5ab4ff, 2) })); rg.position.y = 14 + i * 4; rg.rotation.x = Math.PI / 2 + (i - 1) * 0.35; rg.userData = { spin: (i + 1) * 0.08 }; gp.add(rg); DOM.mats.push(rg); }
#   } else if (kind === 2) { // dead shadow-trees + hanging lanterns
#     near(0x7a30d0, 0.45);
#     for (let i = 0; i < 40; i++) { const a = rand(0, TAU), r = rand(9, 48); const tr = new THREE.Group(); const h = rand(5, 13); const tk = G3.tmesh(new THREE.CylinderGeometry(0.1, 0.35, h, 6), 0x0a0614, { th: 0.04, oc: 0x6a30c0 }); tk.position.y = h / 2; tr.add(tk); for (let b = 0; b < 4; b++) { const br = G3.tmesh(new THREE.CylinderGeometry(0.04, 0.12, rand(2, 4), 5), 0x0a0614, { th: 0.03, oc: 0x6a30c0 }); br.position.set(0, h * rand(0.5, 0.95), 0); br.rotation.set(rand(-.5, .5), rand(0, TAU), rand(0.5, 1.1)); tr.add(br); } tr.position.set(Math.cos(a) * r, 0, Math.sin(a) * r); gp.add(tr); }
#     for (let i = 0; i < 22; i++) { const a = rand(0, TAU), r = rand(5, 30); const l = new THREE.Mesh(new THREE.SphereGeometry(0.22, 8, 6), new THREE.MeshBasicMaterial({ color: col3(0xb070ff, 3) })); l.position.set(Math.cos(a) * r, rand(1, 7), Math.sin(a) * r); l.userData = { by: l.position.y, ph: rand(0, 9), sp: rand(0.5, 1.2) }; gp.add(l); DOM.mats.push(l); }
#   } else { // colosseum ring of pillars + blood moon
#     near(0xff2a3a, 0.5);
#     for (let i = 0; i < 20; i++) { const a = i / 20 * TAU, r = 32; const pl = G3.tmesh(new THREE.CylinderGeometry(1.2, 1.5, 15, 8), 0x3a1418, { th: 0.05, oc: 0xff3040, mo: { emissive: 0x200408 } }); pl.position.set(Math.cos(a) * r, 7.5, Math.sin(a) * r); if (i % 4 === 0) pl.scale.y = 0.6, pl.position.y = 4.5; gp.add(pl); const cap = G3.tmesh(new THREE.BoxGeometry(3.4, 1, 3.4), 0x4a1c20, { th: 0.04, oc: 0xff3040 }); cap.position.set(Math.cos(a) * r, pl.position.y * 2 - (i % 4 === 0 ? 0 : 0) , Math.sin(a) * r); if (i % 4 !== 0) gp.add(cap); }
#     for (let i = 0; i < 20; i++) { const a = (i + 0.5) / 20 * TAU, r = 32; const arc = G3.tmesh(new THREE.BoxGeometry(11, 2, 1.6), 0x2a0e12, { th: 0.04, oc: 0xff3040 }); arc.position.set(Math.cos(a) * r, 14, Math.sin(a) * r); arc.rotation.y = -a + Math.PI / 2; gp.add(arc); }
#     for (let i = 0; i < 4; i++) { const t = new THREE.Mesh(new THREE.ConeGeometry(0.5, 1.6, 6), new THREE.MeshBasicMaterial({ color: col3(0xff6a30, 3) })); const a = i / 4 * TAU + 0.78; t.position.set(Math.cos(a) * 13, 1.6, Math.sin(a) * 13); gp.add(t); const bs = G3.tmesh(new THREE.CylinderGeometry(0.4, 0.5, 1.2, 6), 0x1a0a0c, { th: 0.03 }); bs.position.set(t.position.x, 0.6, t.position.z); gp.add(bs); t.userData = { flame: 1 }; DOM.mats.push(t); }
#   }
#   G3.setSky && 0;
#   scene.background = new THREE.Color(d.bg); scene.fog.color.setHex(d.fog); scene.fog.density = d.fogD;
#   hemi.color.setHex(d.hemi[0]); hemi.groundColor.setHex(d.hemi[1]); hemi.intensity = d.hemi[2]; moon.color.setHex(d.key[0]); moon.intensity = d.key[1];
#   G3.pointFlash(x, 3, z, d.col, 4, 0.8);
# };
# G3.domainOff = function (quiet) {
#   if (!DOM.on) return; DOM.on = false;
#   if (DOM.group) { disposeObj(DOM.group); DOM.group = null; } DOM.mats.length = 0;
#   const s = DOM.saved; if (s) { scene.background = new THREE.Color(s.bg); scene.fog.color.setHex(s.fog); scene.fog.density = s.fd; hemi.color.setHex(s.hemi[0]); hemi.groundColor.setHex(s.hemi[1]); hemi.intensity = s.hemi[2]; moon.color.setHex(s.moon[0]); moon.intensity = s.moon[1]; if (MAP.group) MAP.group.visible = s.vis; }
#   if (!quiet) { G3.flashScreen(0.6); G3.invert(70); shell(DOM.x, 1.4, DOM.z, 14, 0xffffff, 0.5, 1.6, false); }
# };
# G3.domainActive = () => DOM.on;
# G3.domainCenter = () => ({ x: DOM.x, z: DOM.z });
# function updateDomain(dt) {
#   if (!DOM.on) return; DOM.t += dt;
#   for (const o of DOM.mats) {
#     const u = o.userData; if (u.ph !== undefined) { o.position.y = u.by + Math.sin(S.t * u.sp + u.ph) * 0.8; if (o.rotation) o.rotation.y += dt * 0.4; }
#     if (u.spin) o.rotation.z += dt * u.spin; if (u.flame) o.scale.set(1 + Math.sin(S.t * 14) * 0.15, 1 + Math.sin(S.t * 11 + 1) * 0.25, 1);
#   }
#   const g = DOM.group; if (!g) return; const k = DOM.kind;
#   if (Math.random() < dt * 40) {
#     const a = rand(0, TAU), r = rand(2, 40), x = DOM.x + Math.cos(a) * r, z = DOM.z + Math.sin(a) * r;
#     if (k === 1) P({ x, y: rand(0.3, 10), z, vy: rand(0.2, 0.8), life: 3, s0: 0.1, s1: 0.1, c0: 0xffffff, c1: 0x7ab4ff, g: 2.4, drag: 0 });
#     else if (k === 2) P({ x, y: rand(0.3, 8), z, vx: 0.8, vy: rand(-0.2, 0.5), life: 3.5, s0: 0.16, s1: 0.04, c0: 0xc890ff, c1: 0x5a20a0, g: 1.8, drag: 0, swirl: 0.8 });
#     else P({ x, y: 0.2, z, vx: rand(-0.5, 0.5), vy: rand(2, 5), life: 2, s0: 0.12, s1: 0, c0: 0xffd0a0, c1: 0xff2236, g: 2.4, drag: 0.1 });
#   }
#   if (k === 3 && Math.random() < dt * 1.4) { const a = rand(0, TAU); bolt(DOM.x + Math.cos(a) * 30, 20, DOM.z + Math.sin(a) * 30, DOM.x + Math.cos(a) * rand(4, 28), 0, DOM.z + Math.sin(a) * rand(4, 28), 0xff3040, 0.25, 0.3, 2.6); }
# }
# // guaranteed-hit sequence strikes (visual, per hit). n = counter
# G3.domainStrike = function (kind, x, y, z, n) {
#   const d = DOMAINS[kind]; if (!d) return;
#   if (kind === 1) { // infinite-void slashes: bright lines + information overload flashes
#     for (let i = 0; i < 3; i++) slash(x, y + rand(-.5, .5), z, rand(0, 360), rand(-70, 70), rand(2.6, 4.2), 'haru', 0.16, 160, Math.random() < 0.5);
#     G3.hit(x, y, z, 2 + (n % 2), 'haru'); if (n % 3 === 0) { G3.invert(45); ring(x, y, z, 4, 0xffffff, 0.3, 0.2, [0, 1, 0], 3); }
#   } else if (kind === 2) { // erupting shadow spears
#     for (let i = 0; i < 3; i++) { const a = rand(0, TAU), r = i ? rand(0.5, 2.4) : 0; G3.shadowSpike(x + Math.cos(a) * r, z + Math.sin(a) * r, rand(3.5, 6)); }
#     G3.hit(x, y, z, 2 + (n % 2), 'kage');
#   } else { // raining crimson blades + black flash finisher on last
#     for (let i = 0; i < 2; i++) bolt(x + rand(-2, 2), 14, z + rand(-2, 2), x, y, z, i ? 0xffffff : 0xff2236, 0.18, 0.15, 3.2);
#     slash(x, y, z, rand(0, 360), rand(-40, 40), rand(3, 4.5), 'akai', 0.15, 170, n % 2 === 0); G3.hit(x, y, z, 2 + (n % 2), 'akai');
#   }
# };
# G3.domainSure = function (kind, x, y, z) { // final guaranteed-hit detonation
#   const d = DOMAINS[kind]; G3.invert(120); G3.hitstop(160); G3.shake(1.4, 600); G3.flashScreen(0.7);
#   shell(x, y, z, 9, d.col, 0.7, 2.6, true); ring(x, 0.1, z, 20, d.col, 0.9, 0.3, null, 2.6); ring(x, y, z, 10, d.col2, 0.6, 0.3, [0, 1, 0], 2.6); sparkBurst(x, y, z, 80, 18, d.col, 1.0); debris(x, 0.4, z, 30, 12, 0x303040, 0.3);
#   decal('crack', x, z, 10, d.col, 12, 1); arcCloud(x, y, z, 8, 14, d.col, 0.25);
# };
# 
# // ---- misc helpers used by the Volt gameplay layer ----
# G3.rigAuraStyle = function (id, style) { const r = RIGS.get(id); if (!r) return; if (r.aura) { r.body.remove(r.aura.mesh); } G3.auraAttach(r, style); };
# G3.orbFx = function (x, y, z, hex, size) { const p = palOf(hex); P({ x, y, z, life: 0.12, s0: size || 0.9, s1: (size || 0.9) * 0.6, c0: 0xffffff, c1: typeof hex === 'number' ? hex : 0xa050ff, g: 3, a0: 1, drag: 0 }); P({ x, y, z, life: 0.35, s0: (size || 0.9) * 0.7, s1: 0, c0: typeof hex === 'number' ? hex : 0xa050ff, c1: 0x200040, g: 2, a0: 0.8, drag: 3 }); };
# G3.telegraph = function (x, z, R, sec, hex) { decal('glow', x, z, R * 2.2, hex || 0xff2a40, sec, 0.9); ring(x, 0.09, z, R, hex || 0xff2a40, sec, 0.18, null, 1.6); };
# G3.camYawDeg = () => S.yaw * 180 / Math.PI;
# G3.camSetYawDeg = (d) => { S.yaw = d * Math.PI / 180; };
# G3.camDist = (d) => { S.dist = d; };
# G3.camPitchGet = () => S.pitch;
# G3.rigYaw = (id, d) => { const r = RIGS.get(id); if (r) r.root.rotation.y = d * Math.PI / 180; };
# G3.rigPos = (id, x, y, z) => { const r = RIGS.get(id); if (r) r.root.position.set(x, y, z); };
# G3.rigTrailOn = (id, s) => { const r = RIGS.get(id); if (r) r.trail = s; };
# G3.screenFlashColor = function (hex, a) { G3.grade(hex, a); };
# G3.cineOrbit = (x, y, z, dur, a0, a1, rad, h) => G3.cine('orbit', x, y, z, dur, a0 * D2R, a1 * D2R, rad, h);
# G3.cinePush = (x, y, z, dur, aDeg, rad, h) => G3.cine('push', x, y, z, dur, aDeg * D2R, 0, rad, h);
# G3.cineLow = (x, y, z, dur, a0, a1, rad) => G3.cine('low', x, y, z, dur, a0 * D2R, a1 * D2R, rad, 0);
# G3.vel = (x) => x;
# // ---------------------------------------------------------------------
# // Procedural audio (WebAudio): impacts, energy, ability SFX, adaptive music
# // ---------------------------------------------------------------------
# const AU = { ctx: null, master: null, sfx: null, mus: null, noise: null, mood: '', musTimer: 0, step: 0, vol: 0.7, on: true };
# function auInit() {
#   if (AU.ctx) { if (AU.ctx.state === 'suspended') AU.ctx.resume(); return; }
#   try {
#     const C = window.AudioContext || window.webkitAudioContext; const ctx = AU.ctx = new C();
#     AU.master = ctx.createGain(); AU.master.gain.value = AU.vol; const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 6; AU.master.connect(comp); comp.connect(ctx.destination);
#     AU.sfx = ctx.createGain(); AU.sfx.gain.value = 0.9; AU.sfx.connect(AU.master); AU.mus = ctx.createGain(); AU.mus.gain.value = 0.34; AU.mus.connect(AU.master);
#     const len = ctx.sampleRate * 2, b = ctx.createBuffer(1, len, ctx.sampleRate), d = b.getChannelData(0); for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1; AU.noise = b;
#     // simple reverb
#     const rl = ctx.sampleRate * 1.6, rb = ctx.createBuffer(2, rl, ctx.sampleRate); for (let c = 0; c < 2; c++) { const rd = rb.getChannelData(c); for (let i = 0; i < rl; i++) rd[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / rl, 3); }
#     AU.rev = ctx.createConvolver(); AU.rev.buffer = rb; const rg = ctx.createGain(); rg.gain.value = 0.28; AU.rev.connect(rg); rg.connect(AU.master);
#   } catch (e) { AU.ctx = null; }
# }
# G3.audioInit = auInit;
# G3.volume = (v) => { AU.vol = clamp(v, 0, 1); if (AU.master) AU.master.gain.value = AU.vol; };
# function osc(type, f0, f1, dur, vol, t0, dest, delay) {
#   const ctx = AU.ctx, t = (t0 || ctx.currentTime) + (delay || 0), o = ctx.createOscillator(), g = ctx.createGain();
#   o.type = type; o.frequency.setValueAtTime(f0, t); if (f1 != null) o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur);
#   g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + Math.min(0.01, dur * 0.2)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
#   o.connect(g); g.connect(dest || AU.sfx); o.start(t); o.stop(t + dur + 0.05); return g;
# }
# function nz(dur, vol, f0, f1, q, type, delay, wet) {
#   const ctx = AU.ctx, t = ctx.currentTime + (delay || 0), s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
#   s.buffer = AU.noise; s.loop = true; f.type = type || 'bandpass'; f.Q.value = q || 1; f.frequency.setValueAtTime(f0, t); if (f1) f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
#   g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + Math.min(0.015, dur * 0.2)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
#   s.connect(f); f.connect(g); g.connect(AU.sfx); if (wet && AU.rev) g.connect(AU.rev); s.start(t, Math.random()); s.stop(t + dur + 0.05);
# }
# const SFX = {
#   swing: () => nz(0.16, 0.22, 3200, 600, 1.2, 'bandpass'),
#   swing2: () => nz(0.22, 0.28, 2400, 300, 1.0, 'bandpass'),
#   hit: () => { osc('sine', 170, 50, 0.16, 0.9); nz(0.09, 0.5, 1800, 400, 0.8); osc('square', 420, 120, 0.05, 0.12); },
#   heavy: () => { osc('sine', 110, 32, 0.38, 1.1); nz(0.2, 0.6, 1500, 200, 0.6, 'lowpass', 0, true); osc('sawtooth', 220, 50, 0.2, 0.22); },
#   crit: () => { osc('sine', 90, 28, 0.55, 1.2); nz(0.35, 0.7, 4000, 300, 0.7, 'bandpass', 0, true); osc('triangle', 880, 220, 0.25, 0.25); },
#   blackflash: () => { osc('sine', 60, 22, 0.9, 1.4); osc('sawtooth', 1200, 60, 0.5, 0.35); nz(0.7, 0.9, 6000, 100, 0.5, 'bandpass', 0, true); osc('square', 40, 40, 0.6, 0.3); osc('sine', 1760, 3520, 0.12, 0.3, null, null, 0.02); },
#   dash: () => { nz(0.22, 0.3, 700, 4200, 0.9, 'bandpass'); osc('sine', 300, 900, 0.12, 0.1); },
#   block: () => { osc('square', 700, 380, 0.08, 0.3); nz(0.1, 0.4, 3000, 1500, 2, 'bandpass'); osc('sine', 120, 70, 0.12, 0.5); },
#   parry: () => { osc('triangle', 1500, 2400, 0.25, 0.4); osc('sine', 3000, 3000, 0.4, 0.25, null, null, 0.03); nz(0.12, 0.35, 5000, 3000, 3, 'bandpass'); osc('sine', 100, 60, 0.2, 0.6); },
#   guardbreak: () => { osc('sawtooth', 320, 40, 0.5, 0.5); nz(0.4, 0.7, 5000, 400, 0.7, 'bandpass', 0, true); osc('sine', 80, 30, 0.5, 1.0); },
#   jump: () => { nz(0.14, 0.15, 500, 1500, 1, 'bandpass'); },
#   land: () => { osc('sine', 90, 40, 0.15, 0.5); nz(0.1, 0.25, 600, 200, 0.7, 'lowpass'); },
#   charge: () => { osc('sawtooth', 80, 700, 1.1, 0.2); osc('sine', 160, 1400, 1.1, 0.3); nz(1.1, 0.25, 400, 5000, 1.5, 'bandpass', 0, true); },
#   blue: () => { osc('sine', 880, 220, 0.9, 0.35); osc('triangle', 440, 110, 1.1, 0.3); nz(1.2, 0.25, 3500, 500, 3, 'bandpass', 0, true); osc('sine', 60, 60, 1.2, 0.5); },
#   red: () => { osc('sine', 140, 24, 0.9, 1.3); nz(0.6, 0.9, 3000, 90, 0.6, 'bandpass', 0, true); osc('sawtooth', 700, 80, 0.35, 0.4); osc('sine', 1760, 440, 0.2, 0.3); },
#   purple: () => { osc('sine', 55, 30, 1.6, 1.4); osc('sawtooth', 110, 220, 1.2, 0.3); nz(1.3, 0.8, 800, 4500, 0.7, 'bandpass', 0, true); osc('square', 220, 330, 1.0, 0.18); osc('sine', 1320, 1320, 1.2, 0.2); },
#   shadow: () => { nz(0.5, 0.35, 900, 120, 1.2, 'lowpass', 0, true); osc('sine', 220, 55, 0.5, 0.35); },
#   summon: () => { osc('sawtooth', 70, 200, 0.7, 0.28); nz(0.7, 0.4, 300, 2200, 1.5, 'bandpass', 0, true); osc('sine', 50, 50, 0.7, 0.6); },
#   bite: () => { nz(0.1, 0.5, 2500, 800, 2, 'bandpass'); osc('square', 300, 100, 0.08, 0.2); },
#   hurt: () => { osc('sawtooth', 240, 60, 0.25, 0.4); nz(0.15, 0.4, 1200, 300, 1, 'bandpass'); },
#   break: () => { nz(0.35, 0.8, 2200, 150, 0.6, 'bandpass', 0, true); osc('sine', 100, 40, 0.25, 0.7); },
#   domain: () => { osc('sine', 40, 28, 2.4, 1.3); osc('sawtooth', 55, 110, 2.2, 0.3); nz(2.2, 0.7, 200, 3000, 1.4, 'bandpass', 0, true); for (let i = 0; i < 5; i++) osc('sine', 220 * Math.pow(1.5, i % 3), 220 * Math.pow(1.5, i % 3), 1.4, 0.18, null, null, 0.2 + i * 0.28); },
#   domainhit: () => { osc('sine', 150, 40, 0.2, 0.8); nz(0.1, 0.55, 3500, 500, 1, 'bandpass'); },
#   ult: () => { osc('sine', 50, 25, 1.8, 1.3); nz(1.6, 0.8, 300, 5000, 1, 'bandpass', 0, true); osc('sawtooth', 100, 800, 1.2, 0.25); },
#   ready: () => { osc('sine', 660, 990, 0.18, 0.25); osc('sine', 990, 1320, 0.2, 0.2, null, null, 0.1); },
#   ui: () => osc('triangle', 600, 900, 0.07, 0.2),
#   win: () => { [523, 659, 784, 1046].forEach((f, i) => osc('triangle', f, f, 0.5, 0.25, null, null, i * 0.12)); },
#   lose: () => { [392, 330, 262, 196].forEach((f, i) => osc('sawtooth', f, f * 0.98, 0.6, 0.18, null, null, i * 0.2)); },
#   step: () => nz(0.05, 0.1, 400, 200, 1, 'lowpass')
# };
# G3.sfx = function (name) { if (!AU.ctx || !AU.on) return; const f = SFX[name]; if (f) try { f(); } catch (e) { } };
# G3.mute = (m) => { AU.on = !m; if (AU.master) AU.master.gain.value = m ? 0 : AU.vol; };
# 
# // ---- adaptive music: 16-step sequencer, moods ----
# const MOODS = {
#   calm: { bpm: 84, root: 55, scale: [0, 3, 7, 10, 12, 15], bass: [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0], arp: [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0], kick: 0, drone: 1 },
#   battle: { bpm: 142, root: 49, scale: [0, 3, 5, 7, 10, 12], bass: [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0], arp: [1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1], kick: 1, drone: 1 },
#   boss: { bpm: 160, root: 46, scale: [0, 1, 5, 7, 8, 12], bass: [1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0], arp: [1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1], kick: 2, drone: 1 },
#   domain: { bpm: 70, root: 41, scale: [0, 7, 12, 15, 19, 24], bass: [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], arp: [1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0], kick: 0, drone: 2 }
# };
# G3.music = function (mood) { if (AU.mood === mood) return; AU.mood = mood; AU.step = 0; AU.musTimer = 0; if (AU.drone) { try { AU.drone.stop(); } catch (e) { } AU.drone = null; } if (mood && AU.ctx) startDrone(mood); };
# function startDrone(mood) {
#   const M = MOODS[mood]; if (!M) return; const ctx = AU.ctx, g = ctx.createGain(); g.gain.value = 0.0001; g.gain.exponentialRampToValueAtTime(0.16 * M.drone, ctx.currentTime + 2.0);
#   const o1 = ctx.createOscillator(), o2 = ctx.createOscillator(); o1.type = 'sawtooth'; o2.type = 'sine'; o1.frequency.value = M.root; o2.frequency.value = M.root * 1.5;
#   const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 340; o1.connect(f); o2.connect(g); f.connect(g); g.connect(AU.mus); o1.start(); o2.start();
#   AU.drone = { stop() { g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.8); o1.stop(ctx.currentTime + 1); o2.stop(ctx.currentTime + 1); } };
# }
# function updateMusic(dt) {
#   if (!AU.ctx || !AU.mood || !AU.on) return; const M = MOODS[AU.mood]; if (!M) return;
#   const spb = 60 / M.bpm / 4; AU.musTimer += dt;
#   while (AU.musTimer >= spb) {
#     AU.musTimer -= spb; const s = AU.step % 16, bar = (AU.step >> 4) % 4, ctx = AU.ctx, t = ctx.currentTime;
#     const rootShift = [0, 0, -2, 3][bar], f0 = M.root * Math.pow(2, rootShift / 12);
#     if (M.bass[s]) osc('sawtooth', f0, f0 * 0.98, spb * 1.6, 0.18, t, AU.mus);
#     if (M.arp[s]) { const n = M.scale[(s * 3 + bar * 2) % M.scale.length]; osc(AU.mood === 'domain' ? 'sine' : 'square', f0 * 4 * Math.pow(2, n / 12), null, spb * 1.4, AU.mood === 'domain' ? 0.12 : 0.05, t, AU.mus); }
#     if (M.kick && s % 4 === 0) osc('sine', 130, 40, 0.18, 0.5 * (M.kick === 2 ? 1.1 : 0.9), t, AU.mus);
#     if (M.kick && s % 8 === 4) { const sn = ctx.createBufferSource(), ng = ctx.createGain(), nf = ctx.createBiquadFilter(); sn.buffer = AU.noise; nf.type = 'highpass'; nf.frequency.value = 1800; ng.gain.setValueAtTime(0.16, t); ng.gain.exponentialRampToValueAtTime(0.001, t + 0.14); sn.connect(nf); nf.connect(ng); ng.connect(AU.mus); sn.start(t, Math.random()); sn.stop(t + 0.16); }
#     if (M.kick === 2 && s % 2 === 1) { const sn = ctx.createBufferSource(), ng = ctx.createGain(), nf = ctx.createBiquadFilter(); sn.buffer = AU.noise; nf.type = 'highpass'; nf.frequency.value = 7000; ng.gain.setValueAtTime(0.05, t); ng.gain.exponentialRampToValueAtTime(0.001, t + 0.04); sn.connect(nf); nf.connect(ng); ng.connect(AU.mus); sn.start(t, Math.random()); sn.stop(t + 0.05); }
#     AU.step++;
#   }
# }
# // ---------------------------------------------------------------------
# // Anime HUD, menus, banners, speed-line overlay
# // ---------------------------------------------------------------------
# const HUD_CSS = `
# #g3hud{position:fixed;inset:0;pointer-events:none;font-family:'Segoe UI',system-ui,sans-serif;color:#e8ecff;z-index:20;user-select:none;display:none}
# #g3hud *{box-sizing:border-box}
# .g3-port{position:absolute;left:22px;bottom:22px;display:flex;gap:12px;align-items:flex-end}
# .g3-face{width:92px;height:92px;clip-path:polygon(12% 0,100% 0,88% 100%,0 100%);background:linear-gradient(135deg,var(--c1),var(--c2));display:flex;align-items:center;justify-content:center;font-weight:900;font-size:44px;color:#fff;text-shadow:0 0 18px var(--c1);border:0;position:relative}
# .g3-face:after{content:'';position:absolute;inset:3px;clip-path:polygon(12% 0,100% 0,88% 100%,0 100%);background:#0a0d1e;z-index:-1}
# .g3-face{filter:drop-shadow(0 0 10px var(--c1))}
# .g3-bars{width:340px;display:flex;flex-direction:column;gap:6px}
# .g3-name{font-weight:800;letter-spacing:.18em;font-size:13px;text-transform:uppercase;color:var(--c1);text-shadow:0 0 10px var(--c1)}
# .g3-bar{height:14px;background:rgba(8,10,24,.78);border:1px solid rgba(160,180,255,.28);transform:skewX(-18deg);position:relative;overflow:hidden}
# .g3-bar i{position:absolute;inset:0;width:100%;transform-origin:left;transition:transform .09s linear}
# .g3-bar b{position:absolute;inset:0;width:100%;transform-origin:left;opacity:.45;transition:transform .7s ease .25s;background:#fff}
# .g3-hp i{background:linear-gradient(90deg,#ff3b5c,#ff7a8a)}
# .g3-ce i{background:linear-gradient(90deg,var(--c2),var(--c1))}
# .g3-ult{height:8px}
# .g3-ult i{background:linear-gradient(90deg,#ffd35a,#fff3b0)}
# .g3-ult.full{box-shadow:0 0 14px #ffd35a;animation:g3pulse .6s infinite alternate}
# .g3-lbl{font-size:10px;letter-spacing:.2em;opacity:.7;margin-top:-2px}
# .g3-skills{position:absolute;right:26px;bottom:24px;display:flex;gap:10px}
# .g3-sk{width:70px;height:70px;background:rgba(8,10,24,.8);border:1px solid rgba(160,180,255,.35);clip-path:polygon(14% 0,100% 0,86% 100%,0 100%);position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:11px;letter-spacing:.06em;font-weight:700}
# .g3-sk .k{font-size:20px;font-weight:900;color:var(--c1)}
# .g3-sk .cd{position:absolute;left:0;right:0;bottom:0;background:rgba(0,0,0,.72);height:0}
# .g3-sk.rdy{box-shadow:inset 0 0 18px var(--c1);border-color:var(--c1)}
# .g3-sk.low{opacity:.5}
# .g3-combo{position:absolute;right:48px;top:30%;text-align:right;font-weight:900;font-style:italic;transition:transform .08s}
# .g3-combo .n{font-size:84px;line-height:.9;color:#fff;text-shadow:0 0 22px var(--c1),4px 4px 0 var(--c2)}
# .g3-combo .t{font-size:16px;letter-spacing:.35em;color:var(--c1)}
# .g3-combo .r{font-size:22px;letter-spacing:.2em;color:#ffd35a;text-shadow:0 0 12px #ffa010}
# .g3-boss{position:absolute;top:26px;left:50%;transform:translateX(-50%);width:min(720px,70vw);display:none}
# .g3-boss .g3-name{text-align:center;color:#ff8aa0;text-shadow:0 0 12px #ff3050}
# .g3-boss .g3-bar{height:18px}
# .g3-boss .g3-hp i{background:linear-gradient(90deg,#8a2cff,#ff3050)}
# .g3-msg{position:absolute;left:50%;top:22%;transform:translateX(-50%);font-weight:900;font-style:italic;font-size:46px;letter-spacing:.08em;white-space:nowrap;opacity:0;text-shadow:0 0 24px currentColor,3px 3px 0 #000}
# .g3-msg.on{animation:g3msg .9s ease-out}
# .g3-ban{position:fixed;inset:0;display:none;align-items:center;justify-content:center;flex-direction:column;z-index:30;pointer-events:none}
# .g3-ban .a{font-size:min(10vw,110px);font-weight:900;font-style:italic;letter-spacing:.05em;color:#fff;text-shadow:0 0 40px var(--bc),0 0 8px var(--bc),6px 6px 0 rgba(0,0,0,.6);transform:skewX(-10deg)}
# .g3-ban .b{font-size:min(3vw,28px);letter-spacing:.5em;color:var(--bc);text-transform:uppercase;margin-top:10px;text-shadow:0 0 14px var(--bc)}
# .g3-ban.on{display:flex;animation:g3ban var(--bd,2s) ease-out forwards}
# .g3-bar-t,.g3-bar-b{position:fixed;left:0;right:0;height:0;background:#000;z-index:25;pointer-events:none}
# .g3-bar-t{top:0}.g3-bar-b{bottom:0}
# #g3speed{position:fixed;inset:0;z-index:19;pointer-events:none;display:none}
# .g3-hint{position:absolute;left:50%;top:8px;transform:translateX(-50%);font-size:11px;letter-spacing:.14em;opacity:.55;white-space:nowrap}
# .g3-enemies{position:absolute;left:22px;top:34px;font-size:12px;letter-spacing:.2em;opacity:.85}
# .g3-mode{position:absolute;left:22px;top:56px;font-size:11px;letter-spacing:.2em;color:var(--c1)}
# .g3-cross{position:absolute;left:50%;top:50%;width:6px;height:6px;margin:-3px;border-radius:50%;background:rgba(255,255,255,.45)}
# #g3menu{position:fixed;inset:0;z-index:40;background:radial-gradient(ellipse at 50% 30%,rgba(30,20,70,.88),rgba(4,4,12,.96));display:none;flex-direction:column;align-items:center;justify-content:center;font-family:'Segoe UI',system-ui,sans-serif;color:#e8ecff;overflow:auto}
# #g3menu h1{font-size:min(9vw,84px);margin:0;font-weight:900;font-style:italic;letter-spacing:.08em;background:linear-gradient(90deg,#6ab4ff,#b070ff,#ff4a6a);-webkit-background-clip:text;color:transparent;filter:drop-shadow(0 0 24px rgba(150,100,255,.6))}
# #g3menu .sub{letter-spacing:.5em;font-size:12px;opacity:.7;margin:6px 0 26px;text-transform:uppercase}
# .g3-row{display:flex;gap:16px;flex-wrap:wrap;justify-content:center;margin:8px 16px}
# .g3-card{pointer-events:auto;cursor:pointer;width:230px;padding:16px;background:rgba(10,12,30,.8);border:1px solid rgba(160,180,255,.25);transition:all .15s;position:relative;clip-path:polygon(0 0,94% 0,100% 8%,100% 100%,6% 100%,0 92%)}
# .g3-card:hover,.g3-card.sel{border-color:var(--c1);box-shadow:0 0 28px -4px var(--c1),inset 0 0 30px -12px var(--c1);transform:translateY(-3px)}
# .g3-card .nm{font-size:22px;font-weight:900;letter-spacing:.12em;color:var(--c1);text-shadow:0 0 12px var(--c1)}
# .g3-card .ty{font-size:11px;letter-spacing:.25em;opacity:.65;margin:2px 0 8px}
# .g3-card ul{margin:6px 0 0;padding:0 0 0 0;list-style:none;font-size:12px;line-height:1.6;opacity:.9}
# .g3-card li b{color:var(--c1);display:inline-block;width:20px}
# .g3-btn{pointer-events:auto;cursor:pointer;padding:10px 26px;margin:4px;background:rgba(10,12,30,.8);border:1px solid rgba(160,180,255,.3);letter-spacing:.2em;font-weight:700;font-size:13px;color:#e8ecff;transform:skewX(-12deg);transition:all .12s}
# .g3-btn:hover,.g3-btn.sel{background:linear-gradient(90deg,#4a7aff,#a050ff);border-color:#fff;box-shadow:0 0 20px #7a60ff}
# .g3-start{font-size:20px;padding:14px 56px;margin-top:20px;background:linear-gradient(90deg,#4a7aff,#a050ff);border-color:#fff}
# .g3-lab{letter-spacing:.35em;font-size:11px;opacity:.6;margin:14px 0 2px;text-transform:uppercase}
# #g3pause{position:fixed;inset:0;z-index:35;background:rgba(3,4,12,.72);display:none;flex-direction:column;align-items:center;justify-content:center;color:#e8ecff;font-family:'Segoe UI',system-ui,sans-serif}
# #g3pause h2{font-size:48px;letter-spacing:.3em;margin:0 0 20px;font-style:italic}
# #g3end{position:fixed;inset:0;z-index:36;display:none;flex-direction:column;align-items:center;justify-content:center;background:rgba(3,4,12,.78);color:#fff;font-family:'Segoe UI',system-ui,sans-serif}
# #g3end h2{font-size:min(10vw,96px);margin:0;font-style:italic;font-weight:900;letter-spacing:.08em;text-shadow:0 0 30px currentColor}
# @keyframes g3pulse{from{filter:brightness(1)}to{filter:brightness(1.6)}}
# @keyframes g3msg{0%{opacity:0;transform:translateX(-50%) scale(1.8) skewX(-10deg)}12%{opacity:1;transform:translateX(-50%) scale(1) skewX(-10deg)}75%{opacity:1}100%{opacity:0;transform:translateX(-50%) scale(1.05) skewX(-10deg)}}
# @keyframes g3ban{0%{opacity:0;transform:scale(1.4)}8%{opacity:1;transform:scale(1)}80%{opacity:1}100%{opacity:0;transform:scale(1.04)}}
# `;
# const H = {};
# const CHARS = [
#   { id: 'haru', name: 'HARU', ty: 'Limitless · Six-Eyed Sorcerer', c1: '#5ab4ff', c2: '#8a5cff', l: 'H', sk: [['E', 'Blue'], ['X', 'Red'], ['R', 'Purple'], ['G', 'Domain']], desc: ['<b>E</b>Blue — pulls enemies into a point', '<b>X</b>Red — explosive repulsion', '<b>R</b>Hollow Purple — world-tearing beam', '<b>G</b>Boundless Expanse domain'] },
#   { id: 'kage', name: 'KAGE', ty: 'Shadow Technique', c1: '#b070ff', c2: '#4a1a90', l: 'K', sk: [['E', 'Shadow Step'], ['X', 'Hounds'], ['R', 'Shadow Storm'], ['G', 'Domain']], desc: ['<b>E</b>Shadow Step — teleport behind target', '<b>X</b>Summon shadow hounds', '<b>R</b>Legion — mass summon + spears', '<b>G</b>Hollow Garden domain'] },
#   { id: 'akai', name: 'AKAI', ty: 'Blood & Black Lightning', c1: '#ff3a4a', c2: '#ff9a40', l: 'A', sk: [['E', 'Crimson Dash'], ['X', 'Red Bolt'], ['R', 'Meteor Rain'], ['G', 'Domain']], desc: ['<b>E</b>Crimson Dash — lightning rush strike', '<b>X</b>Red Bolt — piercing lightning', '<b>R</b>Meteor Rain — falling blasts', '<b>G</b>Crimson Colosseum domain'] }
# ];
# const MODES = [['Training', 'Infinite dummy · no limits'], ['Survival', 'Endless waves'], ['Boss', 'Fight the Calamity'], ['Arena', '1v1 duel vs rival sorcerer']];
# G3.CHARS = CHARS; G3.MODES = MODES;
# G3.pick = { char: 0, mode: 0, done: false };
# G3.hudInit = function () {
#   const st = document.createElement('style'); st.textContent = HUD_CSS; document.head.appendChild(st);
#   const hud = document.createElement('div'); hud.id = 'g3hud';
#   hud.innerHTML = `<div class="g3-cross"></div><div class="g3-enemies" id="g3en"></div><div class="g3-mode" id="g3mode"></div>
# <div class="g3-boss" id="g3boss"><div class="g3-name" id="g3bn"></div><div class="g3-bar g3-hp"><b id="g3bhg"></b><i id="g3bh"></i></div></div>
# <div class="g3-combo" id="g3combo" style="display:none"><div class="n" id="g3cn">0</div><div class="t">HITS</div><div class="r" id="g3cr"></div></div>
# <div class="g3-msg" id="g3msg"></div>
# <div class="g3-port"><div class="g3-face" id="g3face">H</div><div class="g3-bars"><div class="g3-name" id="g3nm">HARU</div><div class="g3-bar g3-hp"><b id="g3hg"></b><i id="g3h"></i></div><div class="g3-bar g3-ce"><i id="g3c"></i></div><div class="g3-bar g3-ult" id="g3ub"><i id="g3u"></i></div><div class="g3-lbl">HP · CURSED ENERGY · ULTIMATE</div></div></div>
# <div class="g3-skills" id="g3sk"></div>
# <div class="g3-hint">WASD move · MOUSE camera · LMB light · RMB heavy · Q dash · F block · SPACE jump · SHIFT sprint · E / X / R skills · G domain · ESC pause</div>`;
#   document.body.appendChild(hud);
#   const ban = document.createElement('div'); ban.className = 'g3-ban'; ban.id = 'g3ban'; ban.innerHTML = '<div class="a" id="g3ba"></div><div class="b" id="g3bb"></div>'; document.body.appendChild(ban);
#   const bt = document.createElement('div'); bt.className = 'g3-bar-t'; bt.id = 'g3bt'; document.body.appendChild(bt); const bb = document.createElement('div'); bb.className = 'g3-bar-b'; bb.id = 'g3bb2'; document.body.appendChild(bb);
#   const sp = document.createElement('canvas'); sp.id = 'g3speed'; document.body.appendChild(sp); H.sp = sp; H.spx = sp.getContext('2d');
#   const menu = document.createElement('div'); menu.id = 'g3menu'; document.body.appendChild(menu);
#   const pause = document.createElement('div'); pause.id = 'g3pause'; pause.innerHTML = '<h2>PAUSED</h2><div class="g3-btn" id="g3resume">RESUME</div><div class="g3-btn" id="g3q">GRAPHICS: HIGH</div><div class="g3-btn" id="g3vol">SOUND: ON</div><div class="g3-btn" id="g3menuBtn">MAIN MENU</div>'; document.body.appendChild(pause);
#   const end = document.createElement('div'); end.id = 'g3end'; end.innerHTML = '<h2 id="g3et"></h2><div id="g3es" style="letter-spacing:.3em;opacity:.8;margin:10px 0 24px"></div><div class="g3-btn" id="g3again">PLAY AGAIN</div><div class="g3-btn" id="g3menu2">MAIN MENU</div>'; document.body.appendChild(end);
#   for (const k of ['en', 'mode', 'boss', 'bn', 'bh', 'bhg', 'combo', 'cn', 'cr', 'msg', 'face', 'nm', 'h', 'hg', 'c', 'u', 'ub', 'sk', 'ban', 'ba', 'bb', 'bt', 'bb2']) H[k] = document.getElementById('g3' + k);
#   H.hud = hud; H.menu = menu; H.pause = pause; H.end = end; H.skills = [];
#   const qn = ['LOW', 'MEDIUM', 'HIGH'];
#   document.getElementById('g3resume').onclick = () => { G3.paused = false; pause.style.display = 'none'; G3.lock(); };
#   document.getElementById('g3q').onclick = (e) => { G3.setQuality((S.quality + 1) % 3); e.target.textContent = 'GRAPHICS: ' + qn[S.quality]; };
#   document.getElementById('g3vol').onclick = (e) => { const m = AU.on; G3.mute(m); e.target.textContent = 'SOUND: ' + (m ? 'OFF' : 'ON'); };
#   document.getElementById('g3menuBtn').onclick = () => { G3.toMenu(); };
#   document.getElementById('g3menu2').onclick = () => { G3.toMenu(); };
#   document.getElementById('g3again').onclick = () => { end.style.display = 'none'; G3.pick.done = true; G3.pick.restart = (G3.pick.restart || 0) + 1; G3.lock(); };
#   document.addEventListener('pointerlockchange', () => { if (!document.pointerLockElement && S.started && !G3.ended && !G3.inMenu) { G3.paused = true; pause.style.display = 'flex'; } });
#   H.last = {};
# };
# function setTheme(c) { H.hud.style.setProperty('--c1', c.c1); H.hud.style.setProperty('--c2', c.c2); H.ban && H.ban.style.setProperty('--bc', c.c1); }
# G3.setChar = function (i) {
#   const c = CHARS[i]; setTheme(c); H.face.textContent = c.l; H.nm.textContent = c.name;
#   H.sk.innerHTML = c.sk.map((s) => `<div class="g3-sk"><div class="k">${s[0]}</div><div>${s[1]}</div><div class="cd"></div></div>`).join('');
#   H.skills = Array.from(H.sk.children);
# };
# // Volt-facing menu API ----------------------------------------------------
# G3.toMenu = function () {
#   H.end.style.display = 'none'; H.pause.style.display = 'none'; H.hud.style.display = 'none'; G3.inMenu = true; G3.ended = false; G3.paused = false; S.started = false; S.cinemaMenu = true;
#   if (document.pointerLockElement) document.exitPointerLock();
#   G3.domainActive() && G3.domainOff(true);
#   G3.pick.done = false; G3.pick.toMenu = (G3.pick.toMenu || 0) + 1; buildMenu();
# };
# function buildMenu() {
#   const m = H.menu; m.style.display = 'flex'; const p = G3.pick;
#   m.innerHTML = `<h1>CURSED ARENA</h1><div class="sub">a 3D anime action fighter · built in Volt</div>
# <div class="g3-lab">Choose your sorcerer</div><div class="g3-row" id="g3chars">${CHARS.map((c, i) => `<div class="g3-card ${i === p.char ? 'sel' : ''}" data-i="${i}" style="--c1:${c.c1};--c2:${c.c2}"><div class="nm">${c.name}</div><div class="ty">${c.ty}</div><ul>${c.desc.map((d) => '<li>' + d + '</li>').join('')}</ul></div>`).join('')}</div>
# <div class="g3-lab">Mode</div><div class="g3-row" id="g3modes">${MODES.map((mo, i) => `<div class="g3-btn ${i === p.mode ? 'sel' : ''}" data-i="${i}" title="${mo[1]}">${mo[0].toUpperCase()}</div>`).join('')}</div>
# <div class="g3-lab">Graphics</div><div class="g3-row" id="g3gfx">${['LOW', 'MEDIUM', 'HIGH'].map((q, i) => `<div class="g3-btn ${i === S.quality ? 'sel' : ''}" data-i="${i}">${q}</div>`).join('')}</div>
# <div class="g3-btn g3-start" id="g3go">ENTER THE ARENA</div><div class="g3-lab" style="margin-top:18px">WASD · Mouse · LMB/RMB · Q dash · F block · E / X / R skills · G domain · Space · Shift</div>`;
#   const sel = (id, fn) => m.querySelectorAll('#' + id + ' [data-i]').forEach((el) => el.onclick = () => { fn(+el.dataset.i); m.querySelectorAll('#' + id + ' [data-i]').forEach((e2) => e2.classList.toggle('sel', e2 === el)); G3.sfx('ui'); });
#   sel('g3chars', (i) => { p.char = i; setTheme(CHARS[i]); }); sel('g3modes', (i) => { p.mode = i; }); sel('g3gfx', (i) => { G3.setQuality(i); });
#   setTheme(CHARS[p.char]);
#   document.getElementById('g3go').onclick = () => { auInit(); G3.sfx('ready'); m.style.display = 'none'; H.hud.style.display = 'block'; G3.inMenu = false; S.cinemaMenu = false; G3.setChar(p.char); S.started = true; G3.lock(); p.done = true; };
# }
# G3.menuDone = () => (G3.pick.done ? 1 : 0);
# G3.menuChar = () => G3.pick.char; G3.menuMode = () => G3.pick.mode;
# G3.ackMenu = () => { G3.pick.done = false; };
# G3.restartCount = () => G3.pick.restart || 0;
# G3.menuCount = () => G3.pick.toMenu || 0;
# // HUD updates -------------------------------------------------------------
# function hset(el, k, v, f) { if (H.last[k] !== v) { H.last[k] = v; f(el, v); } }
# G3.hud = function (hp, hpMax, ce, ceMax, ult, combo, eCd, xCd, rCd, gCd, ceCostOk) {
#   const sc = (e, v) => (e.style.transform = 'scaleX(' + clamp(v, 0, 1).toFixed(3) + ')');
#   hset(H.h, 'hp', Math.round(hp / hpMax * 400), (e) => sc(e, hp / hpMax)); hset(H.hg, 'hpg', Math.round(hp / hpMax * 400), (e) => sc(e, hp / hpMax));
#   hset(H.c, 'ce', Math.round(ce / ceMax * 400), (e) => sc(e, ce / ceMax)); hset(H.u, 'ult', Math.round(ult), (e) => { sc(e, ult / 100); H.ub.classList.toggle('full', ult >= 100); });
#   const cds = [eCd, xCd, rCd, gCd], ceN = [20, 28, 55, 0];
#   H.skills.forEach((el, i) => { const cd = cds[i] || 0, k = 'sk' + i, ready = cd <= 0 && (i === 2 ? ult >= 50 : i === 3 ? ult >= 100 : ce >= ceN[i]); hset(el, k, Math.round(cd * 10) + (ready ? 'r' : 'n'), (e) => { e.classList.toggle('rdy', ready); e.classList.toggle('low', !ready && cd <= 0); e.querySelector('.cd').style.height = (cd > 0 ? 100 : 0) + '%'; }); });
#   hset(H.combo, 'cb', combo, (e) => {
#     if (combo >= 2) { e.style.display = 'block'; H.cn.textContent = combo; H.cr.textContent = combo >= 30 ? 'SS' : combo >= 20 ? 'S' : combo >= 12 ? 'A' : combo >= 7 ? 'B' : combo >= 4 ? 'C' : ''; e.style.transform = 'scale(1.18)'; setTimeout(() => (e.style.transform = 'scale(1)'), 70); } else e.style.display = 'none';
#   });
# };
# G3.hudInfo = function (enemies, modeText) { hset(H.en, 'en', enemies + modeText, (e) => { e.textContent = enemies >= 0 ? 'ENEMIES ' + enemies : ''; }); hset(H.mode, 'md', modeText, (e) => { e.textContent = modeText; }); };
# G3.hudBoss = function (show, name, hp, hpMax) {
#   hset(H.boss, 'bs', show ? 1 : 0, (e) => { e.style.display = show ? 'block' : 'none'; }); if (!show) return;
#   hset(H.bn, 'bn', name, (e) => { e.textContent = name; });
#   const sc = (e, v) => (e.style.transform = 'scaleX(' + clamp(v, 0, 1).toFixed(3) + ')'); hset(H.bh, 'bh', Math.round(hp / hpMax * 500), (e) => sc(e, hp / hpMax)); hset(H.bhg, 'bhg', Math.round(hp / hpMax * 500), (e) => sc(e, hp / hpMax));
# };
# let msgTimer = 0;
# G3.msg = function (text, hex) { const e = H.msg; e.textContent = text; e.style.color = '#' + (hex == null ? 0xffffff : hex).toString(16).padStart(6, '0'); e.classList.remove('on'); void e.offsetWidth; e.classList.add('on'); };
# G3.banner = function (title, sub, hex, ms) {
#   const b = H.ban; H.ba.textContent = title; H.bb.textContent = sub; b.style.setProperty('--bc', '#' + hex.toString(16).padStart(6, '0')); b.style.setProperty('--bd', (ms / 1000) + 's'); b.classList.remove('on'); void b.offsetWidth; b.classList.add('on');
# };
# G3.endScreen = function (win, sub) {
#   G3.ended = true; if (document.pointerLockElement) document.exitPointerLock(); const e = H.end; e.style.display = 'flex'; const t = document.getElementById('g3et'); t.textContent = win ? 'VICTORY' : 'DEFEATED'; t.style.color = win ? '#ffd35a' : '#ff3b5c'; document.getElementById('g3es').textContent = sub || ''; G3.sfx(win ? 'win' : 'lose');
# };
# G3.clearEnd = function () { G3.ended = false; H.end.style.display = 'none'; };
# G3.isPaused = () => (G3.paused ? 1 : 0);
# // speed lines -------------------------------------------------------------
# let speedT = 0, speedMax = 1, speedCol = '255,255,255';
# G3.speedLines = function (ms, rgb) { speedT = ms / 1000; speedMax = speedT; speedCol = rgb || '255,255,255'; };
# function drawSpeed(rdt) {
#   const cv = H.sp; if (!cv) return; if (speedT <= 0) { if (cv.style.display !== 'none') cv.style.display = 'none'; return; }
#   speedT -= rdt; cv.style.display = 'block'; const w = (cv.width = window.innerWidth >> 1), h = (cv.height = window.innerHeight >> 1), g = H.spx, a = clamp(speedT / speedMax, 0, 1);
#   g.clearRect(0, 0, w, h); const cx = w / 2, cy = h / 2, R = Math.hypot(cx, cy);
#   for (let i = 0; i < 90; i++) { const an = rand(0, TAU), r0 = R * rand(0.35, 0.8), r1 = R * rand(0.9, 1.2), wd = rand(0.004, 0.02); g.fillStyle = 'rgba(' + speedCol + ',' + (rand(0.25, 0.8) * a) + ')'; g.beginPath(); g.moveTo(cx + Math.cos(an - wd) * r1, cy + Math.sin(an - wd) * r1); g.lineTo(cx + Math.cos(an + wd) * r1, cy + Math.sin(an + wd) * r1); g.lineTo(cx + Math.cos(an) * r0, cy + Math.sin(an) * r0); g.fill(); }
# }
# // floating damage numbers
# const _dn = [];
# G3.dmgNum = function (x, y, z, val, hex, big) {
#   if (!camera || !H.hud || H.hud.style.display === 'none') return;
#   const v = new THREE.Vector3(x, y, z).project(camera); if (v.z > 1) return;
#   let e = _dn.find((d) => !d.busy); if (!e) { e = { el: document.createElement('div') }; e.el.style.cssText = 'position:fixed;z-index:21;pointer-events:none;font:900 italic 26px Segoe UI,system-ui,sans-serif;text-shadow:0 0 10px currentColor,2px 2px 0 #000;transition:transform .7s cubic-bezier(.1,.8,.3,1),opacity .7s;will-change:transform'; document.body.appendChild(e.el); _dn.push(e); }
#   e.busy = true; const el = e.el; el.textContent = Math.round(val); el.style.color = '#' + (hex == null ? 0xffffff : hex).toString(16).padStart(6, '0'); el.style.fontSize = (big ? 44 : 24 + Math.min(14, val * 0.25)) + 'px';
#   el.style.transition = 'none'; el.style.opacity = 1; const sx = (v.x * 0.5 + 0.5) * window.innerWidth + rand(-20, 20), sy = (-v.y * 0.5 + 0.5) * window.innerHeight; el.style.left = sx + 'px'; el.style.top = sy + 'px'; el.style.transform = 'translate(-50%,-50%) scale(1.5)'; void el.offsetWidth;
#   el.style.transition = 'transform .7s cubic-bezier(.1,.8,.3,1),opacity .7s'; el.style.transform = 'translate(-50%,-' + (60 + rand(0, 30)) + 'px) scale(1)'; el.style.opacity = 0; setTimeout(() => { e.busy = false; }, 720);
# };
# // ---------------------------------------------------------------------
# // Frame loop + boot
# // ---------------------------------------------------------------------
# G3.frame = function (rdt) {
#   S.t += rdt;
#   if (S.hs > 0) S.hs -= rdt; else if (S.slowT > 0) S.slowT -= rdt;
#   const paused = G3.paused || G3.inMenu && false;
#   const ts = G3.timeScale(), dt = paused ? 0 : rdt * ts;
#   UT.value += dt;
#   if (G3.inMenu) { S.yaw += rdt * 0.12; S.pitch = 0.2; S.dist = 12; G3.camTarget(0, 1.2, 0); }
#   updateRigs(dt); updateAuras(dt); updateParticles(dt); updateDebris(dt); updateDecals(dt); updateFx(dt); updateMap(dt); updateDomain(dt); updateMusic(rdt);
#   for (const p of pointPool) { const u = p.userData; if (u.life > 0) { u.life -= dt; const k = Math.max(0, u.life / u.max); p.intensity = u.i0 * 40 * k * k; } else p.intensity = 0; }
#   updateCamera(rdt);
#   // screen-space effects
#   S.ab *= Math.exp(-9 * rdt); S.warp *= Math.exp(-7 * rdt); S.flash *= Math.exp(-5 * rdt); S.tint = damp(S.tint, S.tintTo, 3, rdt);
#   if (S.invT > 0) { S.invT -= rdt; S.inv = 1; } else S.inv = 0;
#   S.bars = damp(S.bars, S.barsTo, 5, rdt);
#   if (fxPass) {
#     const u = fxPass.uniforms; u.uAb.value = S.ab; u.uWarp.value = S.warp; u.uCenter.value.set(S.warpC.x, S.warpC.y); u.uInv.value = S.inv; u.uFlash.value = S.flash; u.uVig.value = S.vig;
#     u.uTintA.value = S.tint; u.uTint.value.setRGB(S.tintColor[0], S.tintColor[1], S.tintColor[2]);
#   }
#   if (H.bt) { const h = (S.bars * 11).toFixed(2) + 'vh'; H.bt.style.height = h; H.bb2.style.height = h; }
#   drawSpeed(rdt);
#   if (composer) composer.render(); else renderer.render(scene, camera);
#   S.frames = (S.frames || 0) + 1;
# };
# G3.boot = async function () {
#   const ok = await G3.load();
#   if (!ok) { document.body.insertAdjacentHTML('beforeend', '<div style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:#05050a;color:#fff;font:16px sans-serif;text-align:center;z-index:99">Could not load Three.js from the CDN.<br>This game needs an internet connection.</div>'); return 0; }
#   const css = document.createElement('style'); css.textContent = 'html,body{margin:0;background:#05050a;overflow:hidden}canvas#cv,canvas:not(#g3speed):not([data-g3]){}#world3d{position:fixed;inset:0;z-index:0}#world3d canvas{display:block;width:100%;height:100%}'; document.head.appendChild(css);
#   G3.init(); initFxSystems(); G3.buildMap('crossroads'); G3.hudInit(); G3.toMenu();
#   let last = performance.now();
#   const loop = (now) => { requestAnimationFrame(loop); const rdt = Math.min(0.05, (now - last) / 1000); last = now; try { G3.frame(rdt); } catch (e) { if (!G3.errShown) { G3.errShown = 1; console.error('frame error', e); } } };
#   requestAnimationFrame(loop); window.__G3 = G3; G3.booted = true; return 1;
# };
# G3.ready = () => (G3.booted ? 1 : 0);
# })();
# const G3 = window.G3;

// =====================================================================
// CURSED ARENA - gameplay layer, written in Volt.
// Everything that decides how the game plays lives here: movement,
// combos, Black Flash, perfect dodge, parry, abilities, enemy AI,
// bosses, domain expansions, modes. The 3D engine above only draws.
// =====================================================================

Foe = type { kind: int, rig: int, x: float, z: float, y: float, vx: float, vz: float, vy: float, yaw: float, hp: float, hpMax: float, state: string, stT: float, atkCd: float, stun: float, flash: float, dodgeCd: float, slot: float, phase: int, hitDone: bool, comboN: int, airHits: int, speed: float, reach: float, dmg: float, name: string, rushTag: int, blockT: float, armor: float, aux: float, dead: bool, sx: float, sz: float, tx: float, tz: float, atkId: int, lastHit: float }
Hound = type { rig: int, x: float, z: float, yaw: float, life: float, biteCd: float, big: bool }
Shot = type { x: float, y: float, z: float, vx: float, vz: float, life: float, dmg: float, hex: int, t: float }
Blast = type { x: float, z: float, t: float, r: float, dmg: float, kind: int }

// ---- player state ----
let gstate = "menu"
let ch = 0
let mode = 0
let prig = 0
let px = 0.0
let pz = 0.0
let py = 0.0
let pvx = 0.0
let pvz = 0.0
let pvy = 0.0
let pyaw = 0.0
let php = 200.0
let phpMax = 200.0
let pce = 100.0
let pceMax = 100.0
let pult = 0.0
let pstate = "free"
let pst = 0.0
let pdur = 0.4
let pstp = 0
let pbuf = 0
let phit = false
let plast = 9.0
let pcombo = 0
let pcombot = 0.0
let pinv = 0.0
let pdash = 0.0
let pblock = 0.0
let pparry = 0.0
let pflow = 0.0
let pbf = 0.0
let pamb = 0.0
let pairN = 0
let pcdE = 0.0
let pcdX = 0.0
let pcdG = 0.0
let pgnd = true
let pjumpL = false
let pbfNext = false
let pdodge = 0.0
let pfoot = 0.0
let rushId = 0
let rushDx = 0.0
let rushDz = 0.0
let castKind = 0
let castFired = false
let pbfBuf = 0.0
let pbufT = 0.0
let rbuf = 0.0
let pcdDash = 0.0

// ---- abilities in flight ----
let blueT = 0.0
let blueX = 0.0
let blueZ = 0.0
let legionT = 0.0

// ---- domain ----
let domPhase = 0
let domT = 0.0
let domKind = 0
let domN = 0
let domNextT = 0.0
let domSaveX = 0.0
let domSaveZ = 0.0

// ---- input flags ----
let kQ = false
let kE = false
let kX = false
let kR = false
let kG = false
let kT = false
let kY = false
let kB = false
let kK = false

// ---- world ----
let foes = []
let hounds = []
let shots = []
let blasts = []
let engineReady = false
let wave = 0
let waveWait = 0.0
let score = 0
let modeText = ""
let overT = 0.0
let tickN = 0
let lastMusic = ""

// ---------------------------------------------------------------------
// Tiny raw-JS math helpers (Volt's own dist/sqrt round down)
// ---------------------------------------------------------------------
fn ang(x, z) {
  # return Math.atan2(x, z) * 180 / Math.PI
}
fn dst(ax, az, bx, bz) {
  # return Math.hypot(ax - bx, az - bz)
}
fn adiff(a, b) {
  # return ((b - a + 540) % 360) - 180
}
fn rnd(a, b) {
  # return a + Math.random() * (b - a)
}
fn cpx(x, z, r) {
  # if (G3.domainActive()) { const c = G3.domainCenter(); const dx = x - c.x, dz = z - c.z, d = Math.hypot(dx, dz), m = 30 - r; return d > m ? c.x + dx / d * m : x; }
  # return G3.clampPos(x, z, r).x
}
fn cpz(x, z, r) {
  # if (G3.domainActive()) { const c = G3.domainCenter(); const dx = x - c.x, dz = z - c.z, d = Math.hypot(dx, dz), m = 30 - r; return d > m ? c.z + dz / d * m : z; }
  # return G3.clampPos(x, z, r).z
}
fn inArena(x, z) {
  # return (G3.domainActive() || G3.inArena(x, z)) ? 1 : 0
}

// ---------------------------------------------------------------------
// Thin wrappers over the engine (Volt can't call methods directly)
// ---------------------------------------------------------------------
fn fxHit(x, y, z, pw, s) {
  # G3.hit(x, y, z, pw, s)
}
fn fxCrit(x, y, z, s) {
  # G3.crit(x, y, z, s)
}
fn fxBlackFlash(x, y, z) {
  # G3.blackFlash(x, y, z)
}
fn fxGuardBreak(x, y, z, s) {
  # G3.guardBreak(x, y, z, s)
}
fn fxParry(x, y, z) {
  # G3.parry(x, y, z)
}
fn fxBlock(x, y, z) {
  # G3.blockSpark(x, y, z)
}
fn fxDash(x, z, dx, dz, s) {
  # G3.dashTrail(x, z, dx, dz, s)
}
fn fxDust(x, z, n) {
  # G3.footDust(x, z, n)
}
fn fxLand(x, z, pw) {
  # G3.land(x, z, pw)
}
fn fxDeath(x, y, z, s) {
  # G3.death(x, y, z, s)
}
fn fxDmg(x, y, z, v, hex, big) {
  # G3.dmgNum(x, y, z, v, hex, big)
}
fn fxSlash(x, y, z, yaw, tilt, reach, s, dur, sweep, flip) {
  # G3.slash(x, y, z, yaw, tilt, reach, s, dur, sweep, flip)
}
fn sfx(n) {
  # G3.sfx(n)
}
fn shake(a, ms) {
  # G3.shake(a, ms)
}
fn hitstop(ms) {
  # G3.hitstop(ms)
}
fn slowmo(pw, ms) {
  # G3.slowmo(pw, ms)
}
fn fovKick(d) {
  # G3.fovKick(d)
}
fn flashScreen(a) {
  # G3.flashScreen(a)
}
fn speedLines(ms, rgb) {
  # G3.speedLines(ms, rgb)
}
fn msg(t, hex) {
  # G3.msg(t, hex)
}
fn banner(t, s, hex, ms) {
  # G3.banner(t, s, hex, ms)
}
fn bars(flag) {
  # G3.bars(flag)
}
fn rigNew(kind, look) {
  # return G3.rigNew(kind, look)
}
fn rigDel(rid) {
  # G3.rigDel(rid)
}
fn rigSet(rid, x, y, z, yaw) {
  # G3.rigSet(rid, x, y, z, yaw)
}
fn rigPlay(rid, anim, dur, lp) {
  # G3.rigPlay(rid, anim, dur, lp)
}
fn rigRun(rid, s) {
  # G3.rigRun(rid, s)
}
fn rigFlash(rid, v) {
  # G3.rigFlash(rid, v)
}
fn rigScale(rid, s) {
  # G3.rigScale(rid, s)
}
fn rigVis(rid, v) {
  # G3.rigVis(rid, v)
}
fn rigAuraStyle(rid, s) {
  # G3.rigAuraStyle(rid, s)
}
fn aura(rid, lvl) {
  # G3.aura(rid, lvl)
}
fn auraBurst(rid, pw) {
  # G3.auraBurst(rid, pw)
}
fn trail(rid, s) {
  # G3.trail(rid, s)
}
fn partX(rid, what) {
  # return G3.rigPart(rid, what).x
}
fn partY(rid, what) {
  # return G3.rigPart(rid, what).y
}
fn partZ(rid, what) {
  # return G3.rigPart(rid, what).z
}
fn timeScale() {
  # return G3.timeScale()
}
fn camYaw() {
  # return G3.camYawDeg()
}
fn camTarget(x, y, z) {
  # G3.camTarget(x, y, z)
}
fn camDist(d) {
  # G3.camDist(d)
}
fn takeLook() {
  # G3.takeLook()
}
fn click0() {
  # return G3.takeClick(0)
}
fn click1() {
  # return G3.takeClick(1)
}
fn held1() {
  # return G3.heldBtn(1) ? 1 : 0
}
fn cineEnd() {
  # G3.cineEnd()
}
fn cinePush(x, y, z, dur, a, rad, h) {
  # G3.cinePush(x, y, z, dur, a, rad, h)
}
fn cineOrbit(x, y, z, dur, a0, a1, rad, h) {
  # G3.cineOrbit(x, y, z, dur, a0, a1, rad, h)
}
fn cineLow(x, y, z, dur, a0, a1, rad) {
  # G3.cineLow(x, y, z, dur, a0, a1, rad)
}
fn pointFlash(x, y, z, hex, pw, life) {
  # G3.pointFlash(x, y, z, hex, pw, life)
}
fn invert(ms) {
  # G3.invert(ms)
}
fn aberr(a) {
  # G3.aberr(a)
}
fn ringFx(x, y, z, r, hex, dur) {
  # G3.ring(x, y, z, r, hex, dur, 0.3, null, 2.2)
}
fn sparks(x, y, z, n, sp, hex) {
  # G3.sparkBurst(x, y, z, n, sp, hex, 0.5)
}
fn debrisFx(x, z, n, pw) {
  # G3.debris(x, 0.3, z, n, pw, 0x3a3a46, 0.2)
}
fn hitProps(x, z, r, d) {
  # G3.hitProps(x, z, r, d)
}
fn orbFx(x, y, z, hex, size) {
  # G3.orbFx(x, y, z, hex, size)
}
fn telegraph(x, z, r, sec, hex) {
  # G3.telegraph(x, z, r, sec, hex)
}
fn music(m) {
  # G3.music(m)
}
fn hudDraw(a, b, c, d, e, f, g, h, i, j) {
  # G3.hud(a, b, c, d, e, f, g, h, i, j, 0)
}
fn hudInfo(n, t) {
  # G3.hudInfo(n, t)
}
fn hudBoss(vis, nm, hp, hpMax) {
  # G3.hudBoss(vis, nm, hp, hpMax)
}
fn endScreen(win, t) {
  # G3.endScreen(win, t)
}
fn menuDone() {
  # return G3.menuDone()
}
fn menuChar() {
  # return G3.menuChar()
}
fn menuMode() {
  # return G3.menuMode()
}
fn ackMenu() {
  # G3.ackMenu()
}
fn inMenuNow() {
  # return G3.inMenu ? 1 : 0
}
fn isPaused() {
  # return G3.isPaused()
}
fn setChar(i) {
  # G3.setChar(i)
}
fn clearEnd() {
  # G3.clearEnd()
}
fn domainOn(k, x, z) {
  # G3.domainOn(k, x, z)
}
fn domainOff() {
  # G3.domainOff()
}
fn domainQuiet() {
  # G3.domainOff(true)
}
fn shadowIn(x, z) {
  # G3.shadowIn(x, z)
}
fn shadowOut(x, z) {
  # G3.shadowOut(x, z)
}
fn summonFx(x, z, big) {
  # G3.summon(x, z, big)
}
fn shadowSpike(x, z, h) {
  # G3.shadowSpike(x, z, h)
}
fn shadowPool(x, z, r, d) {
  # G3.shadowPool(x, z, r, d)
}
fn blueFx(x, y, z, d, r) {
  # G3.blue(x, y, z, d, r)
}
fn redFx(x, y, z, r) {
  # G3.red(x, y, z, r)
}
fn purpleCharge(rid, d) {
  # G3.purpleCharge(rid, d)
}
fn purpleFx(x, y, z, yaw, ln, d) {
  # G3.purple(x, y, z, yaw, ln, d)
}
fn lightningLine(x1, y1, z1, x2, y2, z2, n) {
  # G3.lightningLine(x1, y1, z1, x2, y2, z2, n)
}
fn meteorFall(x, z, d) {
  # G3.meteorFall(x, z, d)
}
fn crimsonBlast(x, z, r) {
  # G3.crimsonBlast(x, z, r)
}
fn arcCloud(x, y, z, r, n, hex) {
  # G3.arcCloud(x, y, z, r, n, hex)
}
fn camSetYaw(d) {
  # G3.camSetYawDeg(d)
}
fn domainActive() {
  # return G3.domainActive() ? 1 : 0
}
fn guardFx() {
  # return 0
}
fn domainStrike(k, x, y, z, n) {
  # G3.domainStrike(k, x, y, z, n)
}
fn domainSure(k, x, y, z) {
  # G3.domainSure(k, x, y, z)
}
fn bootEngine() {
  # return G3.boot()
}
fn dmgColor(kind) {
  if kind == 3 {
    return 16717880
  }
  if kind == 2 {
    return 11163135
  }
  if kind == 1 {
    return 16764762
  }
  return 16777215
}
fn styleOf() {
  if ch == 0 {
    return "haru"
  }
  if ch == 1 {
    return "kage"
  }
  return "akai"
}
fn lookOf() {
  if ch == 0 {
    return "haru"
  }
  if ch == 1 {
    return "kage"
  }
  return "akai"
}

// ---------------------------------------------------------------------
// Enemy stats
// ---------------------------------------------------------------------
fn kHP(k) {
  if k == 0 {
    return 42.0
  }
  if k == 1 {
    return 62.0
  }
  if k == 2 {
    return 36.0
  }
  if k == 3 {
    return 950.0
  }
  if k == 4 {
    return 340.0
  }
  return 99999.0
}
fn kSpeed(k) {
  if k == 0 {
    return 4.4
  }
  if k == 1 {
    return 7.4
  }
  if k == 2 {
    return 4.0
  }
  if k == 3 {
    return 4.2
  }
  if k == 4 {
    return 6.2
  }
  return 0.0
}
fn kReach(k) {
  if k == 0 {
    return 2.1
  }
  if k == 1 {
    return 2.3
  }
  if k == 3 {
    return 4.8
  }
  if k == 4 {
    return 2.5
  }
  return 0.0
}
fn kDmg(k) {
  if k == 0 {
    return 11.0
  }
  if k == 1 {
    return 9.0
  }
  if k == 2 {
    return 10.0
  }
  if k == 3 {
    return 24.0
  }
  if k == 4 {
    return 9.0
  }
  return 0.0
}
fn kName(k) {
  if k == 0 {
    return "Cursed Spirit"
  }
  if k == 1 {
    return "Fang Curse"
  }
  if k == 2 {
    return "Hex Caster"
  }
  if k == 3 {
    return "THE CALAMITY"
  }
  if k == 4 {
    return "RIVAL SORCERER"
  }
  return "Training Dummy"
}
fn kLook(k) {
  if k == 1 {
    return "fang"
  }
  if k == 2 {
    return "caster"
  }
  if k == 3 {
    return "boss"
  }
  if k == 4 {
    if ch == 2 {
      return "kage"
    }
    return "akai"
  }
  return "grunt"
}

fn spawnFoe(k, x, z) {
  let rid = rigNew("human", kLook(k))
  let arm = 0.0
  if k == 3 {
    arm = 1.0
  }
  let f = Foe { kind: k, rig: rid, x: x, z: z, y: 0.0, vx: 0.0, vz: 0.0, vy: 0.0, yaw: 0.0, hp: kHP(k), hpMax: kHP(k), state: "chase", stT: 0.0, atkCd: rnd(1.0, 2.2), stun: 0.0, flash: 0.0, dodgeCd: 0.0, slot: rnd(0.0, 360.0), phase: 1, hitDone: false, comboN: 0, airHits: 0, speed: kSpeed(k), reach: kReach(k), dmg: kDmg(k), name: kName(k), rushTag: 0, blockT: 0.0, armor: arm, aux: 0.0, dead: false, sx: x, sz: z, tx: 0.0, tz: 0.0, atkId: 0, lastHit: 9.0 }
  if k == 5 {
    f.state = "dummy"
  }
  add f to foes
  rigSet(rid, x, 0.0, z, 0.0)
  if k == 4 {
    aura(rid, 0.5)
  }
  if k == 3 {
    shadowIn(x, z)
    shake(0.8, 500)
  } else {
    if k != 5 {
      shadowIn(x, z)
    }
  }
  return length(foes) - 1
}

fn aliveCount() {
  let n = 0
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].kind != 5 {
      n += 1
    }
    i += 1
  }
  return n
}

fn nearestFoe(maxd) {
  let best = -1
  let bd = maxd
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" {
      let d = dst(px, pz, foes[i].x, foes[i].z)
      if d < bd {
        bd = d
        best = i
      }
    }
    i += 1
  }
  return best
}

// ---------------------------------------------------------------------
// Damage to enemies. kind: 0 light, 1 heavy, 2 special, 3 black flash
// ---------------------------------------------------------------------
fn killFoe(i) {
  if foes[i].kind == 5 {
    foes[i].hp = foes[i].hpMax
    return 0
  }
  foes[i].dead = true
  foes[i].state = "dead"
  foes[i].stT = 1.1
  foes[i].hp = 0.0
  rigPlay(foes[i].rig, "down", 1.0, true)
  fxDeath(foes[i].x, foes[i].y + 1.2, foes[i].z, styleOf())
  score += 1
  pult = min(100.0, pult + 7.0)
  pce = min(pceMax, pce + 10.0)
  if foes[i].kind == 3 or foes[i].kind == 4 {
    slowmo(18, 1400)
    shake(1.2, 600)
    flashScreen(0.4)
    fxBlackFlash(foes[i].x, foes[i].y + 1.5, foes[i].z)
  }
  sfx("heavy")
}

fn hurtFoe(i, dmg, dx, dz, kb, lift, kind) {
  if foes[i].dead {
    return 0
  }
  if foes[i].state == "dodge" or foes[i].state == "roar" or foes[i].state == "leapair" and kind < 2 {
    return 0
  }
  let d = dmg
  let hy = foes[i].y + 1.2
  if foes[i].kind == 3 {
    hy = foes[i].y + 2.3
  }
  let hx = foes[i].x
  let hz = foes[i].z
  let k = kind
  let lf = lift
  let kbk = kb
  // blocking rival
  if foes[i].state == "block" and kind < 2 {
    fxBlock(hx, hy, hz)
    sfx("block")
    foes[i].hp -= d * 0.12
    foes[i].vx += dx * 2.0
    foes[i].vz += dz * 2.0
    pcombo = pcombo
    return 0
  }
  if foes[i].state == "block" and kind == 1 {
    foes[i].state = "stun"
    foes[i].stT = 1.6
    fxGuardBreak(hx, hy, hz, styleOf())
    sfx("guardbreak")
    msg("GUARD BREAK", 16764762)
    d = d * 1.3
  }
  if pamb > 0 and kind < 2 {
    d = d * 1.6
    pamb = 0.0
    msg("AMBUSH", 11163135)
  }
  if kind == 3 {
    d = d * 3.5
  }
  foes[i].hp -= d
  foes[i].flash = 1.0
  foes[i].lastHit = 0.0
  rigFlash(foes[i].rig, 1.0)
  pcombo += 1
  pcombot = 2.4
  if kind == 0 {
    pult = min(100.0, pult + 1.6)
    pce = min(pceMax, pce + 1.4)
  } else {
    pult = min(100.0, pult + 3.5)
  }
  // armoured foes shrug off light stuff
  if foes[i].armor > 0.0 {
    kbk = kbk * 0.2
    if kind < 2 {
      lf = 0.0
    }
  }
  // power of impact visuals
  let pw = 1
  if kind == 1 {
    pw = 3
  }
  if kind == 2 {
    pw = 3
  }
  if kind == 3 {
    fxBlackFlash(hx, hy, hz)
    pbf = 6.0
    pult = min(100.0, pult + 12.0)
    pce = min(pceMax, pce + 25.0)
    aura(prig, 1.6)
    auraBurst(prig, 0.8)
    msg("BLACK FLASH", 16717880)
    speedLines(420, "255,40,60")
    kbk = kbk + 8.0
    if foes[i].armor <= 0.0 {
      lf = max(lf, 6.0)
    }
  } else {
    if kind == 1 and pcombo > 0 and foes[i].hp > 0 and rnd(0.0, 1.0) < 0.0 {
      fxCrit(hx, hy, hz, styleOf())
    } else {
      fxHit(hx, hy, hz, pw, styleOf())
    }
  }
  fxDmg(hx, hy + 0.6, hz, d, dmgColor(kind), kind == 3)
  if kind == 0 {
    sfx("hit")
  } else {
    if kind == 3 {
      sfx("crit")
    } else {
      sfx("heavy")
    }
  }
  if foes[i].hp <= 0.0 {
    killFoe(i)
    if foes[i].kind != 5 {
      foes[i].vx = dx * (kbk + 6.0)
      foes[i].vz = dz * (kbk + 6.0)
      foes[i].vy = 5.0
    }
    return d
  }
  // reactions
  if foes[i].kind == 5 {
    foes[i].vx = dx * kbk * 0.3
    foes[i].vz = dz * kbk * 0.3
    if lf > 0.0 {
      foes[i].vy = lf * 0.8
      foes[i].state = "air"
    } else {
      rigPlay(foes[i].rig, "hit", 0.3, false)
    }
    return d
  }
  if lf > 0.0 or (kind >= 2 and kbk > 12.0 and foes[i].armor <= 0.0) {
    let dec = 1.0 - foes[i].airHits * 0.13
    if dec < 0.45 {
      dec = 0.45
    }
    foes[i].vy = max(lf, 4.5) * dec
    foes[i].airHits += 1
    foes[i].vx = dx * kbk
    foes[i].vz = dz * kbk
    foes[i].state = "air"
  } else {
    if foes[i].armor > 0.0 and kind < 2 {
      foes[i].vx += dx * kbk
      foes[i].vz += dz * kbk
    } else {
      foes[i].state = "hit"
      foes[i].stT = 0.34
      if kind >= 1 {
        foes[i].stT = 0.55
      }
      foes[i].vx = dx * kbk
      foes[i].vz = dz * kbk
      rigPlay(foes[i].rig, "hit", 0.3, false)
    }
  }
  return d
}

// quiet damage over time (Blue's crush, domain strikes use hurtFoe)
fn dotFoe(i, dmg) {
  if foes[i].dead or foes[i].kind == 5 {
    return 0
  }
  foes[i].hp -= dmg
  foes[i].flash = 0.4
  if foes[i].hp <= 0.0 {
    killFoe(i)
  }
}

// ---------------------------------------------------------------------
// Damage to the player
// ---------------------------------------------------------------------
fn gameOver(win) {
  gstate = "over"
  overT = 0.0
  bars(false)
  cineEnd()
  if win {
    endScreen(true, "Foes defeated: " + text(score))
  } else {
    endScreen(false, "Foes defeated: " + text(score))
  }
}

fn perfectDodge() {
  pdodge = 0.0
  pflow = 3.5
  slowmo(22, 1100)
  msg("PERFECT DODGE", 8349951)
  pce = min(pceMax, pce + 18.0)
  pult = min(100.0, pult + 10.0)
  aura(prig, 1.5)
  auraBurst(prig, 0.7)
  aberr(0.012)
  speedLines(380, "140,230,255")
  sfx("parry")
}

fn hurtPlayer(dmg, ax, az, kind, idx) {
  if domPhase > 0 {
    return 0
  }
  if pdodge > 0.0 {
    perfectDodge()
    return 0
  }
  if pinv > 0.0 {
    return 0
  }
  if gstate != "play" {
    return 0
  }
  let dx = px - ax
  let dz = pz - az
  let dd = dst(0.0, 0.0, dx, dz)
  if dd < 0.01 {
    dd = 1.0
    dx = 0.0
    dz = 1.0
  }
  dx = dx / dd
  dz = dz / dd
  if pstate == "block" and kind < 3 {
    if pblock < 0.22 {
      // perfect parry
      fxParry(px + dx * -0.6, py + 1.3, pz + dz * -0.6)
      msg("PARRY", 11463935)
      sfx("parry")
      slowmo(30, 380)
      pparry = 1.1
      pce = min(pceMax, pce + 12.0)
      pult = min(100.0, pult + 7.0)
      if idx >= 0 {
        foes[idx].state = "stun"
        foes[idx].stT = 1.5
        foes[idx].vx = dx * -5.0
        foes[idx].vz = dz * -5.0
      }
      return 0
    }
    php -= dmg * 0.15
    pvx += dx * 6.0
    pvz += dz * 6.0
    fxBlock(px + dx * -0.6, py + 1.3, pz + dz * -0.6)
    sfx("block")
    if kind == 1 {
      pstate = "hit"
      pst = 0.0
      pdur = 0.6
      rigPlay(prig, "stun", 0.6, true)
      fxGuardBreak(px, py + 1.3, pz, "curse")
      shake(0.7, 260)
      php -= dmg * 0.5
    }
    if php <= 0.0 {
      php = 0.0
      gameOver(false)
    }
    return 0
  }
  php -= dmg
  pult = min(100.0, pult + dmg * 0.35)
  pcombo = 0
  pvx += dx * 9.0
  pvz += dz * 9.0
  if pstate != "ult" and pstate != "cast" and pstate != "domain" and pstate != "slam" {
    pstate = "hit"
    pst = 0.0
    pdur = 0.32
    if kind == 1 {
      pdur = 0.55
      pvy = 7.0
      pvx += dx * 6.0
      pvz += dz * 6.0
    }
    rigPlay(prig, "hit", 0.32, false)
  }
  pinv = 0.35
  fxHit(px, py + 1.2, pz, 2, "curse")
  fxDmg(px, py + 2.2, pz, dmg, 16729156, false)
  sfx("hurt")
  shake(0.55, 220)
  aberr(0.006)
  if php <= 0.0 {
    php = 0.0
    slowmo(15, 1400)
    fxDeath(px, py + 1.2, pz, styleOf())
    gameOver(false)
  }
}

// ---------------------------------------------------------------------
// Enemy AI
// ---------------------------------------------------------------------
fn shootAt(x, z, tx, tz, speed, dmg, hex) {
  let dx = tx - x
  let dz = tz - z
  let d = dst(0.0, 0.0, dx, dz)
  if d < 0.1 {
    d = 1.0
  }
  add Shot { x: x, y: 1.5, z: z, vx: dx / d * speed, vz: dz / d * speed, life: 3.0, dmg: dmg, hex: hex, t: 0.0 } to shots
}

fn foeReact() {
  // rivals and fangs try to dodge or block when you start swinging
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state == "chase" and foes[i].dodgeCd <= 0.0 {
      let k = foes[i].kind
      if k == 1 or k == 4 {
        let d = dst(px, pz, foes[i].x, foes[i].z)
        if d < 4.4 {
          let r = rnd(0.0, 1.0)
          if k == 4 and r < 0.38 {
            foes[i].state = "block"
            foes[i].stT = 0.7
            foes[i].dodgeCd = 2.2
            rigPlay(foes[i].rig, "block", 0.3, false)
          } else {
            if r < 0.5 {
              let a = ang(px - foes[i].x, pz - foes[i].z) + 90.0
              if rnd(0.0, 1.0) < 0.5 {
                a = a + 180.0
              }
              foes[i].vx = sin(a) * 15.0
              foes[i].vz = cos(a) * 15.0
              foes[i].state = "dodge"
              foes[i].stT = 0.28
              foes[i].dodgeCd = 2.6
              fxDash(foes[i].x, foes[i].z, sin(a), cos(a), "curse")
            }
          }
        }
      }
    }
    i += 1
  }
}

fn foeStrike(i) {
  let k = foes[i].kind
  let fx = sin(foes[i].yaw)
  let fz = cos(foes[i].yaw)
  let d = dst(px, pz, foes[i].x, foes[i].z)
  let rg = foes[i].reach
  let ad = abs(adiff(foes[i].yaw, ang(px - foes[i].x, pz - foes[i].z)))
  if k == 0 or k == 4 {
    fxSlash(foes[i].x + fx * 0.5, 1.1, foes[i].z + fz * 0.5, foes[i].yaw, rnd(-30.0, 30.0), 2.6, "curse", 0.2, 140.0, foes[i].comboN % 2 == 1)
    sfx("swing")
    if d < rg + 0.7 and ad < 70.0 and py < 1.6 {
      hurtPlayer(foes[i].dmg, foes[i].x, foes[i].z, 0, i)
    }
    if k == 4 and foes[i].comboN < 2 {
      foes[i].comboN += 1
      foes[i].state = "windup"
      foes[i].stT = 0.26
      foes[i].yaw = ang(px - foes[i].x, pz - foes[i].z)
      rigPlay(foes[i].rig, "light" + text(foes[i].comboN + 1), 0.3, false)
      foes[i].vx = fx * 6.0
      foes[i].vz = fz * 6.0
      return 0
    }
    if k == 0 and foes[i].comboN < 1 and rnd(0.0, 1.0) < 0.45 {
      foes[i].comboN += 1
      foes[i].state = "windup"
      foes[i].stT = 0.36
      rigPlay(foes[i].rig, "light2", 0.36, false)
      return 0
    }
    foes[i].comboN = 0
    foes[i].state = "recover"
    foes[i].stT = 0.6
    foes[i].atkCd = rnd(1.2, 2.3)
    return 0
  }
  if k == 1 {
    foes[i].vx = fx * 15.0
    foes[i].vz = fz * 15.0
    sfx("bite")
    fxSlash(foes[i].x + fx * 0.6, 1.0, foes[i].z + fz * 0.6, foes[i].yaw, 20.0, 2.4, "curse", 0.18, 120.0, false)
    if d < rg + 1.4 and ad < 80.0 and py < 1.6 {
      hurtPlayer(foes[i].dmg, foes[i].x, foes[i].z, 0, i)
    }
    foes[i].state = "recover"
    foes[i].stT = 0.5
    foes[i].atkCd = rnd(0.9, 1.7)
    return 0
  }
  if k == 2 {
    shootAt(foes[i].x, foes[i].z, px, pz, 13.0, foes[i].dmg, 11163135)
    sfx("charge")
    foes[i].state = "recover"
    foes[i].stT = 0.6
    foes[i].atkCd = rnd(2.2, 3.2)
    return 0
  }
  if k == 3 {
    let a = foes[i].atkId
    if a == 0 {
      // heavy swing
      fxSlash(foes[i].x + fx * 1.2, 2.0, foes[i].z + fz * 1.2, foes[i].yaw, rnd(-40.0, 40.0), 5.6, "curse", 0.28, 170.0, false)
      sfx("swing2")
      shake(0.45, 200)
      if d < rg + 0.8 and ad < 85.0 and py < 2.4 {
        hurtPlayer(foes[i].dmg, foes[i].x, foes[i].z, 0, i)
      }
      hitProps(foes[i].x + fx * 3.0, foes[i].z + fz * 3.0, 3.0, 20.0)
    }
    if a == 1 {
      // ground slam shockwave
      fxLand(foes[i].x, foes[i].z, 4.0)
      ringFx(foes[i].x, 0.1, foes[i].z, 8.0, 11163135, 0.6)
      debrisFx(foes[i].x, foes[i].z, 24, 9.0)
      shake(1.0, 380)
      sfx("heavy")
      hitProps(foes[i].x, foes[i].z, 6.0, 40.0)
      if d < 6.0 and py < 1.3 {
        hurtPlayer(foes[i].dmg + 6.0, foes[i].x, foes[i].z, 1, i)
      }
    }
    if a == 2 {
      // orb volley
      let n = 0
      while n < 5 {
        let ba = ang(px - foes[i].x, pz - foes[i].z) + (n - 2) * 14.0
        shootAt(foes[i].x, foes[i].z, foes[i].x + sin(ba) * 10.0, foes[i].z + cos(ba) * 10.0, 12.0, 11.0, 16717880)
        n += 1
      }
      sfx("charge")
      shake(0.5, 220)
    }
    if a == 3 {
      // leap
      foes[i].state = "leapair"
      foes[i].vy = 17.0
      let lx = foes[i].tx - foes[i].x
      let lz = foes[i].tz - foes[i].z
      foes[i].vx = lx * 0.95
      foes[i].vz = lz * 0.95
      sfx("swing2")
      return 0
    }
    foes[i].state = "recover"
    foes[i].stT = 0.8
    foes[i].atkCd = rnd(1.1, 2.0)
    if foes[i].phase == 2 {
      foes[i].atkCd = rnd(0.6, 1.3)
    }
    return 0
  }
  foes[i].state = "recover"
  foes[i].stT = 0.5
}

fn foeBeginAttack(i) {
  let k = foes[i].kind
  foes[i].yaw = ang(px - foes[i].x, pz - foes[i].z)
  foes[i].state = "windup"
  foes[i].comboN = 0
  foes[i].vx = 0.0
  foes[i].vz = 0.0
  if k == 0 {
    foes[i].stT = 0.55
    rigPlay(foes[i].rig, "swipe", 0.55, false)
    rigFlash(foes[i].rig, 0.5)
  }
  if k == 1 {
    foes[i].stT = 0.34
    rigPlay(foes[i].rig, "light1", 0.34, false)
    rigFlash(foes[i].rig, 0.5)
  }
  if k == 2 {
    foes[i].stT = 0.75
    rigPlay(foes[i].rig, "cast", 0.75, true)
    orbFx(foes[i].x, 1.6, foes[i].z, 11163135, 1.4)
  }
  if k == 4 {
    foes[i].stT = 0.3
    rigPlay(foes[i].rig, "light1", 0.3, false)
    rigFlash(foes[i].rig, 0.4)
  }
  if k == 3 {
    let d = dst(px, pz, foes[i].x, foes[i].z)
    let r = rnd(0.0, 1.0)
    let a = 0
    if d < 6.5 {
      if r < 0.55 {
        a = 0
      } else {
        a = 1
      }
    } else {
      a = 3
      if foes[i].phase == 2 and r < 0.5 {
        a = 2
      }
      if foes[i].phase == 1 and r < 0.4 {
        a = 2
        if d < 9.0 {
          a = 0
        }
      }
    }
    if a == 2 and foes[i].phase == 1 and r < 0.2 {
      a = 1
    }
    foes[i].atkId = a
    if a == 0 {
      foes[i].stT = 0.8
      rigPlay(foes[i].rig, "light3", 0.8, false)
    }
    if a == 1 {
      foes[i].stT = 1.15
      rigPlay(foes[i].rig, "airslam", 1.15, false)
      telegraph(foes[i].x, foes[i].z, 6.0, 1.15, 16729156)
    }
    if a == 2 {
      foes[i].stT = 0.95
      rigPlay(foes[i].rig, "charge", 0.95, true)
      orbFx(foes[i].x, 3.5, foes[i].z, 16717880, 2.2)
    }
    if a == 3 {
      foes[i].stT = 0.9
      foes[i].tx = px
      foes[i].tz = pz
      rigPlay(foes[i].rig, "teleport", 0.9, false)
      telegraph(px, pz, 5.5, 0.9, 16729156)
    }
    rigFlash(foes[i].rig, 0.6)
    sfx("charge")
  }
}

fn foeTick(i, dt) {
  foes[i].stT -= dt
  foes[i].atkCd -= dt
  foes[i].dodgeCd -= dt
  foes[i].lastHit += dt
  let k = foes[i].kind
  let st = foes[i].state
  if st == "trapped" {
    rigPlay(foes[i].rig, "stun", 1.0, true)
    rigSet(foes[i].rig, foes[i].x, foes[i].y, foes[i].z, foes[i].yaw)
    return 0
  }
  // physics ------------------------------------------------------------
  if foes[i].y > 0.0 or foes[i].vy > 0.0 {
    foes[i].vy -= 30.0 * dt
    foes[i].y += foes[i].vy * dt
    if foes[i].y <= 0.0 {
      foes[i].y = 0.0
      let hard = foes[i].vy
      foes[i].vy = 0.0
      if st == "air" {
        foes[i].state = "down"
        foes[i].stT = 0.9
        foes[i].airHits = 0
        st = "down"
        fxLand(foes[i].x, foes[i].z, 1.0 + abs(hard) * 0.1)
        if abs(hard) > 12.0 {
          fxHit(foes[i].x, 0.5, foes[i].z, 2, styleOf())
        }
      }
      if st == "leapair" {
        foes[i].state = "recover"
        foes[i].stT = 0.9
        foes[i].atkCd = 1.2
        st = "recover"
        fxLand(foes[i].x, foes[i].z, 4.0)
        ringFx(foes[i].x, 0.1, foes[i].z, 8.0, 11163135, 0.6)
        debrisFx(foes[i].x, foes[i].z, 26, 10.0)
        shake(1.1, 400)
        sfx("heavy")
        hitProps(foes[i].x, foes[i].z, 6.0, 40.0)
        if dst(px, pz, foes[i].x, foes[i].z) < 5.8 and py < 1.3 {
          hurtPlayer(foes[i].dmg + 8.0, foes[i].x, foes[i].z, 1, i)
        }
      }
      if st == "dead" {
        foes[i].vx *= 0.5
        foes[i].vz *= 0.5
      }
    }
  }
  foes[i].x += foes[i].vx * dt
  foes[i].z += foes[i].vz * dt
  let fr = 1.0 - 5.5 * dt
  if fr < 0.0 {
    fr = 0.0
  }
  if st != "air" and st != "leapair" {
    foes[i].vx *= fr
    foes[i].vz *= fr
  } else {
    foes[i].vx *= 1.0 - 0.6 * dt
    foes[i].vz *= 1.0 - 0.6 * dt
  }
  let ox = foes[i].x
  let oz = foes[i].z
  foes[i].x = cpx(ox, oz, 0.7)
  foes[i].z = cpz(ox, oz, 0.7)
  if foes[i].x != ox or foes[i].z != oz {
    foes[i].vx *= 0.3
    foes[i].vz *= 0.3
  }
  // state machine ------------------------------------------------------
  if st == "dead" {
    rigPlay(foes[i].rig, "down", 1.0, true)
  }
  if st == "air" {
    rigPlay(foes[i].rig, "ragdoll", 1.0, true)
  }
  if st == "leapair" {
    foes[i].yaw = ang(foes[i].vx, foes[i].vz)
  }
  if st == "hit" and foes[i].stT <= 0.0 {
    foes[i].state = "chase"
  }
  if st == "down" {
    rigPlay(foes[i].rig, "down", 1.0, true)
    if foes[i].stT <= 0.0 {
      foes[i].state = "getup"
      foes[i].stT = 0.5
      rigPlay(foes[i].rig, "getup", 0.5, false)
    }
  }
  if st == "getup" and foes[i].stT <= 0.0 {
    foes[i].state = "chase"
  }
  if st == "stun" {
    rigPlay(foes[i].rig, "stun", 1.0, true)
    if foes[i].stT <= 0.0 {
      foes[i].state = "chase"
    }
  }
  if st == "block" and foes[i].stT <= 0.0 {
    foes[i].state = "chase"
  }
  if st == "dodge" and foes[i].stT <= 0.0 {
    foes[i].state = "chase"
  }
  if st == "roar" {
    rigPlay(foes[i].rig, "ult", 0.8, true)
    if foes[i].stT <= 0.0 {
      foes[i].state = "chase"
      foes[i].atkCd = 0.6
    }
  }
  if st == "recover" and foes[i].stT <= 0.0 {
    foes[i].state = "chase"
  }
  if st == "windup" {
    foes[i].yaw += adiff(foes[i].yaw, ang(px - foes[i].x, pz - foes[i].z)) * min(1.0, 7.0 * dt)
    if foes[i].stT <= 0.0 {
      foeStrike(i)
    }
  }
  if foes[i].state == "chase" {
    let dx = px - foes[i].x
    let dz = pz - foes[i].z
    let d = dst(px, pz, foes[i].x, foes[i].z)
    let want = ang(dx, dz)
    foes[i].yaw += adiff(foes[i].yaw, want) * min(1.0, 10.0 * dt)
    let sp = foes[i].speed
    let mx = 0.0
    let mz = 0.0
    if k == 5 {
      sp = 0.0
    }
    if k == 2 {
      // casters keep their distance
      if d < 7.5 {
        mx = -dx / d
        mz = -dz / d
      } else {
        if d > 13.0 {
          mx = dx / d
          mz = dz / d
        } else {
          mx = cos(want) * 0.7
          mz = -sin(want) * 0.7
        }
      }
    } else {
      if d > foes[i].reach * 0.8 {
        mx = dx / d
        mz = dz / d
        // surround: bend the approach toward this foe's slot
        if d < 9.0 and k != 3 {
          let sa = foes[i].slot + tickN * 0.2
          let tx = px + sin(sa) * 2.0
          let tz = pz + cos(sa) * 2.0
          let ex = tx - foes[i].x
          let ez = tz - foes[i].z
          let ed = dst(0.0, 0.0, ex, ez)
          if ed > 0.1 {
            mx = mx * 0.45 + ex / ed * 0.55
            mz = mz * 0.45 + ez / ed * 0.55
          }
        }
      } else {
        sp = 0.0
        if k == 1 or k == 4 {
          mx = cos(want) * 1.0
          mz = -sin(want) * 1.0
          sp = foes[i].speed * 0.45
        }
      }
    }
    // separation
    let j = 0
    while j < length(foes) {
      if j != i and foes[j].dead == false {
        let sdx = foes[i].x - foes[j].x
        let sdz = foes[i].z - foes[j].z
        let sd = dst(0.0, 0.0, sdx, sdz)
        if sd < 1.6 and sd > 0.01 {
          mx += sdx / sd * 0.8
          mz += sdz / sd * 0.8
        }
      }
      j += 1
    }
    foes[i].x += mx * sp * dt
    foes[i].z += mz * sp * dt
    // player-body collision
    if d < 0.95 {
      foes[i].x -= dx / max(d, 0.05) * (0.95 - d)
      foes[i].z -= dz / max(d, 0.05) * (0.95 - d)
    }
    let moving = 0.0
    if sp > 0.1 {
      moving = sp / 5.0
    }
    rigRun(foes[i].rig, moving)
    rigPlay(foes[i].rig, "idle", 1.0, true)
    // decide to attack
    if foes[i].atkCd <= 0.0 and k != 5 {
      if k == 0 and d < foes[i].reach + 0.4 {
        foeBeginAttack(i)
      }
      if k == 1 and d < foes[i].reach + 2.0 {
        foeBeginAttack(i)
      }
      if k == 2 and d > 4.5 and d < 20.0 {
        foeBeginAttack(i)
      }
      if k == 4 and d < foes[i].reach + 0.6 {
        foeBeginAttack(i)
      }
      if k == 4 and d > 7.0 and foes[i].atkCd < -1.5 {
        foes[i].atkCd = 2.5
        shootAt(foes[i].x, foes[i].z, px, pz, 14.0, 10.0, 11163135)
        rigPlay(foes[i].rig, "release", 0.4, false)
        sfx("charge")
      }
      if k == 3 and (d < foes[i].reach + 1.0 or d > 6.0) {
        foeBeginAttack(i)
      }
    }
    // boss enrage
    if k == 3 and foes[i].phase == 1 and foes[i].hp < foes[i].hpMax * 0.5 {
      foes[i].phase = 2
      foes[i].state = "roar"
      foes[i].stT = 1.9
      foes[i].speed = 5.4
      rigAuraStyle(foes[i].rig, "curse")
      aura(foes[i].rig, 1.3)
      auraBurst(foes[i].rig, 2.0)
      shake(1.2, 900)
      flashScreen(0.4)
      sfx("ult")
      banner("CALAMITY ENRAGED", "Phase II", 16717880, 2000)
      spawnFoe(0, foes[i].x + 6.0, foes[i].z)
      spawnFoe(0, foes[i].x - 6.0, foes[i].z)
    }
  } else {
    rigRun(foes[i].rig, 0.0)
  }
  if foes[i].state == "windup" or foes[i].state == "recover" or foes[i].state == "block" or foes[i].state == "dodge" {
    rigRun(foes[i].rig, 0.0)
  }
  // dummy never moves or attacks
  if k == 5 and foes[i].state == "chase" {
    foes[i].state = "dummy"
  }
  if k == 5 and foes[i].state == "dummy" {
    foes[i].hp = foes[i].hpMax
    rigPlay(foes[i].rig, "idle", 1.0, true)
    rigRun(foes[i].rig, 0.0)
    if dst(foes[i].x, foes[i].z, foes[i].sx, foes[i].sz) > 0.3 {
      foes[i].x += (foes[i].sx - foes[i].x) * min(1.0, 2.0 * dt)
      foes[i].z += (foes[i].sz - foes[i].z) * min(1.0, 2.0 * dt)
    }
    foes[i].yaw = ang(px - foes[i].x, pz - foes[i].z)
  }
  rigSet(foes[i].rig, foes[i].x, foes[i].y, foes[i].z, foes[i].yaw)
}

fn removeFoe(i) {
  rigDel(foes[i].rig)
  remove foes[i]
}

fn shotsTick(dt) {
  let i = 0
  while i < length(shots) {
    shots[i].x += shots[i].vx * dt
    shots[i].z += shots[i].vz * dt
    shots[i].life -= dt
    shots[i].t += dt
    orbFx(shots[i].x, shots[i].y, shots[i].z, shots[i].hex, 0.7)
    let dead = false
    if shots[i].life <= 0.0 {
      dead = true
    }
    if dst(shots[i].x, shots[i].z, px, pz) < 1.0 and py < 2.4 {
      hurtPlayer(shots[i].dmg, shots[i].x - shots[i].vx, shots[i].z - shots[i].vz, 2, -1)
      fxHit(shots[i].x, shots[i].y, shots[i].z, 1, "curse")
      dead = true
    }
    if inArena(shots[i].x, shots[i].z) == 0 {
      dead = true
    }
    if dead {
      remove shots[i]
    } else {
      i += 1
    }
  }
}

fn houndsTick(dt) {
  let i = 0
  while i < length(hounds) {
    hounds[i].life -= dt
    hounds[i].biteCd -= dt
    let best = -1
    let bd = 40.0
    let j = 0
    while j < length(foes) {
      if foes[j].dead == false and foes[j].kind != 5 and foes[j].state != "trapped" {
        let d = dst(hounds[i].x, hounds[i].z, foes[j].x, foes[j].z)
        if d < bd {
          bd = d
          best = j
        }
      }
      j += 1
    }
    let sp = 0.0
    if best >= 0 {
      let dx = foes[best].x - hounds[i].x
      let dz = foes[best].z - hounds[i].z
      hounds[i].yaw += adiff(hounds[i].yaw, ang(dx, dz)) * min(1.0, 12.0 * dt)
      if bd > 1.6 {
        sp = 10.5
        hounds[i].x += dx / bd * sp * dt
        hounds[i].z += dz / bd * sp * dt
      } else {
        if hounds[i].biteCd <= 0.0 {
          hounds[i].biteCd = 0.55
          rigPlay(hounds[i].rig, "bite", 0.35, false)
          let bdm = 7.0
          if hounds[i].big {
            bdm = 12.0
          }
          hurtFoe(best, bdm, dx / bd, dz / bd, 4.0, 0.0, 0)
          sfx("bite")
          pcombo = pcombo
        }
      }
    } else {
      let dx = px - hounds[i].x
      let dz = pz - hounds[i].z
      let d = dst(px, pz, hounds[i].x, hounds[i].z)
      hounds[i].yaw += adiff(hounds[i].yaw, ang(dx, dz)) * min(1.0, 8.0 * dt)
      if d > 3.5 {
        sp = 9.0
        hounds[i].x += dx / d * sp * dt
        hounds[i].z += dz / d * sp * dt
      }
    }
    rigRun(hounds[i].rig, sp / 5.0)
    rigSet(hounds[i].rig, hounds[i].x, 0.0, hounds[i].z, hounds[i].yaw)
    if hounds[i].life <= 0.0 {
      shadowOut(hounds[i].x, hounds[i].z)
      rigDel(hounds[i].rig)
      remove hounds[i]
    } else {
      i += 1
    }
  }
}

fn addHound(x, z, big) {
  let rid = rigNew("beast", "hound")
  let sc = 1.0
  if big {
    sc = 1.5
  }
  add Hound { rig: rid, x: x, z: z, yaw: pyaw, life: 14.0, biteCd: 0.5, big: big } to hounds
  rigSet(rid, x, 0.0, z, pyaw)
  summonFx(x, z, big)
  if big {
    # G3.rigScale(rid, 1.5)
  }
}

// ---------------------------------------------------------------------
// Player: attacks
// ---------------------------------------------------------------------
fn atkDur(s) {
  if s == 1 {
    return 0.40
  }
  if s == 2 {
    return 0.40
  }
  if s == 3 {
    return 0.44
  }
  if s == 4 {
    return 0.48
  }
  return 0.72
}
fn atkDmg(s) {
  if s == 1 {
    return 7.0
  }
  if s == 2 {
    return 7.0
  }
  if s == 3 {
    return 9.0
  }
  if s == 4 {
    return 11.0
  }
  return 17.0
}

fn faceNearest(maxd) {
  let n = nearestFoe(maxd)
  if n >= 0 {
    let a = ang(foes[n].x - px, foes[n].z - pz)
    if abs(adiff(pyaw, a)) < 80.0 {
      pyaw = a
    }
  }
  return n
}

fn startAtk() {
  if pgnd == false {
    pairN += 1
    if pairN >= 3 {
      startSlam()
      return 0
    }
    pstate = "atk"
    pst = 0.0
    pdur = 0.38
    phit = false
    pstp = 10 + pairN
    rigPlay(prig, "air" + text(pairN), 0.38, false)
    pvy = max(pvy, 3.2)
    faceNearest(8.0)
    trail(prig, 0.3)
    sfx("swing")
    foeReact()
    return 0
  }
  pstp += 1
  if pstp > 5 or pstp > 9 {
    pstp = 1
  }
  pstate = "atk"
  pst = 0.0
  phit = false
  pdur = atkDur(pstp)
  rigPlay(prig, "light" + text(pstp), pdur, false)
  faceNearest(9.0)
  trail(prig, pdur * 0.75)
  sfx("swing")
  if pstp == 5 {
    sfx("swing2")
  }
  foeReact()
  let l = 7.0
  if pstp == 5 {
    l = 11.0
  }
  pvx = sin(pyaw) * l
  pvz = cos(pyaw) * l
}

fn strikeLight() {
  let s = pstp
  let air = false
  if s > 9 {
    air = true
    s = 2
  }
  let dmg = atkDmg(s)
  let reach = 3.0
  let kb = 3.0
  let lift = 0.0
  let kind = 0
  if s == 4 {
    kb = 6.0
  }
  if s == 5 {
    reach = 3.6
    kb = 15.0
    lift = 10.0
    kind = 1
  }
  if air {
    lift = 5.5
    dmg = 6.5
  }
  if pbfNext or pflow > 0.0 {
    kind = 3
    pbfNext = false
    pflow = 0.0
  }
  let fx = sin(pyaw)
  let fz = cos(pyaw)
  let tilt = -25.0
  if s % 2 == 0 {
    tilt = 25.0
  }
  if s == 4 {
    tilt = 80.0
  }
  if s == 5 {
    tilt = -10.0
  }
  fxSlash(px + fx * 0.5, py + 1.15, pz + fz * 0.5, pyaw, tilt, reach * 0.95, styleOf(), 0.22, 150.0, s % 2 == 0)
  let hitAny = false
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" {
      let dx = foes[i].x - px
      let dz = foes[i].z - pz
      let d = dst(px, pz, foes[i].x, foes[i].z)
      let rr = reach + 0.5
      if foes[i].kind == 3 {
        rr = rr + 1.4
      }
      if d < rr {
        let a = abs(adiff(pyaw, ang(dx, dz)))
        if a < 70.0 or d < 1.2 {
          if abs((foes[i].y + 1.0) - (py + 1.0)) < 3.2 {
            hurtFoe(i, dmg, dx / max(d, 0.1), dz / max(d, 0.1), kb, lift, kind)
            hitAny = true
          }
        }
      }
    }
    i += 1
  }
  hitProps(px + fx * 2.0, pz + fz * 2.0, 1.8, dmg)
  if hitAny {
    plast = 0.0
    // Black Flash timing cue: a thin red crackle at the fist at the instant of impact
    sparks(partX(prig, "fistR"), partY(prig, "fistR"), partZ(prig, "fistR"), 4, 4.0, 16717880)
    pvx = pvx * 0.3
    pvz = pvz * 0.3
  }
}

fn startHeavy() {
  if pgnd == false {
    startSlam()
    return 0
  }
  pstate = "heavy"
  pst = 0.0
  phit = false
  pdur = 0.85
  rigPlay(prig, "heavy", 0.85, false)
  faceNearest(9.0)
  trail(prig, 0.6)
  sfx("swing2")
  foeReact()
  pvx = sin(pyaw) * 4.0
  pvz = cos(pyaw) * 4.0
}

fn strikeHeavy() {
  let fx = sin(pyaw)
  let fz = cos(pyaw)
  fxSlash(px + fx * 0.6, py + 1.0, pz + fz * 0.6, pyaw, 90.0, 4.2, styleOf(), 0.3, 200.0, false)
  fxLand(px + fx * 2.0, pz + fz * 2.0, 2.5)
  shake(0.6, 260)
  let kind = 1
  if pflow > 0.0 or pbfNext {
    kind = 3
    pflow = 0.0
    pbfNext = false
  }
  let i = 0
  let hitAny = false
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" {
      let dx = foes[i].x - px
      let dz = foes[i].z - pz
      let d = dst(px, pz, foes[i].x, foes[i].z)
      let rr = 4.1
      if foes[i].kind == 3 {
        rr = 5.6
      }
      if d < rr {
        if abs(adiff(pyaw, ang(dx, dz))) < 80.0 or d < 1.4 {
          hurtFoe(i, 26.0, dx / max(d, 0.1), dz / max(d, 0.1), 16.0, 7.5, kind)
          hitAny = true
        }
      }
    }
    i += 1
  }
  hitProps(px + fx * 2.2, pz + fz * 2.2, 2.4, 40.0)
  if hitAny {
    plast = 0.0
  }
}

fn startSlam() {
  pstate = "slam"
  pst = 0.0
  phit = false
  pdur = 0.9
  pairN = 0
  rigPlay(prig, "airslam", 0.62, false)
  pvy = 4.0
  trail(prig, 0.6)
  sfx("swing2")
}

fn doSlamImpact() {
  fxLand(px, pz, 4.0)
  ringFx(px, 0.1, pz, 8.0, 16764762, 0.5)
  debrisFx(px, pz, 18, 8.0)
  shake(0.9, 320)
  hitstop(90)
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" {
      let dx = foes[i].x - px
      let dz = foes[i].z - pz
      let d = dst(px, pz, foes[i].x, foes[i].z)
      if d < 5.0 {
        hurtFoe(i, 24.0, dx / max(d, 0.1), dz / max(d, 0.1), 12.0, 4.0, 1)
      }
    }
    i += 1
  }
  hitProps(px, pz, 4.5, 60.0)
}

fn startDash() {
  let mf = 0.0
  let mr = 0.0
  if held("w") {
    mf += 1.0
  }
  if held("s") {
    mf -= 1.0
  }
  if held("d") {
    mr += 1.0
  }
  if held("a") {
    mr -= 1.0
  }
  let cy = camYaw()
  let wx = -sin(cy) * mf + cos(cy) * mr
  let wz = -cos(cy) * mf - sin(cy) * mr
  let m = dst(0.0, 0.0, wx, wz)
  if m < 0.1 {
    wx = sin(pyaw)
    wz = cos(pyaw)
    m = 1.0
  }
  wx = wx / m
  wz = wz / m
  pvx = wx * 30.0
  pvz = wz * 30.0
  pyaw = ang(wx, wz)
  pstate = "dash"
  pst = 0.0
  pdur = 0.22
  pdodge = 0.26
  pinv = 0.0
  pcdG = pcdG
  rigPlay(prig, "dash", 0.25, true)
  fxDash(px, pz, wx, wz, styleOf())
  sfx("dash")
  speedLines(160, "255,255,255")
  fovKick(4.0)
  trail(prig, 0.3)
  pstp = 0
}

// ---------------------------------------------------------------------
// Player: special abilities (different for every character)
// ---------------------------------------------------------------------
fn aimPoint(maxd, fallback) {
  let n = nearestFoe(maxd)
  if n >= 0 {
    return n
  }
  return -1
}

fn castLock(t, anim) {
  pstate = "cast"
  pst = 0.0
  pdur = t
  rigPlay(prig, anim, t, false)
}

fn castE() {
  if pcdE > 0.0 or pce < 20.0 {
    return 0
  }
  pce -= 20.0
  if ch == 0 {
    // BLUE - pulls everything into a point
    pcdE = 5.5
    let n = nearestFoe(16.0)
    let fx = sin(pyaw)
    let fz = cos(pyaw)
    blueX = px + fx * 7.0
    blueZ = pz + fz * 7.0
    if n >= 0 {
      blueX = foes[n].x
      blueZ = foes[n].z
      pyaw = ang(blueX - px, blueZ - pz)
    }
    blueT = 1.7
    blueFx(blueX, 1.5, blueZ, 1.7, 8.0)
    castLock(0.5, "cast")
    aura(prig, 1.3)
  }
  if ch == 1 {
    // SHADOW STEP - sink into shadow, emerge behind the target
    pcdE = 3.5
    let n = nearestFoe(24.0)
    let nx = px + sin(pyaw) * 10.0
    let nz = pz + cos(pyaw) * 10.0
    if n >= 0 {
      let dx = foes[n].x - px
      let dz = foes[n].z - pz
      let d = max(dst(px, pz, foes[n].x, foes[n].z), 0.5)
      nx = foes[n].x + dx / d * 2.1
      nz = foes[n].z + dz / d * 2.1
      foes[n].state = "stun"
      foes[n].stT = 0.9
    }
    shadowOut(px, pz)
    let sx = cpx(nx, nz, 0.6)
    let sz = cpz(nx, nz, 0.6)
    px = sx
    pz = sz
    if n >= 0 {
      pyaw = ang(foes[n].x - px, foes[n].z - pz)
    }
    shadowIn(px, pz)
    pinv = 0.5
    pamb = 3.0
    pvx = 0.0
    pvz = 0.0
    castLock(0.3, "teleport")
    msg("SHADOW STEP", 11163135)
  }
  if ch == 2 {
    // CRIMSON DASH - lightning rush
    pcdE = 4.0
    let n = nearestFoe(16.0)
    if n >= 0 {
      pyaw = ang(foes[n].x - px, foes[n].z - pz)
    }
    pstate = "rush"
    pst = 0.0
    pdur = 0.26
    rushId += 1
    rushDx = sin(pyaw)
    rushDz = cos(pyaw)
    pvx = rushDx * 44.0
    pvz = rushDz * 44.0
    pinv = 0.4
    rigPlay(prig, "dash", 0.3, true)
    sfx("dash")
    speedLines(260, "255,60,70")
    fovKick(7.0)
    trail(prig, 0.5)
    aura(prig, 1.6)
    lightningLine(px, 1.2, pz, px + rushDx * 11.0, 1.2, pz + rushDz * 11.0, 4)
  }
}

fn castX() {
  if pcdX > 0.0 or pce < 28.0 {
    return 0
  }
  pce -= 28.0
  if ch == 0 {
    // RED - explosive repulsion
    pcdX = 5.0
    let n = nearestFoe(18.0)
    let tx = px + sin(pyaw) * 6.5
    let tz = pz + cos(pyaw) * 6.5
    if n >= 0 {
      tx = foes[n].x
      tz = foes[n].z
      pyaw = ang(tx - px, tz - pz)
    }
    castLock(0.5, "release")
    redFx(tx, 1.2, tz, 7.5)
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" {
        let dx = foes[i].x - tx
        let dz = foes[i].z - tz
        let d = dst(tx, tz, foes[i].x, foes[i].z)
        if d < 8.0 {
          let dd = max(d, 0.2)
          hurtFoe(i, 34.0, dx / dd, dz / dd, 24.0, 8.5, 2)
        }
      }
      i += 1
    }
    let pd = dst(tx, tz, px, pz)
    if pd < 8.0 {
      pvx += (px - tx) / max(pd, 0.3) * 8.0
      pvz += (pz - tz) / max(pd, 0.3) * 8.0
    }
  }
  if ch == 1 {
    // SHADOW HOUNDS
    pcdX = 7.0
    castLock(0.7, "summon")
    let cnt = 0
    while cnt < 2 {
      if length(hounds) < 5 {
        let a = pyaw + 70.0 * (cnt * 2 - 1)
        addHound(px + sin(a) * 2.5, pz + cos(a) * 2.5, false)
      }
      cnt += 1
    }
    aura(prig, 1.4)
    msg("SHADOW HOUNDS", 11163135)
  }
  if ch == 2 {
    // RED BOLT - piercing lightning
    pcdX = 4.5
    let n = nearestFoe(24.0)
    if n >= 0 {
      pyaw = ang(foes[n].x - px, foes[n].z - pz)
    }
    castLock(0.45, "release")
    let fx = sin(pyaw)
    let fz = cos(pyaw)
    let ex = px + fx * 24.0
    let ez = pz + fz * 24.0
    lightningLine(px + fx * 0.8, 1.4, pz + fz * 0.8, ex, 1.4, ez, 9)
    shake(0.7, 260)
    flashScreen(0.15)
    hitstop(70)
    sfx("red")
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" {
        let rx = foes[i].x - px
        let rz = foes[i].z - pz
        let along = rx * fx + rz * fz
        let side = abs(rx * fz - rz * fx)
        if along > 0.0 and along < 25.0 and side < 2.0 {
          hurtFoe(i, 28.0, fx, fz, 14.0, 3.0, 2)
          foes[i].state = "stun"
          foes[i].stT = 1.0
        }
      }
      i += 1
    }
    hitProps(px + fx * 12.0, pz + fz * 12.0, 12.0, 30.0)
  }
}

fn castR() {
  if pult < 50.0 {
    return 0
  }
  pult -= 50.0
  bars(true)
  slowmo(28, 900)
  if ch == 0 {
    // HOLLOW PURPLE
    pstate = "ult"
    pst = 0.0
    pdur = 2.6
    castKind = 1
    castFired = false
    rigPlay(prig, "charge", 1.0, false)
    purpleCharge(prig, 1.0)
    aura(prig, 2.0)
    cinePush(px, 0.0, pz, 1.1, pyaw + 35.0, 5.5, 1.8)
    banner("HOLLOW PURPLE", "Convergence of infinity", 11556095, 1500)
  }
  if ch == 1 {
    // LEGION - mass summon
    pstate = "ult"
    pst = 0.0
    pdur = 2.2
    castKind = 2
    castFired = false
    rigPlay(prig, "summon", 1.2, false)
    aura(prig, 2.0)
    auraBurst(prig, 1.6)
    shadowPool(px, pz, 11.0, 5.0)
    cineOrbit(px, 0.0, pz, 1.4, pyaw + 150.0, pyaw + 260.0, 6.0, 1.6)
    banner("SHADOW LEGION", "A thousand shadows answer", 11163135, 1500)
    sfx("ult")
  }
  if ch == 2 {
    // METEOR RAIN
    pstate = "ult"
    pst = 0.0
    pdur = 2.4
    castKind = 3
    castFired = false
    rigPlay(prig, "ult", 1.0, false)
    aura(prig, 2.0)
    auraBurst(prig, 1.6)
    cineOrbit(px, 0.0, pz, 1.2, pyaw + 160.0, pyaw + 230.0, 6.0, 2.0)
    banner("CRIMSON METEORS", "The sky bleeds red", 16724530, 1500)
    sfx("ult")
  }
}

fn fireUlt() {
  castFired = true
  cineEnd()
  if castKind == 1 {
    let fx = sin(pyaw)
    let fz = cos(pyaw)
    purpleFx(px + fx * 1.2, 1.55, pz + fz * 1.2, pyaw, 46.0, 1.1)
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" {
        let rx = foes[i].x - px
        let rz = foes[i].z - pz
        let along = rx * fx + rz * fz
        let side = abs(rx * fz - rz * fx)
        if along > 0.0 and along < 48.0 and side < 3.6 {
          hurtFoe(i, 95.0, fx, fz, 28.0, 5.0, 2)
        }
      }
      i += 1
    }
  }
  if castKind == 2 {
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" and foes[i].kind != 5 {
        shadowSpike(foes[i].x, foes[i].z, 5.5)
        hurtFoe(i, 42.0, 0.0, 1.0, 4.0, 9.0, 2)
      }
      i += 1
    }
    let n = 0
    while n < 4 {
      if length(hounds) < 8 {
        let a = n * 90.0 + 45.0
        addHound(px + sin(a) * 3.5, pz + cos(a) * 3.5, true)
      }
      n += 1
    }
    shake(1.0, 500)
    flashScreen(0.3)
  }
  if castKind == 3 {
    let n = 0
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" and foes[i].kind != 5 and n < 6 {
        add Blast { x: foes[i].x, z: foes[i].z, t: 0.9 + n * 0.12, r: 4.8, dmg: 38.0, kind: 2 } to blasts
        meteorFall(foes[i].x, foes[i].z, 0.9 + n * 0.12)
        n += 1
      }
      i += 1
    }
    while n < 5 {
      let a = rnd(0.0, 360.0)
      let rr = rnd(4.0, 11.0)
      add Blast { x: px + sin(a) * rr, z: pz + cos(a) * rr, t: 0.9 + n * 0.12, r: 4.8, dmg: 38.0, kind: 2 } to blasts
      meteorFall(px + sin(a) * rr, pz + cos(a) * rr, 0.9 + n * 0.12)
      n += 1
    }
  }
}

fn blastsTick(dt) {
  let b = 0
  while b < length(blasts) {
    blasts[b].t -= dt
    if blasts[b].t <= 0.0 {
      let i = 0
      while i < length(foes) {
        if foes[i].dead == false and foes[i].state != "trapped" {
          let dx = foes[i].x - blasts[b].x
          let dz = foes[i].z - blasts[b].z
          let d = dst(blasts[b].x, blasts[b].z, foes[i].x, foes[i].z)
          if d < blasts[b].r {
            hurtFoe(i, blasts[b].dmg, dx / max(d, 0.2), dz / max(d, 0.2), 16.0, 9.0, 2)
          }
        }
        i += 1
      }
      hitProps(blasts[b].x, blasts[b].z, blasts[b].r, 60.0)
      remove blasts[b]
    } else {
      b += 1
    }
  }
}

fn blueTick(dt) {
  if blueT <= 0.0 {
    return 0
  }
  blueT -= dt
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" and foes[i].kind != 5 and foes[i].armor <= 0.0 {
      let dx = blueX - foes[i].x
      let dz = blueZ - foes[i].z
      let d = dst(blueX, blueZ, foes[i].x, foes[i].z)
      if d < 9.5 and d > 0.05 {
        let pull = 38.0 * (1.0 - d / 10.0) + 6.0
        foes[i].x += dx / d * pull * dt
        foes[i].z += dz / d * pull * dt
        foes[i].vx *= 0.8
        foes[i].vz *= 0.8
        if foes[i].state == "windup" or foes[i].state == "chase" {
          foes[i].state = "stun"
          foes[i].stT = 0.4
        }
        if d < 2.5 {
          dotFoe(i, 9.0 * dt)
        }
      }
    }
    i += 1
  }
  if blueT <= 0.0 {
    let k = 0
    while k < length(foes) {
      if foes[k].dead == false and foes[k].state != "trapped" {
        let d2 = dst(blueX, blueZ, foes[k].x, foes[k].z)
        if d2 < 4.0 {
          hurtFoe(k, 20.0, 0.0, 1.0, 5.0, 6.0, 2)
        }
      }
      k += 1
    }
  }
}

// ---------------------------------------------------------------------
// Domain Expansion (a cinematic with guaranteed hits)
// ---------------------------------------------------------------------
fn domainName() {
  if domKind == 1 {
    return "BOUNDLESS EXPANSE"
  }
  if domKind == 2 {
    return "HOLLOW GARDEN"
  }
  return "CRIMSON COLOSSEUM"
}
fn domainSub() {
  if domKind == 1 {
    return "Domain Expansion - Infinite Void"
  }
  if domKind == 2 {
    return "Domain Expansion - Garden of a Thousand Shadows"
  }
  return "Domain Expansion - Arena of Blood Lightning"
}
fn domainHex() {
  if domKind == 1 {
    return 5944575
  }
  if domKind == 2 {
    return 11563263
  }
  return 16722490
}

fn castG() {
  if pult < 100.0 or pcdG > 0.0 or domPhase > 0 {
    return 0
  }
  if aliveCount() == 0 and mode != 0 {
    msg("NO TARGETS", 16777215)
    return 0
  }
  domKind = ch + 1
  domPhase = 1
  domT = 0.0
  domN = 0
  pult = 0.0
  pstate = "domain"
  pvx = 0.0
  pvz = 0.0
  domSaveX = px
  domSaveZ = pz
  rigPlay(prig, "domain", 0.5, true)
  aura(prig, 2.2)
  auraBurst(prig, 2.2)
  bars(true)
  slowmo(10, 1700)
  banner(domainName(), domainSub(), domainHex(), 2400)
  cineOrbit(px, 0.0, pz, 2.3, pyaw + 30.0, pyaw + 400.0, 5.0, 1.5)
  sfx("domain")
  music("domain")
  invert(90)
  flashScreen(0.4)
  fovKick(8.0)
  shots = []
  blasts = []
  blueT = 0.0
}

fn domainHit(i, dmg) {
  if foes[i].dead {
    return 0
  }
  foes[i].hp -= dmg
  foes[i].flash = 1.0
  rigFlash(foes[i].rig, 1.0)
  domainStrike(domKind, foes[i].x, foes[i].y + 1.3, foes[i].z, domN)
  fxDmg(foes[i].x, foes[i].y + 2.0, foes[i].z, dmg, domainHex(), false)
  sfx("domainhit")
  shake(0.3, 120)
  if foes[i].hp <= 0.0 {
    killFoe(i)
  }
}

fn domainTick(dtR) {
  domT += dtR
  // keep rigs in sync
  let i = 0
  while i < length(foes) {
    if foes[i].state == "trapped" {
      rigSet(foes[i].rig, foes[i].x, foes[i].y, foes[i].z, foes[i].yaw)
      rigPlay(foes[i].rig, "stun", 1.0, true)
    }
    i += 1
  }
  rigSet(prig, px, py, pz, pyaw)
  if domPhase == 1 {
    if domT >= 2.3 {
      // pull everything into the domain
      domPhase = 2
      domT = 0.0
      domN = 0
      domNextT = 0.4
      invert(100)
      flashScreen(1.0)
      domainOn(domKind, 0.0, 0.0)
      px = 0.0
      pz = 0.0
      py = 0.0
      pyaw = 0.0
      let n = 0
      let j = 0
      let cnt = aliveCount()
      while j < length(foes) {
        if foes[j].dead == false and foes[j].kind != 5 {
          foes[j].sx = foes[j].x
          foes[j].sz = foes[j].z
          let a = (n * 360.0 / max(cnt, 1)) + 20.0
          foes[j].x = sin(a) * 7.5
          foes[j].z = cos(a) * 7.5
          foes[j].y = 0.0
          foes[j].vx = 0.0
          foes[j].vz = 0.0
          foes[j].vy = 0.0
          foes[j].yaw = a + 180.0
          foes[j].state = "trapped"
          n += 1
        }
        j += 1
      }
      if n == 0 {
        // training: the dummy gets trapped too
        let q = 0
        while q < length(foes) {
          foes[q].sx = foes[q].x
          foes[q].sz = foes[q].z
          foes[q].x = 0.0
          foes[q].z = 7.0
          foes[q].state = "trapped"
          q += 1
        }
      }
      slowmo(100, 10)
      cineLow(0.0, 0.0, 0.0, 5.2, 20.0, 330.0, 10.0)
      if domKind == 1 {
        pce = pceMax
      }
      sfx("domain")
    }
    return 0
  }
  if domPhase == 2 {
    domNextT -= dtR
    if domNextT <= 0.0 and domN < 14 {
      domNextT = 0.3
      // round-robin through the trapped foes
      let tries = 0
      let pick = -1
      let start = domN % max(length(foes), 1)
      while tries < length(foes) and pick < 0 {
        let c = (start + tries) % length(foes)
        if foes[c].state == "trapped" and foes[c].dead == false {
          pick = c
        }
        tries += 1
      }
      if pick >= 0 {
        let dmgv = 14.0
        if foes[pick].kind == 3 {
          dmgv = 10.0
        }
        domainHit(pick, dmgv)
        if domKind == 2 and domN % 4 == 0 {
          shadowPool(foes[pick].x, foes[pick].z, 3.0, 1.0)
        }
      }
      domN += 1
    }
    if domN >= 14 and domT > 5.2 {
      domPhase = 3
      domT = 0.0
      // guaranteed-hit finisher
      let cx = 0.0
      let cz = 0.0
      let cnt = 0
      let j = 0
      while j < length(foes) {
        if foes[j].state == "trapped" and foes[j].dead == false {
          cx += foes[j].x
          cz += foes[j].z
          cnt += 1
        }
        j += 1
      }
      if cnt > 0 {
        cx = cx / cnt
        cz = cz / cnt
      }
      domainSure(domKind, 0.0, 1.5, 0.0)
      if domKind == 3 {
        fxBlackFlash(cx, 1.4, cz)
      }
      sfx("ult")
      let k = 0
      while k < length(foes) {
        if foes[k].state == "trapped" and foes[k].dead == false {
          let fdmg = 70.0
          if foes[k].kind == 3 {
            fdmg = 140.0
          }
          foes[k].hp -= fdmg
          foes[k].flash = 1.0
          fxDmg(foes[k].x, 2.2, foes[k].z, fdmg, domainHex(), true)
          if foes[k].hp <= 0.0 {
            killFoe(k)
          }
        }
        k += 1
      }
      slowmo(14, 900)
    }
    return 0
  }
  if domPhase == 3 {
    if domT >= 1.4 {
      // back to the original arena
      domPhase = 0
      domainOff()
      cineEnd()
      bars(false)
      px = domSaveX
      pz = domSaveZ
      let j = 0
      while j < length(foes) {
        if foes[j].state == "trapped" {
          foes[j].x = foes[j].sx
          foes[j].z = foes[j].sz
          foes[j].state = "down"
          foes[j].stT = 0.8
          foes[j].vy = 0.0
          if foes[j].dead {
            foes[j].state = "dead"
          }
        }
        j += 1
      }
      pstate = "free"
      pinv = 1.2
      pcdG = 40.0
      pbf = 8.0
      aura(prig, 0.45)
      music("battle")
      flashScreen(0.6)
      fovKick(6.0)
      shake(0.8, 400)
    }
  }
}

// ---------------------------------------------------------------------
// Player tick
// ---------------------------------------------------------------------
fn playerTick(dt) {
  pcdE = max(0.0, pcdE - dt)
  pcdX = max(0.0, pcdX - dt)
  pcdG = max(0.0, pcdG - dt)
  pinv = max(0.0, pinv - dt)
  pdodge = max(0.0, pdodge - dt)
  pparry = max(0.0, pparry - dt)
  pflow = max(0.0, pflow - dt)
  pamb = max(0.0, pamb - dt)
  pbfBuf = max(0.0, pbfBuf - dt)
  plast += dt
  if pcombot > 0.0 {
    pcombot -= dt
    if pcombot <= 0.0 {
      pcombo = 0
    }
  }
  let rg = 5.0
  if pbf > 0.0 {
    rg = 17.0
    pbf -= dt
  }
  pce = min(pceMax, pce + rg * dt)
  // ---- input -----------------------------------------------------------
  let lm = click0()
  let rm = click1()
  if lm > 0 {
    pbuf = 1
    pbufT = 0.3
    // Black Flash: press again within a hair of the previous impact
    if pstate == "atk" and phit and plast < 0.085 and pstp > 0 and pstp < 10 {
      pbfNext = true
      aura(prig, 1.6)
    }
  }
  if rm > 0 {
    rbuf = 0.3
  }
  pbufT = max(0.0, pbufT - dt)
  rbuf = max(0.0, rbuf - dt)
  let mf = 0.0
  let mr = 0.0
  if held("w") {
    mf += 1.0
  }
  if held("s") {
    mf -= 1.0
  }
  if held("d") {
    mr += 1.0
  }
  if held("a") {
    mr -= 1.0
  }
  let cy = camYaw()
  let wx = -sin(cy) * mf + cos(cy) * mr
  let wz = -cos(cy) * mf - sin(cy) * mr
  let mag = dst(0.0, 0.0, wx, wz)
  if mag > 1.0 {
    wx = wx / mag
    wz = wz / mag
    mag = 1.0
  }
  pgnd = py <= 0.02 and pvy <= 0.1
  let canAct = pstate == "free" or pstate == "block" or (pstate == "atk" and phit) or (pstate == "heavy" and phit)
  // jump
  let jh = held("space")
  if jh and pjumpL == false and pgnd and (pstate == "free" or pstate == "block") {
    pvy = 12.5
    pstate = "free"
    sfx("jump")
    fxDust(px, pz, 4)
    pairN = 0
  }
  pjumpL = jh
  // abilities
  if kQ and canAct and pcdDash <= 0.0 {
    startDash()
    pcdDash = 0.5
  }
  kQ = false
  pcdDash = max(0.0, pcdDash - dt)
  if kE and canAct {
    castE()
  }
  if kX and canAct {
    castX()
  }
  if kR and canAct {
    castR()
  }
  if kG and (pstate == "free" or canAct) {
    castG()
  }
  kE = false
  kX = false
  kR = false
  kG = false
  // block
  if held("f") and pgnd and pstate == "free" {
    pstate = "block"
    pblock = 0.0
    rigPlay(prig, "block", 0.3, false)
  }
  if pstate == "block" {
    pblock += dt
    if held("f") == false {
      pstate = "free"
    }
  }
  // counter attack after a perfect parry
  if pparry > 0.0 and pbuf == 1 and (pstate == "block" or pstate == "free") {
    pbuf = 0
    pparry = 0.0
    pstate = "counter"
    pst = 0.0
    pdur = 0.6
    phit = false
    rigPlay(prig, "counter", 0.6, false)
    faceNearest(10.0)
    pvx = sin(pyaw) * 12.0
    pvz = cos(pyaw) * 12.0
    trail(prig, 0.5)
    sfx("swing2")
  }
  // attacks
  if pbuf == 1 and pbufT > 0.0 {
    if pstate == "free" or pstate == "block" {
      pbuf = 0
      pstate = "free"
      if pcombot <= 0.0 and pgnd {
        pstp = 0
      }
      startAtk()
    } else {
      if pstate == "atk" and phit and pst >= pdur * 0.5 + 0.02 {
        pbuf = 0
        if pgnd == false {
          startAtk()
        } else {
          startAtk()
        }
      }
      if pstate == "heavy" and phit and pst >= pdur * 0.62 {
        pbuf = 0
        pstp = 0
        startAtk()
      }
    }
  }
  if rbuf > 0.0 and (pstate == "free" or pstate == "block" or (pstate == "atk" and phit)) {
    rbuf = 0.0
    startHeavy()
  }
  // ---- states ------------------------------------------------------------
  let sp = 6.6
  if held("shift") {
    sp = 10.5
  }
  if pstate == "free" {
    rigPlay(prig, "idle", 1.0, true)
    let acc = 16.0
    if pgnd == false {
      acc = 6.0
    }
    if mag > 0.1 {
      pvx += (wx * sp - pvx) * min(1.0, acc * dt)
      pvz += (wz * sp - pvz) * min(1.0, acc * dt)
      pyaw += adiff(pyaw, ang(wx, wz)) * min(1.0, 18.0 * dt)
      rigRun(prig, sp / 6.2 * mag)
      pfoot += dt
      if pfoot > 0.28 and pgnd {
        pfoot = 0.0
        fxDust(px, pz, 1)
        sfx("step")
      }
    } else {
      pvx *= max(0.0, 1.0 - 14.0 * dt)
      pvz *= max(0.0, 1.0 - 14.0 * dt)
      rigRun(prig, 0.0)
    }
    if pgnd == false {
      if pvy > 0.0 {
        rigPlay(prig, "jump", 1.0, true)
      } else {
        rigPlay(prig, "fall", 1.0, true)
      }
    }
  }
  if pstate == "block" {
    pvx *= max(0.0, 1.0 - 18.0 * dt)
    pvz *= max(0.0, 1.0 - 18.0 * dt)
    rigRun(prig, 0.0)
    if mag > 0.1 {
      pyaw += adiff(pyaw, ang(wx, wz)) * min(1.0, 10.0 * dt)
    }
  }
  if pstate == "atk" or pstate == "heavy" or pstate == "counter" {
    pst += dt
    rigRun(prig, 0.0)
    let hf = 0.5
    if pstate == "heavy" {
      hf = 0.55
    }
    if pstate == "counter" {
      hf = 0.5
    }
    if pstate == "atk" and pstp == 5 {
      hf = 0.56
    }
    if pst < pdur * hf {
      // lunge forward during wind-up
    } else {
      pvx *= max(0.0, 1.0 - 14.0 * dt)
      pvz *= max(0.0, 1.0 - 14.0 * dt)
    }
    if phit == false and pst >= pdur * hf {
      phit = true
      if pstate == "atk" {
        strikeLight()
      }
      if pstate == "heavy" {
        strikeHeavy()
      }
      if pstate == "counter" {
        counterStrike()
      }
    }
    if pgnd == false {
      pvy += 18.0 * dt
      if pvy > 2.5 and pstate == "atk" {
        pvy = 2.5
      }
    }
    if pst >= pdur {
      pstate = "free"
      pcombot = max(pcombot, 0.55)
      if pgnd == false {
        pcombot = max(pcombot, 0.3)
      }
    }
  }
  if pstate == "slam" {
    pst += dt
    if pst < 0.3 {
      pvy = max(pvy, 0.0)
      pvy += 6.0 * dt
    } else {
      if phit == false {
        pvy = -34.0
        phit = true
        speedLines(220, "255,230,160")
        fovKick(5.0)
      }
    }
    if phit and pgnd {
      doSlamImpact()
      pstate = "free"
      pcombot = 0.4
    }
    if pst > 1.2 {
      pstate = "free"
    }
  }
  if pstate == "dash" {
    pst += dt
    rigPlay(prig, "dash", 0.25, true)
    if pst >= pdur {
      pstate = "free"
      pvx *= 0.25
      pvz *= 0.25
      if pgnd == false {
        pvy = max(pvy, 0.0)
      }
    }
  }
  if pstate == "rush" {
    pst += dt
    rigPlay(prig, "dash", 0.25, true)
    let i = 0
    while i < length(foes) {
      if foes[i].dead == false and foes[i].state != "trapped" and foes[i].rushTag != rushId {
        if dst(px, pz, foes[i].x, foes[i].z) < 2.4 {
          foes[i].rushTag = rushId
          hurtFoe(i, 18.0, rushDx, rushDz, 8.0, 4.0, 2)
          lightningLine(px, 1.2, pz, foes[i].x, 1.4, foes[i].z, 3)
        }
      }
      i += 1
    }
    if pst >= pdur {
      pstate = "free"
      pvx *= 0.2
      pvz *= 0.2
      fxSlash(px, py + 1.2, pz, pyaw + 180.0, 0.0, 3.4, "akai", 0.25, 180.0, false)
    }
  }
  if pstate == "cast" {
    pst += dt
    pvx *= max(0.0, 1.0 - 10.0 * dt)
    pvz *= max(0.0, 1.0 - 10.0 * dt)
    rigRun(prig, 0.0)
    if pst >= pdur {
      pstate = "free"
      aura(prig, 0.45)
    }
  }
  if pstate == "ult" {
    pst += dt
    pinv = 0.2
    pvx *= max(0.0, 1.0 - 10.0 * dt)
    pvz *= max(0.0, 1.0 - 10.0 * dt)
    rigRun(prig, 0.0)
    let fireT = 1.0
    if castKind == 2 {
      fireT = 0.8
    }
    if castKind == 3 {
      fireT = 0.7
    }
    if castFired == false and pst >= fireT {
      fireUlt()
      if castKind == 1 {
        rigPlay(prig, "release", 0.5, false)
      }
    }
    if castKind == 1 and castFired and pst < 1.9 {
      pvx -= sin(pyaw) * 14.0 * dt
      pvz -= cos(pyaw) * 14.0 * dt
    }
    if pst >= pdur {
      pstate = "free"
      bars(false)
      aura(prig, 0.45)
      cineEnd()
    }
  }
  if pstate == "hit" {
    pst += dt
    pvx *= max(0.0, 1.0 - 8.0 * dt)
    pvz *= max(0.0, 1.0 - 8.0 * dt)
    rigRun(prig, 0.0)
    if pst >= pdur {
      pstate = "free"
    }
  }
  // ---- physics -----------------------------------------------------------
  if pgnd == false or pvy > 0.0 {
    if pstate != "slam" and pstate != "atk" and pstate != "heavy" {
      pvy -= 34.0 * dt
    }
    if pstate == "atk" and pgnd == false {
      pvy -= 6.0 * dt
    }
    py += pvy * dt
    if py <= 0.0 {
      let hard = pvy
      py = 0.0
      pvy = 0.0
      pairN = 0
      if hard < -14.0 and pstate != "slam" {
        fxLand(px, pz, 2.0)
        sfx("land")
      } else {
        fxDust(px, pz, 3)
      }
    }
  }
  px += pvx * dt
  pz += pvz * dt
  let ox = px
  let oz = pz
  px = cpx(ox, oz, 0.55)
  pz = cpz(ox, oz, 0.55)
  rigSet(prig, px, py, pz, pyaw)
  camTarget(px, py + 1.3, pz)
  // aura level eases back to idle glow
  if pbf > 0.0 {
    aura(prig, 1.0)
  } else {
    if pstate == "free" or pstate == "block" {
      aura(prig, 0.45)
    }
  }
  if php < phpMax * 0.0 {
    php = 0.0
  }
}

fn counterStrike() {
  let fx = sin(pyaw)
  let fz = cos(pyaw)
  fxSlash(px + fx * 0.6, py + 1.1, pz + fz * 0.6, pyaw, -35.0, 4.0, styleOf(), 0.28, 200.0, false)
  shake(0.6, 240)
  let i = 0
  while i < length(foes) {
    if foes[i].dead == false and foes[i].state != "trapped" {
      let dx = foes[i].x - px
      let dz = foes[i].z - pz
      let d = dst(px, pz, foes[i].x, foes[i].z)
      if d < 4.6 {
        if abs(adiff(pyaw, ang(dx, dz))) < 85.0 or d < 1.4 {
          fxCrit(foes[i].x, foes[i].y + 1.2, foes[i].z, styleOf())
          hurtFoe(i, 36.0, dx / max(d, 0.1), dz / max(d, 0.1), 18.0, 8.0, 1)
        }
      }
    }
    i += 1
  }
  hitProps(px + fx * 2.0, pz + fz * 2.0, 2.2, 50.0)
}

// ---------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------
fn spawnAround(k) {
  let tries = 0
  let x = 0.0
  let z = 0.0
  let ok = false
  while tries < 14 and ok == false {
    let a = rnd(0.0, 360.0)
    let r = rnd(11.0, 19.0)
    x = px + sin(a) * r
    z = pz + cos(a) * r
    if inArena(x, z) == 1 {
      let cx = cpx(x, z, 0.8)
      let cz = cpz(x, z, 0.8)
      if abs(cx - x) < 0.05 and abs(cz - z) < 0.05 {
        ok = true
      }
    }
    tries += 1
  }
  if ok == false {
    x = rnd(-6.0, 6.0)
    z = rnd(-6.0, 6.0)
  }
  spawnFoe(k, x, z)
}

fn spawnWave() {
  wave += 1
  let n = 2 + wave
  if n > 8 {
    n = 8
  }
  banner("WAVE " + text(wave), "Cursed spirits approach", 11163135, 1800)
  sfx("ready")
  if wave % 5 == 0 {
    spawnAround(3)
    spawnAround(0)
    spawnAround(0)
    music("boss")
    return 0
  }
  let i = 0
  while i < n {
    let r = rnd(0.0, 1.0)
    let k = 0
    if wave >= 2 and r < 0.3 {
      k = 1
    }
    if wave >= 3 and r > 0.78 {
      k = 2
    }
    spawnAround(k)
    i += 1
  }
}

fn clearWorld() {
  let i = 0
  while i < length(foes) {
    rigDel(foes[i].rig)
    i += 1
  }
  while length(foes) > 0 {
    remove foes[0]
  }
  let h = 0
  while h < length(hounds) {
    rigDel(hounds[h].rig)
    h += 1
  }
  while length(hounds) > 0 {
    remove hounds[0]
  }
  while length(shots) > 0 {
    remove shots[0]
  }
  while length(blasts) > 0 {
    remove blasts[0]
  }
}

fn cleanup() {
  clearWorld()
  if prig != 0 {
    rigDel(prig)
    prig = 0
  }
  domainQuiet()
  domPhase = 0
  cineEnd()
  bars(false)
}

fn startMatch() {
  cleanup()
  ch = menuChar()
  mode = menuMode()
  gstate = "play"
  px = 0.0
  pz = 6.0
  py = 0.0
  pvx = 0.0
  pvz = 0.0
  pvy = 0.0
  pyaw = 180.0
  php = 200.0
  phpMax = 200.0
  pce = 100.0
  pult = 0.0
  pstate = "free"
  pstp = 0
  pbuf = 0
  pcombo = 0
  pcombot = 0.0
  pinv = 1.0
  pcdE = 0.0
  pcdX = 0.0
  pcdG = 0.0
  pflow = 0.0
  pbf = 0.0
  pamb = 0.0
  blueT = 0.0
  wave = 0
  waveWait = 2.0
  score = 0
  overT = 0.0
  pairN = 0
  prig = rigNew("human", lookOf())
  aura(prig, 0.45)
  rigSet(prig, px, 0.0, pz, pyaw)
  camSetYaw(0.0)
  camDist(6.4)
  setChar(ch)
  clearEnd()
  if mode == 0 {
    modeText = "TRAINING  -  T grunt  Y caster  B boss  K clear  -  ult meter fills as you fight"
    spawnFoe(5, 0.0, -6.0)
    pult = 100.0
    banner("TRAINING GROUNDS", "Try everything", 5944575, 1600)
  }
  if mode == 1 {
    modeText = "SURVIVAL"
  }
  if mode == 2 {
    modeText = "BOSS BATTLE"
    spawnFoe(3, 0.0, -14.0)
    banner("THE CALAMITY", "A special-grade curse", 16717880, 2200)
    music("boss")
  }
  if mode == 3 {
    modeText = "1v1 ARENA"
    spawnFoe(4, 0.0, -12.0)
    banner("DUEL", "Defeat the rival sorcerer", 16764762, 1800)
  }
  music("calm")
}

fn modeTick(dt) {
  if mode == 1 {
    modeText = "SURVIVAL  -  WAVE " + text(wave) + "  -  KOs " + text(score)
    if aliveCount() == 0 {
      waveWait -= dt
      if waveWait <= 0.0 {
        spawnWave()
        waveWait = 3.0
        php = min(phpMax, php + 14.0)
        pce = min(pceMax, pce + 25.0)
      }
    }
  }
  if mode == 2 or mode == 3 {
    let boss = -1
    let i = 0
    while i < length(foes) {
      if foes[i].kind == 3 or foes[i].kind == 4 {
        boss = i
      }
      i += 1
    }
    if boss >= 0 and foes[boss].dead and gstate == "play" {
      overT += dt
      if overT > 2.4 {
        gameOver(true)
      }
    }
  }
}

fn bossBar() {
  let i = 0
  let found = false
  while i < length(foes) {
    if (foes[i].kind == 3 or foes[i].kind == 4) and foes[i].dead == false {
      hudBoss(true, foes[i].name, foes[i].hp, foes[i].hpMax)
      found = true
    }
    i += 1
  }
  if found == false {
    hudBoss(false, "", 1.0, 1.0)
  }
}

fn musicPick() {
  let m = "calm"
  if aliveCount() > 0 {
    m = "battle"
  }
  let i = 0
  while i < length(foes) {
    if foes[i].kind == 3 and foes[i].dead == false {
      m = "boss"
    }
    i += 1
  }
  if domPhase > 0 {
    m = "domain"
  }
  if m != lastMusic {
    lastMusic = m
    music(m)
  }
}

// ---------------------------------------------------------------------
// The main tick
// ---------------------------------------------------------------------
fn playTick() {
  tickN += 1
  takeLook()
  let ts = timeScale()
  let dtR = 0.0167
  let dt = 0.0167 * ts
  if domPhase > 0 {
    domainTick(dtR)
    pcdG = max(0.0, pcdG)
  } else {
    playerTick(dt)
    let i = 0
    while i < length(foes) {
      foeTick(i, dt)
      if foes[i].dead and foes[i].stT <= 0.0 {
        removeFoe(i)
      } else {
        i += 1
      }
    }
    shotsTick(dt)
    houndsTick(dt)
    blastsTick(dt)
    blueTick(dt)
    modeTick(dt)
    // training hotkeys
    if mode == 0 {
      if kT {
        spawnAround(0)
      }
      if kY {
        spawnAround(2)
      }
      if kB {
        spawnAround(3)
      }
      if kK {
        let n = 0
        while n < length(foes) {
          if foes[n].kind != 5 {
            foes[n].hp = 1.0
            foes[n].dead = false
            killFoe(n)
          }
          n += 1
        }
      }
    }
    kT = false
    kY = false
    kB = false
    kK = false
  }
  musicPick()
  hudDraw(php, phpMax, pce, pceMax, pult, pcombo, pcdE, pcdX, 0.0, pcdG)
  let alive = aliveCount()
  if mode == 0 {
    alive = -1
  }
  hudInfo(alive, modeText)
  bossBar()
}

fn mainTick() {
  if engineReady == false {
    return 0
  }
  if gstate == "menu" {
    if menuDone() == 1 {
      ackMenu()
      startMatch()
    }
    return 0
  }
  if inMenuNow() == 1 {
    cleanup()
    gstate = "menu"
    return 0
  }
  if gstate == "over" {
    if menuDone() == 1 {
      ackMenu()
      startMatch()
    }
    return 0
  }
  if isPaused() == 1 {
    return 0
  }
  playTick()
}

// ---------------------------------------------------------------------
// Keys and start-up
// ---------------------------------------------------------------------
when key "q" pressed {
  kQ = true
}
when key "e" pressed {
  kE = true
}
when key "x" pressed {
  kX = true
}
when key "r" pressed {
  kR = true
}
when key "g" pressed {
  kG = true
}
when key "t" pressed {
  kT = true
}
when key "y" pressed {
  kY = true
}
when key "b" pressed {
  kB = true
}
when key "k" pressed {
  kK = true
}

# document.title = 'Cursed Arena - a 3D anime action fighter';
bootEngine()
engineReady = true

every frame {
  mainTick()
}
