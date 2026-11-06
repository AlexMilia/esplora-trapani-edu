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
