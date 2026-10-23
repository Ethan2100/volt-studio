// Count button presses and flash the LED every 5 presses.
#c++
// Wire a button between pin 2 and GND (no resistor needed).
pin led = 13
pin button = 2 input

let presses = 0

print "Ready! Press the button."

when button pressed {
  presses = presses + 1
  print "Pressed " + presses + " times"

  if presses % 5 == 0 {
    print "That's " + presses + "!"
    repeat 3 {
      on led
      wait 100ms
      off led
      wait 100ms
    }
  }
}
