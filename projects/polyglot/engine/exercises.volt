// =====================================================================
// POLYGLOT - engine/exercises.volt  (the session + exercise engine)
// A "session" is a queue of items: a lesson (vocabulary, grammar, then
// its exercises), a quick-learn run, a spaced-repetition review, or a
// timed vocabulary challenge. This file holds the state and the rules:
// starting sessions, grading every kind of exercise, finishing and
// awarding XP. How things look is in ui/session.volt.
//
// Item types: intro, grammar, ex (an Exercise), flash (a word card).
// Exercise kinds: choice, fill, translate, arrange, match, listen,
// speak, read, convo.
// =====================================================================

let sessionActive = 0
let sessStage = "run"        // run or result
let sessKind = ""            // lesson, quick, review, challenge, convo, speak
let sessLang = ""
let sessLessonId = ""
let sessMinutes = 0
let sessEx = []
let qType = []
let qRef = []
let qi = 0

let phase = "ask"            // ask, then feedback
let okNow = 0
let curOpts = []
let typedVal = ""
let pickedText = ""
let msg = ""
let pool = []
let built = []
let mLeft = []
let mAns = []
let mRight = []
let mDone = []
let mRDone = []
let mSel = -1
let mWrong = -1
let mMiss = 0
let cSteps = []
let cStep = 0
let cMiss = 0
let cChat = []
let cOpts = []
let flipped = 0
let heard = ""
let heardScore = -1
let selfRate = 0

let scoreRight = 0
let scoreTotal = 0
let xpGain = 0
let startMs = 0
let deadline = 0
let missedWords = []
let leaveArmed = 0
let newAch = []
let learnedWords = []
let resultNote = ""

fn copyList(items) {
  let out = []
  for each x in items {
    add x to out
  }
  return out
}

// ---- generated questions from a single word -------------------------------
fn distractors(lang, field, correct, count) {
  let out = []
  let tries = 0
  while length(out) < count and tries < 300 {
    let cand = wordList[random(0, length(wordList) - 1)]
    if cand.lang == lang {
      let v = cand.meaning
      if field == "word" {
        v = cand.word
      }
      if v != correct and not contains(out, v) {
        add v to out
      }
    }
    tries += 1
  }
  return out
}

fn wordWhy(w) {
  let s = w.word
  if w.pron != "" {
    s += " (" + w.pron + ")"
  }
  s += " means “" + w.meaning + "”."
  if w.example != "" {
    s += " Example: " + w.example + " = " + w.exampleEn
  }
  return s
}

// mode 0: word -> meaning, 1: meaning -> word, 2: type the word
fn wordQuestion(lang, wd, mode) {
  let w = wordData(lang, wd)
  let marker = "~" + wd
  if mode == 0 {
    let opts = distractors(lang, "meaning", w.meaning, 3)
    add w.meaning to opts
    return Exercise { lang: lang, lesson: marker, kind: "choice", stem: "What does “" + w.word + "” mean?", answer: w.meaning, options: opts, why: wordWhy(w), extra: w.word }
  }
  if mode == 1 {
    let opts = distractors(lang, "word", w.word, 3)
    add w.word to opts
    return Exercise { lang: lang, lesson: marker, kind: "choice", stem: "Which word means “" + w.meaning + "”?", answer: w.word, options: opts, why: wordWhy(w), extra: "" }
  }
  return Exercise { lang: lang, lesson: marker, kind: "translate", stem: "Type “" + w.meaning + "” in " + langOf(lang).name, answer: w.word, options: [], why: wordWhy(w), extra: w.pron }
}

fn modeForBox(box) {
  if box <= 1 {
    return 0
  }
  if box == 2 {
    return 1
  }
  return 2
}

// ---- session setup ----------------------------------------------------------
fn sessReset(kind, lang, lid) {
  sessionActive = 1
  sessStage = "run"
  sessKind = kind
  sessLang = lang
  sessLessonId = lid
  sessMinutes = 0
  sessEx = []
  qType = []
  qRef = []
  qi = 0
  scoreRight = 0
  scoreTotal = 0
  xpGain = 0
  missedWords = []
  leaveArmed = 0
  newAch = []
  learnedWords = []
  resultNote = ""
  startMs = nowMs()
  deadline = 0
}

fn queueEx(e) {
  add e to sessEx
  add "ex" to qType
  add length(sessEx) - 1 to qRef
}

fn sessGo() {
  itemBegin()
  render()
}

fn startLesson(lang, lid) {
  sessReset("lesson", lang, lid)
  add "intro" to qType
  add "" to qRef
  add "grammar" to qType
  add "" to qRef
  for each i in exOfLesson(lang, lid) {
    queueEx(exList[i])
  }
  sessGo()
}

// Everything the learner has met, due for review, as flashcards.
fn startReview(lang) {
  let due = srsDueWords(lang)
  if length(due) == 0 {
    return 0
  }
  sessReset("review", lang, "")
  let n = 0
  for each wd in due {
    if n < 20 {
      add "flash" to qType
      add wd to qRef
      n += 1
    }
  }
  sessGo()
  return 1
}

// Time-boxed mixed practice: due words first, then exercises from finished lessons.
fn startQuick(lang, minutes) {
  let items = minutes * 2
  sessReset("quick", lang, "")
  sessMinutes = minutes
  let due = srsDueWords(lang)
  let dueN = 0
  for each wd in due {
    if dueN < items * 2 / 5 {
      let rec = srsRec(lang, wd)
      queueEx(wordQuestion(lang, wd, modeForBox(rec[0])))
      dueN += 1
    }
  }
  let ids = []
  for each i in lessonsOf(lang) {
    if lessonScore(lang, lessonList[i].lid) >= 0 {
      add lessonList[i].lid to ids
    }
  }
  let candidates = []
  for each lid in ids {
    for each j in exOfLesson(lang, lid) {
      let k = exList[j].kind
      if k != "read" and k != "convo" and exList[j].extra != "read" {
        add j to candidates
      }
    }
  }
  candidates = shuffle(candidates)
  let c = 0
  while length(qType) < items and c < length(candidates) {
    queueEx(exList[candidates[c]])
    c += 1
  }
  if length(qType) == 0 {
    sessionActive = 0
    return 0
  }
  // mix it so reviews and new practice alternate
  sessGo()
  return 1
}

// 60 seconds, as many right meanings as you can.
fn startChallenge(lang) {
  let all = []
  let i = 0
  while i < length(wordList) {
    if wordList[i].lang == lang {
      add wordList[i].word to all
    }
    i += 1
  }
  if length(all) < 4 {
    return 0
  }
  sessReset("challenge", lang, "")
  all = shuffle(all)
  let n = 0
  while n < 60 {
    queueEx(wordQuestion(lang, all[n % length(all)], random(0, 1)))
    n += 1
  }
  deadline = nowMs() + 60000
  sessGo()
  return 1
}

fn startOne(lang, lid, kind) {
  sessReset(kind, lang, lid)
  let picks = []
  let i = 0
  while i < length(exList) {
    if exList[i].lang == lang and exList[i].kind == kind and lessonScore(lang, exList[i].lesson) >= 0 {
      add i to picks
    }
    i += 1
  }
  picks = shuffle(picks)
  let n = 0
  for each j in picks {
    if n < 8 {
      queueEx(exList[j])
      n += 1
    }
  }
  if length(qType) == 0 {
    sessionActive = 0
    return 0
  }
  sessGo()
  return 1
}

// ---- per item ------------------------------------------------------------------
fn curEx() {
  return sessEx[qRef[qi]]
}

fn pairsLeft(e) {
  let out = []
  for each pr in e.options {
    add split(pr, "=")[0] to out
  }
  return out
}

fn convoPrepStep() {
  let bits = split(cSteps[cStep], "|")
  cOpts = shuffle([bits[2], bits[3], bits[4]])
}

fn itemBegin() {
  phase = "ask"
  okNow = 0
  typedVal = ""
  pickedText = ""
  msg = ""
  flipped = 0
  heard = ""
  heardScore = -1
  selfRate = 0
  if qType[qi] != "ex" {
    return 0
  }
  let e = curEx()
  if e.kind == "choice" or e.kind == "fill" or e.kind == "listen" or e.kind == "read" {
    curOpts = shuffle(copyList(e.options))
  } else if e.kind == "arrange" {
    pool = shuffle(copyList(e.options))
    built = []
  } else if e.kind == "match" {
    mLeft = pairsLeft(e)
    mAns = []
    mRight = []
    mDone = []
    mRDone = []
    for each pr in e.options {
      add split(pr, "=")[1] to mAns
      add split(pr, "=")[1] to mRight
      add 0 to mDone
      add 0 to mRDone
    }
    mRight = shuffle(mRight)
    mSel = -1
    mWrong = -1
    mMiss = 0
  } else if e.kind == "convo" {
    cSteps = e.options
    cStep = 0
    cMiss = 0
    cChat = []
    let first = split(cSteps[0], "|")
    add "them|" + first[0] + "|" + first[1] to cChat
    convoPrepStep()
  } else if e.kind == "speak" {
    if canRecognize() == 0 {
      selfRate = 1
    }
  }
}

fn sessionWordOf(e) {
  if part(e.lesson, 0, 1) == "~" {
    return part(e.lesson, 1, 200)
  }
  return ""
}

// Called when an exercise has been answered.
fn itemFinish(ok) {
  phase = "feedback"
  okNow = ok
  scoreTotal += 1
  let e = curEx()
  let wd = sessionWordOf(e)
  if ok == 1 {
    scoreRight += 1
    if sessKind == "challenge" {
      xpGain += 1
    } else {
      xpGain += 5
    }
    if wd != "" {
      srsGrade(sessLang, wd, 2)
      kvAdd("cnt:reviews", 1)
      kvAdd("rev:" + dayNum(), 1)
    }
  } else {
    if wd != "" {
      srsGrade(sessLang, wd, 0)
      kvAdd("cnt:reviews", 1)
      kvAdd("rev:" + dayNum(), 1)
      if not contains(missedWords, wd) {
        add wd to missedWords
      }
    }
  }
  if e.kind == "speak" and ok == 1 {
    kvSet("flag:spoke", "1")
  }
  if e.kind == "convo" and cMiss == 0 {
    kvSet("flag:convo", "1")
  }
  if e.kind == "convo" and ok == 1 {
    kvSet("flag:convo", "1")
  }
}

fn gradeChoice(index) {
  if phase != "ask" or index >= length(curOpts) {
    return 0
  }
  let e = curEx()
  pickedText = curOpts[index]
  if pickedText == e.answer {
    itemFinish(1)
  } else {
    itemFinish(0)
  }
  if e.kind == "choice" or e.kind == "fill" {
    // read the correct sentence/word aloud after answering (if the device can)
    if e.extra != "" and e.extra != "read" and sessKind != "challenge" {
      speakText(e.extra, voiceOf(sessLang))
    }
  }
}

fn gradeTyped(value) {
  if phase != "ask" {
    return 0
  }
  let e = curEx()
  typedVal = value
  if norm(value) == "" {
    msg = "Type your answer first."
    return 0
  }
  msg = ""
  itemFinish(answerMatches(value, e.answer, e.extra))
}

fn joinPieces() {
  let out = []
  for each b in built {
    add pool[b] to out
  }
  if sessLang == "ja" {
    return join(out, "")
  }
  return join(out, " ")
}

fn arrangeAdd(index) {
  if phase == "ask" and not contains(built, index) {
    add index to built
  }
}

fn arrangeRemove(position) {
  if phase == "ask" and position < length(built) {
    remove built[position]
  }
}

fn gradeArrange() {
  if phase != "ask" {
    return 0
  }
  if length(built) < length(pool) {
    msg = "Use every piece to build the sentence."
    return 0
  }
  msg = ""
  let e = curEx()
  let mine = joinPieces()
  let answer = e.answer
  if sessLang == "ja" {
    answer = join(split(answer, " "), "")
  }
  typedVal = mine
  if answerMatches(mine, answer, e.extra) == 1 {
    itemFinish(1)
  } else {
    itemFinish(0)
  }
}

fn matchLeftTap(index) {
  if phase == "ask" and mDone[index] == 0 {
    mSel = index
    mWrong = -1
  }
}

fn matchRightTap(index) {
  if phase != "ask" or mSel < 0 or mRDone[index] == 1 {
    return 0
  }
  if mRight[index] == mAns[mSel] {
    mDone[mSel] = 1
    mRDone[index] = 1
    mWrong = -1
  } else {
    mMiss += 1
    mWrong = index
  }
  mSel = -1
  let all = 1
  for each d in mDone {
    if d == 0 {
      all = 0
    }
  }
  if all == 1 {
    if mMiss == 0 {
      itemFinish(1)
    } else {
      itemFinish(0)
    }
  }
}

// Pronunciation: listen through the microphone, then score the match.
fn speakAttempt() {
  if phase != "ask" {
    return 0
  }
  let e = curEx()
  heard = "…"
  render()
  let said = listenOnce(voiceOf(sessLang))
  if part(said, 0, 9) == "__error__" {
    heard = ""
    selfRate = 1
    if said == "__error__:not-allowed" {
      msg = "The microphone is blocked for this page. Allow it in your browser, or rate yourself below."
    } else {
      msg = "Couldn't use the microphone here. Say it aloud, then rate yourself."
    }
    render()
    return 0
  }
  if said == "" {
    heard = ""
    msg = "I didn't catch anything. Try again a little louder."
    render()
    return 0
  }
  heard = said
  heardScore = similarity(said, e.extra)
  msg = ""
  if heardScore >= 70 {
    itemFinish(1)
  } else {
    itemFinish(0)
  }
  render()
}

fn speakSelf(good) {
  if phase == "ask" {
    heardScore = -1
    itemFinish(good)
  }
}

fn convoPick(index) {
  if phase != "ask" or index >= length(cOpts) {
    return 0
  }
  let bits = split(cSteps[cStep], "|")
  let choice = cOpts[index]
  if choice != bits[2] {
    cMiss += 1
    msg = "Not quite. " + bits[5]
    // take the wrong answer out so it can't be picked again
    remove cOpts[index]
    return 0
  }
  msg = ""
  add "me|" + choice + "|" to cChat
  cStep += 1
  if cStep >= length(cSteps) {
    if cMiss <= 1 {
      itemFinish(1)
    } else {
      itemFinish(0)
    }
    return 0
  }
  let nextBits = split(cSteps[cStep], "|")
  add "them|" + nextBits[0] + "|" + nextBits[1] to cChat
  convoPrepStep()
  speakText(nextBits[0], voiceOf(sessLang))
}

// Flashcard rating: 0 again, 1 hard, 2 good, 3 easy.
fn flashRate(grade) {
  let wd = qRef[qi]
  srsGrade(sessLang, wd, grade)
  kvAdd("cnt:reviews", 1)
  kvAdd("rev:" + dayNum(), 1)
  scoreTotal += 1
  if grade >= 2 {
    scoreRight += 1
    xpGain += 2
  } else {
    if not contains(missedWords, wd) {
      add wd to missedWords
    }
  }
  if grade == 0 and sessLang != "" {
    // forgotten cards come back once more at the end of this session
    add "flash" to qType
    add wd to qRef
  }
  itemNext()
}

// ---- moving on and finishing -----------------------------------------------------
fn itemNext() {
  qi += 1
  if qi >= length(qType) {
    finishSession()
    return 0
  }
  if sessKind == "quick" and (nowMs() - startMs) >= sessMinutes * 60000 {
    finishSession()
    return 0
  }
  itemBegin()
  render()
  if qType[qi] == "ex" {
    let e = curEx()
    if e.kind == "listen" and canSpeak() == 1 {
      speakText(e.extra, voiceOf(sessLang))
    }
  }
}

fn tickChallenge() {
  if sessionActive == 1 and sessStage == "run" and sessKind == "challenge" {
    let left = (deadline - nowMs()) / 1000
    if left <= 0 {
      finishSession()
    } else {
      # const c = document.getElementById('clock'); if (c) { c.textContent = left + 's'; }
    }
  }
}

fn finishSession() {
  if sessStage == "result" {
    return 0
  }
  let seconds = (nowMs() - startMs) / 1000
  let L = langOf(sessLang)
  if sessKind == "lesson" {
    let pos = lessonPos(sessLang, sessLessonId)
    let score = pct(scoreRight, scoreTotal)
    if score > lessonScore(sessLang, sessLessonId) {
      kvSet("done:" + sessLang + ":" + sessLessonId, score)
    }
    xpGain += 20
    if score == 100 {
      xpGain += 15
      kvSet("flag:perfect", "1")
    }
    kvAdd("les:" + dayNum(), 1)
    for each i in wordsOfLesson(sessLang, sessLessonId) {
      srsSeed(sessLang, wordList[i].word)
      add wordList[i].word to learnedWords
    }
    logAdd(sessLang, "Finished lesson: " + lessonList[pos].title + " (" + score + "%)")
    resultNote = lessonList[pos].title
  } else if sessKind == "quick" {
    logAdd(sessLang, "Quick learn: " + scoreRight + " of " + scoreTotal + " right")
  } else if sessKind == "review" {
    logAdd(sessLang, "Reviewed " + scoreTotal + " words")
  } else if sessKind == "challenge" {
    logAdd(sessLang, "Vocabulary challenge: " + scoreRight + " points")
    if scoreRight > kvNum("hi:" + sessLang, 0) {
      kvSet("hi:" + sessLang, scoreRight)
      resultNote = "New personal best!"
    }
    if scoreRight >= 15 {
      kvSet("flag:quick", "1")
    }
  } else if sessKind == "convo" {
    logAdd(sessLang, "Practised a conversation")
  } else if sessKind == "speak" {
    logAdd(sessLang, "Practised pronunciation")
  }
  addXp(sessLang, xpGain)
  addStudySeconds(sessLang, seconds)
  newAch = checkAchievements()
  sessStage = "result"
  render()
}

fn closeSession() {
  sessionActive = 0
  sessStage = "run"
  leaveArmed = 0
  // an unfinished session still counts the time spent and XP earned so far
  render()
}

// Leaving mid-way keeps the XP and study time already earned.
fn leaveSession() {
  if sessStage == "run" and (scoreTotal > 0 or xpGain > 0) {
    addXp(sessLang, xpGain)
    addStudySeconds(sessLang, (nowMs() - startMs) / 1000)
    checkAchievements()
  }
  closeSession()
}
