// =====================================================================
//  99 NIGHTS - a first-person 3D survival game, written in Volt
//
//  You wake in a dark forest beside a dying campfire. Keep it burning.
//  By day: chop trees for logs, find fuel, rescue the lost children.
//  By night: the forest hunts. Stay near the fire, swing your axe.
//
//  W A S D walk   SHIFT sprint   MOUSE look (click first)   F swing the axe / chop
//  E use (feed the fire, rescue a child)   U upgrade the fire   M music   ENTER start
//
//  Units: 1 = 1 cm in the 3D world.
// =====================================================================
#html
title "99 Nights"
canvas 320, 180
let crispOn = crisp(2)
world3d "#c4d2c0" fog 5600 ambient 96
look3d 1, "#c9d8c5"
fx3d 35, 30, 4
model3d bonfireM = "models/bonfire.glb"
model3d fireM = "models/bonfire_fire.glb"
model3d logM = "models/woodlog.glb"
model3d tentM = "models/tent.glb"
model3d gasM = "models/gascan.glb"
model3d packM = "models/backpack.glb"
model3d kitM = "models/firstaidkit.glb"
model3d canM = "models/can_closed.glb"
image icI = "icons.png"
sprite icAxe = icI at 0, 0 size 24, 24
sprite icLog = icI at 24, 0 size 24, 24
sprite icGas = icI at 48, 0 size 24, 24
sprite icKit = icI at 72, 0 size 24, 24
sprite icCan = icI at 96, 0 size 24, 24
sprite icSack = icI at 120, 0 size 24, 24
sprite icGun = icI at 144, 0 size 24, 24
image tlI = "titles_hq.png"
sprite tl0 = tlI at 0, 0 size 300, 40
sprite tl1 = tlI at 0, 40 size 300, 40
sprite tl2 = tlI at 0, 80 size 300, 40
sprite tl3 = tlI at 0, 120 size 300, 40
sprite tl4 = tlI at 0, 160 size 300, 40
sprite tl5 = tlI at 0, 200 size 300, 40
sprite tl6 = tlI at 0, 240 size 300, 40
sprite tlTools = tlI at 0, 280 size 300, 40
sprite tlShop = tlI at 0, 320 size 300, 40
model3d wolfM = "models/wolf.glb"
model3d deerM = "models/deer.glb"
model3d bearM = "models/bear.glb"
model3d gunM = "models/shotgun_1.glb"
model3d torchM = "models/woodentorch_fire.glb"
model3d stalkM = "models/hunter.glb"
model3d cultM = "models/raider2.glb"
model3d kidAM = "models/coworker_gold.glb"
model3d kidBM = "models/coworker_cyan.glb"
model3d kidCM = "models/coworker_red.glb"
model3d kidDM = "models/ninja.glb"
model3d pineAM = "models/forest/pine1.glb"
model3d pineBM = "models/forest/pine2.glb"
model3d pineCM = "models/forest/pine3.glb"
model3d deadAM = "models/forest/deadtree1.glb"
model3d deadBM = "models/forest/deadtree2.glb"
model3d comAM = "models/forest/commontree1.glb"
model3d twistAM = "models/forest/twistedtree1.glb"
model3d rockAM = "models/forest/rockmedium1.glb"
model3d rockBM = "models/forest/rockmedium2.glb"
model3d bushAM = "models/forest/bushcommon.glb"
model3d fernAM = "models/forest/fern1.glb"
model3d grassAM = "models/forest/grasswispytall.glb"
model3d mushAM = "models/forest/mushroomcommon.glb"

let WS = 9000                // the forest is 90 m by 90 m
let CX = 4500                // the camp is in the middle
let CZ = 4500
let LX = 2000                // the lobby plaza
let LZ = 2400
let FZ = 1650                // the CLASSES building front

let state = 0                // 0 title, 1 playing, 2 dead, 3 intro
let t = 0
let best = saved("n99_best", 0)
let introSeen = saved("n99_intro", 0)
let bank = saved("n99_bank", 10000)
let musicOn = 1

// the player (centimetres)
let px = 4500
let pz = 4800
let yaw = 0
let pitch = 0
let hp = 5
let hpMax = 5
let hurtT = 0
let swingT = 0
let stam = 600
let tired = 0
let bob = 0
let stepAcc = 0
let logs = 0
let cans = 0
let kits = 0
let foodN = 0
let hunger = 100
let hungT = 0
let slotSel = 0
let cls = saved("n99_cls", 0)
let cFig = []
let lobbyIds = []
let npcA = 0
let npcB = 0
let npcT = 0
let cItem = []
let clsCost = [0, 25, 40, 40, 70, 70, 500]
let hasGun = 0
let shells = 0
let gunT = 0
let bOk = []
let bSeen = 0 - 1
let spdBonus = 0
let packMax = 12
let axeLvl = 0
let kidsSaved = 0
let kidsFollow = 0
let pAv = 0
let avYaw = 0
let avAnim = 0 - 1
let camD = 340
let noteText = ""
let noteT = 0
let ringIds = []
let ringR = 0

// time
let clock = 0
let DAYF = 7200
let NIGHTF = 5400
let night = 1                // the night you are on (or about to be)
let inNight = 0
let nightsDone = 0
let banner = ""
let bannerT = 0
let msg = ""
let msgT = 0

// the campfire
let fuel = 3600
let fireLvl = 1
let fL1 = 0
let fL2 = 0
let fL3 = 0
let fireId = 0
let fuelTick = 0

// trees
let tX = []
let tZ = []
let tHp = []
let tA = []
let tB = []
let tC = []
let tD = []

// monsters (a pool: slots 0-7 stalkers, 8-13 cultists)
let mX = []
let mZ = []
let mHp = []
let mKind = []
let mId = []
let mYaw = []
let mAtk = []
let mOn = []
let mAnim = []
let spawnT = 0

// loot
let iX = []
let iZ = []
let iGot = []
let iId = []
let iKind = []

// lost children
let kX = []
let kZ = []
let kState = []
let kId = []
let kModel = []

// intro cutscene
let cutT = 0
let cutIdx = 0

fn dst(ax, ay, bx, by) {
  let dx = abs(ax - bx)
  let dy = abs(ay - by)
  return max(dx, dy) + min(dx, dy) * 4 / 10
}

fn note(text1) {
  noteText = text1
  noteT = 300
}

fn say(text1, frames) {
  msg = text1
  msgT = frames
}

fn hex2(n) {
  let v = constrain(n, 0, 255)
  let digits = "0123456789abcdef"
  return part(digits, v / 16, 1) + part(digits, v % 16, 1)
}

// ---------- the forest ----------
fn treeAt(x, z) {
  // tall red-brown block trunk with dark slab canopy up high, like the real forest
  let h = random(750, 1150)
  let w = random(70, 100)
  let tr = block3d(x, h / 2, z, w, h, w, "#7a3f2a")
  let cw = random(520, 720)
  let c1 = block3d(x, h + 20, z, cw, 70, cw, "#23602e")
  let c2 = block3d(x, h + 85, z, cw * 7 / 10, 70, cw * 7 / 10, "#286b33")
  let c3 = block3d(x, h + 150, z, cw * 4 / 10, 70, cw * 4 / 10, "#2e773a")
  add tr to tA
  add c1 to tB
  add c2 to tC
  add c3 to tD
}

fn buildWorld() {
  clear3d
  torch3d 0, 2200
  let gnd = block3d(WS / 2, -5, WS / 2, WS + 2400, 10, WS + 2400, "#2fd035")
  glow3d gnd, "#0d3f12"
  tX = []
  tZ = []
  tHp = []
  tA = []
  tB = []
  tC = []
  tD = []
  let tries = 0
  while length(tX) < 190 and tries < 2000 {
    tries += 1
    let x = random(80, WS - 80)
    let z = random(80, WS - 80)
    if dst(x, z, CX, CZ) > 650 and dst(x, z, LX, LZ) > 1500 {
      let ok = 1
      let i = 0
      while i < length(tX) {
        if dst(x, z, tX[i], tZ[i]) < 160 {
          ok = 0
        }
        i += 1
      }
      if ok == 1 {
        add x to tX
        add z to tZ
        add 3 to tHp
        treeAt(x, z)
      }
    }
  }
  // dirt and flower flecks on the grass
  for fl from 1 to 260 {
    let fx2 = random(100, WS - 100)
    let fz2 = random(100, WS - 100)
    let fc = "#e8a033"
    let fr = random(1, 4)
    if fr == 2 {
      fc = "#ffe24d"
    } else if fr == 3 {
      fc = "#b8862e"
    } else if fr == 4 {
      fc = "#ff7a2a"
    }
    let fb = block3d(fx2, 1, fz2, random(14, 40), 2, random(14, 40), fc)
  }
  // a wall of dark pines round the edge
  for e from 0 to 23 {
    let ex = 100 + e * 375
    let r1 = block3d(ex, 200, 40, 160, 400, 160, "#17361f")
    let r2 = block3d(ex, 200, WS - 40, 160, 400, 160, "#17361f")
    let r3 = block3d(40, 200, ex, 160, 400, 160, "#17361f")
    let r4 = block3d(WS - 40, 200, ex, 160, 400, 160, "#17361f")
  }
  // grey block rocks and hedge bushes
  for r from 1 to 30 {
    let rx = random(100, WS - 100)
    let rz = random(100, WS - 100)
    if dst(rx, rz, CX, CZ) > 500 {
      let rw = random(70, 170)
      let rk = block3d(rx, rw / 3, rz, rw, rw * 2 / 3, rw * 9 / 10, "#6d7078")
    }
  }
  for b from 1 to 55 {
    let bx = random(100, WS - 100)
    let bz = random(100, WS - 100)
    if dst(bx, bz, CX, CZ) > 450 {
      let bw = random(110, 190)
      let b1 = block3d(bx, 25, bz, bw, 50, bw, "#2b8a34")
      let b2 = block3d(bx, 65, bz, bw * 6 / 10, 30, bw * 6 / 10, "#34a03e")
    }
  }
  buildCamp()
  buildLoot()
  buildKids()
  buildMonsters()
  pAv = put3d(kidBM, px, 0, pz, 0, 40)
  avAnim = 0 - 1
}

fn lb(x, y, z, w, h, d, col) {
  let bid = block3d(x, y, z, w, h, d, col)
  show3d bid, 0
  add bid to lobbyIds
}

fn buildLobby() {
  // floor and paving
  lb(LX, 0 - 2, LZ, 2600, 6, 2000, "#8a6840")
  lb(LX, 2, LZ + 100, 260, 2, 1500, "#a47c4c")
  lb(LX, 2, LZ - 300, 1500, 2, 120, "#a47c4c")
  // the CLASSES building
  lb(LX, 230, FZ - 130, 900, 460, 260, "#6b4a30")
  lb(LX, 470, FZ - 130, 980, 30, 320, "#2a1c14")
  lb(LX, 130, FZ + 6, 230, 270, 14, "#3a2616")
  lb(LX - 50, 125, FZ + 14, 90, 250, 8, "#8a5a34")
  lb(LX + 50, 125, FZ + 14, 90, 250, 8, "#8a5a34")
  lb(LX, 330, FZ + 8, 360, 70, 14, "#2a1c14")
  lb(LX, 330, FZ + 16, 330, 50, 8, "#e8d6f0")
  for wi from 0 to 1 {
    let sx = 1 - wi * 2
    lb(LX + sx * 330, 260, FZ + 10, 120, 140, 10, "#2a1c14")
    lb(LX + sx * 330, 260, FZ + 16, 100, 120, 8, "#9ad8ff")
    lb(LX + sx * 330, 260, FZ + 22, 8, 120, 4, "#2a1c14")
    lb(LX + sx * 330, 190, FZ + 40, 140, 14, 70, "#2f8a4a")
  }
  for aw from 0 to 7 {
    let ac = "#2f8a4a"
    if aw % 2 == 1 {
      ac = "#f2efe4"
    }
    lb(LX - 154 + aw * 44, 290, FZ + 40, 44, 12, 80, ac)
  }
  // side buildings
  lb(LX - 740, 160, FZ - 20, 420, 320, 200, "#7a3a3a")
  lb(LX - 740, 330, FZ - 20, 450, 24, 230, "#2a1c14")
  lb(LX - 740, 160, FZ + 84, 160, 150, 8, "#ffd27a")
  lb(LX - 740, 140, FZ + 100, 220, 14, 60, "#e86aa8")
  lb(LX + 740, 160, FZ - 20, 420, 320, 200, "#3a5a7a")
  lb(LX + 740, 330, FZ - 20, 450, 24, 230, "#2a1c14")
  lb(LX + 740, 160, FZ + 84, 160, 150, 8, "#9ad8ff")
  lb(LX + 740, 140, FZ + 100, 220, 14, 60, "#e8c84a")
  // string lights
  for sl from 0 to 15 {
    let lc = "#ff7ad8"
    if sl % 3 == 1 {
      lc = "#ffd23f"
    } else if sl % 3 == 2 {
      lc = "#7ad8ff"
    }
    lb(LX - 750 + sl * 100, 380 - (sl % 2) * 14, FZ + 100, 12, 12, 12, lc)
  }
  // the Daily Class Shop counter
  lb(LX, 45, FZ + 300, 260, 90, 60, "#5a3a20")
  lb(LX, 94, FZ + 300, 280, 8, 70, "#8a5a34")
  lb(LX, 170, FZ + 300, 220, 40, 8, "#3a7a4a")
  lb(LX - 120, 85, FZ + 300, 10, 170, 10, "#3a2616")
  lb(LX + 120, 85, FZ + 300, 10, 170, 10, "#3a2616")
  // leaderboards
  for bd from 0 to 2 {
    let bxx = LX + 1000
    let bzz = LZ - 300 + bd * 220
    lb(bxx, 130, bzz, 12, 130, 190, "#10141c")
    for row from 0 to 6 {
      let rc = "#e8e2c8"
      if row == 0 {
        rc = "#ffd23f"
      }
      lb(bxx - 8, 175 - row * 14, bzz - 40 + (row % 3) * 10, 4, 6, 100 - (row % 4) * 15, rc)
    }
  }
  // striped barriers and cones
  for br from 0 to 2 {
    let bx2 = LX - 500 + br * 500
    lb(bx2, 60, LZ + 650, 180, 20, 10, "#f2efe4")
    lb(bx2 - 50, 60, LZ + 651, 40, 20, 12, "#e8742a")
    lb(bx2 + 50, 60, LZ + 651, 40, 20, 12, "#e8742a")
    lb(bx2 - 80, 28, LZ + 650, 8, 56, 8, "#555")
    lb(bx2 + 80, 28, LZ + 650, 8, 56, 8, "#555")
  }
  for cn from 0 to 5 {
    lb(LX - 800 + cn * 320, 22, LZ + 560 + (cn % 2) * 80, 26, 44, 26, "#ff7a1a")
    lb(LX - 800 + cn * 320, 26, LZ + 560 + (cn % 2) * 80, 28, 8, 28, "#ffffff")
  }
  // lamp posts, benches, planters, path lights
  for lp from 0 to 3 {
    let lpx = LX - 420 + (lp % 2) * 840
    let lpz = LZ - 150 + (lp / 2) * 520
    lb(lpx, 110, lpz, 12, 220, 12, "#2a2a34")
    lb(lpx, 230, lpz, 36, 30, 36, "#ffe9a8")
  }
  for bn from 0 to 1 {
    let bnx = LX - 640 + bn * 1280
    lb(bnx, 40, LZ + 260, 160, 14, 50, "#6a4a2a")
    lb(bnx, 70, LZ + 280, 160, 40, 10, "#6a4a2a")
    lb(bnx - 60, 20, LZ + 260, 12, 40, 40, "#2a2a34")
    lb(bnx + 60, 20, LZ + 260, 12, 40, 40, "#2a2a34")
  }
  for pl from 0 to 3 {
    let plx = LX - 380 + pl * 253
    lb(plx, 25, FZ + 190, 90, 50, 50, "#6a4a2a")
    lb(plx, 85, FZ + 190, 70, 70, 70, "#2f8a4a")
  }
  for pt from 0 to 9 {
    lb(LX - 150, 5, LZ - 250 + pt * 130, 10, 6, 10, "#ffd23f")
    lb(LX + 150, 5, LZ - 250 + pt * 130, 10, 6, 10, "#ffd23f")
  }
  // two class characters who wander about
  npcA = put3d(kidDM, LX - 500, 0, LZ + 250, 0, 45)
  npcB = put3d(kidCM, LX + 330, 0, LZ, 0, 45)
  anim3d npcA, "walk"
  anim3d npcB, "walk"
  show3d npcA, 0
  show3d npcB, 0
  // the start pad
  lb(LX, 4, LZ, 200, 4, 200, "#1f6a3a")
  lb(LX, 7, LZ, 150, 2, 150, "#46e070")
  // lamps
  add lamp3d(LX - 300, 260, FZ + 140, "#ff7ad8", 16, 900) to lobbyIds
  add lamp3d(LX + 300, 260, FZ + 140, "#7ad8ff", 16, 900) to lobbyIds
  add lamp3d(LX, 150, LZ, "#46e070", 12, 700) to lobbyIds
  add lamp3d(LX, 220, LZ + 500, "#a070ff", 12, 1100) to lobbyIds
}

fn buildCamp() {
  let base = put3d(bonfireM, CX, 0, CZ, 0, 110)
  fireId = put3d(fireM, CX, 0, CZ, 0, 110)
  fL1 = lamp3d(CX, 90, CZ, "#ff9a3a", 30, 700)
  fL2 = lamp3d(CX, 110, CZ, "#ff8a2a", 30, 1300)
  fL3 = lamp3d(CX, 130, CZ, "#ff7a1a", 30, 2000)
  let t1 = put3d(tentM, CX - 520, 0, CZ - 160, 900, 22)
  let t2 = put3d(tentM, CX + 520, 0, CZ - 260, 2700, 22)
  let l1 = put3d(logM, CX + 110, 0, CZ + 160, 300, 40)
  let l2 = put3d(logM, CX - 130, 0, CZ + 150, 1200, 40)
  let l3 = put3d(logM, CX + 40, 0, CZ - 150, 1700, 40)
  let pk = put3d(packM, CX - 90, 0, CZ + 220, 400, 35)
  let tc = put3d(torchM, CX + 180, 0, CZ + 110, 0, 45)
  // the lobby plaza (hidden while you play)
  lobbyIds = []
  buildLobby()
  // the class figures (only the chosen one shows in the lobby)
  cFig = []
  cItem = []
  for c from 0 to 6 {
    let fm = kidAM
    if c == 1 or c == 4 {
      fm = kidBM
    } else if c == 2 or c == 5 {
      fm = kidCM
    } else if c == 6 {
      fm = kidDM
    }
    let fg = put3d(fm, CX + 110, 0, CZ + 40, 0, 45)
    anim3d fg, "idle"
    let im = torchM
    let isc = 45
    if c == 1 {
      im = packM
      isc = 30
    } else if c == 2 {
      im = kitM
      isc = 35
    } else if c == 3 {
      im = canM
      isc = 40
    } else if c == 4 {
      im = gunM
      isc = 60
    } else if c == 5 {
      im = logM
      isc = 40
    } else if c == 6 {
      im = bearM
      isc = 1
    }
    let it = put3d(im, CX + 60, 40, CZ + 50, 600, isc)
    show3d fg, 0
    show3d it, 0
    add fg to cFig
    add it to cItem
  }
  // the missing children board
  let bx = CX + 260
  let bz = CZ - 470
  let p1 = block3d(bx - 90, 70, bz, 10, 140, 10, "#4a331f")
  let p2 = block3d(bx + 90, 70, bz, 10, 140, 10, "#4a331f")
  let bd1 = block3d(bx, 115, bz, 200, 80, 6, "#6a4a2a")
  bOk = []
  for k from 0 to 3 {
    let pc = block3d(bx - 66 + k * 44, 115, bz - 5, 34, 56, 3, "#e8e2c8")
    let ph = block3d(bx - 66 + k * 44, 125, bz - 7, 16, 16, 2, "#8a6a4a")
    let ok = block3d(bx - 66 + k * 44, 100, bz - 9, 30, 10, 2, "#3ddc5a")
    show3d ok, 0
    add ok to bOk
  }
  bSeen = 0 - 1
  // dashed ring that shows the safe zone, like the real game
  ringIds = []
  for d from 0 to 35 {
    let da = d * 100
    let dz1 = block3d(CX + sin3(da) * 530 / 1000, 3, CZ - cos3(da) * 530 / 1000, 40, 2, 14, "#f2efe4")
    turn3d dz1, da
    add dz1 to ringIds
  }
  ringR = 530
  // crafting bench: stacked crates and a work table
  let cb1 = block3d(CX - 330, 22, CZ + 180, 120, 44, 80, "#c8683c")
  let cb2 = block3d(CX - 330, 52, CZ + 180, 110, 16, 70, "#e0b08a")
  let cb3 = block3d(CX - 270, 15, CZ + 230, 50, 30, 50, "#a85030")
  let cb4 = block3d(CX - 390, 70, CZ + 160, 8, 140, 8, "#6b4a2e")
  // a ring of stones
  for s from 0 to 11 {
    let sa = s * 300
    let sx = CX + sin3(sa) * 85 / 1000
    let sz = CZ - cos3(sa) * 85 / 1000
    let st = block3d(sx, 6, sz, 20, 12, 20, "#5b5f66")
  }
}

fn buildLoot() {
  iX = []
  iZ = []
  iGot = []
  iId = []
  iKind = []
  for k from 0 to 13 {
    let x = random(300, WS - 300)
    let z = random(300, WS - 300)
    if dst(x, z, CX, CZ) < 1200 {
      x = x + 1500
    }
    let kind = 0
    let item = 0
    if k == 4 {
      kind = 3
      item = put3d(gunM, x, 20, z, random(0, 3599), 60)
    } else if k == 9 or k == 12 {
      kind = 4
      item = put3d(packM, x, 0, z, random(0, 3599), 20)
    } else if k % 3 == 2 {
      kind = 1
      item = put3d(kitM, x, 0, z, random(0, 3599), 32)
    } else if k % 3 == 1 {
      kind = 2
      item = put3d(canM, x, 0, z, random(0, 3599), 34)
    } else {
      item = put3d(gasM, x, 0, z, random(0, 3599), 28)
    }
    let lp = lamp3d(x, 40, z, "#ffd23f", 8, 220)
    add x to iX
    add z to iZ
    add 0 to iGot
    add item to iId
    add kind to iKind
  }
}

fn buildKids() {
  kX = []
  kZ = []
  kState = []
  kId = []
  kModel = []
  for k from 0 to 3 {
    let ang = 450 + k * 900
    let distTo = random(2400, 3600)
    let x = CX + sin3(ang) * distTo / 1000
    let z = CZ - cos3(ang) * distTo / 1000
    x = constrain(x, 400, WS - 400)
    z = constrain(z, 400, WS - 400)
    let m = kidAM
    if k == 1 {
      m = kidBM
    } else if k == 2 {
      m = kidCM
    } else if k == 3 {
      m = kidDM
    }
    let nid = put3d(m, x, 0, z, random(0, 3599), 40)
    anim3d nid, "idle"
    let lp = lamp3d(x, 110, z, "#9ad8ff", 10, 300)
    add x to kX
    add z to kZ
    add 0 to kState
    add nid to kId
  }
}

fn buildMonsters() {
  mX = []
  mZ = []
  mHp = []
  mKind = []
  mId = []
  mYaw = []
  mAtk = []
  mOn = []
  mAnim = []
  for i from 0 to 23 {
    let k = 0
    let nid = 0
    if i < 8 {
      nid = put3d(stalkM, 0, 0, 0, 0, 62)
    } else if i < 14 {
      k = 1
      nid = put3d(cultM, 0, 0, 0, 0, 62)
    } else if i < 20 {
      k = 2
      nid = put3d(wolfM, 0, 0, 0, 0, 130)
    } else if i < 22 {
      k = 3
      nid = put3d(bearM, 0, 0, 0, 0, 100)
    } else if i < 24 {
      k = 4
      nid = put3d(deerM, 0, 0, 0, 0, 75)
    } else {
      k = 1
      nid = put3d(cultM, 0, 0, 0, 0, 62)
    }
    show3d nid, 0
    add 0 to mX
    add 0 to mZ
    add 0 to mHp
    add k to mKind
    add nid to mId
    add 0 to mYaw
    add 0 to mAtk
    add 0 to mOn
    add 9 to mAnim
  }
}

// ---------- the campfire ----------
fn fireRadius() {
  if fuel <= 0 {
    return 0
  }
  return 380 + fireLvl * 150
}

fn fuelMax() {
  return 4000 + fireLvl * 1600
}

fn feedFire() {
  if dst(px, pz, CX, CZ) > 380 {
    return 0
  }
  if logs > 0 {
    logs -= 1
    fuel = min(fuelMax(), fuel + 1500)
    tone 220 for 60ms
    say("YOU FEED THE FIRE", 60)
  } else if cans > 0 {
    cans -= 1
    fuel = min(fuelMax(), fuel + 4500)
    tone 140 to 300 for 220ms
    say("THE FIRE ROARS", 80)
  } else {
    say("YOU HAVE NOTHING TO BURN", 80)
  }
}

fn upgradeCost() {
  return 4 + fireLvl * 3
}

fn upgradeFire() {
  if dst(px, pz, CX, CZ) > 380 {
    return 0
  }
  if fireLvl >= 5 {
    say("THE FIRE IS AS BIG AS IT GETS", 80)
    return 0
  }
  if logs < upgradeCost() {
    say("NEED " + upgradeCost() + " LOGS", 80)
    return 0
  }
  logs -= upgradeCost()
  fireLvl += 1
  tone 330 to 660 for 300ms
  say("FIRE LEVEL " + fireLvl, 120)
  note("FIRE REACHED LEVEL " + fireLvl + ". The safe zone has grown bigger")
}

fn ringFrame() {
  let want = fireRadius()
  if want == 0 {
    want = 380
  }
  if want != ringR and length(ringIds) == 36 {
    ringR = want
    for d from 0 to 35 {
      move3d ringIds[d], CX + sin3(d * 100) * want / 1000, 3, CZ - cos3(d * 100) * want / 1000
    }
  }
}

fn fireFrame() {
  ringFrame()
  fuelTick += 1
  // each child you saved keeps the fire a little longer
  if fuel > 0 and (fuelTick % 10) >= kidsSaved {
    fuel -= 1
  }
  let lit = 0
  if fuel > 0 {
    lit = 1
  }
  show3d fireId, lit
  show3d fL1, 0
  show3d fL2, 0
  show3d fL3, 0
  if lit == 1 {
    show3d fL1, 1
    if fireLvl >= 3 {
      show3d fL2, 1
    }
    if fireLvl >= 5 {
      show3d fL3, 1
    }
    if random(1, 6) == 1 {
      move3d fL1, CX + random(0 - 6, 6), 85 + random(0, 14), CZ + random(0 - 6, 6)
    }
    if t % 50 == 0 and dst(px, pz, CX, CZ) < 900 {
      tone 80 + random(0, 60) for 25ms
    }
  }
  if fuel == 600 and inNight == 1 {
    say("THE FIRE IS DYING", 120)
    tone 120 to 70 for 400ms
  }
}

// ---------- day and night ----------
fn skyLevel() {
  let tr = 700
  if clock < DAYF - tr {
    return 100
  }
  if clock < DAYF {
    return (DAYF - clock) * 100 / tr
  }
  if clock < DAYF + NIGHTF - tr {
    return 0
  }
  return (clock - (DAYF + NIGHTF - tr)) * 100 / tr
}

fn clockFrame() {
  clock += 1
  if inNight == 0 and clock >= DAYF {
    inNight = 1
    banner = "NIGHT " + night
    bannerT = 240
    tone 300 to 90 for 900ms
    spawnT = 120
  }
  if inNight == 1 and clock >= DAYF + NIGHTF {
    // dawn: you made it
    inNight = 0
    clock = 0
    nightsDone = night
    bank += 2 + night / 3
    save "n99_bank", bank
    if nightsDone > best {
      best = nightsDone
      save "n99_best", best
    }
    banner = "NIGHT " + night + " SURVIVED"
    bannerT = 280
    night += 1
    killAll()
    tone 400 to 800 for 700ms
  }
  let lvl = skyLevel()
  sky3d(lvl)
  if lvl < 55 {
    torch3d 70, 2400
  } else {
    torch3d 0, 2400
  }
  if bannerT > 0 {
    bannerT -= 1
  }
  if msgT > 0 {
    msgT -= 1
  }
  // night sounds
  if inNight == 1 {
    if random(1, 140) == 1 {
      tone 2400 + random(0, 500) for 30ms
    }
    if random(1, 900) == 1 {
      tone 200 to 120 for 1100ms
    }
  }
}

fn killAll() {
  let i = 0
  while i < length(mId) {
    if mOn[i] == 1 {
      mOn[i] = 0
      show3d mId[i], 0
    }
    i += 1
  }
}

// ---------- monsters ----------
fn nightCap() {
  return min(13, 2 + night * 2 / 3)
}

fn activeCount() {
  let c = 0
  let i = 0
  while i < length(mOn) {
    c += mOn[i]
    i += 1
  }
  return c
}

fn spawnOne() {
  // pick a free slot; cultists only appear from night 3
  let want = 0
  if night >= 3 and random(1, 100) <= 30 {
    want = 1
  }
  if random(1, 100) <= 35 {
    want = 2
  }
  if night >= 5 and random(1, 100) <= 15 {
    want = 3
  }
  if night >= 7 and random(1, 100) <= 12 {
    want = 4
  }
  let i = 0
  while i < length(mOn) {
    if mOn[i] == 0 and mKind[i] == want {
      let ang = random(0, 3599)
      let x = constrain(CX + sin3(ang) * 3600 / 1000, 200, WS - 200)
      let z = constrain(CZ - cos3(ang) * 3600 / 1000, 200, WS - 200)
      mX[i] = x
      mZ[i] = z
      mHp[i] = 2 + want * 2 + night / 8
      if want == 2 {
        mHp[i] = 2
      } else if want == 3 {
        mHp[i] = 9 + night / 4
      } else if want == 4 {
        mHp[i] = 12 + night / 3
      }
      mOn[i] = 1
      mAtk[i] = 40
      mAnim[i] = 9
      show3d mId[i], 1
      move3d mId[i], x, 0, z
      return 0
    }
    i += 1
  }
}

fn monsterFrame() {
  if inNight == 1 {
    spawnT -= 1
    if spawnT <= 0 and activeCount() < nightCap() {
      spawnOne()
      spawnT = max(90, 420 - night * 8)
    }
  }
  let safe = fireRadius()
  let inCamp = 0
  if safe > 0 and dst(px, pz, CX, CZ) < safe {
    inCamp = 1
  }
  let i = 0
  while i < length(mOn) {
    if mOn[i] == 1 {
      let dp = dst(mX[i], mZ[i], px, pz)
      let df = dst(mX[i], mZ[i], CX, CZ)
      let spd = 30 + night / 4
      if mKind[i] == 1 {
        spd = 22 + night / 6
      } else if mKind[i] == 2 {
        spd = 40 + night / 4
      } else if mKind[i] == 3 {
        spd = 20 + night / 8
      } else if mKind[i] == 4 {
        spd = 27 + night / 6
      }
      let gx = px
      let gz = pz
      let mode = 0
      if inCamp == 1 {
        // the player is in the light: they circle at the edge
        gx = CX
        gz = CZ
        if df < safe + 70 {
          mode = 2
        }
      }
      if mode == 2 {
        // pace along the edge of the light
        let ca = atan2(mX[i] - CX, CZ - mZ[i]) + 700
        gx = CX + sin3(ca) * (safe + 90) / 1000
        gz = CZ - cos3(ca) * (safe + 90) / 1000
        spd = spd * 5 / 10
      }
      let dx = gx - mX[i]
      let dz = gz - mZ[i]
      let dlen = max(1, dst(0, 0, dx, dz))
      let want = 0
      if dp > 130 or mode == 2 {
        // spd is in tenths of a centimetre per frame
        mX[i] = mX[i] + dx * spd / dlen / 10
        mZ[i] = mZ[i] + dz * spd / dlen / 10
        want = 1
        if mode == 0 and spd > 28 {
          want = 2
        }
        mYaw[i] = atan2(dx, 0 - dz)
      } else {
        mYaw[i] = atan2(px - mX[i], mZ[i] - pz)
      }
      // a fire pushes them back out of the light
      if safe > 0 and mode != 2 and inCamp == 1 and df < safe {
        mX[i] = mX[i] - (CX - mX[i]) * 3 / max(1, df)
        mZ[i] = mZ[i] - (CZ - mZ[i]) * 3 / max(1, df)
      }
      if mAtk[i] > 0 {
        mAtk[i] -= 1
      }
      if dp < 140 and mAtk[i] == 0 and inCamp == 0 and hurtT == 0 {
        hp -= 1
        hurtT = 60
        mAtk[i] = 70
        tone 120 to 60 for 200ms
        say("YOU WERE HIT", 60)
        want = 3
      }
      if want != mAnim[i] {
        mAnim[i] = want
        if mKind[i] >= 2 {
          want = 9
        } else if want == 0 {
          anim3d mId[i], "idle"
        } else if want == 1 {
          anim3d mId[i], "walk"
        } else if want == 2 {
          anim3d mId[i], "sprint"
        } else if want == 3 {
          anim3d mId[i], "attack-melee-right"
        } else {
          anim3d mId[i], "idle"
        }
      }
      move3d mId[i], mX[i], 0, mZ[i]
      if mKind[i] >= 2 {
        turn3d mId[i], mYaw[i]
      } else {
        turn3d mId[i], mYaw[i] + 1800
      }
    }
    i += 1
  }
  if hurtT > 0 {
    hurtT -= 1
  }
}

fn swing() {
  if swingT > 0 or state != 1 {
    return 0
  }
  swingT = 24
  tone 220 to 120 for 80ms
  let hit = 0
  // monsters first
  let i = 0
  while i < length(mOn) {
    if mOn[i] == 1 {
      let d = dst(px, pz, mX[i], mZ[i])
      let ahead = ((mX[i] - px) * sin3(yaw) - (mZ[i] - pz) * cos3(yaw)) / 1000
      if d < 280 and ahead > 0 {
        mHp[i] -= 1 + axeLvl
        hit = 1
        mX[i] = mX[i] + (mX[i] - px) * 90 / (d + 1)
        mZ[i] = mZ[i] + (mZ[i] - pz) * 90 / (d + 1)
        tone 90 for 60ms
        if mHp[i] <= 0 {
          mOn[i] = 0
          show3d mId[i], 0
          say("IT FALLS", 50)
        }
      }
    }
    i += 1
  }
  if hit == 1 {
    return 0
  }
  // then trees
  let bi = 0 - 1
  let bd = 300
  i = 0
  while i < length(tX) {
    if tHp[i] > 0 {
      let d2 = dst(px, pz, tX[i], tZ[i])
      let ahead2 = ((tX[i] - px) * sin3(yaw) - (tZ[i] - pz) * cos3(yaw)) / 1000
      if d2 < bd and ahead2 > 0 {
        bd = d2
        bi = i
      }
    }
    i += 1
  }
  if bi >= 0 {
    tHp[bi] -= 1 + axeLvl / 2
    tone 160 + random(0, 40) for 50ms
    if tHp[bi] <= 0 {
      show3d tA[bi], 0
      show3d tB[bi], 0
      show3d tC[bi], 0
      show3d tD[bi], 0
      tHp[bi] = 0
      let got = min(2, packMax - logs)
      if cls == 5 and random(1, 100) <= 20 {
        got = min(3, packMax - logs)
      }
      if got > 0 {
        logs += got
        say("+" + got + " LOGS", 70)
      } else {
        say("YOUR PACK IS FULL", 80)
      }
      tone 90 to 50 for 300ms
    }
  }
}

// ---------- loot, kids ----------
fn lootFrame() {
  let i = 0
  while i < length(iX) {
    if iGot[i] == 0 and dst(px, pz, iX[i], iZ[i]) < 140 {
      iGot[i] = 1
      show3d iId[i], 0
      if iKind[i] == 1 {
        kits += 1
        say("FIRST AID KIT (4 TO USE)", 100)
      } else if iKind[i] == 3 {
        hasGun = 1
        shells += 4
        say("SHOTGUN! R TO FIRE", 140)
      } else if iKind[i] == 4 {
        shells += 4
        say("+4 SHELLS", 90)
      } else if iKind[i] == 2 {
        foodN += 1
        say("CANNED FOOD (5 TO EAT)", 100)
      } else {
        cans += 1
        say("GAS CAN - FEEDS THE FIRE", 100)
      }
      tone 520 for 80ms
    }
    i += 1
  }
}

fn kidFrame() {
  let i = 0
  kidsFollow = 0
  while i < length(kX) {
    if kState[i] == 1 {
      kidsFollow += 1
      let d = dst(kX[i], kZ[i], px, pz)
      if d > 170 {
        let dx = px - kX[i]
        let dz = pz - kZ[i]
        let dlen = max(1, dst(0, 0, dx, dz))
        let sp = 26
        if d > 700 {
          sp = 44
        }
        kX[i] = kX[i] + dx * sp / dlen / 10
        kZ[i] = kZ[i] + dz * sp / dlen / 10
        turn3d kId[i], atan2(dx, 0 - dz) + 1800
        move3d kId[i], kX[i], 0, kZ[i]
      }
      if dst(kX[i], kZ[i], CX, CZ) < 480 {
        kState[i] = 2
        kidsSaved += 1
        bank += 10
        save "n99_bank", bank
        // they settle by the fire
        let ang = 300 + i * 1500
        kX[i] = CX + sin3(ang) * 260 / 1000
        kZ[i] = CZ - cos3(ang) * 260 / 1000
        move3d kId[i], kX[i], 0, kZ[i]
        turn3d kId[i], atan2(CX - kX[i], kZ[i] - CZ) + 1800
        banner = "CHILD RESCUED"
        bannerT = 200
        tone 500 to 900 for 400ms
      }
    }
    i += 1
  }
}

fn useKey() {
  if state == 5 {
    lobbyUse()
    return 0
  }
  if state != 1 {
    return 0
  }
  if dst(px, pz, CX, CZ) < 380 {
    feedFire()
    return 0
  }
  if dst(px, pz, CX + 260, CZ - 470) < 300 {
    let bi = 0 - 1
    let bd = 99999
    let j = 0
    while j < length(kX) {
      if kState[j] == 0 and dst(px, pz, kX[j], kZ[j]) < bd {
        bd = dst(px, pz, kX[j], kZ[j])
        bi = j
      }
      j += 1
    }
    if bi < 0 {
      say("ALL THE CHILDREN ARE SAFE", 120)
    } else {
      let dirs = "NORTH"
      let dxk = kX[bi] - px
      let dzk = kZ[bi] - pz
      if abs(dxk) > abs(dzk) {
        dirs = "EAST"
        if dxk < 0 {
          dirs = "WEST"
        }
      } else if dzk > 0 {
        dirs = "SOUTH"
      }
      say("A CHILD WAS SEEN " + (bd / 100) + "m " + dirs, 200)
    }
    return 0
  }
  let i = 0
  while i < length(kX) {
    if kState[i] == 0 and dst(px, pz, kX[i], kZ[i]) < 260 {
      kState[i] = 1
      say("COME ON - TO THE FIRE!", 120)
      tone 600 for 100ms
      return 0
    }
    i += 1
  }
}

// ---------- the player ----------
fn blockedAt(x, z) {
  if x < 140 or z < 140 or x > WS - 140 or z > WS - 140 {
    return 1
  }
  let i = 0
  while i < length(tX) {
    if tHp[i] > 0 and abs(x - tX[i]) < 45 and abs(z - tZ[i]) < 45 {
      return 1
    }
    i += 1
  }
  return 0
}

fn figX(c) {
  return LX + sin3(900 + c * 300) * 520 / 1000
}
fn figZ(c) {
  return LZ - cos3(900 + c * 300) * 520 / 1000
}

fn npcFrame() {
  npcT += 1
  // A strolls along the front of the shop, B circles the pad
  let ax = LX + sin3(npcT * 4) * 620 / 1000
  let axx = LX + sin3(npcT * 3) * 600 / 1000
  let az = LZ + 250 + cos3(npcT * 3) * 40 / 1000
  let adx = cos3(npcT * 3) * 3
  let ba = npcT * 5
  let bx = LX + sin3(ba) * 330 / 1000
  let bz = LZ - cos3(ba) * 330 / 1000
  move3d npcA, axx, 0, az
  turn3d npcA, atan2(adx, 0 - 0) + 1800
  move3d npcB, bx, 0, bz
  turn3d npcB, ba + 900 + 1800
}

fn lobbyShow() {
  if state == 5 {
    show3d npcA, 1
    show3d npcB, 1
  } else {
    show3d npcA, 0
    show3d npcB, 0
  }
  for lid from 0 to length(lobbyIds) - 1 {
    if state == 5 {
      show3d lobbyIds[lid], 1
    } else {
      show3d lobbyIds[lid], 0
    }
  }
  if length(cFig) == 7 {
    for c from 0 to 6 {
      let vis = 0
      if state == 5 or (state == 0 and c == cls) {
        vis = 1
      }
      if state == 5 {
        move3d cFig[c], figX(c), 0, figZ(c)
        turn3d cFig[c], atan2(LX - figX(c), figZ(c) - LZ)
        move3d cItem[c], figX(c) + (LX - figX(c)) / 6 + 30, 40, figZ(c) + (LZ - figZ(c)) / 6
      }
      show3d cFig[c], vis
      if c < 6 {
        show3d cItem[c], vis
      } else {
        show3d cItem[c], 0
      }
    }
  }
}

fn enterLobby() {
  newRun()
  state = 5
  bannerT = 0
  msgT = 0
  px = LX
  pz = LZ + 850
  yaw = 0
  fuel = 9000
  say("PICK A CLASS", 300)
  lobbyShow()
}

fn nearFig() {
  let best1 = 0 - 1
  let bd = 190
  let c = 0
  while c < 7 {
    let d = dst(px, pz, figX(c), figZ(c))
    if d < bd {
      bd = d
      best1 = c
    }
    c += 1
  }
  return best1
}

fn lobbyUse() {
  let c = nearFig()
  if c >= 0 {
    cls = c
    if unlocked(c) == 0 {
      if bank >= clsCost[c] {
        bank -= clsCost[c]
        save "n99_bank", bank
        save "n99_u" + c, 1
        save "n99_cls", c
        say("UNLOCKED!", 100)
        tone 700 for 150ms
      } else {
        cls = saved("n99_cls", 0)
        say("NEED DIAMONDS", 100)
        tone 90 for 120ms
      }
    } else {
      save "n99_cls", c
      say("CLASS SELECTED", 100)
      tone 520 for 80ms
    }
    return 0
  }
  if dst(px, pz, LX, LZ) < 180 {
    newRun()
  }
}

fn boardFrame() {
  if bSeen != kidsSaved and length(bOk) == 4 {
    bSeen = kidsSaved
    for k from 0 to 3 {
      if k < kidsSaved {
        show3d bOk[k], 1
      } else {
        show3d bOk[k], 0
      }
    }
  }
}

fn shoot() {
  if state != 1 or hasGun == 0 or gunT > 0 {
    return 0
  }
  if shells <= 0 {
    say("OUT OF SHELLS", 60)
    gunT = 20
    return 0
  }
  shells -= 1
  gunT = 50
  tone 70 to 40 for 220ms
  hurtT = max(hurtT, 0)
  let i = 0
  let hits = 0
  while i < length(mOn) {
    if mOn[i] == 1 {
      let d = dst(px, pz, mX[i], mZ[i])
      let ahead = ((mX[i] - px) * sin3(yaw) - (mZ[i] - pz) * cos3(yaw)) / 1000
      let side = ((mX[i] - px) * cos3(yaw) + (mZ[i] - pz) * sin3(yaw)) / 1000
      if d < 1500 and ahead > 0 and abs(side) < 130 + d / 8 {
        mHp[i] -= 3
        hits += 1
        mX[i] = mX[i] + (mX[i] - px) * 150 / (d + 1)
        mZ[i] = mZ[i] + (mZ[i] - pz) * 150 / (d + 1)
        if mHp[i] <= 0 {
          mOn[i] = 0
          show3d mId[i], 0
          say("IT FALLS", 50)
        }
      }
    }
    i += 1
  }
}

fn avatarFrame() {
  if pAv == 0 {
    return 0
  }
  let vis = 0
  if state == 1 or state == 5 or state == 2 {
    vis = 1
  }
  show3d pAv, vis
  if vis == 0 {
    return 0
  }
  let fwd = 0
  let side = 0
  if held("w") or held("up") {
    fwd += 1
  }
  if held("s") or held("down") {
    fwd -= 1
  }
  if held("d") {
    side += 1
  }
  if held("a") {
    side -= 1
  }
  let want = 0
  if fwd != 0 or side != 0 {
    want = 1
    avYaw = yaw + atan2(side, fwd)
    if held("shift") and tired == 0 and stam > 0 {
      want = 2
    }
  }
  if want != avAnim {
    avAnim = want
    if want == 0 {
      anim3d pAv, "idle"
    } else if want == 1 {
      anim3d pAv, "walk"
    } else {
      anim3d pAv, "sprint"
    }
  }
  move3d pAv, px, 0, pz
  turn3d pAv, avYaw + 1800
}

fn camFollow(shake) {
  let cxp = px - sin3(yaw) * camD / 1000
  let czp = pz + cos3(yaw) * camD / 1000
  let cyp = max(60, 250 - pitch / 8)
  camera3d cxp, cyp, czp, yaw + shake, 0 - 140 + pitch / 2
}

fn playerFrame() {
  if gunT > 0 {
    gunT -= 1
  }
  yaw += mousedx() * 3
  pitch -= mousedy() * 3
  pitch = constrain(pitch, 0 - 250, 600)
  if held("left") {
    yaw -= 28
  }
  if held("right") {
    yaw += 28
  }
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
  if held("d") {
    side += 1
  }
  if held("a") {
    side -= 1
  }
  let moving = 0
  if fwd != 0 or side != 0 {
    moving = 1
  }
  // speed in tenths of a centimetre per frame
  let spd = 30 + spdBonus
  if moving == 1 and held("shift") and stam > 0 and tired == 0 {
    spd = 52 + spdBonus
    stam -= 2
    if stam <= 0 {
      stam = 0
      tired = 1
      say("OUT OF BREATH", 90)
    }
  } else {
    if moving == 1 {
      stam = min(600, stam + 1)
    } else {
      stam = min(600, stam + 3)
    }
    if tired == 1 and stam >= 240 {
      tired = 0
    }
  }
  let dx = (sin3(yaw) * fwd + cos3(yaw) * side) * spd / 10000
  let dz = (0 - cos3(yaw) * fwd + sin3(yaw) * side) * spd / 10000
  if fwd != 0 and side != 0 {
    dx = dx * 7 / 10
    dz = dz * 7 / 10
  }
  if blockedAt(px + dx, pz) == 0 {
    px += dx
  }
  if blockedAt(px, pz + dz) == 0 {
    pz += dz
  }
  if moving == 1 {
    bob += spd
    stepAcc += spd
    if stepAcc > 1500 {
      stepAcc = 1
      tone 52 + random(0, 16) for 35ms
    }
  } else {
    stepAcc = 0
  }
  if swingT > 0 {
    swingT -= 1
  }
  // hunger
  hungT += 1
  let hungLim = 90
  if cls == 0 {
    hungLim = 100
  }
  if hungT >= hungLim {
    hungT = 0
    hunger = max(0, hunger - 1)
    if hunger == 0 and hp > 1 {
      hp -= 1
      hurtT = 50
      say("YOU ARE STARVING", 80)
    }
  }
  // standing in the firelight slowly heals you
  if fireRadius() > 0 and dst(px, pz, CX, CZ) < fireRadius() and t % 240 == 0 and hp < hpMax {
    hp += 1
  }
}

// ---------- run control ----------
fn newRun() {
  buildWorld()
  px = CX
  pz = CZ + 300
  yaw = 0
  pitch = 0
  hp = hpMax
  stam = 600
  tired = 0
  logs = 3
  cans = 0
  kits = 0
  foodN = 1
  hasGun = 0
  shells = 0
  gunT = 0
  packMax = 12
  axeLvl = 0
  spdBonus = 0
  if cls == 1 {
    packMax = 14
  } else if cls == 2 {
    kits = 2
  } else if cls == 3 {
    foodN = 3
  } else if cls == 4 {
    hasGun = 1
    shells = 12
  } else if cls == 5 {
    axeLvl = 1
  } else if cls == 6 {
    axeLvl = 2
    spdBonus = 6
  }
  lobbyShow()
  hunger = 100
  hungT = 0
  fuel = 3600
  fireLvl = 1
  if cls == 3 {
    fuel = 5400
    fireLvl = 2
  }
  clock = 0
  night = 1
  inNight = 0
  nightsDone = 0
  kidsSaved = 0
  kidsFollow = 0
  spawnT = 0
  hurtT = 0
  swingT = 0
  state = 1
  banner = "DAY 1"
  bannerT = 260
  say("CHOP TREES (F) AND KEEP THE FIRE BURNING", 260)
  if musicOn == 1 {
    music "e3 - - - g3 - - - a3 - - - d3 - - -", "a1 - - - - - - - e2 - - - - - - -" tempo 40
  }
}

fn useKit() {
  if state == 1 and kits > 0 and hp < hpMax {
    kits -= 1
    hp = min(hpMax, hp + 3)
    say("PATCHED UP", 80)
    tone 620 for 90ms
  }
}
fn useFood() {
  if state == 1 and foodN > 0 and hunger < 100 {
    foodN -= 1
    hunger = min(100, hunger + 45)
    say("ATE CANNED FOOD", 80)
    tone 300 for 90ms
  }
}
when key "4" pressed {
  useKit()
}
when key "5" pressed {
  useFood()
}
fn unlocked(c) {
  if c == 0 {
    return 1
  }
  return saved("n99_u" + c, 0)
}
fn pickCls(d) {
  if state == 0 {
    cls = (cls + d + 7) % 7
    save "n99_cls", cls
    tone 500 for 60ms
    lobbyShow()
  }
}
fn buyCls() {
  if unlocked(cls) == 0 {
    if bank >= clsCost[cls] {
      bank -= clsCost[cls]
      save "n99_bank", bank
      save "n99_u" + cls, 1
      tone 700 for 150ms
      return 1
    }
    tone 90 for 120ms
    return 0
  }
  return 1
}
when key "r" pressed {
  shoot()
}
when key "e" pressed {
  useKey()
}
when key "f" pressed {
  swing()
}
when key "space" pressed {
  swing()
}
when key "u" pressed {
  if state == 1 {
    upgradeFire()
  }
}
when key "m" pressed {
  if musicOn == 1 {
    musicOn = 0
    music "-" tempo 40
  } else {
    musicOn = 1
  }
}
when key "enter" pressed {
  if state == 0 {
    if introSeen == 0 {
      startIntro()
    } else {
      enterLobby()
    }
  } else if state == 3 {
    endIntro()
  } else if state == 2 {
    enterLobby()
  }
}

// ---------- intro ----------
fn startIntro() {
  buildWorld()
  state = 3
  cutT = 0
  cutIdx = 0
}

fn endIntro() {
  introSeen = 1
  save "n99_intro", 1
  enterLobby()
}

fn introText(i) {
  if i == 0 {
    return "THE ROAD ENDED THREE DAYS AGO."
  }
  if i == 1 {
    return "THE CHILDREN WANDERED INTO THE TREES."
  }
  if i == 2 {
    return "NIGHT BRINGS THINGS THAT HATE THE LIGHT."
  }
  return "KEEP THE FIRE BURNING. SURVIVE 99 NIGHTS."
}

fn introFrame() {
  cutT += 1
  let dur = 300
  let f = cutT * 1000 / dur
  let ang = 600 * cutIdx + 700 * f / 1000
  let rad = 1400 - cutIdx * 150
  let cxx = CX + sin3(ang) * rad / 1000
  let czz = CZ - cos3(ang) * rad / 1000
  sky3d(40 + cutIdx * 18)
  camera3d cxx, 260 - cutIdx * 30, czz, atan2(CX - cxx, czz - CZ), 0 - 150
  torch3d 0, 1000
  if cutT >= dur {
    cutT = 0
    cutIdx += 1
    if cutIdx > 3 {
      endIntro()
    }
  }
  fireFrame()
}

// ---------- HUD ----------
fn panel(x, y, w, h, col) {
  box x, y, w, h color "#07090dc8"
  box x, y, w, 1 color col
  box x, y + h - 1, w, 1 color "#ffffff12"
}

fn writeR(text1, x, y, col) {
  write text1 at x - length(text1) * 6, y color col
}

fn keyHint(key, text1, y, col) {
  let w = length(text1) * 6 + 30
  let x = 160 - w / 2
  box x, y - 3, w, 15 color "#0d1410b0"
  box x + 4, y, 12, 10 color "#59606e"
  box x + 5, y + 1, 10, 8 color "#161b24"
  write key at x + 8, y + 2 color "#ffffff"
  write text1 at x + 22, y + 2 color col
}

fn bar(x, y, w, val, maxv, col) {
  box x, y, w, 6 color "#000000b0"
  box x + 1, y + 1, w - 2, 4 color "#2a1a1a"
  if val > 0 {
    box x + 1, y + 1, min(w - 2, val * (w - 2) / maxv), 4 color col
  }
}

fn drop(x, y) {
  box x + 2, y, 2, 2 color "#ff3b30"
  box x + 1, y + 2, 4, 3 color "#ff3b30"
  box x + 2, y + 5, 2, 1 color "#ff3b30"
}

fn fork(x, y) {
  box x, y, 1, 6 color "#ffb347"
  box x + 2, y, 1, 6 color "#ffb347"
  box x + 4, y, 1, 6 color "#ffb347"
  box x, y + 3, 5, 1 color "#ffb347"
}

fn vignette() {
  for i from 0 to 5 {
    let a = hex2(150 - i * 24)
    box 0, i * 3, 320, 3 color "#000000" + a
    box 0, 177 - i * 3, 320, 3 color "#000000" + a
    box i * 4, 0, 4, 180 color "#000000" + hex2(120 - i * 20)
    box 316 - i * 4, 0, 4, 180 color "#000000" + hex2(120 - i * 20)
  }
}

fn slot(i, count, x0) {
  let names = ["Axe", "Logs", "Gas", "Kit", "Food", "Ammo"]
  let x = x0 + i * 34
  let y = 160
  box x, y, 32, 17 color "#10161aa8"
  if i == slotSel {
    box x, y, 32, 1 color "#f4f0e7"
    box x, y + 16, 32, 1 color "#f4f0e7"
    box x, y, 1, 17 color "#f4f0e7"
    box x + 31, y, 1, 17 color "#f4f0e7"
  }
  write names[i] at x + 16, y + 2 color "#e8e6df" centered
  if count >= 0 {
    write "" + count at x + 16, y + 9 color "#ffd24a" centered
  } else {
    write "Lv " + (axeLvl + 1) at x + 16, y + 9 color "#bfc4cc" centered
  }
}
fn slotTxt(i, count) {
}

fn y1() {
  return 150
}

fn hudTop() {
  // small day label, top centre, like the real game
  let label = "Day " + night
  if inNight == 1 {
    label = "Night " + night
  }
  write label at 161, 4 color "#000000" centered
  write label at 160, 3 color "#ffffff" centered
  // survival bars, slim, on the left edge
  box 3, 66, 46, 8 color "#00000090"
  box 4, 67, 44, 6 color "#2a1a10"
  box 4, 67, hunger * 44 / 100, 6 color "#f08a1e"
  fork(6, 67)
  box 3, 77, 46, 6 color "#00000090"
  box 4, 78, 44, 4 color "#2a1010"
  box 4, 78, hp * 44 / hpMax, 4 color "#e0382c"
  box 3, 86, 46, 5 color "#00000090"
  box 4, 87, 44, 3 color "#202020"
  box 4, 87, stam * 44 / 600, 3 color "#f4f0e7"
  // compass + clock, small panel top right
  let total = DAYF + NIGHTF
  box 250, 4, 66, 17 color "#00000090"
  let ca = atan2(CX - px, pz - CZ) - yaw
  while ca > 1800 {
    ca -= 3600
  }
  while ca < 0 - 1800 {
    ca += 3600
  }
  let cx2 = 283 + constrain(ca, 0 - 900, 900) * 28 / 900
  box 254, 9, 58, 1 color "#ffffff40"
  box cx2 - 1, 6, 3, 6 color "#ff9a3a"
  write "camp " + dst(px, pz, CX, CZ) / 100 + "m" at 283, 11 color "#d8dbe2" centered
  box 254, 18, 58, 1 color "#ffffff20"
  box 254, 18, DAYF * 58 / total, 1 color "#e6c75a"
  box 254 + clock * 58 / total - 1, 17, 2, 3 color "#ffffff"
  writeR("Kids " + kidsSaved + "/4", 314, 24, "#ffd24a")
  // campfire level bar when near camp
  if dst(px, pz, CX, CZ) < 700 {
    write "level " + fireLvl + " progress: " + (fuel * 100 / fuelMax()) + "/100" at 160, 12 color "#ffffff" centered shadow
    box 105, 21, 110, 8 color "#000000"
    box 105, 21, fuel * 110 / fuelMax(), 8 color "#2cff2c"
  }
}

fn hudBottom() {
  // hotbar: small dark label slots, bottom centre
  let n = 5
  if hasGun == 1 {
    n = 6
  }
  let x0 = 160 - n * 17
  slot(0, 0 - 1, x0)
  slot(1, logs, x0)
  slot(2, cans, x0)
  slot(3, kits, x0)
  slot(4, foodN, x0)
  if hasGun == 1 {
    slot(5, shells, x0)
  }
  if swingT > 0 {
    box x0, 178, swingT * (n * 34) / 24, 1 color "#ffffff"
  }
  // prompts
  let nearFire = dst(px, pz, CX, CZ) < 380
  if nearFire {
    let tx = "FEED THE FIRE (" + logs + " LOGS)"
    if logs == 0 and cans > 0 {
      tx = "POUR GAS ON THE FIRE"
    }
    keyHint("E", tx, 108, "#ff9a3a")
    if fireLvl < 5 {
      keyHint("U", "UPGRADE FIRE - " + upgradeCost() + " LOGS", 124, "#ffd23f")
    }
  } else {
    let i = 0
    while i < length(kX) {
      if kState[i] == 0 and dst(px, pz, kX[i], kZ[i]) < 260 {
        keyHint("E", "RESCUE THE CHILD", 120, "#9ad8ff")
      }
      i += 1
    }
  }
}

fn lvlText(c, l) {
  let all = ["-10% hunger/drain|Better sight/at night|Starts with/a stew", "+2 sack space|Sack fills/slower|More gas cans/in chests", "Starts with/2 medkits|Heals faster|Revive allies", "Starts with/more food|Faster/crockpot|25% hearty/stew", "Shotgun and/12 shells|Reload faster|More shells/in chests", "20% chance of/an extra log|Stronger axe|Chops faster", "Strong blade/+speed|First hit can/crit|Knives spawn/in chests"]
  let row = all[c]
  let n = 0
  let st = 0
  let i = 0
  while i <= length(row) {
    if i == length(row) or part(row, i, 1) == "|" {
      if n == l {
        return part(row, st, i - st)
      }
      n += 1
      st = i + 1
    }
    i += 1
  }
  return ""
}

fn drawLines(tx, x, y, col) {
  let st = 0
  let i = 0
  let yy = y
  while i <= length(tx) {
    if i == length(tx) or part(tx, i, 1) == "/" {
      write part(tx, st, i - st) at x, yy color col
      yy += 9
      st = i + 1
    }
    i += 1
  }
}

fn drawTitle(c, x, y) {
  if c == 0 {
    draw tl0 at x - 75, y - 10 scale 50
  } else if c == 1 {
    draw tl1 at x - 75, y - 10 scale 50
  } else if c == 2 {
    draw tl2 at x - 75, y - 10 scale 50
  } else if c == 3 {
    draw tl3 at x - 75, y - 10 scale 50
  } else if c == 4 {
    draw tl4 at x - 75, y - 10 scale 50
  } else if c == 5 {
    draw tl5 at x - 75, y - 10 scale 50
  } else {
    draw tl6 at x - 75, y - 10 scale 50
  }
}

fn gem(x, y) {
  box x + 2, y, 4, 1 color "#bff3ff"
  box x + 1, y + 1, 6, 2 color "#5ad8ff"
  box x + 2, y + 3, 4, 2 color "#2a9ad8"
  box x + 3, y + 5, 2, 1 color "#1a70b0"
}

fn starRow(n, x, y) {
  let k = 0
  while k < n {
    box x + k * 7, y + 1, 5, 4 color "#ffd23f"
    box x + k * 7 + 1, y, 3, 6 color "#ffd23f"
    k += 1
  }
}

fn classMenu(near) {
  let names = ["Camper", "Scavenger", "Medic", "Cook", "Ranger", "Lumberjack", "Assassin"]
  let tools = ["Flashlight", "No tools", "Bandages", "Seasoning", "Shotgun", "Good Axe", "Katana"]
  let toolN = ["x1", "", "x2", "x1", "x1", "x1", "x1"]
  let stars = [1, 1, 2, 2, 3, 3, 5]
  // left: the daily shop list
  box 3, 20, 100, 136 color "#4a3320e8"
  box 3, 20, 100, 11 color "#6a4a2a"
  draw tlShop at 2 - 75, 17 - 10 scale 50
  let r = 0
  while r < 7 {
    let ry = 33 + r * 17
    let inStock = 1
    if unlocked(r) == 0 and bank < clsCost[r] {
      inStock = 0
    }
    let rc = "#4f8a2e"
    if r == near {
      rc = "#8fe04a"
    }
    box 4, ry, 98, 16 color "#000000a0"
    box 5, ry + 1, 96, 14 color rc
    if unlocked(r) == 0 {
      gem(8, ry + 2)
      write "" + clsCost[r] at 17, ry + 1 color "#ffffff"
    } else {
      write "OK" at 10, ry + 1 color "#7fff9a"
    }
    write names[r] at 100 - length(names[r]) * 6, ry + 1 color "#ffffff"
    starRow(stars[r], 64, ry + 9)
    if inStock == 1 {
      write "IN STOCK" at 8, ry + 9 color "#46e070"
    } else {
      write "NO STOCK" at 8, ry + 9 color "#ff4a3a"
    }
    r += 1
  }
  // top: the name on the doors
  drawTitle(near, 85, 20)
  // right: starter tools
  box 212, 20, 106, 136 color "#3a2a1ce8"
  box 212, 20, 106, 1 color "#e8e2c8"
  draw tlTools at 190 - 75, 22 - 10 scale 50
  write tools[near] at 265, 40 color "#ffffff" centered
  if length(toolN[near]) > 0 {
    write toolN[near] at 300, 40 color "#ffffff"
  }
  let lv = 0
  while lv < 3 {
    let ly = 52 + lv * 34
    box 215, ly, 100, 32 color "#2a2016"
    box 218, ly + 11, 10, 10 color "#e8d9a8"
    box 219, ly + 12, 8, 8 color "#2a2016"
    write "" + (lv + 1) at 221, ly + 13 color "#ffffff"
    let col = "#ffffff"
    if lv > 0 {
      col = "#7f8aa8"
    }
    drawLines(lvlText(near, lv), 232, ly + 7, col)
    lv += 1
  }
  let st = "E: SELECT"
  if unlocked(near) == 0 {
    st = "E: BUY FOR " + clsCost[near]
  } else if cls == near {
    st = "SELECTED"
  }
  keyHint("E", st, 161, "#9ad8ff")
}

fn lobbyHud() {
  let names = ["Camper", "Scavenger", "Medic", "Cook", "Ranger", "Lumberjack", "Assassin"]
  let descs = ["Less hunger drain", "+2 sack space", "Starts with 2 medkits", "Starts with extra food", "Starts with a shotgun", "Better axe, extra logs", "Strong blade, fast"]
  if nearFig() < 0 {
    write "99 Nights Lobby" at 161, 7 color "#000000" size 2 centered
    write "99 Nights Lobby" at 160, 6 color "#ffffff" size 2 centered
  }
  box 6, 6, 40, 14 color "#000000a0"
  box 10, 10, 6, 6 color "#5ad8ff"
  write "" + bank at 20, 10 color "#ffffff"
  let near = nearFig()
  if near >= 0 {
    classMenu(near)
  }
  if near >= 0 {
    box 0, 0, 0, 0 color "#000000"
  } else if dst(px, pz, LX, LZ) < 180 {
    keyHint("E", "START - " + names[cls], 150, "#46e070")
  } else {
    write "Class: " + names[cls] + "   step on the green pad to start" at 160, 168 color "#c9ccd6" centered shadow
  }
  if msgT > 0 {
    write msg at 160, 120 color "#ffffff" centered shadow
  }
}

fn hud() {
  if state == 3 {
    box 0, 0, 320, 24 color "#000000"
    box 0, 156, 320, 24 color "#000000"
    let n = min(length(introText(cutIdx)), cutT / 2)
    write part(introText(cutIdx), 0, n) at 160, 164 color "#e8e2c8" centered
    write "ENTER: SKIP" at 250, 8 color "#6f7686"
    return 0
  }
  if state == 0 {
    box 0, 0, 320, 44 color "#000000a0"
    box 0, 140, 320, 40 color "#000000b0"
    write "99 NIGHTS" at 160, 6 color "#e8e2c8" size 3 centered shadow
    write "IN THE FOREST" at 160, 31 color "#8c8666" centered
    if (t / 30) % 2 == 0 {
      write "PRESS ENTER" at 160, 148 color "#ffd23f" size 2 centered shadow
    }
    write "BEST: " + best + " NIGHTS     DIAMONDS " + bank at 160, 170 color "#6f7686" centered
    return 0
  }
  if state == 5 {
    lobbyHud()
    return 0
  }
  if state == 2 {
    box 0, 0, 320, 180 color "#5a0000c0"
    write "THE FOREST TOOK YOU" at 160, 60 color "#ff3b30" size 2 centered shadow
    write "YOU LASTED " + nightsDone + " NIGHTS" at 160, 94 color "#e8e2c8" centered shadow
    write "BEST: " + best + "   KIDS SAVED: " + kidsSaved at 160, 108 color "#9aa1b0" centered
    if (t / 30) % 2 == 0 {
      write "ENTER: TRY AGAIN" at 160, 140 color "#ffd23f" centered shadow
    }
    return 0
  }
  let carry = logs + "/" + packMax
  write carry at 161, 93 color "#000000" centered size 1
  write carry at 160, 92 color "#ffffff" centered size 1
  hudTop()
  hudBottom()
  if hurtT > 40 {
    box 0, 0, 320, 180 color "#a0000040"
  }
  if msgT > 0 {
    write msg at 161, 43 color "#000000" centered
    write msg at 160, 42 color "#ffffff" centered
  }
  if noteT > 0 {
    noteT -= 1
    let ny = 30
    box 78, ny, 176, 22 color "#e8d9a8e8"
    box 78, ny, 176, 1 color "#fff4cc"
    box 78, ny + 21, 176, 1 color "#a88f55"
    box 83, ny + 5, 10, 10 color "#2a2a2a"
    write noteText at 98, ny + 7 color "#2a2418"
  }
  if bannerT > 0 {
    let a = min(255, bannerT * 3)
    if bannerT > 200 {
      a = min(255, (260 - bannerT) * 6)
    }
    write banner at 160, 56 color "#e8e2c8" + hex2(a) size 2 centered shadow
  }
}

// ---------- main loop ----------
newRun()
state = 0
lobbyShow()
let idle = 0

every frame {
  t += 1
  if state == 0 {
    idle += 2
    sky3d(70)
    camera3d CX - 20 + sin3(idle * 2) * 25 / 1000, 135, CZ + 330, 0 - 60 + sin3(idle * 2) * 30 / 1000, 0 - 40
    torch3d 0, 1000
    fireFrame()
  } else if state == 5 {
    sky3d(58)
    npcFrame()
    playerFrame()
    px = constrain(px, LX - 1250, LX + 1250)
    pz = constrain(pz, FZ + 60, LZ + 1000)
    fireFrame()
    if msgT > 0 {
      msgT -= 1
    }
    hunger = 100
    hp = hpMax
    avatarFrame()
    camFollow(0)
  } else if state == 3 {
    introFrame()
  } else if state == 1 {
    clockFrame()
    fireFrame()
    playerFrame()
    lootFrame()
    boardFrame()
    kidFrame()
    monsterFrame()
    if hp <= 0 {
      state = 2
      nightsDone = night - 1
      tone 100 to 40 for 900ms
    }
    avatarFrame()
    camFollow(0)
  } else if state == 2 {
    sky3d(0)
    avatarFrame()
    camFollow(0)
  }
  render3d
  hud()
}
