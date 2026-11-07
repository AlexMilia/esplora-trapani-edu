/* TEST bussola del player — portare l'occhio sul punto che brilla.
   Il caso che ha fatto nascere questo lavoro: in presentazione, da telefono
   tenuto in verticale, le persone si fermavano perché il punto era fuori
   dallo schermo e la scritta "gira a destra" non la leggeva nessuno.
   Gira su /tmp/pag.html (prodotto da rendi-player.sh). Nessun servizio esterno. */
const { JSDOM, VirtualConsole } = require('jsdom'); const fs = require('fs');

let P=0,F=0;
const ok=(n,c)=>{ if(c){P++;console.log('  ✓ '+n);} else {F++;console.log('  ❌ '+n);} };
const vicino=(a,b,t)=>Math.abs(a-b)<=(t===undefined?0.6:t);

/* La pagina con A-Frame finto: nei test non c'è WebGL, quindi la camera è un
   elemento normale su cui rotation si legge e si scrive come oggetto, come
   farebbe A-Frame. Serve a provare davvero il giro della scena. */
function dom(opt){
  opt=opt||{};
  const html=fs.readFileSync('/tmp/pag.html','utf8');
  const mock=`<script>
    window.AFRAME={registerComponent(){}};window.Hls=undefined;
    window.fetch=()=>Promise.resolve({json:()=>Promise.resolve({ok:true})});
    window.__rot={x:0,y:0,z:0};
    window.__fov=${opt.fov||80};
  </script>`;
  const vc=new VirtualConsole();          /* jsdom non sa suonare i video: silenzio */
  const d=new JSDOM(html.replace('</head>',mock+'</head>'),
    {runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:vc,url:'https://esempio.it/index.php?c=x'});
  const w=d.window;
  Object.defineProperty(w,'innerWidth' ,{value:opt.w||1280,configurable:true});
  Object.defineProperty(w,'innerHeight',{value:opt.h||720 ,configurable:true});
  w.matchMedia=w.matchMedia||(()=>({matches:!!opt.menoMovimento}));
  if(opt.menoMovimento) w.matchMedia=()=>({matches:true});
  const cam=w.document.getElementById('cam');
  cam.getAttribute=(n)=> n==='rotation' ? w.__rot : (n==='camera' ? {fov:w.__fov} : null);
  cam.setAttribute=(n,v)=>{ if(n==='rotation') w.__rot=v; };
  return w;
}

/* ------------------------------------------------------------------ */
console.log('— quanto mondo entra nello schermo: la soglia non è più fissa —');
{
  const lim=dom({w:1920,h:1080}).sogliaVista();          /* LIM 16:9 */
  const tel=dom({w:390 ,h:844 }).sogliaVista();          /* telefono in verticale */
  const tab=dom({w:1024,h:1366}).sogliaVista();          /* tablet in verticale */
  ok('su LIM 16:9 si vede largo (soglia oltre i 40°)', lim.oriz>40);
  ok('su telefono verticale si vede molto meno (soglia sotto i 25°)', tel.oriz<25);
  ok('…ed è proprio il caso che prima sfuggiva: più stretta della vecchia soglia fissa di 40°', tel.oriz<40);
  ok('il tablet sta in mezzo ai due', tab.oriz>tel.oriz && tab.oriz<lim.oriz);
  ok('in verticale la soglia non diventa mai assurda (resta sopra i 12°)', tel.oriz>=12 && tab.oriz>=12);
}

console.log('— da che parte sta il punto —');
{
  const w=dom({w:390,h:844}), s={oriz:20,vert:25};
  ok('punto a destra → "dx"',  w.versoHot(0,0,{yaw: 60,pitch:0},s).lato==='dx');
  ok('punto a sinistra → "sx"',w.versoHot(0,0,{yaw:-60,pitch:0},s).lato==='sx');
  ok('punto in alto → "su"',   w.versoHot(0,0,{yaw:  0,pitch: 40},s).lato==='su');
  ok('punto in basso → "giu"', w.versoHot(0,0,{yaw:  0,pitch:-40},s).lato==='giu');
  ok('punto davanti → nessuna freccia', w.versoHot(0,0,{yaw:5,pitch:3},s).fuori===false);
  ok('si gira sempre dalla parte più corta: da 170° a -170° si va a destra',
     w.versoHot(170,0,{yaw:-170,pitch:0},s).dy>0);
  ok('…e da -170° a 170° si va a sinistra',
     w.versoHot(-170,0,{yaw:170,pitch:0},s).dy<0);
  ok('il punto esattamente dietro le spalle è fuori, da qualunque lato',
     w.versoHot(0,0,{yaw:180,pitch:0},s).fuori===true);
}

console.log('— lo stesso punto: dentro su LIM, fuori su telefono —');
{
  const punto={yaw:35,pitch:0};
  ok('su LIM 35° a destra sono ancora dentro lo schermo',
     dom({w:1920,h:1080}).versoHot(0,0,punto).fuori===false);
  ok('su telefono in verticale lo stesso punto è fuori e va segnalato',
     dom({w:390,h:844}).versoHot(0,0,punto).fuori===true);
}

console.log('— la scena gira verso il punto —');
{
  const w=dom({w:390,h:844});
  ok('di partenza si guarda dritto', w.camVista().yaw===0);
  w.giraVerso({yaw:120,pitch:15},0);                    /* 0 = subito, senza animazione */
  ok('dopo il giro si guarda verso il punto (yaw)',   vicino(w.camVista().yaw,120));
  ok('…e anche in altezza (pitch)',                   vicino(w.camVista().pitch,15));
  ok('ora il punto non è più fuori dallo schermo',    w.versoHot(w.camVista().yaw,w.camVista().pitch,{yaw:120,pitch:15}).fuori===false);
  w.giraVerso({yaw:-170,pitch:0},0);
  ok('passando per il "dietro" si arriva comunque giusti', vicino(w.camVista().yaw,-170,1.2));
  w.giraVerso({yaw:0,pitch:140},0);
  ok('non si guarda mai oltre lo zenit: la scena non si capovolge', w.camVista().pitch===90);
  w.giraVerso({yaw:0,pitch:-140},0);
  ok('…né oltre il nadir', w.camVista().pitch===-90);
  ok('senza un punto non gira nulla', w.giraVerso(null,0)===false);
}

console.log('— chi ha chiesto meno movimento non viene sballottato —');
{
  const w=dom({w:390,h:844,menoMovimento:true});
  w.giraVerso({yaw:90,pitch:0});                        /* durata normale: deve saltare secco */
  ok('con «riduci animazioni» il giro è immediato, senza panoramica', vicino(w.camVista().yaw,90));
}

console.log('— la freccia grande sul bordo —');
{
  const w=dom({w:390,h:844});
  const f=w.document.getElementById('frecciaHot');
  ok('il bottone esiste nella pagina', !!f);
  ok('di partenza è nascosto', !f.classList.contains('on'));
  w.mostraFreccia('sx');
  ok('acceso a sinistra, punta a sinistra', f.classList.contains('on') && f.dataset.lato==='sx'
     && w.document.getElementById('frIco').textContent==='◀');
  ok('dice a voce dove girare (per chi usa il lettore di schermo)',
     /sinistra/.test(f.getAttribute('aria-label')));
  w.mostraFreccia('giu');
  ok('spostandosi in basso cambia verso', f.dataset.lato==='giu' && w.document.getElementById('frIco').textContent==='▼');
  w.mostraFreccia('');
  ok('niente punto fuori → la freccia sparisce', !f.classList.contains('on'));
}

console.log('— toccare la freccia gira la scena —');
{
  const w=dom({w:390,h:844,menoMovimento:true});   /* senza panoramica: il risultato è subito verificabile */
  w.eval('tappaAttiva={hotspots:[{yaw:-100,pitch:12,_fatto:false}]}');
  w.document.getElementById('frecciaHot').dispatchEvent(new w.Event('click'));
  ok('un tocco sulla freccia porta lo sguardo esattamente sul punto',
     vicino(w.camVista().yaw,-100) && vicino(w.camVista().pitch,12));
  w.eval('tappaAttiva=null');
  const prima=w.camVista().yaw;
  w.document.getElementById('frecciaHot').dispatchEvent(new w.Event('click'));
  ok('fuori da una tappa il tocco non fa niente', w.camVista().yaw===prima);
}

console.log('— il dito dell\'alunno viene prima del giro automatico —');
{
  const w=dom({w:390,h:844});
  w.eval('tappaAttiva={hotspots:[{yaw:150,pitch:0,_fatto:false}]};'
        +'document.getElementById("pill").classList.add("on");'
        +'_tappaDa=Date.now()-60000;');          /* come se si cercasse da un minuto */
  w.dispatchEvent(new w.Event('touchstart'));    /* …ma il dito è sullo schermo adesso */
  w.bussola();
  ok('mentre si trascina la scena non viene strappata di mano', w.camVista().yaw===0);
  ok('la freccia però si vede lo stesso', w.document.getElementById('frecciaHot').classList.contains('on'));
  w.eval('_ultimoTocco=0;');                     /* dito alzato da un pezzo */
  w.bussola();
  ok('passata la calma, la scena comincia a girare verso il punto',
     w.camVista().yaw>0 || w.eval('_giratoSu!==null'));
  ok('…e non ci riprova all\'infinito sullo stesso punto', w.eval('_giratoSu')===w.eval('tappaAttiva.hotspots[0]'));
}

console.log('— quando la bussola deve stare zitta —');
{
  const w=dom({w:390,h:844});
  w.eval('tappaAttiva={hotspots:[{yaw:150,pitch:0,_fatto:false}]};'
        +'document.getElementById("pill").classList.add("on");'
        +'document.getElementById("scoperta").classList.add("on");_tappaDa=Date.now()-60000;_ultimoTocco=0;');
  w.bussola();
  ok('con la scheda della scoperta aperta la freccia non la copre',
     !w.document.getElementById('frecciaHot').classList.contains('on'));
  ok('…e la scena non gira mentre si legge', w.camVista().yaw===0);
  w.eval('document.getElementById("scoperta").classList.remove("on");'
        +'tappaAttiva.hotspots[0]._fatto=true;');
  w.bussola();
  ok('tutti i punti trovati: torna la scritta di sempre',
     w.document.getElementById('pill').textContent.indexOf('Trova e tocca')>=0);
  ok('…e nessuna freccia', !w.document.getElementById('frecciaHot').classList.contains('on'));
}

console.log('— la scritta dice la stessa cosa della freccia —');
{
  const w=dom({w:390,h:844});
  w.eval('tappaAttiva={hotspots:[{yaw:-150,pitch:0,_fatto:false}]};'
        +'document.getElementById("pill").classList.add("on");_tappaDa=Date.now();_ultimoTocco=Date.now();');
  w.bussola();
  const t=w.document.getElementById('pill').textContent;
  ok('su telefono la scritta dice che cosa fare, in una riga sola', /Tocca la freccia/.test(t) && t.length<45);
  ok('e la freccia punta dalla parte giusta', w.document.getElementById('frecciaHot').dataset.lato==='sx');

  const g=dom({w:1920,h:1080});   /* su LIM c'è spazio: si scrive anche da che parte */
  g.eval('tappaAttiva={hotspots:[{yaw:-150,pitch:0,_fatto:false}]};'
        +'document.getElementById("pill").classList.add("on");_tappaDa=Date.now();_ultimoTocco=Date.now();');
  g.bussola();
  const tg=g.document.getElementById('pill').textContent;
  ok('su LIM la scritta dice anche da che parte girare', /fuori dallo schermo/.test(tg) && /sinistra/.test(tg));
}

console.log('— dati storti dalla regia: non deve rompersi niente —');
{
  const w=dom({w:390,h:844});
  const s0={oriz:20,vert:25};
  ok('un punto senza coordinate non accende nessuna freccia',
     w.versoHot(0,0,{yaw:null,pitch:null},s0).fuori===false);
  ok('…e nemmeno con coordinate scritte male', w.versoHot(0,0,{yaw:'destra',pitch:'su'},s0).fuori===false);
  w.eval('tappaAttiva={hotspots:[{yaw:"x",pitch:null,_fatto:false}]};'
        +'document.getElementById("pill").classList.add("on");_tappaDa=Date.now()-60000;_ultimoTocco=0;');
  w.bussola();
  ok('la scena resta ferma invece di finire chissà dove', w.camVista().yaw===0);
  ok('e la bussola non blocca il resto della lezione', !w.document.getElementById('frecciaHot').classList.contains('on'));
}

console.log('— su telefono si aspetta meno che su LIM —');
{
  const html=fs.readFileSync('/tmp/pag.html','utf8');
  ok('l\'attesa prima del giro automatico è più corta su schermo stretto',
     /ATTESA_STRETTO=(\d+)[^]*?ATTESA_LARGO=(\d+)/.test(html)
     && parseInt(RegExp.$1,10) < parseInt(RegExp.$2,10));
  ok('su telefono la scritta cresce invece di rimpicciolirsi (era 13px)',
     /\.pill\{top:56px;font-size:16px/.test(html));
  ok('la freccia su telefono è più grande, non più piccola',
     /\.frecciaHot\{padding:16px 18px;font-size:18px\}/.test(html));
  ok('la misura della freccia è scritta in modo valido (niente scorciatoia «font:» con inherit)',
     /\.frecciaHot\{[^}]*font-size:17px/.test(html) && !/\.frecciaHot\{[^}]*font:700/.test(html));
  ok('sulla LIM, che si guarda da lontano, la freccia è ancora più grande',
     /@media\(min-width:1400px\)\{[^]*?\.frecciaHot\{font-size:22px/.test(html));
}

console.log('');
console.log('RISULTATO: '+P+' passati, '+F+' falliti');
process.exit(F?1:0);
