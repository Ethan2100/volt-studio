#!/usr/bin/env node
// =====================================================================
//  Turn the #minecraft output into a datapack folder you can drop into
//  a world.
//
//    node make-datapack.js countdown/countdown.mcfunction [outDir]
//
//  The compiler emits one text file holding two functions, because a
//  compile target returns a single string. This splits them back out
//  and writes the folder around them.
//
//  A datapack can be a plain folder - no zipping needed. Put the result
//  in  <your world>/datapacks/  then, in game:
//
//    /reload
//    /function volt:setup          - load the program
//    /function volt:tick           - run one instruction
//
//  To let it run by itself, put  function volt:tick  in a repeating
//  command block, or  /schedule function volt:tick 1t replace.
// =====================================================================

const fs = require('fs');
const path = require('path');

const PACK_FORMAT = 48;   // 1.21.x - edit if your version complains

function split(text) {
  const out = {};
  let cur = null;
  for (const line of text.split('\n')) {
    const m = line.match(/^#===\s*(\S+):(\w+)\s*===$/);
    if (m) { out.ns = m[1]; cur = m[2]; out[cur] = []; continue; }
    if (cur) out[cur].push(line);
  }
  if (!out.setup || !out.tick) {
    throw new Error('That file has no setup/tick sections - is it output from the #minecraft target?');
  }
  return out;
}

function main() {
  const src = process.argv[2];
  if (!src) {
    console.error('usage: node make-datapack.js <file.mcfunction> [outDir]');
    process.exit(1);
  }
  const parts = split(fs.readFileSync(src, 'utf8'));
  const ns = parts.ns || 'volt';
  const outDir = process.argv[3] || path.join(path.dirname(src), `${ns}-datapack`);

  // 1.21 renamed the folder from "functions" to "function". Writing both
  // costs nothing and means the pack loads either way.
  for (const dir of ['function', 'functions']) {
    const d = path.join(outDir, 'data', ns, dir);
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, 'setup.mcfunction'), parts.setup.join('\n') + '\n');
    fs.writeFileSync(path.join(d, 'tick.mcfunction'), parts.tick.join('\n') + '\n');
  }

  fs.writeFileSync(path.join(outDir, 'pack.mcmeta'), JSON.stringify({
    pack: {
      pack_format: PACK_FORMAT,
      description: `Compiled from Volt - run ${ns}:setup, then ${ns}:tick`,
    },
  }, null, 2) + '\n');

  fs.writeFileSync(path.join(outDir, 'README.txt'), [
    `Compiled from Volt by the #minecraft target.`,
    ``,
    `Put this folder in:  <your world>/datapacks/`,
    `Then in game:`,
    `  /reload`,
    `  /function ${ns}:setup      load the program`,
    `  /function ${ns}:tick       run one instruction`,
    ``,
    `To run it continuously, put this in a repeating command block:`,
    `  function ${ns}:tick`,
    `or run:  /schedule function ${ns}:tick 1t replace`,
    ``,
    `Watch it work:  /scoreboard objectives setdisplay sidebar volt`,
    ``,
    `If the pack does not load, your Minecraft wants a different`,
    `pack_format - change it in pack.mcmeta (this was built for ${PACK_FORMAT}).`,
  ].join('\n') + '\n');

  console.log(`datapack written to ${outDir}`);
  console.log(`  /function ${ns}:setup  then  /function ${ns}:tick`);
}

main();
