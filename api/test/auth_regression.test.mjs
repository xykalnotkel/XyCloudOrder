import test from 'node:test';
import assert from 'node:assert/strict';
import {harness} from './harness.mjs';
test('Verifikasi ulang tanpa OTP dan password penanda sosial tidak menerbitkan token',async()=>{
 const h=await harness();
 try{
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES ('verified','V','v@example.invalid','test',1),('social','S','s@example.invalid','sosial:google',1)").run();
  const r=await h.call('/auth/verify','POST',{email:'v@example.invalid',kode:''});
  assert.equal(r.status,409);assert.ok(!JSON.stringify(r.json).includes('token'));
  const social=await h.call('/auth/login','POST',{email:'s@example.invalid',password:'sosial:google'});
  assert.equal(social.status,401);assert.ok(!JSON.stringify(social.json).includes('token'));
 }finally{await h.mf.dispose();}
});
