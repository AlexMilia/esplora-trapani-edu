/* ESPLORA TRAPANI EDU — demo VR · vr-logic.js · v1.0 (23/09/2026)
   Logica pura, senza A-Frame: così si testa in node e il guscio VR resta sottile. */
(function (root) {
  'use strict';

  /* yaw/pitch (gradi, convenzione del player: 0=davanti, 90=destra) → posizione nella sfera */
  function posizione(yaw, pitch, r) {
    r = r || 7;
    const y = (yaw || 0) * Math.PI / 180, p = (pitch || 0) * Math.PI / 180;
    return { x: r * Math.sin(y) * Math.cos(p), y: r * Math.sin(p), z: -r * Math.cos(y) * Math.cos(p) };
  }

  /* sorgenti video di una clip Bunny (o file locale se la demo è offline) */
  function sorgente(cdn, guid, locale) {
    if (locale) return { mp4: 'video/' + guid + '.mp4', hls: null, guid: guid };
    return { hls: cdn + guid + '/playlist.m3u8', mp4: cdn + guid + '/play_720p.mp4', mp4hd: cdn + guid + '/play_1080p.mp4', guid: guid };
  }

  /* stato di una lezione in corso */
  function creaStato(lezione) {
    return { vidIdx: 0, fatte: {}, aperti: 0, tappaAttiva: null, quizIdx: 0, punti: 0, fase: 'video' };
  }

  /* la tappa da aprire ADESSO, se esiste: stessa clip, tempo raggiunto, non ancora fatta */
  function tappaDaAprire(stato, lezione, tempo) {
    if (stato.tappaAttiva !== null || stato.fase !== 'video') return null;   /* !== null: la tappa 0 è valida */
    const cand = (lezione.tappe || []).map((t, i) => ({ t: t, i: i }))
      .filter(o => o.t.v === stato.vidIdx && !stato.fatte[o.i] && tempo >= o.t.t && o.t.hot && o.t.hot.length);
    if (!cand.length) return null;
    cand.sort((a, b) => a.t.t - b.t.t);
    return cand[0];
  }
  function apriTappa(stato, i) { stato.tappaAttiva = i; stato.aperti = 0; stato.fatte[i] = true; }
  /* un hotspot è stato letto: torna true quando la tappa è completa */
  function hotspotLetto(stato, lezione) {
    stato.aperti++;
    const t = lezione.tappe[stato.tappaAttiva];
    if (stato.aperti >= t.hot.length) { stato.tappaAttiva = null; return true; }
    return false;
  }
  /* fine di una clip: prossima clip o quiz (o fine se non c'è quiz) */
  function fineClip(stato, lezione) {
    if (stato.vidIdx + 1 < lezione.video.length) { stato.vidIdx++; return 'video'; }
    stato.fase = (lezione.quiz && lezione.quiz.length) ? 'quiz' : 'fine';
    return stato.fase;
  }
  /* risposta al quiz: mai punitivo, si passa sempre alla domanda dopo */
  function rispondi(stato, lezione, scelta) {
    const q = lezione.quiz[stato.quizIdx];
    const giusta = (scelta === q.ok);
    if (giusta) stato.punti++;
    stato.quizIdx++;
    if (stato.quizIdx >= lezione.quiz.length) stato.fase = 'fine';
    return { giusta: giusta, corretta: q.opts[q.ok], fine: stato.fase === 'fine' };
  }

  /* a-capo per il testo 3D (a-text non va a capo da solo in modo affidabile) */
  function spezza(testo, maxChar) {
    maxChar = maxChar || 42;
    const parole = String(testo || '').split(/\s+/), righe = []; let riga = '';
    parole.forEach(p => {
      if ((riga + ' ' + p).trim().length > maxChar) { if (riga) righe.push(riga); riga = p; }
      else riga = (riga + ' ' + p).trim();
    });
    if (riga) righe.push(riga);
    return righe.join('\n');
  }
  /* disposizione delle card del menu ad arco davanti all'utente */
  function arcoMenu(n, raggio, apertura) {
    raggio = raggio || 3.2; apertura = apertura || 110;   /* gradi totali */
    const out = [];
    for (let i = 0; i < n; i++) {
      const a = (n === 1) ? 0 : (-apertura / 2 + apertura * i / (n - 1));
      const r = a * Math.PI / 180;
      out.push({ x: raggio * Math.sin(r), y: 1.6, z: -raggio * Math.cos(r), rotY: -a });
    }
    return out;
  }

  const api = { posizione, sorgente, creaStato, tappaDaAprire, apriTappa, hotspotLetto, fineClip, rispondi, spezza, arcoMenu };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.VRLogic = api;
})(typeof window !== 'undefined' ? window : globalThis);
