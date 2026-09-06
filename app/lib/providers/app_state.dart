import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../data/realtime_service.dart';
import '../data/repository.dart';
import '../models/models.dart';

/// State global aplikasi + jembatan ke channel realtime.
class AppState extends ChangeNotifier {
  AppState() {
    _api = ApiClient();
    _repo = XyRepository.create(_api);
  }

  late final ApiClient _api;
  late final XyRepository _repo;
  RealtimeService? _rt;
  StreamSubscription? _rtSub;
  StreamSubscription? _rtState;
  Timer? _mockTicker;
  Timer? _clock;

  // ---------------- state ----------------
  UserProfile? user;
  bool loading = false;
  String? error;

  List<PcPlan> plans = [];
  List<AkunProduk> produk = [];
  List<RentOrder> orders = [];
  List<Transaksi> transaksi = [];
  List<ChatMessage> chat = [];

  RealtimeState koneksi = RealtimeState.offline;
  bool csMengetik = false;
  int notifBelumDibaca = 0;

  bool get masuk => user != null;
  RentOrder? get orderAktif {
    try {
      return orders.firstWhere((o) =>
          o.status == OrderStatus.aktif ||
          o.status == OrderStatus.provisioning ||
          o.status == OrderStatus.dibayar ||
          o.status == OrderStatus.pending);
    } catch (_) {
      return null;
    }
  }

  // ---------------- auth ----------------
  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.login(email, password);
      await muatSemua();
      _mulaiRealtime();
      return true;
    } catch (e) {
      error = 'Login gagal: $e';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void logout() {
    user = null;
    orders = [];
    chat = [];
    _rt?.dispose();
    _rt = null;
    _mockTicker?.cancel();
    _clock?.cancel();
    notifyListeners();
  }

  // ---------------- data ----------------
  Future<void> muatSemua() async {
    final hasil = await Future.wait([
      _repo.plans(),
      _repo.produkAkun(),
      _repo.orders(),
      _repo.transaksi(),
      _repo.riwayatChat(),
    ]);
    plans = hasil[0] as List<PcPlan>;
    produk = hasil[1] as List<AkunProduk>;
    orders = hasil[2] as List<RentOrder>;
    transaksi = hasil[3] as List<Transaksi>;
    chat = hasil[4] as List<ChatMessage>;
    notifyListeners();
  }

  Future<void> refresh() => muatSemua();

  // ---------------- realtime ----------------
  void _mulaiRealtime() {
    // jam berdetak: countdown sesi aktif ter-update tiap detik
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (orders.any((o) => o.status == OrderStatus.aktif)) notifyListeners();
    });

    if (XyConfig.useMock) {
      _mulaiSimulasi();
      koneksi = RealtimeState.online;
      notifyListeners();
      return;
    }

    _rt = RealtimeService();
    _rtState = _rt!.state.listen((s) {
      koneksi = s;
      notifyListeners();
    });
    _rtSub = _rt!.events.listen(_handleEvent);
    _rt!.connect(room: 'user:${user!.id}', token: _api.token ?? '');
  }

  void _handleEvent(RealtimeEvent e) {
    switch (e.type) {
      case 'order.update':
        final upd = RentOrder.fromJson(e.payload);
        final i = orders.indexWhere((o) => o.id == upd.id);
        if (i >= 0) {
          orders[i] = upd;
        } else {
          orders.insert(0, upd);
        }
        notifBelumDibaca++;
        break;
      case 'stock.update':
        final id = '${e.payload['id']}';
        final n = e.payload['unitTersedia'] ?? e.payload['unit_tersedia'];
        final p = plans.where((x) => x.id == id).firstOrNull;
        if (p != null && n is int) p.unitTersedia = n;
        break;
      case 'chat.message':
        chat.add(ChatMessage.fromJson(e.payload));
        csMengetik = false;
        notifBelumDibaca++;
        break;
      case 'cs.typing':
        csMengetik = e.payload['typing'] == true;
        break;
      case 'wallet.update':
        user = user?.copyWith(saldo: e.payload['saldo'] as int);
        break;
    }
    notifyListeners();
  }

  /// Simulasi event realtime untuk mode demo.
  void _mulaiSimulasi() {
    _mockTicker?.cancel();
    _mockTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      var berubah = false;

      // stok PC naik-turun seperti trafik asli
      if (plans.isNotEmpty && Random().nextBool()) {
        final p = plans[Random().nextInt(plans.length)];
        final delta = Random().nextBool() ? 1 : -1;
        final baru = (p.unitTersedia + delta).clamp(0, p.totalUnit);
        if (baru != p.unitTersedia) {
          p.unitTersedia = baru;
          berubah = true;
        }
      }

      // alur order otomatis: pending -> dibayar -> provisioning -> aktif
      for (final o in orders) {
        switch (o.status) {
          case OrderStatus.pending:
            o.status = OrderStatus.dibayar;
            berubah = true;
            break;
          case OrderStatus.dibayar:
            o.status = OrderStatus.provisioning;
            o.progress = 10;
            berubah = true;
            break;
          case OrderStatus.provisioning:
            o.progress = (o.progress + 25 + Random().nextInt(20)).clamp(0, 100);
            if (o.progress >= 100) {
              o.status = OrderStatus.aktif;
              o.mulai = DateTime.now();
              o.berakhir = DateTime.now().add(Duration(hours: o.durasiJam));
              o.host = '103.44.12.${20 + Random().nextInt(200)}:3389';
              o.username = 'xy_${o.kode.toLowerCase().replaceAll('-', '')}';
              o.password = 'Xy#${Random().nextInt(9999)}ok';
            }
            berubah = true;
            break;
          case OrderStatus.aktif:
            if (o.berakhir != null && o.berakhir!.isBefore(DateTime.now())) {
              o.status = OrderStatus.selesai;
              berubah = true;
            }
            break;
          default:
            break;
        }
      }
      if (berubah) notifyListeners();
    });
  }

  // ---------------- aksi ----------------
  Future<RentOrder?> sewaPc(PcPlan plan, int jam, String metode) async {
    try {
      final o = await _repo.buatOrderSewa(plan: plan, jam: jam, metode: metode);
      if (!orders.any((x) => x.id == o.id)) orders.insert(0, o);
      if (metode == 'saldo' && user != null) {
        user = user!.copyWith(saldo: (user!.saldo - o.total).clamp(0, 1 << 31));
      }
      transaksi = await _repo.transaksi();
      notifyListeners();
      return o;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> beliAkun(AkunProduk p, String metode) async {
    try {
      final r = await _repo.beliAkun(produk: p, metode: metode);
      if (metode == 'saldo' && user != null) {
        user = user!.copyWith(saldo: (user!.saldo - p.harga).clamp(0, 1 << 31));
      }
      transaksi = await _repo.transaksi();
      notifyListeners();
      return r;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<void> topup(int nominal) async {
    final saldo = await _repo.topup(nominal);
    user = user?.copyWith(saldo: saldo);
    transaksi = await _repo.transaksi();
    notifyListeners();
  }

  Future<void> kirimChat(String teks) async {
    final msg = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      room: 'cs',
      dari: 'user',
      teks: teks,
      waktu: DateTime.now(),
      terkirim: false,
    );
    chat.add(msg);
    notifyListeners();

    if (XyConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      msg.terkirim = true;
      csMengetik = true;
      notifyListeners();
      await Future.delayed(Duration(milliseconds: 900 + Random().nextInt(1200)));
      csMengetik = false;
      chat.add(ChatMessage(
        id: 'cs_${DateTime.now().microsecondsSinceEpoch}',
        room: 'cs',
        dari: 'cs',
        teks: MockData.balasanCs(teks),
        waktu: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    _rt?.send('chat.message', {'teks': teks});
    try {
      await _repo.kirimChat(teks);
      msg.terkirim = true;
    } catch (_) {}
    notifyListeners();
  }

  void ketikCs(bool val) => _rt?.send('user.typing', {'typing': val});

  void bacaNotif() {
    notifBelumDibaca = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _rtState?.cancel();
    _rt?.dispose();
    _mockTicker?.cancel();
    _clock?.cancel();
    _api.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
