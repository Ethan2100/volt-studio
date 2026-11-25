// Compile and execute the actual Volt RPG runtime, not a JavaScript mock.
const fs = require('fs');
const os = require('os');
const path = require('path');
const volt = require('../compiler/volt.js');
const { JSDOM } = require('jsdom');
let failed = 0;
const check = (name, ok) => { if (!ok) failed++; console.log((ok ? 'pass' : 'FAIL') + '  ' + name); };
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'volt-rpg-'));
for (const f of ['game.volt','combat.volt','rpg.volt']) {
  fs.copyFileSync(path.join(__dirname, '..', 'plugins', 'game-kit', f), path.join(dir, f));
}
const program = `#html
canvas 320, 180
import "game.volt"
import "combat.volt"
import "rpg.volt"
DEATH_SPARKS = false
fn say(label, got, want) {
  if got == want { print "ok " + label }
  else { print "FAIL " + label + " got " + got + " wanted " + want }
}
createQuest("goblin_trial", "Goblin Trial", 2, 80, "Gold", 3)
say("quest starts inactive", QUEST_STATE[0], 0)
say("quest can start", startQuest("goblin_trial"), true)
advanceQuest("goblin_trial", 1)
say("quest tracks partial progress", QUEST_PROGRESS[0], 1)
say("quest not complete early", questCompleted("goblin_trial"), false)
advanceQuest("goblin_trial", 1)
say("quest completes at goal", questCompleted("goblin_trial"), true)
say("quest reward can be claimed", claimQuest("goblin_trial"), true)
say("quest grants xp", PLAYER_XP, 80)
say("quest grants item", countOf("Gold"), 3)
defineSkill("arcane_bolt", 1, 50, "")
say("skill unlocks when affordable", unlockSkill("arcane_bolt"), true)
say("skill state persists in runtime", skillUnlocked("arcane_bolt"), true)
defineSkill("meteor", 2, 20, "arcane_bolt")
say("prerequisite blocks early unlock", unlockSkill("meteor"), false)
addXP(300)
say("xp levels up", PLAYER_LEVEL >= 2, true)
say("prerequisite skill unlocks", unlockSkill("meteor"), true)
let enemy = target("Bandit", 100, 40, -100, 60, 40)
let enemyModel = block3d(100, 40, -100, 40, 80, 40, "#6d9b55")
configureEnemyAI(enemy, enemyModel, 500, 80, 12, 180, 500, "aggressive")
say("enemy starts chasing", stepEnemyAI(enemy, 0, 0), "chase")
moveTarget(enemy, 30, 40, 0)
say("enemy attacks in range", stepEnemyAI(enemy, 0, 0), "attack")
say("enemy damages player", PLAYER_HP < 100, true)
addLoot("bandit", "Coin", 100, 2, 4, "#ffd23f")
say("loot table drops guaranteed item", rollLoot("bandit") >= 2, true)
say("loot goes into backpack", countOf("Coin") >= 2, true)
defineStatus("rage", "attack", 15, 1000)
applyDefinedStatus("rage")
say("status applies attack bonus", PLAYER_STATUS_ATTACK_BONUS, 15)
say("status is queryable", hasStatus("rage"), true)
removeStatus("rage")
say("status removal clears bonus", PLAYER_STATUS_ATTACK_BONUS, 0)
setCheckpoint(120, 30, -450)
PLAYER_X = 0
say("checkpoint restores player position", restoreCheckpoint(), true)
say("checkpoint x restored", PLAYER_X, 120)
addTrigger("shrine", 0, 0, 100, "heal", "25", true)
PLAYER_HP = 50
stepTriggers(0, 0)
say("trigger action executes", PLAYER_HP, 75)
say("one-shot trigger records fired", TRIGGER_FIRED[0], true)
saveRpgProgress()
PLAYER_XP = 0
loadRpgProgress()
say("progression saves and reloads xp", PLAYER_XP > 0, true)
print "DONE"
`;
let html;
try {
  html = volt.compile(program, { baseDir: dir }).code;
  check("RPG systems compile through the Volt compiler", true);
} catch (e) {
  check("RPG systems compile through the Volt compiler", false);
  console.error(e);
  fs.rmSync(dir, {recursive:true,force:true});
  process.exit(1);
}
const mock = (n) => { const m = new Map(); return new Proxy(function(){}, {
  get(t,k) { if(k===Symbol.toPrimitive||k==='valueOf') return ()=>0; if(k==='toString') return ()=>n; if(k==='then') return undefined; if(!m.has(k))m.set(k,mock(n+'.'+String(k))); return m.get(k); },
  set(t,k,v){m.set(k,v);return true}, has(){return true}, apply(){return mock(n+'()')}, construct(){return mock('new '+n)}
});};
const dom = new JSDOM(html,{runScripts:'dangerously',pretendToBeVisual:true,url:'https://volt.test/',beforeParse(w){
  w.THREE=mock('THREE');
  w.HTMLCanvasElement.prototype.getContext=()=>mock('ctx');
}});
setTimeout(()=>{
  const w=dom.window;
  const lines=[...w.document.querySelectorAll('.volt-line')].map(x=>x.textContent);
  const errors=[...w.document.querySelectorAll('.volt-error')].map(x=>x.textContent);
  check("RPG test program completes without runtime errors",errors.length===0&&lines.includes('DONE'));
  for(const line of lines){if(line.startsWith('ok '))check(line.slice(3),true);else if(line.startsWith('FAIL '))check(line.slice(5),false);}
  fs.rmSync(dir,{recursive:true,force:true});
  process.exitCode=failed?1:0;
},700);
