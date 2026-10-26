-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 21 · 02/09/2026 · RUOLI + RLS
-- Da eseguire DOPO la 20. Idempotente.
--
-- ⚠️ VERIFICA PRIMA (SQL Editor): edu_utenti.id deve coincidere con
-- auth.users.id (è l'assunto usato dalla regia: owner = USER.id).
--   select count(*) tot, count(a.id) collegati
--   from edu_utenti u left join auth.users a on a.id = u.id;
-- Se "collegati" = "tot", procedi. Altrimenti fermati e dimmelo.
--
-- Ruoli (edu_utenti.ruolo): 'admin' = superadmin di piattaforma
-- (cliente_id NULL, vede tutto) · 'editor' = redattore del proprio
-- cliente · 'docente' = insegnante del proprio cliente (statistiche,
-- proprie classi). Le policy di edu_lezioni/media/quiz NON vengono
-- toccate qui: la Fase 3 (regia multi-tenant) le scoperà per cliente.
-- ============================================================

-- utente corrente: ruolo + cliente (NULL se anonimo)
create or replace function edu_me()
returns table(uid uuid, ruolo text, cliente_id uuid)
language sql stable security definer set search_path to 'public' as $$
  select u.id, u.ruolo, u.cliente_id from edu_utenti u where u.id = auth.uid();
$$;

create or replace function edu_e_admin()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo = 'admin');
$$;

create or replace function edu_mio_cliente()
returns uuid language sql stable security definer set search_path to 'public' as $$
  select u.cliente_id from edu_utenti u where u.id = auth.uid();
$$;

-- ------------------------------------------------------------
-- edu_clienti
-- ------------------------------------------------------------
alter table edu_clienti enable row level security;
drop policy if exists clienti_sel on edu_clienti;
create policy clienti_sel on edu_clienti for select to authenticated
  using (edu_e_admin() or id = edu_mio_cliente());
drop policy if exists clienti_admin on edu_clienti;
create policy clienti_admin on edu_clienti for all to authenticated
  using (edu_e_admin()) with check (edu_e_admin());

-- ------------------------------------------------------------
-- edu_corsi: lettura nel proprio tenant; scrittura admin o editor del tenant
-- ------------------------------------------------------------
alter table edu_corsi enable row level security;
drop policy if exists corsi_sel on edu_corsi;
create policy corsi_sel on edu_corsi for select to authenticated
  using (edu_e_admin() or proprietario_id = edu_mio_cliente());
drop policy if exists corsi_write on edu_corsi;
create policy corsi_write on edu_corsi for all to authenticated
  using (edu_e_admin() or (proprietario_id = edu_mio_cliente()
         and exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo in ('editor','admin'))))
  with check (edu_e_admin() or (proprietario_id = edu_mio_cliente()
         and exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo in ('editor','admin'))));

-- ------------------------------------------------------------
-- edu_classi: docenti ed editor gestiscono le classi del proprio tenant
-- ------------------------------------------------------------
alter table edu_classi enable row level security;
drop policy if exists classi_tenant on edu_classi;
create policy classi_tenant on edu_classi for all to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente())
  with check (edu_e_admin() or cliente_id = edu_mio_cliente());

-- ------------------------------------------------------------
-- statistiche per il docente: solo il proprio tenant
-- (edu_eventi resta scrivibile da anon via api.php; la lettura
--  passa da questa RPC, mai dalla tabella)
-- ------------------------------------------------------------
create or replace function edu_report_mio_cliente()
returns setof v_edu_report_cliente
language sql stable security definer set search_path to 'public' as $$
  select r.* from v_edu_report_cliente r
  join edu_clienti c on c.slug = r.cliente
  where edu_e_admin() or c.id = edu_mio_cliente();
$$;

grant execute on function edu_me(), edu_e_admin(), edu_mio_cliente(), edu_report_mio_cliente() to authenticated;
grant execute on function edu_get_cliente(text), edu_get_corsi(text), edu_get_lezione_tenant(text, text), edu_licenza_attiva(uuid) to anon, authenticated;
