// =====================================================================
// POLYGLOT - ui/vocabulary.volt
// The word manager: every course word and your own notebook words, with
// status from spaced repetition, filters, search and notebook editing.
// =====================================================================

let vocabFilter = "all"
let vocabCat = ""
let vocabQuery = ""
let vocabMsg = ""
let vocabOpen = ""
let vocabFilters = ["all", "due", "new", "learning", "familiar", "mastered", "difficult"]
let vocabFilterNames = ["All", "Due", "New", "Learning", "Familiar", "Mastered", "Difficult"]

fn notebookWordSet(lang) {
  let out = []
  for each entry in notebookEntries(lang) {
    add split(entry, "|")[0] to out
  }
  return out
}

// Every word for a language: course words first, then the notebook.
fn vocabWords(lang) {
  let out = []
  for each w in wordList {
    if w.lang == lang {
      add w.word to out
    }
  }
  for each wd in notebookWordSet(lang) {
    if not contains(out, wd) {
      add wd to out
    }
  }
  return out
}

fn vocabCats(lang) {
  let out = []
  for each w in wordList {
    if w.lang == lang and not contains(out, w.cat) {
      add w.cat to out
    }
  }
  return out
}

fn isDue(lang, wd) {
  return contains(srsDueWords(lang), wd)
}

fn vocabMatches(lang, wd, due) {
  let w = wordData(lang, wd)
  if vocabCat != "" and w.cat != vocabCat {
    return false
  }
  if vocabQuery != "" {
    let q = norm(vocabQuery)
    if not contains(norm(w.word), q) and not contains(norm(w.meaning), q) and not contains(norm(w.pron), q) {
      return false
    }
  }
  let st = srsStatus(lang, wd)
  if vocabFilter == "due" {
    return contains(due, wd)
  }
  if vocabFilter == "difficult" {
    return srsDifficult(lang, wd)
  }
  if vocabFilter != "all" {
    return st == vocabFilter
  }
  return true
}

fn statusChip(lang, wd) {
  let st = srsStatus(lang, wd)
  let cls = "chip"
  if st == "mastered" {
    cls = "chip good"
  }
  let h = "<span class='" + cls + "'>" + st + "</span>"
  if srsDifficult(lang, wd) {
    h += "<span class='chip' style='border-color:var(--bad);color:var(--bad)'>difficult</span>"
  }
  return h
}

fn wordRow(lang, wd, due, mine) {
  let w = wordData(lang, wd)
  let h = "<div class='w' style='flex-direction:column;align-items:stretch'><div class='row'><button class='sp' style='text-align:left' data-act='vocab:toggle' data-arg='" + esc(wd) + "'><b>" + esc(w.word) + "</b> <span class='muted'>" + esc(w.pron) + "</span><div class='small'>" + esc(w.meaning) + "</div></button>"
  h += "<div class='row wrap' style='justify-content:flex-end'>" + statusChip(lang, wd)
  if contains(due, wd) {
    h += "<span class='chip on'>due</span>"
  }
  h += sayBtn(w.say) + "</div></div>"
  if vocabOpen == wd {
    h += "<div class='small' style='margin-top:8px;border-top:1px solid var(--line);padding-top:8px'>"
    if w.example != "" {
      h += esc(w.example) + "<br><span class='muted'>" + esc(w.exampleEn) + "</span><br>"
    }
    if w.cat != "" {
      h += "<span class='muted'>Category: " + esc(w.cat) + "</span> "
    }
    if mine {
      h += "<button class='btn danger sm' data-act='vocab:remove' data-arg='" + esc(wd) + "'>Remove from notebook</button>"
    }
    let rec = srsRec(lang, wd)
    if length(rec) > 0 {
      h += "<div class='muted'>Box " + rec[0] + " of 5 · missed " + rec[2] + " time" + plural(rec[2]) + " · next review " + dayWord(rec[1]) + "</div>"
    }
    h += "</div>"
  }
  return h + "</div>"
}

fn plural(n) {
  if n == 1 {
    return ""
  }
  return "s"
}

fn notebookForm() {
  let h = "<div class='card flat'><div class='h2' style='margin-bottom:10px'>Add to your notebook</div><div class='cols'>"
  h += "<input id='vw' class='field' maxlength='60' placeholder='Word or phrase' autocomplete='off'>"
  h += "<input id='vm' class='field' maxlength='80' placeholder='Meaning' autocomplete='off'></div>"
  h += "<input id='vn' class='field' style='margin-top:10px' maxlength='160' placeholder='Note or example (optional)' autocomplete='off'>"
  h += "<div class='row' style='margin-top:12px'><button class='btn acc' data-act='vocab:add'>Add word</button>"
  if vocabMsg != "" {
    h += "<span class='small' style='color:var(--bad)'>" + esc(vocabMsg) + "</span>"
  }
  return h + "</div></div>"
}

fn screenVocabulary() {
  let langs = activeLangs()
  let h = "<div class='eyebrow'>Your words</div><h1 class='h1'>Vocabulary</h1><p class='lede'>Course words and your own notebook, scheduled for review so the hard ones come back sooner.</p>"
  if length(langs) == 0 {
    return h + "<div style='margin-top:24px'>" + emptyHtml("Pick a language first", "Your vocabulary appears for the languages you study.<div style='margin-top:14px'><button class='btn primary' data-act='nav:languages'>Choose languages</button></div>") + "</div>"
  }
  h += pathLangTabs()
  let code = currentLang()
  let L = langOf(code)
  let due = srsDueWords(code)
  let all = vocabWords(code)
  let mine = notebookWordSet(code)
  h += "<div class='lc' style='--h:" + L.hue + "'>"
  h += "<div class='stats'>" + statCard("words", length(all)) + statCard("learned", learnedCount(code)) + statCard("due today", length(due)) + statCard("difficult", difficultCount(code)) + "</div>"
  h += "<div class='row wrap' style='margin-top:18px'>"
  if length(due) > 0 {
    h += "<button class='btn acc' data-act='vocab:review'>Review " + length(due) + " due word" + plural(length(due)) + "</button>"
  } else {
    h += "<span class='chip good'>Nothing due. You're up to date.</span>"
  }
  h += "</div><div class='sec'><div class='row wrap'>"
  let i = 0
  while i < length(vocabFilters) {
    let cls = "chip"
    if vocabFilters[i] == vocabFilter {
      cls = "chip on"
    }
    h += "<button class='" + cls + "' data-act='vocab:filter' data-arg='" + vocabFilters[i] + "'>" + vocabFilterNames[i] + "</button>"
    i += 1
  }
  h += "</div><div class='row wrap' style='margin-top:10px'>"
  let cats = vocabCats(code)
  for each c in cats {
    let cls = "chip"
    if c == vocabCat {
      cls = "chip on"
    }
    h += "<button class='" + cls + "' data-act='vocab:cat' data-arg='" + esc(c) + "'>" + esc(c) + "</button>"
  }
  h += "</div><div class='row' style='margin-top:12px'><input id='vq' class='field' placeholder='Search words or meanings' value='" + esc(vocabQuery) + "' autocomplete='off'><button class='btn ghost' data-act='vocab:search'>Search</button></div></div>"
  h += "<div class='sec'><div class='vocab'>"
  let shown = 0
  for each wd in all {
    if shown < 200 and vocabMatches(code, wd, due) {
      h += wordRow(code, wd, due, contains(mine, wd))
      shown += 1
    }
  }
  if shown == 0 {
    if length(all) == 0 {
      h += emptyHtml("No words yet", "This language has no course yet. Add your own words below.")
    } else {
      h += emptyHtml("No words match", "Try another filter or clear the search.")
    }
  }
  h += "</div></div><div class='sec'>" + notebookForm() + "</div></div>"
  return h
}

fn actVocab(verb, arg) {
  let code = currentLang()
  if verb == "filter" {
    vocabFilter = arg
  } else if verb == "cat" {
    if vocabCat == arg {
      vocabCat = ""
    } else {
      vocabCat = arg
    }
  } else if verb == "search" {
    vocabQuery = inputValue("vq")
  } else if verb == "toggle" {
    if vocabOpen == arg {
      vocabOpen = ""
    } else {
      vocabOpen = arg
    }
  } else if verb == "add" {
    vocabMsg = notebookAdd(code, inputValue("vw"), inputValue("vm"), inputValue("vn"))
    if vocabMsg == "" {
      logAdd(code, "Added “" + cleanField(inputValue("vw")) + "” to the notebook")
    }
  } else if verb == "remove" {
    notebookRemove(code, arg)
    vocabOpen = ""
  } else if verb == "review" {
    startReview(code)
    return 0
  }
  render()
}
