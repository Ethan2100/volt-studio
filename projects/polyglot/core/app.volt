// =====================================================================
// POLYGLOT - core/app.volt
// The application core: ONE place that receives every click and key
// press. Buttons carry data-act="area:verb" and data-arg="..." and
// act() routes them. Modules add their own area as they are built.
// =====================================================================

fn actNav(verb, arg) {
  go(verb)
}

fn actLang(verb, arg) {
  if verb == "switch" {
    setCurrent(arg)
    render()
  } else if verb == "open" {
    setCurrent(arg)
    go("paths")
  } else if verb == "toggle" {
    toggleActive(arg)
    render()
  }
}

fn actSet(verb, arg) {
  if verb == "theme" {
    putSetting("theme", arg)
    applyTheme()
    render()
  } else if verb == "themeflip" {
    putSetting("theme", nextTheme(getSetting("theme", "auto")))
    applyTheme()
    render()
  } else if verb == "goal" {
    let bits = split(arg, ":")
    setGoal(bits[0], number(bits[1]))
    render()
  } else if verb == "day" {
    let bits = split(arg, ":")
    toggleDay(bits[0], number(bits[1]))
    render()
  } else if verb == "export" {
    let dump = kvExport()
    if dump == "" {
      dataMsg = "Couldn't read your data to export it."
      dataGood = 0
    } else {
      downloadText("polyglot-backup-" + dayNum() + ".json", dump)
      dataMsg = "Backup saved to your downloads."
      dataGood = 1
    }
    render()
  } else if verb == "import" {
    dataMsg = kvImport(arg)
    if dataMsg == "" {
      dataMsg = "Backup restored."
      dataGood = 1
      route = "settings"
      applyTheme()
    } else {
      dataGood = 0
    }
    render()
  } else if verb == "reset" {
    resetArmed = 1
    render()
  } else if verb == "resetcancel" {
    resetArmed = 0
    render()
  } else if verb == "resetgo" {
    kvWipe()
    resetArmed = 0
    route = "dashboard"
    applyTheme()
    render()
  }
}

fn actEx(verb, arg) {
  if verb == "pick" {
    if qType[qi] == "ex" and curEx().kind == "convo" {
      convoPick(number(arg))
      render()
    } else {
      gradeChoice(number(arg))
      render()
    }
  } else if verb == "next" {
    if qType[qi] == "ex" or qType[qi] == "flash" {
      itemNext()
    } else {
      qi += 1
      itemBegin()
      render()
    }
  } else if verb == "check" {
    if curEx().kind == "arrange" {
      gradeArrange()
    } else {
      gradeTyped(inputValue("ans"))
    }
    render()
  } else if verb == "typed" {
    gradeTyped(arg)
    render()
  } else if verb == "build" {
    arrangeAdd(number(arg))
    render()
  } else if verb == "unbuild" {
    arrangeRemove(number(arg))
    render()
  } else if verb == "mleft" {
    matchLeftTap(number(arg))
    render()
  } else if verb == "mright" {
    matchRightTap(number(arg))
    render()
  } else if verb == "say" {
    speakText(arg, voiceOf(sessLang))
  } else if verb == "slow" {
    speakText(arg, voiceOf(sessLang))
  } else if verb == "mic" {
    speakAttempt()
  } else if verb == "self" {
    speakSelf(number(arg))
    render()
  } else if verb == "flip" {
    flipped = 1
    render()
  } else if verb == "rate" {
    flashRate(number(arg))
  } else if verb == "leave" {
    if sessStage == "result" {
      closeSession()
    } else {
      leaveArmed = 1
      render()
    }
  } else if verb == "stay" {
    leaveArmed = 0
    render()
  } else if verb == "leaveyes" {
    leaveSession()
  } else if verb == "close" {
    closeSession()
  } else if verb == "startnext" {
    let lang = sessLang
    let nx = nextLessonPos(lang)
    sessionActive = 0
    if nx >= 0 {
      startLesson(lang, lessonList[nx].lid)
    } else {
      render()
    }
  }
}

fn act(cmd, arg) {
  let parts = split(cmd, ":")
  let area = parts[0]
  let verb = ""
  if length(parts) > 1 {
    verb = parts[1]
  }
  if area == "nav" {
    actNav(verb, arg)
  } else if area == "lang" {
    actLang(verb, arg)
  } else if area == "set" {
    actSet(verb, arg)
  } else if area == "ex" {
    actEx(verb, arg)
  } else if area == "vocab" {
    actVocab(verb, arg)
  } else if area == "stat" {
    actStat(verb, arg)
  } else if area == "tutor" {
    actTutor(verb, arg)
  } else if area == "go" {
    actGo(verb, arg)
  }
}

// One listener for every tap on anything with data-act.
# document.addEventListener('keydown', (e) => { const t = e.target; if (e.key === 'Enter') { if (t && t.id === 'ans' && !t.disabled) { act('ex:typed', t.value).catch(__error); } else if (t && t.id === 'vq') { act('vocab:search', '').catch(__error); } else if (!t || t.tagName !== 'INPUT') { const b = document.querySelector('.fbar [data-act="ex:next"]') || document.querySelector('.fbar [data-act="ex:check"]') || document.querySelector('.fbody [data-act="ex:next"]') || document.querySelector('.fbody [data-act="ex:flip"]'); if (b) b.click(); } } else if (/^[1-4]$/.test(e.key) && (!t || t.tagName !== 'INPUT')) { const o = document.querySelector('[data-opt="' + e.key + '"]'); if (o) o.click(); } });
# document.addEventListener('change', (e) => { const t = e.target; if (t && t.id === 'bkfile' && t.files && t.files[0]) { const f = t.files[0]; if (f.size > 2000000) { act('set:import', '{}').catch(__error); return; } const r = new FileReader(); r.onload = () => { act('set:import', String(r.result)).catch(__error); }; r.readAsText(f); } });
# document.addEventListener('click', (e) => { const t = e.target.closest('[data-act]'); if (t && !t.disabled) { act(t.dataset.act, t.dataset.arg || '').catch(__error); } });

every 1000ms {
  tickChallenge()
}

fn boot() {
  # document.title = 'Polyglot';
  applyTheme()
  render()
}
