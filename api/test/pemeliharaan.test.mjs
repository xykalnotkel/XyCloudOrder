/**
 * Uji pengecualian mode pemeliharaan ("tester internal").
 *
 * Audit 2026-09-13: pemilik meminta supaya saat mode pemeliharaan menyala,
 * akun tertentu (mis. admin) tetap bisa memakai aplikasi untuk uji. Sebelumnya
 * tidak ada mekanisme itu — pemeliharaan menutup semua jalur non-admin,
 * termasuk login, sehingga bahkan penguji tidak bisa masuk.
 *
 * Sekarang: setelan `pemeliharaan_bebas` berisi daftar {id,email,nama};
 * permintaan dengan token milik pengguna di daftar itu lolos dari 503,
 * dan /api/auth/* tetap terbuka supaya penguji bisa login lebih dulu.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

test('Pemeliharaan: 503 untuk semua kecuali config/auth; penguji terpilih lolos', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare(
      "INSERT INTO users(id,nama,email,password,saldo) VALUES('u1','Tester','tester@example.invalid','x',0)",
    ).run();
    await db.prepare(
      "INSERT INTO users(id,nama,email,password,saldo) VALUES('u2','Orang','orang@example.invalid','x',0)",
    ).run();
    await db.prepare("INSERT INTO setelan(kunci,nilai) VALUES('mode_pemeliharaan','1')").run();
    await db.prepare("INSERT INTO setelan(kunci,nilai) VALUES('pemeliharaan_cakupan','semua')").run();

    const t1 = await token('u1', { email: 'tester@example.invalid' });
    const t2 = await token('u2', { email: 'orang@example.invalid' });
    const pakai = (t) => ({ Authorization: 'Bearer ' + t });

    // Sebelum ada pengecualian: data tertutup, config & auth tetap terbuka.
    assert.equal((await call('/me', 'GET', undefined, pakai(t1))).status, 503);
    assert.equal((await call('/config')).status, 200, 'config harus tetap terbaca');
    assert.equal((await call('/auth/login', 'POST', { email: 'a@b.c', password: 'x' })).status !== 503, true,
      'login harus tetap terbuka saat pemeliharaan supaya penguji bisa masuk');

    // Admin memilih u1 sebagai penguji internal.
    await db.prepare("INSERT INTO setelan(kunci,nilai) VALUES('pemeliharaan_bebas',?)")
      .bind(JSON.stringify([{ id: 'u1', email: 'tester@example.invalid', nama: 'Tester' }]))
      .run();

    // Sesudah: u1 lolos (cocok lewat id maupun email), u2 dan anonim tetap 503.
    assert.notEqual((await call('/me', 'GET', undefined, pakai(t1))).status, 503,
      'penguji yang dikecualikan tidak boleh menerima 503');
    assert.equal((await call('/me', 'GET', undefined, pakai(t2))).status, 503,
      'pengguna lain tetap terkena pemeliharaan');
    assert.equal((await call('/me')).status, 503, 'tanpa token tetap terkena');

    // Daftar kosong / rusak tidak boleh membuat semua orang lolos.
    await db.prepare("UPDATE setelan SET nilai='[]' WHERE kunci='pemeliharaan_bebas'").run();
    assert.equal((await call('/me', 'GET', undefined, pakai(t1))).status, 503);
    await db.prepare("UPDATE setelan SET nilai='bukan-json' WHERE kunci='pemeliharaan_bebas'").run();
    assert.equal((await call('/me', 'GET', undefined, pakai(t1))).status, 503);
  } finally {
    await mf.dispose();
  }
});
