# `#minecraft` — compile Volt into Minecraft commands

Put `#minecraft` on the first line and Volt compiles your program into
commands that run on the scoreboard. **Minecraft's game loop becomes your
program's clock.**

```volt
#minecraft
let count = 5
while count > 0 {
  print count
  count = count - 1
}
print "LIFT OFF"
```

compiles to, among others:

```mcfunction
# 1: if false go to 5
execute if score #pc volt matches 1 run scoreboard players operation #t0 volt = #count volt
execute if score #pc volt matches 1 run scoreboard players set #t1 volt 0
execute if score #pc volt matches 1 if score #t0 volt > #t1 volt run scoreboard players set #t2 volt 1
execute if score #pc volt matches 1 if score #t2 volt matches 0 run scoreboard players set #npc volt 5
# 4: go to 1
execute if score #pc volt matches 4 run scoreboard players set #npc volt 1
```

Put `function volt:tick` on a repeating command block and watch the
countdown appear in chat.

## How it works

The scoreboard is the machine. One objective, `volt`, holds every
register: `#pc` is the program counter, one holder per variable, `#t0…`
for working space.

Your program is lowered to the same flat instruction list the `#excel`
target uses — `SET` / `PRINT` / `JMP` / `JZ` / `HALT` — and then every
command is gated on the program counter:

```mcfunction
execute if score #pc volt matches 7 run ...
```

so the whole program is one flat function, and on any given tick only the
lines belonging to the current instruction do anything. **One call of
`volt:tick` runs exactly one instruction.**

The one real trap: the next counter value is worked out into `#npc` and
only copied into `#pc` at the very end of the tick. Update it in place and
a backward jump lands on a lower instruction whose lines *have not run
yet this tick* — so they fire too, and the program races ahead several
steps in one go.

## Getting it into a world

```
node make-datapack.js countdown/countdown.mcfunction
```

A datapack can be a plain folder, so no zipping is needed — drop the
result in `<your world>/datapacks/` and then, in game:

```
/reload
/function volt:setup      load the program
/function volt:tick       run one instruction
```

To let it run on its own, put `function volt:tick` in a repeating command
block, or `/schedule function volt:tick 1t replace`. To watch the
registers live: `/scoreboard objectives setdisplay sidebar volt`.

## Whole numbers only

A scoreboard holds 32-bit integers and nothing else, so **text exists only
at the moment it is printed.** `print "score: " + n` works — it becomes a
`tellraw` with a text component and a score component — but no variable
can hold text, and a function cannot return it. The compiler works out
which columns would need to and says so instead of producing something
that quietly misbehaves.

FizzBuzz therefore prints from inside the function rather than returning a
word:

```volt
fn say(n) {
  if n % 15 == 0 { print "FizzBuzz" }
  else { ... }
}
```

Volt's arithmetic is preserved where Minecraft's disagrees:

- **`-7 / 2` is `-3`, not `-4`.** Minecraft's `/=` floors; Volt truncates
  toward zero. The generator works out the floor and nudges it back by one
  in exactly the case where they differ — signs differing, no clean
  division.
- **`-7 % 3` is `-1`, not `2`.** Minecraft's `%=` takes the sign of the
  divisor, Volt's takes the sign of the dividend, so the remainder is
  rebuilt from the truncating quotient rather than used directly.
- **`true` and `false` print as words.** A score has no true/false, so a
  print containing one is emitted once per outcome, each guarded on the
  value. Two per line is the limit before it is cheaper to print them
  separately, and the compiler says so.

Also unavailable, each with its own error: recursion (functions are
inlined), `ask`, `random`, `sqrt`, `sin`/`cos`, text functions
(`upper`, `part`, `contains`…), pins, timers and raw code.

## Testing

`test/run.sh` compiles each program in `test/` twice — once to commands,
once through Volt's own `#js` backend — then runs the commands through
`sim.js` and fails on any difference. 5 programs, 60 lines of output.

`sim.js` is a small interpreter for the command forms this target emits,
and it reads the generated text, so it checks the commands that would
actually be pasted into the game — including modelling `/=` as flooring
and `%=` as divisor-signed, which is what makes the corrections above
testable.

**What it does not prove:** that Minecraft accepts the syntax. It checks
the program's logic, not the parser's opinion. Only the game can tell you
that, so try the datapack.

## Install

Copy this folder into your plugins folder (**Library → Open plugins
folder**) and press **Rescan**. `#minecraft` then works as a first line,
and the output panel saves `<name>/<name>.mcfunction`.
