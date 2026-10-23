// Test helper: loads the stepper examples into the editor and checks they compile
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
const outDir = process.argv[process.argv.length - 1];
app.setPath('userData', path.join(outDir, 'ud'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
app.on('browser-window-created', (e, win) => {
  if (BrowserWindow.getAllWindows().length > 1) return;
  win.webContents.on('console-message', (ev) => { if ((ev.level === 'error' || ev.level === 3)) console.log('PAGE ERROR', ev.message); });
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    await sleep(1200);
    const ex = await js('window.volt.examples()');
    for (const name of ['stepper_basics', 'joystick_stepper']) {
      const x = ex.find((e) => e.name.includes(name));
      await js(`document.querySelector('#editor .CodeMirror').CodeMirror.setValue(${JSON.stringify(x.content)}); true`);
      await sleep(500);
      console.log(name, '->', await js(`document.getElementById('status').textContent`), '| button:', await js(`document.getElementById('btn-upload').textContent.trim()`));
    }
    fs.writeFileSync(path.join(outDir, 'stepper.png'), (await win.webContents.capturePage()).toPNG());
    app.exit(0);
  });
});
require('../main.js');
