-- Vibe Vault D1 Database Schema

-- Users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    device_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login_at DATETIME,
    subscription_status TEXT DEFAULT 'free', -- free, active, expired
    subscription_expires_at DATETIME,
    backup_enabled BOOLEAN DEFAULT FALSE,
    encryption_key_hash TEXT -- For verifying backup encryption
);

-- Cloud backups table
CREATE TABLE IF NOT EXISTS backups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    backup_data TEXT NOT NULL, -- Encrypted JSON of secrets
    backup_size INTEGER, -- Size in bytes
    checksum TEXT, -- SHA256 of decrypted data
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    device_name TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Backup schedules table
CREATE TABLE IF NOT EXISTS backup_schedules (
    id TEXT PRIMARY KEY,
    user_id TEXT UNIQUE NOT NULL,
    frequency TEXT NOT NULL, -- daily, weekly, monthly
    day_of_week INTEGER, -- 0-6 for weekly (Sunday=0)
    hour_of_day INTEGER, -- 0-23
    last_backup_at DATETIME,
    next_backup_at DATETIME,
    enabled BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Audit log for cloud operations
CREATE TABLE IF NOT EXISTS cloud_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL, -- login, backup_created, backup_restored, subscription_changed
    details TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_backups_user_id ON backups(user_id);
CREATE INDEX IF NOT EXISTS idx_backups_created_at ON backups(created_at);
CREATE INDEX IF NOT EXISTS idx_cloud_audit_user_id ON cloud_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_cloud_audit_created_at ON cloud_audit(created_at);
