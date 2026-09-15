-- ============================================================
--  0011 — Batch I: profil lengkap, transfer saldo, leaderboard nyata
-- ============================================================
--  Permintaan pemilik 2026-09-15:
--  1. Bingkai avatar profil (frame) — beberapa khusus langganan.
--  2. Banner profil media kustom (GIF / MP4 yang dikonversi ke GIF),
--     khusus pelanggan Pro/VIP.
--  3. Pendinginan ganti nama tampilan (7 hari) & username (30 hari).
--  4. Transfer saldo antar pengguna dengan PIN 6 digit.
--  5. Leaderboard nyata (dari data transaksi & total belanja).

-- Profil: bingkai avatar + media banner kustom (JSON {tipe,url,gif}).
ALTER TABLE users ADD COLUMN bingkai TEXT;
ALTER TABLE users ADD COLUMN banner_media TEXT;

-- Pendinginan perubahan identitas (ISO timestamp; NULL = belum pernah diubah).
ALTER TABLE users ADD COLUMN nama_diubah_pada TEXT;
ALTER TABLE users ADD COLUMN username_diubah_pada TEXT;

-- PIN transfer saldo: format hash sama dengan password (salt$hash PBKDF2).
ALTER TABLE users ADD COLUMN pin_transfer TEXT;

-- Buku besar transfer antar pengguna (satu baris per transfer, untuk audit
-- kedua sisi + batas harian). Riwayat per pengguna tetap di tabel `transaksi`
-- (tipe transfer_keluar / transfer_masuk).
CREATE TABLE IF NOT EXISTS transfer (
  id      TEXT PRIMARY KEY,
  dari_id TEXT NOT NULL,
  ke_id   TEXT NOT NULL,
  nominal INTEGER NOT NULL,
  catatan TEXT,
  dibuat  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_transfer_dari ON transfer(dari_id, dibuat);
CREATE INDEX IF NOT EXISTS idx_transfer_ke   ON transfer(ke_id, dibuat);
