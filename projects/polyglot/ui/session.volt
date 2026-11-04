// =====================================================================
// POLYGLOT - ui/session.volt
// Focus-mode screens for lessons and practice: one thing on screen at a
// time, a progress bar, and a feedback bar that explains every answer.
// All state lives in engine/exercises.volt; this file only draws it.
// =====================================================================

fn sayBtn(phrase) {
  if canSpeak() == 0 or phrase == "" {
    return ""
  }
  return "<button class='btn ghost sm' data-act='ex:say' data-arg='" + esc(phrase) + "' aria-label='Hear it'>🔊</button>"
}

fn optButton(index, label, cls) {
  let key = index + 1
  return "<button class='opt " + cls + "' data-act='ex:pick' data-arg='" + index + "' data-opt='" + key + "'><span class='k'>" + key + "</span><span>" + esc(label) + "</span></button>"
}

fn optsHtml(correct) {
  let h = "<div class='opts'>"
  let i = 0
  while i < length(curOpts) {
    let cls = ""
    if phase == "feedback" {
      if curOpts[i] == correct {
        cls = "right"
      } else if curOpts[i] == pickedText {
        cls = "wrong"
      } else {
        cls = "dim"
      }
    }
    h += optButton(i, curOpts[i], cls)
    i += 1
  }
  return h + "</div>"
}

fn typedHtml(placeholder) {
  let dis = ""
  if phase == "feedback" {
    dis = " disabled"
  }
  let h = "<input id='ans' class='field' autocomplete='dis' autocapitalize='dis' spellcheck='false' placeholder='" + esc(placeholder) + "' value='" + esc(typedVal) + "'" + dis + ">"
  if msg != "" {
    h += "<div class='small' style='color:var(--bad);margin-top:8px'>" + esc(msg) + "</div>"
  }
  return h
}

fn blankStem(stem, fill) {
  let bits = split(esc(stem), "___")
  if length(bits) < 2 {
    return esc(stem)
  }
  return bits[0] + "<span class='blank'>" + esc(fill) + "&nbsp;</span>" + bits[1]
}

fn exBody() {
  let e = curEx()
  let h = ""
  if e.kind == "choice" {
    h += "<div class='eyebrow'>Choose the answer</div><div class='q'>" + esc(e.stem) + " " + sayBtn(e.extra) + "</div>" + optsHtml(e.answer)
  } else if e.kind == "fill" {
    let shown = ""
    if phase == "feedback" {
      shown = e.answer
    } else {
      shown = pickedText
    }
    h += "<div class='eyebrow'>Fill in the blank</div><div class='q'>" + blankStem(e.stem, shown) + "</div>" + optsHtml(e.answer)
  } else if e.kind == "translate" {
    h += "<div class='eyebrow'>Translate</div><div class='q'>" + esc(e.stem) + "</div>" + typedHtml("Type your answer")
  } else if e.kind == "listen" {
    h += "<div class='eyebrow'>Listening</div><div class='q'>What do you hear?</div>"
    if canSpeak() == 1 {
      h += "<div style='margin-bottom:18px'><button class='btn primary' data-act='ex:say' data-arg='" + esc(e.extra) + "'>🔊 Play audio</button> <button class='btn ghost' data-act='ex:slow' data-arg='" + esc(e.extra) + "'>Slower</button></div>"
    } else {
      h += "<div class='card flat' style='margin-bottom:18px'>Your browser can't play speech. Read it instead: <b>" + esc(e.extra) + "</b></div>"
    }
    h += optsHtml(e.answer)
  } else if e.kind == "arrange" {
    h += "<div class='eyebrow'>Build the sentence</div><div class='q'>" + esc(e.stem) + "</div><div class='tray'>"
    let i = 0
    while i < length(built) {
      h += "<button class='piece' data-act='ex:unbuild' data-arg='" + i + "'>" + esc(pool[built[i]]) + "</button>"
      i += 1
    }
    h += "</div><div class='pool'>"
    i = 0
    while i < length(pool) {
      let cls = "piece"
      if contains(built, i) {
        cls = "piece used"
      }
      h += "<button class='" + cls + "' data-act='ex:build' data-arg='" + i + "'>" + esc(pool[i]) + "</button>"
      i += 1
    }
    h += "</div>"
    if msg != "" {
      h += "<div class='small' style='color:var(--bad);margin-top:12px'>" + esc(msg) + "</div>"
    }
  } else if e.kind == "match" {
    h += "<div class='eyebrow'>Match the pairs</div><div class='q'>" + esc(e.stem) + "</div><div class='cols'><div class='stack'>"
    let i = 0
    while i < length(mLeft) {
      let cls = "opt"
      if mDone[i] == 1 {
        cls = "opt right"
      } else if mSel == i {
        cls = "opt sel"
      }
      h += "<button class='" + cls + "' data-act='ex:mleft' data-arg='" + i + "'>" + esc(mLeft[i]) + "</button>"
      i += 1
    }
    h += "</div><div class='stack'>"
    i = 0
    while i < length(mRight) {
      let cls = "opt"
      if mRDone[i] == 1 {
        cls = "opt right"
      } else if mWrong == i {
        cls = "opt wrong"
      }
      h += "<button class='" + cls + "' data-act='ex:mright' data-arg='" + i + "'>" + esc(mRight[i]) + "</button>"
      i += 1
    }
    h += "</div></div>"
  } else if e.kind == "speak" {
    h += "<div class='eyebrow'>Say it out loud</div><div class='q'>" + esc(e.extra) + " " + sayBtn(e.extra) + "</div><p class='muted'>Means: " + esc(e.answer) + "</p>"
    if e.stem != "" {
      h += "<p class='muted small'>" + esc(e.stem) + "</p>"
    }
    if selfRate == 0 {
      h += "<button class='btn primary' data-act='ex:mic'>🎙 Hold on, I'll listen</button>"
    } else if phase == "ask" {
      h += "<div class='card flat'>Say the phrase aloud, then be honest with yourself:</div><div class='row' style='margin-top:12px'><button class='btn primary' data-act='ex:self' data-arg='1'>I said it well</button><button class='btn ghost' data-act='ex:self' data-arg='0'>I need more practice</button></div>"
    }
    if heard != "" {
      h += "<p>I heard: <b>" + esc(heard) + "</b>"
      if heardScore >= 0 {
        h += " (" + heardScore + "% match)"
      }
      h += "</p>"
    }
    if msg != "" {
      h += "<div class='small' style='color:var(--bad);margin-top:8px'>" + esc(msg) + "</div>"
    }
  } else if e.kind == "read" {
    h += "<div class='eyebrow'>Reading · " + esc(e.stem) + "</div><div class='passage'>" + esc(e.extra) + " " + sayBtn(e.extra) + "</div><div class='q' style='font-size:1.2rem'>What is this about?</div>" + optsHtml(e.answer)
  } else if e.kind == "convo" {
    h += "<div class='eyebrow'>Conversation · " + esc(e.stem) + "</div>"
    for each line in cChat {
      let bits = split(line, "|")
      let cls = "bubble"
      if bits[0] == "me" {
        cls = "bubble me"
      }
      h += "<div class='" + cls + "'>" + esc(bits[1])
      if bits[2] != "" {
        h += "<small>" + esc(bits[2]) + "</small>"
      }
      h += "</div>"
    }
    if phase == "ask" {
      h += "<div class='eyebrow' style='margin-top:18px'>Your reply</div><div class='opts' style='margin-top:8px'>"
      let i = 0
      while i < length(cOpts) {
        h += optButton(i, cOpts[i], "")
        i += 1
      }
      h += "</div>"
      if msg != "" {
        h += "<div class='small' style='color:var(--bad);margin-top:10px'>" + esc(msg) + "</div>"
      }
    }
  }
  return h
}

fn feedbackBar() {
  let e = curEx()
  let cls = "bad"
  let head = "Not quite"
  if okNow == 1 {
    cls = "good"
    head = "Correct!"
  }
  let why = ""
  if e.kind == "translate" or e.kind == "arrange" {
    if okNow == 0 {
      why += "Answer: <b style='display:inline;font-size:1rem'>" + esc(e.answer) + "</b><br>"
    }
  }
  if e.kind == "speak" and okNow == 0 and heardScore >= 0 {
    why += "Try again later. "
  }
  why += esc(e.why)
  return "<div class='fbar " + cls + "'><div class='in'><div class='why'><b>" + head + "</b>" + why + "</div><button class='btn primary' data-act='ex:next'>Continue</button></div></div>"
}

fn askBar() {
  let e = curEx()
  let label = ""
  let cmdName = "ex:check"
  if e.kind == "translate" {
    label = "Check"
  } else if e.kind == "arrange" {
    label = "Check"
  }
  if label == "" {
    return ""
  }
  return "<div class='fbar'><div class='in'><span class='sp'></span><button class='btn primary' data-act='" + cmdName + "'>" + label + "</button></div></div>"
}

fn introBody() {
  let L = langOf(sessLang)
  let pos = lessonPos(sessLang, sessLessonId)
  let les = lessonList[pos]
  let h = "<div class='eyebrow'>" + les.level + " · Unit " + les.unit + " · Lesson " + les.num + "</div><h1 class='h1'>" + esc(les.title) + "</h1><p class='lede'>" + esc(les.goal) + "</p>"
  h += "<div class='sechead' style='margin-top:26px'><h2 class='h2'>New words</h2></div><div class='vocab'>"
  for each i in wordsOfLesson(sessLang, sessLessonId) {
    let w = wordList[i]
    h += "<div class='w'><div class='sp'><b>" + esc(w.word) + "</b> <span class='muted'>" + esc(w.pron) + "</span><div class='small'>" + esc(w.meaning) + "</div>"
    if w.example != "" {
      h += "<div class='small muted'>" + esc(w.example) + " — " + esc(w.exampleEn) + "</div>"
    }
    h += "</div>" + sayBtn(w.say) + "</div>"
  }
  h += "</div><div style='margin-top:22px'><button class='btn primary' data-act='ex:next'>Continue to grammar</button></div>"
  return h
}

fn grammarBody() {
  let pos = lessonPos(sessLang, sessLessonId)
  let les = lessonList[pos]
  let h = "<div class='eyebrow'>Grammar</div><h1 class='h1'>" + esc(les.grammarTitle) + "</h1><p style='font-size:1.05rem;line-height:1.7'>" + esc(les.grammar) + "</p>"
  h += "<div class='card flat' style='margin-top:18px'>"
  for each pt in les.points {
    let bits = split(pt, "|")
    h += "<div class='gpoint'><code>" + esc(bits[0]) + "</code><span>" + esc(bits[1]) + "</span></div>"
  }
  h += "</div><div style='margin-top:22px'><button class='btn primary' data-act='ex:next'>Start exercises</button></div>"
  return h
}

fn flashBody() {
  let wd = qRef[qi]
  let w = wordData(sessLang, wd)
  let h = "<div class='eyebrow'>Flashcard</div><div class='flash'><div class='big'>" + esc(w.word) + "</div><div class='muted'>" + esc(w.pron) + "</div><div style='margin-top:6px'>" + sayBtn(w.say) + "</div>"
  if flipped == 1 {
    h += "<hr style='border:0;border-top:1px solid var(--line);margin:20px 0'><div style='font-size:1.4rem'>" + esc(w.meaning) + "</div>"
    if w.example != "" {
      h += "<div class='muted' style='margin-top:8px'>" + esc(w.example) + "<br>" + esc(w.exampleEn) + "</div>"
    }
  }
  h += "</div><div style='margin-top:18px'>"
  if flipped == 0 {
    h += "<button class='btn primary wide' data-act='ex:flip'>Show answer</button>"
  } else {
    h += "<div class='eyebrow' style='margin-bottom:8px'>How well did you know it?</div><div class='row wrap'><button class='btn danger sm' data-act='ex:rate' data-arg='0'>Again</button><button class='btn ghost sm' data-act='ex:rate' data-arg='1'>Hard</button><button class='btn ghost sm' data-act='ex:rate' data-arg='2'>Good</button><button class='btn primary sm' data-act='ex:rate' data-arg='3'>Easy</button></div>"
  }
  return h + "</div>"
}

fn resultBody() {
  let score = pct(scoreRight, scoreTotal)
  let h = "<div class='eyebrow'>Session complete</div><h1 class='h1'>"
  if sessKind == "challenge" {
    h += scoreRight + " points</h1>"
  } else if score >= 90 {
    h += "Excellent work.</h1>"
  } else if score >= 70 {
    h += "Nicely done.</h1>"
  } else {
    h += "Good effort.</h1>"
  }
  if resultNote != "" {
    h += "<p class='lede'>" + esc(resultNote) + "</p>"
  }
  h += "<div class='stats'>" + statCard("XP earned", "+" + xpGain) + statCard("correct", scoreRight + "/" + scoreTotal) + statCard("accuracy", score + "%") + statCard("minutes", ((nowMs() - startMs) / 60000) + 1) + "</div>"
  if length(newAch) > 0 {
    h += "<div class='sec'><h2 class='h2'>Achievement unlocked</h2><div class='row wrap' style='margin-top:10px'>"
    for each aid in newAch {
      h += "<span class='chip good'>★ " + achNames[posOf(achIds, aid)] + "</span>"
    }
    h += "</div></div>"
  }
  if length(learnedWords) > 0 {
    h += "<div class='sec'><h2 class='h2'>Words added to your reviews</h2><div class='row wrap' style='margin-top:10px'>"
    for each wd in learnedWords {
      h += "<span class='chip'>" + esc(wd) + "</span>"
    }
    h += "</div></div>"
  }
  if length(missedWords) > 0 {
    h += "<div class='sec'><h2 class='h2'>To revisit</h2><div class='row wrap' style='margin-top:10px'>"
    for each wd in missedWords {
      h += "<span class='chip'>" + esc(wd) + "</span>"
    }
    h += "</div></div>"
  }
  h += "<div class='row wrap' style='margin-top:28px'>"
  if sessKind == "lesson" {
    let nx = nextLessonPos(sessLang)
    if nx >= 0 {
      h += "<button class='btn primary' data-act='ex:startnext'>Next lesson</button>"
    }
  }
  h += "<button class='btn ghost' data-act='ex:close'>Done</button></div>"
  return h
}

fn screenSession() {
  let L = langOf(sessLang)
  let done = qi
  if sessStage == "result" {
    done = length(qType)
  }
  let top = "<div class='ftop'><button class='btn ghost sm' data-act='ex:leave' aria-label='Leave'>✕</button>"
  if sessKind == "challenge" and sessStage == "run" {
    top += "<span class='chip' id='clock'>60s</span>"
  }
  top += barHtml(pct(done, length(qType))) + "</div>"
  let body = ""
  let bar = ""
  if sessStage == "result" {
    body = resultBody()
  } else if qType[qi] == "intro" {
    body = introBody()
  } else if qType[qi] == "grammar" {
    body = grammarBody()
  } else if qType[qi] == "flash" {
    body = flashBody()
  } else {
    body = exBody()
    if phase == "feedback" {
      bar = feedbackBar()
    } else {
      bar = askBar()
    }
  }
  let leave = ""
  if leaveArmed == 1 {
    leave = "<div class='fbar bad'><div class='in'><div class='why'><b>Leave this session?</b>XP and time so far are kept.</div><button class='btn ghost' data-act='ex:stay'>Stay</button><button class='btn danger' data-act='ex:leaveyes'>Leave</button></div></div>"
    bar = leave
  }
  return "<div class='focus lc' style='--h:" + L.hue + "'>" + top + "<div class='fbody'>" + body + "</div>" + bar + "</div>"
}
