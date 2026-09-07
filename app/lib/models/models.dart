import 'dart:convert';
// ============================================================
// XyCloudOrder — Model data (mirror dari tabel D1 Cloudflare)
// ============================================================

class UserProfile {
  final String id;
  final String nama;
  final String email;
  final String? phone;
  final int saldo;
  final String tier; // basic | pro | vip
  final String? avatar;

  /// Foto profil dari server (Cloudinary atau Google).
  final String? foto;

  /// Terima pemberitahuan kegiatan forum komunitas.
  final bool notifForum;

  UserProfile({
    required this.id,
    required this.nama,
    required this.email,
    this.phone,
    this.saldo = 0,
    this.tier = 'basic',
    this.avatar,
    this.foto,
    this.notifForum = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: '${j['id']}',
        nama: j['nama'] ?? j['name'] ?? 'User',
        email: j['email'] ?? '',
        phone: j['phone'],
        saldo: (j['saldo'] ?? 0) as int,
        tier: j['tier'] ?? 'basic',
        avatar: j['avatar'],
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        notifForum: (j['notif_forum'] ?? 1) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'email': email,
        'phone': phone,
        'saldo': saldo,
        'tier': tier,
        'avatar': avatar,
        'foto': foto,
        'notif_forum': notifForum ? 1 : 0,
      };

  UserProfile copyWith({int? saldo, String? nama, String? phone, String? foto}) => UserProfile(
        id: id,
        nama: nama ?? this.nama,
        email: email,
        phone: phone ?? this.phone,
        saldo: saldo ?? this.saldo,
        tier: tier,
        foto: foto ?? this.foto,
        avatar: avatar,
        notifForum: notifForum,
      );
}

/// Paket / spesifikasi PC cloud yang bisa disewa.
class PcPlan {
  final String id;
  final String nama;
  final String gpu;
  final String cpu;
  final int ramGb;
  final int storageGb;
  final int hargaPerJam;
  final int hargaPerHari;
  final String region;
  final String tag; // Populer, Hemat, Ultra
  final int totalUnit;
  int unitTersedia; // realtime
  final String gambar;

  PcPlan({
    required this.id,
    required this.nama,
    required this.gpu,
    required this.cpu,
    required this.ramGb,
    required this.storageGb,
    required this.hargaPerJam,
    required this.hargaPerHari,
    required this.region,
    required this.tag,
    required this.totalUnit,
    required this.unitTersedia,
    required this.gambar,
  });

  bool get ready => unitTersedia > 0;

  factory PcPlan.fromJson(Map<String, dynamic> j) => PcPlan(
        id: '${j['id']}',
        nama: j['nama'],
        gpu: j['gpu'],
        cpu: j['cpu'],
        ramGb: j['ram_gb'] ?? j['ramGb'] ?? 16,
        storageGb: j['storage_gb'] ?? j['storageGb'] ?? 256,
        hargaPerJam: j['harga_per_jam'] ?? j['hargaPerJam'] ?? 0,
        hargaPerHari: j['harga_per_hari'] ?? j['hargaPerHari'] ?? 0,
        region: j['region'] ?? 'Jakarta',
        tag: j['tag'] ?? '',
        totalUnit: j['total_unit'] ?? j['totalUnit'] ?? 0,
        unitTersedia: j['unit_tersedia'] ?? j['unitTersedia'] ?? 0,
        gambar: j['gambar'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'gpu': gpu,
        'cpu': cpu,
        'ram_gb': ramGb,
        'storage_gb': storageGb,
        'harga_per_jam': hargaPerJam,
        'harga_per_hari': hargaPerHari,
        'region': region,
        'tag': tag,
        'total_unit': totalUnit,
        'unit_tersedia': unitTersedia,
        'gambar': gambar,
      };
}

enum OrderStatus { pending, dibayar, provisioning, aktif, selesai, batal }

OrderStatus statusFrom(String s) => OrderStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => OrderStatus.pending,
    );

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Menunggu Pembayaran',
        OrderStatus.dibayar => 'Pembayaran Diterima',
        OrderStatus.provisioning => 'Menyiapkan Mesin',
        OrderStatus.aktif => 'Sesi Aktif',
        OrderStatus.selesai => 'Selesai',
        OrderStatus.batal => 'Dibatalkan',
      };
  int get step => switch (this) {
        OrderStatus.pending => 0,
        OrderStatus.dibayar => 1,
        OrderStatus.provisioning => 2,
        OrderStatus.aktif => 3,
        OrderStatus.selesai => 4,
        OrderStatus.batal => -1,
      };
}

/// Order sewa PC.
class RentOrder {
  final String id;
  final String kode;
  final String planId;
  final String planNama;
  final int durasiJam;
  final int total;
  OrderStatus status;
  final DateTime dibuat;
  DateTime? mulai;
  DateTime? berakhir;
  String? host;
  String? username;
  String? password;
  int progress; // 0-100 saat provisioning

  RentOrder({
    required this.id,
    required this.kode,
    required this.planId,
    required this.planNama,
    required this.durasiJam,
    required this.total,
    required this.status,
    required this.dibuat,
    this.mulai,
    this.berakhir,
    this.host,
    this.username,
    this.password,
    this.progress = 0,
  });

  factory RentOrder.fromJson(Map<String, dynamic> j) => RentOrder(
        id: '${j['id']}',
        kode: j['kode'] ?? j['code'] ?? '-',
        planId: '${j['plan_id'] ?? j['planId'] ?? ''}',
        planNama: j['plan_nama'] ?? j['planNama'] ?? '',
        durasiJam: j['durasi_jam'] ?? j['durasiJam'] ?? 1,
        total: j['total'] ?? 0,
        status: statusFrom(j['status'] ?? 'pending'),
        dibuat: DateTime.parse(j['dibuat'] ?? j['created_at']),
        mulai: (j['mulai'] ?? j['start_at']) == null ? null : DateTime.parse(j['mulai'] ?? j['start_at']),
        berakhir: (j['berakhir'] ?? j['end_at']) == null ? null : DateTime.parse(j['berakhir'] ?? j['end_at']),
        host: j['host'],
        username: j['username'],
        password: j['password'],
        progress: j['progress'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode': kode,
        'plan_id': planId,
        'plan_nama': planNama,
        'durasi_jam': durasiJam,
        'total': total,
        'status': status.name,
        'dibuat': dibuat.toIso8601String(),
        'mulai': mulai?.toIso8601String(),
        'berakhir': berakhir?.toIso8601String(),
        'host': host,
        'username': username,
        'password': password,
        'progress': progress,
      };
}

/// Produk akun digital yang dijual (Steam, Netflix, Game Pass, dsb).
/// Membaca kolom `detail` yang bisa berupa peta atau teks JSON.
Map<String, dynamic> _petaAman(dynamic v) {
  if (v == null) return const {};
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.trim().startsWith('{')) {
    try {
      return Map<String, dynamic>.from(jsonDecode(v));
    } catch (_) {}
  }
  return const {};
}

class AkunProduk {
  final String id;
  final String nama;
  final String kategori;
  final String deskripsi;
  final int harga;
  final int hargaCoret;
  final int stok; // realtime
  final double rating;
  final int terjual;
  final String gambar;
  final List<String> fitur;
  final String garansi;
  final int jumlahUlasan;
  final Map<String, dynamic> detail;

  AkunProduk({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.deskripsi,
    required this.harga,
    required this.hargaCoret,
    required this.stok,
    required this.rating,
    required this.terjual,
    required this.gambar,
    required this.fitur,
    required this.garansi,
    this.jumlahUlasan = 0,
    this.detail = const {},
  });

  factory AkunProduk.fromJson(Map<String, dynamic> j) => AkunProduk(
        id: '${j['id']}',
        nama: j['nama'],
        kategori: j['kategori'] ?? 'Lainnya',
        deskripsi: j['deskripsi'] ?? '',
        harga: j['harga'] ?? 0,
        hargaCoret: j['harga_coret'] ?? j['hargaCoret'] ?? 0,
        stok: j['stok'] ?? 0,
        rating: (j['rating'] ?? 5).toDouble(),
        terjual: j['terjual'] ?? 0,
        gambar: j['gambar'] ?? '',
        fitur: (j['fitur'] as List?)?.map((e) => '$e').toList() ?? const [],
        garansi: j['garansi'] ?? '7 hari',
        jumlahUlasan: j['jumlah_ulasan'] ?? 0,
        detail: _petaAman(j['detail']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'harga': harga,
        'harga_coret': hargaCoret,
        'stok': stok,
        'rating': rating,
        'terjual': terjual,
        'gambar': gambar,
        'fitur': fitur,
        'garansi': garansi,
        'jumlah_ulasan': jumlahUlasan,
        'detail': detail,
      };
}

class ChatMessage {
  final String id;
  final String room;
  final String dari; // 'user' | 'cs' | 'system'
  final String teks;
  final String? gambar;
  final DateTime waktu;
  bool terkirim;
  bool dibaca;
  bool gagal;

  ChatMessage({
    required this.id,
    required this.room,
    required this.dari,
    required this.teks,
    required this.waktu,
    this.gambar,
    this.terkirim = true,
    this.dibaca = false,
    this.gagal = false,
  });

  bool get milikSaya => dari == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id']}',
        room: j['room'] ?? '',
        dari: j['dari'] ?? j['from'] ?? 'cs',
        teks: j['teks'] ?? j['text'] ?? '',
        gambar: (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null,
        waktu: DateTime.parse(j['waktu'] ?? j['at']),
        dibaca: (j['dibaca'] ?? 0) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'room': room,
        'dari': dari,
        'teks': teks,
        'gambar': gambar,
        'waktu': waktu.toIso8601String(),
      };
}

class Transaksi {
  final String id;
  final String judul;
  final String tipe; // topup | sewa | akun | refund
  final int nominal; // + / -
  final DateTime waktu;
  final String status;

  Transaksi({
    required this.id,
    required this.judul,
    required this.tipe,
    required this.nominal,
    required this.waktu,
    required this.status,
  });

  factory Transaksi.fromJson(Map<String, dynamic> j) => Transaksi(
        id: '${j['id']}',
        judul: j['judul'] ?? '',
        tipe: j['tipe'] ?? 'sewa',
        nominal: j['nominal'] ?? 0,
        waktu: DateTime.parse(j['waktu']),
        status: j['status'] ?? 'sukses',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'tipe': tipe,
        'nominal': nominal,
        'waktu': waktu.toIso8601String(),
        'status': status,
      };
}

/// Banner promo yang tampil sebagai slider di beranda.
/// Dikelola sepenuhnya lewat dashboard admin (tabel `banners` di D1).
class PromoBanner {
  final String id;
  final String judul;
  final String subjudul;
  final String label;
  final String cta;
  final String aksi; // sewa | akun | topup | url
  final String target;
  final String warna1;
  final String warna2;
  final String ikon;
  final int urutan;

  PromoBanner({
    required this.id,
    required this.judul,
    this.subjudul = '',
    this.label = '',
    this.cta = 'Lihat',
    this.aksi = 'sewa',
    this.target = '',
    this.warna1 = '#2F5BFF',
    this.warna2 = '#6A4BFF',
    this.ikon = 'bolt',
    this.urutan = 1,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        id: '${j['id']}',
        judul: j['judul'] ?? '',
        subjudul: j['subjudul'] ?? '',
        label: j['label'] ?? '',
        cta: j['cta'] ?? 'Lihat',
        aksi: j['aksi'] ?? 'sewa',
        target: j['target'] ?? '',
        warna1: j['warna1'] ?? '#2F5BFF',
        warna2: j['warna2'] ?? '#6A4BFF',
        ikon: j['ikon'] ?? 'bolt',
        urutan: (j['urutan'] ?? 1) is int ? (j['urutan'] ?? 1) as int : 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'subjudul': subjudul,
        'label': label,
        'cta': cta,
        'aksi': aksi,
        'target': target,
        'warna1': warna1,
        'warna2': warna2,
        'ikon': ikon,
        'urutan': urutan,
      };
}

/// Ulasan pembeli untuk sebuah produk akun.
class Ulasan {
  final String id;
  final String produkId;
  final String nama;
  final int rating;
  final String komentar;
  final String? gambar;
  final String? balasan;
  final DateTime waktu;

  Ulasan({
    required this.id,
    required this.produkId,
    required this.nama,
    required this.rating,
    required this.komentar,
    required this.waktu,
    this.gambar,
    this.balasan,
  });

  factory Ulasan.fromJson(Map<String, dynamic> j) => Ulasan(
        id: '${j['id']}',
        produkId: '${j['produk_id'] ?? ''}',
        nama: j['nama'] ?? 'Pengguna',
        rating: (j['rating'] ?? 5) is int ? (j['rating'] ?? 5) : int.tryParse('${j['rating']}') ?? 5,
        komentar: j['komentar'] ?? '',
        gambar: (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null,
        balasan: (j['balasan'] as String?)?.isNotEmpty == true ? j['balasan'] : null,
        waktu: DateTime.tryParse('${j['waktu']}') ?? DateTime.now(),
      );
}

/// Permintaan isi saldo yang menunggu konfirmasi admin.
class PermintaanTopup {
  final String id;
  final int nominal;
  final int kodeUnik;
  final int total;
  final String metode;
  final String status; // menunggu | diperiksa | disetujui | ditolak
  final String? bukti;
  final String? catatan;
  final DateTime dibuat;
  final Map<String, dynamic> rekening;

  /// Kalau penyedia pembayaran aktif, di sini ada tautan atau QR-nya.
  final bool otomatis;
  final Map<String, dynamic> bayar;

  PermintaanTopup({
    required this.id,
    required this.nominal,
    required this.kodeUnik,
    required this.total,
    required this.metode,
    required this.status,
    required this.dibuat,
    this.bukti,
    this.catatan,
    this.rekening = const {},
    this.otomatis = false,
    this.bayar = const {},
  });

  factory PermintaanTopup.fromJson(Map<String, dynamic> j) => PermintaanTopup(
        id: '${j['id']}',
        nominal: j['nominal'] ?? 0,
        kodeUnik: j['kode_unik'] ?? 0,
        total: j['total'] ?? (j['nominal'] ?? 0),
        metode: j['metode'] ?? 'transfer',
        status: j['status'] ?? 'menunggu',
        bukti: (j['bukti'] as String?)?.isNotEmpty == true ? j['bukti'] : null,
        catatan: (j['catatan'] as String?)?.isNotEmpty == true ? j['catatan'] : null,
        dibuat: DateTime.tryParse('${j['dibuat']}'.replaceFirst(' ', 'T')) ?? DateTime.now(),
        rekening: _petaAman(j['rekening']),
        otomatis: j['otomatis'] == true,
        bayar: _petaAman(j['bayar']),
      );

  bool get selesai => status == 'disetujui' || status == 'ditolak';
}

/// Konfigurasi dari server: penyedia login aktif, nomor WhatsApp, rekening.
class KonfigurasiApp {
  final bool bayarOtomatis;
  final List<Map<String, dynamic>> metodeBayar;
  final bool googleAktif;
  final bool facebookAktif;
  final String whatsapp;
  final Map<String, dynamic> rekening;
  final int minTopup;

  const KonfigurasiApp({
    this.bayarOtomatis = false,
    this.metodeBayar = const [],
    this.googleAktif = false,
    this.facebookAktif = false,
    this.whatsapp = '',
    this.rekening = const {},
    this.minTopup = 10000,
  });

  factory KonfigurasiApp.fromJson(Map<String, dynamic> j) {
    final p = _petaAman(j['providers']);
    final bayar = _petaAman(j['pembayaran']);
    return KonfigurasiApp(
      bayarOtomatis: bayar['otomatis'] == true,
      metodeBayar: ((bayar['metode'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      googleAktif: p['google'] == true,
      facebookAktif: p['facebook'] == true,
      whatsapp: '${j['whatsapp'] ?? ''}',
      rekening: _petaAman(j['rekening']),
      minTopup: j['minTopup'] ?? 10000,
    );
  }
}

/// Satu diskusi di forum komunitas.
class ForumPost {
  final String id;
  final String userId;
  final String nama;
  final String? foto;
  final String kategori;
  final String judul;
  final String isi;
  final String? gambar;
  final String tier;
  int suka;
  int balasan;
  final bool disematkan;
  final DateTime dibuat;

  ForumPost({
    required this.id,
    required this.userId,
    required this.nama,
    required this.kategori,
    required this.judul,
    required this.isi,
    required this.dibuat,
    this.foto,
    this.gambar,
    this.tier = 'basic',
    this.suka = 0,
    this.balasan = 0,
    this.disematkan = false,
  });

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: '${j['id']}',
        userId: '${j['user_id'] ?? ''}',
        nama: j['nama'] ?? 'Pengguna',
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        kategori: j['kategori'] ?? 'Umum',
        judul: j['judul'] ?? '',
        isi: j['isi'] ?? '',
        gambar: (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null,
        tier: j['tier'] ?? 'basic',
        suka: j['suka'] ?? 0,
        balasan: j['balasan'] ?? 0,
        disematkan: (j['disematkan'] ?? 0) == 1,
        dibuat: DateTime.tryParse('${j['dibuat']}'.replaceFirst(' ', 'T')) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'nama': nama,
        'foto': foto,
        'kategori': kategori,
        'judul': judul,
        'isi': isi,
        'gambar': gambar,
        'tier': tier,
        'suka': suka,
        'balasan': balasan,
        'disematkan': disematkan ? 1 : 0,
        'dibuat': dibuat.toIso8601String(),
      };
}

/// Balasan pada sebuah diskusi.
class ForumBalasan {
  final String id;
  final String postId;
  final String nama;
  final String? foto;
  final String isi;
  final bool admin;
  final String tier;
  final DateTime dibuat;

  ForumBalasan({
    required this.id,
    required this.postId,
    required this.nama,
    required this.isi,
    required this.dibuat,
    this.foto,
    this.admin = false,
    this.tier = 'basic',
  });

  factory ForumBalasan.fromJson(Map<String, dynamic> j) => ForumBalasan(
        id: '${j['id']}',
        postId: '${j['post_id'] ?? ''}',
        nama: j['nama'] ?? 'Pengguna',
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        isi: j['isi'] ?? '',
        admin: (j['admin'] ?? 0) == 1,
        tier: j['tier'] ?? 'basic',
        dibuat: DateTime.tryParse('${j['dibuat']}'.replaceFirst(' ', 'T')) ?? DateTime.now(),
      );
}

/// Sesi bermain di PC sewaan.
class SesiMain {
  final String id;
  final String orderId;
  final String? agenId;
  final String status; // menyiapkan | siap | pairing | berjalan | selesai | gagal
  final String? host;
  final String? catatan;
  final int durasiMenit;
  final DateTime? mulai;
  final DateTime? berakhir;

  SesiMain({
    required this.id,
    required this.orderId,
    required this.status,
    this.agenId,
    this.host,
    this.catatan,
    this.durasiMenit = 60,
    this.mulai,
    this.berakhir,
  });

  factory SesiMain.fromJson(Map<String, dynamic> j) => SesiMain(
        id: '${j['id']}',
        orderId: '${j['order_id'] ?? ''}',
        agenId: j['agen_id'],
        status: j['status'] ?? 'menyiapkan',
        host: (j['host'] as String?)?.isNotEmpty == true ? j['host'] : null,
        catatan: (j['catatan'] as String?)?.isNotEmpty == true ? j['catatan'] : null,
        durasiMenit: j['durasi_menit'] ?? 60,
        mulai: DateTime.tryParse('${j['mulai']}'.replaceFirst(' ', 'T')),
        berakhir: DateTime.tryParse('${j['berakhir']}'.replaceFirst(' ', 'T')),
      );
}
