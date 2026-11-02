// Gamedev struct types: a named shape for the things in a game instead of a
// pile of same-length lists (ex, ey, ehp, emaxhp, ...). Arrow keys move the
// hero; Space hits whatever's closest and knocks a little health off it.
#html
canvas 320, 180

Player = type { name: string, health: int, maxHealth: int, x: int, y: int, speed: int }
Enemy = type { name: string, health: int, x: int, y: int, color: string }

let hero = Player { name: "Finn", health: 10, maxHealth: 10, x: 150, y: 80, speed: 2 }

let enemies = []
add Enemy { name: "Slime", health: 4, x: 60, y: 40, color: "#6fd0a8" } to enemies
add Enemy { name: "Goblin", health: 6, x: 240, y: 120, color: "#7fae4a" } to enemies
add Enemy { name: "Imp", health: 3, x: 40, y: 140, color: "#e06a6a" } to enemies

every frame {
  if held("left") { hero.x -= hero.speed }
  if held("right") { hero.x += hero.speed }
  if held("up") { hero.y -= hero.speed }
  if held("down") { hero.y += hero.speed }

  if held("space") {
    let i = 0
    let best = -1
    let bestDist = 9999
    while i < length(enemies) {
      let d = abs(enemies[i].x - hero.x) + abs(enemies[i].y - hero.y)
      if d < bestDist {
        bestDist = d
        best = i
      }
      i += 1
    }
    if best >= 0 and bestDist < 40 {
      enemies[best].health -= 1
      if enemies[best].health <= 0 {
        remove enemies[best]
      }
    }
  }

  paint "#14111a"
  box hero.x - 6, hero.y - 6, 12, 12 color "#ffd23f"
  write hero.name at hero.x, hero.y - 16 color "#ffd23f" size 1 centered

  let i = 0
  while i < length(enemies) {
    box enemies[i].x - 5, enemies[i].y - 5, 10, 10 color enemies[i].color
    write text(enemies[i].health) at enemies[i].x, enemies[i].y - 14 color "#fff" size 1 centered
    i += 1
  }

  write hero.name + " - " + text(hero.health) + "/" + text(hero.maxHealth) + " hp" at 8, 8 color "#fff" size 1 shadow
  write "Arrows to move, Space to hit the nearest enemy" at 8, 170 color "#9a93a8" size 1 shadow
}
