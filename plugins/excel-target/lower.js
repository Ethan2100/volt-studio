// =====================================================================
//  Volt -> flat instruction list (the "bytecode" the spreadsheet runs)
//
//  Instructions:
//    { op:'SET',   name, expr }        name = expr ; pc+1
//    { op:'PRINT', expr }              emit expr   ; pc+1
//    { op:'JMP',   target }            pc = target
//    { op:'JZ',    expr, target }      pc = (expr falsy) ? target : pc+1
//    { op:'NOP',   note }              pc+1   (wait/clear - nothing to do)
//    { op:'HALT' }                     pc = pc  (frozen)
//
//  Labels are resolved after lowering: a target may be a {label:n} box
//  which is patched to a real index once the index is known.
// =====================================================================

class CompileError extends Error {}

const MAX_INLINE_DEPTH = 24;

function lower(ast) {
  const prog = [];          // instruction list
  const fns = new Map();    // name -> Fn node
  const vars = new Set();   // every variable/column the sheet needs
  let tmp = 0;              // __t0, __t1 ... for inlined return values
  const inlining = [];      // call stack of fn names, for recursion detection

  // --- label helpers -------------------------------------------------
  // A label is a mutable box; jumps hold the box and we read .at later.
  const label = () => ({ at: -1 });
  const here = (L) => { L.at = prog.length; };
  const emit = (ins) => { prog.push(ins); return ins; };

  // --- collect function declarations before anything else ------------
  for (const node of ast) {
    if (node.kind === 'Fn') {
      if (fns.has(node.name)) throw new CompileError(`Two functions are both called '${node.name}' (line ${node.line}).`);
      fns.set(node.name, node);
    }
  }

  const useVar = (n) => { vars.add(n); return n; };

  // =====================================================================
  //  Expressions
  //
  //  An expression may contain a call to a user function, which the
  //  spreadsheet cannot evaluate inline - so we hoist it: emit the
  //  function's body as instructions first, landing its result in a
  //  temp variable, then replace the call with a reference to that temp.
  //  prepExpr returns a *call-free* expression tree.
  // =====================================================================
  function prepExpr(e) {
    if (!e) return e;
    switch (e.kind) {
      case 'Number': case 'String': case 'Bool': return e;
      case 'Var': useVar(e.name); return e;
      case 'Unary': return { ...e, operand: prepExpr(e.operand) };
      case 'Binary': return { ...e, left: prepExpr(e.left), right: prepExpr(e.right) };
      case 'Call': {
        const args = (e.args || []).map(prepExpr);
        if (fns.has(e.name)) return inlineCall(e.name, args, e.line);
        return { ...e, args };               // builtin - the sheet handles it
      }
      case 'Ask':
        throw new CompileError(
          `'ask' needs a keyboard, and a spreadsheet has no input (line ${e.line}). ` +
          `Set the value with 'let' instead, or edit the cell in the sheet.`);
      case 'Read':
        throw new CompileError(`Pin reads need hardware; the #excel target has no pins (line ${e.line}).`);
      case 'Uptime':
        throw new CompileError(`'uptime' needs a clock; the sheet counts steps, not milliseconds (line ${e.line}).`);
      default:
        throw new CompileError(`The #excel target does not understand '${e.kind}' (line ${e.line}).`);
    }
  }

  // Inline one call to a user function, returning a Var node for the result.
  function inlineCall(name, args, line) {
    if (inlining.includes(name))
      throw new CompileError(
        `'${name}' calls itself (line ${line}). A spreadsheet row has no call stack, ` +
        `so the #excel target cannot do recursion - rewrite it as a loop.`);
    if (inlining.length >= MAX_INLINE_DEPTH)
      throw new CompileError(`Functions are nested more than ${MAX_INLINE_DEPTH} deep at line ${line}.`);

    const fn = fns.get(name);
    const params = fn.params || [];
    if (args.length !== params.length)
      throw new CompileError(
        `'${name}' takes ${params.length} value(s) but got ${args.length} (line ${line}).`);

    // Bind the arguments to the parameter names. Parameters are plain
    // columns, which is exactly why recursion can't work here.
    params.forEach((p, i) => emit({ op: 'SET', name: useVar(p), expr: args[i] }));

    const out = `__r${tmp++}`;
    useVar(out);
    // Clear the slot so a function that returns down one branch can't hand
    // back whatever the previous call happened to leave there. Marked as an
    // initialiser so it doesn't count when working out the column's type.
    emit({ op: 'SET', name: out, expr: { kind: 'Number', value: '0' }, init: true });

    const done = label();
    inlining.push(name);
    block(fn.body, { returnTo: done, returnVar: out });
    inlining.pop();
    here(done);

    return { kind: 'Var', name: out, line };
  }

  // =====================================================================
  //  Statements
  // =====================================================================
  // Scratch columns (the __r holders a call's result lands in) only have to
  // live as long as the one statement that reads them, so each statement
  // starts allocating again from wherever its block began. Without this every
  // call site in the program would add a column of its own, and a few nested
  // loops would widen the sheet into the hundreds.
  function block(stmts, ctx) {
    const base = tmp;
    for (const s of stmts) { tmp = base; stmt(s, ctx); }
    tmp = base;
  }

  function stmt(n, ctx) {
    switch (n.kind) {
      case 'Fn': return;                       // already collected; bodies are inlined at call sites

      case 'Let':
      case 'Assign':
        emit({ op: 'SET', name: useVar(n.name), expr: prepExpr(n.value) });
        return;

      case 'Print':
      case 'Show':
        emit({ op: 'PRINT', expr: prepExpr(n.value) });
        return;

      case 'CallStmt': {
        const e = prepExpr(n.call);
        // A user-function call lowers to instructions and yields a temp we
        // simply discard; a builtin used as a statement has no effect here.
        if (e.kind === 'Call') emit({ op: 'NOP', note: `${e.name}()` });
        return;
      }

      case 'If': {
        const cond = prepExpr(n.cond);
        const otherwise = label();
        emit({ op: 'JZ', expr: cond, target: otherwise });
        block(n.then, ctx);
        if (n.otherwise && n.otherwise.length) {
          const end = label();
          emit({ op: 'JMP', target: end });
          here(otherwise);
          block(n.otherwise, ctx);
          here(end);
        } else {
          here(otherwise);
        }
        return;
      }

      case 'While': {
        const top = label(), end = label();
        here(top);
        emit({ op: 'JZ', expr: prepExpr(n.cond), target: end });
        block(n.body, { ...ctx, breakTo: end });
        emit({ op: 'JMP', target: top });
        here(end);
        return;
      }

      case 'Forever': {
        const top = label(), end = label();
        here(top);
        block(n.body, { ...ctx, breakTo: end });
        emit({ op: 'JMP', target: top });
        here(end);
        return;
      }

      case 'For': {
        // for i = a to b  ->  i = a; while i <= b { body; i = i + 1 }
        const i = useVar(n.name);
        emit({ op: 'SET', name: i, expr: prepExpr(n.start) });
        const limit = `__end${tmp++}`;
        useVar(limit);
        emit({ op: 'SET', name: limit, expr: prepExpr(n.end) });

        const top = label(), end = label();
        here(top);
        emit({
          op: 'JZ',
          expr: { kind: 'Binary', op: '<=', left: { kind: 'Var', name: i }, right: { kind: 'Var', name: limit } },
          target: end,
        });
        block(n.body, { ...ctx, breakTo: end });
        emit({
          op: 'SET', name: i,
          expr: { kind: 'Binary', op: '+', left: { kind: 'Var', name: i }, right: { kind: 'Number', value: '1' } },
        });
        emit({ op: 'JMP', target: top });
        here(end);
        return;
      }

      case 'Repeat': {
        // repeat n { }  ->  k = n; while k > 0 { body; k = k - 1 }
        const k = `__n${tmp++}`;
        useVar(k);
        emit({ op: 'SET', name: k, expr: prepExpr(n.count) });
        const top = label(), end = label();
        here(top);
        emit({
          op: 'JZ',
          expr: { kind: 'Binary', op: '>', left: { kind: 'Var', name: k }, right: { kind: 'Number', value: '0' } },
          target: end,
        });
        block(n.body, { ...ctx, breakTo: end });
        emit({
          op: 'SET', name: k,
          expr: { kind: 'Binary', op: '-', left: { kind: 'Var', name: k }, right: { kind: 'Number', value: '1' } },
        });
        emit({ op: 'JMP', target: top });
        here(end);
        return;
      }

      case 'Break':
        if (!ctx.breakTo) throw new CompileError(`'break' is not inside a loop (line ${n.line}).`);
        emit({ op: 'JMP', target: ctx.breakTo });
        return;

      case 'Return':
        if (!ctx.returnTo) throw new CompileError(`'return' is not inside a function (line ${n.line}).`);
        if (n.value) emit({ op: 'SET', name: ctx.returnVar, expr: prepExpr(n.value) });
        emit({ op: 'JMP', target: ctx.returnTo });
        return;

      case 'Stop':
        emit({ op: 'HALT' });
        return;

      case 'Wait':
        prepExpr(n.time);                       // still type-check it
        emit({ op: 'NOP', note: 'wait' });
        return;

      case 'Clear':
        emit({ op: 'NOP', note: 'clear' });
        return;

      case 'Raw':
      case 'RawTop':
        throw new CompileError(
          `Raw code (# / ##) is for the language you are escaping into, and a ` +
          `spreadsheet has none (line ${n.line}).`);

      case 'Pin': case 'Write': case 'Set': case 'SetSpeed': case 'Fade':
      case 'Tone': case 'When': case 'Every':
        throw new CompileError(
          `'${n.kind}' drives hardware or a timer, which a spreadsheet has no way to do (line ${n.line}).`);

      case 'Button': case 'Title': case 'Html': case 'WhenKey':
        throw new CompileError(`'${n.kind}' is for web pages, not spreadsheets (line ${n.line}).`);

      default:
        throw new CompileError(`The #excel target does not understand '${n.kind}' (line ${n.line}).`);
    }
  }

  // --- main body (function declarations are skipped; they inline) -----
  block(ast, {});
  emit({ op: 'HALT' });

  // --- resolve labels -------------------------------------------------
  for (const ins of prog) {
    if (ins.target) {
      if (ins.target.at < 0) throw new CompileError('Compiler bug: a jump target was never placed.');
      ins.target = ins.target.at;
    }
  }

  return { prog, vars: [...vars] };
}

module.exports = { lower, CompileError };
