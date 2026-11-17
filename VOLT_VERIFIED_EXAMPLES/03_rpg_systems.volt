// VERIFIED: compiles and runs. Inventory, quests, an NPC you can talk to,
// and a save system - the parts of an RPG that are data plus HUD rather than
// engine features.
#html
title "RPG Systems"
canvas 480, 270
world3d "#121a26" fog 6000 ambient 95 fov 72 shadows

model3d body = "@male"
model3d moves = "@animations"

block3d(0, 0 - 20, 0, 2600, 40, 2600, "#5b677f")

let hero = put3d(body, 0, 0, 0, 0, 100)
solid3d hero, 0
clips3d hero, moves
anim3d hero, "Idle_Loop"

Npc = type { rig: int, x: float, z: float, name: string, line: string }
Item = type { name: string, kind: string, power: int, count: int }
Quest = type { title: string, need: int, got: int, done: bool }

let npcs = []
let bag = []
let quests = []
let talking = 0 - 1
let hx = 0.0
let hz = 0.0

fn spawnNpc(x, z, nm, ln) {
  let r = put3d(body, x, 0, z, 0, 98)
  solid3d r, 0
  clips3d r, moves
  anim3d r, "Idle_Talking_Loop"
  add Npc { rig: r, x: x, z: z, name: nm, line: ln } to npcs
  return 0
}

// lists have no find, so stacking an item is a loop
fn give(nm, kind, power) {
  let i = 0
  while i < length(bag) {
    if bag[i].name == nm {
      bag[i].count = bag[i].count + 1
      return 0
    }
    i = i + 1
  }
  add Item { name: nm, kind: kind, power: power, count: 1 } to bag
  return 0
}

fn advanceQuest(n) {
  if n >= length(quests) { return 0 }
  quests[n].got = quests[n].got + 1
  if quests[n].got >= quests[n].need { quests[n].done = true }
  return 0
}

// save and saved hold one value each, so a list is flattened by hand
fn saveGame() {
  save "hx", number(hx)
  save "hz", number(hz)
  save "bagCount", length(bag)
  let i = 0
  while i < length(bag) {
    save "bag" + text(i) + "n", bag[i].name
    save "bag" + text(i) + "c", bag[i].count
    i = i + 1
  }
  return 0
}

fn loadGame() {
  hx = number(saved("hx", 0))
  hz = number(saved("hz", 0))
  return 0
}

fn panel(x, y, w, h) {
  alpha 88
  grad x, y, w, h, 14, "#1d2432", "#0c1118"
  alpha 100
  edge x, y, w, h, 14, 1 color "#3a465a"
  return 0
}

fn drawBag() {
  panel(330, 14, 136, 92)
  write "SATCHEL" at 344, 24 color "#8294aa"
  let i = 0
  while i < length(bag) {
    let it = bag[i]
    write it.name + " x" + text(it.count) at 344, number(42 + i * 14) color "#eaf2f8"
    i = i + 1
  }
  return 0
}

fn drawQuests() {
  panel(14, 14, 180, 70)
  write "QUESTS" at 28, 24 color "#8294aa"
  let i = 0
  while i < length(quests) {
    let q = quests[i]
    let tint = "#eaf2f8"
    if q.done { tint = "#9ad7a0" }
    write q.title + "  " + text(q.got) + "/" + text(q.need) at 28, number(42 + i * 14) color tint
    i = i + 1
  }
  return 0
}

fn drawTalk() {
  if talking < 0 { return 0 }
  let n = npcs[talking]
  let w = number(textw(n.line, 1)) + 40.0
  panel(number(240.0 - w / 2.0), 196, number(w), 46)
  write n.name at 240, 206 color "#f3c762" centered
  write n.line at 240, 222 color "#eaf2f8" centered
  return 0
}

spawnNpc(300.0, 400.0, "ELDER MAWE", "Three wolves still prowl the ridge.")
add Quest { title: "Clear the ridge", need: 3, got: 0, done: false } to quests
give("Iron Sword", "weapon", 12)
give("Bread", "food", 0)
give("Bread", "food", 0)
loadGame()

every frame {
  let dt = 0.016

  if held("w") { hz = hz + 240.0 * dt }
  if held("s") { hz = hz - 240.0 * dt }
  if held("a") { hx = hx - 240.0 * dt }
  if held("d") { hx = hx + 240.0 * dt }

  // talk when close enough and E is down
  talking = 0 - 1
  let i = 0
  while i < length(npcs) {
    let n = npcs[i]
    if dist(number(n.x), number(n.z), number(hx), number(hz)) < 220.0 {
      if held("e") { talking = i }
    }
    i = i + 1
  }

  if held("q") { advanceQuest(0) }
  if held("p") { saveGame() }

  move3d hero, number(hx), 0, number(hz)
  camera3d number(hx), 280, number(hz - 440.0), 1800, 0 - 120

  render3d
  drawQuests()
  drawBag()
  drawTalk()
  write "WASD move   E talk   Q progress quest   P save" at 240, 258 color "#55657a" centered
}
