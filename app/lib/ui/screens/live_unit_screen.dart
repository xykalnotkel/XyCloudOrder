import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Status unit PC live — memakai katalog pc_plans (nama, region, spek, stok realtime).
/// Server Worker mengirim update stok via WebSocket room 'katalog' (event stock.update),
/// sehingga angka unit tersedia diperbarui otomatis oleh AppState.
class LiveUnitScreen extends StatelessWidget {
  const LiveUnitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<AppState>().plans;
    final siap = plans.where((p) => p.unitTersedia > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Status Unit Live')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [XyTheme.bgGelap, XyTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: XyTheme.okBright, shape: BoxShape.circle, boxShadow: [BoxShadow(color: XyTheme.okBright, blurRadius: 8)])),
              const SizedBox(width: 10),
              const Expanded(child: Text('Live — update realtime via WebSocket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
              Text('${plans.fold(0, (a, p) => a + p.unitTersedia)} unit ready', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 11.5)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('$siap dari ${plans.length} paket siap dipakai', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SectionHeader('Paket PC'),
          if (plans.isEmpty)
            const Kosong(icon: Icons.desktop_windows_rounded, judul: 'Belum ada data unit', sub: 'Tarik untuk refresh.', ilustrasi: 'pc')
          else
            ...plans.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: XyCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(gradient: XyTheme.gradPrimary, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.memory_rounded, color: Colors.white, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('${p.cpu} • ${p.gpu} • ${p.ramGb}GB RAM', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${p.unitTersedia}/${p.totalUnit}', style: const TextStyle(fontWeight: FontWeight.w700, color: XyTheme.primary)),
                          Text('ready', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 10)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: p.totalUnit == 0 ? 0 : p.unitTersedia / p.totalUnit, minHeight: 6, backgroundColor: XyTheme.of(context).line, valueColor: const AlwaysStoppedAnimation(XyTheme.primary)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        _Chip(p.region, Icons.location_on_rounded),
                        const SizedBox(width: 6),
                        _Chip(p.tag.isEmpty ? '${p.storageGb}GB' : p.tag, Icons.sell_rounded),
                        const SizedBox(width: 6),
                        _Chip(p.unitTersedia > 0 ? 'Online' : 'Penuh', Icons.circle, color: p.unitTersedia > 0 ? XyTheme.okBright : XyTheme.danger),
                      ]),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _Chip(this.label, this.icon, {this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color ?? XyTheme.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: XyTheme.of(context).muted)),
        ]),
      );
}
