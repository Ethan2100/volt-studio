// The VS Code extension. It can't be run without VS Code, so what is checked here is that the
// pieces are sound: the grammar matches the compiler's words, the manifest points at files that
// exist, and the extension's own code parses.
const fs = require('fs');
const path = require('path');

module.exports = (t) => {
  const dir = path.join(t.ROOT, 'vscode-volt');
  const read = (...p) => fs.readFileSync(path.join(dir, ...p), 'utf8');

  t.test('the manifest points at files that exist', () => {
    const manifest = JSON.parse(read('package.json'));
    t.assert.strictEqual(manifest.contributes.languages[0].id, 'volt');
    t.assert.deepStrictEqual(manifest.contributes.languages[0].extensions, ['.volt']);
    for (const file of [manifest.main, manifest.contributes.languages[0].configuration, manifest.contributes.grammars[0].path]) {
      t.assert.ok(fs.existsSync(path.join(dir, file)), `${file} is named in package.json but isn't there`);
    }
    JSON.parse(read('language-configuration.json'));
  });

  t.test('the extension and the server parse as JavaScript', () => {
    for (const file of [path.join(dir, 'extension.js'), path.join(t.ROOT, 'lsp', 'server.js'), path.join(dir, 'build-grammar.js')]) {
      // node strips a #! line when it loads a file; new Function doesn't, so take it off first
      const source = fs.readFileSync(file, 'utf8').replace(/^#![^\n]*\n/, '');
      // eslint-disable-next-line no-new-func
      new Function(source);
    }
  });

  t.test('the grammar is in step with the compiler', () => {
    const { build } = require(path.join(dir, 'build-grammar.js'));
    const committed = JSON.parse(read('syntaxes', 'volt.tmLanguage.json'));
    t.assert.deepStrictEqual(committed, build(),
      'the committed grammar is out of date - run: node vscode-volt/build-grammar.js');
  });

  t.test('every grammar pattern is a working regex that matches what it should', () => {
    const grammar = JSON.parse(read('syntaxes', 'volt.tmLanguage.json'));
    let patterns = 0;
    (function walk(node) {
      for (const [key, value] of Object.entries(node)) {
        if (['match', 'begin', 'end'].includes(key) && typeof value === 'string') { new RegExp(value); patterns++; }
        else if (value && typeof value === 'object') walk(value);
      }
    }(grammar));
    t.assert.ok(patterns >= 10, `only ${patterns} patterns`);

    const hits = (name, text) => new RegExp(grammar.repository[name].match).test(text);
    t.assert.ok(hits('target', '#html'), 'the first line');
    t.assert.ok(hits('keyword', 'continue'), 'a keyword added in Volt 4');
    t.assert.ok(hits('builtin', 'shuffle('), 'a built-in added in Volt 4');
    t.assert.ok(hits('command', '  player3d 0, 0, 0'), 'a command added in Volt 4');
    t.assert.ok(hits('number', '500ms'), 'a length of time');
    t.assert.ok(hits('comment', '// a note'), 'a comment');
    t.assert.ok(hits('type', 'Player = type {'), 'a type');
    t.assert.ok(!hits('target', '#nonsense'), 'not a real target');
  });

  t.test('the grammar knows every built-in the compiler has', () => {
    const volt = t.volt();
    const grammar = JSON.parse(read('syntaxes', 'volt.tmLanguage.json'));
    const builtins = new RegExp(grammar.repository.builtin.match);
    for (const name of Object.keys(volt.BUILTINS)) {
      t.assert.ok(builtins.test(`${name}(`), `'${name}' would not be coloured in VS Code`);
    }
  });
};
