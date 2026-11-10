/* PROVA IN UN BROWSER VERO — la mappa del corso (player v2.9)
   t_mappa.js controlla la logica con un Leaflet finto. Qui invece Chromium
   disegna davvero: il titolo che si ingrandisce sotto il mouse, il doppio tocco
   sulla LIM, il telefono, la modalità ipovedenti, la libreria che non si carica.
   Serve Playwright con Chromium; lo lancia t_mappa_browser.sh.
   I tasselli di OpenStreetMap vengono bloccati apposta: la prova non deve
   dipendere dalla rete (e la mappa deve restare usabile anche senza sfondo). */
const { chromium, devices } = require('playwright'); const fs=require('fs');
const corsi = JSON.parse(fs.readFileSync(require('path').join(__dirname,'fixture_mappa_trapani.json'),'utf8'));
const U = process.env.EDU_URL || 'http://127.0.0.1:8098';
let P=0,F=0; const ok=(n,c)=>{ if(c){P++;console.log('  ✓ '+n);} else {F++;console.log('  ❌ '+n);} };
async function apri(br,opt){ const cx=await br.newContext(opt); const pg=await cx.newPage();
 await pg.route('**/api.php**', r => r.fulfill({ status: 500, body: '{}' })); await pg.route('https://**', r => r.abort());
 await pg.goto(U+'/index.php',{waitUntil:'domcontentloaded'}); await pg.waitForTimeout(1200);
 await pg.evaluate((c)=>{ eval('MENU_CARICATO=true; LICENZA_KO=null; impostaCorsi(c); buildMenu(); scegliCorso(CORSI.findIndex(c=>c.id==="trapani-citta")); window.__aperta=[]; avviaLezione=function(i){ window.__aperta.push(CATALOGO[i].id); };'); },corsi);
 await pg.waitForTimeout(1500); return pg; }
(async()=>{ const br=await chromium.launch();
 console.log('== mouse =='); let pg=await apri(br,{viewport:{width:1366,height:768}});
 const pin=pg.locator('.mp-pin').nth(4), lab=pin.locator('.lab');
 const w0=(await lab.boundingBox()).width;
 await pin.locator('.dot').hover(); await pg.waitForTimeout(300);
 const w1=(await lab.boundingBox()).width;
 ok('al passaggio del mouse il titolo si ingrandisce ('+Math.round(w0)+' → '+Math.round(w1)+' px)', w1>w0*1.2);
 ok('…e compare il luogo sotto il titolo', await pin.locator('.det').isVisible());
 ok('…la riga dell\'elenco si accende', await pg.locator('.mp-riga').nth(4).evaluate(e=>e.classList.contains('on')));
 await pg.locator('.mp-riga').nth(8).hover(); await pg.waitForTimeout(200);
 ok('passando sulla riga 9 si accende il segnaposto 9', await pg.locator('.mp-pin').nth(8).evaluate(e=>e.classList.contains('on')));
 ok('…e il 5 si è spento', !(await pin.evaluate(e=>e.classList.contains('on'))));
 await pin.locator('.dot').click(); 
 ok('con il mouse un clic apre la lezione', JSON.stringify(await pg.evaluate(()=>window.__aperta))==='["trapani-leone"]');
 await pg.locator('.mp-riga').nth(5).click();
 ok('un clic sulla riga apre la lezione', (await pg.evaluate(()=>window.__aperta))[1]==='trapani-collegio');
 await pg.keyboard.press('Tab'); 
 await pg.locator('.mp-riga').nth(0).focus(); await pg.keyboard.press('Enter');
 ok('da tastiera, Invio apre', (await pg.evaluate(()=>window.__aperta))[2]==='trapani-cappuccini');
 ok('la pagina non scorre in orizzontale', await pg.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 const legenda=await pg.locator('.mp-leg').boundingBox(); ok('la legenda si vede senza scorrere (1366×768)', legenda && legenda.y+legenda.height<=768);
 await pg.close();
 console.log('== dito (LIM) =='); pg=await apri(br,{viewport:{width:1920,height:1080},hasTouch:true});
 const p3=pg.locator('.mp-pin').nth(2);
 await p3.locator('.dot').tap(); await pg.waitForTimeout(300);
 ok('il primo tocco NON apre', (await pg.evaluate(()=>window.__aperta)).length===0);
 ok('il primo tocco ingrandisce il titolo', await p3.evaluate(e=>e.classList.contains('on')));
 ok('compare la barra «Apri la lezione» con il titolo', (await pg.locator('.mp-apri.on b').textContent())==='La montagna è femmina');
 await pg.locator('.mp-pin').nth(6).locator('.dot').tap(); await pg.waitForTimeout(200);
 ok('toccando un altro punto si sposta la scelta, senza aprire', (await pg.evaluate(()=>window.__aperta)).length===0 && !(await p3.evaluate(e=>e.classList.contains('on'))) && await pg.locator('.mp-pin').nth(6).evaluate(e=>e.classList.contains('on')));
 await pg.locator('.mp-pin').nth(6).locator('.dot').tap();
 ok('il secondo tocco sullo stesso punto apre', JSON.stringify(await pg.evaluate(()=>window.__aperta))==='["trapani-senatorio"]');
 await pg.locator('.mp-riga').nth(9).tap(); await pg.waitForTimeout(200);
 ok('nell\'elenco un tocco apre subito', (await pg.evaluate(()=>window.__aperta))[1]==='trapani-santa-rita');
 await pg.locator('.mp-pin').nth(3).locator('.dot').tap(); await pg.waitForTimeout(200);
 await pg.locator('.mp-apri button').tap();
 ok('il tasto «Apri la lezione» apre il punto scelto', (await pg.evaluate(()=>window.__aperta))[2]==='trapani-falce');
 await pg.locator('.mp-pin').nth(0).locator('.dot').tap(); await pg.waitForTimeout(150);
 const bm=await pg.locator('#mpLeaf').boundingBox(); await pg.touchscreen.tap(bm.x+bm.width-80,bm.y+60); await pg.waitForTimeout(300);
 ok('un tocco sulla mappa vuota annulla la scelta', !(await pg.locator('.mp-apri').evaluate(e=>e.classList.contains('on'))));
 await pg.close();
 console.log('== telefono =='); pg=await apri(br,devices['iPhone 13']);
 ok('la pagina non scorre in orizzontale', await pg.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 ok('i titoli sulla mappa sono nascosti finché non si tocca', !(await pg.locator('.mp-pin .lab').first().isVisible()));
 await pg.locator('.mp-pin').nth(10).locator('.dot').tap(); await pg.waitForTimeout(300);
 const lb=await pg.locator('.mp-pin').nth(10).locator('.lab').boundingBox(), mb=await pg.locator('#mpLeaf').boundingBox();
 ok('al tocco compare il titolo, dentro la mappa', lb && lb.x>=mb.x-1 && lb.x+lb.width<=mb.x+mb.width+1);
 ok('le righe dell\'elenco sono alte almeno 44 px', (await pg.locator('.mp-riga').first().boundingBox()).height>=44);
 ok('dopo il tocco la mappa resta in vista (la pagina non scappa)', (await pg.locator('.mp-apri button').boundingBox()).y>0 && await pg.locator('.mp-apri.on button').isVisible());
 console.log('== modalità ipovedenti =='); await pg.evaluate(()=>eval("setAcc('ipo')")); await pg.waitForTimeout(300);
 ok('niente mappa: resta l\'elenco grande', (await pg.locator('.mp').count())===0 && (await pg.locator('#menuLez .lez').count())===11);
 await pg.evaluate(()=>eval("setAcc('std')")); await pg.waitForTimeout(800);
 ok('tornando a Standard la mappa ritorna', (await pg.locator('.mp-pin').count())===11);
 await pg.close();
 console.log('== Leaflet mancante =='); { const cx=await br.newContext({viewport:{width:1366,height:768}}); pg=await cx.newPage();
 await pg.route('**/api.php**', r => r.fulfill({ status: 500, body: '{}' })); await pg.route('https://**', r => r.abort()); await pg.route('**/lib/leaflet/**', r => r.abort());
 await pg.goto(U+'/index.php',{waitUntil:'domcontentloaded'}); await pg.waitForTimeout(1000);
 await pg.evaluate((c)=>{ eval('MENU_CARICATO=true; LICENZA_KO=null; impostaCorsi(c); buildMenu(); scegliCorso(CORSI.findIndex(c=>c.id==="trapani-citta"));'); },corsi); await pg.waitForTimeout(1200);
 ok('se la libreria non si carica si torna all\'elenco normale', (await pg.locator('.mp').count())===0 && (await pg.locator('#menuLez .lez').count())===11 && !(await pg.locator('.card.conmappa').count())); }
 console.log('\nRISULTATO: '+P+' passati, '+F+' falliti'); await br.close(); process.exit(F?1:0); })();
