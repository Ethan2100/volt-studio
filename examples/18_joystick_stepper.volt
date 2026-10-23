// Push a joystick left or right to turn a stepper motor. Push further to go faster.
#c++
// Joystick: VRx -> A0, +5V -> 5V, GND -> GND
// ULN2003 board: IN1 -> 8, IN2 -> 9, IN3 -> 10, IN4 -> 11, + -> 5V, - -> GND
pin joyX = A0 analog
pin motor = 8, 9, 10, 11 stepper

let resting = true

forever {
  let x = read joyX

  if x > 600 {
    set motor speed to map(x, 600, 1023, 2, 15)
    step motor 8
    resting = false
  } else if x < 420 {
    set motor speed to map(x, 420, 0, 2, 15)
    step motor -8
    resting = false
  } else if not resting {
    // joystick in the middle: stop and let the motor cool down
    off motor
    print "Stopped at " + read motor + " degrees"
    resting = true
  }
}
