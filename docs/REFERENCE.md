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
14. [Built-in functions](#built-in-functions)
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

Volt numbers are **whole numbers** (no decimals). Dividing rounds down: `7 / 2` is `3`. Decimals are only allowed in times, like `1.5s`.

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

random(1, 6)  map(x, 0, 1023, 0, 100)  constrain(x, 0, 100)
min(a, b)  max(a, b)  abs(x)

# raw code line              ## raw code at the top
#include <Library.h>
```
