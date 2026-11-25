// Keep the Electron project database and World Studio Game panel in sync.
// Run with: node test/game-data-schema-test.js
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const main = fs.readFileSync(path.join(root, 'main.js'), 'utf8');
const panel = fs.readFileSync(path.join(root, 'plugins/world-studio', 'game-panel.js'), 'utf8');
let failed = 0;
const check = (name, ok) => {
  if (!ok) failed++;
  console.log((ok ? 'pass' : 'FAIL') + '  ' + name);
};
const keys = ['abilities','items','equipment','npcs','quests','skills','aiGraphs','lootTables','stats','effects','saveFields','checkpoints','triggers','hud'];
for (const key of keys) {
  check('Electron default schema includes ' + key, main.includes(key + ':'));
  check('Game panel schema includes ' + key, panel.includes(key + ':'));
}
check('legacy enemy records migrate to NPC records', main.includes('stored.enemies') && main.includes('data.npcs = stored.enemies'));
check('old project data receives defaults without discarding saved values', main.includes('Object.assign({}, EMPTY_GAME_DATA, stored)'));
check('game data writes use an atomic temporary file', main.includes("temp = target + '.tmp'") && main.includes('fs.renameSync(temp, target)'));
const studio = fs.readFileSync(path.join(root, 'plugins', 'world-studio', 'src', 'studio.js'), 'utf8');
const runtime = fs.readFileSync(path.join(root, 'plugins', 'game-kit', 'rpg.volt'), 'utf8');
check('Game panel updates World Studio generator state immediately', panel.includes('setGameData(data)') && studio.includes('setGameData(data)'));
for (const [label, token] of [
  ['quest definitions generate runtime code', 'createQuest('],
  ['skill definitions generate runtime code', 'defineSkill('],
  ['enemy AI definitions generate runtime code', 'configureEnemyAI('],
  ['loot tables generate runtime code', 'addLoot('],
  ['status effects generate runtime code', 'defineStatus('],
  ['checkpoint and trigger definitions generate runtime code', 'addTrigger('],
  ['custom save fields use persistent runtime storage', 'saved('),
  ['generated NPCs execute enemy behaviour each frame', 'stepEnemyAI('],
  ['generated games restore progression on startup', 'loadRpgProgress()'],
]) check(label, studio.includes(token));
for (const [label, token] of [
  ['runtime supports quest completion and rewards', 'fn claimQuest('],
  ['runtime supports skill prerequisites', 'fn unlockSkill('],
  ['runtime moves visible enemy objects', 'move3d AI_VISUAL[i]'],
  ['runtime rolls loot into the backpack', 'fn rollLoot('],
  ['runtime expires timed status effects', 'fn stepRpg('],
  ['runtime persists checkpoint positions', 'fn restoreCheckpoint('],
  ['runtime handles proximity triggers', 'fn stepTriggers('],
]) check(label, runtime.includes(token));
console.log('\\n' + (keys.length * 2 + 3 - failed) + ' checks passed, ' + failed + ' failed');
process.exitCode = failed ? 1 : 0;
