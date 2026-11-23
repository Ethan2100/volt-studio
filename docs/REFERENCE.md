# Volt Reference

Volt is a small language that turns into other languages. You write a `.volt` file, and the first line decides what it becomes: **Arduino C++** or **MicroPython** for boards, **Python**, **Ruby** or **JavaScript** scripts that run on your PC, or an **HTML web page**.

```volt
#c++
pin led = 13

every 500ms {
  toggle led
}
```

## Contents

1. [The first line: picking the output](#the-first-line-picking-the-output)
1. [Scripts and web pages](#scripts-and-web-pages)
1. [Lists](#lists)
1. [Games: canvas, sprites and keys](#games-canvas-sprites-and-keys)
1. [3D game files: the player and World Studio](#3d-game-files-the-player-and-world-studio)
1. [Game types (structs)](#game-types-structs)
2. [How a Volt program runs](#how-a-volt-program-runs)
3. [Comments](#comments)
4. [Pins](#pins)
5. [Controlling pins](#controlling-pins)
6. [Reading pins](#reading-pins)
7. [Variables and math](#variables-and-math)
8. [Text and print](#text-and-print)
9. [Times and waiting](#times-and-waiting)
10. [Decisions: if and else](#decisions-if-and-else)
11. [Loops: repeat, while, break](#loops-repeat-while-break)
12. [Running things over time](#running-things-over-time)
13. [Functions](#functions)
14. [Reusing code: import](#reusing-code-import)
15. [Built-in functions](#built-in-functions)
15. [Raw code](#raw-code)
16. [C++ vs Python differences](#c-vs-python-differences)
17. [Names you can't use](#names-you-cant-use)
18. [Using Volt Studio](#using-volt-studio)
19. [Using the command line](#using-the-command-line)
20. [Cheat sheet](#cheat-sheet)

---

## The first line: picking the output

The first line of code (blank lines and `//` comments before it are fine) chooses what Volt compiles to:

| First line | Output | What it's for | In Volt Studio |
|---|---|---|---|
| `#c++` | `name/name.ino` | Arduino Uno, Nano, Mega, Leonardo, ESP32, ESP8266 | **Upload** |
| `#micropython` | `name/main.py` | ESP32 or Raspberry Pi Pico running MicroPython | **Upload** |
| `#python` | `name/name.py` | A Python script on your PC (needs Python installed) | **Run** |
| `#ruby` | `name/name.rb` | A Ruby script on your PC (needs Ruby installed) | **Run** |
| `#js` | `name/name.js` | A JavaScript (Node.js) script. Volt Studio runs it with nothing to install | **Run** |
| `#html` | `name/index.html` | A web page: HTML, CSS and JavaScript in one file | **Preview** |

If there's no first line, Volt uses `#c++`. Other spellings work too: `#cpp`, `#arduino`, `#py`, `#rb`, `#javascript`, `#node`, `#web`.

`#python` is smart: if the program uses `pin`, it becomes **MicroPython** for a board; otherwise it's a normal Python script.

There's no `#css`: CSS goes inside an `#html` program on `##` lines (see [Web pages](#web-pages)).

Most programs work with several first lines, so switching is just changing that line. In Volt Studio, use the **language list** in the top bar.

| Feature | Boards (`#c++`, `#micropython`) | Scripts (`#python`, `#ruby`, `#js`) | `#html` |
|---|---|---|---|
| `pin`, `on`, `read`, `when … pressed` … | ✓ | ✗ | ✗ |
| Text variables, `number`, `text`, `length` | ✓ | ✓ | ✓ |
| `ask` | `#micropython` only | ✓ | ✓ (a box on the page) |
| `button`, `title`, `html`, `when key` | ✗ | ✗ | ✓ |
| `every`, `forever`, `wait`, functions, loops | ✓ | ✓ | ✓ |

## Scripts and web pages

### Text variables

Variables can hold text as well as numbers:

```volt
#python
let name = "Ethan"
let greeting = "Hi " + name
print greeting
```

A variable keeps the kind of value it started with. `let score = 0` always holds a number and `let name = "Ethan"` always holds text, and Volt tells you if you mix them up.

Inside quotes you can use `\"` for a quote mark, `\n` for a new line, `\t` for a tab and `\\` for a backslash:

```volt
print "She said \"hi\"\nand left"
```

### ask (or input)

`ask` shows a question and waits for the person to type an answer. The answer is text. `input` does exactly the same thing, so you can write it the Python way: `input "Name?"` or `input("Name?")`.

```volt
#ruby
let name = ask "What's your name?"
print "Nice to meet you, " + name + "!"
```

In Volt Studio, type the answer in the box at the bottom of the **Console** and press Enter. In an `#html` page, a question box appears on the page.

### show, clear and stop

| Command | What it does |
|---|---|
| `show "Score: " + score` | On an `#html` page: one line that **updates in place** each time, great for scores and timers. Everywhere else it works like `print` |
| `clear` | Wipes printed text. On a page it keeps the title, buttons and `show` line. In scripts it clears the Console. Not available on boards |
| `stop` | Ends the program right there. On a page, timers, buttons and keys stop too. On a board, it stops doing anything until reset |

```volt
#html
let score = 0
title "Clicker"
show "Score: 0"

button "+1" {
  score += 1
  show "Score: " + score
  if score == 10 {
    print "You win!"
    stop
  }
}
```

### Checking text

| Function | What it does | Example |
|---|---|---|
| `upper(x)` | Text in CAPITALS | `upper("hi")` → "HI" |
| `lower(x)` | Text in small letters | `lower("Nairobi")` → "nairobi" |
| `contains(x, part)` | True if `part` is somewhere in `x` | `contains("Nairobi", "robi")` → true |

These help when checking typed answers, so "NAIROBI", "nairobi" and "Nairobi" all count:

```volt
#python
let city = ask "Capital of Kenya?"
if lower(city) == "nairobi" {
  print "Correct!"
}
```

### Turning text into numbers and back

| Function | What it does | Example |
|---|---|---|
| `number(x)` | Text to a whole number (0 if it isn't a number) | `number("42")` → 42 |
| `text(x)` | A number to text | `text(7) + "!"` → "7!" |
| `length(x)` | How many characters | `length("Volt")` → 4 |

```volt
#js
let age = number(ask "How old are you?")
print "Next year you'll be " + (age + 1)
```

### Web pages

An `#html` program builds a web page as it runs. These commands only work in `#html`:

| Command | What it does |
|---|---|
| `title "My page"` | Sets the page title and shows it as a big heading |
| `print "text"` | Adds a line of text to the page |
| `html "<b>bold</b>"` | Adds HTML markup to the page |
| `button "Click me" { … }` | Adds a button; the block runs each time it's clicked |
| `when key "k" pressed { … }` | Runs the block each time that key is pressed |
| `ask "Question?"` | Shows a box with your question and waits for an answer |
| `background.color = "..."` | Simple page styling - no CSS needed (see below) |
| `## css` | A line of CSS for the page |
| `# javascript` | A raw line of JavaScript |

```volt
#html
## body { background: #10131a; color: white; }
## .big { font-size: 48px; color: gold; }

let clicks = 0
title "Click Counter"

button "Click me" {
  clicks = clicks + 1
  print "Clicked " + clicks + " times"
  if clicks % 5 == 0 {
    html "<div class='big'>" + clicks + "!</div>"
  }
}
```

### Simple styling

For quick visual tweaks without writing any CSS, two built-in names can be styled directly with `=`:

| | What it does | Example |
|---|---|---|
| `background.color` (or `.colour`) | The page's background color | `background.color = "yellow"` |
| `background.image` | A picture behind the page | `background.image = "stars.png"` |
| `text.color` (or `.colour`) | Color of printed text | `text.color = "white"` |
| `text.font` | Font family | `text.font = "Georgia"` |
| `text.size` | Font size (a plain number means pixels) | `text.size = 20` |
| `text.align` | Text alignment | `text.align = "center"` |

```volt
#html
background.color = "#101522"
text.color = "white"
text.font = "Georgia"
text.size = 20

title "Night Mode"
print "Dark background, easy-to-read text - no CSS needed."
```

These can also be changed while the page is running, e.g. inside `every frame` or `when key`, for things like a day/night cycle or a flash on taking damage:

```volt
when key "h" pressed {
  text.color = "red"
  wait 200ms
  text.color = "white"
}
```

For anything these two don't cover - styling a specific button, a custom element you build with `html "..."` - use a `## css` line, same as before.

### Key presses

`when key "…" pressed` runs a block each time a key is pressed on the page. Holding a key down counts as one press.

```volt
#html
let score = 0
title "Key Game"
print "Press K to score!"

when key "k" pressed {
  score = score + 1
  print "Score: " + score
}
```

| Key name | Key |
|---|---|
| `"a"` … `"z"`, `"0"` … `"9"` | That letter or number (capitals count too) |
| `"space"` | Space bar |
| `"up"` `"down"` `"left"` `"right"` | Arrow keys |
| `"enter"` `"escape"` `"tab"` `"backspace"` | Those keys |
| `"any"` | Every key |

Click on the page first so it has focus. Keys aren't counted while someone is typing an answer to `ask`.

`when key` only works in `#html`. On a board, use a real button with `when button pressed`; in scripts, use `ask`.

`every` and `wait` work in pages too, so you can make clocks, timers and animations. The finished `index.html` works in any browser: double-click it, or upload it to a website host like Render.

### Running scripts outside Volt Studio

| Language | Command |
|---|---|
| Python | `python name.py` |
| Ruby | `ruby name.rb` |
| JavaScript | `node name.js` |
| HTML | double-click `index.html` |

## Lists

A list holds many values in one variable. Lists work in `#python`, `#ruby`, `#js` and `#html` (not on boards yet).

```volt
let scores = [3, 1, 4]      // [] is an empty list
add 5 to scores             // put a value on the end
scores[0] = 9               // change one value (counting starts at 0)
scores[1] += 10
remove scores[2]            // take one out; the ones after it move up
print length(scores)        // how many values
print contains(scores, 5)   // true or false

for each s in scores {      // every value, in order
  print s
}
```

Text can be read with `[ ]` too, which makes maps easy to draw as text:

```volt
let rows = ["#####", "#..k#", "#####"]
print rows[1][3]            // k
```

To change a list while going through it (removing defeated monsters, say), use a counter and `while`:

```volt
let i = 0
while i < length(hp) {
  if hp[i] <= 0 {
    remove hp[i]            // don't add 1: the next one moved into place i
  } else {
    i += 1
  }
}
```

Two more built-ins help with text and movement: `part(text, start, count)` cuts out a piece (`part("dungeon", 1, 3)` is `"ung"`), and `sign(x)` is `-1`, `0` or `1`.

## Games: canvas, sprites and keys

An `#html` program can be a real game: a pixel screen, pictures, held keys and sound. The finished `index.html` fills the window with crisp, unblurred pixels.

```volt
#html
canvas 320, 180                       // a screen 320 pixels wide, 180 tall
image tiles = "tiles.png"             // a picture next to your .volt file
sprite hero = tiles at 128, 106 size 16, 22 frames 4

let x = 150
let y = 80
let t = 0

every frame {                         // 60 times a second
  t += 1
  if held("left") { x -= 2 }
  if held("right") { x += 2 }
  paint "#14111a"                     // clear the screen
  draw hero at x, y frame t / 8 flip held("left")
  write "Hello, dungeon!" at 160, 20 centered shadow
}
```

| Command | What it does |
|---|---|
| `canvas 320, 180` | Makes the pixel screen. Run it once, before drawing |
| `image tiles = "tiles.png"` | Loads a picture (`.png`, `.jpg`, `.gif`, `.webp`, `.svg`). Top level only. When you Run or Build, Volt packs it into the page, so `index.html` works on its own |
| `sprite hero = tiles at x, y size w, h` | Cuts a rectangle out of a picture. Add `frames 4` when the animation frames sit side by side |
| `draw hero at x, y` | Draws a sprite. Options, in any order: `frame n`, `flipped` or `flip (condition)`, `angle 90`, `size 2` (whole times bigger), `scale 150` (percent, grows from the middle), `alpha 50` (0-100), `flash (condition)` (pure white, for hits), `tint "#ff8a3d"` (recolours it; great for white glow and smoke pictures), `glow` (adds its light to what's underneath, for fire, magic and lamps) |
| `paint "#14111a"` | Fills the whole screen with a colour |
| `box x, y, w, h color "#ff4d6d"` | A filled rectangle. Colours like `"#00000080"` are see-through. Add `round 6` for soft corners, `edge 2` for a line around it and `edgecolor "#000000"` to colour that line |
| `circle x, y, r color "#4dd2ff"` | A filled circle. `x, y` is the middle and `r` is how far out it goes. Takes `edge` and `edgecolor` too |
| `poly x, y, r, sides color "#ffd23f"` | A regular shape: `3` a triangle, `6` a hexagon, `8` an octagon. `r` is from the middle to a corner. Add `angle 30` to turn it (0 puts a point straight up), plus `edge` and `edgecolor` |
| `write "text" at x, y` | Pixel-font text. Options: `color "#ffd23f"`, `size 2`, `centered`, `right`, `shadow`. `\n` starts a new line |
| `write "text" at x, y font "serif"` | A real font instead of the pixel one. Named ones: `sans`, `serif`, `mono`, `round`, `slab`, `fancy` - or give a font name like `"Georgia"`. Add `bold` for heavy. `size` works the same, so swapping a font in does not move everything else |
| `camera x, y` | Moves the view, for worlds bigger than the screen. Use `camera 0, 0` before drawing the score and hearts |
| `every frame { }` | Runs 60 times a second, at the same speed on every screen |
| `held("left")` | `true` while a key is down (`when key "x" pressed` still runs once per press) |
| `touchscreen()` | `true` on phones and tablets, so a game can move its HUD away from the on-screen buttons |
| `tone 440 for 80ms` | A retro beep. `tone 880 to 220 for 150ms` slides the pitch. On pages it doesn't wait |
| `touchpad "x", "z"` | On phones and tablets: an arrow pad plus a button for each key |
| `touchpad "x", "z" stick "pad.png", "nub.png" button "button.png" icons "sword.png", "dash.png"` | The same with your own pictures: `stick` swaps the arrow pad for a joystick you drag, `button` is the picture behind every button, `icons` gives each key's button a picture (one per key). All three are optional |
| `music "e5 g5 a5 _ -", "a2 - e2 -" tempo 140` | A looping chiptune: a melody and an optional bass line. Each word is one step: a note like `c4` or `f#5`, `-` for a rest, `_` to hold the note before. Starting the song that's already playing does nothing, so it's safe inside `every frame` |
| `music off` | Stops the music |
| `audio hit = "hit1.mp3", "hit2.mp3"` | Loads sound files (`.mp3`, `.ogg`, `.wav`, `.m4a`) from beside your .volt file. Top level only. With several files, each play picks one at random, so repeated hits don't sound the same. Packed into the page like pictures |
| `sound hit` | Plays a sound. Add `volume 40` (0-100) to make it quieter |
| `volume 50` | How loud everything is: sounds, beeps and music. `volume 0` mutes the game |
| `save "best", score` | Keeps a value (a number, text or a list) in this browser, even after the page is closed |
| `saved("best", 0)` | Reads a saved value back, or the default if nothing is saved yet |

Things to know:

- `draw`, `box` and `write` all follow the camera. Positions are whole pixels.
- Browsers only play sound after the player presses a key or clicks, so start the music from a title screen's "press X". `.mp3` files work in every browser.
- Volt numbers are whole numbers. For smooth slow movement, keep positions times 10 (`x10 += speed`) and draw at `x10 / 10`.
- `examples/dungeon/moonwell.volt` is a full dungeon crawler written this way: six floors with six bosses, keys, weapons, a shop, music, sound effects and a saved journey.

## 3D games: world3d, blocks and lights

An `#html` program can also be a **first-person 3D game**. Volt bundles Three.js (WebGL) into the finished `index.html`, so it still works by double-click or on a website host. The 2D `canvas` stays on top as your HUD: `box` and `write` draw over the 3D world, and `render3d` clears them each frame, so draw your HUD *after* `render3d`.

```volt
#html
canvas 320, 180
world3d "#05060a" fog 1600 ambient 6 shadows

let floor = block3d(0, -5, 0, 1200, 10, 1200, "#6a6f78")    // x, y, z (the middle), width, height, depth, colour
let wall = block3d(0, 150, -600, 1200, 300, 20, "#7b808a")
let cell = block3d(300, 120, 100, 20, 30, 20, "#2a8aa8")
glow3d cell, "#4de1ff"                                       // it lights itself up
let lamp = lamp3d(300, 140, 100, "#4de1ff", 20, 500)         // a point light

torch3d 60, 1800                                             // a flashlight on the camera
let x = 0
let z = 400
let yaw = 0
every frame {
  yaw += mousedx() * 3                                       // click the page first: the mouse is captured
  if held("w") { z -= 4 }
  camera3d x, 165, z, yaw, 0
  render3d
  write "Hello, 3D" at 160, 8 centered shadow
}
```

In your program **1 unit = 1 cm** (a 2 m corridor is 200) and **y is up**. **Angles are tenths of a degree** (900 is a quarter turn) so mouse-look is smooth with whole numbers. Yaw 0 looks along -z; turning right makes the yaw bigger.

| Command | What it does |
|---|---|
| `world3d "#05060a" fog 1600 ambient 6 fov 75 shadows` | Starts the 3D world. Colour first, then any options: `fog` (how far you can see, in cm), `ambient` (base light 0-100), `fov`, and `shadows` (the flashlight casts shadows) |
| `block3d(x, y, z, w, h, d, "#colour")` | Makes a box and gives back its number. Boxes get a grimy panel texture so flat colours look like surfaces |
| `lamp3d(x, y, z, "#colour", power, range)` | Makes a point light and gives back its number (power 0-100, range in cm) |
| `clear3d` | Removes every block and lamp (use it when building a new level) |
| `camera3d x, y, z, yaw, pitch` | Puts the camera somewhere. Pitch above 0 looks up |
| `torch3d power, range` | A flashlight on the camera. Power 0 turns it off |
| `move3d id, x, y, z` | Moves a block or lamp |
| `turn3d id, yaw` | Turns a block round |
| `show3d id, flag` | Shows or hides a block or lamp |
| `glow3d id, "#4de1ff"` | Makes a block shine with its own light colour |
| `ball3d(x, y, z, radius, "#colour")` | Makes a sphere (x, y, z is its middle) and gives back its number |
| `cyl3d(x, y, z, radius, height, "#colour")` | Makes an upright cylinder (a pillar, barrel or pipe) and gives back its number |
| `shine3d id, rough, metal` | Makes a surface glossy or metal. Both 0-100: rough 0 is a mirror and 100 is chalk, metal 100 is solid metal. Works on blocks, balls, cylinders and models |
| `fx3d bloom, vignette, grain` | The cinematic look. Bloom makes bright things glow (try 60), vignette darkens the edges (40), grain adds film noise (10). It also turns on film tone-mapping and soft shadows. All 0 turns it off |
| `burst3d x, y, z, "#ff8844", count, speed` | A burst of glowing sparks that fly out and fall. Count up to 300, speed in cm per second. With `fx3d` bloom on they really glow |
| `slash3d x, y, z, yaw, size, "#colour"` | A curved blade arc that sweeps and fades - the anime slash. `yaw` is tenths of a degree (which way it faces), `size` is how big it is across, in cm |
| `magic3d x, y, z, size, "#colour", ms` | A magic circle lying on the ground: two rings turning opposite ways with ticks round the rim, for `ms` milliseconds |
| `shock3d x, y, z, size, "#colour"` | A ring that races outwards and fades - an impact, a landing, a blast |
| `beam3d x1, y1, z1, x2, y2, z2, thick, "#colour"` | A glowing beam from one point to another, thinning as it fades |
| `render3d` | Draws the 3D world and clears the 2D layer. Call it once per frame |
| `mousedx()` `mousedy()` | How far the mouse moved since last asked. The first click on the page captures the mouse (Esc lets go) |
| `locked3d()` | 1 while the mouse is captured |
| `sin3(a)` `cos3(a)` | The whole-number 3D versions: angle in tenths of a degree in, thousandths out: `sin3(900)` is 1000. (Plain `sin` and `cos` take degrees and give decimals, see Maths.) |
| `atan2(y, x)` | The angle (0 to 3599) that points from the origin to x, y |
| `sqrt(n)` | Whole-number square root |

`examples/one-more-floor/one-more-floor.volt` is a complete 3D horror game made this way: random floors, a creature that patrols, hears, chases and sniffs out lockers, a flashlight, stamina and an elevator. Three.js is MIT licensed (`lib/THREE_LICENSE.txt`).

`examples/28_thornkeep_realm.volt` is a walkable medieval RPG fantasy map built the same way: a castle, a village, a market, a lake with a bridge, forest and farmland, all just `block3d`/`cyl3d`/`ball3d` calls placed by a handful of small builder functions (`cottage`, `wallTower`, `tree`...) - a good example to copy from for your own open-world map.

### Models: model3d, put3d, anim3d

| Command | What it does |
|---|---|
| `model3d name = "file.glb"` | Loads a `.glb` model before the game starts. The file is packed into the page, and its textures must be packed inside the `.glb`. |
| `put3d(name, x, y, z, yaw, scale)` | Puts a copy of the model in the world and gives back its id. `scale` is a percent (100 = the size it was made, 1 unit = 1 metre). |
| `anim3d id, "walk"` | Plays one of the model's animations on a loop. Part of the name is enough. |

`move3d`, `turn3d`, `show3d` and `glow3d` work on models too.

### The anime effects: slash3d, magic3d, shock3d, beam3d

These four are one-shot: fire one and forget it. Each makes a glowing
shape that grows, turns or races outwards, fades, and tidies itself away -
nothing to keep hold of, nothing to clean up.

```volt
if held("q") {
  slash3d px, 120, pz, yaw, 240, "#dff3ff"      // a sword arc, facing where you look
}
if held("e") {
  magic3d px, 0, pz, 340, "#9d6bff", 1600       // a circle on the ground for 1.6s
}
```

They are drawn as light rather than as solid things, so `fx3d` bloom makes
them glow properly - try `fx3d 70, 30, 6`. Sizes are in cm like everything
else in 3D, and `yaw` is tenths of a degree, so a value you already keep
for the camera or a character can be passed straight in.

`examples/32_anime_effects.volt` puts all four on one key each.

### Mouse look, distances and angles

These already exist and are easy to miss, so they are listed together here.

| Command | What it does |
|---|---|
| `mousedx()` / `mousedy()` | How far the mouse moved since you last asked. This is how you turn the camera. |
| `locked3d()` | 1 once the mouse is captured for looking around. |
| `screenx3d(x, y, z)` / `screeny3d(x, y, z)` | Where a point in the world lands on the flat layer `box` and `write` draw on. This is how a name, a health bar or a damage number sits over something in the world. |
| `onscreen3d(x, y, z)` | `true` when that point is in front of the camera and on screen. Check it before drawing, or things behind you appear mirrored on screen. |

**You do not have to ask for the mouse.** Clicking anywhere in a 3D game captures it
automatically, and `mousedx()` / `mousedy()` start reporting movement from then on. Pressing
Escape releases it, and a click captures it again.

| Command | What it does |
|---|---|
| `dist(x1, y1, x2, y2)` | Straight-line distance between two points. Use it for "is the enemy close enough to hit". |
| `overlaps(ax, ay, aw, ah, bx, by, bw, bh)` | True when two boxes touch. Use it instead of writing four comparisons by hand. |
| `sin3(angle)` / `cos3(angle)` | Sine and cosine in tenths of a degree, giving thousandths back. Use them to move in the direction something is facing. |
| `atan2(y, x)` | The angle from one point to another, in tenths of a degree. Use it to turn an enemy towards the player. |

So moving forwards in whatever direction the hero faces is:

```volt
px += sin3(yaw) * speed / 1000
pz -= cos3(yaw) * speed / 1000
```

### The anime look: toon3d

Normal 3D lighting makes everything look like a photograph. Anime games don't use it. They use
flat bands of colour instead of a smooth fade, a bright edge where a character catches the light,
and a dark line drawn around the silhouette. `toon3d` turns all three on at once.

```volt
#html
world3d "#141026" fog 2200 ambient 14 fov 55 shadows
toon3d 3, 35, 60        // bands, outline thickness, rim brightness
fx3d 45, 30, 4          // bloom, vignette, grain - anime art is bloomy
```

| Command | What it does |
|---|---|
| `toon3d bands, outline, rim` | Switches the whole world to the anime look. `bands` 2-8 is how many steps of light there are (3 is the usual, 2 is harsher). `outline` 0-100 is the thickness of the dark line, 0 turns it off. `rim` 0-100 is how bright the edge glow is, 0 turns it off. |

Put `toon3d` just after `world3d`. Anything placed afterwards is drawn this way, and anything
already placed gets restyled. It works on `block3d`, `ball3d`, `cyl3d` and loaded models alike.

Raising `bands` softens the look; lowering it makes it harsher and more graphic. Turning `rim`
up past about 70 starts to look like the character is glowing rather than lit, which is worth
doing on purpose for a transformation scene and worth avoiding the rest of the time.

### Moving many shapes as one: group3d, join3d

A character built out of blocks and balls is a dozen separate objects. Without a group you have
to `move3d` and `turn3d` every single one of them, every frame. A group is one object you move
instead, and everything inside comes along.

```volt
let hero = group3d(0, 0, 700)        // the point the hero stands on and turns around
let torso = block3d(0, 105, 700, 72, 115, 42, "#9b493b")
let head  = ball3d(0, 235, 700, 38, "#c5a98a")
join3d torso, hero
join3d head, hero

every frame {
  move3d hero, px, 0, pz             // the whole hero moves
  turn3d hero, yaw                   // and turns together
  render3d
}
```

| Command | What it does |
|---|---|
| `group3d(x, y, z)` | Makes an empty group at that spot and gives back its id. The spot is what the group turns around, so put it where the feet are, not in the middle. |
| `join3d part, group` | Puts a shape (or a model, or another group) inside the group. The part stays exactly where it already looks, so you can build everything in world coordinates first and group it afterwards. |

`move3d`, `turn3d` and `show3d` all work on a group. Hiding a group hides everything in it.

### Doing something later: after

`wait` stops everything until it finishes, so a `wait` inside `every frame` freezes the whole
game while it counts down. `after` does not - it runs the block once, later, and the game keeps
going in the meantime. Use it for anything that happens during play.

```volt
after 1700ms {
  bars3d 0                 // end the cutscene a moment from now
}
```

| Command | What it does |
|---|---|
| `after 1700ms { ... }` | Runs the block once, that much later, without holding anything up. Several can run at the same time. `#html` and `#js` only. |

Use `wait` for a scripted sequence before play starts, and `after` for anything during play.

### Cutscenes and fight feel: shot3d, shake3d, slowmo3d, hitstop3d, bars3d

| Command | What it does |
|---|---|
| `shot3d x, y, z, atx, aty, atz, ms` | Glides the camera to `x, y, z` over `ms` milliseconds while keeping it pointed at `atx, aty, atz`. Call it once - it keeps running on its own until it finishes. |
| `lookat3d x, y, z` | Points the camera at a spot in the world right now. |
| `shake3d power, ms` | Shakes the camera. `power` 0-100: about 20 for a footstep, about 70 for a boss landing. |
| `slowmo3d percent, ms` | Runs the world at `percent` of normal speed (10-100) for `ms` of real time. |
| `hitstop3d ms` | Freezes everything for a moment. 60-120 ms on a heavy hit is what makes it feel heavy. |
| `bars3d on` | `1` draws black cinema bars top and bottom, `0` removes them. |

A hit that lands well is usually three of these together, in this order:

```volt
hitstop3d 90          // freeze on the impact frame
shake3d 55, 220       // then the camera jolts
burst3d x, y, z, "#ffd36e", 40, 260
```

A cutscene is `bars3d 1`, one or more `shot3d` calls, then `bars3d 0`:

```volt
bars3d 1
shot3d 0, 180, 600, 0, 150, 0, 2500     // slow push towards the hero
wait 2500ms
shot3d 400, 90, 150, 0, 150, 0, 1200    // cut round to the side
wait 1200ms
bars3d 0
```

`shake3d` deliberately ignores slow motion, so a slow-motion impact still hits hard.

## 3D game files: the player and World Studio

Everything above builds a 3D world. This part is about the person walking
around in it - and about the shape of file World Studio writes, so that
building the world in the editor and writing the game by hand don't fight
over the same file.

### The three parts of a game file

```volt
#html
title "Cell Run"
canvas 320, 180

import "game.volt"      // 1. the player

// ---- 2. settings: change any of these ----
WALK_SPEED = 420
JUMP_POWER = 460

// >>> world-studio
world3d "#05060a" fog 1800 ambient 10 shadows
let Floor = block3d(0, -5, 0, 1600, 10, 1600, "#5d626b")
clearSolids()
solid(0, 0, 800, 800, -10, 0)
playerStart(0, 600, 0)
// <<< world-studio

// ---- 3. your game ----
every frame {
  playerStep()
  render3d
  write "Hello" at 10, 10 shadow
}
```

The two marker lines matter: **World Studio rewrites only what is between
them.** Press *Save world* in the World Studio tab as often as you like -
your settings above and your game below are left exactly as you wrote
them. A file with no markers is left alone, and World Studio offers to
start a game file instead.

`examples/30_world_studio_game.volt` is a small finished game in this
shape: collect three cells, one of which is up a stack of crates and one
behind a beam you have to crouch under.

### The player: import "game.volt"

`import "game.volt"` brings in the **game kit**, the library plugin that
holds the first-person player. Volt Studio finds it on its own (library
plugins are searched after your own folder), so there's nothing to copy.
For a `.volt` file that has to compile somewhere else - the command line,
someone else's machine - open the Library tab, paste the *Game kit*
snippet into the file and delete the import line.

| Function | What it does |
|---|---|
| `playerStep()` | One frame of being a person: mouse look, walking, jumping, falling, and the camera. Call it first in `every frame`, before `render3d` |
| `playerStart(x, z, yaw)` | Puts the player somewhere, facing a direction (yaw in tenths of a degree). Call it once, after the world is built |
| `solid(x, z, halfWidth, halfDepth, bottom, top)` | Adds one box the player bumps into. Knowing the `top` means they can stand on it; knowing the `bottom` means a ceiling is something they walk *under* |
| `clearSolids()` | Forgets every solid box - call it before building a new level |
| `playerNear(x, z, howClose)` | True when the player is within `howClose` cm of a point on the ground |
| `playerFacing(x, z, spread)` | True when they're looking at a point, within `spread` tenths of a degree |
| `blocked(x, z, feet)` / `groundHeight(x, z, feet)` | The two questions the player asks every frame, if you want to ask them yourself (for an enemy, say) |

The player's own state is there to read - and to change, for a teleport
or a cutscene:

| Variable | What it is |
|---|---|
| `PLAYER_X` `PLAYER_Y` `PLAYER_Z` | Where they are. `PLAYER_Y` is their **feet**, not their eyes |
| `PLAYER_YAW` `PLAYER_PITCH` | Where they're looking, in tenths of a degree |
| `PLAYER_FALL` | How fast they're moving up (+) or down (-) |
| `PLAYER_GROUNDED` | True while they're standing on something |
| `PLAYER_MOVING` `PLAYER_RUNNING` `PLAYER_CROUCHING` | What they're doing right now - handy for footstep sounds and stamina |

### Settings

Every setting is a plain variable, so change it with one line **after**
the import (no `let` - it already exists). Change one in the middle of the
game and it takes effect straight away, which is how you do a speed
power-up or a cutscene.

| Setting | Default | What it does |
|---|---|---|
| `WALK_SPEED` | 400 | How fast you walk, in cm a second |
| `RUN_SPEED` | 750 | ... while holding Shift |
| `CROUCH_SPEED` | 180 | ... while holding Ctrl |
| `MOUSE_SPEED` | 3 | How fast the mouse turns the camera |
| `INVERT_LOOK` | false | true = pushing the mouse up looks down |
| `LOOK_LIMIT` | 850 | How far up and down you can look (850 = 85°) |
| `EYE_HEIGHT` | 165 | How tall the player is, in cm |
| `CROUCH_HEIGHT` | 95 | ... while crouching |
| `JUMP_POWER` | 430 | How hard they jump, in cm a second (about 60 cm high) |
| `GRAVITY` | 1500 | How hard they fall, in cm a second per second |
| `STEP_HEIGHT` | 45 | Anything this low is a step, not a wall |
| `PLAYER_WIDTH` | 25 | Half the player's width, in cm |
| `HEAD_BOB` | 3 | How much the view bounces as they walk (0 = off) |
| `CAN_RUN` `CAN_JUMP` `CAN_CROUCH` | true | Turn a move off for this game |
| `CAN_MOVE` | true | false freezes the player, for a cutscene or a menu |

The controls that come with it: **W A S D** (or the arrow keys) to walk,
**mouse** to look, **Shift** to run, **Space** to jump, **Ctrl** to crouch.
Clicking the page captures the mouse and Escape lets it go.

### Characters

Volt Studio comes with rigged characters - the **character pack** plugin -
so a game can have people in it without finding models first. They live in
the plugin's own folder, which `model3d` searches after your own, so this
works from any `.volt` file with nothing to copy:

```volt
model3d hunter_model = "hunter.glb"
let guard = put3d(hunter_model, 0, 0, -400, 0, 100)
anim3d guard, "sprint"
```

The people are `coworker_cyan`, `coworker_gold`, `coworker_red`, `hunter`,
`raider`, `raider2` and `ninja`. Each one has the same 27 animations:
static, idle, walk, sprint, sit, drive, die, pick-up, emote-yes, emote-no,
holding-right, holding-left, holding-both, holding-right-shoot,
holding-left-shoot, holding-both-shoot, attack-melee-right,
attack-melee-left, attack-kick-right, attack-kick-left, interact-right,
interact-left, and five wheelchair ones.

There are also three animals - `wolf`, `bear` and `deer` - box models
with no animations. The people are Kenney's *Blocky Characters*, recoloured
(CC0); the animals were built in Blender for 99 Nights. (The detailed
trees and rocks in that game are a different thing: Quaternius's *Stylized
Nature MegaKit*, which lives with the example, not here.)

Any other `.glb` dropped into the `character-pack` plugin's folder joins
the list - World Studio reads the folder for the **Who** dropdown and reads
the animation names out of the model itself for **Doing**, so a pack with
its own naming (`Idle`, `Run`, `Attack`) works with nothing to change.

`import "characters.volt"` adds the part that makes them look alive: an
**actor** walks to a point, turns to face the way it's going, and plays
idle / walk / sprint to match, instead of sliding about in a T-pose.

| Function | What it does |
|---|---|
| `actor(model, x, z, yaw)` | Starts looking after a model you placed with `put3d`. Gives back its actor number |
| `actorWalkTo(i, x, z, speed)` | Sends it to a point at that speed (cm a second). Pass the player's position every frame for a chase |
| `actorStop(i)` | Stops it where it stands |
| `actorStep(i)` / `actorsStep()` | One frame for one actor, or for all of them. Call it in `every frame` |
| `actorPlay(i, "attack-melee-right")` | Plays an animation, and doesn't restart it while it is already playing |
| `actorNear(i, x, z, howClose)` | True when it has reached a point - "has it caught me yet" |

`ACTOR_WALK` (260) is the speed it starts sprinting at, and `ACTOR_TURN`
(90) is how fast it turns, in degrees a second.

`examples/31_characters_and_scripts.volt` is a small game built this way:
a guard chases you, a campfire burns, and standing by the fire sends the
guard back to its post.

### World Studio

The **World Studio** tab is the 3D editor: a viewport with the parts you
can place down the left, the things in your world and their properties
down the right, and *Play* to walk around what you've built with the same
walking, jumping and crouching the finished game has.

- **Parts** - click one to drop it in front of the camera, or drag it into the world. A part marked *Solid* stops the player, can be stood on, and gets a `solid(...)` line; one that isn't is scenery.
- **Grid** rounds everything off so walls line up (and turning snaps to 15°).
- **Save world** writes the world into the `.volt` file in the editor, between the markers.
- The **⋯** menu has game lighting, reading a world back out of a file, the raw Volt code, starting over, and a short *How do I...?* page.

### Things inside things, scripts and effects

The **Things** list is a tree, like Roblox's Explorer: drag a row onto
another row to put it inside. Move or turn the outer thing and everything
inside comes along, and the saved world does the same with a group:

```volt
let Sword_group = group3d(100, 90, -200)
join3d Sword, Sword_group
join3d Gem, Sword_group
```

Two kinds of thing go *inside* a part and have no body of their own:

- A **Script** is plain Volt. It becomes a function named after it, like
  `fn script_Swing()`, and runs when you choose: at the start, every frame,
  when the player is close, or when they press **E** close by. The part it
  sits in is available by name - a Script inside `Sword` can use `Sword`,
  which is that part's number in the game. A variable you invent needs its
  own `let` line in the game part of the file first.
- An **Effect** is one of the glowing things above: a burst of specks, a
  sword **slash**, a **magic circle**, a **shockwave** or a **beam**. Each
  kind has a colour and the few numbers it needs, and a slash or a beam
  fires the way the part it sits in is turned. It becomes `fn vfx_Flames()`
  and runs on the same choices - including *only when something else calls
  it*, so a script can set it off with `vfx_Slash()`. A repeating effect
  has a beat: every 6 frames, say. Presets are small `.voltfx` files, so
  one can be imported, copied and shared between projects.

World Studio writes two functions to drive them, and the game file it makes
calls both:

```volt
worldStart()           // once, when the game starts
every frame {
  playerStep()
  worldStep()          // the scripts and effects in the world above
  render3d
}
```

Scripts and effects run in the finished game, not in the panel's **Play** -
Play is for walking the world and checking that it fits together.

A world is stored in the file as one `// world-studio: {...}` line inside
the markers - that's how the editor reads it back with everything it knows
(names, colours, what's hidden) intact. Even without that line, World
Studio can read a world out of plain `block3d` / `ball3d` / `cyl3d` /
`lamp3d` / `put3d` lines, which is how it opens a game someone wrote by
hand.

### Fighting, in World Studio

You do not have to write any of the above by hand. The Parts strip has
two more tiles, and every part has a health box:

| In the panel | What Save world writes |
|---|---|
| **Health** on any part (0 = scenery) | `let hp_Crate = target("Crate", x, y, z, hp, reach)` - it can be hurt, shows a bar once damaged, and bursts when it runs out |
| **Ability** | `fn ability_Fireball()` with its wait, its effect and its damage, plus `if held("e")` in `worldStep()` |
| **Item** | `give("Potion", 2, "#ff6b6b")`, and if it is lying in the world, a glowing ball you walk into to pick up |

The import, `stepCombat()` and the HUD are added for you as soon as
anything in the world fights. One line is yours to add, because it lives
in your half of the file: **`worldDraw()` straight after `render3d`** in
your `every frame` block. New game files get it already; World Studio
tells you if an older one is missing it.

An ability's **Set off by** picks the key. Keys 1-9 are also the backpack
slots, so an ability on `1` is what slot 1 does. **Nothing** means no key
is wired up and you call `ability_Fireball()` yourself from a Script.

## Fighting: import "combat.volt"

The other half of the game kit. `game.volt` walks the player around;
`combat.volt` lets things hurt each other, carries a backpack, and draws
the HUD that shows both. Import it after `game.volt`.

```volt
#html
canvas 320, 180
import "game.volt"
import "combat.volt"

let Goblin = block3d(0, 60, -400, 60, 120, 60, "#5d8a4a")
let g = target("Goblin", 0, 60, -400, 40, 90)    // 40 health, 90cm wide
give("Potion", 3, "#ff6b6b")
playerStart(0, 200, 0)

every frame {
  playerStep()
  stepCombat()                                   // cooldowns, flash, floating numbers
  if held("e") and ready("Zap") {
    startCooldown("Zap", 600)
    magic3d PLAYER_X, PLAYER_Y + 5, PLAYER_Z, 300, "#9d6bff", 700
    damageArea(PLAYER_X, PLAYER_Z, 400, 12)
  }
  render3d
  drawCombat()                                   // the HUD goes on top of the world
}
```

Call `stepCombat()` once a frame before `render3d`, and `drawCombat()`
after it.

### Things that can be hurt

| Command | What it does |
|---|---|
| `target(name, x, y, z, hp, reach)` | Says something can be hurt, and gives back its number. `reach` is how close a hit has to land, in cm |
| `alive(i)` | `true` while that one still has health |
| `hurtTarget(i, amount)` | Takes health off one. `true` if that killed it |
| `damageArea(x, z, reach, amount)` | Hurts everything within `reach` cm of a spot. Gives back how many it hit |
| `nearestTarget(x, z, reach)` | The closest living one, or -1 |
| `aliveCount()` | How many are still standing |
| `moveTarget(i, x, y, z)` | Keeps its spot in step with the block you are moving |

### The player

| Command | What it does |
|---|---|
| `hurtPlayer(amount)` | Takes health off, flashes the screen, and kills them at 0 |
| `healPlayer(amount)` | Gives health back, never past `PLAYER_MAX_HP` |
| `revivePlayer()` | Full health, back on their feet |
| `PLAYER_HP` `PLAYER_MAX_HP` | Read them for your own HUD |
| `PLAYER_DEAD` | `true` while they are down |

### Abilities

| Command | What it does |
|---|---|
| `ready(name)` | `true` when that ability can be used again |
| `startCooldown(name, ms)` | Starts the wait. Call it right after using the ability |
| `coolPercent(name, ms)` | 0 to 100, for drawing a dial |

### The backpack

Slots along the bottom of the screen; number keys 1-9 pick one.

| Command | What it does |
|---|---|
| `give(name, count, "#colour")` | Puts something in. The same name stacks up |
| `takeOne(name)` | Uses one. `false` if there was none |
| `countOf(name)` | How many you have |
| `holding()` | The name in the picked slot, `""` if the bag is empty |
| `pickSlot(n)` | Picks a slot, counting from 0 |

### Numbers that float

| Command | What it does |
|---|---|
| `damageNumber(x, y, z, amount, "#colour")` | A number that pops up there and drifts away. Hits do this for you |
| `floatText(x, y, z, "Miss", "#colour")` | The same, with words |

### Settings

Change any of these from your own file, after the import.

| Setting | Default | What it does |
|---|---|---|
| `PLAYER_MAX_HP` | 100 | How much health the player has |
| `RESPAWN_MS` | 2000 | How long they lie dead. 0 keeps them down |
| `HURT_FLASH_MS` | 260 | How long the screen flashes red |
| `HUD_W` `HUD_H` | 320, 180 | The size you gave `canvas` |
| `HUD_COLOR` | `"#ffd23f"` | The colour of the picked backpack slot |
| `SHOW_HEALTH_BAR` | true | The player's bar, bottom left |
| `SHOW_HOTBAR` | true | The backpack slots |
| `SHOW_DAMAGE_NUMBERS` | true | Numbers over a hit |
| `SHOW_ENEMY_BARS` | true | A small bar over a hurt enemy |
| `DEATH_SPARKS` | true | A burst of sparks where something dies |

### How the backpack bar looks

The bar along the bottom draws itself. These say what it looks like, and
World Studio writes them for you when you put a Backpack bar in StarterGui.

| Setting | Default | What it does |
|---|---|---|
| `HOTBAR_STYLE` | `"plain"` | `plain` dark rounded squares, `gold` ornate frames, `round` circles, `hex` six-sided, `slim` no boxes at all |
| `HOTBAR_SIZE` | 22 | How big one slot is |
| `HOTBAR_GAP` | 3 | The space left between slots |
| `HOTBAR_SLOTS` | 0 | How many slots to draw. 0 means one per thing you carry |
| `HOTBAR_ROWS` | 1 | 2 or 3 stacks them up, the way Divinity does |
| `HOTBAR_NUMBERS` | true | The 1-9 then 0 keys in the corner of each slot |
| `HOTBAR_COUNTS` | true | How many of that thing you have |
| `HOTBAR_NAME` | true | The name of what you are holding, above the bar |
| `HOTBAR_WHERE` | `"bottom"` | `bottom`, `top`, `left`, `right` or `middle` |
| `HOTBAR_X` `HOTBAR_Y` | -1 | Put it exactly here instead. -1 means work it out from `HOTBAR_WHERE` |
| `HOTBAR_BACK` | `"#0b0f16cc"` | The colour inside an empty slot |
| `HOTBAR_RIM` | `"#2a3142"` | The line around a slot |
| `HOTBAR_PICKED` | `"#ffd23f"` | The line around the slot you are holding |

### StarterGui, StarterPack and StarterPlayer

World Studio's Things list keeps three containers under the world, the
same three Roblox has:

| Container | What goes in it |
|---|---|
| **StarterGui** | HUD pieces - bars, words, panels, pictures, the backpack slots |
| **StarterPack** | Items and Abilities: what the player starts able to carry and do |
| **StarterPlayer** | Health, how long they take to get back up, walk and run speed, jump power |

A **HUD** piece hangs off a corner of the screen rather than sitting at a
fixed spot, so it stays put whatever size the window is. Pick the corner,
then how far across and down from it.

| HUD piece | What it draws |
|---|---|
| Bar that fills up | A bar tied to health, how ready an ability is, or how many of an item you have |
| Words | Text, in any font, tied to a number or just typed |
| Panel behind things | A see-through rectangle |
| Picture | A `.png` kept beside your `.volt` file |
| Backpack slots | The row of slots, moved where you want it |

Drawing your own health bar or backpack turns the kit's own version off,
so they never double up. Only the StarterPlayer numbers you actually
change get written out.

## Game types (structs)

`#html` games can declare a named shape for the things in a game - a player, an enemy, a pickup - instead of juggling a separate list for every field (`ex`, `ey`, `ehp`, `emaxhp`, ...).

```volt
#html
canvas 320, 180

Player = type { name: string, health: int, speed: float }

let hero = Player { name: "Finn", health: 10, speed: 2 }
let enemies = []
add Player { name: "Slime", health: 4 } to enemies   // speed left out -> 0

hero.health -= 3
enemies[0].health -= 2

every frame {
  paint "#14111a"
  write hero.name + " - " + text(hero.health) + " hp" at 10, 10
}
```

| Command | What it does |
|---|---|
| `Name = type { field: kind, field: kind }` | Declares a type. Top level only. `kind` is a label like `string`, `int`, `float` or `bool` - Volt doesn't enforce it, but an untouched field in a struct value defaults to `""` for `string`/`text`, `false` for `bool`, and `0` for everything else |
| `Name { field: value, field: value }` | Makes a value of that type. Any field you leave out gets its default |
| `thing.field` | Reads a field |
| `thing.field = value` (also `+=`, `-=`, `*=`, `/=`) | Changes a field. Works through a list index too: `enemies[i].health -= 1` |

Things to know:

- Struct types only work in `#html` right now.
- A type must be declared somewhere in the file before you use it, but not necessarily above the line that uses it - Volt looks for every `Name = type { ... }` first.
- There's no nesting (a field can't hold another struct) and no deep assignment (`thing.field.other = ...` isn't supported) - keep structs flat, one level of fields.
- A list can hold values of a struct type just like any other value: `let enemies = []`, `add Player { ... } to enemies`, `enemies[i].health`.

## How a Volt program runs

There is one simple rule:

> Anything **outside** a `forever`, `every` or `when` block runs **once** when the board starts. Everything **inside** those blocks keeps running.

```volt
pin led = 13
print "Starting!"          // runs once

every 1s {                 // runs every second, forever
  toggle led
}
```

In C++, the "once" code goes into `setup()` and the repeating code into `loop()`. In Python and Ruby, the "once" code runs at the top of the file and the repeating code goes inside a loop that never ends. In JavaScript and web pages, the same happens inside an `async` main function.

A script with no `forever`, `every` or `when` simply ends when it reaches the last line.

## Comments

`//` starts a comment. Volt ignores everything after it on that line.

```volt
// This whole line is a comment
pin led = 13   // so is this part
```

## Pins

Every pin you use needs a name. Declare pins at the top level (not inside `{ }`):

```volt
pin led = 13            // output (the default)
pin button = 2 input    // a button
pin knob = A0 analog    // a sensor that gives a range of values
pin glow = 9 pwm        // an LED you can dim
pin arm = 6 servo       // a servo motor
pin motor = 8, 9, 10, 11 stepper   // a stepper motor (4 pins)
```

| Mode | Use it for | Can do | `read` gives |
|---|---|---|---|
| `output` *(default)* | LEDs, buzzers, relays | `on`, `off`, `toggle`, `set`, `tone` | 1 if on, 0 if off |
| `input` | Buttons and switches | `when … pressed`, `read` | 1 if pressed, 0 if not |
| `analog` | Knobs, light sensors, temperature sensors | `read` | 0 to 1023 |
| `pwm` | Dimming LEDs, motor speed | `on`, `off`, `toggle`, `set`, `fade` | brightness 0 to 100 |
| `servo` | Servo motors | `set` | angle 0 to 180 |
| `stepper` | Stepper motors (4 pins) | `turn`, `step`, `set`, `set … speed`, `off` | angle 0 to 359 |

**Wiring buttons:** Volt turns on the board's built-in pull-up resistor, so just connect the button between the pin and **GND**. No extra resistor needed.

**PWM pins:** on an Arduino Uno these are the pins marked `~`: 3, 5, 6, 9, 10, 11.

**Pin numbers:** `A0`–`A7` work in `#c++` only. On ESP32 and Pico boards, use the GPIO number (for example `pin knob = 34 analog` on ESP32, `pin knob = 26 analog` on Pico).

How pins translate:

| Volt | C++ | Python |
|---|---|---|
| `pin led = 13` | `const int led = 13;` + `pinMode(led, OUTPUT)` | `led = Pin(13, Pin.OUT)` |
| `pin b = 2 input` | `pinMode(b, INPUT_PULLUP)` | `Pin(2, Pin.IN, Pin.PULL_UP)` |
| `pin k = A0 analog` | `const int k = A0;` | use a GPIO number: `pin k = 26 analog` → `ADC(Pin(26))` |
| `pin g = 9 pwm` | `pinMode(g, OUTPUT)` | `PWM(Pin(9), freq=1000)` |
| `pin s = 6 servo` | `Servo` object + `attach(6)` | `PWM(Pin(6), freq=50)` |
| `pin m = 8, 9, 10, 11 stepper` | 4 outputs + built-in stepper driver | 4 `Pin(…, Pin.OUT)` + built-in stepper driver |

## Controlling pins

### on, off, toggle

```volt
on led        // turn on
off led       // turn off
toggle led    // flip: on becomes off, off becomes on
```

These work on `output` and `pwm` pins. On a `pwm` pin, `on` means 100% brightness.

### set … to

`set` gives a pin a value. What the value means depends on the pin:

```volt
set glow to 50        // pwm: 50% brightness (0-100)
set arm to 90         // servo: 90 degrees (0-180)
set led to 1          // output: on if the value isn't 0
```

Values outside the range are clamped, so `set glow to 150` becomes 100.

### Stepper motors

A stepper motor turns in tiny exact steps, so it can spin all the way round as many times as you like and stop at an exact angle. Volt supports the **28BYJ-48** motor with its **ULN2003** driver board, which comes in most Arduino kits.

**Wiring:** plug the motor's 5-wire plug into the driver board. Then board **IN1, IN2, IN3, IN4** → four Arduino pins, board **+** → **5V**, board **−** → **GND**.

```volt
#c++
pin motor = 8, 9, 10, 11 stepper     // IN1, IN2, IN3, IN4

set motor speed to 12     // turns per minute (1 to 15)
turn motor 90             // turn 90 degrees
turn motor -90            // turn back the other way
set motor to 180          // go to an exact angle, the short way round
step motor 512            // move by steps (2048 steps = one full turn)
print read motor          // its angle now, 0 to 359
off motor                 // switch the coils off
```

| Command | What it does |
|---|---|
| `turn motor 90` | Turns by an angle in degrees. Negative turns the other way. `turn motor 720` spins twice |
| `set motor to 180` | Goes to an exact angle, whichever way is shorter. 0 is where the motor was when the program started |
| `step motor 512` | Moves by steps. 2048 steps is one full turn, so 512 is a quarter turn |
| `set motor speed to 12` | Speed in turns per minute, 1 to 15. The 28BYJ-48 can't go faster than about 15 |
| `off motor` | Switches the coils off. Use it when the motor is resting, or it stays warm and wastes power |
| `read motor` | The current angle, 0 to 359 |

The motor finishes moving before the next line runs. If it turns the wrong way for you, swap the signs (`90` ↔ `-90`), or swap the middle two pins.

> **Power:** the ULN2003 board can take its 5V from the Arduino for one motor. For two motors, or if the Arduino resets while the motor moves, power the driver board from a separate 5V supply, with its GND joined to the Arduino's GND.

### fade … to … over

Smoothly changes a `pwm` pin's brightness over a time:

```volt
fade glow to 100 over 2s     // fade up over 2 seconds
fade glow to 0 over 500ms    // fade down over half a second
```

`fade` waits until the fade is finished before moving on.

### tone … for

Plays a note on a buzzer (an `output` pin). The number is the pitch in hertz:

```volt
tone buzzer 440 for 200ms    // the note A for 0.2 seconds
tone buzzer 262 for 1s       // middle C for 1 second
```

`tone` waits until the note is finished. Use a **passive** buzzer to hear different pitches.

## Reading pins

`read` gets a pin's current value and can be used anywhere a number goes:

```volt
let light = read sensor            // analog: 0-1023
if read button {                   // input: 1 when pressed
  on led
}
print "Angle: " + read arm         // servo: last angle set
```

## Variables and math

### let and =

`let` makes a new variable. `=` changes it later.

```volt
let score = 0
score = score + 10
```

### Shortcuts: += -= *= /=

These change a variable using its own value:

| Shortcut | Same as |
|---|---|
| `score += 1` | `score = score + 1` |
| `lives -= 1` | `lives = lives - 1` |
| `size *= 2` | `size = size * 2` |
| `size /= 2` | `size = size / 2` |

`+=` also adds to text: `word += "!"`.

A `let` at the top level is visible everywhere. A `let` inside `{ }` only exists inside those braces.

### Numbers

Volt numbers are usually **whole numbers** - dividing rounds down: `7 / 2` is `3`.

Decimals (`2.5`, `0.1`) work in `#python`, `#ruby`, `#js` and `#html`, and change that rule only where they're actually used: dividing is real division as soon as a decimal is involved (`7 / 2.0` is `3.5`), while plain whole numbers still divide the old way (`7 / 2` stays `3`) - so existing programs don't change behavior.

```volt
let price = 19.99
let half = price / 2
print text(half)   // 9.995
```

- **Boards don't support decimals yet.** `#c++` and `#micropython` still only take whole numbers (decimals are allowed in times like `1.5s`, same as before) - using one elsewhere in a board program is an error.
- A struct field declared `float` (`Player = type { speed: float }`) always divides as a decimal, even when its value happens to be whole.
- One JavaScript quirk: `#js`/`#html` can't tell `5.0` apart from `5` once it's passed into a function (JavaScript has no separate decimal type at that point), so dividing a whole-valued decimal that arrived through a function parameter may round down instead of staying a decimal. A decimal with an actual fraction (`2.5`), or one read straight from a variable or struct field, always works correctly.

### Operators

| Operator | Meaning | Example |
|---|---|---|
| `+` `-` `*` `/` | add, subtract, multiply, divide | `(a + b) * 2` |
| `%` | remainder | `presses % 5` is 0 every 5th press |
| `==` `!=` | equal, not equal | `if mode == 2 { }` |
| `<` `>` `<=` `>=` | comparisons | `if temp > 30 { }` |
| `and` `or` `not` | combine conditions | `if a > 5 and not (read button) { }` |
| `true` `false` | 1 and 0 | `let ready = false` |

Multiplication and division happen before addition and subtraction, like in maths. Use brackets `( )` to change the order.

## Text and print

`print` sends a message to the **Serial monitor**:

```volt
print "Hello!"
print 42
print "Score: " + score
print "Pressed " + count + " times"
```

Join text and numbers with `+`. Text goes in double quotes and must fit on one line. Variables can hold numbers or text (see [Text variables](#text-variables)).

Where `print` goes depends on the language: the Serial monitor for boards, the **Console** for scripts, and the page itself for `#html`.

In C++, Volt adds `Serial.begin(9600)` for you, so set the Serial monitor to **9600**. MicroPython boards use **115200**.

## Times and waiting

Times are written with `ms` (milliseconds) or `s` (seconds): `500ms`, `2s`, `1.5s`. 1000ms = 1s.

```volt
wait 200ms
wait 2s
```

To wait for an amount stored in a variable, put the unit after it:

```volt
let gap = 300
wait gap ms
wait gap * 2 ms
```

`uptime` is how many milliseconds have passed since the board started:

```volt
print "Running for " + uptime / 1000 + " seconds"
```

> `wait` pauses everything. While a `wait` is running, `every` and `when` blocks can't run. For things that should happen at the same time, use several `every` blocks instead of `wait`.

## Decisions: if and else

```volt
if temp > 30 {
  on fan
} else if temp > 25 {
  set fan to 50
} else {
  off fan
}
```

`else if` and `else` are optional. The condition can use comparisons, `and`, `or`, `not`, and `read`.

## Loops: repeat, while, break

### repeat

Runs a block a set number of times:

```volt
repeat 3 {
  on led
  wait 100ms
  off led
  wait 100ms
}
```

The number can be a variable: `repeat count { }`.

### while

Keeps running while a condition is true:

```volt
let n = 0
while n < 10 {
  n = n + 1
}

while read button {      // wait until the button is let go
  wait 10ms
}
```

### for … from … to

Counts with a variable. The counter goes up by 1 each time, and both ends are included:

```volt
for i from 1 to 5 {
  print "Number " + i
}
```

If the first number is bigger, it counts down: `for i from 10 to 1 { }`. The ends can be variables or sums: `for i from 1 to count * 2 { }`. The counter only exists inside the braces.

### break

Stops the nearest `repeat` or `while` early:

```volt
repeat 100 {
  if read button {
    break
  }
  wait 50ms
}
```

## Running things over time

These three blocks must be at the top level. They all run side by side, in the order they're written.

### every

Runs a block on a timer:

```volt
every 1s {
  toggle led
}

every 100ms {
  set glow to read knob / 10
}
```

`every` doesn't use `wait`. It checks the board's clock, so several `every` blocks can run at different speeds at the same time.

### when … pressed

Runs a block once each time a button is pressed:

```volt
when button pressed {
  count = count + 1
}
```

Volt **debounces** the button (ignores the tiny flickers a real button makes for a few milliseconds), so one press counts as one press.

### forever

Runs a block over and over, as fast as possible:

```volt
forever {
  if read sensor > 600 {
    on led
  } else {
    off led
  }
}
```

## Functions

`fn` makes a reusable block of code with a name. Functions must be at the top level.

```volt
fn blink(times) {
  repeat times {
    on led
    wait 150ms
    off led
    wait 150ms
  }
}

fn average(a, b) {
  return (a + b) / 2
}

blink(3)
print "Average: " + average(10, 20)
```

- Values in the brackets are **parameters**. Pass values in when calling: `blink(3)`.
- In scripts and pages, parameters can be numbers or text. In `#c++`, functions only take and return numbers.
- `return` sends a value back and ends the function. A function without `return` gives 0.
- Functions can use top-level variables and pins, and can call other functions (even ones written further down).

## Reusing code: import

`import "name.volt"` pastes another `.volt` file's contents in, right where the `import` line is - so a set of functions or types you've written once (or a [library plugin](using-volt-studio)'s snippet file) can be reused from more than one program, instead of copy-pasted by hand into each one.

```volt
// mathlib.volt
fn square(x) {
  return x * x
}
```

```volt
// main.volt
#js
import "mathlib.volt"

print "5 squared is " + square(5)
```

- `import "..."` must be its own line, written exactly like that (a literal file name in quotes - no variables). A `// comment` after it is fine.
- The file is found the same way a `draw`/`image`/`audio` file is: in the same folder as the importing `.volt` file - and then in every library plugin's folder, so a kit a plugin ships (like the game kit's `game.volt`) can be imported without copying it anywhere. Your own folder always wins, so a local copy of the same name replaces the plugin's.
- Importing the same file more than once (directly, or through two other imports) is fine - the repeat is skipped, so two files that both import a shared library don't collide.
- An imported file should be plain code (functions, types, raw `#`/`##` lines) with no `#target` line of its own - like a library plugin's snippet, it's meant to be pasted into a program that already picked its target.
- Error messages after an import point at the merged program, so a mistake inside an imported file may report a line number that doesn't match that file directly - if a message looks off by a few lines, check the imported file too.

## Built-in functions

| Function | What it does | Example |
|---|---|---|
| `random(low, high)` | Random whole number from low to high (both included) | `random(1, 6)` → a dice roll |
| `map(x, inLow, inHigh, outLow, outHigh)` | Converts a number from one range to another | `map(read knob, 0, 1023, 0, 180)` |
| `constrain(x, low, high)` | Keeps a number inside a range | `constrain(speed, 0, 100)` |
| `min(a, b)` | The smaller one | `min(score, 99)` |
| `max(a, b)` | The bigger one | `max(best, score)` |
| `abs(x)` | Removes the minus sign | `abs(-5)` → 5 |
| `number(x)` | Text to a whole number | `number("42")` → 42 |
| `text(x)` | A number to text | `text(5)` → "5" |
| `length(x)` | Number of characters | `length("hi")` → 2 |
| `upper(x)` / `lower(x)` | Capitals / small letters | `lower("HI")` → "hi" |
| `contains(x, part)` | Is `part` inside `x`? | `contains("hello", "ell")` → true |
| `dist(x1, y1, x2, y2)` | Straight-line distance between two points, rounded down | `dist(hero.x, hero.y, goblin.x, goblin.y)` |
| `lerp(from, to, percent)` | The point `percent`% of the way from `from` to `to` | `lerp(0, 100, 25)` → 25 |
| `overlaps(ax, ay, aw, ah, bx, by, bw, bh)` | Do two boxes (position + size) touch? | `overlaps(hero.x, hero.y, 10, 8, e.x, e.y, e.w, e.h)` |
| `sqrt(x)` | Square root, rounded down | `sqrt(16)` → 4 |
| `pow(base, exponent)` | `base` to the power of `exponent`, rounded down | `pow(2, 5)` → 32 |
| `join(list, separator)` | Glues a list's items into one piece of text | `join(["a", "b", "c"], ", ")` → "a, b, c" |
| `split(text, separator)` | Breaks text into a list wherever `separator` appears | `split("a,b,c", ",")` → a 3-item list |
| `sin(degrees)` | Sine of an angle given in degrees (a decimal from -1 to 1) | `sin(90)` → 1 |
| `cos(degrees)` | Cosine of an angle given in degrees (a decimal from -1 to 1) | `cos(0)` → 1 |

`join` and `split` work in `#python`, `#ruby`, `#js` and `#html` (lists aren't supported on boards yet).

`sin` and `cos` always return a decimal, so they need decimal support and don't work on boards (`#c++`, `#micropython`) yet. They're handy for turning an angle (like a character's facing direction) into a movement vector: `moveX = cos(angle)`, `moveY = sin(angle)`.

### Node and the web

These four are for backend/data work rather than games or boards:

| Function | What it does | Example |
|---|---|---|
| `readFile(path)` | A file's contents as text (`#js` run with Node) | `readFile("data.txt")` |
| `writeFile(path, text)` | Saves text to a file, `true` if it worked (`#js` run with Node) | `writeFile("out.txt", report)` |
| `envVar(name)` | An environment variable's value, or `""` if it isn't set (`#js` run with Node) | `envVar("API_KEY")` |
| `fetchText(url)` | Downloads a URL and returns its text (`#js` and `#html`) | `fetchText("https://example.com/data.json")` |

`readFile`, `writeFile` and `envVar` only work when a `#js` program is actually run with Node (`node program.js`) - a web browser has no filesystem or environment variables, so they don't work in `#html` pages. `fetchText` works in both, since both Node and browsers can fetch a URL.

## Raw code

When Volt doesn't have a feature yet, you can write lines in the output language directly. Volt copies them into the output without changing them.

| You write | Where it goes |
|---|---|
| `# code` | Right where you wrote it, in the output language |
| `## code` | The top of the output file (for global variables and objects). In `#html`, `##` lines are **CSS** |
| `#include <Name.h>` | The top of the output file (`#c++` only; also `#define`) |

```volt
#c++
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
## LiquidCrystal_I2C lcd(0x27, 16, 2);

let seconds = 0
# lcd.init();
# lcd.backlight();

every 1s {
  seconds = seconds + 1
  # lcd.setCursor(0, 0);
  # lcd.print(seconds);
}
```

- Raw lines can use Volt variables and pins by name.
- Raw lines are written in the output language: Python in `#python`, Ruby in `#ruby`, JavaScript in `#js` and `#html`. So `# exit` in a Ruby program is Ruby code, not a comment. (Volt comments are always `//`.)
- Volt doesn't check raw code. Mistakes in it show up as errors from the Arduino compiler or MicroPython instead.

## C++ vs Python differences

These are the differences between the two **board** languages:

| Thing | `#c++` | `#micropython` |
|---|---|---|
| Output file | `name/name.ino` | `name/main.py` (runs when the board starts) |
| Serial speed | 9600 | 115200 |
| Analog pin names | `A0`–`A7` or numbers | GPIO numbers only |
| `read` on analog pins | 0–1023 | 0–1023 (Volt scales it for you) |
| `#include` | ✓ | ✗ |
| `ask` | ✗ | ✓ (type in the Serial monitor) |
| Raw code | C++ | Python |

## Names you can't use

Names must start with a letter and can contain letters, numbers and `_`. They can't start with `_`, and they can't be:

- **Volt keywords:** `pin input output analog pwm servo stepper step turn read pressed on off toggle set to fade over tone for let print show clear stop ask uptime if else repeat while break wait forever every when fn return true false and or not`
- **Built-ins:** `random abs min max constrain map number text length upper lower contains`
- **Words one of Volt's languages already uses**, such as `int`, `long`, `double`, `delay`, `setup`, `loop`, `time`, `range`, `str`, `def`, `class`, `import`, `end`, `nil`, `puts`, `var`, `function`, `null`, `document`, `console`.
- In `#ruby`, names must start with a **lowercase** letter.

`button`, `title` and `html` are fine as names (like `pin button = 2 input`). They only act as page commands at the start of a line in `#html`.

Volt tells you if you use one, so you don't need to memorise the list.

## Using Volt Studio

| Part | What it does |
|---|---|
| **Language** list | Changes the first line of your file (`#c++`, `#python`, `#html` …) |
| **New** button | Pick what to make: a board program, a script or a web page |
| **Board** list | Which board you have (C++ only). Picked automatically for genuine Arduinos |
| **Port** list | Which USB port your board is on (boards only). Updates when you plug a board in |
| **Compile** | Checks your code and saves the output file next to your `.volt` file |
| **Upload** | For boards: compiles and sends the program to your board |
| **Run** / **Stop** | For scripts: runs the program; output appears in the Console |
| **Preview** | For `#html`: shows the page in a preview window (Sketch → Open Page in Browser opens it in your normal browser) |
| **Output code** tab | Shows the C++ or Python as you type |
| **Serial monitor** tab | Shows `print` messages; you can also send text to the board |

Errors appear as a red line in the editor with the message underneath. Click the error in the status bar to jump to it.

**Uploading C++** needs the **Arduino IDE 2** installed. Volt Studio uses the `arduino-cli` tool that comes inside it. For ESP32 or other non-Arduino boards, install board support once with **Tools → Install Board Support for Selected Board**.

**Running scripts:** `#js` runs straight away. `#python` needs Python from python.org (tick *Add python.exe to PATH* when installing), and `#ruby` needs Ruby from rubyinstaller.org. **Tools → Upload Setup Check** shows what's installed. When a script uses `ask`, type your answer in the box at the bottom of the Console.

**Uploading MicroPython** needs **MicroPython** installed on the board once. The easiest way is Thonny: *Tools → Options → Interpreter → Install or update MicroPython*. After that, Volt Studio sends `main.py` straight to the board.

### Keyboard shortcuts

| Keys | Action |
|---|---|
| Ctrl+N / Ctrl+O / Ctrl+S | New, open, save |
| Ctrl+Shift+S | Save as |
| Ctrl+R | Compile |
| Ctrl+U | Upload / Run / Preview |
| F5 / Shift+F5 | Run / Stop |
| Ctrl+Shift+M | Serial monitor |
| Tab | Accept the faded suggestion after the cursor (e.g. `fade g` → `fade glow`) |
| Ctrl+Space | Autocomplete (keywords, your names, snippets) |
| Ctrl+/ | Comment or uncomment lines |
| Ctrl+F | Find |
| Ctrl+= / Ctrl+- | Bigger / smaller text |
| F1 | This reference |

## Using the command line

The compiler also works without the app:

```
node volt.js myprogram.volt
```

It writes the output file (`myprogram/myprogram.ino`, `.py`, `.rb`, `.js`, or `myprogram/index.html`) and prints any errors with their line number.

## Cheat sheet

```volt
#c++     // or #micropython #python #ruby #js #html
// comment

pin led = 13                 // output
pin button = 2 input         // button to GND
pin knob = A0 analog         // 0-1023
pin glow = 9 pwm             // 0-100%
pin arm = 6 servo            // 0-180 degrees
pin motor = 8, 9, 10, 11 stepper   // turn, step, set, speed

let x = 0                    // new variable
x = x + 1                    // change it
x += 1                       // same thing (-= *= /= too)
print "x is " + x            // to the serial monitor

on led / off led / toggle led
set glow to 50               // pwm %, servo angle, stepper angle
turn motor 90                // stepper: turn by degrees
step motor 512               // stepper: 2048 steps = 1 turn
set motor speed to 12        // stepper: turns per minute
fade glow to 0 over 1s
tone led 440 for 200ms
wait 500ms                   // or: wait x ms
read knob                    // a pin's value
uptime                       // ms since start

if x > 5 { } else if x > 2 { } else { }
repeat 3 { }
for i from 1 to 10 { }       // counting loop (10 to 1 counts down)
while x < 10 { }
break

every 1s { }                 // on a timer
when button pressed { }      // once per press
forever { }                  // nonstop

fn name(a, b) { return a + b }
name(1, 2)

let word = "text"            // text variables
let answer = ask "Question?" // scripts and pages (input works too)
show "Score: " + x           // updates in place on a page
clear                        // wipe printed text
stop                         // end the program
number("5")  text(5)  length(word)
upper(word)  lower(word)  contains(word, "ex")

title "Page"                 // #html only
button "Click" { }
when key "k" pressed { }
html "<b>markup</b>"
## body { color: white; }    // CSS in #html

let xs = [1, 2]              // lists (not on boards)
add 3 to xs   xs[0] = 5   remove xs[1]
for each v in xs { }
part(word, 0, 3)  sign(x)

canvas 320, 180              // games (#html)
image tiles = "tiles.png"
sprite hero = tiles at 0, 0 size 16, 16 frames 4
every frame { }
paint "#000"
draw hero at x, y frame f flipped
draw spark at x, y tint "#ffd23f" glow scale 150 alpha 60
box x, y, 10, 10 color "#f00"
write "Hi" at 10, 10 size 2 centered shadow
camera x, y
held("left")
touchscreen()
tone 880 to 220 for 100ms
touchpad "x", "z"
music "c5 e5 g5 _", "c3 - g2 -" tempo 150
music off
save "best", score   saved("best", 0)
audio hit = "hit1.mp3", "hit2.mp3"
sound hit volume 60
volume 0

random(1, 6)  map(x, 0, 1023, 0, 100)  constrain(x, 0, 100)
min(a, b)  max(a, b)  abs(x)

# raw code line              ## raw code at the top
#include <Library.h>
```
