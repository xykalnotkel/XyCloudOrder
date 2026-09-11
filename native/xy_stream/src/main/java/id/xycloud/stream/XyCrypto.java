package id.xycloud.stream;

import android.util.Log;

import org.bouncycastle.jce.provider.BouncyCastleProvider;

import java.security.Provider;
import java.security.Security;

/**
 * Android mendaftarkan BouncyCastle "BC" yang dipangkas (tanpa RSA penuh).
 * Moonlight/Sunshine pairing butuh BC lengkap dari dependency app.
 * Ganti provider sistem dengan bcprov yang di-bundle sebelum KeyPair/RSA dipanggil.
 */
public final class XyCrypto {
    private static final String TAG = "XyCrypto";
    private static volatile boolean ready;

    private XyCrypto() {}

    public static synchronized void ensure() {
        if (ready) return;
        try {
            final Provider existing = Security.getProvider(BouncyCastleProvider.PROVIDER_NAME);
            if (existing == null) {
                Security.insertProviderAt(new BouncyCastleProvider(), 1);
                Log.i(TAG, "BC provider dipasang (baru)");
            } else if (!existing.getClass().equals(BouncyCastleProvider.class)) {
                // Android BC (com.android.org.bouncycastle…) — ganti dengan bcprov app
                Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME);
                Security.insertProviderAt(new BouncyCastleProvider(), 1);
                Log.i(TAG, "BC provider Android diganti → bcprov app " + BouncyCastleProvider.class.getName());
            } else {
                Log.i(TAG, "BC provider app sudah aktif");
            }
            // Smoke: pastikan RSA tersedia lewat nama BC
            java.security.KeyPairGenerator.getInstance("RSA", BouncyCastleProvider.PROVIDER_NAME);
            ready = true;
        } catch (Throwable t) {
            Log.e(TAG, "Gagal menyiapkan BC provider: " + t);
            // Coba sekali lagi force insert di posisi 1
            try {
                Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME);
                Security.insertProviderAt(new BouncyCastleProvider(), 1);
                java.security.KeyPairGenerator.getInstance("RSA", new BouncyCastleProvider());
                ready = true;
                Log.i(TAG, "BC provider force-insert OK");
            } catch (Throwable t2) {
                Log.e(TAG, "BC tetap gagal: " + t2);
            }
        }
    }
}
