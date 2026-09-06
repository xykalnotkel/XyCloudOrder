/**
 * ============================================================
 *  XyCloudStore - Push notification (OneSignal)
 *  Dipakai supaya notifikasi tetap masuk walau aplikasi ditutup.
 * ============================================================
 *  Catatan: push Android baru benar-benar terkirim setelah
 *  kredensial Firebase (FCM v1 Service Account JSON) diunggah
 *  ke dashboard OneSignal. Tanpa itu OneSignal menolak kiriman.
 */

const UNGU = '6C2BE2';

/**
 * Kirim push ke satu pengguna berdasarkan external_id (= id user di D1).
 * Aman dipanggil kapan saja; kalau kredensial belum ada, fungsi diam saja.
 */
export async function kirimPush(env, { userId, judul, pesan, data, url }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_API_KEY || !userId) {
    return { ok: false, alasan: 'kredensial OneSignal belum diatur' };
  }

  const body = {
    app_id: env.ONESIGNAL_APP_ID,
    include_aliases: { external_id: [String(userId)] },
    target_channel: 'push',
    headings: { en: judul, id: judul },
    contents: { en: pesan, id: pesan },
    android_accent_color: `FF${UNGU}`,
    small_icon: 'ic_stat_onesignal_default',
    data: data || {},
    ...(url ? { url } : {}),
  };

  try {
    const r = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        Authorization: `Key ${env.ONESIGNAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    return r.ok && !j.errors ? { ok: true, id: j.id } : { ok: false, alasan: JSON.stringify(j.errors || j) };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/** Kirim push ke semua pelanggan yang berlangganan (dipakai untuk promo/banner). */
export async function siarkanPush(env, { judul, pesan, data }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_API_KEY) {
    return { ok: false, alasan: 'kredensial OneSignal belum diatur' };
  }
  try {
    const r = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        Authorization: `Key ${env.ONESIGNAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        app_id: env.ONESIGNAL_APP_ID,
        included_segments: ['Total Subscriptions'],
        headings: { en: judul, id: judul },
        contents: { en: pesan, id: pesan },
        android_accent_color: `FF${UNGU}`,
        data: data || {},
      }),
    });
    const j = await r.json().catch(() => ({}));
    return r.ok && !j.errors ? { ok: true, id: j.id } : { ok: false, alasan: JSON.stringify(j.errors || j) };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}
