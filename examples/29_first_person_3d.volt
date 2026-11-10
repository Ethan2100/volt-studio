#html
// A first-person 3D room in about 40 lines.
// Click the page, then: WASD or arrows to walk, mouse to look, Space to jump, Shift to run.
// Walls, the stairs and the crates are solid without any collision code: player3d + walk3d do it.
title "First person"
canvas 320, 180
world3d "#0a0d14" fog 2600 ambient 9 shadows
fx3d 55, 35, 8
ao3d 70

// the room: floor, four walls, a staircase up to a platform
block3d(0, -10, 0, 1600, 20, 1600, "#5c6470")
block3d(0, 200, -800, 1600, 400, 20, "#737a86")
block3d(0, 200, 800, 1600, 400, 20, "#737a86")
block3d(-800, 200, 0, 20, 400, 1600, "#737a86")
block3d(800, 200, 0, 20, 400, 1600, "#737a86")
for i from 0 to 5 {
  block3d(-300 + i * 60, 15 + i * 30, -500, 60, 30 + i * 60, 240, "#8a6a3a")
}
block3d(250, 165, -500, 500, 30, 240, "#8a6a3a")
freeze3d

// things that can change stay out of freeze3d: three crates and a glowing orb
let crates = []
for i from 0 to 2 {
  add block3d(-250 + i * 250, 40, 200, 80, 80, 80, "#b07a3c") to crates
}
let orb = ball3d(250, 250, -500, 25, "#4de1ff")
glow3d orb, "#4de1ff"
lamp3d(250, 260, -500, "#4de1ff", 45, 900)
lamp3d(-400, 330, 300, "#ffb070", 55, 1400)

player3d 0, 0, 500 speed 420
let score = 0

every frame {
  walk3d

  // look at a crate and click to collect it
  let target = aim3d(350)
  for each crate in crates {
    if crate == target { color3d crate, "#ffd23f" } else { color3d crate, "#b07a3c" }
  }
  if clicked() and contains(crates, target) {
    burst3d hitx(), hity(), hitz(), "#ffd23f", 60, 300
    remove3d target
    remove crates[indexOf(crates, target)]
    score++
    tone 660 to 990 for 120ms
  }

  render3d
  write "Crates: {score}/3" at 6, 6 shadow
  box 159, 89, 2, 2 color "#ffffff"
  if not locked3d() { write "Click to play" at 160, 84 centered shadow }
}
