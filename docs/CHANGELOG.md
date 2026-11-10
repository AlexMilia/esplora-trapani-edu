# Registro delle modifiche

## 10/11/2026 — terza area: «Trapani, la città a forma di falce» · player v2.9 · migrazioni 35 e 36

Terzo caso di studio per le scuole, dopo Antichi Mestieri e Il viaggio di una goccia: undici luoghi del centro storico di Trapani raccontati a 360° da U Cuntastorie. I video erano già su Bunny (girati durante una camminata in città); qui diventano lezioni, **senza nessun riferimento all'evento** in cui sono stati girati.

### Il corso si apre con una mappa — player v2.9
- Un corso con `didattica.mappa = true`, le cui lezioni portano `didattica.luogo = {nome, lat, lng}`, non mostra le card ma una **mappa**: un segnaposto numerato per lezione, con il titolo scritto sopra.
- **Mouse** (PC collegato alla lavagna): passando sopra il titolo si ingrandisce e compare il luogo; un clic apre. **Dito o penna** (LIM, tablet): il primo tocco ingrandisce e fa comparire il tasto «Apri la lezione», il secondo apre. Il tipo di puntatore si legge a ogni tocco, quindi sulla stessa lavagna funzionano entrambi.
- La mappa **inquadra solo i punti presenti** (non la provincia) e si riadatta se la finestra cambia. I titoli si dispongono da soli attorno ai punti per non coprirsi.
- A fianco: **elenco** delle lezioni (legato ai segnaposto: passando su una riga si accende il punto, e viceversa) e **legenda**. Fatta / prossima consigliata / da fare vengono dal diario della classe.
- Telefono: mappa sopra, elenco sotto; sulla mappa i titoli compaiono uno alla volta al tocco.
- **Modalità ipovedenti**: niente mappa, resta l'elenco grande con la lettura vocale. Se la libreria della mappa non si carica (rete della scuola), il player torna da solo all'elenco.
- Leaflet 1.9.4 sta in `app/lib/leaflet/` (nessun CDN). Lo sfondo sono i tasselli di OpenStreetMap, con la citazione obbligatoria: è l'unica chiamata verso l'esterno in più, e parte solo aprendo un corso con la mappa.

### La clip con taglio, voce a parte e sottotitoli propri — player v2.9 + migrazione 35
- `edu_media` ha cinque colonne nuove, tutte facoltative: `inizio_s`, `fine_s` (taglio), `sync_s` (il secondo del video che vale «zero» per voce e sottotitoli), `vol_video` (volume dell'audio del video), `cc_url` (sottotitoli in un file `.vtt`). Le lezioni di prima non cambiano.
- Il player parte da `inizio_s`, chiude la clip a `fine_s`, tiene la voce (`audio_url`, non in ciclo) agganciata al video e la riallinea se scarta più di 0,45 s; barra, tempo e ±10 s lavorano dentro il taglio.
- La migrazione **innesta** le righe nuove nelle funzioni che trova in archivio (`edu_assembla_lezione`, `edu_get_corsi`, `edu_duplica_corso`) invece di riscriverle: non può riportare indietro una funzione che in produzione è più avanti. Se un punto d'innesto non c'è si ferma senza cambiare nulla.
- I campi nuovi **non sono ancora modificabili dalla regia**: per ora si scrivono con la migrazione.

### I contenuti — migrazione 36 (generata da `strumenti/genera_area_trapani.py`)
- Corso `trapani-citta` del tenant vetrina, pubblicato, a catalogo, ordine 25, con licenza anche per l'IC Pagoto (stessa scadenza della sua licenza di Antichi Mestieri). **11 lezioni, 13 racconti**: più racconti nello stesso luogo fanno una lezione sola (la chiesa del Collegio ne ha tre). Le due Mura di Tramontana restano due lezioni: sono a 250 metri.
- Esclusi il racconto che presentava il giro e la ginnastica in piazza. Tagliati i due punti in cui la voce parla dell'evento (l'apertura di Sant'Agostino, l'inizio e il saluto finale di Villa Margherita). Il generatore **si ferma** se in un testo trova una parola dell'evento.
- Per ogni racconto: fermate con il punto «?» già validato e due testi (primaria/medie); due domande per livello a racconto, con la risposta giusta in posizioni diverse.
- Ripetibile e prudente: se il corso esiste già non tocca nulla, quindi le correzioni fatte in regia restano.
- Voce e sottotitoli restano nei file del sito della camminata (`/project/attenti-a-quei-due/ver2/`): **se quella cartella viene spostata o cancellata, le lezioni restano senza voce.**

### Test
`t_clip.js` (39), `t_mappa.js` (54, Leaflet finto), `t_mappa_browser.sh` (26, Chromium vero: hover, doppio tocco, telefono), `t_area_trapani.sql` (35, con il ruolo `anon` come il player). Ogni test è stato visto fallire sul codice sbagliato prima di passare su quello giusto.

### Ordine di messa online
1. Caricare `app/index.php` e la cartella `app/lib/`. 2. Applicare la migrazione 35, poi la 36. 3. Cancellare `app/dati/cache_*.json`. **Mai la 36 prima del player nuovo**: quello vecchio mostrerebbe i video senza tagli e con la voce fuori tempo.

## 07/11/2026 (pomeriggio) — chiusura: due revisioni indipendenti, migrazione 34, pacchetto per Aruba

Prima di chiudere, il lavoro degli ultimi due giorni è stato riletto da due revisori che non lo avevano scritto: uno sulla logica delle modifiche, uno solo sulla sicurezza di tutta la cartella `app/` e delle migrazioni. Ogni segnalazione è stata verificata nel codice prima di essere accettata. Qui sotto quello che era vero e come è stato chiuso.

### Sicurezza del database — `migrazioni/migrazione_34_chiusura_sicurezza.sql`
- **Le viste erano leggibili con la chiave pubblica.** PostgreSQL e Supabase concedono tutto su ciò che nasce in `public`; la migrazione 29 revocava solo sulle tabelle. `v_edu_report_cliente` esponeva ad `anon` tutti i codici classe di tutti i clienti, saltando la RLS. Ora nessuna vista è leggibile direttamente e tutte girano con i privilegi di chi chiama (`security_invoker`).
- **Le funzioni riservate erano eseguibili con la chiave pubblica**, per lo stesso default: `edu_assembla_lezione` (bozze e quiz con le soluzioni, conoscendo l'uuid), `edu_stats_cliente`, `edu_report_mio_cliente`, `edu_duplica_corso`… Il player stesso usava quattro RPC senza nessun grant esplicito. Ora: revoca da `public` e `anon` su tutte le `edu_*`, poi un **elenco esplicito** delle tredici funzioni che il player e le pagine pubbliche chiamano davvero.
- **Un evento storto rompeva le statistiche di un cliente intero.** `edu_stats_cliente` faceva `::boolean` e `::numeric` sul dettaglio degli eventi, che anon scrive. Ora i cast sono tolleranti (`edu_num`, `edu_bool`), `api.php` lascia passare solo chiavi note del tipo giusto, e la policy limita la taglia del dettaglio.
- **Le richieste di attivazione** arrivavano dal browser senza limiti: la policy ora impone `stato='nuova'`, nessun `cliente_id` e lunghezze massime.
- La migrazione finisce con un controllo che **fallisce apposta** se qualcosa è rimasto aperto. `migrazioni/replica.sql` riproduce ora i privilegi di default di Supabase, così i test vedono questi buchi: **senza la 34, `t_sicurezza.sql` ha 10 verifiche rosse**; con la 34, 20 verdi.

### Sicurezza del PHP
- **I limiti per IP si aggiravano con un header.** `api.php` e `live.php` si fidavano di `X-Forwarded-For`; Aruba non lo riscrive, quindi lo sceglieva chi chiamava, con un contatore nuovo a ogni richiesta. Ora conta solo l'indirizzo della connessione.
- La diagnostica di `api.php` passa dal limite per IP (10 tentativi ogni 5 minuti) e con `?k[]=x` risponde 403 invece di un errore 500. Il referer si confronta per host, non per sottostringa.
- `live.php`: tetto ai testi di domande e opzioni, immagini del «Lo sapevi?» solo dai domini della piattaforma.
- Cookie di sessione `HttpOnly`, `SameSite=Lax`, `Secure` su https; `nosniff` anche su `scheda.php`, `compito.php`, `stripe.php`.
- L'`.htaccess` di `/project/edu/` passa l'header `Authorization` a PHP (senza, la regia Abbonamenti risponde sempre 401 su Aruba) e nasconde gli errori PHP.

### Player v2.5 — correzione del giroscopio
Su telefono A-Frame **somma** il movimento del giroscopio alla rotazione che il codice scrive: la rotazione automatica verso il punto atterrava a (punto − giroscopio), e lasciava l'orizzonte inclinato per tutta la lezione. Ora il giro si fa per differenza rispetto a dove gli oggetti stanno. Verificato con un test che riproduce la formula di `look-controls` 1.5.0: con il codice vecchio fallisce. In più: con l'elenco lezioni o la scheda docente aperti la scena non gira sotto, e su telefono stretto la freccia «in alto» non copre più la scritta.

### Schede da stampare
- I promemoria `[DA VERIFICARE SUI VIDEO]` dei quattro mestieri in bozza **non arrivano più sul banco**: la regia li mostra, la stampa li salta. La migrazione 33 li conta in un avviso.
- Con due o tre fasi la mescolata poteva ricadere nell'ordine giusto (esercizio già risolto): ora ruota di un posto. L'articolo «L'…» viene abbassato come gli altri. Un parametro scritto male nell'indirizzo dà la pagina di cortesia, non un errore 500.
- Migrazione 33: riempie **tutte** le lezioni originali che corrispondono (anche la copia di un corso duplicato per un secondo cliente), trova la lezione per slug o per **titolo esatto** (non per somiglianza: «La salina e i fenicotteri» non riceve la scheda del salinaio), e guarda solo i progetti di Antichi Mestieri / Sale in Classe. Il controllo finale non fa fallire il file se una scheda è scritta male.
- Regia: salvando una lezione non si perdono più i campi della scheda che il form non conosce, e la riga «mancano ancora…» si aggiorna subito.

### Pacchetto per Aruba — `deploy/crea-zip.sh`
Costruisce lo zip con la stessa struttura del server e, prima di chiuderlo, verifica che non contenga `config.php`, `debug500.php`, `stripe-setup.php`, `regia-edu.html`, chiavi Stripe o la parola `service_role` fuori dal modello; ogni PHP passa `php -l`; `IMPRONTE.txt` serve a confrontare dopo il caricamento. `deploy/LEGGIMI-METTI-ONLINE.md` ha i passi in ordine e i controlli.

### Test
`t_sicurezza.sql` (20), `t_schede_seed.sql` 16 → 19, `t_bussola.js` 59 → 67, `t_scheda.sh` 43 → 49, `t_didattica_api.sh` 30 → 37. Giro completo: 16 suite jsdom, 11 passi di database con 125 verifiche SQL e le migrazioni applicate due volte, API 37, schede 49, Stripe 28, privacy del live.

### Segnalazioni valutate e NON accolte, con il perché
- *Limitare le adesioni al quiz live per IP*: in una scuola tutta la classe esce con lo stesso IP; avrebbe bloccato la classe, non chi disturba.
- *Non mostrare la risposta giusta nel compito a casa*: è una scelta didattica voluta (il compito è esercizio, non verifica certificata), e senza identificare l'alunno — che per scelta non esiste nel sistema — non si può impedire una seconda consegna.
- *Rendere indistinguibile «stanza inesistente» da «stanza in attesa»*: il PIN a sei cifre dura il tempo di una partita; vale il compromesso che fanno gli strumenti analoghi.

## 07/11/2026 — player v2.5: la scena porta l'occhio sul punto che brilla

Segnalazione dal campo: nelle presentazioni da **smartphone** le persone si fermavano. Il video si bloccava sulla tappa, il punto da toccare era fuori dallo schermo, e la scritta «gira a destra» non la leggeva nessuno.

**La causa non era la scritta, erano le soglie.** La bussola diceva «sei girato bene» se il punto stava entro **40° in orizzontale**: un numero giusto per una LIM 16:9, sbagliato per un telefono tenuto in verticale, dove di larghezza se ne vede un terzo. Il punto era fuori dallo schermo e la piattaforma taceva.

- **La soglia ora esce dal campo visivo reale** della camera e dalla forma dello schermo. Misurata: **48°** su LIM 16:9, **13°** su telefono verticale. Lo stesso punto a 35° di lato è dentro su LIM e fuori su telefono, e adesso la piattaforma lo sa.
- **Freccia grande sul bordo**, dalla parte giusta, che pulsa e si tocca (140×68 px su telefono, ancora più grande oltre i 1400 px perché le LIM si guardano da lontano). Toccandola la scena gira sul punto. La direzione è anche nell'`aria-label`, per chi usa il lettore di schermo.
- **Se nessuno lo trova, la scena gira da sola**, dolcemente: dopo **3,5 s** su schermo stretto, **7 s** su schermo largo — misurati nel browser, 4,0 s e 7,2 s reali. L'attesa serve a non togliere l'esercizio della ricerca; il giro si ferma se qualcuno sta trascinando, e con «riduci animazioni» è uno scatto secco invece di una panoramica.
- **La scritta su telefono cresce** (era 13 px, ora 16) e dice che cosa fare — «Tocca la freccia per trovare il punto» — invece di una frase lunga che andava a quattro righe. Su LIM, dove c'è spazio, dice anche da che parte.
- La freccia sparisce quando la scheda della scoperta è aperta, e non si guarda mai oltre lo zenit.

### Test
`test/t_bussola.js`, **52 verifiche**: la matematica della soglia sui tre formati, il verso più corto (da 170° a −170° si gira a destra), il giro con e senza animazione, il comportamento della freccia, il dito che ha la precedenza, i dati storti dalla regia che non devono far finire la scena chissà dove. Entrata in `esegui-js.sh`: **16 suite**. Verificato che il test del capovolgimento fallisce davvero se si toglie il limite, e provato nel browser in formato telefono e LIM.

## 06/11/2026 (notte) — i testi delle schede entrano nelle lezioni (migrazione 33)

Correzione di rotta sul lavoro di stasera: le schede si componevano dai dati della lezione, ma i **testi** dei cinque mestieri stavano ancora in file del codice (`contenuti/*.json`), letti solo dal mock dei test. In produzione quelle lezioni avevano `didattica.scheda` vuoto, quindi le schede sarebbero uscite incomplete, e soprattutto non c'era nulla da modificare in regia.

### `migrazioni/migrazione_33_schede_contenuti.sql` (nuova)
Porta i testi dei cinque mestieri dentro `edu_lezioni.didattica.scheda`, una volta sola. Da lì in poi si modificano **dalla regia**, come ogni altro contenuto della lezione.
- **Non sovrascrive.** Se una lezione ha già una scheda, anche con un solo campo scritto in regia, viene lasciata com'è. Rilanciare il file non cambia niente.
- **Ripetibile al contrario:** per tornare al testo di partenza di una lezione, si svuotano i campi in regia, si salva, si rilancia.
- Trova la lezione **per slug** (più grafie possibili) e, se non la trova, **per titolo**. Guarda solo le lezioni originali, mai le copie dei docenti. Se una lezione non esiste ancora, lo dice e va avanti senza fallire.
- Ogni passaggio stampa un `NOTICE`: *scheda riempita* / *ha già una scheda* / *nessuna lezione in archivio*, più un riepilogo finale e un avviso se una scheda è senza fasi o senza glossario.

### Due cose in meno da scrivere a mano — `app/scheda.php`
- **Numero della scheda.** Se `numero`/`di` non sono scritti in regia, li ricava dal posto che la lezione occupa nel corso (`edu_get_corsi`): una lezione nuova non obbliga più a rinumerare tutte le altre. Il valore scritto in regia vince sempre su quello dedotto.
- **Che cosa disegnare.** Se il campo è vuoto, si disegna il primo punto che brilla nel video, con l'articolo portato in minuscolo perché la frase regge: «Disegna il munzeddu, e scrivi a cosa serve».

### Regia
Le etichette dicono che cosa succede lasciando vuoto un campo, e la riga di stato non chiede più il disegno fra le cose mancanti, visto che ora ha un ripiego.

### Test
`test/t_schede_seed.sql`, **16 verifiche** dentro `db_avvia.sh`: il seed riempie, non sovrascrive il lavoro fatto in regia, ricarica dopo uno svuotamento, trova la lezione per titolo quando lo slug è diverso, non tocca le copie dei docenti, e quello che scrive è davvero ciò che `scheda.php` legge. `t_scheda.sh` sale a **43 verifiche** con le due deduzioni nuove. Il giro completo sul database: 10 passi, 106 verifiche SQL.

## 06/11/2026 (sera) — le schede da stampare le genera la piattaforma

Finora le schede alunno erano due file Word scritti a mano per un solo mestiere. Ora sono una pagina della piattaforma: il docente apre la lezione, preme 🖨️ e ha davanti la scheda di **quella** lezione, costruita dai dati che sono già in regia.

### `app/scheda.php` (nuovo)
`scheda.php?c=<cliente>&lez=<slug>[&tipo=standard|adattata][&liv=junior|senior]` — HTML con `@page` A4, nessuna libreria PDF sul server: stampa e «salva come PDF» li fa il browser.

- **Versione standard, 2 facciate.** Nove sezioni: domanda di ingresso, caccia agli oggetti dentro il video 360° (con un distrattore che nel video non c'è), fasi del lavoro da rimettere in ordine, glossario del mestiere, domanda sul territorio, intervista da fare a casa, disegno, autovalutazione, firme.
- **Versione adattata (autismo), 10 pagine.** Pagina per l'insegnante (con le soluzioni, da non consegnare), agenda visiva delle cinque attività, una attività per pagina con un solo compito ciascuna, facce per l'autovalutazione, tessere da ritagliare, carte AIUTO e PAUSA, e la **carta del ruolo nel quiz in due versioni** — una se si gioca dalla LIM, una se si gioca dai telefoni — perché l'alunno sappia prima che cosa dovrà fare.
- Tutto viene dai dati della lezione: hotspot → cose da cercare e glossario, tappe → fasi, quiz → vero/falso, `didattica.scheda` → i testi scritti dal docente. **Le fasi escono mescolate** (altrimenti l'esercizio non esiste) ma con un ordine stabile: ristampando si ottiene la stessa copia, e le soluzioni dell'insegnante restano valide.
- Quando in regia manca qualcosa, la scheda **non si rompe**: avvisa in cima che è incompleta e stampa solo le sezioni che ha. Dove manca la foto compare un riquadro «Incolla qui un fotogramma».
- Icone disegnate in SVG, non emoji: in bianco e nero restano nitide.

### Dove si apre
- **Player** (`app/index.php` v2.4): pulsante 🖨️ nella barra docente, accanto a 📋. Se non c'è una lezione aperta lo dice invece di aprire una pagina vuota.
- **Regia** (`app/regia-edu` v18): pannello **🖨️ Scheda da stampare** — si sceglie cliente, lezione, livello e tipo, e si vede subito se quella lezione ha abbastanza dati.

### Contenuti dei cinque mestieri — `contenuti/*.json`
Il salinaio è trascritto dalle due schede cartacee già usate per il Pagoto. Gli altri quattro (corallaio, tappeti ericini, raccolta delle olive, vendemmia) sono **bozze** composte dalla guida docente: le frasi da controllare sul video portano la marcatura `[DA VERIFICARE SUI VIDEO]`, che si vede anche in stampa finché non viene tolta.

### Test
`test/t_scheda.sh`: 39 verifiche verdi — contenuto, ordine stabile delle fasi, livelli, le dieci pagine dell'adattata, i ripieghi quando mancano i dati, e la sicurezza (nessuna chiave nella pagina, `noindex`, solo anon key verso Supabase, nome della scuola nell'indirizzo che non inietta codice). Le ultime due verifiche stampano davvero con Playwright e contano le pagine del PDF.

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
