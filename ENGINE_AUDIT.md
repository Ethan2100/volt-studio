# Volt engine audit

What Volt3D actually was before this branch, measured against the source rather
than described from the docs. Every number here came from reading the files or
running them.

Audited at `76736f8`. Changes made since are listed at the end.

---

## 1. What Volt3D is

`lib/volt3d.js` was 26 KB and `lib/volt3d-anime.js` 12 KB, sitting on a bundled
`lib/three.min.js` of 796 KB. The compiler knew 33 3D keywords.

That makes Volt3D a presentation layer over Three.js, not an engine. It could
draw things and move them, and it had a genuinely good game-feel layer
(`shot3d`, `shake3d`, `slowmo3d`, `hitstop3d`, `bars3d`, toon shading with
banded ramps, fresnel rim light and inverted-hull outlines). What it could not
do was let two objects find out about each other.

### The gap, before this branch

| Capability | Present in `lib/volt3d*.js` |
| --- | --- |
| Collision of any kind | none |
| Raycasting | none |
| Physics | none |
| `InstancedMesh` / batching | none |
| LOD | none |
| Frustum or occlusion control | none |
| Navmesh / pathfinding | none |
| Cascaded shadows | none |
| Positional audio | none |
| Workers / WASM | none |

### The consequence, measured

Every serious 3D thing in the repository was written in raw JavaScript smuggled
through Volt's `#` passthrough, because the language could not express it:

| File | Lines | Raw `#` JS | Actual Volt |
| --- | ---: | ---: | ---: |
| `plugins/combat3d/engine3d.volt` | 1,685 | **100%** | 0 |
| `plugins/combat-vfx/engine.volt` | 654 | 88% | 78 |
| `plugins/vfx-engine/engine.volt` | 156 | 69% | 47 |
| `examples/26_cursed_arena_3d.volt` | 5,307 | 35% | 3,432 |
| `examples/28_thornkeep_realm.volt` | 243 | 0% | 242 |

`engine3d.volt` is 1,685 lines without one line of Volt in it — a Three.js
engine pulled from a CDN and wrapped in `#`. Cursed Arena states the split in
its own comment at line 1773: lines 1–1770 are the JS engine, and the Volt
begins after it as the gameplay layer, because *"the 3D engine above only
draws."*

Thornkeep is the counter-example and it is instructive: 242 lines of pure Volt,
zero escapes — and it is a static walkable map of 27 blocks, 20 cylinders, 2
spheres and 4 lamps. Nothing moves and nothing touches anything.

**The conclusion: Volt was already a good gameplay language and not an engine.**
Cursed Arena proves 3,400 lines of real combat logic works in it. The engine
tier fell out of the language every time.

---

## 2. Rendering defects found

These were bugs, not missing features.

1. **No tone mapping.** `toneMapping` was never set on the renderer, so it ran
   at `NoToneMapping` and every highlight clipped to flat white.
2. **The sun cast no shadows.** `__sun3` was created in `__sky3d` as a
   `DirectionalLight` and given an intensity, but `castShadow` was never set on
   it. The only shadow caster in the entire engine was the torch spotlight at a
   1024 map. Every daylight scene had no shadows at all.
3. **No global image-based lighting.** `__env3()` built a perfectly good PMREM
   probe, but it was only ever attached per-object inside `shine3d`, and only
   when metalness exceeded 0.05. Everything else was lit by one `AmbientLight`
   plus point lights, which is why untouched scenes read as plastic.
4. **Antialiasing was bare MSAA**, pixel ratio capped at 1.25, no FXAA/SMAA/TAA
   pass — so toon outlines shimmered under movement.
5. **Single-channel materials.** `__mat` built a `MeshStandardMaterial` with a
   procedurally drawn canvas grime texture at roughness 0.92. No normal,
   roughness or AO maps on anything built from `block3d`/`cyl3d`/`ball3d`.
6. **Camera far plane hard-coded to 80 world units**, capping view distance
   regardless of the `fog` argument.

The bloom chain was the good part: brightpass → separable blur → mix at
`HalfFloatType`, correctly resized. It holds up.

---

## 3. Animation defects found

`__anim3d` was 20 lines: find clip by name, `fadeIn(0.2).play()`,
`fadeOut(0.2)` the old one.

- **No weight blending.** Zero occurrences of `setEffectiveWeight` or
  `crossFadeTo` in either library file. Walk and run could only hard-cut on a
  fixed 0.2 s fade.
- **No blend trees or blend spaces**, no additive layers, no IK, no root motion.
- **No bone access**, so nothing could be put in a character's hand.
- `if (o.action === a) return;` meant a clip already playing could not be
  restarted — so no repeated attack swing.
- One-shot clips were selected by a hardcoded regex,
  `/^(open|close|die|pick-up)$/`, a magic list left over from an earlier game.
  Any clip not on it looped forever.

---

## 4. Build fingerprints

- Every page Volt has ever generated shipped `<title>Volt page</title>`,
  hardcoded in the HTML template. The `title "..."` word only rendered a heading
  in the body and never reached the document head.

---

## 5. Performance ceiling

The relevant measured limit is not the renderer. Community measurements put
Three.js skinned-mesh cost at roughly 200 characters before frame rate drops
below 60, with the cost in `AnimationMixer.update()`, bone matrix updates and
`Skeleton.update()` — not draw calls.

A football match needs 22 players and a ball. **That is an order of magnitude
under the wall**, which is why this is a tractable target where photorealism is
not.

The real constraint is the target machine: an HP ProBook 430 G3 with Intel
HD 520 integrated graphics and 8 GB RAM. Every quality decision from here is
bounded by that, not by what Three.js can do.

Shape caveat: each `block3d` creates its own `THREE.Mesh`. Geometry is cached by
dimensions and material by colour, but there is no instancing, so Thornkeep's
53 shapes are 53 draw calls and a stadium built the same way would be thousands.

---

## 6. Asset pipeline

There was none. `model3d` embedded a `.glb` from disk as base64 and that was the
whole of it. No built-in models, no texture budget, no format conversion, no
licence tracking.

Two defects surfaced when real assets were brought in:

- The CC0 character pack's own `.gltf` files reference
  `T_Eye_Normal_png.png` and `T_Hair_1_Normal_png.png`, neither of which exists
  in the download — the real files carry no `_png`. Upstream defect.
- At 2048² textures the characters were ~16 MB each. Since Volt base64-embeds
  models into the page, texture weight is page weight.

---

## 7. Changes made on this branch

Implemented and verified since the audit:

**Simulation** — `solid3d`, `bump3d`, `ground3d`, `hit3d`, `hitid3d`, `aim3d`
over a lazily rebuilt 4 m uniform grid; `phys3d`, `kick3d`, `spin3d` with
`where3d`, `vel3d`, `rest3d`. Substepped against the grid so a ball struck at
60 m/s cannot cross a wall between frames; bounce and friction split at the
contact normal; Magnus term curves the flight; grounded slow bodies sleep.

**Animation** — `blend3d` (phase-locked weight blending), `blend4d` (2D
directional blend space), `layer3d` (additive via
`AdditiveAnimationBlendMode`), `once3d` (re-triggerable one-shots), `socket3d`
(bone attachment with inherited scale divided out), `bone3d` (direct bone
control, re-applied after the mixer), `clips3d` (lend a clip library to a rig).

**Rendering** — ACES filmic tone mapping, explicit sRGB output, global IBL from
the existing PMREM probe, sun shadows at 2048 with a camera-following 120 m box.

**Assets** — two CC0 rigged characters and 43 shared clips in `lib/models`,
addressable as `"@male"`, `"@female"`, `"@animations"`. Textures reduced to
512², animation files stripped of their preview mannequin and resampled
(7.6 MB → 2.2 MB each, all 43 clips intact), upstream texture URIs corrected.

**Compiler** — the browser tab is now named from `title "..."`, falling back to
the source file name.

### Verification

- 13-check physics harness against Three.js r158: fall, rest at exactly the
  radius, rebound, no tunnelling at 60 m/s, sideways deflection under spin.
- 12-check animation harness against the real shipped GLBs: clips lend, blend
  weights land at 0.50/0.50, partial names resolve, the mixer moves the
  skeleton, `bone3d` survives the mixer overwriting the pose, `once3d`
  re-triggers mid-swing.
- 10 programs compile, 6 of them pre-existing examples.
- `examples/30_striker.volt` driven headless on a fixed clock for 3 simulated
  minutes: 44–50 shots, 60–84 possession changes, goals scored, no crashes.

### Known-bad, found by running it

Two bugs that compiling could never have caught, both since fixed:

1. The characters carry **zero** animation clips — all 43 live in the library —
   and `blend3d`/`anim3d` looked them up on the character's own model. The game
   compiled and would have thrown on frame one. `clips3d` exists because of this.
2. Possession changed **6,957 times in 7,200 frames**, flipping every frame
   between two players on the same spot. The AI deadlocked between carrying the
   ball and chasing a ball at its own feet, and the match ended 0–0 with
   everyone frozen at spawn. Hysteresis took it to 7.

---

## 8. Still absent

Against a production engine, honestly: no ECS or scene graph beyond Three's own,
no scene serialisation or prefabs, no constraints or trigger volumes, no IK, no
root motion, no animation state machine, no 3D positional audio, no gamepad
support, no navmesh or behaviour trees, no instancing or LOD, no profiler, no
hot reload, and no low-quality rendering tier for the target machine.
