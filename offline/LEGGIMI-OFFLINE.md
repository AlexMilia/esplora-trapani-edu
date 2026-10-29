# Pacchetto OFFLINE — il player in classe senza connessione

(v1 · 29/10/2026 · player v2.4)

A scuola può mancare la linea, o un accordo può chiedere che nulla passi da internet.
Il pacchetto offline è una **cartella autonoma** (chiavetta USB o portatile) con il player 360,
le lezioni di un cliente e i video in locale. In classe non serve nessuna connessione.

```
offline/
  costruisci-player.sh   renderizza app/index.php in modalità offline → offline/player/index.html (serve php)
  crea-pacchetto.js      costruisce la cartella del pacchetto per un cliente (serve node ≥ 18)
  avvia.js · AVVIA.bat · avvia.sh   server locale del pacchetto (copiati dentro ogni pacchetto)
  player/index.html      player statico generato (rigenerare dopo ogni modifica a app/index.php)
  pacchetti/<cliente>/   i pacchetti: dati.js + script di download versionati; video/ e media/ NO (pesano)
```

## Come si costruisce (dal PC con la repository)

```bash
bash offline/costruisci-player.sh                     # 1. player statico (una volta, e dopo ogni modifica a index.php)
node offline/crea-pacchetto.js --tenant esplora-trapani   # 2. contenuti del cliente dal database (anon key dal config)
cd offline/pacchetti/esplora-trapani && bash scarica-video.sh   # 3. video e media da Bunny (una volta, ~90 MB a clip a 720p)
```

Opzioni utili del passo 2:
- `--bozza vendemmia-alagna=TOKEN` include una lezione **in bozza** tramite il token di anteprima
  (Regia → lezione → «Copia link anteprima»: il token è ciò che segue `?lez=`). Così una lezione
  ancora da rifinire si può presentare dal portatile senza pubblicarla alle scuole.
- `--res 1080p` scarica gli mp4 a 1080p invece che a 720p (LIM grandi; pesa il doppio).
- `--da-dati offline/pacchetti/esplora-trapani/dati.js` rigenera script e player da un `dati.js`
  già pronto, senza connessione.

Il pacchetto `esplora-trapani` è già versionato con il suo `dati.js` (4 lezioni degli Antichi
Mestieri, vendemmia compresa, con i titoli dei capitoli): basta eseguire i passi 1 e 3.

## Come si usa a scuola

1. Copiare la cartella del pacchetto sul portatile (con i video già scaricati).
2. **Windows:** doppio clic su `AVVIA.bat` · **Mac/Linux:** `bash avvia.sh`.
   Si apre il browser su `http://localhost:8765` con il menu delle lezioni.
3. Guidare la lezione con il **telecomando** in basso (o con un clicker: tasto avanti = PagGiù).
   Il pulsante **?** spiega tutto in una pagina.

Serve **Node.js** sul portatile (gratuito, nodejs.org, versione LTS). Se manca, `AVVIA` prova PHP
e poi Python, ma con Python i salti avanti/indietro nei video possono non funzionare.

**Non aprire `index.html` con doppio clic**: i browser bloccano i video 360 (texture WebGL) aperti
da `file://`. Serve sempre il piccolo server locale di `AVVIA`.

## Cosa cambia rispetto al player online

| Online | Offline |
|---|---|
| `api.php` → Supabase, risposte cifrate | `dati.js` caricato dalla pagina (`window.EDU_DATI`) |
| video HLS da Bunny (`playlist.m3u8`) | `video/<guid>.mp4` locale (720p o 1080p) |
| sottotitoli `captions/it.vtt` da Bunny | `video/<guid>.it.vtt` se scaricati |
| A-Frame e hls.js dal CDN | `lib/` locale (gli stessi file di `demo-vr/lib`) |
| mascotte YouTube | solo se salvata come `video/yt_<id>.mp4`, altrimenti il player la salta |
| Quiz live con i telefoni, tracking anonimo | non disponibili (serve il server) |
| licenza del cliente controllata a ogni apertura | il pacchetto è una fotografia: va rigenerato per aggiornarlo |

Il player è lo **stesso `index.php`**: la modalità offline si accende solo quando la pagina viene
renderizzata con `EDU_OFFLINE=1` (lo fa `costruisci-player.sh`). In produzione non cambia nulla.

## Sicurezza

Il pacchetto contiene i contenuti in chiaro (`dati.js`) e i video: va consegnato solo a chi ha
una licenza, come si farebbe con una chiavetta di materiale didattico. Non va pubblicato online.
