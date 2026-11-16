-- Reproduit le strict nécessaire de l'environnement Supabase pour exécuter
-- les migrations et les tests sur un PostgreSQL nu (local ou CI).
-- NE PAS appliquer sur un vrai projet Supabase.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema extensions;
create schema auth;
grant usage on schema auth to anon, authenticated;

create table auth.users (
  id    uuid primary key default gen_random_uuid(),
  phone text unique
);

create function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
