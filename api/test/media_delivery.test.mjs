import test from 'node:test';
import assert from 'node:assert/strict';
import {samarkanGambar,imageVariant} from '../src/upload.js';
const env={CLOUDINARY_CLOUD:'owned',PUBLIC_URL:'https://api.example.invalid'};
test('Static delivery resizes/converts while keeping original image identity',()=>{
 const url=samarkanGambar(env,'https://res.cloudinary.com/owned/image/upload/v123/xycloudstore/paket/a.png','t');
 assert.equal(url,'https://api.example.invalid/img/t/v123/xycloudstore/paket/a.png?v=26');
 const image=imageVariant(env,new URL(url).pathname,'image/webp');
 assert.ok(image.url.includes('f_webp,q_78,c_limit,w_360,h_360/'));
 assert.ok(!image.url.includes('dpr_2'));
 assert.equal(imageVariant(env,new URL(url).pathname,'image/avif').format,'avif');
 assert.equal(samarkanGambar(env,url,'s'),'https://api.example.invalid/img/s/v123/xycloudstore/paket/a.png?v=26');
});
test('Animation is preserved and unsafe proxy targets are rejected',()=>{
 const animated=imageVariant(env,'/img/m/v1/xycloudstore/stiker/a.gif','image/avif',true);
 assert.equal(animated.format,'original');assert.equal(animated.url,'https://res.cloudinary.com/owned/image/upload/v1/xycloudstore/stiker/a.gif');
 assert.equal(imageVariant(env,'/img/m/../secret.png'),null);
 assert.equal(imageVariant(env,'/img/m/xycloudstore/%2e%2e/secret.png'),null);
 assert.equal(samarkanGambar(env,'https://res.cloudinary.com/other/image/upload/a.png'),'https://res.cloudinary.com/other/image/upload/a.png');
});
