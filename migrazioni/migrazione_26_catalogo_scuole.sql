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
