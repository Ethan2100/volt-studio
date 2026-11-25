#html
// SHADOW FRUIT — RPG Kit example
// Controls: WASD + mouse, Shift run, Space jump
// 1 sword attack | Q Blood Swarm | E Blood Drain | R Crimson Burst | F Shadow Step

canvas 320, 180
import "game.volt"
import "combat.volt"
import "rpg.volt"

world3d "#090711" fog 1900 ambient 12 shadows
let Floor = block3d(0, -8, 0, 2400, 16, 2400, "#171522")
let RuneFloor = block3d(0, 1, 0, 900, 2, 900, "#21142c")
glow3d RuneFloor, "#311044"
solid(0, 0, 1200, 1200, -16, 0)
playerStart(0, 0, 0)

rpgEquipSword()
let Goblin = rpgSpawnEnemy("Shadow Goblin", 0, -420, 120, 9, 150, 900, 95, "#68436f")
let Bandit = rpgSpawnEnemy("Night Bandit", 260, -650, 180, 13, 175, 1100, 105, "#4d526b")

PLAYER_MAX_HP = 120
PLAYER_HP = 120
HUD_COLOR = "#c78bff"
HOTBAR_STYLE = "gold"
HOTBAR_SIZE = 25
HOTBAR_SLOTS = 4
HOTBAR_BACK = "#100b1dcc"
HOTBAR_RIM = "#633a80"
HOTBAR_PICKED = "#d49aff"
give("Shadow Fruit", 1, "#9b55d4")
give("Health Potion", 3, "#e34c70")

// Procedural bat swarm: body plus two wings per bat.
let BAT_BODY = []
let BAT_LEFT = []
let BAT_RIGHT = []
let BAT_COUNT = 10
let BAT_ANGLE = 0
let BAT_MS = 0
let BAT_PULSE = 0
let i = 0
while i < BAT_COUNT {
  let body = ball3d(0, -500, 0, 9, "#17121f")
  let leftWing = block3d(0, -500, 0, 22, 4, 5, "#2b1738")
  let rightWing = block3d(0, -500, 0, 22, 4, 5, "#2b1738")
  glow3d body, "#8c35a8"
  add body to BAT_BODY
  add leftWing to BAT_LEFT
  add rightWing to BAT_RIGHT
  i += 1
}

fn hideShadowBats() {
  let n = 0
  while n < BAT_COUNT {
    show3d BAT_BODY[n], false
    show3d BAT_LEFT[n], false
    show3d BAT_RIGHT[n], false
    n += 1
  }
}

fn bloodSwarm() {
  if not ready("Blood Swarm") {
    return
  }
  BAT_MS = 5200
  BAT_PULSE = 0
  let n = 0
  while n < BAT_COUNT {
    show3d BAT_BODY[n], true
    show3d BAT_LEFT[n], true
    show3d BAT_RIGHT[n], true
    n += 1
  }
  burst3d PLAYER_X, PLAYER_Y + 90, PLAYER_Z, "#9c42c7", 45, 280
  tone 180 to 440 for 180ms
  startCooldown("Blood Swarm", 7200)
}

fn stepShadowBats() {
  if BAT_MS <= 0 {
    return
  }
  BAT_MS -= 16
  BAT_PULSE -= 16
  BAT_ANGLE += 24
  let n = 0
  while n < BAT_COUNT {
    let a = BAT_ANGLE + n * 360
    let bx = PLAYER_X + sin3(a) * 155 / 1000
    let bz = PLAYER_Z - cos3(a) * 155 / 1000
    let by = PLAYER_Y + 105 + sin3(a * 2) * 38 / 1000
    let flap = sin3(a * 5) * 22 / 1000
    move3d BAT_BODY[n], bx, by, bz
    move3d BAT_LEFT[n], bx - 15, by + flap, bz
    move3d BAT_RIGHT[n], bx + 15, by - flap, bz
    turn3d BAT_BODY[n], a
    turn3d BAT_LEFT[n], a - 250
    turn3d BAT_RIGHT[n], a + 250
    n += 1
  }
  if BAT_PULSE <= 0 {
    let hit = damageArea(PLAYER_X, PLAYER_Z, 205, 7)
    if hit > 0 {
      healPlayer(hit * 2)
      burst3d PLAYER_X, PLAYER_Y + 70, PLAYER_Z, "#d13c69", 15, 170
    }
    BAT_PULSE = 650
  }
  if BAT_MS <= 0 {
    hideShadowBats()
    burst3d PLAYER_X, PLAYER_Y + 80, PLAYER_Z, "#54246e", 28, 180
  }
}

fn bloodDrain() {
  if not ready("Blood Drain") {
    return
  }
  let enemy = nearestTarget(PLAYER_X, PLAYER_Z, 430)
  if enemy >= 0 {
    hurtTarget(enemy, 28)
    healPlayer(18)
    burst3d TARGET_X[enemy], TARGET_TOP[enemy], TARGET_Z[enemy], "#d72e58", 34, 260
    burst3d PLAYER_X, PLAYER_Y + 70, PLAYER_Z, "#a63bd0", 18, 180
    tone 520 to 180 for 160ms
  }
  startCooldown("Blood Drain", 2400)
}

fn crimsonBurst() {
  if not ready("Crimson Burst") {
    return
  }
  burst3d PLAYER_X, PLAYER_Y + 35, PLAYER_Z, "#c52d61", 70, 440
  let hit = damageArea(PLAYER_X, PLAYER_Z, 340, 32)
  if hit > 0 {
    healPlayer(hit * 5)
  }
  tone 110 to 55 for 260ms
  startCooldown("Crimson Burst", 5200)
}

fn shadowStep() {
  if not ready("Shadow Step") {
    return
  }
  burst3d PLAYER_X, PLAYER_Y + 65, PLAYER_Z, "#54216f", 30, 220
  PLAYER_X += sin3(PLAYER_YAW) * 280 / 1000
  PLAYER_Z -= cos3(PLAYER_YAW) * 280 / 1000
  burst3d PLAYER_X, PLAYER_Y + 65, PLAYER_Z, "#a63bd0", 38, 240
  startCooldown("Shadow Step", 3000)
}

hideShadowBats()
every frame {
  playerStep()
  stepCombat()
  rpgStepEnemies()
  rpgSwordStep()
  stepShadowBats()

  when key "1" pressed {
    rpgSwordAttack()
  }
  when key "q" pressed {
    bloodSwarm()
  }
  when key "e" pressed {
    bloodDrain()
  }
  when key "r" pressed {
    crimsonBurst()
  }
  when key "f" pressed {
    shadowStep()
  }

  render3d
  drawCombat()
  write "SHADOW FRUIT" at 160, 8 centered color "#d49aff" size 1
  write "1 Sword   Q Swarm   E Drain   R Burst   F Step" at 160, 22 centered color "#d9c9e8"
}
