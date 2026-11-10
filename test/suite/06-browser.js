// #html programs, run for real in headless Chrome (WebGL through SwiftShader).
// These tests skip themselves when 'playwright' or Chrome isn't installed.
// The 3D tests step the game by calling the runtime directly, so they don't depend on frame rate.
const fs = require('fs');
const path = require('path');

module.exports = (t) => {
  const volt = t.volt();
  const ROOM = [
    '#html', 'canvas 320, 180', 'world3d "#000" ambient 30',
    'let floor = block3d(0, -10, 0, 2000, 20, 2000, "#666")',
    'let wall = block3d(0, 100, -300, 600, 200, 20, "#777")',
    'let stair = block3d(300, 12, 0, 100, 24, 100, "#886")',
    'let tall = block3d(-300, 60, 0, 100, 120, 100, "#868")',
    'let ball = ball3d(0, 300, 300, 20, "#f00")',
    'player3d 0, 0, 0',
  ].join('\n');
  // Hold some keys and step the player n times; returns where it ends up
  const walk = (page, keys, n, setup = '') => page.evaluate(([keys, n, setup]) => {
    // eslint-disable-next-line no-eval
    if (setup) (0, eval)(setup);
    __down.clear(); keys.forEach((k) => __down.add(k));
    for (let i = 0; i < n; i++) __walk3d();
    __down.clear();
    return { x: Math.round(__pl3.x), y: Math.round(__pl3.y), z: Math.round(__pl3.z), ground: __pl3.ground };
  }, [keys, n, setup]);

  t.test('page: text, interpolation, structs and the standard library in #html', () => t.page(volt, [
    '#html', 'Hero = type { name: string, hp: int }', 'let h = Hero { name: "Finn", hp: 7 }',
    'let total = 0', 'for each n, i in [5, 6] { total += n * i }',
    'match h.name { "Finn" { print "{h.name} has {h.hp} HP, total {total}" } else { print "?" } }',
    'print join(sort([3, 1, 2]), "-") + " " + round(2.5)',
  ].join('\n'), async (page) => {
    const lines = await page.evaluate(() => Array.from(document.querySelectorAll('.volt-line')).map((e) => e.textContent));
    t.assert.deepStrictEqual(lines, ['Finn has 7 HP, total 6', '1-2-3 3']);
  }));

  t.test('page: player3d stands on the floor and walks forward', () => t.page(volt, ROOM, async (page) => {
    const rest = await walk(page, [], 30);
    t.assert.deepStrictEqual(rest, { x: 0, y: 0, z: 0, ground: true });
    const moved = await walk(page, ['w'], 30);            // half a second at 380 cm/s, facing -z
    t.assert.deepStrictEqual(moved, { x: 0, y: 0, z: -190, ground: true });
  }));

  t.test('page: a wall stops the player, and the player slides along it', () => t.page(volt, ROOM, async (page) => {
    const hit = await walk(page, ['w'], 240);
    t.assert.ok(hit.z <= -260 && hit.z >= -262, `stops 28 cm (its radius) in front of the wall face at z = -290, got ${hit.z}`);
    const slide = await walk(page, ['w', 'd'], 30);
    t.assert.ok(slide.z <= -260 && slide.z >= -262);
    t.assert.ok(slide.x > 100, 'still moves sideways while pushing into the wall');
  }));

  t.test('page: low steps are climbed, tall blocks are not, and Space jumps', () => t.page(volt, ROOM, async (page) => {
    const up = await walk(page, ['d'], 60);
    t.assert.deepStrictEqual([up.y, up.ground, up.x > 250], [24, true, true], 'stepped onto the 24 cm stair');
    const blocked = await walk(page, ['a'], 240, '__player3d(0, 0, 0)');
    t.assert.ok(blocked.x >= -222 && blocked.x <= -220 && blocked.y === 0, `the 120 cm block is a wall, got ${blocked.x}`);
    const air = await walk(page, [' '], 10, '__player3d(0, 0, 200)');
    t.assert.ok(air.y > 40 && !air.ground, 'in the air after jumping');
    const down = await walk(page, [], 120);
    t.assert.deepStrictEqual([down.y, down.ground], [0, true], 'lands again');
  }));

  t.test('page: solid3d false lets the player through; models are not solid by default', () => t.page(volt, ROOM, async (page) => {
    const through = await walk(page, ['w'], 240, '__solid3d(1, false)');
    t.assert.ok(through.z < -400, 'walked through the wall');
  }));

  t.test('page: aim3d, ray3d, hitdist and touching3d', () => t.page(volt, ROOM, async (page) => {
    const r = await page.evaluate(() => {
      __walk3d();
      const ahead = __aim3d(1000), d = Math.round(__hitdist());
      const short = __aim3d(100);
      const down = __ray3d(0, 500, 0, 0, -900, 2000), dd = Math.round(__hitdist());
      const up = __ray3d(0, 100, 300, 0, 900, 2000);
      return { ahead, d, short, down, dd, up, t1: __touching3d(0, 1), t2: __touching3d(1, 4) };
    });
    t.assert.deepStrictEqual(r, { ahead: 1, d: 290, short: -1, down: 0, dd: 500, up: 4, t1: true, t2: false });
  }));

  t.test('page: scale3d, tilt3d, color3d, attach3d and remove3d', () => t.page(volt, ROOM, async (page) => {
    const r = await page.evaluate(() => {
      __scale3d(3, 100, 200, 100);
      const tallBox = __box3(__objs3[3]).map(Math.round);
      __color3d(3, '#00ff00');
      const colour = __objs3[3].mesh.material.color.getHexString();
      __attach3d(4, 3); __move3d(3, 500, 60, 0);
      const ballBox = __box3(__objs3[4]).map(Math.round);
      __tilt3d(2, 0, 450);
      const tilt = Math.round(__objs3[2].mesh.rotation.z * 1000);
      __remove3d(3);
      let gone = ''; try { __move3d(4, 0, 0, 0); } catch (e) { gone = e.message; }
      return { tallBox, colour, ballBox, tilt, gone, inScene: __sc3.children.filter((c) => c.isMesh).length };
    });
    t.assert.deepStrictEqual(r.tallBox, [-350, -60, -50, -250, 180, 50]);
    t.assert.strictEqual(r.colour, '00ff00');
    t.assert.deepStrictEqual(r.ballBox.slice(0, 2), [780, 280], 'the ball moved with what it is attached to');
    t.assert.strictEqual(r.tilt, 785);
    t.assert.strictEqual(r.gone, 'There is no 3D object number 4', 'removing a parent removes what is attached');
    t.assert.strictEqual(r.inScene, 3);
  }));

  t.test('page: freeze3d joins blocks into one draw call per colour and keeps them solid', () => t.page(volt, [
    '#html', 'canvas 320, 180', 'world3d "#000" ambient 30',
    'block3d(0, -10, 0, 4000, 20, 4000, "#666")',
    'for i from 0 to 199 { block3d(i * 10 - 1000, 100, -300, 10, 200, 20, "#777") }',
    'for i from 0 to 99 { block3d(i * 10 - 500, 100, 600, 10, 200, 20, "#555") }',
    'camera3d 0, 170, 0, 0, 0',
    'render3d',
    'let before = 0',
    '# before = __r3.info.render.calls;',
    'freeze3d',
    'render3d',
    'let after = 0',
    '# after = __r3.info.render.calls;',
    'print "{before} {after}"',
    'player3d 0, 0, 0',
  ].join('\n'), async (page) => {
    const text = await page.evaluate(() => document.querySelector('.volt-line').textContent);
    const [before, after] = text.split(' ').map(Number);
    t.assert.ok(before >= 100, `expected over a hundred draw calls before freezing, got ${before}`);
    t.assert.ok(after <= 3, `expected a handful of draw calls after freezing, got ${after}`);
    const hit = await walk(page, ['w'], 240);
    t.assert.ok(hit.z <= -260 && hit.z >= -262, 'frozen walls still stop the player');
    const err = await page.evaluate(() => { try { __move3d(5, 0, 0, 0); return ''; } catch (e) { return e.message; } });
    t.assert.ok(/joined into the level by freeze3d/.test(err), err);
  }));

  t.test('page: ao3d and fx3d render with no shader errors', () => t.page(volt, [
    '#html', 'canvas 320, 180', 'world3d "#8090a0" ambient 60 shadows',
    'block3d(0, -10, 0, 1000, 20, 1000, "#ccc")', 'block3d(0, 100, -200, 400, 200, 20, "#ddd")',
    'lamp3d(100, 300, 200, "#fff", 60, 1500)', 'ao3d 80', 'fx3d 50, 30, 5', 'camera3d 100, 150, 300, -150, -100',
    'every frame { render3d }',
  ].join('\n'), async (page) => {
    await page.waitForTimeout(600);
    const on = await page.evaluate(() => ({ ao: __fx3.mMix.uniforms.ao.value, fx: __fxOn3, tex: !!__fx3.mMix.uniforms.tAO.value }));
    t.assert.deepStrictEqual(on, { ao: 0.8, fx: true, tex: true });
    await page.evaluate(() => { __fx3d(0, 0, 0); });
    t.assert.strictEqual(await page.evaluate(() => __fxOn3), true, 'ao3d keeps the pipeline on when fx3d is switched off');
  }, { wait: 300 }));

  t.test('page: mouse and gamepad built-ins', () => t.page(volt, [
    '#html', 'canvas 320, 180', 'camera 100, 50',
    'every frame {', '  paint "#000"', '  if clicked() { print "click {mousex()} {mousey()} {mousedown()}" }', '  if pad("a") { print "never" }', '  let sx = padx() + pady2()', '}',
  ].join('\n'), async (page) => {
    await page.mouse.move(320, 180);
    await page.mouse.down();
    await page.waitForTimeout(250);
    await page.mouse.up();
    const lines = await page.evaluate(() => Array.from(document.querySelectorAll('.volt-line')).map((e) => e.textContent));
    t.assert.deepStrictEqual(lines, ['click 260 140 true'], 'the middle of a 320x180 screen, plus the camera offset');
  }));

  t.test('page: sound ... at x, y, z compiles to a 3D sound', () => {
    const dir = path.join(t.ROOT, 'examples', 'dungeon');
    if (!fs.existsSync(path.join(dir, 'sounds'))) return 'skip';
    const file = fs.readdirSync(path.join(dir, 'sounds')).find((f) => /\.(mp3|ogg|wav)$/.test(f));
    const code = volt.compile(`#html\ncanvas 320, 180\nworld3d "#000"\naudio hit = "sounds/${file}"\nsound hit at 100, 0, 200 volume 50\nsound hit volume 20`, { baseDir: dir }).code;
    t.assert.ok(code.includes('__sound3d(hit, 100, 0, 200, 50);'));
    t.assert.ok(code.includes('__sound(hit, 20);'));
  });

  // Older games must still start cleanly with the runtime as it is now
  for (const rel of ['examples/3d-test/showcase.volt', 'examples/21_html_struct_types.volt', 'examples/16_html_key_game.volt', 'examples/29_first_person_3d.volt', 'examples/roguelike/yokai-descent.volt']) {
    t.test(`page: ${rel} starts with no errors`, () => {
      const file = path.join(t.ROOT, rel);
      if (!fs.existsSync(file)) return 'skip';
      return t.page(volt, fs.readFileSync(file, 'utf8'), async (page) => { await page.waitForTimeout(700); }, { dir: path.dirname(file) });
    });
  }

  t.test('pages that do not use the new commands do not carry the new runtime', () => {
    const old = volt.compile('#html\ncanvas 320, 180\nworld3d "#000"\nlet b = block3d(0, 0, 0, 10, 10, 10, "#fff")\nevery frame { render3d }').code;
    t.assert.ok(!old.includes('__walk3d') && !old.includes('__mousex'));
    const neu = volt.compile('#html\ncanvas 320, 180\nworld3d "#000"\nplayer3d 0, 0, 0\nevery frame {\n  walk3d\n  render3d\n  let m = mousex()\n}').code;
    t.assert.ok(neu.includes('function __walk3d') && neu.includes('function __mousex'));
  });
};
