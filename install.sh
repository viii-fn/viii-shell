#!/usr/bin/env bash
# Run with: bash install.sh   (keep it next to quickshell-export.tar.gz)
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$HERE/quickshell-export.tar.gz"
BACKUP="$HOME/quickshell-backup-$(date +%Y%m%d-%H%M%S)"
RC="$HOME/.config/labwc/rc.xml"

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
for t in .config/quickshell .config/labwc/themerc-override .config/labwc/autostart \
         .config/labwc/rc.xml .local/bin/screentime-report \
         .local/share/themes/Vent .themes/Vent; do
    if [ -e "$t" ]; then cp -a --parents "$t" "$BACKUP"; fi
done

# ---------- 3. Unpack into the right folders ----------
say "Unpacking"
tar xzf "$ARCHIVE" -C "$HOME"
if [ -f "$HOME/.local/bin/screentime-report" ]; then chmod +x "$HOME/.local/bin/screentime-report"; fi

# ---------- 4. Quickshell keybinds in rc.xml (only adds missing ones) ----------
say "Adding Quickshell keybinds to rc.xml"
mkdir -p "$(dirname "$RC")"
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

BINDS=(
    "W-m|qs ipc call music toggle"
    "W-i|qs ipc call wifi toggle"
    "W-o|qs ipc call audio toggle"
    "W-j|qs ipc call dpi toggle"
    "W-u|qs ipc call screentime toggle"
    "W-c|qs ipc call clock toggle"
)

BLOCK=""
for entry in "${BINDS[@]}"; do
    key="${entry%%|*}"
    cmd="${entry#*|}"
    if grep -qF "command=\"$cmd\"" "$RC"; then
        continue
    elif grep -qF "key=\"$key\"" "$RC"; then
        warn "$key is already bound to something else, skipped: $cmd"
    else
        BLOCK+="    <keybind key=\"$key\">"$'\n'
        BLOCK+="      <action name=\"Execute\" command=\"$cmd\" />"$'\n'
        BLOCK+="    </keybind>"$'\n'
    fi
done

if [ -n "$BLOCK" ]; then
    grep -q '</keyboard>' "$RC" || die "rc.xml has no </keyboard> section, add the keybinds by hand"
    BLK="$BLOCK" awk '/<\/keyboard>/ && !d { printf "%s", ENVIRON["BLK"]; d=1 } { print }' "$RC" > "$RC.new"
    mv "$RC.new" "$RC"
fi

# ---------- 5. Reload labwc if it is running ----------
if pgrep -x labwc > /dev/null; then
    labwc -r || warn "Could not reload labwc, log out and back in instead"
fi

# ---------- 6. Installs, last ----------
say "Installing packages"
sudo pacman -S --needed --noconfirm \
    curl networkmanager libpulse wlr-randr pipewire pipewire-pulse wireplumber papirus-icon-theme \
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
echo "Log out and back in so labwc starts Quickshell from autostart."
