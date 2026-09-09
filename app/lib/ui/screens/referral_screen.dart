import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/error_state.dart';

/// ============================================================
///  Undang teman: kode referral, bonus, dan daftar undangan
/// ============================================================
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? data;
  String? galat;
  final _kode = TextEditingController();
  bool proses = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => galat = null);
    try {
      final d = await context.read<AppState>().dataReferral();
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) setState(() => galat = 'Belum bisa memuat data undangan.');
    }
  }

  Future<void> _pakaiKode() async {
    final kode = _kode.text.trim().toUpperCase();
    if (kode.length < 4) {
      setState(() => galat = 'Kode referral terlalu pendek');
      return;
    }
    setState(() {
      proses = true;
      galat = null;
    });

    final s = context.read<AppState>();
    final hasil = await s.pakaiReferral(kode);
    if (!mounted) return;
    setState(() => proses = false);

    if (hasil == null) {
      setState(() => galat = s.error ?? 'Kode tidak bisa dipakai');
      return;
    }
    _kode.clear();
    await _muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bonus ${rupiah(hasil['bonus'] ?? 0)} masuk ke saldomu.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sudahDiundang = (s.user?.diundangOleh ?? '').isNotEmpty;
    final daftar = (data?['daftar'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Undang Teman')),
      body: data == null && galat != null
          ? GagalMuat(pesan: galat!, ilustrasi: 'offline', onCoba: _muat)
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  children: [
                    // ---- kartu kode ----
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: XyTheme.gradDeep,
                        borderRadius: BorderRadius.circular(XyRadius.xl),
                        boxShadow: XyTheme.glow(XyTheme.primary, .24),
                      ),
                      child: Column(children: [
                        Text('Kode referralmu',
                            style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 12.5)),
                        const SizedBox(height: 10),
                        Text(
                          '${data!['kode'] ?? '-'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: '${data!['kode']}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kode disalin'), duration: Duration(seconds: 1)),
                                );
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(XyRadius.pill),
                                ),
                                child: const Center(
                                  child: Text('Salin Kode',
                                      style: TextStyle(
                                          color: XyTheme.primaryDeep,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                Clipboard.setData(ClipboardData(
                                  text: 'Pakai kode ${data!['kode']} di XyCloudStore, kamu langsung dapat '
                                      'bonus saldo. Unduh aplikasinya di ${data!['tautan']}',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ajakan disalin, tinggal tempel ke chat')),
                                );
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.14),
                                  borderRadius: BorderRadius.circular(XyRadius.pill),
                                  border: Border.all(color: Colors.white.withOpacity(.2)),
                                ),
                                child: const Center(
                                  child: Text('Salin Ajakan',
                                      style: TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 18),
                    XyCard(
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['bonusPengundang'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 18, color: XyTheme.primary)),
                              const SizedBox(height: 3),
                               Text('Bonus untukmu',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                          Container(width: 1, height: 36, color: XyTheme.of(context).line),
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['bonusDiundang'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 18, color: XyTheme.success)),
                              const SizedBox(height: 3),
                               Text('Bonus temanmu',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                          Container(width: 1, height: 36, color: XyTheme.of(context).line),
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['totalBonus'] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                              const SizedBox(height: 3),
                               Text('Total didapat',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),
                         Text(
                          'Bagikan kodemu. Begitu temanmu memakainya, kalian berdua langsung dapat saldo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.3, height: 1.55),
                        ),
                      ]),
                    ),

                    // ---- pakai kode orang lain ----
                    if (!sudahDiundang) ...[
                      const SectionHeader('Punya kode dari teman?'),
                      XyCard(
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _kode,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Masukkan kode',
                                  prefixIcon: Icon(Icons.card_giftcard_rounded),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 104,
                              child: GradientButton(
                                label: 'Pakai',
                                height: 48,
                                loading: proses,
                                onPressed: proses ? null : _pakaiKode,
                              ),
                            ),
                          ]),
                          if (galat != null) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: XyTheme.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(galat!,
                                    style: const TextStyle(
                                        color: XyTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ],
                        ]),
                      ),
                    ],

                    // ---- daftar undangan ----
                    SectionHeader('Teman yang bergabung', sub: '${daftar.length} orang'),
                    if (daftar.isEmpty)
                      const Kosong(
                        icon: Icons.group_add_outlined,
                        judul: 'Belum ada yang bergabung',
                        sub: 'Bagikan kodemu ke grup atau teman main.',
                        ilustrasi: 'forum',
                      )
                    else
                      ...daftar.map((r) {
                        final m = r as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: XyCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    const BoxDecoration(gradient: XyTheme.gradPrimary, shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    '${m['nama_diundang'] ?? 'X'}'.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${m['nama_diundang'] ?? 'Pengguna baru'}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 3),
                                  Text('${m['dibuat'] ?? ''}'.replaceFirst('T', ' ').split('.').first,
                                      style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                                ]),
                              ),
                              Text('+ ${rupiah(m['bonus_pengundang'] ?? 0)}',
                                  style: const TextStyle(
                                      color: XyTheme.success, fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
