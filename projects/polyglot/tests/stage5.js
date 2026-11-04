const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { doc, w } = k;
(async () => {
  await k.sleep(80);
  await k.run('await act("lang:toggle","es"); await act("lang:toggle","ar");');
  await k.click('[data-act="nav:paths"]');
  k.check('paths shows Spanish lessons', doc.querySelectorAll('.lessonrow').length === 5 && k.errors().length === 0, k.errors());
  await k.click('[data-act="lang:switch"][data-arg="ar"]');
  k.check('unwritten language says so honestly', /aren't written yet/.test(k.text()));
  await k.click('[data-act="lang:switch"][data-arg="es"]');

  await k.click('[data-act="go:lesson"][data-arg="es:es-a1-1"]');
  k.check('lesson opens in focus mode with intro', !!doc.querySelector('.focus') && /New words/.test(k.text()) && !doc.querySelector('.side'));
  await k.click('[data-act="ex:next"]');
  k.check('grammar page explains why', /Why “buenos días”/.test(k.text()));
  await k.click('[data-act="ex:next"]');

  let n = 0, wrongDone = false, kinds = new Set();
  while (!doc.querySelector('.stats') && n < 40) {
    n++;
    const kind = k.ev('qType[qi]') === 'ex' ? k.ev('sessEx[qRef[qi]].kind') : k.ev('qType[qi]');
    kinds.add(kind);
    const ans = k.ev('qType[qi]==="ex" ? sessEx[qRef[qi]].answer : ""');
    if (kind === 'choice' || kind === 'fill' || kind === 'listen' || kind === 'read') {
      const opts = k.ev('curOpts');
      const idx = [...opts].indexOf(ans);
      // answer the very first choice wrongly on purpose
      let pick = idx;
      if (!wrongDone && kind === 'choice') { pick = idx === 0 ? 1 : 0; wrongDone = true; }
      await k.click(`[data-act="ex:pick"][data-arg="${pick}"]`);
    } else if (kind === 'translate') {
      const inp = doc.getElementById('ans'); inp.value = ans;
      await k.click('[data-act="ex:check"]');
    } else if (kind === 'arrange') {
      for (const piece of ans.split(' ')) { /* map to pool indices handled below */ }
      const pool = k.ev('pool'); const parts = [];
      // pieces may contain spaces ("por favor"), so greedy match on the pool
      let remaining = ans; const used = new Set();
      while (remaining.length) {
        let found = -1;
        for (let i = 0; i < pool.length; i++) if (!used.has(i) && (remaining === pool[i] || remaining.startsWith(pool[i] + ' '))) { found = i; break; }
        if (found < 0) throw new Error('cannot rebuild ' + ans);
        used.add(found); await k.click(`[data-act="ex:build"][data-arg="${found}"]`); remaining = remaining.slice(pool[found].length).trim();
      }
      await k.click('[data-act="ex:check"]');
    } else if (kind === 'match') {
      const left = k.ev('mLeft'), right = k.ev('mRight'), pairs = k.ev('sessEx[qRef[qi]].options');
      for (let i = 0; i < left.length; i++) {
        const want = pairs[i].split('=')[1]; await k.click(`[data-act="ex:mleft"][data-arg="${i}"]`);
        await k.click(`[data-act="ex:mright"][data-arg="${[...right].indexOf(want)}"]`);
      }
    } else if (kind === 'speak') {
      k.check('speak falls back to self-rating without a microphone', !!doc.querySelector('[data-act="ex:self"]'));
      await k.click('[data-act="ex:self"][data-arg="1"]');
    } else if (kind === 'convo') {
      while (k.ev('phase') === 'ask') {
        const steps = k.ev('cSteps'), st = k.ev('cStep'); const best = steps[st].split('|')[2];
        const opts = k.ev('cOpts'); await k.click(`[data-act="ex:pick"][data-arg="${[...opts].indexOf(best)}"]`);
      }
    }
    if (k.errors().length) { k.check('no errors during ' + kind, false, k.errors()); break; }
    k.check(`feedback shown after ${kind}`, !!doc.querySelector('.fbar .why'), kind);
    await k.click('[data-act="ex:next"]');
  }
  k.check('all exercise kinds played', ['choice','fill','translate','arrange','match','listen','speak','convo'].every(x => kinds.has(x)), [...kinds]);
  k.check('result screen reached', !!doc.querySelector('.stats') && /Session complete/.test(k.text()));
  const score = w.localStorage.getItem('pg:done:es:es-a1-1');
  k.check('lesson score saved (<100 because one wrong)', score !== null && Number(score) < 100 && Number(score) > 70, score);
  k.check('XP awarded', Number(w.localStorage.getItem('pg:xpt')) > 20, w.localStorage.getItem('pg:xpt'));
  k.check('first lesson achievement unlocked', w.localStorage.getItem('pg:ach:first') !== null);
  k.check('lesson words seeded into SRS', w.localStorage.getItem('pg:w:es:hola') !== null && w.localStorage.getItem('pg:w:es:gracias') !== null);
  k.check('activity logged', /Finished lesson/.test(w.localStorage.getItem('pg:log')));
  await k.click('[data-act="ex:close"]');
  k.check('back to app with sidebar', !!doc.querySelector('.side') && !doc.querySelector('.focus'));
  await k.click('[data-act="nav:paths"]');
  k.check('lesson 1 marked done, lesson 2 up next', /✓/.test(k.text()) && /Up next/.test(k.text()));

  // practice
  await k.click('[data-act="nav:practice"]');
  k.check('practice shows quick learn tiles', doc.querySelectorAll('[data-act="go:quick"]').length === 4);
  await k.click('[data-act="go:quick"][data-arg="es:5"]');
  k.check('quick learn starts', !!doc.querySelector('.focus') && k.ev('sessKind') === 'quick' && k.ev('qType.length') >= 4, k.ev('qType.length'));
  await k.click('[data-act="ex:leave"]'); await k.click('[data-act="ex:leaveyes"]');
  k.check('leaving closes the session', !doc.querySelector('.focus'));
  const today = await k.run('return await dayNum()');
  for (const wd of ['hola', 'gracias', 'adiós']) w.localStorage.setItem('pg:w:es:' + wd, '1|' + (today - 2) + '|0|1');
  await k.click('[data-act="nav:practice"]');
  k.check('review tile enabled with due words', !doc.querySelector('[data-act="go:review"]').disabled);
  await k.click('[data-act="go:review"][data-arg="es"]');
  k.check('review starts flashcards', k.ev('sessKind') === 'review' && !!doc.querySelector('.flash'), k.ev('sessKind'));
  await k.click('[data-act="ex:flip"]');
  await k.click('[data-act="ex:rate"][data-arg="2"]');
  k.check('rating moves to next card', k.ev('qi') === 1);
  await k.click('[data-act="ex:leave"]'); await k.click('[data-act="ex:leaveyes"]');
  await k.click('[data-act="nav:practice"]');
  await k.click('[data-act="go:challenge"][data-arg="es"]');
  k.check('challenge starts with a clock', !!doc.getElementById('clock') && k.ev('deadline') > 0);
  await k.run('deadline = (await nowMs()) - 1; await tickChallenge();');
  k.check('challenge ends when time is up', /points/.test(k.text()) && k.ev('sessStage') === 'result');
  await k.click('[data-act="ex:close"]');
  await k.click('[data-act="go:one"][data-arg="es:convo"]').catch(() => {});
  k.check('convo drill starts', k.ev('sessKind') === 'convo');
  k.check('no runtime errors', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
