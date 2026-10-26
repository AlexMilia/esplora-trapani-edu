-- ============================================================================
-- MIGRAZIONE 31 — elenco minimo dei clienti per il pannello 🎞️ Catalogo
-- ----------------------------------------------------------------------------
-- Perché: con la RLS consolidata (migr. 29) un EDITOR legge solo il PROPRIO
-- cliente (clienti_sel = admin o id = edu_mio_cliente()). È giusto: i dati dei
-- clienti (contatti, note, Stripe) restano riservati. Ma «Chi può usarlo…»
-- deve permettere all'editor proprietario di un corso di concederlo o
-- duplicarlo verso un ALTRO cliente, quindi gli serve almeno id + nome
-- degli altri clienti. Questa RPC restituisce solo quello, solo a editor/admin.
-- Trovata rieseguendo t_flusso_tenant.sql (passo 7) sulla replica pulita.
-- Idempotente. Sicura da rilanciare.
-- ============================================================================
create or replace function edu_elenco_clienti()
returns table(id uuid, slug text, nome text)
language sql stable security definer
set search_path to 'public'
as $$
  select c.id, c.slug, c.nome
  from edu_clienti c
  where edu_sono_editor()            -- editor o admin; docenti e anonimi: nessuna riga
  order by c.nome
$$;
comment on function edu_elenco_clienti() is
  'Catalogo: elenco minimo (id, slug, nome) dei clienti, per concedere/duplicare un corso. Solo editor/admin.';
revoke all on function edu_elenco_clienti() from public;
revoke all on function edu_elenco_clienti() from anon;
grant execute on function edu_elenco_clienti() to authenticated;
