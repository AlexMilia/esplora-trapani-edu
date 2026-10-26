# ESPLORA TRAPANI EDU — FASE 4 · 02/09/2026
## Il prodotto: piani, report, onboarding

Questo zip CONTIENE le Fasi 2-3-4 (app/ completa). Sostituisce i precedenti.

## Cosa cambia
- **Piani con limiti** (migr. 24, unica fonte di verità `edu_piano_limiti`):
  Base = 1 corso pubblicato, 10 classi, **senza Quiz Live** · Pro = illimitato +
  Quiz Live · Premium = Pro + VR. Accessibilità (ipovedenti, LIS) SEMPRE inclusa.
  Il player nasconde il Quiz Live sul piano Base; la regia blocca la
  pubblicazione del secondo corso e la classe oltre il limite, con un toast
  che spiega cosa fare.
- **📊 Statistiche** (regia, tutti i ruoli, ognuno il proprio cliente): KPI
  (classi attive, lezioni avviate/completate, quiz, partite live, media risposte
  giuste), tabella per classe col nome, tabella per lezione con «DA RIVEDERE»
  sotto il 60%, barre degli ultimi 30 giorni. Dati anonimi per codice classe.
- **🏫 Le classi** (regia): crea la classe (codice generato, nome, anno), copia
  il **link del player con il codice** da dare alla maestra. I nomi appaiono
  nelle statistiche al posto dei codici.
- **📥 Richieste di attivazione** in Clienti & Licenze: arrivano da
  **`attiva.php`**, la pagina pubblica «Richiedi l'attivazione» (form con
  honeypot anti-bot, scrive solo-inserimento con la anon key). «＋ Crea cliente»
  crea il tenant in un click, con referente ed email già dentro.

## Deploy
1. **Supabase**: migrazioni in ordine 19 → 20 → 21 → 22 → 23 → **24**
   (idempotenti: le già eseguite non fanno nulla).
2. **FTP**: cartella `app/` intera in `/project/edu/app/` (sovrascrive);
   `.htaccess` in `/project/edu/` (se non c'è già).
3. Regia: badge **v15 · prodotto**. Pagina pubblica:
   `https://www.alessandromilia.it/project/edu/app/attiva.php`
   (con l'.htaccess anche `/project/edu/attiva/attiva.php` non serve: usa app/).
4. Prova: Statistiche → Salina Culcasi (dopo qualche lezione con `?classe=`);
   Le classi → nuova classe → copia link → aprilo: il player parte con quel
   codice; attiva.php → invia una richiesta → compare in Clienti & Licenze.

## Test eseguiti
Migrazione 24 su Postgres 16 (limiti, statistiche con media, divieto
cross-cliente, richieste anon insert-only) · suite regia 37/37 · suite
player 50/50 (incluso piano Base senza Quiz Live) · attiva.php 200 + JS valido.

## Aggiornamento 12/09 — Regia v15.1: recupero password
- Login: si entra con l'**e-mail** (placeholder chiarito, Invio funziona).
- **«Password dimenticata?»** sotto il form: Supabase manda l'e-mail col link;
  il link riporta sulla regia, che mostra il form «Nuova password».
- **Da fare UNA volta in Supabase** (altrimenti il link torna sul Site URL
  sbagliato): Authentication → **URL Configuration** → *Redirect URLs* →
  aggiungi `https://www.alessandromilia.it/project/edu/**`
  (copre app/ e le cartelle ver*). Facoltativo: Authentication → Emails →
  «Reset password» per tradurre il testo in italiano.
- Vale anche per la ver7: copia `regia-edu.php` (v15.1) al posto di quello
  attuale — funziona anche senza le migrazioni SaaS.
