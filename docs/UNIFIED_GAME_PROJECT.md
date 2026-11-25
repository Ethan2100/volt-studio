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

## Runtime systems

World Studio generates the supported Game workspace definitions into the .volt game source. When shared Game data is present, generated games import combat.volt and rpg.volt; the runtime is ticked from worldStep(), and saved progression/checkpoints are restored from the browser's per-game save storage.

The reusable plugins/game-kit/rpg.volt runtime currently provides:

- **Quests:** create/start, objective progress, completion and XP/item reward claiming
- **Progression:** XP, level thresholds, skill prerequisites, unlock costs and saved unlock state
- **Enemy behaviour:** guard/aggressive aggro, chase movement, attack range and cooldowns; generated NPC characters are passed as the visual object so movement updates the visible character
- **Loot:** item entries with drop chances and min/max stack amounts, added to the backpack on a roll
- **Status effects:** timed attack/defence modifiers that affect actual damage dealt and received
- **Persistence:** player XP, level, quest progress/state, skill unlocks and checkpoint position are saved and restored
- **Checkpoints and triggers:** proximity entry events can start/advance quests, heal, grant XP, set checkpoints or apply a defined status effect; one-shot and re-entry behaviour are supported
- **Custom save fields:** generated variables load from and autosave to the game's browser save storage

Call stepRpg() once per frame in hand-authored games. World Studio-generated games do this automatically. Use stepEnemyAI(targetId, PLAYER_X, PLAYER_Z) for each configured enemy and stepTriggers(PLAYER_X, PLAYER_Z) for proximity interactions; World Studio-generated NPCs and triggers are wired automatically.

## Remaining limits

These are gameplay building blocks, not a complete MMO/RPG framework. Dialogue branching/UI, complex visual node-graph execution, navigation/pathfinding around obstacles, animation state selection, multiplayer/network persistence, and cloud saves are not implemented. The current enemy AI is a simple direct-chase/guard behaviour and does not pathfind around walls. In-game visuals and input still need a human play-test in the packaged Electron app; CI compiles the sample and executes automated runtime tests but cannot replace that play-test.
