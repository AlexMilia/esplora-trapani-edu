<?php
/* =====================================================================
   SALE IN CLASSE - api.php (ponte protetto verso Supabase)
   Generico: il progetto (saline / mestieri / ...) e' $EDU_PROGETTO in dati/config.php
   Difesa in profondita' (pattern Odissea/mareandmore):
   - token di sessione obbligatorio (header X-EDU-T, generato da
     index.php): senza passare dalla pagina, 403
   - referer check + rate limiting per sessione
   - la anon key di Supabase vive SOLO qui sul server (dati/config.php)
   - cache su file: le classi non dipendono dalla latenza di Supabase,
     e se Supabase e' giu' si serve l'ultima copia buona
   - risposta CIFRATA AES-256-CBC con chiave di sessione
   Azioni: menu | lezione&id=slug | lez&token=... | track (POST)
   ===================================================================== */
session_start();
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';

/* ---- TENANT (Fase 2 SaaS): ?c=slug, oppure /edu/{slug}/ dal path,
        oppure $EDU_TENANT_DEFAULT del config. '' = modalità legacy. ---- */
function edu_tenant_slug(){
  global $EDU_TENANT_DEFAULT;
  $s = isset($_GET['c']) ? strtolower(trim($_GET['c'])) : '';
  if($s === '' && isset($_SERVER['REQUEST_URI'])
     && preg_match('#/edu/([a-z0-9][a-z0-9-]{1,40})/#', strtolower($_SERVER['REQUEST_URI']), $m)
     && !in_array($m[1], ['app','mestieri','saline'], true) && !preg_match('/^ver\d+$/', $m[1])){
    $s = $m[1];
  }
  if($s === '' && isset($EDU_TENANT_DEFAULT)) $s = (string)$EDU_TENANT_DEFAULT;
  return preg_match('/^[a-z0-9][a-z0-9-]{1,40}$/', $s) ? $s : '';
}
$EDU_C = edu_tenant_slug();
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

/* ---- limite di richieste per INDIRIZZO IP ----
   Quello per sessione non basta: chi non manda il cookie ottiene una
   sessione nuova a ogni richiesta e il contatore resta a 1. Questo invece
   conta per IP su file, ed è condiviso da api.php, live.php e attiva.php. */
function edu_ip(){
  $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
  foreach (['HTTP_CF_CONNECTING_IP','HTTP_X_FORWARDED_FOR'] as $h) {   /* proxy/CDN */
    if (!empty($_SERVER[$h])) { $p = explode(',', $_SERVER[$h]); $ip = trim($p[0]); break; }
  }
  return preg_replace('/[^0-9a-fA-F\.:]/', '', substr($ip, 0, 45));
}
function edu_throttle($azione = 'api', $max = 240, $finestra = 60){
  $dir = __DIR__ . '/dati/rl';
  if (!is_dir($dir)) @mkdir($dir, 0755, true);
  $f = $dir . '/' . $azione . '_' . md5(edu_ip()) . '.txt';
  $ora = time();
  $fp = @fopen($f, 'c+');
  if (!$fp) return true;                       /* disco non scrivibile: non blocco le classi */
  @flock($fp, LOCK_EX);
  $raw = stream_get_contents($fp);
  $d = @json_decode($raw, true);
  if (!is_array($d) || ($ora - ($d['t0'] ?? 0)) > $finestra) $d = ['t0' => $ora, 'n' => 0];
  $d['n']++;
  $ok = ($d['n'] <= $max);
  rewind($fp); ftruncate($fp, 0); fwrite($fp, json_encode($d)); fflush($fp);
  @flock($fp, LOCK_UN); fclose($fp);
  if (random_int(0, 50) === 0) {               /* pulizia dei contatori vecchi */
    foreach (glob($dir . '/*.txt') ?: [] as $v) if ($ora - (int)@filemtime($v) > 3600) @unlink($v);
  }
  return $ok;
}
function edu_deny($code, $err){
  http_response_code($code);
  echo json_encode(['ok' => false, 'err' => $err]);
  exit;
}

/* ---- VERSIONE (sempre accessibile, serve a capire quale file è online) ---- */
if(isset($_GET['ver'])){
  header('Content-Type: text/plain; charset=utf-8');
  echo "Sale in Classe · api.php v5 (catalogo + scuole: licenza a tre livelli) · progetto: " . $EDU_PROGETTO . "\n";
  echo "tenant: " . ($EDU_C !== '' ? $EDU_C : '(legacy: ' . $EDU_PROGETTO . ')') . "\n";
  echo "diagnostica: api.php?action=diag&k=LA_CHIAVE\n";
  exit;
}

/* ---- DIAGNOSTICA (in chiaro, protetta da chiave in config.php) ----
   Apri:  api.php?action=diag&k=LA_TUA_CHIAVE
   Non stampa mai la anon key, solo la sua lunghezza. */
if(isset($_GET['action']) && $_GET['action'] === 'diag'){
  $k = isset($_GET['k']) ? $_GET['k'] : '';
  if($EDU_DIAG_KEY === '' || !hash_equals($EDU_DIAG_KEY, $k)) edu_deny(403, 'diag');
  $cacheFile = __DIR__ . '/dati/cache_catalogo.json';
  list($c1, $o1, $e1) = edu_supa('/rest/v1/rpc/edu_get_lezioni', ['p_progetto' => $EDU_PROGETTO]);
  $dec = json_decode($o1, true);
  echo json_encode([
    'php'              => PHP_VERSION,
    'curl'             => function_exists('curl_init'),
    'openssl'          => function_exists('openssl_encrypt'),
    'anon_key_lunghezza' => strlen($SUPA_ANON),
    'supabase_url'     => $SUPA_URL,
    'progetto'         => $EDU_PROGETTO,
    'tenant'           => $EDU_C,
    'tenant_cliente'   => ($EDU_C !== '' ? edu_cliente($EDU_C) : null),
    'rpc_http'         => $c1,
    'rpc_errore'       => $e1,
    'rpc_e_array'      => is_array($dec),
    'rpc_n_lezioni'    => is_array($dec) ? count($dec) : null,
    'rpc_risposta'     => substr((string)$o1, 0, 400),
    'cache_scrivibile' => is_writable(__DIR__ . '/dati'),
    'cache_presente'   => file_exists($cacheFile),
    'mascotte_config_fallback'=> array_keys(is_array($EDU_MASCOTTE) ? $EDU_MASCOTTE : []),
    'mascotte_db'      => edu_mascotte_db(true),
  ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
  exit;
}

/* ---- limite per IP (prima di tutto: vale anche per chi non manda il cookie) ---- */
if(!edu_throttle('api', 300, 60)){
  edu_log('api_block', 'rate_ip ' . edu_ip());
  header('Retry-After: 60');
  edu_deny(429, 'rate');
}

/* ---- token di sessione ---- */
$tok = isset($_SERVER['HTTP_X_EDU_T']) ? $_SERVER['HTTP_X_EDU_T'] : '';
if(!isset($_SESSION['edu_t']) || !isset($_SESSION['edu_k'])
   || $tok === '' || !hash_equals($_SESSION['edu_t'], $tok)){
  edu_log('api_block', 'token');
  edu_deny(403, 'token');
}

/* ---- referer ---- */
if($EDU_CHECK_REFERER){
  $ref  = isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : '';
  $host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '';
  if($host === '' || strpos($ref, $host) === false){
    edu_log('api_block', 'referer: ' . $ref);
    edu_deny(403, 'ref');
  }
}

/* ---- rate limit per sessione ---- */
$now = time();
if(!isset($_SESSION['edu_rl']) || $now - $_SESSION['edu_rl']['t0'] > $EDU_RATE_WIN){
  $_SESSION['edu_rl'] = ['t0' => $now, 'n' => 0];
}
$_SESSION['edu_rl']['n']++;
if($_SESSION['edu_rl']['n'] > $EDU_RATE_MAX){
  edu_log('api_block', 'rate');
  edu_deny(429, 'rate');
}

/* ---- risposta cifrata AES-256-CBC con chiave di sessione ---- */
function edu_out($arr){
  $key = @hex2bin($_SESSION['edu_k']);
  if($key === false || strlen($key) !== 32 || !function_exists('openssl_encrypt')){
    echo json_encode($arr); /* fallback estremo, mai atteso su Aruba */
    exit;
  }
  $iv = random_bytes(16);
  $ct = openssl_encrypt(json_encode($arr), 'aes-256-cbc', $key, OPENSSL_RAW_DATA, $iv);
  echo json_encode(['enc' => true, 'iv' => base64_encode($iv), 'data' => base64_encode($ct)]);
  exit;
}

/* ---- chiamata a Supabase (la chiave resta qui sul server) ----
   $minimal = true SOLO per gli insert (tracking): sulle RPC l'header
   "Prefer: return=minimal" farebbe tornare un corpo vuoto. */
function edu_supa($path, $body, $minimal = false){
  global $SUPA_URL, $SUPA_ANON;
  if($SUPA_ANON === '') return [0, '', 'anon key mancante in dati/config.php'];
  $url  = $SUPA_URL . $path;
  $json = json_encode($body, JSON_UNESCAPED_UNICODE);
  $head = [
    'Content-Type: application/json',
    'apikey: ' . $SUPA_ANON,
    'Authorization: Bearer ' . $SUPA_ANON,
  ];
  if($minimal) $head[] = 'Prefer: return=minimal';

  if(function_exists('curl_init')){
    $ch = curl_init($url);
    curl_setopt_array($ch, [
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_POST           => true,
      CURLOPT_POSTFIELDS     => $json,
      CURLOPT_HTTPHEADER     => $head,
      CURLOPT_TIMEOUT        => 8,
      CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    $out  = curl_exec($ch);
    $err  = curl_error($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$code, $out, $err];
  }

  /* fallback per hosting senza cURL */
  $ctx = stream_context_create(['http' => [
    'method'        => 'POST',
    'header'        => implode("\r\n", $head),
    'content'       => $json,
    'timeout'       => 8,
    'ignore_errors' => true,
  ]]);
  $out  = @file_get_contents($url, false, $ctx);
  $code = 0;
  if(isset($http_response_header[0]) &&
     preg_match('/\s(\d{3})\s/', $http_response_header[0], $m)){ $code = (int)$m[1]; }
  return [$code, ($out === false ? '' : $out), ($out === false ? 'stream fallito' : '')];
}

/* ---- catalogo lezioni: cache su file + refresh da Supabase ---- */
function edu_catalogo(){
  global $EDU_CACHE_TTL, $EDU_PROGETTO;
  $f = __DIR__ . '/dati/cache_catalogo.json';
  $cache = @json_decode(@file_get_contents($f), true);
  $fresca = is_array($cache) && isset($cache['t']) && (time() - $cache['t'] < $EDU_CACHE_TTL);
  if($fresca && isset($cache['dati'])) return $cache['dati'];

  list($code, $out, $err) = edu_supa('/rest/v1/rpc/edu_get_lezioni', ['p_progetto' => $EDU_PROGETTO]);
  $dati = ($code === 200) ? json_decode($out, true) : null;
  if(is_array($dati)){
    @file_put_contents($f, json_encode(['t' => time(), 'dati' => $dati], JSON_UNESCAPED_UNICODE));
    return $dati;   /* anche vuoto: significa "nessuna lezione pubblicata" */
  }
  edu_log('upstream_ko', 'catalogo http ' . $code . ' ' . $err . ' ' . substr((string)$out, 0, 200));
  /* Supabase giu' o chiave mancante: servi l'ultima copia buona, anche vecchia */
  if(is_array($cache) && isset($cache['dati'])) return $cache['dati'];
  return null;
}

/* ---- TENANT: cliente (brand + licenza) e corsi, cache per cliente ---- */
function edu_cache_json($file, $ttl, $fetch){
  $cache = @json_decode(@file_get_contents($file), true);
  $fresca = is_array($cache) && isset($cache['t']) && (time() - $cache['t'] < $ttl);
  if($fresca && array_key_exists('dati', $cache)) return $cache['dati'];
  $dati = $fetch();
  if($dati !== null){
    @file_put_contents($file, json_encode(['t' => time(), 'dati' => $dati], JSON_UNESCAPED_UNICODE));
    return $dati;
  }
  if(is_array($cache) && array_key_exists('dati', $cache)) return $cache['dati'];  /* ultima copia buona */
  return null;
}
function edu_cliente($slug){
  global $EDU_CACHE_TTL;
  static $memo = [];
  if(isset($memo[$slug])) return $memo[$slug];
  $f = __DIR__ . '/dati/cache_cliente_' . $slug . '.json';
  $memo[$slug] = edu_cache_json($f, $EDU_CACHE_TTL, function() use ($slug){
    list($code, $out, $err) = edu_supa('/rest/v1/rpc/edu_get_cliente', ['p_slug' => $slug]);
    if($code !== 200){ edu_log('upstream_ko', 'cliente http ' . $code . ' ' . $err); return null; }
    $d = json_decode($out, true);
    return (is_array($d) && isset($d['slug'])) ? $d : [];   /* [] = cliente inesistente (o migrazione 20 non eseguita) */
  });
  return $memo[$slug];
}
function edu_corsi($slug){
  global $EDU_CACHE_TTL;
  $f = __DIR__ . '/dati/cache_catalogo_' . $slug . '_' . date('Ymd') . '.json';   /* le licenze scadono per data */
  return edu_cache_json($f, $EDU_CACHE_TTL, function() use ($slug){
    list($code, $out, $err) = edu_supa('/rest/v1/rpc/edu_get_corsi', ['p_cliente_slug' => $slug]);
    if($code !== 200){ edu_log('upstream_ko', 'corsi http ' . $code . ' ' . $err); return null; }
    $d = json_decode($out, true);
    return is_array($d) ? $d : [];
  });
}
function edu_lezione_tenant($slug, $id){
  global $EDU_CACHE_TTL;
  $f = __DIR__ . '/dati/cache_lez_' . $slug . '_' . preg_replace('/[^a-z0-9\-_]/', '', $id) . '.json';
  return edu_cache_json($f, $EDU_CACHE_TTL, function() use ($slug, $id){
    list($code, $out, $err) = edu_supa('/rest/v1/rpc/edu_get_lezione_tenant', ['p_cliente_slug' => $slug, 'p_lezione_slug' => $id]);
    if($code !== 200){ edu_log('upstream_ko', 'lezione http ' . $code . ' ' . $err); return null; }
    $d = json_decode($out, true);
    return (is_array($d) && isset($d['id'])) ? $d : [];
  });
}
/* lezioni piatte del tenant (compat player) + mappa lezione → corso */
/* stato della classe (e quindi della scuola) per il codice ?classe= */
function edu_classe_stato($clienteId, $codice){
  if($clienteId === '' || $codice === '' || $codice === 'ANON') return null;
  static $memo = [];
  $k = $clienteId . '|' . strtoupper($codice);
  if(isset($memo[$k])) return $memo[$k];
  list($code, $out) = edu_supa('/rest/v1/rpc/edu_classe_stato', ['p_cliente' => $clienteId, 'p_codice' => $codice]);
  $d = ($code === 200) ? json_decode($out, true) : null;
  return $memo[$k] = (is_array($d) ? $d : null);
}
function edu_lezioni_piatte($corsi){
  $flat = []; $mappa = [];
  foreach((array)$corsi as $co){
    foreach((array)($co['lezioni'] ?? []) as $l){
      $l['corso'] = $co['id']; $flat[] = $l; $mappa[$l['id']] = $co;
    }
  }
  return [$flat, $mappa];
}

/* ---- mascotte: configurazione + video per livello, dal DB (regia) ----
   cache su file come il catalogo; se la RPC manca o Supabase e' giu'
   si usa l'ultima copia buona, poi il fallback $EDU_MASCOTTE di config. */
function edu_mascotte_db($nocache = false){
  global $EDU_CACHE_TTL, $EDU_PROGETTO, $EDU_MASCOTTE, $EDU_MASCOTTE_QUIZ_SEMPRE, $EDU_BRAND;
  $f = __DIR__ . '/dati/cache_mascotte.json';
  $cache = @json_decode(@file_get_contents($f), true);
  $fresca = is_array($cache) && isset($cache['t']) && (time() - $cache['t'] < $EDU_CACHE_TTL);
  if(!$nocache && $fresca && isset($cache['dati'])) return $cache['dati'];
  list($code, $out, $err) = edu_supa('/rest/v1/rpc/edu_get_mascotte', ['p_progetto' => $EDU_PROGETTO]);
  $d = ($code === 200) ? json_decode($out, true) : null;
  if(is_array($d) && isset($d['video'])){
    @file_put_contents($f, json_encode(['t' => time(), 'dati' => $d], JSON_UNESCAPED_UNICODE));
    return $d;
  }
  if($code !== 200) edu_log('upstream_ko', 'mascotte http ' . $code . ' ' . $err);
  if(is_array($cache) && isset($cache['dati'])) return $cache['dati'];
  /* fallback: config.php */
  $v = is_array($EDU_MASCOTTE) ? $EDU_MASCOTTE : [];
  return [
    'progetto' => $EDU_PROGETTO, 'nome' => $EDU_PROGETTO,
    'mascotte' => [
      'nome' => isset($EDU_BRAND['mascotte']) ? $EDU_BRAND['mascotte'] : '',
      'img'  => isset($EDU_BRAND['mascotte_img']) ? $EDU_BRAND['mascotte_img'] : '',
      'junior' => true, 'senior' => true, 'quiz_sempre' => !empty($EDU_MASCOTTE_QUIZ_SEMPRE)],
    'video' => ['junior' => $v, 'senior' => $v],
    'origine' => 'config.php',
  ];
}

$action = isset($_GET['action']) ? $_GET['action'] : '';

/* ---------- MENU ---------- */
if($action === 'menu'){
  /* --- Fase 2: tenant --- */
  $cliente = ($EDU_C !== '') ? edu_cliente($EDU_C) : null;
  if(is_array($cliente) && isset($cliente['slug'])){
    if(!empty($cliente['progetto_legacy'])) $EDU_PROGETTO = $cliente['progetto_legacy'];  /* mascotte del progetto */
    $pub = ['nome' => $cliente['nome'], 'slug' => $cliente['slug'], 'brand' => $cliente['brand'] ?? new stdClass(),
            'piano' => $cliente['piano'] ?? 'base', 'piattaforma' => $cliente['piattaforma'] ?? 'Esplora Trapani Edu',
            'licenza_stato' => $cliente['licenza_stato'] ?? 'attiva', 'licenza_fine' => $cliente['licenza_fine'] ?? null,
            'limiti' => (isset($cliente['limiti']) && is_array($cliente['limiti'])) ? $cliente['limiti'] : ['quiz_live' => true, 'report' => true, 'nome' => '—'],
            'contatto_email' => $cliente['contatto_email'] ?? null];
    if(empty($cliente['attiva'])){
      edu_log('licenza_ko', $EDU_C . ' ' . ($cliente['licenza_stato'] ?? ''));
      edu_out(['ok' => false, 'err' => 'licenza', 'cliente' => $pub]);
    }
    /* terzo livello di licenza: la scuola a cui appartiene la classe */
    $classe = isset($_GET['classe']) ? preg_replace('/[^A-Za-z0-9\-]/', '', $_GET['classe']) : '';
    $st = ($classe !== '') ? edu_classe_stato($cliente['id'] ?? '', $classe) : null;
    if(is_array($st) && isset($st['valida']) && $st['valida'] === false){
      edu_log('licenza_ko', 'scuola ' . ($st['scuola'] ?? '?') . ' classe ' . $classe);
      edu_out(['ok' => false, 'err' => 'licenza_scuola', 'cliente' => $pub,
               'scuola' => ['nome' => $st['scuola'] ?? '', 'licenza_stato' => $st['licenza_stato'] ?? '',
                            'licenza_a' => $st['licenza_a'] ?? null]]);
    }
    $corsi = edu_corsi($EDU_C);
    if(!is_array($corsi)) edu_deny(503, 'supabase');
    list($flat, ) = edu_lezioni_piatte($corsi);
    $m = edu_mascotte_db();
    $cfg = isset($m['mascotte']) && is_array($m['mascotte']) ? $m['mascotte'] : [];
    $vid = isset($m['video']) && is_array($m['video']) ? $m['video'] : ['junior' => [], 'senior' => []];
    edu_out([
      'ok'          => true,
      'tenant'      => $EDU_C,
      'cliente'     => $pub,
      'scuola'      => (is_array($st) && !empty($st['scuola'])) ? ['nome' => $st['scuola'], 'classe' => $st['nome'] ?? $classe] : null,
      'corsi'       => $corsi,
      'lezioni'     => $flat,
      'mascotte'    => isset($vid['junior']) ? $vid['junior'] : [],
      'mascotteLiv' => $vid,
      'mascotteCfg' => $cfg,
      'quizSempre'  => !isset($cfg['quiz_sempre']) || $cfg['quiz_sempre'],
    ]);
  }
  if($EDU_C !== '' && is_array($cliente) && !isset($cliente['slug']) && $cliente !== []){ edu_deny(404, 'cliente'); }
  /* --- legacy (nessun tenant o migrazione 20 non ancora eseguita) --- */
  $cat = edu_catalogo();
  if(!is_array($cat)) edu_deny(503, 'supabase');
  $out = [];
  foreach($cat as $l){
    if(isset($l['stato']) && $l['stato'] === 'bozza') continue;   /* le bozze restano in regia */
    $out[] = [
      'id'     => $l['id'],
      'em'     => isset($l['em']) ? $l['em'] : '🛠️',
      'cls'    => isset($l['cls']) ? $l['cls'] : 'rosa',
      'tit'    => $l['tit'],
      'sub'    => isset($l['sub']) ? $l['sub'] : '',
      'durata' => isset($l['durata']) ? $l['durata'] : '',
      'stato'  => isset($l['stato']) ? $l['stato'] : 'pubblicata',
      'acc'    => isset($l['acc']) ? $l['acc'] : new stdClass(),
    ];
  }
  $m = edu_mascotte_db();
  $cfg = isset($m['mascotte']) && is_array($m['mascotte']) ? $m['mascotte'] : [];
  $vid = isset($m['video']) && is_array($m['video']) ? $m['video'] : ['junior' => [], 'senior' => []];
  edu_out([
    'ok'          => true,
    'lezioni'     => $out,
    'mascotte'    => isset($vid['junior']) ? $vid['junior'] : [],   /* compat player v1 */
    'mascotteLiv' => $vid,                                         /* {junior:{...}, senior:{...}} */
    'mascotteCfg' => $cfg,                                         /* nome, img, junior, senior, quiz_sempre */
    'quizSempre'  => !isset($cfg['quiz_sempre']) || $cfg['quiz_sempre'],
  ]);
}

/* ---------- LEZIONE COMPLETA per slug ---------- */
if($action === 'lezione'){
  $id = isset($_GET['id']) ? $_GET['id'] : '';
  $cliente = ($EDU_C !== '') ? edu_cliente($EDU_C) : null;
  if(is_array($cliente) && isset($cliente['slug'])){
    if(empty($cliente['attiva'])) edu_deny(403, 'licenza');
    $classe = isset($_GET['classe']) ? preg_replace('/[^A-Za-z0-9\-]/', '', $_GET['classe']) : '';
    if($classe !== ''){
      $st = edu_classe_stato($cliente['id'] ?? '', $classe);
      if(is_array($st) && isset($st['valida']) && $st['valida'] === false) edu_deny(403, 'licenza_scuola');
    }
    $lez = edu_lezione_tenant($EDU_C, $id);
    if(!is_array($lez)) edu_deny(503, 'dati');
    if(!isset($lez['id'])) edu_deny(404, 'lezione');
    edu_log('lezione', $EDU_C . '/' . $id);
    edu_out(['ok' => true, 'lezione' => $lez]);
  }
  $cat = edu_catalogo();
  if(!is_array($cat)) edu_deny(503, 'dati');
  foreach($cat as $l){
    if($l['id'] === $id){
      if(isset($l['stato']) && ($l['stato'] === 'soon' || $l['stato'] === 'bozza')) edu_deny(404, 'soon');
      edu_log('lezione', $id);
      edu_out(['ok' => true, 'lezione' => $l]);
    }
  }
  edu_deny(404, 'lezione');
}

/* ---------- ANTEPRIMA / COPIE DOCENTE via token (no cache) ---------- */
if($action === 'lez'){
  $t = isset($_GET['token']) ? $_GET['token'] : '';
  if(!preg_match('/^[a-f0-9]{6,40}$/', $t)) edu_deny(400, 'token_fmt');
  list($code, $out) = edu_supa('/rest/v1/rpc/edu_get_lezione_token', ['p_token' => $t]);
  $lez = ($code === 200) ? json_decode($out, true) : null;
  if(!is_array($lez) || !isset($lez['id'])) edu_deny(404, 'lez');
  edu_log('anteprima', $lez['id']);
  edu_out(['ok' => true, 'lezione' => $lez]);
}

/* ---------- TRACKING anonimo (POST) ---------- */
if($action === 'track'){
  $b = json_decode(file_get_contents('php://input'), true);
  if(!is_array($b)) edu_deny(400, 'body');
  $classe = isset($b['classe']) ? strtoupper($b['classe']) : 'ANON';
  if(!preg_match('/^[A-Z0-9-]{1,20}$/', $classe)) $classe = 'ANON';
  $tipo = isset($b['tipo']) ? $b['tipo'] : '';
  if(!in_array($tipo, ['lezione_avviata','lezione_completata','quiz_esito'], true)){
    edu_deny(400, 'tipo');
  }
  $lezione = isset($b['lezione']) ? substr(preg_replace('/[^a-z0-9\-_]/', '', strtolower($b['lezione'])), 0, 40) : '';
  $dettaglio = (isset($b['dettaglio']) && is_array($b['dettaglio'])) ? $b['dettaglio'] : [];
  if(strlen(json_encode($dettaglio)) > 1500) $dettaglio = [];
  global $EDU_PROGETTO;
  $riga = [
    'codice_classe' => $classe,
    'progetto'      => $EDU_PROGETTO,
    'lezione'       => ($lezione !== '' ? $lezione : '—'),
    'tipo'          => $tipo,
    'dettaglio'     => $dettaglio,
  ];
  if($EDU_C !== ''){
    $cliente = edu_cliente($EDU_C);
    if(is_array($cliente) && isset($cliente['id'])){
      $riga['cliente_id'] = $cliente['id'];
      if(!empty($cliente['progetto_legacy'])) $riga['progetto'] = $cliente['progetto_legacy'];
      list(, $mappa) = edu_lezioni_piatte(edu_corsi($EDU_C));
      if(isset($mappa[$lezione]['uuid'])) $riga['corso_id'] = $mappa[$lezione]['uuid'];
    }
  }
  list($code, ) = edu_supa('/rest/v1/edu_eventi', $riga, true);
  edu_log('track', $tipo . ' ' . $classe . ' ' . $lezione . ' http' . $code);
  edu_out(['ok' => ($code === 201 || $code === 200)]);
}

edu_deny(400, 'action');
