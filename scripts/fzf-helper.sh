#!/bin/bash
# fzf-helper.sh - shared fzf wrapper, sourced by other pomodoro-*.sh scripts

if ! command -v fzf >/dev/null 2>&1; then
  echo "$(basename "$0"): fzf not found on PATH ($PATH)" >&2
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# fzf_choose HEADER CHOICES - runs fzf over newline-separated CHOICES with a
# consistent header/border style, prints the selected line (empty if the
# user cancelled with Esc/ctrl-c).
fzf_choose() {
  printf '%s\n' "$2" | fzf --border=rounded --header "$1"
}
