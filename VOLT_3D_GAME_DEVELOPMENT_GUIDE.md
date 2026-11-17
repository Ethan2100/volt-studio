# Building a 3D RPG in Volt

Patterns for each system a fantasy RPG needs, written against what the engine
actually has. Every snippet compiles. Where Volt cannot do something, this
says so rather than inventing a function.

Read `VOLT_SYNTAX_REFERENCE.md` first — in particular §8 on units, which is
where most lost hours go.

Working programs to read alongside this: `examples/31_swordsman.volt` (combat,
abilities, HUD) and `examples/30_striker.volt` (many agents, physics, cameras).

---

## The shape of a game

```volt
#html
title "My RPG"
canvas 480, 270
world3d "#121a26" fog 7000 ambient 90 fov 72 shadows

model3d body  = "@male"
model3d moves = "@animations"

let hero = put3d(body, 0, 0, 0, 0, 100)
clips3d hero, moves
anim3d hero, "Idle_Loop"

every frame {
  let dt = 0.016
  // ... read input, move things, set the camera ...
  render3d          // physics, animation and drawing
  hud()             // the 2D layer, after render3d, which clears it
}
```

`render3d` clears the 2D layer, so **the HUD is drawn after it, not before**.
Top-level statements run once at start-up; `fn main()` is never called.

---

## 1. The player character

The two built-in characters carry **no animation clips** — all 43 live in
`"@animations"` — so `clips3d` is required before any animation call:

```volt
model3d body  = "@male"           // or "@female"
model3d moves = "@animations"

let hero = put3d(body, 0, 0, 0, 0, 100)
solid3d hero, 0                   // characters move themselves; keep them
clips3d hero, moves               // out of the static collision set
anim3d hero, "Idle_Loop"
```

The clips: `A_TPose, Crouch_Fwd_Loop, Crouch_Idle_Loop, Dance_Loop, Death01,
Driving_Loop, Fixing_Kneeling, Hit_Chest, Hit_Head, Idle_Loop,
Idle_Talking_Loop, Idle_Torch_Loop, Interact, Jog_Fwd_Loop, Jump_Land,
Jump_Loop, Jump_Start, PickUp_Table, Pistol_Aim_Down, Pistol_Aim_Neutral,
Pistol_Aim_Up, Pistol_Idle_Loop, Pistol_Reload, Pistol_Shoot, Punch_Cross,
Punch_Jab, Push_Loop, Roll, Sitting_Enter, Sitting_Exit, Sitting_Idle_Loop,
Sitting_Talking_Loop, Spell_Simple_Enter, Spell_Simple_Exit,
Spell_Simple_Idle_Loop, Spell_Simple_Shoot, Sprint_Loop, Swim_Fwd_Loop,
Swim_Idle_Loop, Sword_Attack, Sword_Idle, Walk_Formal_Loop, Walk_Loop`.

A partial name matches, so `anim3d hero, "jog"` finds `Jog_Fwd_Loop`.

**There are no strafe clips and no turn-in-place clips.** Characters must face
where they move.

### Equipment and armour

The base mesh is a bare torso. Clothing is geometry socketed to bones:

```volt
fn dress(rig, main, trim) {
  let chest = block3d(0, 0, 0, 34, 46, 22, main)
  solid3d chest, 0
  socket3d rig, "spine_02", chest

  let shoulderL = block3d(0, 0, 0, 15, 13, 17, trim)
  solid3d shoulderL, 0
  socket3d rig, "upperarm_l", shoulderL
  return 0
}
```

Useful bone names: `spine_02`, `spine_03`, `pelvis`, `upperarm_l`,
`upperarm_r`, `lowerarm_l`, `lowerarm_r`, `hand_l`, `hand_r`, `thigh_l`,
`thigh_r`, `calf_l`, `calf_r`, `foot_l`, `foot_r`, `head`, `neck_01`. A partial
name matches. If it misses, `socket3d` lists the model's real bones in the
error.

**A socket keeps the offset the piece was built at.** That is how a weapon is
held by its grip rather than its middle:

```volt
let blade = block3d(0, 62, 0, 5, 94, 11, "#dceaf5")   // built 62cm up
socket3d hero, "hand_r", blade                        // so the hand is at the hilt
```

Armour built at `block3d(0, 0, 0, …)` sits exactly on its bone.

### Swapping equipment

There is no "unsocket". To change a weapon, hide the old one and show the new:

```volt
show3d swordA, 0
show3d swordB, 1
```

Build every piece the character can wear at start-up and toggle visibility.
Creating objects every frame leaks them — there is no destroy.

---

## 2. Third-person camera

The one real trap. `camera3d`'s yaw runs **opposite** to the heading
convention used by `turn3d`, `sin3` and `cos3`:

```volt
let camYaw = 0.0
let camX = 0.0
let camZ = 0.0
let camLag = 0.0

every frame {
  let dt = 0.016
  camYaw = camYaw + number(mousedx()) / 6.0

  // chase a point that itself chases the player, so the camera trails
  camX = camX + (hx - camX) * 7.0 * dt
  camZ = camZ + (hz - camZ) * 7.0 * dt
  camLag = camLag + (camYaw - camLag) * 11.0 * dt

  let back = 400.0 + speed * 0.26
  let cx = camX - sin3(number(camLag * 10.0)) / 1000.0 * back
  let cz = camZ - cos3(number(camLag * 10.0)) / 1000.0 * back

  // 1800.0 - heading, or the camera looks away from the player
  camera3d number(cx), 250, number(cz), number(1800.0 - camLag * 10.0), 0 - 95
  render3d
}
```

**There is no camera collision.** `hit3d` can be cast from the player to the
camera and the distance shortened by hand, but nothing does it for you.

---

## 3. Movement

```volt
let hx = 0.0
let hz = 0.0
let hyaw = 0.0
let speed = 0.0

fn move(dt) {
  let fx = 0.0
  let fz = 0.0
  if held("w") { fz = 1.0 }
  if held("s") { fz = 0 - 1.0 }
  if held("a") { fx = 0 - 1.0 }
  if held("d") { fx = 1.0 }

  let top = 320.0
  if held("shift") { top = 560.0 }

  if fx != 0.0 or fz != 0.0 {
    // rotate input into camera space
    let c = cos3(number(camYaw * 10.0)) / 1000.0
    let s = sin3(number(camYaw * 10.0)) / 1000.0
    let wx = fx * c + fz * s
    let wz = fz * c - fx * s
    let mag = sqrt(number(wx * wx + wz * wz))

    speed = speed + 1300.0 * dt
    if speed > top { speed = top }

    // one axis at a time, which gives wall-sliding instead of sticking
    let nx = hx + wx / mag * speed * dt
    let nz = hz + wz / mag * speed * dt
    if bump3d(number(nx), 60, number(hz), 30) == 0 { hx = nx }
    if bump3d(number(hx), 60, number(nz), 30) == 0 { hz = nz }
    hyaw = atan2(number(wx * 1000.0), number(wz * 1000.0)) / 10.0
  }
  if fx == 0.0 and fz == 0.0 { speed = speed * 0.78 }

  move3d hero, number(hx), 0, number(hz)
  turn3d hero, number(hyaw * 10.0)        // tenths of a degree
  return 0
}
```

### Jumping

`phys3d` is for loose objects. A character's jump is a curve over its own
timer:

```volt
let airT = 0.0
let airY = 0.0

fn jump() {
  if airT > 0.0 { return 0 }
  airT = 0.72
  once3d hero, "Jump_Start"
  return 0
}

// in the frame block
if airT > 0.0 {
  airT = airT - dt
  let k = 1.0 - airT / 0.72
  airY = 150.0 * sin3(number(k * 1800.0)) / 1000.0
  if airT <= 0.0 { once3d hero, "Jump_Land" }
}
move3d hero, number(hx), number(airY), number(hz)
```

---

## 4. Animation

```volt
// idle -> walk -> jog -> sprint, blended by actual speed
fn legs() {
  if actT > 0.0 { return 0 }                 // committed to an action
  if speed < 24.0 {
    blend3d hero, "Sword_Idle", "Walk_Loop", 0
    return 0
  }
  if speed < 320.0 {
    blend3d hero, "Walk_Loop", "Jog_Fwd_Loop", number(speed / 320.0 * 100.0)
    return 0
  }
  blend3d hero, "Jog_Fwd_Loop", "Sprint_Loop", number((speed - 320.0) / 240.0 * 100.0)
  return 0
}
```

- `blend3d` phase-locks the two clips, so footfalls line up.
- `blend4d` is a four-corner directional blend, but the library has no strafe
  clips to put in it.
- `layer3d` plays a clip additively on top — an upper-body action while the
  legs keep running.
- `bone3d` poses one bone on top of whatever is playing, re-applied after the
  animation mixer each frame. This is how to build moves the clip library does
  not contain.

**No IK, no root motion, no animation state machine, no animation events.**
Characters slide rather than plant their feet. Action timing is done with your
own timers.

---

## 5. Sword combat

Combat is a timer, a clip, a pose, and a hit window:

```volt
let actT = 0.0
let actMax = 0.0
let swung = false

fn slash() {
  actT = 0.40
  actMax = 0.40
  swung = false
  once3d hero, "Sword_Attack"        // once3d re-fires mid-swing; anim3d does not
  trail3d blade, "#7fe3ff", 52, 230
  return 0
}

// the arc in front of the character
fn strikeArc(reach, arc, damage) {
  let fx = sin3(number(hyaw * 10.0)) / 1000.0
  let fz = cos3(number(hyaw * 10.0)) / 1000.0
  let got = 0
  let i = 0
  while i < length(foes) {
    let f = foes[i]
    let dx = f.x - hx
    let dz = f.z - hz
    let mag = sqrt(number(dx * dx + dz * dz))
    if mag < reach and mag > 1.0 {
      let dot = (dx / mag) * fx + (dz / mag) * fz    // -1 behind, 1 ahead
      if dot > arc {
        foes[i].hp = f.hp - damage
        got = 1
      }
    }
    i = i + 1
  }
  return got
}

// in the frame block: fire once, partway through the swing
if actT > 0.0 and swung == false {
  let t = 1.0 - actT / actMax
  if t > 0.42 {
    swung = true
    if strikeArc(185.0, 0.3, 15) == 1 {
      hitstop3d 80            // the beat of nothing that sells contact
      shake3d 38, 150
      flash3d "#ffffff", 45
    }
  }
}
```

`arc` is a dot-product threshold: `0.75` is a narrow thrust, `0.3` a normal
swing, `0 - 1.1` a full circle.

---

## 6. Magic

There is no projectile system. A spell is a `phys3d` object you launch, or a
`hit3d` ray you fire:

```volt
// a thrown bolt
let bolt = ball3d(0, 0, 0, 8, "#9fd8ff")
glow3d bolt, "#4fa8ff"
phys3d bolt, 10, 5
show3d bolt, 0

fn cast() {
  once3d hero, "Spell_Simple_Shoot"
  show3d bolt, 1
  move3d bolt, number(hx), 120, number(hz)
  let fx = sin3(number(hyaw * 10.0)) / 1000.0
  let fz = cos3(number(hyaw * 10.0)) / 1000.0
  kick3d bolt, number(fx * 1800.0), 120, number(fz * 1800.0)
  trail3d bolt, "#9fd8ff", 40, 300
  return 0
}

// an instant beam
fn zap() {
  let d = hit3d(number(hx), 120, number(hz), fx, 0, fz, 2000)
  if d > 0 {
    let who = hitid3d()
    burst3d number(hx + fx * d), 120, number(hz + fz * d), "#9fd8ff", 30, 400
  }
  return 0
}
```

Spell clips in the library: `Spell_Simple_Enter`, `Spell_Simple_Idle_Loop`,
`Spell_Simple_Shoot`, `Spell_Simple_Exit`.

---

## 7. Enemies and AI

One record per enemy, in a list. There is **no navmesh and no pathfinding** —
AI steers directly and tests walls with `bump3d`.

```volt
Foe = type { rig: int, x: float, z: float, hp: int, state: int, timer: float }
let foes = []

fn spawnFoe(x, z) {
  let r = put3d(body, x, 0, z, 0, 97)
  solid3d r, 0
  clips3d r, moves
  anim3d r, "Idle_Loop"
  add Foe { rig: r, x: x, z: z, hp: 100, state: 0, timer: 0.0 } to foes
  return 0
}

// 0 idle, 1 chase, 2 attack - a state machine written by hand
fn thinkFoe(i, dt) {
  let f = foes[i]
  let d = dist(number(f.x), number(f.z), number(hx), number(hz))

  if f.state == 0 and d < 900.0 { foes[i].state = 1 }
  if f.state == 1 {
    if d < 180.0 {
      foes[i].state = 2
      foes[i].timer = 0.8
      once3d f.rig, "Punch_Cross"
    }
    if d >= 180.0 {
      let dx = hx - f.x
      let dz = hz - f.z
      foes[i].x = f.x + dx / d * 150.0 * dt
      foes[i].z = f.z + dz / d * 150.0 * dt
      blend3d f.rig, "Idle_Loop", "Walk_Loop", 100
    }
  }
  if f.state == 2 {
    foes[i].timer = f.timer - dt
    if foes[i].timer <= 0.0 { foes[i].state = 1 }
  }

  move3d f.rig, number(foes[i].x), 0, number(foes[i].z)
  turn3d f.rig, number(atan2(number((hx - foes[i].x) * 1000.0), number((hz - foes[i].z) * 1000.0)))
  return 0
}
```

**Line of sight** is the one perception primitive available:

```volt
let toPlayerX = hx - f.x
let toPlayerZ = hz - f.z
let blocked = hit3d(number(f.x), 100, number(f.z), toPlayerX, 0, toPlayerZ, 1200)
// blocked < distance to the player means a wall is in the way
```

`examples/30_striker.volt` runs ten agents with roles, pressing and team shape
in this style, and is the best worked example of AI in the repository.

---

## 8. NPCs, quests, inventory

None of these are engine features. They are data plus HUD, and Volt has what
is needed:

```volt
Npc = type { rig: int, x: float, z: float, name: string, line: string, quest: int }
Item = type { name: string, kind: string, power: int, count: int }
Quest = type { id: int, title: string, need: int, got: int, done: bool }

let npcs = []
let bag = []
let quests = []

// talk when close and E is pressed
fn tryTalk() {
  let i = 0
  while i < length(npcs) {
    let n = npcs[i]
    if dist(number(n.x), number(n.z), number(hx), number(hz)) < 180.0 {
      if held("e") {
        talking = i
        anim3d n.rig, "Idle_Talking_Loop"
      }
    }
    i = i + 1
  }
  return 0
}

fn give(itemName, kind, power) {
  let i = 0
  while i < length(bag) {
    if bag[i].name == itemName {
      bag[i].count = bag[i].count + 1
      return 0
    }
    i = i + 1
  }
  add Item { name: itemName, kind: kind, power: power, count: 1 } to bag
  return 0
}
```

Useful NPC clips: `Idle_Talking_Loop`, `Sitting_Idle_Loop`, `Sitting_Talking_Loop`,
`Interact`, `PickUp_Table`, `Fixing_Kneeling`, `Push_Loop`, `Dance_Loop`.

**Lists have no sort, no find and no remove-by-value.** Write loops. `remove L[i]`
removes by index.

---

## 9. Save system

`save` and `saved` store one value each, in the browser:

```volt
fn saveGame() {
  save "hp", hp
  save "x", number(hx)
  save "z", number(hz)
  save "quest", questStage
  return 0
}

fn loadGame() {
  hp = saved("hp", 100)
  hx = number(saved("x", 0))
  hz = number(saved("z", 0))
  questStage = saved("quest", 0)
  return 0
}
```

**Only numbers and strings, one key at a time.** There is no way to serialise a
list or a record. An inventory has to be flattened by hand:

```volt
save "bagCount", length(bag)
let i = 0
while i < length(bag) {
  save "bag" + text(i) + "name", bag[i].name
  save "bag" + text(i) + "count", bag[i].count
  i = i + 1
}
```

Saves live in browser storage, so they are per-browser and lost when site data
is cleared. There is no cloud save and no save file.

---

## 10. World environments

```volt
// ground, stepped so the eye has something to read
block3d(0, 0 - 24, 0, 3400, 48, 3400, "#55617a")
block3d(0, 2, 0, 1900, 8, 1900, "#616e89")

// a pillar from several pieces, which reads as masonry rather than a tube
fn pillar(x, z) {
  block3d(x, 18, z, 128, 36, 128, "#6c7793")
  cyl3d(x, 230, z, 42, 380, "#8a95ae")
  block3d(x, 448, z, 120, 26, 120, "#7e89a4")
  return 0
}
```

Hard limits worth knowing before planning a world:

- **`block3d` cannot be rotated on its own axis.** Only `turn3d` on a whole
  object, about Y. No ramps, no arches, no anything diagonal.
- **No instancing.** Every shape is its own draw call, so a few hundred objects
  is the practical budget on integrated graphics.
- **No LOD, no occlusion culling, no streaming.** The whole world is drawn
  every frame.
- **No terrain, no heightmaps.** Ground is boxes.
- `lamp3d` halves its power argument, and a handful of lights will saturate a
  `toon3d` scene's brightest band. Four to six is plenty.

For anything organic, build it in Blender and load it with `model3d`.

---

## 11. RPG interfaces

The 2D layer has the pieces for a modern HUD:

```volt
fn panel(x, y, w, h) {
  alpha 88
  grad x, y, w, h, 14, "#1d2432", "#0c1118"
  alpha 100
  edge x, y, w, h, 14, 1 color "#3a465a"
  return 0
}

fn bar(x, y, w, h, frac, hex) {
  card x, y, w, h, number(h / 2.0) color "#121a26"
  clip number(x + 2.0), number(y + 2.0), number(w - 4.0), number(h - 4.0), number(h / 2.0 - 2.0)
  card number(x + 2.0), number(y + 2.0), number((w - 4.0) * frac), number(h - 4.0), number(h / 2.0 - 2.0) color hex
  unclip
  return 0
}

fn cooldownSlot(x, y, left, total, hex) {
  grad x, y, 40, 40, 13, "#263447", "#131b27"
  edge x, y, 40, 40, 13, 1 color "#3f5068"
  if left > 0.0 {
    sweep number(x + 20.0), number(y + 20.0), 15, number(left / total * 100.0), 3 color hex
  }
  if left <= 0.0 {
    glow hex, 9
    ring number(x + 20.0), number(y + 20.0), 15, 2 color hex
    glow "", 0
  }
  return 0
}
```

`textw(s, size)` sizes a panel to its contents, which matters for dialogue
boxes and item tooltips.

**There are no UI widgets.** No buttons, text fields, scrolling or layout.
`hot3d(x, y, w, h)` plus `clicked3d()` is the whole of mouse interaction, and
there is no hover state and no keyboard focus. A menu is drawn by hand and
navigated with keys you poll yourself.

---

## What Volt cannot do

Stated plainly, so none of it gets invented:

| Want | Status |
| --- | --- |
| Networking / multiplayer | `fetchText` in `#js` only. No sockets, no multiplayer. |
| Loading screens / scene files | None. `clear3d` and rebuild by hand. |
| Destroying an object | None. Hide with `show3d id, 0`. |
| Rotating a primitive on its axis | None. Use a model. |
| Terrain or heightmaps | None. |
| Navmesh / pathfinding | None. Steer and test with `bump3d`. |
| IK, root motion, anim state machine | None. |
| 3D positional audio | None. `sound` is flat stereo. |
| Gamepad | None. Keyboard and mouse only. |
| Saving lists or records | None. Flatten to numbered keys. |
| Custom shaders | None exposed to Volt. |
| Text wrapping or UI widgets | None. Draw by hand. |
| Instancing, LOD, culling control | None. |
| Deleting a trail's object mid-flight | `trail3d id, "", 0, 0` first. |

A large RPG is buildable on this. It will be stylised rather than photoreal,
its worlds will be built from boxes and imported models, and its systems will
be written in Volt rather than configured. That is the honest shape of the
engine today.
