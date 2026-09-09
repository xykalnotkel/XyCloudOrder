// ============================================================
//  XyCloudStore — Agen PC Host (Tauri v2 / Rust, tanpa Python)
// ============================================================
mod agent;

use agent::{Konfig, Logger};
use serde_json::json;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use tauri::{Emitter, State};

struct St {
    cfg: Mutex<Konfig>,
    stop: Arc<AtomicBool>,
    berjalan: Arc<Mutex<bool>>,
}

fn buat_log(app: tauri::AppHandle) -> Logger {
    Arc::new(move |teks: &str| {
        let _ = app.emit("log", teks.to_string());
    })
}

#[tauri::command]
fn simpan(kode: String, user: String, sandi: String, server: String, st: State<St>) -> Result<String, String> {
    let k = Konfig {
        kode: kode.trim().into(),
        user: if user.trim().is_empty() { "admin".into() } else { user.trim().into() },
        sandi: sandi.trim().into(),
        server: if server.trim().is_empty() { "https://api.xycloud.my.id".into() } else { server.trim().into() },
    };
    if k.kode.is_empty() {
        return Err("Kode unit wajib diisi.".into());
    }
    let sandi_lama = st.cfg.lock().unwrap().sandi.clone();
    let mut k = k;
    if k.sandi.is_empty() {
        k.sandi = sandi_lama;
    }
    agent::simpan_konfig(&k).map_err(|e| e.to_string())?;
    *st.cfg.lock().unwrap() = k.clone();
    Ok(format!("Pengaturan tersimpan untuk unit {}", k.kode))
}

#[tauri::command]
fn status(st: State<St>) -> serde_json::Value {
    let cfg = st.cfg.lock().unwrap().clone();
    let jalan = *st.berjalan.lock().unwrap();
    json!({
        "kode": cfg.kode,
        "server": cfg.server,
        "user": cfg.user,
        "autostart": agent::autostart_aktif(),
        "berjalan": jalan,
        "versi": agent::VERSI,
    })
}

#[tauri::command]
fn uji_cek(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    let cfg = st.cfg.lock().unwrap().clone();
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    let log = buat_log(app.clone());
    let cfg2 = cfg.clone();
    std::thread::spawn(move || {
        log("Menjalankan uji koneksi lokal (Sunshine API)…");
        let hasil = agent::periksa_sunshine(&cfg2);
        log(&format!(
            "Hasil: {} — {}",
            hasil.get("status").and_then(|x| x.as_str()).unwrap_or("-"),
            hasil.get("pesan").and_then(|x| x.as_str()).unwrap_or("")
        ));
        let _ = app.emit("uji-selesai", hasil);
    });
    Ok(())
}

#[tauri::command]
fn setup_otomatis(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    let cfg = st.cfg.lock().unwrap().clone();
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    let log = buat_log(app.clone());
    std::thread::spawn(move || {
        agent::setup_otomatis(&cfg, log);
    });
    Ok(())
}

#[tauri::command]
fn mulai(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    let cfg = st.cfg.lock().unwrap().clone();
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    {
        let mut b = st.berjalan.lock().unwrap();
        if *b {
            return Ok(());
        }
        *b = true;
    }
    st.stop.store(false, Ordering::Relaxed);
    let log = buat_log(app.clone());
    let stop = st.stop.clone();
    let berjalan = st.berjalan.clone();
    let cfg2 = cfg.clone();
    std::thread::spawn(move || {
        agent::jalankan_loop(cfg2, log, stop);
        *berjalan.lock().unwrap() = false;
    });
    Ok(())
}

#[tauri::command]
fn henti(st: State<St>) -> Result<(), String> {
    st.stop.store(true, Ordering::Relaxed);
    Ok(())
}

#[tauri::command]
fn autostart(aktif: bool, app: tauri::AppHandle) -> Result<(), String> {
    let log = buat_log(app);
    agent::atur_autostart(aktif, &log);
    Ok(())
}

fn main() {
    // verifikasi versi (smoke-test CI & pengguna)
    if std::env::args().any(|a| a == "--veri" || a == "-V") {
        println!("XyCloudStore-Agent {}", agent::VERSI);
        println!("runtime: Rust/Tauri (tanpa Python)");
        std::process::exit(0);
    }
    // mode headless: -Jalankan (dipakai autostart/penjadwal)
    let arg_jalankan = std::env::args().any(|a| a == "-Jalankan" || a == "--jalankan");
    if arg_jalankan {
        let cfg = agent::muat_konfig();
        if cfg.kode.is_empty() {
            eprintln!("Kode unit belum diisi. Jalankan aplikasi UI dulu untuk konfigurasi.");
            std::process::exit(2);
        }
        let stop = Arc::new(AtomicBool::new(false));
        let log: Logger = Arc::new(|t| println!("[XYAGENT] {t}"));
        agent::jalankan_loop(cfg, log, stop);
        return;
    }

    let cfg = agent::muat_konfig();
    tauri::Builder::default()
        .manage(St {
            cfg: Mutex::new(cfg),
            stop: Arc::new(AtomicBool::new(false)),
            berjalan: Arc::new(Mutex::new(false)),
        })
        .invoke_handler(tauri::generate_handler![
            simpan, status, uji_cek, setup_otomatis, mulai, henti, autostart
        ])
        .setup(|_app| Ok(()))
        .run(tauri::generate_context!())
        .expect("gagal menjalankan aplikasi XyCloudStore Agent");
}
