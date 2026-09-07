import { setelan, simpanSetelan } from './sistem.js';
import { unggahGambar } from './upload.js';

export class KontenError extends Error {
  constructor(pesan, status = 400) { super(pesan); this.status = status; }
}
const gagal = (pesan, status) => { throw new KontenError(pesan, status); };
const teks = (v, maks) => String(v ?? '').trim().slice(0, maks);

export function httpsAman(v) {
  try {
    const u = new URL(v);
    return u.protocol === 'https:' && !u.username && !u.password && (!u.port || u.port === '443');
  } catch { return false; }
}

export async function daftarPromosi(env, admin = false) {
  const { results } = await env.DB.prepare(admin
    ? 'SELECT * FROM promo_overlay ORDER BY urutan, dibuat DESC'
    : 'SELECT * FROM promo_overlay WHERE aktif = 1 ORDER BY urutan, dibuat DESC LIMIT 12').all();
  return results;
}

export async function simpanPromosi(env, b) {
  const id = b.id ? teks(b.id, 80) : 'pr_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) gagal('ID promo tidak valid.');
  const jenis = b.jenis === 'popup' ? 'popup' : 'floating';
  const aksi = ['url', 'sewa', 'akun', 'topup', 'komunitas', 'unduh'].includes(b.aksi) ? b.aksi : 'url';
  const target = teks(b.target, 1500);
  if (aksi === 'url' && !httpsAman(target)) gagal('Tujuan klik harus URL HTTPS yang lengkap.');
  let gambar = teks(b.gambar, 8 * 1024 * 1024);
  if (gambar.startsWith('data:')) {
    if (!/^data:image\/(png|jpe?g|webp|gif);base64,/.test(gambar) || gambar.length > 6 * 1024 * 1024) gagal('Gunakan gambar PNG, JPG, WebP atau GIF maksimal 4 MB.');
    const hasil = await unggahGambar(env, { dataUri: gambar, folder: 'xycloudstore/promo' });
    if (!hasil.ok) gagal(hasil.alasan, 502);
    gambar = hasil.url;
  }
  if (!httpsAman(gambar)) gagal('Unggah gambar atau isi URL gambar HTTPS.');
  const waktu = new Date().toISOString();
  await env.DB.prepare(`INSERT INTO promo_overlay
    (id,nama,jenis,gambar,aksi,target,posisi,platform,aktif,urutan,revisi,dibuat,diubah)
    VALUES (?,?,?,?,?,?,?,?,?,?,1,?,?) ON CONFLICT(id) DO UPDATE SET
    nama=excluded.nama,jenis=excluded.jenis,gambar=excluded.gambar,aksi=excluded.aksi,
    target=excluded.target,posisi=excluded.posisi,platform=excluded.platform,aktif=excluded.aktif,
    urutan=excluded.urutan,revisi=promo_overlay.revisi+1,diubah=excluded.diubah`)
    .bind(id, teks(b.nama, 100) || 'Promo', jenis, gambar, aksi, target,
      b.posisi === 'kiri' ? 'kiri' : 'kanan', ['app', 'web'].includes(b.platform) ? b.platform : 'semua',
      b.aktif === 0 ? 0 : 1, Math.max(0, Math.min(999, Number(b.urutan) || 0)), waktu, waktu).run();
  return { ok: true, id };
}

// Kunci GIPHY hanya dibaca server. Setelan dashboard disimpan terenkripsi di D1.
const kunciGiphy = async env => {
  if (!env.JWT_SECRET) gagal('Kunci enkripsi server belum dikonfigurasi.', 503);
  const bahan = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('xycloud:giphy:v1:' + env.JWT_SECRET));
  return crypto.subtle.importKey('raw', bahan, 'AES-GCM', false, ['encrypt', 'decrypt']);
};
const b64 = b => btoa(String.fromCharCode(...new Uint8Array(b)));
const unb64 = s => Uint8Array.from(atob(s), c => c.charCodeAt(0));

export async function ambilKunciGiphy(env) {
  if (env.GIPHY_API_KEY) return env.GIPHY_API_KEY;
  try {
    const paket = JSON.parse(await setelan(env, 'integrasi_giphy_terenkripsi', 'null'));
    if (!paket) return '';
    const isi = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(paket.iv) }, await kunciGiphy(env), unb64(paket.data));
    return new TextDecoder().decode(isi);
  } catch { return ''; }
}

export async function simpanKunciGiphy(env, key) {
  key = teks(key, 160);
  if (!/^[A-Za-z0-9_-]{10,160}$/.test(key)) gagal('Isi API key GIPHY yang valid.');
  const u = new URL('https://api.giphy.com/v1/stickers/trending');
  u.search = new URLSearchParams({ api_key: key, limit: '1', rating: 'g' });
  const r = await fetch(u, { signal: AbortSignal.timeout(10000) });
  if (!r.ok) gagal('GIPHY menolak key atau kuota sedang habis. Periksa key lalu coba lagi.', 400);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await kunciGiphy(env), new TextEncoder().encode(key));
  await simpanSetelan(env, 'integrasi_giphy_terenkripsi', JSON.stringify({ iv: b64(iv), data: b64(data) }));
  return { ok: true, siap: true };
}

export function mediaGiphy(g) {
  const im = g?.images?.fixed_height || g?.images?.downsized || g?.images?.original;
  if (!im) return null;
  const url = im.webp || im.url;
  if (!url || !urlStikerAman({}, url)) return null;
  return { url, mime: im.webp ? 'image/webp' : 'image/gif', nama: teks(g.title, 120) || 'Stiker GIPHY',
    lebar: Number(im.width) || 200, tinggi: Number(im.height) || 200,
    sumber: 'giphy', sumber_url: httpsAman(g.url) ? g.url : 'https://giphy.com', giphy_id: teks(g.id, 80) };
}

export async function cariGiphy(env, params) {
  const key = await ambilKunciGiphy(env);
  if (!key) return { siap: false, items: [], pesan: 'Pencarian GIPHY belum diaktifkan admin.' };
  const q = teks(params.get('q'), 80);
  const jenis = params.get('jenis') === 'gif' ? 'gifs' : 'stickers';
  const offset = Math.max(0, Math.min(499, parseInt(params.get('offset') || '0', 10) || 0));
  const u = new URL(`https://api.giphy.com/v1/${jenis}/${q ? 'search' : 'trending'}`);
  u.search = new URLSearchParams({ api_key: key, q, limit: '24', offset: String(offset), rating: 'g', lang: 'id' });
  const r = await fetch(u, { signal: AbortSignal.timeout(10000) });
  if (!r.ok) gagal('GIPHY sedang tidak tersedia atau kuota habis. Coba galeri atau koleksi lokal.', 502);
  const d = await r.json();
  return { siap: true, items: (d.data || []).map(mediaGiphy).filter(Boolean),
    berikutnya: offset + (d.data?.length || 0), ada_lagi: offset + (d.data?.length || 0) < (d.pagination?.total_count || 0) };
}

export function urlStikerAman(env, value) {
  if (!httpsAman(value)) return false;
  const u = new URL(value);
  if (/^(media\d*|i)\.giphy\.com$/.test(u.hostname)) return /\.(gif|webp|png)(?:$|\/)/i.test(u.pathname);
  return u.hostname === 'res.cloudinary.com' && u.pathname.startsWith(`/${env.CLOUDINARY_CLOUD}/image/upload/`)
    && /\/xycloudstore\/stiker\//.test(u.pathname) && /\.(webp|gif|png|jpe?g)$/i.test(u.pathname);
}

export function tipeBerkasStiker(bytes) {
  if (bytes.length < 12) return null;
  const s = String.fromCharCode(...bytes.slice(0, 12));
  if (s.startsWith('GIF87a') || s.startsWith('GIF89a')) return 'image/gif';
  if (s.startsWith('RIFF') && s.slice(8, 12) === 'WEBP') return 'image/webp';
  if (bytes[0] === 137 && s.slice(1, 4) === 'PNG') return 'image/png';
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return 'image/jpeg';
  return null;
}

export async function terimaStiker(env, value) {
  if (!value) return null;
  if (typeof value !== 'object' || Array.isArray(value)) gagal('Data stiker tidak valid.');
  let url = teks(value.url, 2000), mime = 'image/webp';
  let lebar = 0, tinggi = 0;
  if (value.data_uri) {
    const data = String(value.data_uri);
    const m = data.match(/^data:(image\/(?:webp|gif|png|jpe?g));base64,([A-Za-z0-9+/=]+)$/);
    if (!m || m[2].length > Math.ceil(2 * 1024 * 1024 * 4 / 3) + 4) gagal('Stiker harus WebP, GIF, PNG atau JPG, maksimal 2 MB.');
    let bytes;
    try { bytes = unb64(m[2]); } catch { gagal('Berkas stiker rusak.'); }
    mime = tipeBerkasStiker(bytes);
    if (!mime || (m[1].replace('image/jpg', 'image/jpeg') !== mime)) gagal('Isi berkas tidak sesuai format gambar.');
    const hasil = await unggahGambar(env, { dataUri: data, folder: 'xycloudstore/stiker' });
    if (!hasil.ok) gagal(hasil.alasan, 502);
    url = hasil.url; lebar = hasil.lebar; tinggi = hasil.tinggi;
  } else if (httpsAman(url) && new URL(url).hostname === 'giphy.com') {
    const id = new URL(url).pathname.split('/').filter(Boolean).pop()?.split('-').pop();
    if (!id || !/^[A-Za-z0-9]{4,80}$/.test(id)) gagal('Tautan GIPHY tidak valid.');
    const key = await ambilKunciGiphy(env);
    if (!key) gagal('Admin perlu mengaktifkan GIPHY, atau gunakan URL gambar GIF/WebP langsung.');
    const r = await fetch(`https://api.giphy.com/v1/gifs/${id}?api_key=${encodeURIComponent(key)}`, { signal: AbortSignal.timeout(10000) });
    if (!r.ok) gagal('GIPHY tidak dapat memuat stiker dari tautan tersebut.');
    const item = mediaGiphy((await r.json()).data);
    if (!item) gagal('Gambar GIPHY tidak tersedia.');
    return item;
  }
  if (!urlStikerAman(env, url)) gagal('Gunakan stiker dari galeri, koleksi, atau tautan gambar resmi GIPHY.');
  if (!value.data_uri) mime = /\.gif(?:\?|$)/i.test(url) ? 'image/gif' : /\.png(?:\?|$)/i.test(url) ? 'image/png' : 'image/webp';
  const giphy = new URL(url).hostname.endsWith('.giphy.com');
  return { url, mime, nama: teks(value.nama, 100) || 'Stiker', lebar, tinggi,
    sumber: giphy ? 'giphy' : 'galeri',
    ...(giphy ? { sumber_url: httpsAman(value.sumber_url) && new URL(value.sumber_url).hostname === 'giphy.com' ? value.sumber_url : 'https://giphy.com' } : {}) };
}

export function bacaStiker(value) {
  try { const s = typeof value === 'string' ? JSON.parse(value) : value; return s?.url ? s : null; } catch { return null; }
}
