#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/lib/compose.sh"

for dependency in jq yq jsonnet; do
	if ! command -v "$dependency" >/dev/null; then
		echo "compose tests require $dependency" >&2
		exit 1
	fi
done

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/me-compose-test.XXXXXX")"
repo_test_dir="$(mktemp -d "$repo_root/tests/.compose-test.XXXXXX")"
trap 'rm -rf "$test_dir" "$repo_test_dir"' EXIT

base="$test_dir/settings.json"
mkdir -p "$base.d"

printf '%s\n' '{"steps":["base"],"nested":{"fromBase":true}}' > "$base"
printf '%s\n' '{"steps":["merged-before"]}' > "$base.d/10-before.json"
cat > "$base.d/20-transform.jsonnet" <<'JSONNET'
function(document)
  document {
    steps: ['transformed'] + document.steps,
    nested+: { fromJsonnet: true },
  }
JSONNET
printf '%s\n' '{"steps":["merged-after"]}' > "$base.d/30-after.json"

compose_file "$base" "$test_dir/output.json"
jq -e '
  .steps == ["transformed", "base", "merged-before", "merged-after"] and
  .nested == {"fromBase": true, "fromJsonnet": true}
' "$test_dir/output.json" >/dev/null

yaml_base="$test_dir/settings.yaml"
mkdir -p "$yaml_base.d"
printf '%s\n' 'steps: [base]' > "$yaml_base"
printf '%s\n' 'function(document) document { steps: document.steps + ["jsonnet"] }' > "$yaml_base.d/10-transform.jsonnet"
compose_file "$yaml_base" "$test_dir/output.yaml"
yq -e '.steps[0] == "base" and .steps[1] == "jsonnet" and (.steps | length) == 2' "$test_dir/output.yaml" >/dev/null

yml_base="$test_dir/settings.yml"
mkdir -p "$yml_base.d"
printf '%s\n' 'steps: [base]' > "$yml_base"
printf '%s\n' 'function(document) document { steps: document.steps + ["jsonnet"] }' > "$yml_base.d/10-transform.jsonnet"
compose_file "$yml_base" "$test_dir/output.yml"
yq -e '.steps[0] == "base" and .steps[1] == "jsonnet" and (.steps | length) == 2' "$test_dir/output.yml" >/dev/null

toml_base="$test_dir/settings.toml"
mkdir -p "$toml_base.d"
printf '%s\n' 'steps = ["base"]' > "$toml_base"
printf '%s\n' 'function(document) document { steps: document.steps + ["jsonnet"] }' > "$toml_base.d/10-transform.jsonnet"
compose_file "$toml_base" "$test_dir/output.toml"
yq --input-format=toml -o=json . "$test_dir/output.toml" | jq -e '.steps == ["base", "jsonnet"]' >/dev/null

printf '%s\n' 'function(document) null' > "$base.d/20-transform.jsonnet"
if compose_file "$base" "$test_dir/invalid.json" > "$test_dir/invalid.stdout" 2> "$test_dir/invalid.stderr"; then
	echo "Expected a null Jsonnet result to fail" >&2
	exit 1
fi
grep -q 'Jsonnet transformer returned null' "$test_dir/invalid.stderr"

printf '%s\n' 'function(document) []' > "$base.d/20-transform.jsonnet"
if compose_file "$base" "$test_dir/invalid.json" >/dev/null 2> "$test_dir/invalid.stderr"; then
	echo "Expected a root-type change to fail" >&2
	exit 1
fi
grep -q 'Jsonnet transformer changed root type from object to array' "$test_dir/invalid.stderr"

if (PATH=/usr/bin:/bin; transform_jsonnet_fragment "$base" "$base.d/20-transform.jsonnet" json) > "$test_dir/missing.stdout" 2> "$test_dir/missing.stderr"; then
	echo "Expected a missing jsonnet executable to fail" >&2
	exit 1
fi
case "$(< "$test_dir/missing.stderr")" in
	*'Jsonnet fragment requires jsonnet'*) ;;
	*) echo "Expected the missing-jsonnet diagnostic on stderr" >&2; exit 1 ;;
esac
[[ ! -s "$test_dir/missing.stdout" ]]

managed="$repo_test_dir/managed.json"
destination="$repo_test_dir/deployed.json"
mkdir -p "$managed.d"
printf '%s\n' '{"preserved":true}' > "$destination"
printf '%s\n' '{"replacement":true}' > "$managed"
printf '%s\n' 'function(document) null' > "$managed.d/10-invalid.jsonnet"
printf '%s\n' "$destination" > "$managed.d/dest"
if deploy_managed_under "$repo_test_dir" >/dev/null 2>&1; then
	echo "Expected managed deployment with an invalid transformer to fail" >&2
	exit 1
fi
jq -e '.preserved == true and (keys | length) == 1' "$destination" >/dev/null

echo "compose tests passed"
