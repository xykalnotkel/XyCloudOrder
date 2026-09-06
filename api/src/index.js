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

    if (path === '/health') return json({ ok: true, at: new Date().toISOString() }, 200, env);

    if (!path.startsWith('/api/')) return err('Not found', 404, env);
    const p = path.slice(5);

    try {
      // ---------------- AUTH ----------------
      if (p === 'auth/login' && req.method === 'POST') {
        const { email, password } = await req.json();
        const u = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first();
        if (!u || u.password !== password) return err('Email atau password salah', 401, env);
        const token = await sign({ sub: u.id, email: u.email, iat: Date.now() }, env.JWT_SECRET);
        delete u.password;
        return json({ token, user: u }, 200, env);
      }

      if (p === 'auth/register' && req.method === 'POST') {
        const { nama, email, password, phone } = await req.json();
        const id = uid('u_');
        await env.DB.prepare(
          'INSERT INTO users (id,nama,email,password,phone,saldo,tier) VALUES (?,?,?,?,?,0,\'basic\')'
        ).bind(id, nama, email, password, phone || null).run();
        const token = await sign({ sub: id, email }, env.JWT_SECRET);
        return json({ token, user: { id, nama, email, phone, saldo: 0, tier: 'basic' } }, 201, env);
      }

      // ---------------- KATALOG (publik) ----------------
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
          await env.DB.prepare(
            `INSERT OR REPLACE INTO akun_produk
             (id,nama,kategori,deskripsi,harga,harga_coret,stok,rating,terjual,gambar,fitur,garansi)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`
          ).bind(b.id || uid('ak-'), b.nama, b.kategori, b.deskripsi || '', b.harga, b.harga_coret || 0,
                 b.stok || 0, b.rating || 5, b.terjual || 0, b.gambar || '',
                 JSON.stringify(b.fitur || []), b.garansi || '30 hari').run();
          return json({ ok: true }, 201, env);
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
            `SELECT m.room, u.nama, u.email, COUNT(*) total,
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

        return err('Endpoint admin tidak dikenal', 404, env);
      }

      if (p === 'akun/produk' && req.method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM akun_produk').all();
        return json(results.map(r => ({ ...r, fitur: JSON.parse(r.fitur || '[]') })), 200, env);
      }

      // ---------------- butuh login ----------------
      const me = await auth(req, env);
      if (!me) return err('Unauthorized', 401, env);
      const room = `user:${me.sub}`;

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

        return json({
          kode: 'AK-' + Math.floor(1000 + Math.random() * 8999),
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
        const { nominal } = await req.json();
        await env.DB.batch([
          env.DB.prepare('UPDATE users SET saldo = saldo + ? WHERE id = ?').bind(nominal, me.sub),
          env.DB.prepare('INSERT INTO transaksi (id,user_id,judul,tipe,nominal) VALUES (?,?,?,?,?)')
            .bind(uid('t_'), me.sub, 'Top up saldo', 'topup', nominal),
        ]);
        const u = await env.DB.prepare('SELECT saldo FROM users WHERE id = ?').bind(me.sub).first();
        ctx.waitUntil(push(env, room, 'wallet.update', { saldo: u.saldo }));
        return json({ saldo: u.saldo }, 200, env);
      }

      // ---- customer service ----
      if (p === 'cs/messages' && req.method === 'GET') {
        const { results } = await env.DB
          .prepare('SELECT * FROM cs_messages WHERE room = ? ORDER BY waktu ASC LIMIT 200')
          .bind(room).all();
        return json(results, 200, env);
      }

      if (p === 'cs/messages' && req.method === 'POST') {
        const { teks } = await req.json();
        const msg = { id: uid('m_'), room, dari: 'user', teks, waktu: new Date().toISOString() };
        await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
          .bind(msg.id, room, me.sub, 'user', teks, msg.waktu).run();
        ctx.waitUntil(Promise.all([
          push(env, room, 'chat.message', msg),
          push(env, 'cs:inbox', 'chat.message', { ...msg, user_id: me.sub }), // dashboard admin
        ]));
        return json(msg, 201, env);
      }

      // ---- endpoint untuk dashboard admin/CS ----
      if (p === 'cs/reply' && req.method === 'POST') {
        const { room: target, teks } = await req.json();
        const msg = { id: uid('m_'), room: target, dari: 'cs', teks, waktu: new Date().toISOString() };
        await env.DB.prepare('INSERT INTO cs_messages (id,room,user_id,dari,teks,waktu) VALUES (?,?,?,?,?,?)')
          .bind(msg.id, target, target.split(':')[1], 'cs', teks, msg.waktu).run();
        ctx.waitUntil(push(env, target, 'chat.message', msg));
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
