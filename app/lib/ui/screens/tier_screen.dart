import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class TierScreen extends StatelessWidget {
  const TierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiers = [
      {
        'nama': 'Bronze',
        'min': 'Rp 0',
        'benefit': ['Akses semua PC', 'Support standar', '1 device'],
        'color': XyTheme.bronze,
        'icon': Icons.military_tech_outlined,
      },
      {
        'nama': 'Silver',
        'min': 'Rp 500.000',
        'benefit': ['Cashback 2%', 'Prioritas antrian', '2 device', 'Voucher bulanan'],
        'color': XyTheme.graySoft,
        'icon': Icons.workspace_premium_outlined,
      },
      {
        'nama': 'Gold',
        'min': 'Rp 2.000.000',
        'benefit': ['Cashback 5%', 'Support prioritas 1 jam', '3 device', 'Akses unit premium', 'Badge Gold di forum'],
        'color': XyTheme.goldSoft,
        'icon': Icons.emoji_events_outlined,
      },
      {
        'nama': 'Platinum',
        'min': 'Rp 5.000.000',
        'benefit': ['Cashback 8%', 'Unit prioritas & reserved', '5 device', 'Voucher eksklusif', 'Undangan beta fitur', 'Badge Platinum + glow'],
        'color': XyTheme.plum,
        'icon': Icons.diamond_outlined,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tier & Benefit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [XyTheme.bgGelap, XyTheme.bgGelap2, XyTheme.primary, XyTheme.plum],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: XyTheme.glow(XyTheme.primary, .25),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Naik Tier, Makin Hemat',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Belanja akumulasi otomatis hitung tier. Benefit aktif langsung.',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Tier dihitung dari total belanja lunas (sewa + akun) tanpa batas waktu.',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Level Tier'),
          ...tiers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: XyCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (t['color'] as Color).withOpacity(.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (t['color'] as Color).withOpacity(.25)),
                        ),
                        child: Icon(t['icon'] as IconData, color: t['color'] as Color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t['nama'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text('Minimal ${t['min']}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [t['color'] as Color, (t['color'] as Color).withOpacity(.7)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t['nama'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    ...((t['benefit'] as List<String>).map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: t['color'] as Color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(b, style: TextStyle(color: XyTheme.of(context).inkSoft.withOpacity(.85), fontSize: 12.5))),
                          ]),
                        ))),
                  ]),
                ),
              )),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cara Naik Tier Cepat', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                '• Sewa paket mingguan/bulanan (nilai besar langsung ke tier)\n• Beli akun premium\n• Pakai referral — teman belanja juga hitung 10% ke tier kamu\n• Kumpulkan poin & tukarkan voucher untuk tetap hemat saat push tier',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
