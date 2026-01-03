# CachyOS Backup & Konfiguration - Implementierungsplan

## Übersicht

Dieses Dokument beschreibt die vollständige Einrichtung eines automatisierten Backup-Systems für CachyOS mit BTRFS-Snapshots, verschlüsselten Cloud-Backups zu Google Drive, und SSH-Key-Management.

## System-Konfiguration

| Komponente | Details |
|------------|--------|
| OS | CachyOS (Arch-basiert, Rolling Release) |
| Desktop | KDE Plasma |
| Dateisystem | BTRFS auf allen Platten |
| Cloud Storage | Google One 2TB |
| Backup-Zeit | Täglich um 03:00 Uhr |

### Festplatten-Layout

| Gerät | Label | Mountpoint | Zweck |
|-------|-------|------------|-------|
| nvme0n1p2 | System | `/`, `/home` | System + Projekte |
| sda1 | Samsung_850_250G | `/mnt/samsung_250g` | Daten |
| sdb1 | Samsung_840_120G | `/mnt/samsung_120g` | Daten |
| sdc2 | SanDisk_Ultra_2TB | `/mnt/sandisk_2tb` | Daten |

### BTRFS Subvolumes (bereits vorhanden)

- `@` → `/`
- `@home` → `/home` (enthält Projekte)
- `@root`, `@srv`, `@cache`, `@tmp`, `@log`
- Snapper bereits aktiv mit ~50 Snapshots

---

## Implementierungsschritte

### Phase 1: Google Drive Integration

#### 1.1 rclone installieren
```bash
sudo pacman -S rclone
```

#### 1.2 Google Drive Remote konfigurieren
```bash
rclone config
# n) New remote
# Name: gdrive
# Storage: Google Drive
# OAuth flow durchführen
```

#### 1.3 Verschlüsseltes Remote erstellen
```bash
rclone config
# n) New remote
# Name: gdrive-crypt
# Storage: Encrypt/Decrypt a remote (crypt)
# Remote: gdrive:backups
# Passwort setzen (sicher aufbewahren!)
```

#### 1.4 Google Drive mounten (optional für Dateizugriff)
```bash
# Mount-Punkt erstellen
mkdir -p ~/GoogleDrive

# Systemd User Service erstellen
mkdir -p ~/.config/systemd/user/
```

Datei: `~/.config/systemd/user/rclone-gdrive.service`
```ini
[Unit]
Description=Google Drive FUSE Mount
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: %h/GoogleDrive \
    --vfs-cache-mode full \
    --vfs-cache-max-size 10G \
    --dir-cache-time 72h \
    --poll-interval 15s
ExecStop=/bin/fusermount -u %h/GoogleDrive
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-gdrive.service
```

---

### Phase 2: Snapper Konfiguration

#### 2.1 Bestehende System-Konfiguration prüfen
```bash
sudo snapper list-configs
sudo snapper -c root get-config
```

#### 2.2 Snapper für externe Platten einrichten

Für jede externe Platte:
```bash
# Samsung 250G
sudo snapper -c samsung_250g create-config /mnt/samsung_250g

# Samsung 120G  
sudo snapper -c samsung_120g create-config /mnt/samsung_120g

# SanDisk 2TB
sudo snapper -c sandisk_2tb create-config /mnt/sandisk_2tb
```

#### 2.3 Snapshot-Policies anpassen
```bash
# Für jede Config:
sudo snapper -c <config> set-config \
    TIMELINE_CREATE=yes \
    TIMELINE_CLEANUP=yes \
    TIMELINE_LIMIT_HOURLY=24 \
    TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=4 \
    TIMELINE_LIMIT_MONTHLY=6 \
    TIMELINE_LIMIT_YEARLY=1
```

---

### Phase 3: Automatisierung mit systemd

#### 3.1 Backup Service
Datei: `/etc/systemd/system/btrfs-backup.service`
```ini
[Unit]
Description=BTRFS Backup to Google Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/btrfs-backup-to-cloud
Nice=19
IOSchedulingClass=idle
```

#### 3.2 Backup Timer
Datei: `/etc/systemd/system/btrfs-backup.timer`
```ini
[Unit]
Description=Daily BTRFS Backup at 3 AM

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now btrfs-backup.timer
```

---

### Phase 4: SSH Keys einrichten

#### 4.1 SSH-Verzeichnis erstellen
```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

#### 4.2 Keys aus Google Drive kopieren
```bash
# Nach dem GDrive-Mount:
cp ~/GoogleDrive/ssh-keys/* ~/.ssh/

# Oder mit rclone:
rclone copy gdrive:ssh-keys/ ~/.ssh/
```

#### 4.3 Berechtigungen setzen
```bash
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
chmod 644 ~/.ssh/config 2>/dev/null || true
```

#### 4.4 SSH-Agent mit KDE Wallet
Datei: `~/.config/autostart/ssh-add.desktop`
```ini
[Desktop Entry]
Type=Application
Name=SSH Key Agent
Exec=ssh-add
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
```

---

## Recovery-Anleitung

### Szenario 1: Rolling Release Update kaputt

```bash
# 1. Bei Boot: GRUB -> CachyOS Snapshots -> Snapshot auswählen
# 2. Nach Boot:
sudo snapper rollback
sudo reboot
```

### Szenario 2: Festplatte defekt - Lokale Recovery

```bash
# Von anderem Snapshot wiederherstellen
sudo btrfs subvolume delete /path/to/broken
sudo btrfs subvolume snapshot /.snapshots/XX/snapshot /path/to/restored
```

### Szenario 3: Komplette Neuinstallation - Cloud Recovery

```bash
# 1. CachyOS neu installieren (minimal)
# 2. rclone installieren und konfigurieren
# 3. Backups herunterladen
rclone copy gdrive-crypt:system/ /tmp/restore/

# 4. Entpacken und wiederherstellen
zstd -d /tmp/restore/system_*.btrfs.zst
sudo btrfs receive /mnt/restored < /tmp/restore/system_*.btrfs
```

---

## Wartung & Monitoring

### Backup-Status prüfen
```bash
# Timer-Status
systemctl status btrfs-backup.timer

# Letzte Ausführung
journalctl -u btrfs-backup.service -n 50

# Logs
tail -f /var/log/btrfs-backup.log
```

### Cloud-Speicher prüfen
```bash
rclone size gdrive-crypt:
rclone ls gdrive-crypt:system/ | head -20
```

### Snapshot-Übersicht
```bash
snapper -c root list
snapper -c samsung_250g list
# etc.
```

---

## Sicherheitshinweise

1. **rclone Passwort sicher aufbewahren** - Ohne dieses Passwort sind die Cloud-Backups nicht wiederherstellbar!
2. **Regelmäßig Recovery testen** - Mindestens einmal pro Quartal
3. **SSH Keys nicht nur in der Cloud** - Auch auf USB-Stick oder Passwort-Manager

---

## Zusammenfassung der zu installierenden Pakete

```bash
sudo pacman -S rclone snapper snap-pac grub-btrfs zstd kio-gdrive kaccounts-providers
```
