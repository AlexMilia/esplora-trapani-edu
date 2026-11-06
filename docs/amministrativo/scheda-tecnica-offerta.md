# Scheda tecnica e offerta — «Esplora Trapani Edu»

> **Avvertenza.** Questo è un *modello* predisposto dal fornitore, da allegare agli atti dell'istituto. Non è un parere legale. Deve essere validato da un consulente legale prima dell'uso, e i riferimenti all'acquisto vanno verificati dall'ufficio che cura l'affidamento, perché gli adempimenti variano con il valore del contratto e con il regolamento interno dell'istituto.

---

## 1. Identificazione

| | |
|---|---|
| Fornitore | **[DA COMPILARE: ragione sociale]**, segno distintivo «Esplora Trapani» |
| Forma giuridica | **[DA COMPILARE: forma giuridica]** |
| Sede | **[DA COMPILARE: sede]** |
| P.IVA / C.F. | **[DA COMPILARE: P.IVA]** |
| Iscrizione | Camera di commercio **[DA COMPILARE: CCIAA, numero REA/REG. IMP.]** |
| PEC | **[DA COMPILARE: PEC]** |
| E-mail | `alessandromiliaweb@gmail.com` |
| Sito | `www.alessandromilia.it` |
| Referente | **[DA COMPILARE: nome, ruolo, telefono]** |
| Oggetto | Licenza d'uso del servizio web «Esplora Trapani Edu» |
| Destinatari | Scuola primaria e secondaria di primo grado |
| Data dell'offerta / validità | **[DA COMPILARE: data]** — valida **[DA COMPILARE: giorni]** giorni |

## 2. Descrizione del servizio

«Esplora Trapani Edu» è una piattaforma web di percorsi didattici costruiti su **video a 360 gradi** girati sul territorio. Si usa **in aula**, sulla LIM o sullo schermo interattivo, aprendo un indirizzo web con il browser già presente sul dispositivo.

Caratteristiche che definiscono il servizio:

- **nessun visore** e **nessun software da installare**;
- **nessun account per gli alunni**: non c'è iscrizione, non c'è password, non si inseriscono dati personali;
- fruizione **collettiva**, mediata dall'insegnante;
- lezioni **brevi**, articolate in pochi minuti ciascuna;
- **quiz di fine lezione**, mostrato sullo schermo e giocabile anche con i dispositivi presenti in aula tramite un PIN e un soprannome scelto sul momento;
- **scheda didattica della lezione** per il solo docente, dentro il player;
- **diario del percorso** della classe: lezioni completate e miglior esito, per codice classe;
- **compito a casa**: una pagina con una clip da rivedere e alcune domande, raggiungibile da un link con un codice, senza registrazione e con correzione sul server;
- **esiti di classe** di ogni quiz, con esportazione in CSV e scheda stampabile predisposta per le firme del docente e del dirigente;
- indirizzo dedicato per ciascun cliente, del tipo `www.alessandromilia.it/project/edu/{nome-cliente}/`.

### 2.1 Architettura e collocazione dei dati

| Componente | Funzione | Collocazione |
|---|---|---|
| Applicazione PHP | Erogazione lezioni, quiz, pannello di gestione | Hosting **Aruba**, in **Italia** |
| Database PostgreSQL e autenticazione | Contenuti, account del personale, eventi d'uso | **Supabase**, con sicurezza a livello di riga |
| Distribuzione video | Streaming dei video 360° | **Bunny Stream** (CDN) |

### 2.2 Dati trattati

- **Account con login: solo personale** (dirigente, docenti referenti, gestore). Dati: nome ed e-mail.
- **Alunni: nessun account, nessun dato personale.**
- **Tracciamento anonimo e aggregato per codice classe**. Eventi registrati: lezione avviata, lezione completata, esito del quiz come numero di risposte corrette.
- Per ogni quiz svolto, una **riga di esito della classe**: data, codice classe, corso, lezione, modalità (aula, live, compito, prova d'ingresso, prova d'uscita), numero di partecipanti come conteggio, risposte corrette su domande, percentuale, dettaglio aggregato per domanda. Nessun nome e nessun soprannome.
- Nel quiz live, **soprannome temporaneo** scelto in aula: resta nel file temporaneo della partita, **non entra nel database** e viene cancellato automaticamente con la stanza.
- Nel **compito a casa** nessun dato personale è richiesto all'alunno e le risposte corrette non raggiungono il dispositivo: la correzione avviene sul server e produce una riga di classe.
- **Nessun cookie di profilazione, nessuno strumento pubblicitario.**

Il rapporto è regolato dall'atto di nomina a responsabile del trattamento ex art. 28 GDPR (documento `nomina-responsabile-trattamento.md`).

## 3. Che cosa è incluso

| Voce | Incluso | Note |
|---|---|---|
| Accesso ai **percorsi** del catalogo concessi in licenza | Sì | Numero di corsi secondo la fascia scelta (punto 10) |
| **Lezioni** in video 360° con prologo del corso | Sì | Lezioni brevi; numero per corso secondo il percorso |
| **Quiz** di fine lezione sullo schermo | Sì | Tutte le fasce |
| **Quiz live** con PIN e dispositivi dell'aula | Secondo fascia | Non compreso nella fascia base |
| **Modalità ipovedenti** (testo ingrandito, contrasto, lettura vocale automatica) | Sì, tutte le fasce | Mai a pagamento |
| **Modalità sordi** (clip con interprete LIS affiancata, sottotitoli) | Sì, tutte le fasce, **nei limiti della copertura del corso** | Il materiale LIS **non è fornito dal fornitore**: si veda il punto 4. Anche i **sottotitoli** dipendono dal file caricato per la singola clip: la copertura si verifica prima dell'attivazione |
| **Scheda didattica della lezione** (per il docente) e **diario del percorso** della classe | Sì | Tutte le fasce |
| **Compito a casa** (clip da rivedere + domande, correzione sul server) | Sì | Tutte le fasce. Richiede un dispositivo con connessione a casa: non è obbligatorio per l'alunno |
| **Esiti di classe**: esportazione CSV e scheda stampabile con spazio per le firme di docente e dirigente | Sì | Tutte le fasce. Dati di classe, mai individuali |
| **Navigazione da tastiera** ed etichette per lettori di schermo sui comandi principali | Sì | Si veda la dichiarazione di accessibilità |
| **Codici classe** e area del docente con i dati d'uso aggregati | Sì | Numero di classi secondo la fascia |
| **Formazione dei docenti** | Sì | Un incontro di avvio (punto 7) |
| **Assistenza** | Sì | Livelli al punto 8 |
| **Aggiornamenti** della piattaforma e correzioni | Sì | Compresi nella licenza |
| Produzione di **nuovi contenuti su commessa** | No | Preventivo separato |
| Produzione di **materiale LIS** | No | Preventivo separato o a cura della scuola |
| **Visite sul posto** presso i luoghi e le attività raccontate | No | Si veda il punto 4 |
| Hardware (LIM, schermi, dispositivi, rete) | No | A carico della scuola |

## 4. Esclusioni dichiarate

Dichiarate per evitare malintesi in sede di collaudo.

1. **Il materiale LIS non è prodotto dal fornitore.** La piattaforma sa affiancare al video una clip con interprete LIS, ma la clip è a cura della scuola o di terzi. La **copertura LIS dipende dal singolo corso**: la scuola che ne ha bisogno la verifica **prima** dell'attivazione.
2. **Copertura dei sottotitoli non completa.** I sottotitoli si attivano dal player, ma esistono solo per le clip per cui il file è stato caricato. Si veda la dichiarazione di accessibilità, punto 6.1-bis.
3. **Nessuna audiodescrizione** dei video 360° e **nessuna descrizione automatica dell'immagine**: la descrizione della scena per gli alunni non vedenti o ipovedenti la fa il docente in aula. Si veda la dichiarazione di accessibilità, punti 6.2 e 6.3.
4. **Le visite sul posto non sono organizzate né mediate dal fornitore.** L'eventuale visita è concordata **direttamente** tra la scuola e l'attività, con oneri, assicurazioni e responsabilità a carico della scuola secondo le proprie procedure per le uscite didattiche. Il fornitore non garantisce la disponibilità delle attività ad accogliere le classi. **[DA VERIFICARE: se e quali protagonisti dei percorsi abbiano dato una disponibilità, da riferire solo come loro dichiarazione]**
5. **Nessuna fornitura di hardware**, nessun intervento sulla rete o sui dispositivi dell'istituto.
6. **Nessuna integrazione** con il registro elettronico, con i sistemi di identità della scuola o con il sistema informativo del Ministero, salvo diversa pattuizione scritta.
7. Il fornitore **non è iscritto** nel catalogo dei servizi cloud qualificati dell'Agenzia per la cybersicurezza nazionale. Si veda il punto 12.4.

## 5. Requisiti tecnici minimi della scuola

| Requisito | Specifica |
|---|---|
| **Browser** | Browser aggiornato con supporto a HTML5 e WebGL, in una versione recente (Chrome, Edge, Firefox o Safari). Non è supportato Internet Explorer |
| **Nessuna installazione** | Non si installa software, non si aggiungono estensioni, non servono privilegi di amministratore sul dispositivo |
| **Schermo** | LIM, schermo interattivo o videoproiettore collegato al computer dell'aula. Risoluzione consigliata almeno 1920×1080 |
| **Audio** | Diffusori dell'aula funzionanti: il racconto è parlato e la modalità ipovedenti usa la lettura vocale |
| **Rete** | Connessione cablata o Wi-Fi stabile in aula |
| **Banda indicativa** | Il video 360° è distribuito con **qualità adattiva**: la qualità scende da sé quando la banda non basta e non esiste un comando per scegliere la risoluzione. Per una resa adeguata in aula si indica una banda **effettiva di almeno 15–25 Mbit/s in download sul dispositivo che proietta**. **[DA VERIFICARE: misurazione della banda effettiva in aula, in orario di lezione, prima dell'attivazione]** · **[DA VERIFICARE: risoluzione massima dei file effettivamente caricati corso per corso; il riproduttore usa una versione a 720p come riserva quando lo streaming adattivo non è disponibile]** |
| **Rete e filtri** | Devono essere raggiungibili dall'aula: il dominio `www.alessandromilia.it`, il servizio di database e autenticazione (Supabase) e il CDN video (Bunny). Se l'istituto applica filtri o *proxy*, questi domini vanno autorizzati. Il fornitore consegna l'elenco esatto dei domini in fase di attivazione |
| **Quiz live** (opzionale) | Telefoni o tablet degli alunni, o dispositivi dell'istituto, connessi alla rete. Nessuna app da installare: si apre una pagina e si inserisce il PIN. Il quiz live è dimensionato fino a **200 partecipanti** per stanza |
| **Prova preliminare** | Si raccomanda una prova in aula, sulla LIM effettiva e con la rete effettiva, prima dell'avvio del percorso. Il fornitore la assiste a distanza |

## 6. Modalità di attivazione e tempi

| Fase | Attività | Tempo indicativo |
|---|---|---|
| 1 | Sottoscrizione del contratto di licenza e dell'atto di nomina ex art. 28 GDPR | — |
| 2 | Configurazione del cliente: indirizzo dedicato, intestazione, corsi concessi in licenza, date della licenza | **2 giorni lavorativi** dalla sottoscrizione |
| 3 | Creazione degli account del personale (dirigente, docenti referenti) e dei codici classe | 1 giorno lavorativo |
| 4 | Prova tecnica in aula, assistita a distanza | entro **5 giorni lavorativi**, su appuntamento |
| 5 | Incontro di formazione dei docenti | su appuntamento (punto 7) |
| 6 | Avvio del percorso | dalla data concordata |

Attivazione complessiva: **entro 10 giorni lavorativi** dalla sottoscrizione, salvo diverso accordo sul calendario scolastico.

**[DA COMPILARE: finestra di disponibilità degli incontri e degli avvii nel corso dell'anno scolastico]**

## 7. Formazione dei docenti

- **Un incontro di avvio** compreso nella licenza: presentazione della piattaforma, uso in aula sulla LIM, gestione dei codici classe, conduzione del quiz e del quiz live, attivazione delle modalità accessibili, lettura dei dati d'uso aggregati.
- Durata indicativa **[DA COMPILARE: durata]**; modalità **[DA COMPILARE: in presenza presso l'istituto / a distanza]**.
- Materiale di supporto consegnato in formato elettronico.
- Incontri ulteriori: preventivo separato.

## 8. Livelli di servizio e assistenza

| Voce | Impegno |
|---|---|
| **Disponibilità del servizio** | **Non è dichiarata una percentuale di disponibilità garantita.** Il servizio è erogato su infrastrutture di terzi (Aruba, Supabase, Bunny) e dipende inoltre dalla rete dell'istituto: il fornitore non è in grado di garantire un valore numerico e non lo promette. Si impegna a non eseguire interventi programmati in orario scolastico e a comunicare tempestivamente i disservizi di cui ha notizia, indicandone la causa |
| **Manutenzioni programmate** | Fuori dall'orario scolastico, con preavviso di almeno **2 giorni lavorativi** |
| **Canali di assistenza** | E-mail `alessandromiliaweb@gmail.com`; WhatsApp **3490627997**; PEC **[DA COMPILARE: PEC]** per le comunicazioni formali |
| **Orario del presidio** | Giorni lavorativi, **[DA COMPILARE: fascia oraria]**. Nessun presidio 24 ore su 24, nessuna reperibilità notturna o festiva |
| **Presa in carico** | Entro **1 giorno lavorativo** dalla segnalazione ricevuta in orario di presidio |
| **Blocco totale** (servizio non raggiungibile, lezione non avviabile) | Presa in carico **in giornata** se la segnalazione arriva in orario di presidio; obiettivo di ripristino o di soluzione temporanea entro **1 giorno lavorativo**. Se la causa è di un fornitore di infrastruttura, il fornitore apre la segnalazione, informa la scuola e ne segue l'evoluzione: i tempi sono quelli del fornitore di infrastruttura |
| **Malfunzionamento rilevante** (una lezione o il quiz non funzionano, una modalità accessibile non si attiva) | Presa in carico entro **1 giorno lavorativo**; obiettivo di risoluzione entro **5 giorni lavorativi**, con indicazione di una soluzione alternativa per la lezione in programma |
| **Segnalazione minore** (contenuto, testo, miglioria) | Riscontro entro **5 giorni lavorativi**; risoluzione secondo programmazione |
| **Segnalazioni di accessibilità** | Presa in carico entro **5 giorni lavorativi**, riscontro di merito entro **30 giorni** (dichiarazione di accessibilità, punto 8.2) |
| **Violazioni di dati personali** | Notifica alla scuola senza ingiustificato ritardo e comunque entro **24 ore** dalla conoscenza (atto di nomina, art. 10) |
| **Supporto durante le prime lezioni** | Reperibilità concordata nelle date delle prime due lezioni |
| **Penali** | **Non sono previste penali.** In caso di indisponibilità prolungata o di mancato rispetto reiterato dei termini sopra, la scuola può chiedere la riduzione proporzionale del corrispettivo o recedere senza oneri (punto 9.3) |

Il fornitore opera con una **struttura ridotta** (si veda l'art. 5.2 dell'atto di nomina). I termini sopra sono obiettivi che è in condizione di rispettare con quella struttura: sono volutamente prudenti, e preferibili a termini più stretti che non potrebbero essere mantenuti.

## 9. Durata, rinnovo, recesso

### 9.1 Durata

Licenza **annuale**, con date di inizio e fine stabilite nel contratto, di norma coincidenti con l'anno scolastico. Alla scadenza l'accesso cessa automaticamente.

### 9.2 Rinnovo

**Nessun rinnovo tacito.** Il rinnovo è oggetto di un nuovo atto della scuola. Il fornitore invia la proposta di rinnovo almeno **60 giorni** prima della scadenza. L'assenza di risposta equivale a mancato rinnovo.

### 9.3 Recesso

- La scuola può recedere in qualunque momento con preavviso di **30 giorni** a mezzo PEC. È riconosciuto il rimborso della quota di licenza non goduta, calcolata per dodicesimi, **[DA COMPILARE: condizioni esatte del rimborso]**.
- Recesso senza oneri e con rimborso integrale della quota non goduta nei casi di: opposizione a un nuovo sub-responsabile non superabile (atto di nomina, art. 7.4); mancato rispetto reiterato dei livelli di servizio; impossibilità di garantire la copertura accessibile concordata.
- Il fornitore può recedere solo per giusta causa, con preavviso di **90 giorni** e rimborso integrale della quota non goduta, mai nel corso di un percorso già avviato.
- Alla cessazione si applica l'art. 11 dell'atto di nomina (restituzione o cancellazione dei dati).

## 10. Prospetto economico

Tutti gli importi sono segnaposto da definire.

### 10.1 Fasce di licenza annuale

| Fascia | Contenuto | Quiz live | Classi | Corsi in licenza | Canone annuale |
|---|---|---|---|---|---|
| **Base** | Un corso, quiz sullo schermo, modalità accessibili, dati d'uso aggregati, formazione di avvio | No | **[DA COMPILARE: n. classi]** | 1 | **[DA COMPILARE: € ...]** |
| **Pro** | Più corsi, quiz live con PIN, dati d'uso estesi | Sì | **[DA COMPILARE: n. classi]** | **[DA COMPILARE: n. corsi]** | **[DA COMPILARE: € ...]** |
| **Premium** | Tutto il catalogo concesso in licenza, quiz live, compiti a casa, esportazione degli esiti | Sì | **[DA COMPILARE: n. classi]** | **[DA COMPILARE: n. corsi]** | **[DA COMPILARE: € ...]** |

### 10.2 Voci opzionali

| Voce | Importo |
|---|---|
| Incontro di formazione aggiuntivo | **[DA COMPILARE: € ...]** |
| Corso aggiuntivo in licenza, nell'anno | **[DA COMPILARE: € ...]** |
| Produzione di materiale LIS per un corso | **[DA COMPILARE: € ...]** |
| Produzione di un nuovo percorso su commessa | **[DA COMPILARE: € ... — a preventivo]** |
| Assistenza straordinaria, audit su richiesta | **[DA COMPILARE: € ... / ora o a giornata]** |

### 10.3 Regime fiscale e modalità di pagamento

| | |
|---|---|
| Regime IVA | **[DA COMPILARE: regime IVA applicato — ordinario con aliquota, regime forfettario, operazione esente]** |
| Prezzi indicati | **[DA COMPILARE: IVA esclusa / IVA inclusa]** |
| Eventuale ritenuta d'acconto | **[DA COMPILARE: applicabile / non applicabile]** |
| Fatturazione | Elettronica, tramite Sistema di interscambio |
| Split payment | Si veda il punto 12.3 |
| Termini di pagamento | **[DA COMPILARE: termini — di norma 30 giorni data fattura, nei limiti della normativa sui tempi di pagamento della PA]** |
| Conto dedicato per la tracciabilità | **[DA COMPILARE: IBAN e intestazione del conto dedicato]** |

## 11. Titolarità dei contenuti e licenza d'uso

1. **I contenuti restano del fornitore.** Video 360°, montaggi, testi delle lezioni, quiz, voci narranti, grafiche, mascotte, codice della piattaforma e banca dati sono di titolarità del fornitore o dei suoi aventi causa, e restano tali.
2. **Alla scuola è concessa una licenza** d'uso: non esclusiva, non trasferibile, non sublicenziabile, limitata alla durata e al perimetro del contratto, per finalità didattiche interne alle classi dell'istituto.
3. È **consentito**: proiettare le lezioni in aula; usarle in attività curricolari ed extracurricolari dell'istituto; citare il percorso nella documentazione didattica e nel PTOF; mostrare brevi estratti in incontri con le famiglie e in eventi dell'istituto, con indicazione della fonte.
4. **Non è consentito**, senza accordo scritto: scaricare, registrare, duplicare o ridistribuire i video; caricarli su altre piattaforme, canali social o repository; cederli ad altri istituti; usarli per fini commerciali; modificare o rielaborare i contenuti; aggirare le misure tecniche di protezione.
5. **Materiali conferiti dalla scuola** (immagini, testi, contributi dei docenti, materiale LIS) restano di titolarità della scuola o dei rispettivi autori. La scuola garantisce di avere i diritti necessari e concede al fornitore una licenza limitata all'uso nel servizio e per la durata del contratto. Alla cessazione, tali materiali sono restituiti o rimossi secondo le istruzioni della scuola.
6. **Immagini di persone riprese nei percorsi**: il fornitore si impegna a utilizzare nei percorsi solo riprese per le quali disponga del consenso dei protagonisti per l'uso didattico in licenza, e a esibirne la documentazione su richiesta della scuola. **[DA VERIFICARE prima della sottoscrizione: esistenza, conservazione e perimetro delle liberatorie di ciascun protagonista — la dichiarazione va resa solo per i protagonisti per cui la liberatoria è effettivamente agli atti]**
7. **Marchi e segni distintivi**: ciascuna parte resta titolare dei propri. L'uso del nome della scuola in comunicazioni del fornitore richiede autorizzazione scritta, e viceversa.

## 12. Riferimenti normativi dell'acquisto

Indicazioni ricognitive, da verificare dall'ufficio che cura l'affidamento. Gli adempimenti variano con il valore del contratto.

### 12.1 Affidamento

- Per servizi e forniture di importo **inferiore a 140.000 euro** il Codice dei contratti pubblici prevede l'**affidamento diretto**, ai sensi dell'**art. 50, comma 1, lett. b), del d.lgs. n. 36/2023**, «anche senza consultazione di più operatori economici», a soggetti in possesso di documentate esperienze pregresse idonee all'esecuzione.
- Dal **1° gennaio 2024** le procedure si svolgono tramite **piattaforme di approvvigionamento digitale certificate**, interoperabili con la Banca dati nazionale dei contratti pubblici (artt. 19 e seguenti e art. 25 del d.lgs. n. 36/2023). Il MePA è una di tali piattaforme.
- Per le istituzioni scolastiche l'attività negoziale del dirigente scolastico si svolge nei limiti e secondo i criteri deliberati dal Consiglio di istituto, ai sensi del **d.i. n. 129/2018** (regolamento di contabilità delle scuole). *[DA VERIFICARE CON UN LEGALE: articoli applicabili del d.i. n. 129/2018, soglie e criteri deliberati dal singolo istituto]*
- Il **numero minimo di preventivi** non è imposto dal Codice: dipende dal regolamento interno dell'istituto. Si applica il **principio di rotazione** e, per gli importi più contenuti, le deroghe previste.

### 12.2 CIG, CUP, DURC, tracciabilità

| Adempimento | Nota |
|---|---|
| **CIG** | Acquisito dalla stazione appaltante tramite la piattaforma certificata interoperabile con la BDNCP gestita da ANAC, e riportato negli atti e sui pagamenti. *[DA VERIFICARE: procedura operativa vigente alla data dell'affidamento — le modalità di acquisizione sono state oggetto di modifiche, incluse la dismissione dell'interfaccia web dell'ANAC per i micro-affidamenti]* |
| **CUP** | Necessario quando la spesa è imputata a un progetto di investimento o a un finanziamento che lo richiede (progetti europei, PNRR, finanziamenti ministeriali o regionali). Per una spesa corrente su fondi propri dell'istituto di norma non occorre. *[DA VERIFICARE con l'ufficio che gestisce il progetto di spesa]* |
| **Tracciabilità** | Obblighi della **legge n. 136/2010**: conto corrente dedicato, indicazione del CIG su ogni pagamento, clausola di tracciabilità nel contratto |
| **DURC** | Verifica della regolarità contributiva. **Attenzione**: l'acquisizione del DURC dipende dalla forma giuridica e dalla posizione contributiva del fornitore. Un professionista senza dipendenti e iscritto alla sola Gestione separata INPS può non essere titolare di posizione utile al rilascio del DURC: in tal caso l'istituto acquisisce l'attestazione o la dichiarazione sostitutiva pertinente. **[DA VERIFICARE: posizione contributiva del fornitore e documento effettivamente acquisibile]** |
| **Requisiti generali** | Verifica dei requisiti di cui agli **artt. 94 e seguenti del d.lgs. n. 36/2023**. Per gli importi più contenuti è ammessa la dichiarazione sostitutiva, con controlli a campione |
| **Altre verifiche** | Visura camerale, casellario informatico ANAC, dichiarazione sul conflitto di interessi e sull'insussistenza di cause di esclusione |
| **Pubblicità** | Pubblicazione dei dati dell'affidamento secondo gli obblighi di trasparenza e secondo le regole di pubblicità del Codice |

### 12.3 Fatturazione elettronica e split payment

- La fattura è emessa in formato elettronico tramite **Sistema di interscambio**, con indicazione del **codice univoco ufficio** della scuola (reperibile su IPA) e del **CIG**.
- Si applica la **scissione dei pagamenti (split payment)**, ai sensi dell'**art. 17-*ter* del d.P.R. n. 633/1972**, introdotto dall'art. 1, comma 629, lett. b), della legge n. 190/2014: l'IVA è esposta in fattura ma versata direttamente all'Erario dall'amministrazione, che corrisponde al fornitore il solo imponibile. Nel tracciato XML il campo relativo all'esigibilità dell'IVA è valorizzato con l'indicazione della scissione dei pagamenti.
- La misura si fonda su una deroga autorizzata a livello europeo e prorogata nel tempo: l'ultima proroga risulta disposta con decisione di esecuzione (UE) 2026/1728, con termine al **30 giugno 2029**. *[DA VERIFICARE alla data dell'affidamento: vigenza della deroga e del relativo termine]*
- **Casi di non applicazione** rilevanti per questo contratto: lo split payment **non si applica** se il fornitore non espone IVA in fattura (ad esempio in **regime forfettario**), né alle prestazioni assoggettate a **ritenuta d'acconto**. L'indicazione corretta dipende quindi dal regime fiscale del fornitore, da compilare al punto 10.3. **[DA VERIFICARE con il consulente fiscale del fornitore]**

### 12.4 Protezione dei dati e qualificazione cloud

- Il rapporto è regolato dall'**atto di nomina a responsabile del trattamento ex art. 28 GDPR** (documento `nomina-responsabile-trattamento.md`), che la scuola sottoscrive contestualmente al contratto.
- Il fornitore **non è iscritto** nel catalogo dei servizi cloud qualificati dell'**Agenzia per la cybersicurezza nazionale**. Il Regolamento ACN per le infrastrutture digitali e i servizi cloud della PA (atto del 27 giugno 2024, prot. n. 21007; comunicato in *Gazzetta Ufficiale* Serie generale n. 163 del 13 luglio 2024; in vigore dal 1° agosto 2024) pone in capo all'amministrazione l'obbligo di classificare i propri dati e servizi come ordinari, critici o strategici e di scegliere i servizi cloud in coerenza con tale classificazione. La valutazione compete quindi alla scuola, con il proprio RTD. Gli elementi di fatto utili all'istruttoria — in particolare l'assenza di dati personali degli alunni e di dati relativi a funzioni istituzionali della scuola — sono raccolti nell'**Allegato A** dell'atto di nomina. *[DA VERIFICARE CON UN LEGALE]*
- Il fornitore mette a disposizione la **dichiarazione di accessibilità del servizio** (documento `dichiarazione-accessibilita.md`) come elemento istruttorio. Gli obblighi di dichiarazione sull'applicazione AgID restano in capo alla scuola.

## 13. Checklist — documenti che la scuola deve avere nel fascicolo

Da spuntare prima del pagamento.

### Atti dell'istituto

- [ ] Delibera del Consiglio di istituto sui criteri e limiti dell'attività negoziale, vigente
- [ ] Imputazione della spesa nel programma annuale, con indicazione dell'attività o del progetto
- [ ] Determina a contrarre o decisione di affidamento, con motivazione della scelta del fornitore e della congruità del prezzo
- [ ] Verbale o atto di aggiudicazione, se la procedura lo prevede
- [ ] Contratto o lettera d'ordine sottoscritta digitalmente dalle parti
- [ ] Nomina del RUP

### Documenti del fornitore

- [ ] Offerta e scheda tecnica (il presente documento), sottoscritta
- [ ] Dichiarazione sostitutiva sul possesso dei requisiti generali (artt. 94 e ss. d.lgs. n. 36/2023)
- [ ] Dichiarazione sull'insussistenza di conflitti di interesse
- [ ] Dichiarazione di tracciabilità con indicazione del conto dedicato (legge n. 136/2010)
- [ ] Visura camerale
- [ ] DURC o documento equivalente acquisibile per la posizione contributiva del fornitore
- [ ] Documento d'identità e dati del legale rappresentante
- [ ] **Atto di nomina a responsabile del trattamento ex art. 28 GDPR**, sottoscritto da entrambe le parti
- [ ] **Dichiarazione di accessibilità del servizio** rilasciata dal fornitore
- [ ] Elenco dei sub-responsabili e dei domini da autorizzare sulla rete

### Adempimenti sulla procedura

- [ ] CIG acquisito e riportato negli atti e nei pagamenti
- [ ] CUP, se la spesa è imputata a un progetto che lo richiede
- [ ] Pubblicazione degli atti secondo gli obblighi di trasparenza
- [ ] Verifiche di legge concluse e documentate

### Adempimenti verso le famiglie e verso l'utenza

- [ ] **Informativa alle famiglie** approvata e diffusa (documento `informativa-famiglie.md`)
- [ ] Aggiornamento del registro dei trattamenti dell'istituto
- [ ] Parere del DPO acquisito, se previsto dalle procedure interne
- [ ] Valutazione sulla necessità di una valutazione d'impatto, documentata, anche se negativa
- [ ] Valutazione sull'applicabilità del Regolamento ACN, documentata, a cura del RTD
- [ ] Meccanismo di feedback sull'accessibilità attivo e presidiato

### Esecuzione e pagamento

- [ ] Verbale della prova tecnica in aula
- [ ] Attestazione di regolare esecuzione o verbale di collaudo
- [ ] Fattura elettronica con codice univoco ufficio, CIG e indicazione dello split payment ove applicabile
- [ ] DURC in corso di validità alla data del pagamento, o documento equivalente
- [ ] Mandato di pagamento con indicazione del CIG

---

## Da verificare

- **Riferimenti riscontrati su fonte ufficiale**: art. 50, comma 1, lett. b), d.lgs. n. 36/2023 (affidamento diretto di servizi e forniture sotto i 140.000 euro); artt. 19 e ss. e art. 25 dello stesso decreto (piattaforme di approvvigionamento digitale, obbligatorie dal 1° gennaio 2024); art. 17-*ter* d.P.R. n. 633/1972, introdotto dall'art. 1, comma 629, lett. b), della l. n. 190/2014, con deroga europea prorogata al 30 giugno 2029; Regolamento ACN cloud (atto 27 giugno 2024, prot. n. 21007, GU Serie generale n. 163 del 13 luglio 2024, in vigore dal 1° agosto 2024).
- **Restano da verificare**: articoli applicabili del d.i. n. 129/2018 e soglie deliberate dal singolo istituto; procedura vigente per l'acquisizione del CIG; vigenza della deroga sullo split payment alla data dell'affidamento; regime fiscale del fornitore, da cui dipendono split payment, ritenuta e DURC.
- **Livelli di servizio**: sono stati tolti la disponibilità garantita al 99% e i tempi di intervento a quattro ore, che una struttura di una persona non può mantenere, ed è stata esclusa la previsione di penali. Se una scuola chiede livelli più stretti, vanno concordati per iscritto e solo se sostenibili.
- **Restano da compilare prima di presentare l'offerta**: dati societari e fiscali, PEC, regime IVA, prezzi delle fasce, durata e modalità della formazione, fascia oraria del presidio, verifica delle liberatorie dei protagonisti, copertura LIS e dei sottotitoli corso per corso.

Data **[DA COMPILARE]**

**[DA COMPILARE: ragione sociale]** — il legale rappresentante **[DA COMPILARE]**
