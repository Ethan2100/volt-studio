#html
// Test: edited Kenney models in Volt 3D
title "model test"
canvas 320, 180
world3d "#030308" fog 2600 ambient 8
model3d corr = "models/k_corridor.glb"
model3d cgate = "models/k_gate_door.glb"
model3d comp = "models/s_computer.glb"
model3d crate = "models/s_container.glb"
model3d hunter = "models/hunter.glb"

let t = 0
for i from 0 to 4 {
  let tile = put3d(corr, 0, 0, 0 - i * 400, 900, 100)
}
let g = put3d(cgate, 0, 0, 0 - 2000, 0, 100)
anim3d g, "open"
let c1 = put3d(comp, 120, 0, 0 - 600, 0 - 600, 160)
let b1 = put3d(crate, 0 - 110, 0, 0 - 1000, 300, 150)
let h = put3d(hunter, 0, 0, 0 - 1300, 1800, 100)
anim3d h, "walk"
let l1 = lamp3d(0, 330, 0 - 400, "#ffb347", 22, 900)
let l2 = lamp3d(0, 330, 0 - 1300, "#8a6bff", 25, 900)
torch3d 18, 1800

every frame {
  t = t + 1
  camera3d 0, 160, 150, 0, 0
  render3d
}
