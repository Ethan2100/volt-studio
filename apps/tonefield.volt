#html
// =====================================================================
//  TONEFIELD - a little chiptune tracker, written in Volt.
//
//  Volt's whole audio API is a beep. This turns it into a 16-step
//  sequencer: click out a tune on the two grids, press play, and when you
//  like it press E to get the exact `music ... tempo n` line to paste into
//  one of your games.
//
//  MOUSE  click a square to put a note there, click it again to clear it,
//         drag to paint a run of notes
//  SPACE  play / stop        C  clear          E  show the line to copy
//  [ ]    slower / faster    , .  move the lead octave   < >  the bass
//  S      save               L  load it back
// =====================================================================
title "Tonefield"
canvas 480, 270
let sharp = crisp(2)

// ---- the pattern ----
let steps = 16
let lead = []          // one entry per step: -1 is a rest, 0-11 is a row
let bass = []
let leadOct = 4
let bassOct = 2
let tempo = 120

repeat steps {
  add 0 - 1 to lead
  add 0 - 1 to bass
}

// ---- playing ----
let playing = false
let atStep = 0
let nextStepAt = 0
let painting = 0 - 1   // which grid the mouse is painting in: 0 lead, 1 bass
let paintTo = 0        // whether the drag is filling in or rubbing out
let showLine = false
let note = ""
let noteUntil = 0

// Frequencies for one octave, as whole numbers. Volt's pow() rounds down, so
// an octave up or down is a doubling or halving instead.
let hz4 = [262, 277, 294, 311, 330, 349, 370, 392, 415, 440, 466, 494]
let names = ["c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"]
// the bass grid is the plain notes only, which is kinder to pick out by ear
let bassSemis = [0, 2, 4, 5, 7, 9, 11, 12]

// ---- where things sit on the screen ----
let gridX = 56
let cellW = 26
let leadY = 34
let bassY = 160
let rowH = 9
let leadRows = 12
let bassRows = 8

fn rowToSemi(grid, row) {
  if grid == 0 {
    return 11 - row
  }
  return bassSemis[bassRows - 1 - row]
}

fn octaveOf(grid) {
  if grid == 0 {
    return leadOct
  }
  return bassOct
}

fn noteHz(grid, row) {
  let semi = rowToSemi(grid, row)
  let oct = octaveOf(grid)
  let base = hz4[semi % 12]
  if semi >= 12 {
    base = base * 2
  }
  let out = base
  // an octave is a doubling, so step towards the one we want
  while oct > 4 {
    out = out * 2
    oct -= 1
  }
  while oct < 4 {
    out = out / 2
    oct += 1
  }
  return out
}

fn noteName(grid, row) {
  let semi = rowToSemi(grid, row)
  let oct = octaveOf(grid)
  if semi >= 12 {
    return names[semi % 12] + text(oct + 1)
  }
  return names[semi] + text(oct)
}

// The line you paste into a game. A rest is "-", which Volt's music plays as silence.
fn lineFor(which) {
  let parts = []
  let grid = 0
  if which == 1 {
    grid = 1
  }
  for each row, i in lead {
    let cell = row
    if grid == 1 {
      cell = bass[i]
    }
    if cell < 0 {
      add "-" to parts
    } else {
      add noteName(grid, cell) to parts
    }
  }
  return join(parts, " ")
}

fn say(message) {
  note = message
  noteUntil = uptime + 2000
  return 0
}

fn clearAll() {
  for each cell, i in lead {
    lead[i] = 0 - 1
    bass[i] = 0 - 1
  }
  say("Cleared.")
  return 0
}

fn saveIt() {
  save "tonefield", [lead, bass, leadOct, bassOct, tempo]
  say("Saved.")
  return 0
}

fn loadIt() {
  let got = saved("tonefield", [])
  if length(got) < 5 {
    say("Nothing saved yet.")
    return 0
  }
  lead = got[0]
  bass = got[1]
  leadOct = got[2]
  bassOct = got[3]
  tempo = got[4]
  say("Loaded.")
  return 0
}

// A starting tune, so the page makes a sound the moment you press play
fn demo() {
  let tuneRows = [11, 9, 7, 9, 11, 11, 11, 0 - 1, 9, 9, 9, 0 - 1, 11, 6, 6, 0 - 1]
  let bassRowsIn = [7, 0 - 1, 7, 0 - 1, 4, 0 - 1, 4, 0 - 1, 7, 0 - 1, 7, 0 - 1, 2, 0 - 1, 2, 0 - 1]
  for each row, i in tuneRows {
    lead[i] = row
    bass[i] = bassRowsIn[i]
  }
  return 0
}
demo()

// ---- drawing ----
fn drawGrid(grid, top, rows, label, tint) {
  write label at 4, top - 10 color "#8b93a7"
  for r from 0 to rows - 1 {
    let y = top + r * rowH
    // the note name down the left, and a darker stripe for the black keys
    let semi = rowToSemi(grid, r)
    let shade = "#171b24"
    if grid == 0 and contains([1, 3, 6, 8, 10], semi % 12) {
      shade = "#11141b"
    }
    write noteName(grid, r) at 8, y + 1 color "#6b7389"
    for c from 0 to steps - 1 {
      let x = gridX + c * cellW
      let fill = shade
      // every fourth step is a beat, so it gets a lighter bed
      if c % 4 == 0 {
        fill = "#1d222d"
      }
      box x + 1, y + 1, cellW - 2, rowH - 2 color fill
    }
  }
  // the notes themselves
  for c from 0 to steps - 1 {
    let cell = lead[c]
    if grid == 1 {
      cell = bass[c]
    }
    if cell >= 0 {
      let x = gridX + c * cellW
      let y = top + cell * rowH
      box x + 1, y + 1, cellW - 2, rowH - 2 color tint
      if playing and c == atStep {
        box x + 1, y + 1, cellW - 2, rowH - 2 color "#ffffff"
      }
    }
  }
  return 0
}

// ---- keys (these live at the top level, outside every frame) ----
when key "space" pressed {
  playing = not playing
  atStep = steps - 1
  nextStepAt = uptime
}
when key "c" pressed {
  clearAll()
}
when key "e" pressed {
  showLine = not showLine
}
when key "s" pressed {
  saveIt()
}
when key "l" pressed {
  loadIt()
}
when key "[" pressed {
  tempo = clamp(tempo - 10, 50, 240)
}
when key "]" pressed {
  tempo = clamp(tempo + 10, 50, 240)
}
when key "," pressed {
  leadOct = clamp(leadOct - 1, 2, 6)
}
when key "." pressed {
  leadOct = clamp(leadOct + 1, 2, 6)
}

every frame {
  // ---- the clock ----
  if playing {
    if uptime >= nextStepAt {
      atStep = (atStep + 1) % steps
      nextStepAt = uptime + 30000 / tempo
      let hold = 26000 / tempo
      if lead[atStep] >= 0 {
        tone noteHz(0, lead[atStep]) for hold ms
      }
      if bass[atStep] >= 0 {
        tone noteHz(1, bass[atStep]) for hold ms
      }
    }
  }

  // ---- the mouse ----
  let mx = mousex()
  let my = mousey()
  let overCol = (mx - gridX) / cellW
  let inCols = mx >= gridX and mx < gridX + steps * cellW

  if mousedown() and inCols {
    let grid = 0 - 1
    let row = 0
    if my >= leadY and my < leadY + leadRows * rowH {
      grid = 0
      row = (my - leadY) / rowH
    }
    if my >= bassY and my < bassY + bassRows * rowH {
      grid = 1
      row = (my - bassY) / rowH
    }
    if grid >= 0 {
      // the first press decides whether this drag is drawing notes or rubbing them out
      if painting < 0 {
        painting = grid
        let was = lead[overCol]
        if grid == 1 {
          was = bass[overCol]
        }
        paintTo = 1
        if was == row {
          paintTo = 0
        }
      }
      if painting == grid {
        let value = row
        if paintTo == 0 {
          value = 0 - 1
        }
        if grid == 0 {
          lead[overCol] = value
        } else {
          bass[overCol] = value
        }
      }
    }
  }
  if not mousedown() {
    painting = 0 - 1
  }

  // ---- the picture ----
  paint "#0c0e14"
  write "TONEFIELD" at 4, 6 color "#ffd23f"
  write "{tempo} bpm" at 100, 6 color "#8b93a7"
  if playing {
    write "playing" at 168, 6 color "#6fd0a8"
  } else {
    write "stopped" at 168, 6 color "#8b93a7"
  }
  write "space play   C clear   E export   [ ] tempo   , . octave   S save  L load" at 236, 6 color "#5d6579"

  // the beat numbers along the top
  for c from 0 to steps - 1 {
    let x = gridX + c * cellW
    let shade = "#4a5265"
    if c % 4 == 0 {
      shade = "#8b93a7"
    }
    write text(c + 1) at x + 2, 24 color shade
  }

  drawGrid(0, leadY, leadRows, "LEAD", "#4de1ff")
  drawGrid(1, bassY, bassRows, "BASS", "#ffb347")

  // where the playhead is
  if playing {
    let x = gridX + atStep * cellW
    box x, leadY - 4, cellW, 3 color "#ffffff"
    box x, bassY - 4, cellW, 3 color "#ffffff"
  }

  if uptime < noteUntil {
    write note at 240, 248 centered color "#ffd23f"
  }

  if showLine {
    box 10, 60, 460, 150 color "#10131c"
    write "Paste this into a game:" at 20, 70 color "#ffd23f"
    write "music \"{lineFor(0)}\"," at 20, 90 color "#4de1ff"
    write "      \"{lineFor(1)}\" tempo {tempo}" at 20, 104 color "#ffb347"
    write "Press E to put it away." at 20, 184 color "#8b93a7"
  }
}
