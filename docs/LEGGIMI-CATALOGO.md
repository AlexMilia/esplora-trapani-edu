# ESPLORA TRAPANI EDU — MODELLO CATALOGO (migr. 26-27)
## 16 settembre 2026 · pacchetto completo e collaudato

---

## 1. Che cosa cambia

### Catalogo «stile Netflix»
Un corso esiste **una volta sola** e viene **concesso in licenza** ai clienti che
lo useranno. Correggi un quiz alle 22:00 e alle 22:01 lo vedono corretto tutti.
Ogni cliente ha quindi due tipi di corsi:

| | Corsi **propri** | Corsi **in licenza** |
|---|---|---|
| Chi li modifica | lui | nessuno (solo il proprietario) |
| Aggiornamenti | li fa lui | li riceve automaticamente |
| Scadenza | — | data per data, per singolo cliente |

Serve una copia modificabile? **⧉ Duplica** il corso nel cliente: da quel momento
è suo e non riceve più gli aggiornamenti dell'originale (il pulsante lo dice).

### Livello Scuola: Cliente → Scuola → Classe
Le classi non sono più sciolte: appartengono a un **istituto**, che può essere
**ospite** (invitato dal cliente) o **pagante** (licenza propria con date).

### Licenze a tre livelli
Una lezione si apre se: **account cliente attivo** *e* **corso in licenza valida**
*e* **scuola entro le sue date**. Se cade solo la scuola, il messaggio lo dice
(«IC Scaduto: la licenza è scaduta») e il resto del cliente continua a funzionare.

### Mascotte per corso
Non più legata al vecchio «progetto»: ogni corso ha la sua (Coccio per la salina,
un'altra per un museo). Un cliente nuovo non eredita più Coccio per sbaglio.

---

## 2. Deploy

### 2.1 Supabase — UN FILE SOLO
Apri **`migrazione_completa.sql`** nell'SQL Editor, incolla tutto, **Run**.
Contiene 19 → 19b → 20 → … → 28 in ordine, costruito e collaudato su una
replica esatta dello schema di produzione (esportato il 23/09/2026):
tre esecuzioni consecutive pulite, dati travasati (date degli eventi, classi,
istituti), viste vecchie intatte, RPC del player e permessi verificati.
- È **idempotente**: le parti già applicate (19, 19b) non fanno nulla.
- Supabase lo esegue **in un blocco unico**: o passa tutto o non cambia nulla.
- Se dà errore: fermati e mandami il messaggio con il numero di riga.
Poi il controllo di sempre:
```sql
select u.email, e.ruolo, e.cliente_id
from edu_utenti e join auth.users u on u.id = e.id;
```
(la tua Gmail deve essere `admin`).
I singoli file `migrazione_NN.sql` restano nello zip solo come documentazione.

### 2.2 FTP
Carica la cartella `app/` intera in `/project/edu/app/` (sovrascrive).
Se non l'hai già fatto: `.htaccess` in `/project/edu/` da `htaccess-project-edu.txt`.
Poi **cancella `app/dati/cache_*.json`**.

### 2.3 Verifiche
1. `app/api.php?ver` → «api.php v5 (catalogo + scuole…)»
2. `app/debug500.php?k=salina` → tutto ✓
3. Regia → badge **v16 · catalogo**; in sidebar compaiono 🏫 Scuole e classi
4. `/project/edu/salina-culcasi/` → il menu carica

### 2.4 Primo giro di lavoro in regia
1. **🏢 Clienti** → controlla Salina Culcasi (account attivo).
2. **🏫 Scuole e classi** → rinomina «Da assegnare» o crea gli istituti veri;
   dentro ogni scuola crea le classi e copia il link per la maestra.
3. **📚 Corsi** → «Il viaggio di una goccia»: metti **Condivisibile = sì** se
   vuoi poterlo concedere ad altri clienti; imposta la mascotte del corso.
4. **🎞️ Catalogo** (dall'editor del corso, «Chi può usarlo…») → concedi il corso
   ai clienti, con le date.

---

## 3. Relazione dei test

### 3.1 Funzionali — tutti superati
| Area | Verifiche | Esito |
|---|---|---|
| Migrazioni 19→27 su PostgreSQL 16 | applicate due volte (idempotenza) | ✓ |
| Catalogo | stesso corso in 2 clienti, **1 sola riga nel DB**; revoca isolata | ✓ |
| Licenza corso scaduta | sparisce solo per quel cliente, lezione negata | ✓ |
| Licenza scuola | classe di istituto scaduto bloccata, le altre no | ✓ |
| Duplicazione corso | lezioni, media, audio e quiz copiati; originale intatto | ✓ |
| Permessi contenuti | il licenziatario **legge ma non modifica**; la sua copia sì | ✓ |
| Regia v16 (jsdom) | 19 verifiche: scuole, catalogo, duplica, mascotte, statistiche | 19/19 |
| Player (jsdom) | 11 verifiche: corsi propri/licenza, mascotte corso, prologo, audio, licenza scuola | 11/11 |
| Player, suite storica | 50 verifiche (Fasi 2-4) | 50/50 |
| Audio di clip (migr. 25) | 10 player + 7 regia | 17/17 |
| API v5 end-to-end | menu e lezione con codice classe, cifratura, cache | ✓ |

### 3.2 Sicurezza — due falle trovate e chiuse
**Trovato:** il ruolo *anon* (la chiave pubblica che vive nel browser di chiunque
apra il player) **poteva leggere `edu_eventi`**, cioè i dati d'uso di tutte le
classi di tutti i clienti. **Chiuso** (migr. 27): anon non legge più nessuna
tabella, passa solo dalle RPC a privilegio definito.

**Trovato:** `esc()` nella regia non proteggeva apici e virgolette. Una scuola
chiamata `5ª A');alert(1);('` avrebbe eseguito codice nella regia di chi la apre
(XSS da editor dello stesso cliente). **Chiuso**: escape completo — test con
payload reali 5/5.

**Aggiunto:** limite di richieste **per indirizzo IP** su `api.php` e `live.php`.
Quello precedente era per sessione e si aggirava non mandando il cookie. Provato:
20 stanze create, le successive bloccate con messaggio comprensibile, mentre le
richieste normali continuano a passare (le classi in corso non si fermano mai).

**Verificato negativo** (tutti respinti, da anon): creare clienti falsi,
regalarsi licenze nel catalogo, creare lezioni, promuoversi ad admin, cancellare
eventi, leggere le richieste altrui. Permessi solo i due inserimenti legittimi:
evento di tracciamento e richiesta dalla pagina pubblica.

### 3.3 Velocità — carico di prova: 33 clienti, 64 corsi, 245 lezioni, 274 classi, 55.600 eventi
| Operazione | Tempo |
|---|---|
| Menu del cliente (`edu_get_corsi`) | **1,9–4,2 ms** |
| Apertura lezione (`edu_get_lezione_tenant`) | **3,3 ms** |
| Controllo licenza scuola (`edu_classe_stato`) | **0,7 ms** |
| Dashboard statistiche | **201 ms → 13 ms** dopo gli indici (migr. 27) |
| Peso pagine | index 78 KB · regia 112 KB · rispondi 16 KB · attiva 7 KB |
| Render lato server | < 1 ms per pagina |

*Consiglio*: attivare la compressione gzip su Aruba (`.htaccess`) porta l'index
da 78 KB a circa 20 KB sulla rete della scuola.

### 3.4 UX — correzioni applicate
**Player (LIM).** La barra docente ha 7 pulsanti: su portatili 13" con proiettore
le etichette dei comandi secondari (Aa, CC, libro, Quiz live) ora spariscono
prima, così **Pausa** e **Lezioni** restano sempre leggibili; la barra non va mai
a capo e scorre se serve.

**Dispositivo alunno.** Aggiunto il caso **telefono in orizzontale** (capita
spesso in classe): card compatta, risposte su due colonne, tutto sopra la piega.
Rispettate le aree sicure di notch e barre di sistema. **Vibrazione** breve alla
risposta e all'esito (due colpi se giusto). «Tempo scaduto» diventa **«Risposte
chiuse»**: era la maestra a chiudere, non un timer — il messaggio precedente
confondeva.

**Regia.** Con nove pannelli serviva onestà: su schermi sotto 820 px compare un
avviso che spiega cosa conviene fare da telefono (statistiche e link classi) e
cosa no (editor 360, playlist); le tabelle diventano scorrevoli invece di
sfondare la pagina. Aggiunto il **filtro della sidebar** — con dieci clienti la
colonna diventava infinita.

---

## 4. Cosa resta in coda
- Piano **docente singolo**: lo schema lo regge già (un docente è un cliente con
  i suoi corsi più quelli del catalogo); mancano registrazione autonoma, limiti
  del piano e pagamento.
- Notifica e-mail delle richieste di attivazione, informativa privacy sul modulo
  pubblico, area docente semplificata, esportazione dei report.
- Sostituire i `prompt()` della regia con finestre proprie.


---

## 5. Audit del 17/09 — sette problemi trovati e corretti
Revisione da zero del pacchetto consegnato: lint di tutto, grafo delle chiamate
HTML→JS (nessun pulsante orfano), replay delle migrazioni 19→27 su un database
vergine pre-SaaS (pulito), controlli mirati su DB e codice.

| # | Problema | Gravità | Correzione |
|---|---|---|---|
| 1 | I corsi nel menu erano ordinati come **testo**: ordine 10 → 100 → 20 → 5 | media | `edu_get_corsi` ordina per numero |
| 2 | Le lezioni di un corso «**prossimamente**» erano servite dall'API se richieste direttamente (il player le nascondeva, l'API no) | media | `edu_get_lezione_tenant` serve solo da corsi **pubblicati** |
| 3 | Funzione residua `cliente_id_dummy` lasciata nel DB dalla duplicazione | bassa | rimossa, ciclo riscritto |
| 4 | Cliente **senza corsi pubblicati**: il player restava su «Carico le lezioni…» per sempre | media | messaggio «Nessun corso disponibile al momento» |
| 5 | **Editor senza corsi** che crea una lezione: errore RLS incomprensibile | media | blocco con «Prima crea un corso» (l'admin resta libero) |
| 6 | **Slug riservati** (`app`, `ver7`, `api`…) accettati come nome cliente: un cliente «app» sarebbe stato irraggiungibile | media | validazione in creazione e modifica; auto-prefisso `c-` |
| 7 | Limite per IP del quiz live a 1200/min: **due classi della stessa scuola** (stesso IP) che giocano insieme sarebbero state bloccate | **alta** | il polling ha un limite proprio (9000/min); provato con 1300 richieste consecutive → mai bloccato |

Riverificato dopo le correzioni: regia 19/19 + 5/5 (nuovi casi), player 11/11
+ 50/50, audio 17/17, XSS 5/5, migrazioni 19→27 da zero, sincronia delle due
varianti della regia (differiscono solo nelle 2 righe di configurazione).

### Note aperte (non bug, decisioni da prendere)
- Il **docente** vede le statistiche di tutto il cliente, non solo della propria
  scuola: con il livello Scuola ha senso restringerlo (va deciso).
- La **mascotte per corso** copre nome/immagine/fasce; i **video** della
  mascotte restano legati al vecchio progetto → un cliente nuovo ha Coccio muto.
  Serve un editor mascotte per corso (Fase 5).
- Il percorso **legacy** di api.php (`edu_get_lezioni` per progetto) esiste solo
  in produzione: non è riproducibile in sandbox, va provato su Aruba.
- I `prompt()` della regia restano (funzionano, ma andrebbero sostituiti).


---

## 6. Aggiornamento 17/09 (pomeriggio) — stress test e mascotte per corso

### Stress test del Quiz Live (PHP con 8 worker, tutto dallo stesso IP)
| Scenario | Esito |
|---|---|
| 1 classe da 30 | 0 errori · p50 1,3 ms · p95 28 ms |
| 3 classi da 30 in contemporanea | 0 errori · p95 74 ms |
| 5 classi da 30 (istituto intero) | 0 errori · p95 98 ms |
| aula magna: 150 telefoni in UNA stanza | 0 errori · p95 198 ms |
| **500 alunni** in 10 stanze | **0 errori** · p50 8 ms · p95 0,6 s · p99 0,9 s |

Due limiti che avevo tarato troppo stretti sono emersi e sono stati corretti:
il tetto di **60 giocatori per stanza** (ora 200) e gli **ingressi per IP**
(120 ogni 5 minuti: in aula magna i telefoni escono tutti dallo stesso IP
della scuola; ora 500). I limiti anti-abuso sono ora **per tipo di azione**:
polling 20.000/min, risposte 6.000/min, comandi del docente 1.200/min,
creazione stanze 20 ogni 10 minuti. Script: `stress-live.js N stanze secondi`.

### Mascotte per corso (migr. 28 + regia v16.1 + player)
Ogni corso ha la sua mascotte completa: nome, immagine, fasce, video dei
5 momenti × 3 fasce, direttamente nell'**editor del corso**, con «Importa da
progetto» per prendere Coccio in un click. Il player la applica alla scelta
del corso (cambia corso = cambia personaggio). La migrazione 28 travasa da sola
le mascotte dei progetti esistenti nei corsi collegati, escludendo i video
disattivati. Test: 11/11 (player + regia). Nell'ordine delle migrazioni la 28
va DOPO la 27.

### Statistiche
Restano **per cliente** (azienda, scuola o singolo docente che sia): il livello
Scuola serve al cliente che ospita più istituti, non cambia chi vede cosa.


---

## 7. Deploy del 23/09 — errore sulla 20 e correzione
Su Supabase la 20 si è fermata con `column "creato_il" does not exist`: in
produzione `edu_eventi` ha la data con un altro nome ed `edu_classi` esiste già
dall'agosto 2026 con colonne diverse (istituto, comune, livello). Nella sandbox
non era riproducibile. Correzione:
- **migrazione_19b_allineamento.sql** (da eseguire dopo la 19, prima della 20):
  aggiunge le colonne mancanti e travasa i dati (la data degli eventi da quella
  esistente, il nome della classe dall'istituto), lascia intatte le colonne e
  le viste vecchie.
- **migrazione 26**: le classi nate prima del SaaS ricevono il cliente dal loro
  progetto (o dagli eventi) prima di finire nella scuola «Da assegnare».
Verificato su una replica della produzione: catena 19→19b→20…28 pulita, date
originali conservate, vista `edu_v_report_istituti` intatta, statistiche e
inserimento classi dalla regia funzionanti, anon senza lettura.


---

## 8. Deploy del 23/09 (sera) — schema reale e file unico
Con lo schema esportato dalla produzione sono emerse tre differenze rispetto
alla base su cui avevo testato: `edu_utenti` senza `email` e senza `cliente_id`
(la 20 non era mai passata: Supabase annulla tutto il file al primo errore),
nome/immagine della mascotte in `edu_progetti` e non in `edu_mascotte`,
`edu_classi` con `anno_scolastico`. Correzioni: colonna dei corsi nata come
`proprietario_id` fin dalla 20 (la rinomina della 26 è un passaggio a vuoto),
blocco mascotte della 26 rimosso (lo fa la 28), 19b travasa anche `anno`,
regia senza dipendenza da `edu_utenti.email`. Tutto raccolto in
**migrazione_completa.sql**, provato tre volte di fila sulla replica.
# ESPLORA TRAPANI EDU — AUDIT FASE 1 · 24/09/2026
## Riesame generale, correzione dei flussi, revisione RLS

**Metodo.** Non avendo un tool per far girare agenti separati, ho lavorato da
orchestratore: inventario dei componenti dalla documentazione, poi **sei tracce
di audit** eseguite una per una, ognuna con la propria suite automatica, i
reperti e i fix. Tutto è ripetibile: gli script sono nello zip.

| Traccia | Cosa verifica | Come | Esito |
|---|---|---|---|
| A · RLS e dati | inventario policy, sovrapposizioni, limitazioni, matrice ruoli×tabelle×operazioni | Postgres su replica esatta di produzione | **4 reperti** → migr. 29 · matrice 15 tabelle × 5 ruoli conforme |
| B · Nuovo tenant | dalla richiesta pubblica alla classe che produce statistiche | DB con ruoli reali (24 passi) + regia jsdom (13 passi) | 37/37 |
| C · Player e API | sessione, cifratura, referer, licenza, tenant, cache, protezione dati/ | Apache reale + mod_rewrite | 15/15 |
| D · Quiz Live | PIN, token host, anti-cheat, ripensamenti, range, fine, chiusura | HTTP sull'app | 16/16 |
| E · Grafica e accessibilità | id duplicati, etichette, contrasti WCAG, viewport, lingua | analisi DOM/CSS | **4 reperti** corretti |
| F · Qualità del codice | ogni funzione chiamata deve esistere; lint; sincronia php/html | analisi statica | 0 chiamate non risolte |

Non-regressione finale: regia 33+19+13+11+5+4+5, player 50+11, audio 17, API 15,
live 16, statica 5 file — **tutto verde**.

---

## Traccia A — RLS: reperti e correzioni (migrazione 29)

1. **Quattro tabelle senza RLS e aperte ad anon** per default Supabase:
   `edu_mascotte`, `edu_messaggi`, `edu_progetti`, `edu_versioni`.
   `edu_messaggi` sono i messaggi mostrati in classe: chiunque con la chiave
   pubblica poteva scriverli. **Grave.** Ora RLS attiva: lettura ai ruoli della
   regia, scrittura solo admin/editor, anon escluso.
2. **Sovrapposizioni**: due policy INSERT anon su `edu_eventi` (la legacy di
   agosto accettava qualsiasi `tipo`; in OR vince la più permissiva), due SELECT
   su `edu_utenti`. In produzione i nomi delle policy legacy non sono noti:
   la 29 **elimina tutte le policy delle tabelle `edu_`** (qualunque nome) e
   ricrea il set canonico — una sola policy per (ruolo, operazione), verificata
   da un controllo finale che fallisce se trova doppioni.
3. **Limitazioni sbagliate**: un **docente** poteva creare/cancellare scuole e
   classi altrui del suo cliente. Ora: scuole = lettura per il tenant, scrittura
   editor/admin; classi = il docente gestisce solo le proprie (`docente_id`).
   In più l'editor ora vede i colleghi del suo cliente (prima solo sé stesso).
4. Grant residui: INSERT anon su `edu_utenti`, SELECT/INSERT anon sulle 4
   tabelle del punto 1 → revocati. Anon ha solo INSERT su eventi e richieste.

**Matrice eseguita** (t_rls_matrice.sql): anon legge 0 righe ovunque e scrive
solo eventi con tipo valido e richieste; il docente legge il suo cliente e non
scrive scuole/lezioni/messaggi né promuove utenti; l'editor scrive solo il
proprio, concede in licenza solo i propri corsi, non tocca lezioni altrui;
l'admin tutto. Nessuno scostamento dall'atteso.

---

## Traccia B — Flusso «nuovo tenant» (verificato due volte)
DB con ruoli reali: admin crea cliente (piano base) → editor assegnato → corso in
bozza → licenza propria → lezione con media/audio/tappa/hotspot/quiz → in bozza
NON servita al player → pubblicata: menu con 1 corso, 1 lezione, mascotte del
corso → piano base: 1 corso pubblicato, niente live → scuola + classe → classe
valida; scuola scaduta → gate → eventi della classe → statistiche dell'editor
(100%, Plesso Centro) → la salina non vede nulla del nuovo cliente → la salina
concede la goccia: il nuovo cliente la vede ma non la modifica, il player mostra
2 corsi (proprio + in licenza con scadenza).
Regia (jsdom, nella sequenza reale dell'admin): richiesta pubblica → «Crea
cliente» → piano/scadenza → utente editor → corso → mascotte → pubblicazione →
2° corso bloccato dal piano → lezione nel corso → scuola → classe con codice e
link → catalogo → statistiche. 13/13.

---

## Traccia E — Grafica e accessibilità: reperti corretti
1. **`id="classiList"` duplicato** nella regia (pannello morto della Fase 4 +
   pannello Scuole): `getElementById` prende il primo — funzionava per l'ordine
   nel file. Pannello morto rimosso con la sua funzione.
2. **Pulsanti oro con testo bianco: contrasto 2,4:1** (AA richiede 4,5) — i
   «Ho capito!» del player e i pulsanti `.btn.oro` della regia. Ora testo ink su
   oro: 5,4:1. Kicker oro di attiva.php (2,25) → oro scuro 5,0:1.
3. Cursori del video (player e regia) senza etichetta → `aria-label`.
4. Honeypot di attiva.php nascosto agli screen reader.
Palette verificata: ink/sale 12,3 · rosa-testo/bianco 4,8 · bianco/rosa2 4,8 ·
grigio hint 6,0 · bianco/verde 5,3. Rosa-testo su sale = 4,47 (al limite AA:
usato solo per titoli grandi, dove basta 3).

**Limite dichiarato**: nella sandbox non c'è un browser con rendering grafico;
l'audit visivo è meccanico (DOM/CSS). Layout, allineamenti e resa su LIM,
telefono e visore restano da guardare a occhio: uno screenshot per pagina.

---

## Deploy della Fase 1
1. Supabase → SQL Editor → **`migrazione_29_rls_consolidata.sql`** → Run
   (idempotente; provata 2× sulla replica). Poi, per conferma:
   `select tablename, count(*) from pg_policies where tablename like 'edu_%' group by 1;`
   → ogni tabella con 2 policy (edu_lezioni 4).
2. Aruba → sostituire in `/project/edu/app/`: `regia-edu.php`, `regia-edu.html`
   (v16.3 · audit), `index.php`, `attiva.php`. Cancellare `dati/cache_*.json`.
3. Verifica: regia → badge **v16.3 · audit**; player → i pulsanti «Ho capito!»
   hanno il testo scuro.

---

## Fase 2 — Stripe: dove si aggancia (già predisposto)
- **Cosa si vende**: la licenza del cliente (`edu_clienti.piano`,
  `licenza_stato`, `licenza_fine`) e/o l'accesso a un corso del catalogo
  (`edu_catalogo.stato/da/a`). Entrambe sono già le uniche fonti di verità
  lette dal player: un pagamento deve solo scriverci.
- **Flusso previsto**: `attiva.php` → Stripe Checkout (prezzo per piano) →
  **webhook** (`checkout.session.completed`) su un endpoint PHP nella cartella
  app (`stripe-webhook.php`, con firma verificata) → RPC `edu_attiva_licenza`
  (SECURITY DEFINER, solo chiave service) che crea il cliente se non esiste,
  imposta piano e date, registra la transazione in una tabella `edu_pagamenti`
  (id Stripe, importo, cliente, periodo, stato). Rinnovi: `invoice.paid` →
  proroga `licenza_fine`. Scadenze: già gestite dal gate (nulla da fare).
- **Da decidere prima**: prezzi per piano e per corso, IVA/fatturazione
  (Stripe Tax o fattura esterna), chi può comprare (solo admin del cliente?),
  periodo (anno scolastico vs 12 mesi), e se il piano docente singolo entra
  subito.
