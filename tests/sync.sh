#!/bin/bash
set -euo pipefail

repo_root="${ME_TEST_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/me-sync-test.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
cp "$repo_root/me" "$test_dir/me"
cp -R "$repo_root/lib" "$test_dir/lib"
sed '/^# --- Main /,$d' "$repo_root/me" > "$test_dir/resolve"
cat >> "$test_dir/resolve" <<'RESOLVE'
parse_drift_args "$@"
printf '%s\n' "${selected[@]}"
RESOLVE
export ME_TEST_LOG="$test_dir/deployments"
for unit in apps/agents apps/shell macos/desktop; do
	mkdir -p "$test_dir/configs/$unit"
	printf 'printf "%%s\\n" "%s" >> "$ME_TEST_LOG"\n' "$unit" > "$test_dir/configs/$unit/configure_${unit##*/}.sh"
done

function expect_deployments {
	local expected="$1"
	shift
	: > "$ME_TEST_LOG"
	if ! bash "$test_dir/me" sync "$@" > "$test_dir/output" 2>&1; then
		cat "$test_dir/output"
		exit 1
	fi
	if [[ "$(cat "$ME_TEST_LOG")" != "$expected" ]]; then
		printf 'Unexpected deployment for sync %s\n' "$*" >&2
		cat "$test_dir/output"
		exit 1
	fi
}

function expect_rejection {
	: > "$ME_TEST_LOG"
	if bash "$test_dir/me" sync "$@" > "$test_dir/output" 2>&1; then
		printf 'Expected sync %s to fail\n' "$*" >&2
		exit 1
	fi
	[[ ! -s "$ME_TEST_LOG" ]]
}

[[ "$(bash "$test_dir/resolve" agents)" == configs/apps/agents/configure_agents.sh ]]
[[ "$(bash "$test_dir/resolve" desktop)" == configs/macos/desktop/configure_desktop.sh ]]
expect_deployments apps/agents agents
expect_deployments apps/agents app agents
expect_deployments macos/desktop desktop
expect_deployments $'apps/agents\napps/shell' agents shell
expect_deployments apps/agents agents agents
expect_deployments $'apps/agents\napps/shell' app --yes
expect_deployments macos/desktop macos --yes
expect_deployments $'macos/desktop\napps/agents\napps/shell' --yes
expect_deployments $'macos/desktop\napps/agents\napps/shell' all --yes
expect_rejection agnets
expect_rejection --yes agnets
expect_rejection agents agnets
expect_rejection configs/apps/agents
expect_rejection --yes configs/apps/agents
expect_rejection agents configs/apps/shell
expect_rejection all agents
expect_rejection app agnets
mkdir -p "$test_dir/configs/macos/agents"
printf 'exit 99\n' > "$test_dir/configs/macos/agents/configure_agents.sh"
expect_rejection agents
expect_deployments apps/agents app agents
printf 'sync tests passed\n'
