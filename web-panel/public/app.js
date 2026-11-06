// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Punto de entrada del panel: importa el estado/utilidades compartidas y
// cada módulo de vista (public/views/*.js), los registra en viewRegistry
// para que showView()/refresh()/showLogin() (shared.js) lleguen a ellos sin
// que shared.js tenga que importarlos, y conecta lo que de verdad es del
// "shell" (login/registro, navegación, indicador de conexión perdida y el
// arranque de la sesión) — 16/09/2026: antes todo esto
// vivía en un único fichero de 2563 líneas.
import { t } from './i18n.js';
import {
  $, $$, state, api, showApp, showLogin, showView, viewRegistry, sizeMapView, setSidebarOpen,
  stopRefreshPolling, stopServerStatusPolling, runRefresh, startServerStatusPolling,
} from './shared.js';

import * as playersView from './views/players.js';
import * as mapView from './views/map.js';
import * as socialMapView from './views/socialMap.js';
import * as addonsView from './views/addons.js';
import * as clientWebView from './views/clientWeb.js';
import * as helpView from './views/help.js';
import * as armoryView from './views/armory.js';
import * as moderationView from './views/moderation.js';
import * as serverConfigView from './views/serverConfig.js';
import * as updatesView from './views/updates.js';
import * as botOpsView from './views/botOps.js';
import * as metricsView from './views/metrics.js';
import './views/account.js'; // sólo registra su propio formulario; nada que exponer

Object.assign(viewRegistry, {
  players: playersView,
  map: mapView,
  'social-map': socialMapView,
  addons: addonsView,
  'client-web': clientWebView,
  help: helpView,
  armory: armoryView,
  moderation: moderationView,
  'server-config': serverConfigView,
  updates: updatesView,
  'bot-ops': botOpsView,
  metrics: metricsView,
});

$('#login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('#login-button');
  $('#login-error').textContent = '';
  button.disabled = true;
  button.textContent = t('Comprobando…');
  try {
    const data = await api('/api/login', { method: 'POST', body: JSON.stringify({ username: $('#username').value, password: $('#password').value }) });
    showApp(data.user);
  } catch (error) {
    $('#login-error').textContent = error.message;
  } finally {
    button.disabled = false;
    button.textContent = t('Entrar al reino');
  }
});

$('#logout-button').addEventListener('click', async () => { try { await api('/api/logout', { method: 'POST' }); } finally { showLogin(); } });
$$('.nav-item').forEach((button) => button.addEventListener('click', () => showView(button.dataset.view)));

// El enlace «Jugar en el navegador» (cliente web, fase 10 del instalador, opcional) lo decide views/clientWeb.js (refreshPlayNav) al entrar.

// antes sólo alternaba la clase, sin aria-expanded, sin cierre
// por Escape y sin cierre al pulsar fuera (a diferencia del menú de acciones
// por fila, que ya tenía las tres cosas).
$('#menu-button').addEventListener('click', () => setSidebarOpen(!$('#sidebar').classList.contains('open')));
document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || !$('#sidebar').classList.contains('open')) return;
  setSidebarOpen(false);
  $('#menu-button').focus();
});
document.addEventListener('click', (event) => {
  if (!$('#sidebar').classList.contains('open')) return;
  if (event.target.closest('#sidebar, #menu-button')) return;
  setSidebarOpen(false);
});
window.addEventListener('resize', () => {
  sizeMapView($('#map-view'));
  sizeMapView($('#social-map-view'));
  mapView.fit();
  socialMapView.fit();
});

$('#show-register').addEventListener('click', () => {
  $('#login-view').classList.add('hidden');
  $('#register-view').classList.remove('hidden');
});
$('#show-login').addEventListener('click', () => {
  $('#register-view').classList.add('hidden');
  $('#login-view').classList.remove('hidden');
});
$('#register-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('#register-button');
  $('#register-error').textContent = '';
  button.disabled = true;
  button.textContent = t('Creando…');
  try {
    const data = await api('/api/register', { method: 'POST', body: JSON.stringify({
      inviteCode: $('#register-invite').value, username: $('#register-username').value, password: $('#register-password').value,
    }) });
    showApp(data.user);
  } catch (error) {
    $('#register-error').textContent = error.message;
  } finally {
    button.disabled = false;
    button.textContent = t('Crear cuenta');
  }
});

// Perder la pestaña de vista (cambiar de ventana, minimizar) para el
// muestreo de "Estado y rendimiento"; recuperarla lo retoma:
// mismo trato para el sondeo general de jugadores/mapa y el indicador de
// estado del servidor — ninguno de los dos debe seguir consultando con la
// pestaña oculta, y ambos se retoman al volver. Sólo aplica con sesión
// iniciada: showLogin() ya los para explícitamente.
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    metricsView.exit();
  } else if (!$('#metrics-view').classList.contains('hidden')) {
    metricsView.enter();
  }
  if (!state.user) return;
  if (document.hidden) {
    stopRefreshPolling();
    stopServerStatusPolling();
  } else {
    runRefresh();
    startServerStatusPolling();
  }
});

api('/api/me').then((data) => showApp(data.user)).catch(() => showLogin());
