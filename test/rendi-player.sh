#!/bin/bash
# Renderizza app/index.php con il server PHP integrato e salva le pagine
# che i test jsdom del player si aspettano in /tmp (pag.html, pag26.html,
# pagM.html, pagina12.html: nomi storici, è sempre la stessa pagina).
# Uso:  bash test/rendi-player.sh        (da qualunque cartella)
set -e
QUI="$(cd "$(dirname "$0")" && pwd)"; APP="$QUI/../app"
TMP="$(mktemp -d)"; PORTA=8099
cp -r "$APP"/. "$TMP"/
[ -f "$TMP/dati/config.php" ] || cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
php -S 127.0.0.1:$PORTA -t "$TMP" >"$TMP/php.log" 2>&1 &
PID=$!; trap 'kill $PID 2>/dev/null; rm -rf "$TMP"' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:$PORTA/index.php" && break; sleep 0.3; done
curl -s "http://127.0.0.1:$PORTA/index.php?c=salina-culcasi" -o /tmp/pag.html
grep -q 'window.EDU_C' /tmp/pag.html || { echo "❌ index.php non renderizzato (vedi sotto)"; cat "$TMP/php.log"; exit 1; }
for n in pag26 pagM pagina12; do cp /tmp/pag.html /tmp/$n.html; done
echo "✓ player renderizzato: /tmp/pag.html (+ pag26, pagM, pagina12) — $(wc -c </tmp/pag.html) byte"
