// =====================================================================
// POLYGLOT - engine/tutor.volt  (AI tutor interface layer)
// Builds the tutor's instructions in Volt and sends them to the tutor
// server (server/tutor-server.volt), whose address is set in Settings.
// There is no built-in or pretend tutor: with no server, the Tutor screen
// explains what is needed and nothing is faked.
// =====================================================================

let tutorTaskIds = ["explain", "correct", "chat", "translate", "recommend", "level"]
let tutorTaskNames = ["Explain grammar", "Correct my sentence", "Practise conversation", "Help me translate", "What should I study?", "Is my level right?"]
let tutorTaskHints = ["Ask about a rule, e.g. “Why is it el agua but una manzana?”", "Write a sentence in your language and get it corrected, with the reason.", "Chat in the language. The tutor replies simply and gently corrects mistakes.", "Paste a phrase and ask what it means or how to say something.", "Get a study suggestion based on your progress. No typing needed.", "Ask whether lessons feel too easy or too hard. Based on your progress."]

fn tutorEndpoint() {
  return getSetting("tutor", "")
}

// An address must be a plain http(s) URL. Returns "" if fine, else a message.
fn checkEndpoint(url) {
  let u = trimText(url)
  if u == "" {
    return "Enter the address of your tutor server."
  }
  if length(u) > 300 {
    return "That address is too long."
  }
  if part(u, 0, 7) != "http://" and part(u, 0, 8) != "https://" {
    return "The address must start with http:// or https://"
  }
  if contains(u, " ") {
    return "The address cannot contain spaces."
  }
  return ""
}

fn tutorReady() {
  return checkEndpoint(tutorEndpoint()) == ""
}

fn tutorContext(lang) {
  let L = langOf(lang)
  let s = "The learner is studying " + L.name + ". "
  if hasCourse(lang) {
    s += "They have finished " + lessonsDone(lang) + " of " + lessonCount(lang) + " beginner (A1) lessons. "
    let weak = weakLessons(lang)
    if length(weak) > 0 {
      s += "Lessons they scored under 75% on: "
      let names = []
      for each i in weak {
        add lessonList[i].title to names
      }
      s += join(names, "; ") + ". "
    }
    let nx = nextLessonPos(lang)
    if nx >= 0 {
      s += "Their next lesson is “" + lessonList[nx].title + "”. "
    }
  } else {
    s += "No structured course exists for this language in the app yet. "
  }
  s += learnedCount(lang) + " words learned, " + dueCount(lang) + " due for review, " + difficultCount(lang) + " difficult. "
  s += "Total XP in this language: " + langXp(lang) + "."
  return s
}

fn tutorSystem(task, lang) {
  let L = langOf(lang)
  let s = "You are a patient, accurate " + L.name + " tutor inside a language-learning app. The learner speaks English and is a beginner (CEFR A1 to A2). "
  s += "Reply in under 150 words. Always explain WHY, not just what. Show " + L.name + " text with its English meaning"
  if L.script != "Latin" and L.script != "" {
    s += " and a romanised reading"
  }
  s += ". If you are not sure about something, say so instead of guessing. Do not claim to be a person. "
  if task == "explain" {
    s += "Task: explain the grammar point the learner asks about, with two short examples."
  } else if task == "correct" {
    s += "Task: the learner writes a sentence in " + L.name + ". Give the corrected sentence first, then a one-line reason for each change. If it is already correct, say so."
  } else if task == "chat" {
    s += "Task: hold a simple conversation in " + L.name + ". Reply in " + L.name + " using easy words, add the English meaning in brackets, then ask a short follow-up question. Gently correct any mistake in the learner's last message."
  } else if task == "translate" {
    s += "Task: translate or explain the phrase the learner gives, and point out anything that is different from English word order or usage."
  } else if task == "recommend" {
    s += "Task: recommend what the learner should do next (a lesson, a review, or a kind of practice) using their progress. Be specific and encouraging, in at most four short sentences."
  } else {
    s += "Task: judge whether the learner's current difficulty seems right from their progress, and suggest whether to slow down, stay, or move faster. Be honest: if there is too little data, say so."
  }
  s += " Learner progress: " + tutorContext(lang)
  return s
}

// Sends the conversation. history: lines "me|text" and "ai|text" (oldest first).
// Returns the tutor's reply, or "__error__:reason".
fn tutorPost(url, system, history) {
  # const ctl = new AbortController(); const timer = setTimeout(() => ctl.abort(), 35000); try { const messages = history.map((l) => ({ role: l.startsWith('me|') ? 'user' : 'assistant', content: l.slice(l.indexOf('|') + 1) })); const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ system: system, messages: messages }), signal: ctl.signal }); clearTimeout(timer); const j = await r.json().catch(() => ({})); if (!r.ok) { return '__error__:' + (j.error || ('The server answered with status ' + r.status + '.')); } return j.reply ? String(j.reply) : '__error__:The tutor sent an empty reply.'; } catch (e) { clearTimeout(timer); return '__error__:' + (e && e.name === 'AbortError' ? 'The tutor took too long to answer.' : 'Could not reach the tutor server. Check the address and that it is running.'); }
}

// Asks the server whether it is up and has a key. Returns "ok" or a message.
fn tutorHealth(url) {
  # try { const base = new URL(url); const r = await fetch(base.origin + '/health'); const j = await r.json(); if (!j.ok) { return 'The server answered, but not like a Polyglot tutor server.'; } return j.configured ? 'ok' : 'The server is running but has no ANTHROPIC_API_KEY set.'; } catch (e) { return 'Could not reach the server.'; }
}

fn tutorAsk(task, lang, userText, chat) {
  let url = tutorEndpoint()
  let problem = checkEndpoint(url)
  if problem != "" {
    return "__error__:Set up the tutor server first (Settings or the setup panel)."
  }
  let q = trimText(userText)
  if q == "" {
    if task == "recommend" {
      q = "What should I study next?"
    } else if task == "level" {
      q = "Is my current level right?"
    } else {
      return "__error__:Write something for the tutor first."
    }
  }
  if length(q) > 1500 {
    return "__error__:That message is too long: keep it under 1500 characters."
  }
  let history = []
  let n = 0
  let start = max(0, length(chat) - 6)
  let i = start
  while i < length(chat) {
    let kind = part(chat[i], 0, 3)
    if kind == "me|" or kind == "ai|" {
      add chat[i] to history
    }
    i += 1
  }
  // the conversation sent to the model must begin with the learner
  while length(history) > 0 and part(history[0], 0, 3) != "me|" {
    remove history[0]
  }
  add "me|" + q to history
  return tutorPost(url, tutorSystem(task, lang), history)
}
