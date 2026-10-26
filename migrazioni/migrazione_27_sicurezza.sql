-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 27 · 14/09/2026 · SICUREZZA
-- Esito dei test di penetrazione sul ruolo anon (la chiave pubblica
-- che vive nel browser di chiunque apra il player):
--   ✓ scritture bloccate (clienti, corsi, lezioni, utenti, catalogo)
--   ✗ edu_eventi ERA LEGGIBILE: i dati d'uso delle classi di tutti i
--     clienti erano esposti a chiunque avesse la anon key.
-- Qui si chiude quel buco e si toglie ad anon ogni lettura diretta:
-- il player NON legge tabelle, passa solo dalle RPC SECURITY DEFINER.
-- Idempotente. Dopo la 26.
-- ============================================================

-- 1. eventi: il player DEVE poter inserire, non leggere
revoke select, update, delete on edu_eventi from anon;
grant insert on edu_eventi to anon;

alter table edu_eventi enable row level security;
drop policy if exists eventi_anon_ins on edu_eventi;
create policy eventi_anon_ins on edu_eventi for insert to anon
  with check (char_length(coalesce(codice_classe,'')) between 1 and 20
              and tipo in ('lezione_avviata','lezione_completata','quiz_esito'));
drop policy if exists eventi_lettura on edu_eventi;
create policy eventi_lettura on edu_eventi for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());

-- 2. nessuna lettura diretta delle tabelle di contenuto per anon
--    (le RPC sono SECURITY DEFINER: continuano a funzionare)
revoke select on edu_lezioni, edu_media, edu_tappe, edu_hotspot, edu_quiz,
                 edu_corsi, edu_clienti, edu_classi, edu_mascotte from anon;
revoke insert, update, delete on edu_lezioni, edu_media, edu_tappe, edu_hotspot,
                 edu_quiz, edu_corsi, edu_clienti, edu_classi from anon;

-- 3. richieste dalla pagina pubblica: inserimento sì, lettura no
revoke select, update, delete on edu_richieste from anon;
grant insert on edu_richieste to anon;

-- 4. le RPC che servono al player restano accessibili
grant execute on function edu_get_cliente(text), edu_get_corsi(text),
  edu_get_lezione_tenant(text, text), edu_classe_stato(uuid, text),
  edu_licenza_attiva(uuid), edu_catalogo_valido(uuid, uuid),
  edu_scuola_valida(uuid), edu_piano_limiti(text) to anon;

-- Verifica: da ruolo anon, "select count(*) from edu_eventi" deve dare
-- "permission denied", mentre edu_get_corsi('slug') deve funzionare.
revoke select on edu_utenti from anon;

-- 5. PRESTAZIONI: indici emersi dai test di carico (55.000 eventi).
--    La dashboard delle statistiche passa da ~200 ms a ~13 ms.
create index if not exists edu_eventi_cliente_tipo_idx on edu_eventi(cliente_id, tipo);
create index if not exists edu_eventi_classe_idx       on edu_eventi(codice_classe);
create index if not exists edu_catalogo_corso_idx      on edu_catalogo(corso_id);
create index if not exists edu_lezioni_corso_stato_idx on edu_lezioni(corso_id, stato);
