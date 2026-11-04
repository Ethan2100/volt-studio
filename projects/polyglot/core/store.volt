// =====================================================================
// POLYGLOT - store.volt  (persistence)
// Volt has no storage statement, so this module is the ONLY place that
// touches the browser's localStorage. Everything else in the app saves
// and loads through kvGet / kvSet / kvDel / kvKeys, as plain strings.
// Keys are namespaced "pg:" so Polyglot never touches other apps' data.
//
// If the browser blocks storage (private mode, full disk), writes return
// 0 and storageOk() reports it, so the UI can warn instead of silently
// losing progress.
// =====================================================================

let storeFailed = 0

fn kvGet(key, fallback) {
  # try { const v = localStorage.getItem('pg:' + key); return v === null ? fallback : v; } catch (e) { return fallback; }
}

fn kvSet(key, value) {
  # try { localStorage.setItem('pg:' + key, String(value)); return 1; } catch (e) { storeFailed = 1; return 0; }
}

fn kvDel(key) {
  # try { localStorage.removeItem('pg:' + key); } catch (e) { }
}

// Every key (without the "pg:" prefix) that starts with `prefix`.
fn kvKeys(prefix) {
  # try { return Object.keys(localStorage).filter((k) => k.indexOf('pg:' + prefix) === 0).map((k) => k.slice(3)); } catch (e) { return []; }
}

fn storageOk() {
  return 1 - storeFailed
}

fn kvNum(key, fallback) {
  let raw = kvGet(key, "")
  if raw == "" {
    return fallback
  }
  return number(raw)
}

fn kvAdd(key, amount) {
  kvSet(key, kvNum(key, 0) + amount)
}

// Wipes ALL Polyglot data (used by Settings -> Reset, after confirmation).
fn kvWipe() {
  # try { Object.keys(localStorage).filter((k) => k.indexOf('pg:') === 0).forEach((k) => localStorage.removeItem(k)); } catch (e) { }
}

// ---- backup: export and import --------------------------------------------------
// The backup is one JSON object: { "polyglot": 1, "data": { key: value, ... } }.
fn kvExport() {
  # try { const data = {}; Object.keys(localStorage).filter((k) => k.indexOf('pg:') === 0).forEach((k) => { data[k.slice(3)] = localStorage.getItem(k); }); return JSON.stringify({ polyglot: 1, exported: new Date().toISOString(), data: data }, null, 1); } catch (e) { return ''; }
}

// Saves text as a file download (browser only).
fn downloadText(fileName, content) {
  # const b = new Blob([content], { type: 'application/json' }); const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = fileName; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

// Checks a backup and, only if it is completely valid, replaces all data with it.
// Returns "" on success or a message explaining what is wrong. Nothing is
// changed unless the whole file passes.
fn kvImport(raw) {
  # let obj; try { obj = JSON.parse(raw); } catch (e) { return 'That file is not valid JSON, so it is not a Polyglot backup.'; }
  # if (!obj || obj.polyglot !== 1 || !obj.data || typeof obj.data !== 'object' || Array.isArray(obj.data)) { return 'That file is not a Polyglot backup.'; }
  # const keys = Object.keys(obj.data);
  # if (keys.length > 5000) { return 'That backup is too large to be a Polyglot backup.'; }
  # for (const k of keys) { if (k.length > 120 || typeof obj.data[k] !== 'string' || obj.data[k].length > 30000) { return 'That backup contains data Polyglot does not recognise.'; } }
  # try { Object.keys(localStorage).filter((k) => k.indexOf('pg:') === 0).forEach((k) => localStorage.removeItem(k)); keys.forEach((k) => localStorage.setItem('pg:' + k, obj.data[k])); } catch (e) { storeFailed = 1; return 'The browser would not let Polyglot save the backup (storage may be full or blocked).'; }
  # return '';
}
