#!/usr/bin/env python3
"""Pomodoro timer daemon.

focus -> break is manual (holds at 0 for a "next" request); break -> focus is automatic.
"""

import os
import select
import signal
import subprocess
import sys
import time
from enum import Enum
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DISPLAY_REFRESH = 60
FOREVER_SLEEP = 86400  # ~1 day: effectively "forever" while idle; woken early by a signal

DEFAULT_CONFIG = {
    "FOCUS_LENGTH": 25,
    "BREAK_LENGTH": 5,
    "LONG_BREAK_LENGTH": 15,
    "NUM_SESSIONS": 4,
}


class State(Enum):
    FOCUS = "focus"
    FOCUS_DONE = "focus_done"  # focus session finished, waiting for "next"
    BREAK = "break"
    LONG_BREAK = "long_break"


def now() -> int:
    return int(time.time())


def load_config() -> dict:
    config_dir = os.environ.get("HERDR_PLUGIN_CONFIG_DIR")
    if not config_dir:
        sys.exit(
            "pomodoro-daemon: HERDR_PLUGIN_CONFIG_DIR not set - "
            "was this started outside a herdr plugin action?"
        )

    config = dict(DEFAULT_CONFIG)
    config_file = Path(config_dir) / "config"
    if config_file.exists():
        # Simple KEY=VALUE lines, not a full shell source - keeps this a plain
        # data file instead of executable config.
        for line in config_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.partition("#")[0].strip().strip("\"'")
            if key in config:
                config[key] = int(value)
    return config


def read_state_dir() -> Path:
    marker = SCRIPT_DIR.parent / ".state-dir"
    if not marker.exists() or marker.stat().st_size == 0:
        sys.exit(
            f"pomodoro-daemon: {marker} missing - "
            "has herdr run this plugin's startup hook yet?"
        )
    state_dir = Path(marker.read_text().strip())
    state_dir.mkdir(parents=True, exist_ok=True)
    return state_dir


class PomodoroDaemon:
    def __init__(self, config: dict, state_dir: Path, herdr_bin: str):
        self.durations = {
            State.FOCUS: config["FOCUS_LENGTH"] * 60,
            State.BREAK: config["BREAK_LENGTH"] * 60,
            State.LONG_BREAK: config["LONG_BREAK_LENGTH"] * 60,
        }
        self.num_sessions = config["NUM_SESSIONS"]
        self.herdr_bin = herdr_bin

        self.display_file = state_dir / "display"
        self.paused_file = state_dir / "paused"
        self.paused_file.unlink(missing_ok=True)

        self.state = State.FOCUS
        self.paused = False
        self.session_count = 1
        self.segment_start = now()

        self.got_signal_next = False
        self.got_signal_pause_toggle = False

        # Self-pipe trick: a signal handler can't safely wake a blocked
        # select() by itself, so it writes a byte here instead - select()
        # blocks on this pipe becoming readable, same as it would on a timeout.
        self._wake_r, self._wake_w = os.pipe()
        os.set_blocking(self._wake_r, False)
        os.set_blocking(self._wake_w, False)

        signal.signal(signal.SIGTERM, self._handle_terminate)
        signal.signal(signal.SIGINT, self._handle_terminate)
        signal.signal(signal.SIGUSR1, self._handle_next)
        signal.signal(signal.SIGUSR2, self._handle_pause_toggle)

    # -- signal handlers --

    def _handle_terminate(self, signum, frame):
        self._cleanup()
        sys.exit(0)

    def _handle_next(self, signum, frame):
        self.got_signal_next = True
        self._wake()

    def _handle_pause_toggle(self, signum, frame):
        self.got_signal_pause_toggle = True
        self._wake()

    def _wake(self):
        try:
            os.write(self._wake_w, b"\x00")
        except BlockingIOError:
            pass  # pipe already has a pending wake-up queued, nothing more to do

    def _cleanup(self):
        self.paused_file.unlink(missing_ok=True)

    # -- display --

    def notify(self, body: str):
        if not self.herdr_bin:
            return
        subprocess.run([self.herdr_bin, "notification", "show",
                        "Pomodoro", "--body", body, "--sound", "request", "--position", "top-right"])

    @staticmethod
    def _minutes(remaining_seconds: int) -> int:
        return (remaining_seconds + 59) // 60

    def update_display_file(self):
        remaining = self.remaining_in_segment()
        minutes = self._minutes(remaining)
        progress = f"[{self.session_count}/{self.num_sessions}]"
        icon = "◼" if not self.paused else "▶"
        match self.state:
            case State.FOCUS:
                self.display_file.write_text(
                    f"F: {icon} {minutes} {progress}\n")
            case State.FOCUS_DONE:
                self.display_file.write_text("F: start break? ▶▶\n")
            case State.BREAK:
                self.display_file.write_text(f"B: {icon} {minutes}\n")
            case State.LONG_BREAK:
                self.display_file.write_text(f"B: {icon} {minutes}\n")

    def remaining_in_segment(self) -> int:
        if self.state == State.FOCUS_DONE:
            return 0
        return max(0, self.durations[self.state] - (now() - self.segment_start))

    # -- main loop --
    def _sleep(self, seconds: int):
        ready, _, _ = select.select([self._wake_r], [], [], seconds)
        if ready:
            # drain pipe
            try:
                while os.read(self._wake_r, 4096):
                    pass
            except BlockingIOError:
                pass

    def _consume_signal_next(self) -> bool:
        got_signal, self.got_signal_next = self.got_signal_next, False
        return got_signal

    def _consume_signal_pause_toggle(self) -> bool:
        got_signal, self.got_signal_pause_toggle = self.got_signal_pause_toggle, False
        return got_signal

    # returns either LONG_BREAK or BREAK
    def _get_next_break_type(self) -> State:
        return State.LONG_BREAK if self.session_count == self.num_sessions else State.BREAK

    def focus(self):
        while self.remaining_in_segment() > 0:
            self._sleep(DISPLAY_REFRESH)
            if self._consume_signal_pause_toggle():
                pause_time = self.pause_and_resume()
                self.segment_start += pause_time
            if self._consume_signal_next():
                self.state = self._get_next_break_type()
                return
            self.update_display_file()

        self.state = State.FOCUS_DONE
        self.notify("Start break? Hit 'next'")

    def focus_done(self):
        while True:
            self._sleep(FOREVER_SLEEP)
            # nothing is running here to pause - drop the flag so it doesn't
            # cause a stale, unrequested auto-pause once the next break starts
            self._consume_signal_pause_toggle()
            if self._consume_signal_next():
                self.state = self._get_next_break_type()
                return

    def any_break(self):
        while self.remaining_in_segment() > 0:
            self._sleep(DISPLAY_REFRESH)
            if self._consume_signal_pause_toggle():
                pause_time = self.pause_and_resume()
                self.segment_start += pause_time
            if self._consume_signal_next():
                break
            self.update_display_file()
        self.session_count = 1 if self.state == State.LONG_BREAK else self.session_count + 1
        self.state = State.FOCUS
        self.notify("Starting focus")

    def pause_and_resume(self) -> int:
        self.paused = True
        start = now()
        # -- pause --
        self.update_display_file()
        self.paused_file.touch()

        # don't consume signal next here so that caller can check
        # if next got requested
        while not (self.got_signal_next or self._consume_signal_pause_toggle()):
            self._sleep(FOREVER_SLEEP)

        # -- resume --
        self.paused_file.unlink(missing_ok=True)
        self.paused = False
        return now() - start

    def run(self):
        while True:
            self.segment_start = now()
            self.update_display_file()
            match self.state:
                case State.FOCUS:
                    self.focus()
                case State.FOCUS_DONE:
                    self.focus_done()
                case State.BREAK:
                    self.any_break()
                case State.LONG_BREAK:
                    self.any_break()


def main():
    config = load_config()
    state_dir = read_state_dir()
    herdr_bin = os.environ.get("HERDR_BIN_PATH")
    PomodoroDaemon(config, state_dir, herdr_bin).run()


if __name__ == "__main__":
    main()
