// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
import express from 'express';
import { ClienteWebError, LIMITS } from '../clienteWeb.js';

// Cliente base del cliente web (WEB-PANEL, paso 0). El estado lo ve cualquier cuenta (decide si el menú ofrece «Jugar en el
// navegador»); subir, activar y cancelar son sólo de administradores, con la cabecera anti-CSRF.
export function registerClienteWebRoutes(app, { requireAuth, requireAdmin, requireCsrfHeader, noStore, audit, clientKey, currentGmLevel, clienteWeb }) {
  const base = '/api/cliente-web';
  const record = (request, action, target, detail, result = 'ok') => audit({
    actorAccount: request.session.sub, actorName: request.session.username, action, target, detail, result, ip: clientKey(request),
  });

  function handle(action) {
    return async (request, response, next) => {
      try {
        await action(request, response);
      } catch (error) {
        if (error instanceof ClienteWebError) return response.status(error.status).json({ error: error.message, ...error.extra });
        next(error);
      }
    };
  }

  app.get(`${base}/estado`, requireAuth, handle(async (request, response) => {
    noStore(response);
    const admin = (await currentGmLevel(request.session.sub)) >= 3;
    response.json({ ...clienteWeb.status({ admin }), esAdmin: admin });
  }));

  app.post(`${base}/subida`, requireAuth, requireAdmin, requireCsrfHeader, handle(async (request, response) => {
    noStore(response);
    const { archivos, borrarAntes, reiniciar } = request.body || {};
    const result = await clienteWeb.startUpload({ archivos, borrarAntes: borrarAntes === true, reiniciar: reiniciar === true });
    if (!result.reanudada) await record(request, 'cliente-web-subida-iniciar', result.sesion.id, `${result.sesion.archivos.length} ficheros${borrarAntes === true ? ', borrando el anterior' : ''}`);
    response.status(result.reanudada ? 200 : 201).json(result);
  }));

  app.put(`${base}/subida/archivo`, requireAuth, requireAdmin, requireCsrfHeader,
    express.raw({ type: 'application/octet-stream', limit: LIMITS.chunkBytes + 1024 }),
    handle(async (request, response) => {
      noStore(response);
      response.json(await clienteWeb.receiveChunk({
        ruta: String(request.query.ruta || ''), desde: Number(request.query.desde), datos: request.body, sha256: request.get('X-Chunk-Sha256'),
      }));
    }));

  app.post(`${base}/subida/confirmar`, requireAuth, requireAdmin, requireCsrfHeader, handle(async (request, response) => {
    noStore(response);
    const result = await clienteWeb.commit();
    await record(request, 'cliente-web-subida-confirmar', null, `${result.base?.ficheros ?? 0} ficheros`);
    response.json(result);
  }));

  app.delete(`${base}/subida`, requireAuth, requireAdmin, requireCsrfHeader, handle(async (request, response) => {
    noStore(response);
    const result = await clienteWeb.cancel();
    await record(request, 'cliente-web-subida-cancelar', null, null);
    response.json(result);
  }));

  app.post(`${base}/activo`, requireAuth, requireAdmin, requireCsrfHeader, handle(async (request, response) => {
    noStore(response);
    if (typeof request.body?.activo !== 'boolean') throw new ClienteWebError('Falta «activo» (true o false).');
    const result = clienteWeb.setActive(request.body.activo);
    await record(request, request.body.activo ? 'cliente-web-activar' : 'cliente-web-desactivar', null, null);
    response.json(result);
  }));
}
