// A small quiz web page that asks questions and keeps score.
#html
## body { background: #0f1a2b; color: #eef3ff; }

let score = 0

fn question(q, answer) {
  let reply = ask q
  if reply == answer {
    print "✓ Correct!"
    score = score + 1
  } else {
    print "✗ The answer was " + answer
  }
}

title "Volt Quiz"
print "Three quick questions. Type your answer and press Enter."

question("What is 7 x 8?", "56")
question("What is the capital of Kenya?", "Nairobi")
question("How many legs does a spider have?", "8")

print "You scored " + score + " out of 3!"

button "Play again" {
  # location.reload();
}
