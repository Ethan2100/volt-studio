// A touch lamp for ESP32/Pico: each press cycles the brightness.
#micropython
// LED on GPIO 15 (with a resistor), button between GPIO 4 and GND.
pin lamp = 15 pwm
pin button = 4 input

let level = 0

when button pressed {
  level = level + 25
  if level > 100 {
    level = 0
  }
  print "Brightness: " + level + "%"
  fade lamp to level over 300ms
}
