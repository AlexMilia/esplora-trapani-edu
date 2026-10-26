#!/bin/bash
# TEST FASE 2 — stripe.php + stripe-webhook.php contro finto Stripe (8091) e finto Supabase (8092)
U=http://127.0.0.1:8090; P=0; F=0
ok(){ if [ "$2" = "1" ]; then P=$((P+1)); echo "  ✓ $1"; else F=$((F+1)); echo "  ❌ $1"; fi; }
J(){ php -r '$j=json_decode(stream_get_contents(STDIN),true); $k=explode(".",$argv[1]); foreach($k as $x){ if(!is_array($j)||!array_key_exists($x,$j)){echo "";exit;} $j=$j[$x]; } echo is_bool($j)?($j?"true":"false"):(is_array($j)?json_encode($j):$j);' "$1"; }
SLOG(){ [ -f /tmp/stripe-state.json ] && php -r '$s=json_decode(file_get_contents("/tmp/stripe-state.json"),true); echo json_encode($s["log"]);' || echo "[]"; }
SUPALOG(){ php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); echo json_encode($s["log"]);'; }
CLI=11111111-aaaa-bbbb-cccc-000000000001
rm -f /tmp/stripe-state.json /tmp/supa-state.json
call(){ curl -s -m 8 -X POST "$U/stripe.php?azione=$1" -H "Authorization: Bearer ${3:-tok-admin}" -H 'Content-Type: application/json' -d "$2"; }

echo "— A. Autenticazione —"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe.php?azione=crea" -d '{}'); ok "senza token → 401" "$([ "$R" = "401" ] && echo 1)"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe.php?azione=crea" -H "Authorization: Bearer tok-falso" -d "{\"cliente_id\":\"$CLI\"}"); ok "token non valido → 401" "$([ "$R" = "401" ] && echo 1)"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe.php?azione=crea" -H "Authorization: Bearer tok-docente" -d "{\"cliente_id\":\"$CLI\"}"); ok "utente non admin → 403" "$([ "$R" = "403" ] && echo 1)"
ok "nessuna chiamata a Stripe con utenti non autorizzati" "$([ "$(SLOG)" = "[]" ] && echo 1)"

echo "— B. Crea abbonamento (Pro annuale) —"
R=$(call crea "{\"cliente_id\":\"$CLI\",\"piano\":\"pro\",\"periodo\":\"anno\"}")
ok "risposta ok con link, subscription, email del referente" "$([ "$(echo "$R"|J ok)" = "true" ] && [ -n "$(echo "$R"|J link)" ] && [ "$(echo "$R"|J email)" = "verdi@icnuovo.it" ] && echo 1)"
L=$(SLOG)
ok "customer creato con email, nome e metadata cliente_id (idempotency key)" "$(echo "$L" | php -r '$l=json_decode(stream_get_contents(STDIN),true); foreach($l as $x) if($x["p"]=="/v1/customers"&&$x["m"]=="POST"&&$x["body"]["email"]=="verdi@icnuovo.it"&&$x["body"]["metadata"]["cliente_id"]==$argv[1]&&$x["idem"]) {echo 1;exit;} echo 0;' "$CLI")"
ok "subscription: prezzo Pro/anno, invia-fattura, 7 giorni, metadata piano/periodo/cliente" "$(echo "$L" | php -r '$l=json_decode(stream_get_contents(STDIN),true); foreach($l as $x) if($x["p"]=="/v1/subscriptions"&&$x["m"]=="POST"){ $b=$x["body"]; echo ($b["items"][0]["price"]=="price_pro_a"&&$b["collection_method"]=="send_invoice"&&$b["days_until_due"]=="7"&&$b["metadata"]["piano"]=="pro"&&$b["metadata"]["periodo"]=="anno"&&$b["metadata"]["cliente_id"]==$argv[1])?1:0; exit;} echo 0;' "$CLI")"
ok "fattura finalizzata e inviata (parte l'email di Stripe)" "$(echo "$L" | php -r '$l=json_decode(stream_get_contents(STDIN),true); $f=0;$s=0; foreach($l as $x){ if(preg_match("#/finalize$#",$x["p"]))$f=1; if(preg_match("#/send$#",$x["p"]))$s=1; } echo ($f&&$s)?1:0;')"
ok "DB: cliente in_attesa, piano pro/anno, link e id Stripe salvati (chiave service)" "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); $c=$s["cliente"]; echo ($c["abbonamento_stato"]=="in_attesa"&&$c["abbonamento_piano"]=="pro"&&$c["abbonamento_periodo"]=="anno"&&strpos($c["abbonamento_link"],"invoice.stripe.com")!==false&&$c["stripe_customer_id"]&&$c["stripe_subscription_id"])?1:0;')"
ok "tutte le scritture su Supabase usano la chiave service, mai il token dell'utente" "$(SUPALOG | php -r '$l=json_decode(stream_get_contents(STDIN),true); foreach($l as $x) if($x["p"]=="/rest/v1/edu_clienti"&&$x["auth"]!="Bearer service"){echo 0;exit;} echo 1;')"
R=$(call crea "{\"cliente_id\":\"$CLI\",\"piano\":\"base\",\"periodo\":\"mese\"}"); ok "secondo abbonamento sullo stesso cliente → rifiutato ($(echo "$R"|J err | cut -c1-40)…)" "$([ "$(echo "$R"|J ok)" = "false" ] && echo 1)"
R=$(call crea "{\"cliente_id\":\"$CLI\",\"piano\":\"oro\",\"periodo\":\"anno\"}"); ok "piano inesistente → rifiutato" "$([ "$(echo "$R"|J ok)" = "false" ] && echo 1)"

echo "— C. Pausa / riprendi —"
R=$(call pausa "{\"cliente_id\":\"$CLI\"}"); ok "pausa: Stripe pause_collection=void, DB in_pausa + licenza sospesa" "$([ "$(echo "$R"|J stato)" = "in_pausa" ] && echo "$(SLOG)" | grep -q '"behavior":"void"' && [ "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); echo $s["cliente"]["licenza_stato"];')" = "sospesa" ] && echo 1)"
R=$(call riprendi "{\"cliente_id\":\"$CLI\"}"); ok "riprendi: pause_collection rimossa, DB attivo + licenza attiva" "$([ "$(echo "$R"|J stato)" = "attivo" ] && [ "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); echo $s["cliente"]["licenza_stato"];')" = "attiva" ] && echo 1)"

echo "— D. Annulla —"
R=$(call annulla "{\"cliente_id\":\"$CLI\",\"quando\":\"fine_periodo\"}"); ok "a fine periodo: cancel_at_period_end=true, resta attivo, flag nel DB" "$([ "$(echo "$R"|J annulla_a_fine)" = "true" ] && [ "$(echo "$R"|J stato)" = "attivo" ] && [ "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); echo $s["cliente"]["abbonamento_annulla_a_fine"]?1:0;')" = "1" ] && echo 1)"
R=$(call annulla "{\"cliente_id\":\"$CLI\",\"quando\":\"subito\"}"); ok "subito: DELETE su Stripe, DB annullato + licenza scaduta oggi" "$([ "$(echo "$R"|J stato)" = "annullato" ] && echo "$(SLOG)" | grep -q '"m":"DELETE"' && [ "$(php -r '$s=json_decode(file_get_contents("/tmp/supa-state.json"),true); echo $s["cliente"]["licenza_stato"]." ".$s["cliente"]["licenza_fine"];')" = "scaduta $(date -u +%Y-%m-%d)" ] && echo 1)"
R=$(call stato "{\"cliente_id\":\"$CLI\"}"); ok "stato: rilegge da Stripe (canceled → annullato)" "$([ "$(echo "$R"|J stato)" = "annullato" ] && [ "$(echo "$R"|J stripe_status)" = "canceled" ] && echo 1)"

echo "— E. Webhook —"
firma(){ php -r '$t=$argv[2]?:time(); $s=hash_hmac("sha256",$t.".".$argv[1],"whsec_finto"); echo "t=$t,v1=$s";' "$1" "$2"; }
EV='{"id":"evt_paid_1","type":"invoice.paid","data":{"object":{"id":"in_9","status":"paid","subscription":"sub_9","customer":"cus_9","amount_paid":10000,"currency":"eur","hosted_invoice_url":"https://invoice.stripe.com/i/in_9","subscription_details":{"metadata":{"cliente_id":"'$CLI'"}},"lines":{"data":[{"period":{"start":1790000000,"end":1821536000}}]}}}}'
R=$(curl -s -m 5 -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: $(firma "$EV")" -d "$EV"); ok "invoice.paid firmato → applicato" "$([ "$(echo "$R"|J ok)" = "true" ] && echo 1)"
ok "RPC chiamata con chiave service e campi estratti (importo, periodo, link, cliente dal metadata)" "$(SUPALOG | php -r '$l=json_decode(stream_get_contents(STDIN),true); foreach($l as $x) if($x["p"]=="/rest/v1/rpc/edu_abbonamento_evento"){ $e=$x["body"]["p_evento"]; echo ($x["auth"]=="Bearer service"&&$e["tipo"]=="invoice.paid"&&$e["importo_cent"]==10000&&$e["cliente_id"]==$argv[1]&&substr($e["periodo_a"],0,4)=="2027"&&$e["link"]&&$e["subscription"]=="sub_9")?1:0; exit;} echo 0;' "$CLI")"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: t=$(date +%s),v1=deadbeef" -d "$EV"); ok "firma sbagliata → 400" "$([ "$R" = "400" ] && echo 1)"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: $(firma "$EV" 1700000000)" -d "$EV"); ok "firma vecchia (replay) → 400" "$([ "$R" = "400" ] && echo 1)"
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe-webhook.php" -d "$EV"); ok "senza firma → 400" "$([ "$R" = "400" ] && echo 1)"
EV2='{"id":"evt_sub_2","type":"customer.subscription.updated","data":{"object":{"id":"sub_9","status":"active","customer":"cus_9","pause_collection":{"behavior":"void"},"cancel_at_period_end":false,"current_period_end":1821536000,"metadata":{"cliente_id":"'$CLI'"}}}}'
R=$(curl -s -m 5 -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: $(firma "$EV2")" -d "$EV2"); ok "subscription.updated con pausa → pausa=true nell'evento" "$(SUPALOG | php -r '$l=json_decode(stream_get_contents(STDIN),true); foreach(array_reverse($l) as $x) if($x["p"]=="/rest/v1/rpc/edu_abbonamento_evento"){ $e=$x["body"]["p_evento"]; echo ($e["tipo"]=="customer.subscription.updated"&&$e["pausa"]===true)?1:0; exit;} echo 0;')"
EV3='{"id":"evt_x","type":"charge.succeeded","data":{"object":{"id":"ch_1"}}}'
R=$(curl -s -m 5 -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: $(firma "$EV3")" -d "$EV3"); ok "evento non pertinente → 200 ignorato" "$([ "$(echo "$R"|J ignorato)" = "charge.succeeded" ] && echo 1)"
EV4='{"id":"evt_orf","type":"invoice.paid","data":{"object":{"id":"in_o","subscription":"sub_ignota","customer":"cus_o","amount_paid":1,"currency":"eur","lines":{"data":[]}}}}'
R=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -X POST "$U/stripe-webhook.php" -H "Stripe-Signature: $(firma "$EV4")" -d "$EV4"); ok "cliente non ancora agganciato → 500 (Stripe ritenterà)" "$([ "$R" = "500" ] && echo 1)"

echo "— F. Setup prezzi —"
R=$(curl -s -m 8 "$U/stripe-setup.php?k=diag"); ok "setup crea 3 prodotti e 6 prezzi (mese/anno, IVA inclusa) e stampa le righe del config" "$(echo "$R" | grep -c "price_" | xargs -I{} sh -c '[ {} -ge 9 ] && echo 1')"
ok "setup senza chiave → 403" "$([ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$U/stripe-setup.php")" = "403" ] && echo 1)"
ok "prezzi creati con tax_behavior=inclusive e intervalli month/year" "$(SLOG | php -r '$l=json_decode(stream_get_contents(STDIN),true); $n=0; foreach($l as $x) if($x["p"]=="/v1/prices"&&$x["m"]=="POST"&&$x["body"]["tax_behavior"]=="inclusive"&&in_array($x["body"]["recurring"]["interval"],["month","year"])) $n++; echo $n==6?1:0;')"
echo "RISULTATO: $P passati, $F falliti"
