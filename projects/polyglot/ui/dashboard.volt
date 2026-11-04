// =====================================================================
// POLYGLOT - ui/dashboard.volt
// The home screen: streak, XP, words learned, today's goal for every
// active language, and a feed of recent activity. (Recommended lessons
// and revision areas are added in Stages 5 and 6, when lessons and
// spaced repetition exist to recommend from.)
// =====================================================================

fn goalCard(code) {
  let L = langOf(code)
  let goal = goalFor(code)
  let mins = minutesToday(code)
  let h = "<div class='card lc' style='--h:" + L.hue + "'><div class='row'>" + stampHtml(code, 0)
  h += "<div class='sp'><div class='h2'>" + L.name + "</div><div class='muted small'>" + L.endo + "</div></div>"
  if studyToday(code) {
    h += ringHtml(pct(mins, goal), mins + "/" + goal)
  } else {
    h += "<span class='chip'>Rest day</span>"
  }
  h += "</div><div style='margin:14px 0 4px'>" + barHtml(pct(langXp(code), xpForLevel(levelFor(langXp(code)) + 1))) + "</div>"
  h += "<div class='row small muted'><span>Level " + levelFor(langXp(code)) + "</span><span class='sp'></span><span>" + langXp(code) + " XP</span></div>"
  h += "<div class='row' style='margin-top:14px'><button class='btn acc sm' data-act='lang:open' data-arg='" + code + "'>Open path</button>"
  h += "<span class='muted small'>" + learnedCount(code) + " words learned</span></div></div>"
  return h
}

fn activityFeed() {
  let entries = recentLog(8)
  if length(entries) == 0 {
    return emptyHtml("Nothing yet", "Finish a lesson or review some words and it will show up here.")
  }
  let h = "<div class='card'><div class='feed'>"
  for each line in entries {
    let bits = split(line, "|")
    h += "<div class='item lc' style='--h:" + langOf(bits[1]).hue + "'>" + stampHtml(bits[1], 1) + "<div class='sp'>" + bits[2] + "</div><div class='when'>" + dayWord(number(bits[0])) + "</div></div>"
  }
  h += "</div></div>"
  return h
}

fn screenDashboard() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>" + dateLabel() + "</div><h1 class='h1'>" + greeting() + ".</h1>"
  if length(langs) == 0 {
    h += "<p class='lede'>Polyglot tracks every language you study separately, so you can learn several at once without losing your place in any of them.</p>"
    if storageOk() == 0 {
      h += "<div class='card flat' style='margin-top:24px;border-color:var(--bad);color:var(--bad)'>Your browser is blocking storage, so progress can't be saved this session.</div>"
    }
    h += "<div style='margin-top:26px'>" + emptyHtml("No languages yet", "Pick one or more to begin.<div style='margin-top:16px'><button class='btn primary' data-act='nav:languages'>Choose languages</button></div>") + "</div>"
    return h
  }

  let words = 0
  let mins = 0
  let todays = 0
  for each code in langs {
    words += learnedCount(code)
    mins += minutesToday(code)
    if studyToday(code) {
      todays += 1
    }
  }
  h += "<p class='lede'>"
  if length(langs) == 1 {
    h += "You're studying 1 language."
  } else {
    h += "You're studying " + length(langs) + " languages, " + todays + " scheduled today."
  }
  h += "</p>"
  h += "<div class='stats'>" + statCard("day streak", streakDays()) + statCard("total XP", totalXp()) + statCard("words learned", words) + statCard("minutes today", mins) + "</div>"

  h += "<div class='sec'><div class='sechead'><h2 class='h2'>Today's goals</h2><button class='btn ghost sm' data-act='nav:languages'>Manage languages</button></div><div class='grid'>"
  for each code in langs {
    h += goalCard(code)
  }
  h += "</div></div>"

  let rec = recommendedPanel(langs)
  if rec != "" {
    h += "<div class='sec'><div class='sechead'><h2 class='h2'>Recommended next</h2></div>" + rec + "</div>"
  }
  let rev = revisionPanel(langs)
  if rev != "" {
    h += "<div class='sec'><div class='sechead'><h2 class='h2'>Worth revising</h2></div>" + rev + "</div>"
  }
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>This week</h2><button class='btn ghost sm' data-act='nav:stats'>All statistics</button></div>" + challengeCard() + "</div>"
  h += "<div class='sec'><div class='sechead'><h2 class='h2'>Recent activity</h2></div>" + activityFeed() + "</div>"
  if storageOk() == 0 {
    h += "<div class='card flat' style='margin-top:24px;border-color:var(--bad);color:var(--bad)'>Your browser is blocking storage, so progress can't be saved this session.</div>"
  }
  return h
}
