// =====================================================================
// Wyrmwood Reach - an open-world magic-swords-fantasy mini adventure.
//
// You wake up in Last Ember, a cozy little village you don't remember -
// the classic "pulled into another world" beginning. An elder, a ranger
// and a villager will tell you what little they know, pick a calling
// (Warrior, Mage or Tank), and set out to clear the wyrm-touched
// creatures from the wilds around the lake.
//
// One big continuous overworld (not floor-by-floor like Moonwell) - free
// roam, a village with a lore-filled lake, a bridge, scattered forest,
// goblins/skeletons/slimes to fight, coins and potions to find, and one
// weapon upgrade hidden out there somewhere.
//
// Art: the ground tiles (grass/path/water/trees/town buildings/...) are
// a small original tileset at terrain.png, right next to this file,
// built with hand-shaded blotchy texture and jagged organic shorelines
// instead of flat noise. Everything else - the knight, the weapons, the
// monsters, the villagers, the potions, the touch controls - reuses
// examples/dungeon/dungeon.png and examples/dungeon/controls/*.png (the
// same CC0 tileset Moonwell is built from), so this plays well on a
// phone too.
//
// Controls: 1/2/3 to pick your calling at the start. WASD/arrows to
// move, Space to attack, F to cast a magic bolt (costs mana, which
// slowly regenerates), E near a villager or sign to read.
// =====================================================================
#html

canvas 320, 180
touchpad "space", "f" stick "../dungeon/controls/stick.png", "../dungeon/controls/nub.png" button "../dungeon/controls/button.png" icons "../dungeon/controls/sword.png", "../dungeon/controls/summon.png"

image terrain = "terrain.png"
image tiles = "../dungeon/dungeon.png"

// ----------------------------- ground tiles -----------------------------
sprite grass = terrain at 0, 0 size 16, 16
sprite grassFlowers = terrain at 16, 0 size 16, 16
sprite path = terrain at 32, 0 size 16, 16
sprite sand = terrain at 48, 0 size 16, 16
sprite treeTile = terrain at 64, 0 size 16, 16

sprite rockTile = terrain at 0, 16 size 16, 16
sprite water = terrain at 16, 16 size 16, 16
sprite bridge = terrain at 32, 16 size 16, 16
sprite flowerPatch = terrain at 48, 16 size 16, 16
sprite signpost = terrain at 64, 16 size 16, 16

sprite waterEdgeTop = terrain at 0, 32 size 16, 16
sprite waterEdgeBottom = terrain at 16, 32 size 16, 16
sprite waterEdgeLeft = terrain at 32, 32 size 16, 16
sprite waterEdgeRight = terrain at 48, 32 size 16, 16
sprite woodFloor = terrain at 64, 32 size 16, 16

sprite stoneWall = terrain at 0, 48 size 16, 16
sprite roofTile = terrain at 16, 48 size 16, 16
sprite doorTile = terrain at 32, 48 size 16, 16
sprite cobblestone = terrain at 48, 48 size 16, 16
sprite fenceTile = terrain at 64, 48 size 16, 16

// ------------------------- characters & monsters -------------------------
sprite knightIdle = tiles at 128, 106 size 16, 22 frames 4
sprite knightRun = tiles at 192, 106 size 16, 22 frames 4
sprite rustySword = tiles at 307, 26 size 10, 21
sprite goldSword = tiles at 291, 153 size 10, 22
sprite hammer = tiles at 291, 42 size 10, 37
sprite staff = tiles at 324, 145 size 8, 30
sprite starStaff = tiles at 340, 145 size 8, 30

sprite ladyIdle = tiles at 128, 74 size 16, 22 frames 4
sprite elfIdle = tiles at 128, 42 size 16, 22 frames 4
sprite sorcIdle = tiles at 128, 132 size 16, 28 frames 4

sprite goblinIdle = tiles at 368, 37 size 16, 11 frames 4
sprite goblinRun = tiles at 432, 37 size 16, 11 frames 4
sprite skelIdle = tiles at 368, 80 size 16, 16 frames 4
sprite skelRun = tiles at 432, 80 size 16, 16 frames 4
sprite slime = tiles at 432, 112 size 16, 16 frames 4

// -------------------------------- pickups --------------------------------
sprite coin = tiles at 288, 272 size 8, 8 frames 4
sprite flask = tiles at 288, 240 size 16, 16
sprite flaskG = tiles at 320, 240 size 16, 16

// ================================ lore ===================================
let introLines = [
  "You don't remember falling asleep.",
  "You remember falling - through stars,",
  "through someone else's dying wish - and",
  "then grass, and the smell of woodsmoke.",
  "",
  "They call this place Wyrmwood Reach.",
  "They call the village Last Ember.",
  "They say you were sent for a reason.",
  "",
  "Choose how you'll carry that reason."
]

let signText1 = "LAST EMBER\nPopulation: fewer every year.\nThe wyrm's old magic still seeps\nfrom the lake. Mind the water."
let signText2 = "OLD WATCH POST\nWyrm-touched creatures gather\nwhere the light gets thin.\nA blade helps. So does luck."
let signText3 = "BY THE SHORE\n'The lake was a mirror once,'\nthe elder says. 'Now it only\nshows you what it's hungry for.'"

let npcElderText = "ELDER ORIN:\nAnother one, pulled through same\nas the last. The Reach does that\nwhen it's desperate. Go gently -\nand come back in one piece."
let npcVillagerText = "VILLAGER MEI:\nFolk from your world always look\nso surprised by the trees. Here,\ntake a potion. You'll want it."
let npcRangerText = "RANGER SYLAS:\nWyrm-touched goblins and skeletons\nhaunt the woods past the bridge.\nStay sharp, traveler-from-nowhere."

// ================================ world ===================================
// Legend - walkable: . grass  , grass+flowers  : path  ^ flower patch
//   = bridge  S sand  T cobblestone (town square)  U wood floor (indoors)
//   F door  t/b/l/r water-shore edges (grass/water blend, all walkable)
// solid: # tree  o rock  ~ water  B town wall  Y roof  Z fence
//   P/Q/R signposts (read with E when close)
// spawn codes (parsed out at build time, cleared under the hero's feet):
//   g goblin  k skeleton  m slime
//   N elder NPC  V villager NPC  E ranger NPC (all read with E when close)
// pickups: c coin  h potion  $ mana crystal  W weapon upgrade
let mapRows = [
  "############################################",
  "############################################",
  "##.,.......,..,....#.,...............#....##",
  "##.o.........................,............##",
  "##.YYYYYTYYYYY..^.....,.......o$#.........##",
  "##.BBBBBTBBBBB....^...#...kk.o....#....#..##",
  "##.BUUUBTBUUUB.........h...............,..##",
  "##.BBFBBTBBFBB............,..#............##",
  "##.TTTTTVTTTTT.....c...........,..##......##",
  "##.TTNTTTTTETT.....,....c.......o.........##",
  "##.ZZZZZ:ZZZZZ..........,...#.............##",
  "##.....P:.,....o.^..........ttttttt#,.....##",
  "##...............,...#....tt~~~~~~~...Q...##",
  "##................o......l~~~~~~~~~.......##",
  "##.,...........,o.....o,Rl~~~~~~~~~.......##",
  "##..........::::::::::::::=========:::....##",
  "##.....................#.l~~~~~~~~~.....c.##",
  "##.......................l~~~~~~~~~.......##",
  "##........c..,......,.....bb~~~~~~~.......##",
  "##....,...........g.....#...bbbbbbb...,...##",
  "##...o....,........#......................##",
  "##............c.#...#.#........g......#..###",
  "##............m....,...h....,......c...h.###",
  "##...........,^.........o.,...#....#..#...##",
  "##..,.........................,........g..##",
  "##.......#.#.........#.......#...g...om...##",
  "##......,.#.#^..........c....k#......,.c..##",
  "##......o......,....^.W..#..,......,,....,##",
  "############################################",
  "############################################",
]
let MW = length(mapRows[0])
let MH = length(mapRows)
let cells = []            // flat MW*MH grid, built from mapRows at start

let startHx = 8 * 16 + 3
let startHy = 11 * 16 + 4

// ------------------------------- game state -------------------------------
let gameState = "menu"   // "menu" then "play"
let heroClass = "warrior"

// ------------------------------- player state -----------------------------
let hx = startHx
let hy = startHy
let faceX = 0
let faceY = 1
let lookLeft = false
let moving = false
let tick = 0

let maxHp = 10
let hp = maxHp
let maxMana = 100
let mana = maxMana
let coins = 0
let defeated = 0
let swordLevel = 1          // 1 = starting weapon, 2 = after finding the upgrade
let swordDmg = 2
let moveSpeedBonus = 0      // tank is a touch slower, warrior/mage are not
let boltCost = 25
let boltDmg = 3

let swing = 0                // swing animation timer (counts down to 0)
let swingHit = false
let swingLen = 14
let castT = 0                 // magic cooldown timer
let hitCooldown = 0           // brief invulnerability after taking damage

let camX = 0
let camY = 0

let talkText = ""             // non-empty while a dialogue box is showing
let talkTimer = 0

// ------------------------------- enemy lists ------------------------------
let ex = []
let ey = []
let ekind = []
let ehp = []
let emaxhp = []
let edx = []
let edy = []
let ewander = []
let ehurt = []

// -------------------------------- npc lists --------------------------------
let nx = []
let ny = []
let nkind = []    // "elder" "villager" "ranger"

// ----------------------------- magic bolt lists ---------------------------
let mx = []
let my = []
let mvx = []
let mvy = []
let mlife = []

// -------------------------------- particles --------------------------------
let qx = []
let qy = []
let qvx = []
let qvy = []
let qlife = []
let qcol = []

// =============================== helpers ===================================
fn cellCh(tx, ty) {
  if tx < 0 or ty < 0 or tx >= MW or ty >= MH {
    return "#"
  }
  return cells[ty * MW + tx]
}

fn cellSet(tx, ty, ch) {
  if tx >= 0 and ty >= 0 and tx < MW and ty < MH {
    cells[ty * MW + tx] = ch
  }
}

fn solidCell(tx, ty) {
  return contains("#~oPQRBYZ", cellCh(tx, ty))
}

// is a box (in pixels) touching anything solid?
fn blocked(px, py, w, h) {
  if px < 0 or py < 0 {
    return true
  }
  let x1 = px / 16
  let y1 = py / 16
  let x2 = (px + w - 1) / 16
  let y2 = (py + h - 1) / 16
  return solidCell(x1, y1) or solidCell(x2, y1) or solidCell(x1, y2) or solidCell(x2, y2)
}

fn groundSprite(ch) {
  if ch == "." { return "grass" }
  if ch == "," { return "grassFlowers" }
  if ch == ":" { return "path" }
  if ch == "S" { return "sand" }
  if ch == "~" { return "water" }
  if ch == "#" { return "treeTile" }
  if ch == "o" { return "rockTile" }
  if ch == "=" { return "bridge" }
  if ch == "^" { return "flowerPatch" }
  if ch == "P" or ch == "Q" or ch == "R" { return "signpost" }
  if ch == "t" { return "waterEdgeTop" }
  if ch == "b" { return "waterEdgeBottom" }
  if ch == "l" { return "waterEdgeLeft" }
  if ch == "r" { return "waterEdgeRight" }
  if ch == "T" { return "cobblestone" }
  if ch == "U" { return "woodFloor" }
  if ch == "B" { return "stoneWall" }
  if ch == "Y" { return "roofTile" }
  if ch == "F" { return "doorTile" }
  if ch == "Z" { return "fenceTile" }
  return "grass"
}

fn drawGround(ch, px, py) {
  let s = groundSprite(ch)
  if s == "grass" { draw grass at px, py }
  if s == "grassFlowers" { draw grassFlowers at px, py }
  if s == "path" { draw path at px, py }
  if s == "sand" { draw sand at px, py }
  if s == "water" { draw water at px, py }
  if s == "treeTile" { draw treeTile at px, py }
  if s == "rockTile" { draw rockTile at px, py }
  if s == "bridge" { draw bridge at px, py }
  if s == "flowerPatch" { draw flowerPatch at px, py }
  if s == "signpost" { draw signpost at px, py }
  if s == "waterEdgeTop" { draw waterEdgeTop at px, py }
  if s == "waterEdgeBottom" { draw waterEdgeBottom at px, py }
  if s == "waterEdgeLeft" { draw waterEdgeLeft at px, py }
  if s == "waterEdgeRight" { draw waterEdgeRight at px, py }
  if s == "cobblestone" { draw cobblestone at px, py }
  if s == "woodFloor" { draw woodFloor at px, py }
  if s == "stoneWall" { draw stoneWall at px, py }
  if s == "roofTile" { draw roofTile at px, py }
  if s == "doorTile" { draw doorTile at px, py }
  if s == "fenceTile" { draw fenceTile at px, py }
}

fn burst(px, py, count, color, speed) {
  repeat count {
    add px * 10 to qx
    add py * 10 to qy
    add random(-speed, speed) to qvx
    add random(-speed, speed) to qvy
    add random(10, 24) to qlife
    add color to qcol
  }
}

fn enemyMaxHp(k) {
  if k == "g" { return 6 }
  if k == "k" { return 10 }
  return 8
}

fn enemyDmg(k) {
  if k == "k" { return 2 }
  return 1
}

fn enemySpriteH(k) {
  if k == "g" { return 11 }
  return 16
}

// ================================ world build ===============================
fn buildWorld() {
  cells = []
  let ty = 0
  while ty < MH {
    let row = mapRows[ty]
    let tx = 0
    while tx < MW {
      add part(row, tx, 1) to cells
      tx += 1
    }
    ty += 1
  }
  // pull enemy spawn codes out of the grid, cleared to grass
  ty = 0
  while ty < MH {
    let tx = 0
    while tx < MW {
      let ch = cellCh(tx, ty)
      if ch == "g" or ch == "k" or ch == "m" {
        add tx * 16 + 3 to ex
        add ty * 16 + 4 to ey
        add ch to ekind
        add enemyMaxHp(ch) to ehp
        add enemyMaxHp(ch) to emaxhp
        add 0 to edx
        add 0 to edy
        add 0 to ewander
        add 0 to ehurt
        cellSet(tx, ty, ".")
      } else if ch == "N" or ch == "V" or ch == "E" {
        add tx * 16 to nx
        add ty * 16 - 6 to ny
        if ch == "N" {
          add "elder" to nkind
        } else if ch == "V" {
          add "villager" to nkind
        } else {
          add "ranger" to nkind
        }
        cellSet(tx, ty, "T")
      }
      tx += 1
    }
    ty += 1
  }
}

// ================================ player ====================================
fn moveHero(dx, dy) {
  if dx != 0 and not blocked(hx + dx, hy, 10, 8) {
    hx += dx
  }
  if dy != 0 and not blocked(hx, hy + dy, 10, 8) {
    hy += dy
  }
}

fn checkPickup() {
  let tx = (hx + 5) / 16
  let ty = (hy + 4) / 16
  let ch = cellCh(tx, ty)
  if ch == "c" {
    coins += 1
    burst(hx + 5, hy, 6, "#ffe66d", 8)
    cellSet(tx, ty, ".")
  } else if ch == "h" {
    hp = min(hp + 4, maxHp)
    burst(hx + 5, hy, 8, "#ff6a9c", 8)
    cellSet(tx, ty, ".")
  } else if ch == "$" {
    mana = min(mana + 40, maxMana)
    burst(hx + 5, hy, 8, "#7be0ff", 8)
    cellSet(tx, ty, ".")
  } else if ch == "W" {
    swordLevel = 2
    swordDmg += 2
    burst(hx + 5, hy, 14, "#ffd23f", 12)
    cellSet(tx, ty, ".")
  }
}

fn nearestSignOrNpc() {
  // returns the lore/dialogue text for whatever's right in front of the hero,
  // or "" if nothing's close enough to read/talk to
  let tx = (hx + 5 + faceX * 9) / 16
  let ty = (hy + 4 + faceY * 9) / 16
  let ch = cellCh(tx, ty)
  if ch == "P" { return signText1 }
  if ch == "Q" { return signText2 }
  if ch == "R" { return signText3 }
  let i = 0
  while i < length(nx) {
    if abs(nx[i] + 8 - (hx + 5)) < 16 and abs(ny[i] + 11 - (hy + 4)) < 16 {
      if nkind[i] == "elder" { return npcElderText }
      if nkind[i] == "villager" { return npcVillagerText }
      return npcRangerText
    }
    i += 1
  }
  return ""
}

fn swordHits() {
  let ax = hx + 5 + faceX * 10
  let ay = hy + 4 + faceY * 10
  let i = length(ex) - 1
  while i >= 0 {
    let cx = ex[i] + 5
    let cy = ey[i] + 4
    if abs(cx - ax) < 11 and abs(cy - ay) < 11 {
      ehp[i] -= swordDmg
      ehurt[i] = 8
      burst(cx, cy, 6, "#ffffff", 8)
      if ehp[i] <= 0 {
        killEnemy(i)
      }
    }
    i -= 1
  }
}

fn killEnemy(i) {
  burst(ex[i] + 5, ey[i] + 4, 12, "#ffb34a", 10)
  coins += random(1, 3)
  defeated += 1
  remove ex[i]
  remove ey[i]
  remove ekind[i]
  remove ehp[i]
  remove emaxhp[i]
  remove edx[i]
  remove edy[i]
  remove ewander[i]
  remove ehurt[i]
}

fn castBolt() {
  add hx + 5 + faceX * 8 to mx
  add hy + 4 + faceY * 8 to my
  add faceX * 3 to mvx
  add faceY * 3 to mvy
  add 55 to mlife
}

fn updateHero() {
  if talkTimer > 0 {
    talkTimer -= 1
    if talkTimer == 0 {
      talkText = ""
    }
  }
  if hitCooldown > 0 {
    hitCooldown -= 1
  }
  let mxMove = 0
  let myMove = 0
  if held("left") or held("a") {
    mxMove = -1
  }
  if held("right") or held("d") {
    mxMove = 1
  }
  if held("up") or held("w") {
    myMove = -1
  }
  if held("down") or held("s") {
    myMove = 1
  }
  moving = mxMove != 0 or myMove != 0
  if moving and swing == 0 {
    faceX = mxMove
    faceY = myMove
    if mxMove != 0 and myMove != 0 {
      faceY = 0
    }
  }
  if mxMove < 0 {
    lookLeft = true
  }
  if mxMove > 0 {
    lookLeft = false
  }
  let speed = 1 + tick % 2
  if moveSpeedBonus > 0 and tick % 4 == 0 {
    speed -= 1
  }
  if swing > 0 {
    speed = tick % 2
  }
  moveHero(mxMove * speed, myMove * speed)
  checkPickup()

  if held("e") and talkTimer == 0 {
    let t = nearestSignOrNpc()
    if t != "" {
      talkText = t
      talkTimer = 140
    }
  }

  if held("space") and swing == 0 and castT == 0 {
    swing = swingLen
    swingHit = false
  }
  if swing > 0 {
    swing -= 1
    if swing == swingLen - 5 and not swingHit {
      swingHit = true
      swordHits()
    }
  }

  if held("f") and castT == 0 and swing == 0 and mana >= boltCost {
    castT = 30
    mana -= boltCost
    castBolt()
  }
  if castT > 0 {
    castT -= 1
  }
  if mana < maxMana and tick % 6 == 0 {
    mana += 1
  }

  // contact damage from touching enemies
  if hitCooldown == 0 {
    let i = 0
    while i < length(ex) {
      let cx = ex[i] + 5
      let cy = ey[i] + 4
      if abs(cx - (hx + 5)) < 9 and abs(cy - (hy + 4)) < 8 {
        hp -= enemyDmg(ekind[i])
        hitCooldown = 40
        burst(hx + 5, hy + 4, 6, "#ff4d6d", 7)
        break
      }
      i += 1
    }
  }

  if hp <= 0 {
    hp = maxHp
    hx = startHx
    hy = startHy
    hitCooldown = 60
    burst(hx + 5, hy + 4, 16, "#9bd3ff", 10)
  }
}

// ================================ enemies ===================================
fn updateEnemies() {
  let i = 0
  while i < length(ex) {
    if ehurt[i] > 0 {
      ehurt[i] -= 1
    }
    let k = ekind[i]
    let cx = ex[i] + 5
    let cy = ey[i] + 4
    let far = abs(cx - (hx + 5)) + abs(cy - (hy + 4))
    if far < 56 {
      edx[i] = sign(hx - ex[i])
      edy[i] = sign(hy - ey[i])
      ewander[i] = 0
    } else {
      if ewander[i] <= 0 {
        edx[i] = random(-1, 1)
        edy[i] = random(-1, 1)
        ewander[i] = random(30, 90)
      } else {
        ewander[i] -= 1
      }
    }
    let slow = k == "m" and tick % 2 == 0
    if not slow {
      if edx[i] != 0 and not blocked(ex[i] + edx[i], ey[i], 10, 8) {
        ex[i] += edx[i]
      }
      if edy[i] != 0 and not blocked(ex[i], ey[i] + edy[i], 10, 8) {
        ey[i] += edy[i]
      }
    }
    i += 1
  }
}

fn updateBolts() {
  let i = length(mx) - 1
  while i >= 0 {
    mx[i] += mvx[i]
    my[i] += mvy[i]
    mlife[i] -= 1
    let hitWall = blocked(mx[i] - 2, my[i] - 2, 4, 4)
    let hitEnemy = -1
    let j = 0
    while j < length(ex) {
      if abs(ex[j] + 5 - mx[i]) < 9 and abs(ey[j] + 4 - my[i]) < 9 {
        hitEnemy = j
        break
      }
      j += 1
    }
    if hitEnemy >= 0 {
      ehp[hitEnemy] -= boltDmg
      ehurt[hitEnemy] = 8
      burst(mx[i], my[i], 8, "#7be0ff", 8)
      if ehp[hitEnemy] <= 0 {
        killEnemy(hitEnemy)
      }
      mlife[i] = 0
    }
    if hitWall {
      burst(mx[i], my[i], 5, "#7be0ff", 5)
      mlife[i] = 0
    }
    if mlife[i] <= 0 {
      remove mx[i]
      remove my[i]
      remove mvx[i]
      remove mvy[i]
      remove mlife[i]
    }
    i -= 1
  }
}

fn updateParticles() {
  let i = length(qx) - 1
  while i >= 0 {
    qx[i] += qvx[i]
    qy[i] += qvy[i]
    qlife[i] -= 1
    if qlife[i] <= 0 {
      remove qx[i]
      remove qy[i]
      remove qvx[i]
      remove qvy[i]
      remove qlife[i]
      remove qcol[i]
    }
    i -= 1
  }
}

// ================================= drawing ===================================
fn drawWorld() {
  let t0x = camX / 16 - 1
  let t0y = camY / 16 - 1
  let t1x = (camX + 320) / 16 + 1
  let t1y = (camY + 180) / 16 + 1
  let ty = t0y
  while ty <= t1y {
    let tx = t0x
    while tx <= t1x {
      if tx >= 0 and ty >= 0 and tx < MW and ty < MH {
        let ch = cellCh(tx, ty)
        drawGround(ch, tx * 16, ty * 16)
        if ch == "c" {
          draw coin at tx * 16 + 4, ty * 16 + 4 frame tick / 8 % 4
        } else if ch == "h" {
          draw flask at tx * 16, ty * 16
        } else if ch == "$" {
          draw flaskG at tx * 16, ty * 16
        } else if ch == "W" {
          draw goldSword at tx * 16 + 3, ty * 16 - 4
        }
      }
      tx += 1
    }
    ty += 1
  }
}

fn drawNpcs() {
  let i = 0
  while i < length(nx) {
    let f = tick / 10 % 4
    if nkind[i] == "elder" {
      draw sorcIdle at nx[i] - 3, ny[i] - 6 frame f
    } else if nkind[i] == "villager" {
      draw ladyIdle at nx[i] - 3, ny[i] frame f
    } else {
      draw elfIdle at nx[i] - 3, ny[i] frame f
    }
    i += 1
  }
}

fn drawEnemies() {
  let i = 0
  while i < length(ex) {
    let k = ekind[i]
    let left = edx[i] < 0
    let f = tick / 6 % 4
    let y = ey[i] + 8 - enemySpriteH(k)
    let isHurt = ehurt[i] > 0
    if k == "g" {
      if edx[i] != 0 or edy[i] != 0 {
        draw goblinRun at ex[i] - 3, y frame f flip left flash isHurt
      } else {
        draw goblinIdle at ex[i] - 3, y frame f flip left flash isHurt
      }
    } else if k == "k" {
      if edx[i] != 0 or edy[i] != 0 {
        draw skelRun at ex[i] - 3, y frame f flip left flash isHurt
      } else {
        draw skelIdle at ex[i] - 3, y frame f flip left flash isHurt
      }
    } else {
      draw slime at ex[i] - 3, y frame f flip left flash isHurt
    }
    i += 1
  }
}

fn drawPlayer() {
  let y = hy + 8 - 22
  let f = tick / 6 % 4
  if moving and swing == 0 {
    draw knightRun at hx - 3, y frame f flip lookLeft
  } else {
    draw knightIdle at hx - 3, y frame f flip lookLeft
  }
  if swing > 0 {
    let reach = 10 - abs(swing - swingLen / 2)
    let wx = hx + 3 + faceX * reach
    let wy = hy + 2 + faceY * reach
    if heroClass == "mage" {
      if swordLevel == 2 {
        draw starStaff at wx, wy - 14 flip lookLeft angle faceX * 40
      } else {
        draw staff at wx, wy - 13 flip lookLeft angle faceX * 40
      }
    } else if heroClass == "tank" {
      draw hammer at wx, wy - 16 flip lookLeft angle faceX * 40
    } else {
      if swordLevel == 2 {
        draw goldSword at wx, wy - 10 flip lookLeft angle faceX * 40
      } else {
        draw rustySword at wx, wy - 9 flip lookLeft angle faceX * 40
      }
    }
  }
}

fn drawBolts() {
  let i = 0
  while i < length(mx) {
    box mx[i] - 2, my[i] - 2, 4, 4 color "#7be0ff"
    box mx[i] - 1, my[i] - 1, 2, 2 color "#ffffff"
    i += 1
  }
}

fn drawParticles() {
  let i = 0
  while i < length(qx) {
    box qx[i] / 10, qy[i] / 10, 2, 2 color qcol[i]
    i += 1
  }
}

fn drawUI() {
  box 7, 7, 62, 9 color "#241320"
  box 8, 8, 60 * hp / maxHp, 7 color "#ff4d6d"
  box 7, 18, 62, 9 color "#121a30"
  box 8, 19, 60 * mana / maxMana, 7 color "#4db8ff"
  write "Coins " + text(coins) at 8, 30 color "#ffe66d" size 1 shadow
  write "Defeated " + text(defeated) at 8, 40 color "#f2f3fa" size 1 shadow
  if swordLevel == 2 {
    write "Weapon upgraded" at 8, 50 color "#ffd23f" size 1 shadow
  }
  if talkText != "" {
    box 10, 120, 300, 54 color "#1a0f1f"
    box 12, 122, 296, 50 color "#2c1b33"
    write talkText at 18, 128 color "#f2f3fa" size 1
  }
}

fn drawMenu() {
  paint "#1a0f1f"
  write "WYRMWOOD REACH" at 160, 18 color "#ffd23f" size 1 shadow centered
  let i = 0
  while i < length(introLines) {
    write introLines[i] at 160, 44 + i * 9 color "#f2f3fa" size 1 centered
    i += 1
  }
  box 20, 142, 90, 30 color "#2c1b33"
  write "1 WARRIOR" at 65, 150 color "#ffb34a" size 1 centered
  write "sturdy sword & shield" at 65, 160 color "#cfc9d6" size 1 centered
  box 115, 142, 90, 30 color "#2c1b33"
  write "2 MAGE" at 160, 150 color "#7be0ff" size 1 centered
  write "cheap, strong bolts" at 160, 160 color "#cfc9d6" size 1 centered
  box 210, 142, 90, 30 color "#2c1b33"
  write "3 TANK" at 255, 150 color "#ff6a9c" size 1 centered
  write "big hits, big hp" at 255, 160 color "#cfc9d6" size 1 centered
}

fn chooseClass(cls) {
  heroClass = cls
  if cls == "mage" {
    maxHp = 7
    maxMana = 160
    boltCost = 15
    boltDmg = 5
    swordDmg = 2
    swingLen = 12
    moveSpeedBonus = 0
  } else if cls == "tank" {
    maxHp = 18
    maxMana = 40
    boltCost = 30
    boltDmg = 3
    swordDmg = 4
    swingLen = 20
    moveSpeedBonus = 1
  } else {
    maxHp = 10
    maxMana = 100
    boltCost = 25
    boltDmg = 3
    swordDmg = 2
    swingLen = 14
    moveSpeedBonus = 0
  }
  hp = maxHp
  mana = maxMana
  gameState = "play"
}

// ================================ main loop ===================================
buildWorld()
camX = constrain(hx + 5 - 160, 0, MW * 16 - 320)
camY = constrain(hy + 4 - 90, 0, MH * 16 - 180)

every frame {
  tick += 1

  if gameState == "menu" {
    if held("1") {
      chooseClass("warrior")
    } else if held("2") {
      chooseClass("mage")
    } else if held("3") {
      chooseClass("tank")
    } else if held("space") {
      chooseClass("warrior")
    }
    drawMenu()
  } else {
    updateHero()
    updateEnemies()
    updateBolts()
    updateParticles()

    let tcx = constrain(hx + 5 - 160, 0, MW * 16 - 320)
    let tcy = constrain(hy + 4 - 90, 0, MH * 16 - 180)
    camX += sign(tcx - camX) * max(1, abs(tcx - camX) / 6)
    camY += sign(tcy - camY) * max(1, abs(tcy - camY) / 6)

    paint "#3a1020"
    camera camX, camY
    drawWorld()
    drawNpcs()
    drawEnemies()
    drawBolts()
    drawPlayer()
    drawParticles()
    camera 0, 0
    drawUI()
  }
}
