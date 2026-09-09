import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

test('Push admin: wajib admin, validasi, dan gate provider tanpa kredensial', async () => {
  const h = await harness();
  try {
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified) VALUES ('u_push','User','push@example.invalid','test',1)"
    ).run();

    // tanpa kunci admin -> 403
    const tanpa = await h.call('/admin/push', 'POST', { judul: 'Halo', pesan: 'Tes' });
    assert.equal(tanpa.status, 403);

    const adminH = { 'x-admin-key': 'test-admin' };

    // judul/pesan wajib
    const kosong = await h.call('/admin/push', 'POST', { judul: '', pesan: '' }, adminH);
    assert.equal(kosong.status, 400);

    // user id tak dikenal -> 404
    const takAda = await h.call('/admin/push', 'POST',
      { judul: 'Halo', pesan: 'Tes', mode: 'user', user_id: 'nope' }, adminH);
    assert.equal(takAda.status, 404);

    // tanpa kredensial OneSignal -> 502 dengan alasan jelas (bukan 500)
    const perUser = await h.call('/admin/push', 'POST',
      { judul: 'Halo', pesan: 'Tes', mode: 'user', user_id: 'u_push' }, adminH);
    assert.equal(perUser.status, 502);
    assert.ok(JSON.stringify(perUser.json).includes('kredensial'), JSON.stringify(perUser.json));

    const semua = await h.call('/admin/push', 'POST',
      { judul: 'Halo', pesan: 'Tes', tipe: 'promo' }, adminH);
    assert.equal(semua.status, 502);
    assert.ok(JSON.stringify(semua.json).includes('kredensial'));

    // endpoint memang eksis: dengan kredensial OneSignal tiruan tidak boleh "Endpoint tidak dikenal"
    const h2 = await harness({ ONESIGNAL_APP_ID: 'test', ONESIGNAL_API_KEY: 'test' });
    try {
      const r2 = await h2.call('/admin/push', 'POST', { judul: 'Halo', pesan: 'Tes' }, adminH);
      assert.ok(r2.status === 400 || r2.status === 502 || r2.status === 200,
        `status tak terduga: ${r2.status}`);
      const ra = await h2.call('/admin/push', 'GET');
      assert.equal(ra.status, 403);
    } finally {
      await h2.mf.dispose();
    }
  } finally {
    await h.mf.dispose();
  }
});
