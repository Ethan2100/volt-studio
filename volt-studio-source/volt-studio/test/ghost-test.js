// Test helper: types into the editor and checks the ghost suggestions + Tab
const { app } = require('electron');
const fs = require('fs');
const path = require('path');
const outDir = process.argv[process.argv.length - 1];
app.setPath('userData', path.join(outDir, 'ud'));
app.on('browser-window-created', (e, win) => {
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    await sleep(1200);
    await js(`window.cm = document.querySelector('#editor .CodeMirror').CodeMirror;
      cm.setValue('#c++\\npin led = 13\\npin glow = 9 pwm\\npin button = 2 input\\n\\nforever {\\n  \\n}\\n');
      cm.setCursor({line: 6, ch: 2}); cm.focus();
      window.typeText = (t) => { for (const ch of t) cm.replaceRange(ch, cm.getCursor(), cm.getCursor(), '+input'); };
      window.pressTab = () => cm.triggerOnKeyDown({ type: 'keydown', keyCode: 9, preventDefault() {}, stopPropagation() {} });
      window.ghostText = () => { const g = document.querySelector('.cm-ghost'); return g ? g.firstChild.textContent : null; };
      true`);
    const step = async (label, typed) => {
      await js(`typeText(${JSON.stringify(typed)})`);
      await sleep(200);
      const g = await js('ghostText()');
      console.log(`${label.padEnd(28)} ghost: ${JSON.stringify(g)}`);
      return g;
    };
    await step('typed "fade g"', 'fade g');
    const img = await win.webContents.capturePage();
    fs.writeFileSync(path.join(outDir, 'ghost.png'), img.toPNG());
    await js('pressTab()');
    await step('after Tab, typed " "', ' ');
    await js('pressTab()');
    console.log('line now:', JSON.stringify(await js('cm.getLine(6)')));
    // A block suggestion
    await js(`cm.setValue('#c++\\npin button = 2 input\\n'); cm.setCursor({line: 2, ch: 0}); true`);
    await step('typed "when "', 'when ');
    await js('pressTab()');
    await step('after Tab, typed " "', ' ');
    await js('pressTab()');
    console.log('result:\n' + await js('cm.getValue()'));
    console.log('cursor:', JSON.stringify(await js('cm.getCursor()')));
    // Plain Tab still indents when there is no suggestion
    await js(`cm.setValue('x'); cm.setCursor({line: 0, ch: 0}); pressTab(); true`);
    console.log('plain tab:', JSON.stringify(await js('cm.getValue()')));
    app.exit(0);
  });
});
require('../main.js');
