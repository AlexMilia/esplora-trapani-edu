/* Test XSS: nomi malevoli in scuole/classi non devono eseguire codice */
const { JSDOM } = require('jsdom'); const fs=require('fs');
let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
const SCUOLE=[{id:'sc-x',cliente_id:'cl-1',nome:"5ª A');alert('XSS');('",citta:'<img src=x onerror=alert(1)>',tipo:'ospite',licenza_stato:'attiva',licenza_a:null}];
const CLASSI=[{id:'k-x',cliente_id:'cl-1',scuola_id:'sc-x',codice:'ABC-1A-X',nome:"Classe'\"><script>alert(2)</script>",anno:'2026/27'}];
const esc4js=(s)=>s.replace(/<\//g,'<\\/');
html=html.replace('<head>','<head><script>window.__xss=0;window.alert=()=>{window.__xss++};'+
 'window.__fx={edu_clienti:[{id:"cl-1",slug:"c1",nome:"Cliente",piano:"pro",licenza_stato:"attiva",brand:{}}],edu_scuole:'+esc4js(JSON.stringify(SCUOLE))+',edu_classi:'+esc4js(JSON.stringify(CLASSI))+',edu_corsi:[],edu_utenti:[{id:"u1",ruolo:"admin",cliente_id:null}],edu_lezioni:[]};'+
 'function q(t){const st={t,op:"select",f:[]};const o={};o.select=()=>o;o.order=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.insert=()=>o;o.update=()=>o;o.delete=()=>o;o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
 'o.then=(r)=>{let rows=window.__fx[t]||[];st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));return r({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
 'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u1"}}}}),onAuthStateChange:()=>{}},from:q,rpc:async()=>({data:null,error:null})})};'+
 'window.Hls={isSupported:()=>false};window.confirm=()=>true;window.prompt=()=>"";</script>')
 .replace(/<script src="https:[^"]*"><\/script>/g,'');
const dom=new JSDOM(html,{url:'http://localhost/r.html',runScripts:'dangerously',pretendToBeVisual:true});
const w=dom.window,d=w.document; const at=ms=>new Promise(r=>setTimeout(r,ms));
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
setTimeout(async()=>{
  await w.apriScuole(); await at(120);
  ok('nome malevolo della scuola: nessun codice eseguito', w.__xss===0);
  ok('nome mostrato come testo, non interpretato', d.getElementById('scuoleList').textContent.includes("alert('XSS')"));
  ok('img onerror non creata nel DOM', d.querySelectorAll('#scuoleList img').length===0);
  await w.apriScuola('sc-x'); await at(120);
  ok('classe con <script> nel nome: nessuna esecuzione', w.__xss===0 && d.querySelectorAll('#classiList script').length===0);
  const clic=d.querySelector('#classiList button');
  if(clic) clic.click(); await at(60);
  ok('click sui pulsanti generati non esegue payload', w.__xss===0);
  console.log('RISULTATO XSS: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
},400);
