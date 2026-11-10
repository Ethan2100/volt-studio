#html
// =====================================================================
//  VOLT CHAT - a messaging app, written in Volt.
//
//  The chat part works like WhatsApp: a list of conversations, a thread
//  with bubbles, typing indicators, unread badges, replies that arrive on
//  their own. The look is Instagram's: stories across the top with the
//  coloured ring, and a double-tap on any message to heart it.
//
//  Type on your keyboard - there is no hidden text box, the page reads the
//  keys itself. Enter sends. Esc goes back.
//
//  In the chat list, what you type searches your conversations. To post a
//  story, type what it should say and tap the + on "You".
// =====================================================================
title "Volt Chat"
canvas 270, 480
let sharp = crisp(2)

Person = type { name: string, tint: string, bio: string }
Msg = type { who: int, mine: int, text: string, stamp: string, heart: int, seen: int }

// ---- the people (0-4 you can chat with; 5 is you, for stories) ----
let people = []
fn addPerson(name, tint, bio) {
  add Person { name: name, tint: tint, bio: bio } to people
  return 0
}
addPerson("Mama", "#e8a0bf", "Always asking if you ate")
addPerson("Kesi", "#4de1ff", "Writes songs on the bus")
addPerson("Slime", "#7ee05a", "One more match")
addPerson("Verve", "#9fb4ff", "Slow down, it is fine")
addPerson("Ash", "#b07aff", "Meet me at the elevator")
addPerson("You", "#ffd23f", "")

let storyText = ["Fresh mandazi at 6am", "New beat. Four bars of pure bus.", "Ranked up. Do not ask how.", "Rain on the roof, finally", "Ground floor. Again.", ""]
let viewed = [0, 0, 0, 0, 0, 0]

// ---- the conversations ----
let msgs = []
let typed = ""            // whatever is being typed right now
let screen = 0            // 0 chats, 1 thread
let current = 0              // which thread is current
let skip = 0              // how many messages the thread is scrolled up
let viewing = 0 - 1       // which story is on screen, or -1
let storyStart = 0
let pendingAt = [0, 0, 0, 0, 0]
let pendingText = ["", "", "", "", ""]
let nextPing = 0
let note = ""
let noteUntil = 0
let lastTapAt = 0
let lastTapIdx = 0 - 1

// where each message bubble was drawn this frame, so a tap can find it
let hitX0 = []
let hitX1 = []
let hitY0 = []
let hitY1 = []
let hitIdx = []

# document.addEventListener('keydown', (e) => { if (e.ctrlKey || e.metaKey || e.altKey) return; if (e.key.length === 1) { if (typed.length < 160) typed += e.key; } else if (e.key === 'Backspace') { typed = typed.slice(0, -1); } });

let clockNow = ""
fn nowText() {
  # clockNow = new Date().toTimeString().slice(0, 5);
  return clockNow
}

fn say(message) {
  note = message
  noteUntil = uptime + 2200
  return 0
}

fn nameNumber(name) {
  let total = 7
  for i from 0 to length(name) - 1 {
    total = (total * 31 + indexOf("abcdefghijklmnopqrstuvwxyz .", lower(part(name, i, 1))) + 1) % 100000
  }
  return total
}

// ---- saving ----
fn saveAll() {
  save "voltchat-msgs", msgs
  save "voltchat-viewed", viewed
  save "voltchat-mystory", storyText[5]
  return 0
}

fn addMsg(who, mine, text, stamp, seen) {
  add Msg { who: who, mine: mine, text: text, stamp: stamp, heart: 0, seen: seen } to msgs
  return 0
}

fn seedHistory() {
  addMsg(0, 0, "Did you eat?", "08:02", 1)
  addMsg(0, 1, "Yes mama, just now", "08:05", 1)
  addMsg(0, 0, "Good. Don't stay up late coding", "08:06", 1)
  addMsg(1, 1, "Made you a new loop, listen when you can", "09:14", 1)
  addMsg(1, 0, "ok that is actually fire", "09:31", 1)
  addMsg(1, 0, "send me the stems", "09:31", 1)
  addMsg(2, 0, "queue up?", "11:48", 1)
  addMsg(2, 0, "bro the boss is cheating fr", "11:49", 0)
  addMsg(3, 0, "let's walk later", "13:20", 1)
  addMsg(3, 1, "Yeah, around five?", "13:22", 1)
  addMsg(4, 0, "Late. Meet at the elevator.", "14:55", 0)
  return 0
}

fn loadAll() {
  msgs = saved("voltchat-msgs", [])
  if length(msgs) == 0 {
    seedHistory()
  }
  let v = saved("voltchat-viewed", [0, 0, 0, 0, 0, 0])
  if length(v) == 6 {
    viewed = v
  }
  storyText[5] = saved("voltchat-mystory", "")
  return 0
}
loadAll()

// ---- what the other people say ----
fn greeting(c) {
  if c == 0 {
    return "Hello my dear, how is your day?"
  }
  if c == 1 {
    return "yo. I was just about to message you"
  }
  if c == 2 {
    return "bro what is up"
  }
  if c == 3 {
    return "hey. slow day, which is nice"
  }
  return "..."
}

fn replyList(c) {
  if c == 0 {
    return ["Did you eat?", "Call me when you are free", "Proud of you, you know that", "Come home early today", "Drink water, ok?"]
  }
  if c == 1 {
    return ["ok that is actually fire", "send me the stems", "I am writing something similar rn", "lol no way", "play it again"]
  }
  if c == 2 {
    return ["lmao", "queue up?", "bet", "that boss is cheating fr", "one more match"]
  }
  if c == 3 {
    return ["mm hm", "honestly same", "let's walk later", "slow down a bit", "ok ok"]
  }
  return ["fine.", "Don't tell anyone.", "I will think about it", "Late. Meet at the elevator.", "..."]
}

fn openerList(c) {
  if c == 0 {
    return ["Are you home for dinner?", "Your aunt asked about you", "Did you see the weather?"]
  }
  if c == 1 {
    return ["new idea, check your inbox", "are you still up?", "I found a chord that hurts, in a good way"]
  }
  if c == 2 {
    return ["we are one short, hop on", "new patch dropped", "you owe me a rematch"]
  }
  if c == 3 {
    return ["thinking of you, that is all", "coffee tomorrow?", "look outside"]
  }
  return ["Are you awake", "It moved again.", "Come alone."]
}

fn replyFor(c, text) {
  let low = lower(text)
  if contains(low, "hello") or contains(low, "hey") or low == "hi" {
    return greeting(c)
  }
  let choices = replyList(c)
  return choices[random(0, length(choices) - 1)]
}

// ---- reading the conversations ----
fn lastIndex(c) {
  let found = 0 - 1
  for i from 0 to length(msgs) - 1 {
    if msgs[i].who == c {
      found = i
    }
  }
  return found
}

fn unread(c) {
  let n = 0
  for i from 0 to length(msgs) - 1 {
    if msgs[i].who == c and msgs[i].mine == 0 and msgs[i].seen == 0 {
      n = n + 1
    }
  }
  return n
}

fn markRead(c) {
  for i from 0 to length(msgs) - 1 {
    if msgs[i].who == c {
      msgs[i].seen = 1
    }
  }
  return 0
}

// conversations newest first, filtered by what is typed in the search box
fn chatOrder() {
  let out = []
  let used = [0, 0, 0, 0, 0]
  for round from 0 to 4 {
    let best = 0 - 1
    let bestAt = 0 - 2
    for c from 0 to 4 {
      if used[c] == 0 {
        let at = lastIndex(c)
        let keep = true
        if length(typed) > 0 {
          keep = contains(lower(people[c].name), lower(typed))
          if at >= 0 and contains(lower(msgs[at].text), lower(typed)) {
            keep = true
          }
        }
        if keep and at > bestAt {
          best = c
          bestAt = at
        }
      }
    }
    if best >= 0 {
      add best to out
      used[best] = 1
    }
  }
  return out
}

fn wrapText(t, maxChars) {
  let lines = []
  let cur = ""
  for each w, i in split(t, " ") {
    let word = w
    while length(word) > maxChars {
      if length(cur) > 0 {
        add cur to lines
        cur = ""
      }
      add part(word, 0, maxChars) to lines
      word = part(word, maxChars, length(word) - maxChars)
    }
    if length(cur) == 0 {
      cur = word
    } else if length(cur) + 1 + length(word) <= maxChars {
      cur = cur + " " + word
    } else {
      add cur to lines
      cur = word
    }
  }
  if length(cur) > 0 {
    add cur to lines
  }
  return lines
}

fn longest(lines) {
  let n = 0
  for each ln, i in lines {
    n = max(n, length(ln))
  }
  return n
}

// ---- sending and receiving ----
fn send() {
  let text = typed
  if length(text) == 0 {
    return 0
  }
  addMsg(current, 1, text, nowText(), 1)
  typed = ""
  skip = 0
  if pendingAt[current] == 0 {
    pendingAt[current] = uptime + 1800 + random(0, 2200)
    pendingText[current] = replyFor(current, text)
  }
  saveAll()
  return 0
}

fn deliver(c, text) {
  let inThread = screen == 1 and current == c
  let seen = 0
  if inThread {
    seen = 1
  }
  addMsg(c, 0, text, nowText(), seen)
  if inThread {
    skip = 0
  } else {
    say("{people[c].name}: {part(text, 0, 22)}")
  }
  tone 740 to 990 for 70ms
  saveAll()
  return 0
}

fn openChat(c) {
  current = c
  screen = 1
  skip = 0
  typed = ""
  markRead(c)
  saveAll()
  return 0
}

fn openStory(c) {
  viewing = c
  storyStart = uptime
  viewed[c] = 1
  saveAll()
  return 0
}

fn closeStory() {
  viewing = 0 - 1
  return 0
}

// ---- drawing helpers ----
// a box with its corners shaved, for the soft look
fn soft(x, y, w, h, col, behind) {
  box x, y, w, h color col
  box x, y, 2, 2 color behind
  box x + w - 2, y, 2, 2 color behind
  box x, y + h - 2, 2, 2 color behind
  box x + w - 2, y + h - 2, 2, 2 color behind
  return 0
}

fn avatar(c, x, y, size) {
  let who1 = people[c]
  soft(x, y, size, size, who1.tint, "#0b141a")
  write upper(part(who1.name, 0, 1)) at x + size / 2, y + size / 2 - 5 centered color "#0b141a"
  return 0
}

// the Instagram ring around a story
fn ring(c, x, y, size) {
  let top = "#833ab4"
  let low = "#fcaf45"
  let mid = "#e1306c"
  if viewed[c] == 1 {
    top = "#3b4a54"
    low = "#3b4a54"
    mid = "#3b4a54"
  }
  box x - 4, y - 4, size + 8, size + 8 color mid
  box x - 4, y - 4, size + 8, (size + 8) / 3 color top
  box x - 4, y + size + 4 - (size + 8) / 3, size + 8, (size + 8) / 3 color low
  box x - 4, y - 4, 2, 2 color "#0b141a"
  box x + size + 2, y - 4, 2, 2 color "#0b141a"
  box x - 4, y + size + 2, 2, 2 color "#0b141a"
  box x + size + 2, y + size + 2, 2, 2 color "#0b141a"
  box x - 2, y - 2, size + 4, size + 4 color "#0b141a"
  return 0
}

fn heartIcon(x, y, col) {
  box x + 1, y, 2, 1 color col
  box x + 4, y, 2, 1 color col
  box x, y + 1, 7, 2 color col
  box x + 1, y + 3, 5, 1 color col
  box x + 2, y + 4, 3, 1 color col
  box x + 3, y + 5, 1, 1 color col
  return 0
}

fn rightText(text, edge, y, col) {
  write text at edge - length(text) * 6, y color col
  return 0
}

fn shortText(text, n) {
  if length(text) <= n {
    return text
  }
  return part(text, 0, n - 3) + "..."
}

// ---- the chat list ----
fn drawChats() {
  paint "#0b141a"
  write "Volt Chat" at 12, 10 size 2 color "#ffffff"
  box 0, 34, 68, 2 color "#833ab4"
  box 68, 34, 68, 2 color "#e1306c"
  box 136, 34, 68, 2 color "#f77737"
  box 204, 34, 66, 2 color "#fcaf45"

  // stories
  let order = [5, 0, 1, 2, 3, 4]
  for each c, slot in order {
    let x = 10 + slot * 43
    ring(c, x + 3, 50, 30)
    avatar(c, x + 3, 50, 30)
    if c == 5 and length(storyText[5]) == 0 {
      box x + 22, 68, 14, 14 color "#0095f6"
      write "+" at x + 29, 71 centered color "#ffffff"
    }
    write shortText(people[c].name, 6) at x + 18, 90 centered color "#8696a0"
  }

  // search
  soft(10, 108, 250, 22, "#202c33", "#0b141a")
  if length(typed) == 0 {
    write "Search chats, or type a story" at 18, 115 color "#667781"
  } else {
    write shortText(typed, 38) at 18, 115 color "#e9edef"
    if floor(uptime / 500) % 2 == 0 {
      box 18 + min(length(typed), 38) * 6, 113, 1, 10 color "#00a884"
    }
  }

  // conversations
  let rows = chatOrder()
  if length(rows) == 0 {
    write "No chats match that." at 135, 160 centered color "#667781"
  }
  for each c, slot in rows {
    let y = 138 + slot * 58
    let at = lastIndex(c)
    avatar(c, 12, y + 8, 40)
    write people[c].name at 62, y + 10 color "#e9edef"
    let waiting = pendingAt[c] > 0 and uptime > pendingAt[c] - 1400
    if waiting {
      write "typing..." at 62, y + 26 color "#00a884"
    } else if at >= 0 {
      let m = msgs[at]
      let preview = shortText(m.text, 27)
      if m.mine == 1 {
        preview = "You: " + shortText(m.text, 22)
      }
      let shade = "#8696a0"
      if m.mine == 0 and m.seen == 0 {
        shade = "#e9edef"
      }
      write preview at 62, y + 26 color shade
    }
    if at >= 0 {
      let hot = "#8696a0"
      if unread(c) > 0 {
        hot = "#00a884"
      }
      rightText(msgs[at].stamp, 262, y + 10, hot)
    }
    let n = unread(c)
    if n > 0 {
      soft(240, y + 28, 20, 14, "#00a884", "#0b141a")
      write "{n}" at 250, y + 31 centered color "#0b141a"
    }
    box 62, y + 55, 198, 1 color "#17222a"
  }
}

// ---- a thread ----
fn drawThread() {
  paint "#0b141a"
  hitX0 = []
  hitX1 = []
  hitY0 = []
  hitY1 = []
  hitIdx = []

  // the messages, built up from the bottom
  let cursor = 412   // leaves room under the newest bubble for a heart
  let seenCount = 0
  let total = length(msgs)
  for k from 0 to total - 1 {
    let i = total - 1 - k
    if msgs[i].who == current {
      seenCount = seenCount + 1
      if seenCount > skip and cursor > 56 {
        let m = msgs[i]
        let lines = wrapText(m.text, 29)
        let w = max(54, longest(lines) * 6 + 16)
        let h = length(lines) * 11 + 17
        let y = cursor - h
        let x = 8
        let fill = "#202c33"
        if m.mine == 1 {
          x = 262 - w
          fill = "#005c4b"
        }
        soft(x, y, w, h, fill, "#0b141a")
        for each ln, row in lines {
          write ln at x + 8, y + 6 + row * 11 color "#e9edef"
        }
        write m.stamp at x + w - 8 - length(m.stamp) * 6, y + h - 12 color "#8696a0"
        if m.heart == 1 {
          soft(x + w - 22, y + h - 2, 20, 12, "#17222a", "#0b141a")
          heartIcon(x + w - 15, y + h + 1, "#ff3040")
        }
        add x to hitX0
        add x + w to hitX1
        add y to hitY0
        add y + h to hitY1
        add i to hitIdx
        cursor = y - 8
        if m.heart == 1 {
          cursor = cursor - 8
        }
      }
    }
  }

  // header, drawn over the top of the messages
  box 0, 0, 270, 48 color "#111b21"
  box 0, 48, 270, 1 color "#17222a"
  write "<" at 14, 14 size 2 color "#e9edef"
  ring(current, 44, 10, 28)
  avatar(current, 44, 10, 28)
  write people[current].name at 84, 11 color "#e9edef"
  let waiting = pendingAt[current] > 0 and uptime > pendingAt[current] - 1400
  if waiting {
    write "typing..." at 84, 26 color "#00a884"
  } else {
    write "online" at 84, 26 color "#8696a0"
  }

  // the box you type in
  box 0, 424, 270, 56 color "#111b21"
  soft(8, 432, 196, 32, "#202c33", "#111b21")
  if length(typed) == 0 {
    write "Message" at 18, 444 color "#667781"
  } else {
    let shown = typed
    if length(typed) > 30 {
      shown = part(typed, length(typed) - 30, 30)
    }
    write shown at 18, 444 color "#e9edef"
    if floor(uptime / 500) % 2 == 0 {
      box 18 + length(shown) * 6, 441, 1, 14 color "#00a884"
    }
  }
  let live = length(typed) > 0
  let sendFill = "#1a2a2f"
  let sendInk = "#4a6a6f"
  if live {
    sendFill = "#00a884"
    sendInk = "#0b141a"
  }
  soft(212, 432, 50, 32, sendFill, "#111b21")
  write "send" at 237, 444 centered color sendInk
}

// ---- a story ----
fn drawStory() {
  let c = viewing
  let seed = nameNumber(people[c].name)
  paint "#0a0a0f"
  // art made from the name, so every story looks like itself
  for b from 0 to 5 {
    let h = 120 + (seed / pow(7, b) % 1000) * 240 / 1000
    let shade = people[c].tint
    if b % 2 == 1 {
      shade = "#ffffff"
    }
    box 8 + b * 42, 440 - h, 36, h color shade
  }
  box 0, 0, 270, 70 color "#0a0a0f"
  box 0, 380, 270, 100 color "#0a0a0f"

  // progress
  let done = min(1, (uptime - storyStart) / 4000)
  box 10, 10, 250, 3 color "#3b4a54"
  box 10, 10, 250 * done, 3 color "#ffffff"

  avatar(c, 10, 20, 28)
  write people[c].name at 46, 26 color "#ffffff"
  write "now" at 46, 40 color "#8696a0"

  let lines = wrapText(storyText[c], 20)
  // a dark card behind the words, so they read over any of the bars
  soft(14, 200 - length(lines) * 9 - 10, 242, length(lines) * 18 + 16, "#0a0a0f", "#0a0a0f")
  for each ln, row in lines {
    write ln at 135, 200 + row * 18 - length(lines) * 9 centered size 2 color "#ffffff" shadow
  }

  if c < 5 {
    soft(10, 430, 250, 34, "#161b20", "#0a0a0f")
    write "Send message to {people[c].name}" at 135, 443 centered color "#8696a0"
  }
}

// ---- keys ----
when key "enter" pressed {
  if viewing >= 0 {
    closeStory()
  } else if screen == 1 {
    send()
  }
}
when key "escape" pressed {
  if viewing >= 0 {
    closeStory()
  } else if screen == 1 {
    screen = 0
    typed = ""
  } else {
    typed = ""
  }
}
when key "up" pressed {
  if screen == 1 {
    skip = skip + 1
  }
}
when key "down" pressed {
  if screen == 1 {
    skip = max(0, skip - 1)
  }
}

// ---- the loop ----
every frame {
  // someone replies
  for c from 0 to 4 {
    if pendingAt[c] > 0 and uptime >= pendingAt[c] {
      pendingAt[c] = 0
      deliver(c, pendingText[c])
    }
  }
  // now and then someone writes first
  if nextPing == 0 {
    nextPing = uptime + 14000
  }
  if uptime > nextPing and viewing < 0 {
    let who = random(0, 4)
    if pendingAt[who] == 0 {
      let openers = openerList(who)
      deliver(who, openers[random(0, length(openers) - 1)])
    }
    nextPing = uptime + 18000 + random(0, 22000)
  }

  // a story that has run its time moves on to the next
  if viewing >= 0 and uptime - storyStart > 4000 {
    if viewing < 4 and viewing != 5 {
      openStory(viewing + 1)
    } else {
      closeStory()
    }
  }

  // ---- taps ----
  if clicked() {
    let mx = mousex()
    let my = mousey()
    if viewing >= 0 {
      if my > 425 and viewing < 5 {
        let c = viewing
        closeStory()
        openChat(c)
      } else if mx < 90 {
        if viewing > 0 and viewing < 5 {
          openStory(viewing - 1)
        } else {
          closeStory()
        }
      } else if viewing < 4 {
        openStory(viewing + 1)
      } else {
        closeStory()
      }
    } else if screen == 0 {
      // story row
      if my >= 46 and my < 100 {
        let slot = floor((mx - 10) / 43)
        let order = [5, 0, 1, 2, 3, 4]
        if slot >= 0 and slot <= 5 {
          let c = order[slot]
          if c == 5 {
            if length(typed) > 0 {
              storyText[5] = typed
              typed = ""
              viewed[5] = 0
              saveAll()
              say("Story posted")
            } else if length(storyText[5]) > 0 {
              openStory(5)
            } else {
              say("Type what it says, then tap +")
            }
          } else {
            openStory(c)
          }
        }
      }
      // a conversation
      if my >= 138 {
        let rows = chatOrder()
        let slot = floor((my - 138) / 58)
        if slot >= 0 and slot < length(rows) {
          openChat(rows[slot])
        }
      }
    } else {
      if my < 48 and mx < 40 {
        screen = 0
        typed = ""
      } else if my >= 432 and mx >= 212 {
        send()
      } else {
        // a second tap on the same bubble hearts it
        for k from 0 to length(hitIdx) - 1 {
          if mx >= hitX0[k] and mx < hitX1[k] and my >= hitY0[k] and my < hitY1[k] {
            if hitIdx[k] == lastTapIdx and uptime - lastTapAt < 450 {
              if msgs[hitIdx[k]].heart == 1 {
                msgs[hitIdx[k]].heart = 0
              } else {
                msgs[hitIdx[k]].heart = 1
              }
              saveAll()
              lastTapIdx = 0 - 1
            } else {
              lastTapIdx = hitIdx[k]
              lastTapAt = uptime
            }
          }
        }
      }
    }
  }

  // ---- the picture ----
  if viewing >= 0 {
    drawStory()
  } else if screen == 1 {
    drawThread()
  } else {
    drawChats()
  }

  if uptime < noteUntil and viewing < 0 {
    soft(10, 440, 250, 26, "#233138", "#0b141a")
    write note at 135, 450 centered color "#e9edef"
  }
}
