#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$task_root"
if [ ! -x tools/backend/node_modules/.bin/supabase ]; then
    npm ci --prefix tools/backend --no-audit --no-fund
fi
mkdir -p .supabase
./tools/backend/supabase.sh start --runtime native --eager > .supabase/start.log 2>&1
./tools/backend/supabase.sh status --output-format json > .supabase/status.json
python3 tools/backend/configure-local.py
