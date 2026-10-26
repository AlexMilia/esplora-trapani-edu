-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 22 · 02/09/2026 · Fase 2
-- Ritocchi alle RPC del tenant per api.php v4:
--  - edu_get_cliente: aggiunge progetto_legacy (ponte mascotte) e uuid
--  - edu_get_lezione_tenant: il corso porta anche uuid (tracking)
-- Idempotente (OR REPLACE). Eseguire dopo la 20/21.
-- ============================================================
create or replace function edu_get_cliente(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'id', c.id, 'slug', c.slug, 'nome', c.nome, 'brand', c.brand,
    'progetto_legacy', c.progetto_legacy,
    'piano', c.piano, 'licenza_stato', c.licenza_stato,
    'licenza_fine', c.licenza_fine, 'attiva', edu_licenza_attiva(c.id),
    'contatto_email', c.contatto_email,
    'piattaforma', 'Esplora Trapani Edu')
  from edu_clienti c where c.slug = p_slug;
$$;

create or replace function edu_get_lezione_tenant(p_cliente_slug text, p_lezione_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select edu_assembla_lezione(l.id)
         || jsonb_build_object('corso', jsonb_build_object(
              'id', co.slug, 'uuid', co.id, 'tit', co.titolo,
              'prologo', nullif(trim(co.prologo), '')))
  from edu_lezioni l
  join edu_corsi co on co.id = l.corso_id
  join edu_clienti c on c.id = co.proprietario_id
  where c.slug = p_cliente_slug and l.slug = p_lezione_slug
    and l.owner is null and l.stato not in ('bozza','soon') and co.stato <> 'bozza'
  limit 1;
$$;
grant execute on function edu_get_cliente(text), edu_get_lezione_tenant(text, text) to anon, authenticated;
