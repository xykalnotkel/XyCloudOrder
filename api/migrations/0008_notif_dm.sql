-- ============================================================
--  0008 — Toggle notifikasi pesan langsung (DM)
-- ============================================================
--  Batch D: pengguna bisa mematikan push DM tanpa mematikan
--  notifikasi lain (settings lebih lengkap). Default: aktif.
ALTER TABLE users ADD COLUMN notif_dm INTEGER NOT NULL DEFAULT 1;
