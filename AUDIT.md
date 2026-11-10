# Volt audit

Audit of `Ethan2100/volt-studio` at commit `193ea2e` (Volt compiler 3.3.0, Volt Studio 1.4.0),
done before any change was made. Everything below was checked against the code, and the
numbers come from compiling every `.volt` file in the repo.

## 1. What is in the repo

| Part | Where | Size | What it is |
|---|---|---|---|
| Compiler | `compiler/volt.js` | 3,552 lines, one file | Lexer, parser, generator for 6 targets, plus the whole browser game runtime as string arrays |
| 3D runtime | `lib/volt3d.js` + `lib/three.min.js` | 510 lines + Three.js | Runtime behind `world3d`, `block3d`, `fx3d` ... |
| Studio (main) | `main.js`, `preload.js`, `lib/*.js` | ~1,300 lines | Electron main process: files, compile, upload, run, serial monitor, plugins, AI chat |
| Studio (page) | `renderer/` | ~1,900 lines | CodeMirror 5 editor, tabs, console, Library, AI panel |
| Plugins | `plugins/` (11) | | 7 libraries, 2 panels, 3 targets (`#lua`, `#luau`, `#pseudo`) |
| Examples | `examples/` | 49 `.volt` files, 28k lines | Includes Moonwell, Yokai Descent, One More Floor, Nightshift, 99 Nights, Cursed Arena |
| Docs | `docs/REFERENCE.md`, `docs/PLUGINS.md` | 1,130 + 207 lines | |
| Tests | `test/*.js` | 8 files | All of them need a running Electron window |

Not in the repo: The Sevenfold Oath, Lingo Quest and the VFX Studio. They could not be
checked, so "every game still compiles" below means every game *in this repo*.

## 2. Architecture

```
source text
  -> resolveImports()   textual splice of  import "x.volt"  lines
  -> detectTarget()     first line  #c++ / #python / #html ...
  -> lex()              tokens { type, value, line }
  -> parse()            AST (plain objects with .kind and .line)
  -> generate()         one 1,700-line function with a switch per node kind
                        and  if (py) / if (rb) / if (js) / cpp  inside each case
```

Type inference happens during generation (`genExpr` returns `{ code, type }`), so there is
no separate checking pass. Plugin targets get the AST and bring their own generator.

## 3. What is solid

- **Error messages are written for beginners.** Almost every `VoltError` says what to type
  instead, and misspelled names get a "did you mean" suggestion.
- **Generated code is clean and correct in the details**: integer division rules per target,
  Ruby truthiness, C++ `String` joins, Arduino macro pitfalls, `</script>` escaping.
- **The parser avoids keyword bloat.** Game words (`draw`, `box`, `write` ...) are contextual,
  so old programs with a variable called `box` still compile.
- **The plugin loader is careful**: path-escape checks, sandboxed panels, user plugins override
  bundled ones, one broken plugin does not stop the rest.
- **The 3D runtime already does more than the docs say**: PBR materials (`shine3d`), shadows,
  HDR bloom with ACES tone mapping, vignette, grain, rigged `.glb` models with animation
  blending, particles, a procedural environment map.
- **Compile speed is fine**: all 49 files in 0.6 s; the largest (Moonwell, 6,815 lines) in ~100 ms.

## 4. Bugs found

| # | Bug | Effect |
|---|---|---|
| B1 | `dist` was added as a built-in, which made it a reserved name | **`examples/roguelike/yokai-descent.volt` no longer compiles** (line 1340: it has a parameter and a variable called `dist`). Every new built-in can break old programs the same way. |
| B2 | `package.json` `build.files` does not list `plugins/**` | The installed app ships with **no bundled plugins**: no `#lua`/`#luau`, no World Studio, no Flipbook, no library cards. They only work when running from source. |
| B3 | Errors after an `import` point at the wrong line | Line numbers refer to the merged text, and the file name is lost. |
| B4 | `import` is only recognised with no leading spaces | An indented `import "x.volt"` gives the unrelated error `Expected '=' after 'import'`. |
| B5 | Three.js (795 KB) is read from disk and regex-escaped on every 3D compile | Live compile while typing re-does it each keystroke burst. |
| B6 | `staticType` and `genExpr` are two separate type guessers that can disagree | A top-level `let x = someFn()` is typed `any`, so later assignments to it are never type-checked. |
| B7 | A `let` inside a function cannot reuse the name of a top-level variable, although a parameter can | `'i' already exists` in a function when some other part of a 6,000-line game has a top-level `i`. |
| B8 | `test/` cannot run in CI or without a display | Nothing guards the compiler against regressions like B1. |

## 5. What is fragile

- **One error per compile, line only.** No column, no end position, no error code, no list.
  The editor can only highlight a whole line, and a language server has nothing to underline.
- **The generator is one closure.** Adding a statement means touching the parser switch, the
  generator switch and usually four `if (lang)` branches. There is no table of built-ins with
  signatures, so the editor keeps its own hand-copied lists (`renderer/volt-mode.js`), which
  are already out of date (no `sqrt`, `pow`, `join`, `split`, `sin`, `cos`, `fetchText` ...).
- **The game runtime is JavaScript inside JavaScript strings** (`GAME_RUNTIME`, 415 lines of
  quoted lines). It cannot be linted, tested or syntax-highlighted.
- **Reserved names are global across targets**, so adding any built-in is a breaking change (B1).
- **`import` is copy-paste.** No namespaces, no packages, no versions, no way to share a
  library except copying files or pasting a Library card.

## 6. Missing language features

Ordered by how much the example games work around them:

1. **Text building.** `"HP: " + text(hp) + "/" + text(max)` everywhere. No interpolation.
2. **No `continue`.** Loops use nested `if` pyramids instead.
3. **No `match`.** Long `if / else if` chains on a state string or number.
4. **No default arguments.** Wrapper functions exist only to fill in defaults.
5. **Structs only in `#html`.** `#js`, `#python` and `#ruby` have no records at all.
6. **Small standard library.** No `floor`/`round`/`ceil`, `trim`, `replace`, `startsWith`,
   `indexOf`, `sort`, `reverse`, `slice`, `sum`, `first`/`last`, `fetchJson`, `now`.
7. **No decimals in the 3D API.** Everything is integers: centimetres, tenths of a degree,
   thousandths for `sin3`. Movement code reads `px += fx * 4 / 1000`.
8. **No closures or first-class functions**, no maps/dictionaries, no modules with namespaces.
9. **Functions only at the top level**, and `fn` cannot be declared after use in some targets.

The clearest symptom: the three biggest engines in the repo (`combat3d/engine3d.volt`,
`combat-vfx/engine.volt`, `flipbook-template.volt`) are almost entirely `#` raw JavaScript
lines. When work gets serious, people leave Volt.

## 7. Where Volt is harder to write than it should be

| Task | Today | Lines |
|---|---|---|
| First-person walking with mouse look | Hand-written yaw/pitch, `sin3`/`cos3`, fixed-point maths, no collision | ~20 |
| Stop the player walking through walls | Not available; each game writes its own grid check | 30+ |
| Show a number in text | `"Score: " + text(score)` | |
| Skip one loop iteration | wrap the rest of the body in `if` | |
| Mouse position or click in a 2D game | Not available without raw JS | |
| Gamepad | Not available | |
| Get JSON from a URL | `fetchText` then nothing to parse it with | |
| Remove one 3D object | Not available (`show3d id, 0` hides it, it stays in memory) | |
| Loop over a list with the position | manual `let i = 0 ... i += 1` | 3 |

## 8. Gaps against real engines (Volt3D)

Present: forward renderer, PBR standard material, point/spot/directional shadows, fog, bloom,
ACES tone mapping, vignette, grain, glTF with skeletal animation, sprite particles.

Missing:

- **Scene graph**: objects cannot be parented, scaled, tilted, recoloured or deleted.
- **Collision and physics**: none. No raycast, no overlap test, no character controller.
- **Instancing**: every `block3d` is its own mesh and draw call. 1,000 blocks = 1,000 calls.
- **Culling/LOD**: no distance culling beyond the camera far plane (fixed at 80 m).
- **Ambient occlusion**: none, so flat-coloured rooms look flat.
- **Audio**: 2D only; no positional sound.
- **Input**: keyboard + pointer-lock mouse only; no gamepad, no mouse buttons.
- **No decimals** in positions (see 6.7), so slow movement stutters at 1 cm steps.

## 9. Volt Studio gaps

- Autocomplete is a prefix match over hard-coded word lists; it does not know the user's
  functions' parameters, struct fields, or which words are valid for the current target.
- No go-to-definition, no hover help, no outline.
- One error at a time, whole-line highlight.
- No debugger or structured logging; `print` is the only tool.
- Preview does not reload on save; you press Run again.
- Plugins cannot add themes, snippets for autocomplete, menu commands or file types.
- Volt only works inside Volt Studio: there is no VS Code support and no language server.

## 10. Performance

| Measure | Value |
|---|---|
| All 49 files, cold | 612 ms |
| Moonwell (6,815 lines) | 104 ms |
| 99 Nights (2,160 lines, 8.7 MB output with embedded assets) | 79 ms |
| Three.js read + escape per 3D compile | ~6 ms each time (avoidable) |
| `closestName` on an unknown name | O(names x length^2), only on the error path |

Compile time is not a problem today. The avoidable costs are re-reading Three.js and
re-embedding unchanged assets as base64 on every live compile.
