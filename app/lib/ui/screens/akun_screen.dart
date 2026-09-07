import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/produk_ulasan.dart';

class AkunScreen extends StatefulWidget {
  const AkunScreen({super.key, this.fokusId});
  final String? fokusId;
  @override
  State<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends State<AkunScreen> {
  String kategori = 'Semua';
  String cari = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final kategoriList = ['Semua', ...{...s.produk.map((e) => e.kategori)}];
    var list = s.produk.where((p) {
      final okKat = kategori == 'Semua' || p.kategori == kategori;
      final okCari = cari.isEmpty || p.nama.toLowerCase().contains(cari.toLowerCase());
      return okKat && okCari;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beli Akun', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.4)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: LiveDot(state: s.koneksi)))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => cari = v),
            decoration: const InputDecoration(
              hintText: 'Cari akun, game, atau layanan...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kategoriList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final k = kategoriList[i];
              final aktif = k == kategori;
              return ChoiceChip(
                label: Text(k),
                selected: aktif,
                onSelected: (_) => setState(() => kategori = k),
                selectedColor: XyTheme.primary,
                labelStyle: TextStyle(
                    color: aktif ? Colors.white : XyTheme.ink, fontWeight: FontWeight.w700, fontSize: 12.5),
              );
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Kosong(icon: Icons.search_off_rounded, judul: 'Produk tidak ditemukan')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .66,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _KartuProduk(produk: list[i]),
                ),
        ),
      ]),
    );
  }
}

class _KartuProduk extends StatelessWidget {
  const _KartuProduk({required this.produk});
  final AkunProduk produk;

  @override
  Widget build(BuildContext context) {
    final diskon = produk.hargaCoret > 0
        ? (((produk.hargaCoret - produk.harga) / produk.hargaCoret) * 100).round()
        : 0;
    return XyCard(
      padding: const EdgeInsets.all(12),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SheetDetail(produk: produk),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(
            width: double.infinity,
            child: GambarProduk(produk: produk, tinggi: 92, radius: 14),
          ),
          if (diskon > 0)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: XyTheme.danger, borderRadius: BorderRadius.circular(20)),
                child: Text('-$diskon%',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(produk.nama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.25)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.star_rounded, size: 13, color: XyTheme.gold),
          Text(' ${produk.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(' (${produk.jumlahUlasan})', style: const TextStyle(fontSize: 10.5, color: XyTheme.muted)),
          Text(' · ${produk.terjual}x', style: const TextStyle(fontSize: 11, color: XyTheme.muted)),
        ]),
        const Spacer(),
        if (produk.hargaCoret > 0)
          Text(rupiah(produk.hargaCoret),
              style: const TextStyle(
                  fontSize: 11, color: XyTheme.muted, decoration: TextDecoration.lineThrough)),
        Text(rupiah(produk.harga),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: XyTheme.primary, letterSpacing: -.3)),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: produk.stok > 0 ? XyTheme.success : XyTheme.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(produk.stok > 0 ? 'Stok ${produk.stok}' : 'Stok habis',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: produk.stok > 0 ? XyTheme.success : XyTheme.danger)),
        ]),
      ]),
    );
  }
}

class _SheetDetail extends StatefulWidget {
  const _SheetDetail({required this.produk});
  final AkunProduk produk;
  @override
  State<_SheetDetail> createState() => _SheetDetailState();
}

class _SheetDetailState extends State<_SheetDetail> {
  bool proses = false;
  String metode = 'saldo';

  @override
  void initState() {
    super.initState();
    // ambil ulasan terbaru begitu halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatUlasan(widget.produk.id);
    });
  }

  Future<void> _beli() async {
    final s = context.read<AppState>();
    if (metode == 'saldo' && (s.user?.saldo ?? 0) < widget.produk.harga) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldo tidak cukup, top up dulu ya.')));
      return;
    }
    setState(() => proses = true);
    final hasil = await s.beliAkun(widget.produk, metode);
    if (!mounted) return;
    setState(() => proses = false);
    Navigator.pop(context);
    if (hasil != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DialogAkun(data: hasil, produk: widget.produk),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produk;
    return DraggableScrollableSheet(
      initialChildSize: .82,
      maxChildSize: .95,
      minChildSize: .5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: XyTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: XyTheme.line, borderRadius: BorderRadius.circular(10)),
          ),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
              GambarProduk(produk: p, tinggi: 200),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Pill(p.kategori, warna: XyTheme.violet),
                    const SizedBox(height: 8),
                    Text(p.nama,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.28, letterSpacing: -.4)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Bintang(nilai: p.rating, ukuran: 15),
                      const SizedBox(width: 7),
                      Text('${p.rating}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      Text('  ·  ${p.jumlahUlasan} ulasan  ·  ${p.terjual} terjual',
                          style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              XyCard(
                child: Row(children: [
                  Expanded(child: _Stat('Stok', '${p.stok}', Icons.inventory_2_rounded)),
                  Container(width: 1, height: 34, color: XyTheme.line),
                  Expanded(child: _Stat('Terjual', '${p.terjual}', Icons.local_fire_department_rounded)),
                  Container(width: 1, height: 34, color: XyTheme.line),
                  Expanded(child: _Stat('Garansi', p.garansi, Icons.verified_user_rounded)),
                ]),
              ),
              const SectionHeader('Deskripsi'),
              Text(p.deskripsi.isEmpty ? 'Belum ada deskripsi untuk produk ini.' : p.deskripsi,
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: XyTheme.muted)),
              if (p.detail.isNotEmpty) ...[
                const SectionHeader('Detail Produk'),
                XyCard(
                  child: Column(
                    children: p.detail.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                SizedBox(
                                  width: 116,
                                  child: Text(e.key,
                                      style: const TextStyle(color: XyTheme.muted, fontSize: 12.5)),
                                ),
                                Expanded(
                                  child: Text('${e.value}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.8, height: 1.45)),
                                ),
                              ]),
                            ))
                        .toList(),
                  ),
                ),
              ],
              const SectionHeader('Yang Kamu Dapat'),
              ...p.fitur.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, size: 17, color: XyTheme.success),
                      const SizedBox(width: 9),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 13.5))),
                    ]),
                  )),
              Row(children: [
                const Expanded(child: SectionHeader('Ulasan Pembeli')),
                TextButton.icon(
                  onPressed: () => bukaFormUlasan(context, p),
                  icon: const Icon(Icons.rate_review_outlined, size: 17),
                  label: const Text('Tulis'),
                ),
              ]),
              Builder(builder: (context) {
                final daftar = context.watch<AppState>().ulasanProduk(p.id);
                if (daftar.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    decoration: BoxDecoration(
                      color: XyTheme.surface,
                      borderRadius: BorderRadius.circular(XyRadius.lg),
                      border: Border.all(color: XyTheme.line),
                    ),
                    child: const Column(children: [
                      Icon(Icons.reviews_outlined, color: XyTheme.muted, size: 26),
                      SizedBox(height: 10),
                      Text('Belum ada ulasan untuk produk ini',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('Jadilah yang pertama memberi penilaian.',
                          style: TextStyle(color: XyTheme.muted, fontSize: 12)),
                    ]),
                  );
                }
                return Column(children: daftar.take(8).map((u) => KartuUlasan(u)).toList());
              }),
              const SectionHeader('Bayar Pakai'),
              Row(children: [
                Expanded(child: _PilihBayar('saldo', 'Saldo', Icons.account_balance_wallet_rounded, metode, (v) => setState(() => metode = v))),
                const SizedBox(width: 10),
                Expanded(child: _PilihBayar('qris', 'QRIS', Icons.qr_code_2_rounded, metode, (v) => setState(() => metode = v))),
                const SizedBox(width: 10),
                Expanded(child: _PilihBayar('va', 'VA Bank', Icons.account_balance_rounded, metode, (v) => setState(() => metode = v))),
              ]),
            ]),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(color: XyTheme.surface, boxShadow: XyTheme.shadowMd),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Harga', style: TextStyle(fontSize: 11.5, color: XyTheme.muted)),
                Text(rupiah(p.harga), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -.5)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  label: p.stok == 0 ? 'Stok Habis' : 'Beli Sekarang',
                  icon: p.stok == 0 ? Icons.block_rounded : Icons.shopping_bag_rounded,
                  loading: proses,
                  gradient: const LinearGradient(colors: [XyTheme.violet, XyTheme.primary]),
                  glowColor: XyTheme.violet,
                  onPressed: p.stok == 0 || proses ? null : _beli,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PilihBayar extends StatelessWidget {
  const _PilihBayar(this.id, this.label, this.icon, this.aktifId, this.onPilih);
  final String id, label;
  final IconData icon;
  final String aktifId;
  final ValueChanged<String> onPilih;
  @override
  Widget build(BuildContext context) {
    final aktif = id == aktifId;
    return GestureDetector(
      onTap: () => onPilih(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: aktif ? XyTheme.primary.withOpacity(.08) : XyTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: aktif ? XyTheme.primary : XyTheme.line, width: aktif ? 1.6 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 21, color: aktif ? XyTheme.primary : XyTheme.muted),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: aktif ? XyTheme.primary : XyTheme.muted)),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.nilai, this.icon);
  final String label, nilai;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 18, color: XyTheme.primary),
      const SizedBox(height: 5),
      Text(nilai, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      Text(label, style: const TextStyle(fontSize: 10.5, color: XyTheme.muted)),
    ]);
  }
}

class _DialogAkun extends StatelessWidget {
  const _DialogAkun({required this.data, required this.produk});
  final Map<String, dynamic> data;
  final AkunProduk produk;

  @override
  Widget build(BuildContext context) {
    Widget baris(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k, style: const TextStyle(fontSize: 11, color: XyTheme.muted)),
                SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, fontFamily: 'monospace')),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 17),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: v));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$k disalin'), duration: const Duration(seconds: 1)));
              },
            ),
          ]),
        );

    return Container(
      decoration: const BoxDecoration(
        color: XyTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).padding.bottom + 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const XyIlustrasi('sukses', tinggi: 132),
          const SizedBox(height: 6),
          const Text('Pembelian Berhasil', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(produk.nama, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: XyTheme.muted)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: XyTheme.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              baris('Kode Pesanan', '${data['kode']}'),
              baris('Email Akun', '${data['email']}'),
              baris('Password', '${data['password']}'),
            ]),
          ),
          const SizedBox(height: 12),
          Text('${data['catatan']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: XyTheme.muted, height: 1.5)),
          const SizedBox(height: 18),
          GradientButton(label: 'Selesai', onPressed: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
