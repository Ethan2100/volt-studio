#html
title "Arcane Training Grounds"
canvas 320, 180
import "game.volt"
import "combat.volt"
import "rpg.volt"

// Beginner-friendly playable sample: move, jump, fight, use a potion,
// and equip a sword and armour. Units are centimetres; y points upward.
WALK_SPEED = 420
RUN_SPEED = 720
JUMP_POWER = 450
PLAYER_MAX_HP = 120
PLAYER_HP = 120
HOTBAR_STYLE = "gold"
HOTBAR_NAME = true
HOTBAR_COUNTS = true

world3d "#111827" fog 1900 ambient 22 fov 75 shadows
let Floor = block3d(0, -10, 0, 1800, 20, 1800, "#344638")
let BackWall = block3d(0, 160, -900, 1800, 320, 30, "#55515e")
let LeftWall = block3d(-900, 160, 0, 30, 320, 1800, "#55515e")
let RightWall = block3d(900, 160, 0, 30, 320, 1800, "#55515e")
let PillarA = cyl3d(-450, 150, -350, 55, 300, "#9a815c")
let PillarB = cyl3d(450, 150, -350, 55, 300, "#9a815c")
let Goblin = block3d(0, 65, -480, 90, 130, 70, "#6d9b55")
glow3d Goblin, "#8cff74"
let Crystal = ball3d(0, 130, 300, 35, "#61d8ff")
glow3d Crystal, "#61d8ff"

clearSolids()
solid(0, 0, 900, 900, -20, 0)
solid(0, -900, 900, 15, 0, 320)
solid(-900, 0, 15, 900, 0, 320)
solid(900, 0, 15, 900, 0, 320)
solid(-450, -350, 55, 55, 0, 300)
solid(450, -350, 55, 55, 0, 300)
playerStart(0, 620, 0)

let goblin = target("Training Goblin", 0, 65, -480, 100, 85)
addLoot("training_goblin", "Gold", 100, 2, 4, "#ffd23f")
give("Health Potion", 2, "#e85d75")
give("Iron Sword", 1, "#e5c77a")
give("Leather Armour", 1, "#8a9bb5")
equipItem("Iron Sword", "Weapon", 12, 0)
equipItem("Leather Armour", "Chest", 0, 8)

let crystalTaken = false
let victory = false
let goblinRewarded = false

// Quest, progression and checkpoint systems are real runtime systems.
createQuest("training_trial", "Training Trial", 1, 120, "Arcane Shard", 1)
startQuest("training_trial")
defineSkill("arcane_burst", 1, 60, "")
addTrigger("crystal_checkpoint", 0, 300, 90, "checkpoint", "", true)
loadRpgProgress()

every frame {
  playerStep()
  stepCombat()
  stepRpg()
  stepTriggers(PLAYER_X, PLAYER_Z)

  // Q: Arcane burst. The cooldown prevents it firing every frame.
  if held("q") and ready("Arcane Burst") {
    startCooldown("Arcane Burst", 900)
    magic3d PLAYER_X, PLAYER_Y + 70, PLAYER_Z, 260, "#61d8ff", 500
    damageArea(PLAYER_X, PLAYER_Z, 320, 24)
  }

  // F: drink a potion while it is selected in the backpack.
  if held("f") and holding() == "Health Potion" {
    if takeOne("Health Potion") {
      healPlayer(35)
    }
  }

  // The crystal is a simple collectible objective.
  if not crystalTaken and playerNear(0, 300, 90) {
    crystalTaken = true
    burst3d 0, 130, 300, "#61d8ff", 55, 240
    saveRpgProgress()
  }

  if not alive(goblin) and not goblinRewarded {
    goblinRewarded = true
    advanceQuest("training_trial", 1)
    rollLoot("training_goblin")
    addXP(25)
    if questCompleted("training_trial") { claimQuest("training_trial") }
    saveRpgProgress()
  }

  if alive(goblin) == false and crystalTaken {
    victory = true
  }

  render3d
  drawCombat()
  write "Training Grounds" at 160, 8 centered shadow
  if victory {
    write "Trial complete! You defeated the goblin and found the crystal." at 160, 166 centered shadow
  } else {
    write "WASD move · Shift run · Space jump · Q magic · F potion" at 160, 166 centered shadow
  }
}
