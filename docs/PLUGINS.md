# Plugins / addons

A plugin is just a folder with a `plugin.json` manifest. Drop it into:

- `<Volt Studio install>/plugins/` - bundled examples (the ones that ship
  with the app; see `plugins/vfx-engine`, `plugins/pin-diagram`,
  `plugins/pseudo-target`, `plugins/ui-kit`, `plugins/studio-kit` for
  working, tested examples of all three kinds).
- Your own plugins folder - open it from the **Library** tab's "Open
  plugins folder" button, or find it at `<userData>/plugins/` (Help →
  About shows where `userData` is for your OS). No build step, no install
  UI: just put the folder there and press "Rescan" in the Library tab.

A plugin in your own folder with the same `name` as a bundled one replaces
it, so you can fork and tweak an example without touching the app's files.

There are three plugin `type`s. Pick exactly one per plugin folder.

## `"library"` - reusable Volt snippets

```json
{
  "name": "my-library",
  "type": "library",
  "version": "1.0.0",
  "description": "What this library is for.",
  "snippets": [
    { "file": "thing.volt", "label": "Thing", "description": "What it does." }
  ]
}
```

Each `snippets` entry is a `.volt` file (relative to the plugin folder)
shown as a card in the **Library** tab. Clicking a card inserts that
file's contents at the cursor - it's a paste, not an import, so write the
snippet as something a person can drop into their own program (functions,
raw-code blocks, `##` top-of-file code), not a program on its own.

See `plugins/vfx-engine/engine.volt` for a real example: a canvas particle
engine written with Volt's `#` raw-code escape hatch, plus a small set of
`fn` wrappers (`burst`, `confetti`, `shake`, `flash`, `glow`, ...) so the
rest of a Volt program can call plain Volt functions instead of reaching
into JavaScript directly.

## `"panel"` - a UI tab

```json
{
  "name": "my-panel",
  "type": "panel",
  "version": "1.0.0",
  "description": "What this panel shows.",
  "panel": { "entry": "index.html", "title": "My Panel" }
}
```

`entry` is an HTML file (relative to the plugin folder) shown as its own
side tab, loaded in a sandboxed `<iframe sandbox="allow-scripts">`. That
sandbox means the panel:

- Has **no access** to Node, Electron, the filesystem, or anything in
  `window.volt` - it's an ordinary, isolated web page.
- Can use its own `<script>`, CSS and images, as long as they're files
  inside the plugin folder (loaded via `file://`, so no network fetches).
- Can talk to the rest of Volt Studio only via `postMessage` - there is no
  postMessage bridge wired up yet, so for now a panel is self-contained UI
  (a reference page, a calculator, a diagram) rather than something that
  reads or writes the current program.

See `plugins/pin-diagram/index.html` for a real example: a pure-reference
pinout table with no dependencies at all, picked to show what a panel can
do today without needing a bridge.

## `"target"` - a new compile target

```json
{
  "name": "my-target",
  "type": "target",
  "version": "1.0.0",
  "description": "What #mytarget does.",
  "target": {
    "id": "mytarget",
    "entry": "generate.js",
    "label": "My Target",
    "board": false,
    "fileExt": "mytarget.txt"
  }
}
```

This makes `#mytarget` a valid first line for a `.volt` file. `entry` is a
CommonJS module (relative to the plugin folder) exporting a `generate(ast)`
function:

```js
function generate(ast) {
  // ast is the array of top-level statement nodes Volt's own lexer and
  // parser already produced - the exact same tree the built-in C++,
  // Python, Ruby, JS and HTML generators work from. Return a string.
  return '...';
}
module.exports = { generate };
```

Your `generate(ast)` never touches Volt's lexer or parser, and can't
break the built-in targets - it's handed the real, already-parsed AST and
just needs to turn it into text. `label` is shown in Volt Studio's output
panel; `board` controls whether the board/port/upload controls show for
this target (leave `false` unless you're compiling to something you'll
flash onto hardware); `fileExt` picks the saved output file's extension
(defaults to `<name>.<id>.txt`).

See `plugins/pseudo-target/generate.js` for a complete, tested example: a
`#pseudo` target that turns any Volt program into plain-English
pseudocode. It's a good template to copy from - it handles every node kind
below.

### AST node kinds

Every node has a `kind` and a `line`. Fields beyond that, by kind:

| kind | fields |
|---|---|
| `Let` | `name`, `value` (expr), `topLevel` (bool) |
| `Assign` | `name`, `value` (expr) |
| `Fn` | `name`, `params` (string[]), `body` (statement[]) |
| `Return` | `value` (expr or null) |
| `Forever` | `body` (statement[]) |
| `Every` | `ms` (number literal string), `body` (statement[]) |
| `When` | `pin`, `body` (statement[]) |
| `WhenKey` | `key` (string), `body` (statement[]) |
| `Write` | `pin`, `action` (`'on'` \| `'off'` \| `'toggle'`) |
| `SetSpeed` | `pin`, `value` (expr) |
| `Set` | `pin`, `value` (expr) |
| `Fade` | `pin`, `value` (expr), `time` (expr, in ms) |
| `Tone` | `pin`, `freq` (expr), `time` (expr or null, in ms) |
| `Wait` | `time` (expr, in ms) |
| `Print` | `value` (expr) |
| `Show` | `value` (expr) |
| `Clear` | - |
| `Stop` | - |
| `If` | `cond` (expr), `then` (statement[]), `otherwise` (statement[] or null) |
| `For` | `name`, `start` (expr), `end` (expr), `body` (statement[]) |
| `Repeat` | `count` (expr), `body` (statement[]) |
| `While` | `cond` (expr), `body` (statement[]) |
| `Break` | - |
| `Button` | `label` (expr), `body` (statement[]) - web pages only |
| `Title` | `value` (expr) - web pages only |
| `Html` | `value` (expr) - web pages only |
| `CallStmt` | `call` (a `Call` expr, used as a statement) |
| `Raw` | `code` (string) - a `# ...` raw-code line |
| `RawTop` | `code` (string) - a `## ...` top-of-file raw-code line |
| `Pin` | `name`, `num`, `nums` (number[], for multi-pin), `mode` |
| `Binary` (expr) | `op`, `left` (expr), `right` (expr) |
| `Unary` (expr) | `op`, `operand` (expr) |
| `Bool` (expr) | `value` (bool) |
| `Number` (expr) | `value` (string) |
| `String` (expr) | `value` (string) |
| `Var` (expr) | `name` |
| `Call` (expr) | `name`, `args` (expr[]) |
| `Read` (expr) | `pin` |
| `Ask` (expr) | `prompt` (expr) |
| `Uptime` (expr) | - |

`time` fields (on `Wait`, `Fade`, `Tone`) are always expressions, even for
a literal like `500ms` (which becomes a `Number` node) - never a plain
number, so always run them through your own expression-to-string helper
rather than interpolating directly. The same goes for `Button`'s `label`
and `Print`/`Show`'s `value`.

## How plugins are loaded

`lib/plugins.js` scans both plugin folders at startup (`scanPlugins`),
skipping anything without a `plugin.json`, and reports (not throws) a
clear error for a folder that has one but gets something wrong - a broken
plugin never stops the app or the other plugins from loading. `target`
plugins are registered into the compiler via `volt.registerTarget()`
(`loadTargetPlugins`); `library` and `panel` plugins are read on demand
by the renderer through `plugins:readFile` / `plugins:panelUrl`. Reading
a plugin's files is sandboxed against path traversal - a plugin can't
reference anything outside its own folder.
