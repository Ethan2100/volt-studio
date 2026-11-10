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
