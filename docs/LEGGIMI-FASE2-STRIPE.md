# ESPLORA TRAPANI EDU — FASE 2 · ABBONAMENTI STRIPE
(24/09/2026 · migrazione 30 · stripe.php v1.0 · stripe-webhook.php v1.0 · regia v17)

## Come funziona, in una riga
Il manager sceglie piano e periodo nel cliente e preme **Invia link di pagamento**:
Stripe manda l'email con la pagina di pagamento al referente; quando paga, il
webhook attiva la licenza fino a fine periodo. I rinnovi arrivano da soli. Pausa e
annullamento dalla regia agiscono sull'abbonamento Stripe e sulla licenza.

| Stato abbonamento | Cosa vede la classe | Cosa fa Stripe |
|---|---|---|
| in attesa | licenza com'era (nessun cambio) | ha inviato la fattura, aspetta il pagamento (7 gg) |
| attivo | licenza **attiva** fino a fine periodo | addebita a ogni rinnovo (nuova email) |
| in pausa | licenza **sospesa** | nessun addebito |
| insoluto | licenza resta com'è fino a scadenza | ritenta / sollecita secondo le impostazioni |
| annullato a fine periodo | attiva fino alla scadenza, poi scaduta | nessun rinnovo |
| annullato subito | licenza **scaduta** oggi | abbonamento cancellato |

Prezzi (IVA inclusa): Base 50 · Pro 100 · Premium 200 € al **mese**; annuale di
serie = 10 mensilità (2 mesi gratis: 500 / 1.000 / 2.000 €). Si cambia in
`stripe-setup.php` (array `$PIANI`) prima di eseguirlo.

## Attivazione (in modalità TEST prima, poi LIVE)
1. **Supabase**: SQL Editor → `migrazione_30_abbonamenti.sql` → Run.
2. **Stripe** (dashboard.stripe.com, interruttore «Test mode» acceso):
   Developers → API keys → copia la **Secret key** (`sk_test_…`).
3. **Aruba**: carica in `/project/edu/app/` i file `stripe.php`,
   `stripe-webhook.php`, `stripe-setup.php`, `regia-edu.php`, `regia-edu.html`
   (v17) e aggiungi in `dati/config.php` le righe della sezione STRIPE
   (nel `config.php` dello zip sono già pronte, vuote): `STRIPE_SECRET`,
   `SUPA_SERVICE` (Supabase → Settings → API → **service_role**).
4. **Prezzi**: apri `https://www.alessandromilia.it/project/edu/app/stripe-setup.php?k=LA_CHIAVE_DIAG`
   → crea 3 prodotti e 6 prezzi e stampa `$STRIPE_PRICES = […]` → incollalo nel
   config. Poi **cancella `stripe-setup.php`** dal server.
5. **Webhook**: Developers → Webhooks → Add endpoint →
   `https://www.alessandromilia.it/project/edu/app/stripe-webhook.php` → eventi:
   `invoice.paid`, `invoice.payment_failed`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`,
   `customer.subscription.paused`, `customer.subscription.resumed` → copia il
   **Signing secret** (`whsec_…`) in `STRIPE_WEBHOOK_SECRET`.
6. **Email**: Settings → Billing → Emails → attiva **«Email finalized invoices to
   customers»** (è l'email col link) e, consigliato, i solleciti per fatture scadute.
   Settings → Branding: logo e colori Esplora Trapani.
7. **Prova**: regia → un cliente di prova con la TUA email come referente → Invia
   link → arriva l'email → paghi con la carta di test `4242 4242 4242 4242` →
   il cliente passa ad **Attivo** (Aggiorna da Stripe se non vedi subito) → Pausa →
   Riprendi → Annulla FINE / SUBITO.
8. **Live**: ripeti 2, 4, 5 con «Test mode» spento (chiavi `sk_live_`, nuovi
   price_… e nuovo `whsec_`), aggiorna il config. Le fatture emesse in test
   spariscono da sole.

## Sicurezza
- `stripe.php` accetta solo chiamate con il token Supabase di un **admin**
  (verificato lato server con `edu_e_admin`); le scritture su edu_clienti usano
  la chiave **service**, che vive solo in `dati/config.php` (negata dal web).
- `stripe-webhook.php` verifica la **firma HMAC** di ogni evento (tolleranza 5
  minuti), ignora gli eventi non pertinenti, risponde 500 se il cliente non è
  ancora agganciato (Stripe ritenta) e il DB scarta i duplicati (idempotente).
- La RPC `edu_abbonamento_evento` è eseguibile **solo dal service role**.
- `edu_pagamenti` leggibile dall'admin (e dal cliente per i propri).

## Test eseguiti (finto Stripe + finto Supabase, ogni chiamata registrata)
28 verifiche: 401/403 senza token o non admin e nessuna chiamata a Stripe;
crea (customer con email+metadata e idempotency key, subscription con prezzo
giusto / send_invoice / 7 giorni / metadata, fattura finalizzata e inviata, DB
in_attesa con link e id, scritture solo con chiave service, doppio abbonamento e
piano inesistente rifiutati); pausa/riprendi (pause_collection, licenza
sospesa/attiva); annulla a fine periodo e subito (DELETE, licenza scaduta oggi);
stato; webhook (firma ok/sbagliata/replay/assente, campi estratti, pausa,
evento estraneo ignorato, cliente non agganciato → 500); setup (3 prodotti,
6 prezzi inclusive month/year, 403 senza chiave). Regia: 12 verifiche
sull'interfaccia. DB: ciclo di vita completo degli eventi su replica.
