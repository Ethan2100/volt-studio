// Checks lists, for each, part and sign by compiling one program to every script
// language and running it. Run with: node test/lists-test.js
// (Skips a language whose interpreter isn't installed.)
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');

const program = `
let scores = [3, 1, 4]
add 1 to scores
add 5 to scores
scores[0] = 9
scores[1] += 10
remove scores[2]
let total = 0
for each s in scores {
  total += s
}
print "length " + length(scores)
print "total " + total
print "first " + scores[0]
print "has 5 " + contains(scores, 5)
let rows = ["#..#", "#.k#"]
print "tile " + rows[1][2]
print "part " + part("dungeon", 1, 3)
print "sign " + sign(-7) + sign(0) + sign(12)
let names = []
add "knight" to names
add "elf" to names
for each n in names {
  if n == "elf" {
    break
  }
  print n
}
let i = 0
while i < length(names) {
  print i + ":" + names[i]
  i += 1
}
`;
const expected = [
  'length 4', 'total 26', 'first 9', 'has 5 true', 'tile k', 'part ung', 'sign -101',
  'knight', '0:knight', '1:elf',
].join('\n');

const runners = {
  js: ['node'],
  python: ['python3', 'python'],
  ruby: ['ruby'],
};
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-lists-'));
let failed = 0;
for (const [target, cmds] of Object.entries(runners)) {
  const src = `#${target}\n${program}`;
  const { code } = volt.compile(src);
  const file = path.join(dir, `t.${target === 'python' ? 'py' : target === 'ruby' ? 'rb' : 'js'}`);
  fs.writeFileSync(file, code);
  let out = null;
  for (const cmd of cmds) {
    try { out = execFileSync(cmd, [file], { encoding: 'utf8' }).trim(); break; } catch (e) { if (e.code !== 'ENOENT') { out = String(e.stdout) + String(e.stderr); break; } }
  }
  if (out === null) { console.log(`skip  ${target} (not installed)`); continue; }
  const ok = out === expected;
  if (!ok) failed++;
  console.log(`${ok ? 'pass' : 'FAIL'}  ${target}${ok ? '' : `\n${out}`}`);
}

// Things that must be refused, with a helpful message
const errors = [
  ['#c++\nlet a = [1, 2]\n', 'Lists work in'],
  ['#python\ncanvas 320, 180\n', 'only works in #html'],
  ['#html\nimage tiles = "missing.png"\n', "Can't find the image"],
  ['#html\nsprite hero = tiles at 0, 0 size 16, 16\n', "no image called 'tiles'"],
  ['#html\ncanvas 10, 10\ndraw ghost at 0, 0\n', "no sprite called 'ghost'"],
  ['#js\nevery frame { }\n', "'every frame' is for #html"],
  ['#c++\ntone 440 for 100ms\n', 'needs the buzzer'],
  ['#python\nsave "best", 3\n', 'only works in #html'],
  ['#js\nmusic "c4 e4", "c2" tempo 120\n', 'only works in #html'],
];
for (const [src, msg] of errors) {
  try {
    volt.compile(src, { baseDir: dir });
    failed++; console.log(`FAIL  no error for: ${src.split('\n')[1]}`);
  } catch (e) {
    const ok = e.message.includes(msg);
    if (!ok) failed++;
    console.log(`${ok ? 'pass' : 'FAIL'}  error: ${e.message}`);
  }
}

// Old programs that use the new command words as names still compile
for (const src of ['#html\nlet best = saved("best", 0)\nsave "best", best + 1\nlet song = "c5 e5 g5 _ - e5"\nmusic song, "c3 - g2 -" tempo 150\nmusic off\nlet save = 4\nsave += 1\n', '#js\nlet box = 2\nbox += 1\nprint box\n', '#python\nfn draw(n) { return n }\nprint draw(3)\n', '#c++\npin buzzer = 8\ntone buzzer 440 for 100ms\n']) {
  try { volt.compile(src); console.log('pass  still compiles: ' + src.split('\n')[1]); } catch (e) { failed++; console.log('FAIL  ' + e.message); }
}
process.exitCode = failed ? 1 : 0;
