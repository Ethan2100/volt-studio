#html
// 3D showcase: bloom, soft shadows, shiny metal, spheres, cylinders and sparks
// WASD to walk, mouse to look (click first)
title "3D showcase"
canvas 320, 180
world3d "#04060c" fog 2200 ambient 7 shadows

let floor = block3d(0, -5, 0, 1400, 10, 1400, "#59606c")
let ceil = block3d(0, 360, 0, 1400, 10, 1400, "#3b3f48")
let w1 = block3d(0, 180, -700, 1400, 360, 20, "#6a707b")
let w2 = block3d(0, 180, 700, 1400, 360, 20, "#6a707b")
let w3 = block3d(-700, 180, 0, 20, 360, 1400, "#6a707b")
let w4 = block3d(700, 180, 0, 20, 360, 1400, "#6a707b")

let p1 = cyl3d(-300, 150, -300, 35, 300, "#8a8f99")
let p2 = cyl3d(300, 150, -300, 35, 300, "#8a8f99")
let steel = ball3d(-120, 70, -120, 70, "#c8ccd4")
shine3d steel, 18, 100
let gold = ball3d(120, 70, -120, 70, "#e0b050")
shine3d gold, 30, 100
let gloss = ball3d(0, 45, 120, 45, "#c03a3a")
shine3d gloss, 10, 0

let orb = ball3d(0, 190, -300, 22, "#4de1ff")
glow3d orb, "#4de1ff"
let orblight = lamp3d(0, 190, -300, "#4de1ff", 45, 900)
let warm = lamp3d(-400, 300, 200, "#ffb070", 40, 1100)

fx3d 60, 45, 10

let px = 0
let pz = 520
let yaw = 0
let pitch = 0
let t = 0

every frame {
  yaw += mousedx() * 3
  pitch -= mousedy() * 3
  pitch = constrain(pitch, -800, 800)
  let fx = sin3(yaw)
  let fz = 0 - cos3(yaw)
  if held("w") { px += fx * 4 / 1000
    pz += fz * 4 / 1000 }
  if held("s") { px -= fx * 4 / 1000
    pz -= fz * 4 / 1000 }
  if held("a") { px -= cos3(yaw) * 4 / 1000
    pz -= sin3(yaw) * 4 / 1000 }
  if held("d") { px += cos3(yaw) * 4 / 1000
    pz += sin3(yaw) * 4 / 1000 }
  t += 1
  if t > 90 {
    burst3d 0, 190, -300, "#4de1ff", 70, 380
    t = 0
  }
  camera3d px, 165, pz, yaw, pitch
  render3d
  write "WASD + mouse (click to capture)" at 160, 6 centered shadow
}
