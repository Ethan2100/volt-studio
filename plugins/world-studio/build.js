#!/usr/bin/env node
// Builds index.html - the single file Volt Studio actually loads.
//
// Why: panel plugins run in <iframe sandbox="allow-scripts">, and a sandboxed
// page is not allowed to load other local files (<script src="three.min.js">
// is refused). So the editor's HTML/CSS (src/shell.html), Three.js
// (src/three.min.js) and its own code (src/studio.js) are inlined together.
//
//   node build.js        (run it again after editing anything in src/)
const fs = require('fs');
const path = require('path');
const read = (f) => fs.readFileSync(path.join(__dirname, 'src', f), 'utf8');
// a literal "</script" inside inlined code would end the tag early
const safe = (js) => js.replace(/<\/script/gi, '<\\/script');
const html = read('shell.html')
  .replace('/*THREE*/', () => safe(read('three.min.js')))
  .replace('/*STUDIO*/', () => safe(read('studio.js')));
fs.writeFileSync(path.join(__dirname, 'index.html'), html);
console.log('Built index.html (' + Math.round(html.length / 1024) + ' KB)');
