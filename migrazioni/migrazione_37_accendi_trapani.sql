-- ============================================================
-- MIGRAZIONE 37 · accende l'area Trapani per le scuole
-- Esplora Edu · novembre 2026
--
-- La 36 crea il corso visibile solo alla scuola di prova «prova-trapani».
-- Questa lo accende per il tenant vetrina e per l'IC Pagoto.
-- DA LANCIARE SOLO quando il player v2.9 (con la cartella lib/) è nella cartella
-- che le scuole aprono davvero: il player vecchio mostrerebbe i video senza
-- tagli e con la voce fuori tempo.
-- Ripetibile. Tocca solo le righe che la 36 ha lasciato sospese: una licenza
-- sospesa a mano per altri motivi (nota diversa) non viene riaccesa.
-- ============================================================
update edu_catalogo k set stato = 'attivo', note = replace(k.note, ': si accende con la migr. 37', ' · accesa con la migr. 37')
where k.corso_id = (select co.id from edu_corsi co join edu_clienti v on v.id = co.proprietario_id
                    where co.slug = 'trapani-citta' and v.slug = 'esplora-trapani')
  and k.stato = 'sospeso' and k.note like '%si accende con la migr. 37';
