# Unified game project

World Studio is the single authoring home for a Volt game. The **Game** button opens a clean category-based editor for shared gameplay definitions. The old standalone Gameplay Studio and RPG Studio panels are hidden from the app's side-panel list so users do not have to guess which editor owns the data; their source files remain for compatibility.

## One project, one source of truth

The Electron project bridge stores definitions in `volt-game-data.json` beside the project's `.volt` entry file. Panels load the same versioned `volt-game-project` object and autosave changes through the host bridge. World Studio's **Save game** action writes the shared data and updates the scene section in the `.volt` entry file.

The Game panel includes:

- **Build:** abilities, items, NPCs and HUD elements
- **Gameplay:** quests/dialogue, progression skills, enemy behaviour and loot tables
- **Systems:** player stats, status effects, save fields, checkpoints and interactions/triggers

Each record has a stable ID. Spatial records are linked to World Studio hierarchy objects: abilities, items, NPCs and HUD elements use their corresponding scene object types; non-spatial definitions appear as named folders in the hierarchy. Editing a linked record updates its corresponding World Studio object/inspector values. Deleting a record hides its linked scene object and removes the definition from the shared database.

## What Save game means

- The `.volt` entry file stores the authored 3D scene and generated Volt code.
- `volt-game-data.json` stores the shared gameplay definitions.
- Imported model/audio/image files remain normal project assets; the project folder is the complete game project.
- The project is not collapsed into one giant file. Saving the game writes all project-owned game data without duplicating assets into the scene source.

## Runtime boundary

World Studio already generates Volt code for its native scene objects, abilities, items and HUD elements. The Game panel links those spatial definitions to scene objects so supported properties are reflected when the scene is saved. NPC entries create and link a World Studio Character object; the current NPC editor stores archetype, health, damage and movement/aggro settings, but full NPC AI execution and model animation wiring still require runtime integration. Quests, dialogue, progression graphs, AI graphs, loot tables, status effects, save fields, checkpoints and triggers are persisted and represented in the hierarchy, but their complete runtime execution is not yet implemented. A saved definition must not be mistaken for a runtime feature until it is wired to the Volt runtime and tested in a built game.
