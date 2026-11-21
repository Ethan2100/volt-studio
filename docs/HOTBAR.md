# Volt Game Kit Hotbar

The Game Kit includes a reusable nine-slot hotbar for `#html` 3D games, including games created in World Studio.

## Quick start

```volt
#html
title "Hotbar demo"
canvas 320, 180
import "game.volt"

world3d "#101722" fog 1800 ambient 12
let Floor = block3d(0, -5, 0, 1200, 10, 1200, "#626b78")
clearSolids()
solid(0, 0, 600, 600, -10, 0)
playerStart(0, 400, 0)

HOTBAR_ITEMS = ["SWORD", "POTION", "BOW", "TORCH", "", "", "", "", ""]
HOTBAR_COUNTS = [1, 5, 12, 1, 0, 0, 0, 0, 0]

every frame {
  playerStep()
  hotbarStep()
  render3d
  hotbarDraw()
  write "Selected slot: " + HOTBAR_SELECTED at 8, 8 color "#ffffff"
}
```

## API

| API | Purpose |
|---|---|
| `HOTBAR_ITEMS` | Nine short item labels, one per slot. |
| `HOTBAR_COUNTS` | Nine numeric stack counts. Use 0 for empty/unavailable. |
| `HOTBAR_SELECTED` | Currently selected slot, numbered 1–9. Read it in your gameplay logic to equip/use the chosen item. |
| `HOTBAR_ENABLED` | Set false to hide the bar and ignore number-key selection. |
| `hotbarStep()` | Call once per frame before rendering; reads number keys 1–9. |
| `hotbarDraw()` | Call after `render3d` to draw the screen-space bar. |

Labels should be short (about five characters) so they fit inside each slot. The hotbar uses the standard 320×180 canvas layout. `HOTBAR_SELECTED` is 1-based; when indexing an item array, use `HOTBAR_SELECTED - 1`.

## Equipping an item

The hotbar only handles selection and display. Your game decides what each selected item does:

```volt
if HOTBAR_SELECTED == 1 and held("space") {
  // use the sword
}
if HOTBAR_SELECTED == 2 and held("space") and HOTBAR_COUNTS[1] > 0 {
  // drink a potion
  HOTBAR_COUNTS[1] -= 1
}
```

For a full inventory, update the two arrays when items are picked up, consumed, or dropped. The hotbar intentionally does not create or manage inventory items by itself.
