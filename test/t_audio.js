const { JSDOM } = require('jsdom'); const fs=require('fs');
const AUDIO={url:'https://cdn.x.it/goccia1.mp3',vol:40,loop:true,duck:true};
const MENU={ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:false,senior:false},
  cliente:{nome:'Salina',brand:{titolo:'Sale in Classe'}},
  corsi:[{id:'goccia',tit:'Il viaggio di una goccia',em:'💧',stato:'pubblicato',
    lezioni:[{id:'l1',tit:'Il mare',stato:'pubblicata'}]}], lezioni:[{id:'l1',tit:'Il mare',stato:'pubblicata'}]};
const LEZ={ok:true,lezione:{id:'l1',tit:'Il mare',intro:'Benvenuti',coccio:null,
  video:[{guid:'v1',audio:AUDIO},{guid:'v2',audio:{url:'https://cdn.x.it/goccia2.mp3',vol:60,loop:false,duck:false}},{guid:'v3'}],
  tappe:[{v:0,t:1,cocciu:'Guarda il mare!',hotspots:[{yaw:0,pitch:0,em:'💧',tit:'Goccia',txt:'testo'}]}],
  quiz:[{q:'D?',opts:['a','b'],ok:0}],quiz2:null}};
let html=fs.readFileSync('/tmp/pag.html','utf8');
const mock=`<script>window.fetch=(u)=>{const s=String(u);let b=s.includes('action=menu')?${JSON.stringify(JSON.stringify(MENU))}:s.includes('action=lezione')?${JSON.stringify(JSON.stringify(LEZ))}:'{"ok":true}';return Promise.resolve({json:()=>Promise.resolve(JSON.parse(b))});};
window.AFRAME={registerComponent(){}};window.Hls=undefined;window.alert=()=>{};window.EduLive={apri(){}};</script>`;
html=html.replace('<head>','<head>'+mock).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
const dom=new JSDOM(html,{url:'http://localhost/index.php',runScripts:'dangerously',pretendToBeVisual:true});
const w=dom.window,d=w.document;
// strumentazione: traccio play/pause su HTMLMediaElement
w.__log=[];
// in jsdom .paused è di sola lettura: lo rendo controllabile per simulare il player reale
const stato=new WeakMap();
Object.defineProperty(w.HTMLMediaElement.prototype,'paused',{configurable:true,get(){const s=stato.get(this);return s===undefined?true:s;}});
w.HTMLMediaElement.prototype.play=function(){ w.__log.push((this.id||'vid')+':play'); stato.set(this,false); return Promise.resolve(); };
w.HTMLMediaElement.prototype.pause=function(){ w.__log.push((this.id||'vid')+':pause'); stato.set(this,true); };
w.HTMLMediaElement.prototype.load=function(){};
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
(async()=>{
  await at(400);
  const A=d.getElementById('clipAudio');
  ok('elemento audio presente nel player', !!A);
  w.avviaLezione(0); await at(300);
  ok('audio della clip 1 agganciato: src, volume 40%, loop', A.src===AUDIO.url && Math.abs(A.volume-0.4)<0.01 && A.loop===true);
  ok('audio parte con la lezione', w.__log.includes('clipAudio:play') && A.paused===false);
  // scoperta → duck
  const inj=(code)=>{const s=d.createElement('script');s.textContent=code;d.body.appendChild(s);};
  inj('apriTappa(LEZ.tappe[0]);'); await at(80);
  ok('scoperta aperta: sottofondo abbassato al 25%', Math.abs(A.volume-0.1)<0.02);
  inj('aperti=1; chiudiScoperta();'); await at(80);
  ok('scoperta chiusa: volume ripristinato', Math.abs(A.volume-0.4)<0.01);
  // pausa/ripresa
  w.__log=[]; d.getElementById('vid').pause(); d.getElementById('vid').dispatchEvent(new w.Event('pause')); await at(20);
  ok('video in pausa → audio in pausa', w.__log.includes('clipAudio:pause'));
  w.__log=[]; d.getElementById('vid').play(); d.getElementById('vid').dispatchEvent(new w.Event('play')); await at(20);
  ok('video riparte → audio riparte', w.__log.includes('clipAudio:play'));
  // clip successiva
  inj('vidIdx=0;'); d.getElementById('vid').dispatchEvent(new w.Event('ended')); await at(80);
  ok('clip 2: nuovo audio, volume 60%, senza loop', A.src.includes('goccia2') && Math.abs(A.volume-0.6)<0.01 && A.loop===false);
  // clip senza audio
  inj('vidIdx=1;'); d.getElementById('vid').dispatchEvent(new w.Event('ended')); await at(80);
  ok('clip 3 senza audio: sorgente rimossa', !A.getAttribute('src'));
  // quiz e menu
  inj('vidIdx=2;'); d.getElementById('vid').dispatchEvent(new w.Event('ended')); await at(80);
  ok('quiz avviato in silenzio', !A.getAttribute('src'));
  console.log('RISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.message);process.exit(1);});
