// Test helper: new-file picker, running scripts with input, and the HTML preview
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
const outDir = process.argv[process.argv.length - 1];
app.setPath('userData', path.join(outDir, 'ud'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
app.on('browser-window-created', (e, win) => {
  if (BrowserWindow.getAllWindows().length > 1) return;   // only drive the main window
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    const shot = async (name, w = win) => { await sleep(500); fs.writeFileSync(path.join(outDir, `${name}.png`), (await w.webContents.capturePage()).toPNG()); console.log('saved', name); };
    const consoleText = () => js(`document.getElementById('console').textContent`);
    const typeAnswer = (t) => js(`(() => { const i = document.getElementById('stdin-input'); i.value = ${JSON.stringify(t)}; document.getElementById('console-input').requestSubmit(); })()`);
    const waitStopped = async () => { for (let i = 0; i < 100; i++) { if (!(await js('state.running'))) return; await sleep(100); } };
    try {
      await sleep(1200);
      // 1. New-file picker
      js(`document.getElementById('btn-new').click()`);
      await shot('1-new-picker');
      await js(`document.querySelectorAll('.new-card')[2].click()`);   // Python
      await sleep(400);
      console.log('target after picking Python:', await js('state.target'));
      await js(`document.querySelector('[data-group="bottom"] [data-tab="console"]').click()`);

      // 2. Run the Python starter with typed answers
      await js(`document.getElementById('btn-upload').click()`);
      await sleep(1200);
      await shot('2-python-waiting');
      await typeAnswer('Ethan');
      await waitStopped();
      console.log('--- python console:\n' + await consoleText());
      await shot('3-python-done');

      // 3. Ruby via the language list
      await js(`(() => { const s = document.getElementById('target-select'); s.value = 'ruby'; s.dispatchEvent(new Event('change')); })()`);
      await sleep(500);
      await js(`document.getElementById('btn-upload').click()`);
      await sleep(1200);
      await typeAnswer('Amani');
      await waitStopped();
      console.log('--- ruby console:\n' + await consoleText());

      // 4. JavaScript (built-in runner) with a timer, then Stop
      await js(`cm = document.querySelector('#editor .CodeMirror').CodeMirror; cm.setValue('#js\\nlet n = 0\\nevery 200ms {\\n  n = n + 1\\n  print "tick " + n\\n}\\n'); true`);
      await sleep(400);
      await js(`document.getElementById('btn-upload').click()`);
      await sleep(1300);
      console.log('button while running:', await js(`document.getElementById('btn-upload').textContent.trim()`));
      await shot('4-js-running');
      await js(`document.getElementById('btn-upload').click()`);   // Stop
      await waitStopped();
      console.log('--- js console:\n' + await consoleText());

      // 5. HTML preview
      const ex = await js(`window.volt.examples()`);
      const page = ex.find((x) => x.name.includes('click_counter'));
      await js(`document.querySelector('#editor .CodeMirror').CodeMirror.setValue(${JSON.stringify(page.content)}); true`);
      await sleep(400);
      console.log('primary button for html:', await js(`document.getElementById('btn-upload').textContent.trim()`));
      await shot('5-html-editor');
      await js(`document.getElementById('btn-upload').click()`);
      await sleep(2000);
      const prev = BrowserWindow.getAllWindows().find((w) => w !== win);
      if (prev) {
        for (let i = 0; i < 5; i++) await prev.webContents.executeJavaScript(`document.querySelector('button').click()`);
        await shot('6-preview', prev);
        console.log('preview text:', (await prev.webContents.executeJavaScript(`document.getElementById('volt').innerText`)).replace(/\n+/g, ' | '));
      } else console.log('NO PREVIEW WINDOW');
      console.log('interpreters:', JSON.stringify(await js('window.volt.interpreters()')));
      // 6. Examples list
      await js(`document.querySelector('[data-tab="examples"]').click()`);
      await shot('7-examples');
    } catch (err) { console.error('TEST ERROR', err); }
    app.exit(0);
  });
});
require('../main.js');
