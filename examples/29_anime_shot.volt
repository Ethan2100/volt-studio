#html

// Anime Shot - the smallest scene that shows what toon3d changes.
// Press SPACE to land a hit: hit stop, then camera shake, then sparks.
// Everything here is plain Volt. No raw JavaScript.

world3d "#1a1430" fog 3200 ambient 20 fov 55 shadows
toon3d 3, 35, 60        // 3 bands of light, a dark outline, a bright rim
fx3d 50, 30, 4          // anime art is bloomy - this is most of the glow

// ---- the ground and a few shapes to catch the light ----

block3d(0, 0 - 10, 0, 4000, 20, 4000, "#2a2140")          // courtyard floor
block3d(0, 140, 0 - 700, 1600, 280, 60, "#3b2f58")        // back wall
block3d(0 - 420, 150, 0, 60, 300, 60, "#4a3a6e")          // pillar, left
block3d(420, 150, 0, 60, 300, 60, "#4a3a6e")              // pillar, right

// The rim light is easiest to read on round things, so the two lanterns
// either side of the hero are the clearest proof that toon3d is working.
let lanternL = ball3d(0 - 420, 330, 0, 55, "#ffcf6b")
let lanternR = ball3d(420, 330, 0, 55, "#ffcf6b")
glow3d lanternL, "#ffcf6b"
glow3d lanternR, "#ffcf6b"
lamp3d(0 - 420, 330, 0, "#ffcf6b", 70, 900)
lamp3d(420, 330, 0, "#ffcf6b", 70, 900)

// A stand-in hero: swap these three shapes for a real model with
// model3d / put3d once you have one. toon3d styles models the same way.
let body = cyl3d(0, 90, 0, 48, 180, "#c0325a")
let head = ball3d(0, 215, 0, 52, "#f2d2bd")
let blade = cyl3d(110, 120, 0, 10, 260, "#dfe6f5")
turn3d blade, 450

// ---- camera ----

camera3d 0, 200, 700, 0, 0 - 40
lookat3d 0, 160, 0

let charge = 0
let cooled = 0

every frame {
  // A slow drift so the rim light moves across the shapes and you can see it.
  charge += 1
  turn3d body, charge * 2
  turn3d blade, 450 + charge * 2

  if cooled > 0 {
    cooled -= 1
  }

  if held("space") and cooled == 0 {
    // The order matters. Freeze first so the impact frame is the one you see,
    // then jolt the camera, then throw the sparks.
    hitstop3d 90
    shake3d 55, 220
    burst3d 110, 160, 0, "#ffd36e", 44, 300
    slowmo3d 35, 420
    cooled = 40
  }

  render3d
}
