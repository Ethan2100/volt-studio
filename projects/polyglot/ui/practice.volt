// =====================================================================
// POLYGLOT - ui/practice.volt
// Practice hub: quick-learn sessions (5/10/15/30 min), spaced-repetition
// review, a 60-second vocabulary challenge, and focused drills.
// =====================================================================

fn practiceTile(title, body, cmd, arg, enabled) {
  let dis = ""
  if enabled == 0 {
    dis = " disabled style='opacity:.5'"
  }
  return "<button class='card' data-act='" + cmd + "' data-arg='" + arg + "'" + dis + "><div class='h2'>" + title + "</div><div class='small muted' style='margin-top:4px'>" + body + "</div></button>"
}

fn screenPractice() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>Train</div><h1 class='h1'>Practice</h1><p class='lede'>Short sessions that fit the time you have. Words you find hard come back sooner; words you know come back later.</p>"
  if length(langs) == 0 {
    return h + "<div style='margin-top:24px'>" + emptyHtml("Pick a language first", "Practice works on the languages you study.<div style='margin-top:14px'><button class='btn primary' data-act='nav:languages'>Choose languages</button></div>") + "</div>"
  }
  h += pathLangTabs()
  let code = currentLang()
  let L = langOf(code)
  h += "<div class='lc' style='--h:" + L.hue + "'>"
  if not hasCourse(code) {
    return h + emptyHtml(L.name + " has no lessons yet", "Practice draws from finished lessons, so there's nothing to practise here yet.") + "</div>"
  }
  let done = lessonsDone(code)
  let due = dueCount(code)
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>Quick learn</h2><span class='small muted'>Mixed review of what you've learned</span></div>"
  if done == 0 {
    h += "<div class='card flat'>Finish a lesson first. Quick learn mixes questions from lessons you've completed.</div>"
  } else {
    h += "<div class='tiles'>"
    for each m in goalChoices {
      h += "<button class='card' data-act='go:quick' data-arg='" + code + ":" + m + "'><div class='stat'><div class='v'>" + m + "</div><div class='l'>minutes</div></div></button>"
    }
    h += "</div>"
  }
  h += "</div><div class='sec'><div class='sechead'><h2 class='h2'>Drills</h2></div><div class='grid'>"
  h += practiceTile("Review words", due + " due today. Flashcards scheduled by spaced repetition.", "go:review", code, due > 0)
  h += practiceTile("Vocabulary challenge", "60 seconds, as many meanings as you can. Best: " + kvNum("hi:" + code, 0), "go:challenge", code, wordCount(code) >= 4)
  h += practiceTile("Conversation practice", "Play your part in short scripted dialogues.", "go:one", code + ":convo", done > 0)
  h += practiceTile("Pronunciation", "Say phrases aloud and get a match score.", "go:one", code + ":speak", done > 0)
  h += practiceTile("Listening", "Hear a phrase, pick what it means.", "go:one", code + ":listen", done > 0)
  h += practiceTile("Reading", "Short passages with comprehension.", "go:one", code + ":read", done > 0)
  h += "</div></div></div>"
  return h
}

fn actGo(verb, arg) {
  let bits = split(arg, ":")
  let started = 1
  if verb == "lesson" {
    startLesson(bits[0], bits[1])
  } else if verb == "quick" {
    started = startQuick(bits[0], number(bits[1]))
  } else if verb == "review" {
    started = startReview(bits[0])
  } else if verb == "challenge" {
    started = startChallenge(bits[0])
  } else if verb == "one" {
    started = startOne(bits[0], "", bits[1])
  }
  if started == 0 {
    render()
  }
}
