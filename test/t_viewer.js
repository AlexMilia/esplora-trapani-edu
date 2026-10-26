/* Il viewer della regia: aprire una lezione con un video NON deve lanciare eccezioni e deve aggiornare «stato video» */
const { JSDOM } = require('jsdom'); const fs=require('fs');
let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
html=html.replace('<head>','<head><script>window.__err=[];window.__fx={edu_clienti:[{id:"cl-1",slug:"c1",nome:"C",piano:"pro",licenza_stato:"attiva",brand:{}}],edu_corsi:[{id:"co-1",proprietario_id:"cl-1",slug:"s",titolo:"S",stato:"pubblicato"}],'+
 'edu_lezioni:[{id:"l1",slug:"salinaio",titolo:"Il salinaio",stato:"pubblicata",ordine:10,corso_id:"co-1",accessibilita:{}}],edu_media:[{id:"m1",lezione_id:"l1",ordine:10,tipo:"video",guid:"abc-123"}],edu_tappe:[],edu_hotspot:[],edu_quiz:[],edu_utenti:[{id:"u1",ruolo:"admin",cliente_id:null,nome:"Ale"}],edu_scuole:[],edu_classi:[],edu_catalogo:[],edu_richieste:[],edu_progetti:[]};'+
 'function q(t){const st={t,op:"select",f:[]};const o={};o.select=()=>o;o.order=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.in=()=>o;o.insert=()=>o;o.update=()=>o;o.delete=()=>o;o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
 'o.then=(r)=>{let rows=window.__fx[t]||[];st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));return r({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
 'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u1"}}}}),onAuthStateChange:()=>{}},from:q,rpc:async()=>({data:null,error:null})})};'+
 'window.Hls={isSupported:()=>false};window.addEventListener("error",e=>window.__err.push(e.message));window.addEventListener("unhandledrejection",e=>window.__err.push(String(e.reason)));</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
const dom=new JSDOM(html,{url:'http://localhost/r.html',runScripts:'dangerously',pretendToBeVisual:true}); const w=dom.window,d=w.document;
w.HTMLMediaElement.prototype.load=function(){}; w.HTMLMediaElement.prototype.play=()=>Promise.resolve(); w.HTMLMediaElement.prototype.pause=()=>{};
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
setTimeout(async()=>{
  ok('la funzione vidStato esiste', typeof w.vidStato==='function');
  await w.apriLezione('l1'); await at(300);
  ok('apriLezione con video: nessuna eccezione (prima: "vidStato is not a function")', w.__err.filter(e=>/vidStato/.test(e)).length===0);
  ok('stato video aggiornato nel pannello', d.getElementById('vidStato').textContent!=='—');
  const v=d.getElementById('vwVideo')||d.querySelector('video'); v.dispatchEvent(new w.Event('waiting')); await at(20);
  ok('eventi del video gestiti (buffering)', d.getElementById('vidStato').textContent.includes('buffering'));
  console.log('RISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
},400);
