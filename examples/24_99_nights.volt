#html

// =====================================================================
// 99 Nights - a first-person 3D survival game written in Volt.
//
// Volt's own 2D canvas can't draw 3D, so the actual rendering is done by
// Three.js (loaded from a CDN at runtime) through Volt's raw-code escape
// hatch (the `#` lines below) - but all the GAME LOGIC (movement, the
// day/night cycle, gathering, building a fire, the night threat) is
// ordinary Volt: variables, `every frame`, `if`, `dist()`, `sin()`/`cos()`.
// Three.js only ever gets told where things are; it never decides
// anything.
//
// Click the screen to look around (pointer lock), WASD to walk, E to
// gather wood near a tree, F to build a fire once you have 5 wood.
// Survive the night - a fire keeps the thing in the dark away from you.
// =====================================================================

title "99 Nights"

## html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
## #world3d { position: fixed; inset: 0; z-index: 0; }
## #volt { position: fixed; top: 14px; left: 18px; z-index: 5; pointer-events: none; font-family: system-ui, sans-serif; text-shadow: 0 2px 6px rgba(0,0,0,0.9); }
## .volt-line { margin: 3px 0; font-size: 15px; }
## #lockhint { position: fixed; inset: 0; z-index: 10; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; color: #fff; font: 20px system-ui, sans-serif; background: rgba(0,0,0,0.45); cursor: pointer; text-align: center; text-shadow: 0 2px 6px rgba(0,0,0,0.8); pointer-events: auto; }
## #lockhint b { font-size: 30px; }

// ---------------------------------------------------------------------
// Game state - plain Volt variables. Everything that decides how the
// game plays lives here, not in the raw Three.js code below.
// ---------------------------------------------------------------------
let playerX = 0
let playerZ = 16
let yaw = 0
let pitch = 0
let started = false
let gameOver = false

let wood = 0
let hasFire = false
let night = 1
let dayTimer = 0.0
let dayLength = 24.0
let nightLength = 16.0
let isNight = false
let message = "Gather wood (E near a tree) and build a fire (F, needs 5 wood) before dark."
let lastMessage = ""

let monsterActive = false
let monsterX = 0
let monsterZ = 0

// 8 trees: fixed positions, each with its own "gathered yet" flag
// (Volt has no arrays-of-structs, so these are just plain variables)
let t1x = -10
let t1z = -8
let t1g = false
let t2x = 9
let t2z = -11
let t2g = false
let t3x = 14
let t3z = 4
let t3g = false
let t4x = -14
let t4z = 2
let t4g = false
let t5x = 2
let t5z = -16
let t5g = false
let t6x = -6
let t6z = 13
let t6g = false
let t7x = 16
let t7z = -2
let t7g = false
let t8x = -2
let t8z = 15
let t8g = false

// ---------------------------------------------------------------------
// Raw Three.js glue - presentation only. These functions are the only
// place that talks to THREE directly; gameplay never reaches in here.
// ---------------------------------------------------------------------
fn loadThree() {
  # return new Promise((resolve) => { if (window.THREE) { resolve(); return; } const s = document.createElement('script'); s.src = 'https://unpkg.com/three@0.158.0/build/three.min.js'; s.onload = resolve; document.body.appendChild(s); });
}

fn setupWorld() {
  # window.__T = { trees: [] };
  # const el = document.createElement('div'); el.id = 'world3d'; document.body.insertBefore(el, document.body.firstChild);
  # window.__T.renderer = new THREE.WebGLRenderer({ antialias: true }); window.__T.renderer.setSize(window.innerWidth, window.innerHeight); el.appendChild(window.__T.renderer.domElement);
  # window.__T.scene = new THREE.Scene(); window.__T.scene.background = new THREE.Color(0x8fd0ff);
  # window.__T.scene.fog = new THREE.Fog(0x8fd0ff, 18, 55);
  # window.__T.camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 200); window.__T.camera.rotation.order = 'YXZ';
  # window.__T.sun = new THREE.DirectionalLight(0xffffff, 1.1); window.__T.sun.position.set(20, 30, 10); window.__T.scene.add(window.__T.sun);
  # window.__T.amb = new THREE.AmbientLight(0x667788, 0.9); window.__T.scene.add(window.__T.amb);
  # { const g = new THREE.Mesh(new THREE.CircleGeometry(60, 48), new THREE.MeshLambertMaterial({ color: 0x3a7d3f })); g.rotation.x = -Math.PI / 2; window.__T.scene.add(g); }
  # window.addEventListener('resize', () => { window.__T.camera.aspect = window.innerWidth / window.innerHeight; window.__T.camera.updateProjectionMatrix(); window.__T.renderer.setSize(window.innerWidth, window.innerHeight); });
  # document.addEventListener('mousemove', (e) => { if (document.pointerLockElement) { yaw -= e.movementX * 0.12; pitch -= e.movementY * 0.12; if (pitch > 85) pitch = 85; if (pitch < -85) pitch = -85; } });
  # document.getElementById('world3d').addEventListener('click', () => document.getElementById('world3d').requestPointerLock());
}

fn addTreeMesh(x, z) {
  # const top = new THREE.Mesh(new THREE.ConeGeometry(1.15, 2.7, 7), new THREE.MeshLambertMaterial({ color: 0x2f6b3a })); top.position.set(x, 2.5, z);
  # const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.34, 1.6, 6), new THREE.MeshLambertMaterial({ color: 0x5a3b22 })); trunk.position.set(x, 0.8, z);
  # window.__T.scene.add(top); window.__T.scene.add(trunk); window.__T.trees.push({ top, trunk });
}

fn hideTree(i) {
  # window.__T.trees[i].top.visible = false; window.__T.trees[i].trunk.visible = false;
}

fn buildFireMesh() {
  # if (window.__T.fire) { window.__T.fire.visible = true; window.__T.fireLight.intensity = 1.6; return; }
  # window.__T.fire = new THREE.Mesh(new THREE.ConeGeometry(0.4, 0.9, 8), new THREE.MeshBasicMaterial({ color: 0xff7a1a })); window.__T.fire.position.set(playerX, 0.45, playerZ); window.__T.scene.add(window.__T.fire);
  # window.__T.fireLight = new THREE.PointLight(0xff8a3d, 1.6, 12); window.__T.fireLight.position.set(playerX, 1.2, playerZ); window.__T.scene.add(window.__T.fireLight);
}

fn putOutFireMesh() {
  # if (window.__T.fire) { window.__T.fire.visible = false; window.__T.fireLight.intensity = 0; }
}

fn spawnMonsterMesh() {
  # if (window.__T.monster) { window.__T.monster.visible = true; window.__T.monster.position.set(monsterX, 1, monsterZ); return; }
  # window.__T.monster = new THREE.Mesh(new THREE.ConeGeometry(0.9, 2.2, 5), new THREE.MeshBasicMaterial({ color: 0x1a0a0a })); window.__T.monster.position.set(monsterX, 1, monsterZ); window.__T.scene.add(window.__T.monster);
}

fn hideMonsterMesh() {
  # if (window.__T.monster) window.__T.monster.visible = false;
}

fn syncMonsterMesh() {
  # if (window.__T.monster) window.__T.monster.position.set(monsterX, 1, monsterZ);
}

fn renderWorld() {
  # window.__T.camera.position.set(playerX, 1.7, playerZ);
  # window.__T.camera.rotation.set(pitch * Math.PI / 180, yaw * Math.PI / 180, 0);
  # if (window.__T.fire && window.__T.fire.visible) { window.__T.fire.position.y = 0.45 + Math.sin(performance.now() / 90) * 0.06; }
  # window.__T.renderer.render(window.__T.scene, window.__T.camera);
}

fn setSkyNight(amount) {
  # const day = new THREE.Color(0x8fd0ff), night2 = new THREE.Color(0x0a0f22);
  # const c = day.clone().lerp(night2, amount);
  # window.__T.scene.background.copy(c); window.__T.scene.fog.color.copy(c);
  # window.__T.sun.intensity = 1.1 * (1 - amount) + 0.05 * amount;
  # window.__T.amb.intensity = 0.9 * (1 - amount) + 0.18 * amount;
}

// ---------------------------------------------------------------------
// One-time setup
// ---------------------------------------------------------------------
loadThree()
setupWorld()
addTreeMesh(t1x, t1z)
addTreeMesh(t2x, t2z)
addTreeMesh(t3x, t3z)
addTreeMesh(t4x, t4z)
addTreeMesh(t5x, t5z)
addTreeMesh(t6x, t6z)
addTreeMesh(t7x, t7z)
addTreeMesh(t8x, t8z)

html "<div id=\"lockhint\"><b>99 Nights</b><div>WASD to walk, mouse to look, E to gather wood, F to build a fire</div><div>Click to start</div></div>"
# document.getElementById('lockhint').addEventListener('click', () => { started = true; document.getElementById('lockhint').style.display = 'none'; document.getElementById('world3d').requestPointerLock(); });

when key "e" pressed {
  if not t1g and dist(playerX, playerZ, t1x, t1z) < 3 {
    t1g = true
    wood += 1
    hideTree(0)
  }
  if not t2g and dist(playerX, playerZ, t2x, t2z) < 3 {
    t2g = true
    wood += 1
    hideTree(1)
  }
  if not t3g and dist(playerX, playerZ, t3x, t3z) < 3 {
    t3g = true
    wood += 1
    hideTree(2)
  }
  if not t4g and dist(playerX, playerZ, t4x, t4z) < 3 {
    t4g = true
    wood += 1
    hideTree(3)
  }
  if not t5g and dist(playerX, playerZ, t5x, t5z) < 3 {
    t5g = true
    wood += 1
    hideTree(4)
  }
  if not t6g and dist(playerX, playerZ, t6x, t6z) < 3 {
    t6g = true
    wood += 1
    hideTree(5)
  }
  if not t7g and dist(playerX, playerZ, t7x, t7z) < 3 {
    t7g = true
    wood += 1
    hideTree(6)
  }
  if not t8g and dist(playerX, playerZ, t8x, t8z) < 3 {
    t8g = true
    wood += 1
    hideTree(7)
  }
}

when key "f" pressed {
  if wood >= 5 and not hasFire {
    wood -= 5
    hasFire = true
    buildFireMesh()
  }
}

// ---------------------------------------------------------------------
// Main loop - pure Volt. This is the whole game.
// ---------------------------------------------------------------------
every frame {
  if started and not gameOver {
    let fwdX = 0 - sin(yaw)
    let fwdZ = 0 - cos(yaw)
    let rightX = cos(yaw)
    let rightZ = 0 - sin(yaw)
    let moveF = 0
    let moveR = 0
    if held("w") {
      moveF += 1
    }
    if held("s") {
      moveF -= 1
    }
    if held("d") {
      moveR += 1
    }
    if held("a") {
      moveR -= 1
    }
    let speed = 0.12
    playerX += (fwdX * moveF + rightX * moveR) * speed
    playerZ += (fwdZ * moveF + rightZ * moveR) * speed
    playerX = constrain(playerX, -28, 28)
    playerZ = constrain(playerZ, -28, 28)

    dayTimer += 0.0167
    let cycle = dayLength + nightLength
    while dayTimer >= cycle {
      dayTimer -= cycle
    }
    let wasNight = isNight
    isNight = dayTimer >= dayLength

    let skyAmount = 0
    if isNight {
      let nightProgress = (dayTimer - dayLength) / nightLength
      skyAmount = min(1, nightProgress * 4)
    } else {
      skyAmount = max(0, 1 - (dayLength - dayTimer) * 4)
    }
    setSkyNight(skyAmount)

    // night just started
    if isNight and not wasNight {
      if hasFire {
        message = "The fire is keeping it away tonight."
      } else {
        monsterActive = true
        monsterX = playerX + 30
        monsterZ = playerZ + 30
        spawnMonsterMesh()
        message = "Something is out there. No fire to keep it back..."
      }
    }

    // day just started
    if not isNight and wasNight {
      night += 1
      hasFire = false
      putOutFireMesh()
      if monsterActive {
        monsterActive = false
        hideMonsterMesh()
      }
      message = "Night " + text(night - 1) + " survived. Gather wood before dark falls again."
    }

    if monsterActive {
      let mSpeed = 0.045
      monsterX += sign(playerX - monsterX) * mSpeed
      monsterZ += sign(playerZ - monsterZ) * mSpeed
      syncMonsterMesh()
      if dist(playerX, playerZ, monsterX, monsterZ) < 1.6 {
        gameOver = true
        message = "You were caught. You survived " + text(night - 1) + " of 99 nights."
      }
    }
  }

  renderWorld()

  let dayPart = " (day)"
  if isNight {
    dayPart = " (dark)"
  }
  let firePart = ""
  if hasFire {
    firePart = " | Fire: lit"
  }
  show "Night " + text(night) + dayPart + " | Wood: " + text(wood) + firePart
  if message != lastMessage {
    print message
    lastMessage = message
  }
}
