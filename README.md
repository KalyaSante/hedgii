# 🦔 Hedgii - Your Kawaii Backup Guardian

<div align="center">
  <img src="https://img.shields.io/badge/Status-Protecting%20Your%20Data-brightgreen?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSJjdXJyZW50Q29sb3IiLz4KPC9zdmc+Cg=="/>
  <img src="https://img.shields.io/badge/Made%20with-Bash%20%26%20Love-ff69b4?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Encryption-GPG%20AES256-red?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Cloud-OneDrive%20Ready-0078d4?style=for-the-badge"/>
</div>

<div align="center">
  <h3>✨ The most adorable yet secure backup solution for Linux servers ✨</h3>
  <p><em>Hedgii curls up around your precious data to keep it safe! (｡◕‿◕｡)</em></p>
</div>

---

## 🌟 Why Choose Hedgii?

Hedgii isn't just another backup script - it's your kawaii guardian that protects your data with the determination of a protective hedgehog! 🦔

### 🎯 **Core Features**
- **🔐 Military-grade encryption** with GPG AES-256
- **📁 Intelligent file detection** - automatically handles files and directories
- **🔧 Custom command execution** - database dumps, system exports, and more
- **☁️ Cloud-ready** with rclone integration (OneDrive, Google Drive, Dropbox, S3)
- **🎨 Kawaii logging** - because backup logs should be cute too!
- **⚡ Timeout protection** - no more hanging scripts
- **📊 Comprehensive reporting** - know exactly what was backed up
- **⏰ Automatic scheduling** - daily backups without thinking about it

### 🚀 **Advanced Capabilities**
- **Custom script execution** for database dumps and exports
- **Flexible JSON configuration** - no more hardcoded paths
- **Intelligent error handling** with continue-on-error options
- **Staging directory management** - clean and organized
- **Automatic cleanup** of old backups and logs
- **Detailed logging** with kawaii emojis for easy reading
- **System integration** with aliases and cron jobs

---

## 🚀 Quick Start

### **One-liner Installation**
```bash
# Clone and install Hedgii
git clone https://github.com/damienmarill/hedgii.git
cd hedgii
sudo ./install.sh
```

### **What the installation does:**
- ✅ Installs all dependencies (jq, gpg, rclone, rsync)
- ✅ Sets up configuration directory (`/etc/hedgii/`)
- ✅ Creates automatic daily backup cron job
- ✅ Configures log rotation
- ✅ Adds convenient bash aliases
- ✅ Sets up secure GPG passphrase

### **First Backup**
```bash
# Configure rclone for your cloud storage
rclone config

# Edit your backup sources (optional - works out of the box)
hedgii-config

# Test your configuration
hedgii validate-config

# Test custom commands only
hedgii test-commands

# Run your first backup! 🎉
hedgii-backup
```

---

## 🎮 Commands

Hedgii comes with several kawaii commands to manage your backups:

```bash
# 🦔 Main backup command
hedgii curl            # or simply: hedgii

# 👀 Check backup status
hedgii peek

# 🛡️ View protection status
hedgii guard

# 🧪 Test custom commands without full backup
hedgii test-commands

# ✅ Validate configuration file
hedgii validate-config
```

### **Convenient Aliases** (added during installation)
```bash
hedgii-backup     # Run backup (hedgii curl)
hedgii-status     # Check status (hedgii peek)
hedgii-config     # Edit configuration
hedgii-logs       # View logs in real-time
hedgii-test       # Test custom commands
```

---

## 📋 Configuration

Hedgii uses a simple JSON configuration file that's both powerful and easy to understand:

```json
{
  "backup_sources": [
    {
      "source": "/var/www/html",
      "destination": "web/html",
      "description": "🌐 Main website files"
    }
  ],
  "custom_commands": [
    {
      "command": "mysqldump --all-databases --single-transaction",
      "description": "📊 Complete MySQL database dump",
      "output_file": "databases/mysql_dump.sql",
      "timeout": 600,
      "continue_on_error": false
    }
  ],
  "settings": {
    "staging_dir": "/tmp/hedgii_staging",
    "backup_dir": "/var/backups/hedgii",
    "rclone_remote": "onedrive:hedgii-backups/"
  }
}
```

### **Configuration Options**

#### **backup_sources**
- `source`: Path to file or directory to backup
- `destination`: Relative path in backup archive
- `description`: Kawaii description for logs

#### **custom_commands** ✨ (New!)
- `command`: Shell command to execute
- `description`: What this command does
- `output_file`: Where to save the command output
- `timeout`: Maximum execution time (seconds)
- `working_dir`: Directory to run command in (optional)
- `continue_on_error`: Whether to continue if command fails

#### **settings**
- `staging_dir`: Temporary directory for backup preparation
- `backup_dir`: Local directory for encrypted backups
- `rclone_remote`: Cloud storage destination
- `encrypt_passphrase_file`: Path to GPG passphrase file

---

## 🗂️ Example Configurations

### **Web Server Backup**
```json
{
  "backup_sources": [
    {
      "source": "/var/www",
      "destination": "web",
      "description": "🌐 Website files"
    },
    {
      "source": "/etc/nginx",
      "destination": "config/nginx",
      "description": "⚙️ Nginx configuration"
    }
  ],
  "custom_commands": [
    {
      "command": "mysqldump --all-databases --single-transaction",
      "description": "📊 MySQL databases",
      "output_file": "databases/mysql.sql",
      "timeout": 600
    },
    {
      "command": "docker ps -a --format 'table {{.Names}}\\t{{.Status}}'",
      "description": "🐳 Docker containers",
      "output_file": "system/docker_status.txt",
      "timeout": 60
    }
  ]
}
```

### **Development Environment**
```json
{
  "backup_sources": [
    {
      "source": "/home/developer/projects",
      "destination": "projects",
      "description": "💻 Development projects"
    }
  ],
  "custom_commands": [
    {
      "command": "git log --oneline -10",
      "description": "🌳 Recent commits",
      "output_file": "git/recent_commits.txt",
      "working_dir": "/home/developer/projects/main-project"
    },
    {
      "command": "composer show --installed",
      "description": "🎼 PHP dependencies",
      "output_file": "dependencies/composer.txt",
      "working_dir": "/home/developer/projects/main-project"
    },
    {
      "command": "systemctl list-units --type=service --state=active",
      "description": "🔧 Active services",
      "output_file": "system/services.txt"
    }
  ]
}
```

---

## 🔧 Advanced Usage

### **Automated Backups** ⏰
The installation automatically creates a daily cron job:
```bash
# View current cron schedule
cat /etc/cron.d/hedgii-backup

# Modify schedule (edit the file)
sudo nano /etc/cron.d/hedgii-backup
```

### **Custom Scripts Integration** 🔧
Hedgii can execute any shell command as part of your backup:

**Database Dumps:**
```json
{
  "command": "pg_dumpall --clean --if-exists",
  "description": "🐘 PostgreSQL full dump",
  "output_file": "databases/postgresql.sql",
  "timeout": 900
}
```

**System Information:**
```json
{
  "command": "dpkg --get-selections",
  "description": "📦 Installed packages",
  "output_file": "system/packages.txt"
}
```

**Application State:**
```json
{
  "command": "redis-cli --scan --pattern '*' | head -100",
  "description": "🔴 Redis keys sample",
  "output_file": "databases/redis_keys.txt"
}
```

---

## 🛡️ Security Features

### **🔐 Encryption**
- **GPG AES-256 encryption** for all backup archives
- **Passphrase protection** stored securely with 600 permissions
- **No plain text data** ever touches cloud storage

### **🔒 Access Control**
- Configuration files secured with proper permissions
- Staging directories cleaned after each backup
- Logs contain no sensitive information
- Backup directory protected with 700 permissions

### **🚨 Safety Measures**
- Timeout protection prevents hanging processes
- Error handling with optional fail-safe modes
- Validation of all configurations before execution
- Comprehensive logging for audit trails

---

## 📊 Monitoring & Reporting

Every Hedgii backup includes:
- **📈 Backup statistics** (file count, sizes, duration)
- **📋 Detailed inventory** of backed up files
- **🔧 Custom command outputs** and their results
- **⚙️ Configuration snapshot** used for the backup
- **🎯 Success/failure status** for each operation

### **Log Management**
- Automatic log rotation (30 days retention)
- Colored output for easy reading
- Real-time log viewing with `hedgii-logs`
- Separate cron logs for scheduled backups

---

## 🐛 Troubleshooting

### **Common Issues**

**❌ "Config file not found"**
```bash
# Make sure config file exists
sudo cp config/hedgii_config.json.example /etc/hedgii/hedgii_config.json
```

**❌ "GPG encryption failed"**
```bash
# Check passphrase file
sudo cat /etc/hedgii/gpg_passphrase
sudo chmod 600 /etc/hedgii/gpg_passphrase
```

**❌ "Custom command timeout"**
```bash
# Increase timeout in config or optimize command
# Test command manually first
hedgii test-commands
```

**❌ "rclone upload failed"**
```bash
# Test rclone configuration
rclone ls onedrive:
rclone config reconnect onedrive:
```

### **Debug Mode**
```bash
# Run with verbose logging
bash -x /usr/local/bin/hedgii curl
```

### **Validation Tools**
```bash
# Test configuration syntax
hedgii validate-config

# Test custom commands only
hedgii test-commands

# Check system status
hedgii peek
```

---

## 🗂️ File Locations

After installation, Hedgii uses these locations:

```
📁 System Locations:
├── /usr/local/bin/hedgii          # Main script
├── /usr/bin/hedgii                # Convenient symlink
├── /etc/hedgii/                   # Configuration directory
│   ├── hedgii_config.json         # Main configuration
│   └── gpg_passphrase             # Encryption passphrase
├── /var/log/hedgii/               # Log files
├── /var/backups/hedgii/           # Local encrypted backups
└── /etc/cron.d/hedgii-backup      # Automatic backup schedule
```

---

## 🤝 Contributing

Hedgii welcomes contributions from fellow kawaii coding enthusiasts! (≧◡≦)

### **How to Contribute**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing kawaii feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### **Development Setup**
```bash
git clone https://github.com/your-username/hedgii.git
cd hedgii
chmod +x hedgii.sh
# Start coding! 🎉
```

---

## 🗑️ Uninstallation

To safely remove Hedgii:
```bash
# Download and run uninstall script
curl -fsSL https://raw.githubusercontent.com/damienmarill/hedgii/main/uninstall.sh | sudo bash

# Or if you have the repository
sudo ./uninstall.sh
```

The uninstaller will:
- Remove all Hedgii components
- Preserve your encrypted backups by default
- Ask what to do with configuration and logs

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **🦔 Hedgehogs** - for inspiring the protective nature of this backup solution
- **🌸 Kawaii Culture** - for making technology more adorable
- **💻 Open Source Community** - for sharing knowledge and tools
- **🔐 GPG Team** - for providing rock-solid encryption

---

## 💖 Support Hedgii

If Hedgii has saved your precious data, consider:
- ⭐ **Starring** this repository
- 🐛 **Reporting bugs** you encounter
- 💡 **Suggesting features** you'd love to see
- 🔧 **Contributing code** to make Hedgii even better
- 📢 **Sharing** with other developers who need backups

---

<div align="center">
  <h3>🦔 Hedgii is always watching over your data! ✨</h3>
  <p><em>Made with ❤️ and lots of kawaii energy by <a href="https://github.com/damienmarill">Damien Marill</a></em></p>
  <p><strong>Remember: A backed-up hedgehog is a happy hedgehog! (｡◕‿◕｡)</strong></p>
</div>
