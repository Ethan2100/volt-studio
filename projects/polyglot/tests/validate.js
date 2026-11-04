// Content validator: structural rules for every lesson/word/exercise.
const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom);
(async () => {
  await k.sleep(80);
  const data = JSON.parse(k.ev('JSON.stringify({l:lessonList,w:wordList,e:exList,codes:langCodes})'));
  let bad = 0; const fail = (m) => { bad++; console.log('BAD ' + m); };
  const langs = [...new Set(data.l.map(x => x.lang))];
  console.log('languages with content:', langs.join(','));
  for (const lang of langs) {
    const ls = data.l.filter(x => x.lang === lang);
    if (ls.length < 5) fail(lang + ' has only ' + ls.length + ' lessons');
    for (const les of ls) {
      const ws = data.w.filter(x => x.lang === lang && x.lesson === les.lid);
      const es = data.e.filter(x => x.lang === lang && x.lesson === les.lid);
      const t = lang + '/' + les.lid;
      if (ws.length < 8) fail(t + ' words ' + ws.length);
      if (es.length < 10) fail(t + ' exercises ' + es.length);
      if (!les.points.length || les.points.some(p => p.split('|').length !== 2)) fail(t + ' bad grammar points');
      if (les.grammar.length < 200) fail(t + ' grammar too short');
      const kinds = new Set(es.map(x => x.kind));
      for (const need of ['choice', 'fill', 'translate', 'arrange', 'match', 'listen', 'speak']) if (!kinds.has(need)) fail(t + ' missing kind ' + need);
      for (const w of ws) { if (!w.word || !w.meaning || !w.example || !w.exampleEn) fail(t + ' word incomplete ' + w.word); }
      for (const e of es) {
        const id = t + ' [' + e.kind + '] ' + (e.stem || e.extra).slice(0, 30);
        if (!e.why) fail(id + ' no explanation');
        if (['choice', 'fill', 'listen', 'read'].includes(e.kind)) {
          if (!e.options.includes(e.answer)) fail(id + ' answer not in options');
          if (new Set(e.options).size !== e.options.length) fail(id + ' duplicate options');
          if (e.options.length < 2) fail(id + ' too few options');
        }
        if (e.kind === 'fill' && !e.stem.includes('___')) fail(id + ' fill without blank');
        if (e.kind === 'translate' && !e.answer) fail(id + ' translate no answer');
        if (e.kind === 'arrange') {
          const joined = e.answer.split(' ').length; 
          const pieces = e.options.join(' ').split(' ').sort().join(' ');
          const ans = e.answer.split(' ').sort().join(' ');
          if (pieces !== ans && lang !== 'ja') fail(id + ' pieces do not rebuild answer: ' + pieces + ' vs ' + ans);
        }
        if (e.kind === 'match') {
          if (e.options.length < 3 || e.options.some(o => o.split('=').length !== 2)) fail(id + ' bad pairs');
          const rights = e.options.map(o => o.split('=')[1]); if (new Set(rights).size !== rights.length) fail(id + ' dup right sides');
        }
        if (['listen', 'speak', 'read'].includes(e.kind) && !e.extra) fail(id + ' no text');
        if (e.kind === 'convo') {
          if (e.options.length < 2) fail(id + ' short convo');
          for (const s of e.options) { const b = s.split('|'); if (b.length !== 6 || b.some(x => !x)) fail(id + ' bad step: ' + s.slice(0, 40)); else if (new Set([b[2], b[3], b[4]]).size !== 3) fail(id + ' dup replies'); }
        }
      }
    }
  }
  console.log(bad ? bad + ' problems' : 'content OK: ' + data.l.length + ' lessons, ' + data.w.length + ' words, ' + data.e.length + ' exercises');
  process.exit(bad ? 1 : 0);
})();
