# Volt 3D

The 3D side of Volt. Everything here works in `#html` programs: Volt packs a 3D engine into the
page, so the finished `index.html` runs anywhere on its own.

A 3D program is a 2D game with a world behind it. The `canvas` you make is drawn **on top** of
the 3D view, so it is your HUD: health bars, score, crosshair.

```volt
#html
canvas 320, 180
world3d "#0a0d14" fog 2600 ambient 9 shadows

block3d(0, -10, 0, 2000, 20, 2000, "#5c6470")
freeze3d
player3d 0, 0, 400

every frame {
  walk3d
  render3d
  write "Hello" at 6, 6 shadow
}
```

---

## Contents

1. [Sizes and angles](#sizes-and-angles)
1. [The world](#the-world)
1. [Making things](#making-things)
1. [Changing things](#changing-things)
1. [The player](#the-player)
1. [Bumping into things](#bumping-into-things)
1. [Looking at things](#looking-at-things)
1. [Models](#models)
1. [Light and looks](#light-and-looks)
1. [Sound in 3D](#sound-in-3d)
1. [The HUD](#the-hud)
1. [Making it fast](#making-it-fast)
1. [Every 3D word](#every-3d-word)

---

## Sizes and angles

- **1 unit is 1 cm.** A 2 m wide corridor is `200`. A person is about `170` tall.
- **Angles are in tenths of a degree.** A quarter turn is `900`, all the way round is `3600`.
- `y` is up. Yaw `0` looks towards `-z`; turning right makes the yaw bigger.
- Decimals are fine everywhere.

The oldest 3D helpers - `sin3`, `cos3` and `atan2` - work in tenths of a degree and give back
thousandths, so `sin3(900)` is `1000`. You only need them if you are moving things yourself;
`player3d` and `walk3d` do that work for you.

## The world

```volt
#html
canvas 320, 180
world3d "#05060a" fog 1400 ambient 8 fov 75 shadows
every frame { render3d }
```

`world3d colour` makes the world. Everything after the colour can be left out:

| Option | What it does |
|---|---|
| `fog 1400` | How far you can see before the fog closes in, in cm. |
| `ambient 8` | A dim light on everything, 0 to 100, so shadows aren't pure black. |
| `fov 75` | How wide the view is. Smaller looks zoomed in. |
| `shadows` | Things cast shadows. Costs some speed. |

Other world-level words:

- `clear3d` - empties the world. Use it between levels.
- `render3d` - draws one frame. Put it near the end of `every frame`.
- `far3d 12000` - how far the camera can see, in cm. Things past it are not drawn.
- `sky3d(level)` - the time of day, `0` for night to `100` for bright noon. Changes the sky, the
  fog and the sun together.
- `look3d flat, "#9cc4e0"` - `flat 1` drops the gritty surface texture for flat colours.

## Making things

Each of these gives you back a number. Keep it in a `let` - it is how you refer to that thing later.

```volt
#html
canvas 320, 180
world3d "#05060a" ambient 20

let floor = block3d(0, -10, 0, 2000, 20, 2000, "#5c6470")
let crate = block3d(0, 40, -200, 80, 80, 80, "#b07a3c")
let orb = ball3d(0, 120, -200, 25, "#4de1ff")
let pillar = cyl3d(-300, 150, -200, 35, 300, "#8a8f99")
let lamp = lamp3d(0, 300, 0, "#ffcc88", 50, 1200)

every frame { render3d }
```

| Word | What it makes |
|---|---|
| `block3d(x, y, z, width, height, depth, colour)` | A box, middled on x, y, z. |
| `ball3d(x, y, z, radius, colour)` | A sphere. |
| `cyl3d(x, y, z, radius, height, colour)` | A cylinder. |
| `lamp3d(x, y, z, colour, power, range)` | A light shining in every direction. Power 0-100, range in cm. |
| `put3d(model, x, y, z, yaw, scale)` | A loaded `.glb` model. Scale is a percent. |

## Changing things

```volt
#html
canvas 320, 180
world3d "#05060a" ambient 20
let crate = block3d(0, 40, 0, 80, 80, 80, "#b07a3c")
let hat = block3d(0, 100, 0, 40, 20, 40, "#4de1ff")
let spin = 0

attach3d hat, crate

every frame {
  spin += 20
  turn3d crate, spin
  move3d crate, sin3(spin) / 10, 40, 0
  render3d
}
```

| Word | What it does |
|---|---|
| `move3d thing, x, y, z` | Puts it somewhere else. |
| `turn3d thing, yaw` | Spins it on the spot. |
| `tilt3d thing, pitch, roll` | Leans it forwards and sideways. |
| `scale3d thing, x, y, z` | Stretches it, as a percent of the size it was made. |
| `color3d thing, "#ff4d6d"` | Changes its colour. |
| `glow3d thing, "#4de1ff"` | Makes it light up by itself. |
| `shine3d thing, rough, metal` | How shiny it is. `rough 0` is a mirror, `100` is chalk. |
| `show3d thing, false` | Hides it without removing it. |
| `remove3d thing` | Takes it out of the world for good. Anything attached goes too. |
| `attach3d child, parent` | Glues one thing to another, so it moves with it. `attach3d child, -1` lets go. |

## The player

You do not have to write a walking controller. Two words do it:

```volt
#html
canvas 320, 180
world3d "#0a0d14" fog 2600 ambient 9 shadows
block3d(0, -10, 0, 2000, 20, 2000, "#5c6470")
block3d(0, 150, -600, 1600, 300, 20, "#737a86")
freeze3d

player3d 0, 0, 400 speed 420 jump 430 height 170

every frame {
  walk3d
  render3d
  write "x {round(playerx())}  z {round(playerz())}" at 6, 6 shadow
}
```

`player3d x, y, z` puts the player's feet at that spot. `speed`, `jump` and `height` can all be
left out. Call it again at any time to move the player somewhere else - at the start of a new
level, say.

`walk3d`, once per frame, does all of this:

- **WASD** or the **arrow keys** to walk, and the left stick on a gamepad.
- The **mouse** to look (click the page once to capture it), or the right stick.
- **Space** to jump, **Shift** to run.
- Gravity, falling and landing.
- Walls: you slide along them instead of sticking.
- Steps up to 32 cm high are climbed without jumping.

Where the player is:

| Word | Gives you |
|---|---|
| `playerx()` `playery()` `playerz()` | Where they are. `playery()` is their feet. |
| `playeryaw()` `playerpitch()` | Which way they are looking, in tenths of a degree. |
| `onground()` | True while they are standing on something. |

If you would rather drive the camera yourself, `camera3d x, y, z, yaw, pitch` still works exactly
as it always did, and `mousedx()`, `mousedy()` and `locked3d()` are still there.

## Bumping into things

Blocks, balls and cylinders are solid. Lamps never are. Models are not, until you say so.

```volt
#html
canvas 320, 180
world3d "#000" ambient 20
let ghost = block3d(0, 60, -200, 80, 120, 80, "#88aaff")
let hero = block3d(0, 60, 0, 40, 120, 40, "#ffd23f")
solid3d ghost, false

every frame {
  if touching3d(hero, ghost) {
    write "spooky" at 160, 20 centered shadow
  }
  render3d
}
```

- `solid3d thing, false` - walk straight through it. `solid3d model, true` makes a model solid.
- `touching3d(a, b)` - true when two things overlap.
- `dist3d(x1, y1, z1, x2, y2, z2)` - the straight-line distance between two points.

## Looking at things

```volt
#html
canvas 320, 180
world3d "#000" ambient 20
block3d(0, -10, 0, 2000, 20, 2000, "#666")
let crate = block3d(0, 40, -300, 80, 80, 80, "#b07a3c")
player3d 0, 0, 0

every frame {
  walk3d
  let target = aim3d(400)
  if target == crate {
    write "press click to take" at 160, 150 centered shadow
    if clicked() {
      burst3d hitx(), hity(), hitz(), "#ffd23f", 60, 300
      remove3d crate
    }
  }
  render3d
  box 159, 89, 2, 2 color "#ffffff"
}
```

- `aim3d(range)` - what the middle of the screen is pointing at, or `-1`.
- `ray3d(x, y, z, yaw, pitch, range)` - the first thing along a line, or `-1`.
- After either: `hitdist()` is how far away it was, and `hitx()`, `hity()`, `hitz()` are the exact
  spot it was hit - good for sparks and bullet holes.

## Models

A `.glb` file is loaded once and then put in the world as many times as you like.

```volt
#html
canvas 320, 180
world3d "#000" ambient 30
model3d hunter = "hunter.glb"

let a = put3d(hunter, 0, 0, -300, 0, 100)
let b = put3d(hunter, 200, 0, -300, 900, 100)
anim3d a, "walk"
solid3d a, true

every frame { render3d }
```

- `model3d name = "file.glb"` loads it. Keep the `.glb` next to your `.volt` file.
- `put3d(model, x, y, z, yaw, scale)` places one. Scale is a percent; `100` means 1 unit = 1 metre.
- `anim3d thing, "walk"` plays an animation on a loop. Part of the name is enough. `anim3d thing, ""`
  stops it. Each copy has its own skeleton, so they can be doing different things.

## Light and looks

```volt
#html
canvas 320, 180
world3d "#04060c" fog 2200 ambient 7 shadows
block3d(0, -10, 0, 1400, 20, 1400, "#59606c")
let steel = ball3d(-120, 70, -120, 70, "#c8ccd4")
shine3d steel, 18, 100
lamp3d(0, 300, 0, "#ffffff", 60, 1500)

fx3d 60, 45, 10
ao3d 70
torch3d 60, 1800

every frame { render3d }
```

- `fx3d bloom, vignette, grain` - the cinematic look. Each is 0 to 100; all three `0` turns it off.
  Bright things glow, the picture is tone-mapped like film, the edges darken and a little grain is
  added. It also switches on softer shadows.
- `ao3d strength` - soft shading where surfaces meet, which is what stops flat-coloured rooms
  looking flat. `0` turns it off. It uses the same pipeline as `fx3d`, so switching it on switches
  that on too.
- `torch3d power, range` - a flashlight that follows the camera. `torch3d 0, 0` turns it off.
- `burst3d x, y, z, colour, count, speed` - glowing sparks that fly out and fall.
- `shine3d thing, rough, metal` - `shine3d thing, 18, 100` is polished steel; `shine3d thing, 10, 0`
  is glossy paint.

## Sound in 3D

```volt
#html
canvas 320, 180
world3d "#000" ambient 20
audio thud = "thud.mp3"
player3d 0, 0, 0

every frame {
  walk3d
  if clicked() {
    sound thud at 300, 0, -200
  }
  render3d
}
```

`sound name at x, y, z` is quieter the further it is from the camera, and comes from the left or
right depending on which way you are facing. `volume 50` still works on the end if you want it
quieter. Plain `sound name` is unchanged and plays at full volume in both ears.

## The HUD

The `canvas` is drawn on top of the 3D view every frame, so anything 2D is your HUD: `box`,
`write`, `draw`, `paint`. Draw it **after** `render3d`.

For buttons in the HUD:

- `hot3d(x, y, width, height)` marks a rectangle as clickable.
- `clicked3d()` is true once when the player clicks it.

```volt
#html
canvas 320, 180
world3d "#000" ambient 20
let paused = false

every frame {
  render3d
  box 4, 4, 60, 14 color "#222"
  write "Pause" at 10, 8
  hot3d(4, 4, 60, 14)
  if clicked3d() {
    paused = not paused
  }
  if paused {
    write "PAUSED" at 160, 90 centered shadow
  }
}
```

## Making it fast

**`freeze3d`** is the big one. Call it once, after you have built the level:

```volt
#html
canvas 320, 180
world3d "#000" ambient 20

for i from 0 to 199 {
  block3d(i * 100 - 10000, 150, -600, 100, 300, 20, "#737a86")
}
freeze3d

player3d 0, 0, 0
every frame {
  walk3d
  render3d
}
```

Every plain block, ball and cylinder made so far is joined into one shape per colour. Two hundred
wall blocks stop being two hundred separate things to draw and become one. They stay solid and can
still be hit by `aim3d`, but they can no longer be moved, hidden, recoloured or removed - so make
anything that changes **after** `freeze3d`, or leave it out by giving it its own colour.

Other things that help:

- `far3d 8000` so distant things are not drawn at all.
- Reuse colours. Things sharing a colour share their material, and `freeze3d` can join them.
- `shadows` and `ao3d` both cost time. Turn them off first if a game is slow.

## Every 3D word

**Making:** `world3d` `block3d` `ball3d` `cyl3d` `lamp3d` `model3d` `put3d`

**Changing:** `move3d` `turn3d` `tilt3d` `scale3d` `color3d` `glow3d` `shine3d` `show3d`
`remove3d` `attach3d` `anim3d`

**The player:** `player3d` `walk3d` `playerx` `playery` `playerz` `playeryaw` `playerpitch`
`onground`

**Bumping:** `solid3d` `touching3d` `dist3d`

**Looking:** `aim3d` `ray3d` `hitdist` `hitx` `hity` `hitz` `camera3d` `torch3d` `mousedx`
`mousedy` `locked3d`

**Looks:** `fx3d` `ao3d` `sky3d` `look3d` `burst3d` `far3d`

**The frame:** `render3d` `clear3d` `freeze3d`

**HUD:** `hot3d` `clicked3d`

**Maths:** `sin3` `cos3` `atan2`
