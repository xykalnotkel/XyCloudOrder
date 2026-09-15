// ============================================================
//  XyCloudStore — Agen PC Host (Rust + egui/eframe NATIVE)
// ============================================================
//  Pengganti build Tauri: tanpa WebView2, tanpa terminal, satu
//  exe mandiri. Logika inti (agent.rs) dipakai ulang apa adanya
//  lewat #[path] supaya kedua build tidak pernah berbeda perilaku.
//
//  Mode:
//   --veri / -V      → cetak versi lalu keluar 0 (smoke-test CI)
//   -Jalankan        → headless loop (dipakai autostart registry)
//   (tanpa argumen)  → buka jendela GUI
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[path = "../../src-tauri/src/agent.rs"]
mod agent;

use agent::{Konfig, Logger, VERSI};
use eframe::egui;
use serde_json::Value;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

const UNGU: egui::Color32 = egui::Color32::from_rgb(0x7C, 0x3A, 0xED);
const UNGU_LEMBUT: egui::Color32 = egui::Color32::from_rgb(0xA7, 0x8B, 0xFA);

/// Status operasi berat yang sedang berjalan (uji/setup/loop agen).
#[derive(Clone, Copy, PartialEq, Eq)]
enum Sibuk {
    Tidak,
    Uji,
    Setup,
    Loop,
}

struct Keadaan {
    cfg: Arc<Mutex<Konfig>>,
    stop: Arc<AtomicBool>,
    berjalan: Arc<AtomicBool>,
    sibuk: Arc<Mutex<Sibuk>>,
    log: Arc<Mutex<Vec<String>>>,
    hasil_uji: Arc<Mutex<Option<Value>>>,
    hasil_setup: Arc<Mutex<Option<Value>>>,
    sinkron_draft: Arc<AtomicBool>,
}

impl Keadaan {
    fn baru(cfg: Konfig) -> Arc<Self> {
        Arc::new(Self {
            cfg: Arc::new(Mutex::new(cfg)),
            stop: Arc::new(AtomicBool::new(false)),
            berjalan: Arc::new(AtomicBool::new(false)),
            sibuk: Arc::new(Mutex::new(Sibuk::Tidak)),
            log: Arc::new(Mutex::new(Vec::new())),
            hasil_uji: Arc::new(Mutex::new(None)),
            hasil_setup: Arc::new(Mutex::new(None)),
            sinkron_draft: Arc::new(AtomicBool::new(false)),
        })
    }

    fn cfg(&self) -> Konfig {
        self.cfg.lock().unwrap().clone()
    }

    fn set_sibuk(&self, s: Sibuk) {
        *self.sibuk.lock().unwrap() = s;
    }

    fn log_push(&self, teks: &str, ctx: &egui::Context) {
        let jam = jam_wib();
        let mut l = self.log.lock().unwrap();
        l.push(format!("[{jam}] {teks}"));
        if l.len() > 600 {
            let buang = l.len() - 600;
            l.drain(0..buang);
        }
        drop(l);
        ctx.request_repaint();
    }
}

/// Logger yang menulis ke panel log + minta repaint.
fn logger_gui(st: Arc<Keadaan>, ctx: egui::Context) -> Logger {
    Arc::new(move |teks: &str| st.log_push(teks, &ctx))
}

struct Aplikasi {
    ctx: egui::Context,
    st: Arc<Keadaan>,
    // Draft isian pengaturan (disinkron dari cfg saat perlu).
    d_kode: String,
    d_server: String,
    d_user: String,
    d_sandi: String,
    tampil_sandi: bool,
    autostart: bool,
    status_simpan: Option<(bool, String)>,
}

impl Aplikasi {
    fn baru(cc: &eframe::CreationContext<'_>, st: Arc<Keadaan>) -> Self {
        terapkan_tema(&cc.egui_ctx);
        let cfg = st.cfg();
        let autostart = agent::autostart_aktif();
        Self {
            ctx: cc.egui_ctx.clone(),
            st,
            d_kode: cfg.kode,
            d_server: cfg.server,
            d_user: cfg.user,
            d_sandi: cfg.sandi,
            tampil_sandi: false,
            autostart,
            status_simpan: None,
        }
    }

    fn sinkron_draft(&mut self) {
        let cfg = self.st.cfg();
        self.d_kode = cfg.kode;
        self.d_server = cfg.server;
        self.d_user = cfg.user;
        self.d_sandi = cfg.sandi;
    }

    fn simpan(&mut self) {
        let lama = self.st.cfg();
        let mut k = Konfig {
            kode: self.d_kode.trim().into(),
            user: self.d_user.trim().into(),
            sandi: self.d_sandi.trim().into(),
            server: if self.d_server.trim().is_empty() {
                "https://api.xycloud.my.id".into()
            } else {
                self.d_server.trim().into()
            },
        };
        if k.kode.is_empty() {
            self.status_simpan = Some((false, "Kode unit wajib diisi.".into()));
            return;
        }
        // Kosong = pertahankan kredensial lama (sama seperti build Tauri).
        if k.sandi.is_empty() {
            k.sandi = lama.sandi;
        }
        if k.user.is_empty() {
            k.user = lama.user;
        }
        match agent::simpan_konfig(&k) {
            Ok(_) => {
                *self.st.cfg.lock().unwrap() = k.clone();
                self.d_sandi = k.sandi;
                self.d_user = k.user;
                self.d_server = k.server;
                self.status_simpan =
                    Some((true, format!("Pengaturan tersimpan untuk unit {}", k.kode)));
            }
            Err(e) => self.status_simpan = Some((false, format!("Gagal menyimpan: {e}"))),
        }
    }

    fn uji_koneksi(&self) {
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Uji;
        }
        *self.st.hasil_uji.lock().unwrap() = None;
        let cfg = self.st.cfg();
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            st.log_push("Menjalankan uji koneksi lokal (Sunshine API)…", &ctx);
            let hasil = agent::periksa_sunshine(&cfg);
            {
                *st.hasil_uji.lock().unwrap() = Some(hasil.clone());
                st.set_sibuk(Sibuk::Tidak);
            }
            st.log_push(
                &format!(
                    "Hasil uji: {} — {}",
                    hasil.get("status").and_then(|x| x.as_str()).unwrap_or("-"),
                    hasil.get("pesan").and_then(|x| x.as_str()).unwrap_or("")
                ),
                &ctx,
            );
        });
        self.ctx.request_repaint();
    }

    fn setup_engine(&self) {
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Setup;
        }
        *self.st.hasil_setup.lock().unwrap() = None;
        let cfg = self.st.cfg();
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            let (k_baru, hasil) = agent::setup_otomatis(&cfg, log);
            {
                *st.cfg.lock().unwrap() = k_baru.clone();
                *st.hasil_setup.lock().unwrap() = Some(hasil.clone());
                st.set_sibuk(Sibuk::Tidak);
                st.sinkron_draft.store(true, Ordering::Relaxed);
            }
            st.log_push(
                &format!(
                    "Setup selesai · unit={} · sunshine_user={} · siap={}",
                    k_baru.kode,
                    k_baru.user,
                    hasil.get("siap").and_then(|x| x.as_bool()).unwrap_or(false)
                ),
                &ctx,
            );
        });
        self.ctx.request_repaint();
    }

    fn mulai_loop(&self) {
        // Ambil konfig terbaru (memori → disk), sama seperti build Tauri.
        let cfg = {
            let mem = self.st.cfg();
            if !mem.kode.is_empty() {
                mem
            } else {
                agent::muat_konfig()
            }
        };
        if cfg.kode.is_empty() {
            self.st
                .log_push("Simpan pengaturan (kode unit) dulu.", &self.ctx);
            return;
        }
        if cfg.user.is_empty() || cfg.sandi.is_empty() {
            self.st.log_push(
                "Sunshine belum di-setup. Jalankan Setup Engine dulu.",
                &self.ctx,
            );
            return;
        }
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Loop;
        }
        self.st.stop.store(false, Ordering::Relaxed);
        self.st.berjalan.store(true, Ordering::Relaxed);
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            agent::jalankan_loop(cfg, log, st.stop.clone());
            st.berjalan.store(false, Ordering::Relaxed);
            st.set_sibuk(Sibuk::Tidak);
            ctx.request_repaint();
        });
        self.ctx.request_repaint();
    }

    fn hentikan(&self) {
        self.st.stop.store(true, Ordering::Relaxed);
        self.st.log_push("Menghentikan agen…", &self.ctx);
    }

    fn toggle_autostart(&mut self, aktif: bool) {
        self.autostart = aktif;
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            agent::atur_autostart(aktif, &log);
        });
    }
}

impl eframe::App for Aplikasi {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if self
            .st
            .sinkron_draft
            .swap(false, Ordering::Relaxed)
        {
            self.sinkron_draft();
        }
        let sibuk = *self.st.sibuk.lock().unwrap();
        let berjalan = self.st.berjalan.load(Ordering::Relaxed);
        // Repaint berkala agar indikator & log tetap hidup.
        ctx.request_repaint_after(std::time::Duration::from_millis(500));

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(10.0);

            // ---------- kepala ----------
            ui.horizontal(|ui| {
                let (kotak, _) = ui.allocate_exact_size(
                    egui::vec2(38.0, 38.0),
                    egui::Sense::hover(),
                );
                ui.painter().rect(
                    kotak,
                    11.0,
                    UNGU,
                    egui::Stroke::new(1.4_f32, UNGU_LEMBUT),
                );
                ui.painter().text(
                    kotak.center(),
                    egui::Align2::CENTER_CENTER,
                    "☁",
                    egui::FontId::proportional(19.0),
                    egui::Color32::WHITE,
                );
                ui.add_space(6.0);
                ui.vertical(|ui| {
                    ui.label(
                        egui::RichText::new("XyCloudStore Agent")
                            .strong()
                            .size(17.0),
                    );
                    ui.label(
                        egui::RichText::new(format!(
                            "v{VERSI} · native egui (tanpa Tauri/WebView)"
                        ))
                        .size(11.0)
                        .color(egui::Color32::GRAY),
                    );
                });
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let (warna, teks) = if berjalan {
                        (egui::Color32::from_rgb(0x34, 0xD3, 0x99), "●  Agen berjalan")
                    } else if sibuk != Sibuk::Tidak {
                        (UNGU_LEMBUT, "●  Sibuk…")
                    } else {
                        (egui::Color32::GRAY, "●  Diam")
                    };
                    ui.label(egui::RichText::new(teks).color(warna).strong().size(12.0));
                });
            });

            ui.add_space(12.0);
            ui.separator();

            // ---------- pengaturan ----------
            ui.label(egui::RichText::new("Pengaturan Unit").strong().size(13.5));
            ui.add_space(6.0);
            egui::Grid::new("grid_cfg")
                .num_columns(2)
                .spacing([10.0, 8.0])
                .show(ui, |ui| {
                    ui.label("Kode unit");
                    ui.add(
                        egui::TextEdit::singleline(&mut self.d_kode)
                            .desired_width(f32::INFINITY)
                            .hint_text("contoh: UNIT-01"),
                    );
                    ui.end_row();

                    ui.label("Server API");
                    ui.add(
                        egui::TextEdit::singleline(&mut self.d_server)
                            .desired_width(f32::INFINITY)
                            .hint_text("https://api.xycloud.my.id"),
                    );
                    ui.end_row();

                    ui.label("User Sunshine");
                    ui.add(
                        egui::TextEdit::singleline(&mut self.d_user)
                            .desired_width(f32::INFINITY)
                            .hint_text("kosongkan = auto-setup"),
                    );
                    ui.end_row();

                    ui.label("Sandi Sunshine");
                    ui.horizontal(|ui| {
                        ui.add(
                            egui::TextEdit::singleline(&mut self.d_sandi)
                                .password(!self.tampil_sandi)
                                .desired_width(190.0)
                                .hint_text("kosongkan = dipertahankan",
                            ),
                        );
                        if ui.small_button("👁").clicked() {
                            self.tampil_sandi = !self.tampil_sandi;
                        }
                    });
                    ui.end_row();
                });

            ui.add_space(8.0);
            ui.horizontal(|ui| {
                if ui
                    .add(egui::Button::new("💾  Simpan").min_size(egui::vec2(110.0, 32.0)))
                    .clicked()
                {
                    self.simpan();
                }
                if let Some((ok, pesan)) = &self.status_simpan {
                    ui.label(
                        egui::RichText::new(pesan)
                            .size(11.5)
                            .color(if *ok {
                                egui::Color32::from_rgb(0x34, 0xD3, 0x99)
                            } else {
                                egui::Color32::from_rgb(0xF8, 0x71, 0x71)
                            }),
                    );
                }
            });

            ui.add_space(4.0);
            let cb = ui.checkbox(
                &mut self.autostart,
                "Jalankan otomatis saat login Windows",
            );
            if cb.changed() {
                let a = self.autostart;
                self.toggle_autostart(a);
            }

            ui.add_space(10.0);
            ui.separator();

            // ---------- kendali ----------
            ui.label(egui::RichText::new("Kendali Agen").strong().size(13.5));
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                let mati = sibuk != Sibuk::Tidak;
                ui.add_enabled_ui(!mati, |ui| {
                    if ui
                        .add(egui::Button::new("🔌  Uji koneksi").min_size(egui::vec2(120.0, 34.0)))
                        .clicked()
                    {
                        self.uji_koneksi();
                    }
                    if ui
                        .add(egui::Button::new("⚙  Setup Engine").min_size(egui::vec2(125.0, 34.0)))
                        .clicked()
                    {
                        self.setup_engine();
                    }
                });
                if berjalan {
                    if ui
                        .add(
                            egui::Button::new(
                                egui::RichText::new("⏹  Hentikan").color(egui::Color32::WHITE),
                            )
                            .fill(egui::Color32::from_rgb(0xB4, 0x23, 0x36))
                            .min_size(egui::vec2(110.0, 34.0)),
                        )
                        .clicked()
                    {
                        self.hentikan();
                    }
                } else {
                    ui.add_enabled_ui(!mati, |ui| {
                        if ui
                            .add(
                                egui::Button::new(
                                    egui::RichText::new("▶  Mulai Agen").color(egui::Color32::WHITE),
                                )
                                .fill(UNGU)
                                .min_size(egui::vec2(110.0, 34.0)),
                            )
                            .clicked()
                        {
                            self.mulai_loop();
                        }
                    });
                }
            });

            // Badge hasil uji / setup.
            badge_hasil(ui, "Uji koneksi", &self.st.hasil_uji.lock().unwrap());
            badge_hasil(ui, "Setup engine", &self.st.hasil_setup.lock().unwrap());

            if sibuk != Sibuk::Tidak {
                ui.add_space(4.0);
                ui.horizontal(|ui| {
                    ui.spinner();
                    ui.label(
                        egui::RichText::new(match sibuk {
                            Sibuk::Uji => "Menguji koneksi ke Sunshine…",
                            Sibuk::Setup => "Setup otomatis berjalan (unduh/pasang Sunshine bisa beberapa menit)…",
                            Sibuk::Loop => "Agen berjalan…",
                            Sibuk::Tidak => "",
                        })
                        .size(11.5)
                        .color(UNGU_LEMBUT),
                    );
                });
            }

            ui.add_space(8.0);
            ui.separator();

            // ---------- log ----------
            ui.horizontal(|ui| {
                ui.label(egui::RichText::new("Log Aktivitas").strong().size(13.5));
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.small_button("Bersihkan").clicked() {
                        self.st.log.lock().unwrap().clear();
                    }
                });
            });
            ui.add_space(4.0);
            let tinggi = ui.available_height() - 4.0;
            egui::ScrollArea::vertical()
                .max_height(tinggi.max(80.0))
                .stick_to_bottom(true)
                .auto_shrink([false, false])
                .show(ui, |ui| {
                    let log = self.st.log.lock().unwrap();
                    if log.is_empty() {
                        ui.label(
                            egui::RichText::new(
                                "Belum ada aktivitas. Simpan kode unit → Setup Engine → Mulai Agen.",
                            )
                            .italics()
                            .color(egui::Color32::GRAY),
                        );
                    }
                    for baris in log.iter() {
                        ui.label(
                            egui::RichText::new(baris)
                                .monospace()
                                .size(11.3)
                                .color(egui::Color32::from_rgb(0xC9, 0xC4, 0xD8)),
                        );
                    }
                });
        });
    }
}

fn badge_hasil(ui: &mut egui::Ui, judul: &str, hasil: &Option<Value>) {
    let Some(h) = hasil else { return };
    let siap = h.get("siap").and_then(|x| x.as_bool());
    let status = h
        .get("status")
        .and_then(|x| x.as_str())
        .unwrap_or("SELESAI");
    let pesan = h.get("pesan").and_then(|x| x.as_str()).unwrap_or("");
    let warna = match siap {
        Some(true) => egui::Color32::from_rgb(0x34, 0xD3, 0x99),
        Some(false) => egui::Color32::from_rgb(0xF8, 0x71, 0x71),
        None => UNGU_LEMBUT,
    };
    ui.add_space(6.0);
    ui.horizontal(|ui| {
        ui.label(egui::RichText::new(format!("{judul}: ")).size(11.5).strong());
        ui.label(egui::RichText::new(status).size(11.5).color(warna).strong());
        if !pesan.is_empty() {
            ui.label(egui::RichText::new(format!("— {pesan}")).size(11.5).color(egui::Color32::GRAY));
        }
    });
}

fn terapkan_tema(ctx: &egui::Context) {
    let mut v = egui::Visuals::dark();
    v.panel_fill = egui::Color32::from_rgb(0x12, 0x0C, 0x22);
    v.window_fill = egui::Color32::from_rgb(0x17, 0x10, 0x2B);
    v.widgets.noninteractive.bg_fill = v.panel_fill;
    v.widgets.inactive.bg_fill = egui::Color32::from_rgb(0x1F, 0x16, 0x3A);
    v.widgets.inactive.rounding = egui::Rounding::same(9.0);
    v.widgets.hovered.rounding = egui::Rounding::same(9.0);
    v.widgets.active.rounding = egui::Rounding::same(9.0);
    v.widgets.active.bg_fill = UNGU;
    v.selection.bg_fill = UNGU.linear_multiply(0.35);
    v.hyperlink_color = UNGU_LEMBUT;
    ctx.set_visuals(v);

    let mut gaya = (*ctx.style()).clone();
    gaya.spacing.item_spacing = egui::vec2(8.0, 8.0);
    gaya.text_styles
        .insert(egui::TextStyle::Body, egui::FontId::proportional(12.8));
    ctx.set_style(gaya);
}

/// Jam WIB (UTC+7) HH:MM:SS tanpa dependensi chrono.
fn jam_wib() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let s = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let lokal = (s + 7 * 3600) % 86400;
    format!("{:02}:{:02}:{:02}", lokal / 3600, (lokal % 3600) / 60, lokal % 60)
}

fn ikon_aplikasi() -> Option<egui::IconData> {
    let png = include_bytes!("../../src-tauri/icons/icon.png");
    let img = image::load_from_memory(png).ok()?.to_rgba8();
    let (w, h) = (img.width(), img.height());
    Some(egui::IconData {
        rgba: img.into_raw(),
        width: w,
        height: h,
    })
}

fn main() -> eframe::Result<()> {
    // Smoke-test versi (CI & pengguna) — tanpa membuka jendela.
    if std::env::args().any(|a| a == "--veri" || a == "-V") {
        println!("XyCloudStore-Agent {VERSI}");
        println!("runtime: Rust/egui-native (tanpa Tauri, tanpa WebView, tanpa terminal)");
        std::process::exit(0);
    }
    // Mode headless: -Jalankan (dipakai entri autostart registry).
    if std::env::args().any(|a| a == "-Jalankan" || a == "--jalankan") {
        let cfg = agent::muat_konfig();
        if cfg.kode.is_empty() {
            eprintln!("Kode unit belum diisi. Jalankan aplikasi UI dulu untuk konfigurasi.");
            std::process::exit(2);
        }
        let stop = Arc::new(AtomicBool::new(false));
        let log: Logger = Arc::new(|t| println!("[XYAGENT] {t}"));
        agent::jalankan_loop(cfg, log, stop);
        return Ok(());
    }

    let st = Keadaan::baru(agent::muat_konfig());
    let mut viewport = egui::ViewportBuilder::default()
        .with_inner_size([460.0, 680.0])
        .with_min_inner_size([400.0, 520.0]);
    if let Some(ikon) = ikon_aplikasi() {
        viewport = viewport.with_icon(ikon);
    }
    let opsi = eframe::NativeOptions {
        viewport,
        ..Default::default()
    };
    let st2 = st.clone();
    eframe::run_native(
        "XyCloudStore Agent",
        opsi,
        Box::new(move |cc| Ok(Box::new(Aplikasi::baru(cc, st2.clone())))),
    )
}
