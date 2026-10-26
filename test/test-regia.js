/* TEST REGIA v14 — jsdom + Supabase mock */
const { JSDOM } = require('jsdom');
const fs = require('fs');

const CL_SAL = { id:'cl-sal', slug:'salina-culcasi', nome:'Salina Culcasi', progetto_legacy:'sale-in-classe', brand:{titolo:'Sale in Classe'}, piano:'premium', licenza_stato:'attiva', licenza_fine:null };
const CL_ESP = { id:'cl-esp', slug:'esplora-trapani', nome:'Esplora Trapani', progetto_legacy:'antichi-mestieri-trapani', brand:{}, piano:'pro', licenza_stato:'scaduta', licenza_fine:'2026-06-30' };
const CORSI = [
  { id:'co-sal', proprietario_id:'cl-sal', slug:'la-salina', titolo:'Alla scoperta della salina', emoji:'🧂', stato:'pubblicato', fascia:'entrambe', ordine:10 },
  { id:'co-goc', proprietario_id:'cl-sal', slug:'la-vita-della-goccia', titolo:'La vita della goccia', emoji:'💧', stato:'bozza', fascia:'entrambe', ordine:20, prologo:'Da qualche parte…' },
  { id:'co-mes', proprietario_id:'cl-esp', slug:'antichi-mestieri', titolo:'Antichi Mestieri', emoji:'🛠️', stato:'pubblicato', fascia:'entrambe', ordine:10 },
];
const LEZ = [
  { id:'l1', slug:'salinaio', titolo:'Il mestiere del salinaio', progetto:'sale-in-classe', corso_id:'co-sal', stato:'pubblicata', emoji:'🧂', ordine:10, owner:null },
  { id:'l2', slug:'corallo', titolo:'La lavorazione del corallo', progetto:'antichi-mestieri-trapani', corso_id:'co-mes', stato:'pubblicata', emoji:'🪸', ordine:20, owner:null },
  { id:'l3', slug:'orfana', titolo:'Lezione senza corso', progetto:'sale-in-classe', corso_id:null, stato:'bozza', emoji:'❓', ordine:30, owner:null },
];
const UTENTI = [
  { id:'u-ale', email:'ale@x.it', nome:'Alessandro', ruolo:'admin', cliente_id:null },
  { id:'u-ed', email:'editor@salina.it', nome:'Editor Salina', ruolo:'editor', cliente_id:'cl-sal' },
];

function costruisci(utente) {
  let html = fs.readFileSync(__dirname+'/../app/regia-edu.html', 'utf8');
  const fixtures = { edu_clienti: [CL_SAL, CL_ESP], edu_corsi: CORSI, edu_lezioni: LEZ, edu_utenti: UTENTI, edu_progetti: [],
    edu_classi: [{ id:'k1', cliente_id:'cl-sal', codice:'TP-IC12-5A', nome:'5ª A · IC Pagoto', anno:'2026/27' }],
    edu_richieste: [{ id:'r1', scuola:'IC Pagoto', referente:'Prof. Rossi', email:'rossi@ic.it', interesse:'salina', stato:'nuova', creato_il:'2026-09-01T10:00:00Z' }] };
  const mock = `<script>
  window.__scritture = [];
  window.__fixtures = ${JSON.stringify(fixtures)};
  window.__utente = ${JSON.stringify(utente)};
  function q(tab){
    const st = { tab: tab, op: 'select', filtri: [], payload: null };
    const o = {};
    const self = () => o;
    o.select = () => self(); o.order = () => self(); o.limit = () => self();
    o.eq = (k, v) => { st.filtri.push([k, v]); return o; };
    o.insert = (p) => { st.op = 'insert'; st.payload = p; return o; };
    o.update = (p) => { st.op = 'update'; st.payload = p; return o; };
    o.delete = () => { st.op = 'delete'; return o; };
    o.single = () => { st.single = true; return o; }; o.maybeSingle = () => { st.single = true; return o; };
    o.then = (res) => {
      if (st.op !== 'select') { window.__scritture.push({ tab: st.tab, op: st.op, payload: st.payload, filtri: st.filtri });
        const riga = Object.assign({ id: 'nuovo-' + st.tab }, st.payload || {}); if (st.op === 'insert') (window.__fixtures[st.tab] = window.__fixtures[st.tab] || []).push(riga); return res({ data: riga, error: null }); }
      let rows = window.__fixtures[st.tab] || [];
      st.filtri.forEach(([k, v]) => { rows = rows.filter(r => r[k] === v); });
      return res({ data: st.single ? (rows[0] || null) : rows, error: null });
    };
    return o;
  }
  window.supabase = { createClient: () => ({
    auth: { getSession: async () => ({ data: { session: { user: { id: window.__utente.id, email: window.__utente.email } } } }), onAuthStateChange: () => {} },
    from: q,
    rpc: async (fn, args) => { window.__rpc = (window.__rpc||[]); window.__rpc.push({fn, args});
      if (fn==='edu_piano_limiti') return { data: args.p_piano==='base' ? { corsi_pubblicati:1, quiz_live:false, classi:10, nome:'Base' } : { corsi_pubblicati:999, quiz_live:true, classi:999, nome:'Pro' }, error:null };
      if (fn==='edu_stats_cliente') return { data: { totali:{ classi:2, avviate:5, completate:3, quiz:4, partite_live:1, pct_medio:81 },
        per_classe:[{ codice_classe:'TP-IC12-5A', nome:'5ª A · IC Pagoto', anno:'2026/27', avviate:3, completate:2, quiz:3, partite_live:1, pct_medio:81, ultima:'2026-09-02T10:00:00Z' }],
        per_lezione:[{ lezione:'salinaio', avviate:5, completate:3, quiz:4, pct_medio:55 }],
        ultimi_30gg:[{ giorno:'2026-09-01', n:3 },{ giorno:'2026-09-02', n:5 }] }, error:null };
      return { data:null, error:null }; } }) };
  window.Hls = { isSupported: () => false };
  window.alert = () => {}; window.confirm = () => true;
  window.prompt = (m, d) => window.__promptRisposta !== undefined ? window.__promptRisposta : d;
  </script>`;
  html = html.replace('<head>', '<head>' + mock).replace(/<script src="https:[^"]*"><\/script>/g, '');
  const dom = new JSDOM(html, { url: 'http://localhost/regia-edu.html', runScripts: 'dangerously', pretendToBeVisual: true });
  dom.window.HTMLMediaElement.prototype.play = () => Promise.resolve(); dom.window.HTMLMediaElement.prototype.pause = () => {};
  return dom;
}

const attendi = ms => new Promise(r => setTimeout(r, ms));
let pass = 0, fail = 0;
const ok = (n, c) => { if (c) { pass++; console.log('  ✓ ' + n); } else { fail++; console.log('  ❌ ' + n); } };

(async () => {
  console.log('— A. ADMIN —');
  const dom = costruisci(UTENTI[0]); const w = dom.window, d = w.document;
  await attendi(400);
  const side = d.getElementById('listUff').textContent;
  ok('sidebar raggruppata per cliente', side.indexOf('Salina Culcasi') >= 0 && side.indexOf('Esplora Trapani') >= 0);
  ok('sidebar: corso sotto il cliente, lezione sotto il corso', side.indexOf('Alla scoperta della salina') < side.indexOf('Il mestiere del salinaio'));
  ok('sidebar: corso in bozza etichettato', side.indexOf('La vita della goccia') >= 0 && side.indexOf('bozza') >= 0);
  ok('sidebar: lezione senza corso in sezione a parte', side.indexOf('senza corso') >= 0 && side.indexOf('Lezione senza corso') >= 0);
  ok('pulsante Clienti & Licenze visibile per admin', !d.getElementById('btnClienti').classList.contains('hidden'));

  console.log('— B. Pannello Corsi —');
  await w.apriCorsi(); await attendi(50);
  ok('pannello corsi aperto, cliente selezionabile (2)', !d.getElementById('corsiPanel').classList.contains('hidden') && d.getElementById('cCliente').options.length === 2);
  ok('corsi del cliente selezionato (salina: 2)', d.querySelectorAll('#corsiList .lezItem').length === 2);
  w.apriCorso('co-goc'); await attendi(50);
  ok('form corso compilato (prologo, stato bozza)', d.getElementById('coProl').value.indexOf('Da qualche') === 0 && d.getElementById('coStato').value === 'bozza');
  d.getElementById('coStato').value = 'pubblicato'; d.getElementById('coProl').value = 'Nuovo prologo';
  await w.salvaCorso(); await attendi(30);
  const sc = w.__scritture.find(s => s.tab === 'edu_corsi' && s.op === 'update');
  ok('salvaCorso: update con stato e prologo', sc && sc.payload.stato === 'pubblicato' && sc.payload.prologo === 'Nuovo prologo' && sc.filtri[0][1] === 'co-goc');
  d.getElementById('coSlug').value = 'Slug Non Valido!'; await w.salvaCorso();
  ok('salvaCorso: slug non valido rifiutato', w.__scritture.filter(s => s.tab === 'edu_corsi' && s.op === 'update').length === 1);
  w.__promptRisposta = 'Nuovo corso di prova'; await w.nuovoCorso(); await attendi(30);
  const nc = w.__scritture.find(s => s.tab === 'edu_corsi' && s.op === 'insert');
  ok('nuovoCorso: insert in bozza nel cliente selezionato con slug', nc && nc.payload.stato === 'bozza' && nc.payload.proprietario_id === 'cl-sal' && nc.payload.slug === 'nuovo-corso-di-prova');

  console.log('— C. Pannello Clienti & Licenze —');
  await w.apriClienti(); await attendi(50);
  ok('lista clienti (2) con badge licenza', d.querySelectorAll('#cliList .lezItem').length === 2 && d.getElementById('cliList').textContent.indexOf('SCADUTA') >= 0);
  await w.apriCliente('cl-esp'); await attendi(80);
  ok('form cliente compilato (stato scaduta, data fine)', d.getElementById('clStato').value === 'scaduta' && d.getElementById('clFine').value === '2026-06-30');
  ok('utenti elencati con selettori ruolo/cliente', d.querySelectorAll('#cliUtenti select').length === 4);
  d.getElementById('clStato').value = 'attiva'; d.getElementById('clFine').value = '2027-06-30'; d.getElementById('clRefMail').value = 'dirigente@ic.it';
  await w.salvaCliente(); await attendi(30);
  const scl = w.__scritture.find(s => s.tab === 'edu_clienti' && s.op === 'update');
  ok('salvaCliente: licenza riattivata con nuova data e referente', scl && scl.payload.licenza_stato === 'attiva' && scl.payload.licenza_fine === '2027-06-30' && scl.payload.contatto_email === 'dirigente@ic.it');
  d.getElementById('ur_u-ed').value = 'docente'; await w.salvaUtente('u-ed'); await attendi(30);
  const su = w.__scritture.find(s => s.tab === 'edu_utenti' && s.op === 'update');
  ok('salvaUtente: ruolo e cliente aggiornati', su && su.payload.ruolo === 'docente' && su.payload.cliente_id === 'cl-sal');
  d.getElementById('ur_u-ale').value = 'admin'; await w.salvaUtente('u-ale'); await attendi(30);
  const su2 = w.__scritture.filter(s => s.tab === 'edu_utenti' && s.op === 'update').pop();
  ok('salvaUtente: admin → cliente NULL', su2 && su2.payload.ruolo === 'admin' && su2.payload.cliente_id === null);

  console.log('— D. Lezione nel corso —');

  await w.apriLezione('l1'); await attendi(80);
  const fc = d.getElementById('fCorso');
  ok('select Corso con optgroup per cliente e valore corretto', fc.querySelectorAll('optgroup').length === 2 && fc.value === 'co-sal');
  fc.value = 'co-mes'; await w.salvaMeta(); await attendi(30);
  const sm = w.__scritture.filter(s => s.tab === 'edu_lezioni' && s.op === 'update').pop();
  ok('salvaMeta: corso_id + progetto legacy sincronizzato col cliente del corso', sm && sm.payload.corso_id === 'co-mes' && sm.payload.progetto === 'antichi-mestieri-trapani');
  w.__promptRisposta = '2';   /* titolo E poi scelta corso: stesso prompt stub */
  await w.nuovaLezione(); await attendi(30);
  const nl = w.__scritture.find(s => s.tab === 'edu_lezioni' && s.op === 'insert');
  ok('nuovaLezione: nasce dentro il corso scelto (n.2) con progetto legacy', nl && nl.payload.corso_id === CORSI[1].id && nl.payload.progetto === 'sale-in-classe');

  console.log('— D2. Statistiche —');
  await w.apriStats(); await attendi(80);
  /* superato dal modello catalogo (v16): vedi test-regia26.js */
  ok('KPI media risposte giuste 81%', d.getElementById('stKpi').textContent.indexOf('81%')>=0);
  ok('tabella per classe col NOME della classe', d.getElementById('stClassi').textContent.indexOf('5ª A')>=0);
  ok('lezione sotto il 60% segnalata DA RIVEDERE', d.getElementById('stLezioni').textContent.indexOf('DA RIVEDERE')>=0);
  ok('barre ultimi 30 giorni (2)', d.querySelectorAll('#stGiorni > div').length===2);

  /* D3 (pannello Classi della Fase 4) rimosso: le classi vivono in Scuole e classi — vedi test-regia26.js e t_flusso_regia.js */

  console.log('— D4. Richieste e limiti del piano —');
  await w.apriClienti(); await attendi(80);
  ok('richieste elencate con Crea cliente', d.getElementById('richList').textContent.indexOf('IC Pagoto')>=0 && d.getElementById('richList').textContent.indexOf('Crea cliente')>=0);
  await w.attivaDaRichiesta('r1'); await attendi(80);
  const nc2 = w.__scritture.filter(s => s.tab==='edu_clienti' && s.op==='insert').pop();
  const ur = w.__scritture.filter(s => s.tab==='edu_richieste' && s.op==='update').pop();
  ok('Crea cliente da richiesta: cliente con slug, email referente; richiesta → attivata', nc2 && nc2.payload.slug==='ic-pagoto' && nc2.payload.contatto_email==='rossi@ic.it' && ur && ur.payload.stato==='attivata');
  // limite piano: cliente base con già 1 corso pubblicato → pubblicarne un altro è negato
  w.__fixtures.edu_clienti[0].piano = 'base'; w.__fixtures.edu_corsi[1].stato = 'bozza'; await w.caricaTenant();
  const prima = w.__scritture.filter(s => s.tab==='edu_corsi' && s.op==='update').length;
  await w.apriCorsi(); await attendi(30); w.apriCorso('co-goc'); await attendi(30);
  d.getElementById('coStato').value='pubblicato'; d.getElementById('coSlug').value='la-vita-della-goccia'; await w.salvaCorso(); await attendi(30);
  ok('piano Base: secondo corso pubblicato BLOCCATO', w.__scritture.filter(s => s.tab==='edu_corsi' && s.op==='update').length===prima);
  w.__fixtures.edu_clienti[0].piano = 'pro'; w.__fixtures.edu_corsi[1].stato = 'bozza'; await w.caricaTenant(); w.apriCorso('co-goc'); await attendi(30);
  d.getElementById('coStato').value='pubblicato'; await w.salvaCorso(); await attendi(30);
  ok('piano Pro: pubblicazione consentita', w.__scritture.filter(s => s.tab==='edu_corsi' && s.op==='update').length===prima+1);

  console.log('— E. EDITOR del cliente salina —');
  const dom2 = costruisci(UTENTI[1]); const w2 = dom2.window, d2 = dom2.window.document;
  await attendi(400);
  ok('editor: pulsante Clienti nascosto', d2.getElementById('btnClienti').classList.contains('hidden'));
  ok('editor: clienti visibili = 1 (il suo)', w2.clientiVisibili().length === 1 && w2.clientiVisibili()[0].slug === 'salina-culcasi');
  await w2.apriClienti();
  ok('editor: apriClienti negato', d2.getElementById('cliPanel').classList.contains('hidden'));
  await w2.apriCorsi(); await attendi(30);
  ok('editor: nel pannello corsi solo il suo cliente', d2.getElementById('cCliente').options.length === 1);
  w2.__promptRisposta = '1';
  /* superato dal modello catalogo (v16): vedi test-regia26.js */
  await w2.apriStats(); await attendi(60);
  ok('editor: statistiche solo del proprio cliente (select con 1 voce, rpc chiamata con il suo slug)', d2.getElementById('stCliente').options.length===1 && w2.__rpc.some(r=>r.fn==='edu_stats_cliente'&&r.args.p_slug==='salina-culcasi'));

  console.log('\nRISULTATO: ' + pass + ' passati, ' + fail + ' falliti');
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('ERRORE TEST:', e); process.exit(1); });
