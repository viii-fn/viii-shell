viii-shell

My Quickshell desktop setup for Arch Linux, designed to be restored on another laptop with a single command. Supports labwc, Hyprland, or a standalone shell installation where you configure compositor integration yourself.

The installer can restore the full setup or just the core Quickshell configuration, preserve existing files, install alongside another Quickshell setup, and optionally handle packages and services.

What's in the folder?

Keep these two files together in the same directory:

viii-shell/
├── install.sh                  # Interactive installer
└── quickshell-export.tar.gz    # Quickshell config and supporting files

Install

Run the installer from the directory containing both files:

cd ~/viii-shell
bash install.sh


With no options, the installer asks which compositor to configure and whether to install everything or just the core shell. It detects an existing labwc or Hyprland setup where possible.

You may also specify these choices on the command line; see Installation options.

After installation:

labwc: Log out and back in so Quickshell starts from the labwc autostart file.
Hyprland: The installer adds a Quickshell configuration snippet and sources it from hyprland.conf. If Hyprland is already running, it attempts to reload the configuration.
No compositor integration: Start the shell manually or configure the printed keybinds and autostart command yourself.
zsh helpers: If installed, open a new terminal so srec, srecm, and the other aliases are available.

The installer can be run more than once. It backs up files before replacing them, merges the core Quickshell configuration instead of deleting existing files, and avoids adding duplicate keybinds or source lines where its checks detect them.

Installation options
bash install.sh --help

Option	Description
--compositor labwc	Configure labwc integration.
--compositor hyprland	Configure Hyprland integration.
--compositor none	Install without compositor integration and print the commands to bind yourself.
--core-only	Install the core Quickshell config and screen-time report script, plus compositor integration. Skip extras and zsh helpers.
--full	Install the full setup.
--side-by-side [NAME]	Install under ~/.config/quickshell/NAME rather than replacing the default shell directory. Defaults to viii-shell.
--no-system	Skip package installation and service management. --no-packages is an alias.
--no-zsh	Do not modify ~/.zshrc.
-y, --yes	Use detected values and safe defaults without asking questions.
-h, --help	Display help.
Examples

Install everything for labwc:

bash install.sh --compositor labwc


Install everything for Hyprland:

bash install.sh --compositor hyprland


Install only the core shell, retaining your existing setup:

bash install.sh --core-only


Install a separate shell alongside your existing Quickshell configuration:

bash install.sh --side-by-side


Start that separate shell with:

qs -c viii-shell


Use a custom side-by-side name:

bash install.sh --side-by-side work
qs -c work


Install without package changes or service management:

bash install.sh --no-system


Run unattended with labwc integration:

bash install.sh --compositor labwc --yes


Note: --yes suppresses interactive questions; it does not automatically imply --no-system or --no-zsh. Those behaviors require their respective options.

What the installer does
Checks that quickshell-export.tar.gz exists next to install.sh and can be listed by tar.
Detects the compositor where possible or asks you to select one.
Asks whether to install the full setup or core-only when running interactively without an explicit choice.
Offers a side-by-side installation when an existing ~/.config/quickshell/shell.qml is detected in interactive mode.
Extracts the archive into a temporary staging directory.
Installs the core Quickshell files, merging them with the existing configuration.
Installs supporting scripts and optional extras, backing up files before replacement.
Rewrites hardcoded /home/viii_fn paths in selected installed directories if your home directory differs.
Integrates the shell with labwc or Hyprland, or prints manual integration commands if you choose none.
Adds the zsh helper source line unless zsh integration is disabled or core-only mode is selected.
Attempts package installation and service setup last, so package failures do not prevent the configuration from being installed.
Backups

Files that the installer replaces are backed up under a timestamped directory:

~/quickshell-backup-YYYYMMDD-HHMMSS/


Existing files that are not being forcibly replaced are generally kept. The core Quickshell configuration is merged rather than cleared, so unrelated files in that directory are preserved.

The installer may replace the labwc configuration and Vent theme during a full labwc installation. Review the backup if you need to restore your previous setup.

What's included

The archive contains the core shell and supporting files listed below. Some are installed only in full mode, and some are applied only for a labwc installation.

Path	Purpose
~/.config/quickshell/	Main shell: Island, Music, Wi-Fi, Audio, DPI, Screen Time, Clock, Trim panel/window, Lock
~/.config/labwc/rc.xml	Keybinds and labwc configuration
~/.config/labwc/environment	labwc environment variables
~/.config/labwc/autostart	Starts Quickshell on login
~/.config/labwc/themerc-override	Window border colours
~/.config/wofi/	Launcher configuration and styling
~/.local/bin/screentime-report	Reads screen-time logs for the panel
~/.local/bin/clean.sh	System cleanup script, exposed through the clean alias
~/.local/bin/screenshot	Screenshot helper
~/.local/share/themes/Vent/	labwc/Openbox window theme
~/.local/state/quickshell-clock	Saved clock widget position
~/.config/viii-shell/custom.zsh	srec, srecm, and shell aliases
~/.config/hypr/viii-shell.conf	Generated Hyprland startup and keybind configuration

The Hyprland snippet is generated by the installer rather than supplied as a static archive file. It is sourced from ~/.config/hypr/hyprland.conf when that file exists.

Core-only versus full installation

Core-only (--core-only) installs:

The Quickshell configuration.
~/.local/bin/screentime-report.
An empty screen-time history directory, if needed.
The clock widget state, if it is present in the archive and not already installed.
Compositor keybinds and autostart integration.

It skips the Wofi configuration, cleanup and screenshot scripts, Vent theme installation, and zsh helpers.

Full installation adds the optional extras. A full labwc installation also restores the archived labwc configuration files and Vent theme.

Deliberately not included
Screen-time history: ~/.local/share/screentime/ is not shipped. Each machine starts with its own history.
Git *.sample hook files from the Quickshell configuration repository.
Your existing ~/.zshrc. The installer appends a source line instead of replacing the file.
Keybinds

The installer configures the following bindings for labwc and Hyprland:

Keys	Action
Super + M	Music panel
Super + I	Wi-Fi panel
Super + O	Audio output panel
Super + J	DPI scale panel
Super + U	Screen-time panel
Super + C	Clock widget

These invoke Quickshell IPC commands such as:

qs ipc call music toggle
qs ipc call wifi toggle
qs ipc call audio toggle
qs ipc call dpi toggle
qs ipc call screentime toggle
qs ipc call clock toggle


For a side-by-side installation, the generated commands use qs -c NAME so they target the selected shell.

labwc

The installer adds missing keybinds to ~/.config/labwc/rc.xml and adds the shell startup command to ~/.config/labwc/autostart.

If a key is already bound to another command, the installer skips that binding and prints a warning. It reloads labwc when possible.

Hyprland

The installer generates:

~/.config/hypr/viii-shell.conf


It adds an exec-once startup entry and the Super-key bindings, then sources the snippet from hyprland.conf if that file exists and does not already source it.

If a binding conflicts with an existing binding in hyprland.conf, the generated entry is commented out rather than enabled. If the main configuration does not exist, you must add the source line yourself:

source = ~/.config/hypr/viii-shell.conf

No compositor integration

With --compositor none, the installer leaves compositor integration to you and prints the commands needed for keybinds and startup.

zsh helpers

In a full installation, unless --no-zsh is specified, the installer adds this line to the end of ~/.zshrc if it is not already present:

source ~/.config/viii-shell/custom.zsh


The installer backs up .zshrc before making that change. It does not replace the file.

Command	What it does
srec	Records the full screen to ~/Videos/Screenclips/clip_<timestamp>.mp4
srecm	Records a mouse-selected screen region
reshell	Restarts Quickshell
rebar	Restarts Waybar
clean	Runs ~/.local/bin/clean.sh
note	Opens ~/Documents/note.txt in micro
keybind	Prints the labwc rc.xml

Recording starts with an .mkv file and converts to .mp4 when you stop with Ctrl+C. If conversion fails, the .mkv is retained.

Because the source line is appended to the end of .zshrc, aliases defined by custom.zsh can override earlier aliases with the same names.

Side-by-side note: the installer adds a reshell override for the selected named shell when it detects the custom zsh helper file. Check your resulting custom.zsh if you maintain multiple shell configurations.

Requirements
Arch Linux.
Quickshell, from the official repositories or the AUR.
labwc, Hyprland, or another environment where you will configure shell startup and keybinds yourself.
zsh for the optional shell helpers.
NetworkManager for the Wi-Fi panel.
PipeWire, PipeWire PulseAudio compatibility, and WirePlumber for audio functionality.

The installer attempts to install Quickshell if qs is not available. It tries the official quickshell package first, then quickshell-git through paru or yay if available.

Packages

The installer requests the following core packages:

curl networkmanager libpulse wlr-randr pipewire pipewire-pulse
pipewire-audio wireplumber playerctl brightnessctl python ffmpeg
qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg
qt6-svg qt6-wayland


A full installation also requests:

papirus-icon-theme wofi zenity micro wf-recorder slurp grim wl-clipboard


Package installation is skipped with --no-system. The Quickshell installation attempt is also skipped in that mode.

Services

Unless --no-system is specified, the installer attempts to:

Enable NetworkManager if no supported competing network manager is running.
Leave NetworkManager alone if it is already active.
Avoid enabling NetworkManager when iwd, systemd-networkd, or dhcpcd is active.
Enable the PipeWire, PipeWire PulseAudio compatibility, and WirePlumber user services.

Service failures produce warnings rather than stopping the already-installed configuration.

Troubleshooting

Nothing appears after login.

Check that the compositor starts the correct shell. For labwc, inspect ~/.config/labwc/autostart. For Hyprland, inspect ~/.config/hypr/viii-shell.conf and confirm that hyprland.conf sources it.

Try starting the default shell manually:

setsid qs &


For a side-by-side installation:

setsid qs -c viii-shell &


Check terminal output for errors.

Wi-Fi panel is empty.

The panel uses NetworkManager through nmcli. Check that NetworkManager is active:

systemctl is-active NetworkManager
nmcli device status


If another network manager is running, the installer deliberately avoids enabling NetworkManager. Switch to NetworkManager or adapt the panel to your existing networking setup.

Audio controls do not work.

Check the PipeWire and WirePlumber user services:

systemctl --user status pipewire pipewire-pulse wireplumber
pactl info


A keybind does nothing.

For labwc, reload the configuration:

labwc -r


Then test Quickshell IPC directly:

qs ipc call clock toggle


For Hyprland, check for commented-out bindings in ~/.config/hypr/viii-shell.conf and reload:

hyprctl reload


An existing configuration was overwritten.

Look in the latest ~/quickshell-backup-* directory. The installer backs up files before replacing them.

Quickshell is not found.

Try installing it from the official repositories:

sudo pacman -S quickshell


If the package is unavailable for your setup, install quickshell-git from the AUR using paru or yay.

I want to reinstall without changing system packages or services.

Use:

bash install.sh --no-system


I want to keep my existing Quickshell setup.

Use:

bash install.sh --side-by-side


The named shell is installed under ~/.config/quickshell/viii-shell/ and can be started with qs -c viii-shell.

Rebuilding the archive

Run this on the original laptop after changing your setup. It creates an updated archive in ~/viii-shell/.

mkdir -p ~/viii-shell /tmp/viii-stage/.config/viii-shell

# Extract only the custom-command block from .zshrc.
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


Verify that no screen-time history was included:

if tar tzf ~/viii-shell/quickshell-export.tar.gz \
  | grep -qE '(^|/)\.local/share/screentime/'; then
  echo "!! Screen-time history leaked into the archive"
else
  echo "OK: no screen-time history in the archive"
fi


The # --- CUSTOM COMMANDS --- and # --- END OF CUSTOM COMMANDS --- marker lines in .zshrc must remain intact for the extraction command to work.

The archive is intended to contain configuration and supporting scripts, not machine-specific screen-time history.

Notes
A full labwc install restores the archived labwc configuration and Vent theme; review the backup first if you have heavily customized them.
A core-only install is intended for people who already maintain their own launcher, scripts, theme, and shell helpers.
A side-by-side install is the safest option if you want to keep your default Quickshell configuration.
Use --no-system when you only want to restore configuration and do not want the installer to manage packages or services.
