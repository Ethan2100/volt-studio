// Volt Studio itself: opens the real editor window and checks the language-service features
// that a user actually sees - all the problems at once with the right letters underlined,
// autocomplete that knows the file's own names, hover, go to definition, and highlighting
// built from the compiler's word lists.
//
// Skips itself when Electron isn't installed (npm install) or there is no way to open a window.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

module.exports = (t) => {
  t.test('the editor shows problems, completes, hovers and jumps to definitions', () => {
    const electron = path.join(t.ROOT, 'node_modules', '.bin', 'electron');
    if (!fs.existsSync(electron)) return 'skip';
    const driver = path.join(t.ROOT, 'test', 'studio-driver.js');
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-studio-'));
    // a window needs a display; on a headless Linux box xvfb-run provides one
    const headless = process.platform === 'linux' && !process.env.DISPLAY;
    if (headless && spawnSync('xvfb-run', ['--help']).error) { fs.rmSync(out, { recursive: true, force: true }); return 'skip'; }
    const cmd = headless ? 'xvfb-run' : electron;
    const args = headless ? ['-a', electron, '--no-sandbox', driver, out] : ['--no-sandbox', driver, out];
    const r = spawnSync(cmd, args, { encoding: 'utf8', timeout: 180000, cwd: t.ROOT });
    fs.rmSync(out, { recursive: true, force: true });
    const line = String(r.stdout || '').split('\n').find((l) => l.startsWith('RESULTS '));
    if (!line) {
      if (/Running as root without --no-sandbox|cannot open display|Missing X server/i.test(String(r.stderr))) return 'skip';
      throw new Error(`Volt Studio did not report any results.\n${String(r.stderr || r.stdout).slice(0, 900)}`);
    }
    const results = JSON.parse(line.slice('RESULTS '.length));
    const failed = results.filter((x) => !x.ok
      // a machine with no graphics card can't make a WebGL context; that isn't an editor problem
      && !(x.name === 'no console errors' && x.got.every((m) => /WebGL/i.test(m))));
    t.assert.deepStrictEqual(failed.map((f) => `${f.name}: got ${JSON.stringify(f.got)}, wanted ${JSON.stringify(f.want)}`), []);
    t.assert.ok(results.length >= 17, `expected the full set of checks, got ${results.length}`);
  });
};
