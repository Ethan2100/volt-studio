#minecraft
// returns text? no - a scoreboard can't hold it, so print from inside
fn say(n) {
  if n % 15 == 0 { print "FizzBuzz" }
  else {
    if n % 3 == 0 { print "Fizz" }
    else {
      if n % 5 == 0 { print "Buzz" }
      else { print n }
    }
  }
}
for i from 1 to 20 { say(i) }
