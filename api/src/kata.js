/**
 * ============================================================
 *  Filter kata terlarang (Batch E)
 * ============================================================
 *  Menolak nama, username, bio, dan konten publik yang memuat
 *  kata kasar, ujaran kebencian/SARA, atau pornografi.
 *  Pemeriksaannya sengaja sederhana tapi tahan akal-akalan dasar:
 *  huruf kecil semua, simbol umum dipetakan ke huruf (leetspeak),
 *  lalu pencocokan substring.
 */

export const KATA_TERLARANG = {
  kasar: [
    'anjing', 'anjrit', 'anjay', 'asu', 'bangsat', 'bajingan', 'kontol',
    'kntl', 'memek', 'memeq', 'jembut', 'ngentot', 'ngentd', 'tolol',
    'goblok', 'bodoh', 'idiot', 'babi', 'monyet', 'setan', 'bangke',
    'keparat', 'sundala', 'pukimak', 'matamu', 'tai',
  ],
  sara: [
    'pki', 'kafirun', 'haramjadah', 'teroris', 'bombir', 'jihadis',
    'rasis', 'etnisbersih', 'g30s', 'antiagama', 'penistagama',
  ],
  porno: [
    'porno', 'porn', 'bokep', 'xxx', 'hentai', 'nsfw', 'coli', 'onani',
    'masturbasi', 'pelacur', 'lonte', 'jablay', 'gaysex', 'lesbisex',
    'sange', 'ngecrot', 'sperma', 'vagina', 'penis', 'toket', 'bugil',
    'telanjang', 'sexyvideo', 'onlyfans',
  ],
};

/** Semua kata dalam satu daftar datar untuk pencocokan cepat. */
const SEMUA = Object.entries(KATA_TERLARANG).flatMap(([jenis, daftar]) =>
  daftar.map((k) => ({ kata: k, jenis })),
);

const LEET = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's', '!': 'i', '*': '' , '-': '', '_': '', '.': '' };

/** Normalisasi teks: huruf kecil, leetspeak, buang spasi/tanda baca. */
export function normalisasiKata(teks) {
  return String(teks || '')
    .toLowerCase()
    .split('')
    .map((c) => (c in LEET ? LEET[c] : c))
    .join('')
    .replace(/[^a-z0-9]/g, '');
}

/**
 * Kembalikan kata terlarang pertama yang ditemukan (atau null).
 * Kata panjang (>=4 huruf) dicocokkan sebagai substring pada teks yang
 * dirapatkan (tahan a.n.j.i.n.g / anji_ng). Kata pendek (<=3 huruf) hanya
 * dicocokkan sebagai kata utuh supaya nama sah seperti "Nasution" tidak
 * ikut terjaring ("asu").
 */
export function kataTerlarangDalam(teks) {
  const rapat = normalisasiKata(teks);
  if (rapat.length < 3) return null;
  const berjarak = ' ' + String(teks || '').toLowerCase()
    .replace(/[0o]/g, 'o').replace(/[1i!]/g, 'i').replace(/[3e]/g, 'e')
    .replace(/[4a@]/g, 'a').replace(/[5s$]/g, 's').replace(/[7t]/g, 't')
    .replace(/[^a-z0-9]+/g, ' ').trim() + ' ';
  for (const { kata, jenis } of SEMUA) {
    if (kata.length <= 3) {
      if (berjarak.includes(` ${kata} `)) return { kata, jenis };
    } else if (rapat.includes(kata)) {
      return { kata, jenis };
    }
  }
  return null;
}
