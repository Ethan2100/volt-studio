const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { doc, w } = k;
async function playLesson(lang, lid) {
  await k.run(`await startLesson("${lang}", "${lid}")`);
  await k.click('[data-act="ex:next"]'); await k.click('[data-act="ex:next"]');
  let n = 0;
  while (!doc.querySelector('.stats') && n < 40) {
    n++;
    const kind = k.ev('sessEx[qRef[qi]].kind'); const ans = k.ev('sessEx[qRef[qi]].answer');
    if (['choice', 'fill', 'listen', 'read'].includes(kind)) {
      await k.click(`[data-act="ex:pick"][data-arg="${[...k.ev('curOpts')].indexOf(ans)}"]`);
    } else if (kind === 'translate') { doc.getElementById('ans').value = ans; await k.click('[data-act="ex:check"]'); }
    else if (kind === 'arrange') {
      const pool = k.ev('pool'); let remaining = ans; const used = new Set();
      while (remaining.length) { let f = -1; for (let i = 0; i < pool.length; i++) if (!used.has(i) && (remaining === pool[i] || remaining.startsWith(pool[i] + ' '))) { f = i; break; } if (f < 0) throw new Error('cannot rebuild ' + ans); used.add(f); await k.click(`[data-act="ex:build"][data-arg="${f}"]`); remaining = remaining.slice(pool[f].length).trim(); }
      await k.click('[data-act="ex:check"]');
    } else if (kind === 'match') {
      const right = k.ev('mRight'), pairs = k.ev('sessEx[qRef[qi]].options');
      for (let i = 0; i < pairs.length; i++) { await k.click(`[data-act="ex:mleft"][data-arg="${i}"]`); await k.click(`[data-act="ex:mright"][data-arg="${[...right].indexOf(pairs[i].split('=')[1])}"]`); }
    } else if (kind === 'speak') await k.click('[data-act="ex:self"][data-arg="1"]');
    else if (kind === 'convo') { while (k.ev('phase') === 'ask') { const st = k.ev('cStep'); const best = k.ev('cSteps')[st].split('|')[2]; await k.click(`[data-act="ex:pick"][data-arg="${[...k.ev('cOpts')].indexOf(best)}"]`); } }
    if (!doc.querySelector('.fbar.good')) return `${lang}/${lid}: ${kind} "${ans}" not accepted as correct`;
    await k.click('[data-act="ex:next"]');
  }
  const score = w.localStorage.getItem(`pg:done:${lang}:${lid}`);
  await k.click('[data-act="ex:close"]');
  return score === '100' ? null : `${lang}/${lid}: score ${score}`;
}
(async () => {
  await k.sleep(80);
  let bad = 0;
  for (const lang of ['es', 'de', 'fr', 'nl', 'ja']) {
    await k.run(`await act("lang:toggle","${lang}")`);
    for (let i = 1; i <= 5; i++) {
      const r = await playLesson(lang, `${lang}-a1-${i}`);
      if (r) { bad++; console.log('FAIL ' + r); }
      if (k.errors().length) { bad++; console.log('ERRORS', lang, i, k.errors()); }
    }
    console.log('played ' + lang);
  }
  // typed variants: romaji and accent-less
  const cases = [['ja', 'ありがとう', 'arigatou'], ['ja', 'さようなら', 'sayonara'], ['de', 'ich heiße anna', 'ich heisse anna'], ['fr', "je m'appelle anna", 'je mappelle anna'], ['es', 'por favor', 'POR FAVOR'], ['es', 'quiero agua', 'quiero  agua.']];
  for (const [lang, ans, guess] of cases) {
    const ex = JSON.parse(k.ev('JSON.stringify(exList)')).find(e => e.lang === lang && e.kind === 'translate' && e.answer === ans);
    if (!ex) { console.log('skip variant', ans); continue; }
    const ok = await k.run(`return await answerMatches(${JSON.stringify(guess)}, ${JSON.stringify(ex.answer)}, ${JSON.stringify(ex.extra)})`);
    k.check(`typed variant accepted: ${guess}`, ok === 1);
  }
  const wrong = await k.run('return await answerMatches("gracias", "por favor", "")');
  k.check('wrong answer rejected', wrong === 0);
  console.log(bad ? bad + ' failures' : 'ALL 25 LESSONS PLAY TO 100%');
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
