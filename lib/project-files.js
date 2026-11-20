// Guarded helpers for project-relative Volt source files.
const fs = require('fs');
const path = require('path');

const MANIFEST = 'volt.project.json';
const MAX_SOURCE_BYTES = 2 * 1024 * 1024;
const MAX_ASSET_BYTES = 100 * 1024 * 1024;
const MAX_ASSET_PREVIEW_BYTES = 20 * 1024 * 1024;
const SKIP_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', 'out']);
const ASSET_TYPES = {
  '.glb': { category: 'Models', label: 'GLB model', mime: 'model/gltf-binary', supported: true },
  '.png': { category: 'Textures', label: 'PNG image', mime: 'image/png', supported: true },
  '.jpg': { category: 'Textures', label: 'JPEG image', mime: 'image/jpeg', supported: true },
  '.jpeg': { category: 'Textures', label: 'JPEG image', mime: 'image/jpeg', supported: true },
  '.gif': { category: 'Textures', label: 'GIF image', mime: 'image/gif', supported: true },
  '.webp': { category: 'Textures', label: 'WebP image', mime: 'image/webp', supported: true },
  '.svg': { category: 'Textures', label: 'SVG image', mime: 'image/svg+xml', supported: true },
  '.wav': { category: 'Audio', label: 'WAV audio', mime: 'audio/wav', supported: true },
  '.mp3': { category: 'Audio', label: 'MP3 audio', mime: 'audio/mpeg', supported: true },
  '.ogg': { category: 'Audio', label: 'Ogg audio', mime: 'audio/ogg', supported: true },
  '.m4a': { category: 'Audio', label: 'M4A audio', mime: 'audio/mp4', supported: true },
  '.gltf': { category: 'Unsupported', label: 'glTF scene', supported: false, reason: 'Volt currently loads self-contained .glb models. Convert this scene to a .glb with textures packed inside.' },
  '.obj': { category: 'Unsupported', label: 'Wavefront OBJ', supported: false, reason: 'OBJ import is not available yet. Convert the model to .glb with textures packed inside.' },
  '.fbx': { category: 'Unsupported', label: 'FBX scene', supported: false, reason: 'FBX import is not available yet. Convert the model to .glb with textures packed inside.' },
};

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

function assetRelativePath(value) {
  if (typeof value !== 'string' || !value.trim()) throw new Error('A project-relative asset path is required.');
  const portable = value.replace(/\\/g, '/');
  if (portable.startsWith('/') || /^[a-z]:/i.test(portable)) throw new Error('Project assets must use a relative path.');
  const parts = portable.split('/');
  if (parts.some((part) => !part || part === '.' || part === '..')) throw new Error('That project path is not allowed.');
  if (parts.some((part) => part.startsWith('.') || SKIP_DIRS.has(part.toLowerCase()))) throw new Error('Hidden and generated folders are not available in the Asset Browser.');
  return parts.join(path.sep);
}
function assetPath(root, relative, mustExist = true) {
  const base = rootPath(root), full = path.resolve(base, assetRelativePath(relative));
  if (!isInside(base, full)) throw new Error('That project path is outside the project folder.');
  if (fs.existsSync(full)) {
    const actual = fs.realpathSync(full);
    if (!isInside(base, actual) || !fs.statSync(actual).isFile()) throw new Error('That project asset is unavailable.');
    return actual;
  }
  if (mustExist) throw new Error('That project asset is unavailable.');
  let parent = path.dirname(full);
  while (!fs.existsSync(parent) && isInside(base, parent)) parent = path.dirname(parent);
  if (!isInside(base, fs.realpathSync(parent))) throw new Error('That project path is outside the project folder.');
  return full;
}
function assetType(file) { return ASSET_TYPES[path.extname(file).toLowerCase()] || null; }
function listProjectAssets(root) {
  const base = rootPath(root), files = [];
  function walk(dir) {
    if (files.length >= 2000) return;
    for (const item of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (item.name.startsWith('.') || (item.isDirectory() && SKIP_DIRS.has(item.name.toLowerCase()))) continue;
      const full = path.join(dir, item.name);
      if (item.isDirectory()) walk(full);
      else if (item.isFile()) {
        const type = assetType(item.name);
        if (!type) continue;
        const stat = fs.statSync(full);
        files.push({ file: path.relative(base, full).split(path.sep).join('/'), name: item.name, extension: path.extname(item.name).toLowerCase(), category: type.category, label: type.label, supported: type.supported, reason: type.reason || '', size: stat.size });
        if (files.length >= 2000) return;
      }
    }
  }
  walk(base); return files;
}
function readProjectAsset(root, relative) {
  const full = assetPath(root, relative), type = assetType(full);
  if (!type || !type.supported) throw new Error(type?.reason || `Unsupported asset format: ${path.extname(full) || '(no extension)'}.`);
  const stat = fs.statSync(full);
  if (stat.size > MAX_ASSET_PREVIEW_BYTES) throw new Error('This file is too large for an in-editor preview (20 MB maximum).');
  return `data:${type.mime};base64,${fs.readFileSync(full).toString('base64')}`;
}
function importProjectAssets(root, sourcePaths) {
  const base = rootPath(root);
  if (!Array.isArray(sourcePaths) || !sourcePaths.length) return [];
  if (sourcePaths.length > 100) throw new Error('Import up to 100 assets at a time.');
  const sources = sourcePaths.map((src) => {
    const full = fs.realpathSync(src), stat = fs.statSync(full), type = assetType(full);
    if (!stat.isFile()) throw new Error(`Not a file: ${path.basename(src)}`);
    if (!type || !type.supported) throw new Error(type?.reason || `Unsupported asset format: ${path.extname(full) || '(no extension)'}.`);
    if (stat.size > MAX_ASSET_BYTES) throw new Error(`${path.basename(full)} is larger than the 100 MB per-file limit.`);
    return { full, name: path.basename(full), size: stat.size };
  });
  if (sources.reduce((sum, item) => sum + item.size, 0) > 250 * 1024 * 1024) throw new Error('Import batches are limited to 250 MB total.');
  const folder = path.join(base, 'Assets');
  fs.mkdirSync(folder, { recursive: true });
  if (!isInside(base, fs.realpathSync(folder))) throw new Error('The Assets folder resolves outside this project.');
  const result = [];
  for (const item of sources) {
    const ext = path.extname(item.name), stem = path.basename(item.name, ext);
    let target = path.join(folder, item.name), suffix = 2;
    while (fs.existsSync(target)) target = path.join(folder, `${stem}_${suffix++}${ext}`);
    fs.copyFileSync(item.full, target, fs.constants.COPYFILE_EXCL);
    const type = assetType(target);
    result.push({ file: path.relative(base, target).split(path.sep).join('/'), name: path.basename(target), extension: ext.toLowerCase(), category: type.category, label: type.label, supported: true, reason: '', size: item.size });
  }
  return result;
}

module.exports = { MANIFEST, ASSET_TYPES, rootPath, relativePath, listVoltFiles, readVoltFile, writeVoltFile, readProjectManifest, openProject, listProjectAssets, readProjectAsset, importProjectAssets };
