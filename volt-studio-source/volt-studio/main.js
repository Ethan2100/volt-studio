// =====================================================================
//  Volt Studio - main process
//  Handles windows, files, compiling, uploading and the serial port.
//  The page itself (editor, buttons) lives in renderer/.
// =====================================================================

const { app, BrowserWindow, ipcMain, dialog, shell, Menu } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn, spawnSync } = require('child_process');
const volt = require('./compiler/volt.js');
const { MicroPythonUploader } = require('./lib/micropython.js');

let SerialPort = null;
try { ({ SerialPort } = require('serialport')); } catch (e) { console.error('serialport not available:', e.message); }

let win = null;
let dirty = false;           // does the editor have unsaved changes?
let monitor = null;          // open serial monitor port
let monitorInfo = null;      // { port, baud }
let busy = false;            // an upload is running

// ---------------------------------------------------------------------
//  Settings (saved in the app's data folder)
// ---------------------------------------------------------------------
const settingsFile = path.join(app.getPath('userData'), 'settings.json');
let settings = { arduinoCli: '', board: 'arduino:avr:uno', port: '', lastFile: '', fontSize: 15, baud: 9600 };
try { Object.assign(settings, JSON.parse(fs.readFileSync(settingsFile, 'utf8'))); } catch { /* first run */ }
function saveSettings() {
  try {
    fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
    fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
  } catch (e) { console.error('Could not save settings', e); }
}

const send = (channel, data) => { if (win && !win.isDestroyed()) win.webContents.send(channel, data); };
const log = (text, kind = 'info') => send('console', { text, kind });

// ---------------------------------------------------------------------
//  Window and menu
// ---------------------------------------------------------------------
function createWindow() {
  win = new BrowserWindow({
    width: 1340,
    height: 860,
    minWidth: 900,
    minHeight: 560,
    backgroundColor: '#14161c',
    title: 'Volt Studio',
    icon: path.join(__dirname, 'build', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  // Links in the reference docs open in the normal browser
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (url !== win.webContents.getURL()) {
      e.preventDefault();
      if (/^https?:/.test(url)) shell.openExternal(url);
    }
  });

  // Ask before closing with unsaved changes
  win.on('close', (e) => {
    if (!dirty) return;
    const choice = dialog.showMessageBoxSync(win, {
      type: 'question',
      buttons: ['Close without saving', 'Cancel'],
      defaultId: 1,
      cancelId: 1,
      title: 'Unsaved changes',
      message: 'Your Volt file has unsaved changes. Close anyway?',
    });
    if (choice === 1) e.preventDefault();
  });

  buildMenu();
}

function buildMenu() {
  const cmd = (name) => () => send('menu', name);
  const template = [
    {
      label: 'File',
      submenu: [
        { label: 'New', accelerator: 'CmdOrCtrl+N', click: cmd('new') },
        { label: 'Open…', accelerator: 'CmdOrCtrl+O', click: cmd('open') },
        { label: 'Save', accelerator: 'CmdOrCtrl+S', click: cmd('save') },
        { label: 'Save As…', accelerator: 'CmdOrCtrl+Shift+S', click: cmd('saveAs') },
        { type: 'separator' },
        { label: 'Open Output Folder', click: cmd('openOutput') },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' }, { role: 'redo' }, { type: 'separator' },
        { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' },
        { type: 'separator' },
        { label: 'Find', accelerator: 'CmdOrCtrl+F', click: cmd('find') },
        { label: 'Toggle Comment', accelerator: 'CmdOrCtrl+/', click: cmd('comment') },
      ],
    },
    {
      label: 'Sketch',
      submenu: [
        { label: 'Compile', accelerator: 'CmdOrCtrl+R', click: cmd('compile') },
        { label: 'Upload / Run / Preview', accelerator: 'CmdOrCtrl+U', click: cmd('upload') },
        { label: 'Run', accelerator: 'F5', click: cmd('upload') },
        { label: 'Stop', accelerator: 'Shift+F5', click: cmd('stop') },
        { label: 'Open Page in Browser', click: cmd('openInBrowser') },
        { type: 'separator' },
        {
          label: 'Language',
          submenu: [
            { label: 'Arduino C++', click: cmd('target:cpp') },
            { label: 'MicroPython (ESP32 / Pico)', click: cmd('target:micropython') },
            { type: 'separator' },
            { label: 'Python', click: cmd('target:python') },
            { label: 'Ruby', click: cmd('target:ruby') },
            { label: 'JavaScript', click: cmd('target:js') },
            { label: 'HTML page', click: cmd('target:html') },
          ],
        },
      ],
    },
    {
      label: 'Tools',
      submenu: [
        { label: 'Serial Monitor', accelerator: 'CmdOrCtrl+Shift+M', click: cmd('monitor') },
        { label: 'Refresh Ports', click: cmd('refreshPorts') },
        { type: 'separator' },
        { label: 'Install Board Support for Selected Board', click: cmd('installCore') },
        { label: 'Install Servo Library', click: cmd('installServo') },
        { label: 'Upload Setup Check…', click: cmd('toolsCheck') },
        { label: 'Choose arduino-cli Location…', click: cmd('chooseCli') },
      ],
    },
    {
      label: 'View',
      submenu: [
        { label: 'Bigger Text', accelerator: 'CmdOrCtrl+=', click: cmd('zoomIn') },
        { label: 'Smaller Text', accelerator: 'CmdOrCtrl+-', click: cmd('zoomOut') },
        { type: 'separator' },
        { role: 'reload' },
        { role: 'toggleDevTools' },
        { role: 'togglefullscreen' },
      ],
    },
    {
      label: 'Help',
      submenu: [
        { label: 'Volt Reference', accelerator: 'F1', click: cmd('reference') },
        { label: 'About Volt Studio', click: cmd('about') },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// Opening a .volt file by double-clicking it passes the path on the command line
const voltFileFromArgs = (argv) => argv.slice(1).find((a) => /\.volt$/i.test(a) && fs.existsSync(a)) || null;
let startupFile = voltFileFromArgs(process.argv);

// Only one Volt Studio window; double-clicking another file sends it to the open one
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', (e, argv) => {
    const file = voltFileFromArgs(argv);
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
      if (file) send('open-path', file);
    }
  });
  app.whenReady().then(createWindow);
}
app.on('window-all-closed', () => {
  closeMonitor();
  app.quit();
});

// ---------------------------------------------------------------------
//  Files
// ---------------------------------------------------------------------
const VOLT_FILTER = [{ name: 'Volt programs', extensions: ['volt'] }, { name: 'All files', extensions: ['*'] }];

function readVolt(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  settings.lastFile = filePath;
  saveSettings();
  return { path: filePath, content };
}

ipcMain.handle('file:open', async () => {
  const r = await dialog.showOpenDialog(win, { properties: ['openFile'], filters: VOLT_FILTER });
  if (r.canceled || !r.filePaths[0]) return null;
  return readVolt(r.filePaths[0]);
});

ipcMain.handle('file:openPath', (e, filePath) => {
  if (!filePath || !fs.existsSync(filePath)) return null;
  return readVolt(filePath);
});

ipcMain.handle('file:lastFile', () => {
  if (startupFile) { const f = startupFile; startupFile = null; return readVolt(f); }
  if (settings.lastFile && fs.existsSync(settings.lastFile)) return readVolt(settings.lastFile);
  return null;
});

ipcMain.handle('file:save', async (e, { filePath, content, saveAs, suggestedName }) => {
  let target = filePath;
  if (!target || saveAs) {
    const r = await dialog.showSaveDialog(win, {
      defaultPath: target || path.join(app.getPath('documents'), suggestedName || 'my_program.volt'),
      filters: VOLT_FILTER,
    });
    if (r.canceled || !r.filePath) return null;
    target = r.filePath;
    // Make sure it ends in .volt (no more myled.volt.txt!)
    if (!target.toLowerCase().endsWith('.volt')) target += '.volt';
  }
  fs.writeFileSync(target, content, 'utf8');
  settings.lastFile = target;
  saveSettings();
  return { path: target };
});

ipcMain.on('app:dirty', (e, value) => { dirty = !!value; });

ipcMain.handle('app:info', () => ({
  version: app.getVersion(),
  voltVersion: volt.VERSION,
  platform: process.platform,
  settings,
}));

ipcMain.handle('settings:set', (e, patch) => {
  Object.assign(settings, patch);
  saveSettings();
  return settings;
});

ipcMain.handle('examples:list', () => {
  const dir = path.join(__dirname, 'examples');
  return fs.readdirSync(dir)
    .filter((f) => f.endsWith('.volt'))
    .sort()
    .map((f) => {
      const content = fs.readFileSync(path.join(dir, f), 'utf8');
      const firstComment = (content.match(/^\s*\/\/\s*(.+)$/m) || [])[1] || '';
      return { name: f.replace(/\.volt$/, ''), description: firstComment, content };
    });
});

ipcMain.handle('docs:reference', () => fs.readFileSync(path.join(__dirname, 'docs', 'REFERENCE.md'), 'utf8'));

ipcMain.handle('shell:openExternal', (e, url) => { if (/^https?:/.test(url)) shell.openExternal(url); });

ipcMain.handle('shell:openOutput', (e, filePath) => {
  if (!filePath) return false;
  const { outDir } = volt.outputPath(filePath, 'cpp');
  shell.openPath(fs.existsSync(outDir) ? outDir : path.dirname(filePath));
  return true;
});

// ---------------------------------------------------------------------
//  Compiling
// ---------------------------------------------------------------------
function compileSource(source) {
  try {
    const { target, code } = volt.compile(source);
    return { ok: true, target, code };
  } catch (e) {
    if (e instanceof volt.VoltError) return { ok: false, line: e.line, message: e.message };
    return { ok: false, line: 0, message: `Compiler problem: ${e.message}` };
  }
}

// Live compile while typing (nothing is written to disk)
ipcMain.handle('volt:compile', (e, source) => compileSource(source));

// Compile and save the output next to the .volt file
ipcMain.handle('volt:build', (e, { filePath, source }) => {
  const r = compileSource(source);
  if (!r.ok || !filePath) return r;
  const { outDir, outFile } = volt.outputPath(filePath, r.target);
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outFile, r.code);
  return { ...r, outFile };
});

// ---------------------------------------------------------------------
//  Finding the upload tools
// ---------------------------------------------------------------------
function exists(p) { try { return !!p && fs.statSync(p).isFile(); } catch { return false; } }

function findOnPath(name) {
  const r = spawnSync(process.platform === 'win32' ? 'where' : 'which', [name], { encoding: 'utf8' });
  if (r.status === 0) return r.stdout.split(/\r?\n/).find((l) => l.trim()) || null;
  return null;
}

// arduino-cli: settings -> PATH -> the copy bundled inside Arduino IDE 2
function findArduinoCli() {
  if (exists(settings.arduinoCli)) return settings.arduinoCli;
  const onPath = findOnPath('arduino-cli');
  if (onPath) return onPath.trim();
  const exe = process.platform === 'win32' ? 'arduino-cli.exe' : 'arduino-cli';
  const inside = path.join('resources', 'app', 'lib', 'backend', 'resources', exe);
  const candidates = [];
  if (process.platform === 'win32') {
    const local = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
    candidates.push(
      path.join(local, 'Programs', 'Arduino IDE', inside),
      path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Arduino IDE', inside),
      path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Arduino IDE', inside),
    );
  } else if (process.platform === 'darwin') {
    candidates.push(path.join('/Applications', 'Arduino IDE.app', 'Contents', 'Resources', 'app', 'lib', 'backend', 'resources', exe));
  } else {
    candidates.push(path.join(os.homedir(), 'arduino-ide', inside), path.join('/opt', 'arduino-ide', inside));
  }
  return candidates.find(exists) || null;
}

// The Arduino IDE keeps its own arduino-cli settings (board URLs, folders); share them
function arduinoCliArgs() {
  const ideConfig = path.join(os.homedir(), '.arduinoIDE', 'arduino-cli.yaml');
  return exists(ideConfig) ? ['--config-file', ideConfig] : [];
}

ipcMain.handle('tools:status', () => {
  const cli = findArduinoCli();
  let cliVersion = null;
  if (cli) {
    const r = spawnSync(cli, ['version'], { encoding: 'utf8', timeout: 8000 });
    cliVersion = (r.stdout || '').trim().split('\n')[0] || null;
  }
  return { arduinoCli: cli, cliVersion, serialport: !!SerialPort };
});

ipcMain.handle('tools:chooseCli', async () => {
  const r = await dialog.showOpenDialog(win, {
    title: 'Find arduino-cli',
    properties: ['openFile'],
    filters: process.platform === 'win32' ? [{ name: 'arduino-cli', extensions: ['exe'] }] : [],
  });
  if (r.canceled || !r.filePaths[0]) return null;
  settings.arduinoCli = r.filePaths[0];
  saveSettings();
  return settings.arduinoCli;
});

// ---------------------------------------------------------------------
//  Ports
// ---------------------------------------------------------------------
// USB IDs -> friendly names, so "COM5" can say what is plugged in
const USB_NAMES = {
  '2341:0043': ['Arduino Uno', 'arduino:avr:uno'], '2341:0001': ['Arduino Uno', 'arduino:avr:uno'],
  '2a03:0043': ['Arduino Uno', 'arduino:avr:uno'], '2341:0243': ['Arduino Uno', 'arduino:avr:uno'],
  '2341:0010': ['Arduino Mega', 'arduino:avr:mega'], '2341:0042': ['Arduino Mega', 'arduino:avr:mega'],
  '2341:8036': ['Arduino Leonardo', 'arduino:avr:leonardo'], '2341:0036': ['Arduino Leonardo', 'arduino:avr:leonardo'],
  '1a86:7523': ['CH340 USB chip (Uno/Nano clone)', null],
  '1a86:55d4': ['CH9102 USB chip (often ESP32)', null],
  '10c4:ea60': ['CP210x USB chip (often ESP32)', null],
  '0403:6001': ['FTDI USB chip', null],
  '2e8a:0005': ['Raspberry Pi Pico (MicroPython)', null],
  '2e8a:000a': ['Raspberry Pi Pico', 'rp2040:rp2040:rpipico'],
  '303a:1001': ['ESP32-S3/C3 (USB)', null],
};

ipcMain.handle('ports:list', async () => {
  if (!SerialPort) return { ports: [], error: 'Serial support is missing from this build.' };
  try {
    const list = await SerialPort.list();
    const ports = list
      .filter((p) => p.vendorId || /COM\d+|ttyUSB|ttyACM|cu\.usb/i.test(p.path))
      .map((p) => {
        const id = `${(p.vendorId || '').toLowerCase()}:${(p.productId || '').toLowerCase()}`;
        const [name, fqbn] = USB_NAMES[id] || [p.manufacturer || 'Serial device', null];
        return { path: p.path, label: `${p.path} – ${name}`, fqbn };
      });
    return { ports };
  } catch (e) {
    return { ports: [], error: e.message };
  }
});

// ---------------------------------------------------------------------
//  Serial monitor
// ---------------------------------------------------------------------
function closeMonitor() {
  return new Promise((resolve) => {
    if (!monitor) return resolve();
    const m = monitor;
    monitor = null;
    m.removeAllListeners('close');
    if (m.isOpen) m.close(() => resolve());
    else resolve();
    send('monitor:state', { open: false });
  });
}

function openMonitor(portPath, baud) {
  return new Promise((resolve) => {
    if (!SerialPort) return resolve({ ok: false, message: 'Serial support is missing from this build.' });
    const { StringDecoder } = require('string_decoder');
    const decoder = new StringDecoder('utf8');
    const port = new SerialPort({ path: portPath, baudRate: Number(baud), autoOpen: false });
    port.open((err) => {
      if (err) {
        const busyHint = /access denied|busy|resource busy|permission/i.test(err.message)
          ? ' The port is being used by another program (is the Arduino IDE Serial Monitor open?).' : '';
        return resolve({ ok: false, message: `Couldn't open ${portPath}: ${err.message}.${busyHint}` });
      }
      monitor = port;
      monitorInfo = { port: portPath, baud: Number(baud) };
      port.on('data', (d) => send('monitor:data', decoder.write(d)));
      port.on('close', () => { monitor = null; send('monitor:state', { open: false, message: 'Disconnected (board unplugged?)' }); });
      port.on('error', (e) => send('monitor:data', `\n[serial error: ${e.message}]\n`));
      send('monitor:state', { open: true, port: portPath, baud: Number(baud) });
      resolve({ ok: true });
    });
  });
}

ipcMain.handle('monitor:open', async (e, { port, baud }) => {
  await closeMonitor();
  return openMonitor(port, baud);
});
ipcMain.handle('monitor:close', async () => { await closeMonitor(); monitorInfo = null; return true; });
ipcMain.handle('monitor:send', (e, text) => {
  if (!monitor || !monitor.isOpen) return false;
  monitor.write(text);
  return true;
});

// ---------------------------------------------------------------------
//  Uploading
// ---------------------------------------------------------------------
function run(command, args, { cwd } = {}) {
  return new Promise((resolve) => {
    log(`> ${path.basename(command)} ${args.join(' ')}\n`, 'cmd');
    let output = '';
    let child;
    try {
      child = spawn(command, args, { cwd, windowsHide: true });
    } catch (e) {
      log(`${e.message}\n`, 'error');
      return resolve({ code: -1, output: e.message });
    }
    const onData = (kind) => (d) => { const t = d.toString(); output += t; log(t, kind); };
    child.stdout.on('data', onData('info'));
    child.stderr.on('data', onData('warn'));
    child.on('error', (e) => { output += e.message; log(`${e.message}\n`, 'error'); });
    child.on('close', (code) => resolve({ code, output }));
  });
}

// Folder names for arduino-cli must be simple: letters, numbers, _ - .
const safeName = (name) => (name.replace(/[^A-Za-z0-9_.-]/g, '_').replace(/^[^A-Za-z0-9]+/, '') || 'sketch');

function buildDir(filePath, target) {
  const base = safeName(filePath ? path.basename(filePath, path.extname(filePath)) : 'untitled');
  const dir = path.join(app.getPath('userData'), 'build', target, base);
  fs.mkdirSync(dir, { recursive: true });
  return { dir, base };
}

// Explain common upload errors in plain words
function explainFailure(output) {
  const hints = [];
  if (/platform not installed|Platform '.+' not found|Error resolving FQBN|unknown package/i.test(output)) {
    hints.push('Board support for this board is not installed. Use Tools → Install Board Support for Selected Board.');
  }
  if (/Servo\.h: No such file/i.test(output)) hints.push('The Servo library is missing. Use Tools → Install Servo Library.');
  else if (/\.h: No such file/i.test(output)) hints.push('A library in an #include line is missing. Install it from the Arduino IDE Library Manager.');
  if (/not in sync|programmer is not responding/i.test(output)) {
    hints.push('The board did not answer. Check the port, and the board type (for a cheap Nano, try "Arduino Nano (old bootloader)").');
  }
  if (/access is denied|resource busy|permission denied|can't open device/i.test(output)) {
    hints.push('The port is busy. Close the Arduino IDE Serial Monitor or any other program using the board.');
  }
  if (/Failed to connect to ESP32|Wrong boot mode/i.test(output)) {
    hints.push('ESP32 not responding: hold the BOOT button on the board while uploading starts.');
  }
  return hints;
}

const BOARD_URLS = {
  esp32: 'https://espressif.github.io/arduino-esp32/package_esp32_index.json',
  esp8266: 'https://arduino.esp8266.com/stable/package_esp8266com_index.json',
  rp2040: 'https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json',
};

async function uploadCpp({ filePath, code, port, fqbn }) {
  const cli = findArduinoCli();
  if (!cli) {
    log('Uploading C++ needs arduino-cli, which comes with the Arduino IDE 2.\n' +
        'Install the Arduino IDE (arduino.cc/en/software), or use Tools → Choose arduino-cli Location.\n', 'error');
    return { ok: false, needsCli: true };
  }
  const { dir, base } = buildDir(filePath, 'cpp');
  fs.writeFileSync(path.join(dir, `${base}.ino`), code);
  log(`Compiling and uploading for ${fqbn} on ${port}…\n`, 'step');
  const r = await run(cli, [...arduinoCliArgs(), 'compile', '--upload', '-b', fqbn, '-p', port, dir]);
  if (r.code === 0) return { ok: true };
  explainFailure(r.output).forEach((h) => log(`💡 ${h}\n`, 'hint'));
  return { ok: false };
}

async function uploadPython({ code, port }) {
  if (!SerialPort) {
    log('Serial support is missing from this build.\n', 'error');
    return { ok: false };
  }
  log(`Sending main.py to the board on ${port}…\n`, 'step');
  const uploader = new MicroPythonUploader(SerialPort, port, (t) => log(t, 'info'));
  try {
    await uploader.upload('main.py', code);
    log('Board restarted and is running main.py.\n', 'info');
    return { ok: true };
  } catch (e) {
    log(`${e.message}\n`, 'error');
    log('💡 Make sure MicroPython is installed on the board (Thonny can install it: Tools → Options → Interpreter),\n' +
        '   and that no other program (Thonny, Arduino IDE) has the port open.\n', 'hint');
    return { ok: false };
  }
}

ipcMain.handle('volt:upload', async (e, { filePath, source, port, fqbn }) => {
  if (busy) return { ok: false, message: 'An upload is already running.' };
  const compiled = compileSource(source);
  if (!compiled.ok) return compiled;
  if (!volt.TARGETS[compiled.target].board) return { ok: false, message: 'This program is a script, not a board program. Use Run instead.' };
  if (!port) return { ok: false, message: 'Pick a port first (plug in your board and press the refresh button).' };

  // Also save the compiled file next to the .volt file, like the Compile button does
  if (filePath) {
    const { outDir, outFile } = volt.outputPath(filePath, compiled.target);
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(outFile, compiled.code);
  }

  busy = true;
  send('upload:state', { running: true });
  // The board's port can only be used by one thing at a time
  const reopen = monitor && monitorInfo && monitorInfo.port === port ? { ...monitorInfo } : null;
  if (reopen) { await closeMonitor(); log('(Serial monitor paused for upload)\n', 'info'); }

  let result;
  try {
    result = compiled.target === 'micropython'
      ? await uploadPython({ code: compiled.code, port })
      : await uploadCpp({ filePath, code: compiled.code, port, fqbn });
  } finally {
    busy = false;
    send('upload:state', { running: false });
  }

  if (reopen) {
    await new Promise((r) => setTimeout(r, 1500));   // give the board time to restart
    await openMonitor(reopen.port, reopen.baud);
  }
  return { ...result, target: compiled.target };
});

// Install board support / libraries with arduino-cli
ipcMain.handle('tools:installCore', async (e, fqbn) => {
  const cli = findArduinoCli();
  if (!cli) { log('arduino-cli not found (install the Arduino IDE 2).\n', 'error'); return { ok: false }; }
  const [vendor, arch] = (fqbn || '').split(':');
  if (!vendor || !arch) return { ok: false };
  const url = BOARD_URLS[arch] || BOARD_URLS[vendor];
  const extra = url ? ['--additional-urls', url] : [];
  log(`Installing board support for ${vendor}:${arch} (this can take a few minutes)…\n`, 'step');
  let r = await run(cli, [...arduinoCliArgs(), 'core', 'update-index', ...extra]);
  if (r.code === 0) r = await run(cli, [...arduinoCliArgs(), 'core', 'install', `${vendor}:${arch}`, ...extra]);
  log(r.code === 0 ? 'Board support installed.\n' : 'Installing board support failed.\n', r.code === 0 ? 'step' : 'error');
  return { ok: r.code === 0 };
});

ipcMain.handle('tools:installLib', async (e, name) => {
  const cli = findArduinoCli();
  if (!cli) { log('arduino-cli not found (install the Arduino IDE 2).\n', 'error'); return { ok: false }; }
  log(`Installing the ${name} library…\n`, 'step');
  let r = await run(cli, [...arduinoCliArgs(), 'lib', 'update-index']);
  if (r.code === 0) r = await run(cli, [...arduinoCliArgs(), 'lib', 'install', name]);
  log(r.code === 0 ? `${name} library installed.\n` : `Installing ${name} failed.\n`, r.code === 0 ? 'step' : 'error');
  return { ok: r.code === 0 };
});

// ---------------------------------------------------------------------
//  Running scripts (#python, #ruby, #js) and previewing pages (#html)
// ---------------------------------------------------------------------
let runChild = null;          // the running script process
let previewWin = null;        // the HTML preview window
let lastPagePath = null;      // last built page, for "Open in browser"
const interpreterCache = {};

// Checks a command really is the language (Windows has a fake "python" that opens the Store)
function tryInterpreter(command, args, pattern) {
  try {
    const r = spawnSync(command, [...args, '--version'], { encoding: 'utf8', timeout: 8000, windowsHide: true });
    const out = `${r.stdout || ''}${r.stderr || ''}`;
    if (r.status === 0 && pattern.test(out)) return { command, args, version: out.trim().split(/\r?\n/)[0] };
  } catch { /* not installed */ }
  return null;
}

function findInterpreter(lang) {
  if (interpreterCache[lang]) return interpreterCache[lang];
  let found = null;
  if (lang === 'python') {
    const tries = process.platform === 'win32'
      ? [['py', ['-3']], ['python', []], ['python3', []]]
      : [['python3', []], ['python', []]];
    for (const [c, a] of tries) { found = tryInterpreter(c, a, /Python 3\./); if (found) break; }
  } else if (lang === 'ruby') {
    found = tryInterpreter('ruby', [], /ruby \d/);
    if (!found && process.platform === 'win32') {
      // RubyInstaller puts Ruby in C:\Ruby33-x64\bin and similar
      try {
        const dirs = fs.readdirSync('C:\\').filter((d) => /^Ruby\d+/i.test(d)).sort().reverse();
        for (const d of dirs) {
          found = tryInterpreter(path.join('C:\\', d, 'bin', 'ruby.exe'), [], /ruby \d/);
          if (found) break;
        }
      } catch { /* no C: drive listing */ }
    }
  } else if (lang === 'js') {
    // Volt Studio can run JavaScript itself (Electron includes Node.js)
    found = { command: process.execPath, args: [], env: { ELECTRON_RUN_AS_NODE: '1' }, version: `Node.js ${process.versions.node} (built in)` };
  }
  if (found) interpreterCache[lang] = found;
  return found;
}

const INSTALL_HELP = {
  python: 'Python isn\'t installed. Get it from https://www.python.org/downloads/ and tick "Add python.exe to PATH" in the installer. Then press Run again.',
  ruby: 'Ruby isn\'t installed. Get it from https://rubyinstaller.org/ (pick the version marked "recommended"). Then press Run again.',
};

// Writes the compiled code next to the .volt file (if saved) and into the build folder
function writeOutput(filePath, target, code) {
  if (filePath) {
    const { outDir, outFile } = volt.outputPath(filePath, target);
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(outFile, code);
    return outFile;
  }
  const { dir, base } = buildDir(null, target);
  const outFile = path.join(dir, volt.TARGETS[target].file(base));
  fs.writeFileSync(outFile, code);
  return outFile;
}

function openPreview(file) {
  lastPagePath = file;
  if (previewWin && !previewWin.isDestroyed()) {
    previewWin.loadFile(file);
    if (previewWin.isMinimized()) previewWin.restore();
    previewWin.show();
    return;
  }
  const b = win ? win.getBounds() : { x: 80, y: 80, width: 1200 };
  previewWin = new BrowserWindow({
    width: 860,
    height: 720,
    x: Math.max(0, b.x + b.width - 880),
    y: b.y + 40,
    title: 'Preview',
    backgroundColor: '#ffffff',
    autoHideMenuBar: true,
    icon: path.join(__dirname, 'build', 'icon.png'),
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true },
  });
  previewWin.loadFile(file);
  previewWin.on('page-title-updated', (e, title) => { e.preventDefault(); previewWin.setTitle(`Preview – ${title}`); });
  // Show page errors and console.log in the Volt console
  previewWin.webContents.on('console-message', (e) => {
    const level = e.level !== undefined ? e.level : 0;
    const message = e.message !== undefined ? e.message : '';
    const isError = level === 'error' || level === 3;
    log(`[page] ${message}\n`, isError ? 'error' : 'info');
  });
  // Links in the page open in the normal browser
  previewWin.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  previewWin.on('closed', () => { previewWin = null; });
}

ipcMain.handle('volt:run', async (e, { filePath, source }) => {
  const compiled = compileSource(source);
  if (!compiled.ok) return compiled;
  const { target, code } = compiled;
  if (volt.TARGETS[target].board) return { ok: false, message: 'This is a board program. Use Upload instead.' };

  const outFile = writeOutput(filePath, target, code);

  if (target === 'html') {
    openPreview(outFile);
    log(`Showing ${path.basename(outFile)} in the preview window.\n`, 'step');
    return { ok: true, target, outFile, preview: true };
  }

  if (runChild) return { ok: false, message: 'A program is already running. Press Stop first.' };
  const lang = target === 'python' ? 'python' : target;
  const interp = findInterpreter(lang);
  if (!interp) {
    log(`${INSTALL_HELP[lang]}\n`, 'error');
    return { ok: false, target, missing: lang };
  }

  log(`Running ${path.basename(outFile)} with ${interp.version}…\n`, 'step');
  const env = { ...process.env, PYTHONUNBUFFERED: '1', PYTHONIOENCODING: 'utf-8', ...(interp.env || {}) };
  if (!interp.env) delete env.ELECTRON_RUN_AS_NODE;
  try {
    runChild = spawn(interp.command, [...interp.args, outFile], { cwd: path.dirname(outFile), env, windowsHide: true });
  } catch (err) {
    runChild = null;
    log(`Couldn't start the program: ${err.message}\n`, 'error');
    return { ok: false, target };
  }
  const started = Date.now();
  send('run:state', { running: true, target });
  runChild.stdout.on('data', (d) => log(d.toString(), 'out'));
  runChild.stderr.on('data', (d) => log(d.toString(), 'error'));
  runChild.on('error', (err) => log(`${err.message}\n`, 'error'));
  runChild.on('close', (code, signal) => {
    runChild = null;
    const secs = ((Date.now() - started) / 1000).toFixed(1);
    if (signal) log(`■ Stopped after ${secs}s\n`, 'step');
    else log(code === 0 ? `✓ Finished in ${secs}s\n` : `✗ The program ended with an error (exit code ${code})\n`, code === 0 ? 'ok' : 'error');
    send('run:state', { running: false, code });
  });
  return { ok: true, target, outFile };
});

ipcMain.handle('volt:stop', () => {
  if (!runChild) return false;
  runChild.kill();
  return true;
});

// Text typed into the console goes to the running program (for 'ask')
ipcMain.handle('volt:stdin', (e, text) => {
  if (!runChild || !runChild.stdin.writable) return false;
  runChild.stdin.write(text);
  return true;
});

ipcMain.handle('volt:openInBrowser', () => {
  if (lastPagePath && fs.existsSync(lastPagePath)) { shell.openPath(lastPagePath); return true; }
  return false;
});

ipcMain.handle('tools:interpreters', () => ({
  python: findInterpreter('python'),
  ruby: findInterpreter('ruby'),
  js: findInterpreter('js'),
}));

app.on('before-quit', () => { if (runChild) runChild.kill(); });
