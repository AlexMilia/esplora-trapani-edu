<?php
/* ============================================================
   DEBUG 500 · Sale in Classe · v1.2 (23/08/2026)
   Carica questo file ACCANTO a index.php e apri:
       debug500.php?k=salina
   Ti dice perché index.php dà HTTP 500. Sintassi volutamente
   "antica" (niente arrow fn) per girare su qualsiasi PHP.
   RIMUOVILO appena risolto.
   ============================================================ */
error_reporting(E_ALL);
ini_set('display_errors', '1');
header('Content-Type: text/plain; charset=utf-8');

if (!isset($_GET['k']) || $_GET['k'] !== 'salina') { die('chiave mancante: aggiungi ?k=salina'); }

$ATTESO_MD5  = '989033979e261e52702d8673eca3ba3e';
$ATTESO_SIZE = 83126;

echo "=== DEBUG 500 — Sale in Classe ===\n\n";
echo "PHP versione: " . PHP_VERSION . "\n";
echo "SAPI: " . php_sapi_name() . "\n";
echo "Utente processo: " . (function_exists('get_current_user') ? get_current_user() : '?') . "\n\n";

/* ---- 1. integrità di index.php ---- */
$f = __DIR__ . '/index.php';
echo "--- 1. index.php ---\n";
if (!is_file($f)) {
  echo "❌ index.php NON ESISTE in questa cartella!\n";
} else {
  $size = filesize($f);
  $md5  = md5(str_replace("\r\n", "\n", file_get_contents($f)));   /* fine-riga normalizzati: un upload ASCII (CRLF→LF) non è un file corrotto */
  echo "dimensione: $size byte (attesi: $ATTESO_SIZE con fine-riga Windows; " . ($size === $ATTESO_SIZE ? "✓" : ($size < $ATTESO_SIZE && $size > $ATTESO_SIZE*0.95 ? "✓ probabile upload ASCII, fine-riga convertiti: va bene" : "❌ DIVERSA → upload troncato: ricarica il file")) . ")\n";
  echo "md5: $md5\n";
  echo "     " . ($md5 === $ATTESO_MD5 ? "✓ identico al file consegnato" : "❌ DIVERSO dal file consegnato ($ATTESO_MD5) → il file sul server non è quello giusto") . "\n";

  /* ---- 2. permessi (suPHP di Aruba: 666/777 = HTTP 500!) ---- */
  echo "\n--- 2. permessi (Aruba/suPHP: file scrivibili da gruppo/altri = 500) ---\n";
  $p = fileperms($f) & 0777;
  echo "index.php: " . sprintf('%o', $p) . " " . (($p & 022) ? "❌ SCRIVIBILE da gruppo/altri → QUESTA è la causa tipica del 500: metti 644 dal client FTP" : "✓ ok (non scrivibile da gruppo/altri)") . "\n";
  $pd = fileperms(__DIR__) & 0777;
  echo "cartella:  " . sprintf('%o', $pd) . " " . (($pd & 022) ? "❌ cartella scrivibile da gruppo/altri → metti 755" : "✓ ok") . "\n";

  /* ---- 3. lint del file direttamente sul server ---- */
  echo "\n--- 3. sintassi sul server ---\n";
  if (function_exists('exec')) {
    $out = array(); $rc = 1;
    @exec('php -l ' . escapeshellarg($f) . ' 2>&1', $out, $rc);
    echo ($out ? implode("\n", $out) : '(exec disponibile ma php CLI non trovato)') . "\n";
  } else {
    echo "(exec disabilitato: salto — usa i punti 1 e 2)\n";
  }
}

/* ---- 4. dati/config.php ---- */
echo "\n--- 4. dati/config.php ---\n";
$cfg = __DIR__ . '/dati/config.php';
if (!is_file($cfg)) {
  echo "❌ dati/config.php NON ESISTE → index.php muore alla require = 500\n";
} else {
  $pc = fileperms($cfg) & 0777;
  echo "esiste ✓ — permessi: " . sprintf('%o', $pc) . (($pc & 022) ? " ❌ metti 644" : " ✓") . "\n";
  define('EDU_OK', 1);
  $ok = @include $cfg;
  echo ($ok !== false ? "include riuscito ✓" : "❌ include FALLITO → l'errore è dentro config.php") . "\n";
  echo "funzione edu_log: " . (function_exists('edu_log') ? "presente ✓" : "❌ ASSENTE → index.php la chiama alla riga 34 = fatal = 500") . "\n";
}

/* ---- 4b. resto della filiera ---- */
echo "\n--- 4b. resto della filiera ---\n";
$api = __DIR__ . '/api.php';
if (is_file($api)) {
  $pa = fileperms($api) & 0777;
  echo "api.php: esiste ✓ — permessi: " . sprintf('%o', $pa) . (($pa & 022) ? " ❌ metti 644" : " ✓") . "\n";
} else {
  echo "api.php: ❌ ASSENTE → il player carica ma menu/lezioni falliranno (serve accanto a index.php)\n";
}
$ht = __DIR__ . '/dati/.htaccess';
echo "dati/.htaccess: " . (is_file($ht) ? "presente ✓ (dati/ negata dal web)" : "❌ ASSENTE → crea dati/.htaccess con: Require all denied") . "\n";
$rs = __DIR__ . '/rispondi.php';
echo "rispondi.php: " . (is_file($rs) ? "presente ✓" : "assente (serve per il quiz live)") . "\n";
$ll = __DIR__ . '/live-lim.js';
echo "live-lim.js: " . (is_file($ll) ? "presente ✓ (" . filesize($ll) . " byte, attesi 76567)" : "❌ ASSENTE → il pulsante Gioca live darà errore") . "\n";

/* ---- 5. live.php nella stessa cartella ---- */
echo "\n--- 5. live.php ---\n";
$lv = __DIR__ . '/live.php';
if (is_file($lv)) {
  $pl = fileperms($lv) & 0777;
  echo "esiste ✓ — permessi: " . sprintf('%o', $pl) . (($pl & 022) ? " ❌ metti 644" : " ✓") . "\n";
} else {
  echo "assente (serve per il quiz live)\n";
}

echo "\n=== FINE — dopo il fix RIMUOVI questo file ===\n";
