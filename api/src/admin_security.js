import { SecurityError, securityConfig, saveSecurityConfig, auditSecurity } from './security.js';
import { infoHapusAkun, bersihkanAkun } from './akun.js';

export function ownerProtected(env,u){return String(u?.email||'').toLowerCase()===String(env.EMAIL_ADMIN||'').toLowerCase();}
function owner(admin){if(admin?.peran!=='pemilik')throw new SecurityError('Hanya pemilik yang boleh melakukan tindakan ini.',403,'OWNER_ONLY');}
export async function adminSecurity(env,admin,path,req){
  owner(admin);
  if(path==='security'&&req.method==='GET'){
    const cfg=await securityConfig(env),day='email:'+new Date().toISOString().slice(0,10);
    const stats=await env.DB.prepare(`SELECT (SELECT COUNT(*) FROM security_devices) devices,
      (SELECT COUNT(*) FROM security_devices WHERE blocked=1) blocked,
      (SELECT COALESCE(SUM(count),0) FROM security_events WHERE datetime(last_seen)>=datetime('now','-1 day')) events,
      (SELECT jumlah FROM batas WHERE kunci=?) emails`).bind(day).first();
    return {config:cfg,stats:{...stats,emails:stats.emails||0},email_max:Number(env.EMAIL_BATAS_HARIAN)||100};
  }
  if(path==='security'&&req.method==='POST'){
    const cfg=await saveSecurityConfig(env,await req.json());await auditSecurity(env,'policy_changed',admin.id||'owner','Security settings updated');return {ok:true,config:cfg};
  }
  if(path==='security/events'&&req.method==='GET')return (await env.DB.prepare('SELECT * FROM security_events ORDER BY last_seen DESC LIMIT 150').all()).results;
  if(path==='audit'&&req.method==='GET')return (await env.DB.prepare('SELECT id,admin,peran,aksi,target,waktu FROM log_admin ORDER BY waktu DESC LIMIT 200').all()).results;
  if(path==='devices'&&req.method==='GET')return (await env.DB.prepare(`SELECT d.*,
    (SELECT COUNT(*) FROM security_device_users l JOIN users u ON u.id=l.user_id WHERE l.device_id=d.id AND u.deleted_at IS NULL) linked_accounts
    FROM security_devices d ORDER BY last_seen DESC LIMIT 200`).all()).results;
  if(path.startsWith('devices/')&&req.method==='POST'){
    const [,id,action]=path.split('/');if(!/^[a-f0-9]{64}$/.test(id))throw new SecurityError('ID perangkat tidak valid.',400);
    const b=await req.json();
    if(action==='block')await env.DB.prepare('UPDATE security_devices SET blocked=?,reason=? WHERE id=?').bind(b.blocked?1:0,String(b.reason||'Peninjauan keamanan').slice(0,200),id).run();
    else if(action==='reset'){
      if(b.konfirmasi!=='RESET')throw new SecurityError('Konfirmasi RESET diperlukan.',400);
      await env.DB.prepare('UPDATE security_devices SET registrations=0,reset_at=? WHERE id=?').bind(new Date().toISOString(),id).run();
    }else throw new SecurityError('Tindakan tidak dikenal.',404);
    await auditSecurity(env,'device_'+action,id,'Admin action');return {ok:true};
  }
  if(path.startsWith('devices/')&&req.method==='GET')return (await env.DB.prepare(`SELECT u.id,u.nama,u.email,u.deleted_at,l.signup,l.last_seen FROM security_device_users l JOIN users u ON u.id=l.user_id WHERE l.device_id=? ORDER BY l.last_seen DESC`).bind(path.split('/')[1]).all()).results;
  if(path.startsWith('users/')&&['trash','restore','permanent'].includes(path.split('/')[2])){
    const [,id,action]=path.split('/'),u=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();
    if(!u)throw new SecurityError('Akun tidak ditemukan.',404);
    if(ownerProtected(env,u))throw new SecurityError('Akun pemilik tidak boleh diblokir/dihapus melalui menu ini.',409,'OWNER_PROTECTED');
    const b=await req.json().catch(()=>({}));
    if(action==='restore'&&req.method==='POST'){
      await env.DB.prepare("UPDATE users SET deleted_at=NULL,diblokir=blocked_before_trash,session_version=session_version+1 WHERE id=? AND deleted_at IS NOT NULL").bind(id).run();
    }else if(action==='trash'&&req.method==='POST'){
      const info=await infoHapusAkun(env,u);if(!info.boleh_hapus)throw new SecurityError(info.penghalang.join(' '),409,'UNSETTLED_ACCOUNT');
      if(b.konfirmasi!=='HAPUS')throw new SecurityError('Konfirmasi HAPUS diperlukan.',400);
      await env.DB.prepare('UPDATE users SET deleted_at=?,blocked_before_trash=diblokir,diblokir=1,session_version=session_version+1 WHERE id=? AND deleted_at IS NULL').bind(new Date().toISOString(),id).run();
    }else if(action==='permanent'&&req.method==='DELETE'){
      if(!u.deleted_at)throw new SecurityError('Pindahkan akun ke Sampah terlebih dahulu.',409);
      if(b.konfirmasi!=='HAPUS PERMANEN'||String(b.email||'').trim().toLowerCase()!==u.email.toLowerCase())throw new SecurityError('Ketik email akun dan HAPUS PERMANEN dengan benar.',400);
      const info=await infoHapusAkun(env,u);if(!info.boleh_hapus)throw new SecurityError(info.penghalang.join(' '),409,'UNSETTLED_ACCOUNT');
      await bersihkanAkun(env,u);
    }else throw new SecurityError('Metode tindakan tidak didukung.',405);
    await auditSecurity(env,'user_'+action,id,'Admin '+admin.nama);return {ok:true};
  }
  return undefined;
}
