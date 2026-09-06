import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../data/login_sosial.dart';
import '../data/push_service.dart';
import '../data/realtime_service.dart';
import '../data/repository.dart';
import '../models/models.dart';

/// State global aplikasi + jembatan ke channel realtime.
class AppState extends ChangeNotifier {
  AppState() {
    _api = ApiClient();
    _repo = XyRepository.create(_api);
    unawaited(muatKonfigurasi());
    unawaited(pulihkanSesi());
  }

  /// True selama aplikasi masih memeriksa token tersimpan.
  bool memeriksaSesi = true;

  /// Coba masuk otomatis memakai token yang tersimpan di perangkat.
  Future<void> pulihkanSesi() async {
    try {
      final t = await Prefs.token();
      if (t == null || t.isEmpty) return;
      _repo.pasangToken(t);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
    } catch (_) {
      // token kedaluwarsa atau tidak valid
      await Prefs.hapusToken();
      _repo.pasangToken('');
      user = null;
    } finally {
      memeriksaSesi = false;
      notifyListeners();
    }
  }

  late final ApiClient _api;
  late final XyRepository _repo;
  RealtimeService? _rt;
  RealtimeService? _rtKatalog;
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
  List<PromoBanner> banners = [];
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
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } on PerluVerifikasi catch (e) {
      emailMenungguVerifikasi = e.email;
      error = e.pesan;
      return false;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Hasil pendaftaran: minta pengguna memasukkan kode dari email.
  String? emailMenungguVerifikasi;

  Future<Map<String, dynamic>?> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final d = await _repo.daftar(nama: nama, email: email, password: password, phone: phone);
      emailMenungguVerifikasi = '${d['email'] ?? email}';
      return d;
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> verifikasiEmail(String email, String kode) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.verifikasiEmail(email, kode);
      emailMenungguVerifikasi = null;
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> kirimUlangKode(String email, {String tipe = 'verifikasi'}) async {
    try {
      return await _repo.kirimUlangKode(email, tipe: tipe);
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  Future<String?> lupaPassword(String email) async {
    loading = true;
    notifyListeners();
    try {
      return await _repo.lupaPassword(email);
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({required String email, required String kode, required String password}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.resetPassword(email: email, kode: kode, password: password);
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ================= konfigurasi server =================
  KonfigurasiApp konfigurasi = const KonfigurasiApp();

  Future<void> muatKonfigurasi() async {
    try {
      konfigurasi = await _repo.konfigurasi();
      notifyListeners();
    } catch (_) {
      // biarkan memakai nilai bawaan kalau server belum bisa dihubungi
    }
  }

  /// Ambil dokumen legal dari server (dengan singgahan sederhana).
  final Map<String, Map<String, dynamic>> _legal = {};

  Future<Map<String, dynamic>> dokumenLegal(String jenis) async {
    if (_legal.containsKey(jenis)) return _legal[jenis]!;
    final d = await _repo.legal(jenis);
    _legal[jenis] = d;
    return d;
  }

  // ================= login lewat Google atau Facebook =================
  /// Dipanggil setelah aplikasi menerima token dari halaman OAuth.
  Future<bool> masukDenganToken(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _repo.pasangToken(token);
      await Prefs.simpanToken(token);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Login Google: coba dialog native dulu, kalau tidak bisa baru lewat halaman.
  Future<bool> masukGoogle() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final idToken = await LoginSosial.idTokenGoogleNative();
      if (idToken != null) {
        user = await _repo.masukGoogleNative(idToken);
        await _simpanSesi();
        await muatSemua();
        _mulaiRealtime();
        _daftarkanPush();
        return true;
      }
      // perangkat belum mendukung dialog native
      final token = await LoginSosial.tokenLewatHalaman('google');
      _repo.pasangToken(token);
      await Prefs.simpanToken(token);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } on GagalLoginSosial catch (e) {
      error = e.pesan;
      return false;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ================= ulasan produk =================
  final Map<String, List<Ulasan>> _ulasan = {};

  List<Ulasan> ulasanProduk(String produkId) => _ulasan[produkId] ?? const [];

  Future<List<Ulasan>> muatUlasan(String produkId) async {
    try {
      final data = await _repo.ulasan(produkId);
      _ulasan[produkId] = data;
      notifyListeners();
      return data;
    } catch (_) {
      return _ulasan[produkId] ?? const [];
    }
  }

  Future<String?> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) async {
    try {
      await _repo.kirimUlasan(produkId: produkId, rating: rating, komentar: komentar, gambar: gambar);
      await muatUlasan(produkId);
      await muatProduk();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= dompet: top up sungguhan =================
  List<PermintaanTopup> topupSaya = [];

  Future<void> muatTopup() async {
    try {
      topupSaya = await _repo.daftarTopup();
      notifyListeners();
    } catch (_) {}
  }

  Future<PermintaanTopup?> buatTopup(int nominal, String metode) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final t = await _repo.buatTopup(nominal, metode);
      await muatTopup();
      return t;
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> unggahBukti(String idTopup, String dataUri) async {
    try {
      await _repo.unggahBukti(idTopup, dataUri);
      await muatTopup();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Simpan token aktif supaya sesi bertahan setelah aplikasi ditutup.
  Future<void> _simpanSesi() async {
    final t = _api.token;
    if (t != null && t.isNotEmpty) await Prefs.simpanToken(t);
  }

  /// Hubungkan akun ini ke OneSignal supaya notifikasi tetap masuk saat aplikasi tertutup.
  void _daftarkanPush() {
    final id = user?.id;
    if (id != null) PushService.masuk(id);
  }

  /// Ubah pesan kesalahan teknis jadi kalimat yang mudah dimengerti.
  String _pesan(Object e) {
    final t = e.toString();
    final i = t.indexOf('): ');
    if (i > 0) return t.substring(i + 3);
    if (t.contains('SocketException') || t.contains('Failed host lookup') || t.contains('TimeoutException')) {
      return 'Tidak bisa terhubung ke server. Cek koneksi internet kamu.';
    }
    return t.replaceFirst('Exception: ', '');
  }

  void logout() {
    unawaited(Prefs.hapusToken());
    _api.setToken(null);
    PushService.keluar();
    user = null;
    orders = [];
    chat = [];
    _rt?.dispose();
    _rt = null;
    _rtKatalog?.dispose();
    _rtKatalog = null;
    _mockTicker?.cancel();
    _clock?.cancel();
    notifyListeners();
  }

  // ---------------- data ----------------
  Future<void> muatSemua() async {
    final hasil = await Future.wait([
      _repo.plans(),
      _repo.produkAkun(),
      _repo.banners(),
      _repo.orders(),
      _repo.transaksi(),
      _repo.riwayatChat(),
    ]);
    plans = hasil[0] as List<PcPlan>;
    produk = hasil[1] as List<AkunProduk>;
    banners = hasil[2] as List<PromoBanner>;
    orders = hasil[3] as List<RentOrder>;
    transaksi = hasil[4] as List<Transaksi>;
    chat = hasil[5] as List<ChatMessage>;
    notifyListeners();
    // data pelengkap, tidak perlu ditunggu
    unawaited(muatTopup());
  }

  /// Muat ulang daftar produk saja (dipakai setelah menulis ulasan).
  Future<void> muatProduk() async {
    try {
      produk = await _repo.produkAkun();
      notifyListeners();
    } catch (_) {}
  }

  /// Muat ulang riwayat chat.
  Future<void> muatChat() async {
    try {
      chat = await _repo.riwayatChat();
      notifyListeners();
    } catch (_) {}
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

    // channel katalog: stok unit dan banner promo untuk semua pengguna
    _rtKatalog = RealtimeService();
    _rtKatalog!.events.listen(_handleEvent);
    _rtKatalog!.connect(room: 'katalog', token: _api.token ?? '');
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
      case 'banner.update':
        try {
          final list = (e.payload['banners'] as List?) ?? const [];
          banners = list.map((x) => PromoBanner.fromJson(Map<String, dynamic>.from(x))).toList();
        } catch (_) {}
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



  Future<void> kirimChat(String teks, {String? gambar, String? pratinjau}) async {
    final msg = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      room: 'cs',
      dari: 'user',
      teks: teks,
      gambar: pratinjau,
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

    if (gambar == null) _rt?.send('chat.message', {'teks': teks});
    try {
      await _repo.kirimChat(teks, gambar: gambar);
      msg.terkirim = true;
      if (gambar != null) await muatChat();
    } catch (e) {
      error = _pesan(e);
    }
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
    _rtKatalog?.dispose();
    _mockTicker?.cancel();
    _clock?.cancel();
    _api.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
