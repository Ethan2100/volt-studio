// A guessing game: the computer picks a number, you guess it.
// Same game as 11_python_guess_the_number.volt and 12_ruby_times_tables.volt,
// this time compiled to plain Lua (run it with: lua 19_lua_number_guesser.lua).
#lua
let secret = random(1, 50)
let tries = 0
let guess = 0

print "I'm thinking of a number from 1 to 50."

while guess != secret {
  guess = number(ask "Your guess?")
  tries = tries + 1
  if guess < secret {
    print "Higher!"
  } else if guess > secret {
    print "Lower!"
  }
}

print "You got it in " + tries + " tries!"
