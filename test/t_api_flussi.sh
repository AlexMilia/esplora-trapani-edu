#!/bin/bash
# TRACCIA C — player e API con Apache + cache simulate (Supabase non raggiungibile dalla sandbox)
U=http://127.0.0.1; A=/var/www/html/project/edu/app; P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }
rm -f $A/dati/cache_*.json $A/dati/rl/* 2>/dev/null
php -r '
$mk=function($slug,$nome,$piano,$attiva=true){ return ["t"=>time(),"dati"=>["id"=>"id-".$slug,"slug"=>$slug,"nome"=>$nome,"brand"=>["titolo"=>$nome],"progetto_legacy"=>null,"piano"=>$piano,"limiti"=>["quiz_live"=>$piano!=="base","nome"=>ucfirst($piano)],"licenza_stato"=>$attiva?"attiva":"scaduta","licenza_fine"=>null,"attiva"=>$attiva,"contatto_email"=>"info@x.it","piattaforma"=>"Esplora Trapani Edu"]]; };
$A="/var/www/html/project/edu/app/dati/";
file_put_contents($A."cache_cliente_ic-nuovo.json", json_encode($mk("ic-nuovo","IC Nuovo","base")));
file_put_contents($A."cache_cliente_scaduto.json", json_encode($mk("scaduto","Cliente Scaduto","pro",false)));
$corsi=[["id"=>"il-mio-paese","uuid"=>"u-paese","tit"=>"Il mio paese","em"=>"P","stato"=>"pubblicato","origine"=>"proprio","lezioni"=>[["id"=>"la-piazza","tit"=>"La piazza","stato"=>"pubblicata"]]]];
file_put_contents($A."cache_catalogo_ic-nuovo_".date("Ymd").".json", json_encode(["t"=>time(),"dati"=>$corsi]));
file_put_contents($A."cache_lez_ic-nuovo_la-piazza.json", json_encode(["t"=>time(),"dati"=>["id"=>"la-piazza","tit"=>"La piazza","video"=>[["guid"=>"g1"]],"tappe"=>[],"quiz"=>[["q"=>"D","opts"=>["a","b"],"ok"=>0]],"corso"=>["id"=>"il-mio-paese","tit"=>"Il mio paese"]]]));
'
chown -R www-data:www-data $A/dati
# sessione: apro la pagina del tenant (senza barra → 301 → con barra) e prendo token e chiave dalla pagina
R=$(curl -s -o /dev/null -w "%{http_code}" "$U/project/edu/ic-nuovo"); ok "senza barra finale → 301" "$([ "$R" = "301" ] && echo 1)"
PAG=$(curl -s -c /tmp/cjA "$U/project/edu/ic-nuovo/")
T=$(echo "$PAG" | grep -o 'window.EDU_T = "[^"]*"' | cut -d'"' -f2); K=$(echo "$PAG" | grep -o 'window.EDU_K = "[^"]*"' | cut -d'"' -f2)
ok "pagina del tenant con token e chiave di sessione" "$([ -n "$T" ] && [ -n "$K" ] && echo 1)"
ok "tenant risolto dal percorso (EDU_C=ic-nuovo)" "$(echo "$PAG" | grep -q 'window.EDU_C = "ic-nuovo"' && echo 1)"
DEC='$j=json_decode(stream_get_contents(STDIN),true); if(isset($j["enc"])){echo openssl_decrypt(base64_decode($j["data"]),"aes-256-cbc",hex2bin($argv[1]),OPENSSL_RAW_DATA,base64_decode($j["iv"]));}else echo json_encode($j);'
C="-s -b /tmp/cjA -H X-EDU-T:$T -e $U/project/edu/ic-nuovo/"
MENU=$(curl $C "$U/project/edu/app/api.php?action=menu&c=ic-nuovo" | php -r "$DEC" "$K")
ok "menu cifrato e decifrabile con la chiave di sessione" "$(echo "$MENU" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo ($j["ok"]??false)?1:0;')"
ok "menu: brand, corso e limiti del piano base (quiz_live=false)" "$(echo "$MENU" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo ($j["cliente"]["nome"]=="IC Nuovo" && count($j["corsi"])==1 && $j["cliente"]["limiti"]["quiz_live"]===false)?1:0;')"
LEZ=$(curl $C "$U/project/edu/app/api.php?action=lezione&id=la-piazza&c=ic-nuovo" | php -r "$DEC" "$K")
ok "lezione del tenant servita" "$(echo "$LEZ" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo ($j["lezione"]["tit"]??"")=="La piazza"?1:0;')"
R=$(curl -s -b /tmp/cjA -e "$U/project/edu/ic-nuovo/" -o /dev/null -w "%{http_code}" "$U/project/edu/app/api.php?action=menu&c=ic-nuovo"); ok "senza token X-EDU-T → rifiutato ($R)" "$([ "$R" = "403" ] && echo 1)"
R=$(curl -s -b /tmp/cjA -H "X-EDU-T:$T" -e "https://sito-altro.it/" -o /dev/null -w "%{http_code}" "$U/project/edu/app/api.php?action=menu&c=ic-nuovo"); ok "referer estraneo → rifiutato ($R)" "$([ "$R" = "403" ] && echo 1)"
R=$(curl $C "$U/project/edu/app/api.php?action=lezione&id=la-piazza&c=scaduto" -o /dev/null -w "%{http_code}"); ok "cliente con licenza scaduta → 403 sulla lezione" "$([ "$R" = "403" ] && echo 1)"
SC=$(curl $C "$U/project/edu/app/api.php?action=menu&c=scaduto" | php -r "$DEC" "$K"); ok "menu del cliente scaduto: ok=false, err=licenza (messaggio gentile nel player)" "$(echo "$SC" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo (($j["ok"]??true)===false && ($j["err"]??"")=="licenza")?1:0;')"
R=$(curl $C "$U/project/edu/app/api.php?action=lezione&id=la-piazza&c=altro-cliente" -o /dev/null -w "%{http_code}"); ok "lezione chiesta con un tenant inesistente → $R (non 200)" "$([ "$R" != "200" ] && echo 1)"
R=$(curl $C -X POST -H 'Content-Type: application/json' -d '{"classe":"ICNU-4B-AB12","lezione":"la-piazza","tipo":"lezione_avviata","dettaglio":{}}' "$U/project/edu/app/api.php?action=track&c=ic-nuovo" -o /dev/null -w "%{http_code}"); ok "track accettato dal server (Supabase non raggiungibile: risponde comunque senza 500) → $R" "$([ "$R" = "200" ] && echo 1)"
ok "cache del catalogo scritta per tenant e per giorno" "$([ -f $A/dati/cache_catalogo_ic-nuovo_$(date +%Y%m%d).json ] && echo 1)"
R=$(curl -s -o /dev/null -w "%{http_code}" "$U/project/edu/app/dati/config.php"); ok "dati/config.php negato dal web ($R)" "$([ "$R" = "403" ] && echo 1)"
R=$(curl -s -o /dev/null -w "%{http_code}" "$U/project/edu/app/dati/cache_cliente_ic-nuovo.json"); ok "cache negata dal web ($R)" "$([ "$R" = "403" ] && echo 1)"
echo "RISULTATO: $P passati, $F falliti"
