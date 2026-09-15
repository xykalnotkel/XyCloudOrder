// Ikon & metadata exe Windows (dipakai saat build di windows-latest).
fn main() {
    #[cfg(windows)]
    {
        let mut res = winresource::WindowsResource::new();
        res.set_icon("../src-tauri/icons/icon.ico");
        res.set("ProductName", "XyCloudStore Agent");
        res.set("FileDescription", "Agen PC Host XyCloudStore (native egui)");
        res.set("ProductVersion", env!("CARGO_PKG_VERSION"));
        if let Err(e) = res.compile() {
            println!("cargo:warning=Gagal embed resource exe: {e}");
        }
    }
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../src-tauri/src/agent.rs");
}
