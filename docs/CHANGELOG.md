# Registro delle modifiche

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
