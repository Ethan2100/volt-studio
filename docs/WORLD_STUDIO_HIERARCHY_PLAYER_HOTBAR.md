# World Studio hierarchy and Player hotbar

World Studio has two top-level Explorer sections: **World** and **Player**.

## World hierarchy

- **Folder** — organizational only. Nest folders, parts, models, scripts and effects to keep large scenes readable. Folders do not create runtime geometry or change object transforms.
- **Model** — a transformable group. Put Parts, imported 3D Models, Characters, Scripts and Effects inside it. Moving or rotating the Model carries its spatial descendants in the editor and generated game.
- **Part / Ball / Pillar / Light / Spawn** — scene objects.
- **3D Model** — imports a GLB asset. This is different from a Model group.
- **Script / Effect** — behavior components that can be parented under a scene object or organized in a Folder.

Use the arrow beside a row to expand or collapse it. Drag rows onto another row to reparent them; drag onto **World** to move them back to the root. Double-click a row to focus its object in the viewport. Folder rows are intentionally absent from the 3D viewport because they are not physical objects.

### Example hierarchy

```text
World
└─ Environment (Folder)
   ├─ Castle (Model)
   │  ├─ Keep (Folder)
   │  │  ├─ Wall (Part)
   │  │  └─ Tower (Part)
   │  └─ Gate (Part)
   └─ Crate (Part)
      ├─ Effect
      └─ Script
```

Folders are organizational; Models are spatial. Saving converts Model groups and nested parts into Volt `group3d` / `join3d` relationships while omitting Folder nodes from the runtime scene.

## Player > Backpack > Hotbar

The Player section is a runtime configuration area, not a world object. Open **Player > Backpack > Hotbar** to configure ten starter quick slots.

| Key | Slot |
|---|---:|
| 1–9 | 1–9 |
| 0 | 10 |

Select a slot in the Explorer tree to edit its item label and stack count. Empty labels create empty slots. The item labels are shortened to four characters in the compact in-game HUD; the full label remains in the editor.

World Studio writes the hotbar configuration into the saved world marker and generates calls to:

- `hotbarStep()` — reads the 1–9 / 0 selection keys.
- `hotbarDraw()` — draws the ten-slot HUD after `render3d`.
- `HOTBAR_SELECTED` — 1-based selected slot, available to game logic.
- `HOTBAR_ITEMS` / `HOTBAR_COUNTS` — starter slot labels and stack counts.
- `HOTBAR_ENABLED` — show or hide the HUD.

The Game Kit owns hotbar rendering and key selection. The Player panel configures its starter contents. This is the first-player inventory foundation; multiplayer replication and physical equippable Tool instances are separate future engine features.

## Design references

The workflow takes inspiration from Roblox Studio's Explorer hierarchy, Model grouping, Properties panel and Player Backpack flow. It keeps Volt's current dark editor palette and Volt's own scene data, runtime, and scripting APIs.
