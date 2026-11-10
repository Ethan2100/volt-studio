#html
// =====================================================================
//  VOLT FM - a music app, written in Volt.
//
//  Browse, search by mood, play, like, and build a playlist. Every song is
//  a real chiptune the page plays itself, and every cover is drawn from the
//  song's own name, so the whole app is one file with no assets at all.
//
//  MOUSE  click anything          SPACE  play / pause
//  1 2 3  Home, Search, Library   ← →    previous / next track
//  L      like the playing song   A      add it to the playlist
// =====================================================================
title "Volt FM"
canvas 480, 270
let sharp = crisp(2)

Track = type { name: string, artist: string, mood: string, mel: string, low: string, tempo: int, tint: string }

let tracks = []
fn addTrack(name, artist, mood, mel, low, tempo, tint) {
  add Track { name: name, artist: artist, mood: mood, mel: mel, low: low, tempo: tempo, tint: tint } to tracks
  return 0
}

// Eight tunes written for this app. Octave numbers are part of each note.
addTrack("Night Bus", "Kesi", "calm",
  "a3 - c4 - e4 - d4 - c4 - a3 - g3 - - -",
  "a2 - - - f2 - - - c2 - - - e2 - - -", 96, "#4de1ff")
addTrack("Matatu Run", "Slime Time", "hype",
  "e4 e4 g4 a4 - a4 g4 e4 d4 e4 - d4 c4 - - -",
  "e2 - e2 - a2 - a2 - g2 - g2 - c2 - - -", 150, "#ff4d6d")
addTrack("Cold Rain", "Verve", "calm",
  "d4 - f4 - a4 - g4 f4 - d4 - c4 d4 - - -",
  "d2 - - - bb2 - - - f2 - - - g2 - - -", 84, "#9fb4ff")
addTrack("Tusker Blue", "Kesi", "calm",
  "g3 a3 b3 - d4 - b3 a3 g3 - e3 - g3 - - -",
  "g2 - - - e2 - - - c2 - - - d2 - - -", 100, "#6fd0a8")
addTrack("Pixel Chase", "Slime Time", "hype",
  "c5 b4 a4 g4 a4 b4 c5 - e5 d5 c5 b4 c5 - - -",
  "c3 - g2 - a2 - e2 - f2 - c3 - g2 - - -", 168, "#ffd23f")
addTrack("Elevator", "Ash", "dark",
  "c4 - - eb4 - - g4 - - ab4 - g4 - - - -",
  "c2 - - - c2 - - - ab2 - - - g2 - - -", 76, "#b07aff")
addTrack("Last Torch", "Ash", "dark",
  "a3 - - c4 - - e4 - f4 - e4 - c4 - - -",
  "a2 - - - a2 - - - f2 - - - e2 - - -", 88, "#ff8f4d")
addTrack("Sunrise Ride", "Verve", "hype",
  "f4 g4 a4 - c5 - a4 g4 f4 g4 a4 c5 d5 - - -",
  "f2 - c3 - a2 - f2 - bb2 - f2 - c3 - - -", 140, "#4dffb0")

let moods = ["all", "calm", "hype", "dark"]
let mood = 0

// ---- what the app is doing ----
let screen = 0            // 0 home, 1 search, 2 library
let playing = 0 - 1       // which track is playing, or -1
let paused = false
let startedAt = 0
let liked = []            // one 0/1 per track
let queue = []            // the playlist you build
let note = ""
let noteUntil = 0
let scroll = 0

// the clock on whoever's computer is showing this, which Volt has no word for yet
let greeting = "Good evening"
# greeting = (new Date().getHours() < 12 ? "Good morning" : new Date().getHours() < 18 ? "Good afternoon" : "Good evening");

for each one in tracks {
  add 0 to liked
}

// ---- remembering things between visits ----
fn loadMine() {
  let gotLiked = saved("voltfm-liked", [])
  if length(gotLiked) == length(tracks) {
    liked = gotLiked
  }
  queue = saved("voltfm-queue", [])
  return 0
}
fn saveMine() {
  save "voltfm-liked", liked
  save "voltfm-queue", queue
  return 0
}
loadMine()

fn say(message) {
  note = message
  noteUntil = uptime + 1800
  return 0
}

// ---- the list you are looking at ----
fn inMood(i) {
  if mood == 0 {
    return true
  }
  return tracks[i].mood == moods[mood]
}

fn shownCount() {
  let n = 0
  for each one, i in tracks {
    if screen == 2 {
      if liked[i] == 1 {
        n += 1
      }
    } else {
      if inMood(i) {
        n += 1
      }
    }
  }
  return n
}

// the track sitting at row 'slot' of whatever list is on screen, or -1
fn trackAtRow(slot) {
  let n = 0
  for each one, i in tracks {
    let keep = inMood(i)
    if screen == 2 {
      keep = liked[i] == 1
    }
    if keep {
      if n == slot {
        return i
      }
      n += 1
    }
  }
  return 0 - 1
}

// ---- playing ----
fn playTrack(i) {
  if i < 0 or i >= length(tracks) {
    return 0
  }
  playing = i
  paused = false
  startedAt = uptime
  say("Playing " + tracks[i].name)
  return 0
}

fn nextTrack(by) {
  if playing < 0 {
    playTrack(0)
    return 0
  }
  playTrack((playing + by + length(tracks)) % length(tracks))
  return 0
}

fn toggleLike() {
  if playing < 0 {
    return 0
  }
  if liked[playing] == 1 {
    liked[playing] = 0
    say("Removed from Liked")
  } else {
    liked[playing] = 1
    say("Added to Liked")
  }
  saveMine()
  return 0
}

fn addToQueue() {
  if playing < 0 {
    return 0
  }
  if contains(queue, playing) {
    say("Already in your playlist")
    return 0
  }
  add playing to queue
  saveMine()
  say("Added to your playlist")
  return 0
}

// ---- cover art, drawn from the song's own name ----
// The same name always gives the same cover, so a song keeps its look.
fn nameNumber(name) {
  let total = 7
  for i from 0 to length(name) - 1 {
    total = (total * 31 + indexOf("abcdefghijklmnopqrstuvwxyz .", lower(part(name, i, 1))) + 1) % 100000
  }
  return total
}

fn drawCover(i, x, y, size) {
  let one = tracks[i]
  let seed = nameNumber(one.name)
  box x, y, size, size color "#15181f"
  // a few bars whose heights come from the name
  let bars = 5
  let w = size / bars
  for b from 0 to bars - 1 {
    let h = size / 6 + (seed / pow(7, b) % 1000) * (size * 2 / 3) / 1000
    let shade = one.tint
    if b % 2 == 1 {
      shade = "#ffffff"
    }
    box x + b * w + 1, y + size - h, w - 2, h color shade
  }
  // a ring in the corner, so no two covers read the same
  let r = 3 + seed % 5
  box x + size - r - 4, y + 4, r, r color "#0c0e13"
  return 0
}

// ---- drawing the app ----
fn drawSidebar() {
  box 0, 0, 92, 270 color "#0a0c11"
  write "VOLT FM" at 10, 12 color "#ffd23f"
  let labels = ["Home", "Search", "Library"]
  for each label, i in labels {
    let y = 44 + i * 22
    if screen == i {
      box 0, y - 4, 92, 20 color "#171b23"
      box 0, y - 4, 2, 20 color "#ffd23f"
    }
    let shade = "#8b93a7"
    if screen == i {
      shade = "#ffffff"
    }
    write "{i + 1}  {label}" at 12, y color shade
  }
  write "{length(queue)} in playlist" at 10, 230 color "#5d6579"
  return 0
}

fn drawRow(i, slot, top) {
  let one = tracks[i]
  let y = top + slot * 26
  if playing == i {
    box 100, y - 2, 372, 24 color "#171b23"
  }
  drawCover(i, 102, y, 20)
  let shade = "#e2e5ee"
  if playing == i {
    shade = one.tint
  }
  write one.name at 130, y + 1 color shade
  write one.artist at 130, y + 11 color "#6b7389"
  write one.mood at 330, y + 6 color "#5d6579"
  if liked[i] == 1 {
    write "liked" at 398, y + 6 color "#ff4d6d"
  }
  write "{one.tempo}" at 446, y + 6 color "#5d6579"
  return 0
}

fn drawList(top) {
  let rows = shownCount()
  let fits = 6
  if rows == 0 {
    write "Nothing here yet." at 102, top + 10 color "#6b7389"
    if screen == 2 {
      write "Play something and press L to like it." at 102, top + 24 color "#5d6579"
    }
    return 0
  }
  for slot from 0 to fits - 1 {
    let at = slot + scroll
    if at < rows {
      drawRow(trackAtRow(at), slot, top)
    }
  }
  if rows > fits {
    write "{scroll + 1}-{min(scroll + fits, rows)} of {rows}   up and down arrows to scroll" at 102, top + fits * 26 + 4 color "#5d6579"
  }
  return 0
}

fn drawPlayer() {
  box 92, 226, 388, 44 color "#11141b"
  box 92, 226, 388, 1 color "#232834"
  if playing < 0 {
    write "Nothing playing - click a song" at 104, 244 color "#6b7389"
    return 0
  }
  let one = tracks[playing]
  drawCover(playing, 100, 232, 32)
  write one.name at 140, 234 color "#ffffff"
  write one.artist at 140, 246 color "#6b7389"

  // a moving bar for each voice, in step with the tempo
  let beat = uptime * tempoOf(playing) / 30000
  for b from 0 to 11 {
    let h = 4 + (sin3(beat * 200 + b * 300) + 1000) * 14 / 2000
    if paused {
      h = 4
    }
    box 280 + b * 7, 252 - h, 5, h color one.tint
  }
  if paused {
    write "paused" at 420, 240 color "#8b93a7"
  } else {
    write "playing" at 420, 240 color one.tint
  }
  if liked[playing] == 1 {
    write "liked" at 372, 240 color "#ff4d6d"
  }
  return 0
}

fn tempoOf(i) {
  return tracks[i].tempo
}

// ---- keys ----
when key "space" pressed {
  if playing < 0 {
    playTrack(0)
  } else {
    paused = not paused
  }
}
when key "1" pressed {
  screen = 0
  scroll = 0
}
when key "2" pressed {
  screen = 1
  scroll = 0
}
when key "3" pressed {
  screen = 2
  scroll = 0
}
when key "left" pressed {
  nextTrack(0 - 1)
}
when key "right" pressed {
  nextTrack(1)
}
when key "up" pressed {
  scroll = max(0, scroll - 1)
}
when key "down" pressed {
  scroll = clamp(scroll + 1, 0, max(0, shownCount() - 6))
}
when key "l" pressed {
  toggleLike()
}
when key "a" pressed {
  addToQueue()
}

every frame {
  // the music itself. Volt only restarts a tune when the words change, so
  // setting the same one every frame simply keeps it going.
  if playing >= 0 and not paused {
    music tracks[playing].mel, tracks[playing].low tempo tracks[playing].tempo
  } else {
    music off
  }

  // ---- clicks ----
  if clicked() {
    let mx = mousex()
    let my = mousey()
    if mx < 92 {
      for i from 0 to 2 {
        if my >= 40 + i * 22 and my < 60 + i * 22 {
          screen = i
          scroll = 0
        }
      }
    } else {
      if screen == 1 and my >= 34 and my < 50 {
        for each name, i in moods {
          let x = 100 + i * 62
          if mx >= x and mx < x + 56 {
            mood = i
            scroll = 0
          }
        }
      }
      let top = 60
      if screen == 1 {
        top = 76
      }
      if my >= top and my < top + 6 * 26 {
        let slot = (my - top) / 26
        let picked = trackAtRow(slot + scroll)
        if picked >= 0 {
          playTrack(picked)
        }
      }
      if my >= 226 and playing >= 0 {
        if mx >= 400 and mx < 416 {
          toggleLike()
        } else {
          paused = not paused
        }
      }
    }
  }

  // ---- the picture ----
  paint "#0c0e13"
  drawSidebar()

  let title = greeting

  if screen == 1 {
    title = "Search"
  }
  if screen == 2 {
    title = "Your Library"
  }
  write title at 100, 14 color "#ffffff"
  write "{length(tracks)} songs, played by this page" at 100, 30 color "#5d6579"

  if screen == 1 {
    for each name, i in moods {
      let x = 100 + i * 62
      let fill = "#171b23"
      let shade = "#8b93a7"
      if mood == i {
        fill = "#ffd23f"
        shade = "#1b1600"
      }
      box x, 44, 56, 16 color fill
      write name at x + 28, 50 centered color shade
    }
    drawList(76)
  } else {
    drawList(60)
  }

  drawPlayer()

  if uptime < noteUntil {
    box 306, 8, 168, 15 color "#232834"
    write note at 390, 13 centered color "#ffd23f"
  }
}
