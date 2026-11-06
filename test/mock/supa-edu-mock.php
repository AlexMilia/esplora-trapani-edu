<?php
/* FINTO SUPABASE per le azioni didattiche di api.php (migr. 32):
   edu_get_cliente · edu_get_corsi · edu_classe_stato · edu_salva_esito ·
   edu_diario_classe · edu_compito_apri · edu_compito_valuta.
   Registra tutto ciò che riceve in /tmp/supa-edu-state.json, così il test
   può controllare COSA è arrivato al database, non solo la risposta. */
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
  'lezioni'=>[['id'=>'salinaio','tit'=>'Il salinaio','stato'=>'pubblicata']]]]);
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
if ($p==='/rest/v1/rpc/edu_get_lezione_tenant') out([
  'id'=>'salinaio','tit'=>'Il salinaio','intro'=>'Guardate le vasche','coccio'=>null,
  'didattica'=>[
    'obiettivi'=>['primaria'=>['descrive il lavoro del salinaio con parole sue','riconosce gli attrezzi del mestiere'],
                  'medie'=>['spiega il ciclo di produzione del sale']],
    'parole_chiave'=>['salina','vasca salante','pala','cristallizzazione'],
    'prima'=>'Chiedere alla classe da dove arriva il sale che hanno in cucina. Raccogliere tre ipotesi alla lavagna.',
    'durante'=>'Fermare il video quando il salinaio solleva la pala: far descrivere il gesto e il peso. Aprire la scoperta sulle vasche.',
    'dopo'=>'Disegnare la vasca salante e nominarne le parti con le parole chiave.',
    'materiali'=>['quaderno','sale grosso da toccare'],
    'collegamenti'=>'Storia, cap. 3 — il lavoro dell uomo e il paesaggio'],
  'corso'=>['id'=>'mestieri','uuid'=>'co-1','tit'=>'Antichi Mestieri','prologo'=>null,'mascotte'=>[],
    'didattica'=>['traguardi'=>['primaria'=>['riconosce le tracce del passato nel territorio'],'medie'=>['usa fonti materiali']],
                  'discipline'=>['storia','geografia']]],
  'video'=>[['guid'=>'g-sal']],'tappe'=>[],
  'quiz'=>[['q'=>'Come si chiama la vasca dove cristallizza il sale?','opts'=>['Vasca salante','Vasca fredda'],'ok'=>0]],
  'quiz2'=>null]);
if ($p==='/rest/v1/rpc/edu_get_mascotte') out([]);
if ($p==='/rest/v1/edu_eventi') out([],201);
out(['message'=>'mock: rotta non gestita '.$p],404);
