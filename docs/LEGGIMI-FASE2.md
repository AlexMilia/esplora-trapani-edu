# ESPLORA TRAPANI EDU — FASE 2 · 02/09/2026
## Un solo deploy per tutti i clienti

## Cosa cambia
- **api.php v4**: legge il cliente dall'URL (`/edu/{slug}/` o `?c=slug`),
  verifica la **licenza** (scaduta/sospesa → messaggio gentile con contatto),
  serve **corsi → lezioni** del solo cliente, cache su file **per cliente**,
  tracking con `cliente_id` e `corso_id`.
- **index.php v2.0**: brand (titolo/sottotitolo) dal DB, **menu a due livelli**
  (card dei corsi → lezioni; salto diretto se il cliente ha un corso solo),
  **prologo del corso** mostrato una volta per sessione, gate licenza.
- **Retrocompatibile**: senza migrazioni 20-22 o senza tenant nell'URL,
  api.php lavora come prima (progetto legacy). Niente si rompe.

## Deploy (una volta)
1. **Supabase**: esegui `migrazione_20_saas_fase1.sql`, `21_ruoli_rls.sql`
   (leggi la verifica in testa), `22_rpc_tenant.sql`. Idempotenti.
   (Se non hai ancora eseguito la 19, eseguila prima.)
2. **FTP**: carica la cartella **`app/`** intera in `/project/edu/app/`
   (è la ver7 con api v4 + index v2.0; contiene anche la regia).
3. **FTP**: crea `/project/edu/.htaccess` col contenuto di
   `htaccess-project-edu.txt` (non tocca mestieri/ e le ver* esistenti:
   riscrive solo i percorsi che non esistono su disco).
4. Prova:
   - `https://www.alessandromilia.it/project/edu/salina-culcasi/`
     → brand "Sale in Classe", card dei corsi (la salina + la goccia
     quando la pubblichi), prologo all'avvio
   - `https://www.alessandromilia.it/project/edu/esplora-trapani/`
     → Antichi Mestieri (un corso solo → lezioni dirette)
   - `.../project/edu/salina-culcasi/api.php?ver` → "tenant: salina-culcasi"
   - `.../app/debug500.php?k=salina` → tutto ✓
5. Quando è verde: ver7 e precedenti si possono cancellare. I link e i
   QR delle scuole puntano a `/project/edu/{cliente}/`.

## Nuovo cliente, da ora
Una riga in `edu_clienti` (slug, nome, brand, licenza) + i suoi corsi.
Zero FTP. (La Fase 3 lo farà dal pannello della regia.)

## Note
- Il tenant di default (config: `$EDU_TENANT_DEFAULT`) vale solo quando
  l'URL non lo indica: serve a far funzionare `/app/` aperto direttamente.
- Cache: `dati/cache_cliente_{slug}.json`, `cache_catalogo_{slug}.json`,
  `cache_lez_{slug}_{lezione}.json` (TTL 5'). Cancellarle dopo cambi in regia
  se non vuoi aspettare.
- Test eseguiti: api E2E (tenant dal path, licenza, corsi, 404/403, legacy),
  suite DOM 47/47, migrazioni 20-22 su Postgres 16.
