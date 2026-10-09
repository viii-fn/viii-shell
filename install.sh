#!/usr/bin/env bash
# File: ~/viii-shell/install.sh
# Run with: bash install.sh            (keep it next to quickshell-export.tar.gz)
# Help:     bash install.sh --help
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$HERE/quickshell-export.tar.gz"
BACKUP="$HOME/quickshell-backup-$(date +%Y%m%d-%H%M%S)"
OLDHOME="/home/viii_fn"   # home dir the archive was made on
STAGE=""

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
trap 'die "Failed at line $LINENO"' ERR
trap '[ -n "$STAGE" ] && rm -rf "$STAGE"' EXIT

usage() {
cat << 'EOF'
Usage: bash install.sh [options]

With no options the installer detects your compositor and asks a few questions.

  --compositor labwc|hyprland|none
        Which compositor to wire the shell into. "none" installs the shell
        only and prints the keybind commands for you to bind yourself.
  --core-only
        Install ONLY the Quickshell config and the screentime-report script
        (plus keybinds/autostart for your compositor). Skips wofi, themes,
        clean.sh, screenshot, and the srec/srecm zsh helpers.
  --side-by-side [NAME]
        Install into ~/.config/quickshell/NAME (default: viii-shell) instead
        of replacing ~/.config/quickshell. Start it with: qs -c NAME
        Use this if you already have your own Quickshell setup.
  --no-system
        Do not install packages or enable services.
  --no-zsh
        Do not touch ~/.zshrc.
  -y, --yes
        Never ask questions; use detected values and safe defaults.
  -h, --help
        Show this help.
EOF
}

# ---------- Options ----------
COMPOSITOR=""
CORE_ONLY=""        # "" = ask / default, 0 = full, 1 = core only
SIDE_NAME=""
NO_SYSTEM=0
NO_ZSH=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --compositor)
            [ -n "${2:-}" ] || die "--compositor needs a value: labwc, hyprland or none"
            COMPOSITOR="$2"; shift 2 ;;
        --core-only)    CORE_ONLY=1; shift ;;
        --full)         CORE_ONLY=0; shift ;;
        --side-by-side)
            if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then SIDE_NAME="$2"; shift 2
            else SIDE_NAME="viii-shell"; shift; fi ;;
        --no-system|--no-packages) NO_SYSTEM=1; shift ;;
        --no-zsh)       NO_ZSH=1; shift ;;
        -y|--yes)       ASSUME_YES=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *) usage; die "Unknown option: $1" ;;
    esac
done

case "$COMPOSITOR" in ""|labwc|hyprland|none) ;; *) die "--compositor must be labwc, hyprland or none" ;; esac
if [ -n "$SIDE_NAME" ] && ! [[ "$SIDE_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    die "Side-by-side name may only contain letters, numbers, . _ -"
fi

INTERACTIVE=0
if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then INTERACTIVE=1; fi

ask() {  # ask "prompt" default
    local ans=""
    read -r -p "$1" ans || ans=""
    printf '%s' "${ans:-$2}"
}

detect_compositor() {
    if pgrep -x Hyprland > /dev/null 2>&1 || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then echo hyprland
    elif pgrep -x labwc > /dev/null 2>&1; then echo labwc
    elif [ -d "$HOME/.config/hypr" ]; then echo hyprland
    elif [ -d "$HOME/.config/labwc" ]; then echo labwc
    fi
}

backup() {  # backup <path relative to $HOME>
    if [ -e "$HOME/$1" ]; then
        mkdir -p "$BACKUP"
        (cd "$HOME" && cp -a --parents "$1" "$BACKUP")
    fi
    return 0
}

# ---------- 1. Checks ----------
say "Checking the archive"
[ -f "$ARCHIVE" ] || die "quickshell-export.tar.gz not found next to install.sh"
tar tzf "$ARCHIVE" > /dev/null || die "The archive is corrupt"

# ---------- 2. Questions (only when run in a terminal without flags) ----------
if [ -z "$COMPOSITOR" ]; then
    DETECTED="$(detect_compositor || true)"
    if [ "$INTERACTIVE" -eq 1 ]; then
        echo "Which compositor are you using?"
        echo "  1) labwc"
        echo "  2) Hyprland"
        echo "  3) Something else / none (install the shell only, I'll bind keys myself)"
        case "$DETECTED" in labwc) DEF=1 ;; hyprland) DEF=2 ;; *) DEF=3 ;; esac
        case "$(ask "Choose [1-3, default $DEF]: " "$DEF")" in
            1) COMPOSITOR=labwc ;; 2) COMPOSITOR=hyprland ;; *) COMPOSITOR=none ;;
        esac
    elif [ -n "$DETECTED" ]; then
        COMPOSITOR="$DETECTED"
    else
        warn "Could not detect a compositor, installing the shell only (use --compositor to choose)"
        COMPOSITOR=none
    fi
fi

if [ -z "$CORE_ONLY" ]; then
    if [ "$INTERACTIVE" -eq 1 ]; then
        echo
        echo "What should be installed?"
        echo "  1) Everything (shell, wofi config, scripts, zsh helpers$([ "$COMPOSITOR" = labwc ] && echo ', labwc config + theme'))"
        echo "  2) Only the Quickshell config (core), I have my own setup for the rest"
        case "$(ask "Choose [1-2, default 1]: " 1)" in 2) CORE_ONLY=1 ;; *) CORE_ONLY=0 ;; esac
    else
        CORE_ONLY=0
    fi
fi

if [ -z "$SIDE_NAME" ] && [ "$INTERACTIVE" -eq 1 ] && [ -f "$HOME/.config/quickshell/shell.qml" ]; then
    echo
    echo "You already have a Quickshell config at ~/.config/quickshell."
    echo "  1) Back it up and install over it"
    echo "  2) Install side by side as 'viii-shell' (start it with: qs -c viii-shell)"
    case "$(ask "Choose [1-2, default 2]: " 2)" in 1) ;; *) SIDE_NAME="viii-shell" ;; esac
fi

QS_CMD="qs"
if [ -n "$SIDE_NAME" ]; then QS_CMD="qs -c $SIDE_NAME"; fi
QS_REL=".config/quickshell"
if [ -n "$SIDE_NAME" ]; then QS_REL=".config/quickshell/$SIDE_NAME"; fi

# Replace the whole labwc config only for a full labwc install that is not side by side
REPLACE_LABWC=0
if [ "$COMPOSITOR" = labwc ] && [ "$CORE_ONLY" -eq 0 ] && [ -z "$SIDE_NAME" ]; then REPLACE_LABWC=1; fi

say "Plan: compositor=$COMPOSITOR, $([ "$CORE_ONLY" -eq 1 ] && echo core-only || echo full), quickshell -> ~/$QS_REL"

# ---------- 3. Unpack to a staging folder ----------
STAGE="$(mktemp -d)"
tar xzf "$ARCHIVE" -C "$STAGE"
[ -d "$STAGE/.config/quickshell" ] || die "Archive has no .config/quickshell"

put() {  # put <relative path> <force 0|1>  (copy from the archive; keep existing unless forced)
    local rel="$1" force="$2" src="$STAGE/$1" dst="$HOME/$1"
    [ -e "$src" ] || return 0
    if [ -e "$dst" ] && [ "$force" != 1 ]; then warn "Kept your existing ~/$rel"; return 0; fi
    backup "$rel"
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -a "$src" "$dst"
}

# ---------- 4. Core files ----------
say "Installing the Quickshell config to ~/$QS_REL"
backup "$QS_REL"
mkdir -p "$HOME/$QS_REL"
cp -a "$STAGE/.config/quickshell/." "$HOME/$QS_REL/"   # merges, never deletes your other files

put .local/bin/screentime-report 1
mkdir -p "$HOME/.local/share/screentime"   # screen-time history is NOT shipped; this machine starts its own
put .local/state/quickshell-clock 0

# ---------- 5. Extras (skipped with --core-only) ----------
if [ "$CORE_ONLY" -eq 0 ]; then
    say "Installing extras (wofi, scripts, zsh helpers)"
    FORCE=0; if [ "$REPLACE_LABWC" -eq 1 ]; then FORCE=1; fi
    put .config/wofi "$FORCE"
    put .local/bin/clean.sh "$FORCE"
    put .local/bin/screenshot "$FORCE"
    put .config/viii-shell/custom.zsh 1
    if [ -n "$SIDE_NAME" ] && [ -f "$HOME/.config/viii-shell/custom.zsh" ]; then
        printf "\n# side-by-side install: restart this shell, not the default one\nalias reshell='killall qs; setsid %s >/dev/null 2>&1 &!'\n" "$QS_CMD" \
            >> "$HOME/.config/viii-shell/custom.zsh"
    fi
    if [ "$REPLACE_LABWC" -eq 1 ]; then
        put .local/share/themes/Vent 1
    fi
fi

# ---------- 6. Fix hardcoded home paths (only if the username differs) ----------
if [ "$HOME" != "$OLDHOME" ]; then
    say "Rewriting $OLDHOME to $HOME in the installed files"
    for d in "$QS_REL" .config/labwc .config/wofi .config/viii-shell .local/bin; do
        if [ -d "$HOME/$d" ]; then
            grep -rlI --exclude-dir=.git "$OLDHOME" "$HOME/$d" 2>/dev/null | xargs -r sed -i "s#$OLDHOME#$HOME#g" || true
        fi
    done
fi

# ---------- 7. Compositor wiring ----------
# key | Quickshell IPC target
BINDS=( "M|music" "I|wifi" "O|audio" "J|dpi" "U|screentime" "C|clock" )

integrate_labwc() {
    local RC="$HOME/.config/labwc/rc.xml" AUTO="$HOME/.config/labwc/autostart"
    mkdir -p "$HOME/.config/labwc"
    backup .config/labwc/rc.xml
    backup .config/labwc/autostart
    if [ ! -f "$RC" ]; then
        warn "No rc.xml found, creating a minimal one"
        cat > "$RC" << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<labwc_config>
  <keyboard>
    <default />
  </keyboard>
</labwc_config>
XML
    fi
    local BLOCK="" entry key name cmd lk
    for entry in "${BINDS[@]}"; do
        key="${entry%%|*}"; name="${entry#*|}"
        cmd="$QS_CMD ipc call $name toggle"
        lk="W-$(printf '%s' "$key" | tr 'A-Z' 'a-z')"
        if grep -qF "command=\"$cmd\"" "$RC"; then
            continue
        elif grep -qF "key=\"$lk\"" "$RC"; then
            warn "$lk is already bound to something else in rc.xml, skipped: $cmd"
        else
            BLOCK+="    <keybind key=\"$lk\">"$'\n'
            BLOCK+="      <action name=\"Execute\" command=\"$cmd\" />"$'\n'
            BLOCK+="    </keybind>"$'\n'
        fi
    done
    if [ -n "$BLOCK" ]; then
        grep -q '</keyboard>' "$RC" || die "rc.xml has no </keyboard> section, add the keybinds by hand"
        BLK="$BLOCK" awk '/<\/keyboard>/ && !d { printf "%s", ENVIRON["BLK"]; d=1 } { print }' "$RC" > "$RC.new"
        mv "$RC.new" "$RC"
    fi
    touch "$AUTO"
    if ! grep -qE "^[[:space:]]*(setsid )?${QS_CMD}([[:space:]]|&|$)" "$AUTO"; then
        printf '%s &\n' "$QS_CMD" >> "$AUTO"
    fi
    if pgrep -x labwc > /dev/null 2>&1; then
        labwc -r || warn "Could not reload labwc, log out and back in instead"
    fi
}

integrate_hyprland() {
    local DIR="$HOME/.config/hypr" MAIN="$HOME/.config/hypr/hyprland.conf" SNIP="$HOME/.config/hypr/viii-shell.conf"
    mkdir -p "$DIR"
    backup .config/hypr/viii-shell.conf
    backup .config/hypr/hyprland.conf
    local entry key name cmd
    {
        echo "# Generated by viii-shell install.sh. Edit freely; re-running the installer rewrites it."
        echo "# Bindings that clash with ones in hyprland.conf are written commented-out below."
        if [ -f "$MAIN" ] && [ -z "$SIDE_NAME" ] && grep -qE "^[[:space:]]*exec(-once)?[[:space:]]*=.*(\bqs\b|quickshell)" "$MAIN"; then
            echo "# exec-once = $QS_CMD   # skipped: hyprland.conf already starts Quickshell"
        else
            echo "exec-once = $QS_CMD"
        fi
        echo
        for entry in "${BINDS[@]}"; do
            key="${entry%%|*}"; name="${entry#*|}"
            cmd="$QS_CMD ipc call $name toggle"
            if [ -f "$MAIN" ] && grep -qiE "^[[:space:]]*bind[a-z]*[[:space:]]*=[^,]*,[[:space:]]*${key}[[:space:]]*," "$MAIN"; then
                echo "# bind = SUPER, $key, exec, $cmd   # skipped: a $key bind already exists in hyprland.conf"
                warn "Super+$key is already used in hyprland.conf, left commented out in viii-shell.conf ($name panel)"
            else
                echo "bind = SUPER, $key, exec, $cmd"
            fi
        done
    } > "$SNIP"
    if [ -f "$MAIN" ]; then
        if ! grep -qF 'viii-shell.conf' "$MAIN"; then
            printf '\n# viii-shell (Quickshell)\nsource = ~/.config/hypr/viii-shell.conf\n' >> "$MAIN"
        fi
    else
        warn "No ~/.config/hypr/hyprland.conf found. Add this line to your Hyprland config yourself:"
        warn "    source = ~/.config/hypr/viii-shell.conf"
    fi
    if command -v hyprctl > /dev/null 2>&1 && { pgrep -x Hyprland > /dev/null 2>&1 || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; }; then
        hyprctl reload > /dev/null 2>&1 || warn "Could not reload Hyprland, run: hyprctl reload"
    fi
}

case "$COMPOSITOR" in
    labwc)
        if [ "$REPLACE_LABWC" -eq 1 ]; then
            say "Restoring the labwc config and theme"
            for f in rc.xml environment autostart themerc-override; do put ".config/labwc/$f" 1; done
        else
            say "Adding Quickshell keybinds and autostart to your labwc config"
            integrate_labwc
        fi
        ;;
    hyprland)
        say "Writing ~/.config/hypr/viii-shell.conf and sourcing it from hyprland.conf"
        integrate_hyprland
        ;;
    none)
        say "No compositor selected. Bind these keys yourself:"
        for entry in "${BINDS[@]}"; do echo "  Super+${entry%%|*}  ->  $QS_CMD ipc call ${entry#*|} toggle"; done
        echo "  And start the shell on login with: $QS_CMD"
        ;;
esac

# ---------- 8. zsh helpers ----------
if [ "$NO_ZSH" -eq 0 ] && [ "$CORE_ONLY" -eq 0 ] && [ -f "$HOME/.config/viii-shell/custom.zsh" ]; then
    say "Adding srec/srecm and aliases to ~/.zshrc"
    backup .zshrc
    touch "$HOME/.zshrc"
    SRC_LINE='source ~/.config/viii-shell/custom.zsh'
    if ! grep -qxF "$SRC_LINE" "$HOME/.zshrc"; then
        printf '\n# viii-shell helpers (srec, srecm, aliases)\n%s\n' "$SRC_LINE" >> "$HOME/.zshrc"
    fi
fi

# ---------- 9. Packages and services, last ----------
if [ "$NO_SYSTEM" -eq 0 ]; then
    say "Installing packages"
    CORE_PKGS=(curl networkmanager libpulse wlr-randr pipewire pipewire-pulse pipewire-audio wireplumber
               playerctl brightnessctl python ffmpeg
               qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-wayland)
    EXTRA_PKGS=(papirus-icon-theme wofi zenity micro wf-recorder slurp grim wl-clipboard)
    PKGS=("${CORE_PKGS[@]}")
    if [ "$CORE_ONLY" -eq 0 ]; then PKGS+=("${EXTRA_PKGS[@]}"); fi
    sudo pacman -S --needed --noconfirm "${PKGS[@]}" \
        || warn "Some packages failed. Try: sudo pacman -Syu, then run this script again"

    if ! command -v qs > /dev/null 2>&1; then
        if ! sudo pacman -S --needed --noconfirm quickshell; then
            if command -v paru > /dev/null; then
                paru -S --needed --noconfirm quickshell-git || warn "AUR install of quickshell failed"
            elif command -v yay > /dev/null; then
                yay -S --needed --noconfirm quickshell-git || warn "AUR install of quickshell failed"
            else
                warn "Quickshell is not in your repos and no AUR helper was found. Install quickshell-git from the AUR."
            fi
        fi
    fi

    say "Enabling services"
    if systemctl is-active --quiet NetworkManager; then
        :
    elif systemctl is-active --quiet iwd || systemctl is-active --quiet systemd-networkd || systemctl is-active --quiet dhcpcd; then
        warn "Another network manager is running, so NetworkManager was NOT enabled. The Wi-Fi panel needs it."
    else
        sudo systemctl enable --now NetworkManager || warn "Could not enable NetworkManager"
    fi
    systemctl --user enable --now pipewire pipewire-pulse wireplumber || warn "Could not enable PipeWire services"
fi

# ---------- 10. Done ----------
say "Done"
if [ -d "$BACKUP" ] && [ -n "$(ls -A "$BACKUP")" ]; then echo "Replaced files were backed up to: $BACKUP"; else rmdir "$BACKUP" 2>/dev/null || true; fi
case "$COMPOSITOR" in
    labwc)    echo "Log out and back in so labwc starts Quickshell from autostart." ;;
    hyprland) echo "To try it now without logging out, run:  setsid $QS_CMD >/dev/null 2>&1 &" ;;
    none)     echo "Start it with:  $QS_CMD" ;;
esac
if [ "$CORE_ONLY" -eq 0 ] && [ "$NO_ZSH" -eq 0 ]; then echo "Open a new terminal so srec/srecm load."; fi
