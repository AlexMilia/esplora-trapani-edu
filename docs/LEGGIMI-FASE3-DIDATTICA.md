# Fase 3 · Blocco didattico — messa in produzione

Che cosa aggiunge: gli **esiti dei quiz diventano righe esportabili** (CSV e scheda stampabile con le firme),
la **scheda della lezione** per il docente dentro il player, il **diario del percorso** della classe,
i **compiti a casa** con correzione sul server, e i comandi che mancavano al player (⏪10s/⏩10s, ‹ › tra lezioni).

Tempo: circa 30 minuti. Si può fare in un colpo solo insieme alle migrazioni 29, 30 e 31 ancora in attesa.

---

## 1. Supabase — una sola esecuzione

SQL Editor → incolla **tutto** `migrazioni/migrazione_completa.sql` → Run.

Il file contiene le migrazioni 19 → 32 ed è **idempotente**: le parti già applicate il 23/09 vengono
semplicemente salutate con un «già esiste, salto». Se preferisci andare per passi, esegui nell'ordine
`migrazione_29_rls_consolidata.sql`, `migrazione_30_abbonamenti.sql`, `migrazione_31_elenco_clienti.sql`,
`migrazione_32_didattica.sql`.

> Se Supabase stampa un errore, **non ha cambiato nulla**: tutto il file viene annullato. Mandami l'errore
> e lo correggo; non riprovare a pezzi, perché così perdi la garanzia dell'ordine.

Alla fine, controllo rapido nello stesso editor:

```sql
select count(*) from edu_esiti;                                  -- 0, la tabella c'è
select count(*) from edu_compiti;                                -- 0
select to_regprocedure('edu_salva_esito(jsonb)') is not null;    -- true
select count(*) from information_schema.role_table_grants
 where grantee='anon' and table_name in ('edu_esiti','edu_compiti');   -- deve dare 0
```

L'ultima query è la più importante: **zero** significa che il player anonimo non può leggere né gli esiti
né i compiti (nei compiti ci sono le risposte giuste). La migrazione stessa fallisce se trova il contrario.

## 2. FTP — i file da caricare in `/project/edu/app/`

| File | Che cos'è |
|---|---|
| `api.php` | v6: azioni `esito`, `diario`, `compito`, `consegna` |
| `index.php` | player v2.4 |
| `compito.php` | **nuovo**: la pagina del compito a casa |
| `scheda.php` | **nuovo**: la scheda alunno da stampare (standard e adattata) |
| `regia-edu.php` | regia v18 |
| `regia-edu.html` | la stessa regia, versione senza PHP (tienile allineate) |
| `stripe.php`, `stripe-webhook.php`, `stripe-setup.php` | se attivi anche la Fase 2 |

**Non sovrascrivere `app/dati/config.php`**: è il file con le chiavi, e sul server deve restare quello che c'è.
Permessi 644 per i file, 755 per le cartelle.

Dopo il caricamento, svuota la cache: cancella i file `app/dati/cache_*.json` dal server (si rigenerano da soli).

## 3. Verifiche in produzione, in quest'ordine

1. `.../project/edu/app/api.php?ver` → deve dire **api.php v6**.
2. Apri un tenant con un codice classe, per esempio `.../project/edu/salina-culcasi/?classe=PROVA-1`:
   nella barra in alto ci sono **⏪ 10s**, **⏩ 10s**, **📋** e **‹ ›**.
3. Avvia una lezione e completa il quiz. Poi in regia → **🧾 Esiti e compiti**: deve comparire una riga
   con classe `PROVA-1`. Se non compare, il problema è nella migrazione, non nel player.
4. Premi **⬇ CSV**: il file si apre in Excel con le colonne giuste (il separatore è il punto e virgola).
5. Premi **🖨️ Scheda**: si apre la finestra di stampa con intestazione e spazio per le firme.
6. In regia → **📚 Corsi**, compila *Didattica del corso* su un corso, e nell'editor di una lezione la
   *Scheda didattica*. Salva, aspetta 5 minuti (cache) e riapri la lezione nel player: il tasto **📋**
   mostra quello che hai scritto.
7. Crea un **compito** (🧾 Esiti e compiti → scegli corso e lezione → ＋ Nuovo compito → ⤓ copia le domande
   dal quiz → Salva), copia il link e aprilo dal telefono. Rispondi: il punteggio appare e in regia arriva
   una riga con modalità «compito a casa».
8. Apri una lezione nel player e premi **🖨️**: si apre la scheda alunno di quella lezione. Stampa in PDF e
   controlla che stia in **2 facciate**. Poi in regia → **🖨️ Scheda da stampare** scegli *adattata*: devono
   uscire **10 pagine**. Se una lezione non ha ancora la scheda compilata, in cima compare l'avviso
   «Questa scheda è incompleta»: è il comportamento voluto, non un errore.

## 4. Il primo giro di lavoro vero (quello che serve a gennaio)

1. **Didattica del corso** di Antichi Mestieri: discipline, traguardi per primaria e medie, monte ore,
   prodotto finale. I testi pronti sono in `docs/didattica/UDA-antichi-mestieri.md`.
2. **Scheda didattica** delle cinque lezioni: prima/durante/dopo e obiettivi. Da
   `docs/didattica/guida-docente.md`.
3. **Prove di ingresso e uscita**: le domande sono in `docs/didattica/prove-ingresso-uscita.md`.
   In piattaforma si registrano come esiti in modalità **ingresso** e **uscita** — oggi si creano come
   compiti con quelle domande, e il pannello esiti calcola da sé il guadagno in punti percentuali.
4. Una classe per volta: assegna il **codice classe** dalla regia (🏫 Scuole e classi) e usa sempre
   quel codice nel link. Senza codice classe gli esiti si registrano come `ANON` e il diario non parte.

## 5. Cosa resta fuori, per onestà

- Gli esiti sono **di classe**: non sapranno mai quale alunno ha risposto cosa. È una scelta, non un limite
  tecnico: è ciò che permette di non trattare dati di minori (vedi `docs/amministrativo/`).
- Il compito a casa richiede che il ragazzo abbia una connessione: la clip 360 pesa.
- Le prove di ingresso/uscita non hanno ancora un'interfaccia dedicata: si fanno con i compiti.
- `debug500.php` e `stripe-setup.php` vanno **cancellati dal server** dopo l'uso.
