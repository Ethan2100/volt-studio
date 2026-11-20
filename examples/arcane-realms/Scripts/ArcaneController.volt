let heroHealth = 100
let heroMana = 100
let wardenHealth = 100
let wardenActor = 0
let arcaneCooldown = 0
let hurtCooldown = 0
let weaponMode = 1

fn arcaneSetup() {
  wardenActor = actor(Warden, 0, -920, 0)
  actorPlay(wardenActor, "idle")
  arcaneCooldown = 0
  hurtCooldown = 0
}

fn arcaneStep() {
  if arcaneCooldown > 0 { arcaneCooldown -= 1 }
  if hurtCooldown > 0 { hurtCooldown -= 1 }
  move3d Hero, PLAYER_X, PLAYER_Y, PLAYER_Z
  turn3d Hero, PLAYER_YAW
  camera3d PLAYER_X - sin3(PLAYER_YAW) * 470 / 1000, PLAYER_Y + 260, PLAYER_Z + cos3(PLAYER_YAW) * 470 / 1000, PLAYER_YAW, -100

  let handX = PLAYER_X + cos3(PLAYER_YAW) * 42 / 1000
  let handZ = PLAYER_Z + sin3(PLAYER_YAW) * 42 / 1000
  move3d SwordGrip, handX, PLAYER_Y + 82, handZ
  move3d SwordBlade, handX + sin3(PLAYER_YAW) * 42 / 1000, PLAYER_Y + 178, handZ - cos3(PLAYER_YAW) * 42 / 1000
  move3d StaffShaft, handX - 25, PLAYER_Y + 92, handZ + 20
  move3d StaffOrb, handX - 25, PLAYER_Y + 180, handZ + 20
  if held("1") { weaponMode = 1 }
  if held("2") { weaponMode = 2 }
  if weaponMode == 1 {
    show3d SwordGrip, 1
    show3d SwordBlade, 1
    show3d StaffShaft, 0
    show3d StaffOrb, 0
  } else {
    show3d SwordGrip, 0
    show3d SwordBlade, 0
    show3d StaffShaft, 1
    show3d StaffOrb, 1
  }

  if wardenHealth > 0 {
    actorWalkTo(wardenActor, PLAYER_X, PLAYER_Z, 190)
    if actorNear(wardenActor, PLAYER_X, PLAYER_Z, 105) and hurtCooldown == 0 {
      heroHealth -= 8
      hurtCooldown = 45
      burst3d PLAYER_X, PLAYER_Y + 80, PLAYER_Z, "#ff526f", 14, 180
      if heroHealth < 0 { heroHealth = 0 }
    }
  } else { actorStop(wardenActor) }
  actorsStep()
  if wardenHealth <= 0 { actorPlay(wardenActor, "die") }

  if held("q") and arcaneCooldown == 0 {
    if weaponMode == 1 {
      slash3d PLAYER_X + sin3(PLAYER_YAW) * 130 / 1000, PLAYER_Y + 115, PLAYER_Z - cos3(PLAYER_YAW) * 130 / 1000, PLAYER_YAW, 260, "#dff5ff"
      burst3d PLAYER_X, PLAYER_Y + 100, PLAYER_Z, "#94e7ff", 16, 260
      if wardenHealth > 0 and actorNear(wardenActor, PLAYER_X, PLAYER_Z, 330) { wardenHealth -= 24 }
    } else {
      magic3d PLAYER_X, PLAYER_Y + 90, PLAYER_Z, 210, "#b16cff", 700
      if wardenHealth > 0 and actorNear(wardenActor, PLAYER_X, PLAYER_Z, 520) { wardenHealth -= 15 }
    }
    arcaneCooldown = 25
  }
  if held("e") and arcaneCooldown == 0 and heroMana >= 22 {
    let tx = PLAYER_X + sin3(PLAYER_YAW) * 900 / 1000
    let tz = PLAYER_Z - cos3(PLAYER_YAW) * 900 / 1000
    beam3d PLAYER_X, PLAYER_Y + 140, PLAYER_Z, tx, PLAYER_Y + 140, tz, 28, "#79dfff"
    burst3d tx, PLAYER_Y + 140, tz, "#b7f5ff", 26, 340
    if wardenHealth > 0 and actorNear(wardenActor, tx, tz, 420) { wardenHealth -= 30 }
    heroMana -= 22
    arcaneCooldown = 42
  }
  if held("r") and arcaneCooldown == 0 and heroMana >= 34 {
    magic3d PLAYER_X, PLAYER_Y, PLAYER_Z, 420, "#a95fff", 1500
    shock3d PLAYER_X, PLAYER_Y + 8, PLAYER_Z, 620, "#63dfff"
    burst3d PLAYER_X, PLAYER_Y + 30, PLAYER_Z, "#d2a3ff", 38, 420
    if wardenHealth > 0 and actorNear(wardenActor, PLAYER_X, PLAYER_Z, 610) { wardenHealth -= 38 }
    heroMana -= 34
    arcaneCooldown = 70
  }
  if heroMana < 100 { heroMana += 1 }
  if wardenHealth < 0 { wardenHealth = 0 }
}
