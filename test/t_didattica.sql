-- TEST migrazione 32 — blocco didattico: esiti, diario, compiti, campi didattici, permessi.
-- Gira sulla replica locale (db_avvia.sh lo lancia da sé). Mai in produzione.
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;
select set_config('test.cli', (select id::text from edu_clienti where slug='salina-culcasi'), false);
-- PRECONDIZIONE: licenza del cliente e delle sue scuole attive. t_abbonamenti.sql, se gira prima
-- nella stessa catena, chiude l'abbonamento e fa scadere la licenza: senza questo i salvataggi
-- degli esiti verrebbero rifiutati per 'licenza' e il test parlerebbe di un problema che non c'è.
update edu_clienti set licenza_stato='attiva', licenza_fine=null, abbonamento_stato='nessuno',
       abbonamento_annulla_a_fine=false where slug='salina-culcasi';
update edu_scuole set licenza_stato='attiva' where cliente_id=current_setting('test.cli')::uuid;
-- …e dati PROPRI di questo test: scuola e due classi dedicate. t_rls_matrice.sql prova i DELETE
-- sulle classi e può portarsi via quelle della fixture: un test non deve dipendere dai dati di un altro.
insert into edu_scuole(cliente_id,nome,citta,tipo,licenza_stato)
select current_setting('test.cli')::uuid,'Scuola del test didattico','Erice','ospite','attiva'
where not exists (select 1 from edu_scuole where nome='Scuola del test didattico');
insert into edu_classi(codice,istituto,cliente_id,nome,anno,scuola_id)
select v.cod,'IC Test',current_setting('test.cli')::uuid,v.nome,'2026/27',
       (select id from edu_scuole where nome='Scuola del test didattico' limit 1)
from (values ('DID-5A','5ª A del test'),('DID-4B','4ª B del test')) as v(cod,nome)
on conflict (codice) do update set scuola_id=(select id from edu_scuole where nome='Scuola del test didattico' limit 1),
                                   cliente_id=current_setting('test.cli')::uuid;

\echo '=== 1. campi didattici su corso e lezione ==='
update edu_corsi set didattica = jsonb_build_object(
  'discipline', jsonb_build_array('storia','geografia','arte e immagine'),
  'traguardi', jsonb_build_object('primaria', jsonb_build_array('riconosce le tracce del passato nel territorio')),
  'uda', jsonb_build_object('monte_ore', 8, 'prodotto_finale', 'cartellone dei mestieri'))
where slug='la-salina';
update edu_lezioni set didattica = jsonb_build_object(
  'obiettivi', jsonb_build_object('primaria', jsonb_build_array('descrive il lavoro del salinaio')),
  'prima', 'Chiedere alla classe da dove arriva il sale che hanno in cucina.',
  'durante', 'Fermare il video alla pala e far descrivere il gesto.',
  'dopo', 'Disegnare la vasca salante e nominarne le parti.',
  'parole_chiave', jsonb_build_array('salina','vasca salante','pala'))
where slug='salinaio';
select _ok('didattica salvata sul corso e sulla lezione', (select (didattica->'uda'->>'monte_ore')::int from edu_corsi where slug='la-salina')=8
       and (select didattica->>'prima' from edu_lezioni where slug='salinaio') is not null);
select _ok('il player riceve la didattica del corso (edu_get_corsi)',
       (select x->'didattica'->'uda'->>'prodotto_finale' from jsonb_array_elements(edu_get_corsi('salina-culcasi')) as t(x) where x->>'id'='la-salina')='cartellone dei mestieri');
select _ok('il player riceve la didattica della lezione e del corso (edu_get_lezione_tenant)',
       (edu_get_lezione_tenant('salina-culcasi','salinaio')->'didattica'->>'durante') is not null
   and (edu_get_lezione_tenant('salina-culcasi','salinaio')->'corso'->'didattica'->'discipline'->>0)='storia');

\echo '=== 2. esito di una lezione: salvataggio, numeri, scuola agganciata ==='
select _ok('esito salvato in modalità aula',
  (edu_salva_esito(jsonb_build_object('cliente','salina-culcasi','classe','DID-5A','lezione','salinaio',
    'lezione_titolo','Il salinaio','livello','junior','modalita','aula','n_domande',5,'n_giuste',4,
    'dettaglio',jsonb_build_object('per_domanda',jsonb_build_array(jsonb_build_object('q',1,'pct',80)))))->>'ok')::boolean);
select _ok('percentuale calcolata dal database (4/5 = 80%)', (select pct from edu_esiti order by id desc limit 1)=80);
select _ok('scuola della classe agganciata all esito', (select scuola_id from edu_esiti order by id desc limit 1) is not null);
select _ok('corso e titolo copiati nell esito (resta leggibile se il corso cambia)',
       (select corso_titolo is not null and corso_id is not null from edu_esiti order by id desc limit 1));

\echo '=== 3. esito: validazioni e protezioni ==='
select _ok('cliente inesistente → err cliente', (edu_salva_esito('{"cliente":"non-esiste","classe":"X","lezione":"salinaio","n_domande":3,"n_giuste":1}')->>'err')='cliente');
select _ok('codice classe con caratteri strani → err classe', (edu_salva_esito('{"cliente":"salina-culcasi","classe":"<script>","lezione":"salinaio","n_domande":3,"n_giuste":1}')->>'err')='classe');
select edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"salinaio","n_domande":3,"n_giuste":99}') \g /dev/null
select _ok('n_giuste maggiore di n_domande → troncato a n_domande, nessuna riga incoerente',
  (select n_giuste=3 and n_domande=3 from edu_esiti order by id desc limit 1));
select edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"salinaio","modalita":"pirata","n_domande":2,"n_giuste":1}') \g /dev/null
select _ok('modalità inventata → ricade su aula', (select modalita from edu_esiti order by id desc limit 1)='aula');
select edu_salva_esito(jsonb_build_object('cliente','salina-culcasi','classe','DID-5A','lezione','salinaio','n_domande',1,'n_giuste',1,'dettaglio',jsonb_build_object('x',repeat('a',9000)))) \g /dev/null
select _ok('dettaglio gonfiato (>8KB) scartato, esito salvato comunque', (select dettaglio from edu_esiti order by id desc limit 1)='{}'::jsonb);
select edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"pagoto-1","n_domande":2,"n_giuste":2}') \g /dev/null
select _ok('lezione di un ALTRO cliente → esito salvato senza corso (non inquina il catalogo altrui)',
  (select corso_id is null and lezione_slug='pagoto-1' from edu_esiti order by id desc limit 1));

\echo '=== 4. doppio invio (il docente tocca due volte): una riga sola ==='
select set_config('test.n', (select count(*)::text from edu_esiti), false);
select _ok('primo invio ok', (edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"catena-rosa","modalita":"live","n_domande":6,"n_giuste":5,"n_partecipanti":22}')->>'ok')::boolean);
select _ok('secondo invio identico → gia_salvato, nessuna riga in più',
  (edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"catena-rosa","modalita":"live","n_domande":6,"n_giuste":5,"n_partecipanti":22}')->>'gia_salvato')::boolean
  and (select count(*) from edu_esiti) = current_setting('test.n')::int + 1);
select _ok('partecipanti registrati come semplice conteggio', (select n_partecipanti from edu_esiti where modalita='live' order by id desc limit 1)=22);

\echo '=== 5. licenza della scuola scaduta: esito rifiutato ==='
update edu_scuole set licenza_stato='scaduta' where id=(select scuola_id from edu_classi where codice='DID-5A');
select _ok('scuola con licenza scaduta → err licenza_scuola', (edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"salinaio","n_domande":3,"n_giuste":3}')->>'err')='licenza_scuola');
update edu_scuole set licenza_stato='attiva' where id=(select scuola_id from edu_classi where codice='DID-5A');
select _ok('riattivata la scuola, l esito torna a passare', (edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-5A","lezione":"salinaio","n_domande":3,"n_giuste":3}')->>'ok')::boolean);

\echo '=== 6. diario del percorso della classe ==='
insert into edu_eventi(codice_classe,progetto,lezione,tipo,dettaglio,cliente_id)
values ('DID-5A','sale-in-classe','salinaio','lezione_completata','{"livello":"junior"}',current_setting('test.cli')::uuid),
       ('DID-5A','sale-in-classe','salinaio','lezione_completata','{"livello":"junior"}',current_setting('test.cli')::uuid);
select _ok('il diario elenca le lezioni pubblicate del cliente', jsonb_array_length(edu_diario_classe('salina-culcasi','DID-5A'))>=2);
select _ok('lezione svolta: fatta=true, volte=2, data presente',
  (select (x->>'fatta')::boolean and (x->>'volte')::int=2 and (x->>'quando') is not null
   from jsonb_array_elements(edu_diario_classe('salina-culcasi','DID-5A')) as t(x) where x->>'lezione'='salinaio'));
select _ok('lezione mai svolta: fatta=false, volte=0', (select not (x->>'fatta')::boolean and (x->>'volte')::int=0 from jsonb_array_elements(edu_diario_classe('salina-culcasi','DID-5A')) as t(x) where x->>'lezione'='catena-rosa'));
select _ok('il diario NON mostra le lezioni di un altro cliente', not exists(select 1 from jsonb_array_elements(edu_diario_classe('salina-culcasi','DID-5A')) as t(x) where x->>'lezione'='corallo'));
select _ok('nel diario compare il miglior esito della lezione', (select (x->>'pct')::int from jsonb_array_elements(edu_diario_classe('salina-culcasi','DID-5A')) as t(x) where x->>'lezione'='salinaio')=100);
select _ok('diario di una classe mai vista: righe presenti, tutte da fare', (select bool_and(not (x->>'fatta')::boolean) from jsonb_array_elements(edu_diario_classe('salina-culcasi','MAI-VISTA')) as t(x)));
select _ok('il diario non mostra le bozze', not exists(select 1 from jsonb_array_elements(edu_diario_classe('salina-culcasi','DID-5A')) as t(x) where x->>'lezione'='bozza-x'));

\echo '=== 7. compito a casa ==='
insert into edu_compiti(cliente_id,corso_id,lezione_slug,codice,titolo,consegna,livello,clip,domande)
values (current_setting('test.cli')::uuid,(select id from edu_corsi where slug='la-salina'),'salinaio','SAL2026',
        'Rivedi la vasca salante','Guarda la clip e rispondi','junior',
        '{"guid":"g-salinaio","da":10,"a":70}',
        '[{"domanda":"Come si chiama la vasca dove il sale cristallizza?","opzioni":["Vasca salante","Vasca fredda","Vasca di scolo"],"ok":0},
          {"domanda":"Che attrezzo usa il salinaio?","opzioni":["Il rastrello","La pala","Il martello"],"ok":1}]');
select _ok('compito aperto dal suo codice', (edu_compito_apri('SAL2026')->>'titolo')='Rivedi la vasca salante');
select _ok('il compito porta la clip da rivedere', (edu_compito_apri('SAL2026')->'clip'->>'guid')='g-salinaio');
select _ok('LE RISPOSTE GIUSTE NON ESCONO dal server (nessun campo ok nelle domande)',
       not (edu_compito_apri('SAL2026')->'domande'->0 ? 'ok') and (edu_compito_apri('SAL2026')->'domande'->0->'opzioni'->>0)='Vasca salante');
select _ok('codice sbagliato → niente', edu_compito_apri('XXXXXX') is null);
select _ok('correzione sul server: 2 giuste su 2', (edu_compito_valuta('SAL2026','DID-5A','[0,1]')->>'n_giuste')::int=2);
select _ok('correzione: 1 su 2 con la risposta giusta indicata nel riscontro',
       ((edu_compito_valuta('SAL2026','DID-5A','[0,0]')->>'n_giuste')::int=1)
   and ((edu_compito_valuta('SAL2026','DID-5A','[0,0]')->'esito'->1->>'ok')::int=1));
select _ok('risposte non numeriche o mancanti → contate come sbagliate, nessun errore',
       (edu_compito_valuta('SAL2026','DID-5A','["pirata",null]')->>'n_giuste')::int=0);
select _ok('risposte non array → err risposte', (edu_compito_valuta('SAL2026','DID-5A','"ciao"')->>'err')='risposte');
select _ok('l esito del compito entra nel registro degli esiti', exists(select 1 from edu_esiti where modalita='compito' and lezione_slug='salinaio'));
update edu_compiti set scadenza = current_date - 1 where codice='SAL2026';
select _ok('compito scaduto → non si apre più', edu_compito_apri('SAL2026') is null);
select _ok('compito scaduto → non si consegna più', (edu_compito_valuta('SAL2026','DID-5A','[0,1]')->>'err')='compito');
update edu_compiti set scadenza = null, attivo=false where codice='SAL2026';
select _ok('compito disattivato → non si apre', edu_compito_apri('SAL2026') is null);
update edu_compiti set attivo=true where codice='SAL2026';

\echo '=== 8. permessi: chi legge gli esiti ==='
set role tester; select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
select _ok('editor della salina: vede gli esiti del suo cliente', (select count(*) from edu_esiti)>0);
select _ok('editor: vede i compiti del suo cliente', (select count(*) from edu_compiti)>0);
update edu_esiti set note='rifatto il 12/01' where id=(select max(id) from edu_esiti) \g /dev/null
select _ok('editor: può correggere a mano una nota sull esito', exists(select 1 from edu_esiti where note='rifatto il 12/01'));
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select _ok('editor di un ALTRO cliente: nessun esito della salina', (select count(*) from edu_esiti)=0);
select _ok('editor di un altro cliente: nessun compito della salina', (select count(*) from edu_compiti)=0);
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
select _ok('docente: legge gli esiti del suo cliente', (select count(*) from edu_esiti)>0);
select set_config('test.n2', (select count(*)::text from edu_esiti), false);
delete from edu_esiti where id=(select max(id) from edu_esiti) \g /dev/null
select _ok('docente: il tentativo di cancellare un esito non tocca nulla (lo può fare solo l editor)',
  (select count(*) from edu_esiti) = current_setting('test.n2')::int);
update edu_compiti set titolo='manomesso' where codice='SAL2026' \g /dev/null
select _ok('docente: non riesce a modificare un compito', not exists(select 1 from edu_compiti where titolo='manomesso'));
reset role;

\echo '=== 9. permessi: il player anonimo ==='
set role anon;
\echo '(atteso errore: anon non legge la tabella degli esiti)'
select count(*) from edu_esiti;
\echo '(atteso errore: anon non legge la tabella dei compiti — ci sono le risposte giuste)'
select count(*) from edu_compiti;
select _ok('anon PUÒ salvare un esito (è il player in aula)', (edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-4B","lezione":"salinaio","n_domande":4,"n_giuste":2}')->>'ok')::boolean);
select _ok('anon PUÒ leggere il diario della classe (dati aggregati)', jsonb_array_length(edu_diario_classe('salina-culcasi','DID-4B'))>0);
select _ok('anon PUÒ aprire un compito, sempre senza risposte giuste', not (edu_compito_apri('SAL2026')->'domande'->0 ? 'ok'));
select _ok('anon PUÒ consegnare un compito', (edu_compito_valuta('SAL2026','DID-4B','[0,1]')->>'ok')::boolean);
reset role;

\echo '=== 10. esportazione: i dati che la regia mette in CSV ==='
select _ok('esiti aggregabili per classe e lezione (quello che esporta la regia)',
  (select count(*) from (select codice_classe, lezione_slug, count(*) n, max(pct) migliore
                         from edu_esiti group by 1,2) t)>0);
select edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-4B","lezione":"salinaio","modalita":"ingresso","n_domande":10,"n_giuste":4}') \g /dev/null
select edu_salva_esito('{"cliente":"salina-culcasi","classe":"DID-4B","lezione":"salinaio","modalita":"uscita","n_domande":10,"n_giuste":9}') \g /dev/null
select _ok('pre e post test confrontabili sulla stessa classe: +50 punti percentuali',
  (select max(pct) filter (where modalita='uscita') - max(pct) filter (where modalita='ingresso')
   from edu_esiti where codice_classe='DID-4B')=50);
