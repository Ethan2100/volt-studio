// The 2D shape layer: rounded boxes, outlines, circles and polygons.
// Checks what the compiler emits, and that the drawing really happens,
// by running the generated code against a stub canvas.
//   Run with: node test/shapes-test.js
const volt = require('../compiler/volt.js');

let failed = 0;
const check = (name, cond, extra = '') => { if (!cond) failed++; console.log(`${cond ? 'pass' : 'FAIL'}  ${name}${cond ? '' : '  ' + extra}`); };

const build = (line) => {
  try { return volt.compile(`#html\ncanvas 320, 180\n${line}\n`).code; }
  catch (e) { return 'ERROR: ' + e.message; }
};
const call = (code, fn) => (code.match(new RegExp('__' + fn + '\\((?!x,)[^;]*\\)')) || ['(no ' + fn + ' call)'])[0];

// ---------------------------------------------------------------- box
let c = build('box 1, 2, 3, 4');
check('a plain box is unchanged', call(c, 'box') === '__box(1, 2, 3, 4, "#fff")', call(c, 'box'));

c = build('box 1, 2, 3, 4 color "#f00"');
check('a coloured box is unchanged', call(c, 'box') === '__box(1, 2, 3, 4, "#f00")', call(c, 'box'));

c = build('box 1, 2, 30, 20 color "#f00" round 6');
check('rounded corners are passed', call(c, 'box') === '__box(1, 2, 30, 20, "#f00", 6)', call(c, 'box'));

c = build('box 1, 2, 30, 20 round 6 edge 2 edgecolor "#000"');
check('an outline comes with it', call(c, 'box') === '__box(1, 2, 30, 20, "#fff", 6, 2, "#000")', call(c, 'box'));

c = build('box 1, 2, 30, 20 edge 2');
check('an outline works without rounding', call(c, 'box') === '__box(1, 2, 30, 20, "#fff", 0, 2)', call(c, 'box'));

c = build('box 1, 2, 30, 20 round 6 color "#f00"');
check('the options can come in any order', /__box\(1, 2, 30, 20, "#f00", 6\)/.test(c), call(c, 'box'));

// ------------------------------------------------------------- circle
c = build('circle 50, 60, 20');
check('a circle needs only a middle and a radius', call(c, 'circle') === '__circle(50, 60, 20, "#fff", 0, null)', call(c, 'circle'));

c = build('circle 50, 60, 20 color "#4dd2ff" edge 3 edgecolor "#102030"');
check('a circle takes a colour and an outline', call(c, 'circle') === '__circle(50, 60, 20, "#4dd2ff", 3, "#102030")', call(c, 'circle'));

// --------------------------------------------------------------- poly
c = build('poly 50, 60, 20, 6');
check('a polygon needs a middle, a size and its sides', call(c, 'poly') === '__poly(50, 60, 20, 6, "#fff", 0, 0, null)', call(c, 'poly'));

c = build('poly 50, 60, 20, 6 color "#ff0" angle 30 edge 2 edgecolor "#000"');
check('a polygon can be turned and outlined', call(c, 'poly') === '__poly(50, 60, 20, 6, "#ff0", 30, 2, "#000")', call(c, 'poly'));

// ---------------------------------------------------- values, not just numbers
c = build('let n = 7\nbox 1, 2, 3, 4 round n');
check('a variable can say how round it is', /__box\(1, 2, 3, 4, "#fff", n\)/.test(c), call(c, 'box'));

c = build('let s = 6\npoly 1, 2, 10, s');
check('a variable can say how many sides', /__poly\(1, 2, 10, s,/.test(c), call(c, 'poly'));

// ------------------------------------------------------- only in games
for (const line of ['circle 1, 2, 3', 'poly 1, 2, 3, 4']) {
  const name = line.split(' ')[0];
  try {
    volt.compile(`#python\n${line}\n`);
    check(`${name} is refused where there is no screen`, false, 'it compiled');
  } catch (e) {
    check(`${name} is refused where there is no screen`, /game/i.test(e.message), e.message);
  }
}

// ------------------------------------------- nothing is dragged in unasked
c = volt.compile('#js\nprint "x"\n').code;
check('a plain script gets no shape code', !/__circle|__poly|__roundPath/.test(c));

c = build('box 1, 2, 3, 4');
check('a plain box still brings the drawing code along', /function __box/.test(c));

// ----------------------------------------------------------- it really draws
// A stub canvas that writes down what it was asked to do.
function run(line) {
  const code = build(line);
  const did = [];
  const ctx = {
    fillStyle: '', strokeStyle: '', lineWidth: 0,
    fillRect: (...a) => did.push(['fillRect', ...a]),
    rect: (...a) => did.push(['rect', ...a]),
    arc: (...a) => did.push(['arc', ...a]),
    moveTo: (...a) => did.push(['moveTo', ...a]),
    lineTo: (...a) => did.push(['lineTo', ...a]),
    arcTo: (...a) => did.push(['arcTo', ...a]),
    beginPath: () => did.push(['beginPath']),
    closePath: () => did.push(['closePath']),
    fill: function () { did.push(['fill', ctx.fillStyle]); },
    stroke: function () { did.push(['stroke', ctx.strokeStyle, ctx.lineWidth]); },
    clearRect: () => {}, save: () => {}, restore: () => {}, translate: () => {},
    scale: () => {}, setTransform: () => {}, drawImage: () => {}, measureText: () => ({ width: 0 }),
  };
  // pull the shape helpers out of the generated program and drive them directly
  const body = code;
  const want = ['__box', '__circle', '__poly', '__roundPath', '__edge'];
  const defs = want
    .map((n) => (body.match(new RegExp('^function ' + n + '\\([\\s\\S]*?\\n}', 'm')) || [''])[0])
    .filter(Boolean).join('\n');
  const fn = new Function('__cx', 'ctxOut', `
    let __camX = 0, __camY = 0;
    function __need() {}
    ${defs}
    return { __box, __circle, __poly };
  `);
  return { api: fn(ctx), did, ctx };
}

let { api, did } = run('box 0, 0, 1, 1');
api.__box(10, 20, 30, 40, '#abc');
check('a plain box is one fillRect', did.length === 1 && did[0][0] === 'fillRect' && did[0][3] === 30, JSON.stringify(did));

({ api, did } = run('box 0, 0, 1, 1 round 4'));
api.__box(0, 0, 40, 20, '#abc', 6);
check('a rounded box draws a path and fills it', did.some((d) => d[0] === 'arcTo') && did.some((d) => d[0] === 'fill'), JSON.stringify(did.map((d) => d[0])));

({ api, did } = run('box 0, 0, 1, 1 round 4'));
api.__box(0, 0, 10, 10, '#abc', 999);
check('the corners never round past half the box', did.filter((d) => d[0] === 'arcTo').length === 4, 'it should still be four corners');

({ api, did } = run('box 0, 0, 1, 1 edge 1'));
api.__box(0, 0, 40, 20, null, 0, 3, '#123');
check('an outline with no fill only strokes', !did.some((d) => d[0] === 'fill') && did.some((d) => d[0] === 'stroke' && d[1] === '#123' && d[2] === 3), JSON.stringify(did));

({ api, did } = run('circle 0, 0, 1'));
api.__circle(50, 60, 20, '#4dd2ff', 2, '#000');
check('a circle is one arc, filled and stroked', did.some((d) => d[0] === 'arc' && d[3] === 20) && did.some((d) => d[0] === 'fill') && did.some((d) => d[0] === 'stroke'), JSON.stringify(did.map((d) => d[0])));

({ api, did } = run('poly 0, 0, 1, 3'));
api.__poly(50, 60, 20, 6, '#ff0', 0, 0, null);
check('a six-sided shape has six corners', did.filter((d) => d[0] === 'moveTo' || d[0] === 'lineTo').length === 6, JSON.stringify(did.map((d) => d[0])));

({ api, did } = run('poly 0, 0, 1, 3'));
api.__poly(50, 60, 20, 2, '#ff0', 0, 0, null);
check('fewer than three sides is still a triangle', did.filter((d) => d[0] === 'moveTo' || d[0] === 'lineTo').length === 3);

({ api, did } = run('poly 0, 0, 1, 3'));
api.__poly(0, 0, 10, 4, '#ff0', 0, 0, null);
const first = did.find((d) => d[0] === 'moveTo');
check('with no turn the first corner points straight up', Math.round(first[1]) === 0 && Math.round(first[2]) === -10, JSON.stringify(first));

({ api, did } = run('box 0, 0, 1, 1'));
api.__box(10, 20, 30, 40, '#abc', 0, 0, null);
check('a box with the options turned off is still a plain fillRect', did.length === 1 && did[0][0] === 'fillRect');

process.exitCode = failed ? 1 : 0;
