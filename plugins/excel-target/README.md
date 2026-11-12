# `#excel` — compile Volt into a spreadsheet that runs it

Put `#excel` on the first line and Volt compiles your program into a
spreadsheet. Not a data export — **the spreadsheet is the machine.**

Open the result and you are looking at your program mid-execution. Scroll
down and you watch it run.

```volt
#excel
let count = 5
while count > 0 {
  print count
  count = count - 1
}
print "LIFT OFF"
```

| Step | PC | Just ran | count | Output |
|---|---|---|---|---|
| 0 | 0 | (start) | 0 | |
| 1 | 1 | count = 5 | 5 | |
| 2 | 2 | if not (count > 0) go to step 5 | 5 | |
| 3 | 3 | print count | 5 | 5 |
| 4 | 4 | count = count - 1 | 4 | |
| 5 | 1 | go to step 1 | 4 | |
| … | | | | |
| 23 | 6 | print "LIFT OFF" | 0 | LIFT OFF |

No macros and no VBA — **formulas only**, so it runs the same in Excel,
LibreOffice and Google Sheets.

## How it works

Your program is lowered to a flat list of five instructions:

| | |
|---|---|
| `SET name, expr` | `name = expr`, then step forward |
| `PRINT expr` | put `expr` in the Output column, then step forward |
| `JMP n` | set the program counter to `n` |
| `JZ expr, n` | if `expr` is false, jump to `n`; otherwise step forward |
| `HALT` | freeze |

Then every row of the sheet becomes one tick of the clock. A row reads the
row above it, looks at *that* row's program counter, and applies the single
instruction it points at:

- **Column B (PC)** is the program counter. Most instructions just do
  `=previous + 1`; a jump is a formula that sets it to something else —
  which is the whole trick. **A loop is a formula that points backwards.**
- **One column per variable.** A variable only changes on the steps that
  assign to it, so its formula lists just those steps and otherwise carries
  the value down from the row above.
- **The Output column** holds whatever `print` produced on that step.
- **Column C** names the instruction that just ran, looked up from the
  program listing off to the right of the sheet.

Formulas are written in R1C1, so the identical formula text is correct on
every row — which keeps the file small however many steps you run.

## What it supports

`let` · `if` / `else` · `while` · `for` · `repeat` · `forever` · `break` ·
functions with `return` · `print` · all the arithmetic, comparison and
logical operators · `abs` `min` `max` `sqrt` `sign` `sin` `cos` `constrain`
`map` `number` `text` `length` `upper` `lower` `contains` `part`

Volt's semantics are preserved exactly, including the corners where a
spreadsheet would normally disagree:

- `7 / 2` is `3` — whole numbers divide as whole numbers, and you only get
  decimals once a decimal is involved. The sheet checks as it runs.
- `-7 % 3` is `-1`, not `2`. Excel's `MOD` follows the sign of the divisor;
  Volt follows the dividend, so the generated formula does too.
- `sqrt(10)` is `3` — Volt rounds it down.
- `part(s, 0, 6)` counts from 0, where a spreadsheet's `MID` counts from 1.
- `contains` is case-sensitive, so it compiles to `FIND`, not `SEARCH`.
- `true` and `false` print as the words, not as `TRUE` or `1`.

These are verified rather than asserted: `test/run.sh` compiles each program
in `test/` twice — once with this target, once through Volt's own `#js`
backend — runs the spreadsheet through LibreOffice and the JavaScript under
Node, and fails if the two outputs differ by a single line.

## What it can't do

A spreadsheet row has no call stack and no keyboard, so:

- **No recursion.** Functions are inlined at their call sites, which is why
  a function that calls itself is a compile error instead of a hang.
- **No `ask`** — there is nothing to type into. Use `let`, or point the
  program at a cell and edit it.
- **No `random`.** A spreadsheet's random functions redraw every time
  anything on the sheet changes, which would reshuffle the entire run on
  every edit.
- **No pins, timers or raw code** — there is no hardware and no host
  language to escape into.
- **Dividing by zero gives 0**, where Volt's other targets give `Infinity`.
  Spreadsheets have no infinity, and letting `#DIV/0!` through would poison
  every row below it.

Two size limits, both of which produce a clear error rather than a broken
sheet: a single variable can be assigned in about 60 places (formulas only
nest so deep), and the run is 400 steps long by default — a program that
needs longer stops early with `HALT` still showing in the last row.

## Install

Copy this folder into your plugins folder (**Library → Open plugins
folder**) and press **Rescan**. `#excel` then works as a first line, and the
output panel saves `<name>/<name>.xls`.
