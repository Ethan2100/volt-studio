// Dungeon crawler game: rooms, monsters, keys and a boss (pictures: dungeon.png)
// =====================================================================
//  MOONWELL - a top-down dungeon crawler, written in Volt
//
//  Find two keys, open the locked doors, and defeat the Ember King
//  so the Moonwell can shine again.
//
//  Arrows / WASD  move        X (or space)  swing, open, talk
//  Z              dash        On phones, use the on-screen pad.
//
//  Art: 16x16 DungeonTileset II by 0x72 (CC0) - dungeon.png
// =====================================================================
#html
title "Moonwell"

canvas 320, 180
touchpad "x", "z"

image tiles = "dungeon.png"

// ---------- sprites: rectangles cut out of dungeon.png ----------
// floors (frames are the different cracked versions)
sprite floorA = tiles at 16, 64 size 16, 16 frames 3
sprite floorB = tiles at 16, 80 size 16, 16 frames 3
sprite floorC = tiles at 16, 96 size 16, 16 frames 2
sprite wallFace = tiles at 32, 16 size 16, 16
sprite wallTop = tiles at 32, 0 size 16, 16
sprite bannerRB = tiles at 16, 32 size 16, 16 frames 2
sprite bannerGY = tiles at 16, 48 size 16, 16 frames 2
sprite fountainTop = tiles at 64, 0 size 16, 16
sprite fountain = tiles at 64, 48 size 16, 16 frames 3
sprite basin = tiles at 64, 64 size 16, 16 frames 3
sprite spikes = tiles at 16, 176 size 16, 16 frames 4
sprite ladder = tiles at 48, 96 size 16, 16
sprite doorShut = tiles at 32, 224 size 32, 32
sprite doorOpen = tiles at 80, 224 size 32, 32
sprite skull = tiles at 288, 320 size 16, 16
// things to pick up
sprite chestFull = tiles at 304, 304 size 16, 16 frames 3
sprite coin = tiles at 288, 272 size 8, 8 frames 4
sprite flask = tiles at 288, 240 size 16, 16
sprite heart = tiles at 288, 256 size 16, 16 frames 3
// the hero
sprite knightIdle = tiles at 128, 106 size 16, 22 frames 4
sprite knightRun = tiles at 192, 106 size 16, 22 frames 4
sprite knightHit = tiles at 256, 106 size 16, 22
sprite sword = tiles at 339, 120 size 10, 23
// monsters
sprite goblinIdle = tiles at 368, 37 size 16, 11 frames 4
sprite goblinRun = tiles at 432, 37 size 16, 11 frames 4
sprite skelIdle = tiles at 368, 80 size 16, 16 frames 4
sprite skelRun = tiles at 432, 80 size 16, 16 frames 4
sprite orcIdle = tiles at 368, 204 size 16, 20 frames 4
sprite orcRun = tiles at 432, 204 size 16, 20 frames 4
sprite chortIdle = tiles at 368, 328 size 16, 24 frames 4
sprite chortRun = tiles at 432, 328 size 16, 24 frames 4
sprite kingIdle = tiles at 16, 364 size 32, 36 frames 4
sprite kingRun = tiles at 144, 364 size 32, 36 frames 4

// ---------- the map ----------
// #  wall          .  floor        P  start      ^  spikes
// D  locked door   f  fountain     u  basin      b  banner
// k  chest (key)   c  chest (loot) $  coin       h  potion
// g  goblin        s  skeleton     o  orc        z  chort
// B  the Ember King                L  the ladder out
// x  old bones
let MW = 46
let MH = 45
let rows = [
  "##############################################",
  "##############################################",
  "######b###f###b################b###f###b######",
  "##........u.........########.......u.......###",
  "##.x..........L...x.########.h...........k.###",
  "##..................########.......s.......###",
  "##..................########...z...........###",
  "##........B.........########...............###",
  "##..................########...............###",
  "##..................########...........z...###",
  "##..................########...............###",
  "##..................########..s............###",
  "##..................########.............$$###",
  "##.x..............x.########...............###",
  "##..................##############..##########",
  "#########..#######################..##########",
  "#########..#######################..##########",
  "#########..#######################..##########",
  "#########..#######################..##########",
  "#######f#DD#f###############b#####DD####b#####",
  "#####..u....u..###########.................###",
  "#####..........###########.$$............k.###",
  "#####..........###########....o............###",
  "#####...............................g......###",
  "#####......................................###",
  "#####..........###########.................###",
  "#####.h......$.###########....^^^......o...###",
  "#####..........###########.................###",
  "##########################..g..............###",
  "##########################.................###",
  "#################################..###########",
  "#################################..###########",
  "####b#######b###########b########..#####b#####",
  "##.............######...............^^.....###",
  "##..$$$........######...............^^..g..###",
  "##.........g...######.....^^........^^.....###",
  "##.............######.....^^...s...........###",
  "##........................^^...............###",
  "##........................^^...............###",
  "##.....P.......######.....^^...........s...###",
  "##..........g..######.....^^...............###",
  "##.h...........######..s.....$$$...g.....c.###",
  "##.............######......................###",
  "##############################################",
  "##############################################",
]

// ---------- game state ----------
let mode = 0          // 0 title, 1 playing, 2 fallen, 3 won
let tick = 0
let playTime = 0
let grid = []         // one letter per map cell (changes when doors open)
let look = []         // which floor/wall picture each cell uses
let edge = []         // stone edges to draw around walls

// the hero (a small box at the feet; the picture sits on top of it)
let hx = 0
let hy = 0
let faceX = 0
let faceY = 1
let lookLeft = false
let moving = false
let hp = 6            // half hearts
let coins = 0
let keys = 0
let hurt = 0          // invincible frames after being hit
let swing = 0         // frames left in a sword swing
let swingHit = false
let dash = 0
let dashCool = 0
let kbx = 0
let kby = 0
let dying = 0
let checkX = 0
let checkY = 0

// monsters (one list per detail, same position = same monster)
let ex = []
let ey = []
let ekind = []
let ehp = []
let ehurt = []
let ekx = []
let eky = []
let etimer = []
let edx = []
let edy = []
let eleft = []
let ehome = []        // where it started (for the king)
let kingAwake = false
let kingDead = false
let kingShot = 0
let kingAngry = false

// chests, doors, things on the floor
let chx = []
let chy = []
let chWhat = []       // 1 key, 2 treasure
let chOpen = []
let drx = []
let dry = []
let drOpen = []
let ix = []
let iy = []
let ikind = []        // 1 coin, 2 potion
let ladX = 0
let ladY = 0

// fireballs and sparks (positions times 10 for smooth movement)
let bx = []
let by = []
let bvx = []
let bvy = []
let qx = []
let qy = []
let qvx = []
let qvy = []
let qlife = []
let qcol = []

// talking: a queue of messages, typed out letter by letter
let msgs = []
let shown = 0

let camX = 0
let camY = 0
let shake = 0
let freeze = 0
let seenB = false
let seenF = false
let seenKey = false
let healedAt = -1000

// 8 directions for the king's fireballs (speed x10), and a turned set
let ringX = [20, 14, 0, -14, -20, -14, 0, 14]
let ringY = [0, 14, 20, 14, 0, -14, -20, -14]
let ring2X = [18, 8, -8, -18, -18, -8, 8, 18]
let ring2Y = [8, 18, 18, 8, -8, -18, -18, -8]
let moonW = []

// =====================================================================
//  Setting up the level
// =====================================================================
fn cell(tx, ty) {
  if tx < 0 or ty < 0 or tx >= MW or ty >= MH {
    return "#"
  }
  return grid[ty * MW + tx]
}

fn isWall(tx, ty) {
  return contains("#bf", cell(tx, ty))
}

fn solidCell(tx, ty) {
  return contains("#bfuCD", cell(tx, ty))
}

fn spawnEnemy(kind, tx, ty) {
  let w = 12
  let h = 8
  if kind == 5 {
    w = 24
    h = 14
  }
  add tx * 16 + 8 - w / 2 to ex
  add ty * 16 + 14 - h to ey
  add kind to ekind
  let life = [0, 2, 3, 5, 3, 36]
  add life[kind] to ehp
  add 0 to ehurt
  add 0 to ekx
  add 0 to eky
  add random(0, 60) to etimer
  add 0 to edx
  add 0 to edy
  add false to eleft
  add ty * MW + tx to ehome
}

fn buildLevel() {
  grid = []
  look = []
  edge = []
  ex = []
  ey = []
  ekind = []
  ehp = []
  ehurt = []
  ekx = []
  eky = []
  etimer = []
  edx = []
  edy = []
  eleft = []
  ehome = []
  chx = []
  chy = []
  chWhat = []
  chOpen = []
  drx = []
  dry = []
  drOpen = []
  ix = []
  iy = []
  ikind = []
  bx = []
  by = []
  bvx = []
  bvy = []
  msgs = []
  // read the map letters
  for ty from 0 to MH - 1 {
    for tx from 0 to MW - 1 {
      let ch = rows[ty][tx]
      let keep = ch
      if ch == "P" {
        hx = tx * 16 + 3
        hy = ty * 16 + 6
        checkX = hx
        checkY = hy
        keep = "."
      } else if contains("gsozB", ch) {
        let kinds = "-gsozB"
        let k = 1
        while k < 6 {
          if kinds[k] == ch {
            spawnEnemy(k, tx, ty)
          }
          k += 1
        }
        keep = "."
      } else if ch == "$" or ch == "h" {
        add tx * 16 + 8 to ix
        add ty * 16 + 8 to iy
        if ch == "$" {
          add 1 to ikind
        } else {
          add 2 to ikind
        }
        keep = "."
      } else if ch == "k" or ch == "c" {
        add tx to chx
        add ty to chy
        if ch == "k" {
          add 1 to chWhat
        } else {
          add 2 to chWhat
        }
        add 0 to chOpen
        keep = "C"
      } else if ch == "L" {
        ladX = tx
        ladY = ty
        keep = "."
      } else if ch == "D" {
        if rows[ty][tx - 1] != "D" {
          add tx to drx
          add ty to dry
          add false to drOpen
        }
      }
      add keep to grid
    }
  }
  // choose a picture for every cell
  for ty from 0 to MH - 1 {
    for tx from 0 to MW - 1 {
      let pic = 0
      let ch = grid[ty * MW + tx]
      let below = cell(tx, ty + 1)
      if isWall(tx, ty) {
        if not isWall(tx, ty + 1) and below != "#" {
          pic = 10
          if ch == "b" {
            pic = 11 + (tx + ty) % 4
          }
          if ch == "f" {
            pic = 15
          }
        } else if contains("bf", below) or (below == "#" and not isWall(tx, ty + 2)) {
          pic = 20
          if cell(tx, ty + 1) == "f" {
            pic = 21
          }
        }
      } else {
        let roll = random(1, 100)
        pic = 1
        if roll > 86 {
          pic = random(2, 8)
        }
      }
      add pic to look
      // edges: 1 = open to the right, 2 = open to the left, 4 = open above
      let e = 0
      if isWall(tx, ty) and (pic == 0 or pic == 20 or pic == 21) {
        if not isWall(tx + 1, ty) {
          e += 1
        }
        if not isWall(tx - 1, ty) {
          e += 2
        }
        if not isWall(tx, ty - 1) {
          e += 4
        }
      }
      add e to edge
    }
  }
  // the moon on the title screen: a circle, one row at a time
  moonW = []
  for r from -18 to 18 {
    let w = 0
    while (w + 1) * (w + 1) + r * r <= 324 {
      w += 1
    }
    add w to moonW
  }
  kingAwake = false
  kingDead = false
  kingAngry = false
  kingShot = 0
  hp = 6
  coins = 0
  keys = 0
  hurt = 0
  swing = 0
  dash = 0
  dying = 0
  seenB = false
  seenF = false
  seenKey = false
  playTime = 0
  faceX = 0
  faceY = 1
}

// =====================================================================
//  Small helpers
// =====================================================================
fn overlap(ax, ay, aw, ah, ox, oy, ow, oh) {
  return ax < ox + ow and ox < ax + aw and ay < oy + oh and oy < ay + ah
}

// is a box (in pixels) touching anything solid?
fn blocked(px, py, w, h) {
  let x2 = (px + w - 1) / 16
  let y2 = (py + h - 1) / 16
  let x1 = px / 16
  let y1 = py / 16
  if px < 0 or py < 0 {
    return true
  }
  return solidCell(x1, y1) or solidCell(x2, y1) or solidCell(x1, y2) or solidCell(x2, y2)
}

fn say(words) {
  add words to msgs
}

fn burst(px, py, count, color, speed) {
  repeat count {
    add px * 10 to qx
    add py * 10 to qy
    add random(-speed, speed) to qvx
    add random(-speed, speed) to qvy
    add random(14, 30) to qlife
    add color to qcol
  }
}

fn spikeFrame() {
  let ph = tick % 150
  if ph < 80 {
    return 0
  }
  if ph < 86 {
    return 1
  }
  if ph < 92 {
    return 2
  }
  if ph < 128 {
    return 3
  }
  if ph < 136 {
    return 2
  }
  return 1
}

fn enemyW(k) {
  if k == 5 {
    return 24
  }
  return 12
}

fn enemyH(k) {
  if k == 5 {
    return 14
  }
  return 8
}

// how tall each monster's picture is
fn enemyTall(k) {
  let tall = [0, 11, 16, 20, 24, 36]
  return tall[k]
}

// =====================================================================
//  The hero
// =====================================================================
fn hurtHero(amount, fromX, fromY) {
  if hurt > 0 or dash > 0 or dying > 0 or mode != 1 {
    return 0
  }
  hp -= amount
  hurt = 70
  shake = 10
  freeze = 4
  kbx = sign(hx + 5 - fromX) * 4
  kby = sign(hy + 4 - fromY) * 4
  tone 240 to 70 for 160ms
  burst(hx + 5, hy - 4, 10, "#ff4d6d", 25)
  if hp <= 0 {
    hp = 0
    dying = 70
    tone 300 to 40 for 600ms
  }
}

fn moveHero(dx, dy) {
  if dx != 0 and not blocked(hx + dx, hy, 10, 8) {
    hx += dx
  }
  if dy != 0 and not blocked(hx, hy + dy, 10, 8) {
    hy += dy
  }
}

fn updateHero() {
  if dying > 0 {
    dying -= 1
    if dying == 1 {
      mode = 2
    }
    return 0
  }
  let mx = 0
  let my = 0
  if held("left") or held("a") {
    mx = -1
  }
  if held("right") or held("d") {
    mx = 1
  }
  if held("up") or held("w") {
    my = -1
  }
  if held("down") or held("s") {
    my = 1
  }
  moving = mx != 0 or my != 0
  if moving and swing == 0 and dash == 0 {
    faceX = mx
    faceY = my
    if mx != 0 and my != 0 {
      faceY = 0
    }
  }
  if mx < 0 {
    lookLeft = true
  }
  if mx > 0 {
    lookLeft = false
  }
  // walking speed: 1.5 pixels a frame (1 or 2 in turns)
  let speed = 1 + tick % 2
  if swing > 0 {
    speed = tick % 2
  }
  if dash > 0 {
    dash -= 1
    moveHero(faceX * 4, faceY * 4)
    if tick % 2 == 0 {
      burst(hx + 5, hy + 4, 1, "#9bd3ff", 6)
    }
  } else {
    moveHero(mx * speed, my * speed)
  }
  if dashCool > 0 {
    dashCool -= 1
  }
  // knockback slides
  if kbx != 0 or kby != 0 {
    moveHero(kbx, kby)
    kbx -= sign(kbx)
    kby -= sign(kby)
  }
  if hurt > 0 {
    hurt -= 1
  }
  // spikes
  let ftx = (hx + 5) / 16
  let fty = (hy + 4) / 16
  if cell(ftx, fty) == "^" and spikeFrame() == 3 {
    hurtHero(1, hx + 5, hy - 20)
  }
  // sword swing: it hits once, early in the swing
  if swing > 0 {
    swing -= 1
    if swing == 11 and not swingHit {
      swingHit = true
      swordHits()
    }
  }
}

fn swordHits() {
  let ax = hx - 7
  let ay = hy - 12
  let aw = 24
  let ah = 24
  if faceX > 0 {
    ax = hx + 8
    ay = hy - 16
    aw = 22
    ah = 28
  } else if faceX < 0 {
    ax = hx - 20
    ay = hy - 16
    aw = 22
    ah = 28
  } else if faceY < 0 {
    ax = hx - 9
    ay = hy - 34
    aw = 28
    ah = 24
  } else {
    ax = hx - 9
    ay = hy
    aw = 28
    ah = 22
  }
  let n = 0
  while n < length(ex) {
    let k = ekind[n]
    let tall = enemyTall(k)
    let w = enemyW(k)
    let h = enemyH(k)
    if ehurt[n] < 6 and overlap(ax, ay, aw, ah, ex[n] - 2, ey[n] + h - tall, w + 4, tall) {
      ehp[n] -= 1
      ehurt[n] = 12
      if k != 5 {
        ekx[n] = faceX * 5
        eky[n] = faceY * 5
      }
      freeze = 3
      shake = max(shake, 4)
      tone 180 to 60 for 70ms
      burst(ex[n] + w / 2, ey[n] + h - tall / 2, 8, "#ffffff", 22)
      if k == 5 {
        kingAwake = true
      }
    }
    n += 1
  }
}

// X: talk, open, drink, or swing
fn pressX() {
  if length(msgs) > 0 {
    if shown < length(msgs[0]) {
      shown = length(msgs[0])
    } else {
      remove msgs[0]
      shown = 0
    }
    return 0
  }
  if mode == 0 {
    startGame()
    return 0
  }
  if mode == 2 {
    respawn()
    return 0
  }
  if mode == 3 {
    mode = 0
    buildLevel()
    return 0
  }
  if dying > 0 {
    return 0
  }
  let cx = hx + 5
  let cy = hy + 4
  // a chest?
  let n = 0
  while n < length(chx) {
    if chOpen[n] == 0 and abs(chx[n] * 16 + 8 - cx) < 22 and abs(chy[n] * 16 + 8 - cy) < 22 {
      openChest(n)
      return 0
    }
    n += 1
  }
  // a door?
  n = 0
  while n < length(drx) {
    if not drOpen[n] and abs(drx[n] * 16 + 16 - cx) < 24 and abs(dry[n] * 16 + 8 - cy) < 28 {
      if keys > 0 {
        keys -= 1
        drOpen[n] = true
        grid[dry[n] * MW + drx[n]] = "d"
        grid[dry[n] * MW + drx[n] + 1] = "d"
        checkX = drx[n] * 16 + 11
        checkY = dry[n] * 16 + 20
        if cy < dry[n] * 16 {
          checkY = dry[n] * 16 - 10
        }
        shake = 6
        tone 110 to 55 for 300ms
        burst(drx[n] * 16 + 16, dry[n] * 16 + 8, 18, "#c9a27e", 20)
      } else {
        say("The door is locked tight.\nThere must be a key somewhere nearby.")
      }
      return 0
    }
    n += 1
  }
  // the ladder out?
  if kingDead and cx / 16 == ladX and cy / 16 == ladY {
    mode = 3
    tone 523 to 1046 for 500ms
    return 0
  }
  // the moonwater fountain?
  if cell(cx / 16, cy / 16 - 1) == "u" or cell((cx - 6) / 16, cy / 16 - 1) == "u" or cell((cx + 6) / 16, cy / 16 - 1) == "u" {
    hp = 6
    checkX = hx
    checkY = hy
    burst(cx, cy - 10, 20, "#9bd3ff", 18)
    tone 500 to 1200 for 300ms
    if tick - healedAt > 600 {
      say("The cold moonwater fills you with strength.\nYour hearts are restored.")
    }
    healedAt = tick
    return 0
  }
  // otherwise, swing the sword
  if swing == 0 and dash == 0 {
    swing = 16
    swingHit = false
    tone 320 to 140 for 50ms
  }
}

fn pressZ() {
  if mode != 1 or length(msgs) > 0 or dying > 0 {
    return 0
  }
  if dashCool == 0 and swing == 0 {
    dash = 9
    dashCool = 36
    tone 200 to 500 for 80ms
    if faceX == 0 and faceY == 0 {
      faceY = 1
    }
  }
}

fn openChest(n) {
  chOpen[n] = 1
  tone 400 to 800 for 120ms
  let px = chx[n] * 16 + 8
  let py = chy[n] * 16 + 4
  burst(px, py, 14, "#ffd23f", 16)
  if chWhat[n] == 1 {
    keys += 1
    tone 660 to 1320 for 250ms
    if not seenKey {
      seenKey = true
      say("You found a KEY!\nIt opens one locked door. Press X beside it.")
    } else {
      say("Another KEY. The Ember King's door\nis on the west side.")
    }
  } else {
    coins += 10
    add px to ix
    add py + 14 to iy
    add 2 to ikind
    say("Ten gold coins, and a healing potion!")
  }
}

fn startGame() {
  buildLevel()
  mode = 1
  camX = constrain(hx - 155, 0, MW * 16 - 320)
  camY = constrain(hy - 86, 0, MH * 16 - 180)
  say("Long ago, the Moonwell filled these halls\nwith silver light.")
  say("Then the Ember King climbed up from the\ndeep, and one by one the lights went out.")
  say("Since then, a hundred moons have passed\nin darkness...")
  say("You are the last knight of the old order.\nFind the keys. Wake the Moonwell.")
  say("ARROWS / WASD  move      X  swing, open\nZ  dash through danger")
}

fn respawn() {
  hx = checkX
  hy = checkY
  hp = 6
  hurt = 90
  dying = 0
  swing = 0
  dash = 0
  kbx = 0
  kby = 0
  mode = 1
  bx = []
  by = []
  bvx = []
  bvy = []
  // the king goes back to his throne if he's still around
  let n = 0
  while n < length(ex) {
    if ekind[n] == 5 {
      ehp[n] = 36
      ex[n] = (ehome[n] % MW) * 16 - 4
      ey[n] = (ehome[n] / MW) * 16
      kingAwake = false
      kingAngry = false
    }
    n += 1
  }
  say("You rise again, a little wiser.")
}

// =====================================================================
//  Monsters
// =====================================================================
fn moveEnemy(n, dx, dy) {
  let w = enemyW(ekind[n])
  let h = enemyH(ekind[n])
  if dx != 0 and not blocked(ex[n] + dx, ey[n], w, h) {
    ex[n] += dx
  }
  if dy != 0 and not blocked(ex[n], ey[n] + dy, w, h) {
    ey[n] += dy
  }
}

fn updateEnemies() {
  let n = 0
  while n < length(ex) {
    let k = ekind[n]
    let w = enemyW(k)
    let h = enemyH(k)
    let dx = hx + 5 - (ex[n] + w / 2)
    let dy = hy + 4 - (ey[n] + h / 2)
    let far = abs(dx) + abs(dy)
    if ehurt[n] > 0 {
      ehurt[n] -= 1
    }
    // knocked back?
    if ekx[n] != 0 or eky[n] != 0 {
      moveEnemy(n, ekx[n], eky[n])
      ekx[n] -= sign(ekx[n])
      eky[n] -= sign(eky[n])
    } else if k == 5 {
      updateKing(n, dx, dy)
    } else {
      // speed: goblins and chorts are quick, orcs are slow
      let go = true
      if k == 2 {
        go = tick % 3 != 0
      }
      if k == 3 {
        go = tick % 2 == 0
      }
      if far < 110 and dying == 0 {
        if go {
          moveEnemy(n, sign(dx), sign(dy))
          if k == 4 and tick % 20 < 10 {
            moveEnemy(n, sign(dy), 0 - sign(dx))
          }
        }
        eleft[n] = dx < 0
      } else {
        etimer[n] -= 1
        if etimer[n] <= 0 {
          etimer[n] = random(40, 110)
          edx[n] = random(-1, 1)
          edy[n] = random(-1, 1)
        }
        if go and tick % 2 == 0 {
          moveEnemy(n, edx[n], edy[n])
          if edx[n] != 0 {
            eleft[n] = edx[n] < 0
          }
        }
      }
    }
    // touching the hero hurts
    if overlap(hx, hy, 10, 8, ex[n] - 2, ey[n] - 2, w + 4, h + 4) {
      let dmg = 1
      if k == 3 or k == 5 {
        dmg = 2
      }
      hurtHero(dmg, ex[n] + w / 2, ey[n] + h / 2)
    }
    // defeated?
    if ehp[n] <= 0 {
      killEnemy(n)
    } else {
      n += 1
    }
  }
}

fn killEnemy(n) {
  let k = ekind[n]
  let px = ex[n] + enemyW(k) / 2
  let py = ey[n] + enemyH(k) / 2
  burst(px, py - 6, 22, "#ff8a3d", 28)
  burst(px, py - 6, 10, "#6b5b55", 16)
  tone 300 to 40 for 200ms
  shake = max(shake, 6)
  let roll = random(1, 100)
  if roll <= 45 {
    add px to ix
    add py to iy
    add 1 to ikind
  } else if roll <= 60 {
    add px to ix
    add py to iy
    add 2 to ikind
  }
  if k == 5 {
    kingDead = true
    shake = 40
    freeze = 20
    bx = []
    by = []
    bvx = []
    bvy = []
    burst(px, py - 10, 60, "#ffd23f", 45)
    burst(px, py - 10, 40, "#e8f4ff", 35)
    tone 80 to 30 for 1200ms
    say("The Ember King crumbles into cinders...")
    say("Silver light floods the halls once more.\nA ladder leads up, to the surface.")
  }
  remove ex[n]
  remove ey[n]
  remove ekind[n]
  remove ehp[n]
  remove ehurt[n]
  remove ekx[n]
  remove eky[n]
  remove etimer[n]
  remove edx[n]
  remove edy[n]
  remove eleft[n]
  remove ehome[n]
}

fn updateKing(n, dx, dy) {
  if not kingAwake {
    return 0
  }
  eleft[n] = dx < 0
  if tick % 2 == 0 {
    moveEnemy(n, sign(dx), sign(dy))
  }
  if ehp[n] <= 18 and not kingAngry {
    kingAngry = true
    say("THE EMBER KING:\nRise, my servants! Burn this knight!")
    spawnEnemy(1, 3, 4)
    spawnEnemy(1, 18, 4)
    spawnEnemy(4, 3, 12)
    burst(56, 70, 16, "#ff8a3d", 20)
    burst(296, 70, 16, "#ff8a3d", 20)
  }
  kingShot += 1
  let gap = 130
  if kingAngry {
    gap = 80
  }
  if kingShot >= gap {
    kingShot = 0
    let px = ex[n] + 12
    let py = ey[n] - 8
    let d = 0
    while d < 8 {
      if kingAngry and tick % 2 == 0 {
        fireball(px, py, ring2X[d], ring2Y[d])
      } else {
        fireball(px, py, ringX[d], ringY[d])
      }
      d += 1
    }
    tone 500 to 180 for 120ms
    burst(px, py, 10, "#ff8a3d", 20)
  }
}

fn fireball(px, py, vx, vy) {
  add px * 10 to bx
  add py * 10 to by
  add vx to bvx
  add vy to bvy
}

fn updateFireballs() {
  let n = 0
  while n < length(bx) {
    bx[n] += bvx[n]
    by[n] += bvy[n]
    let px = bx[n] / 10
    let py = by[n] / 10
    let gone = false
    if isWall(px / 16, py / 16) {
      gone = true
      burst(px, py, 5, "#ff8a3d", 14)
    } else if overlap(hx, hy - 12, 10, 20, px - 3, py - 3, 6, 6) {
      hurtHero(1, px, py)
      gone = true
    }
    if gone {
      remove bx[n]
      remove by[n]
      remove bvx[n]
      remove bvy[n]
    } else {
      n += 1
    }
  }
}

// =====================================================================
//  Items, sparks, rooms
// =====================================================================
fn updateItems() {
  let n = 0
  while n < length(ix) {
    let took = false
    if abs(ix[n] - (hx + 5)) < 11 and abs(iy[n] - (hy + 2)) < 12 {
      if ikind[n] == 1 {
        coins += 1
        tone 988 to 1480 for 70ms
        burst(ix[n], iy[n], 5, "#ffd23f", 12)
        took = true
      } else if hp < 6 {
        hp = min(6, hp + 2)
        tone 440 to 880 for 200ms
        burst(ix[n], iy[n], 10, "#ff4d6d", 14)
        took = true
      }
    }
    if took {
      remove ix[n]
      remove iy[n]
      remove ikind[n]
    } else {
      n += 1
    }
  }
  n = 0
  while n < length(chx) {
    if chOpen[n] > 0 and chOpen[n] < 20 {
      chOpen[n] += 1
    }
    n += 1
  }
}

fn updateSparks() {
  let n = 0
  while n < length(qx) {
    qx[n] += qvx[n]
    qy[n] += qvy[n]
    qvx[n] = qvx[n] * 9 / 10
    qvy[n] = qvy[n] * 9 / 10
    qlife[n] -= 1
    if qlife[n] <= 0 {
      remove qx[n]
      remove qy[n]
      remove qvx[n]
      remove qvy[n]
      remove qlife[n]
      remove qcol[n]
    } else {
      n += 1
    }
  }
}

fn checkRooms() {
  let tx = (hx + 5) / 16
  let ty = (hy + 4) / 16
  if not seenB and tx >= 21 and ty >= 33 {
    seenB = true
    say("Spikes rise and fall in these halls.\nWatch their rhythm... or dash across.")
  }
  if not seenF and tx <= 15 and ty >= 20 and ty <= 27 {
    seenF = true
    say("A fountain of moonwater. Press X beside it\nto heal. Heat pours from the door above...")
  }
  if not kingAwake and not kingDead and ty <= 13 and tx <= 20 {
    kingAwake = true
    shake = 20
    tone 90 to 40 for 900ms
    say("THE EMBER KING:\nAnother little knight, come to be ash?")
    say("THE EMBER KING:\nThe Moonwell is MINE. Burn!")
  }
}

fn updateCamera() {
  let tx = constrain(hx + 5 - 160, 0, MW * 16 - 320)
  let ty = constrain(hy - 86, 0, MH * 16 - 180)
  let d = tx - camX
  if d != 0 {
    camX += sign(d) * max(1, abs(d) / 6)
  }
  d = ty - camY
  if d != 0 {
    camY += sign(d) * max(1, abs(d) / 6)
  }
  if shake > 0 {
    shake -= 1
  }
}

fn update() {
  if freeze > 0 {
    freeze -= 1
    return 0
  }
  playTime += 1
  updateHero()
  updateEnemies()
  updateFireballs()
  updateItems()
  checkRooms()
}

// =====================================================================
//  Drawing
// =====================================================================
fn drawCell(tx, ty) {
  if tx < 0 or ty < 0 or tx >= MW or ty >= MH {
    return 0
  }
  let i = ty * MW + tx
  let pic = look[i]
  let x = tx * 16
  let y = ty * 16
  if pic >= 1 and pic <= 3 {
    draw floorA at x, y frame pic - 1
  } else if pic >= 4 and pic <= 6 {
    draw floorB at x, y frame pic - 4
  } else if pic == 7 or pic == 8 {
    draw floorC at x, y frame pic - 7
  } else if pic == 10 {
    draw wallFace at x, y
  } else if pic == 11 or pic == 12 {
    draw bannerRB at x, y frame pic - 11
  } else if pic == 13 or pic == 14 {
    draw bannerGY at x, y frame pic - 13
  } else if pic == 15 {
    draw fountain at x, y frame tick / 8
  } else if pic == 20 {
    draw wallTop at x, y
  } else if pic == 21 {
    draw fountainTop at x, y
  }
  // things painted on the floor
  let ch = grid[i]
  if ch == "^" {
    draw spikes at x, y frame spikeFrame()
  } else if ch == "u" {
    draw basin at x, y frame tick / 8
  } else if ch == "x" {
    draw skull at x, y
  }
  if kingDead and tx == ladX and ty == ladY {
    draw ladder at x, y
  }
  // stone edges around the walls
  let e = edge[i]
  if e > 0 {
    if e % 2 == 1 {
      box x + 13, y, 3, 16 color "#aa8d7a"
      box x + 15, y, 1, 16 color "#d3bfa9"
      box x + 12, y, 1, 16 color "#222222"
    }
    if e / 2 % 2 == 1 {
      box x, y, 3, 16 color "#aa8d7a"
      box x, y, 1, 16 color "#d3bfa9"
      box x + 3, y, 1, 16 color "#222222"
    }
    if e / 4 % 2 == 1 {
      box x, y, 16, 3 color "#aa8d7a"
      box x, y, 16, 1 color "#d3bfa9"
      box x, y + 3, 16, 1 color "#222222"
    }
  }
}

fn drawEnemy(n) {
  let k = ekind[n]
  let tall = enemyTall(k)
  let w = enemyW(k)
  let h = enemyH(k)
  let sw = 16
  if k == 5 {
    sw = 32
  }
  let x = ex[n] + w / 2 - sw / 2
  let y = ey[n] + h - tall
  let f = (tick + n * 7) / 8
  let run = ekx[n] == 0 and (k != 5 or kingAwake)
  let hit = ehurt[n] > 6
  let left = eleft[n]
  // a soft shadow under everyone
  box ex[n], ey[n] + h - 2, w, 3 color "#00000055"
  if k == 1 {
    if run {
      draw goblinRun at x, y frame f flip left flash hit
    } else {
      draw goblinIdle at x, y frame f flip left flash hit
    }
  } else if k == 2 {
    if run {
      draw skelRun at x, y frame f flip left flash hit
    } else {
      draw skelIdle at x, y frame f flip left flash hit
    }
  } else if k == 3 {
    if run {
      draw orcRun at x, y frame f flip left flash hit
    } else {
      draw orcIdle at x, y frame f flip left flash hit
    }
  } else if k == 4 {
    if run {
      draw chortRun at x, y frame f flip left flash hit
    } else {
      draw chortIdle at x, y frame f flip left flash hit
    }
  } else {
    if kingAwake {
      draw kingRun at x, y frame f flip left flash hit
    } else {
      draw kingIdle at x, y frame f flip left flash hit
    }
  }
}

fn drawHero() {
  let x = hx - 3
  let y = hy - 14
  let f = tick / 7
  let blink = hurt > 0 and tick % 6 < 3
  box hx, hy + 6, 10, 3 color "#00000055"
  // dash leaves ghosts behind
  if dash > 0 {
    draw knightRun at x - faceX * 8, y - faceY * 8 frame f flip lookLeft alpha 35
    draw knightRun at x - faceX * 16, y - faceY * 16 frame f flip lookLeft alpha 15
  }
  // the sword: behind the knight when facing up
  if faceY < 0 {
    drawSword()
  }
  if dying > 0 {
    draw knightHit at x, y flip lookLeft alpha dying + 30
  } else if blink {
    draw knightHit at x, y flip lookLeft alpha 60
  } else if moving {
    draw knightRun at x, y frame f flip lookLeft
  } else {
    draw knightIdle at x, y frame f flip lookLeft
  }
  if faceY >= 0 {
    drawSword()
  }
}

fn drawSword() {
  if dying > 0 {
    return 0
  }
  let cx = hx + 5
  let cy = hy - 4
  if swing == 0 {
    // resting at the side
    if lookLeft {
      draw sword at cx - 13, cy - 13 angle -20
    } else {
      draw sword at cx + 3, cy - 13 angle 20
    }
    return 0
  }
  let base = 180
  if faceX > 0 {
    base = 90
  } else if faceX < 0 {
    base = 270
  } else if faceY < 0 {
    base = 0
  }
  let sweep = (16 - swing) * 9 - 70
  let ox = faceX * 13
  let oy = faceY * 13
  if faceX == 0 and faceY == 0 {
    oy = 13
  }
  draw sword at cx + ox - 5, cy + oy - 11 angle base + sweep
  // a bright slash trail
  if swing > 9 {
    box cx + ox - 2 + faceY * (swing - 12) * 2, cy + oy - 2 + faceX * (12 - swing) * 2, 4, 4 color "#ffffffcc"
  }
}

fn drawWorld() {
  paint "#100c14"
  let sx = 0
  let sy = 0
  if shake > 0 {
    sx = random(-2, 2) * min(shake, 6) / 3
    sy = random(-2, 2) * min(shake, 6) / 3
  }
  camera camX + sx, camY + sy
  let t0x = camX / 16 - 1
  let t0y = camY / 16 - 1
  for ty from t0y to t0y + 13 {
    for tx from t0x to t0x + 22 {
      drawCell(tx, ty)
    }
  }
  // doors
  let n = 0
  while n < length(drx) {
    if drOpen[n] {
      draw doorOpen at drx[n] * 16, dry[n] * 16 - 16
    } else {
      draw doorShut at drx[n] * 16, dry[n] * 16 - 16
    }
    n += 1
  }
  // chests and things on the floor
  n = 0
  while n < length(chx) {
    draw chestFull at chx[n] * 16, chy[n] * 16 frame min(2, chOpen[n] / 4)
    n += 1
  }
  n = 0
  while n < length(ix) {
    let bob = (tick / 10 + n) % 4
    if bob == 3 {
      bob = 1
    }
    if ikind[n] == 1 {
      draw coin at ix[n] - 4, iy[n] - 6 - bob frame tick / 6 + n
    } else {
      draw flask at ix[n] - 8, iy[n] - 12 - bob
    }
    n += 1
  }
  // monsters behind the hero, the hero, then monsters in front
  n = 0
  while n < length(ex) {
    if ey[n] + enemyH(ekind[n]) <= hy + 8 {
      drawEnemy(n)
    }
    n += 1
  }
  drawHero()
  n = 0
  while n < length(ex) {
    if ey[n] + enemyH(ekind[n]) > hy + 8 {
      drawEnemy(n)
    }
    n += 1
  }
  // fireballs
  n = 0
  while n < length(bx) {
    let px = bx[n] / 10
    let py = by[n] / 10
    box px - 4, py - 4, 8, 8 color "#ff8a3d55"
    box px - 3, py - 3, 6, 6 color "#ff5a1f"
    box px - 1, py - 2, 3, 3 color "#ffe08a"
    n += 1
  }
  // sparks
  n = 0
  while n < length(qx) {
    let size = 2
    if qlife[n] < 8 {
      size = 1
    }
    box qx[n] / 10, qy[n] / 10, size, size color qcol[n]
    n += 1
  }
  camera 0, 0
}

fn drawVignette() {
  let k = 0
  while k < 6 {
    box 0, k * 3, 320, 3 color "#0000001a"
    box 0, 177 - k * 3, 320, 3 color "#0000001a"
    box k * 3, 0, 3, 180 color "#0000001a"
    box 317 - k * 3, 0, 3, 180 color "#0000001a"
    k += 1
  }
}

fn drawKey(x, y) {
  box x, y + 2, 5, 5 color "#ffd23f"
  box x + 1, y + 3, 3, 3 color "#100c14"
  box x + 5, y + 4, 7, 2 color "#ffd23f"
  box x + 9, y + 6, 2, 2 color "#ffd23f"
  box x + 11, y + 6, 1, 2 color "#ffd23f"
}

fn drawHud() {
  let k = 0
  while k < 3 {
    let v = hp - k * 2
    let pic = 2
    if v >= 2 {
      pic = 0
    } else if v == 1 {
      pic = 1
    }
    draw heart at 4 + k * 14, 3 frame pic
    k += 1
  }
  draw coin at 270, 7 frame tick / 6
  write "x" + coins at 281, 7 shadow
  if keys > 0 {
    drawKey(244, 4)
    write "" + keys at 258, 7 color "#ffd23f" shadow
  }
  // the king's health bar
  if kingAwake and not kingDead and length(msgs) == 0 {
    let n = 0
    while n < length(ex) {
      if ekind[n] == 5 {
        write "THE EMBER KING" at 160, 158 centered color "#ffb38a" shadow
        box 79, 167, 162, 7 color "#000000aa"
        box 80, 168, 160, 5 color "#3a1518"
        box 80, 168, ehp[n] * 160 / 36, 5 color "#ff5a1f"
        box 80, 168, ehp[n] * 160 / 36, 1 color "#ffb38a"
      }
      n += 1
    }
  }
}

fn drawTalk() {
  let words = msgs[0]
  if tick % 2 == 0 and shown < length(words) {
    shown += 1
    if shown % 3 == 0 {
      tone 640 for 12ms
    }
  }
  box 8, 126, 304, 48 color "#05040acc"
  box 8, 126, 304, 1 color "#d3bfa9"
  box 8, 173, 304, 1 color "#d3bfa9"
  box 8, 126, 1, 48 color "#d3bfa9"
  box 311, 126, 1, 48 color "#d3bfa9"
  write part(words, 0, shown) at 18, 136 shadow
  if shown >= length(words) and tick / 20 % 2 == 0 {
    box 298, 162, 6, 2 color "#ffd23f"
    box 299, 164, 4, 1 color "#ffd23f"
    box 300, 165, 2, 1 color "#ffd23f"
  }
}

fn drawMoon(cx, cy) {
  let r = 0
  while r < length(moonW) {
    let w = moonW[r]
    box cx - w, cy - 18 + r, w * 2, 1 color "#e8f4ff"
    r += 1
  }
  box cx - 8, cy - 6, 5, 4 color "#c9dbea"
  box cx + 4, cy + 3, 7, 5 color "#c9dbea"
  box cx - 2, cy + 9, 4, 3 color "#c9dbea"
}

fn titleScreen() {
  // the dungeon slowly drifts past behind the title
  camX = 120 + (tick / 3) % 400
  camY = 260
  drawWorld()
  box 0, 0, 320, 180 color "#0b0814bb"
  drawMoon(160, 40)
  write "MOONWELL" at 160, 70 size 4 centered color "#e8f4ff" shadow
  write "a dungeon crawler written in Volt" at 160, 110 centered color "#9a8fb0"
  if tick / 30 % 2 == 0 {
    write "PRESS X TO BEGIN" at 160, 136 centered color "#ffd23f" shadow
  }
  write "art: 0x72 (CC0)" at 160, 166 centered color "#5d5470"
}

fn endScreen() {
  box 0, 0, 320, 180 color "#000000aa"
  if mode == 2 {
    write "YOU FELL" at 160, 62 size 3 centered color "#ff4d6d" shadow
    write "Press X to rise again" at 160, 104 centered shadow
  } else {
    if tick % 4 == 0 {
      burst(random(0, 320) + camX, random(0, 180) + camY, 1, "#e8f4ff", 8)
    }
    drawMoon(160, 34)
    write "THE MOONWELL WAKES" at 160, 70 size 2 centered color "#e8f4ff" shadow
    let secs = playTime / 60
    let mins = secs / 60
    secs = secs % 60
    let pad = ""
    if secs < 10 {
      pad = "0"
    }
    write "Gold: " + coins + "     Time: " + mins + ":" + pad + secs at 160, 100 centered color "#ffd23f" shadow
    write "Thanks for playing!   Press X" at 160, 124 centered shadow
  }
}

// =====================================================================
//  Start up, keys and the main loop
// =====================================================================
buildLevel()

when key "x" pressed {
  pressX()
}
when key "space" pressed {
  pressX()
}
when key "enter" pressed {
  pressX()
}
when key "z" pressed {
  pressZ()
}
when key "shift" pressed {
  pressZ()
}

every frame {
  tick += 1
  if mode == 0 {
    titleScreen()
  } else {
    if mode == 1 and length(msgs) == 0 {
      update()
    }
    updateSparks()
    updateCamera()
    drawWorld()
    drawVignette()
    drawHud()
    if mode >= 2 and length(msgs) == 0 {
      endScreen()
    }
  }
  if length(msgs) > 0 {
    drawTalk()
  }
}
