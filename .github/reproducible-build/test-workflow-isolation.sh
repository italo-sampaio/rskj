#!/usr/bin/env bash
#
# Regression test for the privilege split between the two reproducible-build
# workflows. Asserts — by static inspection — the security invariants that the
# split exists to guarantee:
#
#   build half  (reproducible-build.yml)    : contents:read, NO secrets, NO tokens
#   PR half     (reproducible-build-pr.yml) : secrets/write isolated to open-pr,
#                                             open-only (never auto-merge),
#                                             only first-party actions, GA-only,
#                                             App token scoped to reproducible-builds
#
# Run from anywhere:  .github/reproducible-build/test-workflow-isolation.sh
# Exits non-zero on the first violated invariant.

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
build_src="$repo_root/.github/workflows/reproducible-build.yml"
prw_src="$repo_root/.github/workflows/reproducible-build-pr.yml"

for f in "$build_src" "$prw_src"; do
  [ -f "$f" ] || { echo "FAIL  missing workflow: $f"; exit 1; }
done

# Assert against a comment-stripped view so a literal like `contents: write`
# inside an explanatory comment can't trip (or mask) an invariant. None of the
# patterns below need a '#', so dropping everything from the first '#' is safe.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
build="$tmp/build.yml"; prw="$tmp/prw.yml"
sed 's/#.*$//' "$build_src" > "$build"
sed 's/#.*$//' "$prw_src"   > "$prw"

fail=0
pass() { printf '  ok  %s\n' "$1"; }
err()  { printf 'FAIL  %s\n' "$1"; fail=1; }

# assert that a grep -E pattern IS present in a file
want() { if grep -Eq "$2" "$1"; then pass "$3"; else err "$3"; fi; }
# assert that a grep -E pattern is ABSENT from a file
deny() { if grep -Eq "$2" "$1"; then err "$3"; else pass "$3"; fi; }

echo "== build half stays clean (reproducible-build.yml) =="
# Top-level permissions are read-only and no secrets/tokens appear anywhere.
want "$build" '^permissions:[[:space:]]*$' "build: declares a permissions block"
want "$build" '^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$' "build: contents: read"
deny "$build" 'contents:[[:space:]]*write' "build: never grants contents: write"
deny "$build" '^[[:space:]]*secrets:' "build: declares no secrets"
deny "$build" 'secrets\.GH_APP' "build: references no App-token secrets"
deny "$build" 'create-github-app-token' "build: mints no App token"

echo "== PR half: secrets/write live ONLY in open-pr (reproducible-build-pr.yml) =="
want "$prw" '^permissions:[[:space:]]*$' "pr: declares a permissions block"
want "$prw" '^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$' "pr: top-level contents: read"
deny "$prw" 'contents:[[:space:]]*write' "pr: never grants contents: write (open-only)"
# The build job must NOT forward secrets to the reusable build workflow.
deny "$prw" '^[[:space:]]*secrets:' "pr: passes no secrets into the build half"

echo "== PR half: open-only, never auto-merge =="
deny "$prw" 'gh pr merge|--auto|--merge\b|merge_pull_request|--admin' "pr: contains no auto-merge"

echo "== PR half: first-party actions only =="
# Every `uses:` must be actions/* or the blessed create-github-app-token. Any
# third-party action (e.g. peter-evans/create-pull-request) is a regression.
bad_uses=$(grep -E '^[[:space:]]*-?[[:space:]]*uses:' "$prw" \
  | grep -vE 'uses:[[:space:]]*\./' \
  | grep -vE 'uses:[[:space:]]*actions/' \
  | grep -vE 'uses:[[:space:]]*actions/create-github-app-token@' || true)
if [ -n "$bad_uses" ]; then
  err "pr: only first-party actions in uses:"
  printf '      offending: %s\n' "$bad_uses"
else
  pass "pr: only first-party actions in uses:"
fi

echo "== PR half: App token pinned + scoped to reproducible-builds =="
want "$prw" 'create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1' "pr: App token pinned to v3.2.0 SHA"
want "$prw" 'repositories:[[:space:]]*reproducible-builds' "pr: App token scoped to reproducible-builds"

echo "== PR half: GA-only guard present =="
want "$prw" '\^\[A-Z\]\+-\[0-9\]\+' "pr: GA tag regex guard present"
want "$prw" 'PREVIEW|TESTNET' "pr: pre-release deny-list present"

echo "== PR half: fail-loud on an existing release dir =="
want "$prw" 'refusing to overwrite' "pr: refuses to overwrite a published dir"

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL — workflow isolation invariants violated"
  exit 1
fi
echo "RESULT: PASS — reproducible-build workflow isolation holds"
