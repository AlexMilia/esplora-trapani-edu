#!/usr/bin/env node
/* =====================================================================
   ESPLORA TRAPANI EDU — crea-pacchetto.js · PACCHETTO OFFLINE per le scuole
   ---------------------------------------------------------------------
   Costruisce una cartella autonoma (da copiare su una chiavetta o sul
   portatile) con il player, i contenuti di un cliente e gli script per
   scaricare i video. In classe non serve nessuna connessione.

   1) Dal database (serve la connessione, la anon key la legge da
      app/dati/config.php o config.example.php):
        node offline/crea-pacchetto.js --tenant esplora-trapani
      opzioni: --progetto antichi-mestieri-trapani   (mascotte; default: progetto_legacy del cliente)
               --bozza vendemmia-alagna=TOKEN        (include una lezione in bozza tramite il suo
                                                      token di anteprima: Regia → "Copia link anteprima",
                                                      il token è ciò che segue ?lez=)
               --res 720p|1080p                      (qualità degli mp4 da scaricare, default 720p)
               --out cartella                        (default offline/pacchetti/<tenant>)
               --anon KEY                            (anon key Supabase, se non sta nel config)

   2) Da un dati.js già pronto (nessuna connessione: rigenera solo script e player):
        node offline/crea-pacchetto.js --da-dati offline/pacchetti/esplora-trapani/dati.js

   Prima di tutto va costruito il player statico:  bash offline/costruisci-player.sh
   Dopo: entra nella cartella e lancia scarica-video.sh (Mac/Linux) o scarica-video.bat
   (Windows), poi AVVIA.bat / avvia.sh. Vedi offline/LEGGIMI-OFFLINE.md.
   ===================================================================== */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');

const RADICE = path.resolve(__dirname, '..');
const CDN = 'https://vz-bedaaab5-085.b-cdn.net/';
const REFERER = 'https://www.alessandromilia.it/';
const LINGUE_CC = ['it', 'en', 'fr', 'es', 'de'];
const MASCOTTE_CHIAVI = ['inizio_corso', 'fine_lezione', 'fine_corso', 'giusta', 'sbagliata'];

/* ---------------- argomenti ---------------- */
const arg = {}; const bozze = [];
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a === '--bozza') { bozze.push(process.argv[++i]); continue; }
  if (a.startsWith('--')) { arg[a.slice(2)] = (process.argv[i + 1] && !process.argv[i + 1].startsWith('--')) ? process.argv[++i] : true; }
}
if (!arg.tenant && !arg['da-dati']) {
  console.log(fs.readFileSync(__filename, 'utf8').split('=====')[2].trim()); process.exit(1);
}
const RES = /^1080/.test(String(arg.res || '')) ? 'play_1080p.mp4' : 'play_720p.mp4';

/* ---------------- Supabase ---------------- */
function leggiConfig() {
  let url = 'https://sdqzqzmkhbkkibjzauox.supabase.co', anon = process.env.SUPA_ANON || '';
  for (const f of ['app/dati/config.php', 'app/dati/config.example.php']) {
    try {
      const s = fs.readFileSync(path.join(RADICE, f), 'utf8');
      const mu = s.match(/\$SUPA_URL\s*=\s*'([^']+)'/); if (mu) url = mu[1];
      const ma = s.match(/\$SUPA_ANON\s*=\s*'([^']+)'/); if (ma && !anon) anon = ma[1];
      if (anon) break;
    } catch (e) {}
  }
  if (arg.anon) anon = String(arg.anon);
  return { url, anon };
}
async function rpc(cfg, fn, body) {
  if (typeof fetch !== 'function') throw new Error('Serve Node.js 18 o più recente (fetch integrato).');
  const r = await fetch(cfg.url + '/rest/v1/rpc/' + fn, {
    method: 'POST', headers: { 'Content-Type': 'application/json', apikey: cfg.anon, Authorization: 'Bearer ' + cfg.anon },
    body: JSON.stringify(body || {})
  });
  if (!r.ok) throw new Error(fn + ' → HTTP ' + r.status + ' ' + (await r.text()).slice(0, 200));
  return r.json();
}

/* ---------------- media remoti → locali ---------------- */
function estensione(u) { const m = String(u).split('?')[0].match(/\.([a-z0-9]{2,5})$/i); return m ? '.' + m[1].toLowerCase() : ''; }
function nomeLocale(u, mappa) {
  for (const k in mappa) if (mappa[k] === u) return k;
  const base = String(u).split('?')[0].split('/').pop().replace(/[^a-z0-9._-]/gi, '_').slice(0, 40) || 'file';
  const h = crypto.createHash('sha1').update(String(u)).digest('hex').slice(0, 8);
  const nome = 'media/' + base.replace(/\.[a-z0-9]+$/i, '') + '-' + h + estensione(u);
  mappa[nome] = u; return nome;
}
/* sostituisce ricorsivamente gli URL https di foto/audio/immagini con percorsi locali */
function localizza(obj, mappa, chiavi) {
  if (Array.isArray(obj)) { obj.forEach(x => localizza(x, mappa, chiavi)); return obj; }
  if (!obj || typeof obj !== 'object') return obj;
  for (const k of Object.keys(obj)) {
    const v = obj[k];
    if (typeof v === 'string' && chiavi.has(k) && /^https?:\/\//i.test(v)) obj[k] = nomeLocale(v, mappa);
    else if (v && typeof v === 'object') localizza(v, mappa, chiavi);
  }
  return obj;
}
const CHIAVI_MEDIA = new Set(['foto', 'audio', 'url', 'img', 'media_spiegazione', 'copertina', 'foto_url', 'audio_url', 'mascotte_img']);

/* ---------------- raccolta video (GUID Bunny) ---------------- */
function guidBunny(s) {
  if (!s) return '';
  s = String(s).trim();
  if (/^bunny:/i.test(s)) s = s.slice(6);
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s) ? s.toLowerCase() : '';
}
function ytId(s) { if (!s) return ''; s = String(s).trim(); if (/^bunny:/i.test(s)) return ''; const m = s.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/))([A-Za-z0-9_-]{6,})/); if (m) return m[1]; return /^[A-Za-z0-9_-]{8,15}$/.test(s) ? s : ''; }
function raccogliVideo(D) {
  const guid = new Set(), yt = new Set();
  const masc = (o) => { if (!o || typeof o !== 'object') return; for (const k of MASCOTTE_CHIAVI) { const g = guidBunny(o[k]); if (g) guid.add(g); const y = ytId(o[k]); if (y) yt.add(y); } };
  Object.values(D.lezioni || {}).forEach(l => {
    (l.video || []).forEach(v => { const g = guidBunny(v.guid); if (g) guid.add(g); const gl = guidBunny(v.lis); if (gl) guid.add(gl); });
    const gc = guidBunny(l.coccio); if (gc) guid.add(gc); const yc = ytId(l.coccio); if (yc) yt.add(yc);
    if (l.corso && l.corso.mascotte && l.corso.mascotte.video) Object.values(l.corso.mascotte.video).forEach(masc);
  });
  const m = D.menu || {};
  masc(m.mascotte); if (m.mascotteLiv) Object.values(m.mascotteLiv).forEach(masc);
  (m.corsi || []).forEach(co => { if (co.mascotte && co.mascotte.video) Object.values(co.mascotte.video).forEach(masc); });
  return { guid: [...guid], yt: [...yt] };
}

/* ---------------- script di download ---------------- */
function scriptSh(D, out) {
  const { guid, yt } = raccogliVideo(D);
  const L = ['#!/bin/bash', '# Scarica i video e i media del pacchetto (serve la connessione UNA volta). Riavviabile: salta i file già presenti.',
    'cd "$(dirname "$0")" || exit 1', 'mkdir -p video media', 'R="' + REFERER + '"', 'ok=0; ko=0',
    'dl(){ [ -s "$2" ] && { echo "  già presente: $2"; return; }; echo "  scarico $2"; if curl -fsSL -e "$R" -o "$2.part" "$1"; then mv "$2.part" "$2"; ok=$((ok+1)); else rm -f "$2.part"; echo "  ✗ non scaricato: $1"; ko=$((ko+1)); fi; }',
    'cc(){ [ -s "$2" ] && return; curl -fsSL -e "$R" -o "$2" "$1" 2>/dev/null || rm -f "$2"; }',
    'echo "Video: ' + guid.length + '"'];
  guid.forEach(g => { L.push('dl "' + CDN + g + '/' + RES + '" "video/' + g + '.mp4"'); LINGUE_CC.forEach(l => L.push('cc "' + CDN + g + '/captions/' + l + '.vtt" "video/' + g + '.' + l + '.vtt"')); });
  const media = D.media_remoti || {};
  L.push('echo "Media: ' + Object.keys(media).length + '"');
  Object.keys(media).forEach(k => L.push('dl "' + media[k] + '" "' + k + '"'));
  if (yt.length) { L.push('echo "Video della mascotte su YouTube (non scaricabili da qui): ' + yt.join(' ') + '"'); L.push('echo "Se vuoi vederli anche offline, salvali come video/yt_<id>.mp4 (es. video/yt_' + yt[0] + '.mp4); altrimenti il player li salta."'); }
  L.push('echo; echo "Fatto: $ok scaricati, $ko non riusciti. Ora: bash avvia.sh"');
  fs.writeFileSync(path.join(out, 'scarica-video.sh'), L.join('\n') + '\n'); try { fs.chmodSync(path.join(out, 'scarica-video.sh'), 0o755); } catch (e) {}
}
function scriptBat(D, out) {
  const { guid, yt } = raccogliVideo(D);
  const L = ['@echo off', 'rem Scarica i video e i media del pacchetto (serve la connessione UNA volta). Riavviabile.',
    'cd /d "%~dp0"', 'if not exist video mkdir video', 'if not exist media mkdir media', 'set R=' + REFERER,
    'echo Video: ' + guid.length];
  const dl = (u, f) => { L.push('if exist "' + f + '" (echo   gia presente: ' + f + ') else (echo   scarico ' + f + ' & curl -fsSL -e "%R%" -o "' + f + '" "' + u + '" || echo   NON scaricato: ' + u + ')'); };
  const cc = (u, f) => { L.push('if not exist "' + f + '" curl -fsSL -e "%R%" -o "' + f + '" "' + u + '" >nul 2>nul'); L.push('if exist "' + f + '" for %%A in ("' + f + '") do if %%~zA==0 del "' + f + '"'); };
  guid.forEach(g => { dl(CDN + g + '/' + RES, 'video\\' + g + '.mp4'); LINGUE_CC.forEach(l => cc(CDN + g + '/captions/' + l + '.vtt', 'video\\' + g + '.' + l + '.vtt')); });
  const media = D.media_remoti || {};
  L.push('echo Media: ' + Object.keys(media).length);
  Object.keys(media).forEach(k => dl(media[k], k.replace(/\//g, '\\')));
  if (yt.length) L.push('echo Video della mascotte su YouTube (non scaricabili da qui): ' + yt.join(' ') + ' - se li vuoi offline salvali come video\\yt_ID.mp4');
  L.push('echo.', 'echo Fatto. Ora fai doppio clic su AVVIA.bat', 'pause');
  fs.writeFileSync(path.join(out, 'scarica-video.bat'), L.join('\r\n') + '\r\n');
}

/* ---------------- cartella del pacchetto ---------------- */
function copiaPlayer(out) {
  const src = path.join(__dirname, 'player', 'index.html');
  if (!fs.existsSync(src)) { console.log('❌ manca offline/player/index.html: esegui prima  bash offline/costruisci-player.sh'); process.exit(1); }
  fs.copyFileSync(src, path.join(out, 'index.html'));
  const lib = path.join(out, 'lib'); fs.mkdirSync(lib, { recursive: true });
  for (const f of ['aframe.min.js', 'hls.min.js']) {
    const s = path.join(RADICE, 'demo-vr', 'lib', f);
    if (!fs.existsSync(s)) { console.log('❌ manca demo-vr/lib/' + f); process.exit(1); }
    fs.copyFileSync(s, path.join(lib, f));
  }
  for (const f of ['avvia.js', 'AVVIA.bat', 'avvia.sh']) fs.copyFileSync(path.join(__dirname, f), path.join(out, f));
  try { fs.chmodSync(path.join(out, 'avvia.sh'), 0o755); } catch (e) {}
  fs.mkdirSync(path.join(out, 'video'), { recursive: true }); fs.mkdirSync(path.join(out, 'media'), { recursive: true });
  fs.writeFileSync(path.join(out, 'video', '.gitkeep'), '');
}
function scriviLeggimi(D, out) {
  const { guid, yt } = raccogliVideo(D);
  const nLez = Object.keys(D.lezioni || {}).length;
  fs.writeFileSync(path.join(out, 'LEGGIMI.txt'), [
    'ESPLORA TRAPANI EDU — PACCHETTO OFFLINE · ' + (D.tenant || '') + ' · generato il ' + (D.generato || ''),
    '',
    'Questa cartella contiene il player 360 e ' + nLez + ' lezioni, pronte da usare SENZA connessione.',
    '',
    'LA PRIMA VOLTA (con la connessione):',
    '  1. Windows: doppio clic su  scarica-video.bat      Mac/Linux: bash scarica-video.sh',
    '     Scarica ' + guid.length + ' video in video/ (circa ' + Math.round(guid.length * 0.09 * 10) / 10 + ' GB a 720p). Si può interrompere e rilanciare.',
    '  2. Se serve Node.js (consigliato): https://nodejs.org → versione LTS → installa.',
    '',
    'IN CLASSE (senza connessione):',
    '  Windows: doppio clic su  AVVIA.bat      Mac/Linux: bash avvia.sh',
    '  Si apre il browser su http://localhost:8765 con il menu delle lezioni.',
    '  Il telecomando in basso (o il tasto PagGiù del clicker) guida la lezione: ? = aiuto.',
    '',
    'NON APRIRE index.html con doppio clic: il browser blocca i video 360 aperti da file. Usare sempre AVVIA.',
    '',
    'COSA NON FUNZIONA OFFLINE: il Quiz live con i telefoni (serve il server), il tracking anonimo,',
    'i video della mascotte su YouTube' + (yt.length ? ' (' + yt.join(', ') + ': per averli, salvali come video/yt_<id>.mp4)' : '') + '.',
    '',
    'AGGIORNARE I CONTENUTI: dal PC con la repository →  node offline/crea-pacchetto.js --tenant ' + (D.tenant || '<slug>'),
    'poi ricopiare dati.js (e rilanciare scarica-video se ci sono clip nuove).',
    ''].join('\n'));
}

function scriviDati(D, out) {
  fs.writeFileSync(path.join(out, 'dati.js'), '/* ESPLORA TRAPANI EDU — contenuti del pacchetto offline (generato da offline/crea-pacchetto.js). NON modificare a mano: usa la Regia e rigenera. */\nwindow.EDU_DATI = ' + JSON.stringify(D, null, 1) + ';\n');
}

function completa(D, out) {
  fs.mkdirSync(out, { recursive: true });
  copiaPlayer(out); scriviDati(D, out); scriptSh(D, out); scriptBat(D, out); scriviLeggimi(D, out);
  const { guid, yt } = raccogliVideo(D);
  console.log('✓ pacchetto in ' + path.relative(process.cwd(), out) || '.');
  console.log('  lezioni: ' + Object.keys(D.lezioni || {}).join(', '));
  console.log('  video da scaricare: ' + guid.length + ' (' + RES + ')' + (yt.length ? ' · mascotte YouTube non scaricabile: ' + yt.join(', ') : ''));
  console.log('  media: ' + Object.keys(D.media_remoti || {}).length);
  console.log('  → ora: cd ' + path.relative(process.cwd(), out) + ' && bash scarica-video.sh   (Windows: scarica-video.bat), poi AVVIA');
}

/* ---------------- modalità --da-dati ---------------- */
if (arg['da-dati']) {
  const f = path.resolve(String(arg['da-dati']));
  const src = fs.readFileSync(f, 'utf8');
  const m = src.match(/window\.EDU_DATI\s*=\s*([\s\S]*?);\s*$/);
  if (!m) { console.log('❌ dati.js non riconosciuto'); process.exit(1); }
  const D = JSON.parse(m[1]);
  completa(D, arg.out ? path.resolve(String(arg.out)) : path.dirname(f));
  process.exit(0);
}

/* ---------------- modalità --tenant (dal database) ---------------- */
(async () => {
  const cfg = leggiConfig();
  if (!cfg.anon) { console.log('❌ anon key Supabase non trovata: --anon KEY oppure app/dati/config.php'); process.exit(1); }
  const tenant = String(arg.tenant).toLowerCase();
  const out = arg.out ? path.resolve(String(arg.out)) : path.join(__dirname, 'pacchetti', tenant);
  console.log('Cliente: ' + tenant);
  const cl = await rpc(cfg, 'edu_get_cliente', { p_slug: tenant });
  if (!cl || !cl.slug) { console.log('❌ cliente «' + tenant + '» non trovato'); process.exit(1); }
  const progetto = String(arg.progetto || cl.progetto_legacy || 'antichi-mestieri-trapani');
  const corsi = await rpc(cfg, 'edu_get_corsi', { p_cliente_slug: tenant });
  const masc = await rpc(cfg, 'edu_get_mascotte', { p_progetto: progetto });
  const mcfg = (masc && masc.mascotte) || {}, mvid = (masc && masc.video) || { junior: {}, senior: {} };
  const menu = {
    ok: true, tenant: tenant,
    cliente: { nome: cl.nome, slug: cl.slug, brand: cl.brand || {}, piano: cl.piano || 'base', piattaforma: 'Esplora Trapani Edu',
      licenza_stato: cl.licenza_stato || 'attiva', licenza_fine: cl.licenza_fine || null,
      limiti: Object.assign({}, cl.limiti || {}, { quiz_live: false }), contatto_email: cl.contatto_email || null },
    scuola: null, corsi: Array.isArray(corsi) ? corsi : [], lezioni: [],
    mascotte: mvid.junior || {}, mascotteLiv: mvid, mascotteCfg: mcfg, quizSempre: mcfg.quiz_sempre !== false
  };
  const lezioni = {};
  for (const co of menu.corsi) for (const l of (co.lezioni || [])) {
    if (l.stato === 'soon') continue;
    process.stdout.write('  lezione ' + l.id + ' … ');
    const d = await rpc(cfg, 'edu_get_lezione_tenant', { p_cliente_slug: tenant, p_lezione_slug: l.id });
    if (d && d.id) { lezioni[l.id] = d; console.log((d.video || []).length + ' clip'); } else console.log('non disponibile (licenza/stato)');
  }
  for (const b of bozze) {
    const [slug, token] = String(b).split('=');
    if (!slug || !token) { console.log('  --bozza: formato slug=token'); continue; }
    process.stdout.write('  bozza ' + slug + ' … ');
    const d = await rpc(cfg, 'edu_get_lezione_token', { p_token: token });
    if (!d || !d.id) { console.log('token non valido'); continue; }
    d.stato = 'pubblicata'; lezioni[d.id] = d;
    const co = menu.corsi.find(c => d.corso && (c.id === d.corso.id)) || menu.corsi[0];
    if (co && !(co.lezioni || []).some(x => x.id === d.id)) {
      co.lezioni = co.lezioni || [];
      const card = { id: d.id, em: d.em, cls: d.cls, tit: d.tit, sub: d.sub, durata: d.durata, stato: 'pubblicata', acc: d.acc || {} };
      const iSoon = co.lezioni.findIndex(x => x.stato === 'soon');
      if (iSoon >= 0) co.lezioni.splice(iSoon, 0, card); else co.lezioni.push(card);
    }
    console.log((d.video || []).length + ' clip (inclusa dal token di anteprima)');
  }
  menu.lezioni = [].concat(...menu.corsi.map(co => (co.lezioni || []).map(l => Object.assign({ corso: co.id }, l))));
  const media = {};
  const D = { generato: new Date().toISOString().slice(0, 10), tenant, progetto, menu, lezioni, media_remoti: media };
  localizza(D.menu, media, CHIAVI_MEDIA); localizza(D.lezioni, media, CHIAVI_MEDIA);
  completa(D, out);
})().catch(e => { console.log('❌ ' + e.message); process.exit(1); });
