#!/bin/bash
# Esegue tutti i test jsdom (player + regia + analisi statica).
# Prerequisiti: node, php-cli, `npm install` fatto nella radice della repo (jsdom).
# Uso:  npm test        oppure       bash test/esegui-js.sh
QUI="$(cd "$(dirname "$0")" && pwd)"
cd "$QUI" || exit 1
bash ./rendi-player.sh || exit 1
TOT=0; KO=0
for t in t_statica.js test-regia.js test-regia26.js t_flusso_regia.js t_viewer.js t_sec_xss.js \
         t_regia_audio.js t_regia_abbonamenti.js t_mascotte.js t_audit.js \
         test-profondo.js t_player26.js t_audio.js; do
  echo; echo "=================== $t ==================="
  OUT="$(node "$t" 2>&1)"; RC=$?
  echo "$OUT" | tail -n 25
  P=$(echo "$OUT" | grep -c '✓'); F=$(echo "$OUT" | grep -c '❌')
  TOT=$((TOT+1))
  if [ $RC -ne 0 ] || [ "$F" -gt 0 ]; then KO=$((KO+1)); echo ">>> $t: PROBLEMI (exit $RC, ✓ $P, ❌ $F)"; else echo ">>> $t: ok (✓ $P)"; fi
done
echo; echo "==========================================="
echo "Suite eseguite: $TOT — con problemi: $KO"
[ $KO -eq 0 ]
