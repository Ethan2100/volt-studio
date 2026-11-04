const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { doc, w } = k;
(async () => {
  await k.sleep(80);
  await k.run('await act("lang:toggle","es"); await act("lang:toggle","de");');
  await k.click('[data-act="nav:vocabulary"]');
  k.check('vocabulary lists 40 Spanish words', doc.querySelectorAll('.vocab .w').length === 40 && k.errors().length === 0, doc.querySelectorAll('.vocab .w').length + ' ' + k.errors());
  k.check('all words start as new, none due', /Nothing due/.test(k.text()) && doc.querySelectorAll('.vocab .w .chip').length >= 40);
  // search
  doc.getElementById('vq').value = 'leche'; await k.click('[data-act="vocab:search"]');
  k.check('search by word narrows the list', doc.querySelectorAll('.vocab .w').length === 1);
  doc.getElementById('vq').value = 'bread'; await k.click('[data-act="vocab:search"]');
  k.check('search by meaning works', doc.querySelectorAll('.vocab .w').length === 1 && /el pan/.test(k.text()));
  doc.getElementById('vq').value = 'zzzz'; await k.click('[data-act="vocab:search"]');
  k.check('empty search result message', /No words match/.test(k.text()));
  doc.getElementById('vq').value = ''; await k.click('[data-act="vocab:search"]');
  await k.click('[data-act="vocab:cat"][data-arg="family"]');
  k.check('category filter', doc.querySelectorAll('.vocab .w').length === 6, doc.querySelectorAll('.vocab .w').length);
  await k.click('[data-act="vocab:cat"][data-arg="family"]');
  // expand
  await k.click('[data-act="vocab:toggle"][data-arg="gracias"]');
  k.check('row expands with example', /Muchas gracias/.test(k.text()));

  // notebook validation + add + remove
  doc.getElementById('vw').value = '   '; doc.getElementById('vm').value = 'x';
  await k.click('[data-act="vocab:add"]');
  k.check('blank word rejected', /needed/.test(k.text()) && w.localStorage.getItem('pg:nb:es') === null);
  doc.getElementById('vw').value = 'a'.repeat(70); doc.getElementById('vm').value = 'long';
  await k.click('[data-act="vocab:add"]');
  k.check('overlong word rejected', /too long/.test(k.text()));
  doc.getElementById('vw').value = 'la playa | beach'; doc.getElementById('vm').value = 'the beach'; doc.getElementById('vn').value = 'Voy a la playa';
  await k.click('[data-act="vocab:add"]');
  k.check('notebook word saved, pipe sanitised', w.localStorage.getItem('pg:nb:es') === 'la playa / beach|the beach|Voy a la playa', w.localStorage.getItem('pg:nb:es'));
  k.check('notebook word appears and is in SRS', doc.querySelectorAll('.vocab .w').length === 41 && w.localStorage.getItem('pg:w:es:la playa / beach') !== null);
  doc.getElementById('vw').value = 'la playa / beach'; doc.getElementById('vm').value = 'dup';
  await k.click('[data-act="vocab:add"]');
  k.check('duplicate rejected', /already/.test(k.text()));
  await k.click('[data-act="vocab:toggle"][data-arg="la playa / beach"]');
  await k.click('[data-act="vocab:remove"][data-arg="la playa / beach"]');
  k.check('removing deletes entry and its SRS record', w.localStorage.getItem('pg:nb:es') === '' && w.localStorage.getItem('pg:w:es:la playa / beach') === null && doc.querySelectorAll('.vocab .w').length === 40);
  k.check('HTML in notebook is escaped', await (async () => { doc.getElementById('vw').value = '<b>x</b>'; doc.getElementById('vm').value = '<i>y</i>'; await k.click('[data-act="vocab:add"]'); return !doc.querySelector('.vocab b + b') && doc.querySelectorAll('.vocab i').length === 0; })());

  // SRS statuses and filters
  const today = await k.run('return await dayNum()');
  w.localStorage.setItem('pg:w:es:hola', '1|' + (today - 1) + '|0|2');
  w.localStorage.setItem('pg:w:es:gracias', '4|' + (today + 20) + '|0|6');
  w.localStorage.setItem('pg:w:es:adiós', '1|' + (today + 1) + '|3|5');
  await k.click('[data-act="nav:languages"]'); await k.click('[data-act="nav:vocabulary"]');
  await k.click('[data-act="vocab:filter"][data-arg="due"]');
  k.check('due filter shows only due word', doc.querySelectorAll('.vocab .w').length === 1 && /hola/.test(k.text()));
  await k.click('[data-act="vocab:filter"][data-arg="mastered"]');
  k.check('mastered filter', doc.querySelectorAll('.vocab .w').length === 1 && /gracias/.test(k.text()));
  await k.click('[data-act="vocab:filter"][data-arg="difficult"]');
  k.check('difficult filter (3 lapses, low box)', doc.querySelectorAll('.vocab .w').length === 1 && /adiós/.test(k.text()));
  await k.click('[data-act="vocab:filter"][data-arg="all"]');
  await k.click('[data-act="vocab:review"]');
  k.check('review from vocabulary starts flashcards with the due word', k.ev('sessKind') === 'review' && k.ev('qRef[0]') === 'hola');
  await k.click('[data-act="ex:flip"]'); await k.click('[data-act="ex:rate"][data-arg="3"]');
  k.check('session finished after the only card', /Session complete/.test(k.text()));
  const rec = w.localStorage.getItem('pg:w:es:hola').split('|').map(Number);
  k.check('easy grade moves word up a box and schedules it later', rec[0] > 1 && rec[1] > today, rec.join());
  await k.click('[data-act="ex:close"]');
  // forgetting
  await k.run('await srsGrade("es","gracias",0)');
  const r2 = w.localStorage.getItem('pg:w:es:gracias').split('|').map(Number);
  k.check('forgetting drops the box and records a lapse', r2[0] < 4 && r2[2] === 1, r2.join());
  // language isolation
  await k.click('[data-act="lang:switch"][data-arg="de"]');
  k.check('vocabulary is per language', doc.querySelectorAll('.vocab .w').length === 40 && /Hallo/.test(k.text()) && !/hola/.test(k.text()));
  k.check('no runtime errors', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
