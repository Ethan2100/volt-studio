# Beginner guide: make your first game in Volt Studio

World Studio is the starting point for building a game. You do not need to learn every panel before you begin.

## The five-step workflow

1. **Create a project** and open **World Studio**.
2. **Build the world.** Use the Parts strip to add objects, then select an object in Explorer and change its values in Properties. Rename objects so Explorer stays readable.
3. **Add gameplay.** Click **Game** in the World Studio toolbar. Choose a category on the left, click **+ Add**, select the new entry and edit its fields. Changes autosave to the project's shared game data.
4. **Save the game.** Use **Save game** in World Studio to save the scene and shared gameplay definitions together.
5. **Play and iterate.** Run the project, test one change at a time, and return to World Studio to adjust it.

## What belongs where?

| I want to… | Start here |
|---|---|
| Place or move scenery and world objects | World Studio viewport, Parts and Explorer |
| Change an object's name, position or appearance | Select it, then use Properties |
| Create an ability, item or NPC definition | Game → Build |
| Create quests, progression or enemy behaviour definitions | Game → Gameplay |
| Configure player stats, effects, saves or interactions | Game → Systems |
| Change the game scene | World Studio → Save game |

## Keep the project organised

- Give objects and gameplay entries clear names.
- Create one feature, save, then test it before adding another.
- Keep related objects together in Explorer.
- Use the built-in examples as starting points rather than building everything from a blank page.
- Make a copy of a project before experimenting with major changes.

## Important feature status

The Game workspace currently provides a shared authoring and autosave layer. Some definitions are linked to World Studio scene objects, but not every category is a complete playable runtime system yet. In particular, full NPC AI, quest execution, progression unlocks, loot drops, status effects, save/checkpoint execution and trigger actions still need runtime implementation. Do not assume that creating a definition automatically makes it work in a running game until that runtime feature is explicitly marked complete.

The beginner workflow is intended to keep authoring in one place: World Studio. The older standalone Gameplay Studio and RPG Studio tabs are hidden to avoid making beginners choose between duplicate editors.
