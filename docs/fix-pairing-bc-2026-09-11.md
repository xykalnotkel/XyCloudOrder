# Fix pairing RSA/BC (2026-09-11)

## Gejala
`STREAM_CONNECT` + `java.security.NoSuchAlgorithmException: no such algorithm: RSA for provider BC`

## Sebab
Android mendaftarkan BouncyCastle provider nama `BC` yang **dipotong**. Moonlight `AndroidCryptoProvider` memakai `KeyPairGenerator.getInstance("RSA", bcProvider)` / factory dengan provider BC lengkap dari dependency. Konflik nama provider → RSA tidak ditemukan.

## Perbaikan
1. `native/xy_stream/.../XyCrypto.java` — ganti BC Android dengan `org.bouncycastle.jce.provider.BouncyCastleProvider` (bcprov-jdk15on).
2. Dipanggil di `MainActivity`, `NativeStreaming.prepare`, `XyGameActivity`.
3. Patch `AndroidCryptoProvider` di `tools/siapkan_streaming.py` (static bootstrap).
4. Flutter `sesi_screen`: auto `resetPairing` + retry bila error BC/RSA.

## Uji
Install APK baru → Hubungkan PC. Agent harus sudah `mulai_sesi` OK (sudah). Pairing PIN otomatis lewat agen.
