-- Additive: existing accounts are not assigned a guessed device.
ALTER TABLE users ADD COLUMN registration_device TEXT;
ALTER TABLE users ADD COLUMN deleted_at TEXT;
ALTER TABLE users ADD COLUMN blocked_before_trash INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN session_version INTEGER NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS security_devices (
 id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'unknown', model TEXT NOT NULL DEFAULT '',
 registrations INTEGER NOT NULL DEFAULT 0, max_accounts INTEGER, blocked INTEGER NOT NULL DEFAULT 0,
 reason TEXT, created_at TEXT NOT NULL, last_seen TEXT NOT NULL, reset_at TEXT
);
CREATE TABLE IF NOT EXISTS security_device_users (
 device_id TEXT NOT NULL, user_id TEXT NOT NULL, signup INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL DEFAULT (datetime('now')), last_seen TEXT NOT NULL DEFAULT (datetime('now')),
 PRIMARY KEY(device_id,user_id)
);
CREATE TABLE IF NOT EXISTS security_events (
 id TEXT PRIMARY KEY, kind TEXT NOT NULL, subject TEXT, route TEXT, note TEXT, count INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL, last_seen TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_security_events_time ON security_events(last_seen);
CREATE INDEX IF NOT EXISTS idx_users_trash ON users(deleted_at);
CREATE TABLE IF NOT EXISTS oauth_states (
 id TEXT PRIMARY KEY, provider TEXT NOT NULL, device_id TEXT, expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS media_assets (
 id TEXT PRIMARY KEY, url TEXT NOT NULL UNIQUE, folder TEXT NOT NULL, format TEXT,
 width INTEGER, height INTEGER, bytes INTEGER, animated INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TRIGGER IF NOT EXISTS register_device_quota AFTER INSERT ON users
WHEN NEW.registration_device IS NOT NULL BEGIN
 SELECT RAISE(ABORT,'DEVICE_UNKNOWN') WHERE NOT EXISTS(SELECT 1 FROM security_devices WHERE id=NEW.registration_device);
 SELECT RAISE(ABORT,'DEVICE_BLOCKED') WHERE EXISTS(SELECT 1 FROM security_devices WHERE id=NEW.registration_device AND blocked=1);
 SELECT RAISE(ABORT,'DEVICE_LIMIT') WHERE EXISTS(
  SELECT 1 FROM security_devices d WHERE d.id=NEW.registration_device AND d.registrations>=COALESCE(d.max_accounts,
    (SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='security_device_accounts'),2));
 UPDATE security_devices SET registrations=registrations+1,last_seen=datetime('now') WHERE id=NEW.registration_device;
 INSERT INTO security_device_users(device_id,user_id,signup) VALUES(NEW.registration_device,NEW.id,1);
END;
