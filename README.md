# Volt Studio

A desktop editor for the **Volt** language. Write Volt once, and the first line decides what it becomes:

| First line | Becomes | Button |
|---|---|---|
| `#c++` | Arduino C++ | Upload |
| `#micropython` | MicroPython for ESP32 / Pico | Upload |
| `#python` | Python script | Run |
| `#ruby` | Ruby script | Run |
| `#js` | JavaScript (Node.js) | Run |
| `#html` | Web page (HTML + CSS + JS) | Preview |

It also drives servos, stepper motors (28BYJ-48), buttons, LEDs, buzzers and sensors on Arduino boards.

## Download

**[Download the latest Windows installer](https://github.com/Ethan2100/volt-studio/releases/latest)**

Open the link, then download **Volt Studio Setup `<version>`.exe** from the release assets. If no release is published yet, use the **Actions → Build and release** workflow described below; it will publish the installer here automatically.

## Install

1. Run **Volt Studio Setup 1.9.0.exe**.
2. If Windows shows "Windows protected your PC", click **More info → Run anyway** (the app isn't code-signed).
3. Click through the installer. You can choose a desktop shortcut and whether `.volt` files open in Volt Studio.

It installs just for you (no admin password needed) into `%LOCALAPPDATA%\Programs\Volt Studio`, and adds Volt Studio to the Start menu.

**Updating:** run a newer Setup file; it replaces the old version and keeps your settings.
**Uninstalling:** Settings → Apps → Volt Studio → Uninstall. Your `.volt` programs are never deleted.

## Uploading to a board

- **Arduino (`#c++`)**: install the **Arduino IDE 2** from arduino.cc. Volt Studio finds the `arduino-cli` inside it automatically. Check with **Tools → Upload Setup Check**.
- **ESP32 / Pico (`#python`)**: install MicroPython on the board once (Thonny: *Tools → Options → Interpreter → Install or update MicroPython*). Volt Studio does the rest.

## Running scripts

- **JavaScript** runs straight away (Volt Studio has Node.js built in).
- **Python** needs Python from python.org (tick "Add python.exe to PATH").
- **Ruby** needs Ruby from rubyinstaller.org.
- **HTML** pages open in a preview window; Sketch → Open Page in Browser opens them in your normal browser.

## Hybrid game-engine roadmap

Volt Studio combines visual authoring tools with the Volt language. See the [engine roadmap](docs/ENGINE_ROADMAP.md) for model/animation, audio, VFX, world-building, and gameplay-system phases, plus the free-asset licensing policy. The [asset workflow](docs/ASSETS.md) explains supported GLB models, embedded animations, images, and audio.

## World Studio

Watch the [captioned World Studio introduction](docs/world-studio-intro.webm) and read its [full code walkthrough and transcript](docs/world-studio-intro-transcript.md).

## Run from the source code

You need Node.js (you already have it).

```
npm install
npm start
```

## Making a release

On GitHub: **Actions → Build and release → Run workflow**, type the new version, and GitHub builds and publishes the installer. Details in [RELEASING.md](RELEASING.md).

## Build the installer yourself (on Windows)

Install NSIS from nsis.sourceforge.io, then:

```
npm install
npm run installer
```

This creates `dist\Volt Studio Setup <version>.exe` using `installer/installer.nsi`.

## Project layout

| Path | What it is |
|---|---|
| `compiler/volt.js` | The Volt compiler (also works alone: `node compiler/volt.js file.volt`) |
| `main.js` | The app's main process: files, compiling, uploading, serial port |
| `preload.js` | The safe bridge between the page and the main process |
| `lib/micropython.js` | Sends `main.py` to MicroPython boards over USB |
| `renderer/` | The editor page: `index.html`, `styles.css`, `renderer.js`, `volt-mode.js` (syntax colours) |
| `plugins/` | Built-in plugins and integrations |
| `examples/` | Example programs shown in the Examples tab |
| `docs/REFERENCE.md` | The full Volt reference (also shown in the app's Reference tab) |
| `docs/ASSETS.md` | Project asset import formats, previews, and known limitations |
| `installer/` | The Windows installer script, icon and pictures |
| `test/` | Scripts used to test the app with fake boards |
| `.github/workflows/release.yml` | Builds the installer on GitHub and publishes a release (see `RELEASING.md`) |


## Unified World Studio

**World Studio is the home for the whole game.** Use the **Game** button inside World Studio to create and edit abilities, items, NPCs, HUD elements, quests, progression, enemy behaviour, loot tables, player stats, status effects, save fields, checkpoints and interactions. Definitions are stored in the project-wide `volt-game-data.json` database and linked into the World Studio hierarchy. Changes autosave to the open project; use **Save game** to save the scene and shared game data together.

The older Gameplay Studio and RPG Studio panels are retained in the source for compatibility but are hidden from the main panel list to avoid duplicate workflows. Existing examples and `.skillset.json` assets remain usable as reference assets.

- [World Studio](plugins/world-studio/index.html)
- [Unified game project format](docs/UNIFIED_GAME_PROJECT.md)
- [Shadow Lifesteal playable example](examples/shadow-lifesteal/Shadow%20Lifesteal.volt)
- [Shadow Lifesteal skillset asset](examples/shadow-lifesteal/Shadow%20Lifesteal.skillset.json)
- [Editor feature catalog](docs/EDITOR_FEATURE_CATALOG.md)
