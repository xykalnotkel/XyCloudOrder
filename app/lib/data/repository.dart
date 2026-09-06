import 'dart:async';
import 'dart:math';
import '../core/config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data.dart';

/// Satu pintu untuk semua data. Mode mock & mode server (Cloudflare Worker)
/// punya kontrak yang sama, jadi UI tidak perlu tahu bedanya.
abstract class XyRepository {
  Future<UserProfile> login(String email, String password);
  Future<List<PcPlan>> plans();
  Future<List<AkunProduk>> produkAkun();
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
  Future<List<PcPlan>> plans() => _delay(_plans);

  @override
  Future<List<AkunProduk>> produkAkun() => _delay(_akun);

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
