package id.xycloud.stream;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.os.Build;
import android.provider.Settings;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Android owns notification sound/vibration settings; the UI never pretends to override user choices. */
public final class NotificationSettings {
    private final Activity activity;
    private final String[][] channels={{"xy_orders_v1","Pesanan dan saldo"},{"xy_cs_v1","Chat CS"},{"xy_forum_v1","Komunitas"},{"xy_promo_v1","Promo dan info"},{"xy_system_v1","Sistem"}};
    public NotificationSettings(Activity a){activity=a;}
    public void ensureChannels(){
        if(Build.VERSION.SDK_INT<26)return;
        NotificationManager manager=activity.getSystemService(NotificationManager.class);
        for(String[] item:channels){
            if(manager.getNotificationChannel(item[0])!=null)continue;
            NotificationChannel c=new NotificationChannel(item[0],item[1],NotificationManager.IMPORTANCE_DEFAULT);
            c.setDescription("Notifikasi "+item[1]+" dari XyCloudStore");c.enableVibration(true);
            c.setSound(Settings.System.DEFAULT_NOTIFICATION_URI,new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build());
            c.setLockscreenVisibility(android.app.Notification.VISIBILITY_PRIVATE);manager.createNotificationChannel(c);
        }
    }
    @SuppressWarnings("unchecked") public Object handle(String method,Object arguments){
        Map<String,Object> args=arguments instanceof Map?(Map<String,Object>)arguments:new HashMap<>();
        if(method.equals("notificationStatus")){
            ensureChannels();List<Map<String,Object>> out=new ArrayList<>();
            NotificationManager manager=(NotificationManager)activity.getSystemService(Activity.NOTIFICATION_SERVICE);
            boolean permission=Build.VERSION.SDK_INT<24||manager.areNotificationsEnabled();
            for(String[] item:channels){
                Map<String,Object> m=new HashMap<>();m.put("id",item[0]);m.put("name",item[1]);m.put("enabled",permission);m.put("sound","Diatur Android");
                if(Build.VERSION.SDK_INT>=26){NotificationChannel c=manager.getNotificationChannel(item[0]);
                    m.put("enabled",permission&&c.getImportance()!=NotificationManager.IMPORTANCE_NONE);m.put("vibration",c.shouldVibrate());
                    Ringtone ring=c.getSound()==null?null:RingtoneManager.getRingtone(activity,c.getSound());m.put("sound",ring==null?"Senyap":ring.getTitle(activity));}
                out.add(m);
            }
            Map<String,Object> result=new HashMap<>();result.put("enabled",permission);result.put("channels",out);return result;
        }
        if(method.equals("notificationSettings")){
            String id=String.valueOf(args.getOrDefault("channel",""));boolean valid=false;for(String[] c:channels)if(c[0].equals(id))valid=true;
            Intent i;
            if(Build.VERSION.SDK_INT>=26){i=new Intent(valid?Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS:Settings.ACTION_APP_NOTIFICATION_SETTINGS);i.putExtra(Settings.EXTRA_APP_PACKAGE,activity.getPackageName());if(valid)i.putExtra(Settings.EXTRA_CHANNEL_ID,id);}
            else{i=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:"+activity.getPackageName()));}
            activity.startActivity(i);return null;
        }
        if(method.equals("storageSettings")){activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:"+activity.getPackageName())));return null;}
        throw new IllegalArgumentException("Pengaturan tidak dikenal");
    }
}
