/* TEST PROFONDO index.php v1.2 — DOM reale (jsdom) + api mockata */
const { JSDOM } = require('jsdom');
const fs = require('fs');

const LEZ_META = { id:'salinaio', tit:'Il mestiere del salinaio', sub:'La raccolta del sale', em:'🧂', stato:'pubblicata' };
const MENU = { ok:true, quizSempre:false, mascotte:{}, mascotteLiv:{}, mascotteCfg:{junior:false,senior:false},
  tenant:'salina-culcasi',
  cliente:{ nome:'Salina Culcasi', brand:{ titolo:'Sale in Classe', sottotitolo:'Salina Culcasi · Trapani' }, piattaforma:'Esplora Trapani Edu' },
  corsi:[ { id:'la-salina', tit:'Alla scoperta della salina', em:'🧂', cls:'rosa', stato:'pubblicato', lezioni:[LEZ_META] },
          { id:'goccia', tit:'La vita della goccia', em:'💧', cls:'oro', stato:'pubblicato', lezioni:[{ id:'g1', tit:'Il mare', stato:'pubblicata' }] } ],
  lezioni:[LEZ_META] };
const LEZIONE = { ok:true, lezione:{ id:'salinaio', tit:'Il mestiere del salinaio', intro:'Benvenuti!',
  coccio:null, corso:{ id:'la-salina', uuid:'u1', tit:'Alla scoperta della salina', prologo:'Da qualche parte, tra il mare e la terra,\nesiste un mondo fatto d\u2019acqua.' }, video:[{guid:'abc-123',lis:'lis-guid-111'},{guid:'def-456'}], tappe:[],
  quiz:[ {q:'Con cosa rompe la crosta?', opts:['Palo a T','Martello'], ok:0, v:0,
          spiegazione:'La crosta è durissima: serve il palo.', media_spiegazione:'https://esempio.it/foto.jpg'},
         {q:'Domanda 2?', opts:['Sì','No'], ok:1, v:1},
         {q:'Domanda generale?', opts:['A','B'], ok:0} ],
  quiz2:null } };

let html = fs.readFileSync('/tmp/pagina12.html','utf8');
// inietto il mock di fetch PRIMA di ogni script della pagina
const mock = `<script>
window.__eventi = [];
window.fetch = function(url, opt){
  window.__eventi.push(String(url));
  let body = null;
  if (String(url).indexOf('action=menu') >= 0) body = ${JSON.stringify(JSON.stringify(MENU))};
  else if (String(url).indexOf('action=lezione') >= 0) body = ${JSON.stringify(JSON.stringify(LEZIONE))};
  else if (String(url).indexOf('action=track') >= 0) body = '{"ok":true}';
  else body = '{"ok":true}';
  return Promise.resolve({ json: function(){ return Promise.resolve(JSON.parse(body)); } });
};
window.EduLive = { chiamate: [], apri: function(cfg){ window.EduLive.chiamate.push(cfg); } };
window.alert = function(m){ window.__eventi.push('ALERT:'+m); };
window.AFRAME = { registerComponent: function(){}, registerGeometry: function(){}, registerShader: function(){} };
window.Hls = undefined;
</script>`;
html = html.replace('<head>', '<head>' + mock);
// il modulo esterno live-lim.js non serve: EduLive è stubbata sopra
html = html.replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');

const dom = new JSDOM(html, { url:'http://localhost/index.php', runScripts:'dangerously',
  pretendToBeVisual:true, resources:undefined });
const { window } = dom; const { document } = window;
// media stub
window.HTMLMediaElement.prototype.play  = function(){ return Promise.resolve(); };
window.HTMLMediaElement.prototype.pause = function(){};
window.HTMLMediaElement.prototype.load  = function(){};

const attendi = ms => new Promise(r=>setTimeout(r,ms));
let passati = 0, falliti = 0;
function ok(nome, cond){ if(cond){ passati++; console.log('  ✓ '+nome); } else { falliti++; console.log('  ❌ '+nome); } }

(async () => {
  await attendi(400);  // bootstrap: caricaMenu + buildMenu

  console.log('— 1. Avvio pagina —');
  ok('menu lezioni visibile', document.getElementById('menu').classList.contains('on'));
  ok('BRAND dal DB applicato (titolo + sottotitolo)', document.getElementById('brandTit').textContent==='Sale in Classe' && document.getElementById('brandSub').textContent.indexOf('Culcasi')>=0 && document.title.indexOf('Sale in Classe')===0);
  ok('MENU a 2 livelli: prima le card dei CORSI (2)', document.querySelectorAll('#menuLez .lez.corso').length===2);
  ok('card corso: conteggio lezioni', document.querySelector('#menuLez .lez.corso small').textContent.indexOf('1 lezione')>=0);
  document.querySelector('#menuLez .lez.corso').click();
  await attendi(50);
  ok('scelto il corso: lezioni del corso renderizzate', document.getElementById('menuLez').textContent.includes('Il mestiere del salinaio') && document.querySelectorAll('#menuLez .lez.corso').length===0);
  ok('pulsante ← Tutti i corsi presente', document.getElementById('menuLez').textContent.indexOf('Tutti i corsi')>=0);
  ok('pulsante teachbar Quiz live presente ma NASCOSTO nel menu', document.getElementById('tbLive') && document.getElementById('tbLive').style.display==='none');

  console.log('— 2. Avvio lezione (con Intro del corso) —');
  window.avviaLezione(0);            // NON await: si ferma sul prologo
  await attendi(250);
  ok('PROLOGO: overlay visibile', document.getElementById('prologoOvl').classList.contains('on'));
  ok('PROLOGO: testo con righe preservate', document.getElementById('prologoTxt').textContent.indexOf('\n')>0);
  document.getElementById('prologoBtn').click();
  await attendi(150);
  ok('PROLOGO: chiuso dopo Inizia', !document.getElementById('prologoOvl').classList.contains('on'));
  ok('pulsante teachbar Quiz live VISIBILE durante la lezione', document.getElementById('tbLive').style.display==='');
  ok('menu chiuso', !document.getElementById('menu').classList.contains('on'));

  console.log('— 3. Quiz live dalla teachbar (a metà lezione, come chiesto) —');
  document.getElementById('tbLive').click();
  await attendi(50);
  ok('EduLive.apri chiamata', window.EduLive.chiamate.length===1);
  const cfg = window.EduLive.chiamate[0]||{};
  ok('titolo lezione passato', cfg.titolo==='Il mestiere del salinaio');
  ok('mapping domanda q→domanda', cfg.quiz && cfg.quiz[0].domanda==='Con cosa rompe la crosta?');
  ok('mapping opzioni opts→opzioni', cfg.quiz && cfg.quiz[0].opzioni.length===2);
  ok('mapping risposta ok→g', cfg.quiz && cfg.quiz[0].g===0);
  ok('spiegazione passata al live', cfg.quiz && cfg.quiz[0].spiegazione.indexOf('palo')>0);
  ok('media passata al live', cfg.quiz && cfg.quiz[0].media==='https://esempio.it/foto.jpg');
  ok('QUIZ PROGRESSIVO: a metà lezione (video 1 di 2) passa SOLO la domanda del video visto',
     cfg.quiz && cfg.quiz.length===1 && cfg.quiz[0].domanda==='Con cosa rompe la crosta?');

  console.log('— 4. Fine partita live: evento edu-live-fine —');
  window.document.dispatchEvent(new window.CustomEvent('edu-live-fine',
    { detail:{ live:true, pct_classe:83, n_gioc:21, n_quiz:2, recap:[] } }));
  await attendi(300);
  ok('overlay fine mostrato', document.getElementById('fine').classList.contains('on'));
  ok('percentuale di classe nel testo', document.getElementById('fineTxt').textContent.indexOf('83')>=0);
  ok('tracking quiz_esito inviato', window.__eventi.some(u=>u.indexOf('action=track')>=0));

  console.log('— 5. Quiz classico: pulsante interno + card Lo sapevi —');
  document.getElementById('fine').classList.remove('on');
  window.avviaQuiz();
  await attendi(50);
  ok('overlay quiz aperto', document.getElementById('quiz').classList.contains('on'));
  ok('pulsante Gioca live visibile alla prima domanda', document.getElementById('qLiveBtn').style.display==='');
  document.getElementById('qLiveBtn').click();
  await attendi(50);
  const cfgFin = window.EduLive.chiamate[window.EduLive.chiamate.length-1]||{};
  ok('dal quiz FINALE il live riceve TUTTE le domande (3, incluse generali)',
     cfgFin.quiz && cfgFin.quiz.length===3);
  ok('card sapevi nascosta prima della risposta', document.getElementById('qSapevi').style.display==='none');
  // rispondo GIUSTO alla domanda 1 (che ha la spiegazione)
  const opts = document.getElementById('qOpts').querySelectorAll('button');
  opts[0].click();
  await attendi(1500);  // attesa 1200ms del flusso senza mascotte
  ok('card "Lo sapevi?" VISIBILE dopo risposta giusta', document.getElementById('qSapevi').style.display==='block');
  ok('testo spiegazione presente', document.getElementById('qSapeviTxt').textContent.indexOf('palo')>0);
  ok('immagine spiegazione presente', document.getElementById('qSapeviImg').style.display==='block');
  ok('flusso FERMO sulla card (non è avanzato da solo)', document.getElementById('qTesto').textContent.indexOf('crosta')>0);
  // Avanti → domanda 2
  window.sapeviAvanti();
  await attendi(50);
  ok('avanzato alla domanda 2', document.getElementById('qTesto').textContent==='Domanda 2?');
  ok('pulsante Gioca live nascosto dalla 2ª domanda', document.getElementById('qLiveBtn').style.display==='none');
  ok('card sapevi resettata', document.getElementById('qSapevi').style.display==='none');
  // rispondo GIUSTO alla 2 e alla 3 → deve chiudere la lezione
  document.getElementById('qOpts').querySelectorAll('button')[1].click();
  await attendi(1600);
  document.getElementById('qOpts').querySelectorAll('button')[0].click();
  await attendi(1600);
  ok('lezione completata (overlay fine)', document.getElementById('fine').classList.contains('on'));
  ok('conteggio nel testo di fine', document.getElementById('fineTxt').textContent.indexOf('3 risposte giuste su 3')>0);

  console.log('— 6. Ritorno al menu —');
  window.vaiMenu();
  ok('pulsante teachbar nascosto nel menu', document.getElementById('tbLive').style.display==='none');

  console.log('— 7. Interprete LIS (fix normalizzaLezione) —');
  document.getElementById('fine').classList.remove('on');
  window.avviaLezione(0);
  await attendi(250);
  ok('PROLOGO del corso: NON ricompare nella stessa sessione', !document.getElementById('prologoOvl').classList.contains('on'));
  function inj(code){ const s=document.createElement('script'); s.textContent=code; document.body.appendChild(s); }
  inj("ACC='lis'; document.body.classList.add('lis'); started=true; vidIdx=0; lisSync(true); window.__lisbox=document.getElementById('lisBox').className; window.__lissrc=document.getElementById('lisVid').src||'';");
  await attendi(50);
  ok('clip 1: finestra LIS attiva', window.__lisbox.indexOf('on')>=0);
  ok('clip 1: NESSUN \"non disponibile\" (campo lis conservato)', window.__lisbox.indexOf('miss')<0);
  ok('clip 1: sorgente dal GUID LIS', window.__lissrc.indexOf('lis-guid-111')>=0);
  inj("vidIdx=1; lisSync(true); window.__lisbox2=document.getElementById('lisBox').className;");
  await attendi(50);
  ok('clip 2 senza LIS: messaggio non disponibile', window.__lisbox2.indexOf('miss')>=0);

  inj("LEZ.prologo=''; window.__pr=null; mostraPrologo().then(()=>{window.__pr='subito'});");
  await attendi(100);
  ok('PROLOGO vuoto: si salta senza mostrare nulla', window.__pr==='subito' && !document.getElementById('prologoOvl').classList.contains('on'));

  console.log('— 8. Licenza scaduta (secondo DOM) —');
  let html2 = fs.readFileSync('/tmp/pagina12.html','utf8');
  const mock2 = mock.replace(JSON.stringify(JSON.stringify(MENU)), JSON.stringify(JSON.stringify({ ok:false, err:'licenza', cliente:{ nome:'Scuola X', licenza_stato:'scaduta', contatto_email:'info@scuolax.it', brand:{ titolo:'Scuola X Edu' } } })));
  html2 = html2.replace('<head>', '<head>' + mock2).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const dom2 = new JSDOM(html2, { url:'http://localhost/index.php', runScripts:'dangerously', pretendToBeVisual:true });
  dom2.window.HTMLMediaElement.prototype.play=function(){return Promise.resolve();}; dom2.window.HTMLMediaElement.prototype.pause=function(){};
  await attendi(400);
  const m2 = dom2.window.document.getElementById('menuLez').textContent;
  ok('LICENZA scaduta: messaggio gentile col nome cliente', m2.indexOf('scaduta')>=0 && m2.indexOf('Scuola X')>=0);
  ok('LICENZA scaduta: contatto mostrato', m2.indexOf('info@scuolax.it')>=0);
  ok('LICENZA scaduta: brand comunque applicato', dom2.window.document.getElementById('brandTit').textContent==='Scuola X Edu');
  ok('LICENZA scaduta: nessuna lezione cliccabile', dom2.window.document.querySelectorAll('#menuLez .lez').length===0);

  console.log('— 9. Piano Base: Quiz Live non incluso (terzo DOM) —');
  let html3 = fs.readFileSync('/tmp/pagina12.html','utf8');
  const MENU3 = JSON.parse(JSON.stringify(MENU)); MENU3.cliente.limiti = { quiz_live:false, nome:'Base' }; MENU3.corsi = [MENU3.corsi[0]];
  const mock3 = mock.replace(JSON.stringify(JSON.stringify(MENU)), JSON.stringify(JSON.stringify(MENU3)));
  html3 = html3.replace('<head>', '<head>' + mock3).replace(/<script src="live-lim\.js[^"]*"><\/script>/,'');
  const dom3 = new JSDOM(html3, { url:'http://localhost/index.php', runScripts:'dangerously', pretendToBeVisual:true });
  dom3.window.HTMLMediaElement.prototype.play=function(){return Promise.resolve();}; dom3.window.HTMLMediaElement.prototype.pause=function(){}; dom3.window.HTMLMediaElement.prototype.load=function(){};
  await attendi(400);
  dom3.window.avviaLezione(0); await attendi(250); dom3.window.document.getElementById('prologoBtn').click(); await attendi(150);
  ok('piano Base: pulsante Quiz Live in teachbar NASCOSTO', dom3.window.document.getElementById('tbLive').style.display==='none');
  dom3.window.avviaQuiz(); await attendi(50);
  ok('piano Base: pulsante Gioca live nel quiz NASCOSTO', dom3.window.document.getElementById('qLiveBtn').style.display==='none');
  ok('piano Pro (DOM principale): Quiz Live disponibile', window.EduLive.chiamate.length>=2);

  console.log('\nRISULTATO: ' + passati + ' passati, ' + falliti + ' falliti');
  process.exit(falliti ? 1 : 0);
})().catch(e => { console.error('ERRORE TEST:', e); process.exit(1); });
