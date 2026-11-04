// =====================================================================
// POLYGLOT - ui/languages.volt  (Stage 4: language management)
// Choose which languages you study, see which ones have a written
// course, compare progress between them and plan which languages you
// study on which days of the week.
// =====================================================================

fn weekSeconds(code) {
  let total = 0
  let d = 0
  while d < 7 {
    total += secondsOnDay(code, dayNum() - d)
    d += 1
  }
  return total
}

fn courseChip(code) {
  if hasCourse(code) {
    return "<span class='chip good'>Course available · " + lessonCount(code) + " lessons</span>"
  }
  return "<span class='chip'>Course not written yet</span>"
}

fn langCard(code) {
  let L = langOf(code)
  let h = "<div class='card lc' style='--h:" + L.hue + "'><div class='row'>" + stampHtml(code, 0)
  h += "<div class='sp'><div class='h2'>" + L.name + "</div><div class='muted small'>" + L.endo + "</div></div>"
  if isActive(code) {
    h += "<span class='chip on'>Studying</span>"
  }
  h += "</div><p class='muted small' style='margin:12px 0'>" + L.tagline + "</p>"
  h += "<div class='row wrap' style='margin-bottom:14px'><span class='chip'>" + L.script + "</span>" + courseChip(code) + "</div>"
  if isActive(code) {
    h += "<button class='btn ghost sm' data-act='lang:toggle' data-arg='" + code + "'>Stop studying</button>"
  } else {
    h += "<button class='btn acc sm' data-act='lang:toggle' data-arg='" + code + "'>Start studying</button>"
  }
  h += "</div>"
  return h
}

fn compareTable(langs) {
  let maxXp = 1
  for each code in langs {
    maxXp = max(maxXp, langXp(code))
  }
  let h = "<div class='card'><div class='tblwrap'><table class='tbl'><thead><tr><th>Language</th><th>Level</th><th>XP</th><th>Lessons</th><th>Words learned</th><th>This week</th></tr></thead><tbody>"
  for each code in langs {
    let L = langOf(code)
    h += "<tr class='lc' style='--h:" + L.hue + "'><td><div class='nm'>" + stampHtml(code, 1) + L.name + "</div></td>"
    h += "<td class='num'>" + levelFor(langXp(code)) + "</td>"
    h += "<td style='min-width:130px'><div class='num'>" + langXp(code) + "</div>" + barHtml(pct(langXp(code), maxXp)) + "</td>"
    h += "<td class='num'>" + lessonsDone(code) + " / " + lessonCount(code) + "</td>"
    h += "<td class='num'>" + learnedCount(code) + "</td>"
    h += "<td class='num'>" + minutesText(weekSeconds(code)) + "</td></tr>"
  }
  h += "</tbody></table></div></div>"
  return h
}

fn scheduleGrid(langs) {
  let today = weekdayIndex()
  let h = "<div class='card'><div class='tblwrap'><div class='sched'><span></span>"
  let i = 0
  while i < 7 {
    let cls = "hd"
    if i == today {
      cls = "hd today"
    }
    h += "<span class='" + cls + "'>" + dayLetters[i] + "</span>"
    i += 1
  }
  for each code in langs {
    let L = langOf(code)
    h += "<span class='nm lc' style='--h:" + L.hue + "'>" + stampHtml(code, 1) + " " + L.name + "</span>"
    i = 0
    while i < 7 {
      let sel = ""
      if dayOn(code, i) {
        sel = " on"
      }
      h += "<button class='day lc" + sel + "' style='--h:" + L.hue + "' data-act='set:day' data-arg='" + code + ":" + i + "'>" + dayLetters[i] + "</button>"
      i += 1
    }
  }
  h += "</div></div><p class='muted small' style='margin:12px 0 0'>Tap a day to switch it on or off. Different languages can fall on different days; on a rest day Polyglot won't ask for that language's goal.</p></div>"
  return h
}

fn screenLanguages() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>" + length(langs) + " of " + length(langList) + " active</div><h1 class='h1'>My Languages</h1>"
  h += "<p class='lede'>Study as many languages as you like. Each keeps its own level, goal, schedule and vocabulary.</p>"
  if length(langs) > 0 {
    h += "<div class='sec'><div class='sechead'><h2 class='h2'>Compare progress</h2></div>" + compareTable(langs) + "</div>"
    h += "<div class='sec'><div class='sechead'><h2 class='h2'>Weekly schedule</h2></div>" + scheduleGrid(langs) + "</div>"
  }
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>All languages</h2></div><div class='grid'>"
  for each code in langCodes {
    h += langCard(code)
  }
  h += "</div></div>"
  return h
}
