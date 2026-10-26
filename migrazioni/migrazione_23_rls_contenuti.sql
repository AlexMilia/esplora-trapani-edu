-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 23 · 02/09/2026 · FASE 3
-- Scoping per CLIENTE delle tabelle di contenuto usate dalla regia.
-- Regole: admin tutto · editor: lezioni del PROPRIO cliente (via
-- corso) + copie personali · docente: sola lettura del proprio
-- cliente · anon: NESSUN accesso diretto (il player legge SOLO via
-- RPC SECURITY DEFINER, quindi non cambia nulla per le classi).
-- Le policy preesistenti su queste tabelle vengono sostituite.
-- Idempotente. Eseguire dopo 20/21/22.
-- ============================================================

-- la lezione appartiene al mio cliente? (o è una mia copia personale)
create or replace function edu_lezione_mia(p_lezione uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or exists (select 1 from edu_lezioni l
                 where l.id = p_lezione and l.owner = auth.uid())
      or exists (select 1 from edu_lezioni l join edu_corsi co on co.id = l.corso_id
                 where l.id = p_lezione and co.proprietario_id = edu_mio_cliente());
$$;

-- posso SCRIVERE su questa lezione? (admin, editor del cliente, o proprietario)
create or replace function edu_lezione_scrivibile(p_lezione uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or exists (select 1 from edu_lezioni l where l.id = p_lezione and l.owner = auth.uid())
      or exists (select 1 from edu_lezioni l join edu_corsi co on co.id = l.corso_id
                 join edu_utenti u on u.id = auth.uid()
                 where l.id = p_lezione and co.proprietario_id = u.cliente_id and u.ruolo = 'editor');
$$;

-- posso creare/spostare una lezione in questo corso?
create or replace function edu_corso_scrivibile(p_corso uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or (p_corso is not null and exists (
            select 1 from edu_corsi co join edu_utenti u on u.id = auth.uid()
            where co.id = p_corso and co.proprietario_id = u.cliente_id and u.ruolo = 'editor'));
$$;

-- sostituzione controllata delle policy
do $$
declare t text; p record;
begin
  foreach t in array array['edu_lezioni','edu_media','edu_tappe','edu_hotspot','edu_quiz'] loop
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy if exists %I on %I', p.policyname, t);
    end loop;
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- edu_lezioni
create policy lez_sel on edu_lezioni for select to authenticated
  using (edu_lezione_mia(id));
create policy lez_ins on edu_lezioni for insert to authenticated
  with check (edu_e_admin() or owner = auth.uid() or edu_corso_scrivibile(corso_id));
create policy lez_upd on edu_lezioni for update to authenticated
  using (edu_lezione_scrivibile(id))
  with check (edu_e_admin() or owner = auth.uid() or edu_corso_scrivibile(corso_id));
create policy lez_del on edu_lezioni for delete to authenticated
  using (edu_lezione_scrivibile(id));

-- figli: media, quiz (lezione_id diretta)
create policy media_sel on edu_media for select to authenticated using (edu_lezione_mia(lezione_id));
create policy media_all on edu_media for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));
create policy quiz_sel on edu_quiz for select to authenticated using (edu_lezione_mia(lezione_id));
create policy quiz_all on edu_quiz for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));
create policy tappe_sel on edu_tappe for select to authenticated using (edu_lezione_mia(lezione_id));
create policy tappe_all on edu_tappe for all to authenticated
  using (edu_lezione_scrivibile(lezione_id)) with check (edu_lezione_scrivibile(lezione_id));

-- hotspot: via tappa
create policy hot_sel on edu_hotspot for select to authenticated
  using (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_mia(tp.lezione_id)));
create policy hot_all on edu_hotspot for all to authenticated
  using (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_scrivibile(tp.lezione_id)))
  with check (exists (select 1 from edu_tappe tp where tp.id = tappa_id and edu_lezione_scrivibile(tp.lezione_id)));

-- utenti: ognuno legge sé stesso; l'admin gestisce tutti (assegna cliente e ruolo)
alter table edu_utenti enable row level security;
drop policy if exists utenti_me on edu_utenti;
create policy utenti_me on edu_utenti for select to authenticated using (id = auth.uid() or edu_e_admin());
drop policy if exists utenti_admin on edu_utenti;
create policy utenti_admin on edu_utenti for all to authenticated using (edu_e_admin()) with check (edu_e_admin());

grant execute on function edu_lezione_mia(uuid), edu_lezione_scrivibile(uuid), edu_corso_scrivibile(uuid) to authenticated;
