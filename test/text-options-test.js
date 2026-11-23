// The 2D text layer: fonts, bold and right-alignment on `write`.
// Checks what the compiler emits, since there is no canvas here.
//   Run with: node test/text-options-test.js
const volt = require('../compiler/volt.js');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

const build = (line) => {
  try { return volt.compile(`#html\ncanvas 320, 180\n${line}\n`).code; }
  catch (e) { return 'ERROR: ' + e.message; }
};
// the call site, not the runtime's definition of __write
const call = (code) => (code.match(/__write\("[^;]*\)/) || ['(no write call)'])[0];

let c = build('write "hi" at 10, 20');
check('a plain write still passes only what it needs', call(c) === '__write("hi", 10, 20)', call(c));

c = build('write "hi" at 10, 20 color "#fff" size 2 centered shadow');
check('the old options are unchanged', /__write\("hi", 10, 20, "#fff", 2, true, true\)/.test(c), call(c));

c = build('write "hi" at 10, 20 font "serif"');
check('a font is passed through', /__write\("hi", 10, 20, null, 1, false, false, "serif"\)/.test(c), call(c));

c = build('write "hi" at 10, 20 font "Georgia" bold');
check('bold comes with it', /__write\("hi", 10, 20, null, 1, false, false, "Georgia", true\)/.test(c), call(c));

c = build('write "hi" at 300, 20 right');
check('right-aligned text says so', /__write\("hi", 300, 20, null, 1, false, false, null, false, true\)/.test(c), call(c));

c = build('write "hi" at 10, 20 color "#ffd23f" font "fancy" size 2 bold centered shadow');
check('every option at once', /__write\("hi", 10, 20, "#ffd23f", 2, true, true, "fancy", true\)/.test(c), call(c));

// the runtime has to know what to do with them
c = build('write "hi" at 10, 20 font "serif"');
check('the runtime gets a font drawing path', /function __ftext\(/.test(c));
check('and the named families it understands', /__FONTS = \{/.test(c) && /serif:/.test(c) && /fancy:/.test(c));
check('the pixel font shifts left when right-aligned', /if \(right\) \{/.test(c));

// a font is a 2D-layer thing, like the rest of write
c = volt.compile('#js\nprint "x"\n').code;
check('a plain script does not drag the text layer in', !/__ftext/.test(c));

// and it still refuses outside a game
try {
  volt.compile('#python\nwrite "hi" at 1, 1 font "serif"\n');
  check('write is still refused where there is no screen', false, 'it compiled');
} catch (e) {
  check('write is still refused where there is no screen', /only.*game|game/i.test(e.message), e.message);
}

process.exitCode = failed ? 1 : 0;
