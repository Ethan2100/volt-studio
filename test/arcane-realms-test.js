// Compile Arcane Realms with Volt's production compiler and exercise project paths.
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');
const plugins = require('../lib/plugins.js');
const projectFiles = require('../lib/project-files.js');

const root = path.join(__dirname, '..');
const projectRoot = path.join(root, 'examples', 'arcane-realms');
const manifest = projectFiles.readProjectManifest(projectRoot);
const source = fs.readFileSync(path.join(projectRoot, manifest.entry), 'utf8');
const pluginList = plugins.scanPlugins(path.join(root, 'plugins'), path.join(root, '.no-user-plugins'));
let failed = 0;
function check(name, ok, note = '') { console.log(`${ok ? 'pass' : 'FAIL'}  ${name}${ok ? '' : `: ${note}`}`); if (!ok) failed++; }

try {
  const result = volt.compile(source, { baseDir: projectRoot, extraDirs: plugins.libraryDirs(pluginList) });
  check('Arcane Realms compiles to a playable HTML game', result.target === 'html' && result.code.includes('render3d'));
} catch (err) { check('Arcane Realms compiles to a playable HTML game', false, `${err.message} line ${err.line}`); }
check('the manifest points to an existing game entry', manifest.entry === 'Arcane Realms.volt');
const project = projectFiles.openProject(projectRoot);
check('the project explorer lists linked gameplay scripts', project.files.includes('Scripts/ArcaneController.volt'));
check('the example includes switchable sword and staff combat', /slash3d/.test(fs.readFileSync(path.join(projectRoot, 'Scripts', 'ArcaneController.volt'), 'utf8')) && /beam3d/.test(fs.readFileSync(path.join(projectRoot, 'Scripts', 'ArcaneController.volt'), 'utf8')) && source.includes('SwordBlade') && source.includes('StaffOrb'));

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-project-test-'));
try {
  fs.writeFileSync(path.join(temp, 'main.volt'), '#html\n');
  check('project helpers list Volt files', projectFiles.listVoltFiles(temp).includes('main.volt'));
  let rejected = false;
  try { projectFiles.readVoltFile(temp, '../outside.volt'); } catch { rejected = true; }
  check('project helpers reject traversal outside a project', rejected);
  check('World Studio can create a nested script file', projectFiles.writeVoltFile(temp, 'Scripts/check.volt', 'fn check() {}').created);
} finally { fs.rmSync(temp, { recursive: true, force: true }); }

if (failed) process.exitCode = 1;
