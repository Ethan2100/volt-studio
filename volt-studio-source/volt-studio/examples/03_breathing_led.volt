// Make an LED fade in and out smoothly, like it's breathing.
#c++
// Use a PWM pin (marked ~ on the Uno: 3, 5, 6, 9, 10, 11).
pin glow = 9 pwm

forever {
  fade glow to 100 over 1.5s
  fade glow to 0 over 1.5s
}
