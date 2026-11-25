# Volt Studio Editor Feature Catalog

This document expands the hybrid-engine roadmap into a practical product specification. It is a target catalogue, not a claim that every listed feature already exists. Each feature must be marked **planned**, **prototype**, or **implemented** in the editor until it is verified.

## Product principle

Volt Studio should feel like one coherent game-making environment:
- Visual-first workflows for common tasks.
- Volt code remains visible, exportable, editable, and authoritative for advanced behavior.
- Editors produce inspectable project data and readable Volt code/configuration rather than opaque state.
- Runtime features must work offline with imported local assets.
- Preserve existing compiler targets, plugins, project formats, renderer APIs, and command syntax through additive changes and migration tests.

## 1. Asset Browser and Library

A unified browser for project and imported assets:
- Folder tree, thumbnails, search, tags, favorites, type filters, and recently used assets.
- Import queue with progress, cancel/retry, validation, and useful error messages.
- Drag assets into the scene, material slots, audio tracks, animation tracks, and UI layouts.
- Dependency graph: show which scenes, prefabs, materials, scripts, and effects use an asset.
- Missing/unused/duplicate asset reports; safe rename and move with reference repair.
- Asset metadata sidecar: source URL, author, exact license identifier, license-file path, attribution text, import settings, and modifications.
- Reimport settings and deterministic project packaging.
- Optional local asset-library indexing; no mandatory cloud account or network dependency.

## 2. 3D Model Studio

- GLB/GLTF-first import and preview; explicit conversion path for other formats rather than silently accepting unsupported files.
- Inspect hierarchy, mesh count, vertex/triangle counts, dimensions, transforms, materials, textures, skeletons, and embedded clips.
- Static and skeletal model preview with orbit/pan/zoom, wireframe, bounds, skeleton and normals overlays.
- Animation clip list, play/pause/scrub, speed, looping, and clip range.
- Collision shape generation and manual collider editing; LOD generation/settings.
- Pivot/origin tools, scale/axis correction, mesh visibility, material reassignment, prefab creation.
- Later: animation state machines, blend spaces, root motion, retargeting, sockets/bone attachments, mesh simplification.
- Preserve source files; imported/processed assets should be reproducible and reversible.

## 3. Materials, Textures and Shader Studio

- PBR material editor: base color/albedo, metallic, roughness, normal, ambient occlusion, emissive, opacity and height/displacement where supported.
- Texture preview, channel inspection, UV checker, tiling/offset, filtering, compression and resolution settings.
- Texture atlas creation and optional packing of ORM channels.
- Material instances with exposed parameters and shared parent materials.
- Node-based visual shader graph with live preview, compile errors, graph comments, reusable functions and code view/export.
- Shader presets: toon/anime, unlit, glass, water, foliage, dissolve, outline, hologram, aura/glow.
- Texture painting is a later integrated feature; initially provide an external-editor handoff and reliable reimport workflow rather than pretending to replace a full painting application.

## 4. 2D Studio

- Sprite and sprite-sheet importer, automatic/manual slicing, pivot editing and animation frame preview.
- 2D scene layers, parallax backgrounds, camera framing, sorting layers and visibility controls.
- TileSet and tilemap painting with brush, erase, fill, rectangle, autotile/terrain rules and collision painting.
- 2D animation timeline, frame tags, onion skin, animation events and sprite state machines.
- 2D lights, shadows, normal maps and particle effects where supported by the renderer.
- 2D physics shape editing, ray/area previews and collision layers/masks.
- Pixel-art-friendly zoom, nearest-neighbor preview, palette tools and grid snapping.

## 5. UI / HUD Studio — drag-and-drop in-game interface editor

A visual canvas that edits the actual runtime UI layout:
- Live game-frame preview with selectable target resolutions and aspect ratios.
- Drag, resize, rotate, align, distribute, group, lock, hide and reorder UI elements.
- Anchors, pivots, margins, safe areas, containers, responsive constraints and scaling modes.
- Guides, grids, snapping, pixel alignment and multi-selection.
- Widget library: panel, image, text, button, progress bar, slider, icon, scroll view, list, tooltip, modal and custom component.
- Style editor: fonts, sizes, outlines, shadows, gradients, borders, nine-slice panels, hover/pressed/disabled/focus states.
- Data bindings for health, mana/aether, XP, level, inventory, quest objectives, minimap, ability cooldowns and status effects.
- Input/navigation preview for keyboard, mouse, controller and touch.
- Screen variants and responsive preview; test small screens and ultrawide layouts.
- Accessibility checks: contrast, minimum text size, focus order, readable labels and scalable UI.
- UI animation timeline and event actions.
- Export readable layout data plus Volt bindings; never make editor-only coordinates the only source of truth.

## 6. Audio Studio

- Asset library with waveform preview, duration, channels, sample rate and format information.
- Non-destructive trim, loop-region selection, fades, gain, pitch preview and audition.
- Audio buses/groups: master, music, ambience, SFX, voice and UI; volume sliders and mute/solo.
- Runtime effects where supported: low/high-pass filters, reverb, echo/delay, distortion and compressor.
- 2D and 3D audio emitters with attenuation, distance, panning, spatial blend, doppler and listener preview.
- Audio event library for footsteps, hits, UI feedback, weapon swings, spells, ambience and dialogue.
- Timeline markers and animation/gameplay event hooks.
- Mixer meters, clipping warnings, voice limits and memory estimates.
- Keep current `music`, `sound` and `volume` syntax compatible; add new commands only with tests and docs.

## 7. VFX Studio — 2D and 3D

- Node/stack-based effect graph with reusable emitters and sub-effects.
- 2D sprites, 3D billboards, mesh particles, ribbons/trails, beams, rings, decals and impact bursts.
- Curves for size, color, opacity, speed, rotation and emission over lifetime.
- Gradients, noise, gravity, velocity, turbulence, collision, attractors and sub-emitters.
- Shape emitters: point, sphere, cone, box, mesh and bone/socket attachment.
- Shader-driven effects: dissolve, fresnel rim, outline, heat haze/distortion and glow where supported.
- Preview controls: play, pause, restart, scrub, random seed, time scale and camera presets.
- Event triggers: spawn, hit, death, dash, heal, level-up, ultimate activation and environment interaction.
- Performance controls: particle budgets, LOD, pooling, culling and overdraw warnings.
- Effect presets and a one-click attach-to-character/bone workflow.

## 8. Ability and Combat Designer

An ability authoring tool for RPGs and action games:
- Ability definition: name, icon, input, target mode, range, area, cost, cooldown, cast time, duration and tags.
- Timeline tracks for animation, VFX, audio, camera shake, hitboxes, damage windows and UI events.
- Status effects and modifiers: damage, defence, speed, attack speed, healing, regeneration, resistance, slow, stun, burn and knockback.
- Stacking rules, refresh/replace behavior, duration policies, cleanse rules and team filters.
- Projectile, melee, dash, summon, beam, area-of-effect, buff and transformation templates.
- Preview against a dummy target; show hitbox, range, timing, damage and cooldown.
- Generate readable Volt code/config and connect to input mapping and HUD cooldown widgets.

### Example: ultimate ability with shaded aura and boost UI

A reusable template named **Ascendant Form**:
1. Charge: play a charge animation, rising audio, ground rune and gathering particles.
2. Activate: camera impulse, flash/ring burst, shader-driven shaded aura around the character, emissive accents and optional eye/weapon glow.
3. Boost: apply configurable damage, defence, movement-speed, attack-speed and regeneration multipliers for a duration.
4. Sustain: aura follows the character or selected skeleton sockets; looping particles and sound are pooled and cleaned up safely.
5. HUD: show an ultimate icon, charge meter, activation flash, duration bar and cooldown overlay.
6. Expire: fade the aura, restore original stats, stop loops and play an end effect.
7. Debug: inspect active modifiers, remaining time, event order and spawned effect counts.

The aura should be a material/VFX preset with tunable color, opacity, fresnel/rim intensity, pulse speed, particle density and shadow treatment. Avoid hard-coding the visual into one ability.

## 9. Animation and Cinematic Studio

- Timeline with tracks, keyframes, markers, curves and snapping.
- Skeletal clip preview, blend trees/spaces, state machines and transitions.
- Animation events for audio, VFX, damage windows, footsteps and UI.
- Camera tracks, camera shake, look-at targets, cuts and simple cutscene sequencing.
- Root-motion preview and per-axis controls; retargeting only after skeleton compatibility checks.
- Undo/redo, copy/paste keys, loop preview and track locking.

## 10. World and Scene Studio

- Scene hierarchy, collections/layers, prefabs and reusable scene templates.
- Terrain sculpt/paint, foliage scatter, environment painting and modular level building.
- Lighting: directional/point/spot/area lights as supported, shadows, probes, fog and sky/HDRI.
- Navigation mesh generation, navigation obstacles and path preview.
- Physics/collision visualization, triggers, joints and layer/mask inspection.
- Reflection/environment settings, post-processing stack and camera tools.
- Scene validation for missing references, bad transforms, unsupported assets and performance risks.

## 11. Gameplay Creation Suite

These are distinct visual editors connected by shared, versioned game data. They should be independently useful, but also integrate without duplicating definitions. For example, an item references a stat modifier; equipment applies it; the character sheet displays the result; a quest can award that item; and the save system persists the resulting inventory.

### 11.1 Inventory and Equipment Editor

- Item database with item ID, display name, icon, description, category, rarity, stack limit, weight/value and tags.
- Item types: consumables, weapons, armor, accessories, materials, quest items, currency and keys.
- Equipment slots and slot rules, two-handed/off-hand compatibility, class/level requirements and equip restrictions.
- Item affixes, randomized rolls, durability, upgrades, sockets and set bonuses.
- Drag-and-drop inventory grid/list preview, sorting, filtering, stack splitting and quick slots.
- Equip/unequip events, use-item actions and configurable behavior hooks.
- Preview character stat changes before confirming equipment.
- Generate item definitions and bindings for inventory/HUD UI; validate unique IDs and missing icons.

### 11.2 Quest and Dialogue Graph Editor

- Node graph for quest start, objectives, branching conditions, counters, timers, choices, rewards, failure and completion.
- Dialogue nodes with speaker, portrait, text, voice/audio cue, choices and localization key.
- Conditions can read documented game state such as flags, inventory, stats, completed quests and world events.
- Objective types: talk, collect, defeat, explore, interact, escort, survive and reach location.
- Quest chains, prerequisites, optional objectives, repeatable quests and mutually exclusive branches.
- Debug simulation: step through nodes, inspect variables, force conditions and preview dialogue choices.
- Quest journal preview and UI binding for objective text, markers and completion state.
- Export readable graph data and generated Volt hooks; detect unreachable nodes and reward loops.

### 11.3 Skill Tree and Progression Editor

- Visual node-and-connection canvas with branches, tiers, prerequisites and mutually exclusive choices.
- Unlock costs using XP, skill points, currency, items or quest flags.
- Passive bonuses, active ability unlocks, stat modifiers and gameplay rule unlocks.
- Class/archetype trees, weapon mastery, elemental affinities and account/character progression profiles.
- Preview locked, available and purchased states; simulate spending and respec rules.
- Connect unlocked skills to the Ability Designer and HUD skill slots.
- Validate cycles, unreachable nodes, missing prerequisites and impossible costs.

### 11.4 Enemy AI Behaviour Graph

- Visual finite-state machine and behavior-tree authoring: idle, patrol, investigate, chase, attack, flee, stunned, dead and custom states.
- Conditions, sequences, selectors, decorators, timers, cooldowns and event-driven transitions.
- Per-enemy blackboard variables and shared perception settings.
- Vision cones, hearing radius, line-of-sight checks, aggro groups and target selection.
- Navigation/pathfinding actions, attack telegraphs, boss phases, reinforcements and phase transitions.
- Debug live state, active node, target, path, blackboard values and transition history.
- Simulate against test dummies and a configurable arena; add safeguards for loops and excessive update frequency.

### 11.5 Loot Tables and Item Database

- Weighted drops, guaranteed drops, drop groups, rarity tiers, quantity ranges and conditional rewards.
- Nested tables for enemy, chest, boss, quest, gathering and world-event rewards.
- Seeded preview rolls so results can be reproduced while balancing.
- Pity/anti-streak rules and per-player limits as optional explicit systems, not hidden defaults.
- Economy balancing view for expected value, drop probability and reward frequency.
- References to Inventory Editor item IDs; detect missing items, impossible tables and unintended guaranteed loops.
- Import/export CSV or JSON for bulk editing, with stable IDs and validation.

### 11.6 Character Stats and Status-Effect Editor

- Define base stats, derived stats, caps, formulas, units and display names.
- Common templates: health, mana/aether, stamina, attack, defence, speed, critical chance, resistance and regeneration.
- Modifier operations: flat add, additive percent, multiplicative scale, override and clamp.
- Explicit modifier order and stacking policy to avoid unpredictable stat results.
- Status effects with duration, tick interval, refresh/stack/replace rules, source attribution and cleanse behavior.
- Buff/debuff templates: burn, poison, freeze, stun, slow, shield, haste, healing-over-time and damage-over-time.
- Live stat calculator showing base value, each modifier, final value and rounding.
- Connect to equipment, abilities, skill trees, enemy definitions and HUD bindings.
- Validate invalid formulas, circular derived stats and conflicting stacking rules.

### 11.7 Save/Load and Checkpoint Editor

- Define save profiles and versioned schemas for player stats, inventory, equipment, quests, skill unlocks, world flags and settings.
- Checkpoint placement and activation rules, respawn transform, restore policy and checkpoint UI.
- Autosave triggers, manual save points, save slots and configurable retention.
- Separate persistent progression from temporary session state.
- Migration hooks for older save versions and clear recovery behavior for corrupt or incomplete saves.
- Preview exactly which fields are written/restored; inspect save data in a readable debug panel.
- Avoid silently saving transient object references; use stable IDs for entities and assets.
- Include test cases for new game, overwrite, reload, checkpoint respawn and schema migration.

### 11.8 Interaction and Trigger-Volume Editor

- Place box, sphere, capsule and custom trigger volumes in the scene; resize and rotate with gizmos.
- Configure enter, stay, exit, interact and proximity events.
- Interaction prompts, input action, priority, range, hold duration and cancel behavior.
- Reusable interaction types: doors, pickups, switches, chests, levers, NPC conversations, crafting stations and portals.
- Conditions and actions can call quest, inventory, dialogue, ability, animation, audio and scene systems.
- Visualize trigger bounds, collision layers, active state and event flow in play mode.
- Support multiplayer ownership/authority as an explicit future capability rather than assuming local-only logic scales automatically.
- Detect overlapping conflicting triggers, missing targets and actions with invalid references.

### 11.9 Shared Gameplay Data and Graph Debugger

- Common stable IDs and typed references connect items, abilities, quests, characters, effects and world objects.
- Reusable graph nodes for conditions, variables, signals/events, timers, functions and subgraphs.
- Nodes call documented runtime functions and can be converted to or paired with Volt code.
- Debug graph execution with current node, variables, breakpoints, event history and step-through simulation.
- Data validation checks broken references, unreachable graph nodes, circular dependencies and incompatible schema versions.
- All visual editors must expose generated data and code; users can inspect and hand-edit supported files without losing editor compatibility.

## 12. Input, Debugging and Profiling

- Input action map with keyboard/mouse/controller/touch bindings and remapping.
- In-editor play mode, pause, single-step, restart and selectable debug camera.
- Console with searchable logs, warnings, errors and clickable source locations.
- Breakpoints, variable inspection, watch expressions and call stack where supported by the compiler/runtime.
- Performance overlay: FPS/frame time, draw calls, triangles, active objects, particles, audio voices and memory.
- CPU/GPU profiling only where reliable instrumentation exists; label unavailable metrics honestly.
- Scene/gameplay inspectors for colliders, rays, navigation paths, AI state, ability hitboxes and UI bounds.

## 13. Project, Build and Collaboration

- Project templates: 2D, 3D, RPG, platformer, top-down, action and blank.
- Build profiles for target platform, resolution, quality, asset compression and output folder.
- Asset validation and dependency-aware packaging; report missing files before export.
- Project settings with input, rendering, physics, audio, localization and accessibility sections.
- Localization tables, font fallback and preview of long translated strings.
- Versioned project format, safe backups, autosave and recovery.
- Git integration should remain optional and never silently rewrite user history.
- Plugin SDK with documented editor panels, importers, inspectors, runtime extensions and permissions.

## 14. Free asset pipeline and licensing

Preferred sources:
- Kenney: https://kenney.nl/assets — many individual packs are CC0; verify the pack page and keep its license metadata. The paid All-in-1 bundle is convenient but is not required for the free workflow.
- Poly Haven: https://polyhaven.com — models, textures and HDRIs are CC0: https://polyhaven.com/license.
- Quaternius: https://quaternius.com — each pack must be checked. The current Quaternius Asset License allows use in personal, educational and commercial projects but prohibits standalone asset redistribution: https://quaternius.com/license.html.
- AmbientCG: https://ambientcg.com — useful source to evaluate for CC0 PBR materials; verify the current license and each downloaded asset's metadata before shipping.
- OpenGameArt: https://opengameart.org — broad 2D/audio library, but licenses vary by asset; filter and record each exact license.

Rules:
- Never treat an entire website as having one universal license unless its publisher explicitly says so.
- Store source URL, author, license identifier, license text/file, attribution and modification notes for every imported pack.
- Do not bundle restricted assets in a redistributable sample library.
- Provide a user-controlled external asset folder and a license report in project exports.

## 15. Suggested implementation order

Build reliable foundations before adding dozens of disconnected panels.

1. **Asset foundation:** asset registry, thumbnails, metadata/license sidecars, dependency tracking, import validation.
2. **Model Studio:** GLB inspector, preview, animation playback, material inspection, collision tools.
3. **UI Studio:** responsive canvas, drag/resize, anchors, widget library, runtime data bindings.
4. **Audio Studio:** waveform preview, non-destructive settings, buses and runtime event integration.
5. **VFX Studio:** 2D/3D emitter preview, curves, trails, reusable presets and event triggers.
6. **Ability Designer:** timeline, modifiers, ultimate template, automatic HUD/cooldown binding.
7. **2D Studio:** sprites, tilemaps, animation and 2D physics authoring.
8. **World Studio expansion:** lighting, terrain, navigation, prefabs and scene validation.
9. **Gameplay graphs:** quest/dialogue/AI/inventory and save data.
10. **Quality:** undo/redo, accessibility, profiling, import fixtures, export tests and documentation.

## Definition of done for every editor

- Works with local project assets and offline after import.
- Has undo/redo for destructive authoring operations.
- Shows clear errors and never silently drops unsupported data.
- Saves versioned, inspectable project data.
- Generates or binds to documented runtime APIs.
- Includes a small example project and automated tests.
- Does not regress existing compiler targets, plugins, projects or runtime commands.
- UI labels distinguish implemented functionality from prototypes and planned features.
