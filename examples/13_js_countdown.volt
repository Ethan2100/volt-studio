// A rocket countdown that uses a timer. Runs without installing anything.
#js
let count = 10

print "Countdown starting..."

every 1s {
  if count > 0 {
    print count + "..."
    count = count - 1
  } else {
    print "LIFT OFF!"
    # process.exit(0);
  }
}
