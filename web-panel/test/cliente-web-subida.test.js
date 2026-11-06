// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Subida del cliente base de extremo a extremo (WEB-PANEL): el cliente real (public/subida-cliente.js) contra las rutas HTTP reales
// del panel, con permisos, cabecera anti-CSRF, trozos con huella, red que falla, pausa y reanudación.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test, { after } from 'node:test';
import { createApp } from '../src/app.js';
import { createClienteWebStore } from '../src/clienteWeb.js';
import { uploadClient } from '../public/subida-cliente.js';
import { fakePool, listenTestApp, sessionCookieFor } from './helpers.js';

const temporaries = [];
after(() => { for (const directory of temporaries) fs.rmSync(directory, { recursive: true, force: true }); });

const mpq = (size, fill) => Buffer.concat([Buffer.from('MPQ\x1a', 'latin1'), Buffer.alloc(size - 4, fill)]);
const CLIENT = new Map([
  ['common.MPQ', mpq(100, 1)], ['expansion.MPQ', mpq(70, 2)], ['lichking.MPQ', mpq(65, 3)], ['patch.MPQ', mpq(40, 4)], ['esES/locale-esES.MPQ', mpq(33, 5)],
]);
const asFiles = (map = CLIENT) => [...map].map(([ruta, data]) => ({ ruta, tamano: data.length, handle: { getFile: async () => new Blob([data]) } }));

function makeStore() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cliente-web-http-'));
  temporaries.push(directory);
  fs.mkdirSync(path.join(directory, 'base'), { recursive: true });
  fs.mkdirSync(path.join(directory, 'play', 'datos'), { recursive: true });
  const calls = { regenerate: 0 };
  const store = createClienteWebStore({
    dataDirectory: path.join(directory, 'base'), root: path.join(directory, 'play'), log: () => {}, freeBytes: () => 50 * 1024 ** 3,
    regenerate: async () => { calls.regenerate += 1; },
  });
  return { store, directory, calls };
}

async function startApp(store, level) {
  const authDb = fakePool({ execute: async (sql) => (sql.includes('FROM account_access') ? [[{ gmlevel: level }]] : [[]]) });
  const app = createApp({ authDb, charactersDb: fakePool(), worldDb: fakePool(), panelDb: fakePool(), soap: { executeCommand: async () => '' }, clienteWeb: store });
  return listenTestApp(app);
}

const cookie = () => sessionCookieFor({ id: 7, username: 'ADMIN' });

function transport(base, { failFirstChunks = 0, stopAfter = Infinity, controller = null } = {}) {
  let sent = 0;
  let failures = failFirstChunks;
  const api = async (url, options = {}) => {
    const response = await fetch(`${base}${url}`, {
      method: options.method || 'GET', body: options.body,
      headers: { Cookie: cookie(), 'X-Panel-Request': '1', 'Content-Type': 'application/json' },
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) { const error = new Error(body.error || 'fallo'); error.status = response.status; throw error; }
    return body;
  };
  const sendChunk = async ({ ruta, desde, bytes, sha256, signal }) => {
    if (failures > 0) { failures -= 1; throw new TypeError('network error'); }
    if (sent >= stopAfter) controller?.abort();
    if (signal?.aborted) { const error = new Error('abortado'); error.name = 'AbortError'; throw error; }
    sent += 1;
    const response = await fetch(`${base}/api/cliente-web/subida/archivo?ruta=${encodeURIComponent(ruta)}&desde=${desde}`, {
      method: 'PUT', body: bytes, headers: { Cookie: cookie(), 'X-Panel-Request': '1', 'Content-Type': 'application/octet-stream', 'X-Chunk-Sha256': sha256 },
    });
    return { status: response.status, body: await response.json().catch(() => ({})) };
  };
  return { api, sendChunk, sent: () => sent };
}

test('el estado lo ve cualquier cuenta pero subir, activar y cancelar son sólo de administradores y exigen la cabecera', async (t) => {
  const { store } = makeStore();
  const player = await startApp(store, 0);
  const admin = await startApp(store, 3);
  t.after(() => { player.server.close(); admin.server.close(); });

  assert.equal((await fetch(`${player.base}/api/cliente-web/estado`)).status, 401);
  const asPlayer = await (await fetch(`${player.base}/api/cliente-web/estado`, { headers: { Cookie: cookie() } })).json();
  assert.deepEqual(asPlayer, { disponible: true, configurado: false, activo: false, esAdmin: false });
  const list = JSON.stringify({ archivos: [...CLIENT].map(([name, data]) => [name, data.length]) });
  const post = (base, headers) => fetch(`${base}/api/cliente-web/subida`, { method: 'POST', headers: { Cookie: cookie(), 'Content-Type': 'application/json', ...headers }, body: list });
  assert.equal((await post(player.base, { 'X-Panel-Request': '1' })).status, 403);
  assert.equal((await post(admin.base, {})).status, 403, 'sin cabecera anti-CSRF');
  assert.equal((await fetch(`${player.base}/api/cliente-web/activo`, { method: 'POST', headers: { Cookie: cookie(), 'X-Panel-Request': '1', 'Content-Type': 'application/json' }, body: '{"activo":true}' })).status, 403);
  const asAdmin = await (await fetch(`${admin.base}/api/cliente-web/estado`, { headers: { Cookie: cookie() } })).json();
  assert.equal(asAdmin.esAdmin, true);
  assert.equal(asAdmin.subida, null);
});

test('la subida completa por HTTP aguanta fallos de red, se pausa, se reanuda y termina con el cliente configurado', async (t) => {
  const { store, calls, directory } = makeStore();
  const admin = await startApp(store, 3);
  t.after(() => admin.server.close());

  // 1.ª tanda: dos envíos fallan por red (se reintentan solos) y se pausa tras 4 trozos
  const controller = new AbortController();
  const first = transport(admin.base, { failFirstChunks: 2, stopAfter: 4, controller });
  const progress = [];
  await assert.rejects(
    () => uploadClient({ files: asFiles(), api: first.api, sendChunk: first.sendChunk, signal: controller.signal, chunkBytes: 16, pause: async () => {}, onProgress: (p) => progress.push(p.recibido) }),
    (error) => error.name === 'AbortError',
  );
  const middle = await (await fetch(`${admin.base}/api/cliente-web/estado`, { headers: { Cookie: cookie() } })).json();
  assert.equal(middle.configurado, false);
  assert.equal(middle.subida.recibido, 64, '4 trozos de 16 bytes en el servidor');
  assert.deepEqual(progress.slice(0, 2), [0, 16]);

  // 2.ª tanda: mismo cliente, reanuda desde lo recibido (no se reenvía lo que ya está)
  const second = transport(admin.base);
  const seen = [];
  const done = await uploadClient({ files: asFiles(), api: second.api, sendChunk: second.sendChunk, chunkBytes: 16, pause: async () => {}, onProgress: (p) => seen.push(p) });
  assert.equal(seen[0].reanudada, true);
  assert.equal(seen[0].recibido, 64);
  assert.equal(second.sent(), 19, 'sólo los 19 trozos que faltaban, no los 4 que ya estaban');
  assert.equal(done.configurado, true);
  assert.deepEqual(done.base.idiomas, ['esES']);
  assert.equal(calls.regenerate, 1);
  for (const [name, data] of CLIENT) assert.equal(fs.readFileSync(path.join(directory, 'base', name)).equals(data), true, name);
});

test('activar y desactivar el cliente web desde la API', async (t) => {
  const { store } = makeStore();
  const admin = await startApp(store, 3);
  t.after(() => admin.server.close());
  const call = (body) => fetch(`${admin.base}/api/cliente-web/activo`, { method: 'POST', headers: { Cookie: cookie(), 'X-Panel-Request': '1', 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  assert.equal((await call({ activo: 'sí' })).status, 400);
  assert.equal((await call({ activo: true })).status, 409, 'sin cliente base no se puede activar');
  const net = transport(admin.base);
  await uploadClient({ files: asFiles(), api: net.api, sendChunk: net.sendChunk, chunkBytes: 64, pause: async () => {} });
  const off = await (await call({ activo: false })).json();
  assert.equal(off.activo, false);
  const estado = await (await fetch(`${admin.base}/api/cliente-web/estado`, { headers: { Cookie: cookie() } })).json();
  assert.equal(estado.activo, false);
  assert.equal(estado.interruptor, false);
  assert.equal((await (await call({ activo: true })).json()).activo, true);
});

test('un trozo con la huella cambiada se rechaza con 422 y el cliente lo reintenta', async (t) => {
  const { store } = makeStore();
  const admin = await startApp(store, 3);
  t.after(() => admin.server.close());
  const net = transport(admin.base);
  let corrupted = 0;
  const sendChunk = async (args) => {
    if (corrupted < 2) { corrupted += 1; return net.sendChunk({ ...args, sha256: '0'.repeat(64) }); }
    return net.sendChunk(args);
  };
  const done = await uploadClient({ files: asFiles(), api: net.api, sendChunk, chunkBytes: 64, pause: async () => {} });
  assert.equal(corrupted, 2);
  assert.equal(done.configurado, true);
});
