import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/pengaturan.dart';
import '../../data/stiker_store.dart';
import '../../models/stiker.dart';
import '../../providers/app_state.dart';
import '../widgets/stiker_picker.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';

class StikerLibraryScreen extends StatefulWidget {
  const StikerLibraryScreen({super.key});
  @override State<StikerLibraryScreen> createState()=>_StikerLibraryScreenState();
}
class _StikerLibraryScreenState extends State<StikerLibraryScreen>{
  late final store=StikerStore.untuk(context.read<AppState>().user!.id);
  List<StikerLokal> items=[];
  Map<String,dynamic>? info;
  String? error;
  final images=<String,Future<Uint8List>>{};
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final list=await store.daftar(),data=await store.informasi();if(mounted)setState((){items=list;info=data;error=null;});}catch(e){if(mounted)setState(()=>error='Koleksi lokal belum dapat dibaca. $e');}}
  Future<void> add()async{final choice=await pilihStiker(context);if(choice==null)return;try{await store.simpan(choice.stiker,bytes:choice.bytes);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
  Future<void> remove(StikerLokal item)async{if(!await konfirmasi(context,judul:'Hapus dari koleksi?',pesan:'Pesan/stiker yang sudah dibagikan tidak ikut dihapus.',tombolYa:'Hapus',bahaya:true))return;await store.hapus(item);images.remove(item.id);await load();}
  String size(num? n)=>n==null?'—':n>1024*1024?'${(n/(1024*1024)).toStringAsFixed(1)} MB':'${(n/1024).ceil()} KB';
  @override Widget build(BuildContext context){final pal=XyTheme.of(context);return Scaffold(appBar:AppBar(title:Text('Stiker & Penyimpanan'),actions:[IconButton(tooltip:'Tambah stiker',onPressed:add,icon:Icon(Icons.add_rounded))]),
    body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(20),children:[
      XyCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Tersimpan di aplikasi ini',style:TextStyle(fontSize:19,fontWeight:FontWeight.w700)),const SizedBox(height:8),
        Text('Koleksi dan cache menggunakan AES-256-GCM. Folder internal package dilindungi Android; bukan folder galeri atau file WebP yang terbuka.',style:TextStyle(color:pal.muted,height:1.6)),
        const SizedBox(height:18),Wrap(spacing:22,runSpacing:12,children:[_stat('Koleksi','${items.length} / 100'),_stat('Ukuran koleksi',size(info?['collectionBytes'] as num?)),_stat('Cache sementara',size(info?['cacheBytes'] as num?))]),
        const SizedBox(height:16),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Lokasi folder internal',style:TextStyle(fontSize:13)),children:[SelectableText('${info?['path']??'Memuat…'}',style:TextStyle(fontSize:11,color:pal.muted))]),
      ])),
      const SizedBox(height:14),SwitchListTile(contentPadding:EdgeInsets.zero,value:PengaturanLokal.nilai['stickerAutoSave']!=false,title:const Text('Simpan stiker yang dikirim'),subtitle:const Text('Otomatis masuk koleksi setelah komentar berhasil dikirim'),onChanged:(v)async{await context.read<AppState>().setPengaturan('stickerAutoSave',v);if(mounted)setState((){});}),
      Text('Stiker yang ditampilkan dicache terenkripsi, maksimum 32 MB. Stiker orang lain tidak otomatis memenuhi koleksi favoritmu.',style:TextStyle(color:pal.muted,fontSize:12,height:1.5)),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:()async{await store.bersihkanCache();await load();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cache dibersihkan. Koleksi tetap tersimpan.')));},icon:const Icon(Icons.cleaning_services_outlined),label:const Text('Bersihkan cache saja')),
      const SizedBox(height:22),Row(children:[const Expanded(child:Text('Koleksi kamu',style:TextStyle(fontWeight:FontWeight.w700,fontSize:17))),TextButton(onPressed:add,child:const Text('Tambah'))]),
      if(error!=null)Text(error!,style:const TextStyle(color:XyTheme.danger)),
      if(info==null&&error==null)const Center(child:CircularProgressIndicator()),
      if(info!=null&&items.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:28),child:Text('Belum ada stiker tersimpan. Impor dari galeri atau simpan stiker yang kamu suka.',textAlign:TextAlign.center,style:TextStyle(color:pal.muted,height:1.6))),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:140,crossAxisSpacing:12,mainAxisSpacing:12),itemCount:items.length,itemBuilder:(ctx,i){final item=items[i];return FutureBuilder<Uint8List>(future:images.putIfAbsent(item.id,()=>store.baca(item)),builder:(ctx,snap)=>InkWell(onLongPress:()=>remove(item),onTap:snap.hasData?()=>showDialog(context:context,builder:(ctx)=>Dialog(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[GambarStiker(item.stiker,bytes:snap.data,ukuran:220),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Tutup')),TextButton(onPressed:(){Navigator.pop(ctx);remove(item);},child:const Text('Hapus dari koleksi'))])))):null,child:Padding(padding:const EdgeInsets.all(8),child:snap.hasData?GambarStiker(item.stiker,bytes:snap.data,ukuran:100):Icon(snap.hasError?Icons.lock_outline:Icons.hourglass_empty,color:pal.muted))));}),
    ])));
  }
  Widget _stat(String title,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:XyTheme.of(context).muted,fontSize:11)),const SizedBox(height:5),Text(value,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16))]);
}
