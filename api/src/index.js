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
import { kirimEmail } from './mail.js';
import { kirimPush, siarkanPush } from './push.js';
import { unggahGambar, samarkanGambar, layaniGambar } from './upload.js';
import { penyediaBayar, metodeTersedia, buatTagihan, bacaPemberitahuan } from './bayar.js';
import { halamanLegal, isiLegal } from './legal.js';
import { SKEMA_APLIKASI, providerSiap, urlMulai, ambilProfil, halamanKembali, verifikasiIdTokenGoogle } from './oauth.js';

const json = (data, status = 200, env) =>
  new Response(JSON.stringify({ data }), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env?.ALLOW_ORIGIN || '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'Cache-Control': 'no-store',
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

/**
 * Pembatas laju sederhana berbasis D1.
 * Mengembalikan true kalau permintaan masih boleh diproses.
 */
async function bolehLanjut(env, kunci, maks, detik) {
  try {
    const sekarang = Date.now();
    const row = await env.DB.prepare('SELECT jumlah, sampai FROM batas WHERE kunci = ?').bind(kunci).first();

    if (!row || new Date(row.sampai).getTime() < sekarang) {
      const sampai = new Date(sekarang + detik * 1000).toISOString();
      await env.DB.prepare(
        'INSERT INTO batas (kunci,jumlah,sampai) VALUES (?,1,?) ON CONFLICT(kunci) DO UPDATE SET jumlah=1, sampai=?'
      ).bind(kunci, sampai, sampai).run();
      return true;
    }

    if (row.jumlah >= maks) return false;
    await env.DB.prepare('UPDATE batas SET jumlah = jumlah + 1 WHERE kunci = ?').bind(kunci).run();
    return true;
  } catch (_) {
    // kalau tabel bermasalah, jangan sampai layanan ikut mati
    return true;
  }
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

/// Masa berlaku token: 30 hari.
const MASA_TOKEN = 30 * 24 * 60 * 60 * 1000;

/**
 * Ambil akun berdasarkan email dari penyedia sosial, atau buat baru.
 * Akun sosial otomatis dianggap terverifikasi.
 */
async function akunSosial(env, ctx, prof, provider) {
  let u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(prof.email).first();

  if (!u) {
    const idBaru = uid('u_');
    await env.DB.prepare(
      "INSERT INTO users (id,nama,email,password,phone,saldo,tier,email_verified,foto) VALUES (?,?,?,?,?,0,'basic',1,?)"
    ).bind(idBaru, prof.nama, prof.email, `sosial:${provider}`, null, prof.foto || null).run();

    const sapa = {
      id: uid('m_'),
      room: `user:${idBaru}`,
      teks: `Halo ${prof.nama.split(' ')[0]}, aku Kirana dari XyCloudStore. Ada yang bisa aku bantu hari ini?`,
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
  if (isi.exp && Number(isi.exp) < Date.now()) return null;
  return isi;
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
    const host = (req.headers.get('host') || '').toLowerCase();
    const domainWeb = !host.startsWith('api.') && !host.startsWith('admin.');

    // ---------- situs publik ----------
    if (domainWeb && (path === '/' || !path.includes('.')) && !path.startsWith('/api/')
        && !path.startsWith('/img/') && !path.startsWith('/unduh/') && !path.startsWith('/legal/')
        && !path.startsWith('/brand/') && !path.startsWith('/bayar/')) {
      return new Response(WEB_HTML, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'public, max-age=300',
          'X-Content-Type-Options': 'nosniff',
          'Referrer-Policy': 'strict-origin-when-cross-origin',
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
      return new Response(ADMIN_HTML, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
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

    if (path.startsWith('/img/')) return layaniGambar(env, path);

    if (path === '/brand/logo.png') {
      return new Response(LOGO_PNG, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' },
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
        const t = await env.DB.prepare("SELECT * FROM topup WHERE id = ? AND status != 'disetujui'")
          .bind(hasil.id).first();
        if (t) {
          const waktu = new Date().toISOString();
          await env.DB.batch([
            env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(t.nominal, t.user_id),
            env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
              .bind(uid('t_'), t.user_id, 'Top up saldo otomatis', 'topup', t.nominal),
            env.DB.prepare("UPDATE topup SET status='disetujui', catatan=?, diproses=? WHERE id=?")
              .bind(`Lunas otomatis lewat ${provider}`, waktu, t.id),
          ]);

          const u = await env.DB.prepare('SELECT saldo, nama, email FROM users WHERE id = ?')
            .bind(t.user_id).first();
          ctx.waitUntil(push(env, `user:${t.user_id}`, 'wallet.update', { saldo: u?.saldo ?? 0 }));
          ctx.waitUntil(kirimPush(env, {
            userId: t.user_id,
            judul: 'Saldo berhasil ditambahkan',
            pesan: `Pembayaran Rp${Number(t.nominal).toLocaleString('id-ID')} sudah kami terima.`,
            data: { tipe: 'wallet' },
          }));
          if (u?.email) {
            ctx.waitUntil(kirimEmail(env, {
              to: u.email, template: 'struk',
              data: { nama: u.nama, kode: t.id.toUpperCase(), judul: 'Top up saldo', total: t.nominal, metode: t.metode },
            }));
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

    try {
      // ---------------- AGEN PC HOST ----------------
      // Agen memakai kode rahasianya sendiri, bukan token pengguna.
      if (p.startsWith('agen/')) {
        const kode = req.headers.get('x-agen-kode') || '';
        if (!kode) return err('Kode agen tidak dikirim', 401, env);
        const agen = await env.DB.prepare('SELECT * FROM agen WHERE kode = ?').bind(kode).first();
        if (!agen) return err('Agen tidak dikenal', 401, env);

        // ---- laporan hidup + spesifikasi ----
        if (p === 'agen/heartbeat' && req.method === 'POST') {
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

          return json({
            ok: true,
            perintah: results.map((r) => ({ ...r, muatan: r.muatan ? JSON.parse(r.muatan) : {} })),
          }, 200, env);
        }

        // ---- agen melaporkan hasil sebuah perintah ----
        if (p.startsWith('agen/perintah/') && req.method === 'POST') {
          const id = p.split('/')[2];
          const b = await req.json().catch(() => ({}));
          await env.DB.prepare("UPDATE perintah SET status = ?, hasil = ?, diproses = ? WHERE id = ? AND agen_id = ?")
            .bind(b.ok === false ? 'gagal' : 'selesai', JSON.stringify(b), new Date().toISOString(), id, agen.id)
            .run();

          // perbarui sesi yang terkait
          if (b.sesi_id) {
            const status = b.status || (b.ok === false ? 'gagal' : 'siap');
            await env.DB.prepare('UPDATE sesi SET status = ?, host = COALESCE(?, host), catatan = ? WHERE id = ?')
              .bind(status, b.host || null, b.catatan || null, b.sesi_id).run();

            const sesi = await env.DB.prepare('SELECT * FROM sesi WHERE id = ?').bind(b.sesi_id).first();
            if (sesi) {
              ctx.waitUntil(push(env, `user:${sesi.user_id}`, 'sesi.update', sesi));
              if (status === 'siap') {
                ctx.waitUntil(kirimPush(env, {
                  userId: sesi.user_id,
                  judul: 'PC kamu siap dimainkan',
                  pesan: 'Buka aplikasi lalu tekan Mulai Main untuk menyambung.',
                  data: { tipe: 'sesi', id: sesi.id },
                }));
              }
            }
          }
          return json({ ok: true }, 200, env);
        }

        return err('Endpoint agen tidak dikenal', 404, env);
      }

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
          syarat.push('(judul LIKE ? OR isi LIKE ?)');
          nilai.push(`%${cari}%`, `%${cari}%`);
        }
        if (syarat.length) sql += ' WHERE ' + syarat.join(' AND ');
        sql += ' ORDER BY disematkan DESC, dibuat DESC LIMIT ? OFFSET ?';
        nilai.push(per, (halaman - 1) * per);

        // ambil tier penulis supaya lencana member tampil di komunitas
        sql = sql.replace(
          'SELECT * FROM forum_post',
          `SELECT f.*, COALESCE(u.tier, CASE WHEN f.user_id = 'admin' THEN 'admin' ELSE 'basic' END) AS tier,
                  COALESCE(u.foto, f.foto) AS foto
           FROM forum_post f LEFT JOIN users u ON u.id = f.user_id`
        ).replace(/\bWHERE (kategori|\()/, 'WHERE f.$1')
         .replace('ORDER BY disematkan DESC, dibuat DESC', 'ORDER BY f.disematkan DESC, f.dibuat DESC');

        const { results } = await env.DB.prepare(sql).bind(...nilai).all();
        return json(results.map((r) => ({ ...r, gambar: samarkanGambar(env, r.gambar, 'm'), foto: samarkanGambar(env, r.foto, 's') })), 200, env);
      }

      if (p.startsWith('forum/') && p.split('/').length === 2 && req.method === 'GET') {
        const id = p.split('/')[1];
        const post = await env.DB.prepare(
          `SELECT f.*, COALESCE(u.tier, CASE WHEN f.user_id = 'admin' THEN 'admin' ELSE 'basic' END) AS tier,
                  COALESCE(u.foto, f.foto) AS foto
           FROM forum_post f LEFT JOIN users u ON u.id = f.user_id WHERE f.id = ?`
        ).bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);

        const { results } = await env.DB.prepare(
          `SELECT b.*, COALESCE(u.tier, CASE WHEN b.admin = 1 THEN 'admin' ELSE 'basic' END) AS tier,
                  COALESCE(u.foto, b.foto) AS foto
           FROM forum_balasan b LEFT JOIN users u ON u.id = b.user_id
           WHERE b.post_id = ? ORDER BY b.dibuat ASC LIMIT 200`
        ).bind(id).all();

        return json({
          post: { ...post, gambar: samarkanGambar(env, post.gambar, 'l'), foto: samarkanGambar(env, post.foto, 's') },
          balasan: results.map((r) => ({ ...r, foto: samarkanGambar(env, r.foto, 's') })),
        }, 200, env);
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
        }, 200, env);
      }

      // ---------------- LOGIN GOOGLE NATIVE (tanpa browser) ----------------
      if (p === 'auth/google/native' && req.method === 'POST') {
        const { id_token: idToken } = await req.json().catch(() => ({}));
        const prof = await verifikasiIdTokenGoogle(env, idToken);
        if (!prof.ok) return err(prof.alasan, 401, env);

        const u = await akunSosial(env, ctx, prof, 'google');
        const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
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

        const u = await akunSosial(env, ctx, prof, provider);

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
        return new Response(
          halamanKembali(`${SKEMA_APLIKASI}://auth?token=${encodeURIComponent(token)}`, `Halo ${u.nama.split(' ')[0]}`),
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      }

      // ---------------- AUTH ----------------
      if (p === 'auth/login' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `login:${ip}`, 12, 300))) {
          return err('Terlalu banyak percobaan masuk. Coba lagi 5 menit lagi.', 429, env);
        }
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

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
        delete u.password;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'auth/register' && req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!(await bolehLanjut(env, `daftar:${ip}`, 6, 3600))) {
          return err('Terlalu banyak pendaftaran dari perangkat ini. Coba lagi nanti.', 429, env);
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
        if (!(await bolehLanjut(env, `verif:${ip}`, 20, 900))) {
          return err('Terlalu banyak percobaan kode. Coba lagi nanti.', 429, env);
        }
        const email = String(body.email || '').trim().toLowerCase();
        const kode = String(body.kode || '').trim();

        const u = await env.DB.prepare('SELECT * FROM users WHERE lower(email) = ?').bind(email).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);
        if (u.email_verified) {
          const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
          delete u.password;
          return json({ token, user: u }, 200, env);
        }

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

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
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

        const token = await sign({ sub: u.id, email: u.email, iat: Date.now(), exp: Date.now() + MASA_TOKEN }, env.JWT_SECRET);
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
        if (!(await bolehLanjut(env, `admin:${ip}`, 240, 60))) {
          return err('Terlalu banyak permintaan admin.', 429, env);
        }
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
            judul: 'Kirana membalas pesanmu',
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
            const tujuan = [p2?.user_id, ...results.map((r) => r.user_id)];
            const cuplikan = baris.isi.length > 80 ? `${baris.isi.slice(0, 80)}...` : baris.isi;
            await pushForum(env, tujuan, {
              judul: 'Kirana membalas diskusimu',
              pesan: cuplikan,
              data: { tipe: 'forum', id },
            });
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

      // ---- profil pengguna yang sedang login ----
      if (p === 'me' && req.method === 'GET') {
        const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(me.sub).first();
        if (!u) return err('Akun tidak ditemukan', 404, env);
        delete u.password;
        return json(u, 200, env);
      }

      // ---- mulai sesi main ----
      if (p === 'sesi/mulai' && req.method === 'POST') {
        const b = await req.json().catch(() => ({}));
        const orderId = String(b.order_id || '');

        const order = await env.DB.prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?')
          .bind(orderId, me.sub).first();
        if (!order) return err('Order tidak ditemukan', 404, env);
        if (!['dibayar', 'provisioning', 'aktif'].includes(order.status)) {
          return err('Order ini belum siap dimainkan', 409, env);
        }

        // sesi yang masih hidup dipakai ulang
        const lama = await env.DB
          .prepare("SELECT * FROM sesi WHERE order_id = ? AND status NOT IN ('selesai','gagal') ORDER BY dibuat DESC LIMIT 1")
          .bind(orderId).first();
        if (lama) return json(lama, 200, env);

        // cari unit yang menganggur untuk paket ini.
        // "hidup" dinilai dari laporan terakhir, bukan label status,
        // supaya unit yang baru selesai dipakai langsung bisa dipilih lagi.
        const ambang = new Date(Date.now() - 90000).toISOString();
        const agen = await env.DB.prepare(
          `SELECT * FROM agen
           WHERE (sesi_aktif IS NULL OR sesi_aktif = '')
             AND terakhir IS NOT NULL AND terakhir > ?
             AND (plan_id IS NULL OR plan_id = ?)
           ORDER BY terakhir DESC LIMIT 1`
        ).bind(ambang, order.plan_id).first();

        if (!agen) {
          return err('Semua unit sedang dipakai. Coba beberapa menit lagi atau hubungi admin.', 503, env);
        }

        const id = uid('s_');
        const durasi = (order.durasi_jam || 1) * 60;
        await env.DB.batch([
          env.DB.prepare(
            "INSERT INTO sesi (id,order_id,user_id,agen_id,status,durasi_menit,host) VALUES (?,?,?,?,'menyiapkan',?,?)"
          ).bind(id, orderId, me.sub, agen.id, durasi, agen.host || null),
          env.DB.prepare('UPDATE agen SET sesi_aktif = ? WHERE id = ?').bind(id, agen.id),
          env.DB.prepare("INSERT INTO perintah (id,agen_id,jenis,muatan) VALUES (?,?,'mulai_sesi',?)")
            .bind(uid('c_'), agen.id, JSON.stringify({
              sesi_id: id,
              order_id: orderId,
              user_id: me.sub,
              durasi_menit: durasi,
              plan: order.plan_nama,
            })),
        ]);

        const sesi = await env.DB.prepare('SELECT * FROM sesi WHERE id = ?').bind(id).first();
        return json(sesi, 201, env);
      }

      // ---- pantau sesi ----
      if (p.startsWith('sesi/') && p.split('/').length === 2 && req.method === 'GET') {
        const sesi = await env.DB.prepare('SELECT * FROM sesi WHERE id = ? AND user_id = ?')
          .bind(p.split('/')[1], me.sub).first();
        if (!sesi) return err('Sesi tidak ditemukan', 404, env);
        return json(sesi, 200, env);
      }

      // ---- kirim PIN dari aplikasi streaming ke host ----
      if (p.startsWith('sesi/') && p.endsWith('/pin') && req.method === 'POST') {
        const id = p.split('/')[1];
        const { pin } = await req.json().catch(() => ({}));
        if (!/^[0-9]{4}$/.test(String(pin || ''))) return err('PIN harus 4 angka', 400, env);

        const sesi = await env.DB.prepare('SELECT * FROM sesi WHERE id = ? AND user_id = ?').bind(id, me.sub).first();
        if (!sesi) return err('Sesi tidak ditemukan', 404, env);

        await env.DB.batch([
          env.DB.prepare("UPDATE sesi SET pin = ?, status = 'pairing' WHERE id = ?").bind(String(pin), id),
          env.DB.prepare("INSERT INTO perintah (id,agen_id,jenis,muatan) VALUES (?,?,'pasangkan',?)")
            .bind(uid('c_'), sesi.agen_id, JSON.stringify({ sesi_id: id, pin: String(pin) })),
        ]);
        return json({ ok: true, pesan: 'PIN dikirim ke PC, tunggu beberapa detik.' }, 200, env);
      }

      // ---- akhiri sesi ----
      if (p.startsWith('sesi/') && p.endsWith('/akhiri') && req.method === 'POST') {
        const id = p.split('/')[1];
        const sesi = await env.DB.prepare('SELECT * FROM sesi WHERE id = ? AND user_id = ?').bind(id, me.sub).first();
        if (!sesi) return err('Sesi tidak ditemukan', 404, env);

        await env.DB.batch([
          env.DB.prepare("UPDATE sesi SET status = 'selesai', berakhir = ? WHERE id = ?")
            .bind(new Date().toISOString(), id),
          env.DB.prepare("UPDATE agen SET sesi_aktif = NULL WHERE id = ?").bind(sesi.agen_id),
          env.DB.prepare("INSERT INTO perintah (id,agen_id,jenis,muatan) VALUES (?,?,'akhiri_sesi',?)")
            .bind(uid('c_'), sesi.agen_id, JSON.stringify({ sesi_id: id })),
        ]);
        return json({ ok: true }, 200, env);
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
        return json(u, 200, env);
      }

      // ---- ganti password ----
      if (p === 'me/password' && req.method === 'POST') {
        const { lama, baru } = await req.json().catch(() => ({}));
        if (String(baru || '').length < 6) return err('Password baru minimal 6 karakter', 400, env);

        const u = await env.DB.prepare('SELECT password FROM users WHERE id = ?').bind(me.sub).first();
        const akunSosialSaja = String(u.password || '').startsWith('sosial:');
        if (!akunSosialSaja && !(await cocokPw(String(lama || ''), u.password))) {
          return err('Password lama salah', 401, env);
        }
        await env.DB.prepare('UPDATE users SET password = ? WHERE id = ?')
          .bind(await buatPw(String(baru)), me.sub).run();
        return json({ ok: true }, 200, env);
      }

      // ---- forum: buat diskusi ----
      if (p === 'forum' && req.method === 'POST') {
        if (!(await bolehLanjut(env, `forum:${me.sub}`, 10, 3600))) {
          return err('Kamu sudah membuat cukup banyak diskusi. Coba lagi nanti.', 429, env);
        }
        const b = await req.json().catch(() => ({}));
        const judul = String(b.judul || '').trim();
        const isi = String(b.isi || '').trim();
        if (judul.length < 5) return err('Judul minimal 5 karakter', 400, env);
        if (isi.length < 10) return err('Isi diskusi minimal 10 karakter', 400, env);

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

      // ---- forum: balas ----
      if (p.startsWith('forum/') && p.endsWith('/balas') && req.method === 'POST') {
        const id = p.split('/')[1];
        const { isi } = await req.json().catch(() => ({}));
        if (String(isi || '').trim().length < 2) return err('Balasan terlalu pendek', 400, env);

        const post = await env.DB.prepare('SELECT id FROM forum_post WHERE id = ?').bind(id).first();
        if (!post) return err('Diskusi tidak ditemukan', 404, env);

        const u = await env.DB.prepare('SELECT nama, foto FROM users WHERE id = ?').bind(me.sub).first();
        const baris = {
          id: uid('fb_'), post_id: id, user_id: me.sub, nama: u?.nama || 'Pengguna',
          foto: u?.foto || null, isi: String(isi).trim(), admin: 0, dibuat: new Date().toISOString(),
        };
        await env.DB.batch([
          env.DB.prepare('INSERT INTO forum_balasan (id,post_id,user_id,nama,foto,isi,dibuat) VALUES (?,?,?,?,?,?,?)')
            .bind(baris.id, id, me.sub, baris.nama, baris.foto, baris.isi, baris.dibuat),
          env.DB.prepare('UPDATE forum_post SET balasan = balasan + 1 WHERE id = ?').bind(id),
        ]);

        ctx.waitUntil(push(env, 'forum', 'forum.balasan', baris));

        // pemberitahuan ke pemilik diskusi dan peserta lain
        ctx.waitUntil((async () => {
          const p2 = await env.DB.prepare('SELECT user_id, judul FROM forum_post WHERE id = ?').bind(id).first();
          const { results } = await env.DB
            .prepare('SELECT DISTINCT user_id FROM forum_balasan WHERE post_id = ? AND user_id != ?')
            .bind(id, me.sub).all();

          const tujuan = [p2?.user_id, ...results.map((r) => r.user_id)].filter((x) => x && x !== me.sub);
          const judulPendek = (p2?.judul || 'diskusi').slice(0, 40);
          const cuplikan = baris.isi.length > 80 ? `${baris.isi.slice(0, 80)}...` : baris.isi;

          await pushForum(env, tujuan, {
            judul: `${baris.nama} membalas "${judulPendek}"`,
            pesan: cuplikan,
            data: { tipe: 'forum', id },
          });
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

        // beri tahu pemilik maksimal sekali per 30 menit per diskusi
        if (!ada) {
          ctx.waitUntil((async () => {
            if (!(await bolehLanjut(env, `sukaforum:${id}`, 1, 1800))) return;
            const p2 = await env.DB.prepare('SELECT user_id, judul FROM forum_post WHERE id = ?').bind(id).first();
            if (!p2 || p2.user_id === me.sub) return;
            await pushForum(env, [p2.user_id], {
              judul: 'Diskusimu disukai',
              pesan: `"${(p2.judul || '').slice(0, 50)}" mendapat ${post?.suka ?? 1} suka.`,
              data: { tipe: 'forum', id },
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

      // ---- customer service ----
      if (p === 'cs/messages' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM cs_messages WHERE room = ? ORDER BY waktu ASC LIMIT 200')
          .bind(room).all();
        return json(results.map((r) => ({ ...r, gambar: samarkanGambar(env, r.gambar, 'm') })), 200, env);
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
          judul: 'Kirana membalas pesanmu',
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
