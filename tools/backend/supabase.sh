#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
export SUPABASE_HOME="$task_root/.supabase"
export SUPABASE_TELEMETRY_DISABLED=1
cd "$task_root"
exec "$task_root/tools/backend/node_modules/.bin/supabase" "$@"
