# POLYGLOT: feasibility report and architecture

Everything below was checked against the real compiler (`compiler/volt.js`), `docs/REFERENCE.md`, and small probe programs compiled and run, not assumed.

## 1. What Volt can do for this project (verified)

| Need | Verdict | How |
|---|---|---|
| Multi-screen app UI | Yes | `#html` target. A screen is a Volt function that calls `clear` then `html "<...>"`. Layout/theming is CSS on `##` lines (works in imported files). |
| Click and keyboard input | Yes | `data-act` attributes + one delegated listener (1 raw JS line), `when key "x" pressed`, `ask`. |
| Multi-file project | Yes | `import "path.volt"` splices files at compile time into one `index.html`. Subfolders work (`import "core/store.volt"`). Repeats are skipped. |
| Data model | Yes, with limits | Flat structs (`Word = type {...}`), lists, lists nested in lists, and lists as struct fields all compile and run. |
| Lots of content | Yes | 6,000 content lines compile in 0.14 s to a 455 KB page. |
| Escapes in strings | Yes | `\"`, `\n`, `\\` verified. |
| Logic | Yes | `fn`, `while`, `for each`, `else if`, `and/or/not`, `split/join/part/contains/upper/lower/random`. Functions compile to async JS, so all calls are awaited automatically. |
| Persistence | Only via raw JS | Volt has no storage statement. A 3-function glue module (`kvGet/kvSet/kvKeys`) uses `localStorage` through `#` raw lines. All logic stays in Volt. |
| Text to speech | Only via raw JS | `speechSynthesis`, one function. Voice quality and availability depend on the device. |
| Pronunciation scoring | Only via raw JS, browser dependent | Web Speech `SpeechRecognition` works in Chrome/Edge/Safari, not Firefox. Volt computes the similarity score. Fallback: listen and self-rate. |
| Theme switching | Raw JS (1 line) | Sets `data-theme` on `<html>`; the themes are CSS variables. |
| AI tutor | Needs a backend | See section 3. |

## 2. Hard limits (so nothing is faked)

- **No maps/dictionaries.** Lookups use lists and string keys in storage.
- **Structs are flat**: a field can be a string, number or list, but not another struct.
- **No unit-test or module namespace system.** `import` is a paste, so every global name must be unique. I prefix module internals (`srs…`, `st…`, `ui…`).
- **Whole-number maths by default.** Fine for XP and intervals.
- **No real network POST** in Volt (`fetchText` is GET-only). The AI call is a raw-JS `fetch` in one function.
- **The compiled output is a single static page.** Progress lives in that browser's `localStorage` (no accounts or cross-device sync) unless a backend is added later.
- **Real content volume.** 13 languages x 6 CEFR levels cannot honestly be authored in one pass. See section 4.

## 3. AI tutor: requirements and design

An Anthropic API key must never ship inside a static web page (anyone could read it). So:

1. `projects/polyglot/server/tutor-server.volt` is a `#js` program (Node) that reads `envVar("ANTHROPIC_API_KEY")` and serves `POST /api/tutor`. Deploys to Render like Ethan's other Node apps. The HTTP server and the API request use a few raw JS lines (Volt has no server or POST statements).
2. The app has a clean interface layer, `tutorAsk(task, language, level, text)`, that builds the prompt in Volt and calls the endpoint set in Settings.
3. With no endpoint configured, the AI Tutor screen says so and shows the setup steps. It does **not** simulate AI replies.

## 4. Content plan

- **Fully authored (real, checked content):** Dutch, German, French, Spanish, Japanese, each with at least 5 A1 lessons. Every lesson has vocabulary (word, pronunciation, example, category, difficulty), a grammar explanation that says *why*, exercises of mixed kinds with explanations, a reading passage and a scripted conversation.
- **Registered but not yet authored:** Italian, Portuguese, Korean, Mandarin, Arabic, Swahili, Russian, Turkish. They appear in My Languages as "course not written yet", with no placeholder lessons. Adding a language = one registry line + one content folder.
- **Levels:** the engine supports A1–C2 on every lesson (`level` field). Only A1 is authored in this pass.

## 5. Architecture

```
projects/polyglot/
  polyglot.volt            entry: #html, imports everything, boots
  core/
    theme.volt             CSS (## lines): tokens, light/dark, layout
    util.volt              shuffle, posOf, text helpers, clock
    store.volt             persistence glue (kvGet/kvSet) + typed helpers
    settings.volt          theme, goals, endpoint, per-language goals
    registry.volt          Language struct + the 13 languages
  engine/
    srs.volt               spaced repetition (intervals, due, lapses)
    progress.volt          XP, streak, goals, achievements, daily stats
    lessons.volt           lesson queries and lesson flow
    exercises.volt         exercise kinds: render + grade + explain
    vocab.volt             vocabulary manager and notebook
    tutor.volt             AI interface layer
  ui/
    shell.volt             sidebar/top bar, router, 8 sections
    dashboard.volt, languages.volt, paths.volt, practice.volt,
    vocabulary.volt, tutor_screen.volt, stats.volt, settings_screen.volt
  content/
    schema.volt            Word/Lesson/Exercise structs + add helpers
    es.volt de.volt fr.volt nl.volt ja.volt
  server/
    tutor-server.volt      #js Node proxy for the AI tutor
```

Data model (all flat structs): `Language`, `Word`, `Lesson` (grammar text and points as list fields), `Exercise` (kind, prompt, answer, `options` list, explanation), `Convo` (turns as list fields). Learner state is strings in storage, keyed `w:<lang>:<word>`, `xp:<lang>:<day>`, `done:<lang>:<lesson>`.

## 6. Where raw JS is used (and nowhere else)

Storage (3 fns), speech out, speech recognition, theme attribute, date/clock, accent-stripping text normalise, the one delegated click/keydown listener, the AI `fetch`, and the Node HTTP server. Everything else (routing, content, SRS, exercises, grading, stats, UI building) is Volt.

## 7. Delivery

Lives in `projects/polyglot/` (not `examples/`, because Volt Studio lists every `.volt` in an examples folder as a separate example, which would clutter the Examples tab with module files). Compile with `node compiler/volt.js projects/polyglot/polyglot.volt` or open `polyglot.volt` in Volt Studio.

## 5. Final status (all 10 stages built and tested)

**Built and working:** 13 languages registered with per-language accents and voices; 5 written A1 courses (Spanish, German, French, Dutch, Japanese: 25 lessons, 200 words, 303 exercises, every answer explained); lesson player with intro, grammar ("why"), and 9 exercise kinds plus flashcards; Quick Learn (5/10/15/30 min), review, 60-second challenge, conversation, pronunciation, listening and reading drills; Leitner spaced repetition with lapse-aware intervals; vocabulary manager with filters, search and a validated personal notebook; XP, levels, streaks, 17 achievements, daily goals, weekly challenge; dashboard, per-language dashboards, comparison, 14-day chart; per-language goals and study days; light/dark/auto themes; backup export/import with strict validation; storage-failure warnings; AI tutor interface plus a Node server.

**Tests** (`tests/`): content validator, 25-lesson playthrough, and 8 behaviour suites (198 checks), all passing; real-Chrome smoke test on phone and desktop (no console errors, no horizontal overflow).

## 6. Known limitations (honest list)

- **Content volume:** only A1 exists, for 5 of 13 languages. Korean, Mandarin, Arabic, Swahili, Russian, Turkish, Italian and Portuguese are registered and selectable but say "course not written yet". Adding a language means writing one `content/xx.volt` file with `defLesson/defWord/defEx/defRead` and importing it; no engine changes. A2 to C2 are not written.
- **AI tutor** has never been run against the real Anthropic API in this environment (no key, restricted network). The server was tested against a stand-in model endpoint; request validation, rate-limiting, error paths and the client were all exercised. The first real call may need the model name in `TUTOR_MODEL` adjusted.
- **Speech:** text-to-speech quality depends on the voices on the device; pronunciation scoring needs a browser with SpeechRecognition (Chrome, Edge, Safari) and microphone permission. Elsewhere the app switches to self-rating and says so.
- **Storage:** progress lives in one browser's localStorage. No accounts or sync; use Export/Import to move it.
- **Japanese typing:** typed answers accept kana or romaji, but kanji is not taught yet.
- **Sentence checking is string-based:** answers tolerate case, accents, spacing and small typos, plus listed alternatives; a correct sentence worded in a way the author did not list will be marked wrong.
- **Not browser-tested:** Safari and Firefox (jsdom and Chrome only); screen-reader behaviour beyond basic labels, focus outlines and keyboard shortcuts (1 to 4, Enter) has not been audited.
- **Raw JS** is limited to the glue listed in section 4; Volt cannot do those things itself.
