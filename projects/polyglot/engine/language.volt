// =====================================================================
// POLYGLOT - engine/language.volt
// Everything about comparing and speaking text:
//  - norm(): makes two spellings comparable (case, accents, punctuation)
//  - similarity(): 0-100 score from edit distance (pure Volt)
//  - answerMatches(): is a typed answer one of the accepted answers?
//  - speech: text-to-speech and speech recognition (raw JS glue, since
//    Volt has no audio-input or voice statements). Both depend on the
//    browser; canSpeak() / canRecognize() say whether they exist here.
// =====================================================================

// Lower-cases, strips accents and punctuation, collapses spaces.
// Kana keep their dakuten (が stays が), Latin accents are dropped (é -> e).
fn norm(s) {
  # return String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').normalize('NFC').toLowerCase().replace(/[.,!?¿¡'’"、。？！\-]/g, '').replace(/\s+/g, ' ').trim();
}

// Edit distance between two strings (how many single-letter changes).
fn levenshtein(a, b) {
  let la = length(a)
  let lb = length(b)
  if la == 0 {
    return lb
  }
  if lb == 0 {
    return la
  }
  let prev = []
  let j = 0
  while j <= lb {
    add j to prev
    j += 1
  }
  let i = 1
  while i <= la {
    let cur = [i]
    j = 1
    while j <= lb {
      let cost = 1
      if a[i - 1] == b[j - 1] {
        cost = 0
      }
      add min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost) to cur
      j += 1
    }
    prev = cur
    i += 1
  }
  return prev[lb]
}

// 100 = identical after normalising, 0 = nothing in common.
fn similarity(a, b) {
  let x = norm(a)
  let y = norm(b)
  let n = max(length(x), length(y))
  if n == 0 {
    return 100
  }
  return max(0, (n - levenshtein(x, y)) * 100 / n)
}

// `alts` is a "|"-separated list of other accepted answers ("" for none).
fn answerMatches(guess, answer, alts) {
  let g = norm(guess)
  if g == "" {
    return 0
  }
  if g == norm(answer) {
    return 1
  }
  if alts != "" {
    for each a in split(alts, "|") {
      if g == norm(a) {
        return 1
      }
    }
  }
  return 0
}

// ---- speech --------------------------------------------------------------
fn canSpeak() {
  # return ('speechSynthesis' in window) ? 1 : 0;
}

fn speakText(phrase, accent) {
  # if ('speechSynthesis' in window) { const u = new SpeechSynthesisUtterance(String(phrase)); u.lang = accent; u.rate = 0.85; speechSynthesis.cancel(); speechSynthesis.speak(u); }
}

fn canRecognize() {
  # return (window.SpeechRecognition || window.webkitSpeechRecognition) ? 1 : 0;
}

// Listens once through the microphone. Returns what was heard, "" if
// nothing, or "__error__:<reason>" (for example "not-allowed" if the
// microphone is blocked).
fn listenOnce(accent) {
  # return new Promise((resolve) => { const R = window.SpeechRecognition || window.webkitSpeechRecognition; if (!R) { resolve('__error__:unsupported'); return; } const r = new R(); r.lang = accent; r.interimResults = false; r.maxAlternatives = 3; let finished = false; r.onresult = (e) => { finished = true; resolve(e.results[0][0].transcript); }; r.onerror = (e) => { if (!finished) { finished = true; resolve('__error__:' + e.error); } }; r.onend = () => { if (!finished) { finished = true; resolve(''); } }; try { r.start(); } catch (err) { resolve('__error__:start'); } });
}

fn voiceOf(lang) {
  return langOf(lang).voice
}
