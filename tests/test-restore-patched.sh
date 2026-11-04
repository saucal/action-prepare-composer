#!/usr/bin/env bash
# prepare-composer-wp.sh restores the previous build's packages, but never a patched one: its
# patch set may have changed, so composer must install (and re-patch) it fresh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../prepare-composer-wp.sh"
fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

paths='{"extra":{"installer-paths":{"wp-content/plugins/{$name}/":["type:wordpress-plugin"],"wp-content/themes/{$name}/":["type:wordpress-theme"]}}}'
mkdir -p "$tmp/from/vendor/composer" "$tmp/to"
echo "$paths" > "$tmp/from/composer.json"
echo "$paths" > "$tmp/to/composer.json"
for p in plugins/plain plugins/saucal-patched themes/cweagans-patched; do
	mkdir -p "$tmp/from/wp-content/$p"; echo "previous build" > "$tmp/from/wp-content/$p/file.php"
done
cat > "$tmp/from/vendor/composer/installed.json" <<'JSON'
{"packages":[
 {"name":"composer/installers","install-path":"./installers"},
 {"name":"acme/plain","install-path":"../../wp-content/plugins/plain"},
 {"name":"acme/saucal-patched","install-path":"../../wp-content/plugins/saucal-patched","extra":{"saucal-patches-applied":"abc123"}},
 {"name":"acme/cweagans-patched","install-path":"../../wp-content/themes/cweagans-patched","extra":{"patches_applied":{"fix":"patches/fix.patch"}}}
]}
JSON
echo '{"packages":[{"name":"acme/plain"},{"name":"acme/saucal-patched"},{"name":"acme/cweagans-patched"}]}' > "$tmp/to/composer.lock"

out="$(GITHUB_WORKSPACE="$tmp" PATH_DIR=to FROM_DIR=from bash "$SCRIPT" 2>&1)" || { echo "FAIL - script exited non-zero"; echo "$out" | sed 's/^/       /'; exit 1; }
names="$(jq -r '.packages[].name' "$tmp/to/vendor/composer/installed.json" | sort | tr '\n' ' ')"

check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }
check "unpatched package restored" '[ -f "$tmp/to/wp-content/plugins/plain/file.php" ]'
check "unpatched package kept in installed.json" 'grep -q "acme/plain" <<< "$names"'
check "saucal-patches-applied package not restored" '[ ! -e "$tmp/to/wp-content/plugins/saucal-patched" ]'
check "saucal-patches-applied package dropped from installed.json" '! grep -q "acme/saucal-patched" <<< "$names"'
check "patches_applied package not restored" '[ ! -e "$tmp/to/wp-content/themes/cweagans-patched" ]'
check "patches_applied package dropped from installed.json" '! grep -q "acme/cweagans-patched" <<< "$names"'
exit $fail
