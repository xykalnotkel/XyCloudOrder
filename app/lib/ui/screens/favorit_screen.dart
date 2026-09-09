import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Favorit Produk — simpan akun/produk yang disukai user
class FavoritScreen extends StatefulWidget {
  const FavoritScreen({super.key});
  @override
  State<FavoritScreen> createState() => _FavoritScreenState();
}

class _FavoritScreenState extends State<FavoritScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatFavorit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final favIds = s.favorit;
    final produkFav = s.produk.where((p) => favIds.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorit Saya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF100030), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: XyTheme.glow(XyTheme.primary, .22),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${favIds.length} Produk Disukai',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Tap produk untuk lihat detail, tap ♥ lagi untuk hapus.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Daftar Favorit'),
          if (produkFav.isEmpty)
            const Kosong(
              icon: Icons.favorite_border_rounded,
              judul: 'Belum ada favorit',
              sub: 'Tap ikon ♥ di produk akun untuk simpan.',
              ilustrasi: 'favorit',
            )
          else
            ...produkFav.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: XyCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: XyTheme.of(context).primarySoft,
                          child: p.gambar.isNotEmpty
                              ? Image.network(p.gambar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded))
                              : const Icon(Icons.storefront_rounded, color: XyTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text('${p.kategori} • Rp ${p.harga}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFE8C07A)),
                            const SizedBox(width: 3),
                            Text('${p.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text('${p.stok} stok', style: TextStyle(fontSize: 10.5, color: XyTheme.of(context).muted)),
                          ]),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_rounded, color: XyTheme.danger, size: 20),
                        onPressed: () => context.read<AppState>().ubahFavorit(p.id),
                      ),
                    ]),
                  ),
                )),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tips', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                '• Favorit tersinkron ke server, tetap ada meski ganti HP\n• Dapatkan notifikasi kalau produk favorit restock atau diskon\n• Gunakan filter Favorit di halaman Akun untuk lihat cepat',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
