#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#
#   █████╗ ███████╗███████╗██████╗  ██████╗ ████████╗██╗  ██╗
#  ██╔══██╗╚══███╔╝██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝██║  ██║
#  ███████║  ███╔╝ █████╗  ██████╔╝██║   ██║   ██║   ███████║
#  ██╔══██║ ███╔╝  ██╔══╝  ██╔══██╗██║   ██║   ██║   ██╔══██║
#  ██║  ██║███████╗███████╗██║  ██║╚██████╔╝   ██║   ██║  ██║
#  ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝
#        ██████╗ ██████╗ ██████╗ ███████╗
#       ██╔════╝██╔═══██╗██╔══██╗██╔════╝
#       ██║     ██║   ██║██████╔╝█████╗
#       ██║     ██║   ██║██╔══██╗██╔══╝
#       ╚██████╗╚██████╔╝██║  ██║███████╗
#        ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
#
#  AzerothCore WotLK 3.3.5a — Instalador automático
#  Ubuntu 24.04 LTS · Proxmox · Ryzen 7 7730U
#
#  ANTES DE EMPEZAR: edita config.sh con tu configuración
#
#  Uso:
#    ./install.sh --guiado     → Primera vez, sin editar nada (recomendado)
#    ./install.sh --reanudar   → Retomar una instalación completa interrumpida
#    ./install.sh              → Instalación completa (fases 1-7) con config.sh actual
#    ./install.sh --only 5     → Solo la fase 5 (configurar servidor)
#    ./install.sh --from 5     → Desde la fase 5 hasta el final
#    ./install.sh --fix        → Reparar configuración existente (fases 2+5)
#    ./install.sh --post       → Pasos post-primer-arranque (fases 8-9)
#    ./install.sh --panel      → Instalar o actualizar sólo el panel web
#    ./install.sh --webclient  → Instalar o actualizar el cliente web del navegador (opcional)
#    ./install.sh --help       → Ver esta ayuda
#
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/versions.sh"
source "$SCRIPT_DIR/lib/mirrors.sh"
source "$SCRIPT_DIR/lib/doctor.sh"
source "$SCRIPT_DIR/lib/install-state.sh"

# =============================================================================
# Mapa de fases
# =============================================================================
declare -A PHASES=(
    [1]="scripts/phases/01_dependencies.sh"
    [2]="scripts/phases/02_mysql_setup.sh"
    [3]="scripts/phases/03_clone_core.sh"
    [4]="scripts/phases/04_compile.sh"
    [5]="scripts/phases/05_configure_server.sh"
    [6]="scripts/phases/06_systemd.sh"
    [7]="scripts/phases/07_automation.sh"
    [8]="scripts/phases/08_post_install.sh"
    [9]="scripts/phases/09_web_panel.sh"
    [10]="scripts/phases/10_web_client.sh"
)
declare -A PHASE_NAMES=(
    [1]="Dependencias del sistema"
    [2]="Configuración MySQL"
    [3]="Clonar código fuente y módulos"
    [4]="Compilar AzerothCore"
    [5]="Configurar servidor y módulos"
    [6]="Servicios systemd"
    [7]="Automatización (crontab y scripts)"
    [8]="Post-instalación (realmlist y cuenta GM)"
    [9]="Panel web (Nginx y systemd)"
    [10]="Cliente web en el navegador (opcional)"
)

# =============================================================================
# Parsear argumentos
# =============================================================================
START_PHASE=1
END_PHASE=7
ONLY_PHASE=""

case "${1:-}" in
    --guiado)
        # Primera vez, sin conocimientos previos: pregunta IP/reino/cuenta,
        # guarda config.sh y lanza la instalación completa desatendida.
        # Admite los sub-modos del asistente: --guiado --comprobar / --configurar.
        shift
        command -v python3 >/dev/null 2>&1 || { error "Falta Python 3. Instálalo con: sudo apt install python3"; exit 1; }
        exec python3 "$SCRIPT_DIR/tools/asistente-instalacion.py" "$@" ;;
    --reanudar)
        # Retoma una instalación completa (--guiado o manual) en el paso pendiente.
        exec bash "$SCRIPT_DIR/scripts/instalar-todo.sh" --reanudar ;;
    --from)   START_PHASE="${2:?'--from requiere un número de fase'}"; END_PHASE=7 ;;
    --only)   ONLY_PHASE="${2:?'--only requiere un número de fase'}" ;;
    --fix)    START_PHASE=2; END_PHASE=5 ;;   # Reparar: MySQL + conf
    --post)   START_PHASE=8; END_PHASE=9 ;;   # Post-primer-arranque + panel web
    --panel)  ONLY_PHASE=9 ;;                 # Instalar/actualizar panel web
    --webclient) ONLY_PHASE=10 ;;             # Instalar/actualizar el cliente web (opcional, /play/)
    --mirror)
        # Regenera las copias offline de los repositorios instalados.
        mirror_all_repos
        echo ""
        exit 0 ;;
    --hidratar)
        # Deja en mirrors/ los snapshots de versions.lock verificados por
        # SHA-256 (asset de versión o reconstrucción desde el upstream, sólo
        # el commit fijado). Opcional: nombres de repositorio para hidratar
        # sólo esos. La edición pública no lleva los .tar.gz.
        shift
        hydrate_mirrors "$@"
        exit $? ;;
    --verify-mirrors)
        # Comprueba que versions.lock, mirrors/versions.lock, MANIFEST.tsv y
        # los tarballs describen exactamente lo mismo. Solo lee: no cambia
        # nada. Salida distinta de cero si hay alguna inconsistencia (la usa
        # también el comando `doctor`).
        # Con --hidratados exige además que los snapshots estén presentes.
        [ "${2:-}" = "--hidratados" ] && export MIRRORS_REQUIRE_FILES=true
        verify_mirrors_consistency
        exit $? ;;
    --doctor)
        # Pasada de comprobaciones de salud (lib/doctor.sh): mirrors,
        # versiones fijadas, claves con historial de incidente, módulos
        # propios, servicios y disco. Solo lee; guarda el resultado en
        # acore_world para el panel (Mi cuenta → Estado del servidor).
        run_doctor "manual"
        exit $? ;;
    --freeze)
        # Congela las versiones instaladas ahora mismo como "las buenas".
        freeze_versions
        echo ""
        echo -e "  Estas son las versiones a las que volverá cualquier instalación:"
        grep -v '^#' "$VERSIONS_LOCK" | awk -F'\t' '{printf "    %-28s %-12s %s (%s)\n", $1, $2, substr($3,1,12), $4}'
        echo ""
        exit 0 ;;
    --help|-h)
        echo ""
        echo -e "  Uso: $0 [opción]"
        echo ""
        echo -e "  --guiado        Primera vez, sin editar nada: pregunta IP/reino/cuenta e instala todo"
        echo -e "  --reanudar      Retomar una instalación completa (--guiado o manual) interrumpida"
        echo -e "  Sin opciones    Instalación completa (fases 1-7) con la config.sh actual"
        echo -e "  --only N        Ejecutar solo la fase N"
        echo -e "  --from N        Ejecutar desde la fase N hasta el final"
        echo -e "  --fix           Reparar instalación existente (MySQL + confs)"
        echo -e "  --post          Pasos tras el primer arranque (fases 8-9, incluido el panel web)"
        echo -e "  --panel         Instalar o actualizar sólo el panel web"
        echo -e "  --webclient     Instalar o actualizar el cliente web del navegador (opcional, fase 10; ver INSTALL_ES.md)"
        echo -e "  --freeze        Congelar las versiones instaladas ahora en versions.lock"
        echo -e "  --mirror        Regenerar las copias offline de los repos en mirrors/"
        echo -e "  --hidratar [repo...]  Reconstruir en mirrors/ los snapshots verificados por SHA-256"
        echo -e "  --verify-mirrors [--hidratados]  Comprobar que versions.lock y mirrors/ coinciden (solo lee)"
        echo -e "  --doctor        Pasada de comprobaciones de salud (mirrors, versiones, claves, módulos...)"
        echo -e "  --help          Ver esta ayuda"
        echo ""
        echo -e "  Fases disponibles:"
        for N in $(seq 1 10); do
            echo -e "    $N — ${PHASE_NAMES[$N]}"
        done
        echo ""
        exit 0 ;;
    "")  ;; # instalación completa por defecto
    *)   error "Opción desconocida: ${1}. Usa --help para ver las opciones."; exit 1 ;;
esac

# =============================================================================
# Nunca como root (salvo --panel)
#
# config.sh hace AC_SYSTEM_USER="$(whoami)". Ejecutar una fase como root
# (p.ej. `sudo ./install.sh --only 6`) deja AC_SYSTEM_USER=root, y las fases 6
# y 7 escriben las unidades systemd y el sudoers con User=root: el servidor
# acaba corriendo como root y la automatización pierde su NOPASSWD.
#
# El instalador está pensado para correr como el usuario del servidor (acore),
# que escala a root con sudo sólo para los comandos que lo necesitan (o con el
# NOPASSWD temporal de instalar-todo.sh). Las únicas excepciones son `--panel` y
# `--webclient`: 09_web_panel.sh y 10_web_client.sh sí necesitan root y se re-lanzan
# con sudo ellos solos.
# =============================================================================
if [ "$(id -u)" -eq 0 ] && [ "${ONLY_PHASE:-}" != "9" ] && [ "${ONLY_PHASE:-}" != "10" ]; then
    error "No ejecutes el instalador como root."
    error "Hazlo con el usuario del servidor (p.ej. 'acore'); sudo se pide sólo cuando hace falta."
    error "  Instalación completa:  ./install.sh --guiado"
    error "  Sólo el panel web:     sudo ./install.sh --panel"
    error "  Sólo el cliente web:   ./install.sh --webclient (pide sudo él solo)"
    exit 1
fi

# =============================================================================
# Pantalla de bienvenida
# =============================================================================
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔════════════════════════════════════════════════════════════╗
  ║       AzerothCore WotLK 3.3.5a — Instalador automático    ║
  ║       Ubuntu 24.04 LTS  ·  Proxmox  ·  Ryzen 7 7730U      ║
  ╚════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${BOLD}Configuración actual (config.sh):${NC}"
echo ""
echo -e "  ${BOLD}Sistema${NC}"
echo -e "    Usuario         : ${CYAN}$AC_SYSTEM_USER${NC}"
echo -e "    Directorio AC   : ${CYAN}$AC_DIR${NC}"
echo -e "    Cores compilac. : ${CYAN}$BUILD_CORES${NC} de $(nproc)"
echo ""
echo -e "  ${BOLD}Servidor${NC}"
echo -e "    Nombre reino    : ${CYAN}$REALM_NAME${NC}"
echo -e "    IP realmlist    : ${CYAN}$REALM_IP${NC}"
echo -e "    Tipo de reino   : ${CYAN}$REALM_TYPE${NC}  (0=Normal 1=PvP 6=RP 8=RP-PvP)"
echo -e "    Máx. jugadores  : ${CYAN}$MAX_PLAYERS${NC}"
echo ""
echo -e "  ${BOLD}Tasas${NC}"
echo -e "    XP Kill/Quest/Explore : ${CYAN}x${RATE_XP_KILL} / x${RATE_XP_QUEST} / x${RATE_XP_EXPLORE}${NC}"
echo -e "    Drop verde/azul/morado: ${CYAN}x${RATE_DROP_UNCOMMON} / x${RATE_DROP_RARE} / x${RATE_DROP_EPIC}${NC}"
echo -e "    Honor / Reputación    : ${CYAN}x${RATE_HONOR} / x${RATE_REPUTATION}${NC}"
echo ""
echo -e "  ${BOLD}Cross-faction${NC}"
echo -e "    Grupos  : $([ "$ALLOW_TWO_SIDE_GROUPS" = true ] && echo "${GREEN}✔ Activado${NC}" || echo "${RED}✘ Desactivado${NC}")"
echo -e "    Guilds  : $([ "$ALLOW_TWO_SIDE_GUILDS" = true ] && echo "${GREEN}✔ Activado${NC}" || echo "${RED}✘ Desactivado${NC}")"
echo -e "    Comercio: $([ "$ALLOW_TWO_SIDE_TRADE"  = true ] && echo "${GREEN}✔ Activado${NC}" || echo "${RED}✘ Desactivado${NC}")"
echo ""
echo -e "  ${BOLD}Módulos${NC}"
# Lista única: "nombre:activado:nota". Al añadir un módulo nuevo basta con
# poner aquí una línea más — antes esto eran 30 líneas repetidas a mano y por
# eso faltaban módulos en el resumen.
MODULE_SUMMARY=(
    "mod-individual-progression:$INSTALL_MOD_INDIVIDUAL_PROGRESSION:progresión Vanilla → TBC → WotLK"
    "mod-progression-skip:${INSTALL_MOD_PROGRESSION_SKIP:-false}:propio — NPC Cronista de las Eras: salto irreversible de progresión (8/13/18)"
    "mod-treasure:${INSTALL_MOD_TREASURE:-false}:propio — cofres itinerantes por zona (SP03)"
    "mod-playerbots:$INSTALL_MOD_PLAYERBOTS:bots ${BOTS_MIN}-${BOTS_MAX}, hasta ${BOTS_MAX_PER_PLAYER} propios en banda"
    "mod-autobalance:$INSTALL_MOD_AUTOBALANCE:raids $([ "$AUTOBALANCE_RAIDS" = true ] && echo "sí" || echo "no"), inflexión ${AUTOBALANCE_INFLECTION}"
    "mod-transmog:$INSTALL_MOD_TRANSMOG:coste ${TRANSMOG_COST} cobre"
    "mod-ah-bot-plus:$INSTALL_MOD_AH_BOT_PLUS:${AH_ITEMS_PER_CYCLE} items por ciclo"
    "mod-random-enchants:$INSTALL_MOD_RANDOM_ENCHANTS:escalado por nivel"
    "mod-congrats-on-level:$INSTALL_MOD_CONGRATS_ON_LEVEL:recompensas en cualquier nivel (parcheado)"
    "mod-dungeon-master:$INSTALL_MOD_DUNGEON_MASTER:⚠ experimental"
    "mod-pvp-titles:$INSTALL_MOD_PVP_TITLES:lo sustituye individual-progression"
    "mod-arac:$INSTALL_MOD_ARAC:requiere parche de cliente manual"
    "mod-challenge-modes:$INSTALL_MOD_CHALLENGE_MODES:hardcore, iron man, XP lenta..."
    "mod-instanced-worldbosses:$INSTALL_MOD_INSTANCED_WORLDBOSSES:jefes de mundo por grupo"
    "mod-war-effort:$INSTALL_MOD_WAR_EFFORT:objetivos x${WAR_EFFORT_GOAL_SCALE}"
    "mod-racial-trait-swap:$INSTALL_MOD_RACIAL_TRAIT_SWAP:${RACIAL_SWAP_GOLD} oro por cambio"
    "mod-reagent-bank:$INSTALL_MOD_REAGENT_BANK:banco de materiales"
    "mod-aoe-loot:$INSTALL_MOD_AOE_LOOT:botín en área"
    "mod-quest-loot-party:${INSTALL_MOD_QUEST_LOOT_PARTY:-false}:copia individual de botín blanco de misión para el grupo"
    "mod-instance-reset:$INSTALL_MOD_INSTANCE_RESET:reinicio de instancias con coste"
    "mod-1v1-arena:$INSTALL_MOD_1V1_ARENA:arena 1c1 a nivel ${ARENA_1V1_MIN_LEVEL}"
    "mod-queue-bots:${INSTALL_MOD_QUEUE_BOTS:-false}:propio — rellena con bots la cola en la que te pones"
    "mod-world-bots:${INSTALL_MOD_WORLD_BOTS:-false}:propio — ${WORLD_BOTS_MIN:-12}-${WORLD_BOTS_MAX:-25} bots de tu nivel en tu zona, ${WORLD_BOTS_CITY_MIN:-30}-${WORLD_BOTS_CITY_MAX:-50} en las capitales"
    "mod-quest-mates:${INSTALL_MOD_QUEST_MATES:-false}:propio — ${QUEST_MATES_MIN:-2}-${QUEST_MATES_MAX:-3} bots cogen tus misiones contigo"
    "mod-dungeon-clear:${INSTALL_MOD_DUNGEON_CLEAR:-false}:el tanque bot lleva la mazmorra$([ "${QUEUE_BOTS_DUNGEON_CLEAR_AUTO:-true}" = true ] && echo ", activado solo al entrar")"
    "mod-party-here:${INSTALL_MOD_PARTY_HERE:-false}:propio — .grupo forma un grupo de bots donde estás; misiones de grupo en automático"
    "mod-home-guild:${INSTALL_MOD_HOME_GUILD:-false}:propio — tu hermandad con ${HOME_GUILD_MEMBERS:-15} bots que siguen tu nivel"
    "mod-bot-operations:${INSTALL_MOD_BOT_OPERATIONS:-false}:propio — publica colas/mundo-etapa/grupos/reservas para el panel web cada ${BOT_OPERATIONS_SNAPSHOT_INTERVAL_SECONDS:-10}s"
    "mod-update-notice:${INSTALL_MOD_UPDATE_NOTICE:-false}:propio — aviso de actualizaciones a los GM al conectarse"
    "mod-server-help:${INSTALL_MOD_SERVER_HELP:-false}:propio — la pestaña de ayuda del cliente con los comandos de tu cuenta (addon ServerHelp)"
    "mod-standby:${INSTALL_MOD_STANDBY:-false}:propio — apaga el worldserver tras ${STANDBY_IDLE_MINUTES:-15} min sin jugadores; .standby"
    "mod-adaptive-ai:${INSTALL_MOD_ADAPTIVE_AI:-false}:propio — bots que aprenden PvP en arenas de entrenamiento (${ADAPTIVE_ARENA_SIMULTANEOUS:-20} a la vez, $(( $(printf '%s' "${ADAPTIVE_ARENA_PAIRS:-warrior:mage}" | tr -cd ',' | wc -c) + 1 )) composiciones); .adaptive"
    "mod-world-buff-bots:${INSTALL_MOD_WORLD_BUFF_BOTS:-false}:buffs de mundo cada ${WORLD_BUFF_BASE_MINUTES:-90}±${WORLD_BUFF_VARIANCE_MINUTES:-60} min"
    "mod-token-turnin:${INSTALL_MOD_TOKEN_TURNIN:-false}:canje de tokens de los bots$([ "${QUEUE_BOTS_TOKEN_TURNIN:-true}" = true ] && echo ", solo tras cada jefe")"
    "mod-playerbots-wintergrasp:${INSTALL_MOD_PLAYERBOTS_WINTERGRASP:-false}:bots aceptan cola/entrada a Wintergrasp; IA táctica apagada"
    "mod-guild-levels:${INSTALL_MOD_GUILD_LEVELS:-false}:XP y 25 niveles de hermandad con perks"
    "mod-guildhouse:${INSTALL_MOD_GUILDHOUSE:-false}:sede de hermandad en la Isla de los MJ (SP02)"
    "mod-profession-experience:${INSTALL_MOD_PROFESSION_EXPERIENCE:-false}:XP por profesiones según dificultad"
)
for SUMMARY_ENTRY in "${MODULE_SUMMARY[@]}"; do
    SUMMARY_MOD="${SUMMARY_ENTRY%%:*}"
    SUMMARY_REST="${SUMMARY_ENTRY#*:}"
    SUMMARY_ON="${SUMMARY_REST%%:*}"
    SUMMARY_NOTE="${SUMMARY_REST#*:}"
    if [ "$SUMMARY_ON" = true ]; then
        echo -e "    ${GREEN}✔${NC} ${SUMMARY_MOD}  ${YELLOW}(${SUMMARY_NOTE})${NC}"
    else
        echo -e "    ${RED}✘${NC} ${SUMMARY_MOD}"
    fi
done
echo ""

# Mostrar qué modo se va a ejecutar
if [ -n "$ONLY_PHASE" ]; then
    echo -e "${YELLOW}  Modo: ejecutar solo fase ${ONLY_PHASE} — ${PHASE_NAMES[$ONLY_PHASE]}${NC}"
elif [ "$START_PHASE" -gt 1 ] || [ "$END_PHASE" -lt 7 ]; then
    echo -e "${YELLOW}  Modo: fases ${START_PHASE} a ${END_PHASE}${NC}"
else
    echo -e "${GREEN}  Modo: instalación completa (fases 1-7)${NC}"
fi
echo ""

echo -e "${BOLD}¿Todo correcto? ¿Continuar? [s/N]${NC} "
read -r CONFIRM
[[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "Instalación cancelada."; exit 0; }

# =============================================================================
# Ejecutar fases
# =============================================================================
INSTALL_START=$(date +%s)
COMPLETED=0

# Nombre de evento para `doctor` (lib/doctor.sh): sólo describe qué se acaba
# de ejecutar, no cambia qué comprueba doctor ni bloquea nada por sí mismo.
if [ -n "$ONLY_PHASE" ]; then
    if [ "$ONLY_PHASE" = "4" ]; then DOCTOR_EVENT="compile"
    elif [ "$ONLY_PHASE" = "3" ]; then DOCTOR_EVENT="update"
    else DOCTOR_EVENT="phase-${ONLY_PHASE}"; fi
elif [ "$START_PHASE" -le 1 ]; then
    DOCTOR_EVENT="install"
else
    DOCTOR_EVENT="update"
fi

run_phase() {
    local N="$1"
    local SCRIPT="$SCRIPT_DIR/${PHASES[$N]}"

    if [ "${AC_INSTALL_PROGRESS_FD:-}" = 8 ]; then
        printf '  Fase %s/9: %s...\n' "$N" "${PHASE_NAMES[$N]}" >&8
    fi

    if [ ! -f "$SCRIPT" ]; then
        error "Script no encontrado: $SCRIPT"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}${BLUE}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}  │  Fase ${N}/${#PHASES[@]} — ${PHASE_NAMES[$N]}${NC}"
    echo -e "${BOLD}${BLUE}  └───────────────────────────────────────────────┘${NC}"
    echo ""

    PHASE_START=$(date +%s)
    if bash "$SCRIPT"; then
        ELAPSED=$(( $(date +%s) - PHASE_START ))
        log "Fase ${N} completada en ${ELAPSED}s."
        COMPLETED=$(( COMPLETED + 1 ))
        # Sólo la instalación completa exporta este destino. Los modos manuales
        # no escriben estado; --post se guarda como un bloque desde su lanzador.
        if [ "$N" -le 7 ]; then save_install_step "$((N + 1))"; fi
    else
        error "Fase ${N} falló."
        error "Revisa el log: ${AC_LOGS_DIR}/install.log"
        error "Puedes reintentar esta fase con: ./install.sh --only ${N}"
        run_doctor "${DOCTOR_EVENT}-failed" || true
        exit 1
    fi
}

if [ -n "$ONLY_PHASE" ]; then
    run_phase "$ONLY_PHASE"
else
    for N in $(seq "$START_PHASE" "$END_PHASE"); do
        run_phase "$N"
    done
fi

# Una sola pasada de doctor por invocación (no una por fase): más que
# suficiente para "al terminar una instalación/actualización/compilación", y
# no repite trabajo si un --only recorre varias fases de golpe. No aborta la
# instalación si encuentra un aviso o un fallo: ya terminó, esto es
# diagnóstico posterior, no una puerta de salida.
run_doctor "$DOCTOR_EVENT" || true

# =============================================================================
# Resumen final
# =============================================================================
TOTAL_ELAPSED=$(( $(date +%s) - INSTALL_START ))
TOTAL_MIN=$(( TOTAL_ELAPSED / 60 ))
TOTAL_SEC=$(( TOTAL_ELAPSED % 60 ))

echo ""
echo -e "${BOLD}${GREEN}"
cat << 'SUCCESS'
  ╔════════════════════════════════════════════════════════════╗
  ║               ✔  INSTALACIÓN COMPLETADA                    ║
  ╚════════════════════════════════════════════════════════════╝
SUCCESS
echo -e "${NC}"
echo -e "  Tiempo total: ${CYAN}${TOTAL_MIN}m ${TOTAL_SEC}s${NC}"
echo ""

# Solo mostrar próximos pasos en instalación completa
if [ -z "$ONLY_PHASE" ] && [ "$START_PHASE" -le 7 ] && [ "$END_PHASE" -ge 6 ]; then
    echo -e "${BOLD}Próximos pasos:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Arrancar el worldserver por primera vez para crear las BDs:"
    echo -e "     ${CYAN}cd $AC_DIR/env/dist/bin && ./worldserver${NC}"
    echo -e "     Responde ${BOLD}yes${NC} a cada pregunta de creación de BD."
    echo -e "     Espera hasta ver: ${BOLD}World initialized${NC}"
    echo ""
    echo -e "  ${YELLOW}2.${NC} Ejecutar los pasos post-instalación (realmlist, instrucciones GM):"
    echo -e "     ${CYAN}./install.sh --post${NC}"
    echo ""
    echo -e "  ${YELLOW}3.${NC} Arrancar los servicios de forma permanente:"
    echo -e "     ${CYAN}sudo service ac-authserver start${NC}"
    echo -e "     ${CYAN}sudo service ac-worldserver start${NC}"
    echo ""
fi

echo -e "${BOLD}Log completo:${NC} ${CYAN}${AC_LOGS_DIR}/install.log${NC}"
echo ""
