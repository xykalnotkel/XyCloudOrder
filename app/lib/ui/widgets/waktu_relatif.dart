import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/waktu.dart';
import '../../core/format.dart';

class WaktuRelatif extends StatefulWidget {
  const WaktuRelatif(this.waktu, {super.key});
  final DateTime waktu;
  @override
  State<WaktuRelatif> createState() => _WaktuRelatifState();
}

class _WaktuRelatifState extends State<WaktuRelatif> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _jadwal();
  }

  void _jadwal() {
    _timer?.cancel();
    final seconds = DateTime.now().difference(widget.waktu).inSeconds;
    _timer = Timer(Duration(seconds: seconds < 60 ? 1 : 60), () {
      if (mounted) {
        setState(() {});
        _jadwal();
      }
    });
  }

  @override
  void didUpdateWidget(covariant WaktuRelatif old) {
    super.didUpdateWidget(old);
    if (old.waktu != widget.waktu) _jadwal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tanggal(widget.waktu.toLocal()),
      child: Text(waktuRelatif(widget.waktu),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 10.5, color: XyTheme.of(context).muted)));
}
