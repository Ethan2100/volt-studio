const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { doc, w } = k;
(async () => {
  await k.sleep(60);
  await k.click('[data-act="nav:languages"]');
  k.check('13 language cards', doc.querySelectorAll('.grid .card').length === 13);
  k.check('no compare/schedule before choosing', !/Compare progress/.test(k.text()));
  k.check('courses honestly marked: 5 available, 8 not written', (k.text().match(/Course available/g) || []).length === 5 && (k.text().match(/Course not written yet/g) || []).length === 8);
  await k.click('[data-act="lang:toggle"][data-arg="de"]');
  await k.click('[data-act="lang:toggle"][data-arg="fr"]');
  k.check('start studying toggles on (2 active)', w.localStorage.getItem('pg:s:langs') === 'de,fr' && /2 of 13 active/.test(k.text()));
  k.check('compare table + schedule appear', /Compare progress/.test(k.text()) && /Weekly schedule/.test(k.text()) && doc.querySelectorAll('.tbl tbody tr').length === 2);
  k.check('card button flips to Stop studying', !!doc.querySelector('[data-act="lang:toggle"][data-arg="de"].ghost'));
  // schedule: de Mon-Wed only, fr Thu-Sun
  for (const i of [3, 4, 5, 6]) await k.click(`[data-act="set:day"][data-arg="de:${i}"]`);
  for (const i of [0, 1, 2]) await k.click(`[data-act="set:day"][data-arg="fr:${i}"]`);
  k.check('different days per language', w.localStorage.getItem('pg:s:days:de') === '1110000' && w.localStorage.getItem('pg:s:days:fr') === '0001111', w.localStorage.getItem('pg:s:days:de') + ' ' + w.localStorage.getItem('pg:s:days:fr'));
  const today = await k.run('return await weekdayIndex()');
  const deToday = '1110000'[today] === '1', frToday = '0001111'[today] === '1';
  await k.click('[data-act="nav:dashboard"]');
  k.check('dashboard honours the schedule (only the scheduled language asks for a goal)', doc.querySelector('.grid').querySelectorAll('.ring').length === (deToday ? 1 : 0) + (frToday ? 1 : 0), doc.querySelector('.grid').querySelectorAll('.ring').length);
  // compare table reflects progress
  await k.run('await addXp("de", 120); await addStudySeconds("de", 1500); await addXp("fr", 30);');
  await k.click('[data-act="nav:languages"]');
  const rows = [...doc.querySelectorAll('.tbl tbody tr')].map((r) => r.textContent);
  k.check('compare shows de ahead of fr', /German2/.test(rows[0]) && rows[0].includes('120') && rows[1].includes('30') && rows[0].includes('25 min'), rows.join(' | '));
  const bars = [...doc.querySelectorAll('.tbl tbody .bar i')].map((b) => b.getAttribute('style'));
  k.check('XP bars scale to the leader (100% vs 25%)', bars[0].includes('100%') && bars[1].includes('25%'), bars.join());
  // stop studying
  await k.click('[data-act="lang:toggle"][data-arg="de"]');
  k.check('stop studying removes it, keeps its progress', w.localStorage.getItem('pg:s:langs') === 'fr' && (await k.run('return await langXp("de")')) === 120);
  await k.click('[data-act="lang:toggle"][data-arg="fr"]');
  k.check('no active languages -> compare hidden again', !/Compare progress/.test(k.text()) && (await k.run('return await currentLang()')) === '');
  k.check('no errors', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
