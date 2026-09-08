package id.xycloud.stream;

import android.app.AlertDialog;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import com.limelight.Game;

/** Native full-screen renderer + XyCloud controls, within the same application ID/APK. */
public class XyGameActivity extends Game {
    private LinearLayout hud;
    private boolean connected;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        FrameLayout root=findViewById(android.R.id.content);
        hud=new LinearLayout(this);hud.setOrientation(LinearLayout.HORIZONTAL);
        hud.setPadding(8,4,8,4);hud.setBackgroundColor(0xCF263541);
        addButton("‹ Sesi",()->new AlertDialog.Builder(this).setTitle("Kembali ke sesi?")
            .setMessage("Video akan terputus. Waktu sewa tetap berjalan sampai sesi diakhiri di XyCloudStore.")
            .setNegativeButton("Batal",null).setPositiveButton("Kembali",(d,w)->finish()).show());
        addButton("Keyboard",this::toggleKeyboard);
        addButton("F1–F12",()->{
            String[] keys={"Esc","Tab","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"};
            new AlertDialog.Builder(this).setTitle("Tombol keyboard")
                .setItems(keys,(d,i)->xyTapKey(i==0?KeyEvent.KEYCODE_ESCAPE:i==1?KeyEvent.KEYCODE_TAB:KeyEvent.KEYCODE_F1+i-2)).show();
        });
        Button toggle=new Button(this);toggle.setText("☰");toggle.setTextColor(Color.WHITE);toggle.setBackgroundColor(0xCF475664);
        toggle.setOnClickListener(v->hud.setVisibility(hud.getVisibility()==View.VISIBLE?View.GONE:View.VISIBLE));
        FrameLayout.LayoutParams menu=new FrameLayout.LayoutParams(dp(42),dp(42),Gravity.TOP|Gravity.END);menu.setMargins(0,dp(6),dp(8),0);root.addView(toggle,menu);
        FrameLayout.LayoutParams params=new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,ViewGroup.LayoutParams.WRAP_CONTENT,Gravity.TOP|Gravity.CENTER_HORIZONTAL);params.topMargin=dp(6);root.addView(hud,params);
    }
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private void addButton(String label,Runnable action){Button b=new Button(this);b.setText(label);b.setTextSize(11);b.setTextColor(Color.WHITE);b.setBackgroundColor(Color.TRANSPARENT);b.setMinWidth(0);b.setMinimumWidth(0);b.setOnClickListener(v->action.run());hud.addView(b,new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,dp(40)));}
    @Override public void connectionStarted(){connected=true;super.connectionStarted();NativeStreaming.emit("connected","Video terhubung.");}
    @Override public void stageFailed(String stage,int ports,int code){NativeStreaming.emit("error","Tahap "+stage+" gagal ("+code+"). Periksa port, jaringan, dan encoder host.");super.stageFailed(stage,ports,code);}
    @Override public void connectionTerminated(int code){NativeStreaming.emit("disconnected","Koneksi video berakhir ("+code+").");super.connectionTerminated(code);}
    @Override protected void onDestroy(){super.onDestroy();NativeStreaming.emit("closed",connected?"Kembali ke sesi. Waktu sewa tetap berjalan.":"Layar streaming ditutup.");}
}
