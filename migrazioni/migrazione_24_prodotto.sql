-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 24 · 02/09/2026 · FASE 4 (prodotto)
-- 1. Piani e limiti (unica fonte di verità, letta da api.php e regia)
-- 2. Statistiche per cliente (dashboard docente/admin)
-- 3. Richieste di attivazione dalla pagina pubblica (attiva.php)
-- Idempotente. Dopo 20/21/22/23.
-- ============================================================

-- ------------------------------------------------------------
-- 1. PIANI
-- ------------------------------------------------------------
create or replace function edu_piano_limiti(p_piano text)
returns jsonb language sql immutable as $$
  select case p_piano
    when 'premium' then '{"corsi_pubblicati": 999, "quiz_live": true,  "report": true, "classi": 999, "vr": true,  "nome": "Premium"}'::jsonb
    when 'pro'     then '{"corsi_pubblicati": 999, "quiz_live": true,  "report": true, "classi": 999, "vr": false, "nome": "Pro"}'::jsonb
    else                '{"corsi_pubblicati": 1,   "quiz_live": false, "report": true, "classi": 10,  "vr": false, "nome": "Base"}'::jsonb
  end;
$$;

-- edu_get_cliente ora porta anche i limiti del piano
create or replace function edu_get_cliente(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'id', c.id, 'slug', c.slug, 'nome', c.nome, 'brand', c.brand,
    'progetto_legacy', c.progetto_legacy,
    'piano', c.piano, 'limiti', edu_piano_limiti(c.piano),
    'licenza_stato', c.licenza_stato,
    'licenza_fine', c.licenza_fine, 'attiva', edu_licenza_attiva(c.id),
    'contatto_email', c.contatto_email,
    'piattaforma', 'Esplora Trapani Edu')
  from edu_clienti c where c.slug = p_slug;
$$;

-- ------------------------------------------------------------
-- 2. STATISTICHE PER CLIENTE
--    admin: qualsiasi cliente · editor/docente: solo il proprio
-- ------------------------------------------------------------
create or replace function edu_stats_cliente(p_slug text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_cl edu_clienti%rowtype;
  v_out jsonb;
begin
  select * into v_cl from edu_clienti where slug = p_slug;
  if v_cl.id is null then return null; end if;
  if not (edu_e_admin() or v_cl.id = edu_mio_cliente()) then
    raise exception 'non autorizzato';
  end if;

  with ev as (
    select e.*, (e.dettaglio->>'live')::boolean as live,
           nullif(e.dettaglio->>'pct_classe','')::numeric as pct_live,
           nullif(e.dettaglio->>'pct','')::numeric as pct_classico
    from edu_eventi e where e.cliente_id = v_cl.id
  ),
  cl as (
    select codice, nome, anno from edu_classi where cliente_id = v_cl.id
  ),
  per_classe as (
    select ev.codice_classe,
           max(cl.nome) as nome, max(cl.anno) as anno,
           count(*) filter (where tipo='lezione_avviata')    as avviate,
           count(*) filter (where tipo='lezione_completata')  as completate,
           count(*) filter (where tipo='quiz_esito')          as quiz,
           count(*) filter (where tipo='quiz_esito' and live) as partite_live,
           round(avg(coalesce(pct_live, pct_classico)) filter (where tipo='quiz_esito'))::int as pct_medio,
           max(creato_il) as ultima
    from ev left join cl on cl.codice = ev.codice_classe
    group by ev.codice_classe
  ),
  per_lezione as (
    select lezione,
           count(*) filter (where tipo='lezione_avviata')   as avviate,
           count(*) filter (where tipo='lezione_completata') as completate,
           count(*) filter (where tipo='quiz_esito')         as quiz,
           round(avg(coalesce(pct_live, pct_classico)) filter (where tipo='quiz_esito'))::int as pct_medio
    from ev group by lezione
  ),
  giorni as (
    select to_char(creato_il::date, 'YYYY-MM-DD') as giorno, count(*) as n
    from ev where creato_il >= now() - interval '30 days'
    group by 1 order by 1
  )
  select jsonb_build_object(
    'cliente', jsonb_build_object('slug', v_cl.slug, 'nome', v_cl.nome, 'piano', v_cl.piano,
                                  'licenza_stato', v_cl.licenza_stato, 'licenza_fine', v_cl.licenza_fine),
    'totali', jsonb_build_object(
       'classi',        (select count(distinct codice_classe) from ev where codice_classe <> 'ANON'),
       'avviate',       (select count(*) from ev where tipo='lezione_avviata'),
       'completate',    (select count(*) from ev where tipo='lezione_completata'),
       'quiz',          (select count(*) from ev where tipo='quiz_esito'),
       'partite_live',  (select count(*) from ev where tipo='quiz_esito' and live),
       'pct_medio',     (select round(avg(coalesce(pct_live, pct_classico)))::int from ev where tipo='quiz_esito'),
       'ultimo_evento', (select max(creato_il) from ev)),
    'per_classe',  coalesce((select jsonb_agg(to_jsonb(pc) order by pc.ultima desc) from per_classe pc), '[]'::jsonb),
    'per_lezione', coalesce((select jsonb_agg(to_jsonb(pl) order by pl.avviate desc) from per_lezione pl), '[]'::jsonb),
    'ultimi_30gg', coalesce((select jsonb_agg(to_jsonb(g)) from giorni g), '[]'::jsonb)
  ) into v_out;
  return v_out;
end $$;
grant execute on function edu_stats_cliente(text), edu_piano_limiti(text) to authenticated;
grant execute on function edu_piano_limiti(text), edu_get_cliente(text) to anon;

-- ------------------------------------------------------------
-- 3. RICHIESTE DI ATTIVAZIONE (pagina pubblica attiva.php)
-- ------------------------------------------------------------
create table if not exists edu_richieste (
  id           uuid primary key default gen_random_uuid(),
  scuola       text not null,
  referente    text,
  email        text not null,
  telefono     text,
  messaggio    text,
  interesse    text,                      -- es. 'salina', 'mestieri', 'altro'
  stato        text not null default 'nuova' check (stato in ('nuova','contattata','attivata','archiviata')),
  cliente_id   uuid references edu_clienti(id),
  creato_il    timestamptz not null default now()
);
alter table edu_richieste enable row level security;
drop policy if exists richieste_anon_ins on edu_richieste;
create policy richieste_anon_ins on edu_richieste for insert to anon
  with check (length(scuola) between 2 and 120 and length(email) between 5 and 120);
drop policy if exists richieste_admin on edu_richieste;
create policy richieste_admin on edu_richieste for all to authenticated
  using (edu_e_admin()) with check (edu_e_admin());
grant insert on edu_richieste to anon;
grant select, insert, update, delete on edu_richieste to authenticated;
