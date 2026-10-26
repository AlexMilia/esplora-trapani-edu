<?php
/* ============================================================
   ESPLORA TRAPANI EDU — dati/config.example.php · MODELLO
   ------------------------------------------------------------
   Questo è il MODELLO versionato nella repository. Il file vero
   si chiama dati/config.php, è escluso da git (.gitignore) e vive
   SOLO sul server Aruba (/project/edu/app/dati/, negato dal web).

   Per far partire una copia locale:
       cp app/dati/config.example.php app/dati/config.php
   e poi compila i valori segnati CAMBIAMI / vuoti.

   ⚠️ Il config reale contiene SUPA_SERVICE (service_role),
   STRIPE_SECRET e STRIPE_WEBHOOK_SECRET: NON committarlo mai e
   NON sovrascriverlo con questo modello durante un deploy.
   ============================================================ */

if (!defined('EDU_OK')) { http_response_code(403); exit('no'); }

/* ---- Supabase ASK Trapani (anon key: pubblica by design, la
        sicurezza sta in RLS + Supabase Auth) ---- */
$SUPA_URL  = 'https://sdqzqzmkhbkkibjzauox.supabase.co';
$SUPA_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkcXpxem1raGJra2lianphdW94Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwNzM4NDYsImV4cCI6MjA5MDY0OTg0Nn0.SQ-de_vaL4op7BXLRg7YjUUP0H03-k4Ym2k0W4h9huE';

/* ---- progetto servito da api.php su Supabase ---- */
$EDU_PROGETTO = 'antichi-mestieri-trapani';   /* legacy: usato se manca il tenant */

/* ---- Fase 2 SaaS: tenant di default quando l'URL non lo indica
        (con /edu/{slug}/ o ?c=slug il default viene ignorato) ---- */
$EDU_TENANT_DEFAULT = 'esplora-trapani';

/* ---- brand del player (il guscio ha già i default: qui solo
        le eventuali personalizzazioni) ---- */
$EDU_BRAND = array(
  'titolo'      => 'Antichi Mestieri di Trapani',
  'sottotitolo' => 'Esplora Trapani · Sale in Classe',
);

/* ---- parametri richiesti da api.php (default sicuri: il config REALE,
        se copiato al posto di questo, vince con i suoi valori) ---- */
$EDU_DIAG_KEY   = 'CAMBIAMI-chiave-lunga-e-casuale';   /* api.php?action=diag&k=... e stripe-setup.php?k=... */
$EDU_CHECK_REFERER = true;
$EDU_RATE_WIN   = 60;      /* finestra rate limit (s) */
$EDU_RATE_MAX   = 240;     /* richieste max per finestra */
$EDU_CACHE_TTL  = 300;     /* cache catalogo/mascotte (s) */
$EDU_MASCOTTE   = array(); /* fallback video mascotte */
$EDU_MASCOTTE_QUIZ_SEMPRE = true;

/* ---- log applicativo minimale su file (dentro dati/, negata
        dal web dall'.htaccess). Se il tuo config reale ha già
        una edu_log più ricca, vince la sua. ---- */
if (!function_exists('edu_log')) {
  function edu_log($tipo, $extra = '') {
    $riga = date('Y-m-d H:i:s') . "\t" . $tipo . "\t" .
            (isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '-') . "\t" .
            str_replace(array("\r", "\n", "\t"), ' ', (string)$extra) . "\n";
    @file_put_contents(__DIR__ . '/log.txt', $riga, FILE_APPEND | LOCK_EX);
  }
}

/* ============================================================
   ⛔ QUI SOTTO, NEL CONFIG REALE, CI SONO LE CHIAVI USATE DA
   api.php (Supabase URL/key, chiave AES di sessione, ecc.).
   Questo file di avvio NON le contiene di proposito: senza di
   esse il player si apre ma il menu lezioni resterà vuoto.
   ============================================================ */

/* ===================== STRIPE (Fase 2 · abbonamenti) =====================
   Chiavi da Stripe → Developers → API keys. Usa prima le chiavi di TEST (sk_test_…),
   poi quelle live. La chiave SERVICE di Supabase (Settings → API → service_role)
   serve SOLO a stripe.php e al webhook: non esce mai da questo file (dati/ è negata dal web). */
$STRIPE_SECRET         = '';            /* sk_test_… / sk_live_… */
$STRIPE_WEBHOOK_SECRET = '';            /* whsec_… (Developers → Webhooks → endpoint → Signing secret) */
$SUPA_SERVICE          = '';            /* eyJ… service_role (Supabase → Settings → API) */
$STRIPE_GIORNI_FATTURA = 7;             /* giorni per pagare la fattura ricevuta via email */
/* ID dei prezzi creati su Stripe (li stampa stripe-setup.php): piano → periodo → price_… */
$STRIPE_PRICES = [
  'base'    => ['mese' => '', 'anno' => ''],
  'pro'     => ['mese' => '', 'anno' => ''],
  'premium' => ['mese' => '', 'anno' => ''],
];
