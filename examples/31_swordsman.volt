// =====================================================================
// BLADE — a swordsman, built properly.
//
// Everything runs through Volt's own engine. The character and all 43
// clips ship with Volt ("@male", "@animations", CC0 by Quaternius), so
// this file needs nothing beside it.
//
// What the engine does here:
//   socket3d   armour and sword ride the skeleton, bone by bone
//   clips3d    lends the shared animation library to the rig
//   blend3d    locomotion mixed by actual speed, not switched
//   bone3d     the wind-up and follow-through no clip contains
//   trail3d    the arc the blade leaves through a swing
//   flash3d    one frame of flat colour on heavy contact
//   hitstop3d  the beat of nothing that makes a hit land
//   slowmo3d   the whole world slowed for the heavy
//
//   WASD move   SHIFT sprint   J slash   K hold heavy   L thrust
//   SPACE dash  mouse look
// =====================================================================
#html

title "Blade"
canvas 480, 270
world3d "#1b2634" fog 7000 ambient 120 fov 72 shadows
look3d 1, "#2e4258"
toon3d 4, 4, 58
fx3d 30, 26, 4

model3d body = "@male"
model3d moves = "@animations"

let INK = "#080b11"
let LINE = "#eaf2f8"
let EDGE = "#7fe3ff"
let HEAT = "#ff8a3c"
let GOLD = "#f3c762"

// =====================================================================
// THE ARENA
//
// A sunken stone ring under a cold sky, ringed by eight pillars with
// braziers between them. Lit cold from above and warm from the ground so
// the character has a rim on one side and a glow on the other, which is
// what makes a figure read against a dark floor.
// =====================================================================
fn pillar(ang, r, lit) {
  let x = sin3(ang) / 1000.0 * r
  let z = cos3(ang) / 1000.0 * r
  // base, shaft, collar, capital - four pieces, so it reads as masonry
  // rather than as one cylinder standing in the dark
  block3d(number(x), 18, number(z), 128, 36, 128, "#6c7793")
  block3d(number(x), 44, number(z), 108, 20, 108, "#7c88a3")
  cyl3d(number(x), 230, number(z), 42, 380, "#8a95ae")
  cyl3d(number(x), 424, number(z), 50, 26, "#9aa5bd")
  block3d(number(x), 448, number(z), 120, 26, 120, "#7e89a4")
  if lit {
    let bx = sin3(number(ang + 225)) / 1000.0 * (r - 170.0)
    let bz = cos3(number(ang + 225)) / 1000.0 * (r - 170.0)
    block3d(number(bx), 16, number(bz), 54, 32, 54, "#4e5566")
    cyl3d(number(bx), 62, number(bz), 13, 92, "#2f3542")
    cyl3d(number(bx), 116, number(bz), 36, 28, "#5e4330")
    ball3d(number(bx), 130, number(bz), 23, "#ff7a2a")
    ball3d(number(bx), 142, number(bz), 13, "#ffd37a")
    lamp3d(number(bx), 150, number(bz), "#ff9448", 56, 1500)
  }
}

// Rubble and low walls, so the floor is not an empty plane. Cheap: these
// are the same cached box geometry the pillars use.
fn debris() {
  let n = 0
  while n < 14 {
    let a = number(n * 257 % 3600)
    let r = 700.0 + number(n * 137 % 620)
    let x = sin3(a) / 1000.0 * r
    let z = cos3(a) / 1000.0 * r
    let h = 20.0 + number(n * 53 % 46)
    block3d(number(x), number(h / 2.0), number(z), number(40 + n % 5 * 16), number(h), number(36 + n % 3 * 20), "#6a768f")
    n = n + 1
  }
  // two low walls framing the arena, which give the eye a middle distance
  block3d(0 - 1500, 90, 0, 90, 180, 1500, "#5f6a84")
  block3d(1500, 90, 0, 90, 180, 1500, "#5f6a84")
  return 0
}

fn buildArena() {
  // floor, in stepped rings so the eye has something to read
  block3d(0, 0 - 24, 0, 3400, 48, 3400, "#55617a")
  block3d(0, 2, 0, 1900, 8, 1900, "#616e89")
  block3d(0, 7, 0, 1320, 6, 1320, "#6d7b98")
  block3d(0, 11, 0, 620, 4, 620, "#7987a6")
  // a dais ring inlaid in the centre, so the middle of the floor has a focus
  cyl3d(0, 13, 0, 300, 4, "#8d9bba")
  cyl3d(0, 15, 0, 150, 4, "#a3b0cc")

  let n = 0
  while n < 8 {
    pillar(number(n * 450), 1180.0, n % 2 == 0)
    n = n + 1
  }
  debris()

  // key from above and a cold fill from behind, so a figure gets a cool
  // rim on one side and the braziers warm the other
  lamp3d(0, 820, 0, "#cfe7ff", 120, 3600)
  lamp3d(0, 340, 0 - 950, "#9fc4ea", 60, 2400)
}

// =====================================================================
// THE CHARACTER
//
// The base mesh is a bare torso, so the armour is geometry socketed to
// the skeleton. Each piece rides its bone through every frame of every
// clip: rigid, but at this distance it reads as a figure rather than a
// mannequin with blocks on.
// =====================================================================
let hero = 0
let blade = 0

fn armour(rig, main, trim, skirt) {
  // chest, with a raised plate so the silhouette is not a flat slab
  let chest = block3d(0, 0, 0, 34, 46, 22, main)
  solid3d chest, 0
  socket3d rig, "spine_02", chest
  let plate = block3d(0, 0, 0, 22, 20, 24, trim)
  solid3d plate, 0
  socket3d rig, "spine_03", plate
  // shoulders: the piece that does most of the work for a warrior outline
  let shL = block3d(0, 0, 0, 15, 13, 17, trim)
  solid3d shL, 0
  socket3d rig, "upperarm_l", shL
  let shR = block3d(0, 0, 0, 15, 13, 17, trim)
  solid3d shR, 0
  socket3d rig, "upperarm_r", shR
  // bracers
  let brL = block3d(0, 0, 0, 11, 18, 12, main)
  solid3d brL, 0
  socket3d rig, "lowerarm_l", brL
  let brR = block3d(0, 0, 0, 11, 18, 12, main)
  solid3d brR, 0
  socket3d rig, "lowerarm_r", brR
  // belt and a hanging skirt plate
  let belt = block3d(0, 0, 0, 30, 10, 22, trim)
  solid3d belt, 0
  socket3d rig, "pelvis", belt
  let tass = block3d(0, 0 - 18, 0, 26, 26, 19, skirt)
  solid3d tass, 0
  socket3d rig, "pelvis", tass
  // greaves
  let gL = block3d(0, 0, 0, 12, 20, 14, main)
  solid3d gL, 0
  socket3d rig, "calf_l", gL
  let gR = block3d(0, 0, 0, 12, 20, 14, main)
  solid3d gR, 0
  socket3d rig, "calf_r", gR
  return 0
}

fn buildHero() {
  hero = put3d(body, 0, 0, 0, 0, 100)
  solid3d hero, 0
  clips3d hero, moves
  anim3d hero, "Sword_Idle"
  armour(hero, "#5a6c8c", "#c3cede", "#b35344")

  // The sword: a tapered blade, a crossguard and a pommel, all hung off
  // the right hand so the whole thing swings as one.
  // hand at the grip, guard above it, blade running out from there
  blade = block3d(0, 62, 0, 5, 94, 11, "#dceaf5")
  solid3d blade, 0
  socket3d hero, "hand_r", blade
  glow3d blade, "#1b3d52"

  let guard = block3d(0, 13, 0, 7, 7, 28, GOLD)
  solid3d guard, 0
  socket3d hero, "hand_r", guard
  let grip = block3d(0, 0 - 4, 0, 6, 26, 8, "#4a3425")
  solid3d grip, 0
  socket3d hero, "hand_r", grip
  let pommel = ball3d(0, 0 - 19, 0, 6, GOLD)
  solid3d pommel, 0
  socket3d hero, "hand_r", pommel
  return 0
}

// =====================================================================
// THE OPPOSITION
// =====================================================================
Foe = type { rig: int, x: float, z: float, hp: int, hurt: float, down: float, kx: float, kz: float, think: float }
let foes = []

fn spawnFoe(x, z) {
  let r = put3d(body, x, 0, z, 0, 97)
  solid3d r, 0
  clips3d r, moves
  anim3d r, "Idle_Loop"
  armour(r, "#4a2b31", "#7c5560", "#32202a")
  add Foe { rig: r, x: x, z: z, hp: 100, hurt: 0.0, down: 0.0, kx: 0.0, kz: 0.0, think: 0.0 } to foes
  return 0
}

// =====================================================================
// STATE
// =====================================================================
let hx = 0.0
let hz = 0.0
let hyaw = 0.0
let speed = 0.0
let hp = 100.0

let actT = 0.0
let actMax = 0.42
let actKind = 0        // 1 slash  2 heavy  3 thrust  4 dash
let lunge = 0.0
let charge = 0.0
let combo = 0
let comboT = 0.0
let swung = false      // has this swing already looked for a target
let camYaw = 0.0
let camShake = 0.0
let camFollowX = 0.0
let camFollowZ = 0.0
let camLag = 0.0

// Cooldowns, one per slot. A hotbar with nothing to count down is just a
// row of pictures, so every ability costs time.
let cdSlash = 0.0
let cdHeavy = 0.0
let cdThrust = 0.0
let cdDash = 0.0
let cdSpin = 0.0
let CD_SLASH = 0.42
let CD_HEAVY = 1.5
let CD_THRUST = 0.7
let CD_DASH = 0.9
let CD_SPIN = 2.4
let airT = 0.0
let airY = 0.0

// =====================================================================
// DAMAGE
// =====================================================================
fn hurtFoe(i, damage, heavyHit) {
  let f = foes[i]
  if f.down > 0.0 { return 0 }
  foes[i].hp = f.hp - damage
  foes[i].hurt = 0.3

  let dx = f.x - hx
  let dz = f.z - hz
  let mag = sqrt(number(dx * dx + dz * dz))
  if mag > 1.0 {
    let kick = 240.0
    if heavyHit { kick = 520.0 }
    foes[i].kx = dx / mag * kick
    foes[i].kz = dz / mag * kick
  }

  burst3d number(f.x), 115, number(f.z), EDGE, 30, 360
  burst3d number(f.x), 95, number(f.z), "#ffffff", 12, 180
  once3d f.rig, "Hit_Chest"
  combo = combo + 1
  comboT = 1.8

  if foes[i].hp <= 0 {
    foes[i].down = 3.0
    once3d f.rig, "Death01"
    burst3d number(f.x), 90, number(f.z), HEAT, 52, 480
    shake3d 62, 220
    flash3d "#ffd9a0", 45
  }
  return 0
}

// Everything in an arc in front of him. Returns 1 if anything was hit.
fn strikeArc(reach, arc, damage, heavyHit) {
  let fx = sin3(number(hyaw * 10.0)) / 1000.0
  let fz = cos3(number(hyaw * 10.0)) / 1000.0
  let got = 0
  let i = 0
  while i < length(foes) {
    let f = foes[i]
    if f.down <= 0.0 {
      let dx = f.x - hx
      let dz = f.z - hz
      let mag = sqrt(number(dx * dx + dz * dz))
      if mag < reach and mag > 1.0 {
        let dot = (dx / mag) * fx + (dz / mag) * fz
        if dot > arc {
          hurtFoe(i, damage, heavyHit)
          got = 1
        }
      }
    }
    i = i + 1
  }
  return got
}

// =====================================================================
// ABILITIES
//
// Each sets a timer and a shape. The pose function below reads the timer
// and adds the wind-up and follow-through, because the shared clip
// library has no combat follow-through in it.
// =====================================================================
fn beginAct(kind, dur, push) {
  actKind = kind
  actT = dur
  actMax = dur
  lunge = push
  swung = false
  return 0
}

fn slash() {
  beginAct(1, 0.40, 170.0)
  once3d hero, "Sword_Attack"
  trail3d blade, EDGE, 52, 230
  return 0
}

fn heavy(power) {
  beginAct(2, 0.82, 110.0 + power * 220.0)
  once3d hero, "Sword_Attack"
  trail3d blade, HEAT, 74, 380
  slowmo3d 32, 340
  bars3d 1
  shake3d number(36 + power * 46.0), 280
  return 0
}

fn thrust() {
  beginAct(3, 0.32, 300.0)
  once3d hero, "Punch_Cross"
  trail3d blade, "#ffffff", 40, 170
  return 0
}

// A full turn with the blade out: the move that clears a crowd, and the
// one that earns the longest cooldown.
fn spin() {
  beginAct(5, 0.72, 120.0)
  once3d hero, "Sword_Attack"
  trail3d blade, GOLD, 96, 460
  shake3d 30, 220
  cdSpin = CD_SPIN
  return 0
}

fn jump() {
  if airT > 0.0 { return 0 }
  airT = 0.72
  once3d hero, "Jump_Start"
  burst3d number(hx), 20, number(hz), "#9fb4c8", 16, 160
  return 0
}

fn dash() {
  beginAct(4, 0.40, 700.0)
  once3d hero, "Roll"
  burst3d number(hx), 36, number(hz), "#9fb4c8", 24, 220
  return 0
}

fn endAct() {
  trail3d blade, "", 0, 0
  bars3d 0
  bone3d hero, "spine_02", 0, 0, 0
  bone3d hero, "spine_03", 0, 0, 0
  bone3d hero, "upperarm_r", 0, 0, 0
  bone3d hero, "upperarm_l", 0, 0, 0
  return 0
}

// The curve every swing follows: wind up against the swing, snap through,
// settle. t runs 0 to 1 across the action.
fn poseAct() {
  if actT <= 0.0 { return 0 }
  let t = 1.0 - actT / actMax

  if actKind == 1 {
    // slash: coil right, then open across the body
    let coil = 1.0 - t
    bone3d hero, "spine_02", number(0 - 150.0 * coil + 210.0 * t), number(240.0 * coil - 300.0 * t), 0
    bone3d hero, "upperarm_r", number(0 - 500.0 * coil + 1020.0 * t), 0, number(200.0 * coil)
    bone3d hero, "upperarm_l", number(180.0 * coil), 0, 0
    return 0
  }
  if actKind == 2 {
    // heavy: a long wind-up over the shoulder, then straight down
    let coil = 1.0 - t
    if t < 0.42 {
      bone3d hero, "spine_02", number(0 - 300.0 * coil), number(180.0 * coil), number(130.0 * coil)
      bone3d hero, "upperarm_r", number(0 - 760.0 * coil), 0, 0
    }
    if t >= 0.42 {
      let k = (t - 0.42) / 0.58
      bone3d hero, "spine_02", number(0 - 174.0 + 560.0 * k), number(104.0 - 200.0 * k), 0
      bone3d hero, "upperarm_r", number(0 - 441.0 + 1500.0 * k), 0, 0
    }
    return 0
  }
  if actKind == 5 {
    // spin: lean out of the turn and let the arm trail the body
    let whirl = t * 3600.0
    bone3d hero, "spine_02", number(0 - 60.0 + 120.0 * t), number(whirl), number(180.0 - 360.0 * t)
    bone3d hero, "upperarm_r", 620, 0, 0
    return 0
  }
  if actKind == 3 {
    // thrust: short coil, long reach, slow recovery
    if t < 0.3 {
      let k = t / 0.3
      bone3d hero, "spine_02", number(0 - 90.0 * k), 0, 0
      bone3d hero, "upperarm_r", number(360.0 - 220.0 * k), 0, 0
    }
    if t >= 0.3 {
      let k = (t - 0.3) / 0.7
      bone3d hero, "spine_02", number(0 - 90.0 + 170.0 * k), 0, 0
      bone3d hero, "upperarm_r", number(140.0 + 620.0 * k), 0, 0
    }
    return 0
  }
  return 0
}

// The window in each swing where the blade is actually out in front.
fn checkStrike() {
  if actT <= 0.0 { return 0 }
  if swung { return 0 }
  let t = 1.0 - actT / actMax
  let got = 0

  if actKind == 1 and t > 0.42 {
    got = strikeArc(185.0, 0.3, 15, false)
    swung = true
  }
  if actKind == 2 and t > 0.58 {
    got = strikeArc(225.0, 0.0 - 0.25, 46, true)
    swung = true
    // the heavy earns a frame of white whether or not it connects
    flash3d "#ffffff", 55
  }
  if actKind == 3 and t > 0.36 {
    got = strikeArc(255.0, 0.75, 24, false)
    swung = true
  }
  // the spin sweeps the whole circle, so it has no facing test at all
  if actKind == 5 and t > 0.3 {
    got = strikeArc(215.0, 0.0 - 1.1, 28, true)
    swung = true
    flash3d "#ffe9bf", 40
  }

  if got == 1 {
    hitstop3d 80
    shake3d 38, 150
    camShake = 0.12
  }
  return 0
}

// =====================================================================
// FOES
// =====================================================================
fn stepFoes(dt) {
  let i = 0
  while i < length(foes) {
    let f = foes[i]
    if f.hurt > 0.0 { foes[i].hurt = f.hurt - dt }

    if f.down > 0.0 {
      foes[i].down = f.down - dt
      if foes[i].down <= 0.0 {
        foes[i].hp = 100
        anim3d f.rig, "Idle_Loop"
        burst3d number(f.x), 90, number(f.z), "#6f8aa8", 20, 240
      }
    }

    if f.down <= 0.0 and f.hurt <= 0.0 {
      // close on him, but stop at sword length
      let dx = hx - f.x
      let dz = hz - f.z
      let mag = sqrt(number(dx * dx + dz * dz))
      if mag > 200.0 {
        foes[i].x = f.x + dx / mag * 150.0 * dt
        foes[i].z = f.z + dz / mag * 150.0 * dt
        blend3d f.rig, "Idle_Loop", "Walk_Loop", 100
      }
      if mag <= 200.0 {
        blend3d f.rig, "Idle_Loop", "Walk_Loop", 0
      }
    }

    foes[i].x = foes[i].x + f.kx * dt
    foes[i].z = foes[i].z + f.kz * dt
    foes[i].kx = f.kx * 0.84
    foes[i].kz = f.kz * 0.84

    move3d f.rig, number(foes[i].x), 0, number(foes[i].z)
    let ang = atan2(number((hx - foes[i].x) * 1000.0), number((hz - foes[i].z) * 1000.0))
    turn3d f.rig, number(ang)
    i = i + 1
  }
  return 0
}

// =====================================================================
// CONTROL
// =====================================================================
fn control(dt) {
  let busy = actT > 0.0

  let fx = 0.0
  let fz = 0.0
  if held("w") { fz = 1.0 }
  if held("s") { fz = 0 - 1.0 }
  if held("a") { fx = 0 - 1.0 }
  if held("d") { fx = 1.0 }

  let top = 320.0
  if held("shift") { top = 560.0 }

  if fx != 0.0 or fz != 0.0 {
    let c = cos3(number(camYaw * 10.0)) / 1000.0
    let sn = sin3(number(camYaw * 10.0)) / 1000.0
    let wx = fx * c + fz * sn
    let wz = fz * c - fx * sn
    let mag = sqrt(number(wx * wx + wz * wz))
    speed = speed + 1300.0 * dt
    if speed > top { speed = top }
    if busy == false {
      hx = hx + wx / mag * speed * dt
      hz = hz + wz / mag * speed * dt
      hyaw = atan2(number(wx * 1000.0), number(wz * 1000.0)) / 10.0
    }
  }
  if fx == 0.0 and fz == 0.0 {
    speed = speed * 0.78
  }

  if lunge > 0.0 {
    let push = lunge * dt * 4.0
    hx = hx + sin3(number(hyaw * 10.0)) / 1000.0 * push
    hz = hz + cos3(number(hyaw * 10.0)) / 1000.0 * push
    lunge = lunge * 0.85
    if lunge < 4.0 { lunge = 0.0 }
  }

  if hx > 900.0 { hx = 900.0 }
  if hx < 0 - 900.0 { hx = 0 - 900.0 }
  if hz > 900.0 { hz = 900.0 }
  if hz < 0 - 900.0 { hz = 0 - 900.0 }

  if busy == false {
    if held("j") and cdSlash <= 0.0 {
      slash()
      cdSlash = CD_SLASH
    }
    if held("l") and cdThrust <= 0.0 {
      thrust()
      cdThrust = CD_THRUST
    }
    if held("u") and cdSpin <= 0.0 { spin() }
    if held("shift") == false and held("space") and cdDash <= 0.0 {
      dash()
      cdDash = CD_DASH
    }
    if held("space") and held("shift") { jump() }
    if held("k") and cdHeavy <= 0.0 {
      charge = charge + dt
      if charge > 1.0 { charge = 1.0 }
    }
    if held("k") == false and charge > 0.08 and cdHeavy <= 0.0 {
      heavy(charge)
      cdHeavy = CD_HEAVY
      charge = 0.0
    }
  }
  return 0
}

// Locomotion, only while he is free to move.
fn legs() {
  if actT > 0.0 { return 0 }
  if speed < 24.0 {
    blend3d hero, "Sword_Idle", "Walk_Loop", 0
    return 0
  }
  if speed < 320.0 {
    blend3d hero, "Walk_Loop", "Jog_Fwd_Loop", number(speed / 320.0 * 100.0)
    return 0
  }
  blend3d hero, "Jog_Fwd_Loop", "Sprint_Loop", number((speed - 320.0) / 240.0 * 100.0)
  return 0
}

// =====================================================================
// HUD
//
// Built from Volt's UI layer: gradients rather than flat fills, a lit
// edge on every panel, glow on what is live, and fills clipped to their
// own rounded tracks. Palette is taken off the arena - cold steel,
// brazier orange, stone and the gold on the sword - not a UI kit.
// =====================================================================
let SLOTY = 203.0
let SLOTW = 40.0
let SLOTGAP = 50.0
let SLOTX = 120.0

fn slot(n, key, glyph, cd, cdMax, tint) {
  let x = SLOTX + n * SLOTGAP
  let ready = cd <= 0.0
  let cx = x + SLOTW / 2.0
  let cy = SLOTY + SLOTW / 2.0

  // the tile: a gradient face with a lit top edge, brighter when live
  if ready {
    grad number(x), SLOTY, number(SLOTW), number(SLOTW), 13, "#263447", "#131b27"
    edge number(x), SLOTY, number(SLOTW), number(SLOTW), 13, 1 color "#3f5068"
  }
  if ready == false {
    grad number(x), SLOTY, number(SLOTW), number(SLOTW), 13, "#161e2a", "#0e141d"
    edge number(x), SLOTY, number(SLOTW), number(SLOTW), 13, 1 color "#222c3a"
  }

  // the glyph
  let ink = tint
  if ready == false { ink = "#44505f" }
  write glyph at number(cx), number(cy - 8.0) color ink centered size 2

  // the dial: a dark track, then either a lit ready ring or the arc left
  ring number(cx), number(cy), 15, 2 color "#1b2432"
  if ready {
    glow tint, 9
    ring number(cx), number(cy), 15, 2 color tint
    glow "", 0
  }
  if ready == false {
    sweep number(cx), number(cy), 15, number(cd / cdMax * 100.0), 3 color tint
  }

  // key cap
  grad number(cx - 10.0), number(SLOTY + SLOTW + 4.0), 20, 13, 6, "#1d2634", "#121923"
  write key at number(cx), number(SLOTY + SLOTW + 7.0) color "#8294aa" centered
  return 0
}

fn hotbar() {
  // the tray sits over the game, so it is translucent rather than solid
  alpha 82
  grad 110, 196, 260, 64, 20, "#141c28", "#080d14"
  alpha 100
  edge 110, 196, 260, 64, 20, 1 color "#263040"
  slot(0, "J", "/", cdSlash, CD_SLASH, "#7fe3ff")
  slot(1, "K", "V", cdHeavy, CD_HEAVY, "#ff8a3c")
  slot(2, "L", "-", cdThrust, CD_THRUST, "#eaf2f8")
  slot(3, "U", "O", cdSpin, CD_SPIN, "#f3c762")
  slot(4, "SP", ">", cdDash, CD_DASH, "#9ad7a0")
  return 0
}

fn healthBar() {
  grad 14, 14, 168, 18, 9, "#121a26", "#080d14"
  edge 14, 14, 168, 18, 9, 1 color "#28344a"
  // the fill is clipped to its own track, so it keeps the rounded ends
  // instead of poking square corners out of the capsule
  clip 18, 18, 160, 10, 5
  let w = 160.0 * hp / 100.0
  grad 18, 18, number(w), 10, 5, "#e8755f", "#b43a2c"
  box 18, 18, number(w), 3 color "#f2a08f"
  unclip
  write "BLADE" at 20, 35 color "#6f8095"
  return 0
}

fn chargeDial() {
  if charge <= 0.02 { return 0 }
  let cx = 240.0
  let cy = 148.0
  let tint = EDGE
  if charge > 0.82 { tint = HEAT }
  ring number(cx), number(cy), 26, 3 color "#141c28"
  glow tint, 14
  sweep number(cx), number(cy), 26, number(charge * 100.0), 4 color tint
  glow "", 0
  write "HEAVY" at number(cx), number(cy - 4.0) color tint centered
  // a chevron that points up as it fills, so the eye has something moving
  if charge > 0.82 {
    tri number(cx), number(cy - 38.0), number(cx + 7.0), number(cy - 30.0), number(cx - 7.0), number(cy - 30.0) color tint
  }
  return 0
}

fn comboTag() {
  if comboT <= 0.0 { return 0 }
  if combo < 2 { return 0 }
  let label = text(combo) + " HIT"
  let w = number(textw(label, 1)) + 34.0
  alpha 88
  grad number(466.0 - w), 58, number(w), 30, 13, "#1d2432", "#0c1118"
  alpha 100
  edge number(466.0 - w), 58, number(w), 30, 13, 1 color "#3a465a"
  glow GOLD, 10
  write text(combo) at number(474.0 - w), 66 color GOLD size 2
  glow "", 0
  write "HIT" at number(496.0 - w), 70 color "#8294aa"
  return 0
}

fn hud() {
  healthBar()
  hotbar()
  chargeDial()
  comboTag()
}

// =====================================================================
buildArena()
buildHero()
spawnFoe(460.0, 540.0)
spawnFoe(0 - 500.0, 420.0)
spawnFoe(80.0, 0 - 560.0)

every frame {
  let dt = 0.016

  camYaw = camYaw + number(mousedx()) / 6.0

  control(dt)

  if actT > 0.0 {
    actT = actT - dt
    if actT <= 0.0 { endAct() }
  }
  if comboT > 0.0 {
    comboT = comboT - dt
    if comboT <= 0.0 { combo = 0 }
  }
  if camShake > 0.0 { camShake = camShake - dt }
  if cdSlash > 0.0 { cdSlash = cdSlash - dt }
  if cdHeavy > 0.0 { cdHeavy = cdHeavy - dt }
  if cdThrust > 0.0 { cdThrust = cdThrust - dt }
  if cdDash > 0.0 { cdDash = cdDash - dt }
  if cdSpin > 0.0 { cdSpin = cdSpin - dt }

  // the jump arc: up fast, hang, down. Volt's physics is for loose objects,
  // so a character's hop is just a curve over its own timer.
  if airT > 0.0 {
    airT = airT - dt
    let k = 1.0 - airT / 0.72
    airY = 150.0 * sin3(number(k * 1800.0)) / 1000.0
    if airT <= 0.0 {
      airY = 0.0
      once3d hero, "Jump_Land"
      burst3d number(hx), 16, number(hz), "#9fb4c8", 14, 180
    }
  }

  checkStrike()
  poseAct()
  legs()
  stepFoes(dt)

  move3d hero, number(hx), number(airY), number(hz)
  turn3d hero, number(hyaw * 10.0)

  // The camera chases a point that itself chases the character, so it
  // lags into turns and settles behind him instead of being welded on.
  camFollowX = camFollowX + (hx - camFollowX) * 7.0 * dt
  camFollowZ = camFollowZ + (hz - camFollowZ) * 7.0 * dt
  let back = 400.0 + speed * 0.26
  // ease the swing of the orbit too, so a flick of the mouse is not a snap
  camLag = camLag + (camYaw - camLag) * 11.0 * dt
  let cx = camFollowX - sin3(number(camLag * 10.0)) / 1000.0 * back
  let cz = camFollowZ - cos3(number(camLag * 10.0)) / 1000.0 * back
  // and rise a little while he sprints, which widens the view of the arena
  let ch = 250.0 + speed * 0.1
  camera3d number(cx), number(ch), number(cz), number(1800.0 - camLag * 10.0), 0 - 95

  render3d
  hud()
}
