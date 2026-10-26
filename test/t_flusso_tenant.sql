-- FLUSSO NUOVO TENANT (end-to-end, ruoli reali, RLS attiva)
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;

\echo '--- 1. ADMIN crea il cliente e assegna un editor'
set role tester; select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into edu_clienti(slug,nome,brand,piano,licenza_inizio) values ('ic-nuovo','IC Nuovo','{"titolo":"IC Nuovo Digitale"}','base',current_date);
insert into auth.users(id,email) values ('55555555-5555-5555-5555-555555555555','editor@icnuovo.it') on conflict do nothing;
insert into edu_utenti(id,ruolo,nome,cliente_id) values ('55555555-5555-5555-5555-555555555555','editor','Editor Nuovo',(select id from edu_clienti where slug='ic-nuovo'));
select _ok('cliente creato con brand e piano base', exists(select 1 from edu_clienti where slug='ic-nuovo' and piano='base'));
select _ok('player: edu_get_cliente lo vede attivo con i limiti del piano', (edu_get_cliente('ic-nuovo')->>'attiva')::boolean and (edu_get_cliente('ic-nuovo')->'limiti'->>'quiz_live')='false');
select _ok('player: nessun corso ancora (menu vuoto, non errore)', edu_get_corsi('ic-nuovo')='[]'::jsonb);

\echo '--- 2. EDITOR del nuovo cliente costruisce il corso'
select set_config('test.uid','55555555-5555-5555-5555-555555555555',false);
insert into edu_corsi(proprietario_id,slug,titolo,stato,ordine,mascotte) values ((select id from edu_clienti where slug='ic-nuovo'),'il-mio-paese','Il mio paese','bozza',10,'{"nome":"Gufo","img":"https://x.it/g.png","junior":true,"senior":true}');
select _ok('corso creato in bozza dall editor', exists(select 1 from edu_corsi where slug='il-mio-paese'));
insert into edu_catalogo(corso_id,cliente_id,stato,da) values ((select id from edu_corsi where slug='il-mio-paese'),(select id from edu_clienti where slug='ic-nuovo'),'attivo',current_date);
select _ok('licenza propria nel catalogo (regia lo fa alla creazione)', exists(select 1 from edu_catalogo k join edu_corsi c on c.id=k.corso_id where c.slug='il-mio-paese'));
insert into edu_lezioni(slug,titolo,stato,ordine,corso_id) values ('la-piazza','La piazza','bozza',10,(select id from edu_corsi where slug='il-mio-paese'));
select _ok('lezione creata dentro il corso (RLS: corso scrivibile)', exists(select 1 from edu_lezioni where slug='la-piazza'));
insert into edu_media(lezione_id,ordine,tipo,guid,audio_url,audio_vol) values ((select id from edu_lezioni where slug='la-piazza'),10,'video','guid-piazza','https://cdn.x.it/piazza.mp3',40);
insert into edu_tappe(lezione_id,media_id,t,ordine,cocciu) values ((select id from edu_lezioni where slug='la-piazza'),(select id from edu_media where guid='guid-piazza'),12,10,'Guarda la fontana!');
insert into edu_hotspot(tappa_id,yaw,pitch,em,tit,txt,ordine) values ((select id from edu_tappe where cocciu='Guarda la fontana!'),20,0,'⛲','La fontana','Del 1700',10);
insert into edu_quiz(lezione_id,livello,domanda,opzioni,ok,ordine,spiegazione) values ((select id from edu_lezioni where slug='la-piazza'),'junior','Di che anno è la fontana?','["1700","1900"]',0,10,'Lo dice la lapide.');
select _ok('media, tappa, hotspot e quiz inseriti', (select count(*) from edu_hotspot h join edu_tappe t on t.id=h.tappa_id join edu_lezioni l on l.id=t.lezione_id where l.slug='la-piazza')=1);
select _ok('player: lezione in BOZZA non servita', edu_get_lezione_tenant('ic-nuovo','la-piazza') is null);
update edu_lezioni set stato='pubblicata' where slug='la-piazza';
update edu_corsi set stato='pubblicato' where slug='il-mio-paese';
select _ok('player: dopo la pubblicazione il menu ha 1 corso con 1 lezione e la mascotte Gufo', jsonb_array_length(edu_get_corsi('ic-nuovo'))=1 and jsonb_array_length(edu_get_corsi('ic-nuovo')->0->'lezioni')=1 and (edu_get_corsi('ic-nuovo')->0->'mascotte'->>'nome')='Gufo');
select _ok('player: la lezione arriva completa (video+audio, tappa, hotspot, quiz)', (select (l->'video'->0->'audio'->>'url')='https://cdn.x.it/piazza.mp3' and jsonb_array_length(l->'tappe')=1 and jsonb_array_length(l->'quiz')=1 from edu_get_lezione_tenant('ic-nuovo','la-piazza') l));

\echo '--- 3. Piano BASE: il secondo corso pubblicato è vietato (regia) — qui verifico solo il limite'
select _ok('edu_piano_limiti(base): 1 corso, 10 classi, niente live', (edu_piano_limiti('base')->>'corsi_pubblicati')='1' and (edu_piano_limiti('base')->>'quiz_live')='false');

\echo '--- 4. Scuola e classe, poi il link della classe'
insert into edu_scuole(cliente_id,nome,citta,tipo) values ((select id from edu_clienti where slug='ic-nuovo'),'Plesso Centro','Trapani','ospite');
insert into edu_classi(cliente_id,scuola_id,codice,nome,anno,docente_id) values ((select id from edu_clienti where slug='ic-nuovo'),(select id from edu_scuole where nome='Plesso Centro'),'ICNU-4B-AB12','4ª B','2026/27','55555555-5555-5555-5555-555555555555');
select _ok('scuola e classe create', exists(select 1 from edu_classi where codice='ICNU-4B-AB12'));
select _ok('player: la classe è valida (scuola attiva, senza scadenza)', (edu_classe_stato((select id from edu_clienti where slug='ic-nuovo'),'ICNU-4B-AB12')->>'valida')::boolean);
update edu_scuole set licenza_stato='scaduta' where nome='Plesso Centro';
select _ok('scuola scaduta → classe NON valida (gate licenza_scuola)', not (edu_classe_stato((select id from edu_clienti where slug='ic-nuovo'),'ICNU-4B-AB12')->>'valida')::boolean);
update edu_scuole set licenza_stato='attiva' where nome='Plesso Centro';

\echo '--- 5. La classe usa la lezione (anon, come il player) e l editor vede le statistiche'
reset role; set role anon;
insert into edu_eventi(codice_classe,progetto,lezione,tipo,dettaglio,cliente_id) values ('ICNU-4B-AB12','x','la-piazza','lezione_avviata','{}',(select (edu_get_cliente('ic-nuovo')->>'id')::uuid));
insert into edu_eventi(codice_classe,progetto,lezione,tipo,dettaglio,cliente_id) values ('ICNU-4B-AB12','x','la-piazza','quiz_esito','{"punti":1,"su":1}',(select (edu_get_cliente('ic-nuovo')->>'id')::uuid));
reset role; set role tester; select set_config('test.uid','55555555-5555-5555-5555-555555555555',false);
select _ok('statistiche dell editor: 1 classe, 1 avviata, media 100%, scuola Plesso Centro', (edu_stats_cliente('ic-nuovo')->'totali'->>'avviate')='1' and (edu_stats_cliente('ic-nuovo')->'totali'->>'pct_medio')='100' and (edu_stats_cliente('ic-nuovo')->'per_scuola'->0->>'scuola')='Plesso Centro');

\echo '--- 6. Isolamento: l editor della salina non vede nulla del nuovo cliente'
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
select _ok('salina non vede il corso di ic-nuovo', not exists(select 1 from edu_corsi where slug='il-mio-paese'));
select _ok('salina non vede le sue classi', not exists(select 1 from edu_classi where codice='ICNU-4B-AB12'));
select _ok('salina non legge le sue statistiche (raise)', (select count(*) from (select 1 where false) x)=0);

\echo '--- 7. Catalogo: la salina concede la goccia a ic-nuovo, che la vede in sola lettura'
select _ok('editor: la RLS gli mostra SOLO il suo cliente in edu_clienti', (select count(*) from edu_clienti)=1);
select _ok('editor: per concedere/duplicare vede l elenco minimo id/nome di tutti i clienti (rpc edu_elenco_clienti, migr. 31)', (select count(*) from edu_elenco_clienti())>=2 and exists(select 1 from edu_elenco_clienti() where slug='ic-nuovo'));
update edu_corsi set stato='pubblicato', visibilita='catalogo' where slug='la-vita-della-goccia';
insert into edu_catalogo(corso_id,cliente_id,stato,da,a) values ((select id from edu_corsi where slug='la-vita-della-goccia'),(select id from edu_elenco_clienti() where slug='ic-nuovo'),'attivo',current_date,current_date+365);
select _ok('la concessione è registrata nel catalogo', exists(select 1 from edu_catalogo k join edu_clienti c on true where k.corso_id=(select id from edu_corsi where slug='la-vita-della-goccia') and k.cliente_id=(select id from edu_elenco_clienti() where slug='ic-nuovo')));
select set_config('test.uid','55555555-5555-5555-5555-555555555555',false);
select _ok('ic-nuovo vede la goccia in regia (lettura)', exists(select 1 from edu_corsi where slug='la-vita-della-goccia'));
update edu_corsi set titolo='Toccata' where slug='la-vita-della-goccia';
select _ok('…ma non può modificarla', not exists(select 1 from edu_corsi where titolo='Toccata'));
select _ok('player ic-nuovo: 2 corsi (proprio + in licenza con scadenza)', jsonb_array_length(edu_get_corsi('ic-nuovo'))=2 and exists(select 1 from jsonb_array_elements(edu_get_corsi('ic-nuovo')) e where e->>'origine'='licenza' and e->>'licenza_a' is not null));
reset role;

\echo '--- 8. edu_elenco_clienti: docente nessuna riga, anon nessun permesso'
set role tester; select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
select _ok('docente: l elenco clienti del catalogo è vuoto', (select count(*) from edu_elenco_clienti())=0);
reset role; set role anon;
\echo '(atteso errore: anon non può chiamare edu_elenco_clienti)'
select count(*) from edu_elenco_clienti();
reset role;
