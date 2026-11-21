#html
// Nine-slot hotbar demo for Volt's Game Kit / World Studio.
title "Volt Hotbar Demo"
canvas 320, 180
import "game.volt"

world3d "#101722" fog 1800 ambient 12 shadows
let Floor = block3d(0, -5, 0, 1200, 10, 1200, "#626b78")
let Crate = block3d(260, 55, -180, 110, 110, 110, "#8a603b")
clearSolids()
solid(0, 0, 600, 600, -10, 0)
solid(260, -180, 55, 55, 0, 110)
playerStart(0, 450, 0)

HOTBAR_ITEMS = ["SWORD", "POTION", "BOW", "TORCH", "", "", "", "", ""]
HOTBAR_COUNTS = [1, 5, 12, 1, 0, 0, 0, 0, 0]

let notice = "Press 1-9 to select a slot"
let useWasDown = false
every frame {
  playerStep()
  hotbarStep()
  let useDown = held("space")
  let usePressed = useDown and not useWasDown

  if usePressed and HOTBAR_SELECTED == 1 {
    notice = "SWORD selected"
  }
  if usePressed and HOTBAR_SELECTED == 2 and HOTBAR_COUNTS[1] > 0 {
    HOTBAR_COUNTS[1] -= 1
    notice = "Potion used"
  }
  if usePressed and HOTBAR_SELECTED == 3 {
    notice = "BOW selected"
  }
  useWasDown = useDown

  render3d
  hotbarDraw()
  write notice at 160, 12 color "#ffffff" centered shadow
  write "WASD move · 1-9 select · Space use demo item" at 160, 28 color "#aab8cc" centered
}
