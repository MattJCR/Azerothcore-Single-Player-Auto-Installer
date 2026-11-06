#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#  lib/doctor.sh — comando `doctor`: una pasada de comprobaciones estructurada
#
#  EL PROBLEMA
#  Antes de esto había comprobaciones sueltas y sin memoria: verificar-
#  instalacion.sh imprime un informe legible que nadie relee después de la
#  pantalla en la que salió, y verify_mirrors_consistency() (P0, hoy) solo
#  avisa por consola. Ninguna deja un resultado que sobreviva al terminal ni
#  distingue "algo va mal" de "salió bien": para eso hace falta un exit code
#  fiable y un sitio donde el panel (o la CI) pueda leer el último resultado
#  sin volver a ejecutar nada.
#
#  LA SOLUCIÓN
#  run_doctor EVENTO ejecuta una batería de comprobaciones de solo lectura
#  (nunca cambia nada del servidor), calcula un resultado global — ok, si
#  todas pasan; warn, si alguna es solo un aviso; fail, si alguna es un error
#  real — y dos cosas:
#    1. Un resumen legible en el log de siempre (mismo INSTALL_LOG que el
#       resto de fases).
#    2. Dos filas en `acore_world` (misma base y mismas credenciales que ya
#       usa el resto del instalador y el propio worldserver, sin credencial
#       nueva que gestionar): `doctor_status` (id=1, "ahora mismo") y
#       `doctor_history` (un historial acotado, más antiguo se recorta), que
#       el panel puede leer con el mismo patrón que ya usa para
#       bot_operations_snapshot.
#
#  Devuelve 0 si el resultado es ok o warn, 1 si es fail — así
#  `./install.sh --doctor` y cualquier disparador automático (ver
#  DOCTOR_TRIGGERS más abajo) pueden usarlo como puerta de salida distinta de
#  cero ante errores reales, sin que un simple aviso rompa una instalación.
# =============================================================================

DOCTOR_WORLD_DB="${PANEL_WORLD_DATABASE:-acore_world}"

# Filas de resultado de la pasada actual: cada una "nombre<TAB>estado<TAB>detalle".
# estado es uno de: ok, warn, fail.
declare -a DOCTOR_CHECKS=()

_doctor_check() {
    local NAME="$1" STATUS="$2" DETAIL="$3"
    DOCTOR_CHECKS+=("${NAME}"$'\t'"${STATUS}"$'\t'"${DETAIL}")
    case "$STATUS" in
        ok)   log  "[doctor] ${NAME}: ${DETAIL}" ;;
        warn) warn "[doctor] ${NAME}: ${DETAIL}" ;;
        fail) error "[doctor] ${NAME}: ${DETAIL}" ;;
    esac
}

# Escapa comillas simples y barras invertidas para meter texto libre entre
# comillas simples en una sentencia SQL (mismo criterio que
# WorldDatabase::EscapeString en el core: sin NO_BACKSLASH_ESCAPES).
_doctor_sql_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/'"'"'/\\'"'"'/g'
}

# JSON mínimo de mano, mismo criterio que mod_bot_operations.cpp (sin
# librería): solo hace falta escribirlo, el panel (JS) es quien lo interpreta.
_doctor_json_escape() {
    local OUT="" C
    # Un detalle puede traer el texto coloreado de error()/warn() (secuencias ANSI) u otros
    # caracteres de control: JSON no los admite y MySQL rechaza el documento entero
    # («Invalid encoding in string», 12/10/2026). Se quitan antes de escapar.
    local S
    S=$(printf '%s' "$1" | sed $'s/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d '\000-\010\013-\037')
    local LEN=${#S}
    local I
    for (( I=0; I<LEN; I++ )); do
        C="${S:$I:1}"
        case "$C" in
            '"')  OUT+='\"' ;;
            '\')  OUT+='\\' ;;
            $'\n') OUT+='\n' ;;
            $'\t') OUT+='\t' ;;
            *) OUT+="$C" ;;
        esac
    done
    printf '%s' "$OUT"
}

_doctor_checks_to_json() {
    local ENTRY NAME STATUS DETAIL FIRST=1
    local OUT="["
    for ENTRY in "${DOCTOR_CHECKS[@]}"; do
        IFS=$'\t' read -r NAME STATUS DETAIL <<< "$ENTRY"
        [ "$FIRST" -eq 1 ] || OUT+=","
        FIRST=0
        OUT+="{\"name\":\"$(_doctor_json_escape "$NAME")\",\"status\":\"${STATUS}\",\"detail\":\"$(_doctor_json_escape "$DETAIL")\"}"
    done
    OUT+="]"
    printf '%s' "$OUT"
}

# =============================================================================
# Comprobaciones individuales — todas de solo lectura
# =============================================================================

_doctor_check_mirrors() {
    local OUT
    if OUT=$(verify_mirrors_consistency 2>&1); then
        _doctor_check "mirrors" ok "versions.lock, mirrors/versions.lock y MANIFEST.tsv coinciden."
    else
        _doctor_check "mirrors" fail "$(echo "$OUT" | tail -3 | tr '\n' '; ')"
    fi
}

# Los mismos commits instalados vs versions.lock que verificar-instalacion.sh,
# pero como una comprobación con veredicto en vez de una tabla para leer a ojo.
_doctor_check_pinned_versions() {
    [ -f "$VERSIONS_LOCK" ] || { _doctor_check "pinned-versions" warn "No existe versions.lock todavía."; return; }

    local NAME BRANCH COMMIT DATE URL DIR CURRENT DRIFTED=0 CHECKED=0
    while IFS=$'\t' read -r NAME BRANCH COMMIT DATE URL; do
        case "$NAME" in ''|\#*) continue ;; esac
        if [ "$NAME" = "core" ]; then DIR="$AC_DIR"
        elif [ -d "$AC_DIR/modules/$NAME/.git" ]; then DIR="$AC_DIR/modules/$NAME"
        elif [ -d "$AC_DIR/extras/$NAME/.git" ]; then DIR="$AC_DIR/extras/$NAME"
        elif [ -d "$AC_DIR/modules-disabled/$NAME/.git" ]; then DIR="$AC_DIR/modules-disabled/$NAME"
        else continue; fi

        CHECKED=$((CHECKED + 1))
        CURRENT=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo "")
        [ "$CURRENT" = "$COMMIT" ] || DRIFTED=$((DRIFTED + 1))
    done < "$VERSIONS_LOCK"

    if [ "$DRIFTED" -eq 0 ]; then
        _doctor_check "pinned-versions" ok "${CHECKED} repositorios en el commit fijado."
    else
        _doctor_check "pinned-versions" warn "${DRIFTED} de ${CHECKED} repositorios NO están en el commit de versions.lock."
    fi
}

# Las cuatro claves que ya han costado cuatro incidentes mudos (ver
# set_conf_value en lib/utils.sh): si worldserver.conf existe, deben tener un
# valor no vacío.
_doctor_check_known_keys() {
    local WS="$AC_DIR/env/dist/etc/worldserver.conf"
    [ -f "$WS" ] || { _doctor_check "known-keys" warn "worldserver.conf todavía no existe (¿fase 5 sin ejecutar?)."; return; }

    local KEY MISSING=()
    for KEY in "MapUpdate.Threads" "AllowTwoSide.Interaction.Chat" \
               "AllowTwoSide.Interaction.Channel" "AllowTwoSide.Interaction.Auction"; do
        grep -qE "^${KEY//./\\.}[[:space:]]*=[[:space:]]*[^[:space:]]" "$WS" 2>/dev/null || MISSING+=("$KEY")
    done

    if [ "${#MISSING[@]}" -eq 0 ]; then
        _doctor_check "known-keys" ok "las 4 claves con historial de incidente tienen valor."
    else
        _doctor_check "known-keys" fail "sin valor: ${MISSING[*]}"
    fi
}

# Claves que set_conf_value tuvo que añadir a un .conf porque su .conf.dist no
# las declaraba (ver el comentario de esa función): señal de que el upstream
# cambió esa clave y el módulo podría no estar leyendo lo que cree.
_doctor_check_unknown_keys() {
    [ -f "$INSTALL_LOG" ] || { _doctor_check "unknown-keys" ok "sin log de instalación todavía."; return; }

    local COUNT
    # grep -c imprime el recuento (0 incluido) pero devuelve 1 sin coincidencias:
    # un "|| echo 0" tras esto duplicaría la salida en el caso de cero. Ese
    # exit 1 sí hay que atajarlo (el "|| true" de abajo) porque install.sh
    # corre con `set -e`: sin él, un log limpio (el caso normal) abortaba
    # toda la pasada de doctor en mitad de esta comprobación (14/09/2026,
    # sólo se vio al arreglar AC_DIR bajo sudo — antes ni se llegaba aquí
    # porque el `[ -f "$INSTALL_LOG" ]` de arriba ya fallaba con el AC_DIR
    # equivocado).
    COUNT=$(grep -ac "NO declarada en" "$INSTALL_LOG" 2>/dev/null || true)
    COUNT="${COUNT:-0}"
    if [ "$COUNT" -eq 0 ]; then
        _doctor_check "unknown-keys" ok "ninguna clave añadida sin declarar en su .conf.dist."
    else
        _doctor_check "unknown-keys" warn "${COUNT} claves añadidas sin declarar en su .conf.dist (ver install.log)."
    fi
}

# Lista única de módulos propios (nombre corto sin "mod-": activo según
# config.sh). La comparte _doctor_check_own_modules (¿está lo que debería?) y
# _doctor_build_modules_json (inventario para el dashboard): antes eran dos
# copias de la misma lista y podían divergir sin que nada avisara.
_doctor_own_modules_list() {
    cat <<EOF
queue-bots:${INSTALL_MOD_QUEUE_BOTS:-false}
world-bots:${INSTALL_MOD_WORLD_BOTS:-false}
quest-mates:${INSTALL_MOD_QUEST_MATES:-false}
party-here:${INSTALL_MOD_PARTY_HERE:-false}
home-guild:${INSTALL_MOD_HOME_GUILD:-false}
bot-operations:${INSTALL_MOD_BOT_OPERATIONS:-false}
update-notice:${INSTALL_MOD_UPDATE_NOTICE:-false}
server-help:${INSTALL_MOD_SERVER_HELP:-false}
standby:${INSTALL_MOD_STANDBY:-false}
progression-skip:${INSTALL_MOD_PROGRESSION_SKIP:-false}
treasure:${INSTALL_MOD_TREASURE:-false}
EOF
}

# Carpeta + .conf de cada módulo propio que config.sh dice que debe estar activo.
_doctor_check_own_modules() {
    local ENTRY NAME ON MISSING=()
    while IFS= read -r ENTRY; do
        NAME="${ENTRY%%:*}"; ON="${ENTRY##*:}"
        [ "$ON" = true ] || continue
        [ -d "$AC_DIR/modules/mod-$NAME" ] || MISSING+=("mod-$NAME (carpeta)")
        [ -f "$AC_DIR/env/dist/etc/modules/mod_${NAME//-/_}.conf" ] || MISSING+=("mod-$NAME (.conf)")
    done < <(_doctor_own_modules_list)

    if [ "${#MISSING[@]}" -eq 0 ]; then
        _doctor_check "own-modules" ok "módulos propios activos con carpeta y .conf presentes."
    else
        _doctor_check "own-modules" fail "faltan: ${MISSING[*]}"
    fi
}

# Inventario de módulos para el dashboard "Estado y rendimiento": terceros con
# su commit corto (versions.lock) y estado activo/desactivado, y propios con
# estado activo/desactivado (su "versión" es installer_commit, el commit de
# este repositorio instalador — no tienen un .git propio dentro de modules/).
_doctor_build_modules_json() {
    local OUT="[" FIRST=1
    local NAME BRANCH COMMIT DATE URL DIR STATUS CURRENT

    if [ -f "$VERSIONS_LOCK" ]; then
        while IFS=$'\t' read -r NAME BRANCH COMMIT DATE URL; do
            case "$NAME" in ''|\#*|core) continue ;; esac
            if [ -d "$AC_DIR/modules/$NAME/.git" ]; then DIR="$AC_DIR/modules/$NAME"; STATUS="active"
            elif [ -d "$AC_DIR/extras/$NAME/.git" ]; then DIR="$AC_DIR/extras/$NAME"; STATUS="active"
            elif [ -d "$AC_DIR/modules-disabled/$NAME/.git" ]; then DIR="$AC_DIR/modules-disabled/$NAME"; STATUS="disabled"
            else continue; fi

            CURRENT=$(git -C "$DIR" rev-parse --short=12 HEAD 2>/dev/null || echo "")
            [ "$FIRST" -eq 1 ] || OUT+=","
            FIRST=0
            OUT+="{\"name\":\"$(_doctor_json_escape "$NAME")\",\"kind\":\"third-party\",\"commit\":\"$(_doctor_json_escape "$CURRENT")\",\"status\":\"${STATUS}\"}"
        done < "$VERSIONS_LOCK"
    fi

    local ENTRY MNAME ON
    while IFS= read -r ENTRY; do
        MNAME="${ENTRY%%:*}"; ON="${ENTRY##*:}"
        if [ "$ON" = true ] && [ -d "$AC_DIR/modules/mod-$MNAME" ]; then STATUS="active"
        elif [ -d "$AC_DIR/modules-disabled/mod-$MNAME" ]; then STATUS="disabled"
        elif [ "$ON" = true ]; then STATUS="active"   # activo en config pero sin copiar aún (fase 3 pendiente)
        else continue; fi

        [ "$FIRST" -eq 1 ] || OUT+=","
        FIRST=0
        OUT+="{\"name\":\"mod-$(_doctor_json_escape "$MNAME")\",\"kind\":\"own\",\"commit\":\"\",\"status\":\"${STATUS}\"}"
    done < <(_doctor_own_modules_list)

    OUT+="]"
    printf '%s' "$OUT"
}

_doctor_check_services() {
    local SVC ACTIVE=() DOWN=()
    for SVC in mysql ac-authserver ac-worldserver; do
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            ACTIVE+=("$SVC")
        elif systemctl list-unit-files "${SVC}.socket" >/dev/null 2>&1 && \
             systemctl is-enabled --quiet "${SVC}.socket" 2>/dev/null; then
            # Modo en espera: worldserver inactivo es normal (dormido, el
            # socket lo despierta), no es una caída.
            ACTIVE+=("$SVC(en espera)")
        elif systemctl list-unit-files "${SVC}.service" >/dev/null 2>&1; then
            DOWN+=("$SVC")
        fi
    done

    if [ "${#DOWN[@]}" -eq 0 ]; then
        _doctor_check "services" ok "activos: ${ACTIVE[*]:-ninguno gestionado por systemd en este host}."
    else
        _doctor_check "services" fail "caídos: ${DOWN[*]}."
    fi
}

_doctor_check_disk_space() {
    local USAGE
    USAGE=$(df -P "$AC_DIR" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [ -z "$USAGE" ]; then
        _doctor_check "disk-space" warn "no se pudo leer el uso de disco de $AC_DIR."
    elif [ "$USAGE" -ge 90 ]; then
        _doctor_check "disk-space" fail "partición de $AC_DIR al ${USAGE}% de uso."
    elif [ "$USAGE" -ge 75 ]; then
        _doctor_check "disk-space" warn "partición de $AC_DIR al ${USAGE}% de uso."
    else
        _doctor_check "disk-space" ok "partición de $AC_DIR al ${USAGE}% de uso."
    fi
}

# Ticks lentos recientes (SlowTick.h, P2 de hoy): no es un fallo por sí solo
# (puede ser una sola pasada puntual), pero si hay muchos en poco tiempo es la
# señal exacta que esta tarea quería tener antes de decidir instrumentar más.
_doctor_check_slow_ticks() {
    local LOG="$AC_DIR/env/dist/bin/Server.log"
    [ -f "$LOG" ] || { _doctor_check "slow-ticks" ok "sin Server.log todavía."; return; }

    local COUNT
    # Mismo gotcha que unknown-keys más arriba: grep -c devuelve 1 sin
    # coincidencias (el caso sano) y aborta la pasada entera bajo `set -e`
    # sin el "|| true".
    COUNT=$(grep -ac "Tick lento" "$LOG" 2>/dev/null || true)
    COUNT="${COUNT:-0}"
    if [ "$COUNT" -eq 0 ]; then
        _doctor_check "slow-ticks" ok "sin avisos de tick lento en Server.log."
    elif [ "$COUNT" -lt 20 ]; then
        _doctor_check "slow-ticks" warn "${COUNT} avisos de tick lento acumulados en Server.log."
    else
        _doctor_check "slow-ticks" fail "${COUNT} avisos de tick lento acumulados en Server.log (revisar qué módulo)."
    fi
}

# DBC del servidor que sustituyen IP y ARAC (apply_server_dbc_overrides). Sin
# ellos el servidor arranca sin error pero sin razas/clases cruzadas: pasó en
# la reinstalación limpia del 24/09/2026 (PLAN AR01) y sólo se vio comparando
# hashes, así que se compara aquí en cada pasada.
_doctor_check_server_dbc() {
    local DST="$AC_DIR/env/dist/bin/dbc" SRC DBC BAD=()
    [ -d "$DST" ] || { _doctor_check "server-dbc" warn "no existe $DST todavía."; return; }
    if [ "${INSTALL_MOD_ARAC:-false}" = true ]; then
        SRC="$AC_DIR/extras/mod-arac/patch-contents/DBFilesContent"
        if [ -d "$SRC" ]; then
            for DBC in "$SRC"/*.dbc; do
                cmp -s "$DBC" "$DST/$(basename "$DBC")" || BAD+=("$(basename "$DBC") (ARAC)")
            done
        else
            BAD+=("falta $SRC")
        fi
    fi
    if [ "${INSTALL_MOD_INDIVIDUAL_PROGRESSION:-false}" = true ] && [ "${IP_OPTIONAL_DBC:-false}" = true ] \
       && [ ! -d "$DST/backup-pre-ip" ]; then
        BAD+=("DBC opcionales de IP sin copiar")
    fi
    if [ "${INSTALL_MOD_GUILDHOUSE:-false}" = true ] && [ -f "$DST/Spell.dbc" ] \
       && ! python3 "$INSTALLER_DIR/tools/piedra_sede_dbc.py" --comprobar "$DST/Spell.dbc" 2>/dev/null; then
        BAD+=("Spell.dbc sin el hechizo 600001 de la piedra de la sede")
    fi
    if [ "${#BAD[@]}" -eq 0 ]; then
        _doctor_check "server-dbc" ok "DBC del servidor de IP/ARAC (y la piedra de la sede) en su sitio."
    else
        _doctor_check "server-dbc" fail "${BAD[*]} — ejecuta ./install.sh --only 5 y reinicia el worldserver."
    fi
}

# Datos del cliente (maps, vmaps, mmaps, dbc): con data-version y sin una extracción a
# medias (.data-extracting). Una descarga cortada o un ZIP a medias dejaban "maps"
# presente pero incompleto y la fase 5 daba los datos por buenos.
_doctor_check_client_data() {
    local BIN="$AC_DIR/env/dist/bin" BAD=() D
    [ -d "$BIN" ] || { _doctor_check "client-data" warn "no existe $BIN todavía."; return; }
    [ -f "$BIN/.data-extracting" ] && BAD+=("extracción interrumpida (.data-extracting)")
    for D in maps vmaps mmaps dbc; do
        [ -n "$(ls -A "$BIN/$D" 2>/dev/null)" ] || BAD+=("$D vacía o ausente")
    done
    if [ "${#BAD[@]}" -eq 0 ]; then
        # data-version lo escribe install_client_data; una instalación anterior puede no tenerlo.
        _doctor_check "client-data" ok "datos del cliente completos ($(head -1 "$BIN/data-version" 2>/dev/null | sed 's#.*/download/##; s# sha256:.*##' || true))."
    else
        _doctor_check "client-data" fail "${BAD[*]} — ./install.sh --only 5 los vuelve a bajar y verificar."
    fi
}

# Addons de cliente que sirve el panel: carpeta del instalador y copia desplegada
# contra el contenido esperado (web-panel/addons/arbol.tsv). Una carpeta ausente o
# alterada es un fallo: el panel serviría un catálogo incompleto.
_doctor_check_addons() {
    [ "${INSTALL_WEB_PANEL:-true}" = true ] || return 0
    command -v node >/dev/null 2>&1 || { _doctor_check "addons" warn "node no está instalado: no se pueden comprobar los addons."; return; }
    local TOOL="$INSTALLER_DIR/web-panel/tools/build-addons.mjs" OUT
    [ -f "$TOOL" ] || { _doctor_check "addons" fail "falta $TOOL."; return; }
    if ! OUT=$(node "$TOOL" verificar --destino "$INSTALLER_DIR/cliente/Interface/AddOns" 2>&1); then
        _doctor_check "addons" fail "$(printf '%s' "$OUT" | tr '
' ' ') — ejecuta ./install.sh --panel."
        return
    fi
    if [ -d /opt/azerothcore-panel/addons/client ]; then
        if ! OUT=$(node "$TOOL" verificar --destino /opt/azerothcore-panel/addons/client 2>&1); then
            _doctor_check "addons" fail "la copia del panel: $(printf '%s' "$OUT" | tr '
' ' ') — ejecuta ./install.sh --panel."
            return
        fi
    fi
    _doctor_check "addons" ok "$(printf '%s' "$OUT" | head -1 | sed 's/^build-addons: //')"
}

# Las filas esES de mod-transmog que el propio módulo no trae (ids 18 y 19) las
# pone patches/locales-es/ en la fase 5, ANTES del arranque que ejecuta el SQL
# del módulo; si ese SQL se reejecuta (renombrado de ficheros, versión nueva) su
# DELETE sobre module_string_locale las borra. Avisa y da el remedio.
_doctor_check_translations() {
    [ "${LOCALE_ES:-false}" = true ] && [ "${INSTALL_MOD_TRANSMOG:-false}" = true ] || return 0
    command -v mysql >/dev/null 2>&1 || return 0
    local N
    N=$(mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -N -B "$DOCTOR_WORLD_DB" -e         "SELECT COUNT(*) FROM module_string_locale WHERE module='mod-transmog' AND id IN (18,19) AND locale='esES';" 2>/dev/null) || N=""
    case "$N" in
        2)  _doctor_check "traducciones-es" ok "mod-transmog: textos 18 y 19 en esES presentes." ;;
        "") _doctor_check "traducciones-es" warn "no se pudo leer module_string_locale (¿acore_world sin crear?)." ;;
        *)  _doctor_check "traducciones-es" warn "mod-transmog: faltan filas esES (hay $N de 2). Las borró el SQL del módulo al reejecutarse; reaplícalas con: bash scripts/reaplicar-traducciones.sh" ;;
    esac
}

# Recursos que el panel genera desde el cliente del jugador (iconos de la armería,
# parches de idioma, mapas). Que falten NO es un fallo del servidor, pero la
# instalación no está completa hasta prepararlos: aviso con el paso a seguir.
_doctor_check_resources() {
    [ "${INSTALL_WEB_PANEL:-true}" = true ] || return 0
    local STATE="${PANEL_RESOURCES_DIRECTORY:-/var/lib/azerothcore-panel/recursos}/estado.json" PENDING
    if [ ! -d "$(dirname "$STATE")" ]; then
        _doctor_check "recursos-cliente" warn "el panel aún no ha creado su carpeta de recursos (¿arrancó?)."
        return
    fi
    PENDING=$(python3 - "$(dirname "$STATE")" <<'PY' 2>/dev/null || echo "?"
import json, os, sys
root = sys.argv[1]
def has(*parts): return os.path.isfile(os.path.join(root, *parts))
pending = []
if not has("iconos", "map.json"): pending.append("iconos de la armería")
# esES es el idioma del proyecto; enUS sólo existe si el cliente del jugador lo trae.
if not has("parches", "esES", "patch-esES-4.MPQ"): pending.append("patch-esES-4.MPQ")
missing = [m for m in ("0", "1", "530", "571") if not has("mapas", m + ".jpg")]
if missing: pending.append("mapas " + ", ".join(missing))
print("; ".join(pending))
PY
)
    if [ "$PENDING" = "?" ]; then
        _doctor_check "recursos-cliente" warn "no se pudo leer el estado de los recursos."
    elif [ -z "$PENDING" ]; then
        _doctor_check "recursos-cliente" ok "iconos, parches de idioma y mapas del panel preparados."
    else
        _doctor_check "recursos-cliente" warn "pendiente: $PENDING. Falta el paso del cliente: abre el panel, Addons, y elige tu carpeta de WoW (un administrador); los genera desde tu cliente."
    fi
}

# Cliente web del navegador (fase 10, opcional): puente activo, nginx con /play/ y las cabeceras de aislamiento, build
# desplegado y Data preparada. Un fallo no afecta al servidor de juego, pero el cliente web no funcionaria.
_doctor_check_web_client() {
    [ "${INSTALL_WEB_CLIENT:-false}" = true ] || return 0
    local ROOT="${WEB_CLIENT_ROOT:-/var/lib/azerothcore-play}" PORT="${PANEL_HTTPS_PORT:-443}" BASE HDR ID PROBLEMS=()
    if ! systemctl is-active --quiet azerothcore-web-bridge 2>/dev/null; then
        PROBLEMS+=("el puente (azerothcore-web-bridge) no está activo")
    fi
    [ -f "$ROOT/current/build.json" ] || PROBLEMS+=("no hay build desplegado en $ROOT/current")
    [ -f "$ROOT/datos/manifiesto.tsv" ] || PROBLEMS+=("falta $ROOT/datos/manifiesto.tsv (WEB_CLIENT_DATA_DIR)")
    if command -v curl >/dev/null 2>&1; then
        BASE="https://127.0.0.1"; [ "$PORT" = 443 ] || BASE="$BASE:$PORT"
        HDR=$(curl -ksI --max-time 5 "$BASE/play/" 2>/dev/null || true)
        printf '%s' "$HDR" | grep -qi '^cross-origin-embedder-policy: require-corp' || PROBLEMS+=("/play/ no devuelve COEP (nginx sin la configuración del cliente web)")
    fi
    if [ "${#PROBLEMS[@]}" -eq 0 ]; then
        ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$ROOT/current/build.json" 2>/dev/null || true)
        _doctor_check "web-client" ok "puente activo, /play/ con aislamiento de origen cruzado, build ${ID:-?} y datos listos."
    else
        _doctor_check "web-client" fail "$(IFS=';'; echo "${PROBLEMS[*]}") — ./install.sh --webclient."
    fi
}

# =============================================================================
# run_doctor EVENTO — ejecuta todas las comprobaciones y persiste el resultado
# =============================================================================
run_doctor() {
    local EVENT="${1:-manual}"
    local START_MS END_MS DURATION_MS
    START_MS=$(date +%s%3N)
    DOCTOR_CHECKS=()

    header "doctor — comprobación de salud (evento: ${EVENT})"

    _doctor_check_mirrors
    _doctor_check_pinned_versions
    _doctor_check_known_keys
    _doctor_check_unknown_keys
    _doctor_check_own_modules
    _doctor_check_server_dbc
    _doctor_check_client_data
    _doctor_check_addons
    _doctor_check_resources
    _doctor_check_web_client
    _doctor_check_translations
    _doctor_check_services
    _doctor_check_disk_space
    _doctor_check_slow_ticks

    local OVERALL="ok" ENTRY STATUS
    for ENTRY in "${DOCTOR_CHECKS[@]}"; do
        STATUS="${ENTRY#*$'\t'}"; STATUS="${STATUS%%$'\t'*}"
        if [ "$STATUS" = "fail" ]; then OVERALL="fail"
        elif [ "$STATUS" = "warn" ] && [ "$OVERALL" != "fail" ]; then OVERALL="warn"; fi
    done

    END_MS=$(date +%s%3N)
    DURATION_MS=$((END_MS - START_MS))

    case "$OVERALL" in
        ok)   log  "[doctor] Resultado: OK (${DURATION_MS} ms)." ;;
        warn) warn "[doctor] Resultado: AVISOS (${DURATION_MS} ms)." ;;
        fail) error "[doctor] Resultado: FALLO (${DURATION_MS} ms)." ;;
    esac

    _doctor_persist "$EVENT" "$OVERALL" "$DURATION_MS"

    [ "$OVERALL" != "fail" ]
}

# Escribe doctor_status (fila única, id=1: "el resultado más reciente") y
# añade una fila a doctor_history (recortada a las últimas 50), en
# acore_world, con las MISMAS credenciales que ya usa el resto del
# instalador (AC_DB_USER/AC_DB_PASS) y que el propio worldserver — sin
# credencial nueva que gestionar ni fichero que hacer legible entre usuarios
# (a diferencia de versions.lock, que sí necesita esa copia porque el panel
# corre con un DynamicUser aislado; esto lo lee por MySQL, no por fichero).
_doctor_persist() {
    local EVENT="$1" OVERALL="$2" DURATION_MS="$3"
    command -v mysql >/dev/null 2>&1 || return 0

    if ! mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -e "SELECT 1;" "$DOCTOR_WORLD_DB" >/dev/null 2>&1; then
        warn "[doctor] No se pudo conectar a ${DOCTOR_WORLD_DB}: resultado no persistido para el panel."
        return 0
    fi

    mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" "$DOCTOR_WORLD_DB" >>"$INSTALL_LOG" 2>&1 <<'DOCTORSCHEMA'
CREATE TABLE IF NOT EXISTS `doctor_status` (
  `id` tinyint unsigned NOT NULL,
  `event_type` varchar(32) NOT NULL,
  `overall_result` varchar(8) NOT NULL,
  `duration_ms` int unsigned NOT NULL,
  `checks` JSON NOT NULL,
  `modules` JSON NOT NULL,
  `installer_commit` varchar(40) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `doctor_history` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `event_type` varchar(32) NOT NULL,
  `overall_result` varchar(8) NOT NULL,
  `duration_ms` int unsigned NOT NULL,
  `checks` JSON NOT NULL,
  `installer_commit` varchar(40) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX idx_doctor_history_created_at (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ALTER en vez de exigir una instalación desde cero: doctor_status ya vivía
-- en producción (P0-P2 de hoy) sin la columna `modules`, añadida al ampliar
-- el dashboard a "Estado y rendimiento". information_schema en vez de un
-- ALTER a ciegas: repetir un ALTER ADD COLUMN sobre una columna que ya existe
-- es un error, no un no-op.
DOCTORSCHEMA

    if ! mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -N -B "$DOCTOR_WORLD_DB" \
        -e "SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='doctor_status' AND column_name='modules';" \
        2>>"$INSTALL_LOG" | grep -q 1; then
        mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" "$DOCTOR_WORLD_DB" \
            -e "ALTER TABLE doctor_status ADD COLUMN modules JSON NOT NULL AFTER checks;" >>"$INSTALL_LOG" 2>&1
    fi

    local CHECKS_JSON MODULES_JSON COMMIT_SHA EVENT_ESC OVERALL_ESC CHECKS_ESC MODULES_ESC COMMIT_ESC
    CHECKS_JSON=$(_doctor_checks_to_json)
    MODULES_JSON=$(_doctor_build_modules_json)
    COMMIT_SHA=$(git -C "$INSTALLER_DIR" rev-parse HEAD 2>/dev/null || echo "")

    EVENT_ESC=$(_doctor_sql_escape "$EVENT")
    OVERALL_ESC=$(_doctor_sql_escape "$OVERALL")
    CHECKS_ESC=$(_doctor_sql_escape "$CHECKS_JSON")
    MODULES_ESC=$(_doctor_sql_escape "$MODULES_JSON")
    COMMIT_ESC=$(_doctor_sql_escape "$COMMIT_SHA")

    mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" "$DOCTOR_WORLD_DB" >>"$INSTALL_LOG" 2>&1 <<SQL
INSERT INTO doctor_status (id, event_type, overall_result, duration_ms, checks, modules, installer_commit)
VALUES (1, '${EVENT_ESC}', '${OVERALL_ESC}', ${DURATION_MS}, '${CHECKS_ESC}', '${MODULES_ESC}', '${COMMIT_ESC}')
ON DUPLICATE KEY UPDATE
  event_type = VALUES(event_type), overall_result = VALUES(overall_result),
  duration_ms = VALUES(duration_ms), checks = VALUES(checks), modules = VALUES(modules),
  installer_commit = VALUES(installer_commit), updated_at = VALUES(updated_at);

INSERT INTO doctor_history (event_type, overall_result, duration_ms, checks, installer_commit)
VALUES ('${EVENT_ESC}', '${OVERALL_ESC}', ${DURATION_MS}, '${CHECKS_ESC}', '${COMMIT_ESC}');

DELETE FROM doctor_history WHERE id NOT IN (
  SELECT id FROM (SELECT id FROM doctor_history ORDER BY id DESC LIMIT 50) AS keep
);
SQL

    if [ $? -eq 0 ]; then
        info "[doctor] Resultado guardado en ${DOCTOR_WORLD_DB}.doctor_status (panel: Estado y rendimiento)."
    else
        warn "[doctor] No se pudo guardar el resultado en ${DOCTOR_WORLD_DB} (ver ${INSTALL_LOG})."
    fi
}
