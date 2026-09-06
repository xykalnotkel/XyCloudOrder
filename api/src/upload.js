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
