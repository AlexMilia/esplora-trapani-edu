-- MATRICE RLS ESEGUITA — ruoli reali × tabelle × operazioni
-- Ruoli: anon | docente (salina) | editor (salina) | editor (ic-pagoto, licenziatario) | admin
create or replace function _prova(op text, sql text) returns text language plpgsql as $$
declare n int; begin
  begin
    if op = 'S' then execute 'select count(*) from (' || sql || ') x' into n; return n::text;
    else execute sql; get diagnostics n = row_count; return case when n > 0 then 'OK' else '0' end; end if;
  exception when others then return case when sqlstate in ('42501') then 'NEG' when sqlstate = '42P01' then 'NOTAB' else 'ERR:' || sqlstate end;
  end;
end $$;

drop table if exists _matrice; create table _matrice(ruolo text, tabella text, op text, esito text, atteso text);
grant all on _matrice to anon, authenticated, tester; grant execute on function _prova(text,text) to anon, authenticated, tester;

do $$
declare
  ruoli text[][] := array[
    ['anon','anon',''],
    ['docente','tester','33333333-3333-3333-3333-333333333333'],
    ['editor-salina','tester','22222222-2222-2222-2222-222222222222'],
    ['editor-icp','tester','44444444-4444-4444-4444-444444444444'],
    ['admin','tester','11111111-1111-1111-1111-111111111111']];
  r text[]; t text; e text;
  sal uuid := (select id from edu_clienti where slug='salina-culcasi');
  icp uuid := (select id from edu_clienti where slug='ic-pagoto');
  lez_sal uuid := (select id from edu_lezioni where slug='salinaio' and owner is null limit 1);
  lez_icp uuid := (select l.id from edu_lezioni l join edu_corsi co on co.id=l.corso_id where co.proprietario_id=icp limit 1);
  co_sal uuid := (select id from edu_corsi where slug='la-salina');
begin
  foreach r slice 1 in array ruoli loop
    perform set_config('test.uid', r[3], false);
    execute 'set role ' || r[2];

    -- LETTURE (quante righe vede)
    foreach t in array array['edu_clienti','edu_corsi','edu_catalogo','edu_scuole','edu_classi','edu_lezioni','edu_media','edu_quiz','edu_eventi','edu_utenti','edu_richieste','edu_messaggi','edu_progetti','edu_mascotte','edu_versioni'] loop
      insert into _matrice values (r[1], t, 'S', _prova('S', 'select 1 from ' || t), null);
    end loop;
    -- SCRITTURE mirate
    insert into _matrice values (r[1],'edu_clienti','I', _prova('I', $q$insert into edu_clienti(slug,nome) values ('x-'||floor(random()*1e6),'X')$q$), null);
    insert into _matrice values (r[1],'edu_corsi(salina)','U', _prova('U', format($q$update edu_corsi set descrizione='t' where proprietario_id=%L$q$, sal)), null);
    insert into _matrice values (r[1],'edu_scuole(salina)','I', _prova('I', format($q$insert into edu_scuole(cliente_id,nome) values (%L,'S-test')$q$, sal)), null);
    insert into _matrice values (r[1],'edu_classi(salina,altrui)','D', _prova('D', format($q$delete from edu_classi where cliente_id=%L and docente_id is distinct from auth.uid() and codice='TP-IC12-5A'$q$, sal)), null);
    insert into _matrice values (r[1],'edu_lezioni(salina)','U', _prova('U', format($q$update edu_lezioni set sottotitolo='t' where id=%L$q$, lez_sal)), null);
    insert into _matrice values (r[1],'edu_lezioni(icp)','U', _prova('U', format($q$update edu_lezioni set sottotitolo='t' where id=%L$q$, lez_icp)), null);
    insert into _matrice values (r[1],'edu_catalogo(la-salina→icp)','I', _prova('I', format($q$insert into edu_catalogo(corso_id,cliente_id) values (%L,%L) on conflict do nothing$q$, co_sal, icp)), null);
    insert into _matrice values (r[1],'edu_eventi','I', _prova('I', $q$insert into edu_eventi(codice_classe,progetto,lezione,tipo) values ('AUDIT-1A','x','y','lezione_avviata')$q$), null);
    insert into _matrice values (r[1],'edu_eventi(tipo falso)','I', _prova('I', $q$insert into edu_eventi(codice_classe,progetto,lezione,tipo) values ('AUDIT-1A','x','y','hack')$q$), null);
    insert into _matrice values (r[1],'edu_messaggi','I', _prova('I', $q$insert into edu_messaggi(chiave,progetto,titolo) values ('h-'||floor(random()*1e6),'x','Iniezione')$q$), null);
    insert into _matrice values (r[1],'edu_richieste','I', _prova('I', $q$insert into edu_richieste(scuola,email) values ('Scuola Audit','a@b.it')$q$), null);
    insert into _matrice values (r[1],'edu_utenti(promozione)','U', _prova('U', $q$update edu_utenti set ruolo='admin' where id='99999999-9999-9999-9999-999999999999'$q$), null);
    reset role;
  end loop;
end $$;

-- ATTESI (S = numero >0 o 0 ; I/U/D = OK o NEG/0)
update _matrice m set atteso = a.v from (values
 ('anon','edu_clienti','S','NEG'),('anon','edu_lezioni','S','NEG'),('anon','edu_eventi','S','NEG'),('anon','edu_messaggi','S','NEG'),('anon','edu_progetti','S','NEG'),('anon','edu_versioni','S','NEG'),('anon','edu_utenti','S','NEG'),
 ('anon','edu_eventi','I','OK'),('anon','edu_eventi(tipo falso)','I','NEG'),('anon','edu_richieste','I','OK'),('anon','edu_messaggi','I','NEG'),('anon','edu_clienti','I','NEG'),('anon','edu_utenti(promozione)','U','NEG'),
 ('docente','edu_scuole(salina)','I','0'),('docente','edu_classi(salina,altrui)','D','0'),('docente','edu_lezioni(salina)','U','0'),('docente','edu_clienti','I','0'),('docente','edu_utenti(promozione)','U','0'),('docente','edu_messaggi','I','0'),
 ('editor-salina','edu_scuole(salina)','I','OK'),('editor-salina','edu_lezioni(salina)','U','OK'),('editor-salina','edu_lezioni(icp)','U','0'),('editor-salina','edu_catalogo(la-salina→icp)','I','OK'),('editor-salina','edu_clienti','I','0'),('editor-salina','edu_utenti(promozione)','U','0'),
 ('editor-icp','edu_lezioni(salina)','U','0'),('editor-icp','edu_corsi(salina)','U','0'),('editor-icp','edu_catalogo(la-salina→icp)','I','0'),
 ('admin','edu_clienti','I','OK'),('admin','edu_lezioni(salina)','U','OK'),('admin','edu_utenti(promozione)','U','OK')
) as a(r,t,o,v) where m.ruolo=a.r and m.tabella=a.t and m.op=a.o;
update _matrice set esito='NEG' where esito='0' and op<>'S' and atteso='0'; update _matrice set atteso='NEG' where atteso='0';

\echo '=== LETTURE (righe visibili per ruolo) ==='
select tabella,
  max(case when ruolo='anon' then esito end) as anon,
  max(case when ruolo='docente' then esito end) as docente,
  max(case when ruolo='editor-salina' then esito end) as editor_sal,
  max(case when ruolo='editor-icp' then esito end) as editor_icp,
  max(case when ruolo='admin' then esito end) as admin
from _matrice where op='S' group by tabella order by tabella;
\echo '=== SCRITTURE (OK = riuscita · 0 = nessuna riga toccata · NEG = negata) ==='
select tabella, op,
  max(case when ruolo='anon' then esito end) as anon,
  max(case when ruolo='docente' then esito end) as docente,
  max(case when ruolo='editor-salina' then esito end) as editor_sal,
  max(case when ruolo='editor-icp' then esito end) as editor_icp,
  max(case when ruolo='admin' then esito end) as admin
from _matrice where op<>'S' group by tabella, op order by tabella;
\echo '=== SCOSTAMENTI DALL ATTESO ==='
select ruolo, tabella, op, esito, atteso from _matrice where atteso is not null and esito <> atteso and not (atteso='NEG' and esito in ('NEG','0')) order by 1,2;
