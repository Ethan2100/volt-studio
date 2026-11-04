// =====================================================================
// POLYGLOT - ui/paths.volt
// Learning Paths: the CEFR ladder for the chosen language, with units
// and lessons. Languages without written content say so honestly.
// =====================================================================

fn pathLangTabs() {
  let h = "<div class='row wrap' style='margin:18px 0 6px'>"
  for each code in activeLangs() {
    let sel = ""
    if code == currentLang() {
      sel = " on"
    }
    h += "<button class='chip lc" + sel + "' style='--h:" + langOf(code).hue + "' data-act='lang:switch' data-arg='" + code + "'>" + langOf(code).glyph + " " + langOf(code).name + "</button>"
  }
  return h + "</div>"
}

fn lessonRow(i) {
  let les = lessonList[i]
  let sc = lessonScore(les.lang, les.lid)
  let nx = nextLessonPos(les.lang)
  let badge = "<span class='chip'>Start</span>"
  if sc >= 0 {
    badge = "<span class='chip good'>✓ " + sc + "%</span>"
  } else if i == nx {
    badge = "<span class='chip on'>Up next</span>"
  }
  let h = "<button class='card flat lessonrow' style='width:100%' data-act='go:lesson' data-arg='" + les.lang + ":" + les.lid + "'><div class='row'><div class='stamp sm'>" + les.num + "</div><div class='sp'><b>" + esc(les.title) + "</b><div class='small muted'>" + esc(les.goal) + " · " + les.minutes + " min</div></div>" + badge + "</div></button>"
  return h
}

fn screenPaths() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>Structured courses</div><h1 class='h1'>Learning Paths</h1><p class='lede'>Each lesson teaches words, explains the grammar behind them, then practises with exercises that tell you why an answer is right.</p>"
  if length(langs) == 0 {
    return h + "<div style='margin-top:24px'>" + emptyHtml("Pick a language first", "Paths appear for the languages you study.<div style='margin-top:14px'><button class='btn primary' data-act='nav:languages'>Choose languages</button></div>") + "</div>"
  }
  h += pathLangTabs()
  let code = currentLang()
  let L = langOf(code)
  h += "<div class='lc' style='--h:" + L.hue + "'>"
  if not hasCourse(code) {
    h += "<div style='margin-top:18px'>" + emptyHtml(L.name + " lessons aren't written yet", "The course content for " + L.name + " hasn't been authored. You can still add words to your notebook and review them in Vocabulary.") + "</div></div>"
    return h
  }
  let total = lessonCount(code)
  let doneN = lessonsDone(code)
  h += "<div class='card' style='margin-top:18px'><div class='row'>" + stampHtml(code, 0) + "<div class='sp'><div class='h2'>" + L.name + "</div><div class='small muted'>" + doneN + " of " + total + " lessons finished</div></div></div><div style='margin-top:14px'>" + barHtml(pct(doneN, total)) + "</div>"
  let nx = nextLessonPos(code)
  if nx >= 0 {
    h += "<div style='margin-top:14px'><button class='btn acc' data-act='go:lesson' data-arg='" + code + ":" + lessonList[nx].lid + "'>Continue: " + esc(lessonList[nx].title) + "</button></div>"
  }
  h += "</div>"
  for each lv in cefrLevels {
    let idx = lessonsAtLevel(code, lv)
    if length(idx) > 0 {
      h += "<div class='sec'><div class='sechead'><h2 class='h2'>" + lv + " · " + cefrNames[posOf(cefrLevels, lv)] + "</h2></div><div class='stack'>"
      let unitSeen = ""
      for each i in idx {
        if lessonList[i].unit != unitSeen {
          unitSeen = lessonList[i].unit
          h += "<div class='eyebrow' style='margin-top:6px'>Unit: " + esc(unitSeen) + "</div>"
        }
        h += lessonRow(i)
      }
      h += "</div></div>"
    }
  }
  h += "</div>"
  return h
}
