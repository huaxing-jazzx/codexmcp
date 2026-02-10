#!/usr/bin/env bash
set -euo pipefail

# Codex CLI in containerized environments should be bootstrapped with an API key.
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  printf '%s\n' "${OPENAI_API_KEY}" | codex login --with-api-key >/dev/null
fi

exec uv run python main.py "$@"
