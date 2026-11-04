// =====================================================================
// POLYGLOT - ui/settings_screen.volt
// Appearance, a daily goal and weekly schedule for each active
// language, and a two-step "erase everything" control.
// =====================================================================

let resetArmed = 0
let dataMsg = ""
let dataGood = 0

fn segHtml(items, labels, current, cmd) {
  let h = "<div class='seg'>"
  let i = 0
  while i < length(items) {
    let sel = ""
    if items[i] == current {
      sel = " class='on'"
    }
    h += "<button" + sel + " data-act='" + cmd + "' data-arg='" + items[i] + "'>" + labels[i] + "</button>"
    i += 1
  }
  h += "</div>"
  return h
}

fn languageSettings(code) {
  let L = langOf(code)
  let h = "<div class='card lc' style='--h:" + L.hue + "'><div class='row wrap'>" + stampHtml(code, 1) + "<div class='h2 sp'>" + L.name + "</div>"
  let labels = []
  let values = []
  for each g in goalChoices {
    add g + " min" to labels
    add code + ":" + g to values
  }
  h += segHtml(values, labels, code + ":" + goalFor(code), "set:goal")
  h += "</div><div class='row wrap' style='margin-top:14px'><span class='muted small'>Study days</span>"
  let i = 0
  while i < 7 {
    let sel = ""
    if dayOn(code, i) {
      sel = " on"
    }
    h += "<button class='day" + sel + "' data-act='set:day' data-arg='" + code + ":" + i + "'>" + dayLetters[i] + "</button>"
    i += 1
  }
  h += "</div></div>"
  return h
}

fn screenSettings() {
  let h = "<div class='eyebrow'>Preferences</div><h1 class='h1'>Settings</h1>"
  h += "<div class='sec'><h2 class='h2' style='margin-bottom:12px'>Appearance</h2><div class='card'><div class='row wrap'><div class='sp'><b>Theme</b><div class='muted small'>Auto follows your device.</div></div>"
  h += segHtml(["auto", "light", "dark"], ["Auto", "Light", "Dark"], getSetting("theme", "auto"), "set:theme") + "</div></div></div>"

  h += "<div class='sec'><h2 class='h2' style='margin-bottom:4px'>Goals and schedule</h2><p class='lede' style='margin-bottom:12px'>Each language has its own daily goal and its own study days. On rest days it won't ask for a goal.</p>"
  let langs = activeLangs()
  if length(langs) == 0 {
    h += emptyHtml("No active languages", "Choose languages in My Languages first.")
  } else {
    h += "<div class='stack'>"
    for each code in langs {
      h += languageSettings(code)
    }
    h += "</div>"
  }
  h += "</div>"

  h += "<div class='sec'><h2 class='h2' style='margin-bottom:12px'>Your data</h2><div class='card'><div class='row wrap'><div class='sp'><b>Stored on this device</b><div class='muted small'>Progress lives in this browser only. Clearing site data erases it.</div></div>"
  if resetArmed == 1 {
    h += "<button class='btn danger sm' data-act='set:resetgo'>Yes, erase everything</button><button class='btn ghost sm' data-act='set:resetcancel'>Cancel</button>"
  } else {
    h += "<button class='btn danger sm' data-act='set:reset'>Reset all progress</button>"
  }
  h += "</div></div>"
  h += "<div class='card' style='margin-top:12px'><div class='row wrap'><div class='sp'><b>Backup</b><div class='muted small'>Save your progress to a file, or restore it on another device or browser. Restoring replaces what is here now.</div></div><button class='btn ghost sm' data-act='set:export'>Export backup</button><label class='btn ghost sm' style='cursor:pointer'>Import backup<input id='bkfile' type='file' accept='.json,application/json' style='display:none'></label></div>"
  if dataMsg != "" {
    let col = "var(--bad)"
    if dataGood == 1 {
      col = "var(--good)"
    }
    h += "<div class='small' style='margin-top:10px;color:" + col + "'>" + esc(dataMsg) + "</div>"
  }
  h += "</div></div>"
  return h
}
