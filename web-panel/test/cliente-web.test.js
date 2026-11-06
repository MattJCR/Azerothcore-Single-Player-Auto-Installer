// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Cliente base del cliente web (WEB-PANEL, paso 0): validación de la lista, subida en trozos con huella y reanudación,
// confirmación con sustitución del cliente anterior, activación y permisos de las rutas.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createClienteWebStore, ClienteWebError } from '../src/clienteWeb.js';

const sha = (buffer) => createHash('sha256').update(buffer).digest('hex');
const mpq = (size, fill = 1) => Buffer.concat([Buffer.from('MPQ\x1a', 'latin1'), Buffer.alloc(size - 4, fill)]);

function fixture(overrides = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cliente-web-'));
  const dataDirectory = path.join(directory, 'base');
  const root = path.join(directory, 'play');
  fs.mkdirSync(dataDirectory, { recursive: true });
  fs.mkdirSync(path.join(root, 'datos'), { recursive: true });
  let regenerated = 0;
  const store = createClienteWebStore({
    dataDirectory, root, log: () => {}, regenerate: async () => { regenerated += 1; }, freeBytes: () => 10 * 1024 ** 3, ...overrides,
  });
  return { directory, dataDirectory, root, store, regenerated: () => regenerated, cleanup: () => fs.rmSync(directory, { recursive: true, force: true }) };
}

const CLIENT = [
  ['common.MPQ', 40], ['expansion.MPQ', 30], ['lichking.MPQ', 30], ['patch.MPQ', 20], ['esES/locale-esES.MPQ', 24],
];
const contents = new Map(CLIENT.map(([name, size], index) => [name, mpq(size, index + 1)]));

async function upload(store, list = CLIENT, chunk = 16) {
  await store.startUpload({ archivos: list.map(([ruta, tamano]) => [ruta, tamano]) });
  for (const [name] of list) {
    const data = contents.get(name);
    for (let from = 0; from < data.length; from += chunk) {
      const part = data.subarray(from, from + chunk);
      await store.receiveChunk({ ruta: name, desde: from, datos: part, sha256: sha(part) });
    }
  }
}

test('sin carpetas configuradas el cliente web no está disponible', () => {
  const store = createClienteWebStore({});
  assert.deepEqual(store.status({ admin: true }), { disponible: false, configurado: false, activo: false });
  assert.rejects(() => store.startUpload({ archivos: CLIENT }), (error) => error instanceof ClienteWebError && error.status === 503);
});

test('la lista se valida: cliente completo, nombres seguros, sin repetidos y con los reservados ignorados', async () => {
  const f = fixture();
  try {
    const rejects = (archivos, pattern) => assert.rejects(() => f.store.startUpload({ archivos }), pattern);
    await rejects([], /Falta la lista/);
    await rejects(CLIENT.slice(1), /faltan common\.mpq/i);
    await rejects(CLIENT.slice(0, 4), /locale/);
    await rejects([...CLIENT, ['../fuera.MPQ', 10]], /no válido/);
    await rejects([...CLIENT, ['esES/sub/otro.MPQ', 10]], /no válido/);
    await rejects([...CLIENT, ['frFR/locale-frFR.MPQ', 10]], /no válido/);
    await rejects([...CLIENT, ['notas.txt', 10]], /no válido/);
    await rejects([...CLIENT, ['COMMON.mpq', 10]], /repetido/);
    await rejects([...CLIENT.slice(0, 4).map(([n]) => [n, 0]), CLIENT[4]], /Tamaño no válido/);
    const result = await f.store.startUpload({ archivos: [...CLIENT, ['custom.MPQ', 5], ['esES/patch-esES-4.MPQ', 5]] });
    assert.deepEqual(result.ignorados, ['custom.MPQ', 'esES/patch-esES-4.MPQ']);
    assert.equal(result.sesion.archivos.length, 5);
  } finally { f.cleanup(); }
});

test('una subida completa deja el cliente configurado, regenera el manifiesto y no deja restos', async () => {
  const f = fixture();
  try {
    assert.equal(f.store.status().configurado, false);
    await upload(f.store);
    const done = await f.store.commit();
    assert.equal(done.configurado, true);
    assert.equal(done.activo, true);
    assert.deepEqual(done.base.idiomas, ['esES']);
    assert.equal(done.base.ficheros, 5);
    assert.equal(done.base.bytes, 144);
    assert.ok(done.base.subido);
    assert.equal(f.regenerated(), 1);
    assert.equal(fs.readFileSync(path.join(f.dataDirectory, 'esES', 'locale-esES.MPQ')).equals(contents.get('esES/locale-esES.MPQ')), true);
    assert.equal(fs.existsSync(path.join(f.dataDirectory, '.subida')), false);
    assert.equal(f.store.currentSession(), null);
  } finally { f.cleanup(); }
});

test('un trozo mal posicionado, con huella falsa o fuera de tamaño se rechaza y no altera lo recibido', async () => {
  const f = fixture();
  try {
    await f.store.startUpload({ archivos: CLIENT });
    const part = contents.get('common.MPQ').subarray(0, 16);
    await assert.rejects(() => f.store.receiveChunk({ ruta: 'common.MPQ', desde: 8, datos: part, sha256: sha(part) }), (e) => e.status === 409 && e.extra.recibido === 0);
    await assert.rejects(() => f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: part, sha256: sha(Buffer.from('otro')) }), (e) => e.status === 422);
    await assert.rejects(() => f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: part, sha256: 'x' }), /huella/);
    await assert.rejects(() => f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: Buffer.alloc(41), sha256: sha(Buffer.alloc(41)) }), /tamaño declarado/);
    await assert.rejects(() => f.store.receiveChunk({ ruta: 'otro.MPQ', desde: 0, datos: part, sha256: sha(part) }), (e) => e.status === 404);
    assert.equal(f.store.currentSession().recibido, 0);
    const ok = await f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: part, sha256: sha(part) });
    assert.equal(ok.recibido, 16);
  } finally { f.cleanup(); }
});

test('la subida se reanuda con la misma lista y exige reiniciar con otra distinta', async () => {
  const f = fixture();
  try {
    await f.store.startUpload({ archivos: CLIENT });
    const part = contents.get('common.MPQ').subarray(0, 16);
    await f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: part, sha256: sha(part) });
    const again = await f.store.startUpload({ archivos: CLIENT.map(([n, s]) => [n.toLowerCase() === 'common.mpq' ? n : n, s]) });
    assert.equal(again.reanudada, true);
    assert.equal(again.sesion.archivos.find((file) => file.ruta === 'common.MPQ').recibido, 16);
    const other = CLIENT.map(([n, s]) => [n, n === 'patch.MPQ' ? s + 1 : s]);
    await assert.rejects(() => f.store.startUpload({ archivos: other }), (e) => e.status === 409 && e.extra.requiereReiniciar === true);
    const restarted = await f.store.startUpload({ archivos: other, reiniciar: true });
    assert.equal(restarted.reanudada, false);
    assert.equal(restarted.sesion.recibido, 0);
  } finally { f.cleanup(); }
});

test('confirmar exige todos los datos y MPQ válidos', async () => {
  const f = fixture();
  try {
    await f.store.startUpload({ archivos: CLIENT });
    await assert.rejects(() => f.store.commit(), (e) => e.status === 409 && e.extra.incompletos.length === 5);
    for (const [name, size] of CLIENT) {
      const data = Buffer.alloc(size, 7);   // sin cabecera MPQ
      await f.store.receiveChunk({ ruta: name, desde: 0, datos: data.subarray(0, 16), sha256: sha(data.subarray(0, 16)) });
      await f.store.receiveChunk({ ruta: name, desde: 16, datos: data.subarray(16), sha256: sha(data.subarray(16)) });
    }
    await assert.rejects(() => f.store.commit(), (e) => e.status === 422);
    assert.equal(f.store.status().configurado, false);
  } finally { f.cleanup(); }
});

test('actualizar sustituye el cliente anterior y conserva los MPQ del reino; cancelar borra lo subido a medias', async () => {
  const f = fixture();
  try {
    await upload(f.store);
    await f.store.commit();
    fs.writeFileSync(path.join(f.dataDirectory, 'custom.MPQ'), mpq(8));
    fs.writeFileSync(path.join(f.dataDirectory, 'patch-2.MPQ'), mpq(8));
    await upload(f.store);
    await f.store.commit();
    assert.equal(fs.existsSync(path.join(f.dataDirectory, 'patch-2.MPQ')), false);   // no estaba en el cliente nuevo
    assert.equal(fs.existsSync(path.join(f.dataDirectory, 'custom.MPQ')), true);     // del reino: se conserva
    await f.store.startUpload({ archivos: CLIENT });
    const part = contents.get('common.MPQ').subarray(0, 16);
    await f.store.receiveChunk({ ruta: 'common.MPQ', desde: 0, datos: part, sha256: sha(part) });
    await f.store.cancel();
    assert.equal(f.store.currentSession(), null);
    assert.equal(fs.existsSync(path.join(f.dataDirectory, '.subida')), false);
    assert.equal(f.store.status().configurado, true);
  } finally { f.cleanup(); }
});

test('sin sitio para dos clientes hay que borrar el actual antes; con la casilla marcada se borra y se sube', async () => {
  let free = 5 * 1024 ** 3;
  const f = fixture({ freeBytes: () => free });
  try {
    await upload(f.store);
    await f.store.commit();
    free = 100 * 1024 ** 2;
    await assert.rejects(() => f.store.startUpload({ archivos: CLIENT }), (e) => e.status === 507);
    assert.equal(f.store.status().configurado, true);   // nada se tocó
    const before = f.regenerated();
    const started = await f.store.startUpload({ archivos: CLIENT, borrarAntes: true }).catch((error) => error);
    assert.equal(started.status, 507);                   // ni borrando el anterior cabe
    assert.equal(f.store.status().configurado, false);   // el anterior sí se borró, y no queda sesión a medias
    assert.equal(f.store.currentSession(), null);
    assert.ok(f.regenerated() > before);
    free = 5 * 1024 ** 3;
    await f.store.startUpload({ archivos: CLIENT, borrarAntes: true });
    assert.equal(f.store.currentSession().archivos.length, 5);
  } finally { f.cleanup(); }
});

test('activar y desactivar escribe la marca que lee nginx; sin cliente base no se puede activar', async () => {
  const f = fixture();
  try {
    assert.throws(() => f.store.setActive(true), (e) => e.status === 409);
    await upload(f.store);
    await f.store.commit();
    const off = f.store.setActive(false);
    assert.equal(off.activo, false);
    assert.equal(off.interruptor, false);
    assert.equal(fs.existsSync(path.join(f.root, 'desactivado')), true);
    assert.equal(f.store.status().activo, false);
    assert.equal(f.store.setActive(true).activo, true);
    assert.equal(fs.existsSync(path.join(f.root, 'desactivado')), false);
  } finally { f.cleanup(); }
});
