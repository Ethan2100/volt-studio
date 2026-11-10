// Every Volt program in the documentation is compiled, so an example can't quietly stop working.
//
// A ```volt block whose first real line picks a target (#html, #c++ ...) is compiled as a whole
// program. A block without one is a fragment shown to explain a point, and is only checked for
// balanced braces. A block that is deliberately wrong is marked in the line before it with
//     <!-- volt-doc: error -->       this must NOT compile
//     <!-- volt-doc: skip -->        don't check this one, and why
const fs = require('fs');
const path = require('path');

function blocks(text, file) {
  const out = [];
  const lines = text.replace(/\r\n?/g, '\n').split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (!/^```volt\s*$/.test(lines[i])) continue;
    const marker = /<!--\s*volt-doc:\s*(\w+)\s*-->/.exec(lines[i - 1] || '');
    const start = i + 1;
    let end = start;
    while (end < lines.length && !/^```\s*$/.test(lines[end])) end++;
    out.push({ file, line: start + 1, code: lines.slice(start, end).join('\n'), mode: marker ? marker[1] : 'check' });
    i = end;
  }
  return out;
}

module.exports = (t) => {
  const volt = t.volt();
  const docsDir = path.join(t.ROOT, 'docs');
  // the odd example refers to a picture or a library file; test/doc-fixtures holds stand-ins
  const where = { baseDir: docsDir, extraDirs: [path.join(t.ROOT, 'test', 'doc-fixtures')] };
  const files = [path.join(t.ROOT, 'README.md'), ...fs.readdirSync(docsDir).filter((f) => f.endsWith('.md')).map((f) => path.join(docsDir, f))];
  const all = [];
  for (const file of files) {
    if (!fs.existsSync(file)) continue;
    all.push(...blocks(fs.readFileSync(file, 'utf8'), path.relative(t.ROOT, file).replace(/\\/g, '/')));
  }

  t.test('the documentation has Volt examples in it', () => {
    t.assert.ok(all.length > 40, `only found ${all.length} volt blocks`);
  });

  const hasTarget = (code) => {
    const first = code.split('\n').map((l) => l.trim()).find((l) => l && !l.startsWith('//'));
    return !!first && /^#[A-Za-z+]+$/.test(first) && !/^#(include|define|ifdef|ifndef|endif|pragma|undef)$/i.test(first);
  };

  for (const b of all) {
    if (b.mode === 'skip') continue;
    const name = `${b.file}:${b.line}`;
    if (b.mode === 'error') {
      t.test(`${name} is meant to be wrong, and is`, () => {
        t.assert.ok(t.errorOf(volt, b.code, where), 'this example compiled, but the docs say it should not');
      });
      continue;
    }
    if (hasTarget(b.code)) {
      t.test(`${name} compiles`, () => {
        const e = t.errorOf(volt, b.code, where);
        if (e) throw new Error(`${e.message}\n${volt.formatProblem(e, b.file, () => b.code)}`);
      });
    } else {
      t.test(`${name} is balanced`, () => {
        let depth = 0;
        for (const ch of b.code.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/\/\/.*/g, '')) {
          if (ch === '{') depth++;
          if (ch === '}') depth--;
          t.assert.ok(depth >= 0, 'a } with no { before it');
        }
        t.assert.strictEqual(depth, 0, 'the { and } in this example do not match up');
      });
    }
  }
};
