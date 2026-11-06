// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Vista "Cliente web" (cuelga de "Cliente local"), WEB-PANEL. Tres pasos en una sola pantalla:
//   0. Cliente base del servidor (sólo administradores): subirlo por HTTP, con reanudación, o actualizarlo; interruptor para todos.
//   1. Dónde está tu cliente local: la carpeta Data de este equipo, para que /play/ lea de ella en vez de bajar la base (WEB-LOCAL).
//   2. Activar el uso del cliente local en este navegador.
// Mientras el servidor no tiene cliente base, un administrador ve el asistente de primera instalación. Lo del paso 1 y 2 se guarda
// sólo en este navegador; lo del paso 0 vive en el servidor.
import { $, api, showToast, escapeHtml, directoryPickerUnavailable } from '../shared.js';
import { t, lang, formatNumber } from '../i18n.js';
import {
  leerConfig, guardarConfig, borrarConfig, findDataDirectory, listLocalMpq, parseManifest, classifyLocal, RESERVED_FALLBACK,
} from '../cliente-local.js';
import { uploadClient } from '../subida-cliente.js';

let current = null;      // configuración local: { handle, nombre, activo, resumen, guardado }
let server = null;       // GET /api/cliente-web/estado
let wizardOpen = false;  // el administrador abrió el asistente aunque ya haya cliente base (Actualizar)
const upload = { files: null, controller: null, running: false, samples: [] };

const formatGb = (bytes) => (bytes >= 1073741824 ? `${formatNumber(bytes / 1073741824, { maximumFractionDigits: 1 })} GB` : `${formatNumber(bytes / 1048576, { maximumFractionDigits: 0 })} MB`);
const REQUIRED_ROOT = ['common.mpq', 'expansion.mpq', 'lichking.mpq', 'patch.mpq'];
const isAdmin = () => Boolean(server?.esAdmin);

export async function enter() {
  const [stored, estado] = await Promise.allSettled([leerConfig(), api('/api/cliente-web/estado')]);
  current = stored.status === 'fulfilled' ? stored.value : null;
  server = estado.status === 'fulfilled' ? estado.value : { disponible: false, configurado: false, activo: false, esAdmin: false };
  if (!upload.running) {
    upload.files = null;
    wizardOpen = isAdmin() && Boolean(server.subida);   // al volver a la pantalla, el asistente sólo sigue abierto si hay una subida a medias
  }
  render();
}

// «Jugar en el navegador»: primero en «Tu experiencia», sólo con el cliente base subido y activo y el build desplegado.
export async function refreshPlayNav() {
  const link = $('#play-nav');
  try {
    const estado = await api('/api/cliente-web/estado');
    const build = estado.activo ? await fetch('/play/build.json', { method: 'HEAD', cache: 'no-store' }) : null;
    link.classList.toggle('hidden', !(estado.activo && build?.ok));
  } catch {
    link.classList.add('hidden');
  }
}

async function loadManifest() {
  const response = await fetch('/play/datos/manifiesto.tsv', { cache: 'no-store', credentials: 'same-origin' });
  if (!response.ok) throw new Error(t('El servidor no tiene preparado el cliente web (falta el manifiesto de /play/).'));
  return parseManifest(await response.text());
}

// Permiso de lectura para la sesión: al elegir la carpeta ya está concedido; al volver a abrir el panel hay que pedirlo con un clic.
async function ensureRead(handle) {
  if (await handle.queryPermission({ mode: 'read' }) === 'granted') return true;
  return await handle.requestPermission({ mode: 'read' }) === 'granted';
}

// ---------------------------------------------------------------- comprobaciones (paso 1)

function summaryRows(summary) {
  const row = (kind, label, title, detail) => `<li class="${kind}"><span class="cw-chip ${kind}">${escapeHtml(label)}</span><div><strong>${escapeHtml(title)}</strong>${detail ? `<small>${escapeHtml(detail)}</small>` : ''}</div></li>`;
  const rows = [];
  for (const custom of summary.custom) {
    rows.push(custom.carga
      ? row('ok', t('Correcto'), t('MPQ propio: {name}', { name: custom.path }), t('El cliente lo abrirá por su nombre, por encima de los parches normales.'))
      : row('info', t('Aviso'), t('MPQ propio sin efecto: {name}', { name: custom.path }), t('El cliente sólo abre patch-?.MPQ y patch-<idioma>-?.MPQ; con este nombre no se carga.')));
  }
  if (summary.faltan) rows.push(row('info', t('Aviso'), t('{count} ficheros que no tienes en tu carpeta los pone el servidor ({size})', { count: summary.faltan, size: formatGb(summary.bytesServidor) }), summary.faltanEjemplos.join(', ')));
  if (summary.reservados.length) rows.push(row('info', t('Aviso'), t('{count} ficheros de tu carpeta se ignoran porque su nombre es del servidor', { count: summary.reservados.length }), summary.reservados.join(', ')));
  if (!rows.length) rows.push(row('ok', t('Correcto'), t('Tu carpeta tiene todo lo que necesita el cliente web.'), ''));
  return rows.join('');
}

function renderSummary(summary) {
  $('#cw-tile-local').textContent = formatNumber(summary.local);
  $('#cw-tile-local-size').textContent = t('ficheros · {size}', { size: formatGb(summary.bytesLocal) });
  $('#cw-tile-server').textContent = formatNumber(summary.faltan);
  $('#cw-tile-server-size').textContent = t('ficheros · {size}', { size: formatGb(summary.bytesServidor) });
  const loaded = summary.custom.filter((custom) => custom.carga).length;
  $('#cw-tile-custom').textContent = formatNumber(summary.custom.length);
  $('#cw-tile-custom-note').textContent = loaded === summary.custom.length ? t('se cargarán') : t('{count} sin efecto', { count: summary.custom.length - loaded });
  $('#cw-tile-ignored').textContent = formatNumber(summary.reservados.length);
  const totalBytes = summary.bytesLocal + summary.bytesServidor;
  const share = totalBytes ? Math.round((summary.bytesLocal / totalBytes) * 100) : 100;
  $('#cw-split-local').style.width = `${share}%`;
  $('#cw-split-server').style.width = `${100 - share}%`;
  $('#cw-legend-local').textContent = t('Se lee de tu equipo · {percent} %', { percent: share });
  $('#cw-legend-server').textContent = t('Lo pone el servidor · {percent} %', { percent: 100 - share });
  $('#cw-summary').innerHTML = summaryRows(summary);
}

// ---------------------------------------------------------------- pintado

function renderStepZero() {
  const configured = Boolean(server?.configurado);
  const admin = isAdmin();
  document.querySelectorAll('#client-web-view .cw-admin-only').forEach((element) => element.classList.toggle('hidden', !admin));
  const pill = $('#cw-s0-pill');
  pill.textContent = configured ? (server.activo ? t('Listo') : t('Desactivado')) : t('Pendiente');
  pill.className = `cw-pill ${configured && server.activo ? 'ok' : 'wait'}`;
  $('#cw-s0-dot').textContent = configured ? '✓' : '0';
  $('#cw-s0-dot').classList.toggle('done', configured);
  const base = server?.base;
  $('#cw-s0-title').textContent = configured
    ? (base ? t('3.3.5a · {languages}', { languages: base.idiomas.join(' + ') }) : t('Cliente base disponible'))
    : t('Sin cliente base');
  $('#cw-s0-detail').textContent = configured && base
    ? t('{date} · {count} ficheros · {size}', {
      date: base.subido ? t('Subido el {date}', { date: new Date(base.subido).toLocaleDateString() }) : t('Subido antes de este panel'),
      count: base.ficheros, size: formatGb(base.bytes),
    })
    : (configured ? '' : t('El servidor todavía no ofrece ningún cliente.'));
  $('#cw-s0-active').checked = Boolean(server?.interruptor);
  $('#cw-s0-active').disabled = !configured;
  $('#cw-s0-waiting').classList.toggle('hidden', configured || admin);
  $('#cw-s0-update').textContent = configured ? t('Actualizar cliente base…') : t('Subir cliente base…');
}

function renderLocalSteps() {
  const configured = Boolean(server?.configurado);
  const hasFolder = Boolean(current?.handle);
  for (const id of ['#cw-step1', '#cw-step2']) $(id).classList.toggle('locked', !configured);
  $('#cw-s1-dot').textContent = hasFolder ? '✓' : '1';
  $('#cw-s1-dot').classList.toggle('done', hasFolder);
  $('#cw-s2-dot').textContent = current?.activo ? '✓' : '2';
  $('#cw-s2-dot').classList.toggle('done', Boolean(current?.activo));
  $('#cw-folder-status').textContent = hasFolder
    ? t('Carpeta elegida: {name}', { name: current.nombre })
    : t('Elige la carpeta de Wow.exe o la propia carpeta Data. El navegador pedirá permiso de lectura; no se copia ni se sube nada.');
  $('#cw-installer').classList.toggle('ready', hasFolder);
  $('#cw-choose-folder').disabled = !configured;
  $('#cw-enabled').disabled = !configured || !hasFolder;
  $('#cw-enabled').checked = Boolean(current?.activo);
  $('#cw-forget').disabled = !hasFolder;
  $('#cw-rescan').disabled = !hasFolder || !configured;
  const summary = current?.resumen;
  $('#cw-summary-panel').classList.toggle('hidden', !(summary && configured));
  if (summary && configured) {
    renderSummary(summary);
    $('#cw-summary-date').textContent = t('Comprobado el {date}', { date: new Date(current.guardado).toLocaleString() });
  }
}

function render() {
  const available = Boolean(server?.disponible);
  $('#cw-unavailable').classList.toggle('hidden', available);
  const showWizard = available && isAdmin() && (wizardOpen || !server.configurado || Boolean(server.subida) || upload.running);
  $('#cw-wizard').classList.toggle('hidden', !showWizard);
  $('#cw-steps').classList.toggle('hidden', !available || showWizard);
  if (!available || showWizard) $('#cw-summary-panel').classList.add('hidden');
  if (showWizard) renderWizard();
  if (available && !showWizard) {
    renderStepZero();
    renderLocalSteps();
  }
}

// ---------------------------------------------------------------- asistente: subir el cliente base (paso 0)

function setMessage(text, kind = '') {
  const element = $('#cw-up-message');
  element.textContent = text;
  element.className = `cw-note ${kind}`.trim();
}

function renderProgress(done, total) {
  const percent = total ? Math.floor((done / total) * 100) : 0;
  $('#cw-up-progress').classList.remove('hidden');
  $('#cw-up-fill').style.width = `${percent}%`;
  $('#cw-up-bar').setAttribute('aria-valuenow', String(percent));
  $('#cw-up-count').textContent = t('{done} de {total} · {percent} %', { done: formatGb(done), total: formatGb(total), percent });
}

function renderWizard() {
  const hasBase = Boolean(server?.configurado);
  const session = server?.subida;
  const running = upload.running;
  $('#cw-up-wipe-row').classList.toggle('hidden', !hasBase || Boolean(session));
  $('#cw-up-back').classList.toggle('hidden', !hasBase || running);
  $('#cw-up-pause').classList.toggle('hidden', !running);
  $('#cw-up-cancel').classList.toggle('hidden', !running && !session);
  $('#cw-up-start').classList.toggle('hidden', running);
  $('#cw-up-start').disabled = !upload.files;
  $('#cw-up-start').textContent = session && upload.files ? t('Continuar la subida') : t('Subir al servidor');
  $('#cw-up-choose').disabled = running;
  if (session && !running) renderProgress(session.recibido, session.total);
  else if (!running && !upload.files) $('#cw-up-progress').classList.add('hidden');
  if (session && !upload.files && !running) {
    $('#cw-up-name').textContent = t('Subida a medias en el servidor');
    $('#cw-up-detail').textContent = t('Vuelve a elegir la misma carpeta para continuar donde se quedó.');
  }
}

function clientProblem(files) {
  const names = new Set(files.map((file) => file.path.toLowerCase()));
  const missing = REQUIRED_ROOT.filter((name) => !names.has(name));
  if (missing.length) return t('No parece un cliente 3.3.5a completo: faltan {names}.', { names: missing.join(', ') });
  if (!['esES', 'enUS'].some((locale) => names.has(`${locale}/locale-${locale}.mpq`.toLowerCase()))) return t('No parece un cliente 3.3.5a completo: falta el idioma (esES o enUS).');
  return '';
}

async function chooseUploadFolder() {
  if (upload.running) return;
  if (!window.isSecureContext) return showToast(t('El certificado aún no es de confianza. Instálalo en Equipo local → Entidades de certificación raíz de confianza.'));
  if (!window.showDirectoryPicker) return directoryPickerUnavailable();
  try {
    const picked = await window.showDirectoryPicker({ id: 'azeroth-wow-data', mode: 'read' });
    const found = await findDataDirectory(picked);
    if (!found) throw new Error(t('La carpeta elegida no es un cliente 3.3.5a: no se encuentra Data con common.MPQ o patch.MPQ.'));
    const reserved = new Set(RESERVED_FALLBACK.map((name) => name.toLowerCase()));
    const listed = (await listLocalMpq(found.data)).filter((file) => !reserved.has(file.path.toLowerCase().split('/').pop()));
    const problem = clientProblem(listed);
    if (problem) throw new Error(problem);
    upload.files = listed.map((file) => ({ ruta: file.path, tamano: file.size, handle: file.handle }));
    const bytes = listed.reduce((sum, file) => sum + file.size, 0);
    const languages = ['esES', 'enUS'].filter((locale) => listed.some((file) => file.path === `${locale}/locale-${locale}.MPQ`));
    $('#cw-up-name').textContent = found.raiz ? found.raiz.name : found.data.name;
    $('#cw-up-detail').textContent = t('{count} ficheros · {size} · {languages}', { count: listed.length, size: formatGb(bytes), languages: languages.join(' + ') || '—' });
    setMessage('');
    renderWizard();
  } catch (error) {
    if (error.name !== 'AbortError') setMessage(error.message, 'error');
  }
}

function trackSpeed(done) {
  const now = Date.now();
  upload.samples.push([now, done]);
  upload.samples = upload.samples.filter(([time]) => now - time <= 20000);
  const [firstTime, firstDone] = upload.samples[0];
  if (now - firstTime < 2000) return '';
  const perSecond = (done - firstDone) / ((now - firstTime) / 1000);
  if (perSecond <= 0) return '';
  const speed = t('{speed} MB/s', { speed: formatNumber(perSecond / 1048576, { maximumFractionDigits: 1 }) });
  return `${speed} · ${t('quedan {time}', { time: formatEta((upload.total - done) / perSecond) })}`;
}

function formatEta(seconds) {
  if (seconds < 90) return t('{count} s', { count: Math.round(seconds) });
  if (seconds < 5400) return t('{count} min', { count: Math.round(seconds / 60) });
  return t('{count} h', { count: formatNumber(seconds / 3600, { maximumFractionDigits: 1 }) });
}

async function sendChunk({ ruta, desde, bytes, sha256, signal }) {
  const response = await fetch(`/api/cliente-web/subida/archivo?ruta=${encodeURIComponent(ruta)}&desde=${desde}`, {
    method: 'PUT',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/octet-stream', 'X-Panel-Request': '1', 'X-Panel-Lang': lang(), 'X-Chunk-Sha256': sha256 },
    body: bytes,
    signal,
  });
  return { status: response.status, body: await response.json().catch(() => ({})) };
}

const warnBeforeLeaving = (event) => { event.preventDefault(); event.returnValue = ''; };

async function startUpload({ reiniciar = false } = {}) {
  if (upload.running || !upload.files) return;
  const wipe = !$('#cw-up-wipe-row').classList.contains('hidden') && $('#cw-up-wipe').checked;
  if (wipe && !reiniciar && !window.confirm(t('Se borrará el cliente base actual del servidor antes de subir el nuevo y, mientras tanto, nadie podrá jugar en el navegador. ¿Continuar?'))) return;
  upload.controller = new AbortController();
  upload.running = true;
  upload.samples = [];
  upload.total = upload.files.reduce((sum, file) => sum + file.tamano, 0);
  window.addEventListener('beforeunload', warnBeforeLeaving);
  setMessage(t('Subiendo… mantén esta pestaña abierta. Puedes pausar y continuar después.'));
  renderWizard();
  let retry = false;
  try {
    const status = await uploadClient({
      files: upload.files, api, sendChunk, borrarAntes: wipe, reiniciar, signal: upload.controller.signal,
      onProgress: ({ recibido, total }) => {
        renderProgress(recibido, total);
        const detail = trackSpeed(recibido);
        if (detail) $('#cw-up-speed').textContent = detail;
      },
    });
    server = { ...status, esAdmin: true };
    if ($('#cw-up-activate').checked !== Boolean(server.interruptor)) server = { ...(await api('/api/cliente-web/activo', { method: 'POST', body: JSON.stringify({ activo: $('#cw-up-activate').checked }) })), esAdmin: true };
    upload.files = null;
    wizardOpen = false;
    showToast(t('Cliente base subido: {count} ficheros.', { count: server.base?.ficheros ?? 0 }));
    refreshPlayNav();
  } catch (error) {
    if (error.name === 'AbortError') {
      setMessage(t('Subida en pausa. Pulsa «Continuar la subida» para seguir donde se quedó.'));
    } else if (error.alIniciar && error.status === 409) {
      if (window.confirm(t('Hay otra subida a medias en el servidor con ficheros distintos. ¿Empezar de nuevo y descartarla?'))) retry = true;
      else setMessage(error.message, 'error');
    } else {
      setMessage(error.message, 'error');
      if (error.status === 507) $('#cw-up-wipe-row').classList.remove('hidden');
    }
  } finally {
    upload.running = false;
    window.removeEventListener('beforeunload', warnBeforeLeaving);
  }
  if (retry) return startUpload({ reiniciar: true });
  try { server = { ...(await api('/api/cliente-web/estado')) }; } catch { /* se queda el último estado conocido */ }
  render();
}

function pauseUpload() {
  upload.controller?.abort();
}

async function cancelUpload() {
  if (!window.confirm(t('¿Cancelar la subida y descartar lo ya enviado?'))) return;
  upload.controller?.abort();
  try {
    server = { ...(await api('/api/cliente-web/subida', { method: 'DELETE' })), esAdmin: true };
    upload.files = null;
    setMessage('');
    $('#cw-up-progress').classList.add('hidden');
    $('#cw-up-name').textContent = t('Ninguna carpeta elegida');
    $('#cw-up-detail').textContent = t('Sólo necesita permiso de lectura. Los ficheros viajan por HTTPS y la subida se puede pausar y reanudar.');
  } catch (error) {
    showToast(error.message);
  }
  render();
}

function openWizard() {
  wizardOpen = true;
  upload.files = null;
  setMessage('');
  $('#cw-up-progress').classList.add('hidden');
  $('#cw-up-name').textContent = t('Ninguna carpeta elegida');
  $('#cw-up-detail').textContent = t('Sólo necesita permiso de lectura. Los ficheros viajan por HTTPS y la subida se puede pausar y reanudar.');
  render();
}

function closeWizard() {
  wizardOpen = false;
  render();
}

async function toggleServerActive() {
  try {
    server = { ...(await api('/api/cliente-web/activo', { method: 'POST', body: JSON.stringify({ activo: $('#cw-s0-active').checked }) })), esAdmin: true };
    refreshPlayNav();
  } catch (error) {
    showToast(error.message);
  }
  render();
}

// ---------------------------------------------------------------- paso 1 y 2: cliente local de este navegador

async function scan(handle) {
  const picked = await findDataDirectory(handle);
  if (!picked) throw new Error(t('La carpeta elegida no es un cliente 3.3.5a: no se encuentra Data con common.MPQ o patch.MPQ.'));
  const [localFiles, manifest] = await Promise.all([listLocalMpq(picked.data), loadManifest()]);
  const result = classifyLocal(localFiles, manifest);
  const faltan = result.ausentes.length;
  return {
    data: picked.data,
    resumen: {
      local: result.local.length,
      bytesLocal: result.bytesLocal,
      faltan,
      bytesServidor: result.bytesServidor,
      faltanEjemplos: result.ausentes.map((row) => row.path).slice(0, 6),
      reservados: result.reservados.map((file) => file.path),
      custom: result.custom.map((file) => ({ path: file.path, carga: file.carga })),
    },
    // Con la carpeta de Wow.exe se guarda esa (el motor entra a Data); con Data, la propia Data.
    handle: picked.raiz || picked.data,
    nombre: picked.raiz ? picked.raiz.name : picked.data.name,
  };
}

async function chooseFolder() {
  if (!window.isSecureContext) return showToast(t('El certificado aún no es de confianza. Instálalo en Equipo local → Entidades de certificación raíz de confianza.'));
  if (!window.showDirectoryPicker) return directoryPickerUnavailable();
  try {
    const picked = await window.showDirectoryPicker({ id: 'azeroth-wow-data', mode: 'read' });
    const scanned = await scan(picked);
    current = { handle: scanned.handle, nombre: scanned.nombre, activo: Boolean(current?.activo), resumen: scanned.resumen, guardado: Date.now() };
    await guardarConfig(current);
    render();
  } catch (error) {
    if (error.name !== 'AbortError') showToast(error.message);
  }
}

async function rescan() {
  if (!current?.handle) return;
  try {
    if (!await ensureRead(current.handle)) return showToast(t('Sin permiso de lectura sobre la carpeta.'));
    const scanned = await scan(current.handle);
    current = { ...current, resumen: scanned.resumen, guardado: Date.now() };
    await guardarConfig(current);
    render();
  } catch (error) {
    showToast(error.message);
  }
}

async function toggleEnabled() {
  if (!current?.handle) return;
  current = { ...current, activo: $('#cw-enabled').checked };
  try { await guardarConfig(current); } catch (error) { showToast(error.message); }
  render();
}

async function forget() {
  if (!window.confirm(t('¿Quitar la carpeta guardada en este navegador? Los ficheros del equipo no se tocan.'))) return;
  try { await borrarConfig(); } catch (error) { showToast(error.message); }
  current = null;
  render();
}

$('#cw-up-choose').addEventListener('click', chooseUploadFolder);
$('#cw-up-start').addEventListener('click', () => startUpload());
$('#cw-up-pause').addEventListener('click', pauseUpload);
$('#cw-up-cancel').addEventListener('click', cancelUpload);
$('#cw-up-back').addEventListener('click', closeWizard);
$('#cw-s0-update').addEventListener('click', openWizard);
$('#cw-s0-active').addEventListener('change', toggleServerActive);
$('#cw-choose-folder').addEventListener('click', chooseFolder);
$('#cw-rescan').addEventListener('click', rescan);
$('#cw-enabled').addEventListener('change', toggleEnabled);
$('#cw-forget').addEventListener('click', forget);
