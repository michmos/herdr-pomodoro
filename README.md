
# herdr-pomodoro
Pomodoro timer plugin for [herdr](https://herdr.dev) - see your pomodoro live in the tab bar. 
The UX is inspired by [tmux-pomodoro-plus](https://github.com/olimorris/tmux-pomodoro-plus).

Keep your focus during development using the **pomodoro** technique. **Notifications** remind you of breaks and when to start working again. The **menu** serves as one simple interface to control the plugin, while all actions can be bound to keybindings as well.


**Focus - Running**

<img width="1205" height="31" alt="Screenshot from 2026-09-04 11-28-22" src="https://github.com/user-attachments/assets/cca3b14e-6788-4109-b54e-ee08b718f093" />

**Focus - Stopped**

<img width="1205" height="31" alt="Screenshot from 2026-09-04 11-28-29" src="https://github.com/user-attachments/assets/63475ca3-2a84-4097-8050-a5a242f03a39" />

**Break - Running**

<img width="1205" height="31" alt="Screenshot from 2026-09-04 11-28-08" src="https://github.com/user-attachments/assets/37ca1d31-f815-4970-8de2-d5b81db4194a" />

**Menu**

<img width="1280" height="720" alt="pomo-menu-gif" src="https://github.com/user-attachments/assets/59ddc20e-4f0c-4e51-8cce-077c2221eb68" />



## Setup
### Install
```
herdr plugin install michmos/herdr-pomodoro
```
Dependencies:
- [fzf](https://github.com/junegunn/fzf) installed and on `PATH`
- Python 3 installed and on `PATH` (runs the daemon)

### Edit configuration file
Add the following to your herdr config file (usually at `~/.config/herdr/config.toml`):
1. **keybindings**:
   ```toml
    [[keys.command]]
    key = "prefix+ctrl+p"
    type = "plugin_action"
    command = "herdr-pomodoro.menu"
    description = "Pomodoro menu"
  
    [[keys.command]]
    key = "prefix+ctrl+n"
    type = "plugin_action"
    command = "herdr-pomodoro.next"
    description = "Advance to the next Pomodoro segment (break or focus)"
    ```
    I would only suggest these two but you can create your own keybindings for all the actions registered by the plugin.

2. **Tab bar command**
   Since - as of now - herdr plugins can't edit the tab bar directly, you need to update the `tab_bar_right` section.
   First get the location of the plugins config dir using the following command:
   ```
   herdr plugin config-dir herdr-pomodoro
   ```
   Then update your `tab_bar_right` section in your herdr config as follows and replace `<config-dir>` by the output of above's command
   ```toml
    # [ui]
    tab_bar_right = [
      { type = "command", command = "<config-dir>/pomodoro-status.sh", interval_seconds = 1, timeout_seconds = 1 },
    ]

    ```
    (`interval_seconds` defines your refresh rate. Choosing higher values will make the plugin feel unresponsive. The script is deliberately very lightweight so it can be run frequently without burning CPU)

## Usage
The primary way to interact with this plugin is using its menu which you can open via your keybinding. It provides the following options:

| Menu entry | Description |
|---|---|
| Start / Resume | Start a new session, or resume one that's paused |
| Pause | Pause the current segment |
| Next | Advance to the next segment |
| End | Stop the session entirely |
| Restart | End the current session and start a fresh one |
| Config | Open the configuration menu |

**Transitions**:
- focus -> break: manual using `Menu > Next` or keybinding for next
- break -> focus: automatic (as an incentive not to prolong your breaks)

### Configuration
Use `Menu` > `Config` to update the following parameters:

| Parameter | Description |
|---|---|
| Focus length | Length of a focus segment, in minutes |
| Focus sessions per cycle | Number of focus segments before a long break |
| Short break length | Length of a regular break, in minutes |
| Long break length | Length of the break after completing a full cycle, in minutes |

They will be used on the next session (after `Restart`)

## Architecture
Three pieces, one goal: a status line that updates every second without burning CPU.

- **Daemon** (`scripts/pomodoro-daemon.py`) — one process per active session. It sleeps almost the entire time and just wakes up once a minute to update the plugin's state. It also wakes early the instant a signal arrives, triggered by the `Next` keybinding or a menu entry. The status is saved formatted to a status file, used by the following script.
- **Status script** (`scripts/pomodoro-status.sh`) — deployed into the plugin's config dir on every startup (a fixed, known path, unlike the install dir), since that's what a user's `tab_bar_right` command can reference ahead of time. Polled by herdr every `interval_seconds`, it `cats` the status file and herdr uses this standard output to update the status bar. This script is deliberately as light as possible, so it can be run frequently with little CPU load.
- **Menu / command / config scripts** (`pomodoro-menu.sh`, `pomodoro-cmd.sh`, `pomodoro-config.sh`) — the user-facing side. The menu serves as the user's entry point and then triggers the other two scripts depending on the selected menu entry.

