// Test helper: runs scripts using the new features inside the app
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
    const setCode = (code) => js(`document.querySelector('#editor .CodeMirror').CodeMirror.setValue(${JSON.stringify(code)}); true`);
    const waitStopped = async () => { for (let i = 0; i < 100; i++) { if (!(await js('state.running'))) return; await sleep(100); } };
    await sleep(1200);
    // 1. clear wipes the console; input works; for counts down
    await setCode('#python\nprint "this line gets cleared"\nclear\nlet name = input("Name?")\nfor i from 3 to 1 {\n  print i\n}\nprint "Bye " + upper(name)\n');
    await sleep(400);
    await js(`document.getElementById('btn-upload').click()`);
    await sleep(1200);
    await js(`(() => { const i = document.getElementById('stdin-input'); i.value = 'ethan'; document.getElementById('console-input').requestSubmit(); })()`);
    await waitStopped();
    console.log('--- console after python run:\n' + await js(`document.getElementById('console').textContent`));
    // 2. stop inside a timer (JS)
    await setCode('#js\nlet n = 0\nevery 100ms {\n  n += 1\n  print "tick " + n\n  if n == 3 {\n    stop\n  }\n}\n');
    await sleep(400);
    await js(`document.getElementById('btn-upload').click()`);
    await sleep(800);
    await waitStopped();
    console.log('--- console after js stop:\n' + await js(`document.getElementById('console').textContent`));
    // 3. key game example with show
    const ex = await js('window.volt.examples()');
    await setCode(ex.find((x) => x.name.includes('key_game')).content);
    await sleep(400);
    await js(`document.getElementById('btn-upload').click()`);
    await sleep(2000);
    const prev = BrowserWindow.getAllWindows().find((w) => w !== win);
    prev.focus(); prev.webContents.focus();
    for (const k of ['k', 'k', 'k', 'k', 'Space', 'k']) {
      prev.webContents.sendInputEvent({ type: 'keyDown', keyCode: k });
      prev.webContents.sendInputEvent({ type: 'char', keyCode: k });
      prev.webContents.sendInputEvent({ type: 'keyUp', keyCode: k });
      await sleep(80);
    }
    await sleep(300);
    console.log('--- key game page:', (await prev.webContents.executeJavaScript(`document.getElementById('volt').innerText`)).replace(/\n+/g, ' | '));
    fs.writeFileSync(path.join(outDir, 'keygame.png'), (await prev.webContents.capturePage()).toPNG());
    // editor screenshot with new syntax
    await setCode('#js\nlet score = 0\nlet name = input("Name?")\n\nfor i from 1 to 5 {\n  score += i\n}\n\nif contains(lower(name), "eth") {\n  show "Hi " + upper(name) + "! Score: " + score\n}\nclear\nstop\n');
    await sleep(600);
    fs.writeFileSync(path.join(outDir, 'editor.png'), (await win.webContents.capturePage()).toPNG());
    app.exit(0);
  });
});
require('../main.js');
