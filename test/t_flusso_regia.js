/* FLUSSO REGIA — creazione di un tenant dall'inizio alla fine, nella sequenza reale dell'admin */
const { JSDOM } = require('jsdom'); const fs=require('fs');
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
html=html.replace('<head>','<head><script>window.__scr=[];window.__rpc=[];window.__toast=[];window.__prompts=[];'+
 'window.__fx={edu_clienti:[],edu_corsi:[],edu_lezioni:[],edu_media:[],edu_scuole:[],edu_classi:[],edu_catalogo:[],edu_richieste:[{id:"r1",scuola:"IC Nuovo",referente:"Prof. Verdi",email:"verdi@icnuovo.it",interesse:"salina",stato:"nuova",creato_il:"2026-09-20T10:00:00Z"}],edu_progetti:[],edu_mascotte:[],'+
 'edu_utenti:[{id:"u-ale",nome:"Alessandro",ruolo:"admin",cliente_id:null},{id:"u-new",nome:"Editor Nuovo",ruolo:"docente",cliente_id:null}]};'+
 'let seq=0; function q(t){const st={t,op:"select",f:[]};const o={};o.select=()=>o;o.order=()=>o;o.limit=()=>o;o.in=()=>o;o.eq=(k,v)=>{st.f.push([k,v]);return o;};o.insert=(x)=>{st.op="insert";st.p=x;return o;};o.update=(x)=>{st.op="update";st.p=x;return o;};o.delete=()=>{st.op="delete";return o;};o.single=()=>{st.s=1;return o;};o.maybeSingle=()=>{st.s=1;return o;};'+
 'o.then=(res)=>{let rows=window.__fx[t]||[];if(st.op==="insert"){const riga=Object.assign({id:t+"-"+(++seq)},(t==="edu_lezioni"||t==="edu_corsi")?{stato:"bozza"}:{},st.p);(window.__fx[t]=window.__fx[t]||[]).push(riga);window.__scr.push({t,op:"insert",p:riga});return res({data:riga,error:null});}'+
 'st.f.forEach(([k,v])=>rows=rows.filter(x=>x[k]===v));if(st.op==="update"){rows.forEach(r=>Object.assign(r,st.p));window.__scr.push({t,op:"update",p:st.p,n:rows.length});return res({data:rows,error:null});}'+
 'if(st.op==="delete"){window.__fx[t]=(window.__fx[t]||[]).filter(r=>!rows.includes(r));window.__scr.push({t,op:"delete",n:rows.length});return res({data:null,error:null});}'+
 'return res({data:st.s?(rows[0]||null):rows,error:null});};return o;}'+
 'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:"u-ale",email:"ale@x.it"}}}}),onAuthStateChange:()=>{}},from:q,'+
 'rpc:async(fn,args)=>{window.__rpc.push({fn,args});if(fn==="edu_piano_limiti")return {data:args.p_piano==="base"?{corsi_pubblicati:1,quiz_live:false,classi:10,nome:"Base"}:{corsi_pubblicati:999,quiz_live:true,classi:999,nome:"Pro"},error:null};if(fn==="edu_stats_cliente")return {data:{totali:{scuole:1,classi:1,avviate:1,completate:0,quiz:1,partite_live:0,pct_medio:100},per_scuola:[{scuola:"Plesso Centro",classi:1,avviate:1,completate:0,pct_medio:100}],per_classe:[],per_lezione:[],ultimi_30gg:[]},error:null};return {data:null,error:null};}})};'+
 'window.Hls={isSupported:()=>false};window.confirm=()=>true;window.__coda=[];window.prompt=(m,d)=>{window.__prompts.push(m);if(window.__coda.length)return window.__coda.shift();return window.__risposta!==undefined?window.__risposta:d;};window.alert=()=>{};'+
 'window.navigator.clipboard={writeText:async(t)=>{window.__copiato=t;}};</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
const dom=new JSDOM(html,{url:'http://localhost/regia-edu.html',runScripts:'dangerously',pretendToBeVisual:true}); const w=dom.window,d=w.document;
w.HTMLMediaElement.prototype.play=()=>Promise.resolve(); w.HTMLMediaElement.prototype.pause=()=>{}; w.HTMLMediaElement.prototype.load=()=>{};
(async()=>{
  await at(450); const s=d.createElement('script'); s.textContent='toast=(m)=>window.__toast.push(m);'; d.body.appendChild(s);
  console.log('— 1. Richiesta pubblica → cliente in un clic —');
  await w.apriClienti(); await at(80);
  ok('la richiesta di IC Nuovo è in lista', d.getElementById('richList').textContent.includes('IC Nuovo'));
  await w.attivaDaRichiesta('r1'); await at(120);
  const cl=w.__fx.edu_clienti.find(c=>c.slug==='ic-nuovo');
  ok('cliente creato: slug ic-nuovo, referente ed email dalla richiesta, richiesta → attivata', cl && cl.contatto_email==='verdi@icnuovo.it' && w.__fx.edu_richieste[0].stato==='attivata');
  console.log('— 2. Licenza e piano —');
  await w.apriClienti(); await at(60); w.apriCliente(cl.id); await at(60);
  d.getElementById('clPiano').value='base'; d.getElementById('clFine').value='2027-06-30'; d.getElementById('clStato').value='attiva';
  await w.salvaCliente(); await at(50);
  ok('piano base con scadenza salvati', cl.piano==='base' && cl.licenza_fine==='2027-06-30');
  d.getElementById('ur_u-new').value='editor'; d.getElementById('uc_u-new').value=cl.id; await w.salvaUtente('u-new'); await at(40);
  ok('utente assegnato come editor del cliente', w.__fx.edu_utenti[1].ruolo==='editor' && w.__fx.edu_utenti[1].cliente_id===cl.id);
  console.log('— 3. Corso, mascotte, pubblicazione (limite del piano) —');
  await w.apriCorsi(); await at(60); d.getElementById('cCliente').value=cl.id; w.__risposta='Il mio paese'; await w.nuovoCorso(); await at(80);
  const co=w.__fx.edu_corsi.find(c=>c.proprietario_id===cl.id);
  ok('corso creato in bozza nel cliente giusto, con slug', co && co.stato==='bozza' && co.slug==='il-mio-paese');
  w.apriCorso(co.id); await at(80);
  d.getElementById('coMascNome').value='Gufo'; d.getElementById('coStato').value='pubblicato'; await w.salvaCorso(); await at(60);
  ok('corso pubblicato con la sua mascotte (1° corso: consentito dal piano base)', co.stato==='pubblicato' && co.mascotte && co.mascotte.nome==='Gufo');
  w.__risposta='Secondo corso'; await w.nuovoCorso(); await at(80); const co2=w.__fx.edu_corsi.find(c=>c.slug==='secondo-corso'); w.apriCorso(co2.id); await at(60);
  d.getElementById('coStato').value='pubblicato'; await w.salvaCorso(); await at(60);
  ok('2° corso pubblicato BLOCCATO dal piano base, con spiegazione', co2.stato==='bozza' && w.__toast.some(t=>t.includes('consente')));
  console.log('— 4. Lezione dentro il corso —');
  w.__risposta='La piazza'; w.scegliCorsoPrompt=()=>co; await w.nuovaLezione(); await at(100);
  const lz=w.__fx.edu_lezioni.find(l=>l.titolo==='La piazza');
  ok('lezione creata in bozza dentro il corso', lz && lz.corso_id===co.id && lz.stato==='bozza');
  console.log('— 5. Scuola, classe, link —');
  await w.apriScuole(); await at(60); d.getElementById('scCliente').value=cl.slug; w.__risposta='Plesso Centro'; await w.nuovaScuola(); await at(80);
  const sc=w.__fx.edu_scuole.find(s=>s.cliente_id===cl.id); ok('scuola creata come ospite', sc && sc.tipo==='ospite');
  w.__coda=['4ª B','2026/27']; await w.nuovaClasse(); await at(80);
  const k=w.__fx.edu_classi.find(x=>x.scuola_id===sc.id);
  ok('classe creata nella scuola con codice generato e anno', k && /^PLES-4-B-/.test(k.codice) && k.anno==='2026/27');
  await w.renderClassi(); await at(40); const link=d.getElementById('classiList').textContent;
  ok('link della classe = /project/edu/ic-nuovo/?classe=CODICE', link.includes('/project/edu/ic-nuovo/?classe='+k.codice));
  console.log('— 6. Catalogo: ricevere un corso in licenza —');
  w.__fx.edu_clienti.push({id:'cl-sal',slug:'salina-culcasi',nome:'Salina',piano:'premium',licenza_stato:'attiva',brand:{}});
  w.__fx.edu_corsi.push({id:'co-goc',proprietario_id:'cl-sal',slug:'la-vita-della-goccia',titolo:'Il viaggio di una goccia',stato:'pubblicato',visibilita:'catalogo'});
  await w.apriCatalogo('co-goc'); await at(80); d.getElementById('catDest').value=cl.id; d.getElementById('catA').value='2027-06-30'; await w.concediCorso(); await at(60);
  ok('la goccia concessa a ic-nuovo fino a giugno', w.__fx.edu_catalogo.some(x=>x.corso_id==='co-goc'&&x.cliente_id===cl.id&&x.a==='2027-06-30'));
  console.log('— 7. Statistiche del nuovo cliente —');
  await w.apriStats(); await at(80); d.getElementById('stCliente').value=cl.slug; await w.caricaStats(); await at(60);
  ok('statistiche caricate per ic-nuovo (Plesso Centro, 100%)', d.getElementById('stScuole').textContent.includes('Plesso Centro') && w.__rpc.some(r=>r.fn==='edu_stats_cliente'&&r.args.p_slug==='ic-nuovo'));
  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e.stack.split('\n').slice(0,3).join(' | '));process.exit(1);});
