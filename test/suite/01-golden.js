// Golden output: every .volt file in the repo must compile to exactly the output recorded in
// test/golden.json (or fail with exactly the recorded error). This is what guarantees that a
// compiler change did not alter any existing program. If a change is deliberate, run
//   UPDATE_GOLDEN=1 npm test
// and explain the change in NOTES.md.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

module.exports = (t) => {
  const goldenFile = path.join(t.ROOT, 'test', 'golden.json');
  const golden = fs.existsSync(goldenFile) ? JSON.parse(fs.readFileSync(goldenFile, 'utf8')) : {};
  const volt = t.volt();
  const files = [];
  (function walk(dir) {
    for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
      if (['node_modules', '.git', 'dist', 'volt_packages'].includes(f.name)) continue;
      const p = path.join(dir, f.name);
      if (f.isDirectory()) walk(p);
      else if (f.name.endsWith('.volt')) files.push(p);
    }
  }(t.ROOT));
  files.sort();

  const now = {};
  for (const file of files) {
    const rel = path.relative(t.ROOT, file).replace(/\\/g, '/');
    if (rel.startsWith('test/')) continue;
    let got;
    try {
      let src = fs.readFileSync(file, 'utf8');
      // A library has no first line of its own: a plugin snippet gets pasted into an #html
      // program, and a package is imported by whatever program wants it. Give each one a first
      // line here so it can be compiled at all.
      const first = src.split('\n').map((l) => l.trim()).find((l) => l && !l.startsWith('//')) || '';
      if (!/^#[a-z+]+$/i.test(first)) {
        if (rel.startsWith('plugins/')) src = '#html\n' + src;
        else if (rel.startsWith('packages/')) src = '#js\n' + src;
      }
      const r = volt.compile(src, { baseDir: path.dirname(file) });
      got = { target: r.target, sha1: crypto.createHash('sha1').update(r.code).digest('hex'), bytes: r.code.length };
    } catch (e) {
      if (!(e instanceof volt.VoltError)) throw e;
      got = { error: `line ${e.line}: ${e.message}` };
    }
    now[rel] = got;
    t.test(rel, () => {
      const want = golden[rel];
      if (process.env.UPDATE_GOLDEN) return;
      if (!want) throw new Error('not in test/golden.json yet - run UPDATE_GOLDEN=1 npm test to add it');
      t.assert.deepStrictEqual(got, want, `output changed.\n  was: ${JSON.stringify(want)}\n  now: ${JSON.stringify(got)}`);
    });
  }
  if (process.env.UPDATE_GOLDEN) {
    fs.writeFileSync(goldenFile, JSON.stringify(now, null, 1) + '\n');
    console.log(`  wrote test/golden.json (${Object.keys(now).length} files)`);
  }
};
