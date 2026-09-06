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
import LOGO_PNG from './brand-logo.png';
import { kirimEmail } from './mail.js';
import { kirimPush, siarkanPush } from './push.js';
import { unggahGambar } from './upload.js';
import { SKEMA_APLIKASI, providerSiap, urlMulai, ambilProfil, halamanKembali } from './oauth.js';

const json = (data, status = 200, env) =>
  new Response(JSON.stringify({ data }), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env?.ALLOW_ORIGIN || '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
    },
  });

const err = (message, status = 400, env) =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env?.ALLOW_ORIGIN || '*',
    },
  });

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
  if (!tersimpan) return false;
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
  const kode = buatKode();
  const kadaluarsa = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  await env.DB.prepare('DELETE FROM otp WHERE email = ? AND tipe = ?').bind(email, tipe).run();
  await env.DB.prepare('INSERT INTO otp (id,email,kode,tipe,kadaluarsa) VALUES (?,?,?,?,?)')
    .bind(uid('otp_'), email, kode, tipe, kadaluarsa).run();
  return kirimEmail(env, {
    to: email,
    template: tipe === 'reset' ? 'resetPassword' : 'verifikasi',
    data: { nama: nama || 'Sobat Xy', kode },
  });
}

/** Periksa OTP; kalau cocok, tandai terpakai. */
async function cekOtp(env, { email, kode, tipe }) {
  const row = await env.DB
    .prepare('SELECT * FROM otp WHERE email = ? AND tipe = ? AND kode = ? AND dipakai = 0')
    .bind(email, tipe, String(kode).trim()).first();
  if (!row) return { ok: false, pesan: 'Kode verifikasi salah' };
  if (new Date(row.kadaluarsa) < new Date()) return { ok: false, pesan: 'Kode sudah kedaluwarsa, minta kode baru' };
  await env.DB.prepare('UPDATE otp SET dipakai = 1 WHERE id = ?').bind(row.id).run();
  return { ok: true };
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
  const expected = await sign(JSON.parse(atob(body.replace(/-/g, '+').replace(/_/g, '/'))), secret);
  if (expected !== token) return null;
  return JSON.parse(atob(body.replace(/-/g, '+').replace(/_/g, '/')));
}

async function auth(req, env) {
  const h = req.headers.get('Authorization') || '';
  return verify(h.replace('Bearer ', ''), env.JWT_SECRET);
}

const uid = (p = '') => p + crypto.randomUUID().replace(/-/g, '').slice(0, 12);

/** Cek admin key dari header x-admin-key atau query ?key= */
function isAdmin(req, env) {
  const url = new URL(req.url);
  const k = req.headers.get('x-admin-key') || url.searchParams.get('key');
  return !!env.ADMIN_KEY && k === env.ADMIN_KEY;
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
  return push(env, 'katalog', 'banner.update', { banners: results });
}

// ============================================================
//  ROUTER
// ============================================================
export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    const path = url.pathname;

    if (req.method === 'OPTIONS') return json({}, 204, env);

    // ---------- WebSocket realtime ----------
    if (path.startsWith('/ws/')) {
      const room = decodeURIComponent(path.slice(4));
      const id = env.HUB.idFromName(room);
      return env.HUB.get(id).fetch(req);
    }

    // ---------- dashboard admin ----------
    if (path === '/' || path === '/admin' || path === '/admin/') {
      return new Response(ADMIN_HTML, {
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
      });
    }

    if (path === '/brand/logo.png') {
      return new Response(LOGO_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' },
      });
    }

    if (path === '/health') return json({ ok: true, at: new Date().toISOString() }, 200, env);

    if (!path.startsWith('/api/')) return err('Not found', 404, env);
    const p = path.slice(5);

    try {
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
        }, 200, env);
      }

      // ---------------- LOGIN SOSIAL ----------------
      if (p.startsWith('auth/') && (p.endsWith('/start') || p.endsWith('/callback'))) {
        const bagian = p.split('/');            // auth / provider / aksi
        const provider = bagian[1];
        const aksi = bagian[2];
        const siap = providerSiap(env);

        if (!siap[provider]) {
          return err(`Login ${provider} belum dikonfigurasi`, 501, env);
        }

        if (aksi === 'start') {
          const state = url.searchParams.get('state') || uid('st_');
          return Response.redirect(urlMulai(env, provider, state), 302);
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

        let u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(prof.email).first();
        if (!u) {
          const idBaru = uid('u_');
          await env.DB.prepare(
            "INSERT INTO users (id,nama,email,password,phone,saldo,tier,email_verified,foto) VALUES (?,?,?,?,?,0,'basic',1,?)"
          ).bind(idBaru, prof.nama, prof.email, `sosial:${provider}`, null, prof.foto || null).run();

          const sapa = {
            id: uid('m_'), room: `user:${idBaru}`, dari: 'cs',
            teks: `Halo ${prof.nama.split(' ')[0]}, selamat datang di XyCloudStore. Ada yang bisa kami bantu?`,
            waktu: new Date().toISOString(),
          };
          ctx.waitUntil(env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
            .bind(sapa.id, sapa.room, idBaru, 'cs', sapa.teks, sapa.waktu).run());
          ctx.waitUntil(kirimEmail(env, { to: prof.email, template: 'selamatDatang', data: { nama: prof.nama } }));

          u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(idBaru).first();
        } else if (!u.email_verified || (prof.foto && !u.foto)) {
          await env.DB.prepare('UPDATE users SET email_verified = 1, foto = COALESCE(foto, ?) WHERE id = ?')
            .bind(prof.foto || null, u.id).run();
          u.email_verified = 1;
          u.foto = u.foto || prof.foto;
        }

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
        return new Response(
          halamanKembali(`${SKEMA_APLIKASI}://auth?token=${encodeURIComponent(token)}`, `Halo ${u.nama.split(' ')[0]}`),
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      }

      // ---------------- AUTH ----------------
      if (p === 'auth/login' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        if (!email || !password) return err('Email dan password wajib diisi', 400, env);

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Email belum terdaftar. Silakan daftar dulu.', 404, env);
        if (!(await cocokPw(password, u.password))) return err('Password salah. Coba lagi.', 401, env);

        if (!u.email_verified) {
          ctx.waitUntil(kirimOtp(env, { email: u.email, nama: u.nama, tipe: 'verifikasi' }));
          return json({ perluVerifikasi: true, email: u.email, nama: u.nama,
            pesan: 'Email belum diverifikasi. Kode baru sudah kami kirim.' }, 200, env);
        }

        // upgrade otomatis password lama ke bentuk hash
        if (!String(u.password).includes('$')) {
          const baru = await buatPw(password);
          ctx.waitUntil(env.DB.prepare('UPDATE users SET password=? WHERE id=?').bind(baru, u.id).run());
        }

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
        delete u.password;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'auth/register' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
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

        let id = ada?.id;
        if (ada) {
          // pendaftaran diulang sebelum diverifikasi: perbarui datanya
          await env.DB.prepare('UPDATE users SET nama=?, password=?, phone=? WHERE id=?')
            .bind(nama, await buatPw(password), phone, id).run();
        } else {
          id = uid('u_');
          await env.DB.prepare(
            "INSERT INTO users (id,nama,email,password,phone,saldo,tier,email_verified) VALUES (?,?,?,?,?,0,'basic',0)"
          ).bind(id, nama, email, await buatPw(password), phone).run();
        }

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
        const body = await req.json().catch(() => ({}));
        const email = String(body.email || '').trim().toLowerCase();
        const kode = String(body.kode || '').trim();

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);
        if (u.email_verified) {
          const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
          delete u.password;
          return json({ token, user: u }, 200, env);
        }

        const cek = await cekOtp(env, { email, kode, tipe: 'verifikasi' });
        if (!cek.ok) return err(cek.pesan, 400, env);

        await env.DB.prepare('UPDATE users SET email_verified = 1 WHERE id = ?').bind(u.id).run();

        // sapaan CS + email selamat datang
        const sapa = {
          id: uid('m_'), room: `user:${u.id}`, dari: 'cs',
          teks: `Halo ${u.nama.split(' ')[0]}, selamat datang di XyCloudStore. Ada yang bisa kami bantu?`,
          waktu: new Date().toISOString(),
        };
        ctx.waitUntil(env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
          .bind(sapa.id, sapa.room, u.id, 'cs', sapa.teks, sapa.waktu).run());
        ctx.waitUntil(kirimEmail(env, { to: email, template: 'selamatDatang', data: { nama: u.nama } }));

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
        delete u.password;
        u.email_verified = 1;
        return json({ token, user: u }, 200, env);
      }

      // ---- kirim ulang kode ----
      if (p === 'auth/resend' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
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
        const email = String(body.email || '').trim().toLowerCase();
        const u = await env.DB.prepare('SELECT nama FROM users WHERE lower(email) = ?').bind(email).first();
        // jawaban selalu sama supaya email orang lain tidak bisa ditebak
        if (u) ctx.waitUntil(kirimOtp(env, { email, nama: u.nama, tipe: 'reset' }));
        return json({ ok: true, pesan: 'Kalau email terdaftar, kode reset sudah kami kirim.' }, 200, env);
      }

      // ---- pasang password baru ----
      if (p === 'auth/reset' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        const email = String(body.email || '').trim().toLowerCase();
        const kode = String(body.kode || '').trim();
        const password = String(body.password || '');
        if (password.length < 6) return err('Password minimal 6 karakter', 400, env);

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);

        const cek = await cekOtp(env, { email, kode, tipe: 'reset' });
        if (!cek.ok) return err(cek.pesan, 400, env);

        await env.DB.prepare('UPDATE users SET password = ?, email_verified = 1 WHERE id = ?')
          .bind(await buatPw(password), u.id).run();

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
        delete u.password;
        u.email_verified = 1;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'pc/plans' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM pc_plans').all();
        return json(results, 200, env);
      }

      if (p === 'banners' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM banners WHERE aktif = 1 ORDER BY urutan ASC').all();
        return json(results, 200, env);
      }

      // ================= ADMIN =================
      if (p.startsWith('admin/')) {
        if (!isAdmin(req, env)) return err('Admin key salah', 401, env);
        const a = p.slice(6);

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

        if (a.startsWith('orders/') && req.method === 'PATCH') {
          const id = a.split('/')[1];
          const b = await req.json();
          const kolom = ['status', 'progress', 'host', 'username', 'password', 'mulai', 'berakhir'];
          const isi = kolom.filter((k) => b[k] !== undefined);
          if (!isi.length) return err('Tidak ada perubahan', 400, env);
          await env.DB.prepare(
            `UPDATE orders SET ${isi.map((k) => `${k}=?`).join(',')} WHERE id=?`
          ).bind(...isi.map((k) => b[k]), id).run();
          const o = await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(id).first();
          ctx.waitUntil(push(env, `user:${o.user_id}`, 'order.update', o));

          // beri tahu pemilik order lewat push dan email
          const pemilik = await env.DB.prepare('SELECT nama, email FROM users WHERE id = ?')
            .bind(o.user_id).first();
          const pesanStatus = {
            dibayar: 'Pembayaran diterima, unit sedang disiapkan.',
            provisioning: 'Unit sedang dinyalakan, tunggu sebentar ya.',
            aktif: 'PC kamu sudah aktif dan siap dipakai.',
            selesai: 'Sesi sewa sudah selesai. Terima kasih.',
            batal: 'Order dibatalkan. Saldo dikembalikan bila sudah terbayar.',
          }[o.status];
          if (pesanStatus) {
            ctx.waitUntil(kirimPush(env, {
              userId: o.user_id,
              judul: `Order ${o.kode}`,
              pesan: pesanStatus,
              data: { tipe: 'order', id: o.id },
            }));
          }
          if (o.status === 'aktif' && pemilik?.email) {
            ctx.waitUntil(kirimEmail(env, {
              to: pemilik.email,
              template: 'orderAktif',
              data: {
                nama: pemilik.nama, kode: o.kode, plan: o.plan_nama, host: o.host,
                username: o.username, password: o.password, durasi: o.durasi_jam,
              },
            }));
          }
          return json(o, 200, env);
        }

        // ---- katalog PC ----
        if (a === 'plans' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM pc_plans').all();
          return json(results, 200, env);
        }
        if (a === 'plans' && req.method === 'POST') {
          const b = await req.json();
          await env.DB.prepare(
            `INSERT OR REPLACE INTO pc_plans
             (id,nama,gpu,cpu,ram_gb,storage_gb,harga_per_jam,harga_per_hari,region,tag,total_unit,unit_tersedia,gambar)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(b.id || uid('pc-'), b.nama, b.gpu, b.cpu, b.ram_gb, b.storage_gb, b.harga_per_jam,
                 b.harga_per_hari, b.region, b.tag || '', b.total_unit, b.unit_tersedia, b.gambar || '').run();
          ctx.waitUntil(push(env, 'katalog', 'stock.update', { id: b.id, unitTersedia: b.unit_tersedia }));
          return json({ ok: true }, 201, env);
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

        // ---- banner ----
        if (a === 'banners' && req.method === 'GET') {
          const { results } = await env.DB.prepare('SELECT * FROM banners ORDER BY urutan ASC').all();
          return json(results, 200, env);
        }
        if (a === 'banners' && req.method === 'POST') {
          const b = await req.json();
          await env.DB.prepare(
            `INSERT OR REPLACE INTO banners
             (id,judul,subjudul,label,cta,aksi,target,warna1,warna2,ikon,urutan,aktif)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(b.id || uid('bn-'), b.judul, b.subjudul || '', b.label || '', b.cta || 'Lihat',
                 b.aksi || 'sewa', b.target || '', b.warna1 || '#2F5BFF', b.warna2 || '#6A4BFF',
                 b.ikon || 'bolt', b.urutan || 0, b.aktif === 0 ? 0 : 1).run();
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
             GROUP BY m.room ORDER BY terakhir DESC LIMIT 50`
          ).all();
          return json(results, 200, env);
        }
        if (a.startsWith('cs/room/') && req.method === 'GET') {
          const room = decodeURIComponent(a.slice(8));
          const { results } = await env.DB
            .prepare('SELECT * FROM cs_messages WHERE room=? ORDER BY waktu ASC LIMIT 300').bind(room).all();
          return json(results, 200, env);
        }
        if (a === 'cs/reply' && req.method === 'POST') {
          const { room, teks } = await req.json();
          const msg = { id: uid('m_'), room, dari: 'cs', teks, waktu: new Date().toISOString() };
          await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
            .bind(msg.id, room, room.split(':')[1] || '', 'cs', teks, msg.waktu).run();
          ctx.waitUntil(push(env, room, 'chat.message', msg));
          ctx.waitUntil(kirimPush(env, {
            userId: room.split(':')[1],
            judul: 'Balasan customer service',
            pesan: teks.length > 90 ? teks.slice(0, 90) + '...' : teks,
            data: { tipe: 'cs' },
          }));
          return json(msg, 201, env);
        }
        if (a === 'cs/typing' && req.method === 'POST') {
          const { room, typing } = await req.json();
          ctx.waitUntil(push(env, room, 'cs.typing', { typing: !!typing }));
          return json({ ok: true }, 200, env);
        }

        // ---- pengguna ----
        if (a === 'users' && req.method === 'GET') {
          const { results } = await env.DB
            .prepare('SELECT id,nama,email,phone,saldo,tier,created_at FROM users ORDER BY created_at DESC LIMIT 100').all();
          return json(results, 200, env);
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
          const t = await env.DB.prepare('SELECT * FROM topup WHERE id = ?').bind(id).first();
          if (!t) return err('Permintaan tidak ditemukan', 404, env);
          if (t.status === 'disetujui') return err('Top up ini sudah disetujui', 409, env);

          const waktu = new Date().toISOString();
          if (status === 'disetujui') {
            await env.DB.batch([
              env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(t.nominal, t.user_id),
              env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
                .bind(uid('t_'), t.user_id, 'Top up saldo', 'topup', t.nominal),
              env.DB.prepare("UPDATE topup SET status='disetujui', catatan=?, diproses=? WHERE id=?")
                .bind(catatan || null, waktu, id),
            ]);
            const u = await env.DB.prepare('SELECT saldo, nama, email FROM users WHERE id = ?').bind(t.user_id).first();
            ctx.waitUntil(push(env, `user:${t.user_id}`, 'wallet.update', { saldo: u.saldo }));
            ctx.waitUntil(kirimPush(env, {
              userId: t.user_id, judul: 'Top up berhasil',
              pesan: `Saldo Rp${Number(t.nominal).toLocaleString('id-ID')} sudah masuk ke dompetmu.`,
              data: { tipe: 'wallet' },
            }));
            if (u?.email) {
              ctx.waitUntil(kirimEmail(env, {
                to: u.email, template: 'struk',
                data: { nama: u.nama, kode: id.toUpperCase(), judul: 'Top up saldo', total: t.nominal, metode: t.metode },
              }));
            }
            return json({ ok: true, saldo: u.saldo }, 200, env);
          }

          await env.DB.prepare("UPDATE topup SET status='ditolak', catatan=?, diproses=? WHERE id=?")
            .bind(catatan || 'Bukti transfer tidak cocok', waktu, id).run();
          ctx.waitUntil(kirimPush(env, {
            userId: t.user_id, judul: 'Top up ditolak',
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
        return json(results, 200, env);
      }

      if (p === 'akun/produk' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM akun_produk').all();
        return json(results.map(r => ({ ...r, fitur: JSON.parse(r.fitur || '[]') })), 200, env);
      }

      // ---------------- butuh login ----------------
      const me = await auth(req, env);
      if (!me) return err('Unauthorized', 401, env);
      const room = `user:${me.sub}`;

      // ---- profil pengguna yang sedang login ----
      if (p === 'me' && req.method === 'GET') {
        const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(me.sub).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);
        delete u.password;
        return json(u, 200, env);
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

      // ---- buat order sewa PC ----
      if (p === 'orders' && req.method === 'POST') {
        const { plan_id, durasi_jam, metode } = await req.json();
        const plan = await env.DB.prepare('SELECT * FROM pc_plans WHERE id = ?').bind(plan_id).first();
        if (!plan) return err('Paket tidak ditemukan', 404, env);
        if (plan.unit_tersedia <= 0) return err('Unit sedang penuh', 409, env);

        const total = plan.harga_per_jam * durasi_jam;
        const user = await env.DB.prepare('SELECT saldo FROM users WHERE id = ?').bind(me.sub).first();
        if (metode === 'saldo' && user.saldo < total) return err('Saldo tidak cukup', 402, env);

        const id = uid('o_');
        const kode = 'XY-' + Math.floor(1000 + Math.random() * 8999);

        await env.DB.batch([
          env.DB.prepare(
            `INSERT INTO orders (id,kode,user_id,plan_id,plan_nama,durasi_jam,total,status)
             VALUES (?,?,?,?,?,?,?,?)`
          ).bind(id, kode, me.sub, plan.id, plan.nama, durasi_jam, total,
                 metode === 'saldo' ? 'dibayar' : 'pending'),
          env.DB.prepare('UPDATE pc_plans SET unit_tersedia = unit_tersedia - 1 WHERE id = ?').bind(plan.id),
          env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
            .bind(uid('t_'), me.sub, `Sewa ${plan.nama} ${durasi_jam} jam`, 'sewa', -total),
          ...(metode === 'saldo'
            ? [env.DB.prepare('UPDATE users SET saldo = saldo - ? WHERE id = ?').bind(total, me.sub)]
            : []),
        ]);

        const order = await env.DB.prepare('SELECT * FROM orders WHERE id = ?').bind(id).first();

        // broadcast stok baru + order baru
        ctx.waitUntil(Promise.all([
          push(env, room, 'order.update', order),
          push(env, 'katalog', 'stock.update',
            { id: plan.id, unitTersedia: plan.unit_tersedia - 1 }),
        ]));

        // simulasi provisioning otomatis (di produksi: panggil API hypervisor)
        ctx.waitUntil(provision(env, room, id));

        return json(order, 201, env);
      }

      // ---- detail order ----
      if (p.startsWith('orders/') && req.method === 'GET') {
        const o = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?')
          .bind(p.split('/')[1], me.sub).first();
        return o ? json(o, 200, env) : err('Order tidak ditemukan', 404, env);
      }

      // ---- beli akun ----
      if (p === 'akun/beli' && req.method === 'POST') {
        const { produk_id, metode } = await req.json();
        const prod = await env.DB.prepare('SELECT * FROM akun_produk WHERE id = ?').bind(produk_id).first();
        if (!prod) return err('Produk tidak ditemukan', 404, env);
        if (prod.stok <= 0) return err('Stok habis', 409, env);

        const stok = await env.DB
          .prepare('SELECT * FROM akun_stok WHERE produk_id = ? AND terpakai = 0 LIMIT 1')
          .bind(produk_id).first();

        const user = await env.DB.prepare('SELECT saldo FROM users WHERE id = ?').bind(me.sub).first();
        if (metode === 'saldo' && user.saldo < prod.harga) return err('Saldo tidak cukup', 402, env);

        await env.DB.batch([
          env.DB.prepare('UPDATE akun_produk SET stok = stok - 1, terjual = terjual + 1 WHERE id = ?').bind(produk_id),
          ...(stok ? [env.DB.prepare('UPDATE akun_stok SET terpakai = 1, user_id = ? WHERE id = ?').bind(me.sub, stok.id)] : []),
          env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
            .bind(uid('t_'), me.sub, `Beli ${prod.nama}`, 'akun', -prod.harga),
          ...(metode === 'saldo'
            ? [env.DB.prepare('UPDATE users SET saldo = saldo - ? WHERE id = ?').bind(prod.harga, me.sub)]
            : []),
        ]);

        ctx.waitUntil(push(env, 'katalog', 'stock.update', { id: produk_id, stok: prod.stok - 1 }));

        const kodeAkun = 'AK-' + Math.floor(1000 + Math.random() * 8999);
        const pembeli = await env.DB.prepare('SELECT nama, email FROM users WHERE id = ?').bind(me.sub).first();
        if (pembeli?.email) {
          ctx.waitUntil(kirimEmail(env, {
            to: pembeli.email,
            template: 'kredensialAkun',
            data: {
              nama: pembeli.nama, produk: prod.nama, kode: kodeAkun,
              email: stok?.email || 'akan dikirim admin', password: stok?.password || '-',
              catatan: `Segera ganti password setelah login. Garansi ${prod.garansi}.`,
            },
          }));
          ctx.waitUntil(kirimEmail(env, {
            to: pembeli.email,
            template: 'struk',
            data: { nama: pembeli.nama, kode: kodeAkun, judul: prod.nama, total: prod.harga, metode },
          }));
        }
        ctx.waitUntil(kirimPush(env, {
          userId: me.sub,
          judul: 'Pembelian berhasil',
          pesan: `${prod.nama} sudah aktif. Kredensial juga dikirim ke emailmu.`,
          data: { tipe: 'akun', kode: kodeAkun },
        }));

        return json({
          kode: kodeAkun,
          email: stok?.email || 'akan dikirim admin',
          password: stok?.password || '-',
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

        // kode unik supaya transfer mudah dicocokkan
        const kodeUnik = 100 + (crypto.getRandomValues(new Uint32Array(1))[0] % 800);
        const id = uid('tp_');
        const total = jumlah + kodeUnik;

        await env.DB.prepare(
          "INSERT INTO topup (id,user_id,nominal,kode_unik,total,metode,status) VALUES (?,?,?,?,?,?,'menunggu')"
        ).bind(id, me.sub, jumlah, kodeUnik, total, metode || 'transfer').run();

        const data = {
          id, nominal: jumlah, kode_unik: kodeUnik, total, metode: metode || 'transfer', status: 'menunggu',
          rekening: {
            bank: env.BANK_NAMA || 'BCA',
            nomor: env.BANK_NOMOR || '1234567890',
            atasNama: env.BANK_ATASNAMA || 'XyCloudStore',
            qris: env.QRIS_URL || '',
          },
          catatan: 'Transfer tepat sampai 3 angka terakhir supaya otomatis kami cocokkan, lalu unggah bukti transfer.',
        };

        ctx.waitUntil(push(env, 'cs:inbox', 'topup.baru', { id, user_id: me.sub, nominal: jumlah, status: 'menunggu' }));
        return json(data, 201, env);
      }

      // ---- customer service ----
      if (p === 'cs/messages' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM cs_messages WHERE room = ? ORDER BY waktu ASC LIMIT 200')
          .bind(room).all();
        return json(results, 200, env);
      }

      if (p === 'cs/messages' && req.method === 'POST') {
        const { teks, gambar } = await req.json();
        let urlGambar = null;
        if (gambar) {
          const hasil = await unggahGambar(env, { dataUri: gambar, folder: 'xycloudstore/chat' });
          if (!hasil.ok) return err(hasil.alasan, 502, env);
          urlGambar = hasil.url;
        }
        const msg = {
          id: uid('m_'), room, dari: 'user', teks: teks || '', gambar: urlGambar,
          waktu: new Date().toISOString(), dibaca: 0,
        };
        await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,gambar,waktu) VALUES (?,?,?,?,?,?,?)')
          .bind(msg.id, room, me.sub, 'user', msg.teks, urlGambar, msg.waktu).run();
        ctx.waitUntil(Promise.all([
          push(env, room, 'chat.message', msg),
          push(env, 'cs:inbox', 'chat.message', { ...msg, user_id: me.sub }), // dashboard admin
        ]));
        return json(msg, 201, env);
      }

      // ---- tandai pesan CS sudah dibaca ----
      if (p === 'cs/dibaca' && req.method === 'POST') {
        await env.DB.prepare("UPDATE cs_messages SET dibaca = 1 WHERE room = ? AND dari = 'cs'").bind(room).run();
        return json({ ok: true }, 200, env);
      }

      // ---- endpoint untuk dashboard admin/CS ----
      if (p === 'cs/reply' && req.method === 'POST') {
        const { room: target, teks, gambar } = await req.json();
        const msg = {
          id: uid('m_'), room: target, dari: 'cs', teks: teks || '',
          gambar: gambar || null, waktu: new Date().toISOString(),
        };
        await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,gambar,waktu) VALUES (?,?,?,?,?,?,?)')
          .bind(msg.id, target, target.split(':')[1], 'cs', msg.teks, msg.gambar, msg.waktu).run();
        ctx.waitUntil(push(env, target, 'chat.message', msg));
        ctx.waitUntil(kirimPush(env, {
          userId: target.split(':')[1],
          judul: 'Balasan customer service',
          pesan: msg.teks ? (msg.teks.length > 90 ? msg.teks.slice(0, 90) + '...' : msg.teks) : 'Mengirim sebuah gambar',
          data: { tipe: 'cs' },
        }));
        return json(msg, 201, env);
      }

      return err('Endpoint tidak dikenal', 404, env);
    } catch (e) {
      return err(`Server error: ${e.message}`, 500, env);
    }
  },
};

/** Simulasi/orkestrasi penyalaan mesin + push progress realtime. */
async function provision(env, room, orderId) {
  const set = async (fields) => {
    const keys = Object.keys(fields);
    await env.DB.prepare(`UPDATE orders SET ${keys.map(k => `${k}=?`).join(',')} WHERE id=?`)
      .bind(...keys.map(k => fields[k]), orderId).run();
    const o = await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(orderId).first();
    await push(env, room, 'order.update', o);
  };

  await set({ status: 'provisioning', progress: 15 });
  await set({ progress: 55 });
  await set({ progress: 85 });

  const o = await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(orderId).first();
  const mulai = new Date();
  const berakhir = new Date(mulai.getTime() + o.durasi_jam * 3600_000);
  await set({
    status: 'aktif',
    progress: 100,
    host: `103.44.12.${20 + Math.floor(Math.random() * 200)}:3389`,
    username: `xy_${o.kode.toLowerCase().replace('-', '')}`,
    password: `Xy#${Math.floor(Math.random() * 9999)}ok`,
    mulai: mulai.toISOString(),
    berakhir: berakhir.toISOString(),
  });
}

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
      // relay ke peserta lain di room yang sama (mis. user <-> CS)
      this.kirimSemua(JSON.stringify(m), server);
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
