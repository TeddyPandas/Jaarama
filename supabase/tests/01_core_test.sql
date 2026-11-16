-- =============================================================================
-- Tests du cœur métier : droits, plafonds, idempotence, QR, échanges, RLS.
-- Exécution : scripts/test-db.sh
-- Chaque étape échoue bruyamment (ON_ERROR_STOP) à la première régression.
-- =============================================================================

\set ON_ERROR_STOP on
\set QUIET on

-- -----------------------------------------------------------------------------
-- Outils de test
-- -----------------------------------------------------------------------------

create schema test;
grant usage on schema test to authenticated, anon;

create function test.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), false);
$$;

create function test.assert_raises(p_sql text, p_expected text) returns void
language plpgsql as $$
declare
  v_msg text;
begin
  begin
    execute p_sql;
  exception when others then
    v_msg := sqlerrm;
  end;
  if v_msg is null then
    raise exception 'ÉCHEC : « % » aurait dû échouer avec « % »', p_sql, p_expected;
  end if;
  if v_msg not like p_expected then
    raise exception 'ÉCHEC : « % » a échoué avec « % » au lieu de « % »', p_sql, v_msg, p_expected;
  end if;
end;
$$;

create function test.assert_eq(p_actual text, p_expected text, p_label text) returns void
language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'ÉCHEC % : obtenu « % », attendu « % »', p_label, p_actual, p_expected;
  end if;
end;
$$;

-- Fabrique le QR qu'afficherait l'application client à l'instant p_at.
create function test.qr(p_customer uuid, p_at timestamptz) returns text
language sql security definer set search_path = '' as $$
  select 'JRM1.' || c.id || '.' || s.step || '.' || private.qr_signature(c.qr_secret, c.id, s.step)
  from public.customers c,
       lateral (select floor(extract(epoch from p_at) / 30)::bigint as step) s
  where c.id = p_customer;
$$;

create function test.customer_of(p_user uuid) returns uuid
language sql security definer set search_path = '' as $$
  select id from public.customers where user_id = p_user;
$$;

grant execute on all functions in schema test to authenticated, anon;

-- -----------------------------------------------------------------------------
-- Données de départ
--   Restaurant A : propriétaire, caissier, récompense à 2 points
--   Restaurant B : un caissier
--   Clients : c1 (installera l'application), c2 (connecté, sans rôle)
-- -----------------------------------------------------------------------------

insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-00000000a001', '221770000001'),
  ('00000000-0000-0000-0000-00000000a002', '221770000002'),
  ('00000000-0000-0000-0000-00000000b002', '221770000003'),
  ('00000000-0000-0000-0000-00000000c001', '221770000101'),
  ('00000000-0000-0000-0000-00000000c002', '221770000102');

insert into public.restaurants (id, name) values
  ('00000000-0000-0000-0000-0000000000a0', 'Restaurant A'),
  ('00000000-0000-0000-0000-0000000000b0', 'Restaurant B');

insert into public.staff (restaurant_id, user_id, role) values
  ('00000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-00000000a001', 'owner'),
  ('00000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-00000000a002', 'cashier'),
  ('00000000-0000-0000-0000-0000000000b0', '00000000-0000-0000-0000-00000000b002', 'cashier');

insert into public.rewards (id, restaurant_id, name, cost_points) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a0', 'Café offert', 2);

\echo '1. Normalisation des numéros'
do $$ begin
  perform test.assert_eq(public.normalize_phone_sn('77 123 45 67'), '+221771234567', 'format local');
  perform test.assert_eq(public.normalize_phone_sn('+221 77-123-45-67'), '+221771234567', 'format international');
  perform test.assert_eq(public.normalize_phone_sn('00221771234567'), '+221771234567', 'préfixe 00');
  perform test.assert_raises($q$ select public.normalize_phone_sn('33 820 00 00') $q$, 'invalid_phone');
  perform test.assert_raises($q$ select public.normalize_phone_sn('7712') $q$, 'invalid_phone');
end $$;

set role authenticated;

\echo '2. Inscription au comptoir par numéro'
do $$
declare r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a002');
  r := public.register_customer('00000000-0000-0000-0000-0000000000a0', '77 000 01 03', 'Awa');
  perform test.assert_eq(r->>'is_new_customer', 'true', 'nouveau client');
  perform test.assert_eq(r->>'balance', '0', 'solde initial');
  r := public.register_customer('00000000-0000-0000-0000-0000000000a0', '770000103', 'Autre prénom');
  perform test.assert_eq(r->>'is_new_customer', 'false', 'client existant');
  perform test.assert_eq(r->>'first_name', 'Awa', 'prénom non écrasé');
end $$;

\echo '3. Crédit par numéro, renvoi idempotent, plafond journalier'
do $$
declare r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a002');
  r := public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000001', now(), p_phone => '770000103');
  perform test.assert_eq(r->>'balance', '1', 'solde après crédit');
  perform test.assert_eq(r->>'already_recorded', 'false', 'premier envoi');

  r := public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000001', now(), p_phone => '770000103');
  perform test.assert_eq(r->>'already_recorded', 'true', 'renvoi reconnu');
  perform test.assert_eq(r->>'balance', '1', 'pas de double crédit');

  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000002', now(), p_phone => '770000103') $q$, 'daily_limit_reached');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000003', now(), p_phone => '770000999') $q$, 'customer_not_found');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000004', now()) $q$, 'exactly_one_identifier');
end $$;

\echo '4. Droits : autre restaurant, simple client, anonyme'
do $$ begin
  perform test.login('00000000-0000-0000-0000-00000000b002');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000005', now(), p_phone => '770000103') $q$, 'forbidden');
  perform test.assert_raises($q$ select public.register_customer('00000000-0000-0000-0000-0000000000a0',
         '770000104') $q$, 'forbidden');

  perform test.login('00000000-0000-0000-0000-00000000c002');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000006', now(), p_phone => '770000103') $q$, 'forbidden');
end $$;

set role anon;
do $$ begin
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '10000000-0000-0000-0000-000000000007', now(), p_phone => '770000103') $q$, 'permission denied%');
end $$;
set role authenticated;

\echo '5. Installation de l''application : rattachement et secret du QR'
do $$
declare r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000c001');
  r := public.claim_customer_profile('Moussa');
  perform test.assert_eq(length(r->>'qr_secret')::text, '64', 'secret de 32 octets');
  perform test.assert_eq((select first_name from public.customers), 'Moussa', 'fiche visible par son titulaire');
  perform test.assert_raises($q$ select qr_secret from public.customers $q$, 'permission denied%');
end $$;

reset role;
update public.restaurants set max_visits_per_day = 5 where id = '00000000-0000-0000-0000-0000000000a0';
set role authenticated;

\echo '6. Crédit par QR : création de carte, réutilisation, expiration, falsification'
do $$
declare
  v_cust  uuid := test.customer_of('00000000-0000-0000-0000-00000000c001');
  v_token text := test.qr(v_cust, now());
  r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a002');
  r := public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '20000000-0000-0000-0000-000000000001', now(), p_qr_token => v_token);
  perform test.assert_eq(r->>'balance', '1', 'carte créée au premier scan');
  perform test.assert_eq(r->>'first_name', 'Moussa', 'prénom affiché au caissier');

  perform test.assert_raises(format($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '20000000-0000-0000-0000-000000000002', now(), p_qr_token => %L) $q$, v_token), 'qr_already_used');
  perform test.assert_raises(format($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '20000000-0000-0000-0000-000000000003', now(), p_qr_token => %L) $q$,
         test.qr(v_cust, now() - interval '10 minutes')), 'qr_expired');
  perform test.assert_raises(format($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '20000000-0000-0000-0000-000000000004', now(), p_qr_token => %L) $q$,
         left(v_token, -1) || case right(v_token, 1) when '0' then '1' else '0' end), 'invalid_qr');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '20000000-0000-0000-0000-000000000005', now(), p_qr_token => 'JRM1.pas-un-uuid.1.x') $q$, 'invalid_qr');
end $$;

\echo '7. Hors ligne : crédit synchronisé tard, limite d''ancienneté, date future'
do $$
declare
  v_cust uuid := test.customer_of('00000000-0000-0000-0000-00000000c001');
  v_past timestamptz := now() - interval '20 hours';
  v_old  timestamptz := now() - interval '30 hours';
  r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a002');
  r := public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '30000000-0000-0000-0000-000000000001', v_past, p_qr_token => test.qr(v_cust, v_past));
  perform test.assert_eq(r->>'balance', '2', 'crédit hors ligne accepté');

  perform test.assert_raises(format($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '30000000-0000-0000-0000-000000000002', %L, p_qr_token => %L) $q$, v_old, test.qr(v_cust, v_old)),
         'occurred_at_out_of_range');
  perform test.assert_raises(format($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '30000000-0000-0000-0000-000000000003', %L, p_phone => '770000101') $q$, now() + interval '1 hour'),
         'occurred_at_out_of_range');
end $$;

\echo '8. Échange de récompense : idempotence et solde insuffisant'
do $$
declare
  v_cust uuid := test.customer_of('00000000-0000-0000-0000-00000000c001');
  r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a002');
  r := public.redeem_reward('00000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-0000000000f1',
         '40000000-0000-0000-0000-000000000001', p_qr_token => test.qr(v_cust, now()));
  perform test.assert_eq(r->>'balance', '0', 'solde après échange');
  r := public.redeem_reward('00000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-0000000000f1',
         '40000000-0000-0000-0000-000000000001', p_qr_token => test.qr(v_cust, now()));
  perform test.assert_eq(r->>'already_recorded', 'true', 'échange rejoué sans débit');
  perform test.assert_raises(format($q$ select public.redeem_reward('00000000-0000-0000-0000-0000000000a0',
         '00000000-0000-0000-0000-0000000000f1', '40000000-0000-0000-0000-000000000002', p_qr_token => %L) $q$,
         test.qr(v_cust, now())), 'insufficient_points');
  perform test.assert_raises($q$ select public.redeem_reward('00000000-0000-0000-0000-0000000000b0',
         '00000000-0000-0000-0000-0000000000f1', '40000000-0000-0000-0000-000000000003', p_phone => '770000101') $q$,
         'forbidden');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '40000000-0000-0000-0000-000000000001', now(), p_phone => '770000101') $q$, 'client_op_id_conflict');
end $$;

\echo '9. Cloisonnement des lectures'
do $$ begin
  perform test.login('00000000-0000-0000-0000-00000000c001');
  perform test.assert_eq((select count(*) from public.cards)::text, '1', 'le client ne voit que sa carte');
  perform test.assert_eq((select count(*) from public.point_entries)::text, '3', 'son historique');
  perform test.assert_eq((select balance from public.card_balances)::text, '0', 'son solde');

  perform test.login('00000000-0000-0000-0000-00000000b002');
  perform test.assert_eq((select count(*) from public.cards)::text, '0', 'caissier B ne voit rien de A');
  perform test.assert_eq((select count(*) from public.point_entries)::text, '0', 'ni son registre');

  perform test.login('00000000-0000-0000-0000-00000000a002');
  perform test.assert_eq((select count(*) from public.cards)::text, '2', 'caissier A voit ses cartes');
  perform test.assert_eq((select count(*) from public.restaurant_customers('00000000-0000-0000-0000-0000000000a0'))::text,
         '0', 'liste clients réservée au gérant');

  perform test.login('00000000-0000-0000-0000-00000000a001');
  perform test.assert_eq((select string_agg(phone_masked, ',' order by phone_masked)
                          from public.restaurant_customers('00000000-0000-0000-0000-0000000000a0')),
         '+22177 *** ** 01,+22177 *** ** 03', 'numéros masqués');
end $$;

\echo '10. Registre en ajout seul'
do $$ begin
  perform test.assert_raises($q$ insert into public.point_entries (card_id, delta, kind, client_op_id, occurred_at)
         select id, 100, 'adjustment', gen_random_uuid(), now() from public.cards limit 1 $q$, 'permission denied%');
  perform test.login('00000000-0000-0000-0000-00000000a002');
  update public.rewards set cost_points = 1;
  perform test.assert_eq((select cost_points from public.rewards)::text, '2', 'le caissier ne modifie pas les récompenses');
end $$;
reset role;
do $$ begin
  perform test.assert_raises($q$ update public.point_entries set delta = 50 $q$, 'point_entries_append_only');
  perform test.assert_raises($q$ delete from public.point_entries $q$, 'point_entries_append_only');
end $$;
set role authenticated;

\echo '11. Gestion de l''équipe'
do $$
declare r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000a001');
  r := public.add_staff_member('00000000-0000-0000-0000-0000000000a0', '77 000 01 02', 'cashier');
  perform test.assert_eq(r->>'role', 'cashier', 'caissier ajouté');
  perform test.assert_raises($q$ select public.add_staff_member('00000000-0000-0000-0000-0000000000a0',
         '770000102', 'owner') $q$, 'owner_assigned_by_platform');
  perform test.assert_raises($q$ select public.add_staff_member('00000000-0000-0000-0000-0000000000a0',
         '770000999', 'cashier') $q$, 'user_not_found');
end $$;
do $$ begin
  perform test.login('00000000-0000-0000-0000-00000000a001');
  perform public.set_staff_active('00000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-00000000c002', false);
  perform test.login('00000000-0000-0000-0000-00000000c002');
  perform test.assert_raises($q$ select public.credit_visit('00000000-0000-0000-0000-0000000000a0',
         '50000000-0000-0000-0000-000000000001', now(), p_phone => '770000103') $q$, 'forbidden');
  perform test.login('00000000-0000-0000-0000-00000000a002');
  perform test.assert_raises($q$ select public.add_staff_member('00000000-0000-0000-0000-0000000000a0',
         '770000102', 'cashier') $q$, 'forbidden');
end $$;

\echo '12. Client inscrit au comptoir qui installe ensuite l''application'
reset role;
insert into auth.users (id, phone) values ('00000000-0000-0000-0000-00000000c003', '221770000103');
set role authenticated;
do $$
declare r jsonb;
begin
  perform test.login('00000000-0000-0000-0000-00000000c003');
  r := public.claim_customer_profile();
  perform test.assert_eq(r->>'first_name', 'Awa', 'fiche du comptoir reprise');
  perform test.assert_eq((select balance from public.card_balances)::text, '1', 'points conservés');
end $$;

\echo '13. Effacement des données client'
do $$ begin
  perform test.login('00000000-0000-0000-0000-00000000c001');
  perform public.delete_my_customer_data();
  perform test.assert_eq((select count(*) from public.customers)::text, '0', 'fiche effacée');
end $$;
reset role;
do $$ begin
  perform test.assert_eq((select count(*) from public.cards c join public.customers cu on cu.id = c.customer_id
                          where cu.phone = '+221770000101')::text, '0', 'cartes effacées');
  perform test.assert_eq((select count(*) from public.point_entries)::text, '1', 'seul le registre d''Awa reste');
  perform test.assert_raises($q$ delete from public.point_entries $q$, 'point_entries_append_only');
end $$;

\echo 'Tous les tests sont passés.'
