// =====================================================================
// POLYGLOT - util.volt
// Small, general helpers. Pure Volt except the clock and DOM bits,
// which are single raw-JavaScript lines (Volt has no clock statement).
// =====================================================================

fn shuffle(items) {
  let i = length(items) - 1
  while i > 0 {
    let j = random(0, i)
    let tmp = items[i]
    items[i] = items[j]
    items[j] = tmp
    i -= 1
  }
  return items
}

fn posOf(items, value) {
  let i = 0
  while i < length(items) {
    if items[i] == value {
      return i
    }
    i += 1
  }
  return -1
}

// Makes user-typed text safe to put inside HTML (pure Volt).
fn esc(s) {
  let out = "" + s
  out = join(split(out, "&"), "&amp;")
  out = join(split(out, "<"), "&lt;")
  out = join(split(out, ">"), "&gt;")
  out = join(split(out, "'"), "&#39;")
  return out
}

fn pct(amount, whole) {
  if whole <= 0 {
    return 0
  }
  return min(100, amount * 100 / whole)
}

// Today as a whole number of days (so "yesterday" is dayNum() - 1).
fn dayNum() {
  # return Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);
}

// Monday = 0 ... Sunday = 6
fn weekdayIndex() {
  # return (new Date().getDay() + 6) % 7;
}

fn greeting() {
  # const h = new Date().getHours(); return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
}

fn dateLabel() {
  # return new Date().toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long' });
}

fn nowMs() {
  # return Date.now();
}

fn dayWord(day) {
  let diff = dayNum() - day
  if diff <= 0 {
    return "Today"
  }
  if diff == 1 {
    return "Yesterday"
  }
  return diff + " days ago"
}

fn minutesText(seconds) {
  if seconds < 60 {
    return seconds + "s"
  }
  return (seconds / 60) + " min"
}

// Reads what the person typed into an <input with that id>.
fn inputValue(elId) {
  # const b = document.getElementById(elId); return b ? String(b.value).trim() : '';
}

fn scrollTop() {
  # window.scrollTo(0, 0);
}
