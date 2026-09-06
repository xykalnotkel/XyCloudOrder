import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xycloud_order/core/theme.dart';
import 'package:xycloud_order/main.dart';

void main() {
  testWidgets('Aplikasi berhasil dibangun dan menampilkan splash', (tester) async {
    await tester.pumpWidget(const XyCloudOrderApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('XyCloudOrder'), findsWidgets);
    expect(find.text('PREMIUM EDITION'), findsOneWidget);
  });

  test('Token tema tersedia', () {
    expect(XyTheme.primary, isA<Color>());
    expect(XyTheme.light().useMaterial3, isTrue);
  });
}
