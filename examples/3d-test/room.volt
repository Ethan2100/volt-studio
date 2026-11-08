#html
// 3D test room: WASD to walk, mouse to look (click first)
title "3D test"
canvas 320, 180
world3d "#05060a" fog 1600 ambient 5 shadows

let floor = block3d(0, -5, 0, 1200, 10, 1200, "#6a6f78")
let ceil = block3d(0, 300, 0, 1200, 10, 1200, "#4a4d55")
let w1 = block3d(0, 150, -600, 1200, 300, 20, "#7b808a")
let w2 = block3d(0, 150, 600, 1200, 300, 20, "#7b808a")
let w3 = block3d(-600, 150, 0, 20, 300, 1200, "#7b808a")
let w4 = block3d(600, 150, 0, 20, 300, 1200, "#7b808a")
let pillar = block3d(150, 150, -200, 60, 300, 60, "#555a63")
let crate = block3d(-200, 40, -250, 80, 80, 80, "#8a6a3a")
let cell = block3d(300, 120, 100, 20, 30, 20, "#4de1ff")
glow3d cell, "#4de1ff"
let lamp = lamp3d(300, 140, 100, "#4de1ff", 20, 500)

let px = 0
let pz = 400
let yaw = 0
let pitch = 0

torch3d 60, 1800

every frame {
  yaw += mousedx() * 3
  pitch -= mousedy() * 3
  pitch = constrain(pitch, -800, 800)
  let fx = sin(yaw)
  let fz = 0 - cos(yaw)
  if held("w") { px += fx * 4 / 1000
    pz += fz * 4 / 1000 }
  if held("s") { px -= fx * 4 / 1000
    pz -= fz * 4 / 1000 }
  if held("a") { px -= cos(yaw) * 4 / 1000
    pz -= sin(yaw) * 4 / 1000 }
  if held("d") { px += cos(yaw) * 4 / 1000
    pz += sin(yaw) * 4 / 1000 }
  camera3d px, 165, pz, yaw, pitch
  turn3d cell, yaw
  render3d
  write "WASD + mouse (click to capture)" at 160, 6 centered shadow
}
