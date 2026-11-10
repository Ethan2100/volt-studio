# Volt for VS Code

Syntax colours, mistakes underlined as you type, autocomplete, hover and go to definition for
`.volt` files - the same ones Volt Studio has, because both use `lib/language-service.js`.

## Installing it

The extension needs Volt Studio (or a copy of this repository) on the same computer: that is
where the compiler and the language server live.

1. Copy this `vscode-volt` folder into your VS Code extensions folder:
   - Windows: `%USERPROFILE%\.vscode\extensions\volt-language`
   - macOS and Linux: `~/.vscode/extensions/volt-language`
2. Restart VS Code and open a `.volt` file.

If it can't find Volt, set **volt.path** in settings to the folder holding `compiler/`, `lib/`
and `lsp/` - for example `C:\Users\you\AppData\Local\Programs\Volt Studio\resources\app`.

## What you get

| | |
|---|---|
| Colours | Built from the compiler's own word lists, so new built-ins are coloured too |
| Problems | Every error *and* warning, underlined exactly where they are |
| Autocomplete | Your own variables, functions, parameters and types first, then built-ins that work in this file's target |
| Hover | What a built-in does, or where one of your names was made |
| Go to definition | F12, or Ctrl+click |
| Outline | The functions, variables and types in the file |
| Commands | **Volt: Build this file** and **Volt: Run this file** |

## Keeping the colours in step

The grammar is generated. After adding a built-in to Volt:

```
node vscode-volt/build-grammar.js
```

`test/suite/13-vscode.js` fails if the committed grammar is out of date, so this is hard to forget.

## Other editors

Any editor that speaks LSP can use the same server directly:

```
node /path/to/volt-studio/lsp/server.js --stdio
```
