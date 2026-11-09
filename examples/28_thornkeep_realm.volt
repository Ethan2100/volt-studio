// =====================================================================
// Thornkeep Realm - a walkable medieval RPG fantasy game map, in Volt.
//
// A YorusDevs video showed Claude Opus 5.5 driving Blender's official
// MCP server with plain-English prompts to place every 3D model for a
// Roblox game's world map - no manual modeling, no clicking, just
// describing what should be where. Volt has no Blender/MCP pipeline,
// but it has its own first-person 3D builtins (world3d, block3d,
// cyl3d, ball3d, lamp3d...), so this does the same kind of job the
// native Volt way: the whole map below is nothing but block3d/cyl3d/
// ball3d calls describing where a wall, a roof, a tree or a torch
// goes. No 3D software, no meshes to import - just Volt code.
//
// A castle (Thornkeep), the village around it (Millhaven), a market,
// a chapel, a lake with a bridge, farmland, two stretches of forest,
// and a watchtower keeping an eye on the south road.
//
// Click the page to look around, WASD to walk. Walk near a landmark
// and its name shows at the bottom, like a simple RPG map legend.
// =====================================================================
#html

canvas 320, 180
world3d "#2b3448" fog 5200 ambient 26 fov 78 shadows
fx3d 45, 32, 8

// ---------------------------------------------------------------------
// Building blocks - each function places a cluster of shapes for one
// kind of structure. Calling these over and over with different
// coordinates *is* the map, the same repetitive placement work the
// video did through Blender's MCP, just written out as Volt code.
// ---------------------------------------------------------------------

fn cottage(x, z, wallColor, roofColor) {
  let w = 150
  let d = 140
  block3d(x, 80, z, w, 160, d, wallColor)
  block3d(x, 175, z, w + 24, 36, d + 24, roofColor)
  cyl3d(x + w / 2 - 15, 225, z - d / 2 + 15, 10, 80, "#55504a")
}

fn wallTower(x, z, h) {
  cyl3d(x, h / 2, z, 60, h, "#6b6f78")
  cyl3d(x, h + 16, z, 68, 32, "#5a3b2a")
}

fn crenel(x, y, z, facingX) {
  if facingX {
    block3d(x, y, z, 10, 50, 50, "#5a5e68")
  } else {
    block3d(x, y, z, 50, 50, 10, "#5a5e68")
  }
}

fn tree(x, z) {
  let h = 150 + random(0, 70)
  cyl3d(x, h * 4 / 10, z, 16, h * 8 / 10, "#4a3425")
  ball3d(x, h, z, 70 + random(0, 35), "#2f6b3a")
}

fn stall(x, z, canopyColor) {
  cyl3d(x - 50, 55, z - 50, 6, 110, "#6b4f2e")
  cyl3d(x + 50, 55, z - 50, 6, 110, "#6b4f2e")
  cyl3d(x - 50, 55, z + 50, 6, 110, "#6b4f2e")
  cyl3d(x + 50, 55, z + 50, 6, 110, "#6b4f2e")
  block3d(x, 120, z, 130, 20, 130, canopyColor)
  block3d(x, 40, z, 90, 40, 90, "#8a6a3f")
}

fn fencePost(x, z) {
  block3d(x, 35, z, 8, 70, 8, "#6b4f2e")
}

// ---------------------------------------------------------------------
// The ground
// ---------------------------------------------------------------------
block3d(0, -10, 0, 6600, 20, 6600, "#3f6b3f")

// ---------------------------------------------------------------------
// Thornkeep Castle - north end of the realm
// ---------------------------------------------------------------------
let castleZ = 0 - 2250

// curtain walls (a gap in the south wall is the gate)
block3d(0, 180, castleZ - 600, 1320, 360, 40, "#6b6f78")        // north wall
block3d(0 - 460, 180, castleZ, 40, 360, 1200, "#6b6f78")        // west wall
block3d(460, 180, castleZ, 40, 360, 1200, "#6b6f78")            // east wall
block3d(0 - 290, 180, castleZ + 600, 360, 360, 40, "#6b6f78")   // south wall, west of gate
block3d(290, 180, castleZ + 600, 360, 360, 40, "#6b6f78")       // south wall, east of gate

// crenellations along the north wall
for i from 0 to 10 {
  crenel(0 - 600 + i * 120, 380, castleZ - 600, false)
}

// corner towers + gate towers
wallTower(0 - 660, castleZ - 600, 460)
wallTower(660, castleZ - 600, 460)
wallTower(0 - 660, castleZ + 600, 460)
wallTower(660, castleZ + 600, 460)
wallTower(0 - 110, castleZ + 600, 420)
wallTower(110, castleZ + 600, 420)

// the keep, in the middle of the yard
block3d(0, 450, castleZ - 150, 360, 900, 360, "#787c86")
block3d(0, 930, castleZ - 150, 400, 40, 400, "#5a5e68")
cyl3d(0 - 170, 500, castleZ - 320, 40, 1000, "#6b6f78")
cyl3d(170, 500, castleZ - 320, 40, 1000, "#6b6f78")
cyl3d(0 - 170, 500, castleZ + 20, 40, 1000, "#6b6f78")
cyl3d(170, 500, castleZ + 20, 40, 1000, "#6b6f78")

// torches at the gate
lamp3d(0 - 110, 260, castleZ + 580, "#ff9a3d", 55, 900)
lamp3d(110, 260, castleZ + 580, "#ff9a3d", 55, 900)

// ---------------------------------------------------------------------
// Road from the gate down to Millhaven's market square
// ---------------------------------------------------------------------
block3d(0, 2, castleZ + 1050, 140, 6, 1500, "#8a8578")

// ---------------------------------------------------------------------
// Millhaven Market, the village square
// ---------------------------------------------------------------------
let stallColors = ["#c0392b", "#2980b9", "#d4a017", "#27ae60", "#8e44ad"]
for i from 0 to 4 {
  let ang = i * 720
  let sx = sin3(ang) * 220 / 1000
  let sz = cos3(ang) * 220 / 1000
  stall(sx, sz, stallColors[i])
}

// ---------------------------------------------------------------------
// Millhaven village - cottages either side of the main road
// ---------------------------------------------------------------------
let roofColors = ["#8a3b2a", "#6b2f2a", "#7a4a2a", "#9c3f2a"]
let wallColors = ["#cfc3a8", "#b8ab8e", "#d8cdb2", "#c2b595"]

cottage(0 - 500, 300, wallColors[0], roofColors[0])
cottage(0 - 500, 560, wallColors[1], roofColors[1])
cottage(0 - 500, 820, wallColors[2], roofColors[2])
cottage(0 - 750, 440, wallColors[3], roofColors[3])
cottage(500, 300, wallColors[1], roofColors[2])
cottage(500, 560, wallColors[2], roofColors[3])
cottage(500, 820, wallColors[3], roofColors[0])
cottage(750, 440, wallColors[0], roofColors[1])

// a lamp lighting the square at dusk
lamp3d(0, 220, 0, "#ffcf8a", 35, 700)

// ---------------------------------------------------------------------
// Chapel of the Dawnlight, east of the square
// ---------------------------------------------------------------------
let chapelX = 1100
let chapelZ = 200
block3d(chapelX, 120, chapelZ, 220, 240, 320, "#b9b2a0")
cyl3d(chapelX, 300, chapelZ - 180, 50, 240, "#9a927c")
cyl3d(chapelX, 440, chapelZ - 180, 56, 40, "#5a3b2a")
block3d(chapelX, 480, chapelZ - 180, 10, 70, 60, "#d8cf3f")      // the cross, upright
block3d(chapelX, 505, chapelZ - 180, 10, 30, 160, "#d8cf3f")     // the cross, crossbar

// ---------------------------------------------------------------------
// Silverlake and its bridge, east of the village
// ---------------------------------------------------------------------
let lakeX = 1950
let lakeZ = 750
let lake = ball3d(lakeX, 0 - 480, lakeZ, 650, "#2a6f9e")
shine3d lake, 8, 0
block3d(lakeX, 22, lakeZ, 1300, 26, 170, "#8a6a3f")
cyl3d(lakeX - 420, 5, lakeZ - 90, 14, 40, "#6b4f2e")
cyl3d(lakeX - 420, 5, lakeZ + 90, 14, 40, "#6b4f2e")
cyl3d(lakeX + 420, 5, lakeZ - 90, 14, 40, "#6b4f2e")
cyl3d(lakeX + 420, 5, lakeZ + 90, 14, 40, "#6b4f2e")

// a diagonal path linking the square to the bridge's near end
let lakePath = block3d(730, 2, 400, 820, 6, 130, "#8a8578")
turn3d lakePath, 400

// ---------------------------------------------------------------------
// Farmland, southwest of the village
// ---------------------------------------------------------------------
block3d(0 - 1150, 1, 1150, 420, 4, 260, "#6b4f2e")
block3d(0 - 1150, 2, 1150, 420, 2, 40, "#5a7a3a")
block3d(0 - 1150, 2, 1230, 420, 2, 40, "#5a7a3a")
block3d(0 - 1150, 2, 1070, 420, 2, 40, "#5a7a3a")
for i from 0 to 8 {
  fencePost(0 - 1360 + i * 100, 1010)
  fencePost(0 - 1360 + i * 100, 1290)
}

// ---------------------------------------------------------------------
// Hollowpine Wood - forest south of the village, and a strip along
// the west edge of the realm
// ---------------------------------------------------------------------
for i from 0 to 22 {
  tree(0 - 900 + random(0, 1800), 1150 + random(0, 650))
}
for i from 0 to 14 {
  tree(0 - 1650 + random(0, 300), 0 - 1600 + random(0, 2400))
}

// ---------------------------------------------------------------------
// Greycairn Watch - a lone tower on the south road, keeping watch
// ---------------------------------------------------------------------
let towerX = 0
let towerZ = 2650
block3d(towerX, 30, towerZ, 260, 60, 260, "#55504a")
cyl3d(towerX, 320, towerZ, 65, 560, "#6b6f78")
cyl3d(towerX, 610, towerZ, 72, 36, "#5a3b2a")
lamp3d(towerX, 650, towerZ, "#ff9a3d", 45, 800)

block3d(0, 2, 1900, 140, 6, 700, "#8a8578")      // the south road, village to the watch

// ---------------------------------------------------------------------
// The landmarks the HUD will name as you walk near them
// ---------------------------------------------------------------------
let lmName = ["Thornkeep Castle", "Millhaven Market", "Chapel of the Dawnlight", "Silverlake", "Hollowpine Wood", "Greycairn Watch"]
let lmX = [0, 0, chapelX, lakeX, 0, towerX]
let lmZ = [castleZ, 0, chapelZ, lakeZ, 1500, towerZ]
let lmRadius = [520, 260, 220, 420, 480, 360]

// ---------------------------------------------------------------------
// Walking around - click to look, WASD to move
// ---------------------------------------------------------------------
let px = 0
let pz = 450
let yaw = 0
let pitch = 0

every frame {
  yaw += mousedx() * 3
  pitch -= mousedy() * 3
  pitch = constrain(pitch, 0 - 800, 800)
  if yaw >= 3600 {
    yaw -= 3600
  }
  if yaw < 0 {
    yaw += 3600
  }

  let fwd = 0
  let side = 0
  if held("w") or held("up") {
    fwd += 1
  }
  if held("s") or held("down") {
    fwd -= 1
  }
  if held("d") or held("right") {
    side += 1
  }
  if held("a") or held("left") {
    side -= 1
  }
  let spd = 420
  px += (sin3(yaw) * fwd + cos3(yaw) * side) * spd / 1000
  pz += (0 - cos3(yaw) * fwd + sin3(yaw) * side) * spd / 1000
  px = constrain(px, 0 - 3200, 3200)
  pz = constrain(pz, 0 - 3200, 3200)

  camera3d px, 165, pz, yaw, pitch
  render3d

  let near = ""
  for i from 0 to length(lmName) - 1 {
    if dist(px, pz, lmX[i], lmZ[i]) < lmRadius[i] {
      near = lmName[i]
    }
  }

  if locked3d() == 0 {
    write "Click to look around - WASD to walk" at 160, 90 centered shadow
  }
  write "X " + text(px / 100) + "  Z " + text(pz / 100) at 8, 8 shadow
  if near != "" {
    write near at 160, 166 centered shadow
  }
}
