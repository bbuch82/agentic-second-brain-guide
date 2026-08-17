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

# --- Files the scanner cannot read ---------------------------------------
# These exercise the scan-time grep-exit-status check (scan_grep_rc): the
# file exists and passes classification, but grep itself cannot open it, and
# that failure (exit 2) must be a hard stop rather than "no match" (exit 1).
printf 'acme-forbidden-term inside\n' > "$TMP/unreadable.md"
chmod 000 "$TMP/unreadable.md"
ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/unreadable.md" >/dev/null 2>&1
unreadable_rc=$?
chmod 644 "$TMP/unreadable.md"
check "an unreadable file (mode 000) fails closed, not silently clean" 2 "$unreadable_rc"

ln -s "$TMP/does-not-exist-target" "$TMP/dangling.md"
ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/dangling.md" >/dev/null 2>&1
check "a dangling symlink fails closed, not silently clean" 2 $?

# --- Denylist validation -----------------------------------------------
printf 're:(unbalanced[paren\n' > "$TMP/malformed-deny-denylist.txt"
printf 'this line contains (unbalanced[paren as a literal substring\n' > "$TMP/malformed-deny.md"
ASBG_DENYLIST="$TMP/malformed-deny-denylist.txt" bash "$CHECK" "$TMP/malformed-deny.md" >/dev/null 2>&1
check "a malformed deny re: rule fails closed, not silently clean" 2 $?

printf 'acme-forbidden-term\nok:(unbalanced[paren\n' > "$TMP/malformed-ok-denylist.txt"
out="$(ASBG_DENYLIST="$TMP/malformed-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" 2>&1)"
rc=$?
check "malformed ok: rule fails closed at startup" 2 "$rc"
check_contains "malformed ok: rule message names the offending rule" "$out" '(unbalanced[paren'

printf 'acme-forbidden-term\nok:.*\n' > "$TMP/overmatch-ok-denylist.txt"
ASBG_DENYLIST="$TMP/overmatch-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "an ok: rule matching everything (.*) is still rejected" 2 $?

printf 'acme-forbidden-term\nok:x*\n' > "$TMP/empty-match-ok-denylist.txt"
ASBG_DENYLIST="$TMP/empty-match-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "an ok: rule matching the empty string is rejected" 2 $?

# A single word-bounded token is a legitimate allow-rule shape — exactly what
# an operator writes to suppress a deny rule that is too eager on a short
# word. It happens to share a word ("no") with one of the two fixed canary
# sentences privacy-check.sh checks allow rules against, but removing two
# characters out of ~35 is nothing like `.*` removing the whole line, so it
# must be accepted, not rejected for merely matching some canary text.
# %s, not the format string, carries the rule text: printf's format string
# interprets \b as a literal backspace byte, which would silently corrupt
# this word-boundary pattern into something that matches nothing at all.
printf '%s\n' 're:LEAKTOKEN-[0-9]{3}' 'ok:\bno\b' > "$TMP/word-scoped-ok-denylist.txt"
ASBG_DENYLIST="$TMP/word-scoped-ok-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "a narrow word-scoped ok: rule is accepted, not rejected as overmatch" 0 $?

printf 'no mention of LEAKTOKEN-123 here\n' > "$TMP/word-scoped-hit.md"
ASBG_DENYLIST="$TMP/word-scoped-ok-denylist.txt" bash "$CHECK" "$TMP/word-scoped-hit.md" >/dev/null 2>&1
check "the scan still behaves normally after accepting a word-scoped ok: rule" 1 $?

# These two pin the exact threshold against privacy-check.sh's first fixed
# canary, "zzz canary line with no secrets zzz" (35 characters): stripping
# its first 18 characters leaves 18, removing 17 (just under half, kept);
# stripping its first 19 characters leaves 17, removing 18 (just over half,
# rejected). A later change to the threshold, or to the canary text, must
# change one of these two literals for the test to keep meaning what it says.
printf 'acme-forbidden-term\nok:zzz canary line wi\n' > "$TMP/just-under-half-denylist.txt"
ASBG_DENYLIST="$TMP/just-under-half-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "an ok: rule removing just under half a canary is accepted" 0 $?

printf 'acme-forbidden-term\nok:zzz canary line wit\n' > "$TMP/just-over-half-denylist.txt"
ASBG_DENYLIST="$TMP/just-over-half-denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "an ok: rule removing just over half a canary is rejected" 2 $?

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
