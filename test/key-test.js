// Test helper: previews the key game and presses keys in the preview window
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
const outDir = process.argv[process.argv.length - 1];
app.setPath('userData', path.join(outDir, 'ud'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
app.on('browser-window-created', (e, win) => {
  if (BrowserWindow.getAllWindows().length > 1) return;
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    await sleep(1200);
    const ex = await js('window.volt.examples()');
    const game = ex.find((x) => x.name.includes('key_game'));
    console.log('example found:', !!game, '| examples:', ex.length);
    await js(`document.querySelector('#editor .CodeMirror').CodeMirror.setValue(${JSON.stringify(game.content)}); true`);
    await sleep(400);
    console.log('status:', await js(`document.getElementById('status').textContent`));
    await js(`document.getElementById('btn-upload').click()`);
    await sleep(2000);
    const prev = BrowserWindow.getAllWindows().find((w) => w !== win);
    prev.focus(); prev.webContents.focus();
    const press = async (keyCode) => {
      prev.webContents.sendInputEvent({ type: 'keyDown', keyCode });
      prev.webContents.sendInputEvent({ type: 'char', keyCode });
      prev.webContents.sendInputEvent({ type: 'keyUp', keyCode });
      await sleep(80);
    };
    for (const k of ['k', 'k', 'k', 'Space', 'k']) await press(k);
    await sleep(300);
    console.log('page:', (await prev.webContents.executeJavaScript(`document.getElementById('volt').innerText`)).replace(/\n+/g, ' | '));
    fs.writeFileSync(path.join(outDir, 'preview.png'), (await prev.webContents.capturePage()).toPNG());
    app.exit(0);
  });
});
require('../main.js');
