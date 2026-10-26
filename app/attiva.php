<?php
/* ESPLORA TRAPANI EDU — attiva.php · pagina pubblica di richiesta attivazione · v1.0 (02/09/2026)
   Scrive in edu_richieste con la anon key (policy: solo INSERT per anon). Le richieste compaiono
   nella regia → Clienti & Licenze → Richieste, con «Crea cliente» in un click. */
define('EDU_OK', 1);
if (is_file(__DIR__ . '/dati/config.php')) { require __DIR__ . '/dati/config.php'; }
if (empty($SUPA_URL))  $SUPA_URL  = 'https://sdqzqzmkhbkkibjzauox.supabase.co';
if (empty($SUPA_ANON)) $SUPA_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkcXpxem1raGJra2lianphdW94Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwNzM4NDYsImV4cCI6MjA5MDY0OTg0Nn0.SQ-de_vaL4op7BXLRg7YjUUP0H03-k4Ym2k0W4h9huE';
if (($_SERVER['HTTP_HOST'] ?? '') === 'alessandromilia.it') { header('Location: https://www.alessandromilia.it' . ($_SERVER['REQUEST_URI'] ?? '/'), true, 301); exit; }
?>
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Esplora Trapani Edu — Attiva per la tua scuola</title>
<meta name="description" content="Lezioni immersive in video 360° sul territorio di Trapani per la scuola primaria e secondaria: saline, antichi mestieri, quiz live, accessibilità ipovedenti e LIS. Richiedi l'attivazione per la tua scuola.">
<style>
  :root{--rosa:#e8788a;--rosa2:#b8506a;--oro:#c9a15a;--sale:#faf7f2;--ink:#3a2e2a;--grigio:#6b625d}
  *{box-sizing:border-box}
  body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--sale);color:var(--ink);line-height:1.5}
  .wrap{max-width:900px;margin:0 auto;padding:28px 20px 60px}
  header{text-align:center;margin-bottom:26px}
  header .k{font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#8a6a2b;font-weight:700}   /* oro scuro: 5.0:1 su sale */
  h1{font-size:clamp(26px,4vw,40px);color:var(--rosa2);margin:6px 0 8px}
  .sub{font-size:17px;color:var(--grigio);max-width:640px;margin:0 auto}
  .griglia{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px;margin:26px 0}
  .box{background:#fff;border-radius:16px;padding:16px 18px;box-shadow:0 4px 16px rgba(58,46,42,.07)}
  .box b{display:block;color:var(--rosa2);margin-bottom:4px}
  .box p{margin:0;font-size:14px;color:var(--grigio)}
  form{background:#fff;border-radius:20px;padding:24px;box-shadow:0 6px 22px rgba(58,46,42,.09);max-width:640px;margin:0 auto}
  label{display:block;font-weight:700;margin:12px 0 5px;font-size:14px}
  input,select,textarea{width:100%;font:inherit;padding:11px 13px;border:2px solid #eadfce;border-radius:12px;background:var(--sale)}
  input:focus,select:focus,textarea:focus{outline:3px solid var(--oro);border-color:var(--oro)}
  button{font:inherit;font-weight:800;font-size:18px;color:#fff;background:var(--rosa2);border:none;border-radius:14px;padding:14px;width:100%;margin-top:18px;cursor:pointer}
  button[disabled]{opacity:.6}
  .ok{display:none;text-align:center;background:#fff;border-radius:20px;padding:34px 24px;max-width:640px;margin:0 auto;box-shadow:0 6px 22px rgba(58,46,42,.09)}
  .ok h2{color:#2f7a46;margin:0 0 8px}
  .err{color:#8c2f2f;background:#fdeaea;border-radius:10px;padding:10px;margin-top:12px;display:none}
  .privacy{font-size:12px;color:var(--grigio);margin-top:10px}
  footer{text-align:center;font-size:12px;color:var(--grigio);margin-top:30px}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="k">Esplora Trapani Edu</div>
    <h1>Il territorio entra in classe, a 360°</h1>
    <p class="sub">Lezioni immersive girate nelle saline e nelle botteghe degli antichi mestieri di Trapani, con quiz live sui dispositivi degli alunni e accessibilità per ipovedenti e sordi (interprete LIS). Per la primaria e la secondaria di primo grado.</p>
  </header>

  <div class="griglia">
    <div class="box"><b>🧂 Contenuti veri</b><p>Raccontati da chi lavora davvero: il salinaio, i corallari, i marmisti. Fonti primarie, validate.</p></div>
    <div class="box"><b>🎮 Quiz live</b><p>PIN sulla LIM, gli alunni rispondono dal telefono. Senza classifiche punitive, con la spiegazione dopo ogni domanda.</p></div>
    <div class="box"><b>♿ Accessibile</b><p>Modalità ipovedenti (testo grande + lettura vocale) e interprete LIS sincronizzato. Sempre incluse.</p></div>
    <div class="box"><b>📊 Report per la scuola</b><p>Statistiche anonime per classe: nessun dato di alunni, mai. GDPR by design.</p></div>
  </div>

  <form id="f" onsubmit="return invia(event)">
    <h2 style="margin:0 0 4px;color:var(--rosa2)">Richiedi l'attivazione</h2>
    <p style="margin:0;color:var(--grigio);font-size:14px">Ti ricontattiamo per attivare la licenza della tua scuola o del tuo ente.</p>
    <label for="scuola">Scuola / Ente *</label><input id="scuola" required maxlength="120" placeholder="es. Istituto Comprensivo Pagoto, Erice">
    <label for="referente">Referente</label><input id="referente" maxlength="120" placeholder="Nome e cognome">
    <label for="email">Email *</label><input id="email" type="email" required maxlength="120" placeholder="nome@scuola.edu.it">
    <label for="telefono">Telefono</label><input id="telefono" maxlength="40">
    <label for="interesse">Cosa vi interessa?</label>
    <select id="interesse"><option value="salina">Sale in Classe · le saline di Trapani</option><option value="mestieri">Antichi Mestieri di Trapani</option><option value="entrambi">Entrambi</option><option value="altro">Altro / un percorso su misura</option></select>
    <label for="messaggio">Messaggio</label><textarea id="messaggio" rows="3" maxlength="1000" placeholder="Classi, periodo, esigenze particolari…"></textarea>
    <input id="hp" style="display:none" tabindex="-1" autocomplete="off" aria-hidden="true" aria-label="lascia vuoto">
    <button id="btn" type="submit">Invia la richiesta ▸</button>
    <div class="err" id="err"></div>
    <p class="privacy">I dati inseriti servono solo per ricontattarti. Nessun dato di alunni viene raccolto.</p>
  </form>

  <div class="ok" id="ok">
    <h2>Richiesta ricevuta ✨</h2>
    <p>Grazie! Ti scriviamo a breve all'indirizzo indicato per attivare Esplora Trapani Edu per la tua scuola.</p>
  </div>

  <footer>Esplora Trapani · Sale in Classe · Trapani</footer>
</div>
<script>
const SUPA_URL=<?php echo json_encode($SUPA_URL, JSON_UNESCAPED_SLASHES); ?>, SUPA_ANON=<?php echo json_encode($SUPA_ANON); ?>;
async function invia(e){
  e.preventDefault();
  if(document.getElementById('hp').value) return false;      /* honeypot anti-bot */
  const btn=document.getElementById('btn'), err=document.getElementById('err'); err.style.display='none'; btn.disabled=true;
  const riga={ scuola:v('scuola'), referente:v('referente')||null, email:v('email'), telefono:v('telefono')||null,
               interesse:v('interesse'), messaggio:v('messaggio')||null };
  try{
    const r=await fetch(SUPA_URL+'/rest/v1/edu_richieste',{ method:'POST',
      headers:{ 'Content-Type':'application/json', 'apikey':SUPA_ANON, 'Authorization':'Bearer '+SUPA_ANON, 'Prefer':'return=minimal' },
      body:JSON.stringify(riga) });
    if(r.status===201){ document.getElementById('f').style.display='none'; document.getElementById('ok').style.display='block'; window.scrollTo(0,0); return false; }
    throw new Error('HTTP '+r.status);
  }catch(ex){ err.textContent='Non siamo riusciti a inviare la richiesta ('+ex.message+'). Riprova o scrivi a info@esploratrapani.it'; err.style.display='block'; btn.disabled=false; }
  return false;
}
function v(id){ return (document.getElementById(id).value||'').trim(); }
</script>
</body>
</html>
