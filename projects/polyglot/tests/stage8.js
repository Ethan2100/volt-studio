const { open, kit } = require('./pg_lib');
let P=0,F=0;
const chk=(n,c,e)=>{ if(c){P++;console.log('PASS '+n);} else {F++;console.log('FAIL '+n+(e!==undefined?' -> '+e:''));} };
(async () => {
  const dom = open(); const k = kit(dom); const { doc, w } = k;
  await k.sleep(80);
  await k.run('await act("lang:toggle","es"); await addXp("es", 120); await srsSeed("es","hola"); await notebookAdd("es","la playa","the beach","nota"); await putSetting("theme","dark");');
  const dump = await k.run('return await kvExport()');
  const obj = JSON.parse(dump);
  chk('export is valid JSON with marker and data', obj.polyglot === 1 && obj.data['xpt'] === '120' && obj.data['s:theme'] === 'dark' && obj.data['nb:es'].startsWith('la playa'));
  await k.click('[data-act="nav:settings"]');
  chk('settings has export and import controls', !!doc.querySelector('[data-act="set:export"]') && !!doc.getElementById('bkfile'));
  let blobs = 0; w.URL.createObjectURL = () => { blobs++; return 'blob:x'; }; w.URL.revokeObjectURL = () => {};
  await k.click('[data-act="set:export"]');
  chk('export triggers a file download', blobs === 1 && /Backup saved/.test(k.text()));

  // restore into a brand-new browser
  const dom2 = open(); const k2 = kit(dom2); await k2.sleep(80);
  chk('new browser starts empty', /No languages yet/.test(k2.text()));
  await k2.run(`await act("set:import", ${JSON.stringify(dump)})`);
  chk('import restores progress, notebook, theme', (await k2.run('return await totalXp()')) === 120 && (await k2.run('return (await activeLangs()).join()')) === 'es' && dom2.window.localStorage.getItem('pg:nb:es').startsWith('la playa') && dom2.window.document.documentElement.dataset.theme === 'dark' && /Backup restored/.test(k2.text()));

  // invalid files change nothing
  const before = JSON.stringify(Object.assign({}, dom2.window.localStorage));
  const bad = ['not json', '{}', '{"polyglot":2,"data":{}}', '{"polyglot":1,"data":[]}', '{"polyglot":1,"data":{"a":5}}', '[1,2]', 'null', '{"polyglot":1,"data":{"' + 'k'.repeat(200) + '":"x"}}'];
  let rejected = 0;
  for (const b of bad) { await k2.run(`await act("set:import", ${JSON.stringify(b)})`); if (!/restored/.test(k2.text()) && JSON.stringify(Object.assign({}, dom2.window.localStorage)) === before) rejected++; }
  chk('all 8 invalid backups are rejected and data is untouched', rejected === bad.length, rejected);
  chk('error message shown to the person', /not a Polyglot backup|not valid JSON|does not recognise|too large/.test(k2.text()));

  // corrupted stored values must not crash the app
  const bad2 = { 'pg:s:langs': 'es,xx,,ja', 'pg:s:cur': 'zz', 'pg:s:goal:es': 'abc', 'pg:s:days:es': 'x', 'pg:xpt': 'NaN', 'pg:w:es:hola': 'garbage', 'pg:w:es:gracias': '9|x|-4|', 'pg:done:es:es-a1-1': 'oops', 'pg:log': 'x\n1|zz|broken\n||', 'pg:nb:es': '||\nlonely\nok|fine|', 'pg:day:5': 'zzz' };
  const dom3 = open(bad2); const k3 = kit(dom3); await k3.sleep(100);
  chk('app boots with corrupted data', k3.errors().length === 0 && !!dom3.window.document.querySelector('.app'), k3.errors());
  for (const r of ['dashboard', 'languages', 'paths', 'practice', 'vocabulary', 'stats', 'settings']) { await k3.click(`[data-act="nav:${r}"]`); if (k3.errors().length) { chk('survives corrupted data on ' + r, false, k3.errors()); break; } }
  chk('every screen renders with corrupted data', k3.errors().length === 0, k3.errors());
  await k3.run('await startLesson("es","es-a1-1")');
  chk('lesson still starts', !!dom3.window.document.querySelector('.focus') && k3.errors().length === 0, k3.errors());

  // blocked storage
  const dom4 = open(); const k4 = kit(dom4); await k4.sleep(60);
  dom4.window.Storage.prototype.setItem = () => { throw new Error('quota'); };
  await k4.run('await act("lang:toggle","es"); await addXp("es", 10);');
  await k4.click('[data-act="nav:dashboard"]');
  chk('failed saves show a warning instead of crashing', /blocking storage/.test(k4.text()) && k4.errors().length === 0, k4.errors());
  const imp = await k4.run('return await kvImport(' + JSON.stringify(dump) + ')');
  chk('import reports storage failure', /would not let/.test(imp), imp);
  console.log(`\n${P} passed, ${F} failed`); process.exit(F?1:0);
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
