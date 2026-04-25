#!/usr/bin/env bash
# Validates that any SQL migration creating a new table also includes GRANT statements.
# Prevents the "Failed to save roadmap" class of bugs where RLS passes but table-level
# GRANTs are missing, causing silent INSERT failures in production.

set -euo pipefail

FAIL=0

# Determine which SQL files changed vs main (PR context) or all migrations (local run)
if git rev-parse origin/main &>/dev/null 2>&1; then
  CHANGED_SQL=$(git diff --name-only origin/main...HEAD -- 'supabase/migrations/*.sql' 2>/dev/null || true)
else
  # Fallback: check all migration files (useful for local dev)
  CHANGED_SQL=$(find supabase/migrations -name '*.sql' 2>/dev/null || true)
fi

if [ -z "$CHANGED_SQL" ]; then
  echo "No migration files changed ✓"
  exit 0
fi

for file in $CHANGED_SQL; do
  [ -f "$file" ] || continue

  if grep -qiE "CREATE TABLE" "$file"; then
    # Must have both SELECT and INSERT GRANTs
    if ! grep -qiE "GRANT[^;]+SELECT[^;]+TO" "$file"; then
      echo "ERROR: $file creates a table but is missing a GRANT SELECT statement."
      echo "  Required: GRANT SELECT, INSERT ON public.<table> TO anon, authenticated;"
      FAIL=1
    fi
    if ! grep -qiE "GRANT[^;]+INSERT[^;]+TO" "$file"; then
      echo "ERROR: $file creates a table but is missing a GRANT INSERT statement."
      echo "  Required: GRANT SELECT, INSERT ON public.<table> TO anon, authenticated;"
      FAIL=1
    fi
    # Must have RLS enabled
    if ! grep -qiE "ENABLE ROW LEVEL SECURITY" "$file"; then
      echo "ERROR: $file creates a table but does not enable RLS."
      echo "  Required: ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;"
      FAIL=1
    fi

    if [ $FAIL -eq 0 ]; then
      echo "✓ $file — CREATE TABLE, RLS, and GRANTs all present"
    fi
  fi
done

if [ $FAIL -eq 1 ]; then
  echo ""
  echo "Migration safety check failed. See errors above."
  exit 1
fi

echo "All migration files passed safety check ✓"
