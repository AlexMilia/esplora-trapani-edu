#!/bin/bash
# TEST scheda.php — la scheda da stampare per la classe (standard e adattata).
# Offline: Supabase finto (mock/supa-edu-mock.php) con i contenuti veri del salinaio.
# Verifica il contenuto, i ripieghi automatici, la sicurezza e che la stampa stia
# davvero in 2 pagine A4 (serve node+playwright; senza, quella parte viene saltata).
# Uso: bash test/t_scheda.sh
set -u
QUI="$(cd "$(dirname "$0")" && pwd)"; APP="$QUI/../app"
php -r 'exit(function_exists("curl_init")?0:1);' || { echo "❌ serve l'estensione php-curl"; exit 1; }
TMP="$(mktemp -d)"; cp -r "$APP"/. "$TMP"/
cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
cat >> "$TMP/dati/config.php" << 'EOF'
$SUPA_URL='http://127.0.0.1:8094'; $SUPA_ANON='anon-finta'; $SUPA_SERVICE='';
$EDU_TENANT_DEFAULT='esplora-trapani'; $EDU_CHECK_REFERER=false;
EOF
rm -f /tmp/supa-edu-state.json
php -S 127.0.0.1:8094 "$QUI/mock/supa-edu-mock.php" >"$TMP/m.log" 2>&1 & M=$!
php -S 127.0.0.1:8096 -t "$TMP"                     >"$TMP/a.log" 2>&1 & A=$!
trap 'kill $M $A 2>/dev/null; rm -rf "$TMP" /tmp/supa-edu-state.json' EXIT
for i in $(seq 1 15); do curl -s -o /dev/null http://127.0.0.1:8096/ && curl -s -o /dev/null http://127.0.0.1:8094/ && break; sleep 0.3; done
U="http://127.0.0.1:8096/scheda.php?c=esplora-trapani&lez=salinaio"
P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }
# tutte: 1 solo se TUTTE le stringhe ci sono. nessuna: 1 solo se NON c'è nessuna.
tutte(){ local t="$1"; shift; for x in "$@"; do echo "$t" | grep -qF "$x" || return 0; done; echo 1; }
nessuna(){ local t="$1"; shift; for x in "$@"; do echo "$t" | grep -qF "$x" && return 0; done; echo 1; }
ha(){ tutte "$1" "$2"; }

STD=$(curl -s "$U&tipo=standard&liv=junior")
ADA=$(curl -s "$U&tipo=adattata&liv=junior")
SEN=$(curl -s "$U&tipo=standard&liv=senior")

echo "— scheda standard: viene dai dati della lezione —"
ok "titolo della lezione e del corso in testata" "$(tutte "$STD" "Il salinaio" "ANTICHI MESTIERI DI TRAPANI")"
ok "numero della scheda (n. 1 di 5)" "$(ha "$STD" "n. 1 di 5")"
ok "domanda di apertura dalla scheda" "$(ha "$STD" "come si «raccoglie» il sale")"
ok "cose da cercare nel video" "$(tutte "$STD" "Il palo a forma di T" "paluneddo")"
ok "il distrattore è mescolato tra le cose da cercare" "$(ha "$STD" "Un mulino a vento")"
ok "tutte e cinque le fasi del lavoro, ognuna col suo quadratino" "$([ "$(echo "$STD" | grep -o 'class=\"num\"' | wc -l)" -ge 5 ] && echo 1)"
ok "glossario con le parole del mestiere" "$(tutte "$STD" "munzeddu" "vasca salante")"
ok "domanda sul territorio" "$(ha "$STD" "tra Trapani e Marsala")"
ok "intervista a casa, tre domande" "$(tutte "$STD" "Hai mai visto una salina" "il sale di Trapani è famoso")"
ok "che cosa disegnare" "$(ha "$STD" "il paluneddo o il palo a T")"
ok "autovalutazione finale" "$(ha "$STD" "Non ancora")"
ok "spazio per nome, classe e data" "$(tutte "$STD" "Nome e cognome" "Classe")"

echo "— le fasi si stampano mescolate, ma sempre allo stesso modo —"
ORD1=$(echo "$STD" | grep -A1 'class="num"' | grep -oE "Il salinaio rompe|Raccoglie il sale|Controlla la punta|Porta il sale|Il munzeddu asciuga" | tr '\n' ',')
ORD2=$(curl -s "$U&tipo=standard&liv=junior" | grep -A1 'class="num"' | grep -oE "Il salinaio rompe|Raccoglie il sale|Controlla la punta|Porta il sale|Il munzeddu asciuga" | tr '\n' ',')
ok "ristampando la scheda l'ordine resta identico (il docente ha la stessa copia)" "$([ "$ORD1" = "$ORD2" ] && echo 1)"
ok "…e non è l'ordine giusto, altrimenti l'esercizio non esiste" "$([ "${ORD1%%,*}" != "Il salinaio rompe" ] && echo 1)"

echo "— livello: primaria e medie —"
ok "la versione primaria lo dichiara" "$(ha "$STD" "scuola primaria")"
ok "la versione medie lo dichiara" "$(ha "$SEN" "secondaria di primo grado")"

echo "— scheda adattata (autismo) —"
ok "pagina per l'insegnante, da non consegnare" "$(ha "$ADA" "non consegnare all’alunno")"
ok "agenda con le cinque attività" "$(tutte "$ADA" "Le mie 5 attività" "Consegno la scheda")"
ok "una attività per pagina, numerata" "$(tutte "$ADA" "Attività 1 di 5" "Attività 5 di 5")"
ok "quattro cose da cercare, in stampatello" "$(tutte "$ADA" "IL MUNZEDDU" "IL PALO A T")"
ok "tre tessere da ritagliare" "$(tutte "$ADA" "Tessere da ritagliare" "Rompo la crosta di sale")"
ok "carte AIUTO e PAUSA" "$(tutte "$ADA" "AIUTO" "PAUSA")"
ok "vero/falso con la frase falsa inclusa" "$(ha "$ADA" "Il sale cresce sugli alberi")"
ok "le risposte del vero/falso sono date all'insegnante, non all'alunno" "$(ha "$ADA" "SÌ · SÌ · SÌ · NO")"
ok "autovalutazione con le facce" "$(tutte "$ADA" "Come è andata?" "Così così")"
ok "carta del ruolo nel quiz: versione LIM" "$(ha "$ADA" "premo il pulsante della risposta sulla LIM")"
ok "carta del ruolo nel quiz: versione telefoni" "$(ha "$ADA" "tocco la risposta sul mio schermo")"
ok "entrambe le carte dicono quando finisce il compito" "$([ "$(echo "$ADA" | grep -o 'Fine del quiz' | wc -l)" -ge 2 ] && echo 1)"
ok "il riquadro per la foto mancante invita a incollare un fotogramma" "$(ha "$ADA" "Incolla qui un fotogramma")"
ok "icone disegnate, non emoji (restano nere in stampa)" "$(ha "$ADA" "<svg class=\"ico\"")"

echo "— ripieghi quando in regia non si è scritto tutto —"
VUOTA=$(curl -s "http://127.0.0.1:8096/scheda.php?c=esplora-trapani&lez=vuota&tipo=standard")
ok "lezione inesistente → pagina di cortesia, non un errore del server" "$(tutte "$VUOTA" "Scheda non disponibile")"
SPOGLIA=$(curl -s "http://127.0.0.1:8096/scheda.php?c=esplora-trapani&lez=spoglia&tipo=standard")
ok "lezione senza scheda compilata: avviso in cima e sezioni mancanti non stampate" "$(tutte "$SPOGLIA" "Questa scheda è incompleta" "le fasi del lavoro")"
ok "…ma quello che c'è già nella lezione viene comunque usato" "$(tutte "$SPOGLIA" "Il munzeddu" "Il palo a T")"

echo "— sicurezza —"
ok "nessuna chiave di Supabase finisce nella pagina" "$(nessuna "$STD$ADA" "anon-finta" "SUPA_" "service_role")"
ok "la pagina dice ai motori di non indicizzarla" "$(ha "$STD" "noindex")"
ok "api.php e scheda.php usano solo la anon key" "$(php -r '$s=json_decode(@file_get_contents("/tmp/supa-edu-state.json"),true); $n=0;$bad=0; foreach(($s["log"]??[]) as $l){ if(strpos($l["p"],"/rest/")!==0)continue; $n++; if($l["auth"]!=="Bearer anon-finta")$bad++; } echo ($n>0&&$bad===0)?1:0;')"
XSS=$(curl -s "http://127.0.0.1:8096/scheda.php?c=esplora-trapani&lez=salinaio&tipo=standard&scuola=%3Cscript%3Ealert(1)%3C/script%3E")
ok "il nome della scuola passato nell'indirizzo non può iniettare codice" "$(nessuna "$XSS" "<script>alert(1)")"

echo "— stampa vera in A4 —"
if command -v node >/dev/null && node -e "require('playwright')" 2>/dev/null; then
  node -e "
  const {chromium}=require('playwright');(async()=>{
   const b=await chromium.launch();const c=await b.newContext();const p=await c.newPage();
   const out=[];
   for(const t of ['standard','adattata']){
     await p.goto('$U&tipo='+t,{waitUntil:'networkidle'});
     await p.emulateMedia({media:'print'});
     const f='/tmp/_sch_'+t+'.pdf'; await p.pdf({path:f,format:'A4',printBackground:true});
     const n=require('fs').readFileSync(f).toString('latin1').match(/\/Type\s*\/Page[^s]/g);
     out.push(t+':'+(n?n.length:0));
   }
   console.log(out.join(' '));await b.close();})();" > /tmp/_sch_pagine.txt 2>/dev/null
  PAG=$(cat /tmp/_sch_pagine.txt 2>/dev/null)
  ok "la standard sta in 2 pagine A4 ($PAG)" "$(echo "$PAG" | grep -q "standard:2" && echo 1)"
  ok "l'adattata ha una pagina per attività, più insegnante, agenda, facce, ritagli ($PAG)" "$(echo "$PAG" | grep -q "adattata:10" && echo 1)"
  rm -f /tmp/_sch_*.pdf /tmp/_sch_pagine.txt
else
  echo "  · playwright non disponibile: salto la prova di stampa"
fi

echo; echo "RISULTATO: $P passati, $F falliti"
[ $F -eq 0 ]
