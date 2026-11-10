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
