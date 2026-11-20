#!/usr/bin/env bash
# Applies database migrations and deploys every edge function to ONE
# Supabase project, named explicitly, so staging and production never mix.
#
#   tools/deploy_backend.sh staging
#   tools/deploy_backend.sh production     (asks you to type "production")
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/supabase_projects.env

target="${1:-}"
case "$target" in
  staging)    ref="$STAGING_REF" ;;
  production) ref="$PRODUCTION_REF" ;;
  *) echo "Usage: tools/deploy_backend.sh staging|production" >&2; exit 1 ;;
esac
if [ -z "$ref" ]; then
  echo "No project ref for $target: set it in tools/supabase_projects.env" >&2
  exit 1
fi
if [ "$target" = production ]; then
  read -r -p "Deploy to PRODUCTION ($ref)? Type production to go on: " answer
  [ "$answer" = production ] || { echo "Stopped."; exit 1; }
fi

echo "== Migrations → $target ($ref)"
supabase db push --remote="$ref"

echo "== Functions → $target ($ref)"
supabase functions deploy ask-astrologer --project-ref "$ref"
supabase functions deploy consult-prices --project-ref "$ref"
supabase functions deploy create-consultation-checkout --project-ref "$ref"
supabase functions deploy stripe-webhook --no-verify-jwt --project-ref "$ref"
supabase functions deploy notify-consultation-paid --no-verify-jwt --project-ref "$ref"

echo "== Done: $target is up to date."
