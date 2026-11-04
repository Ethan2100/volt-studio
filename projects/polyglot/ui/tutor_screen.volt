// =====================================================================
// POLYGLOT - ui/tutor_screen.volt
// The AI Tutor: pick a kind of help, write a message, read the reply.
// If no tutor server is configured the screen explains how to set one up.
// =====================================================================

let tChat = []
let tTask = "explain"
let tBusy = 0
let tNote = ""
let tNoteGood = 0

fn paragraphs(s) {
  return join(split(esc(s), "\n"), "<br>")
}

fn setupPanel() {
  let h = "<div class='card'><div class='h2'>Connect a tutor server</div><p class='muted' style='margin:6px 0 14px'>The tutor needs a small server that holds your Anthropic API key (a browser page can't keep a key secret). Polyglot includes one, written in Volt. Nothing is simulated here: until a server is connected, the tutor stays off.</p>"
  h += "<ol class='small' style='margin:0 0 14px 18px;padding:0;line-height:1.8'><li>Get an API key from the Anthropic Console.</li><li>Run <code>ANTHROPIC_API_KEY=your-key node compiler/volt.js projects/polyglot/server/tutor-server.volt</code>, then <code>node projects/polyglot/server/tutor-server/tutor-server.js</code>. Or deploy that file to a Node host such as Render and set the same environment variable.</li><li>Paste the server's address below, ending in <code>/api/tutor</code>.</li></ol>"
  h += endpointForm()
  return h + "</div>"
}

fn endpointForm() {
  let h = "<div class='row wrap'><input id='tep' class='field sp' style='min-width:220px' placeholder='https://your-server.onrender.com/api/tutor' value='" + esc(tutorEndpoint()) + "' autocomplete='off'><button class='btn acc' data-act='tutor:save'>Save</button>"
  if tutorReady() {
    h += "<button class='btn ghost' data-act='tutor:test'>Test connection</button><button class='btn ghost' data-act='tutor:forget'>Disconnect</button>"
  }
  h += "</div>"
  if tNote != "" {
    let col = "var(--bad)"
    if tNoteGood == 1 {
      col = "var(--good)"
    }
    h += "<div class='small' style='margin-top:10px;color:" + col + "'>" + esc(tNote) + "</div>"
  }
  return h
}

fn chatHtml() {
  let h = ""
  for each line in tChat {
    let at = indexOfBar(line)
    let who = part(line, 0, at)
    let body = part(line, at + 1, length(line))
    if who == "me" {
      h += "<div class='bubble me'>" + paragraphs(body) + "</div>"
    } else if who == "ai" {
      h += "<div class='bubble'>" + paragraphs(body) + "<small>AI tutor · can make mistakes, check anything important</small></div>"
    } else {
      h += "<div class='bubble' style='border-color:var(--bad);color:var(--bad)'>" + paragraphs(body) + "</div>"
    }
  }
  if tBusy == 1 {
    h += "<div class='bubble muted'>Thinking…</div>"
  }
  return h
}

fn indexOfBar(s) {
  let i = 0
  while i < length(s) {
    if part(s, i, i + 1) == "|" {
      return i
    }
    i += 1
  }
  return 0
}

fn screenTutor() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>Ask anything</div><h1 class='h1'>AI Tutor</h1><p class='lede'>Grammar explanations, corrections, conversation practice and study advice from an AI model. It is a helper, not a teacher, so it can be wrong.</p>"
  if length(langs) == 0 {
    return h + "<div style='margin-top:24px'>" + emptyHtml("Pick a language first", "The tutor helps with the languages you study.<div style='margin-top:14px'><button class='btn primary' data-act='nav:languages'>Choose languages</button></div>") + "</div>"
  }
  h += pathLangTabs()
  if not tutorReady() {
    return h + "<div style='margin-top:18px'>" + setupPanel() + "</div>"
  }
  let code = currentLang()
  h += "<div class='lc' style='--h:" + langOf(code).hue + "'><div class='row wrap' style='margin:14px 0'>"
  let i = 0
  while i < length(tutorTaskIds) {
    let cls = "chip"
    if tutorTaskIds[i] == tTask {
      cls = "chip on"
    }
    h += "<button class='" + cls + "' data-act='tutor:task' data-arg='" + tutorTaskIds[i] + "'>" + tutorTaskNames[i] + "</button>"
    i += 1
  }
  h += "</div><div class='small muted' style='margin-bottom:10px'>" + tutorTaskHints[posOf(tutorTaskIds, tTask)] + "</div>"
  h += "<div class='card flat' style='min-height:120px'>" + chatHtml()
  if length(tChat) == 0 and tBusy == 0 {
    h += "<div class='muted'>Nothing yet. Write a message below.</div>"
  }
  h += "</div><div style='margin-top:12px'><textarea id='tin' class='field' rows='3' maxlength='1500' placeholder='Write in English or " + langOf(code).name + "'></textarea></div>"
  h += "<div class='row wrap' style='margin-top:10px'><button class='btn acc' data-act='tutor:send'>Send</button><button class='btn ghost' data-act='tutor:clear'>Clear chat</button><span class='sp'></span><details><summary class='small muted' style='cursor:pointer'>Server settings</summary><div style='margin-top:10px;min-width:280px'>" + endpointForm() + "</div></details></div></div>"
  return h
}

fn actTutor(verb, arg) {
  if verb == "task" {
    tTask = arg
  } else if verb == "clear" {
    tChat = []
    tNote = ""
  } else if verb == "save" {
    let url = trimText(inputValue("tep"))
    let problem = checkEndpoint(url)
    if problem != "" {
      tNote = problem
      tNoteGood = 0
    } else {
      putSetting("tutor", url)
      tNote = "Saved."
      tNoteGood = 1
    }
  } else if verb == "forget" {
    putSetting("tutor", "")
    tNote = ""
    tChat = []
  } else if verb == "test" {
    tNote = "Testing…"
    tNoteGood = 1
    render()
    let result = tutorHealth(tutorEndpoint())
    if result == "ok" {
      tNote = "Connected. The server is running and has a key."
      tNoteGood = 1
    } else {
      tNote = result
      tNoteGood = 0
    }
  } else if verb == "send" {
    if tBusy == 1 {
      return 0
    }
    let q = inputValue("tin")
    if trimText(q) == "" and tTask != "recommend" and tTask != "level" {
      tNote = "Write something for the tutor first."
      tNoteGood = 0
      render()
      return 0
    }
    let task = tTask
    let code = currentLang()
    let before = copyList(tChat)
    if trimText(q) != "" {
      add "me|" + trimText(q) to tChat
    }
    tBusy = 1
    tNote = ""
    render()
    let reply = tutorAsk(task, code, q, before)
    tBusy = 0
    if part(reply, 0, 9) == "__error__" {
      add "err|" + part(reply, 10, length(reply)) to tChat
    } else {
      add "ai|" + reply to tChat
    }
    while length(tChat) > 40 {
      remove tChat[0]
    }
  }
  render()
}
