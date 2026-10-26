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
