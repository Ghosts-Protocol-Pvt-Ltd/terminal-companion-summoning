#!/usr/bin/env bash
# try.sh, a rehearsal.
#
# Runs the real summoning against a throwaway home directory so you can see
# exactly what a new user sees, answer the eight questions yourself, and look
# at every file it creates. Your own ~/.claude, ~/.codex and ~/.gemini are
# never touched.
#
#   bash try.sh                      pretend every agent is installed
#   bash try.sh --agents claude      pretend only Claude Code is installed
#   bash try.sh --agents codex,gemini
#   bash try.sh --keep               do not delete the sandbox at the end
#   bash try.sh --quick              rehearse the short version

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PURPLE=$'\033[38;5;141m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

AGENTS="claude,codex,gemini,opencode"
KEEP=0
QUICK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agents) AGENTS="$2"; shift 2 ;;
    --agents=*) AGENTS="${1#*=}"; shift ;;
    --keep) KEEP=1; shift ;;
    --quick|-q) QUICK="--quick"; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/summoning-rehearsal.XXXXXX")"

cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    echo
    echo "${DIM}The sandbox was kept at:${RESET}"
    echo "${DIM}  $SANDBOX${RESET}"
    echo "${DIM}Delete it with: rm -rf '$SANDBOX'${RESET}"
  else
    rm -rf "$SANDBOX"
  fi
}
trap cleanup EXIT

# Create the config folders for whichever agents we are pretending to have.
# The summoning detects an agent by its folder, so this is what decides which
# installs you get to watch.
OLD_IFS="$IFS"; IFS=','
for a in $AGENTS; do
  case "$a" in
    claude)   mkdir -p "$SANDBOX/.claude" ;;
    codex)    mkdir -p "$SANDBOX/.codex" ;;
    gemini)   mkdir -p "$SANDBOX/.gemini" ;;
    opencode) mkdir -p "$SANDBOX/.config/opencode" ;;
    *) echo "unknown agent: $a (try claude, codex, gemini, opencode)" >&2; exit 1 ;;
  esac
done
IFS="$OLD_IFS"

# Give the pretend Claude Code a settings.json worth protecting, so you can
# see for yourself that the summoning merges instead of overwriting.
if [ -d "$SANDBOX/.claude" ]; then
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "mcpServers": { "example": { "command": "npx", "args": ["some-mcp"] } },
  "permissions": { "allow": ["Bash(npm test)"] }
}
JSON
  printf '# my existing instructions, which should survive as a backup\n' \
    > "$SANDBOX/.claude/CLAUDE.md"
fi

echo
echo "${PURPLE}~ A rehearsal ~${RESET}"
echo
echo "${DIM}This is the real summoning, running against a pretend home directory."
echo "Nothing on your machine is touched. Answer the questions as a new user"
echo "would, and everything it writes is shown to you afterwards.${RESET}"
echo
echo "${DIM}Pretending these agents are installed: $AGENTS${RESET}"
echo

HOME="$SANDBOX" bash "$SCRIPT_DIR/summon.sh" $QUICK

echo
echo "${PURPLE}================ what a new user just got ================${RESET}"
echo

echo "${BOLD}Every file it created${RESET}"
( cd "$SANDBOX" && find . -type f | sed 's|^\./|  ~/|' | sort )
echo

echo "${BOLD}The status line, exactly as Claude Code renders it${RESET}"
printf '  '
printf '{"workspace":{"current_dir":"%s/my-project"},"model":{"display_name":"Opus"}}' "$SANDBOX" \
  | HOME="$SANDBOX" bash "$SANDBOX/.companion/companion.sh"
echo
echo

echo "${BOLD}The greeting, in any other terminal${RESET}"
HOME="$SANDBOX" bash "$SANDBOX/.companion/companion.sh" --greet

if [ -f "$SANDBOX/.claude/settings.json" ]; then
  echo "${BOLD}settings.json after the summoning${RESET}"
  echo "${DIM}(the example MCP server and permissions should still be here)${RESET}"
  sed 's/^/  /' "$SANDBOX/.claude/settings.json"
  echo
fi

BACKUP=$(find "$SANDBOX/.companion" -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | head -1)
if [ -n "$BACKUP" ]; then
  echo "${BOLD}What was backed up before anything was replaced${RESET}"
  ( cd "$BACKUP" && find . -type f | sed 's|^\./|  |' )
  echo
fi

echo "${BOLD}The persona each agent received${RESET}"
for f in "$SANDBOX/.claude/CLAUDE.md" "$SANDBOX/.codex/AGENTS.md" \
         "$SANDBOX/.gemini/GEMINI.md" "$SANDBOX/.config/opencode/AGENTS.md" \
         "$SANDBOX/.companion/AGENTS.md"; do
  [ -f "$f" ] || continue
  echo "  ${DIM}${f#$SANDBOX/}${RESET}"
  grep -m1 "still .*, still accurate" "$f" | sed 's/^/    /' || true
done
echo

echo "${PURPLE}=========================================================${RESET}"
echo
echo "${DIM}To read the whole persona file, run again with --keep and open it.${RESET}"
