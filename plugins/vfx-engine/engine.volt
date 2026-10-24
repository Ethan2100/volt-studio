// =====================================================================
// VFX engine - a small particle/screen-effects engine for #html Volt
// games (burst, confetti, trail, sparkle, shake, flash, ring, glow).
//
// Volt's #html target has no canvas or graphics primitives of its own,
// so the engine itself is raw JavaScript, inserted verbatim via Volt's
// "# " escape hatch (any line starting with "# " is copied into the
// compiled output as-is). Everything it exposes lands on one object,
// window.VFX, so the whole block below is portable to any other page's
// <script> with no Volt dependency at all. The fn wrappers after it are
// a friendly Volt-side API so your own game code can call burst(x, y)
// instead of reaching into window.VFX directly.
//
// Paste this at the top of a #html Volt file (after your `title` line),
// then call burst(), confetti(), shake(), flash(), ring() or glow() from
// your own buttons, `when key` blocks, or game logic.
// =====================================================================

## html, body { margin: 0; height: 100%; background: #05050a; overflow: hidden; }
## body #vfxCanvas { position: fixed; inset: 0; z-index: 0; display: block; }

// The canvas is created and inserted directly on <body> here (not via
// Volt's `html "..."`) so it can never end up nested inside a panel that
// uses backdrop-filter - that turns the panel into a CSS containing
// block for position:fixed children, pulling inset:0 to cover the panel
// instead of the viewport and silently eating every click.
# (function () {
#   var canvas = document.createElement('canvas');
#   canvas.id = 'vfxCanvas';
#   document.body.insertBefore(canvas, document.body.firstChild);
#   var ctx = canvas.getContext('2d');
#   function resize() { canvas.width = window.innerWidth; canvas.height = window.innerHeight; }
#   resize(); window.addEventListener('resize', resize);
#   var rand = function (a, b) { return a + Math.random() * (b - a); };
#   var DEFAULT_COLORS = ['#ff4d6d', '#ffd23f', '#4cc9f0', '#7ee787', '#c77dff', '#ffffff'];
#   var pickColor = function (c) { return c || DEFAULT_COLORS[(Math.random() * DEFAULT_COLORS.length) | 0]; };
#   var particles = [], rings = [], glows = [];
#   var shakeTime = 0, shakeMag = 0;
#   var flashColor = null, flashTime = 0, flashMax = 1;
#   function addParticle(x, y, color, opts) {
#     opts = opts || {};
#     var angle = opts.angle !== undefined ? opts.angle : rand(0, Math.PI * 2);
#     var speed = opts.speed !== undefined ? opts.speed : rand(2, 7);
#     particles.push({
#       x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
#       life: 1, decay: opts.decay || rand(0.012, 0.025), size: opts.size || rand(2, 5),
#       color: pickColor(color), gravity: opts.gravity !== undefined ? opts.gravity : 0.05,
#       drag: opts.drag !== undefined ? opts.drag : 0.985,
#     });
#   }
#   window.VFX = {};
#   window.VFX.burst = function (x, y, color, count) {
#     count = count || 28;
#     for (var i = 0; i < count; i++) addParticle(x, y, color, { speed: rand(2, 9) });
#   };
#   window.VFX.confetti = function (count) {
#     count = count || 70;
#     for (var i = 0; i < count; i++) {
#       addParticle(rand(0, canvas.width), -10, null, {
#         angle: Math.PI / 2 + rand(-0.5, 0.5), speed: rand(1, 4), gravity: 0.1,
#         decay: rand(0.004, 0.01), size: rand(3, 6), drag: 0.995,
#       });
#     }
#   };
#   window.VFX.trail = function (x, y, color) {
#     addParticle(x, y, color, { speed: rand(0.1, 1), decay: rand(0.03, 0.07), size: rand(1.5, 3), gravity: 0 });
#   };
#   window.VFX.sparkle = function (count) {
#     count = count || 1;
#     for (var i = 0; i < count; i++) {
#       addParticle(rand(0, canvas.width), rand(0, canvas.height), '#ffffff', {
#         speed: rand(0, 0.3), decay: rand(0.02, 0.05), size: rand(1, 2.5), gravity: 0,
#       });
#     }
#   };
#   window.VFX.shake = function (duration, magnitude) { shakeTime = duration || 300; shakeMag = magnitude || 10; };
#   window.VFX.flash = function (color, duration) { flashColor = color || '#ffffff'; flashTime = flashMax = duration || 200; };
#   window.VFX.ring = function (x, y, color) { rings.push({ x: x, y: y, r: 4, life: 1, color: pickColor(color) }); };
#   window.VFX.glow = function (x, y, radius, color) { glows.push({ x: x, y: y, r: radius || 40, color: pickColor(color), t: 0 }); };
#   var lastT = performance.now();
#   function frame(now) {
#     var dt = Math.min(now - lastT, 50); lastT = now;
#     var ox = 0, oy = 0;
#     if (shakeTime > 0) { shakeTime -= dt; ox = rand(-shakeMag, shakeMag); oy = rand(-shakeMag, shakeMag); }
#     ctx.setTransform(1, 0, 0, 1, 0, 0);
#     ctx.fillStyle = 'rgba(5,5,10,0.24)';
#     ctx.fillRect(0, 0, canvas.width, canvas.height);
#     ctx.save();
#     ctx.translate(ox, oy);
#     for (var i = glows.length - 1; i >= 0; i--) {
#       var g = glows[i]; g.t += dt;
#       var pulse = 0.6 + 0.4 * Math.sin(g.t / 180);
#       var grad = ctx.createRadialGradient(g.x, g.y, 0, g.x, g.y, g.r * pulse);
#       grad.addColorStop(0, g.color); grad.addColorStop(1, 'transparent');
#       ctx.fillStyle = grad; ctx.beginPath(); ctx.arc(g.x, g.y, g.r * pulse, 0, Math.PI * 2); ctx.fill();
#       if (g.t > 4000) glows.splice(i, 1);
#     }
#     for (var j = rings.length - 1; j >= 0; j--) {
#       var r = rings[j]; r.r += dt * 0.4; r.life -= dt / 600;
#       if (r.life <= 0) { rings.splice(j, 1); continue; }
#       ctx.strokeStyle = r.color; ctx.globalAlpha = Math.max(r.life, 0); ctx.lineWidth = 3;
#       ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2); ctx.stroke(); ctx.globalAlpha = 1;
#     }
#     for (var k = particles.length - 1; k >= 0; k--) {
#       var p = particles[k];
#       p.vy += p.gravity; p.vx *= p.drag; p.vy *= p.drag; p.x += p.vx; p.y += p.vy; p.life -= p.decay;
#       if (p.life <= 0 || p.y > canvas.height + 60) { particles.splice(k, 1); continue; }
#       ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
#       ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
#     }
#     ctx.restore();
#     if (flashTime > 0) {
#       flashTime -= dt; ctx.fillStyle = flashColor;
#       ctx.globalAlpha = Math.max(flashTime / flashMax, 0) * 0.55;
#       ctx.fillRect(0, 0, canvas.width, canvas.height); ctx.globalAlpha = 1;
#     }
#     requestAnimationFrame(frame);
#   }
#   requestAnimationFrame(frame);
#   canvas.addEventListener('pointerdown', function (e) { window.VFX.burst(e.clientX, e.clientY, null, 36); });
#   canvas.addEventListener('pointermove', function (e) { if (e.buttons) window.VFX.trail(e.clientX, e.clientY, null); });
# })();

// ---------------------------------------------------------------------
// Volt-side API - call these from your own buttons, keys, or game logic.
// ---------------------------------------------------------------------

fn burst(x, y) {
  # window.VFX.burst(x, y, null, 28)
}

fn burstColor(x, y, color) {
  # window.VFX.burst(x, y, color, 28)
}

fn confetti() {
  # window.VFX.confetti(70)
}

fn sparkle(count) {
  # window.VFX.sparkle(count)
}

fn trail(x, y) {
  # window.VFX.trail(x, y, null)
}

fn shake() {
  # window.VFX.shake(300, 10)
}

fn shakeHard() {
  # window.VFX.shake(500, 22)
}

fn flash(color) {
  # window.VFX.flash(color, 220)
}

fn ring(x, y) {
  # window.VFX.ring(x, y, null)
}

fn ringColor(x, y, color) {
  # window.VFX.ring(x, y, color)
}

fn glow(x, y, radius, color) {
  # window.VFX.glow(x, y, radius, color)
}
