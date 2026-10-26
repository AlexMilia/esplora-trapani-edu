-- FIXTURE DEI TEST SQL — dati che t_rls_matrice.sql, t_flusso_tenant.sql e t_abbonamenti.sql danno per scontati.
-- Va applicata DOPO migrazione_completa.sql e SOLO sulla replica locale (db_avvia.sh lo fa da sé). Mai in produzione.
-- La replica (replica.sql) rispecchia la produzione: lì l'utente 2222… è un admin ("Demo"); i test invece
-- lo usano come EDITOR della Salina Culcasi, e vogliono un secondo cliente licenziatario (ic-pagoto) con il suo editor.
\set ON_ERROR_STOP on
begin;

-- account Auth corrispondenti (nella replica auth.users è una tabella finta)
insert into auth.users(id,email) values
  ('22222222-2222-2222-2222-222222222222','editor.salina@test.it'),
  ('33333333-3333-3333-3333-333333333333','docente.salina@test.it'),
  ('44444444-4444-4444-4444-444444444444','editor.pagoto@test.it'),
  ('99999999-9999-9999-9999-999999999999','da.promuovere@test.it')
on conflict do nothing;

-- cliente licenziatario di prova
insert into edu_clienti(slug,nome,brand,piano,licenza_inizio)
values ('ic-pagoto','IC Pagoto','{"titolo":"IC Pagoto"}','pro',current_date)
on conflict (slug) do nothing;

-- ruoli: 2222 editor Salina · 3333 docente Salina · 4444 editor ic-pagoto · 9999 docente senza cliente (lo promuove l'admin)
update edu_utenti set ruolo='editor',  cliente_id=(select id from edu_clienti where slug='salina-culcasi') where id='22222222-2222-2222-2222-222222222222';
update edu_utenti set ruolo='docente', cliente_id=(select id from edu_clienti where slug='salina-culcasi') where id='33333333-3333-3333-3333-333333333333';
insert into edu_utenti(id,ruolo,nome,cliente_id) values
  ('44444444-4444-4444-4444-444444444444','editor','Editor Pagoto',(select id from edu_clienti where slug='ic-pagoto')),
  ('99999999-9999-9999-9999-999999999999','docente','Da promuovere',null)
on conflict (id) do update set ruolo=excluded.ruolo, nome=excluded.nome, cliente_id=excluded.cliente_id;

-- un corso proprio di ic-pagoto con una lezione (serve a verificare che l'editor della Salina NON possa toccarla)
insert into edu_corsi(proprietario_id,slug,titolo,fascia,stato,ordine,visibilita)
values ((select id from edu_clienti where slug='ic-pagoto'),'storia-di-pagoto','Storia di Pagoto','entrambe','pubblicato',1,'privato')
on conflict (proprietario_id,slug) do nothing;
insert into edu_lezioni(progetto,slug,titolo,stato,corso_id)
select null,'pagoto-1','La piazza di Pagoto','pubblicata',id from edu_corsi where slug='storia-di-pagoto'
  and not exists (select 1 from edu_lezioni where slug='pagoto-1');

-- una classe della Salina assegnata a un altro docente (il docente 3333 non deve poterla cancellare)
insert into edu_classi(codice,istituto,cliente_id,nome,anno,docente_id,scuola_id)
select 'TP-IC12-5A','IC 12',c.id,'5ª A','2026/27','22222222-2222-2222-2222-222222222222',
       (select id from edu_scuole where cliente_id=c.id order by creato_il limit 1)
from edu_clienti c where c.slug='salina-culcasi'
on conflict (codice) do nothing;

commit;
\echo 'fixture di test applicata'
