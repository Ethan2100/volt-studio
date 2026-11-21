// =====================================================================
// Game kit - the first-person player that every Volt 3D game ends up
// writing by hand: mouse look, walking, running, crouching, jumping,
// gravity, head bob, and solid boxes that stop you (and that you can
// climb onto).
//
// World Studio writes this import for you. The short version is:
//
//   #html
//   canvas 320, 180
//   import "game.volt"
//
//   WALK_SPEED = 500            // settings go here, after the import
//
//   world3d "#05060a" fog 1600 ambient 8 shadows
//   let Floor = block3d(0, -5, 0, 1200, 10, 1200, "#6a6f78")
//   solid(0, 0, 600, 600, -10, 0)   // the floor you can stand on
//
//   playerStart(0, 400, 0)
//   every frame {
//     playerStep()
//     render3d
//   }
//
// Everything in SETTINGS below is a plain variable, so change it from
// your own file with a normal `=` line (no `let`), at the top or in
// the middle of the game:
//
//   WALK_SPEED = 900            // a fast game
//   CAN_JUMP = false            // no jumping in this one
//
// Units are Volt's own 3D units: 1 unit = 1 cm, y is up, and angles are
// tenths of a degree (900 = a quarter turn).
// =====================================================================

// ---------------------------------------------------------------------
//  SETTINGS - change any of these from your game file
// ---------------------------------------------------------------------
let WALK_SPEED = 400        // how fast you walk, in cm per second
let RUN_SPEED = 750         // ... while holding Shift
let CROUCH_SPEED = 180      // ... while holding Ctrl
let MOUSE_SPEED = 3         // how fast the mouse turns the camera
let INVERT_LOOK = false     // true = pushing the mouse up looks down
let LOOK_LIMIT = 850        // how far up and down you can look (850 = 85 degrees)
let EYE_HEIGHT = 165        // how tall the player is, in cm
let CROUCH_HEIGHT = 95      // ... while crouching
let JUMP_POWER = 430        // how hard you jump, in cm per second
let GRAVITY = 1500          // how hard you fall, in cm per second per second
let STEP_HEIGHT = 45        // anything this low is a step, not a wall
let PLAYER_WIDTH = 25       // how wide the player is, in cm (half of it)
let HEAD_BOB = 3            // how much the view bounces as you walk (0 = off)
let CAN_RUN = true
let CAN_JUMP = true
let CAN_CROUCH = true
let CAN_MOVE = true         // false freezes the player (cutscenes, menus)

// ---------------------------------------------------------------------
//  The player - read these from your own code whenever you need them
//  (PLAYER_Y is the height of the player's feet, not their eyes)
// ---------------------------------------------------------------------
let PLAYER_X = 0
let PLAYER_Y = 0
let PLAYER_Z = 0
let PLAYER_YAW = 0
let PLAYER_PITCH = 0
let PLAYER_FALL = 0         // how fast they are moving up (+) or down (-)
let PLAYER_GROUNDED = true  // true while they are standing on something
let PLAYER_CROUCHING = false
let PLAYER_RUNNING = false
let PLAYER_MOVING = false
let PLAYER_BOB = 0

// ---------------------------------------------------------------------
//  Solid boxes. Each one is a flat footprint plus the height of its top
//  face, so the same list both stops you walking through a wall and
//  lets you stand on a crate. World Studio fills these in for you.
// ---------------------------------------------------------------------
let SOLID_X = []
let SOLID_Z = []
let SOLID_HX = []           // half the width, in cm
let SOLID_HZ = []           // half the depth, in cm
let SOLID_BOT = []          // height of the bottom face, in cm
let SOLID_TOP = []          // height of the top face, in cm

// Adds one solid box: the middle of its footprint, half its width and
// depth, and how high its bottom and top faces are. Knowing both means
// a ceiling or a doorway lintel is something you walk under, not a wall,
// and a low beam is something you can crouch under.
fn solid(x, z, halfWidth, halfDepth, bottom, top) {
  add x to SOLID_X
  add z to SOLID_Z
  add halfWidth to SOLID_HX
  add halfDepth to SOLID_HZ
  add bottom to SOLID_BOT
  add top to SOLID_TOP
}

// Forgets every solid box - call it before building a new level.
fn clearSolids() {
  SOLID_X = []
  SOLID_Z = []
  SOLID_HX = []
  SOLID_HZ = []
  SOLID_BOT = []
  SOLID_TOP = []
}

// How much room the player needs above their feet right now - less
// while crouching, which is how you get under a low beam.
fn headRoom() {
  if PLAYER_CROUCHING {
    return CROUCH_HEIGHT
  }
  return EYE_HEIGHT
}

// True when a box there stops you: too tall to step onto, and low
// enough to be in your way (anything above your head is walked under).
fn blocked(x, z, feet) {
  let head = feet + headRoom()
  let i = 0
  while i < length(SOLID_X) {
    if abs(x - SOLID_X[i]) < SOLID_HX[i] + PLAYER_WIDTH and abs(z - SOLID_Z[i]) < SOLID_HZ[i] + PLAYER_WIDTH {
      if SOLID_TOP[i] > feet + STEP_HEIGHT and SOLID_BOT[i] < head {
        return true
      }
    }
    i += 1
  }
  return false
}

// How high the floor is at a point - the top of the highest box you
// could be standing on there, or 0 for the ground.
fn groundHeight(x, z, feet) {
  let best = 0
  let i = 0
  while i < length(SOLID_X) {
    if abs(x - SOLID_X[i]) < SOLID_HX[i] + PLAYER_WIDTH and abs(z - SOLID_Z[i]) < SOLID_HZ[i] + PLAYER_WIDTH {
      if SOLID_TOP[i] <= feet + STEP_HEIGHT and SOLID_TOP[i] > best {
        best = SOLID_TOP[i]
      }
    }
    i += 1
  }
  return best
}

// ---------------------------------------------------------------------
//  The player
// ---------------------------------------------------------------------

// Puts the player somewhere, facing a direction. Call it once before
// your `every frame` block (World Studio uses your Spawn point here).
fn playerStart(x, z, yaw) {
  PLAYER_X = x
  PLAYER_Z = z
  PLAYER_YAW = yaw
  PLAYER_Y = groundHeight(x, z, 10000)
  PLAYER_PITCH = 0
  PLAYER_FALL = 0
}

// Turns the camera with the mouse. (Clicking the page captures the
// mouse; Escape lets it go.)
fn playerLook() {
  PLAYER_YAW += mousedx() * MOUSE_SPEED
  if INVERT_LOOK {
    PLAYER_PITCH += mousedy() * MOUSE_SPEED
  } else {
    PLAYER_PITCH -= mousedy() * MOUSE_SPEED
  }
  PLAYER_PITCH = constrain(PLAYER_PITCH, 0 - LOOK_LIMIT, LOOK_LIMIT)
}

// Walks with W/A/S/D, slides along walls instead of sticking to them.
fn playerWalk() {
  PLAYER_MOVING = false
  PLAYER_RUNNING = false
  PLAYER_CROUCHING = false
  if not CAN_MOVE {
    return 0
  }
  let fx = sin3(PLAYER_YAW)
  let fz = 0 - cos3(PLAYER_YAW)
  let mx = 0
  let mz = 0
  if held("w") or held("up") {
    mx += fx
    mz += fz
  }
  if held("s") or held("down") {
    mx -= fx
    mz -= fz
  }
  if held("a") or held("left") {
    mx -= cos3(PLAYER_YAW)
    mz -= sin3(PLAYER_YAW)
  }
  if held("d") or held("right") {
    mx += cos3(PLAYER_YAW)
    mz += sin3(PLAYER_YAW)
  }
  if CAN_CROUCH and held("control") {
    PLAYER_CROUCHING = true
  }
  let speed = WALK_SPEED
  if CAN_RUN and held("shift") and not PLAYER_CROUCHING {
    speed = RUN_SPEED
    PLAYER_RUNNING = true
  }
  if PLAYER_CROUCHING {
    speed = CROUCH_SPEED
  }
  if mx == 0 and mz == 0 {
    return 0
  }
  PLAYER_MOVING = true
  // mx and mz are in thousandths (sin3/cos3), and speed is cm a second
  // at 60 frames a second - so the step is speed / 60 / 1000 of them.
  let stepX = mx * speed / 60000.0
  let stepZ = mz * speed / 60000.0
  let nx = PLAYER_X + stepX
  if not blocked(nx, PLAYER_Z, PLAYER_Y) {
    PLAYER_X = nx
  }
  let nz = PLAYER_Z + stepZ
  if not blocked(PLAYER_X, nz, PLAYER_Y) {
    PLAYER_Z = nz
  }
  return 1
}

// Jumping and falling. Standing on a crate works because a box's top
// face counts as the floor while you are over it.
fn playerFall() {
  if CAN_JUMP and CAN_MOVE and PLAYER_GROUNDED and held("space") {
    PLAYER_FALL = JUMP_POWER
    PLAYER_GROUNDED = false
  }
  PLAYER_FALL -= GRAVITY / 60.0
  PLAYER_Y += PLAYER_FALL / 60.0
  let floorY = groundHeight(PLAYER_X, PLAYER_Z, PLAYER_Y)
  if PLAYER_Y <= floorY {
    PLAYER_Y = floorY
    PLAYER_FALL = 0
    PLAYER_GROUNDED = true
  } else {
    PLAYER_GROUNDED = false
  }
}

// How high the camera sits above the player's feet right now, including
// the crouch and the walking bounce.
fn eyeLevel() {
  let eye = EYE_HEIGHT
  if PLAYER_CROUCHING {
    eye = CROUCH_HEIGHT
  }
  if HEAD_BOB > 0 and PLAYER_MOVING and PLAYER_GROUNDED {
    PLAYER_BOB += 90
    if PLAYER_RUNNING {
      PLAYER_BOB += 60
    }
    if PLAYER_BOB > 3600 {
      PLAYER_BOB -= 3600
    }
    eye += sin3(PLAYER_BOB) * HEAD_BOB / 1000.0
  }
  return eye
}

// One frame of being a person: look, walk, fall, and move the camera.
// Call it at the top of your `every frame` block, before `render3d`.
fn playerStep() {
  playerLook()
  playerWalk()
  playerFall()
  camera3d PLAYER_X, PLAYER_Y + eyeLevel(), PLAYER_Z, PLAYER_YAW, PLAYER_PITCH
}

// How far the player is from a point on the ground - handy for "am I
// close enough to open this door".
fn playerNear(x, z, howClose) {
  if dist(PLAYER_X, PLAYER_Z, x, z) < howClose {
    return true
  }
  return false
}

// True while the player is looking at a point, within `spread` tenths
// of a degree - the other half of an "press E to open" check.
fn playerFacing(x, z, spread) {
  let want = atan2(x - PLAYER_X, 0 - (z - PLAYER_Z))
  let gap = abs(want - PLAYER_YAW)
  if gap > 1800 {
    gap = 3600 - gap
  }
  if gap < spread {
    return true
  }
  return false
}


// ---------------------------------------------------------------------
//  DEFAULT PLAYER HOTBAR - ten quick slots, matching the familiar
//  1-9 / 0 keyboard layout. World Studio fills the item and stack arrays.
//  Call hotbarStep() once per frame and hotbarDraw() after render3d.
// ---------------------------------------------------------------------
let HOTBAR_ENABLED = true
let HOTBAR_SELECTED = 1
let HOTBAR_SLOT_COUNT = 10
let HOTBAR_ITEMS = ["", "", "", "", "", "", "", "", "", ""]
let HOTBAR_COUNTS = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
let HOTBAR_KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

fn hotbarStep() {
  if not HOTBAR_ENABLED { return 0 }
  if held("1") { HOTBAR_SELECTED = 1 }
  if held("2") { HOTBAR_SELECTED = 2 }
  if held("3") { HOTBAR_SELECTED = 3 }
  if held("4") { HOTBAR_SELECTED = 4 }
  if held("5") { HOTBAR_SELECTED = 5 }
  if held("6") { HOTBAR_SELECTED = 6 }
  if held("7") { HOTBAR_SELECTED = 7 }
  if held("8") { HOTBAR_SELECTED = 8 }
  if held("9") { HOTBAR_SELECTED = 9 }
  if held("0") { HOTBAR_SELECTED = 10 }
  return HOTBAR_SELECTED
}

// Draw after render3d so the bar stays in screen space above the 3D scene.
fn hotbarDraw() {
  if not HOTBAR_ENABLED { return 0 }
  let slotW = 24
  let slotH = 28
  let gap = 2
  let totalW = HOTBAR_SLOT_COUNT * slotW + (HOTBAR_SLOT_COUNT - 1) * gap
  let startX = (320 - totalW) / 2
  let startY = 148
  let i = 0
  while i < HOTBAR_SLOT_COUNT {
    let sx = startX + i * (slotW + gap)
    let edge = "#3b4658"
    let fill = "#101722e8"
    let labelColor = "#dce8f5"
    if i + 1 == HOTBAR_SELECTED {
      edge = "#55c7ff"
      fill = "#19344bf0"
    }
    if i < length(HOTBAR_COUNTS) and HOTBAR_COUNTS[i] <= 0 {
      labelColor = "#7f8999"
    }
    box sx, startY, slotW, slotH color edge
    box sx + 1, startY + 1, slotW - 2, slotH - 2 color fill
    write HOTBAR_KEYS[i] at sx + 3, startY + 2 color "#9fb1c6"
    if i < length(HOTBAR_ITEMS) and HOTBAR_ITEMS[i] != "" {
      write HOTBAR_ITEMS[i] at sx + 12, startY + 12 color labelColor centered
    } else {
      write "-" at sx + 12, startY + 12 color "#596579" centered
    }
    if i < length(HOTBAR_COUNTS) and HOTBAR_COUNTS[i] > 0 {
      write "" + HOTBAR_COUNTS[i] at sx + slotW - 3, startY + 21 color "#ffd36b"
    }
    i += 1
  }
  return 0
}
