import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xycloud_order/core/config.dart';
import 'package:xycloud_order/core/theme.dart';
import 'package:xycloud_order/main.dart';

void main() {
  testWidgets('Aplikasi berhasil dibangun', (tester) async {
    await tester.pumpWidget(const XyCloudStoreApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('Token tema memakai identitas ungu XyCloudStore', () {
    expect(XyTheme.primary, const Color(0xFF6C2BE2));
    expect(XyTheme.light().useMaterial3, isTrue);
  });

  test('Konfigurasi menunjuk domain resmi', () {
    expect(XyConfig.appName, 'XyCloudStore');
    expect(XyConfig.apiUrl.startsWith('https://'), isTrue);
  });
}
