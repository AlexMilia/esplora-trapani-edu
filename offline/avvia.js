#!/usr/bin/env node
/* =====================================================================
   ESPLORA TRAPANI EDU — avvia.js · server locale del pacchetto OFFLINE
   ---------------------------------------------------------------------
   Serve la cartella in cui si trova (index.html, dati.js, lib/, video/,
   media/) su http://localhost:8765 e apre il browser. Niente dipendenze:
   basta Node.js (nodejs.org). Supporta le richieste "Range", che servono
   al browser per saltare avanti e indietro nei video mp4.
   Uso:  node avvia.js            (oppure doppio clic su AVVIA.bat / avvia.sh)
         node avvia.js 9000       (porta diversa)
   ===================================================================== */
'use strict';
const http = require('http'), fs = require('fs'), path = require('path'), os = require('os');
const { exec } = require('child_process');

const RADICE = __dirname;
const PORTA = parseInt(process.argv[2] || process.env.PORTA || '8765', 10) || 8765;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.mp4': 'video/mp4', '.m4v': 'video/mp4', '.webm': 'video/webm', '.m3u8': 'application/vnd.apple.mpegurl', '.ts': 'video/mp2t',
  '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.ogg': 'audio/ogg', '.wav': 'audio/wav',
  '.vtt': 'text/vtt; charset=utf-8', '.srt': 'text/plain; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.woff': 'font/woff', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8'
};

function sicuro(urlPath) {
  const p = decodeURIComponent((urlPath || '/').split('?')[0]).replace(/\\/g, '/');
  const f = path.normalize(path.join(RADICE, p));
  if (!f.startsWith(RADICE)) return null;                 /* niente ../ fuori dalla cartella */
  return f;
}

const server = http.createServer((req, res) => {
  let f = sicuro(req.url);
  if (!f) { res.writeHead(403); return res.end('no'); }
  try { if (fs.statSync(f).isDirectory()) f = path.join(f, 'index.html'); } catch (e) {}
  fs.stat(f, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); return res.end('Non trovato: ' + req.url); }
    const ext = path.extname(f).toLowerCase();
    const head = { 'Content-Type': MIME[ext] || 'application/octet-stream', 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-cache' };
    const range = req.headers.range;
    if (range) {                                            /* il browser chiede un pezzo del video */
      const m = /bytes=(\d*)-(\d*)/.exec(range);
      let inizio = m && m[1] !== '' ? parseInt(m[1], 10) : 0;
      let fine = m && m[2] !== '' ? parseInt(m[2], 10) : st.size - 1;
      if (isNaN(inizio) || isNaN(fine) || inizio > fine || fine >= st.size) { res.writeHead(416, { 'Content-Range': 'bytes */' + st.size }); return res.end(); }
      head['Content-Range'] = 'bytes ' + inizio + '-' + fine + '/' + st.size;
      head['Content-Length'] = fine - inizio + 1;
      res.writeHead(206, head);
      if (req.method === 'HEAD') return res.end();
      return fs.createReadStream(f, { start: inizio, end: fine }).pipe(res);
    }
    head['Content-Length'] = st.size;
    res.writeHead(200, head);
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(f).pipe(res);
  });
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') { console.log('La porta ' + PORTA + ' è occupata: il player è forse già aperto? Apri http://localhost:' + PORTA + '/'); apri(); }
  else console.error('Errore del server:', e.message);
});

function apri() {
  const url = 'http://localhost:' + PORTA + '/';
  const cmd = process.platform === 'win32' ? 'start "" "' + url + '"' : process.platform === 'darwin' ? 'open "' + url + '"' : 'xdg-open "' + url + '"';
  exec(cmd, () => {});
}

server.listen(PORTA, '127.0.0.1', () => {
  const nVideo = (() => { try { return fs.readdirSync(path.join(RADICE, 'video')).filter(x => /\.mp4$/i.test(x)).length; } catch (e) { return 0; } })();
  console.log('ESPLORA TRAPANI EDU · player locale');
  console.log('Cartella: ' + RADICE);
  console.log('Video presenti: ' + nVideo + (nVideo ? '' : '  ← nessun video: esegui prima scarica-video (vedi LEGGIMI.txt)'));
  console.log('Apro http://localhost:' + PORTA + '/  — per chiudere: Ctrl+C (o chiudi questa finestra)');
  apri();
});
