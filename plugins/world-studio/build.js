#!/usr/bin/env node
// Builds index.html - the single file Volt Studio actually loads.
//
// The panel runs in a sandboxed iframe, so every script it needs must be
// inlined. In particular game-panel.js must be bundled here: otherwise the
// Game authoring dock and its hello/getGameData handshake never run in the
// packaged app, even though the host-side database bridge exists.
//
//   node build.js        (run it again after editing panel source)
const fs = require('fs');
const path = require('path');
const read = (f) => fs.readFileSync(path.join(__dirname, 'src', f), 'utf8');
const readPanel = (f) => fs.readFileSync(path.join(__dirname, f), 'utf8');
// A literal "</script" inside inlined code would end the tag early.
const safe = (js) => js.replace(/<\/script/gi, '<\\/script');
const html = read('shell.html')
  .replace('/*THREE*/', () => safe(read('three.min.js')))
  .replace('/*STUDIO*/', () => safe(read('studio.js')))
  // Load after studio.js: the Game panel attaches to its toolbar and
  // consumes window.__worldStudio plus the host's postMessage bridge.
  .replace('</body>', '<script>/*GAME_PANEL*/</script>\\n</body>')
  .replace('/*GAME_PANEL*/', () => safe(readPanel('game-panel.js')));
fs.writeFileSync(path.join(__dirname, 'index.html'), html);
console.log('Built index.html (' + Math.round(html.length / 1024) + ' KB, including Game panel)');
