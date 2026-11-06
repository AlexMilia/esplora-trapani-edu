# Registro delle modifiche

## 06/11/2026 — blocco didattico (migrazione 32): la piattaforma diventa adottabile da una scuola

Chiude i tre buchi che impedivano a un dirigente di comprare: l'evidenza valutativa, la continuità d'uso, la misurabilità.

### Database — `migrazioni/migrazione_32_didattica.sql`
- `edu_corsi.didattica` e `edu_lezioni.didattica` (jsonb): traguardi e obiettivi per livello, UDA, guida prima/durante/dopo, materiali, collegamenti al libro. Esposti al player da `edu_get_corsi` e `edu_get_lezione_tenant` (riscritte).
- **`edu_esiti`**: l'esito di ogni quiz diventa una riga citabile — modalità `aula | live | compito | ingresso | uscita`, partecipanti come conteggio, giuste/domande, percentuale calcolata dal database, dettaglio aggregato per domanda. Prima il risultato del quiz live viveva solo nel file temporaneo della partita e si perdeva.
- **`edu_compiti`** + `edu_compito_apri()` (non restituisce mai le risposte giuste) e `edu_compito_valuta()` (corregge sul server e registra l'esito).
- `edu_salva_esito()` e `edu_diario_classe()` per il player anonimo, con validazione di cliente, licenza, codice classe e dimensione del payload; doppio invio entro due minuti riconosciuto e non duplicato.
- RLS canonica come la migrazione 29: gli esiti li legge il proprio cliente, li scrive l'editor; **anon non ha nessun permesso diretto** sulle due tabelle nuove (c'è un controllo finale che fallisce la migrazione se ne trova). Un controllo in coda verifica questa condizione a ogni esecuzione.

**Privacy, scelta di progetto:** l'unità di misura è la **classe**, non l'alunno. Nessun nome e nessun nickname entra negli esiti; i nickname del quiz live restano nel file della partita. È questa scelta che tiene la piattaforma fuori dal trattamento dei dati dei minori e riduce l'informativa alle famiglie a una pagina.

### API — `app/api.php` v6
Azioni nuove: `esito` (POST, throttle 60/5 min per IP), `diario`, `compito`, `consegna` (POST, throttle 240/5 min: una classe intera, non un bot). Validazione e normalizzazione prima di Supabase; la anon key resta l'unica credenziale usata.

### Player — `app/index.php` v2.4
- **⏪ 10s / ⏩ 10s** e **‹ › lezione precedente/successiva** nella barra docente: prima l'unico modo di spostarsi nel video era trascinare il cursore in fondo allo schermo, impraticabile su una LIM.
- **📋 scheda della lezione** per il docente (obiettivi del livello in corso, traguardi, prima/durante/dopo, materiali): mette in pausa il video all'apertura e riprende alla chiusura; se la lezione non è compilata lo dice invece di mostrarsi vuota.
- **Percorso della classe nel menu**: lezioni fatte con esito e numero di volte, dal server per codice classe (`edu_diario_classe`), con ripiego su `localStorage`.
- **Esito salvato** a fine quiz e a fine quiz live; **«Prossima lezione»** nella schermata finale.

### Compito a casa — `app/compito.php` (nuovo)
Pagina leggera per il telefono: clip 360 da rivedere (A-Frame, finestra `da`→`a` in ciclo), domande a scelta, correzione dal server con riscontro di quale era la risposta giusta. Nessun account, nessun dato personale; sessione e token come il player.

### Regia — `app/regia-edu.php/.html` v18
- Didattica del corso (📚 Corsi) e **scheda didattica della lezione** nell'editor.
- Nuovo pannello **🧾 Esiti e compiti**: filtri per cliente, classe, modalità e periodo; riepilogo con il confronto **ingresso → uscita** e il guadagno in punti; **CSV** (punto e virgola, campi tra virgolette, segno di ordine dei byte: Excel italiano lo apre senza procedure) e **scheda stampabile** con intestazione, nota sull'assenza di dati personali e spazio per le firme di docente e dirigente; gestione dei compiti con generazione del codice, copia delle domande dal quiz della lezione filtrate per livello, link da dare alla classe e anteprima.

### Documenti per le scuole (nuovi)
- `docs/didattica/`: UDA pronta per il PTOF (doppia variante primaria/medie), guida docente lezione per lezione sui cinque mestieri, rubriche su quattro livelli, prove di ingresso e uscita parallele con griglie di correzione, protocollo della sperimentazione all'IC «G. Pagoto» con la struttura della relazione finale.
- `docs/amministrativo/`: nomina a responsabile del trattamento (art. 28 GDPR) con i tre sub-responsabili reali, informativa per le famiglie, dichiarazione di accessibilità (con le non conformità dichiarate, LIS compresa), scheda tecnica per l'affidamento diretto, nota interna sulle vie d'acquisto.
  Sono **modelli**: i segnaposto `[DA COMPILARE: ...]` vanno riempiti e i testi legali validati da un consulente prima dell'uso.

### Test (tutti verdi il 06/11/2026)
- jsdom: **15 suite, 281 verifiche** (`t_didattica_player.js` 38, `t_didattica_regia.js` 57).
- `t_didattica.sql`: 51 verifiche su esiti, diario, compiti e permessi, con la migrazione applicata due volte.
- `t_didattica_api.sh`: 30 verifiche offline contro `mock/supa-edu-mock.php`, compresa la prova che le risposte giuste non lasciano il server e che api.php non usa mai la chiave service.
- Compresi i casi di testo malevolo nei campi didattici e nei dati degli esiti (nessun HTML eseguito, niente XSS) e la tenuta del CSV con virgolette e punti e virgola nelle note.

### Correzioni emerse durante il lavoro
- La didattica del corso non si ricaricava nel form (mancava la chiamata in `apriCorso`): corretta.
- `cpCaricaLezioni` leggeva una variabile che in regia non esiste: ora interroga `edu_lezioni` per corso.
- `t_statica.js` rimane il guardiano delle funzioni mancanti: ha retto anche con 300 righe nuove di regia.

## 26/10/2026 — nascita della repository

Fino a oggi il progetto viveva solo in pacchetti zip (`esplora-trapani-edu-CATALOGO.zip`, `FASE1-AUDIT.zip`,
`FASE2-STRIPE.zip`, `demo-vr-quest.zip`, manuale tecnico). Questa repository li riunisce e diventa la fonte unica.

### Riorganizzazione (nessuna modifica funzionale)
- `app/` → codice da pubblicare; `migrazioni/`, `test/`, `docs/`, `deploy/`, `demo-vr/`.
- `app/dati/config.php` → **`config.example.php`** (modello versionato; il vero `config.php` è escluso da git).
- Test jsdom: percorsi assoluti del vecchio sandbox sostituiti con percorsi relativi alla repo; `npm test` li lancia tutti.
- Nuovi lanciatori: `test/rendi-player.sh` (renderizza `index.php` per i test del player), `test/esegui-js.sh`,
  `test/t_stripe_avvia.sh` (avvia i mock e lancia `t_stripe.sh`), `test/db_avvia.sh` (replica → migrazioni ×2 → fixture → test SQL),
  `test/t_api26.sh` ora autonomo (server PHP integrato, nessun percorso fisso).

### Correzioni emerse rieseguendo TUTTI i test da zero
- **Migrazione 31 + regia v17.1 — pannello 🎞️ Catalogo per gli editor.** Con la RLS consolidata (migr. 29) un editor legge
  solo il proprio cliente, quindi «Chi può usarlo…» non gli offriva più nessuna destinazione a cui concedere o duplicare un corso
  (funzionava solo per l'admin). Nuova RPC `edu_elenco_clienti()` (`security definer`, solo editor/admin, solo `id/slug/nome`)
  e la regia la usa per il menu delle destinazioni e per i nomi nel catalogo; i dati riservati dei clienti restano invisibili.
  Trovato da `t_flusso_tenant.sql` passo 7 sulla replica pulita. **Da applicare in produzione insieme alla regia v17.1.**
- `migrazioni/replica.sql` (solo test): aggiunto il ruolo `service_role` (esiste su Supabase; la migr. 30 gli concede la RPC
  del webhook) e i permessi di `tester` su `auth.users`. Senza, la `migrazione_completa.sql` si fermava alla riga della
  migr. 30 sulla replica — in produzione il ruolo c'è, quindi lì non sarebbe successo.
- `test/fixture_test.sql` (solo test): i test SQL davano per scontati un editor della Salina (`2222…`), un secondo cliente
  licenziatario (`ic-pagoto`) con editor e lezione, un utente da promuovere e una classe altrui; la replica rispecchia la
  produzione (dove `2222…` è admin) e questi dati non c'erano. Ora sono espliciti.
- `test/t_abbonamenti.sql` riscritto con asserzioni ✓/❌ e letture in istruzioni separate dall'evento (prima leggeva lo stato
  precedente per via dello snapshot e la riga «attesi 6» era vecchia: gli eventi distinti sono 7). Confermato: pausa → licenza
  sospesa, ripresa → attiva, cancellazione → scaduta oggi, retry idempotente, editor non legge l'abbonamento.
- `test/t_statica.js`: i nomi protetti da `typeof nome` (wrapper UMD della libreria QR in `live-lim.js`) non sono più
  segnalati come «chiamata non risolta»; controprova fatta: una `vidStato` mancante viene ancora trovata.

### Esito dei test sulla repository (26/10/2026)
- jsdom: 13 suite, 186 verifiche, 0 errori (`npm test`)
- API offline: 5/5 · Stripe su mock: 28/28
- DB: replica + `migrazione_completa.sql` applicata 2 volte senza errori · matrice RLS senza scostamenti ·
  flusso nuovo tenant 25/25 · abbonamenti 14/14
- Non rieseguiti qui (servono Apache + `.htaccess`): `t_api_flussi.sh`, `t_live_flussi.sh`; stress test `stress-live.js`.

## Storico precedente
Vedi `LEGGIMI-CATALOGO.md` (16–25/09: catalogo, audit, stress test, deploy), `AUDIT-FASE1.md` (RLS consolidata),
`LEGGIMI-FASE2-STRIPE.md` (abbonamenti), `MANUALE-TECNICO-PRESA-IN-CARICO.md` (stato al 25/09).
