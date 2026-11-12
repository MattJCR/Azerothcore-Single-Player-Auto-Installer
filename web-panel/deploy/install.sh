#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecuta este instalador con sudo: sudo bash web-panel/deploy/install.sh" >&2
    exit 1
fi

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$DEPLOY_DIR/.." && pwd)"
REPO_DIR="$(cd "$SOURCE_DIR/.." && pwd)"
CONFIG_FILE="${AZEROTHCORE_CONFIG:-$REPO_DIR/config.sh}"

if [ -f "$CONFIG_FILE" ]; then
    ORIGINAL_HOME="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
    # Sólo se consumen las variables de base de datos; HOME correcto evita
    # efectos sorprendentes al evaluar los valores de config.sh.
    HOME="$ORIGINAL_HOME" source "$CONFIG_FILE"
fi

AUTH_DB="${PANEL_AUTH_DATABASE:-acore_auth}"
CHARACTERS_DB="${PANEL_CHARACTERS_DATABASE:-acore_characters}"
WORLD_DB="${PANEL_WORLD_DATABASE:-acore_world}"
PANEL_DB="${PANEL_PANEL_DATABASE:-acore_panel}"
REALM_ID="${PANEL_REALM_ID:-1}"
HTTP_PORT="${PANEL_HTTP_PORT:-80}"
HTTPS_PORT="${PANEL_HTTPS_PORT:-443}"
DB_USER="${PANEL_DB_USER:-acore_panel}"
SOAP_ACCOUNT="${PANEL_SOAP_ACCOUNT:-panel_soap}"
# Cuenta de BD del propio AzerothCore (config.sh): el script privilegiado
# apply-panel-config.sh la reutiliza para leer/limpiar la cola de
# configuración pendiente, en vez de crear una credencial nueva.
AC_DB_USER="${AC_DB_USER:-acore}"
# Rutas reales de los .conf (mismo cálculo que 05_configure_server.sh). El
# panel sólo las LEE (BindReadOnlyPaths en el .service, más abajo): nunca
# escribe aquí, eso es trabajo exclusivo de apply-panel-config.sh.
AC_DIR="${AC_DIR:-$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/azerothcore}"
ETC_DIR="$AC_DIR/env/dist/etc"
MOD_CONF_DIR="$ETC_DIR/modules"
# Server.log vive junto al binario: mismo motivo que ETC_DIR, el panel lo lee
# de sólo lectura para "Estado y rendimiento" (ticks lentos), nunca escribe.
LOG_DIR="$AC_DIR/env/dist/bin"
# worldserver.conf y los .conf de módulo son 640 (dueño:grupo, sin permiso
# para "otros"): el DynamicUser del panel necesita ser miembro de ese grupo
# para poder leerlos a través del bind mount de sólo lectura, ver más abajo.
AC_GROUP="$(stat -c '%G' "$ETC_DIR")"
AC_OWNER="$(stat -c '%U' "$AC_DIR")"
# Cliente web (/play/): carpeta de estado y carpeta del cliente base (WEB-PANEL). Por defecto, la base vive dentro de la de estado.
WEB_ROOT="${WEB_CLIENT_ROOT:-/var/lib/azerothcore-play}"
WEB_DATA="${WEB_CLIENT_DATA_DIR:-$WEB_ROOT/base}"
if [ "${INSTALL_WEB_CLIENT:-false}" = true ]; then
    for web_path in "$WEB_ROOT" "$WEB_DATA"; do
        case "$web_path" in /*) ;; *) echo "WEB_CLIENT_ROOT y WEB_CLIENT_DATA_DIR deben ser rutas absolutas ('$web_path')." >&2; exit 1 ;; esac
        case "$web_path" in /|/home/*|*[!A-Za-z0-9_./-]*) echo "WEB_CLIENT_ROOT y WEB_CLIENT_DATA_DIR: sin espacios ni símbolos y fuera de /home ('$web_path')." >&2; exit 1 ;; esac
    done
fi

for name in "$AUTH_DB" "$CHARACTERS_DB" "$WORLD_DB" "$PANEL_DB" "$DB_USER" "$SOAP_ACCOUNT" "$AC_DB_USER"; do
    if [[ ! "$name" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "Nombre de base de datos/usuario/cuenta no válido: $name" >&2
        exit 1
    fi
done
if [[ ! "$REALM_ID" =~ ^[1-9][0-9]*$ ]] || [[ ! "$HTTP_PORT" =~ ^[0-9]+$ ]] || [[ ! "$HTTPS_PORT" =~ ^[0-9]+$ ]] || [ "$HTTP_PORT" -lt 1 ] || [ "$HTTP_PORT" -gt 65535 ] || [ "$HTTPS_PORT" -lt 1 ] || [ "$HTTPS_PORT" -gt 65535 ] || [ "$HTTP_PORT" = "$HTTPS_PORT" ]; then
    echo "PANEL_REALM_ID, PANEL_HTTP_PORT o PANEL_HTTPS_PORT no es válido." >&2
    exit 1
fi

echo "[1/8] Instalando Node.js, Nginx y herramientas…"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm nginx openssl rsync curl git >/dev/null

NODE_MAJOR="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "Se necesita Node.js 18.18 o posterior (instalado: $(node --version))." >&2
    exit 1
fi

echo "[2/8] Verificando las bases de datos…"
mysql -NBe "SELECT 1 FROM \`$AUTH_DB\`.account LIMIT 1; SELECT 1 FROM \`$CHARACTERS_DB\`.characters LIMIT 1; SELECT 1 FROM \`$WORLD_DB\`.item_template LIMIT 1;" >/dev/null

# El panel y mod-server-help comparten este esquema. Aplicarlo también aquí
# evita que desplegar sólo el panel deje durante horas un backend nuevo leyendo
# una tabla antigua (por ejemplo, antes de que el worldserver vuelva a arrancar).
HELP_SQL="$REPO_DIR/modules/mod-server-help/data/sql/db-world/base/server_help.sql"
if [ -f "$HELP_SQL" ]; then
    mysql "$WORLD_DB" < "$HELP_SQL"
else
    echo "No se encuentra la semilla de mod-server-help: $HELP_SQL" >&2
    exit 1
fi

echo "[3/8] Creando la base del panel y las credenciales…"
ENV_FILE="/etc/azerothcore-panel.env"
DB_PASSWORD=""
SESSION_SECRET=""
if [ -f "$ENV_FILE" ]; then
    DB_PASSWORD="$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE" | head -n 1)"
    SESSION_SECRET="$(sed -n 's/^SESSION_SECRET=//p' "$ENV_FILE" | head -n 1)"
fi
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -hex 24)}"
SESSION_SECRET="${SESSION_SECRET:-$(openssl rand -hex 48)}"
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$PANEL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_invite (
  code_hash CHAR(64) NOT NULL,
  created_by VARCHAR(32) NOT NULL,
  created_at DATETIME NOT NULL,
  expires_at DATETIME NULL,
  used_by_account INT UNSIGNED NULL,
  used_at DATETIME NULL,
  note VARCHAR(255) NULL,
  PRIMARY KEY (code_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_audit (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  at DATETIME NOT NULL,
  actor_account INT UNSIGNED NULL,
  actor_name VARCHAR(32) NULL,
  action VARCHAR(32) NOT NULL,
  target VARCHAR(64) NULL,
  detail VARCHAR(500) NULL,
  result VARCHAR(16) NOT NULL,
  ip VARCHAR(45) NULL,
  PRIMARY KEY (id),
  INDEX idx_panel_audit_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Pantalla de configuración del servidor (administrador): el panel sólo
-- encola aquí, nunca escribe en disco ni reinicia. Sin DELETE para el
-- usuario del panel (ver GRANT más abajo): descartar un cambio es un UPDATE
-- de status, y quien limpia filas ya aplicadas/descartadas es el script
-- privilegiado (apply-panel-config.sh), que se conecta con AC_DB_USER.
CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_config_pending (
  key_name VARCHAR(120) NOT NULL,
  file_name VARCHAR(80) NOT NULL,
  category_id VARCHAR(60) NOT NULL,
  new_value VARCHAR(255) NOT NULL,
  revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
  risk VARCHAR(16) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  created_by VARCHAR(32) NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (key_name, file_name),
  INDEX idx_panel_config_pending_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CREATE TABLE IF NOT EXISTS no amplía instalaciones anteriores a la revisión
-- por lote. Mismo patrón de sentencia preparada que usa
-- mod-server-help/data/sql/db-world/base/server_help.sql, idempotente en
-- MySQL 8 y MariaDB.
SET @panel_config_pending_has_revision := (
  SELECT COUNT(*) FROM \`information_schema\`.\`COLUMNS\`
  WHERE \`TABLE_SCHEMA\` = '$PANEL_DB' AND \`TABLE_NAME\` = 'panel_config_pending' AND \`COLUMN_NAME\` = 'revision'
);
SET @panel_config_pending_add_revision := IF(
  @panel_config_pending_has_revision = 0,
  'ALTER TABLE \`$PANEL_DB\`.panel_config_pending ADD COLUMN revision BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER new_value',
  'SELECT 1'
);
PREPARE panel_config_pending_migration FROM @panel_config_pending_add_revision;
EXECUTE panel_config_pending_migration;
DEALLOCATE PREPARE panel_config_pending_migration;

-- Fuente de la revisión de arriba: patrón UPDATE ... SET n = LAST_INSERT_ID(n
-- + 1), atómico bajo concurrencia (el UPDATE toma el bloqueo de fila) sin
-- necesitar que el usuario del panel pueda borrar filas de
-- panel_config_pending — esa DELETE sigue reservada al usuario del core (ver
-- GRANTs más abajo), a propósito.
CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_config_pending_seq (
  n BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO \`$PANEL_DB\`.panel_config_pending_seq (n)
  SELECT 0 WHERE NOT EXISTS (SELECT 1 FROM \`$PANEL_DB\`.panel_config_pending_seq);

CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_config_apply_request (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  requested_by VARCHAR(32) NOT NULL,
  requested_at DATETIME NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  applied_at DATETIME NULL,
  error VARCHAR(500) NULL,
  PRIMARY KEY (id),
  INDEX idx_panel_config_apply_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- antes, /api/server-config/save comprobaba con un SELECT si
-- ya había una solicitud 'pending' y luego insertaba sin exclusión mutua —
-- dos peticiones simultáneas podían colar dos solicitudes distintas.
-- pending_marker vale 1 sólo mientras status='pending' y NULL en cualquier
-- otro estado; MySQL/MariaDB permiten varios NULL en una clave ÚNICA, así que
-- sólo puede existir una fila 'pending' a la vez en toda la tabla — el propio
-- INSERT pasa a ser la comprobación atómica (ver ER_DUP_ENTRY en app.js).
--
-- Antes de imponer la clave única, resolver cualquier duplicado que una
-- instalación anterior a este cambio pueda haber dejado: se conserva sólo la
-- solicitud 'pending' más reciente.
UPDATE \`$PANEL_DB\`.panel_config_apply_request SET status = 'applied', applied_at = NOW()
  WHERE status = 'pending' AND id NOT IN (
    SELECT id FROM (SELECT MAX(id) AS id FROM \`$PANEL_DB\`.panel_config_apply_request WHERE status = 'pending') AS t
  );
SET @panel_config_apply_has_marker := (
  SELECT COUNT(*) FROM \`information_schema\`.\`COLUMNS\`
  WHERE \`TABLE_SCHEMA\` = '$PANEL_DB' AND \`TABLE_NAME\` = 'panel_config_apply_request' AND \`COLUMN_NAME\` = 'pending_marker'
);
SET @panel_config_apply_add_marker := IF(
  @panel_config_apply_has_marker = 0,
  'ALTER TABLE \`$PANEL_DB\`.panel_config_apply_request ADD COLUMN pending_marker TINYINT GENERATED ALWAYS AS (IF(status = ''pending'', 1, NULL)) VIRTUAL, ADD UNIQUE KEY uniq_panel_config_apply_pending (pending_marker)',
  'SELECT 1'
);
PREPARE panel_config_apply_migration FROM @panel_config_apply_add_marker;
EXECUTE panel_config_apply_migration;
DEALLOCATE PREPARE panel_config_apply_migration;

-- "Estado y rendimiento" (systemMetrics.js + metricsCache.js): una fila por
-- cada muestreo REALMENTE solicitado (nunca uno por cada apertura de la
-- vista: eso es justo lo que evita la caché compartida de 5 min). Todas las
-- columnas de métrica admiten NULL a propósito: "no observado todavía" es un
-- valor distinto de un cero real (systemd sin NRestarts, un tick lento que
-- nunca ha ocurrido...), y el hueco temporal cuando nadie tenía la vista
-- abierta se representa por la simple ausencia de fila, no por un 0.
CREATE TABLE IF NOT EXISTS \`$PANEL_DB\`.panel_metrics_sample (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sampled_at DATETIME NOT NULL,
  cpu_pct DECIMAL(5,1) NULL,
  mem_rss_kb INT UNSIGNED NULL,
  mem_peak_kb INT UNSIGNED NULL,
  uptime_secs INT UNSIGNED NULL,
  world_restarts INT UNSIGNED NULL,
  slow_tick_count INT UNSIGNED NULL,
  players_online INT UNSIGNED NULL,
  bots_online INT UNSIGNED NULL,
  PRIMARY KEY (id),
  INDEX idx_panel_metrics_sample_at (sampled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT SELECT ON \`$AUTH_DB\`.\`account\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$AUTH_DB\`.\`account_access\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$AUTH_DB\`.\`account_banned\` TO '$DB_USER'@'127.0.0.1';
-- Sólo estas cuatro columnas de "account": el panel crea cuentas (registro con
-- invitación, alta por un administrador) y cambia contraseñas, pero no puede
-- tocar gmlevel, locked ni ninguna otra columna aunque quisiera.
GRANT INSERT (username, salt, verifier, expansion), UPDATE (salt, verifier) ON \`$AUTH_DB\`.\`account\` TO '$DB_USER'@'127.0.0.1';
GRANT INSERT ON \`$AUTH_DB\`.\`realmcharacters\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`characters\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`character_talent\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`character_inventory\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`item_instance\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`character_banned\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`guild\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`guild_member\` TO '$DB_USER'@'127.0.0.1';
-- Mapa social del jugador (/api/social/map): grupo, banda y amigos del propio
-- personaje. guild_member ya está arriba.
GRANT SELECT ON \`$CHARACTERS_DB\`.\`group_member\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`groups\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`character_social\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`guild_bank_tab\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`guild_bank_item\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$CHARACTERS_DB\`.\`guild_bank_right\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`item_template\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`item_template_locale\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`server_help_category\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`server_help_article\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`server_help_command\` TO '$DB_USER'@'127.0.0.1';
-- Operaciones de bots (mod-bot-operations): el panel sólo lee la instantánea
-- y encola acciones (INSERT); actualizar status/result/completed_at es cosa
-- exclusiva de mod-bot-operations, con las credenciales propias del core.
GRANT SELECT ON \`$WORLD_DB\`.\`bot_operations_snapshot\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT, INSERT ON \`$WORLD_DB\`.\`bot_operations_action\` TO '$DB_USER'@'127.0.0.1';
-- doctor (lib/doctor.sh): sólo lectura, el panel nunca escribe su propio
-- resultado. A diferencia de un GRANT sobre toda la base (\`$WORLD_DB\`.*),
-- MySQL 8 SÍ exige que exista la tabla al conceder un privilegio sobre una
-- tabla concreta (ERROR 1146, visto el 15/09/2026 en una instalación desde
-- cero: install.sh sólo llama a run_doctor() -que crea estas tablas- DESPUÉS
-- de correr todas las fases pedidas, así que en un \`--post\` sin ningún fallo
-- previo esta fase 9 es la PRIMERA vez que algo toca \`doctor_status\`). Mismo
-- esquema que lib/doctor.sh (CREATE TABLE IF NOT EXISTS ahí también: el que
-- llegue primero no pisa al otro).
CREATE TABLE IF NOT EXISTS \`$WORLD_DB\`.\`doctor_status\` (
  \`id\` tinyint unsigned NOT NULL,
  \`event_type\` varchar(32) NOT NULL,
  \`overall_result\` varchar(8) NOT NULL,
  \`duration_ms\` int unsigned NOT NULL,
  \`checks\` JSON NOT NULL,
  \`modules\` JSON NOT NULL,
  \`installer_commit\` varchar(40) NOT NULL DEFAULT '',
  \`updated_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (\`id\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS \`$WORLD_DB\`.\`doctor_history\` (
  \`id\` bigint unsigned NOT NULL AUTO_INCREMENT,
  \`event_type\` varchar(32) NOT NULL,
  \`overall_result\` varchar(8) NOT NULL,
  \`duration_ms\` int unsigned NOT NULL,
  \`checks\` JSON NOT NULL,
  \`installer_commit\` varchar(40) NOT NULL DEFAULT '',
  \`created_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (\`id\`),
  INDEX idx_doctor_history_created_at (\`created_at\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
GRANT SELECT ON \`$WORLD_DB\`.\`doctor_status\` TO '$DB_USER'@'127.0.0.1';
GRANT SELECT ON \`$WORLD_DB\`.\`doctor_history\` TO '$DB_USER'@'127.0.0.1';
-- Base propia del panel (invitaciones, auditoría): lectura y escritura completas,
-- pero acotadas a esta base, que no contiene ninguna tabla del core.
GRANT SELECT, INSERT, UPDATE ON \`$PANEL_DB\`.* TO '$DB_USER'@'127.0.0.1';
-- Única tabla del panel con DELETE: panel_metrics_sample se recorta sola
-- (igual que doctor_history, pero por antigüedad) cada vez que se guarda una
-- muestra nueva, sin depender de un proceso aparte.
GRANT DELETE ON \`$PANEL_DB\`.panel_metrics_sample TO '$DB_USER'@'127.0.0.1';
-- El panel nunca borra filas de panel_config_pending/panel_config_apply_request
-- (sin DELETE arriba): sólo el usuario del propio core, que ya usa
-- apply-panel-config.sh (fuera de este proceso web) para escribir los .conf y
-- reiniciar, puede limpiar lo ya aplicado/descartado.
GRANT SELECT, UPDATE, DELETE ON \`$PANEL_DB\`.panel_config_pending TO '$AC_DB_USER'@'127.0.0.1';
GRANT SELECT, UPDATE, DELETE ON \`$PANEL_DB\`.panel_config_apply_request TO '$AC_DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

echo "[4/8] Preparando la cuenta de servicio SOAP…"
# Cuenta de juego dedicada con la que el panel se identifica ante la consola
# SOAP del worldserver (ACSoap.cpp exige gmlevel >= 3). Igual que la cuenta de
# administrador de lib/utils.sh: SRP6 calculado con lib/srp6.py, sin que el
# servidor tenga que estar arrancado, e idempotente (si ya existe no se le
# toca la contraseña, salvo que sea demasiado larga: ver abajo).
SOAP_USERNAME=""
SOAP_PASSWORD=""
if [ -f "$ENV_FILE" ]; then
    SOAP_USERNAME="$(sed -n 's/^SOAP_USERNAME=//p' "$ENV_FILE" | head -n 1)"
    SOAP_PASSWORD="$(sed -n 's/^SOAP_PASSWORD=//p' "$ENV_FILE" | head -n 1)"
fi
SOAP_USERNAME="${SOAP_USERNAME:-$SOAP_ACCOUNT}"
# AccountMgr::CheckPassword del core rechaza las contraseñas de más de
# MAX_PASS_STR (16) caracteres, y ACSoap contesta 401 sin más: una contraseña
# de 48 caracteres deja el SOAP inservible. Las instalaciones anteriores
# generaban 48 (openssl rand -hex 24): si la guardada es más larga se
# regenera y se reescribe el verificador de la cuenta.
SOAP_RESET=0
if [ "${#SOAP_PASSWORD}" -gt 16 ]; then
    SOAP_PASSWORD=""
    SOAP_RESET=1
fi
SOAP_PASSWORD="${SOAP_PASSWORD:-$(openssl rand -hex 8)}"
SOAP_UPPER="$(printf '%s' "$SOAP_USERNAME" | tr '[:lower:]' '[:upper:]')"

SOAP_ACCOUNT_ID="$(mysql -NBe "SELECT id FROM \`$AUTH_DB\`.account WHERE username='${SOAP_UPPER}';")"
if [ -z "$SOAP_ACCOUNT_ID" ] || [ "$SOAP_RESET" = 1 ]; then
    PYTHON_BIN=""
    for CANDIDATE in python3 python; do
        command -v "$CANDIDATE" >/dev/null 2>&1 || continue
        if "$CANDIDATE" -c 'import hashlib' >/dev/null 2>&1; then PYTHON_BIN="$CANDIDATE"; break; fi
    done
    if [ -z "$PYTHON_BIN" ]; then
        echo "Hace falta python3 para calcular el verificador SRP6 de la cuenta SOAP." >&2
        exit 1
    fi
    SRP="$("$PYTHON_BIN" "$REPO_DIR/lib/srp6.py" "$SOAP_USERNAME" "$SOAP_PASSWORD")"
    SOAP_SALT="${SRP%% *}"
    SOAP_VERIFIER="${SRP##* }"
    if [ -z "$SOAP_ACCOUNT_ID" ]; then
        mysql -e "INSERT INTO \`$AUTH_DB\`.account (username, salt, verifier, expansion) VALUES ('${SOAP_UPPER}', UNHEX('${SOAP_SALT}'), UNHEX('${SOAP_VERIFIER}'), 2);"
    else
        mysql -e "UPDATE \`$AUTH_DB\`.account SET salt=UNHEX('${SOAP_SALT}'), verifier=UNHEX('${SOAP_VERIFIER}') WHERE id=${SOAP_ACCOUNT_ID};"
    fi
    SOAP_ACCOUNT_ID="$(mysql -NBe "SELECT id FROM \`$AUTH_DB\`.account WHERE username='${SOAP_UPPER}';")"
fi
mysql -e "REPLACE INTO \`$AUTH_DB\`.account_access (id, gmlevel, RealmID, comment) VALUES (${SOAP_ACCOUNT_ID}, 3, -1, 'cuenta de servicio SOAP del panel');"
mysql -e "INSERT IGNORE INTO \`$AUTH_DB\`.realmcharacters (realmid, acctid, numchars) SELECT id, ${SOAP_ACCOUNT_ID}, 0 FROM \`$AUTH_DB\`.realmlist;"

echo "[5/8] Instalando la aplicación…"
install -d -m 0755 /opt/azerothcore-panel
rsync -a --exclude node_modules --exclude .env "$SOURCE_DIR/" /opt/azerothcore-panel/
# Los addons deben estar completos ANTES del rsync --delete: una carpeta a medias
# (descarga fallida, edición pública sin construir) vaciaría lo ya instalado. Los
# deja listos scripts/preparar-recursos.sh; aquí sólo se comprueba contra arbol.tsv.
if ! node "$SOURCE_DIR/tools/build-addons.mjs" verificar --destino "$REPO_DIR/cliente/Interface/AddOns" >/dev/null 2>&1; then
    echo "cliente/Interface/AddOns no coincide con web-panel/addons/arbol.tsv (¿falta construirlo?)." >&2
    echo "Ejecuta ./install.sh --panel (construye los addons) o: node web-panel/tools/build-addons.mjs build" >&2
    exit 1
fi
install -d -m 0755 /opt/azerothcore-panel/addons/client
rsync -a --delete "$REPO_DIR/cliente/Interface/AddOns/" /opt/azerothcore-panel/addons/client/
# El servicio corre como DynamicUser: todo legible para "otros" aunque el origen no lo fuera.
chmod -R u=rwX,go=rX /opt/azerothcore-panel/addons/client
# Generadores de recursos que el panel ejecuta con lo que recibe del navegador del
# jugador (iconos de la armería, parches patch-<idioma>-4.MPQ) y sus entradas fijas.
install -d -m 0755 /opt/azerothcore-panel/tools
install -m 0644 "$REPO_DIR/tools/construir-parche-cliente-items.py" "$REPO_DIR/tools/piedra_sede_dbc.py" /opt/azerothcore-panel/tools/
# Cliente base del cliente web (WEB-PANEL): tras cada subida el panel regenera los enlaces y el manifiesto de /play/datos/ con este script.
if [ -f "$REPO_DIR/web-client/generar-manifiesto.py" ]; then
    install -m 0644 "$REPO_DIR/web-client/generar-manifiesto.py" /opt/azerothcore-panel/tools/
fi
# Carpetas del cliente web (mismas que usa web-client/deploy.sh): el servicio del panel escribe en ellas por el grupo del usuario de
# AzerothCore (ReadWritePaths= en la unidad) y nginx las lee como «otros». Sólo se tocan si el cliente web está activado en config.sh.
if [ "${INSTALL_WEB_CLIENT:-false}" = true ]; then
    install -d -o "$AC_OWNER" -g "$AC_GROUP" -m 2775 "$WEB_ROOT" "$WEB_ROOT/datos" "$WEB_DATA"
fi
if [ -d "$REPO_DIR/.instalacion/insumos/arac" ]; then
    install -d -m 0755 /opt/azerothcore-panel/insumos
    rsync -a --delete "$REPO_DIR/.instalacion/insumos/arac/" /opt/azerothcore-panel/insumos/arac/
fi
if [ -d "$REPO_DIR/.instalacion/semilla" ]; then
    install -d -m 0755 /opt/azerothcore-panel/semilla
    rsync -a --delete "$REPO_DIR/.instalacion/semilla/" /opt/azerothcore-panel/semilla/
fi
# Carpeta de recursos generados (escribe el servicio por el grupo del usuario de
# AzerothCore; lee el doctor sin sudo). Si quedó un enlace de una unidad anterior, se retira.
[ -L /var/lib/azerothcore-panel ] && rm -f /var/lib/azerothcore-panel
install -d -o "$AC_OWNER" -g "$AC_GROUP" -m 2775 /var/lib/azerothcore-panel
# La carpeta de datos antigua (MPQ copiados del repositorio) ya no se usa: el panel
# sirve lo que él mismo genera o incorpora de la semilla.
rm -rf /opt/azerothcore-panel/addons/data
# Copias de sólo lectura para la pantalla de actualizaciones. El panel consulta
# las ramas remotas, pero nunca necesita acceder ni escribir en los clones de
# AzerothCore instalados bajo el directorio personal del usuario del servidor.
install -d -o "$AC_OWNER" -g "$AC_GROUP" -m 0755 /opt/azerothcore-panel/update-locks
install -o "$AC_OWNER" -g "$AC_GROUP" -m 0644 "$REPO_DIR/versions.lock" /opt/azerothcore-panel/update-locks/versions.lock
install -o "$AC_OWNER" -g "$AC_GROUP" -m 0644 "$REPO_DIR/addons.lock" /opt/azerothcore-panel/update-locks/addons.lock
# Punto de montaje del BindReadOnlyPaths de azerothcore-panel.service: tiene
# que existir ya en disco antes de que arranque el sandbox (ver comentario en
# ese fichero sobre por qué un destino dentro de /home no funciona).
install -d -m 0755 /opt/azerothcore-panel/conf-ro
install -d -m 0755 /opt/azerothcore-panel/log-ro
# La primera versión guardaba otra copia comprimida. El catálogo actual genera
# los ZIP desde addons/client y esta ruta concreta ya no debe existir.
rm -rf /opt/azerothcore-panel/addons/packages
# Retira los fondos vectoriales provisionales de la primera versión. Son rutas
# concretas dentro del panel y los mapas JPG reales ya se copiaron arriba.
rm -f /opt/azerothcore-panel/public/assets/map-eastern.svg \
      /opt/azerothcore-panel/public/assets/map-kalimdor.svg \
      /opt/azerothcore-panel/public/assets/map-outland.svg \
      /opt/azerothcore-panel/public/assets/map-northrend.svg
cd /opt/azerothcore-panel
npm ci --omit=dev --no-audit --no-fund >/dev/null

cat > "$ENV_FILE" <<ENV
NODE_ENV=production
HOST=127.0.0.1
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
AUTH_DATABASE=$AUTH_DB
CHARACTERS_DATABASE=$CHARACTERS_DB
WORLD_DATABASE=$WORLD_DB
PANEL_DATABASE=$PANEL_DB
REALM_ID=$REALM_ID
SESSION_SECRET=$SESSION_SECRET
SESSION_TTL_SECONDS=28800
COOKIE_SECURE=true
ADDONS_DIRECTORY=/opt/azerothcore-panel/addons/client
# Recursos generados desde el cliente del jugador (carpeta de estado del servicio,
# StateDirectory= en azerothcore-panel.service) y sus entradas fijas.
RESOURCES_DIRECTORY=/var/lib/azerothcore-panel/recursos
RESOURCES_SEED_DIRECTORY=/opt/azerothcore-panel/semilla
ARAC_INPUT_DIRECTORY=/opt/azerothcore-panel/insumos/arac
PYTHON_COMMAND=/usr/bin/python3
ICONS_SCRIPT=/opt/azerothcore-panel/tools/extract-item-icons.py
PATCH_SCRIPT=/opt/azerothcore-panel/tools/construir-parche-cliente-items.py
# Rutas de sólo lectura dentro del sandbox del panel (ver BindReadOnlyPaths en
# azerothcore-panel.service): no son $ETC_DIR/$MOD_CONF_DIR directamente
# porque ese destino está bajo /home y el bind mount no llega a montarse ahí.
WORLDSERVER_CONF_PATH=/opt/azerothcore-panel/conf-ro/worldserver.conf
MODULE_CONF_DIRECTORY=/opt/azerothcore-panel/conf-ro/modules
WORLDSERVER_LOG_PATH=/opt/azerothcore-panel/log-ro/Server.log
VERSIONS_LOCK_PATH=/opt/azerothcore-panel/update-locks/versions.lock
ADDONS_LOCK_PATH=/opt/azerothcore-panel/update-locks/addons.lock
SOAP_HOST=127.0.0.1
SOAP_PORT=7878
SOAP_USERNAME=$SOAP_USERNAME
SOAP_PASSWORD=$SOAP_PASSWORD
SOAP_TIMEOUT_MS=5000
# Modo en espera (config.sh WORLDSERVER_STANDBY): el panel lo usa para mostrar
# "en espera" en vez de "caído" cuando el worldserver está dormido a propósito.
WORLDSERVER_STANDBY=${WORLDSERVER_STANDBY:-false}
WORLDSERVER_STATE_PATH=/run/azerothcore/worldserver.state
# Cliente web (WEB-PANEL): carpeta del cliente base y de estado de /play/. Sin el cliente web instalado la pantalla «Cliente web» no ofrece subirlo.
WEB_CLIENT_DATA_DIR=$([ "${INSTALL_WEB_CLIENT:-false}" = true ] && echo "$WEB_DATA")
WEB_CLIENT_ROOT=$([ "${INSTALL_WEB_CLIENT:-false}" = true ] && echo "$WEB_ROOT")
WEB_CLIENT_MANIFEST_SCRIPT=/opt/azerothcore-panel/tools/generar-manifiesto.py
ENV
chmod 0600 "$ENV_FILE"

# El aviso de parada y el saveall en modo en espera van por SOAP: safe-stop.sh y
# notify-restart.sh (fases 6 y 7) leen las credenciales de este fichero. Se abre
# a lectura para el grupo del usuario de AzerothCore (nunca para "otros"): las
# mismas credenciales que el panel ya usa, y el proceso del panel sigue con su
# .env propio de modo 600.
if getent group "$AC_GROUP" >/dev/null 2>&1; then
    chgrp "$AC_GROUP" "$ENV_FILE" && chmod 0640 "$ENV_FILE"
fi

echo "[6/8] Configurando systemd…"
sed -e "s|__ETC_DIR__|$ETC_DIR|g" -e "s|__AC_GROUP__|$AC_GROUP|g" -e "s|__LOG_DIR__|$LOG_DIR|g" \
    -e "s|__WEB_ROOT__|$WEB_ROOT|g" -e "s|__WEB_DATA__|$WEB_DATA|g" \
    "$DEPLOY_DIR/azerothcore-panel.service" > /etc/systemd/system/azerothcore-panel.service
chmod 0644 /etc/systemd/system/azerothcore-panel.service
systemctl daemon-reload
systemctl enable azerothcore-panel.service
systemctl restart azerothcore-panel.service

echo "[7/8] Publicando el panel con Nginx…"
SERVER_IP="$(hostname -I | awk '{print $1}')"
SERVER_NAME="$(hostname -f 2>/dev/null || hostname)"
TLS_DIR=/etc/azerothcore-panel/tls
install -d -m 0711 "$TLS_DIR"
chmod 0711 "$TLS_DIR"
install -d -m 0755 /etc/azerothcore-panel/play.d   # el include de nginx.conf (cliente web, fase 10)

if [ -n "${PANEL_TLS_CERTIFICATE:-}" ] || [ -n "${PANEL_TLS_KEY:-}" ]; then
    if [ ! -f "${PANEL_TLS_CERTIFICATE:-}" ] || [ ! -f "${PANEL_TLS_KEY:-}" ]; then
        echo "PANEL_TLS_CERTIFICATE y PANEL_TLS_KEY deben apuntar a archivos existentes." >&2
        exit 1
    fi
    TLS_CERTIFICATE="$PANEL_TLS_CERTIFICATE"
    TLS_KEY="$PANEL_TLS_KEY"
    cp "$TLS_CERTIFICATE" "$TLS_DIR/ca.crt"
else
    CA_KEY="$TLS_DIR/ca.key"
    CA_CERT="$TLS_DIR/ca.crt"
    TLS_KEY="$TLS_DIR/server.key"
    TLS_CERTIFICATE="$TLS_DIR/server.crt"
    if [ ! -s "$CA_KEY" ] || [ ! -s "$CA_CERT" ]; then
        openssl req -x509 -newkey rsa:3072 -sha256 -days 3650 -nodes \
            -subj "/CN=AzerothCore Panel - Autoridad local" \
            -keyout "$CA_KEY" -out "$CA_CERT" >/dev/null 2>&1
    fi
    openssl req -newkey rsa:2048 -nodes -sha256 -subj "/CN=$SERVER_IP" \
        -keyout "$TLS_KEY" -out "$TLS_DIR/server.csr" >/dev/null 2>&1
    printf 'subjectAltName=IP:%s,DNS:%s\nextendedKeyUsage=serverAuth\n' "$SERVER_IP" "$SERVER_NAME" > "$TLS_DIR/server.ext"
    openssl x509 -req -sha256 -days 825 -in "$TLS_DIR/server.csr" \
        -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -extfile "$TLS_DIR/server.ext" \
        -out "$TLS_CERTIFICATE" >/dev/null 2>&1
    rm -f "$TLS_DIR/server.csr" "$TLS_DIR/server.ext"
fi
chmod 0600 "$TLS_KEY"
chmod 0644 "$TLS_CERTIFICATE" "$TLS_DIR/ca.crt"

if [ "$HTTPS_PORT" = 443 ]; then HTTPS_SUFFIX=""; else HTTPS_SUFFIX=":$HTTPS_PORT"; fi
sed -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
    -e "s|__HTTPS_PORT__|$HTTPS_PORT|g" \
    -e "s|__HTTPS_SUFFIX__|$HTTPS_SUFFIX|g" \
    -e "s|__TLS_CERTIFICATE__|$TLS_CERTIFICATE|g" \
    -e "s|__TLS_KEY__|$TLS_KEY|g" \
    "$DEPLOY_DIR/nginx.conf" > /etc/nginx/sites-available/azerothcore-panel
if [ -L /etc/nginx/sites-enabled/default ]; then
    unlink /etc/nginx/sites-enabled/default
fi
ln -sfn /etc/nginx/sites-available/azerothcore-panel /etc/nginx/sites-enabled/azerothcore-panel
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q '^Status: active'; then
    ufw allow "$HTTP_PORT/tcp" >/dev/null
    ufw allow "$HTTPS_PORT/tcp" >/dev/null
fi

echo "[8/8] Comprobando el servicio…"
for _ in $(seq 1 15); do
    if curl -fsS http://127.0.0.1:3000/api/health >/dev/null; then
        if [ "$HTTPS_PORT" = 443 ]; then PANEL_URL="https://$SERVER_IP"; else PANEL_URL="https://$SERVER_IP:$HTTPS_PORT"; fi
        echo "Panel instalado: $PANEL_URL"
        if [ "$HTTP_PORT" = 80 ]; then CA_URL="http://$SERVER_IP/azerothcore-panel-ca.crt"; else CA_URL="http://$SERVER_IP:$HTTP_PORT/azerothcore-panel-ca.crt"; fi
        echo "CA local: $CA_URL"
        echo "Estado: systemctl status azerothcore-panel"
        echo "Logs:   journalctl -u azerothcore-panel -f"
        exit 0
    fi
    sleep 1
done

journalctl -u azerothcore-panel -n 30 --no-pager >&2
echo "El panel no respondió a la comprobación de salud." >&2
exit 1
