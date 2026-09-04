#!/bin/bash
# pomodoro-status.sh - tab_bar_right reader, runs every second, must stay trivial

# This runs as a plain tab_bar_right command, never a plugin action, so it
# never receives $HERDR_PLUGIN_STATE_DIR directly - see pomodoro-daemon.sh
# for how .state-dir lets it agree with the other scripts anyway.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR_MARKER="$SCRIPT_DIR/../.state-dir"
if [ -s "$STATE_DIR_MARKER" ]; then
  cat "$(cat "$STATE_DIR_MARKER")/display" 2>/dev/null || echo "Pomodoro?"
else
  echo "Pomodoro?"
fi
