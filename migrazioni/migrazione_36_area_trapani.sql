-- ============================================================
-- MIGRAZIONE 36 · area «Trapani, la città a forma di falce»
-- Esplora Edu · novembre 2026
--
-- FILE GENERATO da strumenti/genera_area_trapani.py: non modificarlo a mano.
--
-- Che cosa crea
--   · un corso a catalogo del tenant vetrina «esplora-trapani», pubblicato,
--     terzo dopo Antichi Mestieri (10) e Il viaggio di una goccia (20)
--   · 11 lezioni, una per luogo, con 13 racconti a 360° di U Cuntastorie
--   · per ogni racconto: taglio del video, voce a parte, sottotitoli, fermate
--     con il punto «?» già validato, domande junior e senior
--   · didattica.mappa = true sul corso e didattica.luogo su ogni lezione:
--     il player apre il corso con la mappa
--
-- Richiede la migrazione 35 (tagli della clip). Va applicata DOPO aver messo
-- online il player v2.9: quello vecchio ignorerebbe tagli e voce.
--
-- Ripetibile e prudente: se il corso c'è già NON tocca nulla, nemmeno una
-- virgola. Quello che viene corretto dalla regia dopo l'importazione resta.
-- ============================================================
do $trapani$
declare
  v_cli uuid; v_corso uuid; v_lez uuid; v_med uuid; v_tap uuid;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'edu_media' and column_name = 'inizio_s') then
    raise exception 'migr. 36: manca la migrazione 35 (tagli della clip). Applicala prima.';
  end if;
  select id into v_cli from edu_clienti where slug = 'esplora-trapani';
  if v_cli is null then raise exception 'migr. 36: non trovo il cliente «esplora-trapani»'; end if;
  if exists (select 1 from edu_corsi where proprietario_id = v_cli and slug = 'trapani-citta') then
    raise notice 'migr. 36: il corso «trapani-citta» esiste già: non tocco nulla.';
    return;
  end if;

  insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, descrizione, emoji, colore, fascia, prologo,
                         stato, ordine, visibilita, mascotte, didattica)
  values (v_cli, 'trapani-citta', 'Trapani, la città a forma di falce',
          'Chiese, palazzi, miti e leggende del centro storico: undici luoghi sulla mappa, raccontati a 360° da U Cuntastorie',
          'Un giro nel centro storico di Trapani in undici luoghi. In ogni luogo un racconto a 360°: ci si guarda intorno, si cerca il punto che brilla e si risponde alle domande.',
          '⚓', 'blu', 'entrambe', 'Ciao! Io sono Trapani, la città a forma di falce. Sono piena di storie: basta alzare gli occhi. Te le racconta U Cuntastorie, che queste chiese e questi palazzi li conosce pietra per pietra. Scegli un punto sulla mappa e partiamo!',
          'pubblicato', 25, 'catalogo',
          '{"img":"https://www.alessandromilia.it/project/esplora/mascotte.png","nome":"Trapani","video":{"junior":{},"senior":{},"entrambi":{}},"junior":true,"senior":true,"quiz_sempre":true}'::jsonb,
          '{"mappa":true}'::jsonb)
  returning id into v_corso;
  insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
  values (v_corso, v_cli, 'attivo', current_date, 'Corso proprio (migr. 36)')
  on conflict (corso_id, cliente_id) do nothing;


  -- ---------- 1. Tutto al femminile · Chiesa dei Cappuccini ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-cappuccini', 'Tutto al femminile', 'La finta Santa Lucia e le due braccia incrociate dei francescani', '🕯️', 'rosa', '~3 min',
          'Questa chiesa la chiamate tutti Santa Lucia. Sbagliato! Prima di dirti perché, ascolta da dove comincia il viaggio: in questa terra, da sempre, il sacro è donna.', 10, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa dei Cappuccini", "lat": 38.01676, "lng": 12.50095}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '44dc8d52-9ff1-4ab5-a72a-a1841f8a63fe', 'Tutto al femminile', 0.34, 207.34, 0.34, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n02.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n02.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 61.6, 'Tutti la chiamano Santa Lucia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -118, 12, '🕯️', 'La finta Santa Lucia',
          'Questa è la chiesa dell’Epifania dei Cappuccini. Ma per tanti anni qui c’era una strada dedicata a Santa Lucia, e il 13 dicembre la gente veniva a passare un fazzoletto di cotone sulla statua della santa per poi strofinarsi gli occhi.',
          'La chiesa è quella dell’Epifania dei Cappuccini, ma per decenni la strada era dedicata a Santa Lucia e il 13 dicembre i trapanesi venivano qui a passare un fazzoletto di bambagia sulla statua della santa, protettrice della vista, per poi strofinarsi gli occhi. Così il nome popolare è rimasto alla chiesa sbagliata.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 108.5, 'Guarda il portale: c’è un simbolo. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -150, 0, '🤝', 'Due braccia incrociate',
          'Sul portale ci sono due braccia incrociate: una nuda e una vestita. È il simbolo dei francescani. La leggenda dice che San Francesco si tolse una manica del saio per regalarla a un povero.',
          'Lo stemma francescano mostra due braccia incrociate, una nuda (Cristo) e una vestita (San Francesco), sopra il Calvario con la croce. Qui c’era il convento dei Cappuccini, costruito fuori dalle mura, dove fino al Trecento c’erano solo scogli e sabbia; oggi il convento accoglie l’università. Nella veduta della città del Settecento, al Museo Pepoli, si vede dietro il convento un grande orto e perfino una vasca per allevare pesci per i poveri.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che simbolo c’è sul portale?', '["Due braccia incrociate", "Una nave", "Un leone"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa passavano i trapanesi sulla statua di Santa Lucia, il 13 dicembre?', '["Un ramo di corallo", "Un fazzoletto di cotone", "Una candela accesa"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa rappresentano le due braccia incrociate, una nuda e una vestita?', '["Lo stemma del comune", "Lo stemma dei francescani", "Il simbolo dei pescatori"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come si chiama davvero la chiesa che tutti chiamano «Santa Lucia»?', '["Chiesa del Carmine", "Chiesa di Sant’Agostino", "Chiesa dell’Epifania dei Cappuccini"]'::jsonb, 2, 2);

  -- ---------- 2. La santa dei corallari · Ex chiesa di Santa Lucia ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-santa-lucia', 'La santa dei corallari', 'I pescatori di corallo e l’affresco ritrovato', '🪸', 'oro', '~4 min',
          'Ecco la vera chiesa di Santa Lucia. Qui la santa non proteggeva solo la vista: proteggeva i pescatori di corallo. E il corallo ha cambiato la mia storia.', 20, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Ex chiesa di Santa Lucia", "lat": 38.01702, "lng": 12.50254}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '38e125ee-db98-4c24-adf3-9f460d2d872b', 'La santa dei corallari', 2.12, 240.12, 2.12, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n03.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n03.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 39.6, 'Ecco chi pregava qui. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -5, 22, '🪸', 'I pescatori di corallo',
          'Santa Lucia era la protettrice dei pescatori di corallo. Avevano barche lunghe, strette e nere, e sulla prua mettevano sempre un bel ramo di corallo.',
          'A Trapani Santa Lucia era la protettrice dei corallari. Le loro barche, lunghe, strette e nere, avevano sulla prua un ramo di corallo. I corallari avevano almeno due approdi in città.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 95.4, 'Una scoperta fatta durante un restauro. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -25, 33, '🖼️', 'L’affresco ritrovato',
          'Durante un restauro nel Santuario della Madonna, sotto l’intonaco è comparso un affresco: i pescatori trapanesi trovano una montagna di corallo a Tabarca, in Tunisia. Con quella ricchezza la prima cosa che fanno è costruire una cappella per la Madonna.',
          'Nella cappella dei pescatori del Santuario dell’Annunziata, a metà della navata destra, sotto strati d’intonaco è emerso un affresco che racconta una pesca miracolosa di corallo a Tabarca, in Tunisia, tra il 1535 e il 1537. Con la nuova ricchezza i corallari costruirono la cappella dedicata alla Madonna di Trapani, all’inizio con un ingresso esterno.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi proteggeva Santa Lucia a Trapani?', '["I contadini", "I pescatori di corallo", "I soldati"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Com’erano le barche dei pescatori di corallo?', '["Rotonde e bianche", "Grandi come navi", "Lunghe, strette e nere"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Dove trovarono la “montagna di corallo” i pescatori trapanesi?', '["A Malta", "A Favignana", "A Tabarca, in Tunisia"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa costruirono i corallari con la ricchezza del corallo di Tabarca?', '["Una cappella per la Madonna di Trapani", "Un palazzo per sé", "Un nuovo porto"]'::jsonb, 0, 2);

  -- ---------- 3. La montagna è femmina · Mura di Tramontana ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-tramontana', 'La montagna è femmina', 'Erice, la montagna di Venere, e i riti delle donne per Demetra', '⛰️', 'blu', '~4 min',
          'Siamo sulle Mura di Tramontana. Da questa piccola insenatura partivano i corallari. E da qui guardi lei: la montagna sacra, la montagna femmina.', 30, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Mura di Tramontana", "lat": 38.01757, "lng": 12.50415}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'c34f5cb9-ee8a-4d28-a81d-51334bffb95b', 'La montagna è femmina', 174.67, 408.67, 174.67, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n04.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n04.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 231.3, 'Guarda verso la montagna. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -145, 4, '⛰️', 'La montagna di Venere',
          'Da qui si vede Erice, la montagna dedicata a Venere. Già gli Elimi, prima dei Greci e dei Romani, avevano un culto femminile della fertilità.',
          'Da questa piccola insenatura, forse la marina dei corallari, si vede il monte Erice, la montagna sacra a Venere. La città elima aveva un culto femminile ancora più antico: in tutta la Sicilia occidentale, da Erice a Segesta, a Monte Castellazzo di Poggioreale e a Entella, il riferimento della fertilità era sempre femminile.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 313.9, 'Un rito antichissimo, tutto di donne. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 166, -14, '🌾', 'Tre giorni senza mariti',
          'Nei riti per Demetra, la dea del grano, per tre giorni le donne lasciavano casa e mariti e si riunivano in un grande recinto circolare per offrire statuine di terracotta e chiedere la fertilità della terra.',
          'Nelle feste di Demetra (le Tesmoforie) le donne per almeno tre giorni lasciavano casa e mariti, uscivano dalla città e si riunivano in un grande recinto sacro, il tesmoforion, per offrire statuine di terracotta della dea del grano e dell’abbondanza, insieme a piccole offerte: un rito per la fertilità delle donne e della terra.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Quale montagna si vede dalle Mura di Tramontana?', '["L’Etna", "Monte Cofano", "Erice"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Di che cosa era la dea Demetra?', '["Del grano", "Del mare", "Della guerra"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'A quale dea era dedicata la montagna di Erice?', '["Venere", "Atena", "Giunone"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come si chiamavano le feste di Demetra riservate alle donne?', '["Olimpiadi", "Tesmoforie", "Saturnali"]'::jsonb, 1, 2);

  -- ---------- 4. La falce di Demetra · Mura di Tramontana, verso la città ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-falce', 'La falce di Demetra', 'Il mito che spiega la forma di Trapani e le stagioni', '🌙', 'verde', '~3 min',
          'Vuoi sapere perché ho questa forma? Me l’ha raccontato una maestra delle elementari, la prima cuntastorie di U Cuntastorie.', 40, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Mura di Tramontana, verso la città", "lat": 38.01693, "lng": 12.50698}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '0c783b9a-eada-436a-8cc7-ddf6253b16fe', 'La falce di demetra', 2.06, 184.06, 2.06, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n05.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n05.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 98.2, 'Ecco il mito della mia nascita. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -150, 0, '🌙', 'Perché Trapani è una falce',
          'Demetra cercava sua figlia Kore, rapita da Ade, volando su un carro tirato da serpenti alati. Nella mano aveva una falce: le cadde, finì nel mare… e diventò Trapani. Per questo la città ha la forma di una falce!',
          'Il mito: Kore, figlia di Demetra, coglie narcisi sul lago di Pergusa quando Ade la rapisce negli inferi. Demetra la cerca per tutti i cieli di Sicilia su un carro tirato da serpenti alati, con un fascio di spighe e una falce. La falce le cade di mano e dove cade nasce la città: Drepanon, “la falce”, da cui Trapani.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 171.8, 'Lo sai perché d’inverno fa freddo? Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -28, -2, '🍎', 'Sei chicchi di melograno',
          'Ade fece mangiare a Kore sei chicchi di melograno, e così lei doveva restare negli inferi sei mesi all’anno: autunno e inverno. Gli altri sei mesi torna dalla mamma ed è primavera ed estate.',
          'Giove, con Mercurio come mediatore, impone il ritorno di Kore, ma Ade le fa mangiare sei chicchi di melograno: per la legge antica degli inferi non potrà più lasciarli del tutto. L’accordo: sei mesi negli inferi (autunno e inverno), sei mesi con la madre, «a staciuni», primavera ed estate. Lo stesso mito si racconta a Segesta, dove il melograno è rinato dopo l’incendio.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa cadde dalla mano di Demetra e diventò Trapani?', '["Una falce", "Una spiga", "Una corona"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi rapì Kore, la figlia di Demetra?', '["Giove", "Ade", "Mercurio"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché Kore resta sei mesi negli inferi?', '["Ha perso la strada", "Ha mangiato sei chicchi di melograno", "Ha litigato con la madre"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa significa Drepanon, l’antico nome di Trapani?', '["Il porto", "La torre", "La falce"]'::jsonb, 2, 2);

  -- ---------- 5. L’uomo col leone · Palazzo Ferro ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-leone', 'L’uomo col leone', 'La leggenda di Alessandro Ferro, scolpita sopra le nostre teste', '🦁', 'rosa', '~2 min',
          'Quante volte sei passato qui davanti? E quante volte hai alzato gli occhi? Mai. C’è un uomo con un leone… e un cappello.', 50, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Palazzo Ferro", "lat": 38.01625, "lng": 12.508}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '237224a4-e402-49f2-bcb8-789305d4ef71', 'L’uomo col leone', 16.12, 144.12, 16.12, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n06.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n06.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 74.9, 'Ecco come comincia la storia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -38, 52, '🎩', 'Lo scherzo in Francia',
          'Alessandro Ferro era un nobile che a Trapani si sentiva stretto. Andò in Francia per farsi ammirare, ma lì lo presero in giro come un villano di campagna e gli fecero uno scherzo pericoloso.',
          'Alessandro Ferro, nobile forse di rango principesco, si sentiva poco considerato a Trapani e partì per la Francia per dimostrare la sua nobiltà. Lì lo trattarono come un provinciale e gli giocarono uno scherzo: lo portarono in un giardino con animali esotici e una gabbia con un leone.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 128, 'Che cosa fa Alessandro davanti al leone? Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -25, 50, '🦁', 'Il cappello sul leone',
          'Aprirono la gabbia e il leone arrivò dietro di lui. Alessandro, terrorizzato, si tolse il cappello e lo mise sulla testa del leone… e il leone si accucciò! Tornato a Trapani, si fece scolpire con il leone e il cappello.',
          'Gli altri scappano e aprono la gabbia: il leone gli arriva alle spalle, si ferma e lo guarda. Lui, terrorizzato, gli mette il cappello in testa e il leone si accuccia senza sbranarlo. Tornato nel suo palazzo, Ferro si fa scolpire con il leone e il cappello: è l’unica storia al maschile del percorso.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa mise Alessandro Ferro sulla testa del leone?', '["Una corona", "Il suo cappello", "Una sciarpa"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa fece il leone con il cappello in testa?', '["Ruggì fortissimo", "Scappò via", "Si accucciò"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché Alessandro Ferro andò in Francia?', '["Per comprare un leone", "Per studiare", "Per dimostrare la sua nobiltà"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come volle farsi scolpire Alessandro Ferro, tornato a Trapani?', '["Con il leone e il cappello", "A cavallo", "Con una spada in mano"]'::jsonb, 0, 2);

  -- ---------- 6. Chiesa del Collegio · Chiesa del Collegio dei Gesuiti ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-collegio', 'Chiesa del Collegio', 'Tre racconti: la chiesa che rinasce · acqua, terra, aria e fuoco · le sante nel muro', '⛪', 'oro', '~14 min',
          'Entriamo. Questa chiesa è rimasta chiusa per quarantadue anni. Chi l’ha riaperta ti racconta come si fa rinascere un luogo, un pezzo alla volta. Tre racconti, uno dopo l’altro: guardati intorno e, quando appare un “?”, toccalo.', 60, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa del Collegio dei Gesuiti", "lat": 38.01569, "lng": 12.50903}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '1aa7e709-4333-4337-b336-71869c9bc0a5', 'La chiesa che rinasce', 3.57, 305.57, 3.57, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n07.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n07.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 76.8, 'Ascolta la parte moderna di questa storia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -169, 5, '🔑', 'Chiusa per 42 anni',
          'Per 42 anni questa chiesa è rimasta chiusa. Davanti al portone c’erano un telone e una bancarella. Il 3 gennaio 2003 è stata riaperta, anche se il restauro non era finito.',
          'La chiesa del Collegio dei Gesuiti, dedicata all’Immacolata, è rimasta chiusa per 42 anni: davanti al portone un grande telo e una bancarella. L’idea di riaprirla, anche se non ultimata, nacque dalla soprintendente di allora, una donna. Il 3 gennaio 2003 la chiesa riaprì, piena di gente e con la banda.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 240.8, 'Un’idea rivoluzionaria per allora. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -50, 16, '🧱', 'Il cantiere aperto',
          'Ognuno poteva aiutare a restaurare un pezzo della chiesa e vedere quando il lavoro iniziava e quando finiva. È il “cantiere aperto”: tanti piccoli cantieri, poi un grande progetto di tre milioni di euro.',
          'Altari smontati, dipinti assenti, pavimento in parte smontato: dopo 42 anni di abbandono e piccoli furti, partì il “cantiere aperto” e “della conoscenza”. Il primo donatore fu il presidente di un club di servizio, che finanziò un altare; poi altri club, anche femminili, fino a un progetto di circa 3 milioni di euro e dieci anni di lavori. Tutti potevano vedere inizio, durata e fine di ogni intervento.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Per quanti anni è rimasta chiusa la chiesa del Collegio?', '["5", "100", "42"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'In che anno è stata riaperta la chiesa del Collegio?', '["2003", "1950", "1636"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cos’è il “cantiere aperto”?', '["Un restauro che tutti possono vedere e sostenere", "Un cantiere senza tetto", "Un mercato"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi ebbe l’idea di riaprire la chiesa anche se il restauro non era finito?', '["Il re", "La soprintendente di allora", "Un pescatore"]'::jsonb, 1, 2);

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 2, 'video360', '7bc50f53-f02b-40ed-a5f8-e00f5a04ea13', 'Acqua, terra, aria e fuoco', 11.58, 370.58, 11.58, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n08.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n08.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 62.6, 'Ecco la donna al centro di tutto. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -94, 17, '⚪', 'L’Immacolata di Marabitti',
          'Al centro c’è l’Immacolata, una scultura di Ignazio Marabitti. Tutto intorno ci sono immagini di donne della Bibbia, anche donne coraggiose come Giuditta.',
          'Chi entrava doveva avere un riferimento: l’Immacolata. La prima immagine era un dipinto del fiammingo Geronimo Gerardi, nella cappella laterale; poi venne la scultura di Ignazio Marabitti. Intorno, un percorso di immagini mariane e di donne della Bibbia, come Giuditta e Oloferne nei bassorilievi, e figure della genealogia di Maria come Aronne.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 345.7, 'Trapani vive di mare. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 144, 8, '🌊', 'L’altare è una nave',
          'Nei marmi dell’altare ci sono i quattro elementi: l’acqua con l’arca di Noè e i pesci, la terra con il grande grappolo d’uva, l’aria con gli uccelli e il pellicano, il fuoco con il carro di Elia. E tutto l’altare ha la forma di una nave!',
          'Nei marmi mischi dell’altare la storia delle donne si unisce ai quattro elementi: l’acqua (l’arca di Noè, pesci, tartarughe, granchi, aragosta, polpo e mostri marini attorno al giglio di Maria), la terra (il grappolo della Terra promessa, cornucopie e fiori), l’aria (la nube del deserto e gli uccelli, tra cui il pellicano, simbolo cristologico) e il fuoco (il carro di Elia). Ma a Trapani l’elemento principale è il mare: l’altare è una grande nave, con riccioli d’onda tagliati dalla chiglia.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che forma ha l’altare della chiesa del Collegio?', '["Un castello", "Un albero", "Una nave"]'::jsonb, 2, 3);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi ha scolpito l’Immacolata della chiesa del Collegio?', '["Ignazio Marabitti", "Michelangelo", "Leonardo da Vinci"]'::jsonb, 0, 4);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quali sono i quattro elementi raffigurati sull’altare?', '["Acqua, terra, aria e fuoco", "Sole, luna, stelle e mare", "Grano, olio, vino e sale"]'::jsonb, 0, 3);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Sull’altare, quale scena rappresenta il fuoco?', '["L’arca di Noè", "Il carro di Elia", "Il grande grappolo d’uva"]'::jsonb, 1, 4);

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 3, 'video360', 'a359c526-d65c-4013-bdb7-5780be0d83f4', 'Le sante nel muro', 2.89, 175.89, 2.89, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n09.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n09.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 53, 'Che cosa c’era dietro le crepe? Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 128, 22, '🔨', 'Un volto dal muro',
          'Dal ponteggio U Cuntastorie vide delle crepe. Fece aprire il muro e uscì fuori il volto di una donna! Dietro c’erano delle nicchie con le sante, murate da secoli.',
          'Durante i consolidamenti del tetto e delle pareti, dal ponteggio comparvero delle lesioni: o crollava qualcosa, o dietro c’era qualcosa. Un muratore aprì il punto centrale e apparve un volto di donna. Aperte le altre nicchie, vennero fuori le sante martiri siciliane delle province dove i Gesuiti erano presenti.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 106, 'Ne mancava una sola. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 150, 14, '🌹', 'Santa Rosalia dorme ancora',
          'Le sante erano Agata, Rosalia, Barbara, Oliva… Una nicchia però non si è aperta: con una piccola telecamera hanno visto che Santa Rosalia è ancora lì dietro, nascosta dai marmi.',
          'Agata, Rosalia, Barbara, Oliva: le sante siciliane rappresentate dai Gesuiti. L’unica nicchia non riaperta nasconde ancora Santa Rosalia: un piccolo foro con una telecamera dal retro ha confermato che i Gesuiti, nel Settecento, la ricoprirono di marmi per rendere la chiesa più bella. «Ancora adesso lì dorme Santa Rosalia».',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa trovarono dietro i muri della chiesa?', '["Un tesoro di monete", "Una porta segreta", "Nicchie con statue di sante"]'::jsonb, 2, 5);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa fece capire che dietro il muro c’era qualcosa?', '["Delle crepe", "Un rumore", "Una scritta"]'::jsonb, 0, 6);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale santa è ancora nascosta dietro i marmi?', '["Santa Rosalia", "Sant’Agata", "Santa Lucia"]'::jsonb, 0, 5);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Come hanno scoperto che Santa Rosalia è ancora dietro i marmi?', '["Togliendo tutti i marmi", "Con una piccola telecamera", "Leggendo un libro antico"]'::jsonb, 1, 6);

  -- ---------- 7. L’asse sacro e profano · Palazzo Senatorio ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-senatorio', 'L’asse sacro e profano', 'La Madonna con le chiavi della città e il trucco degli architetti', '🗝️', 'blu', '~2 min',
          'Alza la testa sul Palazzo Senatorio: c’è la Madonna di Trapani con le chiavi della città, tra i due santi patroni. Qui la città è donna.', 70, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Palazzo Senatorio", "lat": 38.01536, "lng": 12.50961}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '768748cc-2fc4-40d6-a963-2828ce96840a', 'L’asse sacro e profano', 3.58, 128.59, 3.58, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n10.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n10.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 30.9, 'Guarda in alto, sulla facciata. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 3, 36, '🗝️', 'La Madonna con le chiavi',
          'In alto c’è la Madonna di Trapani con le chiavi della città, tra San Giovanni e Sant’Alberto, i patroni. I patroni sono uomini… ma la città è donna.',
          'Sulla facciata del Palazzo Senatorio la Madonna di Trapani tiene le chiavi della città, tra San Giovanni Battista e Sant’Alberto, patroni ufficiali. Qui, nella seconda metà del Trecento, con Giacomo d’Aragona la città si allarga oltre le vecchie porte: si aprono nuove strade e poi la Rua Nova, oggi via Garibaldi.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 122.6, 'Mettiti al centro della strada. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -36, 20, '👁️', 'Il trucco degli architetti',
          'Gli architetti di Giacomo d’Aragona hanno fatto un trucco: questo punto è un po’ più alto e la strada scende piano piano. Così, se ti metti al centro, vedi fino al mare!',
          'Dal centro dell’incrocio si vede la piazza del Mercato del pesce con la Venere e, un tempo, una statua della Madonna “della triangolazione” della Sicilia: un asse sacro e profano, Venere e Madonna. Gli architetti aragonesi rialzarono leggermente questo punto e fecero scendere la strada: un trucco prospettico che permette di vedere il mare.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa tiene in mano la Madonna sul Palazzo Senatorio?', '["Un ramo di corallo", "Una spada", "Le chiavi della città"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Mettendosi al centro della strada, che cosa si vede in fondo?', '["Il mare", "La montagna", "Un castello"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale re aragonese fece allargare la città oltre le mura nel Trecento?', '["Giacomo d’Aragona", "Federico II", "Carlo V"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi sono i due santi accanto alla Madonna sulla facciata?', '["San Pietro e San Paolo", "San Giovanni Battista e Sant’Alberto", "San Francesco e Sant’Antonio"]'::jsonb, 1, 2);

  -- ---------- 8. Il rosone dei tre popoli · Chiesa di Sant’Agostino ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-rosone', 'Il rosone dei tre popoli', 'Caruso e i pomodori, poi tre religioni in un rosone', '💠', 'verde', '~2 min',
          'Prima una storia di musica e pomodori, poi alza la testa sul rosone: l’hai visto mille volte, ma ci hai mai trovato dentro tre popoli?', 80, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa di Sant’Agostino", "lat": 38.01486, "lng": 12.50982}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', '340b3ae0-68ef-4d9a-a402-3695b05724cb', 'Il rosone dei tre popoli', 22.45, 148.28, 12.95, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n11.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n11.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 44.9, 'Una storia di teatro… e di cuore spezzato. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 4, -10, '🍅', 'Caruso e i pomodori',
          'Il grande tenore Enrico Caruso, da giovanissimo, venne a Trapani a cantare. Sbagliò una nota e i trapanesi gli tirarono i pomodori! Aveva bevuto troppo per una delusione d’amore.',
          'Un giovanissimo Enrico Caruso arriva a Trapani per cantare allo “chalet”, il teatro che non esiste più, e stecca: i melomani trapanesi lo coprono di pomodori. Era ubriaco per una delusione amorosa. Insomma, anche qui c’entra una donna. (Aneddoto raccontato dalla guida.)',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 131.6, 'Guarda bene il rosone. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -43, 37, '✡️', 'Stella, gelosie e Agnello',
          'Nel rosone ci sono la stella di Davide, simbolo ebraico, delle parti traforate come le finestre arabe, e al centro l’Agnello di Dio, simbolo cristiano. Tre popoli insieme, in pace.',
          'Nel rosone convivono la stella di Davide, trafori a gelosia di gusto islamico e l’Agnus Dei cristiano al centro. U Cuntastorie lo ha restaurato al tempo della Coppa America: «ci piace pensare che sia un paradiso terrestre, dove tre popoli e tre religioni vivono in pace insieme». Curiosamente l’Agnus Dei è la parte più recente, rifatta dopo la guerra.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Quali simboli ci sono nel rosone di Sant’Agostino?', '["Stella di Davide, trafori arabi e Agnello di Dio", "Tre leoni", "Il sole e la luna"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa tirarono i trapanesi a Caruso?', '["Fiori", "Pomodori", "Monete"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa successe a Enrico Caruso a Trapani?', '["Vinse un premio", "Fu preso a pomodori dopo una stecca", "Cantò in chiesa"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Qual è la parte più recente del rosone, rifatta dopo la guerra?', '["La stella di Davide", "I trafori", "L’Agnello di Dio al centro"]'::jsonb, 2, 2);

  -- ---------- 9. Le stelle e la Venere · Chiesa del Carmine ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-carmine', 'Le stelle e la Venere', 'Gli osservatori delle stelle e la chiesa storta apposta', '🔭', 'rosa', '~3 min',
          'Un’altra storia al femminile, e un po’ di cielo: da qui i trapanesi guardavano le stelle. Poi una chiesa storta, apposta, e la signorina della piazza.', 90, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Chiesa del Carmine", "lat": 38.0169, "lng": 12.50965}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'fbdabb36-30f3-49bd-ab2e-97b53830d539', 'Le stelle e la venere', 27.1, 212.85, 27.1, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n12.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n12.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 66, 'Guarda la torre alta e stretta. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -48, -10, '🔭', 'Gli osservatori delle stelle',
          'Da quella torre, da poco restaurata, i trapanesi guardavano le stelle. Con il Collegio, Palazzo Riccio di San Gioacchino era uno degli osservatori astronomici della città.',
          'La torre alta e stretta di Palazzo Riccio di San Gioacchino, da poco restaurata, e il Collegio erano due osservatori astronomici al servizio della città: si contavano le stelle e, magari, si cercava il futuro.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 137.2, 'Guarda l’arco della facciata. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -85, 24, '⭐', 'La chiesa storta',
          'La facciata della chiesa del Carmine è storta, apposta! Nel Barocco bisognava stupire, e gli architetti hanno adattato tutto a uno spazio strano. Sopra c’è il simbolo del Monte Carmelo con tre stelle.',
          'La chiesa del Carmine ha un prospetto volutamente obliquo: in uno spazio irregolare gli architetti barocchi hanno piegato tutto, perfino l’arco, che non è circolare ma sghembo, con al centro il simbolo mariano. Lo stemma carmelitano è il Monte Carmelo con tre stelle. Qui, in tempo di guerra e di carestia, si portava al sicuro dentro le mura la Madonna di Trapani.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa guardavano i trapanesi dalla torre alta e stretta?', '["Le navi pirata", "Le stelle", "Il mercato"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa c’è nello stemma dei Carmelitani?', '["Un leone", "Una nave", "Un monte con tre stelle"]'::jsonb, 2, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Perché la facciata del Carmine è storta?', '["Per un terremoto", "Per un errore", "Per adattarsi a uno spazio irregolare e stupire, come nel Barocco"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quali erano i due osservatori astronomici della città?', '["Palazzo Riccio di San Gioacchino e il Collegio", "Palazzo Senatorio e la chiesa del Carmine", "Villa Margherita e le Mura di Tramontana"]'::jsonb, 0, 2);

  -- ---------- 10. La santa degli impossibili · Via Garibaldi ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-santa-rita', 'La santa degli impossibili', 'Nonna Gina e la forza delle donne siciliane', '🌹', 'oro', '~2 min',
          'Questa è la storia di due donne: una santa che conosci, e la donna più importante della vita di U Cuntastorie.', 100, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Via Garibaldi", "lat": 38.01755, "lng": 12.5118}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'abb2627b-d7eb-4fec-9344-1e2504e0fd7c', 'La santa degli impossibili', 29.92, 136.3, 29.92, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n13.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n13.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 60.5, 'Una donna vera, di famiglia. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, -22, -10, '👵', 'Nonna Gina',
          'Nonna Gina ha cresciuto U Cuntastorie insieme alla sua mamma. Era devota a Santa Rita, la santa delle cose impossibili.',
          'Nonna Gina ha cresciuto U Cuntastorie insieme alla madre. Era devotissima a Santa Rita, «la santa degli impossibili»: aveva seguito per amore un uomo in Tunisia, lo aveva perso, era tornata e aveva ricostruito tutto, aprendo forse il primo B&B della città, nel 1935.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 124.7, 'Ascolta il messaggio di questa tappa. Tocca il “?”.', 2) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 142, 18, '🌹', 'Niente è impossibile',
          'Rimasta sola con una bambina piccola e la casa distrutta dalla guerra, nonna Gina ha ricominciato da capo. È il simbolo della forza delle donne siciliane: nei momenti difficili ci si rimbocca le maniche e si va avanti.',
          'Con la figlia di cinque anni e ciò che aveva costruito distrutto dalla guerra, Gina ricominciò. Per U Cuntastorie è il simbolo della forza delle donne, in particolare delle donne siciliane: Santa Rita insegna che niente è impossibile, e che dal dolore bisogna rimboccarsi le maniche e reagire ancora meglio.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Perché Santa Rita è chiamata “la santa degli impossibili”?', '["Perché era molto alta", "Perché non parlava mai", "Perché si pregava per le cose che sembrano impossibili"]'::jsonb, 2, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Chi era nonna Gina?', '["La nonna del cuntastorie", "Una regina", "Una santa"]'::jsonb, 0, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Che cosa aprì nonna Gina a Trapani nel 1935?', '["Forse il primo B&B della città", "Un teatro", "Una scuola"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Dove aveva seguito un uomo, per amore, nonna Gina?', '["In Francia", "In Tunisia", "In America"]'::jsonb, 1, 2);

  -- ---------- 11. Margherita, l’ultima donna · Villa Margherita ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', 'trapani-margherita', 'Margherita, l’ultima donna', 'La regina che dà il nome a un giardino… e a una pizza', '👑', 'blu', '~1 min',
          'L’ultima donna del nostro viaggio dà il nome a questo giardino… e a una pizza.', 110, 'pubblicata', null, v_corso,
          '{"lis":false,"note":"","ipovedenti":true}'::jsonb,
          jsonb_build_object('luogo', '{"nome": "Villa Margherita", "lat": 38.0176, "lng": 12.5156}'::jsonb))
  returning id into v_lez;

  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, 1, 'video360', 'f1f02c62-d474-47ba-86b1-2c8f961506d3', 'Margherita l’ultima donna', 46.08, 93.58, 13.08, 22,
          'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/media/trapani/n14.mp3', 100, false, false, 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/sottotitoli/trapani/n14.vtt')
  returning id into v_med;
  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, 66, 'Ecco l’ultima donna del percorso. Tocca il “?”.', 1) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, 79, 6, '👑', 'La regina Margherita',
          'Questo giardino si chiama Villa Margherita, per la regina Margherita. Alla regina è dedicata anche la pizza più famosa del mondo: pomodoro, mozzarella e basilico!',
          'L’ultima donna è Margherita di Savoia, prima regina d’Italia, a cui è intitolata la villa comunale. U Cuntastorie le è grato non per simpatie monarchiche ma… per la pizza Margherita, che secondo la tradizione porta il suo nome.',
          'validato', 'Esplora Trapani', now(), 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'A chi è dedicata Villa Margherita?', '["Alla regina Margherita", "A una pescatrice", "A una santa"]'::jsonb, 0, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'junior', 'Che cosa c’è sulla pizza Margherita?', '["Tonno e cipolla", "Pomodoro, mozzarella e basilico", "Solo olio e sale"]'::jsonb, 1, 2);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Quale piatto famoso porta il nome della regina Margherita?', '["La cassata", "La pizza Margherita", "L’arancina"]'::jsonb, 1, 1);
  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, 'senior', 'Chi era Margherita di Savoia?', '["Una pittrice trapanese", "Una santa", "La prima regina d’Italia"]'::jsonb, 2, 2);

  raise notice 'migr. 36: creata l''area Trapani (% lezioni)', (select count(*) from edu_lezioni where corso_id = v_corso);
end $trapani$;
