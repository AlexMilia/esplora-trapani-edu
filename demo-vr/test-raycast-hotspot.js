const THREE=require('./lib/three.cjs');
const L=require('./vr-logic.js'); const D=require('./dati.json');
/* Ricostruisco l'hotspot ESATTAMENTE come lo crea index.html: anello 0.42-0.6 (+ pallino visivo senza classe cl) a 7 m, rivolto alla camera. */
function hotspot(yaw,pitch,conBersaglio){
  const g=new THREE.Group(); const p=L.posizione(yaw,pitch,7); g.position.set(p.x,p.y,p.z); g.lookAt(0,1.6,0);
  const ring=new THREE.Mesh(new THREE.RingGeometry(0.42,0.6,32),new THREE.MeshBasicMaterial({side:THREE.DoubleSide})); ring.name='ring.cl'; g.add(ring);
  if(conBersaglio){ const b=new THREE.Mesh(new THREE.CircleGeometry(0.7,32),new THREE.MeshBasicMaterial({transparent:true,opacity:0,side:THREE.DoubleSide})); b.name='bersaglio.cl'; b.position.z=-0.005; g.add(b); }
  g.updateMatrixWorld(true); return g;
}
/* il laser del controller: parte dalla mano (0.3 m a destra, 1.3 m di altezza) e punta verso il bersaglio con un errore angolare */
function laser(target,errGradi){
  const origin=new THREE.Vector3(0.3,1.3,0); const dir=target.clone().sub(origin).normalize();
  const e=errGradi*Math.PI/180; const q=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),e); dir.applyQuaternion(q);
  return new THREE.Raycaster(origin,dir,0,40);
}
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
const hots=D.lezioni.flatMap(l=>l.tappe.flatMap(t=>t.hot));
console.log('— A. COM\'È ORA (solo anello, classe cl) —');
let centroMiss=0, bordoHit=0;
for(const h of hots){ const g=hotspot(h.yaw,h.pitch,false); const centro=new THREE.Vector3(); g.getWorldPosition(centro);
  const r1=laser(centro,0).intersectObjects([g.children[0]],false);           // mira PERFETTA al centro
  if(!r1.length) centroMiss++;
  const r2=laser(centro,4.2).intersectObjects([g.children[0]],false);         // mira sul bordo (~0.5 m a 7 m)
  if(r2.length) bordoHit++; }
console.log('  (dimostrazione del difetto v1.0) centro colpito: '+(centroMiss===0?'sì':'NO'));
console.log('    → centro mancato in '+centroMiss+'/'+hots.length+' hotspot: il buco dell\'anello (r<0.42) è vuoto per il raycaster');
console.log('  (dimostrazione del difetto v1.0) anello colpito: '+(bordoHit===hots.length?'sì':'NO'));
console.log('— B. CON IL BERSAGLIO PIENO invisibile (la correzione) —');
let cm=0, bm=0, largo=0;
for(const h of hots){ const g=hotspot(h.yaw,h.pitch,true); const centro=new THREE.Vector3(); g.getWorldPosition(centro);
  const cl=g.children.filter(c=>c.name.endsWith('.cl'));
  if(!laser(centro,0).intersectObjects(cl,false).length) cm++;
  if(!laser(centro,4.2).intersectObjects(cl,false).length) bm++;
  if(!laser(centro,5.2).intersectObjects(cl,false).length) largo++; }
ok('centro colpito su tutti i '+hots.length+' hotspot', cm===0);
ok('bordo colpito su tutti', bm===0);
ok('tolleranza: anche con 5° di errore (bersaglio 0.7 m a 7 m) si colpisce', largo===0);
console.log('RISULTATO: '+p+' passati, '+f+' falliti');
