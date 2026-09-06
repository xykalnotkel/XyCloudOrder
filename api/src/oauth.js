/**
 * ============================================================
 *  XyCloudStore - Login sosial (OAuth 2.0)
 * ============================================================
 *  Alur:
 *    aplikasi  ->  /api/auth/{provider}/start
 *              ->  halaman izin Google / Facebook
 *              ->  /api/auth/{provider}/callback
 *              ->  balik ke aplikasi lewat xycloudstore://auth?token=...
 *
 *  Tidak butuh Firebase dan tidak butuh sidik jari SHA-1, karena
 *  pertukaran kode dilakukan di server memakai client rahasia.
 */

export const SKEMA_APLIKASI = 'xycloudstore';

export function providerSiap(env) {
  return {
    google: Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET),
    facebook: Boolean(env.FACEBOOK_APP_ID && env.FACEBOOK_APP_SECRET),
  };
}

const alamatCallback = (env, provider) =>
  `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/api/auth/${provider}/callback`;

/** URL halaman izin milik penyedia. */
export function urlMulai(env, provider, state) {
  if (provider === 'google') {
    const q = new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      redirect_uri: alamatCallback(env, 'google'),
      response_type: 'code',
      scope: 'openid email profile',
      access_type: 'online',
      include_granted_scopes: 'true',
      prompt: 'select_account',
      state,
    });
    return `https://accounts.google.com/o/oauth2/v2/auth?${q}`;
  }
  if (provider === 'facebook') {
    const q = new URLSearchParams({
      client_id: env.FACEBOOK_APP_ID,
      redirect_uri: alamatCallback(env, 'facebook'),
      response_type: 'code',
      scope: 'email,public_profile',
      state,
    });
    return `https://www.facebook.com/v21.0/dialog/oauth?${q}`;
  }
  return null;
}

/** Tukar kode dengan profil pengguna: { email, nama, foto }. */
export async function ambilProfil(env, provider, code) {
  if (provider === 'google') {
    const r = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: env.GOOGLE_CLIENT_ID,
        client_secret: env.GOOGLE_CLIENT_SECRET,
        redirect_uri: alamatCallback(env, 'google'),
        grant_type: 'authorization_code',
      }),
    });
    const t = await r.json();
    if (!r.ok || !t.access_token) return { ok: false, alasan: t.error_description || t.error || 'Gagal menukar kode' };

    const p = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
      headers: { Authorization: `Bearer ${t.access_token}` },
    }).then((x) => x.json());

    if (!p.email) return { ok: false, alasan: 'Akun Google tidak membagikan email' };
    return { ok: true, email: String(p.email).toLowerCase(), nama: p.name || p.email.split('@')[0], foto: p.picture };
  }

  if (provider === 'facebook') {
    const q = new URLSearchParams({
      client_id: env.FACEBOOK_APP_ID,
      client_secret: env.FACEBOOK_APP_SECRET,
      redirect_uri: alamatCallback(env, 'facebook'),
      code,
    });
    const t = await fetch(`https://graph.facebook.com/v21.0/oauth/access_token?${q}`).then((x) => x.json());
    if (!t.access_token) return { ok: false, alasan: t.error?.message || 'Gagal menukar kode' };

    const p = await fetch(
      `https://graph.facebook.com/me?fields=id,name,email,picture.width(256)&access_token=${t.access_token}`
    ).then((x) => x.json());

    const email = p.email ? String(p.email).toLowerCase() : `${p.id}@facebook.local`;
    return { ok: true, email, nama: p.name || 'Pengguna Facebook', foto: p.picture?.data?.url };
  }

  return { ok: false, alasan: 'Penyedia tidak dikenal' };
}

/** Halaman kecil yang melempar pengguna kembali ke aplikasi. */
export function halamanKembali(tujuan, pesan) {
  return `<!DOCTYPE html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>XyCloudStore</title>
<meta http-equiv="refresh" content="0;url=${tujuan}"></head>
<body style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  background:linear-gradient(135deg,#6C2BE2,#4A12B8);color:#fff;display:flex;align-items:center;
  justify-content:center;height:100vh;text-align:center">
  <div>
    <div style="font-size:19px;font-weight:800;letter-spacing:-.4px">${pesan}</div>
    <div style="opacity:.8;font-size:13.5px;margin-top:10px">Kembali ke aplikasi XyCloudStore...</div>
    <a href="${tujuan}" style="display:inline-block;margin-top:22px;background:#fff;color:#6C2BE2;
      text-decoration:none;font-weight:800;font-size:14px;padding:12px 24px;border-radius:99px">Buka Aplikasi</a>
  </div>
  <script>setTimeout(function(){location.href=${JSON.stringify(tujuan)}},250)</script>
</body></html>`;
}

/**
 * Verifikasi ID token dari Google Sign-In native (aplikasi Android).
 * Token diperiksa langsung ke Google, lalu dipastikan audiensnya
 * memang milik proyek kita.
 */
export async function verifikasiIdTokenGoogle(env, idToken) {
  if (!idToken) return { ok: false, alasan: 'Token kosong' };
  try {
    const r = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
    const p = await r.json();
    if (!r.ok || p.error_description) {
      return { ok: false, alasan: p.error_description || 'Token Google tidak valid' };
    }

    // audiens harus salah satu client milik proyek ini
    const diizinkan = [env.GOOGLE_CLIENT_ID, env.GOOGLE_CLIENT_ID_ANDROID]
      .filter(Boolean)
      .map((x) => x.trim());
    if (diizinkan.length && !diizinkan.includes(p.aud)) {
      return { ok: false, alasan: 'Aplikasi tidak dikenali oleh server' };
    }

    const penerbitSah = p.iss === 'accounts.google.com' || p.iss === 'https://accounts.google.com';
    if (!penerbitSah) return { ok: false, alasan: 'Penerbit token tidak sah' };
    if (Number(p.exp) * 1000 < Date.now()) return { ok: false, alasan: 'Token sudah kedaluwarsa' };
    if (!p.email) return { ok: false, alasan: 'Akun Google tidak membagikan email' };
    if (p.email_verified === 'false') return { ok: false, alasan: 'Email Google belum terverifikasi' };

    return {
      ok: true,
      email: String(p.email).toLowerCase(),
      nama: p.name || String(p.email).split('@')[0],
      foto: p.picture,
    };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}
