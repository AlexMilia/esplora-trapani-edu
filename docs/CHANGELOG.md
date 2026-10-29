# Registro delle modifiche

## 29/10/2026 (sera) — player v2.4.1: il «?» delle scoperte anche senza rete

- **Trovato provando il pacchetto offline in Chromium con la rete bloccata**: il «?» dentro il cerchio delle
  scoperte era un `<a-text>`, e A-Frame scarica il suo font da `cdn.aframe.io`: senza rete il cerchio
  compariva vuoto (unica richiesta verso internet rimasta nel pacchetto). Ora, in modalità OFFLINE, il «?»
  è disegnato su un canvas e usato come texture di un `a-plane` (`segnoInterrogativo()`, una PNG per colore,
  nero in modalità Ipovedenti). Online non cambia nulla. `test/t_offline.js` lo verifica (26 verifiche).
- Rigenerati `offline/player/index.html` e gli script del pacchetto `esplora-trapani` (`--da-dati`).
- Verifiche fatte: `npm test` 15 suite / 0 errori; player offline servito da `avvia.js` (porta 8765) in
  Chromium headless con le richieste esterne bloccate: menu, vendemmia (9 capitoli, 27 scoperte nell'indice
  ☰), telecomando, PagGiù, →, scoperta aperta con il «?» visibile, zero richieste esterne.
- **Non verificato**: la riproduzione dei video. Da questo ambiente il CDN di Bunny
  (`vz-bedaaab5-085.b-cdn.net`) non è raggiungibile (policy di rete, non il 403 del referer), quindi
  `scarica-video.sh` non ha potuto scaricare i 24 mp4. Da un PC normale lo script funziona com'è.
- Segnalazione: `https://www.alessandromilia.it/project/esplora/mascotte.png` (immagine della mascotte
  di `$BRAND`, usata anche dal player online) risponde **404**: il player ripiega sull'emoji 🧭, e nel
  pacchetto offline `media/mascotte.png` resta vuoto. Va ricaricata sul server o cambiato l'URL nel config.

## 29/10/2026 — player v2.4: telecomando, pacchetto offline, vendemmia ritrovata

### Perché mancava la vendemmia
La lezione `vendemmia-alagna` (9 clip, 27 scoperte, quiz 6+6) era in stato **bozza**: `edu_get_corsi` e
`edu_get_lezione_tenant` escludono le bozze, quindi il player non la mostrava. Ora è in stato **soon**
(«🔒 Prossimamente» nel menu) finché i video non vengono rimontati; il piano di rimontaggio è in
`docs/VENDEMMIA-RIMONTAGGIO.md` e lo strumento per segnare le scene in `strumenti/taglia-scene.html`.

### Telecomando per chi presenta (app/index.php v2.4)
- Barra grande in basso durante la lezione: ⏮ lezione · ⏪ capitolo · −10 s · **Play/Pausa** · +10 s ·
  capitolo ⏩ · lezione ⏭ · ☰ Capitoli · ? Aiuto. Si nasconde con 🎛 (teachbar) o tasto T.
- **Capitolo** = clip della playlist. Avanti/indietro riarmano le scoperte della clip su cui si torna;
  l'ultimo «capitolo successivo» apre il quiz. Lezione precedente/successiva saltano le «soon».
- **«Avanti» intelligente** (PagGiù, Invio, telecomandi da presentazione): chiude la scheda, apre la
  scoperta che brilla, passa al capitolo, avanza dal prologo/mascotte/fine. PagSu = indietro.
  Frecce ←/→ ±10 s, C indice dei capitoli, ? aiuto, [ ] lezioni.
- Indice **☰ Capitoli** con titolo (migr. 32), durata e scoperte cliccabili (si riparte 2,5 s prima).
- Tacche delle scoperte sulla barra del tempo; tornando indietro con la barra le scoperte ricompaiono.
- Overlay di fine: pulsante «⏭ Lezione successiva». Seek-bar: etichetta «cap. n/N».
- `bussola()` non esplode più se la camera non ha ancora la rotazione.

### Migrazione 32 + regia v17.2 — titolo dei capitoli
`edu_media.titolo` esposto come `video[].tit` da `edu_assembla_lezione`; campo 📑 nella playlist della
regia (`salvaCapitolo`). Seed dei titoli per vendemmia, corallo, tappeti e salinaio.
**Applicata in produzione il 29/10** (via MCP Supabase, nome `edu_32_capitoli`); regia v17.2 e player v2.4 vanno caricati via FTP, poi cancellare `dati/cache_*.json`. Cancellata anche la tappa vuota del salinaio (clip 1, 105,2 s) con il suo hotspot «✨».

### Pacchetto OFFLINE (`offline/`, vedi `offline/LEGGIMI-OFFLINE.md`)
- `index.php` renderizzato con `EDU_OFFLINE=1` diventa statico: librerie da `lib/`, contenuti da `dati.js`
  (`window.EDU_DATI`), video da `video/<guid>.mp4`, sottotitoli `video/<guid>.<lingua>.vtt`, nessuna
  chiamata a `api.php`/Bunny/YouTube (mascotte YouTube solo se salvata come `video/yt_<id>.mp4`).
  Quiz live e tracking spenti. In produzione non cambia nulla.
- `costruisci-player.sh` (php) · `crea-pacchetto.js` (node ≥ 18, RPC con la anon key; `--bozza slug=token`
  per includere una lezione in bozza via token di anteprima; `--res 1080p`) · `avvia.js` server locale
  con Range (salti nei video) + `AVVIA.bat`/`avvia.sh` · script `scarica-video.sh/.bat` generati.
- Pacchetto `esplora-trapani` già versionato (`dati.js`: salinaio, corallo, tappeti, **vendemmia**).
- La tappa vuota del salinaio (clip 1, 1:45, scheda «✨» senza testo) non è nel pacchetto ed è stata
  cancellata dal database il 29/10.

### Test
- Nuove suite jsdom `test/t_telecomando.js` (40 verifiche) e `test/t_offline.js` (24), in `npm test`.
- Prova nel browser vero (Chromium headless, rete esterna bloccata): pacchetto offline senza richieste
  verso internet, telecomando, indice capitoli, PagGiù/PagSu, quiz, lezione prec./succ.


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
