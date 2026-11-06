// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Subida del cliente base al servidor (WEB-PANEL, paso 0): cada MPQ se envía en trozos de 16 MiB, cada uno con su SHA-256, por
// HTTP y en orden. El servidor responde con lo que lleva recibido, así que cortar (pausa, red caída, cerrar la pestaña) y volver a
// elegir la misma carpeta continúa donde se quedó. La lógica no toca el DOM: el transporte (`api`, `sendChunk`) llega de fuera.

import { t } from './i18n.js';

export const CHUNK_BYTES = 16 * 1024 * 1024;
const MAX_ATTEMPTS = 6;

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function sha256Hex(bytes) {
  const digest = await globalThis.crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function abortError() {
  const error = new Error('Subida pausada');
  error.name = 'AbortError';
  return error;
}

// Sube `files` ([{ ruta, tamano, handle }], handle = FileSystemFileHandle) y confirma. `api(path, { method, body })` devuelve el JSON o lanza
// un Error con `status`; `sendChunk({ ruta, desde, bytes, sha256, signal })` devuelve { status, body } sin lanzar por códigos HTTP.
export async function uploadClient({ files, api, sendChunk, borrarAntes = false, reiniciar = false, signal, onProgress = () => {}, chunkBytes = CHUNK_BYTES, pause = wait }) {
  let started;
  try {
    started = await api('/api/cliente-web/subida', {
      method: 'POST',
      body: JSON.stringify({ archivos: files.map((file) => [file.ruta, file.tamano]), borrarAntes, reiniciar }),
    });
  } catch (error) {
    error.alIniciar = true;   // 409 aquí = hay otra subida a medias con ficheros distintos
    throw error;
  }
  const session = started.sesion;
  const received = new Map(session.archivos.map((file) => [file.ruta, file.recibido]));
  const total = session.total;
  const sum = () => [...received.values()].reduce((acc, value) => acc + value, 0);
  onProgress({ recibido: sum(), total, ruta: null, reanudada: Boolean(started.reanudada) });

  for (const wanted of session.archivos) {
    const local = files.find((file) => file.ruta === wanted.ruta);
    if (!local) throw new Error(t('Falta el fichero {name} en la carpeta elegida.', { name: wanted.ruta }));
    const file = await local.handle.getFile();
    if (file.size !== wanted.tamano) throw new Error(t('{name} ha cambiado de tamaño desde que se eligió la carpeta.', { name: wanted.ruta }));
    let position = received.get(wanted.ruta);
    while (position < wanted.tamano) {
      if (signal?.aborted) throw abortError();
      const bytes = new Uint8Array(await file.slice(position, Math.min(position + chunkBytes, wanted.tamano)).arrayBuffer());
      const sha256 = await sha256Hex(bytes);
      let attempt = 0;
      for (;;) {
        if (signal?.aborted) throw abortError();
        let response = null;
        try {
          response = await sendChunk({ ruta: wanted.ruta, desde: position, bytes, sha256, signal });
        } catch (error) {
          if (error.name === 'AbortError' || signal?.aborted) throw abortError();
          response = { status: 0, body: {} };   // red caída o corte: se reintenta
        }
        if (response.status >= 200 && response.status < 300) { position = response.body.recibido; break; }
        if (response.status === 409 && Number.isSafeInteger(response.body.recibido)) { position = response.body.recibido; break; }   // el servidor lleva otra posición: se vuelve a cortar desde ahí
        const retryable = response.status === 0 || response.status === 422 || response.status >= 500;
        attempt += 1;
        if (!retryable || attempt >= MAX_ATTEMPTS) throw new Error(response.body?.error || t('El servidor rechazó {name} (código {status}).', { name: wanted.ruta, status: response.status }));
        await pause(Math.min(500 * 2 ** attempt, 8000));
      }
      received.set(wanted.ruta, position);
      onProgress({ recibido: sum(), total, ruta: wanted.ruta });
    }
  }
  return api('/api/cliente-web/subida/confirmar', { method: 'POST' });
}
