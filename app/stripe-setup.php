<?php
/* ESPLORA TRAPANI EDU — stripe-setup.php · v1.0 (24/09/2026)
   Da eseguire UNA volta per ambiente (test, poi live): crea su Stripe i 3 prodotti
   (Base, Pro, Premium) con 2 prezzi ciascuno (mese/anno, IVA inclusa) e stampa le
   righe STRIPE_PRICES da incollare in dati/config.php. Protetto dalla chiave di
   diagnostica: stripe-setup.php?k=<EDU_DIAG_KEY>. Idempotente: se un prodotto con lo
   stesso nome esiste già, riusa quello e i suoi prezzi con lo stesso importo/periodo.
   Cancella il file dal server quando hai finito. */
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';
header('Content-Type: text/plain; charset=utf-8');
if (empty($EDU_DIAG_KEY) || ($_GET['k'] ?? '') !== $EDU_DIAG_KEY) { http_response_code(403); exit("chiave mancante o errata\n"); }
if (empty($STRIPE_SECRET)) exit("STRIPE_SECRET vuota in dati/config.php\n");
$STRIPE_API = $STRIPE_API ?? 'https://api.stripe.com';

/* importi in centesimi (IVA inclusa). L'annuale di serie = 10 mensilità (2 mesi gratis): cambia qui se vuoi. */
$PIANI = $STRIPE_SETUP_PIANI ?? [
  'base'    => ['nome' => 'Esplora Trapani Edu · Base',    'mese' => 5000,  'anno' => 50000],
  'pro'     => ['nome' => 'Esplora Trapani Edu · Pro',     'mese' => 10000, 'anno' => 100000],
  'premium' => ['nome' => 'Esplora Trapani Edu · Premium', 'mese' => 20000, 'anno' => 200000],
];

function stripe($method, $path, $params = []){
  global $STRIPE_SECRET, $STRIPE_API;
  $ch = curl_init($STRIPE_API . $path . ($method === 'GET' && $params ? '?' . http_build_query($params) : ''));
  $h = ['Authorization: Bearer ' . $STRIPE_SECRET, 'Stripe-Version: 2024-06-20'];
  if ($method !== 'GET') { $h[] = 'Content-Type: application/x-www-form-urlencoded'; curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($params)); }
  curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CUSTOMREQUEST => $method, CURLOPT_HTTPHEADER => $h, CURLOPT_TIMEOUT => 25]);
  $raw = curl_exec($ch); $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
  $j = json_decode($raw, true) ?: [];
  if ($code < 200 || $code >= 300) exit("Stripe ha risposto $code: " . ($j['error']['message'] ?? $raw) . "\n");
  return $j;
}

echo "=== Esplora Trapani Edu · setup Stripe (" . (strpos($STRIPE_SECRET, 'sk_test') === 0 ? 'TEST' : 'LIVE') . ") ===\n\n";
$out = [];
foreach ($PIANI as $piano => $p) {
  /* prodotto: riuso se esiste già con lo stesso nome */
  $prod = null;
  $lista = stripe('GET', '/v1/products', ['active' => 'true', 'limit' => 100]);
  foreach ($lista['data'] ?? [] as $x) if (($x['name'] ?? '') === $p['nome']) { $prod = $x; break; }
  if (!$prod) $prod = stripe('POST', '/v1/products', ['name' => $p['nome'], 'metadata[piano]' => $piano, 'description' => 'Licenza annuale o mensile della piattaforma educativa. Prezzi IVA inclusa.']);
  echo $p['nome'] . " → " . $prod['id'] . "\n";
  $out[$piano] = [];
  foreach (['mese' => 'month', 'anno' => 'year'] as $periodo => $intervallo) {
    $price = null;
    $prezzi = stripe('GET', '/v1/prices', ['product' => $prod['id'], 'active' => 'true', 'limit' => 100]);
    foreach ($prezzi['data'] ?? [] as $x)
      if (($x['unit_amount'] ?? 0) == $p[$periodo] && ($x['recurring']['interval'] ?? '') === $intervallo && ($x['currency'] ?? '') === 'eur') { $price = $x; break; }
    if (!$price) $price = stripe('POST', '/v1/prices', ['product' => $prod['id'], 'currency' => 'eur', 'unit_amount' => $p[$periodo],
      'recurring[interval]' => $intervallo, 'tax_behavior' => 'inclusive', 'nickname' => $piano . ' · ' . $periodo . ' · IVA inclusa',
      'metadata[piano]' => $piano, 'metadata[periodo]' => $periodo]);
    $out[$piano][$periodo] = $price['id'];
    echo "   " . str_pad($periodo, 5) . " " . number_format($p[$periodo] / 100, 2, ',', '.') . " € → " . $price['id'] . "\n";
  }
}
echo "\n=== Incolla in dati/config.php ===\n\$STRIPE_PRICES = [\n";
foreach ($out as $piano => $pp) echo "  '" . $piano . "' => ['mese' => '" . $pp['mese'] . "', 'anno' => '" . $pp['anno'] . "'],\n";
echo "];\n\nPoi: Developers → Webhooks → Add endpoint → https://www.alessandromilia.it/project/edu/app/stripe-webhook.php\n";
echo "eventi: invoice.paid, invoice.payment_failed, customer.subscription.created, customer.subscription.updated, customer.subscription.deleted, customer.subscription.paused, customer.subscription.resumed\n";
echo "e copia il Signing secret (whsec_…) in STRIPE_WEBHOOK_SECRET.\nSettings → Billing → Emails: attiva «Email finalized invoices to customers».\nCANCELLA questo file dal server a fine setup.\n";
