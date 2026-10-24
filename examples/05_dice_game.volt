// Press the button to roll a dice: blinks the number and beeps.
#c++
// Button on pin 2 (to GND), buzzer on pin 8, LED on pin 13.
pin led = 13
pin buzzer = 8
pin button = 2 input

let rolls = 0

fn blinkTimes(count) {
  repeat count {
    on led
    wait 200ms
    off led
    wait 200ms
  }
}

fn beep(pitch) {
  tone buzzer pitch for 120ms
}

when button pressed {
  rolls = rolls + 1
  let dice = random(1, 6)
  print "Roll " + rolls + ": you got " + dice
  beep(400 + dice * 100)
  blinkTimes(dice)
  if dice == 6 {
    print "SIX! Lucky roll!"
    repeat 3 {
      beep(1200)
      wait 80ms
    }
  }
}
