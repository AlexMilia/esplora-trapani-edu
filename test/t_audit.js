const { JSDOM } = require('jsdom'); const fs=require('fs');
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
function player(menu){
  let html=fs.readFileSync('/tmp/pag26.html','utf8');
  html=html.replace('<head>','<head><script>window.fetch=(u)=>{const s=String(u);let b=s.includes("action=menu")?'+JSON.stringify(JSON.stringify(menu))+':\'{"ok":true}\';return Promise.resolve({json:()=>Promise.resolve(JSON.parse(b))});};window.AFRAME={registerComponent(){}};window.alert=()=>{};window.EduLive={apri(){}};</script>').replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const D=new JSDOM(html,{url:'http://localhost/index.php',runScripts:'dangerously',pretendToBeVisual:true});
  D.window.HTMLMediaElement.prototype.play=()=>Promise.resolve(); D.window.HTMLMediaElement.prototype.pause=()=>{}; D.window.HTMLMediaElement.prototype.load=()=>{};
  return D;
}
function regia(utente,corsi){
  let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
  html=html.replace('<head>','<head><script>window.__scr=[];window.__toast=[];'+
   'window.__fx={edu_clienti:[{id:"cl-1",slug:"c1",nome:"Cliente",piano:"pro",licenza_stato:"attiva",brand:{}}],edu_corsi:'+JSON.stringify(corsi)+',edu_utenti:[],edu_lezioni:[],edu_scuole:[],edu_classi:[],edu_catalogo:[],edu_progetti:[],edu_richieste:[]};'+
   'function q(t){const st={t,op:"select",f:[],p:null};const o={};o.select=()=>o;o.order=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.insert=(x)=>{st.op="insert";st.p=x;return o;};o.update=(x)=>{st.op="update";st.p=x;return o;};o.delete=()=>o;o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
   'o.then=(r)=>{if(st.op!=="select"){window.__scr.push({t,op:st.op,p:st.p});const riga=Object.assign({id:"n-"+t+"-"+window.__scr.length},st.p||{});if(st.op==="insert")(window.__fx[t]=window.__fx[t]||[]).push(riga);return r({data:riga,error:null});}let rows=window.__fx[t]||[];st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));return r({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
   'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u1"}}}}),onAuthStateChange:()=>{}},from:q,rpc:async()=>({data:null,error:null})})};'+
   'window.Hls={isSupported:()=>false};window.confirm=()=>true;window.prompt=()=>window.__prompt;</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
  html=html.replace('edu_utenti:[]','edu_utenti:['+JSON.stringify(utente)+']');
  const D=new JSDOM(html,{url:'http://localhost/r.html',runScripts:'dangerously',pretendToBeVisual:true});
  return D;
}
(async()=>{
  console.log('— F1. Cliente senza corsi pubblicati —');
  const D=player({ok:true,quizSempre:false,mascotte:{},mascotteLiv:{},mascotteCfg:{junior:false,senior:false},cliente:{nome:'Nuovo Cliente',brand:{titolo:'Nuovo'}},corsi:[],lezioni:[]});
  await at(450);
  const t=D.window.document.getElementById('menuLez').textContent;
  ok('messaggio chiaro invece di «Carico le lezioni…» infinito', t.includes('Nessun corso disponibile') && !t.includes('Carico'));

  console.log('— F2. Editor senza corsi: nuova lezione bloccata con spiegazione —');
  const R=regia({id:'u1',ruolo:'editor',cliente_id:'cl-1'},[]); const w=R.window; await at(400);
  
  const s=w.document.createElement('script'); s.textContent='toast=(m)=>window.__toast.push(m);'; w.document.body.appendChild(s);
  w.__prompt='Lezione nuova'; await w.nuovaLezione(); await at(50);
  ok('nessun insert e messaggio «Prima crea un corso»', w.__scr.filter(x=>x.t==='edu_lezioni').length===0 && w.__toast.some(m=>m.includes('Prima crea un corso')));

  console.log('— F3. Admin senza corsi: la lezione (senza corso) si crea ancora —');
  const R2=regia({id:'u1',ruolo:'admin',cliente_id:null},[]); const w2=R2.window; await at(400);
  
  w2.__prompt='Lezione admin'; await w2.nuovaLezione(); await at(50);
  ok('admin può creare lezione senza corso (legacy)', w2.__scr.some(x=>x.t==='edu_lezioni'&&x.op==='insert'));

  console.log('— F4. Slug riservati —');
  ok('slugOk rifiuta app/ver7/api e accetta ic-pagoto', !w2.slugOk('app') && !w2.slugOk('ver7') && !w2.slugOk('api') && w2.slugOk('ic-pagoto'));
  w2.__prompt='App'; await w2.nuovoCliente(); await at(50);
  const nc=w2.__scr.find(x=>x.t==='edu_clienti'&&x.op==='insert');
  ok('cliente chiamato «App» ottiene slug non riservato', nc && nc.p.slug==='c-app');

  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.message);process.exit(1);});
