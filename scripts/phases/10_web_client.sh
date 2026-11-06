#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#  10_web_client.sh — Cliente web del navegador en /play/ (opcional)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"

header "FASE 10 — Cliente web del navegador"

if [ "${INSTALL_WEB_CLIENT:-false}" != true ]; then
    info "INSTALL_WEB_CLIENT=false: se omite el cliente web (opcional; ver INSTALL_ES.md)."
    exit 0
fi

if [ "${INSTALL_WEB_PANEL:-true}" != true ]; then
    error "El cliente web se publica con el nginx del panel: activa INSTALL_WEB_PANEL=true."
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/web-client/deploy.sh" ]; then
    error "No existe web-client/deploy.sh en el instalador."
    exit 1
fi

if [ -z "${WEB_CLIENT_BUILD_DIR:-}" ] || [ ! -d "${WEB_CLIENT_BUILD_DIR}" ]; then
    warn "WEB_CLIENT_BUILD_DIR no está definido o no existe: no hay build del cliente web que desplegar. Se omite."
    warn "El instalador no trae el cliente: aporta tu propio build (ver INSTALL_ES.md, «Cliente web»)."
    exit 0
fi

# El despliegue escribe en /etc, /opt y systemd: necesita root (igual que la fase 9).
if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    error "La fase 10 necesita sudo sin contraseña o ejecutarse como root."
    error "  - Interactivo:      sudo ./install.sh --webclient"
    exit 1
fi

info "Desplegando el cliente web desde ${WEB_CLIENT_BUILD_DIR}…"
export WEB_CLIENT_BUILD_DIR WEB_CLIENT_DATA_DIR WEB_CLIENT_ROOT WEB_CLIENT_BRIDGE_PORT WEB_CLIENT_AUTH_PORT WEB_CLIENT_WORLD_PORT WEB_CLIENT_WAKE_WAIT
if [ "$(id -u)" -eq 0 ]; then
    bash "$SCRIPT_DIR/web-client/deploy.sh"
else
    sudo -E bash "$SCRIPT_DIR/web-client/deploy.sh"
fi
log "Cliente web instalado o actualizado."
