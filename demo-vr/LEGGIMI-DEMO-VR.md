# ESPLORA TRAPANI EDU — DEMO VR per Meta Quest
(v1.2 · 23/09/2026 · cartella autonoma)

## Cosa c'è
- `index.html` — la demo: landing con un solo tasto **ENTRA**, menu delle
  lezioni ad arco davanti al visitatore, video 360 nella sfera, tappe con i
  cerchi che brillano, schede delle scoperte, quiz finale non punitivo.
- `dati.json` — le lezioni (dalla cache reale del player: tappe, hotspot, quiz).
  Solo **«Il mestiere del salinaio»** ha i suoi video: le altre cinque usano lo
  stesso video come segnaposto anche in produzione, quindi qui compaiono
  come **«in arrivo»** (visibili, non cliccabili). Per attivarle: `"soon": false`
  quando avranno i loro video.
- `vr-logic.js` — la logica (timeline, quiz, coordinate); testata in node.
- `lib/` — A-Frame 1.6 e hls.js in locale: **nessuna dipendenza esterna**
  a parte i video, che arrivano dal CDN Bunny (stessa libreria del player).
- `video/` — vuota: serve solo per la modalità offline (sotto).

## Come si mette online (2 minuti)
La realtà virtuale nel browser (WebXR) funziona **solo in HTTPS**: la cartella va
caricata sul sito, ad esempio in `/project/edu/vr/`, e si apre
`https://www.alessandromilia.it/project/edu/vr/`.
Nota: se Bunny ha la protezione «Allowed referrers» impostata su
alessandromilia.it, la demo deve stare su quel dominio (come il player).

## Nel visore (Meta Quest 2/3/3S)
1. Apri **Browser** sul Quest, vai all'indirizzo della demo e salvala nei
   **preferiti** (o mettila come pagina iniziale).
2. Il visitatore indossa il visore, vede il grande tasto **ENTRA ▸**, lo tocca col
   controller: parte il video e si entra in VR. Un gesto solo.
3. Nel menu punta una card e premi il grilletto. Nella lezione: guardati intorno,
   punta i **cerchi rosa che brillano**, grilletto → si apre la scheda, «Ho capito!»
   → letti tutti, il video riparte. Alla fine il quiz: punta la risposta.
4. Premendo il tasto Oculus/Meta si esce dalla VR e la pagina torna alla
   landing, pronta per il prossimo visitatore.
Senza controller (Cardboard o schermo) funziona lo **sguardo**: fissa un
elemento per 1,6 secondi. Con i controller collegati lo sguardo si spegne
da solo, per non far scattare clic guardando.

## Se il video resta NERO (v1.2)
1. Apri `prova-video.html` nel Browser del Quest (in 2D), premi «Avvia la prova»
   e leggi i tre risultati:
   - **1 = HTTP 403** → il dominio dove hai messo la demo non è autorizzato su
     Bunny: Stream → libreria *esplora-trapani* → Security → *Allowed referrers*
     → aggiungi il dominio (o metti la demo su alessandromilia.it, come il player).
   - **1 = bloccato / CORS** → in Bunny abilita CORS o l'header
     `Access-Control-Allow-Origin` per il dominio.
   - **2 parte ma 3 è nera** → problema di texture WebGL (CORS sul video): stessa
     cura del punto sopra.
   - **2 = play rifiutato** → il browser vuole un tocco: nella demo il tasto ENTRA
     sblocca il video prima di entrare in VR (v1.2).
2. Nella demo vera puoi accendere la diagnostica dentro il visore aggiungendo
   `?diag=1` all'indirizzo: un pannello in basso mostra stato del video, sorgente,
   texture e l'eventuale codice d'errore.
3. Dalla v1.2 la demo usa l'**mp4 diretto** (1080p, poi 720p) e passa a HLS solo
   se entrambi falliscono: è il percorso che il Browser del Quest gestisce meglio.

## Consigli per una fiera / stand
- Wi-Fi decente: i video sono in streaming (HLS adattivo, altrimenti mp4 720p).
- Volume del visore al 60-70%: Mattia parla nel video.
- Il Quest spegne lo schermo dopo poco se nessuno lo indossa: basta
  rimetterlo, la pagina resta dov'era.
- Se il video non parte: controlla che l'indirizzo sia **https** e che il
  browser sia il Browser di Meta (non un'app di terze parti).

## Modalità OFFLINE (senza Wi-Fi)
1. Scarica gli mp4 da Bunny (dashboard → il video → Download, 720p o 1080p).
2. Rinominali `video/<GUID>.mp4` (i GUID sono in `dati.json`).
3. In `index.html` metti `const VIDEO_LOCALI = true;`.
4. Servi la cartella in HTTPS/localhost anche in locale (es. un piccolo server
   sul PC dello stand e il Quest sulla stessa rete, oppure un hotspot).

## Controllo «si clicca con i controller?» (v1.1)
Simulato il laser dei controller con three.js (lo stesso motore di A-Frame)
sui 31 hotspot reali e su tutti i pulsanti. **Trovato e corretto**: l'anello
ha il centro vuoto, e mirando al pallino bianco (dove si mira d'istinto) il
click non partiva in 31 casi su 31. Ora ogni hotspot ha un bersaglio pieno
invisibile di 0,7 m (≈5° di tolleranza) e si illumina di bianco quando il
laser lo tocca. Verificati anche pulsanti «Ho capito», risposte del quiz,
«Torna alle lezioni» e le 6 card del menu (anche quelle a ±60°). Nel sorgente
di A-Frame: grilletto → `triggerdown` → `click` sull'elemento puntato; il
raycaster aggiorna da solo la lista dei bersagli aggiunti a lezione avviata.
Test: `node test-raycast-hotspot.js`, `node test-raycast-pulsanti.js`.

## Test eseguiti
Logica: 20 verifiche in node con le lezioni reali (coordinate degli hotspot
identiche al player, timeline delle tappe di tutte le 6 lezioni, quiz, a-capo,
menu ad arco). Pagina: script validi. I video sul CDN non sono verificabili
dalla sandbox (dominio non raggiungibile): sono gli stessi GUID del player in
esercizio. **Non ho un Quest qui: la prima prova nel visore la fai tu** — se
qualcosa non torna (ad es. il video nero), dimmi cosa vedi e correggiamo.
