// ============================================================
//  Inti agen XyCloudStore (Rust, tanpa Python).
//  - Heartbeat ke server + proses perintah dari antrean
//  - Kontrol Sunshine lokal lewat API web (Basic auth)
//  - Setup otomatis engine (winget), autostart lewat registry
// ============================================================
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

pub const VERSI: &str = "1.2.0-rust";
const SUNSHINE_BAWAAN: &str = "https://127.0.0.1:47990";

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Konfig {
    pub kode: String,
    pub user: String,
    pub sandi: String,
    pub server: String,
}

pub type Logger = Arc<dyn Fn(&str) + Send + Sync>;

fn dir_data() -> PathBuf {
    let base = std::env::var("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::temp_dir());
    base.join("XyCloudStore").join("Agent")
}

fn jalur_config() -> PathBuf {
    dir_data().join("config.json")
}

pub fn muat_konfig() -> Konfig {
    if let Ok(teks) = std::fs::read_to_string(jalur_config()) {
        if let Ok(k) = serde_json::from_str::<Konfig>(&teks) {
            return k;
        }
    }
    Konfig { server: "https://api.xycloud.my.id".into(), ..Default::default() }
}

pub fn simpan_konfig(k: &Konfig) -> std::io::Result<()> {
    let dir = dir_data();
    std::fs::create_dir_all(&dir)?;
    let mut f = std::fs::File::create(jalur_config())?;
    serde_json::to_writer_pretty(&mut f, k)?;
    f.flush()?;
    Ok(())
}

fn klien() -> reqwest::blocking::Client {
    reqwest::blocking::Client::builder()
        .danger_accept_invalid_certs(true)
        .timeout(Duration::from_secs(10))
        .build()
        .expect("gagal membuat klien HTTP")
}

fn minta(
    url: &str,
    data: Option<Value>,
    metode: &str,
    header: Option<Vec<(String, String)>>,
) -> Result<(u16, Value), String> {
    let c = klien();
    let mut req = c.request(
        reqwest::Method::from_bytes(metode.as_bytes()).unwrap_or(reqwest::Method::GET),
        url,
    );
    req = req.header("User-Agent", format!("XyAgent/{VERSI}"));
    if let Some(h) = header {
        for (a, b) in h {
            req = req.header(a, b);
        }
    }
    if let Some(d) = data {
        req = req.json(&d);
    }
    let resp = req.send().map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let teks = resp.text().map_err(|e| e.to_string())?;
    if teks.trim().is_empty() {
        return Ok((status, Value::Object(Default::default())));
    }
    match serde_json::from_str::<Value>(&teks) {
        Ok(v) => Ok((status, v)),
        Err(_) => Ok((status, Value::String(teks))),
    }
}

fn header_basic(k: &Konfig) -> Vec<(String, String)> {
    vec![(
        "Authorization".into(),
        format!("Basic {}", base64ish::encode(&format!("{}:{}", k.user, k.sandi))),
    )]
}

/// Diagnosa API Sunshine (setara `--cek`).
pub fn periksa_sunshine(k: &Konfig) -> Value {
    if k.user.is_empty() || k.sandi.is_empty() {
        return json!({"siap": false, "status": "KREDENSIAL_KOSONG", "pesan": "Kredensial Sunshine belum diisi."});
    }
    let alamat = SUNSHINE_BAWAAN;
    match minta(&format!("{alamat}/api/apps"), None, "GET", Some(header_basic(k))) {
        Ok((status, j)) => {
            if (200..300).contains(&status) && j.get("apps").is_some() {
                json!({"siap": true, "status": "API_SIAP", "pesan": "API Sunshine merespons."})
            } else {
                json!({"siap": false, "status": "API_TIDAK_SESUAI", "pesan": format!("HTTP {status}: respons bukan daftar aplikasi Sunshine.")})
            }
        }
        Err(e) => json!({"siap": false, "status": "TIDAK_TERHUBUNG", "pesan": e}),
    }
}

fn spesifikasi() -> Value {
    let host = std::env::var("COMPUTERNAME").unwrap_or_else(|_| "PC-XY".into());
    let cpu = std::env::var("PROCESSOR_IDENTIFIER").unwrap_or_default();
    let mut spec = json!({
        "hostname": host,
        "os": "Windows",
        "cpu": cpu,
        "rust": true,
        "versi": VERSI,
    });
    if let Ok(out) = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"])
        .output()
    {
        let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if let Ok(v) = teks.parse::<f64>() {
            spec["ram_total_gb"] = json!(format!("{:.1}", v / 1e9));
        }
    }
    spec
}

fn kirim_balasan(k: &Konfig, id: &str, hasil: Value) {
    let url = format!("{}/api/agen/perintah/{}", k.server.trim_end_matches('/'), id);
    let _ = minta(&url, Some(hasil), "POST", Some(vec![("x-agen-kode".into(), k.kode.clone())]));
}

fn kerjakan(k: &Konfig, perintah: &Value, log: &Logger) {
    let jenis = perintah.get("jenis").and_then(|x| x.as_str()).unwrap_or("?");
    let muatan = perintah.get("muatan").cloned().unwrap_or_else(|| json!({}));
    let sesi_id = muatan.get("sesi_id").and_then(|x| x.as_str()).unwrap_or("-");
    let id_per = perintah.get("id").and_then(|x| x.as_str()).unwrap_or("");
    log(&format!("Perintah masuk: {jenis} ({sesi_id})"));

    let balas = |hasil: Value| {
        if !id_per.is_empty() {
            kirim_balasan(k, id_per, hasil);
        }
    };

    let sunshine = SUNSHINE_BAWAAN;
    match jenis {
        "mulai_sesi" => {
            let cek = periksa_sunshine(k);
            if cek.get("siap").and_then(|x| x.as_bool()).unwrap_or(false) {
                let _ = minta(&format!("{sunshine}/api/clients/unpair-all"), Some(json!({})), "POST", Some(header_basic(k)));
                let _ = minta(&format!("{sunshine}/api/apps/close"), Some(json!({})), "POST", Some(header_basic(k)));
                balas(json!({
                    "ok": true, "sesi_id": sesi_id, "status": "siap",
                    "host": std::env::var("COMPUTERNAME").unwrap_or_default(),
                    "catatan": "Sunshine siap menerima sambungan",
                }));
            } else {
                balas(json!({
                    "ok": false, "sesi_id": sesi_id, "status": "gagal",
                    "catatan": cek.get("pesan").cloned().unwrap_or_else(|| json!("Sunshine tidak siap")),
                }));
            }
        }
        "pasangkan" => {
            let pin = muatan.get("pin").and_then(|x| x.as_str()).unwrap_or("").to_string();
            let mut hasil = json!({"ok": false, "sesi_id": sesi_id, "status": "siap", "catatan": "Gagal pasangkan."});
            if let Ok((_, pending)) = minta(&format!("{sunshine}/api/pin"), None, "GET", Some(header_basic(k))) {
                let pasang = pending.get("pairings").and_then(|x| x.as_array()).cloned().unwrap_or_default();
                if let Some(p) = pasang.first() {
                    let id_p = p.get("id").cloned().unwrap_or_else(|| json!(""));
                    let body = json!({"pin": pin, "name": "XyCloudStore", "pairing_id": id_p});
                    if let Ok((status, _j)) = minta(&format!("{sunshine}/api/pin"), Some(body), "POST", Some(header_basic(k))) {
                        let oke = (200..300).contains(&status);
                        hasil = json!({
                            "ok": oke, "sesi_id": sesi_id, "status": "siap",
                            "catatan": if oke { "Perangkat berhasil dipasangkan" } else { "PIN ditolak, minta penyewa mencoba lagi" },
                        });
                    }
                } else {
                    hasil = json!({"ok": false, "sesi_id": sesi_id, "status": "siap",
                        "catatan": "Belum ada permintaan pairing dari HP."});
                }
            }
            balas(hasil);
        }
        "akhiri_sesi" => {
            let tutup = minta(&format!("{sunshine}/api/apps/close"), Some(json!({})), "POST", Some(header_basic(k)));
            let lepas = minta(&format!("{sunshine}/api/clients/unpair-all"), Some(json!({})), "POST", Some(header_basic(k)));
            let oke = tutup.is_ok() && lepas.is_ok();
            balas(json!({
                "ok": oke, "sesi_id": sesi_id,
                "status": if oke { "selesai" } else { "mengakhiri" },
                "catatan": if oke { "Sesi dibersihkan" } else { "Pembersihan belum berhasil; unit tetap dikunci" },
            }));
        }
        lainnya => balas(json!({"ok": false, "catatan": format!("Perintah {lainnya} tidak dikenal")})),
    }
}

fn detak(k: &Konfig, log: &Logger) {
    let cek = periksa_sunshine(k);
    let mut spec = spesifikasi();
    spec["sunshine"] = cek;
    let muatan = json!({
        "status": "online",
        "versi": VERSI,
        "spec": spec,
        "host": std::env::var("COMPUTERNAME").unwrap_or_default(),
    });
    let url = format!("{}/api/agen/heartbeat", k.server.trim_end_matches('/'));
    match minta(&url, Some(muatan), "POST", Some(vec![("x-agen-kode".into(), k.kode.clone())])) {
        Ok((status, j)) => {
            if !(200..300).contains(&status) {
                log("Server belum mengonfirmasi heartbeat (periksa server & kode unit).");
                return;
            }
            if let Some(data) = j.get("data").and_then(|x| x.as_object()) {
                if data.get("ok").and_then(|x| x.as_bool()).unwrap_or(false) {
                    if let Some(daftar) = data.get("perintah").and_then(|x| x.as_array()) {
                        let perintah = daftar.clone();
                        for p in perintah {
                            kerjakan(k, &p, log);
                        }
                    }
                }
            }
        }
        Err(e) => log(&format!("Gagal lapor ke server: {e}")),
    }
}

/// Putaran utama agen (dijalankan di thread sendiri).
pub fn jalankan_loop(k: Konfig, log: Logger, stop: Arc<AtomicBool>) {
    log(&format!("XyCloudStore Agen {VERSI} (Rust) mulai."));
    log(&format!("Server   : {}", k.server));
    log(&format!("Sunshine : {SUNSHINE_BAWAAN}"));
    let mut terakhir = Instant::now();
    while !stop.load(Ordering::Relaxed) {
        if terakhir.elapsed() >= Duration::from_secs(20) {
            terakhir = Instant::now();
            detak(&k, &log);
        }
        std::thread::sleep(Duration::from_secs(2));
    }
    log("Agen dihentikan.");
}

/// Pastikan Sunshine (engine) terpasang — auto unduh via winget kalau belum ada.
pub fn setup_otomatis(k: &Konfig, log: Logger) {
    let cek = periksa_sunshine(k);
    let ada = cek.get("siap").and_then(|x| x.as_bool()).unwrap_or(false)
        || service_sunshine().is_some();
    if ada {
        log("Sunshine (engine streaming) sudah ada di PC ini.");
    } else {
        log("Sunshine belum terpasang — mengunduh & memasang otomatis via winget…");
        match std::process::Command::new("winget")
            .args(["install", "--id", "LizardByte.Sunshine", "-e", "--silent",
                   "--accept-source-agreements", "--accept-package-agreements"])
            .output()
        {
            Ok(o) => {
                let pesan = String::from_utf8_lossy(&o.stdout).to_string()
                    + &String::from_utf8_lossy(&o.stderr);
                for baris in pesan.lines().filter(|x| !x.trim().is_empty()).take(8) {
                    log(baris);
                }
            }
            Err(e) => log(&format!("Gagal menjalankan winget: {e}")),
        }
        log("Buka https://127.0.0.1:47990 untuk membuat akun web-UI Sunshine sekali saja.");
    }
    log("Setup selesai. Klik 'Uji Koneksi' untuk memastikan Sunshine merespons.");
}

fn service_sunshine() -> Option<String> {
    let out = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command",
               "(Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue).Status"])
        .output()
        .ok()?;
    let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if teks.is_empty() { None } else { Some(teks) }
}

/// Autostart saat login lewat registry HKCU Run.
pub fn atur_autostart(aktif: bool, log: &Logger) {
    let kunci = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
    if aktif {
        let exe = std::env::current_exe().unwrap_or_default();
        let cmd = format!("\"{}\" -Jalankan", exe.display());
        let out = std::process::Command::new("reg")
            .args(["add", kunci, "/v", "XyCloudStoreAgent", "/t", "REG_SZ", "/d", &cmd, "/f"])
            .output();
        match out {
            Ok(o) if o.status.success() => log("Autostart didaftarkan (XyCloudStoreAgent @ login)."),
            Ok(o) => log(&format!("Gagal daftar autostart: {}", String::from_utf8_lossy(&o.stderr).trim())),
            Err(e) => log(&format!("Gagal daftar autostart: {e}")),
        }
    } else {
        let out = std::process::Command::new("reg")
            .args(["delete", kunci, "/v", "XyCloudStoreAgent", "/f"])
            .output();
        match out {
            Ok(_) => log("Autostart dihapus."),
            Err(e) => log(&format!("Gagal hapus autostart: {e}")),
        }
    }
}

pub fn autostart_aktif() -> bool {
    let kunci = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
    matches!(
        std::process::Command::new("reg")
            .args(["query", kunci, "/v", "XyCloudStoreAgent"])
            .output(),
        Ok(o) if o.status.success()
    )
}

mod base64ish {
    const TBL: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    pub fn encode(data: &str) -> String {
        let b = data.as_bytes();
        let mut out = String::with_capacity((b.len() + 2) / 3 * 4);
        for chunk in b.chunks(3) {
            let n = ((chunk[0] as u32) << 16)
                | ((if chunk.len() > 1 { chunk[1] } else { 0 }) as u32) << 8
                | (if chunk.len() > 2 { chunk[2] } else { 0 }) as u32;
            out.push(TBL[((n >> 18) & 63) as usize] as char);
            out.push(TBL[((n >> 12) & 63) as usize] as char);
            out.push(if chunk.len() > 1 { TBL[((n >> 6) & 63) as usize] as char } else { '=' });
            out.push(if chunk.len() > 2 { TBL[(n & 63) as usize] as char } else { '=' });
        }
        out
    }
}
