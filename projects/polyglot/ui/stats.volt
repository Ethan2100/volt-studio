// =====================================================================
// POLYGLOT - ui/stats.volt
// Statistics: the last 14 days, how well words are remembered, every
// language side by side, a dashboard for each language, achievements and
// the weekly challenge. Also the recommendation panels used on the home
// screen (what to study next, what to revise).
// =====================================================================

let statLang = ""

fn xpAllOnDay(day) {
  let n = 0
  for each code in langCodes {
    n += xpOnDay(code, day)
  }
  return n
}

fn xpChart() {
  let best = 1
  let d = dayNum() - 13
  while d <= dayNum() {
    best = max(best, xpAllOnDay(d))
    d += 1
  }
  let h = "<div class='chart'>"
  d = dayNum() - 13
  while d <= dayNum() {
    let v = xpAllOnDay(d)
    let hgt = pct(v, best)
    let cls = "col"
    if d == dayNum() {
      cls = "col today"
    }
    h += "<div class='" + cls + "' title='" + v + " XP'><i style='height:" + hgt + "%'></i><span>" + (dayNum() - d) + "</span></div>"
    d += 1
  }
  return h + "</div><div class='small muted' style='margin-top:6px'>XP per day, last 14 days (numbers show days ago; 0 is today).</div>"
}

fn masteryBar(code) {
  let n = 0
  let l = 0
  let f = 0
  let m = 0
  for each wd in vocabWords(code) {
    let st = srsStatus(code, wd)
    if st == "new" {
      n += 1
    } else if st == "learning" {
      l += 1
    } else if st == "familiar" {
      f += 1
    } else {
      m += 1
    }
  }
  let total = max(1, n + l + f + m)
  let h = "<div class='dist'><i style='width:" + pct(m, total) + "%;background:var(--good)'></i><i style='width:" + pct(f, total) + "%;background:var(--acc)'></i><i style='width:" + pct(l, total) + "%;background:var(--brand)'></i></div>"
  h += "<div class='legend'><span><b style='background:var(--good)'></b>Mastered " + m + "</span><span><b style='background:var(--acc)'></b>Familiar " + f + "</span><span><b style='background:var(--brand)'></b>Learning " + l + "</span><span><b style='background:var(--surface2)'></b>New " + n + "</span></div>"
  return h
}

fn challengeCard() {
  let idx = challengeIndex()
  let prog = challengeProgress()
  let target = chTargets[idx]
  let done = prog >= target
  let h = "<div class='card'><div class='row'><div class='sp'><div class='eyebrow'>Weekly challenge</div><div class='h2' style='margin-top:4px'>" + chNames[idx] + "</div><div class='small muted'>"
  if done {
    h += "Completed. A new one starts in " + daysLeftInChallenge() + " day" + plural(daysLeftInChallenge()) + "."
  } else {
    h += min(prog, target) + " of " + target + " · " + daysLeftInChallenge() + " day" + plural(daysLeftInChallenge()) + " left"
  }
  h += "</div></div>" + ringHtml(pct(min(prog, target), target), pct(min(prog, target), target) + "%") + "</div></div>"
  return h
}

fn achievementsGrid() {
  let h = "<div class='badges'>"
  let i = 0
  while i < length(achIds) {
    let got = achUnlocked(achIds[i])
    let cls = "badge locked"
    let mark = "·"
    if got {
      cls = "badge"
      mark = "★"
    }
    h += "<div class='" + cls + "'><span class='ic'>" + mark + "</span><div><b>" + achNames[i] + "</b><small>" + achDescs[i] + "</small></div></div>"
    i += 1
  }
  return h + "</div>"
}

fn langDashboard(code) {
  let L = langOf(code)
  let xp = langXp(code)
  let lvl = levelFor(xp)
  let h = "<div class='card lc' style='--h:" + L.hue + "'><div class='row'>" + stampHtml(code, 0) + "<div class='sp'><div class='h2'>" + L.name + " dashboard</div><div class='small muted'>Level " + lvl + " · " + xp + " XP · " + (xpForLevel(lvl + 1) - xp) + " XP to level " + (lvl + 1) + "</div></div></div>"
  h += "<div style='margin:12px 0'>" + barHtml(pct(xp - xpForLevel(lvl), xpForLevel(lvl + 1) - xpForLevel(lvl))) + "</div>"
  h += "<div class='stats'>" + statCard("lessons done", lessonsDone(code) + "/" + lessonCount(code)) + statCard("words learned", learnedCount(code)) + statCard("minutes studied", kvNum("sect:" + code, 0) / 60) + statCard("today's goal", minutesToday(code) + "/" + goalFor(code)) + "</div>"
  h += "<div style='margin-top:18px'><div class='eyebrow' style='margin-bottom:8px'>How well you remember</div>" + masteryBar(code) + "</div>"
  let weak = weakLessons(code)
  if length(weak) > 0 {
    h += "<div style='margin-top:18px'><div class='eyebrow' style='margin-bottom:8px'>Worth another go</div><div class='row wrap'>"
    for each i in weak {
      h += "<button class='chip' data-act='go:lesson' data-arg='" + code + ":" + lessonList[i].lid + "'>" + esc(lessonList[i].title) + " · " + lessonScore(code, lessonList[i].lid) + "%</button>"
    }
    h += "</div></div>"
  }
  h += "<div style='margin-top:18px'><div class='eyebrow' style='margin-bottom:8px'>Recent activity</div><div class='feed'>"
  let shown = 0
  for each line in recentLog(40) {
    let bits = split(line, "|")
    if bits[1] == code and shown < 5 {
      h += "<div class='item'><div class='sp'>" + bits[2] + "</div><div class='when'>" + dayWord(number(bits[0])) + "</div></div>"
      shown += 1
    }
  }
  if shown == 0 {
    h += "<div class='muted small'>Nothing yet for " + L.name + ".</div>"
  }
  return h + "</div></div></div>"
}

fn screenStats() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>Progress</div><h1 class='h1'>Statistics</h1><p class='lede'>Your effort over time, how well the words are sticking, and how your languages compare.</p>"
  let words = 0
  let lessons = 0
  let secs = 0
  for each code in langCodes {
    words += learnedCount(code)
    lessons += lessonsDone(code)
    secs += kvNum("sect:" + code, 0)
  }
  h += "<div class='stats'>" + statCard("total XP", totalXp()) + statCard("day streak", streakDays()) + statCard("lessons done", lessons) + statCard("hours studied", (secs / 360) / 10 + "." + (secs / 360) % 10) + "</div>"
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>Last 14 days</h2></div><div class='card'>" + xpChart() + "</div></div>"
  h += "<div class='sec'>" + challengeCard() + "</div>"
  if length(langs) == 0 {
    h += "<div class='sec'>" + emptyHtml("No languages yet", "Pick some to see per-language statistics.") + "</div>"
  } else {
    if length(langs) > 1 {
      h += "<div class='sec'><div class='sechead'><h2 class='h2'>Compare languages</h2></div>" + compareTable(langs) + "</div>"
    }
    if statLang == "" or not contains(langs, statLang) {
      statLang = currentLang()
    }
    h += "<div class='sec'><div class='sechead'><h2 class='h2'>Language dashboard</h2></div><div class='row wrap' style='margin-bottom:12px'>"
    for each code in langs {
      let cls = "chip lc"
      if code == statLang {
        cls = "chip lc on"
      }
      h += "<button class='" + cls + "' style='--h:" + langOf(code).hue + "' data-act='stat:lang' data-arg='" + code + "'>" + langOf(code).glyph + " " + langOf(code).name + "</button>"
    }
    h += "</div>" + langDashboard(statLang) + "</div>"
  }
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>Achievements</h2><span class='muted small'>" + achCount() + " of " + length(achIds) + "</span></div>" + achievementsGrid() + "</div>"
  return h
}

// ---- home-screen panels --------------------------------------------------------
fn recommendedPanel(langs) {
  let h = "<div class='grid'>"
  let any = 0
  for each code in langs {
    let nx = nextLessonPos(code)
    if nx >= 0 {
      any += 1
      let les = lessonList[nx]
      h += "<button class='card lc' style='--h:" + langOf(code).hue + "' data-act='go:lesson' data-arg='" + code + ":" + les.lid + "'><div class='row'>" + stampHtml(code, 1) + "<div class='sp'><div class='eyebrow'>" + langOf(code).name + " · " + les.level + "</div><b>" + esc(les.title) + "</b><div class='small muted'>" + les.minutes + " min</div></div></div></button>"
    }
  }
  if any == 0 {
    return ""
  }
  return h + "</div>"
}

fn revisionPanel(langs) {
  let h = ""
  let any = 0
  for each code in langs {
    let due = dueCount(code)
    let weak = weakLessons(code)
    let hard = difficultCount(code)
    if due > 0 or length(weak) > 0 or hard > 0 {
      any += 1
      h += "<div class='card flat lc' style='--h:" + langOf(code).hue + "'><div class='row wrap'>" + stampHtml(code, 1) + "<div class='sp'><b>" + langOf(code).name + "</b><div class='small muted'>"
      if due > 0 {
        h += due + " word" + plural(due) + " due · "
      }
      if hard > 0 {
        h += hard + " difficult · "
      }
      if length(weak) > 0 {
        h += length(weak) + " lesson" + plural(length(weak)) + " to redo"
      }
      h += "</div></div>"
      if due > 0 {
        h += "<button class='btn acc sm' data-act='go:review' data-arg='" + code + "'>Review</button>"
      } else {
        h += "<button class='btn ghost sm' data-act='stat:open' data-arg='" + code + "'>Details</button>"
      }
      h += "</div></div>"
    }
  }
  if any == 0 {
    return ""
  }
  return "<div class='stack'>" + h + "</div>"
}

fn actStat(verb, arg) {
  if verb == "lang" {
    statLang = arg
  } else if verb == "open" {
    statLang = arg
    setCurrent(arg)
    route = "stats"
  }
  render()
}
