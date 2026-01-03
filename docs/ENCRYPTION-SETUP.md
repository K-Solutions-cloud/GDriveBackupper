# rclone Crypt Encryption Setup for BTRFS Backups

This document describes how to set up encrypted backups for BTRFS snapshots using rclone crypt.

## Overview

The encryption setup uses **rclone crypt** to encrypt BTRFS snapshot backups before uploading to Google Drive. This ensures that:

1. **Data at rest is encrypted** - Files on Google Drive are unreadable without the password
2. **Filenames are encrypted** - Directory structure and filenames are obfuscated
3. **Same password as restic** - Uses the same password for consistency and easier management

## Prerequisites

1. **rclone installed and configured** with `K-Solutions` remote
2. **Restic password file** at `~/.config/restic/projects-password`
3. **Root access** for running BTRFS backups

## Setup Instructions

### 1. Ensure Restic Password Exists

The encryption uses the same password as restic. If you haven't set it up yet:

```bash
mkdir -p ~/.config/restic
# Create a strong password (or use an existing one)
echo 'your-secure-password-here' > ~/.config/restic/projects-password
chmod 600 ~/.config/restic/projects-password
```

### 2. Run the Setup Script

```bash
# Make the script executable
chmod +x /mnt/sandisk_2tb/Projects/GDriveBackupper/scripts/setup-rclone-crypt

# Run the setup
./scripts/setup-rclone-crypt
```

The script will:
- Verify prerequisites
- Create the `K-Solutions-Crypt` remote in rclone
- Create the encrypted backup directory on Google Drive
- Test the encryption with a sample file

### 3. Verify the Configuration

```bash
# List configured remotes
rclone listremotes

# Should show:
# K-Solutions:
# K-Solutions-Crypt:

# Test listing (should be empty initially)
rclone ls K-Solutions-Crypt:
```

## Usage

### Encrypted Backups (Default)

```bash
# Run encrypted backup (default)
sudo btrfs-cloud-backup

# Or explicitly
sudo btrfs-cloud-backup --encrypted
```

### Unencrypted Backups (Legacy)

```bash
# Run unencrypted backup
sudo btrfs-cloud-backup --unencrypted
```

### List All Backups

```bash
sudo btrfs-cloud-backup --list
```

## Storage Locations

| Type | Remote | Google Drive Path |
|------|--------|-------------------|
| Encrypted | `K-Solutions-Crypt:` | `Backups/Linux/cachyos-snapshots-encrypted/` |
| Unencrypted | `K-Solutions:` | `Backups/Linux/cachyos-snapshots/` |

## Recovery Instructions

### Recovering Encrypted Backups

To recover encrypted backups on a new system:

1. **Install rclone** on the new system
2. **Configure the base remote** (`K-Solutions`)
3. **Recreate the crypt remote** using the same password

```bash
# Get your password from the backup
cat ~/.config/restic/projects-password

# Create the crypt remote manually
rclone config

# Choose: n) New remote
# Name: K-Solutions-Crypt
# Type: crypt
# Remote: K-Solutions:Backups/Linux/cachyos-snapshots-encrypted
# Filename encryption: standard
# Directory name encryption: true
# Password: (enter your restic password)
# Password2: (generate salt from password - see below)
```

#### Generating the Salt (password2)

The salt is derived from your password for reproducibility:

```bash
PASSWORD=$(cat ~/.config/restic/projects-password)
SALT=$(echo -n "${PASSWORD}-rclone-salt" | sha256sum | cut -d' ' -f1 | head -c 32)
echo "Salt: $SALT"
```

### Restoring a Backup

```bash
# List available backups
rclone ls K-Solutions-Crypt:

# Download a specific backup
rclone copy K-Solutions-Crypt:snapshot_123_2024-01-15_030000.btrfs.zst /tmp/

# Decompress
zstd -d /tmp/snapshot_123_2024-01-15_030000.btrfs.zst

# Restore to BTRFS (requires root)
sudo btrfs receive /path/to/restore < /tmp/snapshot_123_2024-01-15_030000.btrfs
```

## Security Considerations

### Password Storage

- Password is stored in `~/.config/restic/projects-password`
- File permissions should be `600` (owner read/write only)
- **BACKUP THIS PASSWORD SECURELY** - without it, encrypted backups are unrecoverable

### Encryption Details

- **Algorithm**: rclone crypt uses NaCl SecretBox (XSalsa20 + Poly1305)
- **Filename encryption**: Standard (encrypted and base32 encoded)
- **Directory encryption**: Enabled (directory names are also encrypted)

### What's Encrypted

| Component | Encrypted |
|-----------|----------|
| File contents | ✅ Yes |
| Filenames | ✅ Yes |
| Directory names | ✅ Yes |
| File sizes | ❌ No (visible but not exact) |
| Modification times | ❌ No |

## Troubleshooting

### "Encrypted remote not found"

Run the setup script:
```bash
./scripts/setup-rclone-crypt
```

### "Password file not found"

Create the password file:
```bash
mkdir -p ~/.config/restic
echo 'your-password' > ~/.config/restic/projects-password
chmod 600 ~/.config/restic/projects-password
```

### "Decryption failed"

Verify you're using the correct password:
```bash
# Check the password
cat ~/.config/restic/projects-password

# Verify the remote configuration
rclone config show K-Solutions-Crypt
```

### Viewing Encrypted Files on Google Drive

To see what the encrypted files look like:
```bash
# This shows the encrypted (obfuscated) filenames
rclone ls K-Solutions:Backups/Linux/cachyos-snapshots-encrypted/
```

## Migration from Unencrypted Backups

Existing unencrypted backups remain in place. To migrate:

```bash
# Option 1: Keep both (recommended)
# Old backups stay at: K-Solutions:Backups/Linux/cachyos-snapshots/
# New backups go to: K-Solutions-Crypt: (encrypted)

# Option 2: Re-encrypt old backups (manual process)
# Download each backup, then upload to encrypted remote
for file in $(rclone ls K-Solutions:Backups/Linux/cachyos-snapshots/ | awk '{print $2}'); do
    rclone copy "K-Solutions:Backups/Linux/cachyos-snapshots/$file" /tmp/
    rclone copy "/tmp/$file" K-Solutions-Crypt:
    rm "/tmp/$file"
done
```

## Related Documentation

- [BTRFS Backup Setup](./cachyos-backup-setup.md)
- [Restic Recovery Guide](./RESTIC-RECOVERY.md)
- [Backup Evaluation](./BACKUP-EVALUATION.md)
