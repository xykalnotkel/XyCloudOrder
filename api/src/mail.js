/**
 * ============================================================
 *  XyCloudStore - Modul email (Resend)
 *  Semua email memakai identitas ungu XyCloudStore.
 * ============================================================
 */

const UNGU = '#6C2BE2';
const UNGU_PEKAT = '#4A12B8';
const TINTA = '#1A1033';
const MUTED = '#7C7391';

/** Kerangka HTML yang dipakai semua email. */
function rangka({ judul, isi, logoUrl }) {
  return `<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${judul}</title></head>
<body style="margin:0;padding:0;background:#F4F0FD;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F0FD;padding:28px 14px">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
             style="max-width:540px;background:#ffffff;border-radius:20px;overflow:hidden;
                    box-shadow:0 10px 30px rgba(26,16,51,.08)">
        <tr><td style="background:linear-gradient(135deg,${UNGU},${UNGU_PEKAT});padding:26px 30px" align="center">
          <img src="${logoUrl}" alt="XyCloudStore" height="30"
               style="height:30px;display:block;border:0;background:#fff;padding:8px 14px;border-radius:10px">
        </td></tr>
        <tr><td style="padding:32px 30px 34px;color:${TINTA};font-size:15px;line-height:1.65">${isi}</td></tr>
        <tr><td style="background:#FAF8FF;padding:20px 30px;color:${MUTED};font-size:11.5px;line-height:1.6" align="center">
          Email ini dikirim otomatis oleh XyCloudStore. Mohon jangan dibalas.<br>
          Butuh bantuan? Buka menu Customer Service di aplikasi.
        </td></tr>
      </table>
      <div style="color:${MUTED};font-size:11px;margin-top:16px">XyCloudStore &middot; Sewa PC Cloud dan Akun Digital</div>
    </td></tr>
  </table>
</body></html>`;
}

const tombol = (teks, url) =>
  `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px auto"><tr>
     <td style="background:${UNGU};border-radius:12px">
       <a href="${url}" style="display:inline-block;padding:13px 26px;color:#fff;text-decoration:none;
          font-weight:700;font-size:14px">${teks}</a></td></tr></table>`;

const kotakKode = (kode) =>
  `<div style="margin:24px 0;padding:20px;background:#F4F0FD;border:1px dashed ${UNGU}55;border-radius:14px;text-align:center">
     <div style="font-size:11px;font-weight:700;letter-spacing:2px;color:${MUTED}">KODE VERIFIKASI</div>
     <div style="font-size:34px;font-weight:800;letter-spacing:9px;color:${UNGU};margin-top:8px">${kode}</div>
     <div style="font-size:11.5px;color:${MUTED};margin-top:8px">Berlaku 15 menit</div>
   </div>`;

const baris = (k, v) =>
  `<tr><td style="padding:9px 0;color:${MUTED};font-size:13px">${k}</td>
       <td style="padding:9px 0;text-align:right;font-weight:700;font-size:13.5px;color:${TINTA}">${v}</td></tr>`;

const rupiah = (n) => 'Rp' + Number(n || 0).toLocaleString('id-ID');

// ------------------------------------------------------------------
//  Template
// ------------------------------------------------------------------
export const TEMPLATE = {
  verifikasi: ({ nama, kode }) => ({
    subject: `${kode} adalah kode verifikasi XyCloudStore kamu`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Halo ${nama},</div>
      <p style="margin:12px 0 0">Selamat datang di XyCloudStore. Masukkan kode berikut di aplikasi untuk
      mengaktifkan akunmu.</p>
      ${kotakKode(kode)}
      <p style="margin:0;color:${MUTED};font-size:13px">Kalau kamu tidak merasa mendaftar, abaikan saja email ini.</p>`,
  }),

  selamatDatang: ({ nama }) => ({
    subject: 'Akun XyCloudStore kamu sudah aktif',
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Akun aktif, ${nama}</div>
      <p>Sekarang kamu bisa menyewa PC cloud per jam, membeli akun digital bergaransi, dan chat langsung
      dengan customer service kami.</p>
      <ul style="padding-left:18px;color:${TINTA};font-size:14px;line-height:1.9">
        <li>Sewa PC mulai dari Rp5.000 per jam</li>
        <li>Kredensial akun terkirim otomatis setelah pembayaran</li>
        <li>Status order dan chat berjalan realtime</li>
      </ul>
      <p style="margin:0;color:${MUTED};font-size:13px">Selamat menikmati layanannya.</p>`,
  }),

  resetPassword: ({ nama, kode }) => ({
    subject: `${kode} adalah kode reset password XyCloudStore`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Reset password</div>
      <p style="margin:12px 0 0">Halo ${nama}, gunakan kode di bawah ini untuk membuat password baru.</p>
      ${kotakKode(kode)}
      <p style="margin:0;color:${MUTED};font-size:13px">Kalau bukan kamu yang meminta, abaikan email ini.
      Password lama tetap aman.</p>`,
  }),

  kredensialAkun: ({ nama, produk, kode, email, password, catatan }) => ({
    subject: `Kredensial ${produk} - pesanan ${kode}`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Pembelian berhasil</div>
      <p style="margin:12px 0 18px">Terima kasih ${nama}, berikut detail akun yang kamu beli.</p>
      <div style="background:#FAF8FF;border:1px solid #EAE3F7;border-radius:14px;padding:16px 18px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${baris('Produk', produk)}
          ${baris('Kode pesanan', kode)}
          ${baris('Email akun', email)}
          ${baris('Password', password)}
        </table>
      </div>
      <p style="margin:18px 0 0;font-size:13px;color:${MUTED}">${catatan || 'Segera ganti password setelah login pertama.'}</p>`,
  }),

  orderAktif: ({ nama, kode, plan, host, username, password, durasi }) => ({
    subject: `PC ${plan} kamu sudah aktif - ${kode}`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">PC kamu siap dipakai</div>
      <p style="margin:12px 0 18px">Halo ${nama}, unit ${plan} untuk pesanan ${kode} sudah menyala.</p>
      <div style="background:#FAF8FF;border:1px solid #EAE3F7;border-radius:14px;padding:16px 18px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${baris('Alamat (RDP)', host || '-')}
          ${baris('Username', username || '-')}
          ${baris('Password', password || '-')}
          ${baris('Durasi', `${durasi} jam`)}
        </table>
      </div>
      <p style="margin:18px 0 0;font-size:13px;color:${MUTED}">Sesi berhenti otomatis saat durasi habis.
      Perpanjang lewat aplikasi kalau masih butuh.</p>`,
  }),

  laporanHarian: ({ tanggal, ringkas, sorot }) => ({
    subject: `Laporan harian XyCloudStore ${tanggal}`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Laporan ${tanggal}</div>
      <p style="margin:10px 0 18px;color:${MUTED};font-size:13.5px">Ringkasan kegiatan 24 jam terakhir.</p>
      <div style="background:#FAF8FF;border:1px solid #EAE3F7;border-radius:14px;padding:16px 18px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${ringkas.map(([k, v]) => baris(k, v)).join('')}
        </table>
      </div>
      ${sorot ? `<p style="margin:18px 0 0;font-size:13.5px;line-height:1.7">${sorot}</p>` : ''}`,
  }),

  peringatanSistem: ({ judul, rincian }) => ({
    subject: `Peringatan sistem XyCloudStore: ${judul}`,
    isi: `<div style="font-size:21px;font-weight:800;letter-spacing:-.5px;color:#DC2626">${judul}</div>
      <p style="margin:12px 0 0;font-size:14px;line-height:1.7">${rincian}</p>
      <p style="margin:16px 0 0;color:${MUTED};font-size:12.5px">
        Pesan ini dikirim otomatis oleh pemantau kesehatan layanan.</p>`,
  }),

  struk: ({ nama, kode, judul, total, metode }) => ({
    subject: `Struk pembayaran ${kode}`,
    isi: `<div style="font-size:22px;font-weight:800;letter-spacing:-.5px">Pembayaran diterima</div>
      <p style="margin:12px 0 18px">Halo ${nama}, transaksi kamu sudah kami catat.</p>
      <div style="background:#FAF8FF;border:1px solid #EAE3F7;border-radius:14px;padding:16px 18px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          ${baris('Kode', kode)}
          ${baris('Rincian', judul)}
          ${baris('Metode', metode || 'saldo')}
          ${baris('Total', rupiah(total))}
        </table>
      </div>`,
  }),
};

/**
 * Kirim email lewat Resend. Aman dipanggil walau kunci belum diisi
 * (fungsi hanya mencatat lalu keluar, tidak melempar error).
 */
export async function kirimEmail(env, { to, template, data, tombolTeks, tombolUrl }) {
  if (!env.RESEND_API_KEY) return { ok: false, alasan: 'RESEND_API_KEY belum diatur' };

  const t = TEMPLATE[template]?.(data || {});
  if (!t) return { ok: false, alasan: 'template tidak dikenal' };

  const logoUrl = `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/brand/logo.png`;
  const isi = tombolUrl ? t.isi + tombol(tombolTeks || 'Buka Aplikasi', tombolUrl) : t.isi;
  const html = rangka({ judul: t.subject, isi, logoUrl });

  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.MAIL_FROM || 'XyCloudStore <noreply@xyc.my.id>',
        to: [to],
        subject: t.subject,
        html,
      }),
    });
    const j = await r.json().catch(() => ({}));
    return r.ok ? { ok: true, id: j.id } : { ok: false, alasan: j.message || `HTTP ${r.status}` };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}
