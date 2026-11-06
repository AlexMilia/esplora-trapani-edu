-- ============================================================================
-- MIGRAZIONE 33 — i testi delle schede entrano nelle lezioni
-- ----------------------------------------------------------------------------
-- Perché:
--   scheda.php compone la scheda di carta con quello che trova nella lezione
--   (punti che brillano, tappe, quiz) più i testi scritti in regia, che vivono
--   in edu_lezioni.didattica->'scheda'. Finora quei testi stavano in file del
--   codice (contenuti/*.json) e NON nel database: in produzione le schede
--   sarebbero uscite incomplete. Questa migrazione li porta dentro le lezioni,
--   una volta sola. Da lì in poi si modificano dalla regia, come ogni altro
--   contenuto della lezione.
--
-- Due garanzie:
--   1. NON SOVRASCRIVE. Se una lezione ha già una scheda (anche solo un campo
--      scritto in regia), viene lasciata esattamente com'è.
--   2. È ripetibile. Rilanciarla non cambia nulla: serve solo a riempire le
--      lezioni ancora vuote. Per ricaricare il testo di partenza di una
--      lezione, in regia svuota i campi della scheda, salva, e rilancia.
--
-- Come trova la lezione: prima per slug (più grafie possibili), poi per
--   titolo. Guarda solo le lezioni originali (owner is null), mai le copie
--   dei docenti. Se una lezione non c'è ancora, lo dice e va avanti: la
--   migrazione non fallisce per questo.
--
-- Verifica dopo l'esecuzione (nei messaggi NOTICE):
--   «riempita», «già compilata, lasciata com'è» oppure «nessuna lezione».
-- ============================================================================

do $mig$
declare
  r        record;
  v_id     uuid;
  v_slug   text;
  v_esiste boolean;
  n_fatte  int := 0;
  n_salta  int := 0;
  n_manca  int := 0;
begin
  for r in
    select * from (values
    ('Il salinaio', array['salinaio','il-salinaio','mestiere-del-salinaio','salina'], '%salina%', '{"numero":1,"di":5,"prima":"Secondo te, come si «raccoglie» il sale? Scrivi tre parole che ti vengono in mente pensando a una salina.","trova":["Il palo a forma di T","Il fondo di argilla","Il paluneddo, la pala del salinaio","Un munzeddu, il cumulo di sale","La crosta di sale nella vasca"],"distrattori":["Un mulino a vento"],"fasi":["Il salinaio rompe la crosta di sale con il palo a T.","Raccoglie il sale con il paluneddo, senza toccare l''argilla del fondo.","Controlla la punta della pala: se resta bianca, il sale è puro.","Porta il sale fuori dalla vasca e forma il munzeddu.","Il munzeddu asciuga e si copre di una crosta naturale che lo protegge dalla pioggia."],"glossario":[{"parola":"munzeddu"},{"parola":"paluneddo"},{"parola":"crosta di sale"},{"parola":"argilla"},{"parola":"vasca salante"}],"territorio":"Perché le saline sono proprio sulla costa tra Trapani e Marsala? Pensa al mare, al sole e al vento.","capacita":["Forza fisica","Pazienza","Precisione","Conoscere il meteo","Lavoro di squadra","Creatività"],"intervista":["Hai mai visto una salina da vicino? Cosa ricordi?","Conosci qualcuno che ha lavorato in salina o nel commercio del sale?","Perché, secondo te, il sale di Trapani è famoso?"],"disegno":"il paluneddo o il palo a T","vero_falso":[{"f":"Il munzeddu è un mucchio di sale.","v":true},{"f":"Il palo a T rompe la crosta di sale.","v":true},{"f":"Il sale si fa con l''acqua del mare.","v":true},{"f":"Il sale cresce sugli alberi.","v":false}],"autovalutazione":["So spiegare le fasi di questo mestiere","Conosco almeno tre parole del mestiere","Ho lavorato bene con la mia squadra"],"adattata":{"trova4":["Il munzeddu","La vasca con il sale","Il palo a T","La pala"],"fasi3":["Rompo la crosta di sale con il palo a T.","Raccolgo il sale con la pala.","Faccio il munzeddu."],"parole":["munzeddu","pala","vasca"]}}'::jsonb),
    ('Il corallaio', array['corallaio','il-corallaio','corallo','il-corallo'], '%corall%', '{"numero":2,"di":5,"prima":"Il corallo: è una pietra, una pianta o un animale? E che cosa ci si fa? Scrivi tre parole che ti vengono in mente.","trova":["Il banco di lavoro del corallaio","La lampada che illumina il banco","Un rametto di corallo grezzo","Un attrezzo per incidere [DA VERIFICARE SUI VIDEO]","Un oggetto finito in corallo"],"distrattori":["Una rete da pesca"],"fasi":["Il corallaio sceglie il rametto di corallo grezzo.","Taglia il pezzo della misura che gli serve.","Incide la forma con l''attrezzo, poco per volta. [DA VERIFICARE SUI VIDEO]","Liscia e lucida la superficie finché non brilla.","Monta il pezzo finito sull''oggetto (spillone, orecchino, oggetto sacro)."],"glossario":[{"parola":"corallo"},{"parola":"grezzo"},{"parola":"bottega"},{"parola":"incisione"},{"parola":"lucidatura"}],"territorio":"Perché proprio Trapani è diventata famosa per il corallo? Pensa al mare, al porto e alle botteghe della città.","intervista":["In casa vostra c''è un oggetto di corallo? Chi ve l''ha dato?","Conosci qualcuno che lavorava il corallo o l''oro a Trapani?","Secondo te perché oggi restano poche botteghe?"],"disegno":"l''oggetto finito che ti è piaciuto di più","vero_falso":[{"f":"Il corallo viene dal mare.","v":true},{"f":"Il corallaio lavora con attrezzi piccoli.","v":true},{"f":"Il corallo grezzo è già lucido.","v":false},{"f":"A Trapani si lavorava il corallo.","v":true}],"adattata":{"trova4":["Il banco di lavoro","La lampada","Il corallo grezzo","L''oggetto finito"],"fasi3":["Scelgo il corallo grezzo.","Lo lavoro con l''attrezzo.","Lo lucido finché brilla."],"parole":["corallo","bottega","attrezzo"]}}'::jsonb),
    ('I tappeti ericini', array['tappeti','tappeti-ericini','il-tessitore-di-tappeti','tessitore'], '%tappet%', '{"numero":3,"di":5,"prima":"Un tappeto: come si fa un disegno con dei fili? E quanto tempo ci vorrà? Scrivi tre parole.","trova":["Il telaio","I fili dell''ordito, tesi","La spola o la navetta [DA VERIFICARE SUI VIDEO]","Il motivo che si ripete","Il tappeto già cominciato"],"distrattori":["Una macchina da cucire"],"fasi":["Si tendono i fili dell''ordito sul telaio.","Si passa il filo della trama fra i fili tesi.","Si batte la trama per stringere il tessuto. [DA VERIFICARE SUI VIDEO]","Il motivo cresce riga dopo riga, sempre uguale.","Si taglia il tappeto dal telaio e si rifiniscono i bordi."],"glossario":[{"parola":"telaio"},{"parola":"trama"},{"parola":"ordito"},{"parola":"modulo"},{"parola":"motivo"}],"territorio":"Perché questo tappeto si chiama «ericino»? Che cosa lega un oggetto al luogo dove si fa?","intervista":["In casa avete un tappeto o una coperta fatti a mano? Chi li ha fatti?","Qualcuno in famiglia sa cucire, ricamare o tessere? Chi glielo ha insegnato?","Secondo te, perché oggi pochissime persone sanno fare questo lavoro?"],"disegno":"il motivo del tappeto, ripetuto almeno tre volte","vero_falso":[{"f":"Il tappeto si fa sul telaio.","v":true},{"f":"Il motivo si ripete sempre uguale.","v":true},{"f":"Per fare un tappeto ci vuole un''ora.","v":false},{"f":"I fili tesi si chiamano ordito.","v":true}],"adattata":{"trova4":["Il telaio","I fili","Il motivo","Il tappeto"],"fasi3":["Metto i fili sul telaio.","Passo il filo fra i fili.","Il disegno cresce."],"parole":["telaio","trama","motivo"]}}'::jsonb),
    ('La raccolta delle olive', array['olive','raccolta-olive','raccolta-delle-olive','olio'], '%oliv%', '{"numero":4,"di":5,"prima":"L''olio che mettiamo sul pane: quante mani ci sono passate prima di arrivare in bottiglia? Scrivi tre parole.","trova":["Le reti stese sotto l''albero","Il rastrello o l''abbacchiatore [DA VERIFICARE SUI VIDEO]","Le cassette con le olive","L''uliveto in fila","Il frantoio"],"distrattori":["Un trattore che ara"],"fasi":["Si stendono le reti sotto l''albero.","Si fanno cadere le olive dai rami.","Si raccolgono le olive nelle cassette, togliendo foglie e rametti.","Le olive vanno al frantoio il prima possibile. [DA VERIFICARE SUI VIDEO: entro quante ore]","Al frantoio le olive vengono macinate e si ottiene l''olio."],"glossario":[{"parola":"uliveto"},{"parola":"rete"},{"parola":"frantoio"},{"parola":"molitura"},{"parola":"resa"}],"territorio":"Perché l''olivo cresce bene qui e non dappertutto? Pensa al clima, al sole e alla pioggia.","intervista":["In famiglia qualcuno ha raccolto le olive? Dove e quando?","Comprate l''olio o ve lo fate? Da chi?","Qual è la differenza fra l''olio del frantoio e quello del supermercato, secondo chi intervisti?"],"disegno":"un ramo d''olivo con le olive e la rete sotto","vero_falso":[{"f":"L''olio si fa con le olive.","v":true},{"f":"Le reti servono a raccogliere le olive che cadono.","v":true},{"f":"Le olive si possono lasciare un mese nelle cassette.","v":false},{"f":"Il frantoio macina le olive.","v":true}],"adattata":{"trova4":["L''albero di olivo","La rete","Le olive","La cassetta"],"fasi3":["Stendo la rete.","Faccio cadere le olive.","Porto le olive al frantoio."],"parole":["oliva","rete","frantoio"]}}'::jsonb),
    ('La vendemmia', array['vendemmia','la-vendemmia','uva'], '%vendemm%', '{"numero":5,"di":5,"prima":"L''uva si raccoglie e poi? Chi decide qual è il giorno giusto? Scrivi tre parole.","trova":["I filari della vigna","Un grappolo maturo","La forbice da vendemmia","La cassetta dell''uva","La cantina con le vasche [DA VERIFICARE SUI VIDEO]"],"distrattori":["Un albero di limoni"],"fasi":["Si controlla l''uva per decidere il giorno giusto.","Si taglia il grappolo con la forbice e si mette nella cassetta.","L''uva arriva in cantina in giornata.","L''uva viene pigiata e comincia la fermentazione. [DA VERIFICARE SUI VIDEO]","Il mosto diventa vino e riposa."],"glossario":[{"parola":"vigneto"},{"parola":"filare"},{"parola":"grappolo"},{"parola":"vendemmia"},{"parola":"fermentazione"}],"territorio":"Perché la vite sta bene in questa terra? E perché il vino prende il nome del posto in cui nasce?","intervista":["In famiglia qualcuno ha fatto la vendemmia? Racconta com''era.","Si faceva il vino in casa? Chi e come?","Che differenza c''è, per chi intervisti, fra la vendemmia di una volta e quella di oggi?"],"disegno":"un filare con i grappoli, e la cassetta piena","vero_falso":[{"f":"Il vino si fa con l''uva.","v":true},{"f":"L''uva si raccoglie in estate o in autunno.","v":true},{"f":"La vendemmia si fa quando si vuole.","v":false},{"f":"L''uva arriva in cantina il giorno stesso.","v":true}],"adattata":{"trova4":["La vigna","Il grappolo","La forbice","La cassetta"],"fasi3":["Taglio il grappolo.","Riempio la cassetta.","Porto l''uva in cantina."],"parole":["uva","grappolo","cantina"]}}'::jsonb)
    ) as t(nome, slugs, titolo_like, dati)
  loop
    -- 1) per slug, fra le lezioni originali
    select l.id, l.slug into v_id, v_slug
      from edu_lezioni l
     where l.owner is null and l.slug = any (r.slugs)
     order by (l.stato = 'pubblicata') desc, l.ordine nulls last
     limit 1;

    -- 2) se non si trova, per titolo
    if v_id is null then
      select l.id, l.slug into v_id, v_slug
        from edu_lezioni l
       where l.owner is null and l.titolo ilike r.titolo_like
       order by (l.stato = 'pubblicata') desc, l.ordine nulls last
       limit 1;
    end if;

    if v_id is null then
      n_manca := n_manca + 1;
      raise notice '% → nessuna lezione in archivio: la scheda si scriverà in regia quando la lezione esisterà', r.nome;
      continue;
    end if;

    select coalesce(l.didattica -> 'scheda', '{}'::jsonb) <> '{}'::jsonb
      into v_esiste from edu_lezioni l where l.id = v_id;

    if v_esiste then
      n_salta := n_salta + 1;
      raise notice '% (lezione %) → ha già una scheda, lasciata com''è', r.nome, v_slug;
      continue;
    end if;

    update edu_lezioni
       set didattica = jsonb_set(coalesce(didattica, '{}'::jsonb), '{scheda}', r.dati, true),
           aggiornato_il = now()
     where id = v_id;

    n_fatte := n_fatte + 1;
    raise notice '% (lezione %) → scheda riempita', r.nome, v_slug;
  end loop;

  raise notice '--- schede: % riempite, % già compilate, % lezioni non trovate ---',
               n_fatte, n_salta, n_manca;
end
$mig$;

-- ----------------------------------------------------------------------------
-- Controllo: una scheda riempita deve avere almeno le fasi e il glossario,
-- altrimenti la stampa esce monca e tanto vale saperlo adesso.
-- ----------------------------------------------------------------------------
do $ctl$
declare n int;
begin
  select count(*) into n
    from edu_lezioni l
   where l.owner is null
     and coalesce(l.didattica -> 'scheda', '{}'::jsonb) <> '{}'::jsonb
     and (jsonb_array_length(coalesce(l.didattica -> 'scheda' -> 'fasi', '[]'::jsonb)) = 0
       or jsonb_array_length(coalesce(l.didattica -> 'scheda' -> 'glossario', '[]'::jsonb)) = 0);
  if n > 0 then
    raise notice 'ATTENZIONE: % lezioni hanno una scheda senza fasi o senza glossario: apri la regia → Scheda da stampare e completale', n;
  end if;
end
$ctl$;
