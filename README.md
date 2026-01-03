# GDriveBackupper

Automated backup system for CachyOS that backs up BTRFS snapshots and project folders to Google Drive.

## Overview

This project provides two backup systems:

1. **BTRFS System Backup**: Backs up system snapshots (created by Snapper) to Google Drive using `btrfs send` + `zstd` compression + `rclone crypt` (encrypted)
2. **Project Backup**: Backs up project folders with encryption using `restic` + `rclone`

Both backup systems run automatically via systemd timers and support encryption for data at rest.

## Directory Structure

```
GDriveBackupper/
├── scripts/
│   ├── btrfs-cloud-backup    # BTRFS snapshot backup script (supports encryption)
│   ├── project-backup        # Project folder backup script (restic)
│   ├── project-restore       # Interactive restore helper
│   ├── setup-rclone-crypt    # Setup script for encrypted BTRFS backups
│   ├── install.sh            # Installation script
│   └── uninstall.sh          # Uninstallation script
├── systemd/
│   ├── btrfs-backup.service  # Systemd service for BTRFS backup
│   ├── btrfs-backup.timer    # Timer for daily BTRFS backup (3 AM)
│   ├── project-backup.service # Systemd service for project backup
│   ├── project-backup.timer  # Timer for daily project backup (4 AM)
│   └── rclone-gdrive.service # Google Drive FUSE mount service
├── config/
│   ├── backup.env            # Configuration variables
│   └── exclude-patterns.txt  # Exclusion patterns for project backups
├── state/                    # Runtime state and logs (gitignored)
├── docs/                     # Documentation
│   ├── BACKUP-EVALUATION.md
│   ├── BACKUP-SETUP-SUMMARY.md
│   ├── cachyos-backup-setup.md
│   ├── ENCRYPTION-SETUP.md   # rclone crypt encryption guide
│   ├── MIGRATION-PLAN.md
│   ├── PROJECT-BACKUP-DESIGN.md
│   └── RESTIC-RECOVERY.md
└── README.md
```

## Prerequisites

- CachyOS (or Arch-based Linux)
- BTRFS filesystem with Snapper configured
- rclone configured with Google Drive remote (`K-Solutions:`)
- Required packages: `rclone`, `snapper`, `zstd`, `pv`, `restic`

## Installation

```bash
# Clone or navigate to the project
cd /mnt/sandisk_2tb/Projects/GDriveBackupper

# Run the installation script
./scripts/install.sh
```

The installation script will:
- Create symlinks for scripts in `~/.local/bin/`
- Create symlinks for systemd units in `~/.config/systemd/user/`
- Enable and start the backup timers (BTRFS at 3 AM, Projects at 4 AM)

### Setup Encrypted BTRFS Backups

After installation, set up encryption for BTRFS backups:

```bash
# Run the encryption setup script
setup-rclone-crypt
```

This uses the same password as restic (stored in `~/.config/restic/projects-password`).

## Uninstallation

```bash
./scripts/uninstall.sh
```

## Usage

### Manual Backup

```bash
# Run BTRFS backup manually (encrypted by default, requires sudo)
sudo btrfs-cloud-backup

# Run BTRFS backup without encryption
sudo btrfs-cloud-backup --unencrypted

# Run project backup manually
project-backup backup
```

### Project Backup Commands

```bash
# Run a backup
project-backup backup

# List all snapshots
project-backup snapshots

# Show repository statistics
project-backup stats

# Verify repository integrity
project-backup check

# Clean up old snapshots (based on retention policy)
project-backup prune

# Search for files in backups
project-backup find "*.py"

# Compare two snapshots
project-backup diff <snapshot-id-1> <snapshot-id-2>

# Restore a snapshot
project-backup restore <snapshot-id> /path/to/restore

# Interactive restore (easier)
project-restore
```

### Check Backup Status

```bash
# Check timer status
systemctl --user status btrfs-backup.timer
systemctl --user status project-backup.timer

# List all active timers
systemctl --user list-timers

# View recent backup logs
tail -f ~/.local/state/btrfs-backup/backup.log        # BTRFS backup
tail -f ~/.local/state/btrfs-backup/project-backup.log # Project backup

# List backups on Google Drive
sudo btrfs-cloud-backup --list                          # BTRFS snapshots (encrypted & unencrypted)
project-backup snapshots                                  # Project snapshots
```

### Restore from Backup

**BTRFS Restore**: See [docs/BACKUP-SETUP-SUMMARY.md](docs/BACKUP-SETUP-SUMMARY.md) for detailed restore procedures.

**Project Restore**: Use the interactive restore helper:
```bash
# Interactive mode - select snapshot and restore location
project-restore

# Or use project-backup directly
project-backup restore <snapshot-id> /path/to/restore
```

## Configuration

Edit `config/backup.env` to customize:

- `GDRIVE_REMOTE`: rclone remote name (default: `K-Solutions:`)
- `GDRIVE_REMOTE_ENCRYPTED`: Encrypted remote name (default: `K-Solutions-Crypt:`)
- `BTRFS_BACKUP_PATH`: Remote path for unencrypted BTRFS backups
- `BTRFS_BACKUP_PATH_ENCRYPTED`: Remote path for encrypted BTRFS backups
- `PROJECT_BACKUP_PATH`: Remote path for project backups
- `PROJECTS_DIR`: Local projects directory
- `LOG_DIR`: Log file location

### Restic Configuration (for project backups)

- `RESTIC_REPOSITORY`: Repository location (default: `rclone:K-Solutions:Backups/Linux/projects`)
- `RESTIC_PASSWORD_FILE`: Password file location (default: `~/.config/restic/projects-password`)
- `RESTIC_COMPRESSION`: Compression mode - `auto`, `off`, or `max` (default: `max`)
  - `auto`: Let restic decide (good balance)
  - `off`: No compression (fastest, largest files)
  - `max`: Maximum compression (slowest, smallest files - recommended for cloud storage)
- `RESTIC_KEEP_LAST`: Keep last N snapshots (default: 10)
- `RESTIC_KEEP_DAILY`: Keep daily snapshots for N days (default: 7)
- `RESTIC_KEEP_WEEKLY`: Keep weekly snapshots for N weeks (default: 4)
- `RESTIC_KEEP_MONTHLY`: Keep monthly snapshots for N months (default: 6)

### Exclusion Patterns

Edit `config/exclude-patterns.txt` to customize which files/directories are excluded from project backups. By default, it excludes:
- Build artifacts (`node_modules`, `target`, `build`, `dist`, etc.)
- Virtual environments (`.venv`, `venv`, etc.)
- IDE files (`.idea`, `.vscode`)
- Cache directories
- Large binary files

## Backup Schedule

| Backup Type | Schedule | Description |
|-------------|----------|-------------|
| BTRFS System | Daily 3:00 AM | Incremental snapshots of root filesystem (encrypted) |
| Projects | Daily 4:00 AM | Encrypted, deduplicated project folder backup |

## Encryption

Both backup systems support encryption:

| Backup Type | Encryption Method | Password Location |
|-------------|-------------------|-------------------|
| BTRFS | rclone crypt (NaCl SecretBox) | `~/.config/restic/projects-password` |
| Projects | restic (AES-256) | `~/.config/restic/projects-password` |

**Important**: Both systems use the same password file for consistency. Keep this file backed up securely!

See [docs/ENCRYPTION-SETUP.md](docs/ENCRYPTION-SETUP.md) for detailed encryption setup and recovery instructions.

## Documentation

- [BACKUP-EVALUATION.md](docs/BACKUP-EVALUATION.md) - Evaluation of backup strategies
- [BACKUP-SETUP-SUMMARY.md](docs/BACKUP-SETUP-SUMMARY.md) - Current setup summary
- [cachyos-backup-setup.md](docs/cachyos-backup-setup.md) - Initial setup guide
- [ENCRYPTION-SETUP.md](docs/ENCRYPTION-SETUP.md) - rclone crypt encryption setup and recovery
- [MIGRATION-PLAN.md](docs/MIGRATION-PLAN.md) - Migration plan for this project
- [PROJECT-BACKUP-DESIGN.md](docs/PROJECT-BACKUP-DESIGN.md) - Design for project folder backups
- [RESTIC-RECOVERY.md](docs/RESTIC-RECOVERY.md) - Restic recovery procedures

## License

MIT License
