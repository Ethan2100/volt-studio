#html
// Arcane Realms - explore moonlit ruins, fight the Warden, and master sword and staff.
title "Arcane Realms"
canvas 320, 180
import "game.volt"
import "characters.volt"

WALK_SPEED = 390
RUN_SPEED = 650
JUMP_POWER = 430
GRAVITY = 1350
EYE_HEIGHT = 165
HEAD_BOB = 0

import "Scripts/ArcaneController.volt"

// >>> world-studio  (World Studio writes this part - press "Save world" to update it)
import "Scripts/ArcaneController.volt"
world3d "#100c24" fog 3600 ambient 24 fov 72 shadows
model3d hero_model = "coworker_gold.glb"
model3d warden_model = "hunter.glb"
let Floor = block3d(0, -10, 0, 3600, 20, 3600, "#28223f")
let Path = block3d(0, 2, 500, 600, 16, 1900, "#51426d")
let Altar = cyl3d(0, 25, -260, 180, 50, "#463474")
let Crystal = ball3d(0, 175, -260, 54, "#8bdcff")
glow3d Crystal, "#61cfff"
let TowerL = cyl3d(-720, 170, -650, 90, 340, "#554a70")
let TowerR = cyl3d(720, 170, -650, 90, 340, "#554a70")
let RuneCyan = ball3d(-430, 90, -240, 40, "#5ef4ff")
let RuneViolet = ball3d(430, 90, -240, 40, "#c279ff")
glow3d RuneCyan, "#38e8ff"
glow3d RuneViolet, "#bb63ff"
let SwordGrip = cyl3d(0, 60, 0, 8, 90, "#59452f")
let SwordBlade = block3d(0, 130, 0, 14, 100, 8, "#d9eaff")
glow3d SwordBlade, "#81cfff"
let StaffShaft = cyl3d(0, 75, 0, 7, 140, "#77432e")
let StaffOrb = ball3d(0, 160, 0, 23, "#bc76ff")
glow3d StaffOrb, "#a451ff"
let Warden = put3d(warden_model, 0, 0, -920, 0, 115)
anim3d Warden, "idle"
let Hero = put3d(hero_model, 0, 0, 760, 0, 100)
anim3d Hero, "idle"
let MoonLamp = lamp3d(0, 360, -180, "#8d80ff", 85, 1700)
let GateLampL = lamp3d(-600, 220, 140, "#51dfff", 48, 1000)
let GateLampR = lamp3d(600, 220, 140, "#c06fff", 48, 1000)
fx3d 55, 22, 5
torch3d 22, 1200
clearSolids()
solid(0, 0, 1800, 1800, -20, 0)
solid(0, 500, 300, 950, 0, 16)
solid(0, -260, 180, 180, 0, 50)
solid(-720, -650, 45, 45, 0, 340)
solid(720, -650, 45, 45, 0, 340)
playerStart(0, 850, 0)
fn vfx_RunePulse() {
  magic3d 0, 85, -260, 360, "#71dcff", 1900
  shock3d 0, 20, -260, 480, "#986cff"
}
fn script_ArcaneInit() {
  arcaneSetup()
}
fn script_ArcaneController() {
  arcaneStep()
}
let ws_tick = 0
fn worldStart() {
  script_ArcaneInit()
}
fn worldStep() {
  ws_tick += 1
  if ws_tick % 150 == 0 { vfx_RunePulse() }
  script_ArcaneController()
}
// world-studio: {"v":1,"world":{"title":"Arcane Realms","bg":"#100c24","fog":3600,"ambient":24,"fov":72,"shadows":true,"sky":-1,"torch":22,"torchRange":1200,"bloom":55,"vignette":22,"grain":5},"objects":[{"kind":"block","name":"Floor","x":0,"y":-10,"z":0,"w":3600,"h":20,"d":3600,"color":"#28223f","solid":true},{"kind":"block","name":"Path","x":0,"y":2,"z":500,"w":600,"h":16,"d":1900,"color":"#51426d","solid":true},{"kind":"cyl","name":"Altar","x":0,"y":25,"z":-260,"r":180,"h":50,"color":"#463474","solid":true},{"kind":"ball","name":"Crystal","x":0,"y":175,"z":-260,"r":54,"color":"#8bdcff","glow":"#61cfff"},{"kind":"cyl","name":"TowerL","x":-720,"y":170,"z":-650,"r":90,"h":340,"color":"#554a70","solid":true},{"kind":"cyl","name":"TowerR","x":720,"y":170,"z":-650,"r":90,"h":340,"color":"#554a70","solid":true},{"kind":"ball","name":"Rune Cyan","x":-430,"y":90,"z":-240,"r":40,"color":"#5ef4ff","glow":"#38e8ff"},{"kind":"ball","name":"Rune Violet","x":430,"y":90,"z":-240,"r":40,"color":"#c279ff","glow":"#bb63ff"},{"kind":"cyl","name":"SwordGrip","x":0,"y":60,"z":0,"r":8,"h":90,"color":"#59452f"},{"kind":"block","name":"SwordBlade","x":0,"y":130,"z":0,"w":14,"h":100,"d":8,"color":"#d9eaff","glow":"#81cfff"},{"kind":"cyl","name":"StaffShaft","x":0,"y":75,"z":0,"r":7,"h":140,"color":"#77432e"},{"kind":"ball","name":"StaffOrb","x":0,"y":160,"z":0,"r":23,"color":"#bc76ff","glow":"#a451ff"},{"kind":"char","name":"Warden","x":0,"y":0,"z":-920,"file":"hunter","scale":115,"anim":"idle","solid":true},{"kind":"char","name":"Hero","x":0,"y":0,"z":760,"file":"coworker_gold","scale":100,"anim":"idle","solid":true},{"kind":"lamp","name":"MoonLamp","x":0,"y":360,"z":-180,"color":"#8d80ff","power":85,"range":1700},{"kind":"lamp","name":"GateLampL","x":-600,"y":220,"z":140,"color":"#51dfff","power":48,"range":1000},{"kind":"lamp","name":"GateLampR","x":600,"y":220,"z":140,"color":"#c06fff","power":48,"range":1000},{"kind":"vfx","name":"Rune Pulse","effect":"magic","when":"frame","rate":150,"x":0,"y":85,"z":-260,"color":"#71dcff","size":360,"ms":1900},{"kind":"script","name":"ArcaneInit","when":"start","file":"Scripts/ArcaneController.volt","fn":"arcaneSetup"},{"kind":"script","name":"ArcaneController","when":"frame","file":"Scripts/ArcaneController.volt","fn":"arcaneStep"}]}
// <<< world-studio

worldStart()
every frame {
  playerStep()
  worldStep()
  render3d
  write "ARCANE REALMS" at 10, 10 shadow
  write "1 Sword  |  2 Staff" at 160, 148 centered shadow
  write "Q Slash  |  E Bolt  |  R Nova" at 160, 168 centered shadow
  write "Health " + text(heroHealth) + "  Mana " + text(heroMana) at 160, 18 centered shadow
  if wardenHealth > 0 { write "Warden " + text(wardenHealth) at 160, 36 centered shadow }
  else { write "Quest complete! Explore the ruins." at 160, 36 centered shadow }
}
