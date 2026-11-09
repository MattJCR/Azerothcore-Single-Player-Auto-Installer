#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#  lib/utils.sh — Funciones compartidas de logging y utilidades
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# El log va a /tmp mientras no exista el directorio de AC,
# y se mueve al destino definitivo tras el clonado (fase 03).
# Usamos $AC_DIR (config.sh se sourcea antes que este fichero) en vez de
# asumir $HOME/azerothcore: si el usuario cambia AC_DIR, el log lo sigue.
AC_LOG_BASE="${AC_DIR:-$HOME/azerothcore}"
if [ -d "$AC_LOG_BASE" ]; then
    mkdir -p "$AC_LOG_BASE/logs"
    INSTALL_LOG="$AC_LOG_BASE/logs/install.log"
else
    INSTALL_LOG="/tmp/azerothcore-install.log"
fi

# Si el directorio del log desaparece a mitad de una fase (p.ej. la fase 03
# mueve $AC_DIR a un backup antes de clonar), volvemos a /tmp en vez de dejar
# que los redirects `>> "$INSTALL_LOG"` fallen y aborten la fase con un error
# engañoso. NO creamos el directorio: hacerlo rompería el `git clone` posterior.
_ensure_log_dir() {
    [ -d "$(dirname "$INSTALL_LOG")" ] || INSTALL_LOG="/tmp/azerothcore-install.log"
}

# Redirige el log al destino definitivo en cuanto el directorio existe.
_redirect_log_if_needed() {
    if [ "$INSTALL_LOG" = "/tmp/azerothcore-install.log" ] && [ -d "$AC_LOG_BASE" ]; then
        mkdir -p "$AC_LOG_BASE/logs"
        INSTALL_LOG="$AC_LOG_BASE/logs/install.log"
        cat /tmp/azerothcore-install.log >> "$INSTALL_LOG" 2>/dev/null || true
    fi
}

_log_line() { _ensure_log_dir; echo -e "$1" | tee -a "$INSTALL_LOG"; }

log()    { _log_line "${GREEN}[OK]${NC}  $*"; }
info()   { _log_line "${BLUE}[--]${NC}  $*"; }
warn()   { _log_line "${YELLOW}[!!]${NC}  $*"; }
error()  { _log_line "${RED}[ERR]${NC} $*"; }
header() {
    local LINE="══════════════════════════════════════════"
    _log_line "\n${BOLD}${CYAN}${LINE}${NC}"
    _log_line "${BOLD}${CYAN}  $*${NC}"
    _log_line "${BOLD}${CYAN}${LINE}${NC}\n"
}

# Ejecuta un comando, muestra progreso y sale si falla
run() {
    local DESC="$1"; shift
    info "$DESC..."
    _ensure_log_dir
    if "$@" >> "$INSTALL_LOG" 2>&1; then
        log "$DESC — hecho."
    else
        error "$DESC — FALLÓ. Revisa: $INSTALL_LOG"
        exit 1
    fi
}

# Cola de escrituras diferidas por fichero.
#
# set_conf_value() se llama ~557 veces sólo en la fase 5, cada una con su
# propio sed -i (abre, reescribe y renombra el fichero entero) más el grep
# previo: para un .conf con 40 claves tocadas, eso son 80 procesos y 40
# reescrituras completas del mismo fichero. Ahora sólo ENCOLA el par
# clave/valor en memoria; flush_conf_files() aplica TODAS las claves
# pendientes de cada fichero en una sola pasada de sed (una reescritura por
# fichero, no por clave) cuando se la llama explícitamente al final de la
# fase. El separador 0x1E (Record Separator) no puede aparecer en una ruta
# real, así que sirve para componer la clave compuesta "fichero\x1Eclave"
# sin ambigüedad.
declare -gA CONF_PENDING_KEYS=()
declare -gA CONF_PENDING_FILES=()

# Busca una clave en un .conf y sustituye su valor (en la cola, ver arriba).
# Si la clave no existe en el fichero, se añade al final cuando se vacíe la
# cola. Llamar dos veces con la misma clave y fichero dentro de la misma
# fase dice lo mismo que antes: gana el último valor.
#
# Tanto la clave como el valor se escapan antes de entrar en sed: sin esto,
# una contraseña con '|', '&' o '\' (justo lo que produce un generador de
# contraseñas decente) corrompe el .conf o escribe un valor equivocado, y los
# puntos de claves como "Rate.XP.Kill" actúan como comodines de regex.
set_conf_value() {
    local FILE="$1"
    local KEY="$2"
    local VALUE="$3"
    CONF_PENDING_KEYS["${FILE}"$'\x1e'"${KEY}"]="$VALUE"
    CONF_PENDING_FILES["$FILE"]=1
}

# Aplica TODAS las claves encoladas por set_conf_value() desde la última vez
# que se llamó a esta función (o desde el arranque de la fase), un fichero a
# la vez. Debe llamarse al final de cada fase que use set_conf_value —
# ahora mismo la 5 y la 8 — porque hasta entonces nada se ha escrito en
# disco todavía.
flush_conf_files() {
    local FILE
    for FILE in "${!CONF_PENDING_FILES[@]}"; do
        _flush_one_conf_file "$FILE"
    done
    CONF_PENDING_KEYS=()
    CONF_PENDING_FILES=()
}

_flush_one_conf_file() {
    local FILE="$1"
    if [ ! -f "$FILE" ]; then
        warn "flush_conf_files: $FILE no existe, se descartan sus claves pendientes."
        return 1
    fi

    local ENTRY_KEY KEY VALUE KEY_RE VALUE_ESC
    local -a SED_EXPRS=() MISSING_KEYS=() MISSING_VALUES=()

    for ENTRY_KEY in "${!CONF_PENDING_KEYS[@]}"; do
        # Sólo las entradas de ESTE fichero: el prefijo "$FILE\x1E" es exacto,
        # así que un fichero cuyo nombre sea prefijo de otro (p.ej.
        # "a.conf" dentro de "a.conf.dist") no puede confundirse con él.
        case "$ENTRY_KEY" in
            "${FILE}"$'\x1e'*) ;;
            *) continue ;;
        esac
        KEY="${ENTRY_KEY#"${FILE}"$'\x1e'}"
        VALUE="${CONF_PENDING_KEYS[$ENTRY_KEY]}"

        # Metacaracteres literales en BRE y ERE por igual: ] [ \ . * ^ $
        KEY_RE=$(printf '%s' "$KEY" | sed 's/[][\.*^$]/\\&/g')
        # En el texto de reemplazo de sed: \ escapa, & es "todo lo casado",
        # y | es nuestro delimitador.
        VALUE_ESC=$(printf '%s' "$VALUE" | sed 's/[\\&|]/\\&/g')

        if grep -qE "^[[:space:]]*${KEY_RE}[[:space:]]*=" "$FILE"; then
            SED_EXPRS+=(-e "s|^[[:space:]]*${KEY_RE}[[:space:]]*=.*|${KEY} = ${VALUE_ESC}|")
        else
            MISSING_KEYS+=("$KEY")
            MISSING_VALUES+=("$VALUE")
        fi
    done

    # Una única reescritura del fichero para TODAS sus claves ya declaradas,
    # en vez de una por clave. sed aplica cada expresión a las líneas que le
    # correspondan (a lo sumo una por línea, porque cada patrón exige la
    # clave completa antes del "="), así que el orden entre expresiones no
    # importa y una clave duplicada en el fichero se actualiza en sus dos
    # líneas, igual que antes.
    if [ "${#SED_EXPRS[@]}" -gt 0 ]; then
        sed -i "${SED_EXPRS[@]}" "$FILE"
    fi

    # La clave NO estaba en el fichero. Y eso casi siempre significa que no
    # existe: los .conf se copian de su .conf.dist, que declara todas las
    # claves reales del programa (comentadas o no). Escribirla igualmente la
    # deja pegada al final del fichero sin que la lea nadie.
    #
    # Este agujero ha costado ya cuatro incidentes reales, los cuatro mudos:
    #   Playerbots.RandomBotMaxGearQuality           bots vestidos de azul
    #   Playerbots.LevelBrackets.*                   sin bots de nivel 80
    #   MapUpdateThreadCount                          mapas con UN hilo
    #   AllowTwoSide.{Trade,Mail,WhoList,AddFriend}   cross-faction a medias
    #
    # Por eso ahora avisa fuerte y queda apuntado para el resumen del final.
    # Las excepciones legítimas van en la lista blanca: claves que mod-playerbots
    # exige en worldserver.conf y que el .conf.dist del core no declara.
    local i
    for i in "${!MISSING_KEYS[@]}"; do
        KEY="${MISSING_KEYS[$i]}"
        VALUE="${MISSING_VALUES[$i]}"
        case "$KEY" in
            PlayerbotsDatabaseInfo|Playerbots.Updates.EnableDatabases)
                printf '%s = %s\n' "$KEY" "$VALUE" >> "$FILE"
                info "Añadida clave '${KEY}' a $(basename "$FILE") (adición prevista)"
                ;;
            *)
                printf '%s = %s\n' "$KEY" "$VALUE" >> "$FILE"
                warn "Clave '${KEY}' NO declarada en $(basename "$FILE"): se añade al final, pero comprueba que el programa la lea de verdad."
                CONF_KEYS_DESCONOCIDAS="${CONF_KEYS_DESCONOCIDAS:-}${CONF_KEYS_DESCONOCIDAS:+ }$(basename "$FILE"):${KEY}"
                ;;
        esac
    done
}

# Resumen al terminar la fase: si se añadió alguna clave no declarada, se repite
# aquí para que no se pierda entre cientos de líneas de salida.
report_unknown_conf_keys() {
    [ -n "${CONF_KEYS_DESCONOCIDAS:-}" ] || return 0
    warn "Claves escritas que NO estaban declaradas en su .conf.dist:"
    local k
    for k in $CONF_KEYS_DESCONOCIDAS; do
        warn "    $k"
    done
    warn "Si alguna no existe en el programa, no la lee nadie: revísala."
}

# Convierte true/false a 1/0
bool_to_int() {
    [ "$1" = "true" ] && echo 1 || echo 0
}

# Comprueba si MySQL acepta conexiones con las credenciales indicadas
check_mysql_connection() {
    local USER="$1"
    local PASS="$2"
    mysql -u "$USER" -p"$PASS" -e "SELECT 1;" &>/dev/null
}

# Exige MySQL 8.0+. La semilla de mod-server-help usa alias de fila tras VALUES
# ("AS new"), sintaxis de MySQL 8.0.19+ que MariaDB no entiende: aplicada sobre
# el motor equivocado falla a mitad de fichero y deja las tablas a medias sin
# ningún aviso claro (ver apply_sql_dir). En vez de mantener dos sintaxis,
# el instalador declara un único motor soportado y aborta pronto si no es ese.
#
# Recibe el comando mysql ya construido, tal cual se invocaría (sin comillas,
# igual que $MYSQL_ROOT en 02_mysql_setup.sh), porque en fase 2 se comprueba
# con las credenciales de root y en fase 5 con las de acore:
#   require_mysql8 $MYSQL_ROOT
#   require_mysql8 mysql -u "$AC_DB_USER" -p"$AC_DB_PASS"
require_mysql8() {
    local VERSION_STRING
    VERSION_STRING=$("$@" -N -e "SELECT VERSION();" 2>>"$INSTALL_LOG")

    if [ -z "$VERSION_STRING" ]; then
        error "No se pudo consultar la versión de MySQL (¿está arrancado el servicio?)."
        return 1
    fi

    if [[ "$VERSION_STRING" == *MariaDB* ]]; then
        error "Este instalador exige MySQL 8.0+; el servidor conectado es MariaDB ($VERSION_STRING)."
        error "La semilla de mod-server-help usa sintaxis de MySQL 8.0.19+ (alias de fila tras VALUES) que MariaDB no admite."
        return 1
    fi

    local MAJOR="${VERSION_STRING%%.*}"
    if ! [[ "$MAJOR" =~ ^[0-9]+$ ]] || [ "$MAJOR" -lt 8 ]; then
        error "Este instalador exige MySQL 8.0+; se detectó la versión $VERSION_STRING."
        return 1
    fi

    return 0
}

# ¿Existe la base de datos indicada? (evita repetir el SHOW DATABASES en cada fase)
db_exists() {
    local DB="$1"
    mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" \
        -e "SHOW DATABASES LIKE '${DB}';" 2>/dev/null | grep -qx "$DB"
}

# ¿Existe la tabla indicada dentro de una base? A diferencia de db_exists,
# esto distingue el esquema (lo crea la fase 2, vacío) de sus tablas: en
# acore_playerbots las crea el propio mod-playerbots en el primer arranque,
# igual que acore_world/acore_characters. db_exists solo no basta para saber
# si ya se puede insertar en ellas (15/09/2026, fallo real en una reinstalación
# desde cero: "Table 'acore_playerbots.ai_playerbot_texts' doesn't exist").
table_exists() {
    local DB="$1" TABLE="$2"
    mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB}' AND table_name='${TABLE}';" \
        2>/dev/null | grep -qx 1
}

# Busca un fichero .conf.dist de un módulo en múltiples rutas posibles
# y lo copia a etc/modules/ con y sin extensión .dist
install_module_conf() {
    local MODULE_NAME="$1"
    local CONF_BASENAME="$2"          # e.g. "playerbots.conf"
    local MODULE_DIR="$AC_DIR/modules/$MODULE_NAME"
    local DST_DIR="$AC_DIR/env/dist/etc/modules"
    mkdir -p "$DST_DIR"

    # Rutas donde los distintos módulos depositan sus confs
    local SEARCH_PATHS=(
        "$MODULE_DIR/conf/${CONF_BASENAME}.dist"
        "$MODULE_DIR/conf/${CONF_BASENAME}"
        "$AC_DIR/env/dist/etc/modules/${CONF_BASENAME}.dist"
        "$AC_DIR/env/dist/bin/${CONF_BASENAME}.dist"
        "$AC_DIR/env/dist/bin/${CONF_BASENAME}"
    )

    local SRC=""
    for PATH_CANDIDATE in "${SEARCH_PATHS[@]}"; do
        if [ -f "$PATH_CANDIDATE" ]; then
            SRC="$PATH_CANDIDATE"
            break
        fi
    done

    if [ -z "$SRC" ]; then
        warn "[$MODULE_NAME] No se encontró ${CONF_BASENAME}.dist en ninguna ruta conocida."
        warn "  Rutas buscadas:"
        for P in "${SEARCH_PATHS[@]}"; do warn "    $P"; done
        return 1
    fi

    cp "$SRC" "$DST_DIR/${CONF_BASENAME}.dist"
    cp "$SRC" "$DST_DIR/${CONF_BASENAME}"
    log "[$MODULE_NAME] ${CONF_BASENAME} instalado en etc/modules/"
    return 0
}

# =============================================================================
# Aplica TODOS los .sql de un directorio (en orden alfabético) contra una BD.
#
# Antes se usaba `find ... | head -1`, que aplicaba UN fichero arbitrario (el
# orden de find no está definido) e ignoraba el resto en silencio. Varios
# módulos traen más de un .sql — mod-arac, o los típicos base/ + updates/ —
# así que se quedaban a medio instalar sin ningún aviso.
#
# Devuelve el número de ficheros fallidos (0 = todo bien). Los SQL de los
# módulos son idempotentes por diseño (CREATE TABLE IF NOT EXISTS, INSERT ...
# ON DUPLICATE KEY UPDATE): un fallo real aquí es un fallo real, no "ya estaba
# aplicado", así que se propaga en vez de convertirse en un aviso.
#
# Uso: apply_sql_dir "<etiqueta>" "<base_de_datos>" "<directorio>"
# =============================================================================
apply_sql_dir() {
    local LABEL="$1"
    local DB="$2"
    local DIR="$3"
    local FILES=()
    local FAILED=()
    local F OK=0

    if [ ! -d "$DIR" ]; then
        warn "[$LABEL] No existe el directorio de SQL: $DIR"
        return 1
    fi

    # Se excluyen los ficheros bajo una carpeta "(Optional)": por convención del
    # upstream de mod-arac eso no son scripts a ejecutar, sino PLANTILLAS para
    # que te fabriques una raza propia. Aplicarlas tal cual siempre falla y
    # ensucia el log con un error que parece grave y no lo es.
    #
    # LC_ALL=C para que el orden no dependa del locale del sistema (evita que
    # "10_x.sql" y "2_x.sql" se ordenen de forma distinta según la máquina).
    mapfile -t FILES < <(find "$DIR" -type f -name '*.sql' -not -path '*(Optional)*' | LC_ALL=C sort)

    # Un directorio sin .sql no es un fallo: muchos módulos traen db-world/
    # db-characters como andamiaje y sólo usan uno de los dos (o ninguno
    # todavía, como patches/custom-items/ sin objetos propios). El fallo real
    # es un fichero que SÍ está y no aplica limpio (abajo) — eso sí aborta.
    # (15/09/2026: esta rama SÍ abortaba la fase entera — mod-challenge-modes
    # trae data/sql/db-characters/updates/ vacío salvo un .gitkeep — y como
    # tumbaba la fase 8 con set -e, se saltaba todo lo que venía después:
    # mod-arac, recompensas, traducciones, NPC de servicio.)
    if [ "${#FILES[@]}" -eq 0 ]; then
        info "[$LABEL] Sin .sql que aplicar en $DIR (nada que hacer)."
        return 0
    fi

    for F in "${FILES[@]}"; do
        if mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" "$DB" < "$F" >> "$INSTALL_LOG" 2>&1; then
            log "[$LABEL] $(basename "$F") → $DB"
            OK=$((OK + 1))
        else
            FAILED+=("$(basename "$F")")
        fi
    done

    if [ "${#FAILED[@]}" -gt 0 ]; then
        error "[$LABEL] ${#FAILED[@]}/${#FILES[@]} ficheros SQL fallaron en $DB: ${FAILED[*]} (revisa $INSTALL_LOG)."
        return "${#FAILED[@]}"
    fi

    info "[$LABEL] $OK/${#FILES[@]} ficheros SQL aplicados en $DB."
    return 0
}

# =============================================================================
# Parche para mod-dungeon-master: bug conocido de columna desactualizada
# El módulo usa `id1` (nombre antiguo) en vez de `id` para referenciar
# creature.id en sus JOINs, tanto en el SQL de setup como en el código C++.
# Esto rompe la importación inicial y causa un segfault en tiempo de
# ejecución contra el esquema actual de AzerothCore.
# Issue a reportar upstream: https://github.com/InstanceForge/mod-dungeon-master
# Esta función es idempotente: si ya no queda ningún `id1`, no hace nada.
#
# OJO: el parche deja el árbol de git sucio, así que weekly-update.sh hace
# `git reset --hard` ANTES de cada pull y vuelve a llamar aquí después.
# =============================================================================
patch_dungeon_master_id1_bug() {
    local MODULE_DIR="$AC_DIR/modules/mod-dungeon-master"
    [ -d "$MODULE_DIR" ] || return 0

    local PATCHED=false

    # --- SQL de setup inicial ---
    local SQL_FILE="$MODULE_DIR/data/sql/db-world/base/dm_setup.sql"
    if [ -f "$SQL_FILE" ] && grep -q '`id1`' "$SQL_FILE" 2>/dev/null; then
        sed -i 's/`id1`/`id`/g' "$SQL_FILE"
        info "[mod-dungeon-master] Parche aplicado: dm_setup.sql (\`id1\` → \`id\`)"
        PATCHED=true
    fi

    # --- Código C++: queries en tiempo de ejecución ---
    local CPP_FILES=(
        "$MODULE_DIR/src/DMBossSpawnQuery.h"
        "$MODULE_DIR/src/DungeonMasterMgr.cpp"
    )
    for F in "${CPP_FILES[@]}"; do
        if [ -f "$F" ] && grep -q 'c\.id1 = ct\.entry' "$F" 2>/dev/null; then
            sed -i 's/c\.id1 = ct\.entry/c.id = ct.entry/' "$F"
            info "[mod-dungeon-master] Parche aplicado: $(basename "$F") (c.id1 → c.id)"
            PATCHED=true
        fi
    done

    if [ "$PATCHED" = true ]; then
        log "[mod-dungeon-master] Parche del bug 'id1' aplicado correctamente."
    fi
    return 0
}

# =============================================================================
# Limpieza de rastros en la BD al desactivar un módulo
#
# Apartar el módulo de modules/ evita que se compile, pero sus filas siguen en
# acore_world: el core avisa en cada arranque de que hay un ScriptName asignado
# sin código detrás, y quedan NPCs plantados que no hacen nada.
# Se llama desde la fase 3 justo al desactivar un módulo. Es idempotente.
# =============================================================================
cleanup_disabled_module_db() {
    local MODULE="$1"

    # mod-adaptive-ai guarda todo su estado en acore_playerbots, no en world.
    # Al archivarlo no debe quedar una lista histórica de bots, partidas o
    # modelos que pueda reaparecer si alguien lo reactiva por accidente. El
    # entrenamiento útil ya se exporta antes de desactivarlo (ver CHANGELOG).
    if [ "$MODULE" = "mod-adaptive-ai" ] && db_exists acore_playerbots; then
        local ADAPTIVE_TABLES TOTAL=0 TABLE N SQL
        ADAPTIVE_TABLES=$(mysql_q "SELECT table_name FROM information_schema.tables
                                   WHERE table_schema='acore_playerbots'
                                     AND table_name LIKE 'adaptive\\_%' ESCAPE '\\\\'
                                   ORDER BY table_name;")
        for TABLE in $ADAPTIVE_TABLES; do
            N=$(mysql_q "SELECT COUNT(*) FROM acore_playerbots.\`${TABLE}\`;")
            TOTAL=$((TOTAL + ${N:-0}))
        done
        if [ "$TOTAL" -gt 0 ]; then
            SQL="SET FOREIGN_KEY_CHECKS=0;"
            for TABLE in $ADAPTIVE_TABLES; do
                SQL+="TRUNCATE TABLE acore_playerbots.\`${TABLE}\`;"
            done
            SQL+="SET FOREIGN_KEY_CHECKS=1;"
            mysql_q "$SQL"
            log "[$MODULE] Estado adaptive_* vaciado de acore_playerbots (${TOTAL} filas)."
        fi
    fi

    db_exists acore_world || return 0

    # Módulos cuya limpieza es siempre la misma: quitar el ScriptName que quedó
    # asignado en la BD (si no, el core avisa en cada arranque de que hay un
    # script asignado sin código detrás) y borrar las apariciones de su NPC.
    #   modulo : tabla : ScriptName : entradas a desaparecer (vacío = ninguna)
    local SIMPLE=(
        "mod-challenge-modes:gameobject_template:gobject_challenge_modes:254605"
        "mod-racial-trait-swap:creature_template:npc_race_trait_swap:98888"
        "mod-reagent-bank:creature_template:npc_reagent_banker:290011"
        "mod-1v1-arena:creature_template:npc_1v1arena:999991"
        "mod-war-effort:creature_template:npc_mod_war_effort_quartermaster:"
        "mod-progression-skip:creature_template:npc_progression_skip:600200"
    )

    local ENTRY MOD TABLE SCRIPT IDS SPAWN_TABLE N
    for ENTRY in "${SIMPLE[@]}"; do
        IFS=':' read -r MOD TABLE SCRIPT IDS <<< "$ENTRY"
        [ "$MOD" = "$MODULE" ] || continue

        N=$(mysql_q "SELECT COUNT(*) FROM acore_world.${TABLE} WHERE ScriptName='${SCRIPT}';")
        [ "${N:-0}" -gt 0 ] || return 0

        mysql_q "UPDATE acore_world.${TABLE} SET ScriptName='' WHERE ScriptName='${SCRIPT}';"
        if [ -n "$IDS" ]; then
            # creature_template -> creature | gameobject_template -> gameobject
            SPAWN_TABLE="${TABLE%_template}"
            mysql_q "DELETE FROM acore_world.${SPAWN_TABLE} WHERE id IN (${IDS});"
        fi
        log "[$MODULE] Rastros en la BD limpiados (ScriptName '${SCRIPT}')."
        return 0
    done

    case "$MODULE" in
        mod-dungeon-master)
            # "Script named 'npc_dungeon_master' is assigned in the database,
            # but has no code!" + 11 NPCs mudos en las capitales.
            local N
            N=$(mysql_q "SELECT COUNT(*) FROM acore_world.creature_template WHERE ScriptName='npc_dungeon_master';")
            if [ "${N:-0}" -gt 0 ]; then
                mysql_q "UPDATE acore_world.creature_template SET ScriptName='' WHERE ScriptName='npc_dungeon_master';"
                mysql_q "DELETE FROM acore_world.creature WHERE id=500000;"
                log "[$MODULE] Rastros en la BD limpiados (NPC 500000 y su ScriptName)."
            fi
            ;;
    esac
    return 0
}

# =============================================================================
# Crontab
#
# Todas las entradas que pone el instalador llevan el marcador CRON_TAG al
# final de la línea (cron pasa el comando a sh, que trata '#' como comentario).
# Así la fase 7 puede borrar las suyas y volver a escribirlas: antes se hacía
# un simple "¿existe esta línea exacta?", de modo que cambiar una hora en
# config.sh y relanzar la fase dejaba DOS reinicios diarios programados.
# =============================================================================
CRON_TAG="# AZEROTHCORE-INSTALLER"

clear_installer_cron() {
    local CURRENT KEPT
    CURRENT=$(crontab -l 2>/dev/null || true)
    [ -n "$CURRENT" ] || return 0

    # OJO con el `|| true`: grep -v termina en 1 cuando NO deja ninguna línea,
    # y con `set -o pipefail` eso aborta la fase justo después de haber vaciado
    # el crontab del usuario — es decir, se lo borraría y no lo repoblaría.
    KEPT=$(printf '%s\n' "$CURRENT" | grep -vF "$CRON_TAG" || true)

    # Entradas HEREDADAS de instalaciones anteriores: no llevan marcador, así
    # que hay que reconocerlas por lo que ejecutan. Sin esto, la primera vez
    # que se migra a las entradas marcadas quedan las viejas Y las nuevas:
    # dos reinicios diarios, dos actualizaciones semanales y dos reboots.
    KEPT=$(printf '%s\n' "$KEPT" | grep -vF "$AC_SCRIPTS_DIR/" || true)
    KEPT=$(printf '%s\n' "$KEPT" | grep -vE '^[^#]*sudo[[:space:]]+(/usr)?/sbin/reboot[[:space:]]*$' || true)

    KEPT=$(printf '%s\n' "$KEPT" | grep -v '^[[:space:]]*$' || true)

    # Si no ha cambiado nada, no reescribimos el crontab
    if [ "$KEPT" = "$(printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' || true)" ]; then
        return 0
    fi

    if [ -n "$KEPT" ]; then
        printf '%s\n' "$KEPT" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi
    info "Crontab: entradas previas del instalador eliminadas."
}

# Añade una línea al crontab del usuario (marcada, e idempotente)
add_cron() {
    local ENTRY="$1 $CRON_TAG"
    local CURRENT
    CURRENT=$(crontab -l 2>/dev/null || true)

    if printf '%s\n' "$CURRENT" | grep -qF "$ENTRY"; then
        warn "Crontab: entrada ya existe, saltando."
        return 0
    fi

    if [ -n "$CURRENT" ]; then
        printf '%s\n%s\n' "$CURRENT" "$ENTRY" | crontab -
    else
        printf '%s\n' "$ENTRY" | crontab -
    fi
    log "Crontab: entrada añadida."
}

# =============================================================================
# Rutas del propio instalador (para localizar patches/)
# =============================================================================
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHES_DIR="$INSTALLER_DIR/patches"
OWN_MODULES_DIR="$INSTALLER_DIR/modules"

# =============================================================================
# Módulos propios
#
# Los de terceros se clonan de GitHub; los nuestros viven en este repositorio,
# bajo modules/, y se copian a ~/azerothcore/modules para que CMake los compile
# como uno más. Van aparte de patches/ a propósito: un módulo propio no parchea
# código ajeno, así que ninguna actualización puede romperlo ni borrarlo.
#
# Devuelve 0 (éxito, para usarlo con "if") cuando algo cambió y hay que
# recompilar, y 1 cuando no cambió nada. Es idempotente: copia sólo cuando el
# contenido difiere.
#   nombre : condición (true/false)
# =============================================================================
install_own_modules() {
    local CHANGED=1
    local ENTRY MOD_NAME MOD_ON SRC DEST STAGE

    # mod-progression-skip sólo tiene sentido con mod-individual-progression: si
    # el módulo base no está, el NPC no podría avanzar a nadie.
    local PROGRESSION_SKIP_ON=false
    if [ "${INSTALL_MOD_PROGRESSION_SKIP:-false}" = true ] && \
       [ "${INSTALL_MOD_INDIVIDUAL_PROGRESSION:-false}" = true ]; then
        PROGRESSION_SKIP_ON=true
    fi

    local OWN_MODULES=(
        "mod-queue-bots:${INSTALL_MOD_QUEUE_BOTS:-false}"
        "mod-world-bots:${INSTALL_MOD_WORLD_BOTS:-false}"
        "mod-quest-mates:${INSTALL_MOD_QUEST_MATES:-false}"
        "mod-party-here:${INSTALL_MOD_PARTY_HERE:-false}"
        "mod-home-guild:${INSTALL_MOD_HOME_GUILD:-false}"
        "mod-bot-operations:${INSTALL_MOD_BOT_OPERATIONS:-false}"
        "mod-update-notice:${INSTALL_MOD_UPDATE_NOTICE:-false}"
        "mod-server-help:${INSTALL_MOD_SERVER_HELP:-false}"
        "mod-standby:${INSTALL_MOD_STANDBY:-false}"
        "mod-adaptive-ai:${INSTALL_MOD_ADAPTIVE_AI:-false}"
        "mod-progression-skip:${PROGRESSION_SKIP_ON}"
        "mod-treasure:${INSTALL_MOD_TREASURE:-false}"
        "mod-arac-trainer-audit:${INSTALL_MOD_ARAC_TRAINER_AUDIT:-false}"
    )

    # Cabeceras compartidas (modules/shared/*.h): el registro de reservas de
    # bots y el tope de equipo. Cada módulo lleva SU copia en src/ porque los
    # módulos no comparten include path, y las copias tienen que ser byte a
    # byte idénticas (funciones inline con estáticas locales: regla ODR). Por
    # eso hay una sola fuente y se copian aquí, en un directorio de montaje,
    # antes de comparar y copiar. Nunca se editan las copias de src/.
    local SHARED_DIR="$OWN_MODULES_DIR/shared"

    # Módulos propios que ya no existen con ese nombre. Se borran de la
    # instalación: si no, CMake los seguiría compilando y el core cargaría dos
    # veces los mismos scripts.
    local RETIRED_MODULES=(
        "mod-1v1-bots"      # absorbido por mod-queue-bots
    )

    local RETIRED
    for RETIRED in "${RETIRED_MODULES[@]}"; do
        if [ -d "$AC_DIR/modules/$RETIRED" ]; then
            rm -rf "${AC_DIR:?}/modules/${RETIRED:?}"
            warn "[$RETIRED] módulo propio retirado -> eliminado de modules/"
            CHANGED=0
        fi
    done

    for ENTRY in "${OWN_MODULES[@]}"; do
        MOD_NAME="${ENTRY%%:*}"
        MOD_ON="${ENTRY##*:}"
        SRC="$OWN_MODULES_DIR/$MOD_NAME"
        DEST="$AC_DIR/modules/$MOD_NAME"

        if [ "$MOD_ON" != true ]; then
            if [ -d "$DEST" ]; then
                rm -rf "${DEST:?}"
                warn "[$MOD_NAME] desactivado en config.sh -> eliminado de modules/"
                CHANGED=0
            fi
            # Un módulo propio con NPC deja su ScriptName en acore_world; sin
            # código detrás el core avisa en cada arranque. cleanup_disabled_module_db
            # borra ese rastro (lista SIMPLE) y es idempotente.
            cleanup_disabled_module_db "$MOD_NAME"
            continue
        fi

        if [ ! -d "$SRC" ]; then
            warn "[$MOD_NAME] no está en $OWN_MODULES_DIR — se omite."
            continue
        fi

        # Montaje: el módulo tal cual más las cabeceras compartidas en src/.
        STAGE="$(mktemp -d)"
        cp -r "$SRC/." "$STAGE/"
        if [ -d "$SHARED_DIR" ] && [ -d "$STAGE/src" ]; then
            cp "$SHARED_DIR"/*.h "$STAGE/src/" 2>/dev/null || true
        fi

        # diff -r delata cualquier cambio en el código, en las cabeceras
        # compartidas o en el .conf.dist, que es justo cuando hay que
        # recompilar. Sin esto, cada pasada de la fase 3 pediría recompilar
        # aunque no hubiera tocado nada.
        if [ -d "$DEST" ] && diff -rq "$STAGE" "$DEST" >/dev/null 2>&1; then
            info "[$MOD_NAME] ya está al día en modules/."
            rm -rf "$STAGE"
            continue
        fi

        rm -rf "${DEST:?}"
        mkdir -p "$DEST"
        cp -r "$STAGE/." "$DEST/"
        rm -rf "$STAGE"
        log "[$MOD_NAME] módulo propio copiado a modules/ (hay que recompilar)."
        CHANGED=0
    done

    return $CHANGED
}

# Consulta rápida a MySQL sin cabeceras. El 2>/dev/null no es cosmético: sin él
# el aviso "Using a password on the command line interface can be insecure"
# acaba dentro de la variable cuando se captura con $(...).
mysql_q() {
    mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -N -B -e "$1" 2>>"$INSTALL_LOG"
}

# =============================================================================
# Parches sobre el código fuente de módulos de terceros
#
# Se aplican con `git apply` en vez de con sed: son cambios de varias líneas y
# necesitamos poder comprobar si ya están puestos. El orden importa, así que
# los ficheros se recorren ordenados por nombre (01-, 02-, ...).
# =============================================================================

# El diff del árbol de trabajo de un repositorio, preparado para compararlo con
# el de otro árbol: sin las líneas "index" (llevan hashes de blob que no aportan
# nada) y con los ficheros nuevos sin seguimiento incluidos, que `git diff` solo
# no enseña. Devuelve siempre 0: vacío significa árbol limpio.
_module_tree_diff() {
    local DIR="$1" F
    {
        git -C "$DIR" diff --no-color
        # El core contiene logs, scripts operativos y extras sin seguimiento.
        # Sus parches sólo modifican ficheros versionados; no leer esos datos.
        [ "$DIR" = "$AC_DIR" ] && return 0
        while IFS= read -r F; do
            [ -n "$F" ] || continue
            git -C "$DIR" diff --no-color --no-index -- /dev/null "$F" || true
        done < <(git -C "$DIR" ls-files --others --exclude-standard)
    } | grep -v '^index ' || true
}

# =============================================================================
# apply_module_patches MODULO PARCHE... — deja el módulo con todos sus parches
#
# Los parches de un módulo son una PILA: el 02 se escribió sobre el 01 y el 03
# sobre los dos. Por eso no vale comprobar cada uno por separado con
# `git apply --reverse --check`: en cuanto el 02 toca las mismas líneas que el
# 01, la inversa del 01 ya no casa y parecía que "NO aplica" aunque estuviera
# puesto (mod-congrats-on-level, 05/09/2026). Aquí se compara el árbol entero:
#
#   1. Árbol limpio: se aplican todos en orden, comprobando cada uno antes.
#   2. Árbol con cambios: en un worktree temporal se aplican 01, 01+02, ... y
#      se busca la pila más larga cuyo diff sea EXACTAMENTE el del árbol. Esos
#      "ya estaban"; los que siguen se aplican encima. Así un parche nuevo
#      añadido al repositorio se pone sin tocar los anteriores.
#   3. Si ningún prefijo de la pila casa, el árbol tiene cambios que no son
#      de ningún parche: se avisa y no se toca nada, que lo decida alguien.
#
# Devuelve 1 si falta algún parche por aplicar.
# =============================================================================

# Parches sobre una foto sin git (módulo restaurado de mirrors/). No hay árbol que comparar, así
# que cada parche, en orden: si aplica, se aplica; si su inversa aplica, ya estaba puesto; si no,
# error. GIT_CEILING_DIRECTORIES evita que `git apply` suba hasta el repositorio del core (que
# contiene modules/) y tome las rutas del parche como relativas a su raíz.
_apply_patches_to_snapshot() {
    local MODULE="$1" DIR="$2"; shift 2
    local P
    for P in "$@"; do
        if GIT_CEILING_DIRECTORIES="$AC_DIR/modules" git -C "$DIR" apply --unidiff-zero --check "$P" >/dev/null 2>&1; then
            GIT_CEILING_DIRECTORIES="$AC_DIR/modules" git -C "$DIR" apply --unidiff-zero "$P"
            log "[$MODULE] parche aplicado (copia offline, sin git): $(basename "$P")"
        elif GIT_CEILING_DIRECTORIES="$AC_DIR/modules" git -C "$DIR" apply --unidiff-zero --reverse --check "$P" >/dev/null 2>&1; then
            info "[$MODULE] $(basename "$P") ya estaba aplicado (copia offline, sin git)."
        else
            error "[$MODULE] el parche $(basename "$P") NO aplica sobre la copia offline."
            error "  Seguramente la foto no es la versión contra la que se escribió. Revísalo en:"
            error "  $P"
            return 1
        fi
    done
    return 0
}

apply_module_patches() {
    local MODULE="$1"; shift
    local -a PATCHES=("$@")
    local N=${#PATCHES[@]}
    local DIR="$AC_DIR/modules/$MODULE"
    [ "$MODULE" = core ] && DIR="$AC_DIR"
    [ "$N" -gt 0 ] || return 0

    local P
    for P in "${PATCHES[@]}"; do
        if [ ! -f "$P" ]; then
            warn "[$MODULE] no se encuentra el parche $P"
            return 1
        fi
    done

    if [ ! -d "$DIR/.git" ]; then
        # Sin carpeta: no está instalado. Con carpeta y sin .git: foto restaurada desde mirrors/
        # (restore_from_mirror: el upstream ya no existe o no hay red), sin historia de git. Hasta
        # el 09/11/2026 aquí se abortaba, así que la copia de respaldo se restauraba pero la fase 3
        # no podía ponerle sus parches (CI-A: mod-playerbots-wintergrasp en la compilación mensual).
        if [ ! -d "$DIR" ] || [ "$MODULE" = core ]; then
            warn "[$MODULE] no está clonado — no se aplican sus $N parches"
            return 1
        fi
        _apply_patches_to_snapshot "$MODULE" "$DIR" "${PATCHES[@]}"
        return $?
    fi

    local CURRENT
    CURRENT="$(_module_tree_diff "$DIR")"
    local START=0   # índice del primer parche que hay que aplicar

    if [ -n "$CURRENT" ]; then
        local WT
        WT="$(mktemp -d)"
        rmdir "$WT"
        if ! git -C "$DIR" worktree add --detach --quiet "$WT" HEAD >/dev/null 2>&1; then
            error "[$MODULE] no se pudo crear un worktree temporal para comprobar los parches."
            return 1
        fi
        local K=0 I
        for I in $(seq 0 $((N - 1))); do
            git -C "$WT" apply --unidiff-zero "${PATCHES[$I]}" >/dev/null 2>&1 || break
            [ "$(_module_tree_diff "$WT")" = "$CURRENT" ] && K=$((I + 1))
        done
        git -C "$DIR" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
        git -C "$DIR" worktree prune >/dev/null 2>&1 || true

        if [ "$K" -eq 0 ]; then
            error "[$MODULE] el código tiene cambios que no corresponden a sus parches"
            error "  (ni al 01 solo, ni a 01+02, ...). No se toca nada. Míralo con:"
            error "    git -C $DIR diff"
            error "  Si sobran, 'git -C $DIR checkout -- .' y repite la fase 3."
            return 1
        fi
        for I in $(seq 0 $((K - 1))); do
            info "[$MODULE] $(basename "${PATCHES[$I]}") ya estaba aplicado."
        done
        START=$K
    fi

    local I
    for I in $(seq "$START" $((N - 1))); do
        P="${PATCHES[$I]}"
        if git -C "$DIR" apply --unidiff-zero --check "$P" >/dev/null 2>&1; then
            git -C "$DIR" apply --unidiff-zero "$P"
            log "[$MODULE] parche aplicado: $(basename "$P")"
        else
            error "[$MODULE] el parche $(basename "$P") NO aplica sobre el código actual."
            error "  Seguramente el upstream ha cambiado esos ficheros. Revísalo en:"
            error "  $P"
            return 1
        fi
    done
    return 0
}

# Aplica TODOS los parches de código conocidos. Idempotente.
# La llaman la fase 3 (tras clonar) y lib/reapply-patches.sh (tras cada
# actualización semanal, que hace reset --hard y por tanto los borra).
apply_all_source_patches() {
    local FAILED=0

    # mod-dungeon-master: parche por sed (bug de columna id1)
    patch_dungeon_master_id1_bug || FAILED=1

    # Resto: ficheros .patch bajo patches/<modulo>/, por módulo y en orden
    local MODULE_PATCH_DIR MODULE PATCH
    local -a PATCHES
    for MODULE_PATCH_DIR in "$PATCHES_DIR"/*/; do
        [ -d "$MODULE_PATCH_DIR" ] || continue
        MODULE="$(basename "$MODULE_PATCH_DIR")"
        if [ "$MODULE" = core ]; then
            [ -d "$AC_DIR/.git" ] || continue
        else
            [ -d "$AC_DIR/modules/$MODULE" ] || continue
        fi
        PATCHES=()
        while IFS= read -r PATCH; do
            [ -n "$PATCH" ] && PATCHES+=("$PATCH")
        done < <(find "$MODULE_PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | sort)
        [ "${#PATCHES[@]}" -gt 0 ] || continue
        apply_module_patches "$MODULE" "${PATCHES[@]}" || FAILED=1
    done

    return $FAILED
}

# =============================================================================
# mod-ah-bot-plus: cuenta y personajes vendedores
#
# El módulo no funciona hasta que existen personajes reales y sus GUID están en
# AuctionHouseBot.GUIDs; el README manda crearlos a mano desde el cliente.
# Aquí se crean por SQL:
#   - una cuenta de servicio con salt/verifier aleatorios, es decir, IMPOSIBLE
#     de usar para iniciar sesión (nadie puede entrar con el vendedor);
#   - un personaje por facción, para que ambas Casas de Subastas tengan oferta.
#
# Los GUID salen de un rango altísimo (AH_BOT_GUID_BASE) para no colisionar
# jamás con personajes reales ni con los de playerbots, que se asignan desde
# MAX(guid)+1 y andan por las centenas.
#
# Deja el resultado en la variable global AH_BOT_GUIDS ("9000001,9000002").
# =============================================================================
setup_ah_bot_characters() {
    AH_BOT_GUIDS=""

    if ! db_exists acore_characters || ! db_exists acore_auth; then
        warn "[mod-ah-bot-plus] Las BBDD aún no existen; los vendedores se crearán"
        warn "  tras el primer arranque (./install.sh --post)."
        return 1
    fi

    # --- cuenta de servicio (no logueable) ---
    mysql_q "INSERT IGNORE INTO acore_auth.account (username, salt, verifier, expansion)
             VALUES ('${AH_BOT_ACCOUNT}', RANDOM_BYTES(32), RANDOM_BYTES(32), 2);"

    local ACC_ID
    ACC_ID=$(mysql_q "SELECT id FROM acore_auth.account WHERE username='${AH_BOT_ACCOUNT}';")
    if [ -z "$ACC_ID" ]; then
        error "[mod-ah-bot-plus] No se pudo crear la cuenta '${AH_BOT_ACCOUNT}'."
        return 1
    fi
    info "[mod-ah-bot-plus] Cuenta de servicio '${AH_BOT_ACCOUNT}' (id ${ACC_ID}), sin acceso de login."

    # --- personajes vendedores: "nombre:raza:genero" (clase 1 = guerrero) ---
    local SELLERS=(
        "${AH_BOT_CHAR_ALLIANCE}:1:0"   # Humano
        "${AH_BOT_CHAR_HORDE}:2:0"      # Orco
    )

    local IDX=0 ENTRY NAME RACE GENDER GUID EXISTING GUIDS=()
    for ENTRY in "${SELLERS[@]}"; do
        NAME="${ENTRY%%:*}"
        RACE="$(echo "$ENTRY" | cut -d: -f2)"
        GENDER="$(echo "$ENTRY" | cut -d: -f3)"
        GUID=$(( AH_BOT_GUID_BASE + IDX ))
        IDX=$(( IDX + 1 ))

        # ¿Existe ya un personaje con ese nombre? (characters no tiene índice
        # único en `name`, así que hay que mirarlo a mano para no duplicar)
        EXISTING=$(mysql_q "SELECT guid FROM acore_characters.characters WHERE name='${NAME}' LIMIT 1;")
        if [ -n "$EXISTING" ]; then
            info "[mod-ah-bot-plus] Vendedor '${NAME}' ya existe (guid ${EXISTING})."
            GUIDS+=("$EXISTING")
            continue
        fi

        mysql_q "INSERT IGNORE INTO acore_characters.characters
                 (guid, account, name, race, class, gender, level, taximask, innTriggerId)
                 VALUES (${GUID}, ${ACC_ID}, '${NAME}', ${RACE}, 1, ${GENDER}, 1, '', 0);"

        EXISTING=$(mysql_q "SELECT guid FROM acore_characters.characters WHERE guid=${GUID};")
        if [ -n "$EXISTING" ]; then
            log "[mod-ah-bot-plus] Vendedor '${NAME}' creado (guid ${GUID})."
            GUIDS+=("$GUID")
        else
            warn "[mod-ah-bot-plus] No se pudo crear el vendedor '${NAME}'."
        fi
    done

    if [ "${#GUIDS[@]}" -eq 0 ]; then
        error "[mod-ah-bot-plus] No hay ningún vendedor disponible."
        return 1
    fi

    AH_BOT_GUIDS="$(IFS=,; echo "${GUIDS[*]}")"
    return 0
}

# =============================================================================
# mod-individual-progression: SQL opcional
#
# El módulo trae en optional/sql/world/ una colección de cambios de contenido
# que NO se aplican solos. La lista de los que queremos está en IP_OPTIONAL_SQL
# (config.sh), sin el prefijo "zz_optional_" ni la extensión.
#
# El más importante es small_group_adjustments: está escrito para exactamente
# este servidor (raids de 40 completadas por un grupo pequeño con autobalance
# y bots). Sin él, Núcleo de Magma se atasca en las runas y en el combate de
# Garr por falta de cuerpos, no por falta de daño.
# =============================================================================
apply_ip_optional_sql() {
    local DIR="$AC_DIR/modules/mod-individual-progression/optional/sql/world"
    local NAME FILE OK=0 TOTAL=0
    local FAILED=()

    # El guard con +x evita que `set -u` aborte si config.sh es antiguo y no
    # define la lista todavia.
    if [ -z "${IP_OPTIONAL_SQL+x}" ] || [ "${#IP_OPTIONAL_SQL[@]}" -eq 0 ]; then
        info "[mod-individual-progression] IP_OPTIONAL_SQL vacío: no se aplica SQL opcional."
        return 0
    fi
    if [ ! -d "$DIR" ]; then
        warn "[mod-individual-progression] No existe $DIR — ¿se clonó el módulo?"
        return 1
    fi
    if ! db_exists acore_world; then
        warn "[mod-individual-progression] acore_world no existe todavía; el SQL"
        warn "  opcional se aplicará con './install.sh --only 5' o '--post'."
        return 1
    fi

    for NAME in "${IP_OPTIONAL_SQL[@]}"; do
        TOTAL=$((TOTAL + 1))
        FILE="$DIR/zz_optional_${NAME}.sql"
        if [ ! -f "$FILE" ]; then
            warn "[mod-individual-progression] SQL opcional no encontrado: $(basename "$FILE")"
            continue
        fi
        if mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" acore_world < "$FILE" >> "$INSTALL_LOG" 2>&1; then
            log "[mod-individual-progression] opcional aplicado: $NAME"
            OK=$((OK + 1))
        else
            FAILED+=("$NAME")
        fi
    done

    if [ "${#FAILED[@]}" -gt 0 ]; then
        error "[mod-individual-progression] ${#FAILED[@]}/$TOTAL SQL opcionales fallaron: ${FAILED[*]} (ver $INSTALL_LOG)."
        return "${#FAILED[@]}"
    fi

    info "[mod-individual-progression] $OK/$TOTAL SQL opcionales aplicados."
    return 0
}

# =============================================================================
# mod-individual-progression: DBC opcionales del SERVIDOR
#
# Restauran hechizos, recetas y reactivos de Vanilla/TBC. Van en dos archivos
# comprimidos dentro del módulo:
#   optional/dbc.7z     -> SkillLine, SkillLineAbility, SkillRaceClassInfo,
#                          SpellItemEnchantment  (+ parches de cliente)
#   optional/patch-V.7z -> Spell.dbc con los costes de maná de la época
#
# ⚠️  SkillRaceClassInfo.dbc se EXCLUYE cuando mod-arac está activo: ARAC trae
#     su propia versión de ese mismo fichero y es la que permite razas y clases
#     cruzadas. Si la pisáramos, ARAC dejaría de funcionar sin dar ningún error.
# =============================================================================
copy_ip_optional_dbc() {
    local DST="$AC_DIR/env/dist/bin/dbc"
    local SRC="$AC_DIR/modules/mod-individual-progression/optional"
    local TMP FILE BASENAME COPIED=0

    if [ ! -d "$DST" ]; then
        warn "[mod-individual-progression] No existe $DST (faltan los datos del cliente del final de la fase 5)."
        return 1
    fi
    if [ ! -f "$SRC/dbc.7z" ]; then
        warn "[mod-individual-progression] No se encuentra $SRC/dbc.7z"
        return 1
    fi
    if ! command -v 7z &>/dev/null; then
        run "Instalar p7zip" sudo apt-get install -y p7zip-full || return 1
    fi

    TMP="$(mktemp -d)"
    7z x -y -o"$TMP" "$SRC/dbc.7z" >> "$INSTALL_LOG" 2>&1 || {
        warn "[mod-individual-progression] No se pudo extraer dbc.7z"
        rm -rf "$TMP"; return 1
    }
    if [ -f "$SRC/patch-V.7z" ]; then
        7z x -y -o"$TMP" "$SRC/patch-V.7z" >> "$INSTALL_LOG" 2>&1 || \
            warn "[mod-individual-progression] No se pudo extraer patch-V.7z (Spell.dbc)"
    fi

    mkdir -p "$DST/backup-pre-ip"
    while IFS= read -r FILE; do
        BASENAME="$(basename "$FILE")"

        if [ "$BASENAME" = "SkillRaceClassInfo.dbc" ] && [ "${INSTALL_MOD_ARAC:-false}" = true ]; then
            warn "[mod-individual-progression] SkillRaceClassInfo.dbc OMITIDO: manda mod-arac."
            continue
        fi

        # Copia de seguridad del original, sólo la primera vez
        if [ -f "$DST/$BASENAME" ] && [ ! -f "$DST/backup-pre-ip/$BASENAME" ]; then
            cp "$DST/$BASENAME" "$DST/backup-pre-ip/$BASENAME"
        fi
        cmp -s "$FILE" "$DST/$BASENAME" && { COPIED=$((COPIED + 1)); continue; }
        if cp "$FILE" "$DST/$BASENAME" 2>>"$INSTALL_LOG"; then
            COPIED=$((COPIED + 1))
            SERVER_DBC_CHANGED=$((SERVER_DBC_CHANGED + 1))
        else
            warn "[mod-individual-progression] Error copiando $BASENAME"
            rm -rf "$TMP"; return 1
        fi
    done < <(find "$TMP" -maxdepth 2 -type f -name '*.dbc' | sort)

    rm -rf "$TMP"
    log "[mod-individual-progression] $COPIED DBC en $DST (originales en backup-pre-ip/)."
    info "  Paso de cliente OPCIONAL: copia $SRC/patch-V.7z → patch-V.mpq a WoW/Data/"
    return 0
}

# =============================================================================
# mod-arac: los tres DBC del SERVIDOR que habilitan cualquier raza/clase
# (CharBaseInfo, CharStartOutfit, SkillRaceClassInfo), tal cual vienen en
# extras/mod-arac/patch-contents/DBFilesContent/. El cliente lleva los mismos
# fundidos en patch-<idioma>-4.MPQ.
# =============================================================================
copy_arac_server_dbc() {
    local SRC="$AC_DIR/extras/mod-arac/patch-contents/DBFilesContent"
    local DST="$AC_DIR/env/dist/bin/dbc"
    local DBC BASENAME COPIED=0

    if [ ! -d "$SRC" ]; then
        warn "[mod-arac] No se encontró $SRC — revisa que mod-arac se haya clonado bien en extras/."
        return 1
    fi
    if [ ! -d "$DST" ]; then
        warn "[mod-arac] No existe $DST (faltan los datos del cliente del final de la fase 5)."
        return 1
    fi

    mkdir -p "$DST/backup-pre-arac"
    for DBC in "$SRC"/*.dbc; do
        BASENAME="$(basename "$DBC")"
        # Copia de seguridad del original, sólo la primera vez
        if [ -f "$DST/$BASENAME" ] && [ ! -f "$DST/backup-pre-arac/$BASENAME" ]; then
            cp "$DST/$BASENAME" "$DST/backup-pre-arac/$BASENAME"
        fi
        cmp -s "$DBC" "$DST/$BASENAME" && { COPIED=$((COPIED + 1)); continue; }
        if cp "$DBC" "$DST/$BASENAME" 2>>"$INSTALL_LOG" && cmp -s "$DBC" "$DST/$BASENAME"; then
            COPIED=$((COPIED + 1))
            SERVER_DBC_CHANGED=$((SERVER_DBC_CHANGED + 1))
        else
            warn "[mod-arac] Error copiando $BASENAME a $DST — revisa $INSTALL_LOG."
            return 1
        fi
    done
    log "[mod-arac] $COPIED DBC del servidor iguales a los de mod-arac (originales en backup-pre-arac/)."
    return 0
}

# =============================================================================
# DBC del servidor que sustituyen los módulos: IP (opcionales) y ARAC.
#
# Se llaman DESPUÉS de instalar los datos del cliente (Data.zip, al final de la
# fase 5): antes de eso env/dist/bin/dbc no existe. Hasta el 24/09/2026 iban en
# mitad de la fase 5 y en una instalación limpia no llegaban a copiarse nunca
# (PLAN AR01). Orden: IP primero y ARAC después, para que SkillRaceClassInfo.dbc
# sea siempre el de ARAC. Idempotentes; SERVER_DBC_CHANGED cuenta los ficheros
# que han cambiado (el worldserver sólo lee los DBC al arrancar).
# =============================================================================
SERVER_DBC_CHANGED=0

# El hechizo 600001 de la Piedra de la sede (mod-guildhouse) vive en el Spell.dbc EFECTIVO del
# servidor. Los DBC opcionales de IP traen su propio Spell.dbc y lo sustituyen, así que la piedra
# se añade siempre DESPUÉS de ellos y cada vez que se aplican (hasta el 07/10/2026 la fase 8 la
# añadía antes de volver a copiar el de IP y una instalación limpia arrancaba sin el hechizo:
# «spell_guildhouse_stone ... does not exist in Spell.dbc» y la piedra no hacía nada).
add_guildhouse_stone_dbc() {
    local SPELL="$AC_DIR/env/dist/bin/dbc/Spell.dbc"
    if [ ! -f "$SPELL" ]; then
        warn "[mod-guildhouse] falta $SPELL: no se puede instalar la piedra de la sede."
        return 1
    fi
    if python3 "$INSTALLER_DIR/tools/piedra_sede_dbc.py" --comprobar "$SPELL" 2>>"$INSTALL_LOG"; then
        return 0
    fi
    if python3 "$INSTALLER_DIR/tools/piedra_sede_dbc.py" "$SPELL" "$SPELL" >>"$INSTALL_LOG" 2>&1; then
        log "[mod-guildhouse] hechizo 600001 de la piedra añadido al Spell.dbc efectivo."
    else
        warn "[mod-guildhouse] no se pudo añadir la piedra al Spell.dbc (ver $INSTALL_LOG)."
        return 1
    fi
}

# Suma de comprobación de los DBC del servidor, para contar sólo lo que de verdad cambia tras la pasada.
_server_dbc_sums() {
    ( cd "$AC_DIR/env/dist/bin/dbc" 2>/dev/null && md5sum -- *.dbc 2>/dev/null ) || true
}

apply_server_dbc_overrides() {
    local FAILED=0 BEFORE AFTER
    SERVER_DBC_CHANGED=0
    BEFORE="$(_server_dbc_sums)"
    if [ "${INSTALL_MOD_INDIVIDUAL_PROGRESSION:-false}" = true ] && [ "${IP_OPTIONAL_DBC:-false}" = true ]; then
        copy_ip_optional_dbc || FAILED=1
    fi
    if [ "${INSTALL_MOD_ARAC:-false}" = true ]; then
        copy_arac_server_dbc || FAILED=1
    fi
    if [ "${INSTALL_MOD_GUILDHOUSE:-false}" = true ]; then
        add_guildhouse_stone_dbc || FAILED=1
    fi
    # Lo que importa al reiniciar es el resultado final, no cuántas veces se copió y se volvió a parchear.
    AFTER="$(_server_dbc_sums)"
    SERVER_DBC_CHANGED=$(diff <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") | grep -c '^>' || true)
    return $FAILED
}

# =============================================================================
# NPC de servicio: colocación automática
#
# Los módulos traen la PLANTILLA del NPC (creature_template) pero no lo colocan
# en ningún sitio: sus READMEs mandan hacerlo a mano desde el juego con
# ".npc add <entrada>". Aquí se colocan solos en Ventormenta y Orgrimmar.
#
# Las coordenadas NO son fijas: se copian de un NPC que ya existe en cada ciudad
# (el posadero) con un pequeño desplazamiento. Así el NPC queda siempre a ras de
# suelo, en el sitio correcto del mapa y sin depender de coordenadas a mano que
# pueden acabar dentro de una pared.
#
# Idempotente: borra las apariciones anteriores de esas entradas antes de crear
# las nuevas, así que relanzar la fase 5 no duplica NPCs.
# =============================================================================
spawn_service_npcs() {
    db_exists acore_world || { warn "[NPC] acore_world no existe todavía."; return 1; }

    # entrada:etiqueta — sólo se colocan los módulos activos
    local WANTED=()
    # entrada:etiqueta:lado:distancia
    # Se reparten a AMBOS lados del ancla y a poca distancia. Ponerlos los cuatro
    # en fila al mismo lado hacia que los mas alejados (6-8 yardas) acabaran
    # dentro de una pared o detras de cajas en la mitad de las capitales.
    # Transmog y banco de materiales van a la izquierda; el cambio de racial y el
    # battlemaster a la derecha, que es donde habia sitio en Cima del Trueno,
    # Entranas, Lunargenta y Shattrath.
    [ "${INSTALL_MOD_TRANSMOG:-false}" = true ]          && WANTED+=("190010:Transmogrificador:izq:2.5")
    [ "${INSTALL_MOD_REAGENT_BANK:-false}" = true ]      && WANTED+=("290011:Banco de materiales:izq:5")
    [ "${INSTALL_MOD_RACIAL_TRAIT_SWAP:-false}" = true ] && WANTED+=("98888:Cambio de rasgo racial:der:2.5")
    [ "${INSTALL_MOD_1V1_ARENA:-false}" = true ]         && WANTED+=("999991:Battlemaster 1c1:der:5")
    [ "${INSTALL_MOD_GUILDHOUSE:-false}" = true ]        && WANTED+=("500030:Vendedor de sedes:der:7.5")

    if [ "${#WANTED[@]}" -eq 0 ]; then
        info "[NPC] Ningún módulo con NPC propio activo."
        return 0
    fi

    # ── Elección del ancla ───────────────────────────────────────────────────
    # Preferida: el NPC del Dungeon Master, que el módulo coloca en las ONCE
    # capitales. Así los servicios quedan juntos y disponibles en todas ellas.
    # Si ese módulo no está, se recurre a los posaderos de Ventormenta y
    # Orgrimmar, que existen siempre.
    local ANCHOR_WHERE ANCHOR_DESC N_ANCHORS
    N_ANCHORS=$(mysql_q "SELECT COUNT(*) FROM acore_world.creature WHERE id=500000;")
    if [ "${N_ANCHORS:-0}" -gt 0 ]; then
        ANCHOR_WHERE="a.id = 500000"
        ANCHOR_DESC="junto al Dungeon Master (${N_ANCHORS} capitales)"
    else
        ANCHOR_WHERE="t.name IN ('Innkeeper Allison','Innkeeper Gryshka')"
        ANCHOR_DESC="junto al posadero de Ventormenta y Orgrimmar"
        N_ANCHORS=2
    fi

    # ── Anclas de espaldas ───────────────────────────────────────────────────
    # En Bahía del Botín y Lunargenta el NPC del Dungeon Master viene del módulo
    # mirando a la pared, así que toda la fila salía de espaldas. Se giran 180
    # grados ANTES de colocar a los demás, que copian su orientación.
    # Forjaz y Orgrimmar estaban aquí y ya no: verificado en el juego, ahí la
    # orientación que trae el módulo (2,26 y 5,70) es la correcta.
    # Se identifican por posición y no por guid: si el módulo cambia sus spawns,
    # esto deja de aplicarse solo en vez de rotar al NPC equivocado.
    # La orientación se fija en ABSOLUTO, no sumando 180 grados: sumar no es
    # idempotente y dos pasadas dejarían al NPC como estaba. Los valores son los
    # que trae el módulo más PI (4,00 -> 0,8584 y 0,50 -> 3,6416).
    #   mapa : x : y : orientación_corregida
    local ROTATE=(
        "0:-14406:420:0.8584"      # Bahía del Botín
        "530:9738:-7454:3.6416"    # Lunargenta
    )

    # ── Anclas mal colocadas por el módulo ───────────────────────────────────
    # En el Exodar el NPC del Dungeon Master está en el aire: el suelo real
    # queda 165 yardas más abajo y al teletransportarse allí se cae al vacío.
    # Se le reubica sobre el punto de teleport oficial de la ciudad, que sí es
    # suelo válido, y los servicios van con él.
    # En Shattrath ocurre lo mismo por otro motivo: el ancla del módulo queda
    # sobre un hueco de la Terraza de la Luz y al llegar se cae al vacío. Se le
    # mueve 15 yardas a SU IZQUIERDA —el vector (-sin o, cos o) con o = 5,50, o
    # sea (+0,7055, +0,7087)— manteniendo la altura, que ahí el suelo es plano, y
    # se le gira 90 grados a la izquierda (5,50 + π/2 = 0,7876) para que deje de
    # mirar al hueco. Los cuatro servicios se reparten a su alrededor como en el
    # resto de capitales.
    #   mapa : x_actual : y_actual : x_nueva : y_nueva : z_nueva : orientación
    local RELOCATE=(
        "530:-3862.7:-11645.8:-3965.7:-11653.6:-138.84:0.85"   # Exodar
        "530:-1850:5436:-1839.42:5446.63:-12.10:0.7876"        # Shattrath
    )
    local L LMAP LX LY LNX LNY LNZ LO
    for L in "${RELOCATE[@]}"; do
        IFS=':' read -r LMAP LX LY LNX LNY LNZ LO <<< "$L"
        mysql_q "UPDATE acore_world.creature
                    SET position_x = ${LNX}, position_y = ${LNY},
                        position_z = ${LNZ}, orientation = ${LO}
                  WHERE id = 500000 AND map = ${LMAP}
                    AND ABS(position_x - (${LX})) < 15 AND ABS(position_y - (${LY})) < 15;"
    done

    # ── Capitales sin sitio a un lado ────────────────────────────────────────
    # En Dalaran el lado izquierdo del ancla da contra una pared y unas cajas,
    # así que allí los cuatro van al lado derecho, que está despejado.
    # Darnassus estaba en esta lista y ya no: allí hay sitio a ambos lados y
    # quedan mejor repartidos alrededor del ancla, como en el resto.
    #   mapa : x : y
    local ALL_RIGHT=(
        "571:5807:506.2"   # Dalaran
    )
    local R RMAP RX RY RO
    for R in "${ROTATE[@]}"; do
        IFS=':' read -r RMAP RX RY RO <<< "$R"
        mysql_q "UPDATE acore_world.creature
                    SET orientation = ${RO}
                  WHERE id = 500000 AND map = ${RMAP}
                    AND ABS(position_x - (${RX})) < 5 AND ABS(position_y - (${RY})) < 5;"
    done

    local BASE_GUID
    BASE_GUID=$(mysql_q "SELECT IFNULL(MAX(guid),0)+1000 FROM acore_world.creature;")
    if [ -z "$BASE_GUID" ]; then
        warn "[NPC] No se pudo consultar la tabla creature."
        return 1
    fi

    local SQL="" ENTRY_DEF ENTRY LABEL MOD_IDX=0 DIST EXISTS PLACED=0 BLOCK
    # Lista de entradas propias: se excluyen al buscar la Z del suelo, para no
    # copiarse la altura unos a otros y arrastrar el error.
    local ALL_ENTRIES
    ALL_ENTRIES=$(printf '%s,' "${WANTED[@]%%:*}"); ALL_ENTRIES="${ALL_ENTRIES%,}"
    for ENTRY_DEF in "${WANTED[@]}"; do
        IFS=':' read -r ENTRY LABEL SIDE DIST <<< "$ENTRY_DEF"

        EXISTS=$(mysql_q "SELECT COUNT(*) FROM acore_world.creature_template WHERE entry=${ENTRY};")
        if [ "${EXISTS:-0}" -eq 0 ]; then
            warn "[NPC] '$LABEL' (entrada $ENTRY) no está en creature_template todavía: se omite."
            warn "  Su módulo aún no ha aplicado su SQL. Vuelve a lanzar './install.sh --only 5'."
            continue
        fi

        # Desplazamiento perpendicular a la orientación del ancla: el vector a su
        # izquierda es (-sin o, cos o); a la derecha, el mismo con signo opuesto.
        [ "$SIDE" = "der" ] && DIST="-${DIST}"

        # En las capitales de ALL_RIGHT no hay hueco a la izquierda, así que allí
        # los cuatro van escalonados a la derecha. La distancia deja de ser un
        # número y pasa a ser un CASE, porque depende del ancla concreta.
        local OFFSET="${DIST}" COND="" A AMAP AX AY
        if [ "${#ALL_RIGHT[@]}" -gt 0 ]; then
            for A in "${ALL_RIGHT[@]}"; do
                IFS=':' read -r AMAP AX AY <<< "$A"
                [ -n "$COND" ] && COND="${COND} OR "
                COND="${COND}(a.map = ${AMAP} AND ABS(a.position_x - (${AX})) < 15 AND ABS(a.position_y - (${AY})) < 15)"
            done
            OFFSET="CASE WHEN ${COND} THEN $(awk "BEGIN{printf \"%.1f\", -2.5 * (${MOD_IDX} + 1)}") ELSE ${DIST} END"
        fi

        # Cada ancla necesita un guid distinto: ROW_NUMBER() los reparte.
        BLOCK="DELETE FROM \`creature\` WHERE \`id\` = ${ENTRY};
INSERT INTO \`creature\`
  (\`guid\`, \`id\`, \`map\`, \`spawnMask\`, \`phaseMask\`,
   \`position_x\`, \`position_y\`, \`position_z\`, \`orientation\`, \`spawntimesecs\`)
SELECT $(( BASE_GUID + MOD_IDX * 100 )) + ROW_NUMBER() OVER (ORDER BY a.guid),
       ${ENTRY}, a.map, 1, 1,
       a.position_x - ((${OFFSET}) * SIN(a.orientation)),
       a.position_y + ((${OFFSET}) * COS(a.orientation)),
       a.position_z, a.orientation, 300
  FROM \`creature\` a
  JOIN \`creature_template\` t ON t.entry = a.id
 WHERE ${ANCHOR_WHERE};
"
        SQL="${SQL}${BLOCK}"
        MOD_IDX=$(( MOD_IDX + 1 ))
        PLACED=$(( PLACED + 1 ))
    done

    [ -n "$SQL" ] || return 0

    # ── Vendedor de sedes junto al Maestro de hermandad ──────────────────────
    # El vendedor (500030) tiene más sentido donde se funda la hermandad que junto
    # al Dungeon Master: se coloca 2,5 yardas a la derecha del Maestro de hermandad
    # más cercano de su capital (hasta 400 yardas), mirando como él. En las capitales
    # sin Maestro de hermandad (Bahía del Botín, Shattrath) se queda junto al ancla.
    # Va ANTES del ajuste de altura, que copia la Z del vecino más cercano.
    if [ "${INSTALL_MOD_GUILDHOUSE:-false}" = true ]; then
        SQL="${SQL}
UPDATE \`creature\` v
  JOIN (SELECT v2.guid AS vg,
               (SELECT c.guid FROM \`creature\` c
                  JOIN \`creature_template\` t ON t.entry = c.id
                 WHERE t.subname = 'Guild Master' AND c.map = v2.map AND c.phaseMask = 1
                   AND POW(c.position_x - v2.position_x, 2) + POW(c.position_y - v2.position_y, 2) < 160000
                 ORDER BY POW(c.position_x - v2.position_x, 2) + POW(c.position_y - v2.position_y, 2)
                 LIMIT 1) AS gm
          FROM \`creature\` v2 WHERE v2.id = 500030) m ON m.vg = v.guid
  JOIN \`creature\` g ON g.guid = m.gm
   SET v.position_x = g.position_x + 2.5 * SIN(g.orientation),
       v.position_y = g.position_y - 2.5 * COS(g.orientation),
       v.position_z = g.position_z, v.orientation = g.orientation;
"
    fi

    # ── Ajuste de altura ────────────────────────────────────────────────────
    # Desplazarlos en X/Y manteniendo la Z del ancla los entierra en cuanto el
    # suelo tiene pendiente: en Ventormenta el terreno sube más de un metro en
    # 10 yardas, y el NPC más alejado quedaba bajo tierra e invisible.
    # SQL no sabe consultar la altura del terreno, pero los NPC que ya existen
    # SÍ están sobre suelo válido: se copia la Z del más cercano a cada uno, más
    # 20 cm — el vecino más cercano rara vez está exactamente a la misma altura y
    # quedarse corto hunde los pies, mientras que pasarse un poco no se nota.
    SQL="${SQL}
CREATE TEMPORARY TABLE tmp_npc_z AS
SELECT c.guid AS guid,
       (SELECT c2.position_z FROM \`creature\` c2
         WHERE c2.map = c.map
           AND c2.id NOT IN (${ALL_ENTRIES})
           AND ABS(c2.position_x - c.position_x) < 25
           AND ABS(c2.position_y - c.position_y) < 25
         ORDER BY POW(c2.position_x - c.position_x, 2) + POW(c2.position_y - c.position_y, 2)
         LIMIT 1) AS z
  FROM \`creature\` c
 WHERE c.id IN (${ALL_ENTRIES});
UPDATE \`creature\` c JOIN tmp_npc_z t ON t.guid = c.guid
   SET c.position_z = t.z + 0.2 WHERE t.z IS NOT NULL;
DROP TEMPORARY TABLE tmp_npc_z;
"

    if printf '%s' "$SQL" | mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" acore_world >> "$INSTALL_LOG" 2>&1; then
        log "[NPC] $PLACED NPC de servicio colocados ${ANCHOR_DESC}, a ras de suelo."
        info "  Aparecen en el mundo al arrancar (o reiniciar) el worldserver."
    else
        warn "[NPC] Falló la colocación automática — revisa $INSTALL_LOG"
        return 1
    fi
    return 0
}


# =============================================================================
# Cuenta de administrador
#
# AzerothCore no guarda contraseñas: guarda un verificador SRP6. Por eso la
# cuenta no se puede crear con un simple INSERT de la contraseña en claro, y
# hasta ahora la fase 8 se limitaba a IMPRIMIR los comandos para que los
# escribieras a mano en la consola del worldserver.
#
# lib/srp6.py calcula el par (salt, verifier) exactamente igual que el core
# (ver la cabecera del script), así que la cuenta se puede crear por SQL sin
# necesidad de que el servidor esté arrancado.
#
# Idempotente y conservador: si la cuenta ya existe NO se le toca la contraseña
# (podrías haberla cambiado a propósito), sólo se garantiza el nivel de GM.
# =============================================================================
create_admin_account() {
    [ "${CREATE_ADMIN_ACCOUNT:-false}" = true ] || return 0

    local NAME="${ADMIN_ACCOUNT_NAME:-admin}"
    local PASS="${ADMIN_ACCOUNT_PASS:-admin}"
    local GMLEVEL="${ADMIN_ACCOUNT_GMLEVEL:-3}"
    local UPPER_NAME
    UPPER_NAME="$(printf '%s' "$NAME" | tr '[:lower:]' '[:upper:]')"

    if ! db_exists acore_auth; then
        warn "[cuenta] acore_auth no existe todavía: la cuenta '$NAME' se creará"
        warn "  tras el primer arranque, con './install.sh --post'."
        return 1
    fi

    local EXISTING
    EXISTING=$(mysql_q "SELECT id FROM acore_auth.account WHERE username='${UPPER_NAME}';")

    if [ -z "$EXISTING" ]; then
        # Se prueba cada candidato EJECUTANDOLO: que exista en el PATH no basta
        # (hay entornos donde python3 es un lanzador que falla al invocarlo).
        local PY="" CANDIDATE SRP SALT VERIFIER
        for CANDIDATE in python3 python; do
            command -v "$CANDIDATE" >/dev/null 2>&1 || continue
            if "$CANDIDATE" -c 'import hashlib' >/dev/null 2>&1; then
                PY="$CANDIDATE"
                break
            fi
        done
        if [ -z "$PY" ]; then
            error "[cuenta] No hay python3 en el sistema y hace falta para calcular el"
            error "  verificador SRP6. Instálalo (sudo apt-get install -y python3) y"
            error "  vuelve a ejecutar './install.sh --post', o crea la cuenta a mano"
            error "  en la consola del worldserver:  account create ${NAME} ${PASS}"
            return 1
        fi

        SRP=$("$PY" "$INSTALLER_DIR/lib/srp6.py" "$NAME" "$PASS" 2>>"$INSTALL_LOG") || {
            error "[cuenta] srp6.py falló — revisa $INSTALL_LOG"
            return 1
        }
        SALT="${SRP%% *}"
        VERIFIER="${SRP##* }"

        if [ -z "$SALT" ] || [ -z "$VERIFIER" ] || [ "${#SALT}" -ne 64 ] || [ "${#VERIFIER}" -ne 64 ]; then
            error "[cuenta] srp6.py devolvió algo que no son dos valores de 32 bytes."
            return 1
        fi

        mysql_q "INSERT INTO acore_auth.account (username, salt, verifier, expansion)
                 VALUES ('${UPPER_NAME}', UNHEX('${SALT}'), UNHEX('${VERIFIER}'), 2);"

        EXISTING=$(mysql_q "SELECT id FROM acore_auth.account WHERE username='${UPPER_NAME}';")
        if [ -z "$EXISTING" ]; then
            error "[cuenta] No se pudo crear la cuenta '${NAME}'."
            return 1
        fi
        log "[cuenta] Cuenta '${NAME}' creada (contraseña: ${PASS}), sin personajes."
    else
        info "[cuenta] La cuenta '${NAME}' ya existe (id ${EXISTING}); no se toca su contraseña."
    fi

    # Nivel de GM en todos los reinos (-1). REPLACE para que reejecutar la fase
    # no falle por la clave primaria (id, RealmID).
    mysql_q "REPLACE INTO acore_auth.account_access (id, gmlevel, RealmID, comment)
             VALUES (${EXISTING}, ${GMLEVEL}, -1, 'creada por el instalador');"

    # Fila de contador de personajes por reino, igual que hace el core al crear
    # una cuenta desde la consola.
    mysql_q "INSERT IGNORE INTO acore_auth.realmcharacters (realmid, acctid, numchars)
             SELECT realmlist.id, ${EXISTING}, 0 FROM acore_auth.realmlist;"

    log "[cuenta] '${NAME}' tiene nivel de GM ${GMLEVEL} en todos los reinos."
    return 0
}

# =============================================================================
# install_client_data — descarga, verifica y extrae los datos del cliente
# (maps, vmaps, mmaps, dbc, cameras) en <bin_dir>.
#
#   install_client_data <url> <sha256> <bin_dir>
#
# Reglas: nunca se extrae un fichero cuyo SHA-256 no cuadra (se borra); una
# descarga cortada se reanuda (data.zip.part + `wget -c`); un data.zip entero y
# verificado de una ejecución anterior se reutiliza; una extracción interrumpida
# deja .data-extracting y la fase la repite entera. Devuelve 1 ante cualquier fallo.
# =============================================================================
install_client_data() {
    local url="$1" sha="$2" bin="$3" got
    local mark="$bin/.data-extracting"
    cd "$bin" || return 1

    # Instalar p7zip si no está disponible (necesario para extraer este formato)
    if ! command -v 7z &>/dev/null; then
        run "Instalar p7zip" sudo apt-get install -y p7zip-full
    fi

    if [ -f data.zip ] && [ "$(sha256sum data.zip | cut -d' ' -f1)" = "$sha" ]; then
        log "data.zip ya descargado y verificado."
    else
        rm -f data.zip
        info "Descargando los datos del cliente desde: $url"
        # Fuera de run(): run() redirige stdout/stderr al log, asi que el
        # progreso no se veria y una descarga de varios GB parecia colgada.
        info "Descargando Data.zip (más de 1 GB, puede tardar; si se corta, se reanuda)..."
        if ! wget -c --progress=bar:force:noscroll -O data.zip.part "$url"; then
            error "Fallo la descarga de los datos del cliente desde: $url"
            error "Se conserva data.zip.part: al repetir la fase se reanuda."
            return 1
        fi
        got=$(sha256sum data.zip.part | cut -d' ' -f1)
        if [ "$got" != "$sha" ]; then
            error "El SHA-256 de los datos del cliente no coincide."
            error "  esperado: $sha"
            error "  obtenido: $got"
            error "Se borra la descarga; no se extrae nada."
            rm -f data.zip.part
            return 1
        fi
        mv -f data.zip.part data.zip
        log "Descarga completada y verificada (SHA-256)."
    fi

    # Verificar que la descarga es un ZIP válido antes de extraer
    if ! 7z t data.zip &>/dev/null; then
        error "El archivo descargado no es un ZIP válido."
        error "Se borra; al repetir la fase se descarga de nuevo."
        rm -f data.zip
        return 1
    fi
    : > "$mark"
    run "Extraer datos del cliente" 7z x data.zip -o"$bin" -y
    rm -f "$mark" data.zip
    # El ZIP no trae fichero de versión: se deja constancia de qué se instaló.
    printf '%s sha256:%s
' "$url" "$sha" > "$bin/data-version"
    log "Datos del cliente instalados en $bin"
}
