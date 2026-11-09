/* TEST "bordi puliti" — la riga nera verticale nella sfera 360.
   I video Bunny (2162x1080) hanno le due colonne di bordo scurite dal
   ridimensionamento: sulla sfera i due bordi si toccano e disegnano una riga
   verticale scura. Il componente A-Frame `bordi-puliti` non taglia l'immagine
   (tagliare sposterebbe gli hotspot e creerebbe uno scalino): nello shader
   blocca la coordinata orizzontale appena dentro il bordo, così le prime e le
   ultime colonne prendono il colore di quella buona.

   Questa correzione era già stata scritta per ver8 e si era persa nel passaggio
   alla repository: il test esiste perché non si perda una terza volta.
   Gira su /tmp/pag.html (prodotto da rendi-player.sh). Niente WebGL. */
const fs = require('fs');

let P = 0, F = 0;
const ok = (n, c) => { if (c) { P++; console.log('  ✓ ' + n); } else { F++; console.log('  ❌ ' + n); } };

const html = fs.readFileSync('/tmp/pag.html', 'utf8');

/* ---------- 1. il componente c'è ed è agganciato alla sfera ---------- */
ok('il componente bordi-puliti è registrato nella pagina',
   /AFRAME\.registerComponent\(\s*['"]bordi-puliti['"]/.test(html));

const tagSfera = (html.match(/<a-videosphere[^>]*>/) || [''])[0];
ok('la videosphere porta l\'attributo bordi-puliti', /\bbordi-puliti\b/.test(tagSfera));
ok('la videosphere non ha perso rotation e src', /rotation="0 -90 0"/.test(tagSfera) && /src="#vid"/.test(tagSfera));

/* ---------- 2. la logica, eseguita davvero ---------- */
const blocco = (html.match(/<script>([\s\S]*?AFRAME\.registerComponent\(\s*['"]bordi-puliti['"][\s\S]*?)<\/script>/) || [])[1];
ok('il codice del componente si estrae dalla pagina', !!blocco);

let comp = null;
const AFRAME = { registerComponent: (nome, o) => { if (nome === 'bordi-puliti') comp = o; } };
/* three finto: solo i pezzi che il componente tocca */
const THREE = { ShaderChunk: { map_fragment: 'diffuseColor *= texture2D( map, vMapUv );' } };
new Function('AFRAME', 'THREE', blocco)(AFRAME, THREE);
ok('il componente si registra all\'avvio', !!comp && typeof comp.tick === 'function');

/* una sfera finta con il video alla risoluzione che manda Bunny */
function sfera(larghezza) {
  const material = { map: { image: { videoWidth: larghezza } }, userData: {} };
  return { getObject3D: () => ({ material }), _m: material };
}

const el = sfera(2162);
const ctx = { el, data: { px: 2.5 }, u: null };
comp.init.call(ctx);
ok('init prepara l\'uniform a 0', ctx.u && ctx.u.value === 0);

comp.tick.call(ctx);
const atteso = 2.5 / 2162;
ok('tick calcola il bordo dalla larghezza vera del video (2.5 px su 2162)',
   Math.abs(ctx.u.value - atteso) < 1e-9);
ok('il materiale viene marcato e ricompilato una sola volta',
   el._m.userData.bordiPuliti === true && typeof el._m.onBeforeCompile === 'function' && el._m.needsUpdate === true);

/* ---------- 3. lo shader fa davvero il clamp ---------- */
const sh = { uniforms: {}, fragmentShader: 'void main(){\n#include <map_fragment>\n}' };
el._m.onBeforeCompile(sh);
ok('lo shader riceve l\'uniform del bordo', sh.uniforms.eduBordo === ctx.u);
ok('lo shader dichiara uniform float eduBordo', /uniform float eduBordo;/.test(sh.fragmentShader));
ok('la coordinata orizzontale è bloccata fra eduBordo e 1-eduBordo',
   /clamp\(\s*vMapUv\.x,\s*eduBordo,\s*1\.0\s*-\s*eduBordo\s*\)/.test(sh.fragmentShader));
ok('la coordinata verticale resta intatta (niente schiacciamenti)',
   /,\s*vMapUv\.y\s*\)/.test(sh.fragmentShader) && !/clamp\([^)]*vMapUv\.y/.test(sh.fragmentShader));
ok('#include <map_fragment> è stato sostituito, non duplicato',
   !/#include <map_fragment>/.test(sh.fragmentShader) && /texture2D\( map,/.test(sh.fragmentShader));
ok('la cache dei programmi è distinta', el._m.customProgramCacheKey() === 'bordi-puliti');

/* ---------- 4. si riadatta da solo quando HLS cambia risoluzione ---------- */
let compilazioni = 0;
el._m.onBeforeCompile = () => { compilazioni++; };
el._m.map.image.videoWidth = 1280;
comp.tick.call(ctx);
ok('cambiando risoluzione il bordo si ricalcola (2.5 px su 1280)',
   Math.abs(ctx.u.value - 2.5 / 1280) < 1e-9);
ok('ma lo shader non viene ricompilato a ogni fotogramma', compilazioni === 0);

/* ---------- 5. non esplode prima che il video sia pronto ---------- */
const vuota = { getObject3D: () => null };
const ctx2 = { el: vuota, data: { px: 2.5 }, u: null };
comp.init.call(ctx2);
let esplode = false;
try { comp.tick.call(ctx2); } catch (e) { esplode = true; }
ok('senza mesh non solleva errori', !esplode && ctx2.u.value === 0);

const senzaImmagine = { getObject3D: () => ({ material: { map: {}, userData: {} } }) };
const ctx3 = { el: senzaImmagine, data: { px: 2.5 }, u: null };
comp.init.call(ctx3);
try { comp.tick.call(ctx3); } catch (e) { esplode = true; }
ok('con la texture non ancora caricata non solleva errori', !esplode);

const larghezzaZero = sfera(0);
const ctx4 = { el: larghezzaZero, data: { px: 2.5 }, u: null };
comp.init.call(ctx4);
comp.tick.call(ctx4);
ok('larghezza 0: non divide per zero e non tocca il materiale',
   ctx4.u.value === 0 && larghezzaZero._m.userData.bordiPuliti === undefined);

console.log('RISULTATO: ' + P + ' passati, ' + F + ' falliti');
process.exit(F ? 1 : 0);
