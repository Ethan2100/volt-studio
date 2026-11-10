// ---- Volt game input, part 2: mouse and gamepad. Only added to pages that use these. ----
// mousex() mousey()   where the pointer is, in game pixels (it follows 'camera', like drawing does)
// mousedown()         true while the button (or a finger) is down      clicked() true once per press
let __mx = 0, __my = 0, __mb = false, __mclk = false;
function __mouseAt(e) {
  if (!__cv) return;
  const r = __cv.getBoundingClientRect();
  if (!r.width || !r.height) return;
  __mx = (e.clientX - r.left) * __W / r.width; __my = (e.clientY - r.top) * __H / r.height;
}
document.addEventListener('pointermove', __mouseAt);
document.addEventListener('pointerdown', (e) => { __mouseAt(e); if (e.button === 0) { __mb = true; __mclk = true; } });
document.addEventListener('pointerup', (e) => { if (e.button === 0) __mb = false; });
window.addEventListener('blur', () => { __mb = false; });
function __mousex() { return Math.round(__mx) + __camX; }
function __mousey() { return Math.round(__my) + __camY; }
function __mousedown() { return __mb; }
function __clicked() { const v = __mclk; __mclk = false; return v; }
// pad("a")   true while that gamepad button is held: a b x y lb rb lt rt select start up down left right
// padx() pady()     the left stick, -100 to 100      padx2() pady2()   the right stick
const __padNames = { a: 0, b: 1, x: 2, y: 3, lb: 4, rb: 5, lt: 6, rt: 7, select: 8, back: 8, start: 9, ls: 10, rs: 11, up: 12, down: 13, left: 14, right: 15 };
function __gp() { return (navigator.getGamepads ? Array.from(navigator.getGamepads()) : []).find((g) => g && g.connected) || null; }
function __pad(name) {
  const i = __padNames[String(name).toLowerCase()];
  if (i === undefined) throw new Error("There is no gamepad button called '" + name + "'. Use one of: " + Object.keys(__padNames).join(', '));
  const g = __gp();
  return !!(g && g.buttons[i] && g.buttons[i].pressed);
}
function __stick(i) { const g = __gp(); const v = g && g.axes[i] ? g.axes[i] : 0; return Math.abs(v) < 0.15 ? 0 : Math.round(v * 100); }
function __padx() { return __stick(0); }
function __pady() { return __stick(1); }
function __padx2() { return __stick(2); }
function __pady2() { return __stick(3); }
