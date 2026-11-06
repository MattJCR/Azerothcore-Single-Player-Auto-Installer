// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  authDb as defaultAuthDb, charactersDb as defaultCharactersDb, panelDb as defaultPanelDb,
  worldDb as defaultWorldDb, panelTable,
} from './db.js';
import { config } from './config.js';
import { parseCookie, readSession } from './session.js';
import { addonCatalog, findAddon, sendAddonZip } from './addons.js';
import { createPatchCatalog } from './patches.js';
import { createResourceStore } from './resources.js';
import { createClienteWebStore } from './clienteWeb.js';
import { useIconSource } from './item-icons.js';
import { soapClient as defaultSoapClient } from './soap.js';
import { languageMiddleware, translate } from './i18n.js';
import { registerAuthRoutes } from './routes/auth.js';
import { registerPlayersRoutes } from './routes/players.js';
import { registerSocialMapRoutes } from './routes/socialMap.js';
import { createUpdateChecker } from './updates.js';
import { buildMetricsCache, registerStatusRoutes } from './routes/status.js';
import { registerHelpRoutes } from './routes/help.js';
import { registerCharactersRoutes } from './routes/characters.js';
import { registerModerationRoutes } from './routes/moderation.js';
import { registerItemsRoutes } from './routes/items.js';
import { registerAdminRoutes } from './routes/admin.js';
import { registerServerConfigRoutes } from './routes/serverConfig.js';
import { registerBotOperationsRoutes } from './routes/botOperations.js';
import { registerContentRoutes } from './routes/content.js';
import { registerResourceRoutes } from './routes/resources.js';
import { registerClienteWebRoutes } from './routes/clienteWeb.js';

const root = path.dirname(fileURLToPath(import.meta.url));
const publicDirectory = path.join(root, '..', 'public');

// Imágenes neutras propias, mientras no existan las generadas.
const PLACEHOLDER_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56"><rect width="56" height="56" rx="6" fill="#1c1f26" stroke="#4a4f5c" stroke-width="2"/><text x="28" y="37" font-family="sans-serif" font-size="28" text-anchor="middle" fill="#8a90a0">?</text></svg>';
const MAP_PLACEHOLDER_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2560" viewBox="0 0 3840 2560"><rect width="3840" height="2560" fill="#14171d"/></svg>';

const RATE_LIMIT_WINDOW_MS = 15 * 60_000;
const RATE_LIMIT_SWEEP_MS = 15 * 60_000;

// createApp() inyecta los pools/cliente reales por defecto y acepta
// sustitutos (mocks) en `overrides` para poder arrancar la app en tests sin
// MySQL ni worldserver: createApp({ authDb, charactersDb, worldDb, panelDb, soap }).
export function createApp(overrides = {}) {
  const authDb = overrides.authDb || defaultAuthDb;
  const charactersDb = overrides.charactersDb || defaultCharactersDb;
  const worldDb = overrides.worldDb || defaultWorldDb;
  const panelDb = overrides.panelDb || defaultPanelDb;
  const soap = overrides.soap || defaultSoapClient;
  const checkUpdates = overrides.checkUpdates || createUpdateChecker({
    versionsLockPath: config.versionsLockPath,
    addonsLockPath: config.addonsLockPath,
    addonsCatalogPath: config.addonsCatalogPath,
  });

  // Recursos generados desde el cliente del jugador (iconos, parches de idioma, mapas).
  const resources = overrides.resources || createResourceStore({
    directory: config.resourcesDirectory,
    seedDirectory: config.resourcesSeedDirectory,
    aracDirectory: config.aracInputDirectory,
    python: config.pythonCommand,
    iconsScript: config.iconsScript,
    patchScript: config.patchScript,
  });
  // Cliente base del cliente web (WEB-PANEL): sin WEB_CLIENT_DATA_DIR/WEB_CLIENT_ROOT queda como «no disponible».
  const clienteWeb = overrides.clienteWeb || createClienteWebStore({
    dataDirectory: config.webClient.dataDirectory, root: config.webClient.root, python: config.pythonCommand, manifestScript: config.webClient.manifestScript,
  });
  useIconSource(() => resources.iconManifest());
  const { findPatch, patchCatalog } = createPatchCatalog(resources);

  const app = express();
  const attempts = new Map();

  app.disable('x-powered-by');
  app.set('trust proxy', 'loopback');
  app.use(languageMiddleware);
  app.use((request, response, next) => {
    response.set({
      'Content-Security-Policy': "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; font-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
    });
    if (config.cookieSecure) response.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
  });
  app.use(express.json({ limit: '8kb' }));

  function noStore(response) {
    response.set('Cache-Control', 'no-store');
  }

  function clientKey(request) {
    return request.ip || request.socket.remoteAddress || 'unknown';
  }

  function rateLimited(request) {
    const key = clientKey(request);
    const now = Date.now();
    const recent = (attempts.get(key) || []).filter((time) => now - time < RATE_LIMIT_WINDOW_MS);
    if (recent.length) attempts.set(key, recent); else attempts.delete(key);
    return recent.length >= 10;
  }

  function recordFailure(request) {
    const key = clientKey(request);
    attempts.set(key, [...(attempts.get(key) || []), Date.now()]);
  }

  function clearFailures(request) {
    attempts.delete(clientKey(request));
  }

  // Sin este barrido, una IP que falla una vez y no vuelve deja su clave en
  // el mapa para siempre: fuga de memoria lenta en un proceso de larga
  // duración. unref() para que no impida que el proceso termine en los tests.
  const rateLimitSweep = setInterval(() => {
    const now = Date.now();
    for (const [key, times] of attempts) {
      if (!times.some((time) => now - time < RATE_LIMIT_WINDOW_MS)) attempts.delete(key);
    }
  }, RATE_LIMIT_SWEEP_MS).unref();
  app.locals.rateLimitSweep = rateLimitSweep;

  function requireAuth(request, response, next) {
    const session = readSession(parseCookie(request.headers.cookie), config.sessionSecret);
    if (!session) return response.status(401).json({ error: 'Sesión no válida o caducada' });
    request.session = session;
    next();
  }

  // Un formulario de otro origen nunca puede poner esta cabecera: con
  // SameSite=Strict ya no manda la cookie, y connect-src 'self' impide que el
  // propio navegador de la víctima la añada desde un script ajeno.
  function requireCsrfHeader(request, response, next) {
    if (request.get('X-Panel-Request') !== '1') return response.status(403).json({ error: 'Solicitud no válida' });
    next();
  }

  async function currentGmLevel(accountId) {
    const [rows] = await authDb.execute(
      `SELECT gmlevel FROM account_access
       WHERE id = ? AND RealmID IN (-1, ?)
       ORDER BY RealmID DESC LIMIT 1`,
      [accountId, config.realmId],
    );
    return Number(rows[0]?.gmlevel || 0);
  }

  function requireGmLevel(min, message) {
    return async (request, response, next) => {
      try {
        const gmlevel = await currentGmLevel(request.session.sub);
        if (gmlevel < min) return response.status(403).json({ error: message || 'No tienes permiso suficiente' });
        request.gmlevel = gmlevel;
        next();
      } catch (error) {
        next(error);
      }
    };
  }
  const requireGm = requireGmLevel(1, 'Se requiere una cuenta GM');

  // Mismo criterio que mod-home-guild en C++ (IsRandomBotAccount): prefijo
  // configurable seguido sólo de dígitos, sobre acore_auth.account.username.
  // Sólo consulta las cuentas de los personajes online (accountIds), nunca la
  // tabla completa. LIKE escapado porque el prefijo es configurable.
  function likeEscape(value) {
    return value.replace(/[\\%_]/g, (char) => `\\${char}`);
  }

  async function botAccountIdSet(accountIds) {
    const uniqueIds = [...new Set(accountIds)];
    if (!uniqueIds.length) return new Set();
    const prefixLower = config.botAccountPrefix.toLowerCase();
    const digitsAfterPrefix = /^[0-9]+$/;
    const [rows] = await authDb.query(
      'SELECT id, username FROM account WHERE id IN (?) AND username LIKE ?',
      [uniqueIds, `${likeEscape(config.botAccountPrefix)}%`],
    );
    return new Set(
      rows
        .filter((row) => {
          const username = String(row.username).toLowerCase();
          return username.startsWith(prefixLower) && digitsAfterPrefix.test(username.slice(prefixLower.length));
        })
        .map((row) => Number(row.id)),
    );
  }

  // "Estado y rendimiento"/"En vivo": lógica propia extraída a
  // routes/status.js; aquí sólo se decide si usar la caché
  // real o una de test (overrides.metricsCache, como ya hacían los tests de
  // metrics-status.test.js antes de esta extracción).
  const metricsCache = overrides.metricsCache || buildMetricsCache({ worldDb, charactersDb, panelDb, botAccountIdSet });

  async function audit({ actorAccount, actorName, action, target, detail, result, ip }) {
    try {
      await panelDb.execute(
        'INSERT INTO panel_audit (at, actor_account, actor_name, action, target, detail, result, ip) VALUES (NOW(), ?, ?, ?, ?, ?, ?, ?)',
        [actorAccount ?? null, actorName ?? null, action, target ?? null, detail ?? null, result, ip ?? null],
      );
    } catch (error) {
      console.error(`[${new Date().toISOString()}] fallo al auditar ${action}`, error);
    }
  }

  app.get('/api/health', async (_request, response, next) => {
    try {
      await Promise.all([authDb.query('SELECT 1'), charactersDb.query('SELECT 1')]);
      response.json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });

  // Sesión y cuenta (login/logout/me/registro/cambio de contraseña),
  // extraídas a routes/auth.js.
  registerAuthRoutes(app, {
    authDb, config, panelTable, requireAuth, requireCsrfHeader, noStore,
    rateLimited, recordFailure, clearFailures, currentGmLevel, audit, clientKey,
  });

  // Addons/parches del cliente, extraídos a routes/content.js.
  registerContentRoutes(app, { requireAuth, noStore, addonCatalog, findAddon, sendAddonZip, findPatch, patchCatalog });

  // Preparación de recursos desde el cliente del jugador (PUB04-I): sólo administradores.
  registerResourceRoutes(app, {
    requireAuth, requireAdmin: requireGmLevel(3, 'Se requiere una cuenta de administrador'), requireCsrfHeader, noStore, audit, clientKey, resources,
  });

  // Cliente base del cliente web (WEB-PANEL): estado para todas las cuentas, subida y activación sólo para administradores.
  registerClienteWebRoutes(app, {
    requireAuth, requireAdmin: requireGmLevel(3, 'Se requiere una cuenta de administrador'), requireCsrfHeader, noStore, audit, clientKey, currentGmLevel, clienteWeb,
  });

  // Jugadores conectados y mapa GM, extraídos a routes/players.js.
  registerPlayersRoutes(app, { charactersDb, botAccountIdSet, requireAuth, requireGm, noStore });

  // Mapa social del jugador, extraído a routes/socialMap.js.
  registerSocialMapRoutes(app, { charactersDb, requireAuth, noStore });

  // "En vivo/En espera/Caído" y "Estado y rendimiento", extraídos a
  // routes/status.js.
  registerStatusRoutes(app, { requireAuth, noStore, soap, panelDb, metricsCache });

  // Comandos y ayuda, extraídos a routes/help.js.
  registerHelpRoutes(app, { worldDb, currentGmLevel, requireAuth, noStore });

  // Búsqueda de personajes, mis personajes y armería, extraídos a routes/characters.js.
  registerCharactersRoutes(app, { authDb, charactersDb, currentGmLevel, requireAuth, noStore });

  // Moderación (expulsar/silenciar/banear/anunciar/correo) y sanciones
  // vigentes, extraídas a routes/moderation.js.
  registerModerationRoutes(app, {
    authDb, charactersDb, soap, requireAuth, requireGmLevel, requireCsrfHeader, noStore, audit, clientKey, currentGmLevel,
  });

  // Buscador de objetos para el correo de moderación, extraído a routes/items.js.
  registerItemsRoutes(app, { worldDb, requireAuth, requireGmLevel, noStore });

  // Configuración del servidor, extraída a routes/serverConfig.js.
  // requireAdmin se queda aquí: también lo usan routes/admin.js y
  // /api/updates/check, que no forman parte de esa extracción.
  const requireAdmin = requireGmLevel(3, 'Se requiere una cuenta de administrador');
  registerServerConfigRoutes(app, { requireAuth, requireAdmin, requireCsrfHeader, noStore, audit, clientKey, panelDb });

  // Administración (invitaciones, alta de cuentas) y comprobación de
  // actualizaciones, extraídas a routes/admin.js.
  registerAdminRoutes(app, {
    authDb, panelDb, requireAuth, requireAdmin, requireCsrfHeader, noStore, audit, clientKey, checkUpdates,
  });

  // Operaciones de bots, extraída a routes/botOperations.js.
  registerBotOperationsRoutes(app, { requireAuth, requireGm, requireGmLevel, requireCsrfHeader, noStore, audit, clientKey, worldDb });

  // Iconos y mapas generados: del almacén de recursos; si faltan (todavía no se
  // han preparado desde el cliente) se sirve un SVG genérico en vez de una imagen rota.
  app.use('/assets/item-icons', express.static(resources.iconsDirectory, { immutable: true, maxAge: '7d', index: false, fallthrough: true }));
  app.use('/assets/maps', express.static(resources.mapsDirectory, { maxAge: '1h', index: false, fallthrough: true }));
  app.use('/assets/item-icons', (_request, response) => { response.set('Cache-Control', 'no-store').type('image/svg+xml').send(PLACEHOLDER_SVG); });
  app.use('/assets/maps', (_request, response) => { response.set('Cache-Control', 'no-store').type('image/svg+xml').send(MAP_PLACEHOLDER_SVG); });
  app.use('/assets', express.static(path.join(publicDirectory, 'assets'), { immutable: true, maxAge: '7d', index: false }));
  app.use('/vendor/jszip', express.static(path.join(root, '..', 'node_modules', 'jszip', 'dist'), { immutable: true, maxAge: '7d', index: false }));
  app.use(express.static(publicDirectory, { index: false, maxAge: '1h' }));
  app.get('/{*path}', (request, response) => {
    if (request.path.startsWith('/api/')) return response.status(404).json({ error: 'Endpoint no encontrado' });
    if (path.extname(request.path)) return response.status(404).type('text').send(translate('Recurso no encontrado', request.lang));
    response.sendFile(path.join(publicDirectory, 'index.html'));
  });

  app.use((error, request, response, _next) => {
    console.error(`[${new Date().toISOString()}] ${request.method} ${request.path}`, error);
    if (response.headersSent) return;
    response.status(500).json({ error: 'Error interno del panel' });
  });

  return app;
}
