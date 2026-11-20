// Exercise the Asset Browser and its real project IPC from Volt's Electron renderer.
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

const outDir = process.argv[process.argv.length - 1];
if (!outDir || !path.isAbsolute(outDir)) throw new Error('Pass an absolute temporary output folder.');
app.setPath('userData', path.join(outDir, 'ud'));
const project = path.join(outDir, 'asset-project');
fs.mkdirSync(path.join(project, 'Assets'), { recursive: true });
fs.writeFileSync(path.join(project, 'main.volt'), '#html\ncanvas 320, 180\n');
fs.writeFileSync(path.join(project, 'Assets', 'icon.png'), Buffer.from([137, 80, 78, 71]));
fs.writeFileSync(path.join(project, 'Assets', 'bell.wav'), Buffer.from([82, 73, 70, 70]));
fs.writeFileSync(path.join(project, 'Assets', 'mesh.obj'), 'v 0 0 0');

let failed = 0;
function check(label, condition, detail = '') {
  console.log(`${condition ? 'pass' : 'FAIL'}  ${label}${condition ? '' : `: ${detail}`}`);
  if (!condition) failed++;
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

app.on('browser-window-created', (event, win) => {
  if (BrowserWindow.getAllWindows().length > 1) return;
  win.webContents.once('did-finish-load', async () => {
    try {
      await wait(700);
      const file = path.join(project, 'main.volt');
      const result = await win.webContents.executeJavaScript(`(async () => {
        const opened = await window.volt.openPath(${JSON.stringify(file)});
        if (!opened) throw new Error('The test project file did not open');
        loadDocument(opened.content, opened.path, { projectRoot: opened.projectRoot });
        await loadAssetBrowser();
        showTab('side', 'assets');
        await new Promise(resolve => setTimeout(resolve, 150));
        return {
          enabled: !document.getElementById('btn-assets-import').disabled,
          count: document.querySelectorAll('#asset-browser [data-asset-file]').length,
          files: await window.volt.projectAssets(opened.projectRoot),
          root: opened.projectRoot
        };
      })()`);
      check('the project Asset Browser enables import actions', result.enabled);
      check('the UI lists supported and unsupported project assets', result.count === 3 && result.files.some((x) => x.category === 'Unsupported'));
      check('asset metadata comes through the approved project IPC', result.files.some((x) => x.file === 'Assets/bell.wav' && x.supported));

      const preview = await win.webContents.executeJavaScript(`(async () => {
        await selectProjectAsset('Assets/icon.png');
        const image = document.querySelector('#asset-preview img');
        const imageOk = !!image && image.src.startsWith('data:image/png;base64,');
        await selectProjectAsset('Assets/bell.wav');
        const audio = document.querySelector('#asset-preview audio');
        const audioOk = !!audio && audio.src.startsWith('data:audio/wav;base64,');
        await selectProjectAsset('Assets/mesh.obj');
        const reason = document.querySelector('#asset-preview .asset-reason')?.textContent || '';
        editor.setValue('#html\\ncanvas 320, 180\\n'); editor.setCursor({ line: 2, ch: 0 });
        insertAssetDeclaration(assetState.items.find((asset) => asset.file === 'Assets/bell.wav'));
        return { imageOk, audioOk, reason, source: editor.getValue() };
      })()`);
      check('image assets render an in-editor thumbnail', preview.imageOk);
      check('audio assets render an in-editor player', preview.audioOk);
      check('unsupported formats show conversion guidance', /OBJ import is not available/.test(preview.reason));
      check('the browser inserts a valid audio declaration', preview.source.includes('audio asset_bell = "Assets/bell.wav"'));
    } catch (error) {
      failed++;
      console.error('FAIL  Asset Browser integration:', error.stack || error);
    } finally {
      console.log(`Asset Browser checks: ${failed ? `${failed} failed` : 'all passed'}`);
      app.exit(failed ? 1 : 0);
    }
  });
});

require('../main.js');
