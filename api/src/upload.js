/**
 * ============================================================
 *  XyCloudStore - Unggah gambar (Cloudinary, tanda tangan server)
 * ============================================================
 *  Dipakai untuk gambar produk, bukti transfer, lampiran chat,
 *  dan foto pada ulasan. Kunci rahasia tidak pernah keluar dari Worker.
 */

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function sha1(teks) {
  return hex(await crypto.subtle.digest('SHA-1', new TextEncoder().encode(teks)));
}

/**
 * Unggah gambar. `dataUri` boleh berupa `data:image/png;base64,...`
 * atau URL http/https yang bisa diambil Cloudinary.
 */
export async function unggahGambar(env, { dataUri, folder = 'xycloudstore' }) {
  if (!env.CLOUDINARY_CLOUD || !env.CLOUDINARY_KEY || !env.CLOUDINARY_SECRET) {
    return { ok: false, alasan: 'Kredensial Cloudinary belum diatur' };
  }
  if (!dataUri) return { ok: false, alasan: 'Tidak ada berkas' };

  const timestamp = Math.floor(Date.now() / 1000);
  // parameter yang ikut ditandatangani harus urut abjad
  const tandaTangan = await sha1(`folder=${folder}&timestamp=${timestamp}${env.CLOUDINARY_SECRET}`);

  const form = new FormData();
  form.append('file', dataUri);
  form.append('api_key', env.CLOUDINARY_KEY);
  form.append('timestamp', String(timestamp));
  form.append('folder', folder);
  form.append('signature', tandaTangan);

  try {
    const r = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/upload`, {
      method: 'POST',
      body: form,
    });
    const j = await r.json();
    if (!r.ok || j.error) return { ok: false, alasan: j.error?.message || `HTTP ${r.status}` };
    try { await env.DB.prepare(`INSERT INTO media_assets(id,url,folder,format,width,height,bytes,animated) VALUES(?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET url=excluded.url,format=excluded.format,width=excluded.width,height=excluded.height,bytes=excluded.bytes,animated=excluded.animated`)
      .bind(j.public_id,j.secure_url,folder,j.format||null,j.width||null,j.height||null,j.bytes||null,j.pages>1||j.format==='gif'?1:0).run(); } catch (_) {}
    return { ok: true, url: j.secure_url, id: j.public_id, lebar: j.width, tinggi: j.height, format:j.format, bytes:j.bytes };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/**
 * Ubah URL Cloudinary menjadi tautan milik domain sendiri.
 *
 *   https://res.cloudinary.com/awan/image/upload/v123/xycloudstore/produk/abc.png
 *   -> https://api.xycloud.my.id/img/m/xycloudstore/produk/abc.png
 *
 * Selain menyembunyikan penyedia penyimpanan, jalur ini juga
 * memampatkan gambar otomatis lewat transformasi Cloudinary.
 */
export function samarkanGambar(env, url, ukuran = 'm') {
  if(!url||typeof url!=='string')return url;
  try{
    const u=new URL(url),base=env.PUBLIC_URL||'https://api.xycloud.my.id';
    let path;
    if(u.origin===new URL(base).origin&&u.pathname.startsWith('/img/')){
      const p=u.pathname.slice(5).split('/');if(UKURAN_GAMBAR[p[0]])p.shift();path=p.join('/');
    }else if(u.hostname==='res.cloudinary.com'){
      const prefix=`/${env.CLOUDINARY_CLOUD}/image/upload/`;
      if(!u.pathname.startsWith(prefix))return url;
      path=u.pathname.slice(prefix.length);
      const start=path.indexOf('xycloudstore/');if(start<0)return url;
      const before=path.slice(0,start).split('/').filter(Boolean);const version=before.find(v=>/^v\d+$/.test(v));
      path=(version?version+'/':'')+path.slice(start);
    }else return url;
    return `${base}/img/${UKURAN_GAMBAR[ukuran]?ukuran:'m'}/${path}?v=26`;
  }catch{return url;}
}

/** Pixel-sized variants, not doubled by device-pixel-ratio on the server. */
export const UKURAN_GAMBAR={s:160,t:360,m:800,l:1280,o:2048,blur:420};
export function imageVariant(env,path,accept='',animated=false){
  const chunks=path.replace(/^\/img\//,'').split('/');
  const size=UKURAN_GAMBAR[chunks[0]]?chunks.shift():'m';
  const id=chunks.join('/');
  if(!/^(?:v\d+\/)?xycloudstore\/[A-Za-z0-9_./%-]+$/.test(id)||id.split('/').some(x=>x==='..'||x==='.')||/%2e/i.test(id))return null;
  const format=animated?'original':accept.includes('image/avif')?'avif':'webp';
  const transform=animated?'':`${format==='avif'?'f_avif,q_62':'f_webp,q_78'},c_limit,w_${UKURAN_GAMBAR[size]},h_${UKURAN_GAMBAR[size]}${size==='blur'?',e_blur:1600':''}/`;
  return {format,size,id,url:`https://res.cloudinary.com/${env.CLOUDINARY_CLOUD}/image/upload/${transform}${id}`};
}

/** Edge + browser cache. Animated uploads retain original frames/transparency. */
export async function layaniGambar(env,jalur,req,ctx){
  if(!env.CLOUDINARY_CLOUD)return new Response('Media belum tersedia',{status:503});
  const accept=req?.headers.get('accept')||'';
  const first=imageVariant(env,jalur,accept,/\.(gif|webp)$/i.test(jalur));
  if(!first)return new Response('Not found',{status:404});
  const key=new URL(req.url);key.search='v=26&format='+(accept.includes('image/avif')?'avif':'webp');
  const cache=typeof caches!=='undefined'?caches.default:null;
  const cacheKey=new Request(key.toString(),{method:'GET'});
  const hit=cache?await cache.match(cacheKey):null;
  if(hit)return hit;
  let animated=/\.gif$/i.test(jalur);
  if(/\.webp$/i.test(jalur)){
    const id=first.id.replace(/^v\d+\//,'').replace(/\.[^.]+$/,'');
    try{const item=await env.DB.prepare('SELECT animated FROM media_assets WHERE id=?').bind(id).first();animated=item?!!item.animated:true;}catch{animated=true;}
  }
  const variant=imageVariant(env,jalur,accept,animated);
  const response=await fetch(variant.url,{headers:{Accept:animated?'image/webp,image/gif,image/*':`image/${variant.format}`},cf:{cacheTtl:604800,cacheEverything:true}});
  if(!response.ok)return new Response('Media tidak tersedia',{status:response.status===404?404:502});
  const headers=new Headers();
  headers.set('Content-Type',response.headers.get('Content-Type')||'image/'+variant.format);
  headers.set('Cache-Control','public, max-age=604800, immutable');headers.set('Vary','Accept');
  headers.set('X-Content-Type-Options','nosniff');headers.set('X-XY-Media',variant.format+':'+variant.size);
  headers.set('Access-Control-Allow-Origin','*');
  const result=new Response(response.body,{status:200,headers});
  if(cache){const save=cache.put(cacheKey,result.clone()).catch(()=>{});if(ctx)ctx.waitUntil(save);else await save;}
  return result;
}

/** Delete only expired CS uploads; never product/profile/other people's media. */
export async function hapusMediaChat(env, url) {
  try {
    const u=new URL(url);
    const prefix=`/${env.CLOUDINARY_CLOUD}/image/upload/`;
    if(u.hostname!=='res.cloudinary.com'||!u.pathname.startsWith(prefix))return true;
    const match=u.pathname.match(/\/(xycloudstore\/chat\/[^?]+)\.[a-zA-Z0-9]+$/);
    if(!match)return true;
    const publicId=decodeURIComponent(match[1]), timestamp=Math.floor(Date.now()/1000);
    const signature=await sha1(`invalidate=true&public_id=${publicId}&timestamp=${timestamp}${env.CLOUDINARY_SECRET}`);
    const form=new FormData();form.set('public_id',publicId);form.set('invalidate','true');form.set('timestamp',String(timestamp));form.set('signature',signature);form.set('api_key',env.CLOUDINARY_KEY);
    const r=await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/destroy`,{method:'POST',body:form});
    const j=await r.json();return r.ok&&['ok','not found'].includes(j.result);
  }catch{return false;}
}
