// =====================================================================
// Flipbook Studio - draw frames, play them back, export the animation.
// A standalone #html Volt app (not a library you paste into another
// page - this file IS the whole app, start from an empty file).
//
// Rebuilt after looking at how real frame-by-frame tools (Clip Studio
// Paint's animation workflow, Toon Boom Harmony) are actually laid out:
//   - Clip Studio Paint: a Timeline with numbered frame "cels", an
//     onion-skin toggle, Automatic Interpolation (keyframes), and a
//     Fill tool with "close gap"/tolerance options.
//   - Toon Boom Harmony: an Exposure Sheet where each frame is its own
//     slot you can click back into and redraw, not just append to.
// Flipbook Studio borrows the parts that make sense for a quick, tiny
// 2D flipbook rather than a full production timeline:
//   - Frames are an exposure sheet, not a one-way stack: click any
//     thumbnail to load that exact frame back onto the canvas and
//     keep drawing on it. "Save" writes the canvas into the selected
//     frame (overwriting it) or appends a new one if you started a
//     blank "New" frame.
//   - "Duplicate" copies the selected frame right after itself - the
//     normal way to start the next pose without redrawing a static
//     background every time.
//   - "Onion" toggles the faint previous-frame trace on/off (Clip
//     Studio Paint's onion-skin toggle).
//   - A Fill (bucket) tool, flood-filling a connected area of similar
//     color - Clip Studio Paint's fill tool is one of its most-used.
//   - "Loop" toggles whether Play repeats or stops after one pass.
//
// - Pick a color and brush size, draw with the mouse/pen on the
//   paper-white canvas. Smoothed strokes, real eraser (lifts pixels,
//   doesn't just paint over), straight/rect/circle shape tools with
//   shift-angle-snap on Line, and a Fill tool.
// - "Play"/"Stop" plays the saved frames at the current FPS, looping
//   unless you turn "Loop" off.
// - "Export" downloads a single, self-contained .html file that plays
//   the animation on its own - no Volt Studio needed to view it.
//
// The whole toolbar (colors, brush sizes, frame/playback/export
// buttons) is built as real styled DOM elements in the raw-JS block
// below, not with Volt's `button` statement - Volt's button always
// compiles to a bare, unstyled <button> with no per-button class hook,
// which isn't enough control for color swatches or a selected/active
// state. Everything still lives under flip-* classes/ids so it won't
// clash with other addons on the same page.
// =====================================================================

#html
title "Flipbook Studio"

## :root { --flip-bg: #0b0c10; --flip-panel: #15171f; --flip-border: #262936; --flip-text: #f1f2f8; --flip-muted: #9aa0b4; --flip-accent: #ff3d68; }
## body { background: var(--flip-bg); color: var(--flip-text); margin: 0; font-family: system-ui, sans-serif; }
## body #volt { max-width: 760px; margin: 24px auto; padding: 0 16px 40px; display: flex; flex-direction: column; align-items: center; gap: 16px; }
## body #volt h1 { font-size: 1.3em; margin: 10px 0 0; }

## .flip-stage { position: relative; width: 560px; height: 400px; border-radius: 14px; overflow: hidden; box-shadow: 0 20px 50px rgba(0,0,0,0.5); touch-action: none; }
## .flip-stage canvas { position: absolute; inset: 0; width: 100%; height: 100%; }
## canvas#flip-onion { background: #e9e6da; }
## canvas#flip-draw { background: transparent; cursor: crosshair; }

## .flip-panel { width: 560px; background: var(--flip-panel); border: 1px solid var(--flip-border); border-radius: 14px; padding: 14px 16px; }
## .flip-panel + .flip-panel { margin-top: -4px; }
## .flip-label { font-size: 0.72em; text-transform: uppercase; letter-spacing: 0.06em; color: var(--flip-muted); margin-bottom: 10px; font-weight: 700; }
## .flip-row { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }

## .flip-swatch { width: 30px; height: 30px; border-radius: 50%; border: 2px solid var(--flip-border); cursor: pointer; padding: 0; transition: transform 0.1s ease; }
## .flip-swatch:hover { transform: scale(1.1); }
## .flip-swatch.flip-active { border-color: #fff; box-shadow: 0 0 0 2px var(--flip-accent); }

## .flip-size { width: 36px; height: 36px; border-radius: 10px; border: 2px solid var(--flip-border); background: #2a2d3b; cursor: pointer; display: flex; align-items: center; justify-content: center; }
## .flip-size span { border-radius: 50%; background: #fff; display: block; }
## .flip-size.flip-active { border-color: var(--flip-accent); background: #3a1826; }

## .flip-tool { font: inherit; font-size: 0.82em; font-weight: 600; padding: 8px 12px; border-radius: 9px; border: 2px solid var(--flip-border); background: #2a2d3b; color: #fff; cursor: pointer; }
## .flip-tool.flip-active { border-color: var(--flip-accent); background: #3a1826; }

## .flip-btn { font: inherit; font-size: 0.95em; font-weight: 600; padding: 10px 16px; border: 0; border-radius: 10px; background: #2a2d3b; color: #fff; cursor: pointer; transition: background 0.15s ease, transform 0.08s ease; }
## .flip-btn:hover { background: #363a4a; }
## .flip-btn:active { transform: scale(0.95); }
## .flip-btn-accent { background: var(--flip-accent); color: #1b0008; }
## .flip-btn-accent:hover { background: #ff5c80; }
## .flip-btn-play { background: #3fcf8e; color: #04291a; }
## .flip-btn-play:hover { background: #5be0a6; }
## .flip-fps { min-width: 64px; text-align: center; font-weight: 700; color: var(--flip-text); }

## .flip-strip { display: flex; gap: 8px; overflow-x: auto; width: 560px; padding: 8px; background: var(--flip-panel); border: 1px solid var(--flip-border); border-radius: 12px; min-height: 68px; }
## .flip-thumb { width: 60px; height: 45px; flex: none; border-radius: 6px; border: 2px solid var(--flip-border); background-size: cover; background-position: center; background-color: #e9e6da; cursor: pointer; }
## .flip-thumb.flip-thumb-active { border-color: var(--flip-accent); box-shadow: 0 0 0 2px var(--flip-accent); }
## .flip-strip:empty::after { content: 'No frames yet - draw something, then click "Save"'; color: var(--flip-muted); font-size: 0.85em; padding: 8px; }

# (function () {
#   const COLORS = ['#1b1d27', '#ff3d68', '#4cc9f0', '#3fcf8e', '#ffb703', '#f1f2f8'];
#   const SIZES = [3, 7, 14];
#
#   const stage = document.createElement('div');
#   stage.className = 'flip-stage';
#   const onion = document.createElement('canvas');
#   onion.id = 'flip-onion'; onion.width = 560; onion.height = 400;
#   const draw = document.createElement('canvas');
#   draw.id = 'flip-draw'; draw.width = 560; draw.height = 400;
#   stage.append(onion, draw);
#
#   const onionCtx = onion.getContext('2d');
#   const ctx = draw.getContext('2d');
#   ctx.lineCap = 'round'; ctx.lineJoin = 'round';
#
#   let color = COLORS[0];
#   let brushWidth = SIZES[1];
#   let tool = 'pen';       // 'pen' | 'line' | 'rect' | 'circle' | 'eraser' | 'fill'
#   let smooth = true;      // stabilizer: the drawn line eases toward the pointer instead of jumping straight to it
#   function applyBrush() {
#     ctx.globalCompositeOperation = tool === 'eraser' ? 'destination-out' : 'source-over';
#     ctx.strokeStyle = color;
#     ctx.lineWidth = brushWidth;
#   }
#   applyBrush();
#
#   // --- color + brush + tool toolbar --------------------------------
#   const toolsPanel = document.createElement('div');
#   toolsPanel.className = 'flip-panel';
#   const toolsLabel = document.createElement('div');
#   toolsLabel.className = 'flip-label'; toolsLabel.textContent = 'Color & Brush';
#   const toolsRow = document.createElement('div');
#   toolsRow.className = 'flip-row';
#
#   const swatchEls = [];
#   COLORS.forEach((c) => {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-swatch'; b.style.background = c;
#     b.onclick = () => { color = c; if (tool === 'eraser') tool = 'pen'; applyBrush(); updateActive(); };
#     swatchEls.push(b);
#     toolsRow.appendChild(b);
#   });
#
#   const sizeEls = [];
#   SIZES.forEach((s) => {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-size';
#     const dot = document.createElement('span');
#     dot.style.width = s + 'px'; dot.style.height = s + 'px';
#     b.appendChild(dot);
#     b.onclick = () => { brushWidth = s; applyBrush(); updateActive(); };
#     sizeEls.push(b);
#     toolsRow.appendChild(b);
#   });
#
#   const shapesLabel = document.createElement('div');
#   shapesLabel.className = 'flip-label'; shapesLabel.textContent = 'Tool';
#   const shapesRow = document.createElement('div');
#   shapesRow.className = 'flip-row';
#   const TOOLS = [
#     ['pen', 'Pen'],
#     ['line', 'Line'],
#     ['rect', 'Rect'],
#     ['circle', 'Circle'],
#     ['fill', 'Fill'],
#     ['eraser', 'Eraser'],
#   ];
#   const toolEls = [];
#   TOOLS.forEach(([id, label]) => {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-tool'; b.textContent = label;
#     b.onclick = () => { tool = id; applyBrush(); updateActive(); };
#     toolEls.push(b);
#     shapesRow.appendChild(b);
#   });
#   const smoothBtn = document.createElement('button');
#   smoothBtn.type = 'button'; smoothBtn.className = 'flip-tool'; smoothBtn.textContent = 'Smooth';
#   smoothBtn.title = 'Stabilizes your strokes - the line follows your cursor with a slight lag instead of jumping straight to it, which irons out hand shake. Pen tool only.';
#   smoothBtn.onclick = () => { smooth = !smooth; updateActive(); };
#   shapesRow.appendChild(smoothBtn);
#
#   function updateActive() {
#     swatchEls.forEach((b, i) => b.classList.toggle('flip-active', tool !== 'eraser' && COLORS[i] === color));
#     sizeEls.forEach((b, i) => b.classList.toggle('flip-active', SIZES[i] === brushWidth));
#     toolEls.forEach((b, i) => b.classList.toggle('flip-active', TOOLS[i][0] === tool));
#     smoothBtn.classList.toggle('flip-active', smooth);
#   }
#   updateActive();
#   toolsPanel.append(toolsLabel, toolsRow, shapesLabel, shapesRow);
#
#   // --- frame (exposure sheet) + playback + export toolbar ----------
#   const actionsPanel = document.createElement('div');
#   actionsPanel.className = 'flip-panel';
#   const frameLabel = document.createElement('div');
#   frameLabel.className = 'flip-label'; frameLabel.textContent = 'Frame';
#   const frameRow = document.createElement('div');
#   frameRow.className = 'flip-row';
#   const playLabel = document.createElement('div');
#   playLabel.className = 'flip-label'; playLabel.textContent = 'Playback & Export';
#   const playRow = document.createElement('div');
#   playRow.className = 'flip-row';
#
#   function mkBtn(label, cls, onClick) {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-btn' + (cls ? ' ' + cls : ''); b.textContent = label;
#     b.onclick = onClick;
#     return b;
#   }
#   function mkToggle(label, onClick) {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-tool'; b.textContent = label;
#     b.onclick = onClick;
#     return b;
#   }
#
#   const fpsLabel = document.createElement('span');
#   fpsLabel.className = 'flip-fps';
#   function renderFps() { fpsLabel.textContent = fps + ' fps'; }
#
#   const onionBtn = mkToggle('Onion', () => FLIP.toggleOnion());
#   const loopBtn = mkToggle('Loop', () => FLIP.toggleLoop());
#   const playBtn = mkBtn('Play', 'flip-btn-play', () => FLIP.play());
#   const stopBtn = mkBtn('Stop', '', () => FLIP.stop());
#
#   frameRow.append(
#     mkBtn('New', '', () => FLIP.newFrame()),
#     mkBtn('Save', 'flip-btn-accent', () => FLIP.saveFrame()),
#     mkBtn('Duplicate', '', () => FLIP.duplicateFrame()),
#     mkBtn('Delete', '', () => FLIP.deleteFrame()),
#     onionBtn,
#   );
#   playRow.append(
#     mkBtn('−', '', () => FLIP.setFps(fps - 1)),
#     fpsLabel,
#     mkBtn('+', '', () => FLIP.setFps(fps + 1)),
#     loopBtn,
#     playBtn,
#     stopBtn,
#     mkBtn('Export', 'flip-btn-accent', () => FLIP.export()),
#   );
#   actionsPanel.append(frameLabel, frameRow, playLabel, playRow);
#
#   // --- frame strip (exposure sheet) - click a thumbnail to reopen it
#   // for editing, instead of frames only ever being appended ----------
#   const strip = document.createElement('div');
#   strip.className = 'flip-strip';
#
#   // --- drawing --------------------------------------------------------
#   const frames = [];
#   let activeIndex = 0; // index into frames, or === frames.length for a blank unsaved draft
#   let onionOn = true;
#   let loopOn = true;
#   let fps = 8;
#   let playing = false;
#   let playTimer = null;
#   let drawingNow = false;
#   let last = null;
#
#   function posOf(e) {
#     const r = draw.getBoundingClientRect();
#     const scaleX = draw.width / r.width, scaleY = draw.height / r.height;
#     return [(e.clientX - r.left) * scaleX, (e.clientY - r.top) * scaleY];
#   }
#
#   // Snaps a point to the nearest 15-degree angle from (x0,y0) - used by
#   // the Line tool while Shift is held, like the "constrain" behavior in
#   // real drawing apps.
#   function snapAngle(x0, y0, x1, y1) {
#     const dx = x1 - x0, dy = y1 - y0;
#     const dist = Math.hypot(dx, dy);
#     const angle = Math.round(Math.atan2(dy, dx) / (Math.PI / 12)) * (Math.PI / 12);
#     return [x0 + Math.cos(angle) * dist, y0 + Math.sin(angle) * dist];
#   }
#
#   // Flood-fills the connected region under (x,y) with the current
#   // color - a stack-based fill over the canvas's own pixel buffer,
#   // tolerant of slightly anti-aliased edges so it doesn't leave a
#   // thin un-filled ring around pencil lines.
#   function hexToRgba(hex) {
#     const n = parseInt(hex.slice(1), 16);
#     return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 255];
#   }
#   function performFill(px, py) {
#     const w = draw.width, h = draw.height;
#     const x0 = Math.max(0, Math.min(w - 1, Math.round(px)));
#     const y0 = Math.max(0, Math.min(h - 1, Math.round(py)));
#     const imgData = ctx.getImageData(0, 0, w, h);
#     const data = imgData.data;
#     const startIdx = (y0 * w + x0) * 4;
#     const target = [data[startIdx], data[startIdx + 1], data[startIdx + 2], data[startIdx + 3]];
#     const fillColor = hexToRgba(color);
#     if (target[0] === fillColor[0] && target[1] === fillColor[1] && target[2] === fillColor[2] && target[3] === fillColor[3]) return;
#     const tol = 24;
#     function matches(idx) {
#       return Math.abs(data[idx] - target[0]) <= tol && Math.abs(data[idx + 1] - target[1]) <= tol &&
#         Math.abs(data[idx + 2] - target[2]) <= tol && Math.abs(data[idx + 3] - target[3]) <= tol;
#     }
#     const visited = new Uint8Array(w * h);
#     const stack = [[x0, y0]];
#     while (stack.length) {
#       const [cx, cy] = stack.pop();
#       if (cx < 0 || cx >= w || cy < 0 || cy >= h) continue;
#       const vIdx = cy * w + cx;
#       if (visited[vIdx]) continue;
#       const idx = vIdx * 4;
#       if (!matches(idx)) continue;
#       visited[vIdx] = 1;
#       data[idx] = fillColor[0]; data[idx + 1] = fillColor[1]; data[idx + 2] = fillColor[2]; data[idx + 3] = fillColor[3];
#       stack.push([cx + 1, cy], [cx - 1, cy], [cx, cy + 1], [cx, cy - 1]);
#     }
#     ctx.putImageData(imgData, 0, 0);
#   }
#
#   let startPos = null;     // stroke start, for line/rect/circle
#   let shapeSnapshot = null; // canvas pixels before the current shape preview, so dragging can redraw live without leaving trails
#   let smoothed = null;      // the stabilizer's eased brush position, for Pen tool
#
#   draw.addEventListener('pointerdown', (e) => {
#     if (playing) return;
#     const p = posOf(e);
#     if (tool === 'fill') { performFill(p[0], p[1]); return; }
#     drawingNow = true;
#     last = p;
#     startPos = last;
#     smoothed = last;
#     draw.setPointerCapture(e.pointerId);
#     if (tool === 'line' || tool === 'rect' || tool === 'circle') {
#       shapeSnapshot = ctx.getImageData(0, 0, draw.width, draw.height);
#     } else {
#       ctx.beginPath(); ctx.moveTo(last[0], last[1]); ctx.lineTo(last[0] + 0.01, last[1] + 0.01); ctx.stroke();
#     }
#   });
#
#   draw.addEventListener('pointermove', (e) => {
#     if (!drawingNow) return;
#     const p = posOf(e);
#
#     if (tool === 'pen' || tool === 'eraser') {
#       let target = p;
#       if (tool === 'pen' && smooth) {
#         smoothed = [smoothed[0] + (p[0] - smoothed[0]) * 0.35, smoothed[1] + (p[1] - smoothed[1]) * 0.35];
#         target = smoothed;
#       }
#       const mid = [(last[0] + target[0]) / 2, (last[1] + target[1]) / 2];
#       ctx.beginPath(); ctx.moveTo(last[0], last[1]); ctx.quadraticCurveTo(last[0], last[1], mid[0], mid[1]); ctx.stroke();
#       last = target;
#       return;
#     }
#
#     // line/rect/circle: restore the pre-shape pixels, then draw the
#     // shape fresh from startPos to the current pointer, so dragging
#     // around previews live without leaving a trail of old attempts.
#     ctx.putImageData(shapeSnapshot, 0, 0);
#     let end = p;
#     if (tool === 'line' && e.shiftKey) end = snapAngle(startPos[0], startPos[1], p[0], p[1]);
#     ctx.beginPath();
#     if (tool === 'line') {
#       ctx.moveTo(startPos[0], startPos[1]); ctx.lineTo(end[0], end[1]);
#     } else if (tool === 'rect') {
#       ctx.rect(startPos[0], startPos[1], end[0] - startPos[0], end[1] - startPos[1]);
#     } else if (tool === 'circle') {
#       const rx = Math.abs(end[0] - startPos[0]) / 2, ry = Math.abs(end[1] - startPos[1]) / 2;
#       const cx = (startPos[0] + end[0]) / 2, cy = (startPos[1] + end[1]) / 2;
#       ctx.ellipse(cx, cy, Math.max(rx, 0.01), Math.max(ry, 0.01), 0, 0, Math.PI * 2);
#     }
#     ctx.stroke();
#   });
#
#   function endStroke() { drawingNow = false; shapeSnapshot = null; }
#   draw.addEventListener('pointerup', endStroke);
#   draw.addEventListener('pointerleave', endStroke);
#
#   function clearCanvas() { ctx.clearRect(0, 0, draw.width, draw.height); }
#
#   function loadFrame(idx) {
#     clearCanvas();
#     if (idx >= 0 && idx < frames.length) {
#       const img = new Image();
#       img.onload = () => ctx.drawImage(img, 0, 0, draw.width, draw.height);
#       img.src = frames[idx];
#     }
#   }
#
#   function renderOnion() {
#     onionCtx.clearRect(0, 0, onion.width, onion.height);
#     onionCtx.fillStyle = '#e9e6da';
#     onionCtx.fillRect(0, 0, onion.width, onion.height);
#     const prevIdx = activeIndex - 1;
#     if (onionOn && prevIdx >= 0 && prevIdx < frames.length) {
#       const img = new Image();
#       img.onload = () => { onionCtx.globalAlpha = 0.3; onionCtx.drawImage(img, 0, 0, onion.width, onion.height); onionCtx.globalAlpha = 1; };
#       img.src = frames[prevIdx];
#     }
#   }
#   function renderStrip() {
#     strip.innerHTML = '';
#     frames.forEach((f, i) => {
#       const t = document.createElement('div');
#       t.className = 'flip-thumb' + (i === activeIndex ? ' flip-thumb-active' : '');
#       t.style.backgroundImage = "url('" + f + "')";
#       t.title = 'Frame ' + (i + 1) + ' - click to reopen for editing';
#       t.onclick = () => FLIP.selectFrame(i);
#       strip.appendChild(t);
#     });
#   }
#   function updateFrameToggles() {
#     onionBtn.classList.toggle('flip-active', onionOn);
#     loopBtn.classList.toggle('flip-active', loopOn);
#   }
#
#   window.FLIP = {
#     newFrame() {
#       if (playing) return;
#       activeIndex = frames.length;
#       clearCanvas();
#       renderOnion();
#       renderStrip();
#     },
#     saveFrame() {
#       const data = draw.toDataURL('image/png');
#       if (activeIndex < frames.length) {
#         frames[activeIndex] = data;
#       } else {
#         frames.push(data);
#         activeIndex = frames.length - 1;
#       }
#       renderOnion();
#       renderStrip();
#     },
#     duplicateFrame() {
#       if (!frames.length) return;
#       const srcIdx = Math.min(activeIndex, frames.length - 1);
#       frames.splice(srcIdx + 1, 0, frames[srcIdx]);
#       activeIndex = srcIdx + 1;
#       loadFrame(activeIndex);
#       renderOnion();
#       renderStrip();
#     },
#     deleteFrame() {
#       if (!frames.length || activeIndex >= frames.length) return;
#       frames.splice(activeIndex, 1);
#       if (!frames.length) {
#         activeIndex = 0;
#         clearCanvas();
#       } else {
#         if (activeIndex >= frames.length) activeIndex = frames.length - 1;
#         loadFrame(activeIndex);
#       }
#       renderOnion();
#       renderStrip();
#     },
#     selectFrame(idx) {
#       if (playing) return;
#       activeIndex = idx;
#       loadFrame(idx);
#       renderOnion();
#       renderStrip();
#     },
#     toggleOnion() {
#       onionOn = !onionOn;
#       renderOnion();
#       updateFrameToggles();
#     },
#     toggleLoop() {
#       loopOn = !loopOn;
#       updateFrameToggles();
#     },
#     setFps(n) {
#       fps = Math.max(1, Math.min(24, n));
#       renderFps();
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
#         if (i >= frames.length) {
#           if (loopOn) { i = 0; } else { this.stop(); return; }
#         }
#         img.src = frames[i];
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
#         '<canvas id="c" width="560" height="400"></canvas><script>' +
#         'const frames=' + JSON.stringify(frames) + ';const fps=' + fps + ';const loop=' + loopOn + ';' +
#         'const ctx=document.getElementById("c").getContext("2d");let i=0;const img=new Image();' +
#         'img.onload=()=>ctx.drawImage(img,0,0,560,400);' +
#         'let timer=null;function tick(){if(i>=frames.length){if(loop){i=0;}else{clearInterval(timer);return;}}img.src=frames[i];i++;}' +
#         'if(frames.length){tick();timer=setInterval(tick,1000/fps);}' +
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
#     volt.append(stage, toolsPanel, actionsPanel, strip);
#     renderFps();
#     renderOnion();
#     updateFrameToggles();
#   });
# })();
