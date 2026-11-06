<?php
/* =====================================================================
   ESPLORA TRAPANI EDU · scheda.php — la scheda da stampare per la classe
   ---------------------------------------------------------------------
   Compone la scheda dell'alunno a partire da quello che è GIÀ in
   piattaforma: i punti che brillano nel video 360 (hotspot) diventano le
   cose da cercare e il glossario, le tappe danno le fasi del lavoro in
   ordine, il quiz dà le domande, la scheda didattica dà la domanda di
   apertura e le parole chiave. Quello che non si può dedurre si scrive in
   regia (didattica.scheda) e sta tutto in pochi campi.

   Due versioni dagli stessi dati:
     tipo=standard   la scheda dell'alunno, 2 facciate A4
     tipo=adattata   versione strutturata (TEACCH) per un alunno con
                     autismo: agenda, una attività per pagina, tessere da
                     ritagliare, carte AIUTO e PAUSA, carta del ruolo nel
                     quiz nelle due modalità (LIM o telefoni)

   URL: scheda.php?c=cliente&lez=slug[&tipo=standard|adattata][&liv=junior|senior]
   Si stampa dal browser (Ctrl+P → A4). Nessuna libreria, nessun PDF da
   generare sul server: su Aruba non servirebbe altro che grattacapi.
   ===================================================================== */
session_start();
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';

if (!isset($_SESSION['edu_t'])) { $_SESSION['edu_t'] = bin2hex(random_bytes(24)); }

/* ---------- ingresso ---------- */
$C    = isset($_GET['c'])   ? preg_replace('/[^a-z0-9\-]/', '', strtolower($_GET['c'])) : '';
$LEZ  = isset($_GET['lez']) ? preg_replace('/[^a-z0-9\-_]/', '', strtolower($_GET['lez'])) : '';
$TIPO = (isset($_GET['tipo']) && $_GET['tipo'] === 'adattata') ? 'adattata' : 'standard';
$LIV  = (isset($_GET['liv']) && $_GET['liv'] === 'senior') ? 'senior' : 'junior';
if ($C === '' && isset($EDU_TENANT_DEFAULT)) $C = $EDU_TENANT_DEFAULT;

function fine($msg) {
  http_response_code(404);
  echo '<!doctype html><meta charset="utf-8"><title>Scheda non disponibile</title>'
     . '<div style="font:16px/1.6 system-ui;padding:40px;max-width:36em;margin:auto">'
     . '<h1 style="font-size:20px">Scheda non disponibile</h1><p>' . htmlspecialchars($msg) . '</p></div>';
  exit;
}
if ($C === '' || $LEZ === '') fine('Manca il cliente o la lezione nell’indirizzo.');

/* ---------- lettura dei dati (stessa strada di api.php: anon key + RPC) ---------- */
function supa_rpc($fn, $args) {
  global $SUPA_URL, $SUPA_ANON;
  $ch = curl_init(rtrim($SUPA_URL, '/') . '/rest/v1/rpc/' . $fn);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'apikey: ' . $SUPA_ANON,
                           'Authorization: Bearer ' . $SUPA_ANON],
    CURLOPT_POSTFIELDS => json_encode($args), CURLOPT_TIMEOUT => 12,
  ]);
  $out = curl_exec($ch); $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
  return ($code === 200) ? json_decode($out, true) : null;
}
$L = supa_rpc('edu_get_lezione_tenant', ['p_cliente_slug' => $C, 'p_lezione_slug' => $LEZ]);
if (!is_array($L)) fine('Questa lezione non esiste, non è pubblicata, oppure la licenza del cliente non è attiva.');
$CLI = supa_rpc('edu_get_cliente', ['p_slug' => $C]);

/* ---------- raccolta del contenuto ---------- */
$did    = isset($L['didattica']) && is_array($L['didattica']) ? $L['didattica'] : [];
$didCor = isset($L['corso']['didattica']) && is_array($L['corso']['didattica']) ? $L['corso']['didattica'] : [];
$S      = isset($did['scheda']) && is_array($did['scheda']) ? $did['scheda'] : [];
$Scor   = isset($didCor['scheda']) && is_array($didCor['scheda']) ? $didCor['scheda'] : [];
$livKey = ($LIV === 'senior') ? 'medie' : 'primaria';

/* i punti che brillano nel video: sono le cose da cercare, e sono anche il glossario */
$hot = [];
foreach ((isset($L['tappe']) && is_array($L['tappe'])) ? $L['tappe'] : [] as $tp) {
  foreach ((isset($tp['hotspots']) && is_array($tp['hotspots'])) ? $tp['hotspots'] : [] as $h) {
    $hot[] = [
      'em'   => isset($h['em']) ? $h['em'] : '',
      'tit'  => isset($h['tit']) ? trim($h['tit']) : '',
      'txt'  => trim(($LIV === 'senior' && !empty($h['txt2'])) ? $h['txt2'] : (isset($h['txt']) ? $h['txt'] : '')),
      'foto' => isset($h['foto']) ? $h['foto'] : '',
      't'    => isset($tp['t']) ? (float)$tp['t'] : 0,
    ];
  }
}
/* con ripiego: se in regia non si è scritto nulla, si usa quello che c'è già */
$valore = function($chiave, $ripiego = null) use ($S, $Scor) {
  if (isset($S[$chiave]) && $S[$chiave] !== '' && $S[$chiave] !== []) return $S[$chiave];
  if (isset($Scor[$chiave]) && $Scor[$chiave] !== '' && $Scor[$chiave] !== []) return $Scor[$chiave];
  return $ripiego;
};
$titoliHot = array_values(array_filter(array_map(function ($h) { return $h['tit']; }, $hot)));

$numero   = (int)$valore('numero', 0);
$diQuante = (int)$valore('di', 0);
$apertura = $valore('prima', isset($did['prima']) ? $did['prima'] : '');
$trova    = (array)$valore('trova', array_slice($titoliHot, 0, 6));
$distr    = (array)$valore('distrattori', []);
$fasi     = (array)$valore('fasi', []);
$glossar  = (array)$valore('glossario', isset($did['parole_chiave']) ? $did['parole_chiave'] : []);
$territ   = $valore('territorio', '');
$capacita = (array)$valore('capacita', ['Forza fisica', 'Pazienza', 'Precisione',
                                        'Conoscere il meteo', 'Lavoro di squadra', 'Creatività']);
$intervis = (array)$valore('intervista', []);
$disegno  = $valore('disegno', '');
$veroFals = (array)$valore('vero_falso', []);
$autoval  = (array)$valore('autovalutazione', [
  'So spiegare le fasi di questo mestiere',
  'Conosco almeno tre parole del mestiere',
  'Ho lavorato bene con la mia squadra']);
$A        = isset($S['adattata']) && is_array($S['adattata']) ? $S['adattata'] : [];

$titoloLez  = isset($L['tit']) ? $L['tit'] : 'Lezione';
$titoloCor  = isset($L['corso']['tit']) ? $L['corso']['tit'] : '';
$brandTit   = isset($CLI['brand']['titolo']) ? $CLI['brand']['titolo'] : (isset($CLI['nome']) ? $CLI['nome'] : '');
$istituto   = isset($_GET['scuola']) ? substr(preg_replace('/[^\p{L}\p{N} «»\'\.\-]/u', '', $_GET['scuola']), 0, 70) : '';
$annoScol   = (int)date('n') >= 9 ? date('Y') . '/' . (date('Y') + 1) : (date('Y') - 1) . '/' . date('Y');

function e($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
/* icone disegnate, non emoji: in stampa restano nere e nitide */
function ico($n, $w = 26) {
  $d = [
    'video'   => '<circle cx="26" cy="26" r="21" fill="none" stroke="#111" stroke-width="4"/><path d="M21 17l16 9-16 9z" fill="#111"/>',
    'ordina'  => '<rect x="8" y="9" width="36" height="9" rx="2" fill="#111"/><rect x="8" y="22" width="36" height="9" rx="2" fill="#999"/><rect x="8" y="35" width="36" height="9" rx="2" fill="#111"/>',
    'collega' => '<circle cx="13" cy="26" r="6" fill="#111"/><circle cx="39" cy="26" r="6" fill="#111"/><path d="M19 26h14" stroke="#111" stroke-width="4"/>',
    'disegna' => '<path d="M10 42l4-11L34 11l8 8-20 20z" fill="none" stroke="#111" stroke-width="4" stroke-linejoin="round"/><path d="M30 15l8 8" stroke="#111" stroke-width="4"/>',
    'sino'    => '<path d="M8 27l8 8 14-16" fill="none" stroke="#111" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M34 18l12 12M46 18L34 30" stroke="#111" stroke-width="5" stroke-linecap="round"/>',
    'consegna'=> '<path d="M9 20h34v22H9z" fill="none" stroke="#111" stroke-width="4"/><path d="M9 20l17 12 17-12" fill="none" stroke="#111" stroke-width="4"/>',
    'forbici' => '<circle cx="14" cy="38" r="7" fill="none" stroke="#111" stroke-width="4"/><circle cx="38" cy="38" r="7" fill="none" stroke="#111" stroke-width="4"/><path d="M19 33L40 9M33 33L12 9" stroke="#111" stroke-width="4" stroke-linecap="round"/>',
    'colla'   => '<path d="M20 8h12v10l6 8v18H14V26l6-8z" fill="none" stroke="#111" stroke-width="4" stroke-linejoin="round"/>',
    'mano'    => '<path d="M20 44V22a4 4 0 118 0V10a4 4 0 118 0v26c0 5-4 8-9 8z" fill="none" stroke="#111" stroke-width="4" stroke-linejoin="round"/>',
    'pausa'   => '<rect x="15" y="12" width="8" height="28" rx="2" fill="#111"/><rect x="29" y="12" width="8" height="28" rx="2" fill="#111"/>',
    'occhio'  => '<path d="M4 26s9-13 22-13 22 13 22 13-9 13-22 13S4 26 4 26z" fill="none" stroke="#111" stroke-width="4"/><circle cx="26" cy="26" r="6" fill="#111"/>',
    'fatto'   => '<path d="M11 28l10 10 20-24" fill="none" stroke="#111" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>',
  ];
  if (!isset($d[$n])) return '';
  return '<svg class="ico" width="' . $w . '" height="' . $w . '" viewBox="0 0 52 52" aria-hidden="true">' . $d[$n] . '</svg>';
}
function faccia($tipo, $w = 48) {
  $b = '<circle cx="26" cy="26" r="22" fill="none" stroke="#111" stroke-width="3"/><circle cx="18" cy="21" r="3" fill="#111"/><circle cx="34" cy="21" r="3" fill="#111"/>';
  $m = ['bene' => '<path d="M15 32c4 6 18 6 22 0" fill="none" stroke="#111" stroke-width="3" stroke-linecap="round"/>',
        'cosi' => '<path d="M16 34h20" stroke="#111" stroke-width="3" stroke-linecap="round"/>',
        'male' => '<path d="M15 37c4-6 18-6 22 0" fill="none" stroke="#111" stroke-width="3" stroke-linecap="round"/>'];
  return '<svg width="' . $w . '" height="' . $w . '" viewBox="0 0 52 52" aria-hidden="true">' . $b . $m[$tipo] . '</svg>';
}
/* riquadro per una foto: se in regia non c'è, resta uno spazio da riempire a mano */
function riquadroFoto($url, $etichetta, $h = 150) {
  $vuoto = '<span>Incolla qui un fotogramma:<br><b>' . e($etichetta) . '</b></span>';
  if (!$url) return '<div class="foto vuota" style="height:' . $h . 'px">' . $vuoto . '</div>';
  /* se la foto non si carica (rete di scuola lenta, file spostato) la scheda non deve
     stampare un'immagine rotta: diventa il riquadro da riempire a mano */
  return '<div class="foto" style="height:' . $h . 'px"><img src="' . e($url) . '" alt="' . e($etichetta) . '"'
       . ' onerror="this.parentNode.className=\'foto vuota\';this.parentNode.innerHTML=' . e(json_encode($vuoto)) . '"></div>';
}
/* mescola in modo stabile: la stessa scheda esce sempre uguale (ristampe identiche) */
function mescola_stabile(array $a, $seme) {
  $n = count($a); if ($n < 2) return $a;
  $s = crc32($seme);
  for ($i = $n - 1; $i > 0; $i--) { $s = ($s * 1103515245 + 12345) & 0x7fffffff; $j = $s % ($i + 1);
    $t = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $t; }
  return $a;
}
$mancanti = [];
if (!$apertura) $mancanti[] = 'la domanda di apertura';
if (!$trova)    $mancanti[] = 'le cose da cercare nel video (bastano i punti che brillano nella lezione)';
if (!$fasi)     $mancanti[] = 'le fasi del lavoro';
if (!$glossar)  $mancanti[] = 'le parole del mestiere';
?><!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title><?php echo e(($TIPO === 'adattata' ? 'Scheda adattata · ' : 'Scheda · ') . $titoloLez); ?></title>
<style>
  :root{ --ink:#1a1512; --linea:#999; --tenue:#666; }
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;background:#e9e4dc;color:var(--ink);
    font-family:"Segoe UI",system-ui,-apple-system,Roboto,sans-serif;font-size:11pt;line-height:1.45}
  .barra{position:sticky;top:0;z-index:9;background:#2b2118;color:#fff;padding:10px 16px;display:flex;
    gap:10px;align-items:center;flex-wrap:wrap;font-size:14px}
  .barra b{font-size:15px}
  .barra a,.barra button{font:inherit;cursor:pointer;border:0;border-radius:999px;padding:8px 16px;
    background:#f0e6d6;color:#2b2118;text-decoration:none;font-weight:700}
  .barra a.on{background:#d6336c;color:#fff}
  .barra .sp{margin-left:auto;opacity:.8;font-weight:400;font-size:13px}
  .avviso{background:#fff4d6;border-left:5px solid #b8860b;padding:12px 16px;margin:16px auto;max-width:210mm;font-size:13px}
  .foglio{width:210mm;min-height:297mm;background:#fff;margin:16px auto;padding:14mm 14mm 12mm;
    box-shadow:0 2px 10px rgba(0,0,0,.18);position:relative}
  h1{font-size:19pt;margin:0 0 2px}
  .sotto{color:var(--tenue);font-size:10pt;margin:0 0 10px}
  h2{font-size:12.5pt;margin:9px 0 3px;padding-bottom:2px;border-bottom:1.5px solid var(--ink)}
  h2 .n{display:inline-block;min-width:1.5em}
  .ist{font-size:9.5pt;color:var(--tenue);margin:0 0 4px}
  .testata{display:flex;justify-content:space-between;align-items:flex-start;border:1.5px solid var(--ink);
    padding:6px 10px;font-size:9pt;text-transform:uppercase;letter-spacing:.03em;margin-bottom:10px}
  .anagrafe{display:flex;gap:14px;font-size:10.5pt;margin:0 0 12px}
  .anagrafe div{flex:1;border-bottom:1px solid var(--ink);padding-bottom:3px}
  .righe{border-bottom:1px solid var(--linea);height:18px;margin:4px 0}
  .caselle{display:grid;grid-template-columns:1fr 1fr;gap:3px 18px;margin:5px 0}
  .cas{display:flex;gap:7px;align-items:flex-start;font-size:11pt}
  .q{display:inline-block;width:14px;height:14px;border:1.5px solid var(--ink);flex:0 0 auto;margin-top:2px}
  table{border-collapse:collapse;width:100%;font-size:10.5pt}
  td,th{border:1px solid var(--ink);padding:5px 8px;vertical-align:top}
  th{background:#f2ece2;text-align:left;font-size:9.5pt;text-transform:uppercase;letter-spacing:.03em}
  .num{width:34px;text-align:center;font-weight:700}
  .vuoto{height:22px}
  
  
  .disegno{border:1.5px dashed var(--ink);height:24mm;border-radius:4px;margin-top:6px}
  .pallini{text-align:center;font-size:13pt;letter-spacing:.4em}
  .foglio{display:flex;flex-direction:column}
  .piede{margin-top:auto;padding-top:5px;border-top:1px solid var(--linea);
    font-size:8pt;color:var(--tenue);display:flex;justify-content:space-between}
  .ico{vertical-align:middle}
  .foto{border:1.5px solid var(--ink);border-radius:4px;overflow:hidden;display:flex;align-items:center;justify-content:center;background:#f7f4ef}
  .foto img{width:100%;height:100%;object-fit:cover;display:block}
  .foto.vuota{border-style:dashed;color:var(--tenue);font-size:9.5pt;text-align:center;padding:8px}

  /* ---- versione adattata: una attività per pagina, caratteri grandi ---- */
  .ad{font-size:15pt;line-height:1.5}
  .ad h1{font-size:26pt;margin:0 0 6px}
  .ad .cap{display:flex;align-items:center;gap:12px;border:2.5px solid var(--ink);border-radius:10px;
    padding:10px 14px;margin-bottom:16px;font-size:17pt;font-weight:700}
  .ad .cap .passo{margin-left:auto;font-size:12pt;font-weight:400;color:var(--tenue)}
  .ad .istr{font-size:15pt;margin:0 0 14px}
  .ad table{font-size:15pt}
  .ad td,.ad th{padding:10px 12px}
  .ad .qq{display:inline-block;width:22px;height:22px;border:2.5px solid var(--ink);flex:0 0 auto}
  .ad .fine{border:2.5px solid #2f7d32;border-radius:10px;padding:10px 14px;margin-top:18px;
    font-size:14pt;display:flex;gap:10px;align-items:center}
  .agenda td{font-size:16pt}
  .agenda .ck{width:84px;text-align:center}
  .tessera{border:2.5px dashed var(--ink);border-radius:8px;padding:12px 16px;margin:14px 0;font-size:15pt;
    display:flex;gap:12px;align-items:center;min-height:76px}
  .carta{border:3px solid var(--ink);border-radius:12px;padding:14px 18px;text-align:center;font-size:22pt;
    font-weight:800;letter-spacing:.04em}
  .duecol{display:grid;grid-template-columns:1fr 1fr;gap:16px}
  .collega{display:grid;grid-template-columns:1fr 54px 1fr;align-items:center;gap:12px;margin:18px 0}
  .collega .p{border:2.5px solid var(--ink);border-radius:8px;padding:10px;text-align:center;font-weight:700;font-size:16pt}
  .punto{width:14px;height:14px;border-radius:50%;background:#111;margin:auto}

  table,.disegno,.collega,.tessera,.carta{break-inside:avoid;page-break-inside:avoid}
  table.finale{break-inside:auto;page-break-inside:auto}
  table.finale tr{break-inside:avoid;page-break-inside:avoid}
  h2{break-after:avoid;page-break-after:avoid}
  @media print{
    html,body{background:#fff}
    .barra,.avviso{display:none !important}
    .foglio{width:auto;min-height:0;margin:0;padding:0;box-shadow:none;page-break-after:always}
    .foglio:last-child{page-break-after:auto}
    @page{size:A4;margin:14mm 14mm 16mm}
  }
</style>
</head>
<body>

<div class="barra">
  <b>Scheda da stampare</b>
  <a class="<?php echo $TIPO === 'standard' ? 'on' : ''; ?>" href="?c=<?php echo e($C); ?>&lez=<?php echo e($LEZ); ?>&tipo=standard&liv=<?php echo e($LIV); ?>">Standard</a>
  <a class="<?php echo $TIPO === 'adattata' ? 'on' : ''; ?>" href="?c=<?php echo e($C); ?>&lez=<?php echo e($LEZ); ?>&tipo=adattata&liv=<?php echo e($LIV); ?>">Adattata (autismo)</a>
  <a class="<?php echo $LIV === 'junior' ? 'on' : ''; ?>" href="?c=<?php echo e($C); ?>&lez=<?php echo e($LEZ); ?>&tipo=<?php echo e($TIPO); ?>&liv=junior">Primaria</a>
  <a class="<?php echo $LIV === 'senior' ? 'on' : ''; ?>" href="?c=<?php echo e($C); ?>&lez=<?php echo e($LEZ); ?>&tipo=<?php echo e($TIPO); ?>&liv=senior">Medie</a>
  <button onclick="window.print()">🖨️ Stampa</button>
  <span class="sp">Stampa su A4, fronte e retro se vuoi risparmiare carta</span>
</div>

<?php if ($mancanti): ?>
<div class="avviso">
  <b>Questa scheda è incompleta.</b> In regia, nell’editor della lezione, manca ancora:
  <?php echo e(implode('; ', $mancanti)); ?>. Le parti mancanti non vengono stampate.
</div>
<?php endif; ?>

<?php if ($TIPO === 'standard'): /* ===================== SCHEDA STANDARD ===================== */ ?>

<div class="foglio">
  <div class="testata">
    <div><b><?php echo e(mb_strtoupper($titoloCor ?: $brandTit)); ?></b><br>
      <?php echo e(($istituto ? $istituto . ' · ' : '') . 'a.s. ' . $annoScol); ?></div>
    <div style="text-align:right">Scheda alunno<?php echo $numero ? ' n. ' . $numero . ($diQuante ? ' di ' . $diQuante : '') : ''; ?><br>
      <?php echo $LIV === 'senior' ? 'secondaria di primo grado' : 'scuola primaria'; ?></div>
  </div>

  <h1><?php echo e($titoloLez); ?></h1>
  <p class="sotto"><?php echo e(isset($L['sub']) && $L['sub'] ? $L['sub'] : $titoloCor); ?></p>

  <div class="anagrafe">
    <div>Nome e cognome</div><div style="flex:0 0 22%">Classe</div><div style="flex:0 0 28%">Data ____ / ____ / ________</div>
  </div>

  <?php if ($apertura): ?>
  <h2><span class="n">1</span> Prima di entrare</h2>
  <p class="ist">Da compilare all’inizio dell’incontro, prima del video.</p>
  <p style="margin:0 0 4px"><?php echo e($apertura); ?></p>
  <div class="righe"></div><div class="righe"></div>
  <?php endif; ?>

  <?php if ($trova): $tutte = mescola_stabile(array_merge(array_values($trova), array_values($distr)), $LEZ . 'trova'); ?>
  <h2><span class="n">2</span> Dentro il luogo di lavoro</h2>
  <p class="ist">Durante il video 360°: ruota la scena e segna con una ✓ ogni cosa che trovi.<?php echo $distr ? ' Attenzione: una o più non ci sono!' : ''; ?></p>
  <div class="caselle">
    <?php foreach ($tutte as $t): ?><div class="cas"><span class="q"></span><span><?php echo e($t); ?></span></div><?php endforeach; ?>
  </div>
  <?php endif; ?>

  <?php if (count($fasi) > 1): $ord = mescola_stabile(array_values($fasi), $LEZ . 'fasi'); ?>
  <h2><span class="n">3</span> Le fasi del lavoro</h2>
  <p class="ist">Le fasi sono in disordine: scrivi nel quadratino il numero giusto, da 1 a <?php echo count($fasi); ?>.</p>
  <table>
    <?php foreach ($ord as $f): ?><tr><td class="num">&nbsp;</td><td><?php echo e($f); ?></td></tr><?php endforeach; ?>
  </table>
  <?php endif; ?>

  <?php if ($glossar): ?>
  <h2><span class="n">4</span> Le parole del mestiere</h2>
  <p class="ist">Scrivi con parole tue che cosa significano.</p>
  <table>
    <tr><th style="width:34%">Parola</th><th>Che cosa significa</th></tr>
    <?php foreach (array_slice($glossar, 0, 6) as $g): $par = is_array($g) ? (isset($g['parola']) ? $g['parola'] : '') : $g; ?>
    <tr><td><b><?php echo e($par); ?></b></td><td class="vuoto"></td></tr>
    <?php endforeach; ?>
  </table>
  <?php endif; ?>

  <div class="piede"><span><?php echo e($brandTit); ?> · <?php echo e($titoloLez); ?></span><span>pagina 1 di 2</span></div>
</div>

<div class="foglio">
  <?php if ($territ): ?>
  <h2><span class="n">5</span> Il mestiere e il territorio</h2>
  <p style="margin:0 0 4px"><?php echo e($territ); ?></p>
  <div class="righe"></div><div class="righe"></div>
  <?php endif; ?>

  <h2><span class="n">6</span> La carta del mestiere</h2>
  <p class="ist">Quali capacità servono per fare questo lavoro? Segna le tre più importanti.</p>
  <div class="caselle" style="grid-template-columns:1fr 1fr 1fr">
    <?php foreach (array_slice($capacita, 0, 6) as $c): ?><div class="cas"><span class="q"></span><span><?php echo e($c); ?></span></div><?php endforeach; ?>
  </div>
  <p style="margin:10px 0 4px">Ti piacerebbe fare questo mestiere? Perché?</p>
  <div class="righe"></div><div class="righe"></div>

  <?php if ($intervis): ?>
  <h2><span class="n">7</span> Intervista a casa</h2>
  <p class="ist">Fai queste domande a un nonno, a un genitore o a un artigiano. Scrivi le risposte e portale in classe.</p>
  <?php foreach (array_slice($intervis, 0, 3) as $i => $d): ?>
    <p style="margin:8px 0 2px"><b><?php echo ($i + 1); ?>. <?php echo e($d); ?></b></p>
    <div class="righe"></div>
  <?php endforeach; ?>
  <?php endif; ?>

  <?php if ($disegno): ?>
  <h2><span class="n">8</span> Disegna</h2>
  <p class="ist">Disegna <?php echo e($disegno); ?>, e scrivi a cosa serve.</p>
  <div class="disegno"></div>
  <?php endif; ?>

  <h2><span class="n">9</span> Come è andata?</h2>
  <p class="ist">Colora il pallino che ti somiglia di più.</p>
  <table class="finale">
    <tr><th></th><th style="width:70px;text-align:center">Sì</th><th style="width:100px;text-align:center">Abbastanza</th><th style="width:100px;text-align:center">Non ancora</th></tr>
    <?php foreach (array_slice($autoval, 0, 4) as $r): ?>
    <tr><td><?php echo e($r); ?></td><td class="pallini">○</td><td class="pallini">○</td><td class="pallini">○</td></tr>
    <?php endforeach; ?>
  </table>

  <div class="piede"><span><?php echo e($brandTit); ?> · <?php echo e($titoloLez); ?></span><span>pagina 2 di 2</span></div>
</div>

<?php else: /* ===================== SCHEDA ADATTATA ===================== */
  $trova4 = array_slice((array)(isset($A['trova4']) && $A['trova4'] ? $A['trova4'] : $trova), 0, 4);
  $fasi3  = array_slice((array)(isset($A['fasi3'])  && $A['fasi3']  ? $A['fasi3']  : $fasi),  0, 3);
  $parole3 = [];
  foreach (array_slice((array)(isset($A['parole']) && $A['parole'] ? $A['parole'] : $glossar), 0, 3) as $g) {
    $parole3[] = is_array($g) ? (isset($g['parola']) ? $g['parola'] : '') : $g;
  }
  $vf = array_slice($veroFals, 0, 4);
  $fotoDi = function ($nome) use ($hot) {           /* la foto del punto che si chiama così */
    foreach ($hot as $h) { if ($h['tit'] && mb_stripos($nome, $h['tit']) !== false) return $h['foto']; }
    foreach ($hot as $h) { if ($h['tit'] && mb_stripos($h['tit'], $nome) !== false) return $h['foto']; }
    return '';
  };
  $att = [];
  if ($trova4)  $att[] = ['video',   'Guardo il video'];
  if ($fasi3)   $att[] = ['ordina',  'Metto in ordine'];
  if ($parole3) $att[] = ['collega', 'Collego le parole'];
  if ($disegno) $att[] = ['disegna', 'Disegno'];
  if ($vf)      $att[] = ['sino',    'Sì o no'];
  $nAtt = count($att);
?>

<!-- pagina per l'insegnante -->
<div class="foglio">
  <h1 style="font-size:15pt">Per l’insegnante · non consegnare all’alunno</h1>
  <p class="sotto">Scheda adattata «<?php echo e($titoloLez); ?>» · <?php echo e($titoloCor); ?></p>
  <p>È pensata per un alunno con disturbo dello spettro autistico che richiede un supporto sostanziale.
     Ogni profilo è diverso: va adattata insieme al docente di sostegno e alla famiglia, in coerenza con il PEI.</p>
  <p><b>Struttura.</b> Segue l’insegnamento strutturato: l’agenda dice che cosa fare, quanto lavoro c’è
     (<?php echo $nAtt; ?> attività), quando ha finito e che cosa viene dopo. C’è una sola attività per pagina,
     le frasi sono brevi e letterali, e ogni azione ha sempre la stessa icona.</p>
  <p><b>Prima dell’incontro.</b> Mostra all’alunno l’agenda il giorno prima o a inizio lezione. Avvisalo che il
     video si muove e ha dei suoni.</p>
  <p><b>Durante il video 360°.</b> Volume moderato, cuffie se è sensibile ai rumori, posto fisso non troppo vicino
     alla LIM. Dagli solo la pagina dell’attività 1 e tieni le altre girate.</p>
  <p><b>Ritaglio.</b> Le tessere sono nelle ultime pagine. Se ritagliare è faticoso, ritagliale tu prima.
     Si possono plastificare e usare con il velcro per riutilizzarle.</p>
  <p><b>Aiuto e pausa.</b> Ritaglia le carte AIUTO e PAUSA e lasciale sul banco. Mostrare la carta vale come
     richiesta: rispondi sempre.</p>
  <p><b>Fai vedere prima.</b> Esegui tu il primo esempio di ogni attività, poi lascia fare a lui riducendo gli
     aiuti un poco alla volta.</p>
  <p><b>Immagini.</b> Dove manca la foto c’è un riquadro tratteggiato: incolla un fotogramma della lezione.</p>
  <p><b>Rinforzo.</b> Lodi precise e subito («Hai messo in ordine le tre fasi»).</p>
  <p><b>Il ruolo nel quiz.</b> Ci sono due carte, una per ciascun modo di giocare: scegli al momento quella giusta
     e leggila con lui prima di iniziare. Il compito ha confini precisi e finisce quando dici «Fine del quiz».
     Se tende ad andare oltre, indica la carta senza aggiungere regole a voce.</p>
  <?php if ($vf): ?><p><b>Risposte dell’attività «Sì o no»:</b>
    <?php echo e(implode(' · ', array_map(function ($x) { return (!empty($x['v']) ? 'SÌ' : 'NO'); }, $vf))); ?>.</p><?php endif; ?>
  <p style="font-size:8.5pt;color:var(--tenue);margin-top:14px">Riferimenti: DSM-5 (livelli di supporto);
     Linee guida dell’Istituto Superiore di Sanità sull’autismo; programma TEACCH (insegnamento strutturato);
     pratiche basate sull’evidenza (supporti visivi, modeling, analisi del compito).</p>
  <div class="piede"><span>Per l’insegnante</span><span><?php echo e($brandTit); ?></span></div>
</div>

<!-- agenda -->
<div class="foglio ad">
  <p style="font-size:15pt;margin:0">Oggi</p>
  <h1><?php echo e($titoloLez); ?></h1>
  <p style="font-size:15pt">Nome: ______________________</p>
  <h2 style="font-size:18pt;border:0;margin-top:18px">Le mie <?php echo $nAtt; ?> attività</h2>
  <table class="agenda">
    <?php foreach ($att as $i => $a): ?>
    <tr><td class="num" style="width:46px"><?php echo $i + 1; ?></td>
        <td style="width:60px"><?php echo ico($a[0], 34); ?></td>
        <td><?php echo e($a[1]); ?></td>
        <td class="ck"><span class="qq"></span> fatto</td></tr>
    <?php endforeach; ?>
    <tr><td class="num"></td><td><?php echo ico('consegna', 34); ?></td>
        <td>Consegno la scheda</td><td class="ck"><span class="qq"></span> fatto</td></tr>
  </table>
  <h2 style="font-size:17pt;border:0;margin-top:22px">Se ho bisogno:</h2>
  <table><tr>
    <td style="width:60px"><?php echo ico('mano', 34); ?></td><td>mostro la carta <b>AIUTO</b></td>
    <td style="width:60px"><?php echo ico('pausa', 34); ?></td><td>mostro la carta <b>PAUSA</b></td>
  </tr></table>
  <div class="piede"><span><?php echo e($titoloLez); ?></span><span>agenda</span></div>
</div>

<?php $p = 0; foreach ($att as $a): $p++; ?>
<div class="foglio ad">
  <div class="cap"><?php echo ico($a[0], 40); ?><span><?php echo e($a[1]); ?></span>
    <span class="passo">Attività <?php echo $p; ?> di <?php echo $nAtt; ?></span></div>

  <?php if ($a[0] === 'video'): ?>
    <p class="istr">Guarda il video. Cerca queste <?php echo count($trova4); ?> cose.
       Quando la vedi, fai una ✓ nel quadrato.</p>
    <table><?php foreach (array_chunk($trova4, 2) as $riga): ?><tr>
      <?php foreach ($riga as $t): ?><td><span class="qq"></span> <b><?php echo e(mb_strtoupper($t)); ?></b></td><?php endforeach; ?>
      <?php if (count($riga) === 1): ?><td></td><?php endif; ?>
    </tr><?php endforeach; ?></table>

  <?php elseif ($a[0] === 'ordina'): ?>
    <p class="istr">Ritaglia le <?php echo count($fasi3); ?> tessere dell’ultima pagina.<br>
       Incolla le tessere in ordine: 1, poi 2, poi 3.</p>
    <table>
      <?php $et = ['Prima', 'Poi', 'Alla fine']; foreach ($fasi3 as $i => $f): ?>
      <tr><td class="num" style="width:50px"><?php echo $i + 1; ?></td>
          <td style="width:120px"><?php echo e(isset($et[$i]) ? $et[$i] : ''); ?></td>
          <td style="height:72px"></td></tr>
      <?php endforeach; ?>
    </table>

  <?php elseif ($a[0] === 'collega'): ?>
    <p class="istr">Unisci con una linea la parola alla sua immagine.</p>
    <?php foreach ($parole3 as $par): ?>
    <div class="collega">
      <div class="p"><?php echo e(mb_strtoupper($par)); ?></div>
      <div><div class="punto"></div></div>
      <?php echo riquadroFoto($fotoDi($par), $par, 118); ?>
    </div>
    <?php endforeach; ?>

  <?php elseif ($a[0] === 'disegna'): ?>
    <p class="istr">Guarda la foto. Disegna <?php echo e($disegno); ?> nel riquadro.</p>
    <div class="duecol">
      <?php echo riquadroFoto($fotoDi($disegno), $disegno, 170); ?>
      <div class="disegno" style="height:170px;margin:0"></div>
    </div>

  <?php else: ?>
    <p class="istr">Leggi la frase. Colora SÌ oppure NO.</p>
    <table>
      <?php foreach ($vf as $x): ?>
      <tr><td><?php echo e(isset($x['f']) ? $x['f'] : ''); ?></td>
          <td style="width:90px;text-align:center"><b>SÌ</b></td>
          <td style="width:90px;text-align:center"><b>NO</b></td></tr>
      <?php endforeach; ?>
    </table>
  <?php endif; ?>

  <div class="fine"><?php echo ico('fatto', 28); ?>
    <span><?php echo $p < $nAtt
      ? 'Finito? Fai una ✓ nell’agenda e vai all’attività ' . ($p + 1) . '.'
      : 'Finito? Fai una ✓ nell’agenda. Consegna la scheda all’insegnante. Bravo!'; ?></span></div>
  <div class="piede"><span><?php echo e($titoloLez); ?></span><span>attività <?php echo $p; ?> di <?php echo $nAtt; ?></span></div>
</div>
<?php endforeach; ?>

<!-- autovalutazione -->
<div class="foglio ad">
  <h1 style="font-size:20pt">Come è andata?</h1>
  <p class="istr">Colora una faccia.</p>
  <table><tr>
    <td style="text-align:center"><?php echo faccia('bene', 64); ?><br><b>Bene</b></td>
    <td style="text-align:center"><?php echo faccia('cosi', 64); ?><br><b>Così così</b></td>
    <td style="text-align:center"><?php echo faccia('male', 64); ?><br><b>Difficile</b></td>
  </tr></table>
  <div class="piede"><span><?php echo e($titoloLez); ?></span><span>come è andata</span></div>
</div>

<!-- tessere e carte da ritagliare -->
<div class="foglio ad">
  <div class="cap"><?php echo ico('forbici', 36); ?><span>Tessere da ritagliare</span></div>
  <?php foreach ($fasi3 as $f): ?>
  <div class="tessera"><?php echo ico('colla', 28); ?><span><?php echo e($f); ?></span></div>
  <?php endforeach; ?>

  <div class="duecol" style="margin-top:24px">
    <div class="carta"><?php echo ico('mano', 40); ?><br>AIUTO</div>
    <div class="carta"><?php echo ico('pausa', 40); ?><br>PAUSA</div>
  </div>
  <div class="piede"><span><?php echo e($titoloLez); ?></span><span>da ritagliare</span></div>
</div>

<!-- carte del ruolo nel quiz: una per modo di giocare, si sceglie al momento -->
<div class="foglio ad">
  <div class="cap"><?php echo ico('forbici', 36); ?><span>Il mio compito nel quiz</span>
    <span class="passo">ritaglia quella che serve oggi</span></div>
  <p class="istr">L’insegnante sceglie al momento come si gioca. Le due carte dicono la stessa cosa in due modi
     diversi: tieni sul banco solo quella del quiz di oggi.</p>

  <div style="border:3px solid var(--ink);border-radius:12px;padding:16px 20px;margin-bottom:18px">
    <p style="margin:0 0 6px;font-size:12pt;color:var(--tenue);text-transform:uppercase;letter-spacing:.05em">
      Se il quiz si gioca <b>sulla LIM, tutti insieme</b></p>
    <p style="margin:0;font-size:17pt"><b>Il mio compito</b><br>
      Io premo il pulsante della risposta sulla LIM.<br>
      Premo quando l’insegnante dice «Vai».<br>
      Premo una volta sola. Poi torno al posto.<br>
      Il mio compito finisce quando l’insegnante dice: «Fine del quiz».</p>
  </div>

  <div style="border:3px solid var(--ink);border-radius:12px;padding:16px 20px">
    <p style="margin:0 0 6px;font-size:12pt;color:var(--tenue);text-transform:uppercase;letter-spacing:.05em">
      Se il quiz si gioca <b>con i telefoni</b></p>
    <p style="margin:0;font-size:17pt"><b>Il mio compito</b><br>
      Io tocco la risposta sul mio schermo.<br>
      Tocco quando l’insegnante dice «Vai».<br>
      Tocco una volta sola. Poi appoggio il telefono sul banco.<br>
      Il mio compito finisce quando l’insegnante dice: «Fine del quiz».</p>
  </div>
  <div class="piede"><span><?php echo e($titoloLez); ?></span><span>carta del ruolo</span></div>
</div>

<?php endif; ?>
</body>
</html>
