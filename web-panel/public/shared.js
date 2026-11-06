// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Estado compartido, utilidades transversales y el "shell" de navegación
// (showView/showApp/showLogin) que usan varios módulos de vista a la vez.
// Cada módulo de vista vive en views/*.js e importa de aquí lo que necesita;
// ninguno de ellos se importa desde este fichero (así se evita un ciclo) —
// showView() llega a cada vista a través de viewRegistry, que rellena
// app.js tras importar todos los módulos de vista.
import { MAP_BOUNDS, projectMapPlayer } from './map-projection.js?v=1.2.1';
import { t, lang, formatTime } from './i18n.js';

export const RACES = {
  1: [t('Humano'), 'Alliance'], 2: [t('Orco'), 'Horde'], 3: [t('Enano'), 'Alliance'], 4: [t('Elfo de la noche'), 'Alliance'],
  5: [t('No-muerto'), 'Horde'], 6: [t('Tauren'), 'Horde'], 7: [t('Gnomo'), 'Alliance'], 8: [t('Trol'), 'Horde'],
  10: [t('Elfo de sangre'), 'Horde'], 11: [t('Draenei'), 'Alliance'],
};
export const CLASSES = {
  1: [t('Guerrero'), '#c79c6e'], 2: [t('Paladín'), '#f58cba'], 3: [t('Cazador'), '#abd473'], 4: [t('Pícaro'), '#fff569'],
  5: [t('Sacerdote'), '#ffffff'], 6: [t('Caballero de la Muerte'), '#c41f3b'], 7: [t('Chamán'), '#2777ff'],
  8: [t('Mago'), '#69ccf0'], 9: [t('Brujo'), '#9482c9'], 11: [t('Druida'), '#ff7d0a'],
};
export const QUALITY_COLORS = ['#9d9d9d', '#ffffff', '#1eff00', '#0070dd', '#a335ee', '#ff8000', '#e6cc80', '#00ccff'];
const MAPS = {
  0: { name: t('Reinos del Este'), image: '/assets/maps/0.jpg?v=1.2.0', width: 3840, height: 2560, ...MAP_BOUNDS[0] },
  1: { name: t('Kalimdor'), image: '/assets/maps/1.jpg?v=1.2.0', width: 3840, height: 2560, ...MAP_BOUNDS[1] },
  530: { name: t('Terrallende'), image: '/assets/maps/530.jpg?v=1.2.0', width: 3840, height: 2560, ...MAP_BOUNDS[530] },
  571: { name: t('Rasganorte'), image: '/assets/maps/571.jpg?v=1.2.0', width: 3840, height: 2560, ...MAP_BOUNDS[571] },
};

export const state = {
  user: null, players: [], mapPlayers: [], addons: [], patches: [], selectedAddons: new Set(), wowDirectory: null,
  installedAddons: new Map(), installedPatches: new Map(), scanningInstalled: false,
  socialMap: { data: null, character: null }, sort: { key: 'level', direction: -1 },
  help: null, myCharacters: null, currentArmory: null, armoryTab: 'equipped',
  sanctions: null, itemResults: [], selectedItem: null, invites: null,
  modTab: 'character', modCharacter: null, modSearchResults: [], mapFocus: null, helpCategory: '',
  serverConfig: { categories: [], selectedCategoryId: null, category: null, params: [], pending: { changes: [], apply: null }, search: '', searchIndex: null, pollTimer: null },
  updates: { result: null, checking: false, activeGroup: null },
  botOpsTab: 'summary', botOps: { snapshot: null, actions: null, submitting: false },
  metricsTab: 'summary',
};
export const $ = (selector) => document.querySelector(selector);
export const $$ = (selector) => [...document.querySelectorAll(selector)];

// La cabecera va en todas las peticiones: sólo importa en las que escriben
// (el servidor la exige ahí como defensa CSRF), pero es más simple añadirla
// en un único sitio que recordarla en cada llamada mutante.
export async function api(path, options = {}) {
  const response = await fetch(path, { credentials: 'same-origin', headers: { 'Content-Type': 'application/json', 'X-Panel-Request': '1', 'X-Panel-Lang': lang(), ...(options.headers || {}) }, ...options });
  if (response.status === 204) return null;
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.error || t('No se pudo contactar con el servidor'));
    error.status = response.status;
    throw error;
  }
  return data;
}

// evita que una respuesta vieja pise el estado que dejó una
// más reciente a la misma "ranura" (categoría de configuración elegida,
// personaje de armería/mapa social) cuando dos peticiones se solapan y
// llegan en orden distinto al que se pidieron. begin() también sirve para
// invalidar en logout con bump(): una respuesta que llegue después de eso ya
// no encuentra ningún id vigente, aunque no se haya pedido nada nuevo.
export function createRequestSlot() {
  let currentId = 0;
  return { begin: () => ++currentId, isCurrent: (id) => id === currentId, bump: () => { currentId += 1; } };
}
export const armorySlot = createRequestSlot();
export const socialMapSlot = createRequestSlot();
export const serverConfigCategorySlot = createRequestSlot();

export function icon(kind, id, label) {
  return `<svg class="wow-icon" role="img" aria-label="${escapeHtml(label)}"><use href="/assets/icons.svg#${kind}-${id}"></use></svg>`;
}

export function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
}

// Cada módulo de vista se registra aquí (app.js lo rellena tras importarlos
// todos) con las funciones de su ciclo de entrada/salida que necesite el
// resto: enter()/exit() para showView(), render()/load() para refresh().
// Así showView()/refresh()/showLogin() no importan ningún views/*.js
// directamente y no hay ciclo de módulos con ellos.
export const viewRegistry = {};

export function applyModerationVisibility() {
  const level = state.user?.gmlevel || 0;
  $('#moderation-level1').classList.toggle('hidden', level < 1);
  $('#moderation-sanctions').classList.toggle('hidden', level < 1);
  $('#moderation-level2').classList.toggle('hidden', level < 2);
  $('#moderation-level2-general').classList.toggle('hidden', level < 2);
  $('#moderation-level3').classList.toggle('hidden', level < 3);
  $('#moderation-level3-admin').classList.toggle('hidden', level < 3);
}

// perder el rango GM a media sesión sólo puede llegar hoy
// desde una petición GM que devuelva 403 (map.js) mientras el resto del
// sondeo sigue en marcha; centralizado aquí porque antes vivía inline en el
// único catch de refresh() que agrupaba jugadores + mapa.
export function demoteFromGm(message = t('Tu cuenta ya no tiene acceso GM.')) {
  setUser({ ...state.user, gmlevel: 0, isGm: false });
  showToast(message);
}

export function setUser(user) {
  state.user = user;
  $('#account-name').textContent = user.username;
  const rank = user.isGm ? t('Maestro de Juego · Rango {level}', { level: user.gmlevel }) : t('Jugador');
  $('#account-rank').textContent = rank;
  $('#account-avatar').textContent = user.username.slice(0, 1).toUpperCase();
  $('#account-summary-avatar').textContent = user.username.slice(0, 1).toUpperCase();
  $('#account-summary-name').textContent = user.username;
  $('#account-summary-tag').textContent = rank;
  $('#map-nav').classList.toggle('hidden', !user.isGm);
  $('#moderation-nav').classList.toggle('hidden', !user.isGm);
  $('#bot-ops-nav').classList.toggle('hidden', !user.isGm);
  $('#server-config-nav').classList.toggle('hidden', (user.gmlevel || 0) < 3);
  $('#updates-nav').classList.toggle('hidden', (user.gmlevel || 0) < 3);
  $('#gm-nav-label').classList.toggle('hidden', !user.isGm);
  $('#players-actions-head').classList.toggle('hidden', !user.isGm);
  $('#bot-ops-actions-write').classList.toggle('hidden', (user.gmlevel || 0) < 3);
  applyModerationVisibility();
  if (!user.isGm && !$('#map-view').classList.contains('hidden')) showView('players');
  if (!user.isGm && !$('#moderation-view').classList.contains('hidden')) showView('players');
  if (!user.isGm && !$('#bot-ops-view').classList.contains('hidden')) showView('players');
  if ((user.gmlevel || 0) < 3 && !$('#server-config-view').classList.contains('hidden')) showView('players');
  if ((user.gmlevel || 0) < 3 && !$('#updates-view').classList.contains('hidden')) showView('players');
}

export function showApp(user) {
  setUser(user);
  $('#login-view').classList.add('hidden');
  $('#app-view').classList.remove('hidden');
  stopRefreshPolling();
  runRefresh(); // primera pasada inmediata; a partir de ahí se autoprograma
  startServerStatusPolling();
  viewRegistry['client-web']?.refreshPlayNav?.(); // «Jugar en el navegador»: sólo con el cliente base subido y activo
}

export function showLogin() {
  stopRefreshPolling();
  stopServerStatusPolling();
  viewRegistry.metrics?.exit?.(); // cerrar sesión es uno de los motivos explícitos para dejar de muestrear
  clearTimeout(state.serverConfig.pollTimer); // ídem: no seguir preguntando por una solicitud de una sesión ya cerrada
  state.serverConfig.pollTimer = null;
  // Invalida cualquier petición de armería/mapa social/categoría de config que
  // siguiera en vuelo (B1): si llega después de esto, ya no encuentra ningún
  // id vigente y no puede escribir estado de la sesión que se acaba de cerrar.
  armorySlot.bump();
  socialMapSlot.bump();
  serverConfigCategorySlot.bump();
  state.user = null;
  state.help = null;
  state.myCharacters = null;
  state.currentArmory = null;
  state.sanctions = null;
  state.itemResults = [];
  state.selectedItem = null;
  state.invites = null;
  state.updates = { result: null, checking: false, activeGroup: null };
  state.socialMap = { data: null, character: null };
  lastPlayersSignature = null; // fuerza el primer render tras el próximo login (M53)
  $('#app-view').classList.add('hidden');
  $('#register-view').classList.add('hidden');
  $('#login-view').classList.remove('hidden');
  $('#password').value = '';
}

// "unknown" compartía el texto de "online" ("En vivo"), así
// que el HTML inicial y un sondeo fallido se veían igual que un servidor
// realmente en línea. "checking" es el estado antes de la primera respuesta
// válida (arranque de la sesión); "stale" es un sondeo que falló — con o sin
// un estado bueno previo — y se distingue de "En espera"/"Caído" en label,
// clase y color (ver styles.css).
export const SERVER_STATUS_LABELS = {
  online: t('En vivo'),
  standby: t('En espera'),
  offline: t('Caído'),
  checking: t('Comprobando'),
  stale: t('Sin datos'),
};

let serverStatusInFlight = false; // evita dos peticiones a la vez si una tarda más que el intervalo
let serverStatusLastGoodAt = null;

function applyServerStatus(el, key, lastGoodAgoMs) {
  el.dataset.state = key;
  el.querySelector('span').textContent = SERVER_STATUS_LABELS[key] || SERVER_STATUS_LABELS.stale;
  const ageNote = Number.isFinite(lastGoodAgoMs) ? ` ${t('Última comprobación correcta: {ago}.', { ago: formatAgo(lastGoodAgoMs) })}` : '';
  const base = key === 'standby'
    ? t('El worldserver está dormido para ahorrar recursos. La primera conexión de un cliente lo despierta (puede tardar 1-2 min).')
    : key === 'offline'
      ? t('El worldserver no responde.')
      : key === 'checking'
        ? t('Comprobando el estado del worldserver…')
        : key === 'stale'
          ? t('No se ha podido comprobar el estado del worldserver.')
          : t('El worldserver está en línea.');
  el.title = base + ageNote;
}

export async function refreshServerStatus() {
  const el = $('#server-status');
  if (!el || serverStatusInFlight) return;
  serverStatusInFlight = true;
  try {
    const { state: serverState } = await api('/api/server/status');
    const key = SERVER_STATUS_LABELS[serverState] && serverState !== 'checking' && serverState !== 'stale' ? serverState : 'stale';
    serverStatusLastGoodAt = Date.now();
    applyServerStatus(el, key, null);
  } catch {
    // Un fallo puntual del sondeo no debe llenar de toasts, pero tampoco debe
    // dejar el último estado sin marcar como desactualizado.
    applyServerStatus(el, 'stale', serverStatusLastGoodAt ? Date.now() - serverStatusLastGoodAt : null);
  } finally {
    serverStatusInFlight = false;
  }
}

// con 500-600 bots, reconstruir la tabla y recalcular los
// cinco indicadores en cada sondeo (cada 10 s, tanto si algo cambió como si
// no) es el coste dominante del ciclo — la firma es un resumen barato de
// comparar (O(n) en construirla, sin tocar el DOM) frente a eso. El orden
// también forma parte de la firma a propósito: characters está ordenada por
// nivel/nombre en el servidor, así que un cambio de orden es en sí mismo un
// cambio que la tabla debe reflejar.
let lastPlayersSignature = null;
function playersSignature(players) {
  let signature = '';
  for (const player of players) signature += `${player.guid}:${player.level}:${player.type}:${player.class}:${player.race}:${player.role};`;
  return signature;
}

export async function refresh() {
  try {
    const playersData = await api('/api/players');
    state.players = playersData.players;
    const signature = playersSignature(playersData.players);
    if (signature !== lastPlayersSignature) {
      lastPlayersSignature = signature;
      viewRegistry.players?.render?.(playersData.updatedAt);
    }
    // Antes se pedía /api/map/players en cada sondeo aunque el mapa GM
    // estuviera oculto; ahora, como social-map/bot-ops, sólo se pide con la
    // vista abierta — map.js dispara su propia carga inmediata al entrar.
    if (state.user?.isGm && !$('#map-view').classList.contains('hidden')) viewRegistry.map?.load?.();
    if (state.user && !$('#social-map-view').classList.contains('hidden')) viewRegistry['social-map']?.load?.(state.socialMap.character);
    if (state.user?.isGm && !$('#bot-ops-view').classList.contains('hidden')) viewRegistry['bot-ops']?.load?.();
  } catch (error) {
    if (error.status === 401) return showLogin();
    if (error.status === 403) {
      setUser({ ...state.user, gmlevel: 0, isGm: false });
      return showToast(t('Tu cuenta ya no tiene acceso GM.'));
    }
    showToast(error.message);
  }
}

// "refresh" pasa de setInterval (dispara cada 10 s pase lo que
// pase) a autoprogramarse — el siguiente sondeo se planta cuando el anterior
// TERMINA, así que una respuesta lenta nunca hace que dos peticiones queden
// en vuelo a la vez. runRefreshInFlight es además el cerrojo que evita un
// solape si algo (aparte de este propio bucle) llamase a runRefresh() otra
// vez mientras la anterior sigue esperando red.
const REFRESH_INTERVAL_MS = 10_000;
let refreshTimer = null;
let runRefreshInFlight = false;

export function scheduleRefresh(delay = REFRESH_INTERVAL_MS) {
  clearTimeout(refreshTimer);
  refreshTimer = null;
  if (document.hidden) return; // se retoma desde visibilitychange al recuperar la pestaña
  refreshTimer = setTimeout(runRefresh, delay);
}

export async function runRefresh() {
  if (runRefreshInFlight) return;
  runRefreshInFlight = true;
  try {
    await refresh();
  } finally {
    runRefreshInFlight = false;
    scheduleRefresh();
  }
}

export function stopRefreshPolling() {
  clearTimeout(refreshTimer);
  refreshTimer = null;
}

// El indicador global "en vivo/en espera/caído" vive en su propio ciclo,
// separado del de arriba: no debe compartir cadencia con jugadores/mapa (que
// se pueden suspender por vista) ni detenerse por ellos.
const SERVER_STATUS_INTERVAL_MS = 10_000;
let serverStatusTimer = null;

export function startServerStatusPolling() {
  stopServerStatusPolling();
  refreshServerStatus();
  serverStatusTimer = setInterval(refreshServerStatus, SERVER_STATUS_INTERVAL_MS);
}

export function stopServerStatusPolling() {
  clearInterval(serverStatusTimer);
  serverStatusTimer = null;
}

// Alto del contenedor de una vista de mapa = lo que quede de la ventana bajo
// la topbar (que ya está pintada, por eso getBoundingClientRect() basta y no
// hace falta llevar aparte los altos de cabecera/aviso/leyenda,
// 14/09/2026). El CSS reparte ese alto fijo entre la
// cabecera del mapa y el propio mapa (flex-grow), así que crece o encoge solo
// si algún aviso aparece o desaparece.
export function sizeMapView(section) {
  if (section.classList.contains('hidden')) return;
  const top = section.getBoundingClientRect().top;
  const bottomGap = 28;
  section.style.height = `${Math.max(420, window.innerHeight - top - bottomGap)}px`;
}

// Visor de mapa reutilizable: encuadre, zoom con rueda/botones/doble clic,
// arrastre y proyección de marcadores. Lo usan el mapa GM (todo el reino) y el
// mapa social del jugador (su grupo, banda, hermandad y amigos). Cada instancia
// tiene su propio estado de zoom/paneo y sus propios elementos del DOM; lo
// específico de cada uno (marcadores, banner de foco, leyenda) va por opciones.
export function createMapController(refs, options = {}) {
  const view = { zoom: 1, panX: 0, panY: 0, baseWidth: 0, baseHeight: 0 };
  const ctrl = { mapId: 0, view };
  let lastData = { players: [], updatedAt: new Date().toISOString() };

  const currentMap = () => MAPS[ctrl.mapId];

  function fit() {
    const map = currentMap();
    if (!refs.viewport.clientWidth || !refs.viewport.clientHeight) return;
    const scale = Math.min(refs.viewport.clientWidth / map.width, refs.viewport.clientHeight / map.height);
    view.baseWidth = map.width * scale;
    view.baseHeight = map.height * scale;
    applyTransform();
  }

  function maxZoom() {
    const map = currentMap();
    if (!view.baseWidth || !view.baseHeight) return 1;
    return Math.max(1, Math.min(6, map.width / view.baseWidth, map.height / view.baseHeight));
  }

  function clampPan() {
    const scaledWidth = view.baseWidth * view.zoom;
    const scaledHeight = view.baseHeight * view.zoom;
    const maxX = Math.max(0, (scaledWidth - refs.viewport.clientWidth) / 2);
    const maxY = Math.max(0, (scaledHeight - refs.viewport.clientHeight) / 2);
    view.panX = Math.max(-maxX, Math.min(maxX, view.panX));
    view.panY = Math.max(-maxY, Math.min(maxY, view.panY));
  }

  function applyTransform() {
    clampPan();
    const { zoom, panX, panY } = view;
    const width = view.baseWidth * zoom;
    const height = view.baseHeight * zoom;
    const centerX = refs.viewport.clientWidth / 2 + panX;
    const centerY = refs.viewport.clientHeight / 2 + panY;
    refs.stage.style.width = `${width}px`;
    refs.stage.style.height = `${height}px`;
    refs.stage.style.left = `${centerX}px`;
    refs.stage.style.top = `${centerY}px`;
    refs.markers.querySelectorAll('.marker').forEach((marker) => {
      marker.style.left = `${centerX + (Number(marker.dataset.mapX) - .5) * width}px`;
      marker.style.top = `${centerY + (Number(marker.dataset.mapY) - .5) * height}px`;
    });
    refs.zoomLevel.textContent = `${Math.round(zoom * 100)}%`;
    refs.zoomIn.disabled = zoom >= maxZoom() - .001;
    refs.zoomOut.disabled = zoom <= 1.001;
  }

  function resetView() {
    view.zoom = 1;
    view.panX = 0;
    view.panY = 0;
    fit();
  }

  function setZoom(nextZoom, clientX, clientY) {
    const rect = refs.viewport.getBoundingClientRect();
    const oldZoom = view.zoom;
    const zoom = Math.max(1, Math.min(maxZoom(), nextZoom));
    if (zoom === oldZoom) return;
    const pointX = (clientX ?? rect.left + rect.width / 2) - rect.left - rect.width / 2;
    const pointY = (clientY ?? rect.top + rect.height / 2) - rect.top - rect.height / 2;
    view.panX = pointX - ((pointX - view.panX) / oldZoom) * zoom;
    view.panY = pointY - ((pointY - view.panY) / oldZoom) * zoom;
    view.zoom = zoom;
    applyTransform();
  }

  function centerOnMarker(mapX, mapY) {
    view.zoom = Math.max(1, Math.min(maxZoom(), 2));
    view.panX = -(mapX - .5) * view.baseWidth * view.zoom;
    view.panY = -(mapY - .5) * view.baseHeight * view.zoom;
  }

  function render(data) {
    lastData = data;
    const projected = data.players.map(projectMapPlayer);
    const onMapIds = [...new Set(projected.filter((player) => player.onMap).map((player) => player.displayMap))];
    const available = onMapIds.length ? onMapIds : [0, 1, 530, 571];
    if (options.beforeRender) options.beforeRender(projected, available);
    if (!available.includes(ctrl.mapId)) ctrl.mapId = available[0];
    refs.tabs.innerHTML = available.map((id) => `<button class="${id === ctrl.mapId ? 'active' : ''}" data-map="${id}">${MAPS[id].name}</button>`).join('');
    const map = currentMap();
    if (refs.image.dataset.mapId !== String(ctrl.mapId)) {
      refs.image.dataset.mapId = String(ctrl.mapId);
      refs.image.src = map.image;
      resetView();
    }
    refs.image.alt = t('Mapa de {map}', { map: map.name });
    const visible = projected.filter((player) => player.onMap && player.displayMap === ctrl.mapId);
    refs.markers.innerHTML = visible.map((player) => options.buildMarker(player)).join('');
    if (options.afterRender) options.afterRender(projected, visible, { centerOnMarker });
    if (refs.instances) {
      const instances = projected.filter((player) => !player.onMap);
      refs.instances.classList.toggle('hidden', instances.length === 0);
      refs.instances.innerHTML = instances.length
        ? `<strong>${options.instancesLabel || t('En instancias u otros mapas')} (${instances.length}):</strong> ${instances.map((player) => `${escapeHtml(player.name)} <small>[${player.map}]</small>`).join(' · ')}`
        : '';
    }
    if (refs.summary) {
      refs.summary.textContent = t('{count} en {map} · consultado {time}', { count: visible.length, map: map.name, time: formatTime(data.updatedAt) });
    }
    applyTransform();
  }

  const rerender = () => render(lastData);

  refs.viewport.addEventListener('wheel', (event) => {
    event.preventDefault();
    setZoom(view.zoom * (event.deltaY < 0 ? 1.18 : 1 / 1.18), event.clientX, event.clientY);
  }, { passive: false });
  refs.viewport.addEventListener('dblclick', (event) => setZoom(view.zoom * 1.5, event.clientX, event.clientY));
  let drag = null;
  refs.viewport.addEventListener('pointerdown', (event) => {
    if (event.target.closest('.map-controls, .marker')) return;
    drag = { x: event.clientX, y: event.clientY, panX: view.panX, panY: view.panY };
    refs.viewport.setPointerCapture(event.pointerId);
  });
  refs.viewport.addEventListener('pointermove', (event) => {
    if (!drag) return;
    view.panX = drag.panX + event.clientX - drag.x;
    view.panY = drag.panY + event.clientY - drag.y;
    applyTransform();
  });
  refs.viewport.addEventListener('pointerup', () => { drag = null; });
  refs.viewport.addEventListener('pointercancel', () => { drag = null; });
  refs.zoomIn.addEventListener('click', () => setZoom(view.zoom * 1.35));
  refs.zoomOut.addEventListener('click', () => setZoom(view.zoom / 1.35));
  refs.zoomReset.addEventListener('click', resetView);
  refs.image.addEventListener('load', resetView);
  refs.tabs.addEventListener('click', (event) => {
    const button = event.target.closest('[data-map]');
    if (button) { ctrl.mapId = Number(button.dataset.map); rerender(); }
  });

  Object.assign(ctrl, { render, rerender, fit, resetView, setZoom });
  return ctrl;
}

// el menú móvil sólo alternaba la clase; menu-button y el
// cierre por Escape/clic fuera (app.js) necesitan el mismo estado reflejado
// en aria-expanded, así que vive en un único sitio en vez de cada llamante
// tocando la clase por su cuenta.
export function setSidebarOpen(open) {
  $('#sidebar').classList.toggle('open', open);
  $('#menu-button').setAttribute('aria-expanded', String(open));
}

export function showView(name) {
  viewRegistry.players?.closeRowMenu?.();
  $$('.view').forEach((view) => view.classList.add('hidden'));
  $(`#${name}-view`).classList.remove('hidden');
  $$('.nav-item').forEach((button) => button.classList.toggle('active', button.dataset.view === name));
  const titles = { map: t('Mapa del mundo'), 'social-map': t('Mapa'), addons: t('Cliente local'), 'client-web': t('Cliente web'), help: t('Comandos y ayuda'), armory: t('Armería'), moderation: t('Moderación'), account: t('Mi cuenta'), metrics: t('Estado y rendimiento'), 'server-config': t('Configuración del servidor'), updates: t('Actualizaciones'), 'bot-ops': t('Operaciones de bots') };
  $('#page-title').textContent = titles[name] || t('Jugadores conectados');
  setSidebarOpen(false);
  // Al cambiar de menú, la nueva sección arranca visible desde su inicio en
  // vez de heredar el scroll de la anterior. Esta app no tiene navegación "atrás" (sin router ni
  // historial: showView() es la única forma de cambiar de vista), así que no
  // hace falta distinguir ese caso — aquí toda llamada es "ir a una sección",
  // nunca "volver a donde estabas".
  window.scrollTo(0, 0);
  if (name === 'map') viewRegistry.map?.enter?.();
  if (name === 'social-map') viewRegistry['social-map']?.enter?.();
  if (name === 'addons') viewRegistry.addons?.enter?.();
  if (name === 'client-web') viewRegistry['client-web']?.enter?.();
  if (name === 'help') viewRegistry.help?.enter?.();
  if (name === 'armory') viewRegistry.armory?.enter?.();
  if (name === 'moderation') viewRegistry.moderation?.enter?.();
  if (name === 'server-config') viewRegistry['server-config']?.enter?.();
  if (name === 'bot-ops') viewRegistry['bot-ops']?.enter?.();
  // "Estado y rendimiento": pide un estado al entrar y arranca el temporizador
  // de 5 min; cualquier otra vista lo para (cambiar de menú es uno de los
  // motivos para dejar de muestrear).
  if (name === 'metrics') {
    viewRegistry.metrics?.enter?.();
  } else {
    viewRegistry.metrics?.exit?.();
  }
}

let toastTimer;
export function showToast(message, duration = 4000) {
  $('#toast').textContent = message;
  $('#toast').classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => $('#toast').classList.remove('show'), duration);
}

// Aviso cuando el navegador no tiene showDirectoryPicker. Brave la trae desactivada de serie (hay que activarla en brave://flags), así que
// se le dice cómo; el resto de navegadores sin la API (Firefox, Safari) sólo pueden usar Chrome o Edge.
export async function directoryPickerUnavailable() {
  let brave = false;
  try { brave = Boolean(await globalThis.navigator?.brave?.isBrave?.()); } catch { /* sin API de Brave */ }
  showToast(brave
    ? t('Brave trae desactivado el selector de carpetas. Abre brave://flags/#file-system-access-api, ponlo en Enabled y reinicia Brave.')
    : t('El origen ya es seguro, pero este navegador no admite el selector. Usa una versión actual de Chrome o Edge.'), 12000);
}

export function formValues(form) {
  return Object.fromEntries(new FormData(form).entries());
}

// Usado por "Operaciones de bots" (última vez que se agregó el estado) y por
// "Estado y rendimiento" (antigüedad de la última muestra) — 16/09/2026; antes vivían duplicadas, una en cada vista de app.js.
export function formatAgo(ms) {
  if (!Number.isFinite(ms) || ms < 1000) return t('ahora mismo');
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return t('hace {n} s', { n: seconds });
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return t('hace {n} min', { n: minutes });
  return t('hace {n} h', { n: Math.floor(minutes / 60) });
}

export function itemIconHtml(item) {
  const color = QUALITY_COLORS[item.quality] ?? QUALITY_COLORS[1];
  return `<span class="item-icon" style="--item-quality:${color}">
    <img src="/assets/item-icons/${escapeHtml(item.icon)}.webp" alt="" loading="lazy" decoding="async">
    ${item.count > 1 ? `<span class="item-count">${item.count}</span>` : ''}
  </span>`;
}
