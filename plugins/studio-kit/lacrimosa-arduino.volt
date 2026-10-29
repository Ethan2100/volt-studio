#c++
// Lacrimosa - Arduino buzzer rendition, with a pluck-and-decay envelope
//
// Mozarts Lacrimosa (Requiem in D minor, K.626, 1791) is public
// domain. This is my own single-voice transcription of the famous
// choral themes melodic shape (the rising-then-falling sigh figures
// in D minor) - not a note-for-note copy of the orchestral score.
//
// Covers the whole movement's text/arc: the opening "Lacrimosa dies
// illa" grief, the rising "qua resurget ex favilla", the big dramatic
// climax at "Judicandus homo reus" (the guilty man to be judged - the
// loudest, most intense moment in the real piece too), then it recedes
// through "Huic ergo parce, Deus" / "pie Jesu Domine" into a hushed,
// held "dona eis requiem" ending - the real movement's own build-and-
// release shape, same idea plenty of "epic" covers lean on.
//
// Wiring: speaker's signal lead to pin 9, other lead to GND. Put a
// ~150-220 ohm resistor in series on the signal lead - a magnetic
// coil speaker driven straight off a digital pin with no resistor
// can pull more current than the pin is rated for.
//
// Why this doesn't use the plain tone()/wait notes: tone() is a
// flat square wave at constant volume, which always sounds like an
// electronic beep no matter the pitch. Since this is a real magnetic
// coil speaker (not a piezo), it can actually reproduce whatever
// waveform you drive it with - so pluckNote() below bit-bangs the
// square wave itself and shrinks its duty cycle over the note's
// length, giving each note a loud "pluck" that fades into a quieter
// tail, like a struck piano string decaying. Still a synthesized
// tone, not real piano audio, but noticeably less flat than tone().
//
// Note: pitch constants are lowercase (d4, a4, ...) on purpose -
// Arduino's own core already defines A0-A5 as built-in, read-only
// constants for the analog pins, so an uppercase "A4" collides
// with it and fails to build.

## void pluckNote(int pin, int freqHz, int totalMs) {
##   if (freqHz <= 0) { delay(totalMs); return; }
##   unsigned long periodUs = 1000000UL / (unsigned long)freqHz;
##   unsigned long startMs = millis();
##   while (millis() - startMs < (unsigned long)totalMs) {
##     float t = (millis() - startMs) / (float)totalMs;   // 0..1 through the note
##     float decay = (1.0f - t) * (1.0f - t);              // eases out fast, like a pluck
##     if (decay < 0.04f) decay = 0.04f;                    // keep a faint tail audible
##     unsigned long onUs = (unsigned long)(periodUs * 0.5f * decay);
##     if (onUs < 2) onUs = 2;
##     unsigned long offUs = (periodUs > onUs) ? (periodUs - onUs) : 2;
##     digitalWrite(pin, HIGH);
##     delayMicroseconds(onUs);
##     digitalWrite(pin, LOW);
##     delayMicroseconds(offUs);
##   }
##   digitalWrite(pin, LOW);
## }

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
  # pluckNote(buzzer, hz, dur);
  wait 20ms              // tiny gap between notes so they don't blur together
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

  // Phrase 4: Judicandus homo reus - the big dramatic climax. A held
  // high note, then a fast shimmer between two notes (the closest a
  // single buzzer can get to sounding "fuller" instead of flat) before
  // falling back.
  note(d5, 700)
  note(d5, 120)
  note(c5, 120)
  note(d5, 120)
  note(c5, 120)
  note(bb4, 250)
  note(a4, 500)
  note(g4, 250)
  note(fs4, 250)
  note(g4, 1000)
  rest(800)

  // Phrase 5: Huic ergo parce, Deus - the tension releases, quieter
  // and lower, a plea rather than a cry
  note(g4, 500)
  note(f4, 250)
  note(e4, 250)
  note(d4, 750)
  rest(200)

  // Phrase 6: pie Jesu Domine - gentle, still descending
  note(f4, 375)
  note(e4, 250)
  note(d4, 500)
  note(e4, 250)
  note(f4, 750)
  rest(200)

  // Phrase 7: dona eis requiem - resolving home to D, held and let
  // fade (the pluck-and-decay envelope's natural tail fits the hushed
  // ending the real movement actually has)
  note(d4, 250)
  note(e4, 250)
  note(f4, 250)
  note(e4, 250)
  note(d4, 2000)
  rest(2500)
}

forever {
  lacrimosa()
}
