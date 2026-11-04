#html
// =====================================================================
// Combat VFX - anime-style combat effects for #html Volt games that use
// `canvas`. Original effects: power aura, sweeping slash, hit impact
// (with freeze-frame), critical-hit lightning strike, beam, charge orb,
// dash afterimage, speed lines and a domain-style void field.
//
// Like vfx-engine, the engine itself is raw JavaScript (any line that
// starts with "# " is copied verbatim into the page). It draws a smooth,
// glowing overlay ABOVE your pixel canvas, converts your game pixels to
// screen pixels for you, and shakes / colour-inverts the game canvas
// itself for big hits. Everything lands on window.CVFX; the fx* functions
// at the bottom are the friendly Volt-side API.
//
// Coordinates are game pixels (the same numbers you pass to `draw` and
// `box`). Styles: "cursed" (violet/cyan), "fire", "blood" (red/black),
// "void", "lightning", "gold".
//
// Typical use:
//   every frame {
//     paint "#0a0814"
//     ... draw your fighters ...
//     if powered { fxAura(px, py, 12, 24, "cursed") }
//     if not fxFrozen() { ...move things... }      // hit-stop freeze
//   }
//   when key "z" pressed { fxSlash(px + 6, py + 10, 0, 44, "cursed") }
// =====================================================================

# (function () {
#   if (window.CVFX) return;
#   var TAU = Math.PI * 2;
#   var rand = function (a, b) { return a + Math.random() * (b - a); };
#   var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
#   var easeOut = function (t) { return 1 - Math.pow(1 - t, 3); };
# 
#   // ---- colour styles: core (hottest), mid, outer (darkest), accent ----
#   var STYLES = {
#     cursed:    { core: '#eaf6ff', mid: '#7a5cff', outer: '#1a0b3d', accent: '#27e6ff', dark: true },
#     fire:      { core: '#fff6c2', mid: '#ff7a1a', outer: '#4a0a00', accent: '#ffd23f', dark: false },
#     blood:     { core: '#ffffff', mid: '#ff1f45', outer: '#14000a', accent: '#ff1f45', dark: true },
#     void:      { core: '#ffffff', mid: '#b388ff', outer: '#020008', accent: '#7ee7ff', dark: true },
#     lightning: { core: '#ffffff', mid: '#6fa0ff', outer: '#0a1440', accent: '#cfe4ff', dark: false },
#     gold:      { core: '#fffbe6', mid: '#ffc43a', outer: '#4a2a00', accent: '#fff1a8', dark: false }
#   };
#   function st(n) { return STYLES[n] || STYLES.cursed; }
# 
#   // ---- overlay canvas (transparent, sits above the game, ignores clicks) ----
#   var canvas = document.createElement('canvas');
#   canvas.id = 'cvfxCanvas';
#   canvas.style.cssText = 'position:fixed;left:0;top:0;width:100%;height:100%;pointer-events:none;z-index:50;';
#   document.body.appendChild(canvas);
#   var ctx = canvas.getContext('2d');
#   var dpr = 1, VW = 0, VH = 0;
#   function resize() {
#     dpr = Math.min(window.devicePixelRatio || 1, 2);
#     VW = window.innerWidth; VH = window.innerHeight;
#     canvas.width = Math.floor(VW * dpr); canvas.height = Math.floor(VH * dpr);
#   }
#   resize(); window.addEventListener('resize', resize);
# 
#   // ---- game-pixel -> screen-pixel mapping (follows Volt's `canvas` screen) ----
#   var view = { l: 0, t: 0, k: 1 };
#   function gameCanvas() { return (typeof __cv !== 'undefined' && __cv) ? __cv : null; }
#   function updateView() {
#     var c = gameCanvas();
#     if (c) {
#       var r = c.getBoundingClientRect();
#       view.l = r.left; view.t = r.top;
#       view.k = r.width / ((typeof __W !== 'undefined' && __W) ? __W : c.width);
#     } else { view.l = 0; view.t = 0; view.k = 1; }
#   }
#   function X(gx) { return view.l + gx * view.k; }
#   function Y(gy) { return view.t + gy * view.k; }
# 
#   // ---- cached soft-glow sprites (one per colour) ----
#   var spriteCache = {};
#   function glowSprite(color) {
#     var s = spriteCache[color];
#     if (s) return s;
#     s = document.createElement('canvas'); s.width = s.height = 64;
#     var g = s.getContext('2d');
#     var gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
#     gr.addColorStop(0, '#ffffff'); gr.addColorStop(0.25, color); gr.addColorStop(1, 'rgba(0,0,0,0)');
#     g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
#     spriteCache[color] = s; return s;
#   }
#   function blob(x, y, r, color, alpha) {
#     if (r < 0.3 || alpha <= 0) return;
#     ctx.globalAlpha = clamp(alpha, 0, 1);
#     ctx.drawImage(glowSprite(color), x - r, y - r, r * 2, r * 2);
#   }
# 
#   // ---- state ----
#   var parts = [], slashes = [], rings = [], bolts = [], beams = [], ghosts = [], stars = [], flashes = [];
#   var orbRec = null, auraRec = null, speedRec = null, domainRec = null;
#   var shakeMag = 0, shakeTime = 0, shakeMax = 1, hs = 0, slowT = 0, slowS = 1, darkA = 0, darkT = 0, darkMax = 1;
#   var invertT = 0;
#   var T = 0;
# 
#   function addPart(p) { if (parts.length < 1800) parts.push(p); }
# 
#   // ---------------------------------------------------------------------
#   // Spawners
#   // ---------------------------------------------------------------------
#   var API = {};
# 
#   // Call every frame while a fighter is "powered up". x,y,w,h = the body box in game pixels.
#   API.aura = function (x, y, w, h, style, power) {
#     var s = st(style); power = power || 2; updateView();
#     auraRec = { x: x, y: y, w: w, h: h, style: style, ttl: 0.1 };
#     var n = 1 + power;
#     for (var i = 0; i < n; i++) {
#       var side = Math.random() < 0.7 ? (Math.random() < 0.5 ? -2 : w + 2) + rand(-3, 3) : rand(0, w);
#       var px = X(x + side), py = Y(y + rand(h * 0.1, h));
#       addPart({ type: 'flame', x: px, y: py, vx: rand(-10, 10) * view.k, vy: -rand(60, 150) * view.k,
#         life: 0, max: rand(0.5, 1.0), size: rand(4, 9) * view.k, sway: rand(0, TAU), swayAmp: rand(8, 22) * view.k, s: s });
#     }
#     if (Math.random() < 0.25 * power) {
#       addPart({ type: 'spark', x: X(x + rand(0, w)), y: Y(y + rand(h * 0.2, h)), vx: rand(-30, 30) * view.k, vy: -rand(80, 180) * view.k,
#         life: 0, max: rand(0.3, 0.7), size: 1.5 * view.k, color: s.accent, grav: 0 });
#     }
#     if (s.dark && Math.random() < 0.3) {
#       addPart({ type: 'smoke', x: X(x + rand(0, w)), y: Y(y + h * rand(0.4, 1)), vx: rand(-8, 8) * view.k, vy: -rand(20, 50) * view.k,
#         life: 0, max: rand(0.7, 1.2), size: rand(8, 14) * view.k, color: s.outer });
#     }
#   };
# 
#   // A sweeping crescent. x,y = where the swing pivots (the attacker), deg = swing direction, len = reach.
#   API.slash = function (x, y, deg, len, style) {
#     updateView();
#     len = len || 40;
#     slashes.push({ x: X(x), y: Y(y), a: (deg || 0) * Math.PI / 180, R: len * view.k, thick: len * 0.38 * view.k,
#       t: 0, dur: 0.34, s: st(style) });
#     var tip = (deg || 0) * Math.PI / 180;
#     for (var i = 0; i < 6; i++) {
#       var ang = tip + rand(-1, 1);
#       addPart({ type: 'spark', x: X(x) + Math.cos(tip) * len * view.k, y: Y(y) + Math.sin(tip) * len * view.k,
#         vx: Math.cos(ang) * rand(80, 220) * view.k, vy: Math.sin(ang) * rand(80, 220) * view.k,
#         life: 0, max: rand(0.12, 0.3), size: 1.4 * view.k, color: st(style).accent, grav: 0 });
#     }
#   };
# 
#   API.shockwave = function (x, y, size, style) {
#     updateView();
#     rings.push({ x: X(x), y: Y(y), R: (size || 50) * view.k, t: 0, dur: 0.5, s: st(style) });
#   };
# 
#   API.hitstop = function (ms) { hs = Math.max(hs, ms / 1000); };
#   API.slowmo = function (percent, ms) { slowS = clamp(percent / 100, 0.05, 1); slowT = ms / 1000; };
#   API.shake = function (mag, ms) { shakeMag = Math.max(shakeMag, mag); shakeTime = ms / 1000; shakeMax = shakeTime || 1; };
#   API.flash = function (color, ms, alpha) { flashes.push({ c: color || '#ffffff', t: 0, dur: (ms || 160) / 1000, a: alpha == null ? 0.5 : alpha }); };
#   API.darken = function (percent, ms) { darkA = Math.max(darkA, clamp(percent / 100, 0, 1)); darkT = darkMax = ms / 1000; };
#   API.frozen = function () { return hs > 0; };
# 
#   // A normal hit: freeze-frame, spiky flash, ring, sparks and a little shake. power 1..3
#   API.impact = function (x, y, power, style) {
#     updateView(); power = clamp(power || 1, 1, 3);
#     var s = st(style || 'fire');
#     API.hitstop(35 + power * 28);
#     API.shake(2 + power * 2.5, 130 + power * 40);
#     API.flash(s.core, 100 + power * 30, 0.22 + power * 0.08);
#     stars.push({ x: X(x), y: Y(y), n: 10 + power * 2, R: (28 + power * 16) * view.k, t: 0, dur: 0.26, s: s, seed: Math.random() * TAU });
#     rings.push({ x: X(x), y: Y(y), R: (22 + power * 12) * view.k, t: 0, dur: 0.3, s: s, thin: true });
#     var n = 12 + power * 8;
#     for (var i = 0; i < n; i++) {
#       var a = rand(0, TAU), sp = rand(90, 300 + power * 80) * view.k;
#       addPart({ type: 'spark', x: X(x), y: Y(y), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: 0, max: rand(0.15, 0.45),
#         size: rand(1, 2.2) * view.k, color: Math.random() < 0.5 ? s.core : s.accent, grav: 220 * view.k });
#     }
#     for (var j = 0; j < power * 3; j++) {
#       var a2 = rand(0, TAU), sp2 = rand(40, 160) * view.k;
#       addPart({ type: 'debris', x: X(x), y: Y(y), vx: Math.cos(a2) * sp2, vy: Math.sin(a2) * sp2 - 60 * view.k, life: 0, max: rand(0.4, 0.8),
#         size: rand(1.5, 3.2) * view.k, color: s.mid, rot: rand(0, TAU), vr: rand(-12, 12), grav: 520 * view.k });
#     }
#   };
# 
#   // The big critical hit: inverted-colour frames, black-and-red lightning, long freeze, heavy shake.
#   API.crit = function (x, y, style) {
#     updateView();
#     var s = st(style || 'blood');
#     API.hitstop(170);
#     API.shake(11, 380);
#     invertT = 0.07;
#     API.darken(55, 520);
#     API.flash(s.core, 110, 0.7);
#     var cx = X(x), cy = Y(y);
#     var bolts_n = 7;
#     for (var i = 0; i < bolts_n; i++) {
#       var a = (i / bolts_n) * TAU + rand(-0.3, 0.3), len = rand(70, 150) * view.k;
#       bolts.push(makeBolt(cx, cy, cx + Math.cos(a) * len, cy + Math.sin(a) * len, s, rand(0.28, 0.42), 2.4 * view.k, 0.35));
#     }
#     stars.push({ x: cx, y: cy, n: 14, R: 60 * view.k, t: 0, dur: 0.3, s: s, seed: rand(0, TAU) });
#     rings.push({ x: cx, y: cy, R: 120 * view.k, t: 0, dur: 0.55, s: s });
#     rings.push({ x: cx, y: cy, R: 70 * view.k, t: 0, dur: 0.4, s: s, thin: true });
#     for (var k = 0; k < 46; k++) {
#       var b = rand(0, TAU), sp = rand(120, 460) * view.k;
#       addPart({ type: 'spark', x: cx, y: cy, vx: Math.cos(b) * sp, vy: Math.sin(b) * sp, life: 0, max: rand(0.2, 0.6), size: rand(1, 2.6) * view.k,
#         color: Math.random() < 0.6 ? s.mid : '#ffffff', grav: 120 * view.k });
#     }
#   };
# 
#   // Jagged energy bolt between two points (game pixels).
#   API.lightning = function (x1, y1, x2, y2, style, ms) {
#     updateView();
#     bolts.push(makeBolt(X(x1), Y(y1), X(x2), Y(y2), st(style || 'lightning'), (ms || 220) / 1000, 2.2 * view.k, 0.5));
#   };
# 
#   // A thick beam from (x1,y1) to (x2,y2) that lasts ms.
#   API.beam = function (x1, y1, x2, y2, style, width, ms) {
#     updateView();
#     beams.push({ x1: X(x1), y1: Y(y1), x2: X(x2), y2: Y(y2), w: (width || 14) * view.k, s: st(style || 'void'), t: 0, dur: (ms || 600) / 1000 });
#     API.shake(3, 200);
#   };
# 
#   // A charging orb. Call every frame while charging; stop calling and it fades. Returns nothing.
#   API.orb = function (x, y, r, style) {
#     updateView();
#     var s = st(style || 'void');
#     orbRec = { x: X(x), y: Y(y), r: (r || 10) * view.k, s: s, ttl: 0.1 };
#     for (var i = 0; i < 2; i++) {
#       var a = rand(0, TAU), d = (r || 10) * view.k * rand(2.5, 4);
#       addPart({ type: 'pull', x: orbRec.x + Math.cos(a) * d, y: orbRec.y + Math.sin(a) * d, tx: orbRec.x, ty: orbRec.y,
#         life: 0, max: rand(0.25, 0.5), size: rand(1, 2.2) * view.k, color: Math.random() < 0.5 ? s.accent : s.mid });
#     }
#   };
# 
#   // Afterimage of a fighter's body box (call a few times per dash).
#   API.ghost = function (x, y, w, h, style) {
#     updateView();
#     ghosts.push({ x: X(x), y: Y(y), w: w * view.k, h: h * view.k, t: 0, dur: 0.28, s: st(style || 'cursed') });
#   };
# 
#   // Streaks across the screen for ms. deg = travel direction.
#   API.speedLines = function (deg, ms) {
#     speedRec = { a: (deg || 0) * Math.PI / 180, ttl: (ms || 300) / 1000, lines: [] };
#   };
# 
#   // Domain-style void: a dark sphere swallows the screen from (x,y). Call domainEnd() to collapse it.
#   API.domain = function (x, y, style) {
#     updateView();
#     var s = st(style || 'void');
#     var arr = [];
#     for (var i = 0; i < 220; i++) arr.push({ a: rand(0, TAU), d: Math.sqrt(Math.random()), sz: rand(0.6, 2.4), sp: rand(0.05, 0.4) * (Math.random() < 0.5 ? -1 : 1), tw: rand(0, TAU) });
#     domainRec = { x: X(x), y: Y(y), s: s, t: 0, end: -1, stars: arr, glyphs: [] };
#     for (var g = 0; g < 14; g++) domainRec.glyphs.push({ a: rand(0, TAU), d: rand(0.15, 0.95), len: rand(0.04, 0.12), sp: rand(0.1, 0.35) * (Math.random() < 0.5 ? -1 : 1) });
#     API.shake(6, 500);
#     API.flash(s.mid, 220, 0.4);
#   };
#   API.domainEnd = function () { if (domainRec && domainRec.end < 0) domainRec.end = domainRec.t; };
#   API.clear = function () { parts.length = slashes.length = rings.length = bolts.length = beams.length = ghosts.length = stars.length = flashes.length = 0; orbRec = auraRec = speedRec = domainRec = null; };
# 
#   function makeBolt(x1, y1, x2, y2, s, dur, width, jitter) {
#     return { x1: x1, y1: y1, x2: x2, y2: y2, s: s, t: 0, dur: dur, w: width, j: jitter, pts: null, regen: 0 };
#   }
#   function boltPoints(b) {
#     var dx = b.x2 - b.x1, dy = b.y2 - b.y1, len = Math.sqrt(dx * dx + dy * dy), n = Math.max(5, Math.floor(len / 14));
#     var nx = -dy / (len || 1), ny = dx / (len || 1), pts = [];
#     for (var i = 0; i <= n; i++) {
#       var u = i / n, off = (i === 0 || i === n) ? 0 : rand(-1, 1) * len * b.j * 0.2;
#       pts.push([b.x1 + dx * u + nx * off, b.y1 + dy * u + ny * off]);
#     }
#     return pts;
#   }
# 
#   // ---------------------------------------------------------------------
#   // Drawing
#   // ---------------------------------------------------------------------
#   function drawParts(dt) {
#     for (var i = parts.length - 1; i >= 0; i--) {
#       var p = parts[i];
#       p.life += dt;
#       var u = p.life / p.max;
#       if (u >= 1) { parts.splice(i, 1); continue; }
#       if (p.type === 'pull') {
#         p.x += (p.tx - p.x) * Math.min(1, dt * 7); p.y += (p.ty - p.y) * Math.min(1, dt * 7);
#       } else {
#         if (p.grav) p.vy += p.grav * dt;
#         p.x += p.vx * dt + (p.type === 'flame' ? Math.sin(p.life * 7 + p.sway) * p.swayAmp * dt : 0);
#         p.y += p.vy * dt;
#         if (p.type === 'debris') p.rot += p.vr * dt;
#       }
#       if (p.type === 'flame') {
#         var c = u < 0.7 ? p.s.mid : p.s.outer;
#         ctx.globalCompositeOperation = 'lighter';
#         ctx.save(); ctx.translate(p.x, p.y); ctx.scale(0.7, 1.8);
#         blob(0, 0, p.size * (1 - u * 0.7) * 1.4, c, 0.5 * (1 - u));
#         ctx.restore();
#       } else if (p.type === 'spark') {
#         ctx.globalCompositeOperation = 'lighter';
#         ctx.globalAlpha = 1 - u; ctx.strokeStyle = p.color; ctx.lineWidth = p.size;
#         ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.035, p.y - p.vy * 0.035); ctx.stroke();
#       } else if (p.type === 'pull') {
#         ctx.globalCompositeOperation = 'lighter';
#         blob(p.x, p.y, p.size * 3, p.color, 0.5 + 0.5 * u);
#       } else if (p.type === 'smoke') {
#         ctx.globalCompositeOperation = 'source-over';
#         blob(p.x, p.y, p.size * (1 + u * 1.4), p.color, (1 - u) * 0.35);
#       } else if (p.type === 'debris') {
#         ctx.globalCompositeOperation = 'lighter';
#         ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = 1 - u; ctx.fillStyle = p.color;
#         ctx.fillRect(-p.size, -p.size * 0.6, p.size * 2, p.size * 1.2); ctx.restore();
#       }
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawAura(dt) {
#     if (!auraRec) return;
#     auraRec.ttl -= dt; if (auraRec.ttl <= 0) { auraRec = null; return; }
#     var a = auraRec, s = st(a.style);
#     var cx = X(a.x + a.w / 2), cy = Y(a.y + a.h * 0.6), pulse = 0.85 + 0.15 * Math.sin(T * 9);
#     ctx.globalCompositeOperation = 'lighter';
#     ctx.save(); ctx.translate(cx, cy); ctx.scale(0.62, 1);
#     blob(0, 0, Math.max(a.w, a.h) * view.k * 1.0 * pulse, s.mid, 0.22);
#     ctx.restore();
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawSlashes(dt) {
#     for (var i = slashes.length - 1; i >= 0; i--) {
#       var sl = slashes[i]; sl.t += dt;
#       var p = sl.t / sl.dur; if (p >= 1) { slashes.splice(i, 1); continue; }
#       var sw = easeOut(clamp(p / 0.4, 0, 1)), span = 1.15;
#       var head = sl.a - span + 2 * span * sw;
#       var tail = sl.a - span + 2 * span * sw * clamp((p - 0.15) / 0.85, 0, 1);
#       var alpha = p < 0.4 ? 1 : Math.pow(1 - (p - 0.4) / 0.6, 1.5);
#       var N = 26, outer = [], inner = [];
#       for (var k = 0; k <= N; k++) {
#         var u = k / N, ang = tail + (head - tail) * u, th = sl.thick * Math.sin(Math.PI * u);
#         outer.push([sl.x + Math.cos(ang) * sl.R, sl.y + Math.sin(ang) * sl.R]);
#         inner.push([sl.x + Math.cos(ang) * (sl.R - th), sl.y + Math.sin(ang) * (sl.R - th)]);
#       }
#       ctx.globalCompositeOperation = 'lighter';
#       ctx.globalAlpha = alpha;
#       var gr = ctx.createRadialGradient(sl.x, sl.y, sl.R - sl.thick, sl.x, sl.y, sl.R);
#       gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(0.55, sl.s.mid); gr.addColorStop(1, sl.s.core);
#       ctx.fillStyle = gr; ctx.shadowColor = sl.s.mid; ctx.shadowBlur = 18 * view.k;
#       ctx.beginPath(); ctx.moveTo(outer[0][0], outer[0][1]);
#       for (var o = 1; o <= N; o++) ctx.lineTo(outer[o][0], outer[o][1]);
#       for (var q = N; q >= 0; q--) ctx.lineTo(inner[q][0], inner[q][1]);
#       ctx.closePath(); ctx.fill();
#       ctx.shadowBlur = 0;
#       ctx.strokeStyle = sl.s.core; ctx.lineWidth = 1.6 * view.k;
#       ctx.beginPath(); ctx.moveTo(outer[0][0], outer[0][1]);
#       for (var o2 = 1; o2 <= N; o2++) ctx.lineTo(outer[o2][0], outer[o2][1]);
#       ctx.stroke();
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawRings(dt) {
#     for (var i = rings.length - 1; i >= 0; i--) {
#       var r = rings[i]; r.t += dt;
#       var p = r.t / r.dur; if (p >= 1) { rings.splice(i, 1); continue; }
#       var e = easeOut(p), R = r.R * e, a = 1 - p;
#       ctx.globalCompositeOperation = 'lighter';
#       if (!r.thin) {
#         var gr = ctx.createRadialGradient(r.x, r.y, R * 0.6, r.x, r.y, R);
#         gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, r.s.mid);
#         ctx.globalAlpha = a * 0.35; ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(r.x, r.y, R, 0, TAU); ctx.fill();
#       }
#       ctx.globalAlpha = a; ctx.strokeStyle = r.s.core; ctx.lineWidth = Math.max(0.5, (r.thin ? 2 : 5) * view.k * (1 - p));
#       ctx.shadowColor = r.s.mid; ctx.shadowBlur = 14 * view.k;
#       ctx.beginPath(); ctx.arc(r.x, r.y, R, 0, TAU); ctx.stroke(); ctx.shadowBlur = 0;
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawStars(dt) {
#     for (var i = stars.length - 1; i >= 0; i--) {
#       var s = stars[i]; s.t += dt;
#       var p = s.t / s.dur; if (p >= 1) { stars.splice(i, 1); continue; }
#       var R = s.R * (0.4 + easeOut(p) * 0.9), a = 1 - p;
#       ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = a;
#       ctx.fillStyle = s.s.core; ctx.shadowColor = s.s.mid; ctx.shadowBlur = 12 * view.k;
#       for (var k = 0; k < s.n; k++) {
#         var ang = s.seed + (k / s.n) * TAU, len = R * (k % 2 ? 0.55 : 1) * (0.7 + 0.3 * Math.sin(k * 12.9898));
#         var wd = 0.13;
#         ctx.beginPath();
#         ctx.moveTo(s.x + Math.cos(ang - wd) * R * 0.12, s.y + Math.sin(ang - wd) * R * 0.12);
#         ctx.lineTo(s.x + Math.cos(ang) * len, s.y + Math.sin(ang) * len);
#         ctx.lineTo(s.x + Math.cos(ang + wd) * R * 0.12, s.y + Math.sin(ang + wd) * R * 0.12);
#         ctx.closePath(); ctx.fill();
#       }
#       ctx.shadowBlur = 0;
#       blob(s.x, s.y, R * 0.5, s.s.core, a * 0.8);
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function strokeBolt(pts, s, w, alpha) {
#     ctx.lineJoin = 'round'; ctx.lineCap = 'round';
#     ctx.globalAlpha = alpha * 0.45; ctx.strokeStyle = s.mid; ctx.lineWidth = w * 4; ctx.shadowColor = s.mid; ctx.shadowBlur = 16 * view.k;
#     ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); ctx.stroke();
#     ctx.shadowBlur = 0; ctx.globalAlpha = alpha; ctx.strokeStyle = s.core; ctx.lineWidth = w;
#     ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (var j = 1; j < pts.length; j++) ctx.lineTo(pts[j][0], pts[j][1]); ctx.stroke();
#   }
#   function drawBolts(dt) {
#     for (var i = bolts.length - 1; i >= 0; i--) {
#       var b = bolts[i]; b.t += dt; b.regen -= dt;
#       var p = b.t / b.dur; if (p >= 1) { bolts.splice(i, 1); continue; }
#       if (!b.pts || b.regen <= 0) { b.pts = boltPoints(b); b.regen = 0.045; }
#       ctx.globalCompositeOperation = b.s.dark ? 'source-over' : 'lighter';
#       if (b.s.dark) { strokeBolt(b.pts, { mid: b.s.outer, core: b.s.outer }, b.w * 2.2, (1 - p)); }
#       ctx.globalCompositeOperation = 'lighter';
#       strokeBolt(b.pts, b.s, b.w, (1 - p * p) * (0.7 + 0.3 * Math.random()));
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawBeams(dt) {
#     for (var i = beams.length - 1; i >= 0; i--) {
#       var b = beams[i]; b.t += dt;
#       var p = b.t / b.dur; if (p >= 1) { beams.splice(i, 1); continue; }
#       var env = p < 0.12 ? p / 0.12 : (p > 0.75 ? (1 - p) / 0.25 : 1);
#       var w = b.w * env * (0.9 + 0.1 * Math.sin(T * 60));
#       ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
#       ctx.globalAlpha = 0.28 * env; ctx.strokeStyle = b.s.mid; ctx.lineWidth = w * 2.6;
#       ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
#       ctx.globalAlpha = 0.75 * env; ctx.strokeStyle = b.s.mid; ctx.lineWidth = w * 1.3;
#       ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
#       ctx.globalAlpha = env; ctx.strokeStyle = b.s.core; ctx.lineWidth = w * 0.55;
#       ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
#       blob(b.x1, b.y1, w * 2.6, b.s.core, env * 0.9);
#       blob(b.x2, b.y2, w * 3.4, b.s.mid, env * 0.9);
#       if (Math.random() < 0.9) {
#         var a = rand(0, TAU), sp = rand(80, 260) * view.k;
#         addPart({ type: 'spark', x: b.x2, y: b.y2, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: 0, max: rand(0.1, 0.3), size: 1.6 * view.k, color: b.s.accent, grav: 0 });
#       }
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawOrb(dt) {
#     if (!orbRec) return;
#     orbRec.ttl -= dt; if (orbRec.ttl <= 0) { orbRec = null; return; }
#     var o = orbRec, s = o.s, pulse = 1 + 0.06 * Math.sin(T * 22);
#     ctx.globalCompositeOperation = 'lighter';
#     blob(o.x, o.y, o.r * 3.2 * pulse, s.mid, 0.35);
#     blob(o.x, o.y, o.r * 1.8 * pulse, s.accent, 0.4);
#     if (s.dark) {
#       ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
#       ctx.fillStyle = s.outer; ctx.beginPath(); ctx.arc(o.x, o.y, o.r * 0.95, 0, TAU); ctx.fill();
#       ctx.globalCompositeOperation = 'lighter';
#       ctx.strokeStyle = s.core; ctx.lineWidth = Math.max(1, o.r * 0.12); ctx.globalAlpha = 0.9;
#       ctx.shadowColor = s.mid; ctx.shadowBlur = 16 * view.k;
#       ctx.beginPath(); ctx.arc(o.x, o.y, o.r * 0.95, 0, TAU); ctx.stroke(); ctx.shadowBlur = 0;
#     } else {
#       blob(o.x, o.y, o.r * 1.1, s.core, 1);
#     }
#     for (var k = 0; k < 3; k++) {
#       var ang = T * (4 + k) + k * 2.1, rr = o.r * (1.5 + 0.25 * k);
#       blob(o.x + Math.cos(ang) * rr, o.y + Math.sin(ang) * rr * 0.55, o.r * 0.28, s.accent, 0.9);
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawGhosts(dt) {
#     for (var i = ghosts.length - 1; i >= 0; i--) {
#       var g = ghosts[i]; g.t += dt;
#       var p = g.t / g.dur; if (p >= 1) { ghosts.splice(i, 1); continue; }
#       ctx.globalCompositeOperation = 'lighter';
#       ctx.globalAlpha = (1 - p) * 0.55; ctx.fillStyle = g.s.mid; ctx.shadowColor = g.s.accent; ctx.shadowBlur = 12 * view.k;
#       ctx.fillRect(g.x, g.y, g.w, g.h);
#       ctx.shadowBlur = 0; ctx.globalAlpha = (1 - p) * 0.5; ctx.fillStyle = g.s.core;
#       ctx.fillRect(g.x + g.w * 0.2, g.y + g.h * 0.1, g.w * 0.6, g.h * 0.8);
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawSpeed(dt) {
#     if (!speedRec) return;
#     speedRec.ttl -= dt; if (speedRec.ttl <= 0) { speedRec = null; return; }
#     var s = speedRec, fade = clamp(s.ttl / 0.12, 0, 1);
#     while (s.lines.length < 36) {
#       s.lines.push({ off: rand(-0.7, 0.7), pos: rand(-0.2, 1.2), len: rand(0.1, 0.4), sp: rand(2.5, 5), w: rand(1, 2.6) });
#     }
#     var ca = Math.cos(s.a), sa = Math.sin(s.a), D = Math.max(VW, VH);
#     ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = '#ffffff'; ctx.lineCap = 'round';
#     for (var i = 0; i < s.lines.length; i++) {
#       var l = s.lines[i]; l.pos += l.sp * dt; if (l.pos > 1.4) { l.pos = -0.3; l.off = rand(-0.7, 0.7); }
#       var bx = VW / 2 + (-sa) * l.off * D + ca * (l.pos - 0.5) * D, by = VH / 2 + ca * l.off * D + sa * (l.pos - 0.5) * D;
#       ctx.globalAlpha = 0.5 * fade; ctx.lineWidth = l.w * view.k;
#       ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx - ca * l.len * D, by - sa * l.len * D); ctx.stroke();
#     }
#     ctx.globalAlpha = 1;
#   }
# 
#   function drawDomain(dt) {
#     var d = domainRec; if (!d) return;
#     d.t += dt;
#     var Rmax = Math.sqrt(VW * VW + VH * VH) * 1.05;
#     var grow = easeOut(clamp(d.t / 0.75, 0, 1)), R = Rmax * grow, fade = 1;
#     if (d.end >= 0) {
#       var q = (d.t - d.end) / 0.5;
#       if (q >= 1) { domainRec = null; return; }
#       R = Rmax * (1 - q * q); fade = 1 - q * 0.6;
#     }
#     ctx.save();
#     ctx.beginPath(); ctx.arc(d.x, d.y, R, 0, TAU); ctx.clip();
#     ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 0.9 * fade;
#     var bg = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, R);
#     bg.addColorStop(0, d.s.mid); bg.addColorStop(0.18, d.s.outer); bg.addColorStop(1, '#000000');
#     ctx.fillStyle = bg; ctx.fillRect(0, 0, VW, VH);
#     ctx.globalCompositeOperation = 'lighter';
#     ctx.lineCap = 'round'; ctx.strokeStyle = d.s.accent;
#     for (var i = 0; i < d.stars.length; i++) {
#       var s = d.stars[i], ang = s.a + d.t * s.sp * 2.2, dist = s.d * R * 0.98;
#       var tw = 0.5 + 0.5 * Math.sin(d.t * 3 + s.tw), trail = 0.1 + Math.abs(s.sp) * 0.9;
#       ctx.globalAlpha = (0.2 + 0.6 * tw) * fade; ctx.lineWidth = s.sz * view.k;
#       ctx.beginPath();
#       if (s.sp > 0) ctx.arc(d.x, d.y, dist, ang - trail, ang); else ctx.arc(d.x, d.y, dist, ang, ang + trail);
#       ctx.stroke();
#     }
#     ctx.lineWidth = 1.4 * view.k; ctx.strokeStyle = d.s.accent;
#     for (var g = 0; g < d.glyphs.length; g++) {
#       var gl = d.glyphs[g], base = gl.a + d.t * gl.sp, rr = gl.d * R * 0.85;
#       ctx.globalAlpha = 0.5 * fade;
#       ctx.beginPath(); ctx.arc(d.x, d.y, rr, base, base + gl.len * TAU); ctx.stroke();
#     }
#     ctx.restore();
#     ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = fade;
#     ctx.strokeStyle = d.s.core; ctx.lineWidth = 4 * view.k; ctx.shadowColor = d.s.mid; ctx.shadowBlur = 28 * view.k;
#     ctx.beginPath(); ctx.arc(d.x, d.y, R, 0, TAU); ctx.stroke(); ctx.shadowBlur = 0; ctx.globalAlpha = 1;
#   }
# 
#   // ---------------------------------------------------------------------
#   // Main loop
#   // ---------------------------------------------------------------------
#   var last = performance.now();
#   function frame(now) {
#     var rdt = Math.min((now - last) / 1000, 0.05); last = now;
#     updateView();
#     var scale = hs > 0 ? 0.05 : (slowT > 0 ? slowS : 1);
#     var dt = rdt * scale; T += rdt;
#     if (hs > 0) hs -= rdt;
#     if (slowT > 0) slowT -= rdt;
#     if (darkT > 0) darkT -= rdt;
# 
#     var ox = 0, oy = 0;
#     if (shakeTime > 0) {
#       shakeTime -= rdt;
#       var f = clamp(shakeTime / shakeMax, 0, 1), m = shakeMag * f * view.k;
#       ox = rand(-m, m); oy = rand(-m, m);
#       if (shakeTime <= 0) shakeMag = 0;
#     }
#     var gc = gameCanvas();
#     if (gc) {
#       gc.style.transform = (ox || oy) ? 'translate(' + ox.toFixed(1) + 'px,' + oy.toFixed(1) + 'px)' : '';
#       if (invertT > 0) { invertT -= rdt; gc.style.filter = 'invert(1) contrast(1.4)'; } else if (gc.style.filter) gc.style.filter = '';
#     }
# 
#     ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
#     ctx.clearRect(0, 0, VW, VH);
#     ctx.translate(ox, oy);
#     ctx.globalCompositeOperation = 'source-over';
# 
#     if (darkT > 0) {
#       ctx.globalAlpha = darkA * clamp(darkT / darkMax, 0, 1); ctx.fillStyle = '#000'; ctx.fillRect(-20, -20, VW + 40, VH + 40); ctx.globalAlpha = 1;
#     }
#     drawDomain(dt);
#     drawAura(dt);
#     drawGhosts(dt);
#     drawBeams(dt);
#     drawOrb(dt);
#     drawSlashes(dt);
#     drawRings(dt);
#     drawBolts(dt);
#     drawStars(dt);
#     drawParts(dt);
#     drawSpeed(dt);
# 
#     ctx.globalCompositeOperation = 'source-over';
#     for (var i = flashes.length - 1; i >= 0; i--) {
#       var fl = flashes[i]; fl.t += rdt;
#       if (fl.t >= fl.dur) { flashes.splice(i, 1); continue; }
#       ctx.globalAlpha = fl.a * (1 - fl.t / fl.dur); ctx.fillStyle = fl.c; ctx.fillRect(-20, -20, VW + 40, VH + 40);
#     }
#     ctx.globalAlpha = 1;
#     requestAnimationFrame(frame);
#   }
#   requestAnimationFrame(frame);
#   window.CVFX = API;
# })();

// ---------------------------------------------------------------------
// Volt-side API
// ---------------------------------------------------------------------

// Call every frame while a fighter is powered up. x, y, w, h = body box.
fn fxAura(x, y, w, h, style) {
  # CVFX.aura(x, y, w, h, style, 2)
}

fn fxAuraStrong(x, y, w, h, style) {
  # CVFX.aura(x, y, w, h, style, 4)
}

// Sweeping crescent. deg: 0 = right, 90 = down, 180 = left, 270 = up.
fn fxSlash(x, y, deg, reach, style) {
  # CVFX.slash(x, y, deg, reach, style)
}

// Normal hit with freeze-frame. power 1 (light) to 3 (heavy).
fn fxImpact(x, y, power, style) {
  # CVFX.impact(x, y, power, style)
}

// Critical hit: inverted frames, lightning, long freeze, heavy shake.
fn fxCrit(x, y, style) {
  # CVFX.crit(x, y, style)
}

fn fxShockwave(x, y, size, style) {
  # CVFX.shockwave(x, y, size, style)
}

fn fxBeam(x1, y1, x2, y2, style, width, ms) {
  # CVFX.beam(x1, y1, x2, y2, style, width, ms)
}

// Call every frame while charging. r = radius in game pixels.
fn fxOrb(x, y, r, style) {
  # CVFX.orb(x, y, r, style)
}

fn fxLightning(x1, y1, x2, y2, style) {
  # CVFX.lightning(x1, y1, x2, y2, style, 220)
}

// Afterimage of a body box; call every couple of frames while dashing.
fn fxGhost(x, y, w, h, style) {
  # CVFX.ghost(x, y, w, h, style)
}

fn fxSpeedLines(deg, ms) {
  # CVFX.speedLines(deg, ms)
}

// Dark sphere swallows the screen from (x, y). Call fxDomainEnd() to collapse it.
fn fxDomain(x, y, style) {
  # CVFX.domain(x, y, style)
}

fn fxDomainEnd() {
  # CVFX.domainEnd()
}

fn fxHitstop(ms) {
  # CVFX.hitstop(ms)
}

// percent: game speed (100 = normal, 20 = very slow) for ms milliseconds.
fn fxSlowmo(percent, ms) {
  # CVFX.slowmo(percent, ms)
}

fn fxShake(magnitude, ms) {
  # CVFX.shake(magnitude, ms)
}

fn fxFlash(color) {
  # CVFX.flash(color, 160, 0.5)
}

fn fxDarken(percent, ms) {
  # CVFX.darken(percent, ms)
}

// True during a hit-stop freeze: skip your movement/AI code while it is.
fn fxFrozen() {
  # return CVFX.frozen()
}

fn fxClear() {
  # CVFX.clear()
}

// ---------------------------------------------------------------------
// Demo: a tiny training room to try every effect.
//   Left / Right  move        Space  dash (afterimages + speed lines)
//   A  aura on/off            Z  slash        X  hit the dummy
//   C  critical strike        S  shockwave    Hold O  charge an orb, release to fire
//   D  domain on/off          L  lightning    Q  switch colour style
// ---------------------------------------------------------------------
## html, body { margin: 0; background: #05050a; }

title "Combat VFX Demo"
canvas 320, 180

let px = 70
let py = 118
let dir = 1
let dashT = 0
let aura = false
let domain = false
let orbCharge = 0
let wasOrb = false
let tick = 0
let styleN = 0
let styles = ["cursed", "fire", "blood", "void", "lightning", "gold"]
let dummyX = 230
let hurt = 0

every frame {
  tick += 1
  paint "#0b0916"

  // backdrop: moon, far buildings, floor
  box 262, 36, 22, 22 color "#2a2748"
  box 0, 96, 320, 2 color "#1c1836"
  box 20, 70, 24, 40 color "#120f26"
  box 52, 56, 30, 54 color "#150f2c"
  box 96, 78, 22, 32 color "#120f26"
  box 150, 62, 28, 48 color "#150f2c"
  box 0, 142, 320, 38 color "#100d20"
  box 0, 142, 320, 1 color "#3b3566"

  // training dummy (post, cross-beam, target)
  hurt = max(hurt - 1, 0)
  let dmx = dummyX
  if hurt > 0 { dmx = dummyX + (hurt % 2) * 2 - 1 }
  box dmx + 6, 108, 4, 34 color "#6b5848"
  box dmx - 2, 114, 20, 4 color "#8a7160"
  box dmx + 1, 100, 14, 14 color "#c9b79a"
  if hurt > 0 { box dmx + 1, 100, 14, 14 color "#ffffff" }
  box dmx + 5, 104, 6, 6 color "#8a2f2f"

  // fighter (original silhouette: hooded figure with a scarf)
  let sx = px
  box sx, py + 4, 12, 20 color "#1a1630"
  box sx + 1, py - 4, 10, 10 color "#241e44"
  box sx + 3, py - 1, 6, 3 color "#e8e3ff"
  box sx - 3 * dir + 4, py + 5, 3, 12 color "#7a5cff"
  box sx + 2, py + 24, 3, 6 color "#0f0c20"
  box sx + 7, py + 24, 3, 6 color "#0f0c20"

  // HUD
  write "Z slash  X hit  C crit  S shock  L bolt" at 160, 3 centered shadow color "#c9c3d6"
  write "A aura  D domain  Q style  Space dash" at 160, 12 centered shadow color "#c9c3d6"
  write "Hold O: charge orb   style: " + styles[styleN] at 160, 21 centered shadow color "#8f89a8"

  if not fxFrozen() {
    if dashT > 0 {
      dashT -= 1
      px += dir * 7
      if dashT % 2 == 0 { fxGhost(px, py - 4, 12, 34, styles[styleN]) }
    } else {
      if held("left") { px -= 2 dir = -1 }
      if held("right") { px += 2 dir = 1 }
    }
    px = min(max(px, 6), 300)
    if held("o") { orbCharge = min(orbCharge + 1, 90) }
  }

  if aura { fxAura(px, py - 4, 12, 34, styles[styleN]) }

  if held("o") {
    fxOrb(px + 20 * dir, py + 4, 4 + orbCharge / 9, styles[styleN])
    wasOrb = true
  } else {
    if wasOrb {
      wasOrb = false
      let w = 6 + orbCharge / 8
      fxBeam(px + 20 * dir, py + 4, px + 300 * dir, py + 4, styles[styleN], w, 700)
      fxImpact(dummyX + 8, py + 4, 3, styles[styleN])
      hurt = 12
    }
    orbCharge = 0
  }
}

when key "space" pressed {
  dashT = 10
  fxSpeedLines(dir * 180 - 180 + 0, 350)
  fxShake(2, 120)
}
when key "a" pressed { aura = not aura }
when key "z" pressed {
  let deg = 0
  if dir < 0 { deg = 180 }
  fxSlash(px + 6, py + 12, deg, 46, styles[styleN])
  tone 520 to 880 for 70ms
}
when key "x" pressed {
  fxImpact(dummyX + 8, py + 6, 2, styles[styleN])
  hurt = 10
  tone 180 to 90 for 90ms
}
when key "c" pressed {
  fxCrit(dummyX + 8, py + 6, "blood")
  hurt = 22
  tone 80 to 40 for 220ms
}
when key "s" pressed { fxShockwave(px + 6, py + 30, 70, styles[styleN]) }
when key "l" pressed { fxLightning(px + 6, py - 40, dummyX + 8, py + 6, "lightning") }
when key "q" pressed { styleN = (styleN + 1) % 6 }
when key "d" pressed {
  domain = not domain
  if domain { fxDomain(px + 6, py + 10, styles[styleN]) } else { fxDomainEnd() }
}
