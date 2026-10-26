/* ANALISI STATICA — funzioni chiamate ma mai definite (il controllo che avrebbe scovato vidStato) */
const fs = require('fs');
const builtin = new Set(('if for while switch return function catch typeof new await async alert confirm prompt parseInt parseFloat isNaN isFinite ' +
  'encodeURIComponent decodeURIComponent encodeURI String Number Boolean Array Object JSON Math Date RegExp Promise Set Map WeakMap Error TypeError ' +
  'setTimeout clearTimeout setInterval clearInterval fetch requestAnimationFrame cancelAnimationFrame atob btoa escape unescape URL URLSearchParams ' +
  'Uint8Array ArrayBuffer TextEncoder TextDecoder Audio Image Event CustomEvent FormData Blob File FileReader Hls SpeechSynthesisUtterance Intl crypto ' +
  'speechSynthesis history localStorage sessionStorage navigator document window location console Symbol Reflect Proxy structuredClone queueMicrotask ' +
  'getComputedStyle matchMedia open close print focus blur scrollTo postMessage addEventListener removeEventListener dispatchEvent supabase createClient ' +
  'THREE AFRAME QRCode qrcode EduLive VRLogic QR MediaSource XMLHttpRequest AbortController performance Function eval Uint32Array Float32Array Int32Array ' +
  'require module exports process').split(' '));

function pulisci(src) {
  src = src.replace(/<\?php[\s\S]*?\?>/g, 'null');
  src = src.replace(/\/\*[\s\S]*?\*\//g, '');                       // commenti a blocco
  src = src.replace(/(^|[^:\\'"])\/\/[^\n]*/g, '$1');                // commenti di riga (non dentro http://)
  src = src.replace(/'(?:[^'\\\n]|\\.)*'/g, '""');                   // stringhe '
  src = src.replace(/"(?:[^"\\\n]|\\.)*"/g, '""');                   // stringhe "
  src = src.replace(/`(?:[^`\\]|\\.)*`/g, '""');                     // template literal
  return src;
}
function analizza(nome, src) {
  const def = new Set(); let m;
  const regexDef = [
    /(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)\s*\(/g,
    /(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/g,
    /(?:const|let|var)\s+\{([^}]*)\}/g,
    /(?:const|let|var)\s+\[([^\]]*)\]/g,
    /([A-Za-z_$][\w$]*)\s*[:=]\s*(?:async\s*)?(?:function\s*\(|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)/g,
    /\bfunction\s*[\w$]*\s*\(([^)]*)\)/g,
    /\(([^()]*)\)\s*=>/g,
    /([A-Za-z_$][\w$]*)\s*=>/g,
    /\bcatch\s*\(\s*([A-Za-z_$][\w$]*)\s*\)/g
  ];
  const puro = pulisci(src);
  // nomi controllati con `typeof nome` (es. il wrapper UMD `typeof define === 'function' && define.amd`
  // della libreria QR dentro live-lim.js) sono opzionali per costruzione: non vanno segnalati
  for (const g of puro.matchAll(/\btypeof\s+([A-Za-z_$][\w$]*)/g)) def.add(g[1]);
  for (const re of regexDef) while ((m = re.exec(puro))) m[1].split(',').forEach(x => {
    const id = x.trim().split(/[=:\s]/)[0].replace(/^\.\.\./, ''); if (/^[A-Za-z_$][\w$]*$/.test(id)) def.add(id);
  });
  const chiamate = new Map(); const rc = /(^|[^.\w$])([A-Za-z_$][\w$]*)\s*\(/g;
  while ((m = rc.exec(puro))) { const f = m[2]; if (!builtin.has(f) && !def.has(f) && !/^[A-Z]/.test(f)) chiamate.set(f, (chiamate.get(f) || 0) + 1); }
  const lista = [...chiamate.entries()];
  console.log('— ' + nome + ': definite ' + def.size + ' · chiamate NON risolte: ' + lista.length + (lista.length ? '  → ' + lista.map(([f, n]) => f + '×' + n).join(', ') : '  ✓'));
  return lista.length;
}
let tot = 0;
for (const f of ['regia-edu.html', 'index.php', 'live-lim.js', 'rispondi.php', 'attiva.php', 'live.php']) {
  let src = fs.readFileSync(__dirname+'/../app/' + f, 'utf8');
  if (f.endsWith('.php') || f.endsWith('.html')) { const parts = [...src.matchAll(/<script(?![^>]*src)[^>]*>([\s\S]*?)<\/script>/g)].map(x => x[1]); src = parts.join('\n'); }
  if (f === 'live.php') continue;
  tot += analizza(f, src);
}
process.exit(tot ? 1 : 0);
