-- ============================================================
--  0007 — Sosial: follow, DM, profil luas, simpan posting
-- ============================================================
--  Batch D (2026-09-13): komunitas dilengkapi fitur sosial dasar yang diminta:
--  follow/unfollow, pesan pribadi (DM) antar pengguna termasuk pesan suara,
--  profil yang bisa dikustom lebih luas (bio + tema banner), dan simpan
--  posting forum sebagai bookmark pribadi.

-- Profil yang dapat dikustom pengguna.
ALTER TABLE users ADD COLUMN bio TEXT;          -- teks bebas max 240 karakter
ALTER TABLE users ADD COLUMN banner TEXT;       -- id tema banner profil (gradasi)

-- Graph follow sederhana.
CREATE TABLE IF NOT EXISTS follows (
  ikut_id   TEXT NOT NULL,
  target_id TEXT NOT NULL,
  waktu     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (ikut_id, target_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_target ON follows(target_id);

-- Pesan pribadi antar pengguna (teks / suara / gambar).
CREATE TABLE IF NOT EXISTS dm (
  id      TEXT PRIMARY KEY,
  dari_id TEXT NOT NULL,
  ke_id   TEXT NOT NULL,
  teks    TEXT NOT NULL DEFAULT '',
  audio   TEXT,
  durasi  REAL,
  gambar  TEXT,
  tipe    TEXT NOT NULL DEFAULT 'teks',
  dibaca  INTEGER NOT NULL DEFAULT 0,
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_dm_dari ON dm(dari_id, waktu);
CREATE INDEX IF NOT EXISTS idx_dm_ke   ON dm(ke_id, waktu);

-- Peta thread yang dibisukan pengguna: {"dm:u_x": 1735689600000, "cs": ...}.
-- Diisi lewat POST /me/bisukan (dipakai tombol aksi "Bisukan" pada push).
ALTER TABLE users ADD COLUMN bisu_notif TEXT;

-- Bookmark posting forum per pengguna.
CREATE TABLE IF NOT EXISTS simpan_post (
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  waktu   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (post_id, user_id)
);
