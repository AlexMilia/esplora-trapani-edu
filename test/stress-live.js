/* STRESS TEST QUIZ LIVE — simula una partita reale con N alunni simultanei */
const U = process.env.U || 'http://127.0.0.1:8072';
const N = parseInt(process.argv[2] || '30', 10);          // alunni
const STANZE = parseInt(process.argv[3] || '1', 10);      // partite in parallelo
const DURATA = parseInt(process.argv[4] || '20', 10);     // secondi di polling
const http = require('http');
const agent = new http.Agent({ keepAlive: true, maxSockets: 512 });

function chiama(path, body, cookie) {
  return new Promise((res) => {
    const t0 = process.hrtime.bigint();
    const u = new URL(U + path);
    const opt = { method: body ? 'POST' : 'GET', hostname: u.hostname, port: u.port, path: u.pathname + u.search,
      headers: body ? { 'Content-Type': 'application/json' } : {}, agent };
    const rq = http.request(opt, (r) => {
      let d = ''; r.on('data', c => d += c);
      r.on('end', () => { const ms = Number(process.hrtime.bigint() - t0) / 1e6; let j = null; try { j = JSON.parse(d); } catch (e) {}
        res({ code: r.statusCode, ms, j }); });
    });
    rq.on('error', () => res({ code: 0, ms: Number(process.hrtime.bigint() - t0) / 1e6, j: null }));
    if (body) rq.write(JSON.stringify(body));
    rq.end();
  });
}
const lat = []; let err = 0, tot = 0;
function reg(r) { tot++; lat.push(r.ms); if (r.code !== 200) err++; return r; }
const pct = (p) => { const s = [...lat].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(s.length * p))].toFixed(1); };

(async () => {
  console.log(`Stress: ${N} alunni × ${STANZE} stanze · polling ogni 2s per ${DURATA}s + 3 domande`);
  const stanze = [];
  for (let s = 0; s < STANZE; s++) {
    const r = reg(await chiama('/live.php?action=crea', { titolo: 'Stress ' + s, quiz: [
      { domanda: 'D1', opzioni: ['a', 'b', 'c', 'd'], g: 0, spiegazione: 'Perché.' },
      { domanda: 'D2', opzioni: ['a', 'b'], g: 1 }, { domanda: 'D3', opzioni: ['a', 'b', 'c'], g: 2 }] }));
    if (!r.j || !r.j.pin) { console.log('creazione fallita', r.code, r.j); process.exit(1); }
    stanze.push({ pin: r.j.pin, host: r.j.host, alunni: [] });
  }
  // JOIN simultaneo di tutti gli alunni (il momento peggiore: tutti insieme al via)
  const t0 = Date.now();
  await Promise.all(stanze.flatMap(st => Array.from({ length: N }, (_, i) =>
    chiama('/live.php?action=join', { pin: st.pin, nome: 'Alunno' + i }).then(r => { reg(r); if (r.j && r.j.token) st.alunni.push(r.j.token); }))));
  console.log(`join di ${N * STANZE} alunni in ${Date.now() - t0} ms · entrati: ${stanze.reduce((a, s) => a + s.alunni.length, 0)}`);
  // il docente avvia; gli alunni fanno polling e rispondono a ogni domanda
  for (const st of stanze) reg(await chiama('/live.php?action=avanza', { pin: st.pin, host: st.host }));
  const fine = Date.now() + DURATA * 1000;
  let q = 0, ultimoAvanza = Date.now();
  const lettori = stanze.flatMap(st => st.alunni.map(tok => (async () => {
    let risposto = -1;
    while (Date.now() < fine) {
      const r = reg(await chiama(`/live.php?action=stato&pin=${st.pin}&token=${tok}`));
      if (r.j && r.j.stato === 'domanda' && r.j.q_idx !== risposto) {
        risposto = r.j.q_idx;
        reg(await chiama('/live.php?action=risposta', { pin: st.pin, token: tok, q: r.j.q_idx, r: Math.floor(Math.random() * 2) }));
      }
      await new Promise(rs => setTimeout(rs, 2000 + Math.random() * 300));
    }
  })()));
  // il docente chiude le risposte e passa alla domanda seguente ogni ~5s
  const docente = (async () => {
    while (Date.now() < fine) {
      await new Promise(rs => setTimeout(rs, 5000));
      for (const st of stanze) { reg(await chiama('/live.php?action=avanza', { pin: st.pin, host: st.host })); reg(await chiama(`/live.php?action=stato&pin=${st.pin}&token=${st.host}`)); }
    }
  })();
  await Promise.all([...lettori, docente]);
  // verifica dei conteggi
  let contate = 0;
  for (const st of stanze) { const r = await chiama(`/live.php?action=stato&pin=${st.pin}&token=${st.host}`); if (r.j && r.j.recap) contate += r.j.recap.reduce((a, x) => a + x.tot, 0); else if (r.j && r.j.tot != null) contate += r.j.tot; }
  console.log(`richieste: ${tot} · errori: ${err} (${(100 * err / tot).toFixed(2)}%) · latenza p50 ${pct(0.5)} ms · p95 ${pct(0.95)} ms · p99 ${pct(0.99)} ms · max ${pct(1)} ms`);
  console.log(`risposte registrate sul server: ${contate}`);
  for (const st of stanze) await chiama('/live.php?action=chiudi', { pin: st.pin, host: st.host });
  process.exit(err / tot > 0.01 ? 1 : 0);
})();
