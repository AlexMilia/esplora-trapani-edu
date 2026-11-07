-- TEST migrazione 34 — chiusura di sicurezza.
-- Quello che anon (la chiave pubblica del player) può e NON può fare sul
-- database. Gira sulla replica locale, che da oggi riproduce i privilegi di
-- default di Supabase: senza la 34 queste verifiche sono rosse.
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;

\echo '=== 1. le viste non si leggono con la chiave pubblica ==='
select _ok('v_edu_report_cliente: anon non ha SELECT',
  not has_table_privilege('anon', 'v_edu_report_cliente', 'select'));
select _ok('…e nemmeno authenticated (ci passa solo la RPC edu_report_mio_cliente)',
  not has_table_privilege('authenticated', 'v_edu_report_cliente', 'select'));
select _ok('le due viste legacy (edu_v_report_*) sono chiuse ad anon',
  not has_table_privilege('anon', 'edu_v_report_istituti', 'select')
  and not has_table_privilege('anon', 'edu_v_report_moduli', 'select'));
select _ok('le viste girano con i privilegi di chi chiama (security_invoker)',
  (select count(*) from pg_class c where c.relname in ('v_edu_report_cliente','edu_v_report_istituti','edu_v_report_moduli')
     and c.relkind = 'v' and 'security_invoker=true' = any (c.reloptions)) = 3);

\echo '=== 2. le funzioni riservate non si chiamano con la chiave pubblica ==='
select _ok('edu_assembla_lezione (bozze e quiz con le soluzioni): chiusa ad anon',
  not has_function_privilege('anon', 'edu_assembla_lezione(uuid)', 'execute'));
select _ok('edu_stats_cliente: chiusa ad anon',
  not has_function_privilege('anon', 'edu_stats_cliente(text)', 'execute'));
select _ok('edu_report_mio_cliente: chiusa ad anon',
  not has_function_privilege('anon', 'edu_report_mio_cliente()', 'execute'));
select _ok('edu_duplica_corso: chiusa ad anon',
  not has_function_privilege('anon', 'edu_duplica_corso(uuid,uuid,text)', 'execute'));
select _ok('nessuna funzione edu_* è concessa a PUBLIC',
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'edu\_%' and has_function_privilege('public', p.oid, 'execute')) = 0);

\echo '=== 3. …ma il player continua a funzionare ==='
select _ok('le RPC del player restano eseguibili da anon',
  has_function_privilege('anon', 'edu_get_cliente(text)', 'execute')
  and has_function_privilege('anon', 'edu_get_corsi(text)', 'execute')
  and has_function_privilege('anon', 'edu_get_lezione_tenant(text,text)', 'execute')
  and has_function_privilege('anon', 'edu_get_lezione_token(text)', 'execute')
  and has_function_privilege('anon', 'edu_get_lezioni(text)', 'execute')
  and has_function_privilege('anon', 'edu_get_mascotte(text)', 'execute')
  and has_function_privilege('anon', 'edu_classe_stato(uuid,text)', 'execute')
  and has_function_privilege('anon', 'edu_diario_classe(text,text)', 'execute')
  and has_function_privilege('anon', 'edu_salva_esito(jsonb)', 'execute')
  and has_function_privilege('anon', 'edu_compito_apri(text)', 'execute')
  and has_function_privilege('anon', 'edu_compito_valuta(text,text,jsonb)', 'execute'));
select _ok('la regia (authenticated) conserva le sue funzioni',
  has_function_privilege('authenticated', 'edu_assembla_lezione(uuid)', 'execute')
  and has_function_privilege('authenticated', 'edu_stats_cliente(text)', 'execute')
  and has_function_privilege('authenticated', 'edu_e_admin()', 'execute')
  and has_function_privilege('authenticated', 'edu_elenco_clienti()', 'execute'));
set role anon;
select _ok('da anon: una lezione pubblicata si legge ancora (edu_get_lezione_tenant)',
  edu_get_lezione_tenant('salina-culcasi','salinaio') is not null);
reset role;

\echo '=== 4. un evento storto non rompe le statistiche del cliente ==='
-- come farebbe un chiamante malizioso: live non booleano, pct_classe non numerico.
-- (il cliente_id lo conosce chiunque: lo restituisce edu_get_cliente)
select id as cid from edu_clienti where slug = 'salina-culcasi' \gset
set role anon;
insert into edu_eventi(codice_classe, progetto, lezione, tipo, dettaglio, cliente_id)
  values ('DID-5A', 'antichi-mestieri-trapani', 'salinaio', 'quiz_esito',
          '{"live":"xyz","pct_classe":"tanto","punti":"x","su":"y"}'::jsonb, :'cid');
reset role;
select _ok('l''evento storto entra (anon può scrivere eventi)',
  exists (select 1 from edu_eventi where dettaglio->>'live' = 'xyz'));
set test.uid = '11111111-1111-1111-1111-111111111111';
set role authenticated;
select _ok('edu_stats_cliente risponde lo stesso, senza errore',
  (select edu_stats_cliente('salina-culcasi')) is not null);
select _ok('…e il quiz storto conta come non-live con percentuale nulla',
  (select (edu_stats_cliente('salina-culcasi')->'totali'->>'quiz')::int) >= 1);
reset role;
select _ok('edu_num: numeri sì, parole no',
  edu_num(' 86 ') = 86 and edu_num('12.5') = 12.5 and edu_num('tanto') is null and edu_num('') is null);
select _ok('edu_bool: true/false/1/0, il resto è null',
  edu_bool('true') and not edu_bool('0') and edu_bool('xyz') is null);

\echo '=== 5. quello che anon NON può più scrivere ==='
set role anon;
\echo '(atteso errore: dettaglio troppo grande)'
insert into edu_eventi(codice_classe, progetto, lezione, tipo, dettaglio)
  values ('DID-5A', 'antichi-mestieri-trapani', 'salinaio', 'quiz_esito',
          ('{"x":"' || repeat('a', 5000) || '"}')::jsonb);
\echo '(atteso errore: richiesta già «attivata» e agganciata a un cliente)'
insert into edu_richieste(scuola, email, stato, cliente_id)
  values ('Scuola finta', 'x@y.it', 'attivata', :'cid');
\echo '(atteso errore: messaggio oltre i 1000 caratteri)'
insert into edu_richieste(scuola, email, messaggio) values ('Scuola finta', 'x@y.it', repeat('m', 1001));
insert into edu_richieste(scuola, email, referente, messaggio) values ('IC Prova', 'prova@scuola.it', 'Prof', 'Vorremmo provare.');
reset role;
select _ok('la richiesta normale invece entra, con stato «nuova»',
  exists (select 1 from edu_richieste where scuola = 'IC Prova' and stato = 'nuova' and cliente_id is null));
select _ok('nessuna richiesta «attivata» è entrata da anon',
  not exists (select 1 from edu_richieste where scuola = 'Scuola finta'));
select _ok('nessun evento con dettaglio gigante è entrato',
  not exists (select 1 from edu_eventi where pg_column_size(dettaglio) >= 4000));
delete from edu_eventi where dettaglio->>'live' = 'xyz';
delete from edu_richieste where scuola in ('IC Prova','Scuola finta');
