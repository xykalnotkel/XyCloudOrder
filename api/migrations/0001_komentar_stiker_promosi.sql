-- Migrasi non-destruktif v2.4.0: tidak menghapus tabel/data pengguna.
ALTER TABLE forum_balasan ADD COLUMN stiker TEXT;
CREATE TABLE IF NOT EXISTS promo_overlay (
 id TEXT PRIMARY KEY, nama TEXT NOT NULL DEFAULT 'Promo', jenis TEXT NOT NULL DEFAULT 'floating',
 gambar TEXT NOT NULL, aksi TEXT NOT NULL DEFAULT 'url', target TEXT NOT NULL DEFAULT '',
 posisi TEXT NOT NULL DEFAULT 'kanan', platform TEXT NOT NULL DEFAULT 'semua',
 aktif INTEGER NOT NULL DEFAULT 1, urutan INTEGER NOT NULL DEFAULT 0, revisi INTEGER NOT NULL DEFAULT 1,
 dibuat TEXT NOT NULL DEFAULT (datetime('now')), diubah TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_promo_aktif ON promo_overlay(aktif,urutan);
CREATE INDEX IF NOT EXISTS idx_balasan_induk ON forum_balasan(post_id,balas_ke,dibuat);
CREATE TRIGGER IF NOT EXISTS sinkron_identitas_pengguna
AFTER UPDATE OF nama,foto ON users BEGIN
 UPDATE forum_post SET nama=NEW.nama,foto=NEW.foto WHERE user_id=NEW.id;
 UPDATE forum_balasan SET nama=NEW.nama,foto=NEW.foto WHERE user_id=NEW.id;
 UPDATE ulasan SET nama=NEW.nama WHERE user_id=NEW.id;
 UPDATE ulasan_pc SET nama=NEW.nama WHERE user_id=NEW.id;
END;
UPDATE forum_post SET nama=(SELECT nama FROM users WHERE id=forum_post.user_id), foto=(SELECT foto FROM users WHERE id=forum_post.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE forum_balasan SET nama=(SELECT nama FROM users WHERE id=forum_balasan.user_id), foto=(SELECT foto FROM users WHERE id=forum_balasan.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE ulasan SET nama=(SELECT nama FROM users WHERE id=ulasan.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE ulasan_pc SET nama=(SELECT nama FROM users WHERE id=ulasan_pc.user_id) WHERE user_id IN (SELECT id FROM users);
