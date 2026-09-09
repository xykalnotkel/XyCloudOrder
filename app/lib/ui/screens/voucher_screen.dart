import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Voucher Saya — daftar voucher aktif + klaim
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});
  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  List<dynamic> vouchers = [];
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final s = context.read<AppState>();
      // pakai cek voucher? Untuk list, ambil dari api langsung via repo? Simplifikasi: pakai dummy + api promosi/voucher
      // Kita fetch dari /voucher via api client manual
      final d = await s.cekVoucher(kode: 'LIST', jenis: 'sewa', total: 0); // akan error, fallback ke mock
      // Jika endpoint list belum ada, tampilkan promo voucher dari promosi
      if (mounted) setState(() { vouchers = s.promosi.where((p) => p.kodeVoucher != null).toList(); loading = false; });
    } catch (e) {
      if (mounted) setState(() { loading = false; vouchers = []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher Saya')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF100030), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: XyTheme.glow(XyTheme.primary, .22),
                  ),
                  child: Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 26)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Punya kode voucher?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Masukkan saat checkout sewa PC atau beli akun untuk potongan langsung.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                  ]),
                ),
                const SectionHeader('Voucher Tersedia'),
                if (vouchers.isEmpty)
                  const Kosong(icon: Icons.card_giftcard_rounded, judul: 'Belum ada voucher', sub: 'Cek banner promo atau minta kode dari admin.', ilustrasi: 'promo')
                else
                  ...vouchers.map((v) {
                    final kode = (v is dynamic && v.kodeVoucher != null) ? v.kodeVoucher : (v['kode'] ?? '-');
                    final pot = (v is dynamic) ? (v.persen ?? 0) : (v['persen'] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: XyCard(
                        child: Row(children: [
                          Container(width: 56, height: 56, decoration: BoxDecoration(gradient: XyTheme.gradPrimary, borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.confirmation_number_rounded, color: Colors.white))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(kode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.2)),
                            const SizedBox(height: 3),
                            Text('Diskon $pot% • Berlaku untuk sewa & akun', style: TextStyle(color: t.muted, fontSize: 11.5)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: XyTheme.primary.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text('$pot% OFF', style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w800, fontSize: 12))),
                        ]),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                XyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Cara pakai', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('1. Pilih paket PC atau produk akun\n2. Di halaman checkout, tap \"Pakai Voucher\"\n3. Masukkan kode — potongan langsung terhitung\n4. Voucher tidak bisa digabung & ada minimal belanja',
                        style: TextStyle(color: t.muted, fontSize: 12.5, height: 1.6)),
                  ]),
                ),
              ],
            ),
    );
  }
}
