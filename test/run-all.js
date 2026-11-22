// Runs every test that needs nothing but Node, and says how it went.
// The Electron-only tests (features, ghost, upload, stepper, assets-ui,
// screenshots) need a running app and are skipped here.
//   Run with: npm test
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const dir = __dirname;
// Anything that does require('electron') needs a running app, so it is
// found by looking rather than by keeping a list that goes stale.
const needsElectron = (f) => /require\(['"]electron['"]\)/.test(fs.readFileSync(path.join(dir, f), 'utf8'));

const files = fs.readdirSync(dir)
  .filter((f) => f.endsWith('-test.js'))
  .filter((f) => !needsElectron(f))
  .sort();

const skipped = fs.readdirSync(dir).filter((f) => f.endsWith('-test.js') && needsElectron(f)).sort();

let failed = 0, passed = 0;
for (const f of files) {
  let out = '';
  let ok = true;
  try {
    out = execFileSync(process.execPath, [path.join(dir, f)], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    ok = false;
    out = (e.stdout || '') + (e.stderr || '');
  }
  const p = (out.match(/^pass/gm) || []).length;
  const x = (out.match(/^FAIL/gm) || []).length;
  passed += p; failed += x;
  console.log(`${ok && !x ? 'ok  ' : 'FAIL'}  ${f.padEnd(26)} ${p} passed${x ? `, ${x} failed` : ''}`);
  if (!ok || x) {
    for (const line of out.split('\n')) if (/^FAIL|Error|error:/.test(line)) console.log('        ' + line);
    if (!x) failed++;        // crashed without reporting a single FAIL
  }
}
console.log(`\n${passed} passed, ${failed} failed, across ${files.length} files`);
if (skipped.length) console.log(`(${skipped.length} need a running app and were skipped: ${skipped.join(', ')})`);
process.exitCode = failed ? 1 : 0;
