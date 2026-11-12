// =====================================================================
//  Instruction list -> a spreadsheet that executes it.
//
//  Layout of the generated sheet:
//
//    A  Step      how many instructions have run
//    B  PC        the program counter: which instruction runs next
//    C  Next      a readable disassembly of the instruction at that PC
//    D.. one column per variable in the program
//    ..  Output   whatever `print` emitted on this step
//        (gap)
//    ..  the program listing, used by column C and kept for the reader
//
//  Row 2 is the starting state. Every row after it is the state after one
//  more instruction: each cell reads the row above, looks at that row's PC
//  and applies whatever that one instruction did. A loop is just a formula
//  that sets the next PC backwards.
//
//  Formulas are written in R1C1, so the same formula text is correct on
//  every row - which keeps the file small no matter how many steps it runs.
// =====================================================================

const { CompileError } = require('./lower');

const DEFAULT_STEPS = 400;
const MAX_IF_NESTING = 60;   // Excel allows 64 levels; leave headroom

// --- XML / formula escaping -----------------------------------------
const xml = (s) => String(s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

// An Excel string literal: wrap in quotes, double any quote inside.
const lit = (s) => `"${String(s).replace(/"/g, '""')}"`;

// =====================================================================
//  Working out which columns hold text and which hold numbers.
//
//  Volt's `+` both adds and joins text, and which one it means depends on
//  the values. A cell can test that as it runs - ISTEXT(a) - but the test
//  has to name both sides twice, so a chain like "a " + b + " c " + d
//  doubles in size at every `+` and a handful of them turns into megabytes
//  of formula. Nearly always the answer is obvious from the program, so we
//  work out what we can first and only fall back to the runtime test where
//  a column genuinely holds both.
//
//  Types are 'num', 'text', 'any' (definitely mixed) and null (not known
//  yet) - repeat the pass until nothing changes.
// =====================================================================
const TEXT_BUILTINS = new Set(['text', 'upper', 'lower', 'part']);

function inferTypes(prog, vars) {
  const t = new Map(vars.map((v) => [v, null]));
  const join = (a, b) => (a === null ? b : b === null ? a : a === b ? a : 'any');

  const BOOL_OPS = new Set(['==', '!=', '<', '>', '<=', '>=', '&&', '||']);
  const numish = (x) => x === 'num' || x === 'bool';

  const typeOf = (n) => {
    switch (n.kind) {
      case 'String': return 'text';
      case 'Number': return 'num';
      case 'Bool': return 'bool';
      case 'Var': return t.get(n.name) ?? null;
      case 'Unary': return n.op === '!' ? 'bool' : 'num';
      case 'Call':
        if (TEXT_BUILTINS.has(n.name)) return 'text';
        return n.name === 'contains' ? 'bool' : 'num';
      case 'Binary': {
        if (BOOL_OPS.has(n.op)) return 'bool';
        if (n.op !== '+') return 'num';            // plain arithmetic
        const a = typeOf(n.left), b = typeOf(n.right);
        if (a === 'text' || b === 'text') return 'text';
        if (a === 'any' || b === 'any') return 'any';
        if (numish(a) && numish(b)) return 'num';
        return null;                                // still unknown
      }
      default: return 'any';
    }
  };

  for (let pass = 0; pass < vars.length + 3; pass++) {
    let changed = false;
    for (const ins of prog) {
      if (ins.op !== 'SET' || ins.init) continue;
      const merged = join(t.get(ins.name), typeOf(ins.expr));
      if (merged !== t.get(ins.name)) { t.set(ins.name, merged); changed = true; }
    }
    if (!changed) break;
  }
  // A column never written to still starts life as the number 0.
  for (const v of vars) if (t.get(v) === null) t.set(v, 'num');
  return { types: t, typeOf };
}

// =====================================================================
//  Expression -> Excel formula (R1C1, reading the row above)
// =====================================================================
function makeExprCompiler(colOf, typeOf) {
  const prev = (name) => `R[-1]C${colOf(name)}`;

  // Volt writes a true/false as the words "true" and "false"; a spreadsheet
  // would show TRUE, or 1 once it has been through a CSV. Convert when we
  // know the value is a true/false, and ask the cell when we can't tell.
  const asText = (code, type) => {
    if (type === 'bool') return `IF(${code},"true","false")`;
    if (type === 'any') return `IF(ISLOGICAL(${code}),IF(${code},"true","false"),${code})`;
    return code;
  };

  function ex(n) {
    switch (n.kind) {
      case 'Number': return n.value;
      case 'Bool':   return n.value ? 'TRUE' : 'FALSE';
      case 'String': return lit(n.value);
      case 'Var':    return prev(n.name);

      case 'Unary':
        if (n.op === '-') return `(-${ex(n.operand)})`;
        if (n.op === '!') return `NOT(${ex(n.operand)})`;
        throw new CompileError(`Unknown operator '${n.op}'.`);

      case 'Binary': {
        const a = ex(n.left), b = ex(n.right);
        switch (n.op) {
          // Volt's + both adds and joins text. Usually the program makes
          // clear which is meant; only ask the cell when it genuinely isn't.
          case '+': {
            const ta = typeOf(n.left), tb = typeOf(n.right);
            if (ta === 'text' || tb === 'text') return `(${asText(a, ta)}&${asText(b, tb)})`;
            if (ta !== 'any' && tb !== 'any' && ta !== null && tb !== null) return `(${a}+${b})`;
            return `IF(OR(ISTEXT(${a}),ISTEXT(${b})),${a}&${b},${a}+${b})`;
          }
          case '-': return `(${a}-${b})`;
          case '*': return `(${a}*${b})`;
          // Volt divides whole numbers the way whole numbers divide - 7/2 is 3 -
          // and only gives decimals once a decimal is involved. Column values
          // carry no type, so the sheet has to check as it goes.
          case '/': return `IFERROR(IF(AND(${a}=INT(${a}),${b}=INT(${b})),TRUNC(${a}/${b}),${a}/${b}),0)`;
          // Not Excel's MOD: that follows the sign of the divisor, Volt's follows
          // the dividend (-7 % 3 is -1, not 2).
          case '%': return `IFERROR(${a}-${b}*TRUNC(${a}/${b}),0)`;
          case '==': return `(${a}=${b})`;
          case '!=': return `(${a}<>${b})`;
          case '<':  return `(${a}<${b})`;
          case '>':  return `(${a}>${b})`;
          case '<=': return `(${a}<=${b})`;
          case '>=': return `(${a}>=${b})`;
          case '&&': return `AND(${a},${b})`;
          case '||': return `OR(${a},${b})`;
          default: throw new CompileError(`Unknown operator '${n.op}'.`);
        }
      }

      case 'Call': return builtin(n, (x) => ex(x));
      default: throw new CompileError(`Cannot put '${n.kind}' into a cell.`);
    }
  }
  return { ex, asText };
}

// Volt's built-in functions, in spreadsheet terms.
function builtin(n, ex) {
  const a = (n.args || []).map(ex);
  const need = (k) => {
    if (a.length !== k) throw new CompileError(`'${n.name}' takes ${k} value(s), got ${a.length} (line ${n.line}).`);
  };
  switch (n.name) {
    case 'abs':   need(1); return `ABS(${a[0]})`;
    // Volt rounds sqrt down to a whole number.
    case 'sqrt':  need(1); return `IFERROR(TRUNC(SQRT(${a[0]})),0)`;
    case 'sign':  need(1); return `SIGN(${a[0]})`;
    case 'min':   need(2); return `MIN(${a[0]},${a[1]})`;
    case 'max':   need(2); return `MAX(${a[0]},${a[1]})`;
    case 'sin':   need(1); return `SIN(${a[0]}*PI()/180)`;
    case 'cos':   need(1); return `COS(${a[0]}*PI()/180)`;
    case 'constrain': need(3); return `MIN(MAX(${a[0]},${a[1]}),${a[2]})`;
    // map truncates the scaled part before shifting, exactly as Volt does.
    case 'map':   need(5);
      return `IFERROR(TRUNC((${a[0]}-${a[1]})*(${a[4]}-${a[3]})/(${a[2]}-${a[1]}))+${a[3]},0)`;
    // number() parses a whole number, so "3.7" becomes 3 and junk becomes 0.
    case 'number': need(1); return `IFERROR(TRUNC(VALUE(${a[0]})),0)`;
    case 'text':  need(1); return `(${a[0]}&"")`;
    case 'length': need(1); return `LEN(${a[0]}&"")`;
    case 'upper': need(1); return `UPPER(${a[0]}&"")`;
    case 'lower': need(1); return `LOWER(${a[0]}&"")`;
    // FIND, not SEARCH: Volt's contains() is case-sensitive.
    case 'contains': need(2); return `ISNUMBER(FIND(${a[1]}&"",${a[0]}&""))`;
    // part() counts from 0; MID counts from 1.
    case 'part':  need(3); return `IFERROR(MID(${a[0]}&"",(${a[1]})+1,${a[2]}),"")`;
    case 'random':
      throw new CompileError(
        `'random' cannot work here (line ${n.line}). A spreadsheet's random functions ` +
        `redraw every time anything changes, which would reshuffle the whole run on ` +
        `each edit. Pick the number yourself, or read it from a cell.`);
    default:
      throw new CompileError(`The #excel target has no '${n.name}' (line ${n.line}).`);
  }
}

// Build a nested IF chain: cases = [[test, value], ...], plus a fallback.
function ifChain(cases, fallback, what) {
  if (cases.length > MAX_IF_NESTING)
    throw new CompileError(
      `${what} is written to in ${cases.length} places; a spreadsheet formula ` +
      `can only nest about ${MAX_IF_NESTING} decisions deep. Try shortening the program.`);
  let out = fallback;
  for (let i = cases.length - 1; i >= 0; i--) out = `IF(${cases[i][0]},${cases[i][1]},${out})`;
  return out;
}

// A readable one-line disassembly, for the listing and column C.
function disasm(ins, i, srcOf) {
  switch (ins.op) {
    case 'SET':   return `${ins.name} = ${srcOf(ins.expr)}`;
    case 'PRINT': return `print ${srcOf(ins.expr)}`;
    case 'JMP':   return `go to step ${ins.target}`;
    case 'JZ':    return `if not (${srcOf(ins.expr)}) go to step ${ins.target}`;
    case 'NOP':   return `(${ins.note})`;
    case 'HALT':  return 'stop';
    default:      return ins.op;
  }
}

// Turn an expression back into something close to Volt source, for the listing.
function srcOf(n) {
  if (!n) return '';
  switch (n.kind) {
    case 'Number': return n.value;
    case 'Bool':   return n.value ? 'true' : 'false';
    case 'String': return JSON.stringify(n.value);
    case 'Var':    return n.name;
    case 'Unary':  return `${n.op}${srcOf(n.operand)}`;
    case 'Binary': return `${srcOf(n.left)} ${n.op} ${srcOf(n.right)}`;
    case 'Call':   return `${n.name}(${(n.args || []).map(srcOf).join(', ')})`;
    default:       return n.kind;
  }
}

// =====================================================================
//  The sheet
// =====================================================================
function emit({ prog, vars }, opts = {}) {
  const steps = opts.steps || DEFAULT_STEPS;
  const title = opts.title || 'Volt program';

  // --- columns -------------------------------------------------------
  const C_STEP = 1, C_PC = 2, C_INS = 3;
  const C_VAR0 = 4;
  const varCol = new Map(vars.map((v, i) => [v, C_VAR0 + i]));
  const C_OUT = C_VAR0 + vars.length;
  const C_LIST_I = C_OUT + 2;          // one blank column as a gutter
  const C_LIST_T = C_OUT + 3;

  const colOf = (name) => {
    const c = varCol.get(name);
    if (!c) throw new CompileError(`Compiler bug: no column for '${name}'.`);
    return c;
  };
  const { typeOf } = inferTypes(prog, vars);
  const { ex, asText } = makeExprCompiler(colOf, typeOf);

  const pcPrev = `R[-1]C${C_PC}`;
  const lastList = 1 + prog.length;    // listing occupies rows 2..lastList

  // --- B: the program counter ----------------------------------------
  // Everything steps forward by one unless it is a jump or a stop.
  const pcCases = [];
  prog.forEach((ins, i) => {
    if (ins.op === 'JMP')  pcCases.push([`${pcPrev}=${i}`, String(ins.target)]);
    if (ins.op === 'HALT') pcCases.push([`${pcPrev}=${i}`, String(i)]);
    if (ins.op === 'JZ')   pcCases.push([`${pcPrev}=${i}`, `IF(${ex(ins.expr)},${i + 1},${ins.target})`]);
  });
  const fPC = '=' + ifChain(pcCases, `${pcPrev}+1`, 'The program counter');

  // --- one column per variable ---------------------------------------
  // A variable only changes on the steps that assign to it; every other
  // step just carries the value down from the row above.
  const fVar = vars.map((v) => {
    const cases = [];
    prog.forEach((ins, i) => {
      if (ins.op === 'SET' && ins.name === v) cases.push([`${pcPrev}=${i}`, ex(ins.expr)]);
    });
    return '=' + ifChain(cases, 'R[-1]C', `'${v}'`);
  });

  // --- the output column ----------------------------------------------
  const outCases = [];
  prog.forEach((ins, i) => {
    if (ins.op === 'PRINT') outCases.push([`${pcPrev}=${i}`, asText(ex(ins.expr), typeOf(ins.expr))]);
  });
  const fOut = '=' + ifChain(outCases, '""', 'The output column');

  // --- the other two trace columns -------------------------------------
  const fStep = '=R[-1]C+1';
  // The instruction this row just carried out - so it lines up with the
  // values and the output it produced, rather than with the next step.
  const fIns = `=IFERROR(INDEX(R2C${C_LIST_T}:R${lastList}C${C_LIST_T},${pcPrev}+1),"")`;

  // =====================================================================
  //  Write it out as SpreadsheetML - plain text, but Excel, LibreOffice
  //  and Google Sheets all open it and keep the formulas live.
  // =====================================================================
  const out = [];
  const w = (s) => out.push(s);

  // `at` jumps the cell to an absolute column, leaving a gap before it.
  const numCell = (v, f, at) => {
    const ix = at ? ` ss:Index="${at}"` : '';
    return f
      ? `<Cell${ix} ss:Formula="${xml(f)}"><Data ss:Type="Number">0</Data></Cell>`
      : `<Cell${ix}><Data ss:Type="Number">${v}</Data></Cell>`;
  };
  const strCell = (v, f, style, at) => {
    const st = style ? ` ss:StyleID="${style}"` : '';
    const ix = at ? ` ss:Index="${at}"` : '';
    return f
      ? `<Cell${ix}${st} ss:Formula="${xml(f)}"><Data ss:Type="String"></Data></Cell>`
      : `<Cell${ix}${st}><Data ss:Type="String">${xml(v)}</Data></Cell>`;
  };

  w('<?xml version="1.0"?>');
  w('<?mso-application progid="Excel.Sheet"?>');
  w('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
  w(' xmlns:o="urn:schemas-microsoft-com:office:office"');
  w(' xmlns:x="urn:schemas-microsoft-com:office:excel"');
  w(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
  w(`<DocumentProperties xmlns="urn:schemas-microsoft-com:office:office"><Title>${xml(title)}</Title><Author>Volt #excel target</Author></DocumentProperties>`);
  w('<Styles>');
  w('<Style ss:ID="hdr"><Font ss:Bold="1"/><Interior ss:Color="#DDDDDD" ss:Pattern="Solid"/></Style>');
  w('<Style ss:ID="mono"><Font ss:FontName="Consolas"/></Style>');
  w('<Style ss:ID="note"><Font ss:Italic="1" ss:Color="#666666"/></Style>');
  w('</Styles>');
  w('<Worksheet ss:Name="VM">');
  w('<Table>');

  // header row
  const headers = ['Step', 'PC', 'Just ran', ...vars, 'Output'];
  w('<Row>' + headers.map((h) => strCell(h, null, 'hdr')).join('') +
    strCell('#', null, 'hdr', C_LIST_I) + strCell('Program', null, 'hdr') + '</Row>');

  // Row 2: the starting state, and the first row of the program listing.
  {
    const cells = [
      numCell(0), numCell(0),
      strCell('(start)', null, 'note'),
      ...vars.map(() => numCell(0)),
      strCell(''),
    ];
    w('<Row>' + cells.join('') + listingCells(0) + '</Row>');
  }

  // Rows 3.. : one row per executed instruction.
  for (let r = 1; r <= steps; r++) {
    const cells = [
      numCell(0, fStep),
      numCell(0, fPC),
      strCell('', fIns, 'mono'),
      ...vars.map((v, i) => numCell(0, fVar[i])),
      strCell('', fOut),
    ];
    w('<Row>' + cells.join('') + (r < prog.length ? listingCells(r) : '') + '</Row>');
  }

  // If the program is longer than the trace, keep listing it.
  for (let i = steps + 1; i < prog.length; i++) {
    w('<Row>' + listingCells(i) + '</Row>');
  }

  w('</Table>');
  w('<WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">');
  w('<FreezePanes/><FrozenNoSplit/><SplitHorizontal>1</SplitHorizontal><TopRowBottomPane>1</TopRowBottomPane><ActivePane>2</ActivePane>');
  w('</WorksheetOptions>');
  w('</Worksheet>');
  w('</Workbook>');

  function listingCells(i) {
    return numCell(i, null, C_LIST_I) + strCell(disasm(prog[i], i, srcOf), null, 'mono');
  }

  return out.join('\n') + '\n';
}

module.exports = { emit };
