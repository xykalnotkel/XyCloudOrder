import {build} from 'esbuild';
import {Miniflare} from 'miniflare';
import {execFileSync} from 'node:child_process';
import {webcrypto} from 'node:crypto';
export async function harness(bindings={}){
 const code=await build({entryPoints:['src/index.js'],bundle:true,format:'esm',loader:{'.html':'text','.png':'binary'},write:false});
 const secret='local-tests-only-not-production';
 const mf=new Miniflare({modules:true,script:code.outputFiles[0].text,compatibilityDate:'2025-01-01',d1Databases:['DB'],durableObjects:{HUB:'RealtimeHub'},bindings:{JWT_SECRET:secret,ADMIN_KEY:'test-admin',EMAIL_ADMIN:'owner@example.invalid',...bindings}});
 const db=await mf.getD1Database('DB');
 const sql=JSON.parse(execFileSync('python3',['-c',"import json,sqlite3\na=[];b=''\nfor c in open('schema.sql').read():\n b+=c\n if c==';' and sqlite3.complete_statement(b):a.append(b);b=''\nprint(json.dumps(a))"],{encoding:'utf8'}));
 for(const q of sql)await db.prepare(q).run();
 const token=async(id,extra={})=>{const b=Buffer.from(JSON.stringify({v:2,sv:0,sub:id,exp:Date.now()+3600000,...extra})).toString('base64url');const k=await webcrypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);return b+'.'+Buffer.from(await webcrypto.subtle.sign('HMAC',k,new TextEncoder().encode(b))).toString('base64url')};
 const call=async(path,method='GET',body,headers={})=>{const r=await mf.dispatchFetch('https://api.example.invalid/api'+path,{method,headers:{'Content-Type':'application/json','CF-Connecting-IP':'192.0.2.123',...headers},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,headers:r.headers,json:await r.json()};};
 return {mf,db,token,call};
}
