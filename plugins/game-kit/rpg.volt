// =====================================================================
// Volt RPG systems - reusable runtime systems for quests, progression,
// enemy behaviour, loot, timed status effects, checkpoints and triggers.
//
// Import after combat.volt:
//   import "game.volt"
//   import "combat.volt"
//   import "rpg.volt"
//
// Call stepRpg() once per frame. The other functions are event-driven.
// All distances use centimetres and all durations use milliseconds.
// =====================================================================

// ---- quests and rewards ------------------------------------------------
let QUEST_ID = []
let QUEST_NAME = []
let QUEST_GOAL = []
let QUEST_PROGRESS = []
let QUEST_REWARD_XP = []
let QUEST_REWARD_ITEM = []
let QUEST_REWARD_COUNT = []
let QUEST_STATE = []       // 0 inactive, 1 active, 2 complete

fn questIndex(recordId) {
  let i = 0
  while i < length(QUEST_ID) {
    if QUEST_ID[i] == recordId { return i }
    i += 1
  }
  return -1
}

fn createQuest(recordId, name, goal, rewardXp, rewardItem, rewardCount) {
  let at = questIndex(recordId)
  if at >= 0 { return at }
  add recordId to QUEST_ID
  add name to QUEST_NAME
  add max(1, goal) to QUEST_GOAL
  add 0 to QUEST_PROGRESS
  add max(0, rewardXp) to QUEST_REWARD_XP
  add rewardItem to QUEST_REWARD_ITEM
  add max(0, rewardCount) to QUEST_REWARD_COUNT
  add 0 to QUEST_STATE
  return length(QUEST_ID) - 1
}

fn startQuest(recordId) {
  let i = questIndex(recordId)
  if i < 0 or QUEST_STATE[i] != 0 { return false }
  QUEST_STATE[i] = 1
  return true
}

fn advanceQuest(recordId, amount) {
  let i = questIndex(recordId)
  if i < 0 or QUEST_STATE[i] != 1 { return false }
  QUEST_PROGRESS[i] = min(QUEST_GOAL[i], QUEST_PROGRESS[i] + max(0, amount))
  RPG_DIRTY = true
  if QUEST_PROGRESS[i] >= QUEST_GOAL[i] { QUEST_STATE[i] = 2 }
  return QUEST_STATE[i] == 2
}

fn questCompleted(recordId) {
  let i = questIndex(recordId)
  return i >= 0 and QUEST_STATE[i] == 2
}

fn claimQuest(recordId) {
  let i = questIndex(recordId)
  if i < 0 or QUEST_STATE[i] != 2 { return false }
  QUEST_STATE[i] = 3
  RPG_DIRTY = true
  addXP(QUEST_REWARD_XP[i])
  if QUEST_REWARD_COUNT[i] > 0 and QUEST_REWARD_ITEM[i] != "" {
    give(QUEST_REWARD_ITEM[i], QUEST_REWARD_COUNT[i], "#d9bd70")
  }
  return true
}

// ---- player progression and skill unlocks ------------------------------
let PLAYER_XP = 0
let RPG_DIRTY = false
let PLAYER_LEVEL = 1
let XP_NEXT_LEVEL = 100
let SKILL_ID = []
let SKILL_LEVEL = []
let SKILL_COST = []
let SKILL_PREREQ = []
let SKILL_UNLOCKED = []

fn skillIndex(recordId) {
  let i = 0
  while i < length(SKILL_ID) {
    if SKILL_ID[i] == recordId { return i }
    i += 1
  }
  return -1
}

fn defineSkill(recordId, requiredLevel, xpCost, prerequisite) {
  let at = skillIndex(recordId)
  if at >= 0 { return at }
  add recordId to SKILL_ID
  add max(1, requiredLevel) to SKILL_LEVEL
  add max(0, xpCost) to SKILL_COST
  add prerequisite to SKILL_PREREQ
  add false to SKILL_UNLOCKED
  return length(SKILL_ID) - 1
}

fn addXP(amount) {
  PLAYER_XP += max(0, amount)
  RPG_DIRTY = true
  while PLAYER_XP >= XP_NEXT_LEVEL {
    PLAYER_XP -= XP_NEXT_LEVEL
    PLAYER_LEVEL += 1
    XP_NEXT_LEVEL = 100 + (PLAYER_LEVEL - 1) * 50
  }
}

fn skillUnlocked(recordId) {
  let i = skillIndex(recordId)
  return i >= 0 and SKILL_UNLOCKED[i]
}

fn unlockSkill(recordId) {
  let i = skillIndex(recordId)
  if i < 0 or SKILL_UNLOCKED[i] { return false }
  if PLAYER_LEVEL < SKILL_LEVEL[i] or PLAYER_XP < SKILL_COST[i] { return false }
  if SKILL_PREREQ[i] != "" and not skillUnlocked(SKILL_PREREQ[i]) { return false }
  PLAYER_XP -= SKILL_COST[i]
  SKILL_UNLOCKED[i] = true
  RPG_DIRTY = true
  return true
}

// ---- enemy behaviour ---------------------------------------------------
let AI_TARGET = []
let AI_VISUAL = []
let AI_AGGRO = []
let AI_ATTACK_RANGE = []
let AI_DAMAGE = []
let AI_SPEED = []
let AI_COOLDOWN = []
let AI_WAIT = []
let AI_MODE = []            // "guard", "chase", "aggressive"

fn configureEnemyAI(targetId, visual, aggro, attackRange, damage, speed, cooldown, mode) {
  let i = 0
  while i < length(AI_TARGET) {
    if AI_TARGET[i] == targetId {
      AI_VISUAL[i] = visual
      AI_AGGRO[i] = aggro
      AI_ATTACK_RANGE[i] = attackRange
      AI_DAMAGE[i] = damage
      AI_SPEED[i] = speed
      AI_COOLDOWN[i] = cooldown
      AI_MODE[i] = mode
      return i
    }
    i += 1
  }
  add targetId to AI_TARGET
  add visual to AI_VISUAL
  add aggro to AI_AGGRO
  add attackRange to AI_ATTACK_RANGE
  add damage to AI_DAMAGE
  add speed to AI_SPEED
  add cooldown to AI_COOLDOWN
  add 0 to AI_WAIT
  add mode to AI_MODE
  return length(AI_TARGET) - 1
}

// Call once per frame for each configured enemy. The target's registered
// position is moved toward the player; nearby enemies attack on cooldown.
fn stepEnemyAI(targetId, playerX, playerZ) {
  let i = 0
  while i < length(AI_TARGET) {
    if AI_TARGET[i] == targetId {
      if not alive(targetId) { return "dead" }
      let dx = playerX - TARGET_X[targetId]
      let dz = playerZ - TARGET_Z[targetId]
      let distance = dist(playerX, playerZ, TARGET_X[targetId], TARGET_Z[targetId])
      if AI_MODE[i] == "guard" and distance > AI_AGGRO[i] { return "guard" }
      if distance > AI_AGGRO[i] { return "idle" }
      if distance > AI_ATTACK_RANGE[i] {
        let travel = min(AI_SPEED[i] / 60, distance)
        if distance > 0 {
          let nx = TARGET_X[targetId] + dx * travel / distance
          let nz = TARGET_Z[targetId] + dz * travel / distance
          moveTarget(targetId, nx, TARGET_Y[targetId], nz)
          move3d AI_VISUAL[i], nx, TARGET_Y[targetId], nz
        }
        return "chase"
      }
      if AI_WAIT[i] <= 0 {
        hurtPlayer(AI_DAMAGE[i])
        AI_WAIT[i] = AI_COOLDOWN[i]
      }
      return "attack"
    }
    i += 1
  }
  return "unconfigured"
}

// ---- loot tables -------------------------------------------------------
let LOOT_TABLE = []
let LOOT_ITEM = []
let LOOT_CHANCE = []
let LOOT_MIN = []
let LOOT_MAX = []
let LOOT_COLOR = []

fn addLoot(tableId, itemName, chancePercent, minCount, maxCount, color) {
  add tableId to LOOT_TABLE
  add itemName to LOOT_ITEM
  add constrain(chancePercent, 0, 100) to LOOT_CHANCE
  add max(1, minCount) to LOOT_MIN
  add max(max(1, minCount), maxCount) to LOOT_MAX
  add color to LOOT_COLOR
}

fn rollLoot(tableId) {
  let dropped = 0
  let i = 0
  while i < length(LOOT_TABLE) {
    if LOOT_TABLE[i] == tableId and random(0, 100) < LOOT_CHANCE[i] {
      let amount = LOOT_MIN[i]
      if LOOT_MAX[i] > LOOT_MIN[i] {
        amount = random(LOOT_MIN[i], LOOT_MAX[i])
      }
      if give(LOOT_ITEM[i], amount, LOOT_COLOR[i]) { dropped += amount }
    }
    i += 1
  }
  return dropped
}

// ---- timed status effects ----------------------------------------------
let STATUS_NAME = []
let STATUS_STAT = []
let STATUS_AMOUNT = []
let STATUS_LEFT = []
let STATUS_DEF_ID = []
let STATUS_DEF_STAT = []
let STATUS_DEF_AMOUNT = []
let STATUS_DEF_DURATION = []

fn defineStatus(recordId, stat, amount, durationMs) {
  let i = 0
  while i < length(STATUS_DEF_ID) {
    if STATUS_DEF_ID[i] == recordId {
      STATUS_DEF_STAT[i] = stat
      STATUS_DEF_AMOUNT[i] = amount
      STATUS_DEF_DURATION[i] = durationMs
      return true
    }
    i += 1
  }
  add recordId to STATUS_DEF_ID
  add stat to STATUS_DEF_STAT
  add amount to STATUS_DEF_AMOUNT
  add durationMs to STATUS_DEF_DURATION
  return true
}

fn applyDefinedStatus(recordId) {
  let i = 0
  while i < length(STATUS_DEF_ID) {
    if STATUS_DEF_ID[i] == recordId {
      return applyStatus(recordId, STATUS_DEF_STAT[i], STATUS_DEF_AMOUNT[i], STATUS_DEF_DURATION[i])
    }
    i += 1
  }
  return false
}

fn applyStatus(recordId, stat, amount, durationMs) {
  let i = 0
  while i < length(STATUS_NAME) {
    if STATUS_NAME[i] == recordId {
      STATUS_STAT[i] = stat
      STATUS_AMOUNT[i] = amount
      STATUS_LEFT[i] = max(1, durationMs)
      recalcStatuses()
      return true
    }
    i += 1
  }
  add recordId to STATUS_NAME
  add stat to STATUS_STAT
  add amount to STATUS_AMOUNT
  add max(1, durationMs) to STATUS_LEFT
  recalcStatuses()
  return true
}

fn recalcStatuses() {
  PLAYER_STATUS_ATTACK_BONUS = 0
  PLAYER_STATUS_DEFENCE_BONUS = 0
  let i = 0
  while i < length(STATUS_NAME) {
    if STATUS_STAT[i] == "attack" { PLAYER_STATUS_ATTACK_BONUS += STATUS_AMOUNT[i] }
    if STATUS_STAT[i] == "defence" { PLAYER_STATUS_DEFENCE_BONUS += STATUS_AMOUNT[i] }
    i += 1
  }
}

fn removeStatus(recordId) {
  let i = 0
  while i < length(STATUS_NAME) {
    if STATUS_NAME[i] == recordId {
      remove STATUS_NAME[i]
      remove STATUS_STAT[i]
      remove STATUS_AMOUNT[i]
      remove STATUS_LEFT[i]
      recalcStatuses()
      return true
    }
    i += 1
  }
  return false
}

fn hasStatus(recordId) {
  let i = 0
  while i < length(STATUS_NAME) {
    if STATUS_NAME[i] == recordId { return true }
    i += 1
  }
  return false
}

// ---- checkpoints and persistent player progress ------------------------
let CHECKPOINT_X = 0
let CHECKPOINT_Y = 0
let CHECKPOINT_Z = 0
let CHECKPOINT_SET = false

fn setCheckpoint(x, y, z) {
  CHECKPOINT_X = x
  CHECKPOINT_Y = y
  CHECKPOINT_Z = z
  CHECKPOINT_SET = true
  save "checkpoint", [x, y, z]
}

fn restoreCheckpoint() {
  let point = saved("checkpoint", [])
  if length(point) < 3 { return false }
  CHECKPOINT_X = point[0]
  CHECKPOINT_Y = point[1]
  CHECKPOINT_Z = point[2]
  CHECKPOINT_SET = true
  PLAYER_X = CHECKPOINT_X
  PLAYER_Y = CHECKPOINT_Y
  PLAYER_Z = CHECKPOINT_Z
  return true
}

fn saveRpgProgress() {
  save "rpg_xp", PLAYER_XP
  save "rpg_level", PLAYER_LEVEL
  save "rpg_skills", SKILL_UNLOCKED
  save "rpg_quest_progress", QUEST_PROGRESS
  save "rpg_quest_state", QUEST_STATE
}

fn loadRpgProgress() {
  PLAYER_XP = saved("rpg_xp", 0)
  PLAYER_LEVEL = saved("rpg_level", 1)
  SKILL_UNLOCKED = saved("rpg_skills", SKILL_UNLOCKED)
  QUEST_PROGRESS = saved("rpg_quest_progress", QUEST_PROGRESS)
  QUEST_STATE = saved("rpg_quest_state", QUEST_STATE)
  let i = 0
  while i < length(SKILL_ID) {
    if i >= length(SKILL_UNLOCKED) { add false to SKILL_UNLOCKED }
    i += 1
  }
}

// ---- interaction triggers ----------------------------------------------
let TRIGGER_ID = []
let TRIGGER_X = []
let TRIGGER_Z = []
let TRIGGER_RADIUS = []
let TRIGGER_ACTION = []
let TRIGGER_PAYLOAD = []
let TRIGGER_ONCE = []
let TRIGGER_FIRED = []
let TRIGGER_INSIDE = []

fn addTrigger(recordId, x, z, radius, action, payload, once) {
  add recordId to TRIGGER_ID
  add x to TRIGGER_X
  add z to TRIGGER_Z
  add radius to TRIGGER_RADIUS
  add action to TRIGGER_ACTION
  add payload to TRIGGER_PAYLOAD
  add once to TRIGGER_ONCE
  add false to TRIGGER_FIRED
  add false to TRIGGER_INSIDE
}

fn stepTriggers(playerX, playerZ) {
  let i = 0
  while i < length(TRIGGER_ID) {
    let inside = dist(playerX, playerZ, TRIGGER_X[i], TRIGGER_Z[i]) <= TRIGGER_RADIUS[i]
    if inside and not TRIGGER_INSIDE[i] and (not TRIGGER_FIRED[i] or not TRIGGER_ONCE[i]) {
        TRIGGER_INSIDE[i] = true
        let action = TRIGGER_ACTION[i]
        if action == "quest" { startQuest(TRIGGER_PAYLOAD[i]) }
        if action == "advanceQuest" { advanceQuest(TRIGGER_PAYLOAD[i], 1) }
        if action == "heal" { healPlayer(number(TRIGGER_PAYLOAD[i])) }
        if action == "xp" { addXP(int(TRIGGER_PAYLOAD[i])) }
        if action == "checkpoint" { setCheckpoint(playerX, PLAYER_Y, playerZ) }
        if action == "statusAttack" { applyStatus(TRIGGER_ID[i], "attack", int(TRIGGER_PAYLOAD[i]), 5000) }
        if action == "statusDefence" { applyStatus(TRIGGER_ID[i], "defence", int(TRIGGER_PAYLOAD[i]), 5000) }
        if action == "status" { applyDefinedStatus(TRIGGER_PAYLOAD[i]) }
        if TRIGGER_ONCE[i] { TRIGGER_FIRED[i] = true }
    }
    if not inside { TRIGGER_INSIDE[i] = false }
    i += 1
  }
}

// Call once per frame to tick timed systems.
fn stepRpg() {
  let i = 0
  while i < length(STATUS_LEFT) {
    STATUS_LEFT[i] -= 16
    if STATUS_LEFT[i] <= 0 {
      remove STATUS_NAME[i]
      remove STATUS_STAT[i]
      remove STATUS_AMOUNT[i]
      remove STATUS_LEFT[i]
    } else { i += 1 }
  }
  recalcStatuses()
  if RPG_DIRTY {
    saveRpgProgress()
    RPG_DIRTY = false
  }
  i = 0
  while i < length(AI_WAIT) {
    if AI_WAIT[i] > 0 { AI_WAIT[i] -= 16 }
    i += 1
  }
}
