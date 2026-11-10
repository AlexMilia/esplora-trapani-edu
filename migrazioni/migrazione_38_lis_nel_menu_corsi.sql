-- ============================================================
-- MIGRAZIONE 38 · il menu dei corsi sa quali lezioni hanno l'interprete LIS
-- Esplora Edu · novembre 2026
--
-- Il difetto: scegliendo «Sordi · interprete LIS» nel menu, «Il mestiere del
-- salinaio» appariva spenta, come se il video LIS non ci fosse — e invece c'è.
-- Il player decide guardando acc.lis_clip (quante clip hanno il video LIS).
-- Quel conto lo faceva solo la lezione aperta (edu_assembla_lezione); l'elenco
-- dei corsi (edu_get_corsi) passava l'accessibilità così com'è scritta, senza
-- contare. Finché una cartella di prova veniva scambiata per una scuola il menu
-- arrivava da un'altra strada e il difetto non si vedeva; dal player v2.8 il
-- menu arriva dall'elenco dei corsi, e il difetto è uscito.
--
-- La correzione: l'elenco dei corsi conta le clip con LIS, come fa la lezione.
-- Innesto nella funzione viva (stessa tecnica della 35): ripetibile, e se il
-- punto d'innesto non c'è si ferma senza cambiare nulla.
-- ============================================================
do $i$
declare d text; n int;
  cerca text := '''acc'', coalesce(l.accessibilita, ''{}''::jsonb),';
  metti text := '''acc'', coalesce(l.accessibilita, ''{}''::jsonb) || jsonb_build_object(
                           ''lis_clip'', (select count(*) from edu_media m where m.lezione_id = l.id and nullif(trim(m.video_lis),'''') is not null),
                           ''n_clip'',   (select count(*) from edu_media m where m.lezione_id = l.id)),';
begin
  d := pg_get_functiondef('edu_get_corsi(text)'::regprocedure);
  if position('''lis_clip''' in d) > 0 then raise notice 'migr. 38: già presente'; return; end if;
  n := (length(d) - length(replace(d, cerca, ''))) / length(cerca);
  if n <> 1 then raise exception 'migr. 38: punto d''innesto trovato % volte (ne serve 1; la migrazione 35 è stata applicata?). Nulla è stato cambiato.', n; end if;
  execute replace(d, cerca, metti);
  if position('''lis_clip''' in pg_get_functiondef('edu_get_corsi(text)'::regprocedure)) = 0 then raise exception 'migr. 38: innesto non riuscito'; end if;
end $i$;
