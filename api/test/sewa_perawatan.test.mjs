/**
 * Uji pembersih sewa (`rawatSewa`) dan validator host streaming.
 *
 * Menutup regresi yang ditemukan audit 2026-09-13. Di produksi ada satu unit PC
 * yang terkunci selama enam hari karena dua keadaan yang tidak ditangani
 * pembersih:
 *   1. sesi berstatus 'siap' dengan `berakhir` NULL — tidak cocok dengan aturan
 *      mana pun, sehingga `agen.sesi_aktif` tidak pernah dilepas;
 *   2. sesi 'mengakhiri' yang tidak pernah di-ACK agen (agen offline) —
 *      `tutupSewa()` hanya dipanggil dari `konfirmasiAgen()`.
 * Ditambah order 'aktif' yang sudah lewat `berakhir` tidak pernah ditutup, dan
 * `normalisasiHostStream()` menolak `IP:port` padahal lapisan native Android
 * (`NativeStreaming.java#address`) justru mengurai `host:port`.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {harness} from './harness.mjs';
import {normalisasiHostStream} from '../src/sewa.js';

// ---------------------------------------------------------------------------
//  Validator host — fungsi murni
// ---------------------------------------------------------------------------
test('Host streaming: IP publik, FQDN, dan host:port diterima; nama mesin lokal ditolak', () => {
  // IPv4 polos dan dengan port (Sunshine bawaan 47989)
  assert.equal(normalisasiHostStream('203.0.113.7', null), '203.0.113.7');
  assert.equal(normalisasiHostStream('203.0.113.7:47989', null), '203.0.113.7:47989');
  assert.equal(normalisasiHostStream('  203.0.113.7:47989  ', null), '203.0.113.7:47989');
  // FQDN polos dan dengan port
  assert.equal(normalisasiHostStream('pc01.xycloud.my.id', null), 'pc01.xycloud.my.id');
  assert.equal(normalisasiHostStream('pc01.xycloud.my.id:47989', null), 'pc01.xycloud.my.id:47989');
  // IPv6, polos maupun berkurung siku
  assert.equal(normalisasiHostStream('2001:db8::42', null), '2001:db8::42');
  assert.equal(normalisasiHostStream('[2001:db8::42]:47989', null), '[2001:db8::42]:47989');
  // Fallback dipakai kalau isian utama tidak sah
  assert.equal(normalisasiHostStream('runnervmvmocb', '203.0.113.9'), '203.0.113.9');
  assert.equal(normalisasiHostStream('', '203.0.113.9:47989'), '203.0.113.9:47989');

  // Ditolak: COMPUTERNAME Windows / nama mesin tanpa titik (hanya sah di LAN host itu)
  assert.equal(normalisasiHostStream('runnervmvmocb', null), null);
  assert.equal(normalisasiHostStream('DESKTOP-XY123', null), null);
  assert.equal(normalisasiHostStream('PC-XY', null), null);
  // Ditolak: port di luar rentang, spasi, kosong, oktet IPv4 mustahil
  assert.equal(normalisasiHostStream('203.0.113.7:99999', null), null);
  assert.equal(normalisasiHostStream('203.0.113.7:0', null), null);
  assert.equal(normalisasiHostStream('pc 01.xycloud.my.id', null), null);
  assert.equal(normalisasiHostStream('999.1.1.1', null), null);
  assert.equal(normalisasiHostStream('', null), null);
  assert.equal(normalisasiHostStream(null, undefined), null);
});

// ---------------------------------------------------------------------------
//  Pembersih sewa — dijalankan lewat heartbeat agen (jalur produksi)
// ---------------------------------------------------------------------------
test('Pembersih sewa: sesi macet, mengakhiri tanpa ACK, order kedaluwarsa, kunci yatim',
     {timeout: 120000}, async () => {
  const {mf, db, token, call} = await harness();
  try {
    const auth = await token('u');
    const user = (path, method, body) => call(path, method, body, {Authorization: 'Bearer ' + auth});
    /** Heartbeat agen — pemanggil rawatSewa() di jalur produksi. */
    const detak = () => call('/agen/heartbeat', 'POST', {status: 'online', versi: '1.3.3'},
      {'x-agen-kode': 'test-agent'});
    const agen = (path, method, body) => call(path, method, body, {'x-agen-kode': 'test-agent'});
    const ambil = async (sql, kolom, ...bind) => (await db.prepare(sql).bind(...bind).first())[kolom];

    await db.prepare("INSERT INTO users(id,nama,email,password,saldo) VALUES('u','U','u@example.invalid','test',100000)").run();
    await db.prepare("INSERT INTO pc_plans(id,nama,gpu,cpu,ram_gb,storage_gb,harga_per_jam,harga_per_hari,region,total_unit,unit_tersedia) VALUES('p','PC test','G','C',16,100,10000,100000,'test',2,2)").run();
    // Host diisi `IP:port` — persis yang ditolak validator lama.
    await db.prepare("INSERT INTO agen(id,nama,kode,plan_id,host,versi,spec,terakhir) VALUES('a','Unit test','test-agent','p','203.0.113.7:47989','1.3.3',?,datetime('now'))")
      .bind(JSON.stringify({sunshine: {siap: true}})).run();

    // ---- siapkan satu order + sesi nyata sampai status 'siap' ----------------
    const buat = await user('/orders', 'POST', {plan_id: 'p', durasi_jam: 1, metode: 'saldo', request_id: 'req-rawat-001'});
    assert.equal(buat.status, 201, JSON.stringify(buat.json));
    const order = buat.json.data;
    const mulai = await user('/sesi/mulai', 'POST', {order_id: order.id});
    assert.equal(mulai.status, 201, JSON.stringify(mulai.json));
    const sesi = mulai.json.data;
    const cmd = await db.prepare("SELECT * FROM perintah WHERE jenis='mulai_sesi'").first();

    // Agen melapor siap memakai host ber-port; validator lama menolak ini dan
    // membuat host jatuh ke nilai agen yang salah.
    const konfirm = await agen('/agen/perintah/' + cmd.id, 'POST',
      {ok: true, sesi_id: sesi.id, host: '203.0.113.7:47989'});
    assert.equal(konfirm.status, 200, JSON.stringify(konfirm.json));
    assert.equal(await ambil('SELECT host FROM sesi WHERE id=?', 'host', sesi.id), '203.0.113.7:47989',
      'host IP:port harus diterima dan disimpan apa adanya');
    assert.equal(await ambil('SELECT status FROM orders WHERE id=?', 'status', order.id), 'aktif');

    // ---- keadaan (1): sesi 'siap' tanpa `berakhir` ---------------------------
    await db.prepare("UPDATE sesi SET berakhir=NULL, dibuat=datetime('now','-20 minutes') WHERE id=?").bind(sesi.id).run();
    await db.prepare("UPDATE orders SET berakhir=datetime('now','+40 minutes') WHERE id=?").bind(order.id).run();
    assert.equal(await ambil("SELECT sesi_aktif FROM agen WHERE id='a'", 'sesi_aktif'), sesi.id);
    await detak();
    const sesudah = await db.prepare('SELECT status,catatan FROM sesi WHERE id=?').bind(sesi.id).first();
    assert.notEqual(sesudah.status, 'siap',
      'sesi tanpa batas waktu harus ditutup pembersih, bukan dibiarkan siap selamanya');
    assert.match(sesudah.catatan || '', /tanpa batas waktu/i);

    // ---- keadaan (2): 'mengakhiri' tanpa ACK agen ----------------------------
    await db.prepare('DELETE FROM perintah WHERE id=?').bind('end_' + sesi.id).run();
    await db.prepare("UPDATE sesi SET status='mengakhiri' WHERE id=?").bind(sesi.id).run();
    await detak();
    assert.equal(await ambil('SELECT status FROM sesi WHERE id=?', 'status', sesi.id), 'selesai',
      'sesi mengakhiri tanpa ACK harus dipaksa selesai supaya unit tidak terkunci');
    assert.equal(await ambil("SELECT sesi_aktif FROM agen WHERE id='a'", 'sesi_aktif'), null,
      'kunci unit harus dilepas setelah pembersih memaksa sesi selesai');

    // ---- keadaan (3): order 'aktif' yang sudah lewat `berakhir` --------------
    await db.prepare("UPDATE orders SET status='aktif', berakhir=datetime('now','-1 hour') WHERE id=?").bind(order.id).run();
    await detak();
    assert.equal(await ambil('SELECT status FROM orders WHERE id=?', 'status', order.id), 'selesai',
      'order aktif kedaluwarsa harus ditutup, bukan aktif selamanya');

    // ---- keadaan (4): kunci unit yatim --------------------------------------
    await db.prepare("UPDATE agen SET sesi_aktif='s_tidak_ada' WHERE id='a'").run();
    await detak();
    assert.equal(await ambil("SELECT sesi_aktif FROM agen WHERE id='a'", 'sesi_aktif'), null,
      'kunci yang menunjuk sesi/order yang sudah tidak ada harus dilepas');

    // ---- yang TIDAK boleh dilepas: reservasi order yang masih terbuka --------
    const buat2 = await user('/orders', 'POST', {plan_id: 'p', durasi_jam: 1, metode: 'saldo', request_id: 'req-rawat-002'});
    assert.equal(buat2.status, 201, JSON.stringify(buat2.json));
    const order2 = buat2.json.data;
    assert.equal(await ambil("SELECT sesi_aktif FROM agen WHERE id='a'", 'sesi_aktif'), 'order:' + order2.id,
      'trigger harus mereservasi unit begitu order dibuat');
    await detak();
    assert.equal(await ambil("SELECT sesi_aktif FROM agen WHERE id='a'", 'sesi_aktif'), 'order:' + order2.id,
      'reservasi unit untuk order yang masih terbuka tidak boleh dilepas pembersih');
  } finally { await mf.dispose(); }
});
