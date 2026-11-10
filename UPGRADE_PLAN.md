# Volt upgrade plan

Based on [AUDIT.md](AUDIT.md). Ordered so that each step makes the next one safer.

## Ground rule: nothing that compiles today may change

Before any change, every `.volt` file in the repo is compiled and the SHA-1 of its output is
stored in `test/golden.json`. After every step the suite recompiles all of them and compares.
A program that compiled before must produce **byte-identical output** unless the change is
deliberate and written down in NOTES.md. New features use syntax that was an error before, so
old programs cannot hit them by accident.

## Step 0 - Safety net

- `test/run.js`: plain Node, no Electron, no dependencies. `npm test`.
  - golden output hashes for all examples and plugins
  - compiler unit tests (lexer, parser, errors, every new feature)
  - run tests: execute generated JS in Node, Python in `python3`, Ruby in `ruby`, and compare output
- `.github/workflows/test.yml`: run it on every push.

## Step 1 - Compiler quality

1. Tokens carry `col` and `end`; `VoltError` carries `line`, `col`, `endCol`, `hint`, `file`.
2. CLI prints the source line with a caret under the exact spot.
3. Import source map: errors inside an imported file name that file and its real line (fixes B3); indented `import` works (B4).
4. Built-in names stop being reserved, so new built-ins can never break a program again (fixes B1, restores Yokai Descent).
5. `volt.check(source)` returns a **list** of diagnostics (errors and warnings) with ranges, using statement-level recovery. `compile()` keeps throwing the first error, as before.
6. Warnings: unused variable, unused function, unreachable code after `return`/`break`/`stop`.
7. Cache Three.js and embedded assets between compiles (B5).
8. Ship `plugins/**` in the installer (B2).

## Step 2 - Language features

All additive. Each one compiles on every target where it makes sense.

| Feature | Syntax |
|---|---|
| Text interpolation | `"HP: {hp}/{maxHp}"` |
| `continue` | `continue` inside any loop |
| `match` | `match state { "idle" { } "run", "walk" { } else { } }` |
| Default arguments | `fn spawn(x, y, speed = 2) { }` |
| `%=` | `frame %= 4` |
| Loop with position | `for each e, i in enemies { }` |
| Structs everywhere | `Player = type { ... }` in `#js`, `#python`, `#ruby` too |
| Standard library | `floor ceil round clamp`, `trim replace startsWith endsWith indexOf repeatText`, `first last sort reverse slice sum`, `now`, `fetchJson` |
| Packages | `import "name"` finds an installed package |

## Step 3 - Simplicity

- One-line first-person controller with collision: `player3d` + `walk3d`.
- Mouse and gamepad in games: `mousex() mousey() mousedown()`, `pad("a") padx() pady()`.
- 3D calls accept decimals; nothing needs fixed-point maths any more.
- `remove3d`, `scale3d`, `tilt3d`, `color3d`, `attach3d` instead of hide-and-leak.
- Before/after for each in NOTES.md.

## Step 4 - Extensions

1. `bin/volt.js` command line: `volt build | run | check | new | add | remove | list`.
2. `volt.json` manifest + `volt_packages/` folder; `volt add <git url | folder>`.
3. Extension manifest v2 (`"contributes"`): libraries, panels, targets, themes, snippets,
   commands, file types. Old `"type"` manifests keep loading unchanged.
4. Bundled plugins ported to v2.
5. `lib/language-service.js`: diagnostics, completion, hover, definition, symbols.
   Used by Volt Studio directly and by `lsp/server.js` (stdio Language Server Protocol).
6. `vscode-volt/`: VS Code extension (grammar, snippets, language server client).
7. Three sample extensions + docs/EXTENSIONS.md.

## Step 5 - Volt3D

Additive, in `lib/volt3d.js`:

- Scene graph: `attach3d`, `scale3d`, `tilt3d`, `color3d`, `remove3d`.
- Collision: solid boxes, `player3d`/`walk3d` controller with gravity and jump, `ray3d`, `near3d`.
- Rendering: ambient occlusion in the `fx3d` pipeline, automatic instancing of static blocks,
  distance culling (`far3d`), soft shadow tuning, sky gradient.
- Audio: positional `sound ... at x, y, z`.
- Input: gamepad, mouse buttons.

Checked by running real pages in headless Chrome (WebGL via SwiftShader) and taking screenshots.

## Step 6 - Volt Studio

- Autocomplete, hover and go-to-definition (F12 / Ctrl+click) from the shared language service.
- All diagnostics shown at once, underlined at the exact columns; warnings in yellow.
- Editor word lists generated from the compiler instead of hand-copied.
- Preview reloads on save.

## Step 7 - Docs

- `docs/REFERENCE.md` updated for every new feature.
- `docs/VOLT3D.md`: 3D API reference.
- `docs/EXTENSIONS.md`: writing extensions and packages.
- `docs/GETTING_STARTED.md`: "Volt in 10 minutes".
- Every code block in the docs is compiled by the test suite.

## Out of scope for this pass (and why)

- **Rewriting the generator into per-target back ends.** Worth doing, but it cannot be done
  while also guaranteeing byte-identical output for 28,000 lines of games. Do it next, behind
  the golden tests added here.
- **Closures and first-class functions.** They do not map onto the C++ target and need a
  design decision about `async` in the JS targets. Proposal in NOTES.md.
- **A stepping debugger.** Needs a source map from generated code back to Volt; the import
  source map from step 1 is the first half of that.
