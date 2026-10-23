// Blink an LED on an ESP32 or Raspberry Pi Pico using MicroPython.
#micropython
// ESP32 built-in LED is usually pin 2. On a Pico, use pin 25.
pin led = 2

every 500ms {
  toggle led
  print "blink at " + uptime + " ms"
}
