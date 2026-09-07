/**
 * ============================================================
 *  XyCloudStore - Halaman unduh dan info rilis
 * ============================================================
 *  Berkas APK tidak pernah ditautkan langsung ke GitHub.
 *  Semua unduhan lewat domain sendiri:
 *
 *      https://xycloud.my.id/unduh/XyCloudStore-arm64-v8a.apk
 *
 *  Worker yang mengambilkan berkasnya lalu meneruskan ke pengguna,
 *  sekaligus menyimpannya di singgahan tepi Cloudflare supaya cepat.
 */

const JENIS_ABI = {
  'arm64-v8a': {
    nama: 'ARM 64-bit',
    keterangan: 'Hampir semua HP Android keluaran 2016 ke atas',
    utama: true,
  },
  'armeabi-v7a': {
    nama: 'ARM 32-bit',
    keterangan: 'HP lama atau RAM kecil',
    utama: false,
  },
  'x86_64': {
    nama: 'Intel 64-bit',
    keterangan: 'Emulator dan perangkat berbasis Intel',
    utama: false,
  },
  universal: {
    nama: 'Universal',
    keterangan: 'Cocok untuk semua perangkat, ukurannya paling besar',
    utama: false,
  },
};

function abiDariNama(nama) {
  for (const kunci of Object.keys(JENIS_ABI)) {
    if (nama.includes(kunci)) return kunci;
  }
  return 'universal';
}

/**
 * Info rilis diambil dari basis data sendiri supaya tidak bergantung
 * pada GitHub saat pengguna membuka halaman unduh. Isinya dikirim oleh
 * alur build begitu rilis baru terbit. Kalau basis data masih kosong,
 * barulah GitHub ditanya sekali lalu hasilnya disimpan.
 */
export async function infoRilis(env, ctx) {
  try {
    const baris = await env.DB.prepare('SELECT * FROM rilis WHERE id = 1').first();
    if (baris && baris.versi) {
      return {
        versi: baris.versi,
        nama: baris.versi,
        tanggal: baris.tanggal,
        catatan: baris.catatan || '',
        berkas: JSON.parse(baris.berkas || '[]'),
      };
    }
  } catch (_) {
    // lanjut ke GitHub
  }

  const kunciCache = new Request('https://xycloud.my.id/__cache/rilis');
  const cache = caches.default;

  const tersimpan = await cache.match(kunciCache);
  if (tersimpan) return tersimpan.json();

  const repo = env.REPO_RILIS || 'xykalnotkel/XyCloudOrder';
  const r = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
    headers: { 'User-Agent': 'XyCloudStore-Worker', Accept: 'application/vnd.github+json' },
  });

  if (!r.ok) return { versi: null, berkas: [], catatan: 'Info rilis belum tersedia.' };
  const j = await r.json();

  const hasil = {
    versi: j.tag_name,
    nama: j.name,
    tanggal: j.published_at,
    catatan: j.body || '',
    berkas: (j.assets || [])
      .filter((a) => a.name.endsWith('.apk'))
      .map((a) => {
        const abi = abiDariNama(a.name);
        return {
          nama: a.name,
          abi,
          label: JENIS_ABI[abi].nama,
          keterangan: JENIS_ABI[abi].keterangan,
          utama: JENIS_ABI[abi].utama,
          ukuran: a.size,
          ukuranMb: Math.round((a.size / 1048576) * 10) / 10,
          url: `/unduh/${a.name}`,
        };
      })
      .sort((a, b) => Number(b.utama) - Number(a.utama)),
  };

  const jawaban = new Response(JSON.stringify(hasil), {
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=600' },
  });
  if (ctx) ctx.waitUntil(cache.put(kunciCache, jawaban.clone()));
  return hasil;
}

/** Alirkan berkas APK lewat domain sendiri. */
export async function unduhApk(env, ctx, namaBerkas) {
  if (!/^XyCloudStore-[A-Za-z0-9._-]+\.apk$/.test(namaBerkas)) {
    return new Response('Berkas tidak dikenal', { status: 404 });
  }

  const rilis = await infoRilis(env, ctx);
  const berkas = (rilis.berkas || []).find((b) => b.nama === namaBerkas);
  if (!berkas || !rilis.versi) return new Response('Berkas tidak ditemukan', { status: 404 });

  const repo = env.REPO_RILIS || 'xykalnotkel/XyCloudOrder';
  const asal = `https://github.com/${repo}/releases/download/${rilis.versi}/${namaBerkas}`;

  const kunciCache = new Request(`https://xycloud.my.id/__cache/apk/${rilis.versi}/${namaBerkas}`);
  const cache = caches.default;
  const tersimpan = await cache.match(kunciCache);
  if (tersimpan) return tersimpan;

  const jawab = await fetch(asal, { redirect: 'follow' });
  if (!jawab.ok) return new Response('Gagal mengambil berkas', { status: 502 });

  const jawaban = new Response(jawab.body, {
    status: 200,
    headers: {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${namaBerkas}"`,
      'Cache-Control': 'public, max-age=86400',
      'X-Content-Type-Options': 'nosniff',
    },
  });

  if (ctx) ctx.waitUntil(cache.put(kunciCache, jawaban.clone()));
  return jawaban;
}

/**
 * Tebak arsitektur perangkat dari petunjuk peramban.
 * Hasilnya hanya saran; halaman unduh tetap menyediakan pilihan manual.
 */
export function tebakAbi(req) {
  const ua = (req.headers.get('user-agent') || '').toLowerCase();
  const arch = (req.headers.get('sec-ch-ua-arch') || '').toLowerCase().replace(/"/g, '');
  const bit = (req.headers.get('sec-ch-ua-bitness') || '').replace(/"/g, '');

  if (!ua.includes('android')) return { abi: null, alasan: 'bukan Android' };

  if (ua.includes('x86_64') || ua.includes('x86-64') || arch.includes('x86')) {
    return { abi: 'x86_64', alasan: 'petunjuk peramban menunjukkan Intel' };
  }
  if (ua.includes('aarch64') || ua.includes('arm64') || arch.includes('arm') && bit === '64') {
    return { abi: 'arm64-v8a', alasan: 'perangkat ARM 64-bit' };
  }
  if (ua.includes('armv7') || ua.includes('armeabi')) {
    return { abi: 'armeabi-v7a', alasan: 'perangkat ARM 32-bit' };
  }

  // Android 8 ke atas hampir pasti 64-bit
  const versi = ua.match(/android\s([0-9]+)/);
  if (versi && Number(versi[1]) >= 8) {
    return { abi: 'arm64-v8a', alasan: `Android ${versi[1]}, umumnya ARM 64-bit` };
  }
  return { abi: 'universal', alasan: 'perangkat tidak dikenali, dipakai versi universal' };
}

/** Simpan info rilis ke basis data. Dipanggil alur build setelah rilis terbit. */
export async function simpanRilis(env, data) {
  const berkas = (data.berkas || []).map((b) => {
    const abi = abiDariNama(b.nama || '');
    const ukuran = Number(b.ukuran || 0);
    return {
      nama: b.nama,
      abi,
      label: JENIS_ABI[abi].nama,
      keterangan: JENIS_ABI[abi].keterangan,
      utama: JENIS_ABI[abi].utama,
      ukuran,
      ukuranMb: Math.round((ukuran / 1048576) * 10) / 10,
      url: `/unduh/${b.nama}`,
    };
  }).sort((a, b) => Number(b.utama) - Number(a.utama));

  await env.DB.prepare(
    `INSERT INTO rilis (id,versi,tanggal,catatan,berkas,diperbarui) VALUES (1,?,?,?,?,?)
     ON CONFLICT(id) DO UPDATE SET versi=excluded.versi, tanggal=excluded.tanggal,
       catatan=excluded.catatan, berkas=excluded.berkas, diperbarui=excluded.diperbarui`
  ).bind(
    data.versi,
    data.tanggal || new Date().toISOString(),
    data.catatan || '',
    JSON.stringify(berkas),
    new Date().toISOString(),
  ).run();

  return { versi: data.versi, berkas };
}
