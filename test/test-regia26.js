/* TEST REGIA v16 (migr. 26) — jsdom + Supabase mock */
const { JSDOM } = require('jsdom');
const window_fx_clienti=w=>w.__fx.edu_clienti.length;
const fs = require('fs');

const CL_SAL = { id:'cl-sal', slug:'salina-culcasi', nome:'Salina Culcasi', piano:'premium', licenza_stato:'attiva', licenza_fine:null, brand:{} };
const CL_ICP = { id:'cl-icp', slug:'ic-pagoto', nome:'IC Pagoto', piano:'pro', licenza_stato:'attiva', licenza_fine:null, brand:{} };
const CORSI = [
  { id:'co-sal', proprietario_id:'cl-sal', slug:'la-salina', titolo:'Alla scoperta della salina', emoji:'🧂', stato:'pubblicato', fascia:'entrambe', ordine:10, visibilita:'privato' },
  { id:'co-goc', proprietario_id:'cl-sal', slug:'la-vita-della-goccia', titolo:'Il viaggio di una goccia', emoji:'💧', stato:'pubblicato', fascia:'entrambe', ordine:20, visibilita:'catalogo', prologo:'Da qualche parte…', mascotte:{nome:'Coccio di sale',img:'https://x.it/c.png'} },
];
const SCUOLE = [
  { id:'sc-1', cliente_id:'cl-sal', nome:'IC Pagoto', citta:'Erice', tipo:'ospite', licenza_stato:'attiva', licenza_a:null },
  { id:'sc-2', cliente_id:'cl-sal', nome:'IC Scaduto', citta:'Marsala', tipo:'pagante', licenza_stato:'attiva', licenza_a:'2026-06-30' },
];
const CLASSI = [{ id:'k1', cliente_id:'cl-sal', scuola_id:'sc-1', codice:'ICPA-5A-X1', nome:'5ª A', anno:'2026/27' }];
const CATALOGO = [
  { id:'cat-1', corso_id:'co-goc', cliente_id:'cl-sal', stato:'attivo', da:'2026-09-01', a:null, note:'Corso proprio' },
  { id:'cat-2', corso_id:'co-goc', cliente_id:'cl-icp', stato:'attivo', da:'2026-09-01', a:'2027-06-30', note:'Licenza pilota' },
];
const UTENTI = [{ id:'u-ale', email:'ale@x.it', nome:'Alessandro', ruolo:'admin', cliente_id:null }];

function costruisci(utente) {
  let html = fs.readFileSync(__dirname+'/../app/regia-edu.html', 'utf8');
  const fx = { edu_clienti:[CL_SAL,CL_ICP], edu_corsi:CORSI, edu_scuole:SCUOLE, edu_classi:CLASSI,
               edu_catalogo:CATALOGO, edu_utenti:UTENTI, edu_lezioni:[], edu_progetti:[], edu_richieste:[], edu_media:[] };
  const mock = `<script>
  window.__scritture=[]; window.__rpc=[]; window.__fx=${JSON.stringify(fx)}; window.__utente=${JSON.stringify(utente)};
  function q(tab){
    const st={tab,op:'select',filtri:[],payload:null,single:false};
    const o={}; const self=()=>o;
    o.select=()=>self(); o.order=()=>self(); o.limit=()=>self();
    o.eq=(k,v)=>{st.filtri.push([k,v]);return o;};
    o.insert=(p)=>{st.op='insert';st.payload=p;return o;};
    o.update=(p)=>{st.op='update';st.payload=p;return o;};
    o.delete=()=>{st.op='delete';return o;};
    o.single=()=>{st.single=true;return o;}; o.maybeSingle=()=>{st.single=true;return o;};
    o.then=(res)=>{
      if(st.op!=='select'){ window.__scritture.push({tab:st.tab,op:st.op,payload:st.payload,filtri:st.filtri});
        const riga=Object.assign({id:'nuovo-'+st.tab},st.payload||{});
        if(st.op==='insert')(window.__fx[st.tab]=window.__fx[st.tab]||[]).push(riga);
        return res({data:riga,error:null}); }
      let rows=window.__fx[st.tab]||[];
      st.filtri.forEach(([k,v])=>{rows=rows.filter(r=>r[k]===v);});
      return res({data:st.single?(rows[0]||null):rows,error:null});
    };
    return o;
  }
  window.supabase={createClient:()=>({
    auth:{getSession:async()=>({data:{session:{user:{id:window.__utente.id,email:window.__utente.email}}}}),onAuthStateChange:()=>{}},
    from:q,
    rpc:async(fn,args)=>{ window.__rpc.push({fn,args});
      if(fn==='edu_piano_limiti')return {data:{corsi_pubblicati:999,quiz_live:true,classi:999,nome:'Pro'},error:null};
      if(fn==='edu_duplica_corso')return {data:'co-nuovo',error:null};
      if(fn==='edu_elenco_clienti')return {data:window.__fx.edu_clienti.map(c=>({id:c.id,slug:c.slug,nome:c.nome})),error:null};
      if(fn==='edu_stats_cliente')return {data:{totali:{scuole:2,classi:3,avviate:5,completate:3,quiz:4,partite_live:1,pct_medio:78},
        per_scuola:[{scuola:'IC Pagoto',classi:2,avviate:4,completate:3,pct_medio:81,ultima:'2026-09-14T10:00:00Z'},
                    {scuola:'IC Scaduto',classi:1,avviate:1,completate:0,pct_medio:52,ultima:'2026-06-01T10:00:00Z'}],
        per_classe:[{codice_classe:'ICPA-5A-X1',nome:'5ª A',scuola:'IC Pagoto',avviate:3,completate:2,quiz:3,partite_live:1,pct_medio:81,ultima:'2026-09-14T10:00:00Z'}],
        per_lezione:[{lezione:'goccia-mare',avviate:5,completate:3,quiz:4,pct_medio:55}],
        ultimi_30gg:[{giorno:'2026-09-13',n:2},{giorno:'2026-09-14',n:5}]},error:null};
      return {data:null,error:null}; } })};
  window.Hls={isSupported:()=>false}; window.alert=()=>{}; window.confirm=()=>true;
  window.prompt=(m,d)=>window.__prompt!==undefined?window.__prompt:d;
  </script>`;
  html = html.replace('<head>','<head>'+mock).replace(/<script src="https:[^"]*"><\/script>/g,'');
  const dom = new JSDOM(html,{url:'http://localhost/regia-edu.html',runScripts:'dangerously',pretendToBeVisual:true});
  dom.window.HTMLMediaElement.prototype.play=()=>Promise.resolve();
  dom.window.HTMLMediaElement.prototype.pause=()=>{};
  return dom;
}

const at = ms => new Promise(r=>setTimeout(r,ms));
let p=0,f=0; const ok=(n,c)=>{c?(p++,console.log('  ✓ '+n)):(f++,console.log('  ❌ '+n));};

(async () => {
  const dom = costruisci(UTENTI[0]); const w = dom.window, d = w.document;
  await at(450);

  console.log('— A. Scuole —');
  await w.apriScuole(); await at(80);
  ok('pannello scuole aperto, 2 scuole del cliente', !d.getElementById('scuolePanel').classList.contains('hidden') && d.querySelectorAll('#scuoleList .lezItem').length===2);
  ok('badge licenza: attiva e scaduta distinte', d.getElementById('scuoleList').textContent.includes('ATTIVA') && d.getElementById('scuoleList').textContent.includes('2026-06-30'));
  await w.apriScuola('sc-2'); await at(80);
  ok('form scuola compilato (pagante, data)', d.getElementById('sTipo').value==='pagante' && d.getElementById('sA').value==='2026-06-30');
  d.getElementById('sA').value='2027-06-30'; d.getElementById('sRef').value='Prof. Bianchi';
  await w.salvaScuola(); await at(30);
  const ss = w.__scritture.find(s=>s.tab==='edu_scuole'&&s.op==='update');
  ok('salvaScuola: rinnovo licenza + referente', ss && ss.payload.licenza_a==='2027-06-30' && ss.payload.referente==='Prof. Bianchi');
  w.__prompt='IC Nuovo'; await w.nuovaScuola(); await at(50);
  const ns = w.__scritture.find(s=>s.tab==='edu_scuole'&&s.op==='insert');
  ok('nuovaScuola: creata come ospite nel cliente giusto', ns && ns.payload.nome==='IC Nuovo' && ns.payload.tipo==='ospite' && ns.payload.cliente_id==='cl-sal');

  console.log('— B. Classi dentro la scuola —');
  await w.apriScuola('sc-1'); await at(80);
  ok('classi della scuola elencate col link', d.getElementById('classiList').textContent.includes('ICPA-5A-X1') && d.getElementById('classiList').textContent.includes('?classe=ICPA-5A-X1'));
  w.__prompt='5ª B'; await w.nuovaClasse(); await at(60);
  const nk = w.__scritture.find(s=>s.tab==='edu_classi'&&s.op==='insert');
  ok('nuova classe legata alla scuola, codice col prefisso istituto', nk && nk.payload.scuola_id==='sc-1' && /^ICPA-/.test(nk.payload.codice));

  console.log('— C. Catalogo (Netflix) —');
  await w.apriCatalogo('co-goc'); await at(80);
  ok('pannello catalogo aperto sul corso giusto', !d.getElementById('catPanel').classList.contains('hidden') && d.getElementById('catCorso').value==='co-goc');
  ok('destinazioni del catalogo prese dalla rpc edu_elenco_clienti (tutti i clienti, non solo il proprio)', w.__rpc.some(r=>r.fn==='edu_elenco_clienti') && d.getElementById('catDest').options.length===window_fx_clienti(w));
  ok('elenco licenze: proprietario + licenziatario con scadenza', d.getElementById('catList').textContent.includes('PROPRIETARIO') && d.getElementById('catList').textContent.includes('IC Pagoto') && d.getElementById('catList').textContent.includes('2027-06-30'));
  d.getElementById('catDest').value='cl-icp'; d.getElementById('catA').value='2028-06-30';
  const prima = w.__scritture.filter(s=>s.tab==='edu_catalogo').length;
  await w.concediCorso(); await at(30);
  ok('concessione al cliente: insert con date', w.__scritture.filter(s=>s.tab==='edu_catalogo'&&s.op==='insert').length===1);
  d.getElementById('cata_cat-2').value='2029-01-31'; await w.aggiornaLicenzaCorso('cat-2'); await at(30);
  const up = w.__scritture.find(s=>s.tab==='edu_catalogo'&&s.op==='update');
  ok('scadenza licenza aggiornabile dalla lista', up && up.payload.a==='2029-01-31');
  await w.revocaCorso('cat-2'); await at(30);
  ok('revoca licenza', w.__scritture.some(s=>s.tab==='edu_catalogo'&&s.op==='delete'));

  console.log('— D. Corso privato non condivisibile —');
  await w.apriCatalogo('co-sal'); await at(80);
  d.getElementById('catDest').value='cl-icp';
  const pre2 = w.__scritture.filter(s=>s.tab==='edu_catalogo'&&s.op==='insert').length;
  await w.concediCorso(); await at(30);
  ok('corso privato: concessione BLOCCATA con spiegazione', w.__scritture.filter(s=>s.tab==='edu_catalogo'&&s.op==='insert').length===pre2);

  console.log('— E. Duplicazione —');
  await w.apriCatalogo('co-goc'); await at(60);
  d.getElementById('catDest').value='cl-icp';
  await w.duplicaCorso(); await at(60);
  const rp = w.__rpc.find(r=>r.fn==='edu_duplica_corso');
  ok('duplica corso: RPC con corso e cliente destinazione', rp && rp.args.p_corso==='co-goc' && rp.args.p_cliente_dest==='cl-icp');

  console.log('— F. Mascotte e visibilità nel corso —');
  await w.apriCorsi(); await at(60); w.apriCorso('co-goc'); await at(60);
  ok('editor corso: mascotte e visibilità precompilate', d.getElementById('coMascNome').value==='Coccio di sale' && d.getElementById('coVis').value==='catalogo');
  d.getElementById('coMascNome').value='Goccia'; d.getElementById('coVis').value='privato';
  await w.salvaCorso(); await at(40);
  const sc = w.__scritture.filter(s=>s.tab==='edu_corsi'&&s.op==='update').pop();
  ok('salvaCorso: mascotte del corso e visibilità', sc && sc.payload.mascotte.nome==='Goccia' && sc.payload.visibilita==='privato');

  console.log('— G. Statistiche per scuola —');
  await w.apriStats(); await at(100);
  ok('KPI include le scuole', d.getElementById('stKpi').textContent.includes('Scuole'));
  ok('tabella per scuola con media', d.getElementById('stScuole').textContent.includes('IC Pagoto') && d.getElementById('stScuole').textContent.includes('81%'));
  ok('tabella per classe mostra la scuola', d.getElementById('stClassi').textContent.includes('5ª A'));

  console.log('\nRISULTATO: ' + p + ' passati, ' + f + ' falliti');
  process.exit(f ? 1 : 0);
})().catch(e => { console.error('ERRORE TEST:', e.message); process.exit(1); });
