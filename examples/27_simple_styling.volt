#html

// Quick page styling without writing any CSS: just assign to
// background.___ and text.___ like any other Volt variable.

background.color = "#101522"
text.color = "white"
text.font = "Georgia"
text.size = 20
text.align = "center"

title "Night Mode"
print "Dark background, easy-to-read text - no CSS needed."
print "Press H to flash the text red."

when key "h" pressed {
  text.color = "red"
  wait 200ms
  text.color = "white"
}
