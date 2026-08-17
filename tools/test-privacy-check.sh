#!/usr/bin/env bash
# Tests for privacy-check.sh. Run from anywhere: bash tools/test-privacy-check.sh
#
# Content here is never obfuscated to get past the checker: fixtures either
# use a synthetic pattern declared in their own throwaway denylist, or they
# use plain prose the checker is expected to pass. If the live denylist ever
# objects to a line in this file, the fix is to change the content or the
# live rule — never to hide the literal from the scanner.
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

check_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok   - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name (expected output to mention '$needle')"
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

# A synthetic, non-word pattern stands in for any structural re: rule (an
# email address, an IP, whatever a real denylist declares). LEAKTOKEN-nnn
# matches nothing a real denylist would ever match, so it never needs a
# corresponding ok: rule on the live list, and the test's own throwaway
# denylist is the only place the pattern needs to exist.
printf 're:LEAKTOKEN-[0-9]{3}\n' > "$TMP/regex-denylist.txt"
printf 'Contact support about LEAKTOKEN-123 today.\n' > "$TMP/leak.md"
ASBG_DENYLIST="$TMP/regex-denylist.txt" bash "$CHECK" "$TMP/leak.md" >/dev/null 2>&1
check "re: rules are treated as regex" 1 $?

printf 're:LEAKTOKEN-[0-9]{3}\nok:LEAKTOKEN-000\n' > "$TMP/ok-denylist.txt"

printf 'Reference LEAKTOKEN-000 in this changelog entry.\n' > "$TMP/ok-covered.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-covered.md" >/dev/null 2>&1
check "ok: rule allows a matching re: hit" 0 $?

printf 'Reference LEAKTOKEN-123 in this changelog entry.\n' > "$TMP/ok-not-covered.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-not-covered.md" >/dev/null 2>&1
check "re: hit with no ok: match is still blocked" 1 $?

printf 'LEAKTOKEN-000 and LEAKTOKEN-123 both appear here.\n' > "$TMP/ok-mixed.md"
ASBG_DENYLIST="$TMP/ok-denylist.txt" bash "$CHECK" "$TMP/ok-mixed.md" >/dev/null 2>&1
check "ok: matching is token-granular, not line-granular" 1 $?

printf 'acme-real-name\nok:acme-real-name-LEAKTOKEN\n' > "$TMP/name-ok-denylist.txt"
printf 'Contact acme-real-name-LEAKTOKEN for details.\n' > "$TMP/name-ok.md"
ASBG_DENYLIST="$TMP/name-ok-denylist.txt" bash "$CHECK" "$TMP/name-ok.md" >/dev/null 2>&1
check "ok: rules never suppress a plain-name rule hit" 1 $?

# --- Binary files -----------------------------------------------------
# printf writes raw bytes straight to the file, so the embedded \x00 lands
# in the file even though a NUL truncates any shell variable that touches it.
printf 'acme-forbidden-term\x00trailer\n' > "$TMP/dirty.bin"
ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/dirty.bin" >/dev/null 2>&1
check "binary file with a denylisted term is blocked" 1 $?

printf 'nothing\x00to\x00see\x00here\n' > "$TMP/clean.bin"
ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/clean.bin" >/dev/null 2>&1
check "binary file without a denylisted term passes" 0 $?

# --- Denylist validation -----------------------------------------------
printf 'acme-forbidden-term\nok:(unbalanced[paren\n' > "$TMP/malformed-ok-denylist.txt"
out="$(ASBG_DENYLIST="$TMP/malformed-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" 2>&1)"
rc=$?
check "malformed ok: rule fails closed at startup" 2 "$rc"
check_contains "malformed ok: rule message names the offending rule" "$out" '(unbalanced[paren'

printf 'acme-forbidden-term\nok:.*\n' > "$TMP/overmatch-ok-denylist.txt"
ASBG_DENYLIST="$TMP/overmatch-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "an ok: rule matching ordinary prose is rejected" 2 $?

printf '# just a comment\n\n' > "$TMP/empty-denylist.txt"
ASBG_DENYLIST="$TMP/empty-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "a comment-only denylist fails closed" 2 $?

# --- Path edge cases -----------------------------------------------------
colon_file="$TMP/weird:name.md"
printf 'Contact support about LEAKTOKEN-123 today.\n' > "$colon_file"
ASBG_DENYLIST="$TMP/regex-denylist.txt" bash "$CHECK" "$colon_file" >/dev/null 2>&1
check "re: hit is detected in a path containing a colon" 1 $?

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
