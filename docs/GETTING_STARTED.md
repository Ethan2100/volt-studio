# Volt in 10 minutes

Volt is one small language that turns into several others. You write a `.volt` file, and its
**first line** decides what it becomes.

```volt
#html
print "Hello!"
```

That is a web page. Change the first line to `#python` and the same program is a Python script.
Change it to `#c++` and it is an Arduino sketch.

| First line | What you get | Button in Volt Studio |
|---|---|---|
| `#c++` | Arduino C++ | Upload |
| `#micropython` | MicroPython for ESP32 / Pico | Upload |
| `#python` | A Python script | Run |
| `#ruby` | A Ruby script | Run |
| `#js` | JavaScript for Node | Run |
| `#html` | A web page | Preview |

---

## 1. Values and text

```volt
#python
let name = "Ethan"
let games = 7

print "{name} has made {games} games"
print "Next year: {games + 1}"
```

Anything in `{curly braces}` inside text is worked out and dropped in. No `+` and no `text(...)`.

To show a real brace, write `\{` and `\}`.

## 2. Making decisions

```volt
#python
let score = 42

if score > 100 {
  print "amazing"
} else if score > 10 {
  print "not bad"
} else {
  print "keep going"
}
```

When you are checking one value against several possibilities, `match` reads better:

```volt
#python
let state = "run"

match state {
  "idle" {
    print "standing still"
  }
  "run", "walk" {
    print "moving"
  }
  else {
    print "no idea"
  }
}
```

## 3. Repeating

```volt
#python
repeat 3 {
  print "again"
}

for i from 1 to 5 {
  if i == 3 {
    continue      // skip just this turn
  }
  print i
}

for each colour, i in ["red", "green", "blue"] {
  print "{i}: {colour}"
}
```

`break` leaves a loop early; `continue` skips to the next turn. The `, i` is optional and counts
from 0.

## 4. Functions

```volt
#python
fn hit(power, bonus = 5) {
  return power + bonus
}

print hit(10)        // 15, because bonus was left out
print hit(10, 1)     // 11
```

A value with `= something` after it can be left out when you call the function.

## 5. Lists and your own types

```volt
#python
let scores = [5, 3, 9]
add 7 to scores

print "{length(scores)} scores, best is {last(sort(scores))}"
print join(sort(scores), ", ")

Player = type { name: string, health: int }

let hero = Player { name: "Finn", health: 10 }
hero.health -= 3
print "{hero.name}: {hero.health} HP"
```

## 6. A game, in 20 lines

```volt
#html
canvas 320, 180

let x = 160
let y = 90
let score = 0

every frame {
  if held("left") { x -= 3 }
  if held("right") { x += 3 }
  if held("up") { y -= 3 }
  if held("down") { y += 3 }

  if clicked() {
    score += 1
    tone 660 to 990 for 90ms
  }

  paint "#14111a"
  box x - 8, y - 8, 16, 16 color "#ffd23f"
  write "Score: {score}" at 6, 6 shadow
}
```

`every frame` runs 60 times a second. `held` reads the keyboard, `clicked` the mouse.

## 7. A 3D game, in 20 lines

```volt
#html
canvas 320, 180
world3d "#0a0d14" fog 2600 ambient 9 shadows

block3d(0, -10, 0, 2000, 20, 2000, "#5c6470")
block3d(0, 150, -600, 1200, 300, 20, "#737a86")
freeze3d

player3d 0, 0, 400

every frame {
  walk3d
  render3d
  write "WASD and the mouse" at 6, 6 shadow
}
```

`player3d` puts you in the world and `walk3d` does the rest: walking, looking, jumping, gravity
and bumping into walls. `freeze3d` joins the level into one shape so it draws fast.

There is a lot more in [VOLT3D.md](VOLT3D.md).

## 8. Running it

In **Volt Studio**, press the button in the top right: Run, Preview or Upload, depending on the
first line. From a terminal:

```
node compiler/volt.js my_program.volt
```

That writes the finished program into a folder beside your `.volt` file.

## 9. When something is wrong

Volt tries to say what to do about it, and points at the exact spot:

```
game.volt:3:8  error: Unknown variable 'scroe'. Did you mean 'score'?
  3 | print  scroe + 1
    |        ^^^^^
```

In Volt Studio the same problems are underlined as you type. Hover one to read it, hover a name
to see what it does, and press F12 on a name to jump to where it is made.

## Where to go next

- [REFERENCE.md](REFERENCE.md) - every word in the language.
- [VOLT3D.md](VOLT3D.md) - the 3D side: worlds, lights, models, physics, effects.
- [PLUGINS.md](PLUGINS.md) - adding your own libraries, panels and compile targets.
- The **Examples** tab in Volt Studio - working games you can read and change.
