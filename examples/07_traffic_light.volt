// A traffic light with red, yellow and green LEDs.
#c++
pin red = 10
pin yellow = 11
pin green = 12

fn allOff() {
  off red
  off yellow
  off green
}

fn light(color, duration) {
  allOff()
  if color == 1 {
    on red
  } else if color == 2 {
    on yellow
  } else {
    on green
  }
  wait duration ms
}

forever {
  light(3, 4000)
  light(2, 1000)
  light(1, 4000)
}
