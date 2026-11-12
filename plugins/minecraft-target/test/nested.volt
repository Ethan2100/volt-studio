#minecraft
fn area(w, h) { return w * h }
fn total(n) {
  let acc = 0
  for k from 1 to n { acc = acc + area(k, k) }
  return acc
}
for r from 1 to 5 { print "total " + r + " = " + total(r) }
