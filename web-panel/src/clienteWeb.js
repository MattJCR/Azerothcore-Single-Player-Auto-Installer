// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
import { spawn } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

// Cliente base del cliente web (/play/): los .MPQ del cliente 3.3.5a que el servidor ofrece a quien no tiene el suyo (WEB-PANEL).
// Lo sube un administrador desde el navegador por HTTP, en trozos con huella y con reanudación; el servidor los deja en
// WEB_CLIENT_DATA_DIR (la misma carpeta que lee web-client/deploy.sh), regenera con generar-manifiesto.py los enlaces y el
// manifiesto de WEB_CLIENT_ROOT/datos y guarda un resumen. «Activo» es la ausencia del fichero WEB_CLIENT_ROOT/desactivado, que
// nginx comprueba (web-client/nginx-play.conf): sin él, /play/ responde 503.

export class ClienteWebError extends Error {
  constructor(message, status = 400, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

// Mismos nombres que RESERVADOS de web-client/generar-manifiesto.py: los pone el servidor, nunca se suben.
export const RESERVED = new Set(['custom.mpq', 'wateralpha.mpq', 'addons-web.mpq', 'patch-eses-4.mpq', 'patch-enus-4.mpq']);
export const LOCALES = ['esES', 'enUS'];
export const REQUIRED_ROOT = ['common.mpq', 'expansion.mpq', 'lichking.mpq', 'patch.mpq'];

export const LIMITS = Object.freeze({
  files: 100,
  fileBytes: 8 * 1024 ** 3,
  totalBytes: 200 * 1024 ** 3,
  chunkBytes: 16 * 1024 * 1024,
  marginBytes: 512 * 1024 ** 2,
});

const PATH_RULE = /^(?:(esES|enUS)\/)?[A-Za-z0-9_.-]{1,80}\.mpq$/i;
const SHA = /^[0-9a-f]{64}$/;
const MPQ_MAGIC = [Buffer.from('MPQ\x1a', 'latin1'), Buffer.from('MPQ\x1b', 'latin1')];

const isReserved = (relative) => RESERVED.has(path.posix.basename(relative).toLowerCase());
const nowIso = () => new Date().toISOString();

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; }
}

function writeJsonAtomic(file, value) {
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(temporary, file);
}

function runManifestScript({ python, script, dataDirectory, datosDirectory }) {
  return new Promise((resolve, reject) => {
    const child = spawn(python, [script, '--permitir-vacio', dataDirectory, datosDirectory], { stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk) => { output += chunk; });
    child.stderr.on('data', (chunk) => { output += chunk; });
    child.on('error', reject);
    child.on('close', (code) => (code === 0 ? resolve(output.trim()) : reject(new Error(output.trim() || `generar-manifiesto.py terminó con ${code}`))));
  });
}

export function createClienteWebStore(options = {}) {
  const dataDirectory = options.dataDirectory ? path.resolve(options.dataDirectory) : '';
  const root = options.root ? path.resolve(options.root) : '';
  const available = Boolean(dataDirectory && root);
  const stageDirectory = path.join(dataDirectory, '.subida');
  const sessionFile = path.join(stageDirectory, 'sesion.json');
  const infoFile = path.join(root, 'cliente-base.json');
  const flagFile = path.join(root, 'desactivado');
  const datosDirectory = path.join(root, 'datos');
  const log = options.log || ((message) => console.log(`[cliente-web] ${message}`));
  const regenerate = options.regenerate || (() => runManifestScript({
    python: options.python || 'python3', script: options.manifestScript, dataDirectory, datosDirectory,
  }));
  const freeBytes = options.freeBytes || (() => { const stats = fs.statfsSync(dataDirectory); return stats.bavail * stats.bsize; });

  let queue = Promise.resolve();
  // Una sola operación que escribe a la vez (hay un único administrador subiendo): evita dos trozos del mismo fichero a la vez.
  function exclusive(action) {
    const result = queue.then(action, action);
    queue = result.catch(() => {});
    return result;
  }

  function requireAvailable() {
    if (!available) throw new ClienteWebError('El cliente web no está instalado en este servidor (falta WEB_CLIENT_DATA_DIR).', 503);
  }

  // ------------------------------------------------------------ lo que hay en el servidor
  function listBase() {
    const files = [];
    const collect = (directory, prefix) => {
      let entries = [];
      try { entries = fs.readdirSync(directory, { withFileTypes: true }); } catch { return; }
      for (const entry of entries) {
        if (!entry.isFile() || !/\.mpq$/i.test(entry.name)) continue;
        const relative = `${prefix}${entry.name}`;
        files.push({ ruta: relative, tamano: fs.statSync(path.join(directory, entry.name)).size, reservado: isReserved(relative) });
      }
    };
    collect(dataDirectory, '');
    for (const locale of LOCALES) collect(path.join(dataDirectory, locale), `${locale}/`);
    return files;
  }

  function describe(files) {
    const base = files.filter((file) => !file.reservado);
    const names = new Set(base.map((file) => file.ruta.toLowerCase()));
    const idiomas = LOCALES.filter((locale) => names.has(`${locale}/locale-${locale}.mpq`.toLowerCase()));
    const configurado = REQUIRED_ROOT.every((name) => names.has(name)) && idiomas.length > 0;
    return { base, idiomas, configurado };
  }

  const isActive = () => !fs.existsSync(flagFile);

  function status({ admin = false } = {}) {
    if (!available) return { disponible: false, configurado: false, activo: false };
    const { base, idiomas, configurado } = describe(listBase());
    const result = { disponible: true, configurado, activo: configurado && isActive() };
    if (admin) {
      const info = readJson(infoFile, null);
      result.base = configurado
        ? { ficheros: base.length, bytes: base.reduce((sum, file) => sum + file.tamano, 0), idiomas, subido: info?.subido || null }
        : null;
      result.interruptor = isActive();
      result.subida = currentSession();
      result.libre = (() => { try { return freeBytes(); } catch { return null; } })();
    }
    return result;
  }

  // ------------------------------------------------------------ subida
  const partFile = (relative) => path.join(stageDirectory, `${relative.replaceAll('/', '__')}.parte`);

  function receivedOf(relative) {
    try { return fs.statSync(partFile(relative)).size; } catch { return 0; }
  }

  function currentSession() {
    const session = readJson(sessionFile, null);
    if (!session || !Array.isArray(session.archivos)) return null;
    const archivos = session.archivos.map((file) => ({ ruta: file.ruta, tamano: file.tamano, recibido: receivedOf(file.ruta) }));
    return {
      id: session.id, creada: session.creada, archivos,
      total: archivos.reduce((sum, file) => sum + file.tamano, 0), recibido: archivos.reduce((sum, file) => sum + file.recibido, 0),
    };
  }

  function validateList(list) {
    if (!Array.isArray(list) || !list.length) throw new ClienteWebError('Falta la lista de ficheros del cliente.');
    if (list.length > LIMITS.files) throw new ClienteWebError(`Demasiados ficheros (máximo ${LIMITS.files}).`);   // «{max}» en locales/en.js
    const seen = new Set();
    const files = [];
    const ignored = [];
    for (const item of list) {
      const relative = Array.isArray(item) ? item[0] : item?.ruta;
      const size = Number(Array.isArray(item) ? item[1] : item?.tamano);
      if (typeof relative !== 'string' || !PATH_RULE.test(relative)) throw new ClienteWebError(`Nombre de fichero no válido: ${String(relative).slice(0, 80)}`);
      if (!Number.isSafeInteger(size) || size < 1 || size > LIMITS.fileBytes) throw new ClienteWebError(`Tamaño no válido para ${relative}.`);
      if (isReserved(relative)) { ignored.push(relative); continue; }
      const key = relative.toLowerCase();
      if (seen.has(key)) throw new ClienteWebError(`Fichero repetido: ${relative}`);
      seen.add(key);
      files.push({ ruta: relative, tamano: size });
    }
    const names = new Set(files.map((file) => file.ruta.toLowerCase()));
    const missing = REQUIRED_ROOT.filter((name) => !names.has(name));
    if (missing.length || !LOCALES.some((locale) => names.has(`${locale}/locale-${locale}.mpq`.toLowerCase()))) {
      throw new ClienteWebError(`No parece un cliente 3.3.5a completo: faltan ${[...missing, ...(missing.length ? [] : ['locale-<idioma>.MPQ'])].join(', ')}.`);
    }
    const total = files.reduce((sum, file) => sum + file.tamano, 0);
    if (total > LIMITS.totalBytes) throw new ClienteWebError('El cliente es demasiado grande.');
    return { files, ignored, total };
  }

  const sameList = (a, b) => a.length === b.length && a.every((file) => b.some((other) => other.ruta.toLowerCase() === file.ruta.toLowerCase() && other.tamano === file.tamano));

  async function removeBase(except = new Set()) {
    let removed = 0;
    for (const file of listBase()) {
      if (file.reservado || except.has(file.ruta.toLowerCase())) continue;
      fs.rmSync(path.join(dataDirectory, file.ruta), { force: true });
      removed += 1;
    }
    return removed;
  }

  function startUpload({ archivos, borrarAntes = false, reiniciar = false }) {
    return exclusive(async () => {
      requireAvailable();
      const { files, ignored, total } = validateList(archivos);
      const existing = currentSession();
      if (existing && sameList(existing.archivos, files)) {
        return { sesion: existing, ignorados: ignored, reanudada: true };
      }
      if (existing && !reiniciar) {
        throw new ClienteWebError('Hay otra subida a medias con ficheros distintos. Cancélala o empieza de nuevo.', 409, { requiereReiniciar: true });
      }
      fs.rmSync(stageDirectory, { recursive: true, force: true });
      fs.mkdirSync(stageDirectory, { recursive: true });
      if (borrarAntes) {
        const removed = await removeBase();
        fs.rmSync(infoFile, { force: true });
        await regenerate();
        log(`subida: borrado el cliente base anterior (${removed} ficheros)`);
      }
      const free = freeBytes();
      if (free < total + LIMITS.marginBytes) {
        fs.rmSync(stageDirectory, { recursive: true, force: true });
        throw new ClienteWebError('No hay sitio en el servidor para el cliente nuevo mientras existe el anterior. Marca «Borrar el cliente actual antes de subir».', 507, { libre: free, necesario: total });
      }
      writeJsonAtomic(sessionFile, { id: randomBytes(8).toString('hex'), creada: nowIso(), archivos: files });
      return { sesion: currentSession(), ignorados: ignored, reanudada: false };
    });
  }

  function receiveChunk({ ruta, desde, datos, sha256 }) {
    return exclusive(async () => {
      requireAvailable();
      const session = currentSession();
      if (!session) throw new ClienteWebError('No hay ninguna subida en curso.', 409);
      const file = session.archivos.find((candidate) => candidate.ruta === ruta);
      if (!file) throw new ClienteWebError('Ese fichero no está en la subida en curso.', 404);
      if (!Buffer.isBuffer(datos) || !datos.length) throw new ClienteWebError('Falta el trozo (application/octet-stream).');
      if (datos.length > LIMITS.chunkBytes) throw new ClienteWebError('Trozo demasiado grande.', 413);
      if (!SHA.test(sha256 || '')) throw new ClienteWebError('Falta la huella SHA-256 del trozo.');
      if (!Number.isSafeInteger(desde) || desde < 0) throw new ClienteWebError('Posición no válida.');
      if (desde !== file.recibido) throw new ClienteWebError('La posición no coincide con lo recibido.', 409, { recibido: file.recibido });
      if (desde + datos.length > file.tamano) throw new ClienteWebError('El trozo se sale del tamaño declarado.');
      if (createHash('sha256').update(datos).digest('hex') !== sha256) throw new ClienteWebError('La huella del trozo no coincide: se reenvía.', 422, { recibido: file.recibido });
      fs.appendFileSync(partFile(ruta), datos);
      return { ruta, recibido: file.recibido + datos.length, tamano: file.tamano };
    });
  }

  function hasMagic(file) {
    const descriptor = fs.openSync(file, 'r');
    try {
      const head = Buffer.alloc(4);
      fs.readSync(descriptor, head, 0, 4, 0);
      return MPQ_MAGIC.some((magic) => magic.equals(head));
    } finally {
      fs.closeSync(descriptor);
    }
  }

  function commit() {
    return exclusive(async () => {
      requireAvailable();
      const session = currentSession();
      if (!session) throw new ClienteWebError('No hay ninguna subida en curso.', 409);
      const incomplete = session.archivos.filter((file) => file.recibido !== file.tamano);
      if (incomplete.length) throw new ClienteWebError(`Faltan datos de ${incomplete.length} ficheros.`, 409, { incompletos: incomplete.map((file) => file.ruta) });
      const broken = session.archivos.filter((file) => !hasMagic(partFile(file.ruta)));
      if (broken.length) throw new ClienteWebError(`No son MPQ válidos: ${broken.map((file) => file.ruta).join(', ')}.`, 422);
      const keep = new Set(session.archivos.map((file) => file.ruta.toLowerCase()));
      await removeBase(keep);
      for (const file of session.archivos) {
        const destination = path.join(dataDirectory, file.ruta);
        fs.mkdirSync(path.dirname(destination), { recursive: true });
        fs.renameSync(partFile(file.ruta), destination);
        fs.chmodSync(destination, 0o644);
      }
      fs.rmSync(stageDirectory, { recursive: true, force: true });
      await regenerate();
      writeJsonAtomic(infoFile, { subido: nowIso(), ficheros: session.archivos.length, bytes: session.total });
      log(`subida completada: ${session.archivos.length} ficheros, ${session.total} bytes`);
      return status({ admin: true });
    });
  }

  function cancel() {
    return exclusive(async () => {
      requireAvailable();
      fs.rmSync(stageDirectory, { recursive: true, force: true });
      return status({ admin: true });
    });
  }

  function setActive(active) {
    requireAvailable();
    const { configurado } = describe(listBase());
    if (active && !configurado) throw new ClienteWebError('Sube primero el cliente base.', 409);
    if (active) fs.rmSync(flagFile, { force: true });
    else fs.writeFileSync(flagFile, `${nowIso()}\n`);
    return status({ admin: true });
  }

  return { available, status, startUpload, receiveChunk, commit, cancel, setActive, currentSession };
}
