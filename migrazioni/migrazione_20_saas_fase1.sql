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
