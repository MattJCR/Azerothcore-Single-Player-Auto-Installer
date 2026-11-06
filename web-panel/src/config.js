// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const identifier = /^[A-Za-z0-9_]+$/;

function integer(name, fallback, min = 0, max = 65535) {
  const value = Number.parseInt(process.env[name] ?? String(fallback), 10);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} debe ser un entero entre ${min} y ${max}`);
  }
  return value;
}

function databaseName(name, fallback) {
  const value = process.env[name] || fallback;
  if (!identifier.test(value)) throw new Error(`${name} contiene caracteres no válidos`);
  return value;
}

const production = process.env.NODE_ENV === 'production';
const sessionSecret = process.env.SESSION_SECRET || (production ? '' : 'development-only-secret-change-me');
if (sessionSecret.length < 32) throw new Error('SESSION_SECRET debe tener al menos 32 caracteres');

export const config = Object.freeze({
  production,
  host: process.env.HOST || '127.0.0.1',
  port: integer('PORT', 3000, 1),
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: integer('DB_PORT', 3306, 1),
    user: process.env.DB_USER || 'acore_panel',
    password: process.env.DB_PASSWORD || '',
    authDatabase: databaseName('AUTH_DATABASE', 'acore_auth'),
    charactersDatabase: databaseName('CHARACTERS_DATABASE', 'acore_characters'),
    worldDatabase: databaseName('WORLD_DATABASE', 'acore_world'),
    panelDatabase: databaseName('PANEL_DATABASE', 'acore_panel'),
  },
  realmId: integer('REALM_ID', 1, 1, 2147483647),
  sessionSecret,
  sessionTtl: integer('SESSION_TTL_SECONDS', 28800, 300, 604800),
  cookieSecure: process.env.COOKIE_SECURE === 'true',
  addonsDirectory: process.env.ADDONS_DIRECTORY || fileURLToPath(new URL('../../cliente/Interface/AddOns/', import.meta.url)),
  clientDataDirectory: process.env.CLIENT_DATA_DIRECTORY || fileURLToPath(new URL('../../cliente/Data/', import.meta.url)),
  // Recursos generados desde el cliente del jugador (iconos, parches de idioma,
  // mapas): el panel los escribe aquí y desde aquí los sirve. En producción lo fija
  // /etc/azerothcore-panel.env (carpeta de estado del servicio); en desarrollo y
  // pruebas, una carpeta temporal.
  resourcesDirectory: process.env.RESOURCES_DIRECTORY || path.join(os.tmpdir(), 'azerothcore-panel-recursos'),
  // Datos ya preparados (instalación con ellos): se incorporan la primera vez.
  resourcesSeedDirectory: process.env.RESOURCES_SEED_DIRECTORY || '',
  // DBC de mod-arac verificados por el instalador; vacío = el generador usa mirrors/.
  aracInputDirectory: process.env.ARAC_INPUT_DIRECTORY || '',
  pythonCommand: process.env.PYTHON_COMMAND || (process.platform === 'win32' ? 'python' : 'python3'),
  iconsScript: process.env.ICONS_SCRIPT || fileURLToPath(new URL('../tools/extract-item-icons.py', import.meta.url)),
  patchScript: process.env.PATCH_SCRIPT || fileURLToPath(new URL('../../tools/construir-parche-cliente-items.py', import.meta.url)),
  // Cliente web (/play/): carpeta Data del cliente base y carpeta de estado de web-client/deploy.sh. Vacíos = la pantalla «Cliente web» no
  // ofrece subir el cliente base. En la VM los fija /etc/azerothcore-panel.env (el servicio escribe ahí por el grupo del usuario de AzerothCore).
  webClient: {
    dataDirectory: process.env.WEB_CLIENT_DATA_DIR || '',
    root: process.env.WEB_CLIENT_ROOT || '',
    manifestScript: process.env.WEB_CLIENT_MANIFEST_SCRIPT || fileURLToPath(new URL('../../web-client/generar-manifiesto.py', import.meta.url)),
  },
  // Ninguno de los dos tiene valor por defecto local: sólo existen en la VM
  // (montados de sólo lectura para el proceso del panel, ver BindReadOnlyPaths
  // en azerothcore-panel.service). Sin ellos, la lectura del valor actual de
  // un parámetro cae al valor por defecto del catálogo — ver serverConfigFiles.js.
  worldserverConfPath: process.env.WORLDSERVER_CONF_PATH || '',
  moduleConfDirectory: process.env.MODULE_CONF_DIRECTORY || '',
  // Sólo existe en la VM (BindReadOnlyPaths en azerothcore-panel.service,
  // igual que los dos de arriba): "Estado y rendimiento" lo usa para contar
  // avisos de "Tick lento" (SlowTick.h) del arranque actual de worldserver.
  worldserverLogPath: process.env.WORLDSERVER_LOG_PATH || '',
  versionsLockPath: process.env.VERSIONS_LOCK_PATH || fileURLToPath(new URL('../../versions.lock', import.meta.url)),
  addonsLockPath: process.env.ADDONS_LOCK_PATH || fileURLToPath(new URL('../../addons.lock', import.meta.url)),
  addonsCatalogPath: process.env.ADDONS_CATALOG_PATH || fileURLToPath(new URL('../addons/catalog.json', import.meta.url)),
  // Modo en espera (WORLDSERVER_STANDBY en config.sh): con esto activo el
  // worldserver se apaga solo cuando no hay nadie. El panel lo usa para
  // distinguir "en espera" de "caído" cuando SOAP no responde, y para leer el
  // fichero de estado que dejan las unidades systemd.
  standby: {
    enabled: process.env.WORLDSERVER_STANDBY === 'true',
    statePath: process.env.WORLDSERVER_STATE_PATH || '/run/azerothcore/worldserver.state',
  },
  // Prefijo de cuentas de bot que ya usa mod-playerbots (Playerbots.RandomBotAccountPrefix
  // en worldserver.conf, por defecto "rndbot" seguido sólo de dígitos — mismo
  // criterio que modules/mod-home-guild/src/mod_home_guild.cpp:IsRandomBotAccount).
  // El panel no lee C++ ni el .conf: sólo necesita el mismo prefijo para
  // clasificar Jugador/Bot en /api/players sin exponer eso al navegador.
  botAccountPrefix: process.env.BOT_ACCOUNT_PREFIX || 'rndbot',
  soap: {
    host: process.env.SOAP_HOST || '127.0.0.1',
    port: integer('SOAP_PORT', 7878, 1),
    username: process.env.SOAP_USERNAME || '',
    password: process.env.SOAP_PASSWORD || '',
    timeoutMs: integer('SOAP_TIMEOUT_MS', 5000, 100, 60000),
    get configured() {
      return Boolean(this.username && this.password);
    },
  },
});
