// =====================================================================
// POLYGLOT - registry.volt  (language management)
// One line per language. To add a language: add an addLang(...) line
// here and a content file in content/ - nothing else needs to change.
// Whether a language is "ready" is decided by whether it has lessons
// (see hasCourse in content/schema.volt), never by a flag here, so the
// app can't claim a course exists when it doesn't.
//
// hue is a colour (0-360) that tints every screen for that language.
// =====================================================================

Language = type { code: string, name: string, endo: string, glyph: string, voice: string, hue: int, script: string, rtl: int, tagline: string }

let langList = []
let langCodes = []

fn addLang(code, name, endo, glyph, voice, hue, script, tagline) {
  add Language { code: code, name: name, endo: endo, glyph: glyph, voice: voice, hue: hue, script: script, rtl: 0, tagline: tagline } to langList
  add code to langCodes
}

addLang("nl", "Dutch", "Nederlands", "ij", "nl-NL", 28, "Latin", "Easy first steps for English speakers, with a famously throaty g.")
addLang("de", "German", "Deutsch", "ß", "de-DE", 48, "Latin", "Cases and long compound words, but very regular once you see the pattern.")
addLang("fr", "French", "Français", "ç", "fr-FR", 222, "Latin", "Silent letters and liaison: reading comes before speaking.")
addLang("es", "Spanish", "Español", "ñ", "es-ES", 354, "Latin", "Phonetic spelling and a clear rhythm; one of the fastest to start speaking.")
addLang("it", "Italian", "Italiano", "à", "it-IT", 132, "Latin", "Melodic and phonetic, with lots of vocabulary shared with Spanish and French.")
addLang("pt", "Portuguese", "Português", "ã", "pt-PT", 168, "Latin", "Nasal vowels, and a rhythm that differs a lot between Brazil and Portugal.")
addLang("ja", "Japanese", "日本語", "あ", "ja-JP", 318, "Kana + Kanji", "Three writing systems and a very different grammar: kana first, kanji later.")
addLang("ko", "Korean", "한국어", "한", "ko-KR", 268, "Hangul", "A logical alphabet you can learn in an afternoon, with honorific speech levels.")
addLang("zh", "Mandarin Chinese", "中文", "字", "zh-CN", 8, "Hanzi", "Tones and characters, but no verb conjugation at all.")
addLang("ar", "Arabic", "العربية", "ع", "ar-SA", 190, "Arabic", "Right-to-left script, a root-and-pattern word system and rich dialects.")
addLang("sw", "Swahili", "Kiswahili", "Kw", "sw-KE", 96, "Latin", "Noun classes and word-building suffixes, with perfectly regular pronunciation.")
addLang("ru", "Russian", "Русский", "Я", "ru-RU", 246, "Cyrillic", "Cyrillic script and six cases; stress changes how words sound.")
addLang("tr", "Turkish", "Türkçe", "ğ", "tr-TR", 340, "Latin", "Vowel harmony and suffixes added in a chain: very logical once it clicks.")

langList[posOf(langCodes, "ar")].rtl = 1

// The Language struct for a code (the first language if the code is unknown).
fn langOf(code) {
  let i = posOf(langCodes, code)
  if i < 0 {
    i = 0
  }
  return langList[i]
}

// HTML attributes that tint an element with a language's colour.
fn lcAttr(code) {
  return "class='lc' style='--h:" + langOf(code).hue + "'"
}

fn stampHtml(code, small) {
  let cls = "stamp"
  if small == 1 {
    cls = "stamp sm"
  }
  return "<div class='" + cls + "'>" + langOf(code).glyph + "</div>"
}
