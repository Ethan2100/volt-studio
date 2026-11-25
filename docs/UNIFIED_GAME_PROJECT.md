# Unified game project data

Volt Studio visual game editors share a project database stored as `volt-game-data.json` beside the project's `.volt` entry file.

- Gameplay Studio loads the shared database when its panel opens and autosaves edits through the sandboxed panel bridge.
- World Studio loads the same database, exposes it as `window.voltGameData` for editor integrations, and creates hierarchy entries for newly authored abilities and items. These entries retain a `sharedId` reference to their source definition.
- World Studio's Save world action also writes the latest shared database before updating the scene block in the `.volt` file.
- The Electron main process validates the project root, schema and 8 MB size limit, then writes the database atomically.

The scene remains in the `.volt` entry file; imported assets remain in the project asset folders; gameplay definitions are in `volt-game-data.json`. This is a single project workflow, not a single monolithic file.

## Current integration boundary

Abilities created from Gameplay Studio's Skill Progression editor are published as ability definitions. Items are published from Inventory. World Studio creates corresponding Ability and Item hierarchy records and keeps their source IDs. Quest/dialogue graphs, AI graphs, loot tables, stats/effects, save/checkpoint definitions and trigger definitions are saved in the same shared database, but their full World Studio scene/runtime bindings are still future work. Runtime behavior must not be considered implemented merely because a definition is saved.
