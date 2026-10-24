// A night light: the darker the room, the brighter the LED.
#c++
// Light sensor (LDR) on A0 with a 10k resistor to GND, LED on PWM pin 9.
pin sensor = A0 analog
pin glow = 9 pwm

every 100ms {
  let light = read sensor
  let brightness = map(light, 0, 1023, 100, 0)
  set glow to constrain(brightness, 0, 100)
}

every 2s {
  print "Light level: " + read sensor + "  LED: " + read glow + "%"
}
