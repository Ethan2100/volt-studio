# Upgrade notes

Running log of the Volt upgrade: what was done, decisions made on the way, and things you
need to know. Newest step at the bottom. See [AUDIT.md](AUDIT.md) for the starting point and
[UPGRADE_PLAN.md](UPGRADE_PLAN.md) for the plan.

## How "nothing broke" is checked

`npm test` (plain Node, ~2 s, no Electron). The first suite compiles every `.volt` file in the
repo and compares a SHA-1 of the output with `test/golden.json`, which was recorded from the
compiler **before** any change. So for every example and game in the repo, the upgraded
compiler produces byte-for-byte the same file as the old one, except where listed below.

Deliberate output changes so far:

| File | Before | After | Why |
|---|---|---|---|
| `examples/roguelike/yokai-descent.volt` | did not compile (`'dist' is a reserved name`) | compiles | bug B1 fixed |

## Step 0 - Safety net

- `test/run.js` + `test/suite/*.js`: test runner with no dependencies.
- `test/golden.json`: output hash of all 49 `.volt` files.
- `.github/workflows/test.yml`: runs the suite on every push.
- The old `test/*-test.js` files (they drive a real Electron window) are untouched.

## Step 1 - Compiler quality

**Errors know exactly where they are.** Tokens and tree nodes carry `col`/`endCol`, and
`VoltError` has `line`, `col`, `endCol`, `hint`, `file`. The command line shows it:

```
game.volt:3:8  error: Unknown variable 'scroe'. Did you mean 'score'?
  3 | print  scroe + 1
    |        ^^^^^
```

**Imports have a source map.** An error inside an imported file names that file and its own
line, plus the line of the `import` that pulled it in. Before, the line number was an offset
into the merged text. Indented `import` lines work now.

**Built-in names are no longer reserved** (decision). Adding `dist` as a built-in is what broke
Yokai Descent, and every future built-in would risk the same. Now a program's own `dist`
variable or `fn lerp()` simply wins over the built-in. Eleven names stay reserved because the
generated code itself calls them (`random abs min max constrain map sqrt pow sin cos atan2`).

**`volt.check(source)`** returns every problem at once instead of throwing the first:
`{ ok, target, code, diagnostics: [{ severity, message, hint, line, col, endCol, file }] }`.
The parser recovers at the next top-level line; the generator records an error per statement
and carries on. `volt.compile()` is unchanged: it still throws the first error.

**Warnings** (only from `check()`, never from `compile()`): a `let` that is never read, a
function that is never called, a line after `return`/`break`/`stop`. Names used from raw `#`
code count as used. Run over the repo's own games this finds 28 real leftovers and no noise;
a first version flagged 187 `let wall = block3d(...)` lines, so a `let` whose value calls
something is deliberately not reported.

**Speed.** Lexer rewritten to slice instead of building strings a character at a time; Three.js
and embedded assets are read once and reused; embedded base64 skips escaping.

| File | Before | After |
|---|---|---|
| 99 Nights (8.7 MB output) | 79 ms | ~50 ms |
| One More Floor | 53 ms | ~38 ms |
| Moonwell (6,815 lines) | 104 ms | ~60-90 ms |

**Packaging bug fixed (B2).** `plugins/**` was missing from `build.files` in `package.json`,
so the installed app had no bundled plugins at all (no `#lua`, no World Studio, no Flipbook).

**Suggestion quality.** "Did you mean" no longer guesses for very short names (`foo` -> `cos`).

## Review pass (after step 5)

The work so far was reviewed by independently recompiling every `.volt` file with the original
compiler and the new one, rather than trusting `test/golden.json`: 48 of 49 produce byte-identical
output and the 49th is Yokai Descent, which now compiles instead of failing. That claim holds.

Four defects came out of the review, all now fixed.

**1. The `#lua` and `#luau` addon targets had fallen behind the core compiler.** Two separate
problems, both in `plugins/lua-target/lua-common.js`:

- A program's own function did not win over a built-in of the same name, so `fn dist(a, b)`
  compiled as `#js` but failed as `#luau` with `'dist' needs 4 values, got 2`. That is the exact
  bug class step 1 set out to kill; it was only fixed in the core.
- Built-ins the target did not handle fell through to a bare call, so `round(2.5)` compiled
  quietly and then crashed in Lua with `attempt to call a nil value`. This was already true
  before the upgrade for `sqrt`, `pow`, `sin`, `cos`, `dist`, `lerp`, `overlaps`, `join` and
  `split`; adding ~25 built-ins in step 2 made it much worse.

Fixed by: user functions now win on these targets too; the new standard library is implemented in
Lua (25 helpers); and **anything not handled is now a compile error instead of a silent
fall-through**, so this cannot happen again. `HELPER_ORDER` gating was a second silent trap - a
helper missing from that list was simply never written out - and now raises a compiler error too.

Verified by running the generated Lua in a real Lua VM and checking it prints exactly what the
same program prints as `#js`: 25 cases, all matching. `test/suite/07-lua-target.js` keeps it that
way, and CI now installs Lua so those tests really run.

**2. `compiler/volt.js` had been converted from CRLF to LF**, while the rest of the repo is still
CRLF. It made the diff read as 4,303 added / 3,552 removed when the real change is 983 / 226.
Line endings restored; the file matches the rest of the repo again.

**3. `round()` was inconsistent across targets.** Ruby's own `.round` rounds half away from zero,
so `round(-2.5)` gave `-3` in `#ruby` and `-2` everywhere else. Pinned to half-up on every target.

**4. A default argument that was an expression gave a parser error.** `fn f(a, b = 2 + 3)` said
`Expected ')' but found '+'` instead of the "must be a plain value" message written for it, which
could never be reached. It now reports the intended message, with a hint.

While fixing these, one more thing was improved: text in quotes now works inside an interpolation
hole, so `"[{trim("  hi  ")}]"` compiles. It used to end the string at the inner quote.

### The Lua targets also missed the new language features

Running the new tests with a Lua VM actually present (rather than letting them skip) turned up a
second gap: `#lua` and `#luau` rejected `continue` and `match` outright, ignored the position in
`for each item, i in list`, and passed nothing for a left-out default argument. All four now work:

- `continue` compiles to Luau's own keyword, and on plain Lua to a `goto` with a label at the end
  of the loop body (`goto` is Lua 5.2+ and LuaJIT). Tested with variables declared between the
  jump and the label, which is the case Lua is fussy about.
- `match` is built out of plain `if`/`elseif` with the value worked out once, as elsewhere.
- Statements after `return`, `break` or `continue` are dropped. They could never run, and Luau
  requires `continue` to be the last statement in its block, so leaving them in made invalid Luau.

### Known, pre-existing, not introduced here

These behave the same before and after the upgrade, and are worth a decision later:

- Decimals print differently per target: `1.5 + 2.5` is `4` in `#js`, `4.0` in `#python`/`#ruby`.
- A list shown as text differs: `1,2` in `#js`, `[1, 2]` in `#python`/`#ruby`.
- An unescaped `"` inside text ends the text, so `"a { font: "Arial" } b"` is an error. Write `\"`.

## Step 6 - Volt Studio

The editor now asks a shared language service (`lib/language-service.js`) instead of guessing.
The same file serves the VS Code extension later, so the two can't drift apart.

**Every problem at once.** The editor used to show one error, highlighting the whole line.
It now shows every error *and* warning the compiler found, with the exact letters underlined,
a mark in the gutter, and the message on the line it belongs to. Warnings are yellow, errors red.

**Autocomplete that knows the file.** It offers the variables, functions, parameters, pins, types
and sprites the file itself makes, ranked above built-ins, and it only offers what the current
target can do - no `mousex()` in a `#python` script, no `sort()` on a board. Built-ins come with
their signature and a line of explanation. Suggestions appear as you type a name.

**Hover** explains whatever is under the pointer: a built-in's signature and what it does, or
where one of your own names was made. Resting on a mistake shows the message and its hint.

**Go to definition** with F12, Ctrl+B or Ctrl+click, and a flash to show where it landed.

**Highlighting comes from the compiler now.** `renderer/volt-mode.js` used to keep its own copy of
the keyword and built-in lists, and had already fallen behind by nine built-ins. It now builds its
rules from `highlightWords()`, so a new built-in is coloured without anyone editing the editor.
The old hand-written lists are kept only as a fallback for when the service can't be reached.

**Two things the screenshots caught**, both pre-existing and both fixed:

- The language in the toolbar only updated when the file compiled, so a `#html` file with a typo
  still said "Arduino C++". It now follows the first line whatever the state of the file.
- While an error was being fixed, the output pane kept showing the last working output - which,
  after the first line changed language, meant Arduino C++ code sitting under an "HTML page"
  label. Output from a different language is now cleared instead.

### How this is tested

`test/suite/08-language-service.js` covers the service itself, including that it never throws on
half-written code (it is asked at every keystroke) and that the built-in docs cover exactly the
compiler's built-ins with the same number of values.

`test/suite/09-studio.js` opens the real Volt Studio window with Electron and checks what a person
would actually see: three problems from one file with the right severities, `scroe` underlined
rather than the whole line, warnings styled differently, autocomplete putting the file's own
variable first and offering 3D names in `#html`, hover, go to definition, and `shuffle` being
coloured as a built-in. It skips when Electron isn't installed.

## Steps 4 and 7 - sharing code, other editors, and the docs

### A command line

`bin/volt.js`, also installed as `volt`:

```
volt build | run | check | new        one .volt file
volt add | remove | list | install    packages
volt docs <name>                      what a built-in does
```

`volt check` prints every problem with a caret under the exact spot and exits 1 if any of them
are errors, so it can go in a git hook or CI.

### Packages

A package is a folder of `.volt` files with a `volt.json`. `volt add` takes a folder, a GitHub
repository (`owner/repo`) or any git address, copies it into `volt_packages/` and records it in
the project's `volt.json`; `volt install` rebuilds that folder from the manifest. The compiler
already knew how to find `volt_packages` (step 1), including from a program several folders
down, so `import "name"` needed no further work.

Two packages ship in `packages/`: **tween** (easing curves, `progress`, `shake`) and **grid**
(a flat list used as a 2D grid). Both are covered by `test/suite/14-packages.js`, which installs
them the way a person would and checks their answers - writing those tests caught a bounce curve
that overshot 100 and another that was out by a factor of ten.

### Volt in other editors

`lsp/server.js` is a Language Server over stdio, written out by hand so there is nothing to
install. It is a shell around the same `lib/language-service.js` the Studio uses, so every editor
gets the same errors, warnings, autocomplete, hover, definitions and outline.

`vscode-volt/` is a VS Code extension with no dependencies of its own. Its TextMate grammar is
**generated** from the compiler's word lists by `vscode-volt/build-grammar.js`, and
`test/suite/13-vscode.js` fails when the committed grammar has fallen behind - which is exactly
how the old hand-copied editor lists went stale in the first place.

`test/suite/12-lsp.js` drives the server with real LSP messages, including malformed input, to
be sure one bad request can't take it down.

### Docs

- `docs/GETTING_STARTED.md` - Volt in 10 minutes, ending in a working 3D game.
- `docs/VOLT3D.md` - the whole 3D side.
- `docs/EXTENSIONS.md` - packages, plugins, and using Volt from another editor.
- `docs/REFERENCE.md` - updated for everything new.

**Every Volt example in the docs is compiled by the test suite** (`test/suite/10-docs.js`), so an
example cannot quietly stop working. It found two that were already broken, and one of mine that
used `{10}` as if it were a value.

### Deliberately not done: a v2 plugin manifest

The plan had plugins growing a `contributes` section for themes, snippets, commands and file
types. It isn't here, on purpose. Each of those needs matching work inside Volt Studio's UI to
honour it, and none of it is needed by anything that exists: the three plugin kinds already in
`lib/plugins.js` (a library of snippets, a tab, a new output language) cover what the bundled
plugins do, and packages now cover sharing Volt code, which was the real gap. Adding a wider
manifest without anything using it would be surface to maintain for no one's benefit.

The bundled plugins were left on their existing manifests for the same reason: they work, and
porting them would have been churn.

## UI Studio - laying out a HUD or a page by dragging

`plugins/ui-studio/` is a Volt Studio panel for the thing the games here do by hand: a HUD built
from `box` and `write` calls with pixel numbers guessed, compiled, looked at and adjusted.

Two modes in one panel:

- **Game HUD** - a stage at the program's real `canvas` size. Drag boxes, text, health bars,
  sprites and buttons; it writes `box` / `write` / `draw` and, for a button, an
  `if clicked() and mousex() >= ...` block to fill in. The block belongs inside `every frame`.
- **Page** - `title`, `print`, `button ... { }`, `html` and `background.color` / `text.size`
  styling, for a non-game `#html` page, at the top level.

It writes between two marker comments and saves the layout as JSON on one comment line inside the
block, so **Load from file** can open it again. That round-trips reliably without having to parse
back the Volt it generated. Hand edits to the generated lines are not read back, which the panel
and its README say plainly.

It also reads the screen size from the `canvas` line and the sprite names from the `sprite` lines,
so the stage matches the real game and the sprite box offers real names.

### How it is tested

`test/suite/15-ui-studio.js` runs the real panel in a headless browser, builds layouts, and
**compiles what it writes with the real compiler** - inside a whole game for a HUD, as a whole
page for page mode. It covers text people actually type (quotes, backslashes, percent signs,
apostrophes, `{values}`), a layout surviving a save-and-open round trip unchanged, sending twice
replacing the block rather than stacking copies, indentation being kept when the block sits
inside `every frame`, and a damaged block being reported rather than breaking.

One test plays the part of Volt Studio itself - answering `hello` and `getSource` and taking the
`replace` - so the panel's half of the postMessage bridge is really exercised, not assumed.

Two honest limits are shown in the panel rather than hidden: anything reaching past the edge of
the screen is outlined in red and counted, and text holding `{values}` is previewed at the width
you typed, which is not the width it will be once Volt fills the numbers in.

---

## A pass over Volt Studio itself (the app, not the language)

Everything up to here was about the language and the tests. This pass was about the editor: an
audit by a reader who had not written any of it, then fixing what it found, worst first. Nothing
in this section changes what any `.volt` program compiles to - the golden test still says 48 of
the 49 existing programs are byte-identical, and the one that isn't is `apps/tonefield.volt`,
which I edited on purpose.

### The three that made the app look broken

**A file that used `import` could not be run at all.** The live compile the editor does while you
type was called without the file's own folder, so `import "thing.volt"` reported *"this program
has no folder to look in"* - on a correct line, in a file the language service said was fine.
Because Run and Upload both refuse to start while the last compile failed, both buttons were dead
for any such file, including the bundled "import library" example. The same gap quietly dropped
pictures from the Output code pane, so what the pane showed was not what Run produced (267 KB
against 613 KB for the dungeon example). Compile and Run passed the folder; the live compile and
Upload did not. Now all four do.

**A file in an addon language (`#lua`, `#luau`, `#pseudo`, all three bundled) broke the editor's
status line.** The status line looked its language up in a table of the six built-in ones and
found nothing, so it threw. The throw happened inside the function Run and Upload await, so
pressing either did nothing at all, with no message anywhere - and the language menu went blank
because it had no entry to select. Addon languages now join that table at startup and appear in
the menu under *Addons*, which also fixes a second bug: picking a language while such a file was
open used to insert a *second* first line (`#python` above `#lua`) and break the program.

**A failed write vanished.** Four handlers wrote files with nothing around them, and the editor
had two `.catch()` calls in 1400 lines. A read-only folder, a file open in another program, a
full disk or a pulled-out USB stick made Save, Compile and Run do nothing at all and say nothing
- Save even kept the unsaved-changes dot, so the app then asked about unsaved changes for a file
the user believed they had saved. Each write now reports what went wrong in words ("the disk is
full", "the file is in use by another program"), and there is a catch-all in the editor so that
anything that gets through in future at least surfaces as a message.

### Then

- **Rescan printed three red errors for addons that were fine.** Registering a target twice threw
  *"already registered"*, which is exactly what a rescan does. Registering the same addon again is
  now a replace - which is also what makes editing an addon and pressing Rescan work at all -
  while taking the name of one of Volt's own languages is still refused.
- **A broken `plugin.json` was invisible.** The exact reason was worked out at scan time and then
  filtered out of the list. A trailing comma looked identical to having installed nothing. Those
  addons are now shown in the Library tab with the parse error and its position.
- **A panel addon whose entry file was missing showed a blank white rectangle** in a dark app,
  for ever. It now says which file it could not find and where to fix it.
- **Typing in the large examples was laggy.** Every keystroke compiled the file twice - once for
  the problems, once for the output code - synchronously in the main process. On the 6,815-line
  dungeon example that was 159 ms a keystroke. One pass now does both: **56 ms**, byte-identical
  output.
- **Startup read about a megabyte it did not need** - every example's full source, to show
  titles. It now reads the first 2 KB of each for the title, description and language pill, and
  the source when a card is clicked.
- **An upload could not be cancelled.** Compiling for the wrong board takes minutes; Stop only
  knew about scripts, and the only button was greyed out and labelled "Uploading…". Stop now
  stops whichever is running.
- **Closing the editor with the preview window open left the app running** with no window to get
  back to it from, and any running script still going with its output going nowhere.
- **Run looked frozen on a computer without Python** - a miss was never remembered, so every Run
  re-ran three 8-second probes before printing anything. Misses are cached now, and Tools >
  Upload Setup Check clears the cache, which is the way to look again after installing something.
- **Dialogs had no way out but the mouse**, and a second dialog rewrote the first in place and
  left its promise pending for ever. Escape now closes one, taking the Cancel/Close action rather
  than the one that changes something, and only one dialog opens at a time.
- **The AI tab took a second question while the first was in flight** (Enter bypasses a disabled
  submit button), which interleaved the replies and corrupted the history that gets sent next.
- **A cut-off AI answer still offered "Replace file".** Answers are capped, and a long one stops
  mid-code-block. The reply now says it ran out of room, and the last, incomplete block offers
  Copy and Insert but not the one action that overwrites the whole file.
- **Your own chat messages were white on yellow** - about 1.3:1, unreadable. Every other accent
  surface in the app uses the dark ink colour; this one now does too. Assistant answers also had
  a blank line between every paragraph (`pre-wrap` on top of rendered markdown).
- **The API key reached the editor process.** The code said twice in comments that it never did.
  It does not now: `app:info` and `settings:set` strip it, the key dialog starts empty and shows
  the last four characters of the saved key, and there is a "Remove saved key" button, since a
  blank box now means "leave it alone".
- **Save As could overwrite a file without asking.** The dialog asked about `notes.txt`; the code
  then wrote `notes.txt.volt`, clobbering any existing one silently. It asks now.
- **At the window's own minimum width, Upload was off-screen.** The toolbar is one row that does
  not wrap; at 900 px it wanted 1080 px, so Compile was cut in half and Upload was 180 px past
  the edge with no way to scroll to it - which happens on a 1366x768 laptop as soon as the window
  is not maximized. It now fits at every width from 900 px up, shedding the app's own name first,
  then the file name, then the width of the board and port menus. The buttons never shrink.

### How this was checked

`test/studio-driver.js` - which opens the real Electron window - gained checks for the ones that
could be: a file that imports compiling cleanly, an addon language naming itself in the toolbar
and on the status line and being in the menu, switching away from one replacing line 1 rather
than adding a second, Escape cancelling a dialog, and a save that cannot be written being
reported. The toolbar was measured at 900, 1000, 1100 and 1240 px, and the AI and Library tabs
were photographed rather than reasoned about.

### Left alone on purpose

- The serial-port poll every 3 s and the 500 ms baud-sync interval run for the life of the app.
  They are cheap and gated on focus; worth tidying, not worth risking here.
- Tools > Upload Setup Check still blocks for a few seconds behind its probes with no spinner.
  Caching misses took most of the sting out of it; the spinner is a separate change.

---

## apps/volt-fm.volt - a music app in one file

The app, after the Studio pass. It is shaped like the music apps people actually use: a sidebar
with Home, Search and Library, a list of songs, mood filters, likes, a playlist, and a now-playing
bar with a visualiser.

What makes it worth having in this repo rather than being a mockup of one:

- **The songs are real.** Eight original chiptunes, each a `music` line of notes and a bassline at
  its own tempo. The page synthesizes them; there are no audio files.
- **The covers are real too.** Each one is drawn from the song's own name - the name becomes a
  number, the number becomes the bars and the colours. No images anywhere, so the whole app is a
  single `.volt` file with no folder of assets beside it.
- **Likes and the playlist persist** through `save` / `saved`, so they survive a reload.

### What it cost to get right

The layout was wrong in ways that only showed up in a screenshot: the toast box overlapped the
subtitle, the mood chips were drawn over it, the scroll hint sat half-under the player bar, and
the "liked" marker in the player bar was an orphaned letter. Each was found by looking at a
rendering, not by reading the code.

Worse, two of them were bugs I introduced by fixing the first ones: moving the mood chips down
left their *clickable* area 10px above where they were drawn, so the top sliver of a chip worked
and the rest did nothing; and moving the like marker left a hit area with nothing drawn under it.
Both were caught by driving the page in a real browser - clicking where a person would click and
checking what changed - rather than by looking at it again.

`test/golden.json` has it, so its output is pinned like everything else.

### Volt FM, second pass: what an outside opinion changed

I asked ChatGPT (signed out, in the browser pane, so nothing of Ethan's account was touched) what a
music app like this was missing and what made it feel like a demo. Two of its points held up and
one I checked before accepting.

- **A Now Playing screen with a seekable timeline.** Added (Enter, or click the cover). Checking
  whether a timeline was *honest* turned up the real problem: every "song" was a 16-step loop,
  3 to 6 seconds long, so a progress bar would have advertised it. All eight are now 64-step,
  four-bar arrangements (11 to 25 seconds). The bar reads `__song.step` from the music runtime
  rather than a clock beside it, and clicking it sets that counter, so it is a real seek.
- **Stop advertising shortcuts in the UI.** The sidebar no longer shows "1 Home"; the keys still
  work. The "press up and down to scroll" line became a scrollbar.
- Not taken: cutting the mood chips. Its reasoning (eight songs is too few to filter) is fair, but
  Search is the screen that makes this look like a music app at all.

Verified by driving the page: the step counter advances while playing, a click at 75% lands at
step 50 of 64, and play/pause, next, add-to-playlist and Escape all work from the new screen.

---

## apps/volt-chat.volt - a messaging app with Instagram's look

WhatsApp's behaviour in Instagram's clothes, as one `.volt` file with no assets.

- **Chat list** newest first, with unread badges, a "typing..." state, and a search box that is
  the keyboard itself: what you type filters conversations.
- **Threads** with bubbles, word-wrapping, timestamps, a typing indicator, and replies that arrive
  on their own after a delay. People also write first now and then, which is what makes it feel
  alive instead of like a form.
- **Instagram's half:** stories across the top with the gradient ring (grey once viewed), a
  full-screen story viewer that auto-advances and where tapping the left or right side moves
  between people, and a double-tap on any bubble to heart it.
- **Posting a story** is done by typing what it should say in the search box and tapping the +
  on "You".
- Messages, hearts and which stories you have seen persist through `save` / `saved`.

The people are scripted, not real - nothing here talks to a server. That is stated on the screen
that would otherwise imply it, and it is why the replies are keyword-light and in character.

### How text gets in

Volt's canvas has no text input, so the page listens for keys itself through one raw-JS line that
appends to a Volt variable. That works because raw lines share the program's scope. Backspace and
printable characters are handled there; Enter and Esc are ordinary `when key` handlers.

### Bugs this caught while being driven in a real browser

The heart on the newest message was drawn underneath the input bar, and story captions were
unreadable where they crossed the white bars. Both were visible only in a screenshot.
Volt also refused `open`, `time`, `list` and `p` as names, which `volt check` reported clearly.
