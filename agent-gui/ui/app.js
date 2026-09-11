/* XyCloudStore Agen — wizard UI (Tauri withGlobalTauri) */
const T = window.__TAURI__?.core;
async function panggil(nama, args = {}) {
  if (!T) throw new Error("Jalankan lewat XyCloudStore-Agent.exe (bukan browser biasa)");
  return T.invoke(nama, args);
}

const $ = (id) => document.getElementById(id);
const logBox = $("log");
let langkah = 1;
let engineSiap = false;

function tulis(teks, jenis = "") {
  const baris = document.createElement("div");
  if (jenis === "ok") baris.className = "ok-line";
  if (jenis === "err") baris.className = "err-line";
  const t = document.createElement("span");
  t.className = "t";
  t.textContent = new Date().toLocaleTimeString("id-ID", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  baris.appendChild(t);
  baris.appendChild(document.createTextNode(String(teks)));
  logBox.appendChild(baris);
  logBox.scrollTop = logBox.scrollHeight;
}

function setStat(id, teks, cls) {
  const el = $(id);
  if (!el) return;
  el.textContent = teks;
  el.className = "stat-v" + (cls ? " " + cls : "");
}

function perbaruiLencana(berjalan, warn = false) {
  const l = $("lencana");
  if (berjalan) {
    l.textContent = "AGEN AKTIF";
    l.className = "lencana on";
  } else if (warn) {
    l.textContent = "SETUP";
    l.className = "lencana warn";
  } else {
    l.textContent = "BERHENTI";
    l.className = "lencana off";
  }
}

function setLangkah(n) {
  langkah = n;
  document.querySelectorAll("[data-panel]").forEach((p) => {
    p.classList.toggle("sembunyi", Number(p.dataset.panel) !== n);
  });
  document.querySelectorAll(".step").forEach((s) => {
    const sn = Number(s.dataset.step);
    s.classList.toggle("aktif", sn === n);
    s.classList.toggle("done", sn < n);
  });
}

async function muatStatus() {
  try {
    const s = await panggil("status");
    $("kode").value = s.kode || "";
    $("server").value = s.server || "https://api.xycloud.my.id";
    $("user").value = s.user || "";
    $("auto").checked = !!s.autostart;
    if (s.user) $("sandi").placeholder = "•••••••• (tersimpan)";
    if (s.versi) $("versi-tag").textContent = `Agen PC Host · v${s.versi}`;
    perbaruiLencana(!!s.berjalan);
    $("status").innerHTML =
      `Unit     : <span class="${s.kode ? "ok" : "jelek"}">${s.kode || "(belum)"}</span>\n` +
      `Server   : ${s.server || "-"}\n` +
      `Sunshine : ${s.user ? s.user : "(auto)"}\n` +
      `Agen     : ${s.berjalan ? '<span class="ok">berjalan</span>' : '<span class="jelek">berhenti</span>'} · v${s.versi || "?"}\n` +
      `Autostart: ${s.autostart ? "ya" : "tidak"}`;

    if (s.sunshine) {
      terapkanHasilSunshine(s.sunshine);
    }
    // auto-route
    if (!s.kode) setLangkah(1);
    else if (!engineSiap && !s.berjalan) setLangkah(langkah === 1 ? 2 : langkah);
  } catch (e) {
    tulis("Gagal ambil status: " + e, "err");
  }
}

function terapkanHasilSunshine(hasil) {
  const status = (hasil && hasil.status) || "-";
  // siap bisa null (= belum diuji live)
  const siapRaw = hasil && hasil.siap;
  const siap = siapRaw === true;
  const belumUji = siapRaw === null || siapRaw === undefined;
  const svc = (hasil && hasil.service) || "-";
  if (siap) engineSiap = true;
  if (siapRaw === false && status !== "TERSIMPAN") engineSiap = false;

  if (siap) {
    setStat("st-sunshine", "terpasang", "ok");
    setStat("st-service", svc && svc !== "-" ? svc : "aktif", "ok");
    setStat("st-api", "API_SIAP", "ok");
  } else if (belumUji || status === "TERSIMPAN") {
    setStat("st-sunshine", "kredensial ada", "warn");
    setStat("st-service", svc !== "-" ? svc : "—", "");
    setStat("st-api", "belum diuji", "warn");
  } else if (status === "KREDENSIAL_KOSONG") {
    setStat("st-sunshine", "perlu setup", "warn");
    setStat("st-service", "—", "");
    setStat("st-api", status, "jelek");
  } else {
    setStat("st-sunshine", "periksa", "warn");
    setStat("st-service", svc !== "-" ? svc : "—", "");
    setStat("st-api", status, "jelek");
  }
  $("lanjut-3").disabled = !engineSiap;
  // izinkan lanjut juga kalau kredensial tersimpan (user bisa uji nanti)
  if (!engineSiap && (belumUji || status === "TERSIMPAN")) {
    $("lanjut-3").disabled = false;
  }
  if (siap) tulis("Sunshine API siap — boleh jalankan agen.", "ok");
}

async function simpanCfg({ lanjut = false } = {}) {
  const kode = $("kode").value.trim();
  if (!kode) {
    tulis("Kode unit wajib diisi.", "err");
    return false;
  }
  try {
    const hasil = await panggil("simpan", {
      kode,
      user: $("user").value.trim(),
      sandi: $("sandi").value === "••••••••" ? "" : $("sandi").value,
      server: $("server").value.trim() || "https://api.xycloud.my.id",
    });
    tulis(hasil, "ok");
    $("sandi").value = "";
    await muatStatus();
    if (lanjut) setLangkah(2);
    return true;
  } catch (e) {
    tulis("Gagal simpan: " + e, "err");
    return false;
  }
}

// --- events ---
$("simpan-lanjut").onclick = () => simpanCfg({ lanjut: true });

$("tempel").onclick = async () => {
  try {
    const t = await navigator.clipboard.readText();
    if (t) {
      $("kode").value = t.trim();
      tulis("Kode ditempel dari clipboard.");
    }
  } catch (e) {
    tulis("Clipboard tidak bisa dibaca — tempel manual (Ctrl+V).", "err");
  }
};

$("kembali-1").onclick = () => setLangkah(1);
$("kembali-2").onclick = () => setLangkah(2);
$("lanjut-3").onclick = () => setLangkah(3);

document.querySelectorAll(".step").forEach((s) => {
  s.onclick = () => setLangkah(Number(s.dataset.step));
});

$("setup").onclick = async () => {
  try {
    // simpan dulu bila user isi opsi lanjutan
    await simpanCfg({ lanjut: false });
    perbaruiLencana(false, true);
    tulis("Menjalankan auto-setup Sunshine (install + creds + service)…");
    setStat("st-sunshine", "setup…", "warn");
    setStat("st-api", "…", "warn");
    await panggil("setup_otomatis");
  } catch (e) {
    tulis("Gagal setup: " + e, "err");
  }
};

$("uji").onclick = async () => {
  try {
    tulis("Uji koneksi Sunshine…");
    await panggil("uji_cek");
  } catch (e) {
    tulis("Gagal uji: " + e, "err");
  }
};

$("mulai").onclick = async () => {
  try {
    await panggil("mulai");
    tulis("Agen dijalankan — heartbeat tiap 20 dtk.", "ok");
    await muatStatus();
  } catch (e) {
    tulis("Gagal mulai: " + e, "err");
  }
};

$("henti").onclick = async () => {
  try {
    await panggil("henti");
    tulis("Perintah henti dikirim…");
    setTimeout(muatStatus, 1200);
  } catch (e) {
    tulis("Gagal henti: " + e, "err");
  }
};

$("autostart").onclick = async () => {
  try {
    await panggil("autostart", { aktif: $("auto").checked });
    tulis($("auto").checked ? "Autostart diaktifkan." : "Autostart dimatikan.", "ok");
    await muatStatus();
  } catch (e) {
    tulis("Gagal autostart: " + e, "err");
  }
};

$("bersih-log").onclick = () => {
  logBox.innerHTML = "";
};

if (T) {
  T.listen("log", (e) => {
    const msg = String(e.payload ?? "");
    const jenis = /gagal|error|tolak|tidak/i.test(msg) ? "err" : /siap|berhasil|selesai|API_SIAP|tersimpan|aktif/i.test(msg) ? "ok" : "";
    tulis(msg, jenis);
  });
  T.listen("uji-selesai", (e) => {
    if (e?.payload) terapkanHasilSunshine(e.payload);
    muatStatus();
  });
  T.listen("setup-selesai", (e) => {
    if (e?.payload) terapkanHasilSunshine(e.payload);
    if (e?.payload?.siap) setLangkah(3);
    muatStatus();
  });
} else {
  tulis("Preview browser — fitur Tauri nonaktif. Pakai XyCloudStore-Agent.exe di Windows.", "err");
  setStat("st-sunshine", "preview", "warn");
  setStat("st-service", "—", "");
  setStat("st-api", "—", "");
}

muatStatus();
setInterval(() => {
  if (T) muatStatus().catch(() => {});
}, 15000);
