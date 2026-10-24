// =====================================================================
// Flipbook Studio - draw frames, play them back, export the animation.
// A standalone #html Volt app (not a library you insert into other
// pages, like the rest of this plugin - this one IS the app). Compile
// it and open the resulting index.html in any browser.
//
// - Draw with the mouse/pen on the paper-white canvas.
// - "Add Frame" saves the drawing as the next frame and clears the
//   canvas, leaving the saved frame faintly visible (onion skin) so
//   you can trace the next pose on top of it.
// - "Play"/"Stop" loops the saved frames at the current FPS.
// - "Export" downloads a single, self-contained .html file that plays
//   the animation on its own - no Volt Studio needed to view it.
// =====================================================================

#html
title "Flipbook Studio"

## :root { --flip-bg: #0b0c10; --flip-panel: #15171f; --flip-border: #262936; --flip-text: #f1f2f8; --flip-muted: #9aa0b4; --flip-accent: #ff3d68; }
## body { background: var(--flip-bg); color: var(--flip-text); margin: 0; font-family: system-ui, sans-serif; }
## body #volt { max-width: 720px; margin: 24px auto; padding: 0 16px 40px; display: flex; flex-direction: column; align-items: center; gap: 14px; }
## body #volt h1 { font-size: 1.3em; margin: 10px 0 0; }

## .flip-stage { position: relative; width: 480px; height: 360px; border-radius: 14px; overflow: hidden; box-shadow: 0 20px 50px rgba(0,0,0,0.5); touch-action: none; }
## .flip-stage canvas { position: absolute; inset: 0; width: 100%; height: 100%; }
## canvas#flip-onion { background: #e9e6da; }
## canvas#flip-draw { background: transparent; cursor: crosshair; }

## .flip-toolbar { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
## body #volt button { font: inherit; font-size: 0.95em; font-weight: 600; padding: 10px 16px; border: 0; border-radius: 10px; background: #2a2d3b; color: #fff; cursor: pointer; transition: background 0.15s ease, transform 0.08s ease; }
## body #volt button:hover { background: #363a4a; }
## body #volt button:active { transform: scale(0.95); }
## .flip-accent { background: var(--flip-accent) !important; color: #1b0008 !important; }

## .flip-strip { display: flex; gap: 8px; overflow-x: auto; width: 480px; padding: 8px; background: var(--flip-panel); border: 1px solid var(--flip-border); border-radius: 12px; min-height: 68px; }
## .flip-thumb { width: 60px; height: 45px; flex: none; border-radius: 6px; border: 2px solid var(--flip-border); background-size: cover; background-position: center; background-color: #e9e6da; }
## .flip-strip:empty::after { content: 'No frames yet - draw something, then click "Add Frame"'; color: var(--flip-muted); font-size: 0.85em; padding: 8px; }

## .volt-show { color: var(--flip-muted); font-size: 0.9em; }

# (function () {
#   const stage = document.createElement('div');
#   stage.className = 'flip-stage';
#   const onion = document.createElement('canvas');
#   onion.id = 'flip-onion'; onion.width = 480; onion.height = 360;
#   const draw = document.createElement('canvas');
#   draw.id = 'flip-draw'; draw.width = 480; draw.height = 360;
#   stage.append(onion, draw);
#
#   const strip = document.createElement('div');
#   strip.className = 'flip-strip';
#
#   const onionCtx = onion.getContext('2d');
#   const ctx = draw.getContext('2d');
#   ctx.lineWidth = 4; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = '#1b1d27';
#
#   const frames = [];
#   let fps = 8;
#   let playing = false;
#   let playTimer = null;
#   let drawingNow = false;
#   let last = null;
#
#   function pos(e) {
#     const r = draw.getBoundingClientRect();
#     const scaleX = draw.width / r.width, scaleY = draw.height / r.height;
#     return [(e.clientX - r.left) * scaleX, (e.clientY - r.top) * scaleY];
#   }
#   draw.addEventListener('pointerdown', (e) => { if (playing) return; drawingNow = true; last = pos(e); draw.setPointerCapture(e.pointerId); });
#   draw.addEventListener('pointermove', (e) => {
#     if (!drawingNow) return;
#     const p = pos(e);
#     ctx.beginPath(); ctx.moveTo(last[0], last[1]); ctx.lineTo(p[0], p[1]); ctx.stroke();
#     last = p;
#   });
#   function endStroke() { drawingNow = false; }
#   draw.addEventListener('pointerup', endStroke);
#   draw.addEventListener('pointerleave', endStroke);
#
#   function renderOnion() {
#     onionCtx.clearRect(0, 0, onion.width, onion.height);
#     onionCtx.fillStyle = '#e9e6da';
#     onionCtx.fillRect(0, 0, onion.width, onion.height);
#     if (frames.length) {
#       const img = new Image();
#       img.onload = () => { onionCtx.globalAlpha = 0.3; onionCtx.drawImage(img, 0, 0, onion.width, onion.height); onionCtx.globalAlpha = 1; };
#       img.src = frames[frames.length - 1];
#     }
#   }
#   function renderStrip() {
#     strip.innerHTML = '';
#     frames.forEach((f) => {
#       const t = document.createElement('div');
#       t.className = 'flip-thumb';
#       t.style.backgroundImage = "url('" + f + "')";
#       strip.appendChild(t);
#     });
#   }
#
#   window.FLIP = {
#     addFrame() {
#       frames.push(draw.toDataURL('image/png'));
#       ctx.clearRect(0, 0, draw.width, draw.height);
#       renderOnion();
#       renderStrip();
#     },
#     undoFrame() {
#       frames.pop();
#       renderOnion();
#       renderStrip();
#     },
#     clearFrame() {
#       ctx.clearRect(0, 0, draw.width, draw.height);
#     },
#     setFps(n) {
#       fps = Math.max(1, Math.min(24, n));
#       if (playing) { this.stop(); this.play(); }
#       return fps;
#     },
#     play() {
#       if (!frames.length || playing) return;
#       playing = true;
#       draw.style.visibility = 'hidden';
#       let i = 0;
#       onionCtx.clearRect(0, 0, onion.width, onion.height);
#       const img = new Image();
#       const showFrame = () => {
#         img.src = frames[i % frames.length];
#         i++;
#       };
#       img.onload = () => { onionCtx.clearRect(0, 0, onion.width, onion.height); onionCtx.drawImage(img, 0, 0, onion.width, onion.height); };
#       showFrame();
#       playTimer = setInterval(showFrame, 1000 / fps);
#     },
#     stop() {
#       playing = false;
#       clearInterval(playTimer);
#       draw.style.visibility = 'visible';
#       renderOnion();
#     },
#     export() {
#       const html = '<!doctype html><html><head><meta charset="utf-8"><title>My Flipbook</title>' +
#         '<style>body{margin:0;background:#111;display:flex;align-items:center;justify-content:center;height:100vh}' +
#         'canvas{background:#e9e6da;border-radius:12px;box-shadow:0 20px 50px rgba(0,0,0,.5)}</style></head><body>' +
#         '<canvas id="c" width="480" height="360"></canvas><script>' +
#         'const frames=' + JSON.stringify(frames) + ';const fps=' + fps + ';' +
#         'const ctx=document.getElementById("c").getContext("2d");let i=0;const img=new Image();' +
#         'img.onload=()=>ctx.drawImage(img,0,0,480,360);' +
#         'function tick(){img.src=frames[i%frames.length];i++;}' +
#         'if(frames.length){tick();setInterval(tick,1000/fps);}' +
#         '</scr' + 'ipt></body></html>';
#       const blob = new Blob([html], { type: 'text/html' });
#       const a = document.createElement('a');
#       a.href = URL.createObjectURL(blob);
#       a.download = 'my-flipbook.html';
#       a.click();
#     },
#   };
#
#   window.addEventListener('DOMContentLoaded', () => {
#     const volt = document.getElementById('volt');
#     volt.insertBefore(stage, volt.children[1] || null);
#     volt.insertBefore(strip, stage.nextSibling);
#     renderOnion();
#   });
# })();

let fps = 8

html "<div class='flip-toolbar'></div>"
button "Add Frame" {
  # FLIP.addFrame()
}
button "Undo Frame" {
  # FLIP.undoFrame()
}
button "Clear" {
  # FLIP.clearFrame()
}
button "Play" {
  # FLIP.play()
}
button "Stop" {
  # FLIP.stop()
}
button "FPS -" {
  fps = fps - 1
  if fps < 1 {
    fps = 1
  }
  # FLIP.setFps(fps)
  show "Playback speed: " + fps + " fps"
}
button "FPS +" {
  fps = fps + 1
  if fps > 24 {
    fps = 24
  }
  # FLIP.setFps(fps)
  show "Playback speed: " + fps + " fps"
}
button "Export" {
  # FLIP.export()
}

show "Playback speed: " + fps + " fps"
