cat > ~/viii-shell/install.sh << 'INSTALL_EOF'
#!/usr/bin/env bash
# File: ~/viii-shell/install.sh
# Run with: bash install.sh   (keep it next to quickshell-export.tar.gz)
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$HERE/quickshell-export.tar.gz"
BACKUP="$HOME/quickshell-backup-$(date +%Y%m%d-%H%M%S)"
OLDHOME="/home/viii_fn"   # home dir the archive was made on

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
trap 'die "Failed at line $LINENO"' ERR

# ---------- 1. Checks ----------
say "Checking the archive"
[ -f "$ARCHIVE" ] || die "quickshell-export.tar.gz not found next to install.sh"
tar tzf "$ARCHIVE" > /dev/null || die "The archive is corrupt"

# ---------- 2. Back up whatever will be overwritten ----------
say "Backing up existing files to $BACKUP"
mkdir -p "$BACKUP"
cd "$HOME"
for t in .config/quickshell .config/wofi \
         .config/labwc/rc.xml .config/labwc/environment \
         .config/labwc/autostart .config/labwc/themerc-override \
         .config/viii-shell \
         .local/bin/screentime-report .local/bin/clean.sh .local/bin/screenshot \
         .local/share/themes/Vent .themes/Vent \
         .local/state/quickshell-clock; do
    if [ -e "$t" ]; then cp -a --parents "$t" "$BACKUP"; fi
done

# ---------- 3. Unpack into the right folders ----------
say "Unpacking"
tar xzf "$ARCHIVE" -C "$HOME"
chmod +x "$HOME/.local/bin/"{screentime-report,clean.sh,screenshot} 2>/dev/null || true

# Screen-time history is NOT in the archive: this laptop starts its own
mkdir -p "$HOME/.local/share/screentime"

# ---------- 4. Fix hardcoded home paths (only if the username differs) ----------
if [ "$HOME" != "$OLDHOME" ]; then
    say "Rewriting $OLDHOME to $HOME in the config files"
    grep -rlI --exclude-dir=.git "$OLDHOME" \
        "$HOME/.config/quickshell" "$HOME/.config/labwc" \
        "$HOME/.config/wofi" "$HOME/.config/viii-shell" "$HOME/.local/bin" 2>/dev/null \
        | xargs -r sed -i "s#$OLDHOME#$HOME#g"
fi

# ---------- 5. Hook the zsh helpers (srec, srecm, aliases) into ~/.zshrc ----------
say "Adding srec/srecm and aliases to ~/.zshrc"
touch "$HOME/.zshrc"
SRC_LINE='source ~/.config/viii-shell/custom.zsh'
if ! grep -qxF "$SRC_LINE" "$HOME/.zshrc"; then
    printf '\n# viii-shell helpers (srec, srecm, aliases)\n%s\n' "$SRC_LINE" >> "$HOME/.zshrc"
fi

# ---------- 6. Reload labwc if it is running ----------
if pgrep -x labwc > /dev/null; then
    labwc -r || warn "Could not reload labwc, log out and back in instead"
fi

# ---------- 7. Installs, last ----------
say "Installing packages"
sudo pacman -S --needed --noconfirm \
    curl networkmanager libpulse wlr-randr \
    pipewire pipewire-pulse pipewire-audio wireplumber \
    papirus-icon-theme wofi zenity micro \
    playerctl brightnessctl python ffmpeg \
    wf-recorder slurp grim wl-clipboard \
    qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-wayland \
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

say "Done"
if [ -d "$BACKUP" ] && [ -n "$(ls -A "$BACKUP")" ]; then echo "Replaced files were backed up to: $BACKUP"; else rmdir "$BACKUP" 2>/dev/null || true; fi
echo "Open a new terminal (for srec/srecm), then log out and back in so labwc starts Quickshell from autostart."
INSTALL_EOF
