#html
// Cell Run - a small first-person game in the shape World Studio writes.
//
// A game file has three parts:
//   1. SETTINGS   - plain numbers you can change
//   2. the WORLD  - between the >>> and <<< lines; World Studio rewrites it
//   3. YOUR GAME  - everything after it, which is yours
//
// Open the World Studio tab and press "Load the world from the file" in the
// ⋯ menu to edit this room by hand, then "Save world" to write it back -
// the settings and the game below are left exactly as they are.
title "Cell Run"
canvas 320, 180

import "game.volt"   // the player: looking, walking, running, jumping, gravity

// ============================ SETTINGS ============================
WALK_SPEED = 420       // how fast you walk, in cm a second
RUN_SPEED = 800        // ... while holding Shift
JUMP_POWER = 460       // how high you jump
GRAVITY = 1500         // how hard you fall
EYE_HEIGHT = 165       // how tall the player is
MOUSE_SPEED = 3        // how fast the mouse turns you
HEAD_BOB = 4           // how much the view bounces as you walk (0 = off)

// >>> world-studio  (World Studio writes this part - press "Save world" to update it)
world3d "#05060a" fog 1800 ambient 10 fov 75 shadows

let Floor = block3d(0, -5, 0, 1600, 10, 1600, "#5d626b")
let WallNorth = block3d(0, 150, -800, 1600, 300, 20, "#7b808a")
let WallSouth = block3d(0, 150, 800, 1600, 300, 20, "#7b808a")
let WallWest = block3d(-800, 150, 0, 20, 300, 1600, "#7b808a")
let WallEast = block3d(800, 150, 0, 20, 300, 1600, "#7b808a")
let CrateA = block3d(-300, 40, -200, 80, 80, 80, "#8a6a3a")
let CrateB = block3d(-300, 120, -280, 80, 80, 80, "#8a6a3a")
let Ledge = block3d(-300, 200, -420, 300, 20, 200, "#6a6f78")
let Pillar = block3d(320, 150, 200, 60, 300, 60, "#555a63")
let Beam = block3d(0, 120, 300, 900, 40, 40, "#4a4d55")

let CellA = block3d(-300, 230, -420, 20, 30, 20, "#4de1ff")
glow3d CellA, "#4de1ff"
let CellB = block3d(600, 40, -600, 20, 30, 20, "#4de1ff")
glow3d CellB, "#4de1ff"
let CellC = block3d(0, 40, 520, 20, 30, 20, "#4de1ff")
glow3d CellC, "#4de1ff"

fx3d 50, 30, 8
torch3d 70, 1700

// What the player bumps into: middle, half-width, half-depth, bottom, top (cm).
clearSolids()
solid(0, 0, 800, 800, -10, 0)
solid(0, -800, 800, 10, 0, 300)
solid(0, 800, 800, 10, 0, 300)
solid(-800, 0, 10, 800, 0, 300)
solid(800, 0, 10, 800, 0, 300)
solid(-300, -200, 40, 40, 0, 80)
solid(-300, -280, 40, 40, 80, 160)
solid(-300, -420, 150, 100, 190, 210)
solid(320, 200, 30, 30, 0, 300)
solid(0, 300, 450, 20, 100, 140)

// Where the player starts
playerStart(0, 600, 0)
// <<< world-studio

// ============================ YOUR GAME ============================
// Three glowing cells to collect: one on the ledge you climb the crates to
// reach, one in a far corner, and one past the low beam you have to crouch
// under. Nothing here is touched when the world is saved again.

let cellIds = [CellA, CellB, CellC]
let cellX = [-300, 600, 0]
let cellZ = [-420, -600, 520]
let taken = [false, false, false]
let score = 0

every frame {
  playerStep()

  let i = 0
  while i < length(cellIds) {
    if not taken[i] and playerNear(cellX[i], cellZ[i], 90) {
      taken[i] = true
      score += 1
      show3d cellIds[i], 0
      burst3d cellX[i], 60, cellZ[i], "#4de1ff", 60, 300
    }
    i += 1
  }

  render3d

  write "Cells " + text(score) + " / 3" at 10, 10 shadow
  if score < 3 {
    write "WASD move · Shift run · Space jump · Ctrl crouch" at 160, 168 centered shadow
  } else {
    write "All collected!" at 160, 90 centered shadow
  }
}
