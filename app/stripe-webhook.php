<?php
/* ESPLORA TRAPANI EDU — stripe-webhook.php · v1.0 (24/09/2026)
   Riceve gli eventi di Stripe (Developers → Webhooks → endpoint
   https://www.alessandromilia.it/project/edu/app/stripe-webhook.php).
   Verifica la firma (HMAC-SHA256, header Stripe-Signature) con STRIPE_WEBHOOK_SECRET,
   estrae i campi che ci servono e chiama la RPC edu_abbonamento_evento con la
   chiave SERVICE. Idempotente: Stripe ritenta, il DB ignora gli eventi già visti.
   Eventi da abilitare: invoice.paid, invoice.payment_failed,
   customer.subscription.created/updated/deleted/paused/resumed */
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';
header('Content-Type: application/json');

function out($a, $code = 200){ http_response_code($code); echo json_encode($a); exit; }
if (empty($STRIPE_WEBHOOK_SECRET)) out(['ok' => false, 'err' => 'STRIPE_WEBHOOK_SECRET mancante'], 503);
if (empty($SUPA_SERVICE)) out(['ok' => false, 'err' => 'SUPA_SERVICE mancante'], 503);
$STRIPE_API = $STRIPE_API ?? 'https://api.stripe.com';

/* ---------- 1. firma ---------- */
$payload = file_get_contents('php://input');
$sig = $_SERVER['HTTP_STRIPE_SIGNATURE'] ?? '';
$t = null; $v1 = [];
foreach (explode(',', $sig) as $parte) {
  $kv = explode('=', trim($parte), 2); if (count($kv) !== 2) continue;
  if ($kv[0] === 't') $t = (int)$kv[1]; elseif ($kv[0] === 'v1') $v1[] = $kv[1];
}
if (!$t || !$v1) out(['ok' => false, 'err' => 'firma assente'], 400);
if (abs(time() - $t) > 300) out(['ok' => false, 'err' => 'firma scaduta'], 400);
$attesa = hash_hmac('sha256', $t . '.' . $payload, $STRIPE_WEBHOOK_SECRET);
$valida = false; foreach ($v1 as $s) if (hash_equals($attesa, $s)) $valida = true;
if (!$valida) out(['ok' => false, 'err' => 'firma non valida'], 400);

$ev = json_decode($payload, true);
if (!is_array($ev) || empty($ev['id']) || empty($ev['type'])) out(['ok' => false, 'err' => 'evento illeggibile'], 400);
$tipo = $ev['type']; $o = $ev['data']['object'] ?? [];

/* ---------- 2. estrazione dei campi ---------- */
$e = ['id' => $ev['id'], 'tipo' => $tipo];
function cliente_da_meta($o){ return $o['metadata']['cliente_id'] ?? ($o['subscription_details']['metadata']['cliente_id'] ?? null); }

if (strpos($tipo, 'invoice.') === 0) {
  $e['invoice'] = $o['id'] ?? null;
  $e['subscription'] = is_array($o['subscription'] ?? null) ? ($o['subscription']['id'] ?? null) : ($o['subscription'] ?? null);
  $e['customer'] = is_array($o['customer'] ?? null) ? ($o['customer']['id'] ?? null) : ($o['customer'] ?? null);
  $e['importo_cent'] = $o['amount_paid'] ?? ($o['amount_due'] ?? null);
  $e['valuta'] = $o['currency'] ?? null;
  $e['stato_invoice'] = $o['status'] ?? null;
  $e['link'] = $o['hosted_invoice_url'] ?? null;
  $riga = $o['lines']['data'][0] ?? [];
  if (!empty($riga['period']['start'])) $e['periodo_da'] = gmdate('c', $riga['period']['start']);
  if (!empty($riga['period']['end']))   $e['periodo_a']  = gmdate('c', $riga['period']['end']);
  $e['cliente_id'] = cliente_da_meta($o);
  if (!$e['cliente_id'] && !empty($riga['metadata']['cliente_id'])) $e['cliente_id'] = $riga['metadata']['cliente_id'];
} elseif (strpos($tipo, 'customer.subscription.') === 0) {
  $e['subscription'] = $o['id'] ?? null;
  $e['customer'] = is_array($o['customer'] ?? null) ? ($o['customer']['id'] ?? null) : ($o['customer'] ?? null);
  $e['stato_sub'] = $o['status'] ?? null;
  $e['pausa'] = !empty($o['pause_collection']);
  $e['cancel_at_period_end'] = !empty($o['cancel_at_period_end']);
  if (!empty($o['current_period_end'])) $e['periodo_a'] = gmdate('c', $o['current_period_end']);
  if (!empty($o['current_period_start'])) $e['periodo_da'] = gmdate('c', $o['current_period_start']);
  $e['cliente_id'] = $o['metadata']['cliente_id'] ?? null;
} else {
  out(['ok' => true, 'ignorato' => $tipo]);           /* evento non di nostro interesse: 200 e via */
}

/* ---------- 3. applicazione (RPC riservata alla chiave service) ---------- */
$ch = curl_init(rtrim($SUPA_URL, '/') . '/rest/v1/rpc/edu_abbonamento_evento');
curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true, CURLOPT_TIMEOUT => 20,
  CURLOPT_HTTPHEADER => ['apikey: ' . $SUPA_SERVICE, 'Authorization: Bearer ' . $SUPA_SERVICE, 'Content-Type: application/json'],
  CURLOPT_POSTFIELDS => json_encode(['p_evento' => $e])]);
$raw = curl_exec($ch); $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
$ris = json_decode($raw, true);
if ($code !== 200) out(['ok' => false, 'err' => 'db', 'code' => $code], 500);   /* 500 → Stripe ritenta */
if (is_array($ris) && ($ris['ok'] ?? false) === false && ($ris['err'] ?? '') === 'cliente non trovato')
  out(['ok' => false, 'err' => 'cliente non trovato'], 500);                    /* ritenterà: l'aggancio può arrivare dopo */
out(['ok' => true, 'tipo' => $tipo, 'esito' => $ris]);
