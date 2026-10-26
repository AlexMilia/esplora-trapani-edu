-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 19b · 23/09/2026 · ALLINEAMENTO
-- Da eseguire PRIMA della 20 (dopo la 19).
-- In produzione edu_eventi ed edu_classi esistono già, nate con la
-- prima versione della piattaforma (agosto 2026), con colonne diverse
-- da quelle che le migrazioni 20-28 si aspettano. Questa migrazione
-- AGGIUNGE le colonne mancanti e travasa i dati: non cancella nulla,
-- non rinomina nulla, le viste e i report vecchi continuano a funzionare.
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. edu_eventi: serve creato_il (timestamp dell'evento)
-- ------------------------------------------------------------
do $$
declare v_col text;
begin
  if not exists (select 1 from information_schema.tables where table_name = 'edu_eventi') then
    raise notice 'edu_eventi assente: verrà creata dalla migrazione 20';
    return;
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'edu_eventi' and column_name = 'creato_il') then
    alter table edu_eventi add column creato_il timestamptz not null default now();
    -- travaso dalla colonna data esistente, qualunque nome abbia
    select column_name into v_col
      from information_schema.columns
     where table_name = 'edu_eventi' and column_name <> 'creato_il'
       and data_type in ('timestamp with time zone', 'timestamp without time zone')
     order by ordinal_position limit 1;
    if v_col is not null then
      execute format('update edu_eventi set creato_il = %I where %I is not null', v_col, v_col);
      raise notice 'edu_eventi.creato_il travasata da %', v_col;
    else
      raise notice 'edu_eventi: nessuna colonna data esistente, creato_il parte da adesso';
    end if;
  end if;
end $$;

-- ------------------------------------------------------------
-- 2. edu_classi: id, cliente_id, nome, anno, docente_id, creato_il
--    (le colonne originali istituto/comune/livello restano)
-- ------------------------------------------------------------
do $$
declare v_col text;
begin
  if not exists (select 1 from information_schema.tables where table_name = 'edu_classi') then
    raise notice 'edu_classi assente: verrà creata dalla migrazione 20';
    return;
  end if;

  -- id: la regia aggiorna e cancella per id
  if not exists (select 1 from information_schema.columns where table_name = 'edu_classi' and column_name = 'id') then
    alter table edu_classi add column id uuid default gen_random_uuid();
    update edu_classi set id = gen_random_uuid() where id is null;
    alter table edu_classi alter column id set not null;
    alter table edu_classi add constraint edu_classi_id_unique unique (id);
  end if;

  alter table edu_classi add column if not exists cliente_id uuid;
  alter table edu_classi add column if not exists nome       text;
  alter table edu_classi add column if not exists anno       text;
  alter table edu_classi add column if not exists docente_id uuid;
  alter table edu_classi add column if not exists creato_il  timestamptz not null default now();

  -- anno: da anno_scolastico, se c'è
  if exists (select 1 from information_schema.columns where table_name = 'edu_classi' and column_name = 'anno_scolastico') then
    update edu_classi set anno = coalesce(anno, nullif(trim(anno_scolastico), ''));
  end if;
  -- nome: dall'istituto, se c'è
  if exists (select 1 from information_schema.columns where table_name = 'edu_classi' and column_name = 'istituto') then
    update edu_classi set nome = coalesce(nome, nullif(trim(istituto), ''));
  end if;
  -- creato_il: dalla colonna data esistente, se c'è
  select column_name into v_col
    from information_schema.columns
   where table_name = 'edu_classi' and column_name <> 'creato_il'
     and data_type in ('timestamp with time zone', 'timestamp without time zone')
   order by ordinal_position limit 1;
  if v_col is not null then
    execute format('update edu_classi set creato_il = %I where %I is not null', v_col, v_col);
  end if;

  -- vincolo che la regia si aspetta (un codice per cliente)
  if not exists (select 1 from pg_constraint where conname = 'edu_classi_cliente_codice_key') then
    begin
      alter table edu_classi add constraint edu_classi_cliente_codice_key unique (cliente_id, codice);
    exception when others then
      raise notice 'edu_classi: vincolo (cliente_id, codice) non aggiunto: %', sqlerrm;
    end;
  end if;
end $$;

-- ------------------------------------------------------------
-- 3. Le classi esistenti vengono agganciate al cliente giusto dalla
--    migrazione 20 (backfill per progetto). Qui solo un promemoria:
--    select codice, istituto, cliente_id from edu_classi;
-- ------------------------------------------------------------
