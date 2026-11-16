-- =============================================================================
-- Jaarama — schéma initial
--
-- Principes :
--   * Le solde d'une carte n'est jamais stocké : c'est la somme du registre
--     `point_entries`, qui est en ajout seul.
--   * Aucune écriture métier directe depuis les applications : les crédits,
--     échanges et inscriptions passent par des fonctions qui vérifient les
--     droits, les plafonds et l'idempotence.
--   * Chaque table est cloisonnée par restaurant via la sécurité au niveau
--     des lignes (RLS).
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
grant usage on schema private to authenticated;

-- -----------------------------------------------------------------------------
-- Types
-- -----------------------------------------------------------------------------

create type public.staff_role as enum ('owner', 'manager', 'cashier');
create type public.entry_kind as enum ('visit', 'redemption', 'adjustment');

-- -----------------------------------------------------------------------------
-- Numéros de téléphone
-- Accepte « 77 123 45 67 », « 221771234567 », « +221 77... », « 00221... ».
-- Seuls les numéros mobiles sénégalais (9 chiffres commençant par 7) sont
-- acceptés.
-- -----------------------------------------------------------------------------

create function public.normalize_phone_sn(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  d text;
begin
  if p_phone is null then
    return null;
  end if;
  d := regexp_replace(p_phone, '[^0-9]', '', 'g');
  if d like '00%' then
    d := substr(d, 3);
  end if;
  if length(d) = 9 then
    d := '221' || d;
  end if;
  if d !~ '^2217[0-9]{8}$' then
    raise exception 'invalid_phone' using errcode = '22023';
  end if;
  return '+' || d;
end;
$$;

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

create table public.restaurants (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null check (length(trim(name)) between 1 and 120),
  logo_path           text,
  brand_color         text check (brand_color ~ '^#[0-9A-Fa-f]{6}$'),
  points_per_visit    int  not null default 1  check (points_per_visit between 1 and 1000),
  max_visits_per_day  int  not null default 1  check (max_visits_per_day between 1 and 20),
  max_offline_hours   int  not null default 24 check (max_offline_hours between 0 and 168),
  active              boolean not null default true,
  created_at          timestamptz not null default now()
);

comment on column public.restaurants.max_visits_per_day is
  'Plafond anti-fraude : nombre de passages crédités par client et par jour (heure de Dakar).';
comment on column public.restaurants.max_offline_hours is
  'Âge maximal d''un crédit enregistré hors ligne au moment de sa synchronisation.';

create table public.staff (
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  role          public.staff_role not null,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  primary key (restaurant_id, user_id)
);

create index staff_user_idx on public.staff (user_id);

create table public.customers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid unique references auth.users (id) on delete set null,
  phone       text not null unique check (phone ~ '^\+2217[0-9]{8}$'),
  first_name  text check (length(first_name) <= 60),
  qr_secret   bytea not null default extensions.gen_random_bytes(32),
  created_at  timestamptz not null default now()
);

comment on table public.customers is
  'Un client peut exister sans compte applicatif (inscrit par numéro au comptoir). user_id est relié quand il installe l''application.';

create table public.cards (
  id            uuid primary key default gen_random_uuid(),
  customer_id   uuid not null references public.customers (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  enrolled_by   uuid,
  created_at    timestamptz not null default now(),
  unique (customer_id, restaurant_id)
);

create index cards_restaurant_idx on public.cards (restaurant_id);

create table public.rewards (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name          text not null check (length(trim(name)) between 1 and 80),
  description   text check (length(description) <= 500),
  cost_points   int  not null check (cost_points > 0),
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create index rewards_restaurant_idx on public.rewards (restaurant_id);

create table public.redemptions (
  id            uuid primary key default gen_random_uuid(),
  card_id       uuid not null references public.cards (id) on delete cascade,
  reward_id     uuid not null references public.rewards (id) on delete restrict,
  points        int  not null check (points > 0),
  staff_user_id uuid,
  created_at    timestamptz not null default now()
);

create index redemptions_card_idx on public.redemptions (card_id);

-- Registre des points : une ligne par mouvement, jamais modifiée.
create table public.point_entries (
  id             bigint generated always as identity primary key,
  card_id        uuid not null references public.cards (id) on delete cascade,
  delta          int  not null check (delta <> 0),
  kind           public.entry_kind not null,
  staff_user_id  uuid,
  redemption_id  uuid references public.redemptions (id) on delete cascade,
  client_op_id   uuid not null,
  qr_step        bigint,
  occurred_at    timestamptz not null,
  recorded_at    timestamptz not null default now(),
  note           text check (length(note) <= 280),
  constraint point_entries_client_op_id_key unique (client_op_id),
  constraint point_entries_visit_positive check (kind <> 'visit' or delta > 0),
  constraint point_entries_redemption_shape check (
    kind <> 'redemption' or (delta < 0 and redemption_id is not null)
  )
);

comment on column public.point_entries.client_op_id is
  'Identifiant généré par l''appareil du caissier : un renvoi après coupure ne crédite jamais deux fois.';
comment on column public.point_entries.qr_step is
  'Fenêtre de 30 s du QR scanné : un même QR ne peut servir qu''une fois par carte.';

create index point_entries_card_idx on public.point_entries (card_id, occurred_at);
create unique index point_entries_qr_once_idx
  on public.point_entries (card_id, qr_step)
  where qr_step is not null;

create table public.marketing_consents (
  customer_id   uuid not null references public.customers (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  granted       boolean not null,
  updated_at    timestamptz not null default now(),
  primary key (customer_id, restaurant_id)
);

-- Solde par carte, calculé à la lecture et soumis aux droits de l'appelant.
create view public.card_balances
with (security_invoker = true) as
select c.id as card_id,
       c.restaurant_id,
       c.customer_id,
       coalesce(sum(e.delta), 0)::int as balance,
       max(e.occurred_at) filter (where e.kind = 'visit') as last_visit_at
from public.cards c
left join public.point_entries e on e.card_id = c.id
group by c.id;

-- -----------------------------------------------------------------------------
-- Registre en ajout seul
-- La suppression n'est permise que pendant l'effacement d'un compte client.
-- -----------------------------------------------------------------------------

create function private.forbid_entry_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('jaarama.erasure', true) = 'on' then
    return old;
  end if;
  raise exception 'point_entries_append_only' using errcode = '42501';
end;
$$;

create trigger point_entries_append_only
before update or delete on public.point_entries
for each row execute function private.forbid_entry_changes();

-- -----------------------------------------------------------------------------
-- Fonctions internes (schéma private, non exposé par l'API)
-- -----------------------------------------------------------------------------

create function private.has_staff_role(p_restaurant_id uuid, p_roles public.staff_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff s
    join public.restaurants r on r.id = s.restaurant_id
    where s.restaurant_id = p_restaurant_id
      and s.user_id = auth.uid()
      and s.active
      and r.active
      and s.role = any (p_roles)
  );
$$;

create function private.current_customer_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.customers where user_id = auth.uid();
$$;

-- Signature du QR client : HMAC-SHA256 tronqué à 20 caractères hexadécimaux.
-- Doit rester identique à packages/jaarama_core/lib/src/qr_token.dart.
create function private.qr_signature(p_secret bytea, p_customer_id uuid, p_step bigint)
returns text
language sql
immutable
set search_path = ''
as $$
  select substr(
    encode(
      extensions.hmac(convert_to(p_customer_id::text || ':' || p_step::text, 'UTF8'), p_secret, 'sha256'),
      'hex'),
    1, 20);
$$;

-- Vérifie un QR « JRM1.<customer_id>.<step>.<signature> » à l'instant p_at.
-- Tolérance de 2 fenêtres de 30 s pour absorber l'écart d'horloge.
create function private.verify_qr(p_token text, p_at timestamptz,
                                  out o_customer_id uuid, out o_step bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  parts    text[];
  v_secret bytea;
begin
  parts := string_to_array(coalesce(p_token, ''), '.');
  if coalesce(array_length(parts, 1), 0) <> 4 or parts[1] <> 'JRM1' then
    raise exception 'invalid_qr' using errcode = '22023';
  end if;

  begin
    o_customer_id := parts[2]::uuid;
    o_step := parts[3]::bigint;
  exception when others then
    raise exception 'invalid_qr' using errcode = '22023';
  end;

  if abs(o_step - floor(extract(epoch from p_at) / 30)::bigint) > 2 then
    raise exception 'qr_expired' using errcode = '22023';
  end if;

  select c.qr_secret into v_secret from public.customers c where c.id = o_customer_id;
  if not found or private.qr_signature(v_secret, o_customer_id, o_step) <> parts[4] then
    raise exception 'invalid_qr' using errcode = '22023';
  end if;
end;
$$;

-- Identifie le client présenté au comptoir : QR (application) ou numéro.
create function private.resolve_customer(p_qr_token text, p_phone text, p_at timestamptz,
                                         out o_customer_id uuid, out o_step bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (p_qr_token is null) = (p_phone is null) then
    raise exception 'exactly_one_identifier' using errcode = '22023';
  end if;

  if p_qr_token is not null then
    select v.o_customer_id, v.o_step into o_customer_id, o_step
    from private.verify_qr(p_qr_token, p_at) v;
  else
    select c.id into o_customer_id
    from public.customers c
    where c.phone = public.normalize_phone_sn(p_phone);
    if not found then
      raise exception 'customer_not_found' using errcode = 'P0002';
    end if;
  end if;
end;
$$;

create function private.card_balance(p_card_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(delta), 0)::int from public.point_entries where card_id = p_card_id;
$$;

-- -----------------------------------------------------------------------------
-- Fonctions appelées par l'application marchand
-- Elles renvoient du JSON et signalent les erreurs par un code stable
-- (forbidden, daily_limit_reached, ...) que l'application traduit.
-- -----------------------------------------------------------------------------

-- Inscrit un client par son numéro (client sans application) et crée sa carte.
create function public.register_customer(p_restaurant_id uuid, p_phone text, p_first_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone    text := public.normalize_phone_sn(p_phone);
  v_customer public.customers;
  v_is_new   boolean := false;
  v_card_id  uuid;
begin
  if not private.has_staff_role(p_restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_customer from public.customers where phone = v_phone;
  if not found then
    insert into public.customers (phone, first_name)
    values (v_phone, nullif(trim(p_first_name), ''))
    returning * into v_customer;
    v_is_new := true;
  end if;

  insert into public.cards (customer_id, restaurant_id, enrolled_by)
  values (v_customer.id, p_restaurant_id, auth.uid())
  on conflict (customer_id, restaurant_id) do nothing;

  select id into v_card_id from public.cards
  where customer_id = v_customer.id and restaurant_id = p_restaurant_id;

  return jsonb_build_object(
    'card_id', v_card_id,
    'first_name', v_customer.first_name,
    'is_new_customer', v_is_new,
    'balance', private.card_balance(v_card_id));
end;
$$;

-- Crédite un passage. Idempotent sur p_client_op_id, utilisable hors ligne :
-- p_occurred_at est l'heure du scan relevée par l'appareil du caissier.
create function public.credit_visit(
  p_restaurant_id uuid,
  p_client_op_id  uuid,
  p_occurred_at   timestamptz,
  p_qr_token      text default null,
  p_phone         text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_restaurant public.restaurants;
  v_existing   public.point_entries;
  v_customer   uuid;
  v_step       bigint;
  v_card_id    uuid;
  v_day_start  timestamptz;
  v_visits     int;
  v_entry_id   bigint;
  v_constraint text;
begin
  if not private.has_staff_role(p_restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Renvoi d'une opération déjà enregistrée : on renvoie le même résultat.
  select * into v_existing from public.point_entries where client_op_id = p_client_op_id;
  if found then
    return private.visit_result(v_existing, p_restaurant_id, true);
  end if;

  select * into v_restaurant from public.restaurants where id = p_restaurant_id;

  if p_occurred_at is null
     or p_occurred_at > now() + interval '2 minutes'
     or p_occurred_at < now() - make_interval(hours => v_restaurant.max_offline_hours) then
    raise exception 'occurred_at_out_of_range' using errcode = '22023';
  end if;

  select r.o_customer_id, r.o_step into v_customer, v_step
  from private.resolve_customer(p_qr_token, p_phone, p_occurred_at) r;

  insert into public.cards (customer_id, restaurant_id, enrolled_by)
  values (v_customer, p_restaurant_id, auth.uid())
  on conflict (customer_id, restaurant_id) do nothing;

  -- Verrou sur la carte : deux crédits simultanés passent l'un après l'autre.
  select id into v_card_id from public.cards
  where customer_id = v_customer and restaurant_id = p_restaurant_id
  for update;

  v_day_start := date_trunc('day', p_occurred_at at time zone 'Africa/Dakar') at time zone 'Africa/Dakar';
  select count(*) into v_visits
  from public.point_entries
  where card_id = v_card_id
    and kind = 'visit'
    and occurred_at >= v_day_start
    and occurred_at < v_day_start + interval '1 day';

  if v_visits >= v_restaurant.max_visits_per_day then
    raise exception 'daily_limit_reached' using errcode = 'P0001';
  end if;

  begin
    insert into public.point_entries (card_id, delta, kind, staff_user_id, client_op_id, qr_step, occurred_at)
    values (v_card_id, v_restaurant.points_per_visit, 'visit', auth.uid(), p_client_op_id, v_step, p_occurred_at)
    returning * into v_existing;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'point_entries_qr_once_idx' then
      raise exception 'qr_already_used' using errcode = 'P0001';
    end if;
    -- Même opération envoyée deux fois en parallèle.
    select * into v_existing from public.point_entries where client_op_id = p_client_op_id;
    return private.visit_result(v_existing, p_restaurant_id, true);
  end;

  return private.visit_result(v_existing, p_restaurant_id, false);
end;
$$;

create function private.visit_result(p_entry public.point_entries, p_restaurant_id uuid, p_replayed boolean)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_card public.cards;
begin
  select * into v_card from public.cards where id = p_entry.card_id;
  if p_entry.kind <> 'visit' or v_card.restaurant_id <> p_restaurant_id then
    raise exception 'client_op_id_conflict' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'card_id', v_card.id,
    'entry_id', p_entry.id,
    'points_added', p_entry.delta,
    'balance', private.card_balance(v_card.id),
    'first_name', (select first_name from public.customers where id = v_card.customer_id),
    'already_recorded', p_replayed);
end;
$$;

-- Échange des points contre une récompense. Exige le réseau : l'heure de
-- référence est celle du serveur.
create function public.redeem_reward(
  p_restaurant_id uuid,
  p_reward_id     uuid,
  p_client_op_id  uuid,
  p_qr_token      text default null,
  p_phone         text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reward        public.rewards;
  v_existing      public.point_entries;
  v_customer      uuid;
  v_step          bigint;
  v_card_id       uuid;
  v_balance       int;
  v_redemption_id uuid;
begin
  if not private.has_staff_role(p_restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_existing from public.point_entries where client_op_id = p_client_op_id;
  if found then
    if v_existing.kind <> 'redemption' then
      raise exception 'client_op_id_conflict' using errcode = '22023';
    end if;
    return jsonb_build_object(
      'redemption_id', v_existing.redemption_id,
      'points_spent', -v_existing.delta,
      'balance', private.card_balance(v_existing.card_id),
      'already_recorded', true);
  end if;

  select * into v_reward from public.rewards
  where id = p_reward_id and restaurant_id = p_restaurant_id and active;
  if not found then
    raise exception 'reward_not_found' using errcode = 'P0002';
  end if;

  select r.o_customer_id, r.o_step into v_customer, v_step
  from private.resolve_customer(p_qr_token, p_phone, now()) r;

  select id into v_card_id from public.cards
  where customer_id = v_customer and restaurant_id = p_restaurant_id
  for update;
  if not found then
    raise exception 'card_not_found' using errcode = 'P0002';
  end if;

  v_balance := private.card_balance(v_card_id);
  if v_balance < v_reward.cost_points then
    raise exception 'insufficient_points' using errcode = 'P0001';
  end if;

  insert into public.redemptions (card_id, reward_id, points, staff_user_id)
  values (v_card_id, v_reward.id, v_reward.cost_points, auth.uid())
  returning id into v_redemption_id;

  insert into public.point_entries (card_id, delta, kind, staff_user_id, redemption_id, client_op_id, occurred_at)
  values (v_card_id, -v_reward.cost_points, 'redemption', auth.uid(), v_redemption_id, p_client_op_id, now());

  return jsonb_build_object(
    'redemption_id', v_redemption_id,
    'points_spent', v_reward.cost_points,
    'balance', v_balance - v_reward.cost_points,
    'already_recorded', false);
end;
$$;

-- Liste des clients d'un restaurant pour le gérant. Numéro masqué.
create function public.restaurant_customers(p_restaurant_id uuid)
returns table (
  card_id       uuid,
  first_name    text,
  phone_masked  text,
  balance       int,
  visits        int,
  last_visit_at timestamptz,
  enrolled_at   timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id,
         cu.first_name,
         substr(cu.phone, 1, 6) || ' *** ** ' || substr(cu.phone, 12, 2),
         coalesce(sum(e.delta), 0)::int,
         (count(*) filter (where e.kind = 'visit'))::int,
         max(e.occurred_at) filter (where e.kind = 'visit'),
         c.created_at
  from public.cards c
  join public.customers cu on cu.id = c.customer_id
  left join public.point_entries e on e.card_id = c.id
  where c.restaurant_id = p_restaurant_id
    and private.has_staff_role(p_restaurant_id, array['owner', 'manager']::public.staff_role[])
  group by c.id, cu.first_name, cu.phone
  order by max(e.occurred_at) desc nulls last;
$$;

-- Ajoute un caissier ou un gérant. La personne doit d'abord avoir créé son
-- compte dans l'application marchand avec son numéro.
create function public.add_staff_member(p_restaurant_id uuid, p_phone text, p_role public.staff_role)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone   text := public.normalize_phone_sn(p_phone);
  v_user_id uuid;
begin
  if not private.has_staff_role(p_restaurant_id, array['owner']::public.staff_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_role = 'owner' then
    raise exception 'owner_assigned_by_platform' using errcode = '42501';
  end if;

  select u.id into v_user_id from auth.users u
  where '+' || ltrim(u.phone, '+') = v_phone;
  if not found then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;

  insert into public.staff (restaurant_id, user_id, role)
  values (p_restaurant_id, v_user_id, p_role)
  on conflict (restaurant_id, user_id) do update set role = excluded.role, active = true
  where public.staff.role <> 'owner';

  return jsonb_build_object('user_id', v_user_id, 'role', p_role);
end;
$$;

create function public.set_staff_active(p_restaurant_id uuid, p_user_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_staff_role(p_restaurant_id, array['owner']::public.staff_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.staff set active = p_active
  where restaurant_id = p_restaurant_id and user_id = p_user_id and role <> 'owner';
end;
$$;

-- -----------------------------------------------------------------------------
-- Fonctions appelées par l'application client
-- -----------------------------------------------------------------------------

-- Relie le compte connecté (vérifié par code SMS) à sa fiche client, en
-- reprenant les cartes créées au comptoir avant l'installation.
create function public.claim_customer_profile(p_first_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_phone    text;
  v_customer public.customers;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select public.normalize_phone_sn(u.phone) into v_phone from auth.users u where u.id = v_uid;
  if v_phone is null then
    raise exception 'phone_required' using errcode = '22023';
  end if;

  select * into v_customer from public.customers where phone = v_phone for update;
  if not found then
    insert into public.customers (user_id, phone, first_name)
    values (v_uid, v_phone, nullif(trim(p_first_name), ''))
    returning * into v_customer;
  elsif v_customer.user_id is null then
    update public.customers
    set user_id = v_uid,
        first_name = coalesce(nullif(trim(p_first_name), ''), first_name)
    where id = v_customer.id
    returning * into v_customer;
  elsif v_customer.user_id <> v_uid then
    raise exception 'phone_already_linked' using errcode = '23505';
  end if;

  return jsonb_build_object(
    'customer_id', v_customer.id,
    'first_name', v_customer.first_name,
    'qr_secret', encode(v_customer.qr_secret, 'hex'));
end;
$$;

-- Efface la fiche client, ses cartes et son historique.
-- Le compte d'authentification est supprimé séparément par une fonction serveur.
create function public.delete_my_customer_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  perform set_config('jaarama.erasure', 'on', true);
  delete from public.customers where user_id = auth.uid();
  perform set_config('jaarama.erasure', 'off', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- Sécurité au niveau des lignes
-- -----------------------------------------------------------------------------

alter table public.restaurants        enable row level security;
alter table public.staff              enable row level security;
alter table public.customers          enable row level security;
alter table public.cards              enable row level security;
alter table public.rewards            enable row level security;
alter table public.redemptions        enable row level security;
alter table public.point_entries      enable row level security;
alter table public.marketing_consents enable row level security;

-- Restaurants : visibles par tout utilisateur connecté (logo et nom des cartes),
-- modifiables par le propriétaire et le gérant. Création par la plateforme.
create policy restaurants_read on public.restaurants
  for select to authenticated
  using (active or private.has_staff_role(id, array['owner', 'manager', 'cashier']::public.staff_role[]));

create policy restaurants_update on public.restaurants
  for update to authenticated
  using (private.has_staff_role(id, array['owner', 'manager']::public.staff_role[]))
  with check (private.has_staff_role(id, array['owner', 'manager']::public.staff_role[]));

-- Personnel : chacun voit ses propres affectations ; le propriétaire et le
-- gérant voient l'équipe de leur restaurant.
create policy staff_read on public.staff
  for select to authenticated
  using (user_id = auth.uid()
         or private.has_staff_role(restaurant_id, array['owner', 'manager']::public.staff_role[]));

-- Clients : chacun ne voit que sa propre fiche. Le personnel passe par les fonctions.
create policy customers_read_own on public.customers
  for select to authenticated
  using (user_id = auth.uid());

create policy customers_update_own on public.customers
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy cards_read on public.cards
  for select to authenticated
  using (customer_id = private.current_customer_id()
         or private.has_staff_role(restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]));

create policy point_entries_read on public.point_entries
  for select to authenticated
  using (exists (
    select 1 from public.cards c
    where c.id = card_id
      and (c.customer_id = private.current_customer_id()
           or private.has_staff_role(c.restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]))));

create policy redemptions_read on public.redemptions
  for select to authenticated
  using (exists (
    select 1 from public.cards c
    where c.id = card_id
      and (c.customer_id = private.current_customer_id()
           or private.has_staff_role(c.restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]))));

create policy rewards_read on public.rewards
  for select to authenticated
  using (active or private.has_staff_role(restaurant_id, array['owner', 'manager', 'cashier']::public.staff_role[]));

create policy rewards_insert on public.rewards
  for insert to authenticated
  with check (private.has_staff_role(restaurant_id, array['owner', 'manager']::public.staff_role[]));

create policy rewards_update on public.rewards
  for update to authenticated
  using (private.has_staff_role(restaurant_id, array['owner', 'manager']::public.staff_role[]))
  with check (private.has_staff_role(restaurant_id, array['owner', 'manager']::public.staff_role[]));

create policy consents_read_own on public.marketing_consents
  for select to authenticated
  using (customer_id = private.current_customer_id());

create policy consents_insert_own on public.marketing_consents
  for insert to authenticated
  with check (customer_id = private.current_customer_id());

create policy consents_update_own on public.marketing_consents
  for update to authenticated
  using (customer_id = private.current_customer_id())
  with check (customer_id = private.current_customer_id());

-- -----------------------------------------------------------------------------
-- Droits
-- Rien pour le rôle anonyme ; le minimum pour les utilisateurs connectés.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

grant select on public.restaurants, public.staff, public.customers, public.cards,
                public.rewards, public.redemptions, public.point_entries,
                public.marketing_consents, public.card_balances
  to authenticated;
grant update (name, logo_path, brand_color, points_per_visit, max_visits_per_day, max_offline_hours)
  on public.restaurants to authenticated;
grant update (first_name) on public.customers to authenticated;
grant insert (restaurant_id, name, description, cost_points, active),
      update (name, description, cost_points, active)
  on public.rewards to authenticated;
grant insert (customer_id, restaurant_id, granted), update (granted, updated_at)
  on public.marketing_consents to authenticated;

-- Le secret du QR n'est lisible que via claim_customer_profile().
revoke select on public.customers from authenticated;
grant select (id, user_id, phone, first_name, created_at) on public.customers to authenticated;

grant execute on function
  public.normalize_phone_sn(text),
  public.register_customer(uuid, text, text),
  public.credit_visit(uuid, uuid, timestamptz, text, text),
  public.redeem_reward(uuid, uuid, uuid, text, text),
  public.restaurant_customers(uuid),
  public.add_staff_member(uuid, text, public.staff_role),
  public.set_staff_active(uuid, uuid, boolean),
  public.claim_customer_profile(text),
  public.delete_my_customer_data()
  to authenticated;

grant execute on function
  private.has_staff_role(uuid, public.staff_role[]),
  private.current_customer_id()
  to authenticated;
