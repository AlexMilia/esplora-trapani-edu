#!/bin/bash
# ESPLORA TRAPANI EDU — avvia il player locale (Mac / Linux).
# Doppio clic (Mac: tasto destro → Apri con → Terminale) oppure:  bash avvia.sh
cd "$(dirname "$0")" || exit 1
if command -v node >/dev/null 2>&1; then
  exec node avvia.js
elif command -v php >/dev/null 2>&1; then
  echo "Node.js non trovato: uso PHP. Se i salti avanti/indietro nei video non funzionano, installa Node.js (nodejs.org)."
  (sleep 1; open "http://localhost:8765/" 2>/dev/null || xdg-open "http://localhost:8765/" 2>/dev/null) &
  exec php -S localhost:8765
elif command -v python3 >/dev/null 2>&1; then
  echo "Node.js non trovato: uso Python. ATTENZIONE: i salti avanti/indietro nei video possono non funzionare. Meglio installare Node.js (nodejs.org)."
  (sleep 1; open "http://localhost:8765/" 2>/dev/null || xdg-open "http://localhost:8765/" 2>/dev/null) &
  exec python3 -m http.server 8765 --bind 127.0.0.1
else
  echo "Per avviare il player locale serve Node.js: https://nodejs.org (versione LTS)."
  read -r -p "Premi Invio per chiudere"
fi
