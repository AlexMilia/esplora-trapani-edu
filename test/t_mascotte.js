const { JSDOM } = require('jsdom'); const fs=require('fs');
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
const MASC={nome:'Coccio di sale',img:'https://x.it/coccio.png',junior:true,senior:false,quiz_sempre:false,
  video:{entrambi:{inizio_corso:'bunny:aaa',giusta:'bunny:bbb'},junior:{},senior:{giusta:'bunny:ccc'}}};
const MENU={ok:true,quizSempre:true,mascotte:{giusta:'yt:globale'},mascotteLiv:{junior:{giusta:'yt:globale'},senior:{giusta:'yt:globale'}},mascotteCfg:{junior:true,senior:true,nome:'Generica'},
  cliente:{nome:'Salina',brand:{titolo:'Sale in Classe'}},
  corsi:[{id:'goccia',tit:'Goccia',em:'💧',stato:'pubblicato',mascotte:MASC,lezioni:[{id:'l1',tit:'Il mare',stato:'pubblicata'}]},
         {id:'altro',tit:'Altro corso',em:'📚',stato:'pubblicato',lezioni:[{id:'l2',tit:'X',stato:'pubblicata'}]}],lezioni:[]};
(async()=>{
  console.log('— PLAYER: mascotte del corso —');
  let html=fs.readFileSync('/tmp/pagM.html','utf8');
  html=html.replace('<head>','<head><script>window.fetch=(u)=>{const s=String(u);let b=s.includes("action=menu")?'+JSON.stringify(JSON.stringify(MENU))+':\'{"ok":true}\';return Promise.resolve({json:()=>Promise.resolve(JSON.parse(b))});};window.AFRAME={registerComponent(){}};window.alert=()=>{};window.EduLive={apri(){}};</script>').replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const D=new JSDOM(html,{url:'http://localhost/index.php',runScripts:'dangerously',pretendToBeVisual:true}); const w=D.window,d=D.window.document;
  D.window.HTMLMediaElement.prototype.play=()=>Promise.resolve(); D.window.HTMLMediaElement.prototype.pause=()=>{}; D.window.HTMLMediaElement.prototype.load=()=>{};
  await at(450);
  const inj=(c)=>{const s=d.createElement('script');s.textContent=c;d.body.appendChild(s);};
  d.querySelector('#menuLez .lez.corso').click(); await at(60);   // scelgo «Goccia»
  inj("window.__r={liv:LIVELLO,giusta:mascVideo('giusta'),inizio:mascVideo('inizio_corso'),sbagliata:mascVideo('sbagliata'),nome:MASC_CFG.nome,quiz:MASC_QUIZ_SEMPRE};");
  ok('primaria: video «giusta» da entrambi, «inizio» presente, «sbagliata» assente', w.__r.giusta==='bunny:bbb' && w.__r.inizio==='bunny:aaa' && w.__r.sbagliata===null);
  ok('nome mascotte del corso applicato', w.__r.nome==='Coccio di sale');
  ok('quiz_sempre del corso rispettato (false)', w.__r.quiz===false);
  inj("LIVELLO='senior'; window.__r2={giusta:mascVideo('giusta')};");
  ok('medie: mascotte disattivata per la fascia → nessun video', w.__r2.giusta===null);
  inj("LIVELLO='junior'; MASC_CFG.senior=true; LIVELLO='senior'; window.__r3=mascVideo('giusta');");
  ok('medie con fascia attiva: override specifico bunny:ccc', w.__r3==='bunny:ccc');
  inj("tuttiICorsi(); scegliCorso(1); window.__r4={g:mascVideo('giusta'),n:MASC_CFG.nome};");
  ok('corso senza mascotte: resta la configurazione precedente (nessun crash)', typeof w.__r4.n==='string');

  console.log('— REGIA: editor mascotte del corso —');
  let r=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
  const CORSI=[{id:'co-1',proprietario_id:'cl-1',slug:'goccia',titolo:'Goccia',stato:'bozza',visibilita:'privato',mascotte:MASC}];
  r=r.replace('<head>','<head><script>window.__scr=[];window.__toast=[];'+
   'window.__fx={edu_clienti:[{id:"cl-1",slug:"c1",nome:"Cliente",piano:"pro",licenza_stato:"attiva",brand:{}}],edu_corsi:'+JSON.stringify(CORSI)+',edu_utenti:[{id:"u1",ruolo:"admin",cliente_id:null}],edu_lezioni:[],edu_scuole:[],edu_classi:[],edu_catalogo:[],edu_richieste:[],'+
   'edu_progetti:[{progetto:"sale-in-classe",nome:"Sale in Classe",mascotte_nome:"Coccio importato",mascotte_img:"https://x.it/c2.png",mascotte_junior:true,mascotte_senior:true,quiz_sempre:true}],'+
   'edu_mascotte:[{progetto:"sale-in-classe",chiave:"fine_corso",livello:"entrambi",video:"bunny:fine",attivo:true},{progetto:"sale-in-classe",chiave:"giusta",livello:"junior",video:"bunny:off",attivo:false}]};'+
   'function q(t){const st={t,op:"select",f:[]};const o={};o.select=()=>o;o.order=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.insert=(x)=>{st.op="insert";st.p=x;return o;};o.update=(x)=>{st.op="update";st.p=x;return o;};o.delete=()=>o;o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
   'o.then=(res)=>{if(st.op!=="select"){window.__scr.push({t,op:st.op,p:st.p});return res({data:Object.assign({id:"n"},st.p||{}),error:null});}let rows=window.__fx[t]||[];st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));return res({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
   'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u1"}}}}),onAuthStateChange:()=>{}},from:q,rpc:async()=>({data:{corsi_pubblicati:999,nome:"Pro"},error:null})})};'+
   'window.Hls={isSupported:()=>false};window.confirm=()=>true;window.prompt=()=>"";</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
  const R=new JSDOM(r,{url:'http://localhost/r.html',runScripts:'dangerously',pretendToBeVisual:true}); const w2=R.window,d2=R.window.document; await at(450);
  const s2=d2.createElement('script'); s2.textContent='toast=(m)=>window.__toast.push(m);'; d2.body.appendChild(s2);
  await w2.apriCorsi(); await at(80); w2.apriCorso('co-1'); await at(150);
  ok('griglia dei momenti renderizzata (5 momenti × 3 fasce = 15 campi)', d2.querySelectorAll('#coMascGrid input[type=text]').length===15);
  ok('campi precompilati dal jsonb del corso', d2.getElementById('cm_giusta_entrambi').value==='bunny:bbb' && d2.getElementById('cm_giusta_senior').value==='bunny:ccc' && d2.getElementById('coMascSen').checked===false);
  d2.getElementById('cm_fine_lezione_junior').value='bunny:nuovo'; d2.getElementById('coMascSen').checked=true;
  await w2.salvaCorso(); await at(60);
  const up=w2.__scr.filter(x=>x.t==='edu_corsi'&&x.op==='update').pop();
  ok('salvaCorso: jsonb completo con video per fascia e flag', up && up.p.mascotte.video.junior.fine_lezione==='bunny:nuovo' && up.p.mascotte.video.entrambi.giusta==='bunny:bbb' && up.p.mascotte.senior===true && up.p.mascotte.nome==='Coccio di sale');
  d2.getElementById('coMascImporta').value='sale-in-classe'; await w2.importaMascotteCorso(); await at(80);
  ok('importa dal progetto: nome, immagine e video (i disattivati esclusi)', d2.getElementById('coMascNome').value==='Coccio importato' && d2.getElementById('cm_fine_corso_entrambi').value==='bunny:fine' && d2.getElementById('cm_giusta_junior').value==='');
  ['coMascNome','coMascImg'].forEach(i=>d2.getElementById(i).value=''); d2.querySelectorAll('#coMascGrid input[type=text]').forEach(i=>i.value='');
  await w2.salvaCorso(); await at(60);
  ok('tutto vuoto → mascotte null (nessuna mascotte per il corso)', w2.__scr.filter(x=>x.t==='edu_corsi'&&x.op==='update').pop().p.mascotte===null);
  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.message);process.exit(1);});
