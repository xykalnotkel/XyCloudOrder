/**
 * ============================================================
 *  XyCloudStore - Pembayaran otomatis
 * ============================================================
 *  Mendukung dua penyedia yang lazim dipakai di Indonesia:
 *
 *    - Tripay   : QRIS, DANA, OVO, ShopeePay, virtual account bank
 *    - Midtrans : Snap (QRIS, e-wallet, VA, kartu)
 *
 *  Kalau tidak ada satu pun yang dikonfigurasi, sistem otomatis
 *  kembali ke cara manual: transfer + unggah bukti + konfirmasi admin.
 *
 *  Semua kunci disimpan sebagai secret Worker, tidak pernah dikirim
 *  ke aplikasi.
 */

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function hmac(algo, kunci, pesan) {
  const k = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(kunci),
    { name: 'HMAC', hash: algo },
    false,
    ['sign'],
  );
  return hex(await crypto.subtle.sign('HMAC', k, new TextEncoder().encode(pesan)));
}

async function sha512(teks) {
  return hex(await crypto.subtle.digest('SHA-512', new TextEncoder().encode(teks)));
}

/** Penyedia yang sedang aktif: 'tripay' | 'midtrans' | 'manual'. */
export function penyediaBayar(env) {
  if (env.TRIPAY_API_KEY && env.TRIPAY_PRIVATE_KEY && env.TRIPAY_MERCHANT_CODE) return 'tripay';
  if (env.MIDTRANS_SERVER_KEY) return 'midtrans';
  return 'manual';
}

/** Daftar metode yang bisa dipilih pengguna di aplikasi. */
export function metodeTersedia(env) {
  const p = penyediaBayar(env);
  if (p === 'tripay') {
    return [
      { kode: 'QRIS', nama: 'QRIS', jenis: 'otomatis' },
      { kode: 'DANA', nama: 'DANA', jenis: 'otomatis' },
      { kode: 'SHOPEEPAY', nama: 'ShopeePay', jenis: 'otomatis' },
      { kode: 'BRIVA', nama: 'Virtual Account BRI', jenis: 'otomatis' },
      { kode: 'BCAVA', nama: 'Virtual Account BCA', jenis: 'otomatis' },
    ];
  }
  if (p === 'midtrans') {
    return [{ kode: 'SNAP', nama: 'Semua metode (QRIS, e-wallet, VA)', jenis: 'otomatis' }];
  }
  return [
    { kode: 'transfer', nama: 'Transfer manual', jenis: 'manual' },
    { kode: 'qris', nama: 'QRIS manual', jenis: 'manual' },
  ];
}

/**
 * Buat tagihan di penyedia. Mengembalikan
 * { ok, url, qr, kode_bayar, kedaluwarsa, referensi }
 */
export async function buatTagihan(env, { id, nominal, metode, nama, email, phone, keterangan }) {
  const p = penyediaBayar(env);

  if (p === 'tripay') {
    const merchantRef = id;
    const tanda = await hmac(
      'SHA-256',
      env.TRIPAY_PRIVATE_KEY,
      `${env.TRIPAY_MERCHANT_CODE}${merchantRef}${nominal}`,
    );

    const badan = {
      method: metode || 'QRIS',
      merchant_ref: merchantRef,
      amount: nominal,
      customer_name: nama || 'Pengguna XyCloudStore',
      customer_email: email || 'noreply@xyc.my.id',
      customer_phone: phone || '',
      order_items: [
        { sku: 'TOPUP', name: keterangan || 'Isi saldo XyCloudStore', price: nominal, quantity: 1 },
      ],
      expired_time: Math.floor(Date.now() / 1000) + 6 * 3600,
      signature: tanda,
    };

    try {
      const r = await fetch(`${env.TRIPAY_BASE || 'https://tripay.co.id/api'}/transaction/create`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.TRIPAY_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(badan),
      });
      const j = await r.json();
      if (!j.success) return { ok: false, alasan: j.message || 'Tripay menolak permintaan' };
      const d = j.data;
      return {
        ok: true,
        penyedia: 'tripay',
        referensi: d.reference,
        url: d.checkout_url,
        qr: d.qr_url || null,
        kode_bayar: d.pay_code || null,
        nominal: d.amount,
        kedaluwarsa: d.expired_time,
      };
    } catch (e) {
      return { ok: false, alasan: String(e) };
    }
  }

  if (p === 'midtrans') {
    const dasar = env.MIDTRANS_PRODUKSI === 'true'
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

    try {
      const r = await fetch(dasar, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${btoa(`${env.MIDTRANS_SERVER_KEY}:`)}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          transaction_details: { order_id: id, gross_amount: nominal },
          customer_details: { first_name: nama || 'Pengguna', email: email || 'noreply@xyc.my.id', phone: phone || '' },
          item_details: [{ id: 'TOPUP', price: nominal, quantity: 1, name: keterangan || 'Isi saldo' }],
        }),
      });
      const j = await r.json();
      if (!j.token) return { ok: false, alasan: j.error_messages?.join(', ') || 'Midtrans menolak permintaan' };
      return {
        ok: true,
        penyedia: 'midtrans',
        referensi: j.token,
        url: j.redirect_url,
        qr: null,
        kode_bayar: null,
        nominal,
      };
    } catch (e) {
      return { ok: false, alasan: String(e) };
    }
  }

  return { ok: false, alasan: 'manual', penyedia: 'manual' };
}

/**
 * Periksa keaslian pemberitahuan dari penyedia lalu simpulkan hasilnya.
 * Mengembalikan { sah, id, status } dengan status: 'lunas' | 'gagal' | 'menunggu'.
 */
export async function bacaPemberitahuan(env, provider, req, teksBadan) {
  if (provider === 'tripay') {
    const tanda = req.headers.get('x-callback-signature') || '';
    const harus = await hmac('SHA-256', env.TRIPAY_PRIVATE_KEY, teksBadan);
    if (tanda !== harus) return { sah: false };

    const b = JSON.parse(teksBadan);
    const status = b.status === 'PAID' ? 'lunas' : b.status === 'EXPIRED' || b.status === 'FAILED' ? 'gagal' : 'menunggu';
    return { sah: true, id: b.merchant_ref, status, nominal: b.total_amount, referensi: b.reference };
  }

  if (provider === 'midtrans') {
    const b = JSON.parse(teksBadan);
    const harus = await sha512(`${b.order_id}${b.status_code}${b.gross_amount}${env.MIDTRANS_SERVER_KEY}`);
    if ((b.signature_key || '') !== harus) return { sah: false };

    const lunas = ['capture', 'settlement'].includes(b.transaction_status);
    const gagal = ['deny', 'cancel', 'expire', 'failure'].includes(b.transaction_status);
    return {
      sah: true,
      id: b.order_id,
      status: lunas ? 'lunas' : gagal ? 'gagal' : 'menunggu',
      nominal: Number(b.gross_amount),
      referensi: b.transaction_id,
    };
  }

  return { sah: false };
}
