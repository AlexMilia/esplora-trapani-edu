# Test di Esplora Trapani Edu

Tutti i test girano **senza toccare la produzione**: niente Supabase vero, niente Stripe vero.
Prerequisiti: `node` ≥ 18, `php-cli` **con estensione curl**, `postgresql` ≥ 14 (solo per i test DB).

```bash
npm install                 # una volta: installa jsdom
npm test                    # player + regia + analisi statica (17 suite, 300 verifiche)
bash test/t_api26.sh        # api.php offline (cache precompilata, server PHP integrato)
bash test/t_didattica_api.sh # esiti, diario, compiti su un Supabase finto (30 verifiche)
bash test/t_live_gc.sh      # le stanze del quiz live spariscono dopo 3 ore (privacy dichiarata)
bash test/t_scheda.sh       # scheda alunno standard e adattata, contenuto + stampa A4 (39 verifiche)
bash test/t_tenant.sh       # da quale indirizzo il player capisce quale scuola sta aprendo (13 verifiche)
bash test/t_mappa_browser.sh # la mappa dei corsi in Chromium vero: mouse, dito, telefono (26 verifiche; chiede Playwright)
bash test/t_stripe_avvia.sh # stripe.php + webhook + setup contro Stripe/Supabase finti (28 verifiche)
DBURL=postgresql://utente:password@127.0.0.1/edu_test bash test/db_avvia.sh   # migrazioni + RLS + flussi (vedi sotto)
```

## Cosa fa ogni suite

| Suite | Comando | Cosa verifica |
|---|---|---|
| Player (jsdom) | `test-profondo.js`, `t_player26.js`, `t_audio.js`, `t_mascotte.js`, `t_audit.js`, `t_didattica_player.js` | menu, prologo, licenze (cliente e scuola), accessibilità, quiz, audio di sottofondo, mascotte del corso; comandi ⏪10s/⏩10s e lezione precedente/successiva, scheda didattica (📋), percorso della classe nel menu, esito salvato a fine quiz e dopo il quiz live. Leggono `index.php` **renderizzato**: `rendi-player.sh` lo produce in `/tmp/pag*.html` con il server PHP integrato e `config.example.php` |
| Regia (jsdom) | `test-regia.js`, `test-regia26.js`, `t_flusso_regia.js`, `t_viewer.js`, `t_sec_xss.js`, `t_regia_audio.js`, `t_regia_abbonamenti.js`, `t_didattica_regia.js` | tutti i pannelli con Supabase mockato (fixture `window.__fx`, `from()` concatenabile con `then`, `rpc()`), viewer video, XSS, Stripe lato UI, catalogo (destinazioni dalla rpc `edu_elenco_clienti`), didattica di corso e lezione, pannello esiti con filtri, CSV (punto e virgola, virgolette, segno di ordine dei byte) e scheda stampabile, compiti con i loro controlli |
| Statica | `t_statica.js` | ogni funzione chiamata negli script deve essere definita (è il controllo che avrebbe scovato `vidStato`). I nomi protetti da `typeof nome` non vengono segnalati |
| API | `t_api26.sh` | sessione, cifratura AES della risposta, token `X-EDU-T`, referer, cache per giorno — offline |
| API didattica | `t_didattica_api.sh` | azioni `esito`, `diario`, `compito`, `consegna` contro `mock/supa-edu-mock.php`: validazioni, normalizzazione del codice classe, licenza di scuola scaduta, dettaglio gonfiato, **risposte giuste che non lasciano il server**, e la prova che api.php usa solo la anon key |
| Stripe | `t_stripe_avvia.sh` → `t_stripe.sh` | crea/pausa/riprendi/annulla, idempotency key, chiave service mai sostituita dal token utente, webhook (firma, replay, eventi estranei), setup prezzi |
| DB | `db_avvia.sh` | ricrea `edu_test` da `migrazioni/replica.sql` (replica dello schema di produzione), applica `migrazione_completa.sql` **due volte** (idempotenza), carica `fixture_test.sql`, poi `t_rls_matrice.sql` (ruoli × tabelle × operazioni: deve stampare zero scostamenti), `t_flusso_tenant.sql` (nuovo tenant end-to-end con RLS attiva), `t_abbonamenti.sql` (ciclo di vita dell'abbonamento via eventi), `t_didattica.sql` (esiti, diario, compiti e permessi della migrazione 32), `t_schede_seed.sql` (migrazione 33: i testi delle schede entrano nelle lezioni senza sovrascrivere il lavoro fatto in regia), `t_sicurezza.sql` (migrazione 34: quello che la chiave pubblica NON può fare — viste, funzioni riservate, eventi storti, richieste manomesse; la replica riproduce i privilegi di default di Supabase, e senza la 34 queste verifiche sono rosse) |
| Live | `t_live_flussi.sh`, `stress-live.js N stanze secondi` | casi limite del quiz live e carico (500 alunni) |
| Riga nera della sfera | `t_bordi.js` | il componente `bordi-puliti`: i video Bunny hanno le due colonne di bordo scurite dal ridimensionamento e sulla sfera si toccano, disegnando una riga verticale. Il test esegue davvero la logica del componente con un three finto: bordo calcolato sulla larghezza vera del video (si riadatta quando HLS cambia risoluzione), shader compilato una sola volta, `clamp` sulla coordinata orizzontale e **solo** su quella, e i casi in cui il video non è ancora pronto. Verifica anche che l'attributo sia rimasto sulla `<a-videosphere>`: la correzione era già stata scritta per ver8 e si era persa nel passaggio alla repository |
| Clip tagliata | `t_clip.js` | player v2.9: una clip parte da `inizio_s` e si chiude a `fine_s`, la voce a parte resta agganciata al video, i sottotitoli arrivano da un file `.vtt` con i tempi della voce; le lezioni senza tagli si comportano come prima |
| Corso con la mappa | `t_mappa.js` | segnaposto e elenco, mouse (passa sopra / clic) e dito (primo tocco ingrandisce, secondo apre), inquadratura sui soli punti presenti, stati dal diario, modalità ipovedenti senza mappa, ritorno all'elenco se Leaflet non si carica, testi ostili. Leaflet è finto |
| Corso con la mappa, browser vero | `t_mappa_browser.sh` | **Prova in un browser vero**: Chromium con Playwright disegna la mappa a 1366×768, su LIM con tocco e su telefono. Fuori da `npm test` perché chiede Playwright; se manca, salta |
| Area Trapani | `t_area_trapani.sql` | migrazioni 35 e 36 viste dal ruolo `anon`: il corso compare al tenant vetrina e non a chi non ha la licenza, ogni clip ha taglio/voce/sottotitoli, ogni fermata cade nel pezzo di video che si vede, nessun testo nomina l'evento, rilanciare la 36 non tocca le correzioni |
| Quale scuola sta aprendo | `t_tenant.sh` | il player deduce il tenant da `?c=`, da `/edu/{slug}/` o dal default del config. Il test prova che una **cartella di lavoro** (`/edu/definitiva/index.php`, `/edu/ver8/…`, una cartella mai vista) non viene scambiata per una scuola: un indirizzo che chiama un file `.php` per nome non è un tenant. Era il motivo per cui le schede rispondevano «licenza del cliente non attiva» mentre il player sembrava funzionare |
| Bussola del player | `t_bussola.js` | il punto che brilla fuori dallo schermo: soglia calcolata sul campo visivo vero (LIM, tablet e telefono in verticale danno numeri diversi), verso più corto per girare, freccia sul bordo, giro automatico della scena dopo l'attesa, precedenza al dito di chi trascina, e dati storti dalla regia che non devono mandare la scena chissà dove |
| Privacy del live | `t_live_gc.sh` | le stanze con i soprannomi degli alunni vengono davvero cancellate dopo 3 ore (è ciò che l'informativa alle famiglie dichiara), e le partite in corso non vengono toccate |
| Schede da stampare | `t_scheda.sh` | `scheda.php` contro `mock/supa-edu-mock.php`: contenuto preso dai dati della lezione, fasi mescolate ma **stabili fra una stampa e l'altra**, livelli primaria/medie, le dieci pagine dell'adattata (comprese le due carte del ruolo nel quiz, LIM e telefoni), i ripieghi quando la lezione è incompleta, e la sicurezza (nessuna chiave nella pagina, `noindex`, solo anon key, nome della scuola nell'indirizzo che non inietta codice). Le ultime due verifiche stampano davvero con Playwright e contano le pagine del PDF: 2 per la standard, 10 per l'adattata |

## Test che richiedono Apache

`t_api_flussi.sh` e `t_live_flussi.sh` provano **anche** l'`.htaccess` (riscrittura `/edu/{slug}/`, 301 sulla barra finale, `dati/` negata dal web):
servono Apache con `mod_rewrite` + `mod_php` e l'app copiata in `/var/www/html/project/edu/` (percorsi scritti nei file: adattali se la tua macchina è diversa). Non sono inclusi in `npm test`.

## Regole (pagate care)

- **Mai stubbare una funzione dell'app** per far passare un test: se non esiste in jsdom, non esiste nel browser.
- Una correzione che vive solo su una cartella del server (`mestieri/ver8/`) **non esiste**: prima o poi una
  versione nuova la sovrascrive e il difetto torna. Quando ne recuperi una, portala in `app/` **con un test**.
- I test SQL girano sulla **replica**, mai sul progetto Supabase vero (che è condiviso con ASK Trapani).
- `fixture_test.sql` esiste perché la replica rispecchia la produzione (dove `2222…` è un admin) mentre i test vogliono un editor della Salina e un secondo cliente licenziatario: non va mai applicata in produzione.
- Quando Supabase stampa un errore su una migrazione, **tutto il file è stato annullato**: correggi e rilancia da capo.
- I test del player leggono `/tmp/pag.html`: dopo una modifica a `app/index.php` rigenerala con `bash test/rendi-player.sh`, altrimenti stai provando la pagina di prima (`npm test` lo fa da sé).
- `app/index.php` ha fine-riga **CRLF**, la regia **LF**: chi modifica con script automatici deve tenerne conto.
- Le variabili dichiarate con `let` dentro la pagina non sono proprietà di `window`: in jsdom si cambiano solo iniettando uno `<script>`, non con `w.NOME=...`.
- In uno stesso `select`, una sotto-select non vede le scritture fatte da una funzione chiamata nella stessa istruzione (snapshot): applica l'evento in un'istruzione e leggi lo stato in quella dopo (vedi `t_abbonamenti.sql`).
