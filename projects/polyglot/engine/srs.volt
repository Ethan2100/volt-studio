// =====================================================================
// POLYGLOT - engine/srs.volt  (spaced repetition)
// A Leitner-style box system with per-word difficulty.
//
// Each word the learner has met has a record "box|due|lapses|seen":
//   box     0 (new / forgotten) ... 5 (mastered)
//   due     the day number it should next be reviewed
//   lapses  how often it was forgotten
//   seen    how many reviews it has had
// Intervals (days) grow with the box: 0, 1, 3, 7, 16, 35. A word you keep
// forgetting gets SHORTER intervals (and is shown first when several are
// due), while a mastered word waits weeks - so hard words come back more
// often and mastered words rarely, as intended.
//
// Grades: 0 again, 1 hard, 2 good, 3 easy.
// =====================================================================

let srsDays = [0, 1, 3, 7, 16, 35]

fn srsKey(lang, wd) {
  return "w:" + lang + ":" + wd
}

// [box, due, lapses, seen] as numbers, or [] if the word hasn't been met.
fn srsRec(lang, wd) {
  let raw = kvGet(srsKey(lang, wd), "")
  if raw == "" {
    return []
  }
  let bits = split(raw, "|")
  return [number(bits[0]), number(bits[1]), number(bits[2]), number(bits[3])]
}

fn srsSave(lang, wd, rec) {
  kvSet(srsKey(lang, wd), rec[0] + "|" + rec[1] + "|" + rec[2] + "|" + rec[3])
}

// Days until the next review for a box, shortened for words that keep lapsing.
fn srsInterval(box, lapses) {
  let base = srsDays[min(box, 5)]
  if base == 0 {
    return 0
  }
  let scale = 10 - min(lapses, 3) * 2
  return max(1, base * scale / 10)
}

// First meeting (finishing the lesson that teaches it): due tomorrow.
fn srsSeed(lang, wd) {
  if length(srsRec(lang, wd)) == 0 {
    srsSave(lang, wd, [1, dayNum() + 1, 0, 0])
  }
}

fn srsGrade(lang, wd, grade) {
  let rec = srsRec(lang, wd)
  if length(rec) == 0 {
    rec = [0, dayNum(), 0, 0]
  }
  let box = rec[0]
  let lapses = rec[2]
  if grade == 0 {
    box = 0
    lapses += 1
    rec[1] = dayNum()
  } else if grade == 1 {
    box = max(box, 1)
    rec[1] = dayNum() + max(1, srsInterval(box, lapses) / 2)
  } else if grade == 2 {
    box = min(box + 1, 5)
    rec[1] = dayNum() + srsInterval(box, lapses)
  } else {
    box = min(box + 2, 5)
    rec[1] = dayNum() + srsInterval(box, lapses)
  }
  rec[0] = box
  rec[2] = lapses
  rec[3] += 1
  srsSave(lang, wd, rec)
}

// new / learning / familiar / mastered
fn srsStatus(lang, wd) {
  let rec = srsRec(lang, wd)
  if length(rec) == 0 {
    return "new"
  }
  if rec[0] >= 4 {
    return "mastered"
  }
  if rec[0] >= 2 {
    return "familiar"
  }
  return "learning"
}

fn srsDifficult(lang, wd) {
  let rec = srsRec(lang, wd)
  if length(rec) == 0 {
    return 0
  }
  if rec[2] >= 2 and rec[0] <= 2 {
    return 1
  }
  return 0
}

// Words due today or overdue, hardest and most overdue first.
fn srsDueWords(lang) {
  let today = dayNum()
  let names = []
  let scores = []
  let prefix = "w:" + lang + ":"
  for each k in kvKeys(prefix) {
    let wd = part(k, length(prefix), 200)
    let rec = srsRec(lang, wd)
    if length(rec) == 4 and rec[1] <= today {
      let sc = (rec[1] - today) * 10 - rec[2]
      add wd to names
      add sc to scores
    }
  }
  let out = []
  while length(names) > 0 {
    let best = 0
    let i = 1
    while i < length(names) {
      if scores[i] < scores[best] {
        best = i
      }
      i += 1
    }
    add names[best] to out
    remove names[best]
    remove scores[best]
  }
  return out
}

fn dueCount(lang) {
  return length(srsDueWords(lang))
}

fn masteredCount(lang) {
  let n = 0
  let prefix = "w:" + lang + ":"
  for each k in kvKeys(prefix) {
    let rec = srsRec(lang, part(k, length(prefix), 200))
    if length(rec) == 4 and rec[0] >= 4 {
      n += 1
    }
  }
  return n
}

fn difficultCount(lang) {
  let n = 0
  let prefix = "w:" + lang + ":"
  for each k in kvKeys(prefix) {
    if srsDifficult(lang, part(k, length(prefix), 200)) == 1 {
      n += 1
    }
  }
  return n
}
