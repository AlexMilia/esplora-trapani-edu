# Test di Esplora Trapani Edu

Tutti i test girano **senza toccare la produzione**: niente Supabase vero, niente Stripe vero.
Prerequisiti: `node` ≥ 18, `php-cli` **con estensione curl**, `postgresql` ≥ 14 (solo per i test DB).

```bash
npm install                 # una volta: installa jsdom
npm test                    # player + regia + analisi statica (13 suite, ~180 verifiche)
bash test/t_api26.sh        # api.php offline (cache precompilata, server PHP integrato)
bash test/t_stripe_avvia.sh # stripe.php + webhook + setup contro Stripe/Supabase finti (28 verifiche)
DBURL=postgresql://utente:password@127.0.0.1/edu_test bash test/db_avvia.sh   # migrazioni + RLS + flussi (vedi sotto)
```

## Cosa fa ogni suite

| Suite | Comando | Cosa verifica |
|---|---|---|
| Player (jsdom) | `test-profondo.js`, `t_player26.js`, `t_audio.js`, `t_mascotte.js`, `t_audit.js` | menu, prologo, licenze (cliente e scuola), accessibilità, quiz, audio di sottofondo, mascotte del corso. Leggono `index.php` **renderizzato**: `rendi-player.sh` lo produce in `/tmp/pag*.html` con il server PHP integrato e `config.example.php` |
| Regia (jsdom) | `test-regia.js`, `test-regia26.js`, `t_flusso_regia.js`, `t_viewer.js`, `t_sec_xss.js`, `t_regia_audio.js`, `t_regia_abbonamenti.js` | tutti i pannelli con Supabase mockato (fixture `window.__fx`, `from()` concatenabile con `then`, `rpc()`), viewer video, XSS, Stripe lato UI, catalogo (destinazioni dalla rpc `edu_elenco_clienti`) |
| Statica | `t_statica.js` | ogni funzione chiamata negli script deve essere definita (è il controllo che avrebbe scovato `vidStato`). I nomi protetti da `typeof nome` non vengono segnalati |
| API | `t_api26.sh` | sessione, cifratura AES della risposta, token `X-EDU-T`, referer, cache per giorno — offline |
| Stripe | `t_stripe_avvia.sh` → `t_stripe.sh` | crea/pausa/riprendi/annulla, idempotency key, chiave service mai sostituita dal token utente, webhook (firma, replay, eventi estranei), setup prezzi |
| DB | `db_avvia.sh` | ricrea `edu_test` da `migrazioni/replica.sql` (replica dello schema di produzione), applica `migrazione_completa.sql` **due volte** (idempotenza), carica `fixture_test.sql`, poi `t_rls_matrice.sql` (ruoli × tabelle × operazioni: deve stampare zero scostamenti), `t_flusso_tenant.sql` (nuovo tenant end-to-end con RLS attiva), `t_abbonamenti.sql` (ciclo di vita dell'abbonamento via eventi) |
| Live | `t_live_flussi.sh`, `stress-live.js N stanze secondi` | casi limite del quiz live e carico (500 alunni) |

## Test che richiedono Apache

`t_api_flussi.sh` e `t_live_flussi.sh` provano **anche** l'`.htaccess` (riscrittura `/edu/{slug}/`, 301 sulla barra finale, `dati/` negata dal web):
servono Apache con `mod_rewrite` + `mod_php` e l'app copiata in `/var/www/html/project/edu/` (percorsi scritti nei file: adattali se la tua macchina è diversa). Non sono inclusi in `npm test`.

## Regole (pagate care)

- **Mai stubbare una funzione dell'app** per far passare un test: se non esiste in jsdom, non esiste nel browser.
- I test SQL girano sulla **replica**, mai sul progetto Supabase vero (che è condiviso con ASK Trapani).
- `fixture_test.sql` esiste perché la replica rispecchia la produzione (dove `2222…` è un admin) mentre i test vogliono un editor della Salina e un secondo cliente licenziatario: non va mai applicata in produzione.
- Quando Supabase stampa un errore su una migrazione, **tutto il file è stato annullato**: correggi e rilancia da capo.
- In uno stesso `select`, una sotto-select non vede le scritture fatte da una funzione chiamata nella stessa istruzione (snapshot): applica l'evento in un'istruzione e leggi lo stato in quella dopo (vedi `t_abbonamenti.sql`).
