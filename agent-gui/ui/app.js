/* XyCloudStore Agen — wizard UI (Tauri withGlobalTauri) */
const CORE = window.__TAURI__?.core;
const EVENT = window.__TAURI__?.event;

async function panggil(nama, args = {}) {
  if (!CORE) throw new Error("Jalankan lewat XyCloudStore-Agent.exe (bukan browser biasa)");
  return CORE.invoke(nama, args);
}

async function dengar(nama, handler) {
  // Tauri 2: event di window.__TAURI__.event, bukan core
  if (EVENT?.listen) return EVENT.listen(nama, handler);
  if (CORE?.listen) return CORE.listen(nama, handler);
  throw new Error("tauri event API tidak tersedia");
}

const $ = (id) => document.getElementById(id);
const logBox = $("log");
let langkah = 1;
let engineSiap = false;
let setupJalan = false;

function tulis(teks, jenis = "") {
  const baris = document.createElement("div");
  if (jenis === "ok") baris.className = "ok-line";
  if (jenis === "err") baris.className = "err-line";
  const t = document.createElement("span");
  t.className = "t";
  t.textContent = new Date().toLocaleTimeString("id-ID", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
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

function setSetupBusy(on) {
  setupJalan = on;
  const b = $("setup");
  if (b) {
    b.disabled = on;
    b.textContent = on ? "Setup berjalan…" : "Pasang & kunci otomatis";
  }
  if ($("uji")) $("uji").disabled = on;
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
    if (!setupJalan) perbaruiLencana(!!s.berjalan);
    $("status").innerHTML =
      `Unit     : <span class="${s.kode ? "ok" : "jelek"}">${s.kode || "(belum)"}</span>\n` +
      `Server   : ${s.server || "-"}\n` +
      `Sunshine : ${s.user ? s.user : "(auto)"}\n` +
      `Agen     : ${s.berjalan ? '<span class="ok">berjalan</span>' : '<span class="jelek">berhenti</span>'} · v${s.versi || "?"}\n` +
      `Autostart: ${s.autostart ? "ya" : "tidak"}`;

    if (s.sunshine) terapkanHasilSunshine(s.sunshine, false);
    if (!s.kode) setLangkah(1);
    else if (!engineSiap && !s.berjalan && !setupJalan) setLangkah(langkah === 1 ? 2 : langkah);
  } catch (e) {
    tulis("Gagal ambil status: " + e, "err");
  }
}

function terapkanHasilSunshine(hasil, tulisSiap = true) {
  const status = (hasil && hasil.status) || "-";
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
  if (!engineSiap && (belumUji || status === "TERSIMPAN")) {
    $("lanjut-3").disabled = false;
  }
  if (siap && tulisSiap) tulis("Sunshine API siap — boleh jalankan agen.", "ok");
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
  if (setupJalan) return;
  try {
    await simpanCfg({ lanjut: false });
    setLangkah(2);
    perbaruiLencana(false, true);
    setSetupBusy(true);
    tulis("Menjalankan auto-setup Sunshine (winget → MSI · maks ~3 mnt)…");
    tulis("Log berikutnya muncul di sini. Jangan tutup jendela.");
    setStat("st-sunshine", "setup…", "warn");
    setStat("st-api", "…", "warn");
    // Safety: jika event setup-selesai hilang, lepas busy setelah 4 menit
    window.__setupTimer = setTimeout(() => {
      if (setupJalan) {
        setSetupBusy(false);
        tulis("Setup masih berjalan lama / log event hilang. Cek apakah Sunshine sudah terpasang, lalu Uji koneksi.", "err");
      }
    }, 240000);
    await panggil("setup_otomatis");
  } catch (e) {
    setSetupBusy(false);
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

(async function initEvents() {
  if (!CORE) {
    tulis("Preview browser — fitur Tauri nonaktif. Pakai XyCloudStore-Agent.exe di Windows.", "err");
    setStat("st-sunshine", "preview", "warn");
    return;
  }
  try {
    await dengar("log", (e) => {
      const msg = String(e?.payload ?? "");
      const jenis = /gagal|error|tolak|timeout|GAGAL/i.test(msg)
        ? "err"
        : /siap|berhasil|selesai|API_SIAP|tersimpan|aktif|SETUP OK|OK —/i.test(msg)
          ? "ok"
          : "";
      tulis(msg, jenis);
    });
    await dengar("uji-selesai", (e) => {
      if (e?.payload) terapkanHasilSunshine(e.payload);
      muatStatus();
    });
    await dengar("setup-selesai", (e) => {
      if (window.__setupTimer) clearTimeout(window.__setupTimer);
      setSetupBusy(false);
      if (e?.payload) terapkanHasilSunshine(e.payload);
      if (e?.payload?.siap) setLangkah(3);
      else setLangkah(2);
      muatStatus();
    });
    tulis("Siap. Tempel kode unit → Pasang & kunci otomatis.", "ok");
  } catch (e) {
    tulis("Gagal pasang listener log: " + e + " — log setup mungkin tidak tampil real-time.", "err");
  }
  muatStatus();
})();

setInterval(() => {
  if (CORE && !setupJalan) muatStatus().catch(() => {});
}, 15000);
