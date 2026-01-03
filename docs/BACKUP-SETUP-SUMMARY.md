# CachyOS Backup & Konfiguration - Zusammenfassung

## ✅ Was wurde eingerichtet

### 1. Google Drive Integration
- **rclone** konfiguriert mit Remote `K-Solutions:`
- **Google Drive gemountet** unter `~/GoogleDrive`
- **Automatischer Mount** beim Login via systemd User Service

### 2. BTRFS Snapshots (Snapper)
- **Timeline-Snapshots aktiviert** (täglich)
- **Pre/Post Snapshots** bei pacman-Operationen (bereits vorhanden)
- Snapshots werden unter `/.snapshots/` gespeichert

### 3. Cloud Backup
- **Backup-Skript**: `~/.local/bin/btrfs-cloud-backup`
- **Backup-Ziel**: `K-Solutions:Backups/Linux/cachyos-snapshots/`
- **Komprimierung**: zstd (Level 3)
- **Progress-Anzeige**: Mit pv (Geschwindigkeit, ETA, Fortschritt)

### 4. Automatisierung
- **Timer**: Täglich um 03:00 Uhr
- **Service**: `~/.config/systemd/user/btrfs-backup.service`
- **Sudoers**: Passwortloses Backup möglich

### 5. SSH Keys
- **Hauptkey**: `~/.ssh/id_ed25519` (Symlink zu id_ed25519_wsl_aaron)
- **Deploy Keys**: vultr_deploy_key, github_kraken_deploy_no_pass, deploy_key_k-solutions
- **SSH Config**: `~/.ssh/config` (automatische Key-Auswahl pro Host)
- **ksshaskpass**: Grafische Passwort-Eingabe in KDE

---

## 📋 Wichtige Befehle

### Backup manuell starten
```bash
sudo ~/.local/bin/btrfs-cloud-backup
```

### Backup-Status prüfen
```bash
# Timer-Status
systemctl --user status btrfs-backup.timer

# Letzte Ausführung
journalctl --user -u btrfs-backup.service -n 50

# Logs
cat ~/.local/state/btrfs-backup/backup.log
```

### Backups auf Google Drive anzeigen
```bash
rclone ls "K-Solutions:Backups/Linux/cachyos-snapshots/"
rclone size "K-Solutions:Backups/Linux/cachyos-snapshots/"
```

### Snapper Snapshots anzeigen
```bash
sudo snapper list
sudo snapper -c root list
```

### Snapshot Rollback (bei Problemen)
```bash
# Option 1: Bei Boot über GRUB -> CachyOS Snapshots
# Option 2: Im laufenden System:
sudo snapper rollback <snapshot-nummer>
sudo reboot
```

### Google Drive Mount
```bash
# Status prüfen
systemctl --user status rclone-gdrive.service

# Manuell mounten
systemctl --user start rclone-gdrive.service

# Inhalt anzeigen
ls ~/GoogleDrive/
```

### SSH Keys
```bash
# Keys zum Agent hinzufügen
ssh-add ~/.ssh/id_ed25519

# Verbindung testen
ssh -T git@github.com
```

---

## 🔄 Recovery-Szenarien

### Szenario 1: Rolling Release Update kaputt
1. Neustart → GRUB → "CachyOS Snapshots" → Snapshot auswählen
2. Nach Boot: `sudo snapper rollback`
3. Neustart

### Szenario 2: Datei versehentlich gelöscht
```bash
# Snapshot mounten
sudo mount -o subvol=.snapshots/<nummer>/snapshot /mnt/snapshot
# Datei kopieren
cp /mnt/snapshot/pfad/zur/datei ~/
sudo umount /mnt/snapshot
```

### Szenario 3: Komplette Neuinstallation
1. CachyOS neu installieren
2. rclone installieren und konfigurieren
3. Backup herunterladen:
   ```bash
   rclone copy "K-Solutions:Backups/Linux/cachyos-snapshots/snapshot_XX.btrfs.zst" /tmp/
   ```
4. Entpacken und wiederherstellen:
   ```bash
   zstd -d /tmp/snapshot_XX.btrfs.zst
   sudo btrfs receive /mnt/restored < /tmp/snapshot_XX.btrfs
   ```

---

## 📁 Wichtige Dateien

| Datei | Beschreibung |
|-------|-------------|
| `~/.local/bin/btrfs-cloud-backup` | Backup-Skript |
| `~/.config/systemd/user/btrfs-backup.service` | Backup Service |
| `~/.config/systemd/user/btrfs-backup.timer` | Backup Timer (03:00) |
| `~/.config/systemd/user/rclone-gdrive.service` | GDrive Mount Service |
| `~/.config/rclone/rclone.conf` | rclone Konfiguration |
| `~/.ssh/config` | SSH Host-Konfiguration |
| `~/.local/state/btrfs-backup/backup.log` | Backup-Logs |
| `/etc/sudoers.d/btrfs-backup` | Sudoers-Regel |

---

## ⚠️ Wichtige Hinweise

1. **Erstes Backup ist groß** (~11GB), zukünftige inkrementelle Backups sind viel kleiner
2. **SSH Key Passwort** wird beim ersten Gebrauch nach Login abgefragt (ksshaskpass)
3. **Backup läuft automatisch** um 03:00 Uhr wenn PC an ist, sonst beim nächsten Login
4. **Google Drive Mount** startet automatisch beim Login

---

*Erstellt am: 28.12.2025*
