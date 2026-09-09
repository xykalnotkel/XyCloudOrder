import { adminSecurity, ownerProtected } from './admin_security.js';
import { SecurityError, securityConfig, securityHash, securitySlot, auditSecurity, requireRate, deviceFromRequest, linkDevice, beforeRegistration, translateRegistrationError, assertAccountEnabled, otpAllowed, otpDigest, newOAuthState, consumeOAuthState, saveSecurityConfig } from './security.js';
import { estimasiSewa, buatSewa, mulaiSewa, bacaSewa, antreAkhir, konfirmasiAgen, tutupSewa, rawatSewa } from './sewa.js';
import { infoHapusAkun, bersihkanAkun } from './akun.js';
import { KontenError, daftarPromosi, simpanPromosi, ambilKunciGiphy, simpanKunciGiphy, cariGiphy, terimaStiker, bacaStiker } from './engagement.js';
/**
 * ============================================================
 *  XyCloud API — Cloudflare Worker
 *  - REST  : /api/*        (D1)
 *  - Realtime : /ws/:room  (Durable Object "RealtimeHub", WebSocket)
 * ============================================================
 *  Deploy:
 *    npm i -g wrangler
 *    wrangler d1 create xycloud            -> salin id ke wrangler.toml
 *    wrangler d1 execute xycloud --remote --file=./schema.sql
 *    wrangler deploy
 */

import ADMIN_HTML from './admin.html';
import WEB_HTML from './web.html';
import { infoRilis, unduhApk, tebakAbi, simpanRilis } from './rilis.js';
import LOGO_PNG from './brand-logo.png';
import OG_PNG from './brand-og.png';
import MAINT_WEB_PNG from './assets/maintenance-web.png';
import MAINT_APP_PNG from './assets/maintenance-app.png';
import { kirimEmail } from './mail.js';
import { kirimPush, siarkanPush } from './push.js';
import { unggahGambar, samarkanGambar, layaniGambar } from './upload.js';
import { penyediaBayar, metodeTersedia, buatTagihan, bacaPemberitahuan } from './bayar.js';
import { setelan, simpanSetelan, jalankanPemeliharaan, statistikLengkap, catatLog, pantauKesehatan } from './sistem.js';
import { TIER, diskonTier, segarkanTier, cekVoucher, pakaiVoucher, pakaiVoucherStrict, buatCadangan } from './loyal.js';
import { halamanLegal, isiLegal } from './legal.js';
import { SKEMA_APLIKASI, providerSiap, urlMulai, ambilProfil, halamanKembali, verifikasiIdTokenGoogle } from './oauth.js';

const _rateMem = new Map();
function rateMem(key, max, windowSec) {
  const now = Date.now() / 1000;
  let arr = _rateMem.get(key) || [];
  arr = arr.filter((t) => t > now - windowSec);
  if (arr.length >= max) return false;
  arr.push(now);
  _rateMem.set(key, arr);
  return true;
}
// bersihkan map tiap 10 menit biar tidak bocor memori
setInterval?.(() => {
  const now = Date.now() / 1000;
  for (const [k, v] of _rateMem) {
    const fresh = v.filter((t) => t > now - 3600);
    if (fresh.length === 0) _rateMem.delete(k);
    else _rateMem.set(k, fresh);
  }
}, 600000);

const securityHeaders = (env) => ({
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': env?.ALLOW_ORIGIN || '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-admin-key, x-xy-device',
  'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'SAMEORIGIN',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  'Content-Security-Policy': "default-src 'self'; img-src 'self' https://res.cloudinary.com https://*.giphy.com https://media.giphy.com data:; script-src 'self' 'unsafe-inline' https://*.onesignal.com; connect-src 'self' https://api.xycloud.my.id wss://*.xycloud.my.id https://*.onesignal.com; frame-ancestors 'self'",
  'Cache-Control': 'no-store',
});

const json = (data, status = 200, env) =>
  new Response(JSON.stringify({ data }), {
    status,
    headers: securityHeaders(env),
  });

const err = (message, status = 400, env) =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      ...securityHeaders(env),
      'Content-Type': 'application/json',
    },
  });

// ---------- mode pemeliharaan bertingkat ----------
// Cakupan pemeliharaan (`pemeliharaan_cakupan`):
//   'semua'      -> blokir web + aplikasi Android (bawaan, perilaku lama)
//   'web'        -> blokir situs publik saja, aplikasi tetap jalan
//   'aplikasi'   -> blokir aplikasi Android saja, situs tetap jalan
//   'admin'      -> blokir console admin (dan web/app), hanya kunci pemilik tersembunyi
//                   (opsional; berbahaya). Kami batasi ke yang aman di bawah.
const CAKUPAN_PEMELIHARAAN = ['semua', 'web', 'aplikasi'];

/** Deteksi asal permintaan: 'web' (SPA publik) vs 'aplikasi' (Android/native).
 *  Permintaan dari browser ke host API lintas-asal membawa header Origin,
 *  sedangkan aplikasi Android / klien non-peramban tidak mengirimnya. */
function deteksiPlatform(req) {
  const origin = (req.headers.get('origin') || '').trim().toLowerCase();
  return origin ? 'web' : 'aplikasi';
}

/** Baca apakah permintaan dengan platform tertentu sedang diblokir mode pemeliharaan. */
async function tertutupPemeliharaan(env, req) {
  const mode = await setelan(env, 'mode_pemeliharaan', '0');
  if (mode !== '1') return false;
  const cakupan = (await setelan(env, 'pemeliharaan_cakupan', 'semua')) || 'semua';
  if (cakupan === 'semua') return true;
  const plat = deteksiPlatform(req);
  if (cakupan === 'web' && plat === 'web') return true;
  if (cakupan === 'aplikasi' && plat === 'aplikasi') return true;
  return false;
}

// ---------- password ----------
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function hashPw(password, salt) {
  const data = new TextEncoder().encode(`${salt}:${password}`);
  return hex(await crypto.subtle.digest('SHA-256', data));
}

/** Format tersimpan: `salt$hash`. Password lama (plaintext seed) tetap diterima. */
async function buatPw(password) {
  const salt = hex(crypto.getRandomValues(new Uint8Array(8)));
  return `${salt}$${await hashPw(password, salt)}`;
}

async function cocokPw(password, tersimpan) {
  if (!tersimpan || String(tersimpan).startsWith('sosial:')) return false;
  if (!tersimpan.includes('$')) return tersimpan === password; // data lama
  const [salt, h] = tersimpan.split('$');
  return (await hashPw(password, salt)) === h;
}

/** Kode OTP 6 digit. */
function buatKode() {
  return String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000).padStart(6, '0');
}

/** Simpan OTP (berlaku 15 menit) lalu kirim emailnya. */
async function kirimOtp(env, { email, nama, tipe }) {
  if(!await otpAllowed(env,email))return {ok:false,rateLimited:true,alasan:'Batas kode untuk email ini tercapai. Tunggu sebelum meminta lagi.'};
  const kode = buatKode();
  const digest = await otpDigest(env,email,tipe,kode);
  const kadaluarsa = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  await env.DB.prepare('DELETE FROM otp WHERE email = ? AND tipe = ?').bind(email, tipe).run();
  await env.DB.prepare('INSERT INTO otp (id,email,kode,tipe,kadaluarsa) VALUES (?,?,?,?,?)')
    .bind(uid('otp_'), email, digest, tipe, kadaluarsa).run();
  return kirimEmail(env, {
    to: email,
    template: tipe === 'reset' ? 'resetPassword' : tipe === 'hapus_akun' ? 'hapusAkun' : 'verifikasi',
    data: { nama: nama || 'Sobat Xy', kode },
  });
}

/** Periksa OTP; kalau cocok, tandai terpakai. */
async function cekOtp(env, { email, kode, tipe }) {
  await requireRate(env,'otp-verify-email',email,5,900);
  const hash=await otpDigest(env,email,tipe,kode);
  const row=await env.DB.prepare(`UPDATE otp SET dipakai=1 WHERE email=? AND tipe=? AND (kode=? OR kode=?)
    AND dipakai=0 AND kadaluarsa>? RETURNING id`).bind(email,tipe,hash,String(kode).trim(),new Date().toISOString()).first();
  return row?{ok:true}:{ok:false,pesan:'Kode salah, kedaluwarsa, atau sudah dipakai.'};
}

/**
 * Pembatas laju sederhana berbasis D1.
 * Mengembalikan true kalau permintaan masih boleh diproses.
 */
async function bolehLanjut(env,kunci,maks,detik) {
  try{return await securitySlot(env,'request',kunci,maks,detik);}catch{return false;}
}

/**
 * Kirim pemberitahuan forum ke beberapa pengguna sekaligus.
 * Pengguna yang mematikan notifikasi komunitas otomatis dilewati.
 */
async function pushForum(env, idPengguna, { judul, pesan, data }) {
  const daftar = [...new Set(idPengguna.filter(Boolean))].slice(0, 60);
  if (!daftar.length) return;

  const tanda = daftar.map(() => '?').join(',');
  const { results } = await env.DB
    .prepare(`SELECT id FROM users WHERE id IN (${tanda}) AND notif_forum = 1`)
    .bind(...daftar).all();

  await Promise.all(
    results.map((u) => kirimPush(env, { userId: u.id, judul, pesan, data }))
  );
}

/**
 * Simpan pemberitahuan untuk pengguna lalu dorong lewat WebSocket dan push.
 * Dipakai untuk suka, balasan, peringatan admin, dan kabar pesanan.
 */
async function buatNotif(env, ctx, { userId, jenis, judul, pesan, aktor, refJenis, refId, kirimPushJuga = true }) {
  if (!userId) return;
  try {
    const id = uid('n_');
    const waktu = new Date().toISOString();
    await env.DB.prepare(
      'INSERT INTO notifikasi (id,user_id,jenis,judul,pesan,aktor,ref_jenis,ref_id,dibuat) VALUES (?,?,?,?,?,?,?,?,?)'
    ).bind(id, userId, jenis, judul, pesan || '', aktor || null, refJenis || null, refId || null, waktu).run();

    const isi = { id, jenis, judul, pesan, aktor, ref_jenis: refJenis, ref_id: refId, dibaca: 0, dibuat: waktu };
    ctx.waitUntil(push(env, `user:${userId}`, 'notif.baru', isi));

    if (kirimPushJuga) {
      const u = await env.DB.prepare('SELECT notif_forum FROM users WHERE id = ?').bind(userId).first();
      const forumJenis = ['suka', 'balasan', 'sebut', 'komunitas'];
      if (!forumJenis.includes(jenis) || (u?.notif_forum ?? 1) === 1) {
        ctx.waitUntil(kirimPush(env, { userId, judul, pesan: pesan || '', data: { tipe: jenis, id: refId } }));
      }
    }
  } catch (_) { /* jangan sampai menggagalkan permintaan utama */ }
}

/// Masa berlaku token: 30 hari.
const MASA_TOKEN = 30 * 24 * 60 * 60 * 1000;

/**
 * Ambil akun berdasarkan email dari penyedia sosial, atau buat baru.
 * Akun sosial otomatis dianggap terverifikasi.
 */
async function akunSosial(env, ctx, prof, provider, deviceId, req) {
  let u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(prof.email).first();

  if(u)assertAccountEnabled(u);
  if (!u) {
    await beforeRegistration(env,req,deviceId);
    const idBaru = uid('u_');
    await env.DB.prepare(
      "INSERT INTO users (id,nama,email,password,phone,saldo,tier,email_verified,foto,registration_device) VALUES (?,?,?,?,?,0,'basic',1,?,?)"
    ).bind(idBaru, prof.nama, prof.email, `sosial:${provider}`, null, prof.foto || null,deviceId).run().catch(translateRegistrationError);

    const sapa = {
      id: uid('m_'),
      room: `user:${idBaru}`,
      teks: `Selamat datang, ${prof.nama.split(' ')[0]}. Kirim pesan untuk menghubungi tim CS. Percakapan disimpan selama 7 hari.`,
      waktu: new Date().toISOString(),
    };
    ctx.waitUntil(env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
      .bind(sapa.id, sapa.room, idBaru, 'system', sapa.teks, sapa.waktu).run());
    ctx.waitUntil(kirimEmail(env, { to: prof.email, template: 'selamatDatang', data: { nama: prof.nama } }));

    u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(idBaru).first();
  } else if (!u.email_verified || (prof.foto && !u.foto)) {
    await env.DB.prepare('UPDATE users SET email_verified = 1, foto = COALESCE(foto, ?) WHERE id = ?')
      .bind(prof.foto || null, u.id).run();
    u.email_verified = 1;
    u.foto = u.foto || prof.foto;
  }

  return u;
}

const emailValid = (v) => /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(String(v || '').trim());

// ---------- token sederhana (HMAC-SHA256) ----------
const b64u = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function sign(payload, secret) {
  const body = b64u(new TextEncoder().encode(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return `${body}.${b64u(sig)}`;
}

async function verify(token, secret) {
  if (!token) return null;
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;

  let isi;
  try {
    isi = JSON.parse(atob(body.replace(/-/g, '+').replace(/_/g, '/')));
  } catch (_) {
    return null;
  }

  const expected = await sign(isi, secret);
  if (expected !== token) return null;

  // token lama tanpa exp tetap diterima, yang baru wajib belum kedaluwarsa
  if (isi.v!==2 || !isi.sub || !Number.isFinite(Number(isi.exp)) || Number(isi.exp)<=Date.now()) return null;
  return isi;
}

async function auth(req, env) {
  const h=req.headers.get('Authorization')||'';
  const session=await verify(h.replace('Bearer ',''),env.JWT_SECRET);
  if(!session)return null;
  const u=await env.DB.prepare('SELECT session_version,deleted_at FROM users WHERE id=?').bind(session.sub).first();
  if(!u||u.deleted_at||Number(u.session_version)!==Number(session.sv||0))return null;
  if(session.dv){const d=await env.DB.prepare('SELECT blocked FROM security_devices WHERE id=?').bind(session.dv).first();if(d?.blocked)return null;}
  return session;
}
async function issueUserToken(env,u,deviceId=null){
  assertAccountEnabled(u);
  await linkDevice(env,deviceId,u.id);
  return sign({sub:u.id,email:u.email,v:2,sv:u.session_version||0,dv:deviceId,iat:Date.now(),exp:Date.now()+MASA_TOKEN},env.JWT_SECRET);
}

const uid = (p = '') => p + crypto.randomUUID().replace(/-/g, '').slice(0, 12);

/** Cek admin key dari header x-admin-key atau query ?key= */
function isAdmin(req, env) {
  const url = new URL(req.url);
  const k = req.headers.get('x-admin-key') || url.searchParams.get('key');
  return !!env.ADMIN_KEY && k === env.ADMIN_KEY;
}

/**
 * Kenali admin beserta perannya.
 * Kunci utama pada secret berperan sebagai pemilik, kunci tambahan
 * disimpan di tabel admin_kunci dengan peran cs atau moderator.
 */
async function kenaliAdmin(req, env) {
  const url = new URL(req.url);
  const k = req.headers.get('x-admin-key') || url.searchParams.get('key');
  if (!k) return null;

  if (env.ADMIN_KEY && k === env.ADMIN_KEY) {
    return { nama: 'Pemilik', peran: 'pemilik' };
  }

  try {
    const baris = await env.DB.prepare('SELECT * FROM admin_kunci WHERE kunci = ? AND aktif = 1').bind(k).first();
    if (!baris) return null;
    await env.DB.prepare('UPDATE admin_kunci SET terakhir = ? WHERE id = ?')
      .bind(new Date().toISOString(), baris.id).run();
    return { id: baris.id, nama: baris.nama, peran: baris.peran };
  } catch (_) {
    return null;
  }
}

/** Hak akses tiap peran. Pemilik boleh semua. */
const HAK_PERAN = {
  cs: ['cs/', 'users', 'orders', 'topup', 'sesi', 'statistik', 'laporan', 'forum'],
  moderator: ['forum', 'ulasan', 'laporan', 'konten/', 'users', 'statistik'],
};

function bolehAkses(peran, jalur) {
  if (peran === 'pemilik') return true;
  const izin = HAK_PERAN[peran] || [];
  return izin.some((i) => jalur === i || jalur.startsWith(i));
}

/** Catat tindakan admin supaya bisa ditelusuri. */
async function catatAdmin(env, admin, aksi, target) {
  try {
    await env.DB.prepare('INSERT INTO log_admin (id,admin,peran,aksi,target,waktu) VALUES (?,?,?,?,?,?)')
      .bind('la_' + crypto.randomUUID().replace(/-/g, '').slice(0, 12),
            admin?.nama || 'tidak dikenal', admin?.peran || '-', aksi, target || null,
            new Date().toISOString()).run();
  } catch (_) { /* diabaikan */ }
}

/** Kirim event realtime ke room user lewat Durable Object. */
async function push(env, room, type, payload) {
  const id = env.HUB.idFromName(room);
  await env.HUB.get(id).fetch('https://hub/broadcast', {
    method: 'POST',
    body: JSON.stringify({ type, payload }),
  });
}

/** Siarkan daftar banner aktif ke seluruh aplikasi (room `katalog`). */
async function kirimBanner(env) {
  const { results } = await env.DB
    .prepare('SELECT * FROM banners WHERE aktif = 1 ORDER BY urutan ASC').all();
  return push(env, 'katalog', 'banner.update', { banners: results.map(r=>({...r,gambar:samarkanGambar(env,r.gambar,'m')})) });
}

// ============================================================
//  ROUTER
// ============================================================
export default {
  /** Penjadwal Cloudflare: pemeliharaan otomatis berjalan sendiri. */
  async scheduled(event, env, ctx) {
    ctx.waitUntil(jalankanPemeliharaan(env));
    ctx.waitUntil(rawatSewa(env));
    // pantau kesehatan tiap jam
    ctx.waitUntil(pantauKesehatan(env, kirimEmail));
    // cadangan otomatis sekali sehari pada jam 19 UTC (dini hari WIB)
    if (new Date().getUTCHours() === 19) {
      ctx.waitUntil((async () => {
        const hasil = await buatCadangan(env);
        await catatLog(env, 'cadangan', `Cadangan otomatis ${hasil.id}, ${hasil.baris} baris`);
      })());
    }
  },

  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    const path = url.pathname;

    if (req.method === 'OPTIONS') return json({}, 204, env);

    // Private rooms require a valid user token or an authorized admin key.
    if (path.startsWith('/ws/')) {
      const room = decodeURIComponent(path.slice(4));
      if (!['forum','katalog'].includes(room)) {
        const admin = await kenaliAdmin(req, env);
        const wsHeaders=new Headers(req.headers);wsHeaders.set('Authorization','Bearer '+(url.searchParams.get('token')||''));
        const user = await auth(new Request(req.url,{headers:wsHeaders}),env);
        const exists = user && await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(user.sub).first();
        if (!admin && (!exists || room !== `user:${user.sub}`)) return err('Unauthorized room',401,env);
        if (admin && !['pemilik','cs'].includes(admin.peran)) return err('Akses chat ditolak',403,env);
      }
      const id = env.HUB.idFromName(room);
      return env.HUB.get(id).fetch(req);
    }

    // ---------- dashboard admin ----------
    const host = (req.headers.get('host') || '').toLowerCase();
    const domainWeb = !host.startsWith('api.') && !host.startsWith('admin.');

    // ---------- situs publik ----------
    if (domainWeb && (path === '/' || !path.includes('.')) && !path.startsWith('/api/')
        && !path.startsWith('/img/') && !path.startsWith('/unduh/') && !path.startsWith('/legal/')
        && !path.startsWith('/brand/') && !path.startsWith('/bayar/')) {
      // Mode pemeliharaan khusus situs: tampilkan halaman perawatan berilustrasi,
      // bukan web.html yang gagal memuat data. Berkas /brand/ masih boleh dimuat
      // sehingga ilustrasi tampil.
      const maintWeb = (await setelan(env, 'mode_pemeliharaan', '0')) === '1';
      const cakupan = maintWeb ? (await setelan(env, 'pemeliharaan_cakupan', 'semua')) || 'semua' : 'semua';
      if (maintWeb && (cakupan === 'semua' || cakupan === 'web')) {
        const pesan = await setelan(env, 'pesan_pemeliharaan',
          'Kami sedang melakukan perawatan singkat. Silakan coba lagi beberapa menit lagi.');
        const aman = String(pesan).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
        return new Response(`<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>XyCloudStore — Perawatan</title>
<style>
:root{--bg:#140E29;--panel:rgba(255,255,255,.04);--line:rgba(124,58,237,.25);--pur:#A78BFA;--pur2:#7C3AED;--ink:#EDE9F8}
*{box-sizing:border-box;margin:0;padding:0}body{min-height:100dvh;background:radial-gradient(1200px 800px at 50% -10%,#2B1660 0%,var(--bg) 55%);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:grid;place-items:center;padding:28px;overflow-x:hidden}
.wrap{max-width:520px;text-align:center;animation:masuk .7s ease both}
@keyframes masuk{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
.img{width:min(78vw,380px);margin:0 auto 8px;filter:drop-shadow(0 22px 44px rgba(124,58,237,.45))}
h1{font-size:clamp(24px,6vw,34px);letter-spacing:-.5px;margin:6px 0 12px;background:linear-gradient(90deg,#C4B5FD,#8B5CF6,#C4B5FD);-webkit-background-clip:text;background-clip:text;color:transparent;font-weight:800}
p{color:#B6A9DF;font-size:15px;line-height:1.7;max-width:430px;margin:0 auto 22px}
.meter{height:5px;border-radius:99px;background:rgba(124,58,237,.2);overflow:hidden;max-width:300px;margin:0 auto 18px}
.meter i{display:block;height:100%;width:40%;border-radius:99px;background:linear-gradient(90deg,#7C3AED,#C084FC);animation:geser 1.6s ease-in-out infinite}
@keyframes geser{0%{margin-left:-40%}100%{margin-left:100%}}
.tombol{display:inline-flex;align-items:center;gap:8px;border:1px solid rgba(167,139,250,.4);background:rgba(124,58,237,.14);color:#D6CBF5;padding:11px 22px;border-radius:99px;font-size:14px;font-weight:600;cursor:pointer;transition:.2s;font-family:inherit}
.tombol:hover{background:rgba(124,58,237,.3);transform:translateY(-1px)}
.small{display:block;margin-top:14px;color:#8E82B4;font-size:12px}
</style></head><body><div class="wrap">
<img class="img" src="/brand/maintenance-web.png" alt="Sedang perawatan">
<h1>Sedang Perawatan</h1><p>${aman}</p>
<div class="meter"><i></i></div>
<button class="tombol" onclick="location.reload()">↻ Coba lagi sekarang</button>
<span class="small">Kami segera kembali. Terima kasih sudah sabar.</span>
</div></body></html>`, {
          headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
        });
      }
      // Petunjuk arsitektur dari header peramban (dikirim setelah permintaan
      // Accept-CH di bawah). Disuntikkan ke halaman supaya deteksi ABI di web
      // akurat tanpa menunggu getHighEntropyValues yang ditolak banyak browser.
      const baca = (nama) => (req.headers.get(nama) || '').replace(/"/g, '').trim();
      const hintArsitektur = JSON.stringify({
        arch: baca('sec-ch-ua-arch'),
        bitness: baca('sec-ch-ua-bitness'),
        model: baca('sec-ch-ua-model'),
        platform: baca('sec-ch-ua-platform'),
      }).replace(/</g, '\\u003c');
      // Ganti penanda beserta nilai fallback agar tidak menghasilkan "{...} null".
      // Callback menjaga teks header seperti "$&" tetap menjadi data biasa.
      const WEB = WEB_HTML.replace(/\/\*__XY_CH__\*\/\s*null/, () => hintArsitektur);
      return new Response(WEB, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'public, max-age=300',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'SAMEORIGIN',
          'Referrer-Policy': 'strict-origin-when-cross-origin',
          'Content-Security-Policy': "default-src 'self' https://api.xycloud.my.id https://res.cloudinary.com https://*.giphy.com https://media.giphy.com https://*.onesignal.com data: blob:; script-src 'self' 'unsafe-inline' https://*.onesignal.com; style-src 'self' 'unsafe-inline'; img-src 'self' https://res.cloudinary.com https://*.giphy.com https://media.giphy.com data: blob:; connect-src 'self' https://api.xycloud.my.id wss://*.xycloud.my.id https://*.onesignal.com; frame-ancestors 'self'",
          // minta peramban mengirim arsitektur dan lebar bit perangkat.
          'Accept-CH': 'Sec-CH-UA-Arch, Sec-CH-UA-Bitness, Sec-CH-UA-Model, Sec-CH-UA-Platform-Version, Sec-CH-UA-Full-Version-List',
          'Critical-CH': 'Sec-CH-UA-Arch, Sec-CH-UA-Bitness',
          'Permissions-Policy': 'ch-ua-arch=(self), ch-ua-bitness=(self), ch-ua-model=(self), geolocation=(), microphone=(), camera=()',
          'Vary': 'Sec-CH-UA-Arch, Sec-CH-UA-Bitness',
        },
      });
    }

    // ---------- rilis dan unduhan APK lewat domain sendiri ----------
    if (path === '/api/rilis' && req.method === 'GET') {
      const info = await infoRilis(env, ctx);
      return json({ ...info, saran: tebakAbi(req) }, 200, env);
    }
    if (path.startsWith('/unduh/') && path.length > 7) {
      return unduhApk(env, ctx, decodeURIComponent(path.slice(7)));
    }

    if (path === '/' || path === '/admin' || path === '/admin/') {
      const adminHtml=ADMIN_HTML.replace('/*__XY_MEDIA__*/ {"cloud":"","base":""}',()=>JSON.stringify({cloud:env.CLOUDINARY_CLOUD,base:env.PUBLIC_URL||'https://api.xycloud.my.id'}).replace(/</g,'\\u003c'));
      return new Response(adminHtml, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'SAMEORIGIN',
          'Content-Security-Policy': "default-src 'self' https://api.xycloud.my.id https://res.cloudinary.com https://*.giphy.com data: blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' https://res.cloudinary.com https://*.giphy.com data: blob:; connect-src 'self' https://api.xycloud.my.id wss://*.xycloud.my.id; frame-ancestors 'self'",
          'Referrer-Policy': 'strict-origin-when-cross-origin',
          'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
        },
      });
    }

    if (path === '/legal/syarat' || path === '/legal/privasi') {
      const privasi = path.endsWith('privasi');
      return new Response(halamanLegal(privasi ? 'privasi' : 'syarat'), {
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },
      });
    }

    // ---------- berkas mesin pencari ----------
    if (path === '/robots.txt') {
      return new Response(
        `User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /api/\n\nSitemap: https://xycloud.my.id/sitemap.xml\n`,
        { headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'public, max-age=86400' } },
      );
    }

    if (path === '/manifest.webmanifest') {
      return new Response(JSON.stringify({
        name: 'XyCloudStore',
        short_name: 'XyCloud',
        description: 'Sewa PC Cloud dan Akun Digital',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        background_color: '#1A1033',
        theme_color: '#6C2BE2',
        lang: 'id',
        icons: [
          { src: '/brand/logo.png', sizes: '310x96', type: 'image/png' },
          { src: '/brand/og.png', sizes: '1200x630', type: 'image/png', purpose: 'any' },
        ],
      }), {
        headers: { 'Content-Type': 'application/manifest+json', 'Cache-Control': 'public, max-age=86400' },
      });
    }

    if (path === '/sw.js') {
      const isi = `const CACHE = 'xycloudstore-v1';
self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(['/', '/unduh'])));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((k) => Promise.all(k.filter((x) => x !== CACHE).map((x) => caches.delete(x)))));
  self.clients.claim();
});
self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.pathname.startsWith('/api/') || u.pathname.startsWith('/unduh/')) return;
  e.respondWith(
    fetch(e.request)
      .then((r) => {
        const salin = r.clone();
        caches.open(CACHE).then((c) => c.put(e.request, salin)).catch(() => {});
        return r;
      })
      .catch(() => caches.match(e.request).then((c) => c || caches.match('/')))
  );
});`;
      return new Response(isi, {
        headers: { 'Content-Type': 'application/javascript; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },
      });
    }

    if (path === '/sitemap.xml') {
      const halaman = [
        ['/', '1.0', 'daily'],
        ['/sewa', '0.9', 'daily'],
        ['/akun', '0.9', 'daily'],
        ['/komunitas', '0.8', 'hourly'],
        ['/unduh', '0.9', 'weekly'],
        ['/bantuan', '0.6', 'monthly'],
        ['/legal/syarat', '0.3', 'yearly'],
        ['/legal/privasi', '0.3', 'yearly'],
      ];
      const hariIni = new Date().toISOString().slice(0, 10);

      // produk dan diskusi ikut masuk peta situs supaya bisa ditemukan mesin pencari
      try {
        const { results: produk } = await env.DB
          .prepare('SELECT id FROM akun_produk LIMIT 200').all();
        produk.forEach((r) => halaman.push([`/akun/${r.id}`, '0.7', 'weekly']));

        const { results: diskusi } = await env.DB
          .prepare('SELECT id FROM forum_post ORDER BY dibuat DESC LIMIT 300').all();
        diskusi.forEach((r) => halaman.push([`/komunitas/${r.id}`, '0.6', 'weekly']));
      } catch (_) { /* peta situs tetap terbit walau tabel bermasalah */ }

      const isi = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${halaman.map(([u, p2, f]) => `  <url>
    <loc>https://xycloud.my.id${u}</loc>
    <lastmod>${hariIni}</lastmod>
    <changefreq>${f}</changefreq>
    <priority>${p2}</priority>
  </url>`).join('\n')}
</urlset>`;
      return new Response(isi, {
        headers: { 'Content-Type': 'application/xml; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },
      });
    }

    if (path.startsWith('/img/')) return layaniGambar(env, path, req,ctx);

    if (path === '/brand/og.png') {
      return new Response(OG_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=604800' },
      });
    }

    if (path === '/brand/logo.png') {
      return new Response(LOGO_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' },
      });
    }

    // Ilustrasi mode pemeliharaan (3D ungu glossy, latar transparan).
    if (path === '/brand/maintenance-web.png') {
      return new Response(MAINT_WEB_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=3600' },
      });
    }
    if (path === '/brand/maintenance-app.png') {
      return new Response(MAINT_APP_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=3600' },
      });
    }

    if (path === '/health') return json({ ok: true, at: new Date().toISOString() }, 200, env);

    // pemberitahuan dari penyedia pembayaran
    if (path.startsWith('/bayar/webhook/')) {
      const provider = path.split('/')[3];
      const teks = await req.text();
      const hasil = await bacaPemberitahuan(env, provider, req, teks);
      if (!hasil.sah) return new Response('signature tidak sah', { status: 401 });

      if (hasil.status === 'lunas') {
        const waktu = new Date().toISOString();
        // Klaim atomik: hanya SATU panggilan webhook yang boleh menandai top up
        // 'disetujui'. Webhook yang terulang/bersamaan untuk id sama akan kena 0
        // baris sehingga saldo tidak pernah ditambah dua kali.
        const klaim = await env.DB.prepare(
          "UPDATE topup SET status='disetujui', catatan=?, diproses=? WHERE id=? AND status NOT IN ('disetujui','ditolak')"
        ).bind(`Lunas otomatis lewat ${provider}`, waktu, hasil.id).run();
        if (klaim.meta?.changes) {
          const t = await env.DB.prepare('SELECT * FROM topup WHERE id = ?').bind(hasil.id).first();
          const nominal = Number(t?.nominal) || 0;
          if (t && nominal > 0 && t.user_id) {
            await env.DB.batch([
              env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(nominal, t.user_id),
              env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
                .bind(uid('t_'), t.user_id, 'Top up saldo otomatis', 'topup', nominal),
            ]);

            const u = await env.DB.prepare('SELECT saldo, nama, email FROM users WHERE id = ?')
              .bind(t.user_id).first();
            ctx.waitUntil(push(env, `user:${t.user_id}`, 'wallet.update', { saldo: u?.saldo ?? 0 }));
            ctx.waitUntil(kirimPush(env, {
              userId: t.user_id,
              judul: 'Saldo berhasil ditambahkan',
              pesan: `Pembayaran Rp${nominal.toLocaleString('id-ID')} sudah kami terima.`,
              data: { tipe: 'wallet' },
            }));
            if (u?.email) {
              ctx.waitUntil(kirimEmail(env, {
                to: u.email, template: 'struk',
                data: { nama: u.nama, kode: t.id.toUpperCase(), judul: 'Top up saldo', total: nominal, metode: t.metode },
              }));
            }
          }
        }
      } else if (hasil.status === 'gagal') {
        await env.DB.prepare("UPDATE topup SET status='ditolak', catatan='Pembayaran kedaluwarsa atau dibatalkan' WHERE id = ? AND status != 'disetujui'")
          .bind(hasil.id).run();
      }

      return new Response('OK', { status: 200 });
    }

    if (!path.startsWith('/api/')) return err('Not found', 404, env);
    const p = path.slice(5);
    const ip = req.headers.get('CF-Connecting-IP') || 'tanpa-ip';
    // v3.3 global IP rate-limit: 180 req / 60s (D1 atomic)
    if (!p.startsWith('admin/') && !p.startsWith('agen/') && !p.startsWith('bayar/webhook/')) {
      try {
        const ok = await securitySlot(env, 'global-ip', `ip:${ip}`, 180, 60);
        if (!ok) return err('Terlalu banyak permintaan, tunggu sebentar.', 429, env);
      } catch (_) {
        // fail-open kalau D1 batas bermasalah, tapi log
      }
    }

    // saat mode pemeliharaan bertingkat menyala, hanya admin dan agen yang boleh
    // lewat; admin tetap selalu boleh untuk mematikannya. Cakupan memutuskan
    // apakah situs publik (web), aplikasi Android, atau keduanya yang diblokir.
    if (!p.startsWith('admin/') && !p.startsWith('agen/')) {
      const kena = await tertutupPemeliharaan(env, req);
      // /api/config tetap boleh dibaca supaya aplikasi bisa menampilkan pesan
      // pemeliharaan yang benar, bukan galat yang membingungkan.
      if (kena && p !== 'config') {
        return err(
          await setelan(env, 'pesan_pemeliharaan',
            'Kami sedang melakukan perawatan singkat. Silakan coba lagi beberapa menit lagi.'),
          503, env,
        );
      }
    }

    try {
      if(p.startsWith('auth/')&&Number(req.headers.get('content-length')||0)>32768)return err('Data autentikasi terlalu besar',413,env);
      // ---------------- AGEN PC HOST ----------------
      // Agen memakai kode rahasianya sendiri, bukan token pengguna.
      if (p.startsWith('agen/')) {
        const kode = req.headers.get('x-agen-kode') || '';
        if (!kode) return err('Kode agen tidak dikirim', 401, env);
        const agen = await env.DB.prepare('SELECT * FROM agen WHERE kode = ?').bind(kode).first();
        if (!agen) return err('Agen tidak dikenal', 401, env);

        // ---- laporan hidup + spesifikasi ----
        if (p === 'agen/heartbeat' && req.method === 'POST') {
          await rawatSewa(env);
          const b = await req.json().catch(() => ({}));
          await env.DB.prepare(
            "UPDATE agen SET status = ?, spec = COALESCE(?, spec), versi = COALESCE(?, versi), host = COALESCE(?, host), terakhir = ? WHERE id = ?"
          ).bind(
            b.status || 'online',
            b.spec ? JSON.stringify(b.spec) : null,
            b.versi || null,
            b.host || null,
            new Date().toISOString(),
            agen.id
          ).run();

          const { results } = await env.DB
            .prepare("SELECT * FROM perintah WHERE agen_id = ? AND status = 'antre' ORDER BY dibuat ASC LIMIT 5")
            .bind(agen.id).all();

          if (results.length) {
            await env.DB.prepare(
              `UPDATE perintah SET status = 'diambil' WHERE id IN (${results.map(() => '?').join(',')})`
            ).bind(...results.map((r) => r.id)).run();
          }

          const lease = await env.DB.prepare("SELECT s.id,COALESCE(s.berakhir,o.berakhir) AS berakhir,s.status FROM sesi s JOIN agen a ON a.sesi_aktif=s.id LEFT JOIN orders o ON o.id=s.order_id WHERE a.id=?").bind(agen.id).first();
          return json({
            ok: true, lease,
            perintah: results.map((r) => ({ ...r, muatan: r.muatan ? JSON.parse(r.muatan) : {} })),
          }, 200, env);
        }

        // Only the owning agent can acknowledge a persisted command/session.
        if (p.startsWith('agen/perintah/') && req.method === 'POST') {
          const b = await req.json().catch(() => ({}));
          const command = await env.DB.prepare('SELECT * FROM perintah WHERE id=? AND agen_id=?').bind(p.split('/')[2],agen.id).first();
          const session = await konfirmasiAgen(env,agen,command,b);
          if(session.status==='siap'&&command?.jenis==='mulai_sesi'&&command.status!=='selesai')ctx.waitUntil(kirimPush(env,{userId:session.user_id,judul:'Unit siap dimainkan',pesan:'Buka sesi PC di XyCloudStore untuk menyambung.',data:{tipe:'sesi',id:session.id},tombol:[{id:'mulai',text:'Mulai Main'}]}));
          ctx.waitUntil(push(env,`user:${session.user_id}`,'sesi.update',session));
          const order = await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(session.order_id).first();
          if(order) { ctx.waitUntil(push(env,`user:${session.user_id}`,'order.update',order));
            const plan=await env.DB.prepare('SELECT id,unit_tersedia FROM pc_plans WHERE id=?').bind(order.plan_id).first();
            if(plan)ctx.waitUntil(push(env,'katalog','stock.update',{id:plan.id,unitTersedia:plan.unit_tersedia}));
            ctx.waitUntil(segarkanTier(env,session.user_id)); }
          return json({ok:true},200,env);
        }
        if(p==='agen/sesi/selesai' && req.method==='POST') {
          const b=await req.json();
          const session=await env.DB.prepare('SELECT * FROM sesi WHERE id=? AND agen_id=?').bind(String(b.sesi_id||''),agen.id).first();
          if(!session)return err('Sesi tidak ditemukan',404,env);
          if(b.ok!==true)return err('Pembersihan host belum berhasil',409,env);
          await tutupSewa(env,session);
          ctx.waitUntil(push(env,`user:${session.user_id}`,'sesi.update',{...session,status:'selesai'}));
          return json({ok:true},200,env);
        }

        return err('Endpoint agen tidak dikenal', 404, env);
      }

      if (p === 'promosi' && req.method === 'GET') return json(await daftarPromosi(env), 200, env);

      // ---------------- FORUM KOMUNITAS (baca boleh tanpa login) ----------------
      if (p === 'forum' && req.method === 'GET') {
        const kategori = url.searchParams.get('kategori');
        const cari = url.searchParams.get('cari');
        const halaman = Math.max(1, Number(url.searchParams.get('halaman') || 1));
        const per = 20;

        let sql = 'SELECT * FROM forum_post';
        const syarat = [];
        const nilai = [];
        if (kategori && kategori !== 'Semua') {
          syarat.push('kategori = ?');
          nilai.push(kategori);
        }
        if (cari) {
          syarat.push('(f.judul LIKE ? OR f.isi LIKE ?)');
          nilai.push(`%${cari}%`, `%${cari}%`);
        }
        if (syarat.length) sql += ' WHERE ' + syarat.join(' AND ');
        sql += ' ORDER BY disematkan DESC, dibuat DESC LIMIT ? OFFSET ?';
        nilai.push(per, (halaman - 1) * per);

        // ambil tier penulis supaya lencana member tampil di komunitas
        sql = sql.replace(
          'SELECT * FROM forum_post',
          `SELECT f.*, COALESCE(u.tier, CASE WHEN f.user_id = 'admin' THEN 'admin' ELSE 'basic' END) AS tier,
                  u.nama AS nama_terbaru, u.badge AS badge, COALESCE(u.foto, f.foto) AS foto
           FROM forum_post f LEFT JOIN users u ON u.id = f.user_id`
        ).replace('WHERE kategori', 'WHERE f.kategori')
         .replace('ORDER BY disematkan DESC, dibuat DESC', 'ORDER BY f.disematkan DESC, f.dibuat DESC');

        const { results } = await env.DB.prepare(sql).bind(...nilai).all();
        return json(results.map((r) => ({ ...r, nama: r.nama_terbaru || r.nama, gambar: samarkanGambar(env, r.gambar, 'm'), foto: samarkanGambar(env, r.foto, 's') })), 200, env);
      }

      if (p.startsWith('forum/') && p.split('/').length === 2 && req.method === 'GET') {
        const id = p.split('/')[1];
        const post = await env.DB.prepare(
          `SELECT f.*, COALESCE(u.tier, CASE WHEN f.user_id = 'admin' THEN 'admin' ELSE 'basic' END) AS tier,
                  u.nama AS nama_terbaru, u.badge AS badge, COALESCE(u.foto, f.foto) AS foto
           FROM forum_post f LEFT JOIN users u ON u.id = f.user_id WHERE f.id = ?`
        ).bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);

        const { results } = await env.DB.prepare(
          `SELECT b.*, COALESCE(u.tier, CASE WHEN b.admin = 1 THEN 'admin' ELSE 'basic' END) AS tier,
                  u.nama AS nama_terbaru, u.badge AS badge, COALESCE(u.foto, b.foto) AS foto
           FROM forum_balasan b LEFT JOIN users u ON u.id = b.user_id
           WHERE b.post_id = ? ORDER BY b.dibuat DESC, b.id DESC LIMIT 200`
        ).bind(id).all();

        return json({
          post: { ...post, nama: post.nama_terbaru || post.nama, gambar: samarkanGambar(env, post.gambar, 'l'), foto: samarkanGambar(env, post.foto, 's') },
          balasan: results.reverse().map((r) => ({ ...r, nama: r.nama_terbaru || r.nama, stiker: bacaStiker(r.stiker), foto: samarkanGambar(env, r.foto, 's') })),
        }, 200, env);
      }

      // ---------------- LAPORAN GALAT APLIKASI ----------------
      if (p === 'galat' && req.method === 'POST') {
        if (!(await bolehLanjut(env, `galat:${ip}`, 20, 300))) return json({ ok: true }, 200, env);
        const b = await req.json().catch(() => ({}));
        const pesan = String(b.pesan || '').slice(0, 400);
        if (!pesan) return json({ ok: true }, 200, env);

        // galat yang sama digabung supaya daftarnya tidak banjir
        const kunci = await crypto.subtle.digest('SHA-1',
          new TextEncoder().encode(pesan + (b.layar || '')));
        const id = 'gl_' + [...new Uint8Array(kunci)].map((x) => x.toString(16).padStart(2, '0')).join('').slice(0, 16);
        const waktu = new Date().toISOString();

        await env.DB.prepare(
          `INSERT INTO galat (id,user_id,versi,perangkat,android,pesan,jejak,layar,jumlah,terakhir)
           VALUES (?,?,?,?,?,?,?,?,1,?)
           ON CONFLICT(id) DO UPDATE SET jumlah = jumlah + 1, terakhir = excluded.terakhir,
             status = CASE WHEN galat.status = 'selesai' THEN 'baru' ELSE galat.status END`
        ).bind(id, b.user_id || null, b.versi || null, b.perangkat || null, b.android || null,
               pesan, String(b.jejak || '').slice(0, 2000), b.layar || null, waktu).run();

        return json({ ok: true }, 201, env);
      }

      // ---------------- CATATAN KUNJUNGAN SITUS ----------------
      if (p === 'kunjungan' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        ctx.waitUntil(env.DB.prepare(
          'INSERT INTO kunjungan (id,jenis,halaman,referer,negara,perangkat) VALUES (?,?,?,?,?,?)'
        ).bind(
          uid('kj_'),
          String(b.jenis || 'halaman').slice(0, 30),
          String(b.halaman || '/').slice(0, 120),
          String(b.referer || '').slice(0, 120),
          req.cf?.country || '-',
          (req.headers.get('user-agent') || '').toLowerCase().includes('android') ? 'android'
            : (req.headers.get('user-agent') || '').toLowerCase().includes('iphone') ? 'ios' : 'desktop',
        ).run().catch(() => {}));
        return json({ ok: true }, 200, env);
      }

      // ---------------- ULASAN PAKET PC (baca) ----------------
      if (p.startsWith('pc/plans/') && p.endsWith('/ulasan') && req.method === 'GET') {
        const planId = p.split('/')[2];
        const { results } = await env.DB
          .prepare('SELECT * FROM ulasan_pc WHERE plan_id = ? ORDER BY waktu DESC LIMIT 60').bind(planId).all();
        return json(results, 200, env);
      }

      // ---------------- LEGAL ----------------
      if (p === 'legal/syarat' && req.method === 'GET') return json(isiLegal('syarat'), 200, env);
      if (p === 'legal/privasi' && req.method === 'GET') return json(isiLegal('privasi'), 200, env);

      // ---------------- KONFIGURASI APLIKASI ----------------
      if (p === 'config' && req.method === 'GET') {
        return json({
          providers: providerSiap(env),
          whatsapp: env.WA_ADMIN || '',
          rekening: {
            bank: env.BANK_NAMA || 'BCA',
            nomor: env.BANK_NOMOR || '1234567890',
            atasNama: env.BANK_ATASNAMA || 'XyCloudStore',
            qris: env.QRIS_URL || '',
          },
          minTopup: Number(env.MIN_TOPUP || 10000),
          pembayaran: {
            otomatis: penyediaBayar(env) !== 'manual',
            penyedia: penyediaBayar(env),
            metode: metodeTersedia(env),
          },
          tier: TIER,
          versiMinimal: await setelan(env, 'versi_minimal', ''),
        }, 200, env);
      }

      // ---------------- LOGIN GOOGLE NATIVE (tanpa browser) ----------------
      if (p === 'auth/google/native' && req.method === 'POST') {
        await requireRate(env,'google-native-ip',ip,12,300);
        const deviceId=await deviceFromRequest(env,req);
        const { id_token: idToken } = await req.json().catch(() => ({}));
        const prof = await verifikasiIdTokenGoogle(env, idToken);
        if (!prof.ok) return err(prof.alasan, 401, env);

        const u = await akunSosial(env, ctx, prof, 'google',deviceId,req);
        const token = await issueUserToken(env,u,typeof deviceId==='undefined'?null:deviceId);
        delete u.password;
        return json({ token, user: u }, 200, env);
      }

      // ---------------- LOGIN SOSIAL LEWAT HALAMAN WEB ----------------
      if (p.startsWith('auth/') && (p.endsWith('/start') || p.endsWith('/callback'))) {
        const bagian = p.split('/');            // auth / provider / aksi
        const provider = bagian[1];
        const aksi = bagian[2];
        const siap = providerSiap(env);

        if (!siap[provider]) {
          return err(`Login ${provider} belum dikonfigurasi`, 501, env);
        }

        if (aksi === 'start') {
          await requireRate(env,'oauth-start-ip',ip,12,300);
          const deviceId=await deviceFromRequest(env,req,{raw:url.searchParams.get('device')});
          const state=await newOAuthState(env,provider,deviceId);
          return new Response(null,{status:302,headers:{Location:urlMulai(env,provider,state),
            'Set-Cookie':`xy_oauth_nonce=${state}; HttpOnly; Secure; SameSite=Lax; Path=/api/auth; Max-Age=600`}});
        }
        let deviceId;
        try{deviceId=await consumeOAuthState(env,req,provider);}catch(e){
          return new Response(halamanKembali(`${SKEMA_APLIKASI}://auth?error=Login%20kedaluwarsa.%20Mulai%20ulang.`, 'Login tidak valid'),{headers:{'Content-Type':'text/html; charset=utf-8'}});
        }

        // callback
        const code = url.searchParams.get('code');
        const galat = url.searchParams.get('error');
        if (galat || !code) {
          return new Response(
            halamanKembali(`${SKEMA_APLIKASI}://auth?error=${encodeURIComponent(galat || 'dibatalkan')}`, 'Login dibatalkan'),
            { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
          );
        }

        const prof = await ambilProfil(env, provider, code);
        if (!prof.ok) {
          return new Response(
            halamanKembali(`${SKEMA_APLIKASI}://auth?error=${encodeURIComponent(prof.alasan)}`, 'Login gagal'),
            { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
          );
        }

        const u = await akunSosial(env, ctx, prof, provider,deviceId,req);

        const token = await issueUserToken(env,u,typeof deviceId==='undefined'?null:deviceId);
        return new Response(
          halamanKembali(`${SKEMA_APLIKASI}://auth?token=${encodeURIComponent(token)}`, `Halo ${u.nama.split(' ')[0]}`),
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      }

      // ---------------- AUTH ----------------
      if (p === 'auth/login' && req.method === 'POST') {
        const deviceId=await deviceFromRequest(env,req);
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `login:${ip}`, 12, 300))) {
          return err('Terlalu banyak percobaan masuk. Coba lagi 5 menit lagi.', 429, env);
        }
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        if (!email || !password) return err('Email dan password wajib diisi', 400, env);
        await requireRate(env,'login-email',email,10,900);

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Email atau password belum sesuai.', 401, env);
        assertAccountEnabled(u);
        if (!(await cocokPw(password, u.password))) return err('Password salah. Coba lagi.', 401, env);

        if (!u.email_verified) {
          ctx.waitUntil(kirimOtp(env, { email: u.email, nama: u.nama, tipe: 'verifikasi' }));
          return json({ perluVerifikasi: true, email: u.email, nama: u.nama,
            pesan: 'Email belum diverifikasi. Periksa kode terakhir atau gunakan Kirim Ulang setelah jeda.' }, 200, env);
        }

        // upgrade otomatis password lama ke bentuk hash
        if (!String(u.password).includes('$')) {
          const baru = await buatPw(password);
          ctx.waitUntil(env.DB.prepare('UPDATE users SET password=? WHERE id=?').bind(baru, u.id).run());
        }

        const token = await issueUserToken(env,u,typeof deviceId==='undefined'?null:deviceId);
        delete u.password;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'auth/register' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `daftar:${ip}`, 6, 3600))) {
          return err('Terlalu banyak pendaftaran dari jaringan ini. Coba lagi nanti.', 429, env);
        }
        const nama = String(body.nama || '').trim();
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        const phone = String(body.phone || '').trim() || null;

        if (nama.length < 3) return err('Nama minimal 3 karakter', 400, env);
        if (!emailValid(email)) return err('Format email tidak valid', 400, env);
        if (password.length < 6) return err('Password minimal 6 karakter', 400, env);

        const ada = await env.DB.prepare('SELECT id, email_verified FROM users WHERE lower(email) = ?')
          .bind(email).first();
        if (ada && ada.email_verified) return err('Email sudah terdaftar. Silakan masuk.', 409, env);

        if(ada)return json({perluVerifikasi:true,email,nama,emailTerkirim:false,pesan:'Pendaftaran sudah tercatat. Masuk atau minta ulang kode; data akun tidak ditimpa.'},200,env);
        const deviceId=await deviceFromRequest(env,req,{required:true});
        await beforeRegistration(env,req,deviceId);
        const id=uid('u_');
        await env.DB.prepare("INSERT INTO users(id,nama,email,password,phone,saldo,tier,email_verified,registration_device) VALUES(?,?,?,?,?,0,'basic',0,?)")
          .bind(id,nama,email,await buatPw(password),phone,deviceId).run().catch(translateRegistrationError);

        const hasil = await kirimOtp(env, { email, nama, tipe: 'verifikasi' });

        return json({
          perluVerifikasi: true,
          email,
          nama,
          emailTerkirim: hasil.ok,
          pesan: hasil.ok
            ? `Kode verifikasi dikirim ke ${email}. Cek kotak masuk atau folder spam.`
            : 'Akun dibuat, tetapi email verifikasi gagal dikirim. Coba minta kode ulang.',
        }, 201, env);
      }

      // ---- verifikasi email dengan kode OTP ----
      if (p === 'auth/verify' && req.method === 'POST') {
        const deviceId=await deviceFromRequest(env,req);
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `verif:${ip}`, 20, 900))) {
          return err('Terlalu banyak percobaan kode. Coba lagi nanti.', 429, env);
        }
        const email = String(body.email || '').trim().toLowerCase();
        const kode = String(body.kode || '').trim();

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Akun tidak ditemukan',404,env);
        assertAccountEnabled(u);
        if (u.email_verified) return err('Email sudah terverifikasi. Silakan masuk dengan password atau penyedia login.',409,env);

        const cek = await cekOtp(env, { email, kode, tipe: 'verifikasi' });
        if (!cek.ok) return err(cek.pesan, 400, env);

        await env.DB.prepare('UPDATE users SET email_verified = 1 WHERE id = ?').bind(u.id).run();

        // sapaan CS + email selamat datang
        const sapa = {
          id: uid('m_'), room: `user:${u.id}`, dari: 'cs',
          teks: `Halo ${u.nama.split(' ')[0]}, aku Kirana dari XyCloudStore. Ada yang bisa aku bantu hari ini?`,
          waktu: new Date().toISOString(),
        };
        ctx.waitUntil(env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
          .bind(sapa.id, sapa.room, u.id, 'cs', sapa.teks, sapa.waktu).run());
        ctx.waitUntil(kirimEmail(env, { to: email, template: 'selamatDatang', data: { nama: u.nama } }));

        const token = await issueUserToken(env,u,typeof deviceId==='undefined'?null:deviceId);
        delete u.password;
        u.email_verified = 1;
        return json({ token, user: u }, 200, env);
      }

      // ---- kirim ulang kode ----
      if (p === 'auth/resend' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `kode:${ip}`, 6, 900))) {
          return err('Kode sudah dikirim beberapa kali. Tunggu sebentar ya.', 429, env);
        }
        const email = String(body.email || '').trim().toLowerCase();
        const tipe = body.tipe === 'reset' ? 'reset' : 'verifikasi';
        const u = await env.DB.prepare('SELECT nama, email_verified FROM users WHERE lower(email) = ?')
          .bind(email).first();
        if (!u) return err('Email belum terdaftar', 404, env);
        if (tipe === 'verifikasi' && u.email_verified) return err('Email ini sudah terverifikasi', 400, env);
        const hasil = await kirimOtp(env, { email, nama: u.nama, tipe });
        if (!hasil.ok) return err('Gagal mengirim email: ' + hasil.alasan, 502, env);
        return json({ ok: true, pesan: `Kode baru dikirim ke ${email}` }, 200, env);
      }

      // ---- lupa password ----
      if (p === 'auth/forgot' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `lupa:${ip}`, 6, 900))) {
          return err('Permintaan reset terlalu sering. Coba lagi 15 menit lagi.', 429, env);
        }
        const email = String(body.email || '').trim().toLowerCase();
        const u = await env.DB.prepare('SELECT nama FROM users WHERE lower(email) = ?').bind(email).first();
        // jawaban selalu sama supaya email orang lain tidak bisa ditebak
        if (u) ctx.waitUntil(kirimOtp(env, { email, nama: u.nama, tipe: 'reset' }));
        return json({ ok: true, pesan: 'Kalau email terdaftar, kode reset sudah kami kirim.' }, 200, env);
      }

      // ---- pasang password baru ----
      if (p === 'auth/reset' && req.method === 'POST') {
        const deviceId=await deviceFromRequest(env,req);
        await requireRate(env,'reset-ip',ip,10,900);
        const body = await req.json().catch(() => ({}));
        const email = String(body.email || '').trim().toLowerCase();
        const kode = String(body.kode || '').trim();
        const password = String(body.password || '');
        if (password.length < 6) return err('Password minimal 6 karakter', 400, env);

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Akun tidak ditemukan',404,env);
        assertAccountEnabled(u);

        const cek = await cekOtp(env, { email, kode, tipe: 'reset' });
        if (!cek.ok) return err(cek.pesan, 400, env);

        await env.DB.prepare('UPDATE users SET password = ?, email_verified = 1,session_version=session_version+1 WHERE id = ?')
          .bind(await buatPw(password), u.id).run();

        u.session_version=(u.session_version||0)+1;
        const token = await issueUserToken(env,u,typeof deviceId==='undefined'?null:deviceId);
        delete u.password;
        u.email_verified = 1;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'pc/plans' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM pc_plans').all();
        return json(results.map(r=>({...r,gambar:samarkanGambar(env,r.gambar,'m')})),200,env);
      }

      if (p === 'banners' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM banners WHERE aktif = 1 ORDER BY urutan ASC').all();
        return json(results.map(r=>({...r,gambar:samarkanGambar(env,r.gambar,'m')})),200,env);
      }

      // ================= ADMIN =================
      if (p.startsWith('admin/')) {
        if (!(await bolehLanjut(env, `admin:${ip}`, 240, 60))) {
          return err('Terlalu banyak permintaan admin.', 429, env);
        }

        const admin = await kenaliAdmin(req, env);
        if (!admin) return err('Forbidden', 403, env);

        const jalurAdmin = p.slice(6);
        if (!bolehAkses(admin.peran, jalurAdmin)) {
          return err(`Peran ${admin.peran} tidak punya akses ke bagian ini`, 403, env);
        }
        if (req.method !== 'GET') {
          ctx.waitUntil(catatAdmin(env, admin, `${req.method} ${jalurAdmin}`, null));
        }
        const a = jalurAdmin;

        if(a==='security'||a.startsWith('security/')||a==='devices'||a.startsWith('devices/')||a==='audit'||/^users\/[^/]+\/(trash|restore|permanent)$/.test(a)){
          const result=await adminSecurity(env,admin,a,req);
          if(result!==undefined)return json(result,200,env);
        }
        if(a==='media'&&req.method==='GET'){
          if(admin.peran!=='pemilik')return err('Hanya pemilik',403,env);
          const {results}=await env.DB.prepare('SELECT * FROM media_assets ORDER BY created_at DESC LIMIT 200').all();
          return json(results.map(m=>({...m,preview:samarkanGambar(env,m.url,'t')})),200,env);
        }

        if (a === 'stats' && req.method === 'GET') {
          const q = (sql) => env.DB.prepare(sql).first();
          const [u, o, oa, rev, prod, msg] = await Promise.all([
            q('SELECT COUNT(*) c FROM users'),
            q('SELECT COUNT(*) c FROM orders'),
            q("SELECT COUNT(*) c FROM orders WHERE status IN ('aktif','provisioning','dibayar','pending')"),
            q("SELECT COALESCE(SUM(ABS(nominal)),0) c FROM transaksi WHERE nominal < 0"),
            q('SELECT COUNT(*) c FROM akun_produk'),
            q('SELECT COUNT(*) c FROM cs_messages'),
          ]);
          const { results: harian } = await env.DB.prepare(
            "SELECT substr(dibuat,1,10) d, COUNT(*) n, COALESCE(SUM(total),0) v FROM orders GROUP BY d ORDER BY d DESC LIMIT 7"
          ).all();
          return json({
            users: u.c, orders: o.c, ordersAktif: oa.c, revenue: rev.c,
            produk: prod.c, pesan: msg.c, harian,
          }, 200, env);
        }

        if (a === 'orders' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            'SELECT o.*, u.nama AS user_nama, u.email AS user_email FROM orders o LEFT JOIN users u ON u.id=o.user_id ORDER BY o.dibuat DESC LIMIT 100'
          ).all();
          return json(results, 200, env);
        }

        if(a.startsWith('orders/') && req.method==='PATCH'){
          const order=await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(a.split('/')[1]).first();
          if(!order)return err('Pesanan tidak ditemukan',404,env);
          const body=await req.json();
          if(!['selesai','batal'].includes(body.status))return err('Status siap/aktif berasal dari agen. Mulai sesi melalui aplikasi.',409,env);
          const session=await env.DB.prepare("SELECT * FROM sesi WHERE order_id=? AND status NOT IN ('selesai','gagal') ORDER BY dibuat DESC LIMIT 1").bind(order.id).first();
          if(session){
            if(body.status==='batal'&&['dibayar','provisioning'].includes(order.status))await env.DB.prepare("UPDATE orders SET status='batal' WHERE id=?").bind(order.id).run();
            await antreAkhir(env,session,'Sesi dihentikan melalui dashboard');
          }else{
            await env.DB.prepare("UPDATE orders SET status=? WHERE id=? AND status NOT IN ('selesai','batal')").bind(order.status==='dibayar'?'batal':body.status,order.id).run();
          }
          const result=await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(order.id).first();
          ctx.waitUntil(push(env,`user:${order.user_id}`,'order.update',result));
          return json(result,200,env);
        }

        // ---- katalog PC ----
        if (a === 'plans' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM pc_plans').all();
          return json(results, 200, env);
        }
        if (a === 'plans' && req.method === 'POST') {
          const b = await req.json();
          const idPaket = b.id || uid('pc-');

          // gambar boleh data URI hasil unggah dashboard; simpan ke Cloudinary
          let gambar = b.gambar || '';
          if (gambar.startsWith('data:')) {
            const hasil = await unggahGambar(env, { dataUri: gambar, folder: 'xycloudstore/paket' });
            if (!hasil.ok) return err(hasil.alasan, 502, env);
            gambar = hasil.url;
          }

          // jaga nilai rating & jumlah ulasan saat paket diubah (jangan di-reset)
          const lama = await env.DB.prepare('SELECT rating, jumlah_ulasan FROM pc_plans WHERE id = ?')
            .bind(idPaket).first();

          await env.DB.prepare(
            `INSERT OR REPLACE INTO pc_plans
             (id,nama,gpu,cpu,ram_gb,storage_gb,harga_per_jam,harga_per_hari,region,tag,total_unit,unit_tersedia,gambar,rating,jumlah_ulasan)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(idPaket, b.nama, b.gpu, b.cpu, b.ram_gb, b.storage_gb, b.harga_per_jam,
                 b.harga_per_hari, b.region, b.tag || '', b.total_unit, b.unit_tersedia, gambar,
                 lama?.rating ?? 5, lama?.jumlah_ulasan ?? 0).run();
          ctx.waitUntil(push(env, 'katalog', 'stock.update', { id: idPaket, unitTersedia: b.unit_tersedia }));
          return json({ ok: true, id: idPaket, gambar }, 201, env);
        }
        if (a.startsWith('plans/') && req.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM pc_plans WHERE id=?').bind(a.split('/')[1]).run();
          return json({ ok: true }, 200, env);
        }

        // ---- katalog akun ----
        if (a === 'produk' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM akun_produk').all();
          return json(results, 200, env);
        }
        if (a === 'produk' && req.method === 'POST') {
          const b = await req.json();
          const idProduk = b.id || uid('ak-');

          // gambar boleh berupa data URI hasil unggah dari dashboard
          let gambar = b.gambar || '';
          if (gambar.startsWith('data:')) {
            const hasil = await unggahGambar(env, { dataUri: gambar, folder: 'xycloudstore/produk' });
            if (!hasil.ok) return err(hasil.alasan, 502, env);
            gambar = hasil.url;
          }

          const lama = await env.DB.prepare('SELECT rating, jumlah_ulasan FROM akun_produk WHERE id = ?')
            .bind(idProduk).first();

          await env.DB.prepare(
            `INSERT OR REPLACE INTO akun_produk
             (id,nama,kategori,deskripsi,detail,harga,harga_coret,stok,rating,jumlah_ulasan,terjual,gambar,fitur,garansi)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(
            idProduk, b.nama, b.kategori, b.deskripsi || '',
            JSON.stringify(b.detail || {}),
            b.harga, b.harga_coret || 0, b.stok || 0,
            lama?.rating ?? (b.rating || 5), lama?.jumlah_ulasan ?? 0,
            b.terjual || 0, gambar,
            JSON.stringify(b.fitur || []), b.garansi || '30 hari'
          ).run();

          ctx.waitUntil(push(env, 'katalog', 'produk.update', { id: idProduk }));
          return json({ ok: true, id: idProduk, gambar }, 201, env);
        }
        if (a.startsWith('produk/') && req.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM akun_produk WHERE id=?').bind(a.split('/')[1]).run();
          return json({ ok: true }, 200, env);
        }

        // ---- promo melayang / pop-up dan integrasi stiker ----
        if (a.startsWith('promosi') || a.startsWith('integrasi/giphy')) {
          if (admin.peran !== 'pemilik') return err('Hanya pemilik yang boleh mengatur promosi/integrasi', 403, env);
          if (a === 'promosi' && req.method === 'GET') return json(await daftarPromosi(env, true), 200, env);
          if (a === 'promosi' && req.method === 'POST') {
            const hasil = await simpanPromosi(env, await req.json());
            ctx.waitUntil(push(env, 'katalog', 'promosi.update', {}));
            ctx.waitUntil(catatAdmin(env, admin, 'simpan promosi', hasil.id));
            return json(hasil, 201, env);
          }
          if (a.startsWith('promosi/') && req.method === 'DELETE') {
            await env.DB.prepare('DELETE FROM promo_overlay WHERE id = ?').bind(a.split('/')[1]).run();
            ctx.waitUntil(push(env, 'katalog', 'promosi.update', {}));
            return json({ ok: true }, 200, env);
          }
          if (a === 'integrasi/giphy' && req.method === 'GET') return json({ siap: Boolean(await ambilKunciGiphy(env)), dari_env: Boolean(env.GIPHY_API_KEY) }, 200, env);
          if (a === 'integrasi/giphy' && req.method === 'POST') {
            const b = await req.json();
            return json(await simpanKunciGiphy(env, b.api_key), 200, env);
          }
          if (a === 'integrasi/giphy' && req.method === 'DELETE') {
            if (env.GIPHY_API_KEY) return err('Key berasal dari secret Worker; hapus melalui Cloudflare.', 409, env);
            await env.DB.prepare("DELETE FROM setelan WHERE kunci = 'integrasi_giphy_terenkripsi'").run();
            return json({ ok: true, siap: false }, 200, env);
          }
        }

        // ---- banner ----
        if (a === 'banners' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM banners ORDER BY urutan ASC').all();
          return json(results, 200, env);
        }
        if (a === 'banners' && req.method === 'POST') {
          const b = await req.json();

          // latar banner boleh gambar kustom (data URI hasil unggah dashboard)
          let gambarB = b.gambar || '';
          if (gambarB.startsWith('data:')) {
            const hasil = await unggahGambar(env, { dataUri: gambarB, folder: 'xycloudstore/banner' });
            if (!hasil.ok) return err(hasil.alasan, 502, env);
            gambarB = hasil.url;
          }

          await env.DB.prepare(
            `INSERT OR REPLACE INTO banners
             (id,judul,subjudul,label,cta,aksi,target,warna1,warna2,ikon,urutan,aktif,gambar)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(b.id || uid('bn-'), b.judul, b.subjudul || '', b.label || '', b.cta || 'Lihat',
                 b.aksi || 'sewa', b.target || '', b.warna1 || '#2F5BFF', b.warna2 || '#6A4BFF',
                 b.ikon || 'bolt', b.urutan || 0, b.aktif === 0 ? 0 : 1, gambarB).run();
          ctx.waitUntil(kirimBanner(env));
          if (b.kirimPush) {
            ctx.waitUntil(siarkanPush(env, {
              judul: b.judul || 'Promo baru XyCloudStore',
              pesan: b.subjudul || 'Buka aplikasi untuk melihat penawarannya.',
              data: { tipe: 'banner', id: b.id },
            }));
          }
          return json({ ok: true }, 201, env);
        }
        if (a.startsWith('banners/') && req.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM banners WHERE id=?').bind(a.split('/')[1]).run();
          ctx.waitUntil(kirimBanner(env));
          return json({ ok: true }, 200, env);
        }

        // ---- inbox CS ----
        if (a === 'cs/rooms' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT m.room, u.nama, u.email, u.phone, COUNT(*) total,
                    MAX(m.waktu) terakhir,
                    (SELECT teks FROM cs_messages x WHERE x.room = m.room ORDER BY waktu DESC LIMIT 1) preview
             FROM cs_messages m LEFT JOIN users u ON u.id = m.user_id
             WHERE m.dihapus=0 AND datetime(m.waktu)>=datetime('now','-7 days')
             GROUP BY m.room ORDER BY terakhir DESC LIMIT 50`
          ).all();
          return json(results, 200, env);
        }
        if (a.startsWith('cs/room/') && req.method === 'GET') {
          const room = decodeURIComponent(a.slice(8));
          const { results } = await env.DB
            .prepare(`SELECT * FROM (SELECT * FROM cs_messages WHERE room=? AND dihapus=0 AND datetime(waktu)>=datetime('now','-7 days') ORDER BY waktu DESC,id DESC LIMIT 300) ORDER BY waktu,id`).bind(room).all();
          return json(results, 200, env);
        }
        if (a === 'cs/reply' && req.method === 'POST') {
          const { room, teks } = await req.json();
          if(!/^user:[A-Za-z0-9_-]+$/.test(String(room||''))||!String(teks||'').trim())return err('Room dan pesan diperlukan',400,env);
          const msg = { id: uid('m_'), room, dari: 'cs', teks, waktu: new Date().toISOString() };
          await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
            .bind(msg.id, room, room.split(':')[1] || '', 'cs', teks, msg.waktu).run();
          ctx.waitUntil(push(env, room, 'chat.message', msg));
          ctx.waitUntil(kirimPush(env, {
            userId: room.split(':')[1],
            judul: 'Kirana membalas pesanmu',
            pesan: teks.length > 90 ? teks.slice(0, 90) + '...' : teks,
            data: { tipe: 'cs' },
            tombol: [{ id: 'balas', text: 'Balas' }, { id: 'buka', text: 'Buka Chat' }],
          }));
          ctx.waitUntil(kirimPush(env,{userId:room.slice(5),judul:'Tim CS membalas pesanmu',pesan:String(teks).slice(0,120),data:{tipe:'cs'},tombol:[{id:'balas',text:'Balas'}]}));
          return json(msg, 201, env);
        }
        if (a === 'cs/typing' && req.method === 'POST') {
          const { room, typing } = await req.json();
          ctx.waitUntil(push(env, room, 'cs.typing', { typing: !!typing }));
          return json({ ok: true }, 200, env);
        }

        // ---- pengguna ----
        if(a==='users'&&req.method==='GET'){
          const trash=url.searchParams.get('trash')==='1';
          if(trash&&admin.peran!=='pemilik')return err('Hanya pemilik',403,env);
          const q=String(url.searchParams.get('q')||'').slice(0,80);
          const {results}=await env.DB.prepare(`SELECT id,nama,email,phone,saldo,tier,badge,diblokir,alasan_blokir,peringatan,
            created_at,foto,total_belanja,kode_referral,deleted_at,registration_device FROM users
            WHERE deleted_at IS ${trash?'NOT ':''}NULL AND (nama LIKE ? OR email LIKE ?) ORDER BY created_at DESC LIMIT 200`).bind('%'+q+'%','%'+q+'%').all();
          return json(results.map(u=>({...u,foto:samarkanGambar(env,u.foto,'s'),owner_protected:ownerProtected(env,u)})),200,env);
        }

        if (a === 'users/saldo' && req.method === 'POST') {
          const { user_id, nominal, catatan } = await req.json();
          await env.DB.batch([
            env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(nominal, user_id),
            env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
              .bind(uid('t_'), user_id, catatan || 'Penyesuaian saldo oleh admin', nominal > 0 ? 'topup' : 'sewa', nominal),
          ]);
          const u = await env.DB.prepare('SELECT saldo FROM users WHERE id=?').bind(user_id).first();
          ctx.waitUntil(push(env, `user:${user_id}`, 'wallet.update', { saldo: u.saldo }));
          return json({ saldo: u.saldo }, 200, env);
        }

        // ---- unggah gambar dari dashboard ----
        if (a === 'upload' && req.method === 'POST') {
          const { file, folder } = await req.json();
          const hasil = await unggahGambar(env, { dataUri: file, folder: folder || 'xycloudstore/produk' });
          return hasil.ok ? json(hasil, 201, env) : err(hasil.alasan, 502, env);
        }

        // ---- daftar permintaan top up ----
        if (a === 'topup' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT t.*, u.nama, u.email, u.phone FROM topup t
             JOIN users u ON u.id = t.user_id ORDER BY
             CASE t.status WHEN 'diperiksa' THEN 0 WHEN 'menunggu' THEN 1 ELSE 2 END, t.dibuat DESC LIMIT 200`
          ).all();
          return json(results, 200, env);
        }

        // ---- setujui atau tolak top up ----
        if (a.startsWith('topup/') && req.method === 'PATCH') {
          const id = a.split('/')[1];
          const { status, catatan } = await req.json();
          const waktu = new Date().toISOString();
          if (status === 'disetujui') {
            // Klaim atomik: hanya sekali yang boleh menandai 'disetujui' sehingga
            // setujui berulang/bersamaan tidak pernah menggandakan saldo.
            const klaim = await env.DB.prepare(
              "UPDATE topup SET status='disetujui', catatan=?, diproses=? WHERE id=? AND status IN ('menunggu','diperiksa')"
            ).bind(catatan || 'Disetujui admin', waktu, id).run();
            if (!klaim.meta?.changes) {
              const kini = await env.DB.prepare('SELECT status FROM topup WHERE id=?').bind(id).first();
              if (kini?.status === 'disetujui') return err('Top up ini sudah disetujui', 409, env);
              if (kini?.status === 'ditolak') return err('Top up ini sudah ditolak sebelumnya', 409, env);
              return err('Permintaan tidak ditemukan', 404, env);
            }
            const t2 = await env.DB.prepare('SELECT * FROM topup WHERE id=?').bind(id).first();
            const nominal = Number(t2?.nominal) || 0;
            if (!t2 || nominal <= 0 || !t2.user_id) return err('Top up tidak valid', 400, env);
            await env.DB.batch([
              env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(nominal, t2.user_id),
              env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
                .bind(uid('t_'), t2.user_id, 'Top up saldo', 'topup', nominal),
            ]);
            const u = await env.DB.prepare('SELECT saldo, nama, email FROM users WHERE id = ?').bind(t2.user_id).first();
            ctx.waitUntil(push(env, `user:${t2.user_id}`, 'wallet.update', { saldo: u.saldo }));
            ctx.waitUntil(kirimPush(env, {
              userId: t2.user_id, judul: 'Top up berhasil',
              pesan: `Saldo Rp${nominal.toLocaleString('id-ID')} sudah masuk ke dompetmu.`,
              data: { tipe: 'wallet' },
            }));
            if (u?.email) {
              ctx.waitUntil(kirimEmail(env, {
                to: u.email, template: 'struk',
                data: { nama: u.nama, kode: id.toUpperCase(), judul: 'Top up saldo', total: nominal, metode: t2.metode },
              }));
            }
            return json({ ok: true, saldo: u.saldo }, 200, env);
          }

          const tr = await env.DB.prepare('SELECT * FROM topup WHERE id = ?').bind(id).first();
          if (!tr) return err('Permintaan tidak ditemukan', 404, env);
          if (tr.status === 'disetujui') return err('Top up ini sudah disetujui', 409, env);
          if (tr.status === 'ditolak') return err('Top up ini sudah ditolak', 409, env);
          await env.DB.prepare("UPDATE topup SET status='ditolak', catatan=?, diproses=? WHERE id=?")
            .bind(catatan || 'Bukti transfer tidak cocok', waktu, id).run();
          ctx.waitUntil(kirimPush(env, {
            userId: tr.user_id, judul: 'Top up ditolak',
            pesan: catatan || 'Bukti transfer tidak cocok. Hubungi CS untuk bantuan.',
            data: { tipe: 'wallet' },
          }));
          return json({ ok: true }, 200, env);
        }

        // ---- ulasan produk ----
        if (a === 'ulasan' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT r.*, p.nama AS produk FROM ulasan r
             LEFT JOIN akun_produk p ON p.id = r.produk_id ORDER BY r.waktu DESC LIMIT 200`
          ).all();
          return json(results, 200, env);
        }

        if (a.startsWith('ulasan/') && req.method === 'PATCH') {
          const id = a.split('/')[1];
          const { balasan } = await req.json();
          await env.DB.prepare('UPDATE ulasan SET balasan = ? WHERE id = ?').bind(balasan || null, id).run();
          return json({ ok: true }, 200, env);
        }

        if (a.startsWith('ulasan/') && req.method === 'DELETE') {
          const id = a.split('/')[1];
          const r = await env.DB.prepare('SELECT produk_id FROM ulasan WHERE id = ?').bind(id).first();
          await env.DB.prepare('DELETE FROM ulasan WHERE id = ?').bind(id).run();
          if (r) {
            const agg = await env.DB
              .prepare('SELECT ROUND(AVG(rating),1) AS r, COUNT(*) AS n FROM ulasan WHERE produk_id = ?')
              .bind(r.produk_id).first();
            await env.DB.prepare('UPDATE akun_produk SET rating = ?, jumlah_ulasan = ? WHERE id = ?')
              .bind(agg.r || 5, agg.n || 0, r.produk_id).run();
          }
          return json({ ok: true }, 200, env);
        }

        // ---- kelola pengguna: lencana, blokir, tier ----
        if (a.startsWith('users/') && a.endsWith('/kelola') && req.method === 'PATCH') {
          const idU = a.split('/')[1];
          const b = await req.json().catch(() => ({}));
          const target=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(idU).first();
          if(target&&b.diblokir&&ownerProtected(env,target))return err('Akun pemilik dilindungi.',409,env);
          const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(idU).first();
          if (!u) return err('Pengguna tidak ditemukan', 404, env);

          await env.DB.prepare(
            `UPDATE users SET badge = ?, tier = COALESCE(NULLIF(?,''), tier),
                              diblokir = COALESCE(?, diblokir), alasan_blokir = ?
             WHERE id = ?`
          ).bind(
            b.badge === '' ? null : (b.badge ?? u.badge),
            b.tier || '',
            b.diblokir == null ? null : (b.diblokir ? 1 : 0),
            b.diblokir ? (b.alasan || 'Melanggar ketentuan komunitas') : null,
            idU,
          ).run();

          if (b.diblokir != null) {
            await env.DB.prepare('UPDATE users SET session_version=session_version+1 WHERE id=?').bind(idU).run();
            if(b.diblokir){const sessions=await env.DB.prepare("SELECT * FROM sesi WHERE user_id=? AND status NOT IN ('selesai','gagal')").bind(idU).all();for(const session of sessions.results)await antreAkhir(env,session,'Akun dibatasi oleh admin');}
            ctx.waitUntil(buatNotif(env, ctx, {
              userId: idU,
              jenis: 'sistem',
              judul: b.diblokir ? 'Akunmu dibekukan' : 'Akunmu diaktifkan kembali',
              pesan: b.diblokir
                ? `Alasan: ${b.alasan || 'Melanggar ketentuan komunitas'}. Hubungi admin lewat chat untuk banding.`
                : 'Terima kasih sudah bekerja sama. Selamat memakai layanan lagi.',
              aktor: 'Admin',
            }));
          }
          if (b.badge !== undefined) {
            ctx.waitUntil(buatNotif(env, ctx, {
              userId: idU,
              jenis: 'sistem',
              judul: b.badge ? `Kamu mendapat lencana ${b.badge}` : 'Lencanamu dilepas',
              pesan: b.badge ? 'Lencana ini tampil di samping namamu pada komunitas.' : '',
              aktor: 'Admin',
            }));
          }

          const baru = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(idU).first();
          delete baru.password;
          return json(baru, 200, env);
        }

        // ---- kirim peringatan ke pengguna ----
        if (a.startsWith('users/') && a.endsWith('/peringatan') && req.method === 'POST') {
          const idU = a.split('/')[1];
          const { pesan } = await req.json().catch(() => ({}));
          const u = await env.DB.prepare('SELECT id, nama, email, peringatan FROM users WHERE id = ?')
            .bind(idU).first();
          if (!u) return err('Pengguna tidak ditemukan', 404, env);

          await env.DB.prepare('UPDATE users SET peringatan = peringatan + 1 WHERE id = ?').bind(idU).run();

          const isi = pesan || 'Mohon jaga sikap di komunitas XyCloudStore.';
          ctx.waitUntil(buatNotif(env, ctx, {
            userId: idU,
            jenis: 'peringatan',
            judul: `Peringatan dari admin (${(u.peringatan || 0) + 1})`,
            pesan: isi,
            aktor: 'Admin',
          }));

          // sekalian kirim sebagai pesan chat supaya pasti terbaca
          const waktu = new Date().toISOString();
          ctx.waitUntil(env.DB.prepare(
            'INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)'
          ).bind(uid('m_'), `user:${idU}`, idU, 'cs', `Peringatan: ${isi}`, waktu).run());
          ctx.waitUntil(push(env, `user:${idU}`, 'chat.message', {
            id: uid('m_'), room: `user:${idU}`, dari: 'cs', teks: `Peringatan: ${isi}`, waktu,
          }));

          return json({ ok: true, peringatan: (u.peringatan || 0) + 1 }, 200, env);
        }

        // ---- daftar laporan konten ----
        if (a === 'laporan' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT l.*, u.nama AS pelapor_nama FROM laporan l
             LEFT JOIN users u ON u.id = l.pelapor
             ORDER BY CASE l.status WHEN 'baru' THEN 0 ELSE 1 END, l.dibuat DESC LIMIT 100`
          ).all();
          return json(results, 200, env);
        }

        if (a.startsWith('laporan/') && req.method === 'PATCH') {
          const idL = a.split('/')[1];
          const b = await req.json().catch(() => ({}));
          await env.DB.prepare('UPDATE laporan SET status = ? WHERE id = ?')
            .bind(b.status || 'selesai', idL).run();
          return json({ ok: true }, 200, env);
        }

        // ---- tandai konten sensitif ----
        if (a.startsWith('konten/') && req.method === 'PATCH') {
          const [, jenis, idK] = a.split('/');
          const tabel = jenis === 'ulasan' ? 'ulasan' : 'forum_post';
          const b = await req.json().catch(() => ({}));
          await env.DB.prepare(`UPDATE ${tabel} SET sensitif = ? WHERE id = ?`)
            .bind(b.sensitif ? 1 : 0, idK).run();
          return json({ ok: true }, 200, env);
        }

        // ---- laporan galat aplikasi ----
        if (a === 'galat' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT g.*, u.nama AS nama_pengguna FROM galat g
             LEFT JOIN users u ON u.id = g.user_id
             ORDER BY CASE g.status WHEN 'baru' THEN 0 ELSE 1 END, g.terakhir DESC LIMIT 100`
          ).all();
          return json(results, 200, env);
        }

        if (a.startsWith('galat/') && req.method === 'PATCH') {
          const idG = a.split('/')[1];
          const b = await req.json().catch(() => ({}));
          await env.DB.prepare('UPDATE galat SET status = ? WHERE id = ?')
            .bind(b.status || 'selesai', idG).run();
          return json({ ok: true }, 200, env);
        }

        if (a.startsWith('galat/') && req.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM galat WHERE id = ?').bind(a.split('/')[1]).run();
          return json({ ok: true }, 200, env);
        }

        // ---- ringkasan referral ----
        if (a === 'referral' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT r.*, p.nama AS nama_pengundang, d.nama AS nama_diundang
             FROM referral r
             LEFT JOIN users p ON p.id = r.pengundang
             LEFT JOIN users d ON d.id = r.diundang
             ORDER BY r.dibuat DESC LIMIT 100`
          ).all();
          const teratas = await env.DB.prepare(
            `SELECT u.nama, u.kode_referral, COUNT(r.id) jumlah, SUM(r.bonus_pengundang) bonus
             FROM referral r JOIN users u ON u.id = r.pengundang
             GROUP BY r.pengundang ORDER BY jumlah DESC LIMIT 10`
          ).all();
          return json({ daftar: results, teratas: teratas.results }, 200, env);
        }

        // ---- analitik kunjungan situs ----
        if (a === 'analitik' && req.method === 'GET') {
          const semua = async (sql) => {
            try {
              const { results } = await env.DB.prepare(sql).all();
              return results;
            } catch (_) {
              return [];
            }
          };
          return json({
            harian: await semua(
              `SELECT substr(waktu,1,10) d, COUNT(*) n FROM kunjungan
               WHERE waktu > datetime('now','-30 day') GROUP BY d ORDER BY d`),
            halaman: await semua(
              `SELECT halaman, COUNT(*) n FROM kunjungan
               WHERE waktu > datetime('now','-30 day') GROUP BY halaman ORDER BY n DESC LIMIT 10`),
            perangkat: await semua(
              `SELECT perangkat, COUNT(*) n FROM kunjungan
               WHERE waktu > datetime('now','-30 day') GROUP BY perangkat ORDER BY n DESC`),
            negara: await semua(
              `SELECT negara, COUNT(*) n FROM kunjungan
               WHERE waktu > datetime('now','-30 day') GROUP BY negara ORDER BY n DESC LIMIT 8`),
            total: (await semua("SELECT COUNT(*) n FROM kunjungan WHERE waktu > datetime('now','-30 day')"))[0]?.n ?? 0,
          }, 200, env);
        }

        // ---- ulasan paket PC ----
        if (a === 'ulasan-pc' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT r.*, p.nama AS paket FROM ulasan_pc r
             LEFT JOIN pc_plans p ON p.id = r.plan_id ORDER BY r.waktu DESC LIMIT 100`
          ).all();
          return json(results, 200, env);
        }

        // ---- voucher ----
        if (a === 'voucher' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM voucher ORDER BY dibuat DESC LIMIT 100').all();
          return json(results, 200, env);
        }

        if (a === 'voucher' && req.method === 'POST') {
          const b = await req.json();
          const kode = String(b.kode || '').trim().toUpperCase();
          if (kode.length < 3) return err('Kode voucher minimal 3 huruf', 400, env);

          await env.DB.prepare(
            `INSERT OR REPLACE INTO voucher
             (kode,jenis,nilai,min_belanja,maks_potongan,untuk,kuota,terpakai,berlaku_sampai,aktif,keterangan)
             VALUES (?,?,?,?,?,?,?,COALESCE((SELECT terpakai FROM voucher WHERE kode=?),0),?,?,?)`
          ).bind(
            kode, b.jenis || 'persen', Number(b.nilai) || 0, Number(b.min_belanja) || 0,
            Number(b.maks_potongan) || 0, b.untuk || 'semua', Number(b.kuota) || 0, kode,
            b.berlaku_sampai || null, b.aktif === false ? 0 : 1, b.keterangan || '',
          ).run();

          ctx.waitUntil(catatAdmin(env, admin, 'buat voucher', kode));
          return json({ ok: true, kode }, 201, env);
        }

        if (a.startsWith('voucher/') && req.method === 'DELETE') {
          const kode = decodeURIComponent(a.split('/')[1]);
          await env.DB.prepare('DELETE FROM voucher WHERE kode = ?').bind(kode).run();
          ctx.waitUntil(catatAdmin(env, admin, 'hapus voucher', kode));
          return json({ ok: true }, 200, env);
        }

        // ---- kunci admin dan peran ----
        if (a === 'peran' && req.method === 'GET') {
          if (admin.peran !== 'pemilik') return err('Hanya pemilik yang boleh membuka bagian ini', 403, env);
          const { results } = await env.DB.prepare('SELECT * FROM admin_kunci ORDER BY dibuat DESC').all();
          return json(results, 200, env);
        }

        if (a === 'peran' && req.method === 'POST') {
          if (admin.peran !== 'pemilik') return err('Hanya pemilik yang boleh menambah admin', 403, env);
          const b = await req.json();
          const kunci = `xya_${crypto.randomUUID().replace(/-/g, '')}`;
          const id = uid('ak_');
          await env.DB.prepare('INSERT INTO admin_kunci (id,nama,kunci,peran) VALUES (?,?,?,?)')
            .bind(id, b.nama || 'Admin baru', kunci, b.peran || 'cs').run();
          ctx.waitUntil(catatAdmin(env, admin, 'tambah admin', `${b.nama} (${b.peran})`));
          return json({ id, kunci, peran: b.peran || 'cs' }, 201, env);
        }

        if (a.startsWith('peran/') && req.method === 'DELETE') {
          if (admin.peran !== 'pemilik') return err('Hanya pemilik yang boleh menghapus admin', 403, env);
          const idA = a.split('/')[1];
          await env.DB.prepare('DELETE FROM admin_kunci WHERE id = ?').bind(idA).run();
          ctx.waitUntil(catatAdmin(env, admin, 'hapus admin', idA));
          return json({ ok: true }, 200, env);
        }

        if (a === 'log' && req.method === 'GET') {
          const { results } = await env.DB
            .prepare('SELECT * FROM log_admin ORDER BY waktu DESC LIMIT 120').all();
          return json(results, 200, env);
        }

        // ---- cadangan basis data ----
        if (a === 'cadangan' && req.method === 'GET') {
          const { results } = await env.DB
            .prepare('SELECT id, ukuran, jumlah_baris, dibuat FROM cadangan ORDER BY dibuat DESC').all();
          return json(results, 200, env);
        }

        if (a === 'cadangan' && req.method === 'POST') {
          const hasil = await buatCadangan(env);
          ctx.waitUntil(catatAdmin(env, admin, 'buat cadangan', hasil.id));
          return json(hasil, 201, env);
        }

        if (a.startsWith('cadangan/') && req.method === 'GET') {
          const idB = a.split('/')[1];
          const baris = await env.DB.prepare('SELECT isi FROM cadangan WHERE id = ?').bind(idB).first();
          if (!baris) return err('Cadangan tidak ditemukan', 404, env);
          return new Response(baris.isi, {
            headers: {
              'Content-Type': 'application/json',
              'Content-Disposition': `attachment; filename="xycloudstore-${idB}.json"`,
            },
          });
        }

        // ---- atur versi minimal aplikasi ----
        if (a === 'sistem/versi' && req.method === 'POST') {
          const b = await req.json().catch(() => ({}));
          await simpanSetelan(env, 'versi_minimal', String(b.versi || ''));
          ctx.waitUntil(catatAdmin(env, admin, 'atur versi minimal', b.versi));
          return json({ ok: true, versi: b.versi }, 200, env);
        }

        // ---- statistik lengkap ----
        if (a === 'statistik' && req.method === 'GET') {
          return json(await statistikLengkap(env), 200, env);
        }

        // ---- mode pemeliharaan ----
        // Pengaman: setiap kali dinyalakan, waktu mulai dan batas "sampai" ikut
        // dicatat. Pemeliharaan otomatis (sistem.js) akan mematikannya sendiri
        // kalau lewat batas itu, supaya layanan tidak terkunci diam-diam saat
        // operator atau agen AI error setelah menyalakannya.
        // - b.sampai      : ISO absolut kapan harus mati (opsional)
        // - b.maks_menit  : berapa menit boleh menyala, bawaan 720 (12 jam);
        //                   0 = tanpa batas (tidak pernah auto-mati)
        if (a === 'sistem/pemeliharaan' && req.method === 'POST') {
          const b = await req.json().catch(() => ({}));
          const aktif = Boolean(b.aktif);
          // cakupan yang boleh: 'semua' | 'web' | 'aplikasi'
          let cakupan = String(b.cakupan || 'semua').toLowerCase();
          if (!CAKUPAN_PEMELIHARAAN.includes(cakupan)) cakupan = 'semua';
          if (aktif) {
            const kini = Date.now();
            const maks = Number(b.maks_menit ?? (await setelan(env, 'pemeliharaan_maks_menit', '720')));
            const menit = Math.max(0, Math.floor(Number.isFinite(maks) ? maks : 720));
            await simpanSetelan(env, 'mode_pemeliharaan_mulai', new Date(kini).toISOString());
            await simpanSetelan(env, 'pemeliharaan_maks_menit', String(menit));
            const sampai = b.sampai
              ? String(b.sampai)
              : new Date(kini + (menit > 0 ? menit * 60000 : 0)).toISOString();
            await simpanSetelan(env, 'mode_pemeliharaan_sampai', menit > 0 ? sampai : '');
          } else {
            await simpanSetelan(env, 'mode_pemeliharaan_mulai', '');
            await simpanSetelan(env, 'mode_pemeliharaan_sampai', '');
            cakupan = String(b.cakupan || 'semua').toLowerCase();
            if (!CAKUPAN_PEMELIHARAAN.includes(cakupan)) cakupan = 'semua';
          }
          await simpanSetelan(env, 'mode_pemeliharaan', aktif ? '1' : '0');
          await simpanSetelan(env, 'pemeliharaan_cakupan', cakupan);
          if (b.pesan) await simpanSetelan(env, 'pesan_pemeliharaan', String(b.pesan));
          const sampai = aktif ? await setelan(env, 'mode_pemeliharaan_sampai', '') : '';
          const label = { semua: 'semua (web + aplikasi)', web: 'hanya situs web', aplikasi: 'hanya aplikasi Android' }[cakupan];
          ctx.waitUntil(catatLog(env, 'pemeliharaan',
            aktif
              ? `Mode pemeliharaan dinyalakan untuk ${label}${sampai ? ` (auto-mati ${sampai})` : ' (tanpa batas)'}`
              : 'Mode pemeliharaan dimatikan'));
          return json({ ok: true, aktif, cakupan, sampai: aktif ? (sampai || null) : null }, 200, env);
        }

        // ---- jalankan pemeliharaan sekarang ----
        if (a === 'sistem/bersihkan' && req.method === 'POST') {
          return json(await jalankanPemeliharaan(env), 200, env);
        }

        // ---- kosongkan singgahan tepi ----
        if (a === 'sistem/cache' && req.method === 'DELETE') {
          const cache = caches.default;
          const dasar = env.PUBLIC_URL || 'https://api.xycloud.my.id';
          const dibuang = [];
          for (const jalur of ['/__cache/rilis', '/', '/unduh']) {
            const ok = await cache.delete(new Request(`https://xycloud.my.id${jalur}`));
            if (ok) dibuang.push(jalur);
          }
          await cache.delete(new Request(`${dasar}/brand/logo.png`));
          ctx.waitUntil(catatLog(env, 'cache', `Singgahan dikosongkan: ${dibuang.join(', ') || 'tidak ada'}`));
          return json({ ok: true, dibuang }, 200, env);
        }

        // ---- kesehatan layanan ----
        if (a === 'sistem/kesehatan' && req.method === 'GET') {
          const mulai = Date.now();
          let dbOk = true;
          try {
            await env.DB.prepare('SELECT 1').first();
          } catch (_) {
            dbOk = false;
          }
          const jedaDb = Date.now() - mulai;

          const ukuran = await env.DB.prepare(
            `SELECT (SELECT COUNT(*) FROM users) users, (SELECT COUNT(*) FROM orders) orders,
                    (SELECT COUNT(*) FROM cs_messages) pesan, (SELECT COUNT(*) FROM forum_post) forum,
                    (SELECT COUNT(*) FROM log_sistem) log`
          ).first().catch(() => ({}));

          return json({
            database: { hidup: dbOk, jedaMs: jedaDb, baris: ukuran },
            email: Boolean(env.RESEND_API_KEY),
            push: Boolean(env.ONESIGNAL_API_KEY),
            gambar: Boolean(env.CLOUDINARY_KEY),
            pembayaran: penyediaBayar(env),
            loginGoogle: Boolean(env.GOOGLE_CLIENT_ID),
            wilayah: req.cf?.colo || '-',
            waktu: new Date().toISOString(),
          }, 200, env);
        }

        // ---- catat rilis aplikasi baru (dipanggil alur build) ----
        if (a === 'rilis' && req.method === 'POST') {
          const b = await req.json();
          if (!b.versi || !Array.isArray(b.berkas)) return err('Data rilis tidak lengkap', 400, env);
          const hasil = await simpanRilis(env, b);
          return json(hasil, 201, env);
        }

        // ---- unit / agen PC host ----
        if (a === 'agen' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM agen ORDER BY dibuat DESC').all();
          const sekarang = Date.now();
          return json(results.map((r) => ({
            ...r,
            spec: r.spec ? JSON.parse(r.spec) : {},
            // dianggap mati kalau tidak melapor lebih dari 90 detik
            hidup: r.terakhir ? sekarang - new Date(r.terakhir).getTime() < 90000 : false,
          })), 200, env);
        }

        if (a === 'agen' && req.method === 'POST') {
          const b = await req.json();
          const id = b.id || uid('ag_');
          const kode = b.kode || `xya_${crypto.randomUUID().replace(/-/g, '')}`;
          await env.DB.prepare(
            'INSERT OR REPLACE INTO agen (id,nama,kode,plan_id,host,status,dibuat) VALUES (?,?,?,?,?,?,COALESCE((SELECT dibuat FROM agen WHERE id=?),datetime(\'now\')))'
          ).bind(id, b.nama || 'Unit baru', kode, b.plan_id || null, b.host || null, 'offline', id).run();
          return json({ id, kode }, 201, env);
        }

        if (a.startsWith('agen/') && req.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM agen WHERE id = ?').bind(a.split('/')[1]).run();
          return json({ ok: true }, 200, env);
        }

        if (a === 'sesi' && req.method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT s.*, u.nama, u.email, a.nama AS unit FROM sesi s
             LEFT JOIN users u ON u.id = s.user_id
             LEFT JOIN agen a ON a.id = s.agen_id
             ORDER BY s.dibuat DESC LIMIT 100`
          ).all();
          return json(results, 200, env);
        }

        // ---- forum: moderasi ----
        // buat pengumuman resmi dari admin
        if (a === 'forum' && req.method === 'POST') {
          const b = await req.json().catch(() => ({}));
          const judul = String(b.judul || '').trim();
          const isi = String(b.isi || '').trim();
          if (judul.length < 5 || isi.length < 10) return err('Judul dan isi pengumuman terlalu pendek', 400, env);

          let gambar = null;
          if (b.gambar && String(b.gambar).startsWith('data:')) {
            const hasil = await unggahGambar(env, { dataUri: b.gambar, folder: 'xycloudstore/forum' });
            if (!hasil.ok) return err(hasil.alasan, 502, env);
            gambar = hasil.url;
          }

          const post = {
            id: uid('f_'), user_id: 'admin', nama: 'Kirana - XyCloudStore', foto: null,
            kategori: b.kategori || 'Pengumuman', judul, isi, gambar,
            suka: 0, balasan: 0, disematkan: b.sematkan === false ? 0 : 1,
            dibuat: new Date().toISOString(),
          };
          await env.DB.prepare(
            'INSERT INTO forum_post (id,user_id,nama,foto,kategori,judul,isi,gambar,disematkan,dibuat) VALUES (?,?,?,?,?,?,?,?,?,?)'
          ).bind(post.id, 'admin', post.nama, null, post.kategori, judul, isi, gambar, post.disematkan, post.dibuat).run();

          ctx.waitUntil(push(env, 'forum', 'forum.baru', post));

          if (b.kirimPush !== false) {
            ctx.waitUntil(siarkanPush(env, {
              judul: `Pengumuman: ${judul.slice(0, 50)}`,
              pesan: isi.length > 110 ? `${isi.slice(0, 110)}...` : isi,
              data: { tipe: 'forum', id: post.id },
            }));
          }

          return json(post, 201, env);
        }

        if (a === 'forum' && req.method === 'GET') {
          const { results } = await env.DB
            .prepare('SELECT * FROM forum_post ORDER BY disematkan DESC, dibuat DESC LIMIT 200').all();
          return json(results, 200, env);
        }

        if (a.startsWith('forum/') && a.endsWith('/balas') && req.method === 'POST') {
          const id = a.split('/')[1];
          const { isi } = await req.json();
          const baris = {
            id: uid('fb_'), post_id: id, user_id: 'admin', nama: 'Kirana - XyCloudStore',
            foto: null, isi: String(isi || '').trim(), admin: 1, dibuat: new Date().toISOString(),
          };
          await env.DB.batch([
            env.DB.prepare('INSERT INTO forum_balasan (id,post_id,user_id,nama,foto,isi,admin,dibuat) VALUES (?,?,?,?,?,?,1,?)')
              .bind(baris.id, id, 'admin', baris.nama, null, baris.isi, baris.dibuat),
            env.DB.prepare('UPDATE forum_post SET balasan = balasan + 1 WHERE id = ?').bind(id),
          ]);
          ctx.waitUntil(push(env, 'forum', 'forum.balasan', baris));

          ctx.waitUntil((async () => {
            const p2 = await env.DB.prepare('SELECT user_id, judul FROM forum_post WHERE id = ?').bind(id).first();
            const { results } = await env.DB
              .prepare('SELECT DISTINCT user_id FROM forum_balasan WHERE post_id = ? AND user_id != ?')
              .bind(id, 'admin').all();
            const cuplikan = (baris.isi || 'Mengirim stiker').slice(0, 90);
            const tujuan = [...new Set([p2?.user_id, ...results.map((r) => r.user_id)].filter(Boolean))];
            for (const uid2 of tujuan) {
              await buatNotif(env, ctx, {
                userId: uid2,
                jenis: 'balasan',
                judul: 'Kirana membalas diskusi',
                pesan: `"${(p2?.judul || '').slice(0, 50)}": ${cuplikan}`,
                aktor: 'Kirana',
                refJenis: 'forum',
                refId: id,
              });
            }
          })());

          return json(baris, 201, env);
        }

        if (a.startsWith('forum/') && a.endsWith('/sematkan') && req.method === 'PATCH') {
          const id = a.split('/')[1];
          const { disematkan } = await req.json();
          await env.DB.prepare('UPDATE forum_post SET disematkan = ? WHERE id = ?')
            .bind(disematkan ? 1 : 0, id).run();
          return json({ ok: true }, 200, env);
        }

        if (a.startsWith('forum/') && req.method === 'DELETE') {
          const id = a.split('/')[1];
          await env.DB.batch([
            env.DB.prepare('DELETE FROM forum_balasan WHERE post_id = ?').bind(id),
            env.DB.prepare('DELETE FROM forum_suka WHERE post_id = ?').bind(id),
            env.DB.prepare('DELETE FROM forum_post WHERE id = ?').bind(id),
          ]);
          ctx.waitUntil(push(env, 'forum', 'forum.hapus', { id }));
          return json({ ok: true }, 200, env);
        }

        // ---- uji email dan push ----
        if (a === 'uji/email' && req.method === 'POST') {
          const { to } = await req.json();
          const hasil = await kirimEmail(env, {
            to, template: 'verifikasi', data: { nama: 'Admin', kode: '123456' },
          });
          return json(hasil, hasil.ok ? 200 : 502, env);
        }
        if (a === 'uji/push' && req.method === 'POST') {
          const { user_id, pesan } = await req.json();
          const hasil = await kirimPush(env, {
            userId: user_id, judul: 'Uji notifikasi', pesan: pesan || 'Halo dari XyCloudStore',
          });
          return json(hasil, hasil.ok ? 200 : 502, env);
        }

        return err('Endpoint admin tidak dikenal', 404, env);
      }

      // ---- ulasan sebuah produk ----
      if (p.startsWith('akun/produk/') && p.endsWith('/ulasan') && req.method === 'GET') {
        const pid = p.split('/')[2];
        const { results } = await env.DB
          .prepare('SELECT * FROM ulasan WHERE produk_id = ? ORDER BY waktu DESC LIMIT 100').bind(pid).all();
        return json(results.map((r) => ({ ...r, gambar: samarkanGambar(env, r.gambar, 'm') })), 200, env);
      }

      if (p === 'akun/produk' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM akun_produk').all();
        return json(
          results.map((r) => ({
            ...r,
            fitur: JSON.parse(r.fitur || '[]'),
            gambar: samarkanGambar(env, r.gambar, 'm'),
          })),
          200,
          env,
        );
      }

      // ---------------- butuh login ----------------
      const me = await auth(req, env);
      if (!me) return err('Unauthorized', 401, env);
      const room = `user:${me.sub}`;

      // akun yang diblokir hanya boleh membaca pemberitahuan dan menghubungi admin
      const statusAkun = await env.DB.prepare('SELECT diblokir, alasan_blokir,deleted_at FROM users WHERE id = ?')
        .bind(me.sub).first();
      if (!statusAkun || statusAkun.deleted_at) return err('Sesi berakhir. Silakan masuk kembali.', 401, env);
      if (statusAkun?.diblokir === 1 && !p.startsWith('cs/') && !p.startsWith('notifikasi') && p !== 'me') {
        return err(
          statusAkun.alasan_blokir
            ? `Akunmu sedang dibekukan. Alasan: ${statusAkun.alasan_blokir}`
            : 'Akunmu sedang dibekukan. Hubungi admin lewat menu chat.',
          403, env,
        );
      }

      if (p === 'stiker/giphy' && req.method === 'GET') {
        if (!(await bolehLanjut(env, `giphy:${me.sub}`, 30, 60))) return err('Terlalu banyak pencarian. Tunggu sebentar.', 429, env);
        return json(await cariGiphy(env, url.searchParams), 200, env);
      }
      if (p === 'stiker/impor' && req.method === 'POST') {
        if (!(await bolehLanjut(env, `stiker:${me.sub}`, 30, 3600))) return err('Batas impor stiker tercapai. Coba lagi nanti.', 429, env);
        return json(await terimaStiker(env, await req.json()), 201, env);
      }

      if(p==='me/notifikasi/tes'&&req.method==='POST'){
        if(!(await bolehLanjut(env,`push-test:${me.sub}`,3,3600)))return err('Tes notifikasi maksimal 3 kali per jam.',429,env);
        const result=await kirimPush(env,{userId:me.sub,judul:'Tes notifikasi XyCloudStore',pesan:'Jika pesan ini terdengar, pengaturan nada Android sudah diterapkan.',data:{tipe:'sistem'}});
        if(!result.ok)return err('Push belum diterima penyedia. Periksa izin perangkat dan konfigurasi OneSignal/FCM.',502,env);
        return json({ok:true,pesan:'Permintaan dikirim ke penyedia push. Periksa pemberitahuan HP.'},200,env);
      }

      // ---- profil pengguna yang sedang login ----
      if (p === 'me' && req.method === 'GET') {
        const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(me.sub).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);
        delete u.password;
        return json(u, 200, env);
      }

      // Session ownership and real physical host allocation are enforced server-side.
      if(p==='sesi/mulai' && req.method==='POST') {
        const b=await req.json();return json(await mulaiSewa(env,me.sub,String(b.order_id||'')),201,env);
      }
      if(p.startsWith('sesi/') && p.split('/').length===2 && req.method==='GET') return json(await bacaSewa(env,me.sub,p.split('/')[1]),200,env);
      if(p.startsWith('sesi/') && p.endsWith('/pin') && req.method==='POST') {
        const {pin,client_id:clientId}=await req.json();if(!/^[0-9]{4}$/.test(String(pin||'')))return err('PIN harus 4 angka',400,env);
        const session=await bacaSewa(env,me.sub,p.split('/')[1]);
        if(!['siap','pairing','berjalan'].includes(session.status))return err('Sesi tidak menerima pairing',409,env);
        if(!(await bolehLanjut(env,`pair:${session.id}`,6,300)))return err('Terlalu banyak percobaan pairing',429,env);
        await env.DB.batch([
          env.DB.prepare("UPDATE sesi SET status='pairing',pin=? WHERE id=?").bind(String(pin),session.id),
          env.DB.prepare("INSERT INTO perintah(id,agen_id,jenis,muatan) VALUES(?,?,'pasangkan',?)").bind(uid('c_'),session.agen_id,JSON.stringify({sesi_id:session.id,pin:String(pin),client_id:typeof clientId==='string'&&/^[a-f0-9]{16}$/i.test(clientId)?clientId:null})),
        ]);
        return json({ok:true},200,env);
      }
      if(p.startsWith('sesi/') && p.endsWith('/stream') && req.method==='POST') {
        const session=await bacaSewa(env,me.sub,p.split('/')[1]);
        if(!['siap','pairing','berjalan'].includes(session.status))return err('Sesi sudah berakhir',409,env);
        await env.DB.prepare("UPDATE sesi SET status='berjalan',catatan='Klien melaporkan koneksi video aktif' WHERE id=?").bind(session.id).run();
        return json({ok:true},200,env);
      }
      if(p.startsWith('sesi/') && p.endsWith('/akhiri') && req.method==='POST') {
        const session=await bacaSewa(env,me.sub,p.split('/')[1]);return json(await antreAkhir(env,session),200,env);
      }

      // ---- kode referral milikku ----
      if (p === 'referral' && req.method === 'GET') {
        let u = await env.DB.prepare('SELECT kode_referral, nama FROM users WHERE id = ?').bind(me.sub).first();

        if (!u?.kode_referral) {
          // buat kode dari nama, ditambah angka acak supaya unik
          const dasar = (u?.nama || 'XY').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5) || 'XYUSER';
          let kode = '';
          for (let coba = 0; coba < 5; coba++) {
            const acak = String(crypto.getRandomValues(new Uint32Array(1))[0] % 10000).padStart(4, '0');
            const calon = `${dasar}${acak}`;
            const bentrok = await env.DB.prepare('SELECT 1 FROM users WHERE kode_referral = ?').bind(calon).first();
            if (!bentrok) {
              kode = calon;
              break;
            }
          }
          await env.DB.prepare('UPDATE users SET kode_referral = ? WHERE id = ?').bind(kode, me.sub).run();
          u = { kode_referral: kode };
        }

        const { results } = await env.DB.prepare(
          `SELECT r.*, u.nama AS nama_diundang FROM referral r
           LEFT JOIN users u ON u.id = r.diundang
           WHERE r.pengundang = ? ORDER BY r.dibuat DESC LIMIT 50`
        ).bind(me.sub).all();

        const total = results.filter((r) => r.status === 'selesai')
          .reduce((a, r) => a + (r.bonus_pengundang || 0), 0);

        return json({
          kode: u.kode_referral,
          tautan: `${env.WEB_URL || 'https://xycloud.my.id'}/unduh?ref=${u.kode_referral}`,
          bonusPengundang: Number(env.BONUS_REFERRAL || 10000),
          bonusDiundang: Number(env.BONUS_DIUNDANG || 5000),
          totalBonus: total,
          daftar: results,
        }, 200, env);
      }

      // ---- pakai kode referral orang lain ----
      if (p === 'referral/pakai' && req.method === 'POST') {
        const { kode } = await req.json().catch(() => ({}));
        const k = String(kode || '').trim().toUpperCase();
        if (!k) return err('Kode referral kosong', 400, env);

        const aku = await env.DB.prepare('SELECT diundang_oleh, created_at FROM users WHERE id = ?')
          .bind(me.sub).first();
        if (aku?.diundang_oleh) return err('Kamu sudah pernah memakai kode referral', 409, env);

        const pengundang = await env.DB.prepare('SELECT id, nama FROM users WHERE kode_referral = ?')
          .bind(k).first();
        if (!pengundang) return err('Kode referral tidak ditemukan', 404, env);
        if (pengundang.id === me.sub) return err('Tidak bisa memakai kodemu sendiri', 400, env);

        const bonusA = Number(env.BONUS_REFERRAL || 10000);
        const bonusB = Number(env.BONUS_DIUNDANG || 5000);

        await env.DB.batch([
          env.DB.prepare('UPDATE users SET diundang_oleh = ? WHERE id = ?').bind(pengundang.id, me.sub),
          env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(bonusA, pengundang.id),
          env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(bonusB, me.sub),
          env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
            .bind(uid('t_'), pengundang.id, 'Bonus mengundang teman', 'topup', bonusA),
          env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
            .bind(uid('t_'), me.sub, 'Bonus memakai kode referral', 'topup', bonusB),
          env.DB.prepare(
            "INSERT INTO referral (id,pengundang,diundang,bonus_pengundang,bonus_diundang,status,selesai) VALUES (?,?,?,?,?,'selesai',?)"
          ).bind(uid('rf_'), pengundang.id, me.sub, bonusA, bonusB, new Date().toISOString()),
        ]);

        ctx.waitUntil(buatNotif(env, ctx, {
          userId: pengundang.id,
          jenis: 'wallet',
          judul: 'Bonus referral masuk',
          pesan: `Temanmu memakai kodemu. Saldo bertambah Rp${bonusA.toLocaleString('id-ID')}.`,
          aktor: 'XyCloudStore',
        }));

        const saldoBaru = await env.DB.prepare('SELECT saldo FROM users WHERE id = ?').bind(me.sub).first();
        ctx.waitUntil(push(env, room, 'wallet.update', { saldo: saldoBaru?.saldo ?? 0 }));

        return json({
          ok: true,
          bonus: bonusB,
          pengundang: pengundang.nama,
          saldo: saldoBaru?.saldo ?? 0,
        }, 200, env);
      }

      // ---- favorit produk ----
      if (p === 'favorit' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT produk_id FROM favorit WHERE user_id = ?')
          .bind(me.sub).all();
        return json(results.map((r) => r.produk_id), 200, env);
      }

      if (p.startsWith('favorit/') && req.method === 'POST') {
        const produkId = p.split('/')[1];
        const ada = await env.DB.prepare('SELECT 1 FROM favorit WHERE user_id = ? AND produk_id = ?')
          .bind(me.sub, produkId).first();
        if (ada) {
          await env.DB.prepare('DELETE FROM favorit WHERE user_id = ? AND produk_id = ?')
            .bind(me.sub, produkId).run();
          return json({ favorit: false }, 200, env);
        }
        await env.DB.prepare('INSERT INTO favorit (user_id,produk_id) VALUES (?,?)')
          .bind(me.sub, produkId).run();
        return json({ favorit: true }, 200, env);
      }

      // ---- ulasan paket PC ----
      if (p === 'pc/ulasan' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        const nilai = Math.max(1, Math.min(5, Number(b.rating) || 5));
        const planId = String(b.plan_id || '');

        const pernah = await env.DB.prepare(
          "SELECT 1 FROM orders WHERE user_id = ? AND plan_id = ? AND status IN ('aktif','selesai') LIMIT 1"
        ).bind(me.sub, planId).first();
        if (!pernah) return err('Kamu bisa menilai paket setelah pernah menyewanya', 403, env);

        const sudah = await env.DB.prepare('SELECT id FROM ulasan_pc WHERE plan_id = ? AND user_id = ?')
          .bind(planId, me.sub).first();
        if (sudah) return err('Kamu sudah menilai paket ini', 409, env);

        const u = await env.DB.prepare('SELECT nama FROM users WHERE id = ?').bind(me.sub).first();
        const baris = {
          id: uid('rp_'), plan_id: planId, order_id: b.order_id || null, user_id: me.sub,
          nama: u?.nama || 'Pengguna', rating: nilai, komentar: String(b.komentar || '').slice(0, 500),
          waktu: new Date().toISOString(),
        };
        await env.DB.prepare(
          'INSERT INTO ulasan_pc (id,plan_id,order_id,user_id,nama,rating,komentar,waktu) VALUES (?,?,?,?,?,?,?,?)'
        ).bind(baris.id, planId, baris.order_id, me.sub, baris.nama, nilai, baris.komentar, baris.waktu).run();

        const agg = await env.DB
          .prepare('SELECT ROUND(AVG(rating),1) r, COUNT(*) n FROM ulasan_pc WHERE plan_id = ?')
          .bind(planId).first();
        await env.DB.prepare('UPDATE pc_plans SET rating = ?, jumlah_ulasan = ? WHERE id = ?')
          .bind(agg?.r || nilai, agg?.n || 1, planId).run();

        ctx.waitUntil(push(env, 'katalog', 'plan.ulasan', { plan_id: planId, rating: agg?.r, jumlah: agg?.n }));
        return json(baris, 201, env);
      }

      // ---- unduh semua dataku ----
      if (p === 'me/data' && req.method === 'GET') {
        const ambil = async (sql) => {
          try {
            const { results } = await env.DB.prepare(sql).bind(me.sub).all();
            return results;
          } catch (_) {
            return [];
          }
        };
        const profil = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(me.sub).first();
        if (profil) delete profil.password;

        const data = {
          diambil: new Date().toISOString(),
          profil,
          pesanan: await ambil('SELECT * FROM orders WHERE user_id = ?'),
          transaksi: await ambil('SELECT * FROM transaksi WHERE user_id = ?'),
          topup: await ambil('SELECT * FROM topup WHERE user_id = ?'),
          percakapan: await ambil('SELECT dari,teks,waktu FROM cs_messages WHERE user_id = ?'),
          diskusi: await ambil('SELECT * FROM forum_post WHERE user_id = ?'),
          balasan: await ambil('SELECT * FROM forum_balasan WHERE user_id = ?'),
          ulasan: await ambil('SELECT * FROM ulasan WHERE user_id = ?'),
          pemberitahuan: await ambil('SELECT * FROM notifikasi WHERE user_id = ?'),
        };
        return json(data, 200, env);
      }

      // ---- periksa voucher sebelum bayar ----
      if (p === 'voucher/cek' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        const hasil = await cekVoucher(env, {
          kode: b.kode,
          userId: me.sub,
          jenis: b.jenis || 'semua',
          total: Number(b.total) || 0,
        });
        if (!hasil.ok) return err(hasil.alasan, 400, env);
        return json({
          potongan: hasil.potongan,
          kode: hasil.voucher.kode,
          keterangan: hasil.voucher.keterangan || '',
        }, 200, env);
      }

      // ---- hapus akun: tindakan eksplisit + autentikasi ulang, saldo tidak dibuang ----
      if (p === 'me/hapus/info' && req.method === 'GET') {
        const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(me.sub).first();
        return json(await infoHapusAkun(env, u), 200, env);
      }
      if (p === 'me/hapus/kode' && req.method === 'POST') {
        if (!(await bolehLanjut(env, `hapus-kode:${me.sub}`, 3, 3600))) return err('Kode sudah diminta beberapa kali. Coba lagi nanti.', 429, env);
        const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(me.sub).first();
        const info = await infoHapusAkun(env, u);
        if (!info.boleh_hapus) return err(info.penghalang.join(' '), 409, env);
        if (!info.perlu_otp) return err('Akun ini menggunakan konfirmasi password.', 400, env);
        const hasil = await kirimOtp(env, { email: u.email, nama: u.nama, tipe: 'hapus_akun' });
        if (!hasil.ok) return err('Email konfirmasi belum terkirim. Coba lagi nanti.', 502, env);
        return json({ ok: true, pesan: 'Kode konfirmasi dikirim ke email akunmu.' }, 200, env);
      }
      if (p === 'me' && req.method === 'DELETE') {
        const b = await req.json().catch(() => ({}));
        if (b.konfirmasi !== 'HAPUS') return err('Konfirmasi penghapusan diperlukan. Gunakan menu Hapus Akun pada aplikasi terbaru.', 400, env);
        if (!(await bolehLanjut(env, `hapus-akun:${me.sub}`, 5, 900))) return err('Terlalu banyak percobaan. Tunggu 15 menit.', 429, env);
        const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(me.sub).first();
        const info = await infoHapusAkun(env, u);
        if (!info.boleh_hapus) return err(info.penghalang.join(' '), 409, env);
        if (info.perlu_otp) {
          const cek = await cekOtp(env, { email: u.email, kode: b.kode || '', tipe: 'hapus_akun' });
          if (!cek.ok) return err(cek.pesan, 401, env);
        } else if (!(await cocokPw(String(b.password || ''), u.password))) {
          return err('Password salah. Akun tidak dihapus.', 401, env);
        }
        await bersihkanAkun(env, u);
        ctx.waitUntil(catatLog(env, 'akun', 'Penghapusan akun atas permintaan pemilik selesai.'));
        ctx.waitUntil(push(env, 'forum', 'forum.refresh', {}));
        return json({ ok: true, pesan: 'Akun dihapus. Data pembukuan disimpan tanpa identitas akun.' }, 200, env);
      }

      // ---- daftar pemberitahuan ----
      if (p === 'notifikasi' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM notifikasi WHERE user_id = ? ORDER BY dibuat DESC LIMIT 80')
          .bind(me.sub).all();
        const belum = await env.DB
          .prepare('SELECT COUNT(*) n FROM notifikasi WHERE user_id = ? AND dibaca = 0').bind(me.sub).first();
        return json({ daftar: results, belumDibaca: belum?.n ?? 0 }, 200, env);
      }

      // ---- tandai sudah dibaca ----
      if (p === 'notifikasi/baca' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        if (b.id) {
          await env.DB.prepare('UPDATE notifikasi SET dibaca = 1 WHERE id = ? AND user_id = ?')
            .bind(b.id, me.sub).run();
        } else {
          await env.DB.prepare('UPDATE notifikasi SET dibaca = 1 WHERE user_id = ?').bind(me.sub).run();
        }
        return json({ ok: true }, 200, env);
      }

      // ---- hapus semua pemberitahuan ----
      if (p === 'notifikasi' && req.method === 'DELETE') {
        await env.DB.prepare('DELETE FROM notifikasi WHERE user_id = ?').bind(me.sub).run();
        return json({ ok: true }, 200, env);
      }

      // ---- suka pada balasan ----
      if (p.startsWith('forum/balasan/') && p.endsWith('/suka') && req.method === 'POST') {
        const id = p.split('/')[2];
        const b = await env.DB.prepare('SELECT * FROM forum_balasan WHERE id = ?').bind(id).first();
        if (!b) return err('Balasan tidak ditemukan', 404, env);

        const ada = await env.DB.prepare('SELECT 1 FROM forum_balasan_suka WHERE balasan_id = ? AND user_id = ?')
          .bind(id, me.sub).first();

        if (ada) {
          await env.DB.batch([
            env.DB.prepare('DELETE FROM forum_balasan_suka WHERE balasan_id = ? AND user_id = ?').bind(id, me.sub),
            env.DB.prepare('UPDATE forum_balasan SET suka = MAX(0, suka - 1) WHERE id = ?').bind(id),
          ]);
        } else {
          await env.DB.batch([
            env.DB.prepare('INSERT INTO forum_balasan_suka (balasan_id,user_id) VALUES (?,?)').bind(id, me.sub),
            env.DB.prepare('UPDATE forum_balasan SET suka = suka + 1 WHERE id = ?').bind(id),
          ]);

          if (b.user_id !== me.sub) {
            const aku = await env.DB.prepare('SELECT nama FROM users WHERE id = ?').bind(me.sub).first();
            const post = await env.DB.prepare('SELECT judul FROM forum_post WHERE id = ?').bind(b.post_id).first();
            ctx.waitUntil(buatNotif(env, ctx, {
              userId: b.user_id,
              jenis: 'suka',
              judul: `${aku?.nama || 'Seseorang'} menyukai komentarmu`,
              pesan: `Pada diskusi "${(post?.judul || '').slice(0, 60)}"`,
              aktor: aku?.nama || 'Pengguna',
              refJenis: 'forum',
              refId: b.post_id,
            }));
          }
        }

        const baru = await env.DB.prepare('SELECT suka FROM forum_balasan WHERE id = ?').bind(id).first();
        ctx.waitUntil(push(env, 'forum', 'forum.balasan.suka', { id, suka: baru?.suka ?? 0 }));
        return json({ suka: baru?.suka ?? 0, disukai: !ada }, 200, env);
      }

      // ---- daftar balasan yang kusukai ----
      if (p === 'forum/balasan/suka/saya' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT balasan_id FROM forum_balasan_suka WHERE user_id = ?')
          .bind(me.sub).all();
        return json(results.map((r) => r.balasan_id), 200, env);
      }

      // ---- laporkan konten ----
      if (p === 'laporan' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        if (!b.ref_id) return err('Konten yang dilaporkan tidak jelas', 400, env);
        await env.DB.prepare(
          'INSERT INTO laporan (id,jenis,ref_id,url,pelapor,alasan) VALUES (?,?,?,?,?,?)'
        ).bind(uid('lp_'), b.jenis || 'forum', String(b.ref_id), b.url || null, me.sub, b.alasan || 'Tidak pantas').run();
        ctx.waitUntil(push(env, 'cs:inbox', 'laporan.baru', { ref: b.ref_id, jenis: b.jenis }));
        return json({ ok: true, pesan: 'Terima kasih, laporanmu kami tinjau.' }, 201, env);
      }

      // ---- perbarui profil ----
      if (p === 'me' && req.method === 'PATCH') {
        const b = await req.json().catch(() => ({}));
        const nama = String(b.nama || '').trim();
        const phone = String(b.phone || '').trim();
        if (nama && nama.length < 3) return err('Nama minimal 3 karakter', 400, env);

        let foto = null;
        if (b.foto && String(b.foto).startsWith('data:')) {
          const hasil = await unggahGambar(env, { dataUri: b.foto, folder: 'xycloudstore/profil' });
          if (!hasil.ok) return err(hasil.alasan, 502, env);
          foto = hasil.url;
        } else if (b.foto) {
          foto = String(b.foto);
        }

        const notifForum = b.notif_forum == null ? null : (b.notif_forum ? 1 : 0);

        await env.DB.prepare(
          `UPDATE users SET nama = COALESCE(NULLIF(?,''), nama),
                            phone = COALESCE(NULLIF(?,''), phone),
                            foto = COALESCE(?, foto),
                            notif_forum = COALESCE(?, notif_forum)
           WHERE id = ?`
        ).bind(nama, phone, foto, notifForum, me.sub).run();

        const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(me.sub).first();
        delete u.password;
        ctx.waitUntil(push(env, 'forum', 'forum.profil', { user_id: u.id, nama: u.nama, foto: samarkanGambar(env, u.foto, 's') }));
        return json(u, 200, env);
      }

      if(p==='me/password/kode'&&req.method==='POST'){
        const u=await env.DB.prepare('SELECT email,nama,password FROM users WHERE id=?').bind(me.sub).first();
        if(!String(u.password).startsWith('sosial:'))return err('Gunakan password lama untuk akun ini.',400,env);
        const sent=await kirimOtp(env,{email:u.email,nama:u.nama,tipe:'pasang_password'});
        return sent.ok?json({ok:true},200,env):err(sent.alasan,sent.rateLimited?429:502,env);
      }

      // ---- ganti password ----
      if (p === 'me/password' && req.method === 'POST') {
        const { lama, baru } = await req.json().catch(() => ({}));
        if (String(baru || '').length < 6) return err('Password baru minimal 6 karakter', 400, env);

        const u = await env.DB.prepare('SELECT email,password FROM users WHERE id = ?').bind(me.sub).first();
        const akunSosialSaja = String(u.password || '').startsWith('sosial:');
        if(akunSosialSaja){const cek=await cekOtp(env,{email:u.email,kode:lama,tipe:'pasang_password'});if(!cek.ok)return err('Akun sosial memerlukan kode email yang valid.',401,env);}
        if (!akunSosialSaja && !(await cocokPw(String(lama || ''), u.password))) {
          return err('Password lama salah', 401, env);
        }
        await env.DB.prepare('UPDATE users SET password = ?,session_version=session_version+1 WHERE id = ?')
          .bind(await buatPw(String(baru)), me.sub).run();
        return json({ ok: true }, 200, env);
      }

      // ---- forum: buat diskusi ---- (v3.3: max 5/jam + anti-spam link)
      if (p === 'forum' && req.method === 'POST') {
        if (!rateMem(`forum-mem:${me.sub}`, 5, 3600)) {
          return err('Maks 5 diskusi per jam. Coba lagi nanti.', 429, env);
        }
        if (!(await bolehLanjut(env, `forum:${me.sub}`, 10, 3600))) {
          return err('Kamu sudah membuat cukup banyak diskusi. Coba lagi nanti.', 429, env);
        }
        // v3.3: cek DB 1 jam terakhir (anti bypass memory)
        try {
          const satuJam = new Date(Date.now() - 3600000).toISOString();
          const cnt = await env.DB.prepare('SELECT COUNT(*) as c FROM forum_post WHERE user_id=? AND dibuat>?').bind(me.sub, satuJam).first();
          if ((cnt?.c ?? 0) >= 5) return err('Maks 5 diskusi per jam (DB).', 429, env);
        } catch (_) {}
        const b = await req.json().catch(() => ({}));
        const judul = String(b.judul || '').trim();
        const isi = String(b.isi || '').trim();
        if (judul.length < 5) return err('Judul minimal 5 karakter', 400, env);
        if (isi.length < 10) return err('Isi diskusi minimal 10 karakter', 400, env);
        if ((isi.match(/https?:\/\//g) || []).length > 3) return err('Terlalu banyak link, maks 3.', 400, env);

        let gambar = null;
        if (b.gambar) {
          const hasil = await unggahGambar(env, { dataUri: b.gambar, folder: 'xycloudstore/forum' });
          if (!hasil.ok) return err(hasil.alasan, 502, env);
          gambar = hasil.url;
        }

        const u = await env.DB.prepare('SELECT nama, foto FROM users WHERE id = ?').bind(me.sub).first();
        const post = {
          id: uid('f_'), user_id: me.sub, nama: u?.nama || 'Pengguna', foto: u?.foto || null,
          kategori: String(b.kategori || 'Umum'), judul, isi, gambar,
          suka: 0, balasan: 0, disematkan: 0, dibuat: new Date().toISOString(),
        };
        await env.DB.prepare(
          'INSERT INTO forum_post (id,user_id,nama,foto,kategori,judul,isi,gambar,dibuat) VALUES (?,?,?,?,?,?,?,?,?)'
        ).bind(post.id, post.user_id, post.nama, post.foto, post.kategori, judul, isi, gambar, post.dibuat).run();

        ctx.waitUntil(push(env, 'forum', 'forum.baru', post));
        return json(post, 201, env);
      }

      // ---- forum: balas, teks + stiker berada dalam satu pesan ----
      if (p.startsWith('forum/') && p.endsWith('/balas') && req.method === 'POST') {
        const id = p.split('/')[1];
        if (!(await bolehLanjut(env, `komentar:${me.sub}`, 40, 3600))) return err('Terlalu banyak komentar. Coba lagi nanti.', 429, env);
        const b = await req.json().catch(() => ({}));
        const isi = String(b.isi || '').trim();
        const balasKe = b.balas_ke ? String(b.balas_ke) : null;
        if (!isi && !b.stiker) return err('Tulis pesan atau pilih stiker terlebih dahulu.', 400, env);
        if (isi.length > 4000) return err('Komentar maksimal 4.000 karakter.', 400, env);
        const post = await env.DB.prepare('SELECT id FROM forum_post WHERE id = ?').bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);
        if (balasKe && !(await env.DB.prepare('SELECT id FROM forum_balasan WHERE id = ? AND post_id = ?').bind(balasKe, id).first())) {
          return err('Komentar induk sudah dihapus atau berasal dari diskusi lain.', 400, env);
        }
        const stiker = await terimaStiker(env, b.stiker);
        const u = await env.DB.prepare('SELECT nama, foto FROM users WHERE id = ?').bind(me.sub).first();
        const baris = {
          id: uid('fb_'), post_id: id, user_id: me.sub, nama: u.nama,
          foto: u.foto || null, isi, stiker, admin: 0, balas_ke: balasKe,
          dibuat: new Date().toISOString(),
        };
        await env.DB.batch([
          env.DB.prepare('INSERT INTO forum_balasan (id,post_id,user_id,nama,foto,isi,balas_ke,stiker,dibuat) VALUES (?,?,?,?,?,?,?,?,?)')
            .bind(baris.id, id, me.sub, baris.nama, baris.foto, isi, balasKe, stiker ? JSON.stringify(stiker) : null, baris.dibuat),
          env.DB.prepare('UPDATE forum_post SET balasan = balasan + 1 WHERE id = ?').bind(id),
        ]);
        ctx.waitUntil(push(env, 'forum', 'forum.balasan', baris));

        // pemberitahuan ke pemilik diskusi, pemilik komentar yang dibalas, dan peserta lain
        ctx.waitUntil((async () => {
          const p2 = await env.DB.prepare('SELECT user_id, judul FROM forum_post WHERE id = ?').bind(id).first();
          const { results } = await env.DB
            .prepare('SELECT DISTINCT user_id FROM forum_balasan WHERE post_id = ? AND user_id != ?')
            .bind(id, me.sub).all();

          const judulPendek = (p2?.judul || 'diskusi').slice(0, 50);
          const cuplikan = (baris.isi || 'Mengirim stiker').slice(0, 90);
          const sudah = new Set([me.sub]);

          // yang komentarnya dibalas langsung
          if (balasKe) {
            const induk = await env.DB.prepare('SELECT user_id FROM forum_balasan WHERE id = ?')
              .bind(balasKe).first();
            if (induk?.user_id && induk.user_id !== me.sub) {
              sudah.add(induk.user_id);
              await buatNotif(env, ctx, {
                userId: induk.user_id,
                jenis: 'balasan',
                judul: `${baris.nama} membalas komentarmu`,
                pesan: `Di diskusi "${judulPendek}": ${cuplikan}`,
                aktor: baris.nama,
                refJenis: 'forum',
                refId: id,
              });
            }
          }

          // pemilik diskusi
          if (p2?.user_id && !sudah.has(p2.user_id)) {
            sudah.add(p2.user_id);
            await buatNotif(env, ctx, {
              userId: p2.user_id,
              jenis: 'balasan',
              judul: `${baris.nama} membalas diskusimu`,
              pesan: `"${judulPendek}": ${cuplikan}`,
              aktor: baris.nama,
              refJenis: 'forum',
              refId: id,
            });
          }

          // peserta lain cukup diberi tahu sekali
          for (const r of results) {
            if (!r.user_id || sudah.has(r.user_id)) continue;
            sudah.add(r.user_id);
            await buatNotif(env, ctx, {
              userId: r.user_id,
              jenis: 'komunitas',
              judul: `Balasan baru di diskusi yang kamu ikuti`,
              pesan: `${baris.nama} pada "${judulPendek}"`,
              aktor: baris.nama,
              refJenis: 'forum',
              refId: id,
              kirimPushJuga: false,
            });
          }
        })());

        return json(baris, 201, env);
      }

      // ---- forum: suka / batal suka ----
      if (p.startsWith('forum/') && p.endsWith('/suka') && req.method === 'POST') {
        const id = p.split('/')[1];
        const ada = await env.DB.prepare('SELECT 1 FROM forum_suka WHERE post_id = ? AND user_id = ?')
          .bind(id, me.sub).first();

        if (ada) {
          await env.DB.batch([
            env.DB.prepare('DELETE FROM forum_suka WHERE post_id = ? AND user_id = ?').bind(id, me.sub),
            env.DB.prepare('UPDATE forum_post SET suka = MAX(0, suka - 1) WHERE id = ?').bind(id),
          ]);
        } else {
          await env.DB.batch([
            env.DB.prepare('INSERT INTO forum_suka (post_id,user_id) VALUES (?,?)').bind(id, me.sub),
            env.DB.prepare('UPDATE forum_post SET suka = suka + 1 WHERE id = ?').bind(id),
          ]);
        }

        const post = await env.DB.prepare('SELECT suka FROM forum_post WHERE id = ?').bind(id).first();
        ctx.waitUntil(push(env, 'forum', 'forum.suka', { id, suka: post?.suka ?? 0 }));

        if (!ada) {
          ctx.waitUntil((async () => {
            const p2 = await env.DB.prepare('SELECT user_id, judul FROM forum_post WHERE id = ?').bind(id).first();
            if (!p2 || p2.user_id === me.sub) return;
            const aku = await env.DB.prepare('SELECT nama FROM users WHERE id = ?').bind(me.sub).first();
            await buatNotif(env, ctx, {
              userId: p2.user_id,
              jenis: 'suka',
              judul: `${aku?.nama || 'Seseorang'} menyukai diskusimu`,
              pesan: `"${(p2.judul || '').slice(0, 60)}" kini punya ${post?.suka ?? 1} suka`,
              aktor: aku?.nama || 'Pengguna',
              refJenis: 'forum',
              refId: id,
              // push hanya sesekali supaya tidak berisik
              kirimPushJuga: await bolehLanjut(env, `sukaforum:${id}`, 1, 1800),
            });
          })());
        }

        return json({ suka: post?.suka ?? 0, disukai: !ada }, 200, env);
      }

      // ---- forum: daftar id yang sudah kusukai ----
      if (p === 'forum/suka/saya' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT post_id FROM forum_suka WHERE user_id = ?')
          .bind(me.sub).all();
        return json(results.map((r) => r.post_id), 200, env);
      }

      // ---- forum: sunting diskusi sendiri ----
      if (p.startsWith('forum/') && p.split('/').length === 2 && req.method === 'PATCH') {
        const id = p.split('/')[1];
        const b = await req.json().catch(() => ({}));
        const post = await env.DB.prepare('SELECT user_id FROM forum_post WHERE id = ?').bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);
        if (post.user_id !== me.sub) return err('Kamu hanya bisa menyunting diskusi sendiri', 403, env);

        const judul = String(b.judul || '').trim();
        const isi = String(b.isi || '').trim();
        if (judul.length < 5) return err('Judul minimal 5 karakter', 400, env);
        if (isi.length < 10) return err('Isi diskusi minimal 10 karakter', 400, env);

        await env.DB.prepare('UPDATE forum_post SET judul=?, isi=?, kategori=COALESCE(?,kategori), diubah=? WHERE id=?')
          .bind(judul, isi, b.kategori || null, new Date().toISOString(), id).run();

        const baru = await env.DB.prepare('SELECT * FROM forum_post WHERE id = ?').bind(id).first();
        ctx.waitUntil(push(env, 'forum', 'forum.ubah', baru));
        return json(baru, 200, env);
      }

      // ---- forum: hapus balasan sendiri ----
      if (p.startsWith('forum/balasan/') && req.method === 'DELETE') {
        const id = p.split('/')[2];
        const b = await env.DB.prepare('SELECT * FROM forum_balasan WHERE id = ?').bind(id).first();
        if (!b) return err('Balasan tidak ditemukan', 404, env);
        if (b.user_id !== me.sub) return err('Kamu hanya bisa menghapus balasan sendiri', 403, env);

        await env.DB.batch([
          env.DB.prepare('UPDATE forum_balasan SET balas_ke = ? WHERE balas_ke = ?').bind(b.balas_ke || null, id),
          env.DB.prepare('DELETE FROM forum_balasan_suka WHERE balasan_id = ?').bind(id),
          env.DB.prepare('DELETE FROM forum_balasan WHERE id = ?').bind(id),
          env.DB.prepare('UPDATE forum_post SET balasan = MAX(0, balasan - 1) WHERE id = ?').bind(b.post_id),
        ]);
        ctx.waitUntil(push(env, 'forum', 'forum.balasan.hapus', { id, post_id: b.post_id }));
        return json({ ok: true }, 200, env);
      }

      // ---- forum: hapus diskusi sendiri ----
      if (p.startsWith('forum/') && p.split('/').length === 2 && req.method === 'DELETE') {
        const id = p.split('/')[1];
        const post = await env.DB.prepare('SELECT user_id FROM forum_post WHERE id = ?').bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);
        if (post.user_id !== me.sub) return err('Kamu hanya bisa menghapus diskusi sendiri', 403, env);
        await env.DB.batch([
          env.DB.prepare('DELETE FROM forum_balasan WHERE post_id = ?').bind(id),
          env.DB.prepare('DELETE FROM forum_suka WHERE post_id = ?').bind(id),
          env.DB.prepare('DELETE FROM forum_post WHERE id = ?').bind(id),
        ]);
        ctx.waitUntil(push(env, 'forum', 'forum.hapus', { id }));
        return json({ ok: true }, 200, env);
      }

      // ---- unggah gambar (chat, bukti transfer, foto ulasan) ----
      if (p === 'upload' && req.method === 'POST') {
        const { file, folder } = await req.json();
        const hasil = await unggahGambar(env, { dataUri: file, folder: folder || 'xycloudstore/pengguna' });
        return hasil.ok ? json(hasil, 201, env) : err(hasil.alasan, 502, env);
      }

      // ---- tulis ulasan produk ----
      if (p === 'ulasan' && req.method === 'POST') {
        const { produk_id, rating, komentar, gambar } = await req.json();
        const nilai = Math.max(1, Math.min(5, Number(rating) || 5));
        const prod = await env.DB.prepare('SELECT id FROM akun_produk WHERE id = ?').bind(produk_id).first();
        if (!prod) return err('Produk tidak ditemukan', 404, env);

        const sudah = await env.DB.prepare('SELECT id FROM ulasan WHERE produk_id = ? AND user_id = ?')
          .bind(produk_id, me.sub).first();
        if (sudah) return err('Kamu sudah menulis ulasan untuk produk ini', 409, env);

        const u = await env.DB.prepare('SELECT nama FROM users WHERE id = ?').bind(me.sub).first();
        const baris = {
          id: uid('r_'), produk_id, user_id: me.sub, nama: u?.nama || 'Pengguna',
          rating: nilai, komentar: komentar || '', gambar: gambar || null,
          waktu: new Date().toISOString(),
        };
        await env.DB.prepare(
          'INSERT INTO ulasan (id,produk_id,user_id,nama,rating,komentar,gambar,waktu) VALUES (?,?,?,?,?,?,?,?)'
        ).bind(baris.id, produk_id, me.sub, baris.nama, nilai, baris.komentar, baris.gambar, baris.waktu).run();

        // segarkan rata-rata rating produk
        const agg = await env.DB
          .prepare('SELECT ROUND(AVG(rating),1) AS r, COUNT(*) AS n FROM ulasan WHERE produk_id = ?')
          .bind(produk_id).first();
        await env.DB.prepare('UPDATE akun_produk SET rating = ?, jumlah_ulasan = ? WHERE id = ?')
          .bind(agg.r || nilai, agg.n || 1, produk_id).run();

        ctx.waitUntil(push(env, 'katalog', 'ulasan.baru', { produk_id, rating: agg.r, jumlah: agg.n }));
        return json(baris, 201, env);
      }

      // ---- daftar permintaan top up milik sendiri ----
      if (p === 'wallet/topup' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM topup WHERE user_id = ? ORDER BY dibuat DESC LIMIT 50').bind(me.sub).all();
        return json(results, 200, env);
      }

      // ---- unggah bukti transfer ----
      if (p.startsWith('wallet/topup/') && p.endsWith('/bukti') && req.method === 'POST') {
        const id = p.split('/')[2];
        const { file } = await req.json();
        const t = await env.DB.prepare('SELECT * FROM topup WHERE id = ? AND user_id = ?').bind(id, me.sub).first();
        if (!t) return err('Permintaan top up tidak ditemukan', 404, env);

        const hasil = await unggahGambar(env, { dataUri: file, folder: 'xycloudstore/bukti' });
        if (!hasil.ok) return err(hasil.alasan, 502, env);

        await env.DB.prepare("UPDATE topup SET bukti = ?, status = 'diperiksa' WHERE id = ?")
          .bind(hasil.url, id).run();
        ctx.waitUntil(push(env, 'cs:inbox', 'topup.baru', { id, user_id: me.sub, nominal: t.nominal, bukti: hasil.url }));
        return json({ ...t, bukti: hasil.url, status: 'diperiksa' }, 200, env);
      }

      // ---- daftar order ----
      if (p === 'orders' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY dibuat DESC').bind(me.sub).all();
        return json(results, 200, env);
      }

      if(p==='orders/estimasi' && req.method==='POST') {
        const q=await estimasiSewa(env,me.sub,await req.json());const {plan,...price}=q;return json(price,200,env);
      }
      if(p==='orders' && req.method==='POST') {
        if (!rateMem(`order:${me.sub}`, 8, 60)) return err('Terlalu banyak order, tunggu.', 429, env);
        await rawatSewa(env);
        const r=await buatSewa(env,me.sub,await req.json());
        if(r.baru){
          ctx.waitUntil(push(env,room,'order.update',r.order));
          ctx.waitUntil(push(env,'cs:inbox','order.baru',{...r.order,user_id:me.sub}));
          ctx.waitUntil(segarkanTier(env,me.sub));
          const plan=await env.DB.prepare('SELECT unit_tersedia FROM pc_plans WHERE id=?').bind(r.order.plan_id).first();
          ctx.waitUntil(push(env,'katalog','stock.update',{id:r.order.plan_id,unitTersedia:plan.unit_tersedia}));
        }
        return json(r.order,r.baru?201:200,env);
      }
      if(p.startsWith('orders/') && p.endsWith('/batal') && req.method==='POST') {
        const o=await env.DB.prepare('SELECT * FROM orders WHERE id=? AND user_id=?').bind(p.split('/')[1],me.sub).first();
        if(!o)return err('Pesanan tidak ditemukan',404,env);
        if(o.status!=='dibayar')return err('Hanya pesanan yang belum disiapkan dapat dibatalkan di sini.',409,env);
        await env.DB.prepare("UPDATE orders SET status='batal' WHERE id=? AND status='dibayar'").bind(o.id).run();
        return json({ok:true},200,env);
      }

      // ---- detail order ----
      if (p.startsWith('orders/') && req.method === 'GET') {
        const o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?')
          .bind(p.split('/')[1], me.sub).first();
        return o ? json(o, 200, env) : err('Order tidak ditemukan', 404, env);
      }

      // ---- beli akun ----
      // Pembayaran hanya lewat saldo. Untuk mencegah "langsung konfirmasi" tanpa validasi:
      //  1) kredensial diklaim ATOMIK & eksklusif (dua pembeli tak bisa ambil baris sama);
      //  2) kalau tak ada kredensial siap -> DITOLAK dan saldo TIDAK dipotong;
      //  3) pemotongan saldo diguard (harus cukup); kalau gagal, klaim dilepas;
      //  4) pengurangan stok & catatan menyusul HANYA setelah klaim & potong berhasil.
      if (p === 'akun/beli' && req.method === 'POST') {
        if (!rateMem(`beli:${me.sub}`, 10, 60)) return err('Terlalu banyak percobaan beli, tunggu.', 429, env);
        const { produk_id, metode, voucher } = await req.json();
        if(metode!=='saldo')return err('Gunakan saldo untuk pembelian. Top up terlebih dahulu.',400,env);
        const prod = await env.DB.prepare('SELECT * FROM akun_produk WHERE id = ?').bind(produk_id).first();
        if (!prod) return err('Produk tidak ditemukan', 404, env);
        if (prod.stok <= 0) return err('Stok habis', 409, env);

        const user = await env.DB.prepare('SELECT saldo, tier FROM users WHERE id = ?').bind(me.sub).first();
        const potonganTier = Math.floor((prod.harga * (diskonTier(user?.tier) || 0)) / 100);
        let potonganVoucher = 0, kodeVoucher = null;
        if (voucher) {
          const cek = await cekVoucher(env, { kode: voucher, userId: me.sub, jenis: 'akun', total: prod.harga });
          if (!cek.ok) return err(cek.alasan, 400, env);
          potonganVoucher = cek.potongan; kodeVoucher = cek.voucher.kode;
        }
        const bayar = Math.max(0, prod.harga - potonganTier - potonganVoucher);
        if ((user?.saldo ?? 0) < bayar) return err('Saldo tidak cukup', 402, env);

        // (0) Klaim voucher dulu secara atomik jika ada — single-use + kuota guard. Rollback nanti jika langkah selanjutnya gagal.
        let voucherClaimed = false;
        if (kodeVoucher) {
          const vRes = await pakaiVoucher(env, { kode: kodeVoucher, userId: me.sub, refId: produk_id, potongan: potonganVoucher });
          if (!vRes.ok) return err(vRes.alasan || 'Voucher gagal dipakai', 409, env);
          voucherClaimed = true;
        }

        // (1) Klaim satu kredensial secara atomik. Coba beberapa kali karena bisa kalah lomba sesaat dengan pembeli lain.
        let stok = null;
        for (let coba = 0; coba < 3 && !stok; coba++) {
          const calon = await env.DB.prepare('SELECT id FROM akun_stok WHERE produk_id=? AND terpakai=0 ORDER BY id LIMIT 1').bind(produk_id).first();
          if (!calon) break;
          const up = await env.DB.prepare('UPDATE akun_stok SET terpakai=1, user_id=? WHERE id=? AND terpakai=0').bind(me.sub, calon.id).run();
          if (up.meta?.changes) {
            stok = await env.DB.prepare('SELECT * FROM akun_stok WHERE id=?').bind(calon.id).first();
          }
        }
        if (!stok) {
          if (voucherClaimed) {
            // rollback voucher karena kredensial tidak ada
            await env.DB.batch([
              env.DB.prepare('DELETE FROM voucher_pakai WHERE kode=? AND user_id=? AND ref_id=?').bind(kodeVoucher, me.sub, produk_id),
              env.DB.prepare('UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE kode=?').bind(kodeVoucher),
            ]);
          }
          return err('Kredensial produk belum tersedia. Tidak ada saldo yang dipotong — coba lagi beberapa saat.', 409, env);
        }
        if (!stok.email || !stok.password) {
          await env.DB.batch([
            env.DB.prepare('UPDATE akun_stok SET terpakai=0, user_id=NULL WHERE id=?').bind(stok.id),
            ...(voucherClaimed ? [
              env.DB.prepare('DELETE FROM voucher_pakai WHERE kode=? AND user_id=? AND ref_id=?').bind(kodeVoucher, me.sub, produk_id),
              env.DB.prepare('UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE kode=?').bind(kodeVoucher),
            ] : []),
          ]);
          return err('Kredensial tidak lengkap. Tidak ada saldo yang dipotong; hubungi CS.', 409, env);
        }

        // (2) Potong saldo dengan pengaman; kalau gagal, lepaskan klaim kredensial & voucher.
        const potong = await env.DB.prepare(
          'UPDATE users SET saldo=saldo-?, total_belanja=total_belanja+? WHERE id=? AND saldo>=?'
        ).bind(bayar, bayar, me.sub, bayar).run();
        if (!potong.meta?.changes) {
          await env.DB.batch([
            env.DB.prepare('UPDATE akun_stok SET terpakai=0, user_id=NULL WHERE id=?').bind(stok.id),
            ...(voucherClaimed ? [
              env.DB.prepare('DELETE FROM voucher_pakai WHERE kode=? AND user_id=? AND ref_id=?').bind(kodeVoucher, me.sub, produk_id),
              env.DB.prepare('UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE kode=?').bind(kodeVoucher),
            ] : []),
          ]);
          return err('Saldo tidak cukup', 402, env);
        }

        // (3) Kurangi stok (tidak boleh minus) & catat transaksi.
        await env.DB.prepare('UPDATE akun_produk SET stok=MAX(0,stok-1), terjual=terjual+1 WHERE id=?').bind(produk_id).run();
        await env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
          .bind(uid('t_'), me.sub, `Beli ${prod.nama}`, 'akun', -bayar).run();

        ctx.waitUntil(segarkanTier(env, me.sub));
        ctx.waitUntil(push(env, 'katalog', 'stock.update', { id: produk_id, stok: prod.stok - 1 }));

        const kodeAkun = 'AK-' + Math.floor(1000 + Math.random() * 8999);
        const pembeli = await env.DB.prepare('SELECT nama, email FROM users WHERE id = ?').bind(me.sub).first();
        if (pembeli?.email) {
          ctx.waitUntil(kirimEmail(env, {
            to: pembeli.email, template: 'kredensialAkun',
            data: { nama: pembeli.nama, produk: prod.nama, kode: kodeAkun,
              email: stok.email, password: stok.password,
              catatan: `Segera ganti password setelah login. Garansi ${prod.garansi}.` },
          }));
          ctx.waitUntil(kirimEmail(env, {
            to: pembeli.email, template: 'struk',
            data: { nama: pembeli.nama, kode: kodeAkun, judul: prod.nama, total: bayar, metode },
          }));
        }
        ctx.waitUntil(kirimPush(env, {
          userId: me.sub, judul: 'Pembelian berhasil',
          pesan: `${prod.nama} sudah aktif. Kredensial juga dikirim ke emailmu.`,
          data: { tipe: 'akun', kode: kodeAkun }, tombol: [{ id: 'buka', text: 'Lihat Akun Saya' }],
        }));

        return json({
          kode: kodeAkun, email: stok.email, password: stok.password,
          catatan: `Segera ganti password. Garansi ${prod.garansi}.`,
        }, 201, env);
      }

      // ---- wallet ----
      if (p === 'wallet/transaksi' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM transaksi WHERE user_id = ? ORDER BY waktu DESC LIMIT 50').bind(me.sub).all();
        return json(results, 200, env);
      }

      if (p === 'wallet/topup' && req.method === 'POST') {
        const { nominal, metode } = await req.json();
        const jumlah = Number(nominal) || 0;
        const minimal = Number(env.MIN_TOPUP || 10000);
        if (jumlah < minimal) return err(`Minimal top up Rp${minimal.toLocaleString('id-ID')}`, 400, env);

        const id = uid('tp_');
        const otomatis = penyediaBayar(env) !== 'manual';
        const pemilik = await env.DB.prepare('SELECT nama, email, phone FROM users WHERE id = ?')
          .bind(me.sub).first();

        // ---- jalur otomatis lewat penyedia pembayaran ----
        if (otomatis) {
          const tagihan = await buatTagihan(env, {
            id,
            nominal: jumlah,
            metode,
            nama: pemilik?.nama,
            email: pemilik?.email,
            phone: pemilik?.phone,
            keterangan: 'Isi saldo XyCloudStore',
          });

          if (tagihan.ok) {
            await env.DB.prepare(
              "INSERT INTO topup (id,user_id,nominal,kode_unik,total,metode,status,catatan) VALUES (?,?,?,0,?,?,'menunggu',?)"
            ).bind(id, me.sub, jumlah, jumlah, metode || tagihan.penyedia, tagihan.referensi || null).run();

            ctx.waitUntil(push(env, 'cs:inbox', 'topup.baru', { id, user_id: me.sub, nominal: jumlah, otomatis: true }));

            return json({
              id,
              nominal: jumlah,
              total: jumlah,
              kode_unik: 0,
              metode: metode || tagihan.penyedia,
              status: 'menunggu',
              otomatis: true,
              bayar: {
                url: tagihan.url,
                qr: tagihan.qr,
                kode: tagihan.kode_bayar,
                kedaluwarsa: tagihan.kedaluwarsa || null,
              },
              catatan: 'Selesaikan pembayaran, saldo masuk otomatis dalam hitungan detik.',
            }, 201, env);
          }
          // kalau penyedia gagal, lanjut ke jalur manual di bawah
        }

        // ---- jalur manual: transfer + bukti + konfirmasi admin ----
        const kodeUnik = 100 + (crypto.getRandomValues(new Uint32Array(1))[0] % 800);
        const total = jumlah + kodeUnik;

        await env.DB.prepare(
          "INSERT INTO topup (id,user_id,nominal,kode_unik,total,metode,status) VALUES (?,?,?,?,?,?,'menunggu')"
        ).bind(id, me.sub, jumlah, kodeUnik, total, metode || 'transfer').run();

        ctx.waitUntil(push(env, 'cs:inbox', 'topup.baru', { id, user_id: me.sub, nominal: jumlah, status: 'menunggu' }));

        return json({
          id,
          nominal: jumlah,
          kode_unik: kodeUnik,
          total,
          metode: metode || 'transfer',
          status: 'menunggu',
          otomatis: false,
          rekening: {
            bank: env.BANK_NAMA || 'DANA',
            nomor: env.BANK_NOMOR || '-',
            atasNama: env.BANK_ATASNAMA || 'XyCloudStore',
            qris: env.QRIS_URL ? samarkanGambar(env, env.QRIS_URL, 'l') : '',
          },
          catatan: 'Transfer tepat sampai 3 angka terakhir supaya otomatis kami cocokkan, lalu unggah bukti transfer.',
        }, 201, env);
      }

      if(p==='cs/typing'&&req.method==='POST'){
        if(!(await bolehLanjut(env,`typing:${me.sub}`,45,60)))return json({ok:true},200,env);
        const b=await req.json();ctx.waitUntil(push(env,'cs:inbox','user.typing',{room,typing:b.typing===true}));return json({ok:true},200,env);
      }

      // ---- customer service ----
      if (p === 'cs/messages' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare(`SELECT * FROM (SELECT * FROM cs_messages WHERE room=? AND dihapus=0 AND datetime(waktu)>=datetime('now','-7 days') ORDER BY waktu DESC,id DESC LIMIT 200) ORDER BY waktu,id`)
          .bind(room).all();
        return json(results.map((r) => ({ ...r, gambar: samarkanGambar(env, r.gambar, 'm') })), 200, env);
      }

      if (p === 'cs/messages' && req.method === 'POST') {
        if (!rateMem(`cs-mem:${me.sub}`, 30, 60)) {
          return err('Terlalu banyak pesan, tunggu sebentar.', 429, env);
        }
        const { teks, gambar, client_id: clientId } = await req.json();
        if(!String(teks||'').trim()&&!gambar)return err('Pesan kosong',400,env);
        if(String(teks||'').length>5000)return err('Pesan maksimal 5.000 karakter',400,env);
        if(clientId&&!/^[A-Za-z0-9_-]{12,100}$/.test(clientId))return err('ID pesan tidak valid',400,env);
        if(clientId){const old=await env.DB.prepare('SELECT * FROM cs_messages WHERE room=? AND client_id=?').bind(room,clientId).first();if(old)return json(old,200,env);}
        let urlGambar = null;
        if (gambar) {
          const hasil = await unggahGambar(env, { dataUri: gambar, folder: 'xycloudstore/chat' });
          if (!hasil.ok) return err(hasil.alasan, 502, env);
          urlGambar = hasil.url;
        }
        const msg = {
          id: uid('m_'), room, dari: 'user', client_id: clientId || null, teks: teks || '', gambar: urlGambar,
          waktu: new Date().toISOString(), dibaca: 0,
        };
        await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,gambar,waktu,client_id) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(room,client_id) DO NOTHING')
          .bind(msg.id, room, me.sub, 'user', msg.teks, urlGambar, msg.waktu,clientId||null).run();
        if(clientId){const stored=await env.DB.prepare('SELECT * FROM cs_messages WHERE room=? AND client_id=?').bind(room,clientId).first();if(stored.id!==msg.id)return json(stored,200,env);}
        ctx.waitUntil(Promise.all([
          push(env, room, 'chat.message', msg),
          push(env, 'cs:inbox', 'chat.message', { ...msg, user_id: me.sub }), // dashboard admin
        ]));
        return json(msg, 201, env);
      }

      // ---- hapus satu pesan milik sendiri ----
      if (p.startsWith('cs/messages/') && req.method === 'DELETE') {
        const id = p.split('/')[2];
        const m = await env.DB.prepare('SELECT * FROM cs_messages WHERE id = ? AND room = ?')
          .bind(id, room).first();
        if (!m) return err('Pesan tidak ditemukan', 404, env);
        if (m.dari !== 'user') return err('Hanya pesanmu sendiri yang bisa dihapus', 403, env);

        await env.DB.prepare("UPDATE cs_messages SET dihapus = 1, teks = '', gambar = NULL WHERE id = ?")
          .bind(id).run();
        ctx.waitUntil(Promise.all([
          push(env, room, 'chat.hapus', { id }),
          push(env, 'cs:inbox', 'chat.hapus', { id, room }),
        ]));
        return json({ ok: true }, 200, env);
      }

      // ---- bersihkan seluruh percakapan milik sendiri ----
      if (p === 'cs/messages' && req.method === 'DELETE') {
        await env.DB.prepare("UPDATE cs_messages SET dihapus = 1, teks = '', gambar = NULL WHERE room = ? AND dari = 'user'")
          .bind(room).run();
        return json({ ok: true }, 200, env);
      }

      // ---- tandai pesan CS sudah dibaca ----
      if (p === 'cs/dibaca' && req.method === 'POST') {
        await env.DB.prepare("UPDATE cs_messages SET dibaca = 1 WHERE room = ? AND dari = 'cs'").bind(room).run();
        return json({ ok: true }, 200, env);
      }

      if(p==='cs/reply')return err('Balasan CS hanya melalui dashboard admin.',403,env);

      return err('Endpoint tidak dikenal', 404, env);
    } catch (e) {
      if(e instanceof SecurityError)return new Response(JSON.stringify({error:e.message,code:e.code}),{status:e.status,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':env.ALLOW_ORIGIN||'*','Cache-Control':'no-store'}});
      return e instanceof KontenError ? err(e.message, e.status, env) : err(`Server error: ${e.message}`, 500, env);
    }
  },
};

// ============================================================
//  Durable Object — hub WebSocket per room
// ============================================================
export class RealtimeHub {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.clients = new Set();
  }

  async fetch(req) {
    const url = new URL(req.url);

    // broadcast internal dari Worker
    if (url.pathname === '/broadcast' && req.method === 'POST') {
      const body = await req.text();
      this.kirimSemua(body);
      return new Response('ok');
    }

    if (req.headers.get('Upgrade') !== 'websocket') {
      return new Response('Expected WebSocket', { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    this.clients.add(server);

    server.addEventListener('message', (e) => {
      let m;
      try { m = JSON.parse(e.data); } catch { return; }
      if (m.type === 'ping') return server.send(JSON.stringify({ type: 'pong' }));
      if (url.pathname === '/ws/forum' || url.pathname === '/ws/katalog') return;
      // Pesan tersimpan, saldo dan status hanya disiarkan oleh Worker melalui /broadcast.
      return;
    });

    const tutup = () => this.clients.delete(server);
    server.addEventListener('close', tutup);
    server.addEventListener('error', tutup);

    server.send(JSON.stringify({ type: 'hello', payload: { room: url.pathname, at: new Date().toISOString() } }));
    return new Response(null, { status: 101, webSocket: client });
  }

  kirimSemua(data, kecuali = null) {
    for (const ws of this.clients) {
      if (ws === kecuali) continue;
      try { ws.send(data); } catch { this.clients.delete(ws); }
    }
  }
}
