import { test } from 'node:test';
import assert from 'node:assert/strict';
import { periksaTeks, periksaGabungan } from '../src/moderasi.js';

test('teks bersih lolos', () => {
  assert.equal(periksaTeks('Halo komunitas XyCloud, sewa PC lancar!').ok, true);
});

test('kata kasar ditolak', () => {
  const r = periksaTeks('Dasar anjing lu');
  assert.equal(r.ok, false);
  assert.equal(r.kode, 'KATA_KASAR');
});

test('terlalu banyak url', () => {
  const r = periksaTeks('a https://a.com b https://b.com c https://c.com d https://d.com', { maksUrl: 3 });
  assert.equal(r.ok, false);
  assert.equal(r.kode, 'SPAM_LINK');
});

test('domain curiga', () => {
  const r = periksaTeks('Klaim di https://bit.ly/xxx');
  assert.equal(r.ok, false);
  assert.equal(r.kode, 'LINK_CURIGA');
});

test('gabungan judul+isi', () => {
  const r = periksaGabungan('Judul bagus', 'Isi panjang cukup untuk forum tanpa masalah.');
  assert.equal(r.ok, true);
});
