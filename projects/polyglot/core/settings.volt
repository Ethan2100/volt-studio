// =====================================================================
// POLYGLOT - settings.volt
// Theme, which languages are active, the current language, a daily goal
// and a weekly schedule for each language. Stored through store.volt.
// =====================================================================

let goalChoices = [5, 10, 15, 30]
let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

fn getSetting(key, fallback) {
  return kvGet("s:" + key, fallback)
}

fn putSetting(key, value) {
  return kvSet("s:" + key, value)
}

// ---- theme ------------------------------------------------------------
// "auto" follows the device, "light" and "dark" force a theme.
fn applyTheme() {
  let pref = getSetting("theme", "auto")
  # const dark = (pref === 'dark') || (pref === 'auto' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
  # document.documentElement.dataset.theme = dark ? 'dark' : 'light';
}

fn nextTheme(pref) {
  if pref == "auto" {
    return "light"
  }
  if pref == "light" {
    return "dark"
  }
  return "auto"
}

// ---- active languages -------------------------------------------------------
fn activeLangs() {
  let raw = getSetting("langs", "")
  if raw == "" {
    return []
  }
  return split(raw, ",")
}

fn isActive(code) {
  return contains(activeLangs(), code)
}

// Turns a language on or off. Returns the new on/off state.
fn toggleActive(code) {
  let now = activeLangs()
  let out = []
  let was = 0
  for each c in now {
    if c == code {
      was = 1
    } else {
      add c to out
    }
  }
  if was == 0 {
    add code to out
  }
  putSetting("langs", join(out, ","))
  // keep "current language" pointing at something that is still active
  if was == 1 and currentLang() == code {
    if length(out) > 0 {
      putSetting("cur", out[0])
    } else {
      putSetting("cur", "")
    }
  }
  if was == 0 and (getSetting("cur", "") == "" or not contains(out, getSetting("cur", ""))) {
    putSetting("cur", code)
  }
  return 1 - was
}

fn currentLang() {
  let c = getSetting("cur", "")
  let now = activeLangs()
  if contains(now, c) {
    return c
  }
  if length(now) > 0 {
    return now[0]
  }
  return ""
}

fn setCurrent(code) {
  if isActive(code) {
    putSetting("cur", code)
  }
}

// ---- goals and schedule -------------------------------------------------------
fn goalFor(code) {
  return number(getSetting("goal:" + code, "10"))
}

fn setGoal(code, minutes) {
  if contains(goalChoices, minutes) {
    putSetting("goal:" + code, minutes)
  }
}

// Seven characters, Monday first: "1" = study that day, "0" = rest day.
fn daysFor(code) {
  return getSetting("days:" + code, "1111111")
}

fn dayOn(code, index) {
  return part(daysFor(code), index, 1) == "1"
}

fn toggleDay(code, index) {
  let cur = daysFor(code)
  let out = ""
  let i = 0
  while i < 7 {
    let c = part(cur, i, 1)
    if i == index {
      if c == "1" {
        c = "0"
      } else {
        c = "1"
      }
    }
    out += c
    i += 1
  }
  putSetting("days:" + code, out)
}

fn studyToday(code) {
  return dayOn(code, weekdayIndex())
}
