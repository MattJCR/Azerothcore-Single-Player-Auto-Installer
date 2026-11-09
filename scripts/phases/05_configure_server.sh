#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#  05_configure_server.sh — Configura worldserver.conf, authserver.conf,
#                           todos los módulos y descarga datos del cliente
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"

header "FASE 5 — Configurar servidor"

# Esta fase se ejecuta suelta con "--only 5" (p.ej. tras editar config.sh), así
# que no puede asumir que la comprobación de la fase 2 acaba de pasar.
require_mysql8 mysql -u "$AC_DB_USER" -p"$AC_DB_PASS"

ETC_DIR="$AC_DIR/env/dist/etc"
BIN_DIR="$AC_DIR/env/dist/bin"
MOD_CONF_DIR="$ETC_DIR/modules"

mkdir -p "$MOD_CONF_DIR"

# =============================================================================
# worldserver.conf
# =============================================================================
header "worldserver.conf"

if [ ! -f "$ETC_DIR/worldserver.conf.dist" ]; then
    error "No se encuentra worldserver.conf.dist"
    error "¿Se completó la compilación (fase 4)?"
    exit 1
fi

# Backup si ya existe una versión previa
if [ -f "$ETC_DIR/worldserver.conf" ]; then
    BACKUP="$ETC_DIR/worldserver.conf.bak.$(date +%s)"
    cp "$ETC_DIR/worldserver.conf" "$BACKUP"
    warn "worldserver.conf existente guardado como backup: $(basename "$BACKUP")"
fi

cp "$ETC_DIR/worldserver.conf.dist" "$ETC_DIR/worldserver.conf"
WS="$ETC_DIR/worldserver.conf"

# ── Base de datos ─────────────────────────────────────────────────────────────
info "Configurando conexiones a base de datos..."
set_conf_value "$WS" "LoginDatabaseInfo"     "\"127.0.0.1;3306;${AC_DB_USER};${AC_DB_PASS};acore_auth\""
set_conf_value "$WS" "WorldDatabaseInfo"     "\"127.0.0.1;3306;${AC_DB_USER};${AC_DB_PASS};acore_world\""
set_conf_value "$WS" "CharacterDatabaseInfo" "\"127.0.0.1;3306;${AC_DB_USER};${AC_DB_PASS};acore_characters\""

# ── Datos del cliente ─────────────────────────────────────────────────────────
set_conf_value "$WS" "DataDir" "\".\""

# ── Registro ──────────────────────────────────────────────────────────────────
# Los ficheros de log del núcleo vienen SIN marca de tiempo (el tercer campo del
# appender son las banderas, y de fábrica es 0). Sin ella no se puede reconstruir
# qué pasó ni en qué orden, que es justo para lo que se miran. Con 3 se antepone
# la hora y el nivel del mensaje.
# 19 = 1 hora + 2 nivel + 16 copia: al arrancar, el Server.log anterior se
# renombra con su fecha en vez de truncarse (el log de una noche no se pierde
# con un reinicio). daily-restart.sh borra las copias de mas de 14 dias.
set_conf_value "$WS" "Appender.Server"     "2,5,19,Server.log,w"
set_conf_value "$WS" "Appender.Playerbots" "2,5,3,Playerbots.log,w"
set_conf_value "$WS" "Appender.Errors"     "2,2,3,Errors.log,w"

# ── Realm ─────────────────────────────────────────────────────────────────────
set_conf_value "$WS" "GameType"    "$REALM_TYPE"
set_conf_value "$WS" "PlayerLimit" "$MAX_PLAYERS"

# ── Tasas ─────────────────────────────────────────────────────────────────────
info "Configurando tasas de experiencia y loot..."
set_conf_value "$WS" "Rate.XP.Kill"           "$RATE_XP_KILL"
set_conf_value "$WS" "Rate.XP.Quest"          "$RATE_XP_QUEST"
set_conf_value "$WS" "Rate.XP.Explore"        "$RATE_XP_EXPLORE"
set_conf_value "$WS" "Rate.Drop.Money"        "$RATE_DROP_MONEY"
set_conf_value "$WS" "Rate.Drop.Item.Uncommon" "$RATE_DROP_UNCOMMON"
set_conf_value "$WS" "Rate.Drop.Item.Rare"    "$RATE_DROP_RARE"
set_conf_value "$WS" "Rate.Drop.Item.Epic"    "$RATE_DROP_EPIC"
set_conf_value "$WS" "Rate.Honor"             "$RATE_HONOR"
set_conf_value "$WS" "Rate.Reputation.Gain"   "$RATE_REPUTATION"

# ── Cross-faction ─────────────────────────────────────────────────────────────
info "Configurando opciones cross-faction..."
# ⚠️  Los nombres de estas claves se comprobaron uno a uno contra
#     WorldConfig.cpp del core. Antes se escribían cuatro que NO EXISTEN
#     (Interaction.Trade, Interaction.Mail, WhoList y AddFriend): el
#     instalador las pegaba al final del worldserver.conf y no las leía
#     nadie. El core no tiene opción para correo, /quién ni amigos entre
#     facciones; lo más parecido al "comercio" es la casa de subastas.
set_conf_value "$WS" "AllowTwoSide.Interaction.Group"   "$(bool_to_int "$ALLOW_TWO_SIDE_GROUPS")"
set_conf_value "$WS" "AllowTwoSide.Interaction.Guild"   "$(bool_to_int "$ALLOW_TWO_SIDE_GUILDS")"
set_conf_value "$WS" "AllowTwoSide.Interaction.Auction" "$(bool_to_int "$ALLOW_TWO_SIDE_TRADE")"
# El say/yell entre facciones es .Chat; .Channel son los canales globales.
# Se escribía sólo el segundo, así que el chat cruzado estaba apagado.
set_conf_value "$WS" "AllowTwoSide.Interaction.Chat"    "$(bool_to_int "$ALLOW_TWO_SIDE_CHAT")"
set_conf_value "$WS" "AllowTwoSide.Interaction.Channel" "$(bool_to_int "$ALLOW_TWO_SIDE_CHAT")"

# Firmas de carta para fundar hermandad (config.sh, "HERMANDADES"). Rango 0-9
# validado por el propio core; a 0 el fundador no necesita firmantes.
set_conf_value "$WS" "MinPetitionSigns" "$GUILD_MIN_PETITION_SIGNS"

# Buzón refrescado al recibir correo estando conectado (config.sh, "CORREO").
set_conf_value "$WS" "Mail.PushInboxOnDelivery" "$(bool_to_int "${MAIL_PUSH_INBOX_ON_DELIVERY:-false}")"

# ── Rendimiento ───────────────────────────────────────────────────────────────
info "Configurando rendimiento..."
# ⚠️  La clave real es MapUpdate.Threads. Durante meses se escribió
#     MapUpdateThreadCount, que no existe: el servidor actualizaba los mapas
#     con UN hilo (el valor por defecto del .dist) con 250 bots encima.
set_conf_value "$WS" "MapUpdate.Threads" "$MAP_UPDATE_THREADS"
# Hasta dónde ve un jugador en los continentes. Va de la mano de mod-world-bots,
# que suelta bots a 250 yardas: con los 100 del dist tardas en cruzarte con ellos.
set_conf_value "$WS" "Visibility.Distance.Continents" "${VISIBILITY_DISTANCE_CONTINENTS:-100}"

# ── Modo en espera (WORLDSERVER_STANDBY) ──────────────────────────────────────
# Con el modo en espera activo, systemd posee el puerto 8085 y se lo entrega al
# worldserver por herencia de descriptor (activación de socket). El core sólo lo
# usa si Network.UseSocketActivation = 1, y además así NO marca el reino como
# desconectado al cerrarse: el cliente lo sigue viendo seleccionable. La consola
# interactiva se apaga porque el binario corre sin terminal (lo gobierna
# ac-worldserver.service, no screen); las operaciones van por SOAP.
if [ "${WORLDSERVER_STANDBY:-false}" = true ]; then
    set_conf_value "$WS" "Network.UseSocketActivation" "1"
    set_conf_value "$WS" "Console.Enable"              "0"
else
    set_conf_value "$WS" "Network.UseSocketActivation" "0"
fi

# ── Módulos — flags generales ─────────────────────────────────────────────────
set_conf_value "$WS" "EnablePlayerSettings"    "1"
set_conf_value "$WS" "Updates.EnableDatabases" "7"

# mod-individual-progression necesita ESTO en 0 para poder sobrescribir las
# estadísticas de los objetos con sus valores de Vanilla. El core lo trae en 1
# ("respeta lo que diga el DBC") y el módulo lo pide explícitamente en su README.
# Sin esta línea, toda la restauración de objetos del módulo queda inactiva y no
# lo avisa nadie: un objeto del Núcleo de Magma da estadísticas de WotLK.
if [ "$INSTALL_MOD_INDIVIDUAL_PROGRESSION" = true ]; then
    set_conf_value "$WS" "DBC.EnforceItemAttributes" "0"
fi

# ── mod-playerbots — entradas OBLIGATORIAS en worldserver.conf ────────────────
if [ "$INSTALL_MOD_PLAYERBOTS" = true ]; then
    info "Añadiendo configuración obligatoria de mod-playerbots..."
    set_conf_value "$WS" "PlayerbotsDatabaseInfo"          "\"127.0.0.1;3306;${AC_DB_USER};${AC_DB_PASS};acore_playerbots\""
    set_conf_value "$WS" "Playerbots.Updates.EnableDatabases" "1"
fi

# ── SOAP — consola del panel de moderación ─────────────────────────────────────
# Apagado por defecto en el core (INSTALL_ES.md lo documentaba como "a propósito").
# El panel de moderación lo necesita: es la única vía que expulsa/banea/silencia
# a un jugador ya conectado y devuelve confirmación de que el comando se aplicó
# (ver web-panel/README.md). Ligado a INSTALL_WEB_PANEL porque sin panel no hay
# quien lo use. SOAP.IP en 127.0.0.1: nunca sale de la máquina, nginx no lo
# expone y el panel ya habla con MySQL por ese mismo camino local.
if [ "$INSTALL_WEB_PANEL" = true ]; then
    set_conf_value "$WS" "SOAP.Enabled" "1"
    set_conf_value "$WS" "SOAP.IP"      "\"127.0.0.1\""
    set_conf_value "$WS" "SOAP.Port"    "7878"
fi

# Los .conf llevan dentro la contrasena de MySQL en claro: 0640 en vez del
# 0644 por defecto para que no los lea cualquier usuario de la maquina.
chmod 640 "$WS" 2>/dev/null || true
log "worldserver.conf configurado."

# =============================================================================
# authserver.conf
# =============================================================================
header "authserver.conf"

if [ -f "$ETC_DIR/authserver.conf" ]; then
    cp "$ETC_DIR/authserver.conf" "$ETC_DIR/authserver.conf.bak.$(date +%s)"
fi

cp "$ETC_DIR/authserver.conf.dist" "$ETC_DIR/authserver.conf"
set_conf_value "$ETC_DIR/authserver.conf" "LoginDatabaseInfo" \
    "\"127.0.0.1;3306;${AC_DB_USER};${AC_DB_PASS};acore_auth\""

chmod 640 "$ETC_DIR/authserver.conf" 2>/dev/null || true
log "authserver.conf configurado."

# =============================================================================
# Actualizar realmlist en la BD
# =============================================================================
header "Realmlist"

if check_mysql_connection "$AC_DB_USER" "$AC_DB_PASS"; then
    # La BD acore_auth puede no existir aún (se crea en el primer arranque).
    # Si existe, actualizamos la IP directamente.
    if db_exists acore_auth; then
        mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" acore_auth \
            -e "UPDATE realmlist SET address='${REALM_IP}', name='${REALM_NAME}' WHERE id=1;" \
            >> "$INSTALL_LOG" 2>&1 && \
            log "Realmlist actualizado: IP=${REALM_IP}, Nombre='${REALM_NAME}'" || \
            warn "No se pudo actualizar el realmlist ahora. Se actualizará tras el primer arranque."
    else
        warn "La BD acore_auth aún no existe (se crea en el primer arranque)."
        info "La IP del realmlist se actualizará automáticamente en la Fase 8."
    fi
else
    warn "No se pudo conectar a MySQL para actualizar el realmlist. Hazlo manualmente tras el primer arranque."
fi

# =============================================================================
# Configuración de módulos
# =============================================================================
header "Configurando módulos"

# ── mod-individual-progression ────────────────────────────────────────────────
if [ "$INSTALL_MOD_INDIVIDUAL_PROGRESSION" = true ]; then
    if install_module_conf "mod-individual-progression" "individualProgression.conf"; then
        CONF="$MOD_CONF_DIR/individualProgression.conf"
        set_conf_value "$CONF" "IndividualProgression.Enable" "1"

        # Ritmo de la progresión (ver el bloque IP_* de config.sh).
        set_conf_value "$CONF" "IndividualProgression.StartingProgression" "$IP_STARTING_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.ProgressionLimit"    "$IP_PROGRESSION_LIMIT"

        # Poder jugar juntos aunque cada uno vaya por una fase distinta.
        set_conf_value "$CONF" "IndividualProgression.EnforceGroupRules" "$(bool_to_int "$IP_ENFORCE_GROUP_RULES")"

        # RDF activo: con los bots en cola, las mazmorras salen rápido.
        set_conf_value "$CONF" "IndividualProgression.DisableRDF" "$(bool_to_int "$IP_DISABLE_RDF")"

        # Marcadores de quest visibles (el módulo los oculta por defecto).
        set_conf_value "$CONF" "IndividualProgression.DisableQuestMarkers" "$(bool_to_int "$IP_DISABLE_QUEST_MARKERS")"

        # Evitar grindeos largos de atunement en TBC.
        set_conf_value "$CONF" "IndividualProgression.SerpentshrineCavern.RequireAllBosses" "$(bool_to_int "$IP_REQUIRE_ALL_BOSSES_SSC")"
        set_conf_value "$CONF" "IndividualProgression.TheEye.RequireAllBosses"              "$(bool_to_int "$IP_REQUIRE_ALL_BOSSES_TK")"

        # Más contenido disponible en cada fase.
        set_conf_value "$CONF" "IndividualProgression.AllowEarlyDungeonSet2"   "$(bool_to_int "$IP_ALLOW_EARLY_DUNGEON_SET2")"
        set_conf_value "$CONF" "IndividualProgression.AllowEarlyScourgeBosses" "$(bool_to_int "$IP_ALLOW_EARLY_SCOURGE_BOSSES")"

        # Arreglos de XP.
        set_conf_value "$CONF" "IndividualProgression.QuestXPFix"                "$(bool_to_int "$IP_QUEST_XP_FIX")"
        set_conf_value "$CONF" "IndividualProgression.RepeatableVanillaQuestsXP" "$(bool_to_int "$IP_REPEATABLE_VANILLA_QUESTS_XP")"

        # ── Naxx40 accesible con grupo pequeño ───────────────────────────────
        # Cuatro jefes de Naxx40 son un muro para un grupo pequeño por MECÁNICA,
        # no por números: autobalance puede bajarles la vida todo lo que quiera
        # y siguen siendo imposibles sin 40 cuerpos repartiéndose tareas.
        set_conf_value "$CONF" "IndividualProgression.doableNaxx40Bosses_4H"        "$(bool_to_int "$IP_DOABLE_NAXX40_4H")"
        set_conf_value "$CONF" "IndividualProgression.doableNaxx40Bosses_Gluth"     "$(bool_to_int "$IP_DOABLE_NAXX40_GLUTH")"
        set_conf_value "$CONF" "IndividualProgression.doableNaxx40Bosses_Patchwerk" "$(bool_to_int "$IP_DOABLE_NAXX40_PATCHWERK")"
        set_conf_value "$CONF" "IndividualProgression.doableNaxx40Bosses_Razuvious" "$(bool_to_int "$IP_DOABLE_NAXX40_RAZUVIOUS")"

        # ── Dificultad del mundo antiguo ─────────────────────────────────────
        set_conf_value "$CONF" "IndividualProgression.VanillaPowerAdjustment"   "$(bool_to_int "$IP_VANILLA_POWER_ADJUSTMENT")"
        set_conf_value "$CONF" "IndividualProgression.VanillaHealingAdjustment" "$(bool_to_int "$IP_VANILLA_HEALING_ADJUSTMENT")"
        set_conf_value "$CONF" "IndividualProgression.TBCPowerAdjustment"       "$(bool_to_int "$IP_TBC_POWER_ADJUSTMENT")"
        set_conf_value "$CONF" "IndividualProgression.TBCHealingAdjustment"     "$(bool_to_int "$IP_TBC_HEALING_ADJUSTMENT")"

        # ── Accesos y desbloqueos ────────────────────────────────────────────
        set_conf_value "$CONF" "IndividualProgression.MoltenCore.ManualRuneHandling" "$(bool_to_int "$IP_MC_MANUAL_RUNE_HANDLING")"
        set_conf_value "$CONF" "IndividualProgression.RequireNaxxStrathEntrance"     "$(bool_to_int "$IP_REQUIRE_NAXX_STRATH_ENTRANCE")"
        set_conf_value "$CONF" "IndividualProgression.RequiredZulGurubProgression"   "$IP_REQUIRED_ZG_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.RequiredZulAmanProgression"    "$IP_REQUIRED_ZA_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.TbcRacesUnlockProgression"     "$IP_TBC_RACES_UNLOCK_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.tbcRacesStartingProgression"   "$IP_TBC_RACES_STARTING_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.DeathKnightUnlockProgression"  "$IP_DK_UNLOCK_PROGRESSION"
        set_conf_value "$CONF" "IndividualProgression.DeathKnightStartingProgression" "$IP_DK_STARTING_PROGRESSION"

        # ── Títulos PvP vanilla (sustituyen a mod-pvp-titles) ────────────────
        # Los umbrales del módulo divididos por IP_PVP_RANK_DIVISOR, para que
        # sean alcanzables en un servidor pequeño.
        IP_PVP_BASE=(100 200 400 800 1400 2000 3000 4500 6000 8000 10000 13000 18000 24000)
        RANK=1
        for BASE_KILLS in "${IP_PVP_BASE[@]}"; do
            set_conf_value "$CONF" "IndividualProgression.VanillaPvpKillRequirement.Rank${RANK}" \
                "$(( BASE_KILLS / IP_PVP_RANK_DIVISOR ))"
            RANK=$(( RANK + 1 ))
        done
        set_conf_value "$CONF" "IndividualProgression.VanillaPvpTitlesPersistAfterVanilla" \
            "$(bool_to_int "$IP_PVP_TITLES_PERSIST")"

        log "[mod-individual-progression] Progresión configurada (inicio=$IP_STARTING_PROGRESSION, límite=$IP_PROGRESSION_LIMIT)."
    fi

    # ── SQL opcional del módulo (contenido) ──────────────────────────────────
    apply_ip_optional_sql || true

    # Los DBC opcionales del servidor (IP_OPTIONAL_DBC) se copian al final de
    # esta fase, tras los datos del cliente: ver apply_server_dbc_overrides.
fi

# ── mod-autobalance ───────────────────────────────────────────────────────────
# Siempre partimos del .dist actualizado para evitar "deprecated value" warnings.
#
# ⚠️  Nombres verificados contra el .conf.dist Y contra src/ del módulo (01/09/2026).
#     La versión anterior "detectaba" las claves con un grep sobre el dist, y el
#     grep caía en la sección DEPRECATED del final del fichero: escribía
#     AutoBalance.enable y AutoBalance.rate.global.{Health,Damage}, que el módulo
#     sólo lee para avisar de que ya no sirven. Y AutoBalance.Raids no ha
#     existido nunca. Resultado: el escalado corría con los valores de fábrica
#     hiciera lo que hiciera config.sh, y nadie lo sabía.
if [ "$INSTALL_MOD_AUTOBALANCE" = true ]; then
    AB_DIST="$AC_DIR/modules/mod-autobalance/conf/AutoBalance.conf.dist"
    AB_CONF="$MOD_CONF_DIR/AutoBalance.conf"

    if [ -f "$AB_DIST" ]; then
        cp "$AB_DIST" "$MOD_CONF_DIR/AutoBalance.conf.dist"
        cp "$AB_DIST" "$AB_CONF"

        set_conf_value "$AB_CONF" "AutoBalance.Enable.Global"   "$(bool_to_int "$AUTOBALANCE_ENABLED")"
        set_conf_value "$AB_CONF" "AutoBalance.InflectionPoint" "$AUTOBALANCE_INFLECTION"

        # Escalado en bandas: el módulo tiene un interruptor por tamaño. Las
        # mazmorras de 5 y las instancias "otras" las gobierna sólo el global.
        AB_RAIDS=$(bool_to_int "$AUTOBALANCE_RAIDS")
        for AB_SIZE in 10M 15M 20M 25M 40M 10MHeroic 25MHeroic; do
            set_conf_value "$AB_CONF" "AutoBalance.Enable.${AB_SIZE}" "$AB_RAIDS"
        done

        # Multiplicadores de vida y daño: hay una familia por tipo de instancia
        # (5, 5 heroica, banda, banda heroica). Los de tamaño concreto
        # (StatModifierRaid10M...) se dejan en blanco: heredan de su familia.
        for AB_FAM in StatModifier StatModifierHeroic StatModifierRaid StatModifierRaidHeroic; do
            set_conf_value "$AB_CONF" "AutoBalance.${AB_FAM}.Health" "$AUTOBALANCE_RATE_HEALTH"
            set_conf_value "$AB_CONF" "AutoBalance.${AB_FAM}.Damage" "$AUTOBALANCE_RATE_DAMAGE"
        done
        log "[mod-autobalance] configurado desde .dist actualizado."
    else
        warn "[mod-autobalance] AutoBalance.conf.dist no encontrado — módulo no clonado."
    fi
fi

# ── mod-transmog ──────────────────────────────────────────────────────────────
if [ "$INSTALL_MOD_TRANSMOG" = true ]; then
    if install_module_conf "mod-transmog" "transmog.conf"; then
        CONF="$MOD_CONF_DIR/transmog.conf"
        # La clave es Transmogrification.Enable, sin "d": la de antes no la leía nadie
        # (el módulo funcionaba porque su dist ya trae Enable = 1).
        set_conf_value "$CONF" "Transmogrification.Enable"              "1"
        set_conf_value "$CONF" "Transmogrification.AllowMixedWeaponTypes" "$TRANSMOG_MIXED_WEAPONS"
        set_conf_value "$CONF" "Transmogrification.AllowHiddenTransmog"  "$(bool_to_int "$TRANSMOG_ALLOW_HIDDEN")"
        set_conf_value "$CONF" "Transmogrification.CopperCost"           "$TRANSMOG_COST"
    fi
fi

# ── mod-ah-bot-plus — configuración COMPLETA y automática ────────────────────
# OJO con el nombre del fichero: este módulo usa "mod_ahbot.conf", el MISMO
# nombre que usaría el bot de subastas nativo. La versión anterior del
# instalador buscaba "mod_ahbotplus.conf" (que no existe en este fork, así que
# el bloque entero se saltaba) y además escribía a propósito un "stub" de 4
# líneas en mod_ahbot.conf con EnableSeller=0 para "silenciar el bot nativo".
# Resultado: el conf real de 72 KB quedaba machacado por un stub que apagaba el
# bot. Por eso el AH nunca se llenaba y había que configurarlo a mano.
if [ "$INSTALL_MOD_AH_BOT_PLUS" = true ]; then
    if install_module_conf "mod-ah-bot-plus" "mod_ahbot.conf"; then
        CONF="$MOD_CONF_DIR/mod_ahbot.conf"

        # Cuenta de servicio + personajes vendedores, creados por SQL.
        # Sin GUIDs válidos el módulo se desactiva solo al arrancar.
        if setup_ah_bot_characters; then
            set_conf_value "$CONF" "AuctionHouseBot.GUIDs"        "$AH_BOT_GUIDS"
            set_conf_value "$CONF" "AuctionHouseBot.EnableSeller" "true"
            log "[mod-ah-bot-plus] Vendedores listos — AuctionHouseBot.GUIDs = $AH_BOT_GUIDS"
        else
            set_conf_value "$CONF" "AuctionHouseBot.EnableSeller" "false"
            warn "[mod-ah-bot-plus] Aún no hay vendedores: el bot queda desactivado."
            warn "  Se activará solo al ejecutar './install.sh --post' tras el primer arranque."
        fi

        set_conf_value "$CONF" "AuctionHouseBot.ItemsPerCycle"  "$AH_ITEMS_PER_CYCLE"
        set_conf_value "$CONF" "AuctionHouseBot.Buyer.Enabled"  "$AH_BUYER_ENABLED"
        set_conf_value "$CONF" "AuctionHouseBot.Buyer.BuyCandidatesPerBuyCycle" "$AH_BUYER_CANDIDATES_PER_CYCLE"
        set_conf_value "$CONF" "AuctionHouseBot.Buyer.AcceptablePriceModifier"  "$AH_BUYER_PRICE_MODIFIER"
        set_conf_value "$CONF" "AuctionHouseBot.Buyer.BidAgainstPlayers"        "$AH_BUYER_BID_AGAINST_PLAYERS"
        set_conf_value "$CONF" "AuctionHouseBot.AdvancedListingRules.UseDropRates.Enabled" "$(bool_to_int "${AH_USE_DROP_RATES:-true}")"

        # Épicos: este fork NO tiene una clave "vender épicos sí/no" (la versión
        # anterior escribía AuctionHouseBot.Seller.Items.Purple, que no existe y
        # quedaba como clave muerta). Lo que hay son proporciones por categoría,
        # así que solo actuamos cuando se piden desactivar.
        if [ "$AH_SELL_EPICS" != true ]; then
            set_conf_value "$CONF" "AuctionHouseBot.ListProportion.CategoryWeapon.QualityEpic" "0"
            set_conf_value "$CONF" "AuctionHouseBot.ListProportion.CategoryArmor.QualityEpic"  "0"
            info "[mod-ah-bot-plus] Épicos desactivados en armas y armaduras."
        fi

        info "[mod-ah-bot-plus] La AH tarda unas horas en llenarse ($AH_ITEMS_PER_CYCLE items/ciclo)."
        info "  Para llenarla ya: entra con tu GM y ejecuta '.ahbot update' varias veces."
    fi
fi

# ── mod-playerbots ────────────────────────────────────────────────────────────
if [ "$INSTALL_MOD_PLAYERBOTS" = true ]; then
    # Playerbots puede depositar el conf en bin/ o en etc/modules/ según versión
    if install_module_conf "mod-playerbots" "playerbots.conf"; then
        CONF="$MOD_CONF_DIR/playerbots.conf"
        set_conf_value "$CONF" "Playerbots.Enabled"                    "1"
        set_conf_value "$CONF" "Playerbots.MinRandomBots"               "$BOTS_MIN"
        set_conf_value "$CONF" "Playerbots.MaxRandomBots"               "$BOTS_MAX"
        set_conf_value "$CONF" "Playerbots.RandomBotMinLevel"           "$BOTS_LEVEL_MIN"
        set_conf_value "$CONF" "Playerbots.RandomBotMaxLevel"           "$BOTS_LEVEL_MAX"
        set_conf_value "$CONF" "Playerbots.DisabledWithoutRealPlayer"   "$(bool_to_int "$BOTS_DISABLED_WITHOUT_PLAYER")"
        set_conf_value "$CONF" "Playerbots.DisabledWithoutRealPlayerLogoutDelay" "${BOTS_NO_PLAYER_LOGOUT_DELAY:-600}"
        # Porcentaje de bots que simula de verdad lejos de cualquier jugador. Es
        # lo que contiene el coste de subir MinRandomBots/MaxRandomBots a 400/500.
        set_conf_value "$CONF" "Playerbots.BotActiveAlone"              "${BOT_ACTIVE_ALONE:-10}"
        # Cómo cambia la población de bots conectados (0 estático, 1 variable,
        # 2 por horario). Sustituye a la rotación periódica, eliminada en #2774.
        set_conf_value "$CONF" "Playerbots.RandomBotCountMode"           "${BOTS_COUNT_MODE:-0}"
        set_conf_value "$CONF" "Playerbots.MaxAddedBots"                "$BOTS_MAX_PER_PLAYER"
        set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBG"         "$(bool_to_int "$BOTS_AUTO_JOIN_BG")"
        # OJO: RandomBotMaxGearQuality NO existe en el módulo (se comprobó con un
        # grep sobre su código). Las claves que sí se leen son estas dos: la
        # primera manda al aleatorizar un bot, la segunda al auto-equiparlo.
        set_conf_value "$CONF" "Playerbots.RandomGearQualityLimit"      "$BOTS_MAX_GEAR_QUALITY"
        set_conf_value "$CONF" "Playerbots.AutoGearQualityLimit"        "$BOTS_MAX_GEAR_QUALITY"
        set_conf_value "$CONF" "Playerbots.TwoRoundsGearInit"           "$(bool_to_int "${BOTS_GEAR_TWO_ROUNDS:-true}")"
        set_conf_value "$CONF" "Playerbots.RandomBotMaps"               "0,1,530,571"

        # Prioridad de botín para jugadores humanos: requiere el parche 04 de
        # patches/mod-playerbots/ (fase 3); sin él aplicado esta clave no la lee
        # nadie. Al activarla se fija también el resto de la decisión de la IA
        # (necesidad/codicia), que las reglas de utilidad y objetos únicos del
        # bot siguen acotando como siempre.
        set_conf_value "$CONF" "Playerbots.LootRollAfterRealPlayersPass" "$(bool_to_int "${BOTS_LOOT_ROLL_AFTER_REAL_PLAYERS_PASS:-false}")"
        if [ "${BOTS_LOOT_ROLL_AFTER_REAL_PLAYERS_PASS:-false}" = true ]; then
            set_conf_value "$CONF" "Playerbots.LootNeedRollLevel"  "2"
            set_conf_value "$CONF" "Playerbots.LootGreedRollLevel" "1"
        fi

        # Aviso «Eating [objeto] (85%)» al comer/beber (UPD-B). Clave nueva de
        # mod-playerbots 037c014; en versiones anteriores no la lee nadie.
        set_conf_value "$CONF" "Playerbots.AnnounceConsumableUse" "$(bool_to_int "${BOTS_ANNOUNCE_CONSUMABLE_USE:-false}")"

        # ── Que siempre haya bots de tu nivel ────────────────────────────────
        # SyncLevelWithPlayers es la opción clave: pega el nivel máximo de los
        # bots al del jugador de más nivel conectado, así los bots se reparten
        # entre 1 y tu nivel en vez de diluirse hasta 80. Con 150 bots y un
        # jugador de nivel 20 salen ~7 bots por nivel en vez de ~2.
        set_conf_value "$CONF" "Playerbots.SyncLevelWithPlayers"    "$(bool_to_int "$BOTS_SYNC_LEVEL_WITH_PLAYERS")"

        # Los bots usan el buscador de mazmorras: es lo que llena las colas.
        set_conf_value "$CONF" "Playerbots.RandomBotJoinLfg"        "$(bool_to_int "$BOTS_JOIN_LFG")"

        # Recolección (DoGather, 12/10/2026): los bots recorren la zona cogiendo
        # hierbas y minerales. Opción nueva de playerbots, encendida de fábrica y sin
        # medir aquí (coste por bot, competencia por los nodos): arranca apagada
        # hasta probarla (PLAN.md, UPD-O). Peso 0-100 (15 de fábrica) en BOTS_RPG_DO_GATHER.
        set_conf_value "$CONF" "Playerbots.RpgStatusProbWeight.DoGather" "${BOTS_RPG_DO_GATHER:-0}"

        # El módulo amontona por defecto un 10% de bots en el nivel mínimo y
        # otro 10% en el máximo, dejando pelados los niveles intermedios.
        set_conf_value "$CONF" "Playerbots.RandomBotMinLevelChance" "$BOTS_MIN_LEVEL_CHANCE"
        set_conf_value "$CONF" "Playerbots.RandomBotMaxLevelChance" "$BOTS_MAX_LEVEL_CHANCE"

        # Cuentas de bot (10 personajes cada una). El módulo sube este número
        # solo si le hace falta para cumplir con BOTS_MAX, pero nunca lo baja.
        set_conf_value "$CONF" "Playerbots.RandomBotAccountCount"   "${BOTS_ACCOUNT_COUNT:-0}"

        # ── Battlegrounds en todos los rangos ────────────────────────────────
        # El módulo solo apunta bots al bracket MÁS ALTO de cada BG (WS=7,
        # AB=6, AV=3, EY=2, IC=1), así que por debajo de nivel 70 las colas no
        # arrancaban nunca. Y AV/IC venían con Count=0, o sea, nunca.
        set_conf_value "$CONF" "Playerbots.RandomBotJoinBG"     "1"
        set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBG" "$(bool_to_int "$BOTS_AUTO_JOIN_BG")"

        if [ "$BOTS_BG_ALL_BRACKETS" = true ] && [ "$BOTS_AUTO_JOIN_BG" = true ]; then
            set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinWSBrackets" "0,1,2,3,4,5,6,7"
            set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinABBrackets" "0,1,2,3,4,5,6"
            set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinAVBrackets" "0,1,2,3"
            set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinEYBrackets" "0,1,2"
            set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinICBrackets" "0,1"
            for BG_CODE in WS AB AV EY IC; do
                set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBG${BG_CODE}Count" "$BOTS_BG_PER_BRACKET"
            done
            log "[mod-playerbots] Colas de BG activas en todos los rangos de nivel."
        fi

        # ── Reparto de bots por franja de nivel ──────────────────────────────
        # Estas claves sólo existen en versiones del módulo que traigan el
        # sistema de "level brackets". La fijada en versions.lock NO lo trae, y
        # escribirlas a ciegas fue justo el error que dejó el servidor sin bots
        # de nivel 80: se daba por hecho que ese sistema repartía los bots y por
        # eso se había apagado MIN/MAX_LEVEL_CHANCE. Ahora se comprueba antes.
        if [ "$BOTS_LEVEL_BRACKETS" = true ]; then
            if grep -rq 'LevelBrackets' "$AC_DIR/modules/mod-playerbots/src" 2>/dev/null; then
                DYN="$(bool_to_int "${BOTS_LEVEL_BRACKETS_DYNAMIC:-false}")"
                set_conf_value "$CONF" "Playerbots.LevelBrackets.Enabled"                        "1"
                set_conf_value "$CONF" "Playerbots.LevelBrackets.Dynamic.UseDynamicDistribution" "$DYN"
                set_conf_value "$CONF" "Playerbots.LevelBrackets.Dynamic.RealPlayerWeight"       "$BOTS_LEVEL_BRACKETS_PLAYER_WEIGHT"
                set_conf_value "$CONF" "Playerbots.LevelBrackets.Dynamic.HighestPlayerOnly"       "$(bool_to_int "${BOTS_LEVEL_BRACKETS_HIGHEST_ONLY:-false}")"
                set_conf_value "$CONF" "Playerbots.LevelBrackets.Dynamic.SyncFactions"            "$(bool_to_int "${BOTS_LEVEL_BRACKETS_SYNC_FACTIONS:-false}")"
                set_conf_value "$CONF" "Playerbots.SyncLevelWithPlayers"                         "0"
                if [ "$DYN" = "1" ]; then
                    log "[mod-playerbots] Reparto dinámico por franjas de nivel activo."
                    warn "  El reparto dinámico PISA los porcentajes fijos (BOTS_LEVEL80_PCT)."
                else
                    log "[mod-playerbots] Franjas de nivel con porcentajes fijos (reparto dinámico apagado)."
                fi
                info "  (SyncLevelWithPlayers queda a 0: los dos sistemas se pisan)"

                # Cuota de la franja de nivel máximo. El .conf.dist del módulo
                # reparte 9 franjas al 11-12 %, o sea 26 bots de nivel 80 por
                # facción: el gestor BAJA DE NIVEL a los que sobran cada pocos
                # segundos, y eso peleaba con la fábrica de mod-adaptive-ai
                # (03/09/2026: 18 subidas a 80 por minuto para mantener 167 de
                # los 200 pedidos; "Range 9 (80-80): Desired = 26, Actual = 64"
                # en Playerbots.log). Con la cuota alta el forcejeo desaparece.
                # El resto se reparte a partes iguales entre las ocho franjas
                # de abajo. Ojo: esto solo llega a usarse con el reparto
                # dinámico apagado (ApplyBracketWeights reescribe los pct).
                PCT80="${BOTS_LEVEL80_PCT:-36}"
                if [[ "$PCT80" =~ ^[0-9]+$ ]] && [ "$PCT80" -gt 0 ] && [ "$PCT80" -lt 93 ]; then
                    pct80="$PCT80"
                    rest=$(( (100 - pct80) / 8 ))
                    for faction in Alliance Horde; do
                        for r in 1 2 3 4 5 6 7 8; do
                            set_conf_value "$CONF" "Playerbots.LevelBrackets.${faction}.Range${r}.Pct" "$rest"
                        done
                        set_conf_value "$CONF" "Playerbots.LevelBrackets.${faction}.Range9.Pct" "$pct80"
                    done
                    info "  (franja de nivel 80 al ${pct80} %, las ocho de abajo al ${rest} % cada una)"
                fi
            else
                warn "[mod-playerbots] BOTS_LEVEL_BRACKETS=true pero esta versión del módulo"
                warn "  no trae el sistema de franjas de nivel: se ignora."
                warn "  El reparto lo siguen decidiendo BOTS_MIN/MAX_LEVEL_CHANCE."
            fi
        fi

        # ── Arenas puntuadas ─────────────────────────────────────────────────
        # El módulo crea equipos de arena de bots pero de fábrica no los apunta a
        # ninguna partida, así que la arena puntuada nunca arrancaba.
        set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBGRatedArena2v2Count" "$BOTS_ARENA_RATED_2V2"
        set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBGRatedArena3v3Count" "$BOTS_ARENA_RATED_3V3"
        set_conf_value "$CONF" "Playerbots.RandomBotAutoJoinBGRatedArena5v5Count" "$BOTS_ARENA_RATED_5V5"

        # ── Mundo vivo y coherencia con la progresión ────────────────────────
        set_conf_value "$CONF" "Playerbots.RandomBotInvitePlayer"   "$(bool_to_int "$BOTS_GUILD_INVITE_PLAYER")"
        set_conf_value "$CONF" "Playerbots.LimitTalentsExpansion"   "$(bool_to_int "$BOTS_LIMIT_TALENTS_EXPANSION")"
        set_conf_value "$CONF" "Playerbots.SelfBotLevel"            "$BOTS_SELFBOT_LEVEL"
    else
        warn "playerbots.conf no encontrado aún — se generará al compilar."
        warn "Ejecuta './install.sh --only 5' tras compilar para aplicar la configuración."
    fi
fi

# ── mod-random-enchants ───────────────────────────────────────────────────────
if [ "$INSTALL_MOD_RANDOM_ENCHANTS" = true ]; then
    if install_module_conf "mod-random-enchants" "random_enchants.conf"; then
        CONF="$MOD_CONF_DIR/random_enchants.conf"
        set_conf_value "$CONF" "RandomEnchants.Enable"          "1"
        set_conf_value "$CONF" "RandomEnchants.AnnounceOnLogin" "$(bool_to_int "$RANDOM_ENCHANTS_ANNOUNCE")"
        set_conf_value "$CONF" "RandomEnchants.OnLoot"          "1"
        set_conf_value "$CONF" "RandomEnchants.OnCreate"        "1"
        set_conf_value "$CONF" "RandomEnchants.OnQuestReward"   "1"
        set_conf_value "$CONF" "RandomEnchants.OnGroupRoll"     "1"
        set_conf_value "$CONF" "RandomEnchants.EnchantChance1"  "$RANDOM_ENCHANTS_CHANCE_1"
        set_conf_value "$CONF" "RandomEnchants.EnchantChance2"  "$RANDOM_ENCHANTS_CHANCE_2"
        set_conf_value "$CONF" "RandomEnchants.EnchantChance3"  "$RANDOM_ENCHANTS_CHANCE_3"

        # Escalado por nivel — lo aporta nuestro parche
        # (patches/mod-random-enchants/01-level-scaled-tiers.patch), que además
        # arregla la consulta SQL del módulo: tenía la precedencia rota y el
        # filtro de tier no se aplicaba NUNCA, de ahí los encantamientos de
        # nivel 80 en objetos de nivel 10.
        set_conf_value "$CONF" "RandomEnchants.ScaleWithLevel" "$(bool_to_int "$RANDOM_ENCHANTS_SCALE_WITH_LEVEL")"
        set_conf_value "$CONF" "RandomEnchants.Tier2MinLevel"  "$RANDOM_ENCHANTS_TIER2_MIN_LEVEL"
        set_conf_value "$CONF" "RandomEnchants.Tier3MinLevel"  "$RANDOM_ENCHANTS_TIER3_MIN_LEVEL"
        set_conf_value "$CONF" "RandomEnchants.Tier4MinLevel"  "$RANDOM_ENCHANTS_TIER4_MIN_LEVEL"
        set_conf_value "$CONF" "RandomEnchants.Tier5MinLevel"  "$RANDOM_ENCHANTS_TIER5_MIN_LEVEL"

        # SQL necesario: crea la tabla item_enchatment_random_tiers en acore_world.
        # Idempotente: el propio script SQL usa CREATE TABLE IF NOT EXISTS / INSERT
        # IGNORE en las versiones recientes; igualmente lo envolvemos para no
        # abortar la fase si ya se aplicó en una instalación previa.
        RE_SQL_DIR="$AC_DIR/modules/mod-random-enchants/data/sql/db-world"
        if ! db_exists acore_world; then
            warn "[mod-random-enchants] acore_world no existe todavia (se crea en el primer arranque)."
            warn "  El SQL se aplicara automaticamente con './install.sh --only 5' o '--post'."
        else
            apply_sql_dir "mod-random-enchants" acore_world "$RE_SQL_DIR"
        fi
    fi
fi

# ── mod-pvp-titles ────────────────────────────────────────────────────────────
if [ "$INSTALL_MOD_PVP_TITLES" = true ]; then
    if install_module_conf "mod-pvp-titles" "mod_pvptitles.conf"; then
        CONF="$MOD_CONF_DIR/mod_pvptitles.conf"
        # El conf.dist de este módulo no expone más claves que el enable;
        # set_conf_value es seguro de re-ejecutar aunque ya exista la clave.
        set_conf_value "$CONF" "PvPTitles.Enable" "1"
    fi
fi

# ── mod-congrats-on-level ─────────────────────────────────────────────────────
# Recompensas (oro/hechizo/items) configurables por nivel/raza/clase desde la
# tabla mod_congrats_on_level_items en acore_world. Necesita conf + SQL,
# igual que mod-random-enchants: ambos pasos son idempotentes.
if [ "$INSTALL_MOD_CONGRATS_ON_LEVEL" = true ]; then
    if install_module_conf "mod-congrats-on-level" "mod_congratsonlevel.conf"; then
        CONF="$MOD_CONF_DIR/mod_congratsonlevel.conf"
        # La clave de activación real del módulo es CongratsPerLevel.Enable;
        # se detecta dinámicamente por si el .dist usa mayúsculas/minúsculas distintas.
        if grep -qi "^CongratsPerLevel.Enable" "$CONF" 2>/dev/null; then
            set_conf_value "$CONF" "CongratsPerLevel.Enable" "$(bool_to_int "${CONGRATS_LEVEL_MESSAGE:-true}")"
        fi
        # Aviso del módulo al conectar, y mensaje de recompensa (este último lo
        # aporta patches/mod-congrats-on-level/02-reward-message-toggle.patch:
        # sin el parche la clave no existe y set_conf_value avisaría).
        set_conf_value "$CONF" "Congrats.Announce" "$(bool_to_int "${CONGRATS_LOGIN_ANNOUNCE:-false}")"
        if grep -qi "^Congrats.RewardMessage" "$CONF" 2>/dev/null; then
            set_conf_value "$CONF" "Congrats.RewardMessage" "$(bool_to_int "${CONGRATS_REWARD_MESSAGE:-true}")"
            set_conf_value "$CONF" "Congrats.IgnoreBots"    "$(bool_to_int "${CONGRATS_IGNORE_BOTS:-true}")"
        else
            warn "[mod-congrats-on-level] sin el parche 02 el mensaje de recompensa no se puede apagar."
        fi
    fi

    # SQL: crea/rellena mod_congrats_on_level_items en acore_world.
    # Buscamos el .sql dentro del módulo en vez de asumir un nombre fijo,
    # ya que puede variar entre versiones (igual que con otros módulos).
    COL_SQL_DIR="$AC_DIR/modules/mod-congrats-on-level/data/sql/db-world"
    if ! db_exists acore_world; then
        warn "[mod-congrats-on-level] acore_world no existe todavia (se crea en el primer arranque)."
        warn "  El SQL se aplicara automaticamente con './install.sh --only 5' o '--post'."
    else
        apply_sql_dir "mod-congrats-on-level" acore_world "$COL_SQL_DIR"
        info "[mod-congrats-on-level] Recompensas editables en la tabla mod_congrats_on_level_items"
        info "  (acore_world): columnas level, money, spell, learn, itemId1, itemId2, race, class."
    fi
fi

# ── mod-dungeon-master ────────────────────────────────────────────────────────
# ⚠️ Módulo en desarrollo temprano (ver aviso en config.sh). Las claves de
# dificultad/roguelike/recompensas se controlan desde config.sh (prefijo DM_*)
# y se aplican aquí con set_conf_value, igual que el resto de módulos.
# Necesita SQL en DOS bases de datos: acore_world y acore_characters.
if [ "$INSTALL_MOD_DUNGEON_MASTER" = true ]; then
    if install_module_conf "mod-dungeon-master" "mod_dungeon_master.conf"; then
        CONF="$MOD_CONF_DIR/mod_dungeon_master.conf"
        info "[mod-dungeon-master] Aplicando configuración desde config.sh..."

        # OJO con el prefijo: este módulo lee TODAS sus claves como
        # "DungeonMaster.<seccion>.<clave>". Sin él, set_conf_value no
        # encuentra la clave y la AÑADE al final del fichero, donde el
        # módulo no la mira: los 21 valores DM_* de config.sh se estaban
        # ignorando y el módulo corría con sus valores por defecto.
        set_conf_value "$CONF" "DungeonMaster.Enable" "1"

        set_conf_value "$CONF" "DungeonMaster.Scaling.SoloMultiplier"  "$DM_SOLO_MULTIPLIER"
        set_conf_value "$CONF" "DungeonMaster.Scaling.PerPlayerHealth"  "$DM_PER_PLAYER_HEALTH"
        set_conf_value "$CONF" "DungeonMaster.Scaling.BossHealthMult"   "$DM_BOSS_HEALTH_MULT"
        set_conf_value "$CONF" "DungeonMaster.Scaling.BossDamageMult"   "$DM_BOSS_DAMAGE_MULT"
        set_conf_value "$CONF" "DungeonMaster.Scaling.EliteHealthMult"  "$DM_ELITE_HEALTH_MULT"

        set_conf_value "$CONF" "DungeonMaster.Dungeon.BossCount"   "$DM_BOSS_COUNT"
        set_conf_value "$CONF" "DungeonMaster.Dungeon.EliteChance" "$DM_ELITE_CHANCE"

        set_conf_value "$CONF" "DungeonMaster.Roguelike.Enable"                "$(bool_to_int "$DM_ROGUELIKE_ENABLE")"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.TransitionDelay"       "$DM_ROGUELIKE_TRANSITION_DELAY"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.HpScalingPerTier"      "$DM_ROGUELIKE_HP_SCALING_PER_TIER"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.DmgScalingPerTier"     "$DM_ROGUELIKE_DMG_SCALING_PER_TIER"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.ExponentialThreshold"  "$DM_ROGUELIKE_EXPONENTIAL_THRESHOLD"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.ExponentialFactor"     "$DM_ROGUELIKE_EXPONENTIAL_FACTOR"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.AffixStartTier"        "$DM_ROGUELIKE_AFFIX_START_TIER"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.SecondAffixTier"       "$DM_ROGUELIKE_SECOND_AFFIX_TIER"
        set_conf_value "$CONF" "DungeonMaster.Roguelike.ThirdAffixTier"        "$DM_ROGUELIKE_THIRD_AFFIX_TIER"

        set_conf_value "$CONF" "DungeonMaster.Rewards.BaseGold"     "$DM_REWARDS_BASE_GOLD"
        set_conf_value "$CONF" "DungeonMaster.Rewards.XPMultiplier" "$DM_REWARDS_XP_MULTIPLIER"
        set_conf_value "$CONF" "DungeonMaster.Rewards.ItemChance"   "$DM_REWARDS_ITEM_CHANCE"
        set_conf_value "$CONF" "DungeonMaster.Rewards.RareChance"   "$DM_REWARDS_RARE_CHANCE"
        set_conf_value "$CONF" "DungeonMaster.Rewards.EpicChance"   "$DM_REWARDS_EPIC_CHANCE"

        log "[mod-dungeon-master] Configuración aplicada en: $CONF"
    fi

    DM_DIR="$AC_DIR/modules/mod-dungeon-master/data/sql"
    if ! db_exists acore_world || ! db_exists acore_characters; then
        warn "[mod-dungeon-master] acore_world / acore_characters no existen todavia"
        warn "  (se crean en el primer arranque). El SQL se aplicara con '--only 5' o '--post'."
    else
        apply_sql_dir "mod-dungeon-master" acore_world      "$DM_DIR/db-world"
        apply_sql_dir "mod-dungeon-master" acore_characters "$DM_DIR/db-characters"
    fi

    info "[mod-dungeon-master] NPC 'Dungeon Master' (entry 500000) aparece automáticamente"
    info "  en las capitales. Comandos GM: .dm status / .dm list / .dm end / .dm reload"
fi

# ── mod-arac (SQL + DBC del servidor automatizados; el parche de cliente
#    sigue siendo manual porque vive en la máquina de cada jugador) ──────────
# ── mod-challenge-modes ───────────────────────────────────────────────────────
# Modos de desafío por personaje. Usa Player Settings (EnablePlayerSettings ya
# está a 1 arriba) para guardar qué desafíos tiene activos cada personaje.
# Los "Santuarios del Desafío" se colocan solos en las 9 zonas iniciales con el
# SQL del módulo, así que aquí no hay nada que spawnear.
if [ "$INSTALL_MOD_CHALLENGE_MODES" = true ]; then
    if install_module_conf "mod-challenge-modes" "challenge_modes.conf"; then
        CONF="$MOD_CONF_DIR/challenge_modes.conf"
        set_conf_value "$CONF" "ChallengeModes.Enable" "1"

        # Cada desafío: activación, recompensa en puntos de talento y, cuando
        # aplica, multiplicador de XP como compensación por la dificultad.
        # (Los de XP lenta no admiten multiplicador: ya modifican la XP.)
        set_conf_value "$CONF" "Hardcore.Enable"            "$(bool_to_int "$CM_HARDCORE")"
        set_conf_value "$CONF" "Hardcore.TalentRewards"     "\"$CM_TALENTS_HARDCORE\""
        set_conf_value "$CONF" "Hardcore.XPMultiplier"      "$CM_XP_MULT_HARDCORE"

        set_conf_value "$CONF" "SemiHardcore.Enable"        "$(bool_to_int "$CM_SEMI_HARDCORE")"
        set_conf_value "$CONF" "SemiHardcore.TalentRewards" "\"$CM_TALENTS_SEMI_HARDCORE\""
        set_conf_value "$CONF" "SemiHardcore.XPMultiplier"  "$CM_XP_MULT_SEMI_HARDCORE"

        set_conf_value "$CONF" "SelfCrafted.Enable"         "$(bool_to_int "$CM_SELF_CRAFTED")"
        set_conf_value "$CONF" "SelfCrafted.TalentRewards"  "\"$CM_TALENTS_SELF_CRAFTED\""
        set_conf_value "$CONF" "SelfCrafted.XPMultiplier"   "$CM_XP_MULT_SELF_CRAFTED"

        set_conf_value "$CONF" "ItemQualityLevel.Enable"        "$(bool_to_int "$CM_ITEM_QUALITY")"
        set_conf_value "$CONF" "ItemQualityLevel.TalentRewards" "\"$CM_TALENTS_ITEM_QUALITY\""
        set_conf_value "$CONF" "ItemQualityLevel.XPMultiplier"  "$CM_XP_MULT_ITEM_QUALITY"

        set_conf_value "$CONF" "SlowXpGain.Enable"            "$(bool_to_int "$CM_SLOW_XP")"
        set_conf_value "$CONF" "SlowXpGain.TalentRewards"     "\"$CM_TALENTS_SLOW_XP\""
        set_conf_value "$CONF" "VerySlowXpGain.Enable"        "$(bool_to_int "$CM_VERY_SLOW_XP")"
        set_conf_value "$CONF" "VerySlowXpGain.TalentRewards" "\"$CM_TALENTS_VERY_SLOW_XP\""

        set_conf_value "$CONF" "QuestXpOnly.Enable"        "$(bool_to_int "$CM_QUEST_XP_ONLY")"
        set_conf_value "$CONF" "QuestXpOnly.TalentRewards" "\"$CM_TALENTS_QUEST_XP_ONLY\""

        set_conf_value "$CONF" "IronMan.Enable"        "$(bool_to_int "$CM_IRON_MAN")"
        set_conf_value "$CONF" "IronMan.TalentRewards" "\"$CM_TALENTS_IRON_MAN\""
    fi

    if db_exists acore_world; then
        apply_sql_dir "mod-challenge-modes" acore_world \
            "$AC_DIR/modules/mod-challenge-modes/data/sql/db-world"
    fi
fi

# ── mod-instanced-worldbosses ─────────────────────────────────────────────────
if [ "$INSTALL_MOD_INSTANCED_WORLDBOSSES" = true ]; then
    if install_module_conf "mod-instanced-worldbosses" "mod-instanced-worldbosses.conf"; then
        CONF="$MOD_CONF_DIR/mod-instanced-worldbosses.conf"
        set_conf_value "$CONF" "ModInstancedWorldBosses.Enable"           "1"
        set_conf_value "$CONF" "ModInstancedWorldBosses.ResetTimerSecs"   "$IWB_RESET_TIMER_SECS"
        set_conf_value "$CONF" "ModInstancedWorldBosses.RespawnTimerSecs" "$IWB_RESPAWN_TIMER_SECS"
        # PhaseBosses es lo que hace que el jefe sea REALMENTE de tu grupo: sin
        # esto, cualquier bot que pase por ahí puede meterse en el combate.
        set_conf_value "$CONF" "ModInstancedWorldBosses.PhaseBosses"      "$(bool_to_int "$IWB_PHASE_BOSSES")"
    fi

    if db_exists acore_world; then
        apply_sql_dir "mod-instanced-worldbosses" acore_world \
            "$AC_DIR/modules/mod-instanced-worldbosses/data/sql/db-world"
    fi
fi

# ── mod-war-effort ────────────────────────────────────────────────────────────
# Esfuerzo de Guerra de Ahn'Qiraj. Los objetivos por fase se generan desde
# config.sh: son 5 materiales x 5 fases x 2 facciones = 50 claves, así que se
# escriben en bucle en vez de a mano.
if [ "$INSTALL_MOD_WAR_EFFORT" = true ]; then
    if install_module_conf "mod-war-effort" "mod_aq_war_effort.conf"; then
        CONF="$MOD_CONF_DIR/mod_aq_war_effort.conf"
        set_conf_value "$CONF" "ModWarEffort.Enable" "1"

        for WE_FACTION in Horde Alliance; do
            for WE_MATERIAL in Bandages Food Herbs Metal Leather; do
                WE_STAGE=1
                for WE_BASE in "${WAR_EFFORT_GOALS[@]}"; do
                    set_conf_value "$CONF" \
                        "ModWarEffort.Goal.${WE_FACTION}.${WE_MATERIAL}.0${WE_STAGE}" \
                        "$(( WE_BASE * WAR_EFFORT_GOAL_SCALE ))"
                    WE_STAGE=$(( WE_STAGE + 1 ))
                done
            done
        done
        log "[mod-war-effort] Objetivos escalados x${WAR_EFFORT_GOAL_SCALE}."
    fi

    if db_exists acore_world; then
        apply_sql_dir "mod-war-effort" acore_world \
            "$AC_DIR/modules/mod-war-effort/data/sql/db-world"
    fi
    if db_exists acore_characters; then
        apply_sql_dir "mod-war-effort" acore_characters \
            "$AC_DIR/modules/mod-war-effort/data/sql/db-characters"
    fi
fi

# ── mod-racial-trait-swap ─────────────────────────────────────────────────────
if [ "$INSTALL_MOD_RACIAL_TRAIT_SWAP" = true ]; then
    if install_module_conf "mod-racial-trait-swap" "RacialTraitSwap.conf"; then
        CONF="$MOD_CONF_DIR/RacialTraitSwap.conf"
        set_conf_value "$CONF" "Racial.Traits.Swap.Gold" "$RACIAL_SWAP_GOLD"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-racial-trait-swap" acore_world \
            "$AC_DIR/modules/mod-racial-trait-swap/data/sql/db-world"
    fi
fi

# ── mod-reagent-bank ──────────────────────────────────────────────────────────
if [ "$INSTALL_MOD_REAGENT_BANK" = true ]; then
    if install_module_conf "mod-reagent-bank" "reagent_bank.conf"; then
        CONF="$MOD_CONF_DIR/reagent_bank.conf"
        set_conf_value "$CONF" "ReagentBank.Enable" "1"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-reagent-bank" acore_world \
            "$AC_DIR/modules/mod-reagent-bank/data/sql/db-world"
    fi
    if db_exists acore_characters; then
        apply_sql_dir "mod-reagent-bank" acore_characters \
            "$AC_DIR/modules/mod-reagent-bank/data/sql/db-characters"
    fi
fi

# ── mod-aoe-loot ──────────────────────────────────────────────────────────────
if [ "$INSTALL_MOD_AOE_LOOT" = true ]; then
    if install_module_conf "mod-aoe-loot" "mod_aoe_loot.conf"; then
        CONF="$MOD_CONF_DIR/mod_aoe_loot.conf"
        set_conf_value "$CONF" "AOELoot.Enable" "1"
        set_conf_value "$CONF" "AOELoot.Range"  "$AOE_LOOT_RANGE"
        set_conf_value "$CONF" "AOELoot.Group"  "$(bool_to_int "$AOE_LOOT_GROUP")"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-aoe-loot" acore_world \
            "$AC_DIR/modules/mod-aoe-loot/data/sql/db-world"
    fi
fi

# ── mod-quest-loot-party (SP04) ──────────────────────────────────────────────
if [ "${INSTALL_MOD_QUEST_LOOT_PARTY:-false}" = true ]; then
    if install_module_conf "mod-quest-loot-party" "mod-quest-loot-party.conf"; then
        CONF="$MOD_CONF_DIR/mod-quest-loot-party.conf"
        set_conf_value "$CONF" "QuestParty.Enable" "$(bool_to_int "${QUEST_LOOT_PARTY_ENABLE:-true}")"
        set_conf_value "$CONF" "QuestParty.Message" "$(bool_to_int "${QUEST_LOOT_PARTY_MESSAGE:-false}")"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-quest-loot-party" acore_world \
            "$AC_DIR/modules/mod-quest-loot-party/data/sql/db-world"
    fi
fi

# ── mod-instance-reset ────────────────────────────────────────────────────────
# ⚠️ El módulo viene GRATIS de fábrica (TransactionType = 0). Reiniciar sin coste
#    permite granjear la misma raid en bucle y se carga el ritmo de progresión,
#    así que el instalador cobra por defecto (ver INSTANCE_RESET_* en config.sh).
if [ "$INSTALL_MOD_INSTANCE_RESET" = true ]; then
    if install_module_conf "mod-instance-reset" "instance-reset.conf"; then
        CONF="$MOD_CONF_DIR/instance-reset.conf"
        set_conf_value "$CONF" "instanceReset.Enable"          "true"
        set_conf_value "$CONF" "instanceReset.TransactionType" "$INSTANCE_RESET_PAYMENT"
        set_conf_value "$CONF" "instanceReset.MoneyCount"      "$INSTANCE_RESET_MONEY"
        set_conf_value "$CONF" "instanceReset.TokenID"         "$INSTANCE_RESET_TOKEN_ID"
        set_conf_value "$CONF" "instanceReset.TokenCount"      "$INSTANCE_RESET_TOKEN_COUNT"
        set_conf_value "$CONF" "instanceReset.NormalModeOnly"  "$INSTANCE_RESET_NORMAL_ONLY"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-instance-reset" acore_world \
            "$AC_DIR/modules/mod-instance-reset/data/sql/db-world"
    fi
fi

# ── mod-1v1-arena ─────────────────────────────────────────────────────────────
# OJO: sólo se aplica el SQL de db-world. El módulo trae además un
# data/sql/delete/ que DESINSTALA el módulo; apuntar apply_sql_dir a db-world lo
# deja fuera por construcción.
if [ "$INSTALL_MOD_1V1_ARENA" = true ]; then
    if install_module_conf "mod-1v1-arena" "1v1arena.conf"; then
        CONF="$MOD_CONF_DIR/1v1arena.conf"
        set_conf_value "$CONF" "Arena1v1.Enable"           "1"
        set_conf_value "$CONF" "Arena1v1.MinLevel"         "$ARENA_1V1_MIN_LEVEL"
        set_conf_value "$CONF" "Arena1v1.Costs"            "$ARENA_1V1_COST"
        set_conf_value "$CONF" "Arena1v1.ArenaPointsMulti" "$ARENA_1V1_POINTS_MULT"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-1v1-arena" acore_world \
            "$AC_DIR/modules/mod-1v1-arena/data/sql/db-world"
    fi
fi

# ── mod-queue-bots (módulo propio) ────────────────────────────────────────────
# Rellena con bots la cola en la que te pones: 1c1, campo de batalla, arena,
# mazmorra o banda. Es lo que hace jugable el contenido de grupo jugando solo.
if [ "${INSTALL_MOD_QUEUE_BOTS:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-queue-bots] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-queue-bots" "mod_queue_bots.conf"; then
        CONF="$MOD_CONF_DIR/mod_queue_bots.conf"
        set_conf_value "$CONF" "QueueBots.Enable"            "1"
        set_conf_value "$CONF" "QueueBots.Arena1v1"          "$(bool_to_int "$INSTALL_MOD_1V1_ARENA")"
        set_conf_value "$CONF" "QueueBots.Battlegrounds"     "1"
        set_conf_value "$CONF" "QueueBots.Arenas"            "1"
        set_conf_value "$CONF" "QueueBots.Dungeons"          "1"
        set_conf_value "$CONF" "QueueBots.RaidBrowser"       "1"
        set_conf_value "$CONF" "QueueBots.Delay"             "${QUEUE_BOTS_DELAY:-0}"
        set_conf_value "$CONF" "QueueBots.ScanIntervalMs"    "${QUEUE_BOTS_SCAN_INTERVAL_MS:-2000}"
        set_conf_value "$CONF" "QueueBots.ClassVariety"      "$(bool_to_int "${QUEUE_BOTS_CLASS_VARIETY:-true}")"
        set_conf_value "$CONF" "QueueBots.BattlegroundFillToFull" "$(bool_to_int "${QUEUE_BOTS_BG_FILL_TO_FULL:-false}")"
        set_conf_value "$CONF" "QueueBots.Backfill"          "$(bool_to_int "${QUEUE_BOTS_BACKFILL:-true}")"
        set_conf_value "$CONF" "QueueBots.BackfillIntervalSecs" "${QUEUE_BOTS_BACKFILL_INTERVAL_SECS:-20}"
        set_conf_value "$CONF" "QueueBots.BackfillGiveUpSecs" "${QUEUE_BOTS_BACKFILL_GIVE_UP_SECS:-45}"
        set_conf_value "$CONF" "QueueBots.Announce"          "1"
        set_conf_value "$CONF" "QueueBots.ForceAccept"       "1"
        set_conf_value "$CONF" "QueueBots.ForceAcceptAfter"  "${QUEUE_BOTS_FORCE_ACCEPT_AFTER:-40}"
        set_conf_value "$CONF" "QueueBots.MaxRaidBots"       "${QUEUE_BOTS_MAX_RAID:-39}"
        set_conf_value "$CONF" "QueueBots.RaidSize"          "${QUEUE_BOTS_RAID_SIZE:-0}"
        set_conf_value "$CONF" "QueueBots.RaidTanks"         "${QUEUE_BOTS_RAID_TANKS:-0}"
        set_conf_value "$CONF" "QueueBots.RaidHealers"       "${QUEUE_BOTS_RAID_HEALERS:-0}"
        set_conf_value "$CONF" "QueueBots.RaidSummonDelay"   "${QUEUE_BOTS_RAID_SUMMON_DELAY:-8}"
        set_conf_value "$CONF" "QueueBots.RaidSummonGiveUpSecs" "${QUEUE_BOTS_RAID_SUMMON_GIVE_UP_SECS:-60}"
        # Activar mod-dungeon-clear solo cuando el grupo del buscador está dentro.
        if [ "${INSTALL_MOD_DUNGEON_CLEAR:-false}" = true ]; then
            set_conf_value "$CONF" "QueueBots.DungeonClearAuto"  "$(bool_to_int "${QUEUE_BOTS_DUNGEON_CLEAR_AUTO:-true}")"
        else
            set_conf_value "$CONF" "QueueBots.DungeonClearAuto"  "0"
        fi
        set_conf_value "$CONF" "QueueBots.DungeonClearDelay" "${QUEUE_BOTS_DUNGEON_CLEAR_DELAY:-10}"
        set_conf_value "$CONF" "QueueBots.DungeonClearTries" "${QUEUE_BOTS_DUNGEON_CLEAR_TRIES:-3}"
        set_conf_value "$CONF" "QueueBots.DungeonClearReviveDelay" "${QUEUE_BOTS_DUNGEON_CLEAR_REVIVE_DELAY:-8}"
        set_conf_value "$CONF" "QueueBots.DungeonTanks"      "${QUEUE_BOTS_DUNGEON_TANKS:-1}"
        set_conf_value "$CONF" "QueueBots.DungeonHealers"    "${QUEUE_BOTS_DUNGEON_HEALERS:-1}"
        set_conf_value "$CONF" "QueueBots.DungeonDamage"     "${QUEUE_BOTS_DUNGEON_DAMAGE:-3}"
        set_conf_value "$CONF" "QueueBots.WakeBots"          "$(bool_to_int "${QUEUE_BOTS_WAKE:-true}")"
        set_conf_value "$CONF" "QueueBots.WakeMax"           "${QUEUE_BOTS_WAKE_MAX:-40}"
        set_conf_value "$CONF" "QueueBots.WakeCooldownSecs"  "${QUEUE_BOTS_WAKE_COOLDOWN_SECS:-15}"
        # Equipo de los bots al entrar en tu grupo: a tu media y a tu fase.
        set_conf_value "$CONF" "QueueBots.GearMode"          "${QUEUE_BOTS_GEAR_MODE:-1}"
        set_conf_value "$CONF" "QueueBots.GearMargin"        "${QUEUE_BOTS_GEAR_MARGIN:-6}"
        set_conf_value "$CONF" "QueueBots.GearTolerance"     "${QUEUE_BOTS_GEAR_TOLERANCE:-8}"
        set_conf_value "$CONF" "QueueBots.GearMinItemLevel"  "${QUEUE_BOTS_GEAR_MIN_ILVL:-0}"
        # Canje de tokens tras cada jefe, si mod-token-turnin está instalado.
        if [ "${INSTALL_MOD_TOKEN_TURNIN:-false}" = true ]; then
            set_conf_value "$CONF" "QueueBots.TokenTurnIn"   "$(bool_to_int "${QUEUE_BOTS_TOKEN_TURNIN:-true}")"
        else
            set_conf_value "$CONF" "QueueBots.TokenTurnIn"   "0"
        fi
        set_conf_value "$CONF" "QueueBots.TokenTurnInDelay"  "${QUEUE_BOTS_TOKEN_TURNIN_DELAY:-90}"

        if [ "$BOTS_AUTO_JOIN_BG" = true ]; then
            warn "[mod-queue-bots] BOTS_AUTO_JOIN_BG=true a la vez que este módulo:"
            warn "  el auto-apuntado a ciegas de playerbots reparte los bots entre 24"
            warn "  batallas y no llena ninguna. Ponlo a false en config.sh."
        fi
    fi
fi

# ── mod-dungeon-clear ─────────────────────────────────────────────────────────
# El tanque bot lleva la mazmorra. Sus claves admiten sufijo .Heroic y .Raid;
# aquí sólo se fijan las que deciden cómo trata al jugador humano.
if [ "${INSTALL_MOD_DUNGEON_CLEAR:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-dungeon-clear] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-dungeon-clear" "mod_dungeon_clear.conf"; then
        CONF="$MOD_CONF_DIR/mod_dungeon_clear.conf"
        set_conf_value "$CONF" "DungeonClear.Enable"                 "1"
        set_conf_value "$CONF" "DungeonClear.WaitAtBoss"             "$(bool_to_int "${DUNGEON_CLEAR_WAIT_AT_BOSS:-false}")"
        set_conf_value "$CONF" "DungeonClear.SmartRest"              "$(bool_to_int "${DUNGEON_CLEAR_SMART_REST:-false}")"
        set_conf_value "$CONF" "DungeonClear.PostCombatRezTimeoutSecs" "${DUNGEON_CLEAR_REZ_TIMEOUT:-180}"
    fi
fi

# ── mod-world-bots (módulo propio) ────────────────────────────────────────────
# Que la zona en la que estás no esté vacía: trae bots de tu tramo de nivel a
# puntos de caza de tu zona, lejos de ti, y repone mientras sigues allí.
if [ "${INSTALL_MOD_WORLD_BOTS:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-world-bots] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-world-bots" "mod_world_bots.conf"; then
        CONF="$MOD_CONF_DIR/mod_world_bots.conf"
        set_conf_value "$CONF" "WorldBots.Enable"               "1"
        set_conf_value "$CONF" "WorldBots.MinBots"              "${WORLD_BOTS_MIN:-12}"
        set_conf_value "$CONF" "WorldBots.MaxBots"              "${WORLD_BOTS_MAX:-25}"
        set_conf_value "$CONF" "WorldBots.LevelBelow"           "${WORLD_BOTS_LEVEL_BELOW:-5}"
        set_conf_value "$CONF" "WorldBots.LevelAbove"           "${WORLD_BOTS_LEVEL_ABOVE:-3}"
        set_conf_value "$CONF" "WorldBots.MinDistance"          "${WORLD_BOTS_MIN_DISTANCE:-250}"
        set_conf_value "$CONF" "WorldBots.OppositeFactionShare" "${WORLD_BOTS_OPPOSITE_SHARE:-0.35}"
        set_conf_value "$CONF" "WorldBots.MaxPerPass"           "${WORLD_BOTS_MAX_PER_PASS:-5}"
        set_conf_value "$CONF" "WorldBots.MaxTeleportsPerPass"  "${WORLD_BOTS_MAX_TELEPORTS_PER_PASS:-10}"
        set_conf_value "$CONF" "WorldBots.TopUpSeconds"         "${WORLD_BOTS_TOPUP_SECONDS:-60}"
        set_conf_value "$CONF" "WorldBots.WakeBots"             "$(bool_to_int "${WORLD_BOTS_WAKE:-true}")"
        set_conf_value "$CONF" "WorldBots.WakeMax"              "${WORLD_BOTS_WAKE_MAX:-20}"
        set_conf_value "$CONF" "WorldBots.BotMinWorldSeconds"    "${WORLD_BOTS_MIN_WORLD_SECONDS:-60}"
        set_conf_value "$CONF" "WorldBots.Announce"             "$(bool_to_int "${WORLD_BOTS_ANNOUNCE:-false}")"
        set_conf_value "$CONF" "WorldBots.Verbose"              "$(bool_to_int "${WORLD_BOTS_VERBOSE:-false}")"
        set_conf_value "$CONF" "WorldBots.NearbyPlayerRadius"   "${WORLD_BOTS_NEARBY_PLAYER_RADIUS:-150}"
        set_conf_value "$CONF" "WorldBots.WakeBatchSeconds"     "${WORLD_BOTS_WAKE_BATCH_SECONDS:-15}"
        set_conf_value "$CONF" "WorldBots.ZoneSettleSeconds"    "${WORLD_BOTS_ZONE_SETTLE_SECONDS:-2}"
        set_conf_value "$CONF" "WorldBots.RetrySeconds"         "${WORLD_BOTS_RETRY_SECONDS:-15}"
        set_conf_value "$CONF" "WorldBots.AdaptiveDensity"          "$(bool_to_int "${WORLD_BOTS_ADAPTIVE_DENSITY:-false}")"
        set_conf_value "$CONF" "WorldBots.AdaptiveDensityPerHuman"  "${WORLD_BOTS_ADAPTIVE_DENSITY_PER_HUMAN:-4}"
        set_conf_value "$CONF" "WorldBots.AdaptiveDensityMax"       "${WORLD_BOTS_ADAPTIVE_DENSITY_MAX:-0}"
        set_conf_value "$CONF" "WorldBots.Samaritan"                "$(bool_to_int "${WORLD_BOTS_SAMARITAN:-false}")"
        set_conf_value "$CONF" "WorldBots.SamaritanHpPercent"       "${WORLD_BOTS_SAMARITAN_HP_PERCENT:-35}"
        set_conf_value "$CONF" "WorldBots.SamaritanRadius"          "${WORLD_BOTS_SAMARITAN_RADIUS:-45}"
        set_conf_value "$CONF" "WorldBots.SamaritanMaxHelpers"      "${WORLD_BOTS_SAMARITAN_MAX_HELPERS:-2}"
        set_conf_value "$CONF" "WorldBots.SamaritanCooldownSeconds" "${WORLD_BOTS_SAMARITAN_COOLDOWN_SECONDS:-120}"
        set_conf_value "$CONF" "WorldBots.SamaritanDurationSeconds" "${WORLD_BOTS_SAMARITAN_DURATION_SECONDS:-45}"
        set_conf_value "$CONF" "WorldBots.SamaritanLevelBelow"      "${WORLD_BOTS_SAMARITAN_LEVEL_BELOW:-3}"
        set_conf_value "$CONF" "WorldBots.SamaritanLevelAbove"      "${WORLD_BOTS_SAMARITAN_LEVEL_ABOVE:-8}"
        set_conf_value "$CONF" "BotPopulation.PendingTimeoutSeconds" "${BOT_POPULATION_PENDING_TIMEOUT_SECONDS:-90}"
        set_conf_value "$CONF" "BotPopulation.MaxPendingTotal"      "${BOT_POPULATION_MAX_PENDING_TOTAL:-40}"
        set_conf_value "$CONF" "BotPopulation.MaxPendingPerFaction" "${BOT_POPULATION_MAX_PENDING_PER_FACTION:-24}"
        set_conf_value "$CONF" "BotPopulation.MaxPendingPerRange"   "${BOT_POPULATION_MAX_PENDING_PER_RANGE:-12}"
        set_conf_value "$CONF" "WorldBots.CityMinBots"          "${WORLD_BOTS_CITY_MIN:-30}"
        set_conf_value "$CONF" "WorldBots.CityMaxBots"          "${WORLD_BOTS_CITY_MAX:-50}"
        set_conf_value "$CONF" "WorldBots.CityMinDistance"      "${WORLD_BOTS_CITY_MIN_DISTANCE:-150}"
        # Etapas (individual-progression): poblar solo hasta el tope de la etapa del jugador mas avanzado
        set_conf_value "$CONF" "WorldBots.Stage.Enable"         "$(bool_to_int "${WORLD_BOTS_STAGE:-true}")"
        set_conf_value "$CONF" "WorldBots.Stage.TbcFrom"        "${WORLD_BOTS_STAGE_TBC_FROM:-8}"
        set_conf_value "$CONF" "WorldBots.Stage.WotlkFrom"      "${WORLD_BOTS_STAGE_WOTLK_FROM:-13}"
        set_conf_value "$CONF" "WorldBots.Stage.VanillaCap"     "${WORLD_BOTS_STAGE_VANILLA_CAP:-60}"
        set_conf_value "$CONF" "WorldBots.Stage.VanillaMaps"    "\"${WORLD_BOTS_STAGE_VANILLA_MAPS:-0,1}\""
        set_conf_value "$CONF" "WorldBots.Stage.TbcCap"         "${WORLD_BOTS_STAGE_TBC_CAP:-70}"
        set_conf_value "$CONF" "WorldBots.Stage.TbcMaps"        "\"${WORLD_BOTS_STAGE_TBC_MAPS:-0,1,530}\""
        set_conf_value "$CONF" "WorldBots.Stage.PerPass"        "${WORLD_BOTS_STAGE_PER_PASS:-3}"
        set_conf_value "$CONF" "WorldBots.Stage.SyncSeconds"     "${WORLD_BOTS_STAGE_SYNC_SECONDS:-60}"
        # Escalado de poblacion por jugador conectado: pisa Playerbots.MinRandomBots/
        # MaxRandomBots en caliente (BOTS_MIN/BOTS_MAX de mas arriba quedan como el
        # valor de arranque y el que se restaura si esto se desactiva).
        set_conf_value "$CONF" "WorldBots.PlayerScale.Enable"      "$(bool_to_int "${BOTS_PER_PLAYER_SCALE:-false}")"
        set_conf_value "$CONF" "WorldBots.PlayerScale.PerPlayer"   "${BOTS_PER_PLAYER:-150}"
        set_conf_value "$CONF" "WorldBots.PlayerScale.Ceiling"     "${BOTS_PER_PLAYER_CEILING:-600}"
        set_conf_value "$CONF" "WorldBots.PlayerScale.SyncSeconds" "${BOTS_PER_PLAYER_SYNC_SECONDS:-60}"
        # Guerra de mundo: escaramuzas y duelos en puntos calientes.
        set_conf_value "$CONF" "WorldBots.Pvp.Enable"               "$(bool_to_int "${WORLD_BOTS_PVP:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.TickSeconds"          "${WORLD_BOTS_PVP_TICK_SECONDS:-60}"
        set_conf_value "$CONF" "WorldBots.Pvp.EventChancePerTick"   "${WORLD_BOTS_PVP_CHANCE:-25}"
        set_conf_value "$CONF" "WorldBots.Pvp.MaxActiveEvents"      "${WORLD_BOTS_PVP_MAX_ACTIVE:-1}"
        set_conf_value "$CONF" "WorldBots.Pvp.OnlyWithPlayerInZone" "$(bool_to_int "${WORLD_BOTS_PVP_ONLY_WITH_PLAYER:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.MinLevel"             "${WORLD_BOTS_PVP_MIN_LEVEL:-20}"
        set_conf_value "$CONF" "WorldBots.Pvp.MaxBotsPerSide"       "${WORLD_BOTS_PVP_MAX_PER_SIDE:-8}"
        set_conf_value "$CONF" "WorldBots.Pvp.MoveDelaySeconds"     "${WORLD_BOTS_PVP_MOVE_DELAY:-15}"
        set_conf_value "$CONF" "WorldBots.Pvp.MinBotsToStart"       "${WORLD_BOTS_PVP_MIN_BOTS_TO_START:-2}"
        set_conf_value "$CONF" "WorldBots.Pvp.KeepAwayDistance"     "${WORLD_BOTS_PVP_KEEP_AWAY_DISTANCE:-160}"
        set_conf_value "$CONF" "WorldBots.Pvp.RepositionDistance"   "${WORLD_BOTS_PVP_REPOSITION_DISTANCE:-200}"
        set_conf_value "$CONF" "WorldBots.Pvp.NearbyPlayerRadius"   "${WORLD_BOTS_PVP_NEARBY_PLAYER_RADIUS:-150}"
        set_conf_value "$CONF" "WorldBots.Pvp.CombatGraceSeconds"   "${WORLD_BOTS_PVP_COMBAT_GRACE_SECONDS:-60}"
        set_conf_value "$CONF" "WorldBots.Pvp.DuelRange"            "${WORLD_BOTS_PVP_DUEL_RANGE:-35}"
        set_conf_value "$CONF" "WorldBots.Pvp.DuelMaxTries"         "${WORLD_BOTS_PVP_DUEL_MAX_TRIES:-20}"
        set_conf_value "$CONF" "WorldBots.Pvp.Duels"                "$(bool_to_int "${WORLD_BOTS_PVP_DUELS:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.DuelPairs"            "${WORLD_BOTS_PVP_DUEL_PAIRS:-4}"
        set_conf_value "$CONF" "WorldBots.Pvp.Announce"             "$(bool_to_int "${WORLD_BOTS_PVP_ANNOUNCE:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.AutoEnableHighHotspots" "$(bool_to_int "${WORLD_BOTS_PVP_AUTO_ENABLE_HIGH_HOTSPOTS:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.CaptureObjective"     "$(bool_to_int "${WORLD_BOTS_PVP_CAPTURE_OBJECTIVE:-true}")"
        set_conf_value "$CONF" "WorldBots.Pvp.CaptureRadius"        "${WORLD_BOTS_PVP_CAPTURE_RADIUS:-40}"
        set_conf_value "$CONF" "WorldBots.Pvp.CaptureGoal"          "${WORLD_BOTS_PVP_CAPTURE_GOAL:-10}"
        set_conf_value "$CONF" "WorldBots.Pvp.GearMode"             "${WORLD_BOTS_PVP_GEAR_MODE:-1}"
        set_conf_value "$CONF" "WorldBots.Pvp.GearMargin"           "${WORLD_BOTS_PVP_GEAR_MARGIN:-6}"
        set_conf_value "$CONF" "WorldBots.Pvp.GearTolerance"        "${WORLD_BOTS_PVP_GEAR_TOLERANCE:-8}"
        set_conf_value "$CONF" "WorldBots.Pvp.GearMinItemLevel"     "${WORLD_BOTS_PVP_GEAR_MIN_ILVL:-0}"
        # La tabla de puntos calientes (acore_world), idempotente.
        if db_exists acore_world; then
            apply_sql_dir "mod-world-bots (puntos calientes)" acore_world \
                "$AC_DIR/modules/mod-world-bots/data/sql/db-world"
        else
            warn "[mod-world-bots] acore_world no existe todavia: los puntos calientes se cargan con '--only 5' o '--post'."
        fi
    fi
fi

# ── mod-quest-mates (módulo propio) ───────────────────────────────────────────
# Compañeros de misión: al aceptar una misión, bots de tu zona la cogen también.
if [ "${INSTALL_MOD_QUEST_MATES:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-quest-mates] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-quest-mates" "mod_quest_mates.conf"; then
        CONF="$MOD_CONF_DIR/mod_quest_mates.conf"
        set_conf_value "$CONF" "QuestMates.Enable"          "1"
        set_conf_value "$CONF" "QuestMates.MinMates"        "${QUEST_MATES_MIN:-2}"
        set_conf_value "$CONF" "QuestMates.MaxMates"        "${QUEST_MATES_MAX:-3}"
        set_conf_value "$CONF" "QuestMates.LevelBelow"      "${QUEST_MATES_LEVEL_BELOW:-5}"
        set_conf_value "$CONF" "QuestMates.LevelAbove"      "${QUEST_MATES_LEVEL_ABOVE:-3}"
        set_conf_value "$CONF" "QuestMates.Chance"          "${QUEST_MATES_CHANCE:-100}"
        set_conf_value "$CONF" "QuestMates.RememberMinutes" "${QUEST_MATES_REMEMBER_MINUTES:-30}"
        set_conf_value "$CONF" "QuestMates.Announce"        "$(bool_to_int "${QUEST_MATES_ANNOUNCE:-false}")"
        set_conf_value "$CONF" "QuestMates.RpgStrategyPush" "$(bool_to_int "${QUEST_MATES_RPG_STRATEGY_PUSH:-true}")"
        set_conf_value "$CONF" "QuestMates.MaxMatesTracked" "${QUEST_MATES_MAX_MATES_TRACKED:-6}"
        set_conf_value "$CONF" "QuestMates.CleanupIntervalMs" "${QUEST_MATES_CLEANUP_INTERVAL_MS:-3000}"
        set_conf_value "$CONF" "QuestMates.Debug"           "$(bool_to_int "${QUEST_MATES_DEBUG:-false}")"
        set_conf_value "$CONF" "QuestMates.StuckMinutes"    "${QUEST_MATES_STUCK_MINUTES:-0}"
        set_conf_value "$CONF" "QuestMates.AbandonStuck"    "$(bool_to_int "${QUEST_MATES_ABANDON_STUCK:-false}")"
        set_conf_value "$CONF" "QuestMates.FollowAbandon"   "$(bool_to_int "${QUEST_MATES_FOLLOW_ABANDON:-true}")"
        set_conf_value "$CONF" "QuestMates.PreferHomeGuild" "$(bool_to_int "${QUEST_MATES_PREFER_HOME_GUILD:-true}")"
        set_conf_value "$CONF" "QuestMates.JointTurnIn"     "$(bool_to_int "${QUEST_MATES_JOINT_TURN_IN:-true}")"
        set_conf_value "$CONF" "QuestMates.TransitionGraceSeconds" "${QUEST_MATES_TRANSITION_GRACE_SECONDS:-60}"
    fi
fi

# ── mod-party-here (módulo propio) ────────────────────────────────────────────
# Grupo donde estás, sin cola: ".grupo" y misiones de grupo en automático.
if [ "${INSTALL_MOD_PARTY_HERE:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-party-here] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-party-here" "mod_party_here.conf"; then
        CONF="$MOD_CONF_DIR/mod_party_here.conf"
        set_conf_value "$CONF" "PartyHere.Enable"            "1"
        set_conf_value "$CONF" "PartyHere.LevelBelow"        "${PARTY_HERE_LEVEL_BELOW:-3}"
        set_conf_value "$CONF" "PartyHere.LevelAbove"        "${PARTY_HERE_LEVEL_ABOVE:-0}"
        set_conf_value "$CONF" "PartyHere.MaxRaidBots"       "${PARTY_HERE_MAX_RAID_BOTS:-39}"
        set_conf_value "$CONF" "PartyHere.AutoGroupQuests"   "$(bool_to_int "${PARTY_HERE_AUTO_GROUP_QUESTS:-true}")"
        set_conf_value "$CONF" "PartyHere.AutoMaxBots"       "${PARTY_HERE_AUTO_MAX_BOTS:-2}"
        set_conf_value "$CONF" "PartyHere.AutoLingerSeconds" "${PARTY_HERE_AUTO_LINGER_SECONDS:-120}"
        set_conf_value "$CONF" "PartyHere.SyncQuestsToGroup" "$(bool_to_int "${PARTY_HERE_SYNC_QUESTS_TO_GROUP:-true}")"
        set_conf_value "$CONF" "PartyHere.DismissAutoOnZoneChange" "$(bool_to_int "${PARTY_HERE_DISMISS_AUTO_ON_ZONE_CHANGE:-false}")"
        set_conf_value "$CONF" "PartyHere.SummonDelay"       "${PARTY_HERE_SUMMON_DELAY:-3}"
        set_conf_value "$CONF" "PartyHere.SummonRetrySeconds"  "${PARTY_HERE_SUMMON_RETRY_SECONDS:-3}"
        set_conf_value "$CONF" "PartyHere.SummonGiveUpSeconds" "${PARTY_HERE_SUMMON_GIVE_UP_SECONDS:-60}"
        set_conf_value "$CONF" "PartyHere.SummonDistance"      "${PARTY_HERE_SUMMON_DISTANCE:-40}"
        set_conf_value "$CONF" "PartyHere.SummonPlaceRadius"   "${PARTY_HERE_SUMMON_PLACE_RADIUS:-4}"
        set_conf_value "$CONF" "PartyHere.ResurrectOnSummon"   "$(bool_to_int "${PARTY_HERE_RESURRECT_ON_SUMMON:-true}")"
        set_conf_value "$CONF" "PartyHere.Replenish"           "$(bool_to_int "${PARTY_HERE_REPLENISH:-true}")"
        set_conf_value "$CONF" "PartyHere.ReplenishThrottleSeconds" "${PARTY_HERE_REPLENISH_THROTTLE_SECONDS:-15}"
        set_conf_value "$CONF" "PartyHere.PersistMinutes"      "${PARTY_HERE_PERSIST_MINUTES:-10}"
        set_conf_value "$CONF" "PartyHere.PendingTimeoutSeconds" "${PARTY_HERE_PENDING_TIMEOUT_SECONDS:-180}"
        set_conf_value "$CONF" "PartyHere.PendingRetrySeconds" "${PARTY_HERE_PENDING_RETRY_SECONDS:-5}"
        set_conf_value "$CONF" "PartyHere.PendingWakeSeconds" "${PARTY_HERE_PENDING_WAKE_SECONDS:-45}"
        set_conf_value "$CONF" "PartyHere.RoleWaitSeconds"   "${PARTY_HERE_ROLE_WAIT_SECONDS:-45}"
        set_conf_value "$CONF" "PartyHere.RoleRespec"        "$(bool_to_int "${PARTY_HERE_ROLE_RESPEC:-false}")"
        set_conf_value "$CONF" "PartyHere.RoleLevelAbove"    "${PARTY_HERE_ROLE_LEVEL_ABOVE:-0}"
        set_conf_value "$CONF" "PartyHere.DismissExcludeMinutes" "${PARTY_HERE_DISMISS_EXCLUDE_MINUTES:-10}"
        set_conf_value "$CONF" "PartyHere.ScanIntervalMs"      "${PARTY_HERE_SCAN_INTERVAL_MS:-3000}"
        set_conf_value "$CONF" "PartyHere.MaxGroupBots"        "${PARTY_HERE_MAX_GROUP_BOTS:-0}"
        set_conf_value "$CONF" "PartyHere.Tanks"               "${PARTY_HERE_TANKS:-0}"
        set_conf_value "$CONF" "PartyHere.Healers"             "${PARTY_HERE_HEALERS:-0}"
        set_conf_value "$CONF" "PartyHere.AutoQuestMinSuggested" "${PARTY_HERE_AUTO_QUEST_MIN_SUGGESTED:-0}"
        set_conf_value "$CONF" "PartyHere.AnnounceErrors"      "$(bool_to_int "${PARTY_HERE_ANNOUNCE_ERRORS:-true}")"
        set_conf_value "$CONF" "PartyHere.WakeThrottleSeconds" "${PARTY_HERE_WAKE_THROTTLE_SECONDS:-15}"
        set_conf_value "$CONF" "PartyHere.WakeBots"          "$(bool_to_int "${PARTY_HERE_WAKE:-true}")"
        set_conf_value "$CONF" "PartyHere.WakeMax"           "${PARTY_HERE_WAKE_MAX:-20}"
        set_conf_value "$CONF" "PartyHere.BotMinWorldSeconds" "${PARTY_HERE_MIN_WORLD_SECONDS:-60}"
        set_conf_value "$CONF" "PartyHere.Announce"          "$(bool_to_int "${PARTY_HERE_ANNOUNCE:-true}")"
        set_conf_value "$CONF" "PartyHere.LoadGraceSeconds"  "${PARTY_HERE_LOAD_GRACE_SECONDS:-30}"
        set_conf_value "$CONF" "PartyHere.GearMode"          "${PARTY_HERE_GEAR_MODE:-1}"
        set_conf_value "$CONF" "PartyHere.GearMargin"        "${PARTY_HERE_GEAR_MARGIN:-6}"
        set_conf_value "$CONF" "PartyHere.GearTolerance"     "${PARTY_HERE_GEAR_TOLERANCE:-8}"
        set_conf_value "$CONF" "PartyHere.GearMinItemLevel"  "${PARTY_HERE_GEAR_MIN_ILVL:-0}"
    fi
fi

# ── mod-home-guild (módulo propio) ────────────────────────────────────────────
# Tu hermandad: sólo se gestiona después de que el jugador la cree en el juego.
if [ "${INSTALL_MOD_HOME_GUILD:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-home-guild] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-home-guild" "mod_home_guild.conf"; then
        CONF="$MOD_CONF_DIR/mod_home_guild.conf"
        # Ojo: el valor por defecto lleva llaves, y "${VAR:-... {name}}" corta
        # la expansión en la primera "}" (salía "{name}}"). Por eso va aparte.
        HG_NAME="${HOME_GUILD_LEGACY_NAME:-${HOME_GUILD_NAME:-}}"
        [ -n "$HG_NAME" ] || HG_NAME='Companeros de {name}'
        HG_MOTD="${HOME_GUILD_LEGACY_MOTD:-${HOME_GUILD_MOTD:-Bienvenido a casa.}}"
        set_conf_value "$CONF" "HomeGuild.Enable"        "1"
        set_conf_value "$CONF" "HomeGuild.LegacyName"    "\"${HG_NAME}\""
        set_conf_value "$CONF" "HomeGuild.LegacyMotd"    "\"${HG_MOTD}\""
        set_conf_value "$CONF" "HomeGuild.CleanupLegacyAutoGuilds" "$(bool_to_int "${HOME_GUILD_CLEANUP_LEGACY:-true}")"
        set_conf_value "$CONF" "HomeGuild.Members"       "${HOME_GUILD_MEMBERS:-15}"
        set_conf_value "$CONF" "HomeGuild.LevelBelow"    "${HOME_GUILD_LEVEL_BELOW:-3}"
        set_conf_value "$CONF" "HomeGuild.LevelAbove"    "${HOME_GUILD_LEVEL_ABOVE:-2}"
        set_conf_value "$CONF" "HomeGuild.KeepOnline"    "$(bool_to_int "${HOME_GUILD_KEEP_ONLINE:-true}")"
        set_conf_value "$CONF" "HomeGuild.ReLevel"       "$(bool_to_int "${HOME_GUILD_RELEVEL:-true}")"
        set_conf_value "$CONF" "HomeGuild.ReLevelBehind" "${HOME_GUILD_RELEVEL_BEHIND:-4}"
        set_conf_value "$CONF" "HomeGuild.Announce"      "$(bool_to_int "${HOME_GUILD_ANNOUNCE:-true}")"
        set_conf_value "$CONF" "HomeGuild.AnnounceWhenGuildless" "$(bool_to_int "${HOME_GUILD_ANNOUNCE_WHEN_GUILDLESS:-true}")"
        set_conf_value "$CONF" "HomeGuild.AutoAdopt"     "$(bool_to_int "${HOME_GUILD_AUTO_ADOPT:-true}")"
        set_conf_value "$CONF" "HomeGuild.InactiveOwnerReclaimDays" "${HOME_GUILD_INACTIVE_RECLAIM_DAYS:-30}"
        set_conf_value "$CONF" "HomeGuild.CareIntervalSeconds"        "${HOME_GUILD_CARE_INTERVAL_SECONDS:-30}"
        set_conf_value "$CONF" "HomeGuild.RecruitBackoffSeconds"      "${HOME_GUILD_RECRUIT_BACKOFF_SECONDS:-300}"
        set_conf_value "$CONF" "HomeGuild.KeepOnlineIntervalSeconds"  "${HOME_GUILD_KEEP_ONLINE_INTERVAL_SECONDS:-15}"
        set_conf_value "$CONF" "HomeGuild.KeepOnlineBatch"            "${HOME_GUILD_KEEP_ONLINE_BATCH:-5}"
        set_conf_value "$CONF" "HomeGuild.MaxOnlineBots"              "${HOME_GUILD_MAX_ONLINE_BOTS:-0}"
        set_conf_value "$CONF" "HomeGuild.ReLevelPerPass"             "${HOME_GUILD_RELEVEL_PER_PASS:-1}"
        set_conf_value "$CONF" "HomeGuild.ReLevelTargetJitter"        "${HOME_GUILD_RELEVEL_TARGET_JITTER:-0}"
        set_conf_value "$CONF" "HomeGuild.ReLevelMinWorldSeconds"     "${HOME_GUILD_RELEVEL_MIN_WORLD_SECONDS:-60}"
        set_conf_value "$CONF" "HomeGuild.RecruitFromOfflinePool"     "$(bool_to_int "${HOME_GUILD_RECRUIT_FROM_OFFLINE_POOL:-true}")"
        set_conf_value "$CONF" "HomeGuild.AllianceRaces"              "\"${HOME_GUILD_ALLIANCE_RACES:-1,3,4,7,11}\""
        set_conf_value "$CONF" "HomeGuild.HordeRaces"                 "\"${HOME_GUILD_HORDE_RACES:-2,5,6,8,10}\""
        set_conf_value "$CONF" "HomeGuild.LegacyNumberMax"            "${HOME_GUILD_LEGACY_NUMBER_MAX:-100}"
        set_conf_value "$CONF" "HomeGuild.Tanks"                      "${HOME_GUILD_TANKS:-0}"
        set_conf_value "$CONF" "HomeGuild.Healers"                    "${HOME_GUILD_HEALERS:-0}"
        set_conf_value "$CONF" "HomeGuild.GearMode"                   "${HOME_GUILD_GEAR_MODE:-1}"
        set_conf_value "$CONF" "HomeGuild.GearMargin"                 "${HOME_GUILD_GEAR_MARGIN:-6}"
        set_conf_value "$CONF" "HomeGuild.GearTolerance"              "${HOME_GUILD_GEAR_TOLERANCE:-8}"
        set_conf_value "$CONF" "HomeGuild.GearMinItemLevel"           "${HOME_GUILD_GEAR_MIN_ILVL:-0}"
        set_conf_value "$CONF" "HomeGuild.GearIntervalSeconds"        "${HOME_GUILD_GEAR_INTERVAL_SECONDS:-120}"

        # La marca persistente decide qué guilds pertenecen al módulo. El
        # actualizador del core también aplica este directorio al arrancar.
        if db_exists acore_characters; then
            apply_sql_dir "mod-home-guild (propiedad)" acore_characters \
                "$AC_DIR/modules/mod-home-guild/data/sql/db-characters"
        else
            warn "[mod-home-guild] acore_characters no existe todavía: las tablas se cargarán al arrancar."
        fi

    fi
fi

# ── mod-bot-operations (módulo propio) ────────────────────────────────────────
# Puente entre modules/shared/BotOperations.h y acore_world para el panel web.
# No depende de mod-playerbots directamente (lee lo que los demás módulos
# publiquen, aunque alguno esté apagado): sólo se salta la configuración si el
# propio módulo está desactivado. BotOperations.Enable se pone a 1 aquí: el
# .conf.dist arranca en 0 (norma "features de riesgo arrancan en 0") y es este
# despliegue el que decide activarlo, dejando el interruptor a mano.
if [ "${INSTALL_MOD_BOT_OPERATIONS:-false}" = true ]; then
    if install_module_conf "mod-bot-operations" "mod_bot_operations.conf"; then
        CONF="$MOD_CONF_DIR/mod_bot_operations.conf"
        set_conf_value "$CONF" "BotOperations.Enable"                  "$(bool_to_int "${BOT_OPERATIONS_ENABLE:-true}")"
        set_conf_value "$CONF" "BotOperations.SnapshotIntervalSeconds" "${BOT_OPERATIONS_SNAPSHOT_INTERVAL_SECONDS:-10}"
        set_conf_value "$CONF" "BotOperations.ActionPollIntervalSeconds" "${BOT_OPERATIONS_ACTION_POLL_INTERVAL_SECONDS:-2}"
        set_conf_value "$CONF" "BotOperations.ActionQueueMax"          "${BOT_OPERATIONS_ACTION_QUEUE_MAX:-20}"
        set_conf_value "$CONF" "BotOperations.ActionMaxAgeSeconds"     "${BOT_OPERATIONS_ACTION_MAX_AGE_SECONDS:-120}"
    fi
    # Tablas (acore_world), idempotente. El actualizador del core también las
    # aplica al arrancar; aquí para que el panel las vea sin esperar a un reinicio.
    if db_exists acore_world; then
        apply_sql_dir "mod-bot-operations (tablas)" acore_world \
            "$AC_DIR/modules/mod-bot-operations/data/sql/db-world"
    else
        warn "[mod-bot-operations] acore_world no existe todavia: las tablas se cargan con '--only 5' o '--post'."
    fi
fi

# ── mod-update-notice (módulo propio) ─────────────────────────────────────────
# Aviso de actualizaciones a los GM al conectarse. Lee updates-pending.txt en
# el directorio del worldserver; lo escribe tools/revisar-actualizaciones.sh.
if [ "${INSTALL_MOD_UPDATE_NOTICE:-false}" = true ]; then
    if install_module_conf "mod-update-notice" "mod_update_notice.conf"; then
        CONF="$MOD_CONF_DIR/mod_update_notice.conf"
        set_conf_value "$CONF" "UpdateNotice.Enable"       "1"
        set_conf_value "$CONF" "UpdateNotice.File"         "\"updates-pending.txt\""
        # Ruta absoluta al versions.lock REAL (no una copia): así el módulo
        # detecta de verdad cuándo el informe quedó desfasado (P8), aunque
        # nadie vuelva a ejecutar tools/revisar-actualizaciones.sh tras un
        # --freeze o una edición a mano. Antes apuntaba a una copia que
        # write_update_report() reescribía en cada comprobación, con lo que
        # su fecha nunca podía quedar por detrás del informe (panel-versions-lock-copia-estatica).
        set_conf_value "$CONF" "UpdateNotice.VersionsLockFile" "\"$INSTALLER_DIR/versions.lock\""
        set_conf_value "$CONF" "UpdateNotice.Severity"     "$(bool_to_int "${UPDATE_NOTICE_SEVERITY:-true}")"
        set_conf_value "$CONF" "UpdateNotice.MinSecurity"  "${UPDATE_NOTICE_MIN_SECURITY:-2}"
        set_conf_value "$CONF" "UpdateNotice.DelaySeconds" "${UPDATE_NOTICE_DELAY_SECONDS:-8}"
        set_conf_value "$CONF" "UpdateNotice.MaxLines"     "${UPDATE_NOTICE_MAX_LINES:-15}"
        set_conf_value "$CONF" "UpdateNotice.MaxDaysStale" "${UPDATE_NOTICE_MAX_DAYS_STALE:-10}"
        set_conf_value "$CONF" "UpdateNotice.OncePerSession" "$(bool_to_int "${UPDATE_NOTICE_ONCE_PER_SESSION:-false}")"
        set_conf_value "$CONF" "UpdateNotice.CommandOnly"    "$(bool_to_int "${UPDATE_NOTICE_COMMAND_ONLY:-false}")"
        set_conf_value "$CONF" "UpdateNotice.SayIfNoneOnLogin" "$(bool_to_int "${UPDATE_NOTICE_SAY_IF_NONE_ON_LOGIN:-false}")"
    fi
fi

# ── mod-arac-trainer-audit (módulo propio) ────────────────────────────────────
# Verificación de los instructores genéricos de mod-arac con los hooks nuevos
# de entrenador del core (OnPlayerAfterTrainSpell, OnPlayerCanLearnSpell,
# 20/09/2026). No añade hechizos ni toca trainer_spell.
if [ "${INSTALL_MOD_ARAC_TRAINER_AUDIT:-false}" = true ]; then
    if install_module_conf "mod-arac-trainer-audit" "mod_arac_trainer_audit.conf"; then
        CONF="$MOD_CONF_DIR/mod_arac_trainer_audit.conf"
        set_conf_value "$CONF" "AracTrainerAudit.Enable"              "1"
        set_conf_value "$CONF" "AracTrainerAudit.LogTrainerPurchases" "$(bool_to_int "${ARAC_TRAINER_AUDIT_LOG_PURCHASES:-true}")"
        set_conf_value "$CONF" "AracTrainerAudit.GuardClassRaceFit"   "$(bool_to_int "${ARAC_TRAINER_AUDIT_GUARD_CLASS_RACE_FIT:-true}")"
        set_conf_value "$CONF" "AracTrainerAudit.RefreshDruidTrainerList" "$(bool_to_int "${ARAC_TRAINER_AUDIT_REFRESH_DRUID_TRAINER_LIST:-false}")"
        set_conf_value "$CONF" "AracTrainerAudit.TraceAccountId" "${ARAC_TRAINER_AUDIT_TRACE_ACCOUNT_ID:-0}"
    fi
fi

# ── mod-standby (módulo propio) ──────────────────────────────────────────────
# Apaga el worldserver cuando lleva STANDBY_IDLE_MINUTES sin jugadores humanos.
# Sigue a WORLDSERVER_STANDBY (INSTALL_MOD_STANDBY se fija en config.sh).
if [ "${INSTALL_MOD_STANDBY:-false}" = true ]; then
    if install_module_conf "mod-standby" "mod_standby.conf"; then
        CONF="$MOD_CONF_DIR/mod_standby.conf"
        set_conf_value "$CONF" "Standby.Enable"                  "1"
        set_conf_value "$CONF" "Standby.IdleMinutes"             "${STANDBY_IDLE_MINUTES:-15}"
        set_conf_value "$CONF" "Standby.WarnSeconds"             "${STANDBY_WARN_SECONDS:-60}"
        set_conf_value "$CONF" "Standby.MinUptimeMinutes"        "${STANDBY_MIN_UPTIME_MINUTES:-10}"
        set_conf_value "$CONF" "Standby.CheckSeconds"            "${STANDBY_CHECK_SECONDS:-30}"
        set_conf_value "$CONF" "Standby.RequireSocketActivation" "1"
    fi
fi

# ── mod-server-help (módulo propio) ───────────────────────────────────────────
# Base de conocimiento del servidor en la pestaña de ayuda del cliente. Sus
# tablas (categorías, artículos, fichas, reglas) van en acore_world.
if [ "${INSTALL_MOD_SERVER_HELP:-false}" = true ]; then
    if install_module_conf "mod-server-help" "mod_server_help.conf"; then
        CONF="$MOD_CONF_DIR/mod_server_help.conf"
        set_conf_value "$CONF" "ServerHelp.Enable"               "1"
        set_conf_value "$CONF" "ServerHelp.MaxSearchResults"     "${SERVER_HELP_MAX_SEARCH_RESULTS:-60}"
        set_conf_value "$CONF" "ServerHelp.CacheSeconds"         "${SERVER_HELP_CACHE_SECONDS:-300}"
        set_conf_value "$CONF" "ServerHelp.IndexCooldownSeconds" "${SERVER_HELP_INDEX_COOLDOWN:-2}"
        set_conf_value "$CONF" "ServerHelp.SnapshotMaxAge"       "${SERVER_HELP_SNAPSHOT_MAX_AGE:-3600}"
        set_conf_value "$CONF" "ServerHelp.SearchQueryMaxBytes"  "${SERVER_HELP_SEARCH_QUERY_MAX_BYTES:-64}"
        set_conf_value "$CONF" "ServerHelp.CommandQueryMaxBytes" "${SERVER_HELP_COMMAND_QUERY_MAX_BYTES:-128}"
        set_conf_value "$CONF" "ServerHelp.RateWindowSeconds"    "${SERVER_HELP_RATE_WINDOW_SECONDS:-20}"
        set_conf_value "$CONF" "ServerHelp.RateMaxPerWindow"     "${SERVER_HELP_RATE_MAX_PER_WINDOW:-20}"
        set_conf_value "$CONF" "ServerHelp.Export"               "$(bool_to_int "${SERVER_HELP_EXPORT:-true}")"
        set_conf_value "$CONF" "ServerHelp.LogRequests"          "$(bool_to_int "${SERVER_HELP_LOG_REQUESTS:-false}")"
        # Tablas y semilla (acore_world), idempotente. El actualizador del core
        # también las aplica al arrancar; aquí para que ".ayuda recargar" ya las vea.
        if db_exists acore_world; then
            apply_sql_dir "mod-server-help (tablas y semilla)" acore_world \
                "$AC_DIR/modules/mod-server-help/data/sql/db-world"
        else
            warn "[mod-server-help] acore_world no existe todavia: las tablas se cargan con '--only 5' o '--post'."
        fi
    fi
fi

# ── mod-treasure (SP03, módulo propio) ───────────────────────────────────────
if [ "${INSTALL_MOD_TREASURE:-false}" = true ]; then
    if install_module_conf "mod-treasure" "mod_treasure.conf"; then
        CONF="$MOD_CONF_DIR/mod_treasure.conf"
        set_conf_value "$CONF" "SPTreasure.Enable" "$(bool_to_int "${TREASURE_ENABLE:-true}")"
        set_conf_value "$CONF" "SPTreasure.LocationSeconds" "${TREASURE_LOCATION_SECONDS:-3600}"
        set_conf_value "$CONF" "SPTreasure.BasicRespawnSeconds" "${TREASURE_BASIC_RESPAWN_SECONDS:-1800}"
        set_conf_value "$CONF" "SPTreasure.RareRespawnSeconds" "${TREASURE_RARE_RESPAWN_SECONDS:-5400}"
        set_conf_value "$CONF" "SPTreasure.EpicRespawnSeconds" "${TREASURE_EPIC_RESPAWN_SECONDS:-14400}"
        set_conf_value "$CONF" "SPTreasure.CandidateRadius" "${TREASURE_CANDIDATE_RADIUS:-250}"
        set_conf_value "$CONF" "SPTreasure.SpawnSpell" "${TREASURE_SPAWN_SPELL:-30262}"
        set_conf_value "$CONF" "SPTreasure.TestSeconds" "${TREASURE_TEST_SECONDS:-90}"
        set_conf_value "$CONF" "SPTreasure.ScanMs" "${TREASURE_SCAN_MS:-5000}"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-treasure (SP03)" acore_world \
            "$AC_DIR/modules/mod-treasure/data/sql/db-world"
    fi
else
    rm -f "$MOD_CONF_DIR/mod_treasure.conf"
fi

# ── mod-progression-skip (módulo propio) ─────────────────────────────────────
# NPC "Cronista de las Eras": salto irreversible de progresión individual.
# Necesita mod-individual-progression; si ese módulo no está, install_own_modules
# ya no lo compila y esto sólo deja la conf y el NPC (que informará de que la
# función no está disponible). ProgressionSkip.Enable se pone a 1 aquí: el
# .conf.dist arranca en 0 (norma "features de riesgo arrancan en 0") y es este
# despliegue el que decide activarlo, dejando el interruptor a mano.
if [ "${INSTALL_MOD_PROGRESSION_SKIP:-false}" = true ] && [ "${INSTALL_MOD_INDIVIDUAL_PROGRESSION:-false}" = true ]; then
    if install_module_conf "mod-progression-skip" "mod_progression_skip.conf"; then
        CONF="$MOD_CONF_DIR/mod_progression_skip.conf"
        set_conf_value "$CONF" "ProgressionSkip.Enable"         "$(bool_to_int "${PROGRESSION_SKIP_ENABLE:-true}")"
        set_conf_value "$CONF" "ProgressionSkip.RequireNoGroup" "$(bool_to_int "${PROGRESSION_SKIP_REQUIRE_NO_GROUP:-true}")"
    fi
    # NPC, textos y spawns (acore_world), idempotente. El actualizador del core
    # también los aplica al arrancar; aquí para poder probar sin esperar.
    if db_exists acore_world; then
        apply_sql_dir "mod-progression-skip (NPC Cronista)" acore_world \
            "$AC_DIR/modules/mod-progression-skip/data/sql/db-world"
    else
        warn "[mod-progression-skip] acore_world no existe todavia: el NPC se carga con '--only 5' o '--post'."
    fi
else
    rm -f "$MOD_CONF_DIR/mod_progression_skip.conf"
fi

# El módulo puede haberse configurado antes de quedar archivado. La configuración
# residual no se debe instalar ni quedar cargada junto al resto de módulos.
if [ "${INSTALL_MOD_ADAPTIVE_AI:-false}" != true ]; then
    rm -f "$MOD_CONF_DIR/mod_adaptive_ai.conf"
fi

# ── mod-adaptive-ai (módulo propio) ───────────────────────────────────────────
# Bots que aprenden. Sus tablas (adaptive_*) van en acore_playerbots, la base
# de datos de mod-playerbots.
if [ "${INSTALL_MOD_ADAPTIVE_AI:-false}" = true ]; then
    if [ "${INSTALL_MOD_PLAYERBOTS:-false}" != true ]; then
        warn "[mod-adaptive-ai] Requiere INSTALL_MOD_PLAYERBOTS=true: sin playerbots el modulo no hace nada."
    fi
    if install_module_conf "mod-adaptive-ai" "mod_adaptive_ai.conf"; then
        CONF="$MOD_CONF_DIR/mod_adaptive_ai.conf"
        set_conf_value "$CONF" "AdaptiveAI.Enable"                    "$(bool_to_int "${ADAPTIVE_ENABLE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Learn"                     "$(bool_to_int "${ADAPTIVE_LEARN:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Learn.SoloEnArena"         "$(bool_to_int "${ADAPTIVE_LEARN_ONLY_ARENA:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Real.Enable"               "$(bool_to_int "${ADAPTIVE_REAL_ENABLE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Enable"              "$(bool_to_int "${ADAPTIVE_ARENA_ENABLE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Simultaneas"         "${ADAPTIVE_ARENA_SIMULTANEOUS:-20}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.EquipoSimultaneas"   "${ADAPTIVE_ARENA_TEAM_SIMULTANEOUS:-1}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.BotsMax"             "${ADAPTIVE_ARENA_BOTS_MAX:-40}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.ConJugador"          "\"${ADAPTIVE_ARENA_WITH_PLAYER-1c1:21}\""
        set_conf_value "$CONF" "AdaptiveAI.Bg.ConJugador"             "${ADAPTIVE_BG_WITH_PLAYER:-0}"
        set_conf_value "$CONF" "AdaptiveAI.FranjasConJugador"         "$(bool_to_int "${ADAPTIVE_LEVEL_BRACKETS_WITH_PLAYER:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.PausaEntreCombates"  "${ADAPTIVE_ARENA_PAUSE_SECONDS:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Pares"               "\"${ADAPTIVE_ARENA_PAIRS:-warrior:mage}\""
        set_conf_value "$CONF" "AdaptiveAI.Clases"                    "\"${ADAPTIVE_CLASSES:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Bots.Nivel80"              "\"${ADAPTIVE_BOTS_LEVEL80:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Arena.Specs"               "\"${ADAPTIVE_ARENA_SPECS:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Acciones.Excluir"          "\"${ADAPTIVE_ACTIONS_EXCLUDE:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.SaltarSaturadas"  "${ADAPTIVE_CALIBRATE_SKIP_SATURATED:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Objetivos"                 "\"${ADAPTIVE_OBJECTIVES:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Objetivos.Parar"           "$(bool_to_int "${ADAPTIVE_OBJECTIVES_STOP:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Loadout.Enable"            "$(bool_to_int "${ADAPTIVE_LOADOUT_ENABLE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Loadout.EquipoPvP"         "\"${ADAPTIVE_LOADOUT_PVP_ILVL:-0:232,1600:251,1800:264,2200:270}\""
        set_conf_value "$CONF" "AdaptiveAI.Loadout.EquipoPvE"         "\"${ADAPTIVE_LOADOUT_PVE_ILVL:-normal:187,heroica:200,banda10:219,banda25:232,mundo:0}\""
        set_conf_value "$CONF" "AdaptiveAI.Loadout.NivelesTope"       "\"${ADAPTIVE_LOADOUT_CAP_LEVELS:-60,70,80}\""
        set_conf_value "$CONF" "AdaptiveAI.Arena.Tipos"               "\"${ADAPTIVE_ARENA_TYPES:-1c1,2c2,3c3,5c5}\""
        set_conf_value "$CONF" "AdaptiveAI.Bg.Enable"                 "$(bool_to_int "${ADAPTIVE_BG_ENABLE:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Bg.Mapas"                  "\"${ADAPTIVE_BG_MAPS:-WS,AB,EY}\""
        set_conf_value "$CONF" "AdaptiveAI.Bg.CadaMinutos"            "${ADAPTIVE_BG_EVERY_MINUTES:-30}"
        set_conf_value "$CONF" "AdaptiveAI.Bg.PorEquipo"              "${ADAPTIVE_BG_PLAYERS:-0}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Modo"                "\"${ADAPTIVE_ARENA_MODE:-mixto}\""
        set_conf_value "$CONF" "AdaptiveAI.Arena.CederAJugadores"     "$(bool_to_int "${ADAPTIVE_ARENA_YIELD:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Mapa"                "${ADAPTIVE_ARENA_MAP:-559}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.PreparacionSegundos" "${ADAPTIVE_ARENA_PREP_SECONDS:-15}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Nivel"               "${ADAPTIVE_ARENA_LEVEL:-80}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.NivelObjeto"         "${ADAPTIVE_ARENA_GEAR_SCORE:-264}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.CadaMinutos"      "${ADAPTIVE_CALIBRATE_MINUTES:-60}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.Combates"         "${ADAPTIVE_CALIBRATE_MATCHES:-2500}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.MargenMinimo"     "${ADAPTIVE_CALIBRATE_MARGIN:-0.55}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.PorClase"         "$(bool_to_int "${ADAPTIVE_CALIBRATE_PER_CLASS:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.PartidasPorClase" "${ADAPTIVE_CALIBRATE_PER_CLASS_MATCHES:-60}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.CortarAlJuzgar"    "$(bool_to_int "${ADAPTIVE_CALIBRATE_CUT_WHEN_JUDGED:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.PartidasCorte"     "${ADAPTIVE_CALIBRATE_CUT_MATCHES:-0}"
        set_conf_value "$CONF" "AdaptiveAI.Brujo.MascotaPvP"           "\"${ADAPTIVE_WARLOCK_PVP_PET:-felhunter}\""
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.Tipos"            "\"${ADAPTIVE_CALIBRATE_TYPES:-1c1}\""
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.MinutosMaximos"   "${ADAPTIVE_CALIBRATE_MAX_MINUTES:-60}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.Exclusiva"        "$(bool_to_int "${ADAPTIVE_CALIBRATE_EXCLUSIVE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.Reloj"            "$(bool_to_int "${ADAPTIVE_CALIBRATE_CLOCK:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.MejoraPorClase"   "${ADAPTIVE_CALIBRATE_CLASS_GAIN:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.CiclosMaximos"    "${ADAPTIVE_CALIBRATE_MAX_CYCLES:-6}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.PorPareja"        "${ADAPTIVE_CALIBRATE_PER_PAIR:-1}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.VentanaCiclos"    "${ADAPTIVE_CALIBRATE_WINDOW:-2}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.MismoRival"       "$(bool_to_int "${ADAPTIVE_CALIBRATE_SAME_RIVAL:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.Z"                "${ADAPTIVE_CALIBRATE_Z:-1.64}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.VaraSerie"        "$(bool_to_int "${ADAPTIVE_CALIBRATE_LADDER_RULE:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.EscaleraCandidata"   "${ADAPTIVE_ARENA_PROBE:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Decision.VisitasMinimas"   "${ADAPTIVE_DECISION_MIN_VISITS:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Decision.RechazoAprende"   "$(bool_to_int "${ADAPTIVE_DECISION_REJECT_LEARNS:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.AprobadasEntrenan"   "$(bool_to_int "${ADAPTIVE_ARENA_APPROVED_LEARN:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Arena.AprobadaConModelo"   "${ADAPTIVE_ARENA_APPROVED_MODEL:-50}"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.TodasJuegan"      "$(bool_to_int "${ADAPTIVE_CALIBRATE_ALL_PLAY:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Calibrar.RondaMaxExamenes" "${ADAPTIVE_CALIBRATE_ROUND_MAX_EXAMS:-6}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Generaciones"        "${ADAPTIVE_ARENA_GENERATIONS:-15}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Escalera"            "${ADAPTIVE_ARENA_LADDER:-10}"
        set_conf_value "$CONF" "AdaptiveAI.Escalera.PartidasMinimas"  "${ADAPTIVE_LADDER_MIN_MATCHES:-40}"
        set_conf_value "$CONF" "AdaptiveAI.Escalera.DesdeUnix"        "${ADAPTIVE_LADDER_SINCE:-0}"
        set_conf_value "$CONF" "AdaptiveAI.Real.Modo"                 "\"${ADAPTIVE_REAL_MODE:-mejor}\""
        set_conf_value "$CONF" "AdaptiveAI.Real.Espejo.Dispersion"    "${ADAPTIVE_MIRROR_SPREAD:-1}"
        set_conf_value "$CONF" "AdaptiveAI.Real.Espejo.Horas"         "${ADAPTIVE_MIRROR_HOURS:-6}"
        set_conf_value "$CONF" "AdaptiveAI.Generaciones.Guardar"      "${ADAPTIVE_GENERATIONS_KEEP:-5}"
        set_conf_value "$CONF" "AdaptiveAI.Generalizar"               "$(bool_to_int "${ADAPTIVE_GENERALIZE:-true}")"
        set_conf_value "$CONF" "AdaptiveAI.Epsilon"                   "${ADAPTIVE_EPSILON:-0.05}"
        set_conf_value "$CONF" "AdaptiveAI.Arena.Referencia"          "${ADAPTIVE_ARENA_REFERENCE:-10}"
        set_conf_value "$CONF" "AdaptiveAI.Dificultad.PorDefecto"     "${ADAPTIVE_DIFFICULTY_DEFAULT:-3}"
        set_conf_value "$CONF" "AdaptiveAI.Log.Decisiones"            "$(bool_to_int "${ADAPTIVE_LOG_DECISIONS:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Log.AuditarBot"            "${ADAPTIVE_AUDIT_BOT:-0}"
        set_conf_value "$CONF" "AdaptiveAI.Log.AuditarClases"         "\"${ADAPTIVE_AUDIT_CLASSES:-}\""
        set_conf_value "$CONF" "AdaptiveAI.Log.AuditarSesiones"       "${ADAPTIVE_AUDIT_SESSIONS:-3}"
        set_conf_value "$CONF" "AdaptiveAI.Log.Auras"                 "$(bool_to_int "${ADAPTIVE_LOG_AURAS:-false}")"
        set_conf_value "$CONF" "AdaptiveAI.Log.PartidasDias"          "${ADAPTIVE_LOG_MATCH_DAYS:-30}"
        # Tablas (acore_playerbots), idempotente.
        if db_exists acore_playerbots; then
            apply_sql_dir "mod-adaptive-ai (tablas)" acore_playerbots \
                "$AC_DIR/modules/mod-adaptive-ai/data/sql/db-playerbots"
            # Entrenamiento guardado en el repositorio (tools/exportar-adaptive.sh):
            # una instalación desde cero no empieza de vacío. Se pregunta si hay
            # terminal; desatendido manda ADAPTIVE_IMPORTAR_ENTRENADO (sí por
            # defecto). No pisa una base que ya tenga más entrenamiento.
            # Comprimido (lo que guarda tools/exportar-adaptive.ps1: 3,9 MB en vez
            # de 14,5) o en claro, por si alguien lo dejó a mano.
            ENTRENADO="$AC_DIR/modules/mod-adaptive-ai/data/entrenado/adaptive_entrenado.sql"
            LEER=cat
            if [ ! -f "$ENTRENADO" ] && [ -f "$ENTRENADO.gz" ]; then
                ENTRENADO="$ENTRENADO.gz"
                LEER=zcat
            fi
            if [ -f "$ENTRENADO" ]; then
                IMPORTAR="${ADAPTIVE_IMPORTAR_ENTRENADO:-true}"
                if [ -t 0 ] && [ -z "${ADAPTIVE_IMPORTAR_ENTRENADO:-}" ]; then
                    read -r -p "¿Importar el entrenamiento guardado de mod-adaptive-ai? [S/n] " RESP
                    case "$RESP" in n|N|no|NO) IMPORTAR=false ;; *) IMPORTAR=true ;; esac
                fi
                if [ "$IMPORTAR" = true ]; then
                    FILE_VISITS=$("$LEER" "$ENTRENADO" 2>/dev/null | grep -m1 '^-- adaptive-visitas:' | awk '{print $3}' || true)
                    DB_VISITS=$(mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" -N -s acore_playerbots -e "SELECT IFNULL(SUM(visitas),0) FROM adaptive_q" 2>/dev/null || echo 0)
                    if [ "${DB_VISITS:-0}" -gt "${FILE_VISITS:-0}" ]; then
                        warn "[mod-adaptive-ai] La base ya tiene mas entrenamiento ($DB_VISITS visitas) que el fichero ($FILE_VISITS): no se importa."
                    elif "$LEER" "$ENTRENADO" | mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" acore_playerbots >> "$INSTALL_LOG" 2>&1; then
                        log "[mod-adaptive-ai] Entrenamiento importado ($FILE_VISITS visitas; la base tenia $DB_VISITS)."
                    else
                        warn "[mod-adaptive-ai] No se pudo importar $ENTRENADO (ver install.log)."
                    fi
                else
                    info "[mod-adaptive-ai] Entrenamiento guardado no importado (se empieza de vacio)."
                fi
            fi
        else
            warn "[mod-adaptive-ai] acore_playerbots no existe todavia: las tablas se cargan con '--only 5' o '--post'."
        fi
    fi
fi

# ── mod-world-buff-bots ───────────────────────────────────────────────────────
# Buffs de mundo simulados con anuncio. Los textos van en español desde aquí.
if [ "${INSTALL_MOD_WORLD_BUFF_BOTS:-false}" = true ]; then
    if install_module_conf "mod-world-buff-bots" "mod_world_buff_bots.conf"; then
        CONF="$MOD_CONF_DIR/mod_world_buff_bots.conf"
        set_conf_value "$CONF" "WorldBuffBots.Enable"                     "1"
        set_conf_value "$CONF" "WorldBuffBots.BaseMinutes"                "${WORLD_BUFF_BASE_MINUTES:-90}"
        set_conf_value "$CONF" "WorldBuffBots.VarianceMinutes"            "${WORLD_BUFF_VARIANCE_MINUTES:-60}"
        set_conf_value "$CONF" "WorldBuffBots.Warchief.Enable"            "$(bool_to_int "${WORLD_BUFF_WARCHIEF:-true}")"
        set_conf_value "$CONF" "WorldBuffBots.Dragonslayer.Enable"        "$(bool_to_int "${WORLD_BUFF_DRAGONSLAYER:-true}")"
        set_conf_value "$CONF" "WorldBuffBots.Zandalar.Enable"            "$(bool_to_int "${WORLD_BUFF_ZANDALAR:-true}")"
        [ -n "${WORLD_BUFF_WARCHIEF_TEXT:-}" ]     && set_conf_value "$CONF" "WorldBuffBots.Warchief.Announcement"     "${WORLD_BUFF_WARCHIEF_TEXT}"
        [ -n "${WORLD_BUFF_DRAGONSLAYER_TEXT:-}" ] && set_conf_value "$CONF" "WorldBuffBots.Dragonslayer.Announcement" "${WORLD_BUFF_DRAGONSLAYER_TEXT}"
        [ -n "${WORLD_BUFF_ZANDALAR_TEXT:-}" ]     && set_conf_value "$CONF" "WorldBuffBots.Zandalar.Announcement"     "${WORLD_BUFF_ZANDALAR_TEXT}"
    fi
fi

# ── mod-token-turnin ──────────────────────────────────────────────────────────
# Canje de tokens de tier para los bots del grupo. Su tabla va en acore_world.
if [ "${INSTALL_MOD_TOKEN_TURNIN:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-token-turnin] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-token-turnin" "mod_token_turnin.conf"; then
        CONF="$MOD_CONF_DIR/mod_token_turnin.conf"
        set_conf_value "$CONF" "TokenTurnIn.Enable"             "1"
        set_conf_value "$CONF" "TokenTurnIn.IncludeSelf"        "$(bool_to_int "${TOKEN_TURNIN_INCLUDE_SELF:-false}")"
        set_conf_value "$CONF" "TokenTurnIn.IncludeRealPlayers" "0"
        if db_exists acore_world; then
            apply_sql_dir "mod-token-turnin" acore_world \
                "$AC_DIR/modules/mod-token-turnin/data/sql/db-world"
        else
            warn "[mod-token-turnin] acore_world no existe todavia: su SQL se aplicara con '--only 5' o '--post'."
        fi
    fi
fi

# ── mod-playerbots-wintergrasp ─────────────────────────────────────────────────
# Los playerbots aceptan solos la cola y la entrada a Wintergrasp. La IA
# táctica del módulo se deja apagada a propósito (ver config.sh).
if [ "${INSTALL_MOD_PLAYERBOTS_WINTERGRASP:-false}" = true ]; then
    if [ "$INSTALL_MOD_PLAYERBOTS" != true ]; then
        warn "[mod-playerbots-wintergrasp] necesita mod-playerbots activo: no se configura."
    elif install_module_conf "mod-playerbots-wintergrasp" "mod_playerbots_wintergrasp.conf"; then
        CONF="$MOD_CONF_DIR/mod_playerbots_wintergrasp.conf"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.Enable"       "1"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.AcceptQueue"  "1"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.AcceptBattle" "1"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.Announce"     "$(bool_to_int "${WINTERGRASP_ANNOUNCE:-false}")"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.Tactics.Enable" "0"
        # Opciones de la versión 2.0 del módulo, independientes de la IA táctica y
        # encendidas de fábrica: sin medir en este servidor, arrancan apagadas (UPD-P).
        set_conf_value "$CONF" "PlayerbotsWintergrasp.MasterFollowAssist.Enable"      "0"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.GraveyardRespawn.Enable"        "0"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.TeamBalance.Rebalance.Enable"   "0"
        set_conf_value "$CONF" "PlayerbotsWintergrasp.Debug"        "0"
    fi
fi

# ── mod-profession-experience ──────────────────────────────────────────────
# No aporta SQL. Todas las actividades configurables, sin ampliar sus hooks.
if [ "${INSTALL_MOD_PROFESSION_EXPERIENCE:-false}" = true ]; then
    if install_module_conf "mod-profession-experience" "mod-profession-experience.conf"; then
        CONF="$MOD_CONF_DIR/mod-profession-experience.conf"
        for PROFESSION in Alchemy Blacksmith Cooking Disenchanting Enchanting Engineering Fishing FirstAid Herbalism Inscription Jewelcrafting Leatherworking Lockpick Mining Skinning Smelting Tailoring; do
            set_conf_value "$CONF" "ProfessionExperience.${PROFESSION}.Experience" "${PROFESSION_XP_BASE:-0.01}"
        done
        set_conf_value "$CONF" "ProfessionExperience.MultOrange" "${PROFESSION_XP_ORANGE:-1.0}"
        set_conf_value "$CONF" "ProfessionExperience.MultYellow" "${PROFESSION_XP_YELLOW:-0.5}"
        set_conf_value "$CONF" "ProfessionExperience.MultGreen" "${PROFESSION_XP_GREEN:-0.25}"
        set_conf_value "$CONF" "ProfessionExperience.MultGray" "${PROFESSION_XP_GRAY:-0.0}"
        set_conf_value "$CONF" "ProfessionExperience.MultCurve" "${PROFESSION_XP_CURVE:-0.0}"
        set_conf_value "$CONF" "ProfessionExperience.BlockAtSkillCap" "$(bool_to_int "${PROFESSION_XP_BLOCK_AT_SKILL_CAP:-true}")"
        for RANK in Apprentice Journeyman Expert Artisan Master GrandMaster; do
            set_conf_value "$CONF" "ProfessionExperience.Mult${RANK}" "1.0"
        done
    fi
fi

# ── mod-guild-levels ────────────────────────────────────────────────────────
# Experiencia y niveles de hermandad. Valores por defecto del módulo (sin
# tuning propio todavía).
if [ "${INSTALL_MOD_GUILD_LEVELS:-false}" = true ]; then
    if install_module_conf "mod-guild-levels" "guild_levels.conf"; then
        CONF="$MOD_CONF_DIR/guild_levels.conf"
        set_conf_value "$CONF" "GuildLevels.Enable"    "1"
        set_conf_value "$CONF" "GuildLevels.AddonSync" "1"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-guild-levels" acore_world \
            "$AC_DIR/modules/mod-guild-levels/data/sql/world"
    else
        warn "[mod-guild-levels] acore_world no existe todavia: su SQL se aplicara con '--only 5' o '--post'."
    fi
    if db_exists acore_characters; then
        apply_sql_dir "mod-guild-levels" acore_characters \
            "$AC_DIR/modules/mod-guild-levels/data/sql/characters"
    else
        warn "[mod-guild-levels] acore_characters no existe todavia: su SQL se aplicara con '--only 5' o '--post'."
    fi
fi

# ── mod-guildhouse (SP02) ──────────────────────────────────────────────────
if [ "${INSTALL_MOD_GUILDHOUSE:-false}" = true ]; then
    if install_module_conf "mod-guildhouse" "mod_guildhouse.conf"; then
        CONF="$MOD_CONF_DIR/mod_guildhouse.conf"
        set_conf_value "$CONF" "CostGuildHouse" "10000000"
        set_conf_value "$CONF" "GuildHouseMailbox" "500000"
        set_conf_value "$CONF" "GuildHouseInnKeeper" "1000000"
        set_conf_value "$CONF" "GuildHouseBank" "1000000"
        set_conf_value "$CONF" "GuildHouseAuctioneer" "1000000"
        set_conf_value "$CONF" "GuildHouseTrainerCost" "1000000"
        set_conf_value "$CONF" "GuildHouseVendor" "500000"
        set_conf_value "$CONF" "GuildHouseObject" "500000"
        set_conf_value "$CONF" "GuildHousePortal" "1000000"
        set_conf_value "$CONF" "GuildHouseProf" "500000"
        set_conf_value "$CONF" "GuildHouseSpirit" "100000"
        set_conf_value "$CONF" "GuildHouseReagentBank" "1000000"
        set_conf_value "$CONF" "GuildHouseBuyRank" "4"
        set_conf_value "$CONF" "GuildHouseSellRank" "0"
    fi
    if db_exists acore_world; then
        apply_sql_dir "mod-guildhouse" acore_world \
            "$AC_DIR/modules/mod-guildhouse/data/sql/db-world"
    else
        warn "[mod-guildhouse] acore_world no existe todavía: SQL pendiente para '--only 5' o '--post'."
    fi
    if db_exists acore_characters; then
        apply_sql_dir "mod-guildhouse" acore_characters \
            "$AC_DIR/modules/mod-guildhouse/data/sql/db-characters"
    else
        warn "[mod-guildhouse] acore_characters no existe todavía: SQL pendiente para '--only 5' o '--post'."
    fi
fi

if [ "$INSTALL_MOD_ARAC" = true ]; then
    ARAC_SQL_DIR="$AC_DIR/extras/mod-arac/data/sql/db-world"
    if ! db_exists acore_world; then
        warn "[mod-arac] acore_world no existe todavia (se crea en el primer arranque)."
        warn "  El SQL se aplicara automaticamente con './install.sh --only 5' o '--post'."
    else
        # El repo de mod-arac mete su .sql dentro de una subcarpeta "(Optional)"
        # y puede traer mas de uno: apply_sql_dir los recorre todos en orden.
        apply_sql_dir "mod-arac" acore_world "$ARAC_SQL_DIR"

        # Parches propios de razas: corrigen bugs que el upstream tiene en
        # pull requests ABIERTOS y sin mergear. Se aplican DESPUÉS del SQL del
        # módulo para que manden ellos. Ver patches/arac/ para el detalle.
        apply_sql_dir "mod-arac (parches de razas)" acore_world "$PATCHES_DIR/arac"
    fi

    # PlayerStart.CustomSpells vuelve a 1 desde el 22/09/2026 (E1i), PERO sólo
    # porque `patches/arac/09-hechizos-iniciales-podados-por-nivel.sql` acaba
    # de podar `playercreateinfo_spell_custom` — y ese SQL se aplica justo
    # arriba, en el apply_sql_dir de patches/arac.
    #
    # Historia, que importa para no volver atrás a ciegas: la tabla no trae
    # sólo el puñado de hechizos iniciales por raza/clase, trae TODO el árbol
    # de cada clase sin distinción de nivel (Sello de Venganza, de nivel 60,
    # estaba en la fila de Enano). Con el flag a 1 y la tabla intacta,
    # cualquier personaje nuevo aprendía de golpe habilidades que no le
    # tocaban: por eso se revirtió en su día (CHANGELOG, "Domar Bestia rompía
    # la progresión"). El coste oculto de dejarlo a 0 se descubrió el
    # 22/09/2026: es el ÚNICO camino por el que AzerothCore reparte raciales,
    # idiomas, competencias de armadura y los hechizos "generales", así que
    # ningún personaje los tenía — ni siquiera las combinaciones nativas.
    #
    # Con la poda (baseLevel<=1 y spellLevel<=1) se queda lo de nivel 1 y se
    # va el resto, que es justo lo que enseña el instructor. Si alguna vez se
    # reaplica el SQL de mod-arac sin la poda, hay que volver a poner esto a 0
    # o repoblará el árbol entero.
    set_conf_value "$WS" "PlayerStart.CustomSpells" "1"

    # Los DBC del servidor se copian al final de esta fase, tras los datos del
    # cliente: ver apply_server_dbc_overrides.

    warn "[mod-arac] Pendiente SOLO el paso de cliente (no automatizable):"
    warn "  Copia cliente/Data/<idioma>/patch-<idioma>-4.MPQ del instalador a WoW/Data/<idioma>/ de cada jugador"
    warn "  (lleva fundidos los mismos DBC que extras/mod-arac/patch-contents/DBFilesContent/;"
    warn "  cliente/instalar-cliente.ps1 lo hace solo)."
fi


# =============================================================================
# Contenido propio del instalador
#
# Todo lo que hay aquí vive en este repositorio (patches/ y la raíz), no en los
# módulos, así que una actualización de un módulo NO se lo lleva por delante.
# Es idempotente: se reaplica entero en cada './install.sh --only 5'.
# =============================================================================
header "Contenido propio del instalador"

# ── Objetos propios (item_template, entry >= 600000) ─────────────────────────
# Todos los .sql de patches/custom-items/ (uno por objeto). Van ANTES de la
# tabla de recompensas, que referencia alguno (la ganzúa). item_template
# necesita reinicio del worldserver para que el core los vea.
if [ -d "$PATCHES_DIR/custom-items" ] && db_exists acore_world; then
    apply_sql_dir "objetos propios" acore_world "$PATCHES_DIR/custom-items"
fi

# ── Tabla de recompensas por nivel ───────────────────────────────────────────
# Hasta ahora este .sql había que lanzarlo a mano y se perdía en cada
# reinstalación. Va DESPUÉS del SQL del módulo a propósito: el módulo inserta
# sus filas de ejemplo y estas las sustituyen.
if [ "$INSTALL_MOD_CONGRATS_ON_LEVEL" = true ]; then
    COL_REWARDS="$INSTALLER_DIR/congrats_on_level_rewards.sql"
    if [ ! -f "$COL_REWARDS" ]; then
        warn "[recompensas] No se encuentra $COL_REWARDS"
    elif ! db_exists acore_world; then
        warn "[recompensas] acore_world no existe todavía; se aplicarán en '--post'."
    elif mysql -u "$AC_DB_USER" -p"$AC_DB_PASS" acore_world < "$COL_REWARDS" >> "$INSTALL_LOG" 2>&1; then
        log "[recompensas] Tabla de recompensas por nivel aplicada."
    else
        warn "[recompensas] Falló la aplicación — revisa $INSTALL_LOG"
    fi
fi

# ── Traducciones al español ──────────────────────────────────────────────────
# El juego base ya viene traducido en el volcado del core; esto traduce sólo lo
# que añaden los módulos (textos de mod-transmog y nombres de los NPC propios).
if [ "${LOCALE_ES:-false}" = true ]; then
    if db_exists acore_world; then
        apply_sql_dir "traducciones es" acore_world "$PATCHES_DIR/locales-es"
    else
        warn "[traducciones] acore_world no existe todavía; se aplicarán en '--post'."
    fi

    # Lo que dicen los bots por el chat (ai_playerbot_texts) vive en la base de
    # playerbots, no en la del mundo. 846 frases traducidas el 02/09/2026.
    #
    # OJO: acore_playerbots existe (vacía) desde la fase 2 — db_exists no sirve
    # aquí. La tabla ai_playerbot_texts la crea el propio mod-playerbots en el
    # primer arranque, igual que acore_world/acore_characters; hay que
    # comprobar la TABLA, no el esquema (15/09/2026, ver lib/utils.sh).
    if [ "$INSTALL_MOD_PLAYERBOTS" = true ]; then
        if table_exists acore_playerbots ai_playerbot_texts; then
            apply_sql_dir "bots en español" acore_playerbots "$PATCHES_DIR/locales-es-playerbots"
        else
            warn "[traducciones] acore_playerbots todavía no tiene sus tablas (primer arranque pendiente); los textos de los bots se aplicarán en '--post'."
        fi
    fi
fi

# ── NPC de servicio ──────────────────────────────────────────────────────────
if [ "${SPAWN_SERVICE_NPCS:-false}" = true ]; then
    spawn_service_npcs || true
fi

# Hasta aquí, set_conf_value() sólo ha encolado en memoria:
# esta es la única pasada real de escritura de toda la fase, una vez por
# fichero en vez de una vez por clave. Se hace ANTES de la descarga de datos
# del cliente (más abajo) a propósito: son cosas independientes, y un fallo
# de descarga no debe dejar sin escribir la configuración que sí se
# preparó con éxito.
flush_conf_files

# Si durante toda la fase se ha escrito alguna clave que su .conf.dist no
# declaraba, se repite aquí: en medio de la salida no la ve nadie, y es
# justo así como se colaron MapUpdateThreadCount y compañía.
report_unknown_conf_keys

header "Datos del cliente (enUS)"

DATA_VERSION_FILE="$BIN_DIR/data-version"

# Versión fijada de los datos (el core exige mmaps v20): URL y SHA-256 del asset
# oficial de wowgaming/client-data. Para usar otra versión hay que dar las dos
# cosas (AC_DATA_URL y AC_DATA_SHA256); nunca se toma "la última" sin hash.
DATA_URL="${AC_DATA_URL:-https://github.com/wowgaming/client-data/releases/download/v20.0/Data.zip}"
DATA_SHA256="${AC_DATA_SHA256:-a3d4df635ae6c2c8f08052c32a79e0f806955150ad36b014a823dd08a32a4610}"
if [ -n "${AC_DATA_URL:-}" ] && [ -z "${AC_DATA_SHA256:-}" ]; then
    error "AC_DATA_URL exige también AC_DATA_SHA256 (los datos del cliente se verifican siempre)."
    exit 1
fi
DATA_EXTRACT_MARK="$BIN_DIR/.data-extracting"

# Comprobar presencia de datos: primero el fichero de versión, luego la carpeta maps.
# Una extracción interrumpida deja la marca y se repite entera.
DATA_PRESENT=false
if [ -f "$DATA_EXTRACT_MARK" ]; then
    warn "Una extracción anterior de los datos del cliente quedó a medias; se repite."
elif [ -f "$DATA_VERSION_FILE" ]; then
    DATA_PRESENT=true
    warn "Datos del cliente ya presentes ($(cat "$DATA_VERSION_FILE")). Saltando descarga."
elif [ -d "$BIN_DIR/maps" ] && [ -n "$(ls -A "$BIN_DIR/maps" 2>/dev/null)" ]; then
    DATA_PRESENT=true
    warn "Carpeta maps encontrada pero sin data-version. Asumiendo datos presentes."
fi

if [ "$DATA_PRESENT" = true ]; then
    true
else
    install_client_data "$DATA_URL" "$DATA_SHA256" "$BIN_DIR" || exit 1
fi


# ── DBC del servidor de IP y ARAC ────────────────────────────────────────────
# Aquí y no antes: env/dist/bin/dbc no existe hasta extraer los datos del
# cliente justo arriba (PLAN AR01). Un fallo aquí deja el servidor sin razas y
# clases cruzadas sin dar ningún error al arrancar: se para la fase.
header "DBC del servidor (mod-individual-progression y mod-arac)"
if ! apply_server_dbc_overrides; then
    error "No se pudieron copiar los DBC del servidor (ver arriba)."
    exit 1
fi
# (apply_server_dbc_overrides también deja ahí el hechizo 600001 de la Piedra de la sede.)

log "Configuración del servidor completada."
