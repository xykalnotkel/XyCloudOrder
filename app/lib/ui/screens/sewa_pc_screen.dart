import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'checkout_sewa_screen.dart';

class SewaPcScreen extends StatefulWidget {
  const SewaPcScreen({super.key, this.fokusId});
  final String? fokusId;
  @override
  State<SewaPcScreen> createState() => _SewaPcScreenState();
}

class _SewaPcScreenState extends State<SewaPcScreen> {
  String filter = 'Semua';
  final filters = const ['Semua', 'Jakarta', 'Singapore', 'Ready'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = s.plans;
    if (filter == 'Ready') list = list.where((p) => p.ready).toList();
    if (filter == 'Jakarta' || filter == 'Singapore') list = list.where((p) => p.region == filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sewa PC Cloud', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.4)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: LiveDot(state: s.koneksi)))],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final aktif = f == filter;
                  return ChoiceChip(
                    label: Text(f),
                    selected: aktif,
                    onSelected: (_) => setState(() => filter = f),
                    selectedColor: XyTheme.primary,
                    labelStyle: TextStyle(
                      color: aktif ? Colors.white : XyTheme.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: XyTheme.cyan.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.bolt_rounded, color: XyTheme.cyan, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Stok unit diperbarui otomatis setiap detik dari server XyCloud.',
                      style: TextStyle(fontSize: 12, color: XyTheme.ink)),
                ),
              ]),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Kosong(icon: Icons.search_off_rounded, judul: 'Tidak ada PC di filter ini'),
              ),
            ...list.map((p) => Padding(padding: const EdgeInsets.only(top: 12), child: _KartuPlan(plan: p))),
          ],
        ),
      ),
    );
  }
}

class _KartuPlan extends StatelessWidget {
  const _KartuPlan({required this.plan});
  final PcPlan plan;

  @override
  Widget build(BuildContext context) {
    final pakai = plan.totalUnit == 0 ? 0.0 : 1 - (plan.unitTersedia / plan.totalUnit);
    return XyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GradientThumb(seed: plan.id, icon: Icons.memory_rounded, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -.3)),
                const SizedBox(width: 8),
                if (plan.tag.isNotEmpty) Pill(plan.tag, warna: XyTheme.violet),
              ]),
              const SizedBox(height: 3),
              Text(plan.gpu, style: const TextStyle(color: XyTheme.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 8, children: [
          SpecChip(Icons.developer_board_rounded, plan.cpu),
          SpecChip(Icons.memory_outlined, 'RAM ${plan.ramGb}GB'),
          SpecChip(Icons.sd_storage_outlined, 'SSD ${plan.storageGb}GB'),
          SpecChip(Icons.location_on_outlined, plan.region),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pakai),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: XyTheme.line,
                  color: plan.ready ? XyTheme.success : XyTheme.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${plan.unitTersedia}/${plan.totalUnit} unit',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: XyTheme.muted)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rupiah(plan.hargaPerJam),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: XyTheme.primary, letterSpacing: -.5)),
              const Text('  /jam', style: TextStyle(color: XyTheme.muted, fontSize: 12)),
            ]),
            Text('atau ${rupiah(plan.hargaPerHari)} /hari', style: const TextStyle(color: XyTheme.muted, fontSize: 11.5)),
          ]),
          const Spacer(),
          SizedBox(
            width: 138,
            child: GradientButton(
              label: plan.ready ? 'Sewa' : 'Penuh',
              icon: plan.ready ? Icons.bolt_rounded : Icons.block_rounded,
              height: 46,
              onPressed: plan.ready
                  ? () => Navigator.push(context, xyRoute(CheckoutSewaScreen(plan: plan)))
                  : null,
            ),
          ),
        ]),
      ]),
    );
  }
}
