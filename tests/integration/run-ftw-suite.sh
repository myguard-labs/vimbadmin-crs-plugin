#!/usr/bin/env bash
set -euo pipefail

config="${1:-tests/integration/.ftw.yml}"

for suite in tests/regression tests/security; do
    ./ftw check -d "$suite" --config "$config"
    ./ftw run -d "$suite" --config "$config" --show-failures-only
done
