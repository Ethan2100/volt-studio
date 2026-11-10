# Sharing and extending Volt

Three ways to give Volt something it doesn't have:

| | What it is | Where it lives |
|---|---|---|
| **A package** | Volt code other programs `import` | `volt_packages/` in your project |
| **A plugin** | Something Volt Studio itself gains: a tab, a library of snippets, a new output language | Volt Studio's plugins folder |
| **An editor** | Volt's mistakes, autocomplete and hover in any editor that speaks LSP | `lsp/server.js` |

---

## Packages

A package is a folder of `.volt` files with a `volt.json` in it. Once installed, any program can
`import` it by name.

### Using one

```
volt add ./packages/tween          a folder on this computer
volt add ethan2100/volt-tween      a GitHub repository
volt add https://example.com/x.git any git address
```

Then in your program:

```volt
#html
import "tween"
canvas 320, 180

let startedAt = uptime

every frame {
  let t = easeOut(progress(startedAt, 1200))
  paint "#14111a"
  box lerp(20, 280, t), 80, 20, 20 color "#ffd23f"
}
```

`volt add` copies the package into `volt_packages/` and writes it into your project's `volt.json`:

```json
{
  "name": "my-game",
  "version": "1.0.0",
  "dependencies": {
    "tween": "ethan2100/volt-tween"
  }
}
```

Keep `volt.json` and leave `volt_packages/` out of git (it is rebuilt by `volt install`), the same
way `package.json` and `node_modules` work.

| Command | What it does |
|---|---|
| `volt add <source>` | Install a package |
| `volt remove <name>` | Take one out |
| `volt list` | What this project has |
| `volt install` | Install everything `volt.json` asks for |

### Where a package is looked for

`import "name"` looks for `volt_packages/name/`:

1. beside the program,
2. then in each folder above it, up to the top of the drive.

So one `volt_packages` at the root of a project serves every `.volt` file in it, however deep.

`import "name/other.volt"` reaches a particular file inside a package. `import "file.volt"` with a
`.volt` on the end is the old behaviour and still just means the file next to yours.

### Writing one

A package is a folder with `volt.json` and at least one `.volt` file:

```
volt-tween/
  volt.json
  tween.volt
```

```json
{
  "name": "tween",
  "version": "1.0.0",
  "description": "Smooth movement: easing curves, springs and a shake, for games.",
  "main": "tween.volt"
}
```

`main` is what `import "tween"` gets. Without it, Volt looks for `tween.volt`, `index.volt`,
`main.volt` or `lib.volt`.

The file itself is ordinary Volt with **no first line** - it takes on the target of whatever
program imports it:

```volt
// A library: just functions, no #target line of its own.
fn easeOut(percent) {
  let amount = clamp(percent, 0, 100)
  return 100 - (100 - amount) * (100 - amount) / 100
}
```

To share it, put that folder on GitHub. People then install it with `volt add you/volt-tween` -
there is nothing to publish and no registry to sign up for.

### Two that come with Volt

In `packages/`:

- **tween** - `easeIn` `easeOut` `easeInOut` `easeBack` `easeBounce` `progress` `shake`.
  Everything takes and gives 0 to 100, so it drops straight into `lerp`.
- **grid** - a flat list used as a 2D grid: `gridNew` `gridGet` `gridSet` `gridAround`
  `gridCount` `gridRow`. Squares off the grid read as a value you choose, so edges need no
  special case.

```
volt add ./packages/grid
```

### Things worth knowing

- A package's functions share one pool of names with the program that imports it, so give them a
  prefix (`gridGet`, not `get`).
- Importing the same package twice is fine; the second time is skipped.
- Some words can't be used as names (`p`, `map`, `over`, `step` ...). `volt check` will tell you.
- An error inside a package names the package's own file and line, and the line of your `import`.

---

## Plugins for Volt Studio

A plugin adds something to the app itself. There are three kinds - a library of snippets, a tab,
or a whole new output language - and they are covered in full in **[PLUGINS.md](PLUGINS.md)**.

In short: a folder with a `plugin.json`, dropped into Volt Studio's plugins folder (the Library
tab has a button that opens it). No build step.

**Package or plugin?** A package is Volt code you `import`, and works everywhere - the command
line, VS Code, Volt Studio. A plugin changes Volt Studio and only works there. If you are sharing
Volt functions, write a package.

---

## Volt in another editor

`lsp/server.js` is a Language Server. Any editor that speaks LSP can use it to get the same
errors, warnings, autocomplete, hover, go to definition and outline Volt Studio has:

```
node /path/to/volt-studio/lsp/server.js --stdio
```

For VS Code that is already wrapped up in **[vscode-volt](../vscode-volt/README.md)** - copy that
folder into your extensions folder.

### Building on the language service directly

If you are writing a tool rather than an editor plugin, `lib/language-service.js` is the same
thing without the protocol:

```js
const ls = require('./lib/language-service.js');

ls.diagnostics(source, { baseDir });   // every error and warning, with ranges
ls.completions(source, line, col);     // what can be typed here
ls.hover(source, line, col);           // what the thing under the cursor is
ls.definition(source, line, col);      // where that name is made
ls.symbols(source);                    // an outline of the file
ls.highlightWords();                   // the words to colour, straight from the compiler
```

Lines and columns start at 1. Nothing throws: it is built to be asked between keystrokes about
half-written code.

And the compiler itself:

```js
const volt = require('./compiler/volt.js');

volt.compile(source, { baseDir });     // { target, code } - throws on the first mistake
volt.check(source, { baseDir });       // { ok, target, code, diagnostics } - never throws
volt.formatProblem(d, file, sourceOf); // a problem written out with a caret under it
```
