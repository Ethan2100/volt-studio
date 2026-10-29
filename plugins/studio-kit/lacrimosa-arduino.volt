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

pin buzzer = 9

// --- note frequencies (Hz), equal temperament, A4 = 440 ---
let D4  = 294
let E4  = 330
let F4  = 349
let FS4 = 370
let G4  = 392
let A4  = 440
let Bb4 = 466
let C5  = 523
let D5  = 587

fn note(hz, dur) {
  tone buzzer hz for dur ms
  wait 30ms              // tiny gap between notes so they don't blur together
}

fn rest(dur) {
  wait dur ms
}

fn lacrimosa() {
  // Phrase 1: La-cri-mo-sa, di-es il-la
  note(A4, 500)
  note(A4, 250)
  note(Bb4, 250)
  note(A4, 500)
  note(G4, 250)
  note(FS4, 250)
  note(G4, 750)
  rest(150)

  // Phrase 2: echo, settling toward D minor
  note(A4, 500)
  note(A4, 250)
  note(Bb4, 250)
  note(A4, 500)
  note(G4, 250)
  note(FS4, 250)
  note(D4, 750)
  rest(300)

  // Phrase 3: Quae re-sur-get ex fa-vil-la - rising
  note(D4, 250)
  note(E4, 250)
  note(F4, 250)
  note(G4, 500)
  note(A4, 250)
  note(Bb4, 250)
  note(C5, 750)
  rest(150)

  // Phrase 4: Judicandus homo reus - the climax, then falling back
  note(D5, 500)
  note(C5, 250)
  note(Bb4, 250)
  note(A4, 500)
  note(G4, 250)
  note(FS4, 250)
  note(G4, 1000)
  rest(1500)
}

forever {
  lacrimosa()
}
