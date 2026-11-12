#excel
fn label(n) {
  if n % 15 == 0 { return "FizzBuzz" }
  if n % 3 == 0 { return "Fizz" }
  if n % 5 == 0 { return "Buzz" }
  return n
}

for i from 1 to 20 {
  print label(i)
}
