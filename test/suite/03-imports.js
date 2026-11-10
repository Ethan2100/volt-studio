// import "file.volt": errors name the real file and line; indented imports work; packages are found
const fs = require('fs');
const os = require('os');
const path = require('path');

module.exports = (t) => {
  const volt = t.volt();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-imports-'));
  const write = (name, text) => { fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true }); fs.writeFileSync(path.join(dir, name), text); };
  write('lib.volt', 'fn sq(x) {\n  return x * y\n}\n');
  write('good.volt', '// maths\nfn sq(x) {\n  return x * x\n}\n');
  write('volt_packages/shapes/volt.json', JSON.stringify({ name: 'shapes', version: '1.0.0', main: 'src/shapes.volt' }));
  write('volt_packages/shapes/src/shapes.volt', 'fn area(w, h) {\n  return w * h\n}\n');
  write('volt_packages/shapes/extra.volt', 'fn perimeter(w, h) {\n  return 2 * (w + h)\n}\n');
  write('volt_packages/plain/plain.volt', 'fn plainly() {\n  return 7\n}\n');
  write('sub/deep/prog.volt', '#js\nimport "shapes"\nprint area(2, 3)\n');

  t.test('an error inside an imported file names that file and its own line', () => {
    const e = t.errorOf(volt, '#js\n\nimport "lib.volt"\nprint sq(2)', { baseDir: dir });
    t.assert.strictEqual(e.file, path.join(dir, 'lib.volt'));
    t.assert.deepStrictEqual([e.line, e.col, e.importedAt], [2, 14, 3]);
  });
  t.test('an error after an import still has the right line', () => {
    const e = t.errorOf(volt, '#js\nimport "good.volt"\nprint sq(2)\nprint nope', { baseDir: dir });
    t.assert.deepStrictEqual([e.file, e.line, e.col], [null, 4, 7]);
  });
  t.test('an indented import works', () => {
    t.assert.strictEqual(t.run(volt, '#js\n  import "good.volt"\nprint sq(4)', { dir }), '16');
  });
  t.test('importing the same file twice is fine', () => {
    t.assert.strictEqual(t.run(volt, '#js\nimport "good.volt"\nimport "good.volt"\nprint sq(3)', { dir }), '9');
  });
  t.test('a missing file says so, at the import', () => {
    const e = t.errorOf(volt, '#js\nimport "nope.volt"', { baseDir: dir });
    t.assert.deepStrictEqual([e.line, e.col, /Can't import 'nope.volt'/.test(e.message)], [2, 8, true]);
  });
  t.test('import "name" finds a package and its volt.json main', () => {
    t.assert.strictEqual(t.run(volt, '#js\nimport "shapes"\nprint area(2, 3)', { dir }), '6');
  });
  t.test('import "name/file.volt" finds a file inside a package', () => {
    t.assert.strictEqual(t.run(volt, '#js\nimport "shapes/extra.volt"\nprint perimeter(2, 3)', { dir }), '10');
  });
  t.test('a package with no volt.json uses name.volt', () => {
    t.assert.strictEqual(t.run(volt, '#js\nimport "plain"\nprint plainly()', { dir }), '7');
  });
  t.test('packages are found from folders below volt_packages', () => {
    t.assert.strictEqual(t.run(volt, fs.readFileSync(path.join(dir, 'sub/deep/prog.volt'), 'utf8'), { dir: path.join(dir, 'sub/deep') }), '6');
  });
  t.test('a missing package suggests volt add', () => {
    const e = t.errorOf(volt, '#js\nimport "nothere"', { baseDir: dir });
    t.assert.ok(/volt add nothere/.test(e.message), e.message);
  });
};
