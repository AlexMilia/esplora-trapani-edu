const { JSDOM } = require('jsdom'); const fs=require('fs');
const LEZ_META={id:'goccia-mare',tit:'Il mare',stato:'pubblicata'};
const MENU={ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:true,senior:true,nome:'Generica'},
  tenant:'salina-culcasi',cliente:{nome:'Salina Culcasi',brand:{titolo:'Sale in Classe',sottotitolo:'Culcasi'},limiti:{quiz_live:true}},
  scuola:{nome:'IC Pagoto',classe:'5ª A'},
  corsi:[{id:'goccia',tit:'Il viaggio di una goccia',em:'💧',stato:'pubblicato',origine:'proprio',lezioni:[LEZ_META]},
         {id:'mestieri',tit:'Antichi Mestieri',em:'🛠️',stato:'pubblicato',origine:'licenza',licenza_a:'2027-06-30',lezioni:[{id:'corallo',tit:'Il corallo',stato:'pubblicata'}]}],
  lezioni:[LEZ_META]};
const LEZIONE={ok:true,lezione:{id:'goccia-mare',tit:'Il mare',intro:'Benvenuti',coccio:null,
  corso:{id:'goccia',tit:'Il viaggio di una goccia',prologo:'Da qualche parte…',mascotte:{nome:'Coccio di sale',img:'https://x.it/c.png',junior:true,senior:false}},
  video:[{guid:'g1',audio:{url:'https://cdn.x.it/mare.mp3',vol:35,loop:true,duck:true}}],tappe:[],quiz:[{q:'D?',opts:['a','b'],ok:0}],quiz2:null}};
const SCUOLA_KO={ok:false,err:'licenza_scuola',cliente:{nome:'Salina Culcasi',brand:{titolo:'Sale in Classe'}},
  scuola:{nome:'IC Scaduto',licenza_stato:'scaduta',licenza_a:'2026-06-30'}};
function dom(menu,lez){
  let html=fs.readFileSync('/tmp/pag26.html','utf8');
  const mock=`<script>window.__url=[];window.fetch=(u)=>{const s=String(u);window.__url.push(s);
    let b=s.includes('action=menu')?${JSON.stringify(JSON.stringify(menu))}:s.includes('action=lezione')?${JSON.stringify(JSON.stringify(lez))}:'{"ok":true}';
    return Promise.resolve({json:()=>Promise.resolve(JSON.parse(b))});};
    window.AFRAME={registerComponent(){}};window.Hls=undefined;window.alert=(m)=>{window.__alert=m};window.EduLive={apri(){}};</script>`;
  html=html.replace('<head>','<head>'+mock).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const D=new JSDOM(html,{url:'http://localhost/index.php?classe=ICPA-5A-X1',runScripts:'dangerously',pretendToBeVisual:true});
  const st=new WeakMap();
  Object.defineProperty(D.window.HTMLMediaElement.prototype,'paused',{configurable:true,get(){const s=st.get(this);return s===undefined?true:s;}});
  D.window.HTMLMediaElement.prototype.play=function(){st.set(this,false);return Promise.resolve();};
  D.window.HTMLMediaElement.prototype.pause=function(){st.set(this,true);};
  D.window.HTMLMediaElement.prototype.load=function(){};
  return D;
}
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
(async()=>{
  console.log('— A. Menu con corsi propri e in licenza —');
  const D=dom(MENU,LEZIONE); const w=D.window,d=D.window.document; await at(450);
  ok('codice classe inviato alle API', w.__url.some(u=>u.includes('classe=ICPA-5A-X1')));
  ok('due card corso (proprio + in licenza)', d.querySelectorAll('#menuLez .lez.corso').length===2);
  ok('brand dal cliente', d.getElementById('brandTit').textContent==='Sale in Classe');
  d.querySelector('#menuLez .lez.corso').click(); await at(60);
  ok('lezioni del corso scelto', d.getElementById('menuLez').textContent.includes('Il mare'));
  console.log('— B. Mascotte del corso —');
  const inj=(c)=>{const s=d.createElement('script');s.textContent=c;d.body.appendChild(s);};
  w.avviaLezione(0); await at(350);
  inj('window.__masc=JSON.stringify(MASC_CFG);');
  const mc=JSON.parse(w.__masc||'{}');
  ok('mascotte del corso applicata (nome e flag senior)', mc.nome==='Coccio di sale' && mc.senior===false && mc.junior===true);
  ok('prologo del corso mostrato', !d.getElementById('prologoOvl').classList.contains('hidden')||d.getElementById('prologoOvl').classList.contains('on'));
  d.getElementById('prologoBtn').click(); await at(120);
  ok('audio del corso agganciato', d.getElementById('clipAudio').src==='https://cdn.x.it/mare.mp3');
  console.log('— C. Licenza della scuola scaduta —');
  const D2=dom(SCUOLA_KO,LEZIONE); const d2=D2.window.document; await at(450);
  const m2=d2.getElementById('menuLez').textContent;
  ok('messaggio cita la SCUOLA, non il cliente', m2.includes('IC Scaduto') && m2.includes('scaduta'));
  ok('data di scadenza mostrata', m2.includes('2026-06-30'));
  ok('nessuna lezione avviabile', d2.querySelectorAll('#menuLez .lez').length===0);
  ok('brand comunque applicato', d2.getElementById('brandTit').textContent==='Sale in Classe');
  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.message);process.exit(1);});
