// The #lua and #luau addon targets. These compile the same Volt programs as the built-in
// targets, so the rule is simple: whatever #js prints, #lua must print too.
//
// Needs a Lua interpreter: a 'lua' / 'lua5.4' / 'luajit' binary on PATH, or the 'fengari'
// package (a Lua VM in JavaScript) installed anywhere Node can find it. Without one, the
// tests that run Lua skip themselves; the compile-only tests always run.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

let lua;                       // null once we know there is nothing to run Lua with
function luaRunner() {
  if (lua !== undefined) return lua;
  lua = null;
  for (const bin of ['lua', 'lua5.4', 'lua5.3', 'luajit']) {
    if (!spawnSync(bin, ['-v']).error) {
      lua = (code) => {
        const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-lua-'));
        const file = path.join(tmp, 'p.lua');
        fs.writeFileSync(file, code);
        try { return execFileSync(bin, [file], { encoding: 'utf8', timeout: 20000 }).trimEnd(); } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
      };
      return lua;
    }
  }
  let fengari = null;
  const places = ['fengari', process.env.VOLT_FENGARI];
  try { places.push(path.join(execFileSync('npm', ['root', '-g'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(), 'fengari')); } catch (e) { /* no npm */ }
  for (const place of places.filter(Boolean)) { try { fengari = require(place); break; } catch (e) { /* try the next */ } }
  if (!fengari) return lua;
  lua = (code) => {
    const { lauxlib, lualib, lua: L5, to_luastring, to_jsstring } = fengari;
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    const out = [];
    L5.lua_pushjsfunction(L, (S) => {
      const n = L5.lua_gettop(S);
      const parts = [];
      for (let i = 1; i <= n; i++) { lauxlib.luaL_tolstring(S, i, null); parts.push(to_jsstring(L5.lua_tostring(S, -1))); L5.lua_pop(S, 1); }
      out.push(parts.join('\t'));
      return 0;
    });
    L5.lua_setglobal(L, to_luastring('print'));
    if (lauxlib.luaL_dostring(L, to_luastring(code)) !== L5.LUA_OK) throw new Error('Lua: ' + to_jsstring(L5.lua_tostring(L, -1)));
    return out.join('\n').trimEnd();
  };
  return lua;
}

module.exports = (t) => {
  const volt = t.volt();
  // Checks that one program prints the same thing as #js, as #lua and as #luau
  const agrees = (body, { targets = ['lua', 'luau'] } = {}) => {
    const want = t.run(volt, `#js\n${body}`);
    if (want === null) return 'skip';
    const runner = luaRunner();
    if (!runner) return 'skip';
    for (const target of targets) {
      const got = runner(volt.compile(`#${target}\n${body}`).code);
      t.assert.strictEqual(got, want, `#${target} printed something different from #js`);
    }
    return undefined;
  };

  t.test('maths: floor, ceil, round (including negatives), clamp, sqrt, pow, dist, lerp', () => agrees(
    'print "{floor(2.7)} {ceil(2.1)} {round(2.5)} {round(0 - 2.5)} {clamp(15, 0, 10)}"\nprint "{sqrt(16)} {pow(2, 5)} {dist(0, 0, 3, 4)} {lerp(0, 100, 25)}"'));

  t.test('text: trim, replace (including regex-magic characters), startsWith, endsWith, indexOf, repeatText', () => agrees(
    'print "[{trim("  hi  ")}]"\nprint replace("a.b.c", ".", "-")\nprint replace("a%b", "%", "!")\nprint "{startsWith("hello", "he")} {endsWith("hello", "lo")} {endsWith("hello", "he")}"\nprint "{indexOf("hello", "ll")} {indexOf("hello", "z")}"\nprint "[{repeatText("ab", 3)}][{repeatText("x", 0)}]"'));

  t.test('lists: join, split, first, last, sort, reverse, slice, sum, indexOf', () => agrees(
    'let l = [3, 1, 2]\nprint join(l, ",")\nprint join(split("a-b-c", "-"), "|")\nprint "{first(l)} {last(l)} {sum(l)} {indexOf(l, 2)} {indexOf(l, 9)}"\nprint join(sort(l), ",")\nprint join(reverse(l), ",")\nprint join(slice([1, 2, 3, 4], 1, 2), ",")\nprint join(l, ",")'));

  t.test('new language features reach the Lua targets too', () => agrees(
    'let state = "run"\nlet total = 0\nfor i from 1 to 6 {\n  if i == 2 { continue }\n  total += i\n}\nmatch state {\n  "idle" { print "resting" }\n  "run", "walk" { print "moving {total}" }\n  else { print "?" }\n}\nfn hit(power, bonus = 3) {\n  return power + bonus\n}\nlet n = 0\nn++\nn += hit(10)\nprint "{n}"'));

  t.test('a program may use a built-in name for its own function or variable', () => agrees(
    'fn dist(a, b) {\n  return a - b\n}\nlet lerp = 4\nlet round = 2\nprint "{dist(10, lerp)} {round}"'));

  // Compile-only checks: no Lua interpreter needed
  t.test('a built-in the Lua targets cannot do is refused at compile time, not at run time', () => {
    for (const call of ['fetchJson("u")', 'mousex()', 'aim3d(10)', 'saved("k", 0)']) {
      const e = t.errorOf(volt, `#lua\nlet x = ${call}`);
      t.assert.ok(e && /doesn't work in #lua/.test(e.message), `${call} should be refused, got: ${e && e.message}`);
    }
  });

  t.test('every built-in either compiles for #lua or says why not', () => {
    for (const name of Object.keys(volt.BUILTINS)) {
      const args = new Array(volt.BUILTINS[name]).fill('1').join(', ');
      let code = null;
      try { code = volt.compile(`#lua\nlet x = ${name}(${args})`).code; } catch (e) {
        t.assert.ok(e instanceof volt.VoltError, `${name}: ${e.message}`);
        continue;
      }
      // If it compiled, it must not be a bare call to a function Lua does not have
      t.assert.ok(!new RegExp(`[^.\\w]${name}\\(`).test(code), `#lua emitted a bare '${name}(...)' call, which does not exist in Lua`);
    }
  });
};
