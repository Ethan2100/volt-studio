const { open, kit } = require('./pg_lib');
const dom = open(); const k = kit(dom); const { w } = k;
(async () => {
  await k.sleep(50);
  const R = (c) => k.run(c);
  const d = await R('return await dayNum()');
  // intervals
  k.check('interval box1 = 1 day', (await R('return await srsInterval(1, 0)')) === 1);
  k.check('interval box3 = 7 days', (await R('return await srsInterval(3, 0)')) === 7);
  k.check('interval box5 = 35 days', (await R('return await srsInterval(5, 0)')) === 35);
  k.check('lapsing word gets a SHORTER interval (box3, 3 lapses -> 2d... < 7)', (await R('return await srsInterval(3, 3)')) < 7 && (await R('return await srsInterval(3, 3)')) >= 1, await R('return await srsInterval(3, 3)'));
  // seed + status
  k.check('unseen word is "new"', (await R('return await srsStatus("es","hola")')) === 'new');
  await R('await srsSeed("es","hola"); await srsSeed("es","hola");');
  k.check('seed: box1, due tomorrow, idempotent', JSON.stringify(await R('return await srsRec("es","hola")')) === JSON.stringify([1, d + 1, 0, 0]));
  k.check('not due today after seeding', (await R('return await dueCount("es")')) === 0);
  // good x4 climbs, due moves out
  await R('await srsGrade("es","hola",2); await srsGrade("es","hola",2); await srsGrade("es","hola",2);');
  let rec = await R('return await srsRec("es","hola")');
  k.check('3 goods -> box 4 (mastered), due ~16 days', rec[0] === 4 && rec[1] === d + 16 && rec[3] === 3 && (await R('return await srsStatus("es","hola")')) === 'mastered', JSON.stringify(rec));
  // again resets, counts a lapse, due today
  await R('await srsGrade("es","hola",0);');
  rec = await R('return await srsRec("es","hola")');
  k.check('again -> box 0, lapse recorded, due today', rec[0] === 0 && rec[2] === 1 && rec[1] === d, JSON.stringify(rec));
  // easy jumps two boxes, capped at 5
  await R('await srsGrade("es","gracias",3); await srsGrade("es","gracias",3); await srsGrade("es","gracias",3);');
  k.check('easy x3 caps at box 5', (await R('return (await srsRec("es","gracias"))[0]')) === 5);
  // hard keeps the box
  await R('await srsSeed("es","adios"); await srsGrade("es","adios",2);');
  await R('await srsGrade("es","adios",1);');
  k.check('hard keeps the box (2)', (await R('return (await srsRec("es","adios"))[0]')) === 2);
  // due ordering: hardest + most overdue first
  w.localStorage.setItem('pg:w:es:a', '1|' + (d - 3) + '|0|2');
  w.localStorage.setItem('pg:w:es:b', '1|' + (d - 3) + '|4|2');
  w.localStorage.setItem('pg:w:es:c', '1|' + d + '|0|2');
  w.localStorage.setItem('pg:w:es:future', '3|' + (d + 5) + '|0|2');
  const due = await R('return await srsDueWords("es")');
  k.check('due list: b (overdue+hard) before a (overdue) before c; future excluded', due.indexOf('b') < due.indexOf('a') && due.indexOf('a') < due.indexOf('c') && !due.includes('future'), due.join());
  k.check('difficult = lapses>=2 and low box', (await R('return await srsDifficult("es","b")')) === 1 && (await R('return await srsDifficult("es","a")')) === 0);
  k.check('learnedCount counts box>=3 (gracias=5, future=3)', (await R('return await learnedCount("es")')) === 2, await R('return await learnedCount("es")'));
  k.check('masteredCount counts box>=4 (gracias)', (await R('return await masteredCount("es")')) === 1);
  // text helpers
  k.check('norm strips accents/case/punct', (await R('return await norm("¿Cómo   estás?")')) === 'como estas');
  k.check('norm keeps dakuten', (await R('return await norm("が")')) === 'が' && (await R('return await norm("か")')) !== 'が');
  k.check('similarity identical = 100', (await R('return await similarity("Buenos días", "buenos dias")')) === 100);
  k.check('similarity close', (await R('return await similarity("buenos dias", "buenas dias")')) >= 85);
  k.check('similarity far < 40', (await R('return await similarity("hola", "gracias")')) < 40);
  k.check('answerMatches with alternatives', (await R('return await answerMatches("Hi!", "hello", "hi|hey")')) === 1 && (await R('return await answerMatches("yo", "hello", "hi|hey")')) === 0 && (await R('return await answerMatches("", "x", "")')) === 0);
  k.check('no errors', k.errors().length === 0, k.errors());
  k.done();
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
