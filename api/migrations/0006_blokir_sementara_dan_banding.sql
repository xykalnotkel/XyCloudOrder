-- ============================================================
--  0006 — Blokir sementara, riwayat pelanggaran, dan banding
-- ============================================================
--  Audit 2026-09-13: pembekuan akun sebelumnya hanya punya satu bentuk
--  (diblokir = 1, selamanya) dan pengguna yang dibekukan hanya bisa banding
--  lewat chat CS. Sekarang admin bisa memilih durasi (sementara/permanen),
--  setiap pembekuan tercatat sebagai riwayat pelanggaran, dan pengguna bisa
--  mengajukan banding dari dalam aplikasi (layar Akun Dibekukan).

-- Batas akhir pembekuan sementara. NULL = permanen (saat diblokir = 1).
-- Isi ISO-8601; lewat dari waktu ini akun pulih otomatis saat dibaca.
ALTER TABLE users ADD COLUMN blokir_sampai TEXT;

-- Riwayat pelanggaran: satu baris per tindakan moderasi (blokir/peringatan).
CREATE TABLE IF NOT EXISTS pelanggaran (
  id      TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  jenis   TEXT NOT NULL DEFAULT 'blokir',   -- blokir | peringatan
  alasan  TEXT,
  sampai  TEXT,                              -- salinan batas blokir saat itu
  oleh    TEXT,                              -- nama admin pelaku
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_pelanggaran_user ON pelanggaran(user_id);

-- Banding dari pengguna yang dibekukan.
CREATE TABLE IF NOT EXISTS banding (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL,
  pesan             TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'baru',  -- baru | diterima | ditolak
  waktu             TEXT NOT NULL DEFAULT (datetime('now')),
  tanggapan         TEXT,
  waktu_tanggapan   TEXT
);
CREATE INDEX IF NOT EXISTS idx_banding_user  ON banding(user_id);
CREATE INDEX IF NOT EXISTS idx_banding_status ON banding(status);
