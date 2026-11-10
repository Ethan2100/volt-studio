// UI Studio: the panel that lays out a game HUD or a page's UI by dragging.
//
// The one thing that really matters is that whatever it writes is Volt that compiles, so these
// tests build layouts in the real panel (in a headless browser) and then compile what comes out
// with the real compiler. They skip when there's no browser to run the panel in.
const fs = require('fs');
const path = require('path');

module.exports = (t) => {
  const volt = t.volt();
  const panel = path.join(t.ROOT, 'plugins', 'ui-studio', 'index.html');
  const fixtures = path.join(t.ROOT, 'test', 'doc-fixtures');

  // opens the panel and hands it to fn(page); 'skip' when there's no browser
  const inPanel = async (fn) => {
    const b = await t.browser();
    if (!b) return 'skip';
    const page = await b.newPage({ viewport: { width: 1100, height: 720 } });
    const problems = [];
    page.on('pageerror', (e) => problems.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') problems.push(m.text()); });
    try {
      await page.goto(`file://${panel}`);
      await page.waitForTimeout(250);
      const out = await fn(page);
      t.assert.deepStrictEqual(problems, [], 'the panel reported errors');
      return out;
    } finally {
      await page.close();
    }
  };

  // a whole game around a HUD block, so the block is compiled where it will really live
  const inGame = (block) => ['#html', 'canvas 320, 180', 'image sheet = "tiles.png"',
    'sprite icon = sheet at 0, 0 size 16, 16', 'let hp = 7', 'let maxHp = 10', 'let score = 0',
    'let paused = false', 'every frame {', ...block.split('\n').map((l) => `  ${l}`), '}'].join('\n');

  const compiles = (program, what) => {
    const e = t.errorOf(volt, program, { baseDir: fixtures });
    if (e) throw new Error(`${what} did not compile: line ${e.line}: ${e.message}\n---\n${program}`);
  };

  t.test('the manifest is a valid panel plugin and the panel is one self-contained file', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(t.ROOT, 'plugins', 'ui-studio', 'plugin.json'), 'utf8'));
    t.assert.strictEqual(manifest.type, 'panel');
    t.assert.strictEqual(manifest.panel.entry, 'index.html');
    t.assert.ok(fs.existsSync(panel));
    // a panel runs in a sandbox, so it may not pull in any file beside it
    const html = fs.readFileSync(panel, 'utf8');
    t.assert.ok(!/<script[^>]+\bsrc=/.test(html), 'the panel loads an outside script, which a sandboxed panel cannot do');
    t.assert.ok(!/<link[^>]+\bhref=/.test(html), 'the panel loads an outside stylesheet, which a sandboxed panel cannot do');
    // the panel itself must be one page: no scripts, styles or images loaded beside it
    const shipped = fs.readdirSync(path.join(t.ROOT, 'plugins', 'ui-studio')).filter((f) => !/\.md$/i.test(f));
    t.assert.deepStrictEqual(shipped.sort(), ['index.html', 'plugin.json']);
  });

  t.test('a HUD with one of everything compiles inside a game', () => inPanel(async (page) => {
    const block = await page.evaluate(() => {
      UiStudio.state = { mode: 'hud', w: 320, h: 180, items: [], styles: {}, next: 1 };
      for (const kind of ['box', 'bar', 'text', 'button', 'sprite']) UiStudio.addItem(kind);
      return UiStudio.exportVolt();
    });
    compiles(inGame(block), 'the HUD block');
    t.assert.ok(block.includes('box '), block);
    t.assert.ok(block.includes('write '), block);
    t.assert.ok(block.includes('draw icon at'), block);
    t.assert.ok(block.includes('clicked()'), 'a button should react to a click');
  }));

  t.test('a page layout compiles as a whole page', () => inPanel(async (page) => {
    const block = await page.evaluate(() => {
      UiStudio.state = { mode: 'page', w: 320, h: 180, items: [], styles: { background: { color: '#10131a' }, text: { color: 'white', size: 20 } }, next: 1 };
      for (const kind of ['title', 'print', 'pagebutton', 'html']) UiStudio.addItem(kind);
      return UiStudio.exportVolt();
    });
    compiles(`#html\n${block}`, 'the page block');
    t.assert.ok(block.includes('background.color = "#10131a"'));
    t.assert.ok(block.includes('title "My page"'));
  }));

  t.test('text that people really type still comes out as valid Volt', () => inPanel(async (page) => {
    const awkward = [
      'He said "hi"', 'a \\ backslash', "Score: {score}", 'HP {hp}/{maxHp}', '100% done',
      'line\nbreak', '{not volt: text}', 'emoji ok', "it's fine", 'a{hp}c{score}e',
    ];
    const block = await page.evaluate((texts) => {
      UiStudio.state = { mode: 'hud', w: 320, h: 180, items: [], styles: {}, next: 1 };
      texts.forEach((text, i) => { const it = UiStudio.addItem('text'); it.text = text; it.x = 4; it.y = 4 + i * 10; });
      const b = UiStudio.addItem('button');
      b.label = 'Say "go"';
      b.action = 'print "pressed"';
      return UiStudio.exportVolt();
    }, awkward);
    compiles(inGame(block), 'a HUD with awkward text');
    // the text really does reach the finished page
    const { code } = volt.compile(inGame(block), { baseDir: fixtures });
    t.assert.ok(code.includes('100% done'), 'a percent sign survived');
    t.assert.ok(code.includes("it's fine"), 'an apostrophe survived');
  }));

  t.test('a layout saved into a file can be opened again, unchanged', () => inPanel(async (page) => {
    const same = await page.evaluate(() => {
      UiStudio.state = { mode: 'hud', w: 256, h: 144, items: [], styles: {}, next: 1 };
      const bar = UiStudio.addItem('bar');
      bar.x = 6; bar.y = 6; bar.w = 70; bar.value = 'energy';
      const label = UiStudio.addItem('text');
      label.text = 'Floor {floor}'; label.centered = true;
      const before = JSON.stringify(UiStudio.state.items);
      // write it into a file, then read it back the way "Load from file" does
      const file = UiStudio.applyToSource('#html\ncanvas 256, 144\nevery frame {\n  render3d\n}\n', UiStudio.exportVolt());
      const back = UiStudio.loadFromSource(file);
      return { ok: back.ok, before, after: JSON.stringify(back.state.items), w: back.state.w, mode: back.state.mode, file };
    });
    t.assert.strictEqual(same.ok, true);
    t.assert.strictEqual(same.after, same.before, 'the layout changed on the way out and back');
    t.assert.strictEqual(same.w, 256);
    t.assert.strictEqual(same.mode, 'hud');
  }));

  t.test('sending it twice replaces the block instead of stacking up copies', () => inPanel(async (page) => {
    const r = await page.evaluate(() => {
      UiStudio.state = { mode: 'page', w: 320, h: 180, items: [], styles: {}, next: 1 };
      UiStudio.addItem('title');
      const first = UiStudio.applyToSource('#html\nprint "before"\n', UiStudio.exportVolt());
      UiStudio.addItem('print');
      const second = UiStudio.applyToSource(first, UiStudio.exportVolt());
      return { first, second, blocks: (second.match(/---- UI Studio ----/g) || []).length };
    });
    t.assert.strictEqual(r.blocks, 1, 'there should only ever be one block');
    t.assert.ok(r.second.includes('print "before"'), 'the rest of the file is left alone');
    compiles(r.second, 'the file after two sends');
  }));

  t.test('a block written inside every frame keeps its indentation', () => inPanel(async (page) => {
    const file = await page.evaluate(() => {
      UiStudio.state = { mode: 'hud', w: 320, h: 180, items: [], styles: {}, next: 1 };
      UiStudio.addItem('box');
      const start = ['#html', 'canvas 320, 180', 'every frame {', '  // ---- UI Studio ----', '  // ui-studio: {"mode":"hud","w":320,"h":180,"items":[],"styles":{}}', '  // ---- end UI Studio ----', '  render3d', '}'].join('\n');
      return UiStudio.applyToSource(start, UiStudio.exportVolt());
    });
    for (const line of file.split('\n').filter((l) => /^\s*(box|\/\/ ---- )/.test(l))) {
      t.assert.ok(line.startsWith('  '), `this line lost its indentation: ${JSON.stringify(line)}`);
    }
    compiles(file, 'an indented block');
  }));

  t.test('it reads the screen size and the sprite names out of a file', () => inPanel(async (page) => {
    const r = await page.evaluate(() => {
      const source = '#html\ncanvas 480, 270\nimage sheet = "t.png"\nsprite hero = sheet at 0, 0 size 16, 16\nsprite coin = sheet at 16, 0 size 8, 8\n';
      return { size: UiStudio.canvasSizeOf(source), sprites: UiStudio.spritesOf(source), none: UiStudio.canvasSizeOf('#python\nprint 1') };
    });
    t.assert.deepStrictEqual(r.size, { w: 480, h: 270 });
    t.assert.deepStrictEqual(r.sprites, ['hero', 'coin']);
    t.assert.strictEqual(r.none, null);
  }));

  t.test('a file with no block, or a damaged one, says so instead of breaking', () => inPanel(async (page) => {
    const r = await page.evaluate(() => [
      UiStudio.loadFromSource('#html\nprint 1\n'),
      UiStudio.loadFromSource('// ---- UI Studio ----\nbox 1, 2, 3, 4 color "#fff"\n// ---- end UI Studio ----'),
      UiStudio.loadFromSource('// ---- UI Studio ----\n// ui-studio: {not json\n// ---- end UI Studio ----'),
    ]);
    t.assert.deepStrictEqual(r.map((x) => x.ok), [false, false, false]);
    for (const one of r) t.assert.ok(one.why && one.why.length > 10, 'each should explain itself');
  }));

  t.test('an empty layout still writes something that compiles', () => inPanel(async (page) => {
    const blocks = await page.evaluate(() => {
      UiStudio.state = { mode: 'hud', w: 320, h: 180, items: [], styles: {}, next: 1 };
      const hud = UiStudio.exportVolt();
      UiStudio.state = { mode: 'page', w: 320, h: 180, items: [], styles: {}, next: 1 };
      return { hud, page: UiStudio.exportVolt() };
    });
    compiles(inGame(blocks.hud), 'an empty HUD');
    compiles(`#html\n${blocks.page}`, 'an empty page');
  }));

  // The panel talks to Volt Studio only through postMessage (docs/PLUGINS.md). Here the test
  // plays the part of Volt Studio, so the panel's half of that conversation is really exercised:
  // it must say hello, ask for the file, and send back the whole file with its block in place.
  t.test('Load from file and Send to editor talk to the host correctly', async () => {
    const b = await t.browser();
    if (!b) return 'skip';
    const page = await b.newPage({ viewport: { width: 1100, height: 720 } });
    try {
      const existing = ['#html', 'canvas 480, 270', 'image sheet = "tiles.png"',
        'sprite hero = sheet at 0, 0 size 16, 16', 'let hp = 4', 'let maxHp = 10',
        'every frame {', '  render3d', '}'].join('\n');
      // A host page that holds the panel in an iframe and answers it the way Volt Studio does.
      // It has to be a real file: a browser won't load a file:// iframe into a page built in memory.
      const host = fs.mkdtempSync(path.join(require('os').tmpdir(), 'volt-ui-host-'));
      const hostPage = path.join(host, 'host.html');
      fs.writeFileSync(hostPage, `<!doctype html><meta charset="utf-8"><body>
        <iframe id="panel" src="file://${panel}" style="width:1080px;height:700px;border:0"></iframe>
        <script>
          window.sent = [];
          window.fileNow = ${JSON.stringify(existing)};
          addEventListener('message', (e) => {
            const d = e.data;
            if (!d || d.voltPanel !== 1) return;
            window.sent.push(d);
            const reply = (m) => e.source.postMessage(Object.assign({ voltHost: 1 }, m), '*');
            if (d.type === 'hello') reply({ type: 'hello' });
            if (d.type === 'getSource') reply({ type: 'source', req: d.req, source: window.fileNow });
            if (d.type === 'replace') window.fileNow = d.code;
          });
        <\/script></body>`);
      await page.goto(`file://${hostPage}`);
      await page.waitForTimeout(700);

      t.assert.ok(await page.evaluate(() => window.sent.some((m) => m.type === 'hello')), 'the panel should say hello');

      // Load from file: it should take the screen size and the sprite names from the file
      await page.frameLocator('#panel').locator('#load').click();
      await page.waitForTimeout(400);
      const after = await page.evaluate(() => window.sent.filter((m) => m.type === 'getSource').length);
      t.assert.ok(after >= 1, 'Load should ask the host for the file');
      const sizeBox = await page.frameLocator('#panel').locator('#cw').inputValue();
      t.assert.strictEqual(sizeBox, '480', 'it should take the screen width from the canvas line');

      // lay something out, then Send to editor
      await page.frameLocator('#panel').locator('text=+ Bar (health, mana)').click();
      await page.waitForTimeout(200);
      await page.frameLocator('#panel').locator('#send').click();
      await page.waitForTimeout(500);

      const file = await page.evaluate(() => window.fileNow);
      t.assert.ok(file.includes('// ---- UI Studio ----'), 'the block should be in the file now');
      t.assert.ok(file.startsWith('#html'), 'the rest of the file should be kept');
      t.assert.ok(file.includes('sprite hero'), 'the rest of the file should be kept');
      compiles(file, 'the file the panel sent back');

      // and sending again should not add a second block
      await page.frameLocator('#panel').locator('#send').click();
      await page.waitForTimeout(500);
      const twice = await page.evaluate(() => window.fileNow);
      t.assert.strictEqual((twice.match(/---- UI Studio ----/g) || []).length, 1);
    } finally {
      await page.close();
    }
  });

  t.test('it notices when something is off the screen', () => inPanel(async (page) => {
    const status = await page.evaluate(() => {
      UiStudio.state = { mode: 'hud', w: 320, h: 180, items: [], styles: {}, next: 1 };
      const box = UiStudio.addItem('box');
      box.x = 300; box.y = 170; box.w = 60; box.h = 40;
      UiStudio.draw();
      return document.getElementById('status').textContent;
    });
    t.assert.match(status, /off the screen/);
  }));
};
