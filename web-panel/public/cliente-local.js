// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Cliente web local (WEB-LOCAL): la carpeta Data del cliente 3.3.5a de CADA usuario. Se elige y se guarda sólo en su navegador
// (IndexedDB, mismo origen que /play/): nada de esto sale del equipo ni se guarda en el servidor.
//
// El mismo registro lo lee /play/ (web-client/play/index.html, que lleva su propia copia mínima de leerConfig): base
// `azeroth-cliente-local`, almacén `config`, clave `clienteWeb`. Si cambias el formato, cambia también esa página.

export const DB_NAME = 'azeroth-cliente-local';
const STORE = 'config';
const KEY = 'clienteWeb';

// Nombres que son del servidor y que un fichero local del usuario nunca sustituye (el del servidor manda): se usan si el manifiesto
// del servidor aún no trae la columna de origen.
export const RESERVED_FALLBACK = ['custom.MPQ', 'wateralpha.MPQ', 'addons-web.MPQ', 'patch-esES-4.MPQ', 'patch-enUS-4.MPQ'];
export const LOCALES = ['esES', 'enUS'];

function openDb(indexedDB = globalThis.indexedDB) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function withStore(mode, action, indexedDB) {
  const db = await openDb(indexedDB);
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction(STORE, mode);
      const request = action(transaction.objectStore(STORE));
      transaction.oncomplete = () => resolve(request.result);
      transaction.onerror = () => reject(transaction.error);
      transaction.onabort = () => reject(transaction.error);
    });
  } finally {
    db.close();
  }
}

// { handle, nombre, activo, resumen, guardado } o null si no hay nada configurado.
export const leerConfig = (indexedDB) => withStore('readonly', (store) => store.get(KEY), indexedDB).then((value) => value || null);
export const guardarConfig = (config, indexedDB) => withStore('readwrite', (store) => store.put(config, KEY), indexedDB);
export const borrarConfig = (indexedDB) => withStore('readwrite', (store) => store.delete(KEY), indexedDB);

// ---------------------------------------------------------------- carpeta Data

async function childOrNull(directory, name, kind) {
  try { return kind === 'file' ? await directory.getFileHandle(name) : await directory.getDirectoryHandle(name); }
  catch (error) { if (error.name === 'NotFoundError' || error.name === 'TypeMismatchError') return null; throw error; }
}

// Acepta la carpeta de Wow.exe (y baja a su Data) o la propia Data. Devuelve { data, raiz } o null si no parece un cliente.
export async function findDataDirectory(picked) {
  for (const candidate of [picked, await childOrNull(picked, 'Data', 'directory')]) {
    if (!candidate) continue;
    if (await childOrNull(candidate, 'common.MPQ', 'file') || await childOrNull(candidate, 'patch.MPQ', 'file')) {
      return { data: candidate, raiz: candidate === picked ? null : picked };
    }
  }
  return null;
}

// Lista los .MPQ de Data y de sus subcarpetas de idioma: [{ path: 'esES/patch-esES-3.MPQ', size, handle }].
export async function listLocalMpq(dataDirectory) {
  const files = [];
  async function collect(directory, prefix) {
    for await (const [name, handle] of directory.entries()) {
      if (handle.kind === 'file' && /\.mpq$/i.test(name)) files.push({ path: `${prefix}${name}`, size: (await handle.getFile()).size, handle });
    }
  }
  await collect(dataDirectory, '');
  for (const locale of LOCALES) {
    const directory = await childOrNull(dataDirectory, locale, 'directory');
    if (directory) await collect(directory, `${locale}/`);
  }
  return files;
}

// ---------------------------------------------------------------- clasificación

// «ruta<TAB>tamaño<TAB>mtime[<TAB>origen]»; origen = «servidor» para los ficheros propios (sin la columna, todo es base).
export function parseManifest(text) {
  return String(text).split('\n').map((line) => line.replace(/\r$/, '')).filter((line) => line && !line.startsWith('#')).map((line) => {
    const [path, size, , origin] = line.split('\t');
    return { path, size: Number(size) || 0, origin: origin === 'servidor' ? 'servidor' : 'base' };
  });
}

// Los únicos MPQ de parche que abre el cliente (PatchFiles.cpp): Data\patch-?.MPQ y Data\<idioma>\patch-<idioma>-?.MPQ.
export function clientLoadsPatch(path) {
  return /^patch-[^./\\]\.mpq$/i.test(path) || /^(esES|enUS)\/patch-\1-[^./\\]\.mpq$/i.test(path);
}

// Reparte los ficheros según estén o no en la carpeta del usuario (reglas de WEB-LOCAL). NO se compara el contenido ni el tamaño: el cliente
// del usuario es otro y es normal que sus ficheros sean distintos de los del servidor (decisión de diseño del 04/11/2026).
//  * un fichero base que está en la carpeta se usa tal cual; sólo el que falta lo pone el servidor;
//  * lo que es del reino (custom.MPQ, parches propios...) viene siempre del servidor aunque exista uno local con ese nombre;
//  * un MPQ local que no está en el manifiesto es un custom del usuario: se usa si el cliente lo abre por su nombre.
export function classifyLocal(localFiles, manifest, reservedNames = RESERVED_FALLBACK) {
  const reserved = new Set([...reservedNames, ...manifest.filter((row) => row.origin === 'servidor').map((row) => row.path)].map((name) => name.toLowerCase()));
  const isReserved = (path) => reserved.has(path.toLowerCase()) || reserved.has(path.toLowerCase().split('/').pop());
  const baseByPath = new Map(manifest.filter((row) => row.origin === 'base' && !isReserved(row.path)).map((row) => [row.path.toLowerCase(), row]));
  const inManifest = new Set(manifest.map((row) => row.path.toLowerCase()));
  const result = { local: [], ausentes: [], reservados: [], custom: [], bytesLocal: 0, bytesServidor: 0 };
  const seen = new Set();
  for (const file of localFiles) {
    const key = file.path.toLowerCase();
    seen.add(key);
    if (isReserved(file.path)) {
      result.reservados.push(file);
    } else if (baseByPath.has(key)) {
      result.local.push({ ...file, ruta: baseByPath.get(key).path });
      result.bytesLocal += file.size;
    } else if (!inManifest.has(key)) {
      result.custom.push({ ...file, ruta: file.path, carga: clientLoadsPatch(file.path) });
    }
  }
  for (const [key, row] of baseByPath) if (!seen.has(key)) result.ausentes.push(row);
  result.bytesServidor = result.ausentes.reduce((sum, row) => sum + row.size, 0);
  return result;
}
