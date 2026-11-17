# Verified examples

Each program here was compiled with `compiler/volt.js` and then loaded in a
real browser and run for several seconds, with page and console errors
captured. They are starting points, not demos.

| File | Shows |
| --- | --- |
| `01_character_and_camera.volt` | Loading a character, lending it clips, speed-blended locomotion, wall sliding with `bump3d`, a lagged third-person camera with the yaw convention handled |
| `02_combat_and_enemies.volt` | A sword socketed at its grip, a timed swing with a dot-product hit arc, `hitstop3d`/`flash3d`/`trail3d` on contact, and enemies on a hand-written state machine |
| `03_rpg_systems.volt` | Inventory with stacking, quest progress, an NPC you can talk to, a save system flattened to numbered keys, and a HUD built from the rounded UI layer |

Open any of them in Volt Studio and press F5.

Each one is annotated at the point where the engine's behaviour is not
obvious — the camera's inverted yaw, the socket offset that puts the hand on
the hilt, and the fact that the built-in characters carry no clips of their
own.
