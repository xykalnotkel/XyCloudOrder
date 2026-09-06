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
  Future<List<PcPlan>> plans();
  Future<List<AkunProduk>> produkAkun();
  Future<List<PromoBanner>> banners();
  Future<List<RentOrder>> orders();
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode});
  Future<RentOrder> orderDetail(String id);
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode});
  Future<List<Transaksi>> transaksi();
  Future<int> topup(int nominal);
  Future<List<ChatMessage>> riwayatChat();
  Future<void> kirimChat(String teks);

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
  Future<int> topup(int nominal) async => (await api.post('/wallet/topup', {'nominal': nominal}))['saldo'] as int;

  @override
  Future<List<ChatMessage>> riwayatChat() async =>
      ((await api.get('/cs/messages')) as List).map((e) => ChatMessage.fromJson(e)).toList();

  @override
  Future<void> kirimChat(String teks) async => api.post('/cs/messages', {'teks': teks});
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
  Future<int> topup(int nominal) async {
    MockData.user = MockData.user.copyWith(saldo: MockData.user.saldo + nominal);
    _trx.insert(0, Transaksi(id: 'tx${DateTime.now().millisecondsSinceEpoch}', judul: 'Top up saldo', tipe: 'topup', nominal: nominal, waktu: DateTime.now(), status: 'sukses'));
    return _delay(MockData.user.saldo, 900);
  }

  @override
  Future<List<ChatMessage>> riwayatChat() => _delay(_chat, 300);

  @override
  Future<void> kirimChat(String teks) async {}
}
