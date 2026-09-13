/**
 * Uji blokir sementara, riwayat pelanggaran, dan banding (migrasi 0006).
 *
 * Audit 2026-09-13 meminta layar Akun Dibekukan yang lengkap: beda blokir
 * sementara vs permanen, daftar pelanggaran, dan banding dari dalam aplikasi.
 * Uji ini menutup perilaku kontraknya:
 *   - blokir sementara pulih otomatis setelah lewat batas;
 *   - setiap pembekuan baru tercatat di tabel pelanggaran;
 *   - pengguna terblokir tetap bisa membaca statusnya dan mengajukan banding;
 *   - banding diterima => akun aktif kembali; ditolak => tetap terblokir.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

const ADMIN = { 'x-admin-key': 'test-admin' };

test('Blokir sementara pulih otomatis; banding diterima mengaktifkan akun', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare(
      "INSERT INTO users(id,nama,email,password,saldo) VALUES('u1','Terblokir','u1@example.invalid','x',0)",
    ).run();
    // Setiap pembekuan/pemulihan menaikkan session_version, jadi token uji
    // harus diterbitkan ulang dengan sv yang sesuai.
    let sv = 0;
    const user = async (path, method, body) => {
      const t = await token('u1', { email: 'u1@example.invalid', sv });
      return call(path, method, body, { Authorization: 'Bearer ' + t });
    };
    const kelola = (body) => call('/admin/users/u1/kelola', 'PATCH', body, ADMIN);

    // 1) Blokir SEMENTARA yang sudah lewat waktu => pulih otomatis saat dibaca.
    await db.prepare("UPDATE users SET diblokir=1, alasan_blokir='Uji sementara', blokir_sampai=? WHERE id='u1'")
      .bind(new Date(Date.now() - 60_000).toISOString()).run();
    let r = await user('/me/blokir');
    assert.equal(r.status, 200);
    assert.equal(r.json.data.diblokir, false, 'blokir yang sudah lewat batas harus pulih otomatis');
    sv = 1; // pemulihan menaikkan session_version

    // 2) Blokir permanen => tercatat sebagai pelanggaran & status terbaca.
    r = await kelola({ diblokir: true, alasan: 'Uji permanen' });
    assert.equal(r.status, 200);
    sv = 2;
    r = await user('/me/blokir');
    assert.equal(r.json.data.diblokir, true);
    assert.equal(r.json.data.sampai, null, 'permanen tidak punya batas waktu');
    assert.equal(r.json.data.pelanggaran.length, 1, 'pembekuan baru harus tercatat di riwayat');
    assert.equal(r.json.data.pelanggaran[0].alasan, 'Uji permanen');

    // 3) Pengguna terblokir tetap boleh membaca status & mengajukan banding.
    assert.equal((await user('/wallet/transaksi')).status, 403, 'rute lain tetap tertutup');
    r = await user('/me/banding', 'POST', { pesan: 'Saya tidak merasa melanggar, mohon ditinjau ulang.' });
    assert.equal(r.status, 201, 'banding harus bisa diajukan dari aplikasi');
    const idBanding = r.json.data.id;
    // Banding ganda ditolak selama masih baru.
    r = await user('/me/banding', 'POST', { pesan: 'Banding kedua yang seharusnya ditolak sistem.' });
    assert.equal(r.status, 409);
    // Pesan terlalu pendek ditolak.
    await db.prepare("UPDATE banding SET status='ditolak' WHERE id=?").bind(idBanding).run();
    r = await user('/me/banding', 'POST', { pesan: 'pendek' });
    assert.equal(r.status, 422);

    // 4) Admin menolak => akun tetap terblokir; menerima => aktif kembali.
    r = await user('/me/banding', 'POST', { pesan: 'Banding ketiga setelah yang pertama ditolak admin.' });
    assert.equal(r.status, 201);
    const id2 = r.json.data.id;
    r = await call(`/admin/moderasi/banding/${id2}`, 'POST', { status: 'ditolak', tanggapan: 'Bukti cukup.' }, ADMIN);
    assert.equal(r.status, 200);
    assert.equal((await user('/me/blokir')).json.data.diblokir, true);
    r = await call(`/admin/moderasi/banding/${id2}`, 'POST', { status: 'diterima', tanggapan: 'Keliru blokir.' }, ADMIN);
    assert.equal(r.status, 200);
    sv = 3;
    r = await user('/me/blokir');
    assert.equal(r.json.data.diblokir, false, 'banding diterima harus mengaktifkan akun');

    // 5) Daftar banding untuk admin memuat identitas pengaju.
    r = await call('/admin/moderasi/banding', 'GET', undefined, ADMIN);
    assert.equal(r.status, 200);
    assert.ok(r.json.data.length >= 2);
    assert.equal(r.json.data[0].nama, 'Terblokir');
  } finally {
    await mf.dispose();
  }
});
