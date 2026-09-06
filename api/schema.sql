-- ============================================================
-- XyCloud — skema Cloudflare D1
-- jalankan: wrangler d1 execute xycloud --remote --file=./schema.sql
-- ============================================================

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id        TEXT PRIMARY KEY,
  nama      TEXT NOT NULL,
  email     TEXT NOT NULL UNIQUE,
  password  TEXT NOT NULL,          -- simpan hash (SHA-256 + salt)
  phone     TEXT,
  saldo     INTEGER NOT NULL DEFAULT 0,
  tier      TEXT NOT NULL DEFAULT 'basic',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

DROP TABLE IF EXISTS pc_plans;
CREATE TABLE pc_plans (
  id             TEXT PRIMARY KEY,
  nama           TEXT NOT NULL,
  gpu            TEXT NOT NULL,
  cpu            TEXT NOT NULL,
  ram_gb         INTEGER NOT NULL,
  storage_gb     INTEGER NOT NULL,
  harga_per_jam  INTEGER NOT NULL,
  harga_per_hari INTEGER NOT NULL,
  region         TEXT NOT NULL,
  tag            TEXT,
  total_unit     INTEGER NOT NULL,
  unit_tersedia  INTEGER NOT NULL,
  gambar         TEXT
);

DROP TABLE IF EXISTS akun_produk;
CREATE TABLE akun_produk (
  id          TEXT PRIMARY KEY,
  nama        TEXT NOT NULL,
  kategori    TEXT NOT NULL,
  deskripsi   TEXT,
  harga       INTEGER NOT NULL,
  harga_coret INTEGER DEFAULT 0,
  stok        INTEGER NOT NULL DEFAULT 0,
  rating      REAL DEFAULT 5,
  terjual     INTEGER DEFAULT 0,
  gambar      TEXT,
  fitur       TEXT,               -- JSON array
  garansi     TEXT DEFAULT '7 hari'
);

-- stok akun (kredensial yang siap dikirim ke pembeli)
DROP TABLE IF EXISTS akun_stok;
CREATE TABLE akun_stok (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  produk_id  TEXT NOT NULL,
  email      TEXT NOT NULL,
  password   TEXT NOT NULL,
  terpakai   INTEGER NOT NULL DEFAULT 0,
  user_id    TEXT
);

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  id         TEXT PRIMARY KEY,
  kode       TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  plan_id    TEXT NOT NULL,
  plan_nama  TEXT NOT NULL,
  durasi_jam INTEGER NOT NULL,
  total      INTEGER NOT NULL,
  status     TEXT NOT NULL DEFAULT 'pending',
  progress   INTEGER NOT NULL DEFAULT 0,
  host       TEXT,
  username   TEXT,
  password   TEXT,
  dibuat     TEXT NOT NULL DEFAULT (datetime('now')),
  mulai      TEXT,
  berakhir   TEXT
);
CREATE INDEX idx_orders_user ON orders(user_id);

DROP TABLE IF EXISTS transaksi;
CREATE TABLE transaksi (
  id      TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  judul   TEXT NOT NULL,
  tipe    TEXT NOT NULL,
  nominal INTEGER NOT NULL,
  status  TEXT NOT NULL DEFAULT 'sukses',
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_trx_user ON transaksi(user_id);

DROP TABLE IF EXISTS cs_messages;
CREATE TABLE cs_messages (
  id      TEXT PRIMARY KEY,
  room    TEXT NOT NULL,
  user_id TEXT NOT NULL,
  dari    TEXT NOT NULL,          -- user | cs | system
  teks    TEXT NOT NULL,
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_cs_room ON cs_messages(room);

-- ------------------------- SEED -------------------------
INSERT INTO users (id, nama, email, password, phone, saldo, tier) VALUES
 ('u_001','Rangga Pratama','rangga@xycloud.id','xycloud123','081234567890',275000,'pro');

INSERT INTO pc_plans VALUES
 ('pc-lite','XyLite','GTX 1650 4GB','Ryzen 5 3600',16,256,5000,65000,'Jakarta','Hemat',20,12,''),
 ('pc-gaming','XyGaming','RTX 3060 12GB','Ryzen 7 5800X',32,512,12000,150000,'Jakarta','Populer',15,4,''),
 ('pc-editor','XyCreator','RTX 4070 12GB','i7-13700K',64,1024,20000,240000,'Singapore','Editing',10,6,''),
 ('pc-ultra','XyUltra','RTX 4090 24GB','i9-14900K',128,2048,38000,450000,'Singapore','Ultra',6,0,'');

INSERT INTO akun_produk (id,nama,kategori,deskripsi,harga,harga_coret,stok,rating,terjual,gambar,fitur,garansi) VALUES
 ('ak-steam','Steam Account + 5 AAA Games','Gaming','Akun Steam siap pakai berisi 5 game AAA populer.',185000,250000,8,4.9,1240,'','["Full akses email","Bisa ganti password","Garansi 30 hari"]','30 hari'),
 ('ak-gamepass','Xbox Game Pass Ultimate 1 Bulan','Subscription','Akses 400+ game PC & cloud gaming.',65000,120000,25,4.8,3120,'','["Aktivasi akun sendiri","Cloud gaming","Legal & resmi"]','30 hari'),
 ('ak-netflix','Netflix Premium 4K — 1 Profil','Streaming','Sharing profil privat kualitas 4K UHD.',28000,54000,3,4.7,8900,'','["4K UHD","Profil privat","Garansi full replace"]','30 hari'),
 ('ak-adobe','Adobe Creative Cloud All Apps','Produktivitas','Semua aplikasi Adobe untuk 1 tahun.',320000,600000,5,4.9,640,'','["All apps","1 tahun","Cloud storage 100GB"]','1 tahun'),
 ('ak-spotify','Spotify Premium Individual 3 Bulan','Streaming','Upgrade akun pribadi tanpa iklan.',42000,82000,40,4.8,5400,'','["Akun sendiri","Tanpa iklan","Proses instan"]','90 hari');
