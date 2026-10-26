<?php
/* =====================================================================
   SALE IN CLASSE · PLAYER GENERICO — index.php (guscio + bootstrap sicurezza)
   Istanza: ANTICHI MESTIERI DI TRAPANI (brand in $BRAND, progetto in api.php)
   I contenuti delle lezioni NON sono in questo file: vivono su Supabase
   e vengono consegnati da api.php (token di sessione + risposta cifrata
   AES). Chi salva questa pagina si porta via solo il motore.
   Pattern: progetto Odissea/mareandmore (agosto 2026).
   ===================================================================== */
session_start();
/* host canonico: Aruba fa 301 non-www -> www e il preflight CORS di
   api.php muore sul redirect (X-EDU-T = richiesta preflighted); inoltre la
   sessione vive per host. Quindi: pagina SEMPRE su www. (fix 24/08) */
if (($_SERVER['HTTP_HOST'] ?? '') === 'alessandromilia.it') {
  header('Location: https://www.alessandromilia.it' . ($_SERVER['REQUEST_URI'] ?? '/'), true, 301);
  exit;
}
define('EDU_OK', 1);
require __DIR__ . '/dati/config.php';
/* ---- TENANT (Fase 2 SaaS): ?c=slug, /edu/{slug}/, o default del config ---- */
function edu_tenant_slug(){
  global $EDU_TENANT_DEFAULT;
  $s = isset($_GET['c']) ? strtolower(trim($_GET['c'])) : '';
  if($s === '' && isset($_SERVER['REQUEST_URI'])
     && preg_match('#/edu/([a-z0-9][a-z0-9-]{1,40})/#', strtolower($_SERVER['REQUEST_URI']), $m)
     && !in_array($m[1], ['app','mestieri','saline'], true) && !preg_match('/^ver\d+$/', $m[1])){
    $s = $m[1];
  }
  if($s === '' && isset($EDU_TENANT_DEFAULT)) $s = (string)$EDU_TENANT_DEFAULT;
  return preg_match('/^[a-z0-9][a-z0-9-]{1,40}$/', $s) ? $s : '';
}
$EDU_C = edu_tenant_slug();
/* ---- BRAND del progetto (sovrascrivibile da dati/config.php con $EDU_BRAND) ----
   Questo player e' generico: il progetto Supabase lo decide api.php
   ($EDU_PROGETTO in dati/config.php), qui solo titoli, mascotte e colori. */
$BRAND = array_merge(array(
  'titolo'      => 'Antichi Mestieri di Trapani',
  'sottotitolo' => 'Esplora Trapani · Sale in Classe',
  'claim'       => 'Scegli il mestiere di oggi: entrerai nella bottega in 360°.',
  'mascotte'    => 'la guida di Esplora Trapani',   /* nome del personaggio (es. "Coccio di sale") */
  'mascotte_img'=> 'https://www.alessandromilia.it/project/esplora/mascotte.png',
  'mascotte_emoji'=> '🧭',
  'congedo'     => 'Adesso… andate a vedere dal vivo gli artigiani di Trapani!<br>Vi aspettano nelle loro botteghe 🛠️',
  'ko'          => '💧 Ops… non era questa! Ma ogni artigiano ha sbagliato mille volte prima di diventare maestro: riprovate!',
), isset($EDU_BRAND) && is_array($EDU_BRAND) ? $EDU_BRAND : array());
$B = function($k){ global $BRAND; return htmlspecialchars($BRAND[$k], ENT_QUOTES, 'UTF-8'); };
if(!isset($_SESSION['edu_t'])){ $_SESSION['edu_t'] = bin2hex(random_bytes(24)); }
if(!isset($_SESSION['edu_k'])){ $_SESSION['edu_k'] = bin2hex(random_bytes(32)); }
header('X-Content-Type-Options: nosniff');
/* strict-origin-when-cross-origin: verso Bunny parte la sola origine del
   sito, che soddisfa l'allow-list referrer del CDN. NON usare
   'same-origin': azzererebbe il referrer verso Bunny (403 sui video). */
header('Referrer-Policy: strict-origin-when-cross-origin');
edu_log('view', isset($_SERVER['QUERY_STRING']) ? $_SERVER['QUERY_STRING'] : '');
?>
<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<link rel="icon" href="<?php echo $B('mascotte_img'); ?>">
<title><?php echo $B('titolo'); ?> — Lezioni</title>
<script src="https://aframe.io/releases/1.5.0/aframe.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&display=swap" rel="stylesheet">
<style>
  /* --rosaTxt: variante scura del rosa per TESTO su fondo chiaro (contrasto WCAG AA) */
  :root{--rosa:#e8788a;--rosaTxt:#b8506a;--oro:#c9a15a;--ink:#3a2e2a;--sale:#faf7f2;--blu:#2e6e8e;--verde:#5a8a5a}
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%;background:#0b0d10;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;overflow:hidden}

  .teachbar{position:fixed;top:0;left:0;right:0;z-index:40;display:flex;align-items:center;gap:10px;
    padding:10px 14px;background:linear-gradient(180deg,rgba(11,13,16,.85),rgba(11,13,16,0))}
  .teachbar .tit{color:#fff;font-weight:700;font-size:15px}
  .teachbar .tit em{color:var(--rosa);font-style:normal}
  .teachbar .sp{margin-left:auto}
  .tbtn{border:1px solid rgba(255,255,255,.35);background:rgba(17,21,27,.8);color:#fff;border-radius:999px;
    padding:10px 16px;font-size:14px;cursor:pointer;font-family:inherit}

  .cimg{width:82px;height:auto;display:block;filter:drop-shadow(0 4px 10px rgba(0,0,0,.4))}
  .cimg-mid{width:104px;height:auto;display:inline-block;filter:drop-shadow(0 6px 14px rgba(0,0,0,.25))}
  .cimg-mini{height:24px;width:auto;vertical-align:-5px}
  .cocciu{position:fixed;left:14px;bottom:56px;z-index:45;display:flex;align-items:flex-end;gap:10px;max-width:min(560px,86vw)}
  .cocciu .body{transition:transform .3s}
  .cocciu.brilla .body{animation:brilla .8s ease}
  .cocciu.sciolto .body{animation:sciolto 1.2s ease}
  @keyframes brilla{0%{transform:scale(1)}40%{transform:scale(1.25) rotate(-6deg)}100%{transform:scale(1)}}
  @keyframes sciolto{0%{transform:scale(1)}30%{transform:scale(.82) translateY(9px)}70%{transform:scale(.9) translateY(5px)}100%{transform:scale(1)}}
  .cocciu .say{background:#fff;border-radius:4px 18px 18px 18px;padding:12px 16px;font-size:16px;color:var(--ink);
    box-shadow:0 6px 18px rgba(0,0,0,.3);line-height:1.45;transition:opacity .8s}
  .cocciu.fade .say{opacity:0}
  body.cc-on .cocciu{bottom:calc(128px + env(safe-area-inset-bottom,0px))}

  .ovl{position:fixed;inset:0;z-index:60;background:rgba(11,13,16,.78);display:none;
    align-items:center;justify-content:center;padding:20px}
  .ovl.on{display:flex}
  .card{background:var(--sale);border-radius:22px;max-width:680px;width:100%;padding:30px 26px;text-align:center;
    box-shadow:0 20px 60px rgba(0,0,0,.5);max-height:88vh;overflow:auto}
  .card h1{font-size:26px;color:var(--ink);margin-top:10px}
  .card h1 em{color:var(--rosaTxt);font-style:normal}
  .card p{font-size:16px;color:var(--ink);opacity:.85;margin-top:10px;line-height:1.5}
  .bigbtn{border:none;background:var(--rosa);color:#fff;border-radius:999px;padding:16px 34px;font-size:18px;
    font-weight:700;cursor:pointer;margin-top:18px;font-family:inherit}
  .bigbtn.oro{background:var(--oro);color:var(--ink)}   /* AA: ink su oro 5.4:1 */

  /* menu lezioni */
  .lezioni{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:18px}
  .lez{border:none;border-radius:18px;padding:20px 16px;text-align:left;cursor:pointer;color:#fff;
    box-shadow:0 8px 22px rgba(58,46,42,.18);font-family:inherit;transition:transform .12s}
  .lez:active{transform:scale(.98)}
  .lez .em{font-size:32px}
  .lez h3{font-size:18px;margin-top:6px}
  .lez p{font-size:13px;opacity:.92;margin-top:4px;color:#fff}
  .lez small{display:block;margin-top:8px;font-size:11px;opacity:.8}
  .lez.rosa{background:linear-gradient(150deg,var(--rosa),#c95a6e)}
  .lez.oro{background:linear-gradient(150deg,var(--oro),#a57f3b)}
  .lez.soon{background:#e7e0d4;color:#9a8f7d;cursor:default;box-shadow:none}
  .lez.soon p{color:#9a8f7d}

  /* selettore livello (Primaria / Medie) */
  .livsel{margin-top:16px}
  .livsel .lbl{font-size:13px;color:var(--ink);opacity:.7;display:block;margin-bottom:8px}
  .livsel .seg{display:inline-flex;background:#ece4d6;border-radius:999px;padding:4px;gap:4px}
  .livsel .seg button{border:none;background:transparent;color:var(--ink);border-radius:999px;
    padding:9px 18px;font-size:14px;font-weight:600;cursor:pointer;font-family:inherit}
  .livsel .seg button.on{background:var(--rosaTxt);color:#fff}

  #scoperta .card{text-align:left}
  #scoperta .head{display:flex;gap:14px;align-items:center}
  #scoperta .head .em{font-size:48px}
  #scoperta h2{font-size:22px;color:var(--rosaTxt)}
  #scoperta p{margin-top:12px}

  /* elenco scoperte (alternativa testuale al 360 + ripasso) */
  #elenco .card{text-align:left}
  .elItem{display:flex;gap:12px;align-items:flex-start;margin-top:14px;background:#fff;
    border-radius:14px;padding:14px 16px;box-shadow:0 3px 10px rgba(58,46,42,.08)}
  .elItem .em{font-size:30px;line-height:1}
  .elItem h3{font-size:16px;color:var(--rosaTxt)}
  .elItem p{font-size:14px;margin-top:4px;opacity:.9}
  .elItem.todo{opacity:.55}
  .elItem.todo h3::after{content:' · ancora da trovare!';font-size:12px;color:var(--oro)}

  /* alta leggibilità (DSA) */
  /* ================= ACCESSIBILITÀ =================
     Selettore in home: Standard · Ipovedenti · LIS.
     IPOVEDENTI (body.ipo) — parametri WCAG 2.2 applicati:
       1.4.6  contrasto testo ≥ 7:1 (AAA): #111 su #fff = 18.9:1, #fff su #111
       1.4.4  testo ridimensionabile: scala 2× (base 24px = "testo grande" 18pt)
       1.4.8  interlinea ≥ 1.5, paragrafi ≥ 2×, testo MAI giustificato
       1.4.12 letter-spacing ≥ .12em, word-spacing ≥ .16em
       2.5.5  target ≥ 44×44 px (AAA) — qui ≥ 64 px
       2.3.3  niente animazioni non essenziali; hotspot 2× più grandi
       + lettura vocale (speechSynthesis it-IT) di intro, scoperte, quiz */
  .accsel{margin-top:14px}
  .accsel .lbl{font-size:13px;color:var(--ink);opacity:.7;display:block;margin-bottom:8px}
  .accsel .seg{display:inline-flex;background:#ece4d6;border-radius:999px;padding:4px;gap:4px;flex-wrap:wrap;justify-content:center}
  .accsel .seg button{border:none;background:transparent;color:var(--ink);border-radius:999px;padding:8px 14px;font-size:14px;font-weight:700;cursor:pointer;font-family:inherit}
  .accsel .seg button.on{background:var(--blu);color:#fff}
  .lez .accbadge{display:inline-block;margin-left:6px;font-size:11px;background:rgba(255,255,255,.25);border-radius:999px;padding:2px 8px}
  .lez.noacc{opacity:.45;filter:grayscale(.6)}

  body.ipo{--ink:#111;--sale:#fff;--rosaTxt:#8a1e3c;--blu:#0b3d66;--oro:#6b4e00}
  body.ipo,body.ipo button,body.ipo input{font-family:'Atkinson Hyperlegible',-apple-system,sans-serif;letter-spacing:.12em;word-spacing:.16em}
  body.ipo .card{max-width:1100px;padding:36px 34px;border:4px solid #111;border-radius:10px;text-align:left}
  body.ipo .card h1{font-size:48px;line-height:1.3;color:#111;opacity:1}
  body.ipo .card h2{font-size:42px;line-height:1.3;color:#111}
  body.ipo .card p,body.ipo #scoperta p,body.ipo .elItem p,body.ipo #scTxt{font-size:32px;line-height:1.6;color:#111;opacity:1;margin-top:28px;text-align:left}
  body.ipo .livsel .lbl,body.ipo .accsel .lbl{font-size:24px;opacity:1}
  body.ipo .livsel .seg button,body.ipo .accsel .seg button{font-size:24px;padding:16px 26px;min-height:64px;border:3px solid #111;background:#fff;color:#111}
  body.ipo .livsel .seg button.on,body.ipo .accsel .seg button.on{background:#111;color:#fff}
  body.ipo .lez{padding:26px 22px;min-height:150px;border:4px solid #111;border-radius:10px;background:#fff!important;color:#111}
  body.ipo .lez h3{font-size:32px;line-height:1.3;color:#111}
  body.ipo .lez p{font-size:22px;color:#111;opacity:1;line-height:1.5}
  body.ipo .lez small{font-size:20px;opacity:1;color:#111}
  body.ipo .lez .em{font-size:54px}
  body.ipo .lez:focus-visible,body.ipo button:focus-visible{outline:6px solid #ffbf00;outline-offset:3px}
  body.ipo .teachbar{background:#111;padding:12px 16px}
  body.ipo .teachbar .tit{font-size:22px}
  body.ipo .tbtn{font-size:22px;padding:14px 22px;min-height:64px;border:3px solid #fff;background:#111;color:#fff}
  body.ipo .tbtn .lbl{display:inline}
  body.ipo .pill{font-size:28px;padding:18px 28px;background:#111;color:#fff;border:3px solid #fff;top:100px;line-height:1.4;max-width:92vw}
  body.ipo .cocciu .say{font-size:28px;line-height:1.5;background:#fff;color:#111;border:4px solid #111;max-width:min(900px,80vw);padding:18px 22px}
  body.ipo .cocciu{bottom:120px}
  body.ipo #ccBox{font-size:40px;line-height:1.5;background:#111;color:#fff;padding:14px 24px}
  body.ipo #quiz .q{font-size:40px;line-height:1.4;color:#111;text-align:left}
  body.ipo #quiz .opt{font-size:32px;line-height:1.5;padding:22px 26px;min-height:72px;margin-top:20px;border:4px solid #111;background:#fff;color:#111;text-align:left}
  body.ipo #quiz .opt.giusta{background:#0a5c2b;color:#fff;border-color:#0a5c2b}
  body.ipo #quiz .opt.sbagliata{background:#8a1e3c;color:#fff;border-color:#8a1e3c}
  body.ipo #quiz .esito,body.ipo #qEsito{font-size:30px;line-height:1.5;margin-top:26px;color:#111}
  body.ipo .bigbtn{font-size:32px;padding:22px 36px;min-height:72px;border:4px solid #111;background:#111;color:#fff;margin-top:28px}
  body.ipo .closex{font-size:40px;width:72px;height:72px;color:#111}
  body.ipo #seekbar{background:#111;padding:14px 18px}
  body.ipo #seekbar span{font-size:24px}
  body.ipo #seek{height:44px}
  body.ipo .elItem h3{font-size:30px}
  body.ipo .ovl{background:rgba(0,0,0,.9)}
  body.ipo *{animation:none!important;transition:none!important}
  #ttsBar{display:none;position:fixed;left:50%;transform:translateX(-50%);bottom:110px;z-index:120;gap:10px}
  body.ipo #ttsBar.on{display:flex}
  #ttsBar button{font-size:26px;min-height:64px;padding:12px 26px;border:4px solid #fff;background:#111;color:#fff;border-radius:10px;cursor:pointer;font-family:inherit}

  /* LIS (body.lis): finestra dell'interprete in basso a destra, sempre
     sopra il 360 e sotto gli overlay; sincronizzata con il video della lezione. */
  #lisBox{display:none;position:fixed;right:16px;bottom:96px;z-index:36;width:min(34vw,420px);aspect-ratio:9/12;
    background:#000;border:3px solid #fff;border-radius:14px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.6)}
  body.lis #lisBox.on{display:block}
  #lisBox video{width:100%;height:100%;object-fit:cover;display:block}
  #lisBox .lisTag{position:absolute;left:8px;top:8px;background:rgba(0,0,0,.7);color:#fff;font-size:12px;font-weight:700;padding:4px 10px;border-radius:999px}
  #lisBox .lisSize{position:absolute;right:8px;top:8px;background:rgba(0,0,0,.7);color:#fff;border:0;border-radius:999px;width:34px;height:34px;cursor:pointer;font-size:16px}
  #lisBox.big{width:min(48vw,640px);aspect-ratio:4/3}
  #lisBox .lisMiss{position:absolute;inset:0;display:none;align-items:center;justify-content:center;text-align:center;color:#fff;font-size:14px;padding:14px;background:#222}
  #lisBox.miss .lisMiss{display:flex}
  body.lis .cocciu{right:auto;left:16px}
  @media (max-width:900px){ #lisBox{width:42vw;bottom:120px} body.ipo .card h1{font-size:34px} body.ipo .card p,body.ipo #scTxt,body.ipo #quiz .opt{font-size:24px} body.ipo #quiz .q{font-size:28px} }

  body.dsa,body.dsa button,body.dsa input{font-family:'Atkinson Hyperlegible',-apple-system,sans-serif}
  body.dsa .card p,body.dsa #scoperta p,body.dsa .elItem p{font-size:18px;line-height:1.8;letter-spacing:.01em;opacity:1}
  body.dsa .cocciu .say{font-size:17px;line-height:1.7}
  body.dsa #ccBox{font-size:24px;line-height:1.6}
  body.dsa #quiz .opt{font-size:18px;line-height:1.6}

  /* tastiera */
  button:focus-visible{outline:3px solid var(--oro);outline-offset:2px}

  @media (prefers-reduced-motion: reduce){
    .cocciu.brilla .body,.cocciu.sciolto .body{animation:none}
    .lez,.cocciu .body{transition:none}
  }

  #quiz .q{font-size:20px;font-weight:700;color:var(--ink);margin-top:6px}
  #quiz .opt{display:block;width:100%;text-align:left;margin-top:12px;border:2px solid rgba(46,110,142,.35);
    background:#fff;border-radius:14px;padding:16px 18px;font-size:17px;cursor:pointer;font-family:inherit}
  #quiz .opt.giusta{border-color:var(--verde);background:#eef6ee}
  #quiz .opt.sbagliata{border-color:#c66;background:#fbeeee}
  #quiz .esito{margin-top:12px;font-size:16px;min-height:24px}
  #quiz .sapevi{margin-top:14px;background:var(--sale);border:2px solid #eadfce;border-radius:14px;padding:12px 14px;text-align:left}
  #quiz .sapevi .tit{font-weight:800;color:var(--rosaTxt);font-size:13px;text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px}
  #quiz .sapevi p{font-size:16px;line-height:1.5;margin:0}
  #quiz .sapevi img{width:100%;border-radius:10px;margin-top:10px;display:block}
  body.ipo #quiz .sapevi{border:4px solid #111;background:#fff}
  body.ipo #quiz .sapevi p{font-size:26px;line-height:1.5;color:#111}
  body.dsa #quiz .sapevi p{font-size:18px;line-height:1.6}
  /* Intro del corso (prologo a schermo intero) */
  #prologoOvl{position:fixed;inset:0;z-index:960;display:none;background:var(--sale);
    align-items:center;justify-content:center;padding:24px}
  #prologoOvl.on{display:flex}
  #prologoOvl .box{max-width:820px;text-align:center;animation:prologoIn 1.1s ease}
  #prologoTxt{white-space:pre-line;font-size:clamp(19px,2.6vw,30px);line-height:1.65;
    color:var(--ink);font-style:italic}
  @keyframes prologoIn{from{opacity:0;transform:translateY(14px)}to{opacity:1}}
  body.ipo #prologoTxt{font-size:clamp(24px,3.2vw,38px);font-style:normal;color:#111;line-height:1.7}
  body.dsa #prologoTxt{font-style:normal;line-height:1.8}

  .pill{position:fixed;top:64px;left:50%;transform:translateX(-50%);z-index:35;background:rgba(184,80,106,.96);
    color:#fff;border-radius:999px;padding:10px 20px;font-size:15px;font-weight:600;display:none;box-shadow:0 6px 18px rgba(0,0,0,.3)}
  .pill.on{display:block}
  #tarBox{position:fixed;bottom:64px;right:14px;z-index:70;background:rgba(17,21,27,.92);color:#0f0;
    font-family:monospace;font-size:14px;padding:10px 14px;border-radius:10px;display:none}

  /* seek bar */
  #seekbar{display:none;position:fixed;left:0;right:0;bottom:0;z-index:38;align-items:center;gap:10px;
    padding:10px 14px calc(10px + env(safe-area-inset-bottom,0px));
    background:linear-gradient(0deg,rgba(11,13,16,.85),rgba(11,13,16,0))}
  #seek{flex:1;accent-color:var(--rosa);height:28px;cursor:pointer}
  #seekbar span{color:#fff;font-size:12px;white-space:nowrap;font-variant-numeric:tabular-nums}
  #seekClip{opacity:.7}

  /* X di chiusura sulle card */
  .card{position:relative}
  .closex{position:absolute;top:10px;right:12px;border:none;background:#ece4d6;color:var(--ink);
    width:40px;height:40px;border-radius:50%;font-size:17px;cursor:pointer;font-family:inherit;line-height:1}

  /* sottotitoli */
  /* ---------- VIDEO MASCOTTE COCCIO (a tutto schermo) ---------- */
  #coccioOvl{position:fixed;inset:0;z-index:200;background:#0d0b0a;display:none;
    align-items:center;justify-content:center}
  #coccioOvl.on{display:flex}
  #coccioStage{position:relative;width:100%;height:100%;max-width:calc(100vh * 16 / 9);
    max-height:calc(100vw * 9 / 16);margin:auto}
  #coccioStage iframe,#coccioStage video{position:absolute;inset:0;width:100%;height:100%;border:0;background:#0d0b0a}
  #coccioSkip{position:fixed;z-index:210;right:calc(16px + env(safe-area-inset-right,0px));
    bottom:calc(16px + env(safe-area-inset-bottom,0px));border:0;border-radius:999px;
    padding:11px 20px;font-size:15px;font-weight:800;font-family:inherit;cursor:pointer;
    background:rgba(250,247,242,.92);color:#3a2e2a;box-shadow:0 4px 18px rgba(0,0,0,.4)}
  #coccioAttesa{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);
    color:#faf7f2;font-size:15px;opacity:.85;text-align:center}

  /* ---------- SPLASH D'AVVIO (dà il "via libera" all'audio) ---------- */
  #avvio{position:fixed;inset:0;z-index:190;background:linear-gradient(160deg,#fdf6f7,#f4ece0);
    display:none;flex-direction:column;align-items:center;justify-content:center;gap:18px;padding:24px;text-align:center}
  #avvio.on{display:flex}
  #avvio img{width:min(180px,42vw)}
  #avvio h1{font-size:clamp(22px,5vw,34px);color:#b8506a}
  #avvio p{max-width:540px;font-size:16px;line-height:1.5;opacity:.85}
  #avvio button{border:0;border-radius:999px;padding:16px 38px;font-size:20px;font-weight:800;
    font-family:inherit;cursor:pointer;background:#b8506a;color:#fff;box-shadow:0 8px 24px rgba(184,80,106,.35)}

  #ccBox{display:none;position:fixed;left:50%;transform:translateX(-50%);
    bottom:calc(64px + env(safe-area-inset-bottom,0px));z-index:37;max-width:min(860px,88vw);
    background:rgba(11,13,16,.78);color:#fff;font-size:21px;line-height:1.4;text-align:center;
    padding:10px 18px;border-radius:12px;white-space:pre-line}
  #ccMenu{display:none;position:fixed;top:56px;right:12px;z-index:50;flex-direction:column;gap:6px;
    background:rgba(17,21,27,.95);border:1px solid rgba(255,255,255,.2);border-radius:14px;padding:10px}
  #ccMenu button{border:none;background:#232a33;color:#fff;border-radius:9px;padding:10px 18px;
    font-size:14px;cursor:pointer;font-family:inherit;text-align:left}
  #ccMenu button.on{background:var(--rosa)}

  /* portatili 13" / proiettori (1280px): la barra ha 7 pulsanti — le etichette
     dei comandi secondari spariscono prima, così Pausa e Lezioni restano leggibili */
  @media(max-width:1200px){
    .teachbar #btnDSA .lbl,.teachbar #btnCC .lbl,.teachbar #btnElenco .lbl,.teachbar #tbLive .lbl{display:none}
    .teachbar .tit em{display:none}
  }
  @media(max-width:1000px){ .teachbar .tbtn .lbl{display:none} }
  .teachbar{flex-wrap:nowrap;overflow-x:auto;scrollbar-width:none}
  .teachbar::-webkit-scrollbar{display:none}
  @media(max-width:680px){
    .teachbar{padding:8px 10px 8px 12px;gap:6px}
    .teachbar .tit{font-size:13px;max-width:38vw;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .teachbar .demotag{display:none}
    .tbtn{padding:9px 11px;font-size:15px}
    .tbtn .lbl{display:none}
    .pill{top:56px;font-size:13px;padding:8px 14px;max-width:90vw;text-align:center}
    .cocciu{left:10px;bottom:calc(52px + env(safe-area-inset-bottom,0px));gap:8px;max-width:80vw}
    body.cc-on .cocciu{bottom:calc(116px + env(safe-area-inset-bottom,0px))}
    #ccBox{font-size:15px;bottom:calc(56px + env(safe-area-inset-bottom,0px))}
    .cimg{width:54px}
    .cocciu .say{font-size:13px;padding:9px 12px}
    .card{padding:22px 18px}
    .card h1{font-size:21px}
    .cimg-mid{width:78px}
    .bigbtn{padding:14px 26px;font-size:16px}
    .lezioni{grid-template-columns:1fr}
  }
</style>
</head>
<body>
<script>
window.EDU_T = <?php echo json_encode($_SESSION['edu_t']); ?>;
window.EDU_K = <?php echo json_encode($_SESSION['edu_k']); ?>;
window.EDU_C = <?php echo json_encode($EDU_C); ?>;   /* tenant (cliente) */
window.EDU_BASE = <?php echo json_encode(rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/') . '/'); ?>;   /* cartella app/ (percorsi assoluti: funziona con o senza barra finale) */
</script>

<div class="teachbar">
  <span class="tit"><span id="brandTit"><?php echo $B('titolo'); ?></span> <em id="brandSub" style="opacity:.7;font-weight:400"><?php echo $B('sottotitolo'); ?></em> <img class="cimg-mini" src="<?php echo $B('mascotte_img'); ?>" alt="" onerror="this.remove()"><span class="demotag" style="opacity:.5;font-size:12px"> · demo</span></span>
  <span class="sp"></span>
  <button class="tbtn" id="btnPausa" onclick="togglePausa()">⏸<span class="lbl"> Pausa</span></button>
  <button class="tbtn" onclick="prossimaTappa()" aria-label="Prossima scoperta">⏭<span class="lbl"> Prossima scoperta</span></button>
  <button class="tbtn" id="btnElenco" onclick="apriElenco()" aria-label="Elenco delle scoperte">📖</button>
  <button class="tbtn" id="btnDSA" onclick="toggleDSA()" aria-label="Alta leggibilità" title="Alta leggibilità">Aa</button>
  <button class="tbtn" id="btnCC" onclick="toggleCCMenu()" aria-label="Sottotitoli">CC</button>
  <button class="tbtn" id="tbLive" style="display:none" onclick="quizLive()" aria-label="Quiz live con i dispositivi degli alunni" title="Quiz live: PIN sui dispositivi degli alunni">🎮<span class="lbl"> Quiz live</span></button>
  <button class="tbtn" onclick="vaiMenu()" aria-label="Tutte le lezioni">☰<span class="lbl"> Lezioni</span></button>
</div>

<div class="pill" id="pill">👆 Trova e tocca i punti che brillano!</div>

<div class="cocciu" id="cocciu">
  <div class="body"><img class="cimg" src="<?php echo $B('mascotte_img'); ?>" alt="<?php echo $B('mascotte'); ?>" onerror="this.outerHTML='<?php echo $B('mascotte_emoji'); ?>'"></div>
  <div class="say" id="cocciuSay">Ciao classe! Scegliete la lezione di oggi!</div>
</div>

<!-- overlay: MENU LEZIONI -->
<div class="ovl on" id="menu">
  <div class="card">
    <button class="closex" id="menuX" style="display:none" onclick="closeMenu()" aria-label="Chiudi">✕</button>
    <img class="cimg-mid" src="<?php echo $B('mascotte_img'); ?>" alt="<?php echo $B('mascotte'); ?>" onerror="this.outerHTML='<?php echo $B('mascotte_emoji'); ?>'">
    <h1 id="brandH1"><?php echo $B('titolo'); ?></h1>
    <p><?php echo $B('claim'); ?><br>
    Trascina lo schermo per guardarti intorno e tocca i punti che brillano!</p>
    <div class="livsel">
      <span class="lbl">Per che classe è la lezione di oggi?</span>
      <div class="seg" role="group" aria-label="Livello della classe">
        <button id="livJ" class="on" onclick="setLivello('junior')">Primaria · 8–10</button>
        <button id="livS" onclick="setLivello('senior')">Medie · 11–13</button>
      </div>
    </div>
    <div class="accsel">
      <span class="lbl">Accessibilità</span>
      <div class="seg" role="group" aria-label="Modalità di accessibilità">
        <button id="accStd" class="on" onclick="setAcc('std')" aria-pressed="true">Standard</button>
        <button id="accIpo" onclick="setAcc('ipo')" aria-pressed="false">👁 Ipovedenti · testo grande + audio</button>
        <button id="accLis" onclick="setAcc('lis')" aria-pressed="false">🤟 Sordi · interprete LIS</button>
      </div>
      <p id="accNote" class="hint" style="font-size:13px;opacity:.7;margin-top:8px"></p>
    </div>
    <div class="lezioni" id="menuLez"></div>
  </div>
</div>

<!-- overlay: scoperta -->
<div class="ovl" id="scoperta">
  <div class="card">
    <button class="closex" onclick="chiudiScoperta()" aria-label="Chiudi">✕</button>
    <div class="head"><div class="em" id="scEm">🌸</div><h2 id="scTit"></h2></div>
    <p id="scTxt"></p>
    <div style="text-align:center"><button class="bigbtn oro" onclick="chiudiScoperta()">Ho capito!</button></div>
  </div>
</div>

<!-- overlay: quiz -->
<div class="ovl" id="quiz">
  <div class="card">
    <button class="closex" onclick="vaiMenu()" aria-label="Chiudi">✕</button>
    <img class="cimg-mid" src="<?php echo $B('mascotte_img'); ?>" alt="<?php echo $B('mascotte'); ?>" onerror="this.outerHTML='<?php echo $B('mascotte_emoji'); ?>'">
    <h1 id="qTitolo">Quiz della classe!</h1>
    <div class="q" id="qTesto"></div>
    <div id="qOpts"></div>
    <div class="esito" id="qEsito"></div>
    <div class="sapevi" id="qSapevi" style="display:none">
      <div class="tit">💡 Lo sapevi?</div>
      <p id="qSapeviTxt"></p>
      <img id="qSapeviImg" alt="" loading="lazy" style="display:none">
      <div style="text-align:center;margin-top:12px"><button class="bigbtn oro" onclick="sapeviAvanti()">Avanti ▸</button></div>
    </div>
    <div style="text-align:center;margin-top:14px"><button class="tbtn" id="qLiveBtn" onclick="quizLive()">🎮 Gioca live — PIN sui vostri dispositivi</button></div>
  </div>
</div>

<!-- overlay: intro del corso (prologo) -->
<div id="prologoOvl" role="dialog" aria-label="Introduzione del corso">
  <div class="box">
    <div id="prologoTxt"></div>
    <button class="bigbtn oro" id="prologoBtn" style="margin-top:26px">Inizia \u25b8</button>
  </div>
</div>

<!-- overlay: fine -->
<div class="ovl" id="fine">
  <div class="card">
    <button class="closex" onclick="vaiMenu()" aria-label="Chiudi">✕</button>
    <div class="em">🎉 <img class="cimg-mid" src="<?php echo $B('mascotte_img'); ?>" alt="<?php echo $B('mascotte'); ?>" onerror="this.outerHTML='<?php echo $B('mascotte_emoji'); ?>'" style="vertical-align:middle"> 🎉</div>
    <h1>Bravissimi!</h1>
    <p id="fineTxt"></p>
    <p style="font-weight:700;color:var(--rosa)"><?php echo $BRAND['congedo']; ?></p>
    <button class="bigbtn" onclick="vaiMenu()">☰ Torna alle lezioni</button>
  </div>
</div>

<!-- splash d'avvio: un tocco abilita l'audio dei video (policy browser) -->
<div id="avvio">
  <img src="<?php echo $B('mascotte_img'); ?>" alt="" onerror="this.remove()">
  <h1><?php echo $B('titolo'); ?></h1>
  <p><?php echo ucfirst($B('mascotte')); ?> vi aspetta! Alzate il volume della LIM e toccate il pulsante per cominciare.</p>
  <button onclick="avviaCorso()">▶ Comincia</button>
</div>

<!-- interprete LIS (modalità sordi) -->
<div id="lisBox" aria-label="Interprete nella lingua dei segni italiana">
  <span class="lisTag">🤟 LIS</span>
  <button class="lisSize" onclick="lisToggleSize()" aria-label="Ingrandisci o riduci l'interprete">⤢</button>
  <video id="lisVid" playsinline muted></video>
<audio id="clipAudio" preload="auto"></audio>
  <div class="lisMiss">Per questa clip il video LIS non è ancora disponibile.</div>
</div>

<!-- barra lettura vocale (modalità ipovedenti) -->
<div id="ttsBar">
  <button onclick="ttsRipeti()" aria-label="Rileggi">🔊 Rileggi</button>
  <button onclick="ttsStop()" aria-label="Silenzio">⏹ Silenzio</button>
</div>

<!-- video della mascotte a tutto schermo -->
<div id="coccioOvl" aria-hidden="true">
  <div id="coccioStage">
    <div id="coccioAttesa"><?php echo ucfirst($B('mascotte')); ?> sta arrivando…</div>
    <div id="coccioSlot"></div>
  </div>
  <button id="coccioSkip" onclick="chiudiCoccio()">Salta ▸</button>
</div>

<!-- overlay: elenco scoperte (ripasso + alternativa testuale al 360) -->
<div class="ovl" id="elenco">
  <div class="card">
    <button class="closex" onclick="chiudiElenco()" aria-label="Chiudi">✕</button>
    <h1>📖 L'elenco delle <em>scoperte</em></h1>
    <p style="text-align:left">Tutte le schede di questa lezione: per il ripasso, e per chi preferisce leggerle qui invece che nel 360°.</p>
    <div id="elencoBody"></div>
    <div style="text-align:center"><button class="bigbtn oro" onclick="chiudiElenco()">Torna alla lezione</button></div>
  </div>
</div>

<div id="ccMenu">
  <button data-cc="off" class="on" onclick="setCC('off')">Nessuno</button>
  <button data-cc="it" onclick="setCC('it')">🇮🇹 Italiano</button>
  <button data-cc="en" onclick="setCC('en')">🇬🇧 English</button>
  <button data-cc="fr" onclick="setCC('fr')">🇫🇷 Français</button>
  <button data-cc="es" onclick="setCC('es')">🇪🇸 Español</button>
  <button data-cc="de" onclick="setCC('de')">🇩🇪 Deutsch</button>
</div>
<div id="ccBox"></div>

<div id="seekbar">
  <span id="seekClip"></span>
  <input id="seek" type="range" aria-label="Posizione nel video" min="0" max="1000" value="0">
  <span id="seekTime">00:00 / --:--</span>
</div>

<div id="tarBox"></div>

<a-scene vr-mode-ui="enabled:false" loading-screen="dotsColor:#e8788a;backgroundColor:#0b0d10">
  <a-assets><video id="vid" playsinline webkit-playsinline preload="auto" crossorigin="anonymous"></video></a-assets>
  <a-videosphere id="vsky" rotation="0 -90 0" src="#vid"></a-videosphere>
  <a-entity id="hotspots"></a-entity>
  <a-entity cursor="rayOrigin: mouse" raycaster="objects:.hot;far:60"></a-entity>
  <a-camera id="cam" look-controls="reverseMouseDrag:true" wasd-controls="enabled:false"></a-camera>
</a-scene>

<script>
/* =====================================================================
   LEZIONI — ogni lezione: playlist di video (Bunny) + tappe + quiz
   ---------------------------------------------------------------------
   TARATURA: apri  lim-salina.html?taratura  → in basso a destra vedi
   VIDEO corrente, TEMPO e DIREZIONE (yaw/pitch) mentre trascini.
   Nelle tappe:  v = indice del video nella playlist (0,1,2…)
   yaw: 0=davanti · 90=destra · -90=sinistra · 180=dietro
   ===================================================================== */
const CDN='https://vz-bedaaab5-085.b-cdn.net/';
const B=(g)=>({hls:CDN+g+'/playlist.m3u8', mp4:CDN+g+'/play_720p.mp4', guid:g});

const _qsTop=new URLSearchParams(location.search);
const CLASSE=(_qsTop.get('classe')||'ANON').toUpperCase().replace(/[^A-Z0-9-]/g,'').slice(0,20)||'ANON';
/* ---- ponte API: i contenuti vivono sul server (api.php -> Supabase) ---- */
let CATALOGO=[];            // meta delle lezioni per il menu (del corso selezionato)
let CORSI=[], CORSO_SEL=null, CLIENTE=null;   // Fase 2 SaaS: corsi del cliente
const CK=(k)=>k+'_'+(window.EDU_C||'legacy');  // chiavi cache locali per tenant
const LEZ_CACHE={};         // slug -> lezione completa (per sessione)
function hexToBuf(h){const a=new Uint8Array(h.length/2);for(let i=0;i<a.length;i++)a[i]=parseInt(h.substr(i*2,2),16);return a.buffer;}
function b64ToBuf(b){const s=atob(b);const a=new Uint8Array(s.length);for(let i=0;i<s.length;i++)a[i]=s.charCodeAt(i);return a.buffer;}
async function eduApi(params,post){
  const cls=(typeof CLASSE!=='undefined'&&CLASSE!=='ANON')?'&classe='+encodeURIComponent(CLASSE):'';
  const r=await fetch((window.EDU_BASE||'')+'api.php?'+params+(window.EDU_C?'&c='+encodeURIComponent(window.EDU_C):'')+cls,{
    method:post?'POST':'GET',
    headers:Object.assign({'X-EDU-T':window.EDU_T||''},post?{'Content-Type':'application/json'}:{}),
    body:post?JSON.stringify(post):undefined
  });
  const j=await r.json();
  if(j&&j.enc){
    const key=await crypto.subtle.importKey('raw',hexToBuf(window.EDU_K||''),{name:'AES-CBC'},false,['decrypt']);
    const buf=await crypto.subtle.decrypt({name:'AES-CBC',iv:b64ToBuf(j.iv)},key,b64ToBuf(j.data));
    return JSON.parse(new TextDecoder().decode(buf));
  }
  return j;
}
function cacheSet(k,v){ try{localStorage.setItem(k,JSON.stringify({t:Date.now(),v:v}));}catch(e){} }
function cacheGet(k){ try{const x=JSON.parse(localStorage.getItem(k)||'null'); return x&&x.v||null;}catch(e){return null;} }
function normalizzaLezione(l){
  l=JSON.parse(JSON.stringify(l));                                  /* copia pulita */
  l.video=(l.video||[]).filter(v=>v&&v.guid).map(v=>Object.assign(B(v.guid),{lis:(v.lis||v.video_lis||null),audio:(v.audio||null)}));  /* foto360: prossima versione; lis: clip interprete (fix v1.3: prima veniva scartato) */
  (l.tappe||[]).forEach(t=>{t._done=false;(t.hotspots||[]).forEach(h=>h._fatto=false);});
  return l;
}
function applicaBrand(cl){
  CLIENTE=cl||null; if(!cl)return;
  QUIZ_LIVE_OK=!(cl.limiti&&cl.limiti.quiz_live===false);      /* piano Base: niente quiz live */
  if(!QUIZ_LIVE_OK){ const t=document.getElementById('tbLive'), q=document.getElementById('qLiveBtn'); if(t)t.dataset.piano='no'; if(q)q.style.display='none'; }
  const b=cl.brand||{};
  if(b.titolo){ const t=document.getElementById('brandTit'), h=document.getElementById('brandH1'); if(t)t.textContent=b.titolo; if(h)h.textContent=b.titolo; document.title=b.titolo+' — Lezioni'; }
  const s=document.getElementById('brandSub'); if(s&&(b.sottotitolo||cl.nome))s.textContent=b.sottotitolo||cl.nome;
}
function impostaCorsi(corsi){
  CORSI=Array.isArray(corsi)?corsi:[];
  if(CORSI.length===1){ CORSO_SEL=CORSI[0]; CATALOGO=CORSO_SEL.lezioni||[]; applicaMascotteCorso(CORSO_SEL); }
  else { CORSO_SEL=null; CATALOGO=[]; }
}
function mostraLicenza(cl){
  const box=document.getElementById('menuLez'); box.textContent='';
  const p=document.createElement('p'); p.style.cssText='color:var(--rosaTxt);font-weight:700;font-size:17px;max-width:520px;margin:10px auto';
  if(cl&&cl.scuola&&cl.scuola.nome){                       /* licenza della singola scuola */
    const st=cl.scuola.licenza_stato==='sospesa'?'sospesa':'scaduta';
    p.textContent=cl.scuola.nome+': la licenza è '+st+(cl.scuola.licenza_a?' dal '+cl.scuola.licenza_a:'')+'. Le lezioni torneranno disponibili al rinnovo.';
  }else{
    const stato=cl&&cl.licenza_stato==='sospesa'?'sospesa':'scaduta';
    p.textContent=(cl&&cl.nome?cl.nome+': ':'')+'la licenza di Esplora Trapani Edu è '+stato+'. Le lezioni torneranno disponibili al rinnovo.';
  }
  box.appendChild(p);
  if(cl&&cl.contatto_email){ const q=document.createElement('p'); q.style.cssText='opacity:.75;font-size:14px'; q.textContent='Riferimento: '+cl.contatto_email; box.appendChild(q); }
}
async function caricaMenu(){
  try{
    const j=await eduApi('action=menu');
    if(j&&j.ok===false&&j.err==='licenza_scuola'){ /* licenza della SCUOLA (migr. 26) */
      applicaBrand(j.cliente); localStorage.removeItem(CK('edu_menu')); localStorage.removeItem(CK('edu_corsi'));
      CORSI=[]; CATALOGO=[]; LICENZA_KO=Object.assign({}, j.cliente||{}, {scuola:j.scuola||null}); return;
    }
    if(j&&j.ok===false&&j.err==='licenza'){        /* Fase 2: gate licenza */
      applicaBrand(j.cliente); localStorage.removeItem(CK('edu_menu')); localStorage.removeItem(CK('edu_corsi'));
      CORSI=[]; CATALOGO=[]; LICENZA_KO=j.cliente||{}; return;
    }
    if(j&&j.ok&&(Array.isArray(j.corsi)||Array.isArray(j.lezioni))){
      applicaBrand(j.cliente); MENU_CARICATO=true;
      if(Array.isArray(j.corsi)&&j.corsi.length) impostaCorsi(j.corsi); else { CORSI=[]; CORSO_SEL=null; CATALOGO=j.lezioni||[]; }
      MASCOTTE=j.mascotte||{}; MASC_QUIZ_SEMPRE=(j.quizSempre!==false);
      MASC_LIV=j.mascotteLiv||{junior:MASCOTTE,senior:MASCOTTE}; MASC_CFG=j.mascotteCfg||{junior:true,senior:true};
      cacheSet(CK('edu_menu'),j.lezioni||[]); cacheSet(CK('edu_corsi'),j.corsi||[]); cacheSet(CK('edu_cliente'),j.cliente||null);
      cacheSet(CK('edu_masc'),{m:MASCOTTE,q:MASC_QUIZ_SEMPRE,l:MASC_LIV,c:MASC_CFG});
      return;
    }
    throw new Error((j&&j.err)||'menu');
  }catch(e){
    const c=cacheGet(CK('edu_menu'));
    if(c){
      applicaBrand(cacheGet(CK('edu_cliente')));
      const cc=cacheGet(CK('edu_corsi')); if(cc&&cc.length) impostaCorsi(cc); else CATALOGO=c;
      const cm=cacheGet(CK('edu_masc')); if(cm){ MASCOTTE=cm.m||{}; MASC_QUIZ_SEMPRE=(cm.q!==false); MASC_LIV=cm.l||{junior:MASCOTTE,senior:MASCOTTE}; MASC_CFG=cm.c||{junior:true,senior:true}; }
      console.log('[SIC] menu dalla cache locale (rete assente?)'); return;
    }
    throw e;
  }
}
let LICENZA_KO=null, QUIZ_LIVE_OK=true, MENU_CARICATO=false;
async function caricaLezione(slug){
  if(LEZ_CACHE[slug])return normalizzaLezione(LEZ_CACHE[slug]);
  try{
    const j=await eduApi('action=lezione&id='+encodeURIComponent(slug));
    if(j&&j.ok&&j.lezione){ LEZ_CACHE[slug]=j.lezione; cacheSet('edu_lez_'+slug,j.lezione); return normalizzaLezione(j.lezione); }
    throw new Error((j&&j.err)||'lezione');
  }catch(e){
    const c=cacheGet('edu_lez_'+slug);
    if(c){ console.log('[SIC] lezione dalla cache locale'); return normalizzaLezione(c); }
    throw e;
  }
}

/* ===================================================================== */
let LEZ=null, lezIdx=-1, vidIdx=0, tappaIdx=0, aperti=0, quizIdx=0, punti=0, _hls=null, started=false;
const vid=document.getElementById('vid');
const RIDOTTO=window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

/* ---- livello (Primaria 8-10 / Medie 11-13): stessi video, testi e quiz differenziati ---- */
const _qs=new URLSearchParams(location.search);
let LIVELLO=(_qs.get('liv')==='senior'||(!_qs.has('liv')&&localStorage.getItem('edu_livello')==='senior'))?'senior':'junior';
function setLivello(l){
  LIVELLO=(l==='senior')?'senior':'junior';
  try{localStorage.setItem('edu_livello',LIVELLO);}catch(e){}
  document.getElementById('livJ').classList.toggle('on',LIVELLO==='junior');
  document.getElementById('livS').classList.toggle('on',LIVELLO==='senior');
}
function testoScheda(h){ return (LIVELLO==='senior'&&h.txt2)?h.txt2:h.txt; }

/* =====================================================================
   ACCESSIBILITÀ — std | ipo (ipovedenti) | lis (sordi)
   ?acc=ipo|lis nell'URL oppure scelta in home (memorizzata sul dispositivo)
   ===================================================================== */
let ACC=(['ipo','lis'].indexOf(_qs.get('acc'))>=0)?_qs.get('acc'):(localStorage.getItem('edu_acc')||'std');
if(['std','ipo','lis'].indexOf(ACC)<0)ACC='std';
function setAcc(a,silenzioso){
  ACC=(['ipo','lis'].indexOf(a)>=0)?a:'std';
  try{localStorage.setItem('edu_acc',ACC);}catch(e){}
  document.body.classList.toggle('ipo',ACC==='ipo');
  document.body.classList.toggle('lis',ACC==='lis');
  [['accStd','std'],['accIpo','ipo'],['accLis','lis']].forEach(([id,k])=>{
    const b=document.getElementById(id); if(!b)return;
    b.classList.toggle('on',ACC===k); b.setAttribute('aria-pressed',ACC===k?'true':'false');
  });
  const note=document.getElementById('accNote');
  if(note)note.textContent=ACC==='ipo'?'Testo grande ad alto contrasto e lettura vocale di spiegazioni e domande. Tasti: 1-4 risposte, Spazio pausa, N prossima scoperta, R rileggi.'
    :ACC==='lis'?'In basso a destra compare l\'interprete LIS sincronizzato con il video. Sottotitoli attivi.'
    :'';
  document.getElementById('ttsBar').classList.toggle('on',ACC==='ipo');
  if(ACC!=='ipo')ttsStop();
  if(ACC==='lis'){ if(typeof ccLang!=='undefined'&&ccLang==='off'&&LEZ){ ccLang='it'; loadCC(); } lisSync(true); }
  else { lisHide(); }
  if(!silenzioso)buildMenu();
}
function lezAccOk(l){   /* la lezione è fruibile nella modalità scelta? */
  const a=(l&&l.acc)||{};
  if(ACC==='ipo')return a.ipovedenti!==false;
  if(ACC==='lis')return !!(a.lis||(a.lis_clip&&a.lis_clip>0));
  return true;
}

/* ---- lettura vocale (Web Speech API, it-IT) — solo modalità ipovedenti ---- */
let _ttsUltimo='';
function ttsOk(){ return ACC==='ipo'&&'speechSynthesis' in window; }
function ttsVoce(){
  const vs=speechSynthesis.getVoices();
  return vs.find(v=>/^it/i.test(v.lang)&&/google|premium|enhanced/i.test(v.name))||vs.find(v=>/^it/i.test(v.lang))||null;
}
function tts(txt,accoda){
  if(!ttsOk()||!txt)return;
  _ttsUltimo=(accoda&&_ttsUltimo)?(_ttsUltimo+' '+txt):txt;
  if(!accoda)speechSynthesis.cancel();
  const u=new SpeechSynthesisUtterance(String(txt).replace(/[✨🦩🧂🛠️🎉👆▶⏸⏭]/g,''));
  u.lang='it-IT'; u.rate=0.92; u.pitch=1; const v=ttsVoce(); if(v)u.voice=v;
  if(typeof audioDuck==='function'){ audioDuck(true); u.onend=()=>{ if(!speechSynthesis.pending&&!speechSynthesis.speaking)audioDuck(false); }; }
  speechSynthesis.speak(u);
}
function ttsStop(){ try{speechSynthesis.cancel();}catch(e){} if(typeof audioDuck==='function')audioDuck(false); }
function ttsRipeti(){ if(_ttsUltimo)tts(_ttsUltimo); }
if('speechSynthesis' in window){ speechSynthesis.onvoiceschanged=()=>{}; }

/* ---- interprete LIS: un <video> in basso a destra che segue il video 360 ---- */
const lisVid=document.getElementById('lisVid');
let _lisHls=null, _lisGuid='';
function lisSrc(v){
  if(!v||!v.lis)return null;
  const s=String(v.lis).trim();
  if(/^https?:/i.test(s))return {mp4:s,hls:null,guid:s};
  const g=s.replace(/^bunny:/i,'');
  return {mp4:CDN+g+'/play_720p.mp4',hls:CDN+g+'/playlist.m3u8',guid:g};
}
/* ---- AUDIO DI SOTTOFONDO DELLA CLIP (migr. 25) ----
   Il file NON è dentro al video: arriva dalla regia e viene suonato qui,
   agganciato al ciclo di vita della clip (play/pausa/seek/fine). */
const clipAudio=document.getElementById('clipAudio');
let _audioCfg=null, _audioDucked=false;
function audioAttach(v){
  const a=(v&&v.audio)||null;
  _audioCfg=a; _audioDucked=false;
  try{ clipAudio.pause(); }catch(e){}
  if(!a||!a.url){ clipAudio.removeAttribute('src'); return; }
  clipAudio.src=a.url;
  clipAudio.loop=(a.loop!==false);
  clipAudio.volume=Math.max(0,Math.min(1,(a.vol==null?45:a.vol)/100));
  clipAudio.currentTime=0;
  if(started&&!vid.paused) clipAudio.play().catch(()=>{});
}
function audioSync(){
  if(!_audioCfg||!clipAudio.src)return;
  if(vid.paused){ try{clipAudio.pause();}catch(e){} }
  else { clipAudio.play().catch(()=>{}); }
}
function audioSeek(){                     /* la barra è stata spostata: riallineo */
  if(!_audioCfg||!clipAudio.src||clipAudio.loop)return;
  try{ clipAudio.currentTime=Math.min(vid.currentTime||0, clipAudio.duration||0); }catch(e){}
}
function audioDuck(giu){                  /* abbassa mentre parla la mascotte / la voce */
  if(!_audioCfg||!clipAudio.src||_audioCfg.duck===false)return;
  const pieno=Math.max(0,Math.min(1,(_audioCfg.vol==null?45:_audioCfg.vol)/100));
  _audioDucked=!!giu;
  clipAudio.volume=giu?Math.min(pieno,pieno*0.25):pieno;
}
function audioStop(){ try{ clipAudio.pause(); clipAudio.removeAttribute('src'); }catch(e){} _audioCfg=null; }
vid.addEventListener('play',audioSync);
vid.addEventListener('pause',audioSync);
vid.addEventListener('seeked',audioSeek);
function lisHide(){ document.getElementById('lisBox').classList.remove('on'); try{lisVid.pause();}catch(e){} }
function lisSync(force){
  const box=document.getElementById('lisBox');
  if(ACC!=='lis'||!LEZ||!started){ box.classList.remove('on'); return; }
  box.classList.add('on');
  const src=lisSrc(LEZ.video[vidIdx]);
  if(!src){ box.classList.add('miss'); try{lisVid.pause();}catch(e){} _lisGuid=''; return; }
  box.classList.remove('miss');
  if(_lisGuid!==src.guid||force){
    _lisGuid=src.guid;
    if(_lisHls){try{_lisHls.destroy();}catch(e){}_lisHls=null;}
    if(src.hls&&window.Hls&&Hls.isSupported()){ _lisHls=new Hls(); _lisHls.loadSource(src.hls); _lisHls.attachMedia(lisVid);
      _lisHls.on(Hls.Events.ERROR,(e,d)=>{ if(d&&d.fatal){ try{_lisHls.destroy();}catch(x){} _lisHls=null; lisVid.src=src.mp4; } }); }
    else{ lisVid.src=(src.hls&&lisVid.canPlayType('application/vnd.apple.mpegurl'))?src.hls:src.mp4; }
  }
  lisVid.muted=true;                                   /* l'audio resta quello della lezione */
  if(vid.paused){ lisVid.pause(); } else { lisVid.play().catch(()=>{}); }
  if(Math.abs((lisVid.currentTime||0)-(vid.currentTime||0))>0.6) lisVid.currentTime=vid.currentTime||0;
}
function lisToggleSize(){ document.getElementById('lisBox').classList.toggle('big'); }
vid.addEventListener('play',()=>lisSync()); vid.addEventListener('pause',()=>lisSync());
vid.addEventListener('seeked',()=>lisSync()); vid.addEventListener('loadedmetadata',()=>lisSync(true));
setInterval(()=>{ if(ACC==='lis'&&started&&!vid.paused)lisSync(); },2000);

function quizCorrente(){ return (LIVELLO==='senior'&&LEZ&&LEZ.quiz2)?LEZ.quiz2:(LEZ?LEZ.quiz:[]); }

/* ---- tracking anonimo per classe (GDPR by design: zero dati personali) ----
   passa da api.php: nessuna chiave nel client. Codice da ?classe=TP-IC12-5A */
function track(tipo,dettaglio){
  try{
    eduApi('action=track',{classe:CLASSE,lezione:LEZ?LEZ.id:'—',tipo:tipo,
      dettaglio:Object.assign({livello:LIVELLO},dettaglio||{})}).catch(()=>{});
  }catch(e){}
}

let sayTimer=null;
function say(txt,persist){
  const c=document.getElementById('cocciu');
  c.classList.remove('fade');
  document.getElementById('cocciuSay').textContent=txt;
  tts(txt);
  if(sayTimer){clearTimeout(sayTimer);sayTimer=null;}
  if(!persist)sayTimer=setTimeout(()=>c.classList.add('fade'),8000);
}
function mood(m){ const c=document.getElementById('cocciu'); c.classList.remove('brilla','sciolto'); void c.offsetWidth; if(m)c.classList.add(m); }

/* =====================================================================
   VIDEO DELLA MASCOTTE COCCIO — riproduzione a tutto schermo
   Sorgenti accettate: URL/ID YouTube oppure 'bunny:GUID'.
   Regola d'oro: un video non deve MAI bloccare la lezione. Se YouTube è
   filtrato dalla rete scolastica o il player non parte entro pochi
   secondi, l'overlay si chiude da solo e si prosegue.
   ===================================================================== */
let MASCOTTE={}, MASC_LIV={junior:{},senior:{}}, MASC_CFG={junior:true,senior:true}, MASC_QUIZ_SEMPRE=true, _ytPronto=null, _coccioChiudi=null;
/* video della mascotte per il livello scelto; null se la regia l'ha
   disattivata per quella fascia d'età (Primaria / Medie) */
function mascVideo(chiave){
  if(MASC_CFG&&MASC_CFG[LIVELLO]===false)return null;
  const set=(MASC_LIV&&MASC_LIV[LIVELLO])||MASCOTTE||{};
  return set[chiave]||null;
}
const _quizVisti={};

function ytId(src){
  if(!src)return '';
  const s=String(src).trim();
  if(/^bunny:/i.test(s))return '';
  const m=s.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/))([A-Za-z0-9_-]{6,})/);
  if(m)return m[1];
  if(/^[A-Za-z0-9_-]{8,15}$/.test(s))return s;
  return '';
}
function bunnyGuid(src){
  if(!src)return '';
  const s=String(src).trim();
  if(/^bunny:/i.test(s))return s.slice(6);
  return '';
}
function caricaYT(){
  if(_ytPronto)return _ytPronto;
  _ytPronto=new Promise((res)=>{
    if(window.YT&&window.YT.Player){res();return;}
    window.onYouTubeIframeAPIReady=()=>res();
    const t=document.createElement('script');
    t.src='https://www.youtube.com/iframe_api';
    t.onerror=()=>res();                       /* rete che blocca YouTube */
    document.head.appendChild(t);
    setTimeout(res,6000);                      /* non aspettiamo all'infinito */
  });
  return _ytPronto;
}

/* riproduce un video e risolve SEMPRE (fine, salta, errore o timeout) */
function playCoccio(src){
  return new Promise(async (resolve)=>{
    const id=ytId(src), guid=bunnyGuid(src);
    if(!id&&!guid){ resolve('assente'); return; }

    const ovl=document.getElementById('coccioOvl');
    const slot=document.getElementById('coccioSlot');
    const attesa=document.getElementById('coccioAttesa');
    let finito=false, ply=null, guardia=null;

    const fine=(perche)=>{
      if(finito)return; finito=true;
      if(guardia)clearTimeout(guardia);
      _coccioChiudi=null;
      try{ if(ply&&ply.destroy)ply.destroy(); }catch(e){}
      slot.textContent=''; ovl.classList.remove('on');
      document.body.style.cursor='';
      console.log('[COCCIO] fine ('+perche+')');
      resolve(perche);
    };
    _coccioChiudi=()=>fine('saltato');

    attesa.style.display='block';
    slot.textContent='';
    ovl.classList.add('on');

    if(guid){                                   /* video su Bunny (consigliato a scuola) */
      const v=document.createElement('video');
      v.playsInline=true; v.controls=false; v.autoplay=true;
      slot.appendChild(v);
      const mp4=CDN+guid+'/play_720p.mp4', hls=CDN+guid+'/playlist.m3u8';
      let _h=null;
      if(window.Hls&&Hls.isSupported()){
        _h=new Hls(); _h.loadSource(hls); _h.attachMedia(v);
        _h.on(Hls.Events.ERROR,(e,d)=>{ if(d&&d.fatal){ try{_h.destroy();}catch(x){} v.src=mp4; v.play().catch(()=>{}); } });
      }else{ v.src=v.canPlayType('application/vnd.apple.mpegurl')?hls:mp4; }
      v.addEventListener('playing',()=>{attesa.style.display='none';});
      v.addEventListener('ended',()=>fine('completato'));
      v.addEventListener('error',()=>fine('errore'));
      v.play().catch(()=>{});
      guardia=setTimeout(()=>{ if(v.readyState<2)fine('timeout'); },9000);
      return;
    }

    await caricaYT();
    if(!(window.YT&&window.YT.Player)){ fine('youtube-non-disponibile'); return; }
    const host=document.createElement('div'); slot.appendChild(host);
    try{
      ply=new YT.Player(host,{
        host:'https://www.youtube-nocookie.com',
        videoId:id,
        playerVars:{autoplay:1,controls:0,rel:0,modestbranding:1,playsinline:1,fs:0,
                    iv_load_policy:3,disablekb:1,cc_load_policy:0},
        events:{
          onReady:(e)=>{ attesa.style.display='none'; try{e.target.unMute();e.target.setVolume(100);e.target.playVideo();}catch(x){} },
          onStateChange:(e)=>{ if(e.data===YT.PlayerState.ENDED)fine('completato'); },
          onError:()=>fine('errore')
        }
      });
    }catch(e){ fine('errore'); return; }
    guardia=setTimeout(()=>{
      let st=-1; try{ st=ply.getPlayerState(); }catch(x){}
      if(st!==1)fine('timeout');                /* 1 = in riproduzione */
    },9000);
  });
}
function chiudiCoccio(){ if(_coccioChiudi)_coccioChiudi(); }

/* tocco iniziale della maestra: sblocca l'audio e lancia il benvenuto */
async function avviaCorso(){
  document.getElementById('avvio').classList.remove('on');
  try{ sessionStorage.setItem('edu_intro','1'); }catch(e){}
  await playCoccio(mascVideo('inizio_corso'));
}

/* memoria delle lezioni completate (solo su questo dispositivo, anonima) */
function lezioniFatte(){ try{ return JSON.parse(localStorage.getItem('edu_fatte')||'[]'); }catch(e){ return []; } }
function segnaFatta(slug){
  const a=lezioniFatte(); if(a.indexOf(slug)<0)a.push(slug);
  try{ localStorage.setItem('edu_fatte',JSON.stringify(a)); }catch(e){}
}
function corsoCompletato(){
  const attese=CATALOGO.filter(l=>l.stato!=='soon').map(l=>l.id);
  if(!attese.length)return false;
  const fatte=lezioniFatte();
  return attese.every(id=>fatte.indexOf(id)>=0);
}

/* ---- menu lezioni ---- */
function scegliCorso(i){ CORSO_SEL=CORSI[i]; CATALOGO=CORSO_SEL.lezioni||[]; applicaMascotteCorso(CORSO_SEL); buildMenu(); say(CORSO_SEL.tit+': scegliete la lezione!',true); }
function tuttiICorsi(){ CORSO_SEL=null; CATALOGO=[]; buildMenu(); }
function buildMenu(){
  const box=document.getElementById('menuLez'); box.textContent='';
  if(LICENZA_KO){ mostraLicenza(LICENZA_KO); return; }
  /* Fase 2: più corsi → prima le card dei corsi */
  if(CORSI.length>1&&!CORSO_SEL){
    CORSI.forEach((co,i)=>{
      const soon=(co.stato==='soon');
      const b=document.createElement('button'); b.className='lez corso '+(soon?'soon':(co.cls||'rosa')); if(soon)b.disabled=true;
      const em=document.createElement('div');em.className='em';em.textContent=co.em||'🎓';b.appendChild(em);
      const h=document.createElement('h3');h.textContent=co.tit;b.appendChild(h);
      const p=document.createElement('p');p.textContent=co.sub||co.desc||'';b.appendChild(p);
      const n=(co.lezioni||[]).length;
      const s=document.createElement('small');s.textContent=soon?'🔒 Prossimamente':('📚 '+n+(n===1?' lezione':' lezioni'));b.appendChild(s);
      b.onclick=()=>scegliCorso(i);
      box.appendChild(b);
    });
    return;
  }
  if(CORSI.length>1&&CORSO_SEL){
    const back=document.createElement('button'); back.className='tbtn'; back.style.cssText='grid-column:1/-1;justify-self:start;margin-bottom:4px';
    back.textContent='← Tutti i corsi'; back.onclick=tuttiICorsi; box.appendChild(back);
  }
  if(ACC==='ipo'&&!box.dataset.letto){ box.dataset.letto='1'; tts('Scegliete la lezione di oggi. Le lezioni sono: '+CATALOGO.filter(l=>l.stato!=='soon').map((l,i)=>(i+1)+', '+l.tit).join('. ')); }
  if(!CATALOGO.length){
    const p=document.createElement('p');
    p.style.cssText='opacity:.7;font-size:14px';
    /* dopo il caricamento, un cliente senza corsi pubblicati non deve restare su «Carico…» per sempre */
    p.textContent=MENU_CARICATO?'Nessun corso disponibile al momento: chiedi al referente di pubblicarne uno.':'Carico le lezioni…';
    box.appendChild(p);
    return;
  }
  CATALOGO.forEach((l,i)=>{
    const soon=(l.stato==='soon')||l.soon;
    const b=document.createElement('button');
    b.className='lez '+(soon?'soon':(l.cls||'rosa'));
    if(soon)b.disabled=true;
    const em=document.createElement('div');em.className='em';em.textContent=l.em;b.appendChild(em);
    const h=document.createElement('h3');h.textContent=l.tit;b.appendChild(h);
    const p=document.createElement('p');p.textContent=l.sub||'';b.appendChild(p);
    const s=document.createElement('small');s.textContent=soon?'🔒 Prossimamente':('▶ '+(l.durata||''));b.appendChild(s);
    const a=l.acc||{};
    if(a.lis||(a.lis_clip&&a.lis_clip>0)){ const bd=document.createElement('span'); bd.className='accbadge'; bd.textContent='🤟 LIS'+(a.n_clip&&a.lis_clip<a.n_clip?' parziale':''); h.appendChild(bd); }
    if(a.ipovedenti===false){ const bd=document.createElement('span'); bd.className='accbadge'; bd.textContent='👁 non adatta'; h.appendChild(bd); }
    if(!soon&&!lezAccOk(l)){ b.classList.add('noacc'); b.title=ACC==='lis'?'Video LIS non ancora disponibile':'Non adatta al template ipovedenti'; }
    b.setAttribute('aria-label',l.tit+'. '+(l.sub||'')+(soon?' Prossimamente':''));
    if(!soon)b.onclick=()=>{ if(!lezAccOk(l)&&!confirm((ACC==='lis'?'Per questa lezione il video LIS non è ancora pronto.':'Questa lezione non è ancora adattata per ipovedenti.')+'\nAvviarla comunque?'))return; avviaLezione(i); };
    box.appendChild(b);
  });
}
function vaiMenu(){
  audioStop();
  try{vid.pause();}catch(e){} ttsStop(); lisHide(); audioStop();
  started=false;
  updSeekbar(); renderCue('');
  document.getElementById('menuX').style.display=LEZ?'block':'none';
  ['scoperta','quiz','fine'].forEach(i=>document.getElementById(i).classList.remove('on'));
  document.getElementById('pill').classList.remove('on');
  const g=document.getElementById('hotspots'); while(g.firstChild)g.removeChild(g.firstChild);
  document.getElementById('tbLive').style.display='none';
  document.getElementById('menu').classList.add('on');
  say('Scegliete la lezione di oggi!',true);
}

/* ---- sorgente video ---- */
function attach(v){
  if(_hls){try{_hls.destroy();}catch(e){}_hls=null;}
  if(window.Hls&&Hls.isSupported()){
    _hls=new Hls(); _hls.loadSource(v.hls); _hls.attachMedia(vid);
    _hls.on(Hls.Events.ERROR,(e,d)=>{ if(d&&d.fatal){ try{_hls.destroy();}catch(x){} _hls=null; vid.src=v.mp4; vid.load(); vid.play().catch(()=>{});} });
  }else if(vid.canPlayType('application/vnd.apple.mpegurl')){ vid.src=v.hls; }
  else{ vid.src=v.mp4; }
}

async function avviaLezione(i){
  const meta=CATALOGO[i];
  if(!meta||meta.stato==='soon')return;
  say('Un attimo… preparo la lezione!',true);
  let lezioneCaricata;
  try{ lezioneCaricata=await caricaLezione(meta.id); }
  catch(e){ say('Non riesco a caricare la lezione: controllate la connessione e riprovate.',true); console.log('[SIC] lezione KO',e); return; }
  if(!lezioneCaricata.video.length){ say('Questa lezione non ha ancora video pronti.',true); return; }
  lezIdx=i; LEZ=lezioneCaricata;
  vidIdx=0; tappaIdx=0; quizIdx=0; punti=0;
  document.getElementById('menu').classList.remove('on');
  applicaMascotteCorso(LEZ.corso);             /* mascotte del corso (migr. 26) */
  await mostraPrologo();                       /* Intro del corso (migr. 19) */
  if(!(MASC_CFG&&MASC_CFG[LIVELLO]===false))await playCoccio(LEZ.coccio);   /* video d'apertura (se la mascotte è attiva per questa fascia) */
  attach(LEZ.video[0]);
  vid.muted=false;
  vid.play().catch(()=>{ vid.muted=true; vid.play().catch(()=>{}); });
  started=true;
  audioAttach(LEZ.video[0]);
  if(ACC==='lis'&&ccLang==='off')ccLang='it';
  say(LEZ.intro); lisSync(true);
  track('lezione_avviata',{livello:LIVELLO});
  document.getElementById('tbLive').style.display=QUIZ_LIVE_OK?'':'none';
  updPausaBtn();
  updSeekbar();
  loadCC();
}

function closeMenu(){
  if(!LEZ)return;
  document.getElementById('menu').classList.remove('on');
  started=true;
  vid.play().catch(()=>{});
  updPausaBtn(); updSeekbar();
}

/* ---- motore tappe (multi-video) ---- */
function tappeCorrenti(){ return LEZ?LEZ.tappe.filter(t=>t.v===vidIdx):[]; }
function prossima(){ return LEZ?LEZ.tappe.find(t=>!t._done):null; }

vid.addEventListener('timeupdate',()=>{
  if(!started||!LEZ)return;
  const t=LEZ.tappe.find(x=>x.v===vidIdx && !x._done && vid.currentTime>=x.t);
  if(t)apriTappa(t);
});
vid.addEventListener('ended',()=>{
  if(!started||!LEZ)return;
  vidIdx++;
  if(vidIdx<LEZ.video.length){
    attach(LEZ.video[vidIdx]);
    audioAttach(LEZ.video[vidIdx]);
    vid.play().catch(()=>{});
    say('Si continua il viaggio…');
    updSeekbar(); loadCC();
  }else{
    avviaQuiz();
  }
});

let tappaAttiva=null;
function apriTappa(t){
  tappaAttiva=t; t._done=true;
  vid.pause(); updPausaBtn(); audioDuck(true);
  say(t.cocciu,true);
  if(ACC==='ipo')tts(t.cocciu+'. Ci sono '+t.hotspots.length+(t.hotspots.length===1?' scoperta':' scoperte')+'. Premi N per aprirla.',true);
  aperti=0;
  const g=document.getElementById('hotspots');
  while(g.firstChild)g.removeChild(g.firstChild);
  t.hotspots.forEach((h,i)=>{
    const e=document.createElement('a-entity');
    const r=7, y=h.yaw*Math.PI/180, p=h.pitch*Math.PI/180;
    e.setAttribute('position',(r*Math.sin(y)*Math.cos(p))+' '+(r*Math.sin(p))+' '+(-r*Math.cos(y)*Math.cos(p)));
    e.setAttribute('look-at-cam','');
    const ring=document.createElement('a-ring');
    const K=(ACC==='ipo')?2:1;
    ring.setAttribute('radius-inner',0.55*K);ring.setAttribute('radius-outer',0.7*K);
    ring.setAttribute('material','color:#e8788a;shader:flat;opacity:0.95');
    if(RIDOTTO){ ring.setAttribute('scale','1.12 1.12 1'); }
    else{ ring.setAttribute('animation','property:scale;from:1 1 1;to:1.18 1.18 1;dir:alternate;loop:true;dur:700'); }
    ring.classList.add('hot');ring.dataset.h=i;
    e.appendChild(ring);
    const disc=document.createElement('a-circle');
    disc.setAttribute('radius',0.52*K);
    disc.setAttribute('material','color:#ffffff;shader:flat;opacity:0.92');
    disc.classList.add('hot');disc.dataset.h=i;
    e.appendChild(disc);
    const tx=document.createElement('a-text');
    tx.setAttribute('value','?');tx.setAttribute('align','center');tx.setAttribute('baseline','center');
    tx.setAttribute('color',ACC==='ipo'?'#111111':'#e8788a');tx.setAttribute('width',9*K);tx.setAttribute('position','0 0 0.02');
    e.appendChild(tx);
    g.appendChild(e);
  });
  document.getElementById('pill').textContent=PILL_BASE;
  document.getElementById('pill').classList.add('on');
}

/* ---- bussola: se la scoperta che brilla e' fuori dallo schermo, la pill
   dice da che parte girare (sui video provvisori e sulle LIM piccole
   capita spesso che il "?" sia dietro o in basso e sembri "non spuntato") ---- */
const PILL_BASE='👆 Trova e tocca i punti che brillano!';
function bussola(){
  const pill=document.getElementById('pill');
  if(!tappaAttiva||!pill.classList.contains('on')) return;
  const cam=document.getElementById('cam'); if(!cam) return;
  const r=cam.getAttribute('rotation');
  let camYaw=-r.y; camYaw=((camYaw%360)+540)%360-180;
  const camPitch=r.x;
  const h=tappaAttiva.hotspots.find(x=>!x._fatto); if(!h){ pill.textContent=PILL_BASE; return; }
  let dy=h.yaw-camYaw; dy=((dy%360)+540)%360-180;
  const dp=h.pitch-camPitch;
  let hint='';
  if(dy>40) hint='gira a destra ▶';
  else if(dy<-40) hint='◀ gira a sinistra';
  else if(dp>25) hint='▲ guarda in alto';
  else if(dp<-25) hint='▼ guarda in basso';
  pill.textContent=hint?('👆 Il punto che brilla è fuori dallo schermo: '+hint):PILL_BASE;
}
setInterval(bussola,400);

AFRAME.registerComponent('look-at-cam',{
  tick:function(){ const c=document.getElementById('cam'); if(c)this.el.object3D.lookAt(c.object3D.position); }
});

function apriScheda(h,ent){
  if(!h||h._fatto)return;
  h._fatto=true; aperti++;
  if(ent){
    ent.setAttribute('visible',false);
    ent.querySelectorAll('.hot').forEach(x=>x.classList.remove('hot'));
  }
  document.getElementById('scEm').textContent=h.em;
  document.getElementById('scTit').textContent=h.tit;
  document.getElementById('scTxt').textContent=testoScheda(h);
  /* media della scoperta (dalla regia: foto tele, canti degli uccelli…) */
  let mb=document.getElementById('scMedia');
  if(!mb){ mb=document.createElement('div'); mb.id='scMedia'; document.getElementById('scTxt').after(mb); }
  mb.textContent='';
  if(h.foto){ const im=document.createElement('img'); im.src=h.foto; im.alt=h.tit;
    im.style.cssText='width:100%;border-radius:14px;margin-top:12px;display:block'; mb.appendChild(im); }
  if(h.audio){ const au=document.createElement('audio'); au.controls=true; au.src=h.audio;
    au.style.cssText='width:100%;margin-top:10px'; mb.appendChild(au); }
  document.getElementById('scoperta').classList.add('on');
  mood('brilla');
  if(ACC==='ipo'){
    const au=mb.querySelector('audio');
    if(au){ ttsStop(); au.play().catch(()=>tts(h.tit+'. '+testoScheda(h))); }
    else tts(h.tit+'. '+testoScheda(h));
  }
}
document.querySelector('a-scene').addEventListener('click',(e)=>{
  const el=e.target; if(!el||!el.classList||!el.classList.contains('hot'))return;
  if(!tappaAttiva)return;
  apriScheda(tappaAttiva.hotspots[parseInt(el.dataset.h,10)], el.parentEl);
});

function chiudiScoperta(){
  document.getElementById('scoperta').classList.remove('on'); ttsStop();
  if(tappaAttiva && aperti>=tappaAttiva.hotspots.length){
    document.getElementById('pill').classList.remove('on');
    const g=document.getElementById('hotspots'); while(g.firstChild)g.removeChild(g.firstChild);
    tappaAttiva=null;
    audioDuck(false);                          /* il sottofondo torna pieno */
    say('Scoperta fatta! ✨ Si riparte…');
    vid.play().catch(()=>{});
    updPausaBtn();
  }else{
    say('Ce n\'è ancora qualcuno che brilla… trovatelo!');
  }
}

/* ---- controlli ---- */
function togglePausa(){
  if(vid.paused){ vid.play().catch(()=>{}); } else { vid.pause(); }
  updPausaBtn();
}
function updPausaBtn(){ document.getElementById('btnPausa').innerHTML=vid.paused?'▶<span class="lbl"> Riprendi</span>':'⏸<span class="lbl"> Pausa</span>'; }
function prossimaTappa(){
  if(!LEZ)return;
  if(tappaAttiva){
    /* tappa in corso: apre direttamente la prossima scoperta non ancora trovata
       (alternativa da tastiera/LIM al puntamento nel 360°) */
    const i=tappaAttiva.hotspots.findIndex(h=>!h._fatto);
    if(i>=0){
      const g=document.getElementById('hotspots');
      apriScheda(tappaAttiva.hotspots[i], g.children[i]||null);
      return;
    }
  }
  const t=LEZ.tappe.find(x=>!x._done);
  if(t){
    if(t.v!==vidIdx){ vidIdx=t.v; attach(LEZ.video[vidIdx]); }
    vid.currentTime=Math.max(0,t.t-0.2);
    vid.play().catch(()=>{});
  }else{ avviaQuiz(); }
  updPausaBtn();
}

/* ---- elenco scoperte (ripasso + alternativa testuale) ---- */
function apriElenco(){
  if(!LEZ){ say('Prima scegliete una lezione!'); return; }
  const box=document.getElementById('elencoBody'); box.textContent='';
  LEZ.tappe.forEach(t=>t.hotspots.forEach(h=>{
    const d=document.createElement('div'); d.className='elItem'+(h._fatto?'':' todo');
    const em=document.createElement('div'); em.className='em'; em.textContent=h.em; d.appendChild(em);
    const w=document.createElement('div');
    const h3=document.createElement('h3'); h3.textContent=h.tit; w.appendChild(h3);
    if(h._fatto){ const p=document.createElement('p'); p.textContent=testoScheda(h); w.appendChild(p); }
    d.appendChild(w); box.appendChild(d);
  }));
  vid.pause(); updPausaBtn();
  document.getElementById('elenco').classList.add('on');
}
function chiudiElenco(){
  document.getElementById('elenco').classList.remove('on');
}

/* ---- alta leggibilità (DSA) ---- */
function toggleDSA(){
  const on=document.body.classList.toggle('dsa');
  document.getElementById('btnDSA').style.background=on?'var(--rosaTxt)':'';
  try{localStorage.setItem('edu_dsa',on?'1':'0');}catch(e){}
}

/* ---- tastiera: ESC chiude l'overlay in primo piano ---- */
document.addEventListener('keydown',(e)=>{
  if(e.target&&/input|textarea|select/i.test(e.target.tagName))return;
  /* scorciatoie (utili a ipovedenti e LIM): 1-4 risposta, Spazio pausa, N prossima scoperta, R rileggi */
  if(document.getElementById('quiz').classList.contains('on')&&/^[1-4]$/.test(e.key)){
    const b=document.querySelector('#qOpts .opt[data-n="'+e.key+'"]'); if(b&&!b.disabled){ b.click(); } return;
  }
  if(e.key===' '&&LEZ&&started&&!document.querySelector('.ovl.on')){ e.preventDefault(); togglePausa(); return; }
  if((e.key==='n'||e.key==='N')&&LEZ&&!document.getElementById('menu').classList.contains('on')){ prossimaTappa(); return; }
  if((e.key==='r'||e.key==='R')&&ACC==='ipo'){ ttsRipeti(); return; }
  if(e.key!=='Escape')return;
  if(document.getElementById('coccioOvl').classList.contains('on')){ chiudiCoccio(); return; }
  const on=(id)=>document.getElementById(id).classList.contains('on');
  if(on('scoperta')){ chiudiScoperta(); return; }
  if(on('elenco')){ chiudiElenco(); return; }
  const cm=document.getElementById('ccMenu');
  if(cm.style.display==='flex'){ cm.style.display='none'; return; }
  if(on('menu')&&LEZ){ closeMenu(); }
});

/* ---- quiz ---- */
function avviaQuiz(){
  audioStop();                                 /* il quiz è in silenzio */
  vid.pause(); started=false;
  updSeekbar(); renderCue('');
  quizIdx=0;punti=0;
  document.getElementById('quiz').classList.add('on');
  say('Adesso vediamo cosa avete scoperto!');
  mostraDomanda();
}
function mostraDomanda(){
  const QZ=quizCorrente();
  const q=QZ[quizIdx];
  if(!q){ fineLezione(); return; }
  document.getElementById('qTitolo').textContent='Domanda '+(quizIdx+1)+' di '+QZ.length;
  document.getElementById('qTesto').textContent=q.q;
  document.getElementById('qEsito').textContent='';
  document.getElementById('qSapevi').style.display='none';
  document.getElementById('qLiveBtn').style.display=(quizIdx===0&&QUIZ_LIVE_OK)?'':'none';
  const box=document.getElementById('qOpts'); box.textContent='';
  tts('Domanda '+(quizIdx+1)+' di '+QZ.length+'. '+q.q+'. '+q.opts.map((o,i)=>'Risposta '+(i+1)+': '+o).join('. '),quizIdx===0);
  q.opts.forEach((o,i)=>{
    const b=document.createElement('button'); b.className='opt'; b.textContent=(ACC==='ipo'?(i+1)+'. ':'')+o; b.dataset.n=i+1;
    b.onclick=async ()=>{
      if(b.disabled)return;
      const chiave=(LEZ?LEZ.id:'-')+'|'+(i===q.ok?'ok':'ko');
      const giaVisto=!!_quizVisti[chiave];
      const mostra=MASC_QUIZ_SEMPRE||!giaVisto;
      _quizVisti[chiave]=true;
      if(i===q.ok){
        b.classList.add('giusta'); punti++;
        document.getElementById('qEsito').textContent='✨ Giusto! Guarda come brillo!';
        mood('brilla'); tts('Giusto!');
        Array.from(box.children).forEach(x=>x.disabled=true);
        if(mostra)await playCoccio(mascVideo('giusta')); else await new Promise(r=>setTimeout(r,1200));
        if(q.spiegazione){ mostraSapevi(q); } else { quizIdx++; mostraDomanda(); }
      }else{
        b.classList.add('sbagliata');
        document.getElementById('qEsito').textContent=<?php echo json_encode($BRAND['ko'], JSON_UNESCAPED_UNICODE); ?>;
        mood('sciolto'); tts(document.getElementById('qEsito').textContent);
        if(mostra)await playCoccio(mascVideo('sbagliata'));
      }
    };
    box.appendChild(b);
  });
}
/* ---- "Lo sapevi?" — feedback formativo dopo la risposta giusta (migrazione 16) ---- */
function mostraSapevi(q){
  document.getElementById('qSapeviTxt').textContent=q.spiegazione||'';
  const img=document.getElementById('qSapeviImg'), m=q.media_spiegazione||'';
  if(m && /^https:\/\//i.test(m)){ img.src=m; img.style.display='block'; }
  else { img.style.display='none'; img.removeAttribute('src'); }
  document.getElementById('qSapevi').style.display='block';
  tts('Lo sapevi? '+(q.spiegazione||''));
}
function sapeviAvanti(){ document.getElementById('qSapevi').style.display='none'; quizIdx++; mostraDomanda(); }

/* ---- QUIZ LIVE — PIN + dispositivi degli alunni (live.php + live-lim.js) ---- */
function quizLive(){
  let QZ=quizCorrente();
  if(!QUIZ_LIVE_OK){ alert('Il Quiz Live non è incluso nel piano di questa licenza.'); return; }
  if(!QZ.length||typeof EduLive==='undefined'){ alert('Quiz live non disponibile su questa pagina.'); return; }
  /* Quiz progressivo (migrazione 17): a metà lezione entrano solo le
     domande sui video già visti (q.v <= video corrente). Le domande
     generali (v null) e quelle future restano per il quiz finale.
     Se nessuna domanda ha v (lezione non ancora configurata in Regia)
     il comportamento resta quello classico: quiz completo. */
  const lezioneFinita = document.getElementById('quiz').classList.contains('on') || (LEZ && vidIdx>=LEZ.video.length);
  const conV = QZ.some(q=>q.v!=null);
  if(!lezioneFinita && conV){
    const visti = QZ.filter(q=>q.v!=null && q.v<=vidIdx);
    if(!visti.length){ alert('Non ci sono ancora domande sul contenuto visto finora: proseguite la lezione e riprovate!'); return; }
    QZ = visti;
  }
  try{vid.pause();}catch(e){} ttsStop(); started=false; updSeekbar();
  EduLive.apri({
    titolo: LEZ?LEZ.tit:'Quiz', lezione: LEZ?LEZ.id:'', livello: LIVELLO,
    apiUrl: (window.EDU_BASE||'')+'live.php',                                   /* percorsi assoluti verso app/ */
    urlRispondi: location.origin+(window.EDU_BASE||'/')+'rispondi.php',
    quiz: QZ.map(q=>({ domanda:q.q, opzioni:q.opts, g:q.ok,
      spiegazione:q.spiegazione||'', media:q.media_spiegazione||'' }))
  });
}
document.addEventListener('edu-live-fine', async (e)=>{
  const d=e.detail||{};
  track('quiz_esito', d);                      /* d.live=true lo distingue dal quiz di classe */
  track('lezione_completata',{livello:LIVELLO,live:true});
  if(LEZ) segnaFatta(LEZ.id);
  document.getElementById('quiz').classList.remove('on');
  document.getElementById('fineTxt').textContent='Quiz live completato! La classe ha risposto bene al '+(d.pct_classe!=null?d.pct_classe:'—')+'% delle domande. ✨';
  document.getElementById('fine').classList.add('on');
  say('Che squadra fantastica! ✨',true);
});

/* ---- Intro del corso: prologo a schermo intero, righe preservate ---- */
function applicaMascotteCorso(co){
  const m=(co&&co.mascotte)||null; if(!m)return;
  MASC_CFG=Object.assign({}, MASC_CFG||{}, {
    junior: m.junior!==false, senior: m.senior!==false,
    nome: m.nome||(MASC_CFG&&MASC_CFG.nome)||'', img: m.img||(MASC_CFG&&MASC_CFG.img)||''
  });
  if(m.quiz_sempre!==undefined) MASC_QUIZ_SEMPRE=!!m.quiz_sempre;
  /* video per momento: «entrambi» vale per tutte le fasce, poi la fascia specifica sovrascrive */
  if(m.video&&typeof m.video==='object'){
    const e=m.video.entrambi||{};
    MASC_LIV={ junior:Object.assign({},e,m.video.junior||{}), senior:Object.assign({},e,m.video.senior||{}) };
    MASCOTTE=MASC_LIV[LIVELLO]||{};
  }
  if(m.img){ document.querySelectorAll('img.masc, .mascImg').forEach(i=>{ i.src=m.img; }); }
}
function mostraPrologo(){
  return new Promise(res=>{
    const co=(LEZ&&LEZ.corso)||null;
    const t=String((co&&co.prologo)||(LEZ&&LEZ.prologo)||'').trim();
    if(!t){ res(); return; }
    const chiave='edu_prologo_'+(co?co.id:(LEZ.id||'x'));      /* mostrato una volta per sessione */
    try{ if(sessionStorage.getItem(chiave)){ res(); return; } sessionStorage.setItem(chiave,'1'); }catch(e){}
    const ovl=document.getElementById('prologoOvl'), btn=document.getElementById('prologoBtn');
    document.getElementById('prologoTxt').textContent=t;
    ovl.classList.add('on');
    tts(t);                                   /* letto ad alta voce in modalità ipovedenti */
    btn.onclick=()=>{ ovl.classList.remove('on'); ttsStop(); res(); };
  });
}

async function fineLezione(){
  const QZ=quizCorrente();
  document.getElementById('quiz').classList.remove('on');
  track('quiz_esito',{punti:punti,su:QZ.length,livello:LIVELLO});
  track('lezione_completata',{livello:LIVELLO});
  segnaFatta(LEZ.id);
  await playCoccio(mascVideo('fine_lezione'));              /* saluto di fine lezione */
  const tutto=corsoCompletato();
  if(tutto)await playCoccio(mascVideo('fine_corso'));       /* diploma: tutte le lezioni fatte */
  document.getElementById('fineTxt').textContent=
    (tutto?'Percorso completato! ':'')+'Lezione "'+LEZ.tit+'" completata: '+punti+' risposte giuste su '+QZ.length+'!';
  document.getElementById('fine').classList.add('on');
  tts(document.getElementById('fineTxt').textContent);
  say(tutto?'Avete completato tutto il viaggio del sale! ✨':'Che classe fantastica! ✨',true);
}

/* ---- taratura ---- */
if(new URLSearchParams(location.search).has('taratura')){
  const box=document.getElementById('tarBox'); box.style.display='block';
  setInterval(()=>{
    const cam=document.getElementById('cam'); if(!cam)return;
    const r=cam.getAttribute('rotation')||{x:0,y:0};
    let yaw=-r.y; while(yaw>180)yaw-=360; while(yaw<-180)yaw+=360;
    box.textContent='lezione: '+(LEZ?LEZ.id:'—')+' · video v='+vidIdx+' · t: '+vid.currentTime.toFixed(1)+'s · yaw: '+yaw.toFixed(0)+' · pitch: '+r.x.toFixed(0);
  },120);
}

/* ---- seek bar ---- */
const seekEl=document.getElementById('seek');
let seeking=false;
function fmt(x){x=Math.max(0,Math.floor(x||0));return String(Math.floor(x/60)).padStart(2,'0')+':'+String(x%60).padStart(2,'0');}
function updSeekbar(){
  document.getElementById('seekbar').style.display=started?'flex':'none';
  const c=document.getElementById('seekClip');
  c.textContent=(LEZ&&LEZ.video.length>1)?('clip '+(vidIdx+1)+'/'+LEZ.video.length):'';
}
vid.addEventListener('timeupdate',()=>{
  if(!seeking&&vid.duration)seekEl.value=Math.floor(vid.currentTime/vid.duration*1000);
  document.getElementById('seekTime').textContent=fmt(vid.currentTime)+' / '+(vid.duration?fmt(vid.duration):'--:--');
});
seekEl.addEventListener('input',()=>{seeking=true;});
seekEl.addEventListener('change',()=>{
  if(vid.duration)vid.currentTime=seekEl.value/1000*vid.duration;
  seeking=false;
});

/* ---- sottotitoli (file Bunny: /captions/{lingua}.vtt) ---- */
let ccLang='off', ccCues=[];
function toggleCCMenu(){
  const m=document.getElementById('ccMenu');
  m.style.display=(m.style.display==='flex')?'none':'flex';
}
function setCC(l){
  ccLang=l;
  document.getElementById('btnCC').textContent=(l==='off')?'CC':('CC·'+l.toUpperCase());
  document.querySelectorAll('#ccMenu button').forEach(b=>b.classList.toggle('on',b.dataset.cc===l));
  toggleCCMenu();
  loadCC();
}
/* varianti di codice lingua che Bunny può usare come nome file */
const CC_VAR={
  it:['it','it-IT','it_IT','ita','italian','auto'],
  en:['en','en-US','en_US','eng','english'],
  fr:['fr','fr-FR','fra','french'],
  es:['es','es-ES','spa','spanish'],
  de:['de','de-DE','deu','ger','german']
};
const _ccFound={};   // guid+lang -> variante che funziona
async function loadCC(){
  ccCues=[]; renderCue('');
  if(ccLang==='off'||!LEZ)return;
  const v=LEZ.video[vidIdx]; if(!v)return;
  const key=v.guid+'|'+ccLang;
  const vars=_ccFound[key]?[_ccFound[key]]:(CC_VAR[ccLang]||[ccLang]);
  let lastErr='404';
  for(const code of vars){
    const url=CDN+v.guid+'/captions/'+code+'.vtt';
    try{
      const r=await fetch(url);
      if(!r.ok){ lastErr='404'; console.log('[CC] non trovato:',url); continue; }
      const cues=parseVTT(await r.text());
      if(!cues.length){ lastErr='vuoto'; console.log('[CC] file vuoto:',url); continue; }
      ccCues=cues; _ccFound[key]=code;
      console.log('[CC] OK:',url,'·',cues.length,'battute');
      return;
    }catch(e){ lastErr='rete/CORS'; console.log('[CC] bloccato (rete/CORS):',url); }
  }
  renderCue(lastErr==='rete/CORS'
    ? 'Sottotitoli bloccati dal server (CORS) — vedi console'
    : 'Sottotitoli '+ccLang.toUpperCase()+' non ancora disponibili per questo video');
  setTimeout(()=>{ if(!ccCues.length)renderCue(''); },3000);
}
function parseVTT(txt){
  const cues=[];
  const re=/(?:(\d+):)?(\d+):(\d+)[.,](\d+)\s*-->\s*(?:(\d+):)?(\d+):(\d+)[.,](\d+)/;
  txt.replace(/\r/g,'').split('\n\n').forEach(b=>{
    const lines=b.split('\n').filter(x=>x.trim()!=='');
    for(let i=0;i<lines.length;i++){
      const m=lines[i].match(re);
      if(m){
        const t0=(+(m[1]||0))*3600+(+m[2])*60+(+m[3])+(+m[4])/1000;
        const t1=(+(m[5]||0))*3600+(+m[6])*60+(+m[7])+(+m[8])/1000;
        const text=lines.slice(i+1).join('\n').replace(/<[^>]+>/g,'');
        if(text)cues.push({t0:t0,t1:t1,text:text});
        break;
      }
    }
  });
  return cues;
}
function renderCue(t){
  const b=document.getElementById('ccBox');
  b.textContent=t||''; b.style.display=t?'block':'none';
  document.body.classList.toggle('cc-on',!!t);
}
vid.addEventListener('timeupdate',()=>{
  if(ccLang==='off'||!ccCues.length)return;
  const c=ccCues.find(x=>vid.currentTime>=x.t0&&vid.currentTime<=x.t1);
  renderCue(c?c.text:'');
});

setLivello(LIVELLO);
try{ if(localStorage.getItem('edu_dsa')==='1')toggleDSA(); }catch(e){}
setAcc(ACC,true);
buildMenu();               /* mostra "Carico le lezioni…" */
(async function(){
  const tok=_qs.get('lez');
  if(tok){
    /* anteprima bozze / copie personali dei docenti, via token */
    try{
      const j=await eduApi('action=lez&token='+encodeURIComponent(tok));
      if(j&&j.ok&&j.lezione){
        CATALOGO=[{id:j.lezione.id,em:j.lezione.em,cls:j.lezione.cls,tit:j.lezione.tit,
                   sub:j.lezione.sub,durata:j.lezione.durata,stato:'pubblicata'}];
        LEZ_CACHE[j.lezione.id]=j.lezione;
        buildMenu();
        avviaLezione(0);
        return;
      }
    }catch(e){ console.log('[SIC] anteprima KO',e); }
    say('Anteprima non trovata: il link è scaduto o non valido.',true);
    return;
  }
  try{
    await caricaMenu(); buildMenu();
    /* splash: un tocco sblocca l'audio (policy autoplay) e lancia il benvenuto */
    let vista=false; try{ vista=sessionStorage.getItem('edu_intro')==='1'; }catch(e){}
    if(mascVideo('inizio_corso')&&!vista)document.getElementById('avvio').classList.add('on');
  }
  catch(e){
    console.log('[SIC] menu KO',e);
    const box=document.getElementById('menuLez'); box.textContent='';
    const p=document.createElement('p');
    p.style.cssText='color:#b8506a;font-size:14px';
    p.textContent='Non riesco a caricare le lezioni: controllate la connessione e ricaricate la pagina.';
    box.appendChild(p);
  }
})();
</script>
<script src="<?php echo htmlspecialchars(rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/') . '/'); ?>live-lim.js?v=13"></script>
</body>
</html>
