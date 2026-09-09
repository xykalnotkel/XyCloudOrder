-- ============================================================
-- 0005 — Chat CS: pesan suara + balasan (reply) ala WhatsApp
--   cs_messages bertambah kolom:
--     tipe        : teks | gambar | audio | system
--     audio       : URL berkas suara (Cloudinary video/upload)
--     durasi      : lama suara (detik)
--     reply_to    : id pesan yang dibalas
--     reply_teks  : cuplikan pesan yang dibalas (untuk tampilan)
--     reply_tipe  : tipe pesan yang dibalas (teks|gambar|audio)
-- ============================================================
ALTER TABLE cs_messages ADD COLUMN tipe TEXT NOT NULL DEFAULT 'teks';
ALTER TABLE cs_messages ADD COLUMN audio TEXT;
ALTER TABLE cs_messages ADD COLUMN durasi REAL;
ALTER TABLE cs_messages ADD COLUMN reply_to TEXT;
ALTER TABLE cs_messages ADD COLUMN reply_teks TEXT;
ALTER TABLE cs_messages ADD COLUMN reply_tipe TEXT NOT NULL DEFAULT 'teks';
