#excel
// break, else-if chains, string builtins and maths in one program
fn grade(score) {
  if score >= 90 { return "A" }
  else {
    if score >= 80 { return "B" }
    else {
      if score >= 70 { return "C" }
      else { return "F" }
    }
  }
}

let scores = 0
let i = 0
while i < 10 {
  i = i + 1
  let s = i * 11
  if s > 95 { 
    print "stopping at " + s
    break 
  }
  print upper(grade(s)) + " for " + s
}

print "abs " + abs(0 - 7)
print "max " + max(3, 9)
print "len " + length("spreadsheet")
print "mod " + 17 % 5
print "div " + 7 / 2
print "part " + part("spreadsheet", 1, 6)
