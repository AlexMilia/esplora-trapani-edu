#!/bin/bash
# =============================================================================
# crea-zip.sh — prepara il pacchetto da caricare su Aruba in /project/edu/
#
#   bash deploy/crea-zip.sh            →  dist/esplora-trapani-edu-<data>-<commit>.zip
#
# Dentro lo zip c'è SOLO quello che va online, con la stessa struttura del
# server:
#   edu/.htaccess                     (riscritture dei percorsi tenant)
#   edu/app/…                         (il sito)
#   edu/app/dati/.htaccess            (nega la cartella dal web)
#   edu/app/dati/config.example.php   (MODELLO: il config vero resta sul server)
#   edu/app/dati/live/.htaccess
#   migrazioni/                       (da eseguire su Supabase, NON da caricare)
#   LEGGIMI-METTI-ONLINE.md           (i passi, in ordine)
#
# NON entrano, per scelta:
#   app/dati/config.php               non esiste nel repo e non deve mai essere
#                                     sovrascritto: contiene le chiavi segrete
#   app/debug500.php                  pagina di diagnosi: espone i dettagli degli errori
#   app/stripe-setup.php              crea i prezzi su Stripe: si usa una volta e si cancella
#   app/regia-edu.html                doppione statico della regia, senza gli header di
#                                     sicurezza che regia-edu.php manda: online non serve
#   test/, docs/, demo-vr/, contenuti/, .git  non servono al server
# =============================================================================
set -euo pipefail
QUI="$(cd "$(dirname "$0")/.." && pwd)"
cd "$QUI"

DATA="$(date +%Y%m%d)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
NOME="esplora-trapani-edu-$DATA-$COMMIT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
D="$TMP/$NOME"
mkdir -p "$D/edu/app" "$D/migrazioni" dist

# ---- il sito --------------------------------------------------------------
cp -r app/. "$D/edu/app/"
rm -f  "$D/edu/app/debug500.php" "$D/edu/app/stripe-setup.php"
rm -f  "$D/edu/app/regia-edu.html"   # online c'e' solo regia-edu.php (stessi contenuti, piu' gli header di sicurezza)
rm -f  "$D/edu/app/dati/config.php" "$D/edu/app/dati/log.txt"
rm -rf "$D/edu/app/dati/cache" 2>/dev/null || true
find "$D/edu/app/dati/live" -type f ! -name .htaccess -delete
cp deploy/htaccess-project-edu.txt "$D/edu/.htaccess"

# ---- le migrazioni: si eseguono su Supabase, non si caricano su Aruba ------
cp migrazioni/migrazione_completa.sql "$D/migrazioni/"
cp migrazioni/migrazione_29_rls_consolidata.sql migrazioni/migrazione_30_abbonamenti.sql \
   migrazioni/migrazione_31_elenco_clienti.sql migrazioni/migrazione_32_didattica.sql \
   migrazioni/migrazione_33_schede_contenuti.sql migrazioni/migrazione_34_chiusura_sicurezza.sql \
   migrazioni/migrazione_35_clip_tagli_mappa.sql migrazioni/migrazione_36_area_trapani.sql \
   migrazioni/migrazione_37_accendi_trapani.sql "$D/migrazioni/"

# ---- i passi -----------------------------------------------------------------
cp deploy/LEGGIMI-METTI-ONLINE.md "$D/"

# ---- controlli prima di chiudere il pacchetto -------------------------------
err=0
[ -f "$D/edu/app/dati/config.php" ]  && { echo "❌ config.php reale nel pacchetto"; err=1; }
[ -f "$D/edu/app/debug500.php" ]     && { echo "❌ debug500.php nel pacchetto";  err=1; }
[ -f "$D/edu/app/stripe-setup.php" ] && { echo "❌ stripe-setup.php nel pacchetto"; err=1; }
[ -f "$D/edu/app/regia-edu.html" ]   && { echo "❌ regia-edu.html nel pacchetto";   err=1; }
[ -s "$D/edu/app/lib/leaflet/leaflet.js" ] && [ -s "$D/edu/app/lib/leaflet/leaflet.css" ] || { echo "❌ manca lib/leaflet (la mappa dei corsi non partirebbe)"; err=1; }
if grep -rIlE "(sk_live_|sk_test_|whsec_)[A-Za-z0-9]{8,}" "$D" >/dev/null 2>&1; then
  echo "❌ una chiave Stripe è finita nel pacchetto"; err=1; fi
if grep -rIl '"role":"service_role"\|service_role' "$D/edu" | grep -v config.example.php >/dev/null 2>&1; then
  echo "❌ la parola service_role compare fuori dal modello di config"; err=1; fi
for f in "$D"/edu/app/*.php; do php -l "$f" >/dev/null || { echo "❌ errore di sintassi in $f"; err=1; }; done
[ $err -ne 0 ] && { echo "pacchetto NON creato"; exit 1; }

# ---- elenco con impronte: serve a confrontare dopo il caricamento ----------
( cd "$D" && find edu migrazioni -type f | sort | xargs sha256sum ) > "$D/IMPRONTE.txt"

( cd "$TMP" && zip -qr "$QUI/dist/$NOME.zip" "$NOME" )
echo "✓ dist/$NOME.zip"
unzip -l "dist/$NOME.zip" | tail -1
