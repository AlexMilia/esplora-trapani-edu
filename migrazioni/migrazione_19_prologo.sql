-- ============================================================
-- SALE IN CLASSE — Migrazione 19 · 26/08/2026
-- "Intro del corso": prologo a schermo intero all'avvio lezione.
-- Aggiunge edu_lezioni.prologo e lo espone in edu_assembla_lezione.
-- INCLUDE anche i campi della migrazione 18 (quiz: spiegazione,
-- media_spiegazione, v): eseguirla da sola basta, l'ordine 18→19
-- resta comunque sicuro. Idempotente.
-- DOPO: cancellare dati/cache_*.json sul server (o attendere 5').
-- ============================================================

alter table edu_lezioni
  add column if not exists prologo text;

comment on column edu_lezioni.prologo is
  'Intro del corso: testo a schermo intero mostrato all''avvio della lezione, prima di Coccio. Righe preservate. Vuoto = nessun prologo.';

CREATE OR REPLACE FUNCTION public.edu_assembla_lezione(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (
    select id, ordine, tipo, guid, url, durata_s, video_lis,
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
                'lis', nullif(trim(m.video_lis),'')))
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
