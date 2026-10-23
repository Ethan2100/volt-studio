// =====================================================================
//  Volt Studio - page logic (editor, buttons, panels)
//  Talks to the main process through window.volt (see preload.js)
// =====================================================================
/* global CodeMirror, marked */

const api = window.volt;
const $ = (id) => document.getElementById(id);

const BOARDS = [
  ['arduino:avr:uno', 'Arduino Uno'],
  ['arduino:avr:nano', 'Arduino Nano'],
  ['arduino:avr:nano:cpu=atmega328old', 'Arduino Nano (old bootloader)'],
  ['arduino:avr:mega', 'Arduino Mega 2560'],
  ['arduino:avr:leonardo', 'Arduino Leonardo'],
  ['esp32:esp32:esp32', 'ESP32 Dev Module'],
  ['esp8266:esp8266:nodemcuv2', 'ESP8266 NodeMCU'],
  ['rp2040:rp2040:rpipico', 'Raspberry Pi Pico (Arduino)'],
];

// Every language Volt can make. directive = the first line of the file
const LANGS = {
  cpp: { label: 'Arduino C++', short: 'C++', directive: '#c++', board: true, mode: 'text/x-c++src', group: 'Board', blurb: 'Uno, Nano, Mega, ESP32 with the Arduino IDE' },
  micropython: { label: 'MicroPython', short: 'MicroPython', directive: '#micropython', board: true, mode: 'python', group: 'Board', blurb: 'ESP32 or Raspberry Pi Pico running MicroPython' },
  python: { label: 'Python', short: 'Python', directive: '#python', board: false, mode: 'python', group: 'Script', blurb: 'A Python script that runs on your PC' },
  ruby: { label: 'Ruby', short: 'Ruby', directive: '#ruby', board: false, mode: 'ruby', group: 'Script', blurb: 'A Ruby script that runs on your PC' },
  js: { label: 'JavaScript', short: 'JavaScript', directive: '#js', board: false, mode: 'javascript', group: 'Script', blurb: 'A JavaScript (Node.js) script, no install needed' },
  html: { label: 'HTML page', short: 'HTML', directive: '#html', board: false, mode: 'htmlmixed', group: 'Web', blurb: 'A web page with buttons, text and your own CSS' },
};

const SCRIPT_STARTER = (directive, what) => `${directive}
// My ${what} - press Run (F5)
let name = ask "What's your name?"
print "Hello, " + name + "!"

repeat 3 {
  print "Volt is fun!"
}
`;

const STARTER = {
  cpp: `#c++
// My Volt program - press Upload to send it to your board
pin led = 13

every 500ms {
  toggle led
}
`,
  micropython: `#micropython
// My Volt program for a MicroPython board (ESP32 / Pico)
pin led = 2

every 500ms {
  toggle led
}
`,
  python: SCRIPT_STARTER('#python', 'Python script'),
  ruby: SCRIPT_STARTER('#ruby', 'Ruby script'),
  js: SCRIPT_STARTER('#js', 'JavaScript script'),
  html: `#html
// My web page - press Preview (F5)
## body { background: #10131a; color: #f2f4f8; }

let clicks = 0

title "My Volt Page"
print "Welcome! Click the button."

button "Click me" {
  clicks = clicks + 1
  print "Clicked " + clicks + " times"
}
`,
};

// Reads the language from the first line, without compiling
function directiveTarget(text) {
  const line = text.split('\n').map((l) => l.trim()).find((l) => l && !l.startsWith('//')) || '';
  const m = line.match(/^#(\S+)$/);
  const name = m ? m[1].toLowerCase() : '';
  const map = { 'c++': 'cpp', cpp: 'cpp', arduino: 'cpp', micropython: 'micropython', python: 'python', py: 'python', ruby: 'ruby', rb: 'ruby', js: 'js', javascript: 'js', node: 'js', html: 'html', web: 'html' };
  let t = map[name] || 'cpp';
  if (t === 'python' && /^\s*pin\s/m.test(text)) t = 'micropython';
  return t;
}

const state = {
  filePath: null,
  suggestedName: 'my_program.volt',
  dirty: false,
  target: 'cpp',
  lastResult: null,
  errorMark: null,       // { line, widget }
  monitorOpen: false,
  uploading: false,
  running: false,        // a script is running
  settings: {},
};

// ---------------------------------------------------------------------
//  Editors
// ---------------------------------------------------------------------
const editor = CodeMirror($('editor'), {
  mode: 'volt',
  theme: 'volt',
  lineNumbers: true,
  indentUnit: 2,
  tabSize: 2,
  indentWithTabs: false,
  matchBrackets: true,
  autoCloseBrackets: { pairs: '()[]{}""', explode: '{}' },
  styleActiveLine: true,
  gutters: ['CodeMirror-linenumbers', 'error-gutter'],
  extraKeys: {
    Tab: (cm) => {
      if (ghost.accept()) return;
      if (cm.somethingSelected()) cm.indentSelection('add');
      else cm.replaceSelection('  ');
    },
    'Shift-Tab': (cm) => cm.indentSelection('subtract'),
    'Ctrl-Space': (cm) => cm.showHint({ hint: CodeMirror.hint.volt, completeSingle: false }),
    'Ctrl-/': (cm) => cm.toggleComment(),
    'Cmd-/': (cm) => cm.toggleComment(),
  },
});

// Faded suggestions after the cursor (see ghost.js); Tab accepts
const ghost = window.VoltGhost.attach(editor, () => state.target);

const output = CodeMirror($('output'), {
  mode: 'text/x-c++src',
  theme: 'volt',
  readOnly: true,
  lineNumbers: true,
});

// ---------------------------------------------------------------------
//  Small UI helpers
// ---------------------------------------------------------------------
let toastTimer = null;
function toast(text, isError = false) {
  const t = $('toast');
  t.textContent = text;
  t.classList.toggle('error', isError);
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 3200);
}

function setStatus(text, kind = '') {
  const s = $('status');
  s.textContent = text;
  s.className = `status ${kind}`;
}

function modal(title, html, actions = [{ label: 'OK', primary: true }]) {
  return new Promise((resolve) => {
    $('modal-title').textContent = title;
    $('modal-body').innerHTML = html;
    const bar = $('modal-actions');
    bar.innerHTML = '';
    actions.forEach((a, i) => {
      const b = document.createElement('button');
      b.className = `btn${a.primary ? ' primary' : ''}`;
      b.textContent = a.label;
      b.onclick = () => { $('modal').classList.add('hidden'); resolve(i); };
      bar.appendChild(b);
    });
    $('modal').classList.remove('hidden');
    bar.lastChild.focus();
  });
}

const escapeHtml = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const baseName = (p) => (p ? p.split(/[\\/]/).pop() : 'untitled.volt');

function showTab(group, name) {
  document.querySelectorAll(`.tabs[data-group="${group}"] > button[data-tab]`).forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === name);
  });
  const container = group === 'side' ? $('side-pane') : $('bottom-pane');
  container.querySelectorAll(':scope > .tab-body').forEach((p) => p.classList.toggle('active', p.dataset.panel === name));
  if (name === 'output') output.refresh();
}
document.querySelectorAll('.tabs').forEach((nav) => {
  nav.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (b) showTab(nav.dataset.group, b.dataset.tab);
  });
});

// ---------------------------------------------------------------------
//  File handling
// ---------------------------------------------------------------------
function updateTitle() {
  const name = baseName(state.filePath);
  $('file-name').textContent = name;
  $('file-name').title = state.filePath || 'Not saved yet';
  $('file-name').classList.toggle('dirty', state.dirty);
  document.title = `${name}${state.dirty ? ' ●' : ''} – Volt Studio`;
}

function setDirty(value) {
  if (state.dirty === value) return;
  state.dirty = value;
  api.setDirty(value);
  updateTitle();
}

function loadDocument(content, filePath) {
  state.filePath = filePath || null;
  editor.setValue(content);
  editor.clearHistory();
  editor.setCursor(0, 0);
  setDirty(!filePath && content !== STARTER.cpp && content !== STARTER.python);
  updateTitle();
  compileNow();
  editor.focus();
}

async function confirmDiscard() {
  if (!state.dirty) return true;
  const choice = await modal('Unsaved changes',
    `<p><b>${escapeHtml(baseName(state.filePath))}</b> has changes that aren't saved.</p>`,
    [{ label: 'Cancel' }, { label: "Don't save" }, { label: 'Save', primary: true }]);
  if (choice === 0) return false;
  if (choice === 2) return saveFile();
  return true;
}

async function newFile() {
  if (!(await confirmDiscard())) return;
  const keys = Object.keys(LANGS);
  const cards = keys.map((k, i) => `<button class="new-card" data-i="${i}"><span class="group">${LANGS[k].group}</span><b>${LANGS[k].label}</b><span>${LANGS[k].blurb}</span></button>`).join('');
  const picked = await new Promise((resolve) => {
    modal('New Volt file', `<p>What do you want to make?</p><div class="new-grid">${cards}</div>`, [{ label: 'Cancel' }]).then(() => resolve(null));
    document.querySelectorAll('.new-card').forEach((c) => {
      c.onclick = () => { $('modal').classList.add('hidden'); resolve(keys[Number(c.dataset.i)]); };
    });
    const current = document.querySelector(`.new-card[data-i="${keys.indexOf(state.target)}"]`);
    if (current) current.focus();
  });
  if (!picked) return;
  loadDocument(STARTER[picked], null);
  state.suggestedName = 'my_program.volt';
  setDirty(false);
}

async function openFile() {
  if (!(await confirmDiscard())) return;
  const r = await api.open();
  if (r) { loadDocument(r.content, r.path); toast(`Opened ${baseName(r.path)}`); }
}

async function saveFile(saveAs = false) {
  const r = await api.save({ filePath: state.filePath, content: editor.getValue(), saveAs, suggestedName: state.suggestedName });
  if (!r) return false;
  state.filePath = r.path;
  setDirty(false);
  updateTitle();
  setStatus(`Saved ${baseName(r.path)}`, 'ok');
  return true;
}

// ---------------------------------------------------------------------
//  Compiling
// ---------------------------------------------------------------------
function clearError() {
  if (!state.errorMark) return;
  const { line, widget } = state.errorMark;
  editor.removeLineClass(line, 'background', 'line-error');
  editor.setGutterMarker(line, 'error-gutter', null);
  widget.clear();
  state.errorMark = null;
}

function showError(line, message) {
  clearError();
  const ln = Math.max(0, Math.min(editor.lineCount() - 1, (line || 1) - 1));
  editor.addLineClass(ln, 'background', 'line-error');
  const marker = document.createElement('span');
  marker.className = 'error-marker';
  marker.textContent = '!';
  editor.setGutterMarker(ln, 'error-gutter', marker);
  const box = document.createElement('div');
  box.className = 'error-widget';
  box.textContent = message;
  const widget = editor.addLineWidget(ln, box, { coverGutter: false, noHScroll: true });
  state.errorMark = { line: ln, widget };
}

function setTarget(target) {
  const L = LANGS[target] || LANGS.cpp;
  state.target = target;
  $('target-select').value = target;
  $('output-lang').textContent = L.label;
  $('status-target').textContent = L.label;
  document.body.classList.toggle('script-mode', !L.board);
  $('board-wrap').classList.toggle('hidden', target !== 'cpp');
  $('port-wrap').classList.toggle('hidden', !L.board);
  $('btn-refresh').classList.toggle('hidden', !L.board);
  output.setOption('mode', L.mode);
  updatePrimaryButton();
}

// The yellow button is Upload for boards, Run for scripts, Preview for pages, Stop while running
const ICONS = {
  upload: '<path d="M12 19V5M5 12l7-7 7 7"/>',
  run: '<path d="M7 4.5v15l12-7.5z" fill="currentColor"/>',
  preview: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
  stop: '<rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor"/>',
};
function updatePrimaryButton() {
  const b = $('btn-upload');
  const L = LANGS[state.target] || LANGS.cpp;
  let kind;
  let label;
  let title;
  if (state.running) { kind = 'stop'; label = 'Stop'; title = 'Stop the running program (Shift+F5)'; }
  else if (state.uploading) { kind = 'upload'; label = 'Uploading…'; title = 'Uploading'; }
  else if (L.board) { kind = 'upload'; label = 'Upload'; title = 'Send the program to your board (Ctrl+U)'; }
  else if (state.target === 'html') { kind = 'preview'; label = 'Preview'; title = 'Show the page in the preview window (F5)'; }
  else { kind = 'run'; label = 'Run'; title = 'Run the script (F5)'; }
  b.classList.toggle('run', kind === 'run' || kind === 'preview');
  b.classList.toggle('stop', kind === 'stop');
  b.classList.toggle('running', state.uploading);
  b.disabled = state.uploading;
  b.title = title;
  $('primary-icon').innerHTML = ICONS[kind];
  b.querySelector('span').textContent = label;
}

let compileTimer = null;
function scheduleCompile() {
  clearTimeout(compileTimer);
  compileTimer = setTimeout(compileNow, 250);
}

async function compileNow() {
  const r = await api.compile(editor.getValue());
  state.lastResult = r;
  if (r.ok) {
    clearError();
    if (r.target !== state.target) setTarget(r.target);
    const scroll = output.getScrollInfo();
    output.setValue(r.code);
    output.scrollTo(scroll.left, scroll.top);
    const lines = r.code.split('\n').length;
    $('output-info').textContent = `${lines} lines · updates as you type`;
    setStatus(`✓ No errors · compiles to ${LANGS[r.target].label}`, 'ok');
  } else {
    showError(r.line, r.message);
    $('output-info').textContent = 'Fix the error to update';
    setStatus(`✗ Line ${r.line}: ${r.message}`, 'error');
  }
  return r;
}

async function compileAndSave() {
  const r = await api.build({ filePath: state.filePath, source: editor.getValue() });
  showTab('bottom', 'console');
  if (!r.ok) {
    await compileNow();
    logLine(`✗ Line ${r.line}: ${r.message}\n`, 'error');
    jumpToError();
    return;
  }
  await compileNow();
  if (r.outFile) {
    logLine(`✓ Compiled. Saved ${r.outFile}\n`, 'ok');
    toast(`Compiled → ${baseName(r.outFile)}`);
  } else {
    logLine('✓ Compiled with no errors. Save your .volt file to also save the output file next to it.\n', 'ok');
  }
}

function jumpToError() {
  if (!state.errorMark) return;
  editor.setCursor(state.errorMark.line, 0);
  editor.scrollIntoView(null, 120);
  editor.focus();
}
$('status').addEventListener('click', () => { if ($('status').classList.contains('error')) jumpToError(); });

// Rewrites the first line (#c++, #python, #html ...) when a language is picked
function switchTarget(target) {
  const directive = LANGS[target].directive;
  for (let i = 0; i < editor.lineCount(); i++) {
    const text = editor.getLine(i).trim();
    if (text === '' || text.startsWith('//')) continue;
    if (/^#(c\+\+|cpp|arduino|python|py|micropython|ruby|rb|js|javascript|node|html|web)$/i.test(text)) {
      editor.replaceRange(directive, { line: i, ch: 0 }, { line: i, ch: editor.getLine(i).length });
      return;
    }
    break;
  }
  editor.replaceRange(`${directive}\n`, { line: 0, ch: 0 });
}
$('target-select').addEventListener('change', (e) => {
  const target = e.target.value;
  switchTarget(target);
  const L = LANGS[target];
  toast(L.board ? `Now compiling to ${L.label}` : `Now compiling to ${L.label}. Press ${target === 'html' ? 'Preview' : 'Run'} to try it`);
  editor.focus();
});

editor.on('change', () => { setDirty(true); scheduleCompile(); });
editor.on('cursorActivity', () => {
  const c = editor.getCursor();
  $('status-cursor').textContent = `Ln ${c.line + 1}, Col ${c.ch + 1}`;
});

// ---------------------------------------------------------------------
//  Console
// ---------------------------------------------------------------------
function logLine(text, kind = 'info') {
  const el = $('console');
  // A program's 'clear' sends the terminal clear-screen code; wipe the console for it
  const CLEAR = '\x1b[2J';
  if (text.includes(CLEAR)) {
    el.textContent = '';
    text = text.slice(text.lastIndexOf(CLEAR) + CLEAR.length);
  }
  text = text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, '');
  if (!text) return;
  const span = document.createElement('span');
  span.className = kind;
  span.textContent = text;
  el.appendChild(span);
  while (el.childNodes.length > 2000) el.removeChild(el.firstChild);
  el.scrollTop = el.scrollHeight;
}
api.onConsole(({ text, kind }) => logLine(text, kind));

$('btn-clear').addEventListener('click', () => {
  const active = document.querySelector('.tabs[data-group="bottom"] > button.active').dataset.tab;
  $(active === 'monitor' ? 'monitor' : 'console').textContent = '';
});

// ---------------------------------------------------------------------
//  Boards and ports
// ---------------------------------------------------------------------
function fillBoards() {
  const sel = $('board-select');
  sel.innerHTML = BOARDS.map(([fqbn, name]) => `<option value="${fqbn}">${name}</option>`).join('');
  sel.value = state.settings.board || 'arduino:avr:uno';
  if (!sel.value) sel.value = 'arduino:avr:uno';
}
$('board-select').addEventListener('change', (e) => api.setSettings({ board: e.target.value }));

let lastPortKey = '';
async function refreshPorts(manual = false) {
  if (manual) $('btn-refresh').classList.add('spinning');
  const { ports, error } = await api.ports();
  if (manual) setTimeout(() => $('btn-refresh').classList.remove('spinning'), 400);
  const key = ports.map((p) => p.path).join('|');
  if (key === lastPortKey && !manual) return;
  const previous = $('port-select').value || state.settings.port;
  const sel = $('port-select');

  if (!ports.length) {
    sel.innerHTML = '<option value="">No board found</option>';
    if (manual) toast(error ? `Couldn't list ports: ${error}` : 'No board found. Is it plugged in with a data USB cable?', !!error);
  } else {
    sel.innerHTML = ports.map((p) => `<option value="${escapeHtml(p.path)}" data-fqbn="${p.fqbn || ''}">${escapeHtml(p.label)}</option>`).join('');
    sel.value = ports.some((p) => p.path === previous) ? previous : ports[0].path;
    // A new board was plugged in
    if (lastPortKey && ports.length > lastPortKey.split('|').filter(Boolean).length) {
      toast(`Board connected: ${ports.find((p) => !lastPortKey.split('|').includes(p.path)).label}`);
    }
    onPortChosen(false);
  }
  lastPortKey = key;
}

function onPortChosen(announce = true) {
  const opt = $('port-select').selectedOptions[0];
  if (!opt || !opt.value) return;
  api.setSettings({ port: opt.value });
  const fqbn = opt.dataset.fqbn;
  if (fqbn && $('board-select').value !== fqbn && BOARDS.some(([f]) => f === fqbn)) {
    $('board-select').value = fqbn;
    api.setSettings({ board: fqbn });
    if (announce) toast(`Board type set to ${BOARDS.find(([f]) => f === fqbn)[1]}`);
  }
}
$('port-select').addEventListener('change', () => onPortChosen(true));
$('btn-refresh').addEventListener('click', () => refreshPorts(true));
setInterval(() => { if (document.hasFocus() && !state.uploading) refreshPorts(false); }, 3000);

// ---------------------------------------------------------------------
//  Upload
// ---------------------------------------------------------------------
// Runs a script, or shows a page in the preview window
async function run() {
  if (state.running) { await api.stop(); return; }
  const r = await compileNow();
  if (!r.ok) { jumpToError(); toast(`Fix line ${r.line} first`, true); return; }
  if (state.dirty && state.filePath) await saveFile();
  showTab('bottom', 'console');
  if (state.target !== 'html') $('console').textContent = '';
  const res = await api.run({ filePath: state.filePath, source: editor.getValue() });
  if (res.ok && res.preview) {
    setStatus('✓ Page shown in the preview window', 'ok');
  } else if (!res.ok) {
    if (res.message) logLine(`${res.message}\n`, 'error');
    if (res.missing) {
      const links = { python: 'https://www.python.org/downloads/', ruby: 'https://rubyinstaller.org/' };
      const choice = await modal(`${res.missing === 'python' ? 'Python' : 'Ruby'} isn't installed`,
        `<p>Volt turned your program into ${res.missing === 'python' ? 'Python' : 'Ruby'}, but this computer doesn't have ${res.missing === 'python' ? 'Python' : 'Ruby'} installed to run it.</p>` +
        (res.missing === 'python' ? '<p>When installing, tick <b>"Add python.exe to PATH"</b>.</p>' : '<p>Pick the installer marked <b>recommended</b>.</p>') +
        '<p class="muted">You can still press Compile to save the file, or switch to JavaScript, which runs without installing anything.</p>',
        [{ label: 'Close' }, { label: 'Open download page', primary: true }]);
      if (choice === 1) api.openExternal(links[res.missing]);
    }
    setStatus('✗ Could not run. See the console', 'error');
  }
}

api.onRunState(({ running }) => {
  state.running = running;
  $('console-input').classList.toggle('hidden', !running);
  if (running) setTimeout(() => $('stdin-input').focus(), 50);
  setStatus(running ? 'Running… (type answers in the console)' : 'Ready', running ? 'busy' : '');
  updatePrimaryButton();
});

$('console-input').addEventListener('submit', async (e) => {
  e.preventDefault();
  const input = $('stdin-input');
  logLine(`${input.value}\n`, 'echo');
  await api.sendInput(`${input.value}\n`);
  input.value = '';
});

async function upload() {
  if (!(LANGS[state.target] || LANGS.cpp).board) { run(); return; }
  if (state.uploading) return;
  const r = await compileNow();
  if (!r.ok) { jumpToError(); toast(`Fix line ${r.line} first`, true); return; }
  const port = $('port-select').value;
  if (!port) {
    await refreshPorts(true);
    if (!$('port-select').value) {
      modal('No board found',
        '<p>Plug your board into a USB port, then press the refresh button next to the port list.</p>' +
        '<p class="muted">Tip: some USB cables only charge and can\'t send data. If nothing shows up, try another cable.</p>');
      return;
    }
  }
  if (state.dirty && state.filePath) await saveFile();

  showTab('bottom', 'console');
  $('console').textContent = '';
  setStatus('Uploading…', 'busy');
  const res = await api.upload({
    filePath: state.filePath,
    source: editor.getValue(),
    port: $('port-select').value,
    fqbn: $('board-select').value,
  });
  if (res.ok) {
    logLine('✓ Upload complete!\n', 'ok');
    setStatus('✓ Uploaded to your board', 'ok');
    toast('Uploaded! Your board is running the new program.');
  } else {
    if (res.message) logLine(`${res.message}\n`, 'error');
    setStatus('✗ Upload failed. See the console for details', 'error');
    if (res.needsCli) showToolsCheck();
  }
}

api.onUploadState(({ running }) => {
  state.uploading = running;
  updatePrimaryButton();
});

async function showToolsCheck() {
  const s = await api.toolsStatus();
  const row = (ok, title, detail) => `<div class="check-row"><span class="mark ${ok ? 'ok' : 'no'}">${ok ? '✓' : '✗'}</span><div><b>${title}</b><br><span class="muted">${detail}</span></div></div>`;
  const html =
    row(!!s.arduinoCli, 'arduino-cli (for #c++ uploads)', s.arduinoCli
      ? `Found: <code>${escapeHtml(s.arduinoCli)}</code><br>${escapeHtml(s.cliVersion || '')}`
      : 'Not found. Install the <b>Arduino IDE 2</b> from arduino.cc (Volt Studio uses the arduino-cli inside it), or choose an arduino-cli.exe yourself.') +
    row(s.serialport, 'USB serial (ports, monitor, #micropython uploads)', s.serialport ? 'Ready' : 'Missing from this build');
  const it = await api.interpreters();
  const extra =
    row(!!it.python, 'Python (for #python scripts)', it.python ? escapeHtml(it.python.version) : 'Not found. Install it from python.org and tick "Add python.exe to PATH".') +
    row(!!it.ruby, 'Ruby (for #ruby scripts)', it.ruby ? escapeHtml(it.ruby.version) : 'Not found. Install it from rubyinstaller.org.') +
    row(!!it.js, 'JavaScript (for #js scripts)', it.js ? escapeHtml(it.js.version) : 'Missing');
  const choice = await modal('Setup check', html + extra, [{ label: 'Choose arduino-cli…' }, { label: 'Close', primary: true }]);
  if (choice === 0) {
    const p = await api.chooseCli();
    if (p) toast(`Using ${baseName(p)}`);
  }
}

// ---------------------------------------------------------------------
//  Serial monitor
// ---------------------------------------------------------------------
function setMonitorUi(open) {
  state.monitorOpen = open;
  $('btn-monitor').textContent = open ? 'Disconnect' : 'Connect';
  $('monitor-dot').classList.toggle('on', open);
  $('monitor-input').disabled = !open;
  $('btn-send').disabled = !open;
}

async function toggleMonitor() {
  showTab('bottom', 'monitor');
  if (state.monitorOpen) {
    await api.monitorClose();
    setMonitorUi(false);
    return;
  }
  const port = $('port-select').value;
  if (!port) { toast('Pick a port first', true); return; }
  const baud = Number($('baud-select').value);
  const r = await api.monitorOpen({ port, baud });
  if (!r.ok) { appendMonitor(`[${r.message}]\n`); toast(r.message, true); return; }
  api.setSettings({ baud });
  appendMonitor(`[Connected to ${port} at ${baud} baud]\n`);
}

let pendingMonitor = '';
let monitorFrame = null;
function appendMonitor(text) {
  pendingMonitor += text.replace(/\r\n?/g, '\n');
  if (monitorFrame) return;
  monitorFrame = requestAnimationFrame(() => {
    const el = $('monitor');
    el.textContent = (el.textContent + pendingMonitor).slice(-150000);
    pendingMonitor = '';
    monitorFrame = null;
    if ($('autoscroll').checked) el.scrollTop = el.scrollHeight;
  });
}
api.onMonitorData(appendMonitor);
api.onMonitorState((s) => {
  setMonitorUi(s.open);
  if (!s.open && s.message) appendMonitor(`[${s.message}]\n`);
});

async function sendMonitor() {
  const input = $('monitor-input');
  if (!input.value) return;
  await api.monitorSend(`${input.value}\n`);
  input.value = '';
}
$('btn-monitor').addEventListener('click', toggleMonitor);
$('btn-send').addEventListener('click', sendMonitor);
$('monitor-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') sendMonitor(); });

// MicroPython talks at 115200, Serial.begin in Volt's C++ uses 9600
let lastTargetForBaud = null;
setInterval(() => {
  if (state.target !== lastTargetForBaud && !state.monitorOpen) {
    $('baud-select').value = state.target === 'micropython' ? '115200' : '9600';
    lastTargetForBaud = state.target;
  }
}, 500);

// ---------------------------------------------------------------------
//  Reference and examples
// ---------------------------------------------------------------------
const slug = (text) => text.toLowerCase().replace(/<[^>]+>/g, '').replace(/&#39;|'|&\w+;/g, '').replace(/[^\w]+/g, '-').replace(/^-|-$/g, '');

async function loadReference() {
  const md = await api.reference();
  marked.use({
    renderer: {
      heading(text, level) {
        return `<h${level} id="${slug(text)}">${text}</h${level}>`;
      },
    },
  });
  const el = $('reference');
  el.innerHTML = marked.parse(md);

  // Colour the code blocks and add copy buttons
  el.querySelectorAll('pre code').forEach((code) => {
    const lang = (code.className.match(/language-(\S+)/) || [])[1];
    const mode = { volt: 'volt', cpp: 'text/x-c++src', 'c++': 'text/x-c++src', python: 'python', ruby: 'ruby', js: 'javascript', javascript: 'javascript', html: 'htmlmixed', css: 'css' }[lang];
    const text = code.textContent;
    if (mode) {
      code.classList.add('cm-s-volt');
      code.textContent = '';
      CodeMirror.runMode(text, mode, code);
    }
    const btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'Copy';
    btn.onclick = () => { navigator.clipboard.writeText(text); btn.textContent = 'Copied'; setTimeout(() => { btn.textContent = 'Copy'; }, 1200); };
    code.parentElement.appendChild(btn);
  });

  el.addEventListener('click', (e) => {
    const a = e.target.closest('a');
    if (!a) return;
    e.preventDefault();
    const href = a.getAttribute('href') || '';
    if (href.startsWith('#')) {
      const target = document.getElementById(href.slice(1));
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } else {
      api.openExternal(href);
    }
  });
}

async function loadExamples() {
  const list = await api.examples();
  const box = $('examples');
  box.innerHTML = '';
  list.forEach((ex) => {
    const lang = LANGS[directiveTarget(ex.content)];
    const b = document.createElement('button');
    b.className = 'example';
    b.innerHTML = `<h4>${escapeHtml(ex.name.replace(/^\d+_/, '').replace(/_/g, ' '))} <span class="lang-pill">${lang.short}</span></h4><p>${escapeHtml(ex.description)}</p>`;
    b.onclick = async () => {
      if (!(await confirmDiscard())) return;
      loadDocument(ex.content, null);
      state.suggestedName = `${ex.name.replace(/^\d+_/, '')}.volt`;
      setDirty(false);
      toast(`Loaded example: ${ex.name}. Save it to keep your changes.`);
    };
    box.appendChild(b);
  });
}

// ---------------------------------------------------------------------
//  Resizing the panels
// ---------------------------------------------------------------------
function makeDraggable(handle, onMove) {
  handle.addEventListener('mousedown', (e) => {
    e.preventDefault();
    handle.classList.add('dragging');
    const move = (ev) => { onMove(ev); editor.refresh(); output.refresh(); };
    const up = () => {
      handle.classList.remove('dragging');
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  });
}
makeDraggable($('divider-v'), (e) => {
  const width = Math.max(280, Math.min(window.innerWidth - 360, window.innerWidth - e.clientX));
  document.documentElement.style.setProperty('--side-width', `${width}px`);
});
makeDraggable($('divider-h'), (e) => {
  const height = Math.max(90, Math.min(window.innerHeight - 220, window.innerHeight - e.clientY - 26));
  document.documentElement.style.setProperty('--bottom-height', `${height}px`);
});

function setFontSize(px) {
  const size = Math.max(11, Math.min(26, px));
  state.settings.fontSize = size;
  document.documentElement.style.setProperty('--code-size', `${size}px`);
  editor.refresh();
  output.refresh();
  api.setSettings({ fontSize: size });
}

// ---------------------------------------------------------------------
//  Buttons and menu
// ---------------------------------------------------------------------
$('btn-new').addEventListener('click', newFile);
$('btn-open').addEventListener('click', openFile);
$('btn-save').addEventListener('click', () => saveFile());
$('btn-compile').addEventListener('click', compileAndSave);
$('btn-upload').addEventListener('click', upload);
$('btn-copy-output').addEventListener('click', () => {
  navigator.clipboard.writeText(output.getValue());
  toast('Output code copied');
});
$('btn-open-output').addEventListener('click', async () => {
  if (!state.filePath) { toast('Save your .volt file first'); return; }
  await api.build({ filePath: state.filePath, source: editor.getValue() });
  api.openOutput(state.filePath);
});

const MENU = {
  new: newFile,
  open: openFile,
  save: () => saveFile(),
  saveAs: () => saveFile(true),
  openOutput: () => $('btn-open-output').click(),
  find: () => editor.execCommand('find'),
  comment: () => editor.toggleComment(),
  compile: compileAndSave,
  upload,
  stop: () => { if (state.running) api.stop(); },
  openInBrowser: async () => { if (!(await api.openInBrowser())) toast('Preview an #html page first'); },
  monitor: toggleMonitor,
  refreshPorts: () => refreshPorts(true),
  installCore: async () => {
    showTab('bottom', 'console');
    const board = $('board-select').value;
    await api.installCore(board);
  },
  installServo: async () => { showTab('bottom', 'console'); await api.installLib('Servo'); },
  toolsCheck: showToolsCheck,
  chooseCli: async () => { const p = await api.chooseCli(); if (p) toast(`Using ${baseName(p)}`); },
  zoomIn: () => setFontSize((state.settings.fontSize || 15) + 1),
  zoomOut: () => setFontSize((state.settings.fontSize || 15) - 1),
  reference: () => showTab('side', 'reference'),
  about: async () => {
    const info = await api.info();
    modal('Volt Studio',
      `<p><b>Volt Studio ${escapeHtml(info.version)}</b> · Volt language ${escapeHtml(info.voltVersion)}</p>` +
      '<p>Write Volt, compile to Arduino C++ or MicroPython, and upload to your board in one click.</p>');
  },
};
api.onMenu((name) => {
  if (name.startsWith('target:')) { const t = name.slice(7); if (t !== state.target) switchTarget(t); return; }
  if (MENU[name]) MENU[name]();
});
api.onOpenPath(async (filePath) => {
  if (!(await confirmDiscard())) return;
  const r = await api.openPath(filePath);
  if (r) { loadDocument(r.content, r.path); toast(`Opened ${baseName(r.path)}`); }
});

// ---------------------------------------------------------------------
//  Start up
// ---------------------------------------------------------------------
(async function start() {
  const info = await api.info();
  state.settings = info.settings || {};
  $('status-version').textContent = `Volt ${info.voltVersion}`;
  if (state.settings.fontSize) setFontSize(state.settings.fontSize);
  $('baud-select').value = String(state.settings.baud || 9600);
  fillBoards();
  setTarget('cpp');

  const last = await api.lastFile();
  if (last) loadDocument(last.content, last.path);
  else { loadDocument(STARTER.cpp, null); setDirty(false); }

  await Promise.all([loadReference(), loadExamples(), refreshPorts(false)]);
  editor.refresh();
  output.refresh();
}());
