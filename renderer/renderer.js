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
  projectRoot: null,
  projectFiles: [],
  entryFile: null,
  documents: [],
  activeDoc: null,
  entryDoc: null,
  target: 'cpp',
  lastResult: null,
  errorMark: null,       // { line, widget }
  monitorOpen: false,
  uploading: false,
  running: false,        // a script is running
  settings: {},
};
const assetState = { items: [], selected: null, previewToken: 0, renderToken: 0 };

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

// Works for any nesting depth: a .tabs nav always toggles the .tab-body
// siblings living alongside it (its parent's direct children) - so the
// Tools tab's own Reference/Examples/Library sub-nav works the same way
// as the top-level side/bottom ones, with no special-casing.
function showTab(group, name) {
  const nav = document.querySelector(`.tabs[data-group="${group}"]`);
  if (!nav) return;
  nav.querySelectorAll(':scope > button[data-tab]').forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === name);
  });
  const container = nav.parentElement;
  container.querySelectorAll(':scope > .tab-body').forEach((p) => p.classList.toggle('active', p.dataset.panel === name));
  if (name === 'output') output.refresh();
  if (group === 'side' && name === 'assets') loadAssetBrowser();
}
document.querySelectorAll('.tabs').forEach((nav) => {
  nav.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (b) showTab(nav.dataset.group, b.dataset.tab);
  });
});
// "Close" on a menu-only panel (Reference / Examples / Library - opened
// from the Tools menu, with no tab button of their own) goes back to
// whichever tab it names (usually Output code).
document.querySelectorAll('[data-close-tab]').forEach((b) => {
  b.addEventListener('click', () => showTab('side', b.dataset.closeTab));
});

// ---------------------------------------------------------------------
//  File handling
// ---------------------------------------------------------------------
const pathBase = (p) => (p ? p.split(/[\\/]/).pop() : 'untitled.volt');
const pathDir = (p) => (p ? p.replace(/[\\/][^\\/]*$/, '') : '');
const pathJoin = (root, rel) => `${String(root || '').replace(/[\\/]$/, '')}${String(root || '').includes('\\') ? '\\' : '/'}${String(rel || '').replace(/[\\/]/g, String(root || '').includes('\\') ? '\\' : '/')}`;
const projectRelative = (p, root) => String(p || '').slice(String(root || '').length).replace(/^[\\/]+/, '').replace(/\\/g, '/');
function compileFilePath() {
  if (state.entryDoc?.filePath) return state.entryDoc.filePath;
  if (state.projectRoot && state.entryFile) return pathJoin(state.projectRoot, state.entryFile);
  return null;
}
function anyDirty() { return state.documents.some((d) => d.dirty); }
function syncDirty() {
  state.dirty = anyDirty();
  api.setDirty(state.dirty);
  updateTitle();
  renderDocumentTabs();
}
function updateTitle() {
  const doc = state.activeDoc;
  const name = doc ? pathBase(doc.filePath || doc.relativePath || state.suggestedName) : pathBase(state.filePath);
  $('file-name').textContent = name;
  $('file-name').title = doc?.filePath || (doc?.relativePath ? `${state.projectRoot || ''}/${doc.relativePath}` : 'Not saved yet');
  $('file-name').classList.toggle('dirty', state.dirty);
  document.title = `${name}${state.dirty ? ' ●' : ''} – Volt Studio`;
}

function setDirty(value) {
  if (state.activeDoc) state.activeDoc.dirty = value;
  syncDirty();
}

function renderDocumentTabs() {
  const tabs = $('document-tabs');
  if (!tabs) return;
  tabs.innerHTML = state.documents.map((d, i) => {
    const label = pathBase(d.filePath || d.relativePath || state.suggestedName);
    return `<button class="document-tab${d === state.activeDoc ? ' active' : ''}" data-doc="${i}" title="${escapeHtml(d.filePath || d.relativePath || label)}"><span class="tab-label">${escapeHtml(label)}</span>${d.dirty ? '<span class="tab-dirty">●</span>' : ''}${d.isEntry ? '' : '<span class="tab-close" data-close-doc="' + i + '" title="Close file">×</span>'}</button>`;
  }).join('');
}

function renderProjectTree() {
  const tree = $('project-tree'), box = $('project-files'), pane = document.querySelector('.editor-pane');
  const open = !!state.projectRoot;
  tree.classList.toggle('hidden', !open);
  pane.classList.toggle('project-open', open);
  if (!open) return;
  $('project-title').textContent = pathBase(state.projectRoot) || 'PROJECT';
  if (!state.projectFiles.length) {
    box.innerHTML = '<div class="project-empty">No Volt files in this project yet.</div>';
    return;
  }
  box.innerHTML = state.projectFiles.map((f) => {
    const isActive = f === state.activeDoc?.relativePath;
    const depth = Math.max(0, f.split('/').length - 1);
    return `<button class="project-file${isActive ? ' active' : ''}" data-project-file="${escapeHtml(f)}" style="padding-left:${12 + depth * 12}px"><span class="file-glyph">V</span><span>${escapeHtml(pathBase(f))}</span></button>`;
  }).join('');
}

function assetSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
function assetIcon(asset) {
  if (!asset.supported) return '!';
  if (asset.category === 'Models') return '◇';
  if (asset.category === 'Textures') return '▧';
  if (asset.category === 'Audio') return '♫';
  return '•';
}
function visibleAssets() {
  const query = $('asset-search').value.trim().toLowerCase(), category = $('asset-category').value;
  return assetState.items.filter((asset) => (category === 'all' || asset.category === category) && (!query || `${asset.name} ${asset.file} ${asset.category}`.toLowerCase().includes(query)));
}
function renderAssetBrowser() {
  const box = $('asset-browser');
  if (!state.projectRoot) {
    box.innerHTML = '<div class="project-empty">Open a project folder to browse and import assets.</div>';
    $('btn-assets-import').disabled = true; $('btn-assets-refresh').disabled = true;
    return;
  }
  $('btn-assets-import').disabled = false; $('btn-assets-refresh').disabled = false;
  if (!assetState.items.length) {
    box.innerHTML = '<div class="project-empty">No supported assets found. Import GLB models, PNG/JPEG images, or WAV/MP3/OGG/M4A audio.</div>';
    return;
  }
  const shown = visibleAssets();
  if (!shown.length) { box.innerHTML = '<div class="project-empty">No assets match this search.</div>'; return; }
  box.innerHTML = shown.map((asset) => {
    const selected = assetState.selected?.file === asset.file;
    const image = asset.category === 'Textures' && asset.thumb ? `<img class="asset-thumb" alt="" src="${asset.thumb}">` : `<span class="asset-glyph">${assetIcon(asset)}</span>`;
    return `<button class="asset-card${selected ? ' selected' : ''}${asset.supported ? '' : ' unsupported'}" data-asset-file="${escapeHtml(asset.file)}" title="${escapeHtml(asset.reason || asset.file)}">${image}<span class="asset-name">${escapeHtml(asset.name)}</span><span class="asset-meta">${escapeHtml(asset.label)} · ${assetSize(asset.size)}</span></button>`;
  }).join('');
  const token = ++assetState.renderToken;
  const thumbs = shown.filter((a) => a.category === 'Textures' && a.size <= 2 * 1024 * 1024 && a.thumb === undefined).slice(0, 18);
  if (thumbs.length) Promise.all(thumbs.map(async (asset) => {
    try { asset.thumb = await api.readProjectAsset(state.projectRoot, asset.file); }
    catch { asset.thumb = null; }
  })).then(() => { if (token === assetState.renderToken) renderAssetBrowser(); });
}

async function loadAssetBrowser() {
  if (!state.projectRoot) { assetState.items = []; renderAssetBrowser(); return; }
  try {
    assetState.items = await api.projectAssets(state.projectRoot);
    if (assetState.selected && !assetState.items.some((a) => a.file === assetState.selected.file)) {
      assetState.selected = null;
      $('asset-preview').innerHTML = '<span class="muted">Select an asset to preview it or insert its Volt declaration.</span>';
    }
    renderAssetBrowser();
  } catch (err) { toast(`Could not list project assets: ${err.message}`, true); }
}

function assetIdentifier(asset) {
  const stem = asset.name.replace(/\.[^.]+$/, '').replace(/([a-z0-9])([A-Z])/g, '$1_$2').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
  return `asset_${stem || 'file'}`;
}
function insertAssetDeclaration(asset) {
  if (!asset?.supported) return;
  if (state.target !== 'html') { toast('Asset declarations are available in #html Volt games.', true); return; }
  const name = assetIdentifier(asset), file = asset.file.replace(/\\/g, '/');
  const quotedFile = JSON.stringify(file);
  const declaration = asset.category === 'Models' ? `model3d ${name} = ${quotedFile}`
    : asset.category === 'Textures' ? `image ${name} = ${quotedFile}`
      : `audio ${name} = ${quotedFile}`;
  editor.replaceSelection(`${declaration}\n`);
  setDirty(true); scheduleCompile(); editor.focus();
}

async function selectProjectAsset(file) {
  const asset = assetState.items.find((item) => item.file === file);
  if (!asset) return;
  assetState.selected = asset; renderAssetBrowser();
  const preview = $('asset-preview'), token = ++assetState.previewToken;
  if (!asset.supported) {
    preview.innerHTML = `<b>${escapeHtml(asset.name)}</b><p class="asset-reason">${escapeHtml(asset.reason)}</p>`;
    return;
  }
  preview.innerHTML = `<b>${escapeHtml(asset.name)}</b><span> · ${escapeHtml(asset.label)} · ${assetSize(asset.size)}</span><div class="asset-preview-content muted">Loading preview…</div><div class="asset-actions"><button class="link-btn" id="btn-insert-asset">Insert Volt declaration</button><span class="muted">${escapeHtml(asset.file)}</span></div>`;
  $('btn-insert-asset').onclick = () => insertAssetDeclaration(asset);
  if (asset.category !== 'Textures' && asset.category !== 'Audio') {
    preview.querySelector('.asset-preview-content').textContent = 'GLB model is ready to reference from a Volt game. Previewing models in the Asset Browser is not supported yet.';
    return;
  }
  try {
    const data = await api.readProjectAsset(state.projectRoot, asset.file);
    if (token !== assetState.previewToken || assetState.selected?.file !== asset.file) return;
    const content = preview.querySelector('.asset-preview-content');
    if (asset.category === 'Textures') content.innerHTML = `<img alt="Preview of ${escapeHtml(asset.name)}" src="${data}">`;
    else content.innerHTML = `<audio controls preload="none" src="${data}">Audio preview is not supported by this system.</audio>`;
  } catch (err) {
    if (token === assetState.previewToken) preview.querySelector('.asset-preview-content').textContent = err.message;
  }
}

async function importProjectAssets() {
  if (!state.projectRoot) { toast('Open a project folder before importing assets.', true); return; }
  const result = await api.importProjectAssets(state.projectRoot);
  if (!result) return;
  if (!Array.isArray(result)) { toast(result.error || 'Could not import assets.', true); return; }
  await loadAssetBrowser();
  toast(`Imported ${result.length} asset${result.length === 1 ? '' : 's'} into Assets/`);
}

async function refreshProjectTree() {
  if (!state.projectRoot) { state.projectFiles = []; renderProjectTree(); await loadAssetBrowser(); return; }
  try { state.projectFiles = await api.projectFiles(state.projectRoot); }
  catch (err) { state.projectFiles = []; toast(`Could not read project files: ${err.message}`, true); }
  renderProjectTree();
  await loadAssetBrowser();
}

function activateDocument(doc, compile = true) {
  if (!doc) return;
  state.activeDoc = doc;
  state.filePath = doc.filePath || null;
  editor.swapDoc(doc.cm);
  $('target-select').disabled = !doc.isEntry;
  updateTitle(); renderDocumentTabs(); renderProjectTree();
  editor.refresh();
  if (doc.isEntry && compile) compileNow();
  else if (!doc.isEntry) {
    clearError();
    $('output-info').textContent = 'Save this script to compile the project';
    setStatus(`Editing project script: ${doc.relativePath}`, '');
  }
  editor.focus();
}

function addDocument(content, filePath, relativePath, isEntry = false) {
  const doc = { cm: new CodeMirror.Doc(content, 'volt'), filePath: filePath || null, relativePath: relativePath || null, isEntry, dirty: false };
  state.documents.push(doc);
  if (isEntry) state.entryDoc = doc;
  return doc;
}

function loadDocument(content, filePath, options = {}) {
  state.documents = [];
  state.activeDoc = null;
  state.entryDoc = null;
  state.filePath = filePath || null;
  const oldProjectRoot = state.projectRoot;
  state.projectRoot = options.projectRoot || (filePath ? pathDir(filePath) : null);
  if (oldProjectRoot !== state.projectRoot) {
    assetState.items = []; assetState.selected = null;
    assetState.previewToken++; assetState.renderToken++;
    $('asset-preview').innerHTML = '<span class="muted">Select an asset to preview it or insert its Volt declaration.</span>';
  }
  state.entryFile = options.entryFile || (filePath && state.projectRoot ? projectRelative(filePath, state.projectRoot) : null);
  state.assetDir = options.assetDir || null;
  state.suggestedName = options.suggestedName || (state.entryFile ? pathBase(state.entryFile) : 'my_program.volt');
  const doc = addDocument(content, filePath, state.entryFile, true);
  state.target = directiveTarget(content);
  setTarget(state.target);
  activateDocument(doc, false);
  syncDirty();
  refreshProjectTree();
  compileNow();
}

function openProjectEntry(root, relative, content, files) {
  const full = pathJoin(root, relative);
  state.projectFiles = files || [];
  state.assetDir = root;
  loadDocument(content, full, { projectRoot: root, entryFile: relative, assetDir: root });
}

async function chooseEntryFile(files) {
  if (!files.length) return null;
  if (files.length === 1) return files[0];
  return new Promise((resolve) => {
    const items = files.map((f) => `<button class="example" data-entry="${escapeHtml(f)}"><h4>${escapeHtml(f)}</h4><p>Open as the project game file</p></button>`).join('');
    modal('Choose the game file', `<p>Select the main .volt file for this project.</p><div class="examples">${items}</div>`, [{ label: 'Cancel' }]).then(() => resolve(null));
    $('modal-body').querySelectorAll('[data-entry]').forEach((b) => b.onclick = () => { $('modal').classList.add('hidden'); resolve(b.dataset.entry); });
  });
}

async function openProject() {
  if (!(await confirmDiscard())) return;
  const project = await api.openProject();
  if (!project) return;
  if (project.error) { toast(project.error, true); return; }
  const entry = project.entry || await chooseEntryFile(project.files || []);
  if (!entry) { toast('Choose a project with a .volt game file.', true); return; }
  try { openProjectEntry(project.root, entry, await api.readProjectScript(project.root, entry), project.files); }
  catch (err) { toast(`Could not open project: ${err.message}`, true); }
  toast(`Opened project: ${project.manifest?.name || pathBase(project.root)}`);
}

async function openProjectFromDetails(project) {
  if (!(await confirmDiscard())) return;
  try { openProjectEntry(project.projectRoot, project.entryFile, project.content, await api.projectFiles(project.projectRoot)); }
  catch (err) { toast(`Could not open project: ${err.message}`, true); return; }
  toast(`Opened project: ${project.name}`);
}

async function confirmDiscard() {
  if (!anyDirty()) return true;
  const choice = await modal('Unsaved changes',
    `<p>${state.documents.filter((d) => d.dirty).map((d) => `<b>${escapeHtml(pathBase(d.filePath || d.relativePath || state.suggestedName))}</b>`).join(', ')} ${state.documents.filter((d) => d.dirty).length === 1 ? 'has' : 'have'} changes that aren't saved.</p>`,
    [{ label: 'Cancel' }, { label: "Don't save" }, { label: 'Save All', primary: true }]);
  if (choice === 0) return false;
  if (choice === 2) return saveAll();
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
  if (r) { loadDocument(r.content, r.path, { projectRoot: r.projectRoot }); toast(`Opened ${baseName(r.path)}`); }
}

async function saveFile(saveAs = false) {
  const doc = state.activeDoc;
  if (!doc) return false;
  if (!doc.isEntry) {
    if (!state.projectRoot || !doc.relativePath) { toast('Open a project folder before saving a script.', true); return false; }
    try {
      await api.writeProjectScript(state.projectRoot, doc.relativePath, doc.cm.getValue());
      doc.dirty = false; syncDirty();
      const functionName = (doc.cm.getValue().match(/^\s*fn\s+([A-Za-z_]\w*)\s*\(/m) || [])[1] || '';
      notifyWorldStudioScriptSaved(doc.relativePath, functionName);
      setStatus(`Saved ${doc.relativePath}`, 'ok');
      return true;
    } catch (err) { toast(`Could not save script: ${err.message}`, true); return false; }
  }
  const r = await api.save({ filePath: doc.filePath, content: doc.cm.getValue(), saveAs, suggestedName: state.suggestedName });
  if (!r) return false;
  doc.filePath = r.path; doc.relativePath = projectRelative(r.path, r.projectRoot); state.filePath = r.path;
  state.projectRoot = r.projectRoot; state.entryFile = doc.relativePath; state.assetDir = null;
  doc.dirty = false; syncDirty(); refreshProjectTree();
  setStatus(`Saved ${baseName(r.path)}`, 'ok');
  return true;
}

async function saveAll() {
  const active = state.activeDoc;
  const docs = [...state.documents].filter((d) => d.dirty).sort((a, b) => Number(b.isEntry) - Number(a.isEntry));
  for (const doc of docs) {
    activateDocument(doc, false);
    if (!(await saveFile(false))) {
      if (active) activateDocument(active, false);
      return false;
    }
  }
  if (active) activateDocument(active, false);
  return true;
}

async function openProjectFile(relative) {
  if (!state.projectRoot) return;
  const entryPath = pathJoin(state.projectRoot, relative);
  let doc = state.documents.find((d) => d.filePath === entryPath || d.relativePath === relative);
  if (!doc) {
    try { doc = addDocument(await api.readProjectScript(state.projectRoot, relative), entryPath, relative, relative === state.entryFile); }
    catch (err) { toast(`Could not open ${relative}: ${err.message}`, true); return; }
  }
  if (doc.isEntry) state.entryDoc = doc;
  activateDocument(doc);
}

async function closeDocument(doc) {
  if (!doc || doc.isEntry) return;
  if (doc.dirty) {
    const choice = await modal('Unsaved script', `<p><b>${escapeHtml(doc.relativePath)}</b> has unsaved changes.</p>`, [{ label: 'Cancel' }, { label: "Don't save" }, { label: 'Save', primary: true }]);
    if (choice === 0) return;
    if (choice === 2) { activateDocument(doc, false); if (!(await saveFile())) return; }
  }
  const index = state.documents.indexOf(doc);
  state.documents.splice(index, 1);
  if (state.activeDoc === doc) activateDocument(state.entryDoc || state.documents[0]);
  syncDirty();
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

// Does this open document correspond to the file the compiler named? The
// compiler reports the path as it was imported ("Scripts/script.volt"), so
// match on the tail of the path.
function docIsFile(doc, file) {
  if (!doc || !file) return false;
  const want = String(file).replace(/\\/g, '/').toLowerCase();
  const have = String(doc.filePath || doc.name || '').replace(/\\/g, '/').toLowerCase();
  return have === want || have.endsWith('/' + want) || have.split('/').pop() === want.split('/').pop();
}

function showError(line, message, file) {
  clearError();
  state.errorFile = file || '';
  // The compile always runs on the entry document, so an error can belong
  // to a file other than the one being looked at. Marking it here anyway -
  // and clamping the line to fit - is how a perfectly good '}' at the end
  // of an imported file ends up underlined in red. Say where it is instead.
  if (file && !docIsFile(state.activeDoc, file)) return;
  if (!line || line > editor.lineCount()) return;
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
  const r = await api.compile({ source: state.entryDoc?.cm.getValue() || editor.getValue(), filePath: compileFilePath(), assetDir: state.assetDir || state.projectRoot });
  state.lastResult = r;
  updateAiErrorButton();
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
    showError(r.line, r.message, r.file);
    $('output-info').textContent = 'Fix the error to update';
    setStatus(`✗ ${r.file ? r.file + ' ' : ''}Line ${r.line}: ${r.message}`, 'error');
  }
  return r;
}

async function compileAndSave() {
  const filePath = compileFilePath();
  if (anyDirty() && !(await saveAll())) return;
  const r = await api.build({ filePath, source: state.entryDoc?.cm.getValue() || editor.getValue(), assetDir: state.assetDir || state.projectRoot });
  showTab('bottom', 'console');
  if (!r.ok) {
    await compileNow();
    logLine(`✗ ${r.file ? r.file + ' ' : ''}Line ${r.line}: ${r.message}\n`, 'error');
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
  // the error may be in another open file - go to that tab first
  if (state.errorFile && !docIsFile(state.activeDoc, state.errorFile)) {
    const doc = state.documents.find((d) => docIsFile(d, state.errorFile));
    if (doc) {
      activateDocument(doc);
      const r = state.lastResult;
      if (r && !r.ok) showError(r.line, r.message, r.file);
    }
    return;
  }
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
  if (anyDirty() && state.projectRoot && !(await saveAll())) return;
  showTab('bottom', 'console');
  if (state.target !== 'html') $('console').textContent = '';
  const res = await api.run({ filePath: compileFilePath(), source: state.entryDoc?.cm.getValue() || editor.getValue(), assetDir: state.assetDir || state.projectRoot });
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
  if (anyDirty() && state.projectRoot && !(await saveAll())) return;

  showTab('bottom', 'console');
  $('console').textContent = '';
  setStatus('Uploading…', 'busy');
  const res = await api.upload({
    filePath: compileFilePath(),
    source: state.entryDoc?.cm.getValue() || editor.getValue(),
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
  // The inline suggestions read their built-in signatures straight out of
  // this same document, so they can never offer syntax the reference does
  // not describe (see renderer/ghost.js).
  if (window.VoltGhost && window.VoltGhost.learn) {
    try { window.VoltGhost.learn(md); } catch (e) { console.warn('Could not read signatures from the reference', e); }
  }
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
      if (ex.projectRoot && Array.isArray(ex.files)) {
        openProjectEntry(ex.projectRoot, ex.entryFile, ex.content, ex.files);
        toast(`Opened project example: ${ex.name}`);
      } else {
        loadDocument(ex.content, null, { assetDir: ex.assetDir || null });
        state.suggestedName = `${ex.name.replace(/^\d+_/, '')}.volt`;
        setDirty(false);
        toast(`Loaded example: ${ex.name}. Save it to keep your changes.`);
      }
    };
    box.appendChild(b);
  });
}

// ---------------------------------------------------------------------
//  Addons / plugins
// ---------------------------------------------------------------------
// Dynamically-added side tabs for "panel" plugins (built once per rescan,
// since the set of plugins can change if the user drops a new one in).
let panelTabEls = []; // { button, body } pairs added to the DOM
function clearPanelTabs() {
  panelTabEls.forEach(({ button, body }) => { button.remove(); body.remove(); });
  panelTabEls = [];
}

function addPanelTab(plugin) {
  const name = `panel-${plugin.id}`;
  const nav = document.querySelector('.tabs[data-group="side"]');
  const button = document.createElement('button');
  button.dataset.tab = name;
  button.textContent = (plugin.manifest.panel && plugin.manifest.panel.title) || plugin.manifest.name;
  nav.appendChild(button);

  const body = document.createElement('div');
  body.className = 'tab-body';
  body.dataset.panel = name;
  const frame = document.createElement('iframe');
  frame.sandbox = 'allow-scripts';
  frame.style.cssText = 'flex:1;border:0;width:100%;height:100%;background:#fff;';
  body.appendChild(frame);
  $('side-pane').appendChild(body);

  api.pluginsPanelUrl({ id: plugin.id }).then((url) => { if (url) frame.src = url; });
  panelTabEls.push({ button, body, frame });
}

function notifyWorldStudioScriptSaved(relative, fn) {
  for (const panel of panelTabEls) {
    if (panel.frame && /world-studio/i.test(panel.button?.textContent || '')) {
      try { panel.frame.contentWindow.postMessage({ voltHost: 1, type: 'scriptSaved', file: relative, fn }, '*'); } catch { /* panel may be reloading */ }
    }
  }
}

function scriptSlug(name) {
  const slug = String(name || 'World Script').replace(/([a-z0-9])([A-Z])/g, '$1_$2').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
  return slug || 'world_script';
}

async function openWorldStudioScript(entry, message, reply) {
  if (!state.projectRoot) { reply({ type: 'scriptOpenFailed', message: 'Open or save this game inside a project folder first.' }); return; }
  const requested = typeof message.file === 'string' ? message.file : '';
  let relative = requested, fn = typeof message.fn === 'string' ? message.fn : '';
  try {
    if (!relative) {
      const stem = scriptSlug(message.name);
      let candidateFn = `world_${stem}`;
      let suffix = 1;
      relative = `Scripts/${stem}.volt`;
      while (state.projectFiles.includes(relative)) { relative = `Scripts/${stem}_${++suffix}.volt`; candidateFn = `world_${stem}_${suffix}`; }
      const legacy = String(message.code || '').replace(/\r/g, '').split('\n').filter((line, i, all) => !(i === all.length - 1 && !line.trim()));
      const body = legacy.some((line) => line.trim()) ? legacy.map((line) => line.trim() ? `  ${line}` : '').join('\n') : '  // Add this script\'s behavior here.\n  // Use PLAYER_X, PLAYER_Y, PLAYER_Z and the VFX helpers from the game file.';
      const result = await api.createProjectScript(state.projectRoot, relative, `// World Studio script: ${message.name || 'World Script'}\nfn ${candidateFn}() {\n${body}\n}\n`);
      if (!result.created) { await openWorldStudioScript(entry, { ...message, file: relative, fn: candidateFn }, reply); return; }
      fn = candidateFn;
    }
    const content = await api.readProjectScript(state.projectRoot, relative);
    const declared = [...content.matchAll(/^\s*fn\s+([A-Za-z_]\w*)\s*\(/gm)].map((m) => m[1]);
    if (!declared.includes(fn)) fn = declared[0] || '';
    if (!state.projectFiles.includes(relative)) { state.projectFiles.push(relative); state.projectFiles.sort(); renderProjectTree(); }
    await openProjectFile(relative);
    reply({ type: 'scriptOpened', objectId: message.objectId, file: relative, fn });
  } catch (err) { reply({ type: 'scriptOpenFailed', message: err.message || 'Could not open script file.' }); }
}

async function loadPlugins() {
  const plugins = await api.pluginsList();

  // Library tab: every "library" plugin's snippet files, click-to-insert
  const box = $('library');
  box.innerHTML = '';
  const libraries = plugins.filter((p) => !p.broken && p.manifest.type === 'library');
  if (!libraries.length) {
    box.innerHTML = '<p class="ai-empty">No library addons installed. Drop a folder with a plugin.json into the plugins folder to add one.</p>';
  }
  for (const p of libraries) {
    for (const snip of (p.manifest.snippets || [])) {
      const b = document.createElement('button');
      b.className = 'example';
      b.innerHTML = `<h4>${escapeHtml(snip.label || snip.file)} <span class="lang-pill">${escapeHtml(p.manifest.name)}</span></h4><p>${escapeHtml(snip.description || '')}</p>`;
      b.onclick = async () => {
        const code = await api.pluginsReadFile({ id: p.id, file: snip.file });
        if (code == null) { toast(`Could not read ${snip.file}`, true); return; }
        editor.replaceSelection(code.endsWith('\n') ? code : `${code}\n`);
        toast(`Inserted ${snip.label || snip.file}`);
        editor.focus();
      };
      box.appendChild(b);
    }
  }

  // Panel tabs: one new side tab per "panel" plugin
  clearPanelTabs();
  plugins.filter((p) => !p.broken && p.manifest.type === 'panel').forEach(addPanelTab);
}
$('btn-plugins-folder').addEventListener('click', () => api.pluginsOpenFolder());
$('btn-plugins-rescan').addEventListener('click', async () => { await api.pluginsRescan(); await loadPlugins(); toast('Rescanned plugins'); });

// ---------------------------------------------------------------------
//  Panel bridge: lets a "panel" addon talk to the editor with postMessage.
//  Panels stay sandboxed (no Node, no filesystem) - they can only ask for
//  these few things. See docs/PLUGINS.md ("Talking to the editor").
// ---------------------------------------------------------------------
let sideWidthBeforeWide = null;
window.addEventListener('message', (ev) => {
  const m = ev.data;
  if (!m || m.voltPanel !== 1) return;
  const entry = panelTabEls.find((p) => p.frame && p.frame.contentWindow === ev.source);
  if (!entry) return;   // only our own panel frames may talk to the editor
  const reply = (msg) => { try { entry.frame.contentWindow.postMessage(Object.assign({ voltHost: 1 }, msg), '*'); } catch (e) { /* frame went away */ } };
  const code = typeof m.code === 'string' && m.code.length < 4000000 ? m.code : null;
  switch (m.type) {
    case 'hello': reply({ type: 'hello', version: 1 }); break;
    case 'getSource': reply({ type: 'source', req: m.req, source: state.entryDoc?.cm.getValue() || editor.getValue() }); break;
    case 'openScript': openWorldStudioScript(entry, m, reply); break;
    case 'insert':
      if (code != null) { editor.replaceSelection(code.endsWith('\n') ? code : `${code}\n`); editor.focus(); }
      break;
    case 'replace':   // one undo step in the code editor (Ctrl+Z)
      if (code != null) {
        const doc = state.entryDoc || state.activeDoc;
        doc.cm.setValue(code); doc.cm.setCursor(0, 0); doc.dirty = true; syncDirty(); compileNow();
        if (m.run) run();
      }
      break;
    case 'toast': if (typeof m.text === 'string') toast(m.text.slice(0, 200), !!m.error); break;
    case 'assetList':   // which models a library plugin ships
      api.pluginsListAssets({ id: String(m.plugin || '') })
        .then((files) => reply({ type: 'assetList', req: m.req, files: files || [] }))
        .catch(() => reply({ type: 'assetList', req: m.req, files: [] }));
      break;
    case 'asset':   // a model a library plugin ships, so the panel can show it
      api.pluginsReadAsset({ id: String(m.plugin || ''), file: String(m.file || '') })
        .then((base64) => reply({ type: 'asset', req: m.req, file: m.file, base64 }))
        .catch(() => reply({ type: 'asset', req: m.req, file: m.file, base64: null }));
      break;
    case 'wide': {   // a panel can ask for more room (and give it back)
      const root = document.documentElement.style;
      if (m.on) {
        if (sideWidthBeforeWide === null) sideWidthBeforeWide = root.getPropertyValue('--side-width');
        root.setProperty('--side-width', `${Math.max(280, Math.min(window.innerWidth - 380, Math.round(window.innerWidth * 0.78)))}px`);
      } else if (sideWidthBeforeWide !== null) {
        if (sideWidthBeforeWide) root.setProperty('--side-width', sideWidthBeforeWide); else root.removeProperty('--side-width');
        sideWidthBeforeWide = null;
      }
      editor.refresh(); output.refresh();
      break;
    }
  }
});

// ---------------------------------------------------------------------
//  AI chat - grounded in the real Volt reference (see lib/ai.js);
//  answered by the user's own Gemini API key, kept in the main process.
// ---------------------------------------------------------------------
const aiHistory = []; // [{ role, content }], sent in full with every request

function renderAiCode(container) {
  container.querySelectorAll('pre code').forEach((code) => {
    const lang = (code.className.match(/language-(\S+)/) || [])[1];
    const mode = { volt: 'volt', cpp: 'text/x-c++src', 'c++': 'text/x-c++src', python: 'python', ruby: 'ruby', js: 'javascript', javascript: 'javascript', html: 'htmlmixed' }[lang];
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

    const insertBtn = document.createElement('button');
    insertBtn.className = 'copy-btn';
    insertBtn.textContent = 'Insert';
    insertBtn.title = 'Insert at the cursor in your editor';
    insertBtn.onclick = () => {
      editor.replaceSelection(text.endsWith('\n') ? text : `${text}\n`);
      toast('Inserted into the editor');
      editor.focus();
    };

    const replaceBtn = document.createElement('button');
    replaceBtn.className = 'copy-btn';
    replaceBtn.textContent = 'Replace file';
    replaceBtn.title = 'Replace everything in the editor with this code';
    replaceBtn.onclick = async () => {
      const choice = await modal('Replace file with this code?',
        '<p>This overwrites everything currently in the editor with the code block above. Undo (Ctrl+Z) still works if you change your mind.</p>',
        [{ label: 'Cancel' }, { label: 'Replace', primary: true }]);
      if (choice !== 1) return;
      editor.setValue(text);
      setDirty(true);
      toast('Replaced the file with the AI\'s code');
    };

    const bar = document.createElement('div');
    bar.className = 'ai-code-actions';
    bar.append(btn, insertBtn, replaceBtn);
    code.parentElement.insertAdjacentElement('afterend', bar);
  });
}

function addAiMessage(role, text) {
  const list = $('ai-messages');
  list.querySelector('.ai-empty')?.remove();
  const div = document.createElement('div');
  div.className = `ai-msg ${role}`;
  if (role === 'assistant') {
    div.innerHTML = marked.parse(text);
    renderAiCode(div);
  } else {
    div.textContent = text;
  }
  list.appendChild(div);
  list.scrollTop = list.scrollHeight;
  return div;
}

// Every question is sent with the user's current file as live context, so
// the AI can read and reason about the actual code they're looking at
// (and, via the Insert/Replace buttons above, write back into it) without
// them having to paste it in themselves. This is built fresh per request
// rather than cached in aiHistory, so it always reflects the latest edits.
function buildCodeContext() {
  const lang = (LANGS[state.target] && LANGS[state.target].label) || state.target;
  let text = `[Context: the user's current .volt file, compiling to ${lang}]\n\`\`\`volt\n${editor.getValue()}\n\`\`\``;
  if (state.lastResult && !state.lastResult.ok) {
    text += `\n\nThis file currently fails to compile, at line ${state.lastResult.line}: ${state.lastResult.message}`;
  }
  return text;
}

async function sendAiMessage(text) {
  addAiMessage('user', text);
  aiHistory.push({ role: 'user', content: text }); // stored as plain display text
  const list = $('ai-messages');
  const thinking = document.createElement('div');
  thinking.className = 'ai-thinking';
  thinking.textContent = 'Thinking…';
  list.appendChild(thinking);
  list.scrollTop = list.scrollHeight;
  $('ai-send').disabled = true;
  // A visible, ticking counter so waiting never looks frozen - and past
  // 10s a reminder that the request is hard-capped (see lib/ai.js), so a
  // bad connection fails loudly within ~25s instead of hanging silently.
  const startedAt = Date.now();
  const ticker = setInterval(() => {
    const secs = Math.floor((Date.now() - startedAt) / 1000);
    thinking.textContent = secs < 10 ? `Thinking… (${secs}s)` : `Thinking… (${secs}s - will time out around 25s if the connection has stalled)`;
  }, 1000);
  try {
    // Only the newest user turn is sent with fresh code context attached -
    // earlier turns go as plain text, so the file isn't re-sent in full on
    // every message once the conversation moves on.
    const wireMessages = aiHistory.map((m, i) => (
      i === aiHistory.length - 1 && m.role === 'user'
        ? { role: m.role, content: `${buildCodeContext()}\n\n${m.content}` }
        : m
    ));
    const r = await api.aiChat(wireMessages);
    clearInterval(ticker);
    thinking.remove();
    if (r.ok) {
      addAiMessage('assistant', r.reply);
      aiHistory.push({ role: 'assistant', content: r.reply });
    } else {
      addAiMessage('error', r.error);
      aiHistory.pop(); // don't keep a failed turn in the sent history
    }
  } catch (err) {
    clearInterval(ticker);
    thinking.remove();
    addAiMessage('error', err && err.message ? err.message : String(err));
    aiHistory.pop();
  } finally {
    clearInterval(ticker);
    $('ai-send').disabled = false;
  }
}

$('ai-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const box = $('ai-text');
  const text = box.value.trim();
  if (!text) return;
  box.value = '';
  sendAiMessage(text);
});
$('ai-text').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); $('ai-form').requestSubmit(); }
});
$('btn-ai-clear').addEventListener('click', () => {
  aiHistory.length = 0;
  $('ai-messages').innerHTML = '<p class="ai-empty">Ask anything about Volt - syntax, a compile error, what a built-in does - or have it write or fix code in your open file. Every question is sent with your current file as context, and any code it writes back can be inserted with one click.</p>';
});

$('ai-explain').addEventListener('click', () => sendAiMessage('Explain what this file does, in a few sentences.'));
$('ai-fix-error').addEventListener('click', () => sendAiMessage('This file fails to compile with the error above. Explain what\'s wrong and show the fixed code.'));
function updateAiErrorButton() {
  $('ai-fix-error').classList.toggle('hidden', !(state.lastResult && !state.lastResult.ok));
}

// The resolved key can come from the saved setting or from the
// GEMINI_API_KEY environment variable (see main.js's resolveAiKey) -
// ai:keyInfo tells us which, without ever handing the actual key to the
// renderer, so the status line can say which one is actually in effect.
async function updateAiKeyStatus() {
  const info = await api.aiKeyInfo();
  if (!info.hasKey) { $('ai-key-status').textContent = 'No API key set'; return; }
  // with several keys, say which one is in use - a key that runs out is
  // skipped from then on, so this number moving is the sign that happened
  const which = info.count > 1 ? ` (…${info.last4}, key ${info.using} of ${info.count})` : ` (…${info.last4})`;
  const where = info.source === 'env' ? (info.envName || 'GEMINI_API_KEY') : 'your key';
  $('ai-key-status').textContent = `Using ${where}${which} · ${info.model}`;
}

$('btn-ai-settings').addEventListener('click', async () => {
  const info = await api.aiKeyInfo();
  const envNote = info.hasKey && info.source === 'env'
    ? `<p class="muted">Currently using the <code>${info.envName || 'GEMINI_API_KEY'}</code> environment variable (${info.count > 1 ? `${info.count} keys` : `…${info.last4}`}). Saving a key here overrides it; leave this blank and Cancel to keep using the environment variable.</p>`
    : '<p class="muted">You can also set this via the <code>GEMINI_API_KEY</code> environment variable, or <code>GEMINI_API_KEYS</code> for several at once (and optionally <code>GEMINI_MODEL</code>), instead of saving it here.</p>';
  const modalPromise = modal('Gemini API key',
    `<p class="muted" style="margin-top:0">Used only to power the AI tab, called from this app's own process - your key never leaves your computer except straight to Google. Get a key at <code>aistudio.google.com</code>. You can paste several, separated by commas: if one is out of quota the next is used.</p>
     <label style="display:block;margin-bottom:10px">API key${info.count > 1 ? 's' : ''}
       <input type="password" id="ai-key-input" value="${escapeHtml(state.settings.geminiApiKey || '')}" placeholder="${info.hasKey && info.source === 'env' ? 'Leave blank to keep using the environment variable' : 'AIza…'}" style="width:100%;margin-top:4px;padding:7px 9px;background:var(--panel-2);border:1px solid var(--border);border-radius:7px;color:var(--text);font:inherit">
     </label>
     <label style="display:block;margin-bottom:10px">Model
       <input type="text" id="ai-model-input" value="${escapeHtml(state.settings.geminiModel || '')}" placeholder="${info.model}" style="width:100%;margin-top:4px;padding:7px 9px;background:var(--panel-2);border:1px solid var(--border);border-radius:7px;color:var(--text);font:inherit">
     </label>
     ${envNote}`,
    [{ label: 'Cancel' }, { label: 'Save', primary: true }]);
  // modal()'s DOM setup (including its own default focus on the Save
  // button) runs synchronously before it returns the pending promise, so
  // this re-focus - onto the key field, where someone opening this dialog
  // actually wants to type - takes effect right after, before they can
  // notice the first focus at all.
  const keyInput = $('ai-key-input');
  const modelInput = $('ai-model-input');
  keyInput.focus();
  keyInput.select();
  const saveOnEnter = (e) => { if (e.key === 'Enter') { e.preventDefault(); $('modal-actions').lastElementChild.click(); } };
  keyInput.addEventListener('keydown', saveOnEnter);
  modelInput.addEventListener('keydown', saveOnEnter);

  const choice = await modalPromise;
  if (choice !== 1) return;
  const geminiApiKey = keyInput.value.trim();
  const geminiModel = modelInput.value.trim(); // blank = fall back to GEMINI_MODEL / the default
  state.settings = await api.setSettings({ geminiApiKey, geminiModel });
  await updateAiKeyStatus();
  toast(geminiApiKey ? 'Saved your API key' : 'Cleared the saved key');
});

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
$('btn-project').addEventListener('click', openProject);
$('btn-project-refresh').addEventListener('click', refreshProjectTree);
$('btn-assets-refresh').addEventListener('click', loadAssetBrowser);
$('btn-assets-import').addEventListener('click', importProjectAssets);
$('asset-search').addEventListener('input', renderAssetBrowser);
$('asset-category').addEventListener('change', renderAssetBrowser);
$('asset-browser').addEventListener('click', (e) => { const b = e.target.closest('[data-asset-file]'); if (b) selectProjectAsset(b.dataset.assetFile); });
$('project-files').addEventListener('click', (e) => { const b = e.target.closest('[data-project-file]'); if (b) openProjectFile(b.dataset.projectFile); });
$('document-tabs').addEventListener('click', (e) => {
  const close = e.target.closest('[data-close-doc]');
  if (close) { e.stopPropagation(); closeDocument(state.documents[Number(close.dataset.closeDoc)]); return; }
  const tab = e.target.closest('[data-doc]'); if (tab) activateDocument(state.documents[Number(tab.dataset.doc)]);
});
{
  let drag = false;
  $('project-divider').addEventListener('mousedown', (e) => { drag = true; e.preventDefault(); });
  window.addEventListener('mousemove', (e) => { if (drag) document.documentElement.style.setProperty('--project-width', `${Math.max(140, Math.min(420, e.clientX))}px`); });
  window.addEventListener('mouseup', () => { drag = false; });
}
$('btn-save').addEventListener('click', () => saveFile());
$('btn-compile').addEventListener('click', compileAndSave);
$('btn-upload').addEventListener('click', upload);
$('btn-copy-output').addEventListener('click', () => {
  navigator.clipboard.writeText(output.getValue());
  toast('Output code copied');
});
$('btn-open-output').addEventListener('click', async () => {
  const filePath = compileFilePath();
  if (!filePath) { toast('Save your .volt file first'); return; }
  await api.build({ filePath, source: state.entryDoc?.cm.getValue() || editor.getValue(), assetDir: state.assetDir || state.projectRoot });
  api.openOutput(filePath);
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
  examples: () => showTab('side', 'examples'),
  library: () => showTab('side', 'library'),
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

  updateAiKeyStatus();
  await Promise.all([loadReference(), loadExamples(), loadPlugins(), refreshPorts(false)]);
  editor.refresh();
  output.refresh();
}());
