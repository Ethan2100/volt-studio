// Lingo Quest - a language learning app written in Volt.
//
// Pick a language (Spanish, French, Japanese or Swahili), then learn it in
// short lessons: meet the words, answer 8 questions (pick the meaning, pick
// the word, listen, then type it), and watch your XP and streak grow.
// Words you get right move up a level; words you miss slide back down, so
// "Review weak words" always practises what you need most.
//
// Everything is saved in the browser (localStorage), so progress stays when
// you come back. Tap a speaker button to hear a word - that uses the
// browser's built-in voices, so how good it sounds depends on your device.
//
// Keys: 1-4 pick an answer, Enter checks / continues.
#html

## body { background: #0e1220; color: #eef0ff; }
## #volt { max-width: 720px; padding: 18px 16px 60px; }
## #volt button { margin: 0; font-family: inherit; }
## .top { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
## .brand { font-size: 1.35em; font-weight: 800; letter-spacing: 0.01em; }
## .chips { display: flex; gap: 8px; }
## .chip { background: #1b2036; border: 1px solid #2b3150; border-radius: 999px; padding: 5px 12px; font-weight: 700; font-size: 0.9em; white-space: nowrap; }
## .muted { color: #9aa3c7; font-size: 0.9em; }
## .langs { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 16px; }
## button.lang { background: #1b2036; color: #eef0ff; border: 2px solid #2b3150; border-radius: 12px; padding: 9px 14px; font-weight: 700; }
## button.lang.on { border-color: #5eead4; background: #12332f; }
## .hero { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }
## .big { font-size: 1.7em; font-weight: 800; }
## .bar { height: 10px; border-radius: 999px; background: #232845; overflow: hidden; flex: 1; min-width: 60px; }
## .bar i { display: block; height: 100%; background: linear-gradient(90deg, #5eead4, #38bdf8); border-radius: 999px; transition: width 0.3s ease; }
## .units { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 18px; }
## .unit { background: #161a2e; border: 1px solid #262c4a; border-radius: 16px; padding: 14px; display: flex; flex-direction: column; gap: 10px; }
## .uhead { display: flex; align-items: center; gap: 10px; }
## .uicon { font-size: 1.8em; }
## .uname { font-weight: 800; font-size: 1.05em; }
## .uact { display: flex; gap: 8px; }
## button.primary { background: #5eead4; color: #062a26; border-radius: 12px; padding: 11px 18px; font-weight: 800; border: 0; cursor: pointer; }
## button.ghost { background: transparent; color: #eef0ff; border: 2px solid #2b3150; border-radius: 12px; padding: 9px 14px; font-weight: 700; cursor: pointer; }
## button.sm { padding: 5px 11px; }
## #volt button.wide { width: 100%; margin-top: 16px; padding: 14px; font-size: 1.05em; }
## .uact button { flex: 1; }
## .prompt { color: #9aa3c7; font-weight: 700; margin: 22px 0 8px; }
## .word { font-size: 2.3em; font-weight: 800; line-height: 1.2; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
## .roman { font-size: 1em; color: #9aa3c7; font-weight: 600; }
## .word .roman { font-size: 0.45em; }
## button.say { background: #1b2036; border: 2px solid #2b3150; border-radius: 50%; width: 44px; height: 44px; font-size: 1.1em; cursor: pointer; padding: 0; color: #eef0ff; }
## .opts { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 18px; }
## button.opt { background: #161a2e; color: #eef0ff; border: 2px solid #2b3150; border-radius: 14px; padding: 16px 12px; font-size: 1.05em; font-weight: 700; text-align: left; cursor: pointer; display: flex; gap: 10px; align-items: center; }
## button.opt .k { background: #232845; border-radius: 6px; padding: 1px 8px; font-size: 0.8em; color: #9aa3c7; }
## button.opt:hover:not(:disabled) { border-color: #5eead4; }
## button.opt.good { border-color: #4ade80; background: #123222; }
## button.opt.bad { border-color: #f87171; background: #3a1820; }
## button.opt:disabled { cursor: default; color: inherit; }
## .typebox { width: 100%; box-sizing: border-box; font: inherit; font-size: 1.2em; padding: 14px; border-radius: 14px; border: 2px solid #2b3150; background: #161a2e; color: #eef0ff; margin-top: 18px; }
## .typebox:focus { outline: none; border-color: #5eead4; }
## .fb { margin-top: 18px; padding: 14px 16px; border-radius: 14px; font-weight: 700; }
## .fb.good { background: #123222; color: #86efac; }
## .fb.bad { background: #3a1820; color: #fca5a5; }
## .fb small { display: block; color: #cbd0ea; font-weight: 500; margin-top: 4px; }
## .plist { display: flex; flex-direction: column; gap: 8px; margin-top: 14px; }
## .prow { display: flex; align-items: center; gap: 12px; background: #161a2e; border: 1px solid #262c4a; border-radius: 14px; padding: 10px 12px; }
## .prow .pw { flex: 1; font-weight: 800; font-size: 1.1em; }
## .prow .pe { color: #cbd0ea; }
## .flash { margin-top: 18px; min-height: 220px; border-radius: 20px; background: #161a2e; border: 2px solid #2b3150; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; text-align: center; padding: 20px; cursor: pointer; user-select: none; }
## .ftarget { font-size: 2.6em; font-weight: 800; }
## .fenglish { font-size: 2em; font-weight: 800; color: #5eead4; }
## .row { display: flex; gap: 10px; margin-top: 14px; justify-content: center; align-items: center; }
## .row button { flex: 1; }
## .result { text-align: center; margin-top: 30px; }
## .result .trophy { font-size: 4em; }
## .result h2 { margin: 8px 0 4px; font-size: 1.8em; }
## .stats { display: flex; gap: 10px; justify-content: center; margin: 18px 0; flex-wrap: wrap; }
## .stat { background: #161a2e; border: 1px solid #262c4a; border-radius: 14px; padding: 12px 18px; min-width: 90px; }
## .stat b { display: block; font-size: 1.4em; }
## .missed { text-align: left; background: #161a2e; border: 1px solid #262c4a; border-radius: 14px; padding: 12px 16px; margin-top: 8px; }
## @media (max-width: 560px) { .units { grid-template-columns: 1fr; } .word { font-size: 1.9em; } .opts { grid-template-columns: 1fr; } .ftarget { font-size: 2.2em; } }

// ---------------------------------------------------------------------
// The words. One struct per word; `roman` is the reading for Japanese.
// ---------------------------------------------------------------------

Card = type { lang: string, unit: string, target: string, english: string, roman: string }

let deck = []

fn addWord(lng, grp, tgt, eng) {
  add Card { lang: lng, unit: grp, target: tgt, english: eng, roman: "" } to deck
}

fn addJa(grp, tgt, rom, eng) {
  add Card { lang: "ja", unit: grp, target: tgt, english: eng, roman: rom } to deck
}

let langCodes = ["es", "fr", "ja", "sw"]
let langNames = ["Spanish", "French", "Japanese", "Swahili"]
let langFlags = ["🇪🇸", "🇫🇷", "🇯🇵", "🇰🇪"]
let langVoices = ["es-ES", "fr-FR", "ja-JP", "sw-KE"]
let unitNames = ["Basics", "Food", "People", "Places"]
let unitIcons = ["👋", "🍞", "👨‍👩‍👧", "🌍"]

// Spanish
addWord("es", "Basics", "hola", "hello")
addWord("es", "Basics", "adiós", "goodbye")
addWord("es", "Basics", "gracias", "thank you")
addWord("es", "Basics", "por favor", "please")
addWord("es", "Basics", "sí", "yes")
addWord("es", "Basics", "no", "no")
addWord("es", "Food", "agua", "water")
addWord("es", "Food", "pan", "bread")
addWord("es", "Food", "leche", "milk")
addWord("es", "Food", "manzana", "apple")
addWord("es", "Food", "queso", "cheese")
addWord("es", "Food", "café", "coffee")
addWord("es", "People", "madre", "mother")
addWord("es", "People", "padre", "father")
addWord("es", "People", "amigo", "friend")
addWord("es", "People", "niño", "boy")
addWord("es", "People", "niña", "girl")
addWord("es", "People", "familia", "family")
addWord("es", "Places", "casa", "house")
addWord("es", "Places", "escuela", "school")
addWord("es", "Places", "tren", "train")
addWord("es", "Places", "playa", "beach")
addWord("es", "Places", "aeropuerto", "airport")
addWord("es", "Places", "ciudad", "city")

// French
addWord("fr", "Basics", "bonjour", "hello")
addWord("fr", "Basics", "au revoir", "goodbye")
addWord("fr", "Basics", "merci", "thank you")
addWord("fr", "Basics", "s'il vous plaît", "please")
addWord("fr", "Basics", "oui", "yes")
addWord("fr", "Basics", "non", "no")
addWord("fr", "Food", "eau", "water")
addWord("fr", "Food", "pain", "bread")
addWord("fr", "Food", "lait", "milk")
addWord("fr", "Food", "pomme", "apple")
addWord("fr", "Food", "fromage", "cheese")
addWord("fr", "Food", "café", "coffee")
addWord("fr", "People", "mère", "mother")
addWord("fr", "People", "père", "father")
addWord("fr", "People", "ami", "friend")
addWord("fr", "People", "garçon", "boy")
addWord("fr", "People", "fille", "girl")
addWord("fr", "People", "famille", "family")
addWord("fr", "Places", "maison", "house")
addWord("fr", "Places", "école", "school")
addWord("fr", "Places", "train", "train")
addWord("fr", "Places", "plage", "beach")
addWord("fr", "Places", "aéroport", "airport")
addWord("fr", "Places", "ville", "city")

// Japanese (with the reading, so you can type it without a kana keyboard)
addJa("Basics", "こんにちは", "konnichiwa", "hello")
addJa("Basics", "さようなら", "sayounara", "goodbye")
addJa("Basics", "ありがとう", "arigatou", "thank you")
addJa("Basics", "お願いします", "onegaishimasu", "please")
addJa("Basics", "はい", "hai", "yes")
addJa("Basics", "いいえ", "iie", "no")
addJa("Food", "水", "mizu", "water")
addJa("Food", "パン", "pan", "bread")
addJa("Food", "牛乳", "gyuunyuu", "milk")
addJa("Food", "りんご", "ringo", "apple")
addJa("Food", "チーズ", "chiizu", "cheese")
addJa("Food", "コーヒー", "koohii", "coffee")
addJa("People", "母", "haha", "mother")
addJa("People", "父", "chichi", "father")
addJa("People", "友達", "tomodachi", "friend")
addJa("People", "男の子", "otokonoko", "boy")
addJa("People", "女の子", "onnanoko", "girl")
addJa("People", "家族", "kazoku", "family")
addJa("Places", "家", "ie", "house")
addJa("Places", "学校", "gakkou", "school")
addJa("Places", "電車", "densha", "train")
addJa("Places", "ビーチ", "biichi", "beach")
addJa("Places", "空港", "kuukou", "airport")
addJa("Places", "都市", "toshi", "city")

// Swahili
addWord("sw", "Basics", "jambo", "hello")
addWord("sw", "Basics", "kwaheri", "goodbye")
addWord("sw", "Basics", "asante", "thank you")
addWord("sw", "Basics", "tafadhali", "please")
addWord("sw", "Basics", "ndiyo", "yes")
addWord("sw", "Basics", "hapana", "no")
addWord("sw", "Food", "maji", "water")
addWord("sw", "Food", "mkate", "bread")
addWord("sw", "Food", "maziwa", "milk")
addWord("sw", "Food", "tufaha", "apple")
addWord("sw", "Food", "jibini", "cheese")
addWord("sw", "Food", "kahawa", "coffee")
addWord("sw", "People", "mama", "mother")
addWord("sw", "People", "baba", "father")
addWord("sw", "People", "rafiki", "friend")
addWord("sw", "People", "mvulana", "boy")
addWord("sw", "People", "msichana", "girl")
addWord("sw", "People", "familia", "family")
addWord("sw", "Places", "nyumba", "house")
addWord("sw", "Places", "shule", "school")
addWord("sw", "Places", "treni", "train")
addWord("sw", "Places", "ufuo", "beach")
addWord("sw", "Places", "uwanja wa ndege", "airport")
addWord("sw", "Places", "jiji", "city")

// ---------------------------------------------------------------------
// State
// ---------------------------------------------------------------------

let lang = "es"
let xp = 0
let streak = 0
let lastDay = 0
let maxHearts = 3
let lessonLen = 8

let view = "home"          // home, preview, q, result, cards
let mode = "unit"          // unit or review
let unit = ""
let lesson = []            // deck positions for this run
let qi = 0
let hearts = 3
let right = 0
let sessionXp = 0
let missed = []
let qkind = "choose"       // choose, reverse, listen, type
let opts = []
let correctPos = 0
let answered = 0
let picked = -1
let typed = ""
let lastOk = 0
let cardList = []
let ci = 0
let flipped = 0

// ---------------------------------------------------------------------
// Small helpers (the raw # lines are plain JavaScript)
// ---------------------------------------------------------------------

fn load() {
  # try { window.LQ = JSON.parse(localStorage.getItem('lingoquest:v1') || '{}'); } catch (e) { window.LQ = {}; }
  # LQ.lv = LQ.lv || {};
  # xp = LQ.xp || 0;
  # streak = LQ.streak || 0;
  # lastDay = LQ.last || 0;
  # if (LQ.lang) { lang = LQ.lang; }
}

fn save() {
  # LQ.xp = xp; LQ.streak = streak; LQ.last = lastDay; LQ.lang = lang;
  # try { localStorage.setItem('lingoquest:v1', JSON.stringify(LQ)); } catch (e) { }
}

fn levelOf(c) {
  # return (LQ.lv[c.lang + '|' + c.target] || 0);
}

fn setLevel(c, v) {
  # LQ.lv[c.lang + '|' + c.target] = v;
}

fn todayNum() {
  # return Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);
}

fn canSpeak() {
  # return ('speechSynthesis' in window) ? 1 : 0;
}

fn speakWord(phrase, accent) {
  # if ('speechSynthesis' in window) { const u = new SpeechSynthesisUtterance(String(phrase)); u.lang = accent; u.rate = 0.85; speechSynthesis.cancel(); speechSynthesis.speak(u); }
}

fn norm(s) {
  # return String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').normalize('NFC').toLowerCase().replace(/[.,!?¿¡'’"\-]/g, '').replace(/\s+/g, ' ').trim();
}

fn boxValue() {
  # const b = document.getElementById('answerBox'); return b ? b.value : '';
}

fn shuffle(items) {
  let i = length(items) - 1
  while i > 0 {
    let j = random(0, i)
    let tmp = items[i]
    items[i] = items[j]
    items[j] = tmp
    i -= 1
  }
  return items
}

fn posOf(items, value) {
  let i = 0
  while i < length(items) {
    if items[i] == value {
      return i
    }
    i += 1
  }
  return -1
}

fn voiceFor() {
  return langVoices[posOf(langCodes, lang)]
}

fn poolFor(lng, grp) {
  let out = []
  let i = 0
  while i < length(deck) {
    if deck[i].lang == lng and (grp == "" or deck[i].unit == grp) {
      add i to out
    }
    i += 1
  }
  return out
}

fn masteryOf(pool) {
  if length(pool) == 0 {
    return 0
  }
  let total = 0
  for each idx in pool {
    total += levelOf(deck[idx])
  }
  return total * 100 / (4 * length(pool))
}

fn learnedIn(pool) {
  let n = 0
  for each idx in pool {
    if levelOf(deck[idx]) >= 3 {
      n += 1
    }
  }
  return n
}

fn weakest(lng, count) {
  let pool = poolFor(lng, "")
  let out = []
  let want = min(count, length(pool))
  while length(out) < want {
    let best = -1
    let bestScore = 9999
    for each idx in pool {
      if not contains(out, idx) {
        let sc = levelOf(deck[idx]) * 100 + random(0, 99)
        if sc < bestScore {
          bestScore = sc
          best = idx
        }
      }
    }
    add best to out
  }
  return out
}

fn bar(percent) {
  return "<div class='bar'><i style='width:" + percent + "%'></i></div>"
}

fn heartsText() {
  let s = ""
  let i = 0
  while i < maxHearts {
    if i < hearts {
      s += "❤️"
    } else {
      s += "🖤"
    }
    i += 1
  }
  return s
}

fn optLabel(c) {
  if c.roman != "" {
    return c.target + " (" + c.roman + ")"
  }
  return c.target
}

fn kindFor(level) {
  if level <= 0 {
    return "choose"
  }
  if level == 1 {
    return "reverse"
  }
  if level == 2 {
    if canSpeak() == 1 {
      return "listen"
    }
    return "choose"
  }
  return "type"
}

fn touchStreak() {
  let day = todayNum()
  if lastDay == day {
    return 0
  }
  if lastDay == day - 1 {
    streak += 1
  } else {
    streak = 1
  }
  lastDay = day
  save()
}

// ---------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------

fn showHome() {
  view = "home"
  clear
  let li = posOf(langCodes, lang)
  let all = poolFor(lang, "")
  let h = "<div class='top'><div class='brand'>🌍 Lingo Quest</div><div class='chips'>"
  h += "<span class='chip'>🔥 " + streak + "</span><span class='chip'>⭐ " + xp + " XP</span></div></div>"
  h += "<div class='langs'>"
  let i = 0
  while i < length(langCodes) {
    let cls = "lang"
    if langCodes[i] == lang {
      cls = "lang on"
    }
    h += "<button class='" + cls + "' data-act='lang' data-arg='" + langCodes[i] + "'>" + langFlags[i] + " " + langNames[i] + "</button>"
    i += 1
  }
  h += "</div>"
  h += "<div class='hero'><div><div class='big'>" + langNames[li] + "</div>"
  h += "<div class='muted'>" + learnedIn(all) + " of " + length(all) + " words learned</div></div>"
  h += "<button class='primary' data-act='review'>⚡ Review weak words</button></div>"
  h += bar(masteryOf(all))
  h += "<div class='units'>"
  let u = 0
  while u < length(unitNames) {
    let pool = poolFor(lang, unitNames[u])
    h += "<div class='unit'><div class='uhead'><div class='uicon'>" + unitIcons[u] + "</div><div><div class='uname'>" + unitNames[u] + "</div>"
    h += "<div class='muted'>" + learnedIn(pool) + "/" + length(pool) + " learned</div></div></div>"
    h += bar(masteryOf(pool))
    h += "<div class='uact'><button class='primary' data-act='start' data-arg='" + u + "'>Lesson</button>"
    h += "<button class='ghost' data-act='cards' data-arg='" + u + "'>Cards</button></div></div>"
    u += 1
  }
  h += "</div>"
  html h
  # document.title = 'Lingo Quest'; window.scrollTo(0, 0);
}

fn showPreview() {
  view = "preview"
  clear
  let u = posOf(unitNames, unit)
  let h = "<div class='top'><button class='ghost sm' data-act='home'>✕</button><div class='chips'><span class='chip'>" + langFlags[posOf(langCodes, lang)] + " " + langNames[posOf(langCodes, lang)] + "</span></div></div>"
  h += "<div class='big'>" + unitIcons[u] + " " + unit + "</div>"
  h += "<div class='muted'>Meet the words first. Tap a speaker to hear one.</div><div class='plist'>"
  for each idx in poolFor(lang, unit) {
    let c = deck[idx]
    h += "<div class='prow'><button class='say' data-act='say' data-arg='" + idx + "'>🔊</button><div class='pw'>" + c.target
    if c.roman != "" {
      h += " <span class='muted'>" + c.roman + "</span>"
    }
    h += "</div><div class='pe'>" + c.english + "</div></div>"
  }
  h += "</div><button class='primary wide' data-act='begin'>Start lesson →</button>"
  html h
  # window.scrollTo(0, 0);
}

fn buildOptions(c, forward) {
  opts = []
  let correct = ""
  if forward == 1 {
    correct = c.english
  } else {
    correct = optLabel(c)
  }
  add correct to opts
  let tries = 0
  while length(opts) < 4 and tries < 100 {
    let d = deck[random(0, length(deck) - 1)]
    if d.lang == lang {
      let s = ""
      if forward == 1 {
        s = d.english
      } else {
        s = optLabel(d)
      }
      if not contains(opts, s) {
        add s to opts
      }
    }
    tries += 1
  }
  opts = shuffle(opts)
  correctPos = posOf(opts, correct)
}

fn showQuestion() {
  view = "q"
  let idx = lesson[qi]
  let c = deck[idx]
  qkind = kindFor(levelOf(c))
  answered = 0
  picked = -1
  typed = ""
  if qkind == "choose" or qkind == "listen" {
    buildOptions(c, 1)
  }
  if qkind == "reverse" {
    buildOptions(c, 0)
  }
  renderQuestion()
  if qkind == "listen" {
    speakWord(c.target, voiceFor())
  }
}

fn renderQuestion() {
  clear
  let c = deck[lesson[qi]]
  let li = posOf(langCodes, lang)
  let h = "<div class='top'><button class='ghost sm' data-act='home'>✕</button>" + bar(qi * 100 / length(lesson))
  h += "<span class='chip'>" + heartsText() + "</span></div>"

  if qkind == "choose" {
    h += "<div class='prompt'>What does this mean?</div>"
    h += "<div class='word'>" + c.target + "<button class='say' data-act='say' data-arg='" + lesson[qi] + "'>🔊</button></div>"
    if c.roman != "" {
      h += "<div class='roman'>" + c.roman + "</div>"
    }
  }
  if qkind == "reverse" {
    h += "<div class='prompt'>How do you say this in " + langNames[li] + "?</div>"
    h += "<div class='word'>" + c.english + "</div>"
  }
  if qkind == "listen" {
    h += "<div class='prompt'>Tap what you hear</div>"
    h += "<div class='word'><button class='say' data-act='say' data-arg='" + lesson[qi] + "'>🔊</button></div>"
  }
  if qkind == "type" {
    h += "<div class='prompt'>Type it in " + langNames[li] + "</div>"
    h += "<div class='word'>" + c.english + "</div>"
    if c.roman != "" {
      h += "<div class='muted'>Kana or romaji both work.</div>"
    }
    let dis = ""
    if answered == 1 {
      dis = " disabled"
    }
    h += "<input id='answerBox' class='typebox' autocomplete='off' autocapitalize='off' spellcheck='false' placeholder='Type your answer' value='" + typed + "'" + dis + ">"
    if answered == 0 {
      h += "<button class='primary wide' data-act='check'>Check</button>"
    }
  } else {
    h += "<div class='opts'>"
    let i = 0
    while i < length(opts) {
      let cls = "opt"
      let attrs = " data-act='pick' data-arg='" + i + "'"
      if answered == 1 {
        attrs = " disabled"
        if i == correctPos {
          cls = "opt good"
        } else if i == picked {
          cls = "opt bad"
        }
      }
      h += "<button class='" + cls + "'" + attrs + "><span class='k'>" + (i + 1) + "</span>" + opts[i] + "</button>"
      i += 1
    }
    h += "</div>"
  }

  if answered == 1 {
    if lastOk == 1 {
      h += "<div class='fb good'>✅ Correct! +10 XP<small>" + optLabel(c) + " = " + c.english + "</small></div>"
    } else {
      h += "<div class='fb bad'>❌ Not quite<small>" + optLabel(c) + " = " + c.english + "</small></div>"
    }
    h += "<button class='primary wide' data-act='next'>Continue</button>"
  }
  html h
  if qkind == "type" and answered == 0 {
    # setTimeout(() => { const b = document.getElementById('answerBox'); if (b) { b.focus(); } }, 30);
  }
}

fn grade(ok) {
  let idx = lesson[qi]
  let c = deck[idx]
  let lv = levelOf(c)
  lastOk = ok
  if ok == 1 {
    setLevel(c, min(lv + 1, 4))
    right += 1
    sessionXp += 10
  } else {
    setLevel(c, max(lv - 1, 0))
    hearts -= 1
    if not contains(missed, idx) {
      add idx to missed
    }
  }
  save()
  renderQuestion()
  if ok == 1 and qkind != "listen" {
    speakWord(c.target, voiceFor())
  }
}

fn pickAnswer(pos) {
  if view != "q" or answered == 1 or qkind == "type" or pos >= length(opts) {
    return 0
  }
  picked = pos
  answered = 1
  if pos == correctPos {
    grade(1)
  } else {
    grade(0)
  }
}

fn checkTyped(guess) {
  if view != "q" or qkind != "type" {
    return 0
  }
  if answered == 1 {
    nextStep()
    return 0
  }
  if norm(guess) == "" {
    return 0
  }
  let c = deck[lesson[qi]]
  typed = guess
  answered = 1
  let ok = 0
  if norm(guess) == norm(c.target) {
    ok = 1
  }
  if c.roman != "" and norm(guess) == norm(c.roman) {
    ok = 1
  }
  grade(ok)
}

fn nextStep() {
  if view == "preview" {
    showQuestion()
    return 0
  }
  if view != "q" or answered == 0 {
    return 0
  }
  if hearts <= 0 {
    showResult(0)
    return 0
  }
  qi += 1
  if qi >= length(lesson) {
    showResult(1)
  } else {
    showQuestion()
  }
}

fn showResult(won) {
  view = "result"
  clear
  let gained = sessionXp
  if won == 1 and length(missed) == 0 {
    gained += 5
  }
  xp += gained
  touchStreak()
  save()
  let h = "<div class='result'>"
  if won == 1 {
    h += "<div class='trophy'>🎉</div><h2>Lesson complete!</h2>"
    if length(missed) == 0 {
      h += "<div class='muted'>Perfect run - bonus +5 XP</div>"
    }
  } else {
    h += "<div class='trophy'>💔</div><h2>Out of hearts</h2><div class='muted'>No worries - the missed words are now first in line for review.</div>"
  }
  h += "<div class='stats'><div class='stat'><b>" + right + "</b>correct</div><div class='stat'><b>+" + gained + "</b>XP</div><div class='stat'><b>🔥 " + streak + "</b>day streak</div></div>"
  if length(missed) > 0 {
    h += "<div class='missed'><b>Words to practise</b>"
    for each idx in missed {
      h += "<div class='prow' style='margin-top:8px'><button class='say' data-act='say' data-arg='" + idx + "'>🔊</button><div class='pw'>" + optLabel(deck[idx]) + "</div><div class='pe'>" + deck[idx].english + "</div></div>"
    }
    h += "</div>"
  }
  h += "<button class='primary wide' data-act='again'>Practise again</button>"
  h += "<button class='ghost wide' data-act='home'>Back to home</button></div>"
  html h
  # window.scrollTo(0, 0);
}

fn resetRun() {
  qi = 0
  hearts = maxHearts
  right = 0
  sessionXp = 0
  missed = []
}

fn buildLesson(grp) {
  unit = grp
  mode = "unit"
  let pool = shuffle(poolFor(lang, grp))
  lesson = []
  let n = 0
  while n < lessonLen {
    add pool[n % length(pool)] to lesson
    n += 1
  }
  resetRun()
}

fn buildReview() {
  mode = "review"
  unit = ""
  lesson = shuffle(weakest(lang, lessonLen))
  resetRun()
}

// Flashcards -----------------------------------------------------------

fn showCard() {
  view = "cards"
  clear
  let c = deck[cardList[ci]]
  let h = "<div class='top'><button class='ghost sm' data-act='home'>✕</button>" + bar(ci * 100 / length(cardList))
  h += "<span class='chip'>" + (ci + 1) + "/" + length(cardList) + "</span></div>"
  h += "<div class='flash' data-act='flip'>"
  if flipped == 0 {
    h += "<div class='ftarget'>" + c.target + "</div>"
    if c.roman != "" {
      h += "<div class='roman'>" + c.roman + "</div>"
    }
    h += "<div class='muted'>Tap the card to see the meaning</div>"
  } else {
    h += "<div class='fenglish'>" + c.english + "</div><div class='muted'>" + optLabel(c) + "</div>"
  }
  h += "</div><div class='row'><button class='say' data-act='say' data-arg='" + cardList[ci] + "'>🔊</button>"
  if flipped == 1 {
    h += "<button class='ghost' data-act='cardAgain'>Again</button><button class='primary' data-act='cardGood'>Got it</button>"
  }
  h += "</div>"
  html h
}

fn cardDone(good) {
  let idx = cardList[ci]
  let c = deck[idx]
  let lv = levelOf(c)
  if good == 1 {
    setLevel(c, min(lv + 1, 4))
    xp += 2
  } else {
    setLevel(c, max(lv - 1, 0))
    add idx to cardList
  }
  save()
  flipped = 0
  ci += 1
  if ci >= length(cardList) {
    touchStreak()
    showHome()
  } else {
    showCard()
  }
}

// ---------------------------------------------------------------------
// One place that handles every tap and key
// ---------------------------------------------------------------------

fn act(cmd, arg) {
  if cmd == "lang" {
    lang = arg
    save()
    showHome()
  } else if cmd == "home" {
    showHome()
  } else if cmd == "start" {
    buildLesson(unitNames[number(arg)])
    showPreview()
  } else if cmd == "begin" {
    showQuestion()
  } else if cmd == "review" {
    buildReview()
    showQuestion()
  } else if cmd == "again" {
    if mode == "review" {
      buildReview()
    } else {
      buildLesson(unit)
    }
    showQuestion()
  } else if cmd == "pick" {
    pickAnswer(number(arg))
  } else if cmd == "check" {
    checkTyped(boxValue())
  } else if cmd == "submit" {
    checkTyped(arg)
  } else if cmd == "next" {
    nextStep()
  } else if cmd == "say" {
    speakWord(deck[number(arg)].target, voiceFor())
  } else if cmd == "cards" {
    unit = unitNames[number(arg)]
    cardList = shuffle(poolFor(lang, unit))
    ci = 0
    flipped = 0
    showCard()
  } else if cmd == "flip" {
    flipped = 1 - flipped
    showCard()
  } else if cmd == "cardGood" {
    cardDone(1)
  } else if cmd == "cardAgain" {
    cardDone(0)
  }
}

fn enterKey() {
  if view == "preview" or (view == "q" and answered == 1) {
    nextStep()
  }
}

// Taps on anything with data-act, and Enter inside the typing box
# document.addEventListener('click', (e) => { const t = e.target.closest('[data-act]'); if (t && !t.disabled) { act(t.dataset.act, t.dataset.arg || '').catch(__error); } });
# document.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target && e.target.id === 'answerBox') { e.preventDefault(); act('submit', e.target.value).catch(__error); } });

when key "1" pressed {
  act("pick", "0")
}
when key "2" pressed {
  act("pick", "1")
}
when key "3" pressed {
  act("pick", "2")
}
when key "4" pressed {
  act("pick", "3")
}
when key "enter" pressed {
  enterKey()
}

// Go!
load()
showHome()
