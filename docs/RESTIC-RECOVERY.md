# Restic Backup Recovery Guide

This document provides step-by-step instructions for recovering your project backups if your system is lost or needs to be rebuilt.

## Prerequisites

Before you can restore backups, you need:

1. **The restic encryption password** - Without this, your backups are irrecoverable
2. **Access to Google Drive** - The backup repository is stored on Google Drive
3. **rclone configured** - To access Google Drive from the command line

## Step 1: Install Required Software

### Install restic (CachyOS/Arch Linux)

```bash
sudo pacman -S restic
```

### Install rclone (if not already installed)

```bash
sudo pacman -S rclone
```

### Verify installations

```bash
restic version
rclone version
```

## Step 2: Configure rclone for Google Drive

If rclone is not already configured:

```bash
rclone config
```

Follow the prompts to:
1. Create a new remote named `K-Solutions`
2. Select `Google Drive` as the storage type
3. Complete the OAuth authentication

Verify the configuration:

```bash
rclone lsd K-Solutions:Backups/Linux/
```

You should see the `projects` directory listed.

## Step 3: Restore the Password File

### Option A: From Password Manager

If you stored your password in a password manager:

```bash
mkdir -p ~/.config/restic
# Paste your password into the file
nano ~/.config/restic/projects-password
chmod 600 ~/.config/restic/projects-password
```

### Option B: From Backup Copy

If you have a backup copy of the password:

```bash
mkdir -p ~/.config/restic
cp /path/to/backup/projects-password ~/.config/restic/projects-password
chmod 600 ~/.config/restic/projects-password
```

### Verify password file permissions

```bash
ls -la ~/.config/restic/projects-password
# Should show: -rw------- 1 user user 45 date projects-password
```

## Step 4: Verify Repository Access

Test that you can access the backup repository:

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       snapshots
```

This should list all available backup snapshots.

## Step 5: Restore Backups

### List available snapshots

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       snapshots
```

Example output:
```
ID        Time                 Host        Tags        Paths
────────────────────────────────────────────────────────────
abc123    2026-01-03 12:00:00  hostname                /mnt/sandisk_2tb/Projects
def456    2026-01-02 12:00:00  hostname                /mnt/sandisk_2tb/Projects
```

### Restore the latest snapshot

```bash
# Create the target directory
mkdir -p /mnt/sandisk_2tb/Projects

# Restore to the original location
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       restore latest --target /
```

### Restore a specific snapshot

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       restore abc123 --target /
```

### Restore to a different location

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       restore latest --target /tmp/restore
```

### Restore specific files or directories

```bash
# Restore only a specific project
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       restore latest --target /tmp/restore \
       --include "/mnt/sandisk_2tb/Projects/MyProject"
```

## Step 6: Browse Backup Contents (Optional)

### Mount the repository for browsing

```bash
mkdir -p /tmp/restic-mount
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       mount /tmp/restic-mount
```

Then browse `/tmp/restic-mount` to explore snapshots. Press Ctrl+C to unmount.

### List files in a snapshot

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       ls latest
```

## Useful Commands Reference

### Check repository integrity

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       check
```

### Show repository statistics

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       stats
```

### Compare two snapshots

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       diff snapshot1 snapshot2
```

### Find files across snapshots

```bash
restic -r rclone:K-Solutions:Backups/Linux/projects \
       --password-file ~/.config/restic/projects-password \
       find "filename.txt"
```

## Environment Variables (Convenience)

Add these to your `~/.bashrc` or `~/.zshrc` for easier commands:

```bash
export RESTIC_REPOSITORY="rclone:K-Solutions:Backups/Linux/projects"
export RESTIC_PASSWORD_FILE="${HOME}/.config/restic/projects-password"
```

Then you can simply run:

```bash
restic snapshots
restic restore latest --target /
```

## Troubleshooting

### "repository does not exist" error

- Verify rclone is configured correctly: `rclone lsd K-Solutions:`
- Check the repository path exists: `rclone ls K-Solutions:Backups/Linux/projects/`

### "wrong password" error

- Verify the password file exists and has correct permissions
- Ensure the password matches the one used to initialize the repository
- Check for trailing newlines or whitespace in the password file

### Slow restore speeds

- Google Drive has rate limits; large restores may take time
- Consider using `--verbose` to see progress
- For very large restores, consider downloading the repository first:
  ```bash
  rclone sync K-Solutions:Backups/Linux/projects /tmp/local-repo
  restic -r /tmp/local-repo --password-file ~/.config/restic/projects-password restore latest --target /
  ```

## Repository Information

| Property | Value |
|----------|-------|
| Repository Location | `rclone:K-Solutions:Backups/Linux/projects` |
| Repository ID | `6ac4aec1f8` |
| Password File | `~/.config/restic/projects-password` |
| Created | 2026-01-03 |

## Important Reminders

⚠️ **NEVER lose your password** - Without it, your backups cannot be decrypted

⚠️ **Test restores periodically** - Verify your backups work before you need them

⚠️ **Keep password backups in multiple secure locations** - Password manager, encrypted USB, etc.
