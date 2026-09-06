import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Live chat CS — pesan masuk lewat WebSocket (atau simulasi di mode mock).
class CsScreen extends StatefulWidget {
  const CsScreen({super.key});
  @override
  State<CsScreen> createState() => _CsScreenState();
}

class _CsScreenState extends State<CsScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();

  static const cepat = [
    'PC saya lag, bagaimana?',
    'Cara top up saldo?',
    'Garansi akun berapa lama?',
    'Minta refund order saya',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _keBawah());
  }

  void _keBawah() {
    if (!scroll.hasClients) return;
    scroll.animateTo(scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _kirim([String? teks]) async {
    final t = (teks ?? ctrl.text).trim();
    if (t.isEmpty) return;
    ctrl.clear();
    await context.read<AppState>().kirimChat(t);
    if (mounted) _keBawah();
  }

  @override
  void dispose() {
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _keBawah());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          Stack(children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: XyTheme.primary,
              child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: XyTheme.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: XyTheme.bg, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CS XyCloud', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            Text(s.csMengetik ? 'sedang mengetik...' : 'Online · balas < 1 menit',
                style: TextStyle(
                    fontSize: 11.5,
                    color: s.csMengetik ? XyTheme.primary : XyTheme.success,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: s.chat.length + (s.csMengetik ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == s.chat.length) return const _Mengetik();
              return _Gelembung(msg: s.chat[i]);
            },
          ),
        ),
        if (s.chat.length < 4)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cepat.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(cepat[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _kirim(cepat[i]),
                backgroundColor: XyTheme.surface,
                side: const BorderSide(color: XyTheme.line),
              ),
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(color: XyTheme.surface, boxShadow: XyTheme.shadowMd),
          child: Row(children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.attach_file_rounded, color: XyTheme.muted),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _kirim(),
                onChanged: (v) => context.read<AppState>().ketikCs(v.isNotEmpty),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  fillColor: XyTheme.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: XyTheme.primary, width: 1.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: XyTheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _kirim(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Gelembung extends StatelessWidget {
  const _Gelembung({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    if (msg.dari == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: XyTheme.line.withOpacity(.6), borderRadius: BorderRadius.circular(20)),
          child: Text(msg.teks, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: XyTheme.muted)),
        ),
      );
    }
    final saya = msg.milikSaya;
    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: saya ? XyTheme.primary : XyTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(saya ? 18 : 4),
            bottomRight: Radius.circular(saya ? 4 : 18),
          ),
          border: saya ? null : Border.all(color: XyTheme.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(msg.teks,
              style: TextStyle(color: saya ? Colors.white : XyTheme.ink, fontSize: 13.8, height: 1.42)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(jam(msg.waktu),
                style: TextStyle(fontSize: 10, color: saya ? Colors.white70 : XyTheme.muted)),
            if (saya) ...[
              const SizedBox(width: 4),
              Icon(msg.terkirim ? Icons.done_all_rounded : Icons.schedule_rounded,
                  size: 12, color: Colors.white70),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _Mengetik extends StatefulWidget {
  const _Mengetik();
  @override
  State<_Mengetik> createState() => _MengetikState();
}

class _MengetikState extends State<_Mengetik> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: XyTheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: XyTheme.line),
        ),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((c.value + i * .22) % 1);
              final naik = (t < .5 ? t : 1 - t) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                transform: Matrix4.translationValues(0, -naik * 4, 0),
                decoration: BoxDecoration(
                  color: XyTheme.muted.withOpacity(.4 + naik * .5),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
