#!/bin/bash
# TEST PRIVACY del quiz live: le stanze (dove vivono i soprannomi degli alunni)
# devono sparire da sé. L'informativa alle famiglie dichiara «poche ore»: questo
# test è la prova che il codice lo fa davvero, e va rifatto se si tocca live.php.
# Uso: bash test/t_live_gc.sh
QUI="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d); cp -r "$QUI/../app"/. "$TMP"/; cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
mkdir -p "$TMP/dati/live"
php -S 127.0.0.1:8097 -t "$TMP" >/dev/null 2>&1 & S=$!
trap 'kill $S 2>/dev/null; rm -rf "$TMP"' EXIT
for i in $(seq 1 12); do curl -s -o /dev/null http://127.0.0.1:8097/live.php && break; sleep 0.3; done
# stanza vecchia di 4 ore (TTL = 3) e una di adesso
echo '{"creato":1,"stato":"attesa","giocatori":{"tok1":{"nome":"Peppe","risposte":{}}}}' > "$TMP/dati/live/111111.json"
touch -d '4 hours ago' "$TMP/dati/live/111111.json"
echo '{"creato":9999999999,"stato":"attesa","giocatori":{}}' > "$TMP/dati/live/222222.json"
PRIMA=$(ls "$TMP/dati/live"/*.json 2>/dev/null | wc -l)
curl -s -X POST -H 'Content-Type: application/json' -d '{"lezione":"x","livello":"junior","quiz":[{"domanda":"D?","opzioni":["a","b"],"g":0}]}' "http://127.0.0.1:8097/live.php?action=crea" >/dev/null
sleep 0.4
DOPO=$(ls "$TMP/dati/live"/*.json 2>/dev/null | wc -l)
VECCHIA=$([ -f "$TMP/dati/live/111111.json" ] && echo "c'è ancora" || echo "cancellata")
NUOVA=$([ -f "$TMP/dati/live/222222.json" ] && echo "conservata" || echo "cancellata per errore")
echo "file prima: $PRIMA · dopo la creazione: $DOPO"
echo "stanza vecchia di 4 ore (con il soprannome dentro): $VECCHIA"
echo "stanza recente: $NUOVA"
[ "$VECCHIA" = "cancellata" ] && [ "$NUOVA" = "conservata" ] && echo "✓ la pulizia è certa alla creazione e non tocca le partite in corso" || { echo "❌ pulizia non conforme"; exit 1; }
