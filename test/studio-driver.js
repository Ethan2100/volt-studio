// Drives the real Volt Studio window and checks the editor features work end to end.
//
// Run by test/suite/09-studio.js, which skips it when Electron isn't installed. On Linux it
// needs a display: the suite uses xvfb-run when there is no DISPLAY.
//
//   xvfb-run -a ./node_modules/.bin/electron --no-sandbox test/studio-driver.js /tmp/out
const { app, BrowserWindow } = require('electron');
const path = require('path');
const out = process.argv[process.argv.length - 1];
app.setPath('userData', path.join(out, 'ud'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
app.on('browser-window-created', (e, win) => {
  if (BrowserWindow.getAllWindows().length > 1) return;
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    const errors = [];
    win.webContents.on('console-message', (ev, level, message) => { if (level >= 2) errors.push(message); });
    const setCode = (code) => js(`document.querySelector('#editor .CodeMirror').CodeMirror.setValue(${JSON.stringify(code)}); true`);
    const check = (name, got, want) => { results.push({ name, got, want, ok: JSON.stringify(got) === JSON.stringify(want) }); };
    try {
      await sleep(2000);

      // 1. every problem at once, each underlined at the right columns
      await setCode('#js\nlet score = 0\nprint scroe\nfn never() {\n  let unused = 1\n  return 2\n}\nprint 1');
      await sleep(1200);
      check('problem count', await js('state.problems.length'), 3);
      check('severities', await js('state.problems.map(p => p.severity).join(",")'), 'error,warning,warning');
      check('underlined letters', await js(`(() => {
        const marks = document.querySelectorAll('.squiggle-error');
        return marks.length ? marks[0].textContent : 'none';
      })()`), 'scroe');
      check('gutter marks', await js("document.querySelectorAll('.error-marker, .warning-marker').length"), 3);
      check('warning styled differently', await js("document.querySelectorAll('.warning-widget').length"), 2);

      // 2. a clean file clears everything
      await setCode('#js\nlet a = 1\nprint a');
      await sleep(900);
      check('clean file has no problems', await js('state.problems.length'), 0);
      check('clean file has no squiggles', await js("document.querySelectorAll('.squiggle-error, .squiggle-warning').length"), 0);

      // 3. autocomplete knows the file's own names and the target
      await setCode('#html\ncanvas 320, 180\nlet playerHealth = 10\nlet x = play');
      await sleep(700);
      const hints = await js(`(async () => {
        const cm = document.querySelector('#editor .CodeMirror').CodeMirror;
        cm.setCursor({ line: 3, ch: 12 });
        cm.showHint({ hint: voltHint, completeSingle: false });
        await new Promise(r => setTimeout(r, 700));
        return Array.from(document.querySelectorAll('.CodeMirror-hint .hint-label')).map(e => e.textContent);
      })()`);
      check('autocomplete offers my own variable first', hints[0], 'playerHealth');
      check('autocomplete offers 3D names in #html', hints.includes('player3d') && hints.includes('playerx'), true);

      // 4. hover explains a built-in
      const hov = await js(`(async () => {
        const r = await window.volt.langHover({ source: '#html\\ncanvas 320, 180\\nlet n = aim3d(300)', line: 3, col: 10 });
        return r && r.signature;
      })()`);
      check('hover signature', hov, 'aim3d(range)');

      // 5. go to definition
      await setCode('#js\nlet score = 0\nfn addPoints(n) {\n  score += n\n}\naddPoints(5)');
      await sleep(700);
      check('go to definition jumps', await js(`(async () => {
        const cm = document.querySelector('#editor .CodeMirror').CodeMirror;
        cm.setCursor({ line: 5, ch: 3 });
        await goToDefinition();
        const c = cm.getCursor();
        return c.line + ':' + c.ch;
      })()`), '2:3');

      // 6. the editor colours a word the compiler added recently
      check('new built-in is highlighted', await js(`(() => {
        const cm = document.querySelector('#editor .CodeMirror').CodeMirror;
        cm.setValue('#js\\nlet l = shuffle([1, 2])');
        const tokens = cm.getLineTokens(1);
        const t = tokens.find(x => x.string === 'shuffle');
        return t ? t.type : 'none';
      })()`), 'variable-2');

      check('no console errors', errors.filter((m) => !/Autofill|devtools/i.test(m)), []);
    } catch (err) {
      results.push({ name: 'threw', got: String(err && err.message), want: '', ok: false });
    }
    console.log('RESULTS ' + JSON.stringify(results));
    app.exit(results.every((r) => r.ok) ? 0 : 1);
  });
});
require(path.join(__dirname, '..', 'main.js'));
