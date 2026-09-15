-- ============================================================
--  0012 — Batch L: identitas profil lanjutan + gaya nama
-- ============================================================
--  Permintaan pemilik 2026-09-15:
--  1. Slogan profil (tagline pendek di bawah nama, maks 60 huruf).
--  2. Bio link (satu URL publik di profil, divalidasi server).
--  3. Gaya nama kustom (font/efek gradasi/animasi) — sebagian
--     khusus langganan Pro/VIP, whitelist GAYA_NAMA di index.js.
--  Catatan: bingkai baru (naga, sakura, sirkuit, sayap, petir,
--  mahkota) hanya menambah whitelist BINGKAI_PROFIL — tanpa DDL.

ALTER TABLE users ADD COLUMN slogan TEXT;
ALTER TABLE users ADD COLUMN bio_link TEXT;
ALTER TABLE users ADD COLUMN gaya_nama TEXT;
