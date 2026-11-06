/* TEST REGIA v18 (migr. 32) — didattica del corso e della lezione,
   esiti con filtri/CSV/stampa, compiti a casa.  jsdom + Supabase mock. */
const { JSDOM } = require('jsdom');
const fs = require('fs');

const CL_SAL={id:'cl-sal',slug:'salina-culcasi',nome:'Salina Culcasi',piano:'premium',licenza_stato:'attiva',licenza_fine:null,brand:{}};
const CL_ICP={id:'cl-icp',slug:'ic-pagoto',nome:'IC Pagoto',piano:'pro',licenza_stato:'attiva',licenza_fine:null,brand:{}};
const CORSI=[
  {id:'co-mes',proprietario_id:'cl-sal',slug:'mestieri',titolo:'Antichi Mestieri',emoji:'🛠️',stato:'pubblicato',fascia:'entrambe',ordine:10,visibilita:'privato',
   didattica:{discipline:['storia','geografia'],competenze_chiave:['consapevolezza culturale'],
              traguardi:{primaria:['riconosce le tracce del passato'],medie:['usa fonti materiali']},
              uda:{monte_ore:14,prodotto_finale:'cartellone dei mestieri',verifica:'prove di ingresso e uscita'}}},
  {id:'co-sal',proprietario_id:'cl-sal',slug:'la-salina',titolo:'Alla scoperta della salina',emoji:'🧂',stato:'bozza',fascia:'entrambe',ordine:20,visibilita:'privato'}
];
const LEZIONI=[
  {id:'lz-1',corso_id:'co-mes',slug:'salinaio',titolo:'Il salinaio',stato:'pubblicata',ordine:10,progetto:'antichi-mestieri-trapani',owner:null,
   accessibilita:{},didattica:{obiettivi:{primaria:['descrive il lavoro del salinaio'],medie:['spiega il ciclo del sale']},
     parole_chiave:['salina','pala'],prima:'Da dove arriva il sale?',durante:'Fermare alla pala.',dopo:'Disegnare la vasca.',
     materiali:['quaderno'],collegamenti:'Storia cap. 3'}},
  {id:'lz-2',corso_id:'co-mes',slug:'corallaio',titolo:'Il corallaio',stato:'pubblicata',ordine:20,progetto:'antichi-mestieri-trapani',owner:null,accessibilita:{},didattica:{}}
];
const QUIZ=[
  {id:'q1',lezione_id:'lz-1',livello:'junior',domanda:'Come si chiama la vasca?',opzioni:['Vasca salante','Vasca fredda'],ok:0,ordine:10},
  {id:'q2',lezione_id:'lz-1',livello:'junior',domanda:'Che attrezzo usa?',opzioni:['Rastrello','Pala'],ok:1,ordine:20},
  {id:'q3',lezione_id:'lz-1',livello:'senior',domanda:'Domanda per le medie',opzioni:['a','b'],ok:0,ordine:30}
];
const ESITI=[
  {id:1,cliente_id:'cl-sal',scuola_id:'sc-1',codice_classe:'ICPA-5A',corso_id:'co-mes',corso_titolo:'Antichi Mestieri',lezione_slug:'salinaio',lezione_titolo:'Il salinaio',livello:'junior',modalita:'ingresso',n_partecipanti:21,n_domande:10,n_giuste:4,pct:40,dettaglio:{},note:null,svolto_il:'2027-01-12T09:00:00Z'},
  {id:2,cliente_id:'cl-sal',scuola_id:'sc-1',codice_classe:'ICPA-5A',corso_id:'co-mes',corso_titolo:'Antichi Mestieri',lezione_slug:'salinaio',lezione_titolo:'Il salinaio',livello:'junior',modalita:'aula',n_partecipanti:null,n_domande:5,n_giuste:4,pct:80,dettaglio:{},note:null,svolto_il:'2027-01-13T10:00:00Z'},
  {id:3,cliente_id:'cl-sal',scuola_id:'sc-1',codice_classe:'ICPA-5A',corso_id:'co-mes',corso_titolo:'Antichi Mestieri',lezione_slug:'corallaio',lezione_titolo:'Il corallaio',livello:'junior',modalita:'live',n_partecipanti:22,n_domande:4,n_giuste:3,pct:75,dettaglio:{},note:null,svolto_il:'2027-01-20T10:00:00Z'},
  {id:4,cliente_id:'cl-sal',scuola_id:'sc-1',codice_classe:'ICPA-5A',corso_id:'co-mes',corso_titolo:'Antichi Mestieri',lezione_slug:'salinaio',lezione_titolo:'Il salinaio',livello:'junior',modalita:'uscita',n_partecipanti:21,n_domande:10,n_giuste:9,pct:90,dettaglio:{},note:'ottimo',svolto_il:'2027-02-10T09:00:00Z'},
  {id:5,cliente_id:'cl-sal',scuola_id:'sc-1',codice_classe:'ICPA-4B',corso_id:'co-mes',corso_titolo:'Antichi Mestieri',lezione_slug:'salinaio',lezione_titolo:'Il salinaio',livello:'junior',modalita:'compito',n_partecipanti:1,n_domande:2,n_giuste:2,pct:100,dettaglio:{compito:'SAL2026X'},note:null,svolto_il:'2027-01-15T18:00:00Z'}
];
const COMPITI=[{id:'cp-1',cliente_id:'cl-sal',corso_id:'co-mes',lezione_slug:'salinaio',codice:'SAL2026X',titolo:'Rivedi la vasca',
  consegna:'Guarda e rispondi',livello:'junior',clip:{guid:'g-sal',da:10,a:70},
  domande:[{domanda:'La vasca?',opzioni:['salante','fredda'],ok:0}],attivo:true,scadenza:null,creato_il:'2027-01-14T10:00:00Z'}];
const UTENTI=[{id:'u-ale',nome:'Alessandro',ruolo:'admin',cliente_id:null}];

function costruisci(){
  let html=fs.readFileSync(__dirname+'/../app/regia-edu.html','utf8');
  const fx={edu_clienti:[CL_SAL,CL_ICP],edu_corsi:CORSI,edu_lezioni:LEZIONI,edu_quiz:QUIZ,edu_esiti:ESITI,edu_compiti:COMPITI,
            edu_scuole:[{id:'sc-1',cliente_id:'cl-sal',nome:'IC Pagoto',citta:'Erice',tipo:'ospite',licenza_stato:'attiva',licenza_a:null}],
            edu_classi:[{id:'k1',cliente_id:'cl-sal',scuola_id:'sc-1',codice:'ICPA-5A',nome:'5ª A',anno:'2026/27'}],
            edu_catalogo:[],edu_utenti:UTENTI,edu_progetti:[],edu_richieste:[],edu_media:[],edu_tappe:[],edu_hotspot:[]};
  const mock=`<script>
  window.__scritture=[];window.__rpc=[];window.__query=[];window.__fx=${JSON.stringify(fx)};window.__utente=${JSON.stringify(UTENTI[0])};
  window.__scaricati=[];window.__finestre=[];
  function q(tab){
    const st={tab,op:'select',filtri:[],payload:null,single:false,limiti:[]};
    const o={};const self=()=>o;
    o.select=()=>self();o.order=()=>self();o.limit=()=>self();
    o.eq=(k,v)=>{st.filtri.push([k,v]);return o;};
    o.gte=(k,v)=>{st.limiti.push(['gte',k,v]);return o;};
    o.lte=(k,v)=>{st.limiti.push(['lte',k,v]);return o;};
    o.in=(k,v)=>{st.filtri.push([k,v]);return o;};
    o.insert=(p)=>{st.op='insert';st.payload=p;return o;};
    o.update=(p)=>{st.op='update';st.payload=p;return o;};
    o.delete=()=>{st.op='delete';return o;};
    o.single=()=>{st.single=true;return o;};o.maybeSingle=()=>{st.single=true;return o;};
    o.then=(res)=>{
      if(st.op!=='select'){ window.__scritture.push({tab:st.tab,op:st.op,payload:st.payload,filtri:st.filtri});
        const riga=Object.assign({id:'nuovo-'+st.tab},st.payload||{});
        if(st.op==='insert')(window.__fx[st.tab]=window.__fx[st.tab]||[]).push(riga);
        return res({data:riga,error:null}); }
      window.__query.push({tab:st.tab,filtri:st.filtri,limiti:st.limiti});
      let rows=window.__fx[st.tab]||[];
      st.filtri.forEach(([k,v])=>{rows=Array.isArray(v)?rows.filter(r=>v.indexOf(r[k])>=0):rows.filter(r=>r[k]===v);});
      st.limiti.forEach(([op,k,v])=>{rows=rows.filter(r=>op==='gte'?String(r[k])>=String(v):String(r[k])<=String(v));});
      return res({data:st.single?(rows[0]||null):rows,error:null});
    };
    return o;
  }
  window.supabase={createClient:()=>({
    auth:{getSession:async()=>({data:{session:{user:{id:window.__utente.id,email:'ale@x.it'}}}}),onAuthStateChange:()=>{}},
    from:q,
    rpc:async(fn,args)=>{ window.__rpc.push({fn,args});
      if(fn==='edu_piano_limiti')return {data:{corsi_pubblicati:999,quiz_live:true,classi:999,nome:'Premium'},error:null};
      if(fn==='edu_elenco_clienti')return {data:window.__fx.edu_clienti.map(c=>({id:c.id,slug:c.slug,nome:c.nome})),error:null};
      return {data:null,error:null}; }})};
  window.Hls={isSupported:()=>false};window.alert=(m)=>{window.__alert=m};window.confirm=()=>true;
  window.HTMLAnchorElement.prototype.click=function(){window.__click=(this.download||'')+'|'+(this.href||'');};
  window.prompt=(m,dd)=>window.__prompt!==undefined?window.__prompt:dd;
  const Blob0=window.Blob;
  window.Blob=function(parti,opt){ window.__blobTesti=window.__blobTesti||[]; window.__blobTesti.push((parti||[]).join('')); return new Blob0(parti,opt); };
  window.URL.createObjectURL=(b)=>{window.__scaricati.push(b);return 'blob:finto';};
  window.URL.revokeObjectURL=()=>{};
  window.open=(u)=>{const f={url:u,html:'',document:{write(h){f.html+=h;},close(){},},focus(){},print(){f.stampato=true;}};
    f.document.write=(h)=>{f.html+=h;};window.__finestre.push(f);return f;};
  </script>`;
  html=html.replace('<head>','<head>'+mock).replace(/<script src="https:[^"]*"><\/script>/g,'');
  const dom=new JSDOM(html,{url:'http://localhost/regia-edu.html',runScripts:'dangerously',pretendToBeVisual:true});
  dom.window.HTMLMediaElement.prototype.play=()=>Promise.resolve();
  dom.window.HTMLMediaElement.prototype.pause=()=>{};
  return dom;
}
const at=ms=>new Promise(r=>setTimeout(r,ms));
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};

(async()=>{
  const dom=costruisci(); const w=dom.window, d=w.document;
  const inj=(c)=>{const s=d.createElement('script');s.textContent=c;d.body.appendChild(s);};
  await at(500);

  console.log('— A. didattica del corso —');
  await w.apriCorsi(); await at(80);
  await w.apriCorso('co-mes'); await at(80);
  ok('i campi didattici del corso si riempiono da quello che c è salvato',
     d.getElementById('coDisc').value==='storia, geografia' && d.getElementById('coOre').value==='14'
     && d.getElementById('coTragJ').value==='riconosce le tracce del passato'
     && d.getElementById('coProd').value==='cartellone dei mestieri');
  ok('traguardi delle medie separati da quelli della primaria', d.getElementById('coTragS').value==='usa fonti materiali');
  d.getElementById('coTragJ').value='riconosce le tracce del passato\nlegge una carta del territorio';
  d.getElementById('coDisc').value='storia, geografia, tecnologia';
  d.getElementById('coOre').value='16';
  d.getElementById('coVer').value='prove di ingresso e uscita, esiti dei quiz';
  await w.salvaCorso(); await at(60);
  const sc=w.__scritture.filter(s=>s.tab==='edu_corsi'&&s.op==='update').pop();
  ok('salvataggio: una voce per riga diventa un elenco', sc && sc.payload.didattica.traguardi.primaria.length===2);
  ok('salvataggio: discipline e monte ore nell UDA', sc && sc.payload.didattica.discipline.length===3 && sc.payload.didattica.uda.monte_ore===16);
  ok('salvataggio: verifica dentro l UDA', sc && sc.payload.didattica.uda.verifica.includes('prove di ingresso'));
  ok('la mascotte del corso non si perde salvando la didattica', sc && sc.payload.mascotte!==undefined);
  d.getElementById('coTragJ').value=''; d.getElementById('coTragS').value=''; d.getElementById('coDisc').value='';
  d.getElementById('coOre').value=''; d.getElementById('coProd').value=''; d.getElementById('coVer').value=''; d.getElementById('coComp').value='';
  await w.salvaCorso(); await at(60);
  const sc2=w.__scritture.filter(s=>s.tab==='edu_corsi'&&s.op==='update').pop();
  ok('tutto vuoto → didattica vuota, non campi finti', sc2 && JSON.stringify(sc2.payload.didattica)==='{}');

  console.log('— B. scheda didattica della lezione —');
  await w.apriLezione('lz-1'); await at(120);
  ok('la scheda della lezione si riempie dal salvato',
     d.getElementById('fObJ').value==='descrive il lavoro del salinaio' && d.getElementById('fPrima').value==='Da dove arriva il sale?'
     && d.getElementById('fParole').value==='salina, pala' && d.getElementById('fColleg').value==='Storia cap. 3');
  d.getElementById('fDopo').value='Disegnare la vasca e nominarne le parti.';
  d.getElementById('fMateriali').value='quaderno, sale grosso';
  await w.salvaMeta(); await at(60);
  const sl=w.__scritture.filter(s=>s.tab==='edu_lezioni'&&s.op==='update').pop();
  ok('salvataggio: prima/durante/dopo e materiali', sl && sl.payload.didattica.dopo.includes('nominarne le parti') && sl.payload.didattica.materiali.length===2);
  ok('salvataggio: obiettivi distinti per livello', sl && sl.payload.didattica.obiettivi.primaria.length===1 && sl.payload.didattica.obiettivi.medie.length===1);
  ok('l accessibilità della lezione resta intatta', sl && sl.payload.accessibilita!==undefined);
  await w.apriLezione('lz-2'); await at(120);
  ok('lezione senza didattica: campi vuoti, nessun residuo della precedente',
     d.getElementById('fObJ').value==='' && d.getElementById('fPrima').value==='' && d.getElementById('fMateriali').value==='');

  console.log('— C. pannello esiti —');
  w.apriEsiti(); await at(200);
  ok('il pannello si apre e gli altri si chiudono',
     !d.getElementById('esitiPanel').classList.contains('hidden') && d.getElementById('corsiPanel').classList.contains('hidden'));
  ok('gli esiti sono chiesti per cliente', w.__query.some(q=>q.tab==='edu_esiti'&&q.filtri.some(ff=>ff[0]==='cliente_id'&&ff[1]==='cl-sal')));
  let righe=d.querySelectorAll('#esitiList tbody tr');
  ok('cinque esiti in tabella', righe.length===5);
  const txt=d.getElementById('esitiList').textContent;
  ok('le modalità sono scritte in italiano, non in codice',
     txt.includes('prova d')&&txt.includes('quiz live')&&txt.includes('compito a casa')&&!txt.includes('ingresso,'));
  ok('ogni riga porta classe, lezione e punteggio', txt.includes('ICPA-5A') && txt.includes('Il salinaio') && txt.includes('9 / 10'));
  ok('riepilogo: conta gli esiti e le classi coinvolte',
     d.getElementById('esRiepilogo').textContent.includes('5') && d.getElementById('esRiepilogo').textContent.includes('2'));
  ok('riepilogo: confronto ingresso → uscita con il guadagno',
     d.getElementById('esRiepilogo').textContent.includes('40%') && d.getElementById('esRiepilogo').textContent.includes('90%')
     && d.getElementById('esRiepilogo').textContent.includes('+50'));
  ok('il menu delle classi è costruito dagli esiti trovati', d.getElementById('esClasse').options.length===3);

  console.log('— D. filtri —');
  d.getElementById('esClasse').value='ICPA-4B'; w.renderEsiti(); await at(40);
  righe=d.querySelectorAll('#esitiList tbody tr');
  ok('filtro per classe: solo le righe di quella classe', righe.length===1 && d.getElementById('esitiList').textContent.includes('ICPA-4B'));
  d.getElementById('esClasse').value=''; d.getElementById('esMod').value='live'; w.renderEsiti(); await at(40);
  ok('filtro per modalità: solo il quiz live', d.querySelectorAll('#esitiList tbody tr').length===1);
  d.getElementById('esMod').value='ingresso'; w.renderEsiti(); await at(40);
  ok('con una sola modalità il confronto ingresso/uscita non viene inventato',
     !d.getElementById('esRiepilogo').textContent.includes('→'));
  d.getElementById('esMod').value=''; w.renderEsiti(); await at(40);
  d.getElementById('esDa').value='2027-02-01'; await w.caricaEsiti(); await at(80);
  ok('filtro per data applicato alla query, non in pagina',
     w.__query.filter(q=>q.tab==='edu_esiti').pop().limiti.some(l=>l[0]==='gte'&&String(l[2]).startsWith('2027-02-01')));
  ok('nel periodo scelto resta solo l esito di febbraio', d.querySelectorAll('#esitiList tbody tr').length===1);
  d.getElementById('esDa').value=''; await w.caricaEsiti(); await at(80);

  console.log('— E. esportazione CSV —');
  w.esportaEsitiCsv(); await at(60);
  ok('un file è stato prodotto', w.__scaricati.length===1);
  const csv=w.__blobTesti[0];
  ok('il CSV usa il punto e virgola (Excel italiano lo apre senza procedure)', csv.split('\r\n')[0].indexOf(';')>0);
  ok('ha intestazione e una riga per esito', csv.trim().split('\r\n').length===6);
  ok('contiene classe, modalità in italiano e percentuale', csv.includes('ICPA-5A') && csv.includes('quiz live') && csv.includes('"90"'));
  ok('i campi sono tra virgolette (le note con punto e virgola non spostano le colonne)', csv.includes('"ottimo"'));
  ok('comincia col segno di ordine dei byte, così le lettere accentate si leggono', csv.charCodeAt(0)===0xFEFF);

  console.log('— F. scheda stampabile —');
  w.stampaEsiti(); await at(400);
  const fin=w.__finestre[w.__finestre.length-1];
  ok('si apre una finestra di stampa', !!fin);
  ok('la scheda intesta cliente, classe e periodo', fin.html.includes('Salina Culcasi') && fin.html.includes('tutte le classi'));
  ok('contiene la tabella degli esiti', fin.html.includes('Il salinaio') && fin.html.includes('9/10'));
  ok('dichiara che non ci sono dati personali degli alunni', fin.html.includes('non registra dati personali'));
  ok('ha lo spazio per le firme di docente e dirigente', fin.html.includes('Il docente') && fin.html.includes('Il dirigente'));
  ok('la stampa viene lanciata da sola', fin.stampato===true);

  console.log('— G. compiti a casa —');
  ok('il compito esistente è elencato col suo codice', d.getElementById('compitiList').textContent.includes('SAL2026X'));
  ok('…e con il numero di consegne arrivate', d.getElementById('compitiList').textContent.includes('consegne: 1'));
  await w.apriCompito('cp-1'); await at(60);
  ok('il form si riempie: titolo, clip e secondi',
     d.getElementById('cpTitolo').value==='Rivedi la vasca' && d.getElementById('cpGuid').value==='g-sal'
     && d.getElementById('cpDa').value==='10' && d.getElementById('cpA').value==='70');
  ok('mostra il link da dare alla classe', d.getElementById('cpLink').textContent.includes('compito.php?k=SAL2026X'));
  d.getElementById('cpCorso').value='co-mes'; w.cpCaricaLezioni(); await at(30);
  ok('le lezioni del corso sono selezionabili', d.getElementById('cpLezione').options.length===2);
  w.nuovoCompito(); await at(40);
  ok('nuovo compito: codice generato di 8 caratteri leggibili', /^[A-Z0-9]{8}$/.test(d.getElementById('cpTit').textContent.split('·').pop().trim()));
  ok('il titolo è precompilato con la lezione', d.getElementById('cpTitolo').value.includes('Il salinaio'));
  await w.cpCopiaQuiz(); await at(80);
  inj("window.__cpdom=JSON.stringify(CP_DOM);window.__cplez=JSON.stringify(CP_LEZ.map(x=>x.slug));window.__cpsel=JSON.stringify(COMPITO_SEL&&{l:COMPITO_SEL.lezione_slug,liv:COMPITO_SEL.livello})");
  if(process.env.DBG)console.log('    DBG dom=',w.__cpdom,'lez=',w.__cplez,'sel=',w.__cpsel,'alert=',w.__alert);
  ok('copia dal quiz solo le domande del livello scelto (entrambe → primaria)',
     d.getElementById('cpDomande').innerHTML.includes('Come si chiama la vasca')
     && !d.getElementById('cpDomande').innerHTML.includes('Domanda per le medie'));
  ok('le opzioni arrivano una per riga e la risposta giusta è indicata come numero di riga',
     d.getElementById('cpDomande').textContent.includes('Rastrello')
     && [...d.querySelectorAll('#cpDomande input[type=number]')].map(i=>i.value).join(',')==='1,2');
  await w.salvaCompito(); await at(80);
  const ins=w.__scritture.filter(s=>s.tab==='edu_compiti'&&s.op==='insert').pop();
  ok('il compito è salvato con cliente, lezione e domande', ins && ins.payload.cliente_id==='cl-sal' && ins.payload.lezione_slug==='salinaio' && ins.payload.domande.length===2);
  ok('la risposta giusta è salvata come indice', ins && ins.payload.domande[0].ok===0 && ins.payload.domande[1].ok===1);
  ok('la clip è salvata con i secondi di inizio e fine', ins && ins.payload.clip!==undefined && ins.payload.clip.da===0);

  console.log('— H. controlli prima di salvare un compito —');
  w.nuovoCompito(); await at(40);
  d.getElementById('cpTitolo').value='';
  const prima=w.__scritture.filter(s=>s.tab==='edu_compiti').length;
  await w.salvaCompito(); await at(40);
  ok('senza titolo non salva', w.__scritture.filter(s=>s.tab==='edu_compiti').length===prima);
  d.getElementById('cpTitolo').value='Prova';
  inj("CP_DOM=[{domanda:'Solo una opzione?',opzioni:['a'],ok:0}]");
  await w.salvaCompito(); await at(40);
  ok('una domanda con meno di due opzioni non passa', w.__scritture.filter(s=>s.tab==='edu_compiti').length===prima);
  inj("CP_DOM=[{domanda:'Giusta inesistente?',opzioni:['a','b'],ok:7}]");
  await w.salvaCompito(); await at(40);
  ok('risposta giusta fuori dalle opzioni: non passa', w.__scritture.filter(s=>s.tab==='edu_compiti').length===prima);
  inj("CP_DOM=[{domanda:'Va bene?',opzioni:['a','b'],ok:1}]");
  d.getElementById('cpDa').value='40'; d.getElementById('cpA').value='20';
  await w.salvaCompito(); await at(40);
  ok('secondo finale prima di quello iniziale: non passa', w.__scritture.filter(s=>s.tab==='edu_compiti').length===prima);
  d.getElementById('cpDa').value='10'; d.getElementById('cpA').value='70';
  await w.salvaCompito(); await at(60);
  ok('con i dati corretti salva', w.__scritture.filter(s=>s.tab==='edu_compiti').length===prima+1);

  console.log('— I. testo malevolo nei dati —');
  w.__fx.edu_esiti.push({id:9,cliente_id:'cl-sal',scuola_id:null,codice_classe:'X<img src=x onerror=window.__xss=1>',
    corso_id:null,corso_titolo:'<script>window.__xss2=1<\/script>',lezione_slug:'x',lezione_titolo:'y',livello:null,
    modalita:'aula',n_partecipanti:null,n_domande:1,n_giuste:1,pct:100,dettaglio:{},note:'"punto;virgola"',svolto_il:'2027-03-01T10:00:00Z'});
  await w.caricaEsiti(); await at(120);
  ok('la tabella degli esiti non esegue HTML dei dati',
     w.__xss===undefined && w.__xss2===undefined && d.getElementById('esitiList').querySelectorAll('img,script').length===0);
  ok('…e il testo si vede come scritto', d.getElementById('esitiList').textContent.includes('<img src=x'));
  w.esportaEsitiCsv(); await at(60);
  const csv2=w.__blobTesti[w.__blobTesti.length-1];
  ok('nel CSV le virgolette dentro una nota sono raddoppiate', csv2.includes('""punto;virgola""'));

  console.log('\nRISULTATO: '+p+' passati, '+f+' falliti');
  process.exit(f?1:0);
})().catch(e=>{console.error('ERRORE',e&&e.message,e&&e.stack);process.exit(1);});
