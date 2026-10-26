# ESPLORA TRAPANI EDU — Architettura SaaS · 02/09/2026

## Decisioni prese (brainstorming 02/09)
| Tema | Decisione |
|---|---|
| Piattaforma | **Esplora Trapani Edu** (ombrello); "Sale in Classe" resta il prodotto-salina |
| Gerarchia | **Cliente** (tenant + licenza) → **Corso** → **Lezione** |
| Tenant nell'URL | Percorso: `/edu/{slug-cliente}/` (es. `/edu/salina-culcasi/`) |
| Prologo | Sul **corso** (mostrato all'avvio della prima lezione del corso) |
| Licenza | Piano base/pro/premium; stato attiva/sospesa/scaduta; **date libere** decise dal superadmin |
| Docenti | **Login** (Supabase Auth) + statistiche del proprio cliente; il codice classe resta per gli alunni |
| Accessibilità | Ipovedenti e LIS **mai a pagamento** |
| Ruoli | `admin` = superadmin (cliente NULL) · `editor` = redattore del cliente · `docente` |

## Fase 1 — DATABASE (fatta, migrazioni 20 + 21)
- `edu_clienti` (slug, brand jsonb, piano, licenza_stato/inizio/fine)
- `edu_corsi` (cliente_id, slug, titolo, fascia, **prologo**, stato bozza/pubblicato/soon)
- `edu_lezioni.corso_id`, `edu_utenti.cliente_id`, `edu_eventi.cliente_id/corso_id`
- `edu_classi` (registro codici classe per cliente, docente_id)
- Backfill automatico: `sale-in-classe` → cliente **Salina Culcasi** con corso
  "Alla scoperta della salina" (le lezioni attuali) + corso **"La vita della
  goccia"** in bozza con l'Intro del corso già dentro; `antichi-mestieri-trapani`
  → cliente **Esplora Trapani** con corso "Antichi Mestieri".
- RPC per il player: `edu_get_cliente(slug)` (brand + licenza), `edu_get_corsi(slug)`
  (menu a due livelli, bozze escluse), `edu_get_lezione_tenant(slug, lezione)`.
- RLS (21): admin vede tutto; editor/docente solo il proprio cliente; docente
  non crea corsi; report via `edu_report_mio_cliente()`.
- Testato su Postgres 16 con schema replica: idempotenza (x2), backfill, RPC,
  isolamento RLS con tre utenti di tenant diversi.
- Nulla si rompe: `progetto` resta come alias finché la Fase 2 non lo sostituisce.

## Fase 2 — API + PLAYER (fatta 02/09)
- `api.php`: legge lo slug dal path (`/edu/{slug}/`), chiama `edu_get_cliente`,
  **gate licenza** (scaduta/sospesa → pagina gentile), `edu_get_corsi` per il menu,
  `edu_get_lezione_tenant` per la lezione; cache su file **per cliente**.
- `index.php`: brand dal DB (titolo, colori, mascotte) al posto di `$EDU_BRAND`;
  menu a due livelli (corsi → lezioni; salto diretto se il cliente ha un corso solo);
  prologo dal corso; tracking con cliente_id/corso_id.
- Un solo deploy per tutti i clienti. Nuovo cliente = una riga in regia. Zero FTP.

## Fase 3 — REGIA MULTI-TENANT (fatta 02/09, Regia v14 + migr. 23)
- Pannello **Clienti & Licenze** (solo admin): crea cliente, brand, piano, date,
  sospendi/riattiva, assegna utenti (editor/docente).
- Editor corsi: copertina, fascia, prologo, ordine, stato; lezioni dentro il corso.
- Scoping RLS su edu_lezioni/media/tappe/quiz per cliente (oggi sono per progetto).
- Vista docente: proprie classi (edu_classi), statistiche del proprio cliente.

## Fase 4 — PRODOTTO (fatta 02/09, Regia v15 + migr. 24 + attiva.php)
- Piani e limiti (base: 1 corso; pro: quiz live + report; premium: VR/produzione).
- Dashboard report per cliente (il valore che rinnova la licenza).
- Pagina pubblica "attiva la tua licenza" / onboarding scuola.
- Sottodominio opzionale in futuro (`salina.esploratrapani.it`).

## Come eseguire la Fase 1 (SQL Editor di Supabase)
1. Verifica preliminare della 21 (edu_utenti.id = auth.users.id): query nel file.
2. `migrazione_20_saas_fase1.sql` → poi `migrazione_21_ruoli_rls.sql`.
3. Controlli: `select slug, edu_licenza_attiva(id) from edu_clienti;` ·
   `select edu_get_corsi('salina-culcasi');`
4. In regia (per ora): niente cambia — le lezioni attuali continuano a funzionare.
