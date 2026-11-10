// The 'volt' command line and the package manager, driven the way a person would use them.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

module.exports = (t) => {
  const cli = path.join(t.ROOT, 'bin', 'volt.js');
  // runs 'volt ...' in its own throwaway folder and returns what it printed
  const run = (cwd, ...args) => {
    const r = spawnSync(process.execPath, [cli, ...args], { cwd, encoding: 'utf8', timeout: 60000 });
    return { out: `${r.stdout || ''}${r.stderr || ''}`.trim(), code: r.status };
  };
  const fresh = () => fs.mkdtempSync(path.join(os.tmpdir(), 'volt-cli-'));
  const write = (dir, name, text) => { fs.writeFileSync(path.join(dir, name), text); return path.join(dir, name); };

  t.test('volt new makes a program, volt build compiles it', () => {
    const dir = fresh();
    t.assert.match(run(dir, 'new', 'game.volt', '3d').out, /Made game\.volt/);
    t.assert.ok(fs.existsSync(path.join(dir, 'game.volt')));
    const built = run(dir, 'build', 'game.volt');
    t.assert.strictEqual(built.code, 0, built.out);
    t.assert.ok(fs.existsSync(path.join(dir, 'game', 'index.html')), 'the page was written next to the .volt file');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('volt new refuses to write over a file', () => {
    const dir = fresh();
    run(dir, 'new', 'a.volt');
    const again = run(dir, 'new', 'a.volt');
    t.assert.strictEqual(again.code, 1);
    t.assert.match(again.out, /already exists/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('volt run really runs the program', () => {
    if (spawnSync('node', ['--version']).error) return 'skip';
    const dir = fresh();
    write(dir, 'p.volt', '#js\nprint "answer {40 + 2}"\n');
    const r = run(dir, 'run', 'p.volt');
    t.assert.match(r.out, /answer 42/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('volt check lists every problem and sets the exit code', () => {
    const dir = fresh();
    write(dir, 'bad.volt', '#js\nlet score = 1\nprint scroe\nfn spare() {\n  return 1\n}\n');
    const bad = run(dir, 'check', 'bad.volt');
    t.assert.strictEqual(bad.code, 1);
    t.assert.match(bad.out, /Did you mean 'score'/);
    t.assert.match(bad.out, /\^\^\^\^\^/, 'points at the word');
    t.assert.match(bad.out, /never called/, 'warnings are listed too');
    t.assert.match(bad.out, /1 error, 1 warning/);

    write(dir, 'good.volt', '#js\nprint 1\n');
    const good = run(dir, 'check', 'good.volt');
    t.assert.strictEqual(good.code, 0, good.out);
    t.assert.match(good.out, /no problems/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('a package can be added from a folder, used, listed and removed', () => {
    const dir = fresh();
    const lib = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-lib-'));
    fs.mkdirSync(path.join(lib, 'src'));
    write(lib, 'volt.json', JSON.stringify({ name: 'shapes', version: '1.2.0', description: 'Area helpers', main: 'src/shapes.volt' }));
    fs.writeFileSync(path.join(lib, 'src', 'shapes.volt'), 'fn area(w, h) {\n  return w * h\n}\n');

    const added = run(dir, 'add', lib);
    t.assert.match(added.out, /Installed 'shapes'/);
    t.assert.ok(fs.existsSync(path.join(dir, 'volt_packages', 'shapes', 'src', 'shapes.volt')));

    const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'volt.json'), 'utf8'));
    t.assert.ok(manifest.dependencies.shapes, 'the package is written into volt.json');

    t.assert.match(run(dir, 'list').out, /shapes 1\.2\.0 - Area helpers/);

    write(dir, 'uses.volt', '#js\nimport "shapes"\nprint area(3, 4)\n');
    t.assert.match(run(dir, 'run', 'uses.volt').out, /12/);

    // a program in a subfolder finds the package too
    fs.mkdirSync(path.join(dir, 'deep', 'deeper'), { recursive: true });
    write(dir, path.join('deep', 'deeper', 'sub.volt'), '#js\nimport "shapes"\nprint area(2, 5)\n');
    t.assert.match(run(dir, 'run', path.join('deep', 'deeper', 'sub.volt')).out, /10/);

    const removed = run(dir, 'remove', 'shapes');
    t.assert.match(removed.out, /Removed 'shapes'/);
    t.assert.ok(!fs.existsSync(path.join(dir, 'volt_packages', 'shapes')));
    t.assert.match(run(dir, 'check', 'uses.volt').out, /volt add shapes/, 'and says how to get it back');

    // volt install puts it back from volt.json
    const manifest2 = JSON.parse(fs.readFileSync(path.join(dir, 'volt.json'), 'utf8'));
    manifest2.dependencies = { shapes: lib };
    fs.writeFileSync(path.join(dir, 'volt.json'), JSON.stringify(manifest2));
    t.assert.match(run(dir, 'install').out, /Installed 1 package/);
    t.assert.match(run(dir, 'run', 'uses.volt').out, /12/);

    fs.rmSync(dir, { recursive: true, force: true });
    fs.rmSync(lib, { recursive: true, force: true });
  });

  t.test('a folder with no .volt files in it is not a package', () => {
    const dir = fresh();
    const notLib = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-notlib-'));
    write(notLib, 'readme.txt', 'nothing here');
    const r = run(dir, 'add', notLib);
    t.assert.strictEqual(r.code, 1);
    t.assert.match(r.out, /no \.volt files/);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.rmSync(notLib, { recursive: true, force: true });
  });

  t.test('volt docs explains a built-in', () => {
    const dir = fresh();
    t.assert.match(run(dir, 'docs', 'round').out, /round\(number\)/);
    t.assert.match(run(dir, 'docs', 'shuffle').out, /random order/);
    t.assert.match(run(dir, 'docs').out, /Built-in functions:/);
    t.assert.strictEqual(run(dir, 'docs', 'nope').code, 1);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('unknown commands and missing files say what to do', () => {
    const dir = fresh();
    const unknown = run(dir, 'frobnicate');
    t.assert.strictEqual(unknown.code, 1);
    t.assert.match(unknown.out, /isn't a Volt command/);
    const missing = run(dir, 'build', 'nope.volt');
    t.assert.strictEqual(missing.code, 1);
    t.assert.match(missing.out, /Can't find 'nope\.volt'/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('the addon targets work from the command line too', () => {
    const dir = fresh();
    write(dir, 'r.volt', '#luau\nfn dist(a, b) {\n  return a - b\n}\nprint dist(10, 4)\n');
    const r = run(dir, 'build', 'r.volt');
    t.assert.strictEqual(r.code, 0, r.out);
    t.assert.ok(fs.existsSync(path.join(dir, 'r', 'r.luau')), r.out);
    fs.rmSync(dir, { recursive: true, force: true });
  });
};
