import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import '../widgets/common.dart';
import 'profil_publik_screen.dart';

/// ============================================================
///  Leaderboard NYATA (Batch I) — peringkat dari data transaksi
///  server, bukan mock. Dua periode: belanja bulan ini & total.
/// ============================================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _periode = 'bulan';
  DataLeaderboard? _data;
  String? _galat;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat({String? periode}) async {
    if (periode != null) {
      setState(() {
        _periode = periode;
        _memuat = true;
      });
    }
    try {
      final d =
          await context.read<AppState>().repo.leaderboard(periode: _periode);
      if (!mounted) return;
      setState(() {
        _data = d;
        _galat = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galat = 'Leaderboard gagal dimuat. Periksa koneksi kamu.';
        _memuat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final d = _data;
    final papan = d?.papan ?? const <PapanPeringkat>[];
    final podium = papan.take(3).toList();
    final sisa = papan.skip(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: RefreshIndicator(
        onRefresh: () => _muat(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            // Hero — gradasi midnight aurora.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [XyTheme.bgGelap2, XyTheme.primaryDark, XyTheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(XyRadius.lg),
                boxShadow: XyTheme.glow(XyTheme.primary, .22),
              ),
              child: Column(children: [
                const Icon(Icons.emoji_events_rounded,
                    color: XyTheme.goldSoft, size: 42),
                const SizedBox(height: 10),
                Text(
                  _periode == 'bulan'
                      ? 'Top Spender Bulan Ini'
                      : 'Top Spender Sepanjang Masa',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  _periode == 'bulan'
                      ? 'Periode ${_labelBulan()} — dihitung dari transaksi lunas bulan ini. Transfer saldo tidak dihitung.'
                      : 'Akumulasi seluruh transaksi lunas sepanjang akun aktif. Transfer saldo tidak dihitung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(.72), fontSize: 11.8, height: 1.5),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Segmen periode.
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.lineSoft,
                borderRadius: BorderRadius.circular(XyRadius.pill),
                border: Border.all(color: t.line),
              ),
              child: Row(children: [
                for (final p in const [
                  ('bulan', 'Bulan Ini'),
                  ('total', 'Sepanjang Masa'),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: _periode == p.$1 ? null : () => _muat(periode: p.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: _periode == p.$1 ? XyTheme.gradPrimary : null,
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _periode == p.$1
                                ? Colors.white
                                : t.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(
              'Sumber: riwayat transaksi lunas (top 50) · urutan menurun · akun diblokir tidak tampil',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted.withOpacity(.85), fontSize: 10.5),
            ),

            if (_memuat && d == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_galat != null)
              Kosong(
                icon: Icons.leaderboard_rounded,
                judul: 'Waduh',
                sub: _galat,
                ilustrasi: '',
                aksi: GradientButton(
                    label: 'Coba Lagi', onPressed: () => _muat()),
              )
            else if (papan.isEmpty)
              Kosong(
                icon: Icons.emoji_events_outlined,
                judul: _periode == 'bulan'
                    ? 'Belum ada belanja bulan ini'
                    : 'Belum ada yang masuk papan',
                sub:
                    'Jadilah yang pertama! Sewa PC atau beli akun untuk naik peringkat.',
                ilustrasi: 'kosong',
              )
            else ...[
              // ---------- podium 3 besar ----------
              if (podium.length >= 3) ...[
                const SectionHeader('Podium'),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: _Podium(entry: podium[1], tinggi: 118, warna: const Color(0xFFB7C1D1), medali: '2')),
                  const SizedBox(width: 10),
                  Expanded(child: _Podium(entry: podium[0], tinggi: 148, warna: XyTheme.goldSoft, medali: '1')),
                  const SizedBox(width: 10),
                  Expanded(child: _Podium(entry: podium[2], tinggi: 100, warna: XyTheme.bronze, medali: '3')),
                ]),
                const SizedBox(height: 8),
              ],
              // ---------- daftar ----------
              SectionHeader(podium.length >= 3 ? 'Peringkat Lainnya' : 'Peringkat'),
              ...sisa.asMap().entries.map((e) {
                final x = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: XyCard(
                    padding: const EdgeInsets.all(13),
                    onTap: () => Navigator.push(context,
                        xyRoute(ProfilPublikScreen(userId: x.id))),
                    child: Row(children: [
                      SizedBox(
                        width: 30,
                        child: Text('${x.peringkat}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: x.saya ? t.accent : t.muted)),
                      ),
                      const SizedBox(width: 8),
                      AvatarBingkai(
                        bingkai: x.bingkai,
                        size: 40,
                        child: _AvatarPapan(x),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: GayaNama(x.nama,
                                      gaya: x.gayaNama,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: x.saya ? t.accent : t.ink)),
                                ),
                                if (x.saya) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: XyTheme.violet.withOpacity(.16),
                                      borderRadius:
                                          BorderRadius.circular(XyRadius.pill),
                                    ),
                                    child: const Text('KAMU',
                                        style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: XyTheme.violet,
                                            letterSpacing: .6)),
                                  ),
                                ],
                                if (x.tier == 'vip' || x.tier == 'pro') ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                      x.tier == 'vip'
                                          ? Icons.diamond_rounded
                                          : Icons.workspace_premium_rounded,
                                      size: 12,
                                      color: x.tier == 'vip'
                                          ? XyTheme.goldSoft
                                          : XyTheme.violet),
                                ],
                              ]),
                              if ((x.username ?? '').isNotEmpty)
                                Text('@${x.username}',
                                    style: TextStyle(
                                        fontSize: 11, color: t.muted)),
                              // Batch L: slogan singkat pemilik peringkat.
                              if ((x.slogan ?? '').isNotEmpty)
                                Text('“${x.slogan}”',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontStyle: FontStyle.italic,
                                        color: t.muted.withOpacity(.9))),
                            ]),
                      ),
                      Text(rupiah(x.poin),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: x.saya ? t.accent : t.ink)),
                    ]),
                  ),
                );
              }),
              // Podium 1–3 tetap bisa diketuk lewat kartu ringkas di atas podium.
              if (podium.length >= 1 && sisa.isEmpty)
                Text('Hanya ${papan.length} pengguna dengan transaksi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.muted, fontSize: 11.5)),
            ],

            const SizedBox(height: 10),
            XyCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cara Naik Peringkat',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      '• Belanja sewa PC & akun digital dihitung sebagai poin (1 poin = Rp1)\n'
                      '• Peringkat "Bulan Ini" direset tiap awal bulan\n'
                      '• Transfer saldo antar pengguna TIDAK dihitung\n'
                      '• Akun yang diblokir otomatis keluar dari papan',
                      style: TextStyle(color: t.muted, fontSize: 12.3, height: 1.65),
                    ),
                  ]),
            ),
          ],
        ),
      ),
      // ---------- kartu peringkatku ----------
      bottomNavigationBar: d == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: t.surfaceHigh,
                    borderRadius: BorderRadius.circular(XyRadius.lg),
                    border: Border.all(color: XyTheme.violet.withOpacity(.35)),
                    boxShadow: XyTheme.glow(XyTheme.primary, .12),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: XyTheme.gradPrimary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        d.peringkatSaya == null ? '–' : '${d.peringkatSaya}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Peringkatku',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                            Text(
                              d.peringkatSaya == null
                                  ? 'Belanja dulu untuk masuk papan'
                                  : (_periode == 'bulan'
                                      ? 'Belanja bulan ini'
                                      : 'Total belanja'),
                              style: TextStyle(fontSize: 11, color: t.muted),
                            ),
                          ]),
                    ),
                    Text(rupiah(d.poinSaya),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: t.accent)),
                  ]),
                ),
              ),
            ),
    );
  }
}

/// Contoh: "1–30 September 2026" (bulan berjalan, zona waktu server = UTC).
String _labelBulan() {
  final n = DateTime.now().toUtc();
  final akhir = DateTime(n.year, n.month + 1, 0).day;
  const nama = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  return '1–$akhir ${nama[n.month - 1]} ${n.year}';
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.entry,
    required this.tinggi,
    required this.warna,
    required this.medali,
  });
  final PapanPeringkat entry;
  final double tinggi;
  final Color warna;
  final String medali;

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Pressable(
      onTap: () => Navigator.push(
          context, xyRoute(ProfilPublikScreen(userId: entry.id))),
      child: Column(children: [
        // Batch L: mahkota kecil melayang di atas juara 1.
        if (medali == '1')
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(Icons.emoji_events_rounded,
                size: 20, color: XyTheme.goldSoft),
          ),
        AvatarBingkai(
          bingkai: entry.bingkai,
          size: medali == '1' ? 62 : 52,
          child: _AvatarPapan(entry),
        ),
        const SizedBox(height: 8),
        Center(
          child: GayaNama(entry.nama,
              gaya: entry.gayaNama,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        Text(rupiah(entry.poin),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: t.muted)),
        const SizedBox(height: 8),
        Container(
          height: tinggi,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            gradient: LinearGradient(
              colors: [warna, warna.withOpacity(.55)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Column(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.28),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(medali,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AvatarPapan extends StatelessWidget {
  const _AvatarPapan(this.x);
  final PapanPeringkat x;

  @override
  Widget build(BuildContext context) {
    if ((x.foto ?? '').isNotEmpty) return AppImage(x.foto!);
    return Container(
      color: XyTheme.of(context).primarySoft,
      alignment: Alignment.center,
      child: Text(
        x.nama.isEmpty ? '?' : x.nama[0].toUpperCase(),
        style: TextStyle(
            fontWeight: FontWeight.w800, color: XyTheme.of(context).accent),
      ),
    );
  }
}
