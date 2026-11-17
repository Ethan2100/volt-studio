// VERIFIED: compiles and runs. Sword combat with a hit arc, hitstop, trails
// and impact frames, against enemies driven by a hand-written state machine.
#html
title "Combat"
canvas 480, 270
world3d "#121a26" fog 6000 ambient 90 fov 72 shadows

model3d body = "@male"
model3d moves = "@animations"

block3d(0, 0 - 20, 0, 3000, 40, 3000, "#55617a")

let hero = put3d(body, 0, 0, 0, 0, 100)
solid3d hero, 0
clips3d hero, moves
anim3d hero, "Sword_Idle"

// the sword is built 62cm up its own length, so the hand grips the hilt
let blade = block3d(0, 62, 0, 5, 94, 11, "#dceaf5")
solid3d blade, 0
socket3d hero, "hand_r", blade

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

let hx = 0.0
let hz = 0.0
let hyaw = 0.0
let actT = 0.0
let actMax = 0.4
let swung = false

fn slash() {
  if actT > 0.0 { return 0 }
  actT = 0.40
  actMax = 0.40
  swung = false
  once3d hero, "Sword_Attack"
  trail3d blade, "#7fe3ff", 52, 230
  return 0
}

// dot > arc keeps the hit in front: 0.75 narrow, 0.3 a swing, -1.1 all round
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
      let dot = (dx / mag) * fx + (dz / mag) * fz
      if dot > arc {
        foes[i].hp = f.hp - damage
        once3d f.rig, "Hit_Chest"
        burst3d number(f.x), 110, number(f.z), "#7fe3ff", 26, 320
        got = 1
      }
    }
    i = i + 1
  }
  return got
}

fn thinkFoe(i, dt) {
  let f = foes[i]
  if f.hp <= 0 { return 0 }
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

spawnFoe(400.0, 500.0)
spawnFoe(0 - 450.0, 380.0)

every frame {
  let dt = 0.016

  if held("w") { hz = hz + 220.0 * dt }
  if held("s") { hz = hz - 220.0 * dt }
  if held("a") { hx = hx - 220.0 * dt }
  if held("d") { hx = hx + 220.0 * dt }
  if held("j") { slash() }

  if actT > 0.0 {
    actT = actT - dt
    let t = 1.0 - actT / actMax
    // the wind-up and follow-through the clip library does not contain
    bone3d hero, "spine_02", number(0 - 150.0 + 360.0 * t), 0, 0
    bone3d hero, "upperarm_r", number(0 - 500.0 + 1020.0 * t), 0, 0
    if swung == false and t > 0.42 {
      swung = true
      if strikeArc(185.0, 0.3, 15) == 1 {
        hitstop3d 80
        shake3d 38, 150
        flash3d "#ffffff", 45
      }
    }
    if actT <= 0.0 {
      trail3d blade, "", 0, 0
      bone3d hero, "spine_02", 0, 0, 0
      bone3d hero, "upperarm_r", 0, 0, 0
    }
  }

  let i = 0
  while i < length(foes) {
    thinkFoe(i, dt)
    i = i + 1
  }

  move3d hero, number(hx), 0, number(hz)
  turn3d hero, number(hyaw * 10.0)
  camera3d number(hx), 260, number(hz - 420.0), 1800, 0 - 110

  render3d
  write "WASD move   J slash" at 240, 250 color "#8294aa" centered
}
