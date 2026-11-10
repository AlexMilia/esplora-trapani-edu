/* TEST player v2.9 — il corso che si apre con la MAPPA

   Nasce con l'area «Trapani, la città a forma di falce»: undici lezioni girate
   in undici punti del centro storico. Invece delle solite card, il corso mostra
   una mappa con un segnaposto per lezione e il titolo scritto sopra.

   Le richieste, una per una, e qui sotto la verifica di ognuna:
     · mouse (PC collegato alla lavagna): passando sopra il titolo si ingrandisce, un clic apre
     · dito (LIM): il primo tocco ingrandisce, il secondo apre
     · la mappa inquadra SOLO i punti presenti, non tutta la provincia
     · elenco e legenda a fianco
     · chi usa la modalità ipovedenti continua ad avere l'elenco grande
     · se la mappa non si carica, la classe non resta a piedi: torna l'elenco

   Leaflet qui è finto (jsdom non disegna): registra che cosa gli viene chiesto.
   Il disegno vero, con hover e tocchi veri, si prova in Chromium: vedi
   LEGGIMI-TEST.md, «Prova in un browser vero».
   Gira su /tmp/pag.html (prodotto da rendi-player.sh). Nessun servizio esterno. */
const { JSDOM, VirtualConsole } = require('jsdom'); const fs = require('fs'); const path = require('path');

let P=0,F=0; const ok=(n,c)=>{ if(c){P++;console.log('  ✓ '+n);} else {F++;console.log('  ❌ '+n);} };
const at=ms=>new Promise(r=>setTimeout(r,ms));

const lz=(id,tit,lat,lng,nome,extra)=>Object.assign({id,tit,sub:'',em:'📍',cls:'rosa',durata:'~3 min',stato:'pubblicata',acc:{ipovedenti:true},luogo:(lat===null?null:{nome,lat,lng})},extra||{});
const TRAPANI=[
  lz('t-cappuccini','Tutto al femminile',38.01676,12.50095,'Chiesa dei Cappuccini'),
  lz('t-lucia','La santa dei corallari',38.01702,12.50254,'Ex chiesa di Santa Lucia'),
  lz('t-collegio','Chiesa del Collegio',38.01569,12.50903,'Chiesa del Collegio dei Gesuiti',{durata:'~14 min'}),
  lz('t-xss','<img src=x onerror="window.__bucato=1">',38.01536,12.50961,'<b>Palazzo</b>'),
  lz('t-presto','In arrivo',38.0176,12.5156,'Villa Margherita',{stato:'soon'}),
  lz('t-senza','Lezione senza luogo',null),
];
const MESTIERI=[lz('salinaio','Il salinaio',null),lz('corallo','Il corallo',null)];
const corso=(id,tit,lezioni,did)=>({id,tit,em:'⚓',cls:'blu',stato:'pubblicato',origine:'proprio',didattica:did||{},lezioni});
const MENU=(corsi)=>({ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:true,senior:true},
  cliente:{nome:'Esplora Trapani',brand:{titolo:'Esplora Edu'},limiti:{quiz_live:true}},corsi,lezioni:[]});
const DUE=[corso('mestieri','Antichi Mestieri',MESTIERI),corso('trapani','Trapani, la città a forma di falce',TRAPANI,{mappa:true})];

/* Leaflet finto: tiene nota di ciò che il player gli chiede */
const LEAFLET_FINTO=`window.__L={mappe:0,tolte:0,fit:null,tasselli:null,opzioni:null,linea:null};
  window.L={
    latLng:(a,b)=>({lat:a,lng:b}),
    latLngBounds:(p)=>({punti:p}),
    map:(el,o)=>{ window.__L.mappe++; window.__L.opzioni=o; const ev={};
      return {el, attributionControl:{setPrefix(){}}, on(n,f){ev[n]=f;return this;}, __ev:ev,
        invalidateSize(){}, fitBounds(b,o){window.__L.fit={b,o};}, getZoom:()=>16,
        latLngToContainerPoint:(ll)=>({x:(ll.lng-12.5)*40000,y:(38.02-ll.lat)*40000}),
        getBounds:()=>({pad:()=>({contains:()=>true})}), panTo(){}, remove(){window.__L.tolte++;}}; },
    tileLayer:(u,o)=>{ window.__L.tasselli={u,o}; return {addTo(){return this;}}; },
    polyline:(p,o)=>{ window.__L.linea={p,o}; return {addTo(){return this;}}; },
    divIcon:(o)=>o,
    marker:(ll,o)=>({addTo(m){ const d=document.createElement('div'); d.className='leaflet-marker-icon '+o.icon.className; d.appendChild(o.icon.html); m.el.appendChild(d); return this; }})
  };`;

function dom(corsi, conLeaflet){
  let html=fs.readFileSync('/tmp/pag.html','utf8');
  const mock=`<script>
    window.fetch=(u,o)=>{const s=String(u); let b='{"ok":true}';
      if(s.includes('action=menu'))b=${JSON.stringify(JSON.stringify(MENU(corsi)))};
      else if(s.includes('action=diario'))b='{"ok":true,"diario":[]}';
      return Promise.resolve({ok:true,text:()=>Promise.resolve(''),json:()=>Promise.resolve(JSON.parse(b))});};
    ${conLeaflet?LEAFLET_FINTO:''}
    window.AFRAME={registerComponent(){}};window.Hls=undefined;
    window.alert=()=>{};window.confirm=()=>true;window.EduLive={apri(){}};</script>`;
  html=html.replace('<head>','<head>'+mock).replace(/<script src="[^"]*live-lim\.js[^"]*"><\/script>/,'');
  return new JSDOM(html,{url:'http://localhost/index.php?classe=PROVA-1',runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:new VirtualConsole()});
}
function punta(w,el,tipo,evento){ const e=new w.Event(evento,{bubbles:evento!=='pointerenter'&&evento!=='pointerleave',cancelable:true}); e.pointerType=tipo; el.dispatchEvent(e); }
function tocca(w,el,tipo){ punta(w,el,tipo,'pointerdown'); el.click(); }
const corsoIdx=(w,id)=>w.eval('CORSI.findIndex(c=>c.id==="'+id+'")');

(async()=>{
  /* ================= 1. il corso con la mappa ================= */
  console.log('== un corso con didattica.mappa si apre con la mappa ==');
  let D=dom(DUE,true), w=D.window, d=w.document; await at(600);
  ok('con due corsi si parte dalle card dei corsi, senza mappa', d.querySelectorAll('#menuLez .lez.corso').length===2 && !d.querySelector('.mp'));
  w.scegliCorso(corsoIdx(w,'mestieri')); await at(50);
  ok('il corso SENZA mappa mostra le card di sempre', d.querySelectorAll('#menuLez .lez').length===2 && !d.querySelector('.mp') && w.__L.mappe===0);
  w.tuttiICorsi(); w.scegliCorso(corsoIdx(w,'trapani')); await at(80);
  const aperte=[]; w.avviaLezione=(i)=>{ aperte.push(w.eval('CATALOGO['+i+'].id')); };
  ok('il corso con la mappa disegna la mappa', !!d.querySelector('.mp #mpLeaf') && w.__L.mappe===1);
  ok('la card si allarga per fare posto alla mappa', d.querySelector('#menu .card').classList.contains('conmappa'));
  const pin=[...d.querySelectorAll('.mp-pin')], righe=[...d.querySelectorAll('.mp-riga')];
  ok('un segnaposto per ogni lezione che ha un luogo (5 su 6)', pin.length===5);
  ok('nell\'elenco a fianco ci sono tutte le lezioni, anche quella senza luogo (6)', righe.length===6);
  ok('sul segnaposto si legge il titolo della lezione', pin[0].querySelector('.lab').textContent.indexOf('Tutto al femminile')===0);
  ok('…e, da ingrandito, anche il nome del luogo', pin[2].querySelector('.det').textContent.indexOf('Chiesa del Collegio dei Gesuiti')===0);
  ok('i segnaposto sono numerati nell\'ordine del percorso', pin.map(p=>p.querySelector('.dot').textContent).join(',')==='1,2,3,4,5');
  ok('c\'è la legenda', !!d.querySelector('.mp-leg') && /Lezione fatta/.test(d.querySelector('.mp-leg').textContent) && /Prossima consigliata/.test(d.querySelector('.mp-leg').textContent));
  ok('il tasto «Tutti i corsi» c\'è ancora', [...d.querySelectorAll('.mp-testa .tbtn')].some(b=>/Tutti i corsi/.test(b.textContent)));

  console.log('== la mappa inquadra i punti presenti, non la provincia ==');
  const fit=w.__L.fit, pt=fit&&fit.b.punti;
  ok('l\'inquadratura è calcolata sui punti delle lezioni (5 punti)', !!pt && pt.length===5);
  ok('…ed è larga quanto i punti: da 12.50095 a 12.5156 di longitudine', !!pt && Math.min(...pt.map(p=>p.lng))===12.50095 && Math.max(...pt.map(p=>p.lng))===12.5156);
  ok('…non si allontana oltre il necessario e non entra oltre il livello 18', fit.o.maxZoom===18);
  ok('la linea del percorso passa dai punti nell\'ordine delle lezioni', w.__L.linea && w.__L.linea.p.length===5 && w.__L.linea.p[0].lng===12.50095);
  ok('i tasselli sono quelli di OpenStreetMap, con la citazione obbligatoria', /tile\.openstreetmap\.org/.test(w.__L.tasselli.u) && /OpenStreetMap/.test(w.__L.tasselli.o.attribution));
  ok('due tocchi svelti non ingrandiscono la mappa (doppio clic spento)', w.__L.opzioni.doubleClickZoom===false);

  console.log('== mouse: passare sopra ingrandisce, un clic apre ==');
  punta(w,pin[1],'mouse','pointerenter');
  ok('passando sopra, il segnaposto si accende (il titolo si ingrandisce via CSS)', pin[1].classList.contains('on'));
  ok('…e si accende la riga corrispondente nell\'elenco', righe[1].classList.contains('on'));
  punta(w,pin[1],'mouse','pointerleave');
  ok('uscendo si spegne', !pin[1].classList.contains('on') && !righe[1].classList.contains('on'));
  punta(w,righe[2],'mouse','pointerenter');
  ok('passando sulla riga si accende il segnaposto', pin[2].classList.contains('on'));
  punta(w,righe[2],'mouse','pointerleave');
  tocca(w,pin[1],'mouse');
  ok('un clic del mouse apre subito la lezione giusta', aperte.join()==='t-lucia');
  const regole=fs.readFileSync('/tmp/pag.html','utf8').match(/\.mp-pin\.on \.lab[^{]*\{[^}]*\}/g)||[];
  ok('l\'ingrandimento del titolo è nel foglio di stile (scale 1.3)', regole.some(r=>/transform:scale\(1\.3\)/.test(r)));

  console.log('== dito: il primo tocco ingrandisce, il secondo apre ==');
  aperte.length=0;
  tocca(w,pin[0],'touch');
  ok('il primo tocco NON apre la lezione', aperte.length===0);
  ok('il primo tocco ingrandisce il titolo', pin[0].classList.contains('on'));
  ok('compare la barra con il tasto «Apri la lezione»', d.querySelector('.mp-apri').classList.contains('on') && d.querySelector('.mp-apri b').textContent==='Tutto al femminile');
  tocca(w,pin[2],'touch');
  ok('toccare un altro punto sposta la scelta, senza aprire', aperte.length===0 && !pin[0].classList.contains('on') && pin[2].classList.contains('on'));
  tocca(w,pin[2],'touch');
  ok('il secondo tocco sullo stesso punto apre', aperte.join()==='t-collegio');
  aperte.length=0; tocca(w,pin[0],'pen');
  ok('la penna della LIM si comporta come il dito', aperte.length===0 && pin[0].classList.contains('on'));
  d.querySelector('.mp-apri button').click();
  ok('il tasto «Apri la lezione» apre il punto scelto', aperte.join()==='t-cappuccini');
  aperte.length=0; tocca(w,righe[1],'touch');
  ok('nell\'elenco, dove il titolo si legge già, un tocco apre', aperte.join()==='t-lucia');
  aperte.length=0;
  const k=new w.KeyboardEvent('keydown',{key:'Enter',bubbles:true}); pin[1].dispatchEvent(k); pin[1].click();
  ok('da tastiera Invio apre (anche dopo aver usato il dito)', aperte.join()==='t-lucia');

  console.log('== stati, lezioni non pronte, testi ostili ==');
  aperte.length=0; tocca(w,pin[4],'mouse'); righe[4].click();
  ok('la lezione «prossimamente» non si apre né dalla mappa né dall\'elenco', aperte.length===0 && righe[4].disabled && pin[4].classList.contains('soon'));
  tocca(w,righe[5],'mouse');
  ok('la lezione senza luogo si apre dall\'elenco', aperte.join()==='t-senza');
  ok('la prima lezione non fatta è segnata come «prossima»', pin[0].classList.contains('prossima') && righe[0].classList.contains('prossima') && d.querySelectorAll('.mp-pin.prossima').length===1);
  w.eval("DIARIO['t-cappuccini']={fatta:true,pct:80,volte:1}"); w.buildMenu(); await at(60);
  const pin2=[...d.querySelectorAll('.mp-pin')], righe2=[...d.querySelectorAll('.mp-riga')];
  ok('dopo aver fatto la prima: segnaposto e riga diventano «fatta», con il voto del quiz', pin2[0].classList.contains('fatta') && /fatta · 80%/.test(righe2[0].textContent));
  ok('…e la «prossima» passa alla seconda', pin2[1].classList.contains('prossima') && !pin2[0].classList.contains('prossima'));
  ok('ridisegnando non restano mappe doppie (la vecchia viene smontata)', d.querySelectorAll('.mp').length===1 && w.__L.mappe===2 && w.__L.tolte===1);
  ok('un titolo con codice dentro resta testo: nessun elemento creato, nessuno script eseguito', !d.querySelector('.mp img') && !d.querySelector('.mp b:not(.mp-apri b)') && w.__bucato===undefined && pin2[3].querySelector('.lab').textContent.indexOf('<img')===0);
  ok('ogni segnaposto e ogni riga è un vero pulsante con la sua descrizione per i lettori di schermo', pin2.every(p=>p.tagName==='BUTTON'&&/^Lezione \d+, /.test(p.getAttribute('aria-label'))) && righe2.every(r=>r.tagName==='BUTTON'&&r.getAttribute('aria-label')));

  console.log('== coordinate storte ==');
  const buono=(g)=>w.luogoOk({luogo:g});
  ok('coordinate giuste accettate (anche scritte come testo)', buono({lat:38.01,lng:12.5}) && buono({lat:'38.01',lng:'12.5'}));
  ok('scartati: niente luogo, latitudine 200, testo, vuoto, null', !buono(null) && !buono({lat:200,lng:12}) && !buono({lat:'abc',lng:12}) && !buono({lat:'',lng:''}) && !buono({lat:null,lng:null}) && !buono('38,12'));

  console.log('== uscita e ritorno ==');
  w.tuttiICorsi(); await at(30);
  ok('tornando a «tutti i corsi» la mappa sparisce e la card torna stretta', !d.querySelector('.mp') && !d.querySelector('#menu .card').classList.contains('conmappa') && w.__L.tolte===2);

  console.log('== modalità ipovedenti: resta l\'elenco grande ==');
  w.scegliCorso(corsoIdx(w,'trapani')); await at(40);
  w.setAcc('ipo'); await at(60);
  ok('in modalità ipovedenti niente mappa: le card grandi di sempre', !d.querySelector('.mp') && d.querySelectorAll('#menuLez .lez').length===6);
  w.setAcc('std'); await at(60);
  ok('tornando a Standard la mappa ritorna', d.querySelectorAll('.mp-pin').length===5);
  w.setAcc('lis'); await at(60);
  ok('in modalità LIS la mappa resta', d.querySelectorAll('.mp-pin').length===5);
  D.window.close();

  /* ================= 2. quando la mappa non ci può essere ================= */
  console.log('== un solo corso, ed è quello con la mappa ==');
  D=dom([DUE[1]],true); w=D.window; d=w.document; await at(600);
  ok('si apre direttamente sulla mappa, senza il tasto «Tutti i corsi»', d.querySelectorAll('.mp-pin').length===5 && !d.querySelector('.mp-testa .tbtn'));
  D.window.close();

  console.log('== mappa chiesta, ma i luoghi non ci sono ==');
  D=dom([corso('x','Senza luoghi',[TRAPANI[0],TRAPANI[5],MESTIERI[0]],{mappa:true})],true); w=D.window; d=w.document; await at(600);
  ok('con un solo luogo non si disegna una mappa: card normali', !d.querySelector('.mp') && d.querySelectorAll('#menuLez .lez').length===3);
  D.window.close();
  D=dom([corso('x','Mappa non chiesta',TRAPANI,{mappa:'true'})],true); w=D.window; d=w.document; await at(600);
  ok('didattica.mappa deve essere proprio true (non il testo "true")', !d.querySelector('.mp'));
  D.window.close();

  console.log('== la libreria della mappa non si carica (rete della scuola, file mancante) ==');
  D=dom([DUE[1]],false); w=D.window; d=w.document;
  w.caricaLeaflet=()=>Promise.reject(new Error('file non trovato'));
  await at(700); w.buildMenu(); await at(80);
  ok('si torna da soli all\'elenco normale: 6 card, nessuna mappa a metà', !d.querySelector('.mp') && d.querySelectorAll('#menuLez .lez').length===6 && !d.querySelector('#menu .card').classList.contains('conmappa'));
  const ap=[]; w.avviaLezione=(i)=>ap.push(i); d.querySelectorAll('#menuLez .lez')[1].click();
  ok('…e le lezioni si aprono lo stesso', ap.join()==='1');
  D.window.close();

  /* ================= 3. i file ================= */
  console.log('== file della libreria ==');
  const lib=path.join(__dirname,'..','app','lib','leaflet');
  ok('Leaflet è dentro l\'app (lib/leaflet/leaflet.js e .css), non su un servizio esterno', fs.existsSync(path.join(lib,'leaflet.js')) && fs.existsSync(path.join(lib,'leaflet.css')));
  ok('c\'è la licenza di Leaflet accanto ai file', fs.existsSync(path.join(lib,'LICENSE')));
  const pag=fs.readFileSync('/tmp/pag.html','utf8');
  ok('la pagina carica Leaflet dalla cartella dell\'app e solo quando serve', /EDU_BASE\|\|''\)\+'lib\/leaflet\/'/.test(pag) && !/<script[^>]+leaflet/i.test(pag) && !/unpkg\.com|cdnjs[^"']*leaflet/i.test(pag));

  console.log('\nRISULTATO: '+P+' passati, '+F+' falliti');
  process.exit(F?1:0);
})();
