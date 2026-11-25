#html
// SHADOW LIFE STEAL — Volt 3.4.0 sample
// WASD + mouse | 1 sword | Q mark | E leech | R harvest | F wraith step | G eclipse
canvas 320, 180
import "game.volt"
import "combat.volt"
import "rpg.volt"

world3d "#080711" fog 1900 ambient 12 shadows
let Floor = block3d(0, -8, 0, 2400, 16, 2400, "#171321")
let RuneFloor = block3d(0, 1, 0, 900, 2, 900, "#21132e")
glow3d RuneFloor, "#35124b"
solid(0, 0, 1200, 1200, -16, 0)
playerStart(0, 0, 0)
rpgEquipSword()
let Enemy = rpgSpawnEnemy("Dusk Warden", 0, -430, 140, 12, 160, 950, 100, "#5c3b70")
PLAYER_MAX_HP = 150
PLAYER_HP = 150
HUD_COLOR = "#b879f5"
HOTBAR_STYLE = "gold"
HOTBAR_SIZE = 25
HOTBAR_SLOTS = 5
HOTBAR_BACK = "#100b1dcc"
HOTBAR_RIM = "#633a80"
HOTBAR_PICKED = "#d49aff"

let MARK_MS = 0
let ECLIPSE_MS = 0
let ECLIPSE_PULSE = 0
let AURA = ball3d(0, -500, 0, 90, "#321047")
glow3d AURA, "#a34be8"

fn shadowMark() {
  if not ready("Umbral Mark") { return }
  MARK_MS = 8000
  burst3d TARGET_X[0], TARGET_TOP[0], TARGET_Z[0], "#a34be8", 28, 220
  startCooldown("Umbral Mark", 6500)
}
fn shadowLeech() {
  if not ready("Shadow Leech") { return }
  let enemy = nearestTarget(PLAYER_X, PLAYER_Z, 480)
  if enemy >= 0 {
    hurtTarget(enemy, 34)
    healPlayer(24)
    burst3d TARGET_X[enemy], TARGET_TOP[enemy], TARGET_Z[enemy], "#d43c83", 34, 260
    burst3d PLAYER_X, PLAYER_Y + 75, PLAYER_Z, "#9b4bd2", 24, 190
    tone 480 to 170 for 180ms
  }
  startCooldown("Shadow Leech", 3200)
}
fn nightfallHarvest() {
  if not ready("Nightfall Harvest") { return }
  let hit = damageArea(PLAYER_X, PLAYER_Z, 370, 26)
  if hit > 0 { healPlayer(hit * 10) }
  burst3d PLAYER_X, PLAYER_Y + 45, PLAYER_Z, "#6b2797", 85, 460
  tone 120 to 48 for 300ms
  startCooldown("Nightfall Harvest", 8500)
}
fn wraithStep() {
  if not ready("Wraith Step") { return }
  burst3d PLAYER_X, PLAYER_Y + 65, PLAYER_Z, "#54216f", 36, 220
  PLAYER_X += sin3(PLAYER_YAW) * 340 / 1000
  PLAYER_Z -= cos3(PLAYER_YAW) * 340 / 1000
  burst3d PLAYER_X, PLAYER_Y + 65, PLAYER_Z, "#b35bea", 40, 250
  startCooldown("Wraith Step", 3000)
}
fn eclipseAscendant() {
  if not ready("Eclipse Ascendant") { return }
  ECLIPSE_MS = 12000
  ECLIPSE_PULSE = 0
  burst3d PLAYER_X, PLAYER_Y + 40, PLAYER_Z, "#9c48d4", 100, 520
  tone 90 to 360 for 420ms
  startCooldown("Eclipse Ascendant", 30000)
}
fn eclipseStep() {
  if ECLIPSE_MS <= 0 { show3d AURA, false; return }
  ECLIPSE_MS -= 16
  ECLIPSE_PULSE -= 16
  move3d AURA, PLAYER_X, PLAYER_Y + 85, PLAYER_Z
  show3d AURA, true
  if ECLIPSE_PULSE <= 0 {
    burst3d PLAYER_X, PLAYER_Y + 80, PLAYER_Z, "#9b4bd2", 14, 190
    ECLIPSE_PULSE = 500
  }
  if ECLIPSE_MS <= 0 {
    show3d AURA, false
    burst3d PLAYER_X, PLAYER_Y + 80, PLAYER_Z, "#54246e", 38, 230
  }
}
every frame {
  playerStep()
  stepCombat()
  rpgStepEnemies()
  rpgSwordStep()
  eclipseStep()
  when key "1" pressed { rpgSwordAttack() }
  when key "q" pressed { shadowMark() }
  when key "e" pressed { shadowLeech() }
  when key "r" pressed { nightfallHarvest() }
  when key "f" pressed { wraithStep() }
  when key "g" pressed { eclipseAscendant() }
  render3d
  drawCombat()
  write "SHADOW LIFE STEAL" at 160, 8 centered color "#d49aff" size 1
  write "Q Mark  E Leech  R Harvest  F Step  G Eclipse" at 160, 22 centered color "#d9c9e8"
}