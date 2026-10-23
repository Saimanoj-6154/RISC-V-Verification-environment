#!/usr/bin/env bash
# Remove build products and run outputs. Keeps the .gitkeep placeholders.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
rm -rf work transcript modelsim.ini
find sim/logs sim/waves regression/results -type f ! -name '.gitkeep' -delete 2>/dev/null || true
echo "cleaned"
