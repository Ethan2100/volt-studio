# Volt Game Kit Hotbar

The Game Kit provides a reusable ten-slot player hotbar for `#html` 3D games, including games created in World Studio.

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

HOTBAR_ITEMS = ["SWORD", "POTION", "BOW", "TORCH", "", "", "", "", "", ""]
HOTBAR_COUNTS = [1, 5, 12, 1, 0, 0, 0, 0, 0, 0]

every frame {
  playerStep()
  hotbarStep()
  render3d
  hotbarDraw()
}
```

## API

| API | Purpose |
|---|---|
| `HOTBAR_ITEMS` | Ten item labels, one per slot. World Studio displays four characters in the compact HUD. |
| `HOTBAR_COUNTS` | Ten numeric stack counts. Use 0 for empty/unavailable. |
| `HOTBAR_SELECTED` | Currently selected slot, numbered 1–10. Use `HOTBAR_SELECTED - 1` for a zero-based array index. |
| `HOTBAR_ENABLED` | Set false to hide the bar and ignore number-key selection. |
| `HOTBAR_SLOT_COUNT` | Number of quick slots (10). |
| `hotbarStep()` | Call once per frame before rendering; reads number keys 1–9 and 0, plus mouse-wheel selection. |
| `hotbarDraw()` | Call after `render3d` to draw the screen-space hotbar. |

The tenth slot is selected with **0**. Scrolling down advances to the next slot; scrolling up selects the previous slot, wrapping at either end. The HUD uses Volt's existing palette, a selected-slot highlight, item labels and stack counts.

## Equipping an item

The hotbar handles selection and display. Your game decides what each selected item does:

```volt
if HOTBAR_SELECTED == 1 and held("space") {
  // use the sword
}
if HOTBAR_SELECTED == 2 and held("space") and HOTBAR_COUNTS[1] > 0 {
  // consume a potion
  HOTBAR_COUNTS[1] -= 1
}
```

World Studio configures starter labels and counts under **Player > Backpack > Hotbar**. The selected slot is exposed to game logic through `HOTBAR_SELECTED`.

This is the starter inventory and HUD layer. Physical equippable Tool instances and multiplayer inventory replication are separate engine features.
