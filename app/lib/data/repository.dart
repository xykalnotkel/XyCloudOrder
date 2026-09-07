import 'dart:async';
import 'dart:math';
import '../core/config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data.dart';

/// Dilempar ketika akun ada tetapi emailnya belum diverifikasi.
class PerluVerifikasi implements Exception {
  PerluVerifikasi(this.email, this.nama, this.pesan);
  final String email;
  final String nama;
  final String pesan;
  @override
  String toString() => pesan;
}

/// Satu pintu untuk semua data. Mode mock & mode server (Cloudflare Worker)
/// punya kontrak yang sama, jadi UI tidak perlu tahu bedanya.
abstract class XyRepository {
  Future<UserProfile> login(String email, String password);
  /// Mendaftar. Hasilnya berupa peta berisi `perluVerifikasi`, `email`, dan `pesan`.
  Future<Map<String, dynamic>> daftar({required String nama, required String email, required String password, String? phone});

  /// Memverifikasi kode OTP lalu mengembalikan profil pengguna.
  Future<UserProfile> verifikasiEmail(String email, String kode);
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'});
  Future<String> lupaPassword(String email);
  Future<UserProfile> resetPassword({required String email, required String kode, required String password});

  /// Konfigurasi server: penyedia login aktif, nomor WhatsApp, rekening top up.
  Future<KonfigurasiApp> konfigurasi();

  /// Dokumen legal: 'syarat' atau 'privasi'.
  Future<Map<String, dynamic>> legal(String jenis);

  /// Ambil profil memakai token yang sudah dipasang (dipakai setelah login sosial).
  Future<UserProfile> profilSaya();

  /// Tukar ID token Google (login native) dengan token XyCloudStore.
  Future<UserProfile> masukGoogleNative(String idToken);
  void pasangToken(String token);

  Future<List<Ulasan>> ulasan(String produkId);
  Future<Ulasan> kirimUlasan({required String produkId, required int rating, required String komentar, String? gambar});

  Future<PermintaanTopup> buatTopup(int nominal, String metode);
  Future<List<PermintaanTopup>> daftarTopup();
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri);

  // ---------- profil ----------
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum});
  Future<void> gantiPassword(String lama, String baru);

  // ---------- sesi main ----------
  Future<SesiMain> sesiMulai(String orderId);
  Future<SesiMain> sesiStatus(String id);
  Future<void> sesiPin(String id, String pin);
  Future<void> sesiAkhiri(String id);

  // ---------- forum ----------
  Future<List<ForumPost>> forum();
  Future<List<ForumBalasan>> forumDetail(String id);
  Future<ForumPost> forumBuat({required String judul, required String isi, required String kategori, String? gambar});
  Future<ForumBalasan> forumBalas(String id, String isi);
  Future<Map<String, dynamic>> forumSuka(String id);
  Future<List<String>> forumSukaSaya();
  Future<void> forumHapus(String id);
  Future<List<PcPlan>> plans();
  Future<List<AkunProduk>> produkAkun();
  Future<List<PromoBanner>> banners();
  Future<List<RentOrder>> orders();
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode});
  Future<RentOrder> orderDetail(String id);
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode});
  Future<List<Transaksi>> transaksi();
  Future<List<ChatMessage>> riwayatChat();
  Future<void> kirimChat(String teks, {String? gambar});

  factory XyRepository.create(ApiClient api) =>
      XyConfig.useMock ? MockRepository() : RemoteRepository(api);
}

// ------------------------------------------------------------------
// REMOTE — Cloudflare Worker + D1
// ------------------------------------------------------------------
class RemoteRepository implements XyRepository {
  RemoteRepository(this.api);
  final ApiClient api;

  @override
  Future<UserProfile> login(String email, String password) async {
    final d = await api.post('/auth/login', {'email': email, 'password': password});
    if (d['perluVerifikasi'] == true) {
      throw PerluVerifikasi('${d['email']}', '${d['nama'] ?? ''}', '${d['pesan'] ?? ''}');
    }
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<Map<String, dynamic>> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async =>
      Map<String, dynamic>.from(await api.post('/auth/register', {
        'nama': nama,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }));

  @override
  Future<UserProfile> verifikasiEmail(String email, String kode) async {
    final d = await api.post('/auth/verify', {'email': email, 'kode': kode});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'}) async =>
      '${(await api.post('/auth/resend', {'email': email, 'tipe': tipe}))['pesan']}';

  @override
  Future<String> lupaPassword(String email) async =>
      '${(await api.post('/auth/forgot', {'email': email}))['pesan']}';

  @override
  Future<UserProfile> resetPassword({
    required String email,
    required String kode,
    required String password,
  }) async {
    final d = await api.post('/auth/reset', {'email': email, 'kode': kode, 'password': password});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<KonfigurasiApp> konfigurasi() async =>
      KonfigurasiApp.fromJson(Map<String, dynamic>.from(await api.get('/config')));

  @override
  Future<Map<String, dynamic>> legal(String jenis) async =>
      Map<String, dynamic>.from(await api.get('/legal/$jenis'));

  @override
  Future<UserProfile> profilSaya() async => UserProfile.fromJson(await api.get('/me'));

  @override
  Future<UserProfile> masukGoogleNative(String idToken) async {
    final d = await api.post('/auth/google/native', {'id_token': idToken});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  void pasangToken(String token) => api.setToken(token);

  @override
  Future<List<Ulasan>> ulasan(String produkId) async =>
      ((await api.get('/akun/produk/$produkId/ulasan')) as List).map((e) => Ulasan.fromJson(e)).toList();

  @override
  Future<Ulasan> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) async =>
      Ulasan.fromJson(Map<String, dynamic>.from(await api.post('/ulasan', {
        'produk_id': produkId,
        'rating': rating,
        'komentar': komentar,
        if (gambar != null) 'gambar': gambar,
      })));

  @override
  Future<PermintaanTopup> buatTopup(int nominal, String metode) async =>
      PermintaanTopup.fromJson(Map<String, dynamic>.from(
          await api.post('/wallet/topup', {'nominal': nominal, 'metode': metode})));

  @override
  Future<List<PermintaanTopup>> daftarTopup() async =>
      ((await api.get('/wallet/topup')) as List).map((e) => PermintaanTopup.fromJson(e)).toList();

  @override
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri) async =>
      PermintaanTopup.fromJson(Map<String, dynamic>.from(
          await api.post('/wallet/topup/$idTopup/bukti', {'file': dataUri})));

  @override
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum}) async =>
      UserProfile.fromJson(await api.patch('/me', {
        if (nama != null) 'nama': nama,
        if (phone != null) 'phone': phone,
        if (foto != null) 'foto': foto,
        if (notifForum != null) 'notif_forum': notifForum ? 1 : 0,
      }));

  @override
  Future<void> gantiPassword(String lama, String baru) async =>
      api.post('/me/password', {'lama': lama, 'baru': baru});

  @override
  Future<SesiMain> sesiMulai(String orderId) async =>
      SesiMain.fromJson(Map<String, dynamic>.from(await api.post('/sesi/mulai', {'order_id': orderId})));

  @override
  Future<SesiMain> sesiStatus(String id) async =>
      SesiMain.fromJson(Map<String, dynamic>.from(await api.get('/sesi/$id')));

  @override
  Future<void> sesiPin(String id, String pin) async => api.post('/sesi/$id/pin', {'pin': pin});

  @override
  Future<void> sesiAkhiri(String id) async => api.post('/sesi/$id/akhiri');

  @override
  Future<List<ForumPost>> forum() async =>
      ((await api.get('/forum')) as List).map((e) => ForumPost.fromJson(e)).toList();

  @override
  Future<List<ForumBalasan>> forumDetail(String id) async {
    final d = await api.get('/forum/$id');
    return ((d['balasan'] as List?) ?? const []).map((e) => ForumBalasan.fromJson(e)).toList();
  }

  @override
  Future<ForumPost> forumBuat({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) async =>
      ForumPost.fromJson(Map<String, dynamic>.from(await api.post('/forum', {
        'judul': judul,
        'isi': isi,
        'kategori': kategori,
        if (gambar != null) 'gambar': gambar,
      })));

  @override
  Future<ForumBalasan> forumBalas(String id, String isi) async =>
      ForumBalasan.fromJson(Map<String, dynamic>.from(await api.post('/forum/$id/balas', {'isi': isi})));

  @override
  Future<Map<String, dynamic>> forumSuka(String id) async =>
      Map<String, dynamic>.from(await api.post('/forum/$id/suka'));

  @override
  Future<List<String>> forumSukaSaya() async =>
      ((await api.get('/forum/suka/saya')) as List).map((e) => '$e').toList();

  @override
  Future<void> forumHapus(String id) async => api.delete('/forum/$id');

  @override
  Future<List<PcPlan>> plans() async =>
      ((await api.get('/pc/plans')) as List).map((e) => PcPlan.fromJson(e)).toList();

  @override
  Future<List<AkunProduk>> produkAkun() async =>
      ((await api.get('/akun/produk')) as List).map((e) => AkunProduk.fromJson(e)).toList();

  @override
  Future<List<PromoBanner>> banners() async =>
      ((await api.get('/banners')) as List).map((e) => PromoBanner.fromJson(e)).toList();

  @override
  Future<List<RentOrder>> orders() async =>
      ((await api.get('/orders')) as List).map((e) => RentOrder.fromJson(e)).toList();

  @override
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode}) async =>
      RentOrder.fromJson(await api.post('/orders', {'plan_id': plan.id, 'durasi_jam': jam, 'metode': metode}));

  @override
  Future<RentOrder> orderDetail(String id) async => RentOrder.fromJson(await api.get('/orders/$id'));

  @override
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode}) async =>
      Map<String, dynamic>.from(await api.post('/akun/beli', {'produk_id': produk.id, 'metode': metode}));

  @override
  Future<List<Transaksi>> transaksi() async =>
      ((await api.get('/wallet/transaksi')) as List).map((e) => Transaksi.fromJson(e)).toList();

  @override
  @override
  Future<List<ChatMessage>> riwayatChat() async =>
      ((await api.get('/cs/messages')) as List).map((e) => ChatMessage.fromJson(e)).toList();

  @override
  Future<void> kirimChat(String teks, {String? gambar}) async =>
      api.post('/cs/messages', {'teks': teks, if (gambar != null) 'gambar': gambar});
}

// ------------------------------------------------------------------
// MOCK — jalan tanpa server
// ------------------------------------------------------------------
class MockRepository implements XyRepository {
  final _plans = MockData.plans();
  final _akun = MockData.akun();
  final _orders = MockData.orders();
  final _trx = MockData.transaksi();
  final _chat = MockData.chatAwal();

  Future<T> _delay<T>(T v, [int ms = 500]) =>
      Future.delayed(Duration(milliseconds: ms + Random().nextInt(250)), () => v);

  @override
  Future<UserProfile> login(String email, String password) => _delay(MockData.user, 800);

  @override
  Future<Map<String, dynamic>> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async {
    MockData.user = UserProfile(id: 'u_demo', nama: nama, email: email, phone: phone, saldo: 0, tier: 'basic');
    return _delay({'perluVerifikasi': true, 'email': email, 'nama': nama, 'pesan': 'Kode demo: 123456'}, 700);
  }

  @override
  Future<UserProfile> verifikasiEmail(String email, String kode) => _delay(MockData.user, 600);

  @override
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'}) =>
      _delay('Kode demo dikirim ulang: 123456', 400);

  @override
  Future<String> lupaPassword(String email) => _delay('Kode demo reset: 123456', 400);

  @override
  Future<UserProfile> resetPassword({required String email, required String kode, required String password}) =>
      _delay(MockData.user, 600);

  @override
  Future<KonfigurasiApp> konfigurasi() =>
      _delay(const KonfigurasiApp(googleAktif: false, facebookAktif: false, whatsapp: '', minTopup: 10000), 200);

  @override
  Future<Map<String, dynamic>> legal(String jenis) => _delay(
        {'judul': jenis, 'pembaruan': '-', 'bagian': const [], 'lisensi': const []},
        200,
      );

  @override
  Future<UserProfile> profilSaya() => _delay(MockData.user, 200);

  @override
  Future<UserProfile> masukGoogleNative(String idToken) => _delay(MockData.user, 500);

  @override
  void pasangToken(String token) {}

  @override
  Future<List<Ulasan>> ulasan(String produkId) => _delay(<Ulasan>[], 300);

  @override
  Future<Ulasan> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) =>
      _delay(
        Ulasan(
          id: 'r_demo', produkId: produkId, nama: MockData.user.nama, rating: rating,
          komentar: komentar, waktu: DateTime.now(),
        ),
        400,
      );

  @override
  Future<PermintaanTopup> buatTopup(int nominal, String metode) => _delay(
        PermintaanTopup(
          id: 'tp_demo', nominal: nominal, kodeUnik: 123, total: nominal + 123,
          metode: metode, status: 'menunggu', dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<List<PermintaanTopup>> daftarTopup() => _delay(<PermintaanTopup>[], 300);

  @override
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum}) =>
      _delay(MockData.user, 400);

  @override
  Future<void> gantiPassword(String lama, String baru) async {}

  @override
  Future<SesiMain> sesiMulai(String orderId) => _delay(
        SesiMain(id: 's_demo', orderId: orderId, status: 'siap', host: '103.10.20.30', durasiMenit: 60),
        700,
      );

  @override
  Future<SesiMain> sesiStatus(String id) => _delay(
        SesiMain(id: id, orderId: 'o_demo', status: 'siap', host: '103.10.20.30'),
        300,
      );

  @override
  Future<void> sesiPin(String id, String pin) async {}

  @override
  Future<void> sesiAkhiri(String id) async {}

  @override
  Future<List<ForumPost>> forum() => _delay(<ForumPost>[], 300);

  @override
  Future<List<ForumBalasan>> forumDetail(String id) => _delay(<ForumBalasan>[], 300);

  @override
  Future<ForumPost> forumBuat({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) =>
      _delay(
        ForumPost(
          id: 'f_demo', userId: 'u_demo', nama: MockData.user.nama, kategori: kategori,
          judul: judul, isi: isi, dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<ForumBalasan> forumBalas(String id, String isi) => _delay(
        ForumBalasan(id: 'fb_demo', postId: id, nama: MockData.user.nama, isi: isi, dibuat: DateTime.now()),
        300,
      );

  @override
  Future<Map<String, dynamic>> forumSuka(String id) => _delay({'suka': 1, 'disukai': true}, 200);

  @override
  Future<List<String>> forumSukaSaya() => _delay(<String>[], 200);

  @override
  Future<void> forumHapus(String id) async {}

  @override
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri) => _delay(
        PermintaanTopup(
          id: idTopup, nominal: 0, kodeUnik: 0, total: 0, metode: 'transfer',
          status: 'diperiksa', dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<List<PcPlan>> plans() => _delay(_plans);

  @override
  Future<List<AkunProduk>> produkAkun() => _delay(_akun);

  @override
  Future<List<PromoBanner>> banners() => _delay(MockData.banners(), 200);

  @override
  Future<List<RentOrder>> orders() => _delay(_orders);

  @override
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode}) async {
    final kode = 'XY-${9000 + Random().nextInt(999)}';
    final o = RentOrder(
      id: 'o_${DateTime.now().millisecondsSinceEpoch}',
      kode: kode,
      planId: plan.id,
      planNama: plan.nama,
      durasiJam: jam,
      total: plan.hargaPerJam * jam,
      status: OrderStatus.pending,
      dibuat: DateTime.now(),
    );
    _orders.insert(0, o);
    if (plan.unitTersedia > 0) plan.unitTersedia--;
    _trx.insert(0, Transaksi(id: 'tx${o.id}', judul: 'Sewa ${plan.nama} $jam jam', tipe: 'sewa', nominal: -o.total, waktu: DateTime.now(), status: 'sukses'));
    return _delay(o, 700);
  }

  @override
  Future<RentOrder> orderDetail(String id) async => _delay(_orders.firstWhere((e) => e.id == id), 200);

  @override
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode}) async {
    _trx.insert(0, Transaksi(id: 'tx${DateTime.now().millisecondsSinceEpoch}', judul: 'Beli ${produk.nama}', tipe: 'akun', nominal: -produk.harga, waktu: DateTime.now(), status: 'sukses'));
    return _delay({
      'kode': 'AK-${1000 + Random().nextInt(8999)}',
      'email': 'xy${Random().nextInt(9999)}@mail.xycloud.id',
      'password': 'Xy${Random().nextInt(99999)}!',
      'catatan': 'Segera ganti password setelah login. Garansi ${produk.garansi}.',
    }, 1200);
  }

  @override
  Future<List<Transaksi>> transaksi() => _delay(_trx);

  @override
  Future<List<ChatMessage>> riwayatChat() => _delay(_chat, 300);

  @override
  Future<void> kirimChat(String teks, {String? gambar}) async {}
}
