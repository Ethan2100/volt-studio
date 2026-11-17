// =====================================================================
// BLADE — a swordsman and four abilities, written in Volt.
//
// Everything here runs through Volt's own engine. The character and all
// 43 clips ship with Volt ("@male", "@animations", CC0 by Quaternius), so
// this file needs no assets beside it.
//
// The abilities are built from the pieces the engine actually has:
//   once3d     fires a clip once and can re-fire it mid-swing
//   bone3d     poses a bone on top of the clip, for the lunge and the
//              recoil, because the library has no combat follow-through
//   socket3d   keeps the blade in his right hand through every frame
//   burst3d    the spark and dust
//   hitstop3d  freezes everything for a beat on contact
//   slowmo3d   drops the whole world into slow motion for the heavy
//   shake3d    kicks the camera
//
//   WASD   move        SHIFT  sprint
//   J      slash       K      heavy (hold to charge)
//   L      thrust      SPACE  dash
// =====================================================================
#html

title "Blade"
canvas 480, 270
world3d "#1a2230" fog 5200 ambient 62 fov 74 shadows
look3d 1, "#2a3a52"
toon3d 4, 5, 52
fx3d 26, 26, 5

model3d body = "@male"
model3d moves = "@animations"

let INK = "#0a0d13"
let LINE = "#eef3f8"
let EDGE = "#6fd6ff"
let HEAT = "#ff8a3c"

// ---------------------------------------------------------------------
// The arena: a stone platform ringed by pillars, lit cold from above and
// warm from the braziers, so the blade reads bright against the floor.
// ---------------------------------------------------------------------
fn pillar(ang, r, lit) {
  let x = sin3(ang) / 1000.0 * r
  let z = cos3(ang) / 1000.0 * r
  cyl3d(number(x), 190, number(z), 46, 380, "#39414f")
  block3d(number(x), 390, number(z), 130, 36, 130, "#454e5e")
  if lit {
    lamp3d(number(x * 0.82), 260, number(z * 0.82), "#ff8e42", 26, 1150)
  }
}

fn buildArena() {
  block3d(0, 0 - 20, 0, 2600, 40, 2600, "#2b3340")
  block3d(0, 2, 0, 1700, 6, 1700, "#353e4d")
  block3d(0, 5, 0, 1180, 6, 1180, "#3d4759")
  let n = 0
  while n < 8 {
    pillar(number(n * 450), 1120.0, n % 2 == 0)
    n = n + 1
  }
  // only the four corner braziers are lit; eight point lights on one toon
  // surface is enough to saturate its brightest band everywhere
  lamp3d(0, 720, 0, "#bfe2ff", 52, 3000)
}

// ---------------------------------------------------------------------
// Him.
// ---------------------------------------------------------------------
let hero = 0
let blade = 0
let hx = 0.0
let hz = 0.0
let hyaw = 0.0
let speed = 0.0

// One timer per ability. While any is above zero he is committed to it,
// which is what stops you cancelling a swing by walking away.
let actT = 0.0
let actKind = 0        // 1 slash  2 heavy  3 thrust  4 dash
let lunge = 0.0
let charge = 0.0
let combo = 0
let comboT = 0.0
let facing = 0.0

fn buildHero() {
  hero = put3d(body, 0, 0, 0, 0, 100)
  solid3d hero, 0
  clips3d hero, moves
  anim3d hero, "Sword_Idle"

  // a plain dark tunic, so he is not a bare mannequin
  let shirt = block3d(0, 0, 0, 42, 56, 26, "#2f3b4e")
  solid3d shirt, 0
  socket3d hero, "spine_02", shirt
  let belt = block3d(0, 0, 0, 38, 20, 26, "#1d242f")
  solid3d belt, 0
  socket3d hero, "pelvis", belt

  // the blade itself: a long thin slab plus a crossguard, hung off the
  // right hand so it follows every frame of every clip
  blade = block3d(0, 0, 0, 7, 150, 20, "#cfe6f5")
  solid3d blade, 0
  socket3d hero, "hand_r", blade
  glow3d blade, "#1d3a4d"
}

// ---------------------------------------------------------------------
// Dummies to hit. They flash, get knocked back, and fall over.
// ---------------------------------------------------------------------
Dummy = type { rig: int, x: float, z: float, hp: int, hurt: float, down: float, kx: float, kz: float }
let dummies = []

fn spawnDummy(x, z) {
  let r = put3d(body, x, 0, z, 0, 98)
  solid3d r, 0
  clips3d r, moves
  anim3d r, "Idle_Loop"
  let coat = block3d(0, 0, 0, 42, 56, 26, "#5a2730")
  solid3d coat, 0
  socket3d r, "spine_02", coat
  add Dummy { rig: r, x: x, z: z, hp: 100, hurt: 0.0, down: 0.0, kx: 0.0, kz: 0.0 } to dummies
  return 0
}

fn hurtDummy(i, damage, px, pz) {
  let d = dummies[i]
  if d.down > 0.0 { return 0 }
  dummies[i].hp = d.hp - damage
  dummies[i].hurt = 0.25
  // knock them back along the line from the blow
  let dx = d.x - px
  let dz = d.z - pz
  let mag = sqrt(number(dx * dx + dz * dz))
  if mag > 1.0 {
    dummies[i].kx = dx / mag * 260.0
    dummies[i].kz = dz / mag * 260.0
  }
  burst3d number(d.x), 110, number(d.z), EDGE, 26, 320
  once3d d.rig, "Hit_Chest"
  combo = combo + 1
  comboT = 1.6
  if dummies[i].hp <= 0 {
    dummies[i].down = 2.6
    once3d d.rig, "Death01"
    burst3d number(d.x), 90, number(d.z), HEAT, 40, 420
    shake3d 50, 180
  }
  return 0
}

// Everything within reach of a swing, in an arc in front of him.
fn strikeArc(reach, arc, damage) {
  let fx = sin3(number(hyaw * 10.0)) / 1000.0
  let fz = cos3(number(hyaw * 10.0)) / 1000.0
  let hitAny = 0
  let i = 0
  while i < length(dummies) {
    let d = dummies[i]
    if d.down <= 0.0 {
      let dx = d.x - hx
      let dz = d.z - hz
      let mag = sqrt(number(dx * dx + dz * dz))
      if mag < reach and mag > 1.0 {
        // dot product of the way he faces against the way the target lies
        let dot = (dx / mag) * fx + (dz / mag) * fz
        if dot > arc {
          hurtDummy(i, damage, hx, hz)
          hitAny = 1
        }
      }
    }
    i = i + 1
  }
  return hitAny
}

// ---------------------------------------------------------------------
// Abilities.
//
// Each one is the same shape: commit a timer, fire a clip, and let the
// per-frame pose function add the part the clip does not have.
// ---------------------------------------------------------------------
fn slash() {
  actKind = 1
  actT = 0.42
  lunge = 150.0
  once3d hero, "Sword_Attack"
  burst3d number(hx + sin3(number(hyaw * 10.0)) / 1000.0 * 90.0), 120, number(hz + cos3(number(hyaw * 10.0)) / 1000.0 * 90.0), EDGE, 16, 260
  return 0
}

fn heavy(power) {
  actKind = 2
  actT = 0.78
  lunge = 90.0 + power * 180.0
  once3d hero, "Sword_Attack"
  // the whole world drops into slow motion for a beat - this is the one
  // ability that is worth the interruption
  slowmo3d 34, 320
  bars3d 1
  shake3d number(40 + power * 50.0), 260
  return 0
}

fn thrust() {
  actKind = 3
  actT = 0.34
  lunge = 260.0
  once3d hero, "Punch_Cross"
  return 0
}

fn dash() {
  actKind = 4
  actT = 0.42
  lunge = 620.0
  once3d hero, "Roll"
  burst3d number(hx), 40, number(hz), "#8ea6bd", 22, 200
  return 0
}

// The follow-through the clip library does not contain: a lean into the
// swing, and the blade angle through the arc.
fn poseAction() {
  if actT <= 0.0 {
    bone3d hero, "spine_02", 0, 0, 0
    bone3d hero, "upperarm_r", 0, 0, 0
    return 0
  }
  if actKind == 1 {
    let t = 1.0 - actT / 0.42
    bone3d hero, "spine_02", number(0 - 120.0 + t * 300.0), 0, 0
    bone3d hero, "upperarm_r", number(0 - 420.0 + t * 980.0), 0, 0
  }
  if actKind == 2 {
    let t = 1.0 - actT / 0.78
    bone3d hero, "spine_02", number(0 - 260.0 + t * 520.0), 0, number(140.0 - t * 280.0)
    bone3d hero, "upperarm_r", number(0 - 620.0 + t * 1400.0), 0, 0
  }
  if actKind == 3 {
    let t = 1.0 - actT / 0.34
    bone3d hero, "spine_02", number(0 - 60.0 + t * 160.0), 0, 0
    bone3d hero, "upperarm_r", number(700.0 - t * 260.0), 0, 0
  }
  if actKind == 4 {
    bone3d hero, "spine_02", 0, 0, 0
    bone3d hero, "upperarm_r", 0, 0, 0
  }
  return 0
}

// The moment in each swing where the blade is actually out in front.
fn checkStrike(dt) {
  if actT <= 0.0 { return 0 }
  let hitNow = 0
  if actKind == 1 {
    let t = 1.0 - actT / 0.42
    if t > 0.38 and t < 0.56 { hitNow = strikeArc(170.0, 0.35, 14) }
  }
  if actKind == 2 {
    let t = 1.0 - actT / 0.78
    if t > 0.44 and t < 0.66 { hitNow = strikeArc(210.0, 0.0 - 0.2, 42) }
  }
  if actKind == 3 {
    let t = 1.0 - actT / 0.34
    if t > 0.3 and t < 0.5 { hitNow = strikeArc(230.0, 0.72, 22) }
  }
  if hitNow == 1 {
    // the beat of nothing that makes a hit feel like contact
    hitstop3d 70
    shake3d 34, 140
  }
  return 0
}

// ---------------------------------------------------------------------
// Input and movement.
// ---------------------------------------------------------------------
let camYaw = 0.0
let kHeld = false
let busy = false

fn control(dt) {
  busy = actT > 0.0

  let fx = 0.0
  let fz = 0.0
  if held("w") { fz = 1.0 }
  if held("s") { fz = 0 - 1.0 }
  if held("a") { fx = 0 - 1.0 }
  if held("d") { fx = 1.0 }

  let top = 300.0
  if held("shift") { top = 520.0 }
  if busy { top = 0.0 }

  if fx != 0.0 or fz != 0.0 {
    let c = cos3(number(camYaw * 10.0)) / 1000.0
    let s = sin3(number(camYaw * 10.0)) / 1000.0
    let wx = fx * c + fz * s
    let wz = fz * c - fx * s
    let mag = sqrt(number(wx * wx + wz * wz))
    speed = speed + 1100.0 * dt
    if speed > top { speed = top }
    if busy == false {
      hx = hx + wx / mag * speed * dt
      hz = hz + wz / mag * speed * dt
      hyaw = atan2(number(wx * 1000.0), number(wz * 1000.0)) / 10.0
    }
  }
  if fx == 0.0 and fz == 0.0 {
    speed = speed * 0.8
  }

  // the lunge each ability carries him forward by
  if lunge > 0.0 {
    let push = lunge * dt * 4.0
    hx = hx + sin3(number(hyaw * 10.0)) / 1000.0 * push
    hz = hz + cos3(number(hyaw * 10.0)) / 1000.0 * push
    lunge = lunge * 0.86
    if lunge < 4.0 { lunge = 0.0 }
  }

  // stay on the platform
  if hx > 820.0 { hx = 820.0 }
  if hx < 0 - 820.0 { hx = 0 - 820.0 }
  if hz > 820.0 { hz = 820.0 }
  if hz < 0 - 820.0 { hz = 0 - 820.0 }

  if busy == false {
    if held("j") { slash() }
    if held("l") { thrust() }
    if held("space") { dash() }
    if held("k") {
      charge = charge + dt
      if charge > 1.0 { charge = 1.0 }
    }
    if held("k") == false and charge > 0.08 {
      heavy(charge)
      charge = 0.0
    }
  }
  return 0
}

// Locomotion, only while he is not committed to a swing.
fn legs() {
  if actT > 0.0 { return 0 }
  if speed < 20.0 {
    blend3d hero, "Sword_Idle", "Walk_Loop", 0
    return 0
  }
  if speed < 300.0 {
    blend3d hero, "Walk_Loop", "Jog_Fwd_Loop", number(speed / 300.0 * 100.0)
    return 0
  }
  blend3d hero, "Jog_Fwd_Loop", "Sprint_Loop", number((speed - 300.0) / 220.0 * 100.0)
  return 0
}

fn stepDummies(dt) {
  let i = 0
  while i < length(dummies) {
    let d = dummies[i]
    if d.hurt > 0.0 { dummies[i].hurt = d.hurt - dt }
    if d.down > 0.0 {
      dummies[i].down = d.down - dt
      if dummies[i].down <= 0.0 {
        // back on their feet for another round
        dummies[i].hp = 100
        move3d d.rig, number(d.x), 0, number(d.z)
        anim3d d.rig, "Idle_Loop"
      }
    }
    // slide out from the knockback
    dummies[i].x = d.x + d.kx * dt
    dummies[i].z = d.z + d.kz * dt
    dummies[i].kx = d.kx * 0.86
    dummies[i].kz = d.kz * 0.86
    move3d d.rig, number(dummies[i].x), 0, number(dummies[i].z)
    // always face him
    let ang = atan2(number((hx - dummies[i].x) * 1000.0), number((hz - dummies[i].z) * 1000.0))
    turn3d d.rig, number(ang)
    i = i + 1
  }
  return 0
}

// ---------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------
fn hud() {
  write "BLADE" at 16, 12 color LINE

  if charge > 0.02 {
    box 165, 248, 150, 9 color INK
    let hex = EDGE
    if charge > 0.8 { hex = HEAT }
    box 167, 250, number(146.0 * charge), 5 color hex
    write "HEAVY" at 240, 236 color hex centered
  }

  if comboT > 0.0 and combo > 1 {
    write text(combo) + " HIT" at 240, 60 color HEAT centered
  }

  write "J slash   K heavy   L thrust   SPACE dash" at 240, 258 color "#5d6b7c" centered
}

// ---------------------------------------------------------------------
buildArena()
buildHero()
spawnDummy(420.0, 520.0)
spawnDummy(0 - 460.0, 430.0)
spawnDummy(120.0, 0 - 520.0)

every frame {
  let dt = 0.016

  camYaw = camYaw + number(mousedx()) / 6.0

  control(dt)
  if actT > 0.0 { actT = actT - dt }
  if comboT > 0.0 {
    comboT = comboT - dt
    if comboT <= 0.0 { combo = 0 }
  }

  checkStrike(dt)
  poseAction()
  legs()
  stepDummies(dt)

  move3d hero, number(hx), 0, number(hz)
  turn3d hero, number(hyaw * 10.0)

  let cx = hx - sin3(number(camYaw * 10.0)) / 1000.0 * 400.0
  let cz = hz - cos3(number(camYaw * 10.0)) / 1000.0 * 400.0
  camera3d number(cx), 260, number(cz), number(camYaw * 10.0), 0 - 110

  render3d
  hud()
}
