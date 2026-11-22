// An error inside an imported file must be reported against THAT file and
// its own line number. Before the source map, the line was a position in
// the merged text - a number belonging to no file anyone can open, which
// editors then pinned to whatever line happened to exist there.
//   Run with: node test/import-errors-test.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-imports-'));
const write = (rel, text) => {
  const full = path.join(dir, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, text);
  return full;
};
const compile = (source) => {
  try { return { ok: true, ...volt.compile(source, { baseDir: dir }) }; }
  catch (e) { return { ok: false, line: e.line, file: e.file, merged: e.mergedLine, message: e.message }; }
};

// a 40-line helper, so a merged-text line number is obviously different
write('lib/helper.volt', '// helper\n'.repeat(39) + 'fn helper() {\n  nosuchthing()\n}\n');
write('lib/fine.volt', 'fn fine() {\n  let x = 1\n  print x\n}\n');

const main = [
  '#js',
  'import "lib/fine.volt"',
  'import "lib/helper.volt"',
  'fine()',
  'helper()',
].join('\n');

const r = compile(main);
check('the bad call is found', !r.ok && /nosuchthing/.test(r.message), r.message);
check('it is blamed on the file it is actually in', r.file === 'lib/helper.volt', JSON.stringify(r.file));
check('with that file\'s own line number', r.line === 41, `line ${r.line}`);
check('and the merged position is kept for debugging', r.merged > 41, `merged ${r.merged}`);

// an error in the main file keeps pointing at the main file
const r2 = compile('#js\nimport "lib/fine.volt"\nnope()\n');
check('an error in the program itself has no file set', !r2.ok && r2.file === '', JSON.stringify(r2.file));
check('and keeps its own line number', r2.line === 3, `line ${r2.line}`);

// an import nested inside an import
write('lib/outer.volt', 'import "inner.volt"\nfn outer() { inner() }\n');
write('lib/inner.volt', 'fn inner() {\n  alsomissing()\n}\n');
const r3 = compile('#js\nimport "lib/outer.volt"\nouter()\n');
check('an error two imports deep names the innermost file', !r3.ok && r3.file === 'inner.volt', JSON.stringify(r3.file));
check('with the innermost file\'s line number', r3.line === 2, `line ${r3.line}`);

// and a working import still works
write('lib/ok.volt', 'fn greet() {\n  print "hi"\n}\n');
const r4 = compile('#js\nimport "lib/ok.volt"\ngreet()\n');
check('a good import still compiles', r4.ok === true, r4.message || '');
check('the imported code is in the output', r4.ok && /hi/.test(r4.code));

// a missing import is reported against the line that asked for it
const r5 = compile('#js\nimport "lib/ghost.volt"\n');
check('a missing import points at the import line', !r5.ok && r5.line === 2 && /Can't import/.test(r5.message), `${r5.line}: ${r5.message}`);

fs.rmSync(dir, { recursive: true, force: true });
process.exitCode = failed ? 1 : 0;
