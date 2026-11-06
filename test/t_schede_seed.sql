-- TEST migrazione 33 — i testi delle schede entrano nelle lezioni.
-- Verifica che il seed riempia le lezioni vuote, che NON tocchi quelle già
-- compilate in regia, che trovi la lezione anche quando lo slug è diverso,
-- e che quello che scrive sia davvero ciò che scheda.php legge.
-- Gira sulla replica locale (db_avvia.sh lo lancia da sé). Mai in produzione.
\set ON_ERROR_STOP off
create or replace function _ok(nome text, cond boolean) returns text language sql as $$ select case when cond then '  ✓ ' else '  ❌ ' end || nome $$;
grant execute on function _ok(text,boolean) to anon, authenticated, tester;

-- ---------------------------------------------------------------------------
-- Dati propri del test: questo file non deve dipendere da quello che hanno
-- lasciato gli altri. Azzero le schede e creo le lezioni dei mestieri che
-- nella replica non ci sono.
-- ---------------------------------------------------------------------------
update edu_lezioni set didattica = coalesce(didattica, '{}'::jsonb) - 'scheda' where owner is null;

insert into edu_lezioni(corso_id, progetto, slug, titolo, stato, ordine, token)
select (select id from edu_corsi where slug='antichi-mestieri' limit 1),
       'antichi-mestieri-trapani', v.slug, v.tit, 'pubblicata', v.ord, 'tok-'||v.slug
from (values ('tappeti-ericini','Il tessitore di tappeti ericini',40),
             ('raccolta-delle-olive','La raccolta delle olive',50),
             ('vendemmia','La vendemmia',60)) as v(slug,tit,ord)
where not exists (select 1 from edu_lezioni l where l.slug = v.slug and l.owner is null);

\echo '=== 1. il seed riempie le lezioni vuote ==='
\ir ../migrazioni/migrazione_33_schede_contenuti.sql

select _ok('il salinaio ha la scheda in database',
  (select didattica->'scheda' from edu_lezioni where slug='salinaio' and owner is null) is not null
  and (select didattica->'scheda' from edu_lezioni where slug='salinaio' and owner is null) <> '{}'::jsonb);

select _ok('tutti e cinque i mestieri hanno una scheda',
  (select count(*) from edu_lezioni where owner is null
    and coalesce(didattica->'scheda','{}'::jsonb) <> '{}'::jsonb) >= 5);

\echo '=== 2. dentro c''è quello che scheda.php legge ==='
select _ok('fasi del lavoro (sono l''esercizio da riordinare)',
  jsonb_array_length((select didattica->'scheda'->'fasi' from edu_lezioni where slug='salinaio' and owner is null)) = 5);
select _ok('glossario come elenco di oggetti {parola}',
  (select didattica->'scheda'->'glossario'->0->>'parola' from edu_lezioni where slug='salinaio' and owner is null) = 'munzeddu');
select _ok('distrattore: una cosa che nel video NON c''è',
  jsonb_array_length((select didattica->'scheda'->'distrattori' from edu_lezioni where slug='salinaio' and owner is null)) >= 1);
select _ok('vero/falso con almeno una frase falsa (serve alla versione adattata)',
  exists (select 1 from jsonb_array_elements((select didattica->'scheda'->'vero_falso' from edu_lezioni where slug='salinaio' and owner is null)) x
          where (x->>'v')::boolean is false));
select _ok('parte adattata: quattro cose da cercare, tre fasi, tre parole',
  jsonb_array_length((select didattica->'scheda'->'adattata'->'trova4' from edu_lezioni where slug='salinaio' and owner is null)) = 4
  and jsonb_array_length((select didattica->'scheda'->'adattata'->'fasi3' from edu_lezioni where slug='salinaio' and owner is null)) = 3
  and jsonb_array_length((select didattica->'scheda'->'adattata'->'parole' from edu_lezioni where slug='salinaio' and owner is null)) = 3);
select _ok('numero della scheda e totale (il «n. 1 di 5» in testata)',
  (select (didattica->'scheda'->>'numero')::int from edu_lezioni where slug='salinaio' and owner is null) = 1
  and (select (didattica->'scheda'->>'di')::int from edu_lezioni where slug='salinaio' and owner is null) = 5);
select _ok('ogni mestiere ha il suo numero, non tutti «1»',
  (select count(distinct didattica->'scheda'->>'numero') from edu_lezioni
    where owner is null and coalesce(didattica->'scheda','{}'::jsonb) <> '{}'::jsonb) >= 5);
select _ok('la didattica che c''era già non è stata cancellata',
  (select didattica ? 'scheda' from edu_lezioni where slug='salinaio' and owner is null));

\echo '=== 3. non sovrascrive il lavoro fatto in regia ==='
update edu_lezioni set didattica = jsonb_set(didattica, '{scheda}',
  '{"prima":"DOMANDA SCRITTA DALLA REGIA","fasi":["una fase sola"]}'::jsonb)
where slug='salinaio' and owner is null;
\ir ../migrazioni/migrazione_33_schede_contenuti.sql
select _ok('la scheda modificata in regia resta intatta dopo un nuovo lancio',
  (select didattica->'scheda'->>'prima' from edu_lezioni where slug='salinaio' and owner is null) = 'DOMANDA SCRITTA DALLA REGIA');
select _ok('…e il seed non ci ha rimesso dentro i suoi campi',
  (select didattica->'scheda' ? 'glossario' from edu_lezioni where slug='salinaio' and owner is null) is false);

\echo '=== 4. ripetibile: svuotando, si ricarica il testo di partenza ==='
update edu_lezioni set didattica = coalesce(didattica,'{}'::jsonb) - 'scheda' where slug='salinaio' and owner is null;
\ir ../migrazioni/migrazione_33_schede_contenuti.sql
select _ok('svuotata in regia e rilanciata, la scheda torna quella di partenza',
  (select didattica->'scheda'->>'prima' from edu_lezioni where slug='salinaio' and owner is null) like 'Secondo te%');

\echo '=== 5. trova la lezione anche se lo slug è diverso (match sul titolo) ==='
update edu_lezioni set slug='lez-zz1', didattica = coalesce(didattica,'{}'::jsonb) - 'scheda'
 where slug='corallo' and owner is null;
\ir ../migrazioni/migrazione_33_schede_contenuti.sql
select _ok('lezione «Il corallo» trovata per titolo anche con slug sconosciuto',
  (select coalesce(didattica->'scheda','{}'::jsonb) <> '{}'::jsonb from edu_lezioni where slug='lez-zz1' and owner is null));
update edu_lezioni set slug='corallo' where slug='lez-zz1' and owner is null;

\echo '=== 6. le copie dei docenti non vengono toccate ==='
select _ok('una copia con owner non riceve la scheda dal seed',
  not exists (select 1 from edu_lezioni where owner is not null
              and coalesce(didattica->'scheda','{}'::jsonb) <> '{}'::jsonb));

\echo '=== 7. il player riceve la scheda dentro la lezione ==='
select _ok('edu_get_lezione_tenant espone didattica.scheda',
  (edu_get_lezione_tenant('salina-culcasi','salinaio')->'didattica'->'scheda') is not null);
