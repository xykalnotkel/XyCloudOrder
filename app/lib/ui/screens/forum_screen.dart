import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/error_state.dart';
import '../widgets/lembar.dart';

/// ============================================================
///  Forum komunitas XyCloudStore
/// ============================================================
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  static const kategori = ['Semua', 'Umum', 'Tanya Jawab', 'Tips', 'Jual Beli', 'Keluhan'];
  String pilih = 'Semua';
  String cari = '';
  final _cari = TextEditingController();

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatForum();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final kunci = cari.trim().toLowerCase();
    final daftar = s.forum.where((f) {
      final cocokKategori = pilih == 'Semua' || f.kategori == pilih;
      final cocokCari = kunci.isEmpty ||
          f.judul.toLowerCase().contains(kunci) ||
          f.isi.toLowerCase().contains(kunci) ||
          f.nama.toLowerCase().contains(kunci);
      return cocokKategori && cocokCari;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunitas'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => s.muatForum(paksa: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: Pressable(
              onTap: () => bukaTulisDiskusi(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: XyTheme.gradPrimary,
                  borderRadius: BorderRadius.circular(XyRadius.pill),
                  boxShadow: XyTheme.glow(XyTheme.primary, .25),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Tulis',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        BilahOffline(tampil: s.offline, onCoba: () => s.muatForum(paksa: true)),

        // ---- kolom pencarian ----
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: TextField(
            controller: _cari,
            onChanged: (v) => setState(() => cari = v),
            decoration: InputDecoration(
              hintText: 'Cari diskusi, isi, atau nama penulis',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: cari.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _cari.clear();
                        setState(() => cari = '');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
          ),
        ),

        // ---- pilihan kategori ----
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            itemCount: kategori.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final k = kategori[i];
              final on = k == pilih;
              return Pressable(
                onTap: () => setState(() => pilih = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? XyTheme.primary : XyTheme.surface,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(color: on ? XyTheme.primary : XyTheme.line),
                  ),
                  child: Text(k,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : XyTheme.inkSoft,
                      )),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: s.forumGalat != null && s.forum.isEmpty
              ? GagalMuat(
                  pesan: s.forumGalat!,
                  ilustrasi: s.offline ? 'offline' : 'error',
                  onCoba: () => s.muatForum(paksa: true),
                )
              : s.forumMemuat && s.forum.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : daftar.isEmpty
                      ? Kosong(
                          icon: Icons.forum_outlined,
                          judul: kunci.isEmpty ? 'Belum ada diskusi di sini' : 'Tidak ada yang cocok',
                          sub: kunci.isEmpty
                              ? 'Jadi yang pertama bertanya atau berbagi tips.'
                              : 'Coba kata kunci lain atau ganti kategorinya.',
                          ilustrasi: kunci.isEmpty ? 'forum' : 'kosong',
                        )
                      : RefreshIndicator(
                          color: XyTheme.primary,
                          onRefresh: () => s.muatForum(paksa: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                            itemCount: daftar.length + 1,
                            itemBuilder: (_, i) => i == 0
                                ? _AjakanTulis(nama: s.user?.nama ?? '')
                                : _KartuPost(post: daftar[i - 1]),
                          ),
                        ),
        ),
      ]),
    );
  }
}

/// Kotak ajakan menulis, sekaligus pengganti tombol melayang
/// yang dulu tertutup menu bawah.
class _AjakanTulis extends StatelessWidget {
  const _AjakanTulis({required this.nama});
  final String nama;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: XyCard(
        onTap: () => bukaTulisDiskusi(context),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(gradient: XyTheme.gradPrimary, shape: BoxShape.circle),
            child: Center(
              child: Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Mau tanya atau berbagi tips? Tulis di sini...',
                style: TextStyle(color: XyTheme.muted, fontSize: 13.2)),
          ),
          const Icon(Icons.edit_rounded, size: 18, color: XyTheme.primary),
        ]),
      ),
    );
  }
}

/// Lencana keanggotaan yang tampil di samping nama penulis.
class LencanaTier extends StatelessWidget {
  const LencanaTier(this.tier, {super.key});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final t = tier.toLowerCase();
    if (t.isEmpty) return const SizedBox.shrink();

    final (warna, label, ikon) = switch (t) {
      'admin' => (XyTheme.primary, 'ADMIN', Icons.verified_rounded),
      'vip' => (const Color(0xFFC08A2E), 'VIP', Icons.workspace_premium_rounded),
      'pro' => (XyTheme.violet, 'PRO', Icons.bolt_rounded),
      _ => (XyTheme.muted, 'BASIC', Icons.person_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: warna.withOpacity(.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: warna.withOpacity(.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, size: 9.5, color: warna),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(color: warna, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
      ]),
    );
  }
}

/// Lencana khusus pemberian admin, contohnya XySpace atau Staff.
class LencanaKhusus extends StatelessWidget {
  const LencanaKhusus(this.teks, {super.key});
  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          gradient: XyTheme.gradPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded, size: 9.5, color: Colors.white),
          const SizedBox(width: 3),
          Text(teks.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
        ]),
      );
}

class _KartuPost extends StatelessWidget {
  const _KartuPost({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final disukai = s.forumDisukai.contains(post.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: XyCard(
        onTap: () => Navigator.push(context, xyRoute(ForumDetailScreen(post: post))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(nama: post.nama, foto: post.foto),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(post.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                  LencanaTier(post.tier),
                  if (post.badge != null) LencanaKhusus(post.badge!),
                  if (post.disematkan) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.push_pin_rounded, size: 13, color: XyTheme.primary),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(tanggal(post.dibuat),
                    style: const TextStyle(color: XyTheme.muted, fontSize: 11)),
              ]),
            ),
            Pill(post.kategori, warna: XyTheme.violet),
          ]),
          const SizedBox(height: 12),
          Text(post.judul,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.32, letterSpacing: -.2)),
          const SizedBox(height: 6),
          Text(
            post.isi,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: XyTheme.muted, fontSize: 13, height: 1.55),
          ),
          if (post.gambar != null && !s.hematData) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.md),
              child: Image.network(post.gambar!,
                  height: 160, width: double.infinity, fit: BoxFit.cover, cacheWidth: 900),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Pressable(
              onTap: () => s.sukaForum(post.id),
              child: Row(children: [
                Icon(disukai ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 17, color: disukai ? XyTheme.danger : XyTheme.muted),
                const SizedBox(width: 5),
                Text('${post.suka}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: disukai ? XyTheme.danger : XyTheme.muted)),
              ]),
            ),
            const SizedBox(width: 18),
            const Icon(Icons.mode_comment_outlined, size: 16, color: XyTheme.muted),
            const SizedBox(width: 5),
            Text('${post.balasan} balasan',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XyTheme.muted)),
            const Spacer(),
            const Text('Lihat',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: XyTheme.primary)),
            const Icon(Icons.chevron_right_rounded, size: 17, color: XyTheme.primary),
          ]),
        ]),
      ),
    );
  }
}

/// ---------------- detail diskusi ----------------
class ForumDetailScreen extends StatefulWidget {
  const ForumDetailScreen({super.key, required this.post});
  final ForumPost post;

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final _balas = TextEditingController();
  final _fokusBalas = FocusNode();
  ForumBalasan? sedangDibalas;
  List<ForumBalasan> balasan = [];
  bool memuat = true;
  bool mengirim = false;
  String? galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _balas.dispose();
    _fokusBalas.dispose();
    super.dispose();
  }

  /// Laporkan konten yang tidak pantas ke admin.
  Future<void> _lapor(BuildContext context, String jenis, String refId) async {
    final alasan = await pilihAlasanLaporan(context);
    if (alasan == null || !context.mounted) return;
    final galatLapor = await context.read<AppState>().laporkan(jenis: jenis, refId: refId, alasan: alasan);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(galatLapor ?? 'Terima kasih, laporanmu kami tinjau.')),
    );
  }

  Future<void> _muat() async {
    setState(() {
      memuat = true;
      galat = null;
    });
    context.read<AppState>().muatSukaBalasan();
    try {
      final d = await context.read<AppState>().detailForum(widget.post.id);
      if (mounted) setState(() => balasan = d);
    } catch (e) {
      if (mounted) setState(() => galat = 'Tidak bisa memuat balasan. Periksa koneksimu.');
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  Future<void> _kirim() async {
    final t = _balas.text.trim();
    if (t.length < 2) return;
    setState(() => mengirim = true);
    final pesan = await context
        .read<AppState>()
        .balasForum(widget.post.id, t, balasKe: sedangDibalas?.id);
    if (!mounted) return;
    setState(() => mengirim = false);
    if (pesan != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      return;
    }
    _balas.clear();
    setState(() => sedangDibalas = null);
    FocusScope.of(context).unfocus();
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.forum.firstWhere((f) => f.id == widget.post.id, orElse: () => widget.post);
    final disukai = s.forumDisukai.contains(p.id);
    final punyaSaya = p.userId == s.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diskusi'),
        actions: [
          if (!punyaSaya)
            IconButton(
              tooltip: 'Laporkan diskusi',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => _lapor(context, 'forum', p.id),
            ),
          if (punyaSaya)
            IconButton(
              tooltip: 'Sunting diskusi',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => bukaTulisDiskusi(context, postLama: p),
            ),
          if (punyaSaya)
            IconButton(
              tooltip: 'Hapus diskusi',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final yakin = await konfirmasi(
                  context,
                  judul: 'Hapus diskusi ini?',
                  pesan: 'Semua balasan ikut terhapus dan tidak bisa dikembalikan.',
                  tombolYa: 'Hapus',
                  ikon: Icons.delete_outline_rounded,
                  bahaya: true,
                );
                if (!yakin || !context.mounted) return;
                final pesan = await context.read<AppState>().hapusForum(p.id);
                if (!context.mounted) return;
                if (pesan == null) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
                }
              },
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            children: [
              XyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Avatar(nama: p.nama, foto: p.foto),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(p.nama,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          ),
                          LencanaTier(p.tier),
                          if (p.badge != null) LencanaKhusus(p.badge!),
                        ]),
                        Text(tanggal(p.dibuat),
                            style: const TextStyle(color: XyTheme.muted, fontSize: 11)),
                      ]),
                    ),
                    Pill(p.kategori, warna: XyTheme.violet),
                  ]),
                  const SizedBox(height: 14),
                  Text(p.judul,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.3, letterSpacing: -.4)),
                  const SizedBox(height: 10),
                  Text(p.isi, style: const TextStyle(fontSize: 14, height: 1.7, color: XyTheme.inkSoft)),
                  if (p.gambar != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(XyRadius.md),
                      child: Image.network(p.gambar!,
                          width: double.infinity, fit: BoxFit.cover, cacheWidth: 1200),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Pressable(
                      onTap: () => s.sukaForum(p.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: disukai ? XyTheme.danger.withOpacity(.08) : XyTheme.lineSoft,
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(disukai ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16, color: disukai ? XyTheme.danger : XyTheme.muted),
                          const SizedBox(width: 6),
                          Text('${p.suka} suka',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: disukai ? XyTheme.danger : XyTheme.muted)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${p.balasan} balasan',
                        style: const TextStyle(fontSize: 12, color: XyTheme.muted, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),

              const SectionHeader('Balasan'),

              if (memuat)
                const Center(child: Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator()))
              else if (galat != null)
                GagalMuat(pesan: galat!, ilustrasi: 'offline', rapat: true, onCoba: _muat)
              else if (balasan.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('Belum ada balasan. Bantu jawab, yuk.',
                        style: TextStyle(color: XyTheme.muted, fontSize: 13)),
                  ),
                )
              else
                ...balasan.map((b) {
                  ForumBalasan? induk;
                  if (b.balasKe != null) {
                    for (final x in balasan) {
                      if (x.id == b.balasKe) {
                        induk = x;
                        break;
                      }
                    }
                  }
                  final milikku = b.userId == s.user?.id;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 10, left: induk != null ? 22 : 0),
                    child: XyCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _Avatar(nama: b.nama, foto: b.foto, ukuran: 30, admin: b.admin),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(children: [
                              Flexible(
                                child: Text(b.nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.8)),
                              ),
                              LencanaTier(b.admin ? 'admin' : b.tier),
                              if (b.badge != null) LencanaKhusus(b.badge!),
                            ]),
                          ),
                          Text(tanggal(b.dibuat),
                              style: const TextStyle(color: XyTheme.muted, fontSize: 10.5)),
                        ]),
                        if (induk != null) ...[
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                            decoration: BoxDecoration(
                              color: XyTheme.lineSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: const Border(left: BorderSide(color: XyTheme.primary, width: 2.5)),
                            ),
                            child: Text(
                              'Membalas ${induk.nama}: ${induk.isi}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: XyTheme.muted, height: 1.4),
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Text(b.isi, style: const TextStyle(fontSize: 13.2, height: 1.6)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Pressable(
                            onTap: () async {
                              final baru = await context.read<AppState>().sukaBalasan(b.id);
                              if (baru != null && mounted) setState(() => b.suka = baru);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(
                                  s.balasanDisukai.contains(b.id)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: s.balasanDisukai.contains(b.id) ? XyTheme.danger : XyTheme.muted,
                                ),
                                const SizedBox(width: 5),
                                Text('${b.suka}',
                                    style: TextStyle(
                                        fontSize: 11.8,
                                        fontWeight: FontWeight.w700,
                                        color: s.balasanDisukai.contains(b.id) ? XyTheme.danger : XyTheme.muted)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Pressable(
                            onTap: () {
                              setState(() => sedangDibalas = b);
                              _fokusBalas.requestFocus();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                              child: Text('Balas',
                                  style: TextStyle(
                                      fontSize: 11.8, fontWeight: FontWeight.w800, color: XyTheme.primary)),
                            ),
                          ),
                          if (!milikku) ...[
                            const SizedBox(width: 16),
                            Pressable(
                              onTap: () => _lapor(context, 'balasan', b.id),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                                child: Text('Laporkan',
                                    style: TextStyle(
                                        fontSize: 11.8, fontWeight: FontWeight.w700, color: XyTheme.muted)),
                              ),
                            ),
                          ],
                          if (milikku) ...[
                            const SizedBox(width: 16),
                            Pressable(
                              onTap: () async {
                                final yakin = await konfirmasi(
                                  context,
                                  judul: 'Hapus balasan?',
                                  pesan: 'Balasan ini akan hilang dari diskusi.',
                                  tombolYa: 'Hapus',
                                  ikon: Icons.delete_outline_rounded,
                                  bahaya: true,
                                );
                                if (!yakin || !context.mounted) return;
                                final pesan = await context
                                    .read<AppState>()
                                    .hapusBalasanForum(b.id, widget.post.id);
                                if (pesan == null) {
                                  await _muat();
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(pesan)));
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                                child: Text('Hapus',
                                    style: TextStyle(
                                        fontSize: 11.8, fontWeight: FontWeight.w800, color: XyTheme.danger)),
                              ),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  );
                }),
            ],
          ),
        ),

        // ---- kolom balas ----
        Container(
          padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(color: XyTheme.surface, boxShadow: XyTheme.shadowMd),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sedangDibalas != null)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                decoration: BoxDecoration(
                  color: XyTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.reply_rounded, size: 15, color: XyTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Membalas ${sedangDibalas!.nama}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: XyTheme.primary)),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.close_rounded, size: 16, color: XyTheme.primary),
                    onPressed: () => setState(() => sedangDibalas = null),
                  ),
                ]),
              ),
            Row(children: [
            Expanded(
              child: TextField(
                controller: _balas,
                focusNode: _fokusBalas,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tulis balasan...',
                  fillColor: XyTheme.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Material(
              color: XyTheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: mengirim ? null : _kirim,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: mengirim
                      ? const SizedBox(
                          width: 19, height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                ),
              ),
            ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// ---------------- tulis diskusi ----------------
Future<void> bukaTulisDiskusi(BuildContext context, {ForumPost? postLama}) =>
    Navigator.push(context, xyRouteBawah(_FormTulis(postLama: postLama)));

class _FormTulis extends StatefulWidget {
  const _FormTulis({this.postLama});
  final ForumPost? postLama;

  @override
  State<_FormTulis> createState() => _FormTulisState();
}

class _FormTulisState extends State<_FormTulis> {
  late final _judul = TextEditingController(text: widget.postLama?.judul ?? '');
  late final _isi = TextEditingController(text: widget.postLama?.isi ?? '');
  late String kategori = widget.postLama?.kategori ?? 'Umum';
  String? gambar;
  bool proses = false;

  bool get sunting => widget.postLama != null;

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _pilihGambar() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 78);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final tipe = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() => gambar = 'data:image/$tipe;base64,${base64Encode(bytes)}');
  }

  Future<void> _kirim() async {
    setState(() => proses = true);
    final s = context.read<AppState>();
    final pesan = sunting
        ? await s.suntingForum(
            id: widget.postLama!.id,
            judul: _judul.text.trim(),
            isi: _isi.text.trim(),
            kategori: kategori,
          )
        : await s.buatForum(
            judul: _judul.text.trim(),
            isi: _isi.text.trim(),
            kategori: kategori,
            gambar: gambar,
          );
    if (!mounted) return;
    setState(() => proses = false);
    if (pesan != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sunting ? 'Diskusi diperbarui.' : 'Diskusi kamu sudah tayang.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pilihan = ['Umum', 'Tanya Jawab', 'Tips', 'Jual Beli', 'Keluhan'];

    return Scaffold(
      appBar: AppBar(title: Text(sunting ? 'Sunting Diskusi' : 'Tulis Diskusi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pilihan.map((k) {
              final on = k == kategori;
              return Pressable(
                onTap: () => setState(() => kategori = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? XyTheme.primary : XyTheme.surface,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(color: on ? XyTheme.primary : XyTheme.line),
                  ),
                  child: Text(k,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : XyTheme.inkSoft)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Judul', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 9),
          TextField(
            controller: _judul,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Tulis judul yang jelas, minimal 5 karakter'),
          ),
          const SizedBox(height: 18),
          const Text('Isi diskusi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 9),
          TextField(
            controller: _isi,
            maxLines: 9,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ceritakan detailnya di sini. Semakin jelas, semakin mudah dibantu.',
              alignLabelWithHint: true,
            ),
          ),
          if (!sunting) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pilihGambar,
              icon: Icon(gambar == null ? Icons.image_outlined : Icons.check_rounded, size: 18),
              label: Text(gambar == null ? 'Tambah Gambar (opsional)' : 'Gambar siap dikirim'),
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(
            label: sunting ? 'Simpan Perubahan' : 'Kirim Diskusi',
            icon: sunting ? Icons.check_rounded : Icons.send_rounded,
            loading: proses,
            onPressed: proses ? null : _kirim,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Hormati sesama pengguna. Diskusi yang melanggar akan dihapus admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: XyTheme.muted, fontSize: 11.8, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nama, this.foto, this.ukuran = 38, this.admin = false});
  final String nama;
  final String? foto;
  final double ukuran;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    if ((foto ?? '').isNotEmpty) {
      return CircleAvatar(radius: ukuran / 2, backgroundImage: NetworkImage(foto!));
    }
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        gradient: admin ? XyTheme.gradDeep : XyTheme.gradPrimary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: admin
            ? Icon(Icons.verified_user_rounded, size: ukuran * .5, color: Colors.white)
            : Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ukuran * .42)),
      ),
    );
  }
}
