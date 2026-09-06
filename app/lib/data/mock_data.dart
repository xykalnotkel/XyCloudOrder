import 'dart:async';
import 'dart:math';
import '../models/models.dart';

/// Data & simulator realtime untuk mode demo (XyConfig.useMock = true).
/// Struktur JSON-nya identik dengan respons Worker Cloudflare,
/// jadi tinggal matikan mock kalau server sudah siap.
class MockData {
  static final rnd = Random();

  static UserProfile user = UserProfile(
    id: 'u_001',
    nama: 'Rangga Pratama',
    email: 'rangga@xycloud.id',
    phone: '0812-3456-7890',
    saldo: 275000,
    tier: 'pro',
  );

  static List<PcPlan> plans() => [
        PcPlan(
          id: 'pc-lite',
          nama: 'XyLite',
          gpu: 'GTX 1650 4GB',
          cpu: 'Ryzen 5 3600',
          ramGb: 16,
          storageGb: 256,
          hargaPerJam: 5000,
          hargaPerHari: 65000,
          region: 'Jakarta',
          tag: 'Hemat',
          totalUnit: 20,
          unitTersedia: 12,
          gambar: '',
        ),
        PcPlan(
          id: 'pc-gaming',
          nama: 'XyGaming',
          gpu: 'RTX 3060 12GB',
          cpu: 'Ryzen 7 5800X',
          ramGb: 32,
          storageGb: 512,
          hargaPerJam: 12000,
          hargaPerHari: 150000,
          region: 'Jakarta',
          tag: 'Populer',
          totalUnit: 15,
          unitTersedia: 4,
          gambar: '',
        ),
        PcPlan(
          id: 'pc-editor',
          nama: 'XyCreator',
          gpu: 'RTX 4070 12GB',
          cpu: 'i7-13700K',
          ramGb: 64,
          storageGb: 1024,
          hargaPerJam: 20000,
          hargaPerHari: 240000,
          region: 'Singapore',
          tag: 'Editing',
          totalUnit: 10,
          unitTersedia: 6,
          gambar: '',
        ),
        PcPlan(
          id: 'pc-ultra',
          nama: 'XyUltra',
          gpu: 'RTX 4090 24GB',
          cpu: 'i9-14900K',
          ramGb: 128,
          storageGb: 2048,
          hargaPerJam: 38000,
          hargaPerHari: 450000,
          region: 'Singapore',
          tag: 'Ultra',
          totalUnit: 6,
          unitTersedia: 0,
          gambar: '',
        ),
      ];

  static List<AkunProduk> akun() => [
        AkunProduk(
          id: 'ak-steam',
          nama: 'Steam Account + 5 AAA Games',
          kategori: 'Gaming',
          deskripsi: 'Akun Steam siap pakai berisi 5 game AAA populer. Full akses, bisa ganti email & password.',
          harga: 185000,
          hargaCoret: 250000,
          stok: 8,
          rating: 4.9,
          terjual: 1240,
          gambar: '',
          fitur: ['Full akses email', 'Bisa ganti password', 'Garansi 30 hari', 'Kirim < 5 menit'],
          garansi: '30 hari',
        ),
        AkunProduk(
          id: 'ak-gamepass',
          nama: 'Xbox Game Pass Ultimate 1 Bulan',
          kategori: 'Subscription',
          deskripsi: 'Akses 400+ game PC & cloud gaming, EA Play included. Aktivasi ke akun pribadimu.',
          harga: 65000,
          hargaCoret: 120000,
          stok: 25,
          rating: 4.8,
          terjual: 3120,
          gambar: '',
          fitur: ['Aktivasi akun sendiri', 'Cloud gaming', 'Legal & resmi'],
          garansi: '30 hari',
        ),
        AkunProduk(
          id: 'ak-netflix',
          nama: 'Netflix Premium 4K — 1 Profil',
          kategori: 'Streaming',
          deskripsi: 'Sharing profil privat, kualitas 4K UHD, anti limit device.',
          harga: 28000,
          hargaCoret: 54000,
          stok: 3,
          rating: 4.7,
          terjual: 8900,
          gambar: '',
          fitur: ['4K UHD', 'Profil privat', 'Garansi full replace'],
          garansi: '30 hari',
        ),
        AkunProduk(
          id: 'ak-adobe',
          nama: 'Adobe Creative Cloud All Apps',
          kategori: 'Produktivitas',
          deskripsi: 'Semua aplikasi Adobe untuk 1 tahun, cocok dipadukan dengan sewa PC XyCreator.',
          harga: 320000,
          hargaCoret: 600000,
          stok: 5,
          rating: 4.9,
          terjual: 640,
          gambar: '',
          fitur: ['All apps', '1 tahun', 'Cloud storage 100GB'],
          garansi: '1 tahun',
        ),
        AkunProduk(
          id: 'ak-spotify',
          nama: 'Spotify Premium Individual 3 Bulan',
          kategori: 'Streaming',
          deskripsi: 'Upgrade akun pribadi, tanpa iklan, offline download.',
          harga: 42000,
          hargaCoret: 82000,
          stok: 40,
          rating: 4.8,
          terjual: 5400,
          gambar: '',
          fitur: ['Akun sendiri', 'Tanpa iklan', 'Proses instan'],
          garansi: '90 hari',
        ),
        AkunProduk(
          id: 'ak-chatgpt',
          nama: 'AI Pro Access 1 Bulan',
          kategori: 'Produktivitas',
          deskripsi: 'Akses AI premium untuk kebutuhan kerja & belajar.',
          harga: 95000,
          hargaCoret: 160000,
          stok: 0,
          rating: 4.6,
          terjual: 210,
          gambar: '',
          fitur: ['Akses penuh', 'Support 24 jam'],
          garansi: '30 hari',
        ),
      ];

  static List<RentOrder> orders() => [
        RentOrder(
          id: 'o_9001',
          kode: 'XY-9001',
          planId: 'pc-gaming',
          planNama: 'XyGaming',
          durasiJam: 3,
          total: 36000,
          status: OrderStatus.aktif,
          dibuat: DateTime.now().subtract(const Duration(minutes: 40)),
          mulai: DateTime.now().subtract(const Duration(minutes: 35)),
          berakhir: DateTime.now().add(const Duration(hours: 2, minutes: 25)),
          host: '103.44.12.90:3389',
          username: 'xy_user9001',
          password: 'Xy#9001pro',
        ),
        RentOrder(
          id: 'o_8842',
          kode: 'XY-8842',
          planId: 'pc-lite',
          planNama: 'XyLite',
          durasiJam: 5,
          total: 25000,
          status: OrderStatus.selesai,
          dibuat: DateTime.now().subtract(const Duration(days: 2)),
          mulai: DateTime.now().subtract(const Duration(days: 2)),
          berakhir: DateTime.now().subtract(const Duration(days: 2, hours: -5)),
        ),
      ];

  static List<Transaksi> transaksi() => [
        Transaksi(id: 't1', judul: 'Top up saldo — QRIS', tipe: 'topup', nominal: 200000, waktu: DateTime.now().subtract(const Duration(hours: 3)), status: 'sukses'),
        Transaksi(id: 't2', judul: 'Sewa XyGaming 3 jam', tipe: 'sewa', nominal: -36000, waktu: DateTime.now().subtract(const Duration(minutes: 40)), status: 'sukses'),
        Transaksi(id: 't3', judul: 'Beli Netflix Premium', tipe: 'akun', nominal: -28000, waktu: DateTime.now().subtract(const Duration(days: 1)), status: 'sukses'),
        Transaksi(id: 't4', judul: 'Refund XyLite (gangguan)', tipe: 'refund', nominal: 25000, waktu: DateTime.now().subtract(const Duration(days: 2)), status: 'sukses'),
      ];

  static List<ChatMessage> chatAwal() => [
        ChatMessage(
          id: 'm1',
          room: 'cs',
          dari: 'system',
          teks: 'Kamu terhubung dengan CS XyCloud. Rata-rata balasan < 1 menit.',
          waktu: DateTime.now().subtract(const Duration(minutes: 6)),
        ),
        ChatMessage(
          id: 'm2',
          room: 'cs',
          dari: 'cs',
          teks: 'Halo kak Rangga, ada yang bisa Xy bantu hari ini?',
          waktu: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

  /// Balasan CS otomatis (simulasi) berdasar kata kunci.
  static String balasanCs(String pesan) {
    final p = pesan.toLowerCase();
    if (p.contains('lemot') || p.contains('lag') || p.contains('putus')) {
      return 'Baik kak, coba pindah region ke Jakarta dulu ya lewat menu Sewa PC. Kalau masih lag, Xy bantu migrasi mesin gratis tanpa biaya.';
    }
    if (p.contains('refund') || p.contains('uang')) {
      return 'Untuk refund, saldo otomatis kembali maksimal 1x24 jam kak. Boleh kirim kode ordernya?';
    }
    if (p.contains('akun') || p.contains('garansi')) {
      return 'Semua akun bergaransi kak, kalau bermasalah langsung kami replace tanpa biaya.';
    }
    if (p.contains('bayar') || p.contains('qris') || p.contains('topup')) {
      return 'Pembayaran bisa QRIS, e-wallet, dan transfer bank. Saldo masuk otomatis < 1 menit kak.';
    }
    if (p.contains('halo') || p.contains('hai') || p.contains('pagi') || p.contains('malam')) {
      return 'Halo kak, Xy siap bantu. Mau sewa PC, beli akun, atau ada kendala order?';
    }
    return 'Siap kak, pesanmu sudah Xy catat. Tim teknis sedang mengecek, mohon tunggu sebentar ya.';
  }
}
