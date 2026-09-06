import 'package:flutter/material.dart';

// ============================================================
//  Logo merek asli untuk tombol login sosial.
//  Digambar langsung di canvas (tanpa paket tambahan, tanpa aset),
//  memakai data path resmi masing-masing merek.
// ============================================================

/// Parser path SVG minimal: M m L l H h V v C c S s Q q T t Z z.
class SvgPathMini {
  static final RegExp _num = RegExp(r'[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?');

  static const Map<String, int> _arity = {
    'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Q': 4, 'T': 2, 'Z': 0,
  };

  static List<Object> _tokens(String d) {
    final out = <Object>[];
    var i = 0;
    while (i < d.length) {
      final c = d[i];
      if (RegExp(r'[A-Za-z]').hasMatch(c)) {
        out.add(c);
        i++;
      } else if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        i++;
      } else {
        final m = _num.matchAsPrefix(d, i);
        if (m == null) {
          i++;
          continue;
        }
        out.add(double.parse(m.group(0)!));
        i = m.end;
      }
    }
    return out;
  }

  static Path parse(String d) {
    final t = _tokens(d);
    final path = Path();
    var i = 0;
    String? cmd;
    var cx = 0.0, cy = 0.0; // titik saat ini
    var sx = 0.0, sy = 0.0; // titik awal subpath
    var lcx = 0.0, lcy = 0.0; // kontrol terakhir (untuk S/T)

    while (i < t.length) {
      final tok = t[i];
      if (tok is String) {
        cmd = tok;
        i++;
      } else if (cmd == null) {
        break;
      } else {
        if (cmd == 'M') cmd = 'L';
        if (cmd == 'm') cmd = 'l';
      }
      if (cmd == null) break;

      final rel = cmd.toLowerCase() == cmd;
      final key = cmd.toUpperCase();
      final n = _arity[key] ?? 0;
      if (i + n > t.length) break;

      final a = <double>[];
      for (var k = 0; k < n; k++) {
        final v = t[i + k];
        a.add(v is double ? v : 0);
      }
      i += n;

      switch (key) {
        case 'M':
          cx = rel ? cx + a[0] : a[0];
          cy = rel ? cy + a[1] : a[1];
          sx = cx;
          sy = cy;
          path.moveTo(cx, cy);
          break;
        case 'L':
          cx = rel ? cx + a[0] : a[0];
          cy = rel ? cy + a[1] : a[1];
          path.lineTo(cx, cy);
          break;
        case 'H':
          cx = rel ? cx + a[0] : a[0];
          path.lineTo(cx, cy);
          break;
        case 'V':
          cy = rel ? cy + a[0] : a[0];
          path.lineTo(cx, cy);
          break;
        case 'C':
          final x1 = rel ? cx + a[0] : a[0];
          final y1 = rel ? cy + a[1] : a[1];
          final x2 = rel ? cx + a[2] : a[2];
          final y2 = rel ? cy + a[3] : a[3];
          final x = rel ? cx + a[4] : a[4];
          final y = rel ? cy + a[5] : a[5];
          path.cubicTo(x1, y1, x2, y2, x, y);
          lcx = x2;
          lcy = y2;
          cx = x;
          cy = y;
          break;
        case 'S':
          final x1 = 2 * cx - lcx;
          final y1 = 2 * cy - lcy;
          final x2 = rel ? cx + a[0] : a[0];
          final y2 = rel ? cy + a[1] : a[1];
          final x = rel ? cx + a[2] : a[2];
          final y = rel ? cy + a[3] : a[3];
          path.cubicTo(x1, y1, x2, y2, x, y);
          lcx = x2;
          lcy = y2;
          cx = x;
          cy = y;
          break;
        case 'Q':
          final x1 = rel ? cx + a[0] : a[0];
          final y1 = rel ? cy + a[1] : a[1];
          final x = rel ? cx + a[2] : a[2];
          final y = rel ? cy + a[3] : a[3];
          path.quadraticBezierTo(x1, y1, x, y);
          lcx = x1;
          lcy = y1;
          cx = x;
          cy = y;
          break;
        case 'T':
          final x1 = 2 * cx - lcx;
          final y1 = 2 * cy - lcy;
          final x = rel ? cx + a[0] : a[0];
          final y = rel ? cy + a[1] : a[1];
          path.quadraticBezierTo(x1, y1, x, y);
          lcx = x1;
          lcy = y1;
          cx = x;
          cy = y;
          break;
        case 'Z':
          path.close();
          cx = sx;
          cy = sy;
          cmd = null;
          break;
      }
    }
    return path;
  }
}

// ------------------------------------------------------------------
//  Google
// ------------------------------------------------------------------
class _GooglePainter extends CustomPainter {
  static const double _vbW = 533.5;
  static const double _vbH = 544.3;

  // Data path resmi logo Google (empat segmen warna).
  static const List<List<String>> _parts = [
    [
      '4285F4',
      'M533.5 278.4c0-18.5-1.5-37.1-4.7-55.3H272.1v104.8h147c-6.1 33.8-25.7 63.7-54.4 82.7'
          'v68h87.7c51.5-47.4 81.1-117.4 81.1-200.2z'
    ],
    [
      '34A853',
      'M272.1 544.3c73.4 0 135.3-24.1 180.4-65.7l-87.7-68c-24.4 16.6-55.9 26-92.6 26-71 0-131.2-47.9-152.8-112.3'
          'H28.9v70.1c46.2 91.9 140.3 149.9 243.2 149.9z'
    ],
    ['FBBC04', 'M119.3 324.3c-11.4-33.8-11.4-70.4 0-104.2V150H28.9c-38.6 76.9-38.6 167.5 0 244.4l90.4-70.1z'],
    [
      'EA4335',
      'M272.1 107.7c38.8-.6 76.3 14 104.4 40.8l77.7-77.7C405 24.6 339.7-.8 272.1 0 169.2 0 75.1 58 28.9 150'
          'l90.4 70.1c21.5-64.5 81.8-112.4 152.8-112.4z'
    ],
  ];

  static final List<Path> _paths = _parts.map((e) => SvgPathMini.parse(e[1])).toList();

  @override
  void paint(Canvas canvas, Size size) {
    final skala = size.width / _vbW;
    canvas.save();
    canvas.translate(0, (size.height - _vbH * skala) / 2);
    canvas.scale(skala);
    for (var i = 0; i < _paths.length; i++) {
      final p = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = Color(int.parse('FF${_parts[i][0]}', radix: 16));
      canvas.drawPath(_paths[i], p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Logo Google asli (empat warna).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GooglePainter()),
      );
}

// ------------------------------------------------------------------
//  Facebook
// ------------------------------------------------------------------
class _FacebookPainter extends CustomPainter {
  static const String _f =
      'M80 299.3V512H196V299.3h86.5l18-97.8H196v-33.5c0-51.9 20.3-71.8 72.9-71.8c16.3 0 29.4 .4 37 1.2'
      'V7.9C291.4 4 256.4 0 236.2 0C129.3 0 80 50.5 80 159.4v42.1H0v97.8H80z';
  static final Path _glyph = SvgPathMini.parse(_f);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF1877F2),
    );

    // glyph "f" (viewBox 320 x 512), tinggi 62% dari lingkaran, menempel sisi bawah
    const vbW = 320.0, vbH = 512.0;
    final skala = size.height * .62 / vbH;
    canvas.save();
    canvas.translate((size.width - vbW * skala) / 2 + size.width * .012, size.height - vbH * skala);
    canvas.scale(skala);
    canvas.drawPath(
      _glyph,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Logo Facebook asli (lingkaran biru dengan huruf f).
class FacebookLogo extends StatelessWidget {
  const FacebookLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FacebookPainter()),
      );
}
