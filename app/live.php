<?php
/* ============================================================
   SALE IN CLASSE — QUIZ LIVE  ·  live.php  ·  v1.2 (23/08/2026)
   ------------------------------------------------------------
   Backend delle stanze quiz live ("il Kahoot delle saline").
   FILOSOFIA: stato su FILE (dati/live/{pin}.json) con flock,
   ZERO chiamate Supabase durante la partita. Funziona anche se
   Supabase è giù. Il tracking finale lo fa la LIM tramite il
   normale api.php?action=track (evento quiz_live).

   Nessun dato personale: soprannomi liberi, token effimeri,
   stanze cancellate dopo 3 ore. Classifica individuale: MAI.
   Esito sempre e solo di classe (ricristallizzazione).

   Deploy: accanto a index.php/api.php. Richiede la cartella
   dati/ già negata dal web (.htaccess Require all denied);
   live.php crea da solo dati/live/.
   ============================================================ */

declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('Referrer-Policy: strict-origin-when-cross-origin');

$LIVE_DIR      = __DIR__ . '/dati/live';
$TTL_STANZA    = 3 * 3600;   // vita massima di una stanza (s)
$MAX_GIOCATORI = 200;        /* aula magna: verificato in stress test */
$MAX_QUIZ      = 30;         // domande max per stanza
$MAX_NOME      = 14;         // caratteri soprannome

/* ---------- utilità ---------- */

/* limite per IP: senza, si possono creare stanze a raffica o provare PIN */
function live_ip(){
  $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
  foreach (['HTTP_CF_CONNECTING_IP','HTTP_X_FORWARDED_FOR'] as $h)
    if (!empty($_SERVER[$h])) { $p = explode(',', $_SERVER[$h]); $ip = trim($p[0]); break; }
  return preg_replace('/[^0-9a-fA-F\.:]/', '', substr($ip, 0, 45));
}
function live_throttle(string $azione, int $max, int $finestra): bool {
  $dir = __DIR__ . '/dati/rl';
  if (!is_dir($dir)) @mkdir($dir, 0755, true);
  $f = $dir . '/live_' . $azione . '_' . md5(live_ip()) . '.txt';
  $ora = time();
  $fp = @fopen($f, 'c+');
  if (!$fp) return true;
  @flock($fp, LOCK_EX);
  $d = @json_decode(stream_get_contents($fp), true);
  if (!is_array($d) || ($ora - ($d['t0'] ?? 0)) > $finestra) $d = ['t0' => $ora, 'n' => 0];
  $d['n']++;
  $ok = ($d['n'] <= $max);
  rewind($fp); ftruncate($fp, 0); fwrite($fp, json_encode($d)); fflush($fp);
  @flock($fp, LOCK_UN); fclose($fp);
  return $ok;
}
function fail(string $msg, int $code = 400): void {
  http_response_code($code);
  echo json_encode(['err' => $msg], JSON_UNESCAPED_UNICODE);
  exit;
}

function ok(array $data = []): void {
  echo json_encode(['ok' => true] + $data, JSON_UNESCAPED_UNICODE);
  exit;
}

function body(): array {
  $raw = file_get_contents('php://input');
  if ($raw === '' || $raw === false) return [];
  $j = json_decode($raw, true);
  return is_array($j) ? $j : [];
}

function pin_path(string $pin): string {
  global $LIVE_DIR;
  if (!preg_match('/^[0-9]{6}$/', $pin)) fail('PIN non valido');
  return $LIVE_DIR . '/' . $pin . '.json';
}

/* Lettura+modifica atomica della stanza sotto flock.
   $fn riceve l'array stanza (o null se assente) e restituisce
   [nuovaStanza|null(=cancella)|false(=non toccare), rispostaPerIlClient] */
function con_stanza(string $pin, callable $fn, bool $creare = false): void {
  $path = pin_path($pin);
  if (!$creare && !is_file($path)) fail('Stanza non trovata: controlla il PIN', 404);
  $fp = fopen($path, 'c+');
  if (!$fp) fail('Errore di scrittura sul server', 500);
  if (!flock($fp, LOCK_EX)) { fclose($fp); fail('Server occupato, riprova', 503); }
  $raw = stream_get_contents($fp);
  $stanza = ($raw !== '' && $raw !== false) ? json_decode($raw, true) : null;
  if (!is_array($stanza)) $stanza = null;

  // stanza scaduta = come inesistente
  global $TTL_STANZA;
  if ($stanza && time() - ($stanza['creato'] ?? 0) > $TTL_STANZA) $stanza = null;
  if (!$stanza && !$creare) { flock($fp, LOCK_UN); fclose($fp); fail('La stanza è scaduta', 410); }

  [$nuova, $out] = $fn($stanza);

  if ($nuova === null && $creare === false && $out === null) {
    // cancellazione richiesta
    ftruncate($fp, 0);
    flock($fp, LOCK_UN); fclose($fp);
    @unlink($path);
    ok();
  }
  if (is_array($nuova)) {
    rewind($fp); ftruncate($fp, 0);
    fwrite($fp, json_encode($nuova, JSON_UNESCAPED_UNICODE));
    fflush($fp);
  }
  flock($fp, LOCK_UN); fclose($fp);
  ok($out ?? []);
}

function token(): string { return bin2hex(random_bytes(12)); }

/* fallback se mbstring non è disponibile */
function taglia(string $s, int $n): string {
  return function_exists('mb_substr') ? mb_substr($s, 0, $n) : substr($s, 0, $n);
}
function minuscolo(string $s): string {
  return function_exists('mb_strtolower') ? mb_strtolower($s) : strtolower($s);
}

function pulisci_nome(string $n): string {
  global $MAX_NOME;
  $n = trim(strip_tags($n));
  $n = preg_replace('/[^\p{L}\p{N} _\-\'.]/u', '', $n) ?? '';
  $n = preg_replace('/\s+/', ' ', $n) ?? '';
  return taglia($n, $MAX_NOME);
}

/* garbage collection stanze vecchie (best effort, 1 volta su ~20) */
function gc(): void {
  global $LIVE_DIR, $TTL_STANZA;
  if (random_int(0, 19) !== 0) return;
  foreach (glob($LIVE_DIR . '/*.json') ?: [] as $f) {
    if (time() - (int)@filemtime($f) > $TTL_STANZA) @unlink($f);
  }
}

/* ---------- preparazione ---------- */

if (!is_dir($LIVE_DIR)) {
  @mkdir($LIVE_DIR, 0755, true);
  // doppia rete oltre all'.htaccess di dati/
  @file_put_contents($LIVE_DIR . '/.htaccess', "Require all denied\n");
}
if (!is_writable($LIVE_DIR)) fail('dati/live non scrivibile', 500);

gc();

$action = $_GET['action'] ?? '';
$B = body();

/* limiti per IP: stanze nuove poche, tentativi d'ingresso moderati, polling ampio */
if ($action === 'crea' && !live_throttle('crea', 20, 600))  fail('Troppe stanze create da questa rete: riprova fra qualche minuto', 429);
if ($action === 'join' && !live_throttle('join', 500, 300)) fail('Troppi tentativi di ingresso: riprova fra qualche minuto', 429);
/* il polling di 'stato' è la voce grossa (30 alunni ogni 2s = 900/min PER CLASSE):
   una scuola con più classi dietro lo stesso IP non deve mai essere bloccata */
/* limiti PER TIPO di azione, tarati sullo stress test (500 alunni dallo stesso IP):
   - stato   : polling, ~30/min per alunno  → 20.000/min regge 600 telefoni
   - risposta: pochi per alunno ma tutti insieme → 6.000/min
   - resto   : avanza/chiudi/rimuovi/ver, azioni del docente → 1.200/min
   La creazione di stanze (sopra) resta stretta: è l'unica che costa disco. */
if     ($action === 'stato')    { if (!live_throttle('stato', 20000, 60))   fail('Troppe richieste: riprova fra un minuto', 429); }
elseif ($action === 'risposta') { if (!live_throttle('risposta', 6000, 60)) fail('Troppe richieste: riprova fra un minuto', 429); }
elseif (!live_throttle('tot', 1200, 60)) fail('Troppe richieste: riprova fra un minuto', 429);

/* ============================================================
   AZIONI
   ============================================================ */

switch ($action) {

/* ---- versione in chiaro (come ?ver di api.php) ---- */
case 'ver':
  ok(['live' => 'v1.2']);

/* ------------------------------------------------------------
   CREA — la LIM crea la stanza passando le domande del quiz.
   Le risposte esatte ("g") restano SOLO sul server: ai
   dispositivi degli alunni non arrivano mai prima dei risultati.
   body: { titolo, lezione, livello, quiz:[{domanda,opzioni[],g}] }
   → { pin, host }
   ------------------------------------------------------------ */
case 'crea': {
  $quiz = $B['quiz'] ?? null;
  if (!is_array($quiz) || count($quiz) < 1) fail('Quiz vuoto');
  if (count($quiz) > $MAX_QUIZ) fail('Troppe domande');
  $Q = [];
  foreach ($quiz as $q) {
    $dom = trim((string)($q['domanda'] ?? ''));
    $opz = $q['opzioni'] ?? null;
    $g   = $q['g'] ?? null;
    if ($dom === '' || !is_array($opz) || count($opz) < 2 || count($opz) > 6)
      fail('Domanda malformata');
    $opz = array_values(array_map(fn($o) => trim((string)$o), $opz));
    if (!is_int($g) || $g < 0 || $g >= count($opz)) fail('Indice risposta non valido');
    // "Lo sapevi?": spiegazione + media opzionali, svelati SOLO ai risultati
    $sp  = taglia(trim((string)($q['spiegazione'] ?? '')), 500);
    $med = trim((string)($q['media'] ?? ''));
    if ($med !== '' && (!preg_match('#^https://#i', $med) || strlen($med) > 500)) $med = '';
    $Q[] = ['domanda' => $dom, 'opzioni' => $opz, 'g' => $g,
             'sp' => $sp, 'med' => $med];
  }

  // PIN a 6 cifre libero (max 30 tentativi)
  $pin = null;
  for ($i = 0; $i < 30; $i++) {
    $p = str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    if (!is_file(pin_path($p))) { $pin = $p; break; }
  }
  if ($pin === null) fail('Server pieno, riprova', 503);

  $host = token();
  $stanza = [
    'pin'       => $pin,
    'creato'    => time(),
    'host'      => $host,
    'titolo'    => taglia(trim((string)($B['titolo'] ?? 'Quiz')), 80),
    'lezione'   => taglia(trim((string)($B['lezione'] ?? '')), 60),
    'livello'   => in_array($B['livello'] ?? '', ['junior','senior'], true) ? $B['livello'] : 'junior',
    'stato'     => 'attesa',      // attesa → domanda → risultati → … → fine
    'q_idx'     => -1,
    'quiz'      => $Q,
    'giocatori' => (object)[],    // token => {nome, risposte:{qIdx:opzIdx}}
  ];

  con_stanza($pin, fn($s) => [$stanza, ['pin' => $pin, 'host' => $host, 'n_quiz' => count($Q)]], true);
  break;
}

/* ------------------------------------------------------------
   JOIN — un alunno entra col PIN e un soprannome.
   Ammesso in ogni stato tranne "fine" (arrivi in ritardo ok).
   body: { pin, nome } → { token, nome, titolo, stato }
   ------------------------------------------------------------ */
case 'join': {
  $pin  = (string)($B['pin'] ?? '');
  $nome = pulisci_nome((string)($B['nome'] ?? ''));
  if ($nome === '') fail('Scegli un soprannome');

  con_stanza($pin, function ($s) use ($nome) {
    global $MAX_GIOCATORI;
    if ($s['stato'] === 'fine') fail('Il quiz è già finito', 410);
    $gioc = (array)$s['giocatori'];
    if (count($gioc) >= $MAX_GIOCATORI) fail('La stanza è piena');

    // soprannomi doppi: aggiungo un numero
    $nomi = array_map(fn($g) => minuscolo($g['nome']), $gioc);
    $base = $nome; $k = 2;
    while (in_array(minuscolo($nome), $nomi, true)) { $nome = $base . ' ' . $k; $k++; }

    $tok = token();
    $gioc[$tok] = ['nome' => $nome, 'risposte' => (object)[]];
    $s['giocatori'] = $gioc;
    return [$s, ['token' => $tok, 'nome' => $nome, 'titolo' => $s['titolo'], 'stato' => $s['stato']]];
  });
  break;
}

/* ------------------------------------------------------------
   RISPOSTA — un alunno risponde alla domanda corrente.
   Una sola risposta per domanda, accettata solo in stato
   "domanda" e solo per q_idx corrente. Non rivela l'esito.
   body: { pin, token, q, r } → { ok }
   ------------------------------------------------------------ */
case 'risposta': {
  $pin = (string)($B['pin'] ?? '');
  $tok = (string)($B['token'] ?? '');
  $q   = $B['q'] ?? null;  $r = $B['r'] ?? null;
  if (!is_int($q) || !is_int($r)) fail('Dati mancanti');

  con_stanza($pin, function ($s) use ($tok, $q, $r) {
    if ($s['stato'] !== 'domanda') fail('Le risposte sono chiuse', 409);
    if ($q !== $s['q_idx']) fail('Domanda superata', 409);
    $gioc = (array)$s['giocatori'];
    if (!isset($gioc[$tok])) fail('Non sei nella stanza', 403);
    $nOpz = count($s['quiz'][$q]['opzioni']);
    if ($r < 0 || $r >= $nOpz) fail('Risposta non valida');
    $risp = (array)$gioc[$tok]['risposte'];
    if (isset($risp[(string)$q])) return [false, ['gia' => true]];  // già risposto: idempotente
    $risp[(string)$q] = $r;
    $gioc[$tok]['risposte'] = $risp;
    $s['giocatori'] = $gioc;
    return [$s, []];
  });
  break;
}

/* ------------------------------------------------------------
   AVANZA — solo host. attesa→domanda0, domanda→risultati,
   risultati→domanda successiva oppure fine.
   body: { pin, host } → { stato, q_idx }
   ------------------------------------------------------------ */
case 'avanza': {
  $pin = (string)($B['pin'] ?? '');
  $h   = (string)($B['host'] ?? '');

  con_stanza($pin, function ($s) use ($h) {
    if (!hash_equals($s['host'], $h)) fail('Solo il docente può farlo', 403);
    switch ($s['stato']) {
      case 'attesa':
        $s['stato'] = 'domanda'; $s['q_idx'] = 0; break;
      case 'domanda':
        $s['stato'] = 'risultati'; break;
      case 'risultati':
        if ($s['q_idx'] + 1 < count($s['quiz'])) { $s['q_idx']++; $s['stato'] = 'domanda'; }
        else $s['stato'] = 'fine';
        break;
      case 'fine':
        return [false, ['stato' => 'fine', 'q_idx' => $s['q_idx']]];
    }
    return [$s, ['stato' => $s['stato'], 'q_idx' => $s['q_idx']]];
  });
  break;
}

/* ------------------------------------------------------------
   RIMUOVI — solo host, per soprannomi inopportuni in lobby.
   body: { pin, host, giocatore } → { ok }
   ------------------------------------------------------------ */
case 'rimuovi': {
  $pin = (string)($B['pin'] ?? '');
  $h   = (string)($B['host'] ?? '');
  $t   = (string)($B['giocatore'] ?? '');
  con_stanza($pin, function ($s) use ($h, $t) {
    if (!hash_equals($s['host'], $h)) fail('Solo il docente può farlo', 403);
    $gioc = (array)$s['giocatori'];
    unset($gioc[$t]);
    $s['giocatori'] = $gioc;
    return [$s, []];
  });
  break;
}

/* ------------------------------------------------------------
   CHIUDI — solo host: cancella la stanza (dopo il recap).
   body: { pin, host }
   ------------------------------------------------------------ */
case 'chiudi': {
  $pin = (string)($B['pin'] ?? '');
  $h   = (string)($B['host'] ?? '');
  con_stanza($pin, function ($s) use ($h) {
    if (!hash_equals($s['host'], $h)) fail('Solo il docente può farlo', 403);
    return [null, null];   // segnale di cancellazione
  });
  break;
}

/* ------------------------------------------------------------
   STATO — polling. Risposta diversa per alunno e per host.
   GET consigliato: ?action=stato&pin=…&token=…
   Alunno:  stato, q (senza risposta esatta) finché "domanda";
            in "risultati" riceve g + se ha indovinato;
            in "fine" il recap di classe.
   Host:    tutto + conteggi live + istogramma + elenco nomi.
   ------------------------------------------------------------ */
case 'stato': {
  $pin = (string)($_GET['pin'] ?? $B['pin'] ?? '');
  $tok = (string)($_GET['token'] ?? $B['token'] ?? '');

  con_stanza($pin, function ($s) use ($tok) {
    $eHost = $tok !== '' && hash_equals($s['host'], $tok);
    $gioc  = (array)$s['giocatori'];
    $qIdx  = $s['q_idx'];
    $out = [
      'stato'   => $s['stato'],
      'q_idx'   => $qIdx,
      'n_quiz'  => count($s['quiz']),
      'titolo'  => $s['titolo'],
      'n_gioc'  => count($gioc),
    ];

    // istogramma + statistiche della domanda corrente (o di tutte a fine)
    $isto = function (int $i) use ($s, $gioc): array {
      $q = $s['quiz'][$i];
      $conta = array_fill(0, count($q['opzioni']), 0);
      foreach ($gioc as $g) {
        $r = ((array)$g['risposte'])[(string)$i] ?? null;
        if (is_int($r) && isset($conta[$r])) $conta[$r]++;
      }
      $tot = array_sum($conta);
      return ['conta' => $conta, 'tot' => $tot, 'g' => $q['g'],
              'giuste' => $conta[$q['g']] ?? 0];
    };

    if ($s['stato'] === 'domanda' || $s['stato'] === 'risultati') {
      $q = $s['quiz'][$qIdx];
      $out['domanda'] = $q['domanda'];
      $out['opzioni'] = $q['opzioni'];
      // quanti hanno già risposto (visibile a tutti: crea attesa buona)
      $risposte = 0;
      foreach ($gioc as $g) if (isset(((array)$g['risposte'])[(string)$qIdx])) $risposte++;
      $out['n_risposte'] = $risposte;
    }

    if ($s['stato'] === 'risultati') {
      $st = $isto($qIdx);
      $out['g']     = $st['g'];
      $out['conta'] = $st['conta'];
      $out['tot']   = $st['tot'];
      $qq = $s['quiz'][$qIdx];
      if (!empty($qq['sp']))  $out['spiegazione'] = $qq['sp'];
      if (!empty($qq['med'])) $out['media']       = $qq['med'];
      if (!$eHost && isset($gioc[$tok])) {
        $mia = ((array)$gioc[$tok]['risposte'])[(string)$qIdx] ?? null;
        $out['mia']    = $mia;
        $out['giusta'] = ($mia === $st['g']);
      }
    }

    if ($s['stato'] === 'fine') {
      $recap = [];
      $sommaPct = 0;
      foreach ($s['quiz'] as $i => $q) {
        $st = $isto($i);
        $pct = $st['tot'] > 0 ? (int)round(100 * $st['giuste'] / $st['tot']) : 0;
        $sommaPct += $pct;
        $recap[] = ['domanda' => $q['domanda'], 'g' => $st['g'],
                    'conta' => $st['conta'], 'tot' => $st['tot'], 'pct' => $pct];
      }
      $out['recap'] = $recap;
      $out['pct_classe'] = count($recap) ? (int)round($sommaPct / count($recap)) : 0;
      if (!$eHost && isset($gioc[$tok])) {
        $mie = 0;
        foreach ($s['quiz'] as $i => $q)
          if ((((array)$gioc[$tok]['risposte'])[(string)$i] ?? null) === $q['g']) $mie++;
        $out['mie_giuste'] = $mie;   // solo sul SUO dispositivo, mai in classifica
      }
    }

    if ($eHost) {
      $out['host'] = true;
      if ($s['stato'] === 'fine') {
        $pod = array();
        foreach ($gioc as $g) {
          $n2 = 0;
          foreach ($s['quiz'] as $i2 => $q2)
            if (((((array)$g['risposte'])[(string)$i2]) ?? null) === $q2['g']) $n2++;
          $pod[] = array('nome' => $g['nome'], 'giuste' => $n2);
        }
        usort($pod, fn($a, $b) => $b['giuste'] <=> $a['giuste']);
        $out['podio'] = array_slice($pod, 0, 3);
      }
      $out['nomi'] = array_map(
        fn($t2, $g) => ['t' => $t2, 'nome' => $g['nome']],
        array_keys($gioc), array_values($gioc)
      );
      $out['lezione'] = $s['lezione'];
      $out['livello'] = $s['livello'];
    } else {
      $out['io_dentro'] = isset($gioc[$tok]);   // se rimosso, il client lo scopre qui
    }

    return [false, $out];   // sola lettura: non riscrivo il file
  });
  break;
}

default:
  fail('Azione sconosciuta', 404);
}
