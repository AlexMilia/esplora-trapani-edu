const { JSDOM } = require('jsdom'); const fs=require('fs');
let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
html=html.replace('<head>','<head><script>window.__upd=[];window.__toast=[];'+
 'window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session:null}}),onAuthStateChange:()=>{}},'+
 'from:(t)=>({update:(p)=>({eq:async(k,v)=>{window.__upd.push({t,p,id:v});return {error:null};}})})})};'+
 'window.Hls={isSupported:()=>false};window.alert=()=>{};</script>').replace(/<script src="https:[^"]*"><\/script>/g,'');
const dom=new JSDOM(html,{url:'http://localhost/r.html',runScripts:'dangerously'});
const w=dom.window,d=w.document;
const at=ms=>new Promise(r=>setTimeout(r,ms)); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
setTimeout(async()=>{
  const s=d.createElement('script'); s.textContent="MEDIA=[{id:'m1',tipo:'video',guid:'g1',audio_url:null,audio_vol:45}]; toast=(m)=>window.__toast.push(m); selMedia=null; renderMedia();";
  d.body.appendChild(s); await at(50);
  ok('riga media con campo audio, volume e tasto ascolta',
     !!d.getElementById('aud_m1') && d.getElementById('avol_m1').value==='45' && !!d.getElementById('aprv_m1'));
  const set=(u,v)=>{d.getElementById('aud_m1').value=u; if(v!==undefined)d.getElementById('avol_m1').value=v;};
  set('https://www.youtube.com/watch?v=x'); await w.salvaAudio('m1');
  ok('YouTube rifiutato', w.__upd.length===0 && w.__toast.some(t=>t.includes('file audio')));
  set('http://cdn.x.it/a.mp3'); await w.salvaAudio('m1');
  ok('http rifiutato', w.__upd.length===0 && w.__toast.some(t=>t.includes('https')));
  set('https://cdn.x.it/cartella/'); await w.salvaAudio('m1');
  ok('URL non-file rifiutato', w.__upd.length===0);
  set('https://cdn.x.it/goccia-1.mp3', '30'); await w.salvaAudio('m1'); await at(20);
  ok('mp3 https salvato con volume', w.__upd.length===1 && w.__upd[0].p.audio_url==='https://cdn.x.it/goccia-1.mp3' && w.__upd[0].p.audio_vol===30 && w.__upd[0].id==='m1');
  set('https://cdn.x.it/voce.m4a?v=2', '150'); await w.salvaAudio('m1'); await at(20);
  ok('m4a con query ok, volume oltre 100 limitato a 100', w.__upd[1].p.audio_url.includes('.m4a') && w.__upd[1].p.audio_vol===100);
  set('', '45'); await w.salvaAudio('m1'); await at(20);
  ok('campo svuotato = audio rimosso (null)', w.__upd[2].p.audio_url===null);
  console.log('RISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
},300);
