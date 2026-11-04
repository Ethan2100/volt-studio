// =====================================================================
// POLYGLOT - ui/shell.volt
// The frame around every screen: sidebar (bottom bar on phones), the
// router, and small reusable component builders. A "screen" is just a
// Volt function that returns an HTML string; render() wraps it.
// =====================================================================

let navIds = ["dashboard", "languages", "paths", "practice", "vocabulary", "tutor", "stats", "settings"]
let navNames = ["Dashboard", "My Languages", "Learning Paths", "Practice", "Vocabulary", "AI Tutor", "Statistics", "Settings"]
let navGlyphs = ["▦", "◎", "↗", "✎", "Aa", "✺", "▥", "⚙"]
let navShort = ["Home", "Languages", "Paths", "Practice", "Words", "Tutor", "Stats", "Settings"]

let route = "dashboard"

// ---- reusable components ------------------------------------------------
fn statCard(label, value) {
  return "<div class='card stat'><div class='v'>" + value + "</div><div class='l'>" + label + "</div></div>"
}

fn barHtml(percent) {
  return "<div class='bar'><i style='width:" + percent + "%'></i></div>"
}

fn ringHtml(percent, label) {
  return "<div class='ring' style='--p:" + percent + "'><span>" + label + "</span></div>"
}

fn emptyHtml(heading, body) {
  return "<div class='empty'><b>" + heading + "</b>" + body + "</div>"
}

// Honest "this part isn't built yet" panel, used for screens that arrive in a later stage.
fn screenSoon(heading, what) {
  let h = "<div class='eyebrow'>Under construction</div><h1 class='h1'>" + heading + "</h1>"
  h += "<p class='lede'>" + what + "</p>"
  return h
}

// ---- the frame --------------------------------------------------------------
fn shellSidebar() {
  let h = "<aside class='side'><div class='brand'><span class='mark'>P</span>Polyglot</div><nav class='nav'>"
  let i = 0
  while i < length(navIds) {
    let cls = "navbtn"
    let cur = ""
    if navIds[i] == route {
      cls = "navbtn on"
      cur = " aria-current='page'"
    }
    h += "<button class='" + cls + "' data-act='nav:" + navIds[i] + "'" + cur + "><span class='g'>" + navGlyphs[i] + "</span><span class='lbl'>" + navNames[i] + "</span><span class='sh'>" + navShort[i] + "</span></button>"
    i += 1
  }
  h += "</nav><div class='sidefoot'>"
  let langs = activeLangs()
  if length(langs) > 0 {
    h += "<div class='eyebrow'>Studying</div><div class='studying'>"
    for each code in langs {
      let sel = ""
      if code == currentLang() {
        sel = " on"
      }
      h += "<button class='chip lc" + sel + "' style='--h:" + langOf(code).hue + "' data-act='lang:switch' data-arg='" + code + "' title='Switch to " + langOf(code).name + "'>" + langOf(code).glyph + " " + langOf(code).name + "</button>"
    }
    h += "</div>"
  }
  h += "<button class='btn ghost sm' data-act='set:themeflip'>Theme: " + getSetting("theme", "auto") + "</button>"
  h += "</div></aside>"
  return h
}

fn screenBody() {
  if route == "dashboard" {
    return screenDashboard()
  }
  if route == "settings" {
    return screenSettings()
  }
  if route == "languages" {
    return screenLanguages()
  }
  if route == "paths" {
    return screenPaths()
  }
  if route == "practice" {
    return screenPractice()
  }
  if route == "vocabulary" {
    return screenVocabulary()
  }
  if route == "tutor" {
    return screenTutor()
  }
  if route == "stats" {
    return screenStats()
  }
  return screenSoon("Not found", "That page doesn't exist.")
}

fn render() {
  clear
  if sessionActive == 1 {
    html screenSession()
    scrollTop()
    return 0
  }
  let h = "<div class='app'>" + shellSidebar() + "<main class='main'>"
  h += "<div class='mtop'><div class='brand'><span class='mark'>P</span>Polyglot</div><button class='btn ghost sm' data-act='set:themeflip'>Theme</button></div>"
  h += "<div class='screen'>" + screenBody() + "</div></main></div>"
  html h
  scrollTop()
}

fn go(name) {
  route = name
  render()
}
