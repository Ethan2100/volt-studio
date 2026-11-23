// =====================================================================
// Combat kit - health, damage, abilities, a backpack and the HUD that
// shows all three. The other half of the game kit: game.volt walks the
// player around, this one lets things hurt each other.
//
// World Studio writes the import and the setup for you. By hand it is:
//
//   #html
//   canvas 320, 180
//   import "game.volt"
//   import "combat.volt"
//
//   let Goblin = block3d(0, 60, -400, 60, 120, 60, "#5d8a4a")
//   let g = target("Goblin", 0, 60, -400, 40, 90)   // 40 health
//
//   every frame {
//     playerStep()
//     stepCombat()                  // cooldowns, hurt flash, damage numbers
//     when key "e" pressed {
//       magic3d PLAYER_X, PLAYER_Y + 5, PLAYER_Z, 300, "#9d6bff", 900
//       damageArea(PLAYER_X, PLAYER_Z, 250, 15)
//     }
//     render3d
//     drawCombat()                  // the HUD goes on top of the world
//   }
//
// Units match the rest of Volt: 1 = 1 cm, y is up.
// =====================================================================

// ---------------------------------------------------------------------
//  SETTINGS - change any of these from your game file
// ---------------------------------------------------------------------
let PLAYER_MAX_HP = 100
let PLAYER_HP = 100
let RESPAWN_MS = 2000       // how long you lie dead before coming back (0 = stay dead)
let HURT_FLASH_MS = 260     // how long the screen flashes red when you are hit
let TOUCH_DAMAGE = 10       // damage a touching enemy does, per second
let HUD_W = 320             // the size you gave `canvas` - the HUD is drawn in these
let HUD_H = 180
let HUD_COLOR = "#ffd23f"
let SHOW_HEALTH_BAR = true
let SHOW_HOTBAR = true

// ---------------------------------------------------------------------
//  How the hotbar looks. Change any of these from your game file.
// ---------------------------------------------------------------------
let HOTBAR_STYLE = "plain"   // plain, gold, round, hex, slim
let HOTBAR_SIZE = 22         // how big one slot is, in HUD pixels
let HOTBAR_GAP = 3           // the space left between slots
let HOTBAR_SLOTS = 0         // 0 means one slot per item you carry
let HOTBAR_ROWS = 1          // 2 or 3 stacks the slots up, like Divinity
let HOTBAR_NUMBERS = true    // the 1 2 3 keys in the corner of each slot
let HOTBAR_COUNTS = true     // how many of that thing you have
let HOTBAR_NAME = true       // the name of what you are holding, above the bar
let HOTBAR_WHERE = "bottom"  // bottom, top, left, right or middle
let HOTBAR_X = 0 - 1         // -1 means work it out from HOTBAR_WHERE
let HOTBAR_Y = 0 - 1
let HOTBAR_BACK = "#0b0f16cc"   // the colour inside an empty slot
let HOTBAR_RIM = "#2a3142"      // the line around a slot
let HOTBAR_PICKED = "#ffd23f"   // the line around the slot you are holding
let SHOW_DAMAGE_NUMBERS = true
let SHOW_ENEMY_BARS = true
let DEATH_SPARKS = true     // a burst of sparks where something dies

// ---------------------------------------------------------------------
//  The player's state - read these, and use hurtPlayer / healPlayer to
//  change them so the flash and the death both happen
// ---------------------------------------------------------------------
let PLAYER_DEAD = false
let PLAYER_HURT = 0         // counts down in ms while the screen is red
let DEAD_FOR = 0            // counts up in ms while dead

// ---------------------------------------------------------------------
//  Things that can be hurt. One entry per enemy, barrel or crate, kept
//  as parallel lists the same way game.volt keeps its solid boxes.
// ---------------------------------------------------------------------
let TARGET_NAME = []
let TARGET_X = []
let TARGET_Y = []           // the middle of it
let TARGET_Z = []
let TARGET_HP = []
let TARGET_MAX = []
let TARGET_REACH = []       // how close a hit has to land, in cm
let TARGET_TOP = []         // how high its head is - where the bar and numbers go

// Adds something that can be hurt, and gives back its number so you can
// talk about it later: `let goblin = target("Goblin", 0, 60, -400, 40, 90)`
fn target(name, x, y, z, hp, reach) {
  add name to TARGET_NAME
  add x to TARGET_X
  add y to TARGET_Y
  add z to TARGET_Z
  add hp to TARGET_HP
  add hp to TARGET_MAX
  add reach to TARGET_REACH
  add y + reach to TARGET_TOP
  return length(TARGET_NAME) - 1
}

fn alive(i) {
  if i < 0 or i >= length(TARGET_HP) {
    return false
  }
  return TARGET_HP[i] > 0
}

// Keep a target's spot in step with the block or model you are moving.
fn moveTarget(i, x, y, z) {
  if i < 0 or i >= length(TARGET_X) {
    return
  }
  TARGET_X[i] = x
  TARGET_Y[i] = y
  TARGET_Z[i] = z
  TARGET_TOP[i] = y + TARGET_REACH[i]
}

// ---------------------------------------------------------------------
//  Doing damage
// ---------------------------------------------------------------------

// Hurts one target by number. Gives back true if that killed it.
fn hurtTarget(i, amount) {
  if not alive(i) {
    return false
  }
  TARGET_HP[i] -= amount
  damageNumber(TARGET_X[i], TARGET_TOP[i], TARGET_Z[i], amount, "#ff6b6b")
  if TARGET_HP[i] <= 0 {
    TARGET_HP[i] = 0
    if DEATH_SPARKS {
      burst3d TARGET_X[i], TARGET_Y[i], TARGET_Z[i], "#ff9a66", 26, 260
    }
    return true
  }
  return false
}

// Hurts everything standing within `reach` cm of a spot. This is what an
// ability calls. Gives back how many it hit.
fn damageArea(x, z, reach, amount) {
  let hit = 0
  let i = 0
  while i < length(TARGET_HP) {
    if alive(i) {
      if dist(x, z, TARGET_X[i], TARGET_Z[i]) <= reach + TARGET_REACH[i] {
        hurtTarget(i, amount)
        hit += 1
      }
    }
    i += 1
  }
  return hit
}

// The closest living target within reach, or -1 if there is none.
fn nearestTarget(x, z, reach) {
  let best = -1
  let bestD = reach + 1
  let i = 0
  while i < length(TARGET_HP) {
    if alive(i) {
      let d = dist(x, z, TARGET_X[i], TARGET_Z[i])
      if d < bestD {
        bestD = d
        best = i
      }
    }
    i += 1
  }
  return best
}

// How many are still standing - useful for "you win".
fn aliveCount() {
  let n = 0
  let i = 0
  while i < length(TARGET_HP) {
    if TARGET_HP[i] > 0 {
      n += 1
    }
    i += 1
  }
  return n
}

// ---------------------------------------------------------------------
//  Hurting and healing the player
// ---------------------------------------------------------------------
fn hurtPlayer(amount) {
  if PLAYER_DEAD {
    return
  }
  PLAYER_HP -= amount
  PLAYER_HURT = HURT_FLASH_MS
  if PLAYER_HP <= 0 {
    PLAYER_HP = 0
    PLAYER_DEAD = true
    DEAD_FOR = 0
    CAN_MOVE = false
  }
}

fn healPlayer(amount) {
  if PLAYER_DEAD {
    return
  }
  PLAYER_HP = min(PLAYER_MAX_HP, PLAYER_HP + amount)
}

fn revivePlayer() {
  PLAYER_HP = PLAYER_MAX_HP
  PLAYER_DEAD = false
  PLAYER_HURT = 0
  DEAD_FOR = 0
  CAN_MOVE = true
}

// ---------------------------------------------------------------------
//  Cooldowns, so an ability cannot be spammed every frame
// ---------------------------------------------------------------------
let COOL_NAME = []
let COOL_LEFT = []

fn coolIndex(name) {
  let i = 0
  while i < length(COOL_NAME) {
    if COOL_NAME[i] == name {
      return i
    }
    i += 1
  }
  add name to COOL_NAME
  add 0 to COOL_LEFT
  return length(COOL_NAME) - 1
}

// true when the ability can be used again
fn ready(name) {
  return COOL_LEFT[coolIndex(name)] <= 0
}

// starts the wait - call it right after using the ability
fn startCooldown(name, ms) {
  COOL_LEFT[coolIndex(name)] = ms
}

// 0 to 100: how far through the wait it is, for drawing a dial
fn coolPercent(name, ms) {
  if ms <= 0 {
    return 100
  }
  let left = COOL_LEFT[coolIndex(name)]
  if left <= 0 {
    return 100
  }
  return 100 - (left * 100) / ms
}

// ---------------------------------------------------------------------
//  The backpack. Slots 1-9 along the bottom of the screen, the way a
//  Roblox backpack works: picking a slot holds that item, and using it
//  is up to your own code.
// ---------------------------------------------------------------------
let BAG_NAME = []
let BAG_COUNT = []
let BAG_COLOR = []
let BAG_SLOT = 0            // which slot is in your hand, counting from 0
let BAG_MAX = 9

fn bagIndex(name) {
  let i = 0
  while i < length(BAG_NAME) {
    if BAG_NAME[i] == name {
      return i
    }
    i += 1
  }
  return -1
}

// Puts something in the backpack. Same name stacks up.
fn give(name, count, color) {
  let at = bagIndex(name)
  if at >= 0 {
    BAG_COUNT[at] += count
    return true
  }
  if length(BAG_NAME) >= BAG_MAX {
    return false
  }
  add name to BAG_NAME
  add count to BAG_COUNT
  add color to BAG_COLOR
  return true
}

fn countOf(name) {
  let at = bagIndex(name)
  if at < 0 {
    return 0
  }
  return BAG_COUNT[at]
}

// Uses one up. true if there was one to use.
fn takeOne(name) {
  let at = bagIndex(name)
  if at < 0 {
    return false
  }
  if BAG_COUNT[at] <= 0 {
    return false
  }
  BAG_COUNT[at] -= 1
  if BAG_COUNT[at] <= 0 {
    remove BAG_NAME[at]
    remove BAG_COUNT[at]
    remove BAG_COLOR[at]
    if BAG_SLOT >= length(BAG_NAME) {
      BAG_SLOT = max(0, length(BAG_NAME) - 1)
    }
  }
  return true
}

// What is in your hand right now ("" when the backpack is empty).
fn holding() {
  if BAG_SLOT < 0 or BAG_SLOT >= length(BAG_NAME) {
    return ""
  }
  return BAG_NAME[BAG_SLOT]
}

fn pickSlot(n) {
  if n >= 0 and n < length(BAG_NAME) {
    BAG_SLOT = n
  }
}

// ---------------------------------------------------------------------
//  Damage numbers: the number that pops up where a hit landed and
//  floats away. They live in the 3D world but are drawn on the flat HUD,
//  which is what screenx3d / screeny3d are for.
// ---------------------------------------------------------------------
let DMG_X = []
let DMG_Y = []
let DMG_Z = []
let DMG_TEXT = []
let DMG_LIFE = []           // ms left
let DMG_COLOR = []

fn damageNumber(x, y, z, amount, color) {
  if not SHOW_DAMAGE_NUMBERS {
    return
  }
  add x to DMG_X
  add y to DMG_Y
  add z to DMG_Z
  add "" + amount to DMG_TEXT
  add 900 to DMG_LIFE
  add color to DMG_COLOR
}

// A word instead of a number: "Miss", "Blocked", "+20"
fn floatText(x, y, z, words, color) {
  add x to DMG_X
  add y to DMG_Y
  add z to DMG_Z
  add words to DMG_TEXT
  add 900 to DMG_LIFE
  add color to DMG_COLOR
}

// ---------------------------------------------------------------------
//  Call these two every frame: stepCombat() before render3d, and
//  drawCombat() after it, so the HUD sits on top of the world.
// ---------------------------------------------------------------------
fn stepCombat() {
  let tick = 16            // about one frame at 60 a second

  if PLAYER_HURT > 0 {
    PLAYER_HURT -= tick
  }

  let i = 0
  while i < length(COOL_LEFT) {
    if COOL_LEFT[i] > 0 {
      COOL_LEFT[i] -= tick
    }
    i += 1
  }

  i = 0
  while i < length(DMG_LIFE) {
    DMG_LIFE[i] -= tick
    DMG_Y[i] += 1           // drift upwards as it fades
    i += 1
  }
  while length(DMG_LIFE) > 0 and DMG_LIFE[0] <= 0 {
    remove DMG_X[0]
    remove DMG_Y[0]
    remove DMG_Z[0]
    remove DMG_TEXT[0]
    remove DMG_LIFE[0]
    remove DMG_COLOR[0]
  }

  if PLAYER_DEAD {
    DEAD_FOR += tick
    if RESPAWN_MS > 0 and DEAD_FOR >= RESPAWN_MS {
      revivePlayer()
    }
  }

  stepHotbarKeys()
}

// Number keys 1-9 pick a backpack slot.
fn stepHotbarKeys() {
  if held("1") { pickSlot(0) }
  if held("2") { pickSlot(1) }
  if held("3") { pickSlot(2) }
  if held("4") { pickSlot(3) }
  if held("5") { pickSlot(4) }
  if held("6") { pickSlot(5) }
  if held("7") { pickSlot(6) }
  if held("8") { pickSlot(7) }
  if held("9") { pickSlot(8) }
}

// ---------------------------------------------------------------------
//  The HUD
// ---------------------------------------------------------------------
fn drawCombat() {
  if PLAYER_HURT > 0 {
    box 0, 0, HUD_W, HUD_H color "#ff000033"
  }
  if SHOW_ENEMY_BARS {
    drawEnemyBars()
  }
  if SHOW_DAMAGE_NUMBERS {
    drawDamageNumbers()
  }
  if SHOW_HEALTH_BAR {
    drawHealthBar()
  }
  if SHOW_HOTBAR {
    drawHotbar()
  }
  if PLAYER_DEAD {
    box 0, 0, HUD_W, HUD_H color "#00000099"
    write "YOU DIED" at HUD_W / 2, HUD_H / 2 - 8 centered color "#ff6b6b" size 2
    if RESPAWN_MS > 0 {
      write "getting back up..." at HUD_W / 2, HUD_H / 2 + 10 centered color "#8c93a3"
    }
  }
}

fn drawHealthBar() {
  let w = 92
  let filled = (PLAYER_HP * w) / PLAYER_MAX_HP
  box 8, HUD_H - 16, w + 2, 8 color "#00000099"
  if filled > 0 {
    let c = "#4ade80"
    if PLAYER_HP * 100 / PLAYER_MAX_HP < 50 {
      c = "#ffd23f"
    }
    if PLAYER_HP * 100 / PLAYER_MAX_HP < 25 {
      c = "#ff6b6b"
    }
    box 9, HUD_H - 15, filled, 6 color c
  }
  write "" + PLAYER_HP at 9 + w + 6, HUD_H - 16 color "#cfe6ff"
}

// A small bar over the head of every living target you can see.
fn drawEnemyBars() {
  let i = 0
  while i < length(TARGET_HP) {
    if TARGET_HP[i] > 0 and TARGET_HP[i] < TARGET_MAX[i] {
      if onscreen3d(TARGET_X[i], TARGET_TOP[i], TARGET_Z[i]) {
        let sx = screenx3d(TARGET_X[i], TARGET_TOP[i], TARGET_Z[i])
        let sy = screeny3d(TARGET_X[i], TARGET_TOP[i], TARGET_Z[i])
        let filled = (TARGET_HP[i] * 28) / TARGET_MAX[i]
        box sx - 15, sy - 7, 30, 5 color "#00000099"
        if filled > 0 {
          box sx - 14, sy - 6, filled, 3 color "#ff6b6b"
        }
      }
    }
    i += 1
  }
}

fn drawDamageNumbers() {
  let i = 0
  while i < length(DMG_TEXT) {
    if onscreen3d(DMG_X[i], DMG_Y[i], DMG_Z[i]) {
      write DMG_TEXT[i] at screenx3d(DMG_X[i], DMG_Y[i], DMG_Z[i]), screeny3d(DMG_X[i], DMG_Y[i], DMG_Z[i]) centered color DMG_COLOR[i] shadow
    }
    i += 1
  }
}

fn drawHotbar() {
  let slots = hotbarSlots()
  if slots == 0 {
    return
  }
  let rows = max(1, HOTBAR_ROWS)
  let across = ceilDiv(slots, rows)
  let wide = HOTBAR_SIZE + HOTBAR_GAP
  let barW = across * wide - HOTBAR_GAP
  let barH = rows * wide - HOTBAR_GAP
  let left = hotbarLeft(barW)
  let top = hotbarTop(barH)
  let i = 0
  let r = 0
  let c = 0
  while i < slots {
    drawSlot(i, left + c * wide, top + r * wide)
    c += 1
    if c >= across {
      c = 0
      r += 1
    }
    i += 1
  }
  if HOTBAR_NAME and holding() != "" {
    write holding() at left + barW / 2, top - 10 centered color "#cfe6ff" shadow
  }
}

// How many slots to draw: what you are carrying, or the fixed number you set.
fn hotbarSlots() {
  if HOTBAR_SLOTS > 0 {
    return HOTBAR_SLOTS
  }
  return length(BAG_NAME)
}

// a divided by b, rounded up, in whole numbers
fn ceilDiv(a, b) {
  if b <= 1 {
    return a
  }
  let got = 0
  let n = 0
  while got < a {
    got += b
    n += 1
  }
  return n
}

fn hotbarLeft(barW) {
  if HOTBAR_X >= 0 {
    return HOTBAR_X
  }
  if HOTBAR_WHERE == "left" {
    return 8
  }
  if HOTBAR_WHERE == "right" {
    return HUD_W - barW - 8
  }
  return HUD_W / 2 - barW / 2
}

fn hotbarTop(barH) {
  if HOTBAR_Y >= 0 {
    return HOTBAR_Y
  }
  if HOTBAR_WHERE == "top" {
    return 8
  }
  if HOTBAR_WHERE == "middle" {
    return HUD_H / 2 - barH / 2
  }
  return HUD_H - barH - 8
}

// One slot: the frame in whichever style you picked, then what is in it.
fn drawSlot(i, x, y) {
  let size = HOTBAR_SIZE
  let pad = max(4, size / 4)      // how far the thing sits inside its slot
  let picked = i == BAG_SLOT
  let rim = HOTBAR_RIM
  if picked {
    rim = HOTBAR_PICKED
  }
  let has = i < length(BAG_NAME)

  if HOTBAR_STYLE == "round" {
    let mid = size / 2
    circle x + mid, y + mid, mid color HOTBAR_BACK edge 2 edgecolor rim
    if picked {
      circle x + mid, y + mid, mid + 2 edge 1 edgecolor HOTBAR_PICKED
    }
    if has {
      circle x + mid, y + mid, mid - pad color BAG_COLOR[i]
    }
  } else if HOTBAR_STYLE == "hex" {
    let mid = size / 2
    poly x + mid, y + mid, mid, 6 color HOTBAR_BACK angle 30 edge 2 edgecolor rim
    if picked {
      poly x + mid, y + mid, mid + 2, 6 angle 30 edge 1 edgecolor HOTBAR_PICKED
    }
    if has {
      poly x + mid, y + mid, mid - pad, 6 color BAG_COLOR[i] angle 30
    }
  } else if HOTBAR_STYLE == "gold" {
    // two frames, one inside the other, the way fantasy games do it
    box x, y, size, size color "#2a1d0e" round 3 edge 2 edgecolor "#c89b3c"
    box x + 2, y + 2, size - 4, size - 4 color HOTBAR_BACK round 2 edge 1 edgecolor "#6b4f1d"
    if picked {
      box x - 2, y - 2, size + 4, size + 4 round 4 edge 2 edgecolor HOTBAR_PICKED
    }
    if has {
      box x + pad, y + pad, size - pad * 2, size - pad * 2 color BAG_COLOR[i] round 2
    }
  } else if HOTBAR_STYLE == "slim" {
    // no box at all, just the thing and a line under the one you hold
    if has {
      box x + pad - 1, y + pad - 1, size - pad * 2 + 2, size - pad * 2 + 2 color BAG_COLOR[i] round 2
    }
    if picked {
      box x, y + size - 2, size, 2 color HOTBAR_PICKED
    }
  } else {
    box x, y, size, size color HOTBAR_BACK round 4 edge 1 edgecolor rim
    if picked {
      box x, y, size, 2 color HOTBAR_PICKED round 1
    }
    if has {
      box x + pad, y + pad, size - pad * 2, size - pad * 2 color BAG_COLOR[i] round 2
    }
  }

  if HOTBAR_NUMBERS and slotKey(i) != "" {
    write slotKey(i) at x + 2, y + 2 color "#b9c2d0" shadow
  }
  if HOTBAR_COUNTS and has and BAG_COUNT[i] > 1 {
    write "" + BAG_COUNT[i] at x + size - 3, y + size - 13 right color "#ffffff" shadow
  }
}

// The key you press for a slot: 1 to 9, then 0, then nothing.
fn slotKey(i) {
  if i < 9 {
    return "" + (i + 1)
  }
  if i == 9 {
    return "0"
  }
  return ""
}
