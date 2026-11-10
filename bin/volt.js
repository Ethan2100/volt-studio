#!/usr/bin/env node
// =====================================================================
//  The Volt command line.
//
//    volt build game.volt        turn it into the language its first line picks
//    volt run game.volt          build it and run it (or open the page)
//    volt check game.volt        list every mistake, and say nothing when there are none
//    volt new game.volt          start a new program from a template
//
//    volt add <package>          install a package into volt_packages/
//    volt remove <package>       take one out again
//    volt list                   what this project has installed
//    volt install                install everything volt.json asks for
//
//    volt docs round             what a built-in does
//
//  A package is a folder of .volt files with a volt.json in it. Once installed,
//  a program reaches it with  import "name".  See docs/EXTENSIONS.md.
// =====================================================================

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const volt = require(path.join(ROOT, 'compiler', 'volt.js'));
const plugins = require(path.join(ROOT, 'lib', 'plugins.js'));

// Addon targets (#lua, #luau ...) so the command line understands the same first lines the app does
try {
  plugins.loadTargetPlugins(plugins.scanPlugins(path.join(ROOT, 'plugins'), path.join(os.homedir(), '.volt', 'plugins')), volt, null);
} catch (e) { /* no plugins is fine */ }

const PACKAGES = 'volt_packages';
const MANIFEST = 'volt.json';

const say = (...a) => console.log(...a);
const problem = (...a) => console.error(...a);
function stop(message, hint) {
  problem(message);
  if (hint) problem(`  ${hint}`);
  process.exit(1);
}

// ---------------------------------------------------------------------
//  The project: the nearest folder above the file that has a volt.json,
//  or the file's own folder when there isn't one.
// ---------------------------------------------------------------------
function projectDir(from) {
  let dir = path.resolve(from || process.cwd());
  if (fs.existsSync(dir) && fs.statSync(dir).isFile()) dir = path.dirname(dir);
  for (;;) {
    if (fs.existsSync(path.join(dir, MANIFEST)) || fs.existsSync(path.join(dir, PACKAGES))) return dir;
    const up = path.dirname(dir);
    if (up === dir) return path.resolve(from && fs.existsSync(from) && fs.statSync(from).isFile() ? path.dirname(from) : (from || process.cwd()));
    dir = up;
  }
}

function readManifest(dir) {
  const file = path.join(dir, MANIFEST);
  if (!fs.existsSync(file)) return null;
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    stop(`${file} is not valid JSON: ${e.message}`, 'Fix the file, or delete it to start again.');
    return null;
  }
}

function writeManifest(dir, manifest) {
  fs.writeFileSync(path.join(dir, MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`);
}

// ---------------------------------------------------------------------
//  Compiling
// ---------------------------------------------------------------------
function compileOptions(file) {
  const dir = path.dirname(path.resolve(file));
  const project = projectDir(dir);
  return { baseDir: dir, packageDirs: [path.join(project, PACKAGES)] };
}

function needFile(file) {
  if (!file) stop('Which file? Try: volt build game.volt');
  if (!fs.existsSync(file)) {
    const alt = `${file}.volt`;
    stop(`Can't find '${file}'`, fs.existsSync(alt) ? `Did you mean '${alt}'?` : `Looked in ${path.resolve(path.dirname(file))}`);
  }
  return file;
}

function compileFile(file) {
  const source = fs.readFileSync(file, 'utf8');
  try {
    return { source, ...volt.compile(source, compileOptions(file)) };
  } catch (e) {
    if (!(e instanceof volt.VoltError)) throw e;
    problem(volt.formatProblem(e, file, (f) => (f ? fs.readFileSync(f, 'utf8') : source)));
    process.exit(1);
    return null;
  }
}

function cmdBuild(file) {
  needFile(file);
  const { target, code } = compileFile(file);
  const { outDir, outFile } = volt.outputPath(file, target);
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outFile, code);
  say(`Built ${file} -> ${outFile}`);
  return { target, outFile };
}

function cmdCheck(file) {
  needFile(file);
  const source = fs.readFileSync(file, 'utf8');
  const result = volt.check(source, compileOptions(file));
  const sourceOf = (f) => (f ? fs.readFileSync(f, 'utf8') : source);
  for (const d of result.diagnostics) problem(volt.formatProblem(d, file, sourceOf));
  const errors = result.diagnostics.filter((d) => d.severity !== 'warning').length;
  const warnings = result.diagnostics.length - errors;
  if (!result.diagnostics.length) say(`${file}: no problems. It compiles to ${(volt.TARGETS[result.target] || {}).label || result.target}.`);
  else say(`\n${errors} error${errors === 1 ? '' : 's'}, ${warnings} warning${warnings === 1 ? '' : 's'}`);
  process.exit(errors ? 1 : 0);
}

function cmdRun(file) {
  const { target, outFile } = cmdBuild(file);
  const how = {
    js: ['node'], python: ['python3'], ruby: ['ruby'], micropython: null, cpp: null, html: null,
  }[target];
  if (target === 'html') {
    const opener = process.platform === 'win32' ? ['cmd', ['/c', 'start', '', outFile]]
      : process.platform === 'darwin' ? ['open', [outFile]] : ['xdg-open', [outFile]];
    const r = spawnSync(opener[0], opener[1], { stdio: 'ignore' });
    say(r.error ? `Open this in a browser: ${outFile}` : `Opened ${outFile}`);
    return;
  }
  if (!how) {
    say(target === 'cpp'
      ? 'This is an Arduino sketch. Open it in the Arduino IDE, or upload it from Volt Studio.'
      : 'This is for a MicroPython board. Copy main.py onto the board, or upload it from Volt Studio.');
    return;
  }
  let tool = how[0];
  if (spawnSync(tool, ['--version'], { stdio: 'ignore' }).error) {
    if (tool !== 'python3' || spawnSync('python', ['--version'], { stdio: 'ignore' }).error) {
      stop(`'${tool}' isn't installed, so this program can't run here.`, `Install ${tool} and try again.`);
    }
    tool = 'python';
  }
  const r = spawnSync(tool, [outFile], { stdio: 'inherit' });
  process.exit(r.status === null ? 1 : r.status);
}

const TEMPLATES = {
  html: '#html\n// A web page. Press Preview to see it.\ntitle "My page"\nprint "Hello!"\n',
  game: '#html\n// A little game. Arrow keys to move.\ncanvas 320, 180\n\nlet x = 160\nlet y = 90\n\nevery frame {\n  if held("left") { x -= 3 }\n  if held("right") { x += 3 }\n  if held("up") { y -= 3 }\n  if held("down") { y += 3 }\n\n  paint "#14111a"\n  box x - 8, y - 8, 16, 16 color "#ffd23f"\n  write "Move with the arrow keys" at 160, 160 centered shadow\n}\n',
  '3d': '#html\n// A 3D room. Click, then WASD and the mouse.\ncanvas 320, 180\nworld3d "#0a0d14" fog 2600 ambient 9 shadows\n\nblock3d(0, -10, 0, 2000, 20, 2000, "#5c6470")\nblock3d(0, 150, -600, 1600, 300, 20, "#737a86")\nfreeze3d\n\nplayer3d 0, 0, 400\n\nevery frame {\n  walk3d\n  render3d\n}\n',
  python: '#python\n// A script that runs on your computer.\nlet name = ask "What is your name?"\nprint "Hello {name}!"\n',
  arduino: '#c++\n// An Arduino sketch: blinks the light on pin 13.\npin led = 13\n\nevery 500ms {\n  toggle led\n}\n',
  library: '// A library: just functions, with no first line of its own.\n// Other programs use it with:  import "this-file.volt"\n\nfn double(x) {\n  return x * 2\n}\n',
};

function cmdNew(file, kind) {
  if (!file) stop('What should it be called? Try: volt new game.volt', `Kinds: ${Object.keys(TEMPLATES).join(', ')}`);
  const name = /\.volt$/i.test(file) ? file : `${file}.volt`;
  if (fs.existsSync(name)) stop(`'${name}' already exists.`, 'Pick another name, or delete that one first.');
  const template = TEMPLATES[kind || 'html'];
  if (!template) stop(`There is no '${kind}' template.`, `Try one of: ${Object.keys(TEMPLATES).join(', ')}`);
  fs.mkdirSync(path.dirname(path.resolve(name)), { recursive: true });
  fs.writeFileSync(name, template);
  say(`Made ${name}. Build it with: volt build ${name}`);
}

// ---------------------------------------------------------------------
//  Packages
// ---------------------------------------------------------------------
// What 'volt add <source>' accepts:
//    ./some/folder          a folder on this computer (copied in)
//    owner/repo             a GitHub repository
//    https://… or git@…     any git repository
function readSource(source) {
  if (/^(\.|\/|[A-Za-z]:\\)/.test(source) || fs.existsSync(source)) return { kind: 'folder', from: path.resolve(source) };
  if (/^(https?:\/\/|git@|git:)/.test(source)) return { kind: 'git', from: source };
  if (/^[\w.-]+\/[\w.-]+$/.test(source)) return { kind: 'git', from: `https://github.com/${source}.git`, short: source };
  return null;
}

function packageNameOf(dir, fallback) {
  const manifest = readManifest(dir);
  if (manifest && manifest.name) return String(manifest.name).replace(/[^\w.-]/g, '-');
  return String(fallback).replace(/\.git$/, '').split(/[\\/]/).filter(Boolean).pop().replace(/[^\w.-]/g, '-');
}

function copyFolder(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === PACKAGES) continue;
    const a = path.join(from, entry.name);
    const b = path.join(to, entry.name);
    if (entry.isDirectory()) copyFolder(a, b);
    else if (entry.isFile()) fs.copyFileSync(a, b);
  }
}

function installOne(source, project, { quiet } = {}) {
  const where = readSource(source);
  if (!where) {
    stop(`I don't know how to get '${source}'.`,
      'Use a folder (./my-lib), a GitHub repository (owner/repo), or a git address (https://...).');
  }
  const packagesDir = path.join(project, PACKAGES);
  fs.mkdirSync(packagesDir, { recursive: true });
  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-add-'));
  try {
    if (where.kind === 'folder') {
      if (!fs.existsSync(where.from) || !fs.statSync(where.from).isDirectory()) stop(`'${source}' is not a folder.`);
      copyFolder(where.from, staging);
    } else {
      if (spawnSync('git', ['--version'], { stdio: 'ignore' }).error) {
        stop('Installing from a git address needs git, which is not installed.', 'Install git from git-scm.com, or copy the folder in by hand.');
      }
      const r = spawnSync('git', ['clone', '--depth', '1', '--quiet', where.from, staging], { encoding: 'utf8' });
      if (r.status !== 0) {
        stop(`Could not download '${source}'.`, (r.stderr || '').trim().split('\n').pop() || 'Check the address and your connection.');
      }
      fs.rmSync(path.join(staging, '.git'), { recursive: true, force: true });
    }
    const voltFiles = [];
    (function look(dir) {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.isDirectory()) look(path.join(dir, entry.name));
        else if (entry.name.endsWith('.volt')) voltFiles.push(entry.name);
      }
    }(staging));
    if (!voltFiles.length) stop(`'${source}' has no .volt files in it, so it isn't a Volt package.`);

    const name = packageNameOf(staging, where.short || where.from);
    const target = path.join(packagesDir, name);
    fs.rmSync(target, { recursive: true, force: true });
    copyFolder(staging, target);

    const manifest = readManifest(project) || { name: path.basename(project), version: '1.0.0' };
    manifest.dependencies = manifest.dependencies || {};
    manifest.dependencies[name] = where.kind === 'folder' ? path.relative(project, where.from).replace(/\\/g, '/') || '.' : (where.short || where.from);
    writeManifest(project, manifest);
    if (!quiet) {
      say(`Installed '${name}' into ${PACKAGES}/${name}`);
      say(`Use it with:  import "${name}"`);
    }
    return name;
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function cmdAdd(source) {
  if (!source) stop('Which package? Try: volt add owner/repo', 'Or a folder: volt add ../my-library');
  installOne(source, projectDir(process.cwd()));
}

function cmdRemove(name) {
  if (!name) stop('Which package? Try: volt remove shapes');
  const project = projectDir(process.cwd());
  const dir = path.join(project, PACKAGES, name);
  if (!fs.existsSync(dir)) stop(`'${name}' is not installed here.`, `See what is, with: volt list`);
  fs.rmSync(dir, { recursive: true, force: true });
  const manifest = readManifest(project);
  if (manifest && manifest.dependencies) {
    delete manifest.dependencies[name];
    writeManifest(project, manifest);
  }
  say(`Removed '${name}'.`);
}

function cmdInstall() {
  const project = projectDir(process.cwd());
  const manifest = readManifest(project);
  if (!manifest || !manifest.dependencies || !Object.keys(manifest.dependencies).length) {
    say(`Nothing to install: ${MANIFEST} lists no packages.`);
    return;
  }
  for (const [name, source] of Object.entries(manifest.dependencies)) {
    say(`Installing ${name} from ${source} ...`);
    installOne(/^[.\/]/.test(source) ? path.resolve(project, source) : source, project, { quiet: true });
  }
  say(`Installed ${Object.keys(manifest.dependencies).length} package(s).`);
}

function cmdList() {
  const project = projectDir(process.cwd());
  const packagesDir = path.join(project, PACKAGES);
  if (!fs.existsSync(packagesDir)) {
    say(`No packages installed in ${project}`);
    say('Add one with: volt add owner/repo');
    return;
  }
  const names = fs.readdirSync(packagesDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
  if (!names.length) { say('No packages installed.'); return; }
  say(`Packages in ${path.relative(process.cwd(), packagesDir) || PACKAGES}:`);
  for (const name of names) {
    const manifest = readManifest(path.join(packagesDir, name));
    const version = manifest && manifest.version ? ` ${manifest.version}` : '';
    const about = manifest && manifest.description ? ` - ${manifest.description}` : '';
    say(`  ${name}${version}${about}`);
  }
}

function cmdDocs(name) {
  const { BUILTIN_DOCS, STATEMENT_DOCS } = require(path.join(ROOT, 'lib', 'builtin-docs.js'));
  if (!name) {
    say('Built-in functions:');
    const names = Object.keys(BUILTIN_DOCS).sort();
    for (let i = 0; i < names.length; i += 6) say(`  ${names.slice(i, i + 6).join('  ')}`);
    say('\nWhat one does:  volt docs round');
    return;
  }
  const entry = BUILTIN_DOCS[name] || STATEMENT_DOCS[name];
  if (!entry) {
    const close = Object.keys({ ...BUILTIN_DOCS, ...STATEMENT_DOCS }).filter((k) => k.startsWith(name.slice(0, 3)));
    stop(`There is no built-in called '${name}'.`, close.length ? `Did you mean: ${close.join(', ')}` : 'See them all with: volt docs');
  }
  const where = { all: 'every target', script: '#python #ruby #js #html', js: '#js and #html', node: '#js run with Node', web: '#html', game: '#html games', '3d': '#html 3D games' }[entry[2]] || entry[2];
  say(`  ${entry[0]}`);
  say(`  ${entry[1]}`);
  say(`  Works in: ${where}`);
}

// ---------------------------------------------------------------------
function usage() {
  say(`Volt ${volt.VERSION}

  volt build <file.volt>     turn it into the language its first line picks
  volt run <file.volt>       build it and run it, or open the page
  volt check <file.volt>     list every mistake in it
  volt new <file.volt> [kind]  start a new program (${Object.keys(TEMPLATES).join(', ')})

  volt add <package>         install a package: owner/repo, a git address, or a folder
  volt remove <package>      take one out again
  volt list                  what this project has installed
  volt install               install everything ${MANIFEST} asks for

  volt docs [name]           what a built-in does`);
}

function main(argv) {
  const [command, ...rest] = argv;
  switch (command) {
    case 'build': return cmdBuild(rest[0]);
    case 'run': return cmdRun(rest[0]);
    case 'check': return cmdCheck(rest[0]);
    case 'new': return cmdNew(rest[0], rest[1]);
    case 'add': case 'install-package': return cmdAdd(rest[0]);
    case 'remove': case 'uninstall': return cmdRemove(rest[0]);
    case 'install': return cmdInstall();
    case 'list': return cmdList();
    case 'docs': case 'help-with': return cmdDocs(rest[0]);
    case 'version': case '--version': case '-v': return say(`Volt ${volt.VERSION}`);
    case undefined: case 'help': case '--help': case '-h': return usage();
    default:
      // 'volt game.volt' is a friendly shorthand for 'volt build game.volt'
      if (/\.volt$/i.test(command)) return cmdBuild(command);
      problem(`'${command}' isn't a Volt command.`);
      usage();
      process.exit(1);
  }
  return undefined;
}

if (require.main === module) main(process.argv.slice(2));
module.exports = { main };
