#html
// Four strikes - the 3D effects, one key each.
//
//   Q  slash      a curved blade arc that sweeps and fades
//   E  circle     a magic circle on the ground, two rings turning
//   R  stomp      a shockwave ring racing outwards
//   F  beam       a glowing beam down the way you are looking
//
// They all take a position in cm and a colour, and they clean themselves
// up - fire one off and forget about it.
title "Four Strikes"
canvas 320, 180

import "game.volt"

WALK_SPEED = 420
RUN_SPEED = 800

world3d "#070a12" fog 3000 ambient 14 fov 75 shadows
let Floor = block3d(0, -5, 0, 2400, 10, 2400, "#4a4f59")
let Pillar1 = cyl3d(-300, 150, -500, 40, 300, "#5d636f")
let Pillar2 = cyl3d(300, 150, -500, 40, 300, "#5d636f")
let Dummy = block3d(0, 90, -500, 70, 180, 70, "#7a5c3a")

clearSolids()
solid(0, 0, 1200, 1200, -10, 0)
solid(-300, -500, 40, 40, 0, 300)
solid(300, -500, 40, 40, 0, 300)
solid(0, -500, 35, 35, 0, 180)

fx3d 70, 30, 6      // bloom makes the effects glow properly
torch3d 30, 1400
playerStart(0, 400, 0)

let cool = 0
let shown = "Q slash · E circle · R stomp · F beam"

every frame {
  playerStep()

  // a point about 2 m in front of the player, where the effects go off
  let fx = PLAYER_X + sin3(PLAYER_YAW) * 200 / 1000
  let fz = PLAYER_Z - cos3(PLAYER_YAW) * 200 / 1000

  if cool > 0 {
    cool -= 1
  }

  if held("q") and cool == 0 {
    slash3d fx, PLAYER_Y + 120, fz, PLAYER_YAW, 240, "#dff3ff"
    burst3d fx, PLAYER_Y + 120, fz, "#ffffff", 18, 360
    cool = 18
    shown = "slash"
  }
  if held("e") and cool == 0 {
    magic3d fx, PLAYER_Y, fz, 340, "#9d6bff", 1600
    cool = 30
    shown = "magic circle"
  }
  if held("r") and cool == 0 {
    shock3d PLAYER_X, PLAYER_Y, PLAYER_Z, 520, "#ffd23f"
    burst3d PLAYER_X, PLAYER_Y + 20, PLAYER_Z, "#ffd23f", 30, 260
    cool = 26
    shown = "stomp"
  }
  if held("f") and cool == 0 {
    let tx = PLAYER_X + sin3(PLAYER_YAW) * 1200 / 1000
    let tz = PLAYER_Z - cos3(PLAYER_YAW) * 1200 / 1000
    beam3d PLAYER_X, PLAYER_Y + 140, PLAYER_Z, tx, PLAYER_Y + 140, tz, 30, "#ff5a4d"
    cool = 34
    shown = "beam"
  }

  render3d

  write shown at 160, 16 centered shadow
  write "Q slash · E circle · R stomp · F beam" at 160, 168 centered shadow
}
