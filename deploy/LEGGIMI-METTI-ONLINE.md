# Metti online — Esplora Trapani Edu

Questo pacchetto contiene tutto quello che serve a portare online la versione completa
(player v2.5, regia v18, schede stampabili, blocco didattico). Sono tre passi, in
quest'ordine: **prima il database, poi i file, poi i controlli**. Fatti in un altro
ordine il sito resta rotto per il tempo che ci metti.

Tempo: 20 minuti, più i controlli.

---

## 0 · Prima di cominciare

- Fai una **copia di sicurezza** di `/project/edu/app/` dal pannello Aruba (File Manager →
  comprimi la cartella). Se qualcosa va storto, rimetti quella.
- Apri `app/dati/config.php` **sul server** e verifica che ci siano queste righe (se
  mancano, copiale da `deploy/righe-da-aggiungere-a-config.txt`):
  `$STRIPE_SECRET`, `$STRIPE_WEBHOOK_SECRET`, `$SUPA_SERVICE`, `$STRIPE_PRICES`.
  **Non toccare quel file per nessun altro motivo: contiene le chiavi segrete e non
  esiste in nessun altro posto.**

## 1 · Database (Supabase → SQL Editor)

1. Apri `migrazioni/migrazione_completa.sql`, copia tutto, incolla, **Run**.
   Contiene le migrazioni 19 → 33 ed è ripetibile: quello che c'è già viene saltato
   con un avviso «già esiste». Se preferisci andare per passi: 29, 30, 31, 32, 33,
   una alla volta, nell'ordine.
2. Leggi i messaggi in fondo. Per la **33** (i testi delle schede dentro le lezioni)
   devi vedere una riga per mestiere: *«scheda riempita»*, *«ha già una scheda,
   lasciata com'è»* oppure *«nessuna lezione in archivio»*. L'ultima non è un errore:
   quella lezione non esiste ancora.
3. Se compare un **ERROR** la migrazione si è fermata lì e non ha scritto nulla
   (Supabase annulla tutto il file al primo errore): copia il messaggio e fermati.

## 2 · File (Aruba → File Manager o FTP)

Carica il contenuto della cartella `edu/` del pacchetto dentro `/project/edu/`,
**sovrascrivendo** i file esistenti. In dettaglio cambiano:

| file | perché |
|---|---|
| `.htaccess` | percorsi tenant (`/edu/salina-culcasi/`) — uguale a prima, lo ricarichi per sicurezza |
| `app/api.php` | v6: esiti, diario, compiti |
| `app/index.php` | player v2.5: bussola, schede, percorso della classe, comandi del video |
| `app/regia-edu.php` + `.html` | v18: didattica, esiti e compiti, scheda da stampare |
| `app/compito.php` | **nuovo** — il compito a casa |
| `app/scheda.php` | **nuovo** — la scheda alunno da stampare |
| `app/live.php` | pulizia certa delle stanze del quiz |
| `app/dati/config.example.php` | solo il modello, aggiornato |

**Non caricare** `app/dati/config.php`: nel pacchetto non c'è apposta.
Se nel File Manager vedi ancora `app/debug500.php` o `app/stripe-setup.php`,
**cancellali**: sono file di servizio e non devono stare online.

Dopo il caricamento, su un terminale con `sha256sum` puoi confrontare le impronte:
`IMPRONTE.txt` nel pacchetto elenca ogni file con la sua impronta.

## 3 · Controlli (5 minuti, dal browser)

Apri in ordine, e per ognuno è scritto che cosa devi vedere:

1. `https://<dominio>/project/edu/salina-culcasi/` → la schermata con i cinque mestieri.
   Scegli «Il salinaio»: il video parte. In alto ci sono **−10s / +10s** e le frecce
   **‹ ›** per cambiare lezione.
2. Nella stessa pagina premi **📋**: si apre la *Scheda della lezione* (obiettivi, prima /
   durante / dopo). Chiudila, premi **🖨️**: si apre la scheda da stampare in una nuova
   scheda, titolo «Il salinaio», «Scheda alunno n. 1 di 5». Stampa → anteprima: **2
   facciate**.
3. Quando il video si ferma sulla tappa, **tocca un punto che brilla**: deve aprirsi la
   *scoperta* (nome dell'oggetto e due righe), **non** la scheda del docente.
4. `…/app/regia-edu.php` → accedi → apri una lezione → pannello **🖨️ Scheda da
   stampare** → *Anteprima adattata*: **10 pagine**. Pannello **🧾 Esiti e compiti**:
   si apre senza errori (vuoto, è normale).
5. `…/app/api.php?action=diag&k=<la tua EDU_DIAG_KEY>` → `"ok":true` e la versione
   `api v6`. Con una chiave sbagliata → 403.
6. Dal telefono, in verticale, apri una lezione e aspetta la prima tappa: se il punto è
   fuori dallo schermo compare la **freccia grande** sul bordo e, dopo pochi secondi, la
   scena gira da sola.

Se un controllo fallisce, la copia di sicurezza del punto 0 rimette tutto com'era in
due minuti; poi mandami lo screenshot dell'errore.

## 4 · Da fare a mano, una volta sola (sicurezza)

Queste non le può fare il pacchetto:

- [ ] Supabase → Authentication → utente `alessandromiliaweb@gmail.com` → attiva la
      **verifica in due passaggi** (MFA). È l'unico account che può tutto.
- [ ] Supabase → Authentication → utente `demo@test.it`: se esiste ancora, **declassalo
      a editor** o cancellalo. Non deve essere admin.
- [ ] `app/dati/config.php` → `$EDU_DIAG_KEY` deve essere una stringa lunga e casuale,
      non il valore d'esempio «CAMBIAMI…».
- [ ] Stripe → Developers → Webhooks: l'endpoint punta a `…/app/stripe-webhook.php` e
      il *Signing secret* è quello in `$STRIPE_WEBHOOK_SECRET`.
- [ ] Verifica che `https://<dominio>/project/edu/app/dati/config.php` risponda
      **403** (la cartella è negata dall'`.htaccess`). Se risponde altro, fermati e
      scrivimi: vuol dire che Apache non legge l'`.htaccess`.

## Che cosa NON è in questo pacchetto

- I **video** restano su Bunny: nulla da caricare.
- I documenti per le scuole (`docs/`) e le schede PDF di esempio non vanno sul server.
- I test e la replica del database servono solo in locale.
