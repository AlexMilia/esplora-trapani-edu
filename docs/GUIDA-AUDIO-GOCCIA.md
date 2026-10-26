# IL VIAGGIO DI UNA GOCCIA — audio di sottofondo dalla regia
(12/09/2026 · migrazione 25 · player v2.2 · regia v15.2)

## Dove carico gli audio?
**Bunny Storage** — la scelta consigliata: stesso fornitore dei video, stessa
fattura, CDN veloce, e ti dà un URL pubblico diretto al file.
1. dash.bunny.net → **Storage** → *Add Storage Zone* → nome `esplora-audio`
   (regione Europa).
2. Dentro la zona crea la cartella `goccia/` e trascina i file.
3. Collega una **Pull Zone** (te lo propone lui): ottieni URL del tipo
   `https://esplora-audio.b-cdn.net/goccia/vasche-fredde.mp3`.
4. Quell'URL si incolla in regia. Deve finire con `.mp3` (o .m4a/.ogg).

In alternativa va bene **Backblaze B2** (già usato per le foto 360) o una
cartella su Aruba: serve solo un URL **https diretto al file**, pubblico.
NON funzionano: link a YouTube/Vimeo, a Drive/Dropbox (sono pagine, non file),
o `http://` — la regia li rifiuta con un messaggio che spiega perché.

## Formato dei file
- **mp3** (o m4a), **128 kbps** bastano per un sottofondo.
- Esporta già a volume contenuto, poi si regola in regia.
- Nomi senza spazi né accenti: `vasche-fredde.mp3`, `voce-goccia-01.mp3`.
- Se è musica d'ambiente, va bene anche corta: di serie va in loop.

## Come si mette (regia)
Lezione → **Media della lezione (playlist)** → sulla riga della clip, campo **🎵**:
- incolla l'URL del file audio;
- imposta il **volume** (0-100, di serie 45 = sottofondo discreto);
- **▶** ascolta subito per provare il livello.
Il salvataggio è immediato; in classe si vede entro 5 minuti (cache) oppure
cancella `dati/cache_*.json`.

## Come si comporta in classe
- Parte **con la clip** e si ferma in pausa; riprende alla ripresa.
- **Si abbassa al 25%** quando parla la mascotte, si apre una scoperta o la
  voce legge in modalità ipovedenti; torna pieno subito dopo.
- Cambia da solo a ogni clip; **il quiz è in silenzio**.
- Di serie va in **loop** finché la clip dura (campo `audio_loop` in
  `edu_media`: se ti serve lo esponiamo anche in regia).

## Deploy
1. Supabase: esegui `migrazione_25_audio_clip.sql` (idempotente; rinomina anche
   il corso in «Il viaggio di una goccia»).
2. FTP: `index.php`, `regia-edu.php`, `regia-edu.html` dalla cartella `app/`.
3. Cancella `dati/cache_*.json`.

## Test eseguiti
Migrazione 25 su Postgres 16 (x2, audio nel JSON della lezione) · player 10/10
(aggancio, volume, loop, pausa/ripresa, abbassamento su scoperta e voce, cambio
clip, clip senza audio, silenzio nel quiz) · regia 7/7 (validazioni URL e
volume, salvataggio, rimozione).
**Nota**: trovato e corretto lo stesso difetto già visto per il LIS —
`normalizzaLezione` scartava il campo `audio`; ora è conservato.
