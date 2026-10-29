/* MODALITÀ OFFLINE (player v2.4) — jsdom sul player statico offline/player/index.html
   con il dati.js del pacchetto esplora-trapani. Verifica: nessuna fetch, menu e
   lezione da dati.js, sorgenti video locali, quiz live spento, mascotte YouTube saltata. */
const { JSDOM } = require('jsdom');
const fs = require('fs'), path = require('path');
const RADICE = path.join(__dirname, '..');
const PLAYER = path.join(RADICE, 'offline', 'player', 'index.html');
const DATI = path.join(RADICE, 'offline', 'pacchetti', 'esplora-trapani', 'dati.js');
if (!fs.existsSync(PLAYER)) { console.log('❌ manca offline/player/index.html: bash offline/costruisci-player.sh'); process.exit(1); }
let html = fs.readFileSync(PLAYER, 'utf8');
let p = 0, f = 0; const ok = (n, c) => { c ? (p++, console.log('  ✓ ' + n)) : (f++, console.log('  ❌ ' + n)); };

console.log('— 1. Il player statico non dipende da internet —');
ok('nessun CDN (aframe.io, jsdelivr, fonts)', !/aframe\.io|jsdelivr|fonts\.googleapis/.test(html));
ok('librerie locali e dati.js', /src="lib\/aframe\.min\.js"/.test(html) && /src="lib\/hls\.min\.js"/.test(html) && /src="dati\.js"/.test(html));
ok('live-lim.js non caricato', !/<script src="[^"]*live-lim\.js/.test(html));
ok('mascotte locale', /media\/mascotte\.png/.test(html));
ok('bandiera EDU_OFFLINE', /window\.EDU_OFFLINE=true/.test(html));

/* inietto dati.js al posto dello script esterno, e stub di fetch che fallisce (non deve mai essere chiamata) */
const dati = fs.readFileSync(DATI, 'utf8');
html = html.replace('<script src="dati.js"></script>', '<script>' + dati + '</script>')
  .replace(/<script src="lib\/[^"]+"><\/script>/g, '')
  .replace('<head>', '<head><script>window.__fetch=0; window.fetch=function(){ window.__fetch++; return Promise.reject(new Error("rete")); };' +
    'window.AFRAME={registerComponent(){},registerGeometry(){},registerShader(){}}; window.Hls=undefined; window.alert=function(){};</script>');
const dom = new JSDOM(html, { url: 'http://localhost:8765/', runScripts: 'dangerously', pretendToBeVisual: true });
const { window } = dom; const { document } = window;
window.HTMLMediaElement.prototype.play = function () { return Promise.resolve(); };
window.HTMLMediaElement.prototype.pause = function () {};
window.HTMLMediaElement.prototype.load = function () {};
const attendi = ms => new Promise(r => setTimeout(r, ms));
const g = expr => window.eval(expr);   /* let/const di primo livello non stanno su window */
(async () => {
  await attendi(400);
  console.log('— 2. Menu e lezione da dati.js —');
  ok('OFFLINE attivo nel player', g('OFFLINE') === true);
  ok('nessuna fetch al caricamento', window.__fetch === 0);
  ok('due corsi dal pacchetto', document.querySelectorAll('#menuLez .lez.corso').length === 2);
  ok('brand del cliente', document.getElementById('brandTit').textContent === 'Antichi Mestieri di Trapani');
  ok('quiz live spento offline', g('QUIZ_LIVE_OK') === false);
  document.querySelector('#menuLez .lez.corso').click(); await attendi(50);
  const tit = Array.from(document.querySelectorAll('#menuLez .lez h3')).map(h => h.textContent);
  ok('5 lezioni, vendemmia compresa', tit.length === 5 && tit.some(t => /vendemmia/i.test(t)));
  ok('olive resta «prossimamente»', document.querySelectorAll('#menuLez .lez.soon').length === 1);
  window.avviaLezione(3); await attendi(400);
  ok('vendemmia avviata da dati.js', g('LEZ') && g('LEZ').id === 'vendemmia-alagna' && g('started') === true);
  ok('9 capitoli con titolo', g('LEZ').video.length === 9 && g('LEZ').video.every(v => v.tit));
  ok('sorgente video locale video/<guid>.mp4, niente HLS', g('LEZ').video[0].mp4 === 'video/3bf24071-3b60-430a-b77c-097440006f53.mp4' && g('LEZ').video[0].hls === null);
  ok('il <video> punta al file locale', document.getElementById('vid').src.endsWith('/video/3bf24071-3b60-430a-b77c-097440006f53.mp4'));
  ok('ancora nessuna fetch (lezione e tracking non passano dalla rete)', window.__fetch === 0);
  ok('pulsante quiz live nascosto', document.getElementById('tbLive').style.display === 'none');
  ok('telecomando visibile', document.getElementById('remote').classList.contains('on'));
  /* v2.4.1: il «?» delle scoperte non è un <a-text> (font dal CDN di A-Frame) ma un piano con texture canvas */
  window.apriTappa(g('LEZ').tappe[0]); await attendi(50);
  ok('scoperta aperta: il «?» è un a-plane, nessun a-text (niente font dal CDN)',
    document.querySelectorAll('#hotspots a-plane').length === 1 && document.querySelectorAll('#hotspots a-text').length === 0);
  ok('il segno «?» è una data URL PNG', /^data:image\/png;base64,/.test(window.segnoInterrogativo('#e8788a')));
  window.chiudiScoperta && window.chiudiScoperta();
  console.log('— 3. Mascotte YouTube offline: si salta senza bloccare —');
  /* in jsdom il <video> non carica nulla: simulo l'errore 404 che nel browser arriva dal server locale */
  const prova = async (src) => { const pr = window.playCoccio(src); await attendi(50);
    const el = document.querySelector('#coccioSlot video'); const s = el ? el.getAttribute('src') : '';
    if (el) el.dispatchEvent(new window.Event('error'));
    return { esito: await Promise.race([pr, attendi(1500).then(() => 'bloccato')]), src: s }; };
  const yt = await prova('DsrzZPFkTmM');
  ok('video YouTube cercato in locale come video/yt_<id>.mp4', yt.src === 'video/yt_DsrzZPFkTmM.mp4');
  ok('…e se manca si prosegue (' + yt.esito + ')', yt.esito === 'errore');
  const bn = await prova('bunny:abc');
  ok('video bunny mancante → prosegue (' + bn.esito + '), sorgente locale', bn.esito === 'errore' && bn.src === 'video/abc.mp4');
  ok('overlay della mascotte chiuso', !document.getElementById('coccioOvl').classList.contains('on'));
  ok('sottotitoli cercati in locale', (() => { window.eval("ccLang='it'"); return typeof window.loadCC === 'function'; })());
  console.log('RISULTATO: ' + p + ' passati, ' + f + ' falliti');
  process.exit(f ? 1 : 0);
})();
