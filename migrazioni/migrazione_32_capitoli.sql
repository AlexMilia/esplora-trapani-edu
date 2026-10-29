-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 32 · 29/10/2026
-- Titolo dei CAPITOLI (player v2.4, telecomando per chi presenta).
--   edu_media.titolo  titolo breve della clip, mostrato nell'indice
--                     «☰ Capitoli» del player e nella voce della mascotte
--                     quando si cambia capitolo. Vuoto = «Capitolo n».
-- Esposto in edu_assembla_lezione dentro video[].tit (+ durata_s già c'era).
-- Seed: titoli delle clip di vendemmia, corallo, tappeti e salinaio,
-- ricavati dalle note di produzione già presenti in edu_media.note.
-- Idempotente. Dopo 19-31. Poi: cancellare dati/cache_*.json sul server.
-- ============================================================

alter table edu_media
  add column if not exists titolo text;

comment on column edu_media.titolo is
  'Titolo del capitolo (clip) mostrato nell''indice del player. Vuoto = "Capitolo n".';

-- ---- RPC: espone il titolo del capitolo nella playlist della lezione ----
CREATE OR REPLACE FUNCTION public.edu_assembla_lezione(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (
    select id, ordine, tipo, guid, url, durata_s, video_lis, titolo,
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
                'tit', nullif(trim(m.titolo), ''),
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

-- ---- seed dei titoli (solo dove il titolo è ancora vuoto) ----
-- helper temporaneo: titolo per (slug lezione, ordine clip)
create temp table if not exists _cap(slug text, ordine int, titolo text) on commit drop;
insert into _cap values
  ('vendemmia-alagna', 0, 'In vigna: la vendemmia a mano'),
  ('vendemmia-alagna', 1, 'Quanto è dolce l''uva? Il mostimetro'),
  ('vendemmia-alagna', 2, 'L''uva entra in cantina'),
  ('vendemmia-alagna', 3, 'Una cantina nata nel 1946 (parte 1)'),
  ('vendemmia-alagna', 4, 'Una cantina nata nel 1946 (parte 2)'),
  ('vendemmia-alagna', 5, 'Botti sempre piene (parte 1)'),
  ('vendemmia-alagna', 6, 'Il segreto della paraffina (parte 2)'),
  ('vendemmia-alagna', 7, 'Il vino di Sicilia, da Giulio Cesare a oggi (parte 1)'),
  ('vendemmia-alagna', 8, 'Ottanta ettari di vitigni autoctoni (parte 2)'),
  ('corallo-maestro', 0, 'Il corallo che entra nel cuore'),
  ('corallo-maestro', 1, 'Corallo nero, forma e fantasia'),
  ('corallo-maestro', 2, 'Gli attrezzi del corallaro'),
  ('corallo-maestro', 3, 'I segreti del presepe di corallo'),
  ('corallo-maestro', 4, 'L''amuleto del mare'),
  ('tappeti-franca-vario', 0, 'Una storia d''amore lunga 46 anni'),
  ('tappeti-franca-vario', 1, 'Le parti del telaio'),
  ('tappeti-franca-vario', 2, 'L''ordito, l''anima del tappeto'),
  ('tappeti-franca-vario', 3, 'Dalle lenzuola al tappeto'),
  ('tappeti-franca-vario', 4, 'Si tesse! Pedale, pettine e numeri'),
  ('tappeti-franca-vario', 5, 'Il telaio si accorda come una chitarra'),
  ('tappeti-franca-vario', 6, 'Ogni tappeto è unico'),
  ('salinaio', 0, 'Mattia racconta il suo mestiere (parte 1)'),
  ('salinaio', 1, 'Mattia racconta il suo mestiere (parte 2)'),
  ('salinaio', 2, 'Passeggiata tra i munzeddi');

update edu_media m
   set titolo = c.titolo
  from _cap c, edu_lezioni l
 where l.id = m.lezione_id and l.slug = c.slug and l.owner is null
   and m.ordine = c.ordine
   and nullif(trim(coalesce(m.titolo, '')), '') is null;

-- verifica rapida
-- select l.slug, m.ordine, m.titolo from edu_media m join edu_lezioni l on l.id=m.lezione_id
--  where l.slug in ('vendemmia-alagna','corallo-maestro','tappeti-franca-vario','salinaio') order by 1,2;
