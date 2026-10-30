// =====================================================================
// Floor Forge - a level/tile editor for Moonwell, written in Volt.
//
// Paint a Moonwell dungeon floor with the exact same tile codes
// Moonwell's maps array already uses (see examples/dungeon/moonwell.volt,
// the comment above "let shopRows ="), using the real tileset for
// previews, then export the result as a ready-to-paste Volt map literal
// - "let roomsNEW = [ \"...\", ... ]" - with the right quoting, straight
// into moonwell.volt's maps list.
//
// This is a standalone app, not a library: compile this file as-is.
// Everything is Volt - the grid, the palette, the import/export text -
// built as HTML strings and shown with `html`. Raw JavaScript (# lines)
// only covers reading/writing plain <input>/<textarea> form fields,
// which Volt has no word for yet.
//
// Compile with:  node volt.js level-editor-template.volt  (or Preview in Volt Studio)
// =====================================================================
#html

image tiles = "../../examples/dungeon/dungeon.png"
let tilesSrc = ""
# tilesSrc = tiles.src;

// ------------------------------ design --------------------------------
## :root { color-scheme: dark; --ink:#F2F3FA; --ink2:#B9BEDB; --bg:#13111C; --panel:#1C1830; --panel2:#241F3D; --edge:#352E54; --acc:#7C6CF0; --acc2:#5B4FCF; --warn:#FF6A6A; --good:#4CD3A0; --font:'Nunito',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif; --mono:'JetBrains Mono',ui-monospace,Menlo,Consolas,monospace; }
## * { box-sizing: border-box; }
## body { margin:0 auto; max-width:1400px; padding:16px; background:var(--bg); color:var(--ink); font-family:var(--font); }
## h1 { font-size: 22px; margin: 0 0 4px; }
## .sub { color: var(--ink2); font-size: 13px; margin: 0 0 16px; }
## .panel { background: var(--panel); border: 1px solid var(--edge); border-radius: 12px; padding: 12px; margin-bottom: 12px; }
## .row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
## .btn { background: var(--panel2); color: var(--ink); border: 1px solid var(--edge); border-radius: 8px; padding: 7px 12px; font-size: 13px; cursor: pointer; font-family: var(--font); }
## .btn:hover { border-color: var(--acc); }
## .btn.acc { background: var(--acc); border-color: var(--acc); color: #fff; font-weight: 700; }
## .btn.sm { padding: 4px 8px; font-size: 12px; }
## .num { width: 56px; background: var(--panel2); color: var(--ink); border: 1px solid var(--edge); border-radius: 6px; padding: 5px 6px; font-family: var(--mono); font-size: 13px; }
## .txt { background: var(--panel2); color: var(--ink); border: 1px solid var(--edge); border-radius: 6px; padding: 5px 8px; font-family: var(--mono); font-size: 13px; }
## .groupLabel { font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--ink2); margin: 10px 0 4px; }
## .palette { display: flex; flex-wrap: wrap; gap: 4px; }
## .swatch { width: 30px; height: 30px; border: 2px solid var(--edge); border-radius: 6px; cursor: pointer; background-color: #2a2540; background-repeat: no-repeat; image-rendering: pixelated; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; color: #fff; text-shadow: 0 1px 2px #000; position: relative; }
## .swatch:hover { border-color: var(--ink2); }
## .swatch.sel { border-color: var(--acc); box-shadow: 0 0 0 2px var(--acc); }
## .gridWrap { overflow: auto; border: 1px solid var(--edge); border-radius: 8px; background: #0b0a12; max-height: 70vh; }
## .gridInner { display: grid; width: max-content; }
## .cell { width: 16px; height: 16px; background-color: #211c34; background-repeat: no-repeat; image-rendering: pixelated; cursor: pointer; font-size: 8px; font-weight: 800; color: #fff; text-align: center; line-height: 16px; user-select: none; }
## .cell:hover { outline: 1px solid var(--acc); outline-offset: -1px; }
## .status { font-size: 12px; color: var(--good); min-height: 16px; }
## .modal { position: fixed; inset: 0; background: rgba(0,0,0,.6); display: flex; align-items: center; justify-content: center; z-index: 10; padding: 16px; }
## .modalBox { background: var(--panel); border: 1px solid var(--edge); border-radius: 12px; padding: 16px; max-width: 700px; width: 100%; }
## .modalBox textarea { width: 100%; min-height: 240px; background: #0b0a12; color: var(--good); border: 1px solid var(--edge); border-radius: 8px; padding: 10px; font-family: var(--mono); font-size: 12px; white-space: pre; }
## .legend { font-size: 11px; color: var(--ink2); line-height: 1.6; }
## @media (max-width: 700px) { .cell { width: 14px; height: 14px; line-height: 14px; } }

// -------------------------------- state --------------------------------
let W = 30
let H = 20
let cells = []
let selCode = "#"
let selLabel = "Wall"
let floorName = "roomsNEW"
let statusMsg = ""
let advanced = 0
let modal = ""   // "", "export" or "import"

// ---------------------- the legend (from moonwell.volt) ----------------
// #  wall          .  floor        P  start      ^  spikes
// D  locked door   f  moonwater    u  its basin  b  banner
// r  lava fall     v  lava pool    x  old bones  L  ladder down
// k  chest (key)   c  chest (gold) w  chest (weapon)
// $  coin          h  potion       K  the mage   1-6  things for sale
// monsters:  g goblin  s skeleton  o orc  z chort  Z zombie  i ice zombie
//            m slime  M masked orc  S shaman  N necromancer  t tiny zombie
//            I imp    B the floor's boss
// Sprite coordinates below are copied from moonwell.volt's own sprite
// list, so previews match the real game exactly.

fn tileName(ch) {
  if ch == "#" { return "Wall" }
  if ch == "." { return "Floor" }
  if ch == "P" { return "Player start" }
  if ch == "L" { return "Ladder down" }
  if ch == "^" { return "Spikes" }
  if ch == "D" { return "Locked door (place 2 wide)" }
  if ch == "f" { return "Moonwater" }
  if ch == "u" { return "Basin (blue light)" }
  if ch == "r" { return "Lava fall" }
  if ch == "v" { return "Lava pool (orange light)" }
  if ch == "x" { return "Old bones" }
  if ch == "b" { return "Banner" }
  if ch == "k" { return "Chest (key)" }
  if ch == "c" { return "Chest (gold)" }
  if ch == "w" { return "Chest (weapon)" }
  if ch == "$" { return "Coin" }
  if ch == "h" { return "Potion" }
  if ch == "K" { return "The mage (camp only)" }
  if ch == "B" { return "Floor boss" }
  if ch == "g" { return "Goblin" }
  if ch == "s" { return "Skeleton" }
  if ch == "o" { return "Orc" }
  if ch == "z" { return "Chort" }
  if ch == "Z" { return "Zombie" }
  if ch == "i" { return "Ice zombie" }
  if ch == "m" { return "Slime" }
  if ch == "M" { return "Masked orc" }
  if ch == "S" { return "Shaman" }
  if ch == "N" { return "Necromancer" }
  if ch == "t" { return "Tiny zombie" }
  if ch == "I" { return "Imp" }
  if ch == "q" { return "Secret room marker" }
  if ch == "*" { return "Moon shard (story item)" }
  return "Shop item (floor 0 only)"
}

// background-position/size for the real tileset, at native 16px (no
// zoom), for codes that have proper art. Codes with no direct sprite
// (monsters, shop digits/letters) fall back to a coloured letter badge.
fn tileCss(ch) {
  if ch == "#" { return "background-image:url(" + tilesSrc + ");background-position:-32px -16px;background-size:512px 512px;" }
  if ch == "." { return "background-image:url(" + tilesSrc + ");background-position:-16px -64px;background-size:512px 512px;" }
  if ch == "P" { return "background-image:url(" + tilesSrc + ");background-position:-128px -106px;background-size:512px 512px;" }
  if ch == "L" { return "background-image:url(" + tilesSrc + ");background-position:-48px -96px;background-size:512px 512px;" }
  if ch == "^" { return "background-image:url(" + tilesSrc + ");background-position:-16px -176px;background-size:512px 512px;" }
  if ch == "D" { return "background-image:url(" + tilesSrc + ");background-position:-32px -224px;background-size:512px 512px;" }
  if ch == "f" { return "background-image:url(" + tilesSrc + ");background-position:-64px -48px;background-size:512px 512px;" }
  if ch == "u" { return "background-image:url(" + tilesSrc + ");background-position:-64px -64px;background-size:512px 512px;" }
  if ch == "r" { return "background-image:url(" + tilesSrc + ");background-position:-64px -16px;background-size:512px 512px;" }
  if ch == "v" { return "background-image:url(" + tilesSrc + ");background-position:-64px -32px;background-size:512px 512px;" }
  if ch == "x" { return "background-image:url(" + tilesSrc + ");background-position:-288px -320px;background-size:512px 512px;" }
  if ch == "b" { return "background-image:url(" + tilesSrc + ");background-position:-16px -32px;background-size:512px 512px;" }
  if ch == "k" or ch == "c" or ch == "w" { return "background-image:url(" + tilesSrc + ");background-position:-304px -304px;background-size:512px 512px;" }
  if ch == "$" { return "background-image:url(" + tilesSrc + ");background-position:-288px -272px;background-size:512px 512px;" }
  if ch == "h" { return "background-image:url(" + tilesSrc + ");background-position:-288px -240px;background-size:512px 512px;" }
  if ch == "K" { return "background-image:url(" + tilesSrc + ");background-position:-128px -170px;background-size:512px 512px;" }
  if ch == "B" { return "background-color:#5a1030;" }
  if contains("gsozZimMSNtI", ch) { return "background-color:#3a1a1a;" }
  if ch == "q" { return "background-color:#1a3a2a;" }
  if ch == "*" { return "background-color:#3a3010;" }
  return "background-color:#2a2540;"
}

fn tileGlyph(ch) {
  if ch == "B" or contains("gsozZimMSNtI", ch) { return ch }
  if contains("0123456789adejlnpUVXYq", ch) { return ch }
  return ""
}

// -------------------------------- grid ----------------------------------
fn resetGrid(w, h) {
  let newCells = []
  let total = w * h
  let i = 0
  while i < total {
    add "#" to newCells
    i += 1
  }
  cells = newCells
  W = w
  H = h
}

fn paintCell(i) {
  if i >= 0 and i < length(cells) {
    cells[i] = selCode
  }
  render()
}

fn pickTool(code, label) {
  selCode = code
  selLabel = label
  render()
}

fn fillAll() {
  let i = 0
  while i < length(cells) {
    cells[i] = selCode
    i += 1
  }
  statusMsg = "Filled the whole floor with " + selLabel + "."
  render()
}

fn doResize(nw, nh) {
  let ow = W
  let oh = H
  let newCells = []
  let ty = 0
  while ty < nh {
    let tx = 0
    while tx < nw {
      let ch = "#"
      if tx < ow and ty < oh {
        ch = cells[ty * ow + tx]
      }
      add ch to newCells
      tx += 1
    }
    ty += 1
  }
  cells = newCells
  W = nw
  H = nh
  statusMsg = "Resized to " + text(nw) + " x " + text(nh) + "."
  render()
}

fn newFloor() {
  resetGrid(W, H)
  statusMsg = "Blank " + text(W) + " x " + text(H) + " floor - all walls."
  render()
}

// ---------------------------- html pieces -------------------------------
fn toolbarHtml() {
  let h = "<div class='panel'><div class='row'>"
  h += "<button class='btn acc' onclick='newFloor()'>New floor</button>"
  h += "<label>W <input class='num' id='wIn' type='number' value='" + text(W) + "' min='5' max='90'></label>"
  h += "<label>H <input class='num' id='hIn' type='number' value='" + text(H) + "' min='5' max='70'></label>"
  h += "<button class='btn' onclick='applyResize()'>Resize</button>"
  h += "<button class='btn' onclick='fillAll()'>Fill all with selected</button>"
  h += "<button class='btn' onclick='openImport()'>Import</button>"
  h += "<button class='btn' onclick='openExport()'>Export</button>"
  h += "</div><div class='status'>" + esc(statusMsg) + "</div></div>"
  return h
}

fn swatch(code, label) {
  let cls = "swatch"
  if code == selCode { cls = "swatch sel" }
  let glyph = tileGlyph(code)
  return "<div class='" + cls + "' style='" + tileCss(code) + "' title='" + esc(code) + " - " + esc(label) + "' onclick=\"pickTool('" + code + "', '" + esc(label) + "')\">" + glyph + "</div>"
}

fn paletteHtml() {
  let h = "<div class='panel'>"
  h += "<div class='groupLabel'>Selected: " + esc(selCode) + " - " + esc(selLabel) + "</div>"
  h += "<div class='groupLabel'>Structure</div><div class='palette'>"
  h += swatch("#", "Wall") + swatch(".", "Floor") + swatch("P", "Player start") + swatch("L", "Ladder down")
  h += "</div>"
  h += "<div class='groupLabel'>Hazards &amp; decor</div><div class='palette'>"
  h += swatch("^", "Spikes") + swatch("D", "Locked door") + swatch("f", "Moonwater") + swatch("u", "Basin (light)") + swatch("r", "Lava fall") + swatch("v", "Lava pool (light)") + swatch("x", "Old bones") + swatch("b", "Banner")
  h += "</div>"
  h += "<div class='groupLabel'>Pickups</div><div class='palette'>"
  h += swatch("k", "Chest (key)") + swatch("c", "Chest (gold)") + swatch("w", "Chest (weapon)") + swatch("$", "Coin") + swatch("h", "Potion")
  h += "</div>"
  h += "<div class='groupLabel'>NPC &amp; boss</div><div class='palette'>"
  h += swatch("K", "The mage (camp only)") + swatch("B", "Floor boss") + swatch("*", "Moon shard")
  h += "</div>"
  h += "<div class='groupLabel'>Monsters</div><div class='palette'>"
  h += swatch("g", "Goblin") + swatch("s", "Skeleton") + swatch("o", "Orc") + swatch("z", "Chort") + swatch("Z", "Zombie") + swatch("i", "Ice zombie") + swatch("m", "Slime") + swatch("M", "Masked orc") + swatch("S", "Shaman") + swatch("N", "Necromancer") + swatch("t", "Tiny zombie") + swatch("I", "Imp")
  h += "</div>"
  let toggleLabel = "Show"
  if advanced == 1 { toggleLabel = "Hide" }
  h += "<div class='row' style='margin-top:8px'><button class='btn sm' onclick='toggleAdvanced()'>" + toggleLabel + " camp/shop items (floor 0 only)</button></div>"
  if advanced == 1 {
    h += "<div class='groupLabel'>Secret &amp; camp-shop (floor 0)</div><div class='palette'>"
    h += swatch("q", "Secret room marker")
    h += swatch("1", "Shop slot 1") + swatch("2", "Shop slot 2") + swatch("3", "Shop slot 3") + swatch("4", "Shop slot 4") + swatch("5", "Shop slot 5") + swatch("6", "Shop slot 6") + swatch("7", "Shop slot 7") + swatch("8", "Shop slot 8") + swatch("9", "Shop slot 9") + swatch("0", "Shop slot 10")
    h += swatch("a", "Gear item a") + swatch("d", "Gear item d") + swatch("e", "Gear item e") + swatch("j", "Gear item j") + swatch("l", "Gear item l") + swatch("n", "Gear item n")
    h += swatch("p", "Equip item p") + swatch("U", "Equip item U") + swatch("V", "Equip item V") + swatch("X", "Equip item X") + swatch("Y", "Equip item Y")
    h += "</div>"
  }
  h += "</div>"
  return h
}

fn gridHtml() {
  let h = "<div class='panel'><div class='gridWrap'><div class='gridInner' id='gridInner' style='grid-template-columns:repeat(" + text(W) + ", 16px)'>"
  let i = 0
  let total = length(cells)
  while i < total {
    let ch = cells[i]
    h += "<div class='cell' style='" + tileCss(ch) + "' title='" + esc(ch) + " - " + esc(tileName(ch)) + "' onmousedown='startPaint(" + text(i) + ")' onmouseenter='dragPaint(" + text(i) + ")'>" + tileGlyph(ch) + "</div>"
    i += 1
  }
  h += "</div></div></div>"
  return h
}

fn exportText() {
  let t = "let " + floorName + " = [\n"
  let ty = 0
  while ty < H {
    let line = ""
    let tx = 0
    while tx < W {
      line += cells[ty * W + tx]
      tx += 1
    }
    t += "  \"" + line + "\",\n"
    ty += 1
  }
  t += "]"
  return t
}

fn modalHtml() {
  if modal == "export" {
    let h = "<div class='modal' onclick='if(event.target===this) closeModal()'><div class='modalBox'>"
    h += "<div class='row' style='margin-bottom:8px'><b>Export</b><label style='margin-left:auto'>Name <input class='txt' id='nameIn' value='" + esc(floorName) + "'></label><button class='btn sm' onclick='applyName()'>Rename</button></div>"
    h += "<p class='legend'>Paste this straight into moonwell.volt, then add it to the <code>maps</code> list and give it a boss letter in <code>floorBoss</code>.</p>"
    h += "<textarea id='exportArea' readonly onclick='this.select()'>" + esc(exportText()) + "</textarea>"
    h += "<div class='row' style='margin-top:8px'><button class='btn' onclick=\"document.getElementById('exportArea').select()\">Select all</button><button class='btn' onclick='closeModal()'>Close</button></div>"
    h += "</div></div>"
    return h
  }
  if modal == "import" {
    let h = "<div class='modal' onclick='if(event.target===this) closeModal()'><div class='modalBox'>"
    h += "<div class='row' style='margin-bottom:8px'><b>Import</b></div>"
    h += "<p class='legend'>Paste an existing floor here - either the quoted rows from moonwell.volt (<code>\"#####\",</code> one per line) or the plain rows with no quotes. Shorter rows are padded with walls.</p>"
    h += "<textarea id='importArea' placeholder='Paste map rows here...'></textarea>"
    h += "<div class='row' style='margin-top:8px'><button class='btn acc' onclick='applyImport()'>Load into grid</button><button class='btn' onclick='closeModal()'>Cancel</button></div>"
    h += "</div></div>"
    return h
  }
  return ""
}

fn esc(s) {
  let t = s
  # t = String(t).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  return t
}

// ------------------------------- render ----------------------------------
fn render() {
  clear
  html "<h1>Floor Forge</h1><p class='sub'>A level editor for Moonwell - paint a floor, then export it as a ready-to-paste Volt map.</p>"
  html toolbarHtml()
  html paletteHtml()
  html gridHtml()
  html modalHtml()
}

// ---------------------------- modal controls ------------------------------
fn openExport() {
  modal = "export"
  render()
}

fn openImport() {
  modal = "import"
  render()
}

fn closeModal() {
  modal = ""
  render()
}

fn toggleAdvanced() {
  if advanced == 1 { advanced = 0 } else { advanced = 1 }
  render()
}

fn applyName() {
  # var v = document.getElementById('nameIn').value.trim();
  # if (v) { floorName = v.replace(/[^A-Za-z0-9_]/g, '') || floorName; }
  render()
}

// ------------------------ raw-JS edges: form fields ------------------------
fn applyResize() {
  # var w = Math.max(5, Math.min(90, parseInt(document.getElementById('wIn').value, 10) || W));
  # var h = Math.max(5, Math.min(70, parseInt(document.getElementById('hIn').value, 10) || H));
  # doResize(w, h);
}

fn applyImport() {
  # var raw = document.getElementById('importArea').value;
  # var lines = raw.split('\n').map(function (l) {
  #   var m = l.match(/"((?:[^"\\]|\\.)*)"/);
  #   if (m) return m[1];
  #   return l.replace(/[\[\],]/g, '').trim();
  # }).filter(function (l) { return l.length > 0; });
  # if (lines.length === 0) {
  #   statusMsg = 'Nothing to import - paste the floor rows first.';
  #   render();
  # } else {
  #   var w = 0;
  #   for (var k = 0; k < lines.length; k++) { w = Math.max(w, lines[k].length); }
  #   for (var k2 = 0; k2 < lines.length; k2++) { while (lines[k2].length < w) lines[k2] += '#'; }
  #   W = w; H = lines.length;
  #   cells = lines.join('').split('');
  #   statusMsg = 'Imported ' + W + ' x ' + H + '.';
  #   modal = '';
  #   render();
  # }
}

// click-and-drag painting across cells
# var __painting = false;
# document.addEventListener('mouseup', function () { __painting = false; });
fn startPaint(i) {
  # __painting = true;
  paintCell(i)
}
fn dragPaint(i) {
  # if (__painting) {
  paintCell(i)
  # }
}

// ------------------------------- start -------------------------------
# document.title = 'Floor Forge';
resetGrid(W, H)
render()
