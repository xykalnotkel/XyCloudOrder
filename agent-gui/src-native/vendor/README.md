# vendor/egui-wgpu

Salinan vendored `egui-wgpu 0.29.1` (crates.io, lisensi MIT OR Apache-2.0,
bagian dari proyek egui/eframe — © Emil Ernerfeldt dan kontributor).

## Perubahan dari upstream (hanya 1 fitur, 3 baris efektif)

`WgpuConfiguration.force_fallback_adapter: bool` (default `false`) yang
diteruskan ke `Instance::request_adapter`. Upstream meng-hardcode `false`,
sehingga adapter software (WARP di Windows) tidak pernah dipakai — akibatnya
aplikasi gagal membuka jendela di PC tanpa GPU/driver layak. Agen XyCloudStore
memakainya sebagai fallback renderer terakhir (`--warp`).

Dipasang lewat `[patch.crates-io]` di `../Cargo.toml`. Tidak ada perubahan
lain; jangan naikkan versi tanpa menyandingkan ulang patch ini.
