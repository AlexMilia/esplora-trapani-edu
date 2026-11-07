<?php
/* FINTO SUPABASE per le azioni didattiche di api.php (migr. 32):
   edu_get_cliente · edu_get_corsi · edu_classe_stato · edu_salva_esito ·
   edu_diario_classe · edu_compito_apri · edu_compito_valuta.
   Registra tutto ciò che riceve in /tmp/supa-edu-state.json, così il test
   può controllare COSA è arrivato al database, non solo la risposta. */
define('SCHEDA_SALINAIO', json_decode(<<<'J'
{
 "numero": 1,
 "di": 5,
 "prima": "Secondo te, come si «raccoglie» il sale? Scrivi tre parole che ti vengono in mente pensando a una salina.",
 "trova": [
  "Il palo a forma di T",
  "Il fondo di argilla",
  "Il paluneddo, la pala del salinaio",
  "Un munzeddu, il cumulo di sale",
  "La crosta di sale nella vasca"
 ],
 "distrattori": [
  "Un mulino a vento"
 ],
 "fasi": [
  "Il salinaio rompe la crosta di sale con il palo a T.",
  "Raccoglie il sale con il paluneddo, senza toccare l'argilla del fondo.",
  "Controlla la punta della pala: se resta bianca, il sale è puro.",
  "Porta il sale fuori dalla vasca e forma il munzeddu.",
  "Il munzeddu asciuga e si copre di una crosta naturale che lo protegge dalla pioggia."
 ],
 "glossario": [
  {
   "parola": "munzeddu"
  },
  {
   "parola": "paluneddo"
  },
  {
   "parola": "crosta di sale"
  },
  {
   "parola": "argilla"
  },
  {
   "parola": "vasca salante"
  }
 ],
 "territorio": "Perché le saline sono proprio sulla costa tra Trapani e Marsala? Pensa al mare, al sole e al vento.",
 "capacita": [
  "Forza fisica",
  "Pazienza",
  "Precisione",
  "Conoscere il meteo",
  "Lavoro di squadra",
  "Creatività"
 ],
 "intervista": [
  "Hai mai visto una salina da vicino? Cosa ricordi?",
  "Conosci qualcuno che ha lavorato in salina o nel commercio del sale?",
  "Perché, secondo te, il sale di Trapani è famoso?"
 ],
 "disegno": "il paluneddo o il palo a T",
 "vero_falso": [
  {
   "f": "Il munzeddu è un mucchio di sale.",
   "v": true
  },
  {
   "f": "Il palo a T rompe la crosta di sale.",
   "v": true
  },
  {
   "f": "Il sale si fa con l'acqua del mare.",
   "v": true
  },
  {
   "f": "Il sale cresce sugli alberi.",
   "v": false
  }
 ],
 "autovalutazione": [
  "So spiegare le fasi di questo mestiere",
  "Conosco almeno tre parole del mestiere",
  "Ho lavorato bene con la mia squadra"
 ],
 "adattata": {
  "trova4": [
   "Il munzeddu",
   "La vasca con il sale",
   "Il palo a T",
   "La pala"
  ],
  "fasi3": [
   "Rompo la crosta di sale con il palo a T.",
   "Raccolgo il sale con la pala.",
   "Faccio il munzeddu."
  ],
  "parole": [
   "munzeddu",
   "pala",
   "vasca"
  ]
 }
}
J
, true));
$F='/tmp/supa-edu-state.json';
$S=@json_decode(@file_get_contents($F),true) ?: ['log'=>[],'esiti'=>[]];
$m=$_SERVER['REQUEST_METHOD'];
$p=parse_url($_SERVER['REQUEST_URI'],PHP_URL_PATH);
$j=json_decode(file_get_contents('php://input'),true);
$auth=$_SERVER['HTTP_AUTHORIZATION']??'';
$S['log'][]=['p'=>$p,'body'=>$j,'auth'=>$auth];
function out($a,$c=200){ global $S,$F; file_put_contents($F,json_encode($S)); http_response_code($c); header('Content-Type: application/json'); echo json_encode($a); exit; }

/* la anon key è l'unica credenziale che api.php deve usare: se arriva altro, è un errore */
if ($auth!=='Bearer anon-finta') out(['message'=>'api.php non deve usare questa chiave: '.$auth],401);

$CLIENTE=['id'=>'cl-1','slug'=>'esplora-trapani','nome'=>'Esplora Trapani',
  'brand'=>['titolo'=>'Antichi Mestieri'],'piano'=>'premium','limiti'=>['quiz_live'=>true,'nome'=>'Premium'],
  'licenza_stato'=>'attiva','attiva'=>true,'progetto_legacy'=>'antichi-mestieri-trapani'];

if ($p==='/rest/v1/rpc/edu_get_cliente') out($CLIENTE);
if ($p==='/rest/v1/rpc/edu_get_corsi') out([[
  'id'=>'mestieri','uuid'=>'co-1','tit'=>'Antichi Mestieri','em'=>'🛠️','stato'=>'pubblicato','ordine'=>10,
  'origine'=>'proprio','didattica'=>['traguardi'=>['primaria'=>['riconosce le tracce del passato']],'uda'=>['monte_ore'=>14]],
  /* l'elenco serve anche a scheda.php: quando in regia non si scrive il numero
     della scheda, lo deduce dal posto che la lezione occupa qui dentro.
     'senzanum' e' la lezione di prova senza numero scritto a mano: e' la terza di sei. */
  'lezioni'=>[['id'=>'salinaio','tit'=>'Il salinaio','stato'=>'pubblicata'],
              ['id'=>'corallaio','tit'=>'Il corallaio','stato'=>'pubblicata'],
              ['id'=>'senzanum','tit'=>'Lezione senza numero','stato'=>'pubblicata'],
              ['id'=>'tappeti','tit'=>'Il tessitore di tappeti ericini','stato'=>'pubblicata'],
              ['id'=>'olive','tit'=>'La raccolta delle olive','stato'=>'pubblicata'],
              ['id'=>'vendemmia','tit'=>'La vendemmia','stato'=>'pubblicata']]]]);
if ($p==='/rest/v1/rpc/edu_classe_stato'){
  $cod=strtoupper($j['p_codice']??'');
  if($cod==='SCADUTA-1') out(['classe'=>$cod,'valida'=>false,'scuola'=>'IC Scaduto','scuola_id'=>'sc-9']);
  out(['classe'=>$cod,'valida'=>true,'scuola'=>'IC Pagoto','scuola_id'=>'sc-1']);
}
if ($p==='/rest/v1/rpc/edu_salva_esito'){
  $e=$j['p']??[];
  if(($e['cliente']??'')!=='esplora-trapani') out(['ok'=>false,'err'=>'cliente']);
  if(strtoupper($e['classe']??'')==='SCADUTA-1') out(['ok'=>false,'err'=>'licenza_scuola']);
  $S['esiti'][]=$e;
  out(['ok'=>true,'id'=>count($S['esiti'])]);
}
if ($p==='/rest/v1/rpc/edu_diario_classe') out([
  ['corso'=>'mestieri','lezione'=>'salinaio','tit'=>'Il salinaio','ordine'=>10,'fatta'=>true,'quando'=>'2027-01-12T10:00:00Z','volte'=>2,'pct'=>80],
  ['corso'=>'mestieri','lezione'=>'corallaio','tit'=>'Il corallaio','ordine'=>20,'fatta'=>false,'quando'=>null,'volte'=>0,'pct'=>null]]);
if ($p==='/rest/v1/rpc/edu_compito_apri'){
  $k=strtoupper($j['p_codice']??'');
  if($k!=='SAL2026X') out(null);
  out(['ok'=>true,'codice'=>'SAL2026X','titolo'=>'Rivedi la vasca','consegna'=>'Guarda e rispondi',
    'livello'=>'junior','clip'=>['guid'=>'g-sal','da'=>10,'a'=>70],'lezione'=>'salinaio',
    'cliente'=>'esplora-trapani','brand'=>['titolo'=>'Antichi Mestieri'],'scadenza'=>null,
    'domande'=>[   /* NOTA: nessun campo "ok": la RPC vera non lo restituisce */
      ['domanda'=>'Come si chiama la vasca?','opzioni'=>['Vasca salante','Vasca fredda']],
      ['domanda'=>'Che attrezzo usa il salinaio?','opzioni'=>['Rastrello','Pala']]]]);
}
if ($p==='/rest/v1/rpc/edu_compito_valuta'){
  $k=strtoupper($j['p_codice']??''); $r=$j['p_risposte']??[];
  if($k!=='SAL2026X') out(['ok'=>false,'err'=>'compito']);
  $giuste=[0,1]; $n=0; $es=[];
  foreach($giuste as $i=>$g){
    $dato=$r[$i]??null;
    $bene=($dato!==null && (int)$dato===$g);
    if($bene)$n++;
    $es[]=$bene?['n'=>$i,'giusta'=>true]:['n'=>$i,'giusta'=>false,'ok'=>$g];
  }
  $S['esiti'][]=['modalita'=>'compito','classe'=>$j['p_classe']??'','n_giuste'=>$n,'n_domande'=>count($giuste),'risposte'=>$r];
  out(['ok'=>true,'n_domande'=>count($giuste),'n_giuste'=>$n,'esito'=>$es]);
}
if ($p==='/rest/v1/rpc/edu_get_lezione_tenant'){
  $slug=$j['p_lezione_slug']??'';
  /* i contenuti veri dei mestieri, se ci sono, stanno in contenuti/{slug}.json:
     così con lo stesso mock si generano le schede di tutti e cinque */
  $fileCont = __DIR__.'/../../contenuti/'.preg_replace('/[^a-z]/','',$slug).'.json';
  $cont = (is_file($fileCont)) ? json_decode(file_get_contents($fileCont), true) : null;
  if($cont) unset($cont['_nota']);
  /* 'senzanum': come il salinaio, ma senza numero/di/disegno scritti in regia.
     Serve a provare che la piattaforma li deduce da sola. */
  if($slug==='senzanum'){ $cont=json_decode(file_get_contents(__DIR__.'/../../contenuti/salinaio.json'),true);
    unset($cont['_nota'],$cont['numero'],$cont['di'],$cont['disegno']); }
  if($slug!=='salinaio' && $slug!=='spoglia' && !$cont) out(null);     /* lezione inesistente */
  $conScheda = ($slug!=='spoglia');
  $TITOLI=['salinaio'=>'Il salinaio','corallaio'=>'Il corallaio','tappeti'=>'Il tessitore di tappeti ericini',
           'olive'=>'La raccolta delle olive','vendemmia'=>'La vendemmia','spoglia'=>'Il salinaio',
           'senzanum'=>'Lezione senza numero'];
  out([
  'id'=>$slug,'tit'=>($TITOLI[$slug]??'Lezione'),'sub'=>($slug==='salinaio'?'La salina tra Trapani e Paceco':''),'intro'=>'Guardate le vasche','coccio'=>null,
  'didattica'=>[
    'obiettivi'=>['primaria'=>['descrive il lavoro del salinaio con parole sue','riconosce gli attrezzi del mestiere'],
                  'medie'=>['spiega il ciclo di produzione del sale']],
    'parole_chiave'=>['salina','vasca salante','pala','cristallizzazione'],
    'prima'=>'Chiedere alla classe da dove arriva il sale che hanno in cucina. Raccogliere tre ipotesi alla lavagna.',
    'durante'=>'Fermare il video quando il salinaio solleva la pala: far descrivere il gesto e il peso.',
    'dopo'=>'Disegnare la vasca salante e nominarne le parti con le parole chiave.',
    'materiali'=>['quaderno','sale grosso da toccare'],
    'collegamenti'=>'Storia, cap. 3 — il lavoro dell uomo e il paesaggio',
    'scheda'=>$conScheda?($cont?:SCHEDA_SALINAIO):[]],
  'corso'=>['id'=>'mestieri','uuid'=>'co-1','tit'=>'Antichi Mestieri di Trapani','prologo'=>null,'mascotte'=>[],
    'didattica'=>['traguardi'=>['primaria'=>['riconosce le tracce del passato nel territorio'],'medie'=>['usa fonti materiali']],
                  'discipline'=>['storia','geografia']]],
  'video'=>[['guid'=>'g-sal']],
  'tappe'=>[
    ['v'=>0,'t'=>12,'hotspots'=>[
      ['yaw'=>10,'pitch'=>0,'em'=>'🧂','tit'=>'Il munzeddu','txt'=>'Il cumulo di sale appena raccolto.','foto'=>'https://vz-bedaaab5-085.b-cdn.net/g-sal/thumbnail.jpg'],
      ['yaw'=>80,'pitch'=>0,'em'=>'🔨','tit'=>'Il palo a T','txt'=>'Serve a rompere la crosta di sale.','foto'=>'']]],
    ['v'=>0,'t'=>48,'hotspots'=>[
      ['yaw'=>-30,'pitch'=>-5,'em'=>'🥄','tit'=>'La pala','txt'=>'Si chiama paluneddo.','foto'=>''],
      ['yaw'=>120,'pitch'=>0,'em'=>'💧','tit'=>'La vasca con il sale','txt'=>'La vasca salante, dove il sale cristallizza.','foto'=>'']]]],
  'quiz'=>[['q'=>'Come si chiama la vasca dove cristallizza il sale?','opts'=>['Vasca salante','Vasca fredda'],'ok'=>0]],
  'quiz2'=>null]);
}
if ($p==='/rest/v1/rpc/edu_get_mascotte') out([]);
if ($p==='/rest/v1/edu_eventi'){ $S['ultimo_evento']=$j; out([],201); }
out(['message'=>'mock: rotta non gestita '.$p],404);
