#!/bin/bash
# GDriveBackupper Uninstallation Script
# Removes symlinks and disables systemd timers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
STATE_DIR="${HOME}/.local/state/btrfs-backup"

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Disable and stop timers
disable_timers() {
    log_info "Disabling systemd timers..."
    
    # Stop and disable btrfs-backup timer
    if systemctl --user is-active btrfs-backup.timer &>/dev/null; then
        systemctl --user stop btrfs-backup.timer
        log_info "  Stopped: btrfs-backup.timer"
    fi
    
    if systemctl --user is-enabled btrfs-backup.timer &>/dev/null; then
        systemctl --user disable btrfs-backup.timer
        log_info "  Disabled: btrfs-backup.timer"
    fi
    
    # Stop rclone-gdrive service if running
    if systemctl --user is-active rclone-gdrive.service &>/dev/null; then
        systemctl --user stop rclone-gdrive.service
        log_info "  Stopped: rclone-gdrive.service"
    fi
    
    if systemctl --user is-enabled rclone-gdrive.service &>/dev/null; then
        systemctl --user disable rclone-gdrive.service
        log_info "  Disabled: rclone-gdrive.service"
    fi
}

# Remove systemd unit symlinks
remove_systemd_units() {
    log_info "Removing systemd unit symlinks..."
    
    local units=(
        "btrfs-backup.service"
        "btrfs-backup.timer"
        "rclone-gdrive.service"
    )
    
    for unit in "${units[@]}"; do
        if [[ -L "$SYSTEMD_USER_DIR/$unit" ]]; then
            rm "$SYSTEMD_USER_DIR/$unit"
            log_info "  Removed: $unit"
        elif [[ -f "$SYSTEMD_USER_DIR/$unit" ]]; then
            log_warn "  $unit is a file, not a symlink - skipping (manual removal required)"
        else
            log_info "  $unit not found - skipping"
        fi
    done
    
    # Reload systemd
    systemctl --user daemon-reload
    log_info "Systemd daemon reloaded"
}

# Remove script symlinks
remove_scripts() {
    log_info "Removing script symlinks..."
    
    if [[ -L "$BIN_DIR/btrfs-cloud-backup" ]]; then
        rm "$BIN_DIR/btrfs-cloud-backup"
        log_info "  Removed: btrfs-cloud-backup"
    elif [[ -f "$BIN_DIR/btrfs-cloud-backup" ]]; then
        log_warn "  btrfs-cloud-backup is a file, not a symlink - skipping (manual removal required)"
    else
        log_info "  btrfs-cloud-backup not found - skipping"
    fi
}

# Optionally remove state directory
remove_state() {
    if [[ -d "$STATE_DIR" ]]; then
        echo ""
        read -p "Remove state directory ($STATE_DIR) including logs? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$STATE_DIR"
            log_info "State directory removed"
        else
            log_info "State directory preserved"
        fi
    fi
}

# Verify uninstallation
verify_uninstallation() {
    log_info "Verifying uninstallation..."
    
    local remaining=0
    
    # Check script symlink
    if [[ -e "$BIN_DIR/btrfs-cloud-backup" ]]; then
        log_warn "  ⚠ btrfs-cloud-backup still exists"
        ((remaining++))
    else
        log_info "  ✓ btrfs-cloud-backup removed"
    fi
    
    # Check systemd units
    for unit in btrfs-backup.service btrfs-backup.timer rclone-gdrive.service; do
        if [[ -e "$SYSTEMD_USER_DIR/$unit" ]]; then
            log_warn "  ⚠ $unit still exists"
            ((remaining++))
        else
            log_info "  ✓ $unit removed"
        fi
    done
    
    if [[ $remaining -eq 0 ]]; then
        log_info "Uninstallation verified successfully!"
    else
        log_warn "Some items could not be removed automatically"
    fi
}

# Main
main() {
    echo "========================================"
    echo "GDriveBackupper Uninstallation"
    echo "========================================"
    echo ""
    
    echo "This will:"
    echo "  - Disable and stop backup timers"
    echo "  - Remove symlinks from ~/.local/bin/"
    echo "  - Remove symlinks from ~/.config/systemd/user/"
    echo ""
    echo "This will NOT:"
    echo "  - Remove the project directory"
    echo "  - Remove backups from Google Drive"
    echo "  - Remove rclone configuration"
    echo ""
    
    read -p "Continue with uninstallation? [y/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo ""
    disable_timers
    remove_systemd_units
    remove_scripts
    remove_state
    verify_uninstallation
    
    echo ""
    echo "========================================"
    log_info "Uninstallation complete!"
    echo "========================================"
    echo ""
    echo "To reinstall, run:"
    echo "  ./scripts/install.sh"
}

main "$@"
