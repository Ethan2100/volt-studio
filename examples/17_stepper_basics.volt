// Turn a 28BYJ-48 stepper motor: quarter turns, exact angles and full spins.
#c++
// ULN2003 board: IN1 -> 8, IN2 -> 9, IN3 -> 10, IN4 -> 11, + -> 5V, - -> GND
pin motor = 8, 9, 10, 11 stepper

set motor speed to 12

forever {
  print "Quarter turns..."
  repeat 4 {
    turn motor 90
    wait 500ms
  }

  print "Going to exact angles..."
  set motor to 45
  wait 500ms
  set motor to 180
  wait 500ms
  set motor to 0

  print "One full spin back"
  turn motor -360

  off motor
  wait 2s
}
