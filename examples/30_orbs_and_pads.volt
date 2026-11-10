#html
// =====================================================================
//  ORBS AND PADS - a first-person 3D puzzle in about 120 lines of Volt.
//
//  Three glowing orbs, three pads. Look at an orb and click to pick it up;
//  it floats in front of you. Click again to drop it. Drop an orb on the
//  pad of its own colour and it locks in. Place all three to win.
//
//  W A S D walk   MOUSE look (click the page first)   SHIFT run   SPACE jump
//  CLICK pick up and drop      R put everything back
//
//  Units: 1 = 1 cm. Angles are in tenths of a degree.
// =====================================================================
title "Orbs and Pads"
canvas 320, 180

world3d "#0b1020" fog 3400 ambient 26 shadows
fx3d 65, 40, 6
ao3d 70
far3d 6000

Orb = type { body: int, slab: int, homeX: int, homeZ: int, done: bool }

let orbs = []
let carrying = 0 - 1          // which orb is in your hands, or -1
let won = false
let winAt = 0
let hint = ""
let hintUntil = 0

// ---- the room: built once, then frozen so it draws in a couple of calls ----
block3d(0, 0 - 10, 0, 2400, 20, 2400, "#4d5565")
block3d(0, 200, 0 - 1200, 2400, 400, 20, "#616a7c")
block3d(0, 200, 1200, 2400, 400, 20, "#616a7c")
block3d(0 - 1200, 200, 0, 20, 400, 2400, "#616a7c")
block3d(1200, 200, 0, 20, 400, 2400, "#616a7c")

// a low plinth in the middle, just to break up the floor
block3d(0, 15, 0, 420, 30, 420, "#59616f")
block3d(0, 45, 0, 300, 30, 300, "#515866")

// crates to climb on, so the room has somewhere to go
block3d(0 - 700, 45, 0 - 700, 90, 90, 90, "#8a6a3a")
block3d(0 - 700, 135, 0 - 700, 90, 90, 90, "#8a6a3a")
block3d(0 - 610, 45, 0 - 700, 90, 90, 90, "#8a6a3a")
freeze3d

// four cool ceiling lights, so you can see the room you are walking around
lamp3d(0 - 600, 360, 0 - 600, "#9fc4ff", 45, 1700)
lamp3d(600, 360, 0 - 600, "#9fc4ff", 45, 1700)
lamp3d(0 - 600, 360, 600, "#9fc4ff", 45, 1700)
lamp3d(600, 360, 600, "#9fc4ff", 45, 1700)

// ---- the pads and their orbs ----
fn addOrb(colour, padX, padZ, orbX, orbZ) {
  let slab = cyl3d(padX, 4, padZ, 70, 8, "#2b3242")
  let ring = cyl3d(padX, 7, padZ, 56, 4, colour)
  glow3d ring, colour
  lamp3d(padX, 40, padZ, colour, 22, 420)

  let body = ball3d(orbX, 70, orbZ, 26, colour)
  glow3d body, colour
  solid3d body, false
  lamp3d(orbX, 70, orbZ, colour, 30, 600)

  add Orb { body: body, slab: ring, homeX: orbX, homeZ: orbZ } to orbs
  return 0
}

addOrb("#4de1ff", 0 - 300, 0 - 300, 520, 640)
addOrb("#ff4d6d", 300, 0 - 300, 0 - 560, 620)
addOrb("#ffd23f", 0, 320, 700, 0 - 520)

// the light that travels with a carried orb
let handLight = lamp3d(0, 0 - 900, 0, "#ffffff", 0, 10)

player3d 0, 0, 760

fn say(message) {
  hint = message
  hintUntil = uptime + 2200
  return 0
}

// ---- picking up, carrying and dropping ----
fn dropCarried() {
  if carrying < 0 {
    return 0
  }
  let held = orbs[carrying]
  let slabX = 0
  let slabZ = 0
  // a pad is a ring sitting at its own spot; find where this orb's pad is
  for each one, i in orbs {
    if i == carrying {
      slabX = padXOf(i)
      slabZ = padZOf(i)
    }
  }
  let gap = dist(round(playerx()), round(playerz()), slabX, slabZ)
  if gap < 150 {
    move3d held.body, slabX, 60, slabZ
    held.done = true
    burst3d slabX, 70, slabZ, "#ffffff", 70, 420
    tone 520 to 1040 for 140ms
    say("Locked in.")
  } else {
    move3d held.body, round(playerx()), 70, round(playerz())
    tone 300 to 220 for 90ms
  }
  show3d handLight, false
  carrying = 0 - 1
  return 0
}

// where each pad sits (kept beside the orbs so the list stays simple)
let padXs = [0 - 300, 300, 0]
let padZs = [0 - 300, 0 - 300, 320]
fn padXOf(i) {
  return padXs[i]
}
fn padZOf(i) {
  return padZs[i]
}

fn resetAll() {
  for each one, i in orbs {
    move3d one.body, one.homeX, 70, one.homeZ
    one.done = false
  }
  carrying = 0 - 1
  won = false
  show3d handLight, false
  say("Back to the start.")
  return 0
}

show3d handLight, false

every frame {
  walk3d

  // carrying: the orb floats just in front of your eyes
  if carrying >= 0 {
    let held = orbs[carrying]
    let ahead = 95
    let hx = playerx() + sin3(playeryaw()) * ahead / 1000
    let hz = playerz() - cos3(playeryaw()) * ahead / 1000
    let hy = playery() + 120 + sin3(uptime * 2) * 6 / 1000
    move3d held.body, hx, hy, hz
    move3d handLight, hx, hy, hz
  }

  // what you are looking at
  let looking = 0 - 1
  if carrying < 0 and not won {
    looking = aim3d(320)
  }

  if clicked() and not won {
    if carrying >= 0 {
      dropCarried()
    } else {
      for each one, i in orbs {
        if one.body == looking and not one.done {
          carrying = i
          show3d handLight, true
          glow3d handLight, "#ffffff"
          tone 740 to 980 for 70ms
          say("Carry it to the matching pad.")
        }
      }
    }
  }

  if held("r") and carrying < 0 {
    resetAll()
  }

  // have we finished?
  let placed = 0
  for each one in orbs {
    if one.done {
      placed += 1
    }
  }
  if placed == length(orbs) and not won {
    won = true
    winAt = uptime
    tone 660 to 1320 for 420ms
  }

  render3d

  // ---- the HUD, drawn over the 3D view ----
  write "Orbs placed: {placed}/{length(orbs)}" at 6, 6 shadow

  if carrying >= 0 {
    write "Click to put it down" at 160, 164 centered shadow
  } else {
    if looking >= 0 {
      write "Click to pick it up" at 160, 164 centered shadow
    }
  }

  if uptime < hintUntil {
    write hint at 160, 150 centered color "#ffd23f" shadow
  }

  if not locked3d() {
    write "Click the page to look around" at 160, 90 centered shadow
  }

  // a small crosshair, brighter when something is under it
  if looking >= 0 {
    box 158, 89, 4, 2 color "#ffd23f"
    box 159, 88, 2, 4 color "#ffd23f"
  } else {
    box 159, 89, 2, 2 color "#8c93a4"
  }

  if won {
    let age = uptime - winAt
    box 60, 70, 200, 40 color "#10131c"
    write "ALL THREE PLACED" at 160, 82 centered color "#ffd23f" shadow
    write "Press R to play again" at 160, 96 centered shadow
    if age < 900 {
      burst3d 0, 120, 0, "#ffd23f", 6, 500
    }
  }
}
