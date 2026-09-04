#!/usr/bin/env bash
# test.sh, the regression suite.
#
# Runs the summoning many times against throwaway home directories and checks
# what it wrote. Nothing on your machine is touched. Exits non-zero if any
# assertion fails, so it is safe to wire into CI.
#
#   bash test.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUMMON="$SCRIPT_DIR/summon.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/summoning-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'

ck() { # expected, actual, label
  if [ "$1" = "$2" ]; then
    PASS=$((PASS + 1)); printf '  %sok%s   %s\n' "$GREEN" "$RESET" "$3"
  else
    FAIL=$((FAIL + 1)); printf '  %sFAIL%s %s\n        expected [%s] got [%s]\n' \
      "$RED" "$RESET" "$3" "$1" "$2"
  fi
}

# A sandbox home. Any agent names given become detectable config folders.
new_home() {
  local sb; sb="$WORK/home.$RANDOM$RANDOM"
  mkdir -p "$sb"
  local a
  for a in "$@"; do
    case "$a" in
      claude) mkdir -p "$sb/.claude" ;;
      codex) mkdir -p "$sb/.codex" ;;
      gemini) mkdir -p "$sb/.gemini" ;;
      opencode) mkdir -p "$sb/.config/opencode" ;;
    esac
  done
  printf '%s' "$sb"
}

# Run the summoning with the given answers. env -i keeps the host's installed
# agents from being detected, so each test controls its own world.
summon() { # home, answers
  printf '%b' "$2" | env -i HOME="$1" PATH="/usr/bin:/bin" TERM=dumb \
    bash "$SUMMON" > "$1/summon.log" 2>&1
}

memdir() { printf '%s/.claude/projects/%s/memory' "$1" "$(printf '%s' "$1" | tr '/' '-')"; }

ANS='Fern\na stone fox that keeps watch\nwarm, dry\nterse\n@\nfriend\nmentor\nI get overwhelmed by jargon.\n'

echo
echo "the harness itself"
_p=$PASS; _f=$FAIL
ck "a" "b" "a deliberately failing assertion (this FAIL is expected)"
if [ "$FAIL" -eq $((_f + 1)) ]; then
  FAIL=$_f; PASS=$((_p + 1))
  printf '  %sok%s   the harness can report failure, so its passes mean something\n' "$GREEN" "$RESET"
else
  echo "  the harness cannot fail; every result below is meaningless"; exit 1
fi

echo
echo "the three figure doors"
for mode in 1 2 3; do
  H=$(new_home claude)
  if [ "$mode" = 2 ]; then summon "$H" "$ANS$mode\n  (o_o) {{NAME}}\n\n"
  else summon "$H" "$ANS$mode\n\n"; fi
  ck "0" "$?" "mode $mode completes"
  ck "y" "$(test -f "$H/.claude/CLAUDE.md" && echo y)" "mode $mode writes a persona"
  ck "y" "$(test -f "$H/.companion/figure.txt" && echo y)" "mode $mode writes the figure"
  ck "0" "$(grep -c '{{' "$H/.claude/CLAUDE.md" 2>/dev/null)" "mode $mode leaves no placeholders"
  env -i PATH="/usr/bin:/bin" bash -n "$H/.companion/companion.sh" 2>/dev/null
  ck "0" "$?" "mode $mode generates a parseable companion.sh"
done

echo
echo "the same answers always conjure the same form"
H1=$(new_home claude); summon "$H1" "$ANS""3\n\n"
H2=$(new_home claude); summon "$H2" "$ANS""3\n\n"
ck "$(grep -o 'Form: [a-z0-9-]*' "$H1/summon.log" | head -1)" \
   "$(grep -o 'Form: [a-z0-9-]*' "$H2/summon.log" | head -1)" "fate is deterministic"

echo
echo "it installs only where an agent actually lives"
H=$(new_home codex); summon "$H" "$ANS""1\n\n"
ck "1" "$(grep -c 'still Codex' "$H/.codex/AGENTS.md" 2>/dev/null)" "a Codex-only home names Codex"
ck "n" "$(test -f "$H/.claude/CLAUDE.md" && echo y || echo n)" "and gets no Claude Code files"
H=$(new_home claude gemini); summon "$H" "$ANS""1\n\n"
ck "1" "$(grep -c 'still Claude' "$H/.claude/CLAUDE.md" 2>/dev/null)" "Claude Code copy names Claude"
ck "1" "$(grep -c 'still Gemini' "$H/.gemini/GEMINI.md" 2>/dev/null)" "Gemini copy names Gemini"
H=$(new_home); summon "$H" "$ANS""1\n\n"
ck "y" "$(test -f "$H/.companion/AGENTS.md" && echo y)" "no agent found leaves a persona to point at"

echo
echo "it never destroys what was already there"
H=$(new_home claude)
printf '{"mcpServers":{"x":{"command":"npx"}},"model":"opus"}\n' > "$H/.claude/settings.json"
printf 'my instructions\n' > "$H/.claude/CLAUDE.md"
summon "$H" "$ANS""1\n\n"
ck "yes" "$(python3 -c "
import json;d=json.load(open('$H/.claude/settings.json'))
print('yes' if 'statusLine' in d and 'mcpServers' in d and d.get('model')=='opus' else 'no')")" \
  "settings.json is merged, not replaced"
ck "my instructions" "$(cat "$H/.companion/"backup-*/.claude_CLAUDE.md 2>/dev/null)" \
  "the previous persona is backed up"
ck "1" "$(grep -c 'previous files were saved' "$H/summon.log")" "the backup path is announced"

H=$(new_home claude)
printf '{"mcpServers":{"x":1},}\n' > "$H/.claude/settings.json"   # trailing comma
BEFORE=$(cat "$H/.claude/settings.json")
summon "$H" "$ANS""1\n\n"
ck "$BEFORE" "$(cat "$H/.claude/settings.json")" "an unreadable settings.json is left alone"

H=$(new_home); mkdir -p "$H/.companion"
printf 'hand written\n' > "$H/.companion/AGENTS.md"
summon "$H" "$ANS""1\n\n"
ck "hand written" "$(cat "$H/.companion/"backup-*/.companion_AGENTS.md 2>/dev/null)" \
  "the fallback persona is backed up too"

echo
echo "awkward answers do not break the ritual"
H=$(new_home claude); summon "$H" "O'Brien\nfox\nwarm\nterse\n@\nfriend\nmentor\nseed\n1\n\n"
ck "0" "$?" "an apostrophe in the name"
env -i PATH="/usr/bin:/bin" bash -n "$H/.companion/companion.sh" 2>/dev/null
ck "0" "$?" "  and the companion.sh it produces still parses"

H=$(new_home claude); summon "$H" 'AC/DC\nfox\nwarm\nterse\n@\nfriend\nmentor\nseed\n1\n\n'
ck "0" "$?" "a slash in the name"
ck "0" "$(grep -c '{{NAME}}' "$H/.companion/figure.txt" 2>/dev/null)" "  and the figure is substituted"

H=$(new_home claude); summon "$H" '100% Cocoa\nfox\nwarm\nterse\n@\nfriend\nmentor\nseed\n1\n\n'
OUT=$(env -i HOME="$H" PATH="/usr/bin:/bin" bash "$H/.companion/companion.sh" 2>&1)
ck "1" "$(printf '%s' "$OUT" | grep -c '100% Cocoa')" "a percent sign in the name survives"

H=$(new_home claude)
SEED=$(python3 -c "print('I am learning. ' + 'é'*60)")
summon "$H" "Fern\nfox\nwarm\nterse\n@\nfriend\nmentor\n$SEED\n1\n\n"
ck "0" "$?" "a long non-ASCII day-one seed"
ck "nonempty" "$(test -s "$(memdir "$H")/MEMORY.md" && echo nonempty || echo EMPTY)" \
  "  and MEMORY.md is not truncated"

H=$(new_home claude)
summon "$H" "Fern\nfox\nwarm\nterse\n@\nfriend\nmentor\nseed\n2\n  (o_o)\nFIGURE_EOF\n  tail\n\n"
OUT=$(env -i HOME="$H" PATH="/usr/bin:/bin" bash "$H/.companion/companion.sh" --greet 2>&1)
ck "0" "$(printf '%s' "$OUT" | grep -c 'command not found')" \
  "pasted art cannot escape into the shell"

echo
echo "the visible form behaves in any terminal"
H=$(new_home claude); summon "$H" "$ANS""1\n\n"
J='{"workspace":{"current_dir":"/tmp/demo"},"model":{"display_name":"Opus"}}'
ck "1" "$(printf '%s\n' "$J" | env -i HOME="$H" PATH="/usr/bin:/bin" bash "$H/.companion/companion.sh" | grep -c '/tmp/demo')" \
  "status line reads the JSON it is given"
ck "1" "$(printf '%s' "$J" | env -i HOME="$H" PATH="/usr/bin:/bin" bash "$H/.companion/companion.sh" | grep -c '/tmp/demo')" \
  "  even without a trailing newline"
( sleep 20 ) | env -i HOME="$H" PATH="/usr/bin:/bin" timeout 5 bash "$H/.companion/companion.sh" >/dev/null 2>&1
ck "0" "$?" "status line never hangs waiting for input"
env -i HOME="$H" PATH="/usr/bin:/bin" timeout 5 bash "$H/.companion/companion.sh" --greet >/dev/null 2>&1
ck "0" "$?" "--greet works on its own"

echo
echo "portability"
ck "0" "$(grep -vE '^[[:space:]]*#' "$SUMMON" | grep -c 'declare -A')" \
  "no declare -A (bash 3.2 on macOS has none)"
ck "0" "$(grep -vE '^[[:space:]]*#' "$SUMMON" | grep -cE 'mapfile|readarray|sed -i')" \
  "no bash 4 or GNU-only builtins"

echo
printf '  %s%d passed, %d failed%s\n\n' "$DIM" "$PASS" "$FAIL" "$RESET"
[ "$FAIL" -eq 0 ]
