// =====================================================================
// POLYGLOT - engine/achievements.volt
// Achievements and the weekly challenge. Both are computed from the
// stored progress data, so they can never drift out of sync with it.
//
// Counters and flags written elsewhere:
//   les:<day>  lessons finished that day     rev:<day>  words reviewed that day
//   flag:<name>  one-off facts (perfect, spoke, convo, challenge15)
// =====================================================================

let achIds = ["first", "five", "streak3", "streak7", "streak30", "xp100", "xp500", "xp2000", "words25", "words100", "perfect", "poly2", "poly3", "spoke", "convo", "quick", "rev50"]
let achNames = ["First steps", "Five down", "On a roll", "Week warrior", "Unstoppable", "Getting going", "Dedicated", "Devoted", "Word collector", "Walking dictionary", "Flawless", "Polyglot day", "Triple threat", "Out loud", "Small talk", "Quick thinker", "Memory keeper"]
let achDescs = ["Finish your first lesson.", "Finish 5 lessons.", "Study 3 days in a row.", "Study 7 days in a row.", "Study 30 days in a row.", "Earn 100 XP.", "Earn 500 XP.", "Earn 2,000 XP.", "Learn 25 words (box 3 or higher).", "Learn 100 words.", "Finish a lesson with 100%.", "Earn XP in 2 languages on the same day.", "Earn XP in 3 languages on the same day.", "Complete a pronunciation exercise.", "Finish a conversation simulation.", "Score 15 or more in a vocabulary challenge.", "Review 50 words."]

fn totalLessonsDone() {
  let n = 0
  for each code in langCodes {
    n += lessonsDone(code)
  }
  return n
}

fn totalLearned() {
  let n = 0
  for each code in langCodes {
    n += learnedCount(code)
  }
  return n
}

fn languagesToday() {
  let n = 0
  for each code in langCodes {
    if xpOnDay(code, dayNum()) > 0 {
      n += 1
    }
  }
  return n
}

fn totalReviews() {
  return kvNum("cnt:reviews", 0)
}

fn achMet(aid) {
  if aid == "first" {
    return totalLessonsDone() >= 1
  }
  if aid == "five" {
    return totalLessonsDone() >= 5
  }
  if aid == "streak3" {
    return streakDays() >= 3
  }
  if aid == "streak7" {
    return streakDays() >= 7
  }
  if aid == "streak30" {
    return streakDays() >= 30
  }
  if aid == "xp100" {
    return totalXp() >= 100
  }
  if aid == "xp500" {
    return totalXp() >= 500
  }
  if aid == "xp2000" {
    return totalXp() >= 2000
  }
  if aid == "words25" {
    return totalLearned() >= 25
  }
  if aid == "words100" {
    return totalLearned() >= 100
  }
  if aid == "perfect" {
    return kvGet("flag:perfect", "") != ""
  }
  if aid == "poly2" {
    return languagesToday() >= 2 or kvGet("flag:poly2", "") != ""
  }
  if aid == "poly3" {
    return languagesToday() >= 3 or kvGet("flag:poly3", "") != ""
  }
  if aid == "spoke" {
    return kvGet("flag:spoke", "") != ""
  }
  if aid == "convo" {
    return kvGet("flag:convo", "") != ""
  }
  if aid == "quick" {
    return kvGet("flag:quick", "") != ""
  }
  if aid == "rev50" {
    return totalReviews() >= 50
  }
  return false
}

fn achUnlocked(aid) {
  return kvGet("ach:" + aid, "") != ""
}

// Unlocks anything newly earned. Returns the ids that were unlocked just now.
fn checkAchievements() {
  // remember "polyglot day" permanently once it happens
  if languagesToday() >= 2 {
    kvSet("flag:poly2", "1")
  }
  if languagesToday() >= 3 {
    kvSet("flag:poly3", "1")
  }
  let fresh = []
  for each aid in achIds {
    if not achUnlocked(aid) and achMet(aid) {
      kvSet("ach:" + aid, dayNum())
      add aid to fresh
    }
  }
  return fresh
}

fn achCount() {
  let n = 0
  for each aid in achIds {
    if achUnlocked(aid) {
      n += 1
    }
  }
  return n
}

// ---- weekly challenge -----------------------------------------------------
// A new challenge every 7 days (blocks of 7 day-numbers), chosen in turn.
let chNames = ["Earn 150 XP", "Finish 3 lessons", "Study on 5 different days", "Review 40 words"]
let chTargets = [150, 3, 5, 40]

fn weekBlock() {
  return dayNum() / 7
}

fn weekStart() {
  return weekBlock() * 7
}

fn challengeIndex() {
  return weekBlock() % length(chNames)
}

fn challengeProgress() {
  let kind = challengeIndex()
  let total = 0
  let d = weekStart()
  while d < weekStart() + 7 {
    if kind == 0 {
      total += kvNum("day:" + d, 0)
    } else if kind == 1 {
      total += kvNum("les:" + d, 0)
    } else if kind == 2 {
      if kvNum("day:" + d, 0) > 0 {
        total += 1
      }
    } else {
      total += kvNum("rev:" + d, 0)
    }
    d += 1
  }
  return total
}

fn daysLeftInChallenge() {
  return weekStart() + 7 - dayNum()
}
