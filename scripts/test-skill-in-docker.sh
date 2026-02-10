#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-codexmcp:latest}"
PROMPT="${MCP_SKILL_PROMPT:-\$mcp-skill-smoke run the smoke script from this skill now. Follow its workflow exactly and then report the contents of skill-smoke-result.txt.}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_output="$(mktemp -d "/tmp/codexmcp-skill-test.XXXXXX")"
result_file="${tmp_output}/skill-smoke-result.txt"
run_log="${tmp_output}/run.log"
success=0

cleanup() {
  if [[ "${success}" -eq 1 ]]; then
    rm -rf "${tmp_output}" 2>/dev/null || true
  else
    echo "Debug artifacts kept at: ${tmp_output}"
  fi
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed"
  exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "ERROR: image '${IMAGE}' not found. Build it first:"
  echo "  docker build -t ${IMAGE} ${repo_root}"
  exit 1
fi

docker_auth_args=()
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  docker_auth_args=(-e "OPENAI_API_KEY=${OPENAI_API_KEY}")
elif [[ -f "${repo_root}/.env" ]] && grep -q '^OPENAI_API_KEY=' "${repo_root}/.env"; then
  key_from_env_file="$(grep -m1 '^OPENAI_API_KEY=' "${repo_root}/.env" | cut -d= -f2-)"
  key_from_env_file="${key_from_env_file%$'\r'}"
  if [[ "${key_from_env_file}" == \"*\" && "${key_from_env_file}" == *\" ]]; then
    key_from_env_file="${key_from_env_file:1:${#key_from_env_file}-2}"
  elif [[ "${key_from_env_file}" == \'*\' && "${key_from_env_file}" == *\' ]]; then
    key_from_env_file="${key_from_env_file:1:${#key_from_env_file}-2}"
  fi
  docker_auth_args=(-e "OPENAI_API_KEY=${key_from_env_file}")
else
  echo "ERROR: OPENAI_API_KEY not set and ${repo_root}/.env is missing OPENAI_API_KEY"
  exit 1
fi

echo "Running Docker skill smoke test with image: ${IMAGE}"
set +e
docker run --rm \
  "${docker_auth_args[@]}" \
  -e "CODEX_SANDBOX_MODE=${CODEX_SANDBOX_MODE:-danger-full-access}" \
  -v "${tmp_output}:/app/output" \
  "${IMAGE}" \
  "${PROMPT}" 2>&1 | tee "${run_log}"
run_status=${PIPESTATUS[0]}
set -e

if [[ "${run_status}" -ne 0 ]]; then
  if grep -qi 'invalid_api_key\|Incorrect API key provided' "${run_log}"; then
    echo
    echo "FAIL: OpenAI API key is invalid for this run."
    echo "Update OPENAI_API_KEY and retry."
  elif grep -qi 'Missing bearer authentication in header' "${run_log}"; then
    echo
    echo "FAIL: codex subprocess did not receive OPENAI_API_KEY."
    echo "Ensure main.py passes env to MCPServerStdio and rebuild the image."
  else
    echo
    echo "FAIL: container run failed. See ${run_log}"
  fi
  exit "${run_status}"
fi

if [[ ! -f "${result_file}" ]]; then
  echo "FAIL: skill marker file was not created: ${result_file}"
  exit 1
fi

if ! grep -q '^skill=mcp-skill-smoke$' "${result_file}"; then
  echo "FAIL: marker file exists but has unexpected content:"
  cat "${result_file}"
  exit 1
fi

if ! grep -q '^script_path=.*/mcp-skill-smoke/scripts/run-smoke.sh$' "${result_file}"; then
  echo "FAIL: marker file does not confirm smoke script path:"
  cat "${result_file}"
  exit 1
fi

echo
echo "PASS: skill was triggered and executed inside Docker."
cat "${result_file}"
success=1
