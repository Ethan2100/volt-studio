// Blink the built-in LED. The "hello world" of Arduino.
#c++
pin led = 13

every 500ms {
  toggle led
}
