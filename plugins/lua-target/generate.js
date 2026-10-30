// =====================================================================
// #lua target addon - plain Lua output (run with: lua thisfile.lua).
//
// Thin wrapper: all the real codegen is shared with #luau (Roblox) in
// lua-common.js, since both compile the same Lua-family language. See
// that file's header comment for the design notes (forward-declared
// top-level names, runtime-dispatched '+'/length()/contains(), etc).
// =====================================================================

const { generate: generateLua } = require('./lua-common.js');

function generate(ast) {
  return generateLua(ast, { luau: false });
}

module.exports = { generate };
