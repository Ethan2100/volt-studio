// The language service that Volt Studio and the VS Code extension both use.
// It must never throw, even on half-written code, and must stay in step with the compiler.
module.exports = (t) => {
  const path = require('path');
  const ls = require(path.join(t.ROOT, 'lib', 'language-service.js'));
  const volt = t.volt();
  const labels = (src, line, col) => ls.completions(src, line, col).items.map((c) => c.label);

  t.test('the built-in docs cover exactly the compiler built-ins, with the same values', () => {
    const arity = (sig) => {
      const inner = sig.slice(sig.indexOf('(') + 1, sig.lastIndexOf(')')).trim();
      return inner ? inner.split(',').length : 0;
    };
    for (const name of Object.keys(volt.BUILTINS)) {
      t.assert.ok(ls.BUILTIN_DOCS[name], `'${name}' is a built-in with no entry in lib/builtin-docs.js`);
      t.assert.strictEqual(arity(ls.BUILTIN_DOCS[name][0]), volt.BUILTINS[name], `'${name}' documents a different number of values`);
    }
    for (const name of Object.keys(ls.BUILTIN_DOCS)) {
      t.assert.ok(volt.BUILTINS[name] !== undefined, `'${name}' is documented but is not a built-in`);
    }
  });

  t.test('diagnostics come back with ranges and severities', () => {
    const d = ls.diagnostics('#js\nlet a = 1\nprint bbb\nfn never() {\n  return 1\n}');
    t.assert.deepStrictEqual(d.map((x) => `${x.severity} ${x.line}:${x.col}`), ['error 3:7', 'warning 4:1']);
  });

  t.test('completion knows the file\'s own names', () => {
    const src = '#js\nlet score = 0\nfn addPoints(amount) {\n  return amount\n}\nprint s';
    const got = labels(src, 6, 8);
    t.assert.ok(got.includes('score'), got.join(','));
    t.assert.ok(!got.includes('addPoints'), 'only names starting with the typed letters');
    t.assert.ok(labels(src, 6, 7).includes('addPoints'));
  });

  t.test('completion offers a function\'s own parameters inside it', () => {
    const got = labels('#js\nfn hit(power, bonus) {\n  return p\n}\nhit(1, 2)', 3, 11);
    t.assert.ok(got.includes('power'), got.join(','));
  });

  t.test('completion is filtered by what the target can do', () => {
    const game = labels('#html\ncanvas 320, 180\nlet x = mous', 3, 13);
    t.assert.ok(game.includes('mousex') && game.includes('mousedown'), game.join(','));
    t.assert.ok(!labels('#python\nlet x = mous', 2, 13).includes('mousex'), 'no mouse in a #python script');
    t.assert.ok(!labels('#c++\nlet x = sor', 2, 12).includes('sort'), 'no lists on a board');
    t.assert.ok(labels('#js\nlet x = sor', 2, 12).includes('sort'));
  });

  t.test('completion offers the targets on the first line', () => {
    t.assert.ok(labels('#ht', 1, 4).includes('#html'));
  });

  t.test('hover explains built-ins, statements and the file\'s own names', () => {
    const b = ls.hover('#html\ncanvas 320, 180\nlet n = aim3d(300)', 3, 10);
    t.assert.strictEqual(b.signature, 'aim3d(range)');
    t.assert.ok(/points at/.test(b.doc));
    const s = ls.hover('#html\nplayer3d 0, 0, 0', 2, 3);
    t.assert.ok(/player3d x, y, z/.test(s.signature), s.signature);
    const mine = ls.hover('#js\nfn hit(power, bonus) {\n  return power\n}\nhit(1, 2)', 5, 2);
    t.assert.strictEqual(mine.signature, 'fn hit(power, bonus)');
    t.assert.strictEqual(ls.hover('#js\nlet a = 1', 2, 9), null, 'nothing to say about a number');
  });

  t.test('go to definition finds where a name is made', () => {
    const src = '#js\nlet score = 0\nfn addPoints(amount) {\n  score += amount\n}\naddPoints(5)';
    t.assert.deepStrictEqual(ls.definition(src, 6, 3), { line: 3, col: 4, endCol: 13, name: 'addPoints', kind: 'function' });
    t.assert.deepStrictEqual(ls.definition(src, 4, 4).line, 2, 'score is made on line 2');
  });

  t.test('an outline of the file', () => {
    const src = '#html\nPlayer = type { hp: int }\nimage tiles = "t.png"\nlet score = 0\nfn go() {\n  return 1\n}';
    t.assert.deepStrictEqual(ls.symbols(src).map((s) => `${s.kind} ${s.name}`), ['type Player', 'image tiles', 'variable score', 'function go']);
  });

  t.test('nothing throws on half-written code', () => {
    const broken = ['#js\nlet x = ', '#html\nfn (', 'match {', '#js\nprint "unclosed', '', '#js\nfor each ', '{{{', '#js\nlet a = [1, 2'];
    for (const src of broken) {
      for (let line = 1; line <= src.split('\n').length; line++) {
        for (let col = 1; col <= (src.split('\n')[line - 1] || '').length + 1; col++) {
          ls.completions(src, line, col);
          ls.hover(src, line, col);
          ls.definition(src, line, col);
        }
      }
      ls.symbols(src);
      ls.diagnostics(src);
    }
  });

  t.test('the editor\'s highlight words come from the compiler, not a copied list', () => {
    const w = ls.highlightWords();
    t.assert.ok(w.builtins.includes('shuffle') && w.builtins.includes('aim3d'));
    t.assert.ok(w.keywords.includes('every') && w.targets.includes('html'));
    for (const name of Object.keys(volt.BUILTINS)) t.assert.ok(w.builtins.includes(name), name);
  });

  t.test('the target is read from the first line', () => {
    t.assert.strictEqual(ls.targetOf('// a note\n\n#html\ncanvas 1, 1'), 'html');
    t.assert.strictEqual(ls.targetOf('pin led = 13'), 'cpp');
    t.assert.strictEqual(ls.targetOf('#python\nprint 1'), 'python');
  });
};
