#!/usr/bin/env bash
# Tests for privacy-check.sh. Run from anywhere: bash tools/test-privacy-check.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/privacy-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

printf 'acme-forbidden-term\n' > "$TMP/denylist.txt"
printf 'This line mentions acme-forbidden-term inline.\n' > "$TMP/dirty.md"
printf 'This line is entirely harmless.\n' > "$TMP/clean.md"
printf 'A term like acme-forbidden-termination should not match.\n' > "$TMP/boundary.md"

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "clean file passes" 0 $?

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/dirty.md" >/dev/null 2>&1
check "denylisted term is blocked" 1 $?

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/boundary.md" >/dev/null 2>&1
check "word boundary is respected" 0 $?

ASBG_DENYLIST="$TMP/does-not-exist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "missing denylist fails closed" 2 $?

printf 're:[a-z]+@[a-z]+\.[a-z]{2,}\n' > "$TMP/regex-denylist.txt"
printf 'Contact someone@example.org for details.\n' > "$TMP/email.md"
ASBG_DENYLIST="$TMP/regex-denylist.txt" bash "$CHECK" "$TMP/email.md" >/dev/null 2>&1
check "re: rules are treated as regex" 1 $?

printf 're:[a-zA-Z0-9._%%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\nok:[a-zA-Z0-9._%%+-]+@example\.(com|org|net)\n' > "$TMP/ok-denylist.txt"

printf 'Contact jane@example.com for details.\n' > "$TMP/ok-covered.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-covered.md" >/dev/null 2>&1
check "ok: rule allows a matching re: hit" 0 $?

# The "at" indirection below keeps a plausible, non-reserved-domain address
# out of this file's literal text: privacy-check.sh's own generic email rule
# would otherwise flag this source line every time the real repository is
# scanned, even though the address only ever exists in a throwaway temp file.
at="@"
printf 'Contact jane%sunreserved-domain.example.co for details.\n' "$at" > "$TMP/ok-not-covered.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-not-covered.md" >/dev/null 2>&1
check "re: hit with no ok: match is still blocked" 1 $?

printf 'jane%sexample.com person%sunreserved-domain.example.co\n' "$at" "$at" > "$TMP/ok-mixed.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-mixed.md" >/dev/null 2>&1
check "ok: matching is token-granular, not line-granular" 1 $?

printf 'acme-real-name\nok:acme-real-name@example\.com\n' > "$TMP/name-ok-denylist.txt"
printf 'Contact acme-real-name@example.com for details.\n' > "$TMP/name-ok.md"
ASBG_DENYLIST="$TMP/name-ok-denylist.txt" bash "$CHECK" "$TMP/name-ok.md" >/dev/null 2>&1
check "ok: rules never suppress a plain-name rule hit" 1 $?

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
