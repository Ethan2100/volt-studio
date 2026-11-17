// =====================================================================
// STRIKER - a football match in Volt.
//
// 4-a-side plus keepers on a scaled pitch. Everything that decides how
// the game plays is Volt: dribbling, passing, shooting, keeper reactions,
// team shape, offside-ish positioning. The engine only draws and
// simulates - the ball is a real phys3d object, so a struck shot arcs,
// dips, bounces off the bar and curves if you lean into it.
//
// The characters and all 43 animation clips ship with Volt itself
// ("@male", "@female", "@animations", all CC0 by Quaternius), so this
// file needs no assets beside it.
//
// The animation library has no kicking clip, so the leg swing is driven
// directly with bone3d on thigh_r and calf_r. That is the whole reason
// bone3d exists.
//
//   WASD      run            hold SPACE    charge a shot, release to hit
//   E         pass to the best team-mate   SHIFT   sprint
//   mouse     look around
// =====================================================================
#html

title "Striker"
canvas 480, 270
world3d "#6f8fb8" fog 14000 ambient 42 fov 72 shadows
look3d 1, "#bcd4ea"
fx3d 28, 26, 5
sky3d 78

model3d body = "@male"
model3d body2 = "@female"
model3d moves = "@animations"

// ---------------------------------------------------------------------
// Pitch dimensions, in cm. A real pitch is 10500 x 6800; this is tighter
// so that a 4-a-side game still feels busy.
// ---------------------------------------------------------------------
let PITCH_X = 2400.0
let PITCH_Z = 3600.0
let GOAL_W = 700.0
let GOAL_H = 240.0

let score1 = 0
let score2 = 0
let tick = 0.0
let secs = 0
let mins = 0
let msg = ""
let msgT = 0.0

// =====================================================================
// THE GROUND
// =====================================================================
fn stripe(z, d, hex) {
  block3d(0, 0, z, PITCH_X * 2 + 600, 10, d, hex)
}

fn line(x, z, w, d) {
  block3d(x, 6, z, w, 6, d, "#eef3f6")
}

fn goalFrame(z, facing) {
  let post = GOAL_W / 2
  cyl3d(0 - post, GOAL_H / 2, z, 12, GOAL_H, "#f2f5f8")
  cyl3d(post, GOAL_H / 2, z, 12, GOAL_H, "#f2f5f8")
  block3d(0, GOAL_H, z, GOAL_W + 24, 14, 14, "#f2f5f8")
  // the net, as a slab behind the line: the ball bounces dead in it
  block3d(0, GOAL_H / 2, z + facing * 90, GOAL_W, GOAL_H, 12, "#c8d4dd")
  block3d(0 - post, GOAL_H / 2, z + facing * 45, 10, GOAL_H, 90, "#c8d4dd")
  block3d(post, GOAL_H / 2, z + facing * 45, 10, GOAL_H, 90, "#c8d4dd")
}

// ---------------------------------------------------------------------
// The stadium. Every shape here is one draw call - Volt has no instancing
// yet - so the whole bowl is kept near 120 blocks. That is the budget an
// Intel HD 520 can carry alongside ten animated players.
//
// Colours come off a floodlit pitch at night: turf green, floodlight
// white, concrete grey, and one warm seat colour so the bowl reads as
// occupied rather than empty.
// ---------------------------------------------------------------------
let SEAT_A = "#c2412f"
let SEAT_B = "#e0e4e8"

// One bank of seating: three tiers stepping back and up from the pitch.
fn standSide(side, span) {
  let tier = 0
  while tier < 3 {
    let h = 260.0 + tier * 240.0
    let out = PITCH_X + 520.0 + tier * 300.0
    let y = h / 2 + tier * 90.0
    block3d(side * out, y, 0, 300, h, span, "#5c646e")
    // the seated crowd, as a band of colour along the front of each tier
    let seat = SEAT_A
    if tier % 2 == 1 { seat = SEAT_B }
    block3d(side * (out - 170.0), y + h / 2 - 40.0, 0, 60, 90, span - 100, seat)
    tier = tier + 1
  }
  // roof over the top tier
  block3d(side * (PITCH_X + 1100.0), 1180, 0, 1500, 40, span + 200, "#39404a")
  block3d(side * (PITCH_X + 1820.0), 640, 0, 70, 1120, span + 200, "#2d343c")
}

// Behind each goal: shallower, so it does not wall off the view down the pitch.
fn standEnd(dir, wide) {
  let tier = 0
  while tier < 2 {
    let h = 240.0 + tier * 220.0
    let out = PITCH_Z + 520.0 + tier * 300.0
    let y = h / 2 + tier * 80.0
    block3d(0, y, dir * out, wide, h, 300, "#5c646e")
    let seat = SEAT_B
    if tier % 2 == 1 { seat = SEAT_A }
    block3d(0, y + h / 2 - 40.0, dir * (out - 170.0), wide - 100, 90, 60, seat)
    tier = tier + 1
  }
  block3d(0, 1000, dir * (PITCH_Z + 1050.0), wide + 200, 40, 1400, "#39404a")
}

// Floodlight pylon: a lattice mast with a lamp head, one at each corner.
fn pylon(sx, sz) {
  let x = sx * (PITCH_X + 1500.0)
  let z = sz * (PITCH_Z + 1200.0)
  cyl3d(x, 1100, z, 40, 2200, "#4a515b")
  block3d(x, 2280, z, 420, 150, 120, "#2a3038")
  let n = 0
  while n < 3 {
    block3d(x - 140.0 + n * 140.0, 2280, z - 70.0, 110, 110, 20, "#fdf6dd")
    n = n + 1
  }
  lamp3d(number(x * 0.55), 2100, number(z * 0.55), "#fff4d6", 85, 7000)
}

fn buildStadium() {
  standSide(0 - 1, PITCH_Z * 2 + 900)
  standSide(1, PITCH_Z * 2 + 900)
  standEnd(0 - 1, PITCH_X * 2 + 700)
  standEnd(1, PITCH_X * 2 + 700)
  pylon(0 - 1, 0 - 1)
  pylon(1, 0 - 1)
  pylon(0 - 1, 1)
  pylon(1, 1)
}

fn buildPitch() {
  // Ground that runs well past the goal lines. Without it there is no floor
  // behind the goals and a shot that crosses the line falls out of the world.
  block3d(0, 0 - 30, 0, PITCH_X * 2 + 3000, 40, PITCH_Z * 2 + 3000, "#2c6e34")
  let n = 0
  while n < 12 {
    let z = 0 - PITCH_Z + n * (PITCH_Z * 2 / 12) + PITCH_Z / 12
    let hex = "#2f7a3a"
    if n % 2 == 0 { hex = "#35853f" }
    stripe(z, PITCH_Z * 2 / 12, hex)
    n = n + 1
  }
  // touchlines and the halfway line
  line(0 - PITCH_X, 0, 12, PITCH_Z * 2)
  line(PITCH_X, 0, 12, PITCH_Z * 2)
  line(0, 0, PITCH_X * 2, 12)
  line(0, 0 - PITCH_Z, PITCH_X * 2, 12)
  line(0, PITCH_Z, PITCH_X * 2, 12)
  // both boxes
  line(0, 0 - PITCH_Z + 700, 1600, 12)
  line(0 - 800, 0 - PITCH_Z + 350, 12, 700)
  line(800, 0 - PITCH_Z + 350, 12, 700)
  line(0, PITCH_Z - 700, 1600, 12)
  line(0 - 800, PITCH_Z - 350, 12, 700)
  line(800, PITCH_Z - 350, 12, 700)

  goalFrame(0 - PITCH_Z, 0 - 1)
  goalFrame(PITCH_Z, 1)
  buildStadium()
  lamp3d(0 - 1800, 1400, 0 - 2200, "#fff6e0", 70, 5200)
  lamp3d(1800, 1400, 2200, "#fff6e0", 70, 5200)
}

// =====================================================================
// THE BALL
// =====================================================================
let ball = 0
let ballOwner = 0 - 1
let loose = 0.0

fn resetBall() {
  move3d ball, 0, 40, 0
  kick3d ball, 0, 0, 0
  spin3d ball, 0, 0, 0
  ballOwner = 0 - 1
  loose = 0.6
}

// =====================================================================
// PLAYERS
//
// One record per player. 'side' is 1 for your team attacking +z, 2 for
// theirs. 'hx'/'hz' is the shape position the player drifts back to when
// they are not the one chasing.
// =====================================================================
Man = type { rig: int, x: float, z: float, yaw: float, side: int, keeper: bool, hx: float, hz: float, speed: float, kickT: float, foot: float, cool: float }

let men = []
let you = 0

// ---------------------------------------------------------------------
// Kits. The base characters are bare torsos with painted-on shorts, so a
// shirt has to be geometry. Each piece is socketed to a bone, which means
// it rides the skeleton through every animation without being skinned to
// it - rigid, but at match distance it reads as a kit.
//
// Four pieces per player: shirt, two sleeves, shorts. Ten players is 40
// extra draw calls on top of the stadium, which is the most this can cost
// before the HD 520 budget starts to hurt.
// ---------------------------------------------------------------------
fn kitPiece(rig, bone, w, h, d, hex) {
  let piece = block3d(0, 0, 0, w, h, d, hex)
  solid3d piece, 0
  socket3d rig, bone, piece
  return piece
}

fn dress(rig, shirt, trim) {
  kitPiece(rig, "spine_02", 52, 64, 32, shirt)
  kitPiece(rig, "upperarm_l", 22, 34, 22, trim)
  kitPiece(rig, "upperarm_r", 22, 34, 22, trim)
  kitPiece(rig, "pelvis", 46, 30, 32, trim)
  return 0
}

fn spawn(side, keeper, hx, hz, female) {
  let m = body
  if female { m = body2 }
  let rid = put3d(m, hx, 0, hz, 0, 95)
  solid3d rid, 0
  clips3d rid, moves          // the characters carry no clips of their own
  anim3d rid, "Idle_Loop"
  // home side in deep red, away in white, keepers in a colour neither
  // outfield team wears so they read instantly
  if keeper {
    dress(rid, "#2fbf71", "#1c1f24")
  }
  if keeper == false {
    if side == 1 {
      dress(rid, "#c2322a", "#f2f4f6")
    }
    if side == 2 {
      dress(rid, "#eef1f4", "#1b2a52")
    }
  }
  add Man { rig: rid, x: hx, z: hz, yaw: 0.0, side: side, keeper: keeper, hx: hx, hz: hz, speed: 0.0, kickT: 0.0, foot: 0.0, cool: 0.0 } to men
  return length(men) - 1
}

fn buildTeams() {
  // your side attacks +z
  you = spawn(1, false, 0.0, 0 - 600.0, false)
  spawn(1, false, 0 - 900.0, 0 - 1100.0, false)
  spawn(1, false, 900.0, 0 - 1100.0, true)
  spawn(1, false, 0.0, 0 - 1900.0, false)
  spawn(1, true, 0.0, 0 - PITCH_Z + 160.0, false)
  // and theirs attacks -z
  spawn(2, false, 0.0, 600.0, true)
  spawn(2, false, 0 - 900.0, 1100.0, false)
  spawn(2, false, 900.0, 1100.0, true)
  spawn(2, false, 0.0, 1900.0, false)
  spawn(2, true, 0.0, PITCH_Z - 160.0, true)
}

// A kick is a quarter-second swing of the right leg, driven bone by bone
// because the shared animation library has no football clips in it.
fn swingLeg(i) {
  let m = men[i]
  if m.kickT <= 0.0 {
    bone3d m.rig, "thigh_r", 0, 0, 0
    bone3d m.rig, "calf_r", 0, 0, 0
    return 0
  }
  // 0 at the start of the swing, 1 at the end
  let t = 1.0 - m.kickT / 0.26
  let back = 1.0 - t
  // leg goes back then snaps through
  let thigh = 0 - 260.0 * back + 620.0 * t
  let calf = 520.0 * back - 180.0 * t
  bone3d m.rig, "thigh_r", number(thigh), 0, 0
  bone3d m.rig, "calf_r", number(calf), 0, 0
  return 0
}

// Locomotion: one blend from standing to jogging to sprinting, driven by
// how fast the player is actually moving. The library has no strafes, so
// everyone turns to face where they are going, which is what a football
// game does anyway.
fn legs(i) {
  let m = men[i]
  let sp = m.speed
  if sp < 260.0 {
    blend3d m.rig, "Idle_Loop", "Jog_Fwd_Loop", number(sp / 260.0 * 100.0)
  }
  if sp >= 260.0 {
    let k = (sp - 260.0) / 340.0 * 100.0
    if k > 100.0 { k = 100.0 }
    blend3d m.rig, "Jog_Fwd_Loop", "Sprint_Loop", number(k)
  }
}

// =====================================================================
// BALL CONTROL
// =====================================================================
fn ballX() { return number(where3d(ball, 0)) }
fn ballY() { return number(where3d(ball, 1)) }
fn ballZ() { return number(where3d(ball, 2)) }

fn nearBall(i) {
  let m = men[i]
  return dist(number(m.x), number(m.z), where3d(ball, 0), where3d(ball, 2))
}

// Whoever is closest and close enough has it at their feet.
fn settleOwner() {
  if loose > 0.0 { return 0 }

  // Whoever has it keeps it until the ball actually gets away from them.
  // Without this the owner flips every frame between two players standing
  // on the same spot, and the AI freezes: one frame it is carrying the
  // ball and running at goal, the next it is chasing a ball at its own
  // feet and braking.
  let cur = ballOwner
  if cur >= 0 {
    let curD = number(nearBall(cur))
    if curD < 200.0 and men[cur].cool <= 0.0 {
      // a defender right on top of them can still nick it
      let j = 0
      while j < length(men) {
        if men[j].side != men[cur].side and men[j].cool <= 0.0 {
          if number(nearBall(j)) < 70.0 and random(0, 100) < 4 {
            ballOwner = j
            men[cur].cool = 0.5
            loose = 0.1
            return 0
          }
        }
        j = j + 1
      }
      return 0
    }
  }

  let best = 0 - 1
  let bestD = 150.0
  let i = 0
  while i < length(men) {
    let d = number(nearBall(i))
    if d < bestD and men[i].cool <= 0.0 {
      bestD = d
      best = i
    }
    i = i + 1
  }
  ballOwner = best
  return 0
}

// Dribbling: the ball is nudged to sit just ahead of the owner's feet.
fn dribble(dt) {
  if ballOwner < 0 { return 0 }
  let m = men[ballOwner]
  let ahead = 95.0
  let tx = m.x + sin3(number(m.yaw * 10.0)) / 1000.0 * ahead
  let tz = m.z + cos3(number(m.yaw * 10.0)) / 1000.0 * ahead
  let bx = ballX()
  let bz = ballZ()
  kick3d ball, number((tx - bx) * 5.0), 0, number((tz - bz) * 5.0)
  return 0
}

fn shoot(i, power, lift, curve) {
  let m = men[i]
  let dx = sin3(number(m.yaw * 10.0)) / 1000.0
  let dz = cos3(number(m.yaw * 10.0)) / 1000.0
  kick3d ball, number(dx * power), number(lift), number(dz * power)
  spin3d ball, 0, number(curve), 0
  ballOwner = 0 - 1
  loose = 0.25
  men[i].kickT = 0.26
  men[i].cool = 0.3
  return 0
}

fn passTo(giver, mate) {
  let a = men[giver]
  let b = men[mate]
  let dx = b.x - a.x
  let dz = b.z - a.z
  let d = sqrt(number(dx * dx + dz * dz))
  if d < 1.0 { return 0 }
  // lead the pass a little and lift it just off the turf
  let power = d * 1.9
  if power > 2600.0 { power = 2600.0 }
  kick3d ball, number(dx / d * power), 110, number(dz / d * power)
  spin3d ball, 0, 0, 0
  ballOwner = 0 - 1
  loose = 0.22
  men[giver].kickT = 0.26
  men[giver].cool = 0.25
  men[mate].cool = 0.0
  return 0
}

fn bestMate(i) {
  let m = men[i]
  let best = 0 - 1
  let bestScore = 0 - 1.0
  let j = 0
  while j < length(men) {
    let o = men[j]
    if j != i and o.side == m.side and o.keeper == false {
      // prefer team-mates who are ahead of you and not miles away
      let fwd = (o.z - m.z) * (3 - m.side * 2)
      let d = sqrt(number((o.x - m.x) * (o.x - m.x) + (o.z - m.z) * (o.z - m.z)))
      let s = fwd - d * 0.35
      if d < 2600.0 and s > bestScore {
        bestScore = s
        best = j
      }
    }
    j = j + 1
  }
  return best
}

// =====================================================================
// AI
// =====================================================================
fn closestOnSide(side) {
  let best = 0 - 1
  let bestD = 99999.0
  let i = 0
  while i < length(men) {
    if men[i].side == side and men[i].keeper == false {
      let d = number(nearBall(i))
      if d < bestD {
        bestD = d
        best = i
      }
    }
    i = i + 1
  }
  return best
}

fn steer(i, tx, tz, top, dt) {
  let m = men[i]
  let dx = tx - m.x
  let dz = tz - m.z
  let d = sqrt(number(dx * dx + dz * dz))
  if d < 12.0 {
    men[i].speed = men[i].speed * 0.8
    return 0
  }
  let sp = m.speed + 900.0 * dt
  if sp > top { sp = top }
  men[i].speed = sp
  let nx = m.x + dx / d * sp * dt
  let nz = m.z + dz / d * sp * dt
  men[i].x = nx
  men[i].z = nz
  men[i].yaw = atan2(number(dx * 1000.0), number(dz * 1000.0)) / 10.0
  return 0
}

fn aiThink(i, dt) {
  let m = men[i]
  let bx = ballX()
  let bz = ballZ()

  if m.keeper {
    // a keeper who gathers it has to give it away again, or the match stalls
    // with the ball in his hands forever
    if ballOwner == i and m.cool <= 0.0 {
      let mate = bestMate(i)
      if mate >= 0 {
        passTo(i, mate)
        return 0
      }
      // nobody on: hoof it upfield
      let up = 2400.0
      if m.side == 2 { up = 0 - 2400.0 }
      kick3d ball, number(random(0 - 400, 400)), 300, number(up)
      ballOwner = 0 - 1
      loose = 0.4
      men[i].cool = 0.6
      return 0
    }
    // stay on the line, shuffle across to the ball
    let gz = 0 - PITCH_Z + 160.0
    if m.side == 2 { gz = PITCH_Z - 160.0 }
    let want = bx * 0.45
    if want > GOAL_W / 2 { want = GOAL_W / 2 }
    if want < 0 - GOAL_W / 2 { want = 0 - GOAL_W / 2 }
    // rush out if the ball is loose and close
    let near = dist(number(m.x), number(m.z), number(bx), number(bz))
    if near < 420.0 and ballOwner < 0 {
      steer(i, bx, bz, 520.0, dt)
      return 0
    }
    steer(i, want, gz, 420.0, dt)
    return 0
  }

  let chaser = closestOnSide(m.side)

  if ballOwner == i {
    // carry it at goal, then shoot once you are close enough
    let gz = PITCH_Z
    if m.side == 2 { gz = 0 - PITCH_Z }
    let togoal = dist(number(m.x), number(m.z), 0, number(gz))
    if togoal < 1500.0 and m.cool <= 0.0 {
      shoot(i, 2600.0 + random(0, 500), 230, random(0 - 600, 600))
      return 0
    }
    // look for a better-placed team-mate now and then
    if random(0, 100) < 2 {
      let mate = bestMate(i)
      if mate >= 0 {
        passTo(i, mate)
        return 0
      }
    }
    steer(i, 0.0, gz, 560.0, dt)
    return 0
  }

  if chaser == i {
    if ballOwner >= 0 and men[ballOwner].side != m.side {
      // close the carrier down from the goal side, not by standing on them
      let own = 0 - PITCH_Z
      if m.side == 2 { own = PITCH_Z }
      let gx = men[ballOwner].x * 0.8
      let gz = men[ballOwner].z + (own - men[ballOwner].z) * 0.06
      steer(i, gx, gz, 640.0, dt)
      return 0
    }
    steer(i, bx, bz, 620.0, dt)
    return 0
  }

  // otherwise hold shape, shifted towards the ball
  let sx = m.hx + bx * 0.3
  let sz = m.hz + bz * 0.45
  steer(i, sx, sz, 430.0, dt)
  return 0
}

// =====================================================================
// YOU
// =====================================================================
let charge = 0.0
let stamina = 100.0
let camYaw = 0.0
let camPitch = 12.0

// Camera modes, cycled with C. eFootball ships a dozen presets; these are
// the four that actually change how you play rather than how it looks.
//   0 broadcast  high and wide, tracking the ball - the default to watch
//   1 third      behind your player, the one to dribble with
//   2 first      at head height, looking where the player faces
//   3 tactical   straight down, for reading the shape
let camMode = 0
let camNames = ["BROADCAST", "THIRD", "FIRST", "TACTICAL"]
let camHeld = false

fn cycleCam() {
  if held("c") {
    if camHeld == false {
      camHeld = true
      camMode = camMode + 1
      if camMode > 3 { camMode = 0 }
      msg = camNames[camMode]
      msgT = 1.0
    }
  }
  if held("c") == false { camHeld = false }
  return 0
}

fn placeCamera() {
  let m = men[you]
  // In first person the camera sits inside your own skull, so your head
  // fills the bottom of the frame. Hide your model while that view is on.
  if camMode == 2 {
    show3d m.rig, 0
  }
  if camMode != 2 {
    show3d m.rig, 1
  }
  let bx = ballX()
  let bz = ballZ()
  let fx = sin3(number(m.yaw * 10.0)) / 1000.0
  let fz = cos3(number(m.yaw * 10.0)) / 1000.0

  if camMode == 0 {
    // Broadcast: sits off to the side at height and slides along with play,
    // which is the view every televised match is shot from.
    let tx = bx * 0.35
    let tz = bz * 0.85
    camera3d number(tx), 1450, number(tz - 1900.0), 0, 0 - 240
    return 0
  }
  if camMode == 1 {
    let cx = m.x - sin3(number(camYaw * 10.0)) / 1000.0 * 620.0
    let cz = m.z - cos3(number(camYaw * 10.0)) / 1000.0 * 620.0
    camera3d number(cx), 390, number(cz), number(camYaw * 10.0), 0 - number(camPitch * 10.0)
    return 0
  }
  if camMode == 2 {
    // First person: at the player's own eyeline, just ahead of the head so
    // the camera is not inside their own skull.
    camera3d number(m.x + fx * 26.0), 168, number(m.z + fz * 26.0), number(m.yaw * 10.0), 0
    return 0
  }
  // Tactical: straight down over the ball.
  camera3d number(bx * 0.6), 3400, number(bz * 0.6 - 1100.0), 0, 0 - 680
  return 0
}

fn playerThink(dt) {
  let m = men[you]
  let fx = 0.0
  let fz = 0.0
  if held("w") { fz = 1.0 }
  if held("s") { fz = 0 - 1.0 }
  if held("a") { fx = 0 - 1.0 }
  if held("d") { fx = 1.0 }

  let top = 560.0
  if held("shift") and stamina > 1.0 {
    top = 760.0
    stamina = stamina - dt * 14.0
  }
  if held("shift") == false {
    stamina = stamina + dt * 7.0
  }
  if stamina > 100.0 { stamina = 100.0 }
  if stamina < 0.0 { stamina = 0.0 }

  if fx != 0.0 or fz != 0.0 {
    // move relative to where the camera is looking
    let c = cos3(number(camYaw * 10.0)) / 1000.0
    let s = sin3(number(camYaw * 10.0)) / 1000.0
    let wx = fx * c + fz * s
    let wz = fz * c - fx * s
    let d = sqrt(number(wx * wx + wz * wz))
    steer(you, m.x + wx / d * 400.0, m.z + wz / d * 400.0, top, dt)
  }
  if fx == 0.0 and fz == 0.0 {
    men[you].speed = men[you].speed * 0.82
  }

  // hold to charge, release to strike
  if held("space") and ballOwner == you {
    charge = charge + dt
    if charge > 1.0 { charge = 1.0 }
  }
  if held("space") == false and charge > 0.05 {
    if ballOwner == you {
      let power = 1500.0 + charge * 2600.0
      let lift = 120.0 + charge * 260.0
      shoot(you, power, lift, 0 - men[you].speed * 0.5)
    }
    charge = 0.0
  }

  if held("e") and ballOwner == you and men[you].cool <= 0.0 {
    let mate = bestMate(you)
    if mate >= 0 { passTo(you, mate) }
  }
  return 0
}

// =====================================================================
// GOALS
// =====================================================================
fn checkGoal() {
  let bz = ballZ()
  let bx = ballX()
  let by = ballY()
  if by > GOAL_H { return 0 }
  if bx > GOAL_W / 2 or bx < 0 - GOAL_W / 2 { return 0 }
  if bz > PITCH_Z {
    score1 = score1 + 1
    msg = "GOAL"
    msgT = 2.2
    kickoff(2)
  }
  if bz < 0 - PITCH_Z {
    score2 = score2 + 1
    msg = "GOAL - THEM"
    msgT = 2.2
    kickoff(1)
  }
  return 0
}

fn kickoff(side) {
  resetBall()
  let i = 0
  while i < length(men) {
    men[i].x = men[i].hx
    men[i].z = men[i].hz
    men[i].speed = 0.0
    men[i].cool = 0.4
    i = i + 1
  }
  return 0
}

fn outOfPlay() {
  let bx = ballX()
  let bz = ballZ()
  if bx > PITCH_X + 240 or bx < 0 - PITCH_X - 240 {
    resetBall()
    msg = "OUT"
    msgT = 1.1
  }
  if bz > PITCH_Z + 300 or bz < 0 - PITCH_Z - 300 {
    resetBall()
    msg = "OUT"
    msgT = 1.1
  }
  return 0
}

// =====================================================================
// HUD
// =====================================================================
// The match HUD. Same job as a football game's: who is winning, how long
// is left, where everyone is, and how hard you are about to hit it.
// Drawn on the 2D layer over the 3D, at the canvas size of 480x270.
//
// Palette is taken off the pitch itself rather than a UI kit: floodlight
// white on a near-black slate, turf green for the radar, and one warm
// amber that only ever means "this is you".
let INK = "#0b0f14"
let LINE = "#f2f6f8"
let MINE = "#f0a830"
let THEM = "#4aa3df"
let TURF = "#17351d"

fn scoreboard() {
  // One slab, left-aligned like a broadcast bug rather than centred.
  box 12, 10, 196, 26 color INK
  box 12, 10, 5, 26 color MINE
  write "YOU" at 26, 18 color LINE
  write text(score1) + " - " + text(score2) at 104, 18 color LINE centered
  write "CPU" at 170, 18 color LINE

  let ss = text(secs)
  if secs < 10 { ss = "0" + text(secs) }
  box 208, 10, 54, 26 color INK
  write text(mins) + ":" + ss at 235, 18 color LINE centered
}

// Radar: the whole pitch squashed into a corner box, every player a dot.
// This is the one HUD element that genuinely changes how you play, because
// it is the only way to see a run behind you.
fn radar() {
  let rx = 12.0
  let ry = 206.0
  let rw = 104.0
  let rh = 52.0
  box number(rx), number(ry), number(rw), number(rh) color TURF
  box number(rx + rw / 2.0 - 1.0), number(ry), 1, number(rh) color "#2c5c36"

  let i = 0
  while i < length(men) {
    let m = men[i]
    // pitch runs -PITCH_X..PITCH_X across and -PITCH_Z..PITCH_Z down
    let px = rx + (m.z + PITCH_Z) / (PITCH_Z * 2.0) * rw
    let py = ry + rh - (m.x + PITCH_X) / (PITCH_X * 2.0) * rh
    let hex = THEM
    if m.side == 1 { hex = "#d8dde2" }
    if i == you { hex = MINE }
    let sz = 3.0
    if i == you { sz = 5.0 }
    box number(px - sz / 2.0), number(py - sz / 2.0), number(sz), number(sz) color hex
    i = i + 1
  }
  let bpx = rx + (ballZ() + PITCH_Z) / (PITCH_Z * 2.0) * rw
  let bpy = ry + rh - (ballX() + PITCH_X) / (PITCH_X * 2.0) * rh
  box number(bpx - 1.0), number(bpy - 1.0), 3, 3 color "#ffffff"
}

// Power gauge, at the bottom edge where your eyes already are when you are
// lining a shot up. Only ever on screen while you are actually charging.
fn powerGauge() {
  if charge <= 0.02 { return 0 }
  let w = 150.0
  let x = 240.0 - w / 2.0
  box number(x), 250, number(w), 9 color INK
  let hex = MINE
  if charge > 0.85 { hex = "#e8513c" }
  box number(x + 2.0), 252, number((w - 4.0) * charge), 5 color hex
  return 0
}

// Who you are controlling, and whether you have the ball. The real games
// put a cursor in the 3D scene; a name plate is the honest 2D version.
fn playerPlate() {
  box 376, 206, 92, 52 color INK
  write camNames[camMode] at 422, 214 color "#8e9aa6" centered
  let state = "CHASING"
  if ballOwner == you { state = "ON THE BALL" }
  write state at 422, 230 color LINE centered
  // stamina stands in as how fresh your legs are: it drains as you sprint
  box 388, 246, 68, 5 color "#232a33"
  box 388, 246, number(68.0 * stamina / 100.0), 5 color MINE
}

fn hud() {
  scoreboard()
  radar()
  powerGauge()
  playerPlate()

  if msgT > 0.0 {
    write msg at 240, 96 color LINE centered
  }

  write "C camera   SPACE shoot   E pass   SHIFT sprint" at 240, 264 color "#6f7b87" centered
}

// =====================================================================
// SET UP
// =====================================================================
buildPitch()
ball = ball3d(0, 40, 0, 12, "#f7f9fb")
phys3d ball, 52, 42
buildTeams()
resetBall()

every frame {
  let dt = 0.016

  tick = tick + dt
  if tick >= 1.0 {
    tick = tick - 1.0
    secs = secs + 1
    if secs >= 60 {
      secs = 0
      mins = mins + 1
    }
  }
  if msgT > 0.0 { msgT = msgT - dt }
  if loose > 0.0 { loose = loose - dt }

  camYaw = camYaw + number(mousedx()) / 6.0

  playerThink(dt)

  let i = 0
  while i < length(men) {
    if men[i].cool > 0.0 { men[i].cool = men[i].cool - dt }
    if men[i].kickT > 0.0 { men[i].kickT = men[i].kickT - dt }
    if i != you { aiThink(i, dt) }
    // keep everyone on the park
    if men[i].x > PITCH_X + 200 { men[i].x = PITCH_X + 200 }
    if men[i].x < 0 - PITCH_X - 200 { men[i].x = 0 - PITCH_X - 200 }
    if men[i].z > PITCH_Z + 100 { men[i].z = PITCH_Z + 100 }
    if men[i].z < 0 - PITCH_Z - 100 { men[i].z = 0 - PITCH_Z - 100 }
    move3d men[i].rig, number(men[i].x), 0, number(men[i].z)
    turn3d men[i].rig, number(men[i].yaw * 10.0)
    legs(i)
    swingLeg(i)
    i = i + 1
  }

  settleOwner()
  dribble(dt)
  checkGoal()
  outOfPlay()

  cycleCam()
  placeCamera()

  render3d
  hud()
}
