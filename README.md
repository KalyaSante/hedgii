# 🦔 Hedgii - Your Kawaii Backup Guardian!

*The adorable yet secure backup solution that protects your data like a hedgehog protects itself*

## Why Hedgii? (｡◕‿◕｡)

- **🛡️ Protective**: Curls up your data into encrypted balls when threatened
- **⚡ Simple**: Easy configuration with JSON files  
- **🔒 Secure**: GPG encryption with strong ciphers
- **☁️ Cloud Ready**: Upload to OneDrive, Google Drive, or any rclone target
- **🎯 Smart**: Auto-detects files vs folders, handles exclusions
- **🧹 Clean**: Automatic cleanup of old backups

## Quick Start

```bash
# Install Hedgii
sudo ./install.sh

# Configure your backup sources
sudo nano /etc/hedgii/hedgii_config.json

# Configure rclone for your cloud storage
rclone config

# Run your first backup
sudo ./hedgii.sh
```

## Commands

- `hedgii curl` - Curl up and secure your data (backup)
- `hedgii peek` - Quick status check
- `hedgii uncurl` - Safely restore your data  
- `hedgii guard` - View protection status

## Configuration

Edit `/etc/hedgii/hedgii_config.json` with your backup sources and settings.

## Recovery

```bash
# Decrypt a backup
./scripts/decrypt.sh backup_20241217.gpg

# Recover encryption key
./scripts/recover_key.sh
```

## Requirements

- Linux system (Debian/Ubuntu tested)
- GPG, rclone, jq, rsync
- Cloud storage account

## License

MIT License - Keep your data safe and share the love! 💖

---

*Built with kawaii spirit by Damien Marill* 🦔✨


## Project Structure

```
hedgii/
├── 🦔 README.md              # You're here!
├── 🔧 install.sh             # Installation script
├── 🎯 hedgii.sh              # Main backup script
├── 📋 LICENSE                # MIT License
├── 📁 config/
│   └── hedgii_config.json.example  # Configuration template
└── 📁 scripts/
    ├── decrypt.sh            # Decrypt backups
    └── recover_key.sh        # Recover encryption key
```

## Quick Test

After installation, test with:
```bash
hedgii-backup peek     # Check status
hedgii-backup          # Run backup
```

---

*May your data be forever protected by kawaii hedgehog magic!* 🦔💫
