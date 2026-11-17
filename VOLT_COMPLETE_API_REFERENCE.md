# Volt Studio — complete API reference

An audit of what the engine actually supports, produced by reading the
compiler and runtime and then **compiling and executing a probe program for
every API**. Nothing here is listed because a name appears in the source.

Audited against commit `2876c7c`, November 2026.

## The documents

| File | What it is |
| --- | --- |
| `VOLT_SYNTAX_REFERENCE.md` | The language: types, operators, control flow, program shape, units, reserved words, and what Volt does not have |
| `VOLT_FUNCTION_REGISTRY.md` | Every function and statement, by category, with signature and verified status |
| `VOLT_3D_GAME_DEVELOPMENT_GUIDE.md` | How to build each RPG system with what exists |
| `VOLT_VERIFIED_EXAMPLES/` | Three complete programs, compiled and run |

## Method

1. The authoritative lists were extracted from the compiler itself — the
   builtin arity table, `GAME_WORDS`, the 3D command arity map and the
   statement dispatch — rather than from any documentation.
2. A probe program was generated for each name, with arguments of the right
   type and in the right context.
3. Each probe was compiled with `compiler/volt.js`.
4. Each compiled probe was loaded in headless Chrome and run for several
   frames, with page errors and console errors captured.

### Results

| Status | Count | Meaning |
| --- | ---: | --- |
| VERIFIED | 104 | Compiled and ran a frame with no errors |
| PARTIAL | 3 | Works, but only in some targets |
| IMPLEMENTED | 1 | Compiles; not testable in this sandbox |
| UNAVAILABLE | 0 | — |

The three PARTIAL entries are `readFile`, `writeFile` and `envVar`: they work
in `#js` and are rejected by name in `#html`. The one IMPLEMENTED entry is
`fetchText`, which needs network access this environment does not have.

Two probes failed on the first run and both were faults in the probe, not the
engine. `join3d` was called group-first when the signature is
`join3d part, group` — the engine's own error message said so. The `image`
probe was handed `"@male"`, which is a 3D model name; `@` resolution applies
only to `model3d`.

## The five things most worth knowing

**1. Games are `#html`.** All 3D, all 2D drawing and all input exist only in
the `#html` target. `#c++` is for microcontrollers and rejects `box` and
`world3d` by name. An RPG is an `#html` program.

**2. `fn main()` is never called.** Not in any target. Top-level statements
are the entry point, and a game's loop is `every frame { }`. A program whose
body sits inside `fn main()` compiles and does nothing.

**3. 3D angles are tenths of a degree.** `turn3d id, 900` is 90°. `sin3` and
`cos3` take tenths and return values scaled by 1000.

**4. The camera's yaw runs opposite to headings.** `camera3d` aims along
`(sin(yaw), -cos(yaw))`, while `turn3d` and the movement maths use
`(sin, cos)`. To look along a heading, pass `1800 - heading`. Getting this
wrong points the camera away from its subject, and it is silent.

**5. Statements and functions are different.** Functions return a value and
take parentheses: `let id = block3d(...)`. Statements are commands with no
parentheses: `move3d id, x, y, z`. The registry marks which each name is.

## Coverage by area

| Area | State |
| --- | --- |
| 2D drawing | Full: rounded panels, gradients, strokes, rings, arcs, triangles, alpha, glow, clipping, text measurement |
| 3D primitives | Boxes, spheres, cylinders, groups. **No rotation of a primitive on its own axis** |
| Models | glTF/GLB via `model3d`, two CC0 characters and 43 clips built in |
| Animation | Clip playback, weight blending, 2D blend space, additive layers, bone sockets, direct bone posing. **No IK, root motion or state machine** |
| Physics | Collision queries, raycasting, rigid bodies with bounce, friction and Magnus spin. **No joints, triggers or character controller** |
| Lighting | Ambient, point lights, camera torch, sun with shadows, image-based lighting, ACES tone mapping |
| Materials | Colour, metalness, emissive, cel shading with outlines and rim. **No custom shaders, no normal or roughness maps on primitives** |
| Effects | Particle bursts, ribbon trails, impact frames, hitstop, slow motion, camera shake, bloom, vignette, grain |
| Input | Keyboard, mouse movement, pointer lock, click regions, touch pad. **No gamepad** |
| Audio | Loading, one-shot playback, looping music, volume. **No 3D positional audio** |
| Saves | One number or string per key, in browser storage. **No list or record serialisation** |
| Networking | `fetchText` in `#js` only. **No multiplayer** |
| Scene management | `clear3d` and rebuild. **No scene files, no object deletion** |

## Where the engine's limits bite hardest

For a large RPG, in rough order of how much work they add:

1. **No object deletion.** `show3d id, 0` hides; nothing frees. Pool everything
   at start-up.
2. **No list or record saving.** An inventory must be flattened to numbered
   keys by hand.
3. **No navmesh or pathfinding.** AI steers directly and probes walls with
   `bump3d`.
4. **No primitive rotation.** Anything diagonal must be a model.
5. **No instancing or LOD.** A few hundred objects is the budget on
   integrated graphics.
6. **No UI widgets.** `hot3d` plus `clicked3d` is the whole of mouse
   interaction; menus are drawn and navigated by hand.
7. **No IK or root motion.** Feet slide.

None of these stops a stylised 3D RPG being built. They decide its shape.

## Repository check

All 35 `.volt` programs in `examples/` and `VOLT_VERIFIED_EXAMPLES/` compile,
with three environmental exceptions: `19_lua_number_guesser.volt` and
`20_luau_part_spawner.volt` need plugin targets that only load inside the Volt
Studio app, and `22_import_library.volt` needs its folder passed as
`baseDir` so its `import` can be resolved. All three were confirmed working
once given what they need.

## Reproducing this audit

The probe harness lives outside the repository, but the method is short
enough to repeat: extract `BUILTIN`'s arity table and `GAME_WORDS` from
`compiler/volt.js`, generate one minimal program per name, compile each with
`require('./compiler/volt.js').compile(src, { filename })`, and load the
output in a browser while listening for `pageerror`.

The distinction that matters: **a page that compiles but throws on frame one
is not a working API.** Several real bugs in this project were found exactly
there, invisible to compilation.
