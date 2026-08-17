#!/usr/bin/env bash
# Blocks publication of denylisted strings.
#
# The denylist contains exactly the strings that must never be published, so it
# is deliberately NOT stored in this repository. Point ASBG_DENYLIST at it, or
# place it at ~/.config/asbg/denylist.txt. See tools/denylist.example.txt for
# the format.
#
# Usage: privacy-check.sh [PATH...]
#   With paths: scans those paths.
#   Without:    scans every git-tracked file, minus tools/privacy-check.ignore.
# Exit: 0 clean, 1 denylist hit, 2 denylist unavailable.
set -uo pipefail

DENYLIST="${ASBG_DENYLIST:-$HOME/.config/asbg/denylist.txt}"

if [[ ! -r "$DENYLIST" ]]; then
  echo "privacy-check: denylist not readable at $DENYLIST" >&2
  echo "privacy-check: create it or set ASBG_DENYLIST; see tools/denylist.example.txt" >&2
  exit 2
fi

files=()
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  root="$(git rev-parse --show-toplevel)" || exit 2
  cd "$root" || exit 2
  ignore="tools/privacy-check.ignore"
  prefixes=()
  if [[ -r "$ignore" ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -n "$line" ]] && prefixes+=("$line")
    done < "$ignore"
  fi
  while IFS= read -r f; do
    skip=0
    for p in ${prefixes[@]+"${prefixes[@]}"}; do
      if [[ "$f" == "$p"* ]]; then skip=1; break; fi
    done
    [[ $skip -eq 0 ]] && files+=("$f")
  done < <(git ls-files)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "privacy-check: no files to scan"
  exit 0
fi

# Word-boundary syntax differs between greps: GNU uses \b, BSD uses [[:<:]], and
# a given machine may have either behind the name `grep` (ugrep, for one, accepts
# \b but not [[:<:]]). Each candidate is proven by a positive and a negative
# probe before use. If neither can be proven, fall back to substring matching:
# over-matching costs a false positive, while under-matching would let a
# denylisted term through silently, and this is a safety gate.
detect_boundary_style() {
  if grep -qE '\bword\b' <<< 'a word here' 2>/dev/null \
     && ! grep -qE '\bword\b' <<< 'a wordy here' 2>/dev/null; then
    echo gnu; return
  fi
  if grep -qE '[[:<:]]word[[:>:]]' <<< 'a word here' 2>/dev/null \
     && ! grep -qE '[[:<:]]word[[:>:]]' <<< 'a wordy here' 2>/dev/null; then
    echo bsd; return
  fi
  echo none
}

BOUNDARY_STYLE="$(detect_boundary_style)"
if [[ "$BOUNDARY_STYLE" == none ]]; then
  echo "privacy-check: this grep has no provable word-boundary support; matching substrings instead (expect false positives)" >&2
fi

boundary_pattern() {
  case "$BOUNDARY_STYLE" in
    gnu)  printf '\\b%s\\b' "$1" ;;
    bsd)  printf '[[:<:]]%s[[:>:]]' "$1" ;;
    *)    printf '%s' "$1" ;;
  esac
}

# The denylist holds two kinds of line: deny rules (plain text or `re:`),
# which trigger a block, and `ok:` allow rules, which suppress specific
# substrings within a `re:` hit. Both are collected in one pass, before any
# scanning starts, so their order in the file does not matter.
deny_rules=()
ok_rules=()
while IFS= read -r rule || [[ -n "$rule" ]]; do
  rule="${rule#"${rule%%[![:space:]]*}"}"
  rule="${rule%"${rule##*[![:space:]]}"}"
  [[ -z "$rule" || "$rule" == \#* ]] && continue
  if [[ "$rule" == ok:* ]]; then
    ok_rules+=("${rule#ok:}")
  else
    deny_rules+=("$rule")
  fi
done < "$DENYLIST"

# strip_allowed blanks every ok: match out of a line of grep-hit content, so
# the same re: pattern can be re-tested against what remains.
#
# Three properties are load-bearing here, not incidental:
#   1. Allow rules apply only to `re:` deny rules, never to plain-name rules.
#      A denylisted name embedded in an address (name@example.com) must still
#      be blocked, and the name rule is what blocks it — widening ok: to
#      cover name rules would open exactly that hole.
#   2. Matching is token-granular, not line-granular: an allow match is
#      blanked out of the line and the same re: pattern is re-tested against
#      the remainder, so a second, non-allowed address on the same line as
#      an allowed one is still caught (see the "token-granular" test case).
#   3. Deny and allow rules are read in a single pass before scanning begins,
#      so file order between them never matters.
# $'\037' (unit separator) is used as the sed delimiter so an ok: pattern
# containing `/` or `|` cannot break the substitution.
strip_allowed() {
  local content; content="$(cat)"
  local ok
  for ok in ${ok_rules[@]+"${ok_rules[@]}"}; do
    content="$(printf '%s' "$content" | sed -E "s"$'\037'"${ok}"$'\037'" "$'\037'"g")"
  done
  printf '%s' "$content"
}

status=0
rules=0
for rule in ${deny_rules[@]+"${deny_rules[@]}"}; do
  rules=$((rules + 1))
  if [[ "$rule" == re:* ]]; then
    pattern="${rule#re:}"
    # -H forces the path:lineno:content format even when only one file is
    # scanned; grep otherwise omits the path prefix for a single-file input,
    # which the field split below relies on.
    if hits="$(grep -InEHi -- "$pattern" "${files[@]}" 2>/dev/null)"; then
      real_hits=""
      while IFS= read -r hitline; do
        [[ -z "$hitline" ]] && continue
        content="$(cut -d: -f3- <<< "$hitline")"
        remaining="$(printf '%s' "$content" | strip_allowed)"
        if grep -qEi -- "$pattern" <<< "$remaining" 2>/dev/null; then
          real_hits+="${hitline}"$'\n'
        fi
      done <<< "$hits"
      real_hits="${real_hits%$'\n'}"
      if [[ -n "$real_hits" ]]; then
        echo "privacy-check: BLOCKED by rule '${rule}'" >&2
        printf '%s\n' "$real_hits" | head -20 >&2
        status=1
      fi
    fi
  else
    pattern="$(boundary_pattern "$rule")"
    if hits="$(grep -InEi -- "$pattern" "${files[@]}" 2>/dev/null)"; then
      echo "privacy-check: BLOCKED by rule '${rule}'" >&2
      printf '%s\n' "$hits" | head -20 >&2
      status=1
    fi
  fi
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "privacy-check: blocked. Remove the content, or narrow the rule if it is a false positive." >&2
  exit 1
fi

echo "privacy-check: clean (${#files[@]} files, $rules rules)"
