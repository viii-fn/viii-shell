# viii-shell

My Quickshell desktop setup for Arch Linux + labwc, packed so it can be restored on another laptop with one command.

Keep these two files together in the same folder:

```
viii-shell/
├── install.sh                  # the installer
└── quickshell-export.tar.gz    # all the config files
```

## Install

```bash
cd ~/viii-shell
bash install.sh
```

Then **open a new terminal** (so `srec` / `srecm` load) and **log out and back in** so labwc starts Quickshell from its autostart file.

The installer is safe to run more than once.

## What the installer does

1. Checks the archive exists and isn't corrupt.
2. Backs up anything it's about to overwrite to `~/quickshell-backup-<date>/`.
3. Unpacks the archive into your home folder.
4. If your username differs from the original (`viii_fn`), rewrites hardcoded `/home/viii_fn` paths in the config files.
5. Adds one line to the end of your existing `~/.zshrc` (see [zsh helpers](#zsh-helpers)).
6. Reloads labwc if it's running.
7. Installs packages (last, so a package failure never blocks the config).
8. Enables NetworkManager (only if no other network manager is running) and the PipeWire user services.

## What's included

| Path | What it is |
|---|---|
| `~/.config/quickshell/` | The whole shell: Island, Music, Wi-Fi, Audio, DPI, Screen Time, Clock, Trim panel/window, Lock |
| `~/.config/labwc/rc.xml` | Keybinds, theme name (Vent), corner radius, shadows, Papirus icons |
| `~/.config/labwc/environment` | labwc environment variables |
| `~/.config/labwc/autostart` | Starts Quickshell and friends on login |
| `~/.config/labwc/themerc-override` | Window border colours |
| `~/.config/wofi/` | Launcher config and style |
| `~/.local/bin/screentime-report` | Reads the screen-time logs for the panel |
| `~/.local/bin/clean.sh` | System cleanup script (the `clean` alias) |
| `~/.local/bin/screenshot` | Screenshot helper |
| `~/.local/share/themes/Vent/` | The labwc/openbox window theme |
| `~/.local/state/quickshell-clock` | Saved clock widget position |
| `~/.config/viii-shell/custom.zsh` | `srec`, `srecm` and aliases (hooked into `.zshrc`) |

### Deliberately NOT included

- **Screen-time history** (`~/.local/share/screentime/`). Each laptop builds its own history. The installer just creates the empty folder.
- Git `*.sample` hook files from the Quickshell config repo.
- Your `.zshrc` itself (see below).

## Keybinds

| Keys | Action |
|---|---|
| `Super + M` | Music panel |
| `Super + I` | Wi-Fi panel |
| `Super + O` | Audio output panel |
| `Super + J` | DPI scale panel |
| `Super + U` | Screen time panel |
| `Super + C` | Clock widget |

They're defined in `~/.config/labwc/rc.xml` and call `qs ipc call <panel> toggle`.

## zsh helpers

The installer **never replaces** `~/.zshrc`. It appends a single line, only if it isn't already there:

```zsh
source ~/.config/viii-shell/custom.zsh
```

That file provides:

| Command | What it does |
|---|---|
| `srec` | Record the full screen to `~/Videos/Screenclips/clip_<timestamp>.mp4` (Ctrl+C to stop) |
| `srecm` | Same, but drag a region with the mouse first |
| `reshell` | Restart Quickshell |
| `rebar` | Restart Waybar |
| `clean` | Run `~/.local/bin/clean.sh` |
| `note` | Open `~/Documents/note.txt` in micro |
| `keybind` | Print `rc.xml` |

Recordings are saved as `.mkv` first and converted to `.mp4` when you stop. If conversion fails, the `.mkv` is kept.

If the other laptop already defines an alias with the same name, these win, because the `source` line sits at the end of `.zshrc`.

## Requirements

- Arch Linux with **labwc** as the compositor
- Quickshell (`quickshell` from the repos, or `quickshell-git` from the AUR; the installer tries both)
- NetworkManager (the Wi-Fi panel uses `nmcli`)
- PipeWire + WirePlumber (the audio panel uses `pactl`)

Packages the installer pulls in: `curl networkmanager libpulse wlr-randr pipewire pipewire-pulse pipewire-audio wireplumber papirus-icon-theme wofi zenity micro playerctl brightnessctl python ffmpeg wf-recorder slurp grim wl-clipboard qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-wayland`

## Troubleshooting

**Nothing shows after login.** Check `~/.config/labwc/autostart` launches `qs`, then run `reshell` or `setsid qs &` from a terminal and read the errors.

**Wi-Fi panel is empty.** Another network manager (iwd, systemd-networkd, dhcpcd) is probably running. The installer won't fight it. Either switch to NetworkManager or adapt the panel.

**A keybind does nothing.** Run `labwc -r` to reload, then `qs ipc call clock toggle` by hand to see if Quickshell responds.

**Something got overwritten.** Look in `~/quickshell-backup-<date>/`.

**Quickshell not found.** Install `quickshell-git` from the AUR with `paru` or `yay`.

## Rebuilding the archive (on the original laptop)

Run this after changing your setup, then copy the `viii-shell` folder to the other machine:

```bash
mkdir -p ~/viii-shell /tmp/viii-stage/.config/viii-shell

# Pull just the custom zsh block into its own file
sed -n '/^# --- CUSTOM COMMANDS ---/,/^# --- END OF CUSTOM COMMANDS ---/p' ~/.zshrc \
  > /tmp/viii-stage/.config/viii-shell/custom.zsh

tar czf ~/viii-shell/quickshell-export.tar.gz --exclude='*.sample' \
  -C ~ \
  .config/quickshell \
  .config/labwc/rc.xml .config/labwc/environment \
  .config/labwc/autostart .config/labwc/themerc-override \
  .config/wofi \
  .local/bin/screentime-report .local/bin/clean.sh .local/bin/screenshot \
  .local/share/themes/Vent \
  .local/state/quickshell-clock \
  -C /tmp/viii-stage .config/viii-shell/custom.zsh

# Sanity check: this should print the OK line
tar tzf ~/viii-shell/quickshell-export.tar.gz | grep -E '\.local/share/screentime/' \
  && echo "!! history leaked in" || echo "OK: no screen-time history in the archive"
```

The `# --- CUSTOM COMMANDS ---` and `# --- END OF CUSTOM COMMANDS ---` marker lines in `~/.zshrc` must stay intact, since the `sed` command above relies on them.
