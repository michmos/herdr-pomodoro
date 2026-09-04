#!/bin/bash
# pomodoro-cmd.sh - daemon lifecycle: start, end, pause, restart, next

COMMAND="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STATE_DIR_MARKER="$SCRIPT_DIR/../.state-dir"
if [ ! -s "$STATE_DIR_MARKER" ]; then
  if [ -n "$HERDR_PLUGIN_STATE_DIR" ]; then
    echo "$HERDR_PLUGIN_STATE_DIR" >"$STATE_DIR_MARKER"
  else
    echo "pomodoro-cmd: HERDR_PLUGIN_STATE_DIR not set - was this started outside a herdr plugin action?" >&2
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
  fi
fi
STATE_DIR="$(cat "$STATE_DIR_MARKER")"
mkdir -p "$STATE_DIR" || exit 1
DAEMON_PID_FILE="$STATE_DIR/daemon.pid"
DISPLAY_FILE="$STATE_DIR/display"
PAUSED_FILE="$STATE_DIR/paused"

is_daemon_running() {
  [ -f "$DAEMON_PID_FILE" ] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null
}

is_daemon_paused() {
  [ -f "$PAUSED_FILE" ]
}

spawn_daemon() {
  # Spawned via a herdr action (never a popup), so the daemon is already a
  # job supervised directly by the herdr server
  "$SCRIPT_DIR/pomodoro-daemon.py" </dev/null >/tmp/pomodoro.log 2>&1 &
  disown
  echo $! >"$DAEMON_PID_FILE"
}

end_daemon() {
  if [ -f "$DAEMON_PID_FILE" ]; then
    kill "$(cat "$DAEMON_PID_FILE")" 2>/dev/null
    rm -f "$DAEMON_PID_FILE"
  fi
  echo "Pomodoro?" >"$DISPLAY_FILE"
}

toggle_pause_daemon() {
  kill -USR2 "$(cat "$DAEMON_PID_FILE")"
}

case "$COMMAND" in
# start doubles as resume: a paused daemon is still running, so it just gets un-paused
start)
  if is_daemon_running; then
    is_daemon_paused && toggle_pause_daemon
    exit 0
  fi
  spawn_daemon
  ;;

end)
  end_daemon
  ;;

pause)
  is_daemon_running && ! is_daemon_paused && toggle_pause_daemon
  ;;

restart)
  end_daemon
  spawn_daemon
  ;;

next)
  is_daemon_running && kill -USR1 "$(cat "$DAEMON_PID_FILE")"
  ;;

*)
  echo "Usage: $(basename "$0") {start|end|pause|restart|next}" >&2
  exit 1
  ;;
esac
