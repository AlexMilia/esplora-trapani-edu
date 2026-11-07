-- ============================================================================
-- MIGRAZIONE 34 — chiusura di sicurezza prima della messa online
-- ----------------------------------------------------------------------------
-- Quattro cose emerse dalla revisione di sicurezza del 7/11/2026.
--
-- 1. FUNZIONI: PostgreSQL (e Supabase) concedono EXECUTE a tutti su ogni
--    funzione nuova. Finora il player funzionava con la anon key anche su RPC
--    senza nessun grant esplicito, e per lo stesso motivo da fuori si potevano
--    chiamare edu_assembla_lezione (bozze e quiz con le soluzioni, conoscendo
--    l'uuid), edu_stats_cliente, edu_report_mio_cliente… Qui si revoca tutto
--    da public e anon e si ri-concede ad anon SOLO l'elenco delle funzioni che
--    il player usa davvero. Authenticated conserva tutto (le policy RLS
--    chiamano edu_e_admin() & co.).
-- 2. VISTE: il revoke della migrazione 29 ciclava solo sulle tabelle; le viste
--    (v_edu_report_cliente e le due legacy) restavano leggibili da anon con i
--    privilegi del proprietario, saltando la RLS: tutti i codici classe di tutti
--    i clienti. Ora: nessun accesso diretto, e security_invoker.
-- 3. STATISTICHE: edu_stats_cliente faceva ::boolean e ::numeric sul dettaglio
--    degli eventi, che anon scrive. Un evento con live:"xyz" rompeva il pannello
--    Statistiche di tutto il cliente. Ora i cast sono tolleranti (edu_num,
--    edu_bool) e la policy limita la taglia del dettaglio.
-- 4. RICHIESTE: attiva.php scrive in edu_richieste direttamente dal browser.
--    La policy ora impone stato='nuova', cliente_id nullo e lunghezze massime.
-- ============================================================================

-- ---- 3a. cast tolleranti --------------------------------------------------
create or replace function edu_num(p text) returns numeric
language sql immutable strict parallel safe as $$
  select case when p ~ '^\s*-?\d+(\.\d+)?\s*$' then p::numeric else null end
$$;
create or replace function edu_bool(p text) returns boolean
language sql immutable strict parallel safe as $$
  select case lower(trim(p)) when 'true' then true when 't' then true when '1' then true
                             when 'false' then false when 'f' then false when '0' then false
                             else null end
$$;

-- ---- 3b. statistiche con i cast tolleranti --------------------------------
create or replace function edu_stats_cliente(p_slug text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_cl edu_clienti%rowtype; v_out jsonb;
begin
  select * into v_cl from edu_clienti where slug = p_slug;
  if v_cl.id is null then return null; end if;
  if not (edu_e_admin() or v_cl.id = edu_mio_cliente()) then raise exception 'non autorizzato'; end if;

  with ev as (
    select e.*, coalesce(edu_bool(e.dettaglio->>'live'), false) as live,
           coalesce(edu_num(e.dettaglio->>'pct_classe'),
                    case when coalesce(edu_num(e.dettaglio->>'su'), 0) > 0
                         then round(100.0 * coalesce(edu_num(e.dettaglio->>'punti'), 0) / edu_num(e.dettaglio->>'su'))
                    end) as pct
    from edu_eventi e where e.cliente_id = v_cl.id
  ),
  cl as (select c.codice, c.nome, c.anno, c.scuola_id, s.nome as scuola
         from edu_classi c left join edu_scuole s on s.id = c.scuola_id
         where c.cliente_id = v_cl.id),
  per_classe as (
    select ev.codice_classe, max(cl.nome) as nome, max(cl.anno) as anno, max(cl.scuola) as scuola,
           count(*) filter (where tipo='lezione_avviata') as avviate,
           count(*) filter (where tipo='lezione_completata') as completate,
           count(*) filter (where tipo='quiz_esito') as quiz,
           count(*) filter (where tipo='quiz_esito' and live) as partite_live,
           round(avg(pct) filter (where tipo='quiz_esito'))::int as pct_medio,
           max(creato_il) as ultima
    from ev left join cl on cl.codice = ev.codice_classe group by ev.codice_classe),
  per_scuola as (
    select coalesce(max(cl.scuola),'—') as scuola,
           count(distinct ev.codice_classe) as classi,
           count(*) filter (where tipo='lezione_avviata') as avviate,
           count(*) filter (where tipo='lezione_completata') as completate,
           round(avg(pct) filter (where tipo='quiz_esito'))::int as pct_medio,
           max(creato_il) as ultima
    from ev left join cl on cl.codice = ev.codice_classe
    group by cl.scuola_id),
  per_lezione as (
    select lezione,
           count(*) filter (where tipo='lezione_avviata') as avviate,
           count(*) filter (where tipo='lezione_completata') as completate,
           count(*) filter (where tipo='quiz_esito') as quiz,
           round(avg(pct) filter (where tipo='quiz_esito'))::int as pct_medio
    from ev group by lezione),
  giorni as (
    select to_char(creato_il::date,'YYYY-MM-DD') as giorno, count(*) as n
    from ev where creato_il >= now() - interval '30 days' group by 1 order by 1)
  select jsonb_build_object(
    'cliente', jsonb_build_object('slug', v_cl.slug, 'nome', v_cl.nome, 'piano', v_cl.piano,
                                  'licenza_stato', v_cl.licenza_stato, 'licenza_fine', v_cl.licenza_fine),
    'totali', jsonb_build_object(
       'classi', (select count(distinct codice_classe) from ev where codice_classe <> 'ANON'),
       'scuole', (select count(*) from edu_scuole where cliente_id = v_cl.id),
       'avviate', (select count(*) from ev where tipo='lezione_avviata'),
       'completate', (select count(*) from ev where tipo='lezione_completata'),
       'quiz', (select count(*) from ev where tipo='quiz_esito'),
       'partite_live', (select count(*) from ev where tipo='quiz_esito' and live),
       'pct_medio', (select round(avg(pct))::int from ev where tipo='quiz_esito'),
       'ultimo_evento', (select max(creato_il) from ev)),
    'per_scuola',  coalesce((select jsonb_agg(to_jsonb(ps) order by ps.avviate desc) from per_scuola ps), '[]'::jsonb),
    'per_classe',  coalesce((select jsonb_agg(to_jsonb(pc) order by pc.ultima desc) from per_classe pc), '[]'::jsonb),
    'per_lezione', coalesce((select jsonb_agg(to_jsonb(pl) order by pl.avviate desc) from per_lezione pl), '[]'::jsonb),
    'ultimi_30gg', coalesce((select jsonb_agg(to_jsonb(g)) from giorni g), '[]'::jsonb)
  ) into v_out;
  return v_out;
end $$;
grant execute on function edu_stats_cliente(text) to authenticated;

-- ---- 3c/4. policy più strette su quello che anon può scrivere -------------
drop policy if exists eventi_anon_ins on edu_eventi;
create policy eventi_anon_ins on edu_eventi for insert to anon
  with check (char_length(coalesce(codice_classe,'')) between 1 and 20
              and codice_classe ~ '^[A-Z0-9-]+$'
              and tipo in ('lezione_avviata','lezione_completata','quiz_esito')
              and pg_column_size(coalesce(dettaglio, '{}'::jsonb)) < 4000);

drop policy if exists richieste_anon_ins on edu_richieste;
create policy richieste_anon_ins on edu_richieste for insert to anon
  with check (length(scuola) between 2 and 120
              and length(email) between 5 and 120
              and stato = 'nuova'
              and cliente_id is null
              and length(coalesce(referente, '')) <= 120
              and length(coalesce(telefono,  '')) <= 40
              and length(coalesce(interesse, '')) <= 40
              and length(coalesce(messaggio, '')) <= 1000);

-- ---- 2. viste: nessuna lettura diretta, e con i privilegi di chi chiama ----
do $v$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'v'
              and (c.relname like 'v\_edu\_%' or c.relname like 'edu\_v\_%')
  loop
    execute format('revoke all on %I from public, anon, authenticated', r.relname);
    execute format('alter view %I set (security_invoker = true)', r.relname);
  end loop;
end $v$;

-- ---- 1. funzioni: elenco esplicito per anon -------------------------------
do $f$
declare r record;
begin
  for r in select p.oid::regprocedure as f, p.proname
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname like 'edu\_%'
  loop
    execute format('revoke all on function %s from public, anon', r.f);
    if r.proname <> 'edu_abbonamento_evento' then
      execute format('grant execute on function %s to authenticated, service_role', r.f);
    end if;
  end loop;
  /* quello che il player e le pagine pubbliche chiamano con la anon key */
  for r in select p.oid::regprocedure as f
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in (
              'edu_get_cliente', 'edu_get_corsi', 'edu_get_lezione_tenant',
              'edu_get_lezione_token', 'edu_get_lezioni', 'edu_get_mascotte',
              'edu_classe_stato', 'edu_diario_classe', 'edu_salva_esito',
              'edu_compito_apri', 'edu_compito_valuta',
              'edu_licenza_attiva', 'edu_piano_limiti',
              'edu_num', 'edu_bool')
  loop
    execute format('grant execute on function %s to anon', r.f);
  end loop;
end $f$;

-- ---- controllo finale: se qualcosa è rimasto aperto, la migrazione fallisce ----
do $c$
declare n int;
begin
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = 'public' and c.relkind = 'v'
     and (c.relname like 'v\_edu\_%' or c.relname like 'edu\_v\_%')
     and has_table_privilege('anon', c.oid, 'select');
  if n > 0 then raise exception 'anon legge ancora % viste edu', n; end if;
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public' and p.proname in ('edu_assembla_lezione','edu_stats_cliente','edu_report_mio_cliente','edu_me','edu_duplica_corso')
     and has_function_privilege('anon', p.oid, 'execute');
  if n > 0 then raise exception 'anon esegue ancora % funzioni riservate', n; end if;
end $c$;
