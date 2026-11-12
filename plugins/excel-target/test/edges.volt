#excel
// the exact spots where a spreadsheet's idea of maths differs from Volt's
print 7 / 2
print 0 - 7 / 2
print (0 - 7) / 2
print 7 % 3
print (0 - 7) % 3
print 7 % (0 - 3)
print sqrt(10)
print sqrt(16)
print number("3.7")
print number("abc")
print map(5, 0, 10, 0, 100)
print map(3, 0, 10, 0, 100)
print contains("Spreadsheet", "Spread")
print contains("Spreadsheet", "spread")
print part("spreadsheet", 0, 6)
print part("spreadsheet", 6, 5)
print abs(0 - 4) + max(1, 2) + min(5, 3)
print constrain(99, 0, 10)
print length("abc") + length(123)
let flag = 3 > 2
print flag
print "flag is " + flag
print 10 == 10
print "x" != "x"
