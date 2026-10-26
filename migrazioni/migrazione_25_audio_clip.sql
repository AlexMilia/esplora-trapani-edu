-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 25 · 12/09/2026
-- "Il viaggio di una goccia": audio di sottofondo per clip,
-- gestito dalla regia e NON incollato nel video.
--   edu_media.audio_url   URL https diretto (Bunny Storage / B2)
--   edu_media.audio_vol   volume 0-100 (default 45: sottofondo)
--   edu_media.audio_loop  ripete finché la clip va avanti
--   edu_media.audio_duck  abbassa l'audio quando parla la mascotte,
--                         si apre una scoperta o legge la voce (ipovedenti)
-- Esposti in edu_assembla_lezione dentro video[].audio.
-- Idempotente. Dopo 19-24. Poi: cancellare dati/cache_*.json.
-- ============================================================

alter table edu_media
  add column if not exists audio_url  text,
  add column if not exists audio_vol  smallint default 45,
  add column if not exists audio_loop boolean default true,
  add column if not exists audio_duck boolean default true;

comment on column edu_media.audio_url is
  'Audio di sottofondo della clip (URL https diretto a .mp3/.m4a/.ogg). Vuoto = nessun sottofondo. Parte e si ferma con il video.';

-- il corso creato dalla migrazione 20 prende il nome definitivo
update edu_corsi
   set titolo = 'Il viaggio di una goccia',
       sottotitolo = 'Dal mare al sale: il viaggio di una goccia fino alla cristallizzazione'
 where slug = 'la-vita-della-goccia' and titolo = 'La vita della goccia';

CREATE OR REPLACE FUNCTION public.edu_assembla_lezione(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (
    select id, ordine, tipo, guid, url, durata_s, video_lis,
           audio_url, audio_vol, audio_loop, audio_duck,
           row_number() over (order by ordine, id) - 1 as v
    from edu_media where lezione_id = p_id
  )
  select jsonb_build_object(
    'id', l.slug,
    'uuid', l.id,
    'em', l.emoji,
    'cls', l.colore,
    'tit', l.titolo,
    'sub', l.sottotitolo,
    'durata', l.durata_label,
    'intro', l.intro,
    'prologo', nullif(trim(l.prologo), ''),
    'stato', l.stato,
    'coccio', l.video_coccio,
    'acc', coalesce(l.accessibilita, '{}'::jsonb)
           || jsonb_build_object('lis_clip', (select count(*) from m where nullif(trim(m.video_lis),'') is not null),
                                 'n_clip',   (select count(*) from m)),
    'video', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'tipo', m.tipo, 'guid', m.guid, 'url', m.url, 'durata_s', m.durata_s,
                'lis', nullif(trim(m.video_lis),''),
                'audio', case when nullif(trim(m.audio_url),'') is null then null
                         else jsonb_build_object(
                              'url',  trim(m.audio_url),
                              'vol',  coalesce(m.audio_vol, 45),
                              'loop', coalesce(m.audio_loop, true),
                              'duck', coalesce(m.audio_duck, true)) end))
                order by m.v) from m), '[]'::jsonb),
    'tappe', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'v', m.v, 't', tp.t, 'cocciu', tp.cocciu, 'cocciu2', tp.cocciu2,
                'hotspots', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'yaw', h.yaw, 'pitch', h.pitch, 'em', h.em, 'tit', h.tit,
                    'txt', h.txt, 'txt2', h.txt2, 'foto', h.foto_url, 'audio', h.audio_url))
                    order by h.ordine, h.id), '[]'::jsonb)
                  from edu_hotspot h where h.tappa_id = tp.id)))
                order by tp.ordine, tp.t)
              from edu_tappe tp join m on m.id = tp.media_id
              where tp.lezione_id = p_id), '[]'::jsonb),
    'quiz',  coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'junior'), '[]'::jsonb),
    'quiz2', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'q', q.domanda, 'opts', q.opzioni, 'ok', q.ok,
                'spiegazione',       nullif(trim(q.spiegazione), ''),
                'media_spiegazione', nullif(trim(q.media_spiegazione), ''),
                'v', q.v)) order by q.ordine)
              from edu_quiz q where q.lezione_id = p_id and q.livello = 'senior')
  )
  from edu_lezioni l where l.id = p_id;
$function$;
