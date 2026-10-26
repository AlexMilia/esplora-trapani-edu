#!/bin/bash
# Avvia l'ambiente del test Stripe (Fase 2) e lancia t_stripe.sh:
#   8091 = finto Stripe (mock/stripe-mock.php)   8092 = finto Supabase (mock/supa-mock.php)
#   8090 = app/ con un config di test (chiavi finte che i mock riconoscono)
# Prerequisiti: php-cli con estensione curl.   Uso: bash test/t_stripe_avvia.sh
set -e
QUI="$(cd "$(dirname "$0")" && pwd)"; APP="$QUI/../app"
php -r 'exit(function_exists("curl_init")?0:1);' || { echo "❌ serve l'estensione php-curl (es. apt install php-curl)"; exit 1; }
TMP="$(mktemp -d)"; cp -r "$APP"/. "$TMP"/
cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
cat >> "$TMP/dati/config.php" << 'EOF'

/* ---- SOLO TEST: puntiamo ai mock locali ---- */
$SUPA_URL = 'http://127.0.0.1:8092';  $SUPA_SERVICE = 'service';
$STRIPE_API = 'http://127.0.0.1:8091'; $STRIPE_SECRET = 'sk_test_finto'; $STRIPE_WEBHOOK_SECRET = 'whsec_finto';
$EDU_DIAG_KEY = 'diag';
$STRIPE_PRICES = ['base'=>['mese'=>'price_base_m','anno'=>'price_base_a'],'pro'=>['mese'=>'price_pro_m','anno'=>'price_pro_a'],'premium'=>['mese'=>'price_premium_m','anno'=>'price_premium_a']];
EOF
php -S 127.0.0.1:8091 "$QUI/mock/stripe-mock.php" >"$TMP/m1.log" 2>&1 & P1=$!
php -S 127.0.0.1:8092 "$QUI/mock/supa-mock.php"   >"$TMP/m2.log" 2>&1 & P2=$!
php -S 127.0.0.1:8090 -t "$TMP"                     >"$TMP/m3.log" 2>&1 & P3=$!
trap 'kill $P1 $P2 $P3 2>/dev/null; rm -rf "$TMP" /tmp/stripe-state.json /tmp/supa-state.json' EXIT
for i in $(seq 1 15); do curl -s -o /dev/null http://127.0.0.1:8090/ && curl -s -o /dev/null http://127.0.0.1:8091/ && curl -s -o /dev/null http://127.0.0.1:8092/ && break; sleep 0.3; done
set +e
bash "$QUI/t_stripe.sh"; RC=$?
exit $RC
