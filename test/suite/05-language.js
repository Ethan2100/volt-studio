// Language features added in Volt 4. Every test compiles a program for several targets,
// really runs it (node, python3, ruby, and g++ for Arduino C++) and compares what it prints.
module.exports = (t) => {
  const volt = t.volt();
  const ALL = ['js', 'python', 'ruby', 'cpp'];
  const SCRIPTS = ['js', 'python', 'ruby'];
  const err = (src) => { const e = t.errorOf(volt, src); return e ? e.message : null; };

  // ---- text with {values} in it ----
  t.test('interpolation: "HP: {hp}/{max}"', () => {
    t.same(volt, 'let hp = 7\nlet top = 10\nlet name = "Finn"\nprint "{name} has {hp}/{top} HP"', 'Finn has 7/10 HP', ALL);
  });
  t.test('interpolation: any expression, and two numbers join instead of adding', () => {
    t.same(volt, 'let a = 2\nlet b = 3\nprint "{a}{b} and {a + b} and {max(a, b) * 2}"', '23 and 5 and 6', ALL);
  });
  t.test('interpolation: braces that are not Volt stay as text', () => {
    t.same(volt, 'print "a { b } c {} {0} {not volt:} {x: 1}"', 'a { b } c {} {0} {not volt:} {x: 1}', SCRIPTS);
  });
  t.test('interpolation: \\{ shows a real brace', () => {
    t.same(volt, 'let x = 5\nprint "\\{x\\} is {x}"', '{x} is 5', SCRIPTS);
  });
  t.test('interpolation: an unknown name inside {} is an error at the right column', () => {
    const e = t.errorOf(volt, '#js\nprint "Score: {scroe}"');
    t.assert.deepStrictEqual([e.line, e.col, e.endCol], [2, 16, 21]);
  });
  t.test('interpolation: true/false and decimals', () => {
    t.same(volt, 'let half = 1.5\nprint "{(3 > 2)} {half}"', 'true 1.5', SCRIPTS);
  });

  // ---- continue ----
  t.test('continue in for, while, repeat and for each', () => {
    t.same(volt, [
      'let total = 0',
      'for i from 1 to 6 {\n  if i == 2 { continue }\n  total += i\n}',
      'let n = 0\nwhile n < 5 {\n  n += 1\n  if n == 3 { continue }\n  total += 100\n}',
      'let r = 0\nrepeat 4 {\n  r += 1\n  if r == 1 {\n    continue\n  }\n  total += 1000\n}',
      'print total',
    ].join('\n'), '3419', ALL);
    t.same(volt, 'let out = ""\nfor each w in ["a", "b", "c"] {\n  if w == "b" { continue }\n  out = out + w\n}\nprint out', 'ac', SCRIPTS);
  });
  t.test('continue outside a loop is an error', () => {
    t.assert.ok(/only works inside a loop/.test(err('#js\ncontinue')));
  });
  t.test('a variable called continue-ish names still works', () => {
    t.assert.strictEqual(err('#js\nlet match = 3\nmatch = match + 1\nprint match'), null);
  });

  // ---- match ----
  t.test('match with several values per case and else', () => {
    const body = (v) => `let state = ${v}\nmatch state {\n  "idle" { print "resting" }\n  "run", "walk" {\n    print "moving"\n  }\n  else { print "other" }\n}`;
    t.same(volt, body('"walk"'), 'moving', ALL);
    t.same(volt, body('"idle"'), 'resting', ALL);
    t.same(volt, body('"fly"'), 'other', ALL);
  });
  t.test('match on numbers, on an expression, without else, and nested', () => {
    t.same(volt, 'let n = 4\nmatch n * 2 {\n  1, 2 { print "small" }\n  8 {\n    match n {\n      4 { print "eight from four" }\n    }\n  }\n}\nmatch n { 9 { print "no" } }\nprint "done"', 'eight from four\ndone', ALL);
  });
  t.test('match works out its value only once', () => {
    t.same(volt, 'let calls = 0\nfn bump() {\n  calls += 1\n  return calls\n}\nmatch bump() {\n  5 { print "five" }\n  6 { print "six" }\n  1 { print "one" }\n}\nprint calls', 'one\n1', ALL);
  });
  t.test('match errors are helpful', () => {
    t.assert.ok(/at least one value/.test(err('#js\nlet x = 1\nmatch x { }')));
    t.assert.ok(/'else' must be the last/.test(err('#js\nlet x = 1\nmatch x { else { } 1 { } }')));
  });

  // ---- default values ----
  t.test('fn with default values', () => {
    t.same(volt, 'fn area(w, h = 2, scale = 10) {\n  return w * h * scale\n}\nprint area(3)\nprint area(3, 4)\nprint area(3, 4, 1)', '60\n120\n12', ALL);
    t.same(volt, 'fn greet(name, hello = "Hi") {\n  return hello + " " + name\n}\nprint greet("Sam")\nprint greet("Sam", "Yo")', 'Hi Sam\nYo Sam', SCRIPTS);
  });
  t.test('default value errors', () => {
    t.assert.ok(/needs 1 to 3 values, got 0/.test(err('#js\nfn f(a, b = 1, c = 2) { }\nf()')));
    t.assert.ok(/needs a default too/.test(err('#js\nfn f(a = 1, b) { }')));
    t.assert.ok(/must be a plain value/.test(err('#js\nlet k = 2\nfn f(a = k) { }')));
  });

  // ---- small operators ----
  t.test('%=  ++  --', () => {
    t.same(volt, 'let f = 10\nf %= 4\nlet s = 0\ns++\ns++\ns--\nprint "{f} {s}"', '2 1', ALL);
  });
  t.test('++ needs to be on its own: a + +b style code is untouched', () => {
    t.same(volt, 'let a = 1\nlet b = 2\nlet c = a - -b\nprint c', '3', ALL);
  });

  // ---- for each with a position ----
  t.test('for each item, i in list', () => {
    t.same(volt, 'for each name, i in ["a", "b", "c"] {\n  print "{i}:{name}"\n}', '0:a\n1:b\n2:c', SCRIPTS);
  });

  // ---- struct types outside #html ----
  t.test('struct types in #js, #python and #ruby', () => {
    t.same(volt, [
      'Player = type { name: string, hp: int, alive: bool }',
      'let hero = Player { name: "Finn", hp: 10 }',
      'let party = []',
      'add hero to party',
      'add Player { name: "Jake", hp: 3 } to party',
      'hero.hp -= 4',
      'party[1].hp = party[1].hp + 1',
      'for each who in party {\n  print "{who.name} {who.hp}"\n}',
      'if hero.alive { print "yes" } else { print "not yet" }',
    ].join('\n'), 'Finn 6\nJake 4\nnot yet', SCRIPTS);
  });
  t.test('struct types still say no on boards, with a reason', () => {
    t.assert.ok(/doesn't work on boards/.test(err('#c++\nP = type { hp: int }')));
  });

  // ---- standard library ----
  t.test('rounding', () => {
    t.same(volt, 'print "{floor(2.7)} {ceil(2.1)} {round(2.5)} {round(2.4)} {floor(0 - 2.5)} {clamp(15, 0, 10)}"', '2 3 3 2 -3 10', SCRIPTS);
    t.same(volt, 'print "{floor(7)} {round(7)} {clamp(15, 0, 10)}"', '7 7 10', ['cpp']);
  });
  t.test('text helpers', () => {
    t.same(volt, 'let s = "  Hello World  "\nprint "[{trim(s)}]"\nprint replace("a-b-c", "-", "+")\nprint startsWith("hello", "he")\nprint endsWith("hello", "lo")\nprint endsWith("hello", "he")\nprint indexOf("hello", "ll")\nprint indexOf("hello", "z")\nprint repeatText("ab", 3)',
      '[Hello World]\na+b+c\ntrue\ntrue\nfalse\n2\n-1\nababab', SCRIPTS);
    t.same(volt, 'let s = "  Hi  "\nprint "[" + trim(s) + "]"\nprint replace("a-b-c", "-", "+")\nprint indexOf("hello", "ll")\nprint repeatText("ab", 3)\nif startsWith("hello", "he") { print "yes" }', '[Hi]\na+b+c\n2\nababab\nyes', ['cpp']);
  });
  t.test('list helpers', () => {
    t.same(volt, 'let l = [3, 1, 2]\nprint "{first(l)} {last(l)} {sum(l)} {indexOf(l, 2)} {indexOf(l, 9)}"\nprint join(sort(l), ",")\nprint join(reverse(l), ",")\nprint join(slice(l, 1, 2), ",")\nprint join(l, ",")\nprint length(shuffle(l))\nprint contains(l, pick(l))',
      '3 2 6 2 -1\n1,2,3\n2,1,3\n1,2\n3,1,2\n3\ntrue', SCRIPTS);
  });
  t.test('chance and now', () => {
    t.same(volt, 'let hits = 0\nrepeat 200 {\n  if chance(100) { hits += 1 }\n  if chance(0) { hits += 1000 }\n}\nprint hits\nprint now() > 1600000000000', '200\ntrue', SCRIPTS);
  });
  t.test('new built-in names can still be used as names', () => {
    t.same(volt, 'let floor = 3\nlet round = 2\nlet first = 1\nlet now = 9\nfn pick(a) {\n  return a * 2\n}\nprint floor + round + first + now + pick(5) + floor(1.9)', '26', SCRIPTS);
  });
  t.test('fetchJson is for #js and #html only', () => {
    t.assert.ok(/only works in #js and #html/.test(err('#python\nlet d = fetchJson("x")')));
    t.assert.strictEqual(err('#js\nlet d = fetchJson("https://example.com/x.json")\nprint d'), null);
  });
};
