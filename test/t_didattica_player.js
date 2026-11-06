/* TEST player v2.4 — blocco didattico (migr. 32)
   Comandi ⏪10s/⏩10s, lezione precedente/successiva, scheda per il docente,
   percorso della classe nel menu, esito salvato come evidenza valutativa.
   Gira su /tmp/pag.html (prodotto da rendi-player.sh). Nessun servizio esterno. */
const { JSDOM } = require('jsdom'); const fs = require('fs');

const DID_LEZ = {
  obiettivi:{primaria:['descrive il lavoro del salinaio'],medie:['spiega il ciclo del sale']},
  parole_chiave:['salina','vasca salante'],
  prima:'Chiedere da dove arriva il sale che hanno in cucina.',
  durante:'Fermare il video alla pala e far descrivere il gesto.',
  dopo:'Disegnare la vasca e nominarne le parti.',
  materiali:['quaderno','sale grosso'], collegamenti:'Libro di storia, cap. 3'
};
const DID_CORSO = { traguardi:{primaria:['riconosce le tracce del passato nel territorio'],medie:['usa fonti materiali']},
                    discipline:['storia','geografia'] };

const LEZ_A={id:'salinaio',tit:'Il salinaio',stato:'pubblicata'};
const LEZ_B={id:'corallaio',tit:'Il corallaio',stato:'pubblicata'};
const LEZ_C={id:'tappeti',tit:'I tappeti di Erice',stato:'soon'};
const MENU={ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:true,senior:true},
  cliente:{nome:'Esplora Trapani',brand:{titolo:'Antichi Mestieri'},limiti:{quiz_live:true}},
  corsi:[{id:'mestieri',tit:'Antichi Mestieri',em:'🛠️',stato:'pubblicato',origine:'proprio',
          didattica:DID_CORSO,lezioni:[LEZ_A,LEZ_B,LEZ_C]}],
  lezioni:[LEZ_A,LEZ_B,LEZ_C]};
const lezione=(id,tit,did)=>({ok:true,lezione:{id:id,tit:tit,intro:'Guardate',coccio:null,didattica:did,
  corso:{id:'mestieri',tit:'Antichi Mestieri',didattica:DID_CORSO},
  video:[{guid:'g-'+id}],tappe:[],quiz:[{q:'D1?',opts:['a','b'],ok:0},{q:'D2?',opts:['a','b'],ok:1}],quiz2:null}});
const DIARIO={ok:true,diario:[
  {corso:'mestieri',lezione:'salinaio',tit:'Il salinaio',ordine:1,fatta:true,quando:'2027-01-12T10:00:00Z',volte:2,pct:80},
  {corso:'mestieri',lezione:'corallaio',tit:'Il corallaio',ordine:2,fatta:false,quando:null,volte:0,pct:null}]};

function dom(opt){
  opt=opt||{};
  let html=fs.readFileSync('/tmp/pag.html','utf8');
  const mock=`<script>window.__url=[];window.__post=[];
    window.fetch=(u,o)=>{const s=String(u); window.__url.push(s);
      if(o&&o.body)window.__post.push({u:s,b:JSON.parse(o.body)});
      let b='{"ok":true}';
      if(s.includes('action=menu'))b=${JSON.stringify(JSON.stringify(MENU))};
      else if(s.includes('action=diario'))b=${JSON.stringify(JSON.stringify(DIARIO))}${opt.senzaDiario?".replace(/.*/, '{\"ok\":true,\"diario\":[]}')":''};
      else if(s.includes('action=lezione')){
        const id=(s.match(/[?&]id=([^&]+)/)||[])[1]||'salinaio';
        b=JSON.stringify(window.__lez[id]||window.__lez.salinaio);
      }
      return Promise.resolve({json:()=>Promise.resolve(JSON.parse(b))});};
    window.__lez=${JSON.stringify({salinaio:lezione('salinaio','Il salinaio',DID_LEZ),
                                   corallaio:lezione('corallaio','Il corallaio',{})})};
    window.AFRAME={registerComponent(){}};window.Hls=undefined;
    window.alert=(m)=>{window.__alert=m};window.confirm=()=>true;window.EduLive={apri(){}};</script>`;
  html=html.replace('<head>','<head>'+mock).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const D=new JSDOM(html,{url:opt.url||'http://localhost/index.php?classe=ICPA-5A',runScripts:'dangerously',pretendToBeVisual:true});
  const st=new WeakMap(), tm=new WeakMap();
  Object.defineProperty(D.window.HTMLMediaElement.prototype,'paused',{configurable:true,get(){const s=st.get(this);return s===undefined?true:s;}});
  Object.defineProperty(D.window.HTMLMediaElement.prototype,'duration',{configurable:true,get(){return 120;}});
  Object.defineProperty(D.window.HTMLMediaElement.prototype,'currentTime',{configurable:true,
    get(){return tm.get(this)||0;},set(v){tm.set(this,v);}});
  D.window.HTMLMediaElement.prototype.play=function(){st.set(this,false);return Promise.resolve();};
  D.window.HTMLMediaElement.prototype.pause=function(){st.set(this,true);};
  D.window.HTMLMediaElement.prototype.load=function(){};
  return D;
}
const at=ms=>new Promise(r=>setTimeout(r,ms));
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};

(async()=>{
  console.log('— A. comandi di navigazione nella barra docente —');
  const D=dom(); const w=D.window, d=D.window.document; await at(500);
  ok('⏪ e ⏩ presenti con etichetta leggibile dai lettori di schermo',
     d.getElementById('btnIndietro').getAttribute('aria-label').includes('Indietro')
     && d.getElementById('btnAvanti').getAttribute('aria-label').includes('Avanti'));
  ok('‹ e › per lezione precedente/successiva presenti',
     !!d.getElementById('btnPrec') && !!d.getElementById('btnSucc'));
  ok('📋 scheda della lezione presente', !!d.getElementById('btnScheda'));
  ok('fuori da una lezione i tasti ‹ › sono spenti',
     d.getElementById('btnPrec').disabled && d.getElementById('btnSucc').disabled);

  console.log('— B. percorso della classe nel menu (diario dal server) —');
  ok('il diario è stato chiesto al server col codice classe',
     w.__url.some(u=>u.includes('action=diario')&&u.includes('classe=ICPA-5A')));
  const cards=[...d.querySelectorAll('#menuLez .lez')];
  const cSal=cards.find(b=>b.textContent.includes('Il salinaio'));
  const cCor=cards.find(b=>b.textContent.includes('Il corallaio'));
  ok('lezione già svolta: segnata come fatta, con esito e numero di volte',
     cSal.classList.contains('fatta') && cSal.textContent.includes('80%') && cSal.textContent.includes('2 volte'));
  ok('lezione non svolta: nessun segno di completamento', !cCor.classList.contains('fatta'));
  const cTap=cards.find(b=>b.textContent.includes('I tappeti'));
  ok('lezione «prossimamente» resta bloccata', cTap.disabled && cTap.textContent.includes('Prossimamente'));

  console.log('— C. avanti/indietro di 10 secondi —');
  w.avviaLezione(0); await at(400);
  if(d.getElementById('prologoBtn'))try{d.getElementById('prologoBtn').click();}catch(e){}
  await at(150);
  const v=d.getElementById('vid');
  v.currentTime=50;
  w.saltaVideo(10);
  ok('⏩ sposta avanti di 10 secondi', Math.abs(v.currentTime-60)<0.01);
  w.saltaVideo(-10);
  ok('⏪ torna indietro di 10 secondi', Math.abs(v.currentTime-50)<0.01);
  v.currentTime=3; w.saltaVideo(-10);
  ok('all inizio del video non va in negativo', v.currentTime===0);
  v.currentTime=118; w.saltaVideo(10);
  ok('alla fine del video non supera la durata', v.currentTime<=119.7 && v.currentTime>=119.6);

  console.log('— D. lezione precedente e successiva —');
  w.updNav();
  ok('prima lezione: ‹ spento, › acceso', d.getElementById('btnPrec').disabled && !d.getElementById('btnSucc').disabled);
  w.lezioneSucc(); await at(400);
  const inj=(c)=>{const s=d.createElement('script');s.textContent=c;d.body.appendChild(s);};
  inj('window.__lezId=LEZ?LEZ.id:null;window.__lezIdx=lezIdx;');
  ok('› apre la lezione successiva', w.__lezId==='corallaio' && w.__lezIdx===1);
  w.updNav();
  ok('ultima lezione apribile: › spento (quella dopo è «prossimamente»)', d.getElementById('btnSucc').disabled);
  ok('‹ ora è acceso', !d.getElementById('btnPrec').disabled);
  w.lezionePrec(); await at(400);
  inj('window.__lezId2=LEZ?LEZ.id:null;');
  ok('‹ torna alla lezione precedente', w.__lezId2==='salinaio');

  console.log('— E. scheda della lezione (per il docente) —');
  w.apriScheda(); await at(60);
  const sb=d.getElementById('schedaBody').textContent;
  ok('la scheda si apre', d.getElementById('scheda').classList.contains('on'));
  ok('il video si mette in pausa quando si apre la scheda', d.getElementById('vid').paused);
  ok('mostra obiettivi del livello, prima, durante e dopo',
     sb.includes('descrive il lavoro del salinaio') && sb.includes('Chiedere da dove arriva')
     && sb.includes('Fermare il video') && sb.includes('Disegnare la vasca'));
  ok('mostra i traguardi del corso e le parole chiave',
     sb.includes('riconosce le tracce del passato') && sb.includes('vasca salante'));
  ok('mostra materiali e collegamenti al libro', sb.includes('sale grosso') && sb.includes('cap. 3'));
  ok('al livello medie mostra gli obiettivi delle medie, non quelli della primaria',
     (()=>{ w.chiudiScheda(); w.setLivello('senior'); w.apriScheda();
            const t=d.getElementById('schedaBody').textContent;
            const giusto=t.includes('spiega il ciclo del sale') && !t.includes('descrive il lavoro del salinaio');
            w.chiudiScheda(); w.setLivello('junior'); return giusto; })());
  w.chiudiScheda();
  ok('chiudendo la scheda la lezione riprende', !d.getElementById('scheda').classList.contains('on') && !d.getElementById('vid').paused);

  console.log('— F. scheda non compilata e testo malevolo —');
  w.lezioneSucc(); await at(400);     /* corallaio: didattica vuota */
  w.apriScheda(); await at(50);
  ok('senza didattica la scheda lo dice, non resta vuota',
     d.getElementById('schedaBody').textContent.includes('non è ancora stata compilata'));
  w.chiudiScheda();
  inj(`LEZ.didattica={prima:"<img src=x onerror=window.__xss=1>",parole_chiave:["<b>grassetto</b>"]};`);
  w.apriScheda(); await at(60);
  ok('la scheda non esegue HTML messo nei campi didattici (niente XSS)',
     w.__xss===undefined && d.getElementById('schedaBody').querySelectorAll('img,script,iframe').length===0);
  ok('…e il testo si vede comunque come scritto',
     d.getElementById('schedaBody').textContent.includes('<img src=x') && d.getElementById('schedaBody').textContent.includes('<b>grassetto</b>'));
  w.chiudiScheda();

  console.log('— G. esito della lezione salvato come evidenza —');
  w.__post.length=0;
  w.avviaLezione(0); await at(400);
  if(d.getElementById('prologoBtn'))try{d.getElementById('prologoBtn').click();}catch(e){}
  await at(120);
  inj('punti=2;quizIdx=99;fineLezione();'); await at(400);
  const es=w.__post.find(x=>x.u.includes('action=esito'));
  ok('a fine lezione il player invia l esito ad api.php', !!es);
  ok('l esito porta classe, lezione, livello e modalità aula',
     es && es.b.classe==='ICPA-5A' && es.b.lezione==='salinaio' && es.b.modalita==='aula' && es.b.livello==='junior');
  ok('l esito porta il punteggio sulle domande del quiz', es && es.b.n_giuste===2 && es.b.n_domande===2);
  ok('nel dettaglio nessun nome di alunno, solo le domande',
     es && JSON.stringify(es.b.dettaglio).indexOf('nick')<0 && Array.isArray(es.b.dettaglio.per_domanda));
  ok('la schermata finale propone la lezione successiva col suo titolo',
     d.getElementById('btnFineSucc').style.display!=='none' && d.getElementById('btnFineSucc').textContent.includes('Il corallaio'));
  d.getElementById('btnFineSucc').click(); await at(400);
  inj('window.__lezId3=LEZ?LEZ.id:null;');
  ok('«Prossima lezione» apre davvero la lezione dopo', w.__lezId3==='corallaio');

  console.log('— H. esito del quiz live —');
  w.__post.length=0;
  d.dispatchEvent(new w.CustomEvent('edu-live-fine',{detail:{lezione:'corallaio',livello:'junior',
    pct_classe:75,n_gioc:22,n_quiz:4,recap:[{domanda:'D1?',pct:100,tot:22},{domanda:'D2?',pct:50,tot:22}]}}));
  await at(300);
  const el=w.__post.find(x=>x.u.includes('action=esito'));
  ok('anche il quiz live lascia un esito salvato', !!el && el.b.modalita==='live');
  ok('con il numero di partecipanti e il punteggio di classe',
     el && el.b.n_partecipanti===22 && el.b.n_domande===4 && el.b.n_giuste===3);
  ok('nel dettaglio del live niente nickname, solo l aggregato per domanda',
     el && JSON.stringify(el.b.dettaglio).indexOf('nome')<0 && el.b.dettaglio.per_domanda.length===2);

  console.log('— I. senza codice classe non si tracciano esiti di classe —');
  const D3=dom({url:'http://localhost/index.php'});
  await at(500);
  ok('senza ?classe= il diario non viene nemmeno chiesto', !D3.window.__url.some(u=>u.includes('action=diario')));
  ok('…e il menu si costruisce comunque', D3.window.document.querySelectorAll('#menuLez .lez').length>0);

  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti');
  process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e&&e.message,e&&e.stack);process.exit(1);});
