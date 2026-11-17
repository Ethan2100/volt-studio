// ---- Volt 3D anime layer: toon3d, shot3d, lookat3d, shake3d, slowmo3d, hitstop3d, bars3d ----
// Loaded straight after volt3d.js, so it can borrow and wrap what is already there.
//
// Why this file exists: plain lighting makes everything look like a photo. Anime games do not
// use it. They use flat bands of colour, a bright edge around the character, and a dark line
// drawn around the silhouette. That is what the three settings on toon3d control.
//
// Same units as the rest of Volt: 1 unit = 1 cm, angles are tenths of a degree, times are in
// milliseconds.

let __toonOn3 = 0;            // 0 = normal lighting, 1 = anime look
let __toonBands3 = 3;         // how many steps of brightness (2 = harsh, 5 = soft)
let __toonLine3 = 35;         // outline thickness, 0 = no outline
let __toonRim3 = 60;          // rim light strength, 0 = none
let __toonRimHex3 = '#ffffff';
const __rampCache3 = new Map();
const __toonMats3 = new Map();

// A ramp is a one-pixel-tall strip that goes dark -> light in hard steps. Three.js reads it to
// decide how a surface is shaded, so the number of steps is the number of bands you see.
function __ramp3(bands) {
  const n = Math.max(2, Math.min(8, Math.round(bands)));
  const hit = __rampCache3.get(n);
  if (hit) return hit;
  const data = new Uint8Array(n * 4);
  for (let i = 0; i < n; i++) {
    // Shadows in anime art are tinted, never plain grey, so the darkest band keeps some blue.
    const t = i / (n - 1);
    const lift = 0.32 + 0.68 * t;
    data[i * 4 + 0] = Math.round(255 * lift * (0.94 + 0.06 * t));
    data[i * 4 + 1] = Math.round(255 * lift * (0.96 + 0.04 * t));
    data[i * 4 + 2] = Math.round(255 * lift);
    data[i * 4 + 3] = 255;
  }
  const t = new THREE.DataTexture(data, n, 1, THREE.RGBAFormat);
  t.needsUpdate = true;
  t.minFilter = t.magFilter = THREE.NearestFilter;   // nearest = hard edges between bands
  t.generateMipmaps = false;
  __rampCache3.set(n, t);
  return t;
}

// Adds a fresnel rim to any material: surfaces facing away from the camera glow at their edge.
// This is the single cheapest thing that makes a character read as "anime" instead of "3D model".
// Set true to put the rim back on plain shapes as well as characters.
let __rimOnShapes3 = false;

// A character is a skinned mesh, or anything parented under one.
function __rimWanted3(mesh) {
  if (mesh.isSkinnedMesh) return true;
  let n = mesh.parent;
  while (n) {
    if (n.isSkinnedMesh || (n.userData && n.userData.__isModel)) return true;
    n = n.parent;
  }
  return false;
}

function __rim3(mat) {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.rimColor = { value: new THREE.Color(__toonRimHex3) };
    sh.uniforms.rimPower = { value: 2.5 };
    sh.uniforms.rimAmount = { value: Math.max(0, Math.min(100, __toonRim3)) / 100 };
    const add = [
      'float rimF = 1.0 - max(dot(normalize(vNormal), normalize(vViewPosition)), 0.0);',
      'rimF = pow(clamp(rimF, 0.0, 1.0), rimPower) * rimAmount;',
      'gl_FragColor.rgb += rimColor * rimF;'
    ].join('\n');
    sh.fragmentShader = sh.fragmentShader
      .replace('void main() {', 'uniform vec3 rimColor;\nuniform float rimPower;\nuniform float rimAmount;\nvoid main() {');
    // Chunk names moved around between Three.js versions, so patch whichever one is present.
    let done = false;
    // Order matters: these must be tried EARLIEST first. Anchoring on
    // dithering_fragment put the rim after tone mapping and colour space
    // conversion, so it was added to an already-displayed pixel and could
    // never be rolled off - a large floor seen at a glancing angle is
    // almost entirely rim, and went pure white.
    for (const anchor of ['#include <opaque_fragment>', '#include <output_fragment>', '#include <tonemapping_fragment>', '#include <dithering_fragment>']) {
      if (!done && sh.fragmentShader.indexOf(anchor) >= 0) {
        sh.fragmentShader = sh.fragmentShader.replace(anchor, anchor + '\n' + add);
        done = true;
      }
    }
    mat.userData.shader = sh;
  };
  mat.needsUpdate = true;
  return mat;
}

function __toonMat3(color) {
  const key = String(color) + '|' + __toonBands3 + '|' + __toonRim3;
  const hit = __toonMats3.get(key);
  if (hit) return hit;
  const m = new THREE.MeshToonMaterial({ color: String(color), gradientMap: __ramp3(__toonBands3) });
  // shapes built by block3d/cyl3d/ball3d are world, not character: no rim
  if (__toonRim3 > 0 && __rimOnShapes3) __rim3(m);
  __toonMats3.set(key, m);
  return m;
}

// The outline is a second copy of the model, turned inside out and pushed outwards along its
// own surface direction. You only ever see the part that sticks out past the real model, which
// reads as a drawn line. Width is in tenths of a percent of the model's size.
// skinned: an outline for a character, which has to follow the skeleton.
// Without the skinning chunks the hull draws the model's bind pose, which
// on an animated character is a black T-posed copy of it standing still
// behind the real one.
function __outlineMat3(width, skinned) {
  const head = skinned
    ? ['#include <common>', '#include <skinning_pars_vertex>', 'uniform float lineWidth;']
    : ['uniform float lineWidth;'];
  const body = skinned
    ? ['  vec3 objectNormal = normalize(normal);',
       '  vec3 transformed = position + objectNormal * lineWidth * 100.0;',
       '  #include <skinbase_vertex>',
       '  #include <skinning_vertex>',
       '  gl_Position = projectionMatrix * modelViewMatrix * vec4(transformed, 1.0);']
    : ['  vec3 pushed = position + normalize(normal) * lineWidth * 100.0;',
       '  gl_Position = projectionMatrix * modelViewMatrix * vec4(pushed, 1.0);'];
  return new THREE.ShaderMaterial({
    uniforms: { lineWidth: { value: width / 10000 }, lineColor: { value: new THREE.Color('#15111c') } },
    vertexShader: head.concat(['void main() {'], body, ['}']).join('\n'),
    fragmentShader: 'uniform vec3 lineColor;\nvoid main() { gl_FragColor = vec4(lineColor, 1.0); }',
    side: THREE.BackSide
  });
}

// Walks anything already in the scene (or newly added) and gives it the anime treatment.
function __toonify3(root) {
  if (!__toonOn3 || !root) return;
  const adds = [];
  root.traverse((c) => {
    if (!c.isMesh || c.userData.__isOutline) return;
    const old = c.material;
    if (old && !old.isMeshToonMaterial) {
      const col = old.color ? old.color.getHexString() : 'ffffff';
      const m = new THREE.MeshToonMaterial({ color: '#' + col, gradientMap: __ramp3(__toonBands3) });
      if (old.map) m.map = old.map;
      if (old.transparent) { m.transparent = true; m.opacity = old.opacity; }
      // Rim light belongs on characters, not on the world. The term is
      // 1 - dot(normal, view), which approaches 1 across any large surface
      // seen at a glancing angle - so a floor took full rim everywhere and
      // washed out to flat grey no matter how the scene was lit. Skinned
      // meshes are the characters, which is where the effect is wanted.
      if (__toonRim3 > 0 && __rimWanted3(c)) __rim3(m);
      c.material = m;
    }
    if (__toonLine3 > 0 && !c.userData.__hasOutline) {
      let o;
      if (c.isSkinnedMesh && c.skeleton) {
        // share the character's own skeleton, so the hull moves with it
        o = new THREE.SkinnedMesh(c.geometry, __outlineMat3(__toonLine3, true));
        o.bind(c.skeleton, c.bindMatrix);
        o.bindMode = c.bindMode;
      } else {
        o = new THREE.Mesh(c.geometry, __outlineMat3(__toonLine3, false));
      }
      o.userData.__isOutline = true;
      o.renderOrder = -1;
      o.frustumCulled = false;
      c.userData.__hasOutline = true;
      adds.push([c, o]);
    }
  });
  // Added after the walk so the traverse is not modified while it is running.
  for (const pair of adds) pair[0].add(pair[1]);
}

// toon3d bands, outline, rim
//   bands   2..8    how many steps of light (3 is the usual anime look, 2 is harsher)
//   outline 0..100  thickness of the dark line around things, 0 turns it off
//   rim     0..100  how bright the edge glow is, 0 turns it off
// Turn it on once, near world3d, and everything afterwards is drawn this way.
function __toon3d(bands, outline, rim) {
  __need3();
  __toonBands3 = Math.max(2, Math.min(8, Math.round(bands == null ? 3 : bands)));
  __toonLine3 = Math.max(0, Math.min(100, outline == null ? 35 : outline));
  __toonRim3 = Math.max(0, Math.min(100, rim == null ? 60 : rim));
  __toonOn3 = 1;
  __toonMats3.clear();
  if (__sc3) __toonify3(__sc3);         // restyle anything already placed
  return 0;
}

// Wrap the two places that make materials, so blocks and models both pick up the anime look.
// These are plain function declarations in volt3d.js, so reassigning them here is allowed.
const __matBase3 = __mat;
__mat = function (color, own) {
  if (__toonOn3) return own ? __toonMat3(color).clone() : __toonMat3(color);
  return __matBase3(color, own);
};
const __putBase3 = __put3d;
__put3d = function (m, x, y, z, yaw, scale) {
  const id = __putBase3(m, x, y, z, yaw, scale);
  if (__toonOn3) __toonify3(__objs3[id].mesh);
  return id;
};

// ---- camera work: shots, shake, slow motion, hit stop, letterbox bars ----

let __shot3 = null;            // the camera move that is running right now
let __shake3 = null;
let __slow3 = 1;               // 1 = normal speed, 0.25 = quarter speed
let __slowLeft3 = 0;
let __stop3 = 0;               // milliseconds of frozen time left
let __bars3 = null;

function __ease3(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }

// lookat3d x, y, z     point the camera at a spot in the world
function __lookat3d(x, y, z) {
  __need3();
  __cam3.lookAt(x / 100, y / 100, z / 100);
  return 0;
}

// shot3d x, y, z, atx, aty, atz, ms
//   Glides the camera to x, y, z over ms milliseconds while keeping it pointed at atx, aty, atz.
//   Call it once; it keeps running on its own every render3d until it finishes.
function __shot3d(x, y, z, ax, ay, az, ms) {
  __need3();
  __shot3 = {
    from: __cam3.position.clone(),
    to: new THREE.Vector3(x / 100, y / 100, z / 100),
    at: new THREE.Vector3(ax / 100, ay / 100, az / 100),
    ms: Math.max(1, ms || 1000),
    t: 0
  };
  return 0;
}

// shake3d power, ms     power 0..100. Use ~20 for a footstep, ~70 for a boss landing.
function __shake3d(power, ms) {
  __need3();
  __shake3 = { power: Math.max(0, Math.min(100, power)) / 100, ms: Math.max(1, ms || 200), t: 0 };
  return 0;
}

// slowmo3d percent, ms     percent 10..100 of normal speed, for ms of real time.
function __slowmo3d(percent, ms) {
  __slow3 = Math.max(10, Math.min(100, percent || 100)) / 100;
  __slowLeft3 = Math.max(0, ms || 0);
  return 0;
}

// hitstop3d ms     freezes everything for a moment. 60-120 ms on a heavy hit sells the weight.
function __hitstop3d(ms) {
  __stop3 = Math.max(0, Math.min(1000, ms || 0));
  return 0;
}

// bars3d on     1 draws black cinema bars top and bottom, 0 removes them.
function __bars3d(on) {
  if (!on) {
    if (__bars3) { __bars3.remove(); __bars3 = null; }
    return 0;
  }
  if (__bars3) return 0;
  const wrap = document.createElement('div');
  wrap.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:40';
  for (const edge of ['top', 'bottom']) {
    const b = document.createElement('div');
    b.style.cssText = 'position:absolute;left:0;right:0;height:12vh;background:#000;' + edge + ':0;' +
      'transition:height .4s ease';
    wrap.appendChild(b);
  }
  document.body.appendChild(wrap);
  __bars3 = wrap;
  return 0;
}

// Returns how much time the game should advance this frame, after slow motion and hit stop.
// volt3d.js's own render loop still runs at real speed; this only scales what the anime layer does.
function __timeScale3(dtMs) {
  if (__stop3 > 0) { __stop3 -= dtMs; return 0; }
  if (__slowLeft3 > 0) { __slowLeft3 -= dtMs; return __slow3; }
  return 1;
}

let __animeLast3 = performance.now();
function __animeUpdate3() {
  const now = performance.now();
  const dt = Math.min(100, now - __animeLast3);
  __animeLast3 = now;
  const scale = __timeScale3(dt);
  const step = dt * scale;

  if (__shot3) {
    __shot3.t += step;
    const k = Math.min(1, __shot3.t / __shot3.ms);
    __cam3.position.lerpVectors(__shot3.from, __shot3.to, __ease3(k));
    __cam3.lookAt(__shot3.at);
    if (k >= 1) __shot3 = null;
  }
  if (__shake3) {
    __shake3.t += dt;                                  // shake ignores slow motion on purpose
    const left = 1 - Math.min(1, __shake3.t / __shake3.ms);
    const amt = __shake3.power * left * 0.12;
    __cam3.position.x += (Math.random() - 0.5) * amt;
    __cam3.position.y += (Math.random() - 0.5) * amt;
    if (left <= 0) __shake3 = null;
  }
  // Model animations obey slow motion and freeze on a hit stop.
  for (const o of __objs3) {
    if (o && o.mixer && o.mixer.timeScale !== scale) o.mixer.timeScale = scale;
  }
}

const __renderBase3 = __render3d;
__render3d = function () {
  __animeUpdate3();
  return __renderBase3();
};

// ---- groups: move many shapes as one thing ----
//
// A character built from blocks and balls is a dozen separate objects. Without a group you have
// to move and turn every single one of them yourself, every frame. A group is one object you
// move instead, and everything inside it comes along.
//
//   let hero = group3d(0, 0, 700)        // the point the hero turns around
//   join3d heroBody, hero
//   join3d heroHead, hero
//   move3d hero, px, 0, pz               // the whole hero moves
//   turn3d hero, yaw                     // and turns

function __group3d(x, y, z) {
  __need3();
  const g = new THREE.Group();
  g.position.set(x / 100, y / 100, z / 100);
  __sc3.add(g);
  __objs3.push({ mesh: g, group: true, own: false, model: false, mixer: null, action: null });
  return __objs3.length - 1;
}

// join3d part, group   -- the part keeps exactly where it looks right now, so you can build
// everything in world coordinates first and group it afterwards.
function __join3d(partId, groupId) {
  const p = __o3(partId), g = __o3(groupId);
  if (!g.group) throw new Error('join3d needs a group made with: let name = group3d(x, y, z)');
  const child = p.mesh || p.light;
  if (!child) throw new Error('join3d cannot move that into a group');
  if (child === g.mesh) throw new Error('join3d cannot put a group inside itself');
  g.mesh.updateMatrixWorld(true);
  child.updateMatrixWorld(true);
  const world = new THREE.Vector3();
  child.getWorldPosition(world);
  g.mesh.add(child);                 // reparenting happens here
  g.mesh.worldToLocal(world);
  child.position.copy(world);        // ...and this keeps it looking unchanged
  return 0;
}
