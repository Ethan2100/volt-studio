# Volt function registry

Every entry below was produced by compiling a probe program with
`compiler/volt.js` and, where the probe targets `#html`, loading it in a real
browser and running frames. Nothing here is listed because its name appears in
the source.

Audited against commit `2876c7c`.

| Status | Meaning |
| --- | --- |
| VERIFIED | Compiled and ran a frame with no errors |
| IMPLEMENTED | Compiles, not runtime-testable in this environment |
| PARTIAL | Works, but only in some targets |
| UNAVAILABLE | Not implemented |

**Totals: 104 VERIFIED, 3 PARTIAL, 1 IMPLEMENTED, across 108 probes.**

Every 3D, 2D and input name below is `#html` only. See the syntax reference, §1.


## General

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `ask` | statement | `let n = ask "question"` | IMPLEMENTED | Reads a line of input. #js and other script targets. |
| `print` | statement | `print value` | IMPLEMENTED | Writes a line to the console (or the page console in #html). |
| `uptime` | statement | `uptime` | IMPLEMENTED | Milliseconds since the program started. |

## Data

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `contains` | function | `contains(haystack, needle)` | VERIFIED | Returns 1 if the string contains the substring. |
| `join` | function | `join(list, separator)` | VERIFIED | Joins a list into a string. |
| `length` | function | `length(listOrString)` | VERIFIED | Item count of a list, or character count of a string. |
| `lower` | function | `lower(s)` | VERIFIED | Lowercase copy of a string. |
| `number` | function | `number(v)` | VERIFIED | Converts a string or float to a number. Also used to pass floats where an engine command wants a number. |
| `part` | function | `part(s, from, to)` | VERIFIED | Substring between two indexes. |
| `split` | function | `split(s, separator)` | VERIFIED | Splits a string into a list. |
| `text` | function | `text(v)` | VERIFIED | Converts a value to a string. Required to join a number to a string. |
| `upper` | function | `upper(s)` | VERIFIED | Uppercase copy of a string. |

## Maths

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `abs` | function | `abs(n)` | VERIFIED | Absolute value. |
| `atan2` | function | `atan2(y, x)` | VERIFIED | Angle of a vector, in tenths of a degree, 0-3600. Feed scaled integers: atan2(dx * 1000.0, dz * 1000.0). |
| `constrain` | function | `constrain(v, low, high)` | VERIFIED | Clamps a value into a range. |
| `cos` | function | `cos(radians)` | VERIFIED | Cosine, in radians. |
| `cos3` | function | `cos3(tenthsOfADegree)` | VERIFIED | Cosine scaled by 1000. Divide by 1000.0 for a unit value. |
| `dist` | function | `dist(x1, y1, x2, y2)` | VERIFIED | Distance between two 2D points. Used for 3D ground distance by passing x and z. |
| `lerp` | function | `lerp(a, b, percent)` | VERIFIED | Blends between two numbers, percent 0-100. |
| `map` | function | `map(v, inLow, inHigh, outLow, outHigh)` | VERIFIED | Rescales a value from one range to another. |
| `max` | function | `max(a, b)` | VERIFIED | Larger of two numbers. |
| `min` | function | `min(a, b)` | VERIFIED | Smaller of two numbers. |
| `overlaps` | function | `overlaps(ax, ay, aw, ah, bx, by, bw, bh)` | VERIFIED | Returns 1 if two rectangles overlap. |
| `pow` | function | `pow(base, exp)` | VERIFIED | Exponentiation. |
| `random` | function | `random(low, high)` | VERIFIED | Whole number in the range, inclusive. |
| `sign` | function | `sign(n)` | VERIFIED | -1, 0 or 1. |
| `sin` | function | `sin(radians)` | VERIFIED | Sine, in radians. For 3D work use sin3, which is in tenths of a degree. |
| `sin3` | function | `sin3(tenthsOfADegree)` | VERIFIED | Sine scaled by 1000. Divide by 1000.0 for a unit value. |
| `sqrt` | function | `sqrt(n)` | VERIFIED | Square root. Returns a whole number (floored). For distances prefer dist(). |

## 2D

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `alpha` | statement | `alpha percent` | VERIFIED | Sets opacity for everything drawn after it, 0-100. Statement. Mode-setting: reset with alpha 100. |
| `box` | statement | `box x, y, w, h color "#rrggbb"` | VERIFIED | Filled rectangle. Statement. |
| `camera` | statement | `camera x, y` | VERIFIED | Offsets all 2D drawing, for a scrolling world. Statement. Does not affect the 3D camera. |
| `card` | statement | `card x, y, w, h, radius color "#rrggbb"` | VERIFIED | Filled rounded panel. Statement. |
| `clicked3d` | function | `clicked3d()` | VERIFIED | Returns 1 once if the last hot3d rectangle was clicked. |
| `clip` | statement | `clip x, y, w, h, radius` | VERIFIED | Confines later draws to a rounded shape until unclip. Statement. Must be paired with unclip. |
| `crisp` | function | `crisp(1)` | VERIFIED | Turns off smoothing, for pixel art. |
| `edge` | statement | `edge x, y, w, h, radius, thickness color "#..."` | VERIFIED | Rounded outline. Statement. Lines up exactly with card/grad of the same box. |
| `glow` | statement | `glow "#rrggbb", size` | VERIFIED | Soft glow on everything drawn after it. Statement. Turn off with glow "", 0. |
| `grad` | statement | `grad x, y, w, h, radius, topColor, bottomColor` | VERIFIED | Rounded panel with a vertical gradient. Statement. No color keyword; both colours are positional. |
| `hot3d` | function | `hot3d(x, y, w, h)` | VERIFIED | Marks a clickable rectangle for this frame. Pair with clicked3d(). |
| `paint` | statement | `paint "#rrggbb"` | VERIFIED | Fills the whole canvas with a colour. Statement. Not for sprites. |
| `ring` | statement | `ring x, y, radius, thickness color "#..."` | VERIFIED | Circle outline. Statement. |
| `sweep` | statement | `sweep x, y, radius, amount, thickness color "#..."` | VERIFIED | Arc filling clockwise from twelve o'clock, amount 0-100. Statement. The cooldown dial primitive. |
| `textw` | function | `textw(s, size)` | VERIFIED | Pixel width the string will draw at. The only way to size a panel to its contents. |
| `tri` | statement | `tri ax, ay, bx, by, cx, cy color "#..."` | VERIFIED | Filled triangle. Statement. Arrows and chevrons. |
| `unclip` | statement | `unclip` | VERIFIED | Ends the most recent clip. Statement. |
| `write` | statement | `write value at x, y color "#..." size n centered shadow` | VERIFIED | Draws text. All options after at are optional. Statement. |

## 3D world

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `clear3d` | statement | `clear3d` | VERIFIED | Removes everything from the 3D world. Statement. Also clears physics, trails and collision. |
| `render3d` | statement | `render3d` | VERIFIED | Advances physics and animation, then draws the frame. Statement. Call once per frame, and draw the HUD after it. |
| `world3d` | statement | `world3d "#rrggbb" fog N ambient N fov N shadows` | VERIFIED | Creates the 3D world. Required before any other 3D call. Statement. All options after the colour are optional. |

## 3D primitives

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `ball3d` | function | `ball3d(x, y, z, radius, "#rrggbb")` | VERIFIED | A sphere. Returns its id. |
| `block3d` | function | `block3d(x, y, z, w, h, d, "#rrggbb")` | VERIFIED | A box. Returns its id. Centimetres. Cannot be rotated on its own axis. |
| `cyl3d` | function | `cyl3d(x, y, z, radius, height, "#rrggbb")` | VERIFIED | A cylinder. Returns its id. |

## 3D transforms

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `group3d` | function | `group3d(x, y, z)` | VERIFIED | An empty parent. Returns its id. |
| `join3d` | statement | `join3d part, group` | VERIFIED | Moves a part into a group, keeping its on-screen position. Statement. Part first, group second. |
| `move3d` | statement | `move3d id, x, y, z` | VERIFIED | Moves an object. Statement. |
| `show3d` | statement | `show3d id, 1` | VERIFIED | Shows (1) or hides (0) an object. Statement. |
| `turn3d` | statement | `turn3d id, yaw` | VERIFIED | Rotates an object about Y. Statement. Tenths of a degree. |

## 3D models

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `model3d` | statement | `model3d name = "file.glb"` | IMPLEMENTED | Loads a glTF model before the program starts. Top-level only. "@male", "@female", "@animations" are built in. |
| `put3d` | function | `put3d(model, x, y, z, yaw, size)` | VERIFIED | Places an instance of a loaded model. Returns its id. size is a percentage: 100 is natural size. |

## Camera

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `bars3d` | statement | `bars3d 1` | VERIFIED | Cinematic letterbox bars on (1) or off (0). Statement. |
| `camera3d` | statement | `camera3d x, y, z, yaw, pitch` | VERIFIED | Positions and aims the 3D camera. Statement. Yaw runs opposite to headings: use 1800 - heading. |
| `lookat3d` | statement | `lookat3d x, y, z` | VERIFIED | Points the camera at a world position. Statement. |
| `shake3d` | statement | `shake3d power, ms` | VERIFIED | Shakes the camera. Statement. |
| `shot3d` | statement | `shot3d x, y, z, atX, atY, atZ, ms` | VERIFIED | Moves the camera to a framing over a time. Statement. |

## Lighting

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `lamp3d` | function | `lamp3d(x, y, z, "#rrggbb", power, range)` | VERIFIED | A point light. Returns its id. power is halved internally: 40 becomes intensity 20. A handful of lights saturates a toon scene. |
| `sky3d` | function | `sky3d(brightness)` | VERIFIED | Sets sun and sky brightness, 0-100. Also usable as a statement. |
| `torch3d` | statement | `torch3d 1, 60` | VERIFIED | A spotlight that follows the camera. Statement. |

## Materials

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `fx3d` | statement | `fx3d bloom, vignette, grain` | VERIFIED | Post-processing, each 0-100. Statement. |
| `glow3d` | statement | `glow3d id, "#rrggbb"` | VERIFIED | Makes a surface emit light of its own. Statement. |
| `look3d` | statement | `look3d 1, "#rrggbb"` | VERIFIED | Sets the overall look and tint. Statement. |
| `shine3d` | statement | `shine3d id, metalness, roughness` | VERIFIED | Makes a surface metallic, each 0-100. Statement. Attaches an environment probe. |
| `toon3d` | statement | `toon3d bands, outline, rim` | VERIFIED | Cel shading: colour bands, outline width, rim strength. Statement. outline is pushed width/100 model units, so 5 is 5cm. rim applies to skinned characters only. |

## Animation

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `anim3d` | statement | `anim3d id, "ClipName"` | VERIFIED | Plays a clip, crossfading from the current one. Statement. Partial names match. |
| `blend3d` | statement | `blend3d id, "clipA", "clipB", amount` | VERIFIED | Weight-blends two looping clips, 0-100, phase-locked. Statement. |
| `blend4d` | statement | `blend4d id, "fwd", "back", "left", "right", dx, dy` | VERIFIED | A 2D directional blend space, dx and dy -100..100. Statement. |
| `bone3d` | statement | `bone3d id, "boneName", pitch, yaw, roll` | VERIFIED | Adds rotation to one bone on top of the clip. Statement. Re-applied after the mixer each frame. |
| `clips3d` | statement | `clips3d rigId, libraryModel` | VERIFIED | Lends another model's animation clips to a rig. Statement. Required for the built-in characters, which carry no clips. |
| `layer3d` | statement | `layer3d id, "clip", weight` | VERIFIED | Plays a clip additively on top of whatever is running. Statement. Upper-body actions over locomotion. |
| `once3d` | statement | `once3d id, "clip"` | VERIFIED | Plays a clip once; can be re-fired mid-play. Statement. Use for attacks. |
| `socket3d` | statement | `socket3d rigId, "boneName", childId` | VERIFIED | Attaches an object to a bone. Statement. The child keeps the offset it was built at. |

## Input

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `held` | function | `held("w")` | VERIFIED | Returns 1 while a key is down. Use "shift", "space", single letters. |
| `locked3d` | function | `locked3d()` | VERIFIED | Returns 1 while the pointer is locked. |
| `mousedx` | function | `mousedx()` | VERIFIED | Mouse movement in X since last call. Consumed on read. |
| `mousedy` | function | `mousedy()` | VERIFIED | Mouse movement in Y since last call. Consumed on read. |
| `touchpad` | statement | `touchpad "w", "a", "s", "d"` | VERIFIED | On-screen pad mapped to keys, for touch devices. Statement, top level. |
| `touchscreen` | function | `touchscreen()` | VERIFIED | Returns 1 on a touch device. |

## Physics

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `aim3d` | function | `aim3d(range)` | VERIFIED | What the camera is looking at, or -1. |
| `bump3d` | function | `bump3d(x, y, z, radius)` | VERIFIED | Returns 1 if a ball there overlaps something solid. Test one axis at a time for wall-sliding. |
| `ground3d` | function | `ground3d(x, z, maxDrop)` | VERIFIED | Height of the floor under a point, or -99999. |
| `hit3d` | function | `hit3d(x, y, z, dx, dy, dz, range)` | VERIFIED | Distance to the first solid along a ray, or -1. Hits real triangles, not boxes. |
| `hitid3d` | function | `hitid3d()` | VERIFIED | Which object the last hit3d, bump3d or aim3d found. |
| `kick3d` | statement | `kick3d id, vx, vy, vz` | VERIFIED | Sets velocity, in cm per second. Statement. |
| `phys3d` | statement | `phys3d id, bounce, friction` | VERIFIED | Makes an object a rigid body, each 0-100. Statement. For loose objects such as a ball, not for characters. |
| `rest3d` | function | `rest3d(id)` | VERIFIED | Returns 1 once a body has settled. |
| `solid3d` | statement | `solid3d id, 0` | VERIFIED | Turns collision off (0) or on (1) for one object. Statement. Everything with a mesh is solid by default. |
| `spin3d` | statement | `spin3d id, sx, sy, sz` | VERIFIED | Sets spin, which curves the flight (Magnus). Statement. |
| `vel3d` | function | `vel3d(id, axis)` | VERIFIED | Velocity per axis, cm per second. |
| `where3d` | function | `where3d(id, axis)` | VERIFIED | Position in cm. axis 0=x, 1=y, 2=z. |

## Effects

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `burst3d` | statement | `burst3d x, y, z, "#rrggbb", count, speed` | VERIFIED | A particle burst. Max 300 per call. Statement. One shared pool; no emitter shapes. |
| `flash3d` | statement | `flash3d "#rrggbb", ms` | VERIFIED | One frame of flat colour over the scene. Statement. Impact frames. |
| `hitstop3d` | statement | `hitstop3d ms` | VERIFIED | Freezes the world briefly. Statement. |
| `slowmo3d` | statement | `slowmo3d percent, ms` | VERIFIED | Slows the whole world. Statement. |
| `trail3d` | statement | `trail3d id, "#rrggbb", width, lifeMs` | VERIFIED | A ribbon following where an object has been. Statement. trail3d id, "", 0, 0 stops it. |

## Audio

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `audio` | statement | `audio name = "file.mp3"` | IMPLEMENTED | Loads a sound. Top level. |
| `music` | statement | `music "file.mp3"` | IMPLEMENTED | Plays looping background music. Statement. |
| `sound` | statement | `sound name` | IMPLEMENTED | Plays a loaded sound. Statement. |
| `volume` | statement | `volume percent` | VERIFIED | Sets volume, 0-100. Statement. |

## Assets

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `draw` | statement | `draw sprite at x, y flipped glow` | IMPLEMENTED | Draws a sprite. Statement. Options optional. |
| `image` | statement | `image name = "file.png"` | IMPLEMENTED | Loads an image. Top level. |
| `sprite` | statement | `sprite name = image at x, y size w, h frames n` | IMPLEMENTED | Cuts a sprite out of an image. Top level. frames is optional. |

## Saves

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `save` | statement | `save "key", value` | VERIFIED | Stores a value in the browser. Statement. |
| `saved` | function | `saved("key", fallback)` | VERIFIED | Reads a stored value. |

## Files

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `envVar` | function | `envVar(name)` | PARTIAL | Reads an environment variable. #js only. Rejected in #html. |
| `readFile` | function | `readFile(path)` | PARTIAL | Reads a text file. #js only. Rejected in #html. |
| `writeFile` | function | `writeFile(path, text)` | PARTIAL | Writes a text file. #js only. Rejected in #html. |

## Networking

| Name | Kind | Signature | Status | What it does |
| --- | --- | --- | --- | --- |
| `fetchText` | function | `fetchText(url)` | IMPLEMENTED | Fetches a URL as text. #js only. The only networking in Volt. |
