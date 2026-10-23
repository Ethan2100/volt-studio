// Test helper: starts Volt Studio, clicks through a few states and saves screenshots.
// Run with:  electron test/screenshots.js <output folder>
const { app } = require('electron');
const fs = require('fs');
const path = require('path');

const outDir = process.argv.find((a, i) => i > 1 && !a.startsWith('-') && !a.endsWith('.js')) || path.join(__dirname, 'shots');
fs.mkdirSync(outDir, { recursive: true });
app.setPath('userData', path.join(outDir, 'userdata'));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

app.on('browser-window-created', (e, win) => {
  win.webContents.on('console-message', (ev, level, message, line, source) => {
    console.log(`[page ${level}] ${message} (${source}:${line})`);
  });
  win.webContents.once('did-finish-load', async () => {
    const js = (code) => win.webContents.executeJavaScript(code);
    const shot = async (name) => {
      await sleep(600);
      const img = await win.webContents.capturePage();
      fs.writeFileSync(path.join(outDir, `${name}.png`), img.toPNG());
      console.log('saved', name);
    };
    try {
      await sleep(1500);
      // 1. Load the dice example
      await js(`document.querySelector('[data-tab="examples"]').click()`);
      await shot('1-examples');
      await js(`[...document.querySelectorAll('.example')][4].click()`);
      await sleep(400);
      await js(`document.querySelector('[data-tab="output"]').click()`);
      await js(`document.querySelector('[data-group="bottom"] [data-tab="console"]').click()`);
      await js(`document.getElementById('btn-compile').click()`);
      await shot('2-dice-cpp');

      // 2. Make an error
      await js(`(() => { const cm = document.querySelector('#editor .CodeMirror').CodeMirror; cm.replaceRange('  set button to 5\\n', {line: 26, ch: 0}); })()`);
      await sleep(500);
      await shot('3-error');

      // 3. Switch to Python
      await js(`(() => { const cm = document.querySelector('#editor .CodeMirror').CodeMirror; cm.undo(); })()`);
      await sleep(300);
      await js(`document.querySelector('[data-target="python"]').click()`);
      await sleep(600);
      await shot('4-python');

      // 4. Reference
      await js(`document.querySelector('[data-tab="reference"]').click()`);
      await js(`document.getElementById('pins').scrollIntoView()`);
      await shot('5-reference');

      // 5. Autocomplete
      await js(`(() => { const cm = document.querySelector('#editor .CodeMirror').CodeMirror; cm.focus(); cm.setCursor(cm.lineCount() - 1, 0); cm.replaceSelection('fa'); CodeMirror.commands.autocomplete ? cm.showHint({ hint: CodeMirror.hint.volt, completeSingle: false }) : 0; })()`);
      await shot('6-autocomplete');

      // 6. Upload with no board, and the setup check
      await js(`document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape'}))`);
      await js(`document.querySelector('[data-target="cpp"]').click()`);
      await js(`document.querySelector('[data-group="bottom"] [data-tab="monitor"]').click()`);
      await shot('7-monitor');
      const check = await js(`window.volt.toolsStatus()`);
      console.log('tools status:', JSON.stringify(check));
      const ports = await js(`window.volt.ports()`);
      console.log('ports:', JSON.stringify(ports));
    } catch (err) {
      console.error('TEST ERROR', err);
    }
    app.exit(0);
  });
});

require('../main.js');
