// Prints a times table for any number you choose.
#ruby
fn line(n, times) {
  print n + " x " + times + " = " + n * times
}

let n = number(ask "Which times table?")
let i = 1
repeat 12 {
  line(n, i)
  i = i + 1
}
print "Done!"
