# UI Studio

Lay out a game's HUD or a page's UI by dragging, at the size it will really appear, instead of
guessing pixel numbers and recompiling to see where things landed.

Open it from the **UI Studio** tab in Volt Studio.

## Using it

1. Open your `.volt` file and press **Load from file**. The panel takes the screen size from your
   `canvas` line and the sprite names from your `sprite` lines.
2. Add things, drag them, drag a corner to resize. Arrow keys nudge (hold Shift for 10),
   Delete removes.
3. Press **Send to editor**. The Volt goes into your file between two marker comments.

Press **Load from file** again later and you can keep editing the same layout.

## The two modes

**Game HUD** draws on your `canvas`, so the block belongs **inside `every frame { }`**. If you
already have a block there, "Send to editor" replaces it in place and keeps its indentation.

| | Writes |
|---|---|
| Box | `box x, y, w, h color "…"` |
| Text | `write "…" at x, y color "…" size n centered shadow` |
| Bar | two boxes - the empty one, then one scaled by an expression you give, for health and mana |
| Sprite | `draw name at x, y` |
| Button | a box, a label, and an `if clicked() and mousex() …` block you fill in |

**Page** is for a non-game `#html` page, and goes at the **top level**: `title`, `print`,
`button … { }`, `html`, and `background.color` / `text.size` styling.

## What it writes

```
// ---- UI Studio ----
// ui-studio: {"mode":"hud", … }
box 6, 6, 70, 7 color "#2a1f1f"
box 6, 6, 70 * (hp * 100 / maxHp) / 100, 7 color "#ff4d6d"
write "HP {hp}/{maxHp}" at 6, 16 color "#ffffff" shadow
// ---- end UI Studio ----
```

The `ui-studio:` line is the layout, saved so the panel can open it again. Everything under it is
ordinary Volt you can read and change.

## Worth knowing

- **Hand edits to the generated lines are not read back.** The panel reloads from the saved
  layout line, so if you change `box 6, 6, …` by hand and then press Load, your change is not
  picked up. Change it in the panel, or stop using the panel for that block.
- **`{values}` in text are previewed as you typed them.** In the game `{score}` becomes a number,
  so the real width differs. Leave room, or tick "centred on x".
- Anything reaching past the edge of the screen is outlined in red and counted in the status line.
- A **Button** uses `clicked()` and `mousex()`, so the program needs a `canvas`.
