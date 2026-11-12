// =====================================================================
//  #minecraft - compiles a Volt program into Minecraft commands.
//
//  The scoreboard is the machine: one objective holds the program
//  counter, every variable and the working registers, and running the
//  tick function once carries out exactly one instruction. Put it on a
//  repeating command block and Minecraft's own game loop becomes the
//  clock your program runs on.
//
//  Scoreboards hold whole numbers only, so text exists just long enough
//  to reach a tellraw: you can print it, but no variable can hold it.
// =====================================================================

const { lower, CompileError } = require('./lower');
const { emit } = require('./emit');

function generate(ast) {
  return emit(lower(ast, { target: 'minecraft' }), {});
}

module.exports = { generate, CompileError };
