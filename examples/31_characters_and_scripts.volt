#html
// Keep Away - a guard chases you while a campfire burns.
//
// This is the shape World Studio writes when a world has characters,
// scripts and effects in it: things inside other things become groups,
// an effect becomes a `vfx_` function, a script becomes a `script_`
// function, and worldStart / worldStep decide when each one runs.
title "Keep Away"
canvas 320, 180

import "game.volt"         // the player
import "characters.volt"   // actors: walk to a point, turn, animate

// ============================ SETTINGS ============================
WALK_SPEED = 450
RUN_SPEED = 820
JUMP_POWER = 450
EYE_HEIGHT = 165

let GUARD_SPEED = 300      // how fast the guard follows you
let SAFE = 150             // how close the guard has to get to catch you

// >>> world-studio  (World Studio writes this part - press "Save world" to update it)
world3d "#0b1018" fog 2600 ambient 16 fov 75 shadows

model3d hunter_model = "hunter.glb"
model3d wolf_model = "wolf.glb"

let Floor = block3d(0, -5, 0, 2400, 10, 2400, "#4f5560")
let Rock = block3d(-400, 60, -300, 220, 120, 180, "#6a6f78")
let Campfire = cyl3d(300, 20, 200, 60, 40, "#3a2d22")
let Ember = ball3d(300, 50, 200, 22, "#ff6a2a")
glow3d Ember, "#ff8a3a"
let Guard = put3d(hunter_model, 0, 0, -600, 0, 100)
anim3d Guard, "idle"
let Wolf = put3d(wolf_model, 500, 0, -500, 0, 100)
turn3d Wolf, 1800

// The fire and its ember move together
let Campfire_group = group3d(300, 20, 200)
join3d Campfire, Campfire_group
join3d Ember, Campfire_group

fx3d 55, 35, 10
torch3d 40, 1500

// What the player bumps into: middle, half-width, half-depth, bottom, top (cm).
clearSolids()
solid(0, 0, 1200, 1200, -10, 0)
solid(-400, -300, 110, 90, 0, 120)
solid(300, 200, 60, 60, 0, 40)

// Where the player starts
playerStart(0, 700, 0)

// ---- effects ----
// Flames (inside Campfire) - Fire
fn vfx_Flames() {
  burst3d 300, 70, 200, "#ff6a2a", 26, 150
}
// Caught (inside Guard) - Impact
fn vfx_Caught() {
  burst3d 0, 80, -600, "#c0392b", 34, 420
}

// ---- scripts ----
// Patrol (inside Guard) - When the game starts
fn script_Patrol() {
  guardIndex = actor(Guard, 0, -600, 0)
}

// ---- when the scripts and effects run ----
let ws_tick = 0
fn worldStart() {
  script_Patrol()
}
fn worldStep() {
  ws_tick += 1
  if ws_tick % 6 == 0 {
    vfx_Flames()
  }
}
// <<< world-studio

// ============================ YOUR GAME ============================
let guardIndex = 0
let caught = false
let escaped = 0

worldStart()

every frame {
  playerStep()
  worldStep()

  if not caught {
    actorWalkTo(guardIndex, PLAYER_X, PLAYER_Z, GUARD_SPEED)
    if actorNear(guardIndex, PLAYER_X, PLAYER_Z, SAFE) {
      caught = true
      vfx_Caught()
    }
  }
  actorsStep()

  // standing by the fire is safe - it pushes the guard back to its post
  if playerNear(300, 200, 220) and not caught {
    escaped += 1
    actorWalkTo(guardIndex, 0, -600, GUARD_SPEED)
  }

  render3d

  if caught {
    write "The guard got you - refresh to try again" at 160, 90 centered shadow
  } else {
    write "Keep away from the guard · the fire is safe" at 160, 168 centered shadow
    write "Safe for " + text(escaped / 60) + "s" at 10, 10 shadow
  }
}
