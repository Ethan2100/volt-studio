// VERIFIED: compiles and runs. Player, third-person camera, movement with
// wall sliding, speed-blended locomotion. The smallest complete base for an
// RPG in Volt.
#html
title "Character"
canvas 480, 270
world3d "#121a26" fog 7000 ambient 90 fov 72 shadows

model3d body = "@male"
model3d moves = "@animations"

block3d(0, 0 - 20, 0, 4000, 40, 4000, "#55617a")
block3d(600, 90, 0, 80, 180, 900, "#6c7793")

let hero = put3d(body, 0, 0, 0, 0, 100)
solid3d hero, 0
clips3d hero, moves
anim3d hero, "Idle_Loop"

let hx = 0.0
let hz = 0.0
let hyaw = 0.0
let speed = 0.0
let camYaw = 0.0
let camX = 0.0
let camZ = 0.0
let camLag = 0.0

fn walk(dt) {
  let fx = 0.0
  let fz = 0.0
  if held("w") { fz = 1.0 }
  if held("s") { fz = 0 - 1.0 }
  if held("a") { fx = 0 - 1.0 }
  if held("d") { fx = 1.0 }

  let top = 320.0
  if held("shift") { top = 560.0 }

  if fx != 0.0 or fz != 0.0 {
    let c = cos3(number(camYaw * 10.0)) / 1000.0
    let s = sin3(number(camYaw * 10.0)) / 1000.0
    let wx = fx * c + fz * s
    let wz = fz * c - fx * s
    let mag = sqrt(number(wx * wx + wz * wz))
    speed = speed + 1300.0 * dt
    if speed > top { speed = top }
    let nx = hx + wx / mag * speed * dt
    let nz = hz + wz / mag * speed * dt
    // one axis at a time gives wall sliding instead of sticking
    if bump3d(number(nx), 60, number(hz), 30) == 0 { hx = nx }
    if bump3d(number(hx), 60, number(nz), 30) == 0 { hz = nz }
    hyaw = atan2(number(wx * 1000.0), number(wz * 1000.0)) / 10.0
  }
  if fx == 0.0 and fz == 0.0 { speed = speed * 0.78 }
  return 0
}

fn legs() {
  if speed < 24.0 {
    blend3d hero, "Idle_Loop", "Walk_Loop", 0
    return 0
  }
  if speed < 320.0 {
    blend3d hero, "Walk_Loop", "Jog_Fwd_Loop", number(speed / 320.0 * 100.0)
    return 0
  }
  blend3d hero, "Jog_Fwd_Loop", "Sprint_Loop", number((speed - 320.0) / 240.0 * 100.0)
  return 0
}

every frame {
  let dt = 0.016
  camYaw = camYaw + number(mousedx()) / 6.0
  walk(dt)
  legs()

  move3d hero, number(hx), 0, number(hz)
  turn3d hero, number(hyaw * 10.0)

  camX = camX + (hx - camX) * 7.0 * dt
  camZ = camZ + (hz - camZ) * 7.0 * dt
  camLag = camLag + (camYaw - camLag) * 11.0 * dt
  let back = 400.0 + speed * 0.26
  let cx = camX - sin3(number(camLag * 10.0)) / 1000.0 * back
  let cz = camZ - cos3(number(camLag * 10.0)) / 1000.0 * back
  // 1800.0 - heading, or the camera looks away from the player
  camera3d number(cx), 250, number(cz), number(1800.0 - camLag * 10.0), 0 - 95

  render3d
  write "WASD move   SHIFT sprint   mouse look" at 240, 250 color "#8294aa" centered
}
