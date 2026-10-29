#!/bin/bash
# =====================================================================
# ESPLORA TRAPANI EDU — costruisci-player.sh
# Renderizza app/index.php UNA volta in modalità OFFLINE (EDU_OFFLINE=1)
# e salva il player statico in offline/player/index.html.
# Va rilanciato ogni volta che cambia app/index.php. Serve php-cli.
# Uso:  bash offline/costruisci-player.sh        (da qualunque cartella)
# =====================================================================
set -e
QUI="$(cd "$(dirname "$0")" && pwd)"; APP="$QUI/../app"; OUT="$QUI/player"
TMP="$(mktemp -d)"; PORTA=8098
cp -r "$APP"/. "$TMP"/
[ -f "$TMP/dati/config.php" ] || cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
EDU_OFFLINE=1 php -S 127.0.0.1:$PORTA -t "$TMP" >"$TMP/php.log" 2>&1 &
PID=$!; trap 'kill $PID 2>/dev/null; rm -rf "$TMP"' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:$PORTA/index.php" && break; sleep 0.3; done
mkdir -p "$OUT"
curl -s "http://127.0.0.1:$PORTA/index.php" -o "$OUT/index.html"
grep -q 'window.EDU_OFFLINE=true' "$OUT/index.html" || { echo "❌ player non renderizzato in modalità offline (vedi sotto)"; cat "$TMP/php.log"; exit 1; }
grep -q 'aframe.io/releases' "$OUT/index.html" && { echo "❌ il player offline punta ancora al CDN"; exit 1; }
echo "✓ player offline: $OUT/index.html — $(wc -c <"$OUT/index.html") byte"
echo "  Ora: node offline/crea-pacchetto.js --tenant <slug>   (oppure --da-dati offline/pacchetti/<slug>/dati.js)"
