import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:xycloud_order/core/waktu.dart';
import 'package:xycloud_order/models/models.dart';
import 'package:xycloud_order/providers/app_state.dart';
import 'package:xycloud_order/ui/screens/order_detail_screen.dart';
import 'komentar_akun_test.dart' show StateUji;

void main(){
  setUpAll(() async {await initializeDateFormatting('id_ID');});
  test('Waktu relatif Indonesia dari detik sampai tahun',(){
    final now=DateTime.utc(2026,9,7,12);
    expect(waktuRelatif(now.subtract(const Duration(seconds:1)),sekarang:now),'1 detik lalu');
    expect(waktuRelatif(now.subtract(const Duration(minutes:2)),sekarang:now),'2 menit lalu');
    expect(waktuRelatif(now.subtract(const Duration(hours:3)),sekarang:now),'3 jam lalu');
    expect(waktuRelatif(now.subtract(const Duration(days:7)),sekarang:now),'7 hari lalu');
    expect(waktuRelatif(now.add(const Duration(seconds:5)),sekarang:now),'baru saja');
  });
  test('Timestamp SQLite ditafsirkan sebagai UTC, bukan jam lokal HP',(){
    expect(tanggalServer('2026-09-07 12:30:00'),DateTime.utc(2026,9,7,12,30));
    expect(tanggalServer('2026-09-07T19:30:00+07:00').toUtc(),DateTime.utc(2026,9,7,12,30));
  });
  testWidgets('Pesanan dibayar tanpa deadline sudah mempunyai tombol Mulai Main',(tester)async{
    final s=StateUji();s.orders=[RentOrder(id:'o',kode:'XY-TEST',planId:'p',planNama:'Paket Uji',durasiJam:1,total:11000,status:OrderStatus.dibayar,dibuat:DateTime.now())];
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value:s,child:MaterialApp(home:const OrderDetailScreen(orderId:'o'))));
    await tester.pump();
    expect(find.text('Mulai Main'),findsOneWidget);expect(find.text('Perpanjang'),findsNothing);expect(find.text('Kredensial Remote Desktop'),findsNothing);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());s.dispose();
  });
}
