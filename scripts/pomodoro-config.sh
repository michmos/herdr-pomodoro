#!/bin/bash
# pomodoro-config.sh - fzf-based config editor for the four session lengths

if [ -z "$HERDR_PLUGIN_CONFIG_DIR" ]; then
  echo "pomodoro-config: HERDR_PLUGIN_CONFIG_DIR not set - was this started outside a herdr plugin action?" >&2
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi
CONFIG_FILE="$HERDR_PLUGIN_CONFIG_DIR/config"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fzf-helper.sh"

FOCUS_LENGTH=$(fzf_choose "Focus length (minutes)" $'15\n20\n25\n30\n35\n40\n45\n50\n55\n60')
[ -z "$FOCUS_LENGTH" ] && exit 0

NUM_SESSIONS=$(fzf_choose "Focus sessions per cycle" $'1\n2\n3\n4\n5\n6')
[ -z "$NUM_SESSIONS" ] && exit 0

BREAK_LENGTH=$(fzf_choose "Short break length (minutes)" $'3\n5\n10\n15')
[ -z "$BREAK_LENGTH" ] && exit 0

LONG_BREAK_LENGTH=$(fzf_choose "Long break length (minutes)" $'10\n15\n20\n25\n30\n45')
[ -z "$LONG_BREAK_LENGTH" ] && exit 0

mkdir -p "$(dirname "$CONFIG_FILE")"
cat >"$CONFIG_FILE" <<EOF
# Pomodoro Plugin Configuration
# Edit these values to customize your Pomodoro sessions.
# Changes take effect the next time the daemon is (re)started.

FOCUS_LENGTH=$FOCUS_LENGTH        # Length of a focus session, in minutes
BREAK_LENGTH=$BREAK_LENGTH         # Length of a regular break, in minutes
LONG_BREAK_LENGTH=$LONG_BREAK_LENGTH   # Length of the long break after NUM_SESSIONS, in minutes
NUM_SESSIONS=$NUM_SESSIONS         # Focus sessions per cycle before a long break
EOF
