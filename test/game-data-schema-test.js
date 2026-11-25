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
check('game data writes use an atomic temporary file', main.includes("const temp = target + '.tmp'") && main.includes('fs.renameSync(temp, target)'));
console.log('\\n' + (keys.length * 2 + 3 - failed) + ' checks passed, ' + failed + ' failed');
process.exitCode = failed ? 1 : 0;
