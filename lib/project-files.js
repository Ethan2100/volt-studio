// Guarded helpers for project-relative Volt source files.
const fs = require('fs');
const path = require('path');

const MANIFEST = 'volt.project.json';
const MAX_SOURCE_BYTES = 2 * 1024 * 1024;
const SKIP_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', 'out']);

function rootPath(root) {
  if (typeof root !== 'string' || !root) throw new Error('Choose a project folder first.');
  const real = fs.realpathSync(root);
  if (!fs.statSync(real).isDirectory()) throw new Error('The project folder is unavailable.');
  return real;
}
function isInside(root, target) {
  const rel = path.relative(root, target);
  return rel === '' || (!path.isAbsolute(rel) && rel !== '..' && !rel.startsWith('..' + path.sep));
}
function relativePath(value) {
  if (typeof value !== 'string' || !value.trim()) throw new Error('A project-relative file path is required.');
  const portable = value.replace(/\\/g, '/');
  if (portable.startsWith('/') || /^[a-z]:/i.test(portable)) throw new Error('Project files must use a relative path.');
  const parts = portable.split('/');
  if (parts.some((part) => !part || part === '.' || part === '..')) throw new Error('That project path is not allowed.');
  if (!/\.volt$/i.test(parts[parts.length - 1])) throw new Error('Only Volt source files can be opened here.');
  return parts.join(path.sep);
}
function filePath(root, relative, mustExist = true) {
  const base = rootPath(root), full = path.resolve(base, relativePath(relative));
  if (!isInside(base, full)) throw new Error('That project path is outside the project folder.');
  if (fs.existsSync(full)) {
    const actual = fs.realpathSync(full);
    if (!isInside(base, actual) || !fs.statSync(actual).isFile()) throw new Error('That project file is unavailable.');
    if (mustExist) return actual;
  } else if (mustExist) throw new Error('That project file is unavailable.');
  let parent = path.dirname(full);
  while (!fs.existsSync(parent) && isInside(base, parent)) parent = path.dirname(parent);
  if (!isInside(base, fs.realpathSync(parent))) throw new Error('That project path is outside the project folder.');
  return full;
}
function listVoltFiles(root) {
  const base = rootPath(root), files = [];
  function walk(dir) {
    for (const item of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (item.name.startsWith('.') || (item.isDirectory() && SKIP_DIRS.has(item.name.toLowerCase()))) continue;
      const full = path.join(dir, item.name);
      if (item.isDirectory()) walk(full);
      else if (item.isFile() && item.name.toLowerCase().endsWith('.volt')) {
        files.push(path.relative(base, full).split(path.sep).join('/'));
        if (files.length >= 1000) return;
      }
    }
  }
  walk(base); return files;
}
function readVoltFile(root, relative) {
  const content = fs.readFileSync(filePath(root, relative), 'utf8');
  if (Buffer.byteLength(content, 'utf8') > MAX_SOURCE_BYTES) throw new Error('That Volt file is too large to open in the editor.');
  return content;
}
function writeVoltFile(root, relative, content, createOnly = false) {
  if (typeof content !== 'string' || Buffer.byteLength(content, 'utf8') > MAX_SOURCE_BYTES) throw new Error('Volt source must be under 2 MB.');
  const full = filePath(root, relative, false);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  const base = rootPath(root);
  if (!isInside(base, fs.realpathSync(path.dirname(full)))) throw new Error('That project path is outside the project folder.');
  if (createOnly && fs.existsSync(full)) return { created: false, content: readVoltFile(root, relative) };
  fs.writeFileSync(full, content, createOnly ? { encoding: 'utf8', flag: 'wx' } : 'utf8');
  return { created: true, content };
}
function readProjectManifest(root) {
  const base = rootPath(root), manifestPath = path.join(base, MANIFEST);
  if (!fs.existsSync(manifestPath)) return null;
  const data = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!data || typeof data !== 'object' || typeof data.entry !== 'string') throw new Error(`${MANIFEST} must name an entry .volt file.`);
  const entry = relativePath(data.entry).split(path.sep).join('/');
  readVoltFile(base, entry);
  return { name: String(data.name || path.basename(base)), entry, version: Number(data.version) || 1 };
}
function openProject(root) {
  const base = rootPath(root), manifest = readProjectManifest(base), files = listVoltFiles(base);
  let entry = manifest && manifest.entry;
  if (!entry) {
    const rootFiles = files.filter((f) => !f.includes('/'));
    entry = rootFiles.find((f) => /^main\.volt$/i.test(f)) || rootFiles.find((f) => path.basename(f, '.volt').toLowerCase() === path.basename(base).toLowerCase());
    if (!entry && files.length === 1) entry = files[0];
  }
  return { root: base, manifest, entry, files };
}

module.exports = { MANIFEST, rootPath, relativePath, listVoltFiles, readVoltFile, writeVoltFile, readProjectManifest, openProject };
