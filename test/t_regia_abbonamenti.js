/* REGIA v17 — blocco Abbonamento: stati, pulsanti, chiamate a stripe.php con il token dell'admin */
const { JSDOM } = require('jsdom'); const fs=require('fs');
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
const CL={id:'cl-1',slug:'ic-nuovo',nome:'IC Nuovo',piano:'pro',licenza_stato:'attiva',brand:{},contatto_email:'verdi@icnuovo.it'};
html=html.replace('<head>','<head><script>window.__fetch=[];window.__ab={stato:"nessuno",pagamenti:[]};window.__toast=[];'+
 'window.__fx={edu_clienti:['+JSON.stringify(CL)+'],edu_corsi:[],edu_lezioni:[],edu_utenti:[{id:"u-ale",nome:"Ale",ruolo:"admin",cliente_id:null}],edu_scuole:[],edu_classi:[],edu_catalogo:[],edu_richieste:[],edu_progetti:[]};'+
 'function q(t){const st={t,f:[]};const o={};o.select=()=>o;o.order=()=>o;o.in=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.insert=()=>o;o.update=()=>o;o.delete=()=>o;o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
 'o.then=(r)=>{let rows=window.__fx[t]||[];st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));return r({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
 'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u-ale"},access_token:"tok-admin"}}}),onAuthStateChange:()=>{}},from:q,rpc:async(fn,a)=>{if(fn==="edu_abbonamento_cliente")return {data:window.__ab,error:null};return {data:null,error:null};}})};'+
 'window.fetch=async(u,o)=>{window.__fetch.push({u:String(u),h:o&&o.headers,b:o&&o.body?JSON.parse(o.body):null});const az=String(u).split("azione=")[1];'+
 ' if(az==="crea"){window.__ab={stato:"in_attesa",piano:"pro",periodo:"anno",link:"https://invoice.stripe.com/i/in_1",pagamenti:[]};return {json:async()=>({ok:true,link:"https://invoice.stripe.com/i/in_1",messaggio:"Abbonamento creato: Stripe ha inviato il link"})};}'+
 ' if(az==="pausa"){window.__ab.stato="in_pausa";return {json:async()=>({ok:true,stato:"in_pausa",messaggio:"in pausa"})};}'+
 ' if(az==="riprendi"){window.__ab.stato="attivo";return {json:async()=>({ok:true,stato:"attivo",messaggio:"ripreso"})};}'+
 ' if(az==="annulla"){window.__ab.stato="annullato";return {json:async()=>({ok:true,stato:"annullato",messaggio:"annullato"})};}'+
 ' return {json:async()=>({ok:false,err:"boh"})};};'+
 'window.Hls={isSupported:()=>false};window.confirm=()=>true;window.prompt=(m,d)=>window.__prompt!==undefined?window.__prompt:d;window.alert=()=>{};window.navigator.clipboard={writeText:async()=>{}};</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
const dom=new JSDOM(html,{url:'http://localhost/regia-edu.html',runScripts:'dangerously',pretendToBeVisual:true}); const w=dom.window,d=w.document;
w.HTMLMediaElement.prototype.play=()=>Promise.resolve(); w.HTMLMediaElement.prototype.pause=()=>{}; w.HTMLMediaElement.prototype.load=()=>{};
(async()=>{
  await at(450); const s=d.createElement('script'); s.textContent='toast=(m)=>window.__toast.push(m);'; d.body.appendChild(s);
  await w.apriClienti(); await at(80); w.apriCliente('cl-1'); await at(150);
  console.log('— stato iniziale —');
  ok('blocco abbonamento con email del referente e stato «Nessun abbonamento»', d.getElementById('abEmail').textContent==='verdi@icnuovo.it' && d.getElementById('abStato').textContent.includes('Nessun abbonamento'));
  ok('pulsanti pausa/riprendi/annulla nascosti, «Invia link» attivo', d.getElementById('abPausa').style.display==='none' && d.getElementById('abAnnulla').style.display==='none' && !d.getElementById('abCrea').disabled);
  console.log('— invia link —');
  d.getElementById('abPiano').value='pro'; d.getElementById('abPeriodo').value='anno'; await w.abbonamentoCrea(); await at(150);
  const c=w.__fetch.find(x=>x.u.includes('azione=crea'));
  ok('chiamata a stripe.php?azione=crea con token admin e cliente/piano/periodo', c && c.h.Authorization==='Bearer tok-admin' && c.b.cliente_id==='cl-1' && c.b.piano==='pro' && c.b.periodo==='anno');
  ok('stato → In attesa del pagamento, con il link visibile', d.getElementById('abStato').textContent.includes('In attesa') && d.getElementById('abStato').innerHTML.includes('invoice.stripe.com'));
  ok('«Invia link» disabilitato, «Annulla» e «Copia link» visibili', d.getElementById('abCrea').disabled && d.getElementById('abAnnulla').style.display==='' && d.getElementById('abLink').style.display==='');
  console.log('— dopo il pagamento (simulo lo stato dal webhook) —');
  w.__ab={stato:'attivo',piano:'pro',periodo:'anno',fine:'2027-09-24T00:00:00Z',pagamenti:[{tipo:'invoice.paid',importo_cent:10000,quando:'2026-09-24T10:00:00Z',link:'https://invoice.stripe.com/i/in_1'}]}; await w.abbonamentoRender(); await at(50);
  ok('stato Attivo · piano Pro annuale · fino al 24/09/2027 · storico con ricevuta', d.getElementById('abStato').textContent.includes('Attivo') && d.getElementById('abStato').textContent.includes('Pro') && d.getElementById('abStato').textContent.includes('2027') && d.getElementById('abStorico').innerHTML.includes('ricevuta'));
  ok('pausa visibile, riprendi nascosto', d.getElementById('abPausa').style.display==='' && d.getElementById('abRiprendi').style.display==='none');
  console.log('— pausa / riprendi / annulla —');
  await w.abbonamentoPausa(); await at(120);
  ok('pausa: chiamata e stato «In pausa», riprendi visibile', w.__fetch.some(x=>x.u.includes('azione=pausa')) && d.getElementById('abStato').textContent.includes('In pausa') && d.getElementById('abRiprendi').style.display==='');
  await w.abbonamentoRiprendi(); await at(120);
  ok('riprendi: stato Attivo', d.getElementById('abStato').textContent.includes('Attivo'));
  w.__prompt='FINE'; await w.abbonamentoAnnulla(); await at(120);
  const an=w.__fetch.filter(x=>x.u.includes('azione=annulla')).pop();
  ok('annulla scrivendo FINE → quando=fine_periodo', an && an.b.quando==='fine_periodo');
  w.__ab.stato='attivo'; w.__prompt='SUBITO'; await w.abbonamentoAnnulla(); await at(120);
  ok('annulla scrivendo SUBITO → quando=subito, stato Annullato, «Invia link» di nuovo attivo', w.__fetch.filter(x=>x.u.includes('azione=annulla')).pop().b.quando==='subito' && d.getElementById('abStato').textContent.includes('Annullato') && !d.getElementById('abCrea').disabled);
  w.__prompt='forse'; const n=w.__fetch.length; await w.abbonamentoAnnulla(); await at(50);
  ok('risposta diversa da FINE/SUBITO → nessuna chiamata', w.__fetch.length===n && w.__toast.some(t=>t.includes('FINE oppure SUBITO')));
  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.stack.split('\n').slice(0,3).join(' | '));process.exit(1);});
