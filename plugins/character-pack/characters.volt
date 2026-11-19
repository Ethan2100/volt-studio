// =====================================================================
// Character pack - the rigged people and animals that come with Volt
// Studio, plus the small amount of code every one of them needs: face
// the way you're walking, and play the animation that matches what
// you're doing.
//
// The models live in this plugin folder, so `model3d` finds them from
// any .volt file without copying anything:
//
//   #html
//   import "characters.volt"
//   model3d hunter = "hunter.glb"
//
//   let guard = put3d(hunter, 0, 0, -400, 0, 100)
//   let g = actor(guard, 0, -400, 0)
//
//   every frame {
//     actorWalkTo(g, PLAYER_X, PLAYER_Z, 300)   // walks over, turning as it goes
//     actorStep(g)
//     render3d
//   }
//
// The people: coworker_cyan, coworker_gold, coworker_red, hunter,
// raider, raider2, ninja - Kenney's blocky characters, recoloured. All of
// them have the same 27 animations:
//
//   static, idle, walk, sprint, sit, drive, die, pick-up,
//   emote-yes, emote-no, holding-right, holding-left, holding-both,
//   holding-right-shoot, holding-left-shoot, holding-both-shoot,
//   attack-melee-right, attack-melee-left, attack-kick-right,
//   attack-kick-left, interact-right, interact-left,
//   wheelchair-sit, wheelchair-move-forward, wheelchair-move-back,
//   wheelchair-move-left, wheelchair-move-right
//
// The animals (wolf, bear, deer) are box models without animations - move
// and turn them like anything else.
//
// Characters by Kenney (CC0 - public domain). Drop any other .glb into
// this folder to use it the same way; see README.md.
// =====================================================================

// One list per field: an actor is a model you've already put in the
// world, plus where it is, where it's going, and what it's playing.
let ACTOR_ID = []
let ACTOR_X = []
let ACTOR_Z = []
let ACTOR_YAW = []
let ACTOR_TX = []        // where it's heading
let ACTOR_TZ = []
let ACTOR_SPEED = []     // cm a second, 0 = standing still
let ACTOR_ANIM = []      // what's playing now, so we only change it when it changes
let ACTOR_WALK = 260     // under this speed it walks, over it sprints
let ACTOR_TURN = 90      // how fast it turns to face where it's going, degrees a second

// Takes a model you have already placed with put3d and starts looking
// after it. Gives back its actor number.
fn actor(model, x, z, yaw) {
  add model to ACTOR_ID
  add x to ACTOR_X
  add z to ACTOR_Z
  add yaw to ACTOR_YAW
  add x to ACTOR_TX
  add z to ACTOR_TZ
  add 0 to ACTOR_SPEED
  add "" to ACTOR_ANIM
  return length(ACTOR_ID) - 1
}

// Sends it somewhere. Call it as often as you like - a chasing enemy
// just passes the player's position every frame.
fn actorWalkTo(i, x, z, speed) {
  ACTOR_TX[i] = x
  ACTOR_TZ[i] = z
  ACTOR_SPEED[i] = speed
}

fn actorStop(i) {
  ACTOR_SPEED[i] = 0
  ACTOR_TX[i] = ACTOR_X[i]
  ACTOR_TZ[i] = ACTOR_Z[i]
}

// Plays an animation, but only tells the model when it actually
// changes - restarting "walk" every frame would freeze it on frame one.
fn actorPlay(i, name) {
  if ACTOR_ANIM[i] != name {
    ACTOR_ANIM[i] = name
    anim3d ACTOR_ID[i], name
  }
}

// Turns it towards an angle a little at a time, the short way round.
fn actorFace(i, yaw) {
  let gap = yaw - ACTOR_YAW[i]
  if gap > 1800 {
    gap -= 3600
  }
  if gap < 0 - 1800 {
    gap += 3600
  }
  let most = ACTOR_TURN * 10 / 60.0
  if gap > most {
    gap = most
  }
  if gap < 0 - most {
    gap = 0 - most
  }
  ACTOR_YAW[i] = ACTOR_YAW[i] + gap
  if ACTOR_YAW[i] < 0 {
    ACTOR_YAW[i] += 3600
  }
  if ACTOR_YAW[i] > 3600 {
    ACTOR_YAW[i] -= 3600
  }
}

// One frame for one actor: step towards where it's going, turn to face
// that way, play idle / walk / sprint to match, and move the model.
fn actorStep(i) {
  let dx = ACTOR_TX[i] - ACTOR_X[i]
  let dz = ACTOR_TZ[i] - ACTOR_Z[i]
  let away = dist(ACTOR_X[i], ACTOR_Z[i], ACTOR_TX[i], ACTOR_TZ[i])
  if ACTOR_SPEED[i] > 0 and away > 20 {
    actorFace(i, atan2(dx, 0 - dz))
    let hop = ACTOR_SPEED[i] / 60.0
    if hop > away {
      hop = away
    }
    ACTOR_X[i] = ACTOR_X[i] + dx * hop / away
    ACTOR_Z[i] = ACTOR_Z[i] + dz * hop / away
    if ACTOR_SPEED[i] > ACTOR_WALK {
      actorPlay(i, "sprint")
    } else {
      actorPlay(i, "walk")
    }
  } else {
    actorPlay(i, "idle")
  }
  move3d ACTOR_ID[i], ACTOR_X[i], 0, ACTOR_Z[i]
  turn3d ACTOR_ID[i], ACTOR_YAW[i]
}

// Everyone, in one line - call this instead of actorStep in a loop.
fn actorsStep() {
  let i = 0
  while i < length(ACTOR_ID) {
    actorStep(i)
    i += 1
  }
}

// How far an actor is from a point - for "has it reached me yet".
fn actorNear(i, x, z, howClose) {
  if dist(ACTOR_X[i], ACTOR_Z[i], x, z) < howClose {
    return true
  }
  return false
}
