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

      // 7. panel targets: an addon only shows up for the first lines it is any use for
      const visibleTabs = () => js(`Array.from(document.querySelectorAll('.tabs[data-group="side"] button')).filter(b => !b.classList.contains('hidden')).map(b => b.textContent.trim())`);
      await setCode('#html\ncanvas 320, 180\nevery frame {\n  paint "#000"\n}');
      await sleep(1000);
      const web = await visibleTabs();
      check('panel targets: web page shows the UI and world editors', web.includes('UI Studio') && web.includes('World Studio') && !web.includes('Pin Diagram'), true);
      // open one, then change the first line under it
      await js("showTab('side', 'panel-world-studio'); true");
      await setCode('#c++\npin led = 13\nevery 500ms {\n  toggle led\n}');
      await sleep(1000);
      const board = await visibleTabs();
      check('panel targets: a board shows the pinout instead', board.includes('Pin Diagram') && !board.includes('World Studio') && !board.includes('UI Studio'), true);
      check('panel targets: a tab that stops fitting does not stay open', await js(`document.querySelector('[data-panel="panel-world-studio"]').classList.contains('active')`), false);
      check('panel targets: the library says when snippets are hidden', /other kinds of program/.test(await js("(document.getElementById('library-hidden')||{}).textContent || ''")), true);
      await setCode('#python\nprint 1');
      await sleep(900);
      const script = await visibleTabs();
      check('panel targets: a plain script shows neither', !script.includes('Pin Diagram') && !script.includes('World Studio'), true);

      // 8. a program that uses `import` compiles in the editor, not just on Run.
      //    The live compile used to drop the file's own folder, so every such file
      //    showed a red error on a correct line and Run and Upload refused to start.
      const imported = path.join(__dirname, '..', 'examples', '22_import_library.volt');
      await js(`(async () => {
        const r = await window.volt.openPath(${JSON.stringify(imported)});
        loadDocument(r.content, r.path);
      })()`);
      await sleep(1400);
      check('a file that imports has no problems', await js('state.problems.length'), 0);
      check('a file that imports compiles', await js('state.lastResult.ok'), true);

      // 9. a language added by an addon (#lua ships in plugins/) is a language the
      //    editor knows about, rather than a crash on the status line and a blank menu
      await js("state.filePath = null; true");
      await setCode('#lua\nlet x = 1\nprint x');
      await sleep(1200);
      check('an addon language compiles', await js('state.lastResult.ok'), true);
      check('an addon language names itself in the toolbar', await js("document.getElementById('status-target').textContent"), 'Lua');
      check('an addon language is in the language menu', await js("document.getElementById('target-select').value"), 'lua');
      check('an addon language says so on the status line', /compiles to Lua/.test(await js("document.getElementById('status').textContent")), true);

      // 10. picking a language while an addon file is open replaces its first line
      //     instead of adding a second one
      await js("switchTarget('python'); true");
      await sleep(900);
      check('switching away from an addon language replaces line 1',
        await js(`document.querySelector('#editor .CodeMirror').CodeMirror.getValue().split('\\n').slice(0, 2).join('|')`),
        '#python|let x = 1');
      check('switching away from an addon language leaves a program that compiles', await js('state.lastResult.ok'), true);

      // 11. Escape closes a dialog, and takes the way out rather than the action
      const escaped = await js(`(async () => {
        const p = modal('Test', '<p>x</p>', [{ label: 'Cancel' }, { label: 'Replace', primary: true }]);
        await new Promise(r => setTimeout(r, 120));
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
        const choice = await p;
        return choice + ':' + document.getElementById('modal').classList.contains('hidden');
      })()`);
      check('Escape closes a dialog by cancelling', escaped, '0:true');

      // 12. a save that cannot be written says so instead of looking like it worked
      const refused = await js(`(async () => {
        const r = await window.volt.save({ filePath: ${JSON.stringify(path.join(out, 'no', 'such', 'folder', 'x.volt'))}, content: 'x' });
        return r && r.error ? 'reported' : 'silent';
      })()`);
      check('a save that fails is reported', refused, 'reported');

      check('no console errors', errors.filter((m) => !/Autofill|devtools/i.test(m)), []);
    } catch (err) {
      results.push({ name: 'threw', got: String(err && err.message), want: '', ok: false });
    }
    console.log('RESULTS ' + JSON.stringify(results));
    app.exit(results.every((r) => r.ok) ? 0 : 1);
  });
});
require(path.join(__dirname, '..', 'main.js'));
