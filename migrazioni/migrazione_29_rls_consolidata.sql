-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 29 · 24/09/2026 · RLS CONSOLIDATA
-- Esito dell'audit (Fase 1) sulle policy:
--   • 4 tabelle SENZA RLS e accessibili ad anon per default Supabase:
--     edu_mascotte, edu_messaggi, edu_progetti, edu_versioni
--     (edu_messaggi = messaggi mostrati in classe: scrivibili da chiunque!)
--   • policy che si SOMMANO in OR con quelle legacy di agosto (nomi ignoti
--     in produzione): due INSERT anon su edu_eventi (la legacy accetta
--     qualsiasi tipo), due SELECT su edu_utenti
--   • policy troppo larghe: un DOCENTE poteva creare/cancellare scuole e
--     classi altrui del suo cliente (ALL sul tenant)
-- Strategia: per ogni tabella edu_ si ELIMINANO TUTTE le policy esistenti
-- (qualunque nome) e si ricrea il set canonico. Nessuna sovrapposizione
-- possibile. Idempotente: rieseguirla produce lo stesso set.
-- ============================================================

-- ------------------------------------------------------------
-- 0. helper (già presenti dalle migrazioni precedenti; qui garantiti)
-- ------------------------------------------------------------
create or replace function edu_e_admin() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo = 'admin');
$$;
create or replace function edu_mio_cliente() returns uuid
language sql stable security definer set search_path to 'public' as $$
  select u.cliente_id from edu_utenti u where u.id = auth.uid();
$$;
create or replace function edu_sono_editor() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo in ('editor','admin'));
$$;

-- ------------------------------------------------------------
-- 1. AZZERAMENTO: via tutte le policy delle tabelle edu_
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies
            where schemaname = 'public' and tablename like 'edu\_%' escape '\' loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- RLS attiva su TUTTE le tabelle edu_ (comprese le 4 scoperte)
do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'edu\_%' escape '\' loop
    execute format('alter table public.%I enable row level security', r.relname);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. PERMESSI DI TABELLA (le policy filtrano le righe, i grant le operazioni)
--    anon: SOLO insert su eventi e richieste. authenticated: tutto, filtrato da RLS.
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'edu\_%' escape '\' loop
    execute format('revoke all on public.%I from anon', r.relname);
    execute format('grant select, insert, update, delete on public.%I to authenticated', r.relname);
  end loop;
end $$;
grant insert on edu_eventi, edu_richieste to anon;
grant usage, select on all sequences in schema public to authenticated;
grant usage, select on all sequences in schema public to anon;   -- serve per l'insert su edu_eventi (bigserial)

-- ------------------------------------------------------------
-- 3. SET CANONICO
-- Convenzione: <tabella>_sel (lettura) e <tabella>_wr (scrittura), mai due
-- policy per la stessa operazione e lo stesso ruolo.
-- ------------------------------------------------------------

-- utenti: ognuno legge sé stesso; l'admin gestisce tutti; l'editor vede i colleghi del suo cliente
create policy utenti_sel on edu_utenti for select to authenticated
  using (id = auth.uid() or edu_e_admin() or (cliente_id is not null and cliente_id = edu_mio_cliente()));
create policy utenti_wr on edu_utenti for all to authenticated
  using (edu_e_admin()) with check (edu_e_admin());

-- clienti: l'admin tutto; il proprio cliente in lettura
create policy clienti_sel on edu_clienti for select to authenticated
  using (edu_e_admin() or id = edu_mio_cliente());
create policy clienti_wr on edu_clienti for all to authenticated
  using (edu_e_admin()) with check (edu_e_admin());

-- corsi: proprietario o licenziatario in lettura; scrive solo l'editor del proprietario
create policy corsi_sel on edu_corsi for select to authenticated
  using (edu_e_admin() or proprietario_id = edu_mio_cliente() or edu_ho_licenza(id));
create policy corsi_wr on edu_corsi for all to authenticated
  using (edu_e_admin() or (proprietario_id = edu_mio_cliente() and edu_sono_editor()))
  with check (edu_e_admin() or (proprietario_id = edu_mio_cliente() and edu_sono_editor()));

-- catalogo: legge chi ha il corso o lo possiede; scrive l'admin o l'editor proprietario del corso
create policy catalogo_sel on edu_catalogo for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente() or edu_sono_proprietario(corso_id));
create policy catalogo_wr on edu_catalogo for all to authenticated
  using (edu_e_admin() or (edu_sono_proprietario(corso_id) and edu_sono_editor()))
  with check (edu_e_admin() or (edu_sono_proprietario(corso_id) and edu_sono_editor()));

-- scuole: il tenant le legge; le scrive l'editor (il docente NO)
create policy scuole_sel on edu_scuole for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());
create policy scuole_wr on edu_scuole for all to authenticated
  using (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()))
  with check (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()));

-- classi: il tenant le legge; l'editor le gestisce tutte, il docente solo le PROPRIE (docente_id)
create policy classi_sel on edu_classi for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());
create policy classi_wr on edu_classi for all to authenticated
  using (edu_e_admin() or (cliente_id = edu_mio_cliente() and (edu_sono_editor() or docente_id = auth.uid())))
  with check (edu_e_admin() or (cliente_id = edu_mio_cliente() and (edu_sono_editor() or docente_id = auth.uid())));

-- lezioni: "mia" = del mio cliente, in licenza (sola lettura) o mia copia; scrivibile solo se proprietario/copia
create policy lez_sel on edu_lezioni for select to authenticated using (edu_lezione_mia(id));
create policy lez_ins on edu_lezioni for insert to authenticated
  with check (edu_e_admin() or owner = auth.uid() or edu_corso_scrivibile(corso_id));
create policy lez_upd on edu_lezioni for update to authenticated
  using (edu_lezione_scrivibile(id)) with check (edu_e_admin() or owner = auth.uid() or edu_corso_scrivibile(corso_id));
create policy lez_del on edu_lezioni for delete to authenticated using (edu_lezione_scrivibile(id));

-- contenuti della lezione (media, tappe, hotspot, quiz, versioni): seguono la lezione
create policy media_sel on edu_media for select to authenticated using (edu_lezione_mia(lezione_id));
create policy media_wr  on edu_media for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));
create policy tappe_sel on edu_tappe for select to authenticated using (edu_lezione_mia(lezione_id));
create policy tappe_wr  on edu_tappe for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));
create policy hot_sel on edu_hotspot for select to authenticated
  using (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_mia(tp.lezione_id)));
create policy hot_wr on edu_hotspot for all to authenticated
  using (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_scrivibile(tp.lezione_id)))
  with check (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_scrivibile(tp.lezione_id)));
create policy quiz_sel on edu_quiz for select to authenticated using (edu_lezione_mia(lezione_id));
create policy quiz_wr  on edu_quiz for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));
create policy versioni_sel on edu_versioni for select to authenticated using (edu_lezione_mia(lezione_id));
create policy versioni_wr  on edu_versioni for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));

-- mascotte, progetti, messaggi (configurazione legacy per progetto): lettura a tutti i
-- ruoli della regia, scrittura solo admin/editor. Il player NON li legge (RPC).
create policy mascotte_sel on edu_mascotte for select to authenticated using (true);
create policy mascotte_wr  on edu_mascotte for all to authenticated
  using (edu_sono_editor()) with check (edu_sono_editor());
create policy progetti_sel on edu_progetti for select to authenticated using (true);
create policy progetti_wr  on edu_progetti for all to authenticated
  using (edu_sono_editor()) with check (edu_sono_editor());
create policy messaggi_sel on edu_messaggi for select to authenticated using (true);
create policy messaggi_wr  on edu_messaggi for all to authenticated
  using (edu_sono_editor()) with check (edu_sono_editor());

-- eventi: il player (anon) inserisce, con tipo e codice controllati; il tenant legge i propri
create policy eventi_anon_ins on edu_eventi for insert to anon
  with check (char_length(coalesce(codice_classe,'')) between 1 and 20
              and codice_classe ~ '^[A-Z0-9-]+$'
              and tipo in ('lezione_avviata','lezione_completata','quiz_esito'));
create policy eventi_sel on edu_eventi for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());

-- richieste dalla pagina pubblica: anon inserisce, l'admin gestisce
create policy richieste_anon_ins on edu_richieste for insert to anon
  with check (length(scuola) between 2 and 120 and length(email) between 5 and 120);
create policy richieste_wr on edu_richieste for all to authenticated
  using (edu_e_admin()) with check (edu_e_admin());

-- ------------------------------------------------------------
-- 4. Verifica: nessuna tabella edu_ con più di una policy per (ruolo, comando)
-- ------------------------------------------------------------
do $$
declare v int;
begin
  select count(*) into v from (
    select tablename, cmd, r from pg_policies p, unnest(p.roles) r
    where tablename like 'edu\_%' escape '\' and cmd <> 'ALL'
    group by tablename, cmd, r having count(*) > 1) x;
  if v > 0 then raise exception 'policy sovrapposte: %', v; end if;
end $$;
