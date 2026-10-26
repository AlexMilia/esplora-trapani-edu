-- ============================================================
-- ESPLORA TRAPANI EDU — Migrazione 28 · 17/09/2026
-- MASCOTTE PER CORSO, completa (nome, immagine, fasce, video dei momenti).
-- Travasa nel jsonb edu_corsi.mascotte la configurazione del vecchio
-- "progetto" (edu_progetti + edu_mascotte) per i corsi che ne hanno una,
-- così i corsi esistenti conservano Coccio con tutti i suoi video.
-- Da qui in poi la mascotte si gestisce nell'editor del corso; il
-- pannello «Mascotte & progetti» resta solo come sorgente da importare.
-- Idempotente (non sovrascrive mascotte già complete). Dopo la 26.
-- Struttura: {nome, img, junior, senior, quiz_sempre,
--             video:{entrambi:{chiave:src}, junior:{...}, senior:{...}}}
-- chiavi: inizio_corso, fine_lezione, fine_corso, giusta, sbagliata
-- ============================================================
do $$
begin
  if not exists (select 1 from information_schema.tables where table_name = 'edu_progetti')
     or not exists (select 1 from information_schema.tables where table_name = 'edu_mascotte') then
    raise notice 'edu_progetti/edu_mascotte assenti: nessun travaso (i corsi partono senza mascotte)';
    return;
  end if;

  update edu_corsi co
     set mascotte = jsonb_build_object(
       'nome',        coalesce(p.mascotte_nome, ''),
       'img',         coalesce(p.mascotte_img, ''),
       'junior',      coalesce(p.mascotte_junior, true),
       'senior',      coalesce(p.mascotte_senior, true),
       'quiz_sempre', coalesce(p.quiz_sempre, true),
       'video', jsonb_build_object(
         'entrambi', coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'entrambi' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb),
         'junior',   coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'junior' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb),
         'senior',   coalesce((select jsonb_object_agg(m.chiave, m.video) from edu_mascotte m
                               where m.progetto = p.progetto and m.livello = 'senior' and m.attivo is distinct from false and nullif(m.video,'') is not null), '{}'::jsonb)))
    from edu_clienti c
    join edu_progetti p on p.progetto = c.progetto_legacy
   where c.id = co.proprietario_id
     and (co.mascotte is null or co.mascotte->'video' is null);   -- solo dove manca
end $$;

comment on column edu_corsi.mascotte is
  'Mascotte del corso: {nome,img,junior,senior,quiz_sempre,video:{entrambi|junior|senior:{inizio_corso,fine_lezione,fine_corso,giusta,sbagliata}}}. Gestita nell''editor del corso.';
