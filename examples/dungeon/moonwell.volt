// Dungeon crawler game: three floors, a shop, weapons, music and saves (pictures: dungeon.png)
// =====================================================================
//  MOONWELL - a top-down dungeon crawler, written in Volt
//
//  Go down three floors, find the keys, buy better weapons at the
//  Rest Camp, and defeat the Ember King so the Moonwell can shine.
//
//  Arrows / WASD  move          X (or space)  swing, open, talk, buy
//  Z              dash          C             switch weapon
//  M              music on/off  On phones, use the on-screen pad.
//
//  Your journey is saved at every floor, so you can continue later.
//  Art: 16x16 DungeonTileset II by 0x72 (CC0) - dungeon.png
// =====================================================================
#html
title "Moonwell"

canvas 320, 180
touchpad "x", "z", "c"

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
sprite lavaFall = tiles at 64, 16 size 16, 16 frames 3
sprite lavaPool = tiles at 64, 32 size 16, 16 frames 3
sprite spikes = tiles at 16, 176 size 16, 16 frames 4
sprite ladder = tiles at 48, 96 size 16, 16
sprite doorShut = tiles at 32, 224 size 32, 32
sprite doorOpen = tiles at 80, 224 size 32, 32
sprite skull = tiles at 288, 320 size 16, 16
sprite crate = tiles at 288, 298 size 16, 22
// things to pick up
sprite chestFull = tiles at 304, 304 size 16, 16 frames 3
sprite coin = tiles at 288, 272 size 8, 8 frames 4
sprite flask = tiles at 288, 240 size 16, 16
sprite bigFlask = tiles at 288, 224 size 16, 16
sprite heart = tiles at 288, 256 size 16, 16 frames 3
// the hero and the camp's mage
sprite knightIdle = tiles at 128, 106 size 16, 22 frames 4
sprite knightRun = tiles at 192, 106 size 16, 22 frames 4
sprite knightHit = tiles at 256, 106 size 16, 22
sprite mage = tiles at 128, 170 size 16, 22 frames 4
// weapons
sprite rusty = tiles at 307, 26 size 10, 21
sprite knightSword = tiles at 339, 120 size 10, 23
sprite hammer = tiles at 291, 42 size 10, 37
sprite goldSword = tiles at 291, 153 size 10, 22
sprite staff = tiles at 324, 145 size 8, 30
// monsters
sprite goblinIdle = tiles at 368, 37 size 16, 11 frames 4
sprite goblinRun = tiles at 432, 37 size 16, 11 frames 4
sprite skelIdle = tiles at 368, 80 size 16, 16 frames 4
sprite skelRun = tiles at 432, 80 size 16, 16 frames 4
sprite orcIdle = tiles at 368, 204 size 16, 20 frames 4
sprite orcRun = tiles at 432, 204 size 16, 20 frames 4
sprite chortIdle = tiles at 368, 328 size 16, 24 frames 4
sprite chortRun = tiles at 432, 328 size 16, 24 frames 4
sprite zombie = tiles at 368, 144 size 16, 16 frames 4
sprite iceZombie = tiles at 432, 144 size 16, 16 frames 4
sprite slime = tiles at 432, 112 size 16, 16 frames 4
sprite maskIdle = tiles at 368, 172 size 16, 20 frames 4
sprite maskRun = tiles at 432, 172 size 16, 20 frames 4
sprite shamanIdle = tiles at 368, 236 size 16, 20 frames 4
sprite shamanRun = tiles at 432, 236 size 16, 20 frames 4
sprite necro = tiles at 366, 270 size 16, 20 frames 4
sprite tinyIdle = tiles at 368, 20 size 16, 12 frames 4
sprite tinyRun = tiles at 432, 20 size 16, 12 frames 4
sprite impIdle = tiles at 368, 48 size 16, 16 frames 4
sprite impRun = tiles at 432, 48 size 16, 16 frames 4
// bosses
sprite kingIdle = tiles at 16, 364 size 32, 36 frames 4
sprite kingRun = tiles at 144, 364 size 32, 36 frames 4
sprite ogreIdle = tiles at 16, 320 size 32, 32 frames 4
sprite ogreRun = tiles at 144, 320 size 32, 32 frames 4
sprite wardenIdle = tiles at 16, 270 size 32, 34 frames 4
sprite wardenRun = tiles at 144, 270 size 32, 34 frames 4

// ---------- the maps ----------
// #  wall          .  floor        P  start      ^  spikes
// D  locked door   f  moonwater    u  its basin  b  banner
// r  lava fall     v  lava pool    x  old bones  L  ladder down
// k  chest (key)   c  chest (gold) w  chest (weapon)
// $  coin          h  potion       K  the mage   1-6  things for sale
// monsters:  g goblin  s skeleton  o orc  z chort  Z zombie  i ice zombie
//            m slime  M masked orc  S shaman  N necromancer  t tiny zombie
//            I imp    B the floor's boss
let shopRows = [
  "##################",
  "##################",
  "###b#f###b###b####",
  "##...u..........##",
  "##.........K....##",
  "##..............##",
  "##.1.2.3..4.5.6.##",
  "##..............##",
  "##..............##",
  "##.......P....L.##",
  "##..............##",
  "##################",
]
let rows1 = [
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
  "##..................########.w...........$$###",
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
let rows2 = [
  "############################################",
  "###############b###########b################",
  "############....................############",
  "############.x..L.............x.############",
  "############....................############",
  "############.........B..........############",
  "############....................############",
  "############....................############",
  "############.x................x.############",
  "#####################..#####################",
  "#####################..#####################",
  "#####################..#####################",
  "#######f#######b#####DD####b################",
  "###....u....###..............###############",
  "###w........###.$..$s.$..$...###############",
  "###.........###..............###############",
  "###.........###...#......#...###############",
  "###...N...........#......#...###############",
  "###...................N......###############",
  "###.........###..m...........###############",
  "###......t..###.....^^^^..m..###############",
  "###.t.......###..............###############",
  "###........h###...#......#...###############",
  "###############...#......#...###############",
  "###############......m.......###############",
  "###############.........s....###############",
  "###############..............###############",
  "#####################..#####################",
  "#####b####b##########..##########b####b#####",
  "###..........########..########.........k###",
  "###.h...^..$.#####b##..##b#####$.......t.###",
  "###..Z..^..$.####..........####...i......###",
  "###.....^....####..........####..........###",
  "###....Z^...........................t....###",
  "###.....^................................###",
  "###.....^.Z..####....P.....####.......i..###",
  "###c....^....####..........####.$t.......###",
  "###..........####..........####..........###",
  "############################################",
  "############################################",
]
let rows3 = [
  "##############################################",
  "######r#####b#####r###########################",
  "##....v...........v....########r#######r######",
  "##.x.............L...x.#####w..v.......v..k###",
  "##.....................#####......S........###",
  "##.....................#####............M..###",
  "##..........B..........#####...z...........###",
  "##.....................#####...............###",
  "##.....................#####...............###",
  "##.....................#####...........z...###",
  "##.....................#####...............###",
  "##.x.................x.#####...............###",
  "##.....................#####..............h###",
  "#########..########################..#########",
  "#########..########################..#########",
  "#########..########################..#########",
  "#########..########################..#########",
  "#####b###DD##f################b####DD###b#####",
  "####.........u...###########$.............k###",
  "####.............###########.............S.###",
  "####..........S..###########...............###",
  "####.............###########...M...........###",
  "####.............###########...............###",
  "####.......................................###",
  "####..M....................................###",
  "####.............###########...........M...###",
  "####.............###########...............###",
  "####.h.........$.###########.I.............###",
  "####.............###########...............###",
  "###################################..#########",
  "###################################..#########",
  "###################################..#########",
  "#####b##################b######b###..###b#####",
  "###..........#######.......................###",
  "###.......I..#######.........I.........o...###",
  "###..........#######.....o.................###",
  "###....P......................^^^..........###",
  "###........$..................^^^o.........###",
  "###.h......$.#######.................I.....###",
  "###..........#######.$$...................c###",
  "##############################################",
  "##############################################",
]
let maps = [shopRows, rows1, rows2, rows3]
let floorNames = ["THE REST CAMP", "THE UPPER HALLS", "THE DROWNED CRYPT", "THE EMBER THRONE"]
let floorBoss = [0, 14, 15, 5]

// ---------- monsters: one entry per kind ----------
// kinds: 1 goblin, 2 skeleton, 3 orc, 4 chort, 5 Ember King, 6 zombie, 7 ice zombie,
//        8 slime, 9 masked orc, 10 shaman, 11 necromancer, 12 tiny zombie, 13 imp,
//        14 Grukk the ogre, 15 the Rotting Warden
let kindLetters = "-gsozBZimMSNtI"
let kindLife = [0, 2, 3, 5, 3, 44, 4, 7, 3, 7, 4, 5, 1, 2, 34, 38]
let kindTall = [0, 11, 16, 20, 24, 36, 16, 16, 16, 20, 20, 20, 12, 16, 32, 34]
let kindHit = [0, 1, 1, 2, 1, 2, 1, 2, 1, 2, 1, 1, 1, 1, 2, 2]
let kindPace = [0, 1, 3, 2, 1, 2, 2, 3, 2, 2, 2, 3, 1, 1, 2, 3]

// ---------- weapons ----------
let wName = ["", "Rusty Sword", "Knight Sword", "Big Hammer", "Golden Sword", "Ember Staff"]
let wInfo = ["", "Old, but it cuts.", "Hits twice as hard.", "Slow, huge reach, 3 damage.", "Fast and deadly, 3 damage.", "Shoots flames that pass through foes."]
let wDmg = [0, 1, 2, 3, 3, 2]
let wLen = [0, 16, 16, 26, 12, 18]
let wReach = [0, 0, 2, 9, 2, 0]
let wW = [0, 10, 10, 10, 10, 8]
let wH = [0, 21, 23, 37, 22, 30]
// the shop: 1 potion, 2 heart vessel, 3-6 weapons 2-5
let shopName = ["", "Healing Potion", "Heart Vessel", "Knight Sword", "Big Hammer", "Golden Sword", "Ember Staff"]
let shopCost = [0, 8, 35, 25, 45, 70, 60]

// ---------- music (each word is one step: a note, - for rest, _ to hold) ----------
let songTitle = "a4 _ c5 e5 a5 _ g5 e5 f5 _ e5 c5 d5 _ b4 _ a4 _ c5 e5 a5 _ b5 c6 b5 _ g5 e5 e5 _ _ _"
let bassTitle = "a2 _ _ _ a2 _ _ _ f2 _ _ _ g2 _ _ _ a2 _ _ _ a2 _ _ _ e2 _ _ _ e2 _ _ _"
let songHalls = "d5 - a4 d5 f5 _ e5 d5 c5 - a4 c5 e5 _ d5 c5 a#4 - f4 a#4 d5 _ c5 a#4 a4 _ c#5 _ e5 _ - -"
let bassHalls = "d3 - d3 - d3 - d3 - c3 - c3 - c3 - c3 - a#2 - a#2 - a#2 - a#2 - a2 - a2 - a2 - e2 -"
let songCrypt = "e5 _ _ - g5 _ f#5 _ e5 _ _ - b4 _ _ - c5 _ _ - d5 _ c5 _ b4 _ _ _ - - - -"
let bassCrypt = "e2 _ b2 _ e3 _ b2 _ c3 _ g2 _ c3 _ g2 _ a2 _ e3 _ a2 _ e3 _ b2 _ f#2 _ b2 _ - _"
let songThrone = "c5 c5 g4 c5 d#5 - d5 c5 g5 _ f5 d#5 d5 - a#4 - c5 c5 g4 c5 d#5 - f5 g5 g#5 _ g5 f5 g5 _ _ -"
let bassThrone = "c3 c3 c3 c3 c3 c3 c3 c3 a#2 a#2 a#2 a#2 a#2 a#2 a#2 a#2 g#2 g#2 g#2 g#2 g#2 g#2 g#2 g#2 g2 g2 g2 g2 g2 g2 g2 g2"
let songBoss = "a4 a5 g5 a5 e5 a5 d5 a5 c5 a5 b4 a5 g#4 _ e5 _ a4 a5 g5 a5 e5 a5 f5 e5 d5 c5 b4 c5 d5 _ e5 _"
let bassBoss = "a2 - a2 a2 - a2 a2 - f2 - f2 f2 - f2 f2 - g2 - g2 g2 - g2 g2 - e2 - e2 e2 - e2 g#2 -"
let songCamp = "e5 g5 c6 _ g5 e5 f5 a5 c6 _ a5 f5 g5 _ e5 c5 d5 _ g4 b4 d5 _ c5 _ e5 g5 c6 _ b5 g5 c6 _ _ -"
let bassCamp = "c3 _ g3 _ c3 _ g3 _ f3 _ c4 _ f3 _ c4 _ g2 _ d3 _ g2 _ d3 _ c3 _ g3 _ c3 _ g2 _"
let songWin = "c5 e5 g5 c6 _ g5 c6 _ e6 _ _ _ d6 _ c6 _ a5 c6 f6 _ e6 _ d6 _ c6 _ _ _ _ _ - -"
let bassWin = "c3 _ g3 _ c3 _ e3 _ f3 _ g3 _ c3 _ _ _ f2 _ c3 _ g2 _ d3 _ c3 _ _ _ _ _ - -"

// ---------- game state ----------
let mode = 0          // 0 title, 1 playing, 2 fallen, 3 won
let tick = 0
let playTime = 0
let floor = 1         // 0 is the Rest Camp between floors
let nextFloor = 2     // where the camp's ladder leads
let rows = []
let MW = 46
let MH = 45
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
let maxHp = 6
let coins = 0
let keys = 0
let weapon = 1
let owned = [1]
let weaponShow = 0
let hurt = 0
let swing = 0
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
let ehome = []
let eshot = []

// the floor's boss
let bossKind = 0
let bossMax = 1
let bossAwake = false
let bossDead = false
let bossAngry = false
let bossShot = 0
let bossWind = 0
let bossRush = 0
let bossRushX = 0
let bossRushY = 0

// chests, doors, shop, things on the floor
let chx = []
let chy = []
let chWhat = []       // 1 key, 2 gold, 3 weapon
let chOpen = []
let drx = []
let dry = []
let drOpen = []
let ix = []
let iy = []
let ikind = []        // 1 coin, 2 potion
let shx = []
let shy = []
let shItem = []
let ladX = 0
let ladY = 0
let mageX = 0
let mageY = 0

// fireballs, the hero's flames and sparks (positions times 10)
let bx = []
let by = []
let bvx = []
let bvy = []
let bcol = []
let fx = []
let fy = []
let fvx = []
let fvy = []
let flife = []
let fhit = []
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
let fadeIn = 0
let seenSpikes = false
let seenRest = false
let healedAt = -1000
let muted = false
let shopNear = -1
let bestTime = 0
let save0 = []

// 8 directions for ring attacks (speed x10), and a turned set
let ringX = [20, 14, 0, -14, -20, -14, 0, 14]
let ringY = [0, 14, 20, 14, 0, -14, -20, -14]
let ring2X = [18, 8, -8, -18, -18, -8, 8, 18]
let ring2Y = [8, 18, 18, 8, -8, -18, -18, -8]
let moonW = []
let fadeHex = ["00", "11", "22", "33", "44", "55", "66", "77", "88", "99", "aa", "bb", "cc", "dd", "ee", "ff"]

// =====================================================================
//  Setting up a floor
// =====================================================================
fn cell(tx, ty) {
  if tx < 0 or ty < 0 or tx >= MW or ty >= MH {
    return "#"
  }
  return grid[ty * MW + tx]
}

fn isWall(tx, ty) {
  return contains("#bfr", cell(tx, ty))
}

fn solidCell(tx, ty) {
  return contains("#bfruvCDK123456", cell(tx, ty))
}

fn isBoss(k) {
  return k == 5 or k >= 14
}

fn spawnEnemy(kind, tx, ty) {
  let w = 12
  let h = 8
  if isBoss(kind) {
    w = 24
    h = 14
  }
  add tx * 16 + 8 - w / 2 to ex
  add ty * 16 + 14 - h to ey
  add kind to ekind
  add kindLife[kind] to ehp
  add 0 to ehurt
  add 0 to ekx
  add 0 to eky
  add random(0, 60) to etimer
  add 0 to edx
  add 0 to edy
  add false to eleft
  add ty * MW + tx to ehome
  add random(40, 140) to eshot
}

fn spawnNear(kind, tx, ty) {
  if not solidCell(tx, ty) and cell(tx, ty) != "^" {
    spawnEnemy(kind, tx, ty)
    burst(tx * 16 + 8, ty * 16 + 8, 10, "#c77dff", 14)
  }
}

fn clearLists() {
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
  eshot = []
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
  shx = []
  shy = []
  shItem = []
  bx = []
  by = []
  bvx = []
  bvy = []
  bcol = []
  fx = []
  fy = []
  fvx = []
  fvy = []
  flife = []
  fhit = []
  msgs = []
  shown = 0
}

fn buildLevel() {
  clearLists()
  rows = maps[floor]
  MH = length(rows)
  MW = length(rows[0])
  bossKind = floorBoss[floor]
  bossMax = kindLife[bossKind]
  // read the map letters
  for ty from 0 to MH - 1 {
    for tx from 0 to MW - 1 {
      let ch = rows[ty][tx]
      let keep = ch
      if ch == "P" {
        hx = tx * 16 + 3
        hy = ty * 16 + 6
        keep = "."
      } else if contains(kindLetters, ch) and ch != "-" {
        let k = 1
        while k < 14 {
          if kindLetters[k] == ch {
            if k == 5 {
              spawnEnemy(bossKind, tx, ty)
            } else {
              spawnEnemy(k, tx, ty)
            }
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
      } else if ch == "k" or ch == "c" or ch == "w" {
        add tx to chx
        add ty to chy
        if ch == "k" {
          add 1 to chWhat
        } else if ch == "c" {
          add 2 to chWhat
        } else {
          add 3 to chWhat
        }
        add 0 to chOpen
        keep = "C"
      } else if ch == "L" {
        ladX = tx
        ladY = ty
        keep = "."
      } else if ch == "K" {
        mageX = tx
        mageY = ty
      } else if contains("123456", ch) {
        add tx to shx
        add ty to shy
        add number(ch) to shItem
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
            // banner colours change with the floor
            pic = 11 + (tx + ty) % 2 + (floor % 2) * 2
          }
          if ch == "f" {
            pic = 15
          }
          if ch == "r" {
            pic = 16
          }
        } else if contains("bfr", below) or (below == "#" and not isWall(tx, ty + 2)) {
          pic = 20
          if contains("fr", below) {
            pic = 21
          }
        }
      } else {
        pic = 1
        if random(1, 100) > 86 {
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
  checkX = hx
  checkY = hy
  bossAwake = false
  bossDead = floor == 0
  bossAngry = false
  bossShot = 0
  bossWind = 0
  bossRush = 0
  keys = 0
  hurt = 0
  swing = 0
  dash = 0
  dying = 0
  faceX = 0
  faceY = -1
  camX = constrain(hx + 5 - 160, 0, MW * 16 - 320)
  camY = constrain(hy - 86, 0, MH * 16 - 180)
}

// =====================================================================
//  Journeys: new, continue, save, and moving between floors
// =====================================================================
fn saveGame() {
  let data = [floor, nextFloor, coins, maxHp, weapon, playTime]
  for each w in owned {
    add w to data
  }
  save "moonwell", data
}

fn enterFloor(f) {
  floor = f
  buildLevel()
  hp = maxHp
  fadeIn = 30
  mode = 1
  saveGame()
  if floor == 0 {
    say("THE REST CAMP\nA quiet cave between the floors.")
    say("MAGE:\nAh, a knight! Gold for steel. Have a look.")
  } else if floor == 2 {
    say("FLOOR 2: THE DROWNED CRYPT\nCold water drips. Something shuffles in the dark.")
    say("One key opens the crypt's great door.\nThe Warden waits beyond it.")
  } else if floor == 3 {
    say("FLOOR 3: THE EMBER THRONE\nThe walls glow red. He is close now.")
    say("Two keys, two doors. Then the throne.")
  }
}

fn newJourney() {
  coins = 0
  maxHp = 6
  weapon = 1
  owned = [1]
  playTime = 0
  nextFloor = 2
  seenSpikes = false
  seenRest = false
  enterFloor(1)
  say("Long ago, the Moonwell filled these halls\nwith silver light.")
  say("Then the Ember King climbed up from the\ndeep, and one by one the lights went out.")
  say("Since then, a hundred moons have passed\nin darkness...")
  say("You are the last knight of the old order.\nGo down. Find the Ember King.")
  say("ARROWS / WASD  move     X  swing, open, buy\nZ  dash     C  switch weapon     M  music")
}

fn continueJourney() {
  let data = saved("moonwell", [])
  nextFloor = data[1]
  coins = data[2]
  maxHp = data[3]
  weapon = data[4]
  playTime = data[5]
  owned = []
  let n = 6
  while n < length(data) {
    add data[n] to owned
    n += 1
  }
  seenSpikes = true
  seenRest = true
  enterFloor(data[0])
  say("Welcome back, knight.\n" + floorNames[floor] + " awaits.")
}

fn useLadder() {
  tone 523 to 1046 for 300ms
  if floor == 3 {
    mode = 3
    save "moonwell", []
    if bestTime == 0 or playTime < bestTime {
      bestTime = playTime
      save "best", bestTime
    }
    return 0
  }
  if floor == 0 {
    enterFloor(nextFloor)
  } else {
    nextFloor = floor + 1
    enterFloor(0)
  }
}

// =====================================================================
//  Small helpers
// =====================================================================
fn overlap(ax, ay, aw, ah, ox, oy, ow, oh) {
  return ax < ox + ow and ox < ax + aw and ay < oy + oh and oy < ay + ah
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
  if isBoss(k) {
    return 24
  }
  return 12
}

fn enemyH(k) {
  if isBoss(k) {
    return 14
  }
  return 8
}

// a rough length of (dx, dy) without square roots
fn roughLength(dx, dy) {
  let a = abs(dx)
  let b = abs(dy)
  return max(1, max(a, b) + min(a, b) / 2)
}

fn fireball(px, py, vx, vy, color) {
  add px * 10 to bx
  add py * 10 to by
  add vx to bvx
  add vy to bvy
  add color to bcol
}

// shoot at the hero: count is 1, 3 or 5 shots in a fan
fn aimAt(px, py, speed, count, color) {
  let dx = hx + 5 - px
  let dy = hy - 2 - py
  let dist = roughLength(dx, dy)
  let vx = dx * speed / dist
  let vy = dy * speed / dist
  let s = 0 - count / 2
  while s <= count / 2 {
    fireball(px, py, vx - vy * s * 3 / 10, vy + vx * s * 3 / 10, color)
    s += 1
  }
}

fn ring(px, py, turned, color) {
  let d = 0
  while d < 8 {
    if turned {
      fireball(px, py, ring2X[d], ring2Y[d], color)
    } else {
      fireball(px, py, ringX[d], ringY[d], color)
    }
    d += 1
  }
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
  if kbx != 0 or kby != 0 {
    moveHero(kbx, kby)
    kbx -= sign(kbx)
    kby -= sign(kby)
  }
  if hurt > 0 {
    hurt -= 1
  }
  if weaponShow > 0 {
    weaponShow -= 1
  }
  // spikes
  let ftx = (hx + 5) / 16
  let fty = (hy + 4) / 16
  if cell(ftx, fty) == "^" and spikeFrame() == 3 {
    hurtHero(1, hx + 5, hy - 20)
  }
  // the weapon lands partway through the swing
  if swing > 0 {
    swing -= 1
    if swing == wLen[weapon] - 5 and not swingHit {
      swingHit = true
      if weapon == 5 {
        shootFlame()
      } else {
        swordHits()
      }
    }
  }
}

fn swordHits() {
  let r = wReach[weapon]
  let ax = hx - 7 - r
  let ay = hy - 12 - r
  let aw = 24 + r * 2
  let ah = 24 + r * 2
  if faceX > 0 {
    ax = hx + 8
    ay = hy - 16 - r
    aw = 22 + r
    ah = 28 + r * 2
  } else if faceX < 0 {
    ax = hx - 20 - r
    ay = hy - 16 - r
    aw = 22 + r
    ah = 28 + r * 2
  } else if faceY < 0 {
    ax = hx - 9 - r
    ay = hy - 34 - r
    aw = 28 + r * 2
    ah = 24 + r
  } else {
    ax = hx - 9 - r
    ay = hy
    aw = 28 + r * 2
    ah = 22 + r
  }
  let n = 0
  while n < length(ex) {
    let k = ekind[n]
    let tall = kindTall[k]
    let w = enemyW(k)
    let h = enemyH(k)
    if ehurt[n] < 6 and overlap(ax, ay, aw, ah, ex[n] - 2, ey[n] + h - tall, w + 4, tall) {
      hitEnemy(n, wDmg[weapon], faceX * 5, faceY * 5)
    }
    n += 1
  }
  if weapon == 3 {
    shake = max(shake, 5)
    burst(ax + aw / 2, ay + ah / 2, 6, "#c9a27e", 14)
  }
}

fn hitEnemy(n, dmg, pushX, pushY) {
  let k = ekind[n]
  ehp[n] -= dmg
  ehurt[n] = 12
  if not isBoss(k) {
    ekx[n] = pushX
    eky[n] = pushY
  } else {
    bossAwake = true
  }
  freeze = 3
  shake = max(shake, 4)
  tone 180 to 60 for 70ms
  burst(ex[n] + enemyW(k) / 2, ey[n] + enemyH(k) - kindTall[k] / 2, 8, "#ffffff", 22)
}

// the Ember Staff throws a flame that passes through monsters
fn shootFlame() {
  let vx = faceX * 40
  let vy = faceY * 40
  if faceX == 0 and faceY == 0 {
    vy = 40
  }
  let startX = hx + 5 + faceX * 8
  let startY = hy - 4 + faceY * 8
  add startX * 10 to fx
  add startY * 10 to fy
  add vx to fvx
  add vy to fvy
  add 40 to flife
  add "," to fhit
  tone 700 to 300 for 90ms
}

fn updateFlames() {
  let n = 0
  while n < length(fx) {
    fx[n] += fvx[n]
    fy[n] += fvy[n]
    flife[n] -= 1
    let px = fx[n] / 10
    let py = fy[n] / 10
    if tick % 2 == 0 {
      burst(px, py, 1, "#ffb34a", 8)
    }
    // burn every monster it touches, once each
    let e2 = 0
    while e2 < length(ex) {
      let k = ekind[e2]
      let tag = "," + ehome[e2] + ","
      if not contains(fhit[n], tag) and overlap(px - 5, py - 5, 10, 10, ex[e2] - 2, ey[e2] + enemyH(k) - kindTall[k], enemyW(k) + 4, kindTall[k]) {
        fhit[n] = fhit[n] + ehome[e2] + ","
        hitEnemy(e2, wDmg[5], sign(fvx[n]) * 4, sign(fvy[n]) * 4)
      }
      e2 += 1
    }
    if flife[n] <= 0 or isWall(px / 16, py / 16) {
      burst(px, py, 6, "#ff8a3d", 14)
      remove fx[n]
      remove fy[n]
      remove fvx[n]
      remove fvy[n]
      remove flife[n]
      remove fhit[n]
    } else {
      n += 1
    }
  }
}

fn switchWeapon() {
  if mode != 1 or length(owned) < 2 or swing > 0 {
    return 0
  }
  let n = 0
  let pick = owned[0]
  while n < length(owned) {
    if owned[n] == weapon {
      pick = owned[(n + 1) % length(owned)]
    }
    n += 1
  }
  weapon = pick
  weaponShow = 90
  tone 400 to 600 for 60ms
}

fn giveWeapon(wid) {
  if not contains(owned, wid) {
    add wid to owned
  }
  weapon = wid
  weaponShow = 150
}

// X: talk, open, buy, climb, or swing
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
    if length(save0) > 0 {
      continueJourney()
    } else {
      newJourney()
    }
    return 0
  }
  if mode == 2 {
    respawn()
    return 0
  }
  if mode == 3 {
    mode = 0
    save0 = []
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
  // something for sale?
  n = 0
  while n < length(shx) {
    if abs(shx[n] * 16 + 8 - cx) < 14 and abs(shy[n] * 16 + 8 - cy) < 24 {
      buy(shItem[n])
      return 0
    }
    n += 1
  }
  // the mage?
  if floor == 0 and abs(mageX * 16 + 8 - cx) < 24 and abs(mageY * 16 + 8 - cy) < 26 {
    say("MAGE:\nStand by a pedestal and press X to buy.\nPress C to switch between your weapons.")
    return 0
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
        say("The door is locked tight.\nThere must be a key somewhere on this floor.")
      }
      return 0
    }
    n += 1
  }
  // the ladder down?
  if bossDead and cx / 16 == ladX and cy / 16 == ladY {
    useLadder()
    return 0
  }
  // moonwater?
  if cell(cx / 16, cy / 16 - 1) == "u" or cell((cx - 6) / 16, cy / 16 - 1) == "u" or cell((cx + 6) / 16, cy / 16 - 1) == "u" {
    hp = maxHp
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
  // otherwise, swing
  if swing == 0 and dash == 0 {
    swing = wLen[weapon]
    swingHit = false
    if weapon == 3 {
      tone 160 to 70 for 90ms
    } else {
      tone 320 to 140 for 50ms
    }
  }
}

fn buy(item) {
  let cost = shopCost[item]
  if item >= 3 and contains(owned, item - 1) {
    say("You already own the " + shopName[item] + ".\nPress C to switch to it.")
    return 0
  }
  if item == 2 and maxHp >= 10 {
    say("Five hearts is as strong as a knight gets.")
    return 0
  }
  if item == 1 and hp >= maxHp {
    say("Your hearts are already full.")
    return 0
  }
  if coins < cost {
    say("MAGE:\nThat's " + cost + " gold. You have " + coins + ". Come back richer!")
    return 0
  }
  coins -= cost
  tone 880 to 1320 for 160ms
  burst(hx + 5, hy - 8, 14, "#ffd23f", 16)
  if item == 1 {
    hp = min(maxHp, hp + 4)
  } else if item == 2 {
    maxHp += 2
    hp = maxHp
    say("A new heart! You can take more hits now.")
  } else {
    giveWeapon(item - 1)
    say("You bought the " + shopName[item] + ".\n" + wInfo[item - 1])
  }
  saveGame()
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
    say("You found a KEY!\nIt opens one locked door. Press X beside it.")
  } else if chWhat[n] == 3 {
    let wid = floor + 1
    if contains(owned, wid) {
      coins += 25
      say("A " + wName[wid] + "... you already have one.\nYou sell the spare for 25 gold.")
    } else {
      giveWeapon(wid)
      tone 523 to 1568 for 400ms
      say("You found the " + upper(wName[wid]) + "!\n" + wInfo[wid] + "  (C switches weapons)")
    }
  } else {
    coins += 10
    add px to ix
    add py + 14 to iy
    add 2 to ikind
    say("Ten gold coins, and a healing potion!")
  }
}

fn respawn() {
  hx = checkX
  hy = checkY
  hp = maxHp
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
  bcol = []
  // the boss goes back to the middle of its room
  let n = 0
  while n < length(ex) {
    if isBoss(ekind[n]) {
      ehp[n] = bossMax
      ex[n] = (ehome[n] % MW) * 16 - 4
      ey[n] = (ehome[n] / MW) * 16
      bossAwake = false
      bossAngry = false
      bossRush = 0
      bossWind = 0
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

fn countKind(k) {
  let c = 0
  for each kk in ekind {
    if kk == k {
      c += 1
    }
  }
  return c
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
    let go = tick % kindPace[k] == 0
    if ehurt[n] > 0 {
      ehurt[n] -= 1
    }
    if ekx[n] != 0 or eky[n] != 0 {
      // knocked back
      moveEnemy(n, ekx[n], eky[n])
      ekx[n] -= sign(ekx[n])
      eky[n] -= sign(eky[n])
    } else if isBoss(k) {
      updateBoss(n, dx, dy, far)
    } else if (k == 10 or k == 11) and far < 150 and dying == 0 {
      // spellcasters keep their distance and shoot
      if go {
        if far < 70 {
          moveEnemy(n, 0 - sign(dx), 0 - sign(dy))
        } else if far > 110 {
          moveEnemy(n, sign(dx), sign(dy))
        }
      }
      eleft[n] = dx < 0
      eshot[n] -= 1
      if eshot[n] <= 0 {
        eshot[n] = random(110, 170)
        if k == 10 {
          aimAt(ex[n] + 6, ey[n] - 8, 18, 1, "#ff8a3d")
        } else {
          aimAt(ex[n] + 6, ey[n] - 8, 15, 3, "#c77dff")
          if countKind(12) < 6 {
            spawnNear(12, (ex[n] + 6) / 16 + random(-1, 1), (ey[n] + 4) / 16 + random(-1, 1))
          }
        }
        tone 520 to 260 for 90ms
      }
    } else if far < 120 and dying == 0 {
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
    // touching the hero hurts
    if overlap(hx, hy, 10, 8, ex[n] - 2, ey[n] - 2, w + 4, h + 4) {
      hurtHero(kindHit[k], ex[n] + w / 2, ey[n] + h / 2)
    }
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
  if k != 12 or roll <= 25 {
    if roll <= 50 {
      add px to ix
      add py to iy
      add 1 to ikind
    } else if roll <= 62 {
      add px to ix
      add py to iy
      add 2 to ikind
    }
  }
  if isBoss(k) {
    bossDead = true
    shake = 40
    freeze = 20
    bx = []
    by = []
    bvx = []
    bvy = []
    bcol = []
    burst(px, py - 10, 60, "#ffd23f", 45)
    burst(px, py - 10, 40, "#e8f4ff", 35)
    tone 80 to 30 for 1200ms
    // a pile of gold
    repeat 8 {
      add px + random(-20, 20) to ix
      add py + random(-14, 14) to iy
      add 1 to ikind
    }
    if k == 14 {
      say("GRUKK THE GATEKEEPER:\nGrukk... tired. Grukk... nap now.")
      say("A ladder leads down to the next floor.\nStand on it and press X.")
    } else if k == 15 {
      say("THE ROTTING WARDEN:\nThe dead... will rest... at last.")
      say("The ladder leads down. Heat rises from\nbelow. Only the Ember Throne remains.")
    } else {
      say("The Ember King crumbles into cinders...")
      say("Silver light floods the halls once more.\nThe ladder leads home, to the surface.")
    }
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
  remove eshot[n]
}

fn wakeBoss() {
  bossAwake = true
  shake = 20
  tone 90 to 40 for 900ms
  if bossKind == 14 {
    say("GRUKK THE GATEKEEPER:\nNobody passes Grukk! Grukk SMASH!")
  } else if bossKind == 15 {
    say("THE ROTTING WARDEN:\nThe dead do not sleep here, knight.\nNeither will you.")
  } else {
    say("THE EMBER KING:\nAnother little knight, come to be ash?")
    say("THE EMBER KING:\nThe Moonwell is MINE. Burn!")
  }
}

fn updateBoss(n, dx, dy, far) {
  if not bossAwake {
    if far < 110 and dying == 0 {
      wakeBoss()
    }
    return 0
  }
  let k = ekind[n]
  let px = ex[n] + 12
  let py = ey[n] - 8
  eleft[n] = dx < 0
  if ehp[n] * 2 <= bossMax and not bossAngry {
    bossAngry = true
    shake = 16
    if k == 14 {
      say("GRUKK THE GATEKEEPER:\nGrukk ANGRY now!")
    } else if k == 15 {
      say("THE ROTTING WARDEN:\nRise, all of you. RISE!")
      spawnNear(12, ex[n] / 16 - 3, ey[n] / 16)
      spawnNear(12, ex[n] / 16 + 4, ey[n] / 16)
      spawnNear(6, ex[n] / 16, ey[n] / 16 + 3)
    } else {
      say("THE EMBER KING:\nRise, my servants! Burn this knight!")
      spawnNear(13, ex[n] / 16 - 4, ey[n] / 16)
      spawnNear(13, ex[n] / 16 + 5, ey[n] / 16)
      spawnNear(4, ex[n] / 16, ey[n] / 16 + 4)
    }
  }
  // Grukk: winds up, then charges
  if k == 14 {
    if bossRush > 0 {
      bossRush -= 1
      moveEnemy(n, bossRushX, bossRushY)
      moveEnemy(n, bossRushX, bossRushY)
      if tick % 3 == 0 {
        burst(px, py + 16, 2, "#8a7a6a", 10)
      }
      if bossRush == 0 {
        shake = 10
        tone 90 to 40 for 200ms
        if bossAngry {
          ring(px, py + 6, tick % 2 == 0, "#c9a27e")
        }
      }
      return 0
    }
    if bossWind > 0 {
      bossWind -= 1
      if bossWind == 0 {
        bossRush = 28
        bossRushX = sign(dx) * 2
        bossRushY = sign(dy) * 2
        if abs(dx) < 10 {
          bossRushX = 0
        }
        if abs(dy) < 10 {
          bossRushY = 0
        }
        tone 140 to 300 for 150ms
      }
      return 0
    }
    if tick % 2 == 0 {
      moveEnemy(n, sign(dx), sign(dy))
    }
    bossShot += 1
    let gap = 150
    if bossAngry {
      gap = 100
    }
    if bossShot >= gap {
      bossShot = 0
      bossWind = 30
      ehurt[n] = 0
    }
    return 0
  }
  // the Warden: slow, spits and calls the dead
  if k == 15 {
    if tick % 3 == 0 {
      moveEnemy(n, sign(dx), sign(dy))
    }
    bossShot += 1
    let gap = 110
    if bossAngry {
      gap = 75
    }
    if bossShot >= gap {
      bossShot = 0
      if bossAngry {
        aimAt(px, py, 16, 5, "#9be36b")
      } else {
        aimAt(px, py, 16, 3, "#9be36b")
      }
      tone 300 to 120 for 140ms
      if countKind(12) < 4 and random(1, 3) == 1 {
        spawnNear(12, ex[n] / 16 + random(-3, 3), ey[n] / 16 + 2)
      }
    }
    return 0
  }
  // the Ember King: rings of fire, and aimed bursts when angry
  if tick % 2 == 0 {
    moveEnemy(n, sign(dx), sign(dy))
  }
  bossShot += 1
  let gap = 120
  if bossAngry {
    gap = 70
  }
  if bossShot >= gap {
    bossShot = 0
    ring(px, py, bossAngry and tick % 2 == 0, "#ff5a1f")
    if bossAngry {
      aimAt(px, py, 22, 3, "#ffd23f")
    }
    tone 500 to 180 for 120ms
    burst(px, py, 10, "#ff8a3d", 20)
  }
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
      burst(px, py, 5, bcol[n], 14)
    } else if overlap(hx, hy - 12, 10, 20, px - 3, py - 3, 6, 6) {
      hurtHero(1, px, py)
      gone = true
    }
    if gone {
      remove bx[n]
      remove by[n]
      remove bvx[n]
      remove bvy[n]
      remove bcol[n]
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
        coins += 2
        tone 988 to 1480 for 70ms
        burst(ix[n], iy[n], 5, "#ffd23f", 12)
        took = true
      } else if hp < maxHp {
        hp = min(maxHp, hp + 2)
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
  if floor == 1 and not seenSpikes and tx >= 21 and ty >= 33 {
    seenSpikes = true
    say("Spikes rise and fall in these halls.\nWatch their rhythm... or dash across.")
  }
  if not seenRest and cell(tx, ty - 1) == "u" {
    seenRest = true
    say("A fountain of moonwater. Press X beside it\nto heal and set your return point.")
  }
}

fn updateCamera() {
  let tx = constrain(hx + 5 - 160, 0, max(0, MW * 16 - 320))
  let ty = constrain(hy - 86, 0, max(0, MH * 16 - 180))
  if MW * 16 < 320 {
    tx = (MW * 16 - 320) / 2
  }
  if MH * 16 < 180 {
    ty = (MH * 16 - 180) / 2
  }
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
  updateFlames()
  updateItems()
  checkRooms()
}

fn pickMusic() {
  if muted {
    music off
  } else if mode == 0 {
    music songTitle, bassTitle tempo 110
  } else if mode == 3 {
    music songWin, bassWin tempo 120
  } else if bossAwake and not bossDead {
    music songBoss, bassBoss tempo 180
  } else if floor == 0 {
    music songCamp, bassCamp tempo 120
  } else if floor == 1 {
    music songHalls, bassHalls tempo 140
  } else if floor == 2 {
    music songCrypt, bassCrypt tempo 100
  } else {
    music songThrone, bassThrone tempo 160
  }
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
  } else if pic == 16 {
    draw lavaFall at x, y frame tick / 8
  } else if pic == 20 {
    draw wallTop at x, y
  } else if pic == 21 {
    draw fountainTop at x, y
  }
  // things on the floor
  let ch = grid[i]
  if ch == "^" {
    draw spikes at x, y frame spikeFrame()
  } else if ch == "u" {
    draw basin at x, y frame tick / 8
  } else if ch == "v" {
    draw lavaPool at x, y frame tick / 8
  } else if ch == "x" {
    draw skull at x, y
  }
  if bossDead and tx == ladX and ty == ladY {
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
  let tall = kindTall[k]
  let w = enemyW(k)
  let h = enemyH(k)
  let sw = 16
  if isBoss(k) {
    sw = 32
  }
  let x = ex[n] + w / 2 - sw / 2
  let y = ey[n] + h - tall
  let f = (tick + n * 7) / 8
  let run = ekx[n] == 0 and (not isBoss(k) or bossAwake)
  let hit = ehurt[n] > 6
  let left = eleft[n]
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
  } else if k == 6 {
    draw zombie at x, y frame f flip left flash hit
  } else if k == 7 {
    draw iceZombie at x, y frame f flip left flash hit
  } else if k == 8 {
    draw slime at x, y frame f flip left flash hit
  } else if k == 9 {
    if run {
      draw maskRun at x, y frame f flip left flash hit
    } else {
      draw maskIdle at x, y frame f flip left flash hit
    }
  } else if k == 10 {
    if run {
      draw shamanRun at x, y frame f flip left flash hit
    } else {
      draw shamanIdle at x, y frame f flip left flash hit
    }
  } else if k == 11 {
    draw necro at x, y frame f flip left flash hit
  } else if k == 12 {
    if run {
      draw tinyRun at x, y frame f flip left flash hit
    } else {
      draw tinyIdle at x, y frame f flip left flash hit
    }
  } else if k == 13 {
    if run {
      draw impRun at x, y frame f flip left flash hit
    } else {
      draw impIdle at x, y frame f flip left flash hit
    }
  } else if k == 14 {
    // Grukk glows white while winding up a charge
    let windup = bossWind > 0 and tick % 6 < 3
    if run {
      draw ogreRun at x, y frame f flip left flash hit or windup
    } else {
      draw ogreIdle at x, y frame f flip left flash hit
    }
  } else if k == 15 {
    if run {
      draw wardenRun at x, y frame f flip left flash hit
    } else {
      draw wardenIdle at x, y frame f flip left flash hit
    }
  } else {
    if run {
      draw kingRun at x, y frame f flip left flash hit
    } else {
      draw kingIdle at x, y frame f flip left flash hit
    }
  }
}

// draws a weapon picture centred on (cx, cy), turned by ang degrees
fn drawWeapon(wid, cx, cy, ang) {
  let x = cx - wW[wid] / 2
  let y = cy - wH[wid] / 2
  if wid == 1 {
    draw rusty at x, y angle ang
  } else if wid == 2 {
    draw knightSword at x, y angle ang
  } else if wid == 3 {
    draw hammer at x, y angle ang
  } else if wid == 4 {
    draw goldSword at x, y angle ang
  } else {
    draw staff at x, y angle ang
  }
}

fn drawHero() {
  let x = hx - 3
  let y = hy - 14
  let f = tick / 7
  let blink = hurt > 0 and tick % 6 < 3
  box hx, hy + 6, 10, 3 color "#00000055"
  if dash > 0 {
    draw knightRun at x - faceX * 8, y - faceY * 8 frame f flip lookLeft alpha 35
    draw knightRun at x - faceX * 16, y - faceY * 16 frame f flip lookLeft alpha 15
  }
  if faceY < 0 {
    drawHeld()
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
    drawHeld()
  }
}

fn drawHeld() {
  if dying > 0 {
    return 0
  }
  let cx = hx + 5
  let cy = hy - 4
  let half = wH[weapon] / 2
  if swing == 0 {
    // resting at the side
    if lookLeft {
      drawWeapon(weapon, cx - 8, cy - half + 7, -20)
    } else {
      drawWeapon(weapon, cx + 8, cy - half + 7, 20)
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
  let total = wLen[weapon]
  let sweep = (total - swing) * 140 / total - 70
  if weapon == 5 {
    sweep = 0
  }
  let reach = half + 2
  let ox = faceX * reach
  let oy = faceY * reach
  if faceX == 0 and faceY == 0 {
    oy = reach
  }
  drawWeapon(weapon, cx + ox, cy + oy, base + sweep)
  if swing > total - 7 and weapon != 5 {
    box cx + ox * 3 / 2 - 2, cy + oy * 3 / 2 - 2, 4, 4 color "#ffffffcc"
  }
}

fn drawShop() {
  // the mage
  box mageX * 16 + 2, mageY * 16 + 12, 12, 3 color "#00000055"
  draw mage at mageX * 16, mageY * 16 - 6 frame tick / 9 flipped
  let n = 0
  let near = -1
  while n < length(shx) {
    let x = shx[n] * 16
    let y = shy[n] * 16
    let item = shItem[n]
    let bob = (tick / 12 + n) % 2
    // a stone pedestal
    box x + 1, y + 6, 14, 10 color "#6b5b55"
    box x + 1, y + 6, 14, 2 color "#aa8d7a"
    box x + 3, y + 16, 10, 2 color "#00000055"
    let sold = item >= 3 and contains(owned, item - 1)
    if item == 1 {
      draw flask at x, y - 8 - bob
    } else if item == 2 {
      draw heart at x, y - 8 - bob
    } else {
      drawWeapon(item - 1, x + 8, y - 4 - bob, 0)
    }
    if sold {
      write "OWNED" at x + 8, y + 20 size 1 centered color "#7ee787" shadow
    } else {
      write "" + shopCost[item] at x + 8, y + 20 centered color "#ffd23f" shadow
    }
    if abs(x + 8 - (hx + 5)) < 14 and abs(y + 8 - (hy + 4)) < 24 {
      near = item
    }
    n += 1
  }
  shopNear = near
}

fn drawShopInfo() {
  if shopNear < 0 or length(msgs) > 0 {
    return 0
  }
  box 30, 22, 260, 24 color "#05040acc"
  box 30, 22, 260, 1 color "#6b5b55"
  let info = "Restores 2 hearts."
  if shopNear == 2 {
    info = "One more heart, for good."
  } else if shopNear >= 3 {
    info = wInfo[shopNear - 1]
  }
  write shopName[shopNear] + " - " + shopCost[shopNear] + " gold   (X to buy)" at 160, 26 centered color "#ffd23f"
  write info at 160, 36 centered color "#c9c3d6"
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
  let n = 0
  while n < length(drx) {
    if drOpen[n] {
      draw doorOpen at drx[n] * 16, dry[n] * 16 - 16
    } else {
      draw doorShut at drx[n] * 16, dry[n] * 16 - 16
    }
    n += 1
  }
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
  // fireballs and flames
  n = 0
  while n < length(bx) {
    let px = bx[n] / 10
    let py = by[n] / 10
    box px - 4, py - 4, 8, 8 color bcol[n] + "55"
    box px - 3, py - 3, 6, 6 color bcol[n]
    box px - 1, py - 2, 3, 3 color "#fff4d0"
    n += 1
  }
  n = 0
  while n < length(fx) {
    let px = fx[n] / 10
    let py = fy[n] / 10
    box px - 5, py - 5, 10, 10 color "#ff8a3d44"
    box px - 3, py - 3, 6, 6 color "#ffb34a"
    box px - 1, py - 1, 3, 3 color "#ffffff"
    n += 1
  }
  n = 0
  while n < length(qx) {
    let size = 2
    if qlife[n] < 8 {
      size = 1
    }
    box qx[n] / 10, qy[n] / 10, size, size color qcol[n]
    n += 1
  }
  if floor == 0 {
    drawShop()
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

fn bossTitle() {
  if bossKind == 14 {
    return "GRUKK THE GATEKEEPER"
  }
  if bossKind == 15 {
    return "THE ROTTING WARDEN"
  }
  return "THE EMBER KING"
}

fn drawHud() {
  let k = 0
  while k < maxHp / 2 {
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
  draw coin at 266, 7 frame tick / 6
  write "x" + coins at 277, 7 shadow
  if keys > 0 {
    drawKey(238, 4)
    write "" + keys at 252, 7 color "#ffd23f" shadow
  }
  // the weapon in hand
  box 4, 150, 26, 26 color "#05040a99"
  box 4, 150, 26, 1 color "#6b5b55"
  drawWeapon(weapon, 17, 163, 45)
  let bossBar = bossAwake and not bossDead and length(msgs) == 0
  if weaponShow > 0 and not bossBar {
    write wName[weapon] at 34, 160 color "#e8f4ff" shadow
    if length(owned) > 1 {
      write "C: switch" at 34, 169 color "#9a8fb0"
    }
  }
  if floor > 0 {
    write "FLOOR " + floor at 274, 170 color "#5d5470"
  } else {
    drawShopInfo()
  }
  // the boss's health bar
  if bossBar {
    let n = 0
    while n < length(ex) {
      if isBoss(ekind[n]) {
        write bossTitle() at 160, 158 centered color "#ffb38a" shadow
        box 79, 167, 162, 7 color "#000000aa"
        box 80, 168, 160, 5 color "#3a1518"
        box 80, 168, ehp[n] * 160 / bossMax, 5 color "#ff5a1f"
        box 80, 168, ehp[n] * 160 / bossMax, 1 color "#ffb38a"
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
  box 8, 124, 304, 50 color "#05040acc"
  box 8, 124, 304, 1 color "#d3bfa9"
  box 8, 173, 304, 1 color "#d3bfa9"
  box 8, 124, 1, 50 color "#d3bfa9"
  box 311, 124, 1, 50 color "#d3bfa9"
  write part(words, 0, shown) at 18, 132 shadow
  if shown >= length(words) and tick / 20 % 2 == 0 {
    box 298, 164, 6, 2 color "#ffd23f"
    box 299, 166, 4, 1 color "#ffd23f"
    box 300, 167, 2, 1 color "#ffd23f"
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

fn clock(frames) {
  let secs = frames / 60
  let mins = secs / 60
  secs = secs % 60
  if secs < 10 {
    return mins + ":0" + secs
  }
  return mins + ":" + secs
}

fn titleScreen() {
  // the first floor slowly drifts past behind the title
  camX = 120 + (tick / 3) % 400
  camY = 260
  drawWorld()
  box 0, 0, 320, 180 color "#0b0814bb"
  drawMoon(160, 36)
  write "MOONWELL" at 160, 64 size 4 centered color "#e8f4ff" shadow
  write "a dungeon crawler written in Volt" at 160, 102 centered color "#9a8fb0"
  if length(save0) > 0 {
    if tick / 30 % 2 == 0 {
      write "X  CONTINUE - " + floorNames[save0[0]] at 160, 124 centered color "#ffd23f" shadow
    }
    write "N  start a new journey" at 160, 138 centered color "#c9c3d6" shadow
  } else if tick / 30 % 2 == 0 {
    write "PRESS X TO BEGIN" at 160, 128 centered color "#ffd23f" shadow
  }
  if bestTime > 0 {
    write "best time " + clock(bestTime) at 160, 154 centered color "#7ee787"
  }
  write "art: 0x72 (CC0)   M: music" at 160, 168 centered color "#5d5470"
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
    write "Gold: " + coins + "     Time: " + clock(playTime) at 160, 98 centered color "#ffd23f" shadow
    if playTime == bestTime {
      write "A new best time!" at 160, 110 centered color "#7ee787" shadow
    }
    write "Thanks for playing!   Press X" at 160, 128 centered shadow
  }
}

// =====================================================================
//  Start up, keys and the main loop
// =====================================================================
// the moon on the title screen: a circle, one row at a time
for r from -18 to 18 {
  let w = 0
  while (w + 1) * (w + 1) + r * r <= 324 {
    w += 1
  }
  add w to moonW
}
save0 = saved("moonwell", [])
bestTime = saved("best", 0)
floor = 1
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
when key "c" pressed {
  switchWeapon()
}
when key "q" pressed {
  switchWeapon()
}
when key "m" pressed {
  muted = not muted
}
when key "n" pressed {
  if mode == 0 and length(msgs) == 0 {
    newJourney()
  }
}

every frame {
  tick += 1
  pickMusic()
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
    if fadeIn > 0 {
      box 0, 0, 320, 180 color "#000000" + fadeHex[fadeIn / 2]
      fadeIn -= 1
    }
  }
  if length(msgs) > 0 {
    drawTalk()
  }
}
