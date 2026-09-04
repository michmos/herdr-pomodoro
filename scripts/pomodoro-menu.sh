#!/bin/bash
# pomodoro-menu.sh - fzf-based interactive menu

if [ -z "$HERDR_PLUGIN_CONFIG_DIR" ]; then
  echo "pomodoro-menu: HERDR_PLUGIN_CONFIG_DIR not set - was this started outside a herdr plugin action?" >&2
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fzf-helper.sh"

MENU_CHOICES=$'▶  Start / Resume\n◼  Pause\n▶▶ Next\nx  End\n⭮  Restart\n☰ Config'
CHOICE=$(fzf_choose "Pomodoro Control" "$MENU_CHOICES")
FZF_STATUS=$?

# 130 = user cancelled with Esc/ctrl-c, a normal exit, not a failure
if [ "$FZF_STATUS" -ne 0 ] && [ "$FZF_STATUS" -ne 130 ]; then
  echo "pomodoro-menu: fzf exited with status $FZF_STATUS" >&2
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# Dispatched via $HERDR_BIN_PATH instead of calling pomodoro-cmd.sh directly -
# a daemon spawned from inside this popup's process group can lose the race
# against the popup closing
case "$CHOICE" in
"▶  Start / Resume")
  "$HERDR_BIN_PATH" plugin action invoke start --plugin "$HERDR_PLUGIN_ID"
  ;;
"◼  Pause")
  "$HERDR_BIN_PATH" plugin action invoke pause --plugin "$HERDR_PLUGIN_ID"
  ;;
"▶▶ Next")
  "$HERDR_BIN_PATH" plugin action invoke next --plugin "$HERDR_PLUGIN_ID"
  ;;
"x  End")
  "$HERDR_BIN_PATH" plugin action invoke end --plugin "$HERDR_PLUGIN_ID"
  ;;
"⭮  Restart")
  "$HERDR_BIN_PATH" plugin action invoke restart --plugin "$HERDR_PLUGIN_ID"
  ;;
"☰ Config")
  "$SCRIPT_DIR/pomodoro-config.sh"
  "$SCRIPT_DIR/pomodoro-menu.sh"
  ;;
esac
