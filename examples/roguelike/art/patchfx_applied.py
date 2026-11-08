import re
p='yokai-descent.volt'
s=open(p,encoding='utf-8').read()
def rep(a,b,cnt=1):
    global s
    assert s.count(a)==cnt,(a,s.count(a))
    s=s.replace(a,b)
rep('image fxSheet = "../dungeon/fx.png"','image fxSheet = "../dungeon/fx.png"\nimage fxPic = "art/fx.png"')
spr=open('art/fx_sprites.txt').read().strip()+'\n'
rep('sprite fxSlash =',spr+'sprite fxSlash =')
rep('let tL = []','let tL = []\n// magic effects: kind 0 hit, 1 puff, 2 heart\nlet gX = []\nlet gY = []\nlet gK = []\nlet gT = []')
rep('fn popText(px, py, words, color) {','''fn addFx(kind, x, y) {
  add x to gX
  add y to gY
  add kind to gK
  add 0 to gT
}

fn popText(px, py, words, color) {''')
rep('  popText(cx, cy - 10, text(dmg), "#ffffff")\n','  popText(cx, cy - 10, text(dmg), "#ffffff")\n  addFx(0, cx, cy)\n')
rep('  burst(cx, cy, 12, "#ffb34a", 10)\n','  burst(cx, cy, 12, "#ffb34a", 10)\n  addFx(1, cx, cy)\n')
rep('        sound sndHeal volume 50\n','        sound sndHeal volume 50\n        addFx(2, pcx, pcy)\n')
rep('    popText(cx, cy - 10, "+HP", "#7ee787")\n','    popText(cx, cy - 10, "+HP", "#7ee787")\n    addFx(2, pcx, pcy)\n')
rep('  sound sndDash volume 60\n','  sound sndDash volume 60\n  addFx(1, hx / 10 + 5, hy / 10 + 8)\n')
rep('  tL = []\n  tC = []\n','  tL = []\n  tC = []\n  gX = []\n  gY = []\n  gK = []\n  gT = []\n')
rep('  let n = length(tX) - 1\n  while n >= 0 {\n    tL[n] -= 1','''  let g = length(gX) - 1
  while g >= 0 {
    gT[g] += 1
    if gT[g] >= 16 {
      remove gX[g]
      remove gY[g]
      remove gK[g]
      remove gT[g]
    }
    g -= 1
  }
  let n = length(tX) - 1
  while n >= 0 {
    tL[n] -= 1''')
rep('    draw fxCircle at cx - 32, by - 40 tint "#c77dff" alpha 40 scale 45 angle tick * 6 glow','    draw mRing at cx - 36, by - 44 frame tick / 4 tint "#c77dff" alpha 70 scale 50 glow')
rep('''  if atkT > 5 {
    let sx = pcx + aimX * 13
    let sy = hy / 10 + 4 + aimY * 13
    draw fxSlash at sx - 16, sy - 16 tint "#ffc2e0" angle slashAngle() alpha 80 scale 170 glow
  }''','''  if atkT > 1 {
    let sx = pcx + aimX * 13
    let sy = hy / 10 + 4 + aimY * 13
    draw mSlash at sx - 36, sy - 36 frame (12 - atkT) * 8 / 12 angle (1035 - slashAngle()) % 360 tint "#ffc2e0" alpha 90 scale 50 glow
  }''')
rep('fn drawParticles() {\n','''fn drawFx() {
  let i = 0
  while i < length(gX) {
    let f = gT[i] / 2
    if gK[i] == 0 {
      draw mHit at gX[i] - 36, gY[i] - 36 frame f tint "#ff9ad5" alpha 90 scale 50 glow
    } else if gK[i] == 1 {
      draw mPuff at gX[i] - 36, gY[i] - 36 frame f tint "#ffd9a0" alpha 70 scale 50 glow
    } else {
      draw mHeart at gX[i] - 36, gY[i] - 44 frame f tint "#ff9ab0" alpha 90 scale 50 glow
    }
    i += 1
  }
}

fn drawParticles() {
''')
rep('  drawShots()\n  drawParticles()','  drawShots()\n  drawFx()\n  drawParticles()')
open(p,'w',encoding='utf-8').write(s)
