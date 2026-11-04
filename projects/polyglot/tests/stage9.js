const { open, kit } = require('./pg_lib');
const { spawn } = require('child_process');
let P=0,F=0; const chk=(n,c,e)=>{ if(c){P++;console.log('PASS '+n);} else {F++;console.log('FAIL '+n+(e!==undefined?' -> '+e:''));} };
(async () => {
  const up = spawn('node', [require('path').join(__dirname, 'fake_up.js')], { stdio: 'inherit' });
  const srv = spawn('node', [require('path').join(__dirname, '..', 'server', 'tutor-server', 'tutor-server.js')], { env: { ...process.env, ANTHROPIC_API_KEY: 'k', PORT: '8794', TUTOR_UPSTREAM: 'http://127.0.0.1:8792' }, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 800));
  const dom = open(); const k = kit(dom); const { doc, w } = k; await k.sleep(80);
  w.fetch = (...a) => fetch(...a); w.AbortController = AbortController; w.URL = URL;
  await k.run('await act("lang:toggle","es"); await act("lang:toggle","ja");');
  await k.click('[data-act="nav:tutor"]');
  chk('with no server the tutor says so and offers setup (no fake AI)', /Connect a tutor server/.test(k.text()) && !doc.getElementById('tin') && /Nothing is simulated/.test(k.text()));
  for (const bad of ['', 'ftp://x', 'localhost:8794', 'http://a b', 'javascript:alert(1)']) { doc.getElementById('tep').value = bad; await k.click('[data-act="tutor:save"]'); chk('rejects address "' + bad + '"', w.localStorage.getItem('pg:s:tutor') === null && /address|Enter|start with|spaces/.test(k.text())); }
  doc.getElementById('tep').value = 'http://127.0.0.1:8794/api/tutor'; await k.click('[data-act="tutor:save"]');
  chk('valid address saved, chat UI appears', w.localStorage.getItem('pg:s:tutor') === 'http://127.0.0.1:8794/api/tutor' && !!doc.getElementById('tin') && doc.querySelectorAll('[data-act="tutor:task"]').length === 6);
  await k.click('[data-act="tutor:test"]'); await k.sleep(300);
  chk('connection test succeeds', /Connected/.test(k.text()), k.text().slice(-200));
  // empty send
  await k.click('[data-act="tutor:send"]');
  chk('empty message is refused locally', /Write something/.test(k.text()) && (await (await fetch('http://127.0.0.1:8792/log')).json()).length === 0);
  // real round trip
  await k.click('[data-act="tutor:task"][data-arg="correct"]');
  doc.getElementById('tin').value = 'Yo soy estudiante <script>x</script>'; await k.click('[data-act="tutor:send"]'); await k.sleep(400);
  let log = await (await fetch('http://127.0.0.1:8792/log')).json();
  chk('request reached the model with system prompt and the message', log.length === 1 && /Spanish tutor/.test(log[0].system) && /Correct|corrected sentence/.test(log[0].system) && log[0].messages.at(-1).content.includes('Yo soy estudiante'), JSON.stringify(log[0]).slice(0, 200));
  chk('system prompt carries learner progress', /finished 0 of 5/.test(log[0].system) && /Spanish/.test(log[0].system));
  chk('reply is shown, HTML escaped', /Reply #1/.test(k.text()) && !doc.querySelector('.bubble b') && doc.querySelectorAll('.bubble').length === 2);
  doc.getElementById('tin').value = 'Gracias'; await k.click('[data-act="tutor:send"]'); await k.sleep(400);
  log = await (await fetch('http://127.0.0.1:8792/log')).json();
  chk('conversation history is sent (user, assistant, user)', log[1].messages.map(m => m.role).join() === 'user,assistant,user', log[1].messages.map(m => m.role).join());
  // no-typing tasks
  await k.click('[data-act="tutor:task"][data-arg="recommend"]'); await k.click('[data-act="tutor:send"]'); await k.sleep(400);
  log = await (await fetch('http://127.0.0.1:8792/log')).json();
  chk('recommend works without typing', log.length === 3 && /What should I study next/.test(log[2].messages.at(-1).content));
  // japanese romanisation hint
  await k.click('[data-act="lang:switch"][data-arg="ja"]'); await k.click('[data-act="tutor:send"]'); await k.sleep(400);
  log = await (await fetch('http://127.0.0.1:8792/log')).json();
  chk('non-Latin languages ask for romanised readings', /romanised/.test(log[3].system) && /Japanese tutor/.test(log[3].system));
  // too long
  doc.getElementById('tin').value = 'a'.repeat(1600); await k.click('[data-act="tutor:task"][data-arg="explain"]');
  await k.click('[data-act="tutor:clear"]'); doc.getElementById('tin').value = 'a'.repeat(1600); await k.click('[data-act="tutor:send"]'); await k.sleep(300);
  chk('over-long message refused with a clear error', /too long/.test(k.text()));
  // server down
  doc.getElementById('tep') ; 
  await k.run('await putSetting("tutor","http://127.0.0.1:1/api/tutor")'); await k.click('[data-act="nav:dashboard"]'); await k.click('[data-act="nav:tutor"]');
  await k.click('[data-act="tutor:clear"]'); doc.getElementById('tin').value = 'hola'; await k.click('[data-act="tutor:send"]'); await k.sleep(600);
  chk('unreachable server shows a friendly error, no crash', /Could not reach the tutor server/.test(k.text()) && k.errors().length === 0, k.errors());
  await k.click('[data-act="tutor:forget"]');
  chk('disconnect returns to setup', /Connect a tutor server/.test(k.text()) && w.localStorage.getItem('pg:s:tutor') === '');
  chk('no runtime errors', k.errors().length === 0, k.errors());
  up.kill(); srv.kill();
  console.log(`\n${P} passed, ${F} failed`); process.exit(F ? 1 : 0);
})().catch((e) => { console.error('HARNESS ERROR', e.message); process.exit(2); });
