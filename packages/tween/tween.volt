// tween - smooth movement for games.
//
// For #html and #js games. The curves use big whole numbers internally, which would overflow
// the 32-bit numbers on an Arduino, so this isn't meant for boards.
//
//   volt add ./packages/tween
//   import "tween"
//
// Everything takes a progress from 0 to 100 and gives back a progress from 0 to 100, so you
// can feed it straight into lerp():
//
//   let t = easeOut(progress)
//   box lerp(startX, endX, t), y, 20, 20 color "#ffd23f"

// Starts slowly, then speeds up.
fn easeIn(percent) {
  let amount = clamp(percent, 0, 100)
  return amount * amount / 100
}

// Starts quickly, then settles.
fn easeOut(percent) {
  let amount = clamp(percent, 0, 100)
  return 100 - (100 - amount) * (100 - amount) / 100
}

// Slow at both ends, quick in the middle. The usual choice for moving a menu or a camera.
fn easeInOut(percent) {
  let amount = clamp(percent, 0, 100)
  if amount < 50 {
    return easeIn(amount * 2) / 2
  }
  return 50 + easeOut((amount - 50) * 2) / 2
}

// Overshoots a little and comes back, so a thing lands with some weight.
fn easeBack(percent) {
  let amount = clamp(percent, 0, 100)
  let pull = 170
  return (amount * amount * ((pull + 100) * amount / 100 - pull)) / 10000
}

// Bounces to a stop, like something dropped on a floor.
// (the maths is done in hundredths and divided down at the end, so whole numbers are enough;
//  the four pieces of the curve meet at 36.36, 72.73 and 90.91, hence the thresholds)
fn easeBounce(percent) {
  let at = clamp(percent, 0, 100) * 100
  if at < 3636 {
    return clamp(756 * at * at / 1000000 / 100, 0, 100)
  }
  if at < 7273 {
    let d = at - 5455
    return clamp((756 * d * d / 1000000 + 7500) / 100, 0, 100)
  }
  if at < 9091 {
    let d = at - 8182
    return clamp((756 * d * d / 1000000 + 9375) / 100, 0, 100)
  }
  let d = at - 9545
  return clamp((756 * d * d / 1000000 + 9844) / 100, 0, 100)
}

// How far through something is, as 0 to 100. 'started' is when it began (uptime), 'ms' how long it lasts.
fn progress(started, ms) {
  if ms <= 0 {
    return 100
  }
  return clamp((uptime - started) * 100 / ms, 0, 100)
}

// A value that wobbles around zero and dies away - good for screen shake and recoil.
// 'strength' is how far it moves at the start, 'percent' how far through the shake you are.
fn shake(strength, percent) {
  let left = 100 - clamp(percent, 0, 100)
  return random(0 - strength, strength) * left / 100
}
