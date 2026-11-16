#!/usr/bin/env bash
# Applique les migrations sur une base PostgreSQL vide puis lance les tests.
#
# Usage : scripts/test-db.sh
# Variables : PGHOST, PGPORT, PGUSER, PGPASSWORD (connexion à un serveur
# PostgreSQL 15+ ; une base temporaire jaarama_test y est recréée).
set -euo pipefail

cd "$(dirname "$0")/.."
DB="${TEST_DB:-jaarama_test}"

psql -v ON_ERROR_STOP=1 -qX -d postgres -c "drop database if exists $DB" -c "create database $DB"

# Les rôles anon/authenticated/service_role sont propres au cluster : on ne les
# recrée que s'ils n'existent pas déjà.
if psql -qtAX -d postgres -c "select 1 from pg_roles where rolname = 'authenticated'" | grep -q 1; then
  sed '/^create role /d' supabase/tests/00_supabase_shim.sql | psql -v ON_ERROR_STOP=1 -qX -d "$DB" >/dev/null
else
  psql -v ON_ERROR_STOP=1 -qX -d "$DB" -f supabase/tests/00_supabase_shim.sql >/dev/null
fi

for f in supabase/migrations/*.sql; do
  echo "Migration : $f"
  psql -v ON_ERROR_STOP=1 -qX -d "$DB" -f "$f" >/dev/null
done

for f in supabase/tests/[0-9]*_test.sql; do
  echo "Tests : $f"
  psql -v ON_ERROR_STOP=1 -qX -d "$DB" -f "$f"
done
