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

## 🔄 Sync Clients

Hedgii supports multiple sync clients for maximum flexibility:

### **🎯 Auto-Detection (Recommended)**
Hedgii automatically chooses the best available sync client:
- **OneDrive client** for OneDrive (more stable, faster)
- **rclone** for other cloud providers or as fallback

### **🌥️ Supported Sync Methods**

#### **rclone (Universal)**
- Supports 40+ cloud providers
- Battle-tested and reliable
- Great for multi-cloud setups

```bash
# Configure rclone
rclone config

# Test connection
rclone ls onedrive:
```

#### **OneDrive Client (OneDrive Optimized)**
- Dedicated OneDrive client by abraunegg
- Better performance for OneDrive
- Native Linux integration

```bash
# Setup OneDrive client
hedgii setup-onedrive

# Or use the wizard
hedgii setup-sync
```

### **🔧 Sync Configuration**

```json
{
  "settings": {
    "sync_method": "auto",           // auto, rclone, or onedrive
    "cloud_provider": "onedrive",    // Helps auto-detection
    
    // rclone settings
    "rclone_remote": "onedrive:hedgii-backups/",
    
    // OneDrive client settings
    "onedrive_backup_dir": "hedgii-backups",
    "onedrive_config_dir": "/etc/hedgii/onedrive"
  }
}
```

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

### 🚀 **Advanced Capabilities**
- **Multi-sync support** - rclone AND abraunegg/onedrive compatibility
- **Auto-detection** - automatically chooses the best sync method
- **Custom script execution** for database dumps and exports
- **Flexible JSON configuration** - no more hardcoded paths
- **Intelligent error handling** with continue-on-error options
- **Staging directory management** - clean and organized
- **Automatic cleanup** of old backups
- **Interactive setup wizard** for sync clients
- **Detailed logging** with kawaii emojis for easy reading

---

## 🚀 Quick Start

### **One-liner Installation** (Coming Soon!)
```bash
curl -fsSL https://raw.githubusercontent.com/damienmarill/hedgii/main/install.sh | sudo bash
```

### **Manual Installation**
```bash
# Clone the kawaii repository
git clone https://github.com/damienmarill/hedgii.git
cd hedgii

# Make hedgii executable
chmod +x hedgii.sh

# Create configuration directory
sudo mkdir -p /etc/hedgii

# Copy example configuration
sudo cp config/hedgii_config.json.example /etc/hedgii/hedgii_config.json

# Set up GPG passphrase
echo "your_super_secret_passphrase" | sudo tee /etc/hedgii/gpg_passphrase
sudo chmod 600 /etc/hedgii/gpg_passphrase

# Configure rclone for your cloud storage
rclone config
```

### **First Backup**
```bash
# Test your configuration
sudo ./hedgii.sh validate-config

# Test custom commands only
sudo ./hedgii.sh test-commands

# Run your first backup! 🎉
sudo ./hedgii.sh curl
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

#### **custom_commands**
- `command`: Shell command to execute
- `description`: What this command does
- `output_file`: Where to save the command output
- `timeout`: Maximum execution time (seconds)
- `working_dir`: Directory to run command in
- `continue_on_error`: Whether to continue if command fails

#### **settings**
- `staging_dir`: Temporary directory for backup preparation
- `backup_dir`: Local directory for encrypted backups
- `rclone_remote`: Cloud storage destination

---

## 🎮 Commands

Hedgii comes with several kawaii commands to manage your backups:

```bash
# 🦔 Main backup command
sudo hedgii curl

# 👀 Check backup status
sudo hedgii peek

# 🛡️ View protection status
sudo hedgii guard

# 🧪 Test custom commands without full backup
sudo hedgii test-commands

# ✅ Validate configuration file
sudo hedgii validate-config
```

### **🔄 Sync Commands**

```bash
# 🧪 Test available sync clients
sudo hedgii test-sync

# 🔧 Interactive sync setup wizard
sudo hedgii setup-sync

# 📤 Setup OneDrive client specifically
sudo hedgii setup-onedrive

# 📊 Show sync clients status
sudo hedgii sync-status
```

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
    }
  ]
}
```

---

## 🔧 Advanced Usage

### **Sync Client Setup**

#### **Option 1: OneDrive Client (Recommended for OneDrive)**
```bash
# Install OneDrive client (done automatically by installer)
# Or manually: https://github.com/abraunegg/onedrive

# Setup with Hedgii
sudo hedgii setup-onedrive

# Test connection
sudo hedgii test-sync
```

#### **Option 2: rclone (Universal)**
```bash
# Configure rclone
rclone config

# Test connection
rclone ls onedrive:

# Update Hedgii config to use rclone
sudo hedgii setup-sync
```

#### **Option 3: Auto-Detection (Best of Both)**
```json
{
  "settings": {
    "sync_method": "auto",
    "cloud_provider": "onedrive"
  }
}
```

### **Automated Backups with Cron**
```bash
# Daily backup at 2 AM (configured automatically)
# Check with: cat /etc/cron.d/hedgii-backup

# Manual cron setup if needed
echo "0 2 * * * root /usr/local/bin/hedgii curl >> /var/log/hedgii/cron.log 2>&1" | sudo tee /etc/cron.d/hedgii-backup
```

### **Custom Scripts Integration**
Hedgii can execute any shell command as part of your backup:

```json
{
  "custom_commands": [
    {
      "command": "docker ps -a --format 'table {{.Names}}\\t{{.Status}}'",
      "description": "🐳 Docker containers status",
      "output_file": "system/docker_status.txt"
    },
    {
      "command": "systemctl list-units --type=service --state=active",
      "description": "🔧 Active system services",
      "output_file": "system/services.txt"
    }
  ]
}
```

---

## 🛡️ Security Features

### **🔐 Encryption**
- **GPG AES-256 encryption** for all backup archives
- **Passphrase protection** stored securely
- **No plain text data** ever touches cloud storage

### **🔒 Access Control**
- Configuration files secured with proper permissions
- Staging directories cleaned after each backup
- Logs contain no sensitive information

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
sudo hedgii test-commands
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
bash -x hedgii.sh curl
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
