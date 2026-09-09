/* XyCloudStore Agen — frontend Tauri (withGlobalTauri) */
const T = window.__TAURI__?.core;
async function panggil(nama, args = {}) {
  if (!T) throw new Error("tauri core tidak tersedia");
  return T.invoke(nama, args);
}

const $ = (id) => document.getElementById(id);
const logBox = $("log");

function tulis(teks) {
  const baris = document.createElement("div");
  const t = document.createElement("span");
  t.className = "t";
  t.textContent = new Date().toLocaleTimeString("id-ID");
  baris.appendChild(t);
  baris.appendChild(document.createTextNode(teks));
  logBox.appendChild(baris);
  logBox.scrollTop = logBox.scrollHeight;
}

async function muatStatus() {
  try {
    const s = await panggil("status");
    $("kode").value = s.kode || "";
    $("server").value = s.server || "";
    $("user").value = s.user || "";
    $("auto").checked = !!s.autostart;
    if (s.kode) $("sandi").value = "••••••••";
    perbaruiLencana(s.berjalan);
    $("status").innerHTML =
      `Unit&nbsp;&nbsp;&nbsp;: <span class="${s.kode ? "ok" : "jelek"}">${s.kode || "(belum diisi)"}</span>\n` +
      `Server&nbsp;&nbsp;: ${s.server}\n` +
      `Agen&nbsp;&nbsp;&nbsp;: ${s.berjalan ? '<span class="ok">berjalan</span>' : '<span class="jelek">berhenti</span>'} · v${s.versi}`;
    if (s.autostart) tulis("Autostart aktif saat Windows menyala.");
  } catch (e) {
    tulis("Gagal ambil status: " + e);
  }
}

function perbaruiLencana(berjalan) {
  const l = $("lencana");
  if (berjalan) {
    l.textContent = "AGEN AKTIF";
    l.className = "lencana on";
  } else {
    l.textContent = "BERHENTI";
    l.className = "lencana off";
  }
}

$("simpan").onclick = async () => {
  try {
    const hasil = await panggil("simpan", {
      kode: $("kode").value,
      user: $("user").value,
      sandi: $("sandi").value === "••••••••" ? "" : $("sandi").value,
      server: $("server").value,
    });
    tulis(hasil);
    await muatStatus();
  } catch (e) {
    tulis("Gagal simpan: " + e);
  }
};

$("uji").onclick = () => panggil("uji_cek").catch((e) => tulis("Gagal: " + e));
$("setup").onclick = () => panggil("setup_otomatis").catch((e) => tulis("Gagal: " + e));

$("mulai").onclick = async () => {
  try {
    await panggil("mulai");
    tulis("Agen mulai dijalankan (heartbeat tiap 20 dtk).");
    await muatStatus();
  } catch (e) {
    tulis("Gagal mulai: " + e);
  }
};

$("henti").onclick = async () => {
  try {
    await panggil("henti");
    tulis("Perintah henti dikirim…");
    setTimeout(muatStatus, 1200);
  } catch (e) {
    tulis("Gagal henti: " + e);
  }
};

$("autostart").onclick = async () => {
  try {
    await panggil("autostart", { aktif: $("auto").checked });
    await muatStatus();
  } catch (e) {
    tulis("Gagal autostart: " + e);
  }
};

if (T) {
  T.listen("log", (e) => tulis(String(e.payload ?? "")));
  T.listen("uji-selesai", () => muatStatus());
} else {
  tulis("Menjalankan di browser (tanpa Tauri) — hanya tampilan.");
}

muatStatus();
