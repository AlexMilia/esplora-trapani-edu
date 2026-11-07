#!/bin/bash
# TEST api.php v6 — azioni didattiche (migr. 32): esito, diario, compito, consegna.
# Gira offline: Supabase è finto (mock/supa-edu-mock.php), api.php è servito dal
# server PHP integrato. Verifica le risposte E ciò che arriva al database.
# Uso: bash test/t_didattica_api.sh      (serve php-cli con estensione curl)
set -u
QUI="$(cd "$(dirname "$0")" && pwd)"; APP="$QUI/../app"
php -r 'exit(function_exists("curl_init")?0:1);' || { echo "❌ serve l'estensione php-curl"; exit 1; }

TMP="$(mktemp -d)"; cp -r "$APP"/. "$TMP"/
cp "$TMP/dati/config.example.php" "$TMP/dati/config.php"
cat >> "$TMP/dati/config.php" << 'EOF'

/* ---- SOLO TEST: Supabase finto, referer non controllato ---- */
$SUPA_URL='http://127.0.0.1:8094'; $SUPA_ANON='anon-finta'; $SUPA_SERVICE='';
$EDU_TENANT_DEFAULT='esplora-trapani'; $EDU_PROGETTO='antichi-mestieri-trapani';
$EDU_CHECK_REFERER=false; $EDU_CACHE_TTL=0; $EDU_RATE_MAX=100000;
EOF
rm -f /tmp/supa-edu-state.json
php -S 127.0.0.1:8094 "$QUI/mock/supa-edu-mock.php" >"$TMP/mock.log" 2>&1 & M=$!
php -S 127.0.0.1:8093 -t "$TMP"                      >"$TMP/app.log"  2>&1 & A=$!
trap 'kill $M $A 2>/dev/null; rm -rf "$TMP"; [ "${EDU_KEEP:-}" = 1 ] || rm -f /tmp/supa-edu-state.json' EXIT
for i in $(seq 1 15); do curl -s -o /dev/null http://127.0.0.1:8093/index.php && curl -s -o /dev/null http://127.0.0.1:8094/ && break; sleep 0.3; done

U=http://127.0.0.1:8093
cat > "$TMP/boot.php" << 'EOF'
<?php session_start(); if(!isset($_SESSION['edu_t']))$_SESSION['edu_t']=bin2hex(random_bytes(24)); if(!isset($_SESSION['edu_k']))$_SESSION['edu_k']=bin2hex(random_bytes(32)); echo json_encode(['t'=>$_SESSION['edu_t'],'k'=>$_SESSION['edu_k']]);
EOF
B=$(curl -s -c /tmp/cj_edu "$U/boot.php")
T=$(echo "$B" | php -r '$j=json_decode(stream_get_contents(STDIN),true);echo $j["t"];')
K=$(echo "$B" | php -r '$j=json_decode(stream_get_contents(STDIN),true);echo $j["k"];')
DEC='$j=json_decode(stream_get_contents(STDIN),true); if(isset($j["enc"])){echo openssl_decrypt(base64_decode($j["data"]),"aes-256-cbc",hex2bin($argv[1]),OPENSSL_RAW_DATA,base64_decode($j["iv"]));}else echo json_encode($j);'
api(){ curl -s -b /tmp/cj_edu -H "X-EDU-T:$T" -e "$U/index.php" "$@" | php -r "$DEC" "$K"; }
post(){ curl -s -b /tmp/cj_edu -H "X-EDU-T:$T" -H 'Content-Type: application/json' -e "$U/index.php" -d "$2" "$U/api.php?action=$1" | php -r "$DEC" "$K"; }
campo(){ php -r '$j=json_decode(stream_get_contents(STDIN),true); $v=$j; foreach(explode(".",$argv[1]) as $k){ $v=is_array($v)&&array_key_exists($k,$v)?$v[$k]:null; } echo is_bool($v)?($v?"true":"false"):(is_array($v)?json_encode($v):(string)$v);' "$1"; }
stato(){ php -r '$s=json_decode(file_get_contents("/tmp/supa-edu-state.json"),true); echo json_encode($s["esiti"][count($s["esiti"])-1] ?? []);'; }
P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }

echo "— versione —"
V=$(curl -s "$U/api.php?ver"); ok "api.php si dichiara v6 con il blocco didattico" "$(echo "$V" | grep -q 'v6' && echo "$V" | grep -qi 'didattico' && echo 1)"

echo "— ESITO: salvataggio —"
R=$(post esito '{"classe":"ICPA-5A","lezione":"salinaio","lezione_titolo":"Il salinaio","livello":"junior","modalita":"aula","n_domande":5,"n_giuste":4,"dettaglio":{"per_domanda":[{"n":0}]}}')
ok "esito accettato" "$([ "$(echo "$R" | campo ok)" = "true" ] && echo 1)"
S=$(stato)
ok "al database arrivano cliente, classe e lezione giusti" "$([ "$(echo "$S" | campo cliente)" = "esplora-trapani" ] && [ "$(echo "$S" | campo classe)" = "ICPA-5A" ] && [ "$(echo "$S" | campo lezione)" = "salinaio" ] && echo 1)"
ok "punteggio e modalità trasmessi" "$([ "$(echo "$S" | campo n_giuste)" = "4" ] && [ "$(echo "$S" | campo n_domande)" = "5" ] && [ "$(echo "$S" | campo modalita)" = "aula" ] && echo 1)"

echo "— ESITO: validazioni —"
R=$(post esito '{"classe":"icpa-5a","lezione":"SALINAIO","n_domande":3,"n_giuste":1}')
ok "classe normalizzata in maiuscolo e lezione in minuscolo" "$([ "$(stato | campo classe)" = "ICPA-5A" ] && [ "$(stato | campo lezione)" = "salinaio" ] && echo 1)"
R=$(post esito '{"classe":"<script>","lezione":"salinaio","n_domande":3,"n_giuste":1}')
ok "codice classe non valido → diventa ANON, niente caratteri strani nel database" "$([ "$(stato | campo classe)" = "ANON" ] && echo 1)"
R=$(post esito '{"classe":"ICPA-5A","lezione":"salinaio","n_domande":3,"n_giuste":99}')
ok "risposte giuste maggiori delle domande → troncate" "$([ "$(stato | campo n_giuste)" = "3" ] && echo 1)"
R=$(post esito '{"classe":"ICPA-5A","lezione":"salinaio","modalita":"pirata","n_domande":2,"n_giuste":1}')
ok "modalità inventata → ricade su aula" "$([ "$(stato | campo modalita)" = "aula" ] && echo 1)"
R=$(post esito '{"classe":"ICPA-5A","lezione":"salinaio","n_domande":0,"n_giuste":0}')
ok "zero domande → rifiutato (non è un esito)" "$([ "$(echo "$R" | campo err)" = "n_domande" ] && echo 1)"
R=$(post esito '{"classe":"SCADUTA-1","lezione":"salinaio","n_domande":3,"n_giuste":3}')
ok "scuola con licenza scaduta → err licenza_scuola" "$([ "$(echo "$R" | campo err)" = "licenza_scuola" ] && echo 1)"
BIG=$(php -r 'echo json_encode(["classe"=>"ICPA-5A","lezione"=>"salinaio","n_domande"=>2,"n_giuste"=>2,"dettaglio"=>["x"=>str_repeat("a",7000)]]);')
R=$(post esito "$BIG")
ok "dettaglio gonfiato scartato, esito salvato comunque" "$([ "$(echo "$R" | campo ok)" = "true" ] && [ "$(stato | campo dettaglio)" = "[]" -o "$(stato | campo dettaglio)" = "{}" ] && echo 1)"
R=$(post esito 'non-json')
ok "corpo non JSON → 400 body" "$([ "$(echo "$R" | campo err)" = "body" ] && echo 1)"

echo "— ESITO: sicurezza —"
C=$(curl -s -b /tmp/cj_edu -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -e "$U/index.php" -d '{"classe":"X","lezione":"salinaio","n_domande":1,"n_giuste":1}' "$U/api.php?action=esito")
ok "senza token X-EDU-T → rifiutato ($C)" "$([ "$C" = "403" ] && echo 1)"
ok "api.php parla con Supabase solo con la anon key, mai con la service" "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-edu-state.json"),true); $n=0; $bad=0; foreach($s["log"] as $l){ if(strpos($l["p"],"/rest/")!==0 && strpos($l["p"],"/auth/")!==0) continue; $n++; if($l["auth"]!=="Bearer anon-finta")$bad++; } echo ($n>0 && $bad===0)?1:0;')"

echo "— DIARIO del percorso —"
R=$(api "$U/api.php?action=diario&classe=ICPA-5A")
ok "il diario torna al player" "$([ "$(echo "$R" | campo ok)" = "true" ] && echo 1)"
ok "due lezioni, una fatta e una da fare" "$([ "$(echo "$R" | campo diario.0.fatta)" = "true" ] && [ "$(echo "$R" | campo diario.1.fatta)" = "false" ] && echo 1)"
ok "la lezione fatta porta data, volte e miglior esito" "$([ "$(echo "$R" | campo diario.0.volte)" = "2" ] && [ "$(echo "$R" | campo diario.0.pct)" = "80" ] && echo 1)"
R=$(api "$U/api.php?action=diario")
ok "senza codice classe il diario è vuoto, non un errore" "$([ "$(echo "$R" | campo ok)" = "true" ] && [ "$(echo "$R" | campo diario)" = "[]" ] && echo 1)"

echo "— COMPITO: apertura —"
R=$(api "$U/api.php?action=compito&k=SAL2026X")
ok "compito aperto dal codice" "$([ "$(echo "$R" | campo compito.titolo)" = "Rivedi la vasca" ] && echo 1)"
ok "porta la clip da rivedere con i secondi" "$([ "$(echo "$R" | campo compito.clip.guid)" = "g-sal" ] && [ "$(echo "$R" | campo compito.clip.da)" = "10" ] && echo 1)"
ok "LE RISPOSTE GIUSTE NON ARRIVANO al dispositivo" "$(echo "$R" | php -r '$j=json_decode(stream_get_contents(STDIN),true); $d=$j["compito"]["domande"]??[]; foreach($d as $x){ if(array_key_exists("ok",$x)){echo 0;exit;} } echo count($d)===2?1:0;')"
C=$(curl -s -b /tmp/cj_edu -o /dev/null -w '%{http_code}' -H "X-EDU-T:$T" -e "$U/index.php" "$U/api.php?action=compito&k=zzz")
ok "codice troppo corto → 400 ($C)" "$([ "$C" = "400" ] && echo 1)"
C=$(curl -s -b /tmp/cj_edu -o /dev/null -w '%{http_code}' -H "X-EDU-T:$T" -e "$U/index.php" "$U/api.php?action=compito&k=NONESISTE1")
ok "codice inesistente → 404 ($C)" "$([ "$C" = "404" ] && echo 1)"

echo "— COMPITO: consegna —"
R=$(post consegna '{"k":"SAL2026X","classe":"ICPA-5A","risposte":[0,1]}')
ok "tutte giuste: 2 su 2" "$([ "$(echo "$R" | campo n_giuste)" = "2" ] && [ "$(echo "$R" | campo n_domande)" = "2" ] && echo 1)"
R=$(post consegna '{"k":"SAL2026X","classe":"ICPA-5A","risposte":[0,0]}')
ok "una sbagliata: il riscontro dice quale era la giusta" "$([ "$(echo "$R" | campo n_giuste)" = "1" ] && [ "$(echo "$R" | campo esito.1.ok)" = "1" ] && echo 1)"
R=$(post consegna '{"k":"SAL2026X","classe":"ICPA-5A","risposte":["pirata",null]}')
ok "risposte non numeriche → ripulite, zero giuste, nessun errore" "$([ "$(echo "$R" | campo n_giuste)" = "0" ] && echo 1)"
ok "al database arrivano numeri o null, mai testo" "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-edu-state.json"),true); $u=$s["esiti"][count($s["esiti"])-1]; foreach(($u["risposte"]??[]) as $r){ if($r!==null && !is_int($r)){echo 0;exit;} } echo 1;')"
R=$(post consegna '{"k":"SAL2026X","classe":"ICPA-5A","risposte":{"a":1}}')
ok "risposte non in elenco → trattate come vuote" "$([ "$(echo "$R" | campo ok)" = "true" ] && [ "$(echo "$R" | campo n_giuste)" = "0" ] && echo 1)"
R=$(post consegna '{"k":"NONESISTE1","classe":"ICPA-5A","risposte":[0]}')
ok "compito inesistente → err compito" "$([ "$(echo "$R" | campo err)" = "compito" ] && echo 1)"

echo "— chiusura di sicurezza (revisione del 7/11) —"
# 1. X-Forwarded-For non conta: il limite per IP si calcola sull'indirizzo vero
cat > "$TMP/ipcheck.php" << 'EOF'
<?php define('EDU_OK',1); require __DIR__.'/dati/config.php';
$src=file_get_contents(__DIR__.'/api.php'); preg_match('/function edu_ip\(\)\{.*?\n\}/s',$src,$m); eval(substr($m[0],0));
$_SERVER['REMOTE_ADDR']='10.0.0.7'; $_SERVER['HTTP_X_FORWARDED_FOR']='1.2.3.4'; $_SERVER['HTTP_CF_CONNECTING_IP']='5.6.7.8';
echo edu_ip();
EOF
ok "l'IP per il limite è quello della connessione, non X-Forwarded-For" "$([ "$(curl -s "$U/ipcheck.php")" = "10.0.0.7" ] && echo 1)"
# 2. la diagnostica con una chiave non-stringa → 403, non 500
C=$(curl -s -o /dev/null -w '%{http_code}' "$U/api.php?action=diag&k[]=x")
ok "diag con ?k[]=x → 403 pulito, non errore 500 ($C)" "$([ "$C" = "403" ] && echo 1)"
# 3. nel dettaglio di un evento passano solo chiavi note, del tipo giusto
post track '{"classe":"5A","lezione":"salinaio","tipo":"quiz_esito","dettaglio":{"live":"xyz","pct_classe":"tanto","punti":7,"su":10,"xss":"<script>","recap":[{"pct":50,"tot":3,"nick":"Marco"}]}}' >/dev/null
EV=$(php -r '$s=json_decode(file_get_contents("/tmp/supa-edu-state.json"),true); echo json_encode($s["ultimo_evento"]["dettaglio"] ?? null);')
ok "live:\"xyz\" diventa un booleano vero/falso" "$(echo "$EV" | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo is_bool($d["live"]??null)?1:0;')"
ok "pct_classe:\"tanto\" non passa" "$(echo "$EV" | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo array_key_exists("pct_classe",$d)?0:1;')"
ok "punti e su restano numeri" "$(echo "$EV" | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo ($d["punti"]==7 && $d["su"]==10)?1:0;')"
ok "una chiave sconosciuta non passa" "$(echo "$EV" | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo array_key_exists("xss",$d)?0:1;')"
ok "nel recap per domanda restano solo pct e tot, mai un nome" "$(echo "$EV" | php -r '$d=json_decode(stream_get_contents(STDIN),true); $r=$d["recap"][0]??[]; echo (isset($r["pct"]) && isset($r["tot"]) && !isset($r["nick"]))?1:0;')"

echo "— il player resta intero —"
R=$(api "$U/api.php?action=menu")
ok "il menu funziona ancora e porta la didattica del corso" "$([ "$(echo "$R" | campo ok)" = "true" ] && [ "$(echo "$R" | campo corsi.0.didattica.uda.monte_ore)" = "14" ] && echo 1)"

echo; echo "RISULTATO: $P passati, $F falliti"
[ $F -eq 0 ]
