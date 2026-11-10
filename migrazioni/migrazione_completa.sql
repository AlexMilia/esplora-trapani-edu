-- ============================================================
-- ESPLORA TRAPANI EDU — MIGRAZIONE COMPLETA · 23/09/2026
-- Un file solo: 19 → 19b → 20 → … → 30 (abbonamenti Stripe) → 31 (elenco clienti) → 32 (blocco didattico) → 33 → 34 → 35 (tagli della clip, luogo) → 36 (area Trapani).
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


-- ################################################################
-- ##  migrazione_32_didattica.sql
-- ################################################################

-- ============================================================================
-- MIGRAZIONE 32 — BLOCCO DIDATTICO
-- ----------------------------------------------------------------------------
-- Chiude i tre buchi che impediscono a una scuola di adottare la piattaforma:
--
--  (a) BUCO DIDATTICO-AMMINISTRATIVO
--      · edu_corsi.didattica / edu_lezioni.didattica (jsonb): traguardi e
--        obiettivi delle Indicazioni Nazionali, UDA, guida per il docente
--        (prima/durante/dopo), materiali. Esposti al player e alla regia.
--      · edu_esiti: l'esito di una lezione diventa una RIGA CITABILE, che il
--        docente esporta e allega alla valutazione. Finora il quiz live viveva
--        solo in un file temporaneo e scompariva a partita finita.
--
--  (b) BUCO DELLA FREQUENZA
--      · edu_diario_classe(): la classe vede il percorso fatto e cosa resta.
--      · edu_compiti: compito a casa su una clip, con link a codice proprio,
--        correzione lato server e esito che rientra nel registro degli esiti.
--
--  (c) BUCO DELLA PROVA
--      · gli esiti sono confrontabili nel tempo (modalita + svolto_il + pct),
--        quindi pre/post test e sperimentazione si misurano con dati reali.
--
-- PRIVACY (scelta di progetto, non un dettaglio tecnico)
--   Nessun dato personale di minori entra qui. L'unità di misura è la CLASSE
--   (codice classe), non l'alunno: n_partecipanti è un conteggio, e i nickname
--   del quiz live restano nel file temporaneo della partita — in `dettaglio`
--   finisce l'aggregato per domanda, mai un elenco di nomi. Questo tiene la
--   piattaforma fuori dal trattamento dei dati dei minori e rende l'informativa
--   alle famiglie una pagina sola.
--
-- Idempotente. Sicura da rilanciare. Non tocca tabelle non `edu_`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CAMPI DIDATTICI SU CORSO E LEZIONE
-- ----------------------------------------------------------------------------
alter table edu_corsi   add column if not exists didattica jsonb not null default '{}'::jsonb;
alter table edu_lezioni add column if not exists didattica jsonb not null default '{}'::jsonb;

comment on column edu_corsi.didattica is
  'Didattica del CORSO. Forma attesa: {discipline:[],competenze_chiave:[],traguardi:{primaria:[],medie:[]},uda:{prodotto_finale,fasi,monte_ore,metodologie,verifica},note}';
comment on column edu_lezioni.didattica is
  'Didattica della LEZIONE. Forma attesa: {obiettivi:{primaria:[],medie:[]},parole_chiave:[],prima,durante,dopo,materiali:[],collegamenti}';

-- ----------------------------------------------------------------------------
-- 2. EDU_ESITI — l'evidenza valutativa
-- ----------------------------------------------------------------------------
create table if not exists edu_esiti (
  id             bigserial primary key,
  cliente_id     uuid not null references edu_clienti(id) on delete cascade,
  scuola_id      uuid references edu_scuole(id) on delete set null,
  codice_classe  text not null,
  corso_id       uuid references edu_corsi(id) on delete set null,
  corso_titolo   text,                       -- copia: l'esito resta leggibile anche se il corso cambia
  lezione_slug   text not null,
  lezione_titolo text,
  livello        text check (livello in ('junior','senior')),
  modalita       text not null default 'aula'
                 check (modalita in ('aula','live','compito','ingresso','uscita')),
                 -- aula = quiz di fine lezione · live = quiz coi dispositivi
                 -- compito = a casa · ingresso/uscita = pre e post test della sperimentazione
  n_partecipanti int check (n_partecipanti is null or n_partecipanti between 0 and 500),
  n_domande      int  not null default 0 check (n_domande between 0 and 100),
  n_giuste       int  not null default 0 check (n_giuste >= 0),
  pct            int generated always as
                 (case when n_domande > 0 then round(100.0 * n_giuste / n_domande)::int end) stored,
  dettaglio      jsonb not null default '{}'::jsonb,   -- aggregato per domanda: [{q,giuste,tot,pct}]
  note           text,
  svolto_il      timestamptz not null default now(),
  creato_il      timestamptz not null default now(),
  constraint edu_esiti_giuste_coerenti check (n_giuste <= n_domande)
);
create index if not exists edu_esiti_cliente_idx on edu_esiti(cliente_id, svolto_il desc);
create index if not exists edu_esiti_classe_idx  on edu_esiti(cliente_id, codice_classe, svolto_il desc);
create index if not exists edu_esiti_lezione_idx on edu_esiti(corso_id, lezione_slug);

comment on table edu_esiti is
  'Esito di una lezione per una CLASSE: la riga che il docente esporta e allega alla valutazione. Nessun dato personale di alunni (vedi migrazione 32).';

-- ----------------------------------------------------------------------------
-- 3. EDU_COMPITI — il ritorno a casa
-- ----------------------------------------------------------------------------
create table if not exists edu_compiti (
  id            uuid primary key default gen_random_uuid(),
  cliente_id    uuid not null references edu_clienti(id) on delete cascade,
  corso_id      uuid references edu_corsi(id) on delete cascade,
  lezione_slug  text not null,
  codice        text not null unique,          -- codice del link pubblico (?compito=XXXXXXXX)
  titolo        text not null,
  consegna      text,
  livello       text not null default 'entrambe' check (livello in ('junior','senior','entrambe')),
  clip          jsonb not null default '{}'::jsonb,   -- {guid, da, a}: il pezzo di video da rivedere
  domande       jsonb not null default '[]'::jsonb,   -- [{domanda, opzioni:[], ok:int}] — `ok` NON esce mai dal server
  attivo        boolean not null default true,
  scadenza      date,
  creato_da     uuid,
  creato_il     timestamptz not null default now(),
  constraint edu_compiti_codice_ok check (codice ~ '^[A-Z0-9]{6,12}$')
);
create index if not exists edu_compiti_cliente_idx on edu_compiti(cliente_id, creato_il desc);
create index if not exists edu_compiti_corso_idx   on edu_compiti(corso_id, lezione_slug);

comment on table edu_compiti is
  'Compito a casa su una clip. Le risposte giuste (domande[].ok) restano sul server: edu_compito_apri() non le restituisce, la correzione la fa edu_compito_valuta().';

-- ----------------------------------------------------------------------------
-- 4. RLS — set canonico, come la migrazione 29
-- ----------------------------------------------------------------------------
alter table edu_esiti   enable row level security;
alter table edu_compiti enable row level security;

drop policy if exists esiti_sel   on edu_esiti;
drop policy if exists esiti_wr    on edu_esiti;
drop policy if exists compiti_sel on edu_compiti;
drop policy if exists compiti_wr  on edu_compiti;

-- esiti: li legge il mio cliente, li scrive/cancella l'editor (o il docente della classe)
create policy esiti_sel on edu_esiti for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());
create policy esiti_wr on edu_esiti for all to authenticated
  using (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()))
  with check (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()));

-- compiti: idem; il player anonimo NON tocca la tabella, passa dalle RPC qui sotto
create policy compiti_sel on edu_compiti for select to authenticated
  using (edu_e_admin() or cliente_id = edu_mio_cliente());
create policy compiti_wr on edu_compiti for all to authenticated
  using (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()))
  with check (edu_e_admin() or (cliente_id = edu_mio_cliente() and edu_sono_editor()));

revoke all on edu_esiti   from public, anon;
revoke all on edu_compiti from public, anon;
grant select, insert, update, delete on edu_esiti   to authenticated;
grant select, insert, update, delete on edu_compiti to authenticated;
grant usage, select on sequence edu_esiti_id_seq to authenticated;

-- ----------------------------------------------------------------------------
-- 5. RPC PER IL PLAYER (anonimo, sempre via api.php)
-- ----------------------------------------------------------------------------

-- 5.1 salva l'esito di una lezione. Chiamata da api.php con la anon key.
--     Valida tutto: cliente, licenza, codice classe, numeri, dimensione del dettaglio.
--     Doppio invio entro 2 minuti con gli stessi numeri: restituisce la riga già scritta.
create or replace function edu_salva_esito(p jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_cli    uuid;
  v_stato  jsonb;
  v_codice text;
  v_corso  uuid;
  v_mod    text;
  v_nd     int;
  v_ng     int;
  v_np     int;
  v_liv    text;
  v_det    jsonb;
  v_id     bigint;
begin
  select id into v_cli from edu_clienti where slug = p->>'cliente';
  if v_cli is null then return jsonb_build_object('ok', false, 'err', 'cliente'); end if;
  if not edu_licenza_attiva(v_cli) then return jsonb_build_object('ok', false, 'err', 'licenza'); end if;

  v_codice := upper(coalesce(nullif(trim(p->>'classe'), ''), 'ANON'));
  if v_codice !~ '^[A-Z0-9-]{1,20}$' then return jsonb_build_object('ok', false, 'err', 'classe'); end if;
  v_stato := edu_classe_stato(v_cli, v_codice);
  if not coalesce((v_stato->>'valida')::boolean, true) then
    return jsonb_build_object('ok', false, 'err', 'licenza_scuola');
  end if;

  v_mod := coalesce(p->>'modalita', 'aula');
  if v_mod not in ('aula','live','compito','ingresso','uscita') then v_mod := 'aula'; end if;

  v_nd := greatest(0, least(100, coalesce((p->>'n_domande')::int, 0)));
  v_ng := greatest(0, least(v_nd,  coalesce((p->>'n_giuste')::int, 0)));
  v_np := case when p ? 'n_partecipanti'
               then greatest(0, least(500, (p->>'n_partecipanti')::int)) end;
  v_liv := case when p->>'livello' in ('junior','senior') then p->>'livello' end;

  v_det := coalesce(p->'dettaglio', '{}'::jsonb);
  if pg_column_size(v_det) > 8192 then v_det := '{}'::jsonb; end if;   -- niente payload gonfiati

  -- la lezione deve appartenere a un corso accessibile a questo cliente
  select co.id into v_corso
  from edu_lezioni l join edu_corsi co on co.id = l.corso_id
  where l.slug = p->>'lezione' and l.owner is null
    and edu_catalogo_valido(co.id, v_cli)
  limit 1;

  -- doppio invio: stessa classe, stessa lezione, stessi numeri, entro 2 minuti
  select e.id into v_id from edu_esiti e
  where e.cliente_id = v_cli and e.codice_classe = v_codice
    and e.lezione_slug = coalesce(p->>'lezione', '—') and e.modalita = v_mod
    and e.n_domande = v_nd and e.n_giuste = v_ng
    and e.svolto_il > now() - interval '2 minutes'
  limit 1;
  if v_id is not null then
    return jsonb_build_object('ok', true, 'id', v_id, 'gia_salvato', true);
  end if;

  insert into edu_esiti(cliente_id, scuola_id, codice_classe, corso_id, corso_titolo,
                        lezione_slug, lezione_titolo, livello, modalita,
                        n_partecipanti, n_domande, n_giuste, dettaglio)
  values (v_cli,
          nullif(v_stato->>'scuola_id', '')::uuid,
          v_codice,
          v_corso,
          (select titolo from edu_corsi where id = v_corso),
          coalesce(nullif(trim(p->>'lezione'), ''), '—'),
          left(coalesce(p->>'lezione_titolo', ''), 200),
          v_liv, v_mod, v_np, v_nd, v_ng, v_det)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
comment on function edu_salva_esito(jsonb) is
  'Registra l''esito di una lezione per una classe. Nessun dato personale: il dettaglio è l''aggregato per domanda.';

-- 5.2 diario del percorso di una classe: cosa ha fatto, quando, con che esito
create or replace function edu_diario_classe(p_cliente_slug text, p_codice text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  with cl as (select id from edu_clienti where slug = p_cliente_slug),
  cod as (select upper(coalesce(nullif(trim(p_codice), ''), 'ANON')) as c)
  select coalesce(jsonb_agg(x order by (x->>'ordine')::int), '[]'::jsonb) from (
    select jsonb_build_object(
      'corso',  co.slug,
      'corso_tit', co.titolo,
      'lezione', l.slug,
      'tit',     l.titolo,
      'ordine',  l.ordine,
      'fatta',   e.quando is not null,
      'quando',  e.quando,
      'volte',   coalesce(e.volte, 0),
      'pct',     s.pct_migliore
    ) as x
    from edu_corsi co
    join edu_lezioni l on l.corso_id = co.id and l.owner is null and l.stato = 'pubblicata'
    left join (
      select ev.lezione, max(ev.creato_il) as quando, count(*) as volte
      from edu_eventi ev
      where ev.cliente_id = (select id from cl)
        and upper(ev.codice_classe) = (select c from cod)
        and ev.tipo = 'lezione_completata'
      group by ev.lezione
    ) e on e.lezione = l.slug
    left join (
      select es.lezione_slug, max(es.pct) as pct_migliore
      from edu_esiti es
      where es.cliente_id = (select id from cl)
        and es.codice_classe = (select c from cod)
      group by es.lezione_slug
    ) s on s.lezione_slug = l.slug
    where co.stato = 'pubblicato'
      and edu_catalogo_valido(co.id, (select id from cl))
  ) t;
$$;
comment on function edu_diario_classe(text,text) is
  'Percorso di una classe: lezioni fatte, quando, miglior esito. Dati aggregati di classe, nessun alunno.';

-- 5.3 apre un compito dal suo codice — SENZA le risposte giuste
create or replace function edu_compito_apri(p_codice text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'ok', true,
    'codice', k.codice,
    'titolo', k.titolo,
    'consegna', k.consegna,
    'livello', k.livello,
    'clip', k.clip,
    'lezione', k.lezione_slug,
    'cliente', c.slug,
    'brand', c.brand,
    'scadenza', k.scadenza,
    'domande', coalesce((
        select jsonb_agg(jsonb_build_object('domanda', d->>'domanda', 'opzioni', d->'opzioni')
               order by i)
        from jsonb_array_elements(k.domande) with ordinality as q(d, i)), '[]'::jsonb)
  )
  from edu_compiti k
  join edu_clienti c on c.id = k.cliente_id
  where upper(k.codice) = upper(p_codice)
    and k.attivo
    and (k.scadenza is null or k.scadenza >= current_date)
    and edu_licenza_attiva(k.cliente_id)
  limit 1;
$$;
comment on function edu_compito_apri(text) is
  'Compito per il dispositivo dell''alunno: domande e opzioni, mai il campo ok (correzione solo server-side).';

-- 5.4 corregge il compito sul server e registra l'esito
create or replace function edu_compito_valuta(p_codice text, p_classe text, p_risposte jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  k         edu_compiti;
  v_nd      int;
  v_ng      int := 0;
  v_i       int;
  v_ok      int;
  v_data    jsonb := '[]'::jsonb;
  v_esito   jsonb;
begin
  select * into k from edu_compiti
  where upper(codice) = upper(p_codice) and attivo
    and (scadenza is null or scadenza >= current_date);
  if k.id is null then return jsonb_build_object('ok', false, 'err', 'compito'); end if;
  if jsonb_typeof(p_risposte) <> 'array' then return jsonb_build_object('ok', false, 'err', 'risposte'); end if;

  v_nd := jsonb_array_length(k.domande);
  for v_i in 0 .. v_nd - 1 loop
    v_ok := (k.domande -> v_i ->> 'ok')::int;
    if coalesce((p_risposte -> v_i)::text, 'null') <> 'null'
       and (p_risposte -> v_i)::text ~ '^-?[0-9]+$'
       and (p_risposte ->> v_i)::int = v_ok then
      v_ng := v_ng + 1;
      v_data := v_data || jsonb_build_object('n', v_i, 'giusta', true);
    else
      v_data := v_data || jsonb_build_object('n', v_i, 'giusta', false, 'ok', v_ok);
    end if;
  end loop;

  v_esito := edu_salva_esito(jsonb_build_object(
    'cliente',  (select slug from edu_clienti where id = k.cliente_id),
    'classe',   p_classe,
    'lezione',  k.lezione_slug,
    'modalita', 'compito',
    'n_domande', v_nd, 'n_giuste', v_ng, 'n_partecipanti', 1,
    'dettaglio', jsonb_build_object('compito', k.codice, 'risposte', v_data)));

  return jsonb_build_object('ok', true, 'n_domande', v_nd, 'n_giuste', v_ng,
                            'esito', v_data, 'salvato', coalesce((v_esito->>'ok')::boolean, false));
end $$;
comment on function edu_compito_valuta(text,text,jsonb) is
  'Corregge il compito lato server e registra l''esito (modalita=compito). Le risposte giuste non lasciano il database.';

-- ----------------------------------------------------------------------------
-- 6. LE FUNZIONI DEL PLAYER PORTANO ANCHE LA DIDATTICA
--    (riscritte integralmente: unica differenza, il campo 'didattica')
-- ----------------------------------------------------------------------------
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
      'didattica', coalesce(co.didattica, '{}'::jsonb),
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

create or replace function edu_get_lezione_tenant(p_cliente_slug text, p_lezione_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select edu_assembla_lezione(l.id)
         || jsonb_build_object('corso', jsonb_build_object(
              'id', co.slug, 'uuid', co.id, 'tit', co.titolo,
              'prologo', nullif(trim(co.prologo), ''),
              'mascotte', co.mascotte,
              'didattica', coalesce(co.didattica, '{}'::jsonb)))
         || jsonb_build_object('didattica', coalesce(l.didattica, '{}'::jsonb))
  from edu_lezioni l
  join edu_corsi co on co.id = l.corso_id
  join edu_clienti c on c.slug = p_cliente_slug
  where l.slug = p_lezione_slug
    and l.owner is null and l.stato not in ('bozza','soon') and co.stato = 'pubblicato'
    and edu_catalogo_valido(co.id, c.id)
  limit 1;
$$;

-- ----------------------------------------------------------------------------
-- 7. PERMESSI SULLE RPC
--    anon esegue solo ciò che serve al player; nessuna lettura di tabelle.
-- ----------------------------------------------------------------------------
revoke all on function edu_salva_esito(jsonb)                 from public;
revoke all on function edu_diario_classe(text,text)           from public;
revoke all on function edu_compito_apri(text)                 from public;
revoke all on function edu_compito_valuta(text,text,jsonb)    from public;

grant execute on function edu_salva_esito(jsonb)              to anon, authenticated;
grant execute on function edu_diario_classe(text,text)        to anon, authenticated;
grant execute on function edu_compito_apri(text)              to anon, authenticated;
grant execute on function edu_compito_valuta(text,text,jsonb) to anon, authenticated;
grant execute on function edu_get_corsi(text)                 to anon, authenticated;
grant execute on function edu_get_lezione_tenant(text,text)   to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 8. CONTROLLO FINALE: niente lettura diretta per anon sulle nuove tabelle
-- ----------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
  from information_schema.role_table_grants
  where grantee = 'anon' and table_name in ('edu_esiti','edu_compiti');
  if n > 0 then
    raise exception 'migrazione 32: anon ha % permessi diretti su edu_esiti/edu_compiti (attesi 0)', n;
  end if;
end $$;


-- ============================================================================
-- MIGRAZIONE 33 — i testi delle schede entrano nelle lezioni
-- ----------------------------------------------------------------------------
-- Perché:
--   scheda.php compone la scheda di carta con quello che trova nella lezione
--   (punti che brillano, tappe, quiz) più i testi scritti in regia, che vivono
--   in edu_lezioni.didattica->'scheda'. Finora quei testi stavano in file del
--   codice (contenuti/*.json) e NON nel database: in produzione le schede
--   sarebbero uscite incomplete. Questa migrazione li porta dentro le lezioni,
--   una volta sola. Da lì in poi si modificano dalla regia, come ogni altro
--   contenuto della lezione.
--
-- Garanzie:
--   1. NON SOVRASCRIVE. Una lezione che ha già una scheda (anche un solo campo
--      scritto in regia) viene lasciata esattamente com'è.
--   2. È ripetibile. Rilanciarla riempie solo le lezioni ancora vuote. Per
--      ricaricare il testo di partenza: in regia svuota i campi, salva, rilancia.
--   3. Riempie TUTTE le lezioni originali che corrispondono (non solo la prima):
--      se un corso è stato duplicato per un secondo cliente, anche la copia
--      riceve la scheda.
--   4. Guarda solo i progetti di Antichi Mestieri / Sale in Classe, mai le copie
--      dei docenti (owner is null), e trova la lezione per slug oppure per
--      TITOLO ESATTO (non per somiglianza: «la salina» dei fenicotteri non deve
--      ricevere la scheda del salinaio).
--
-- Nei messaggi NOTICE, per ogni lezione toccata: «riempita», «già compilata,
-- lasciata com'è», oppure «nessuna lezione in archivio» per il mestiere.
-- I testi che portano la marcatura [DA VERIFICARE SUI VIDEO] sono bozze: la
-- migrazione li carica (così la regia li mostra e si correggono da lì) ma
-- scheda.php NON li stampa finché la marcatura c'è, e qui sotto vengono
-- contati in un avviso.
-- ============================================================================

do $mig$
declare
  r        record;
  v        record;
  v_trov   int;
  v_esiste boolean;
  n_fatte  int := 0;
  n_salta  int := 0;
  n_manca  int := 0;
begin
  for r in
    select * from (values
    ('Il salinaio', array['salinaio','il-salinaio','mestiere-del-salinaio'], array['il salinaio','il mestiere del salinaio','salinaio'], '{"numero":1,"di":5,"prima":"Secondo te, come si «raccoglie» il sale? Scrivi tre parole che ti vengono in mente pensando a una salina.","trova":["Il palo a forma di T","Il fondo di argilla","Il paluneddo, la pala del salinaio","Un munzeddu, il cumulo di sale","La crosta di sale nella vasca"],"distrattori":["Un mulino a vento"],"fasi":["Il salinaio rompe la crosta di sale con il palo a T.","Raccoglie il sale con il paluneddo, senza toccare l''argilla del fondo.","Controlla la punta della pala: se resta bianca, il sale è puro.","Porta il sale fuori dalla vasca e forma il munzeddu.","Il munzeddu asciuga e si copre di una crosta naturale che lo protegge dalla pioggia."],"glossario":[{"parola":"munzeddu"},{"parola":"paluneddo"},{"parola":"crosta di sale"},{"parola":"argilla"},{"parola":"vasca salante"}],"territorio":"Perché le saline sono proprio sulla costa tra Trapani e Marsala? Pensa al mare, al sole e al vento.","capacita":["Forza fisica","Pazienza","Precisione","Conoscere il meteo","Lavoro di squadra","Creatività"],"intervista":["Hai mai visto una salina da vicino? Cosa ricordi?","Conosci qualcuno che ha lavorato in salina o nel commercio del sale?","Perché, secondo te, il sale di Trapani è famoso?"],"disegno":"il paluneddo o il palo a T","vero_falso":[{"f":"Il munzeddu è un mucchio di sale.","v":true},{"f":"Il palo a T rompe la crosta di sale.","v":true},{"f":"Il sale si fa con l''acqua del mare.","v":true},{"f":"Il sale cresce sugli alberi.","v":false}],"autovalutazione":["So spiegare le fasi di questo mestiere","Conosco almeno tre parole del mestiere","Ho lavorato bene con la mia squadra"],"adattata":{"trova4":["Il munzeddu","La vasca con il sale","Il palo a T","La pala"],"fasi3":["Rompo la crosta di sale con il palo a T.","Raccolgo il sale con la pala.","Faccio il munzeddu."],"parole":["munzeddu","pala","vasca"]}}'::jsonb),
    ('Il corallaio', array['corallaio','il-corallaio','corallo','il-corallo'], array['il corallaio','il corallo','il mestiere del corallaio','corallaio'], '{"numero":2,"di":5,"prima":"Il corallo: è una pietra, una pianta o un animale? E che cosa ci si fa? Scrivi tre parole che ti vengono in mente.","trova":["Il banco di lavoro del corallaio","La lampada che illumina il banco","Un rametto di corallo grezzo","Un attrezzo per incidere [DA VERIFICARE SUI VIDEO]","Un oggetto finito in corallo"],"distrattori":["Una rete da pesca"],"fasi":["Il corallaio sceglie il rametto di corallo grezzo.","Taglia il pezzo della misura che gli serve.","Incide la forma con l''attrezzo, poco per volta. [DA VERIFICARE SUI VIDEO]","Liscia e lucida la superficie finché non brilla.","Monta il pezzo finito sull''oggetto (spillone, orecchino, oggetto sacro)."],"glossario":[{"parola":"corallo"},{"parola":"grezzo"},{"parola":"bottega"},{"parola":"incisione"},{"parola":"lucidatura"}],"territorio":"Perché proprio Trapani è diventata famosa per il corallo? Pensa al mare, al porto e alle botteghe della città.","intervista":["In casa vostra c''è un oggetto di corallo? Chi ve l''ha dato?","Conosci qualcuno che lavorava il corallo o l''oro a Trapani?","Secondo te perché oggi restano poche botteghe?"],"disegno":"l''oggetto finito che ti è piaciuto di più","vero_falso":[{"f":"Il corallo viene dal mare.","v":true},{"f":"Il corallaio lavora con attrezzi piccoli.","v":true},{"f":"Il corallo grezzo è già lucido.","v":false},{"f":"A Trapani si lavorava il corallo.","v":true}],"adattata":{"trova4":["Il banco di lavoro","La lampada","Il corallo grezzo","L''oggetto finito"],"fasi3":["Scelgo il corallo grezzo.","Lo lavoro con l''attrezzo.","Lo lucido finché brilla."],"parole":["corallo","bottega","attrezzo"]}}'::jsonb),
    ('I tappeti ericini', array['tappeti','tappeti-ericini','il-tessitore-di-tappeti','tessitore'], array['il tessitore di tappeti ericini','i tappeti ericini','il tessitore','tappeti ericini'], '{"numero":3,"di":5,"prima":"Un tappeto: come si fa un disegno con dei fili? E quanto tempo ci vorrà? Scrivi tre parole.","trova":["Il telaio","I fili dell''ordito, tesi","La spola o la navetta [DA VERIFICARE SUI VIDEO]","Il motivo che si ripete","Il tappeto già cominciato"],"distrattori":["Una macchina da cucire"],"fasi":["Si tendono i fili dell''ordito sul telaio.","Si passa il filo della trama fra i fili tesi.","Si batte la trama per stringere il tessuto. [DA VERIFICARE SUI VIDEO]","Il motivo cresce riga dopo riga, sempre uguale.","Si taglia il tappeto dal telaio e si rifiniscono i bordi."],"glossario":[{"parola":"telaio"},{"parola":"trama"},{"parola":"ordito"},{"parola":"modulo"},{"parola":"motivo"}],"territorio":"Perché questo tappeto si chiama «ericino»? Che cosa lega un oggetto al luogo dove si fa?","intervista":["In casa avete un tappeto o una coperta fatti a mano? Chi li ha fatti?","Qualcuno in famiglia sa cucire, ricamare o tessere? Chi glielo ha insegnato?","Secondo te, perché oggi pochissime persone sanno fare questo lavoro?"],"disegno":"il motivo del tappeto, ripetuto almeno tre volte","vero_falso":[{"f":"Il tappeto si fa sul telaio.","v":true},{"f":"Il motivo si ripete sempre uguale.","v":true},{"f":"Per fare un tappeto ci vuole un''ora.","v":false},{"f":"I fili tesi si chiamano ordito.","v":true}],"adattata":{"trova4":["Il telaio","I fili","Il motivo","Il tappeto"],"fasi3":["Metto i fili sul telaio.","Passo il filo fra i fili.","Il disegno cresce."],"parole":["telaio","trama","motivo"]}}'::jsonb),
    ('La raccolta delle olive', array['olive','raccolta-olive','raccolta-delle-olive'], array['la raccolta delle olive','raccolta delle olive','le olive','l''olio'], '{"numero":4,"di":5,"prima":"L''olio che mettiamo sul pane: quante mani ci sono passate prima di arrivare in bottiglia? Scrivi tre parole.","trova":["Le reti stese sotto l''albero","Il rastrello o l''abbacchiatore [DA VERIFICARE SUI VIDEO]","Le cassette con le olive","L''uliveto in fila","Il frantoio"],"distrattori":["Un trattore che ara"],"fasi":["Si stendono le reti sotto l''albero.","Si fanno cadere le olive dai rami.","Si raccolgono le olive nelle cassette, togliendo foglie e rametti.","Le olive vanno al frantoio il prima possibile. [DA VERIFICARE SUI VIDEO: entro quante ore]","Al frantoio le olive vengono macinate e si ottiene l''olio."],"glossario":[{"parola":"uliveto"},{"parola":"rete"},{"parola":"frantoio"},{"parola":"molitura"},{"parola":"resa"}],"territorio":"Perché l''olivo cresce bene qui e non dappertutto? Pensa al clima, al sole e alla pioggia.","intervista":["In famiglia qualcuno ha raccolto le olive? Dove e quando?","Comprate l''olio o ve lo fate? Da chi?","Qual è la differenza fra l''olio del frantoio e quello del supermercato, secondo chi intervisti?"],"disegno":"un ramo d''olivo con le olive e la rete sotto","vero_falso":[{"f":"L''olio si fa con le olive.","v":true},{"f":"Le reti servono a raccogliere le olive che cadono.","v":true},{"f":"Le olive si possono lasciare un mese nelle cassette.","v":false},{"f":"Il frantoio macina le olive.","v":true}],"adattata":{"trova4":["L''albero di olivo","La rete","Le olive","La cassetta"],"fasi3":["Stendo la rete.","Faccio cadere le olive.","Porto le olive al frantoio."],"parole":["oliva","rete","frantoio"]}}'::jsonb),
    ('La vendemmia', array['vendemmia','la-vendemmia'], array['la vendemmia','vendemmia'], '{"numero":5,"di":5,"prima":"L''uva si raccoglie e poi? Chi decide qual è il giorno giusto? Scrivi tre parole.","trova":["I filari della vigna","Un grappolo maturo","La forbice da vendemmia","La cassetta dell''uva","La cantina con le vasche [DA VERIFICARE SUI VIDEO]"],"distrattori":["Un albero di limoni"],"fasi":["Si controlla l''uva per decidere il giorno giusto.","Si taglia il grappolo con la forbice e si mette nella cassetta.","L''uva arriva in cantina in giornata.","L''uva viene pigiata e comincia la fermentazione. [DA VERIFICARE SUI VIDEO]","Il mosto diventa vino e riposa."],"glossario":[{"parola":"vigneto"},{"parola":"filare"},{"parola":"grappolo"},{"parola":"vendemmia"},{"parola":"fermentazione"}],"territorio":"Perché la vite sta bene in questa terra? E perché il vino prende il nome del posto in cui nasce?","intervista":["In famiglia qualcuno ha fatto la vendemmia? Racconta com''era.","Si faceva il vino in casa? Chi e come?","Che differenza c''è, per chi intervisti, fra la vendemmia di una volta e quella di oggi?"],"disegno":"un filare con i grappoli, e la cassetta piena","vero_falso":[{"f":"Il vino si fa con l''uva.","v":true},{"f":"L''uva si raccoglie in estate o in autunno.","v":true},{"f":"La vendemmia si fa quando si vuole.","v":false},{"f":"L''uva arriva in cantina il giorno stesso.","v":true}],"adattata":{"trova4":["La vigna","Il grappolo","La forbice","La cassetta"],"fasi3":["Taglio il grappolo.","Riempio la cassetta.","Porto l''uva in cantina."],"parole":["uva","grappolo","cantina"]}}'::jsonb)
    ) as t(nome, slugs, titoli, dati)
  loop
    v_trov := 0;
    for v in
      select l.id, l.slug, l.titolo, l.progetto,
             coalesce(l.didattica -> 'scheda', '{}'::jsonb) <> '{}'::jsonb as ha_scheda
        from edu_lezioni l
       where l.owner is null
         and coalesce(l.progetto, '') in ('antichi-mestieri-trapani', 'sale-in-classe')
         and (l.slug = any (r.slugs) or lower(trim(l.titolo)) = any (r.titoli))
       order by l.ordine nulls last
    loop
      v_trov := v_trov + 1;
      if v.ha_scheda then
        n_salta := n_salta + 1;
        raise notice '% → lezione «%» (%/%) ha già una scheda, lasciata com''è', r.nome, v.titolo, v.progetto, v.slug;
        continue;
      end if;
      update edu_lezioni
         set didattica = jsonb_set(coalesce(didattica, '{}'::jsonb), '{scheda}', r.dati, true),
             aggiornato_il = now()
       where id = v.id;
      n_fatte := n_fatte + 1;
      raise notice '% → lezione «%» (%/%): scheda riempita', r.nome, v.titolo, v.progetto, v.slug;
    end loop;
    if v_trov = 0 then
      n_manca := n_manca + 1;
      raise notice '% → nessuna lezione in archivio: la scheda si scriverà in regia quando la lezione esisterà', r.nome;
    end if;
  end loop;

  raise notice '--- schede: % riempite, % già compilate, % mestieri senza lezione ---',
               n_fatte, n_salta, n_manca;
end
$mig$;

-- ----------------------------------------------------------------------------
-- Controllo: una scheda senza fasi o senza glossario stampa monca; e i testi
-- ancora marcati [DA VERIFICARE SUI VIDEO] vanno riscontrati in regia.
-- Solo avvisi: non fanno fallire la migrazione.
-- ----------------------------------------------------------------------------
do $ctl$
declare n int; m int;
begin
  select count(*) into n
    from edu_lezioni l
   where l.owner is null
     and coalesce(l.didattica -> 'scheda', '{}'::jsonb) <> '{}'::jsonb
     and (jsonb_typeof(l.didattica -> 'scheda' -> 'fasi') is distinct from 'array'
          or jsonb_array_length(l.didattica -> 'scheda' -> 'fasi') = 0
          or jsonb_typeof(l.didattica -> 'scheda' -> 'glossario') is distinct from 'array'
          or jsonb_array_length(l.didattica -> 'scheda' -> 'glossario') = 0);
  if n > 0 then
    raise notice 'ATTENZIONE: % lezioni hanno una scheda senza fasi o senza glossario: regia → Scheda da stampare', n;
  end if;
  select count(*) into m
    from edu_lezioni l
   where l.owner is null and (l.didattica -> 'scheda')::text like '%[DA VERIFICARE%';
  if m > 0 then
    raise notice 'DA FARE: % lezioni hanno testi marcati [DA VERIFICARE SUI VIDEO]: finché la marcatura resta, quelle voci non vengono stampate', m;
  end if;
end
$ctl$;

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



-- ################################################################
-- ##  migrazione_35_clip_tagli_mappa.sql
-- ################################################################

-- ============================================================
-- MIGRAZIONE 35 · clip con taglio, voce a parte e sottotitoli propri · luogo della lezione
-- Esplora Edu · novembre 2026
--
-- A che cosa serve
--   I racconti a 360° di U Cuntastorie a Trapani hanno tre cose che le lezioni di
--   prima non avevano:
--     1. il video su Bunny dura più del racconto → servono un INIZIO e una FINE;
--     2. la voce pulita sta in un file a parte, da tenere agganciata al video,
--        mentre l'audio del video (la strada, la gente) resta basso;
--     3. i sottotitoli stanno in un file .vtt nostro, con i tempi della voce.
--   In più ogni lezione ha un LUOGO sulla mappa (edu_lezioni.didattica->'luogo').
--
-- Che cosa cambia
--   · edu_media: cinque colonne nuove, tutte facoltative (null = come prima)
--   · edu_assembla_lezione: ogni clip porta da / a / t0 / volv / cc / tit
--   · edu_get_corsi: ogni lezione dell'elenco porta 'luogo'
--   · edu_duplica_corso: copia anche le colonne nuove e il titolo della clip
--
-- Come lo fa
--   Le tre funzioni NON vengono riscritte da zero: la migrazione legge la
--   definizione che c'è in archivio e vi innesta le righe nuove. Così non può
--   riportare indietro una funzione che in produzione è più avanti del file.
--   Se un punto d'innesto non si trova, si ferma con un errore chiaro e non
--   cambia nulla. Ripetibile: se l'innesto c'è già, salta.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Colonne nuove su edu_media
-- ------------------------------------------------------------
alter table edu_media add column if not exists titolo    text;      -- nome del racconto (in produzione c'è già: qui solo per le copie rimaste indietro)
alter table edu_media add column if not exists inizio_s  numeric;   -- secondo del video da cui parte la clip
alter table edu_media add column if not exists fine_s    numeric;   -- secondo del video a cui la clip si ferma
alter table edu_media add column if not exists sync_s    numeric;   -- secondo del video che vale «zero» per voce e sottotitoli (null = inizio_s)
alter table edu_media add column if not exists vol_video smallint;  -- volume dell'audio del video, 0-100 (null = pieno)
alter table edu_media add column if not exists cc_url    text;      -- file .vtt dei sottotitoli, se non stanno su Bunny

comment on column edu_media.inizio_s  is 'Taglio in testa: secondo del video da cui parte la clip (null/0 = dall''inizio)';
comment on column edu_media.fine_s    is 'Taglio in coda: secondo del video a cui la clip finisce (null = fine del video)';
comment on column edu_media.sync_s    is 'Secondo del video che corrisponde allo zero della voce (audio_url non in loop) e dei sottotitoli (cc_url); null = inizio_s';
comment on column edu_media.vol_video is 'Volume dell''audio del video 0-100; null = pieno. Serve quando il racconto sta in audio_url';
comment on column edu_media.cc_url    is 'Sottotitoli in un file .vtt https; i tempi sono quelli della voce (vedi sync_s)';

do $v$
begin
  if not exists (select 1 from pg_constraint where conname = 'edu_media_tagli_ck') then
    alter table edu_media add constraint edu_media_tagli_ck check (
          (inizio_s  is null or inizio_s >= 0)
      and (fine_s    is null or fine_s   >  0)
      and (inizio_s  is null or fine_s is null or fine_s > inizio_s)
      and (sync_s    is null or sync_s  >= 0)
      and (vol_video is null or vol_video between 0 and 100)
      and (cc_url    is null or cc_url ~* '^https://[^[:space:]"''<>]+\.vtt(\?[^[:space:]"''<>]*)?$')
    );
  end if;
end $v$;

-- ------------------------------------------------------------
-- 2. Innesti nelle funzioni esistenti
-- ------------------------------------------------------------
create or replace function pg_temp.edu_innesta(p_fn regprocedure, p_marca text, p_cerca text, p_metti text)
returns text language plpgsql as $f$
declare d text; n int;
begin
  d := pg_get_functiondef(p_fn);
  if position(p_marca in d) > 0 then return 'già presente'; end if;
  n := (length(d) - length(replace(d, p_cerca, ''))) / length(p_cerca);
  if n <> 1 then
    raise exception 'migr. 35: in % il punto d''innesto «%» compare % volte (ne serve 1). Nulla è stato cambiato.', p_fn, left(p_cerca, 60), n;
  end if;
  execute replace(d, p_cerca, p_metti);
  return 'innestato';
end $f$;

do $i$
declare r text;
begin
  -- 2a. edu_assembla_lezione: le colonne nuove entrano nel CTE…
  r := pg_temp.edu_innesta('edu_assembla_lezione(uuid)'::regprocedure, 'inizio_s',
         'audio_url, audio_vol, audio_loop, audio_duck,',
         'audio_url, audio_vol, audio_loop, audio_duck, titolo, inizio_s, fine_s, sync_s, vol_video, cc_url,');
  raise notice 'edu_assembla_lezione · colonne: %', r;
  -- …e nella clip che arriva al player
  r := pg_temp.edu_innesta('edu_assembla_lezione(uuid)'::regprocedure, '''volv''',
         '''lis'', nullif(trim(m.video_lis),''''),',
         '''lis'', nullif(trim(m.video_lis),''''),
                ''tit'', nullif(trim(m.titolo),''''),
                ''da'', m.inizio_s, ''a'', m.fine_s, ''t0'', m.sync_s,
                ''volv'', m.vol_video, ''cc'', nullif(trim(m.cc_url),''''),');
  raise notice 'edu_assembla_lezione · clip: %', r;

  -- 2b. edu_get_corsi: il luogo della lezione, per la pagina con la mappa
  r := pg_temp.edu_innesta('edu_get_corsi(text)'::regprocedure, '''luogo''',
         '''acc'', coalesce(l.accessibilita, ''{}''::jsonb))',
         '''acc'', coalesce(l.accessibilita, ''{}''::jsonb),
                  ''luogo'', l.didattica->''luogo'')');
  raise notice 'edu_get_corsi · luogo: %', r;

  -- 2c. edu_duplica_corso: una copia non deve perdere tagli, voce e sottotitoli.
  --     Due innesti su UNA riga ciascuno: in produzione le funzioni hanno i fine-riga
  --     di Windows, e un punto d'innesto su più righe non verrebbe trovato.
  r := pg_temp.edu_innesta('edu_duplica_corso(uuid,uuid,text)'::regprocedure, 'vol_video, cc_url)',
         'audio_url, audio_vol, audio_loop, audio_duck)',
         'audio_url, audio_vol, audio_loop, audio_duck, titolo, inizio_s, fine_s, sync_s, vol_video, cc_url)');
  raise notice 'edu_duplica_corso · colonne: %', r;
  r := pg_temp.edu_innesta('edu_duplica_corso(uuid,uuid,text)'::regprocedure, 'v_m.inizio_s',
         'v_m.audio_url, v_m.audio_vol, v_m.audio_loop, v_m.audio_duck)',
         'v_m.audio_url, v_m.audio_vol, v_m.audio_loop, v_m.audio_duck, v_m.titolo, v_m.inizio_s, v_m.fine_s, v_m.sync_s, v_m.vol_video, v_m.cc_url)');
  raise notice 'edu_duplica_corso · valori: %', r;
end $i$;

-- ------------------------------------------------------------
-- 3. Controllo finale: se qualcosa non è entrato, la migrazione fallisce
-- ------------------------------------------------------------
do $c$
declare d text;
begin
  d := pg_get_functiondef('edu_assembla_lezione(uuid)'::regprocedure);
  if position('''volv''' in d) = 0 or position('m.inizio_s' in d) = 0 then raise exception 'migr. 35: edu_assembla_lezione non porta i tagli della clip'; end if;
  d := pg_get_functiondef('edu_get_corsi(text)'::regprocedure);
  if position('''luogo''' in d) = 0 then raise exception 'migr. 35: edu_get_corsi non porta il luogo'; end if;
  d := pg_get_functiondef('edu_duplica_corso(uuid,uuid,text)'::regprocedure);
  if position('v_m.inizio_s' in d) = 0 then raise exception 'migr. 35: edu_duplica_corso non copia i tagli'; end if;
  -- la chiusura della migrazione 34 deve reggere: anon non esegue la funzione riservata
  if has_function_privilege('anon', 'edu_assembla_lezione(uuid)', 'execute') then
    raise exception 'migr. 35: anon esegue edu_assembla_lezione (la chiusura della migr. 34 non regge più)';
  end if;
end $c$;



-- ################################################################
-- ##  migrazione_36_area_trapani.sql
-- ################################################################

-- ============================================================
-- MIGRAZIONE 36 · area «Trapani, la città a forma di falce»
-- Esplora Edu · novembre 2026
--
-- FILE GENERATO da strumenti/genera_area_trapani.py: non modificarlo a mano.
--
-- Che cosa crea
--   · un corso a catalogo del tenant vetrina «esplora-trapani», pubblicato,
--     terzo dopo Antichi Mestieri (10) e Il viaggio di una goccia (20)
--   · 11 lezioni, una per luogo, con 13 racconti a 360° di U Cuntastorie
--   · per ogni racconto: taglio del video, voce a parte, sottotitoli, fermate
--     con il punto «?» già validato, domande junior e senior
--   · didattica.mappa = true sul corso e didattica.luogo su ogni lezione:
--     il player apre il corso con la mappa
--
-- Richiede la migrazione 35 (tagli della clip). Va applicata DOPO aver messo
-- online il player v2.9: quello vecchio ignorerebbe tagli e voce.
--
-- Ripetibile e prudente: se il corso c'è già NON tocca nulla, nemmeno una
-- virgola. Quello che viene corretto dalla regia dopo l'importazione resta.
-- ============================================================
do $trapani$
declare
  v_cli uuid; v_corso uuid; v_lez uuid; v_med uuid; v_tap uuid;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'edu_media' and column_name = 'inizio_s') then
    raise exception 'migr. 36: manca la migrazione 35 (tagli della clip). Applicala prima.';
  end if;
  select id into v_cli from edu_clienti where slug = 'esplora-trapani';
  if v_cli is null then raise exception 'migr. 36: non trovo il cliente «esplora-trapani»'; end if;
  if exists (select 1 from edu_corsi where proprietario_id = v_cli and slug = 'trapani-citta') then
    raise notice 'migr. 36: il corso «trapani-citta» esiste già: non tocco nulla.';
    return;
  end if;

  insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, descrizione, emoji, colore, fascia, prologo,
                         stato, ordine, visibilita, mascotte, didattica)
  values (v_cli, 'trapani-citta', 'Trapani, la città a forma di falce',
          'Chiese, palazzi, miti e leggende del centro storico: undici luoghi sulla mappa, raccontati a 360° da U Cuntastorie',
          'Un giro nel centro storico di Trapani in undici luoghi. In ogni luogo un racconto a 360°: ci si guarda intorno, si cerca il punto che brilla e si risponde alle domande.',
          '⚓', 'blu', 'entrambe', 'Ciao! Io sono Trapani, la città a forma di falce. Sono piena di storie: basta alzare gli occhi. Te le racconta U Cuntastorie, che queste chiese e questi palazzi li conosce pietra per pietra. Scegli un punto sulla mappa e partiamo!',
          'pubblicato', 25, 'catalogo',
          '{"img":"https://www.alessandromilia.it/project/esplora/mascotte.png","nome":"Trapani","video":{"junior":{},"senior":{},"entrambi":{}},"junior":true,"senior":true,"quiz_sempre":true}'::jsonb,
          '{"mappa":true}'::jsonb)
  returning id into v_corso;
  insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
  values (v_corso, v_cli, 'attivo', current_date, 'Corso proprio (migr. 36)')
  on conflict (corso_id, cliente_id) do nothing;


  -- ---------- 1. Tutto al femminile · Chiesa dei Cappuccini ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-cappuccini', 'Tutto al femminile', 'La finta Santa Lucia e le due braccia incrociate dei francescani', '🕯️', 'rosa', '~3 min',
          'Questa chiesa la chiamate tutti Santa Lucia. Sbagliato! Prima di dirti perché, ascolta da dove comincia il viaggio: in questa terra, da sempre, il sacro è donna.', 10, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa dei Cappuccini", "lat": 38.01676, "lng": 12.50095}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '44dc8d52-9ff1-4ab5-a72a-a1841f8a63fe', 'Tutto al femminile', 0.34, 207.34, 0.34, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n02.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n02.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 61.6, 'Tutti la chiamano Santa Lucia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -118, 12, '🕯️', 'La finta Santa Lucia',
          'Questa è la chiesa dell’Epifania dei Cappuccini. Ma per tanti anni qui c’era una strada dedicata a Santa Lucia, e il 13 dicembre la gente veniva a passare un fazzoletto di cotone sulla statua della santa per poi strofinarsi gli occhi.',
          'La chiesa è quella dell’Epifania dei Cappuccini, ma per decenni la strada era dedicata a Santa Lucia e il 13 dicembre i trapanesi venivano qui a passare un fazzoletto di bambagia sulla statua della santa, protettrice della vista, per poi strofinarsi gli occhi. Così il nome popolare è rimasto alla chiesa sbagliata.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 108.5, 'Guarda il portale: c’è un simbolo. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -150, 0, '🤝', 'Due braccia incrociate',
          'Sul portale ci sono due braccia incrociate: una nuda e una vestita. È il simbolo dei francescani. La leggenda dice che San Francesco si tolse una manica del saio per regalarla a un povero.',
          'Lo stemma francescano mostra due braccia incrociate, una nuda (Cristo) e una vestita (San Francesco), sopra il Calvario con la croce. Qui c’era il convento dei Cappuccini, costruito fuori dalle mura, dove fino al Trecento c’erano solo scogli e sabbia; oggi il convento accoglie l’università. Nella veduta della città del Settecento, al Museo Pepoli, si vede dietro il convento un grande orto e perfino una vasca per allevare pesci per i poveri.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che simbolo c’è sul portale?', '["Due braccia incrociate", "Una nave", "Un leone"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa passavano i trapanesi sulla statua di Santa Lucia, il 13 dicembre?', '["Un ramo di corallo", "Un fazzoletto di cotone", "Una candela accesa"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa rappresentano le due braccia incrociate, una nuda e una vestita?', '["Lo stemma del comune", "Lo stemma dei francescani", "Il simbolo dei pescatori"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come si chiama davvero la chiesa che tutti chiamano «Santa Lucia»?', '["Chiesa del Carmine", "Chiesa di Sant’Agostino", "Chiesa dell’Epifania dei Cappuccini"]'::jsonb, 2, 2);

  -- ---------- 2. La santa dei corallari · Ex chiesa di Santa Lucia ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-santa-lucia', 'La santa dei corallari', 'I pescatori di corallo e l’affresco ritrovato', '🪸', 'oro', '~4 min',
          'Ecco la vera chiesa di Santa Lucia. Qui la santa non proteggeva solo la vista: proteggeva i pescatori di corallo. E il corallo ha cambiato la mia storia.', 20, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Ex chiesa di Santa Lucia", "lat": 38.01702, "lng": 12.50254}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '38e125ee-db98-4c24-adf3-9f460d2d872b', 'La santa dei corallari', 2.12, 240.12, 2.12, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n03.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n03.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 39.6, 'Ecco chi pregava qui. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -5, 22, '🪸', 'I pescatori di corallo',
          'Santa Lucia era la protettrice dei pescatori di corallo. Avevano barche lunghe, strette e nere, e sulla prua mettevano sempre un bel ramo di corallo.',
          'A Trapani Santa Lucia era la protettrice dei corallari. Le loro barche, lunghe, strette e nere, avevano sulla prua un ramo di corallo. I corallari avevano almeno due approdi in città.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 95.4, 'Una scoperta fatta durante un restauro. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -25, 33, '🖼️', 'L’affresco ritrovato',
          'Durante un restauro nel Santuario della Madonna, sotto l’intonaco è comparso un affresco: i pescatori trapanesi trovano una montagna di corallo a Tabarca, in Tunisia. Con quella ricchezza la prima cosa che fanno è costruire una cappella per la Madonna.',
          'Nella cappella dei pescatori del Santuario dell’Annunziata, a metà della navata destra, sotto strati d’intonaco è emerso un affresco che racconta una pesca miracolosa di corallo a Tabarca, in Tunisia, tra il 1535 e il 1537. Con la nuova ricchezza i corallari costruirono la cappella dedicata alla Madonna di Trapani, all’inizio con un ingresso esterno.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi proteggeva Santa Lucia a Trapani?', '["I contadini", "I pescatori di corallo", "I soldati"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Com’erano le barche dei pescatori di corallo?', '["Rotonde e bianche", "Grandi come navi", "Lunghe, strette e nere"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Dove trovarono la “montagna di corallo” i pescatori trapanesi?', '["A Malta", "A Favignana", "A Tabarca, in Tunisia"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa costruirono i corallari con la ricchezza del corallo di Tabarca?', '["Una cappella per la Madonna di Trapani", "Un palazzo per sé", "Un nuovo porto"]'::jsonb, 0, 2);

  -- ---------- 3. La montagna è femmina · Mura di Tramontana ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-tramontana', 'La montagna è femmina', 'Erice, la montagna di Venere, e i riti delle donne per Demetra', '⛰️', 'blu', '~4 min',
          'Siamo sulle Mura di Tramontana. Da questa piccola insenatura partivano i corallari. E da qui guardi lei: la montagna sacra, la montagna femmina.', 30, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Mura di Tramontana", "lat": 38.01757, "lng": 12.50415}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'c34f5cb9-ee8a-4d28-a81d-51334bffb95b', 'La montagna è femmina', 174.67, 408.67, 174.67, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n04.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n04.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 231.3, 'Guarda verso la montagna. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -145, 4, '⛰️', 'La montagna di Venere',
          'Da qui si vede Erice, la montagna dedicata a Venere. Già gli Elimi, prima dei Greci e dei Romani, avevano un culto femminile della fertilità.',
          'Da questa piccola insenatura, forse la marina dei corallari, si vede il monte Erice, la montagna sacra a Venere. La città elima aveva un culto femminile ancora più antico: in tutta la Sicilia occidentale, da Erice a Segesta, a Monte Castellazzo di Poggioreale e a Entella, il riferimento della fertilità era sempre femminile.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 313.9, 'Un rito antichissimo, tutto di donne. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 166, -14, '🌾', 'Tre giorni senza mariti',
          'Nei riti per Demetra, la dea del grano, per tre giorni le donne lasciavano casa e mariti e si riunivano in un grande recinto circolare per offrire statuine di terracotta e chiedere la fertilità della terra.',
          'Nelle feste di Demetra (le Tesmoforie) le donne per almeno tre giorni lasciavano casa e mariti, uscivano dalla città e si riunivano in un grande recinto sacro, il tesmoforion, per offrire statuine di terracotta della dea del grano e dell’abbondanza, insieme a piccole offerte: un rito per la fertilità delle donne e della terra.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Quale montagna si vede dalle Mura di Tramontana?', '["L’Etna", "Monte Cofano", "Erice"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Di che cosa era la dea Demetra?', '["Del grano", "Del mare", "Della guerra"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'A quale dea era dedicata la montagna di Erice?', '["Venere", "Atena", "Giunone"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come si chiamavano le feste di Demetra riservate alle donne?', '["Olimpiadi", "Tesmoforie", "Saturnali"]'::jsonb, 1, 2);

  -- ---------- 4. La falce di Demetra · Mura di Tramontana, verso la città ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-falce', 'La falce di Demetra', 'Il mito che spiega la forma di Trapani e le stagioni', '🌙', 'verde', '~3 min',
          'Vuoi sapere perché ho questa forma? Me l’ha raccontato una maestra delle elementari, la prima cuntastorie di U Cuntastorie.', 40, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Mura di Tramontana, verso la città", "lat": 38.01693, "lng": 12.50698}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '0c783b9a-eada-436a-8cc7-ddf6253b16fe', 'La falce di demetra', 2.06, 184.06, 2.06, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n05.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n05.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 98.2, 'Ecco il mito della mia nascita. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -150, 0, '🌙', 'Perché Trapani è una falce',
          'Demetra cercava sua figlia Kore, rapita da Ade, volando su un carro tirato da serpenti alati. Nella mano aveva una falce: le cadde, finì nel mare… e diventò Trapani. Per questo la città ha la forma di una falce!',
          'Il mito: Kore, figlia di Demetra, coglie narcisi sul lago di Pergusa quando Ade la rapisce negli inferi. Demetra la cerca per tutti i cieli di Sicilia su un carro tirato da serpenti alati, con un fascio di spighe e una falce. La falce le cade di mano e dove cade nasce la città: Drepanon, “la falce”, da cui Trapani.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 171.8, 'Lo sai perché d’inverno fa freddo? Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -28, -2, '🍎', 'Sei chicchi di melograno',
          'Ade fece mangiare a Kore sei chicchi di melograno, e così lei doveva restare negli inferi sei mesi all’anno: autunno e inverno. Gli altri sei mesi torna dalla mamma ed è primavera ed estate.',
          'Giove, con Mercurio come mediatore, impone il ritorno di Kore, ma Ade le fa mangiare sei chicchi di melograno: per la legge antica degli inferi non potrà più lasciarli del tutto. L’accordo: sei mesi negli inferi (autunno e inverno), sei mesi con la madre, «a staciuni», primavera ed estate. Lo stesso mito si racconta a Segesta, dove il melograno è rinato dopo l’incendio.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa cadde dalla mano di Demetra e diventò Trapani?', '["Una falce", "Una spiga", "Una corona"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi rapì Kore, la figlia di Demetra?', '["Giove", "Ade", "Mercurio"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché Kore resta sei mesi negli inferi?', '["Ha perso la strada", "Ha mangiato sei chicchi di melograno", "Ha litigato con la madre"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa significa Drepanon, l’antico nome di Trapani?', '["Il porto", "La torre", "La falce"]'::jsonb, 2, 2);

  -- ---------- 5. L’uomo col leone · Palazzo Ferro ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-leone', 'L’uomo col leone', 'La leggenda di Alessandro Ferro, scolpita sopra le nostre teste', '🦁', 'rosa', '~2 min',
          'Quante volte sei passato qui davanti? E quante volte hai alzato gli occhi? Mai. C’è un uomo con un leone… e un cappello.', 50, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Palazzo Ferro", "lat": 38.01625, "lng": 12.508}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '237224a4-e402-49f2-bcb8-789305d4ef71', 'L’uomo col leone', 16.12, 144.12, 16.12, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n06.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n06.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 74.9, 'Ecco come comincia la storia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -38, 52, '🎩', 'Lo scherzo in Francia',
          'Alessandro Ferro era un nobile che a Trapani si sentiva stretto. Andò in Francia per farsi ammirare, ma lì lo presero in giro come un villano di campagna e gli fecero uno scherzo pericoloso.',
          'Alessandro Ferro, nobile forse di rango principesco, si sentiva poco considerato a Trapani e partì per la Francia per dimostrare la sua nobiltà. Lì lo trattarono come un provinciale e gli giocarono uno scherzo: lo portarono in un giardino con animali esotici e una gabbia con un leone.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 128, 'Che cosa fa Alessandro davanti al leone? Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -25, 50, '🦁', 'Il cappello sul leone',
          'Aprirono la gabbia e il leone arrivò dietro di lui. Alessandro, terrorizzato, si tolse il cappello e lo mise sulla testa del leone… e il leone si accucciò! Tornato a Trapani, si fece scolpire con il leone e il cappello.',
          'Gli altri scappano e aprono la gabbia: il leone gli arriva alle spalle, si ferma e lo guarda. Lui, terrorizzato, gli mette il cappello in testa e il leone si accuccia senza sbranarlo. Tornato nel suo palazzo, Ferro si fa scolpire con il leone e il cappello: è l’unica storia al maschile del percorso.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa mise Alessandro Ferro sulla testa del leone?', '["Una corona", "Il suo cappello", "Una sciarpa"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa fece il leone con il cappello in testa?', '["Ruggì fortissimo", "Scappò via", "Si accucciò"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché Alessandro Ferro andò in Francia?', '["Per comprare un leone", "Per studiare", "Per dimostrare la sua nobiltà"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come volle farsi scolpire Alessandro Ferro, tornato a Trapani?', '["Con il leone e il cappello", "A cavallo", "Con una spada in mano"]'::jsonb, 0, 2);

  -- ---------- 6. Chiesa del Collegio · Chiesa del Collegio dei Gesuiti ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-collegio', 'Chiesa del Collegio', 'Tre racconti: la chiesa che rinasce · acqua, terra, aria e fuoco · le sante nel muro', '⛪', 'oro', '~14 min',
          'Entriamo. Questa chiesa è rimasta chiusa per quarantadue anni. Chi l’ha riaperta ti racconta come si fa rinascere un luogo, un pezzo alla volta. Tre racconti, uno dopo l’altro: guardati intorno e, quando appare un “?”, toccalo.', 60, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa del Collegio dei Gesuiti", "lat": 38.01569, "lng": 12.50903}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '1aa7e709-4333-4337-b336-71869c9bc0a5', 'La chiesa che rinasce', 3.57, 305.57, 3.57, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n07.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n07.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 76.8, 'Ascolta la parte moderna di questa storia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -169, 5, '🔑', 'Chiusa per 42 anni',
          'Per 42 anni questa chiesa è rimasta chiusa. Davanti al portone c’erano un telone e una bancarella. Il 3 gennaio 2003 è stata riaperta, anche se il restauro non era finito.',
          'La chiesa del Collegio dei Gesuiti, dedicata all’Immacolata, è rimasta chiusa per 42 anni: davanti al portone un grande telo e una bancarella. L’idea di riaprirla, anche se non ultimata, nacque dalla soprintendente di allora, una donna. Il 3 gennaio 2003 la chiesa riaprì, piena di gente e con la banda.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 240.8, 'Un’idea rivoluzionaria per allora. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -50, 16, '🧱', 'Il cantiere aperto',
          'Ognuno poteva aiutare a restaurare un pezzo della chiesa e vedere quando il lavoro iniziava e quando finiva. È il “cantiere aperto”: tanti piccoli cantieri, poi un grande progetto di tre milioni di euro.',
          'Altari smontati, dipinti assenti, pavimento in parte smontato: dopo 42 anni di abbandono e piccoli furti, partì il “cantiere aperto” e “della conoscenza”. Il primo donatore fu il presidente di un club di servizio, che finanziò un altare; poi altri club, anche femminili, fino a un progetto di circa 3 milioni di euro e dieci anni di lavori. Tutti potevano vedere inizio, durata e fine di ogni intervento.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Per quanti anni è rimasta chiusa la chiesa del Collegio?', '["5", "100", "42"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'In che anno è stata riaperta la chiesa del Collegio?', '["2003", "1950", "1636"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cos’è il “cantiere aperto”?', '["Un restauro che tutti possono vedere e sostenere", "Un cantiere senza tetto", "Un mercato"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi ebbe l’idea di riaprire la chiesa anche se il restauro non era finito?', '["Il re", "La soprintendente di allora", "Un pescatore"]'::jsonb, 1, 2);

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 2, 'video360', '7bc50f53-f02b-40ed-a5f8-e00f5a04ea13', 'Acqua, terra, aria e fuoco', 11.58, 370.58, 11.58, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n08.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n08.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 62.6, 'Ecco la donna al centro di tutto. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -94, 17, '⚪', 'L’Immacolata di Marabitti',
          'Al centro c’è l’Immacolata, una scultura di Ignazio Marabitti. Tutto intorno ci sono immagini di donne della Bibbia, anche donne coraggiose come Giuditta.',
          'Chi entrava doveva avere un riferimento: l’Immacolata. La prima immagine era un dipinto del fiammingo Geronimo Gerardi, nella cappella laterale; poi venne la scultura di Ignazio Marabitti. Intorno, un percorso di immagini mariane e di donne della Bibbia, come Giuditta e Oloferne nei bassorilievi, e figure della genealogia di Maria come Aronne.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 345.7, 'Trapani vive di mare. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 144, 8, '🌊', 'L’altare è una nave',
          'Nei marmi dell’altare ci sono i quattro elementi: l’acqua con l’arca di Noè e i pesci, la terra con il grande grappolo d’uva, l’aria con gli uccelli e il pellicano, il fuoco con il carro di Elia. E tutto l’altare ha la forma di una nave!',
          'Nei marmi mischi dell’altare la storia delle donne si unisce ai quattro elementi: l’acqua (l’arca di Noè, pesci, tartarughe, granchi, aragosta, polpo e mostri marini attorno al giglio di Maria), la terra (il grappolo della Terra promessa, cornucopie e fiori), l’aria (la nube del deserto e gli uccelli, tra cui il pellicano, simbolo cristologico) e il fuoco (il carro di Elia). Ma a Trapani l’elemento principale è il mare: l’altare è una grande nave, con riccioli d’onda tagliati dalla chiglia.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che forma ha l’altare della chiesa del Collegio?', '["Un castello", "Un albero", "Una nave"]'::jsonb, 2, 3);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi ha scolpito l’Immacolata della chiesa del Collegio?', '["Ignazio Marabitti", "Michelangelo", "Leonardo da Vinci"]'::jsonb, 0, 4);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quali sono i quattro elementi raffigurati sull’altare?', '["Acqua, terra, aria e fuoco", "Sole, luna, stelle e mare", "Grano, olio, vino e sale"]'::jsonb, 0, 3);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Sull’altare, quale scena rappresenta il fuoco?', '["L’arca di Noè", "Il carro di Elia", "Il grande grappolo d’uva"]'::jsonb, 1, 4);

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 3, 'video360', 'a359c526-d65c-4013-bdb7-5780be0d83f4', 'Le sante nel muro', 2.89, 175.89, 2.89, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n09.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n09.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 53, 'Che cosa c’era dietro le crepe? Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 128, 22, '🔨', 'Un volto dal muro',
          'Dal ponteggio U Cuntastorie vide delle crepe. Fece aprire il muro e uscì fuori il volto di una donna! Dietro c’erano delle nicchie con le sante, murate da secoli.',
          'Durante i consolidamenti del tetto e delle pareti, dal ponteggio comparvero delle lesioni: o crollava qualcosa, o dietro c’era qualcosa. Un muratore aprì il punto centrale e apparve un volto di donna. Aperte le altre nicchie, vennero fuori le sante martiri siciliane delle province dove i Gesuiti erano presenti.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 106, 'Ne mancava una sola. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 150, 14, '🌹', 'Santa Rosalia dorme ancora',
          'Le sante erano Agata, Rosalia, Barbara, Oliva… Una nicchia però non si è aperta: con una piccola telecamera hanno visto che Santa Rosalia è ancora lì dietro, nascosta dai marmi.',
          'Agata, Rosalia, Barbara, Oliva: le sante siciliane rappresentate dai Gesuiti. L’unica nicchia non riaperta nasconde ancora Santa Rosalia: un piccolo foro con una telecamera dal retro ha confermato che i Gesuiti, nel Settecento, la ricoprirono di marmi per rendere la chiesa più bella. «Ancora adesso lì dorme Santa Rosalia».',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa trovarono dietro i muri della chiesa?', '["Un tesoro di monete", "Una porta segreta", "Nicchie con statue di sante"]'::jsonb, 2, 5);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa fece capire che dietro il muro c’era qualcosa?', '["Delle crepe", "Un rumore", "Una scritta"]'::jsonb, 0, 6);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale santa è ancora nascosta dietro i marmi?', '["Santa Rosalia", "Sant’Agata", "Santa Lucia"]'::jsonb, 0, 5);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come hanno scoperto che Santa Rosalia è ancora dietro i marmi?', '["Togliendo tutti i marmi", "Con una piccola telecamera", "Leggendo un libro antico"]'::jsonb, 1, 6);

  -- ---------- 7. L’asse sacro e profano · Palazzo Senatorio ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-senatorio', 'L’asse sacro e profano', 'La Madonna con le chiavi della città e il trucco degli architetti', '🗝️', 'blu', '~2 min',
          'Alza la testa sul Palazzo Senatorio: c’è la Madonna di Trapani con le chiavi della città, tra i due santi patroni. Qui la città è donna.', 70, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Palazzo Senatorio", "lat": 38.01536, "lng": 12.50961}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '768748cc-2fc4-40d6-a963-2828ce96840a', 'L’asse sacro e profano', 3.58, 128.59, 3.58, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n10.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n10.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 30.9, 'Guarda in alto, sulla facciata. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 3, 36, '🗝️', 'La Madonna con le chiavi',
          'In alto c’è la Madonna di Trapani con le chiavi della città, tra San Giovanni e Sant’Alberto, i patroni. I patroni sono uomini… ma la città è donna.',
          'Sulla facciata del Palazzo Senatorio la Madonna di Trapani tiene le chiavi della città, tra San Giovanni Battista e Sant’Alberto, patroni ufficiali. Qui, nella seconda metà del Trecento, con Giacomo d’Aragona la città si allarga oltre le vecchie porte: si aprono nuove strade e poi la Rua Nova, oggi via Garibaldi.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 122.6, 'Mettiti al centro della strada. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -36, 20, '👁️', 'Il trucco degli architetti',
          'Gli architetti di Giacomo d’Aragona hanno fatto un trucco: questo punto è un po’ più alto e la strada scende piano piano. Così, se ti metti al centro, vedi fino al mare!',
          'Dal centro dell’incrocio si vede la piazza del Mercato del pesce con la Venere e, un tempo, una statua della Madonna “della triangolazione” della Sicilia: un asse sacro e profano, Venere e Madonna. Gli architetti aragonesi rialzarono leggermente questo punto e fecero scendere la strada: un trucco prospettico che permette di vedere il mare.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa tiene in mano la Madonna sul Palazzo Senatorio?', '["Un ramo di corallo", "Una spada", "Le chiavi della città"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Mettendosi al centro della strada, che cosa si vede in fondo?', '["Il mare", "La montagna", "Un castello"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale re aragonese fece allargare la città oltre le mura nel Trecento?', '["Giacomo d’Aragona", "Federico II", "Carlo V"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi sono i due santi accanto alla Madonna sulla facciata?', '["San Pietro e San Paolo", "San Giovanni Battista e Sant’Alberto", "San Francesco e Sant’Antonio"]'::jsonb, 1, 2);

  -- ---------- 8. Il rosone dei tre popoli · Chiesa di Sant’Agostino ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-rosone', 'Il rosone dei tre popoli', 'Caruso e i pomodori, poi tre religioni in un rosone', '💠', 'verde', '~2 min',
          'Prima una storia di musica e pomodori, poi alza la testa sul rosone: l’hai visto mille volte, ma ci hai mai trovato dentro tre popoli?', 80, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa di Sant’Agostino", "lat": 38.01486, "lng": 12.50982}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '340b3ae0-68ef-4d9a-a402-3695b05724cb', 'Il rosone dei tre popoli', 22.45, 148.28, 12.95, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n11.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n11.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 44.9, 'Una storia di teatro… e di cuore spezzato. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 4, -10, '🍅', 'Caruso e i pomodori',
          'Il grande tenore Enrico Caruso, da giovanissimo, venne a Trapani a cantare. Sbagliò una nota e i trapanesi gli tirarono i pomodori! Aveva bevuto troppo per una delusione d’amore.',
          'Un giovanissimo Enrico Caruso arriva a Trapani per cantare allo “chalet”, il teatro che non esiste più, e stecca: i melomani trapanesi lo coprono di pomodori. Era ubriaco per una delusione amorosa. Insomma, anche qui c’entra una donna. (Aneddoto raccontato dalla guida.)',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 131.6, 'Guarda bene il rosone. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -43, 37, '✡️', 'Stella, gelosie e Agnello',
          'Nel rosone ci sono la stella di Davide, simbolo ebraico, delle parti traforate come le finestre arabe, e al centro l’Agnello di Dio, simbolo cristiano. Tre popoli insieme, in pace.',
          'Nel rosone convivono la stella di Davide, trafori a gelosia di gusto islamico e l’Agnus Dei cristiano al centro. U Cuntastorie lo ha restaurato al tempo della Coppa America: «ci piace pensare che sia un paradiso terrestre, dove tre popoli e tre religioni vivono in pace insieme». Curiosamente l’Agnus Dei è la parte più recente, rifatta dopo la guerra.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Quali simboli ci sono nel rosone di Sant’Agostino?', '["Stella di Davide, trafori arabi e Agnello di Dio", "Tre leoni", "Il sole e la luna"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa tirarono i trapanesi a Caruso?', '["Fiori", "Pomodori", "Monete"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa successe a Enrico Caruso a Trapani?', '["Vinse un premio", "Fu preso a pomodori dopo una stecca", "Cantò in chiesa"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Qual è la parte più recente del rosone, rifatta dopo la guerra?', '["La stella di Davide", "I trafori", "L’Agnello di Dio al centro"]'::jsonb, 2, 2);

  -- ---------- 9. Le stelle e la Venere · Chiesa del Carmine ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-carmine', 'Le stelle e la Venere', 'Gli osservatori delle stelle e la chiesa storta apposta', '🔭', 'rosa', '~3 min',
          'Un’altra storia al femminile, e un po’ di cielo: da qui i trapanesi guardavano le stelle. Poi una chiesa storta, apposta, e la signorina della piazza.', 90, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa del Carmine", "lat": 38.0169, "lng": 12.50965}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'fbdabb36-30f3-49bd-ab2e-97b53830d539', 'Le stelle e la venere', 27.1, 212.85, 27.1, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n12.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n12.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 66, 'Guarda la torre alta e stretta. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -48, -10, '🔭', 'Gli osservatori delle stelle',
          'Da quella torre, da poco restaurata, i trapanesi guardavano le stelle. Con il Collegio, Palazzo Riccio di San Gioacchino era uno degli osservatori astronomici della città.',
          'La torre alta e stretta di Palazzo Riccio di San Gioacchino, da poco restaurata, e il Collegio erano due osservatori astronomici al servizio della città: si contavano le stelle e, magari, si cercava il futuro.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 137.2, 'Guarda l’arco della facciata. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -85, 24, '⭐', 'La chiesa storta',
          'La facciata della chiesa del Carmine è storta, apposta! Nel Barocco bisognava stupire, e gli architetti hanno adattato tutto a uno spazio strano. Sopra c’è il simbolo del Monte Carmelo con tre stelle.',
          'La chiesa del Carmine ha un prospetto volutamente obliquo: in uno spazio irregolare gli architetti barocchi hanno piegato tutto, perfino l’arco, che non è circolare ma sghembo, con al centro il simbolo mariano. Lo stemma carmelitano è il Monte Carmelo con tre stelle. Qui, in tempo di guerra e di carestia, si portava al sicuro dentro le mura la Madonna di Trapani.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa guardavano i trapanesi dalla torre alta e stretta?', '["Le navi pirata", "Le stelle", "Il mercato"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa c’è nello stemma dei Carmelitani?', '["Un leone", "Una nave", "Un monte con tre stelle"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché la facciata del Carmine è storta?', '["Per un terremoto", "Per un errore", "Per adattarsi a uno spazio irregolare e stupire, come nel Barocco"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quali erano i due osservatori astronomici della città?', '["Palazzo Riccio di San Gioacchino e il Collegio", "Palazzo Senatorio e la chiesa del Carmine", "Villa Margherita e le Mura di Tramontana"]'::jsonb, 0, 2);

  -- ---------- 10. La santa degli impossibili · Via Garibaldi ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-santa-rita', 'La santa degli impossibili', 'Nonna Gina e la forza delle donne siciliane', '🌹', 'oro', '~2 min',
          'Questa è la storia di due donne: una santa che conosci, e la donna più importante della vita di U Cuntastorie.', 100, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Via Garibaldi", "lat": 38.01755, "lng": 12.5118}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'abb2627b-d7eb-4fec-9344-1e2504e0fd7c', 'La santa degli impossibili', 29.92, 136.3, 29.92, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n13.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n13.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 60.5, 'Una donna vera, di famiglia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -22, -10, '👵', 'Nonna Gina',
          'Nonna Gina ha cresciuto U Cuntastorie insieme alla sua mamma. Era devota a Santa Rita, la santa delle cose impossibili.',
          'Nonna Gina ha cresciuto U Cuntastorie insieme alla madre. Era devotissima a Santa Rita, «la santa degli impossibili»: aveva seguito per amore un uomo in Tunisia, lo aveva perso, era tornata e aveva ricostruito tutto, aprendo forse il primo B&B della città, nel 1935.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 124.7, 'Ascolta il messaggio di questa tappa. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 142, 18, '🌹', 'Niente è impossibile',
          'Rimasta sola con una bambina piccola e la casa distrutta dalla guerra, nonna Gina ha ricominciato da capo. È il simbolo della forza delle donne siciliane: nei momenti difficili ci si rimbocca le maniche e si va avanti.',
          'Con la figlia di cinque anni e ciò che aveva costruito distrutto dalla guerra, Gina ricominciò. Per U Cuntastorie è il simbolo della forza delle donne, in particolare delle donne siciliane: Santa Rita insegna che niente è impossibile, e che dal dolore bisogna rimboccarsi le maniche e reagire ancora meglio.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Perché Santa Rita è chiamata “la santa degli impossibili”?', '["Perché era molto alta", "Perché non parlava mai", "Perché si pregava per le cose che sembrano impossibili"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi era nonna Gina?', '["La nonna del cuntastorie", "Una regina", "Una santa"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa aprì nonna Gina a Trapani nel 1935?', '["Forse il primo B&B della città", "Un teatro", "Una scuola"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Dove aveva seguito un uomo, per amore, nonna Gina?', '["In Francia", "In Tunisia", "In America"]'::jsonb, 1, 2);

  -- ---------- 11. Margherita, l’ultima donna · Villa Margherita ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-margherita', 'Margherita, l’ultima donna', 'La regina che dà il nome a un giardino… e a una pizza', '👑', 'blu', '~1 min',
          'L’ultima donna del nostro viaggio dà il nome a questo giardino… e a una pizza.', 110, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Villa Margherita", "lat": 38.0176, "lng": 12.5156}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'f1f02c62-d474-47ba-86b1-2c8f961506d3', 'Margherita l’ultima donna', 46.08, 93.58, 13.08, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n14.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n14.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 66, 'Ecco l’ultima donna del percorso. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 79, 6, '👑', 'La regina Margherita',
          'Questo giardino si chiama Villa Margherita, per la regina Margherita. Alla regina è dedicata anche la pizza più famosa del mondo: pomodoro, mozzarella e basilico!',
          'L’ultima donna è Margherita di Savoia, prima regina d’Italia, a cui è intitolata la villa comunale. U Cuntastorie le è grato non per simpatie monarchiche ma… per la pizza Margherita, che secondo la tradizione porta il suo nome.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'A chi è dedicata Villa Margherita?', '["Alla regina Margherita", "A una pescatrice", "A una santa"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa c’è sulla pizza Margherita?', '["Tonno e cipolla", "Pomodoro, mozzarella e basilico", "Solo olio e sale"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale piatto famoso porta il nome della regina Margherita?', '["La cassata", "La pizza Margherita", "L’arancina"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi era Margherita di Savoia?', '["Una pittrice trapanese", "Una santa", "La prima regina d’Italia"]'::jsonb, 2, 2);

  raise notice 'migr. 36: creata l''area Trapani (% lezioni)', (select count(*) from edu_lezioni where corso_id = v_corso);
end $trapani$;
