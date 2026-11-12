// =====================================================================
//  #excel - compiles a Volt program into a spreadsheet that runs it.
//
//  Not a data export: the sheet is the machine. The program is lowered to
//  a flat list of instructions, and every row of the sheet is one tick of
//  the clock - it reads the row above, looks at that row's program
//  counter, and applies the one instruction it points at. A loop is a
//  formula that sets the next program counter backwards. Scroll down and
//  you are watching the program execute.
//
//  No macros and no VBA - only formulas, so it runs in Excel, LibreOffice
//  and Google Sheets alike.
// =====================================================================

const { lower, CompileError } = require('./lower');
const { emit } = require('./emit');

function generate(ast) {
  const lowered = lower(ast);
  return emit(lowered, {});
}

module.exports = { generate, CompileError };
