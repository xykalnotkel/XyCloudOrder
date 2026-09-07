-- Additive upgrade. No fabricated orders, hosts, or credentials.
ALTER TABLE orders ADD COLUMN request_id TEXT;
ALTER TABLE orders ADD COLUMN metode TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE orders ADD COLUMN agen_id TEXT;
ALTER TABLE orders ADD COLUMN stok_kembali INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN dikembalikan INTEGER NOT NULL DEFAULT 0;
ALTER TABLE cs_messages ADD COLUMN client_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_order_request ON orders(user_id,request_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cs_client ON cs_messages(room,client_id);
CREATE INDEX IF NOT EXISTS idx_cs_room_time ON cs_messages(room,waktu);
CREATE INDEX IF NOT EXISTS idx_sesi_order_status ON sesi(order_id,status);

-- Charge, stock and physical-host reservation are one SQLite transaction.
CREATE TRIGGER IF NOT EXISTS order_saldo_baru AFTER INSERT ON orders
WHEN NEW.metode='saldo' BEGIN
 SELECT RAISE(ABORT,'ORDER_INVALID') WHERE NEW.total<0 OR NEW.durasi_jam<1 OR NEW.durasi_jam>24;
 SELECT RAISE(ABORT,'SALDO_TIDAK_CUKUP') WHERE NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.user_id AND saldo>=NEW.total);
 SELECT RAISE(ABORT,'UNIT_PENUH') WHERE NOT EXISTS(SELECT 1 FROM pc_plans WHERE id=NEW.plan_id AND unit_tersedia>0);
 SELECT RAISE(ABORT,'UNIT_PENUH') WHERE NOT EXISTS(SELECT 1 FROM agen WHERE id=NEW.agen_id AND (sesi_aktif IS NULL OR sesi_aktif=''));
 SELECT RAISE(ABORT,'VOUCHER_TIDAK_TERSEDIA') WHERE NEW.voucher IS NOT NULL AND (
   NOT EXISTS(SELECT 1 FROM voucher WHERE kode=NEW.voucher AND aktif=1 AND (kuota=0 OR terpakai<kuota))
   OR EXISTS(SELECT 1 FROM voucher_pakai WHERE kode=NEW.voucher AND user_id=NEW.user_id));
 UPDATE users SET saldo=saldo-NEW.total,total_belanja=total_belanja+NEW.total WHERE id=NEW.user_id;
 UPDATE pc_plans SET unit_tersedia=unit_tersedia-1 WHERE id=NEW.plan_id;
 UPDATE agen SET sesi_aktif='order:'||NEW.id WHERE id=NEW.agen_id;
 UPDATE voucher SET terpakai=terpakai+1 WHERE kode=NEW.voucher;
 INSERT INTO voucher_pakai(id,kode,user_id,ref_id,potongan)
   SELECT 'vp_'||NEW.id,NEW.voucher,NEW.user_id,NEW.id,NEW.potongan WHERE NEW.voucher IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS order_saldo_selesai AFTER UPDATE OF status ON orders
WHEN NEW.metode='saldo' AND NEW.status IN ('selesai','batal') AND OLD.status NOT IN ('selesai','batal') BEGIN
 UPDATE pc_plans SET unit_tersedia=MIN(total_unit,unit_tersedia+1) WHERE id=NEW.plan_id AND NEW.stok_kembali=0;
 UPDATE orders SET stok_kembali=1 WHERE id=NEW.id;
 -- Unstarted reservations can be released immediately; started machines stay locked until cleanup ACK.
 UPDATE agen SET sesi_aktif=NULL WHERE sesi_aktif='order:'||NEW.id;
 UPDATE users SET saldo=saldo+NEW.total,total_belanja=MAX(0,total_belanja-NEW.total)
   WHERE id=NEW.user_id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
   SELECT 'refund_'||NEW.id,NEW.user_id,'Pengembalian sewa gagal/batal sebelum siap','refund',NEW.total,'sukses',datetime('now')
   WHERE NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE kode=NEW.voucher
   AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 DELETE FROM voucher_pakai WHERE ref_id=NEW.id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 UPDATE orders SET dikembalikan=1 WHERE id=NEW.id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning');
END;

CREATE TABLE IF NOT EXISTS media_hapus (url TEXT PRIMARY KEY, dibuat TEXT NOT NULL DEFAULT (datetime('now')), percobaan INTEGER NOT NULL DEFAULT 0);
