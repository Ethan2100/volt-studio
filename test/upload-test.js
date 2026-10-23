// Test helper: runs uploads through the real app with a fake arduino-cli and a fake MicroPython board
const { app } = require('electron');
const fs = require('fs');
const path = require('path');
const [outDir, fakeCli, ptyPath] = process.argv.slice(-3);
app.setPath('userData', path.join(outDir, 'userdata'));
fs.mkdirSync(app.getPath('userData'), { recursive: true });
fs.writeFileSync(path.join(app.getPath('userData'), 'settings.json'), JSON.stringify({ arduinoCli: fakeCli }));
app.on('browser-window-created', (e, win) => {
  win.webContents.once('did-finish-load', async () => {
    const js = (c) => win.webContents.executeJavaScript(c);
    await new Promise((r) => setTimeout(r, 1200));
    const runUpload = async (label, src, port, fqbn, file) => {
      await js(`document.getElementById('console').textContent = ''`);
      const res = await js(`window.volt.upload(${JSON.stringify({ filePath: file || null, source: src, port, fqbn })})`);
      await new Promise((r) => setTimeout(r, 300));
      const text = await js(`document.getElementById('console').textContent`);
      console.log(`\n===== ${label}: ${JSON.stringify(res)}\n${text}`);
    };
    const cpp = fs.readFileSync(path.join(__dirname, '..', 'examples', '01_blink.volt'), 'utf8');
    const servo = fs.readFileSync(path.join(__dirname, '..', 'examples', '04_knob_servo.volt'), 'utf8');
    const py = fs.readFileSync(path.join(__dirname, '..', 'examples', '09_micropython_blink.volt'), 'utf8');
    fs.writeFileSync(path.join(outDir, 'my led.volt'), cpp);
    await runUpload('C++ upload (file name with a space)', cpp, 'COM5', 'arduino:avr:uno', path.join(outDir, 'my led.volt'));
    fs.writeFileSync(path.join(outDir, 'servo_test.volt'), servo);
    await runUpload('C++ upload failing (missing Servo)', servo, 'COM5', 'arduino:avr:uno', path.join(outDir, 'servo_test.volt'));
    await runUpload('Compile error', 'pin led = 13\nset led to', 'COM5', 'arduino:avr:uno');
    await runUpload('No port', cpp, '', 'arduino:avr:uno');
    await runUpload('Python upload to fake board', py, ptyPath, '');
    console.log('\nfiles next to .volt:', fs.readdirSync(path.join(outDir, 'my led')));
    app.exit(0);
  });
});
require('../main.js');
