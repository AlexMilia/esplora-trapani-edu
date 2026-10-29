/* TELECOMANDO (player v2.4) — DOM reale (jsdom) + api mockata.
   Verifica: barra visibile solo durante la lezione, capitoli avanti/indietro,
   «avanti» intelligente (PagGiù) in ogni stato, indice dei capitoli, lezione
   successiva/precedente, tacche sulla barra, riarmo delle tappe tornando indietro. */
const { JSDOM } = require('jsdom');
const fs = require('fs');

const L = (id, tit, stato) => ({ id, tit, sub: '', em: '🎬', stato: stato || 'pubblicata' });
const MENU = { ok: true, quizSempre: false, mascotte: {}, mascotteLiv: {}, mascotteCfg: { junior: false, senior: false },
  tenant: 'esplora-trapani', cliente: { nome: 'Esplora Trapani', brand: { titolo: 'Antichi Mestieri' }, piattaforma: 'Esplora Trapani Edu' },
  corsi: [{ id: 'antichi-mestieri', tit: 'Antichi Mestieri', em: '🛠️', cls: 'oro', stato: 'pubblicato',
    lezioni: [L('uno', 'Lezione uno'), L('vendemmia', 'La vendemmia'), L('olive', 'Olive', 'soon'), L('tre', 'Lezione tre')] }] };
const lez = (id, tit, nClip) => ({ ok: true, lezione: { id, tit, intro: 'Ciao', coccio: null, corso: { id: 'antichi-mestieri', tit: 'Antichi Mestieri' },
  video: Array.from({ length: nClip }, (_, i) => ({ guid: id + '-clip' + i, tit: i === 1 ? 'Il mostimetro' : null, durata_s: 60 })),
  tappe: [{ v: 0, t: 10, cocciu: 'Tappa A', hotspots: [{ em: '🍇', tit: 'Catarratto', txt: 'testo', yaw: 0, pitch: 0 }] },
          { v: 0, t: 40, cocciu: 'Tappa B', hotspots: [{ em: '🌱', tit: 'Viti', txt: 'testo', yaw: 0, pitch: 0 }] },
          { v: 1, t: 5, cocciu: 'Tappa C', hotspots: [{ em: '⚖️', tit: 'Archimede', txt: 'testo', yaw: 0, pitch: 0 }] }],
  quiz: [{ q: 'Domanda?', opts: ['A', 'B'], ok: 0 }], quiz2: null } });

let html = fs.readFileSync('/tmp/pag.html', 'utf8');
const mock = `<script>
window.__url=[];
window.fetch=function(url){ window.__url.push(String(url)); let b;
  if(String(url).indexOf('action=menu')>=0) b=${JSON.stringify(JSON.stringify(MENU))};
  else if(String(url).indexOf('id=vendemmia')>=0) b=${JSON.stringify(JSON.stringify(lez('vendemmia', 'La vendemmia', 3)))};
  else if(String(url).indexOf('id=uno')>=0) b=${JSON.stringify(JSON.stringify(lez('uno', 'Lezione uno', 1)))};
  else if(String(url).indexOf('id=tre')>=0) b=${JSON.stringify(JSON.stringify(lez('tre', 'Lezione tre', 2)))};
  else b='{"ok":true}';
  return Promise.resolve({ json:()=>Promise.resolve(JSON.parse(b)) }); };
window.EduLive={ apri(){} }; window.alert=function(){};
window.AFRAME={ registerComponent(){}, registerGeometry(){}, registerShader(){} }; window.Hls=undefined;
</script>`;
html = html.replace('<head>', '<head>' + mock).replace(/<script src="live-lim\.js[^"]*"><\/script>/, '');
const dom = new JSDOM(html, { url: 'http://localhost/index.php', runScripts: 'dangerously', pretendToBeVisual: true });
const { window } = dom; const { document } = window;
window.HTMLMediaElement.prototype.play = function () { this._p = false; return Promise.resolve(); };
window.HTMLMediaElement.prototype.pause = function () { this._p = true; };
window.HTMLMediaElement.prototype.load = function () {};
Object.defineProperty(window.HTMLMediaElement.prototype, 'paused', { get() { return this._p !== false; }, configurable: true });
Object.defineProperty(window.HTMLMediaElement.prototype, 'duration', { get() { return 60; }, configurable: true });
let _ct = 0; Object.defineProperty(window.HTMLMediaElement.prototype, 'currentTime', { get() { return _ct; }, set(v) { _ct = v; }, configurable: true });

const attendi = ms => new Promise(r => setTimeout(r, ms));
const on = id => document.getElementById(id).classList.contains('on');
const g = expr => window.eval(expr);   /* let/const di primo livello non stanno su window */
const key = (k, extra) => document.dispatchEvent(new window.KeyboardEvent('keydown', Object.assign({ key: k, bubbles: true, cancelable: true }, extra || {})));
let p = 0, f = 0; const ok = (n, c) => { c ? (p++, console.log('  ✓ ' + n)) : (f++, console.log('  ❌ ' + n)); };

(async () => {
  await attendi(400);
  console.log('— 1. Nel menu il telecomando è nascosto —');
  ok('barra assente nel menu', !on('remote') && !document.body.classList.contains('remote-on'));
  ok('pulsante 🎛 in teachbar', !!document.getElementById('btnRemote'));
  ok('overlay aiuto e capitoli esistono', !!document.getElementById('aiuto') && !!document.getElementById('capitoli'));
  key('PageDown'); await attendi(50);
  ok('PagGiù nel menu senza lezione: nessun errore, menu ancora aperto', on('menu'));

  console.log('— 2. Lezione avviata: barra visibile, etichette —');
  window.avviaLezione(1); await attendi(400);
  ok('lezione vendemmia avviata', g('LEZ') && g('LEZ').id === 'vendemmia' && g('started') === true);
  ok('telecomando visibile', on('remote') && document.body.classList.contains('remote-on'));
  ok('etichetta «cap. 1/3»', document.getElementById('seekClip').textContent === 'cap. 1/3');
  ok('pulsante lezione precedente attivo (uno), successiva attiva (tre, salta olive soon)', !document.getElementById('rmLezPrev').disabled && !document.getElementById('rmLezNext').disabled);
  ok('Play/Pausa riflette lo stato (in riproduzione → «Pausa»)', document.getElementById('rmPlay').textContent.includes('Pausa'));

  console.log('— 3. Capitoli —');
  window.capitoloSuccessivo(); await attendi(50);
  ok('capitolo successivo → clip 2', g('vidIdx') === 1 && document.getElementById('seekClip').textContent === 'cap. 2/3');
  ok('voce della mascotte col titolo del capitolo', document.getElementById('cocciuSay').textContent.includes('Il mostimetro'));
  ok('tappe della clip 1 segnate fatte, clip 2 riarmate', g('LEZ').tappe[0]._done && g('LEZ').tappe[1]._done && !g('LEZ').tappe[2]._done);
  _ct = 20; window.capitoloPrecedente(); await attendi(50);
  ok('capitolo precedente a metà clip → inizio dello stesso capitolo', g('vidIdx') === 1);
  _ct = 1; window.capitoloPrecedente(); await attendi(50);
  ok('capitolo precedente all\'inizio → clip 1', g('vidIdx') === 0 && !g('LEZ').tappe[0]._done);
  ok('etichetta ultimo capitolo = «Quiz»', (() => { window.vaiCapitolo(2); return document.querySelector('#rmCapNext small').textContent === 'Quiz'; })());
  window.capitoloSuccessivo(); await attendi(50);
  ok('dopo l\'ultimo capitolo → quiz', on('quiz'));
  document.getElementById('quiz').classList.remove('on'); window.vaiCapitolo(0); await attendi(50);

  console.log('— 4. ±10 s e riarmo delle tappe —');
  _ct = 30; window.salta(10);
  ok('+10 s', _ct === 40);
  g('LEZ').tappe[0]._done = true; g('LEZ').tappe[0].hotspots[0]._fatto = true;
  window.salta(-10); window.salta(-10); window.salta(-10); window.salta(-10);
  ok('−10 s fino a 0 (mai negativo)', _ct === 0);
  ok('tornando indietro la tappa a 10 s è riarmata', !g('LEZ').tappe[0]._done && !g('LEZ').tappe[0].hotspots[0]._fatto);
  ok('tacche delle tappe sulla barra (2 nella clip 1)', (() => { window.renderSeekMarks(); return document.querySelectorAll('#seekMarks i').length === 2; })());

  console.log('— 5. «Avanti» intelligente (PagGiù / clicker) —');
  window.apriTappa(g('LEZ').tappe[0]); await attendi(30);
  ok('tappa aperta: video in pausa, pill visibile', g('tappaAttiva') && on('pill'));
  key('PageDown'); await attendi(30);
  ok('PagGiù con tappa attiva → apre la scheda della scoperta', on('scoperta') && document.getElementById('scTit').textContent === 'Catarratto');
  key('PageDown'); await attendi(30);
  ok('PagGiù sulla scheda → chiude e riparte', !on('scoperta') && !g('tappaAttiva'));
  key('Enter'); await attendi(30);
  ok('Invio = avanti → capitolo successivo', g('vidIdx') === 1);
  key('c'); await attendi(30);
  ok('C → indice dei capitoli', on('capitoli'));
  const voci = Array.from(document.querySelectorAll('#capBody .capItem h3')).map(h => h.textContent);
  ok('indice: 3 capitoli, titolo dal DB o «Capitolo n»', voci.length === 3 && voci[0] === 'Capitolo 1' && voci[1] === 'Il mostimetro');
  ok('capitolo corrente evidenziato', document.querySelectorAll('#capBody .capItem')[1].classList.contains('on'));
  ok('scoperte elencate sotto i capitoli (3)', document.querySelectorAll('#capBody .capTappa').length === 3);
  key('PageDown'); await attendi(30);
  ok('PagGiù sull\'indice → lo chiude', !on('capitoli'));
  document.querySelectorAll('#capBody .capTappa')[0].click(); await attendi(30);
  document.getElementById('vid').dispatchEvent(new window.Event('loadedmetadata'));   /* in jsdom i metadati non arrivano da soli */
  await attendi(30);
  ok('tocco su una scoperta dell\'indice → clip 1, 2,5 s prima, riarmata', g('vidIdx') === 0 && Math.abs(_ct - 7.5) < 0.01 && !g('LEZ').tappe[0]._done);
  key('?'); await attendi(30);
  ok('? → aiuto', on('aiuto'));
  key('Escape'); await attendi(30);
  ok('Esc chiude l\'aiuto', !on('aiuto'));
  key('t'); await attendi(30);
  ok('T nasconde il telecomando', !on('remote') && window.localStorage.getItem('edu_remote') === '0');
  key('t'); await attendi(30);
  ok('T lo rimostra', on('remote'));

  console.log('— 6. Lezione successiva / precedente —');
  window.lezioneSuccessiva(); await attendi(400);
  ok('successiva salta «olive» (soon) e apre «tre»', g('LEZ').id === 'tre' && g('started') === true);
  ok('su «tre» il pulsante successiva è disattivato (è l\'ultima)', document.getElementById('rmLezNext').disabled);
  window.lezionePrecedente(); await attendi(400);
  ok('precedente → vendemmia', g('LEZ').id === 'vendemmia');
  window.avviaQuiz(); await attendi(30);
  document.querySelector('#qOpts .opt').click(); await attendi(1500);
  ok('fine lezione: pulsante «Lezione successiva» visibile', on('fine') && document.getElementById('fineNext').style.display === '');
  key('PageDown'); await attendi(400);
  ok('PagGiù sulla fine → lezione successiva', g('LEZ').id === 'tre');

  console.log('— 7. Nel menu tutto torna nascosto —');
  window.vaiMenu(); await attendi(30);
  ok('barra nascosta, overlay chiusi', !on('remote') && !on('capitoli') && !on('aiuto'));
  console.log('RISULTATO: ' + p + ' passati, ' + f + ' falliti');
  process.exit(f ? 1 : 0);
})();
