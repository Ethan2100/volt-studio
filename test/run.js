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
    if (target === 'cpp') return t.runCpp(code);
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
  // Compiles Arduino C++ with g++ against test/arduino-stub/Arduino.h and runs it:
  // setup() once, then loop() three times. Serial.println goes to the output.
  runCpp(code) {
    const { spawnSync } = require('child_process');
    if (spawnSync('g++', ['--version']).error) return null;
    const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'volt-cpp-'));
    fs.writeFileSync(path.join(tmp, 'p.cpp'), '#include "Arduino.h"\n' + code.replace(/#include <Servo\.h>/g, ''));
    const c = spawnSync('g++', ['-std=c++11', '-w', '-I', path.join(__dirname, 'arduino-stub'), '-o', path.join(tmp, 'p'), path.join(tmp, 'p.cpp')], { encoding: 'utf8', timeout: 60000 });
    if (c.status !== 0) { fs.rmSync(tmp, { recursive: true, force: true }); throw new Error(`the C++ did not compile:\n${c.stderr}\n--- generated code ---\n${code}`); }
    const r = spawnSync(path.join(tmp, 'p'), [], { encoding: 'utf8', timeout: 20000 });
    fs.rmSync(tmp, { recursive: true, force: true });
    if (r.status !== 0) throw new Error(`the C++ program crashed:\n${r.stderr}`);
    return r.stdout.trimEnd();
  },
  // Runs the same program as #js, #python and #ruby and checks all three print 'expected'
  same(volt, body, expected, targets = ['js', 'python', 'ruby']) {
    for (const target of targets) {
      const got = t.run(volt, `#${target === 'cpp' ? 'c++' : target}\n${body}`);
      if (got === null) continue;
      assert.strictEqual(got, expected, `#${target} printed something different`);
    }
  },
  // Opens a compiled #html program in headless Chrome and hands the page to fn(page).
  // Needs the 'playwright' package and a Chrome/Chromium; returns 'skip' when they aren't here.
  //   await t.page(volt, '#html\n...', async (page) => { ... })
  async page(volt, src, fn, options = {}) {
    const b = await t.browser();
    if (!b) return 'skip';
    const { code } = volt.compile(src, options.dir ? { baseDir: options.dir } : {});
    const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'volt-page-'));
    fs.writeFileSync(path.join(tmp, 'index.html'), code);
    const page = await b.newPage({ viewport: { width: 640, height: 360 } });
    const problems = [];
    page.on('console', (m) => { if (m.type() === 'error') problems.push(m.text()); });
    page.on('pageerror', (e) => problems.push(e.message));
    try {
      await page.goto('file://' + path.join(tmp, 'index.html'));
      await page.waitForTimeout(options.wait || 400);
      const result = await fn(page);
      const shown = await page.evaluate(() => Array.from(document.querySelectorAll('.volt-error')).map((e) => e.textContent));
      if (!options.allowErrors && (problems.length || shown.length)) throw new Error(`the page reported problems:\n${[...problems, ...shown].join('\n').slice(0, 1500)}`);
      return result;
    } finally {
      await page.close();
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  },
  async browser() {
    if (t._browser !== undefined) return t._browser;
    t._browser = null;
    let pw = null;
    const { execSync } = require('child_process');
    const places = ['playwright', process.env.VOLT_PLAYWRIGHT, '/opt/npm-tools/node_modules/playwright'];
    try { places.push(path.join(execSync('npm root -g', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(), 'playwright')); } catch (e) { /* no npm */ }
    for (const place of places.filter(Boolean)) { try { pw = require(place); break; } catch (e) { /* try the next */ } }
    if (!pw) return null;
    const args = ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
    const exes = [undefined, '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'];
    for (const executablePath of exes) {
      if (executablePath && !fs.existsSync(executablePath)) continue;
      try { t._browser = await pw.chromium.launch({ args, executablePath }); break; } catch (e) { /* try the next */ }
    }
    return t._browser;
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
  if (t._browser) await t._browser.close();
  console.log(`\n${pass} passed, ${fail} failed${skipped ? `, ${skipped} skipped` : ''}  (${Date.now() - started} ms)`);
  process.exit(fail ? 1 : 0);
})();
