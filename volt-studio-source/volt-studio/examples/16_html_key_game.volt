// Press keys to play: K scores a point, space starts again. First to 20 wins.
#html
## body { background: #10131a; color: #f2f4f8; }
## .volt-show { color: #ffd23f; font-size: 2.4em; }

let score = 0
let best = 0

title "Key Game"
print "Click here first, then press K as fast as you can. Space starts again."
show "Score: 0"

when key "k" pressed {
  score += 1
  best = max(best, score)
  show "Score: " + score + "   (best: " + best + ")"
  if score == 20 {
    show "20 points - you win! Press space to play again"
  }
}

when key "space" pressed {
  score = 0
  show "Score: 0   (best: " + best + ")"
}
