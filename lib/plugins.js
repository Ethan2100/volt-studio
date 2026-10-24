// =====================================================================
//  Plugins / addons for Volt Studio.
//
//  A plugin is a folder with a plugin.json manifest, in one of two
//  places:
//    <app>/plugins/<name>/          - bundled with Volt Studio (examples)
//    <userData>/plugins/<name>/     - installed by the user (just a folder
//                                      drop - no build step, no install UI
//                                      needed beyond "put it here")
//
//  Three manifest "type"s are supported, one per plugin folder:
//
//  "library" - a package of reusable Volt code snippets, shown in the
//    Library tab. manifest.snippets is a list of { file, label, description }.
//
//  "panel" - a sandboxed UI panel shown as a new bottom tab. Runs in an
//    <iframe sandbox="allow-scripts">, loaded from the plugin's own HTML
//    file, with NO access to Node, Electron, or the rest of the app - only
//    postMessage. manifest.panel = { entry, title }.
//
//  "target" - a new compile target (a new first line like "#rust"),
//    implemented against Volt's real lexer/parser via compiler/volt.js's
//    registerTarget(). manifest.target = { entry, id, label, file }, where
//    entry is a CommonJS module exporting { generate(ast) }.
//
//  See docs/PLUGINS.md for the full manifest schema and examples.
// =====================================================================

const fs = require('fs');
const path = require('path');

const VALID_TYPES = new Set(['library', 'panel', 'target']);

function readManifest(dir) {
  const manifestPath = path.join(dir, 'plugin.json');
  if (!fs.existsSync(manifestPath)) return null;
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (e) {
    return { error: `plugin.json is not valid JSON: ${e.message}` };
  }
  if (!manifest.name) return { error: 'plugin.json needs a "name"' };
  if (!VALID_TYPES.has(manifest.type)) {
    return { error: `plugin.json "type" must be one of: ${[...VALID_TYPES].join(', ')} (got ${JSON.stringify(manifest.type)})` };
  }
  return manifest;
}

// Scans one directory of plugin folders (non-recursive, one level).
function scanDir(dir, source) {
  const found = [];
  if (!fs.existsSync(dir)) return found;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const pluginDir = path.join(dir, entry.name);
    const manifest = readManifest(pluginDir);
    if (!manifest) continue; // no plugin.json here, not a plugin folder
    if (manifest.error) {
      found.push({ id: entry.name, dir: pluginDir, source, broken: true, error: manifest.error });
      continue;
    }
    found.push({ id: manifest.name, dir: pluginDir, source, manifest });
  }
  return found;
}

// bundledDir: <app>/plugins (read-only examples shipped with Volt Studio)
// userDir: <userData>/plugins (anything the user drops in)
function scanPlugins(bundledDir, userDir) {
  const bundled = scanDir(bundledDir, 'bundled');
  const user = scanDir(userDir, 'user');
  // A user plugin with the same name as a bundled one replaces it (lets
  // someone fork/customize an example without editing the app's own files).
  const byName = new Map();
  for (const p of bundled) byName.set(p.id, p);
  for (const p of user) byName.set(p.id, p);
  return [...byName.values()];
}

// Reads a file belonging to a plugin, refusing anything that escapes the
// plugin's own folder (no "../../../etc/passwd" from a manifest or a
// malicious relative path).
function readPluginFile(pluginDir, relPath) {
  const resolved = path.resolve(pluginDir, relPath);
  const base = path.resolve(pluginDir) + path.sep;
  if (!resolved.startsWith(base)) {
    throw new Error(`Refusing to read '${relPath}': it points outside the plugin's own folder`);
  }
  return fs.readFileSync(resolved, 'utf8');
}

// Loads every "target" plugin into the given volt compiler module, so
// their first-line word (e.g. "#rust") is recognized by compile(). Call
// this once at startup. Errors in one target plugin are reported but
// don't stop the others or the app from loading.
function loadTargetPlugins(plugins, volt, log) {
  for (const p of plugins) {
    if (p.broken || !p.manifest || p.manifest.type !== 'target') continue;
    try {
      const t = p.manifest.target || {};
      if (!t.entry || !t.id) throw new Error('manifest.target needs "entry" and "id"');
      const modPath = path.resolve(p.dir, t.entry);
      delete require.cache[require.resolve(modPath)]; // pick up edits across reloads
      const mod = require(modPath);
      if (typeof mod.generate !== 'function') throw new Error(`${t.entry} must export a generate(ast) function`);
      volt.registerTarget(t.id, {
        label: t.label || p.manifest.name,
        board: !!t.board,
        file: t.fileExt ? (n) => `${n}.${t.fileExt}` : undefined,
        generate: mod.generate,
      });
      log && log(`Loaded target addon: #${t.id} (${p.manifest.name})`, 'info');
    } catch (e) {
      log && log(`Target addon '${p.id}' failed to load: ${e.message}`, 'error');
    }
  }
}

module.exports = { scanPlugins, readPluginFile, loadTargetPlugins, VALID_TYPES };
