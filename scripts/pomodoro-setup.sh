#!/bin/bash
# pomodoro-setup.sh - deploy config-dir assets: state marker, default config,
# tab-bar status script. Idempotent - runs on every startup and can also be
# invoked manually via the "setup" action right after installing, since
# startup hooks don't run on install/link/enable, only on session (re)start.

mkdir -p "$HERDR_PLUGIN_CONFIG_DIR"
echo "$HERDR_PLUGIN_STATE_DIR" >"$HERDR_PLUGIN_CONFIG_DIR/.state-dir"
[ -f "$HERDR_PLUGIN_CONFIG_DIR/config" ] || cp "$HERDR_PLUGIN_ROOT/config.default" "$HERDR_PLUGIN_CONFIG_DIR/config"
cp "$HERDR_PLUGIN_ROOT/scripts/pomodoro-status.sh" "$HERDR_PLUGIN_CONFIG_DIR/pomodoro-status.sh"
