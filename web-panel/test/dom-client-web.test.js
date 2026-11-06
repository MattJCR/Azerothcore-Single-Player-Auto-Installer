// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// WEB-PANEL: la pantalla «Cliente web» según quién la mira y cómo está el servidor: asistente para el administrador sin cliente base,
// tres pasos cuando ya lo hay, paso 0 de sólo lectura para jugadores, y «Jugar en el navegador» sólo con el cliente base activo.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { mountApp, flush } from './dom-helpers.js';

let estado;
let build = true;

const { shared, document } = await mountApp({
  fetchHandler: (url) => {
    if (url.endsWith('/api/me')) return { status: 401, body: {} };
    if (url.endsWith('/api/players')) return { status: 200, body: { players: [], updatedAt: new Date().toISOString() } };
    if (url.endsWith('/api/server/status')) return { status: 200, body: { state: 'online' } };
    if (url.endsWith('/api/cliente-web/estado')) return { status: 200, body: estado };
    if (url.endsWith('/play/build.json')) return { status: build ? 200 : 404, body: {} };
    return { status: 404, body: {} };
  },
});

after(() => { shared.stopRefreshPolling(); shared.stopServerStatusPolling(); });

const hidden = (selector) => document.querySelector(selector).classList.contains('hidden');
const text = (selector) => document.querySelector(selector).textContent.replace(/\s+/g, ' ').trim();

async function open(user, state) {
  estado = state;
  shared.showApp(user);
  await flush(6);
  shared.showView('client-web');
  await flush(6);
}

const ADMIN = { username: 'ADMIN', gmlevel: 3, isGm: true };
const BASE = { ficheros: 35, bytes: 38 * 1024 ** 3, idiomas: ['esES', 'enUS'], subido: '2026-11-04T12:00:00Z' };

test('sin cliente base el administrador ve el asistente y el menú no ofrece jugar', async () => {
  await open(ADMIN, { disponible: true, configurado: false, activo: false, esAdmin: true, base: null, interruptor: true, subida: null, libre: 1e12 });
  assert.equal(hidden('#cw-wizard'), false);
  assert.equal(hidden('#cw-steps'), true);
  assert.equal(document.querySelector('#cw-up-start').disabled, true, 'hasta elegir carpeta no se puede subir');
  assert.equal(hidden('#cw-up-wipe-row'), true, 'sin cliente anterior no hay nada que borrar');
  assert.equal(hidden('#play-nav'), true);
  assert.equal(document.querySelector('.nav-section-label + #play-nav') !== null, true, '«Jugar en el navegador» es el primero de «Tu experiencia»');
});

test('con cliente base activo el administrador ve los tres pasos, el resumen del base y el menú ofrece jugar', async () => {
  await open(ADMIN, { disponible: true, configurado: true, activo: true, esAdmin: true, base: BASE, interruptor: true, subida: null, libre: 1e12 });
  assert.equal(hidden('#cw-wizard'), true);
  assert.equal(hidden('#cw-steps'), false);
  assert.match(text('#cw-s0-pill'), /Listo/);
  assert.match(text('#cw-s0-title'), /esES \+ enUS/);
  assert.match(text('#cw-s0-detail'), /35/);
  assert.equal(document.querySelector('#cw-s0-active').checked, true);
  assert.equal(hidden('#cw-s0-update'), false);
  assert.equal(document.querySelector('#cw-choose-folder').disabled, false);
  assert.equal(hidden('#play-nav'), false);
});

test('Actualizar cliente base abre el asistente con la opción de borrar el actual y la salida «Volver»', async () => {
  document.querySelector('#cw-s0-update').click();
  await flush(2);
  assert.equal(hidden('#cw-wizard'), false);
  assert.equal(hidden('#cw-up-wipe-row'), false);
  assert.equal(hidden('#cw-up-back'), false);
  document.querySelector('#cw-up-back').click();
  await flush(2);
  assert.equal(hidden('#cw-steps'), false);
});

test('una subida a medias en el servidor reabre el asistente y pide elegir la misma carpeta', async () => {
  await open(ADMIN, {
    disponible: true, configurado: false, activo: false, esAdmin: true, base: null, interruptor: true, libre: 1e12,
    subida: { id: 'x', total: 1000, recibido: 400, archivos: [] },
  });
  assert.equal(hidden('#cw-wizard'), false);
  assert.match(text('#cw-up-name'), /a medias/);
  assert.equal(hidden('#cw-up-cancel'), false);
  assert.equal(document.querySelector('#cw-up-bar').getAttribute('aria-valuenow'), '40');
});

test('un jugador ve el paso 0 sólo como estado, sin acciones de administrador', async () => {
  await open({ username: 'JUGADOR', gmlevel: 0, isGm: false }, { disponible: true, configurado: true, activo: true, esAdmin: false });
  assert.equal(hidden('#cw-steps'), false);
  assert.equal(hidden('#cw-wizard'), true);
  for (const element of document.querySelectorAll('#client-web-view .cw-admin-only')) assert.equal(element.classList.contains('hidden'), true);
  assert.match(text('#cw-s0-pill'), /Listo/);
  assert.equal(hidden('#play-nav'), false);
});

test('un jugador con el servidor sin preparar ve el aviso y los pasos 1 y 2 bloqueados', async () => {
  await open({ username: 'JUGADOR', gmlevel: 0, isGm: false }, { disponible: true, configurado: false, activo: false, esAdmin: false });
  assert.equal(hidden('#cw-wizard'), true);
  assert.equal(hidden('#cw-s0-waiting'), false);
  assert.equal(document.querySelector('#cw-step1').classList.contains('locked'), true);
  assert.equal(document.querySelector('#cw-choose-folder').disabled, true);
  assert.equal(hidden('#play-nav'), true);
});

test('con el cliente base desactivado, o sin el build desplegado, el menú no ofrece jugar', async () => {
  await open(ADMIN, { disponible: true, configurado: true, activo: false, esAdmin: true, base: BASE, interruptor: false, subida: null, libre: 1e12 });
  assert.match(text('#cw-s0-pill'), /Desactivado/);
  assert.equal(document.querySelector('#cw-s0-active').checked, false);
  assert.equal(hidden('#play-nav'), true);
  build = false;
  await open(ADMIN, { disponible: true, configurado: true, activo: true, esAdmin: true, base: BASE, interruptor: true, subida: null, libre: 1e12 });
  assert.equal(hidden('#play-nav'), true);
  build = true;
});

test('sin cliente web instalado en el servidor sólo se ve el aviso', async () => {
  await open(ADMIN, { disponible: false, configurado: false, activo: false, esAdmin: true });
  assert.equal(hidden('#cw-unavailable'), false);
  assert.equal(hidden('#cw-wizard'), true);
  assert.equal(hidden('#cw-steps'), true);
});
