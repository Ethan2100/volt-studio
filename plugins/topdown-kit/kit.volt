// =====================================================================
// Top-down kit - the boilerplate every tile-based top-down game ends up
// writing by hand: a reusable entity shape, camera-follow smoothing,
// chase AI, and damage/kill helpers. Built on Volt's struct types
// (`Name = type { ... }`), so paste this near the top of a #html game,
// after your sprites, and adapt the Entity fields to your own game.
//
// Pairs well with the VFX engine library (particle bursts, hit flashes)
// and the UI kit (menus, HUD panels) - none of them overlap with this.
//
// A quick example of the whole loop:
//
//   let enemies = []
//   add Entity { x: 80, y: 40, w: 10, h: 8, hp: 6, maxHp: 6, kind: "goblin" } to enemies
//   let cam = Camera { x: 0, y: 0 }
//
//   every frame {
//     cameraFollow(cam, hero.x, hero.y, 320, 180, worldW, worldH)
//     let i = length(enemies) - 1
//     while i >= 0 {
//       tickHurt(enemies[i])
//       if dist(enemies[i].x, enemies[i].y, hero.x, hero.y) < 60 {
//         chaseStep(enemies[i], 1, hero.x, hero.y)
//       }
//       if overlaps(hero.x, hero.y, 10, 8, enemies[i].x, enemies[i].y, enemies[i].w, enemies[i].h) {
//         if hit(enemies[i], swordDmg, 8) { remove enemies[i] }
//       }
//       i -= 1
//     }
//     camera cam.x, cam.y
//     // ... drawWorld() / draw each enemy, flashing while .hurt > 0 ...
//   }
// =====================================================================

Entity = type { x: int, y: int, w: int, h: int, hp: int, maxHp: int, kind: string, dx: int, dy: int, hurt: int }
Camera = type { x: int, y: int }

// Keeps an entity's box fully inside 0,0 .. worldW,worldH - call after
// moving it so nothing ever walks off the edge of the map.
fn clampToWorld(e, worldW, worldH) {
  e.x = constrain(e.x, 0, worldW - e.w)
  e.y = constrain(e.y, 0, worldH - e.h)
}

// Steps an entity up to `speed` pixels toward a point - the "chase"
// half of the usual wander-then-chase enemy pattern. Call it every
// frame once the entity is within range of its target (see the example
// above). e.dx/e.dy are left set to the facing direction, handy for
// picking a run-animation frame or flipping a sprite.
fn chaseStep(e, speed, targetX, targetY) {
  e.dx = sign(targetX - e.x)
  e.dy = sign(targetY - e.y)
  e.x += e.dx * speed
  e.y += e.dy * speed
}

// Smoothly slides a camera toward centring on (targetX, targetY),
// clamped so it never shows past the edge of a worldW x worldH map.
// Call every frame, then draw with `camera cam.x, cam.y`.
fn cameraFollow(cam, targetX, targetY, viewW, viewH, worldW, worldH) {
  let tx = constrain(targetX - viewW / 2, 0, max(0, worldW - viewW))
  let ty = constrain(targetY - viewH / 2, 0, max(0, worldH - viewH))
  cam.x += sign(tx - cam.x) * max(1, abs(tx - cam.x) / 6)
  cam.y += sign(ty - cam.y) * max(1, abs(ty - cam.y) / 6)
}

// Takes damage and starts a short "hurt flash" timer (see tickHurt)
// your draw code can read to flash the sprite white, e.g.
// `draw goblinIdle at e.x, e.y flash e.hurt > 0`. Returns true if this
// hit brought hp to 0 or below, so the caller knows to remove() it.
fn hit(e, amount, flashFrames) {
  e.hp -= amount
  e.hurt = flashFrames
  return e.hp <= 0
}

// Ticks an entity's hurt-flash timer down - call once per entity, every
// frame (before or after moving it, doesn't matter).
fn tickHurt(e) {
  if e.hurt > 0 {
    e.hurt -= 1
  }
}

// The index of whichever position in `xs`/`ys` (two same-length lists of
// coordinates) is closest to (fromX, fromY), or -1 if they're empty.
// Handy for "attack whatever enemy is nearest" or simple homing.
fn nearestIndex(fromX, fromY, xs, ys) {
  let best = -1
  let bestDist = 999999
  let i = 0
  while i < length(xs) {
    let d = dist(fromX, fromY, xs[i], ys[i])
    if d < bestDist {
      bestDist = d
      best = i
    }
    i += 1
  }
  return best
}
