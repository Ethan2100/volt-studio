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

## Install

1. Run **Volt Studio Setup 1.4.0.exe**.
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
| `examples/` | Example programs shown in the Examples tab |
| `docs/REFERENCE.md` | The full Volt reference (also shown in the app's Reference tab) |
| `installer/` | The Windows installer script, icon and pictures |
| `test/` | Scripts used to test the app with fake boards |
| `.github/workflows/release.yml` | Builds the installer on GitHub and publishes a release (see `RELEASING.md`) |
