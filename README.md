# Esplora Trapani Edu

Piattaforma educativa in video 360° per le scuole (8–13 anni), multi-cliente, con quiz live su LIM + telefoni,
accessibilità (ipovedenti + LIS), mascotte per corso, catalogo corsi «stile Netflix» e abbonamenti Stripe.
Un prodotto di **Esplora Trapani** (Alessandro Milia, Trapani).

- **Produzione:** `https://www.alessandromilia.it/project/edu/` (Aruba, PHP 8) — un tenant si apre con `/project/edu/{slug}/`
- **Database/Auth:** Supabase, progetto condiviso con ASK Trapani (`sdqzqzmkhbkkibjzauox`): si toccano **solo** gli oggetti `edu_*`
- **Video:** Bunny Stream, libreria `esplora-trapani` (ID 721728) — mai creare librerie nuove
- **Regia:** `app/regia-edu.php` (login Supabase Auth; ruoli `admin` / `editor` / `docente` in `edu_utenti`)

> Chi prende in mano il progetto parte da **`docs/MANUALE-TECNICO-PRESA-IN-CARICO.md`** (architettura, flussi, sicurezza,
> schema, trappole note) e poi da **`docs/LEGGIMI-CATALOGO.md`** (deploy e relazione dei test).

## Struttura della repository

```
app/            codice che va su Aruba in /project/edu/app/
  index.php       player 360° (A-Frame + hls.js), tenant da ?c= o da /edu/{slug}/
  api.php         API del player: menu, lezione, tracking; risposte cifrate AES-256 con chiave di sessione
  live.php        quiz live (stanze su file in dati/live/), live-lim.js (LIM), rispondi.php (telefoni)
  regia-edu.php   regia (identica a regia-edu.html, ma URL/chiave Supabase letti da dati/config.php)
  attiva.php      modulo pubblico «richiedi l'attivazione» → edu_richieste
  stripe.php / stripe-webhook.php / stripe-setup.php   abbonamenti (Fase 2)
  debug500.php    diagnostica di deploy — DA CANCELLARE dal server dopo l'uso
  dati/           config.example.php (modello), .htaccess (nega tutto dal web); a runtime: config.php, cache, log, rl/, live/
deploy/         htaccess-project-edu.txt → va in /project/edu/.htaccess · righe-da-aggiungere-a-config.txt (Stripe)
migrazioni/     migrazione_19 … 31 (singole) · migrazione_completa.sql (tutte insieme, idempotente) · replica.sql (schema di produzione per i test)
test/           tutte le suite + mock Stripe/Supabase + lanciatori (vedi test/LEGGIMI-TEST.md)
docs/           manuale tecnico, architettura, relazioni di deploy/audit, guida audio, manuale quiz live, relazione per la finanza agevolata
demo-vr/        demo offline per Meta Quest (A-Frame locale, video da Bunny o da demo-vr/video/)
```

## Far girare il progetto in locale

```bash
cp app/dati/config.example.php app/dati/config.php      # poi compila i valori CAMBIAMI
php -S 127.0.0.1:8080 -t app                             # player: http://127.0.0.1:8080/index.php?c=salina-culcasi
npm install && npm test                                  # test jsdom (nessun servizio esterno)
bash test/t_api26.sh && bash test/t_stripe_avvia.sh      # API offline e Stripe su mock
DBURL=postgresql://utente:password@127.0.0.1/edu_test bash test/db_avvia.sh   # migrazioni + RLS su replica locale
```

Senza il `config.php` reale (chiavi Supabase) il player si apre ma il menu resta vuoto: è voluto.

## Deploy (riassunto — dettagli in `docs/LEGGIMI-CATALOGO.md`)

1. **Supabase → SQL Editor:** eseguire **solo le migrazioni non ancora applicate** (vedi stato sotto). Supabase esegue il file in blocco: se dà errore non ha cambiato nulla.
2. **FTP (Aruba):** caricare il contenuto di `app/` in `/project/edu/app/` **senza sovrascrivere `dati/config.php`**, e `deploy/htaccess-project-edu.txt` come `/project/edu/.htaccess`. Permessi 644 file / 755 cartelle.
3. Cancellare `app/dati/cache_*.json` sul server dopo ogni migrazione; controllare `api.php?ver` e aprire un tenant.

### Stato di produzione al 26/10/2026

| Pezzo | In produzione | Note |
|---|---|---|
| Migrazioni 19 → 28 | ✅ dal 23/09 | `migrazione_completa.sql` (allora 19→28) |
| Migrazione 29 (RLS consolidata) | ❌ da applicare | Fase 1 audit |
| Migrazione 30 (abbonamenti) + Stripe | ❌ da attivare | Fase 2, passi in `docs/LEGGIMI-FASE2-STRIPE.md` (prima chiavi di test) |
| Migrazione 31 (elenco clienti per il catalogo) | ❌ da applicare | insieme a regia v17.1 (vedi `docs/CHANGELOG.md`) |
| `app/` (api v5, player v2.3, regia v16.2) | ✅ dal 23/09 | regia v17.1 + stripe*.php ancora da caricare |

## Regole di sicurezza (non negoziabili)

- `app/dati/config.php` **non entra mai in git** (è nel `.gitignore`): contiene `SUPA_SERVICE` (service_role), `STRIPE_SECRET`, `STRIPE_WEBHOOK_SECRET`. Vive solo sul server, in una cartella negata dal web.
- La anon key di Supabase è pubblica per costruzione (finisce nel browser): la sicurezza sta nella **RLS** (una policy per ruolo × operazione, migr. 29) e in Supabase Auth.
- `anon` non legge nessuna tabella: solo `INSERT` su `edu_eventi` e `edu_richieste`. Il player passa da `api.php` (token di sessione `X-EDU-T`, referer, throttle per IP, risposte cifrate).
- `stripe-setup.php` e `debug500.php` vanno cancellati dal server dopo l'uso. MFA sull'account admin.
- Mai toccare tabelle del progetto Supabase che non iniziano per `edu_`.

## Documenti

`docs/MANUALE-TECNICO-PRESA-IN-CARICO.md` (+ PDF) · `docs/ARCHITETTURA-EDU-SAAS.md` · `docs/LEGGIMI-CATALOGO.md` ·
`docs/AUDIT-FASE1.md` · `docs/LEGGIMI-FASE2-STRIPE.md` · `docs/GUIDA-AUDIO-GOCCIA.md` · `docs/MANUALE-QUIZ-LIVE.pdf` ·
`docs/CHANGELOG.md` · `docs/relazione/` (relazione di progetto per il progettista di finanza agevolata) · `demo-vr/LEGGIMI-DEMO-VR.md`
