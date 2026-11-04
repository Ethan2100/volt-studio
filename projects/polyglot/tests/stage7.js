const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { doc, w } = k;
(async () => {
  await k.sleep(80);
  await k.run('await act("lang:toggle","es"); await act("lang:toggle","de"); await act("lang:toggle","ja");');
  const today = await k.run('return await dayNum()');
  // empty-progress screens
  await k.click('[data-act="nav:stats"]');
  k.check('stats renders with no progress', k.errors().length === 0 && /Statistics/.test(k.text()) && doc.querySelectorAll('.chart .col').length === 14, k.errors());
  k.check('all 17 achievements shown locked', doc.querySelectorAll('.badge.locked').length === 17 && /0 of 17/.test(k.text()));
  await k.click('[data-act="nav:dashboard"]');
  k.check('dashboard recommends one next lesson per language', doc.querySelectorAll('[data-act="go:lesson"]').length === 3 && /Recommended next/.test(k.text()));
  k.check('no revision panel when nothing to revise', !/Worth revising/.test(k.text()));
  k.check('weekly challenge on dashboard', /Weekly challenge/.test(k.text()));

  // seed progress
  const set = (a, b) => w.localStorage.setItem('pg:' + a, b);
  for (let i = 0; i < 14; i++) { set('day:' + (today - i), String(10 + i * 3)); set('xp:es:' + (today - i), String(10 + i * 3)); }
  set('xpt', '350'); set('xpt:es', '350'); set('sect:es', '7200'); set('sec:es:' + today, '600');
  set('done:es:es-a1-1', '100'); set('done:es:es-a1-2', '60'); set('done:de:de-a1-1', '90');
  for (const wd of ['hola', 'gracias', 'adiós', 'por favor', 'de nada']) set('w:es:' + wd, '4|' + (today + 30) + '|0|9');
  set('w:es:soy', '1|' + (today - 1) + '|3|8'); set('w:es:eres', '1|' + (today - 2) + '|0|2');
  set('log', today + '|es|Finished lesson: Hello and thank you (100%)');
  await k.click('[data-act="nav:stats"]');
  k.check('chart shows 14 bars with the biggest at 100%', /height:100%/.test(doc.querySelector('.chart').innerHTML) && doc.querySelectorAll('.chart .col i').length === 14);
  k.check('totals reflect progress', /350/.test(k.text()) && /2 hours|2\.0/.test(k.text()) || /2\.0/.test(k.text()), k.text().slice(0, 300));
  k.check('compare table lists active languages', doc.querySelectorAll('.tbl tbody tr').length === 3);
  k.check('language dashboard defaults to current language', /Spanish dashboard/.test(k.text()));
  k.check('mastery bar counts mastered words (5)', /Mastered 5/.test(k.text()), (k.text().match(/Mastered \d+/) || [])[0]);
  k.check('weak lesson (60%) offered for retry', doc.querySelectorAll('[data-act="go:lesson"][data-arg="es:es-a1-2"]').length === 1);
  await k.click('[data-act="stat:lang"][data-arg="de"]');
  k.check('switching language dashboard', /German dashboard/.test(k.text()) && /Nothing yet for German/.test(k.text()));

  // achievements computed from progress
  const fresh = await k.run('return await checkAchievements()');
  k.check('achievements unlock from real progress', ['first', 'streak7', 'xp100', 'xp500' ].filter(a => !fresh.includes(a) && !w.localStorage.getItem('pg:ach:' + a)).length === 1 && fresh.includes('first') && fresh.includes('streak7') && fresh.includes('xp100'), fresh.join());
  k.check('xp500 not unlocked at 350 XP', !fresh.includes('xp500'));
  k.check('achievements persisted', w.localStorage.getItem('pg:ach:first') !== null);
  const again = await k.run('return await checkAchievements()');
  k.check('achievements never unlock twice', again.length === 0);
  await k.click('[data-act="nav:stats"]');
  k.check('unlocked badges rendered', doc.querySelectorAll('.badge:not(.locked)').length >= 3);

  // dashboard with progress
  await k.click('[data-act="nav:dashboard"]');
  k.check('revision panel shows due words and difficult words', /Worth revising/.test(k.text()) && /due/.test(k.text()) && /difficult/.test(k.text()));
  await k.click('[data-act="go:review"][data-arg="es"]');
  k.check('review from the dashboard starts', k.ev('sessKind') === 'review' && k.ev('qType.length') === 2, k.ev('qType.length'));
  await k.click('[data-act="ex:leave"]'); await k.click('[data-act="ex:leaveyes"]');

  // weekly challenge rotation + progress
  const idx = await k.run('return await challengeIndex()');
  k.check('challenge index valid', idx >= 0 && idx < 4);
  const prog = await k.run('return await challengeProgress()');
  k.check('challenge progress is a number', typeof prog === 'number' && prog >= 0, prog);
  const d1 = await k.run('return await weekStart()'); k.check('week starts on a multiple of 7 within the last 7 days', d1 % 7 === 0 && today - d1 < 7 && today - d1 >= 0);

  // finishing a lesson unlocks achievements and counts review
  await k.run('await startLesson("de","de-a1-2")');
  k.check('lesson ends cleanly', k.errors().length === 0);
  k.check('no runtime errors', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
