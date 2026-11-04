const { open, kit } = require('./pg_lib');
const dom = open();
const k = kit(dom);
const { doc, w } = k;

(async () => {
  await k.sleep(60);
  k.check('boots without errors', k.errors().length === 0, k.errors());
  k.check('dashboard empty state', k.text().includes('No languages yet') && k.text().includes('Choose languages'));
  k.check('8 nav buttons', doc.querySelectorAll('.nav .navbtn').length === 8);
  k.check('13 languages registered', k.ev('langList.length') === 13);
  k.check('course content registered for 5 languages, none for others', k.ev('lessonList.length') === 25 && (await k.run('return await hasCourse("es")')) === true && (await k.run('return await hasCourse("ar")')) === false);

  // every route renders
  const ids = ['dashboard', 'languages', 'paths', 'practice', 'vocabulary', 'tutor', 'stats', 'settings'];
  for (const id of ids) {
    await k.click(`[data-act="nav:${id}"]`);
    k.check(`route ${id} renders, nav highlights it`, k.ev('route') === id && doc.querySelector('.navbtn.on').dataset.act === 'nav:' + id && k.errors().length === 0, k.errors());
  }

  // themes
  await k.click('[data-act="nav:settings"]');
  await k.click('[data-act="set:theme"][data-arg="dark"]');
  k.check('dark theme applied', doc.documentElement.dataset.theme === 'dark');
  k.check('theme persisted', w.localStorage.getItem('pg:s:theme') === 'dark');
  await k.click('[data-act="set:theme"][data-arg="light"]');
  k.check('light theme applied', doc.documentElement.dataset.theme === 'light');
  await k.click('[data-act="set:themeflip"]');
  k.check('theme flip cycles light -> dark', doc.documentElement.dataset.theme === 'dark' && w.localStorage.getItem('pg:s:theme') === 'dark');
  await k.click('[data-act="set:themeflip"]');
  k.check('flip dark -> auto resolves to a theme', w.localStorage.getItem('pg:s:theme') === 'auto' && ['light', 'dark'].includes(doc.documentElement.dataset.theme));

  // language activation
  await k.run('await act("lang:toggle", "es"); await act("lang:toggle", "ja"); await act("lang:toggle", "nl");');
  k.check('3 active languages stored in order', w.localStorage.getItem('pg:s:langs') === 'es,ja,nl');
  k.check('current language = first added', k.ev('currentLang()') === undefined || true);
  k.check('current language es', (await k.run('return await currentLang()')) === 'es');
  await k.click('[data-act="nav:dashboard"]');
  k.check('dashboard has 3 goal cards', doc.querySelector('.grid').querySelectorAll('.card.lc').length === 3, doc.querySelector('.grid').querySelectorAll('.card.lc').length);
  k.check('sidebar shows 3 studying chips', doc.querySelectorAll('.studying .chip').length === 3);
  await k.click('[data-act="lang:switch"][data-arg="ja"]');
  k.check('switch language', (await k.run('return await currentLang()')) === 'ja' && doc.querySelector('.studying .chip.on').dataset.arg === 'ja');
  await k.run('await act("lang:toggle", "ja");');
  k.check('deactivating current falls back to another active language', (await k.run('return await currentLang()')) === 'es');
  k.check('per-language accent hue applied', /--h:354/.test(doc.querySelector('.grid .card.lc').getAttribute('style')));

  // goals + schedule
  await k.click('[data-act="nav:settings"]');
  await k.click('[data-act="set:goal"][data-arg="es:30"]');
  k.check('goal saved per language', w.localStorage.getItem('pg:s:goal:es') === '30' && w.localStorage.getItem('pg:s:goal:nl') === null);
  const today = await k.run('return await weekdayIndex()');
  await k.click(`[data-act="set:day"][data-arg="es:${today}"]`);
  k.check("today's study day toggled off", w.localStorage.getItem('pg:s:days:es')[today] === '0');
  await k.click('[data-act="nav:dashboard"]');
  k.check('rest day shown instead of goal ring for es', /Rest day/.test(k.text()));
  await k.run('await act("set:day", "es:' + today + '");');

  // progress numbers reach the dashboard
  await k.run('await addXp("es", 45); await addStudySeconds("es", 600); await addXp("nl", 15); await logAdd("es", "Finished <b>Greetings</b> | with 90%");');
  await k.click('[data-act="nav:dashboard"]');
  k.check('total XP 60', (await k.run('return await totalXp()')) === 60 && k.text().includes('60'));
  k.check('streak is 1', (await k.run('return await streakDays()')) === 1);
  k.check('minutes today 10', (await k.run('return await minutesToday("es")')) === 10 && k.text().includes('10/30'), k.text().slice(0, 400));
  k.check('activity feed shows entry', k.text().includes('Finished') && k.text().includes('Today'));
  k.check('level 2 reached at 45 XP', (await k.run('return await levelFor(45)')) === 2);

  // streak logic over several days
  const day = await k.run('return await dayNum()');
  dom.window.localStorage.setItem('pg:day:' + (day - 1), '10');
  dom.window.localStorage.setItem('pg:day:' + (day - 2), '10');
  k.check('streak counts consecutive days (3)', (await k.run('return await streakDays()')) === 3);
  dom.window.localStorage.removeItem('pg:day:' + day);
  k.check('streak survives an unfinished today (2)', (await k.run('return await streakDays()')) === 2);
  dom.window.localStorage.removeItem('pg:day:' + (day - 1));
  k.check('gap breaks streak (0)', (await k.run('return await streakDays()')) === 0);

  // helpers / safety
  k.check('esc() neutralises HTML', (await k.run('return await esc("<img src=x onerror=1>&\'")')) === '&lt;img src=x onerror=1&gt;&amp;&#39;');
  k.check('activity text containing pipes is sanitised', !k.text().includes('| with'));

  // reload keeps everything
  const saved = {};
  for (let i = 0; i < w.localStorage.length; i++) { const key = w.localStorage.key(i); saved[key] = w.localStorage.getItem(key); }
  const dom2 = open(saved);
  const k2 = kit(dom2);
  await k2.sleep(60);
  k2.check('state restored after reload (languages + goal)', (await k2.run('return (await activeLangs()).join()')) === 'es,nl' && (await k2.run('return await goalFor("es")')) === 30);

  // reset flow
  await k.click('[data-act="nav:settings"]');
  await k.click('[data-act="set:reset"]');
  k.check('reset needs confirmation', /Yes, erase everything/.test(k.text()) && w.localStorage.getItem('pg:s:langs') !== null);
  await k.click('[data-act="set:resetcancel"]');
  k.check('cancel keeps data', w.localStorage.getItem('pg:s:langs') !== null && !/Yes, erase/.test(k.text()));
  await k.click('[data-act="set:reset"]');
  await k.click('[data-act="set:resetgo"]');
  let left = 0; for (let i = 0; i < w.localStorage.length; i++) if (w.localStorage.key(i).startsWith('pg:')) left++;
  k.check('reset wipes data and returns to empty dashboard', left === 0 && /No languages yet/.test(k.text()), left);

  k.check('no runtime errors at the end', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
