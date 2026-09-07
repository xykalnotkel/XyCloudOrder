/**
 * ============================================================
 *  XyCloudStore - Unggah gambar (Cloudinary, tanda tangan server)
 * ============================================================
 *  Dipakai untuk gambar produk, bukti transfer, lampiran chat,
 *  dan foto pada ulasan. Kunci rahasia tidak pernah keluar dari Worker.
 */

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function sha1(teks) {
  return hex(await crypto.subtle.digest('SHA-1', new TextEncoder().encode(teks)));
}

/**
 * Unggah gambar. `dataUri` boleh berupa `data:image/png;base64,...`
 * atau URL http/https yang bisa diambil Cloudinary.
 */
export async function unggahGambar(env, { dataUri, folder = 'xycloudstore' }) {
  if (!env.CLOUDINARY_CLOUD || !env.CLOUDINARY_KEY || !env.CLOUDINARY_SECRET) {
    return { ok: false, alasan: 'Kredensial Cloudinary belum diatur' };
  }
  if (!dataUri) return { ok: false, alasan: 'Tidak ada berkas' };

  const timestamp = Math.floor(Date.now() / 1000);
  // parameter yang ikut ditandatangani harus urut abjad
  const tandaTangan = await sha1(`folder=${folder}&timestamp=${timestamp}${env.CLOUDINARY_SECRET}`);

  const form = new FormData();
  form.append('file', dataUri);
  form.append('api_key', env.CLOUDINARY_KEY);
  form.append('timestamp', String(timestamp));
  form.append('folder', folder);
  form.append('signature', tandaTangan);

  try {
    const r = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/upload`, {
      method: 'POST',
      body: form,
    });
    const j = await r.json();
    if (!r.ok || j.error) return { ok: false, alasan: j.error?.message || `HTTP ${r.status}` };
    return { ok: true, url: j.secure_url, id: j.public_id, lebar: j.width, tinggi: j.height };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/**
 * Ubah URL Cloudinary menjadi tautan milik domain sendiri.
 *
 *   https://res.cloudinary.com/awan/image/upload/v123/xycloudstore/produk/abc.png
 *   -> https://api.xycloud.my.id/img/m/xycloudstore/produk/abc.png
 *
 * Selain menyembunyikan penyedia penyimpanan, jalur ini juga
 * memampatkan gambar otomatis lewat transformasi Cloudinary.
 */
export function samarkanGambar(env, url, ukuran = 'm') {
  if (!url || typeof url !== 'string') return url;
  const dasar = env.PUBLIC_URL || 'https://api.xycloud.my.id';

  const cocok = url.match(/res\.cloudinary\.com\/[^/]+\/image\/upload\/(?:[^/]+\/)*?(?:v\d+\/)?(.+)$/);
  if (!cocok) return url;
  return `${dasar}/img/${ukuran}/${cocok[1]}`;
}

/** Transformasi untuk tiap ukuran: tajam tapi ringan. */
export const UKURAN_GAMBAR = {
  s: 'f_auto,q_auto:good,c_limit,w_320,dpr_2.0',
  t: 'f_auto,q_auto:good,c_limit,w_560,dpr_2.0',
  m: 'f_auto,q_auto:good,c_limit,w_900,dpr_2.0',
  l: 'f_auto,q_auto:good,c_limit,w_1440',
  o: 'f_auto,q_auto:best',
  // versi buram untuk konten yang ditandai sensitif
  blur: 'f_auto,q_auto:low,c_limit,w_420,e_blur:1600',
};

/** Ambil gambar dari Cloudinary lewat Worker sendiri, lalu simpan di singgahan tepi. */
export async function layaniGambar(env, jalur, req) {
  const potong = jalur.replace(/^\/img\//, '');
  const pisah = potong.split('/');
  const ukuran = UKURAN_GAMBAR[pisah[0]] ? pisah.shift() : 'm';
  const publicId = pisah.join('/');

  if (!publicId || !env.CLOUDINARY_CLOUD) return new Response('Not found', { status: 404 });

  const asal = `https://res.cloudinary.com/${env.CLOUDINARY_CLOUD}/image/upload/${UKURAN_GAMBAR[ukuran]}/${publicId}`;

  // teruskan Accept supaya Cloudinary memilih WebP atau AVIF sesuai kemampuan peramban
  const terima = req?.headers.get('accept') || 'image/avif,image/webp,image/*,*/*';
  const jawab = await fetch(asal, {
    headers: { Accept: terima },
    cf: { cacheTtl: 604800, cacheEverything: true },
  });
  if (!jawab.ok) return new Response('Not found', { status: 404 });

  const kepala = new Headers(jawab.headers);
  kepala.set('Cache-Control', 'public, max-age=604800, immutable');
  kepala.set('X-Content-Type-Options', 'nosniff');
  kepala.set('Vary', 'Accept');
  kepala.delete('set-cookie');
  return new Response(jawab.body, { status: 200, headers: kepala });
}
