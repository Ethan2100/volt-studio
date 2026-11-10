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
