// =====================================================================
//  THE NIGHTSHIFT - a first-person 3D horror game, written in Volt
//
//  You work the night shift in an endless underground facility.
//  Find the 3 energy charges on each floor, get back to the elevator
//  and ride down. The Hunter is always somewhere in the dark.
//
//  W A S D   walk              mouse (click first)   look   (or the arrow keys)
//  SHIFT     sprint (loud!)    E                     hide in a locker / call the elevator
//  M         music on/off      ENTER                 start / try again
//
//  The world is made of 3D models (Kenney, CC0) that were recoloured for this game.
//  Units: 1 = 1 cm in the 3D world. Positions are kept in millimetres (x10).
// =====================================================================
#html
title "The Nightshift"
canvas 320, 180
world3d "#02060c" fog 2800 ambient 9 shadows

model3d inter = "models/k_corridor_intersection.glb"
model3d corr = "models/k_corridor.glb"
model3d corn = "models/k_corridor_corner.glb"
model3d endp = "models/k_corridor_end.glb"
model3d jun = "models/k_corridor_junction.glb"
model3d gate = "models/k_gate_door.glb"
model3d hunter = "models/hunter.glb"
model3d raider = "models/raider.glb"
model3d coworker = "models/coworker.glb"
model3d tableL = "models/s_table_large.glb"
model3d tallM = "models/s_container_tall.glb"
model3d crateM = "models/s_container.glb"
model3d compM = "models/s_computer.glb"
model3d pipeM = "models/s_pipe.glb"
model3d pipeBM = "models/s_pipe_bend.glb"
model3d tableM = "models/s_table.glb"
model3d chairM = "models/s_chair.glb"

// ---------- the map: a maze of 4 metre tiles ----------
let MW = 8
let MH = 8
let CS = 4000                // one tile is 4 m (4000 mm)
let opE = []                 // opE[c] = 1 when tile c is open to the east
let opS = []                 // opS[c] = 1 when tile c is open to the south
let seen = []
let stack = []
let nb = []
let dist = []                // distance-to-target for the creature's pathfinding
let queue = []
let startC = 0               // the tile with the elevator
let lockC = []               // lockers: tile and wall direction
let lockD = []
let lockX = []
let lockZ = []
let cellX = []               // energy charges (millimetres)
let cellZ = []
let cellGot = []
let cellId = []
let cellLamp = []
let flLamp = []              // overhead lights: lamp, glowing panel, flicker timer
let flPanel = []
let flT = []
let deskX = []               // desks you can search
let deskZ = []
let deskDir = []
let deskDone = []
let dropKind = []            // things lying on the floor: 1 crowbar, 2 light emitter
let dropX = []
let dropZ = []
let dropId = []
let dropGot = []
let crowN = 0                // crowbars you carry (key 2)
let emitN = 1                // light emitters you carry (key 1)
let emitId = 0               // the emitter you threw
let emitLamp = 0
let emitT = 0
let emitFocus = 0            // the Hunter is walking to your emitter
let axeN = 0                 // fire axes (key 3)
let bandN = 0                // bandages (key 4)
let hp = 3
let invuln = 0
let dmgFlash = 0
let swingCD = 0
// ---------- the Raider (every fifth floor) ----------
let rdist = []              // the Raiders' distance map (everything that follows you uses it)
let rX = []                  // Raiders: position, health, stun, facing, model, animation
let rZ = []
let rHp = []
let rStun = []
let rYaw = []
let rId = []
let rAnim = []
let rpath = 0
// ---------- scrap, the workbench, the lost coworker, money ----------
let scrapN = 0
let money = 0
let saved2 = 0
let benchX = 0
let benchDir = 0
let benchZ = 0
let cwX = 0
let cwZ = 0
let cwYaw = 0
let cwState = 0              // 0 trapped, 1 following you, 2 safe
let cwId = 0
let cwAnim = 9
let explored = []            // tiles you have seen (for the map)
let eMap = []                // path distance to the elevator, and to each charge
let c0Map = []
let c1Map = []
let c2Map = []
let scanned = 0              // the workstation has marked the charges
let showMap = 0
let deskKind = []            // 0 desk, 1 supply crate
let cellG1 = []
let cellG2 = []

// ---------- game state ----------
let state = 0                // 0 title, 1 playing, 2 caught, 3 riding, 4 escaped
let floor = 1
let best = saved("ns_best", 1)
let t = 0
let cells = 0
let px = 0                   // player position in mm
let pz = 0
let yaw = 0                  // tenths of a degree
let pitch = 0
let stam = 600
let tired = 0
let hidden = 0
let hideIdx = 0
let hideCool = 0
let seenHiding = 0
let stepAcc = 0
let bob = 0
let msg = ""
let msgT = 0
let fadeIn = 90
let rideT = 0
let deadT = 0
let won = 0
let musicOn = 1
let gateOpen = 0
let gateId = 0
let zoneName = ""

// ---------- the Hunter ----------
let hunterId = 0
let hanim = 9
let mx = 0                   // position in mm
let mz = 0
let myaw = 0
let mstate = 0               // 0 patrol, 1 chase, 2 investigate, 3 sniff
let mtimer = 0
let mlost = 0
let mgoalC = 0               // tile the Hunter is heading for
let mpath = 0
let rolled = 0
let hbT = 0
let alertCool = 0
let monLamp = 0
let elevRed = 0
let elevGreen = 0
let elevInd = 0

// ---------- helpers ----------
fn dst(ax, ay, bx, by) {
  let dx = abs(ax - bx)
  let dy = abs(ay - by)
  return max(dx, dy) + min(dx, dy) * 4 / 10
}

fn dirX(d) {
  if d == 0 {
    return 1
  }
  if d == 2 {
    return 0 - 1
  }
  return 0
}

fn dirZ(d) {
  if d == 1 {
    return 1
  }
  if d == 3 {
    return 0 - 1
  }
  return 0
}

// is tile c open in direction d? (0 east, 1 south, 2 west, 3 north)
fn canGo(c, d) {
  let cx = c % MW
  let cy = c / MW
  if d == 0 {
    if cx >= MW - 1 {
      return 0
    }
    return opE[c]
  }
  if d == 1 {
    if cy >= MH - 1 {
      return 0
    }
    return opS[c]
  }
  if d == 2 {
    if cx <= 0 {
      return 0
    }
    return opE[c - 1]
  }
  if cy <= 0 {
    return 0
  }
  return opS[c - MW]
}

fn setEdge(c, d, v) {
  let cx = c % MW
  let cy = c / MW
  if d == 0 and cx < MW - 1 {
    opE[c] = v
  }
  if d == 1 and cy < MH - 1 {
    opS[c] = v
  }
  if d == 2 and cx > 0 {
    opE[c - 1] = v
  }
  if d == 3 and cy > 0 {
    opS[c - MW] = v
  }
}

fn nbr(c, d) {
  if d == 0 {
    return c + 1
  }
  if d == 1 {
    return c + MW
  }
  if d == 2 {
    return c - 1
  }
  return c - MW
}

fn inGrid(c, d) {
  let cx = c % MW
  let cy = c / MW
  if d == 0 and cx >= MW - 1 {
    return 0
  }
  if d == 1 and cy >= MH - 1 {
    return 0
  }
  if d == 2 and cx <= 0 {
    return 0
  }
  if d == 3 and cy <= 0 {
    return 0
  }
  return 1
}

// can a body of radius r stand at (x, z)? (millimetres). Walls are 1.6 m from a tile's middle.
fn blocked(x, z, r) {
  if x < 0 or z < 0 {
    return 1
  }
  let cx = x / CS
  let cz = z / CS
  if cx >= MW or cz >= MH {
    return 1
  }
  let c = cz * MW + cx
  let lx = x - cx * CS - 2000
  let lz = z - cz * CS - 2000
  let lim = 1600 - r
  if lx > lim and canGo(c, 0) == 0 {
    return 1
  }
  if lx < 0 - lim and canGo(c, 2) == 0 {
    return 1
  }
  if lz > lim and canGo(c, 1) == 0 {
    return 1
  }
  if lz < 0 - lim and canGo(c, 3) == 0 {
    return 1
  }
  if abs(lx) > lim and abs(lz) > lim {
    return 1
  }
  return 0
}

// can (x0, z0) see (x1, z1) without a wall in between?
fn los(x0, z0, x1, z1) {
  let d = dst(x0, z0, x1, z1)
  let n = d / 300 + 1
  for i from 1 to n {
    let sx = x0 + (x1 - x0) * i / n
    let sz = z0 + (z1 - z0) * i / n
    if blocked(sx, sz, 1) == 1 {
      return 0
    }
  }
  return 1
}

fn say(text1, frames) {
  msg = text1
  msgT = frames
}

fn zoneOf() {
  return (floor - 1) % 3 + 1
}

// ---------- making a floor ----------
fn makeMap() {
  opE = []
  opS = []
  seen = []
  dist = []
  rdist = []
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
    add 0 to opE
    add 0 to opS
    add 0 to seen
    add 9999 to dist
    add 9999 to rdist
  }
  // the elevator is on the south edge
  startC = (MH - 1) * MW + random(1, MW - 2)
  stack = []
  seen[startC] = 1
  add startC to stack
  while length(stack) > 0 {
    let top = stack[length(stack) - 1]
    nb = []
    for d from 0 to 3 {
      if inGrid(top, d) == 1 {
        if seen[nbr(top, d)] == 0 {
          add d to nb
        }
      }
    }
    if length(nb) == 0 {
      remove stack[length(stack) - 1]
    } else {
      let pick = nb[random(0, length(nb) - 1)]
      setEdge(top, pick, 1)
      let nx = nbr(top, pick)
      seen[nx] = 1
      add nx to stack
    }
  }
  // a few extra doorways so there are loops to run round
  for k from 1 to 12 {
    let c = random(0, MW * MH - 1)
    let d = random(0, 3)
    if c != startC and inGrid(c, d) == 1 {
      if nbr(c, d) != startC {
        setEdge(c, d, 1)
      }
    }
  }
}

fn bfs(goal) {
  let n = MW * MH
  let i = 0
  while i < n {
    dist[i] = 9999
    i += 1
  }
  queue = []
  dist[goal] = 0
  add goal to queue
  let head = 0
  while head < length(queue) {
    let cur = queue[head]
    head += 1
    let d1 = dist[cur] + 1
    for d from 0 to 3 {
      if canGo(cur, d) == 1 {
        let nx = nbr(cur, d)
        if dist[nx] > d1 {
          dist[nx] = d1
          add nx to queue
        }
      }
    }
  }
}

fn bfsMap(arr, goal) {
  let n = MW * MH
  let i = 0
  while i < n {
    arr[i] = 9999
    i += 1
  }
  let q = [goal]
  arr[goal] = 0
  let head = 0
  while head < length(q) {
    let cur = q[head]
    head += 1
    let d1 = arr[cur] + 1
    for d from 0 to 3 {
      if canGo(cur, d) == 1 {
        let nx = nbr(cur, d)
        if arr[nx] > d1 {
          arr[nx] = d1
          add nx to q
        }
      }
    }
  }
}

// which way to walk from here to reach the goal this map leads to (-1: you are there)
fn stepDir(arr) {
  let c = cellOf(px, pz)
  let goDir = 0 - 1
  let bd = arr[c]
  for d from 0 to 3 {
    if canGo(c, d) == 1 {
      if arr[nbr(c, d)] < bd {
        bd = arr[nbr(c, d)]
        goDir = d
      }
    }
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

// the charge whose path from you is shortest (0..2), or -1 when none are left
fn nearestCharge() {
  let c = cellOf(px, pz)
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
  return pick1
}

fn placeThings() {
  px = (startC % MW) * CS + 2000
  pz = (startC / MW) * CS + 2000
  yaw = 0
  for d0 from 0 to 3 {
    if canGo(startC, d0) == 1 {
      yaw = ((d0 + 3) % 4) * 900
    }
  }
  pitch = 0
  bfs(startC)
  // the Hunter starts in the tile farthest from the elevator
  let far = 0
  let fd = 0
  for c from 0 to MW * MH - 1 {
    if dist[c] > fd and dist[c] < 9999 {
      fd = dist[c]
      far = c
    }
  }
  mx = (far % MW) * CS + 2000
  mz = (far / MW) * CS + 2000
  // three charges in different tiles, never near the elevator or the Hunter's own tile
  cellX = []
  cellZ = []
  cellGot = []
  let used = [far, startC]
  let found = 0
  let tries = 0
  while found < 3 and tries < 500 {
    tries += 1
    let c = random(0, MW * MH - 1)
    let ok = 1
    if dist[c] < 4 or dist[c] > 9000 {
      ok = 0
    }
    for u from 0 to length(used) - 1 {
      if used[u] == c {
        ok = 0
      }
    }
    if ok == 1 {
      add c to used
      let ccx = (c % MW) * CS + 2000
      let ccz = (c / MW) * CS + 2000
      add ccx to cellX
      add ccz to cellZ
      add 0 to cellGot
      found += 1
    }
  }
  while found < 3 {
    add mx to cellX
    add mz to cellZ
    add 0 to cellGot
    found += 1
  }
  bfsMap(eMap, startC)
  bfsMap(c0Map, cellOf(cellX[0], cellZ[0]))
  bfsMap(c1Map, cellOf(cellX[1], cellZ[1]))
  bfsMap(c2Map, cellOf(cellX[2], cellZ[2]))
  scanned = 0
  // lockers, each against a closed wall
  lockC = []
  lockD = []
  lockX = []
  lockZ = []
  tries = 0
  while length(lockC) < 6 and tries < 400 {
    tries += 1
    let c2 = random(0, MW * MH - 1)
    let d2 = random(0, 3)
    if c2 != startC and c2 != far and canGo(c2, d2) == 0 {
      let dup = 0
      for q from 0 to length(lockC) - 1 {
        if lockC[q] == c2 {
          dup = 1
        }
      }
      if dup == 0 {
        add c2 to lockC
        add d2 to lockD
        let lkx2 = (c2 % MW) * CS + 2000 + dirX(d2) * 1250
        let lkz2 = (c2 / MW) * CS + 2000 + dirZ(d2) * 1250
        add lkx2 to lockX
        add lkz2 to lockZ
      }
    }
  }
  // Raiders (like the cultists in 99 Nights) raid you on every fifth floor
  rX = []
  rZ = []
  rHp = []
  rStun = []
  rYaw = []
  rAnim = []
  let nRaid = 0
  if floor % 5 == 0 {
    nRaid = min(3, floor / 5)
  }
  let placed = 0
  let rt = 0
  while placed < nRaid and rt < 600 {
    rt += 1
    let rc = random(0, MW * MH - 1)
    if dist[rc] >= 6 and dist[rc] < 9999 and rc != far {
      let rxv = (rc % MW) * CS + 2000
      let rzv = (rc / MW) * CS + 2000
      add rxv to rX
      add rzv to rZ
      add 6 to rHp
      add 0 to rStun
      add 0 to rYaw
      add 9 to rAnim
      placed += 1
    }
  }
  // the workbench: a wall close to the elevator
  benchX = 0
  benchZ = 0
  let bt = 0
  while benchX == 0 and bt < 400 {
    bt += 1
    let bc = random(0, MW * MH - 1)
    let bd = random(0, 3)
    if dist[bc] >= 1 and dist[bc] <= 3 and canGo(bc, bd) == 0 {
      benchX = (bc % MW) * CS + 2000 + dirX(bd) * 1150
      benchZ = (bc / MW) * CS + 2000 + dirZ(bd) * 1150
      benchDir = bd
    }
  }
  if benchX == 0 {
    benchX = px + 800
    benchZ = pz - 1100
    benchDir = 3
  }
  // a coworker is trapped somewhere deep in the floor
  cwState = 0
  cwAnim = 9
  let ct = 0
  while ct < 400 {
    ct += 1
    let cc2 = random(0, MW * MH - 1)
    if dist[cc2] >= 5 and dist[cc2] < 9999 and cc2 != far {
      cwX = (cc2 % MW) * CS + 2000
      cwZ = (cc2 / MW) * CS + 2000
      ct = 999
    }
  }
  myaw = 0
  mstate = 0
  mtimer = 0
  mlost = 0
  emitFocus = 0
  pickWaypoint()
}

fn pickWaypoint() {
  mgoalC = random(0, MW * MH - 1)
  bfs(mgoalC)
}

fn cellOf(x, z) {
  return (z / CS) * MW + x / CS
}

// ---------- building the 3D scene ----------
fn placeTile(c) {
  let cx = c % MW
  let cz = c / MW
  let e = canGo(c, 0)
  let s2 = canGo(c, 1)
  let w = canGo(c, 2)
  let n = canGo(c, 3)
  let cnt = e + s2 + w + n
  let x = cx * 400 + 200
  let z = cz * 400 + 200
  let tid = 0
  if cnt >= 4 {
    tid = put3d(inter, x, 0, z, 0, 100)
  } else if cnt == 3 {
    let closed = 0
    if s2 == 0 {
      closed = 1
    }
    if w == 0 {
      closed = 2
    }
    if n == 0 {
      closed = 3
    }
    tid = put3d(jun, x, 0, z, ((closed + 3) % 4) * 900, 100)
  } else if cnt == 2 {
    if e == 1 and w == 1 {
      tid = put3d(corr, x, 0, z, 0, 100)
    } else if s2 == 1 and n == 1 {
      tid = put3d(corr, x, 0, z, 900, 100)
    } else {
      let d = 0
      if s2 == 1 and w == 1 {
        d = 1
      }
      if w == 1 and n == 1 {
        d = 2
      }
      if n == 1 and e == 1 {
        d = 3
      }
      tid = put3d(corn, x, 0, z, ((d + 2) % 4) * 900, 100)
    }
  } else {
    let k = 0
    if s2 == 1 {
      k = 1
    }
    if w == 1 {
      k = 2
    }
    if n == 1 {
      k = 3
    }
    tid = put3d(endp, x, 0, z, k * 900, 100)
  }
}

fn addProp(kind, x, z, yw) {
  let pid = 0
  if kind == 0 {
    pid = put3d(crateM, x, 0, z, yw, 170)
  } else if kind == 1 {
    pid = put3d(compM, x, 0, z, yw, 190)
  } else if kind == 2 {
    pid = put3d(pipeM, x, 130, z, yw, 130)
  } else if kind == 3 {
    pid = put3d(pipeBM, x, 130, z, yw, 130)
  } else if kind == 4 {
    pid = put3d(tableM, x, 0, z, yw, 170)
  } else {
    pid = put3d(chairM, x, 0, z, yw, 170)
  }
}

fn build3d() {
  clear3d
  torch3d 11, 2400
  let zone = zoneOf()
  for c from 0 to MW * MH - 1 {
    placeTile(c)
  }
  let roof = block3d(MW * 200, 440, MH * 200, MW * 400 + 100, 10, MH * 400 + 100, "#141418")
  // props along the walls: crates in the halls, pipes in the boiler room, desks in storage
  for k from 1 to 22 {
    let c = random(0, MW * MH - 1)
    let d = random(0, 3)
    if c != startC and canGo(c, d) == 0 {
      let offs = random(0 - 500, 500)
      let x = (c % MW) * CS + 2000 + dirX(d) * 1250 + dirZ(d) * offs
      let z = (c / MW) * CS + 2000 + dirZ(d) * 1250 + dirX(d) * offs
      let kind = 0
      if zone == 1 {
        kind = random(0, 1)
      } else if zone == 2 {
        kind = random(2, 3)
      } else {
        kind = random(4, 5)
      }
      addProp(kind, x / 10, z / 10, ((d + 1) % 4) * 900)
    }
  }
  // lights
  let lc = "#5ab4ff"
  if zone == 2 {
    lc = "#ff8a3a"
  }
  if zone == 3 {
    lc = "#7a8cff"
  }
  flLamp = []
  flPanel = []
  flT = []
  for k2 from 1 to 9 {
    let c3 = random(0, MW * MH - 1)
    let l1 = lamp3d((c3 % MW) * 400 + 200, 330, (c3 / MW) * 400 + 200, lc, 15, 800)
    let panel = block3d((c3 % MW) * 400 + 200, 436, (c3 / MW) * 400 + 200, 130, 4, 28, "#bfe6ff")
    glow3d panel, lc
    add l1 to flLamp
    add panel to flPanel
    add 0 to flT
  }
  // desks: search them with E, they drop tools
  deskX = []
  deskZ = []
  deskDir = []
  deskDone = []
  deskKind = []
  dropKind = []
  dropX = []
  dropZ = []
  dropId = []
  dropGot = []
  let tries2 = 0
  while length(deskX) < 9 and tries2 < 500 {
    tries2 += 1
    let c4 = random(0, MW * MH - 1)
    let d4 = random(0, 3)
    if c4 != startC and canGo(c4, d4) == 0 {
      let dx4 = (c4 % MW) * CS + 2000 + dirX(d4) * 1100
      let dz4 = (c4 / MW) * CS + 2000 + dirZ(d4) * 1100
      let near4 = 0
      for q4 from 0 to length(deskX) - 1 {
        if dst(deskX[q4], deskZ[q4], dx4, dz4) < 3500 {
          near4 = 1
        }
      }
      if near4 == 0 {
        add dx4 to deskX
        add dz4 to deskZ
        add d4 to deskDir
        add 0 to deskDone
        let yw4 = ((d4 + 1) % 4) * 900
        if length(deskX) <= 5 {
          add 0 to deskKind
          let dk = put3d(tableM, dx4 / 10, 0, dz4 / 10, yw4, 150)
          let pc = put3d(compM, dx4 / 10, 60, dz4 / 10, yw4 + 1800, 110)
        } else {
          add 1 to deskKind
          let cr = put3d(crateM, dx4 / 10, 0, dz4 / 10, yw4, 190)
          let cr2 = put3d(crateM, dx4 / 10 + dirZ(d4) * 55, 0, dz4 / 10 + dirX(d4) * 55, yw4 + 300, 150)
        }
      }
    }
  }
  // the emitter you throw (hidden until used)
  emitId = block3d(0, 0, 0, 14, 14, 14, "#9fe8ff")
  glow3d emitId, "#4de1ff"
  emitLamp = lamp3d(0, 0, 0, "#4de1ff", 45, 1300)
  show3d emitId, 0
  show3d emitLamp, 0
  emitT = 0
  // lockers
  let i = 0
  while i < length(lockC) {
    let lk = put3d(tallM, lockX[i] / 10, 0, lockZ[i] / 10, ((lockD[i] + 1) % 4) * 900, 190)
    i += 1
  }
  // the elevator: a gate set into the south wall of the first tile
  let gx = (startC % MW) * 400 + 200
  let gz = (startC / MW) * 400 + 200 + 190
  gateId = put3d(gate, gx, 0, gz, 0, 100)
  anim3d gateId, "close"
  gateOpen = 0
  elevInd = block3d(gx, 330, gz - 60, 50, 10, 4, "#300000")
  glow3d elevInd, "#ff2a1a"
  elevRed = lamp3d(gx, 260, gz - 120, "#ff3322", 14, 520)
  elevGreen = lamp3d(gx, 260, gz - 120, "#33ff77", 14, 520)
  show3d elevGreen, 0
  // energy charges
  cellId = []
  cellLamp = []
  cellG1 = []
  cellG2 = []
  for c2 from 0 to 2 {
    let cb = block3d(cellX[c2] / 10, 110, cellZ[c2] / 10, 24, 36, 24, "#5d6770")
    let cs1 = block3d(cellX[c2] / 10, 110, cellZ[c2] / 10, 12, 28, 26, "#7fefff")
    glow3d cs1, "#4de1ff"
    let cs2 = block3d(cellX[c2] / 10, 130, cellZ[c2] / 10, 26, 4, 26, "#c9a227")
    add cb to cellId
    add cs1 to cellG1
    add cs2 to cellG2
    add lamp3d(cellX[c2] / 10, 120, cellZ[c2] / 10, "#4de1ff", 22, 520) to cellLamp
  }
  // the Hunter
  hunterId = put3d(hunter, mx / 10, 0, mz / 10, 0, 112)
  hanim = 9
  setAnim(0)
  monLamp = lamp3d(0, 150, 0, "#ff2211", 10, 340)
  placeMonster()
  rId = []
  let ri = 0
  while ri < length(rX) {
    let rm = put3d(raider, rX[ri] / 10, 0, rZ[ri] / 10, 0, 108)
    add rm to rId
    rAnim[ri] = 9
    setRAnim(ri, 1)
    ri += 1
  }
  // the workbench
  let bw = put3d(tableL, benchX / 10, 0, benchZ / 10, ((benchDir + 1) % 4) * 900, 150)
  let bc1 = put3d(compM, benchX / 10 - dirZ(benchDir) * 35, 60, benchZ / 10 + dirX(benchDir) * 35, ((benchDir + 3) % 4) * 900, 110)
  let bstrip = block3d(benchX / 10 - dirX(benchDir) * 40, 62, benchZ / 10 - dirZ(benchDir) * 40, 12, 3, 12, "#ffb347")
  glow3d bstrip, "#ffb347"
  let bl = lamp3d(benchX / 10 - dirX(benchDir) * 60, 130, benchZ / 10 - dirZ(benchDir) * 60, "#ffb347", 14, 420)
  // the trapped coworker
  cwId = put3d(coworker, cwX / 10, 0, cwZ / 10, random(0, 3) * 900, 100)
  anim3d cwId, "sit"
  cwAnim = 0
}

fn setAnim(a) {
  if a == hanim {
    return 0
  }
  hanim = a
  if a == 0 {
    anim3d hunterId, "walk"
  } else if a == 1 {
    anim3d hunterId, "sprint"
  } else {
    anim3d hunterId, "idle"
  }
}

fn setRAnim(i, a) {
  if rAnim[i] == a {
    return 0
  }
  rAnim[i] = a
  if a == 1 {
    anim3d rId[i], "sprint"
  } else if a == 2 {
    anim3d rId[i], "idle"
  } else {
    anim3d rId[i], "attack-melee-right"
  }
}

fn raidersAlive() {
  let n = 0
  let i = 0
  while i < length(rHp) {
    if rHp[i] > 0 {
      n += 1
    }
    i += 1
  }
  return n
}

// the living Raider closest to you (or -1)
fn nearestRaider() {
  let bi = 0 - 1
  let bd = 99999
  let i = 0
  while i < length(rHp) {
    if rHp[i] > 0 {
      let d = dst(px, pz, rX[i], rZ[i])
      if d < bd {
        bd = d
        bi = i
      }
    }
    i += 1
  }
  return bi
}

fn placeMonster() {
  move3d hunterId, mx / 10, 0, mz / 10
  turn3d hunterId, myaw + 1800
  move3d monLamp, mx / 10, 150, mz / 10
}

fn newFloor() {
  makeMap()
  placeThings()
  build3d()
  cells = 0
  showMap = 0
  hidden = 0
  invuln = 0
  dmgFlash = 0
  stam = 600
  tired = 0
  msg = ""
  msgT = 0
  fadeIn = 90
  mpath = 0
  bestCheck()
  let z = zoneOf()
  if z == 1 {
    zoneName = "CONCRETE HALLS"
  } else if z == 2 {
    zoneName = "BOILER ROOM"
  } else {
    zoneName = "DEEP STORAGE"
  }
  if length(rX) > 0 {
    say("RAIDERS ON THIS FLOOR - FIND A WEAPON", 260)
  } else if floor == 1 {
    say("FIND 3 ENERGY CHARGES", 240)
  } else {
    say("FLOOR " + floor + " - " + zoneName, 180)
  }
}

fn bestCheck() {
  if floor > best {
    best = floor
    save "ns_best", best
  }
}

// ---------- pathfinding for the Hunter ----------
// the neighbouring tile that is closest to the goal
fn nextCell() {
  let c = cellOf(mx, mz)
  let bestN = c
  let bd = dist[c]
  for d from 0 to 3 {
    if canGo(c, d) == 1 {
      let nx = nbr(c, d)
      if dist[nx] < bd {
        bd = dist[nx]
        bestN = nx
      }
    }
  }
  return bestN
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
  if blocked(nx, nz, 450) == 0 {
    mx = nx
    mz = nz
  } else if blocked(nx, mz, 450) == 0 {
    mx = nx
  } else if blocked(mx, nz, 450) == 0 {
    mz = nz
  }
  myaw = atan2(gx - mx, mz - gz)
  return 1
}

fn followPath(spd) {
  let nc = nextCell()
  moveMon((nc % MW) * CS + 2000, (nc / MW) * CS + 2000, spd)
}

// the Raider has its own distance map, so it never confuses the Hunter's path
fn bfsR(goal) {
  let n = MW * MH
  let i = 0
  while i < n {
    rdist[i] = 9999
    i += 1
  }
  let q = [goal]
  rdist[goal] = 0
  let head = 0
  while head < length(q) {
    let cur = q[head]
    head += 1
    let d1 = rdist[cur] + 1
    for d from 0 to 3 {
      if canGo(cur, d) == 1 {
        let nx = nbr(cur, d)
        if rdist[nx] > d1 {
          rdist[nx] = d1
          add nx to q
        }
      }
    }
  }
}

// the neighbouring tile closest to you, for anything standing at (x, z)
fn nextCellAt(x, z) {
  let c = cellOf(x, z)
  let bestN = c
  let bd = rdist[c]
  for d from 0 to 3 {
    if canGo(c, d) == 1 {
      let nx = nbr(c, d)
      if rdist[nx] < bd {
        bd = rdist[nx]
        bestN = nx
      }
    }
  }
  return bestN
}

fn moveRaider(i, gx, gz, spd) {
  let d = dst(rX[i], rZ[i], gx, gz)
  if d < 1 {
    return 0
  }
  let nx = rX[i]
  let nz = rZ[i]
  if d <= spd {
    nx = gx
    nz = gz
  } else {
    nx = rX[i] + (gx - rX[i]) * spd / d
    nz = rZ[i] + (gz - rZ[i]) * spd / d
  }
  if blocked(nx, nz, 450) == 0 {
    rX[i] = nx
    rZ[i] = nz
  } else if blocked(nx, rZ[i], 450) == 0 {
    rX[i] = nx
  } else if blocked(rX[i], nz, 450) == 0 {
    rZ[i] = nz
  }
  rYaw[i] = atan2(gx - rX[i], rZ[i] - gz)
  return 1
}

fn hurt(n, fx, fz) {
  hp -= n
  invuln = 90
  dmgFlash = 24
  tone 150 to 60 for 220ms
  // shove the player away from whatever hit them
  let d = dst(px, pz, fx, fz)
  let kx = px + (px - fx) * 900 / max(1, d)
  let kz = pz + (pz - fz) * 900 / max(1, d)
  if blocked(kx, kz, 420) == 0 {
    px = kx
    pz = kz
  }
  if hp <= 0 {
    hp = 0
    caught()
  } else {
    say("THE RAIDER HIT YOU", 80)
  }
}

fn chaseMap() {
  if length(rX) > 0 or cwState == 1 {
    rpath += 1
    if rpath >= 10 {
      rpath = 0
      bfsR(cellOf(px, pz))
    }
  }
}

fn raiderFrame() {
  let n = length(rX)
  if n == 0 {
    return 0
  }
  let i = 0
  while i < n {
    if rHp[i] > 0 {
      if rStun[i] > 0 {
        rStun[i] = rStun[i] - 1
        setRAnim(i, 2)
      } else {
        let d = dst(px, pz, rX[i], rZ[i])
        let spd = 28 + floor + i * 2
        if hidden == 0 and d < 5000 and los(rX[i], rZ[i], px, pz) == 1 {
          moveRaider(i, px, pz, spd)
        } else {
          let nc = nextCellAt(rX[i], rZ[i])
          moveRaider(i, (nc % MW) * CS + 2000, (nc / MW) * CS + 2000, spd)
        }
        if d < 1700 {
          setRAnim(i, 3)
        } else {
          setRAnim(i, 1)
        }
        if state == 1 and invuln == 0 and hidden == 0 and d < 1000 {
          hurt(1, rX[i], rZ[i])
          rStun[i] = 45
        }
        // they drag you out of a locker if they find you
        if hidden == 1 and dst(rX[i], rZ[i], lockX[hideIdx], lockZ[hideIdx]) < 2000 {
          hidden = 0
          hideCool = 30
          px = (lockC[hideIdx] % MW) * CS + 2000
          pz = (lockC[hideIdx] / MW) * CS + 2000
          hurt(1, rX[i], rZ[i])
          rStun[i] = 45
        }
      }
      move3d rId[i], rX[i] / 10, 0, rZ[i] / 10
      turn3d rId[i], rYaw[i] + 1800
    }
    i += 1
  }
}

// the coworker you freed follows you
fn coworkerFrame() {
  if cwState != 1 {
    return 0
  }
  let d = dst(px, pz, cwX, cwZ)
  if d > 2000 {
    let nc = nextCellAt(cwX, cwZ)
    let gx = (nc % MW) * CS + 2000
    let gz = (nc / MW) * CS + 2000
    if cellOf(cwX, cwZ) == cellOf(px, pz) {
      gx = px
      gz = pz
    }
    let gd = max(1, dst(cwX, cwZ, gx, gz))
    let nx = cwX + (gx - cwX) * 25 / gd
    let nz = cwZ + (gz - cwZ) * 25 / gd
    if blocked(nx, nz, 400) == 0 {
      cwX = nx
      cwZ = nz
    }
    cwYaw = atan2(gx - cwX, cwZ - gz)
    if cwAnim != 1 {
      cwAnim = 1
      anim3d cwId, "walk"
    }
  } else if cwAnim != 2 {
    cwAnim = 2
    anim3d cwId, "idle"
  }
  move3d cwId, cwX / 10, 0, cwZ / 10
  turn3d cwId, cwYaw + 1800
}

// ---------- the Hunter's brain ----------
fn monsterFrame() {
  let spdPatrol = 16 + floor * 3
  let spdChase = 24 + floor * 6
  let sight = 11000 + floor * 500
  let d = dst(px, pz, mx, mz)
  let sees = 0
  if hidden == 0 and d < sight {
    sees = los(mx, mz, px, pz)
  }
  if alertCool > 0 {
    alertCool -= 1
  }
  if mstate == 4 and sees == 1 and d < 3200 {
    mstate = 3
  }
  if mstate == 0 or mstate == 2 or mstate == 3 {
    if sees == 1 {
      mstate = 1
      mlost = 0
      emitFocus = 0
      mgoalC = cellOf(px, pz)
      bfs(mgoalC)
      mpath = 0
      tone 180 to 60 for 350ms
      say("IT SEES YOU - RUN", 120)
    } else if hidden == 0 and mstate != 1 {
      let heard = 0
      if stepAcc > 0 and held("shift") and tired == 0 and d < 9000 {
        heard = 1
      }
      if d < 3000 {
        heard = 1
      }
      if heard == 1 and alertCool == 0 and mstate != 2 {
        mstate = 2
        mgoalC = cellOf(px, pz)
        bfs(mgoalC)
        alertCool = 240
      }
    }
  }
  let gcx = (mgoalC % MW) * CS + 2000
  let gcz = (mgoalC / MW) * CS + 2000
  if mstate == 0 {
    setAnim(0)
    followPath(spdPatrol)
    if dst(mx, mz, gcx, gcz) < 600 {
      mstate = 3
      mtimer = 120
      rolled = 1
    }
  } else if mstate == 1 {
    setAnim(1)
    if sees == 1 {
      mlost = 0
      mgoalC = cellOf(px, pz)
    } else {
      mlost += 1
    }
    mpath += 1
    if mpath >= 8 {
      mpath = 0
      bfs(mgoalC)
    }
    if sees == 1 and d < 5000 {
      moveMon(px, pz, spdChase)
    } else {
      followPath(spdChase)
    }
    if sees == 0 and dst(mx, mz, gcx, gcz) < 700 {
      mstate = 3
      mtimer = 150
      rolled = 0
    }
    if sees == 0 and mlost > 420 {
      mstate = 0
      pickWaypoint()
    }
  } else if mstate == 2 {
    setAnim(0)
    if emitFocus == 1 {
      followPath(spdChase * 13 / 10)
    } else {
      followPath((spdPatrol + spdChase) / 2)
    }
    if dst(mx, mz, gcx, gcz) < 700 {
      if emitFocus == 1 {
        // the emitter has its full attention
        mstate = 4
        mtimer = 420
        emitFocus = 0
      } else {
        mstate = 3
        mtimer = 110
        rolled = 0
      }
    }
  } else if mstate == 4 {
    // staring at the emitter
    setAnim(2)
    mtimer -= 1
    if emitT <= 0 {
      mtimer = 0
    }
    if mtimer <= 0 {
      mstate = 0
      pickWaypoint()
    }
  } else if mstate == 3 {
    setAnim(2)
    mtimer -= 1
    myaw += 14
    if myaw >= 3600 {
      myaw -= 3600
    }
    if mtimer == 60 and rolled == 0 {
      rolled = 1
      if hidden == 1 {
        if dst(mx, mz, lockX[hideIdx], lockZ[hideIdx]) < 4200 {
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
  if state == 1 and hidden == 0 and dst(px, pz, mx, mz) < 900 {
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
  torch3d 0, 2400
  tone 900 to 90 for 600ms
  music off
}

// ---------- the player ----------
fn playerFrame() {
  if hideCool > 0 {
    hideCool -= 1
  }
  if hidden == 1 {
    stam = min(600, stam + 2)
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
  if blocked(px + dx, pz, 420) == 0 {
    px += dx
  }
  if blocked(px, pz + dz, 420) == 0 {
    pz += dz
  }
  if moving == 1 {
    stepAcc += spd
    bob += spd
    if stepAcc > 900 {
      stepAcc = 1
      tone 70 for 35ms
    }
  } else {
    stepAcc = 0
  }
  for c from 0 to 2 {
    if cellGot[c] == 0 and dst(px, pz, cellX[c], cellZ[c]) < 1000 {
      cellGot[c] = 1
      cells += 1
      money += 10
      show3d cellId[c], 0
      show3d cellG1[c], 0
      show3d cellG2[c], 0
      show3d cellLamp[c], 0
      tone 660 for 70ms
      if cells == 3 {
        tone 880 for 160ms
        say("ELEVATOR POWERED - GET BACK", 240)
        show3d elevRed, 0
        show3d elevGreen, 1
        glow3d elevInd, "#22ff66"
        mstate = 2
        mgoalC = cellOf(px, pz)
        bfs(mgoalC)
        alertCool = 600
      } else {
        say("ENERGY CHARGE " + cells + " / 3", 120)
      }
    }
  }
}

// picking things up off the floor
fn pickups() {
  let ec = cellOf(px, pz)
  explored[ec] = 1
  for d from 0 to 3 {
    if canGo(ec, d) == 1 {
      explored[nbr(ec, d)] = 1
    }
  }
  let i = 0
  while i < length(dropKind) {
    if dropGot[i] == 0 and dst(px, pz, dropX[i], dropZ[i]) < 1000 {
      dropGot[i] = 1
      show3d dropId[i], 0
      tone 520 for 60ms
      if dropKind[i] == 1 {
        crowN += 1
        say("CROWBAR - PRESS 2 TO SWING", 160)
      } else if dropKind[i] == 2 {
        emitN += 1
        say("LIGHT EMITTER - PRESS 1 TO THROW", 160)
      } else if dropKind[i] == 3 {
        axeN += 1
        say("FIRE AXE - PRESS 3 TO SWING", 160)
      } else if dropKind[i] == 4 {
        bandN += 1
        say("BANDAGE - PRESS 4 TO HEAL", 160)
      } else {
        scrapN += 1
        say("SCRAP +1 - CRAFT AT THE WORKBENCH (C)", 160)
      }
    }
    i += 1
  }
}

// overhead lights sometimes flicker
fn flickerFrame() {
  if invuln > 0 {
    invuln -= 1
  }
  if dmgFlash > 0 {
    dmgFlash -= 1
  }
  if swingCD > 0 {
    swingCD -= 1
  }
  let chance = 1400
  if zoneOf() == 2 {
    chance = 600
  }
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
    } else if random(1, chance) == 1 {
      flT[i] = random(20, 70)
    }
    i += 1
  }
  if emitT > 0 {
    emitT -= 1
    if emitT <= 0 {
      show3d emitId, 0
      show3d emitLamp, 0
    }
  }
}

// something is close: the flashlight misbehaves
fn torchFrame() {
  if hidden == 1 {
    torch3d 10, 2400
    return 0
  }
  let d = dst(px, pz, mx, mz)
  let pw = 11
  if d < 6500 and random(1, 100) <= 18 {
    pw = random(2, 8)
  }
  torch3d pw, 2400
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

// where you stand to use the elevator
fn elevX() {
  return (startC % MW) * CS + 2000
}

fn elevZ() {
  return (startC / MW) * CS + 2000 + 1600
}

// ---------- E: hide, leave a locker, call the elevator ----------
when key "e" pressed {
  interact()
}

fn interact() {
  if state != 1 {
    return 0
  }
  if hidden == 1 {
    hidden = 0
    hideCool = 30
    px = (lockC[hideIdx] % MW) * CS + 2000
    pz = (lockC[hideIdx] / MW) * CS + 2000
    return 0
  }
  if hideCool > 0 {
    return 0
  }
  let i = 0
  while i < length(lockC) {
    if dst(px, pz, lockX[i], lockZ[i]) < 2200 {
      hidden = 1
      hideIdx = i
      hideCool = 30
      seenHiding = 0
      if mstate == 1 and los(mx, mz, px, pz) == 1 and dst(mx, mz, px, pz) < 9000 {
        seenHiding = 1
      }
      yaw = ((lockD[i] + 3) % 4) * 900
      pitch = 0
      tone 120 for 60ms
      return 0
    }
    i += 1
  }
  if scanned == 0 and dst(px, pz, benchX, benchZ) < 2400 {
    scanned = 1
    tone 880 for 120ms
    tone 1180 for 160ms
    say("WORKSTATION SCAN: CHARGES MARKED ON THE MAP", 200)
    return 0
  }
  if cwState == 0 and dst(px, pz, cwX, cwZ) < 2200 {
    cwState = 1
    cwAnim = 9
    money += 50
    tone 660 for 90ms
    say("COWORKER FREED +$50 - GET THEM TO THE ELEVATOR", 200)
    return 0
  }
  let dI = 0
  while dI < length(deskX) {
    if deskDone[dI] == 0 and dst(px, pz, deskX[dI], deskZ[dI]) < 2000 {
      deskDone[dI] = 1
      let roll = random(1, 100)
      let kind = 5
      if floor % 5 == 0 {
        if roll <= 20 {
          kind = 1
        } else if roll <= 30 {
          kind = 2
        } else if roll <= 55 {
          kind = 3
        } else if roll <= 75 {
          kind = 4
        }
      } else {
        if roll <= 20 {
          kind = 1
        } else if roll <= 45 {
          kind = 2
        } else if roll <= 55 {
          kind = 3
        } else if roll <= 70 {
          kind = 4
        }
      }
      let ddx = deskX[dI] - dirX(deskDir[dI]) * 900
      let ddz = deskZ[dI] - dirZ(deskDir[dI]) * 900
      spawnDrop(kind, ddx, ddz)
      tone 300 for 80ms
      say("YOU FOUND SOMETHING", 100)
      return 0
    }
    dI += 1
  }
  if dst(px, pz, elevX(), elevZ()) < 2400 {
    if cells < 3 {
      say("NO POWER - " + cells + " / 3 CHARGES", 150)
      tone 140 for 120ms
    } else {
      if floor >= 3 and won == 0 {
        state = 4
        won = 1
        if cwState == 1 {
          cwState = 2
          saved2 += 1
          money += 100
        }
        bestCheck()
        music off
        tone 523 for 120ms
      } else {
        state = 3
        rideT = 0
        tone 440 for 120ms
        if cwState == 1 {
          cwState = 2
          saved2 += 1
          money += 100
        }
      }
    }
  }
}

// key 1: throw a light emitter - the Hunter goes to look at it
when key "1" pressed {
  useEmitter()
}

fn useEmitter() {
  if state != 1 or hidden == 1 or emitN <= 0 or emitT > 0 {
    return 0
  }
  emitN -= 1
  let tx = px + sin(yaw) * 2400 / 1000
  let tz = pz - cos(yaw) * 2400 / 1000
  if blocked(tx, tz, 300) == 1 {
    tx = px
    tz = pz
  }
  move3d emitId, tx / 10, 10, tz / 10
  move3d emitLamp, tx / 10, 60, tz / 10
  show3d emitId, 1
  show3d emitLamp, 1
  emitT = 6000
  tone 740 for 80ms
  say("EMITTER DOWN - THE HUNTER WILL GO LOOK", 120)
  if mstate != 1 {
    mstate = 2
    emitFocus = 1
    mgoalC = cellOf(tx, tz)
    bfs(mgoalC)
    alertCool = 600
  }
}

// keys 2 and 3: melee weapons - they only hurt the Raider
when key "2" pressed {
  if crowN > 0 {
    swing(1)
  }
}

when key "3" pressed {
  if axeN > 0 {
    swing(2)
  }
}

fn swing(dmg) {
  if state != 1 or hidden == 1 or swingCD > 0 {
    return 0
  }
  swingCD = 28
  tone 260 to 140 for 90ms
  // hit the closest Raider in front of you
  let bi = 0 - 1
  let bd = 99999
  let i = 0
  while i < length(rX) {
    if rHp[i] > 0 {
      let d = dst(px, pz, rX[i], rZ[i])
      let want = atan2(rX[i] - px, pz - rZ[i])
      let diff = want - yaw
      if diff > 1800 {
        diff -= 3600
      }
      if diff < 0 - 1800 {
        diff += 3600
      }
      if d < 2600 and abs(diff) < 800 and d < bd {
        bd = d
        bi = i
      }
    }
    i += 1
  }
  if bi >= 0 {
    rHp[bi] = rHp[bi] - dmg
    rStun[bi] = 55
    tone 120 to 50 for 140ms
    let kx = rX[bi] + (rX[bi] - px) * 900 / max(1, bd)
    let kz = rZ[bi] + (rZ[bi] - pz) * 900 / max(1, bd)
    if blocked(kx, kz, 450) == 0 {
      rX[bi] = kx
      rZ[bi] = kz
    }
    if rHp[bi] <= 0 {
      raiderDown(bi)
    } else {
      say("HIT!", 40)
    }
  }
}

fn raiderDown(i) {
  rHp[i] = 0
  show3d rId[i], 0
  tone 100 to 40 for 400ms
  money += 25
  if raidersAlive() == 0 {
    say("RAIDERS DOWN +$25", 140)
  } else {
    say("RAIDER DOWN +$25", 100)
  }
  spawnDrop(random(1, 4), rX[i], rZ[i])
  spawnDrop(5, rX[i] + 500, rZ[i])
}

// C at the workbench: turn scrap into gear
when key "c" pressed {
  craft()
}

fn craft() {
  if state != 1 or hidden == 1 {
    return 0
  }
  if dst(px, pz, benchX, benchZ) > 2400 {
    return 0
  }
  if scrapN >= 3 and axeN == 0 {
    scrapN -= 3
    axeN = 1
    say("CRAFTED A FIRE AXE", 120)
    tone 600 for 100ms
  } else if scrapN >= 2 and bandN < 3 {
    scrapN -= 2
    bandN += 1
    say("CRAFTED A BANDAGE", 100)
    tone 560 for 100ms
  } else if scrapN >= 1 {
    scrapN -= 1
    emitN += 1
    say("CRAFTED A LIGHT EMITTER", 100)
    tone 520 for 100ms
  } else {
    say("NEED SCRAP - SEARCH DESKS AND CRATES", 120)
    tone 140 for 100ms
  }
}

// key 4: use a bandage
when key "4" pressed {
  if state == 1 and bandN > 0 and hp < 3 {
    bandN -= 1
    hp += 1
    tone 500 for 80ms
    say("PATCHED UP", 80)
  }
}

fn spawnDrop(kind, x, z) {
  let item = 0
  if kind == 1 {
    item = block3d(x / 10, 4, z / 10, 6, 6, 52, "#9a2a2a")
  } else if kind == 2 {
    item = block3d(x / 10, 8, z / 10, 14, 14, 14, "#9fe8ff")
    glow3d item, "#4de1ff"
  } else if kind == 3 {
    item = block3d(x / 10, 5, z / 10, 9, 9, 68, "#b8481f")
    glow3d item, "#ff6a1a"
  } else if kind == 4 {
    item = block3d(x / 10, 4, z / 10, 18, 7, 12, "#f2f2f2")
    glow3d item, "#a02020"
  } else {
    item = block3d(x / 10, 5, z / 10, 16, 10, 14, "#7a8088")
    glow3d item, "#2a2f38"
  }
  add kind to dropKind
  add x to dropX
  add z to dropZ
  add item to dropId
  add 0 to dropGot
}

fn startMusic() {
  if musicOn == 1 {
    music "e3 - - - - - - - - - - - d#3 - - -", "a1 - - - - - - - - - - - - - - -" tempo 46
  }
}

when key "enter" pressed {
  if state == 0 or state == 2 {
    floor = 1
    won = 0
    crowN = 0
    emitN = 1
    axeN = 0
    bandN = 0
    scrapN = 0
    money = 0
    saved2 = 0
    hp = 3
    state = 1
    newFloor()
    startMusic()
  } else if state == 4 {
    floor += 1
    state = 1
    newFloor()
    startMusic()
  }
}

when key "m" pressed {
  if state == 1 {
    showMap = 1 - showMap
  }
}

when key "n" pressed {
  if musicOn == 1 {
    musicOn = 0
    music off
  } else {
    musicOn = 1
    if state == 1 {
      startMusic()
    }
  }
}

// ---------- the 2D layer (HUD) on top of the 3D world ----------
fn hud() {
  if state == 1 {
    box 159, 89, 2, 2 color "#ffffff70"
    box 6, 5, 112, 54 color "#0b0c10c0"
    write "LEVEL " + floor at 12, 9 color "#d7dbe3" size 2
    for c from 0 to 2 {
      let col = "#2a2f38"
      if cellGot[c] == 1 {
        col = "#5be39a"
      }
      box 12 + c * 20, 28, 17, 3 color col
    }
    write cells + " / 3 charges" at 12, 35 color "#8c93a3"
    for h from 0 to 2 {
      let hc = "#2a2f38"
      if hp > h {
        hc = "#e0463c"
      }
      box 12 + h * 14, 47, 11, 6 color hc
    }
    box 8, 168, 62, 6 color "#000000a0"
    let sc = "#e8e2c8"
    if tired == 1 {
      sc = "#d8503c"
    }
    box 9, 169, stam * 60 / 600, 4 color sc
    let near = 0
    let i = 0
    while i < length(lockC) {
      if hidden == 0 and dst(px, pz, lockX[i], lockZ[i]) < 2200 {
        near = 1
      }
      i += 1
    }
    if near == 1 {
      write "[E] HIDE" at 160, 130 centered shadow
    }
    if hidden == 0 and dst(px, pz, elevX(), elevZ()) < 2400 {
      if cells == 3 {
        write "[E] CALL ELEVATOR" at 160, 130 color "#7dff9c" centered shadow
      } else {
        write "[E] ELEVATOR (" + cells + "/3)" at 160, 130 color "#ff8a7a" centered shadow
      }
    }
    if msgT > 0 {
      write msg at 160, 62 color "#f2e9c9" centered shadow
    }
    // tools, like the hotbar in the Roblox game
    box 80, 160, 58, 16 color "#0b0c10c0"
    box 140, 160, 58, 16 color "#0b0c10c0"
    box 200, 160, 58, 16 color "#0b0c10c0"
    box 260, 160, 58, 16 color "#0b0c10c0"
    let c1 = "#4de1ff"
    if emitN == 0 {
      c1 = "#4a525e"
    }
    let c2 = "#ff8a7a"
    if crowN == 0 {
      c2 = "#4a525e"
    }
    let c3 = "#ffb347"
    if axeN == 0 {
      c3 = "#4a525e"
    }
    let c4 = "#7dff9c"
    if bandN == 0 {
      c4 = "#4a525e"
    }
    write "1 EMIT " + emitN at 84, 165 color c1
    write "2 CROW " + crowN at 144, 165 color c2
    write "3 AXE " + axeN at 204, 165 color c3
    write "4 BAND " + bandN at 264, 165 color c4
    // the nearest Raider's health
    let nr = nearestRaider()
    if nr >= 0 and dst(px, pz, rX[nr], rZ[nr]) < 9000 {
      write "RAIDER" at 160, 10 color "#ff6a5a" centered shadow
      box 110, 20, 100, 5 color "#000000a0"
      box 111, 21, rHp[nr] * 98 / 6, 3 color "#ff3b30"
    }
    // guide arrows: the way to the elevator, and to the nearest charge once the workstation has scanned
    let ea = arrowGlyph(stepDir(eMap))
    let ecol = "#ff8a7a"
    if cells == 3 {
      ecol = "#7dff9c"
    }
    write ea + "  EXIT " + eMap[cellOf(px, pz)] * 4 + "M" at 160, 74 color ecol centered shadow
    if scanned == 1 {
      let nc = nearestCharge()
      if nc >= 0 {
        let cm = c0Map
        if nc == 1 {
          cm = c1Map
        }
        if nc == 2 {
          cm = c2Map
        }
        write arrowGlyph(stepDir(cm)) + "  CHARGE " + cm[cellOf(px, pz)] * 4 + "M" at 160, 84 color "#4de1ff" centered shadow
      }
    }
    write "$" + money at 262, 8 color "#ffd23f" size 2
    write "SCRAP " + scrapN at 262, 24 color "#9aa1b0"
    if saved2 > 0 {
      write "SAVED " + saved2 at 262, 34 color "#7dff9c"
    }
    let nearD = 0
    let dH = 0
    while dH < length(deskX) {
      if deskDone[dH] == 0 and hidden == 0 and dst(px, pz, deskX[dH], deskZ[dH]) < 2000 {
        nearD = 1
      }
      dH += 1
    }
    if nearD == 1 {
      write "[E] SEARCH" at 160, 118 centered shadow
    }
    if hidden == 0 and cwState == 0 and dst(px, pz, cwX, cwZ) < 2200 {
      write "[E] FREE THE COWORKER" at 160, 106 color "#7dff9c" centered shadow
    }
    if hidden == 0 and dst(px, pz, benchX, benchZ) < 2400 {
      write "[C] CRAFT: 3 SCRAP AXE / 2 BANDAGE / 1 EMITTER" at 160, 94 color "#ffb347" centered shadow
      if scanned == 0 {
        write "[E] WORKSTATION: SCAN THE FLOOR" at 160, 82 color "#4de1ff" centered shadow
      }
    }
    if mstate == 1 {
      box 0, 0, 320, 3 color "#ff1a1a60"
      box 0, 177, 320, 3 color "#ff1a1a60"
      box 0, 0, 3, 180 color "#ff1a1a60"
      box 317, 0, 3, 180 color "#ff1a1a60"
    }
    if locked3d() == 0 {
      write "CLICK TO LOOK AROUND" at 160, 145 color "#8c93a3" centered shadow
    }
    if hidden == 1 {
      box 0, 0, 320, 64 color "#050605"
      box 0, 116, 320, 64 color "#050605"
      for s from 0 to 5 {
        box 0, 70 + s * 8, 320, 3 color "#050605"
      }
      box 0, 64, 6, 52 color "#050605"
      box 314, 64, 6, 52 color "#050605"
      write "[E] LEAVE LOCKER" at 160, 164 color "#8c93a3" centered shadow
    }
    if showMap == 1 {
      drawMap()
    }
    if dmgFlash > 0 {
      box 0, 0, 320, 180 color "#ff0000" + hex2(dmgFlash * 5)
    }
    if fadeIn > 0 {
      box 0, 0, 320, 180 color "#000000" + hex2(fadeIn * 255 / 90)
    }
  } else if state == 0 {
    box 0, 0, 320, 180 color "#000000b0"
    write "THE NIGHTSHIFT" at 160, 46 color "#e8e2c8" size 3 centered shadow
    write "THE FACILITY NEVER SLEEPS. NEITHER DOES THE HUNTER." at 160, 82 color "#9aa1b0" centered
    write "WASD WALK  SHIFT SPRINT  E USE  1-4 ITEMS  M MAP" at 160, 112 color "#c9ccd6" centered
    write "MOUSE LOOK (CLICK THE GAME FIRST)" at 160, 123 color "#c9ccd6" centered
    write "FIND 3 ENERGY CHARGES, THEN RIDE THE ELEVATOR DOWN" at 160, 134 color "#c9ccd6" centered
    if (t / 30) % 2 == 0 {
      write "PRESS ENTER" at 160, 150 color "#ffd23f" size 2 centered shadow
    }
    write "DEEPEST FLOOR: " + best at 160, 170 color "#6f7686" centered
  } else if state == 2 {
    let a = min(255, deadT * 4)
    box 0, 0, 320, 180 color "#5a0000" + hex2(min(a, 200))
    if deadT > 40 {
      write "THE HUNTER GOT YOU" at 160, 62 color "#ff3b30" size 3 centered shadow
      write "YOU REACHED FLOOR " + floor at 160, 100 color "#e8e2c8" centered shadow
      write "DEEPEST: " + best at 160, 112 color "#9aa1b0" centered
      if (t / 30) % 2 == 0 {
        write "ENTER: START A NEW SHIFT" at 160, 140 color "#ffd23f" centered shadow
      }
    }
  } else if state == 3 {
    let a = min(255, rideT * 6)
    box 0, 0, 320, 180 color "#000000" + hex2(a)
    if rideT > 40 {
      write "DESCENDING" at 160, 72 color "#9aa1b0" size 2 centered shadow
      write "FLOOR " + (floor + 1) at 160, 98 color "#e8e2c8" size 2 centered shadow
    }
  } else if state == 4 {
    box 0, 0, 320, 180 color "#000000d8"
    write "SHIFT OVER" at 160, 48 color "#7dff9c" size 3 centered shadow
    write "THREE FLOORS DOWN... AND THE ELEVATOR KEEPS GOING." at 160, 88 color "#c9ccd6" centered
    if (t / 30) % 2 == 0 {
      write "ENTER: ONE MORE FLOOR?" at 160, 128 color "#ffd23f" size 2 centered shadow
    }
  }
}

// the map: only tiles you have seen. Press M to open and close it.
fn drawMap() {
  let x0 = 100
  let y0 = 28
  box x0 - 5, y0 - 5, 130, 140 color "#05070bf4"
  for c from 0 to MW * MH - 1 {
    if explored[c] == 1 {
      let cx = c % MW
      let cy = c / MW
      let bx = x0 + cx * 15
      let by = y0 + cy * 15
      box bx + 1, by + 1, 13, 13 color "#2b3340"
      if canGo(c, 0) == 1 {
        box bx + 14, by + 4, 2, 7 color "#2b3340"
      }
      if canGo(c, 1) == 1 {
        box bx + 4, by + 14, 7, 2 color "#2b3340"
      }
    }
  }
  // the elevator, the workbench, charges and the coworker
  let sx = x0 + (startC % MW) * 15
  let sy = y0 + (startC / MW) * 15
  let mc = "#ff5a4a"
  if cells == 3 {
    mc = "#5dffa0"
  }
  box sx + 2, sy + 11, 11, 3 color mc
  let bcell = cellOf(benchX, benchZ)
  if explored[bcell] == 1 {
    box x0 + (bcell % MW) * 15 + 5, y0 + (bcell / MW) * 15 + 5, 5, 5 color "#ffb347"
  }
  if scanned == 1 {
    for k from 0 to 2 {
      if cellGot[k] == 0 {
        let kc = cellOf(cellX[k], cellZ[k])
        box x0 + (kc % MW) * 15 + 4, y0 + (kc / MW) * 15 + 4, 7, 7 color "#4de1ff"
      }
    }
  }
  if cwState == 0 {
    let wc = cellOf(cwX, cwZ)
    if explored[wc] == 1 {
      box x0 + (wc % MW) * 15 + 5, y0 + (wc / MW) * 15 + 5, 5, 5 color "#7dff9c"
    }
  }
  // you: a dot with a nose pointing the way you face
  let ppx = x0 + px * 15 / CS
  let ppy = y0 + pz * 15 / CS
  box ppx - 1, ppy - 1, 3, 3 color "#ffffff"
  box ppx + sin(yaw) * 5 / 1000 - 1, ppy - cos(yaw) * 5 / 1000 - 1, 2, 2 color "#ffd23f"
  write "MAP" at 160, y0 + 120 color "#8c93a3" centered
}

// two hex digits for a number 0..255 (used for see-through black fades)
fn hex2(n) {
  let v = constrain(n, 0, 255)
  let digits = "0123456789abcdef"
  return part(digits, v / 16, 1) + part(digits, v % 16, 1)
}

// ---------- start up: a slowly turning view of the first tile ----------
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
  if state == 0 {
    idle += 3
    camera3d px / 10, 150, pz / 10, idle, 0 - 40
    torch3d 11, 2400
    show3d monLamp, 0
  } else if state == 1 {
    if fadeIn > 0 {
      fadeIn -= 1
    }
    playerFrame()
    pickups()
    flickerFrame()
    monsterFrame()
    chaseMap()
    raiderFrame()
    coworkerFrame()
    placeMonster()
    torchFrame()
    heartbeat()
    for c from 0 to 2 {
      if cellGot[c] == 0 {
        let hov = 110 + sin(t * 30) * 8 / 1000
        turn3d cellId[c], t * 12
        move3d cellId[c], cellX[c] / 10, hov, cellZ[c] / 10
        turn3d cellG1[c], t * 12
        move3d cellG1[c], cellX[c] / 10, hov, cellZ[c] / 10
        turn3d cellG2[c], t * 12
        move3d cellG2[c], cellX[c] / 10, hov + 20, cellZ[c] / 10
      }
    }
    // the elevator doors open when it is powered and you are close
    let want = 0
    if cells == 3 and dst(px, pz, elevX(), elevZ()) < 4000 {
      want = 1
    }
    if want != gateOpen {
      gateOpen = want
      if want == 1 {
        anim3d gateId, "open"
      } else {
        anim3d gateId, "close"
      }
    }
    if hidden == 1 {
      camera3d lockX[hideIdx] / 10, 150, lockZ[hideIdx] / 10, yaw, 0
    } else {
      let bobY = sin(bob * 7) * 4 / 1000
      camera3d px / 10, 165 + bobY, pz / 10, yaw, pitch
    }
  } else if state == 2 {
    deadT += 1
    let want2 = atan2(mx - px, pz - mz)
    let diff = want2 - yaw
    if diff > 1800 {
      diff -= 3600
    }
    if diff < 0 - 1800 {
      diff += 3600
    }
    yaw += diff / 4
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
      startMusic()
    }
    camera3d px / 10, 165 + random(0 - 2, 2), pz / 10, yaw, 0
  } else if state == 4 {
    camera3d px / 10, 165, pz / 10, yaw, 0
  }
  render3d
  hud()
}
