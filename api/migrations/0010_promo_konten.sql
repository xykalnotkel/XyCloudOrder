-- Batch G (2026-09-15): kolom konten untuk promo_overlay
-- (popup fullscreen & strip nav menampilkan gambar + teks konten).
ALTER TABLE promo_overlay ADD COLUMN konten TEXT NOT NULL DEFAULT '';
