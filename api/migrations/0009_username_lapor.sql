-- ============================================================
--  0009 — Username unik + filter nama (Batch E)
-- ============================================================
--  Username publik (unik, bisa dicek ketersediaannya). NULL =
--  belum dipakai; index unik parsial supaya banyak NULL aman.
ALTER TABLE users ADD COLUMN username TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username) WHERE username IS NOT NULL;
