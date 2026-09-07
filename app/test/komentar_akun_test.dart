import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xycloud_order/models/models.dart';
import 'package:xycloud_order/providers/app_state.dart';
import 'package:xycloud_order/ui/screens/forum_screen.dart';
import 'package:xycloud_order/ui/screens/hapus_akun_screen.dart';

class StateUji extends AppState {
  StateUji(){
    user=UserProfile(id:'a',nama:'Baru',email:'a@example.invalid');
    forum=[ForumPost(id:'p',userId:'a',nama:'Lama',kategori:'Umum',judul:'Diskusi uji',isi:'Isi diskusi untuk uji lokal.',dibuat:DateTime(2026))];
  }
  String? pesanTerkirim,parentTerkirim,passwordHapus;
  @override Future<void> muatKonfigurasi()async{}
  @override Future<void> muatPromosi()async{}
  @override Future<void> muatTema()async{}
  @override Future<void> periksaPembaruan()async{}
  @override Future<void> pulihkanSesi()async{memeriksaSesi=false;}
  @override Future<void> muatSukaBalasan()async{}
  @override Future<void> muatForum({bool paksa=false})async{}
  @override Future<List<ForumBalasan>> detailForum(String id)async=>[
    ForumBalasan(id:'c1',postId:'p',userId:'a',nama:'Lama',isi:'Halo',dibuat:DateTime(2026)),
    ForumBalasan(id:'c2',postId:'p',userId:'b',nama:'B',isi:'Balasan',balasKe:'c1',dibuat:DateTime(2026)),
  ];
  @override Future<String?> balasForum(String id,String isi,{String? balasKe,Map<String,dynamic>? stiker})async{pesanTerkirim=isi;parentTerkirim=balasKe;return null;}
  @override Future<Map<String,dynamic>> infoHapusAkun()async=>{'boleh_hapus':true,'perlu_otp':false,'penghalang':[]};
  @override Future<String?> hapusAkun({String? password,String? kode,bool paksa=false})async{passwordHapus=password;return null;}
}

void main(){
  setUpAll(() async { await initializeDateFormatting('id_ID'); });
  testWidgets('Komentar memakai nama terbaru dan tombol balas mengarah ke induk yang benar',(tester)async{
    await tester.binding.setSurfaceSize(const Size(390,844));addTearDown(()=>tester.binding.setSurfaceSize(null));
    final state=StateUji();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value:state,child:MaterialApp(theme:ThemeData.dark(),home:ForumDetailScreen(post:state.forum.first))));
    await tester.pump(const Duration(milliseconds:300));
    expect(find.text('Lama'),findsNothing);expect(find.text('Baru'),findsWidgets);
    await tester.ensureVisible(find.text('Balas').first);await tester.tap(find.text('Balas').first);await tester.pump();
    await tester.enterText(find.byType(TextField),'Pesan balasan');await tester.pump();
    await tester.tap(find.byTooltip('Kirim komentar'));await tester.pump(const Duration(milliseconds:300));
    expect(state.pesanTerkirim,'Pesan balasan');expect(state.parentTerkirim,'c1');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());state.dispose();
  });
  testWidgets('Hapus akun memerlukan password dan kata konfirmasi eksplisit',(tester)async{
    final state=StateUji();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value:state,child:MaterialApp(home:const HapusAkunScreen())));
    await tester.pump(const Duration(milliseconds:300));
    final button=find.byWidgetPredicate((w)=>w is FilledButton);
    await tester.ensureVisible(button);
    expect(tester.widget<FilledButton>(button).onPressed,isNull);
    await tester.enterText(find.byType(TextField).first,'password-test');
    await tester.enterText(find.byType(TextField).last,'HAPUS');await tester.pump();
    await tester.ensureVisible(button);await tester.tap(button);await tester.pump();
    expect(state.passwordHapus,'password-test');expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());state.dispose();
  });
}
