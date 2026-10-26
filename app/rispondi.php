<?php /* SALE IN CLASSE — QUIZ LIVE · pagina alunno · v1.1b (24/08/2026) */
/* host canonico: Aruba fa 301 non-www -> www e il preflight CORS di
   api.php muore sul redirect (X-EDU-T = richiesta preflighted); inoltre la
   sessione vive per host. Quindi: pagina SEMPRE su www. (fix 24/08) */
if (($_SERVER['HTTP_HOST'] ?? '') === 'alessandromilia.it') {
  header('Location: https://www.alessandromilia.it' . ($_SERVER['REQUEST_URI'] ?? '/'), true, 301);
  exit;
}
?>
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<meta name="robots" content="noindex">
<title>Quiz live — Sale in Classe</title>
<style>
  :root{
    --rosa:#e8788a; --rosa2:#b8506a; --oro:#c9a15a;
    --sale:#faf7f2; --ink:#3a2e2a;
    --c0:#b8506a; --c1:#c9a15a; --c2:#4a7c59; --c3:#3d5a80; --c4:#7d4f9e; --c5:#b05c2a;
  }
  *{box-sizing:border-box; -webkit-tap-highlight-color:transparent}
  html,body{margin:0; min-height:100%;}
  body{
    font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    background:var(--sale); color:var(--ink);
    display:flex; flex-direction:column; align-items:center;
    padding:16px; padding-bottom:32px;
  }
  #vers{position:fixed; bottom:4px; right:8px; font-size:11px; opacity:.45}
  .card{width:100%; max-width:440px; background:#fff; border-radius:20px;
        box-shadow:0 4px 18px rgba(58,46,42,.10); padding:22px; margin-top:14px;}
  h1{font-size:22px; margin:6px 0 2px; color:var(--rosa2); text-align:center}
  .sotto{ text-align:center; font-size:15px; opacity:.8; margin:0 0 14px}
  label{display:block; font-weight:600; margin:12px 0 6px; font-size:16px}
  input{width:100%; font-size:24px; padding:14px; border:2px solid #e5ddd4;
        border-radius:14px; text-align:center; letter-spacing:.08em; background:var(--sale)}
  input:focus{outline:3px solid var(--oro); border-color:var(--oro)}
  button{font-family:inherit; cursor:pointer; border:none; border-radius:16px}
  .btnp{width:100%; min-height:64px; font-size:22px; font-weight:700; color:#fff;
        background:var(--rosa2); margin-top:18px}
  .btnp:active{transform:scale(.98)}
  .btnp[disabled]{opacity:.55}
  .err{background:#fdeaea; color:#8c2f2f; border-radius:12px; padding:10px 14px;
       margin-top:12px; font-size:15px; display:none; text-align:center}
  .masc{width:86px; height:86px; object-fit:contain; display:block; margin:4px auto}
  .masc-emo{font-size:64px; text-align:center; display:none}
  .grande{font-size:44px; font-weight:800; text-align:center; color:var(--rosa2); margin:6px 0}
  .attesa-punti::after{content:'…'; animation:p 1.4s infinite}
  @keyframes p{0%{content:'.'}33%{content:'..'}66%{content:'...'}}

  /* domanda */
  #domTxt{font-size:19px; font-weight:700; text-align:center; margin:2px 0 14px; line-height:1.35}
  .opz{display:flex; flex-direction:column; gap:12px}
  .opz button{
    min-height:72px; display:flex; align-items:center; gap:14px;
    padding:12px 16px; font-size:19px; font-weight:700; color:#fff; text-align:left;
    border-radius:16px; line-height:1.25;
  }
  .opz .forma{font-size:26px; flex:0 0 auto}
  .opz button:active{transform:scale(.985)}
  .opz button.scelta{outline:5px solid var(--ink)}
  .opz button[disabled]{opacity:.5}
  .opz button.scelta[disabled]{opacity:1}
  .fatto{ text-align:center; font-size:17px; margin-top:14px; font-weight:600}

  /* risultato */
  .brilla{animation:brilla 1.1s ease-in-out 2}
  @keyframes brilla{0%,100%{filter:none}50%{filter:brightness(1.7) drop-shadow(0 0 18px var(--oro))}}
  .sciolto{animation:sciolto 1.6s ease-in-out 1}
  @keyframes sciolto{0%{transform:scaleY(1)}40%{transform:scaleY(.35) translateY(28px); opacity:.55}
                     70%{transform:scaleY(1.06)}100%{transform:none; opacity:1}}
  .esito{font-size:24px; font-weight:800; text-align:center; margin-top:8px}
  .esito.ok{color:#2f7a46} .esito.no{color:var(--rosa2)}
  .spiega{ text-align:center; font-size:16px; margin-top:6px; line-height:1.4}

  /* fine */
  .pctc{font-size:54px; font-weight:800; color:var(--oro); text-align:center; margin:4px 0}
  .nasc{display:none}

  /* telefono in ORIZZONTALE (capita spesso in classe): la card diventerebbe
     più alta dello schermo e i pulsanti finirebbero sotto la piega */
  @media (orientation:landscape) and (max-height:520px){
    body{padding:8px}
    .card{max-width:min(96vw,760px);padding:14px 18px;margin-top:6px}
    h1{font-size:19px;margin:2px 0}
    .sotto{font-size:13px;margin-bottom:8px}
    .masc,.masc-emo{display:none}
    label{margin:6px 0 3px;font-size:14px}
    input{font-size:19px;padding:9px}
    .btnp{min-height:50px;font-size:19px;margin-top:10px}
    .opz{display:grid;grid-template-columns:1fr 1fr;gap:9px}
    .opz button{min-height:58px;font-size:17px;padding:9px 12px}
    #domTxt{font-size:17px;margin:2px 0 10px}
    .esito{font-size:20px}
    .sapevi p{font-size:14px}
    .pctc{font-size:38px}
  }
  /* tacche più visibili su schermi molto piccoli */
  @media (max-width:360px){ .tacche i{flex-basis:18px} .opz button{font-size:17px} }
  /* notch e barre di sistema */
  body{padding-left:max(16px,env(safe-area-inset-left));padding-right:max(16px,env(safe-area-inset-right));
       padding-bottom:max(32px,env(safe-area-inset-bottom))}

  /* tacche di progresso (stile Kahoot) */
  .tacche{display:flex; gap:6px; justify-content:center; margin:2px 0 12px}
  .tacche i{flex:0 1 26px; height:7px; border-radius:99px; background:#e5ddd4}
  .tacche i.fatta{background:var(--oro)}
  .tacche i.ora{background:var(--rosa2)}

  /* banner diagonale esito */
  .nastro{position:relative; overflow:hidden; margin:10px -22px 6px; padding:14px 0;
          transform:rotate(-3deg); text-align:center; font-size:26px; font-weight:800;
          color:#fff; box-shadow:0 4px 14px rgba(58,46,42,.18)}
  .nastro.ok{background:#2f7a46} .nastro.no{background:var(--rosa2)}
  @keyframes nastroIn{from{transform:rotate(-3deg) translateX(-110%)}to{transform:rotate(-3deg) translateX(0)}}
  .nastro{animation:nastroIn .45s ease-out}

  /* card Lo sapevi? */
  .sapevi{background:var(--sale); border:2px solid #eadfce; border-radius:16px;
          padding:14px 16px; margin-top:16px; text-align:left}
  .sapevi .tit{font-weight:800; color:var(--rosa2); font-size:15px;
               text-transform:uppercase; letter-spacing:.06em; margin-bottom:6px}
  .sapevi p{margin:0; font-size:16px; line-height:1.45}
  .sapevi img{width:100%; border-radius:12px; margin-top:10px; display:block}
</style>
</head>
<body>
<div id="vers">quiz live v1.1</div>

<!-- ========== SCHERMATA INGRESSO ========== -->
<div class="card" id="sIngresso">
  <img class="masc" id="mascImg1"
       src="https://alessandromilia.it/project/saline/cristalli_di_sale.png"
       alt="" onerror="this.style.display='none';document.getElementById('mascE1').style.display='block'">
  <div class="masc-emo" id="mascE1">🧂</div>
  <h1>Quiz live!</h1>
  <p class="sotto">Entra e gioca con la tua classe</p>
  <label for="pin">PIN sulla LIM</label>
  <input id="pin" inputmode="numeric" pattern="[0-9]*" maxlength="6" placeholder="● ● ● ● ● ●" autocomplete="off">
  <label for="nome">Il tuo soprannome</label>
  <input id="nome" maxlength="14" placeholder="es. FenicotteroRosa" autocomplete="off">
  <button class="btnp" id="btnEntra">Entra ▸</button>
  <div class="err" id="errIn"></div>
</div>

<!-- ========== ATTESA ========== -->
<div class="card nasc" id="sAttesa">
  <img class="masc" src="https://alessandromilia.it/project/saline/cristalli_di_sale.png" alt=""
       onerror="this.style.display='none';this.nextElementSibling.style.display='block'">
  <div class="masc-emo">🧂</div>
  <h1 id="attesaTit">Sei dentro!</h1>
  <p class="sotto" id="attesaNome"></p>
  <p class="grande attesa-punti" style="font-size:24px">Guarda la LIM</p>
  <p class="sotto" id="attesaGioc"></p>
</div>

<!-- ========== DOMANDA ========== -->
<div class="card nasc" id="sDomanda">
  <div class="tacche" id="taccheD"></div>
  <p class="sotto" id="domProg"></p>
  <div id="domTxt"></div>
  <div class="opz" id="opz"></div>
  <div class="fatto nasc" id="fatto">✓ Risposta inviata! Aspetta i risultati…</div>
  <div class="err" id="errDom"></div>
</div>

<!-- ========== RISULTATO DOMANDA ========== -->
<div class="card nasc" id="sRisultato">
  <div class="tacche" id="taccheR"></div>
  <div class="nastro nasc" id="nastro"></div>
  <img class="masc" id="mascR"
       src="https://alessandromilia.it/project/saline/cristalli_di_sale.png" alt=""
       onerror="this.style.display='none';document.getElementById('mascRE').style.display='block'">
  <div class="masc-emo" id="mascRE">🧂</div>
  <div class="esito" id="esitoTxt"></div>
  <div class="spiega" id="esitoSpiega"></div>
  <div class="sapevi nasc" id="sapevi">
    <div class="tit">🧂 Lo sapevi?</div>
    <p id="sapeviTxt"></p>
    <img id="sapeviImg" class="nasc" alt="" loading="lazy">
  </div>
</div>

<!-- ========== FINE ========== -->
<div class="card nasc" id="sFine">
  <img class="masc" src="https://alessandromilia.it/project/saline/cristalli_di_sale.png" alt=""
       onerror="this.style.display='none';this.nextElementSibling.style.display='block'">
  <div class="masc-emo">🧂</div>
  <h1>Fine del quiz!</h1>
  <div class="pctc" id="finePct"></div>
  <p class="sotto">di risposte giuste — <b>tutta la classe insieme!</b></p>
  <div class="spiega" id="fineMie"></div>
  <div class="spiega" style="margin-top:10px">Il sale si ricristallizza sempre:<br>quello che oggi si scioglie, domani brilla. ✨</div>
</div>

<script>
(function(){
'use strict';
var API = 'live.php';
var COLORI = ['var(--c0)','var(--c1)','var(--c2)','var(--c3)','var(--c4)','var(--c5)'];
var FORME  = ['▲','◆','●','■','⬟','★'];
var S = { pin:null, token:null, nome:null, qMostrata:-1, rMostrato:-1, mia:null, timer:null };
var LSK = 'edu_live_alunno';

function $(id){ return document.getElementById(id); }
function mostra(id){
  ['sIngresso','sAttesa','sDomanda','sRisultato','sFine'].forEach(function(s){
    $(s).classList.toggle('nasc', s!==id);
  });
}
function post(action, dati){
  return fetch(API+'?action='+action, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify(dati)
  }).then(function(r){ return r.json(); });
}

/* ---------- ingresso ---------- */
var qs = new URLSearchParams(location.search);
if (qs.get('pin')) $('pin').value = qs.get('pin').replace(/\D/g,'').slice(0,6);

$('btnEntra').addEventListener('click', entra);
$('nome').addEventListener('keydown', function(e){ if(e.key==='Enter') entra(); });

function entra(){
  var pin  = $('pin').value.replace(/\D/g,'');
  var nome = $('nome').value.trim();
  var err  = $('errIn'); err.style.display='none';
  if (pin.length!==6){ err.textContent='Il PIN ha 6 cifre'; err.style.display='block'; return; }
  if (!nome){ err.textContent='Scegli un soprannome'; err.style.display='block'; return; }
  $('btnEntra').disabled = true;
  post('join', {pin:pin, nome:nome}).then(function(j){
    $('btnEntra').disabled = false;
    if (j.err){ err.textContent=j.err; err.style.display='block'; return; }
    S.pin=pin; S.token=j.token; S.nome=j.nome;
    try{ localStorage.setItem(LSK, JSON.stringify({pin:pin, token:j.token, nome:j.nome, t:Date.now()})); }catch(e){}
    $('attesaNome').textContent = 'Ciao '+j.nome+'! Il quiz: '+j.titolo;
    mostra('sAttesa');
    avviaPolling();
  }).catch(function(){ $('btnEntra').disabled=false;
    err.textContent='Rete assente: riprova'; err.style.display='block'; });
}

/* riaggancio dopo un refresh (stessa partita, entro 3h) */
try{
  var mem = JSON.parse(localStorage.getItem(LSK)||'null');
  if (mem && Date.now()-mem.t < 3*3600*1000){
    S.pin=mem.pin; S.token=mem.token; S.nome=mem.nome;
    fetch(API+'?action=stato&pin='+S.pin+'&token='+S.token)
      .then(function(r){return r.json();})
      .then(function(j){
        if (j.ok && j.io_dentro){
          $('attesaNome').textContent='Bentornato '+S.nome+'!';
          mostra('sAttesa'); avviaPolling();
        } else { S.pin=S.token=null; }
      }).catch(function(){});
  }
}catch(e){}

/* ---------- polling ---------- */
function avviaPolling(){
  if (S.timer) clearInterval(S.timer);
  giro();
  S.timer = setInterval(giro, 2000);
}
function giro(){
  if (!S.pin) return;
  fetch(API+'?action=stato&pin='+S.pin+'&token='+S.token)
    .then(function(r){ return r.json(); })
    .then(applica)
    .catch(function(){ /* rete che va e viene: si riprova al giro dopo */ });
}

function applica(j){
  if (j.err){  // stanza chiusa/scaduta
    clearInterval(S.timer);
    $('errIn').textContent = 'La partita è terminata.'; $('errIn').style.display='block';
    mostra('sIngresso'); return;
  }
  if (j.io_dentro === false){
    clearInterval(S.timer);
    $('errIn').textContent = 'Il docente ti ha fatto uscire dalla stanza.';
    $('errIn').style.display='block';
    try{ localStorage.removeItem(LSK); }catch(e){}
    mostra('sIngresso'); return;
  }

  if (j.stato === 'attesa'){
    $('attesaGioc').textContent = j.n_gioc + (j.n_gioc===1?' giocatore':' giocatori') + ' in stanza';
    mostra('sAttesa'); return;
  }

  if (j.stato === 'domanda'){
    if (S.qMostrata !== j.q_idx) disegnaDomanda(j);
    mostra('sDomanda'); return;
  }

  if (j.stato === 'risultati'){
    if (S.rMostrato !== j.q_idx) disegnaRisultato(j);
    mostra('sRisultato'); return;
  }

  if (j.stato === 'fine'){
    clearInterval(S.timer);
    $('finePct').textContent = j.pct_classe + '%';
    $('fineMie').textContent = (typeof j.mie_giuste==='number')
      ? 'Tu hai indovinato '+j.mie_giuste+' su '+j.n_quiz+' — solo tu puoi vederlo 😉' : '';
    try{ localStorage.removeItem(LSK); }catch(e){}
    mostra('sFine');
  }
}

/* ---------- domanda ---------- */
function tacche(el, j){
  var box = document.getElementById(el); if(!box) return;
  box.innerHTML='';
  for (var i=0;i<j.n_quiz;i++){
    var t=document.createElement('i');
    if (i<j.q_idx) t.className='fatta';
    else if (i===j.q_idx) t.className='ora';
    box.appendChild(t);
  }
}
function disegnaDomanda(j){
  S.qMostrata = j.q_idx; S.mia = null;
  tacche('taccheD', j);
  $('domProg').textContent = 'Domanda '+(j.q_idx+1)+' di '+j.n_quiz;
  $('domTxt').textContent  = j.domanda;
  $('fatto').classList.add('nasc');
  $('errDom').style.display='none';
  var box = $('opz'); box.innerHTML='';
  j.opzioni.forEach(function(testo, i){
    var b = document.createElement('button');
    b.style.background = COLORI[i % COLORI.length];
    b.innerHTML = '<span class="forma">'+FORME[i % FORME.length]+'</span><span></span>';
    b.lastElementChild.textContent = testo;
    b.addEventListener('click', function(){ rispondi(j.q_idx, i, b); });
    box.appendChild(b);
  });
}

function rispondi(q, r, btn){
  if (S.mia !== null) return;
  S.mia = r;
  var tutti = $('opz').querySelectorAll('button');
  tutti.forEach(function(b){ b.disabled = true; });
  btn.classList.add('scelta');
  post('risposta', {pin:S.pin, token:S.token, q:q, r:r}).then(function(j){
    if (j.err){
      $('errDom').textContent = j.err; $('errDom').style.display='block';
      S.mia=null; tutti.forEach(function(b){ b.disabled=false; b.classList.remove('scelta'); });
      return;
    }
    $('fatto').classList.remove('nasc');
    try{ navigator.vibrate && navigator.vibrate(30); }catch(e){}       /* conferma tattile */
  }).catch(function(){
    $('errDom').textContent='Rete assente: tocca di nuovo la risposta';
    $('errDom').style.display='block';
    S.mia=null; tutti.forEach(function(b){ b.disabled=false; b.classList.remove('scelta'); });
  });
}

/* ---------- risultato: RICRISTALLIZZAZIONE ---------- */
function disegnaRisultato(j){
  S.rMostrato = j.q_idx;
  try{ navigator.vibrate && navigator.vibrate(j.giusta?[25,60,25]:[90]); }catch(e){}   /* esito: due colpi se giusto */
  tacche('taccheR', j);
  var img = $('mascR'), emo = $('mascRE');
  img.classList.remove('brilla','sciolto'); emo.classList.remove('brilla','sciolto');
  void img.offsetWidth;  // riavvia l'animazione
  var giustaTxt = j.opzioni[j.g];
  var nast = $('nastro');
  nast.classList.remove('nasc');
  void nast.offsetWidth;
  if (j.mia === null || typeof j.mia === 'undefined'){
    nast.textContent = '⏱ Risposte chiuse'; nast.className = 'nastro no';
    $('esitoTxt').textContent = ''; $('esitoTxt').className='esito no';
    $('esitoSpiega').textContent = 'Non hai fatto in tempo. La risposta giusta era: '+giustaTxt;
  } else if (j.giusta){
    img.classList.add('brilla'); emo.classList.add('brilla');
    nast.textContent = '✓ Corretto!'; nast.className = 'nastro ok';
    $('esitoTxt').textContent = 'Cristallo perfetto! ✨'; $('esitoTxt').className='esito ok';
    $('esitoSpiega').textContent = 'Proprio così: '+giustaTxt;
  } else {
    img.classList.add('sciolto'); emo.classList.add('sciolto');
    nast.textContent = '✗ Ops, sciolto'; nast.className = 'nastro no';
    $('esitoTxt').textContent = ''; $('esitoTxt').className='esito no';
    $('esitoSpiega').textContent = 'La risposta giusta era: '+giustaTxt+
      ' — ma il sale si ricristallizza sempre: riprovate!';
  }
  // "Lo sapevi?" — feedback formativo (stile modalità Impara)
  var sap = $('sapevi'), sImg = $('sapeviImg');
  if (j.spiegazione){
    $('sapeviTxt').textContent = j.spiegazione;
    if (j.media){ sImg.src = j.media; sImg.classList.remove('nasc'); }
    else { sImg.classList.add('nasc'); sImg.removeAttribute('src'); }
    sap.classList.remove('nasc');
  } else sap.classList.add('nasc');
}
})();
</script>
</body>
</html>
