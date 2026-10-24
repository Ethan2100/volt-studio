// Turn a knob (potentiometer) to move a servo motor.
#c++
// Knob middle leg -> A0, outer legs -> 5V and GND. Servo signal -> pin 6.
pin knob = A0 analog
pin arm = 6 servo

every 30ms {
  let value = read knob
  set arm to map(value, 0, 1023, 0, 180)
}

every 1s {
  print "Knob: " + read knob + "  Servo angle: " + read arm
}
