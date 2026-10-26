// =====================================================================
// Flipbook Studio - draw frames, play them back, export the animation.
// A standalone #html Volt app (not a library you paste into another
// page - this file IS the whole app, start from an empty file).
//
// Built after looking at how real frame-by-frame tools (Clip Studio
// Paint's animation workflow, Toon Boom Harmony) are actually laid
// out, taking the parts that make sense for a quick 2D flipbook:
//
// FRAMES (exposure sheet)
//   Click any thumbnail to reopen that exact frame for editing.
//   New / Save / Duplicate / Delete, an Onion-skin toggle.
//
// LAYERS
//   Two layers: a persistent "Background" (shared by every frame, so
//   you don't redraw a static background each time) and a per-frame
//   "Character" layer (what New/Save/Duplicate/Delete/the thumbnails
//   actually operate on). Switch which one you're drawing on, hide
//   the background to check the character alone, or import an image
//   onto either one. Import Image drops the picture in as a movable
//   selection (scaled to fit) instead of baking it straight onto the
//   layer - drag it into position first, then draw elsewhere or
//   switch tools to lock it in. That's the "ready to animate" part:
//   it's now sitting there as one bitmap you can Save as a frame and
//   hand straight to Keyframe Tween.
//
// FILL & SHADE
//   Fill is flood fill - click inside a closed outline for flat cel
//   color. Shade and Highlight are freehand brushes that darken
//   (multiply) or lighten (screen) whatever's underneath instead of
//   replacing it, the way cel-shading is actually done: flat-fill the
//   character with Fill, then paint shadow/light areas with Shade/
//   Highlight and they blend with the fill color rather than
//   covering it up.
//
// BRUSHES
//   Pen / Pencil / Marker / Airbrush textures for the Pen tool, a
//   thickness slider, and an anti-aliasing setting. Being honest
//   about that last one: canvas strokes are always smoothed by the
//   browser - the AA setting changes how IMPORTED IMAGES and the
//   onion-skin ghost get scaled, not your hand-drawn lines.
//
// SELECT / TRANSFORM
//   Drag a rectangle to lift that piece of the active layer, then
//   drag it to reposition it before it's dropped back in - a small
//   move/transform tool rather than only drawing fresh ink.
//
// KEYFRAME TWEEN
//   Enter a move/scale/rotate/opacity amount and a frame count, and
//   it auto-generates that many in-between frames by redrawing the
//   active layer's current bitmap at interpolated positions - Clip
//   Studio Paint calls this Automatic Interpolation. Combined with
//   "Import Image" on the Character layer, this is how you bring in
//   a character image and have Flipbook Studio generate its motion
//   automatically, rather than hand-drawing every pose. To be clear:
//   it tweens the transform you give it (position/scale/rotation/
//   opacity) - it isn't an AI that invents a walk cycle on its own.
//
// BOARD EXPORT
//   "Export Board" lays saved frames out top-to-bottom into one tall
//   image, like a manhwa page/scroll, and downloads it as a PNG.
//
// - "Play"/"Stop" plays the saved frames at the current FPS, looping
//   unless "Loop" is off.
// - "Export" downloads a single, self-contained .html file that plays
//   the animation on its own - no Volt Studio needed to view it.
//
// The whole toolbar is built as real styled DOM elements in the
// raw-JS block below, not with Volt's `button` statement - Volt's
// button always compiles to a bare, unstyled <button> with no
// per-button class hook, which isn't enough control for color
// swatches or active-state toggles. Everything lives under flip-*
// classes/ids so it won't clash with other addons on the same page.
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
## canvas#flip-bg { background: transparent; }
## canvas#flip-draw { background: transparent; }
## canvas#flip-draw2 { background: transparent; }
## canvas#flip-overlay { background: transparent; pointer-events: none; }
## .flip-stage.flip-cursor-draw { cursor: crosshair; }
## .flip-stage.flip-cursor-select { cursor: cell; }

## .flip-panel { width: 560px; background: var(--flip-panel); border: 1px solid var(--flip-border); border-radius: 14px; padding: 14px 16px; }
## .flip-panel + .flip-panel { margin-top: -4px; }
## .flip-label { font-size: 0.72em; text-transform: uppercase; letter-spacing: 0.06em; color: var(--flip-muted); margin-bottom: 10px; font-weight: 700; }
## .flip-label:not(:first-child) { margin-top: 14px; }
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

## .flip-field { display: flex; flex-direction: column; gap: 4px; font-size: 0.72em; color: var(--flip-muted); font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; }
## .flip-input { width: 66px; padding: 7px 8px; border-radius: 8px; border: 2px solid var(--flip-border); background: #2a2d3b; color: #fff; font: inherit; font-size: 0.9em; }
## .flip-range { width: 130px; accent-color: var(--flip-accent); }
## .flip-file-btn { display: inline-flex; }
## .flip-file-btn input { display: none; }
## .flip-hint { font-size: 0.78em; color: var(--flip-muted); line-height: 1.4; }

## .flip-tabbar { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 12px; }
## .flip-tab { font: inherit; font-size: 0.78em; font-weight: 700; padding: 7px 13px; border-radius: 8px; border: 2px solid transparent; background: #20232f; color: var(--flip-muted); cursor: pointer; }
## .flip-tab:hover { color: var(--flip-text); }
## .flip-tab.flip-active { border-color: var(--flip-accent); color: var(--flip-text); background: #3a1826; }
## .flip-tabcontent { display: none; }
## .flip-tabcontent.flip-tabcontent-active { display: block; }
## .flip-tabcontent .flip-label:first-child { margin-top: 0; }

## .flip-strip { display: flex; gap: 8px; overflow-x: auto; width: 560px; padding: 8px; background: var(--flip-panel); border: 1px solid var(--flip-border); border-radius: 12px; min-height: 68px; }
## .flip-thumb { width: 60px; height: 45px; flex: none; border-radius: 6px; border: 2px solid var(--flip-border); background-size: cover; background-position: center; background-color: #e9e6da; cursor: pointer; }
## .flip-thumb.flip-thumb-active { border-color: var(--flip-accent); box-shadow: 0 0 0 2px var(--flip-accent); }
## .flip-strip:empty::after { content: 'No frames yet - draw something, then click "Save"'; color: var(--flip-muted); font-size: 0.85em; padding: 8px; }

# (function () {
#   const COLORS = ['#1b1d27', '#ff3d68', '#4cc9f0', '#3fcf8e', '#ffb703', '#f1f2f8'];
#   const SIZES = [3, 7, 14];
#   const BRUSHES = [['pen', 'Standard'], ['pencil', 'Pencil'], ['marker', 'Marker'], ['ink', 'Ink'], ['airbrush', 'Airbrush']];
#   const AA_LEVELS = ['high', 'low', 'none']; // cycled by the AA button; 'none' disables image smoothing
#
#   const stage = document.createElement('div');
#   stage.className = 'flip-stage flip-cursor-draw';
#   const onion = document.createElement('canvas');
#   onion.id = 'flip-onion'; onion.width = 560; onion.height = 400;
#   const bg = document.createElement('canvas');
#   bg.id = 'flip-bg'; bg.width = 560; bg.height = 400;
#   const draw = document.createElement('canvas');
#   draw.id = 'flip-draw'; draw.width = 560; draw.height = 400;
#   // Second, independently-animatable character - stacked in front of
#   // the first so a character brought in later (or just drawn second)
#   // reads as being in front, the usual front-to-back order for a two-
#   // person shot. Its own per-frame array (frames2) keeps it on the
#   // same shared timeline as Character 1.
#   const draw2 = document.createElement('canvas');
#   draw2.id = 'flip-draw2'; draw2.width = 560; draw2.height = 400;
#   const overlay = document.createElement('canvas');
#   overlay.id = 'flip-overlay'; overlay.width = 560; overlay.height = 400;
#   stage.append(onion, bg, draw, draw2, overlay);
#
#   const onionCtx = onion.getContext('2d');
#   const bgCtx = bg.getContext('2d');
#   const ctx = draw.getContext('2d');
#   const ctx2 = draw2.getContext('2d');
#   const overlayCtx = overlay.getContext('2d');
#   ctx.lineCap = 'round'; ctx.lineJoin = 'round';
#   ctx2.lineCap = 'round'; ctx2.lineJoin = 'round';
#   bgCtx.lineCap = 'round'; bgCtx.lineJoin = 'round';
#
#   let color = COLORS[0];
#   let brushWidth = SIZES[1];
#   let brushType = 'pen';  // 'pen' | 'pencil' | 'marker' | 'airbrush' - texture for the Pen drawing tool
#   let tool = 'pen';       // 'pen' | 'line' | 'rect' | 'circle' | 'eraser' | 'fill' | 'select'
#   let smooth = true;      // stabilizer: the drawn line eases toward the pointer instead of jumping straight to it
#   let aaIndex = 0;        // index into AA_LEVELS
#   let activeLayer = 'character'; // 'character' | 'character2' | 'background'
#   let bgVisible = true;
#
#   function activeCanvas() { return activeLayer === 'background' ? bg : activeLayer === 'character2' ? draw2 : draw; }
#   function activeCtx() { return activeLayer === 'background' ? bgCtx : activeLayer === 'character2' ? ctx2 : ctx; }
#
#   function applyBrush(targetCtx) {
#     const c = targetCtx || activeCtx();
#     c.globalCompositeOperation = tool === 'eraser' ? 'destination-out'
#       : tool === 'shade' ? 'multiply'   // darkens whatever's under the stroke - cel-shading shadows
#       : tool === 'highlight' ? 'screen' // lightens whatever's under the stroke - cel-shading highlights
#       : 'source-over';
#     c.strokeStyle = color;
#     c.fillStyle = color;
#     c.lineWidth = brushWidth;
#     c.globalAlpha = (tool === 'shade' || tool === 'highlight') ? 0.45 : 1;
#   }
#   applyBrush();
#
#   function applyAA() {
#     const mode = AA_LEVELS[aaIndex];
#     [ctx, ctx2, bgCtx, onionCtx].forEach((c) => {
#       c.imageSmoothingEnabled = mode !== 'none';
#       if (mode !== 'none') c.imageSmoothingQuality = mode;
#     });
#   }
#   applyAA();
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
#     b.onclick = () => { brushWidth = s; thicknessInput.value = s; applyBrush(); updateActive(); };
#     sizeEls.push(b);
#     toolsRow.appendChild(b);
#   });
#
#   const thicknessField = document.createElement('label');
#   thicknessField.className = 'flip-field'; thicknessField.textContent = 'Thickness';
#   const thicknessInput = document.createElement('input');
#   thicknessInput.type = 'range'; thicknessInput.min = '1'; thicknessInput.max = '40'; thicknessInput.value = String(brushWidth);
#   thicknessInput.className = 'flip-range';
#   thicknessInput.oninput = () => { brushWidth = Number(thicknessInput.value); applyBrush(); updateActive(); };
#   thicknessField.appendChild(thicknessInput);
#   toolsRow.appendChild(thicknessField);
#
#   const brushLabel = document.createElement('div');
#   brushLabel.className = 'flip-label'; brushLabel.textContent = 'Brush texture (Pen tool)';
#   const brushRow = document.createElement('div');
#   brushRow.className = 'flip-row';
#   const brushEls = [];
#   const BRUSH_TITLES = {
#     ink: 'Tapered, variable-width line like a real inking brush - thin where a stroke starts/lifts and where the pointer moves fast, fuller where it slows down or lingers. This is the brush for clean anime-style linework; the other brushes stay a flat width.',
#   };
#   BRUSHES.forEach(([id, label]) => {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-tool'; b.textContent = label;
#     if (BRUSH_TITLES[id]) b.title = BRUSH_TITLES[id];
#     b.onclick = () => { brushType = id; tool = 'pen'; applyBrush(); updateActive(); };
#     brushEls.push(b);
#     brushRow.appendChild(b);
#   });
#   const aaBtn = document.createElement('button');
#   aaBtn.type = 'button'; aaBtn.className = 'flip-tool';
#   aaBtn.title = 'Anti-aliasing: affects imported images and the onion-skin ghost. Hand-drawn strokes are always smoothed by the browser, so this does not change them.';
#   aaBtn.onclick = () => { aaIndex = (aaIndex + 1) % AA_LEVELS.length; applyAA(); renderAABtn(); };
#   function renderAABtn() { aaBtn.textContent = 'AA: ' + ({ high: 'Strong', low: 'Weak', none: 'None' })[AA_LEVELS[aaIndex]]; }
#   renderAABtn();
#   brushRow.appendChild(aaBtn);
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
#     ['shade', 'Shade'],
#     ['highlight', 'Highlight'],
#     ['eraser', 'Eraser'],
#     ['select', 'Select'],
#   ];
#   const TOOL_TITLES = {
#     fill: 'Flood-fills the connected area you click with the current color - flat cel colors.',
#     shade: 'Paints a darkening (multiply) stroke over whatever is underneath, instead of replacing the color - pick a shadow tone (a muted blue/purple works well) and paint where the light doesn\'t reach.',
#     highlight: 'Paints a lightening (screen) stroke over whatever is underneath - pick a light/warm tone and paint where the light hits.',
#     select: 'Drag a rectangle to lift that part of the layer, then drag it again to move it. Pick another tool, or click outside it, to drop it back in.',
#   };
#   const toolEls = [];
#   TOOLS.forEach(([id, label]) => {
#     const b = document.createElement('button');
#     b.type = 'button'; b.className = 'flip-tool'; b.textContent = label;
#     if (TOOL_TITLES[id]) b.title = TOOL_TITLES[id];
#     b.onclick = () => { commitFloatingSelection(); tool = id; applyBrush(); updateActive(); stage.className = 'flip-stage ' + (id === 'select' ? 'flip-cursor-select' : 'flip-cursor-draw'); };
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
#     brushEls.forEach((b, i) => b.classList.toggle('flip-active', BRUSHES[i][0] === brushType && tool === 'pen'));
#     toolEls.forEach((b, i) => b.classList.toggle('flip-active', TOOLS[i][0] === tool));
#     smoothBtn.classList.toggle('flip-active', smooth);
#   }
#   updateActive();
#   toolsPanel.append(toolsLabel, toolsRow, shapesLabel, shapesRow);
#
#   // --- tabbed secondary panels -----------------------------------------
#   // Brush textures, Layers, Frame, Tween and Playback used to all sit
#   // open at once as stacked panels - a wall of controls. They're used
#   // far less often than color/tool/thickness above, so they're tabs
#   // now: one visible at a time, switched with a small tab bar.
#   const tabPanel = document.createElement('div');
#   tabPanel.className = 'flip-panel';
#   const tabBar = document.createElement('div');
#   tabBar.className = 'flip-tabbar';
#   tabPanel.appendChild(tabBar);
#   const tabs = [];
#   function addTab(id, label, contentEl) {
#     contentEl.className = (contentEl.className ? contentEl.className + ' ' : '') + 'flip-tabcontent';
#     const btn = document.createElement('button');
#     btn.type = 'button'; btn.className = 'flip-tab'; btn.textContent = label;
#     btn.onclick = () => showTab(id);
#     tabBar.appendChild(btn);
#     tabPanel.appendChild(contentEl);
#     tabs.push({ id, btn, contentEl });
#   }
#   function showTab(id) {
#     tabs.forEach((t) => {
#       t.btn.classList.toggle('flip-active', t.id === id);
#       t.contentEl.classList.toggle('flip-tabcontent-active', t.id === id);
#     });
#   }
#
#   // --- Brush texture tab content ---------------------------------------
#   const brushContent = document.createElement('div');
#   brushContent.append(brushLabel, brushRow);
#
#   // --- layers tab content -----------------------------------------------
#   const layersContent = document.createElement('div');
#   const layersLabel = document.createElement('div');
#   layersLabel.className = 'flip-label'; layersLabel.textContent = 'Layers';
#   const layersRow = document.createElement('div');
#   layersRow.className = 'flip-row';
#   const charLayerBtn = document.createElement('button');
#   charLayerBtn.type = 'button'; charLayerBtn.className = 'flip-tool'; charLayerBtn.textContent = 'Draw on: Character';
#   const char2LayerBtn = document.createElement('button');
#   char2LayerBtn.type = 'button'; char2LayerBtn.className = 'flip-tool'; char2LayerBtn.textContent = 'Draw on: Character 2';
#   char2LayerBtn.title = 'A second, independently-posed figure sharing the same frames - for two-character shots (sparring, a duel, a reaction shot). Drawn in front of Character. New/Save/Duplicate/Delete move both characters together on the one shared timeline; Import/Auto-Detect/Auto-Rig target whichever of the two is active here.';
#   const bgLayerBtn = document.createElement('button');
#   bgLayerBtn.type = 'button'; bgLayerBtn.className = 'flip-tool'; bgLayerBtn.textContent = 'Draw on: Background';
#   charLayerBtn.onclick = () => { commitFloatingSelection(); activeLayer = 'character'; applyBrush(); updateLayerButtons(); };
#   char2LayerBtn.onclick = () => { commitFloatingSelection(); activeLayer = 'character2'; applyBrush(); updateLayerButtons(); };
#   bgLayerBtn.onclick = () => { commitFloatingSelection(); activeLayer = 'background'; applyBrush(); updateLayerButtons(); };
#   const bgVisibleBtn = document.createElement('button');
#   bgVisibleBtn.type = 'button'; bgVisibleBtn.className = 'flip-tool'; bgVisibleBtn.textContent = 'Background visible';
#   bgVisibleBtn.onclick = () => { bgVisible = !bgVisible; bg.style.visibility = bgVisible ? 'visible' : 'hidden'; updateLayerButtons(); renderOnion(); renderStrip(); };
#   const clearLayerBtn = document.createElement('button');
#   clearLayerBtn.type = 'button'; clearLayerBtn.className = 'flip-btn'; clearLayerBtn.textContent = 'Clear Layer';
#   clearLayerBtn.onclick = () => { activeCtx().clearRect(0, 0, 560, 400); renderOnion(); renderStrip(); };
#   const importLabel = document.createElement('label');
#   importLabel.className = 'flip-btn flip-file-btn'; importLabel.textContent = 'Import Image';
#   importLabel.title = 'Drops the image in as a movable selection, scaled to fit - drag it into position (for example on the Character layer, right where you\'ll want it for frame 1), then switch tools or draw elsewhere to lock it in. From there, Save it as a frame and use Keyframe Tween (Tween tab) to animate it.';
#   const importInput = document.createElement('input');
#   importInput.type = 'file'; importInput.accept = 'image/*';
#   importInput.onchange = () => {
#     const file = importInput.files && importInput.files[0];
#     if (!file) return;
#     const reader = new FileReader();
#     reader.onload = () => {
#       const img = new Image();
#       img.onload = () => {
#         // Drop the image in as a FLOATING selection (the same lifted
#         // state the Select tool produces) rather than baking it
#         // straight onto the layer - so the very next thing you do is
#         // drag it into position, ready to pose/animate, instead of
#         // having to switch to Select and re-lift it yourself.
#         commitFloatingSelection();
#         const scale = Math.min(560 / img.width, 400 / img.height, 1);
#         const w = Math.max(1, Math.round(img.width * scale)), h = Math.max(1, Math.round(img.height * scale));
#         const off = document.createElement('canvas');
#         off.width = w; off.height = h;
#         off.getContext('2d').drawImage(img, 0, 0, w, h);
#         const x = Math.round((560 - w) / 2), y = Math.round((400 - h) / 2);
#         selectState = { phase: 'floating', canvas: off, x, y, w, h, dragging: false, dragOffset: [0, 0], srcCtx: activeCtx() };
#         tool = 'select';
#         applyBrush();
#         updateActive();
#         stage.className = 'flip-stage flip-cursor-select';
#         drawFloatingPreview();
#       };
#       img.src = reader.result;
#     };
#     reader.readAsDataURL(file);
#     importInput.value = '';
#   };
#   importLabel.appendChild(importInput);
#
#   // --- Auto-Detect: splits one imported picture into Background +
#   // Character automatically, using a real foreground-detection model
#   // (TensorFlow.js BodyPix) rather than a color-based trick - a flat
#   // chroma-key wouldn't do anything useful on a photo-like background
#   // like the one in the screenshot this was built against. Honesty
#   // up front: BodyPix is trained to find PEOPLE in photos. It often
#   // still picks out a clear single subject in anime/illustration art
#   // too (edges + a salient figure against a busy background give it
#   // enough to go on), but it's not guaranteed on every image, and the
#   // cutout can come out rough around fine details like hair or fur -
#   // clean it up afterward with Select/Eraser/Fill like any cutout.
#   // It also needs an internet connection the FIRST time it's used in
#   // a session, to download the (few-MB) model; Import Image above
#   // needs no internet and always works.
#   let bodyPixLoad = null;
#   function loadScript(src) {
#     return new Promise((resolve, reject) => {
#       const s = document.createElement('script');
#       s.src = src; s.onload = () => resolve(); s.onerror = () => reject(new Error('failed to load ' + src));
#       document.head.appendChild(s);
#     });
#   }
#   function ensureBodyPix() {
#     if (!bodyPixLoad) {
#       bodyPixLoad = (async () => {
#         if (!window.tf) await loadScript('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.20.0/dist/tf.min.js');
#         if (!window.bodyPix) await loadScript('https://cdn.jsdelivr.net/npm/@tensorflow-models/body-pix@2.2.0/dist/body-pix.min.js');
#         return window.bodyPix.load({ architecture: 'MobileNetV1', outputStride: 16, multiplier: 0.75, quantBytes: 2 });
#       })();
#     }
#     return bodyPixLoad;
#   }
#
#   const autoLabel = document.createElement('label');
#   autoLabel.className = 'flip-btn flip-btn-accent flip-file-btn';
#   const autoLabelText = document.createElement('span'); autoLabelText.textContent = 'Auto-Detect';
#   autoLabel.appendChild(autoLabelText);
#   autoLabel.title = 'Splits one picture into Background (the whole image) and whichever Character layer is active below (just the detected subject, cut out and dropped in as a movable selection) automatically. Needs internet the first time, to download the detection model.';
#   const autoInput = document.createElement('input');
#   autoInput.type = 'file'; autoInput.accept = 'image/*';
#   autoInput.onchange = () => {
#     const file = autoInput.files && autoInput.files[0];
#     autoInput.value = '';
#     if (!file) return;
#     // Captured at file-pick time: whichever Character layer was active
#     // ("Draw on") when Auto-Detect was clicked is where the cutout
#     // lands, so running it twice can target Character then Character 2.
#     const targetLayer = activeLayer === 'character2' ? 'character2' : 'character';
#     const targetCtx = targetLayer === 'character2' ? ctx2 : ctx;
#     const reader = new FileReader();
#     reader.onload = async () => {
#       const img = new Image();
#       img.onload = async () => {
#         const originalLabel = autoLabelText.textContent;
#         autoLabelText.textContent = 'Loading model...';
#         try {
#           const net = await ensureBodyPix();
#           autoLabelText.textContent = 'Detecting...';
#           const natural = document.createElement('canvas');
#           natural.width = img.width; natural.height = img.height;
#           natural.getContext('2d').drawImage(img, 0, 0);
#           const mask = await net.segmentPerson(natural, { internalResolution: 'medium', segmentationThreshold: 0.6 });
#           let personPixels = 0;
#           for (let i = 0; i < mask.data.length; i++) if (mask.data[i]) personPixels++;
#
#           // Background: the whole picture, scaled to fit, committed
#           // straight onto the shared Background layer - do this
#           // regardless of whether a subject was found, since it's
#           // useful on its own.
#           const scale = Math.min(560 / img.width, 400 / img.height, 1);
#           const w = Math.max(1, Math.round(img.width * scale)), h = Math.max(1, Math.round(img.height * scale));
#           bgCtx.drawImage(img, (560 - w) / 2, (400 - h) / 2, w, h);
#
#           // The model only recognizes human figures. On art styles or
#           // subjects it doesn't recognize (an anime character, a
#           // creature, an object) it can come back having marked
#           // nothing at all - rather than drop an invisible, empty
#           // floating selection with no explanation, say so plainly
#           // and leave Character for the person to fill in by hand.
#           if (personPixels < 40) {
#             renderOnion(); renderStrip();
#             alert('Auto-Detect looks for a human figure and couldn\'t find one in this picture, so only the Background layer was filled in. Use Import Image above, or draw the Character by hand, to add the subject yourself.');
#           } else {
#             // Character: only the pixels the model marked as the
#             // subject, everything else made transparent, then dropped
#             // in as a floating selection just like Import Image - drag
#             // it into place, same as a manual import.
#             const cut = natural.getContext('2d').getImageData(0, 0, img.width, img.height);
#             for (let i = 0; i < mask.data.length; i++) {
#               if (!mask.data[i]) cut.data[i * 4 + 3] = 0;
#             }
#             const cutCanvasNatural = document.createElement('canvas');
#             cutCanvasNatural.width = img.width; cutCanvasNatural.height = img.height;
#             cutCanvasNatural.getContext('2d').putImageData(cut, 0, 0);
#             const cutScaled = document.createElement('canvas');
#             cutScaled.width = w; cutScaled.height = h;
#             cutScaled.getContext('2d').drawImage(cutCanvasNatural, 0, 0, w, h);
#
#             commitFloatingSelection();
#             activeLayer = targetLayer;
#             const x = Math.round((560 - w) / 2), y = Math.round((400 - h) / 2);
#             selectState = { phase: 'floating', canvas: cutScaled, x, y, w, h, dragging: false, dragOffset: [0, 0], srcCtx: targetCtx };
#             tool = 'select';
#             applyBrush();
#             updateActive();
#             updateLayerButtons();
#             stage.className = 'flip-stage flip-cursor-select';
#             drawFloatingPreview();
#             renderOnion(); renderStrip();
#           }
#         } catch (err) {
#           alert('Auto-Detect needs an internet connection (it downloads a small detection model the first time) and couldn\'t load it: ' + err.message + '. Import Image above works offline if you\'d rather place the layers yourself.');
#         } finally {
#           autoLabelText.textContent = originalLabel;
#         }
#       };
#       img.src = reader.result;
#     };
#     reader.readAsDataURL(file);
#   };
#   autoLabel.appendChild(autoInput);
#
#   // --- auto-rig + walk cycle -------------------------------------------
#   // Builds on Auto-Detect: after finding the subject (BodyPix) it ALSO
#   // runs a pose-detection model (MoveNet) to find the skeleton
#   // (shoulders, elbows, wrists, hips, knees, ankles, nose), slices the
#   // cutout into a paper-doll rig around those joints, and drives the rig
#   // through a procedural walk cycle. Honesty up front: both models are
#   // trained on PHOTOS of real people. On a photo of a person standing
#   // reasonably upright and mostly visible, this usually works; on
#   // illustrated/anime art, a logo, an object, or someone heavily
#   // obscured, pose detection is likely to come back too thin to rig -
#   // in that case this still drops the cutout in as a normal floating
#   // selection, same as Auto-Detect, so the import isn't wasted.
#   let poseDetectorLoad = null;
#   function ensurePoseDetector() {
#     if (!poseDetectorLoad) {
#       poseDetectorLoad = (async () => {
#         if (!window.tf) await loadScript('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.20.0/dist/tf.min.js');
#         if (!window.poseDetection) await loadScript('https://cdn.jsdelivr.net/npm/@tensorflow-models/pose-detection@2.1.3/dist/pose-detection.min.js');
#         return window.poseDetection.createDetector(window.poseDetection.SupportedModels.MoveNet, {
#           modelType: window.poseDetection.movenet.modelType.SINGLEPOSE_LIGHTNING,
#         });
#       })();
#     }
#     return poseDetectorLoad;
#   }
#
#   // Crops a rectangle from `src` into its own small canvas and records
#   // where that rectangle's top-left sits in `src`'s space, so a joint's
#   // position inside the crop can be recovered later.
#   function cropRect(src, srcW, srcH, left, top, right, bottom) {
#     left = Math.max(0, Math.floor(left)); top = Math.max(0, Math.floor(top));
#     right = Math.min(srcW, Math.ceil(right)); bottom = Math.min(srcH, Math.ceil(bottom));
#     const w = Math.max(1, right - left), h = Math.max(1, bottom - top);
#     const c = document.createElement('canvas');
#     c.width = w; c.height = h;
#     c.getContext('2d').drawImage(src, left, top, w, h, 0, 0, w, h);
#     return { canvas: c, left, top };
#   }
#   function cropBone(src, srcW, srcH, p1, p2, padFrac, minPad) {
#     const len = Math.hypot(p2.x - p1.x, p2.y - p1.y);
#     const pad = Math.max(minPad, len * padFrac);
#     return cropRect(src, srcW, srcH, Math.min(p1.x, p2.x) - pad, Math.min(p1.y, p2.y) - pad, Math.max(p1.x, p2.x) + pad, Math.max(p1.y, p2.y) + pad);
#   }
#   // A rig part: its own cropped image, where to draw that image once
#   // translated to its pivot joint, and its rest-pose offset from its
#   // parent's pivot - the offset is what keeps it attached to the parent
#   // as the parent rotates, since it's applied INSIDE the parent's own
#   // translate/rotate (see drawRigPart).
#   function makePart(pivot, crop, parentPivot, anim) {
#     return {
#       canvas: crop.canvas,
#       drawOffsetX: -(pivot.x - crop.left),
#       drawOffsetY: -(pivot.y - crop.top),
#       restVec: parentPivot ? { x: pivot.x - parentPivot.x, y: pivot.y - parentPivot.y } : { x: 0, y: 0 },
#       anim,
#       children: [],
#     };
#   }
#   function drawRigPart(ctx, part, phase) {
#     ctx.save();
#     ctx.translate(part.restVec.x, part.restVec.y);
#     ctx.rotate(part.anim(phase));
#     ctx.drawImage(part.canvas, part.drawOffsetX, part.drawOffsetY);
#     part.children.forEach((child) => drawRigPart(ctx, child, phase));
#     ctx.restore();
#   }
#
#   // Procedural move presets - each drives the rig through `frames`
#   // steps. A looping move (walk/dash) spans one full cycle, meant to
#   // be played with Loop on. A one-shot move (punch/kick/block) plays
#   // through once and holds its last pose for `holdLast` ticks (the
#   // impact/guard frame), using the Hold feature so it reads with
#   // actual weight instead of snapping straight back to neutral.
#   // Amplitudes are in radians/pixels, tuned by eye, not biomechanics.
#   const MOVES = {
#     walk: { frames: 10, loop: true, holdLast: 1 },
#     dash: { frames: 8, loop: true, holdLast: 1 },
#     punch: { frames: 8, loop: false, holdLast: 3 },
#     kick: { frames: 8, loop: false, holdLast: 3 },
#     block: { frames: 6, loop: false, holdLast: 6 },
#   };
#   function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3); }
#   // Fast snap out, then HOLD at full extension - this is the curve for
#   // one-shot strikes, whose generated sequence ends on the frame that
#   // gets frozen via holdLast, so it must read as impact, not neutral.
#   // (A snap-out-then-retract shape would mean the "held" frame is the
#   // pose AFTER the hit relaxes, which looks like nothing landed.)
#   function strikeCurve(u) {
#     const rise = 0.35;
#     return u < rise ? easeOutCubic(u / rise) : 1;
#   }
#   function moveAngle(move, kind, u) {
#     const phase = u * Math.PI * 2;
#     if (move === 'walk' || move === 'dash') {
#       const k = move === 'dash' ? 1.6 : 1; // dash swings bigger, reads as faster
#       const lean = move === 'dash' ? 0.22 : 0; // constant forward lean while dashing
#       if (kind === 'leftThigh') return 0.5 * k * Math.sin(phase);
#       if (kind === 'rightThigh') return 0.5 * k * Math.sin(phase + Math.PI);
#       if (kind === 'leftShin') return 0.55 * k * Math.max(0, -Math.sin(phase + 0.6));
#       if (kind === 'rightShin') return 0.55 * k * Math.max(0, -Math.sin(phase + 0.6 + Math.PI));
#       if (kind === 'leftArm') return 0.42 * k * Math.sin(phase + Math.PI);
#       if (kind === 'rightArm') return 0.42 * k * Math.sin(phase);
#       if (kind === 'leftForearm') return 0.32 * k * Math.max(0, Math.sin(phase + Math.PI + 0.5));
#       if (kind === 'rightForearm') return 0.32 * k * Math.max(0, Math.sin(phase + 0.5));
#       if (kind === 'torso') return lean + 0.05 * Math.sin(phase * 2);
#       if (kind === 'head') return -lean * 0.4 - 0.015 * Math.sin(phase * 2);
#       return 0;
#     }
#     if (move === 'punch') {
#       const p = strikeCurve(u);
#       if (kind === 'rightArm') return -p * 1.3;
#       if (kind === 'rightForearm') return -p * 0.9;
#       if (kind === 'leftArm') return p * 0.25;
#       if (kind === 'leftForearm') return p * 0.15;
#       if (kind === 'leftThigh') return p * 0.1;
#       if (kind === 'rightThigh') return p * 0.12;
#       if (kind === 'torso') return p * 0.22;
#       if (kind === 'head') return -p * 0.06;
#       return 0;
#     }
#     if (move === 'kick') {
#       const p = strikeCurve(u);
#       if (kind === 'rightThigh') return -p * 1.1;
#       if (kind === 'rightShin') return -p * 0.9;
#       if (kind === 'leftThigh') return p * 0.12;
#       if (kind === 'rightArm') return p * 0.35;
#       if (kind === 'leftArm') return -p * 0.3;
#       if (kind === 'torso') return -p * 0.28;
#       if (kind === 'head') return p * 0.05;
#       return 0;
#     }
#     if (move === 'block') {
#       const e = easeOutCubic(Math.min(1, u / 0.5)); // snap up quickly, then hold
#       if (kind === 'leftArm') return -e * 1.1;
#       if (kind === 'rightArm') return e * 1.1;
#       if (kind === 'leftForearm') return -e * 1.0;
#       if (kind === 'rightForearm') return e * 1.0;
#       if (kind === 'leftThigh') return e * 0.12;
#       if (kind === 'rightThigh') return -e * 0.12;
#       if (kind === 'torso') return e * 0.1;
#       if (kind === 'head') return -e * 0.05;
#       return 0;
#     }
#     return 0;
#   }
#   function moveBob(move, u) {
#     const phase = u * Math.PI * 2;
#     if (move === 'walk') return -Math.abs(Math.sin(phase)) * 5;
#     if (move === 'dash') return -Math.abs(Math.sin(phase)) * 7 - 3; // lower stance while dashing
#     if (move === 'punch') return strikeCurve(u) * 3;
#     if (move === 'kick') return strikeCurve(u) * -4; // rises slightly onto the kick
#     if (move === 'block') return Math.min(1, u / 0.5) * 6; // settles into a lower guard stance
#     return 0;
#   }
#
#   const rigLabel = document.createElement('label');
#   rigLabel.className = 'flip-btn flip-btn-accent flip-file-btn';
#   const rigLabelText = document.createElement('span'); rigLabelText.textContent = 'Auto-Rig';
#   rigLabel.appendChild(rigLabelText);
#   rigLabel.title = 'Imports a picture, finds the subject AND its skeleton (shoulders/elbows/hips/knees/etc.), and auto-generates the move picked below onto whichever Character layer is active - run it once per character for a two-person scene. Works best on a clear photo of a person, mostly visible and roughly upright - needs internet the first time, to download the detection models.';
#   const rigMoveSelect = document.createElement('select');
#   rigMoveSelect.className = 'flip-btn';
#   [['walk', 'Walk'], ['dash', 'Dash'], ['punch', 'Punch'], ['kick', 'Kick'], ['block', 'Block']].forEach(([val, label]) => {
#     const o = document.createElement('option'); o.value = val; o.textContent = label;
#     rigMoveSelect.appendChild(o);
#   });
#   const rigInput = document.createElement('input');
#   rigInput.type = 'file'; rigInput.accept = 'image/*';
#   rigInput.onchange = () => {
#     const file = rigInput.files && rigInput.files[0];
#     rigInput.value = '';
#     if (!file) return;
#     // Captured at file-pick time, same as Auto-Detect: whichever
#     // Character layer is active ("Draw on") is the one Auto-Rig
#     // builds the skeleton and generated move onto - run it once per
#     // character to rig a two-person scene.
#     const targetLayer = activeLayer === 'character2' ? 'character2' : 'character';
#     const targetCtx = targetLayer === 'character2' ? ctx2 : ctx;
#     const reader = new FileReader();
#     reader.onload = async () => {
#       const img = new Image();
#       img.onload = async () => {
#         const originalLabel = rigLabelText.textContent;
#         rigLabelText.textContent = 'Loading models...';
#         try {
#           const [net, detector] = await Promise.all([ensureBodyPix(), ensurePoseDetector()]);
#           rigLabelText.textContent = 'Detecting...';
#           const natural = document.createElement('canvas');
#           natural.width = img.width; natural.height = img.height;
#           natural.getContext('2d').drawImage(img, 0, 0);
#           const [mask, poses] = await Promise.all([
#             net.segmentPerson(natural, { internalResolution: 'medium', segmentationThreshold: 0.6 }),
#             detector.estimatePoses(natural),
#           ]);
#           let personPixels = 0;
#           for (let i = 0; i < mask.data.length; i++) if (mask.data[i]) personPixels++;
#
#           const scale = Math.min(560 / img.width, 400 / img.height, 1);
#           const w = Math.max(1, Math.round(img.width * scale)), h = Math.max(1, Math.round(img.height * scale));
#           bgCtx.drawImage(img, (560 - w) / 2, (400 - h) / 2, w, h);
#
#           if (personPixels < 40) {
#             renderOnion(); renderStrip();
#             alert('Auto-Rig looks for a human figure and couldn\'t find one in this picture, so only the Background layer was filled in. Use Import Image above, or draw the Character by hand, to add the subject yourself.');
#             return;
#           }
#
#           const cut = natural.getContext('2d').getImageData(0, 0, img.width, img.height);
#           for (let i = 0; i < mask.data.length; i++) { if (!mask.data[i]) cut.data[i * 4 + 3] = 0; }
#           const cutCanvasNatural = document.createElement('canvas');
#           cutCanvasNatural.width = img.width; cutCanvasNatural.height = img.height;
#           cutCanvasNatural.getContext('2d').putImageData(cut, 0, 0);
#           const cutScaled = document.createElement('canvas');
#           cutScaled.width = w; cutScaled.height = h;
#           cutScaled.getContext('2d').drawImage(cutCanvasNatural, 0, 0, w, h);
#           const x = Math.round((560 - w) / 2), y = Math.round((400 - h) / 2);
#
#           // --- find the skeleton (all joint coords local to cutScaled, i.e. 0..w, 0..h) ---
#           const kps = (poses && poses[0] && poses[0].keypoints) || [];
#           function joint(name, minScore) {
#             const k = kps.find((p) => p.name === name);
#             if (!k || (k.score || 0) < (minScore === undefined ? 0.25 : minScore)) return null;
#             return { x: k.x * scale, y: k.y * scale };
#           }
#           const lsh = joint('left_shoulder', 0.3), rsh = joint('right_shoulder', 0.3);
#           const lhip = joint('left_hip', 0.3), rhip = joint('right_hip', 0.3);
#
#           if (!lsh || !rsh || !lhip || !rhip) {
#             // Not enough of the skeleton to rig a walk cycle - fall back
#             // to dropping the cutout in as a normal movable selection,
#             // same as Auto-Detect, so the import still isn't wasted.
#             commitFloatingSelection();
#             activeLayer = targetLayer;
#             selectState = { phase: 'floating', canvas: cutScaled, x, y, w, h, dragging: false, dragOffset: [0, 0], srcCtx: targetCtx };
#             tool = 'select';
#             applyBrush(); updateActive(); updateLayerButtons();
#             stage.className = 'flip-stage flip-cursor-select';
#             drawFloatingPreview();
#             renderOnion(); renderStrip();
#             alert('Found the subject, but not enough of a clear skeleton (shoulders + hips) to animate - it\'s been dropped in as a normal movable selection instead. This works best on a photo of a person standing, mostly visible and upright.');
#             return;
#           }
#
#           const nose = joint('nose', 0.2);
#           const lel = joint('left_elbow'), rel = joint('right_elbow');
#           const lwr = joint('left_wrist'), rwr = joint('right_wrist');
#           const lkn = joint('left_knee'), rkn = joint('right_knee');
#           const lan = joint('left_ankle'), ran = joint('right_ankle');
#
#           const shoulderC = { x: (lsh.x + rsh.x) / 2, y: (lsh.y + rsh.y) / 2 };
#           const hipC = { x: (lhip.x + rhip.x) / 2, y: (lhip.y + rhip.y) / 2 };
#           const torsoHeight = Math.max(20, hipC.y - shoulderC.y);
#           const shoulderW = Math.hypot(rsh.x - lsh.x, rsh.y - lsh.y);
#
#           const currentMove = rigMoveSelect.value || 'walk';
#           const moveInfo = MOVES[currentMove] || MOVES.walk;
#           function partAnim(kind) { return (u) => moveAngle(currentMove, kind, u); }
#
#           // Padding is generous on purpose - these are rigid, non-
#           // deforming pieces, so adjacent parts only stay visually
#           // connected through a rotation if they overlap well beyond
#           // the bare joint-to-joint line.
#           const torsoPad = Math.max(14, shoulderW * 0.35);
#           const torso = makePart(hipC, cropRect(cutScaled, w, h,
#             Math.min(lsh.x, rsh.x, lhip.x, rhip.x) - torsoPad, Math.min(lsh.y, rsh.y) - torsoPad * 0.6,
#             Math.max(lsh.x, rsh.x, lhip.x, rhip.x) + torsoPad, Math.max(lhip.y, rhip.y) + torsoPad,
#           ), null, partAnim('torso'));
#
#           const headTop = nose ? nose.y - (shoulderC.y - nose.y) * 1.5 - 6 : shoulderC.y - torsoHeight * 0.6;
#           const headCx = nose ? nose.x : shoulderC.x;
#           const headHalfW = Math.max(14, shoulderW * 0.45);
#           const head = makePart(shoulderC, cropRect(cutScaled, w, h, headCx - headHalfW, headTop, headCx + headHalfW, shoulderC.y + torsoPad * 0.6), hipC, partAnim('head'));
#           torso.children.push(head);
#
#           function limb(shoulder, elbow, wrist, armKind, forearmKind) {
#             if (!shoulder || !elbow) return;
#             const upper = makePart(shoulder, cropBone(cutScaled, w, h, shoulder, elbow, 0.55, 14), hipC, partAnim(armKind));
#             torso.children.push(upper);
#             if (wrist) upper.children.push(makePart(elbow, cropBone(cutScaled, w, h, elbow, wrist, 0.55, 13), shoulder, partAnim(forearmKind)));
#           }
#           limb(lsh, lel, lwr, 'leftArm', 'leftForearm');
#           limb(rsh, rel, rwr, 'rightArm', 'rightForearm');
#
#           // Legs are drawn in their own pass, BEFORE the torso (and
#           // everything attached to it), so they land behind it.
#           const legs = [];
#           function leg(hip, knee, ankle, thighKind, shinKind) {
#             if (!hip || !knee) return;
#             const thigh = makePart(hip, cropBone(cutScaled, w, h, hip, knee, 0.5, 16), hipC, partAnim(thighKind));
#             if (ankle) thigh.children.push(makePart(knee, cropBone(cutScaled, w, h, knee, ankle, 0.5, 15), hip, partAnim(shinKind)));
#             legs.push(thigh);
#           }
#           leg(lhip, lkn, lan, 'leftThigh', 'leftShin');
#           leg(rhip, rkn, ran, 'rightThigh', 'rightShin');
#
#           commitFloatingSelection();
#           activeLayer = targetLayer;
#           const steps = moveInfo.frames;
#           const insertAt = activeIndex < frames.length ? activeIndex + 1 : frames.length;
#           const newIndices = [];
#           // The other Character layer isn't part of this generation -
#           // freeze its current pose into every newly-inserted frame so
#           // it doesn't vanish while this one gets its move (same
#           // approach as Keyframe Tween).
#           const otherFrozen = (targetLayer === 'character2' ? draw : draw2).toDataURL('image/png');
#           for (let k = 0; k < steps; k++) {
#             // Looping moves span a full cycle (k/steps never reaches a
#             // repeated 1.0 - the loop wraps via Loop on playback).
#             // One-shot moves run k/(steps-1) so the LAST generated frame
#             // is exactly the held end pose (u=1), not short of it.
#             const u = moveInfo.loop ? k / steps : (steps > 1 ? k / (steps - 1) : 1);
#             const bob = moveBob(currentMove, u);
#             const frameCanvas = document.createElement('canvas');
#             frameCanvas.width = 560; frameCanvas.height = 400;
#             const fctx = frameCanvas.getContext('2d');
#             fctx.save();
#             fctx.translate(x + hipC.x, y + hipC.y + bob);
#             legs.forEach((part) => drawRigPart(fctx, part, u));
#             drawRigPart(fctx, torso, u);
#             fctx.restore();
#
#             const idx = insertAt + k;
#             const data = frameCanvas.toDataURL('image/png');
#             if (targetLayer === 'character2') { frames2.splice(idx, 0, data); frames.splice(idx, 0, otherFrozen); }
#             else { frames.splice(idx, 0, data); frames2.splice(idx, 0, otherFrozen); }
#             holds.splice(idx, 0, (!moveInfo.loop && k === steps - 1) ? moveInfo.holdLast : 1);
#             newIndices.push(idx);
#           }
#           activeIndex = newIndices[newIndices.length - 1];
#           loadFrame(activeIndex);
#           updateLayerButtons();
#           renderOnion(); renderStrip(); renderHold();
#         } catch (err) {
#           alert('Auto-Rig needs an internet connection (it downloads two small detection models the first time) and couldn\'t load them: ' + err.message + '. Import Image above works offline if you\'d rather place and animate the layers yourself.');
#         } finally {
#           rigLabelText.textContent = originalLabel;
#         }
#       };
#       img.src = reader.result;
#     };
#     reader.readAsDataURL(file);
#   };
#   rigLabel.appendChild(rigInput);
#
#   function updateLayerButtons() {
#     charLayerBtn.classList.toggle('flip-active', activeLayer === 'character');
#     char2LayerBtn.classList.toggle('flip-active', activeLayer === 'character2');
#     bgLayerBtn.classList.toggle('flip-active', activeLayer === 'background');
#     bgVisibleBtn.classList.toggle('flip-active', bgVisible);
#   }
#   updateLayerButtons();
#   layersRow.append(charLayerBtn, char2LayerBtn, bgLayerBtn, bgVisibleBtn, clearLayerBtn, importLabel, autoLabel, rigMoveSelect, rigLabel);
#   const layersHint = document.createElement('div');
#   layersHint.className = 'flip-hint';
#   layersHint.textContent = 'Background is one shared layer behind every frame. Character and Character 2 are two independent per-frame layers on the same timeline - New/Save/Duplicate/Delete move both together, so draw/pose one, switch "Draw on" to the other, and pose it for the same frames (a two-character shot). Auto-Detect splits one picture into Background + whichever Character layer is active (needs internet the first time); Auto-Rig does the same but also finds the skeleton and generates the move picked in the dropdown - Walk, Dash, Punch, Kick or Block - onto whichever Character layer is active (best on a clear photo of a person); Import Image places a picture onto whichever layer is active, no internet needed.';
#   layersContent.append(layersLabel, layersRow, layersHint);
#
#   // --- frame (exposure sheet) tab content -------------------------------
#   const frameContent = document.createElement('div');
#   const frameRow = document.createElement('div');
#   frameRow.className = 'flip-row';
#
#   // --- playback + export tab content -------------------------------------
#   const playContent = document.createElement('div');
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
#   // Per-frame exposure ("hold") - classic "on 1s/2s/3s" anime timing,
#   // where a key/impact pose is held for several ticks while a fast
#   // action beat only gets one, instead of every frame taking the same
#   // amount of screen time.
#   const holdLabel = document.createElement('span');
#   holdLabel.className = 'flip-fps';
#   holdLabel.title = 'How many ticks this frame is held for during playback/export - hold impact poses longer, fast motion shorter.';
#   function renderHold() {
#     const h = activeIndex < holds.length ? holds[activeIndex] : 1;
#     holdLabel.textContent = 'Hold: ' + h + 'x';
#   }
#   const holdMinusBtn = mkBtn('−', '', () => FLIP.setHold((activeIndex < holds.length ? holds[activeIndex] : 1) - 1));
#   const holdPlusBtn = mkBtn('+', '', () => FLIP.setHold((activeIndex < holds.length ? holds[activeIndex] : 1) + 1));
#
#   frameRow.append(
#     mkBtn('New', '', () => FLIP.newFrame()),
#     mkBtn('Save', 'flip-btn-accent', () => FLIP.saveFrame()),
#     mkBtn('Duplicate', '', () => FLIP.duplicateFrame()),
#     mkBtn('Delete', '', () => FLIP.deleteFrame()),
#     mkBtn('Flash', '', () => FLIP.insertFlash()),
#     onionBtn,
#     holdMinusBtn, holdLabel, holdPlusBtn,
#   );
#   playRow.append(
#     mkBtn('−', '', () => FLIP.setFps(fps - 1)),
#     fpsLabel,
#     mkBtn('+', '', () => FLIP.setFps(fps + 1)),
#     loopBtn,
#     playBtn,
#     stopBtn,
#     mkBtn('Export', 'flip-btn-accent', () => FLIP.export()),
#     mkBtn('Export Board', '', () => FLIP.exportBoard()),
#   );
#   frameContent.appendChild(frameRow);
#   playContent.appendChild(playRow);
#
#   // --- keyframe tween tab content ---------------------------------------
#   const tweenContent = document.createElement('div');
#   const tweenRow = document.createElement('div');
#   tweenRow.className = 'flip-row';
#   function mkNum(labelText, value, min, max) {
#     const field = document.createElement('label');
#     field.className = 'flip-field'; field.textContent = labelText;
#     const input = document.createElement('input');
#     input.type = 'number'; input.className = 'flip-input'; input.value = String(value);
#     if (min !== undefined) input.min = String(min);
#     if (max !== undefined) input.max = String(max);
#     field.appendChild(input);
#     tweenRow.appendChild(field);
#     return input;
#   }
#   const tweenDx = mkNum('Move X (px)', 0, -560, 560);
#   const tweenDy = mkNum('Move Y (px)', 0, -400, 400);
#   const tweenScale = mkNum('Scale (%)', 100, 10, 400);
#   const tweenRotate = mkNum('Rotate (°)', 0, -360, 360);
#   const tweenOpacity = mkNum('Opacity (%)', 100, 0, 100);
#   const tweenSteps = mkNum('Frames', 4, 1, 24);
#   const easeBtn = mkBtn('Ease: Linear', '', () => FLIP.cycleEase());
#   easeBtn.title = 'Shapes the timing of the in-between frames - Linear moves at a constant rate, Ease In/Out starts or ends slow for weight, Ease In-Out does both (the most natural-feeling motion).';
#   const tweenBtn = mkBtn('Generate Tween', 'flip-btn-accent', () => FLIP.generateTween());
#   tweenRow.append(easeBtn, tweenBtn);
#   const tweenHint = document.createElement('div');
#   tweenHint.className = 'flip-hint';
#   tweenHint.textContent = 'Takes the active layer\'s current drawing (e.g. an imported character) and auto-generates that many in-between frames moving/scaling/rotating/fading it from its current spot to the amounts above, inserted right after the selected frame. Works on Character or Character 2, whichever is active - the other one keeps its current pose through the new frames.';
#   tweenContent.append(tweenRow, tweenHint);
#   function renderEaseBtn() { easeBtn.textContent = 'Ease: ' + EASE_LABELS[easeMode]; }
#
#   addTab('frame', 'Frame', frameContent);
#   addTab('play', 'Play', playContent);
#   addTab('layers', 'Layers', layersContent);
#   addTab('brush', 'Brush', brushContent);
#   addTab('tween', 'Tween', tweenContent);
#   showTab('frame');
#
#   // --- frame strip (exposure sheet) - click a thumbnail to reopen it
#   // for editing, instead of frames only ever being appended ----------
#   const strip = document.createElement('div');
#   strip.className = 'flip-strip';
#
#   // --- drawing --------------------------------------------------------
#   const frames = [];     // Character-layer dataURLs, one per frame slot
#   const frames2 = [];    // Character 2-layer dataURLs - always kept the same length as `frames`, same index = same point in time, so the two characters share one timeline
#   const holds = [];      // exposure count per frame (how many ticks it's held) - "on 1s/2s/3s" timing, parallel to frames
#   let activeIndex = 0;   // index into frames, or === frames.length for a blank unsaved draft
#   let easeMode = 'linear'; // 'linear' | 'in' | 'out' | 'inout' - shapes Tween's interpolation curve
#   const EASE_MODES = ['linear', 'in', 'out', 'inout'];
#   const EASE_LABELS = { linear: 'Linear', in: 'Ease In', out: 'Ease Out', inout: 'Ease In-Out' };
#   function ease(t) {
#     if (easeMode === 'in') return t * t;
#     if (easeMode === 'out') return 1 - (1 - t) * (1 - t);
#     if (easeMode === 'inout') return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
#     return t;
#   }
#   let onionOn = true;
#   let loopOn = true;
#   let fps = 8;
#   let playing = false;
#   let playTimer = null;
#   let drawingNow = false;
#   let last = null;
#
#   function posOf(e) {
#     const r = stage.getBoundingClientRect();
#     const scaleX = 560 / r.width, scaleY = 400 / r.height;
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
#   // color - a stack-based fill over the active layer's own pixel
#   // buffer, tolerant of slightly anti-aliased edges so it doesn't
#   // leave a thin un-filled ring around pencil lines.
#   function hexToRgba(hex) {
#     const n = parseInt(hex.slice(1), 16);
#     return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 255];
#   }
#   function performFill(px, py) {
#     const c = activeCtx();
#     const w = 560, h = 400;
#     const x0 = Math.max(0, Math.min(w - 1, Math.round(px)));
#     const y0 = Math.max(0, Math.min(h - 1, Math.round(py)));
#     const imgData = c.getImageData(0, 0, w, h);
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
#     c.putImageData(imgData, 0, 0);
#   }
#
#   // --- select / transform tool -----------------------------------------
#   let selectState = null; // { phase:'marquee', startPos } | { phase:'floating', canvas, x, y, w, h, dragging, dragOffset, srcCtx }
#   function clearOverlay() { overlayCtx.clearRect(0, 0, 560, 400); }
#   function drawMarquee(x0, y0, x1, y1) {
#     clearOverlay();
#     overlayCtx.save();
#     overlayCtx.setLineDash([6, 4]);
#     overlayCtx.strokeStyle = '#ffffff';
#     overlayCtx.lineWidth = 1.5;
#     overlayCtx.strokeRect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0));
#     overlayCtx.restore();
#   }
#   function drawFloatingPreview() {
#     clearOverlay();
#     if (!selectState || selectState.phase !== 'floating') return;
#     overlayCtx.drawImage(selectState.canvas, selectState.x, selectState.y);
#     overlayCtx.save();
#     overlayCtx.setLineDash([6, 4]);
#     overlayCtx.strokeStyle = '#ffffff';
#     overlayCtx.lineWidth = 1.5;
#     overlayCtx.strokeRect(selectState.x, selectState.y, selectState.w, selectState.h);
#     overlayCtx.restore();
#   }
#   function commitFloatingSelection() {
#     if (!selectState || selectState.phase !== 'floating') return;
#     selectState.srcCtx.drawImage(selectState.canvas, selectState.x, selectState.y);
#     selectState = null;
#     clearOverlay();
#     renderOnion(); renderStrip();
#   }
#   function pointInFloating(p) {
#     return selectState && selectState.phase === 'floating' &&
#       p[0] >= selectState.x && p[0] <= selectState.x + selectState.w &&
#       p[1] >= selectState.y && p[1] <= selectState.y + selectState.h;
#   }
#
#   let startPos = null;     // stroke start, for line/rect/circle
#   let shapeSnapshot = null; // canvas pixels before the current shape preview, so dragging can redraw live without leaving trails
#   let smoothed = null;      // the stabilizer's eased brush position, for Pen tool
#   let inkWidth = 0;        // Ink brush's current (smoothed) stroke width, carried segment to segment
#   let inkSegIndex = 0;     // segments drawn since this stroke started - drives the taper-in ramp
#   let inkLastDir = [0, 0]; // direction of the most recent real (non-dot) ink segment, for the taper-out flick
#   let inkHasMoved = false; // whether this ink stroke has moved enough to need a taper-out at all
#
#   // --- brush texture strokes (Pen tool only) ----------------------------
#   function strokePenSegment(c, x0, y0, x1, y1) {
#     const mid = [(x0 + x1) / 2, (y0 + y1) / 2];
#     c.globalAlpha = 1;
#     c.beginPath(); c.moveTo(x0, y0); c.quadraticCurveTo(x0, y0, mid[0], mid[1]); c.stroke();
#   }
#   function strokePencilSegment(c, x0, y0, x1, y1) {
#     const savedWidth = c.lineWidth;
#     c.lineWidth = Math.max(1, savedWidth * 0.6);
#     c.globalAlpha = 0.8;
#     const mid = [(x0 + x1) / 2, (y0 + y1) / 2];
#     c.beginPath(); c.moveTo(x0, y0); c.quadraticCurveTo(x0, y0, mid[0], mid[1]); c.stroke();
#     c.lineWidth = savedWidth;
#     c.globalAlpha = 1;
#   }
#   function strokeMarkerSegment(c, x0, y0, x1, y1) {
#     const savedWidth = c.lineWidth;
#     c.lineWidth = savedWidth * 1.4;
#     c.globalAlpha = 0.4;
#     const mid = [(x0 + x1) / 2, (y0 + y1) / 2];
#     c.beginPath(); c.moveTo(x0, y0); c.quadraticCurveTo(x0, y0, mid[0], mid[1]); c.stroke();
#     c.lineWidth = savedWidth;
#     c.globalAlpha = 1;
#   }
#   function strokeAirbrushSegment(c, x0, y0, x1, y1) {
#     const dist = Math.hypot(x1 - x0, y1 - y0);
#     const dabCount = Math.max(1, Math.round(dist / 2)) + 3;
#     c.save();
#     c.globalAlpha = 0.12;
#     c.fillStyle = color;
#     for (let i = 0; i < dabCount; i++) {
#       const t = i / dabCount;
#       const cx = x0 + (x1 - x0) * t, cy = y0 + (y1 - y0) * t;
#       const r = brushWidth * (0.4 + Math.random() * 0.6);
#       const ox = (Math.random() - 0.5) * brushWidth;
#       const oy = (Math.random() - 0.5) * brushWidth;
#       c.beginPath(); c.arc(cx + ox, cy + oy, r / 2, 0, Math.PI * 2); c.fill();
#     }
#     c.restore();
#   }
#   // Tapered, variable-width line - the one brush here that isn't a flat
#   // stroke width. Each segment is filled as its own little ribbon from
#   // the width carried out of the previous segment (w0) to a new target
#   // width (w1): wider where the pointer slows or lingers, thinner where
#   // it moves fast, and ramped up from near-zero for the stroke's first
#   // handful of segments so every line actually starts at a point
#   // instead of a stamped-on full-width blob. This is what gives
#   // anime-style inking its characteristic tapered linework instead of
#   // the uniform width every other brush here draws.
#   function strokeInkSegment(c, x0, y0, x1, y1) {
#     const w0 = inkWidth;
#     const dx = x1 - x0, dy = y1 - y0;
#     const dist = Math.hypot(dx, dy);
#     const rampFactor = Math.min(1, (inkSegIndex + 1) / 7);
#     const speedFactor = Math.max(0.3, Math.min(1.35, 1.5 - dist * 0.055));
#     const targetWidth = Math.max(0.6, brushWidth * speedFactor * rampFactor);
#     const w1 = inkSegIndex === 0 ? targetWidth : w0 + (targetWidth - w0) * 0.5;
#     inkWidth = w1;
#     inkSegIndex++;
#     c.globalAlpha = 1;
#     if (dist < 0.5) {
#       c.beginPath(); c.arc(x1, y1, w1 / 2, 0, Math.PI * 2); c.fill();
#       return;
#     }
#     inkHasMoved = true;
#     inkLastDir = [dx / dist, dy / dist];
#     const nx = -dy / dist, ny = dx / dist;
#     const hw0 = w0 / 2, hw1 = w1 / 2;
#     c.beginPath();
#     c.moveTo(x0 + nx * hw0, y0 + ny * hw0);
#     c.lineTo(x1 + nx * hw1, y1 + ny * hw1);
#     c.lineTo(x1 - nx * hw1, y1 - ny * hw1);
#     c.lineTo(x0 - nx * hw0, y0 - ny * hw0);
#     c.closePath();
#     c.fill();
#     // Round off the joint so two segments meeting at an angle don't
#     // leave a visible notch - cheap substitute for a proper line-join.
#     c.beginPath(); c.arc(x1, y1, hw1, 0, Math.PI * 2); c.fill();
#   }
#   // Shrinks the ink line's width down to nothing over a short flick
#   // past the stroke's last point - the taper-out half of the pair,
#   // drawn once on release since (unlike the taper-in) there's no way
#   // to know a stroke has ended until the pointer actually lifts.
#   function inkTaperOut(c) {
#     if (!inkHasMoved || !last || inkWidth <= 0.6) return;
#     const steps = 3;
#     let w0 = inkWidth, x0 = last[0], y0 = last[1];
#     const nx = -inkLastDir[1], ny = inkLastDir[0];
#     c.globalAlpha = 1;
#     for (let i = 1; i <= steps; i++) {
#       const w1 = inkWidth * (1 - i / steps);
#       const x1 = x0 + inkLastDir[0] * (inkWidth * 0.3);
#       const y1 = y0 + inkLastDir[1] * (inkWidth * 0.3);
#       const hw0 = w0 / 2, hw1 = Math.max(0, w1 / 2);
#       c.beginPath();
#       c.moveTo(x0 + nx * hw0, y0 + ny * hw0);
#       c.lineTo(x1 + nx * hw1, y1 + ny * hw1);
#       c.lineTo(x1 - nx * hw1, y1 - ny * hw1);
#       c.lineTo(x0 - nx * hw0, y0 - ny * hw0);
#       c.closePath();
#       c.fill();
#       x0 = x1; y0 = y1; w0 = w1;
#     }
#   }
#   function strokeSegment(c, x0, y0, x1, y1) {
#     if (brushType === 'pencil') strokePencilSegment(c, x0, y0, x1, y1);
#     else if (brushType === 'marker') strokeMarkerSegment(c, x0, y0, x1, y1);
#     else if (brushType === 'airbrush') strokeAirbrushSegment(c, x0, y0, x1, y1);
#     else if (brushType === 'ink') strokeInkSegment(c, x0, y0, x1, y1);
#     else strokePenSegment(c, x0, y0, x1, y1);
#   }
#
#   stage.addEventListener('pointerdown', (e) => {
#     if (playing) return;
#     const p = posOf(e);
#
#     if (tool === 'select') {
#       if (pointInFloating(p)) {
#         selectState.dragging = true;
#         selectState.dragOffset = [p[0] - selectState.x, p[1] - selectState.y];
#       } else {
#         commitFloatingSelection();
#         selectState = { phase: 'marquee', startPos: p };
#       }
#       stage.setPointerCapture(e.pointerId);
#       return;
#     }
#
#     if (tool === 'fill') { performFill(p[0], p[1]); return; }
#
#     const c = activeCtx();
#     drawingNow = true;
#     last = p;
#     startPos = p;
#     smoothed = p;
#     inkWidth = 0; inkSegIndex = 0; inkLastDir = [0, 0]; inkHasMoved = false;
#     stage.setPointerCapture(e.pointerId);
#     if (tool === 'line' || tool === 'rect' || tool === 'circle') {
#       shapeSnapshot = c.getImageData(0, 0, 560, 400);
#     } else if (tool === 'pen') {
#       strokeSegment(c, last[0], last[1], last[0] + 0.01, last[1] + 0.01);
#     } else {
#       // eraser/shade/highlight: a plain dot, not a Pen-tool texture -
#       // keeps shade/highlight's reduced globalAlpha intact instead of
#       // strokeSegment's texture branches overriding it to 1.
#       c.beginPath(); c.moveTo(last[0], last[1]); c.lineTo(last[0] + 0.01, last[1] + 0.01); c.stroke();
#     }
#   });
#
#   stage.addEventListener('pointermove', (e) => {
#     const p = posOf(e);
#
#     if (tool === 'select' && selectState) {
#       if (selectState.phase === 'marquee') { drawMarquee(selectState.startPos[0], selectState.startPos[1], p[0], p[1]); return; }
#       if (selectState.phase === 'floating' && selectState.dragging) {
#         selectState.x = p[0] - selectState.dragOffset[0];
#         selectState.y = p[1] - selectState.dragOffset[1];
#         drawFloatingPreview();
#         return;
#       }
#       return;
#     }
#
#     if (!drawingNow) return;
#     const c = activeCtx();
#
#     if (tool === 'pen' || tool === 'eraser' || tool === 'shade' || tool === 'highlight') {
#       let target = p;
#       if (tool === 'pen' && smooth) {
#         smoothed = [smoothed[0] + (p[0] - smoothed[0]) * 0.35, smoothed[1] + (p[1] - smoothed[1]) * 0.35];
#         target = smoothed;
#       }
#       if (tool === 'pen') {
#         strokeSegment(c, last[0], last[1], target[0], target[1]);
#       } else {
#         // eraser/shade/highlight: a plain round stroke - the effect
#         // comes from globalCompositeOperation (set in applyBrush), not
#         // from a Pen-tool texture.
#         const mid = [(last[0] + target[0]) / 2, (last[1] + target[1]) / 2];
#         c.beginPath(); c.moveTo(last[0], last[1]); c.quadraticCurveTo(last[0], last[1], mid[0], mid[1]); c.stroke();
#       }
#       last = target;
#       return;
#     }
#
#     // line/rect/circle: restore the pre-shape pixels, then draw the
#     // shape fresh from startPos to the current pointer, so dragging
#     // around previews live without leaving a trail of old attempts.
#     c.putImageData(shapeSnapshot, 0, 0);
#     let end = p;
#     if (tool === 'line' && e.shiftKey) end = snapAngle(startPos[0], startPos[1], p[0], p[1]);
#     c.beginPath();
#     if (tool === 'line') {
#       c.moveTo(startPos[0], startPos[1]); c.lineTo(end[0], end[1]);
#     } else if (tool === 'rect') {
#       c.rect(startPos[0], startPos[1], end[0] - startPos[0], end[1] - startPos[1]);
#     } else if (tool === 'circle') {
#       const rx = Math.abs(end[0] - startPos[0]) / 2, ry = Math.abs(end[1] - startPos[1]) / 2;
#       const cx = (startPos[0] + end[0]) / 2, cy = (startPos[1] + end[1]) / 2;
#       c.ellipse(cx, cy, Math.max(rx, 0.01), Math.max(ry, 0.01), 0, 0, Math.PI * 2);
#     }
#     c.stroke();
#   });
#
#   function endStroke(e) {
#     if (tool === 'select' && selectState) {
#       const p = posOf(e);
#       if (selectState.phase === 'marquee') {
#         const x = Math.min(selectState.startPos[0], p[0]);
#         const y = Math.min(selectState.startPos[1], p[1]);
#         const w = Math.abs(p[0] - selectState.startPos[0]);
#         const h = Math.abs(p[1] - selectState.startPos[1]);
#         clearOverlay();
#         if (w < 2 || h < 2) { selectState = null; return; }
#         const srcCtx = activeCtx();
#         const clipped = { x: Math.max(0, Math.round(x)), y: Math.max(0, Math.round(y)), w: Math.round(Math.min(w, 560 - x)), h: Math.round(Math.min(h, 400 - y)) };
#         const lifted = srcCtx.getImageData(clipped.x, clipped.y, clipped.w, clipped.h);
#         const off = document.createElement('canvas');
#         off.width = clipped.w; off.height = clipped.h;
#         off.getContext('2d').putImageData(lifted, 0, 0);
#         srcCtx.clearRect(clipped.x, clipped.y, clipped.w, clipped.h);
#         selectState = { phase: 'floating', canvas: off, x: clipped.x, y: clipped.y, w: clipped.w, h: clipped.h, dragging: false, dragOffset: [0, 0], srcCtx };
#         drawFloatingPreview();
#       } else if (selectState.phase === 'floating') {
#         selectState.dragging = false;
#       }
#       return;
#     }
#     if (drawingNow && tool === 'pen' && brushType === 'ink') inkTaperOut(activeCtx());
#     drawingNow = false;
#     shapeSnapshot = null;
#   }
#   stage.addEventListener('pointerup', endStroke);
#   stage.addEventListener('pointerleave', (e) => { if (tool !== 'select') endStroke(e); });
#
#   function clearCanvas() { ctx.clearRect(0, 0, 560, 400); }
#   function clearCanvas2() { ctx2.clearRect(0, 0, 560, 400); }
#
#   // Loads a dataURL into an <img>, resolving null for a missing/blank
#   // source instead of rejecting - used everywhere two character layers
#   // need to be fetched in parallel (one of the two is very often empty
#   // for a given frame) without one missing layer breaking the other.
#   function loadImg(src) {
#     return new Promise((resolve) => {
#       if (!src) { resolve(null); return; }
#       const img = new Image();
#       img.onload = () => resolve(img);
#       img.onerror = () => resolve(null);
#       img.src = src;
#     });
#   }
#
#   function loadFrame(idx) {
#     clearCanvas(); clearCanvas2();
#     if (idx >= 0 && idx < frames.length && frames[idx]) {
#       const img = new Image();
#       img.onload = () => ctx.drawImage(img, 0, 0, 560, 400);
#       img.src = frames[idx];
#     }
#     if (idx >= 0 && idx < frames2.length && frames2[idx]) {
#       const img2 = new Image();
#       img2.onload = () => ctx2.drawImage(img2, 0, 0, 560, 400);
#       img2.src = frames2[idx];
#     }
#   }
#
#   // Composites the background layer (if visible) with the two
#   // character-layer images onto a fresh canvas and returns it - used
#   // for the onion ghost, thumbnails, playback and export, all of which
#   // need every layer flattened into one picture. Character 2 is drawn
#   // on top of Character, matching their front-to-back stacking live.
#   function compositeWith(characterImg, character2Img) {
#     const c = document.createElement('canvas');
#     c.width = 560; c.height = 400;
#     const cx = c.getContext('2d');
#     cx.fillStyle = '#e9e6da';
#     cx.fillRect(0, 0, 560, 400);
#     if (bgVisible) cx.drawImage(bg, 0, 0);
#     if (characterImg) cx.drawImage(characterImg, 0, 0, 560, 400);
#     if (character2Img) cx.drawImage(character2Img, 0, 0, 560, 400);
#     return c;
#   }
#   function compositeFrame(idx, cb) {
#     if (idx < 0 || idx >= frames.length) { cb(compositeWith(null, null)); return; }
#     Promise.all([loadImg(frames[idx]), loadImg(frames2[idx])]).then(([img1, img2]) => cb(compositeWith(img1, img2)));
#   }
#
#   function renderOnion() {
#     onionCtx.clearRect(0, 0, 560, 400);
#     onionCtx.fillStyle = '#e9e6da';
#     onionCtx.fillRect(0, 0, 560, 400);
#     const prevIdx = activeIndex - 1;
#     if (onionOn && prevIdx >= 0 && prevIdx < frames.length) {
#       Promise.all([loadImg(frames[prevIdx]), loadImg(frames2[prevIdx])]).then(([img1, img2]) => {
#         onionCtx.globalAlpha = 0.3;
#         if (img1) onionCtx.drawImage(img1, 0, 0, 560, 400);
#         if (img2) onionCtx.drawImage(img2, 0, 0, 560, 400);
#         onionCtx.globalAlpha = 1;
#       });
#     }
#   }
#   function renderStrip() {
#     strip.innerHTML = '';
#     frames.forEach((f, i) => {
#       const t = document.createElement('div');
#       t.className = 'flip-thumb' + (i === activeIndex ? ' flip-thumb-active' : '');
#       t.title = 'Frame ' + (i + 1) + ' - click to reopen for editing';
#       t.onclick = () => FLIP.selectFrame(i);
#       strip.appendChild(t);
#       compositeFrame(i, (c) => { t.style.backgroundImage = "url('" + c.toDataURL('image/png') + "')"; });
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
#       commitFloatingSelection();
#       activeIndex = frames.length;
#       clearCanvas(); clearCanvas2();
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     // Snapshots BOTH character canvases together into this frame slot -
#     // draw/pose Character, switch "Draw on" to Character 2, pose it too,
#     // then one Save captures both for this point in the timeline.
#     saveFrame() {
#       commitFloatingSelection();
#       const data = draw.toDataURL('image/png');
#       const data2 = draw2.toDataURL('image/png');
#       if (activeIndex < frames.length) {
#         frames[activeIndex] = data;
#         frames2[activeIndex] = data2;
#       } else {
#         frames.push(data);
#         frames2.push(data2);
#         holds.push(1);
#         activeIndex = frames.length - 1;
#       }
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     duplicateFrame() {
#       if (!frames.length) return;
#       commitFloatingSelection();
#       const srcIdx = Math.min(activeIndex, frames.length - 1);
#       frames.splice(srcIdx + 1, 0, frames[srcIdx]);
#       frames2.splice(srcIdx + 1, 0, frames2[srcIdx]);
#       holds.splice(srcIdx + 1, 0, holds[srcIdx]);
#       activeIndex = srcIdx + 1;
#       loadFrame(activeIndex);
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     deleteFrame() {
#       if (!frames.length || activeIndex >= frames.length) return;
#       commitFloatingSelection();
#       frames.splice(activeIndex, 1);
#       frames2.splice(activeIndex, 1);
#       holds.splice(activeIndex, 1);
#       if (!frames.length) {
#         activeIndex = 0;
#         clearCanvas(); clearCanvas2();
#       } else {
#         if (activeIndex >= frames.length) activeIndex = frames.length - 1;
#         loadFrame(activeIndex);
#       }
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     selectFrame(idx) {
#       if (playing) return;
#       commitFloatingSelection();
#       activeIndex = idx;
#       loadFrame(idx);
#       renderOnion();
#       renderStrip();
#       renderHold();
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
#     // Reads whichever Character layer is active's CURRENT bitmap as a
#     // single "object" (e.g. an imported character image) and
#     // auto-generates `steps` new frames right after the selected one,
#     // each redrawing that bitmap at a linearly interpolated position/
#     // scale/rotation/opacity between where it is now and the amounts
#     // entered in the panel. Only a Character layer can be tweened this
#     // way - Background is one layer shared by every frame, so it has
#     // no "per frame" version to animate between. The OTHER character
#     // layer isn't being tweened here, so each new frame slot just
#     // repeats its current pose, instead of going blank, while this one
#     // moves - switch layers afterward to animate it through the same
#     // stretch.
#     generateTween() {
#       commitFloatingSelection();
#       if (activeLayer === 'background') {
#         alert('Keyframe Tween animates a Character layer. Background is shared by every frame, so it can\'t be tweened per frame - switch "Draw on" to Character or Character 2 first.');
#         return;
#       }
#       const onChar2 = activeLayer === 'character2';
#       const movingCanvas = onChar2 ? draw2 : draw;
#       const otherFrozen = (onChar2 ? draw : draw2).toDataURL('image/png');
#       const dx = Number(tweenDx.value) || 0;
#       const dy = Number(tweenDy.value) || 0;
#       const scalePct = Number(tweenScale.value) || 100;
#       const rotateDeg = Number(tweenRotate.value) || 0;
#       const opacityPct = Math.max(0, Math.min(100, Number(tweenOpacity.value) || 0));
#       const steps = Math.max(1, Math.min(24, Math.round(Number(tweenSteps.value)) || 1));
#
#       const movingSrc = document.createElement('canvas');
#       movingSrc.width = 560; movingSrc.height = 400;
#       movingSrc.getContext('2d').drawImage(movingCanvas, 0, 0);
#
#       const insertAt = activeIndex < frames.length ? activeIndex + 1 : frames.length;
#       const newIndices = [];
#       for (let step = 1; step <= steps; step++) {
#         const t = ease(step / steps);
#         // Character-layer frames are transparent except where drawn -
#         // the background (if any) is composited in separately at
#         // render/export time, so this canvas must stay transparent,
#         // not filled with the paper color.
#         const frameCanvas = document.createElement('canvas');
#         frameCanvas.width = 560; frameCanvas.height = 400;
#         const fctx = frameCanvas.getContext('2d');
#         fctx.save();
#         fctx.globalAlpha = Math.max(0, Math.min(1, 1 + (opacityPct - 100) / 100 * t));
#         const cx = 280 + dx * t, cy = 200 + dy * t;
#         fctx.translate(cx, cy);
#         fctx.rotate((rotateDeg * t) * Math.PI / 180);
#         const s = 1 + (scalePct - 100) / 100 * t;
#         fctx.scale(s, s);
#         fctx.translate(-280, -200);
#         fctx.drawImage(movingSrc, 0, 0, 560, 400);
#         fctx.restore();
#
#         const idx = insertAt + step - 1;
#         const data = frameCanvas.toDataURL('image/png');
#         if (onChar2) { frames2.splice(idx, 0, data); frames.splice(idx, 0, otherFrozen); }
#         else { frames.splice(idx, 0, data); frames2.splice(idx, 0, otherFrozen); }
#         holds.splice(idx, 0, 1);
#         newIndices.push(idx);
#       }
#
#       activeIndex = newIndices[newIndices.length - 1];
#       loadFrame(activeIndex);
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     // Inserts a single, fully opaque near-white frame right after the
#     // selected one - a classic anime "impact flash" cut. It's stored
#     // on the Character layer (so it fully covers the Background too,
#     // which is what sells the flash) with Character 2 left blank at
#     // that index - the opaque white frame already covers the whole
#     // picture, so there's nothing for a second layer to add there -
#     // and starts with hold 1 - bump the hold if you want the white to
#     // linger.
#     insertFlash() {
#       commitFloatingSelection();
#       const flashCanvas = document.createElement('canvas');
#       flashCanvas.width = 560; flashCanvas.height = 400;
#       const fctx = flashCanvas.getContext('2d');
#       fctx.fillStyle = '#ffffff';
#       fctx.fillRect(0, 0, 560, 400);
#       const idx = activeIndex < frames.length ? activeIndex + 1 : frames.length;
#       frames.splice(idx, 0, flashCanvas.toDataURL('image/png'));
#       frames2.splice(idx, 0, '');
#       holds.splice(idx, 0, 1);
#       activeIndex = idx;
#       loadFrame(activeIndex);
#       renderOnion();
#       renderStrip();
#       renderHold();
#     },
#     cycleEase() {
#       easeMode = EASE_MODES[(EASE_MODES.indexOf(easeMode) + 1) % EASE_MODES.length];
#       renderEaseBtn();
#       return easeMode;
#     },
#     setHold(n) {
#       const clamped = Math.max(1, Math.min(24, Math.round(n) || 1));
#       if (activeIndex < holds.length) holds[activeIndex] = clamped;
#       renderHold();
#       return clamped;
#     },
#     play() {
#       if (!frames.length || playing) return;
#       playing = true;
#       draw.style.visibility = 'hidden';
#       draw2.style.visibility = 'hidden';
#       bg.style.visibility = 'hidden';
#       let i = 0;
#       onionCtx.clearRect(0, 0, 560, 400);
#       const showFrame = () => {
#         if (i >= frames.length) {
#           if (loopOn) { i = 0; } else { this.stop(); return; }
#         }
#         compositeFrame(i, (c) => {
#           onionCtx.clearRect(0, 0, 560, 400);
#           onionCtx.drawImage(c, 0, 0);
#         });
#         const dur = (1000 / fps) * Math.max(1, holds[i] || 1);
#         i++;
#         playTimer = setTimeout(showFrame, dur);
#       };
#       showFrame();
#     },
#     stop() {
#       playing = false;
#       clearTimeout(playTimer);
#       draw.style.visibility = 'visible';
#       draw2.style.visibility = 'visible';
#       bg.style.visibility = bgVisible ? 'visible' : 'hidden';
#       renderOnion();
#     },
#     export() {
#       const pending = frames.map((_, i) => new Promise((resolve) => compositeFrame(i, (c) => resolve(c.toDataURL('image/png')))));
#       Promise.all(pending).then((composited) => {
#         const html = '<!doctype html><html><head><meta charset="utf-8"><title>My Flipbook</title>' +
#           '<style>body{margin:0;background:#111;display:flex;align-items:center;justify-content:center;height:100vh}' +
#           'canvas{background:#e9e6da;border-radius:12px;box-shadow:0 20px 50px rgba(0,0,0,.5)}</style></head><body>' +
#           '<canvas id="c" width="560" height="400"></canvas><script>' +
#           'const frames=' + JSON.stringify(composited) + ';const holds=' + JSON.stringify(holds) + ';const fps=' + fps + ';const loop=' + loopOn + ';' +
#           'const ctx=document.getElementById("c").getContext("2d");let i=0;const img=new Image();' +
#           'img.onload=()=>ctx.drawImage(img,0,0,560,400);' +
#           'let timer=null;function tick(){if(i>=frames.length){if(loop){i=0;}else{return;}}img.src=frames[i];const dur=(1000/fps)*Math.max(1,holds[i]||1);i++;timer=setTimeout(tick,dur);}' +
#           'if(frames.length){tick();}' +
#           '</scr' + 'ipt></body></html>';
#         const blob = new Blob([html], { type: 'text/html' });
#         const a = document.createElement('a');
#         a.href = URL.createObjectURL(blob);
#         a.download = 'my-flipbook.html';
#         a.click();
#       });
#     },
#     // Lays every saved frame out top-to-bottom into one tall image and
#     // downloads it as a PNG - a manhwa-style scroll page/board.
#     exportBoard() {
#       if (!frames.length) return;
#       const pending = frames.map((_, i) => new Promise((resolve) => compositeFrame(i, resolve)));
#       Promise.all(pending).then((canvases) => {
#         const gap = 16;
#         const board = document.createElement('canvas');
#         board.width = 560;
#         board.height = canvases.length * 400 + (canvases.length - 1) * gap;
#         const bctx = board.getContext('2d');
#         bctx.fillStyle = '#0b0c10';
#         bctx.fillRect(0, 0, board.width, board.height);
#         canvases.forEach((c, i) => bctx.drawImage(c, 0, i * (400 + gap)));
#         const a = document.createElement('a');
#         a.href = board.toDataURL('image/png');
#         a.download = 'flipbook-board.png';
#         a.click();
#       });
#     },
#   };
#
#   window.addEventListener('DOMContentLoaded', () => {
#     const volt = document.getElementById('volt');
#     volt.append(stage, toolsPanel, tabPanel, strip);
#     renderFps();
#     renderOnion();
#     updateFrameToggles();
#     renderHold();
#     renderEaseBtn();
#   });
# })();
