// =====================================================================
//  ASHGROVE - a first-person 3D horror roguelike, written in Volt
//
//  You are trapped in an elevator in an abandoned underground facility.
//  Every time the doors open you step onto a freshly generated floor.
//  Find the 3 energy cells, get back to the elevator, ride down.
//  Something lives down here, and every floor it gets faster.
//
//  W A S D   walk              mouse (click first)   look   (or the arrow keys)
//  SHIFT     sprint (loud!)    E                     hide in a locker / call the elevator
//  M         music on/off      ENTER                 start / try again
//
//  Units: 1 = 1 cm in the 3D world. Positions are kept in millimetres (x10) so slow
//  movement stays smooth with whole numbers.
// =====================================================================
#html
title "Ashgrove"
canvas 320, 180
world3d "#020203" fog 2600 ambient 6 shadows
image hbI = "hotbar_icons.png"
sprite icRadio = hbI at 0, 0 size 24, 24
sprite icCan = hbI at 24, 0 size 24, 24
sprite icAxe = hbI at 48, 0 size 24, 24
sprite icKey = hbI at 72, 0 size 24, 24
sprite icSmoke = hbI at 96, 0 size 24, 24
model3d raiderM = "models/raider2.glb"
model3d hunterM = "models/hunter.glb"
model3d radioM = "models/radio.glb"
model3d drinkM = "models/drink_red.glb"
model3d tableM = "models/s_table.glb"
model3d compM = "models/s_computer.glb"
model3d gateM = "models/k_gate_door.glb"
model3d lockM = "models/s_container_tall.glb"
model3d tableL = "models/s_table_large.glb"
model3d axeM = "models/axe.glb"
model3d brawlM = "models/coworker_red.glb"
model3d ninjaM = "models/ninja.glb"
model3d barM = "models/s_structure_barrier.glb"
model3d wideM = "models/s_container_wide.glb"
model3d ringM = "models/s_pipe_ring.glb"
model3d scoutM = "models/coworker_cyan.glb"
model3d engM = "models/coworker_gold.glb"
model3d termM = "models/s_computer_wide.glb"

// ---------- the map ----------
let TS = 160                 // one tile is 160 cm wide
let MW = 26
let MH = 20
let grid = []                // 0 floor, 1 wall, 2 locker, 3 elevator
let dist = []                // distance-to-target for the monster's pathfinding
let queue = []
let rx = []                  // rooms: top-left tile and size
let ry = []
let rw = []
let rh = []
let lkx = []                 // lockers: the wall tile each one is built into
let lky = []
let cellX = []               // energy cells (millimetres)
let cellZ = []
let cellGot = []
let cellId = []
let cellLamp = []
let ex = 0                   // the elevator's wall tile
let ey = 0

// ---------- game state ----------
let state = 0                // 0 title, 1 playing, 2 caught, 3 riding, 4 escaped
let floor = 1
let best = saved("omf_best", 1)
let bank = saved("omf_bank", 80)        // money kept between runs
let cls = saved("omf_cls", 0)           // 0 scout, 1 engineer, 2 brawler
let loreFound = saved("omf_lore", 0)
let t = 0
let cells = 0                // cells installed in the charger
let carry = 0                // cells you are carrying
let chX = 0                  // the charging station (mm)
let chZ = 0
let chSlot = []
let chRed = []
let chGrn = []
let scanT = 0
let chLamp = 0
let px = 0                   // player position in mm
let pz = 0
let yaw = 1800               // tenths of a degree
let pitch = 0
let stam = 600
let tired = 0
let hidden = 0
let hideIdx = 0
let hideCool = 0
let seenHiding = 0
let hideDanger = 0
let stepAcc = 0
let bob = 0
let msg = ""
let msgT = 0
let fadeIn = 90
let rideT = 0
let deadT = 0
let won = 0
let musicOn = 1
let doorOpen = 0

// ---------- map, guide arrows, workstation, desks, flickering lights ----------
let explored = []            // tiles you have seen (for the map)
let eMap = []                // path distance to the elevator, and to each cell
let c0Map = []
let c1Map = []
let c2Map = []
let showMap = 0
let scanned = 0              // the workstation has marked the cells
let termX = 0                // the workstation (mm)
let termZ = 0
let deskX = []               // desks you can search
let deskZ = []
let deskDone = []
let dropKind = []            // 1 light emitter, 2 energy drink
let dropX = []
let dropZ = []
let dropId = []
let dropGot = []
let emitN = 1
let drinkN = 0
let emitId = 0
let emitLamp = 0
let emitT = 0
let emitFocus = 0
let flLamp = []
let flPanel = []
let flT = []
let menace = 0               // how much pressure the creature puts on you (the director watches this)
let breather = 0             // frames the creature is kept away after a long chase
let nudgeT = 0
let trackerOn = 1
let beepT = 0
let noiseLvl = 0

// ---------- the creature ----------
let mx = 0                   // position in mm
let mz = 0
let myaw = 0
let mstate = 0               // 0 patrol, 1 chase, 2 investigate, 3 sniff
let mtimer = 0
let mlost = 0
let mgoalX = 0               // tile the monster is heading for
let mgoalY = 0
let mpath = 0
let rolled = 0
let hbT = 0
let alertCool = 0
let monId = []
let monOx = []
let monOy = []
let monOz = []
let monLamp = 0
let hunterId = 0
let keyN = 0                 // keycards in your pocket
let crowbar = 0
let hp = 3
let hpMax = 3
let hurtT = 0
let swingT = 0
let buyE = 0                 // what you bought in the loadout screen
let buyD = 0
let buyK = 0
let buyC = 0
let buyH = 0
let loreData = []
let loreOpen = 0
let loreView = 0
let doorTx = []              // locked doors (tile)
let doorTy = []
let doorId = []
let doorRoom = []
let deskRoom = []
let anyChase = 0
let lockTmp = []
let lockRoom = 0 - 1
let cardDesk = 0 - 1
let raidFloor = 0            // every fifth floor raiders hold the level and the creature stays away
let rX = []
let rZ = []
let rHp = []
let rStun = []
let rYaw = []
let rId = []
let rAnim = []
let rMode = []
let rLost = []
let rPath = 0
let gateId = 0
let gateWas = 0
let slotFlash = 0
let slotKind = 0
let loreMax = 16
let introSeen = saved("omf_intro", 0)
let cutT = 0
let cutIdx = 0
let lookT = 0
let seenRun = 0
let lobChar = []
let cardT = 0
let upL = []                 // permanent upgrades (saved): 0 thick skin, 1 soft soles, 2 quick hands, 3 lucky finder, 4 deep pockets
let cdDone = []              // redeemed codes (saved)
let upOpen = 0
let codeOpen = 0
let codeBuf = ""
let codeMsg = ""
let dropLamp = []
let smokeN = 0
let smokeT = 0
let smokeId = 0
let buyS = 0
let roleOf = []               // 0 plain, 1 engine room, 2 boiler room, 3 server room
let roleSeen = 0
let stX = []                 // lobby stations (mm)
let stZ = []
let stK = []                 // 0-2 class, 3-7 shop, 8 drop in
let lobLamp = []
let lobNear = 0 - 1
let hanim = 9
let elevRed = 0
let elevGreen = 0
let elevInd = 0
let doorL = 0
let doorR = 0

// ---------- lore cards (title + five lines each) ----------
fn loreAdd(a1, b1, c1, d1, e1, f1) {
  add a1 to loreData
  add b1 to loreData
  add c1 to loreData
  add d1 to loreData
  add e1 to loreData
  add f1 to loreData
}

fn loreInit() {
  loreData = []
  loreAdd("LOG 01 - ASHGROVE", "Facility Ashgrove was built to hold the", "deep survey crew. Six floors, one lift.", "Power comes from sealed energy cells.", "Surface lost contact in March.", "")
  loreAdd("LOG 02 - THE LIFT", "The lift only runs when three cells sit", "in the charging table. We wired it that", "way on purpose. Nobody wanted it to", "leave by accident.", "")
  loreAdd("NOTE - NIGHT SHIFT", "Heard it again at 3 AM. It does not look", "for you. It listens. Boots on metal, a", "dropped cup, a breath too loud.", "Stand still and it forgets you.", "")
  loreAdd("MEMO - DECOY RADIOS", "Requisition approved: noisemakers.", "Leave one playing and walk the other", "way. It always goes to the sound.", "It cannot tell a radio from a person.", "")
  loreAdd("LOG 05 - KEYCARDS", "Vault rooms are card-locked. Cells and", "supplies live inside. Cards were split", "between desks so no single person", "could empty a vault alone.", "")
  loreAdd("NOTE - RAIDERS", "Scavengers follow the lift shaft down.", "Every fifth floor they hold the halls.", "Whatever lives here keeps away from", "them. Be quicker. Swing first.", "")
  loreAdd("LOG 07 - DR. IMANI", "I think it was one of us. The badge in", "its nest still scans. Employee 0417.", "I am not writing the name down.", "", "")
  loreAdd("DIARY - MARCUS", "If you read this, do not run. Running is", "loud. Walk. Hide when you hear it close.", "The lockers bolt from the inside", "for a reason.", "")
  loreAdd("LOG 09 - DEPTH", "The floors are never the same twice.", "Every descent the facility rebuilds", "itself. I stopped counting at forty.", "The lift never reaches the bottom.", "")
  loreAdd("LOG 11 - BOILER ROOM", "Pressure never drops down here. The", "boilers roar so loud the whole floor", "goes deaf. Even it cannot hear you", "over them. Stay close to the steam.", "")
  loreAdd("LOG 12 - ENGINE ROOM", "The engine feeds the lift cables. Chief", "says it hums one note. It has been", "getting lower every week, as if", "something breathes in time with it.", "")
  loreAdd("SERVER LOG - RACK 7", "Every badge scan is still being logged.", "Employee 0417 walks the same loop.", "Tonight the loop changed. It now", "ends at the elevator.", "")
  loreAdd("NOTE - SMOKE", "Thermite smoke hides body heat and mutes", "footsteps. The assassins the surface", "hired used it. None of them came", "back up either.", "")
  loreAdd("MEMO - THE NINJAS", "Contractors in black. They never took", "the lift. They came down the shaft in", "silence. The creature walked past one", "and did not even turn its head.", "")
  loreAdd("LOG 16 - OPEN FLOOR", "We left a message on the servers for", "whoever came next. It reads: the lift", "is not an exit. Find the cells.", "Keep them safe. Keep going.", "")
  loreAdd("FINAL LOG", "There is no exit at the bottom. The lift", "was only ever meant to bring things", "down. If you are reading this:", "one more floor. Then one more.", "")
}

// ---------- helpers ----------
fn dst(ax, ay, bx, by) {
  let dx = abs(ax - bx)
  let dy = abs(ay - by)
  return max(dx, dy) + min(dx, dy) * 4 / 10
}

fn tileAt(tx, ty) {
  if tx < 0 or ty < 0 or tx >= MW or ty >= MH {
    return 1
  }
  return grid[ty * MW + tx]
}

fn isSolid(tx, ty) {
  if tileAt(tx, ty) == 0 {
    return 0
  }
  return 1
}

fn blocked(x, y, r) {
  if isSolid((x - r) / 1600, (y - r) / 1600) == 1 {
    return 1
  }
  if isSolid((x + r) / 1600, (y - r) / 1600) == 1 {
    return 1
  }
  if isSolid((x - r) / 1600, (y + r) / 1600) == 1 {
    return 1
  }
  if isSolid((x + r) / 1600, (y + r) / 1600) == 1 {
    return 1
  }
  return 0
}

// can (x0, y0) see (x1, y1) without a wall in between? (millimetres)
fn los(x0, y0, x1, y1) {
  let d = dst(x0, y0, x1, y1)
  let n = d / 400 + 1
  for i from 1 to n {
    let sx = x0 + (x1 - x0) * i / n
    let sy = y0 + (y1 - y0) * i / n
    if isSolid(sx / 1600, sy / 1600) == 1 {
      return 0
    }
  }
  return 1
}

fn say(text1, frames) {
  msg = text1
  msgT = frames
}

// ---------- making a floor ----------
fn placeRooms() {
  rx = []
  ry = []
  rw = []
  rh = []
  let tries = 0
  while length(rx) < 7 and tries < 400 {
    tries += 1
    let w = random(4, 7)
    let h = random(4, 6)
    let x = random(1, MW - w - 1)
    let y = random(2, MH - h - 1)
    let ok = 1
    let i = 0
    while i < length(rx) {
      if x < rx[i] + rw[i] + 2 and x + w + 2 > rx[i] and y < ry[i] + rh[i] + 2 and y + h + 2 > ry[i] {
        ok = 0
      }
      i += 1
    }
    if ok == 1 {
      add x to rx
      add y to ry
      add w to rw
      add h to rh
    }
  }
}

fn corridor(ax, ay, bx, by) {
  for cx from ax to bx {
    grid[ay * MW + cx] = 0
  }
  for cy from ay to by {
    grid[cy * MW + bx] = 0
  }
}

fn makeMap() {
  grid = []
  dist = []
  for i from 1 to MW * MH {
    add 1 to grid
    add 9999 to dist
  }
  placeRooms()
  while length(rx) < 5 {
    placeRooms()
  }
  let n = length(rx)
  for r from 0 to n - 1 {
    for yy from ry[r] to ry[r] + rh[r] - 1 {
      for xx from rx[r] to rx[r] + rw[r] - 1 {
        grid[yy * MW + xx] = 0
      }
    }
  }
  for r from 1 to n - 1 {
    corridor(rx[r - 1] + rw[r - 1] / 2, ry[r - 1] + rh[r - 1] / 2, rx[r] + rw[r] / 2, ry[r] + rh[r] / 2)
  }
  // one extra loop so there is always a second way round
  let a = random(0, n - 1)
  let b = random(0, n - 1)
  if a != b {
    corridor(rx[a] + rw[a] / 2, ry[a] + rh[a] / 2, rx[b] + rw[b] / 2, ry[b] + rh[b] / 2)
  }
  // the elevator sits in the north wall of room 0
  ex = rx[0] + rw[0] / 2
  ey = ry[0] - 1
  let k = 0
  while grid[ey * MW + ex] != 1 and k < rw[0] {
    ex = rx[0] + k
    k += 1
  }
  grid[ey * MW + ex] = 3
  // lockers in the other north walls
  lkx = []
  lky = []
  for r from 0 to n - 1 {
    if random(1, 100) <= 75 or r == 1 {
      let lx = rx[r] + random(0, rw[r] - 1)
      let ly = ry[r] - 1
      if grid[ly * MW + lx] == 1 and not (lx == ex and ly == ey) {
        grid[ly * MW + lx] = 2
        add lx to lkx
        add ly to lky
      }
    }
  }
}

fn placeThings() {
  let n = length(rx)
  // start in the middle of room 0, facing into the room (the elevator is behind you)
  px = (rx[0] + rw[0] / 2) * 1600 + 800
  pz = (ry[0] + 1) * 1600 + 800
  yaw = 1800
  pitch = 0
  termX = (rx[0] + rw[0] - 1) * 1600 + 800
  termZ = (ry[0] + 1) * 1600 + 800
  // the creature starts in the room farthest from the elevator
  let far = 1
  let fd = 0
  for r from 1 to n - 1 {
    let d = dst(rx[r] + rw[r] / 2, ry[r] + rh[r] / 2, rx[0] + rw[0] / 2, ry[0] + rh[0] / 2)
    if d > fd {
      fd = d
      far = r
    }
  }
  mx = (rx[far] + rw[far] / 2) * 1600 + 800
  mz = (ry[far] + rh[far] / 2) * 1600 + 800
  // three cells, each in a different room (never the creature's own room, never the elevator room)
  let cand = []
  for r from 1 to n - 1 {
    if r != far {
      add r to cand
    }
  }
  cellX = []
  cellZ = []
  cellGot = []
  for c from 0 to 2 {
    let k = random(0, length(cand) - 1)
    let r2 = cand[k]
    remove cand[k]
    let cxv = (rx[r2] + random(0, rw[r2] - 1)) * 1600 + 800
    let czv = (ry[r2] + random(0, rh[r2] - 1)) * 1600 + 800
    add cxv to cellX
    add czv to cellZ
    add 0 to cellGot
  }
  myaw = 0
  mstate = 0
  mtimer = 0
  mlost = 0
  pickWaypoint()
}

fn pickWaypoint() {
  let r = random(0, length(rx) - 1)
  mgoalX = rx[r] + rw[r] / 2
  mgoalY = ry[r] + rh[r] / 2
  bfs(mgoalX, mgoalY)
}

// ---------- vault rooms with keycard doors ----------
fn clearDoors() {
  doorTx = []
  doorTy = []
  doorId = []
  doorRoom = []
  lockRoom = 0 - 1
  cardDesk = 0 - 1
}

fn markDoor(x, y, r) {
  if tileAt(x, y) == 0 {
    grid[y * MW + x] = 4
    add x to doorTx
    add y to doorTy
    add r to doorRoom
    add 0 to doorId
  }
}

fn undoDoors() {
  let i = 0
  while i < length(doorTx) {
    grid[doorTy[i] * MW + doorTx[i]] = 0
    i += 1
  }
  clearDoors()
}

fn roomOfCell(c) {
  let cx1 = cellX[c] / 1600
  let cy1 = cellZ[c] / 1600
  let found = 0 - 1
  for r from 0 to length(rx) - 1 {
    if cx1 >= rx[r] and cx1 < rx[r] + rw[r] and cy1 >= ry[r] and cy1 < ry[r] + rh[r] {
      found = r
    }
  }
  return found
}

// can you still walk from the start to the elevator and every other room?
fn allReachable(skip) {
  lockTmp = []
  for i from 1 to MW * MH {
    add 9999 to lockTmp
  }
  bfsMap(lockTmp, px / 1600, pz / 1600)
  if lockTmp[(ey + 1) * MW + ex] >= 9999 {
    return 0
  }
  for r from 0 to length(rx) - 1 {
    if r != skip {
      if lockTmp[(ry[r] + rh[r] / 2) * MW + rx[r] + rw[r] / 2] >= 9999 {
        return 0
      }
    }
  }
  return 1
}

fn setupLocks() {
  clearDoors()
  if floor < 2 or raidFloor == 1 {
    return 0
  }
  if random(1, 100) > 65 {
    return 0
  }
  let tries = 0
  while tries < 3 and lockRoom < 0 {
    tries += 1
    let r = roomOfCell(random(0, 2))
    if r > 0 {
      for xx from rx[r] to rx[r] + rw[r] - 1 {
        markDoor(xx, ry[r] - 1, r)
        markDoor(xx, ry[r] + rh[r], r)
      }
      for yy from ry[r] to ry[r] + rh[r] - 1 {
        markDoor(rx[r] - 1, yy, r)
        markDoor(rx[r] + rw[r], yy, r)
      }
      if length(doorTx) > 0 and allReachable(r) == 1 {
        lockRoom = r
      } else {
        undoDoors()
      }
    }
  }
}

fn nearDoor() {
  let found = 0 - 1
  let i = 0
  while i < length(doorTx) {
    if grid[doorTy[i] * MW + doorTx[i]] == 4 and dst(px, pz, doorTx[i] * 1600 + 800, doorTy[i] * 1600 + 800) < 1700 {
      found = i
    }
    i += 1
  }
  return found
}

fn openVault(r) {
  let i = 0
  while i < length(doorTx) {
    if doorRoom[i] == r and grid[doorTy[i] * MW + doorTx[i]] == 4 {
      grid[doorTy[i] * MW + doorTx[i]] = 0
      anim3d doorId[i], "open"
    }
    i += 1
  }
  keyN -= 1
  lockRoom = 0 - 1
  bfsMap(c0Map, cellX[0] / 1600, cellZ[0] / 1600)
  bfsMap(c1Map, cellX[1] / 1600, cellZ[1] / 1600)
  bfsMap(c2Map, cellX[2] / 1600, cellZ[2] / 1600)
  tone 520 for 80ms
  tone 780 for 140ms
  say("VAULT UNLOCKED", 140)
}

// ---------- guide arrows and the map ----------
fn bfsMap(arr, gx, gy) {
  let n = MW * MH
  let i = 0
  while i < n {
    arr[i] = 9999
    i += 1
  }
  let q = [gy * MW + gx]
  arr[gy * MW + gx] = 0
  let head = 0
  while head < length(q) {
    let cur = q[head]
    head += 1
    let cxx = cur % MW
    let cyy = cur / MW
    let d1 = arr[cur] + 1
    if cxx > 0 and arr[cur - 1] > d1 and isSolid(cxx - 1, cyy) == 0 {
      arr[cur - 1] = d1
      add cur - 1 to q
    }
    if cxx < MW - 1 and arr[cur + 1] > d1 and isSolid(cxx + 1, cyy) == 0 {
      arr[cur + 1] = d1
      add cur + 1 to q
    }
    if cyy > 0 and arr[cur - MW] > d1 and isSolid(cxx, cyy - 1) == 0 {
      arr[cur - MW] = d1
      add cur - MW to q
    }
    if cyy < MH - 1 and arr[cur + MW] > d1 and isSolid(cxx, cyy + 1) == 0 {
      arr[cur + MW] = d1
      add cur + MW to q
    }
  }
}

fn buildGuides() {
  explored = []
  eMap = []
  c0Map = []
  c1Map = []
  c2Map = []
  for i from 1 to MW * MH {
    add 0 to explored
    add 9999 to eMap
    add 9999 to c0Map
    add 9999 to c1Map
    add 9999 to c2Map
  }
  bfsMap(eMap, ex, ey + 1)
  bfsMap(c0Map, cellX[0] / 1600, cellZ[0] / 1600)
  bfsMap(c1Map, cellX[1] / 1600, cellZ[1] / 1600)
  bfsMap(c2Map, cellX[2] / 1600, cellZ[2] / 1600)
  scanned = 0
  scanT = 0
  showMap = 0
}

// which way to walk to reach the goal this map leads to: 0 east, 1 south, 2 west, 3 north, -1 there
fn stepDir(arr) {
  let tx = px / 1600
  let ty = pz / 1600
  let goDir = 0 - 1
  let bd = arr[ty * MW + tx]
  if tx < MW - 1 and isSolid(tx + 1, ty) == 0 and arr[ty * MW + tx + 1] < bd {
    bd = arr[ty * MW + tx + 1]
    goDir = 0
  }
  if ty < MH - 1 and isSolid(tx, ty + 1) == 0 and arr[(ty + 1) * MW + tx] < bd {
    bd = arr[(ty + 1) * MW + tx]
    goDir = 1
  }
  if tx > 0 and isSolid(tx - 1, ty) == 0 and arr[ty * MW + tx - 1] < bd {
    bd = arr[ty * MW + tx - 1]
    goDir = 2
  }
  if ty > 0 and isSolid(tx, ty - 1) == 0 and arr[(ty - 1) * MW + tx] < bd {
    bd = arr[(ty - 1) * MW + tx]
    goDir = 3
  }
  return goDir
}

fn arrowGlyph(dir) {
  if dir < 0 {
    return "*"
  }
  let diff = ((dir + 1) % 4) * 900 - yaw
  if diff > 1800 {
    diff -= 3600
  }
  if diff < 0 - 1800 {
    diff += 3600
  }
  if abs(diff) < 450 {
    return "^"
  }
  if abs(diff) > 1350 {
    return "v"
  }
  if diff > 0 {
    return ">"
  }
  return "<"
}

// the unclaimed cell with the shortest walk from here (0..2), or -1
fn nearestCell() {
  let c = (pz / 1600) * MW + px / 1600
  let pick1 = 0 - 1
  let bd = 99999
  if cellGot[0] == 0 and c0Map[c] < bd {
    bd = c0Map[c]
    pick1 = 0
  }
  if cellGot[1] == 0 and c1Map[c] < bd {
    bd = c1Map[c]
    pick1 = 1
  }
  if cellGot[2] == 0 and c2Map[c] < bd {
    bd = c2Map[c]
    pick1 = 2
  }
  if bd >= 9999 {
    return 0 - 2
  }
  return pick1
}

// remember the tiles you can see, for the map
fn exploreFrame() {
  if t % 6 != 0 {
    return 0
  }
  let tx = px / 1600
  let ty = pz / 1600
  for ddy from -3 to 3 {
    for ddx from -3 to 3 {
      let ax = tx + ddx
      let ay = ty + ddy
      if tileAt(ax, ay) == 0 {
        if los(px, pz, ax * 1600 + 800, ay * 1600 + 800) == 1 {
          explored[ay * MW + ax] = 1
        }
      }
    }
  }
}

// overhead lights sometimes flicker; thrown emitters burn out
fn flickerFrame() {
  let i = 0
  while i < length(flT) {
    if flT[i] > 0 {
      flT[i] = flT[i] - 1
      let lit = 1
      if random(1, 100) <= 55 {
        lit = 0
      }
      if flT[i] == 0 {
        lit = 1
      }
      show3d flLamp[i], lit
      show3d flPanel[i], lit
    } else if random(1, 1300) == 1 {
      flT[i] = random(20, 70)
    } else if dst(mx, mz, px, pz) < 5000 and random(1, 160) == 1 {
      flT[i] = random(10, 40)
    }
    i += 1
  }
  // distant sounds keep you on edge, and the floor shudders when the creature is close
  if state == 1 and random(1, 900) == 1 {
    tone 90 to 55 for 500ms
  }
  if state == 1 and dst(mx, mz, px, pz) < 3200 and t % 40 == 0 {
    tone 45 for 120ms
  }
  if emitT > 0 {
    emitT -= 1
    if emitT <= 0 {
      show3d emitId, 0
      show3d emitLamp, 0
    }
  }
}

// the director (the idea behind Alien: Isolation): it watches your menace. When the pressure
// peaks it pulls the creature back to give you a breather. When things stay quiet too long
// it nudges the creature toward your part of the map - but the creature still has to find you itself.
fn directorFrame() {
  if state != 1 or raidFloor == 1 {
    return 0
  }
  let d = dst(mx, mz, px, pz)
  if mstate == 1 and d < 3500 {
    menace += 4
  } else if mstate != 3 and d < 4800 {
    menace += 2
  } else if menace > 0 {
    menace -= 1
  }
  if breather > 0 {
    breather -= 1
  }
  // pressure peaked: back off for a while
  if menace > 1100 and mstate != 1 {
    menace = 0
    breather = 700
    pickWaypoint()
    mstate = 0
    say("IT BACKS OFF... FOR NOW", 120)
  }
  if menace > 1500 {
    menace = 1100
  }
  // too quiet for too long: it drifts toward where you are
  if breather == 0 and menace < 60 and mstate == 0 {
    nudgeT += 1
    if nudgeT > 1100 {
      nudgeT = 0
      mgoalX = px / 1600
      mgoalY = pz / 1600
      bfs(mgoalX, mgoalY)
      mstate = 2
      alertCool = 200
    }
  } else {
    nudgeT = 0
  }
}

// motion tracker (key T): shows the creature while it is moving, beeps faster the closer it is
fn trackerFrame() {
  // how loud you are right now: what the creature can hear
  let nz = 0
  if state == 1 and hidden == 0 and stepAcc > 0 {
    nz = 45
    if held("shift") and tired == 0 {
      nz = 100
    }
  }
  if cls == 0 {
    nz = nz * 65 / 100
  }
  if cls == 3 {
    nz = nz * 35 / 100
  }
  nz = nz * (100 - upL[1] * 10) / 100
  if state == 1 {
    let rl = roleAtPlayer()
    if rl == 2 {
      nz = nz * 45 / 100
    }
    if rl != roleSeen {
      roleSeen = rl
      roleMsg(rl)
    }
  }
  if nz > noiseLvl {
    noiseLvl = nz
  } else if noiseLvl > 0 {
    noiseLvl -= 2
  }
  // the noisemaker plays a tune the creature cannot resist
  if emitT > 0 and emitT % 70 == 0 {
    tone 1320 for 50ms
    tone 990 for 50ms
  }
  if state != 1 or trackerOn == 0 or hidden == 1 {
    return 0
  }
  let d = dst(mx, mz, px, pz)
  if mstate != 3 and d < 7000 {
    beepT += 1
    if beepT > 14 + d / 90 {
      beepT = 0
      tone 1500 for 25ms
    }
  }
}

fn keyKt() {
  if codeOpen == 1 {
    typeCh("t")
    return 0
  }
  trackerOn = 1 - trackerOn
}

when key "t" pressed {
  keyKt()
}


fn spawnDrop(kind, x, z) {
  let item = 0
  let lamp = 0
  if kind == 1 {
    item = put3d(radioM, x / 10, 0, z / 10, 0, 34)
  } else if kind == 2 {
    item = put3d(drinkM, x / 10, 0, z / 10, 0, 26)
  } else if kind == 3 {
    item = block3d(x / 10, 3, z / 10, 16, 5, 9, "#4cb36a")
    glow3d item, "#2f8f4a"
  } else if kind == 4 {
    item = block3d(x / 10, 2, z / 10, 15, 1, 10, "#4de1ff")
    glow3d item, "#4de1ff"
  } else if kind == 6 {
    item = block3d(x / 10, 8, z / 10, 22, 14, 14, "#f2f2f2")
    glow3d item, "#ff3b3b"
    lamp = lamp3d(x / 10, 30, z / 10, "#ff4a4a", 12, 220)
  } else {
    // a lore card stands upright, glowing, with its own little light
    item = block3d(x / 10, 80, z / 10, 22, 30, 2, "#f2e6b0")
    glow3d item, "#ffd23f"
    lamp = lamp3d(x / 10, 90, z / 10, "#ffd23f", 16, 280)
  }
  add lamp to dropLamp
  add kind to dropKind
  add x to dropX
  add z to dropZ
  add item to dropId
  add 0 to dropGot
}

// the workstation scans on its own while you stand close to it
fn scanNeed() {
  if cls == 1 {
    return 45 - upL[2] * 5
  }
  return 90 - upL[2] * 12
}

fn scanFrame() {
  if state != 1 or scanned == 1 {
    return 0
  }
  if hidden == 0 and dst(px, pz, termX, termZ) < 1900 {
    scanT += 1
    if scanT % 12 == 0 {
      tone 900 for 20ms
    }
    if scanT >= scanNeed() {
      scanned = 1
      scanT = 0
      tone 880 for 120ms
      tone 1180 for 160ms
      say("SCAN COMPLETE - CELLS MARKED ON THE MAP", 200)
    }
  } else if scanT > 0 {
    scanT -= 2
    if scanT < 0 {
      scanT = 0
    }
  }
}

fn pickups() {
  let i = 0
  while i < length(dropKind) {
    if dropKind[i] == 5 and dropGot[i] == 0 {
      move3d dropId[i], dropX[i] / 10, 80 + sin(t * 25) * 6 / 1000, dropZ[i] / 10
    }
    i += 1
  }
  i = 0
  while i < length(dropKind) {
    if dropGot[i] == 0 and dst(px, pz, dropX[i], dropZ[i]) < 1000 {
      dropGot[i] = 1
      show3d dropId[i], 0
      if dropLamp[i] > 0 {
        show3d dropLamp[i], 0
      }
      tone 520 for 60ms
      if dropKind[i] == 1 {
        emitN += 1
        say("NOISEMAKER - PRESS 1 TO THROW", 160)
      } else if dropKind[i] == 2 {
        drinkN += 1
        say("ENERGY DRINK - PRESS 2 FOR STAMINA", 160)
      } else if dropKind[i] == 3 {
        let amt = (15 + random(0, 20) + floor * 3) * (100 + upL[3] * 25) / 100
        bank += amt
        save "omf_bank", bank
        say("FOUND $" + amt, 140)
      } else if dropKind[i] == 6 {
        if hp < hpMax {
          hp += 1
          say("MEDKIT - +1 HEART", 140)
        } else {
          hp = hpMax
          say("MEDKIT - ALREADY AT FULL HEALTH", 140)
        }
      } else if dropKind[i] == 4 {
        keyN += 1
        say("KEYCARD - OPENS A LOCKED VAULT DOOR", 180)
      } else {
        if loreFound < loreMax {
          loreFound += 1
          save "omf_lore", loreFound
        }
        loreView = loreFound - 1
        loreOpen = 1
        say("LORE CARD FOUND - PRESS L", 180)
      }
    }
    i += 1
  }
}

// key 1: throw a light emitter - the creature goes to look at it
fn keyK1() {
  if codeOpen == 1 {
    typeCh("1")
    return 0
  }
  if upOpen == 1 {
    buyUp(0)
    return 0
  }
  useEmitter()
}

when key "1" pressed {
  keyK1()
}


fn useEmitter() {
  if state != 1 or hidden == 1 or emitN <= 0 or emitT > 0 {
    return 0
  }
  emitN -= 1
  slotFlash = 18
  slotKind = 1
  let tx = px + sin(yaw) * 2400 / 1000
  let tz = pz - cos(yaw) * 2400 / 1000
  if blocked(tx, tz, 200) == 1 {
    tx = px
    tz = pz
  }
  move3d emitId, tx / 10, 0, tz / 10
  move3d emitLamp, tx / 10, 60, tz / 10
  show3d emitId, 1
  show3d emitLamp, 1
  emitT = 1500
  tone 740 for 80ms
  say("NOISEMAKER PLAYING - IT WILL GO LOOK", 120)
  if mstate != 1 {
    mstate = 2
    emitFocus = 1
    mgoalX = tx / 1600
    mgoalY = tz / 1600
    bfs(mgoalX, mgoalY)
    alertCool = 600
  }
}

// key 4: smoke bomb - the creature loses you for a while
fn keyK4() {
  if codeOpen == 1 {
    typeCh("4")
    return 0
  }
  if upOpen == 1 {
    buyUp(3)
    return 0
  }
  if state == 1 and smokeN > 0 and hidden == 0 and smokeT == 0 {
    smokeN -= 1
    slotFlash = 18
    slotKind = 4
    smokeT = 480
    smokeId = block3d(px / 10, 70, pz / 10, 150, 130, 150, "#8d939e")
    tone 200 to 90 for 300ms
    say("SMOKE - IT CANNOT FIND YOU", 120)
    if mstate == 1 {
      mstate = 0
      mlost = 0
      pickWaypoint()
    }
  }
}

when key "4" pressed {
  keyK4()
}


// key 2: drink an energy drink - full stamina
fn keyK2() {
  if codeOpen == 1 {
    typeCh("2")
    return 0
  }
  if upOpen == 1 {
    buyUp(1)
    return 0
  }
  if state == 1 and drinkN > 0 and stam < 500 {
    drinkN -= 1
    slotFlash = 18
    slotKind = 2
    stam = 600
    tired = 0
    tone 500 for 80ms
    say("ENERGY DRINK", 60)
  }
}

when key "2" pressed {
  keyK2()
}


// ---------- building the 3D scene ----------
fn exposed(tx, ty) {
  if tileAt(tx, ty) == 0 or tileAt(tx, ty) == 4 {
    return 0
  }
  for ddx from -1 to 1 {
    for ddy from -1 to 1 {
      if tileAt(tx + ddx, ty + ddy) == 0 {
        return 1
      }
    }
  }
  return 0
}

fn monsterPart(ox, oy, oz, w, h, d, col) {
  let bid = block3d(0, 0, 0, w, h, d, col)
  add bid to monId
  add ox to monOx
  add oy to monOy
  add oz to monOz
  return bid
}

fn build3d() {
  let n3 = length(rx)
  clear3d
  torch3d 60, 2200
  let sx = MW * TS
  let sz = MH * TS
  let f = block3d(sx / 2, -5, sz / 2, sx, 10, sz, "#555960")
  let c = block3d(sx / 2, 290, sz / 2, sx, 10, sz, "#35373d")
  // walls: runs of wall tiles that touch the walkable space become one long box each
  for ty from 0 to MH - 1 {
    let start = -1
    for tx from 0 to MW {
      let e = 0
      if tx < MW {
        e = exposed(tx, ty)
      }
      if e == 1 and start < 0 {
        start = tx
      }
      if e == 0 and start >= 0 {
        let runLen = tx - start
        let w = block3d((start + tx) * TS / 2, 140, ty * TS + TS / 2, runLen * TS, 280, TS, "#767b85")
        start = -1
      }
    }
  }
  // lockers
  let i = 0
  while i < length(lkx) {
    let lz = lky[i] * TS + TS
    let lxx = lkx[i] * TS + TS / 2
    let body = block3d(lxx, 100, lz - 14, 96, 200, 28, "#46544b")
    let v1 = block3d(lxx, 168, lz + 1, 60, 5, 2, "#0b0d0c")
    let v2 = block3d(lxx, 154, lz + 1, 60, 5, 2, "#0b0d0c")
    let v3 = block3d(lxx, 140, lz + 1, 60, 5, 2, "#0b0d0c")
    let hd = block3d(lxx + 34, 95, lz + 3, 6, 22, 5, "#9aa0a8")
    // a storage canister stands by each locker
    let cn = put3d(lockM, lxx + 90, 0, lz + 50, 0, 100)
    i += 1
  }
  // keycard doors
  let dk = 0
  while dk < length(doorTx) {
    let dyaw = 0
    if tileAt(doorTx[dk] - 1, doorTy[dk]) == 0 or tileAt(doorTx[dk] + 1, doorTy[dk]) == 0 {
      dyaw = 900
    }
    doorId[dk] = put3d(gateM, doorTx[dk] * TS + TS / 2, 0, doorTy[dk] * TS + TS / 2, dyaw, 50)
    anim3d doorId[dk], "close"
    let dl = lamp3d(doorTx[dk] * TS + TS / 2, 230, doorTy[dk] * TS + TS / 2, "#ff3322", 8, 260)
    dk += 1
  }
  // the elevator: a frame, two sliding doors and a status lamp
  let ez = ey * TS + TS
  let exx = ex * TS + TS / 2
  gateId = put3d(gateM, exx, 0, ez - 20, 1800, 50)
  anim3d gateId, "close"
  gateWas = 0
  doorL = block3d(exx, 0 - 500, ez, 1, 1, 1, "#000000")
  doorR = block3d(exx, 0 - 500, ez, 1, 1, 1, "#000000")
  elevInd = block3d(exx, 244, ez + 3, 50, 10, 4, "#300000")
  glow3d elevInd, "#ff2a1a"
  elevRed = lamp3d(exx, 200, ez + 60, "#ff3322", 30, 520)
  elevGreen = lamp3d(exx, 200, ez + 60, "#33ff77", 30, 520)
  show3d elevGreen, 0
  doorOpen = 0
  // the charging station: a console table beside the elevator. Three cradles on top take the cells.
  let cdx = 1
  if ex + 1 >= rx[0] + rw[0] {
    cdx = 0 - 1
  }
  let tabX = (ex + cdx) * 1600 + 800
  let tabZ = (ey + 1) * 1600 + 520
  chX = tabX
  chZ = tabZ + 700
  let ctab = put3d(tableL, tabX / 10, 0, tabZ / 10, 0, 100)
  let cmon = put3d(termM, tabX / 10, 75, tabZ / 10 - 14, 1800, 70)
  chSlot = []
  chRed = []
  chGrn = []
  for k from 0 to 2 {
    let sxk = tabX / 10 - 32 + k * 32
    let pad = block3d(sxk, 76, tabZ / 10 + 8, 22, 2, 22, "#0a0e12")
    let wl1 = block3d(sxk - 11, 84, tabZ / 10 + 8, 2, 14, 22, "#1b222b")
    let wl2 = block3d(sxk + 11, 84, tabZ / 10 + 8, 2, 14, 22, "#1b222b")
    let wl3 = block3d(sxk, 84, tabZ / 10 - 3, 22, 14, 2, "#1b222b")
    let rim = block3d(sxk, 92, tabZ / 10 + 8, 22, 1, 22, "#2a8fb0")
    glow3d rim, "#2a8fb0"
    let sl = block3d(sxk, 86, tabZ / 10 + 8, 12, 20, 12, "#4de1ff")
    glow3d sl, "#4de1ff"
    show3d sl, 0
    add sl to chSlot
    let rd = block3d(sxk, 100, tabZ / 10 - 8, 10, 3, 3, "#ff3322")
    glow3d rd, "#ff3322"
    let gr = block3d(sxk, 100, tabZ / 10 - 8, 10, 3, 3, "#33ff77")
    glow3d gr, "#33ff77"
    show3d gr, 0
    add rd to chRed
    add gr to chGrn
  }
  chLamp = lamp3d(tabX / 10, 140, tabZ / 10, "#4de1ff", 12, 380)
  // energy cells
  cellId = []
  cellLamp = []
  for c2 from 0 to 2 {
    let cb = block3d(cellX[c2] / 10, 110, cellZ[c2] / 10, 22, 34, 22, "#2a8aa8")
    glow3d cb, "#4de1ff"
    add cb to cellId
    add lamp3d(cellX[c2] / 10, 120, cellZ[c2] / 10, "#4de1ff", 18, 450) to cellLamp
  }
  // the creature, built from boxes (forward is +oz)
  monId = []
  monOx = []
  monOy = []
  monOz = []
  hunterId = put3d(hunterM, mx / 10, 0, mz / 10, 0, 112)
  hanim = 9
  monLamp = lamp3d(0, 150, 0, "#ff2211", 10, 340)
  // overhead lights in every room (they sometimes flicker)
  flLamp = []
  flPanel = []
  flT = []
  for r3 from 0 to n3 - 1 {
    let lx3 = (rx[r3] + rw[r3] / 2) * TS + TS / 2
    let lz3 = (ry[r3] + rh[r3] / 2) * TS + TS / 2
    let pl = block3d(lx3, 284, lz3, 120, 4, 30, "#bfe6ff")
    glow3d pl, "#bfe6ff"
    let ll = lamp3d(lx3, 255, lz3, "#cfe0ff", 16, 700)
    add ll to flLamp
    add pl to flPanel
    add 0 to flT
  }
  // the workstation next to the elevator: press E to scan the floor
  let tbody = put3d(termM, termX / 10, 0, termZ / 10, 1800, 100)
  let tl = lamp3d(termX / 10, 130, termZ / 10, "#4de1ff", 12, 380)
  // desks you can search
  deskX = []
  deskZ = []
  deskDone = []
  deskRoom = []
  dropKind = []
  dropLamp = []
  dropX = []
  dropZ = []
  dropId = []
  dropGot = []
  for r4 from 1 to n3 - 1 {
    if r4 <= 5 {
      let dxm = (rx[r4] + random(0, rw[r4] - 1)) * 1600 + 800
      let tries2 = 0
      while tries2 < 12 and (grid[(ry[r4] - 1) * MW + dxm / 1600] != 1 or grid[(ry[r4] - 1) * MW + dxm / 1600 - 1] == 2 or grid[(ry[r4] - 1) * MW + dxm / 1600 + 1] == 2) {
        dxm = (rx[r4] + random(0, rw[r4] - 1)) * 1600 + 800
        tries2 += 1
      }
      let dzm = ry[r4] * 1600 + 380
      add dxm to deskX
      add dzm to deskZ
      add 0 to deskDone
      add r4 to deskRoom
      let db = put3d(tableM, dxm / 10, 0, dzm / 10, 0, 100)
      let dm = put3d(compM, dxm / 10, 75, dzm / 10, 1800, 100)
    }
  }
  // one desk (outside the vault) holds the keycard
  cardDesk = 0 - 1
  if lockRoom >= 0 and length(deskX) > 0 {
    let ct = 0
    while cardDesk < 0 and ct < 30 {
      ct += 1
      let cd = random(0, length(deskX) - 1)
      if deskRoom[cd] != lockRoom {
        cardDesk = cd
      }
    }
  }
  emitId = put3d(radioM, 0, 0, 0, 0, 34)
  emitLamp = lamp3d(0, 0, 0, "#4de1ff", 45, 1300)
  show3d emitId, 0
  show3d emitLamp, 0
  emitT = 0
  spawnRaiders()
  placeMonster()
}

fn placeMonster() {
  let s = sin(myaw)
  let co = cos(myaw)
  move3d hunterId, mx / 10, 0, mz / 10
  turn3d hunterId, myaw + 1800
  let wantA = 0
  if mstate == 1 {
    wantA = 1
  } else if mstate == 3 {
    wantA = 2
  }
  if wantA != hanim {
    hanim = wantA
    if wantA == 0 {
      anim3d hunterId, "walk"
    } else if wantA == 1 {
      anim3d hunterId, "sprint"
    } else {
      anim3d hunterId, "idle"
    }
  }
  move3d monLamp, mx / 10, 150, mz / 10
}

// ---------- themed rooms: boiler (loud, masks your steps), engine (cash), server (log cards) ----------
fn assignRoles() {
  let n = length(rx)
  roleOf = []
  for r from 0 to n - 1 {
    add 0 to roleOf
  }
  if raidFloor == 1 {
    return 0
  }
  let wi = 0
  let r2 = 1 + random(0, n - 2)
  let k = 0
  while k < n - 1 and wi < 3 {
    let rr = 1 + (r2 + k) % (n - 1)
    k += 1
    if rr != lockRoom and roleOf[rr] == 0 {
      // wi 0 boiler, 1 engine, 2 server (engine and server start on floor 2)
      if wi == 0 {
        roleOf[rr] = 2
      } else if wi == 1 and floor >= 2 {
        roleOf[rr] = 1
      } else if wi == 2 and floor >= 2 {
        roleOf[rr] = 3
      }
      wi += 1
    }
  }
}

fn roleAtPlayer() {
  let tx = px / 1600
  let ty = pz / 1600
  let found = 0
  for r from 0 to length(rx) - 1 {
    if tx >= rx[r] and tx < rx[r] + rw[r] and ty >= ry[r] and ty < ry[r] + rh[r] {
      found = roleOf[r]
    }
  }
  return found
}

fn led(x, y, z, col) {
  let l1 = block3d(x, y, z, 6, 2, 1, col)
  glow3d l1, col
}

fn decorRooms() {
  for r from 0 to length(rx) - 1 {
    let ox = rx[r] * TS
    let oz = ry[r] * TS
    let cx = ox + rw[r] * TS / 2
    let cz = oz + rh[r] * TS / 2 + 30
    if roleOf[r] == 2 {
      // boiler room: big tanks, hot pipes, orange glow
      let b1 = put3d(lockM, cx - 70, 0, cz, 0, 250)
      let b2 = put3d(lockM, cx + 70, 0, cz, 0, 250)
      let bl = lamp3d(cx, 150, cz, "#ff6a1a", 40, 460)
      let bw = lamp3d(cx, 40, cz + 60, "#ff3a00", 30, 300)
      for i from 0 to 2 {
        let px1 = ox + 30 + i * (rw[r] * TS - 60) / 2
        let pp = block3d(px1, 140, oz + rh[r] * TS - 26, 10, 280, 10, "#7a4a2a")
        let vl = block3d(px1, 90, oz + rh[r] * TS - 26, 18, 8, 18, "#c0392b")
      }
      let hp1 = block3d(cx, 262, oz + rh[r] * TS - 26, rw[r] * TS - 40, 10, 10, "#7a4a2a")
      let g1 = block3d(cx, 120, cz - 62, 40, 30, 4, "#1c1c1c")
      glow3d g1, "#ff5a10"
      spawnDrop(6, cx * 10, cz * 10 + 1100)
    }
    if roleOf[r] == 1 {
      // engine room: a humming machine with green rings
      let e1 = put3d(wideM, cx, 0, cz, 0, 300)
      let e2 = put3d(ringM, cx - 120, 0, cz - 40, 0, 300)
      let e3 = put3d(ringM, cx + 120, 0, cz - 40, 900, 300)
      let el = lamp3d(cx, 170, cz + 90, "#33ff77", 40, 460)
      for i from 0 to 3 {
        led(cx - 60 + i * 40, 130 + i * 14, cz + 94, "#33ff77")
      }
      let br = put3d(barM, cx, 0, cz + 130, 0, 100)
      spawnDrop(3, cx * 10 - 400, cz * 10 + 1200)
    }
    if roleOf[r] == 3 {
      // server room: racks line both side walls facing a cold blue aisle, a console at the end
      for side from 0 to 1 {
        for i from 0 to 3 {
          let rz = oz + 110 + i * 62
          let rxp = ox + 34
          let dirn = 1
          if side == 1 {
            rxp = ox + rw[r] * TS - 34
            dirn = 0 - 1
          }
          if rz < oz + rh[r] * TS - 30 {
            let fr = block3d(rxp, 100, rz, 50, 200, 56, "#101216")
            let pn = block3d(rxp + dirn * 25, 100, rz, 2, 188, 50, "#1b1f27")
            for lr from 0 to 7 {
              let ly = 28 + lr * 22
              led(rxp + dirn * 27, ly, rz - 14, "#2a8fff")
              led(rxp + dirn * 27, ly, rz + 2, "#33ff77")
              if (lr + i + side) % 3 == 0 {
                led(rxp + dirn * 27, ly, rz + 16, "#ff3b3b")
              } else {
                led(rxp + dirn * 27, ly, rz + 16, "#2a8fff")
              }
            }
          }
        }
      }
      let aisle = block3d(cx, 1, cz, 40, 1, rh[r] * TS - 100, "#2a8fff")
      glow3d aisle, "#1c6fd0"
      let sl = lamp3d(cx, 160, cz, "#3a9aff", 40, 480)
      let sl2 = lamp3d(cx, 100, cz + 60, "#2a8fff", 30, 360)
      let tt = put3d(termM, cx, 0, oz + rh[r] * TS - 30, 1800, 100)
      let cg = lamp3d(cx, 90, oz + rh[r] * TS - 60, "#4de1ff", 20, 300)
      if loreFound < loreMax {
        spawnDrop(5, cx * 10, cz * 10)
      } else {
        spawnDrop(3, cx * 10, cz * 10)
      }
    }
  }
  // one log card is hidden somewhere on every normal floor
  if raidFloor == 0 and loreFound < loreMax and floor >= 1 {
    let hasSrv = 0
    for q from 0 to length(roleOf) - 1 {
      if roleOf[q] == 3 {
        hasSrv = 1
      }
    }
    if hasSrv == 0 {
      let lr2 = 1 + random(0, length(rx) - 2)
      spawnDrop(5, (rx[lr2] * TS + rw[lr2] * TS / 2) * 10, (ry[lr2] * TS + rh[lr2] * TS / 2 + 40) * 10)
    }
  }
}

fn roleMsg(rl) {
  if rl == 2 {
    say("BOILER ROOM - THE NOISE HIDES YOUR STEPS", 160)
  } else if rl == 1 {
    say("ENGINE ROOM - SOMETHING VALUABLE NEARBY", 160)
  } else if rl == 3 {
    say("SERVER ROOM - A LOG CARD IS HERE", 160)
  }
}

fn newFloor() {
  raidFloor = 0
  if floor % 5 == 0 {
    raidFloor = 1
  }
  makeMap()
  placeThings()
  if raidFloor == 1 {
    mx = 0 - 90000
    mz = 0 - 90000
    mstate = 3
  }
  setupLocks()
  assignRoles()
  build3d()
  decorRooms()
  smokeT = 0
  roleSeen = 0
  buildGuides()
  cells = 0
  carry = 0
  hp = hpMax
  hurtT = 0
  swingT = 0
  anyChase = 0
  hidden = 0
  stam = 600
  tired = 0
  msg = ""
  msgT = 0
  fadeIn = 90
  cardT = 260
  mpath = 0
  bestCheck()
  if raidFloor == 1 {
    say("RAIDERS HOLD THIS FLOOR - THE CREATURE STAYS AWAY", 260)
  } else if floor == 1 {
    say("FIND 3 ENERGY CELLS", 240)
  } else if lockRoom >= 0 {
    say("FLOOR " + floor + " - A VAULT IS LOCKED", 200)
  } else {
    say("FLOOR " + floor, 150)
  }
}

fn bestCheck() {
  if floor > best {
    best = floor
    save "omf_best", best
  }
}

// ---------- pathfinding for the creature ----------
fn bfs(gx, gy) {
  let n = MW * MH
  let i = 0
  while i < n {
    dist[i] = 9999
    i += 1
  }
  queue = []
  dist[gy * MW + gx] = 0
  add gy * MW + gx to queue
  let head = 0
  while head < length(queue) {
    let cur = queue[head]
    head += 1
    let cxx = cur % MW
    let cyy = cur / MW
    let d1 = dist[cur] + 1
    if cxx > 0 and dist[cur - 1] > d1 and isSolid(cxx - 1, cyy) == 0 {
      dist[cur - 1] = d1
      add cur - 1 to queue
    }
    if cxx < MW - 1 and dist[cur + 1] > d1 and isSolid(cxx + 1, cyy) == 0 {
      dist[cur + 1] = d1
      add cur + 1 to queue
    }
    if cyy > 0 and dist[cur - MW] > d1 and isSolid(cxx, cyy - 1) == 0 {
      dist[cur - MW] = d1
      add cur - MW to queue
    }
    if cyy < MH - 1 and dist[cur + MW] > d1 and isSolid(cxx, cyy + 1) == 0 {
      dist[cur + MW] = d1
      add cur + MW to queue
    }
  }
}

// the neighbouring tile that is closest to the goal
fn nextTile() {
  let tx = mx / 1600
  let ty = mz / 1600
  let best1 = ty * MW + tx
  let bd = dist[best1]
  if tx > 0 and dist[best1 - 1] < bd {
    bd = dist[best1 - 1]
    best1 = ty * MW + tx - 1
  }
  if tx < MW - 1 and dist[ty * MW + tx + 1] < bd {
    bd = dist[ty * MW + tx + 1]
    best1 = ty * MW + tx + 1
  }
  if ty > 0 and dist[(ty - 1) * MW + tx] < bd {
    bd = dist[(ty - 1) * MW + tx]
    best1 = (ty - 1) * MW + tx
  }
  if ty < MH - 1 and dist[(ty + 1) * MW + tx] < bd {
    bd = dist[(ty + 1) * MW + tx]
    best1 = (ty + 1) * MW + tx
  }
  return best1
}

// move towards a point, sliding along walls
fn moveMon(gx, gz, spd) {
  let d = dst(mx, mz, gx, gz)
  if d < 1 {
    return 0
  }
  let nx = mx
  let nz = mz
  if d <= spd {
    nx = gx
    nz = gz
  } else {
    nx = mx + (gx - mx) * spd / d
    nz = mz + (gz - mz) * spd / d
  }
  if blocked(nx, nz, 300) == 0 {
    mx = nx
    mz = nz
  } else if blocked(nx, mz, 300) == 0 {
    mx = nx
  } else if blocked(mx, nz, 300) == 0 {
    mz = nz
  }
  myaw = atan2(gx - mx, mz - gz)
  return 1
}

fn followPath(spd) {
  let nt = nextTile()
  moveMon((nt % MW) * 1600 + 800, (nt / MW) * 1600 + 800, spd)
}

// ---------- raiders (every fifth floor) ----------
fn nextTileXZ(x, z) {
  let tx = x / 1600
  let ty = z / 1600
  let best1 = ty * MW + tx
  let bd = dist[best1]
  if tx > 0 and dist[best1 - 1] < bd {
    bd = dist[best1 - 1]
    best1 = ty * MW + tx - 1
  }
  if tx < MW - 1 and dist[ty * MW + tx + 1] < bd {
    bd = dist[ty * MW + tx + 1]
    best1 = ty * MW + tx + 1
  }
  if ty > 0 and dist[(ty - 1) * MW + tx] < bd {
    bd = dist[(ty - 1) * MW + tx]
    best1 = (ty - 1) * MW + tx
  }
  if ty < MH - 1 and dist[(ty + 1) * MW + tx] < bd {
    bd = dist[(ty + 1) * MW + tx]
    best1 = (ty + 1) * MW + tx
  }
  return best1
}

fn moveR(i, gx, gz, spd) {
  let d = dst(rX[i], rZ[i], gx, gz)
  if d < 1 {
    return 0
  }
  let nx = gx
  let nz = gz
  if d > spd {
    nx = rX[i] + (gx - rX[i]) * spd / d
    nz = rZ[i] + (gz - rZ[i]) * spd / d
  }
  if blocked(nx, nz, 300) == 0 {
    rX[i] = nx
    rZ[i] = nz
  } else if blocked(nx, rZ[i], 300) == 0 {
    rX[i] = nx
  } else if blocked(rX[i], nz, 300) == 0 {
    rZ[i] = nz
  }
  rYaw[i] = atan2(gx - rX[i], rZ[i] - gz)
  return 1
}

fn setRAnim(i, a) {
  if rAnim[i] == a {
    return 0
  }
  rAnim[i] = a
  if a == 1 {
    anim3d rId[i], "sprint"
  } else if a == 2 {
    anim3d rId[i], "attack-melee-right"
  } else {
    anim3d rId[i], "idle"
  }
}

fn spawnRaiders() {
  rX = []
  rZ = []
  rHp = []
  rStun = []
  rYaw = []
  rId = []
  rAnim = []
  rMode = []
  rLost = []
  if raidFloor == 0 {
    return 0
  }
  let n = 2 + floor / 10
  if n > 4 {
    n = 4
  }
  for i from 1 to n {
    let r = random(1, length(rx) - 1)
    let sx1 = (rx[r] + rw[r] / 2) * 1600 + 800 + (i - 1) * 260
    let sz1 = (ry[r] + rh[r] / 2) * 1600 + 800
    add sx1 to rX
    add sz1 to rZ
    add 2 + floor / 10 to rHp
    add 0 to rStun
    add 0 to rYaw
    add 0 to rMode
    add 0 to rLost
    add 9 to rAnim
    let rid = put3d(raiderM, sx1 / 10, 0, sz1 / 10, 0, 65)
    add rid to rId
    anim3d rid, "idle"
  }
}

fn raiderFrame() {
  if raidFloor == 0 or state != 1 {
    return 0
  }
  if hurtT > 0 {
    hurtT -= 1
  }
  if swingT > 0 {
    swingT -= 1
  }
  let lured = 0
  if emitT > 0 and emitFocus == 1 {
    lured = 1
  }
  rPath += 1
  if anyChase == 1 and lured == 0 and rPath >= 8 {
    rPath = 0
    bfs(px / 1600, pz / 1600)
  }
  anyChase = 0
  let spd = 30 + floor
  let i = 0
  while i < length(rId) {
    if rHp[i] > 0 {
      let d = dst(px, pz, rX[i], rZ[i])
      if rStun[i] > 0 {
        rStun[i] -= 1
        setRAnim(i, 0)
      } else {
        let sees = 0
        if hidden == 0 and d < 3800 {
          sees = los(rX[i], rZ[i], px, pz)
        }
        let hears = 0
        if hidden == 0 and noiseLvl > 0 and d < noiseLvl * 70 {
          hears = 1
        }
        if sees == 1 or hears == 1 {
          if rMode[i] == 0 {
            tone 160 to 90 for 200ms
          }
          rMode[i] = 1
          rLost[i] = 0
        } else if rMode[i] == 1 {
          rLost[i] += 1
          if rLost[i] > 360 {
            rMode[i] = 0
          }
        }
        let moving = 0
        if lured == 1 {
          if dst(rX[i], rZ[i], mgoalX * 1600 + 800, mgoalY * 1600 + 800) > 900 {
            let nt = nextTileXZ(rX[i], rZ[i])
            moving = moveR(i, (nt % MW) * 1600 + 800, (nt / MW) * 1600 + 800, spd)
          }
        } else if rMode[i] == 1 {
          anyChase = 1
          if sees == 1 and d < 2600 {
            moving = moveR(i, px, pz, spd)
          } else {
            let nt = nextTileXZ(rX[i], rZ[i])
            moving = moveR(i, (nt % MW) * 1600 + 800, (nt / MW) * 1600 + 800, spd)
          }
        }
        if d < 1100 and hidden == 0 and rMode[i] == 1 {
          setRAnim(i, 2)
          if d < 900 and hurtT == 0 {
            hp -= 1
            hurtT = 80
            tone 120 to 60 for 220ms
            say("HIT!", 60)
            // shove the player away
            let kx = px + (px - rX[i]) * 500 / (d + 1)
            let kz = pz + (pz - rZ[i]) * 500 / (d + 1)
            if blocked(kx, kz, 250) == 0 {
              px = kx
              pz = kz
            }
            if hp <= 0 {
              caught()
            }
          }
        } else if moving == 1 {
          setRAnim(i, 1)
        } else {
          setRAnim(i, 0)
        }
      }
      move3d rId[i], rX[i] / 10, 0, rZ[i] / 10
      turn3d rId[i], rYaw[i] + 1800
    }
    i += 1
  }
}

fn swingCrowbar() {
  if crowbar == 0 or swingT > 0 or state != 1 or hidden == 1 {
    return 0
  }
  swingT = 30
  slotFlash = 14
  slotKind = 3
  tone 220 to 120 for 90ms
  let dmg = 1
  if cls == 2 {
    dmg = 2
  }
  if cls == 3 {
    dmg = 3
  }
  let i = 0
  while i < length(rId) {
    if rHp[i] > 0 {
      let d = dst(px, pz, rX[i], rZ[i])
      let ahead = ((rX[i] - px) * sin(yaw) - (rZ[i] - pz) * cos(yaw)) / 1000
      if d < 1700 and ahead > 0 {
        rHp[i] -= dmg
        rStun[i] = 50
        rMode[i] = 1
        tone 90 for 60ms
        let kx = rX[i] + (rX[i] - px) * 450 / (d + 1)
        let kz = rZ[i] + (rZ[i] - pz) * 450 / (d + 1)
        if blocked(kx, kz, 300) == 0 {
          rX[i] = kx
          rZ[i] = kz
        }
        if rHp[i] <= 0 {
          show3d rId[i], 0
          spawnDrop(3, rX[i], rZ[i])
          say("RAIDER DOWN", 90)
        }
      }
    }
    i += 1
  }
}

// ---------- the creature's brain ----------
fn monsterFrame() {
  if raidFloor == 1 {
    return 0
  }
  let spdPatrol = 16 + floor * 3
  let spdChase = 24 + floor * 6
  // it hunts by SOUND first; it only sees you when you are fairly close
  let sight = 2600 + floor * 150
  let hearRange = noiseLvl * 80 + floor * 60
  if noiseLvl == 0 {
    hearRange = 0
  }
  if smokeT > 0 {
    smokeT -= 1
    sight = 500
    hearRange = hearRange * 25 / 100
    if smokeT == 0 {
      show3d smokeId, 0
    }
  }
  let d = dst(px, pz, mx, mz)
  let sees = 0
  if hidden == 0 and d < sight {
    sees = los(mx, mz, px, pz)
  }
  if alertCool > 0 {
    alertCool -= 1
  }
  // patrolling and investigating can be interrupted
  if mstate == 0 or mstate == 2 or mstate == 3 {
    if sees == 1 {
      mstate = 1
      mlost = 0
      emitFocus = 0
      if seenRun == 0 {
        seenRun = 1
        lookT = 50
      }
      mgoalX = px / 1600
      mgoalY = pz / 1600
      bfs(mgoalX, mgoalY)
      mpath = 0
      tone 180 to 60 for 350ms
      say("IT SEES YOU - RUN", 120)
    } else if hidden == 0 and mstate != 1 {
      // hearing: sprinting is loud, walking is quieter, standing still is silent
      let heard = 0
      if hearRange > 0 and d < hearRange {
        heard = 1
      }
      if d < 1300 {
        heard = 1
      }
      if heard == 1 and alertCool == 0 and emitFocus == 0 {
        mstate = 2
        mgoalX = px / 1600
        mgoalY = pz / 1600
        bfs(mgoalX, mgoalY)
        alertCool = 70
      }
    }
  }

  if mstate == 0 {
    followPath(spdPatrol)
    if dst(mx, mz, mgoalX * 1600 + 800, mgoalY * 1600 + 800) < 500 {
      mstate = 3
      mtimer = 120
      rolled = 1
    }
  } else if mstate == 1 {
    let heardNow = 0
    if hidden == 0 and hearRange > 0 and d < hearRange {
      heardNow = 1
    }
    if sees == 1 or heardNow == 1 {
      mlost = 0
      mgoalX = px / 1600
      mgoalY = pz / 1600
    } else {
      mlost += 1
    }
    mpath += 1
    if mpath >= 8 {
      mpath = 0
      bfs(mgoalX, mgoalY)
    }
    if sees == 1 and d < 5000 {
      moveMon(px, pz, spdChase)
    } else {
      followPath(spdChase)
    }
    // lost you at the last place it saw you: sniff around
    if sees == 0 and dst(mx, mz, mgoalX * 1600 + 800, mgoalY * 1600 + 800) < 600 {
      mstate = 3
      mtimer = 150
      rolled = 0
    }
    if sees == 0 and mlost > 420 {
      mstate = 0
      pickWaypoint()
    }
  } else if mstate == 2 {
    if emitFocus == 1 {
      followPath(spdChase)
    } else {
      followPath((spdPatrol + spdChase) / 2)
    }
    if dst(mx, mz, mgoalX * 1600 + 800, mgoalY * 1600 + 800) < 600 {
      mstate = 3
      mtimer = 110
      if emitFocus == 1 {
        mtimer = 380
        emitFocus = 0
      }
      rolled = 0
    }
  } else if mstate == 3 {
    mtimer -= 1
    myaw += 14
    if myaw >= 3600 {
      myaw -= 3600
    }
    // halfway through sniffing: is somebody in a locker close by?
    if mtimer == 60 and rolled == 0 {
      rolled = 1
      if hidden == 1 {
        let lx = lkx[hideIdx] * 1600 + 800
        let lz = lky[hideIdx] * 1600 + 800 + 1600
        if dst(mx, mz, lx, lz) < 3400 {
          let chance = 30 + floor * 10 + seenHiding * 45
          if chance > 95 {
            chance = 95
          }
          if random(1, 100) <= chance {
            caught()
          }
        }
      }
    }
    if mtimer <= 0 {
      mstate = 0
      pickWaypoint()
    }
  }

  // hiding is not perfectly safe: if it lingers by your locker it can find you
  if state == 1 and hidden == 1 {
    let lkx2 = lkx[hideIdx] * 1600 + 800
    let lkz2 = lky[hideIdx] * 1600 + 800 + 1600
    if dst(mx, mz, lkx2, lkz2) < 1500 {
      hideDanger += 1
      if hideDanger % 50 == 0 {
        tone 70 for 120ms
        let hch = 25 + floor * 8 + seenHiding * 45
        if mstate == 1 {
          hch += 25
        }
        if hch > 95 {
          hch = 95
        }
        if random(1, 100) <= hch {
          caught()
        }
      }
    } else if hideDanger > 0 {
      hideDanger -= 1
    }
  } else {
    hideDanger = 0
  }
  // touching it is the end
  if state == 1 and hidden == 0 and dst(px, pz, mx, mz) < 800 {
    caught()
  }
}

fn caught() {
  if state != 1 {
    return 0
  }
  state = 2
  deadT = 0
  hidden = 0
  torch3d 0, 2200
  tone 900 to 90 for 600ms
  music off
}

// ---------- the player ----------
fn playerFrame() {
  if hideCool > 0 {
    hideCool -= 1
  }
  if hidden == 1 {
    // breathing in the dark: stamina comes back
    stam = min(600, stam + 2)
    return 0
  }
  if lookT > 0 {
    // the first time it sees you: you freeze and turn to face it
    lookT -= 1
    let wd = atan2(mx - px, pz - mz) - yaw
    if wd > 1800 {
      wd -= 3600
    }
    if wd < 0 - 1800 {
      wd += 3600
    }
    yaw += wd / 5
    if lookT % 12 == 0 {
      tone 45 for 160ms
    }
    return 0
  }
  yaw += mousedx() * 3
  pitch -= mousedy() * 3
  pitch = constrain(pitch, 0 - 800, 800)
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
  let spd = 26
  if moving == 1 and held("shift") and stam > 0 and tired == 0 {
    spd = 44
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
  let dx = (sin(yaw) * fwd + cos(yaw) * side) * spd / 1000
  let dz = (0 - cos(yaw) * fwd + sin(yaw) * side) * spd / 1000
  if fwd != 0 and side != 0 {
    dx = dx * 7 / 10
    dz = dz * 7 / 10
  }
  if blocked(px + dx, pz, 260) == 0 {
    px += dx
  }
  if blocked(px, pz + dz, 260) == 0 {
    pz += dz
  }
  if moving == 1 {
    stepAcc += spd
    bob += spd
    if stepAcc > 900 {
      stepAcc = 1
      tone 58 + random(0, 18) for 35ms
    }
  } else {
    stepAcc = 0
  }

  // pick up energy cells
  for c from 0 to 2 {
    if cellGot[c] == 0 and dst(px, pz, cellX[c], cellZ[c]) < 900 {
      cellGot[c] = 1
      carry += 1
      show3d cellId[c], 0
      show3d cellLamp[c], 0
      tone 660 for 70ms
      say("ENERGY CELL - TAKE IT TO THE CHARGER", 150)
    }
  }
}

// put a carried cell into the charging station by the elevator
fn insertCell() {
  carry -= 1
  show3d chSlot[cells], 1
  show3d chRed[cells], 0
  show3d chGrn[cells], 1
  cells += 1
  tone 760 for 90ms
  if cells == 3 {
    tone 880 for 160ms
    say("ELEVATOR POWERED - GET IN", 240)
    show3d elevRed, 0
    show3d elevGreen, 1
    glow3d elevInd, "#22ff66"
    // the surge wakes it up: it comes straight for you
    if mstate != 1 {
      mstate = 2
      mgoalX = px / 1600
      mgoalY = pz / 1600
      bfs(mgoalX, mgoalY)
      alertCool = 600
    }
  } else {
    say("CELL INSTALLED " + cells + " / 3", 120)
  }
}

// something is close: the flashlight misbehaves
fn torchFrame() {
  if hidden == 1 {
    torch3d 16, 2200
    return 0
  }
  let d = dst(px, pz, mx, mz)
  let pw = 60
  if d < 6000 and random(1, 100) <= 18 {
    pw = random(8, 40)
  }
  torch3d pw, 2200
}

// each kind of room has its own sound
fn ambience() {
  if state != 1 {
    return 0
  }
  let rl = roleAtPlayer()
  if rl == 1 and t % 45 == 0 {
    tone 48 for 300ms
  }
  if rl == 2 and t % 30 == 0 {
    tone 2200 + random(0, 400) for 25ms
  }
  if rl == 3 and random(1, 70) == 1 {
    tone 1600 + random(0, 800) for 18ms
  }
  if t % 600 == 0 and random(1, 3) == 1 {
    tone 130 to 70 for 900ms
  }
}

fn heartbeat() {
  let d = dst(px, pz, mx, mz)
  if d < 14000 {
    hbT += 1
    if hbT >= 22 + d / 240 {
      hbT = 0
      tone 60 to 38 for 120ms
    }
  }
}

// ---------- E: hide, leave a locker, call the elevator ----------
fn keyKe() {
  if codeOpen == 1 {
    typeCh("e")
    return 0
  }
  interact()
}

when key "e" pressed {
  keyKe()
}


fn interact() {
  if state == 5 {
    lobbyUse()
    return 0
  }
  if state != 1 {
    return 0
  }
  if hidden == 1 {
    hidden = 0
    hideCool = 30
    px = lkx[hideIdx] * 1600 + 800
    pz = lky[hideIdx] * 1600 + 800 + 1600
    return 0
  }
  if hideCool > 0 {
    return 0
  }
  // a locker close by?
  let i = 0
  while i < length(lkx) {
    let ax = lkx[i] * 1600 + 800
    let az = lky[i] * 1600 + 800 + 1600
    if dst(px, pz, ax, az) < 1500 {
      hidden = 1
      hideIdx = i
      hideCool = 30
      seenHiding = 0
      if mstate == 1 and hidden == 1 and los(mx, mz, px, pz) == 1 and dst(mx, mz, px, pz) < 9000 {
        seenHiding = 1
      }
      yaw = 1800
      pitch = 0
      tone 120 for 60ms
      return 0
    }
    i += 1
  }
  if carry > 0 and dst(px, pz, chX, chZ) < 1700 {
    insertCell()
    return 0
  }
  let dI = 0
  while dI < length(deskX) {
    if deskDone[dI] == 0 and dst(px, pz, deskX[dI], deskZ[dI]) < 1900 {
      deskDone[dI] = 1
      let kind = 3
      let roll = random(1, 100)
      if roll <= 22 {
        kind = 1
      } else if roll <= 42 {
        kind = 2
      } else if roll <= 56 {
        kind = 3
      } else if roll <= 68 {
        kind = 6
      } else if loreFound < loreMax {
        kind = 5
      }
      if dI == cardDesk {
        kind = 4
      }
      spawnDrop(kind, deskX[dI], deskZ[dI] + 800)
      tone 300 for 80ms
      say("YOU FOUND SOMETHING", 100)
      return 0
    }
    dI += 1
  }
  let dn = nearDoor()
  if dn >= 0 {
    if keyN > 0 {
      openVault(doorRoom[dn])
    } else {
      say("LOCKED - FIND A KEYCARD", 140)
      tone 140 for 120ms
    }
    return 0
  }
  // the elevator
  let ax2 = ex * 1600 + 800
  let az2 = ey * 1600 + 800 + 1600
  if dst(px, pz, ax2, az2) < 1700 {
    if cells < 3 {
      say("NO POWER - " + cells + " / 3 CELLS INSTALLED", 150)
      tone 140 for 120ms
    } else {
      if floor >= 5 and won == 0 {
        state = 4
        won = 1
        bestCheck()
        music off
        tone 523 for 120ms
      } else {
        state = 3
        rideT = 0
        tone 440 for 120ms
      }
    }
  }
}

fn startRun() {
  floor = 1
  won = 0
  emitN = buyE
  drinkN = buyD
  keyN = buyK
  crowbar = buyC
  smokeN = buyS
  drinkN += upL[4]
  hpMax = 3 + buyH + upL[0]
  if cls == 0 {
    emitN += 1
  }
  if cls == 1 {
    keyN += 1
  }
  if cls == 2 {
    crowbar = 1
    hpMax = 5 + buyH + upL[0]
  }
  if cls == 3 {
    crowbar = 1
    hpMax = 2 + buyH + upL[0]
    smokeN += 2
  }
  menace = 0
  breather = 0
  seenRun = 0
  state = 1
  newFloor()
}

// ---------- the lobby: walk to a class podium, shop tables, then the elevator ----------
fn addStation(k, x, z) {
  add k to stK
  add x to stX
  add z to stZ
}

fn pedestal(x, z, col) {
  let tb = put3d(tableM, x, 0, z, 0, 140)
  let pad = block3d(x, 1, z + 72, 120, 2, 36, col)
  glow3d pad, col
}

fn lobbyLamps() {
  for c from 0 to 3 {
    show3d lobLamp[c], 0
    if cls == c {
      show3d lobLamp[c], 1
    }
  }
}

fn buildLobby() {
  grid = []
  for i from 1 to MW * MH {
    add 1 to grid
  }
  for yy from 1 to 6 {
    for xx from 1 to 10 {
      grid[yy * MW + xx] = 0
    }
  }
  clear3d
  torch3d 70, 2000
  let fl = block3d(960, -5, 640, 1920, 10, 1280, "#2e2a2a")
  let rug = block3d(960, 0, 640, 700, 1, 500, "#4a1f24")
  let ce = block3d(960, 290, 640, 1920, 10, 1280, "#2b2d33")
  let wn = block3d(960, 140, 80, 1920, 280, 160, "#6d717b")
  let ws = block3d(960, 140, 1200, 1920, 280, 160, "#6d717b")
  let ww = block3d(80, 140, 640, 160, 280, 1280, "#6d717b")
  let we = block3d(1840, 140, 640, 160, 280, 1280, "#6d717b")
  let trim = block3d(960, 12, 166, 1600, 24, 4, "#33363d")
  // warm ceiling lights
  for rowi from 0 to 2 {
    for coli from 0 to 2 {
      let lz = 300 + rowi * 350
      let lx = 320 + coli * 640
      let fx = block3d(lx, 284, lz, 60, 4, 30, "#fff0c8")
      glow3d fx, "#ffe2a0"
      let lp = lamp3d(lx, 250, lz, "#ffd9a0", 30, 520)
    }
  }
  // class podiums along the north wall
  stX = []
  stZ = []
  stK = []
  pedestal(360, 295, "#4de1ff")
  let pr = put3d(radioM, 360, 57, 295, 1800, 34)
  let ch0 = put3d(scoutM, 360, 0, 200, 0, 65)
  anim3d ch0, "idle"
  lobChar = []
  add ch0 to lobChar
  addStation(0, 3600, 3300)
  pedestal(760, 295, "#ffd23f")
  let pc = put3d(compM, 760, 57, 295, 0, 100)
  let ch1 = put3d(engM, 760, 0, 200, 0, 65)
  anim3d ch1, "idle"
  add ch1 to lobChar
  addStation(1, 7600, 3300)
  pedestal(1160, 295, "#ff5a4a")
  let pa = put3d(axeM, 1160, 57, 295, 1800, 40)
  let ch2 = put3d(brawlM, 1160, 0, 200, 0, 65)
  anim3d ch2, "idle"
  add ch2 to lobChar
  addStation(2, 11600, 3300)
  pedestal(1560, 295, "#b04aff")
  let pn = block3d(1560, 58, 295, 22, 1, 22, "#8a1020")
  glow3d pn, "#ff2a3a"
  let ch3 = put3d(ninjaM, 1560, 0, 200, 0, 65)
  anim3d ch3, "idle"
  add ch3 to lobChar
  addStation(9, 15600, 3300)
  lobLamp = []
  add lamp3d(360, 160, 300, "#4de1ff", 20, 300) to lobLamp
  add lamp3d(760, 160, 300, "#ffd23f", 20, 300) to lobLamp
  add lamp3d(1160, 160, 300, "#ff5a4a", 20, 300) to lobLamp
  add lamp3d(1560, 160, 300, "#b04aff", 20, 300) to lobLamp
  lobbyLamps()
  // shop tables along the south wall
  let t1 = put3d(tableM, 240, 0, 1040, 1800, 140)
  let i1 = put3d(radioM, 240, 57, 1040, 1800, 34)
  addStation(3, 2400, 9300)
  let t2 = put3d(tableM, 500, 0, 1040, 1800, 140)
  let i2 = put3d(drinkM, 500, 57, 1040, 0, 26)
  addStation(4, 5000, 9300)
  let t3 = put3d(tableM, 760, 0, 1040, 1800, 140)
  let i3 = block3d(760, 58, 1040, 16, 1, 10, "#4de1ff")
  glow3d i3, "#4de1ff"
  addStation(5, 7600, 9300)
  let t4 = put3d(tableM, 1020, 0, 1040, 1800, 140)
  let i4 = put3d(axeM, 1020, 57, 1040, 1800, 40)
  addStation(6, 10200, 9300)
  let t5 = put3d(tableM, 1280, 0, 1040, 1800, 140)
  let i5 = block3d(1280, 63, 1040, 12, 12, 12, "#ff3b4a")
  glow3d i5, "#ff3b4a"
  addStation(7, 12800, 9300)
  let t6 = put3d(tableM, 1540, 0, 1040, 1800, 140)
  let i6 = block3d(1540, 62, 1040, 14, 10, 14, "#9aa0aa")
  glow3d i6, "#6a707a"
  addStation(10, 15400, 9300)
  // the archive terminal on the west wall: read the log cards you have found
  let at = put3d(termM, 205, 0, 640, 900, 100)
  let al = lamp3d(240, 130, 640, "#e8dcb0", 14, 380)
  addStation(11, 2700, 6400)
  // the upgrade bench (east wall, south) and the code terminal (east wall, north)
  let ub = put3d(tableL, 1780, 0, 950, 2700, 100)
  let ui = block3d(1770, 80, 950, 10, 14, 50, "#ffd23f")
  glow3d ui, "#ffd23f"
  addStation(12, 16700, 9300)
  let ct = put3d(termM, 1795, 0, 300, 2700, 100)
  let cl = lamp3d(1730, 130, 300, "#4de1ff", 14, 380)
  addStation(13, 16700, 3000)
  // the elevator on the east wall: your way down
  let gt = put3d(gateM, 1780, 0, 640, 2700, 50)
  let gi = block3d(1756, 244, 640, 4, 10, 50, "#103010")
  glow3d gi, "#33ff77"
  let gl = lamp3d(1700, 200, 640, "#33ff77", 30, 520)
  addStation(8, 16700, 6400)
}

fn enterLobby() {
  buyE = 0
  buyD = 0
  buyK = 0
  buyC = 0
  buyH = 0
  buyS = 0
  cellGot = []
  add 1 to cellGot
  add 1 to cellGot
  add 1 to cellGot
  buildLobby()
  px = 9600
  pz = 7000
  yaw = 0
  pitch = 0
  hidden = 0
  hp = 3
  stam = 600
  tired = 0
  msg = ""
  msgT = 0
  state = 5
  if musicOn == 1 {
    music "c3 - - - g2 - - - a2 - - - e3 - - -", "c2 - - - - - - - - - - - - - - -" tempo 38
  }
  say("PICK A CLASS - SHOP - THEN DROP IN", 200)
}

fn lobbyFrame() {
  if upOpen == 0 and codeOpen == 0 and loreOpen == 0 {
    playerFrame()
  }
  lobNear = 0 - 1
  let bd = 1700
  for i from 0 to length(stK) - 1 {
    let d = dst(px, pz, stX[i], stZ[i])
    if d < bd {
      bd = d
      lobNear = i
    }
  }
  // the survivors turn to look at you when you come close
  for c from 0 to 3 {
    let cxm = 3600 + c * 4000
    let want = 0
    if dst(px, pz, cxm, 2000) < 3200 {
      want = atan2(px - cxm, 2000 - pz) + 1800
    }
    turn3d lobChar[c], want
  }
  let bobY = sin(bob * 7) * 4 / 1000
  camera3d px / 10, 165 + bobY, pz / 10, yaw + sin(t * 9) * 4 / 1000, pitch + sin(t * 13) * 3 / 1000
}

fn selectClass(c) {
  cls = c
  save "omf_cls", cls
  lobbyLamps()
  tone 500 for 40ms
  say(className(c) + " SELECTED", 80)
}

fn lobbyUse() {
  if upOpen == 1 or codeOpen == 1 {
    closeMenus()
    return 0
  }
  if loreOpen == 1 {
    loreView -= 1
    if loreView < 0 {
      loreOpen = 0
    }
    return 0
  }
  if lobNear < 0 {
    return 0
  }
  let k = stK[lobNear]
  if k <= 2 {
    selectClass(k)
  } else if k == 9 {
    selectClass(3)
  } else if k == 3 {
    shopBuy(20, 0)
  } else if k == 4 {
    shopBuy(15, 1)
  } else if k == 5 {
    shopBuy(30, 2)
  } else if k == 6 {
    shopBuy(25, 3)
  } else if k == 7 {
    shopBuy(20, 4)
  } else if k == 10 {
    shopBuy(20, 5)
  } else if k == 12 {
    upOpen = 1
  } else if k == 13 {
    codeOpen = 1
    codeBuf = ""
    codeMsg = ""
  } else if k == 11 {
    if loreFound == 0 {
      say("NO LOG CARDS YET - SEARCH DESKS, SERVER ROOMS", 160)
    } else {
      loreOpen = 1
      loreView = loreFound - 1
    }
  } else {
    startRun()
    if musicOn == 1 {
      music "e3 - - - - - - - - - - - d#3 - - -", "a1 - - - - - - - - - - - - - - -" tempo 46
    }
  }
}

fn stName(k) {
  if k == 9 {
    return "NINJA"
  }
  if k <= 2 {
    return className(k)
  }
  if k == 3 {
    return "NOISEMAKER  $20"
  }
  if k == 4 {
    return "ENERGY DRINK  $15"
  }
  if k == 5 {
    return "KEYCARD  $30"
  }
  if k == 6 {
    return "FIRE AXE  $25"
  }
  if k == 7 {
    return "EXTRA HEART  $20"
  }
  if k == 10 {
    return "SMOKE BOMB  $20"
  }
  if k == 11 {
    return "ARCHIVE TERMINAL"
  }
  if k == 12 {
    return "UPGRADE BENCH"
  }
  if k == 13 {
    return "CODE TERMINAL"
  }
  return "THE ELEVATOR"
}

fn stDesc(k) {
  if k == 9 {
    return classLine(3, 0) + " - " + classLine(3, 1) + " - " + classLine(3, 2)
  }
  if k <= 2 {
    return classLine(k, 0) + " - " + classLine(k, 1) + " - " + classLine(k, 2)
  }
  if k == 3 {
    return "THROW IT - THE CREATURE GOES TO LOOK"
  }
  if k == 4 {
    return "REFILLS YOUR STAMINA"
  }
  if k == 5 {
    return "OPENS ONE LOCKED VAULT"
  }
  if k == 6 {
    return "SWING AT RAIDERS (KEY 3)"
  }
  if k == 7 {
    return "ONE MORE HEART (MAX 3)"
  }
  if k == 10 {
    return "KEY 4 - IT LOSES YOU FOR 8 SECONDS"
  }
  if k == 11 {
    return "READ YOUR LOG CARDS  " + loreFound + " / " + loreMax
  }
  if k == 12 {
    return "PERMANENT UPGRADES FOR EVERY RUN"
  }
  if k == 13 {
    return "ENTER A SECRET CODE FOR REWARDS"
  }
  return "GO DOWN TO FLOOR 1"
}

fn drawUpgrades() {
  panel(30, 14, 260, 140, "#ffd23f")
  box 31, 15, 258, 138 color "#07090df0"
  write "UPGRADE BENCH" at 40, 21 color "#ffd23f"
  writeR("BANK $" + bank, 280, 21, "#7dff9c")
  for i from 0 to 4 {
    let y = 38 + i * 21
    box 40, y - 2, 240, 19 color "#ffffff0c"
    box 40, y, 12, 10 color "#59606e"
    write "" + (i + 1) at 44, y + 1 color "#ffffff"
    write upName(i) at 58, y color "#e8e2c8"
    write upDesc(i) at 58, y + 9 color "#8c93a3"
    let lv = upL[i]
    let mx2 = upMax(i)
    for pp from 0 to mx2 - 1 {
      let pc = "#2a2f38"
      if pp < lv {
        pc = "#ffd23f"
      }
      box 196 + pp * 10, y + 1, 8, 8 color pc
    }
    if lv >= mx2 {
      writeR("MAX", 276, y + 1, "#7dff9c")
    } else {
      let cc = "#7dff9c"
      if bank < upCost(i) {
        cc = "#5a606c"
      }
      writeR("$" + upCost(i), 276, y + 1, cc)
    }
  }
  write "PRESS 1-5 TO BUY    E: CLOSE" at 160, 142 color "#6f7686" centered
  if msgT > 0 {
    write msg at 160, 160 color "#f2e9c9" centered shadow
  }
}

fn drawCode() {
  panel(50, 40, 220, 86, "#4de1ff")
  box 51, 41, 218, 84 color "#07090df0"
  write "CODE TERMINAL" at 60, 47 color "#4de1ff"
  box 60, 64, 200, 16 color "#10161e"
  box 60, 64, 200, 1 color "#59606e"
  let shown = ""
  for i from 1 to length(codeBuf) {
    shown = shown + "*"
  }
  let cur = ""
  if (t / 20) % 2 == 0 {
    cur = "_"
  }
  write codeBuf + cur at 66, 69 color "#e8e2c8"
  write codeMsg at 160, 90 color "#ffd23f" centered
  write "TYPE A CODE   ENTER: REDEEM" at 160, 104 color "#6f7686" centered
  write "ESC: CLOSE" at 160, 114 color "#6f7686" centered
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

fn stQuote(k) {
  if k == 0 {
    return "WALK. DON'T RUN. IT HEARS EVERYTHING."
  }
  if k == 1 {
    return "THE CHARGER ONLY LIKES THREE CELLS."
  }
  if k == 2 {
    return "IF THE RAIDERS COME, I SWING FIRST."
  }
  if k == 9 {
    return "..."
  }
  if k == 8 {
    return "NO ONE KNOWS WHAT IS AT THE BOTTOM."
  }
  if k == 11 {
    return "THE DEAD LEFT US THEIR WORDS."
  }
  if k == 12 {
    return "EVERY DESCENT TEACHES SOMETHING."
  }
  return ""
}

fn drawLobby() {
  if upOpen == 1 {
    drawUpgrades()
    return 0
  }
  if codeOpen == 1 {
    drawCode()
    return 0
  }
  if loreOpen == 1 {
    drawLore()
    return 0
  }
  vignette()
  box 159, 89, 2, 2 color "#ffffff70"
  panel(6, 6, 100, 30, "#7dff9c")
  write "BANK" at 12, 11 color "#8c93a3"
  writeR("$" + bank, 100, 11, "#7dff9c")
  write "CLASS" at 12, 23 color "#8c93a3"
  writeR(className(cls), 100, 23, "#ffd23f")
  // what you are taking down
  let ne = buyE
  let nk = buyK
  let hh = 3 + buyH
  let ax = "NO"
  if buyC == 1 {
    ax = "YES"
  }
  if cls == 0 {
    ne += 1
  }
  if cls == 1 {
    nk += 1
  }
  let sm = buyS
  if cls == 2 {
    hh = 5 + buyH
    ax = "YES"
  }
  if cls == 3 {
    hh = 2 + buyH
    ax = "YES"
    sm += 2
  }
  panel(214, 6, 100, 68, "#59606e")
  write "TAKING DOWN" at 220, 11 color "#8c93a3"
  write "NOISEMAKER" at 220, 21 color "#c9ccd6"
  writeR("" + ne, 308, 21, "#4de1ff")
  write "DRINK" at 220, 29 color "#c9ccd6"
  writeR("" + buyD, 308, 29, "#ffcf3f")
  write "KEYCARD" at 220, 37 color "#c9ccd6"
  writeR("" + nk, 308, 37, "#4de1ff")
  write "FIRE AXE" at 220, 45 color "#c9ccd6"
  writeR(ax, 308, 45, "#e8e2c8")
  write "HEARTS" at 220, 53 color "#c9ccd6"
  writeR("" + hh, 308, 53, "#ff5a4a")
  write "SMOKE" at 220, 61 color "#c9ccd6"
  writeR("" + sm, 308, 61, "#c9ccd6")
  if msgT > 0 {
    let mw = length(msg) * 6 + 16
    panel(160 - mw / 2, 80, mw, 14, "#e8e2c8")
    write msg at 160, 84 color "#f2e9c9" centered
  }
  if lobNear >= 0 {
    let k = stK[lobNear]
    let col = "#ffd23f"
    if k >= 3 and k <= 7 {
      col = "#7dff9c"
    }
    if k == 10 {
      col = "#7dff9c"
    }
    if k == 11 {
      col = "#e8dcb0"
    }
    if k == 12 {
      col = "#ffd23f"
    }
    if k == 13 {
      col = "#4de1ff"
    }
    if k == 8 {
      col = "#33ff77"
    }
    let dd = stDesc(k)
    let qq = stQuote(k)
    let ww = max(max(length(dd) * 6 + 20, length(qq) * 6 + 20), 150)
    let qo = 0
    if length(qq) > 0 {
      qo = 10
    }
    panel(160 - ww / 2, 106 - qo, ww, 54 + qo, col)
    write stName(k) at 160, 111 - qo color col centered
    if qo > 0 {
      write qq at 160, 122 - qo color "#8c8666" centered
    }
    write dd at 160, 125 color "#c9ccd6" centered
    let kc = k
    if k == 9 {
      kc = 3
    }
    if k <= 2 or k == 9 {
      if cls == kc {
        keyHint("E", "SELECTED", 141, "#7dff9c")
      } else {
        keyHint("E", "SELECT CLASS", 141, col)
      }
    } else if k == 8 {
      keyHint("E", "DROP IN", 141, col)
    } else if k == 11 {
      keyHint("E", "READ", 141, col)
    } else if k == 12 {
      keyHint("E", "OPEN UPGRADES", 141, col)
    } else if k == 13 {
      keyHint("E", "ENTER CODE", 141, col)
    } else {
      let own = buyE
      if k == 10 {
        own = buyS
      }
      if k == 4 {
        own = buyD
      }
      if k == 5 {
        own = buyK
      }
      if k == 6 {
        own = buyC
      }
      if k == 7 {
        own = buyH
      }
      keyHint("E", "BUY  (HAVE " + own + ")", 141, col)
    }
  }
  write "WASD WALK  E USE  PURCHASES ARE FINAL" at 6, 171 color "#6f7686"
}

// ---------- permanent upgrades and redeem codes ----------
fn upInit() {
  upL = []
  add saved("omf_up0", 0) to upL
  add saved("omf_up1", 0) to upL
  add saved("omf_up2", 0) to upL
  add saved("omf_up3", 0) to upL
  add saved("omf_up4", 0) to upL
  cdDone = []
  add saved("omf_cd0", 0) to cdDone
  add saved("omf_cd1", 0) to cdDone
  add saved("omf_cd2", 0) to cdDone
  add saved("omf_cd3", 0) to cdDone
  add saved("omf_cd4", 0) to cdDone
  add saved("omf_cd5", 0) to cdDone
}

fn upSave() {
  save "omf_up0", upL[0]
  save "omf_up1", upL[1]
  save "omf_up2", upL[2]
  save "omf_up3", upL[3]
  save "omf_up4", upL[4]
}

fn upName(i) {
  if i == 0 {
    return "THICK SKIN"
  }
  if i == 1 {
    return "SOFT SOLES"
  }
  if i == 2 {
    return "QUICK HANDS"
  }
  if i == 3 {
    return "LUCKY FINDER"
  }
  return "DEEP POCKETS"
}

fn upDesc(i) {
  if i == 0 {
    return "+1 HEART EVERY RUN"
  }
  if i == 1 {
    return "10% QUIETER STEPS"
  }
  if i == 2 {
    return "WORKSTATION SCANS FASTER"
  }
  if i == 3 {
    return "+25% CASH FOUND"
  }
  return "START WITH +1 DRINK"
}

fn upMax(i) {
  if i == 0 or i == 4 {
    return 2
  }
  return 3
}

fn upCost(i) {
  let base = 150
  if i == 1 {
    base = 80
  } else if i == 2 {
    base = 70
  } else if i == 3 {
    base = 60
  } else if i == 4 {
    base = 90
  }
  return base * (upL[i] + 1)
}

fn buyUp(i) {
  if upOpen == 0 {
    return 0
  }
  if upL[i] >= upMax(i) {
    say("ALREADY MAXED", 60)
    return 0
  }
  let c = upCost(i)
  if bank < c {
    tone 140 for 100ms
    say("NOT ENOUGH CASH", 70)
    return 0
  }
  bank -= c
  upL[i] += 1
  save "omf_bank", bank
  upSave()
  tone 700 for 80ms
  say(upName(i) + " UPGRADED", 90)
}

fn typeCh(ch) {
  if length(codeBuf) < 14 {
    codeBuf = codeBuf + ch
    tone 400 for 20ms
  }
}

fn codeIndex(c) {
  if c == "onemorefloor" {
    return 0
  }
  if c == "ashgrove" {
    return 1
  }
  if c == "elevator" {
    return 2
  }
  if c == "ninja" {
    return 3
  }
  if c == "0417" {
    return 4
  }
  if c == "logcard" {
    return 5
  }
  return 0 - 1
}

fn submitCode() {
  let k = codeIndex(codeBuf)
  if k < 0 {
    codeMsg = "INVALID CODE"
    tone 140 for 120ms
  } else if cdDone[k] == 1 {
    codeMsg = "CODE ALREADY USED"
    tone 140 for 120ms
  } else {
    cdDone[k] = 1
    save "omf_cd" + k, 1
    if k == 5 {
      if loreFound < loreMax {
        loreFound += 1
        save "omf_lore", loreFound
      }
      codeMsg = "A LOG CARD WAS ADDED TO YOUR ARCHIVE"
    } else {
      let amt = 100
      if k == 1 {
        amt = 150
      } else if k == 2 {
        amt = 50
      } else if k == 3 {
        amt = 75
      } else if k == 4 {
        amt = 250
      }
      bank += amt
      save "omf_bank", bank
      codeMsg = "REDEEMED  +$" + amt
    }
    tone 700 for 120ms
  }
  codeBuf = ""
}

fn closeMenus() {
  upOpen = 0
  codeOpen = 0
  codeBuf = ""
  codeMsg = ""
}

// ---------- cutscenes ----------
fn cutText(i) {
  if i == 0 {
    return "MARCH. THE SURFACE LOST CONTACT WITH ASHGROVE."
  }
  if i == 1 {
    return "SIX FLOORS. ONE LIFT. NO ONE CAME BACK UP."
  }
  if i == 2 {
    return "THE SURVIVORS LEFT WHAT THEY COULD CARRY."
  }
  return "SOMETHING DOWN THERE IS LISTENING."
}

fn cutFrame() {
  cutT += 1
  let dur = 260
  let f = cutT * 1000 / dur
  let cxx = 0
  let cyy = 165
  let czz = 0
  let cyw = 0
  if cutIdx == 0 {
    cxx = 1000 + 450 * f / 1000
    czz = 640
    cyw = 900
  } else if cutIdx == 1 {
    cxx = 960
    czz = 760
    cyw = (3400 + 450 * f / 1000) % 3600
  } else if cutIdx == 2 {
    cxx = 960 - 300 * f / 1000
    czz = 520
    cyw = 1800 - 200 * f / 1000
  } else {
    cxx = 1450 + 190 * f / 1000
    czz = 640
    cyw = 900
  }
  camera3d cxx, cyy + sin(t * 8) * 2 / 1000, czz, cyw, 0
  if cutT >= dur {
    cutT = 0
    cutIdx += 1
    if cutIdx > 3 {
      endIntro()
    }
  }
}

fn startIntro() {
  enterLobby()
  state = 7
  cutT = 0
  cutIdx = 0
  say("", 1)
}

fn endIntro() {
  introSeen = 1
  save "omf_intro", 1
  state = 5
  px = 9600
  pz = 7000
  yaw = 0
  pitch = 0
  say("PICK A CLASS - SHOP - THEN DROP IN", 200)
}

fn drawCut() {
  box 0, 0, 320, 24 color "#000000"
  box 0, 156, 320, 24 color "#000000"
  let n = min(length(cutText(cutIdx)), cutT / 2)
  let a = 255
  if cutT > 225 {
    a = max(0, (260 - cutT) * 7)
  }
  write part(cutText(cutIdx), 0, n) at 160, 164 color "#e8e2c8" + hex2(a) centered
  write "ENTER: SKIP" at 312 - 11 * 6, 8 color "#6f7686"
  if cutIdx == 3 and cutT > 200 {
    box 0, 0, 320, 180 color "#000000" + hex2(min(255, (cutT - 200) * 4))
  }
}

fn rideLine(f) {
  let k = f % 4
  if k == 1 {
    return "THE CABLES SING. THE LIFT SHAKES."
  }
  if k == 2 {
    return "SOMETHING BREATHES IN THE SHAFT."
  }
  if k == 3 {
    return "THE PANEL NUMBERS DO NOT MATCH."
  }
  return "ONE MORE FLOOR."
}

fn shopBuy(price, what) {
  if state != 5 {
    return 0
  }
  if bank < price {
    tone 140 for 100ms
    say("NOT ENOUGH CASH", 70)
    return 0
  }
  if what == 3 and (buyC == 1 or cls >= 2) {
    return 0
  }
  if what == 4 and buyH >= 3 {
    return 0
  }
  bank -= price
  say("BOUGHT", 50)
  if what == 0 {
    buyE += 1
  } else if what == 1 {
    buyD += 1
  } else if what == 2 {
    buyK += 1
  } else if what == 3 {
    buyC = 1
  } else if what == 5 {
    buyS += 1
  } else {
    buyH += 1
  }
  save "omf_bank", bank
  tone 600 for 50ms
}

fn keyK3() {
  if codeOpen == 1 {
    typeCh("3")
    return 0
  }
  if upOpen == 1 {
    buyUp(2)
    return 0
  }
  if state == 1 {
    swingCrowbar()
  }
}

when key "3" pressed {
  keyK3()
}


fn keyKl() {
  if codeOpen == 1 {
    typeCh("l")
    return 0
  }
  if (state == 1 or state == 5) and loreFound > 0 {
    if loreOpen == 0 {
      loreOpen = 1
      loreView = loreFound - 1
    } else {
      loreView -= 1
      if loreView < 0 {
        loreOpen = 0
      }
    }
  }
}

when key "l" pressed {
  keyKl()
}


fn keyKenter() {
  if codeOpen == 1 {
    submitCode()
    return 0
  }
  if state == 7 {
    endIntro()
  } else if state == 0 and introSeen == 0 {
    startIntro()
  } else if state == 0 or state == 2 {
    enterLobby()
  } else if state == 4 {
    floor += 1
    state = 1
    newFloor()
    if musicOn == 1 {
      music "e3 - - - - - - - - - - - d#3 - - -", "a1 - - - - - - - - - - - - - - -" tempo 46
    }
  }
}

when key "enter" pressed {
  keyKenter()
}


when key "esc" pressed {
  closeMenus()
  if loreOpen == 1 and state == 5 {
    loreOpen = 0
  }
}

when key "backspace" pressed {
  if codeOpen == 1 and length(codeBuf) > 0 {
    codeBuf = part(codeBuf, 0, length(codeBuf) - 1)
  }
}

when key "a" pressed {
  if codeOpen == 1 {
    typeCh("a")
  }
}

when key "b" pressed {
  if codeOpen == 1 {
    typeCh("b")
  }
}

when key "c" pressed {
  if codeOpen == 1 {
    typeCh("c")
  }
}

when key "d" pressed {
  if codeOpen == 1 {
    typeCh("d")
  }
}

when key "f" pressed {
  if codeOpen == 1 {
    typeCh("f")
  }
}

when key "g" pressed {
  if codeOpen == 1 {
    typeCh("g")
  }
}

when key "h" pressed {
  if codeOpen == 1 {
    typeCh("h")
  }
}

when key "i" pressed {
  if codeOpen == 1 {
    typeCh("i")
  }
}

when key "j" pressed {
  if codeOpen == 1 {
    typeCh("j")
  }
}

when key "k" pressed {
  if codeOpen == 1 {
    typeCh("k")
  }
}

when key "o" pressed {
  if codeOpen == 1 {
    typeCh("o")
  }
}

when key "p" pressed {
  if codeOpen == 1 {
    typeCh("p")
  }
}

when key "q" pressed {
  if codeOpen == 1 {
    typeCh("q")
  }
}

when key "r" pressed {
  if codeOpen == 1 {
    typeCh("r")
  }
}

when key "s" pressed {
  if codeOpen == 1 {
    typeCh("s")
  }
}

when key "u" pressed {
  if codeOpen == 1 {
    typeCh("u")
  }
}

when key "v" pressed {
  if codeOpen == 1 {
    typeCh("v")
  }
}

when key "w" pressed {
  if codeOpen == 1 {
    typeCh("w")
  }
}

when key "x" pressed {
  if codeOpen == 1 {
    typeCh("x")
  }
}

when key "y" pressed {
  if codeOpen == 1 {
    typeCh("y")
  }
}

when key "z" pressed {
  if codeOpen == 1 {
    typeCh("z")
  }
}

when key "0" pressed {
  if codeOpen == 1 {
    typeCh("0")
  }
}

when key "5" pressed {
  if upOpen == 1 {
    buyUp(4)
  }
  if codeOpen == 1 {
    typeCh("5")
  }
}

when key "6" pressed {
  if codeOpen == 1 {
    typeCh("6")
  }
}

when key "7" pressed {
  if codeOpen == 1 {
    typeCh("7")
  }
}

when key "8" pressed {
  if codeOpen == 1 {
    typeCh("8")
  }
}

when key "9" pressed {
  if codeOpen == 1 {
    typeCh("9")
  }
}

fn keyKm() {
  if codeOpen == 1 {
    typeCh("m")
    return 0
  }
  if state == 1 {
    showMap = 1 - showMap
  }
}

when key "m" pressed {
  keyKm()
}


fn keyKn() {
  if codeOpen == 1 {
    typeCh("n")
    return 0
  }
  if musicOn == 1 {
    musicOn = 0
    music off
  } else {
    musicOn = 1
    if state == 1 {
      music "e3 - - - - - - - - - - - d#3 - - -", "a1 - - - - - - - - - - - - - - -" tempo 46
    }
  }
}

when key "n" pressed {
  keyKn()
}


// ---------- drawing the 2D layer (HUD) on top of the 3D world ----------
// ---------- HUD ----------
// a panel: dark glass with a thin accent line on top and small corner ticks
fn panel(x, y, w, h, col) {
  box x, y, w, h color "#07090dc8"
  box x, y, w, 1 color col
  box x, y + h - 1, w, 1 color "#ffffff12"
  box x, y, 2, 2 color col
  box x + w - 2, y, 2, 2 color col
}

// text that ends at x
fn writeR(text1, x, y, col) {
  write text1 at x - length(text1) * 6, y color col
}

// a thin progress bar
fn meter(x, y, w, val, maxv, col) {
  box x, y, w, 4 color "#ffffff14"
  if val > 0 {
    box x, y, val * w / maxv, 4 color col
  }
}

// a prompt with a key cap: [E] SEARCH DESK
fn keyHint(key, text1, y, col) {
  let w = length(text1) * 6 + 30
  let x = 160 - w / 2
  panel(x, y - 3, w, 16, col)
  box x + 4, y, 12, 10 color "#59606e"
  box x + 5, y + 1, 10, 8 color "#161b24"
  write key at x + 8, y + 2 color "#ffffff"
  write text1 at x + 22, y + 2 color col
}

// top left: floor number and the three cells
fn heart(x, y, col) {
  box x, y, 2, 2 color col
  box x + 3, y, 2, 2 color col
  box x, y + 1, 5, 2 color col
  box x + 1, y + 3, 3, 1 color col
  box x + 2, y + 4, 1, 1 color col
}

fn hudStatus() {
  let pw = 70
  if keyN > 0 {
    pw = 92
  }
  panel(6, 6, pw, 26, "#8c93a3")
  write "FLOOR " + floor at 11, 10 color "#e8e2c8"
  if keyN > 0 {
    box 66, 11, 10, 6 color "#4de1ff"
    box 67, 13, 8, 1 color "#0b1118"
    write "" + keyN at 79, 10 color "#4de1ff"
  }
  if raidFloor == 1 or hp < hpMax {
    for hh from 0 to hpMax - 1 {
      let hc = "#3a1a1e"
      if hh < hp {
        hc = "#ff4b5c"
      }
      heart(7 + hh * 7, 35, hc)
    }
  }
  write "$" + bank at 314 - length("$" + bank) * 6, 20 color "#7dff9c"
  for c from 0 to 2 {
    let col = "#1c2a30"
    if cellGot[c] == 1 {
      col = "#4de1ff"
    }
    if c < cells {
      col = "#5dffa0"
    }
    box 11 + c * 16, 21, 12, 8 color "#000000"
    box 12 + c * 16, 22, 10, 6 color col
  }
}

// top centre: where to go (a second line appears once the floor is scanned)
fn hudGuide() {
  let h = 17
  if scanned == 1 {
    h = 28
  }
  let ecol = "#ff8a7a"
  if cells == 3 {
    ecol = "#7dff9c"
  }
  let elab = "EXIT"
  if carry > 0 {
    elab = "CHARGER"
    ecol = "#4de1ff"
  }
  let gw = 88
  if scanned == 1 {
    gw = 150
  }
  panel(160 - gw / 2, 6, gw, h, ecol)
  write arrowGlyph(stepDir(eMap)) + " " + elab + " " + eMap[(pz / 1600) * MW + px / 1600] * 16 / 10 + "M" at 160, 11 color ecol centered
  if scanned == 1 {
    let nc = nearestCell()
    if nc == 0 - 2 {
      if keyN > 0 {
        write "VAULT: USE KEYCARD AT DOOR" at 160, 22 color "#ffd23f" centered
      } else {
        write "VAULT LOCKED - FIND A CARD" at 160, 22 color "#ffd23f" centered
      }
    }
    if nc >= 0 {
      let cm = c0Map
      if nc == 1 {
        cm = c1Map
      }
      if nc == 2 {
        cm = c2Map
      }
      write arrowGlyph(stepDir(cm)) + " CELL " + cm[(pz / 1600) * MW + px / 1600] * 16 / 10 + "M" at 160, 22 color "#4de1ff" centered
    }
  }
}

// the tracker button. Click it with the mouse (press Esc to free the cursor) or press T.
fn trackerButton(bx, by) {
  let bc = "#2fff7a"
  let lab = "TRACKER ON"
  if trackerOn == 0 {
    bc = "#6b7280"
    lab = "TRACKER OFF"
  }
  panel(bx, by, 82, 13, bc)
  box bx + 4, by + 3, 8, 8 color bc
  write "T" at bx + 6, by + 4 color "#0b1210"
  write lab at bx + 16, by + 4 color bc
  let hz = hot3d(bx, by, 82, 13)
}

// bottom left: the tracker (button + grid radar with a sweep) and two slim bars
fn hudVitals() {
  if hidden == 0 {
    trackerButton(6, 102)
  }
  if trackerOn == 1 and hidden == 0 {
    let rx0 = 6
    let ry0 = 117
    let rcx = rx0 + 41
    let rcy = ry0 + 21
    panel(rx0, ry0, 82, 43, "#2fff7a")
    box rx0 + 1, ry0 + 1, 80, 41 color "#041109"
    // grid lines every 10 pixels, brighter through the centre
    for gx from 1 to 7 {
      box rx0 + gx * 10, ry0 + 1, 1, 41 color "#0c2417"
    }
    for gy from 1 to 3 {
      box rx0 + 1, ry0 + gy * 10 + 1, 80, 1 color "#0c2417"
    }
    box rcx, ry0 + 1, 1, 41 color "#1b5a34"
    box rx0 + 1, rcy, 80, 1 color "#1b5a34"
    // two range rings (7 m and 3.5 m)
    for a2 from 0 to 23 {
      let ang = a2 * 150
      box rcx + sin(ang) * 38 / 1000, rcy - cos(ang) * 19 / 1000, 1, 1 color "#1f6b3c"
      box rcx + sin(ang) * 19 / 1000, rcy - cos(ang) * 9 / 1000, 1, 1 color "#164d2b"
    }
    // the sweep
    let sw = (t * 30) % 3600
    for r2 from 1 to 9 {
      box rcx + sin(sw) * r2 * 4 / 1000, rcy - cos(sw) * r2 * 2 / 1000, 1, 1 color "#3dff8a"
    }
    box rcx - 1, rcy - 1, 3, 3 color "#2fff7a"
    // the creature, only while it is moving
    let ddx = mx - px
    let ddz = mz - pz
    let lr = (ddx * cos(yaw) + ddz * sin(yaw)) / 1000
    let lf = (ddx * sin(yaw) - ddz * cos(yaw)) / 1000
    if mstate != 3 and abs(lr) < 7000 and abs(lf) < 7000 {
      let rbx = rcx + lr * 38 / 7000
      let rby = rcy - lf * 19 / 7000
      box rbx - 2, rby - 2, 4, 4 color "#ff3b2f"
      box rbx - 1, rby - 1, 2, 2 color "#ffb0a8"
    }
  }
  // sound and stamina
  let nc = "#6fe38a"
  if noiseLvl > 70 {
    nc = "#ff5a4a"
  } else if noiseLvl > 35 {
    nc = "#ffd23f"
  }
  write "NOISE" at 6, 164 color "#8c93a3"
  meter(40, 165, 48, noiseLvl, 100, nc)
  let sc = "#e8e2c8"
  if tired == 1 {
    sc = "#d8503c"
  }
  write "STAM" at 6, 172 color "#8c93a3"
  meter(40, 173, 48, stam, 600, sc)
}

// bottom centre: the hotbar. 1 noisemaker, 2 drink, 3 axe (if you have one), 4 smoke bomb, E keycards
fn hudHotbar() {
  if slotFlash > 0 {
    slotFlash -= 1
  }
  let kinds = []
  add 0 to kinds
  add 1 to kinds
  if crowbar == 1 {
    add 2 to kinds
  }
  if smokeN > 0 or cls == 3 {
    add 3 to kinds
  }
  add 4 to kinds
  let ns = length(kinds)
  let sx0 = 160 - ns * 36 / 2 + 3
  for sl from 0 to ns - 1 {
    let sx = sx0 + sl * 36
    let sy = 138
    let kind = kinds[sl]
    let cnt = emitN
    let scol = "#4de1ff"
    let lab = "" + (sl + 1)
    if kind == 1 {
      cnt = drinkN
      scol = "#ffcf3f"
    }
    if kind == 2 {
      cnt = 1
      scol = "#e8e2c8"
    }
    if kind == 3 {
      cnt = smokeN
      scol = "#c9ccd6"
      lab = "4"
    }
    if kind == 4 {
      cnt = keyN
      scol = "#4de1ff"
      lab = "E"
    }
    let edge = "#59606e"
    let fillc = "#0d1118e8"
    if cnt == 0 {
      edge = "#2a2f38"
    }
    if slotFlash > 0 and slotKind == kind + 1 {
      edge = "#ffffff"
      fillc = "#2a3342f0"
    }
    box sx, sy, 30, 30 color edge
    box sx + 1, sy + 1, 28, 28 color fillc
    if kind == 0 {
      draw icRadio at sx + 3, sy + 3
    } else if kind == 1 {
      draw icCan at sx + 3, sy + 3
    } else if kind == 2 {
      draw icAxe at sx + 3, sy + 3
    } else if kind == 3 {
      draw icSmoke at sx + 3, sy + 3
    } else {
      draw icKey at sx + 3, sy + 3
    }
    if cnt == 0 {
      box sx + 1, sy + 1, 28, 28 color "#0d1118c0"
    }
    if kind == 2 and swingT > 0 {
      box sx + 1, sy + 26, 28, 3 color "#ffffff"
    }
    if kind == 3 and smokeT > 0 {
      box sx + 1, sy + 26, smokeT * 28 / 480, 3 color "#c9ccd6"
    }
    if kind != 2 {
      box sx + 18, sy + 20, 11, 9 color "#000000c0"
      write "" + cnt at sx + 21, sy + 21 color scol
    }
    write lab at sx + 13, sy + 32 color "#8c93a3"
  }
}

fn drawLore() {
  let base = loreView * 6
  panel(40, 30, 240, 104, "#e8dcb0")
  box 41, 31, 238, 102 color "#0e0c08fa"
  write loreData[base] at 52, 38 color "#ffd23f"
  box 52, 48, 216, 1 color "#4a4328"
  for ln from 1 to 5 {
    write loreData[base + ln] at 52, 52 + (ln - 1) * 11 color "#e8dcb0"
  }
  write "CARD " + (loreView + 1) + " / " + loreFound at 52, 118 color "#8c8666"
  writeR("L: OLDER", 268, 118, "#8c8666")
}

fn className(k) {
  if k == 0 {
    return "SCOUT"
  }
  if k == 1 {
    return "ENGINEER"
  }
  if k == 2 {
    return "BRAWLER"
  }
  return "NINJA"
}

fn classLine(k, ln) {
  if k == 0 {
    if ln == 0 {
      return "QUIET STEPS"
    }
    if ln == 1 {
      return "+1 NOISEMAKER"
    }
    return "3 HEARTS"
  }
  if k == 1 {
    if ln == 0 {
      return "FAST SCANNER"
    }
    if ln == 1 {
      return "1 KEYCARD"
    }
    return "3 HEARTS"
  }
  if k == 3 {
    if ln == 0 {
      return "NEAR SILENT"
    }
    if ln == 1 {
      return "FIRE AXE"
    }
    return "2 HEARTS"
  }
  if ln == 0 {
    return "5 HEARTS"
  }
  if ln == 1 {
    return "FIRE AXE"
  }
  return "HITS HARD"
}

fn hud() {
  if state == 7 {
    drawCut()
    return 0
  }
  if state == 5 {
    drawLobby()
    return 0
  }
  if state == 1 {
    // crosshair
    vignette()
    box 159, 89, 2, 2 color "#ffffff70"
    hudStatus()
    hudGuide()
    hudVitals()
    hudHotbar()
    if menace > 700 {
      box 0, 0, 320, 4 color "#ff000060"
      box 0, 176, 320, 4 color "#ff000060"
    }
    // toast messages
    if msgT > 0 {
      let mw = length(msg) * 6 + 16
      panel(160 - mw / 2, 42, mw, 14, "#e8e2c8")
      write msg at 160, 46 color "#f2e9c9" centered
    }
    // interact prompts (one at a time)
    let near = 0
    let i = 0
    while i < length(lkx) {
      if hidden == 0 and dst(px, pz, lkx[i] * 1600 + 800, lky[i] * 1600 + 800 + 1600) < 1500 {
        near = 1
      }
      i += 1
    }
    let nearD = 0
    let dH = 0
    while dH < length(deskX) {
      if deskDone[dH] == 0 and hidden == 0 and dst(px, pz, deskX[dH], deskZ[dH]) < 1900 {
        nearD = 1
      }
      dH += 1
    }
    let nDoor = nearDoor()
    if hidden == 0 and carry > 0 and dst(px, pz, chX, chZ) < 1700 {
      keyHint("E", "INSERT CELL  (" + cells + "/3)", 124, "#4de1ff")
    } else if hidden == 0 and nDoor >= 0 {
      if keyN > 0 {
        keyHint("E", "UNLOCK VAULT (KEYCARD)", 124, "#4de1ff")
      } else {
        keyHint("E", "LOCKED - NEEDS KEYCARD", 124, "#ff8a7a")
      }
    } else if hidden == 0 and dst(px, pz, ex * 1600 + 800, ey * 1600 + 800 + 1600) < 1700 {
      if cells == 3 {
        keyHint("E", "CALL ELEVATOR", 124, "#7dff9c")
      } else {
        keyHint("E", "ELEVATOR  " + cells + "/3 CELLS", 124, "#ff8a7a")
      }
    } else if nearD == 1 {
      keyHint("E", "SEARCH DESK", 124, "#e8e2c8")
    } else if near == 1 {
      keyHint("E", "HIDE", 124, "#c9ccd6")
    }
    // the workstation scans while you stand next to it
    if scanned == 0 and hidden == 0 and scanT > 0 {
      panel(92, 90, 136, 22, "#4de1ff")
      write "WORKSTATION SCANNING" at 160, 94 color "#4de1ff" centered
      meter(98, 104, 124, scanT, scanNeed(), "#4de1ff")
    }
    // the creature is after you: red edges
    if mstate == 1 {
      box 0, 0, 320, 3 color "#ff1a1a60"
      box 0, 177, 320, 3 color "#ff1a1a60"
      box 0, 0, 3, 180 color "#ff1a1a60"
      box 317, 0, 3, 180 color "#ff1a1a60"
    }
    if locked3d() == 0 {
      writeR("CLICK TO LOOK", 314, 8, "#8c93a3")
    }
    // hiding: look out through the slits of the locker door
    if hidden == 1 {
      box 0, 0, 320, 64 color "#050605"
      box 0, 116, 320, 64 color "#050605"
      for s from 0 to 5 {
        box 0, 70 + s * 8, 320, 3 color "#050605"
      }
      box 0, 64, 6, 52 color "#050605"
      box 314, 64, 6, 52 color "#050605"
      keyHint("E", "LEAVE LOCKER", 160, "#c9ccd6")
    }
    if hurtT > 60 {
      box 0, 0, 320, 180 color "#ff000050"
    }
    if loreOpen == 1 and loreFound > 0 {
      drawLore()
    }
    if showMap == 1 {
      drawMap()
    }
    if fadeIn > 0 {
      box 0, 0, 320, 180 color "#000000" + hex2(fadeIn * 255 / 90)
    }
    if lookT > 0 {
    box 0, 0, 320, 14 color "#000000"
    box 0, 166, 320, 14 color "#000000"
  }
  if cardT > 0 {
      cardT -= 1
      let ca = min(255, cardT * 3)
      if cardT > 230 {
        ca = min(255, (260 - cardT) * 9)
      }
      write "ASHGROVE" at 160, 70 color "#e8e2c8" + hex2(ca) size 2 centered
      if raidFloor == 1 {
        write "THE RAIDERS HAVE TAKEN THIS FLOOR" at 160, 90 color "#d8503c" + hex2(ca) centered
      } else {
        write "SUBLEVEL " + floor at 160, 90 color "#8c8666" + hex2(ca) centered
      }
    }
  } else if state == 0 {
    box 0, 0, 320, 180 color "#000000b0"
    write "ASHGROVE" at 160, 40 color "#e8e2c8" size 3 centered shadow
    write "DEEP SURVEY FACILITY - SIX FLOORS - ONE LIFT" at 160, 64 color "#8c8666" centered
    write "THE ELEVATOR OPENS. SOMETHING IS WAITING." at 160, 82 color "#9aa1b0" centered
    write "WASD WALK  SHIFT RUN  E USE  M MAP  T TRACKER" at 160, 112 color "#c9ccd6" centered
    write "MOUSE LOOK (CLICK THE GAME FIRST)" at 160, 123 color "#c9ccd6" centered
    write "FIND 3 ENERGY CELLS, THEN GET BACK TO THE ELEVATOR" at 160, 134 color "#c9ccd6" centered
    if (t / 30) % 2 == 0 {
      write "ENTER: THE LOBBY" at 160, 150 color "#ffd23f" size 2 centered shadow
    }
    write "DEEPEST FLOOR: " + best at 160, 170 color "#6f7686" centered
  } else if state == 2 {
    let a = min(255, deadT * 4)
    box 0, 0, 320, 180 color "#5a0000" + hex2(min(a, 200))
    if deadT > 40 {
      write "IT FOUND YOU" at 160, 62 color "#ff3b30" size 3 centered shadow
      write "YOU REACHED FLOOR " + floor at 160, 100 color "#e8e2c8" centered shadow
      write "DEEPEST: " + best at 160, 112 color "#9aa1b0" centered
      if (t / 30) % 2 == 0 {
        write "ENTER: TRY AGAIN FROM FLOOR 1" at 160, 140 color "#ffd23f" centered shadow
      }
    }
  } else if state == 3 {
    let a = min(255, rideT * 6)
    box 0, 0, 320, 180 color "#000000" + hex2(a)
    if rideT > 40 {
      write "DESCENDING" at 160, 72 color "#9aa1b0" size 2 centered shadow
      write "FLOOR " + (floor + 1) at 160, 98 color "#e8e2c8" size 2 centered shadow
      write rideLine(floor + 1) at 160, 124 color "#8c8666" centered
    }
  } else if state == 4 {
    box 0, 0, 320, 180 color "#000000d8"
    write "YOU MADE IT OUT" at 160, 48 color "#7dff9c" size 3 centered shadow
    write "FIVE FLOORS DOWN... AND THE ELEVATOR KEEPS GOING." at 160, 88 color "#c9ccd6" centered
    if (t / 30) % 2 == 0 {
      write "ENTER: GO DEEPER?" at 160, 128 color "#ffd23f" size 2 centered shadow
    }
  }
}

// the map: only tiles you have seen. Press M to open and close it.
fn drawMap() {
  let x0 = 82
  let y0 = 24
  box x0 - 5, y0 - 5, 166, 130 color "#05070bf4"
  for ty from 0 to MH - 1 {
    for tx from 0 to MW - 1 {
      if explored[ty * MW + tx] == 1 {
        box x0 + tx * 6, y0 + ty * 6, 5, 5 color "#2b3340"
      }
    }
  }
  let mc = "#ff5a4a"
  if cells == 3 {
    mc = "#5dffa0"
  }
  box x0 + ex * 6, y0 + ey * 6, 5, 3 color mc
  let i = 0
  while i < length(lkx) {
    if explored[(lky[i] + 1) * MW + lkx[i]] == 1 {
      box x0 + lkx[i] * 6 + 1, y0 + lky[i] * 6, 3, 3 color "#6b8a76"
    }
    i += 1
  }
  let tt = (termZ / 1600) * MW + termX / 1600
  if explored[tt] == 1 {
    box x0 + (termX / 1600) * 6 + 1, y0 + (termZ / 1600) * 6 + 1, 3, 3 color "#4de1ff"
  }
  if scanned == 1 {
    for k from 0 to 2 {
      if cellGot[k] == 0 {
        box x0 + (cellX[k] / 1600) * 6 - 1, y0 + (cellZ[k] / 1600) * 6 - 1, 7, 7 color "#4de1ff"
      }
    }
  }
  let ppx = x0 + px * 6 / 1600
  let ppy = y0 + pz * 6 / 1600
  box ppx - 1, ppy - 1, 3, 3 color "#ffffff"
  box ppx + sin(yaw) * 4 / 1000 - 1, ppy - cos(yaw) * 4 / 1000 - 1, 2, 2 color "#ffd23f"
  write "MAP" at 160, y0 + 114 color "#8c93a3" centered
}

// two hex digits for a number 0..255 (used for see-through black fades)
fn hex2(n) {
  let v = constrain(n, 0, 255)
  let digits = "0123456789abcdef"
  return part(digits, v / 16, 1) + part(digits, v % 16, 1)
}

// ---------- start up: a slowly turning view of the first elevator room ----------
loreInit()
upInit()
makeMap()
placeThings()
build3d()
show3d monLamp, 0
let idle = 0

every frame {
  t += 1
  if msgT > 0 {
    msgT -= 1
  }
  if state == 7 {
    cutFrame()
  } else if state == 5 {
    lobbyFrame()
  } else if state == 0 {
    // title: orbit the first room
    idle += 3
    camera3d px / 10, 150, pz / 10, idle, 0 - 40
    torch3d 50, 2200
    show3d monLamp, 0
  } else if state == 1 {
    if fadeIn > 0 {
      fadeIn -= 1
    }
    playerFrame()
    pickups()
    scanFrame()
    flickerFrame()
    if clicked3d() == 1 {
      trackerOn = 1 - trackerOn
      tone 700 for 30ms
    }
    directorFrame()
    trackerFrame()
    exploreFrame()
    monsterFrame()
    raiderFrame()
    placeMonster()
    torchFrame()
    heartbeat()
    ambience()
    // cells spin and hover
    for c from 0 to 2 {
      if cellGot[c] == 0 {
        turn3d cellId[c], t * 12
        move3d cellId[c], cellX[c] / 10, 110 + sin(t * 30) * 8 / 1000, cellZ[c] / 10
      }
    }
    // the elevator doors slide open when it is powered and you are close
    let want = 0
    if cells == 3 and dst(px, pz, ex * 1600 + 800, ey * 1600 + 800 + 1600) < 3200 {
      want = 1
    }
    if want == 1 and doorOpen < 56 {
      doorOpen += 2
    }
    if want == 0 and doorOpen > 0 {
      doorOpen -= 2
    }
    if want != gateWas {
      gateWas = want
      if want == 1 {
        anim3d gateId, "open"
      } else {
        anim3d gateId, "close"
      }
    }
    // the camera
    if hidden == 1 {
      camera3d lkx[hideIdx] * TS + TS / 2, 150, lky[hideIdx] * TS + TS / 2, yaw, 0
    } else {
      let bobY = sin(bob * 7) * 4 / 1000
      let sprintDip = 0
      if stepAcc > 0 and held("shift") and tired == 0 and stam > 0 {
        sprintDip = 30
      }
      camera3d px / 10, 165 + bobY - sprintDip / 6, pz / 10, yaw + sin(t * 9) * 4 / 1000, pitch + sin(t * 13) * 3 / 1000 + sprintDip
    }
  } else if state == 2 {
    deadT += 1
    // turn to face the creature
    let want2 = atan2(mx - px, pz - mz)
    let diff = want2 - yaw
    if diff > 1800 {
      diff -= 3600
    }
    if diff < 0 - 1800 {
      diff += 3600
    }
    yaw += diff / 4
    // it lunges the last bit
    if deadT < 20 {
      moveMon(px, pz, 40)
    }
    placeMonster()
    camera3d px / 10, 165, pz / 10, yaw, 0
  } else if state == 3 {
    rideT += 1
    if rideT == 70 {
      tone 330 for 200ms
    }
    if rideT >= 160 {
      floor += 1
      state = 1
      newFloor()
      if musicOn == 1 {
        music "e3 - - - - - - - - - - - d#3 - - -", "a1 - - - - - - - - - - - - - - -" tempo 46
      }
    }
    camera3d px / 10, 165 + random(0 - 2, 2), pz / 10, yaw, 0
  } else if state == 4 {
    camera3d px / 10, 165, pz / 10, yaw, 0
  }
  render3d
  hud()
}
