// =====================================================================
// POLYGLOT - content/schema.volt
// The shapes of course content, plus small queries over it. Content
// files (es.volt, de.volt ...) fill these lists with real lessons; this
// file never contains lesson text itself.
//
// Volt structs are flat, so lists inside a field are used for anything
// that repeats (grammar points, answer options).
// =====================================================================

// A lesson belongs to one language and one CEFR level (A1 ... C2).
Lesson = type { lang: string, lid: string, level: string, unit: string, num: int, title: string, goal: string, grammarTitle: string, grammar: string, points: list, minutes: int }

// A vocabulary item. `pron` is a respelling or reading, `say` is what the
// browser voice should speak (usually the word itself).
Word = type { lang: string, lesson: string, word: string, say: string, pron: string, meaning: string, example: string, exampleEn: string, cat: string, diff: int }

// An exercise. kind is one of: choice, fill, translate, arrange, match,
// listen, speak, read. For `choice`, options holds the choices and answer
// the correct one. `why` is the explanation shown after every answer.
Exercise = type { lang: string, lesson: string, kind: string, stem: string, answer: string, options: list, why: string, extra: string }

let lessonList = []
let wordList = []
let exList = []

fn lessonCount(code) {
  let n = 0
  for each l in lessonList {
    if l.lang == code {
      n += 1
    }
  }
  return n
}

// A language has a course only if real lessons were written for it.
fn hasCourse(code) {
  return lessonCount(code) > 0
}

fn wordCount(code) {
  let n = 0
  for each w in wordList {
    if w.lang == code {
      n += 1
    }
  }
  return n
}

// ---- authoring helpers (used by the content files) ----------------------
// defLesson(lang, lid, level, unit, num, title, goal, grammarTitle, grammar, points, minutes)
//   points: list of "pattern|explanation" strings
// defWord(lang, lid, word, pron, meaning, example, exampleEn, category, difficulty 1-3)
// defEx(lang, lid, kind, stem, answer, options, why, extra)
//   choice  : options = the choices (including answer)
//   fill    : stem contains ___ ; options = word bank
//   translate: typed; extra = other accepted answers separated by |
//   arrange : options = the sentence's pieces; answer = pieces joined by spaces; extra = other accepted orders separated by |
//   match   : options = "left=right" pairs
//   listen  : extra = the text that is spoken; options = meanings; answer = the right one
//   speak   : extra = the text to say aloud; answer = its meaning
//   read    : stem = title, extra = passage, options = three English summaries, answer = the right summary
//   convo   : stem = title, options = steps "partner line|English|best reply|wrong reply|wrong reply|why", why = summary

fn defLesson(lang, lid, level, unit, num, title, goal, gTitle, grammar, points, minutes) {
  add Lesson { lang: lang, lid: lid, level: level, unit: unit, num: num, title: title, goal: goal, grammarTitle: gTitle, grammar: grammar, points: points, minutes: minutes } to lessonList
}

fn defWord(lang, lid, wd, pron, meaning, example, exampleEn, cat, diff) {
  add Word { lang: lang, lesson: lid, word: wd, say: wd, pron: pron, meaning: meaning, example: example, exampleEn: exampleEn, cat: cat, diff: diff } to wordList
}

fn defEx(lang, lid, kind, stem, answer, options, why, extra) {
  add Exercise { lang: lang, lesson: lid, kind: kind, stem: stem, answer: answer, options: options, why: why, extra: extra } to exList
}

// defRead(lang, lid, title, passage, summaries, why)
//   A reading exercise: the learner reads the passage and picks which English
//   summary fits. The FIRST summary must be the correct one (they are shuffled
//   when shown).
fn defRead(lang, lid, title, passage, summaries, why) {
  defEx(lang, lid, "read", title, summaries[0], summaries, why, passage)
}
