#!/usr/bin/env python3
"""Genera migrazioni/migrazione_36_area_trapani.sql dai dati della camminata di Trapani.

Uso:  python3 strumenti/genera_area_trapani.py /percorso/sito.json
(sito.json = i dati del sito «ver2», non sta in git: serve solo a rigenerare.)

Regole scritte qui dentro, così restano:
  · una lezione per LUOGO: più racconti nello stesso punto = una lezione sola
  · si saltano il racconto 1 (presenta la camminata) e il 15 (ginnastica in piazza)
  · nessun riferimento all'evento in cui i video sono stati girati: dove la voce
    ne parla la clip viene tagliata (inizio_s / fine_s), dove ne parla un testo
    il testo non viene importato
"""
import json, sys, re

BASE = 'https://www.alessandromilia.it/project/attenti-a-quei-due/ver2/'
R = {r['n']: r for r in json.load(open(sys.argv[1]))['R']['rooms']}

# n racconto → (taglio in testa sulla voce, taglio in coda sulla voce, {t fermata: nuovo t}, fermate da scartare)
TAGLI = {
    11: dict(testa=9.5),                               # la voce apre parlando dell'evento
    14: dict(testa=33.0, coda=80.5, sposta={50.9: 66.0}, scarta=[109.8]),
}
# domande in più (oltre a quella del sito), scritte sui testi delle fermate: (domanda, [giusta, sbagliata, sbagliata])
EXTRA = {
 2: (("Che cosa passavano i trapanesi sulla statua di Santa Lucia, il 13 dicembre?", ["Un fazzoletto di cotone", "Un ramo di corallo", "Una candela accesa"]),
     ("Come si chiama davvero la chiesa che tutti chiamano «Santa Lucia»?", ["Chiesa dell’Epifania dei Cappuccini", "Chiesa del Carmine", "Chiesa di Sant’Agostino"])),
 3: (("Com’erano le barche dei pescatori di corallo?", ["Lunghe, strette e nere", "Rotonde e bianche", "Grandi come navi"]),
     ("Che cosa costruirono i corallari con la ricchezza del corallo di Tabarca?", ["Una cappella per la Madonna di Trapani", "Un palazzo per sé", "Un nuovo porto"])),
 4: (("Di che cosa era la dea Demetra?", ["Del grano", "Del mare", "Della guerra"]),
     ("Come si chiamavano le feste di Demetra riservate alle donne?", ["Tesmoforie", "Olimpiadi", "Saturnali"])),
 5: (("Chi rapì Kore, la figlia di Demetra?", ["Ade", "Giove", "Mercurio"]),
     ("Che cosa significa Drepanon, l’antico nome di Trapani?", ["La falce", "Il porto", "La torre"])),
 6: (("Che cosa fece il leone con il cappello in testa?", ["Si accucciò", "Ruggì fortissimo", "Scappò via"]),
     ("Come volle farsi scolpire Alessandro Ferro, tornato a Trapani?", ["Con il leone e il cappello", "A cavallo", "Con una spada in mano"])),
 7: (("In che anno è stata riaperta la chiesa del Collegio?", ["2003", "1950", "1636"]),
     ("Chi ebbe l’idea di riaprire la chiesa anche se il restauro non era finito?", ["La soprintendente di allora", "Il re", "Un pescatore"])),
 8: (("Chi ha scolpito l’Immacolata della chiesa del Collegio?", ["Ignazio Marabitti", "Michelangelo", "Leonardo da Vinci"]),
     ("Sull’altare, quale scena rappresenta il fuoco?", ["Il carro di Elia", "L’arca di Noè", "Il grande grappolo d’uva"])),
 9: (("Che cosa fece capire che dietro il muro c’era qualcosa?", ["Delle crepe", "Un rumore", "Una scritta"]),
     ("Come hanno scoperto che Santa Rosalia è ancora dietro i marmi?", ["Con una piccola telecamera", "Togliendo tutti i marmi", "Leggendo un libro antico"])),
 10: (("Mettendosi al centro della strada, che cosa si vede in fondo?", ["Il mare", "La montagna", "Un castello"]),
      ("Chi sono i due santi accanto alla Madonna sulla facciata?", ["San Giovanni Battista e Sant’Alberto", "San Pietro e San Paolo", "San Francesco e Sant’Antonio"])),
 11: (("Che cosa tirarono i trapanesi a Caruso?", ["Pomodori", "Fiori", "Monete"]),
      ("Qual è la parte più recente del rosone, rifatta dopo la guerra?", ["L’Agnello di Dio al centro", "La stella di Davide", "I trafori"])),
 12: (("Che cosa c’è nello stemma dei Carmelitani?", ["Un monte con tre stelle", "Un leone", "Una nave"]),
      ("Quali erano i due osservatori astronomici della città?", ["Palazzo Riccio di San Gioacchino e il Collegio", "Palazzo Senatorio e la chiesa del Carmine", "Villa Margherita e le Mura di Tramontana"])),
 13: (("Chi era nonna Gina?", ["La nonna del cuntastorie", "Una regina", "Una santa"]),
      ("Dove aveva seguito un uomo, per amore, nonna Gina?", ["In Tunisia", "In Francia", "In America"])),
 14: (("Che cosa c’è sulla pizza Margherita?", ["Pomodoro, mozzarella e basilico", "Tonno e cipolla", "Solo olio e sale"]),
      ("Chi era Margherita di Savoia?", ["La prima regina d’Italia", "Una pittrice trapanese", "Una santa"])),
}
INTRO = {   # dove l'apertura del sito parlava del giro a piedi
 12: "Un’altra storia al femminile, e un po’ di cielo: da qui i trapanesi guardavano le stelle. Poi una chiesa storta, apposta, e la signorina della piazza.",
 13: "Questa è la storia di due donne: una santa che conosci, e la donna più importante della vita di U Cuntastorie.",
 14: "L’ultima donna del nostro viaggio dà il nome a questo giardino… e a una pizza.",
}
# slug, titolo, sottotitolo, emoji, colore, nome del luogo, racconti
LEZIONI = [
 ('trapani-cappuccini', 'Tutto al femminile', 'La finta Santa Lucia e le due braccia incrociate dei francescani', '🕯️', 'rosa', 'Chiesa dei Cappuccini', [2]),
 ('trapani-santa-lucia', 'La santa dei corallari', 'I pescatori di corallo e l’affresco ritrovato', '🪸', 'oro', 'Ex chiesa di Santa Lucia', [3]),
 ('trapani-tramontana', 'La montagna è femmina', 'Erice, la montagna di Venere, e i riti delle donne per Demetra', '⛰️', 'blu', 'Mura di Tramontana', [4]),
 ('trapani-falce', 'La falce di Demetra', 'Il mito che spiega la forma di Trapani e le stagioni', '🌙', 'verde', 'Mura di Tramontana, verso la città', [5]),
 ('trapani-leone', 'L’uomo col leone', 'La leggenda di Alessandro Ferro, scolpita sopra le nostre teste', '🦁', 'rosa', 'Palazzo Ferro', [6]),
 ('trapani-collegio', 'Chiesa del Collegio', 'Tre racconti: la chiesa che rinasce · acqua, terra, aria e fuoco · le sante nel muro', '⛪', 'oro', 'Chiesa del Collegio dei Gesuiti', [7, 8, 9]),
 ('trapani-senatorio', 'L’asse sacro e profano', 'La Madonna con le chiavi della città e il trucco degli architetti', '🗝️', 'blu', 'Palazzo Senatorio', [10]),
 ('trapani-rosone', 'Il rosone dei tre popoli', 'Caruso e i pomodori, poi tre religioni in un rosone', '💠', 'verde', 'Chiesa di Sant’Agostino', [11]),
 ('trapani-carmine', 'Le stelle e la Venere', 'Gli osservatori delle stelle e la chiesa storta apposta', '🔭', 'rosa', 'Chiesa del Carmine', [12]),
 ('trapani-santa-rita', 'La santa degli impossibili', 'Nonna Gina e la forza delle donne siciliane', '🌹', 'oro', 'Via Garibaldi', [13]),
 ('trapani-margherita', 'Margherita, l’ultima donna', 'La regina che dà il nome a un giardino… e a una pizza', '👑', 'blu', 'Villa Margherita', [14]),
]
TIT_CLIP = {7: 'La chiesa che rinasce', 8: 'Acqua, terra, aria e fuoco', 9: 'Le sante nel muro'}
VIETATE = re.compile(r'pink|ciccio|pilates|gambicchia|tumor|\bseno\b|camminat|attenti a quei|18 ottobre|prufissure|no gravity', re.I)

def q(s):
    return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"
def num(x):
    return ('%.2f' % x).rstrip('0').rstrip('.')
def titolo_caso(t3):
    s = ' '.join(t3).lower(); return s[0].upper() + s[1:]

out, visti = [], []
def testo(s):
    if VIETATE.search(s or ''): raise SystemExit('testo con riferimento all’evento: ' + s)
    visti.append(s); return q(s)

out.append('''-- ============================================================
-- MIGRAZIONE 36 · area «Trapani, la città a forma di falce»
-- Esplora Edu · novembre 2026
--
-- FILE GENERATO da strumenti/genera_area_trapani.py: non modificarlo a mano.
--
-- Che cosa crea
--   · un corso a catalogo del tenant vetrina «esplora-trapani», pubblicato,
--     con licenza anche per l'IC Pagoto (stessa scadenza di Antichi Mestieri),
--     terzo dopo Antichi Mestieri (10) e Il viaggio di una goccia (20)
--   · 11 lezioni, una per luogo, con 13 racconti a 360° di U Cuntastorie
--   · per ogni racconto: taglio del video, voce a parte, sottotitoli, fermate
--     con il punto «?» già validato, domande junior e senior
--   · didattica.mappa = true sul corso e didattica.luogo su ogni lezione:
--     il player apre il corso con la mappa
--
-- Richiede la migrazione 35 (tagli della clip). Va applicata DOPO aver messo
-- online il player v2.9: quello vecchio ignorerebbe tagli e voce.
--
-- Ripetibile e prudente: se il corso c'è già NON tocca nulla, nemmeno una
-- virgola. Quello che viene corretto dalla regia dopo l'importazione resta.
-- ============================================================
do $trapani$
declare
  v_cli uuid; v_corso uuid; v_lez uuid; v_med uuid; v_tap uuid;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'edu_media' and column_name = 'inizio_s') then
    raise exception 'migr. 36: manca la migrazione 35 (tagli della clip). Applicala prima.';
  end if;
  select id into v_cli from edu_clienti where slug = 'esplora-trapani';
  if v_cli is null then raise exception 'migr. 36: non trovo il cliente «esplora-trapani»'; end if;
  if exists (select 1 from edu_corsi where proprietario_id = v_cli and slug = 'trapani-citta') then
    raise notice 'migr. 36: il corso «trapani-citta» esiste già: non tocco nulla.';
    return;
  end if;
''')
prologo = ("Ciao! Io sono Trapani, la città a forma di falce. Sono piena di storie: basta alzare gli occhi. "
           "Te le racconta U Cuntastorie, che queste chiese e questi palazzi li conosce pietra per pietra. "
           "Scegli un punto sulla mappa e partiamo!")
out.append(f'''  insert into edu_corsi (proprietario_id, slug, titolo, sottotitolo, descrizione, emoji, colore, fascia, prologo,
                         stato, ordine, visibilita, mascotte, didattica)
  values (v_cli, 'trapani-citta', {testo('Trapani, la città a forma di falce')},
          {testo('Chiese, palazzi, miti e leggende del centro storico: undici luoghi sulla mappa, raccontati a 360° da U Cuntastorie')},
          {testo('Un giro nel centro storico di Trapani in undici luoghi. In ogni luogo un racconto a 360°: ci si guarda intorno, si cerca il punto che brilla e si risponde alle domande.')},
          '⚓', 'blu', 'entrambe', {testo(prologo)},
          'pubblicato', 25, 'catalogo',
          '{{"img":"https://www.alessandromilia.it/project/esplora/mascotte.png","nome":"Trapani","video":{{"junior":{{}},"senior":{{}},"entrambi":{{}}}},"junior":true,"senior":true,"quiz_sempre":true}}'::jsonb,
          '{{"mappa":true}}'::jsonb)
  returning id into v_corso;
  -- Chi lo vede. All'inizio SOLO la scuola di prova: vetrina e IC Pagoto ricevono la riga
  -- ma sospesa, e la accende la migrazione 37 quando il player v2.9 è nella cartella
  -- che usano le scuole (quello vecchio mostrerebbe i video senza tagli).
  insert into edu_clienti (slug, nome, brand, piano, licenza_stato, licenza_inizio, note)
  select 'prova-trapani', 'Prova · area Trapani',
         '{{"titolo":"Trapani, la città a forma di falce","sottotitolo":"Scuola di prova","emoji":"⚓","colore":"blu","claim":"Scegli un punto sulla mappa: entrerai nel luogo in 360°.<br>Trascina lo schermo per guardarti intorno e tocca i punti che brillano!"}}'::jsonb,
         'base', 'attiva', current_date, 'Scuola di prova per guardare l''area Trapani prima di accenderla alle scuole (migr. 36). Si può cancellare dopo.'
  where not exists (select 1 from edu_clienti where slug = 'prova-trapani');
  insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
  select v_corso, id, 'attivo', current_date, 'Scuola di prova (migr. 36)' from edu_clienti where slug = 'prova-trapani'
  on conflict (corso_id, cliente_id) do nothing;
  insert into edu_catalogo (corso_id, cliente_id, stato, da, note)
  values (v_corso, v_cli, 'sospeso', current_date, 'Corso proprio (migr. 36): si accende con la migr. 37')
  on conflict (corso_id, cliente_id) do nothing;
''')

tot_racconti = 0
for i, (slug, tit, sub, em, col, luogo, racconti) in enumerate(LEZIONI):
    r0 = R[racconti[0]]
    clip = []
    for n in racconti:
        r, tg = R[n], TAGLI.get(n, {})
        da = r['vstart'] + tg.get('testa', 0)
        a = r['vstart'] + tg['coda'] if 'coda' in tg else r['vend']
        clip.append((n, r, tg, da, a))
    sec = sum(a - da for _, _, _, da, a in clip)
    durata = '~%d min' % max(1, round(sec / 60))
    intro = INTRO.get(racconti[0], r0['intro'])
    if len(racconti) > 1:
        intro += ' Tre racconti, uno dopo l’altro: guardati intorno e, quando appare un “?”, toccalo.'
    luogo_j = json.dumps({'nome': luogo, 'lat': r0['geo'][0], 'lng': r0['geo'][1]}, ensure_ascii=False)
    testo(luogo)
    out.append(f'''
  -- ---------- {i+1}. {tit} · {luogo} ----------
  insert into edu_lezioni (progetto, slug, titolo, sottotitolo, emoji, colore, durata_label, intro, ordine, stato,
                           owner, corso_id, accessibilita, didattica)
  values ('antichi-mestieri-trapani', {q(slug)}, {testo(tit)}, {testo(sub)}, {q(em)}, {q(col)}, {q(durata)},
          {testo(intro)}, {(i+1)*10}, 'pubblicata', null, v_corso,
          '{{"lis":false,"note":"","ipovedenti":true}}'::jsonb,
          jsonb_build_object('luogo', {q(luogo_j)}::jsonb))
  returning id into v_lez;''')
    nq = {'junior': 0, 'senior': 0}
    for k, (n, r, tg, da, a) in enumerate(clip):
        tot_racconti += 1
        assert r['narr'] and r['cc'] and da < a
        titc = TIT_CLIP.get(n, titolo_caso(r['t3']))
        out.append(f'''
  insert into edu_media (lezione_id, ordine, tipo, guid, titolo, inizio_s, fine_s, sync_s, vol_video,
                         audio_url, audio_vol, audio_loop, audio_duck, cc_url)
  values (v_lez, {k+1}, 'video360', {q(r['bunny360'])}, {testo(titc)}, {num(da)}, {num(a)}, {num(r['vstart'])}, {round(r.get('ambiente', .22)*100)},
          {q(BASE + r['narr'])}, 100, false, false, {q(BASE + r['cc'])})
  returning id into v_med;''')
        j = 0
        for t in r['tappe']:
            if t['t'] in tg.get('scarta', []): continue
            tt = tg.get('sposta', {}).get(t['t'], t['t'])
            assert da < tt < a, (n, tt, da, a)
            j += 1
            out.append(f'''  insert into edu_tappe (lezione_id, media_id, t, cocciu, ordine)
  values (v_lez, v_med, {num(tt)}, {testo(t['narr'])}, {j}) returning id into v_tap;
  insert into edu_hotspot (tappa_id, yaw, pitch, em, tit, txt, txt2, validazione, validatore, validato_il, ordine)
  values (v_tap, {t['yaw']}, {t['pitch']}, {q(t['em'])}, {testo(t['tit'])},
          {testo(t['txt'])},
          {testo(t['txt2'])},
          'validato', 'Esplora Trapani', now(), 1);''')
        assert j >= 1
        for li, lv in enumerate(('junior', 'senior')):
            dom = [(x['d'], [x['o'][x['ok']]] + [o for z, o in enumerate(x['o']) if z != x['ok']]) for x in r['quiz'][lv]]
            dom.append(EXTRA[n][li])
            for d, opz in dom:
                assert len(opz) == 3
                nq[lv] += 1
                pos = (n + nq[lv] + li) % 3          # la risposta giusta non sta sempre al primo posto
                o = opz[1:]; o.insert(pos, opz[0])
                out.append(f'''  insert into edu_quiz (lezione_id, livello, domanda, opzioni, ok, ordine)
  values (v_lez, {q(lv)}, {testo(d)}, {q(json.dumps([*o], ensure_ascii=False))}::jsonb, {pos}, {nq[lv]});''')
                for x in o: testo(x)
out.append('''
  raise notice 'migr. 36: creata l''area Trapani (% lezioni)', (select count(*) from edu_lezioni where corso_id = v_corso);
end $trapani$;

-- Licenza anche all'IC Pagoto (deciso il 10/11/2026), con la stessa scadenza della
-- sua licenza di Antichi Mestieri. Sta fuori dal blocco sopra perché deve valere
-- anche se il corso c'era già; se la riga esiste non viene toccata. Nasce SOSPESA:
-- la accende la migrazione 37.
insert into edu_catalogo (corso_id, cliente_id, stato, da, a, note)
select co.id, k.id, 'sospeso', current_date,
       (select c2.a from edu_catalogo c2 join edu_corsi am on am.id = c2.corso_id
         where c2.cliente_id = k.id and am.slug = 'antichi-mestieri' and am.proprietario_id = co.proprietario_id limit 1),
       'Area Trapani (migr. 36): si accende con la migr. 37'
from edu_corsi co
join edu_clienti v on v.id = co.proprietario_id and v.slug = 'esplora-trapani'
join edu_clienti k on k.slug = 'ic-pagoto'
where co.slug = 'trapani-citta'
on conflict (corso_id, cliente_id) do nothing;
''')
assert tot_racconti == 13 and len(LEZIONI) == 11
open('migrazioni/migrazione_36_area_trapani.sql', 'w').write('\n'.join(out))
print('scritto: 11 lezioni, 13 racconti,', len(visti), 'testi controllati')
