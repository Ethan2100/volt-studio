// An addon can say which first lines it is any use for ("targets" in plugin.json), so a 3D world
// editor doesn't sit in an Arduino sketch and a pinout chart doesn't sit in a web page.
const fs = require('fs');
const os = require('os');
const path = require('path');

module.exports = (t) => {
  const plugins = require(path.join(t.ROOT, 'lib', 'plugins.js'));

  t.test('target names are understood however they are written', () => {
    for (const [given, want] of [['html', 'html'], ['#c++', 'cpp'], ['arduino', 'cpp'], ['MicroPython', 'micropython'],
      ['py', 'python'], ['JavaScript', 'js'], ['luau', 'luau']]) {
      t.assert.strictEqual(plugins.normalizeTarget(given), want, given);
    }
    t.assert.strictEqual(plugins.normalizeTarget('not a target'), null);
  });

  t.test('a manifest with a bad targets list is reported, not silently ignored', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-plug-'));
    const make = (targets) => {
      const one = path.join(dir, 'thing');
      fs.mkdirSync(one, { recursive: true });
      fs.writeFileSync(path.join(one, 'plugin.json'), JSON.stringify({ name: 'thing', type: 'library', targets }));
      return plugins.scanPlugins(dir, path.join(dir, 'none'))[0];
    };
    t.assert.match(make('html').error, /must be a list of target names/);
    t.assert.match(make(['html', 'nonsense name']).error, /name Volt doesn't know/);
    t.assert.strictEqual(make(['#c++', 'arduino']).manifest.targets.join(), 'cpp', 'the same target twice counts once');
    t.assert.strictEqual(make(undefined).manifest.targets, undefined, 'leaving it out still means all targets');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  t.test('the bundled addons say what they are for', () => {
    const found = {};
    for (const p of plugins.scanPlugins(path.join(t.ROOT, 'plugins'), path.join(t.ROOT, '.none'))) {
      t.assert.ok(!p.broken, `${p.id}: ${p.error}`);
      found[p.id] = p.manifest.targets || null;
    }
    t.assert.deepStrictEqual(found['world-studio'], ['html'], 'a 3D world editor is for web pages');
    t.assert.deepStrictEqual(found['ui-studio'], ['html']);
    t.assert.deepStrictEqual(found['pin-diagram'], ['cpp', 'micropython'], 'a pinout chart is for boards');
    t.assert.deepStrictEqual(found['ui-kit'], ['html']);
  });

  t.test('one addon can hold snippets for different targets', () => {
    const kit = plugins.scanPlugins(path.join(t.ROOT, 'plugins'), path.join(t.ROOT, '.none')).find((p) => p.id === 'studio-kit');
    const tagged = kit.manifest.snippets.filter((s) => s.targets);
    t.assert.ok(tagged.length >= 3, 'its snippets should each say what they are for');
    for (const s of tagged) t.assert.ok(fs.existsSync(path.join(kit.dir, s.file)), s.file);
  });

  // the live behaviour, driven in the real window, lives in test/studio-driver.js
  t.test('Volt Studio hides and shows the tabs as the first line changes', () => {
    const driver = path.join(t.ROOT, 'test', 'studio-driver.js');
    t.assert.ok(fs.readFileSync(driver, 'utf8').includes('panel targets'), 'the window test should cover this too');
  });
};
