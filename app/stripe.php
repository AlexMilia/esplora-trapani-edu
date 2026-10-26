<?php
/* ESPLORA TRAPANI EDU — stripe.php · v1.0 (24/09/2026)
   Comandi del MANAGER (admin della regia) verso Stripe. Nessun SDK: REST diretta.
   Autenticazione: header Authorization: Bearer <access_token Supabase> → l'utente
   deve essere admin (edu_e_admin via RPC con il SUO token). Le scritture su
   edu_clienti avvengono con la chiave service (config), mai con quella dell'utente.

   Azioni (POST JSON):
     crea      { cliente_id, piano: base|pro|premium, periodo: mese|anno }
               → customer (se manca) + subscription in modalità "invia fattura":
                 È STRIPE a mandare l'email con il link di pagamento al referente.
     pausa     { cliente_id }            → pause_collection (nessun addebito, licenza sospesa)
     riprendi  { cliente_id }            → riattiva gli addebiti
     annulla   { cliente_id, quando: subito|fine_periodo }
     stato     { cliente_id }            → rilegge da Stripe e allinea il DB
     link      { cliente_id }            → l'URL della fattura aperta (per reinviare a mano)
*/
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function out($a, $code = 200){ http_response_code($code); echo json_encode($a, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); exit; }
function fail($msg, $code = 400){ out(['ok' => false, 'err' => $msg], $code); }

if (empty($STRIPE_SECRET))  fail('Stripe non configurato (STRIPE_SECRET in dati/config.php)', 503);
if (empty($SUPA_SERVICE))   fail('Manca SUPA_SERVICE in dati/config.php', 503);
$STRIPE_API = $STRIPE_API ?? 'https://api.stripe.com';
$SUPA_URL   = rtrim($SUPA_URL, '/');
$PREZZI     = $STRIPE_PRICES ?? [];
$GIORNI_SCADENZA_FATTURA = $STRIPE_GIORNI_FATTURA ?? 7;

/* ---------- HTTP helpers ---------- */
function http($method, $url, $headers, $body = null){
  $ch = curl_init($url);
  curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_CUSTOMREQUEST => $method, CURLOPT_TIMEOUT => 25,
                          CURLOPT_HTTPHEADER => $headers]);
  if ($body !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
  $raw = curl_exec($ch); $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); $err = curl_error($ch); curl_close($ch);
  if ($raw === false) return [0, ['error' => ['message' => $err]]];
  return [$code, json_decode($raw, true) ?: []];
}
/* Stripe: form-encoded, Basic auth con la secret key, idempotency key sulle creazioni */
function stripe($method, $path, $params = [], $idem = null){
  global $STRIPE_SECRET, $STRIPE_API;
  $h = ['Authorization: Bearer ' . $STRIPE_SECRET, 'Stripe-Version: 2024-06-20'];
  if ($idem) $h[] = 'Idempotency-Key: ' . $idem;
  $body = null; $url = $STRIPE_API . $path;
  if ($method === 'GET') { if ($params) $url .= '?' . http_build_query($params); }
  else { $h[] = 'Content-Type: application/x-www-form-urlencoded'; $body = http_build_query($params); }
  list($code, $j) = http($method, $url, $h, $body);
  if ($code < 200 || $code >= 300) fail('Stripe: ' . ($j['error']['message'] ?? ('HTTP ' . $code)), 502);
  return $j;
}
/* Supabase con la chiave SERVICE (scritture di sistema) */
function supa($method, $path, $body = null){
  global $SUPA_URL, $SUPA_SERVICE;
  $h = ['apikey: ' . $SUPA_SERVICE, 'Authorization: Bearer ' . $SUPA_SERVICE, 'Content-Type: application/json', 'Prefer: return=representation'];
  list($code, $j) = http($method, $SUPA_URL . $path, $h, $body === null ? null : json_encode($body));
  if ($code < 200 || $code >= 300) fail('Supabase: ' . ($j['message'] ?? ('HTTP ' . $code)), 502);
  return $j;
}

/* ---------- 1. chi chiama? deve essere un admin della regia ---------- */
$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
if (!preg_match('/^Bearer\s+(\S+)$/i', $auth, $m)) fail('Accesso negato: manca il token', 401);
$token = $m[1];
list($c1, $utente) = http('GET', $SUPA_URL . '/auth/v1/user', ['apikey: ' . $SUPA_ANON, 'Authorization: Bearer ' . $token]);
if ($c1 !== 200 || empty($utente['id'])) fail('Sessione non valida: rientra nella regia', 401);
list($c2, $isAdmin) = http('POST', $SUPA_URL . '/rest/v1/rpc/edu_e_admin',
  ['apikey: ' . $SUPA_ANON, 'Authorization: Bearer ' . $token, 'Content-Type: application/json'], '{}');
if ($c2 !== 200 || $isAdmin !== true) fail('Solo l\'amministratore può gestire gli abbonamenti', 403);

/* ---------- 2. input ---------- */
$B = json_decode(file_get_contents('php://input'), true) ?: [];
$azione = preg_replace('/[^a-z_]/', '', $_GET['azione'] ?? ($B['azione'] ?? ''));
$clienteId = preg_replace('/[^0-9a-f-]/', '', $B['cliente_id'] ?? '');
if ($clienteId === '') fail('cliente_id mancante');
$rows = supa('GET', '/rest/v1/edu_clienti?id=eq.' . $clienteId . '&select=id,slug,nome,contatto_nome,contatto_email,stripe_customer_id,stripe_subscription_id,abbonamento_stato,abbonamento_piano,abbonamento_periodo,abbonamento_link');
$cl = $rows[0] ?? null; if (!$cl) fail('Cliente non trovato', 404);

function aggiorna_cliente($id, $campi){ $campi['abbonamento_aggiornato'] = gmdate('c'); supa('PATCH', '/rest/v1/edu_clienti?id=eq.' . $id, $campi); }
function stato_da_sub($s){
  if (!empty($s['pause_collection'])) return 'in_pausa';
  $st = $s['status'] ?? '';
  if ($st === 'active')  return 'attivo';
  if ($st === 'canceled') return 'annullato';
  if (in_array($st, ['past_due','unpaid'])) return 'insoluto';
  return 'in_attesa';
}
function sync_da_sub($cl, $s, $link = null){
  $campi = ['abbonamento_stato' => stato_da_sub($s), 'stripe_subscription_id' => $s['id'],
            'abbonamento_annulla_a_fine' => !empty($s['cancel_at_period_end']),
            'abbonamento_fine' => !empty($s['current_period_end']) ? gmdate('c', $s['current_period_end']) : null];
  if ($link) $campi['abbonamento_link'] = $link;
  if (!empty($s['metadata']['piano']))   $campi['abbonamento_piano']   = $s['metadata']['piano'];
  if (!empty($s['metadata']['periodo'])) $campi['abbonamento_periodo'] = $s['metadata']['periodo'];
  if ($campi['abbonamento_stato'] === 'in_pausa') $campi['licenza_stato'] = 'sospesa';
  if ($campi['abbonamento_stato'] === 'attivo')   $campi['licenza_stato'] = 'attiva';
  aggiorna_cliente($cl['id'], $campi);
  return $campi;
}

/* ---------- 3. azioni ---------- */
switch ($azione) {

case 'crea': {
  $piano = $B['piano'] ?? ''; $periodo = $B['periodo'] ?? 'anno';
  if (!isset($PREZZI[$piano][$periodo])) fail('Piano o periodo non configurati (STRIPE_PRICES): ' . $piano . '/' . $periodo);
  if (empty($cl['contatto_email'])) fail('Il cliente non ha un\'email del referente: Stripe non saprebbe a chi mandare il link');
  if (!empty($cl['stripe_subscription_id']) && in_array($cl['abbonamento_stato'], ['in_attesa','attivo','in_pausa','insoluto']))
    fail('Questo cliente ha già un abbonamento ' . $cl['abbonamento_stato'] . ': annullalo prima di crearne un altro');

  $customer = $cl['stripe_customer_id'];
  if (empty($customer)) {
    $c = stripe('POST', '/v1/customers', ['email' => $cl['contatto_email'], 'name' => $cl['nome'],
      'description' => 'Esplora Trapani Edu · ' . $cl['slug'], 'metadata[cliente_id]' => $cl['id'], 'metadata[slug]' => $cl['slug']],
      'cust-' . $cl['id']);
    $customer = $c['id'];
    aggiorna_cliente($cl['id'], ['stripe_customer_id' => $customer]);
  }
  /* abbonamento in modalità "invia fattura": Stripe invia l'email col link di pagamento;
     gli addebiti successivi arrivano allo stesso modo a ogni rinnovo */
  $s = stripe('POST', '/v1/subscriptions', [
    'customer' => $customer, 'items[0][price]' => $PREZZI[$piano][$periodo],
    'collection_method' => 'send_invoice', 'days_until_due' => (int)$GIORNI_SCADENZA_FATTURA,
    'metadata[cliente_id]' => $cl['id'], 'metadata[slug]' => $cl['slug'], 'metadata[piano]' => $piano, 'metadata[periodo]' => $periodo,
    'expand[]' => 'latest_invoice'], 'sub-' . $cl['id'] . '-' . time());
  $inv = $s['latest_invoice'] ?? null; $link = is_array($inv) ? ($inv['hosted_invoice_url'] ?? null) : null;
  if (is_array($inv) && ($inv['status'] ?? '') === 'draft') {     /* la finalizzo io: parte l'email */
    $inv = stripe('POST', '/v1/invoices/' . $inv['id'] . '/finalize', ['auto_advance' => 'true']);
    $link = $inv['hosted_invoice_url'] ?? $link;
    try { stripe('POST', '/v1/invoices/' . $inv['id'] . '/send', []); } catch (Throwable $e) {}
  }
  $campi = sync_da_sub($cl, $s, $link);
  $campi['abbonamento_stato'] = 'in_attesa'; $campi['abbonamento_piano'] = $piano; $campi['abbonamento_periodo'] = $periodo;
  aggiorna_cliente($cl['id'], ['abbonamento_stato' => 'in_attesa', 'abbonamento_piano' => $piano, 'abbonamento_periodo' => $periodo, 'abbonamento_link' => $link]);
  out(['ok' => true, 'subscription' => $s['id'], 'customer' => $customer, 'link' => $link, 'email' => $cl['contatto_email'],
       'messaggio' => 'Abbonamento creato: Stripe ha inviato il link di pagamento a ' . $cl['contatto_email']]);
}

case 'pausa': {
  if (empty($cl['stripe_subscription_id'])) fail('Nessun abbonamento da mettere in pausa');
  $s = stripe('POST', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['pause_collection[behavior]' => 'void']);
  $campi = sync_da_sub($cl, $s);
  out(['ok' => true, 'stato' => $campi['abbonamento_stato'], 'messaggio' => 'Abbonamento in pausa: nessun addebito e licenza sospesa finché non lo riprendi']);
}

case 'riprendi': {
  if (empty($cl['stripe_subscription_id'])) fail('Nessun abbonamento da riprendere');
  $s = stripe('POST', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['pause_collection' => '']);
  $campi = sync_da_sub($cl, $s);
  out(['ok' => true, 'stato' => $campi['abbonamento_stato'], 'messaggio' => 'Abbonamento ripreso']);
}

case 'annulla': {
  if (empty($cl['stripe_subscription_id'])) fail('Nessun abbonamento da annullare');
  $quando = ($B['quando'] ?? 'fine_periodo') === 'subito' ? 'subito' : 'fine_periodo';
  if ($quando === 'subito') {
    $s = stripe('DELETE', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['invoice_now' => 'false', 'prorate' => 'false']);
    aggiorna_cliente($cl['id'], ['abbonamento_stato' => 'annullato', 'abbonamento_annulla_a_fine' => false, 'licenza_stato' => 'scaduta', 'licenza_fine' => gmdate('Y-m-d')]);
    out(['ok' => true, 'stato' => 'annullato', 'messaggio' => 'Abbonamento annullato subito: licenza chiusa']);
  } else {
    $s = stripe('POST', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['cancel_at_period_end' => 'true']);
    $campi = sync_da_sub($cl, $s);
    out(['ok' => true, 'stato' => $campi['abbonamento_stato'], 'annulla_a_fine' => true,
         'messaggio' => 'Abbonamento in chiusura: resta attivo fino al ' . (!empty($s['current_period_end']) ? date('d/m/Y', $s['current_period_end']) : 'fine periodo') . ', poi nessun rinnovo']);
  }
}

case 'stato': {
  if (empty($cl['stripe_subscription_id'])) out(['ok' => true, 'stato' => $cl['abbonamento_stato'] ?: 'nessuno']);
  $s = stripe('GET', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['expand[]' => 'latest_invoice']);
  $inv = $s['latest_invoice'] ?? null; $link = is_array($inv) ? ($inv['hosted_invoice_url'] ?? null) : null;
  $campi = sync_da_sub($cl, $s, $link);
  out(['ok' => true, 'stato' => $campi['abbonamento_stato'], 'fine' => $campi['abbonamento_fine'], 'link' => $link, 'stripe_status' => $s['status'] ?? null]);
}

case 'link': {
  if (empty($cl['stripe_subscription_id'])) fail('Nessun abbonamento');
  $s = stripe('GET', '/v1/subscriptions/' . $cl['stripe_subscription_id'], ['expand[]' => 'latest_invoice']);
  $inv = $s['latest_invoice'] ?? null;
  if (!is_array($inv) || empty($inv['hosted_invoice_url'])) fail('Nessuna fattura aperta per questo abbonamento');
  if (($inv['status'] ?? '') === 'open') { try { stripe('POST', '/v1/invoices/' . $inv['id'] . '/send', []); } catch (Throwable $e) {} }
  out(['ok' => true, 'link' => $inv['hosted_invoice_url'], 'stato_fattura' => $inv['status'] ?? null, 'messaggio' => 'Link pronto (e reinviato via email se la fattura è aperta)']);
}

default: fail('Azione sconosciuta');
}
