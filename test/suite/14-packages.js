// The packages that ship with Volt, in packages/. They are installed and used the way a person
// would, and their answers are checked - a library nobody tests is a library that quietly rots.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

module.exports = (t) => {
  const cli = path.join(t.ROOT, 'bin', 'volt.js');
  const packagesDir = path.join(t.ROOT, 'packages');
  const run = (cwd, ...args) => {
    const r = spawnSync(process.execPath, [cli, ...args], { cwd, encoding: 'utf8', timeout: 60000 });
    return `${r.stdout || ''}${r.stderr || ''}`.trim();
  };

  // installs the named packages into a throwaway project, runs the program, returns its output
  const withPackages = (names, program) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-pkg-'));
    try {
      for (const name of names) {
        const out = run(dir, 'add', path.join(packagesDir, name));
        if (!/Installed/.test(out)) throw new Error(`could not install ${name}: ${out}`);
      }
      fs.writeFileSync(path.join(dir, 'p.volt'), program);
      const out = run(dir, 'run', 'p.volt');
      return out.split('\n').filter((l) => !/^Built /.test(l)).join('\n');
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  };

  t.test('every package in packages/ has a volt.json and compiles', () => {
    const names = fs.readdirSync(packagesDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
    t.assert.ok(names.length >= 2, 'expected some packages to ship');
    const volt = t.volt();
    for (const name of names) {
      const manifest = JSON.parse(fs.readFileSync(path.join(packagesDir, name, 'volt.json'), 'utf8'));
      t.assert.strictEqual(manifest.name, name, `${name}/volt.json calls itself something else`);
      t.assert.ok(manifest.description, `${name} has no description`);
      const main = path.join(packagesDir, name, manifest.main);
      t.assert.ok(fs.existsSync(main), `${name}/volt.json points at ${manifest.main}, which isn't there`);
      // a library has no first line of its own, so give it one to check it compiles
      const e = t.errorOf(volt, `#js\n${fs.readFileSync(main, 'utf8')}\nprint 1`, { baseDir: path.dirname(main) });
      t.assert.strictEqual(e, null, e ? `${name}: ${e.message} (line ${e.line})` : '');
    }
  });

  t.test('tween: the curves start at 0, end at 100 and never leave the range', () => {
    const out = withPackages(['tween'], [
      '#js',
      'import "tween"',
      'let ends = []',
      'for each name, i in ["in", "out", "inOut", "back", "bounce"] {',
      '  add name to ends',
      '}',
      'print "{easeIn(0)} {easeIn(100)} {easeOut(0)} {easeOut(100)} {easeInOut(0)} {easeInOut(100)}"',
      'print "{easeBack(0)} {easeBack(100)} {easeBounce(0)} {easeBounce(100)}"',
      'let bad = 0',
      'for i from 0 to 100 {',
      '  if easeIn(i) < 0 or easeIn(i) > 100 { bad += 1 }',
      '  if easeOut(i) < 0 or easeOut(i) > 100 { bad += 1 }',
      '  if easeInOut(i) < 0 or easeInOut(i) > 100 { bad += 1 }',
      '  if easeBounce(i) < 0 or easeBounce(i) > 100 { bad += 1 }',
      '}',
      'print "out of range {bad}"',
      'print "eased out is ahead of eased in: {easeOut(25) > easeIn(25)}"',
      'print "clamped {easeIn(0 - 50)} {easeOut(500)}"',
    ].join('\n'));
    t.assert.strictEqual(out, [
      '0 100 0 100 0 100',
      '0 100 0 100',
      'out of range 0',
      'eased out is ahead of eased in: true',
      'clamped 0 100',
    ].join('\n'));
  });

  t.test('tween: progress and shake behave', () => {
    const out = withPackages(['tween'], [
      '#js',
      'import "tween"',
      'print "{progress(uptime, 0)} {progress(uptime - 1000, 500)}"',
      'let big = 0',
      'repeat 200 {',
      '  if abs(shake(10, 0)) > 10 { big += 1 }',
      '  if shake(10, 100) != 0 { big += 1 }',
      '}',
      'print "outside the shake {big}"',
    ].join('\n'));
    t.assert.strictEqual(out, '100 100\noutside the shake 0');
  });

  t.test('grid: reading, writing, edges and neighbours', () => {
    const out = withPackages(['grid'], [
      '#js',
      'import "grid"',
      'let board = gridNew(4, 3, 0)',
      'gridSet(board, 4, 1, 1, 7)',
      'print "{gridGet(board, 4, 1, 1)} {gridGet(board, 4, 0, 0)} {gridHeight(board, 4)} {length(board)}"',
      '// off the grid reads as the value you give, and writing there changes nothing',
      'print "{gridGetOr(board, 4, 9, 9, 5)} {gridGetOr(board, 4, 0 - 1, 0, 5)} {gridInside(board, 4, 9, 0)}"',
      'gridSet(board, 4, 9, 9, 3)',
      'print "still {length(board)} squares, {gridCount(board, 4, 3)} threes"',
      'gridRow(board, 4, 0, "#..#", "#")',
      'print "walls {gridCount(board, 4, 1)}"',
      'print "around {join(gridAround(board, 4, 0, 0, 9), ",")}"',
    ].join('\n'));
    t.assert.strictEqual(out, [
      '7 0 3 12',
      '5 5 false',
      'still 12 squares, 0 threes',
      'walls 2',
      'around 9,0,0,9',
    ].join('\n'));
  });
};
