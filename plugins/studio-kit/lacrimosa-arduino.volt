#c++
// Lacrimosa - Arduino buzzer rendition
//
// Mozarts Lacrimosa (Requiem in D minor, K.626, 1791) is public
// domain. An Arduino tone() can only play one note at a time, so
// this is my own single-voice transcription of the famous choral
// themes melodic shape (the rising-then-falling sigh figures in
// D minor) - not a note-for-note copy of the orchestral score.
//
// Wiring: buzzer/speaker signal lead to pin 9, other lead to GND.
// Use a PASSIVE buzzer/speaker (one that needs tone() to make any
// pitch at all) - a simple on/off piezo can only click, not sing.
//
// Note: pitch constants are lowercase (d4, a4, ...) on purpose -
// Arduino's own core already defines A0-A5 as built-in, read-only
// constants for the analog pins, so an uppercase "A4" collides
// with it and fails to build.

pin buzzer = 9

// --- note frequencies (Hz), equal temperament, a4 = 440 ---
let d4  = 294
let e4  = 330
let f4  = 349
let fs4 = 370
let g4  = 392
let a4  = 440
let bb4 = 466
let c5  = 523
let d5  = 587

fn note(hz, dur) {
  tone buzzer hz for dur ms
  wait 30ms              // tiny gap between notes so they don't blur together
}

fn rest(dur) {
  wait dur ms
}

fn lacrimosa() {
  // Phrase 1: La-cri-mo-sa, di-es il-la
  note(a4, 500)
  note(a4, 250)
  note(bb4, 250)
  note(a4, 500)
  note(g4, 250)
  note(fs4, 250)
  note(g4, 750)
  rest(150)

  // Phrase 2: echo, settling toward D minor
  note(a4, 500)
  note(a4, 250)
  note(bb4, 250)
  note(a4, 500)
  note(g4, 250)
  note(fs4, 250)
  note(d4, 750)
  rest(300)

  // Phrase 3: Quae re-sur-get ex fa-vil-la - rising
  note(d4, 250)
  note(e4, 250)
  note(f4, 250)
  note(g4, 500)
  note(a4, 250)
  note(bb4, 250)
  note(c5, 750)
  rest(150)

  // Phrase 4: Judicandus homo reus - the climax, then falling back
  note(d5, 500)
  note(c5, 250)
  note(bb4, 250)
  note(a4, 500)
  note(g4, 250)
  note(fs4, 250)
  note(g4, 1000)
  rest(1500)
}

forever {
  lacrimosa()
}
