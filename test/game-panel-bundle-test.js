// The packaged World Studio page must include its unified Game panel.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const builder = fs.readFileSync(path.join(root, 'plugins/world-studio', 'build.js'), 'utf8');
const panel = fs.readFileSync(path.join(root, 'plugins/world-studio', 'game-panel.js'), 'utf8');
const shell = fs.readFileSync(path.join(root, 'plugins/world-studio', 'src', 'shell.html'), 'utf8');
let failed = 0;
const check = (name, ok) => { if (!ok) failed++; console.log((ok ? 'pass' : 'FAIL') + '  ' + name); };
check('build script reads game-panel.js from plugin root', /readPanel\\('game-panel\\.js'\\)/.test(builder));
check('build script injects Game panel after the World Studio app', builder.indexOf('/*STUDIO*/') < builder.indexOf('/*GAME_PANEL*/'));
check('build output includes Game panel script before body close', /replace\\('</body>'/.test(builder));
check('Game panel exposes all authoring categories', ['abilities','items','equipment','npcs','quests','skills','aiGraphs','lootTables','stats','effects','saveFields','checkpoints','triggers','hud'].every(k => panel.includes(k)));
check('Game panel performs host data handshake', panel.includes("send('hello')") && panel.includes("send('getGameData'"));
check('Game panel exposes a visible toolbar entry', panel.includes("b.id='bGameData'") && panel.includes("b.textContent='✧ Game'"));
check('host bridge contract is present in World Studio shell', shell.includes('id="bSave"'));
console.log('\\n' + (7 - failed) + ' checks passed, ' + failed + ' failed');
process.exitCode = failed ? 1 : 0;
