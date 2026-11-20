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
  const audioSource = path.join(temp, 'bell.wav');
  const objSource = path.join(temp, 'mesh.obj');
  const imageSource = path.join(temp, 'icon.png');
  fs.writeFileSync(audioSource, Buffer.from([82, 73, 70, 70]));
  fs.writeFileSync(objSource, 'v 0 0 0');
  fs.writeFileSync(imageSource, Buffer.from([137, 80, 78, 71]));
  const imported = projectFiles.importProjectAssets(temp, [audioSource]);
  check('asset import copies supported audio into Assets', imported[0]?.file === 'Assets/bell.wav');
  check('asset browser reports supported audio metadata', projectFiles.listProjectAssets(temp).some((asset) => asset.file === 'Assets/bell.wav' && asset.category === 'Audio' && asset.supported));
  check('audio assets can be previewed as a data URL', projectFiles.readProjectAsset(temp, 'Assets/bell.wav').startsWith('data:audio/wav;base64,'));
  projectFiles.importProjectAssets(temp, [imageSource]);
  const assetGame = volt.compile('#html\ncanvas 320, 180\nimage ui_icon = "Assets/icon.png"\naudio bell = "Assets/bell.wav"\n', { baseDir: temp });
  check('imported image and audio declarations compile', assetGame.code.includes('__image(') && assetGame.code.includes('__audio('));
  check('asset paths reject traversal outside a project', (() => { try { projectFiles.readProjectAsset(temp, '../bell.wav'); return false; } catch { return true; } })());
  let unsupportedMessage = '';
  try { projectFiles.importProjectAssets(temp, [objSource]); } catch (err) { unsupportedMessage = err.message; }
  check('unsupported OBJ import explains the GLB conversion path', /OBJ import is not available.*\.glb/i.test(unsupportedMessage));
  check('importing a duplicate asset keeps the existing file', projectFiles.importProjectAssets(temp, [audioSource])[0]?.file === 'Assets/bell_2.wav');
} finally { fs.rmSync(temp, { recursive: true, force: true }); }

if (failed) process.exitCode = 1;
