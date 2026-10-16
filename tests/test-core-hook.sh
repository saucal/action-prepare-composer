#!/usr/bin/env bash
# handle-wp-core-update.sh against a fake SSH layer: never updates a host-managed core, and
# keeps today's behaviour where the SSH user can write core.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/../handle-wp-core-update.sh"
fail=0

# run_case <name> <writable yes|no> <remote> <to> <from> <consistency> <dry_run> <want_exit> <want_update yes|no>
run_case() {
  local name="$1" writable="$2" remote="$3" to="$4" from="$5" cc="$6" dry="$7" want_exit="$8" want_update="$9"
  local tmp; tmp="$(mktemp -d)"
  echo "$to" > "$tmp/core-version-composer-to"
  [ -n "$from" ] && echo "$from" > "$tmp/core-version-composer-from"
  cat > "$tmp/fake-ssh" <<FAKE
#!/usr/bin/env bash
case "\$1" in
  *"wp core update"*) echo "\$1" >> "$tmp/updates"; exit 0 ;;
  *"wp-includes/version.php"*) [ "$writable" = yes ] && echo writable || echo managed ;;
  *"wp core version"*) echo "$remote" ;;
  *) exit 0 ;;
esac
FAKE
  chmod +x "$tmp/fake-ssh"
  out="$(RUNNER_TEMP="$tmp" SSH_COMMAND="$tmp/fake-ssh" REMOTE_ROOT=/srv CONSISTENCY_CHECK="$cc" DRY_RUN="$dry" GITHUB_WORKSPACE="$tmp" PATH_DIR=. bash "$HOOK" 2>&1)"
  code=$?
  updated=no; [ -s "$tmp/updates" ] && updated=yes
  if [ "$code" = "$want_exit" ] && [ "$updated" = "$want_update" ]; then echo "ok   - $name"
  else echo "FAIL - $name (exit $code, updated $updated)"; echo "$out" | sed 's/^/       /'; fail=1; fi
  if [ "$writable" = no ]; then
    [ -f "$tmp/core-managed-by-host" ] || { echo "FAIL - $name: core-managed-by-host not recorded"; fail=1; }
    [ "$to" != "$remote" ] && ! grep -q "::warning" <<< "$out" && { echo "FAIL - $name: no out-of-sync warning"; fail=1; }
  fi
  rm -rf "$tmp"
}

run_case "managed core, deploy, versions differ: warn, never update" no 7.1.3 7.1.4 7.1.3 true false 0 no
run_case "managed core, dry run, versions differ: warn, do not fail" no 7.1.3 7.1.4 7.1.3 true true 0 no
run_case "managed core, in sync: quiet success" no 7.1.3 7.1.3 7.1.3 true true 0 no
run_case "writable core, deploy: updates as before" yes 7.1.3 7.1.4 7.1.3 true false 0 yes
run_case "writable core, dry run, versions differ: fail, never update" yes 7.1.3 7.1.4 7.1.3 true true 1 no
exit $fail
