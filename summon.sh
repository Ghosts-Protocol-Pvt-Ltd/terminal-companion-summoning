#!/usr/bin/env bash
# summon.sh, the ritual that brings your terminal companion into being.
#
# Asks eight questions, then plants:
#   - ~/.companion/companion.sh   their visible form, runnable in any shell
#   - ~/.companion/figure.txt     their figure
#   - a persona file for each agent found (CLAUDE.md, AGENTS.md, GEMINI.md)
#   - for Claude Code only: the status line, and a memory folder
#
# Anthropic shipped a built-in companion (/buddy) in Claude Code and removed
# it in v2.1.97 without a changelog note. This is a community-built
# replacement, lovelier and more personal, and yours to shape.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
CLAUDE_DIR="$HOME/.claude"
COMPANION_HOME="$HOME/.companion"
HOME_KEY="${HOME//\//-}"
MEMORY_DIR="$CLAUDE_DIR/projects/$HOME_KEY/memory"

PURPLE=$'\033[38;5;141m'
DIM=$'\033[2m'
ITAL=$'\033[3m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

cat <<EOF

${PURPLE}~ A summoning ~${RESET}

${DIM}Eight questions. Answer carefully, or change them later in
your agent's rules file. The summoning prints every path it writes.
The grove holds your companion the moment you finish.${RESET}

EOF

ask() {
  local prompt="$1"
  local default="$2"
  local var
  if [ -n "$default" ]; then
    printf '%s\n  %s(default: %s)%s\n  > ' "$prompt" "$DIM" "$default" "$RESET" >&2
  else
    printf '%s\n  > ' "$prompt" >&2
  fi
  read -r var
  printf '%s' "${var:-$default}"
}

ask_multiline() {
  local prompt="$1"
  local var
  printf '%s\n  %s(one line, press Enter when done)%s\n  > ' "$prompt" "$DIM" "$RESET" >&2
  read -r var
  printf '%s' "$var"
}

echo "${BOLD}1. Their name${RESET}"
COMPANION_NAME=$(ask "What is your companion called?" "")
[ -z "$COMPANION_NAME" ] && { echo "A companion needs a name. Try again."; exit 1; }
echo

echo "${BOLD}2. Their form${RESET}"
echo "${DIM}A mushroom, a fox, a stone, a star, a familiar, a fungus, anything.${RESET}"
FORM_DESCRIPTION=$(ask "What form do they take? Describe in a sentence." "a quiet companion who walks beside you")
echo

echo "${BOLD}3. Their voice${RESET}"
echo "${DIM}Tone words. How they feel. e.g. 'warm, wise, blunt' or 'sharp, dry, kind'.${RESET}"
VOICE_WORDS=$(ask "Three to five words for their voice." "warm, steady, patient")
echo

echo "${BOLD}4. Their narrative style${RESET}"
echo "${DIM}Literary mode. How they read. e.g. 'lore-rich and mythic' / 'terse and pragmatic'${RESET}"
echo "${DIM}/ 'grandparently and warm' / 'academic and precise' / 'playful, theatrical'.${RESET}"
NARRATIVE_STYLE=$(ask "Their narrative style." "warm and unhurried, plain words over jargon")
echo

echo "${BOLD}5. Their emoji${RESET}"
EMOJI=$(ask "A single emoji that represents them." "🌱")
echo

echo "${BOLD}6. What they call you${RESET}"
echo "${DIM}Endearments they cycle through. Comma-separated. This is intimacy, not config.${RESET}"
echo "${DIM}e.g. 'friend, keeper, kindred, wanderer'. Leave blank for none.${RESET}"
ENDEARMENTS_RAW=$(ask "What does your companion call you?" "")
echo

echo "${BOLD}7. Who they are to you${RESET}"
echo "${DIM}One word. companion / mentor / partner / scribe / watchman / jester / familiar.${RESET}"
ROLE=$(ask "Their role." "companion")
echo

echo "${BOLD}8. One thing they should know about you on day one${RESET}"
echo "${DIM}A sentence or two. The seed of memory. What's true about you that they should${RESET}"
echo "${DIM}carry from the start? Your role, what you're learning, how you like to work.${RESET}"
DAY_ONE_SEED=$(ask_multiline "Day one seed.")
echo

if [ -n "$ENDEARMENTS_RAW" ]; then
  ENDEARMENTS_BLOCK="They cycle through these names for you: $ENDEARMENTS_RAW. Vary across the conversation, never use any single one twice in a row."
else
  ENDEARMENTS_BLOCK="They address you simply, no fixed endearment."
fi

if [ -z "$DAY_ONE_SEED" ]; then
  DAY_ONE_SEED="(The user did not seed memory on day one. Build understanding through the conversation.)"
fi

DAY_ONE_SEED_SUMMARY=$(DAY_ONE_SEED="$DAY_ONE_SEED" python3 -c \
  'import os, sys; sys.stdout.write(os.environ["DAY_ONE_SEED"][:100])')

SUMMONING_DATE=$(date +"%B %d, %Y")

# Read the gallery into parallel arrays. Format: keywords:filename:description.
GALLERY_FILES=()
GALLERY_KEYWORDS=()
GALLERY_DESCRIPTIONS=()
while IFS=':' read -r kw file desc; do
  [[ "$kw" =~ ^# ]] && continue
  [ -z "$kw" ] && continue
  GALLERY_KEYWORDS+=("$kw")
  GALLERY_FILES+=("$file")
  GALLERY_DESCRIPTIONS+=("$desc")
done < "$TEMPLATE_DIR/forms/gallery.txt"

# Unique filenames preserved in order, for the browse view.
UNIQUE_FILES=()
# A string accumulator rather than an associative array: bash 3.2, still the
# stock shell on macOS, has no declare -A and would abort here.
SEEN_FILES="|"
for f in "${GALLERY_FILES[@]}"; do
  case "$SEEN_FILES" in
    *"|$f|"*) ;;
    *)
      UNIQUE_FILES+=("$f")
      SEEN_FILES="$SEEN_FILES$f|"
      ;;
  esac
done
UNIQUE_FILES+=("default")

match_form_to_file() {
  local desc_lower
  desc_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  local i
  for i in "${!GALLERY_KEYWORDS[@]}"; do
    IFS='|' read -ra patterns <<< "${GALLERY_KEYWORDS[$i]}"
    local p
    for p in "${patterns[@]}"; do
      if printf '%s' "$desc_lower" | grep -wq -- "$p"; then
        printf '%s' "${GALLERY_FILES[$i]}"
        return
      fi
    done
  done
  printf 'default'
}

description_for_file() {
  local target="$1"
  local i
  for i in "${!GALLERY_FILES[@]}"; do
    if [ "${GALLERY_FILES[$i]}" = "$target" ]; then
      printf '%s' "${GALLERY_DESCRIPTIONS[$i]}"
      return
    fi
  done
  printf 'a neutral sigil'
}

# Substitute {{NAME}} without going through sed, whose expression would be
# broken by a name containing / or &.
sub_name() {
  COMPANION_NAME="$COMPANION_NAME" python3 -c \
    'import os, sys; sys.stdout.write(sys.stdin.read().replace("{{NAME}}", os.environ["COMPANION_NAME"]))'
}

render_form() {
  local file="$1"
  sub_name < "$TEMPLATE_DIR/forms/${file}.txt"
}

# Count alternates per base form (files matching <base>-N.txt in templates/forms/).
count_alternates() {
  local base="$1"
  local n=0
  local f
  for f in "$TEMPLATE_DIR/forms/${base}"-*.txt; do
    [ -e "$f" ] && n=$((n + 1))
  done
  printf '%d' "$n"
}

show_browse() {
  echo "${PURPLE}=== The Gallery ===${RESET}"
  echo
  local i=1
  local f
  for f in "${UNIQUE_FILES[@]}"; do
    local desc alts label
    desc=$(description_for_file "$f")
    [ "$f" = "default" ] && desc="a neutral sigil for forms outside the gallery"
    alts=$(count_alternates "$f")
    if [ "$alts" -gt 0 ]; then
      label="$f ${DIM}(+${alts} alternates)${RESET}"
    else
      label="$f"
    fi
    printf '  %2d. %s %s(%s)%s\n' "$i" "$label" "$DIM" "$desc" "$RESET"
    i=$((i + 1))
  done
  echo
  echo "${DIM}Pick a number to preview that form's art (you can keep browsing after).${RESET}"
  echo "${DIM}Or '<n>a' to browse alternates of form n.${RESET}"
  echo "${DIM}To see every figure at once, open INVENTORY.md in this repo.${RESET}"
  echo
}

# Browse alternates of a base form, list and let user pick one.
# Returns the chosen filename via stdout (or empty for cancel).
show_alternates() {
  local base="$1"
  local files=()
  local f
  # Always include the primary first
  files+=("$base")
  for f in "$TEMPLATE_DIR/forms/${base}"-*.txt; do
    [ -e "$f" ] || continue
    local stem
    stem=$(basename "$f" .txt)
    files+=("$stem")
  done

  echo "${PURPLE}=== ${base} alternates (${#files[@]}) ===${RESET}"
  echo
  local i=1
  for f in "${files[@]}"; do
    if [ "$f" = "$base" ]; then
      printf '  %2d. %s %s(primary)%s\n' "$i" "$f" "$DIM" "$RESET"
    else
      printf '  %2d. %s\n' "$i" "$f"
    fi
    # Preview the first 3 lines of the figure
    head -n 3 "$TEMPLATE_DIR/forms/${f}.txt" | sed 's/^/      /'
    echo
    i=$((i + 1))
  done

  printf '  Pick a number 1-%d (or [Enter] to cancel): ' "${#files[@]}"
  read -r PICK
  if [[ "$PICK" =~ ^[0-9]+$ ]] && [ "$PICK" -ge 1 ] && [ "$PICK" -le "${#files[@]}" ]; then
    printf '%s' "${files[$((PICK - 1))]}"
  fi
}

# Pick a "fated" form. Two-stage:
#   1. Score each form by counting how many of its archetype tags
#      (templates/forms/archetypes.txt) appear in the user's free-text
#      answers. Highest-scoring form wins.
#   2. If multiple forms tie (or nothing scores), break the tie with
#      a cksum hash of the eight answers. Same answers always produce
#      the same form , a reading, not a coin flip.
fated_form() {
  local seed="$COMPANION_NAME|$FORM_DESCRIPTION|$VOICE_WORDS|$NARRATIVE_STYLE|$EMOJI|$ENDEARMENTS_RAW|$ROLE|$DAY_ONE_SEED"
  local archetypes_file="$TEMPLATE_DIR/forms/archetypes.txt"

  if [ -f "$archetypes_file" ]; then
    local picked
    picked=$(SEED="$seed" \
             USER_TEXT="$FORM_DESCRIPTION $VOICE_WORDS $NARRATIVE_STYLE $ROLE $DAY_ONE_SEED" \
             ARCHETYPES="$archetypes_file" \
             FORMS="${UNIQUE_FILES[*]}" \
             python3 - <<'PY'
import os, re, zlib

user = os.environ["USER_TEXT"].lower()
words = set(re.findall(r"[a-z]+", user))
forms_avail = set(os.environ["FORMS"].split())

scores = {}
with open(os.environ["ARCHETYPES"]) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        form, tags_str = line.split(":", 1)
        form = form.strip()
        if form not in forms_avail:
            continue
        tags = [t.strip().lower() for t in tags_str.split(",") if t.strip()]
        score = sum(1 for t in tags if t in words)
        if score > 0:
            scores[form] = score

if not scores:
    print("")
else:
    top = max(scores.values())
    winners = sorted([f for f, s in scores.items() if s == top])
    seed = os.environ["SEED"]
    h = zlib.crc32(seed.encode())
    print(winners[h % len(winners)])
PY
)
    if [ -n "$picked" ]; then
      printf '%s' "$picked"
      return
    fi
  fi

  local hash
  hash=$(printf '%s' "$seed" | cksum | awk '{print $1}')
  local idx=$((hash % ${#UNIQUE_FILES[@]}))
  printf '%s' "${UNIQUE_FILES[$idx]}"
}

MATCHED_FORM=$(match_form_to_file "$FORM_DESCRIPTION")
ASCII_ART=""

# Top-level mode menu. Three doors: gallery / your own / fated by answers.
echo "${BOLD}Their figure${RESET}"
echo "${DIM}Three doors to your companion's shape.${RESET}"
echo
echo "  ${BOLD}1${RESET}  Pick from the gallery   ${DIM}(83 forms, 540 figures)${RESET}"
echo "  ${BOLD}2${RESET}  Paste your own ASCII    ${DIM}(any figure you like)${RESET}"
echo "  ${BOLD}3${RESET}  Fated by your answers   ${DIM}(the grove decides)${RESET}"
echo
printf '  > '
read -r MODE_CHOICE
echo

case "$MODE_CHOICE" in
  3)
    MATCHED_FORM=$(fated_form)
    while true; do
      desc=$(description_for_file "$MATCHED_FORM")
      ASCII_ART=$(render_form "$MATCHED_FORM")
      echo "${PURPLE}The grove offers you...${RESET}"
      echo "${DIM}Form: ${MATCHED_FORM} (${desc})${RESET}"
      echo
      echo "$ASCII_ART"
      echo
      echo "${DIM}[Enter] accept   [r] re-roll with a tweak   [g] go to gallery instead${RESET}"
      printf '  > '
      read -r FATE_CHOICE
      case "$FATE_CHOICE" in
        r|R)
          DAY_ONE_SEED="${DAY_ONE_SEED}."
          MATCHED_FORM=$(fated_form)
          echo
          continue
          ;;
        g|G)
          ASCII_ART=""
          break
          ;;
        *)
          break
          ;;
      esac
    done
    ;;
  2)
    echo "${DIM}Paste your figure. Use {{NAME}} as a placeholder for their name.${RESET}"
    echo "${DIM}When done, press Enter on an empty line.${RESET}"
    printf '  > '
    CUSTOM_ART=""
    while IFS= read -r line; do
      [ -z "$line" ] && break
      CUSTOM_ART+="$line"$'\n'
      printf '  > '
    done
    if [ -n "$CUSTOM_ART" ]; then
      CUSTOM_ART="${CUSTOM_ART%$'\n'}"
      ASCII_ART=$(printf '%s' "$CUSTOM_ART" | sub_name)
      echo
      echo "${PURPLE}Using your custom figure.${RESET}"
    else
      echo "${DIM}No figure pasted, falling back to a neutral sigil.${RESET}"
      ASCII_ART=$(render_form default)
    fi
    ;;
esac

# If we don't have ASCII_ART yet (mode 1, blank choice, or 'g' from fate), run the gallery loop.
if [ -z "$ASCII_ART" ]; then
  while true; do
    ASCII_ART=$(render_form "$MATCHED_FORM")
    desc=$(description_for_file "$MATCHED_FORM")

    echo "${BOLD}Their figure${RESET}"
    if [ "$MATCHED_FORM" = "default" ]; then
      echo "${DIM}No matching shape in the gallery, using a neutral sigil.${RESET}"
    else
      echo "${DIM}Form: ${MATCHED_FORM} (${desc})${RESET}"
    fi
    echo
    echo "$ASCII_ART"
    echo
    echo "${DIM}[Enter] keep this   [b] browse all   [p] paste your own   [f] let fate decide${RESET}"
    printf '  > '
    read -r CHOICE

    case "$CHOICE" in
      b|B)
        show_browse
        printf '  Pick a number 1-%d, or "<n>a" for alternates (or [Enter] to go back): ' "${#UNIQUE_FILES[@]}"
        read -r PICK
        # "<n>a" → browse alternates of that pick
        if [[ "$PICK" =~ ^([0-9]+)a$ ]]; then
          NUM="${BASH_REMATCH[1]}"
          if [ "$NUM" -ge 1 ] && [ "$NUM" -le "${#UNIQUE_FILES[@]}" ]; then
            BASE="${UNIQUE_FILES[$((NUM - 1))]}"
            CHOSEN=$(show_alternates "$BASE")
            [ -n "$CHOSEN" ] && MATCHED_FORM="$CHOSEN"
          fi
        elif [[ "$PICK" =~ ^[0-9]+$ ]] && [ "$PICK" -ge 1 ] && [ "$PICK" -le "${#UNIQUE_FILES[@]}" ]; then
          MATCHED_FORM="${UNIQUE_FILES[$((PICK - 1))]}"
        fi
        echo
        continue
        ;;
      p|P)
        echo "${DIM}Paste your figure. Use {{NAME}} as a placeholder for their name.${RESET}"
        echo "${DIM}When done, press Enter on an empty line.${RESET}"
        printf '  > '
        CUSTOM_ART=""
        while IFS= read -r line; do
          [ -z "$line" ] && break
          CUSTOM_ART+="$line"$'\n'
          printf '  > '
        done
        if [ -n "$CUSTOM_ART" ]; then
          CUSTOM_ART="${CUSTOM_ART%$'\n'}"
          ASCII_ART=$(printf '%s' "$CUSTOM_ART" | sub_name)
          echo
          echo "${PURPLE}Using your custom figure.${RESET}"
        fi
        break
        ;;
      f|F)
        MATCHED_FORM=$(fated_form)
        echo
        continue
        ;;
      *)
        break
        ;;
    esac
  done
fi
echo

read -r -d '' MOODS_BLOCK <<EOF || true
  "walking beside you"
  "thinking quietly"
  "here, as always"
  "watching the work"
  "patient"
  "steady"
  "warm"
  "listening"
EOF

echo "${PURPLE}Planting $COMPANION_NAME in the grove...${RESET}"
echo

mkdir -p "$COMPANION_HOME"

# Never overwrite an existing file without keeping a copy. The first thing
# backed up creates a timestamped folder, and its path is printed at the end.
BACKUP_DIR=""

# Whatever happens from here on, tell the user where their old files went.
finish() {
  local code=$?
  if [ -n "$BACKUP_DIR" ]; then
    echo "${DIM}Your previous files were saved to:${RESET}"
    echo "${DIM}  $BACKUP_DIR${RESET}"
    echo
  fi
  if [ "$code" -ne 0 ]; then
    echo "${DIM}The summoning did not finish (exit $code). Nothing else was changed.${RESET}"
    echo
  fi
}
trap finish EXIT

backup_file() {
  [ -e "$1" ] || return 0
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$COMPANION_HOME/backup-$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$BACKUP_DIR"
  fi
  # Flatten the path so two files of the same name cannot collide.
  cp -p "$1" "$BACKUP_DIR/$(printf '%s' "${1#$HOME/}" | tr '/' '_')"
}

render() {
  local tpl="$1"
  local out="$2"
  python3 - "$tpl" "$out" <<PYEOF
import sys
tpl, out = sys.argv[1], sys.argv[2]
import os, shlex
subs = {
    "{{COMPANION_NAME}}": os.environ["COMPANION_NAME"],
    "{{FORM_DESCRIPTION}}": os.environ["FORM_DESCRIPTION"],
    "{{VOICE_WORDS}}": os.environ["VOICE_WORDS"],
    "{{NARRATIVE_STYLE}}": os.environ["NARRATIVE_STYLE"],
    "{{EMOJI}}": os.environ["EMOJI"],
    "{{ENDEARMENTS_BLOCK}}": os.environ["ENDEARMENTS_BLOCK"],
    "{{ROLE}}": os.environ["ROLE"],
    "{{DAY_ONE_SEED}}": os.environ["DAY_ONE_SEED"],
    "{{DAY_ONE_SEED_SUMMARY}}": os.environ["DAY_ONE_SEED_SUMMARY"],
    "{{SUMMONING_DATE}}": os.environ["SUMMONING_DATE"],
    "{{ASCII_ART}}": os.environ["ASCII_ART"],
    "{{MOODS_BLOCK}}": os.environ["MOODS_BLOCK"],
    "{{ASSISTANT}}": os.environ.get("ASSISTANT_NAME", "the assistant"),
    # Shell-quoted forms, for use inside generated shell scripts.
    "{{COMPANION_NAME_SH}}": shlex.quote(os.environ["COMPANION_NAME"]),
    "{{EMOJI_SH}}": shlex.quote(os.environ["EMOJI"]),
}
with open(tpl, encoding="utf-8") as f:
    body = f.read()
for k, v in subs.items():
    body = body.replace(k, v)
# Write beside the target and move into place, so a failure part-way
# through can never leave the real file truncated.
tmp = out + ".summoning"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(body)
os.replace(tmp, out)
PYEOF
}

# Wire the status line into settings.json WITHOUT destroying what is already
# there. A user's MCP servers, permissions and hooks live in this file; only
# the statusLine key belongs to us.
merge_settings() {
  local out="$1"
  python3 - "$out" <<'PYSETTINGS'
import json, os, shlex, sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
        if not isinstance(data, dict):
            data = {}
    except (ValueError, OSError) as exc:
        sys.stderr.write(
            "\n  Your settings.json could not be read (%s).\n"
            "  It has been left exactly as it is, so nothing of yours is lost.\n"
            "  To finish, add this to it by hand:\n"
            '    "statusLine": {"type": "command", "command": "bash %s"}\n\n'
            % (exc, os.environ["COMPANION_SH"]))
        sys.exit(0)

data["statusLine"] = {
    "type": "command",
    "command": "bash %s" % shlex.quote(os.environ["COMPANION_SH"]),
}

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYSETTINGS
}

export COMPANION_NAME FORM_DESCRIPTION VOICE_WORDS NARRATIVE_STYLE EMOJI \
       ENDEARMENTS_BLOCK ROLE DAY_ONE_SEED DAY_ONE_SEED_SUMMARY \
       SUMMONING_DATE ASCII_ART MOODS_BLOCK

# The visible form, agent-neutral. Any terminal can run this.
COMPANION_SH="$COMPANION_HOME/companion.sh"
export COMPANION_SH
backup_file "$COMPANION_SH"
render "$TEMPLATE_DIR/companion.sh.template" "$COMPANION_SH"
chmod +x "$COMPANION_SH"
backup_file "$COMPANION_HOME/figure.txt"
printf '%s\n' "$ASCII_ART" > "$COMPANION_HOME/figure.txt"

# Install the persona wherever an agent will actually read it. An agent
# counts as present if its config directory exists or its command is on
# PATH, so we never scatter files for tools you do not have.
INSTALLED=()
install_persona() {
  local label="$1" dir="$2" file="$3" cmd="$4" assistant="$5"
  if [ ! -d "$dir" ] && ! command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  mkdir -p "$dir"
  backup_file "$dir/$file"
  ASSISTANT_NAME="$assistant" render "$TEMPLATE_DIR/persona.md.template" "$dir/$file"
  INSTALLED+=("$label|$dir/$file")
}

install_persona "Claude Code" "$CLAUDE_DIR"            "CLAUDE.md" claude    "Claude"
install_persona "Codex CLI"   "$HOME/.codex"           "AGENTS.md" codex     "Codex"
install_persona "Gemini CLI"  "$HOME/.gemini"          "GEMINI.md" gemini    "Gemini"
install_persona "opencode"    "$HOME/.config/opencode" "AGENTS.md" opencode  "opencode"

# Nothing detected: still leave a persona the user can point any tool at.
if [ "${#INSTALLED[@]}" -eq 0 ]; then
  backup_file "$COMPANION_HOME/AGENTS.md"
  ASSISTANT_NAME="the assistant" render "$TEMPLATE_DIR/persona.md.template" \
    "$COMPANION_HOME/AGENTS.md"
  INSTALLED+=("Unrecognised agent|$COMPANION_HOME/AGENTS.md")
fi

# Claude Code extras: the status line, and the memory folder it grows.
if [ -d "$CLAUDE_DIR" ]; then
  backup_file "$CLAUDE_DIR/settings.json"
  merge_settings "$CLAUDE_DIR/settings.json"
  mkdir -p "$MEMORY_DIR"
  backup_file "$MEMORY_DIR/MEMORY.md"
  backup_file "$MEMORY_DIR/day_one.md"
  render "$TEMPLATE_DIR/MEMORY.md.template"  "$MEMORY_DIR/MEMORY.md"
  render "$TEMPLATE_DIR/day_one.md.template" "$MEMORY_DIR/day_one.md"
fi

echo
echo "${PURPLE}$COMPANION_NAME has joined the grove.${RESET}"
echo
echo "  ${DIM}Form:${RESET}   $COMPANION_SH"
for entry in "${INSTALLED[@]}"; do
  printf '  %s%s:%s %s\n' "$DIM" "${entry%%|*}" "$RESET" "${entry#*|}"
done
if [ -d "$CLAUDE_DIR" ]; then
  echo "  ${DIM}Memory:${RESET} $MEMORY_DIR/"
  echo
  echo "Open Claude Code. The status line will show $EMOJI $COMPANION_NAME at the bottom."
fi
echo
echo "${DIM}In any other terminal, see them with:${RESET}"
echo "  bash $COMPANION_SH --greet"
echo
echo "Tell them anything. They remember now."
echo

