/* test della logica della demo VR — node test-vr-logic.js */
const L=require('./vr-logic.js'); const D=require('./dati.json'); let p=0,f=0;
const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
const a=L.posizione(0,0,7), b=L.posizione(90,0,7), c=L.posizione(0,90,7);
ok('yaw 0 davanti', Math.abs(a.x)<1e-9 && a.z<-6.9); ok('yaw 90 destra', b.x>6.9); ok('pitch 90 sopra', c.y>6.9);
ok('hotspot sulla sfera', D.lezioni.flatMap(l=>l.tappe.flatMap(t=>t.hot)).every(h=>{const q=L.posizione(h.yaw,h.pitch,7);return Math.abs(Math.hypot(q.x,q.y,q.z)-7)<1e-6;}));
for(const l of D.lezioni){ const s=L.creaStato(l); let aperte=0;
  for(let v=0;v<l.video.length;v++){ s.vidIdx=v; for(let t=0;t<400;t+=0.25){ const x=L.tappaDaAprire(s,l,t); if(x){aperte++; L.apriTappa(s,x.i); for(let k=0;k<l.tappe[x.i].hot.length;k++)L.hotspotLetto(s,l);} } if(v<l.video.length-1)L.fineClip(s,l); }
  ok(l.id+': tutte le tappe una volta sola, poi quiz', aperte===l.tappe.filter(t=>t.hot.length).length && L.fineClip(s,l)==='quiz');
  let r; while(s.fase!=='fine') r=L.rispondi(s,l,l.quiz[s.quizIdx].ok); ok(l.id+': quiz completo, tutte giuste = '+s.punti+'/'+l.quiz.length, r.fine && s.punti===l.quiz.length); }
const s0=L.creaStato(D.lezioni[0]); const x=L.tappaDaAprire(s0,D.lezioni[0],41.5); L.apriTappa(s0,x.i);
ok('tappa di indice 0 blocca le successive (bug !== null)', L.tappaDaAprire(s0,D.lezioni[0],999)===null);
ok('spezza rispetta il limite', L.spezza('la raccolta del sale raccontata da chi la fa davvero',20).split('\n').every(r=>r.length<=20));
ok('arco simmetrico', (()=>{const m=L.arcoMenu(6,3.2,120);return Math.abs(m[0].x+m[5].x)<1e-9;})());
console.log('RISULTATO: '+p+' passati, '+f+' falliti'); process.exit(f?1:0);
