# ESPLORA TRAPANI EDU — FASE 3 · 02/09/2026
## Regia multi-tenant: Clienti & Licenze, Corsi, scoping per cliente

Questo zip CONTIENE anche la Fase 2 (app/ completa). Se non l'hai
ancora deployata, questo la sostituisce.

## Cosa cambia (Regia v14 «tenant»)
- **🏢 Clienti & Licenze** (solo admin): crea cliente (slug = indirizzo
  `/project/edu/{slug}/`), brand del player (titolo/sottotitolo), piano,
  **stato licenza e date** (le decidi tu), referente ed email (mostrata
  alle classi se la licenza scade), «Copia link del player».
  **Utenti**: assegna a ogni account ruolo (editor/docente/admin) e cliente.
- **📚 Corsi** (admin ed editor del cliente): crea/modifica corsi con
  emoji, colore, fascia, stato (bozza = invisibile alle classi), ordine,
  descrizione e **Intro del corso** (prologo). «Apri il player del cliente».
- **Sidebar** raggruppata Cliente → Corso → Lezioni (le lezioni senza
  corso restano visibili in una sezione a parte, per assegnarle).
- **Editor lezione**: nuovo campo **Corso**; una nuova lezione nasce
  dentro un corso (scelta al volo). Il vecchio «progetto» si allinea da
  solo al cliente del corso (compatibilità con il player legacy).
- **Migrazione 23**: RLS sui contenuti. Editor e docenti vedono SOLO il
  proprio cliente; docenti in sola lettura; nessun accesso anonimo diretto
  (il player passa dalle RPC, nulla cambia per le classi).

## Deploy
1. **Supabase** (SQL Editor, in ordine, tutte idempotenti):
   `migrazione_19` (se non fatta) → `20` → `21` (leggi la verifica in
   testa) → `22` → **`23`**.
2. **FTP**: cartella `app/` intera in `/project/edu/app/` (sovrascrive).
   `.htaccess` in `/project/edu/` da `htaccess-project-edu.txt` (se non
   già fatto in Fase 2).
3. Apri la regia: `/project/edu/app/regia-edu.php` → badge **v14 · tenant**.
   In sidebar: Salina Culcasi (corsi «Alla scoperta della salina» e
   «La vita della goccia» in bozza) ed Esplora Trapani («Antichi Mestieri»).
4. Prova: Clienti & Licenze → Salina Culcasi → metti una data di fine
   licenza e Salva → il player `/project/edu/salina-culcasi/` risponde di
   conseguenza (entro 5', o cancella `app/dati/cache_cliente_*.json`).

## Da ora, il lavoro sulle nuove lezioni della salina
Regia → Corsi → Salina Culcasi → «La vita della goccia» → il prologo è
già lì. «＋ Nuova lezione» → scegli il corso n. della goccia → lavori in
bozza. Quando è pronto: stato corso «pubblicato» e le lezioni «pubblicata».

## Test eseguiti
Migrazione 23 su Postgres 16 (x2, isolamento admin/editor/docente/anon) ·
suite DOM regia 25/25 (admin + editor, mock Supabase) · suite player 47/47.
