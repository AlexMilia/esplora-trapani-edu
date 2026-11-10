-- TEST migrazioni 35 e 36 — l'area «Trapani, la città a forma di falce».
-- Verifica che cosa vedono DAVVERO le scuole (ruolo anon, come il player), che
-- ogni racconto abbia taglio, voce e sottotitoli, che le fermate cadano dentro
-- il pezzo di video che si vede, che nessun testo parli dell'evento in cui i
-- video sono stati girati, e che rilanciare la migrazione non rovini le correzioni.
-- Gira sulla replica locale (db_avvia.sh lo lancia da sé). Mai in produzione.
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;
create or replace view _tp_lez as
  select l.* from edu_lezioni l join edu_corsi c on c.id = l.corso_id where c.slug = 'trapani-citta';

-- nella replica l'IC Pagoto nasce con le fixture, dopo le migrazioni: rilancio la 36 perché riceva la licenza
\ir ../migrazioni/migrazione_36_area_trapani.sql

\echo '=== 1. il corso ==='
select _ok('il corso c''è, pubblicato e a catalogo, del tenant vetrina',
  exists (select 1 from edu_corsi c join edu_clienti k on k.id = c.proprietario_id
          where c.slug='trapani-citta' and c.stato='pubblicato' and c.visibilita='catalogo' and k.slug='esplora-trapani'));
select _ok('viene dopo Antichi Mestieri (10) e Il viaggio di una goccia (20)',
  (select ordine from edu_corsi where slug='trapani-citta') > 20
  and (select ordine from edu_corsi where slug='trapani-citta') > (select max(ordine) from edu_corsi where slug in ('antichi-mestieri','la-vita-della-goccia')));
select _ok('porta il segnale della mappa (didattica.mappa = true)', (select didattica->'mappa' from edu_corsi where slug='trapani-citta') = 'true'::jsonb);
select _ok('11 lezioni, tutte pubblicate e senza proprietario privato', (select count(*) from _tp_lez where stato='pubblicata' and owner is null) = 11 and (select count(*) from _tp_lez) = 11);
select _ok('13 racconti in tutto; la chiesa del Collegio ne ha 3',
  (select count(*) from edu_media m join _tp_lez l on l.id = m.lezione_id) = 13
  and (select count(*) from edu_media m join _tp_lez l on l.id = m.lezione_id where l.slug='trapani-collegio') = 3);
select _ok('ogni lezione ha il suo luogo con nome e coordinate dentro Trapani',
  not exists (select 1 from _tp_lez l where coalesce(l.didattica->'luogo'->>'nome','') = ''
     or (l.didattica->'luogo'->>'lat')::numeric not between 38.010 and 38.022
     or (l.didattica->'luogo'->>'lng')::numeric not between 12.495 and 12.520));

\echo '=== 2a. prima dell''accensione: solo la scuola di prova ==='
set role anon;
select _ok('la scuola di prova vede SOLO l''area Trapani, con 11 lezioni',
  (select string_agg(x->>'id' || ':' || jsonb_array_length(x->'lezioni'), ',') from jsonb_array_elements(edu_get_corsi('prova-trapani')) x) = 'trapani-citta:11');
select _ok('la scuola di prova apre la lezione', jsonb_array_length(edu_get_lezione_tenant('prova-trapani','trapani-collegio')->'video') = 3);
select _ok('vetrina e IC Pagoto NON la vedono ancora (il loro player è quello vecchio)',
  not exists (select 1 from jsonb_array_elements(edu_get_corsi('esplora-trapani') || edu_get_corsi('ic-pagoto')) x where x->>'id'='trapani-citta'));
reset role;
\ir ../migrazioni/migrazione_37_accendi_trapani.sql

\echo '=== 2b. dopo la migrazione 37: che cosa vede una scuola (ruolo anon, come il player) ==='
set role anon;
select _ok('il tenant vetrina vede il corso nell''elenco, con 11 lezioni',
  (select jsonb_array_length(x->'lezioni') from jsonb_array_elements(edu_get_corsi('esplora-trapani')) x where x->>'id'='trapani-citta') = 11);
select _ok('ogni lezione dell''elenco porta il luogo (serve alla mappa)',
  (select count(*) from jsonb_array_elements(edu_get_corsi('esplora-trapani')) x, jsonb_array_elements(x->'lezioni') l
    where x->>'id'='trapani-citta' and (l->'luogo'->>'lat') is not null and (l->'luogo'->>'nome') is not null) = 11);
select _ok('l''elenco porta didattica.mappa', (select x->'didattica'->'mappa' from jsonb_array_elements(edu_get_corsi('esplora-trapani')) x where x->>'id'='trapani-citta') = 'true'::jsonb);
select _ok('nell''elenco il corso sta dopo i due già pubblicati',
  (select array_position(array_agg(x->>'id' order by o), 'trapani-citta') from jsonb_array_elements(edu_get_corsi('esplora-trapani')) with ordinality t(x,o))
  > (select array_position(array_agg(x->>'id' order by o), 'antichi-mestieri') from jsonb_array_elements(edu_get_corsi('esplora-trapani')) with ordinality t(x,o)));
select _ok('l''IC Pagoto, che ha la licenza, lo vede con le 11 lezioni',
  (select jsonb_array_length(x->'lezioni') from jsonb_array_elements(edu_get_corsi('ic-pagoto')) x where x->>'id'='trapani-citta') = 11);
select _ok('un cliente senza licenza per questo corso NON lo vede (salina-culcasi)',
  not exists (select 1 from jsonb_array_elements(edu_get_corsi('salina-culcasi')) x where x->>'id'='trapani-citta'));
select _ok('la lezione arriva al player con taglio, voce e sottotitoli (Collegio, 3 clip)',
  (select count(*) from jsonb_array_elements(edu_get_lezione_tenant('esplora-trapani','trapani-collegio')->'video') v
    where (v->>'da')::numeric >= 0 and (v->>'a')::numeric > (v->>'da')::numeric and (v->>'t0') is not null
      and (v->>'volv')::int = 22 and v->>'cc' like 'https://%.vtt' and v->'audio'->>'url' like 'https://%.mp3'
      and (v->'audio'->>'loop')::boolean = false and (v->>'tit') is not null) = 3);
select _ok('…e ogni clip del Collegio ha le sue fermate (v = 0, 1, 2)',
  (select count(distinct t->>'v') from jsonb_array_elements(edu_get_lezione_tenant('esplora-trapani','trapani-collegio')->'tappe') t) = 3);
select _ok('l''IC Pagoto apre la lezione', jsonb_array_length(edu_get_lezione_tenant('ic-pagoto','trapani-collegio')->'video') = 3);
select _ok('un cliente senza licenza non apre la lezione nemmeno conoscendone il nome',
  coalesce(edu_get_lezione_tenant('salina-culcasi','trapani-collegio')->'video', '[]'::jsonb) = '[]'::jsonb
  or edu_get_lezione_tenant('salina-culcasi','trapani-collegio') is null);
\echo '(atteso errore: anon non legge le tabelle)'
select count(*) from edu_media;
reset role;

\echo '=== 3. ogni racconto è completo ==='
select _ok('ogni clip: video Bunny, inizio < fine, punto zero della voce, volume del video basso',
  not exists (select 1 from edu_media m join _tp_lez l on l.id = m.lezione_id
    where m.tipo <> 'video360' or m.guid !~ '^[0-9a-f-]{36}$' or m.inizio_s is null or m.fine_s is null or m.fine_s <= m.inizio_s
       or m.sync_s is null or m.sync_s > m.inizio_s or m.vol_video is distinct from 22));
select _ok('ogni clip: voce in mp3 https, non in ciclo, a volume pieno; sottotitoli in vtt https',
  not exists (select 1 from edu_media m join _tp_lez l on l.id = m.lezione_id
    where m.audio_url !~ '^https://.+\.mp3$' or m.audio_loop or m.audio_duck or m.audio_vol <> 100 or m.cc_url !~ '^https://.+\.vtt$'));
select _ok('13 video diversi: nessun racconto ripetuto', (select count(distinct m.guid) from edu_media m join _tp_lez l on l.id = m.lezione_id) = 13);
select _ok('ogni fermata cade DENTRO il pezzo di video che si vede',
  not exists (select 1 from edu_tappe t join edu_media m on m.id = t.media_id join _tp_lez l on l.id = t.lezione_id
    where t.t <= m.inizio_s or t.t >= m.fine_s));
select _ok('ogni racconto ha almeno una fermata', not exists (select 1 from edu_media m join _tp_lez l on l.id = m.lezione_id
    where not exists (select 1 from edu_tappe t where t.media_id = m.id)));
select _ok('ogni fermata ha il suo punto «?», con titolo e due testi (primaria e medie), già validato',
  not exists (select 1 from edu_tappe t join _tp_lez l on l.id = t.lezione_id
    where (select count(*) from edu_hotspot h where h.tappa_id = t.id and h.validazione = 'validato'
             and coalesce(h.tit,'') <> '' and coalesce(h.txt,'') <> '' and coalesce(h.txt2,'') <> ''
             and h.yaw between -180 and 180 and h.pitch between -90 and 90) <> 1));
select _ok('ogni lezione ha almeno 2 domande per la primaria e 2 per le medie',
  not exists (select 1 from _tp_lez l where (select count(*) from edu_quiz q where q.lezione_id = l.id and q.livello='junior') < 2
                                          or (select count(*) from edu_quiz q where q.lezione_id = l.id and q.livello='senior') < 2));
select _ok('ogni domanda: tre risposte e quella giusta esiste', not exists (select 1 from edu_quiz q join _tp_lez l on l.id = q.lezione_id
    where jsonb_array_length(q.opzioni) <> 3 or q.ok not between 0 and 2));
select _ok('la risposta giusta non sta sempre allo stesso posto',
  (select count(distinct q.ok) from edu_quiz q join _tp_lez l on l.id = q.lezione_id) = 3
  and (select max(n) from (select count(*) n from edu_quiz q join _tp_lez l on l.id = q.lezione_id group by q.ok) z)
      < 0.5 * (select count(*) from edu_quiz q join _tp_lez l on l.id = q.lezione_id));

\echo '=== 4. solo la storia di Trapani: nessun riferimento all''evento ==='
create or replace view _tp_testi as
  select 'corso' dove, concat_ws(' ', titolo, sottotitolo, descrizione, prologo, mascotte::text) t from edu_corsi where slug='trapani-citta'
  union all select 'lezione', concat_ws(' ', titolo, sottotitolo, intro, didattica::text) from _tp_lez
  union all select 'clip', m.titolo from edu_media m join _tp_lez l on l.id = m.lezione_id
  union all select 'fermata', concat_ws(' ', t.cocciu, t.cocciu2) from edu_tappe t join _tp_lez l on l.id = t.lezione_id
  union all select 'punto', concat_ws(' ', h.tit, h.txt, h.txt2) from edu_hotspot h join edu_tappe t on t.id = h.tappa_id join _tp_lez l on l.id = t.lezione_id
  union all select 'quiz', concat_ws(' ', q.domanda, q.opzioni::text, q.spiegazione) from edu_quiz q join _tp_lez l on l.id = q.lezione_id;
select _ok('nei testi non compaiono: Pink Lady, Ciccio, Pilates, tumore, camminata, «Attenti a quei due»',
  not exists (select 1 from _tp_testi where t ~* '(pink|lady|ciccio|pilates|gambicchia|tumor|camminat|attenti a quei|18 ottobre|prufissure|no gravity)'));
select _ok('il racconto che presentava il giro e quello della ginnastica in piazza non ci sono',
  not exists (select 1 from edu_media m join _tp_lez l on l.id = m.lezione_id where m.audio_url ~ '/n(01|15)\.mp3$'));
select _ok('Sant''Agostino parte DOPO il saluto all''evento (9,5 secondi di voce tagliati)',
  (select m.inizio_s - m.sync_s from edu_media m join _tp_lez l on l.id = m.lezione_id where l.slug='trapani-rosone') = 9.5);
select _ok('Villa Margherita: tagliati l''inizio e il saluto finale, resta la regina (33 → 80,5 s di voce)',
  (select (m.inizio_s - m.sync_s, m.fine_s - m.sync_s) = (33.0, 80.5) from edu_media m join _tp_lez l on l.id = m.lezione_id where l.slug='trapani-margherita')
  and (select count(*) from edu_tappe t join _tp_lez l on l.id = t.lezione_id where l.slug='trapani-margherita') = 1);

\echo '=== 5. rilanciare la migrazione non rovina le correzioni fatte in regia ==='
update edu_lezioni set titolo = 'TITOLO CORRETTO IN REGIA' where slug = 'trapani-leone';
delete from edu_quiz where lezione_id = (select id from _tp_lez where slug = 'trapani-falce');
\ir ../migrazioni/migrazione_36_area_trapani.sql
select _ok('il titolo corretto a mano resta', (select titolo from edu_lezioni where slug='trapani-leone') = 'TITOLO CORRETTO IN REGIA');
select _ok('le domande cancellate a mano non ricompaiono', (select count(*) from edu_quiz where lezione_id = (select id from _tp_lez where slug='trapani-falce')) = 0);
update edu_catalogo set stato='sospeso', note='sospesa a mano' where corso_id=(select id from edu_corsi where slug='trapani-citta') and cliente_id=(select id from edu_clienti where slug='ic-pagoto');
\ir ../migrazioni/migrazione_36_area_trapani.sql
\ir ../migrazioni/migrazione_37_accendi_trapani.sql
select _ok('una licenza sospesa a mano resta sospesa, anche rilanciando 36 e 37', (select stato from edu_catalogo where corso_id=(select id from edu_corsi where slug='trapani-citta') and cliente_id=(select id from edu_clienti where slug='ic-pagoto')) = 'sospeso');
select _ok('niente doppioni: sempre 1 corso, 11 lezioni, 13 racconti',
  (select count(*) from edu_corsi where slug='trapani-citta') = 1 and (select count(*) from _tp_lez) = 11
  and (select count(*) from edu_media m join _tp_lez l on l.id = m.lezione_id) = 13);

\echo '=== 6. la migrazione 35 regge ==='
\ir ../migrazioni/migrazione_35_clip_tagli_mappa.sql
select _ok('rilanciata, non innesta due volte', (select (length(d) - length(replace(d, '''volv''', ''))) / 6 from (select pg_get_functiondef('edu_assembla_lezione(uuid)'::regprocedure) d) z) = 1);
\echo '(atteso errore: un taglio con la fine prima dell''inizio viene rifiutato)'
update edu_media set fine_s = 1, inizio_s = 5 where id = (select m.id from edu_media m join _tp_lez l on l.id = m.lezione_id limit 1);
\echo '(atteso errore: i sottotitoli devono essere un file .vtt in https)'
update edu_media set cc_url = 'javascript:alert(1)' where id = (select m.id from edu_media m join _tp_lez l on l.id = m.lezione_id limit 1);
select _ok('le lezioni di prima non hanno tagli: si vedono come sempre',
  not exists (select 1 from edu_media m where m.lezione_id not in (select id from _tp_lez) and (m.inizio_s is not null or m.fine_s is not null or m.cc_url is not null)));

\echo '=== 7. migr. 38: il menu dei corsi sa quali lezioni hanno la LIS ==='
update edu_media set video_lis = 'aa2bf8b1-446d-494e-9434-6bd0d49dc17a'
 where lezione_id = (select id from _tp_lez where slug = 'trapani-collegio') and ordine in (1, 2);
set role anon;
select _ok('l''elenco conta le clip con LIS (2 su 3 al Collegio)',
  (select (l->'acc'->>'lis_clip')::int = 2 and (l->'acc'->>'n_clip')::int = 3 from jsonb_array_elements(edu_get_corsi('prova-trapani')) x, jsonb_array_elements(x->'lezioni') l where l->>'id' = 'trapani-collegio'));
select _ok('una lezione senza LIS porta zero, non un valore mancante',
  (select (l->'acc'->>'lis_clip')::int = 0 and (l->'acc'->>'n_clip')::int = 1 from jsonb_array_elements(edu_get_corsi('prova-trapani')) x, jsonb_array_elements(x->'lezioni') l where l->>'id' = 'trapani-leone'));
select _ok('il resto dell''accessibilità non si perde', (select (l->'acc'->>'ipovedenti')::boolean from jsonb_array_elements(edu_get_corsi('prova-trapani')) x, jsonb_array_elements(x->'lezioni') l where l->>'id' = 'trapani-leone'));
reset role;

drop view _tp_testi; drop view _tp_lez;
