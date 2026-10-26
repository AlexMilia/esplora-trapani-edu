#!/bin/bash
# TEST DATABASE — ricrea la replica dello schema di produzione, applica migrazione_completa.sql
# (idempotente: viene applicata DUE volte apposta) e lancia i test SQL con i ruoli reali.
# Prerequisiti: PostgreSQL locale (>= 14) e un utente che possa creare database.
# Uso:  DBURL=postgresql://utente:password@127.0.0.1/edu_test bash test/db_avvia.sh
#       (DBURL è facoltativo: default postgresql://localhost/edu_test)
QUI="$(cd "$(dirname "$0")" && pwd)"; MIG="$QUI/../migrazioni"
DBURL="${DBURL:-postgresql://localhost/edu_test}"; ADMIN="${DBURL%/*}/postgres"; NOME="${DBURL##*/}"
P=0; F=0; LOG="${TMPDIR:-/tmp}/edu_db_test.log"; : > "$LOG"
passo(){ if [ "$2" = "0" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }
errori(){ grep -E "ERROR|FATAL" "$1" | grep -v "NOTICE" | head -6 | sed 's/^/     /'; }

echo "— 1. database $NOME da zero —"
psql "$ADMIN" -v ON_ERROR_STOP=1 -q -c "drop database if exists $NOME" -c "create database $NOME" 2>>"$LOG"; passo "database ricreato" $?
psql "$DBURL" -v ON_ERROR_STOP=1 -q -f "$MIG/replica.sql" >/dev/null 2>/tmp/db_err.txt; RC=$?; passo "replica dello schema di produzione (replica.sql)" $RC; [ $RC -ne 0 ] && errori /tmp/db_err.txt

echo "— 2. migrazione_completa.sql (19 → 31) —"
psql "$DBURL" -v ON_ERROR_STOP=1 -q -f "$MIG/migrazione_completa.sql" >/dev/null 2>/tmp/db_err.txt; RC=$?; passo "prima applicazione pulita" $RC; [ $RC -ne 0 ] && errori /tmp/db_err.txt
psql "$DBURL" -v ON_ERROR_STOP=1 -q -f "$MIG/migrazione_completa.sql" >/dev/null 2>/tmp/db_err.txt; RC=$?; passo "seconda applicazione (idempotenza)" $RC; [ $RC -ne 0 ] && errori /tmp/db_err.txt

echo "— 3. fixture dei test (solo replica locale) —"
psql "$DBURL" -q -f "$QUI/fixture_test.sql" >/dev/null 2>/tmp/db_err.txt; RC=$?; passo "fixture_test.sql (editor/licenziatario/classe di prova)" $RC; [ $RC -ne 0 ] && errori /tmp/db_err.txt

echo "— 4. test SQL con i ruoli reali —"
# stdbuf tiene in ordine stdout e stderr, così un ERROR resta vicino alla riga "(atteso errore…)" che lo annuncia
for t in t_rls_matrice.sql t_flusso_tenant.sql t_abbonamenti.sql; do
  OUT="$(stdbuf -o0 -e0 psql "$DBURL" -q -At -f "$QUI/$t" 2>&1)"; echo "$OUT" >> "$LOG"
  OKN=$(echo "$OUT" | grep -c '✓'); KON=$(echo "$OUT" | grep -c '❌')
  # errori non annunciati da una riga "(atteso errore" nelle 2 righe precedenti
  ERRN=$(echo "$OUT" | awk '/\(atteso errore/{att=2; next} /ERROR|FATAL/{ if(att>0){att=0} else {n++} ; next} {if(att>0)att--} END{print n+0}')
  SCOST=0; echo "$OUT" | grep -q 'SCOSTAMENTI' && SCOST=$(echo "$OUT" | awk '/SCOSTAMENTI/{s=1;next} s&&NF{n++} END{print n+0}')
  echo "$OUT" | awk '/\(atteso errore/{att=2; next} /ERROR|FATAL|❌/{ if(att>0){att=0} else print "     " $0 ; next} {if(att>0)att--}' | head -8
  case $t in
    t_rls_matrice.sql)  if [ "$ERRN" = 0 ] && [ "$SCOST" = 0 ]; then passo "$t — matrice ruoli×tabelle senza scostamenti dall'atteso" 0; else passo "$t — scostamenti $SCOST · errori $ERRN" 1; fi ;;
    *)                  if [ "$KON" = 0 ] && [ "$ERRN" = 0 ] && [ "$OKN" -gt 0 ]; then passo "$t — $OKN verifiche" 0; else passo "$t — ✓ $OKN · ❌ $KON · errori $ERRN" 1; fi ;;
  esac
done
echo; echo "RISULTATO DB: $P passi ok, $F con problemi   (log completo: $LOG)"
[ $F -eq 0 ]
