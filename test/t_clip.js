/* TEST player v2.9 — la clip con taglio, voce a parte e sottotitoli propri (migr. 35)

   Il caso che ha fatto nascere questo lavoro: i racconti di U Cuntastorie a
   Trapani. Il video 360 su Bunny dura più del racconto (c'è il prima e il dopo
   della camminata), la voce pulita sta in un file a parte e i sottotitoli pure.
   Quindi una clip deve poter dire: «parto dal secondo 20, finisco al 60, la
   voce comincia al secondo 10 del video, l'audio del video tienilo basso».

   Gira su /tmp/pag.html (prodotto da rendi-player.sh). Nessun servizio esterno. */
const { JSDOM, VirtualConsole } = require('jsdom'); const fs = require('fs');

let P=0,F=0; const ok=(n,c)=>{ if(c){P++;console.log('  ✓ '+n);} else {F++;console.log('  ❌ '+n);} };
const at=ms=>new Promise(r=>setTimeout(r,ms));
const vicino=(a,b,t)=>Math.abs(a-b)<=(t===undefined?0.02:t);

const VTT='WEBVTT\n\n1\n00:00:12.000 --> 00:00:15.000\nEnrico Caruso arriva a Trapani\n\n2\n00:00:30.000 --> 00:00:33.000\ne i trapanesi lo riempiono di pomodori\n';

const CLIP_TAGLIATA={guid:'g-uno',da:20,a:60,t0:10,volv:22,cc:'https://esempio.it/sub/n01.vtt',tit:'La chiesa che rinasce',
                     audio:{url:'https://esempio.it/voce/n01.mp3',vol:100,loop:false,duck:false}};
const CLIP_NORMALE={guid:'g-due',tit:'L’altare'};
const LEZ_NUOVA={ok:true,lezione:{id:'collegio',tit:'Chiesa del Collegio',intro:'Entriamo',coccio:null,didattica:{},
  corso:{id:'trapani',tit:'Trapani'},video:[CLIP_TAGLIATA,CLIP_NORMALE],
  tappe:[{v:0,t:40,cocciu:'Guardate il portone',hotspots:[{yaw:0,pitch:0,em:'🔑',tit:'Chiusa per 42 anni',txt:'Il portone'}]}],
  quiz:[{q:'D1?',opts:['a','b'],ok:0}],quiz2:null}};
const LEZ_VECCHIA={ok:true,lezione:{id:'salinaio',tit:'Il salinaio',intro:'Guardate',coccio:null,didattica:{},
  corso:{id:'trapani',tit:'Trapani'},video:[{guid:'g-vecchia'}],tappe:[],quiz:[{q:'D1?',opts:['a','b'],ok:0}],quiz2:null}};
const A={id:'collegio',tit:'Chiesa del Collegio',stato:'pubblicata'}, B={id:'salinaio',tit:'Il salinaio',stato:'pubblicata'};
const MENU={ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:true,senior:true},
  cliente:{nome:'Esplora Trapani',brand:{titolo:'Esplora Edu'},limiti:{quiz_live:true}},
  corsi:[{id:'trapani',tit:'Trapani',em:'⚓',stato:'pubblicato',origine:'proprio',didattica:{},lezioni:[A,B]}],lezioni:[A,B]};

function dom(){
  let html=fs.readFileSync('/tmp/pag.html','utf8');
  const mock=`<script>window.__url=[];
    window.fetch=(u,o)=>{const s=String(u); window.__url.push(s);
      if(/\\.vtt(\\?|$)/.test(s)) return Promise.resolve({ok:true,text:()=>Promise.resolve(${JSON.stringify(VTT)})});
      let b='{"ok":true}';
      if(s.includes('action=menu'))b=${JSON.stringify(JSON.stringify(MENU))};
      else if(s.includes('action=diario'))b='{"ok":true,"diario":[]}';
      else if(s.includes('action=lezione')){ const id=(s.match(/[?&]id=([^&]+)/)||[])[1]; b=JSON.stringify(window.__lez[id]); }
      return Promise.resolve({ok:true,json:()=>Promise.resolve(JSON.parse(b))});};
    window.__lez=${JSON.stringify({collegio:LEZ_NUOVA,salinaio:LEZ_VECCHIA})};
    window.AFRAME={registerComponent(){}};window.Hls=undefined;
    window.alert=()=>{};window.confirm=()=>true;window.EduLive={apri(){}};</script>`;
  html=html.replace('<head>','<head>'+mock).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const D=new JSDOM(html,{url:'http://localhost/index.php?classe=PROVA-1',runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:new VirtualConsole()});
  const st=new WeakMap(), tm=new WeakMap(), vo=new WeakMap(), M=D.window.HTMLMediaElement.prototype;
  Object.defineProperty(M,'paused',{configurable:true,get(){const s=st.get(this);return s===undefined?true:s;}});
  Object.defineProperty(M,'duration',{configurable:true,get(){return 120;}});
  Object.defineProperty(M,'currentTime',{configurable:true,get(){return tm.get(this)||0;},set(v){tm.set(this,v);}});
  Object.defineProperty(M,'volume',{configurable:true,get(){const x=vo.get(this);return x===undefined?1:x;},set(v){vo.set(this,v);}});
  M.play=function(){st.set(this,false);return Promise.resolve();};
  M.pause=function(){st.set(this,true);};
  M.load=function(){};
  return D;
}
async function avvia(w,d,i){
  w.avviaLezione(i); await at(400);
  if(d.getElementById('prologoBtn'))try{d.getElementById('prologoBtn').click();}catch(e){}
  await at(150);
}
const ev=(w,el,tipo)=>el.dispatchEvent(new w.Event(tipo));

(async()=>{
  console.log('— A. la clip parte dal punto giusto e col volume giusto —');
  let D=dom(), w=D.window, d=w.document; await at(500);
  await avvia(w,d,0);
  const v=d.getElementById('vid'), voce=d.getElementById('clipAudio');
  ok('l\'audio del video è abbassato al 22%: il racconto sta nella traccia a parte', vicino(v.volume,0.22));
  ok('la traccia della voce è quella indicata dalla clip, non in loop', /n01\.mp3$/.test(voce.src) && voce.loop===false);
  ev(w,v,'loadedmetadata');
  ok('appena il video è pronto salta al secondo 20, dove comincia il racconto', vicino(v.currentTime,20));
  ok('i tagli si leggono dalle funzioni del player', w.clipDa()===20 && w.clipA()===60 && w.clipT0()===10);

  console.log('— B. la barra si muove dentro il taglio, non sull\'intero video —');
  v.currentTime=30; ev(w,v,'timeupdate');
  ok('a 10 secondi dall\'inizio del racconto la barra è a un quarto (10 su 40)', d.getElementById('seek').value==='250');
  ok('il tempo mostrato è quello del racconto: 00:10 / 00:40', d.getElementById('seekTime').textContent==='00:10 / 00:40');
  d.getElementById('seek').value='500'; ev(w,d.getElementById('seek'),'change');
  ok('trascinando la barra a metà si va a metà del racconto (secondo 40 del video)', vicino(v.currentTime,40));
  v.currentTime=25; w.saltaVideo(-10);
  ok('⏪ non torna prima dell\'inizio del racconto', vicino(v.currentTime,20));
  v.currentTime=55; w.saltaVideo(10);
  ok('⏩ non supera la fine del racconto', vicino(v.currentTime,59.7));

  console.log('— C. la voce resta agganciata al video —');
  v.currentTime=30; ev(w,v,'seeked');
  ok('spostando il video la voce va al suo secondo corrispondente (30 − 10 = 20)', vicino(voce.currentTime,20));
  voce.currentTime=5; ev(w,v,'timeupdate');
  ok('se la voce scarta di oltre mezzo secondo viene riallineata', vicino(voce.currentTime,20));
  voce.currentTime=20.3; ev(w,v,'timeupdate');
  ok('uno scarto piccolo (0,3 s) non viene toccato: niente scatti nell\'audio', vicino(voce.currentTime,20.3));

  console.log('— D. sottotitoli dal file della clip, con i tempi della voce —');
  w.eval("ccLang='it'"); await w.loadCC();
  ok('il file .vtt della clip è stato chiesto', w.__url.some(u=>u==='https://esempio.it/sub/n01.vtt'));
  v.currentTime=23; ev(w,v,'timeupdate');
  ok('la battuta dei secondi 12–15 della voce compare al secondo 23 del video (10 + 13)',
     d.getElementById('ccBox').textContent==='Enrico Caruso arriva a Trapani');
  v.currentTime=13; ev(w,v,'timeupdate');
  ok('…e non al secondo 13 del video, dove la voce non è ancora partita', d.getElementById('ccBox').textContent==='');
  w.eval("ccLang='off'"); w.renderCue('');

  console.log('— E. la fermata funziona come sempre, e il taglio in coda chiude la clip —');
  v.currentTime=40.2; ev(w,v,'timeupdate'); await at(50);
  ok('al secondo 40 la fermata si apre', w.eval('!!tappaAttiva'));
  v.currentTime=60.5; ev(w,v,'timeupdate');
  ok('con la fermata aperta il taglio non scatta: prima si trova il punto', w.eval('vidIdx')===0);
  w.eval("tappaAttiva.hotspots.forEach(h=>h._fatto=true); tappaAttiva._done=true; tappaAttiva=null;");
  v.currentTime=60.1; ev(w,v,'timeupdate'); await at(30);
  ok('arrivati al secondo 60 si passa alla clip successiva, senza aspettare la fine del video', w.eval('vidIdx')===1);
  ok('la barra dice quale racconto è: «clip 2/2 · L’altare»', d.getElementById('seekClip').textContent==='clip 2/2 · L’altare');
  ok('la clip senza indicazioni torna a volume pieno', vicino(v.volume,1));
  ok('…e senza tagli: parte da zero e dura tutto il video', w.clipDa()===0 && w.clipA()===120);
  ok('la voce della clip precedente è stata staccata', !voce.getAttribute('src'));
  ev(w,v,'ended'); await at(60);
  ok('finita l\'ultima clip si apre il quiz', d.getElementById('quiz').classList.contains('on'));

  console.log('— F. le lezioni di prima non cambiano di una virgola —');
  D=dom(); w=D.window; d=w.document; await at(500);
  await avvia(w,d,1);
  const v2=d.getElementById('vid');
  ok('nessun taglio: da 0 alla durata del video', w.clipDa()===0 && w.clipA()===120);
  ok('volume pieno', vicino(v2.volume,1));
  v2.currentTime=60; ev(w,v2,'timeupdate');
  ok('barra a metà quando il video è a metà', d.getElementById('seek').value==='500');
  ok('tempo mostrato: 01:00 / 02:00', d.getElementById('seekTime').textContent==='01:00 / 02:00');
  v2.currentTime=118; w.saltaVideo(10);
  ok('⏩ si ferma a 0,3 s dalla fine, come prima', vicino(v2.currentTime,119.7));
  v2.currentTime=3; w.saltaVideo(-10);
  ok('⏪ si ferma a zero, come prima', v2.currentTime===0);
  v2.currentTime=119; ev(w,v2,'timeupdate'); await at(30);
  ok('senza taglio il video non viene interrotto prima della fine', !d.getElementById('quiz').classList.contains('on'));
  ev(w,v2,'ended'); await at(60);
  ok('…e alla fine naturale parte il quiz', d.getElementById('quiz').classList.contains('on'));

  console.log('— G. dati storti dalla regia: non devono fare danni —');
  ok('un indirizzo dei sottotitoli che non è https viene scartato', w.ccUrlOk('http://esempio.it/a.vtt')===null);
  ok('…e così uno che non è un file .vtt', w.ccUrlOk('https://esempio.it/a.php')===null);
  ok('…e un tentativo di codice', w.ccUrlOk('javascript:alert(1)//.vtt')===null);
  ok('un indirizzo buono passa', w.ccUrlOk('https://www.esempio.it/sub/n01.vtt')==='https://www.esempio.it/sub/n01.vtt');
  const n=w.normalizzaLezione({video:[{guid:'g',da:-5,a:'abc',t0:'x',volv:900,cc:'ftp://x/a.vtt'}],tappe:[]}).video[0];
  ok('tagli negativi o non numerici diventano «nessun taglio»', n.da===0 && n.a===0 && n.t0===null);
  ok('un volume fuori scala viene riportato fra 0 e 100', n.volv===100);
  ok('un file sottotitoli non valido non viene nemmeno chiesto', n.cc===null);
  const n2=w.normalizzaLezione({video:[{guid:'g',da:30,a:10}],tappe:[]});
  w.eval('LEZ='+JSON.stringify(n2)+';vidIdx=0;');
  ok('una fine che viene prima dell\'inizio viene ignorata: si arriva in fondo al video', w.clipA()===120);

  console.log('RISULTATO: '+P+' passati, '+F+' falliti');
  process.exit(F?1:0);
})();
