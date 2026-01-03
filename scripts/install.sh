#!/bin/bash
# GDriveBackupper Installation Script
# Creates symlinks and enables systemd timers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Directories
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.local/config"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
STATE_DIR="${HOME}/.local/state/btrfs-backup"

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Create necessary directories
create_directories() {
    log_info "Creating directories..."
    mkdir -p "$BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SYSTEMD_USER_DIR"
    mkdir -p "$STATE_DIR"
    log_info "Directories created"
}

# Install configuration files
install_config() {
    log_info "Installing configuration files to $CONFIG_DIR..."
    
    # backup.env
    if [[ -f "$CONFIG_DIR/backup.env" ]]; then
        log_info "  backup.env already exists, skipping (preserving user settings)"
    else
        cp "$PROJECT_ROOT/config/backup.env" "$CONFIG_DIR/backup.env"
        log_info "  Copied: backup.env"
    fi
    
    # exclude-patterns.txt
    if [[ -f "$CONFIG_DIR/exclude-patterns.txt" ]]; then
        log_info "  exclude-patterns.txt already exists, skipping"
    else
        cp "$PROJECT_ROOT/config/exclude-patterns.txt" "$CONFIG_DIR/exclude-patterns.txt"
        log_info "  Copied: exclude-patterns.txt"
    fi
}

# Create symlinks for scripts
install_scripts() {
    log_info "Installing scripts to $BIN_DIR..."
    
    # btrfs-cloud-backup
    if [[ -L "$BIN_DIR/btrfs-cloud-backup" ]]; then
        rm "$BIN_DIR/btrfs-cloud-backup"
    fi
    ln -sf "$PROJECT_ROOT/scripts/btrfs-cloud-backup" "$BIN_DIR/btrfs-cloud-backup"
    chmod +x "$PROJECT_ROOT/scripts/btrfs-cloud-backup"
    log_info "  Linked: btrfs-cloud-backup"
    
    # project-backup
    if [[ -L "$BIN_DIR/project-backup" ]]; then
        rm "$BIN_DIR/project-backup"
    fi
    ln -sf "$PROJECT_ROOT/scripts/project-backup" "$BIN_DIR/project-backup"
    chmod +x "$PROJECT_ROOT/scripts/project-backup"
    log_info "  Linked: project-backup"
    
    # project-restore
    if [[ -L "$BIN_DIR/project-restore" ]]; then
        rm "$BIN_DIR/project-restore"
    fi
    ln -sf "$PROJECT_ROOT/scripts/project-restore" "$BIN_DIR/project-restore"
    chmod +x "$PROJECT_ROOT/scripts/project-restore"
    log_info "  Linked: project-restore"
    
    # setup-rclone-crypt
    if [[ -L "$BIN_DIR/setup-rclone-crypt" ]]; then
        rm "$BIN_DIR/setup-rclone-crypt"
    fi
    ln -sf "$PROJECT_ROOT/scripts/setup-rclone-crypt" "$BIN_DIR/setup-rclone-crypt"
    chmod +x "$PROJECT_ROOT/scripts/setup-rclone-crypt"
    log_info "  Linked: setup-rclone-crypt"
}

# Create symlinks for systemd units
install_systemd_units() {
    log_info "Installing systemd units to $SYSTEMD_USER_DIR..."
    
    local units=(
        "btrfs-backup.service"
        "btrfs-backup.timer"
        "rclone-gdrive.service"
        "project-backup.service"
        "project-backup.timer"
    )
    
    for unit in "${units[@]}"; do
        if [[ -L "$SYSTEMD_USER_DIR/$unit" ]]; then
            rm "$SYSTEMD_USER_DIR/$unit"
        fi
        ln -sf "$PROJECT_ROOT/systemd/$unit" "$SYSTEMD_USER_DIR/$unit"
        log_info "  Linked: $unit"
    done
    
    # Reload systemd
    systemctl --user daemon-reload
    log_info "Systemd daemon reloaded"
}

# Enable and start timers
enable_timers() {
    log_info "Enabling systemd timers..."
    
    # Enable btrfs-backup timer
    systemctl --user enable btrfs-backup.timer
    systemctl --user start btrfs-backup.timer
    log_info "  Enabled: btrfs-backup.timer"
    
    # Enable project-backup timer
    systemctl --user enable project-backup.timer
    systemctl --user start project-backup.timer
    log_info "  Enabled: project-backup.timer"
    
    # Enable rclone-gdrive service (optional, for FUSE mount)
    # Uncomment if you want the Google Drive mount to start automatically
    # systemctl --user enable rclone-gdrive.service
    # log_info "  Enabled: rclone-gdrive.service"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local errors=0
    
    # Check script symlinks
    for script in btrfs-cloud-backup project-backup project-restore setup-rclone-crypt; do
        if [[ -L "$BIN_DIR/$script" ]]; then
            log_info "  ✓ $script symlink exists"
        else
            log_error "  ✗ $script symlink missing"
            ((errors++))
        fi
    done
    
    # Check systemd units
    for unit in btrfs-backup.service btrfs-backup.timer rclone-gdrive.service project-backup.service project-backup.timer; do
        if [[ -L "$SYSTEMD_USER_DIR/$unit" ]]; then
            log_info "  ✓ $unit symlink exists"
        else
            log_error "  ✗ $unit symlink missing"
            ((errors++))
        fi
    done
    
    # Check timer status
    if systemctl --user is-enabled btrfs-backup.timer &>/dev/null; then
        log_info "  ✓ btrfs-backup.timer is enabled"
    else
        log_warn "  ⚠ btrfs-backup.timer is not enabled"
    fi
    
    if systemctl --user is-enabled project-backup.timer &>/dev/null; then
        log_info "  ✓ project-backup.timer is enabled"
    else
        log_warn "  ⚠ project-backup.timer is not enabled"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "Installation verified successfully!"
    else
        log_error "Installation completed with $errors error(s)"
        return 1
    fi
}

# Show status
show_status() {
    echo ""
    log_info "Current timer status:"
    systemctl --user list-timers btrfs-backup.timer project-backup.timer --no-pager || true
    
    echo ""
    log_info "Next scheduled backups:"
    systemctl --user list-timers btrfs-backup.timer project-backup.timer --no-pager 2>/dev/null | grep -E "NEXT|btrfs|project" || echo "  Timers not active"
}

# Main
main() {
    echo "========================================"
    echo "GDriveBackupper Installation"
    echo "========================================"
    echo ""
    
    create_directories
    install_config
    install_scripts
    install_systemd_units
    enable_timers
    verify_installation
    show_status
    
    echo ""
    echo "========================================"
    log_info "Installation complete!"
    echo "========================================"
    echo ""
    echo "To setup encrypted BTRFS backups:"
    echo "  setup-rclone-crypt"
    echo ""
    echo "To run a manual BTRFS backup (encrypted by default):"
    echo "  sudo btrfs-cloud-backup"
    echo ""
    echo "To run a manual project backup:"
    echo "  project-backup backup"
    echo ""
    echo "To check backup logs:"
    echo "  tail -f $STATE_DIR/backup.log"
    echo ""
    echo "To uninstall:"
    echo "  $PROJECT_ROOT/scripts/uninstall.sh"
}

main "$@"
