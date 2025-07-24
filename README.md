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

Hedgii uses a comprehensive JSON configuration file that gives you full control over your backup process. The configuration is located at `/etc/hedgii/hedgii_config.json`.

### 🗂️ **Configuration Structure**

```json
{
  "backup_sources": [...],
  "custom_commands": [...],
  "settings": {...},
  "exclusions": [...]
}
```

---

### 📁 **backup_sources** - File & Directory Sources

Define which files and directories to include in your backup:

```json
{
  "backup_sources": [
    {
      "source": "/var/www/html",
      "destination": "web/html",
      "description": "🌐 Main website files"
    },
    {
      "source": "/etc/nginx/sites-available",
      "destination": "config/nginx",
      "description": "⚙️ Nginx configuration"
    }
  ]
}
```

**Parameters:**
- `source` *(string, required)*: Absolute path to file or directory to backup
- `destination` *(string, required)*: Relative path in backup archive (no leading slash)
- `description` *(string, required)*: Human-readable description for logs (kawaii emojis encouraged! ✨)

**Notes:**
- Directories are copied recursively with `rsync`
- Automatic exclusions apply (see exclusions section)
- Source paths are validated before backup

---

### 🔧 **custom_commands** - Dynamic Data Collection

Execute commands to capture database dumps, system state, and more:

```json
{
  "custom_commands": [
    {
      "command": "mysqldump --all-databases --single-transaction --routines --triggers",
      "description": "📊 Complete MySQL database dump",
      "output_file": "databases/mysql_full_dump.sql",
      "timeout": 600,
      "working_dir": "/tmp",
      "continue_on_error": false
    },
    {
      "command": "docker ps -a --format 'table {{.Names}}\\t{{.Status}}'",
      "description": "🐳 Docker containers status",
      "output_file": "system/docker_status.txt",
      "timeout": 60,
      "working_dir": "/tmp",
      "continue_on_error": true
    }
  ]
}
```

**Parameters:**
- `command` *(string, required)*: Shell command to execute
- `description` *(string, required)*: Human-readable description for logs
- `output_file` *(string, required)*: Relative path where command output is saved
- `timeout` *(integer, optional)*: Maximum execution time in seconds (default: 300)
- `working_dir` *(string, optional)*: Directory to execute command in (default: "/tmp")
- `continue_on_error` *(boolean, optional)*: Whether to continue backup if command fails (default: true)

**Command Examples:**
```json
// Database dumps
{
  "command": "pg_dumpall --clean --if-exists",
  "description": "🐘 PostgreSQL full dump",
  "output_file": "databases/postgresql_dump.sql",
  "timeout": 900
}

// System information
{
  "command": "systemctl list-units --type=service --state=active --no-pager",
  "description": "🔧 Active system services",
  "output_file": "system/active_services.txt"
}

// Application-specific
{
  "command": "composer show --installed --format=json",
  "description": "🎼 Composer dependencies",
  "output_file": "development/composer_packages.json",
  "working_dir": "/var/www/html"
}
```

---

### ⚙️ **settings** - Core Configuration

Control Hedgii's behavior and sync options:

```json
{
  "settings": {
    "staging_dir": "/tmp/hedgii_staging",
    "backup_dir": "/var/backups/hedgii",
    "encrypt_passphrase_file": "/etc/hedgii/gpg_passphrase",
    "compression_format": "zip",
    
    "sync_method": "auto",
    "cloud_provider": "onedrive",
    
    "rclone_remote": "onedrive:hedgii-backups/",
    
    "onedrive_backup_dir": "hedgii-backups",
    "onedrive_config_dir": "/etc/hedgii/onedrive"
  }
}
```

#### **🗂️ Backup & Storage Settings**

- `staging_dir` *(string, optional)*: Temporary directory for backup preparation
  - Default: `"/tmp/hedgii_staging"`
  - Must be writable by hedgii user
  - Cleaned up after each backup

- `backup_dir` *(string, optional)*: Local directory for encrypted backup files
  - Default: `"/var/backups/hedgii"`
  - Directory is created if it doesn't exist
  - Should have sufficient space for temporary encrypted files

- `encrypt_passphrase_file` *(string, required)*: Path to GPG passphrase file
  - Must be readable by hedgii user only (chmod 600)
  - Contains plain text passphrase for GPG encryption
  - Example setup: `echo "your_passphrase" | sudo tee /etc/hedgii/gpg_passphrase && sudo chmod 600 /etc/hedgii/gpg_passphrase`

- `compression_format` *(string, optional)*: Archive format before encryption
  - Options: `"zip"` or `"tar.gz"`
  - Default: `"tar.gz"`
  - **`"zip"`**: Windows-friendly, better integration, native support
  - **`"tar.gz"`**: Unix-standard, better compression, preserves permissions
  - Affects output filename: `hedgii_backup_YYYYMMDD_HHMMSS.{zip|tar.gz}.gpg`

#### **☁️ Sync Method Configuration**

- `sync_method` *(string, optional)*: Which sync client to use
  - Options: `"auto"`, `"rclone"`, `"onedrive"`
  - Default: `"auto"`
  - **`"auto"`**: Automatically detects and chooses best available client
  - **`"rclone"`**: Force use of rclone (universal, 40+ cloud providers)
  - **`"onedrive"`**: Force use of OneDrive client (OneDrive-optimized)

- `cloud_provider` *(string, optional)*: Helps auto-detection choose optimal client
  - Options: `"onedrive"`, `"googledrive"`, `"dropbox"`, etc.
  - Default: `"onedrive"`
  - Used when `sync_method` is `"auto"`

#### **🔄 rclone Configuration**

- `rclone_remote` *(string, optional)*: rclone remote path for uploads
  - Format: `"remote_name:path/"`
  - Default: `"onedrive:hedgii-backups/"`
  - Configure remotes with: `rclone config`
  - Test with: `rclone ls remote_name:`

#### **📤 OneDrive Client Configuration**

- `onedrive_backup_dir` *(string, optional)*: Directory name in OneDrive
  - Default: `"hedgii-backups"`
  - Created automatically if it doesn't exist
  - All backups stored in this folder

- `onedrive_config_dir` *(string, optional)*: Local OneDrive client config directory
  - Default: `"/etc/hedgii/onedrive"`
  - Contains OneDrive client configuration and sync cache
  - Created during `hedgii setup-onedrive`

---

### 🚫 **exclusions** - File Exclusion Patterns

Patterns to exclude from all backups (applied to both file sources and custom command outputs):

```json
{
  "exclusions": [
    "*.tmp",
    "*.log.old",
    "node_modules",
    ".git",
    "*.cache",
    ".DS_Store",
    "Thumbs.db"
  ]
}
```

**Parameters:**
- Array of glob patterns (shell wildcards)
- Applied during `rsync` and `zip` operations
- Case-sensitive matching
- Relative to source directories

**Common Exclusion Patterns:**
```json
[
  // Temporary files
  "*.tmp", "*.temp", "*.swp", "*~",
  
  // Logs (keep current, exclude rotated)
  "*.log.old", "*.log.[0-9]*", "*.log.gz",
  
  // Development
  "node_modules", ".git", ".svn", ".hg",
  "vendor", "bower_components",
  
  // Cache directories
  "*.cache", "cache/*", ".cache",
  
  // OS files
  ".DS_Store", "Thumbs.db", "desktop.ini",
  
  // Build artifacts
  "dist", "build", "*.min.js", "*.min.css"
]
```

---

### 🎯 **Complete Configuration Examples**

#### **Web Server with Database**
```json
{
  "backup_sources": [
    {
      "source": "/var/www/html",
      "destination": "web/html",
      "description": "🌐 Main website files"
    },
    {
      "source": "/etc/nginx",
      "destination": "config/nginx",
      "description": "⚙️ Nginx configuration"
    },
    {
      "source": "/etc/ssl/certs/mydomain.crt",
      "destination": "security/ssl_cert.crt",
      "description": "🔐 SSL certificate"
    }
  ],
  "custom_commands": [
    {
      "command": "mysqldump --all-databases --single-transaction --routines --triggers",
      "description": "📊 Complete MySQL database dump",
      "output_file": "databases/mysql_full_dump.sql",
      "timeout": 600,
      "continue_on_error": false
    },
    {
      "command": "nginx -T",
      "description": "🔧 Nginx configuration test and dump",
      "output_file": "config/nginx_full_config.txt",
      "timeout": 30
    }
  ],
  "settings": {
    "compression_format": "zip",
    "sync_method": "auto",
    "cloud_provider": "onedrive"
  },
  "exclusions": [
    "*.log.old", "*.tmp", "cache/*", ".git"
  ]
}
```

#### **Development Environment**
```json
{
  "backup_sources": [
    {
      "source": "/home/developer/projects",
      "destination": "projects",
      "description": "💻 Development projects"
    },
    {
      "source": "/home/developer/.ssh",
      "destination": "security/ssh",
      "description": "🔐 SSH keys and config"
    }
  ],
  "custom_commands": [
    {
      "command": "git log --oneline --graph -20",
      "description": "🌳 Recent git commits",
      "output_file": "git/recent_commits.txt",
      "working_dir": "/home/developer/projects/main-project",
      "timeout": 30
    },
    {
      "command": "npm list --depth=0 --json",
      "description": "📦 NPM dependencies",
      "output_file": "dependencies/npm_packages.json",
      "working_dir": "/home/developer/projects/frontend",
      "continue_on_error": true
    },
    {
      "command": "docker images --format 'table {{.Repository}}:{{.Tag}}\\t{{.Size}}\\t{{.CreatedAt}}'",
      "description": "🐳 Docker images inventory",
      "output_file": "system/docker_images.txt",
      "timeout": 60
    }
  ],
  "settings": {
    "compression_format": "zip",
    "sync_method": "rclone",
    "rclone_remote": "googledrive:backups/dev-machine/"
  },
  "exclusions": [
    "node_modules", ".git", "dist", "build", 
    "*.log", "*.tmp", ".cache", "vendor"
  ]
}
```

#### **Docker Production Server**
```json
{
  "backup_sources": [
    {
      "source": "/opt/docker-compose",
      "destination": "docker/compose",
      "description": "🐳 Docker compose files"
    },
    {
      "source": "/var/lib/docker/volumes",
      "destination": "docker/volumes",
      "description": "💾 Docker persistent volumes"
    }
  ],
  "custom_commands": [
    {
      "command": "docker-compose config",
      "description": "🔧 Docker compose configuration",
      "output_file": "docker/resolved_compose.yml",
      "working_dir": "/opt/docker-compose",
      "timeout": 60
    },
    {
      "command": "docker system df -v",
      "description": "📊 Docker system usage",
      "output_file": "system/docker_usage.txt",
      "timeout": 30
    },
    {
      "command": "docker network ls && docker volume ls",
      "description": "🌐 Docker networks and volumes",
      "output_file": "docker/resources.txt",
      "timeout": 30
    }
  ],
  "settings": {
    "compression_format": "tar.gz",
    "sync_method": "auto"
  }
}
```

---

### ⚡ **Configuration Management Commands**

```bash
# 📝 Edit configuration with nano
sudo hedgii edit-config

# ✅ Validate configuration syntax
sudo hedgii validate-config

# 📦 Check current compression format
sudo hedgii compression-info

# 🔐 Change GPG passphrase
sudo hedgii change-passphrase

# 🧪 Test custom commands without full backup
sudo hedgii test-commands
```

---

### 🔍 **Configuration Validation**

Hedgii automatically validates your configuration:

- **JSON syntax** - Must be valid JSON
- **Required fields** - Source, destination, description for sources
- **Path validation** - Source paths must exist and be readable
- **Command syntax** - Custom commands are validated before execution
- **Timeout values** - Must be positive integers
- **File permissions** - Passphrase file must be secure (600 permissions)

**Common Validation Errors:**
```bash
# Invalid JSON
hedgii validate-config
# Output: ✗ Configuration JSON is invalid

# Missing required field
# Output: ✗ backup_sources[0].source is missing

# Invalid path
# Output: ⚠️ Source not found: /nonexistent/path
```

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

# 📝 Edit configuration with nano
sudo hedgii edit-config

# 🔐 Change GPG encryption passphrase
sudo hedgii change-passphrase

# 📦 Show current compression format information
sudo hedgii compression-info
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
