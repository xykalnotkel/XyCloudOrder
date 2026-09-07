import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/cache.dart';
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

  /// True kalau permintaan terakhir ke server gagal karena jaringan.
  bool offline = false;

  /// Data yang tampil sekarang berasal dari singgahan, bukan server.
  bool dariCache = false;

  /// Hemat kuota: gambar produk dan banner tidak diunduh.
  bool hematData = false;

  Future<void> setHematData(bool v) async {
    hematData = v;
    await Cache.setHematData(v);
    notifyListeners();
  }

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
  RealtimeService? _rtForum;
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

  // ================= sesi main di PC sewaan =================
  Future<SesiMain?> mulaiSesi(String orderId) async {
    error = null;
    try {
      return await _repo.sesiMulai(orderId);
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  Future<SesiMain?> statusSesi(String id) async {
    try {
      return await _repo.sesiStatus(id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> kirimPinSesi(String id, String pin) async {
    try {
      await _repo.sesiPin(id, pin);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<void> akhiriSesi(String id) async {
    try {
      await _repo.sesiAkhiri(id);
    } catch (_) {}
  }

  // ================= profil =================
  Future<String?> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum}) async {
    try {
      user = await _repo.perbaruiProfil(nama: nama, phone: phone, foto: foto, notifForum: notifForum);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> gantiPassword(String lama, String baru) async {
    try {
      await _repo.gantiPassword(lama, baru);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= forum komunitas =================
  List<ForumPost> forum = [];
  Set<String> forumDisukai = {};
  bool forumMemuat = false;
  String? forumGalat;

  Future<void> muatForum({bool paksa = false}) async {
    if (forumMemuat) return;
    forumMemuat = true;
    forumGalat = null;
    notifyListeners();

    if (!paksa && forum.isEmpty) {
      final simpanan = await Cache.daftar('forum');
      if (simpanan.isNotEmpty) {
        forum = simpanan.map((e) => ForumPost.fromJson(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
      }
    }

    try {
      forum = await _repo.forum();
      offline = false;
      unawaited(Cache.simpan('forum', forum.map((e) => e.toJson()).toList()));
      if (user != null) {
        try {
          forumDisukai = (await _repo.forumSukaSaya()).toSet();
        } catch (_) {}
      }
    } catch (e) {
      offline = _masalahJaringan(e);
      forumGalat = _pesan(e);
    } finally {
      forumMemuat = false;
      notifyListeners();
    }
  }

  Future<List<ForumBalasan>> detailForum(String id) => _repo.forumDetail(id);

  Future<String?> buatForum({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) async {
    try {
      final post = await _repo.forumBuat(judul: judul, isi: isi, kategori: kategori, gambar: gambar);
      forum.insert(0, post);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> balasForum(String id, String isi, {String? balasKe}) async {
    try {
      await _repo.forumBalas(id, isi, balasKe: balasKe);
      final i = forum.indexWhere((f) => f.id == id);
      if (i >= 0) forum[i].balasan++;
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<void> sukaForum(String id) async {
    // tampilkan perubahan lebih dulu supaya terasa cepat
    final i = forum.indexWhere((f) => f.id == id);
    final tadinya = forumDisukai.contains(id);
    if (i >= 0) forum[i].suka += tadinya ? -1 : 1;
    tadinya ? forumDisukai.remove(id) : forumDisukai.add(id);
    notifyListeners();

    try {
      final d = await _repo.forumSuka(id);
      if (i >= 0) forum[i].suka = d['suka'] ?? forum[i].suka;
      if (d['disukai'] == true) {
        forumDisukai.add(id);
      } else {
        forumDisukai.remove(id);
      }
    } catch (_) {
      // kembalikan seperti semula kalau gagal
      if (i >= 0) forum[i].suka += tadinya ? 1 : -1;
      tadinya ? forumDisukai.add(id) : forumDisukai.remove(id);
    }
    notifyListeners();
  }

  Future<String?> suntingForum({
    required String id,
    required String judul,
    required String isi,
    String? kategori,
  }) async {
    try {
      final baru = await _repo.forumSunting(id: id, judul: judul, isi: isi, kategori: kategori);
      final i = forum.indexWhere((f) => f.id == id);
      if (i >= 0) forum[i] = baru;
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> hapusBalasanForum(String id, String postId) async {
    try {
      await _repo.forumHapusBalasan(id);
      final i = forum.indexWhere((f) => f.id == postId);
      if (i >= 0 && forum[i].balasan > 0) forum[i].balasan--;
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus satu pesan chat milik sendiri.
  Future<String?> hapusPesan(String id) async {
    try {
      await _repo.hapusPesan(id);
      chat.removeWhere((m) => m.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Bersihkan seluruh pesan yang pernah kukirim.
  Future<String?> hapusSemuaPesan() async {
    try {
      await _repo.hapusSemuaPesan();
      await muatChat();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> hapusForum(String id) async {
    try {
      await _repo.forumHapus(id);
      forum.removeWhere((f) => f.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
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
    _rtForum?.dispose();
    _rtKatalog = null;
    _rtForum?.dispose();
    _rtForum = null;
    _mockTicker?.cancel();
    _clock?.cancel();
    notifyListeners();
  }

  // ---------------- data ----------------
  /// Ambil semua data. Singgahan ditampilkan lebih dulu supaya layar
  /// langsung terisi, lalu diperbarui begitu server menjawab.
  Future<void> muatSemua({bool paksa = false}) async {
    hematData = await Cache.hematData();
    if (!paksa) await _muatDariCache();

    try {
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

      offline = false;
      dariCache = false;
      error = null;
      unawaited(_simpanCache());
      unawaited(muatTopup());
    } catch (e) {
      offline = _masalahJaringan(e);
      error = _pesan(e);
      // kalau belum ada isi sama sekali, coba singgahan sebagai penyelamat
      if (plans.isEmpty && produk.isEmpty) await _muatDariCache();
    }
    notifyListeners();
  }

  bool _masalahJaringan(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('socket') ||
        t.contains('failed host') ||
        t.contains('timeout') ||
        t.contains('connection') ||
        t.contains('jaringan') ||
        t.contains('koneksi');
  }

  Future<void> _muatDariCache() async {
    try {
      final p = await Cache.daftar('plans');
      final pr = await Cache.daftar('produk');
      final bn = await Cache.daftar('banners');
      final od = await Cache.daftar('orders');
      final tr = await Cache.daftar('transaksi');
      if (p.isEmpty && pr.isEmpty) return;

      plans = p.map((e) => PcPlan.fromJson(Map<String, dynamic>.from(e))).toList();
      produk = pr.map((e) => AkunProduk.fromJson(Map<String, dynamic>.from(e))).toList();
      banners = bn.map((e) => PromoBanner.fromJson(Map<String, dynamic>.from(e))).toList();
      orders = od.map((e) => RentOrder.fromJson(Map<String, dynamic>.from(e))).toList();
      transaksi = tr.map((e) => Transaksi.fromJson(Map<String, dynamic>.from(e))).toList();
      dariCache = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _simpanCache() async {
    try {
      await Cache.simpan('plans', plans.map((e) => e.toJson()).toList());
      await Cache.simpan('produk', produk.map((e) => e.toJson()).toList());
      await Cache.simpan('banners', banners.map((e) => e.toJson()).toList());
      await Cache.simpan('orders', orders.map((e) => e.toJson()).toList());
      await Cache.simpan('transaksi', transaksi.map((e) => e.toJson()).toList());
    } catch (_) {}
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

  Future<void> refresh() => muatSemua(paksa: true);

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

    _rtForum = RealtimeService();
    _rtForum!.events.listen(_handleEvent);
    _rtForum!.connect(room: 'forum', token: _api.token ?? '');
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
        _terimaPesan(ChatMessage.fromJson(e.payload));
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
      case 'sesi.update':
        // status sesi diperbarui oleh agen PC
        break;
      case 'chat.hapus':
        chat.removeWhere((m) => m.id == '${e.payload['id']}');
        break;
      case 'forum.ubah':
        try {
          final p = ForumPost.fromJson(Map<String, dynamic>.from(e.payload));
          final i = forum.indexWhere((f) => f.id == p.id);
          if (i >= 0) forum[i] = p;
        } catch (_) {}
        break;
      case 'forum.balasan.hapus':
        try {
          final i = forum.indexWhere((f) => f.id == '${e.payload['post_id']}');
          if (i >= 0 && forum[i].balasan > 0) forum[i].balasan--;
        } catch (_) {}
        break;
      case 'forum.baru':
        try {
          final p = ForumPost.fromJson(Map<String, dynamic>.from(e.payload));
          if (!forum.any((f) => f.id == p.id)) forum.insert(0, p);
        } catch (_) {}
        break;
      case 'forum.balasan':
        try {
          final id = '${e.payload['post_id']}';
          final i = forum.indexWhere((f) => f.id == id);
          if (i >= 0) forum[i].balasan++;
        } catch (_) {}
        break;
      case 'forum.suka':
        try {
          final i = forum.indexWhere((f) => f.id == '${e.payload['id']}');
          if (i >= 0) forum[i].suka = e.payload['suka'] ?? forum[i].suka;
        } catch (_) {}
        break;
      case 'forum.hapus':
        forum.removeWhere((f) => f.id == '${e.payload['id']}');
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

    // hanya lewat REST; server yang menyiarkan ke WebSocket,
    // jadi pesan tidak akan tampil dua kali
    try {
      await _repo.kirimChat(teks, gambar: gambar);
      msg.terkirim = true;
      if (gambar != null) await muatChat();
    } catch (e) {
      error = _pesan(e);
      msg.gagal = true;
    }
    notifyListeners();
  }

  /// Masukkan pesan dari server sambil mencegah pesan kembar.
  ///
  /// Pesan yang baru saja kita kirim sudah tampil duluan sebagai pesan
  /// sementara, jadi versi dari server dipakai untuk menggantikannya,
  /// bukan ditambahkan lagi.
  void _terimaPesan(ChatMessage baru) {
    // sudah ada dengan id yang sama
    if (chat.any((m) => m.id == baru.id)) return;

    if (baru.milikSaya) {
      final i = chat.lastIndexWhere(
        (m) => m.id.startsWith('local_') && m.dari == 'user' && m.teks == baru.teks,
      );
      if (i >= 0) {
        chat[i] = baru;
        csMengetik = false;
        notifyListeners();
        return;
      }
    }

    chat.add(baru);
    csMengetik = false;
    if (!baru.milikSaya) notifBelumDibaca++;
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
    _rtForum?.dispose();
    _mockTicker?.cancel();
    _clock?.cancel();
    _api.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
