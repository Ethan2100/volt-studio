#!/usr/bin/env node
// =====================================================================
//  Volt test suite - plain Node, no Electron, no packages to install.
//
//    npm test                     run everything
//    node test/run.js golden      run only suites whose name contains "golden"
//    UPDATE_GOLDEN=1 npm test     accept the current compiler output as the new baseline
//
//  Each file in test/suite/ exports a function (t) => { ... } that registers
//  tests with t.test(name, fn). A test passes unless it throws.
// =====================================================================

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const ROOT = path.join(__dirname, '..');
const filter = process.argv.slice(2).filter((a) => !a.startsWith('-'));
const verbose = process.argv.includes('-v');

const tests = [];
const t = {
  ROOT,
  assert,
  test(name, fn) { tests.push({ suite: t.suite, name, fn }); },
  // A fresh copy of the compiler, with the bundled target plugins (#lua, #luau, #pseudo) loaded
  volt() {
    for (const k of Object.keys(require.cache)) {
      if (k.startsWith(ROOT) && !k.includes('node_modules') && !k.startsWith(__dirname)) delete require.cache[k];
    }
    const volt = require(path.join(ROOT, 'compiler', 'volt.js'));
    const plugins = require(path.join(ROOT, 'lib', 'plugins.js'));
    plugins.loadTargetPlugins(plugins.scanPlugins(path.join(ROOT, 'plugins'), path.join(ROOT, '.no-user-plugins')), volt, null);
    return volt;
  },
  // Compile a program, run it for real (node / python3 / ruby) and return what it printed.
  // Returns null when that language isn't installed here, so the test can skip itself.
  run(volt, src, { stdin = '', dir = null } = {}) {
    const { target, code } = volt.compile(src, dir ? { baseDir: dir } : {});
    const tool = { js: ['node'], python: ['python3'], ruby: ['ruby'] }[target];
    if (!tool) throw new Error(`t.run can't run '${target}' programs`);
    const { spawnSync } = require('child_process');
    if (spawnSync(tool[0], ['--version']).error) return null;
    const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'volt-test-'));
    const file = path.join(tmp, { js: 'p.js', python: 'p.py', ruby: 'p.rb' }[target]);
    fs.writeFileSync(file, code);
    const r = spawnSync(tool[0], [file], { input: stdin, encoding: 'utf8', timeout: 20000 });
    fs.rmSync(tmp, { recursive: true, force: true });
    if (r.status !== 0) throw new Error(`the ${target} program failed:\n${r.stderr || r.stdout}\n--- generated code ---\n${code}`);
    return r.stdout.replace(/\r\n/g, '\n').trimEnd();
  },
  // Runs the same program as #js, #python and #ruby and checks all three print 'expected'
  same(volt, body, expected, targets = ['js', 'python', 'ruby']) {
    for (const target of targets) {
      const got = t.run(volt, `#${target}\n${body}`);
      if (got === null) continue;
      assert.strictEqual(got, expected, `#${target} printed something different`);
    }
  },
  // Compile and return the error (or null) instead of throwing
  errorOf(volt, src, options) {
    try { volt.compile(src, options); return null; } catch (e) { if (e instanceof volt.VoltError) return e; throw e; }
  },
};

for (const file of fs.readdirSync(path.join(__dirname, 'suite')).sort()) {
  if (!file.endsWith('.js')) continue;
  t.suite = file.replace(/\.js$/, '');
  require(path.join(__dirname, 'suite', file))(t);
}

(async () => {
  let pass = 0, fail = 0, skipped = 0;
  const started = Date.now();
  for (const tc of tests) {
    const full = `${tc.suite} > ${tc.name}`;
    if (filter.length && !filter.some((f) => full.includes(f))) continue;
    try {
      const r = await tc.fn();
      if (r === 'skip') { skipped++; if (verbose) console.log(`  skip ${full}`); continue; }
      pass++;
      if (verbose) console.log(`  ok   ${full}`);
    } catch (e) {
      fail++;
      console.log(`  FAIL ${full}\n       ${String(e && e.message ? e.message : e).split('\n').join('\n       ')}`);
    }
  }
  console.log(`\n${pass} passed, ${fail} failed${skipped ? `, ${skipped} skipped` : ''}  (${Date.now() - started} ms)`);
  process.exit(fail ? 1 : 0);
})();
