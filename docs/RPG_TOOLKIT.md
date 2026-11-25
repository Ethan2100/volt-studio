# RPG Kit

Volt's RPG Kit is an optional library built on top of the existing `game-kit`
and `combat-kit`. It adds reusable 3D starter weapons and simple enemy NPC AI
without replacing the existing health, target, cooldown, backpack or HUD APIs.

## Import

```volt
#html
canvas 320, 180
import "game.volt"
import "combat.volt"
import "rpg.volt"
```

## Default sword

Call `rpgEquipSword()` once before the game loop, or use `rpgEquipWeapon("Katana")`, `rpgEquipWeapon("Greatsword")`, or `rpgEquipWeapon("Dagger")` to choose a procedural weapon model. Call `rpgSwordStep()`
each frame to attach the sword meshes to the player. Call
`rpgSwordAttack()` when the attack input is pressed.

## Enemy NPCs

Use the included presets `rpgSpawnGoblin(x, z)`, `rpgSpawnBandit(x, z)` and `rpgSpawnSkeleton(x, z)`, or create a custom enemy. Create an enemy with:

```volt
let goblin = rpgSpawnEnemy("Goblin", 0, -400, 100, 8, 150, 900, 95, "#648b4a")
```

Arguments are name, x, z, health, attack damage, chase speed (cm/s),
aggro radius (cm), melee attack range (cm), and body color.

Call `rpgStepEnemies()` every frame. NPCs register with the combat kit's
`target()` system, so existing `hurtTarget()`, `damageArea()`,
`drawEnemyBars()` and damage-number behavior work with them. Enemies chase
the player inside their aggro radius and attack at close range with a cooldown.

## RPG Studio panel\n\nThe `plugins/rpg-studio` panel provides a Skillset Builder, live particle VFX preview/editor, local audio preview and settings editor, HUD/font preview, and NPC profile editor. It exports `.skillset.json`, VFX, audio, HUD theme and NPC profile configuration files. These exports are portable configuration assets; connecting them to a running game is currently a manual integration step.\n\n## Example project

See [Shadow Fruit](../examples/shadow-fruit/Shadow%20Fruit.volt) for a sample
that combines the sword, two hostile NPCs, the existing combat HUD and a
four-move shadow skillset.

## Current limitations

The included NPCs are procedural block/ball characters and use simple
distance-based chase AI. This initial kit does not yet provide navmesh
pathfinding, rigged animation retargeting, loot tables, or a visual NPC
behavior editor.
