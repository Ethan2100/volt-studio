// =====================================================================
// #luau target addon - Roblox Luau output, meant to be pasted into a
// Script/LocalScript in Roblox Studio (or synced in with Rojo).
//
// All the real codegen is shared with #lua in
// ../lua-target/lua-common.js, since both compile the same Lua-family
// language - variables, functions, if/while/for/repeat, lists, print,
// and the built-in functions (random, contains, length, ...) work
// identically either way. What's different for #luau specifically:
//
//   - 'wait' compiles to the real, modern task.wait(seconds) instead of
//     a busy-wait loop.
//   - 'stop' compiles to a bare 'return' (there's no os.exit() in a
//     Roblox script - this just ends the script's own thread).
//   - 'clear' is a no-op (the Output window has no clear-from-script API).
//   - Roblox's actual game APIs - Instance.new(...), game:GetService(...),
//     workspace, CFrame/Vector3, :Connect(...) events, and so on - are
//     NOT modeled as new Volt syntax. Volt already has a real escape
//     hatch for "things the language doesn't have its own words for":
//     '#'/'##' raw-code lines (the same mechanism the #c++ target uses
//     for direct Arduino/register calls). Drop real Luau into those and
//     it's copied straight into the output, so 'workspace', 'game', and
//     every Roblox API are available exactly as they are in Studio.
// =====================================================================

const { generate: generateLua } = require('../lua-target/lua-common.js');

function generate(ast) {
  return generateLua(ast, { luau: true });
}

module.exports = { generate };
