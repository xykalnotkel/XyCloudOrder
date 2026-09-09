import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockTop = [
      {'nama': 'Rizky Pro', 'poin': 12450, 'badge': 'WHALE'},
      {'nama': 'Ayu Gamer', 'poin': 9800, 'badge': 'TOP'},
      {'nama': 'Budi', 'poin': 7200, 'badge': 'ACTIVE'},
      {'nama': 'Sinta', 'poin': 5400, 'badge': ''},
      {'nama': 'Joko', 'poin': 3200, 'badge': ''},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF100030), Color(0xFF200050), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFE8C07A), size: 42),
              const SizedBox(height: 10),
              const Text('Top Spender Bulan Ini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Belanja & undang teman untuk naik peringkat', style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 12)),
            ]),
          ),
          const SectionHeader('Peringkat'),
          ...mockTop.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: XyCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: i == 0 ? const Color(0xFFE8C07A) : XyTheme.of(context).primarySoft, shape: BoxShape.circle), child: Center(child: Text('${i+1}', style: TextStyle(fontWeight: FontWeight.w700, color: i==0? Colors.black: XyTheme.primary)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(m['nama'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if ((m['badge'] as String).isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: XyTheme.primary, borderRadius: BorderRadius.circular(6)), child: Text(m['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('${m['poin']} poin', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: XyTheme.muted),
                ]),
              ),
            );
          }),
          const SizedBox(height: 10),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cara dapat poin', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('• Sewa PC 1 jam = 10 poin\n• Beli akun = 20 poin\n• Undang teman = 50 poin\n• Ulasan produk = 5 poin\n\nPoin bisa ditukar voucher di menu Voucher Saya (segera).',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6)),
            ]),
          ),
        ],
      ),
    );
  }
}
