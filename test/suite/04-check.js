// volt.check(): every problem at once, with warnings, for editors and the language server
module.exports = (t) => {
  const volt = t.volt();
  const list = (src, opts) => volt.check(src, opts).diagnostics.map((d) => `${d.severity} ${d.line}:${d.col} ${d.message}`);

  t.test('a clean program is ok and returns the code', () => {
    const r = volt.check('#js\nprint 1 + 2');
    t.assert.strictEqual(r.ok, true);
    t.assert.deepStrictEqual(r.diagnostics, []);
    t.assert.strictEqual(r.code, volt.compile('#js\nprint 1 + 2').code);
  });
  t.test('reports several errors in one go', () => {
    const got = list('#js\nlet a = 1\nprint bbbb\nprint cccc +\nprint dddd\nprint a');
    t.assert.deepStrictEqual(got, [
      "error 3:7 Unknown variable 'bbbb'. Did you forget 'let bbbb = ...'?",
      "error 5:1 Expected a value but found 'print'",
    ]);
  });
  t.test('one bad let does not cause follow-on errors', () => {
    const got = list('#js\nfn f() {\n  let x = nope\n  print x\n  print x + 1\n}\nf()');
    t.assert.deepStrictEqual(got, ["error 3:11 Unknown variable 'nope'. Did you forget 'let nope = ...'?"]);
  });
  t.test('warns about unused variables, uncalled functions and unreachable lines', () => {
    const got = list('#js\nfn f(x) {\n  let unused = 3\n  return x\n  print 1\n}\nprint 2');
    t.assert.deepStrictEqual(got, [
      "warning 2:1 The function 'f' is never called",
      "warning 3:3 'unused' is made here but never used",
      "warning 5:3 This line can never run: the 'return' above it always leaves first",
    ]);
  });
  t.test('names used from raw # code count as used', () => {
    t.assert.deepStrictEqual(list('#js\nfn helper() {\n  return 1\n}\n# helper();'), []);
  });
  t.test('warnings alone still give code', () => {
    const r = volt.check('#js\nfn f() {\n  return 1\n}\nprint 2');
    t.assert.strictEqual(r.ok, true);
    t.assert.ok(r.code.includes('console.log'));
  });
  t.test('compile() behaves as before: throws the first error only', () => {
    const e = t.errorOf(volt, '#js\nprint bbbb\nprint cccc');
    t.assert.strictEqual(e.line, 2);
  });
  t.test('check() gives exactly the code compile() gives, for every example', () => {
    const fs = require('fs');
    const path = require('path');
    const golden = JSON.parse(fs.readFileSync(path.join(t.ROOT, 'test', 'golden.json'), 'utf8'));
    let n = 0;
    for (const [rel, want] of Object.entries(golden)) {
      // plugins/ and packages/ hold libraries with no first line of their own; the golden suite
      // gives them one, so they are not whole programs to compare here
      if (want.error || rel.startsWith('plugins/') || rel.startsWith('packages/')) continue;
      const file = path.join(t.ROOT, rel);
      const src = fs.readFileSync(file, 'utf8');
      const r = volt.check(src, { baseDir: path.dirname(file) });
      t.assert.deepStrictEqual(r.diagnostics.filter((d) => d.severity === 'error'), [], rel);
      t.assert.ok(r.code === volt.compile(src, { baseDir: path.dirname(file) }).code, `${rel}: check() and compile() disagree`);
      n++;
    }
    t.assert.ok(n > 30);
  });
};
