# World Studio: Your First 3D World

**[Play the 3:53 captioned walkthrough](world-studio-intro.webm).** This illustrated read-along is based on the current World Studio implementation in `plugins/world-studio/` and its example game files. It has no voice track; the full narration text is below and in `storyboard.json`.

## What it covers

1. The visual scene workflow and how it fits into a Volt game.
2. The Things palette, Three.js viewport, hierarchy and Properties panel.
3. Camera navigation, transform tools, framing, grid and axes.
4. Scene objects, grouping, attached Script and Effect components, and Spawn.
5. How Save world writes generated Volt code and a scene snapshot between world markers.
6. How geometry, collision, player start and the game loop work together.
7. A concise crate script that triggers its magic-circle effect once per E press.
8. A practical build, save, compile and preview checklist.

## Full narration

### Build a world visually

Welcome to World Studio, Volt Studio's visual editor for building small three dimensional game worlds. You create and arrange things in the viewport, then save the world into a normal Volt game file. The editor turns that scene into Volt code, while leaving your own game logic outside the generated section. This walkthrough follows the path from the editor, to the saved file, to a running game.

### Read the editor

The left strip holds things you can add, such as parts, walls, floors, lights, characters, scripts and effects. The center is the Three.js viewport. The Things list shows the scene hierarchy, including children attached to a parent. Select an item to edit its values in Properties. The toolbar switches between picking, moving, turning and resizing. Use Frame to see the whole scene and Focus to center the selected thing.

### Navigate and place objects

In the viewport, right drag turns the editor camera, middle drag pans, and the mouse wheel zooms. The view cube switches to top, front, back, left or right. Grid and Axes can be toggled independently. Click to select an object, then drag it with the active transform tool. Frame fits the whole scene; Focus centers the selected object. These controls change the editor camera or scene object, not the player camera in your game.

### Build a scene hierarchy

Parts, balls, pillars and models are scene objects. The Properties panel edits their names, positions, sizes, colors, visibility and collision setting. You can place objects under another object to make a group that moves together. Script and Effect entries are attached components: they belong to a thing, but do not appear as separate geometry. A Spawn sets where the player begins.

### Save and understand the file

Save world writes the scene into the open Volt file. World Studio stores a compact JSON scene snapshot on a comment line, between its world markers. It also writes the readable Volt instructions that build the world. When you save again, the editor replaces only that marked world section. Settings and your own game code outside the markers are preserved. When loading, the saved snapshot restores details that are not easy to infer from code alone.

### From scene to playable game

The generated code describes the scene with Volt's three dimensional commands. A part becomes a `block3d` object. Solid boxes tell the game kit where the player can walk and stand. Player Start records the spawn point. The game kit handles first person movement. In the `every frame` loop, `playerStep` reads movement input, `worldStep` runs World Studio behaviors, and `render3d` draws the scene. You can keep gameplay code below the generated world section.

### Scripts and visual effects

An Effect component stores a preset, color and size. World Studio generates a `vfx_` function for it. A Script component links a Volt file and function, then World Studio imports and calls that function according to its trigger setting. Here is the simpler crate example. The script runs through `worldStep`. It remembers whether E was down last frame, so it calls the magic circle only on a fresh press while the player is nearby. Releasing E lets the next press trigger it again.

### Compile, preview, improve

A reliable first workflow is simple. Add a floor and a few parts, set the spawn, and check which objects should be solid. Add a Script or Effect only when the world needs behavior. Save world, compile the Volt file, and preview the game. Walk around with W A S D and the mouse. Check collision, the spawn height, the effect location and the controls. Make a change, save, compile and preview again. The editor test also checks that generated scripts and effects are wired into the game loop.

## Crate script shown in the video

Attach an Effect component to the crate, set it to the Magic circle preset with its trigger set to **Only when something else calls it**, and link a Script component to `Scripts/script.volt` with function name `world_script`.

```volt
let e_was_down = false

fn world_script() {
  let e_is_down = held("e")
  if e_is_down and not e_was_down and playerNear(-200, -250, 150) {
    vfx_Effect()
  }
  e_was_down = e_is_down
}
```

The linked script runs through `worldStep()`. `held("e")` reads the key state, `playerNear` checks distance from the crate, and `e_was_down` makes the condition true only on the transition from released to pressed. Releasing E resets the edge detector for the next use.

## Re-render on Windows

Run `npm ci`, then:

```powershell
powershell -ExecutionPolicy Bypass -File tools/world-studio-intro/render.ps1
```

The renderer records a captioned WebM into `docs/world-studio-intro.webm`.
