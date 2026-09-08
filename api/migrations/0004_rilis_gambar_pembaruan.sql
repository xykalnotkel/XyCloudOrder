-- Tambah kolom 'gambar' pada tabel rilis: URL banner/ilustrasi kustom per rilis
-- yang tampil di popup pembaruan aplikasi. Boleh NULL -> app memakai fallback generik.
ALTER TABLE rilis ADD COLUMN gambar TEXT;
