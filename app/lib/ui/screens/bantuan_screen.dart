import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class BantuanScreen extends StatelessWidget {
  const BantuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faq = [
      {'q': 'Bagaimana cara sewa PC?', 'a': 'Pilih paket di menu Sewa PC → pilih durasi → pilih metode bayar (saldo / transfer) → bayar → tunggu provisioning → data RDP akan muncul di Pesanan Saya.'},
      {'q': 'PC saya tidak bisa konek?', 'a': 'Cek di Status Unit Live apakah unit online. Pastikan internet stabil. Jika masih gagal, hubungi CS via chat realtime di aplikasi.'},
      {'q': 'Voucher tidak bisa dipakai?', 'a': 'Cek minimal belanja & masa berlaku. Voucher hanya bisa dipakai sekali per user & tidak bisa digabung.'},
      {'q': 'Bagaimana top up saldo?', 'a': 'Masuk Dompet → Top Up → pilih nominal & metode → transfer sesuai instruksi → upload bukti → tunggu admin verifikasi (max 15 menit).'},
      {'q': 'Update aplikasi tidak muncul?', 'a': 'Buka Tentang Aplikasi → Cek Pembaruan. Jika ada versi baru, popup violet-indigo akan muncul. Pastikan izin pasang aplikasi dari sumber tidak dikenal aktif.'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Pusat Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF100030), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Butuh bantuan cepat?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                SizedBox(height: 4),
                Text('Chat CS realtime 24/7 atau WA admin.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _ActionBtn(icon: Icons.chat_bubble_rounded, label: 'Chat CS', onTap: () => Navigator.pop(context))),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(icon: Icons.call_rounded, label: 'WA Admin', onTap: () async {
              final uri = Uri.parse('https://wa.me/6281234567890?text=Halo%20admin%20XyCloud');
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            })),
          ]),
          const SectionHeader('FAQ'),
          ...faq.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: XyCard(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(f['a']!, style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6)))],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Video Tutorial', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Segera hadir: cara sewa PC, cara pakai RDP, cara beli akun.', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: XyTheme.of(context).line)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: XyTheme.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))]),
        ),
      );
}
