#!/bin/bash
# PROVA IN UN BROWSER VERO — la mappa del corso (mouse, dito, telefono).
# Avvia e spegne da solo `php -S` sulla porta 8098 e lancia Chromium con Playwright.
# Se Playwright non è installato salta la prova senza fallire (i test jsdom restano).
cd "$(dirname "$0")" || exit 1
node -e "require('playwright')" 2>/dev/null || { echo "⏭  Playwright non installato: prova saltata (npm i -D playwright && npx playwright install chromium)"; exit 0; }
if command -v lsof >/dev/null && lsof -ti:8098 >/dev/null 2>&1; then echo "❌ la porta 8098 è già occupata"; exit 9; fi
TMP="$(mktemp -d)"; cp -r ../app/. "$TMP"/
[ -f "$TMP/dati/config.php" ] || cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
php -S 127.0.0.1:8098 -t "$TMP" >"$TMP/php.log" 2>&1 & PID=$!
trap 'kill $PID 2>/dev/null; rm -rf "$TMP"' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:8098/index.php" && break; sleep 0.3; done
node prova_mappa_browser.js
