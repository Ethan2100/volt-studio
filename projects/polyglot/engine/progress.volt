// =====================================================================
// POLYGLOT - engine/progress.volt
// XP, daily study time, streaks, the activity log and per-language
// counters. Every number is stored per language AND per day, so the
// dashboard, statistics and goals are all computed from the same data.
//
// Stored keys:
//   xp:<lang>:<day>   XP earned that day        day:<day>  XP, all languages
//   sec:<lang>:<day>  seconds studied that day
//   xpt / xpt:<lang>  lifetime XP
//   done:<lang>:<lessonId>  lesson completed (best score as text)
//   w:<lang>:<word>   spaced-repetition record "box|due|lapses|seen"
//   log               recent activity, one "day|lang|text" per line
// =====================================================================

fn addXp(lang, amount) {
  if amount <= 0 {
    return 0
  }
  let d = dayNum()
  kvAdd("xp:" + lang + ":" + d, amount)
  kvAdd("day:" + d, amount)
  kvAdd("xpt:" + lang, amount)
  kvAdd("xpt", amount)
}

fn totalXp() {
  return kvNum("xpt", 0)
}

fn langXp(lang) {
  return kvNum("xpt:" + lang, 0)
}

fn xpOnDay(lang, day) {
  return kvNum("xp:" + lang + ":" + day, 0)
}

fn addStudySeconds(lang, seconds) {
  if seconds > 0 {
    kvAdd("sec:" + lang + ":" + dayNum(), min(seconds, 3600))
    kvAdd("sect:" + lang, min(seconds, 3600))
  }
}

fn secondsOnDay(lang, day) {
  return kvNum("sec:" + lang + ":" + day, 0)
}

fn minutesToday(lang) {
  return secondsOnDay(lang, dayNum()) / 60
}

// Days in a row with any XP. If today has none yet, the streak is still
// alive until midnight, so it counts back from yesterday.
fn streakDays() {
  let d = dayNum()
  if kvNum("day:" + d, 0) == 0 {
    d -= 1
  }
  let n = 0
  while kvNum("day:" + d, 0) > 0 and n < 3650 {
    n += 1
    d -= 1
  }
  return n
}

// ---- lessons ------------------------------------------------------------
fn lessonsDone(lang) {
  return length(kvKeys("done:" + lang + ":"))
}

fn lessonDone(lang, lessonId) {
  return kvGet("done:" + lang + ":" + lessonId, "") != ""
}

// ---- words (spaced-repetition records live in engine/srs.volt) -----------
fn learnedCount(lang) {
  let n = 0
  for each k in kvKeys("w:" + lang + ":") {
    let rec = split(kvGet(k, "0|0|0|0"), "|")
    if number(rec[0]) >= 3 {
      n += 1
    }
  }
  return n
}

fn seenCount(lang) {
  return length(kvKeys("w:" + lang + ":"))
}

// ---- learner level ------------------------------------------------------
// Level grows with the square root of XP, so early levels come quickly.
fn levelFor(xp) {
  return 1 + sqrt(xp / 40)
}

fn xpForLevel(level) {
  return (level - 1) * (level - 1) * 40
}

// ---- activity log -------------------------------------------------------------
fn logAdd(lang, message) {
  let clean = join(split(join(split("" + message, "|"), "/"), "\n"), " ")
  let old = kvGet("log", "")
  let lines = []
  if old != "" {
    lines = split(old, "\n")
  }
  let out = [dayNum() + "|" + lang + "|" + clean]
  let i = 0
  while i < length(lines) and i < 39 {
    add lines[i] to out
    i += 1
  }
  kvSet("log", join(out, "\n"))
}

// Newest first: a list of "day|lang|text" strings.
fn recentLog(count) {
  let raw = kvGet("log", "")
  let out = []
  if raw == "" {
    return out
  }
  let lines = split(raw, "\n")
  let i = 0
  while i < length(lines) and i < count {
    add lines[i] to out
    i += 1
  }
  return out
}
