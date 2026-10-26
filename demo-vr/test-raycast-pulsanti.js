const THREE=require('./lib/three.cjs');
/* pulsante come lo crea bottone(): a-plane pieno w×0.32 con classe cl, dentro un pannello a 2.6 m rivolto alla camera */
function pulsante(w,offY){ const g=new THREE.Group(); g.position.set(0,1.6,-2.6); g.lookAt(0,1.6,0);
  const m=new THREE.Mesh(new THREE.PlaneGeometry(w,0.32),new THREE.MeshBasicMaterial({side:THREE.DoubleSide})); m.position.set(0,offY,0.02); g.add(m); g.updateMatrixWorld(true); return {g,m}; }
function laser(target,errGradi){ const o=new THREE.Vector3(0.3,1.3,0); const d=target.clone().sub(o).normalize(); d.applyQuaternion(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),errGradi*Math.PI/180)); return new THREE.Raycaster(o,d,0,40); }
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};
for(const [nome,w,y] of [['Ho capito (1.3 m)',1.3,-0.72],['risposta quiz (2.6 m)',2.6,0.15],['Torna alle lezioni (1.8 m)',1.8,-0.45]]){
  const {m}=pulsante(w,y); const c=new THREE.Vector3(); m.getWorldPosition(c);
  const centro=laser(c,0).intersectObject(m).length>0, bordo=laser(c,Math.atan((w/2)*0.9/2.6)*180/Math.PI).intersectObject(m).length>0, fuori=laser(c,Math.atan((w/2)*1.3/2.6)*180/Math.PI).intersectObject(m).length===0;
  ok(nome+': centro e bordo colpiti, fuori dal pulsante no', centro&&bordo&&fuori); }
/* card del menu ad arco: 1.25×0.78 a 3.2 m, ruotata verso il centro */
const L=require('./vr-logic.js'); const arc=L.arcoMenu(6,3.2,120); let cardOk=0;
for(const pos of arc){ const g=new THREE.Group(); g.position.set(pos.x,pos.y,pos.z); g.rotation.y=pos.rotY*Math.PI/180; const m=new THREE.Mesh(new THREE.PlaneGeometry(1.25,0.78),new THREE.MeshBasicMaterial({side:THREE.DoubleSide})); g.add(m); g.updateMatrixWorld(true);
  const c=new THREE.Vector3(); m.getWorldPosition(c); if(laser(c,0).intersectObject(m).length) cardOk++; }
ok('tutte le 6 card del menu colpibili col laser (anche quelle laterali a ±60°)', cardOk===6);
console.log('RISULTATO: '+p+' passati, '+f+' falliti');
