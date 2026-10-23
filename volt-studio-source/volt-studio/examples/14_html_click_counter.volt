// A web page with buttons and your own CSS colours.
#html
// ## lines are CSS for the page
## body { background: #10131a; color: #f2f4f8; }
## .big { font-size: 56px; font-weight: 800; color: #ffd23f; }

let clicks = 0

title "Click Counter"
html "<p>Made with <b>Volt</b>. Every 5 clicks you get a surprise.</p>"

button "Click me" {
  clicks = clicks + 1
  print "Clicked " + clicks + " times"
  if clicks % 5 == 0 {
    html "<div class='big'>" + clicks + "!</div>"
  }
}

button "Reset" {
  clicks = 0
  print "Back to zero"
}
