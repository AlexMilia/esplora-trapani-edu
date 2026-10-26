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
