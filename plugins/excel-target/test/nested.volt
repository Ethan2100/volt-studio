#excel
fn area(w, h) { return w * h }
fn describe(w, h) {
  return "box " + w + "x" + h + " = " + area(w, h)
}
for r from 1 to 3 {
  for c from 1 to 3 {
    if r != c {
      print describe(r, c)
    }
  }
}
print "done"
