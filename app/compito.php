<?php
header('X-Content-Type-Options: nosniff');
/* =====================================================================
   ESPLORA TRAPANI EDU · compito.php — il compito a casa (migr. 32)
   Si apre dal link che il docente dà alla classe:
       .../app/compito.php?k=CODICE[&classe=TP-IC12-5A]
   Chiude il «buco della frequenza»: la lezione non finisce in aula, il
   ragazzo rivede la clip e risponde da casa, e l'esito torna al docente.

   Niente account, niente dati personali: l'unità di misura resta la
   CLASSE. Le risposte giuste NON arrivano al telefono: la correzione la
   fa il database (edu_compito_valuta), come per il quiz live.
   Sessione e token come index.php: api.php rifiuta chi non passa da qui.
   ===================================================================== */
session_set_cookie_params([
  'httponly' => true, 'samesite' => 'Lax',
  'secure'   => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
]);
session_start();
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';

if(!isset($_SESSION['edu_t'])){ $_SESSION['edu_t'] = bin2hex(random_bytes(24)); }
if(!isset($_SESSION['edu_k'])){ $_SESSION['edu_k'] = bin2hex(random_bytes(32)); }

$K = isset($_GET['k']) ? strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $_GET['k'])) : '';
?><!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex,nofollow">
<title>Compito · Esplora Trapani Edu</title>
<script src="https://aframe.io/releases/1.5.0/aframe.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>
<style>
  :root{ --rosa:#d6336c; --oro:#b8860b; --ink:#2b2118; --carta:#fdf8f1; }
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;background:var(--carta);color:var(--ink);
    font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
  .wrap{max-width:720px;margin:0 auto;padding:16px 16px calc(24px + env(safe-area-inset-bottom))}
  h1{font-size:22px;margin:4px 0 2px;line-height:1.25}
  .sub{opacity:.75;font-size:14px;margin:0 0 14px}
  .scena{position:relative;width:100%;aspect-ratio:16/9;background:#000;border-radius:14px;overflow:hidden;margin-bottom:6px}
  .scena a-scene{width:100%;height:100%}
  .nota{font-size:13px;opacity:.7;margin:0 0 16px}
  .cmd{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0 18px}
  button{font:inherit;cursor:pointer;border:0;border-radius:999px;padding:12px 18px;font-weight:700;
    background:#efe4d2;color:var(--ink);min-height:48px}
  button.rosa{background:var(--rosa);color:#fff}
  button.oro{background:var(--oro);color:#fff}
  button:disabled{opacity:.45;cursor:default}
  .dom{background:#fff;border:1px solid #eadfce;border-radius:16px;padding:14px 16px;margin:0 0 12px}
  .dom p{margin:0 0 10px;font-weight:700;font-size:17px;line-height:1.35}
  .opz{display:flex;flex-direction:column;gap:8px}
  .opz label{display:flex;align-items:center;gap:10px;background:var(--carta);border:1px solid #eadfce;
    border-radius:12px;padding:12px;min-height:48px;cursor:pointer;font-size:16px}
  .opz input{width:22px;height:22px;accent-color:var(--rosa);flex:0 0 auto}
  .opz label:has(input:checked){border-color:var(--rosa);box-shadow:inset 0 0 0 2px rgba(214,51,108,.25)}
  .giusta{border-color:#2f7d32!important;background:#f1f8f1!important}
  .sbagliata{border-color:#b3261e!important;background:#fdf1f0!important}
  .esito{background:#fff;border:2px solid var(--oro);border-radius:16px;padding:16px;text-align:center;margin:14px 0}
  .esito b{font-size:30px;display:block;color:var(--rosa)}
  .msg{background:#fff;border:1px solid #eadfce;border-radius:14px;padding:18px;text-align:center}
  .privacy{font-size:12px;opacity:.6;margin-top:22px;line-height:1.5}
  @media (prefers-color-scheme: dark){
    :root{ --carta:#1d1a16; --ink:#f5efe6 }
    .dom,.esito,.msg{background:#262220;border-color:#3a342e}
    .opz label{background:#1d1a16;border-color:#3a342e}
    button{background:#3a342e;color:#f5efe6}
  }
</style>
</head>
<body>
<script>
window.EDU_T = <?php echo json_encode($_SESSION['edu_t']); ?>;
window.EDU_K = <?php echo json_encode($_SESSION['edu_k']); ?>;
window.EDU_C = <?php echo json_encode(isset($EDU_TENANT_DEFAULT) ? $EDU_TENANT_DEFAULT : ''); ?>;
window.EDU_BASE = <?php echo json_encode(rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/') . '/'); ?>;
window.EDU_K_COMPITO = <?php echo json_encode($K); ?>;
</script>

<div class="wrap">
  <h1 id="tit">Carico il compito…</h1>
  <p class="sub" id="sub"></p>

  <div id="corpo" hidden>
    <div class="scena" id="scena">
      <a-scene embedded vr-mode-ui="enabled:false" device-orientation-permission-ui="enabled:false" renderer="antialias:true">
        <a-assets><video id="clip" crossorigin="anonymous" playsinline webkit-playsinline preload="metadata" loop></video></a-assets>
        <a-videosphere src="#clip" rotation="0 -90 0"></a-videosphere>
        <a-entity camera look-controls="reverseMouseDrag:false; touchEnabled:true" position="0 0 0"></a-entity>
      </a-scene>
    </div>
    <p class="nota">Trascina col dito per guardarti attorno. Puoi rivedere la clip quante volte vuoi.</p>
    <div class="cmd">
      <button class="rosa" id="bPlay" type="button">▶ Guarda la clip</button>
      <button type="button" id="bInd">⏪ 10s</button>
      <button type="button" id="bAvz">10s ⏩</button>
    </div>

    <form id="form" autocomplete="off"></form>
    <div class="cmd"><button class="oro" id="bInvia" type="button">Consegna le risposte</button></div>
    <div id="esito"></div>
  </div>

  <div class="msg" id="msg" hidden></div>

  <p class="privacy">Non serve registrarsi e non ti chiediamo il nome: al tuo insegnante arriva solo
  il risultato della classe. Il video è ospitato su Bunny Stream.</p>
</div>

<script>
const $=(i)=>document.getElementById(i);
const CDN='https://vz-bedaaab5-085.b-cdn.net/';
const _qs=new URLSearchParams(location.search);
const CLASSE=(_qs.get('classe')||'ANON').toUpperCase().replace(/[^A-Z0-9-]/g,'').slice(0,20)||'ANON';
let COMPITO=null, _hls=null, INVIATO=false;

function esc(s){ const d=document.createElement('div'); d.textContent=String(s==null?'':s); return d.innerHTML.replace(/'/g,'&#39;').replace(/"/g,'&quot;'); }
function hexToBuf(h){ const a=new Uint8Array(h.length/2); for(let i=0;i<a.length;i++)a[i]=parseInt(h.substr(i*2,2),16); return a; }
function b64ToBuf(b){ const s=atob(b), a=new Uint8Array(s.length); for(let i=0;i<s.length;i++)a[i]=s.charCodeAt(i); return a; }

async function eduApi(params,post){
  const r=await fetch((window.EDU_BASE||'')+'api.php?'+params+(window.EDU_C?'&c='+encodeURIComponent(window.EDU_C):''),{
    method:post?'POST':'GET',
    headers:Object.assign({'X-EDU-T':window.EDU_T||''},post?{'Content-Type':'application/json'}:{}),
    body:post?JSON.stringify(post):undefined
  });
  const j=await r.json();
  if(j&&j.enc){
    const key=await crypto.subtle.importKey('raw',hexToBuf(window.EDU_K||''),{name:'AES-CBC'},false,['decrypt']);
    const buf=await crypto.subtle.decrypt({name:'AES-CBC',iv:b64ToBuf(j.iv)},key,b64ToBuf(j.data));
    return JSON.parse(new TextDecoder().decode(buf));
  }
  return j;
}
function avviso(txt){ $('msg').hidden=false; $('msg').textContent=txt; $('tit').textContent='Compito non disponibile'; $('sub').textContent=''; }

/* ---- la clip da rivedere: stesse sorgenti del player (HLS, con mp4 di riserva) ---- */
const vid=()=>document.getElementById('clip');
function sorgente(){
  const c=(COMPITO&&COMPITO.clip)||{}, g=c.guid||'';
  if(!g){ $('scena').hidden=true; document.querySelector('.nota').hidden=true; document.querySelector('.cmd').hidden=true; return; }
  const v=vid(), hls=CDN+g+'/playlist.m3u8', mp4=CDN+g+'/play_720p.mp4';
  if(window.Hls&&Hls.isSupported()){
    _hls=new Hls(); _hls.loadSource(hls); _hls.attachMedia(v);
    _hls.on(Hls.Events.ERROR,(e,d)=>{ if(d&&d.fatal){ try{_hls.destroy();}catch(x){} _hls=null; v.src=mp4; v.load(); } });
  } else if(v.canPlayType('application/vnd.apple.mpegurl')){ v.src=hls; }
  else { v.src=mp4; }
  const da=Number(c.da||0);
  v.addEventListener('loadedmetadata',()=>{ if(da>0)try{v.currentTime=da;}catch(e){} },{once:true});
  /* la clip è una finestra dentro il video: arrivati alla fine si torna all'inizio */
  v.addEventListener('timeupdate',()=>{
    const a=Number(c.a||0);
    if(a>0&&v.currentTime>a){ v.currentTime=da>0?da:0; }
  });
}
function entro(t){
  const c=(COMPITO&&COMPITO.clip)||{}, da=Number(c.da||0), a=Number(c.a||0);
  let x=t; if(da>0&&x<da)x=da; if(a>0&&x>a)x=a;
  return Math.max(0,x);
}
function salta(s){ const v=vid(); if(!v.duration)return; v.currentTime=entro((v.currentTime||0)+s); }

/* ---- domande ---- */
function disegnaDomande(){
  const f=$('form'); f.innerHTML='';
  (COMPITO.domande||[]).forEach((d,i)=>{
    const box=document.createElement('div'); box.className='dom'; box.id='d'+i;
    const p=document.createElement('p'); p.textContent=(i+1)+'. '+(d.domanda||''); box.appendChild(p);
    const o=document.createElement('div'); o.className='opz';
    (d.opzioni||[]).forEach((t,j)=>{
      const lab=document.createElement('label'); lab.id='o'+i+'_'+j;
      const inp=document.createElement('input');
      inp.type='radio'; inp.name='q'+i; inp.value=String(j);
      lab.appendChild(inp);
      const sp=document.createElement('span'); sp.textContent=t; lab.appendChild(sp);
      o.appendChild(lab);
    });
    box.appendChild(o); f.appendChild(box);
  });
}
function risposteDate(){
  return (COMPITO.domande||[]).map((d,i)=>{
    const s=document.querySelector('input[name="q'+i+'"]:checked');
    return s?Number(s.value):null;
  });
}

async function invia(){
  if(INVIATO)return;
  const r=risposteDate();
  const mancanti=r.filter(x=>x===null).length;
  if(mancanti && !confirm('Hai lasciato '+mancanti+(mancanti===1?' domanda senza risposta.':' domande senza risposta.')+'\nConsegnare comunque?'))return;
  $('bInvia').disabled=true; $('bInvia').textContent='Invio…';
  let j=null;
  try{ j=await eduApi('action=consegna',{k:COMPITO.codice,classe:CLASSE,risposte:r}); }catch(e){}
  if(!j||!j.ok){
    $('bInvia').disabled=false; $('bInvia').textContent='Consegna le risposte';
    $('esito').innerHTML='<div class="esito">Non riesco a inviare le risposte. Controlla la connessione e riprova.</div>';
    return;
  }
  INVIATO=true;
  /* riscontro: cosa era giusto e cosa no (lo dice il server, non la pagina) */
  (j.esito||[]).forEach(e=>{
    const scelta=document.querySelector('input[name="q'+e.n+'"]:checked');
    if(scelta){ const lab=scelta.closest('label'); if(lab)lab.classList.add(e.giusta?'giusta':'sbagliata'); }
    if(!e.giusta && e.ok!==undefined){ const buona=$('o'+e.n+'_'+e.ok); if(buona)buona.classList.add('giusta'); }
    document.querySelectorAll('input[name="q'+e.n+'"]').forEach(x=>x.disabled=true);
  });
  const pct=j.n_domande?Math.round(100*j.n_giuste/j.n_domande):0;
  $('esito').innerHTML='<div class="esito"><b>'+j.n_giuste+' / '+j.n_domande+'</b>'+
    (pct>=80?'Bravissimo! Hai capito la lezione.':pct>=50?'Bene! Rivedi la clip sulle domande sbagliate.':'Riguarda la clip con calma: le risposte sono tutte lì.')+
    '</div>';
  $('bInvia').style.display='none';
  $('esito').scrollIntoView({behavior:'smooth',block:'center'});
}

async function avvia(){
  const k=window.EDU_K_COMPITO||'';
  if(!/^[A-Z0-9]{6,12}$/.test(k)){ avviso('Il link del compito non è completo. Chiedi di nuovo il link al tuo insegnante.'); return; }
  let j=null;
  try{ j=await eduApi('action=compito&k='+encodeURIComponent(k)); }catch(e){}
  if(!j||!j.ok||!j.compito){ avviso('Questo compito non è più disponibile: può essere scaduto o essere stato chiuso dall\'insegnante.'); return; }
  COMPITO=j.compito;
  const b=COMPITO.brand||{};
  document.title=(COMPITO.titolo||'Compito')+' · '+(b.titolo||'Esplora Trapani Edu');
  $('tit').textContent=COMPITO.titolo||'Compito';
  $('sub').textContent=(COMPITO.consegna||'')+(COMPITO.scadenza?'  ·  da consegnare entro il '+COMPITO.scadenza.split('-').reverse().join('/'):'');
  $('corpo').hidden=false;
  sorgente(); disegnaDomande();
  if(!(COMPITO.domande||[]).length){ $('bInvia').style.display='none'; }
}

$('bPlay').addEventListener('click',()=>{
  const v=vid();
  if(v.paused){ v.play().catch(()=>{ v.muted=true; v.play().catch(()=>{}); }); $('bPlay').textContent='⏸ Pausa'; }
  else { v.pause(); $('bPlay').textContent='▶ Guarda la clip'; }
});
$('bInd').addEventListener('click',()=>salta(-10));
$('bAvz').addEventListener('click',()=>salta(10));
$('bInvia').addEventListener('click',invia);
avvia();
</script>
</body>
</html>
