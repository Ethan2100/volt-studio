// =====================================================================
// POLYGLOT - engine/lessons.volt
// Queries over the course content and over the learner's progress in it.
// =====================================================================

let cefrLevels = ["A1", "A2", "B1", "B2", "C1", "C2"]
let cefrNames = ["Beginner", "Elementary", "Intermediate", "Upper Intermediate", "Advanced", "Proficient"]

// Positions in lessonList for one language, in the order they were written.
fn lessonsOf(lang) {
  let out = []
  let i = 0
  while i < length(lessonList) {
    if lessonList[i].lang == lang {
      add i to out
    }
    i += 1
  }
  return out
}

fn lessonsAtLevel(lang, level) {
  let out = []
  for each i in lessonsOf(lang) {
    if lessonList[i].level == level {
      add i to out
    }
  }
  return out
}

fn lessonPos(lang, lid) {
  let i = 0
  while i < length(lessonList) {
    if lessonList[i].lang == lang and lessonList[i].lid == lid {
      return i
    }
    i += 1
  }
  return -1
}

fn wordsOfLesson(lang, lid) {
  let out = []
  let i = 0
  while i < length(wordList) {
    if wordList[i].lang == lang and wordList[i].lesson == lid {
      add i to out
    }
    i += 1
  }
  return out
}

fn exOfLesson(lang, lid) {
  let out = []
  let i = 0
  while i < length(exList) {
    if exList[i].lang == lang and exList[i].lesson == lid {
      add i to out
    }
    i += 1
  }
  return out
}

// Best score (0-100) for a finished lesson, or -1 if not finished yet.
fn lessonScore(lang, lid) {
  let raw = kvGet("done:" + lang + ":" + lid, "")
  if raw == "" {
    return -1
  }
  return number(raw)
}

// Position in lessonList of the first lesson not finished yet (-1 if all done).
fn nextLessonPos(lang) {
  for each i in lessonsOf(lang) {
    if lessonScore(lang, lessonList[i].lid) < 0 {
      return i
    }
  }
  return -1
}

// Finished lessons scored under 75%: worth another go.
fn weakLessons(lang) {
  let out = []
  for each i in lessonsOf(lang) {
    let sc = lessonScore(lang, lessonList[i].lid)
    if sc >= 0 and sc < 75 {
      add i to out
    }
  }
  return out
}

// The word record for a language + word text: from the course if it is
// there, otherwise from the personal notebook, otherwise a bare record.
fn wordData(lang, wd) {
  let i = 0
  while i < length(wordList) {
    if wordList[i].lang == lang and wordList[i].word == wd {
      return wordList[i]
    }
    i += 1
  }
  for each entry in notebookEntries(lang) {
    let bits = split(entry, "|")
    if bits[0] == wd {
      return Word { lang: lang, lesson: "", word: wd, say: wd, pron: "", meaning: bits[1], example: bits[2], exampleEn: "", cat: "notebook", diff: 2 }
    }
  }
  return Word { lang: lang, lesson: "", word: wd, say: wd, pron: "", meaning: "?", example: "", exampleEn: "", cat: "", diff: 2 }
}

// ---- notebook (personal words) -------------------------------------------
// Stored as one line per word: "word|meaning|note".
fn notebookEntries(lang) {
  let raw = kvGet("nb:" + lang, "")
  if raw == "" {
    return []
  }
  return split(raw, "\n")
}

fn trimText(s) {
  # return String(s).replace(/\s+/g, ' ').trim();
}

fn cleanField(s) {
  return trimText(join(split(join(split("" + s, "|"), "/"), "\n"), " "))
}

// Returns "" on success, otherwise a message to show the person.
fn notebookAdd(lang, wd, meaning, note) {
  let a = cleanField(wd)
  let b = cleanField(meaning)
  let c = cleanField(note)
  if length(a) == 0 or length(b) == 0 {
    return "Both the word and its meaning are needed."
  }
  if length(a) > 60 or length(b) > 80 or length(c) > 160 {
    return "That's too long: keep the word under 60 characters, the meaning under 80 and the note under 160."
  }
  for each entry in notebookEntries(lang) {
    if split(entry, "|")[0] == a {
      return "That word is already in your notebook."
    }
  }
  let out = notebookEntries(lang)
  add a + "|" + b + "|" + c to out
  kvSet("nb:" + lang, join(out, "\n"))
  srsSeed(lang, a)
  return ""
}

fn notebookRemove(lang, wd) {
  let out = []
  for each entry in notebookEntries(lang) {
    if split(entry, "|")[0] != wd {
      add entry to out
    }
  }
  kvSet("nb:" + lang, join(out, "\n"))
  kvDel(srsKey(lang, wd))
}
