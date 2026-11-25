# Volt Studio Engine Roadmap

## Product direction

Volt Studio is a hybrid engine: visual tools for common work, Volt code for precision and advanced behavior. Keep the editor approachable without hiding the underlying engine. Existing Arduino, MicroPython, Python, Ruby, JavaScript, HTML, compiler, plugin, project, and release workflows must remain working.

## Current foundations verified in the repository

- Three.js-powered 3D runtime in `lib/volt3d.js`.
- `model3d` loads embedded GLB assets; `put3d` places instances.
- `anim3d` plays named skeletal animation clips embedded in GLB files using Three.js AnimationMixer.
- `music` and `sound` are existing language/runtime commands; keep them compatible.
- Project Assets import copies files into the project's Assets directory; model declarations compile from GLB.
- World Studio can import GLB models into its viewport, place them, and export Volt declarations.
- Character-pack assets expose their embedded animation names and can be selected in World Studio.
- The RPG Kit and RPG Studio branch adds starter RPG code and authoring prototypes.

## Roadmap (hybrid + free assets)

### Phase 1 — Model and animation workflow
- Keep GLB as the reliable runtime interchange format.
- Improve GLB inspection: clip names, mesh/material counts, dimensions, texture presence, and actionable import errors.
- Add a model inspector and animation clip selector in World Studio.
- Add playback controls and preview without altering the source GLB.
- Ensure selected animation names are emitted as `anim3d` statements.
- Add automated fixtures for static GLB, animated GLB, malformed GLB, and missing-file behavior.
- Later: animation timeline, blend states, retargeting, root-motion controls.

### Phase 2 — Audio engine and Audio Studio
- Audit and document the existing `music` and `sound` runtime commands before extending them.
- Build a shared audio asset registry, preview player, volume/pitch/loop controls, and 3D spatial audio.
- Add animation/gameplay event hooks for footsteps, impacts, spell casts, and UI feedback.
- Preserve existing command syntax and existing game output.

### Phase 3 — VFX Studio
- Move from 2D-only authoring previews to actual 3D runtime previews.
- Reuse existing `burst3d`, `slash3d`, `magic3d`, `shock3d`, and `beam3d` primitives where appropriate.
- Add reusable presets, curves, emitters, trails, and event triggers.

### Phase 4 — Visual gameplay systems
- Skillsets, inventory, quests, dialogue, enemy AI, and save data.
- Visual editors generate readable Volt code and configuration, never opaque project state.
- Keep code export and manual editing available at all times.

### Phase 5 — World and asset pipeline
- Terrain, environment painting, lighting, navigation, collision, prefabs, and scene validation.
- GLB is the runtime target; OBJ/FBX/text glTF require explicit conversion or a documented importer.
- Add asset dependency checks and portable project packaging.

### Phase 6 — Quality and release
- Compiler tests, runtime smoke tests, fixture projects, performance budgets, accessibility, and documentation.
- Run the existing test suite and compile checks on every pull request.
- Do not merge or publish untested engine changes.

## Free asset policy

Prefer assets with clear per-pack licenses and retain each pack's license file and source URL in the project asset metadata. Do not assume every item on a site shares one license.

Recommended sources:
- Kenney — https://kenney.nl/assets. Kenney states its asset-page downloads are CC0; verify the individual pack page and include its license file.
- Quaternius — https://quaternius.com. Check the specific pack license: some packs use CC0 and others use the Quaternius Asset License, which permits game use but restricts standalone asset redistribution.
- Poly Haven — https://polyhaven.com. Its assets are CC0, suitable for models, materials, and HDRIs.

The engine should never bundle a third-party asset without recording the exact source and license. Do not repackage or redistribute Quaternius assets as a standalone asset library where its license forbids it.

## Expanded editor specification

See [`EDITOR_FEATURE_CATALOG.md`](./EDITOR_FEATURE_CATALOG.md) for the detailed feature catalogue and recommended implementation order. It covers the unified asset browser, 3D model and material workflows, texture/shader editing, 2D sprite/tilemap tools, drag-and-drop responsive HUD editor, audio mixer, 2D/3D VFX, ultimate ability designer with aura and timed stat boosts, animation/cinematics, world building, gameplay graphs, debugging/profiling, and project/build tooling. The catalogue explicitly distinguishes planned work from implemented features and defines completion criteria for each editor.

## Engineering rules

1. Inspect the current implementation before changing it.
2. Make additive changes; do not replace working compiler, renderer, plugin, or project APIs without migration tests.
3. Keep visual editors and runtime APIs separate, with a small documented bridge.
4. Validate every generated Volt example with the real compiler.
5. Prefer small pull requests by phase over one giant engine rewrite.
6. If a feature is only a prototype, label it as such in the UI and docs.
7. Keep the free asset path offline-friendly after import; no game should need a network connection to load local assets.
