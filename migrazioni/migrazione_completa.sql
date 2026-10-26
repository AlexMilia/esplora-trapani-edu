-- ============================================================
-- ESPLORA TRAPANI EDU — MIGRAZIONE COMPLETA · 23/09/2026
-- Un file solo: 19 → 19b → 20 → … → 29 → 30 (abbonamenti Stripe) → 31 (elenco clienti per il catalogo).
-- Costruito e collaudato su una replica ESATTA dello schema di produzione
-- (esportato dall'information_schema il 23/09/2026).
-- Idempotente: le parti già applicate (19, 19b) non fanno nulla.
-- Supabase lo esegue in un blocco unico: o passa tutto, o non cambia nulla.
-- Dopo l'esecuzione: cancellare app/dati/cache_*.json sul server.
-- ============================================================



-- ################################################################
-- ##  migrazione_19_prologo.sql
-- ################################################################

-- ============================================================
-- SALE IN CLASSE — Migrazione 19 · 26/08/2026
-- "Intro del corso": prologo a schermo intero all'avvio lezione.
-- Aggiunge edu_lezioni.prologo e lo espone in edu_assembla_lezione.
-- INCLUDE anche i campi della migrazione 18 (quiz: spiegazione,
-- media_spiegazione, v): eseguirla da sola basta, l'ordine 18→19
-- resta comunque sicuro. Idempotente.
-- DOPO: cancellare dati/cache_*.json sul server (o attendere 5').
-- ============================================================

alter table edu_lezioni
  add column if not exists prologo text;

comment on column edu_lezioni.prologo is
  'Intro del corso: testo a schermo intero mostrato all''avvio della lezione, prima di Coccio. Righe preservate. Vuoto = nessun prologo.';

CREATE OR REPLACE FUNCTION public.edu_assembla_lezione(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (
    select id, ordine, tipo, guid, url, durata_s, video_lis,
           row_number() over (order by ordine, id) - 1 as v
    from edu_media where lezione_id = p_id
  )
  select jsonb_build_object(
    'id', l.slug,
    'uuid', l.id,
    'em', l.emoji,
    'cls', l.colore,
    'tit', l.titolo,
    'sub', l.sottotitolo,
    'durata', l.durata_label,
    'intro', l.intro,
    'prologo', nullif(trim(l.prologo), ''),
    'stato', l.stato,
    'coccio', l.video_coccio,
    'acc', coalesce(l.accessibilita, '{}'::jsonb)
           || jsonb_build_object('lis_clip', (select count(*) from m where nullif(trim(m.video_lis),'') is not null),
                                 'n_clip',   (select count(*) from m)),
    'video', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'tipo', m.tipo, 'guid', m.guid, 'url', m.url, 'durata_s', m.durata_s,
                'lis', nullif(trim(m.video_lis),'')))
                order by m.v) from m), '[]'::jsonb),
    'tappe', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'v', m.v, 't', tp.t, 'cocciu', tp.cocciu, 'cocciu2', tp.cocciu2,
                'hotspots', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'yaw', h.yaw, 'pitch', h.pitch, 'em', h.em, 'tit', h.tit,
                    'txt', h.txt, 'txt2', h.txt2, 'foto', h.foto_url, 'audio', h.audio_url))
                    order by h.ordine, h.id), '[]'::jsonb)
                  from edu_hotspot h where h.tappa_id = tp.id)))
                order by tp.ordine, tp.t)
              from edu_tappe tp join m on m.id = tp.media_id
              where tp.lezione_id = p_id), '[]'::jsonb),
    'quiz',  coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'junior'), '[]'::jsonb),
    'quiz2', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'senior')
  )
  from edu_lezioni l where l.id = p_id;
$function$;


-- ################################################################
-- ##  migrazione_19b_allineamento.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_20_saas_fase1.sql
-- ################################################################

-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 20 · 02/09/2026 · FASE 1 SaaS
-- Gerarchia: CLIENTE (tenant + licenza) → CORSO → LEZIONE
-- Decisioni (brainstorming 02/09): tenant nel path /edu/{slug}/,
-- prologo sul CORSO, licenza con date libere decise dal superadmin,
-- docenti con login e statistiche, piattaforma "Esplora Trapani Edu".
--
-- Additiva e idempotente: NON rompe il player attuale (progetto resta
-- come alias legacy finché la Fase 2 non lo sostituisce con corso_id).
-- RLS e ruoli sono nella migrazione 21 (richiede una verifica prima).
-- ============================================================

-- ------------------------------------------------------------
-- 1. CLIENTI (tenant) con licenza incorporata
-- ------------------------------------------------------------
create table if not exists edu_clienti (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique,          -- /edu/{slug}/
  nome             text not null,
  progetto_legacy  text unique,                   -- vecchio $EDU_PROGETTO
  brand            jsonb not null default '{}'::jsonb,
                   -- {titolo, sottotitolo, logo_url, colore, mascotte:{nome,img}}
  piano            text not null default 'base'
                   check (piano in ('base','pro','premium')),
  licenza_stato    text not null default 'attiva'
                   check (licenza_stato in ('attiva','sospesa','scaduta')),
  licenza_inizio   date,
  licenza_fine     date,                          -- NULL = senza scadenza
  contatto_nome    text,
  contatto_email   text,
  note             text,
  creato_il        timestamptz not null default now()
);
comment on table edu_clienti is
  'Tenant di Esplora Trapani Edu: brand, licenza (date libere) e slug del path /edu/{slug}/';

-- licenza valida = stato attiva e (nessuna scadenza o non ancora scaduta)
create or replace function edu_licenza_attiva(p_cliente uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from edu_clienti c
    where c.id = p_cliente
      and c.licenza_stato = 'attiva'
      and (c.licenza_fine is null or c.licenza_fine >= current_date)
  );
$$;

-- ------------------------------------------------------------
-- 2. CORSI (contenitore di lezioni; il PROLOGO vive qui)
-- ------------------------------------------------------------
create table if not exists edu_corsi (
  id            uuid primary key default gen_random_uuid(),
  proprietario_id    uuid not null references edu_clienti(id) on delete cascade,
  slug          text not null,
  titolo        text not null,
  sottotitolo   text,
  descrizione   text,
  emoji         text default '🎓',
  colore        text default 'rosa',
  copertina_url text,
  fascia        text not null default 'entrambe'
                check (fascia in ('primaria','medie','entrambe')),
  prologo       text,                             -- Intro del corso (schermo intero)
  stato         text not null default 'bozza'
                check (stato in ('bozza','pubblicato','soon')),
  ordine        int not null default 0,
  creato_il     timestamptz not null default now(),
  unique (proprietario_id, slug)
);
comment on column edu_corsi.prologo is
  'Intro del corso: testo a schermo intero all''avvio della PRIMA lezione del corso. Sostituisce edu_lezioni.prologo (migr. 19, ora legacy).';

-- ------------------------------------------------------------
-- 3. LEZIONI → corso_id  ·  UTENTI → cliente_id  ·  EVENTI → cliente/corso
-- ------------------------------------------------------------
alter table edu_lezioni add column if not exists corso_id uuid references edu_corsi(id);
create index if not exists edu_lezioni_corso_idx on edu_lezioni(corso_id);

alter table edu_utenti add column if not exists cliente_id uuid references edu_clienti(id);
comment on column edu_utenti.cliente_id is
  'Tenant dell''utente. NULL = superadmin di piattaforma (Alessandro).';

alter table edu_eventi add column if not exists cliente_id uuid;
alter table edu_eventi add column if not exists corso_id   uuid;
create index if not exists edu_eventi_cliente_idx on edu_eventi(cliente_id, creato_il);

-- ------------------------------------------------------------
-- 4. CLASSI: registro dei codici classe per cliente (docenti con
--    login → statistiche della PROPRIA classe)
-- ------------------------------------------------------------
create table if not exists edu_classi (
  id            uuid primary key default gen_random_uuid(),
  cliente_id    uuid not null references edu_clienti(id) on delete cascade,
  codice        text not null,                    -- es. TP-IC12-5A (quello del ?classe=)
  nome          text,                             -- es. "5ª A · IC Pagoto"
  anno          text,                             -- es. "2026/27"
  docente_id    uuid,                             -- edu_utenti.id del docente (facoltativo)
  creato_il     timestamptz not null default now(),
  unique (cliente_id, codice)
);

-- ------------------------------------------------------------
-- 5. BACKFILL: i due progetti esistenti diventano clienti + corsi
-- ------------------------------------------------------------
insert into edu_clienti (slug, nome, progetto_legacy, brand, piano, licenza_inizio, note)
values
  ('salina-culcasi', 'Salina Culcasi', 'sale-in-classe',
   '{"titolo":"Sale in Classe","sottotitolo":"Salina Culcasi · Trapani","colore":"rosa","mascotte":{"nome":"Coccio di sale"}}'::jsonb,
   'premium', current_date, 'Cliente pilota. Licenza: date da definire con il cliente.'),
  ('esplora-trapani', 'Esplora Trapani', 'antichi-mestieri-trapani',
   '{"titolo":"Antichi Mestieri di Trapani","sottotitolo":"Esplora Trapani · Sale in Classe","colore":"oro"}'::jsonb,
   'premium', current_date, 'Tenant interno (produzioni proprie).')
on conflict (slug) do nothing;

-- corsi contenitore per le lezioni esistenti (SOLO se la colonna si chiama ancora
-- cliente_id: dopo la migrazione 26 diventa proprietario_id e i corsi esistono già)
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_name = 'edu_corsi' and column_name = 'proprietario_id') then
    raise notice 'edu_corsi senza proprietario_id: salto il backfill dei corsi';
    return;
  end if;
insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, emoji, colore, stato, ordine)
select c.id, 'la-salina', 'Alla scoperta della salina',
       'Il mestiere del salinaio e la vita della salina, raccontati da chi la vive',
       '🧂', 'rosa', 'pubblicato', 10
from edu_clienti c where c.slug = 'salina-culcasi'
on conflict (proprietario_id, slug) do nothing;

insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, emoji, colore, stato, ordine)
select c.id, 'antichi-mestieri', 'Antichi Mestieri di Trapani',
       'Salinaio, corallo, marmo, tappeti di Erice, vendemmia, olive',
       '🛠️', 'oro', 'pubblicato', 10
from edu_clienti c where c.slug = 'esplora-trapani'
on conflict (proprietario_id, slug) do nothing;

-- il NUOVO corso della salina, in bozza, con l'Intro del corso del cliente
insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, emoji, colore, fascia, stato, ordine, prologo)
select c.id, 'la-vita-della-goccia', 'La vita della goccia',
       'Dal mare al sale: il viaggio di una goccia fino alla cristallizzazione',
       '💧', 'oro', 'entrambe', 'bozza', 20,
       E'Da qualche parte, tra il mare e la terra, esiste un mondo fatto d''acqua, di vento e di Sole.\nUn mondo dove tutto sembra immobile…\ne invece, lentamente, tutto cambia.\nL''acqua si colora.\nIl mare si trasforma.\nE ciò che prima era invisibile, un giorno appare.\nPer scoprirne il segreto bisogna diventare piccoli. Piccolissimi.\nPiccoli come una goccia d''acqua.\nE lasciarsi trasportare… in un lungo viaggio,\ndal mare al sale.'
from edu_clienti c where c.slug = 'salina-culcasi'
on conflict (proprietario_id, slug) do nothing;

-- lezioni esistenti → corso del loro progetto (solo quelle ancora senza corso)
end $$;

update edu_lezioni l
   set corso_id = co.id
  from edu_clienti c join edu_corsi co on co.proprietario_id = c.id
 where l.corso_id is null
   and l.progetto = c.progetto_legacy
   and co.slug in ('la-salina','antichi-mestieri');

-- eventi storici → cliente (per i report)
update edu_eventi e
   set cliente_id = c.id
  from edu_clienti c
 where e.cliente_id is null and e.progetto = c.progetto_legacy;

-- ------------------------------------------------------------
-- 6. RPC del tenant (Fase 2 le userà api.php e il player)
-- ------------------------------------------------------------

-- brand + stato licenza del cliente, dallo slug del path
create or replace function edu_get_cliente(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'id', c.id, 'slug', c.slug, 'nome', c.nome, 'brand', c.brand,
    'piano', c.piano, 'licenza_stato', c.licenza_stato,
    'licenza_fine', c.licenza_fine, 'attiva', edu_licenza_attiva(c.id),
    'piattaforma', 'Esplora Trapani Edu')
  from edu_clienti c where c.slug = p_slug;
$$;

-- corsi pubblicati del cliente con i metadati delle lezioni (menu a 2 livelli)
create or replace function edu_get_corsi(p_cliente_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', co.slug, 'uuid', co.id, 'tit', co.titolo, 'sub', co.sottotitolo,
      'desc', co.descrizione, 'em', co.emoji, 'cls', co.colore,
      'copertina', co.copertina_url, 'fascia', co.fascia, 'stato', co.stato,
      'prologo', nullif(trim(co.prologo), ''),
      'lezioni', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'id', l.slug, 'em', l.emoji, 'cls', l.colore, 'tit', l.titolo,
                  'sub', l.sottotitolo, 'durata', l.durata_label, 'stato', l.stato,
                  'acc', coalesce(l.accessibilita, '{}'::jsonb))
                order by l.ordine)
         from edu_lezioni l
         where l.corso_id = co.id and l.owner is null and l.stato <> 'bozza'), '[]'::jsonb)
    ) order by co.ordine, co.titolo), '[]'::jsonb)
  from edu_corsi co join edu_clienti c on c.id = co.proprietario_id
  where c.slug = p_cliente_slug and co.stato <> 'bozza';
$$;

-- lezione completa per cliente+slug (riusa edu_assembla_lezione, aggiunge il corso)
create or replace function edu_get_lezione_tenant(p_cliente_slug text, p_lezione_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select edu_assembla_lezione(l.id)
         || jsonb_build_object('corso', jsonb_build_object(
              'id', co.slug, 'tit', co.titolo, 'prologo', nullif(trim(co.prologo), '')))
  from edu_lezioni l
  join edu_corsi co on co.id = l.corso_id
  join edu_clienti c on c.id = co.proprietario_id
  where c.slug = p_cliente_slug and l.slug = p_lezione_slug
    and l.owner is null and l.stato not in ('bozza','soon') and co.stato <> 'bozza'
  limit 1;
$$;

-- report per cliente (base della dashboard docente/superadmin)
create or replace view v_edu_report_cliente as
  select c.slug as cliente, e.codice_classe, e.lezione, e.tipo,
         count(*) as n, min(e.creato_il) as prima_volta, max(e.creato_il) as ultima_volta
  from edu_eventi e join edu_clienti c on c.id = e.cliente_id
  group by c.slug, e.codice_classe, e.lezione, e.tipo;

-- ------------------------------------------------------------
-- Verifica rapida dopo l'esecuzione:
--   select slug, nome, licenza_stato, edu_licenza_attiva(id) from edu_clienti;
--   select c.slug, co.slug, co.stato, count(l.id) lezioni
--     from edu_corsi co join edu_clienti c on c.id=co.proprietario_id
--     left join edu_lezioni l on l.corso_id=co.id group by 1,2,3 order by 1,2;
--   select edu_get_corsi('salina-culcasi');
-- ------------------------------------------------------------


-- ################################################################
-- ##  migrazione_21_ruoli_rls.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_22_rpc_tenant.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_23_rls_contenuti.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_24_prodotto.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_25_audio_clip.sql
-- ################################################################

-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 25 · 12/09/2026
-- "Il viaggio di una goccia": audio di sottofondo per clip,
-- gestito dalla regia e NON incollato nel video.
--   edu_media.audio_url   URL https diretto (Bunny Storage / B2)
--   edu_media.audio_vol   volume 0-100 (default 45: sottofondo)
--   edu_media.audio_loop  ripete finché la clip va avanti
--   edu_media.audio_duck  abbassa l'audio quando parla la mascotte,
--                         si apre una scoperta o legge la voce (ipovedenti)
-- Esposti in edu_assembla_lezione dentro video[].audio.
-- Idempotente. Dopo 19-24. Poi: cancellare dati/cache_*.json.
-- ============================================================

alter table edu_media
  add column if not exists audio_url  text,
  add column if not exists audio_vol  smallint default 45,
  add column if not exists audio_loop boolean default true,
  add column if not exists audio_duck boolean default true;

comment on column edu_media.audio_url is
  'Audio di sottofondo della clip (URL https diretto a .mp3/.m4a/.ogg). Vuoto = nessun sottofondo. Parte e si ferma con il video.';

-- il corso creato dalla migrazione 20 prende il nome definitivo
update edu_corsi
   set titolo = 'Il viaggio di una goccia',
       sottotitolo = 'Dal mare al sale: il viaggio di una goccia fino alla cristallizzazione'
 where slug = 'la-vita-della-goccia' and titolo = 'La vita della goccia';

CREATE OR REPLACE FUNCTION public.edu_assembla_lezione(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (
    select id, ordine, tipo, guid, url, durata_s, video_lis,
           audio_url, audio_vol, audio_loop, audio_duck,
           row_number() over (order by ordine, id) - 1 as v
    from edu_media where lezione_id = p_id
  )
  select jsonb_build_object(
    'id', l.slug,
    'uuid', l.id,
    'em', l.emoji,
    'cls', l.colore,
    'tit', l.titolo,
    'sub', l.sottotitolo,
    'durata', l.durata_label,
    'intro', l.intro,
    'prologo', nullif(trim(l.prologo), ''),
    'stato', l.stato,
    'coccio', l.video_coccio,
    'acc', coalesce(l.accessibilita, '{}'::jsonb)
           || jsonb_build_object('lis_clip', (select count(*) from m where nullif(trim(m.video_lis),'') is not null),
                                 'n_clip',   (select count(*) from m)),
    'video', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'tipo', m.tipo, 'guid', m.guid, 'url', m.url, 'durata_s', m.durata_s,
                'lis', nullif(trim(m.video_lis),''),
                'audio', case when nullif(trim(m.audio_url),'') is null then null
                         else jsonb_build_object(
                              'url',  trim(m.audio_url),
                              'vol',  coalesce(m.audio_vol, 45),
                              'loop', coalesce(m.audio_loop, true),
                              'duck', coalesce(m.audio_duck, true)) end))
                order by m.v) from m), '[]'::jsonb),
    'tappe', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'v', m.v, 't', tp.t, 'cocciu', tp.cocciu, 'cocciu2', tp.cocciu2,
                'hotspots', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'yaw', h.yaw, 'pitch', h.pitch, 'em', h.em, 'tit', h.tit,
                    'txt', h.txt, 'txt2', h.txt2, 'foto', h.foto_url, 'audio', h.audio_url))
                    order by h.ordine, h.id), '[]'::jsonb)
                  from edu_hotspot h where h.tappa_id = tp.id)))
                order by tp.ordine, tp.t)
              from edu_tappe tp join m on m.id = tp.media_id
              where tp.lezione_id = p_id), '[]'::jsonb),
    'quiz',  coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'junior'), '[]'::jsonb),
    'quiz2', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'senior')
  )
  from edu_lezioni l where l.id = p_id;
$function$;


-- ################################################################
-- ##  migrazione_26_catalogo_scuole.sql
-- ################################################################

-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 26 · 14/09/2026 · MODELLO CATALOGO
-- Decisioni (brainstorming 14/09):
--   • CATALOGO "stile Netflix": un corso esiste UNA volta sola e viene
--     concesso in licenza a più clienti (edu_catalogo). Ogni cliente ha
--     quindi corsi PROPRI (li modifica) e corsi IN LICENZA (li usa).
--   • Nuovo livello SCUOLA: Cliente → Scuola → Classe.
--   • Licenze su TRE livelli: account cliente + corso (accesso) + scuola.
--   • Mascotte per CORSO (non più per "progetto" legacy).
--   • "Corso" è l'unico nome; edu_lezioni.progetto va in pensione.
-- Additiva e idempotente. Dopo 19-25.
-- Rev. 17/09 (audit): ordinamento numerico dei corsi, lezioni servite solo
-- da corsi PUBBLICATI (non «prossimamente»), rimosso helper residuo.
-- DOPO l'esecuzione: cancellare dati/cache_*.json.
-- ============================================================

-- ------------------------------------------------------------
-- 1. CORSI: il proprietario (chi lo produce) + visibilità + mascotte
-- ------------------------------------------------------------
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_name='edu_corsi' and column_name='cliente_id')
     and not exists (select 1 from information_schema.columns
             where table_name='edu_corsi' and column_name='proprietario_id') then
    alter table edu_corsi rename column cliente_id to proprietario_id;
  end if;
end $$;

alter table edu_corsi
  add column if not exists visibilita text not null default 'privato',
  add column if not exists mascotte   jsonb,
  add column if not exists copia_di   uuid references edu_corsi(id) on delete set null;

do $$ begin
  alter table edu_corsi add constraint edu_corsi_visibilita_chk
    check (visibilita in ('privato','catalogo'));
exception when duplicate_object then null; end $$;

comment on column edu_corsi.proprietario_id is 'Cliente che POSSIEDE il corso: lo modifica e lo concede in licenza.';
comment on column edu_corsi.visibilita is 'privato = solo il proprietario · catalogo = concedibile ad altri clienti via edu_catalogo.';
comment on column edu_corsi.mascotte is 'Mascotte del corso: {nome, img, junior, senior, quiz_sempre}. Sostituisce la configurazione per "progetto".';

-- ------------------------------------------------------------
-- 2. CATALOGO: chi ha accesso a quale corso, con le sue date
-- ------------------------------------------------------------
create table if not exists edu_catalogo (
  id          uuid primary key default gen_random_uuid(),
  corso_id    uuid not null references edu_corsi(id)   on delete cascade,
  cliente_id  uuid not null references edu_clienti(id) on delete cascade,
  stato       text not null default 'attivo' check (stato in ('attivo','sospeso','scaduto')),
  da          date,
  a           date,                       -- NULL = senza scadenza
  note        text,
  creato_il   timestamptz not null default now(),
  unique (corso_id, cliente_id)
);
comment on table edu_catalogo is 'Licenze d''uso dei corsi: il corso resta uno solo, qui si dice CHI può usarlo e FINO A QUANDO.';
create index if not exists edu_catalogo_cliente_idx on edu_catalogo(cliente_id, stato);

create or replace function edu_catalogo_valido(p_corso uuid, p_cliente uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from edu_catalogo k
    where k.corso_id = p_corso and k.cliente_id = p_cliente
      and k.stato = 'attivo'
      and (k.da is null or k.da <= current_date)
      and (k.a  is null or k.a  >= current_date));
$$;

-- il cliente può USARE il corso? (proprietario, oppure licenza valida)
create or replace function edu_corso_accessibile(p_corso uuid, p_cliente uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_corsi co where co.id = p_corso and co.proprietario_id = p_cliente)
      or edu_catalogo_valido(p_corso, p_cliente);
$$;

-- ------------------------------------------------------------
-- 3. SCUOLE: Cliente → Scuola → Classe
-- ------------------------------------------------------------
create table if not exists edu_scuole (
  id             uuid primary key default gen_random_uuid(),
  cliente_id     uuid not null references edu_clienti(id) on delete cascade,
  nome           text not null,
  citta          text,
  referente      text,
  email          text,
  tipo           text not null default 'ospite' check (tipo in ('ospite','pagante')),
                 -- ospite = il cliente le offre l'accesso · pagante = licenza propria
  licenza_stato  text not null default 'attiva' check (licenza_stato in ('attiva','sospesa','scaduta')),
  licenza_da     date,
  licenza_a      date,                    -- NULL = come l'account del cliente
  note           text,
  creato_il      timestamptz not null default now()
);
create index if not exists edu_scuole_cliente_idx on edu_scuole(cliente_id);
comment on table edu_scuole is 'Istituti che usano i corsi di un cliente. "ospite" = invitata dal cliente; "pagante" = ha una propria licenza con date.';

alter table edu_classi add column if not exists scuola_id uuid references edu_scuole(id) on delete set null;
create index if not exists edu_classi_scuola_idx on edu_classi(scuola_id);

create or replace function edu_scuola_valida(p_scuola uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce((
    select s.licenza_stato = 'attiva'
       and (s.licenza_da is null or s.licenza_da <= current_date)
       and (s.licenza_a  is null or s.licenza_a  >= current_date)
    from edu_scuole s where s.id = p_scuola), true);   -- nessuna scuola = nessun vincolo
$$;

-- stato d'accesso di un codice classe (usato dal player quando c'è ?classe=)
create or replace function edu_classe_stato(p_cliente uuid, p_codice text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce((
    select jsonb_build_object(
      'classe', cl.codice, 'nome', cl.nome,
      'scuola', s.nome, 'scuola_id', s.id,
      'tipo', s.tipo, 'licenza_stato', s.licenza_stato, 'licenza_a', s.licenza_a,
      'valida', edu_scuola_valida(s.id))
    from edu_classi cl left join edu_scuole s on s.id = cl.scuola_id
    where cl.cliente_id = p_cliente and upper(cl.codice) = upper(p_codice)),
    jsonb_build_object('classe', p_codice, 'valida', true, 'scuola', null));  -- classe non registrata: ammessa
$$;

-- ------------------------------------------------------------
-- 4. BACKFILL: ogni corso entra nel catalogo del proprio proprietario
--    (così la regola d'accesso è una sola, anche per i corsi propri)
-- ------------------------------------------------------------
insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
select co.id, co.proprietario_id, 'attivo', current_date, 'Corso proprio (backfill migr. 26)'
from edu_corsi co
where co.proprietario_id is not null
on conflict (corso_id, cliente_id) do nothing;

-- i corsi prodotti da Esplora Trapani sono concedibili ad altri clienti
update edu_corsi co set visibilita = 'catalogo'
from edu_clienti c
where c.id = co.proprietario_id and c.slug = 'esplora-trapani' and co.visibilita = 'privato';

-- (mascotte dei corsi: travaso completo nella migrazione 28)

-- le classi nate PRIMA del SaaS non hanno il cliente: lo ricavo dal loro
-- "progetto" (colonna della vecchia tabella) o, in mancanza, dagli eventi
do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'edu_classi' and column_name = 'progetto') then
    update edu_classi cl set cliente_id = c.id
      from edu_clienti c
     where cl.cliente_id is null and c.progetto_legacy = cl.progetto;
  end if;
  update edu_classi cl set cliente_id = sub.id
    from (select e.codice_classe, c.id, row_number() over (partition by e.codice_classe order by count(*) desc) rn
            from edu_eventi e join edu_clienti c on c.progetto_legacy = e.progetto
           group by e.codice_classe, c.id) sub
   where cl.cliente_id is null and sub.codice_classe = cl.codice and sub.rn = 1;
  -- chi resta senza cliente (nessun evento, nessun progetto) va al primo cliente legacy
  update edu_classi cl set cliente_id = (select id from edu_clienti where progetto_legacy is not null order by slug limit 1)
   where cl.cliente_id is null;
end $$;

-- scuola "Da assegnare" per le classi già esistenti, così nulla resta orfano
insert into edu_scuole (cliente_id, nome, tipo, note)
select distinct cl.cliente_id, 'Da assegnare', 'ospite', 'Creata dalla migrazione 26: sposta qui le classi nella scuola giusta.'
from edu_classi cl
where cl.scuola_id is null and cl.cliente_id is not null
  and not exists (select 1 from edu_scuole s where s.cliente_id = cl.cliente_id and s.nome = 'Da assegnare');

update edu_classi cl
   set scuola_id = s.id
  from edu_scuole s
 where cl.scuola_id is null and s.cliente_id = cl.cliente_id and s.nome = 'Da assegnare';

-- ------------------------------------------------------------
-- 5. RPC DEL PLAYER (rifatte sul nuovo modello)
-- ------------------------------------------------------------

-- corsi visibili al cliente: propri + in licenza, con 'origine' e stato
create or replace function edu_get_corsi(p_cliente_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  with cl as (select id from edu_clienti where slug = p_cliente_slug)
  select coalesce(jsonb_agg(x order by (x->>'ordine')::int, x->>'tit'), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', co.slug, 'uuid', co.id, 'tit', co.titolo, 'sub', co.sottotitolo,
      'desc', co.descrizione, 'em', co.emoji, 'cls', co.colore,
      'copertina', co.copertina_url, 'fascia', co.fascia, 'stato', co.stato,
      'ordine', co.ordine,
      'prologo', nullif(trim(co.prologo), ''),
      'mascotte', co.mascotte,
      'origine', case when co.proprietario_id = (select id from cl) then 'proprio' else 'licenza' end,
      'licenza_a', (select k.a from edu_catalogo k where k.corso_id = co.id and k.cliente_id = (select id from cl)),
      'lezioni', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'id', l.slug, 'em', l.emoji, 'cls', l.colore, 'tit', l.titolo,
                  'sub', l.sottotitolo, 'durata', l.durata_label, 'stato', l.stato,
                  'acc', coalesce(l.accessibilita, '{}'::jsonb))
                order by l.ordine)
         from edu_lezioni l
         where l.corso_id = co.id and l.owner is null and l.stato <> 'bozza'), '[]'::jsonb)
    ) as x
    from edu_corsi co
    where co.stato <> 'bozza'
      and edu_catalogo_valido(co.id, (select id from cl))
  ) t;
$$;

-- lezione completa: serve una licenza valida sul corso che la contiene
create or replace function edu_get_lezione_tenant(p_cliente_slug text, p_lezione_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select edu_assembla_lezione(l.id)
         || jsonb_build_object('corso', jsonb_build_object(
              'id', co.slug, 'uuid', co.id, 'tit', co.titolo,
              'prologo', nullif(trim(co.prologo), ''),
              'mascotte', co.mascotte))
  from edu_lezioni l
  join edu_corsi co on co.id = l.corso_id
  join edu_clienti c on c.slug = p_cliente_slug
  where l.slug = p_lezione_slug
    and l.owner is null and l.stato not in ('bozza','soon') and co.stato = 'pubblicato'
    and edu_catalogo_valido(co.id, c.id)
  limit 1;
$$;

grant execute on function edu_get_corsi(text), edu_get_lezione_tenant(text, text),
  edu_catalogo_valido(uuid, uuid), edu_corso_accessibile(uuid, uuid),
  edu_scuola_valida(uuid), edu_classe_stato(uuid, text) to anon, authenticated;

-- ------------------------------------------------------------
-- 6. DUPLICAZIONE DI UN CORSO (quando serve una copia modificabile)
-- ------------------------------------------------------------
create or replace function edu_duplica_corso(p_corso uuid, p_cliente_dest uuid, p_nuovo_slug text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  v_new uuid; v_slug text; v_lez record; v_newlez uuid; v_map jsonb := '{}'::jsonb;
  v_tp record; v_newtp uuid; v_m record; v_newm uuid;
begin
  if not (edu_e_admin() or exists (select 1 from edu_utenti u where u.id = auth.uid()
          and u.ruolo = 'editor' and u.cliente_id = p_cliente_dest)) then
    raise exception 'non autorizzato a duplicare in questo cliente';
  end if;
  select coalesce(p_nuovo_slug, slug) into v_slug from edu_corsi where id = p_corso;
  while exists (select 1 from edu_corsi co where co.proprietario_id = p_cliente_dest and co.slug = v_slug) loop
    v_slug := v_slug || '-copia';
  end loop;

  insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, descrizione, emoji, colore,
                         copertina_url, fascia, prologo, stato, ordine, mascotte, visibilita, copia_di)
  select p_cliente_dest, v_slug, titolo, sottotitolo, descrizione, emoji, colore,
         copertina_url, fascia, prologo, 'bozza', ordine, mascotte, 'privato', id
  from edu_corsi where id = p_corso
  returning id into v_new;

  insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
  values (v_new, p_cliente_dest, 'attivo', current_date, 'Copia creata il ' || current_date)
  on conflict do nothing;

  for v_lez in select * from edu_lezioni where corso_id = p_corso and owner is null loop
    insert into edu_lezioni (slug, titolo, sottotitolo, progetto, stato, ordine, emoji, colore,
                             durata_label, intro, prologo, video_coccio, accessibilita, corso_id)
    values (v_lez.slug, v_lez.titolo, v_lez.sottotitolo, v_lez.progetto, 'bozza', v_lez.ordine, v_lez.emoji,
            v_lez.colore, v_lez.durata_label, v_lez.intro, v_lez.prologo, v_lez.video_coccio,
            v_lez.accessibilita, v_new)
    returning id into v_newlez;

    v_map := '{}'::jsonb;
    for v_m in select * from edu_media where lezione_id = v_lez.id order by ordine loop
      insert into edu_media (lezione_id, ordine, tipo, guid, url, durata_s, video_lis,
                             audio_url, audio_vol, audio_loop, audio_duck)
      values (v_newlez, v_m.ordine, v_m.tipo, v_m.guid, v_m.url, v_m.durata_s, v_m.video_lis,
              v_m.audio_url, v_m.audio_vol, v_m.audio_loop, v_m.audio_duck)
      returning id into v_newm;
      v_map := v_map || jsonb_build_object(v_m.id::text, v_newm::text);
    end loop;

    for v_tp in select * from edu_tappe where lezione_id = v_lez.id order by ordine loop
      insert into edu_tappe (lezione_id, media_id, t, ordine, cocciu, cocciu2)
      values (v_newlez, nullif(v_map->>v_tp.media_id::text,'')::uuid, v_tp.t, v_tp.ordine, v_tp.cocciu, v_tp.cocciu2)
      returning id into v_newtp;
      insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, foto_url, audio_url, ordine)
      select v_newtp, yaw, pitch, em, tit, txt, txt2, foto_url, audio_url, ordine
      from edu_hotspot where tappa_id = v_tp.id;
    end loop;

    insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine, spiegazione, media_spiegazione, v)
    select v_newlez, livello, domanda, opzioni, ok, ordine, spiegazione, media_spiegazione, v
    from edu_quiz where lezione_id = v_lez.id;
  end loop;

  return v_new;
end $$;

drop function if exists cliente_id_dummy();

grant execute on function edu_duplica_corso(uuid, uuid, text) to authenticated;

-- ------------------------------------------------------------
-- 7. STATISTICHE: livello SCUOLA (oltre a classe e lezione)
-- ------------------------------------------------------------
create or replace function edu_stats_cliente(p_slug text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_cl edu_clienti%rowtype; v_out jsonb;
begin
  select * into v_cl from edu_clienti where slug = p_slug;
  if v_cl.id is null then return null; end if;
  if not (edu_e_admin() or v_cl.id = edu_mio_cliente()) then raise exception 'non autorizzato'; end if;

  with ev as (
    select e.*, (e.dettaglio->>'live')::boolean as live,
           coalesce(nullif(e.dettaglio->>'pct_classe','')::numeric,
                    case when nullif(e.dettaglio->>'su','') is not null
                              and (e.dettaglio->>'su')::numeric > 0
                         then round(100.0 * (e.dettaglio->>'punti')::numeric / (e.dettaglio->>'su')::numeric)
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

-- ------------------------------------------------------------
-- 8. RLS sulle nuove tabelle e aggiornamento di quelle esistenti
-- ------------------------------------------------------------
-- NOTA: le policy NON fanno sotto-query incrociate fra edu_corsi ed
-- edu_catalogo (si innescherebbe una ricorsione infinita: la policy di
-- una tabella interroga l'altra e viceversa). Tutti i controlli passano
-- da funzioni SECURITY DEFINER, che leggono le tabelle senza riattivare
-- le policy del chiamante.

create or replace function edu_sono_proprietario(p_corso uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_corsi co where co.id = p_corso and co.proprietario_id = edu_mio_cliente());
$$;

create or replace function edu_ho_licenza(p_corso uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_catalogo k where k.corso_id = p_corso and k.cliente_id = edu_mio_cliente());
$$;

create or replace function edu_sono_editor()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from edu_utenti u where u.id = auth.uid() and u.ruolo in ('editor','admin'));
$$;

alter table edu_scuole enable row level security;
drop policy if exists scuole_tenant on edu_scuole;
create policy scuole_tenant on edu_scuole for all to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente())
  with check (edu_e_admin() or cliente_id = edu_mio_cliente());

alter table edu_catalogo enable row level security;
drop policy if exists catalogo_sel on edu_catalogo;
create policy catalogo_sel on edu_catalogo for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente() or edu_sono_proprietario(corso_id));
drop policy if exists catalogo_admin on edu_catalogo;
create policy catalogo_admin on edu_catalogo for all to authenticated
  using (edu_e_admin() or (edu_sono_proprietario(corso_id) and edu_sono_editor()))
  with check (edu_e_admin() or (edu_sono_proprietario(corso_id) and edu_sono_editor()));

-- corsi: le policy della migr. 21 usavano cliente_id → rifatte su proprietario_id
drop policy if exists corsi_sel on edu_corsi;
create policy corsi_sel on edu_corsi for select to authenticated
  using (edu_e_admin() or proprietario_id = edu_mio_cliente() or edu_ho_licenza(id));
drop policy if exists corsi_write on edu_corsi;
create policy corsi_write on edu_corsi for all to authenticated
  using (edu_e_admin() or (proprietario_id = edu_mio_cliente() and edu_sono_editor()))
  with check (edu_e_admin() or (proprietario_id = edu_mio_cliente() and edu_sono_editor()));

-- lezioni: "mia" = del mio cliente (proprietario del corso), in licenza (sola
-- lettura) o mia copia personale
create or replace function edu_lezione_mia(p_lezione uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or exists (select 1 from edu_lezioni l where l.id = p_lezione and l.owner = auth.uid())
      or exists (select 1 from edu_lezioni l join edu_corsi co on co.id = l.corso_id
                 where l.id = p_lezione and co.proprietario_id = edu_mio_cliente())
      or exists (select 1 from edu_lezioni l join edu_catalogo k on k.corso_id = l.corso_id
                 where l.id = p_lezione and k.cliente_id = edu_mio_cliente());
$$;

-- scrivibile SOLO se il mio cliente è il proprietario del corso
-- (i corsi ricevuti in licenza non si modificano: si duplicano)
create or replace function edu_lezione_scrivibile(p_lezione uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or exists (select 1 from edu_lezioni l where l.id = p_lezione and l.owner = auth.uid())
      or exists (select 1 from edu_lezioni l join edu_corsi co on co.id = l.corso_id
                 join edu_utenti u on u.id = auth.uid()
                 where l.id = p_lezione and co.proprietario_id = u.cliente_id and u.ruolo = 'editor');
$$;

create or replace function edu_corso_scrivibile(p_corso uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select edu_e_admin()
      or (p_corso is not null and exists (
            select 1 from edu_corsi co join edu_utenti u on u.id = auth.uid()
            where co.id = p_corso and co.proprietario_id = u.cliente_id and u.ruolo = 'editor'));
$$;

-- ------------------------------------------------------------
-- 9. PERMESSI sulle tabelle nuove (i GRANT generici sono stati dati
--    prima che queste tabelle esistessero)
-- ------------------------------------------------------------
grant select, insert, update, delete on edu_scuole, edu_catalogo to authenticated;
grant execute on function edu_sono_proprietario(uuid), edu_ho_licenza(uuid), edu_sono_editor(),
  edu_lezione_mia(uuid), edu_lezione_scrivibile(uuid), edu_corso_scrivibile(uuid) to authenticated;

-- ------------------------------------------------------------
-- Verifica rapida:
--   select slug, visibilita, (select count(*) from edu_catalogo k where k.corso_id=co.id) licenze
--     from edu_corsi co order by slug;
--   select edu_get_corsi('salina-culcasi');
-- ------------------------------------------------------------


-- ################################################################
-- ##  migrazione_27_sicurezza.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_28_mascotte_corso.sql
-- ################################################################

-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 28 · 17/09/2026
-- MASCOTTE PER CORSO, completa (nome, immagine, fasce, video dei momenti).
-- Travasa nel jsonb edu_corsi.mascotte la configurazione del vecchio
-- "progetto" (edu_progetti + edu_mascotte) per i corsi che ne hanno una,
-- così i corsi esistenti conservano Coccio con tutti i suoi video.
-- Da qui in poi la mascotte si gestisce nell'editor del corso; il
-- pannello «Mascotte & progetti» resta solo come sorgente da importare.
-- Idempotente (non sovrascrive mascotte già complete). Dopo la 26.
-- Struttura: {nome, img, junior, senior, quiz_sempre,
--             video:{entrambi:{chiave:src}, junior:{...}, senior:{...}}}
-- chiavi: inizio_corso, fine_lezione, fine_corso, giusta, sbagliata
-- ============================================================
do $$
begin
  if not exists (select 1 from information_schema.tables where table_name = 'edu_progetti')
     or not exists (select 1 from information_schema.tables where table_name = 'edu_mascotte') then
    raise notice 'edu_progetti/edu_mascotte assenti: nessun travaso (i corsi partono senza mascotte)';
    return;
  end if;

  update edu_corsi co
     set mascotte = jsonb_build_object(
       'nome',        coalesce(p.mascotte_nome, ''),
       'img',         coalesce(p.mascotte_img, ''),
       'junior',      coalesce(p.mascotte_junior, true),
       'senior',      coalesce(p.mascotte_senior, true),
       'quiz_sempre', coalesce(p.quiz_sempre, true),
       'video', jsonb_build_object(
         'entrambi', coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'entrambi' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb),
         'junior',   coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'junior' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb),
         'senior',   coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'senior' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb)))
    from edu_clienti c
    join edu_progetti p on p.progetto = c.progetto_legacy
   where c.id = co.proprietario_id
     and (co.mascotte is null or co.mascotte->'video' is null);   -- solo dove manca
end $$;

comment on column edu_corsi.mascotte is
  'Mascotte del corso: {nome,img,junior,senior,quiz_sempre,video:{entrambi|junior|senior:{inizio_corso,fine_lezione,fine_corso,giusta,sbagliata}}}. Gestita nell''editor del corso.';


-- ################################################################
-- ##  migrazione_29_rls_consolidata.sql
-- ################################################################

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


-- ################################################################
-- ##  migrazione_30_abbonamenti.sql
-- ################################################################

-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 30 · 24/09/2026 · ABBONAMENTI STRIPE (Fase 2)
-- Il player legge la licenza da edu_clienti: Stripe deve solo scriverci.
--   edu_clienti.abbonamento_*   stato dell'abbonamento (specchio di Stripe)
--   edu_pagamenti               storico eventi/pagamenti (idempotente per evento)
--   edu_abbonamento_evento()    unica porta di scrittura, riservata al webhook
--                               (service role): applica l'evento e allinea la licenza
-- Idempotente. Dopo la 29.
-- ============================================================

alter table edu_clienti
  add column if not exists stripe_customer_id     text,
  add column if not exists stripe_subscription_id text,
  add column if not exists abbonamento_stato      text not null default 'nessuno',
  add column if not exists abbonamento_piano      text,
  add column if not exists abbonamento_periodo    text,
  add column if not exists abbonamento_fine       timestamptz,
  add column if not exists abbonamento_annulla_a_fine boolean not null default false,
  add column if not exists abbonamento_link       text,
  add column if not exists abbonamento_aggiornato timestamptz;

do $$ begin
  alter table edu_clienti add constraint edu_clienti_abb_stato_chk
    check (abbonamento_stato in ('nessuno','in_attesa','attivo','in_pausa','insoluto','annullato','scaduto'));
exception when duplicate_object then null; end $$;
create unique index if not exists edu_clienti_stripe_sub_idx on edu_clienti(stripe_subscription_id) where stripe_subscription_id is not null;

create table if not exists edu_pagamenti (
  id                     uuid primary key default gen_random_uuid(),
  cliente_id             uuid references edu_clienti(id) on delete set null,
  stripe_evento_id       text unique,
  tipo                   text not null,           -- invoice.paid, invoice.payment_failed, customer.subscription.updated, …
  stripe_invoice_id      text,
  stripe_subscription_id text,
  importo_cent           integer,
  valuta                 text,
  periodo_da             timestamptz,
  periodo_a              timestamptz,
  stato                  text,                    -- paid, open, void, uncollectible, …
  link_fattura           text,
  dettaglio              jsonb,
  creato_il              timestamptz not null default now()
);
create index if not exists edu_pagamenti_cliente_idx on edu_pagamenti(cliente_id, creato_il desc);
alter table edu_pagamenti enable row level security;
drop policy if exists pagamenti_sel on edu_pagamenti;
create policy pagamenti_sel on edu_pagamenti for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());
revoke all on edu_pagamenti from anon;
grant select on edu_pagamenti to authenticated;

-- ------------------------------------------------------------
-- RPC riservata al webhook (service role). Applica UN evento Stripe:
-- registra in edu_pagamenti (idempotente) e allinea edu_clienti + licenza.
-- p_evento: { id, tipo, subscription, customer, invoice, importo_cent, valuta,
--             periodo_da, periodo_a, stato_sub, pausa (bool), cancel_at_period_end (bool),
--             link, stato_invoice, cliente_id (metadata) }
-- ------------------------------------------------------------
create or replace function edu_abbonamento_evento(p_evento jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_id uuid; v_tipo text := p_evento->>'tipo'; v_sub text := p_evento->>'subscription';
  v_cliente uuid; v_nuovo_stato text; v_fine timestamptz; v_lic text;
begin
  -- 1. il cliente: dal metadata, altrimenti dall'abbonamento, altrimenti dal customer
  v_cliente := nullif(p_evento->>'cliente_id','')::uuid;
  if v_cliente is null and v_sub is not null then
    select id into v_cliente from edu_clienti where stripe_subscription_id = v_sub;
  end if;
  if v_cliente is null and (p_evento->>'customer') is not null then
    select id into v_cliente from edu_clienti where stripe_customer_id = p_evento->>'customer';
  end if;

  -- cliente sconosciuto: NON registro (Stripe ritenta: al retry il cliente potrebbe esserci)
  if v_cliente is null then
    return jsonb_build_object('ok', false, 'err', 'cliente non trovato');
  end if;

  -- 2. storico (idempotente per evento)
  insert into edu_pagamenti (cliente_id, stripe_evento_id, tipo, stripe_invoice_id, stripe_subscription_id,
                             importo_cent, valuta, periodo_da, periodo_a, stato, link_fattura, dettaglio)
  values (v_cliente, p_evento->>'id', v_tipo, p_evento->>'invoice', v_sub,
          nullif(p_evento->>'importo_cent','')::int, p_evento->>'valuta',
          nullif(p_evento->>'periodo_da','')::timestamptz, nullif(p_evento->>'periodo_a','')::timestamptz,
          coalesce(p_evento->>'stato_invoice', p_evento->>'stato_sub'), p_evento->>'link', p_evento)
  on conflict (stripe_evento_id) do nothing
  returning id into v_id;
  if v_id is null and (p_evento->>'id') is not null then
    return jsonb_build_object('ok', true, 'gia_applicato', true);     -- evento già visto
  end if;

  -- 3. stato dell'abbonamento e della licenza
  v_fine := nullif(p_evento->>'periodo_a','')::timestamptz;
  if v_tipo = 'invoice.paid' then
    v_nuovo_stato := 'attivo'; v_lic := 'attiva';
  elsif v_tipo = 'invoice.payment_failed' then
    v_nuovo_stato := 'insoluto'; v_lic := null;          -- la licenza resta com'è fino a fine periodo
  elsif v_tipo = 'customer.subscription.deleted' then
    v_nuovo_stato := 'annullato'; v_lic := 'scaduta';
  elsif v_tipo in ('customer.subscription.updated','customer.subscription.created','customer.subscription.paused','customer.subscription.resumed') then
    if (p_evento->>'pausa')::boolean then v_nuovo_stato := 'in_pausa'; v_lic := 'sospesa';
    elsif (p_evento->>'stato_sub') = 'canceled' then v_nuovo_stato := 'annullato'; v_lic := 'scaduta';
    elsif (p_evento->>'stato_sub') in ('past_due','unpaid') then v_nuovo_stato := 'insoluto'; v_lic := null;
    elsif (p_evento->>'stato_sub') = 'active' then v_nuovo_stato := 'attivo'; v_lic := 'attiva';
    elsif (p_evento->>'stato_sub') in ('incomplete','trialing') then v_nuovo_stato := 'in_attesa'; v_lic := null;
    end if;
  end if;

  update edu_clienti set
    stripe_subscription_id = coalesce(v_sub, stripe_subscription_id),
    stripe_customer_id     = coalesce(p_evento->>'customer', stripe_customer_id),
    abbonamento_stato      = coalesce(v_nuovo_stato, abbonamento_stato),
    abbonamento_fine       = coalesce(v_fine, abbonamento_fine),
    abbonamento_annulla_a_fine = coalesce((p_evento->>'cancel_at_period_end')::boolean, abbonamento_annulla_a_fine),
    abbonamento_link       = coalesce(nullif(p_evento->>'link',''), abbonamento_link),
    abbonamento_aggiornato = now(),
    licenza_stato          = coalesce(v_lic, licenza_stato),
    licenza_fine           = case when v_lic = 'attiva' and v_fine is not null then v_fine::date
                                  when v_lic = 'scaduta' then least(coalesce(licenza_fine, current_date), current_date)
                                  else licenza_fine end
  where id = v_cliente;

  return jsonb_build_object('ok', true, 'cliente_id', v_cliente, 'stato', v_nuovo_stato, 'licenza', v_lic);
end $$;

-- solo il webhook (service role) può chiamarla
revoke all on function edu_abbonamento_evento(jsonb) from public, anon, authenticated;
grant execute on function edu_abbonamento_evento(jsonb) to service_role;

-- ------------------------------------------------------------
-- Lettura per la regia (admin): stato abbonamento del cliente + ultimi pagamenti
-- ------------------------------------------------------------
create or replace function edu_abbonamento_cliente(p_cliente uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select case when not edu_e_admin() then null else jsonb_build_object(
    'stato', c.abbonamento_stato, 'piano', c.abbonamento_piano, 'periodo', c.abbonamento_periodo,
    'fine', c.abbonamento_fine, 'annulla_a_fine', c.abbonamento_annulla_a_fine, 'link', c.abbonamento_link,
    'customer', c.stripe_customer_id, 'subscription', c.stripe_subscription_id, 'aggiornato', c.abbonamento_aggiornato,
    'pagamenti', coalesce((select jsonb_agg(jsonb_build_object('tipo', p.tipo, 'importo_cent', p.importo_cent, 'valuta', p.valuta,
                   'periodo_da', p.periodo_da, 'periodo_a', p.periodo_a, 'stato', p.stato, 'link', p.link_fattura, 'quando', p.creato_il)
                   order by p.creato_il desc) from (select * from edu_pagamenti where cliente_id = c.id order by creato_il desc limit 20) p), '[]'::jsonb))
  end
  from edu_clienti c where c.id = p_cliente;
$$;
grant execute on function edu_abbonamento_cliente(uuid) to authenticated;


-- ################################################################
-- ##  migrazione_31_elenco_clienti.sql
-- ################################################################

-- ============================================================================
-- MIGRAZIONE 31 — elenco minimo dei clienti per il pannello 🎞️ Catalogo
-- ----------------------------------------------------------------------------
-- Perché: con la RLS consolidata (migr. 29) un EDITOR legge solo il PROPRIO
-- cliente (clienti_sel = admin o id = edu_mio_cliente()). È giusto: i dati dei
-- clienti (contatti, note, Stripe) restano riservati. Ma «Chi può usarlo…»
-- deve permettere all'editor proprietario di un corso di concederlo o
-- duplicarlo verso un ALTRO cliente, quindi gli serve almeno id + nome
-- degli altri clienti. Questa RPC restituisce solo quello, solo a editor/admin.
-- Trovata rieseguendo t_flusso_tenant.sql (passo 7) sulla replica pulita.
-- Idempotente. Sicura da rilanciare.
-- ============================================================================
create or replace function edu_elenco_clienti()
returns table(id uuid, slug text, nome text)
language sql stable security definer
set search_path to 'public'
as $$
  select c.id, c.slug, c.nome
  from edu_clienti c
  where edu_sono_editor()            -- editor o admin; docenti e anonimi: nessuna riga
  order by c.nome
$$;
comment on function edu_elenco_clienti() is
  'Catalogo: elenco minimo (id, slug, nome) dei clienti, per concedere/duplicare un corso. Solo editor/admin.';
revoke all on function edu_elenco_clienti() from public;
revoke all on function edu_elenco_clienti() from anon;
grant execute on function edu_elenco_clienti() to authenticated;
