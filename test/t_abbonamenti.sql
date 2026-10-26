-- TEST migrazione 30 — ciclo di vita di un abbonamento via eventi (come li manda il webhook)
-- Ogni passo: PRIMA applica l'evento (una istruzione), POI legge lo stato (istruzione separata):
-- nella stessa istruzione la sotto-select vedrebbe ancora lo stato precedente (snapshot).
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;
select set_config('test.cli', (select id::text from edu_clienti where slug='salina-culcasi'), false);
create temp table _r(k text primary key, v jsonb);
create or replace function _ev(j jsonb) returns jsonb language plpgsql as $$ declare r jsonb; begin r := edu_abbonamento_evento(j); insert into _r values (j->>'id', r) on conflict (k) do update set v = excluded.v; return r; end $$;

\echo '=== 1. evento su abbonamento sconosciuto (arriva prima dell aggancio): NON registrato, retry possibile ==='
select _ok('evento orfano → err "cliente non trovato" (il webhook risponde 500 e Stripe ritenta)', (_ev('{"id":"evt_0","tipo":"invoice.paid","subscription":"sub_ignota"}')->>'err') = 'cliente non trovato');
select _ok('nessun pagamento registrato', (select count(*) from edu_pagamenti) = 0);

\echo '=== 2. creazione (metadata cliente_id) → in_attesa, link salvato ==='
select _ev(jsonb_build_object('id','evt_1','tipo','customer.subscription.created','subscription','sub_1','customer','cus_1','cliente_id',current_setting('test.cli'),'stato_sub','incomplete','pausa',false,'cancel_at_period_end',false,'link','https://invoice.stripe.com/i/abc')) \g /dev/null
select _ok('cliente in_attesa con link della fattura e id Stripe agganciati', abbonamento_stato='in_attesa' and abbonamento_link='https://invoice.stripe.com/i/abc' and stripe_subscription_id='sub_1' and stripe_customer_id='cus_1') from edu_clienti where slug='salina-culcasi';

\echo '=== 3. pagamento → attivo, licenza attiva fino a fine periodo ==='
select _ev('{"id":"evt_2","tipo":"invoice.paid","subscription":"sub_1","customer":"cus_1","invoice":"in_1","importo_cent":5000,"valuta":"eur","periodo_da":"2026-09-24T00:00:00Z","periodo_a":"2027-09-24T00:00:00Z","stato_invoice":"paid"}') \g /dev/null
select _ok('pagato → abbonamento attivo, licenza attiva fino al 2027-09-24', abbonamento_stato='attivo' and licenza_stato='attiva' and licenza_fine='2027-09-24') from edu_clienti where slug='salina-culcasi';
select _ok('retry dello stesso evento → gia_applicato=true (idempotenza)', (_ev('{"id":"evt_2","tipo":"invoice.paid","subscription":"sub_1"}')->>'gia_applicato')::boolean);
select _ok('…e il pagamento resta registrato una volta sola', (select count(*) from edu_pagamenti where stripe_evento_id='evt_2') = 1);

\echo '=== 4. pausa → in_pausa, licenza sospesa; ripresa → attivo, licenza attiva ==='
select _ev('{"id":"evt_3","tipo":"customer.subscription.updated","subscription":"sub_1","stato_sub":"active","pausa":true}') \g /dev/null
select _ok('pausa → in_pausa e licenza sospesa', abbonamento_stato='in_pausa' and licenza_stato='sospesa') from edu_clienti where slug='salina-culcasi';
select _ev('{"id":"evt_4","tipo":"customer.subscription.updated","subscription":"sub_1","stato_sub":"active","pausa":false}') \g /dev/null
select _ok('ripresa → attivo e licenza attiva', abbonamento_stato='attivo' and licenza_stato='attiva') from edu_clienti where slug='salina-culcasi';

\echo '=== 5. annulla a fine periodo → resta attivo, flag acceso ==='
select _ev('{"id":"evt_5","tipo":"customer.subscription.updated","subscription":"sub_1","stato_sub":"active","pausa":false,"cancel_at_period_end":true}') \g /dev/null
select _ok('annulla a fine periodo → ancora attivo, flag annulla_a_fine=true, licenza attiva', abbonamento_stato='attivo' and abbonamento_annulla_a_fine and licenza_stato='attiva') from edu_clienti where slug='salina-culcasi';

\echo '=== 6. insoluto → stato insoluto, licenza NON toccata ==='
select _ev('{"id":"evt_6","tipo":"invoice.payment_failed","subscription":"sub_1","invoice":"in_2","importo_cent":5000,"stato_invoice":"open"}') \g /dev/null
select _ok('insoluto → abbonamento insoluto, licenza ancora attiva (si decide a mano)', abbonamento_stato='insoluto' and licenza_stato='attiva') from edu_clienti where slug='salina-culcasi';

\echo '=== 7. cancellazione definitiva → annullato, licenza scaduta oggi ==='
select _ev('{"id":"evt_7","tipo":"customer.subscription.deleted","subscription":"sub_1","stato_sub":"canceled"}') \g /dev/null
select _ok('cancellato → annullato, licenza scaduta con fine = oggi', abbonamento_stato='annullato' and licenza_stato='scaduta' and licenza_fine=current_date) from edu_clienti where slug='salina-culcasi';
select _ok('storico: 7 eventi distinti registrati per sub_1 (evt_1…evt_7, il retry non raddoppia)', (select count(*) from edu_pagamenti where stripe_subscription_id='sub_1') = 7);

\echo '=== 8. permessi ==='
set role tester; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select _ok('admin legge stato e storico via edu_abbonamento_cliente', (edu_abbonamento_cliente(current_setting('test.cli')::uuid)->>'stato')='annullato' and jsonb_array_length(edu_abbonamento_cliente(current_setting('test.cli')::uuid)->'pagamenti')=7);
\echo '(atteso errore: authenticated non applica eventi)'
select edu_abbonamento_evento('{"id":"evt_h","tipo":"invoice.paid","subscription":"sub_1"}');
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
select _ok('editor: edu_abbonamento_cliente restituisce null (solo admin)', edu_abbonamento_cliente(current_setting('test.cli')::uuid) is null);
reset role; set role anon;
\echo '(atteso errore: anon non legge i pagamenti)'
select count(*) from edu_pagamenti;
reset role;
