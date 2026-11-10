-- ============================================================
-- MIGRAZIONE 35 · clip con taglio, voce a parte e sottotitoli propri · luogo della lezione
-- Esplora Edu · novembre 2026
--
-- A che cosa serve
--   I racconti a 360° di U Cuntastorie a Trapani hanno tre cose che le lezioni di
--   prima non avevano:
--     1. il video su Bunny dura più del racconto → servono un INIZIO e una FINE;
--     2. la voce pulita sta in un file a parte, da tenere agganciata al video,
--        mentre l'audio del video (la strada, la gente) resta basso;
--     3. i sottotitoli stanno in un file .vtt nostro, con i tempi della voce.
--   In più ogni lezione ha un LUOGO sulla mappa (edu_lezioni.didattica->'luogo').
--
-- Che cosa cambia
--   · edu_media: cinque colonne nuove, tutte facoltative (null = come prima)
--   · edu_assembla_lezione: ogni clip porta da / a / t0 / volv / cc / tit
--   · edu_get_corsi: ogni lezione dell'elenco porta 'luogo'
--   · edu_duplica_corso: copia anche le colonne nuove e il titolo della clip
--
-- Come lo fa
--   Le tre funzioni NON vengono riscritte da zero: la migrazione legge la
--   definizione che c'è in archivio e vi innesta le righe nuove. Così non può
--   riportare indietro una funzione che in produzione è più avanti del file.
--   Se un punto d'innesto non si trova, si ferma con un errore chiaro e non
--   cambia nulla. Ripetibile: se l'innesto c'è già, salta.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Colonne nuove su edu_media
-- ------------------------------------------------------------
alter table edu_media add column if not exists titolo    text;      -- nome del racconto (in produzione c'è già: qui solo per le copie rimaste indietro)
alter table edu_media add column if not exists inizio_s  numeric;   -- secondo del video da cui parte la clip
alter table edu_media add column if not exists fine_s    numeric;   -- secondo del video a cui la clip si ferma
alter table edu_media add column if not exists sync_s    numeric;   -- secondo del video che vale «zero» per voce e sottotitoli (null = inizio_s)
alter table edu_media add column if not exists vol_video smallint;  -- volume dell'audio del video, 0-100 (null = pieno)
alter table edu_media add column if not exists cc_url    text;      -- file .vtt dei sottotitoli, se non stanno su Bunny

comment on column edu_media.inizio_s  is 'Taglio in testa: secondo del video da cui parte la clip (null/0 = dall''inizio)';
comment on column edu_media.fine_s    is 'Taglio in coda: secondo del video a cui la clip finisce (null = fine del video)';
comment on column edu_media.sync_s    is 'Secondo del video che corrisponde allo zero della voce (audio_url non in loop) e dei sottotitoli (cc_url); null = inizio_s';
comment on column edu_media.vol_video is 'Volume dell''audio del video 0-100; null = pieno. Serve quando il racconto sta in audio_url';
comment on column edu_media.cc_url    is 'Sottotitoli in un file .vtt https; i tempi sono quelli della voce (vedi sync_s)';

do $v$
begin
  if not exists (select 1 from pg_constraint where conname = 'edu_media_tagli_ck') then
    alter table edu_media add constraint edu_media_tagli_ck check (
          (inizio_s  is null or inizio_s >= 0)
      and (fine_s    is null or fine_s   >  0)
      and (inizio_s  is null or fine_s is null or fine_s > inizio_s)
      and (sync_s    is null or sync_s  >= 0)
      and (vol_video is null or vol_video between 0 and 100)
      and (cc_url    is null or cc_url ~* '^https://[^[:space:]"''<>]+\.vtt(\?[^[:space:]"''<>]*)?$')
    );
  end if;
end $v$;

-- ------------------------------------------------------------
-- 2. Innesti nelle funzioni esistenti
-- ------------------------------------------------------------
create or replace function pg_temp.edu_innesta(p_fn regprocedure, p_marca text, p_cerca text, p_metti text)
returns text language plpgsql as $f$
declare d text; n int;
begin
  d := pg_get_functiondef(p_fn);
  if position(p_marca in d) > 0 then return 'già presente'; end if;
  n := (length(d) - length(replace(d, p_cerca, ''))) / length(p_cerca);
  if n <> 1 then
    raise exception 'migr. 35: in % il punto d''innesto «%» compare % volte (ne serve 1). Nulla è stato cambiato.', p_fn, left(p_cerca, 60), n;
  end if;
  execute replace(d, p_cerca, p_metti);
  return 'innestato';
end $f$;

do $i$
declare r text;
begin
  -- 2a. edu_assembla_lezione: le colonne nuove entrano nel CTE…
  r := pg_temp.edu_innesta('edu_assembla_lezione(uuid)'::regprocedure, 'inizio_s',
         'audio_url, audio_vol, audio_loop, audio_duck,',
         'audio_url, audio_vol, audio_loop, audio_duck, titolo, inizio_s, fine_s, sync_s, vol_video, cc_url,');
  raise notice 'edu_assembla_lezione · colonne: %', r;
  -- …e nella clip che arriva al player
  r := pg_temp.edu_innesta('edu_assembla_lezione(uuid)'::regprocedure, '''volv''',
         '''lis'', nullif(trim(m.video_lis),''''),',
         '''lis'', nullif(trim(m.video_lis),''''),
                ''tit'', nullif(trim(m.titolo),''''),
                ''da'', m.inizio_s, ''a'', m.fine_s, ''t0'', m.sync_s,
                ''volv'', m.vol_video, ''cc'', nullif(trim(m.cc_url),''''),');
  raise notice 'edu_assembla_lezione · clip: %', r;

  -- 2b. edu_get_corsi: il luogo della lezione, per la pagina con la mappa
  r := pg_temp.edu_innesta('edu_get_corsi(text)'::regprocedure, '''luogo''',
         '''acc'', coalesce(l.accessibilita, ''{}''::jsonb))',
         '''acc'', coalesce(l.accessibilita, ''{}''::jsonb),
                  ''luogo'', l.didattica->''luogo'')');
  raise notice 'edu_get_corsi · luogo: %', r;

  -- 2c. edu_duplica_corso: una copia non deve perdere tagli, voce e sottotitoli.
  --     Due innesti su UNA riga ciascuno: in produzione le funzioni hanno i fine-riga
  --     di Windows, e un punto d'innesto su più righe non verrebbe trovato.
  r := pg_temp.edu_innesta('edu_duplica_corso(uuid,uuid,text)'::regprocedure, 'vol_video, cc_url)',
         'audio_url, audio_vol, audio_loop, audio_duck)',
         'audio_url, audio_vol, audio_loop, audio_duck, titolo, inizio_s, fine_s, sync_s, vol_video, cc_url)');
  raise notice 'edu_duplica_corso · colonne: %', r;
  r := pg_temp.edu_innesta('edu_duplica_corso(uuid,uuid,text)'::regprocedure, 'v_m.inizio_s',
         'v_m.audio_url, v_m.audio_vol, v_m.audio_loop, v_m.audio_duck)',
         'v_m.audio_url, v_m.audio_vol, v_m.audio_loop, v_m.audio_duck, v_m.titolo, v_m.inizio_s, v_m.fine_s, v_m.sync_s, v_m.vol_video, v_m.cc_url)');
  raise notice 'edu_duplica_corso · valori: %', r;
end $i$;

-- ------------------------------------------------------------
-- 3. Controllo finale: se qualcosa non è entrato, la migrazione fallisce
-- ------------------------------------------------------------
do $c$
declare d text;
begin
  d := pg_get_functiondef('edu_assembla_lezione(uuid)'::regprocedure);
  if position('''volv''' in d) = 0 or position('m.inizio_s' in d) = 0 then raise exception 'migr. 35: edu_assembla_lezione non porta i tagli della clip'; end if;
  d := pg_get_functiondef('edu_get_corsi(text)'::regprocedure);
  if position('''luogo''' in d) = 0 then raise exception 'migr. 35: edu_get_corsi non porta il luogo'; end if;
  d := pg_get_functiondef('edu_duplica_corso(uuid,uuid,text)'::regprocedure);
  if position('v_m.inizio_s' in d) = 0 then raise exception 'migr. 35: edu_duplica_corso non copia i tagli'; end if;
  -- la chiusura della migrazione 34 deve reggere: anon non esegue la funzione riservata
  if has_function_privilege('anon', 'edu_assembla_lezione(uuid)', 'execute') then
    raise exception 'migr. 35: anon esegue edu_assembla_lezione (la chiusura della migr. 34 non regge più)';
  end if;
end $c$;
