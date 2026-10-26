#!/bin/bash
# TEST API (catalogo) — api.php servito dal server PHP integrato, con la cache precompilata
# al posto di Supabase (così gira offline). Avvia e spegne da solo `php -S` sulla porta 8076.
# Uso: bash test/t_api26.sh
cd "$(dirname "$0")/../app" || exit 1
U=http://127.0.0.1:8076
CFG_TMP=0; [ -f dati/config.php ] || { cp dati/config.example.php dati/config.php; CFG_TMP=1; }
php -S 127.0.0.1:8076 -t . >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV 2>/dev/null; rm -f test_boot.php dati/cache_*.json; rm -rf dati/rl; [ $CFG_TMP = 1 ] && rm -f dati/config.php dati/log.txt' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "$U/index.php" && break; sleep 0.3; done
rm -f dati/cache_*.json
cat > test_boot.php << 'EOF'
<?php session_start(); if(!isset($_SESSION['edu_t']))$_SESSION['edu_t']=bin2hex(random_bytes(24)); if(!isset($_SESSION['edu_k']))$_SESSION['edu_k']=bin2hex(random_bytes(32)); echo json_encode(['t'=>$_SESSION['edu_t'],'k'=>$_SESSION['edu_k']]);
EOF
php -r '
$t=time();
$mk=function($slug,$nome,$attiva=true){ return ["t"=>time(),"dati"=>["id"=>"id-".$slug,"slug"=>$slug,"nome"=>$nome,"brand"=>["titolo"=>$nome],"progetto_legacy"=>"sale-in-classe","piano"=>"pro","limiti"=>["quiz_live"=>true,"nome"=>"Pro"],"licenza_stato"=>$attiva?"attiva":"scaduta","licenza_fine"=>null,"attiva"=>$attiva,"contatto_email"=>"info@x.it","piattaforma"=>"Esplora Trapani Edu"]]; };
file_put_contents("dati/cache_cliente_salina-culcasi.json", json_encode($mk("salina-culcasi","Salina Culcasi")));
$corsi=[["id"=>"goccia","uuid"=>"u-goc","tit"=>"Il viaggio di una goccia","em"=>"D","stato"=>"pubblicato","origine"=>"proprio","licenza_a"=>null,"mascotte"=>["nome"=>"Coccio"],"lezioni"=>[["id"=>"goccia-mare","tit"=>"Il mare","stato"=>"pubblicata"]]]];
file_put_contents("dati/cache_catalogo_salina-culcasi_".date("Ymd").".json", json_encode(["t"=>$t,"dati"=>$corsi]));
file_put_contents("dati/cache_lez_salina-culcasi_goccia-mare.json", json_encode(["t"=>$t,"dati"=>["id"=>"goccia-mare","tit"=>"Il mare","video"=>[["guid"=>"g1","audio"=>["url"=>"https://cdn.x.it/mare.mp3","vol"=>35,"loop"=>true,"duck"=>true]]],"corso"=>["id"=>"goccia","tit"=>"Il viaggio di una goccia","prologo"=>"Da qualche parte","mascotte"=>["nome"=>"Coccio","img"=>"https://x.it/c.png"]]]]));
'
B=$(curl -s -c /tmp/cj "$U/test_boot.php")
T=$(echo "$B" | php -r '$j=json_decode(stream_get_contents(STDIN),true);echo $j["t"];')
K=$(echo "$B" | php -r '$j=json_decode(stream_get_contents(STDIN),true);echo $j["k"];')
DEC='$j=json_decode(stream_get_contents(STDIN),true); if(isset($j["enc"])){echo openssl_decrypt(base64_decode($j["data"]),"aes-256-cbc",hex2bin($argv[1]),OPENSSL_RAW_DATA,base64_decode($j["iv"]));}else echo json_encode($j);'
P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }

echo "== MENU con codice classe =="
M=$(curl -s -b /tmp/cj -H "X-EDU-T:$T" -e "$U/index.php" "$U/api.php?action=menu&c=salina-culcasi&classe=ICPA-5A-X1" | php -r "$DEC" "$K")
echo "$M" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo "   ok=".var_export($j["ok"],true)." corsi=".count($j["corsi"])." origine=".$j["corsi"][0]["origine"]." mascotte=".($j["corsi"][0]["mascotte"]["nome"]??"-")."\n";'
ok "menu cifrato, decifrato con la chiave di sessione, 1 corso proprio con mascotte" "$(echo "$M" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo ($j["ok"]===true && count($j["corsi"])==1 && $j["corsi"][0]["origine"]=="proprio" && $j["corsi"][0]["mascotte"]["nome"]=="Coccio")?1:0;')"

echo "== LEZIONE: corso, mascotte, audio =="
L=$(curl -s -b /tmp/cj -H "X-EDU-T:$T" -e "$U/index.php" "$U/api.php?action=lezione&id=goccia-mare&c=salina-culcasi&classe=ICPA-5A-X1" | php -r "$DEC" "$K")
echo "$L" | php -r '$j=json_decode(stream_get_contents(STDIN),true); $l=$j["lezione"]; echo "   corso=".$l["corso"]["id"]." mascotte=".$l["corso"]["mascotte"]["nome"]." audio=".$l["video"][0]["audio"]["url"]."\n";'
ok "lezione con corso, mascotte del corso e audio di sottofondo della clip" "$(echo "$L" | php -r '$j=json_decode(stream_get_contents(STDIN),true); $l=$j["lezione"]??[]; echo (($l["corso"]["id"]??"")=="goccia" && ($l["corso"]["mascotte"]["nome"]??"")=="Coccio" && ($l["video"][0]["audio"]["url"]??"")=="https://cdn.x.it/mare.mp3")?1:0;')"

echo "== sicurezza =="
R=$(curl -s -b /tmp/cj -e "$U/index.php" -o /dev/null -w "%{http_code}" "$U/api.php?action=menu&c=salina-culcasi"); ok "senza token X-EDU-T → rifiutato ($R)" "$([ "$R" = "403" ] && echo 1)"
R=$(curl -s -b /tmp/cj -H "X-EDU-T:$T" -e "https://sito-altro.it/" -o /dev/null -w "%{http_code}" "$U/api.php?action=menu&c=salina-culcasi"); ok "referer estraneo → rifiutato ($R)" "$([ "$R" = "403" ] && echo 1)"

echo "== cache separata per giorno =="
ls dati/ | grep catalogo | sed 's/^/   /'
ok "file di cache del catalogo datato $(date +%Y%m%d)" "$(ls dati/ | grep -q "cache_catalogo_salina-culcasi_$(date +%Y%m%d).json" && echo 1)"
echo; echo "Passati: $P — Falliti: $F"
[ $F -eq 0 ]
