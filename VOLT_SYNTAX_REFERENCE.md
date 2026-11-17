# Volt syntax reference

Every rule here was confirmed by compiling it with `compiler/volt.js`. Where a
form is marked as rejected, that is the compiler's own error message, quoted.

Audited against commit `2876c7c`.

---

## 1. The first line picks the output

A Volt file's first line chooses what it compiles into:

| First line | Output | 3D? | 2D canvas? |
| --- | --- | :-: | :-: |
| `#html` | a self-contained web page | yes | yes |
| `#js` | a Node.js script | no | no |
| `#c++` | Arduino C++ | no | no |
| `#python` | Python | no | no |
| `#micropython` | MicroPython | no | no |
| `#ruby` | Ruby | no | no |

Plugins add more targets (`lua`, `luau`, `pseudo`, and the novelty `excel` and
`minecraft`). These are loaded by the Volt Studio app from `plugins/`; the bare
compiler rejects them with `Volt can't make 'lua' yet`, so a plugin target
only works inside the app.

**This matters more than anything else in this document: all 3D, all 2D
drawing, and all game input exist only in `#html`.** A `#c++` program cannot
call `world3d`, `box` or `held`. The compiler rejects it by name:

```
'box' only works in #html programs (web pages with a canvas)
```

So a 3D RPG is an `#html` program. The C++ target is for microcontrollers.

---

## 2. Values and variables

```volt
let x = 5            // whole number
let r = 1.5          // decimal
let s = "hello"      // string, double quotes
let b = true         // or false
let L = [1, 2, 3]    // list
```

- `let` declares. Plain `name = value` assigns to something already declared.
- **There are no type annotations on `let` or on function parameters.**
  `let x: int = 5` is rejected with `Expected '=' but found ':'`, and
  `fn add(a: int, b: int)` with `Expected ')' but found ':'`. Types appear
  only in record declarations (below).
- A `let` at the top level of the file is global and is visible inside
  functions, which may both read and assign to it.

### Records

```volt
Foe = type { hp: int, name: string, x: float, alive: bool }

let f = Foe { hp: 10, name: "wolf", x: 0.0, alive: true }
print f.hp
f.hp = 5
```

Field types are `int`, `float`, `string`, `bool`, `list`.

**Records only work in `#html`.** In any other target the compiler says
`'Foe = type { ... }' only works in #html programs`.

Records inside a list can be mutated in place: `men[i].hp = 5` works, and is
how every game in `examples/` keeps per-entity state.

### Lists

```volt
let L = []
add 7 to L              // append
remove L[0]             // remove by index
let n = length(L)
let first = L[0]
L[0] = 9
```

`remove 0 from L` is **not** valid — the compiler asks for `remove L[0]`.

---

## 3. Operators

| Kind | Operators |
| --- | --- |
| Arithmetic | `+` `-` `*` `/` `%` |
| Comparison | `==` `!=` `<` `>` `<=` `>=` |
| Logical | `and` `or` `not` (also `&&` `\|\|`) |
| String | `+` joins; use `text(n)` to add a number to a string |

Unary minus works: `-3` compiles to `-(3)`. The repository's examples
nonetheless write `0 - 3` everywhere, which is also correct and is worth
matching for consistency.

Compound assignment works too: `z += 2` compiles to `z = z + 2`. `-=`, `*=`
and `/=` follow the same pattern. `++` and `--` do not exist.

---

## 4. Control flow

```volt
if hp > 0 {
  print "alive"
} else {
  print "dead"
}

while i < 10 {
  i = i + 1
}

repeat 3 {
  print "again"
}

for i from 1 to 10 {
  print i
}

for each item in L {
  print item
}

break          // leaves the nearest loop
```

`for i in 1 to 10` is rejected: the keyword is `from`, not `in`
(`Expected 'from' after 'i'`). `for each ... in` is correct.

---

## 5. Functions

```volt
fn add(a, b) {
  return a + b
}

fn greet(name) {
  print "hi " + name
  return 0
}
```

- No type annotations, no default arguments, no varargs.
- `return` with no value is allowed; several engine commands expect a
  function to end with `return 0`.
- Functions may be declared in any order and may call each other.
- Recursion compiles.

---

## 6. Program shape

A `#html` game is set-up statements at the top level, then a frame block:

```volt
#html
title "My Game"
canvas 480, 270
world3d "#101820" fog 5000 ambient 60 fov 70 shadows

let hero = block3d(0, 0, 0, 40, 100, 40, "#8ab")

every frame {
  move3d hero, 0, 0, 0
  render3d
}
```

**`fn main()` is not an entry point in any target.** It compiles, and nothing
ever calls it. A `#js` program whose whole body sits inside `fn main()` runs
and prints nothing; an `#html` game written that way shows a black screen.

The entry point is **top-level statements**. They run in order, once, at
start-up. For a game, the frame loop is `every frame { }`:

```volt
#js
print "this runs"
let x = 2
print x * 3          // 6

fn greet(n) {
  print "hi " + n
  return 0
}
greet("ethan")       // called explicitly, at the top level
```

Other top-level blocks:

```volt
when key "w" pressed {  }    // not `when key "w" {`
after 500ms {  }             // or `after 2s` - a bare number is rejected
forever {  }
```

### Importing another file

```volt
import "mathlib.volt"
```

Pastes another Volt file's code in before compiling. The file must sit in the
same folder. It is textual inclusion, not a module system: there are no
namespaces, no exports and no selective import, and a name clash is a
redefinition. Verified working — `examples/22_import_library.volt` imports
`22_import_library_lib.volt` and prints the right answers.

### Raw passthrough

A line beginning with `#` inside the body is emitted verbatim into the output
language:

```volt
# const extra = 1;
```

This is the escape hatch, and it is how most of the repository's older 3D code
was written before the engine had the features. It is not Volt, and a weaker
model reading those files will learn JavaScript rather than Volt.

---

## 7. Statements versus functions

This is the distinction that catches people, and the compiler enforces it
strictly.

**Functions** return a value and take parentheses:

```volt
let id = block3d(0, 0, 0, 10, 10, 10, "#fff")
let d  = dist(0, 0, 3, 4)
let n  = bump3d(x, y, z, 30)
```

**Statements** are commands, take no parentheses, and return nothing:

```volt
move3d id, 0, 0, 0
turn3d id, 900
camera3d 0, 100, 0 - 300, 0, 0
render3d
```

Writing `move3d(id, 0, 0, 0)` is a syntax error, and so is
`let x = move3d id, 0, 0, 0`. Section 2 of the registry marks which is which
for every name.

---

## 8. Units, which are not obvious

| Quantity | Unit | Note |
| --- | --- | --- |
| 3D distance | **centimetres** | `block3d(0, 0, 0, 100, 100, 100, …)` is a 1 m cube |
| 3D angles | **tenths of a degree** | `turn3d id, 900` is 90°. `__D2R = PI/1800` |
| 2D distance | pixels, in canvas space | |
| Time (`after`) | `500ms`, `2s` | a bare number is rejected |
| Percentages | 0–100 | `alpha`, `blend3d`, `sweep`, `shine3d` |
| Colours | `"#rrggbb"` strings | |

The tenths-of-a-degree rule is the one that costs hours. `sin3`, `cos3` and
`atan2` all use it, and they return values scaled by 1000, so the idiom for a
unit direction vector is:

```volt
let fx = sin3(number(yaw * 10.0)) / 1000.0
let fz = cos3(number(yaw * 10.0)) / 1000.0
```

### The camera's yaw runs the other way

`camera3d` sets `rotation.y = -yaw`, so its look vector is
`(sin(yaw), -cos(yaw))` — the opposite in Z to the `(sin, cos)` heading that
`turn3d` and the movement maths use. To aim a camera **along** a heading:

```volt
camera3d cx, cy, cz, number(1800.0 - heading * 10.0), pitch
```

Omitting the `1800.0 -` points the camera away from whatever it should be
looking at. This is a real trap and it is why both games in `examples/` once
framed the wrong thing.

---

## 9. Reserved words

These cannot be used as variable or parameter names:

```
pin input output analog pwm servo stepper read pressed step turn on off
toggle set to fade over tone for let print uptime ask if else repeat while
break wait stop show clear forever every after when fn return true false
and or not
```

Plus every game word (`box`, `card`, `draw`, `camera`, `save`, `clip`, …) and
every builtin (`len`, `min`, `max`, `text`, `number`, …). The compiler's error
is helpful and names a replacement:

```
'step' is a Volt word, so it can't be used as a name. Pick another, like 'step1' or 'myStep'
```

`len`, `step`, `turn`, `end`, `dir` are the ones that bite most often.

---

## 10. What Volt does not have

Verified absent, so that nothing is invented:

- No classes, methods, inheritance or `this`.
- No closures, lambdas or function values. A function cannot be passed as an
  argument.
- No `try`/`catch`, no exceptions.
- No `switch`.
- No `++`, `--` (but `+=`, `-=`, `*=`, `/=` do work).
- No ternary `? :` — the compiler says `I don't understand the character '?'`.
- No string interpolation. Use `+` and `text()`.
- No dictionaries or maps. Records have fixed fields; lists are the only
  dynamic collection.
- No `null`/`nil`.
- No multiple return values.
- No unary minus (see §3).
