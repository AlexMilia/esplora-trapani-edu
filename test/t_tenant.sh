#!/bin/bash
# TEST — da quale indirizzo il player capisce QUALE SCUOLA sta aprendo.
#
# Il caso che ha fatto nascere questo test: lo zip caricato in una cartella di
# prova, /project/edu/definitiva/index.php. Il player leggeva "definitiva" come
# se fosse lo slug di una scuola, e da lì in poi schede e compiti rispondevano
# «Questa lezione non esiste, non è pubblicata, oppure la licenza del cliente
# non è attiva» — mentre il player, che ripiega sulle lezioni ufficiali,
# sembrava funzionare benissimo.
#
# La regola: un tenant si apre con /edu/{slug}/ e nell'indirizzo NON compare
# nessun .php (ci pensa l'.htaccess a riscrivere). Se l'indirizzo chiama un file
# per nome, quel pezzo è il nome di una cartella, non di una scuola.
#
# Avvia e spegne da solo `php -S` sulla porta 8077. Nessun servizio esterno.
cd "$(dirname "$0")/../app" || exit 1
U=http://127.0.0.1:8077

if command -v lsof >/dev/null && lsof -ti:8077 >/dev/null 2>&1; then
  echo "❌ la porta 8077 è già occupata: un server vecchio servirebbe codice vecchio"; exit 9
fi

CFG_TMP=0; [ -f dati/config.php ] || { cp dati/config.example.php dati/config.php; CFG_TMP=1; }
cat > test_router.php << 'EOF'
<?php require __DIR__.'/index.php';
EOF
php -S 127.0.0.1:8077 test_router.php >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV 2>/dev/null; rm -f test_router.php; rm -f dati/cache_*.json; rm -rf dati/rl; [ $CFG_TMP = 1 ] && rm -f dati/config.php dati/log.txt' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "$U/index.php" && break; sleep 0.3; done

DEFAULT=$(php -r 'define("EDU_OK",1); include "dati/config.php"; echo $EDU_TENANT_DEFAULT;')
P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1  (ho letto: $3)"; fi; }
tenant(){ curl -s "$U$1" | grep -o 'window.EDU_C = "[^"]*"' | head -1 | sed 's/.*= "//;s/"$//'; }
atteso(){ # $1 indirizzo  $2 tenant atteso  $3 descrizione
  local v; v=$(tenant "$1")
  if [ "$v" = "$2" ]; then ok "$3" 1; else ok "$3" 0 "$v"; fi
}

echo "== cartelle di lavoro: NON sono scuole =="
atteso "/project/edu/definitiva/index.php"              "$DEFAULT" "/edu/definitiva/index.php → il default, non «definitiva»"
atteso "/project/edu/definitiva/index.php?classe=demo"  "$DEFAULT" "…anche con il codice classe nell'indirizzo"
atteso "/project/edu/ver8/index.php"                    "$DEFAULT" "/edu/ver8/index.php → il default"
atteso "/project/edu/prova-nuova/scheda.php"            "$DEFAULT" "una cartella mai vista con un file .php → il default"
atteso "/index.php"                                     "$DEFAULT" "indirizzo senza /edu/ → il default"

echo "== i tenant veri continuano a funzionare =="
atteso "/project/edu/salina-culcasi/"                   "salina-culcasi" "/edu/salina-culcasi/ → salina-culcasi"
atteso "/project/edu/salina-culcasi/?classe=3A"         "salina-culcasi" "…con il codice classe"
atteso "/project/edu/ic-pagoto/"                        "ic-pagoto"      "/edu/ic-pagoto/ → ic-pagoto"

echo "== ?c= vince sempre su tutto il resto =="
atteso "/project/edu/app/index.php?c=ic-pagoto"            "ic-pagoto"      "da app/ con ?c="
atteso "/project/edu/definitiva/index.php?c=salina-culcasi" "salina-culcasi" "da una cartella di prova con ?c="
atteso "/project/edu/salina-culcasi/?c=ic-pagoto"           "ic-pagoto"      "?c= ha la precedenza sul percorso"

echo "== indirizzi storti: non deve uscire spazzatura =="
atteso "/project/edu/definitiva/index.php?c=NON%20VALIDO!" "" "uno slug con caratteri strani viene scartato"
atteso "/project/edu/definitiva/index.php?c=SALINA-CULCASI" "salina-culcasi" "maiuscole normalizzate"

echo
echo "RISULTATO: $P passati, $F falliti"
[ $F -eq 0 ] || exit 1
