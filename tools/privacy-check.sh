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
# Exit: 0 clean, 1 denylist hit, 2 denylist unavailable or unusable.
#
# Known limitations:
#   - Allow-rule (ok:) matching is case-sensitive while deny-rule matching is
#     case-insensitive, so an ok: rule written in one case will not suppress
#     a hit that only differs in case. This fails safe (it can over-block,
#     never silently allow), and the fix — a case-insensitive substitution
#     flag on sed — does not exist in the sed shipped on macOS.
#   - Scanning is line-oriented: a denylisted term split across a line break
#     is not detected.
set -uo pipefail

DENYLIST="${ASBG_DENYLIST:-$HOME/.config/asbg/denylist.txt}"

if [[ ! -r "$DENYLIST" ]]; then
  echo "privacy-check: denylist not readable at $DENYLIST" >&2
  echo "privacy-check: create it or set ASBG_DENYLIST; see tools/denylist.example.txt" >&2
  exit 2
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

boundary_pattern() {
  case "$BOUNDARY_STYLE" in
    gnu)  printf '\\b%s\\b' "$1" ;;
    bsd)  printf '[[:<:]]%s[[:>:]]' "$1" ;;
    *)    printf '%s' "$1" ;;
  esac
}

# A NUL byte anywhere in a file marks it as binary; everything else is text —
# but a file this process cannot read has no content to classify either way,
# and reporting one anyway is the same shape of mistake as two other bugs
# found in this scanner (see docs/material/failure-modes-observed.md,
# entries 6 and 7): an I/O failure quietly folded into a result that looks
# like success. A classifier with no opinion must say so, not guess "text"
# and let whatever runs next inherit the blind spot. So unreadable files
# (wrong permissions, a broken symlink, an unmounted path) are a hard stop
# right here, before either scan branch runs, rather than a silent default.
#
# `od` emits one two-digit hex token per byte; squeezing whitespace onto its
# own lines and requiring an exact "00" line rules out false positives from
# adjacent hex digits belonging to two different non-zero bytes.
is_binary() {
  if [[ ! -r "$1" ]]; then
    echo "privacy-check: cannot read ${1} to classify it (permissions, a broken symlink, or a missing file)" >&2
    exit 2
  fi
  od -An -tx1 -- "$1" 2>/dev/null | tr -s ' \n' '\n' | grep -qx '00'
}

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
#
# Every ok: rule is proven to compile under this exact sed invocation at
# startup (see validate_rules), but the check here is kept anyway: a rule can
# be valid for grep -E and still break sed -E, and defence in depth means
# this path fails closed even if the startup probe is ever bypassed.
strip_allowed() {
  local content; content="$(cat)"
  local ok out
  for ok in ${ok_rules[@]+"${ok_rules[@]}"}; do
    if ! out="$(printf '%s' "$content" | sed -E "s"$'\037'"${ok}"$'\037'" "$'\037'"g" 2>/dev/null)"; then
      echo "privacy-check: ok: rule broke sed at scan time: '${ok}'" >&2
      exit 2
    fi
    content="$out"
  done
  printf '%s' "$content"
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

# Two fixed canary sentences, deliberately different in vocabulary, used to
# reject an ok: rule that overmatches. Not randomised: the check must give
# the same answer on every run, or an operator cannot reproduce a rejection.
readonly CANARY_A='zzz canary line with no secrets zzz'
readonly CANARY_B='another distinct probe about ordinary matters'

# An allow rule is meant to excise a single token from a line, not gut it.
# Whether a rule merely *matches* a canary cannot tell a word-bounded rule
# (legitimate; removes a token) from `.*` (removes everything) — both match.
# What distinguishes them is how much of the line disappears, so the rule is
# applied to each canary exactly as strip_allowed would, and rejected only if
# it strips away more than half of one. Half, not some smaller fraction: a
# rule that excises one real word out of a short sentence can reasonably
# remove a third or more of it, and rejecting on presence-of-any-word-match
# is exactly the bug this constant replaces (an operator's correct,
# narrowly-scoped rule refused only because it happened to share vocabulary
# with the canary text — as fatal as a bypass, from the other direction).
readonly ALLOW_RULE_MAX_STRIP_FRACTION_DENOM=2

# The denylist is validated once, in full, before any file is scanned. Every
# failure here exits 2 ("denylist unusable") rather than 1 ("hit found") or
# 0 ("clean"): an unusable rule set is not the same as a clean scan, and
# treating it as clean is exactly how a single typo silently disables the
# gate.
validate_rules() {
  if [[ ${#deny_rules[@]} -eq 0 ]]; then
    echo "privacy-check: denylist contains no deny rules (only comments, blank lines, or ok: rules)" >&2
    exit 2
  fi

  local pat rc
  for pat in "${deny_rules[@]}"; do
    [[ "$pat" == re:* ]] || continue
    pat="${pat#re:}"
    grep -qE -- "$pat" </dev/null 2>/dev/null
    rc=$?
    if [[ $rc -gt 1 ]]; then
      echo "privacy-check: malformed re: rule, does not compile: '${pat}'" >&2
      exit 2
    fi
  done

  local ok
  for ok in ${ok_rules[@]+"${ok_rules[@]}"}; do
    grep -qE -- "$ok" </dev/null 2>/dev/null
    rc=$?
    if [[ $rc -gt 1 ]]; then
      echo "privacy-check: malformed ok: rule, does not compile as a regex: '${ok}'" >&2
      exit 2
    fi

    if ! printf '' | sed -E "s"$'\037'"${ok}"$'\037'" "$'\037'"g" >/dev/null 2>&1; then
      echo "privacy-check: malformed ok: rule, breaks the sed substitution used at scan time: '${ok}'" >&2
      exit 2
    fi

    if printf '\n' | grep -qE -- "$ok" 2>/dev/null; then
      echo "privacy-check: ok: rule matches the empty string, rejected: '${ok}'" >&2
      exit 2
    fi

    local canary orig_len stripped remaining_len removed
    for canary in "$CANARY_A" "$CANARY_B"; do
      orig_len=${#canary}
      stripped="$(printf '%s' "$canary" | sed -E "s"$'\037'"${ok}"$'\037'" "$'\037'"g" 2>/dev/null)"
      remaining_len=${#stripped}
      removed=$(( orig_len - remaining_len ))
      if (( removed * ALLOW_RULE_MAX_STRIP_FRACTION_DENOM > orig_len )); then
        echo "privacy-check: ok: rule strips more than half of a canary line, rejected as an overmatch risk: '${ok}'" >&2
        exit 2
      fi
    done
  done
}

BOUNDARY_STYLE="$(detect_boundary_style)"
if [[ "$BOUNDARY_STYLE" == none ]]; then
  echo "privacy-check: this grep has no provable word-boundary support; matching substrings instead (expect false positives)" >&2
fi

validate_rules

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
      [[ -n "$line" ]] || continue
      # An ignore entry must be unambiguous: either a directory prefix
      # (trailing slash) or an exact, existing file. An entry without a
      # trailing slash that names a nonexistent path would silently
      # over-match any sibling path sharing that prefix (e.g. `v1` would
      # also exempt `v1-old/`).
      if [[ "$line" != */ && ! -f "$line" ]]; then
        echo "privacy-check: invalid entry in $ignore: '${line}' (must end in / or name an existing file)" >&2
        exit 2
      fi
      prefixes+=("$line")
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

text_files=()
binary_files=()
for f in "${files[@]}"; do
  if is_binary "$f"; then
    binary_files+=("$f")
  else
    text_files+=("$f")
  fi
done

# Scanning is per-file, per-rule, on purpose:
#   - Binary files (C1) are matched with grep -a (never -I, which would treat
#     them as an automatic non-match) so a denylisted term in, say, image
#     metadata is still caught. Only a presence check is done on them —
#     their content is never printed to the report.
#   - Text files are matched one file at a time, rather than batching every
#     file into a single grep call. grep only prints a path prefix when
#     scanning multiple files at once, so batching would recreate the exact
#     "path:lineno:content" field-splitting fragility this design avoids
#     (unambiguous on a path that itself contains a colon): scanning one file
#     at a time means the path is already known from the loop variable, and
#     grep's un-prefixed "lineno:content" output only ever needs one split.
# scan_grep_rc treats grep's own error exit (2: malformed pattern, unreadable
# file, etc.) as a hard stop, distinct from "no match" (1) and "match" (0).
# validate_rules already proves every deny and allow pattern compiles before
# any file is scanned, so this should never fire — it exists as defence in
# depth, on the same principle as strip_allowed's sed exit-status check: a
# pattern that compiles standalone can still fail in a context validate_rules
# did not anticipate, and folding that failure into "no match" is exactly how
# a rule silently stops firing while the scan reports clean.
scan_grep_rc() {
  local rc="$1" rule="$2" f="$3"
  if [[ $rc -eq 2 ]]; then
    echo "privacy-check: rule '${rule}' failed to scan ${f} (grep reported an error, not just no match)" >&2
    exit 2
  fi
}

status=0
rules=0
for rule in "${deny_rules[@]}"; do
  rules=$((rules + 1))
  if [[ "$rule" == re:* ]]; then
    pattern="${rule#re:}"
  else
    pattern="$(boundary_pattern "$rule")"
  fi

  for f in ${binary_files[@]+"${binary_files[@]}"}; do
    grep -aqE -- "$pattern" "$f" 2>/dev/null
    rc=$?
    scan_grep_rc "$rc" "$rule" "$f"
    if [[ $rc -eq 0 ]]; then
      echo "privacy-check: BLOCKED by rule '${rule}'" >&2
      echo "${f}: binary file matches rule '${rule}'" >&2
      status=1
    fi
  done

  for f in ${text_files[@]+"${text_files[@]}"}; do
    hits="$(grep -nEi -- "$pattern" "$f" 2>/dev/null)"
    rc=$?
    scan_grep_rc "$rc" "$rule" "$f"
    if [[ $rc -eq 0 ]]; then
      if [[ "$rule" == re:* ]]; then
        real_hits=""
        while IFS= read -r hitline; do
          [[ -z "$hitline" ]] && continue
          content="${hitline#*:}"
          remaining="$(printf '%s' "$content" | strip_allowed)"
          grep -qEi -- "$pattern" <<< "$remaining" 2>/dev/null
          retest_rc=$?
          scan_grep_rc "$retest_rc" "$rule" "$f"
          if [[ $retest_rc -eq 0 ]]; then
            real_hits+="${f}:${hitline}"$'\n'
          fi
        done <<< "$hits"
        real_hits="${real_hits%$'\n'}"
        if [[ -n "$real_hits" ]]; then
          echo "privacy-check: BLOCKED by rule '${rule}'" >&2
          printf '%s\n' "$real_hits" | head -20 >&2
          status=1
        fi
      else
        display_hits=""
        while IFS= read -r hitline; do
          [[ -z "$hitline" ]] && continue
          display_hits+="${f}:${hitline}"$'\n'
        done <<< "$hits"
        display_hits="${display_hits%$'\n'}"
        echo "privacy-check: BLOCKED by rule '${rule}'" >&2
        printf '%s\n' "$display_hits" | head -20 >&2
        status=1
      fi
    fi
  done
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "privacy-check: blocked. Remove the content, or narrow the rule if it is a false positive." >&2
  exit 1
fi

echo "privacy-check: clean (${#files[@]} files, $rules rules)"
