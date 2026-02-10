#!/usr/bin/env bash
set -euo pipefail

out_file="${1:-skill-smoke-result.txt}"
timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
nonce="$(uuidgen 2>/dev/null || date +%s)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="${script_dir}/$(basename "${BASH_SOURCE[0]}")"

{
  echo "skill=mcp-skill-smoke"
  echo "timestamp_utc=${timestamp_utc}"
  echo "nonce=${nonce}"
  echo "pid=$$"
  echo "script_path=${script_path}"
  echo "cwd=$(pwd)"
} > "${out_file}"

echo "wrote ${out_file}"
