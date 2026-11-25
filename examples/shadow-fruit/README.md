# Volt RPG Kit — Shadow Fruit sample

This first implementation adds a reusable RPG library and a playable sample.

## Install
Copy the three library files from `plugins/game-kit/` and `plugins/rpg-kit/`
into your Volt project's plugin library folders, or install the plugin through
Volt Studio's plugin manager if it is already available there.

The sample file is `examples/shadow-fruit/Shadow Fruit.volt`.

## Controls
- WASD + mouse: move and look
- Shift: run; Space: jump
- 1: iron sword attack
- Q: Blood Swarm — ten procedural bats orbit the player, periodically damage nearby targets and heal.
- E: Blood Drain — damage the nearest target and heal.
- R: Crimson Burst — area damage and conditional healing.
- F: Shadow Step — short forward blink.

## What is implemented
- Procedural 3D iron sword made from multiple meshes.
- Equipping/following the player's position and facing.
- Damageable NPC targets with health.
- Basic enemy chase and melee attack AI.
- NPC attack cooldowns and death visibility.
- Shadow Fruit example with four abilities and bat orbit meshes.
- Reuses existing game-kit/combat-kit health, damage, healing, cooldown, hotbar and HUD systems.

## Current limitations
- NPCs use procedural placeholder geometry, not rigged character models.
- AI is a simple distance-based chase/attack behavior; no navigation mesh or obstacle pathfinding yet.
- Sword attack uses a forward damage area, not a swept animated hitbox.
- The sample and library should be compiled and playtested in the target Volt Studio build before being treated as production-ready.
