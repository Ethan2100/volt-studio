// =====================================================================
// RPG Kit for Volt Studio
// Requires game-kit and combat-kit:
//   import "game.volt"
//   import "combat.volt"
//   import "rpg.volt"
//
// Units: centimetres, y is up. Call rpgStepEnemies() every frame.
// =====================================================================

// -------------------- Default 3D iron sword --------------------
let RPG_SWORD_GRIP = -1
let RPG_SWORD_GUARD = -1
let RPG_SWORD_BLADE = -1
let RPG_SWORD_TIP = -1
let RPG_SWORD_COOLDOWN = 0
let RPG_SWORD_DAMAGE = 24
let RPG_SWORD_REACH = 250

fn rpgCreateIronSword() {
  RPG_SWORD_GRIP = cyl3d(0, -500, 0, 7, 78, "#573a29")
  RPG_SWORD_GUARD = block3d(0, -500, 0, 52, 9, 13, "#b88a45")
  RPG_SWORD_BLADE = block3d(0, -500, 0, 15, 112, 8, "#d9e5f5")
  RPG_SWORD_TIP = ball3d(0, -500, 0, 8, "#eef5ff")
  glow3d RPG_SWORD_BLADE, "#8aa8ce"
}

fn rpgEquipSword() {
  if RPG_SWORD_GRIP < 0 {
    rpgCreateIronSword()
  }
}

fn rpgSwordStep() {
  if RPG_SWORD_GRIP < 0 {
    return
  }
  if RPG_SWORD_COOLDOWN > 0 {
    RPG_SWORD_COOLDOWN -= 16
  }
  let handX = PLAYER_X + sin3(PLAYER_YAW) * 34 / 1000
  let handZ = PLAYER_Z - cos3(PLAYER_YAW) * 34 / 1000
  let swing = 0
  if RPG_SWORD_COOLDOWN > 650 {
    swing = sin3((900 - RPG_SWORD_COOLDOWN) * 5) * 360 / 1000
  }
  move3d RPG_SWORD_GRIP, handX, PLAYER_Y + 78, handZ
  move3d RPG_SWORD_GUARD, handX, PLAYER_Y + 118, handZ
  move3d RPG_SWORD_BLADE, handX, PLAYER_Y + 180, handZ
  move3d RPG_SWORD_TIP, handX, PLAYER_Y + 238, handZ
  turn3d RPG_SWORD_GRIP, PLAYER_YAW + swing
  turn3d RPG_SWORD_GUARD, PLAYER_YAW + swing
  turn3d RPG_SWORD_BLADE, PLAYER_YAW + swing
  turn3d RPG_SWORD_TIP, PLAYER_YAW + swing
}

fn rpgSwordAttack() {
  if RPG_SWORD_COOLDOWN > 0 {
    return
  }
  RPG_SWORD_COOLDOWN = 850
  let fx = sin3(PLAYER_YAW)
  let fz = 0 - cos3(PLAYER_YAW)
  let hitX = PLAYER_X + fx * RPG_SWORD_REACH / 1000
  let hitZ = PLAYER_Z + fz * RPG_SWORD_REACH / 1000
  let hit = damageArea(hitX, hitZ, 150, RPG_SWORD_DAMAGE)
  burst3d hitX, PLAYER_Y + 105, hitZ, "#dceaff", 18, 180
  tone 420 to 170 for 110ms
}

// -------------------- Basic enemy NPCs --------------------
// NPC meshes are deliberately procedural, so the kit works offline
// without a model download. Replace the body/head with GLB models later.
let RPG_NPC_BODY = []
let RPG_NPC_HEAD = []
let RPG_NPC_EYE_A = []
let RPG_NPC_EYE_B = []
let RPG_NPC_ARM_L = []
let RPG_NPC_ARM_R = []
let RPG_NPC_LEG_L = []
let RPG_NPC_LEG_R = []
let RPG_NPC_WALK = []
let RPG_NPC_TARGET = []
let RPG_NPC_SPEED = []
let RPG_NPC_DAMAGE = []
let RPG_NPC_AGGRO = []
let RPG_NPC_ATTACK_RANGE = []
let RPG_NPC_ATTACK_WAIT = []
let RPG_NPC_HOME_X = []
let RPG_NPC_HOME_Z = []
let RPG_NPC_PATROL = []
let RPG_NPC_COUNT = 0

fn rpgSpawnEnemy(name, x, z, hp, damage, speed, aggro, attackRange, color) {
  let body = block3d(x, 72, z, 58, 144, 48, color)
  let head = ball3d(x, 174, z, 34, "#b9a0a0")
  let eyeA = ball3d(x - 12, 180, z - 29, 5, "#ff536f")
  let eyeB = ball3d(x + 12, 180, z - 29, 5, "#ff536f")
  let armL = block3d(x - 39, 75, z, 18, 92, 22, color)
  let armR = block3d(x + 39, 75, z, 18, 92, 22, color)
  let legL = block3d(x - 17, 15, z, 22, 55, 26, "#292536")
  let legR = block3d(x + 17, 15, z, 22, 55, 26, "#292536")
  let targetId = target(name, x, 72, z, hp, 105)
  add body to RPG_NPC_BODY
  add head to RPG_NPC_HEAD
  add eyeA to RPG_NPC_EYE_A
  add eyeB to RPG_NPC_EYE_B
  add armL to RPG_NPC_ARM_L
  add armR to RPG_NPC_ARM_R
  add legL to RPG_NPC_LEG_L
  add legR to RPG_NPC_LEG_R
  add 0 to RPG_NPC_WALK
  add targetId to RPG_NPC_TARGET
  add speed to RPG_NPC_SPEED
  add damage to RPG_NPC_DAMAGE
  add aggro to RPG_NPC_AGGRO
  add attackRange to RPG_NPC_ATTACK_RANGE
  add 0 to RPG_NPC_ATTACK_WAIT
  add x to RPG_NPC_HOME_X
  add z to RPG_NPC_HOME_Z
  add 0 to RPG_NPC_PATROL
  RPG_NPC_COUNT += 1
  return RPG_NPC_COUNT - 1
}

fn rpgStepEnemies() {
  let i = 0
  while i < RPG_NPC_COUNT {
    let targetId = RPG_NPC_TARGET[i]
    if alive(targetId) {
      let ex = TARGET_X[targetId]
      let ez = TARGET_Z[targetId]
      let dx = PLAYER_X - ex
      let dz = PLAYER_Z - ez
      let d = dist(PLAYER_X, PLAYER_Z, ex, ez)
      if RPG_NPC_ATTACK_WAIT[i] > 0 {
        RPG_NPC_ATTACK_WAIT[i] -= 16
      }
      if d <= RPG_NPC_AGGRO[i] and d > RPG_NPC_ATTACK_RANGE[i] {
        let step = RPG_NPC_SPEED[i] / 60
        let nx = ex + dx * step / max(1, d)
        let nz = ez + dz * step / max(1, d)
        move3d RPG_NPC_BODY[i], nx, 72, nz
        move3d RPG_NPC_HEAD[i], nx, 174, nz
        move3d RPG_NPC_EYE_A[i], nx - 12, 180, nz - 29
        move3d RPG_NPC_EYE_B[i], nx + 12, 180, nz - 29
        RPG_NPC_WALK[i] += 260
        let stride = sin3(RPG_NPC_WALK[i]) * 17 / 1000
        move3d RPG_NPC_ARM_L[i], nx - 39, 75 + stride, nz
        move3d RPG_NPC_ARM_R[i], nx + 39, 75 - stride, nz
        move3d RPG_NPC_LEG_L[i], nx - 17, 15 - stride, nz
        move3d RPG_NPC_LEG_R[i], nx + 17, 15 + stride, nz
        moveTarget(targetId, nx, 72, nz)
        turn3d RPG_NPC_BODY[i], atan2(dx, 0 - dz)
        turn3d RPG_NPC_HEAD[i], atan2(dx, 0 - dz)
        turn3d RPG_NPC_ARM_L[i], atan2(dx, 0 - dz)
        turn3d RPG_NPC_ARM_R[i], atan2(dx, 0 - dz)
        turn3d RPG_NPC_LEG_L[i], atan2(dx, 0 - dz)
        turn3d RPG_NPC_LEG_R[i], atan2(dx, 0 - dz)
      }
      if d <= RPG_NPC_ATTACK_RANGE[i] and RPG_NPC_ATTACK_WAIT[i] <= 0 {
        hurtPlayer(RPG_NPC_DAMAGE[i])
        RPG_NPC_ATTACK_WAIT[i] = 1100
        burst3d PLAYER_X, PLAYER_Y + 80, PLAYER_Z, "#d94b55", 12, 140
        tone 130 to 70 for 120ms
      }
    } else {
      show3d RPG_NPC_BODY[i], false
      show3d RPG_NPC_HEAD[i], false
      show3d RPG_NPC_EYE_A[i], false
      show3d RPG_NPC_EYE_B[i], false
      show3d RPG_NPC_ARM_L[i], false
      show3d RPG_NPC_ARM_R[i], false
      show3d RPG_NPC_LEG_L[i], false
      show3d RPG_NPC_LEG_R[i], false
    }
    i += 1
  }
}
