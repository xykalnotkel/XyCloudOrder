/**
 * Uji Batch I: pendinginan ganti nama/username, validasi username ketat,
 * bingkai profil, gate banner media langganan, transfer saldo antar
 * pengguna (PIN 6 digit), dan leaderboard nyata dari data transaksi.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

test('Batch I: cooldown nama 7 hari & username 30 hari + validasi ketat', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('a','Andi','a@example.invalid','x')").run();
    const ta = await token('a');
    const A = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + ta });

    // --- nama tampilan ---
    // Perubahan pertama boleh (belum ada cap waktu).
    let r = await A('/me', 'PATCH', { nama: 'Andi Pertama' });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.data.nama, 'Andi Pertama');
    assert.ok(r.json.data.nama_diubah_pada);
    // Perubahan kedua dalam 7 hari ditolak.
    r = await A('/me', 'PATCH', { nama: 'Andi Kedua' });
    assert.equal(r.status, 429);
    // Nama yang sama persis (tidak berubah) tidak kena cooldown.
    r = await A('/me', 'PATCH', { nama: 'andi pertama' });
    assert.equal(r.status, 200);

    // --- username ---
    // Pemasangan pertama boleh.
    r = await A('/me', 'PATCH', { username: 'andi_publik' });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.ok(r.json.data.username_diubah_pada);
    // Penggantian dalam 30 hari ditolak.
    r = await A('/me', 'PATCH', { username: 'andi_baru' });
    assert.equal(r.status, 429);

    // --- validasi format ketat (pakai akun baru tanpa cooldown) ---
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('c','Caca','c@example.invalid','x')").run();
    const tc = await token('c');
    const C = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + tc });
    const buruk = ['.caca', 'caca.', 'ca..ca', '_caca', 'ab', 'caca space'];
    for (const un of buruk) {
      const rr = await C('/me', 'PATCH', { username: un });
      assert.equal(rr.status, 422, `username '${un}' harusnya ditolak: ${JSON.stringify(rr.json)}`);
    }
    // Dicadangkan (persis maupun awalan merek/official).
    for (const un of ['admin', 'a.d.m.i.n', 'xycloudstore', 'xycloud_dev', 'officialxy', 'support1']) {
      const rr = await C('/me', 'PATCH', { username: un });
      assert.equal(rr.status, 422, `username cadangan '${un}' harusnya ditolak`);
    }
    // Yang valid tetap lolos; huruf besar dinormalisasi ke kecil.
    r = await C('/me', 'PATCH', { username: 'Caca.Gaming_99' });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.data.username, 'caca.gaming_99');

    // /cek-nama memakai aturan yang sama.
    r = await C('/cek-nama', 'POST', { username: 'admin' });
    assert.equal(r.json.data.username.tersedia, false);
    assert.match(r.json.data.username.alasan, /dicadangkan/i);
    r = await C('/cek-nama', 'POST', { username: 'belum_ada_1' });
    assert.equal(r.json.data.username.tersedia, true);
  } finally {
    await mf.dispose();
  }
});

test('Batch I: bingkai profil + gate langganan banner media', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password,tier,saldo) VALUES('a','Andi','a@example.invalid','x','basic',0)").run();
    const ta = await token('a');
    const A = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + ta });

    // Bingkai standar boleh untuk semua tier.
    let r = await A('/me', 'PATCH', { bingkai: 'emas' });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.bingkai, 'emas');
    // Bingkai tidak dikenal ditolak.
    assert.equal((await A('/me', 'PATCH', { bingkai: 'xxx' })).status, 422);
    // Bingkai premium (aurora/permata) ditolak untuk basic.
    assert.equal((await A('/me', 'PATCH', { bingkai: 'aurora' })).status, 403);
    // Banner media ditolak untuk basic.
    r = await A('/me/banner-media', 'POST', { berkas: 'data:image/gif;base64,R0lGOD' });
    assert.equal(r.status, 403);

    // Naikkan ke pro → bingkai premium boleh; unggah media gagal 502 karena
    // kredensial Cloudinary tidak ada di lingkungan uji (gate sudah lolos).
    await db.prepare("UPDATE users SET tier='pro' WHERE id='a'").run();
    r = await A('/me', 'PATCH', { bingkai: 'aurora' });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.bingkai, 'aurora');
    // Tipe berkas bukan gif/mp4 ditolak sebelum menyentuh Cloudinary.
    r = await A('/me/banner-media', 'POST', { berkas: 'data:image/png;base64,AAAA' });
    assert.equal(r.status, 422);
    r = await A('/me/banner-media', 'POST', { berkas: 'data:image/gif;base64,R0lGOD' });
    assert.equal(r.status, 502);
    // Hapus banner media selalu boleh.
    r = await A('/me/banner-media', 'DELETE');
    assert.equal(r.status, 200);

    // Profil publik menyertakan bingkai & banner_media.
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('b','Budi','b@example.invalid','x')").run();
    const tb = await token('b');
    r = await call('/users/a/profil', 'GET', undefined, { Authorization: 'Bearer ' + tb });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.bingkai, 'aurora');
    assert.equal('banner_media' in r.json.data, true);

    // Batch J: bingkai aset AI (api/galaksi) ikut gate langganan yang sama.
    r = await A('/me', 'PATCH', { bingkai: 'galaksi' }); // tier pro → boleh
    assert.equal(r.status, 200);
    await db.prepare("UPDATE users SET tier='basic' WHERE id='a'").run();
    assert.equal((await A('/me', 'PATCH', { bingkai: 'api' })).status, 403);
    await db.prepare("UPDATE users SET tier='vip' WHERE id='a'").run();
    r = await A('/me', 'PATCH', { bingkai: 'api' });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.bingkai, 'api');
  } finally {
    await mf.dispose();
  }
});

test('Batch I: transfer saldo antar pengguna dengan PIN', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password,username,saldo) VALUES('a','Andi','a@example.invalid','x','andi',150000)").run();
    await db.prepare("INSERT INTO users(id,nama,email,password,username,saldo) VALUES('b','Budi','b@example.invalid','x','budi',0)").run();
    const ta = await token('a');
    const A = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + ta });

    // Cari penerima: @username dan email persis; tidak ada fuzzy.
    let r = await A('/me/transfer/cari?q=@budi');
    assert.equal(r.status, 200);
    assert.equal(r.json.data.id, 'b');
    r = await A('/me/transfer/cari?q=b@example.invalid');
    assert.equal(r.json.data.id, 'b');
    assert.equal((await A('/me/transfer/cari?q=tidakada')).status, 404);
    assert.equal((await A('/me/transfer/cari?q=@andi')).status, 422); // diri sendiri

    // Tanpa PIN → 428; pasang PIN dengan konfirmasi password.
    r = await A('/me/transfer', 'POST', { ke: 'b', nominal: 50000, pin: '123456' });
    assert.equal(r.status, 428);
    assert.equal((await A('/me/pin-transfer', 'POST', { pin: '12ab', konfirmasi: 'x' })).status, 422);
    assert.equal((await A('/me/pin-transfer', 'POST', { pin: '123456', konfirmasi: 'salah' })).status, 401);
    r = await A('/me/pin-transfer', 'POST', { pin: '123456', konfirmasi: 'x' });
    assert.equal(r.status, 200);

    // GET /me: hash PIN tidak bocor, hanya flag.
    r = await A('/me');
    assert.equal(r.json.data.pin_transfer, undefined);
    assert.equal(r.json.data.pin_transfer_aktif, 1);

    // Nominal di bawah minimum / atas maksimum.
    assert.equal((await A('/me/transfer', 'POST', { ke: 'b', nominal: 9999, pin: '123456' })).status, 422);
    assert.equal((await A('/me/transfer', 'POST', { ke: 'b', nominal: 5000001, pin: '123456' })).status, 422);
    // PIN salah.
    assert.equal((await A('/me/transfer', 'POST', { ke: 'b', nominal: 50000, pin: '000000' })).status, 401);
    // Kirim diri sendiri.
    assert.equal((await A('/me/transfer', 'POST', { ke: 'a', nominal: 50000, pin: '123456' })).status, 422);

    // Transfer sah.
    r = await A('/me/transfer', 'POST', { ke: 'b', nominal: 50000, pin: '123456', catatan: 'Traktir kopi' });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.data.saldo, 100000);
    const a = await db.prepare('SELECT saldo FROM users WHERE id=\'a\'').first();
    const bb = await db.prepare('SELECT saldo FROM users WHERE id=\'b\'').first();
    assert.equal(a.saldo, 100000);
    assert.equal(bb.saldo, 50000);
    // Buku besar + riwayat dua sisi.
    const tf = await db.prepare('SELECT * FROM transfer WHERE dari_id=\'a\' AND ke_id=\'b\'').first();
    assert.equal(tf.nominal, 50000);
    assert.equal(tf.catatan, 'Traktir kopi');
    const keluar = await db.prepare("SELECT * FROM transaksi WHERE user_id='a' AND tipe='transfer_keluar'").first();
    assert.equal(keluar.nominal, -50000);
    const masuk = await db.prepare("SELECT * FROM transaksi WHERE user_id='b' AND tipe='transfer_masuk'").first();
    assert.equal(masuk.nominal, 50000);
    // Notifikasi penerima tercatat.
    const n = await db.prepare("SELECT * FROM notifikasi WHERE user_id='b' AND ref_jenis='transfer'").first();
    assert.ok(n && /50\.000/.test(n.pesan));

    // Saldo tidak cukup.
    assert.equal((await A('/me/transfer', 'POST', { ke: 'b', nominal: 5000000, pin: '123456' })).status, 422);

    // Batas harian 10 juta: dua transfer 5jt masih boleh bila saldo cukup,
    // di sini saldo tinggal 100rb jadi cukup uji guard saldo saja (di atas).
  } finally {
    await mf.dispose();
  }
});

test('Batch I: leaderboard nyata dari transaksi & total belanja', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password,username,total_belanja) VALUES('a','Andi','a@example.invalid','x','andi',250000)").run();
    await db.prepare("INSERT INTO users(id,nama,email,password,username,total_belanja) VALUES('b','Budi','b@example.invalid','x','budi',900000)").run();
    await db.prepare("INSERT INTO users(id,nama,email,password,username,total_belanja,diblokir) VALUES('c','Caca','c@example.invalid','x','caca',999999,1)").run();
    // Transaksi bulan berjalan (default waktu = now).
    await db.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal) VALUES('t1','a','Sewa','sewa',-120000)").run();
    await db.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal) VALUES('t2','a','Sewa','sewa',-30000)").run();
    await db.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal) VALUES('t3','b','Akun','akun',-75000)").run();
    // Transfer keluar TIDAK dihitung sebagai poin belanja.
    await db.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal) VALUES('t4','a','Transfer','transfer_keluar',-500000)").run();
    // Top up (positif) juga tidak dihitung.
    await db.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal) VALUES('t5','a','Topup','topup',500000)").run();

    const ta = await token('a');
    const A = (p) => call(p, 'GET', undefined, { Authorization: 'Bearer ' + ta });

    // Periode bulan (default).
    let r = await A('/leaderboard');
    assert.equal(r.status, 200);
    assert.equal(r.json.data.periode, 'bulan');
    const papan = r.json.data.papan;
    assert.equal(papan[0].id, 'a');
    assert.equal(papan[0].poin, 150000); // 120k + 30k, transfer dikecualikan
    assert.equal(papan[0].peringkat, 1);
    assert.equal(papan[1].id, 'b');
    assert.equal(papan[1].poin, 75000);
    assert.equal(papan.find((x) => x.id === 'c'), undefined); // diblokir
    assert.equal(r.json.data.saya.peringkat, 1);
    assert.equal(r.json.data.saya.poin, 150000);

    // Periode total (total_belanja).
    r = await A('/leaderboard?periode=total');
    assert.equal(r.json.data.periode, 'total');
    assert.equal(r.json.data.papan[0].id, 'b'); // 900k > 250k, caca diblokir
    assert.equal(r.json.data.saya.peringkat, 2);
    assert.equal(r.json.data.saya.poin, 250000);

    // Pengguna tanpa aktivitas: poin 0, peringkat null.
    const tb = await token('b');
    r = await call('/leaderboard', 'GET', undefined, { Authorization: 'Bearer ' + tb });
    assert.equal(r.json.data.saya.peringkat, 2); // b punya 75k bulan ini
  } finally {
    await mf.dispose();
  }
});
