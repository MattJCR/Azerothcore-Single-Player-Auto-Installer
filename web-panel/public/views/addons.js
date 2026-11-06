// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Vista "Addons del cliente": catálogo, instalación directa vía File System
// Access API, detección de lo ya instalado y parches de cliente.
import { $, $$, state, api, showLogin, showToast, escapeHtml, directoryPickerUnavailable } from '../shared.js';
import { ClientData, describeClient, prepareResources } from '../client-resources.js';
import { t, lang, lowerCase, compareText, formatDate, formatDateTime, formatNumber } from '../i18n.js';

export const CLASS_FILTERS = ['Guerrero', 'Paladín', 'Cazador', 'Pícaro', 'Sacerdote', 'Caballero de la Muerte', 'Chamán', 'Mago', 'Brujo', 'Druida'];

export function enter() {
  loadAddons();
  refreshInstalledState();
  loadResources();
}

function formatBytes(bytes) {
  if (bytes < 1024 * 1024) return `${Math.ceil(bytes / 1024)} KB`;
  return `${formatNumber(bytes / 1024 / 1024, { maximumFractionDigits: 1 })} MB`;
}

function filteredAddons() {
  const search = lowerCase($('#addon-search').value.trim());
  const category = $('#addon-category').value;
  const playerClass = $('#addon-class').value;
  return state.addons.filter((addon) => (!search || lowerCase(`${addon.name} ${addon.description}`).includes(search))
    && (!category || addon.category === category)
    && (!playerClass || addon.classes.includes(playerClass)));
}

function updateAddonSelection() {
  $('#selected-count').textContent = state.selectedAddons.size;
  $$('#addon-grid input[type="checkbox"]').forEach((input) => { input.checked = state.selectedAddons.has(input.value); });
  $('#install-addons').disabled = !state.wowDirectory || !state.selectedAddons.size;
  $('#install-patches').disabled = !state.patches.length;
  $('#rescan-installed').disabled = !state.wowDirectory;
}

// El estado de instalado/actualización se calcula siempre desde el disco (ver
// scanInstalledAddons/scanInstalledPatches): no hay un manifiesto propio que
// pueda desincronizarse. 'not-installed' se omite del todo (badge null).
function installStatusBadge(status) {
  if (status === 'current') return { text: t('✓ Instalado'), className: 'status-current' };
  if (status === 'update') return { text: t('⟳ Actualización disponible'), className: 'status-update' };
  return null;
}

function renderPatches() {
  $('#patch-list').innerHTML = state.patches.map((patch) => {
    const status = state.installedPatches.get(patch.id);
    const badge = installStatusBadge(status);
    const canUninstall = !patch.required && (status === 'current' || status === 'update');
    const pending = patch.available === false;
    return `<article class="patch-item ${pending ? 'patch-pending' : ''}">
    <span class="patch-file">${escapeHtml(patch.name)}</span>
    <span class="patch-copy"><strong>${patch.required ? t('★ Obligatorio') : t('Opcional')}</strong><small>${escapeHtml(patch.description)} · ${pending ? `<em class="resource-state-pendiente">${t('Pendiente de generar desde un cliente de WoW (lo hace un administrador)')}</em>` : formatBytes(patch.size)}${badge ? ` · <em class="badge-${badge.className}">${badge.text}</em>` : ''}</small></span>
    <span class="patch-actions">
      ${pending ? '' : `<a href="${escapeHtml(patch.downloadUrl)}" download>${t('Descargar')}</a>`}
      ${canUninstall ? `<button type="button" class="link-danger" data-uninstall-patch="${escapeHtml(patch.id)}">${t('Desinstalar')}</button>` : ''}
    </span>
  </article>`;
  }).join('');
}

function renderAddons() {
  const addons = filteredAddons();
  $('#addon-grid').innerHTML = addons.map((addon) => {
    const status = state.installedAddons.get(addon.id);
    const badge = installStatusBadge(status);
    const canUninstall = !addon.required && (status === 'current' || status === 'update');
    return `<article class="addon-card ${addon.required ? 'required' : addon.recommended ? 'recommended' : ''}">
    <label class="addon-choice">
      <input type="checkbox" value="${escapeHtml(addon.id)}" ${state.selectedAddons.has(addon.id) ? 'checked' : ''} ${addon.required ? 'disabled' : ''}>
      <span class="addon-emblem" aria-hidden="true">${escapeHtml(addon.name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase())}</span>
      <span class="addon-copy">
        <span class="addon-title"><strong>${escapeHtml(addon.name)}</strong>${addon.required ? `<em class="badge-protected" title="${t('Se instala siempre; no se puede desmarcar ni desinstalar.')}">${t('★ Obligatorio')}</em>` : addon.recommended ? `<em class="badge-recommended">${t('Recomendado')}</em>` : ''}${badge ? `<em class="badge-${badge.className}">${badge.text}</em>` : ''}</span>
        <span class="addon-category">${escapeHtml(t(addon.category))} · ${formatBytes(addon.size)}${addon.classes.length && addon.classes.length < CLASS_FILTERS.length ? ` · ${escapeHtml(addon.classes.map((name) => t(name)).join(', '))}` : ''}</span>
        <span class="addon-description">${escapeHtml(addon.description)}</span>
      </span>
      <span class="checkmark" aria-hidden="true">✓</span>
    </label>
    <div class="addon-links">
      ${addon.sourceUrl ? `<a href="${escapeHtml(addon.sourceUrl)}" target="_blank" rel="noreferrer">${t('Fuente')}</a>` : `<span>${t('Addon del servidor')}</span>`}
      <a class="addon-download" href="${escapeHtml(addon.downloadUrl)}" download>${t('Descargar ZIP')}</a>
      ${canUninstall ? `<button type="button" class="link-danger" data-uninstall-addon="${escapeHtml(addon.id)}">${t('Desinstalar')}</button>` : ''}
    </div>
  </article>`;
  }).join('');
  $('#addons-empty').classList.toggle('hidden', addons.length > 0);
  updateAddonSelection();
}

async function loadAddons() {
  if (state.addons.length) return;
  try {
    const catalog = await api('/api/addons');
    state.addons = catalog.addons;
    state.patches = catalog.patches || [];
    state.selectedAddons = new Set(catalog.addons.filter((addon) => addon.required || addon.recommended).map((addon) => addon.id));
    $('#addon-total').textContent = catalog.addons.length;
    $('#mirror-version').textContent = t('Copia {commit} · {date}', { commit: catalog.sourceCommit.slice(0, 8), date: formatDate(catalog.mirroredAt) });
    // El valor de la opción es la categoría del catálogo (en español); sólo cambia lo que se lee.
    const categories = [...new Set(catalog.addons.map((addon) => addon.category))].sort((a, b) => compareText(t(a), t(b)));
    $('#addon-category').insertAdjacentHTML('beforeend', categories.map((category) => `<option value="${escapeHtml(category)}">${escapeHtml(t(category))}</option>`).join(''));
    renderAddons();
    renderPatches();
    await refreshInstalledState();
  } catch (error) {
    if (error.status === 401) return showLogin();
    showToast(error.message);
  }
}

async function containsWowExecutable(directory) {
  for await (const [name, handle] of directory.entries()) {
    if (handle.kind === 'file' && name.toLowerCase() === 'wow.exe') return true;
  }
  return false;
}

async function directoryHandleOrNull(parent, name) {
  try { return await parent.getDirectoryHandle(name); }
  catch (error) { if (error.name === 'NotFoundError') return null; throw error; }
}

async function listDirectoryFilesSorted(directoryHandle) {
  const results = [];
  async function walk(handle, relativePath) {
    for await (const [name, entry] of handle.entries()) {
      const entryRelativePath = relativePath ? `${relativePath}/${name}` : name;
      if (entry.kind === 'directory') await walk(entry, entryRelativePath);
      else results.push({ relativePath: entryRelativePath, handle: entry });
    }
  }
  await walk(directoryHandle, '');
  results.sort((a, b) => (a.relativePath < b.relativePath ? -1 : a.relativePath > b.relativePath ? 1 : 0));
  return results;
}

async function sha256Hex(buffer) {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

// Mismo esquema que computeContentVersion en web-panel/src/addons.js: nombre
// de carpeta + ruta relativa + salto de línea + contenido de cada archivo, en
// orden alfabético estable, para poder comparar sin un manifiesto propio en
// el cliente. Si falta alguna de las carpetas del addon se considera no
// instalado (aunque tenga alguna otra ya presente de una instalación previa).
async function computeLocalAddonVersion(addonsDirectory, directories) {
  const encoder = new TextEncoder();
  const chunks = [];
  for (const name of directories) {
    const directoryHandle = await directoryHandleOrNull(addonsDirectory, name);
    if (!directoryHandle) return null;
    for (const { relativePath, handle } of await listDirectoryFilesSorted(directoryHandle)) {
      chunks.push(encoder.encode(`${name}/${relativePath}\n`));
      chunks.push(new Uint8Array(await (await handle.getFile()).arrayBuffer()));
      chunks.push(encoder.encode('\n'));
    }
  }
  const combined = new Uint8Array(chunks.reduce((sum, chunk) => sum + chunk.length, 0));
  let offset = 0;
  for (const chunk of chunks) { combined.set(chunk, offset); offset += chunk.length; }
  return sha256Hex(combined.buffer);
}

async function scanInstalledAddons() {
  if (!state.wowDirectory || !state.addons.length) return;
  try {
    const interfaceDirectory = await state.wowDirectory.getDirectoryHandle('Interface', { create: true });
    const addonsDirectory = await interfaceDirectory.getDirectoryHandle('AddOns', { create: true });
    const statuses = new Map();
    for (const addon of state.addons) {
      const localVersion = await computeLocalAddonVersion(addonsDirectory, addon.directories);
      statuses.set(addon.id, localVersion === null ? 'not-installed' : localVersion === addon.contentVersion ? 'current' : 'update');
    }
    state.installedAddons = statuses;
  } catch (error) {
    console.warn(t('No se pudo comprobar los addons instalados'), error);
  }
  renderAddons();
}

async function scanInstalledPatches() {
  if (!state.wowDirectory || !state.patches.length) return;
  const statuses = new Map();
  try {
    const dataDirectory = await state.wowDirectory.getDirectoryHandle('Data', { create: true });
    for (const patch of state.patches) {
      try {
        const directory = patch.targetDir ? await dataDirectory.getDirectoryHandle(patch.targetDir) : dataDirectory;
        const file = await (await directory.getFileHandle(patch.file)).getFile();
        const hex = (await sha256Hex(await file.arrayBuffer())).toUpperCase();
        statuses.set(patch.id, hex === patch.sha256 ? 'current' : 'update');
      } catch (error) {
        if (error.name !== 'NotFoundError') console.warn(t('No se pudo comprobar {file}', { file: patch.file }), error);
        statuses.set(patch.id, 'not-installed');
      }
    }
  } catch (error) {
    console.warn(t('No se pudo comprobar los parches instalados'), error);
  }
  state.installedPatches = statuses;
  renderPatches();
}

async function refreshInstalledState() {
  if (!state.wowDirectory || state.scanningInstalled) return;
  state.scanningInstalled = true;
  const status = $('#folder-status');
  status.textContent = t('{folder} · comprobando addons y parches instalados…', { folder: state.wowDirectory.name });
  try {
    await Promise.all([scanInstalledAddons(), scanInstalledPatches()]);
  } finally {
    state.scanningInstalled = false;
    status.textContent = t('{folder} · cliente verificado. Se instalará en Interface/AddOns y Data.', { folder: state.wowDirectory.name });
  }
}

// ------------------------------------------------------------------ recursos
// Iconos de la armería y parches de idioma se generan desde el cliente del
// jugador (client-resources.js). Sólo un administrador puede prepararlos.
const isAdmin = () => (state.user?.gmlevel || 0) >= 3;
let preparing = null;

function renderResources() {
  const panel = $('#resources-panel');
  panel.classList.toggle('hidden', !isAdmin() || !state.resources);
  if (!state.resources) return;
  const names = { iconos: t('Iconos de la armería'), 'parche-esES': t('Parche patch-esES-4.MPQ'), 'parche-enUS': t('Parche patch-enUS-4.MPQ'), mapas: t('Mapas del panel') };
  $('#resource-list').innerHTML = state.resources.recursos.map((item) => `<article class="resource-item">
    <span class="patch-file">${escapeHtml(names[item.id] || item.id)}</span>
    <span class="patch-copy"><strong class="resource-state-${escapeHtml(item.estado)}">${item.estado === 'listo' ? t('✓ Listo') : t('Pendiente')}</strong><small>${item.estado === 'listo'
      ? `${item.origen === 'preparado' ? t('Preparado en el servidor') : t('Generado desde tu cliente')}${item.actualizado ? ` · ${formatDateTime(item.actualizado)}` : ''}`
      : escapeHtml(item.detalle || '')}</small></span>
  </article>`).join('');
  const job = state.resources.trabajo;
  if (job && job.estado === 'error') {
    $('#resource-list').insertAdjacentHTML('beforeend', `<article class="resource-item"><span class="patch-file">${t('Último intento')}</span><span class="patch-copy"><strong class="resource-state-pendiente">${t('Falló')}</strong><small>${escapeHtml(job.mensaje)}</small></span></article>`);
  }
}

async function loadResources() {
  if (!isAdmin()) {
    state.resources = null;
    renderResources();
    return;
  }
  try {
    state.resources = await api('/api/recursos');
  } catch (error) {
    if (error.status === 401) return showLogin();
    state.resources = null;
  }
  renderResources();
}

function setResourceProgress({ texto, hecho, total }) {
  const progress = $('#resource-progress');
  progress.classList.remove('hidden');
  progress.querySelector('span').textContent = texto;
  progress.querySelector('i').style.width = total ? `${Math.round(hecho / total * 100)}%` : '12%';
}

async function listClientMpq(dataDirectory) {
  const files = [];
  async function collect(directory, prefix) {
    for await (const [name, handle] of directory.entries()) {
      if (handle.kind === 'file' && /\.mpq$/i.test(name)) files.push({ path: `${prefix}${name}`, blob: await handle.getFile() });
    }
  }
  await collect(dataDirectory, '');
  for (const language of ['esES', 'enUS']) {
    const directory = await directoryHandleOrNull(dataDirectory, language);
    if (directory) await collect(directory, `${language}/`);
  }
  return files;
}

const resourceHttp = {
  json: (method, path, body) => api(path, { method, body: body === undefined ? undefined : JSON.stringify(body) }),
  async put(path, bytes) {
    const response = await fetch(path, { method: 'PUT', credentials: 'same-origin', headers: { 'Content-Type': 'application/zip', 'X-Panel-Request': '1', 'X-Panel-Lang': lang() }, body: bytes });
    if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || t('No se pudo enviar el lote al servidor'));
  },
};

// Lee el cliente elegido, envía lo que falte y espera a que el servidor genere.
// Devuelve true si el servidor queda con todo preparado.
async function prepareFromClient({ force = false } = {}) {
  if (preparing) return false;
  if (!state.wowDirectory) await chooseWowDirectory({ skipPrepare: true });
  if (!state.wowDirectory) return false;
  const buttons = ['#prepare-resources', '#regenerate-resources'].map($);
  const cancel = $('#cancel-resources');
  const controller = new AbortController();
  preparing = controller;
  buttons.forEach((button) => { button.disabled = true; });
  cancel.classList.remove('hidden');
  cancel.onclick = () => controller.abort();
  try {
    setResourceProgress({ texto: t('Abriendo los MPQ de tu cliente…') });
    const dataDirectory = await state.wowDirectory.getDirectoryHandle('Data');
    const client = new ClientData(await listClientMpq(dataDirectory));
    const { languages } = describeClient(client);
    const result = await prepareResources({
      client, http: resourceHttp, JSZip: window.JSZip, languages, force: force ? ['iconos', ...languages.map((language) => `parche-${language}`)] : [],
      onProgress: setResourceProgress, signal: controller.signal,
    });
    setResourceProgress({ texto: result.estado === 'alDia' ? t('Los recursos ya estaban al día con tu cliente.') : t('Recursos generados y verificados en el servidor.'), hecho: 1, total: 1 });
    showToast(result.estado === 'alDia' ? t('Los recursos ya estaban al día con tu cliente.') : t('Recursos preparados. Ya puedes instalar los parches.'));
    state.patches = [];
    state.addons = [];
    await Promise.all([loadResources(), loadAddons()]);
    return true;
  } catch (error) {
    setResourceProgress({ texto: t('No se pudieron preparar los recursos: {error}', { error: error.message }), hecho: 0, total: 1 });
    showToast(error.message);
    await loadResources();
    return false;
  } finally {
    preparing = null;
    cancel.classList.add('hidden');
    buttons.forEach((button) => { button.disabled = false; });
  }
}

const resourcesPending = () => Boolean(state.resources?.recursos.some((item) => item.id !== 'mapas' && item.estado === 'pendiente'));

async function chooseWowDirectory({ skipPrepare = false } = {}) {
  if (!window.isSecureContext) {
    showToast(t('El certificado aún no es de confianza. Instálalo en Equipo local → Entidades de certificación raíz de confianza.'));
    return;
  }
  if (!window.showDirectoryPicker) {
    directoryPickerUnavailable();
    return;
  }
  try {
    const directory = await window.showDirectoryPicker({ id: 'azeroth-wow-client', mode: 'readwrite' });
    if (!await containsWowExecutable(directory)) throw new Error(t('La carpeta elegida no contiene Wow.exe.'));
    state.wowDirectory = directory;
    state.installedAddons = new Map();
    state.installedPatches = new Map();
    $('#installer-notice').classList.add('ready');
    updateAddonSelection();
    await refreshInstalledState();
    // Con el cliente elegido, un administrador completa lo que falte (iconos y parches).
    if (!skipPrepare && isAdmin()) {
      await loadResources();
      if (resourcesPending()) await prepareFromClient();
    }
  } catch (error) {
    if (error.name !== 'AbortError') showToast(error.message);
  }
}

async function uninstallAddon(addon) {
  if (addon.required || !state.wowDirectory) return;
  if (!window.confirm(t('¿Desinstalar {name}? Se borrará su carpeta de Interface/AddOns junto con su configuración guardada.', { name: addon.name }))) return;
  try {
    const interfaceDirectory = await state.wowDirectory.getDirectoryHandle('Interface', { create: true });
    const addonsDirectory = await interfaceDirectory.getDirectoryHandle('AddOns', { create: true });
    for (const name of addon.directories) {
      try { await addonsDirectory.removeEntry(name, { recursive: true }); }
      catch (error) { if (error.name !== 'NotFoundError') throw error; }
    }
    state.installedAddons.set(addon.id, 'not-installed');
    state.selectedAddons.delete(addon.id);
    showToast(t('{name} desinstalado.', { name: addon.name }));
    renderAddons();
  } catch (error) {
    showToast(t('No se pudo desinstalar {name}: {error}', { name: addon.name, error: error.message }));
  }
}

async function uninstallPatch(patch) {
  if (patch.required || !state.wowDirectory) return;
  if (!window.confirm(t('¿Desinstalar {name}?', { name: patch.name }))) return;
  try {
    const dataDirectory = await state.wowDirectory.getDirectoryHandle('Data', { create: true });
    const directory = patch.targetDir ? await dataDirectory.getDirectoryHandle(patch.targetDir, { create: true }) : dataDirectory;
    try { await directory.removeEntry(patch.file); }
    catch (error) { if (error.name !== 'NotFoundError') throw error; }
    state.installedPatches.set(patch.id, 'not-installed');
    showToast(t('{name} desinstalado.', { name: patch.name }));
    renderPatches();
  } catch (error) {
    showToast(t('No se pudo desinstalar {name}: {error}', { name: patch.name, error: error.message }));
  }
}

function installableZipEntries(zip) {
  const entries = Object.values(zip.files).filter((entry) => !entry.dir)
    .map((entry) => ({ entry, path: entry.name.replace(/^\.\//, '').replaceAll('\\', '/') }))
    .filter(({ path }) => path && !path.startsWith('__MACOSX/') && !path.endsWith('/.DS_Store'));
  if (entries.some(({ path }) => path.startsWith('/') || path.split('/').some((part) => !part || part === '..' || part.includes(':')))) {
    throw new Error(t('El paquete contiene una ruta no segura.'));
  }
  const tocPaths = entries.map(({ path }) => path).filter((value) => value.toLowerCase().endsWith('.toc'));
  if (!tocPaths.length) throw new Error(t('El paquete no contiene ningún archivo .toc de addon.'));
  const first = entries[0]?.path.split('/')[0];
  const stripWrapper = first && entries.every(({ path }) => path.split('/')[0] === first) && tocPaths.every((value) => value.split('/').length >= 3);
  return entries.map(({ entry, path }) => ({ entry, path: stripWrapper ? path.split('/').slice(1).join('/') : path }));
}

async function writeZipToDirectory(buffer, addonsDirectory) {
  const zip = await window.JSZip.loadAsync(buffer);
  const entries = installableZipEntries(zip);
  for (const { entry, path: entryPath } of entries) {
    const parts = entryPath.split('/');
    const fileName = parts.pop();
    let directory = addonsDirectory;
    for (const part of parts) directory = await directory.getDirectoryHandle(part, { create: true });
    const file = await directory.getFileHandle(fileName, { create: true });
    const writable = await file.createWritable();
    await writable.write(await entry.async('uint8array'));
    await writable.close();
  }
}

// Igual que installPatchesCore: solo la instalación, sin UI propia, para que
// la reutilicen el botón suelto y la operación combinada. onProgress(index,
// total, addon) se llama antes de decidir si ese addon se copia o se salta.
async function installAddonsCore(selected, onProgress) {
  if (!selected.length) return { written: 0, skipped: 0 };
  const interfaceDirectory = await state.wowDirectory.getDirectoryHandle('Interface', { create: true });
  const addonsDirectory = await interfaceDirectory.getDirectoryHandle('AddOns', { create: true });
  let written = 0;
  let skipped = 0;
  for (let index = 0; index < selected.length; index += 1) {
    const addon = selected[index];
    onProgress?.(index, selected.length, addon);
    // Ya instalado y con el mismo contenido que sirve el panel: no se
    // vuelve a copiar, para no pisar SavedVariables ni configuración del
    // jugador dentro de esa misma carpeta.
    if (state.installedAddons.get(addon.id) === 'current') {
      skipped += 1;
      continue;
    }
    const response = await fetch(addon.downloadUrl, { credentials: 'same-origin' });
    if (!response.ok) throw new Error(t('No se pudo descargar {name}.', { name: addon.name }));
    await writeZipToDirectory(await response.arrayBuffer(), addonsDirectory);
    state.installedAddons.set(addon.id, 'current');
    written += 1;
  }
  renderAddons();
  return { written, skipped };
}

async function installSelectedAddons() {
  const selected = state.addons.filter((addon) => state.selectedAddons.has(addon.id));
  if (!state.wowDirectory || !selected.length) return;
  const button = $('#install-addons');
  const progress = $('#install-progress');
  button.disabled = true;
  progress.classList.remove('hidden');
  try {
    const { written, skipped } = await installAddonsCore(selected, (index, total, addon) => {
      progress.querySelector('i').style.width = `${Math.round(index / total * 100)}%`;
      progress.querySelector('span').textContent = state.installedAddons.get(addon.id) === 'current'
        ? t('{index}/{total} · {name} ya está al día, sin tocar…', { index: index + 1, total, name: addon.name })
        : t('{index}/{total} · Descargando e instalando {name}…', { index: index + 1, total, name: addon.name });
    });
    progress.querySelector('i').style.width = '100%';
    progress.querySelector('span').textContent = written === 1
      ? t('1 addon instalado/actualizado, {skipped} sin cambios.', { skipped })
      : t('{written} addons instalados/actualizados, {skipped} sin cambios.', { written, skipped });
    showToast(t('Instalación terminada correctamente.'));
  } catch (error) {
    progress.querySelector('span').textContent = t('Instalación detenida: {error}', { error: error.message });
    showToast(error.message);
  } finally {
    button.disabled = false;
  }
}

// Lógica de instalación de parches en sí, sin tocar el botón ni mostrar
// toasts: la usa installPatches, que sí controla el botón y los mensajes.
async function installPatchesCore() {
  const dataDirectory = await state.wowDirectory.getDirectoryHandle('Data', { create: true });
  let written = 0;
  let skipped = 0;
  for (const patch of state.patches) {
    if (patch.available === false) continue; // aún no generado: no hay nada que copiar
    // Ya instalado con el mismo hash que sirve el panel: no se vuelve a
    // copiar (y no hace falta borrar la caché por él).
    if (state.installedPatches.get(patch.id) === 'current') {
      skipped += 1;
      continue;
    }
    const response = await fetch(patch.downloadUrl, { credentials: 'same-origin' });
    if (!response.ok) throw new Error(t('No se pudo descargar {name}.', { name: patch.name }));
    // targetDir: los parches de DBC de idioma van en Data/<idioma>/ (Data/esES,
    // Data/enUS), no planos en Data/, para pisar a patch-<idioma>-3.
    let directory = dataDirectory;
    if (patch.targetDir) {
      directory = await directory.getDirectoryHandle(patch.targetDir, { create: true });
    }
    const file = await directory.getFileHandle(patch.file, { create: true });
    const writable = await file.createWritable();
    await writable.write(await response.arrayBuffer());
    await writable.close();
    state.installedPatches.set(patch.id, 'current');
    written += 1;
  }
  renderPatches();
  // Los parches cambian DBC. El cliente cachea las consultas al servidor en
  // Cache/WDB y, si no se borra, sigue enseñando los datos viejos (icono "?",
  // nombres de otro servidor). Se borra aquí para que el jugador sólo tenga
  // que reiniciar el WoW.
  let cacheError = null;
  if (written) {
    try {
      await state.wowDirectory.removeEntry('Cache', { recursive: true });
    } catch (error) {
      if (error?.name !== 'NotFoundError') cacheError = error;
    }
  }
  return { written, skipped, cacheError };
}

// Autosuficiente: pide la carpeta de Wow.exe si todavía no se eligió,
// instala los parches y vuelve a leer del disco (hash a hash) antes de
// avisar — no basta con que el bucle de copia no lanzara una excepción.
// Sólo se ocupa de parches: los addons obligatorios se instalan desde su
// propia sección (paso 3), no desde aquí.
async function installPatches() {
  if (!window.isSecureContext) {
    showToast(t('El certificado aún no es de confianza. Instálalo en Equipo local → Entidades de certificación raíz de confianza.'));
    return;
  }
  if (!window.showDirectoryPicker) {
    directoryPickerUnavailable();
    return;
  }
  if (!state.patches.length) {
    showToast(t('El catálogo todavía se está cargando. Espera un momento y vuelve a pulsar.'));
    return;
  }
  const button = $('#install-patches');
  button.disabled = true;
  try {
    if (!state.wowDirectory) await chooseWowDirectory({ skipPrepare: true });
    if (!state.wowDirectory) return;
    if (state.patches.some((patch) => patch.required && patch.available === false)) {
      if (!isAdmin()) {
        showToast(t('Los parches aún no están generados. Un administrador debe elegir su cliente en esta pantalla para prepararlos.'));
        return;
      }
      if (!await prepareFromClient()) return;
    }

    const { written, skipped, cacheError } = await installPatchesCore();
    await scanInstalledPatches();
    const missing = state.patches.filter((patch) => patch.required && state.installedPatches.get(patch.id) !== 'current');
    if (missing.length) {
      showToast(t('Instalación incompleta: falta {names}. Vuelve a pulsar "Instalar parches".', { names: missing.map((patch) => patch.name).join(', ') }));
      return;
    }
    if (!written) {
      showToast(skipped === 1
        ? t('El parche ya estaba al día y verificado. No se ha tocado nada.')
        : t('Los {skipped} parches ya estaban al día y verificados. No se ha tocado nada.', { skipped }));
      return;
    }
    const installed = written === 1
      ? t('1 parche instalado/actualizado y verificado')
      : t('{written} parches instalados/actualizados y verificados', { written });
    showToast(cacheError
      ? t('{installed} ({skipped} sin cambios). No pude borrar Cache\\ (¿WoW abierto?): ciérralo, bórrala y reinicia.', { installed, skipped })
      : t('{installed} ({skipped} sin cambios) y caché limpiada. Cierra y abre el WoW.', { installed, skipped }));
  } catch (error) {
    showToast(t('No se pudieron instalar los parches: {error}', { error: error.message }));
  } finally {
    button.disabled = !state.patches.length;
  }
}

$('#addon-search').addEventListener('input', renderAddons);
$('#addon-category').addEventListener('change', renderAddons);
$('#addon-class').addEventListener('change', renderAddons);
$('#addon-grid').addEventListener('change', (event) => {
  const input = event.target.closest('input[type="checkbox"]');
  if (!input) return;
  if (input.checked) state.selectedAddons.add(input.value); else state.selectedAddons.delete(input.value);
  updateAddonSelection();
});
$('#addon-grid').addEventListener('click', (event) => {
  const button = event.target.closest('[data-uninstall-addon]');
  if (!button) return;
  const addon = state.addons.find((item) => item.id === button.dataset.uninstallAddon);
  if (addon) uninstallAddon(addon);
});
$('#patch-list').addEventListener('click', (event) => {
  const button = event.target.closest('[data-uninstall-patch]');
  if (!button) return;
  const patch = state.patches.find((item) => item.id === button.dataset.uninstallPatch);
  if (patch) uninstallPatch(patch);
});
$('#rescan-installed').addEventListener('click', refreshInstalledState);
$('#clear-addons').addEventListener('click', () => {
  state.selectedAddons = new Set(state.addons.filter((addon) => addon.required).map((addon) => addon.id));
  renderAddons();
});
$('#select-visible-addons').addEventListener('click', () => {
  filteredAddons().forEach((addon) => state.selectedAddons.add(addon.id));
  renderAddons();
});
$('#choose-wow-folder').addEventListener('click', chooseWowDirectory);
$('#install-addons').addEventListener('click', installSelectedAddons);
$('#install-patches').addEventListener('click', installPatches);
$('#prepare-resources').addEventListener('click', () => prepareFromClient());
$('#regenerate-resources').addEventListener('click', () => {
  if (window.confirm(t('¿Regenerar todos los recursos desde tu cliente? Sustituye los actuales cuando termine bien.'))) prepareFromClient({ force: true });
});

if (!window.isSecureContext) {
  $('#folder-status').textContent = t('El certificado aún no es de confianza. Instálalo en Equipo local → Entidades de certificación raíz de confianza, cierra el navegador por completo y vuelve a entrar por HTTPS.');
} else if (!window.showDirectoryPicker) {
  $('#folder-status').textContent = t('La conexión ya es segura, pero este navegador no admite la instalación directa. Usa una versión actual de Chrome o Edge.');
}

// El valor es el nombre de clase del catálogo (en español); sólo cambia lo que se lee.
for (const name of CLASS_FILTERS) $('#addon-class').insertAdjacentHTML('beforeend', `<option value="${name}">${t(name)}</option>`);
