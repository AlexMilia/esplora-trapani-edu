# La vendemmia (Cantina Alagna) — piano di rimontaggio dei video

(29/10/2026 · lezione `vendemmia-alagna`, corso Antichi Mestieri · riprese del 4/9/2026)

## Dove siamo

- La lezione **esiste** in regia con 9 clip su Bunny, 27 tappe e 27 scoperte, quiz 6+6, ma era in stato
  **bozza**: per questo non compariva nel player (il catalogo mostra solo `pubblicata` e `soon`).
  Dal 29/10 è in stato **soon**: compare nel menu come «🔒 Prossimamente» finché i video non sono
  rimontati. Per metterla in onda basta cambiare lo stato in regia (Pubblicata).
- Nel **pacchetto offline** `esplora-trapani` la vendemmia è inclusa e giocabile fin da ora
  (presentazioni dal portatile, non dalle scuole).
- I titoli dei 9 capitoli sono nella migrazione 32 (indice «☰ Capitoli» del telecomando).

## Il problema segnalato

1. Molte inquadrature **seguono Alessandro** invece di Ercole Alagna, che è chi racconta.
2. Alcune clip sono **deformate**.
3. Alcune scene **non c'entrano** (chiacchiere con Alessandro, non il vino).

> **Nota onesta.** Da questo ambiente di lavoro Bunny e i file Insta360 non sono raggiungibili, quindi
> non ho potuto guardare le scene una per una. Qui sotto c'è la mappa del montaggio attuale ricavata
> dalla regia (file sorgente, tagli, argomenti), i criteri di scelta, le ricette ffmpeg per i tre
> problemi e uno strumento (`strumenti/taglia-scene.html`) per segnare IN/OUT guardando i file
> originali ed esportare i comandi di taglio. La scelta finale delle scene va fatta davanti al girato.

## Mappa del montaggio attuale (dalla regia)

| Cap. | GUID Bunny | File sorgente (Insta360) | Taglio | Durata | Di cosa parla Ercole (dalle scoperte) |
|---|---|---|---|---|---|
| 1 In vigna: la vendemmia a mano | `3bf24071…` | VID_20260904_082743_00_567 | 0–159 s | 2:39 | catarratto a mano · viti giovani/vecchie non a macchina · rimorchio → cantina · mosto sulle foglie → aceto |
| 2 Quanto è dolce l'uva? Il mostimetro | `4fa3126f…` | VID_20260904_071219_00_555 | 50–128 s | 1:18 | campione di mosto · spinta di Archimede · mostimetro di Klosterneuburg |
| 3 L'uva entra in cantina | `aa257284…` | VID_20260904_071219_00_555 | 158–280 s | 2:02 | tramoggia · pigiatura · pressa soffice |
| 4 Una cantina nata nel 1946 (1) | `db4245c5…` | VID_20260904_072044_00_556 | 55–148 s | 1:33 | nonno Giuseppe e il papà enotecnico ad Alba · scuola chiusa per la guerra · la prima stanza |
| 5 Una cantina nata nel 1946 (2) | `b5c9da99…` | VID_20260904_073328_00_557 | 0–50 s | 0:50 | vasche di cemento vetrificate · 350.000 litri |
| 6 Botti sempre piene (1) | `86f55f85…` | VID_20260904_072044_00_556 | 278–348 s | 1:10 | botti senza rubinetto · la barca di legno · sempre piena |
| 7 Il segreto della paraffina (2) | `53251350…` | VID_20260904_072044_00_556 | 608–697 s | 1:29 | castagno amaro · paraffina nella tanica militare · strato protettivo · «parum affinis» |
| 8 Il vino di Sicilia (1) | `0243d1fc…` | VID_20260904_075009_00_559 | 0–114 s | 1:54 | Giulio Cesare · da nomadi a contadini · vite e ulivo, Polifemo |
| 9 Ottanta ettari (2) | `82f82eec…` | VID_20260904_075009_00_559 | 162–204 s | 0:42 | 80 ettari · vitigni autoctoni (zibibbo, catarratto, insolia, grillo) |

Totale 13:17. I **buchi** tra i tagli dello stesso file (es. 128→158 s del `_555`, 148→278 e
348→608 s del `_556`, 114→162 s del `_559`) sono i pezzi già scartati: lì probabilmente ci sono le
chiacchiere con Alessandro e i cambi di posizione. Vanno ricontrollati solo se manca qualcosa.

## Criteri per scegliere le scene (da applicare davanti al girato)

**Tenere** una scena se Ercole:
- spiega un gesto o uno strumento della vendemmia/cantina (taglio del grappolo, mostimetro, tramoggia, pressa, botti, paraffina);
- racconta la storia della cantina o del vino di Sicilia;
- risponde a una domanda **dei bambini** o a una domanda che un bambino potrebbe fare.

**Scartare** se:
- parla con Alessandro di altro (battute, organizzazione delle riprese, «picchiare», ecc.);
- la camera è in movimento rapido, si cambia posizione o si inquadra chi filma;
- c'è un'informazione che va **validata** (tutte le scoperte sono ancora `da_validare`: dopo il
  montaggio va fatta una lettura con Ercole o con un enologo).

Regola del player: **le pause-scoperta non devono cadere sul parlato** — dopo il rimontaggio i tempi
`t` delle tappe vanno ritarati con l'editor piatto della regia.

## Le tre ricette ffmpeg

### 1. «La camera segue me invece di lui»: ricentrare il 360 su Ercole (niente deformazione)

In un video 360 equirettangolare non esiste una «inquadratura»: esiste solo **da che parte parte lo
sguardo** della classe (yaw 0 = davanti). Oggi gli hotspot della vendemmia stanno quasi tutti tra
yaw −25 e −170: Ercole è **a sinistra o dietro** rispetto alla direzione iniziale. Basta ruotare il
video, senza reinquadrarlo né tagliarlo:

```bash
# ruota il 360 di 100° perché ciò che oggi sta a yaw -100 finisca davanti (yaw 0)
ffmpeg -i in.mp4 -vf "v360=e:e:yaw=-100:interp=lanczos" -c:v libx264 -crf 18 -preset slow -c:a copy out.mp4
```

Il segno della rotazione dipende dalla convenzione del filtro rispetto a quella del player
(videosfera ruotata di −90°): **provare su una clip sola**, aprirla in `index.php?taratura` e
controllare dove finisce Ercole; se è dalla parte sbagliata, invertire il segno. Trovato l'angolo
`D` per una clip, gli hotspot di quella clip si spostano in blocco in SQL (idempotente per clip):

```sql
-- D = gradi di cui si è ruotato il video (stesso segno del player). Esempio: D = 100
update edu_hotspot h set yaw = ((h.yaw + 100 + 180)::numeric % 360 + 360) % 360 - 180
  from edu_tappe t where t.id = h.tappa_id and t.media_id = '<uuid della clip in edu_media>';
```

Vantaggio: si tengono i video che ci sono (niente nuove riprese), la classe vede subito Ercole, e chi
vuole può sempre girarsi. Per le versioni **16:9 «che seguono il personaggio»** (come fatto per
Franca Vario) il percorso è Insta360 Studio → FreeCapture, con FOV ≤ 110° e keyframe lenti: è la
«deformazione» tipica un FOV troppo largo o un Reframe con proiezione sbagliata.

### 2. «Alcune clip sono deformate»: controllo e correzione

Controllo rapido: un equirettangolare deve essere esattamente **2:1** (es. 3840×1920, 5760×2880) e
Bunny deve riceverlo così, senza ritagli.

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,codec_name -of csv=p=0 in.mp4
```

Se non è 2:1, è stato esportato con la proiezione sbagliata (o «Reframe» a schermo piatto) e va
riesportato da Insta360 Studio come **360 equirettangolare**, cucitura *Stitching AI*, *Protezioni
lenti* coerenti con il case usato (per il corallo era «Case subacqueo off»; per i tappeti «Standard»).
Se invece è 2:1 ma l'orizzonte è storto, la correzione è ancora v360:

```bash
ffmpeg -i in.mp4 -vf "v360=e:e:pitch=-6:roll=2" ... out.mp4     # raddrizza di pochi gradi
```

### 3. Tagliare le scene (dopo averle scelte)

Dal file originale, con i tempi segnati con `strumenti/taglia-scene.html`:

```bash
# taglio senza ricodifica (veloce, i keyframe possono spostare l'inizio di ~1 s)
ffmpeg -ss 00:00:50 -to 00:02:08 -i VID_20260904_071219_00_555.mp4 -c copy cap2_mostimetro.mp4
# taglio preciso + ricentratura in un passaggio
ffmpeg -ss 00:00:50 -to 00:02:08 -i VID_...mp4 -vf "v360=e:e:yaw=-100" -c:v libx264 -crf 18 -c:a aac cap2.mp4
```

Poi: caricare su Bunny (stessa libreria `esplora-trapani`), sostituire il GUID nella playlist della
regia, ritarare `t` e yaw/pitch delle tappe con l'editor piatto, togliere lo stato «soon».

## Proposta di struttura (6 capitoli invece di 9)

Le coppie «parte 1 / parte 2» nascono da tagli tecnici, non da argomenti. Con il rimontaggio
conviene arrivare a **un capitolo = un argomento**, ciascuno di 1–2 minuti:

1. In vigna: la vendemmia a mano (cap. 1 attuale, da asciugare a ~2 min)
2. Il mostimetro: quanto è dolce l'uva (cap. 2)
3. L'uva entra in cantina: tramoggia, pigiatura, pressa soffice (cap. 3)
4. Una cantina nata nel 1946 (cap. 4 + 5)
5. Botti sempre piene e il segreto della paraffina (cap. 6 + 7)
6. Il vino di Sicilia, da Giulio Cesare agli 80 ettari di oggi (cap. 8 + 9)

Le 27 scoperte già scritte restano valide: cambiano solo clip e tempi. L'intro della lezione dice
già «sei brevi racconti».

## Checklist

- [ ] Guardare i 5 file sorgente con `strumenti/taglia-scene.html` e segnare IN/OUT (tieni/scarta)
- [ ] Decidere l'angolo di ricentratura per clip (dove sta Ercole) e provarlo su una clip
- [ ] Tagliare/ricodificare, controllare 2:1, caricare su Bunny
- [ ] In regia: nuovi GUID, titoli dei capitoli (migr. 32), ritaratura tappe, hotspot da validare → validati
- [ ] Stato lezione: soon → pubblicata; cancellare `dati/cache_*.json` sul server
- [ ] Rigenerare il pacchetto offline (`node offline/crea-pacchetto.js --tenant esplora-trapani`)
