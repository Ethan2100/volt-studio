// Shared test helpers for Polyglot (jsdom)
const { JSDOM } = require('jsdom');
const fs = require('fs');

function open(storage) {
  const html = fs.readFileSync(require('path').join(__dirname, '..', 'polyglot', 'index.html'), 'utf8');
  const dom = new JSDOM(html, {
    runScripts: 'dangerously', url: 'https://polyglot.test/', pretendToBeVisual: true,
    beforeParse(win) {
      win.scrollTo = () => {};
      if (storage) for (const k of Object.keys(storage)) win.localStorage.setItem(k, storage[k]);
    },
  });
  return dom;
}

function kit(dom) {
  const w = dom.window, doc = w.document;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const ev = (code) => w.eval(code);
  // Volt functions are async: run statements/expressions with await
  const run = async (code) => await w.eval('(async () => { ' + code + ' })()');
  const click = async (sel) => {
    const el = doc.querySelector(sel);
    if (!el) throw new Error('missing element: ' + sel + ' | route=' + ev('route'));
    el.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
    await sleep(20);
  };
  const text = () => doc.getElementById('volt').textContent;
  const errors = () => [...doc.querySelectorAll('.volt-error')].map((e) => e.textContent);
  let fails = 0, passes = 0;
  const check = (name, cond, extra) => {
    if (cond) { passes++; console.log('PASS ' + name); }
    else { fails++; console.log('FAIL ' + name + (extra !== undefined ? '  -> ' + extra : '')); }
  };
  const done = () => { console.log(`\n${passes} passed, ${fails} failed`); process.exit(fails ? 1 : 0); };
  return { w, doc, sleep, ev, run, click, text, errors, check, done };
}
module.exports = { open, kit };
