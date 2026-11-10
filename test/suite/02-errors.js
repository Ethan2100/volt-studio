// Errors: exact line and column, hints, and how the command line prints them
module.exports = (t) => {
  const volt = t.volt();
  const at = (src) => { const e = t.errorOf(volt, src); return e && [e.line, e.col, e.endCol, e.message]; };

  t.test('unknown variable points at the name', () => {
    t.assert.deepStrictEqual(at('#js\nlet score = 1\nprint  scroe + 1'), [3, 8, 13, "Unknown variable 'scroe'. Did you mean 'score'?"]);
  });
  t.test('a bad character points at that character', () => {
    t.assert.deepStrictEqual(at('#js\nlet x = 5 @').slice(0, 3), [2, 11, 12]);
  });
  t.test('unclosed text points at the opening quote to the end', () => {
    t.assert.deepStrictEqual(at('#js\nprint "abc').slice(0, 3), [2, 7, 11]);
  });
  t.test('a type mistake underlines the whole expression', () => {
    t.assert.deepStrictEqual(at('#js\nprint "a" - 3').slice(0, 3), [2, 7, 14]);
  });
  t.test('short names do not get wild suggestions', () => {
    t.assert.ok(!/Did you mean/.test(at('#js\nlet a = 1\nprint b')[3]));
    t.assert.ok(!/Did you mean/.test(at('#js\nfoo(1)')[3]));
  });
  t.test('formatProblem draws a caret under the spot', () => {
    const src = '#js\nlet score = 1\nprint  scroe + 1';
    const text = volt.formatProblem(t.errorOf(volt, src), 'game.volt', () => src);
    t.assert.strictEqual(text, [
      "game.volt:3:8  error: Unknown variable 'scroe'. Did you mean 'score'?",
      '  3 | print  scroe + 1',
      '    |        ^^^^^',
    ].join('\n'));
  });
  t.test('built-in names can be reused (dist, lerp, length ...)', () => {
    t.assert.strictEqual(t.run(volt, '#js\nfn dist(a, b) {\n  return a - b\n}\nlet lerp = 4\nlet length = dist(10, lerp)\nprint length'), '6');
    t.assert.strictEqual(at('#html\nfn move(dx, dist) {\n  return dx / dist\n}\nprint move(4, 2)'), null);
  });
  t.test('names the generated code needs stay reserved', () => {
    for (const name of ['random', 'abs', 'min', 'max', 'map', 'sqrt']) {
      t.assert.ok(/reserved name/.test(at(`#js\nlet ${name} = 1`)[3]), name);
    }
  });
};
