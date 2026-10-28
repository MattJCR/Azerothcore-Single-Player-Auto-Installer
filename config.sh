#!/bin/bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# =============================================================================
#  config.sh — Configuración central de AzerothCore Installer
#
#  Este es el ÚNICO archivo que necesitas editar antes de instalar.
#  Cada opción tiene una explicación clara de qué hace y qué valores acepta.
# =============================================================================


# ═══════════════════════════════════════════════════════════════════════════════
#  DIRECTORIOS
# ═══════════════════════════════════════════════════════════════════════════════

# Directorio donde se instalará AzerothCore.
# Por defecto en la carpeta home del usuario actual. Bajo sudo, $HOME pasa a
# ser el del usuario objetivo (normalmente /root), no el del usuario real que
# invocó sudo: para `sudo ./install.sh --panel` (la única fase que install.sh
# deja correr como root — ver su comentario "Nunca como root salvo --panel")
# eso dejaba AC_DIR=/root/azerothcore, que no existe, y la pasada de `doctor`
# que se relanza al final de cada invocación reportaba módulos propios "que
# faltan" que en realidad sí estaban instalados (14/09/2026). Se resuelve con
# SUDO_USER cuando lo hay.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    AC_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    AC_HOME="$HOME"
fi
AC_DIR="$AC_HOME/azerothcore"

# Zona horaria del sistema (04/09/2026). La fase 1 la aplica con timedatectl. Los logs,
# las fechas de las tablas adaptive_* y el reinicio diario del cron van en esta hora.
# Vacío = no tocar la de la máquina.
TIMEZONE="Europe/Madrid"


# ═══════════════════════════════════════════════════════════════════════════════
#  BASE DE DATOS (MySQL)
# ═══════════════════════════════════════════════════════════════════════════════

# Contraseña del usuario ROOT de MySQL.
# Déjalo vacío si MySQL se instaló sin contraseña (instalación nueva).
MYSQL_ROOT_PASS=""

# Usuario y contraseña que usará AzerothCore para conectarse a MySQL.
# CAMBIA LA CONTRASEÑA si este servidor va a ser accesible desde la red.
AC_DB_USER="acore"
AC_DB_PASS="acore"

# Panel web del reino. Se instala después del primer arranque, cuando las bases
# de datos ya existen. Queda accesible como http://REALM_IP por defecto.
# Incluye moderación (expulsar, banear, silenciar, anunciar, enviar objetos y
# oro): esas acciones hablan con la consola SOAP del worldserver, así que
# activarlo (fase 5) va ligado a este mismo interruptor.
INSTALL_WEB_PANEL=true
PANEL_HTTP_PORT=80
PANEL_HTTPS_PORT=443
PANEL_REALM_ID=1
PANEL_AUTH_DATABASE="acore_auth"
PANEL_CHARACTERS_DATABASE="acore_characters"
PANEL_WORLD_DATABASE="acore_world"
PANEL_PANEL_DATABASE="acore_panel"
PANEL_DB_USER="acore_panel"
PANEL_SOAP_ACCOUNT="panel_soap"


# ═══════════════════════════════════════════════════════════════════════════════
#  MÓDULOS
#  Cambia a false los módulos que NO quieras instalar.
# ═══════════════════════════════════════════════════════════════════════════════

# Progresión individual por expansión (Vanilla → TBC → WotLK por personaje)
INSTALL_MOD_INDIVIDUAL_PROGRESSION=true

# Módulo PROPIO. NPC neutral "Cronista de las Eras": deja AVANZAR de forma
# irreversible en mod-individual-progression sin jugarse el contenido (saltar
# Vanilla → etapa 8, saltar Terrallende → 13, desactivar las etapas → 18). No
# entrega recompensas, logros, reputación ni attunements; usa la API pública del
# módulo (monotónica y respeta ProgressionLimit). Aparece en Gadgetzan, Bahía del
# Botín, Shattrath y Dalaran. Se desactiva solo si la línea de arriba es false.
# El interruptor fino (ProgressionSkip.Enable) lo fija la fase 5; aquí sólo se
# decide si el módulo se compila y se coloca el NPC.
INSTALL_MOD_PROGRESSION_SKIP=true

# SP03: cofres itinerantes; cada zona se habilita tras validar sus puntos.
INSTALL_MOD_TREASURE=true
TREASURE_ENABLE=true
TREASURE_LOCATION_SECONDS=3600
TREASURE_BASIC_RESPAWN_SECONDS=1800
TREASURE_RARE_RESPAWN_SECONDS=5400
TREASURE_EPIC_RESPAWN_SECONDS=14400
TREASURE_CANDIDATE_RADIUS=250
TREASURE_SPAWN_SPELL=30262
TREASURE_TEST_SECONDS=90
TREASURE_SCAN_MS=5000
# Interruptor fino del NPC (lo aplica la fase 5). true = el Cronista ofrece los
# saltos; false = el NPC sigue colocado pero guarda silencio.
PROGRESSION_SKIP_ENABLE=true
# Exigir salir del grupo antes de confirmar un salto (evita dejar compañeros con
# EnforceGroupRules en etapas incompatibles). true recomendado.
PROGRESSION_SKIP_REQUIRE_NO_GROUP=true

# Bots con IA que simulan jugadores reales.
# ⚠️  IMPORTANTE: activa este módulo ANTES de la primera instalación.
#     Requiere un fork especial del core. Si ya tienes AzerothCore instalado
#     sin este fork, necesitarás reinstalar desde cero.
INSTALL_MOD_PLAYERBOTS=true

# Escala automática de dificultad en instancias según número de jugadores
INSTALL_MOD_AUTOBALANCE=true

# Transmogrificación de equipo mediante NPC
INSTALL_MOD_TRANSMOG=true

# Bot de Casa de Subastas con precios estilo Blizzard
INSTALL_MOD_AH_BOT_PLUS=true

# Encantamientos aleatorios en items obtenidos por loot, quest o profesión
INSTALL_MOD_RANDOM_ENCHANTS=true

# Títulos de PvP estilo Vanilla por asesinatos en combate (Honorable Kills)
# ⚠️  DESACTIVADO A PROPÓSITO. mod-individual-progression trae SU PROPIO sistema
#     de títulos PvP vanilla (IndividualProgression.VanillaPvpKillRequirement.*),
#     con umbrales más altos y consciente de la fase de progresión: los títulos
#     sólo se ganan durante la fase vanilla. Este módulo da los MISMOS 14 títulos
#     por HK, pero más baratos (50/100/500...), así que siempre gana él y anula el
#     diseño del otro. Ver IP_PVP_RANK_* más abajo para ajustar los umbrales.
INSTALL_MOD_PVP_TITLES=false

# All Races All Classes — permite combinar cualquier raza con cualquier clase.
# ⚠️  ESTE MÓDULO ES DIFERENTE A LOS DEMÁS: no es un módulo de compilación C++,
#     es un parche de cliente (Patch-A.MPQ) + SQL en la BD del mundo + DBC.
#     El instalador solo puede automatizar la parte de SQL; el resto
#     (Patch-A.MPQ en el cliente y archivos DBC en el servidor) requiere
#     pasos manuales que se mostrarán al final de la instalación.
INSTALL_MOD_ARAC=true

# Módulo PROPIO. Verificación de los instructores genéricos de mod-arac con
# los hooks de entrenador del core (20/09/2026): deja en Server.log cada
# hechizo comprado en un entrenador (raza/clase/entrenador/hechizo) y veta,
# con aviso, cualquier compra que no encaje con la raza/clase del jugador
# (red de seguridad; el core ya filtra esto antes de dejar comprar). No
# añade hechizos ni toca trainer_spell. Ajustes: ARAC_TRAINER_AUDIT_*.
INSTALL_MOD_ARAC_TRAINER_AUDIT=true

# Recompensas automáticas (oro, hechizos, items) al alcanzar ciertos niveles,
# configurables por raza/clase desde la tabla mod_congratulations en acore_world.
INSTALL_MOD_CONGRATS_ON_LEVEL=true

# Mazmorras procedurales: un NPC "Dungeon Master" teletransporta a los
# jugadores a instancias repobladas con enemigos escalados por nivel/tema,
# con un modo Roguelike de dificultad progresiva.
# ⚠️  EN DESARROLLO TEMPRANO (early development) según su propio autor.
#     Toca combate, daño e instancias en tiempo real — el mismo terreno que
#     mod-autobalance y mod-playerbots. Puede tener bugs que afecten a la
#     experiencia de otros módulos o causar comportamiento inesperado en
#     instancias. Actívalo sabiendo esto; si prefieres mayor estabilidad,
#     ponlo en false (el módulo seguiría clonándose y actualizándose
#     semanalmente vía crontab, pero no se compilaría ni cargaría).
INSTALL_MOD_DUNGEON_MASTER=true

# ── Módulos de contenido añadidos (ver README.md) ─────────────────────

# Modos de desafío por personaje: Hardcore, Semi-Hardcore, Sólo Fabricado,
# Sólo calidad Normal, XP Lenta, XP Muy Lenta, Sólo XP de misiones e Iron Man.
# Se activan hablando con el "Santuario del Desafío" que aparece solo junto al
# cementerio de cada zona inicial, y sólo a nivel 1 (55 para Caballero de la
# Muerte). Las recompensas por hitos se configuran más abajo (CM_*).
# Mismo autor que mod-individual-progression: encajan por diseño.
INSTALL_MOD_CHALLENGE_MODES=true

# Jefes de mundo (Kazzak, Azuregos, los dragones esmeralda, Doomwalker...)
# instanciados por grupo. Jugando solo o con bots son inaccesibles de otra forma.
INSTALL_MOD_INSTANCED_WORLDBOSSES=true

# Esfuerzo de Guerra para abrir las puertas de Ahn'Qiraj: entregas acumulativas
# de materiales en 5 fases. Los objetivos son configurables (WAR_EFFORT_* abajo),
# así que un solo jugador puede completarlo.
INSTALL_MOD_WAR_EFFORT=true

# Cambiar el rasgo racial del personaje por otro, pagando oro, hablando con un
# NPC. Sinergia directa con mod-arac: hay combinaciones raza/clase con racials
# inútiles que así se pueden arreglar.
INSTALL_MOD_RACIAL_TRAIT_SWAP=true

# Banco de materiales de profesión (un NPC que guarda reactivos aparte, sin
# gastar espacio de banco). Muy útil con las profesiones vanilla.
INSTALL_MOD_REAGENT_BANK=true

# Lootear todos los cadáveres cercanos de una vez. Ya viene traducido al español.
INSTALL_MOD_AOE_LOOT=true
INSTALL_MOD_QUEST_LOOT_PARTY=true

# Reiniciar instancias pagando (oro o emblemas).
# ⚠️  El coste alto es DELIBERADO: reiniciar barato permitiría granjear la misma
#     raid en bucle y se cargaría el ritmo de progresión del servidor.
INSTALL_MOD_INSTANCE_RESET=true

# Arena 1c1 con su propio battlemaster. Requiere nivel 80.
INSTALL_MOD_1V1_ARENA=true

# Módulo PROPIO (vive en modules/ de este repositorio, no se clona de GitHub).
# Cuando te pones en una cola —refriega 1c1, campo de batalla, arena, buscador
# de mazmorras o de bandas— mete en ella los bots que faltan, del tramo de nivel
# que corresponda.
# ⚠️  Es lo que hace jugable el contenido de grupo en un servidor de una persona.
#     El auto-apuntado que trae playerbots va a ciegas: intenta llenar una
#     batalla por cada tramo de cada campo de batalla (24 a la vez) repartiendo
#     entre todas los bots conectados, así que no llena ninguna — y de tu cola no
#     sabe nada. Comprobado en el juego. Al activar esto, el instalador apaga
#     aquél (BOTS_AUTO_JOIN_BG).
# Requiere INSTALL_MOD_PLAYERBOTS=true. Para la cola 1c1, INSTALL_MOD_1V1_ARENA.
INSTALL_MOD_QUEUE_BOTS=true

# Módulo PROPIO. Que la zona en la que estás no esté vacía: al entrar en una
# zona cuenta los bots de tu tramo de nivel que hay en ella y, si faltan hasta
# el objetivo (15-30; 30-50 en capitales), trae bots libres de otras zonas a puntos de caza a más de
# 250 yardas de ti — o despierta dormidos si no hay bastantes. Mientras sigues
# en la zona repone cada minuto; al salir, se quedan.
# ⚠️  Sin esto, 250 bots repartidos entre 80 niveles y ~90 zonas dan 1-2 bots
#     por zona: playerbots mueve a cada bot dentro de SU zona y lo cambia de
#     zona al azar cada 1-5 horas, y de dónde estás tú sólo sabe para despertar
#     a los que ya estaban allí. LevelBrackets arregla el nivel, no la zona.
# Requiere INSTALL_MOD_PLAYERBOTS=true. Sus ajustes, más abajo (WORLD_BOTS_*).
INSTALL_MOD_WORLD_BOTS=true

# Módulo PROPIO. Compañeros de misión: al aceptar una misión, dos o tres bots
# de tu zona, de tu facción y de tu nivel la cogen también y se les ve cazar y
# recoger lo mismo que tú. Los mismos repiten contigo mientras sigan en la
# zona. Fuera quedan las de mazmorra, banda, escolta, JcJ, diarias y de evento.
# Requiere INSTALL_MOD_PLAYERBOTS=true. Sus ajustes, más abajo (QUEST_MATES_*).
INSTALL_MOD_QUEST_MATES=true

# Módulo PROPIO. Grupo donde estás, sin cola: ".grupo" te forma un grupo de
# cinco con bots de tu nivel (tanque y sanador de verdad) y los trae a tu lado;
# ".grupo banda 25" una banda; ".grupo fuera" se van. Y en automático: al
# aceptar una misión de grupo ("jugadores sugeridos") invita a los que falten,
# que se van solos al entregarla o al cambiar de zona. Es lo que hace jugables
# las misiones de élite y las mazmorras a pie. Ajustes: PARTY_HERE_*.
# Requiere INSTALL_MOD_PLAYERBOTS=true.
INSTALL_MOD_PARTY_HERE=true

# Módulo PROPIO. Tu hermandad: no crea ni adopta ninguna automáticamente. Cuando
# fundas una mediante el flujo normal del juego, la marca como tuya y la rellena
# con bots de tu facción y nivel. Sólo el fundador mientras siga siendo líder
# activa el cuidado. Ajustes: HOME_GUILD_*.
# No cambia las invitaciones de otras hermandades. Requiere
# INSTALL_MOD_PLAYERBOTS=true.
INSTALL_MOD_HOME_GUILD=true

# Módulo PROPIO. Puente entre los módulos de bots de arriba y el panel web:
# publica una instantánea (colas, mundo/etapa, grupos, hermandades,
# compañeros de misión, reservas) cada BOT_OPERATIONS_SNAPSHOT_INTERVAL_SECONDS
# en acore_world, y procesa una cola de acciones seguras y limitadas que deja
# el panel (adelantar una pasada normal, parar un evento PvP de mundo
# atascado, refrescar la instantánea). No interpreta texto de SOAP ni ofrece
# ningún comando de juego: sólo lee/escribe esas dos tablas. Ajustes: más
# abajo (BOT_OPERATIONS_*). No requiere ningún módulo de bots en concreto: los
# que no estén activos simplemente no publican su sección (queda "apagado").
INSTALL_MOD_BOT_OPERATIONS=true
# Interruptor fino del módulo (lo aplica la fase 5). true = publica
# instantáneas y procesa acciones; false = compilado pero inactivo, el panel
# mostrará que no hay una instantánea reciente.
BOT_OPERATIONS_ENABLE=true
BOT_OPERATIONS_SNAPSHOT_INTERVAL_SECONDS=10
BOT_OPERATIONS_ACTION_POLL_INTERVAL_SECONDS=2
BOT_OPERATIONS_ACTION_QUEUE_MAX=20
BOT_OPERATIONS_ACTION_MAX_AGE_SECONDS=120

# Módulo PROPIO. Aviso de actualizaciones al conectarse: si algún repositorio
# remoto tiene commits nuevos sobre versions.lock, las cuentas GM ven un mensaje
# del sistema al entrar (y con ".actualizaciones"). Lee el fichero que escribe
# tools/revisar-actualizaciones.sh (a mano o desde la tarea semanal). No toca
# la red ni el servidor. Ajustes: UPDATE_NOTICE_*.
INSTALL_MOD_UPDATE_NOTICE=true

# Módulo PROPIO. La pestaña "Solicitud de ayuda" > "Ayuda básica" del cliente
# como base de conocimiento del servidor: todos los comandos que la cuenta
# conectada puede usar (del core y de cualquier módulo, detectados solos), con
# su ayuda, permiso y categoría, más artículos y fichas en español (tablas
# server_help_* de acore_world). El filtro de permisos lo hace el core con la
# sesión real: un jugador no recibe ni los nombres de los comandos de GM.
# Necesita el addon ServerHelp en el cliente (carpeta cliente/). Comando
# ".ayuda" también desde el chat. Ajustes: SERVER_HELP_*.
INSTALL_MOD_SERVER_HELP=true

# Módulo PROPIO. Modo en espera: apaga el worldserver cuando lleva
# STANDBY_IDLE_MINUTES sin jugadores humanos, para que la VM no gaste CPU ni RAM
# con los bots mientras nadie juega. Comando ".standby". NO se activa aquí: se
# activa y se ajusta con WORLDSERVER_STANDBY y STANDBY_* en la sección
# "MODO EN ESPERA" (más abajo), que fija INSTALL_MOD_STANDBY para que lo siga.

# Módulo PROPIO. Bots que aprenden: una capa de decisión encima de la IA de
# playerbots que, en cada punto de decisión de un combate PvP, elige QUÉ hacer
# (interrumpir, cargar, control, defensiva, nada) y aprende de lo que pasa
# después. Entrena en arenas instanciadas en segundo plano (no se ven) y solo
# pasa a los bots que te cruzas lo que gana a la versión anterior en una
# calibración. Fase 1: 1c1 guerrero contra mago. Comandos ".adaptive".
# Requiere INSTALL_MOD_PLAYERBOTS=true y bots de nivel 80. Ajustes: ADAPTIVE_*.
# Con BOTS_DISABLED_WITHOUT_PLAYER=true la arena de fondo solo entrena mientras
# alguien juega (sin jugador no hay bots); a false, las 24 horas.
# Archivado el 06/09/2026: la fase 3 lo aparta de modules/ y no se compila ni carga.
INSTALL_MOD_ADAPTIVE_AI=false

# El tanque bot lleva la mazmorra de punta a punta: ruta entre jefes, pulls,
# eventos con guion, botín, descanso y resurrección. Se activa con ".dc on"
# dentro de la mazmorra, o solo, si QUEUE_BOTS_DUNGEON_CLEAR_AUTO=true (lo hace
# mod-queue-bots cuando el grupo del buscador ya está dentro).
# Revisado su código el 02/09/2026 (CHANGELOG.md anexo A5): ESPERA al jugador humano
# —a más de 25 yardas, sin vida o maná, muerto— sin límite de tiempo, y
# descansa entre pulls. El rebufo automático sólo lo hace en bandas; en
# mazmorras de 5 los bots se bufan con sus estrategias normales.
# ⚠️  Tú no puedes ser el tanque: la IA lleva al tanque bot. Apúntate de daño o
#     sanador. Módulo grande (94.000 líneas) que toca interioridades de
#     playerbots: es el más frágil ante actualizaciones. Fijado en versions.lock.
INSTALL_MOD_DUNGEON_CLEAR=true

# Buffs de mundo simulados: cada 30-150 minutos un "jugador" con nombre
# inventado entrega la cabeza de Onyxia en Ventormenta, el Jefe de Guerra
# bendice Orgrimmar o vuelve el Corazón de Hakkar a Stranglethorn, con anuncio
# a todo el servidor y el buff de verdad a quien esté allí. Autónomo (no toca
# playerbots). Encaja con la fase Vanilla de individual-progression.
# Revisado su código el 02/09/2026 (CHANGELOG.md anexo A5, ronda 2). Textos en español
# desde WORLD_BUFF_*. Fijado en versions.lock.
INSTALL_MOD_WORLD_BUFF_BOTS=true

# Canje de tokens de tier para los bots: ".tokenturnin redeem" recorre a los
# bots de tu grupo, deduce su especialización por talentos y cambia cada token
# por su pieza. Los bots sólo tiran codicia sobre los tokens que pueden usar:
# los que tú pasas se los llevan y sin esto se quedan muertos en su bolsa.
# mod-queue-bots lo manda solo tras cada jefe (QUEUE_BOTS_TOKEN_TURNIN).
# Submódulo de la lista oficial de playerbots. Fijado en versions.lock.
INSTALL_MOD_TOKEN_TURNIN=true

# Los playerbots aceptan solos la cola y la entrada a la batalla de Guerra de
# las Tierras Árticas (Wintergrasp), interceptando los paquetes que el core
# les manda (sin esto, playerbots nunca hace clic en esas dos invitaciones y
# los bots no llegan a entrar en Wintergrasp aunque estén en la zona).
# Trae además una "IA táctica" experimental (rutas, talleres, cañones) que se
# deja DESACTIVADA a propósito: su propio autor la
# marca como experimental, y usa varios mutex sobre acciones que reentran en
# playerbots — el mismo patrón que ya colgó un mapa entero una vez (ver
# CHANGELOG.md, "cerrojos reentrantes con hooks"). Parche local propio evita
# además una copia de paquete innecesaria mientras esa IA sigue apagada (ver
# patches/mod-playerbots-wintergrasp/). Fijado en versions.lock.
# Requiere INSTALL_MOD_PLAYERBOTS=true.
INSTALL_MOD_PLAYERBOTS_WINTERGRASP=true
# Aviso "Created by iCore" al conectar un jugador real. Apagado, igual que el
# resto de anuncios de autoría de módulos de terceros (ver CONGRATS_LOGIN_ANNOUNCE).
WINTERGRASP_ANNOUNCE=false

# Experiencia y 25 niveles de hermandad con perks al estilo Cataclysm (más XP,
# reputación y honor, oro al banco al saquear, reposición de durabilidad,
# tiradas extra de profesión, montura más rápida, banco de hermandad temporal,
# resurrección en masa). Encaja con mod-home-guild: los bots de tu hermandad-
# hogar generan XP de hermandad igual que un jugador real (cualquier Player
# que gane experiencia cuenta, sea bot o no). Sin mod-ale/AIO: solo comandos
# GM (.guildlevels) y el addon de cliente de serie (ver cliente/Interface/
# AddOns/GuildLevels). Fijado en versions.lock.
INSTALL_MOD_GUILD_LEVELS=true

# Sede de hermandad (SP02). Compra y mejoras con los precios originales;
# entrada de miembros por vendedor/comando y salida mediante sus portales.
INSTALL_MOD_GUILDHOUSE=true

# XP por profesiones, incluidos bots. Fuente independiente de Guild Levels.
INSTALL_MOD_PROFESSION_EXPERIENCE=true
# Base común para las 17 actividades configurables: 0.01 = 1 % del nivel.
# Prospección/molienda conservan la cobertura upstream (sin XP).
PROFESSION_XP_BASE=0.01
PROFESSION_XP_ORANGE=1.0
PROFESSION_XP_YELLOW=0.5
PROFESSION_XP_GREEN=0.25
PROFESSION_XP_GRAY=0.0
PROFESSION_XP_CURVE=0.0
PROFESSION_XP_BLOCK_AT_SKILL_CAP=true

# NOTA sobre Eluna y Acore_LevelUpReward (55Honey):
# Ya está resuelto de dónde sale Eluna: el repositorio azerothcore/mod-eluna
# ahora redirige a azerothcore/mod-ale (AzerothCore Lua Engine), y para scripts
# de Eluna clásico existe ElunaLuaEngine/ElunaAzerothcore.
# AUN ASÍ SE MANTIENE FUERA, y por motivos de peso: Eluna obliga al servidor a
# usar un único hilo de actualización de mapas — con 150 bots eso es inaceptable
# — y hay roturas de compilación conocidas entre Eluna y el fork de playerbots.
# El motivo original para quererlo (recompensas por nivel) lo cubre
# mod-congrats-on-level, ahora parcheado para premiar en CUALQUIER nivel
# (ver patches/mod-congrats-on-level/).

# ── mod-congrats-on-level: qué mensajes se ven ───────────────────────────────
# El módulo manda tres mensajes distintos. El de la recompensa lo tenía fijo en
# el código y, con el premio en todos los niveles, salía en cada subida: lo
# apaga el parche 02 (Congrats.RewardMessage). Petición del 02/09/2026.
CONGRATS_LOGIN_ANNOUNCE=false     # aviso del módulo al conectar
CONGRATS_LEVEL_MESSAGE=true       # "[FELICITACIONES!] X ha alcanzado el nivel N" a todos
CONGRATS_REWARD_MESSAGE=false     # el anuncio de la recompensa + aviso de banda
# Los bots también pasan por el módulo: cada bot que sube de nivel recibía
# premio y se anunciaba a todo el servidor ("[FELICITACIONES!] Bot ha alcanzado
# el nivel N" sin parar). Con esto, a los bots ni premio ni anuncio.
CONGRATS_IGNORE_BOTS=true


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-DUNGEON-MASTER — MAZMORRAS PROCEDURALES (⚠️ módulo experimental)
#  Solo se aplican si INSTALL_MOD_DUNGEON_MASTER=true. Ver aviso arriba.
# ═══════════════════════════════════════════════════════════════════════════════

# Escalado de dificultad en solitario vs grupo (reducción de HP/daño para 1 jugador)
DM_SOLO_MULTIPLIER=0.5

# HP añadido por cada miembro extra del grupo (0.25 = +25% por jugador)
DM_PER_PLAYER_HEALTH=0.25

# Multiplicadores de jefe (encima del escalado por tamaño de grupo)
DM_BOSS_HEALTH_MULT=8.0
DM_BOSS_DAMAGE_MULT=1.5

# Multiplicador de HP de los mobs élite (trash)
DM_ELITE_HEALTH_MULT=2.0

# Número de jefes por mazmorra
DM_BOSS_COUNT=1

# Probabilidad (%) de que un mob trash aparezca como élite
DM_ELITE_CHANCE=20

# Activar el Modo Roguelike (mazmorras encadenadas con dificultad creciente)
DM_ROGUELIKE_ENABLE=true

# Segundos de espera entre mazmorras en modo Roguelike
DM_ROGUELIKE_TRANSITION_DELAY=30

# Escalado de HP/daño por tier en Roguelike (0.10 = +10% por tier)
DM_ROGUELIKE_HP_SCALING_PER_TIER=0.10
DM_ROGUELIKE_DMG_SCALING_PER_TIER=0.08

# Tier a partir del cual el escalado pasa a ser exponencial, y su factor
DM_ROGUELIKE_EXPONENTIAL_THRESHOLD=5
DM_ROGUELIKE_EXPONENTIAL_FACTOR=1.15

# Tiers en los que se añaden el 1º, 2º y 3º affix simultáneo (estilo Mythic+)
DM_ROGUELIKE_AFFIX_START_TIER=3
DM_ROGUELIKE_SECOND_AFFIX_TIER=7
DM_ROGUELIKE_THIRD_AFFIX_TIER=10

# Recompensas al completar una mazmorra
DM_REWARDS_BASE_GOLD=50000          # En cobre (50000 = 5 gold)
DM_REWARDS_XP_MULTIPLIER=1.0
DM_REWARDS_ITEM_CHANCE=80           # % de recibir un item de recompensa
DM_REWARDS_RARE_CHANCE=40           # % de que ese item sea azul
DM_REWARDS_EPIC_CHANCE=15           # % de que ese item sea épico



# ═══════════════════════════════════════════════════════════════════════════════
#  SERVIDOR — CONFIGURACIÓN GENERAL
# ═══════════════════════════════════════════════════════════════════════════════

# Nombre del reino (aparece en la pantalla de selección de servidor)
REALM_NAME="Azeroth SP"

# Tipo de reino: 0=Normal  1=PvP  6=RP  8=RP-PvP
REALM_TYPE=0

# Máximo de jugadores conectados simultáneamente
MAX_PLAYERS=100

# IP del servidor en el realmlist.
# Usa 127.0.0.1 si solo juegas desde la misma máquina.
# Usa la IP local (192.168.x.x) si juegas en red local.
# Usa tu IP pública si quieres acceso desde internet.
# El asistente (./install.sh --guiado) pregunta este valor y lo guarda en
# config.local.sh; no lo escribas aquí si vas a compartir tu copia.
REALM_IP="127.0.0.1"


# ═══════════════════════════════════════════════════════════════════════════════
#  SERVIDOR — TASAS DE EXPERIENCIA Y LOOT
# ═══════════════════════════════════════════════════════════════════════════════

# Multiplicador de experiencia al matar criaturas  (1=Blizzlike, 2=x2, 5=x5)
RATE_XP_KILL=1.5

# Multiplicador de experiencia al completar quests
RATE_XP_QUEST=1

# Multiplicador de experiencia al explorar zonas
RATE_XP_EXPLORE=1

# Multiplicador de dinero al matar criaturas
RATE_DROP_MONEY=1

# Multiplicador de drop de items por calidad
RATE_DROP_UNCOMMON=1      # Verde
RATE_DROP_RARE=1          # Azul
RATE_DROP_EPIC=1          # Morado

# Multiplicador de honor en PvP
RATE_HONOR=2

# Multiplicador de reputación
RATE_REPUTATION=3


# ═══════════════════════════════════════════════════════════════════════════════
#  SERVIDOR — CROSS-FACTION (facciones mixtas)
# ═══════════════════════════════════════════════════════════════════════════════

# Permitir grupos mixtos Alianza + Horda
ALLOW_TWO_SIDE_GROUPS=true

# Permitir guilds con miembros de ambas facciones
ALLOW_TWO_SIDE_GUILDS=true

# Permitir usar la casa de subastas de la facción contraria.
# ⚠️  Esta variable se llamaba "comercio" y escribía AllowTwoSide.Interaction.Trade,
#     que NO EXISTE en el core: el intercambio directo entre facciones no se
#     puede activar por configuración (haría falta un módulo). Lo que sí existe,
#     y es lo que activa ahora, es la subasta compartida (.Interaction.Auction).
ALLOW_TWO_SIDE_TRADE=true

# ⚠️  SIN EFECTO: el core no tiene opción para el correo entre facciones. Se
#     conserva la variable para no romper configuraciones existentes, pero el
#     instalador ya no escribe ninguna clave con ella.
ALLOW_TWO_SIDE_MAIL=true

# Permitir chat entre facciones (say, yell y canales globales).
# ⚠️  El say/yell es AllowTwoSide.Interaction.Chat y NO se escribía: sólo se
#     ponía .Channel (los canales globales). O sea que el chat cruzado que esta
#     variable prometía llevaba todo este tiempo apagado. Ahora se escriben las dos.
ALLOW_TWO_SIDE_CHAT=true

# ⚠️  SIN EFECTO: tampoco hay opción de núcleo para /quién ni para la lista de
#     amigos entre facciones. Mismo caso que el correo.
ALLOW_TWO_SIDE_WHO=true

# ═══════════════════════════════════════════════════════════════════════════════
#  SERVIDOR — HERMANDADES
# ═══════════════════════════════════════════════════════════════════════════════

# Firmas necesarias en la carta para fundar una hermandad (MinPetitionSigns,
# clave del core, rango 0-9). Blizzard pide 9 (+ el fundador, 10 en total): en
# single player casi nunca hay 9 jugadores más de tu facción disponibles para
# firmar, y los bots aleatorios rechazan la firma si no calzan con tu facción
# en ese instante, así que nunca se llegaba a fundar ninguna. A 0 fundas tú
# solo. No toca mod-home-guild: ese módulo solo empieza a reclutar DESPUÉS de
# que la hermandad ya exista.
GUILD_MIN_PETITION_SIGNS=0

# ═══════════════════════════════════════════════════════════════════════════════
#  SERVIDOR — CORREO
# ═══════════════════════════════════════════════════════════════════════════════

# Refrescar el buzón en el momento en que te llega un correo estando conectado
# (Mail.PushInboxOnDelivery, core del 13/09/2026). El cliente guarda el buzón
# ~1 minuto y no vuelve a pedirlo: sin esto, un correo recién llegado (el aviso
# de mod-update-notice, la recompensa de congrats-on-level con las bolsas
# llenas...) no aparece al abrir el buzón hasta pasado ese minuto o un /reload.
# Cuesta un paquete de buzón por entrega; con un solo jugador no importa.
MAIL_PUSH_INBOX_ON_DELIVERY=true


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-PLAYERBOTS — CONFIGURACIÓN DE BOTS
# ═══════════════════════════════════════════════════════════════════════════════

# Número mínimo de bots aleatorios activos en el mundo cuando hay jugadores.
# ⚠️  Importa más de lo que parece: el módulo sube el número de conectados MUY
#     despacio (cambia el objetivo cada 30-120 minutos), así que en la práctica
#     el número de bots que hay en el mundo es este, no el máximo. Con 100 sólo
#     había 132 conectados de un tope de 250, y de nivel 80 apenas 22.
# 02/09/2026: de 200 a 400, para que mod-world-bots tenga de dónde sacar bots de
# tu tramo sin despoblar el resto del mundo. El coste lo contiene BOT_ACTIVE_ALONE
# (sólo un 10 % simula de verdad lejos de cualquier jugador).
BOTS_MIN=500   # mínimo de bots conectados (03/09/2026: 500 para llenar arenas, campos y colas sin esperas)

# Número máximo de bots aleatorios activos.
# ⚠️  Este número NO es sólo una cuestión de recursos: es cuántos bots llegan a
#     existir de verdad. El módulo despierta hasta este tope y les tira el dado
#     del nivel LA PRIMERA VEZ que entran; el resto se queda en la reserva a
#     nivel 1 sin estrenar. Con 150 había 653 personajes pero sólo 150
#     aleatorizados, y por eso las colas de cualquier nivel iban tan justas.
# 02/09/2026: de 250 a 500 (es lo que trae el dist del módulo). Con 153 bots el
# worldserver ocupaba 3,7 GB; la VM tiene 16. Vigilar la memoria tras el primer
# reinicio con este valor: INSTALL_ES.md parte 4 §6.
BOTS_MAX=600   # máximo (03/09/2026: 600)

# Escalado por jugador conectado (14/09/2026, 150→300 el mismo día: el
# usuario probó 150 y le pareció poco). BOTS_MIN/BOTS_MAX de arriba siguen
# yendo al .conf de playerbots como siempre (y son el valor al que se
# restaura si esto se apaga), pero en caliente mod-world-bots los pisa con
# BOTS_PER_PLAYER * jugadores reales conectados (tope BOTS_PER_PLAYER_CEILING,
# 600: con 300 y 2 jugadores ya se llega justo a ese tope). Servidor de una
# sola persona: con el fijo 500/600 se gastaba esa RAM las 24h que hubiera
# cualquiera dentro, fuera uno o varios. Con 300 y 1 jugador (el caso normal)
# quedan ~300 en vez de 500-600 -de los ~24 MB/bot medidos, la mitad-, y sin
# jugador DisabledWithoutRealPlayer sigue vaciando el mundo igual que antes,
# sin relación con esto. Bajar el objetivo no expulsa a nadie de golpe: sólo
# deja de admitir altas nuevas, la población de más drena sola por la
# rotación periódica (BOTS_PERIODIC_ONLINE_OFFLINE).
BOTS_PER_PLAYER_SCALE=true
BOTS_PER_PLAYER=300
BOTS_PER_PLAYER_CEILING=600
BOTS_PER_PLAYER_SYNC_SECONDS=60

# Cuentas de bot que mantiene el módulo (10 personajes cada una). Con 0 lo
# calcula playerbots a partir de BOTS_MAX en cada arranque (con BOTS_MAX=600
# le salen ~170) y crea las cuentas que falten solo. Fijarlo a mano por debajo
# de ese número no sirve: playerbots lo sube al valor calculado y avisa en el
# log ("RandomBotAccountCount=... es insuficiente"). Si se quiere fijar a mano
# para dar margen a subir BOTS_MAX luego, poner un valor >= 170.
BOTS_ACCOUNT_COUNT=0

# Nivel mínimo y máximo de los bots aleatorios
BOTS_LEVEL_MIN=1
BOTS_LEVEL_MAX=80

# Desactivar bots cuando no haya jugadores reales conectados.
# Se mantienen durante BOTS_NO_PLAYER_LOGOUT_DELAY antes de desconectarse.
BOTS_DISABLED_WITHOUT_PLAYER=true
# Segundos que los bots aleatorios esperan antes de salir tras desconectarse
# el ultimo jugador real (600 = 10 minutos).
BOTS_NO_PLAYER_LOGOUT_DELAY=600

# Los bots entran y salen por turnos, como gente real: de un conjunto el doble
# de grande que BOTS_MAX (ratio 2.0 → 1000 de los 1500 personajes) hay BOTS_MAX
# conectados en cada momento, y van rotando. Con el tiempo se estrenan más bots
# y la población cambia de un día a otro. Decidido el 02/09/2026.
BOTS_PERIODIC_ONLINE_OFFLINE=true
BOTS_PERIODIC_RATIO=2.0

# Porcentaje de bots que simula de verdad cuando no hay ningún jugador cerca.
# Es el mando "cuánto vive el mundo lejos de ti" contra CPU: los bots de TU zona
# se despiertan siempre (BotActiveAloneForceWhenInZone = 1, valor del dist), así
# que esto sólo afecta a los que están lejos. 10 es el valor del módulo; con
# 400-500 bots es lo que hace asumible el coste.
BOT_ACTIVE_ALONE=10

# Número máximo de bots propios que un jugador puede tener en grupo o banda.
# 40 es el máximo del módulo y NO se toca: con menos, las raids son imposibles.
# Con el valor anterior (4) sólo se podía formar un grupo de 5 — mazmorras sí,
# raids no — y con mod-individual-progression la progresión ES la raid: Núcleo
# de Magma, Cámara Negra, AQ40 y Naxx40 son de 40 jugadores.
# Es un TOPE, no una reserva: sólo consume CPU cuando los invocas de verdad.
BOTS_MAX_PER_PLAYER=40

# Auto-apuntado de bots a campos de batalla POR SU CUENTA.
# ⚠️  DESACTIVADO A PROPÓSITO cuando INSTALL_MOD_QUEUE_BOTS=true, y es la
#     diferencia entre que las colas funcionen o no. Este sistema intenta llenar
#     una batalla por cada tramo de nivel de cada campo de batalla —24 a la vez—
#     repartiendo entre todas ellas los bots conectados: con 150 bots no llena
#     ninguna, y de la cola en la que estás TÚ no sabe nada. mod-queue-bots hace
#     lo contrario: mete bots sólo en tu cola, y así basta con los que hay.
BOTS_AUTO_JOIN_BG=false

# Calidad máxima del equipo de los bots.
# 2=Verde  3=Azul  4=Épico
# ⚠️  A 4 a propósito. Con 3, los bots de nivel 80 salen vestidos de azul (se
#     comprobó: 672 piezas azules de 738), y un bot así ni aguanta Naxxramas ni
#     te hace sombra en un campo de batalla. Con mod-individual-progression el
#     contenido de este servidor son las bandas, así que el equipo de los bots
#     es lo que decide si son jugables o un lastre.
# ⚠️  El instalador escribía Playerbots.RandomBotMaxGearQuality, una clave que
#     NO EXISTE en esta versión del módulo: no la lee nadie. Las buenas son
#     RandomGearQualityLimit (equipo al aleatorizarse) y AutoGearQualityLimit
#     (equipo con el comando de auto-equipar).
BOTS_MAX_GEAR_QUALITY=4

# Dos pasadas al vestir a un bot en vez de una. La segunda rellena los huecos
# que dejó la primera, así que salen menos piezas blancas y menos ranuras
# vacías. Cuesta un poco más de CPU cada vez que un bot se estrena.
BOTS_GEAR_TWO_ROUNDS=true

# En un grupo con jugadores humanos, los bots esperan el voto de cada humano
# antes de tirar por un objeto: si algún humano pide necesidad, codicia o
# desencantar, todos los bots pasan; solo cuando todos los humanos
# participantes pasaron, los bots valoran el objeto con su criterio normal.
# Requiere el parche patches/mod-playerbots/04-loot-roll-real-players-priority.patch
# (fase 3); sin él aplicado, esta clave no la lee nadie. No afecta a grupos
# formados solo por bots, ni a Botín maestro/Todos por igual (los bots ya
# pasan siempre ahí).
# A true desde el 13/09/2026: parche 04 desplegado y compilado en la VM,
# activado para completar su validación en juego.
BOTS_LOOT_ROLL_AFTER_REAL_PLAYERS_PASS=true

# Los bots de tu grupo te susurran «Eating [objeto] (85%)» cada vez que comen,
# beben o usan un banquete. En single player, con compañeros de `.grupo` o de
# mazmorra, es ruido en el chat. A false: siguen comiendo y bebiendo igual, pero
# en silencio (Playerbots.AnnounceConsumableUse, de mod-playerbots desde el
# 05/10/2026; con el valor de fábrica, true, hablaban). UPD-B.
BOTS_ANNOUNCE_CONSUMABLE_USE=false

# ── Bots al nivel del jugador y colas cortas ─────────────────────────────────
# Limita el nivel máximo de los bots al del jugador de más nivel conectado.
# ⚠️  A false a propósito, por dos motivos:
#     1. Quien reparte bots a tu nivel ahora es mod-queue-bots, que los saca del
#        tramo de la cola en la que te metes. Un pozo repartido de 1 a 80 le
#        sirve para cualquier nivel; uno pegado a tu personaje de más nivel, no.
#     2. El tope que usa es "el nivel del jugador más alto conectado", y **sin
#        nadie conectado vale 1** (RandomPlayerbotMgr.cpp:1296). Con esto en
#        true, cualquier re-aleatorizado con el servidor vacío deja a TODOS los
#        bots a nivel 1. Además sólo sube durante la sesión, nunca baja.
BOTS_SYNC_LEVEL_WITH_PLAYERS=false

# Los bots usan el buscador de mazmorras (LFG/RDF), que es lo que hace que las
# colas de mazmorra se llenen solas.
BOTS_JOIN_LFG=true

# Porcentaje de bots que se quedan clavados en el nivel mínimo y en el máximo
# al crearse. El módulo trae 0.1 (10% + 10%), lo que amontona bots en el 1 y en
# el tope y deja los niveles intermedios pelados. A 0 se reparten de forma
# uniforme, que es lo que interesa para encontrar grupo a cualquier nivel.
BOTS_MIN_LEVEL_CHANCE=0.0
# El nivel máximo es el único tramo de UN SOLO nivel: con el reparto uniforme le
# tocan ~8 personajes de 653 (y había 3, ninguno de la Horda), así que a nivel 80
# no salía ni un campo de batalla ni una mazmorra. Un 10% clavado ahí tapa ese
# agujero sin despoblar el resto de niveles.
BOTS_MAX_LEVEL_CHANCE=0.35

# Apuntar bots a battlegrounds en TODOS los rangos de nivel, no solo en el más
# alto. El módulo trae solo el bracket máximo de cada BG (WS=7, AB=6, AV=3,
# EY=2, IC=1), así que por debajo del nivel 70 las colas no arrancaban nunca.
BOTS_BG_ALL_BRACKETS=true

# Cuántos bots se apuntan por bracket y battleground. Subirlo acorta la cola
# pero consume más CPU.
BOTS_BG_PER_BRACKET=1

# ── Reparto de bots por franja de nivel ──────────────────────────────────────
# Reparte la población de bots por franjas de diez niveles y, con distribución
# dinámica, la sesga hacia la franja donde estás TÚ.
#
# HISTORIA, porque importa: esto estuvo en false mucho tiempo y con razón. El
# sistema NO existía en la versión de mod-playerbots que había fijada, así que
# las claves Playerbots.LevelBrackets.* que el instalador escribía no las leía
# nadie — y encima se había apagado (a 0.0) el único mecanismo que sí funcionaba,
# el MIN/MAX_LEVEL_CHANCE de arriba. Resultado: ni un bot de nivel 80.
#
# Ya no es el caso. Se integró en playerbots el 07/08/2026 (PR #2558, el port de
# mod-player-bot-level-brackets) y la versión que fijamos ahora sí lo trae:
# comprobado clave por clave contra su conf.dist.
#
# La guarda de la fase 5 sigue en pie (grep 'LevelBrackets' sobre el código del
# módulo antes de escribir nada), así que si algún día se revierte, se apaga sola.
#
# ⚠️  Contrapartida real: para mover un bot de una franja a otra lo RE-RULA
#     entero con PlayerbotFactory::Randomize() — nivel, equipo, talentos y
#     misiones de ese bot. Es el mismo efecto que 'rndbot init', pero por goteo.
#     No afecta a tu personaje. Si notas que los bots cambian demasiado, ponlo
#     en false: no hace falta recompilar, basta ./install.sh --only 5.
BOTS_LEVEL_BRACKETS=true

# Reparto DINÁMICO de franjas. En el perfil SP está activo para que la población
# siga al jugador real, en lugar de reservar medio servidor en nivel 80 para el
# antiguo entrenamiento de mod-adaptive-ai.
BOTS_LEVEL_BRACKETS_DYNAMIC=true

# Peso de respaldo para el reparto dinámico. Con el parche HighestPlayerOnly
# activo no decide los porcentajes; 1000 conserva el resultado SP si el parche
# no llegase a aplicarse y sólo hay un humano conectado.
BOTS_LEVEL_BRACKETS_PLAYER_WEIGHT=1000.0

# En el perfil SP, todas las facciones siguen exclusivamente el bracket del
# jugador real conectado de mayor nivel. Requiere el parche local de
# mod-playerbots; si el parche faltase, el peso 1000 mantiene el mismo resultado
# con un único jugador conectado.
BOTS_LEVEL_BRACKETS_HIGHEST_ONLY=true
BOTS_LEVEL_BRACKETS_SYNC_FACTIONS=true

# Cuota fija de nivel 80 retirada. Cero conserva la plantilla uniforme al
# regenerar el conf; con el reparto dinámico activo tampoco gobierna el runtime.
BOTS_LEVEL80_PCT=0

# Cuánto se queda un bot en el mundo antes de que se le pueda rotar (segundos).
# El .conf.dist del módulo trae 600 (10 min) y el código de playerbots usa 7200
# por defecto. Con 10 minutos hay trasiego constante y cada re-entrada de un bot
# de entrenamiento cuesta un Randomize completo (03/09/2026).
BOTS_WORLD_TIME_MIN=7200
BOTS_WORLD_TIME_MAX=28800

# ── Arenas puntuadas ─────────────────────────────────────────────────────────
# El módulo crea equipos de arena de bots (10 de 2c2, 10 de 3c3, 5 de 5c5) pero
# de fábrica NO los apunta a ninguna partida, así que la arena puntuada nunca
# arranca. Estos son los combates que se ponen en cola por ciclo.
# Sólo aplica al nivel 80 (la arena es de nivel máximo).
BOTS_ARENA_RATED_2V2=2
BOTS_ARENA_RATED_3V3=2
BOTS_ARENA_RATED_5V5=1

# ── Mundo vivo ───────────────────────────────────────────────────────────────
# Las hermandades de bots pueden invitarte. Con 20 hermandades de bots en el
# mundo, esto hace que el servidor se sienta habitado. mod-home-guild no cambia
# esta decisión: puedes aceptar una invitación o fundar tu propia hermandad.
BOTS_GUILD_INVITE_PLAYER=true

# Limitar los talentos de los bots a la expansión de la fase de progresión.
# El equipo y los encantamientos ya vienen limitados por defecto; los talentos no.
BOTS_LIMIT_TALENTS_EXPANSION=true

# Permiso para convertir tu propio personaje/alt en bot ("selfbot"):
#   0 = desactivado   1 = sólo GM (valor del módulo)
#   2 = todos los jugadores   3 = activar al conectar
# En 2, cualquiera puede usar sus alts como compañeros — muy útil jugando solo.
BOTS_SELFBOT_LEVEL=2


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-AUTOBALANCE — DIFICULTAD DE INSTANCIAS
# ═══════════════════════════════════════════════════════════════════════════════

# Activar escalado de dificultad en instancias de 5 jugadores
AUTOBALANCE_ENABLED=true

# Activar escalado también en raids
AUTOBALANCE_RAIDS=true

# Punto de inflexión de la curva de dificultad (0.0 - 1.0)
# 0.5 = curva equilibrada (recomendado)
# Valores más bajos = más fácil jugando solo
AUTOBALANCE_INFLECTION=0.5

# Multiplicador de vida de los mobs escalados (1.0 = sin cambio)
AUTOBALANCE_RATE_HEALTH=1.0

# Multiplicador de daño de los mobs escalados
AUTOBALANCE_RATE_DAMAGE=1.0


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-AH-BOT-PLUS — CASA DE SUBASTAS
# ═══════════════════════════════════════════════════════════════════════════════

# El instalador configura este módulo por completo: crea una cuenta de servicio
# (NO logueable: se le da un verifier aleatorio) y los personajes vendedores,
# y escribe sus GUID en AuctionHouseBot.GUIDs. No tienes que hacer nada a mano.
#
# Nombre de la cuenta de servicio del bot.
AH_BOT_ACCOUNT="AHBOT"

# Nombres de los personajes vendedores. Son los que verán los jugadores como
# vendedores en la Casa de Subastas, así que ponles nombres creíbles.
# Se crea uno por facción para que ambas AH tengan oferta.
AH_BOT_CHAR_ALLIANCE="Aurelian"
AH_BOT_CHAR_HORDE="Grimtusk"

# GUID base de los personajes del bot. Se usa un rango muy alto a propósito
# para no chocar nunca con los personajes reales ni con los de playerbots.
AH_BOT_GUID_BASE=9000001

# Items que el bot añade a la Casa de Subastas por ciclo de actualización.
# Más alto = AH se llena más rápido pero consume más CPU.
AH_ITEMS_PER_CYCLE=75

# Activar comprador automático (el bot compra items de jugadores)
AH_BUYER_ENABLED=true

# Cuántos items evalúa el comprador en cada ciclo (1 por Casa de Subastas).
AH_BUYER_CANDIDATES_PER_CYCLE=1

# Multiplicador sobre el precio calculado que el comprador acepta pagar.
# 1.0 = paga el precio que él mismo calcula; <1 tacaño; >1 generoso.
AH_BUYER_PRICE_MODIFIER=1.0

# Permitir que el bot puje contra pujas de jugadores reales.
AH_BUYER_BID_AGAINST_PLAYERS=false

# Hacer que armas, armaduras y recetas respeten su rareza real de drop al
# poblar la AH, en vez de ofrecer un catálogo plano de objetos raros.
AH_USE_DROP_RATES=true

# Poner items de calidad épica en la AH (true/false).
# En false, el instalador pone a 0 la proporción de épicos de armas y armaduras;
# en true se respetan las proporciones "blizzlike" que trae el módulo.
AH_SELL_EPICS=true


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-TRANSMOG — TRANSMOGRIFICACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

# Permitir mezcla de tipos de arma: 0=Estricto  1=Similar  2=Libre
TRANSMOG_MIXED_WEAPONS=1

# Permitir ocultar slots de equipo (hacerlos invisibles)
TRANSMOG_ALLOW_HIDDEN=true

# Coste del transmog en cobre (0 = gratis, 10000 = 1 gold)
TRANSMOG_COST=0


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-INDIVIDUAL-PROGRESSION — RITMO DE LA PROGRESIÓN
#  Vanilla → TBC → WotLK por personaje. Estos valores buscan una progresión
#  entretenida en un servidor pequeño con bots, no una réplica exacta del
#  calendario original de Blizzard.
# ═══════════════════════════════════════════════════════════════════════════════

# Fase en la que empiezan los personajes nuevos (0 = Vanilla desde el principio)
IP_STARTING_PROGRESSION=0

# Fase máxima alcanzable (0 = sin límite, hasta completar WotLK)
IP_PROGRESSION_LIMIT=0

# Exigir que todo el grupo vaya en la misma fase de progresión.
# En false podéis jugar juntos aunque cada uno vaya por su sitio — casi
# obligatorio en un servidor de pocos amigos.
IP_ENFORCE_GROUP_RULES=false

# Desactivar el buscador de mazmorras (RDF).
# En false el RDF sigue activo: combinado con los bots, las colas son cortas.
IP_DISABLE_RDF=false

# Ocultar los signos de exclamación/interrogación de las quests.
# El módulo lo activa para dar sensación "vanilla clásico"; en false se ven,
# que es bastante más cómodo si no vas buscando purismo.
IP_DISABLE_QUEST_MARKERS=false

# Exigir matar a TODOS los jefes de Caverna Serpiente y La Cámara del Ojo
# antes de los jefes finales. En false se evita un grindeo largo con bots.
IP_REQUIRE_ALL_BOSSES_SSC=false
IP_REQUIRE_ALL_BOSSES_TK=false

# Permitir acceso temprano al set 2 de mazmorra y a los jefes de la Plaga.
# Da más contenido disponible en cada fase.
IP_ALLOW_EARLY_DUNGEON_SET2=true
IP_ALLOW_EARLY_SCOURGE_BOSSES=true

# Arreglo de XP de quests y XP por quests vanilla repetibles (recomendado)
IP_QUEST_XP_FIX=true
IP_REPEATABLE_VANILLA_QUESTS_XP=true

# ── Naxxramas 40 accesible con grupo pequeño ─────────────────────────────────
# Cuatro jefes de Naxx40 están diseñados para 40 jugadores repartiéndose tareas
# y no se superan con un grupo pequeño por mucho que autobalance escale la vida:
# el problema es de mecánica, no de números. Con esto activado:
#   4H        → los Cuatro Jinetes pegan mucho menos y se pueden pelear juntos
#   Gluth     → busca zombi cada 12s en vez de cada 3
#   Patchwerk → Golpe Odioso hace el 80% del daño
#   Razuvious → lanza Grito perturbador en vez de Quemadura de maná
# La propia documentación del módulo menciona a los bots: no salen del daño en
# área hasta que ya lo están recibiendo.
IP_DOABLE_NAXX40_4H=true
IP_DOABLE_NAXX40_GLUTH=true
IP_DOABLE_NAXX40_PATCHWERK=true
IP_DOABLE_NAXX40_RAZUVIOUS=true

# ── Dificultad del mundo antiguo ─────────────────────────────────────────────
# Ajustan el poder y la sanación del jugador durante Vanilla y TBC para simular
# la dificultad original de la época. En true (valor del módulo) el mundo antiguo
# se siente como entonces; en false pegas como un personaje de WotLK.
IP_VANILLA_POWER_ADJUSTMENT=true
IP_VANILLA_HEALING_ADJUSTMENT=true
IP_TBC_POWER_ADJUSTMENT=true
IP_TBC_HEALING_ADJUSTMENT=true

# Runas del Núcleo de Magma gestionadas a mano (true = comportamiento original:
# hay que apagar las runas con Quintaesencia). El SQL opcional
# "small_group_adjustments" (ver IP_OPTIONAL_SQL) da acceso temprano a la
# Quintaesencia Eterna, que es lo que hace esto llevadero jugando solo.
IP_MC_MANUAL_RUNE_HANDLING=true

# Exigir la entrada a Naxxramas por Stratholme (false = entrada directa)
IP_REQUIRE_NAXX_STRATH_ENTRANCE=false

# Fase de progresión necesaria para entrar en Zul'Gurub y Zul'Aman
IP_REQUIRED_ZG_PROGRESSION=3
IP_REQUIRED_ZA_PROGRESSION=12

# Fase en la que se desbloquean Draenei y Elfos de Sangre, y el Caballero de la
# Muerte. 0 = disponibles desde el principio.
# ⚠️  Con mod-arac activo conviene dejar las razas TBC a 0: si no, las
#     combinaciones raza/clase que ARAC habilita quedan a medias hasta TBC.
IP_TBC_RACES_UNLOCK_PROGRESSION=0
IP_TBC_RACES_STARTING_PROGRESSION=0
IP_DK_UNLOCK_PROGRESSION=13
IP_DK_STARTING_PROGRESSION=13

# ── Títulos PvP vanilla (sustituyen a mod-pvp-titles) ────────────────────────
# Honorable Kills necesarios para cada uno de los 14 rangos. Los valores son los
# del módulo; se dividen entre IP_PVP_RANK_DIVISOR para que sean alcanzables en
# un servidor pequeño (1 = umbrales originales, 2 = la mitad, 4 = un cuarto...).
IP_PVP_RANK_DIVISOR=4

# Mantener los títulos ya ganados al salir de la fase vanilla
IP_PVP_TITLES_PERSIST=true

# ── SQL opcional del módulo ──────────────────────────────────────────────────
# El módulo trae 22 ficheros SQL opcionales en optional/sql/world/ que cambian
# contenido del mundo. Aquí se listan los que se aplican, sin el prefijo
# "zz_optional_" ni la extensión. Lista completa disponible:
#   ammo_stack_size, aq_quest_nerf, av_landmines, creature_stats,
#   item_stack_sizes, limit_spells_to_expansion, phasing, remove_heirlooms,
#   restore_crafting_cd_timers, restore_potion_cd, restore_rogue_poisons,
#   small_group_adjustments, spell_damage_and_healing, stackable_buff_scrolls,
#   tbc_heroic_dungeon_keys_nerf, tbc_pvp_prices, unobtainable_items,
#   vanilla_crafting_requirements, vanilla_models, vanilla_regen_values,
#   vanilla_transports, wotlk_hp_values_for_tbc_raids
#
# small_group_adjustments es EL importante: está escrito literalmente para este
# caso (raids de 40 completadas por un grupo pequeño con autobalance y bots).
IP_OPTIONAL_SQL=(
    small_group_adjustments
    vanilla_models
    restore_rogue_poisons
    vanilla_crafting_requirements
)

# ── DBC opcionales del módulo ────────────────────────────────────────────────
# Restauran hechizos, recetas y reactivos de Vanilla/TBC en el SERVIDOR.
# ⚠️  SkillRaceClassInfo.dbc NUNCA se copia si mod-arac está activo: ambos
#     módulos traen ese fichero y el de ARAC es el que permite razas/clases
#     cruzadas. El instalador ya aplica esa regla solo.
# Paso de cliente opcional (no automatizable): copiar patch-V.mpq a WoW/Data/
IP_OPTIONAL_DBC=true


# ═══════════════════════════════════════════════════════════════════════════════
#  RENDIMIENTO
# ═══════════════════════════════════════════════════════════════════════════════

# Threads de actualización de mapas.
# Recomendado: núcleos_físicos / 2  (para Ryzen 7730U de 8 núcleos → 4)
MAP_UPDATE_THREADS=4

# Distancia de visibilidad en los continentes (yardas). El core trae 100. Con
# mod-world-bots soltando bots a 250 yardas, 160 hace que los veas antes de
# llegar a ellos sin que aparezcan de golpe. Más distancia = más objetos que
# actualizar para cada jugador; 180 es un tope razonable.
VISIBILITY_DISTANCE_CONTINENTS=160

# Tamaño del buffer pool de InnoDB en GB.
# Recomendado: 25% de la RAM de la VM  (para 16 GB de VM → 4)
MYSQL_BUFFER_POOL_GB=4


# ═══════════════════════════════════════════════════════════════════════════════
#  AUTOMATIZACIÓN — REINICIOS Y ACTUALIZACIONES
# ═══════════════════════════════════════════════════════════════════════════════

# Hora del reinicio diario del servidor WoW (formato 24h)
# El aviso a jugadores se envía 5 minutos antes
CRON_DAILY_RESTART_HOUR=0     # 0 = medianoche
CRON_DAILY_RESTART_MIN=0

# 14/09/2026: con true, el reinicio diario de arriba deja de ser un reinicio
# de servicios (daily-restart.sh: systemctl stop/start de authserver y
# worldserver) y pasa a ser un "sudo reboot" de la VM entera, igual que el
# reinicio semanal de más abajo. daily-restart.sh sólo libera la memoria del
# propio worldserver, y encima con WORLDSERVER_STANDBY activo (el caso
# normal) ni eso: a medianoche casi siempre está dormido y el script no hace
# nada ("Worldserver dormido: no se reinicia nada"). Lo que NO se libera ni
# una vez al día es MySQL, el panel (Node) y la cache de página del kernel;
# antes sólo se soltaba una vez a la semana (CRON_WEEKLY_REBOOT). safe-stop.sh
# ya está preparado para que lo dispare `sudo reboot` (es su ExecStop, avisa
# 60s y hace saveall igual que un reinicio de servicio) tanto en modo clásico
# como en espera, así que no hace falta ningún aviso previo aparte. A
# diferencia de daily-restart.sh, esto NO se salta aunque el worldserver esté
# dormido -es justo lo que libera la memoria del sistema esas noches-, igual
# que ya hace sin condición ninguna el reinicio semanal de más abajo.
# En false vuelve al reinicio de servicios de siempre (daily-restart.sh).
CRON_DAILY_RESTART_FULL_REBOOT=true

# Hora de la actualización semanal (git pull + recompilación si hay cambios)
# Se ejecuta los domingos
CRON_WEEKLY_UPDATE_HOUR=3
CRON_WEEKLY_UPDATE_MIN=0

# Hora del reinicio semanal completo de la VM (domingos)
# Debe ser DESPUÉS de la actualización semanal
CRON_WEEKLY_REBOOT_HOUR=5
CRON_WEEKLY_REBOOT_MIN=0


# ═══════════════════════════════════════════════════════════════════════════════
#  MODO EN ESPERA — APAGAR EL WORLDSERVER CUANDO NO HAY NADIE
# ═══════════════════════════════════════════════════════════════════════════════
#
#  El servidor es de una sola persona. Con 200-400 bots dentro gasta ~6 GB y
#  ~270 % de CPU las 24 horas aunque nadie juegue. Con esto activado:
#
#   1. worldserver.conf pone Network.UseSocketActivation = 1. El core hereda el
#      socket del puerto 8085 de systemd en vez de abrirlo él, y NO marca el
#      reino como desconectado al cerrarse (el cliente lo sigue viendo).
#   2. La unidad ac-worldserver.service pasa a ejecutar el binario directamente
#      (sin screen ni restarter) con Restart=on-failure, y hay una unidad
#      ac-worldserver.socket que posee el 8085 y arranca el worldserver a la
#      primera conexión de un cliente.
#   3. El módulo propio mod-standby apaga el worldserver (salida limpia, código
#      0 → systemd no lo revive) cuando lleva STANDBY_IDLE_MINUTES sin ninguna
#      sesión humana. authserver, MySQL, el panel y la VM siguen en pie.
#
#  Coste: la PRIMERA conexión tras dormir puede tardar lo que tarde un arranque
#  en frío (~1-2 min); si el cliente se cansa antes, vuelve a la lista de reinos
#  y al reseleccionar ya está arrancado. Las siguientes son instantáneas.
#
#  En false vuelve a la instalación clásica (screen + Restart=always, el
#  worldserver siempre encendido).

WORLDSERVER_STANDBY=true

# Minutos sin ninguna sesión humana (juego o pantalla de personajes; los bots
# no cuentan) antes de apagar el worldserver. Con BOTS_NO_PLAYER_LOGOUT_DELAY
# en 600 s (10 min), a los 15 los bots ya han salido solos.
STANDBY_IDLE_MINUTES=15

# Segundos de cuenta atrás (con aviso) antes de cerrar. 0 = cerrar de inmediato.
STANDBY_WARN_SECONDS=60

# El módulo no apaga el servidor durante estos minutos tras arrancar: cubre el
# cuelgue del primer arranque con muchas cuentas de bots y da margen a que el
# jugador que lo despertó termine de entrar.
STANDBY_MIN_UPTIME_MINUTES=10

# Cada cuántos segundos se cuenta la población humana (durante una cuenta atrás
# pasa a cada tick para poder cancelarla a tiempo).
STANDBY_CHECK_SECONDS=30

# El módulo mod-standby sigue a WORLDSERVER_STANDBY.
INSTALL_MOD_STANDBY="$WORLDSERVER_STANDBY"


# ═══════════════════════════════════════════════════════════════════════════════
#  VERSIONES — QUÉ VERSIÓN DE CADA REPOSITORIO SE INSTALA
#
#  El core y los módulos son repositorios de terceros que cambian a diario. Una
#  actualización automática puede romperte el servidor un domingo de madrugada
#  sin que te enteres hasta el lunes.
#
#  versions.lock guarda el commit EXACTO de cada repositorio con el que sabemos
#  que este servidor funciona. Es tu punto de retorno.
# ═══════════════════════════════════════════════════════════════════════════════

# Clavar cada repositorio al commit anotado en versions.lock.
# true  = instalas siempre la combinación conocida como buena (recomendado)
# false = cada repositorio se queda en la última versión de su rama
PIN_VERSIONS=true

# Si un pin de versions.lock o un parche de patches/ no se puede aplicar, la
# fase 3 aborta (salida distinta de cero): arrancar con una combinación de
# versiones no probada, o sin un parche que corrige un bug conocido, es
# justo lo que este mecanismo existe para evitar.
# true = solo avisa y sigue. SOLO para depuración puntual en desarrollo —
#        nunca lo dejes activo en una instalación real.
ALLOW_PIN_OR_PATCH_FAILURE=false

# Qué hace la tarea semanal de los domingos:
#   "check" = solo MIRA si hay versiones nuevas y avisa. No toca nada.
#             Actualizar pasa a ser una decisión tuya. (recomendado)
#   "apply" = comportamiento antiguo: descarga, recompila y reinicia solo.
WEEKLY_UPDATE_MODE="check"

# Avisar a las cuentas GM cuando haya versiones nuevas. El aviso llega como
# correo dentro del juego, así que lo ves al conectarte ("Tienes correo nuevo").
NOTIFY_GM_ON_UPDATE=true

# Nivel de GM mínimo que recibe el aviso (3 = administrador)
GM_NOTIFY_MIN_LEVEL=3

# ── Copias offline de los repositorios (mirrors/) ────────────────────────────
# versions.lock fija el commit exacto, pero eso solo vale mientras el
# repositorio siga existiendo. Varios módulos son proyectos de una sola
# persona: si alguien archiva, renombra o borra el suyo, la instalación deja de
# poder reproducirse. mirrors/ guarda un .tar.gz del árbol en el commit fijado,
# y la fase 3 tira de ahí automáticamente si el clonado falla.
#
# Se regeneran con: ./install.sh --mirror
MIRROR_REPOS=true

# Incluir también el core en las copias.
# Son ~211 MB, así que el repositorio del instalador pesa lo suyo. Aquí está en
# true porque este proyecto se aloja en un Gitea propio, sin el límite de 100 MB
# por fichero que impone GitHub. Si algún día lo mueves a GitHub, o lo pones en
# false y le haces un fork al core en tu cuenta, o usarás Git LFS.
MIRROR_INCLUDE_CORE=true

# Asset de versión desde el que ./install.sh --hidratar puede descargar los
# snapshots antes de reconstruirlos desde el upstream (opcional, https://; vacío
# = sólo el upstream). Se descarga <URL>/<fichero de MANIFEST.tsv> y se acepta
# únicamente si su SHA-256 cuadra con el manifiesto. Si el asset no existe, se
# reconstruye desde el upstream como siempre.
MIRROR_ASSET_BASE_URL="https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer/releases/download/snapshots"


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-RANDOM-ENCHANTS — ENCANTAMIENTOS ALEATORIOS
# ═══════════════════════════════════════════════════════════════════════════════

# Mostrar un mensaje al hacer login explicando que el módulo está activo
RANDOM_ENCHANTS_ANNOUNCE=true

# Probabilidad (%) de aplicar el primer / segundo / tercer encantamiento
# (el segundo solo se evalúa si se aplicó el primero, y así sucesivamente)
RANDOM_ENCHANTS_CHANCE_1=25.0
RANDOM_ENCHANTS_CHANCE_2=20.0
RANDOM_ENCHANTS_CHANCE_3=10.0

# ── Escalado por nivel del personaje ─────────────────────────────────────────
# El módulo original elegía el "tier" del encantamiento SOLO por la calidad del
# objeto, de modo que un arma verde de una quest de nivel 10 podía llevar un
# encantamiento pensado para nivel 80. Además su consulta SQL tenía la
# precedencia rota y el filtro de tier no se aplicaba nunca.
# El instalador parchea ambas cosas (patches/mod-random-enchants/) y añade
# estas opciones: la calidad sigue mandando hacia abajo, pero el tier nunca
# sube por encima de lo que corresponde al nivel del personaje.
RANDOM_ENCHANTS_SCALE_WITH_LEVEL=true

# Nivel mínimo del personaje para que puedan salir encantamientos de cada tier.
# Por debajo del primer umbral solo salen de tier 1.
RANDOM_ENCHANTS_TIER2_MIN_LEVEL=20
RANDOM_ENCHANTS_TIER3_MIN_LEVEL=40
RANDOM_ENCHANTS_TIER4_MIN_LEVEL=60
RANDOM_ENCHANTS_TIER5_MIN_LEVEL=71



# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-CHALLENGE-MODES — MODOS DE DESAFÍO POR PERSONAJE
#  Se activan en el "Santuario del Desafío" que aparece solo junto al cementerio
#  de cada zona inicial, y sólo a nivel 1 (55 en Caballero de la Muerte).
#  Se pueden combinar varios en el mismo personaje si no se contradicen.
# ═══════════════════════════════════════════════════════════════════════════════

# Cada desafío se puede activar o desactivar por separado
CM_HARDCORE=true            # Al morir te quedas en espíritu para siempre
CM_SEMI_HARDCORE=true       # Al morir pierdes el equipo puesto y el oro
CM_SELF_CRAFTED=true        # Sólo puedes llevar equipo fabricado por ti
CM_ITEM_QUALITY=true        # Sólo equipo de calidad Normal o Pobre
CM_SLOW_XP=true             # XP x0.5
CM_VERY_SLOW_XP=true        # XP x0.25
CM_QUEST_XP_ONLY=true       # Sólo ganas XP con misiones
CM_IRON_MAN=true            # Reglas Iron Man completas

# Recompensas por llegar a ciertos niveles con el desafío activo.
# Formato: "nivel puntos, nivel puntos, ..." (puntos de talento adicionales).
# Es la recompensa más segura: no depende de IDs de objetos ni de títulos, que
# cambian entre parches. Para dar objetos o títulos, el módulo admite además
# <Desafío>.ItemRewards e <Desafío>.TitleRewards — ver su conf.
CM_TALENTS_HARDCORE="40 1, 60 1, 70 1, 80 2"
CM_TALENTS_SEMI_HARDCORE="40 1, 60 1, 80 1"
CM_TALENTS_SELF_CRAFTED="40 1, 60 1, 80 1"
CM_TALENTS_ITEM_QUALITY="40 1, 60 1, 80 2"
CM_TALENTS_SLOW_XP="40 1, 60 1, 80 1"
CM_TALENTS_VERY_SLOW_XP="40 1, 60 1, 70 1, 80 2"
CM_TALENTS_QUEST_XP_ONLY="40 1, 60 1, 80 1"
CM_TALENTS_IRON_MAN="40 1, 60 1, 70 1, 80 3"

# Multiplicador de XP mientras el desafío está activo (compensación por la
# dificultad extra). No aplica a los desafíos de XP lenta, que ya la modifican.
CM_XP_MULT_HARDCORE=1.25
CM_XP_MULT_SEMI_HARDCORE=1.10
CM_XP_MULT_SELF_CRAFTED=1.10
CM_XP_MULT_ITEM_QUALITY=1.15
CM_XP_MULT_IRON_MAN=1.25


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-INSTANCED-WORLDBOSSES — JEFES DE MUNDO POR GRUPO
# ═══════════════════════════════════════════════════════════════════════════════

# Segundos hasta que el jefe vuelve a estar disponible para tu grupo
# (25920 = 3 días, el valor del módulo)
IWB_RESET_TIMER_SECS=25920

# Segundos hasta que el jefe reaparece tras morir
IWB_RESPAWN_TIMER_SECS=3600

# Sacar de fase a los jugadores al entrar en combate con el jefe. Es lo que hace
# que el jefe sea REALMENTE tuyo y no te lo quite nadie (ni un bot).
IWB_PHASE_BOSSES=true


# ═══════════════════════════════════════════════════════════════════════════════
#  MOD-WAR-EFFORT — ESFUERZO DE GUERRA DE AHN'QIRAJ
#  Entregas acumulativas de materiales en 5 fases para abrir las puertas.
# ═══════════════════════════════════════════════════════════════════════════════

# Multiplicador sobre los objetivos de cada fase. El módulo trae de fábrica
# 5/10/15/20/25 unidades por material y fase, que un solo jugador puede reunir.
#   1 = objetivos originales del módulo (recomendado jugando solo)
#   4 = cuatro veces más material (para un grupo de amigos)
WAR_EFFORT_GOAL_SCALE=1

# Objetivos base por fase (se multiplican por WAR_EFFORT_GOAL_SCALE).
# Se aplican a los 5 tipos de material: vendas, comida, hierbas, metal y cuero.
WAR_EFFORT_GOALS=(5 10 15 20 25)


# ═══════════════════════════════════════════════════════════════════════════════
#  MÓDULOS DE SERVICIO — AJUSTES
# ═══════════════════════════════════════════════════════════════════════════════

# ── mod-racial-trait-swap ────────────────────────────────────────────────────
# Coste en ORO de cambiar el rasgo racial
RACIAL_SWAP_GOLD=10

# ── mod-aoe-loot ─────────────────────────────────────────────────────────────
AOE_LOOT_RANGE=55.0        # Radio en yardas
AOE_LOOT_GROUP=true        # Funciona también en grupo

# SP04: una copia de los objetos blancos de quest_items para cada miembro
# presente y elegible del grupo. En solitario conserva el botín del core.
QUEST_LOOT_PARTY_ENABLE=true
QUEST_LOOT_PARTY_MESSAGE=false

# ── mod-instance-reset ───────────────────────────────────────────────────────
# Cómo se paga el reinicio de instancia:
#   0 = gratis   1 = con emblemas   2 = con oro (recomendado)   3 = ambos
# ⚠️  El módulo viene GRATIS de fábrica. Reiniciar sin coste permite granjear la
#     misma raid en bucle y se carga el ritmo de progresión del servidor.
INSTANCE_RESET_PAYMENT=2
INSTANCE_RESET_MONEY=2500000      # En cobre (2500000 = 250 oro)
INSTANCE_RESET_TOKEN_ID=49426     # Emblema de Escarcha
INSTANCE_RESET_TOKEN_COUNT=26
INSTANCE_RESET_NORMAL_ONLY=false  # true = sólo instancias en modo normal

# ── mod-1v1-arena ────────────────────────────────────────────────────────────
ARENA_1V1_MIN_LEVEL=80
ARENA_1V1_COST=400000             # En cobre (400000 = 40 oro) para crear el equipo
ARENA_1V1_POINTS_MULT=0.64        # Multiplicador de puntos de arena

# Segundos que mod-queue-bots espera antes de meter bots en tu cola, por si
# aparece gente de verdad. Con 0 entran en cuanto te encolas.
QUEUE_BOTS_DELAY=0

# Tope de bots que te mete en la banda el buscador de bandas. No puede pasar de
# BOTS_MAX_PER_PLAYER.
QUEUE_BOTS_MAX_RAID=39

# Tanques y sanadores que se aseguran en una banda antes de meter gente de daño.
# Con 0 se decide por el tamaño: 2 y 3 para diez, 3 y 6 para veinticinco, y 5 y
# 12 para cuarenta (vanilla pedía mucho más sanador que WotLK). Tú cuentas: si
# vas de tanque, hace falta uno menos.
# ⚠️  Si los pones a mano, el número vale para TODOS los tamaños por igual.
QUEUE_BOTS_RAID_TANKS=0
QUEUE_BOTS_RAID_HEALERS=0

# Segundos tras unirse a tu banda (buscador de bandas) hasta que el bot se
# teletransporta a tu lado. A veces no vienen solos (otro continente, o su IA
# no arranca el "seguir"); esto los trae con un retardo y sin hacerlo en
# combate. 0 = nunca. Visto en el juego el 02/09/2026.
QUEUE_BOTS_RAID_SUMMON_DELAY=8

# Despertar bots dormidos cuando la cola en la que te metes pide más de los que
# hay en el mundo. El servidor tiene ~1500 personajes de bot pero mantiene
# despiertos muchos menos, y sube ese número muy despacio: sin esto te encolas a
# un campo de batalla de nivel 80 y se queda a medias esperando.
QUEUE_BOTS_WAKE=true

# Tope de bots que se despiertan de una vez.
QUEUE_BOTS_WAKE_MAX=40

# Tamaño de banda que forma el buscador de bandas. Con 0 se deduce de tu ajuste
# de dificultad de banda (10 o 25), porque el tablón de 3.3.5 no guarda a qué
# banda te apuntaste. Ponlo a 40 para las bandas de 40 de vanilla.
QUEUE_BOTS_RAID_SIZE=0

# Segundos que se le dan a la IA del bot para aceptar la invitación a la partida
# antes de meterle a la fuerza.
# ⚠️  No bajarlo. La invitación dura 60 s y es al aceptarla cuando playerbots le
#     configura las estrategias de combate del campo de batalla. Entrándole a la
#     fuerza antes de tiempo, el bot llega a la partida y se queda quieto.
QUEUE_BOTS_FORCE_ACCEPT_AFTER=40

# Activar mod-dungeon-clear solo cuando el grupo del buscador ya está dentro de
# la mazmorra (todos en el mismo mapa, tanque bot presente, tú no eres el
# tanque), pasados estos segundos. Es lo que hace que "esté activo por defecto":
# el módulo en sí sólo arranca con ".dc on".
QUEUE_BOTS_DUNGEON_CLEAR_AUTO=true
QUEUE_BOTS_DUNGEON_CLEAR_DELAY=10
QUEUE_BOTS_DUNGEON_CLEAR_TRIES=3

# mod-dungeon-clear se autodesactiva tras un wipe, una muerte que nadie puede
# resucitar o un rez que se agota, y pide ".dc on" manual para retomar (no hay
# forma de reenganchar esto a "entrar en la mazmorra": revivir es la MISMA
# instancia, sin evento de entrada). En cuanto el grupo se repone (todos con
# vida) se reabre una tanda de reintentos igual a la de la entrada, tras este
# margen en segundos. No distingue esto de un ".dc off" tuyo justo entonces.
QUEUE_BOTS_DUNGEON_CLEAR_REVIVE_DELAY=8

# Composicion del grupo de cinco del buscador de mazmorras (tu cuentas: si vas
# de sanador, se busca uno menos).
QUEUE_BOTS_DUNGEON_TANKS=1
QUEUE_BOTS_DUNGEON_HEALERS=1
QUEUE_BOTS_DUNGEON_DAMAGE=3

# Evitar repetir clase en el grupo mientras haya alternativas libres. En
# poblacion baja conviene apagarlo.
QUEUE_BOTS_CLASS_VARIETY=true
# Llenar los campos de batalla a plantilla completa en vez de al minimo.
QUEUE_BOTS_BG_FILL_TO_FULL=false
# Reponer bots que se caen de un campo de batalla o arena a mitad de partida.
QUEUE_BOTS_BACKFILL=true
QUEUE_BOTS_BACKFILL_INTERVAL_SECS=20   # cada cuanto se comprueba (minimo 3)
QUEUE_BOTS_BACKFILL_GIVE_UP_SECS=45    # un repuesto que no entra en este tiempo se descarta
# Margen entre tandas de despertar bots (segundos) y hasta cuando se intenta
# traer a un bot recien metido en la banda.
QUEUE_BOTS_WAKE_COOLDOWN_SECS=15
QUEUE_BOTS_RAID_SUMMON_GIVE_UP_SECS=60

# ── mod-dungeon-clear ────────────────────────────────────────────────────────
# Pausar antes de cada jefe hasta que digas ".dc pause" para seguir. Apagado: el
# tanque ya espera a que todos estén cerca, con vida y maná antes de cada pull.
DUNGEON_CLEAR_WAIT_AT_BOSS=false
# Descanso "inteligente": el grupo tira sin parar hasta que alguien baja del 50 %
# de vida, y entonces descansan todos. Apagado a propósito: con el descanso
# clásico el tanque espera a que TÚ tengas vida y maná antes de cada pull, sin
# límite de tiempo; el inteligente sigue adelante a los 3 minutos aunque estés
# AFK.
DUNGEON_CLEAR_SMART_REST=false
# Segundos fuera de combate que se le da a la recuperación por resurrección
# antes de que el run se rinda (el módulo trae 90; 180 en heroico).
DUNGEON_CLEAR_REZ_TIMEOUT=180

# ── Coordinador compartido de población bot ─────────────────────────────────
BOT_POPULATION_PENDING_TIMEOUT_SECONDS=90
BOT_POPULATION_MAX_PENDING_TOTAL=40
BOT_POPULATION_MAX_PENDING_PER_FACTION=24
BOT_POPULATION_MAX_PENDING_PER_RANGE=12

# ── mod-world-bots (módulo propio) ───────────────────────────────────────────
# Cuántos bots de tu tramo de nivel se quieren en tu zona. El objetivo se elige
# al azar entre los dos cada vez que entras en una zona.
# 06/09/2026: 15-30 por zona completa. Conserva la semántica original del
# módulo: no es una cuota por radio alrededor del jugador.
WORLD_BOTS_MIN=15
WORLD_BOTS_MAX=30

# Tramo de nivel de los bots que se traen, respecto al tuyo: [nivel-5, nivel+3].
WORLD_BOTS_LEVEL_BELOW=5
WORLD_BOTS_LEVEL_ABOVE=3

# Distancia mínima (yardas) entre tú y el punto donde se suelta a un bot. Por
# debajo de 150 lo verías aparecer (es el margen que se impone playerbots).
WORLD_BOTS_MIN_DISTANCE=250

# En zonas contestadas, qué parte del objetivo es de la facción contraria. En
# zonas de una facción (Elwynn, Durotar...) todos son de esa facción. 0 = sólo
# de la tuya.
WORLD_BOTS_OPPOSITE_SHARE=0.35

# Bots que se teletransportan por pasada (cada 15 s hasta llegar al objetivo):
# es lo que evita las oleadas.
WORLD_BOTS_MAX_PER_PASS=5
WORLD_BOTS_MAX_TELEPORTS_PER_PASS=10   # presupuesto global entre todas las zonas

# Con la zona llena, cada cuántos segundos se repone lo que se haya ido o muerto.
WORLD_BOTS_TOPUP_SECONDS=60

# Despertar bots dormidos si no hay bastantes libres de tu tramo en el mundo, y
# cuántos como máximo de una vez.
WORLD_BOTS_WAKE=true
WORLD_BOTS_WAKE_MAX=20

# No teletransportar bots hasta que su sesion lleve este tiempo asentada.
WORLD_BOTS_MIN_WORLD_SECONDS=60

# Avisar por chat de cuántos bots han llegado. Apagado: la gracia es que no se note.
WORLD_BOTS_ANNOUNCE=false
WORLD_BOTS_VERBOSE=false              # actividad normal en DEBUG; true la eleva a INFO
WORLD_BOTS_NEARBY_PLAYER_RADIUS=150   # "alguien lo ve" al reubicar; suelo de MinDistance
WORLD_BOTS_WAKE_BATCH_SECONDS=15      # margen entre tandas de despertar bots
WORLD_BOTS_ZONE_SETTLE_SECONDS=2      # espera a que la zona se asiente al cambiar de zona
WORLD_BOTS_RETRY_SECONDS=15           # reintento cuando faltan bots o no cabe el teletransporte
# Densidad adaptativa: con varios humanos en una zona el objetivo de bots crece.
# 0 = clásico (valor al azar del rango, elegido al entrar en la zona).
WORLD_BOTS_ADAPTIVE_DENSITY=false
WORLD_BOTS_ADAPTIVE_DENSITY_PER_HUMAN=4  # bots extra por cada humano de más en la zona
WORLD_BOTS_ADAPTIVE_DENSITY_MAX=0        # tope duro; 0 = 2x MaxBots
# Modo "buen samaritano" (EXPERIMENTAL): un bot libre cercano acude a la pelea de
# un humano en apuros y vuelve a lo suyo. .wbots samaritano off para rechazarlo.
WORLD_BOTS_SAMARITAN=false
WORLD_BOTS_SAMARITAN_HP_PERCENT=35       # el humano pide ayuda por debajo de este % de vida
WORLD_BOTS_SAMARITAN_RADIUS=45
WORLD_BOTS_SAMARITAN_MAX_HELPERS=2
WORLD_BOTS_SAMARITAN_COOLDOWN_SECONDS=120
WORLD_BOTS_SAMARITAN_DURATION_SECONDS=45
WORLD_BOTS_SAMARITAN_LEVEL_BELOW=3
WORLD_BOTS_SAMARITAN_LEVEL_ABOVE=8

# Capitales (las ocho más Shattrath y Dalaran): no tienen puntos de caza, así
# que los bots se sueltan delante de sus NPC de servicio, de CUALQUIER nivel, y
# se quieren más que en una zona de campo. Distancia mínima 150 (las ciudades
# son pequeñas).
WORLD_BOTS_CITY_MIN=30
WORLD_BOTS_CITY_MAX=50
WORLD_BOTS_STAGE=true            # población por etapa: con jugador, bots sólo hasta el tope de la etapa más alta conectada y en sus mapas
WORLD_BOTS_STAGE_TBC_FROM=8      # nivel de progresión desde el que la etapa es TBC (8 = PRE_TBC)
WORLD_BOTS_STAGE_WOTLK_FROM=13   # ... y WotLK (13 = TBC_TIER_5)
WORLD_BOTS_STAGE_VANILLA_CAP=60
WORLD_BOTS_STAGE_VANILLA_MAPS="0,1"
WORLD_BOTS_STAGE_TBC_CAP=70
WORLD_BOTS_STAGE_TBC_MAPS="0,1,530"
WORLD_BOTS_STAGE_PER_PASS=3      # tope de cada barrido (nivel, mapa) cada 5 s; nivel va primero
WORLD_BOTS_STAGE_SYNC_SECONDS=60 # reconciliar topes/mapas si otro reload los pisa
WORLD_BOTS_CITY_MIN_DISTANCE=150

# ── Guerra de mundo (mod-world-bots, desde 02/09/2026) ───────────────────────
# Escaramuzas entre facciones en puntos calientes (Costasur, Molino Tarren, El
# Cruce...) y duelos a las puertas de las capitales. Fork propio de
# mod-playerbot-world-pvp: mismos 23 puntos (tabla world_bots_pvp_hotspot en
# acore_world, editable) y mismo ciclo, pero sólo con bots libres, estrategias
# restauradas al acabar, sin "respuesta reactiva", y sólo en zonas donde hay un
# jugador. GM: .wpvp estado | lista | iniciar <nombre> | parar | recargar.
WORLD_BOTS_PVP=true
WORLD_BOTS_PVP_TICK_SECONDS=60
WORLD_BOTS_PVP_CHANCE=1.5                # % por minuto; requiere soporte decimal del módulo propio
WORLD_BOTS_PVP_MAX_ACTIVE=1
WORLD_BOTS_PVP_ONLY_WITH_PLAYER=true     # sólo en zonas con jugador
WORLD_BOTS_PVP_MIN_LEVEL=20
WORLD_BOTS_PVP_MAX_PER_SIDE=8
WORLD_BOTS_PVP_MOVE_DELAY=15             # segundos de reunión antes de avanzar
WORLD_BOTS_PVP_MIN_BOTS_TO_START=2       # mínimo por bando para que un evento arranque
WORLD_BOTS_PVP_KEEP_AWAY_DISTANCE=160    # un punto nunca a menos de esto de un humano
WORLD_BOTS_PVP_REPOSITION_DISTANCE=200   # ... se reproyecta a esta distancia
WORLD_BOTS_PVP_NEARBY_PLAYER_RADIUS=150  # "alguien lo ve" al teletransportar (guerra)
WORLD_BOTS_PVP_COMBAT_GRACE_SECONDS=60   # gracia en combate al terminar antes de forzar la vuelta
WORLD_BOTS_PVP_DUELS=true
WORLD_BOTS_PVP_DUEL_PAIRS=4
WORLD_BOTS_PVP_DUEL_RANGE=35             # distancia máxima para lanzar el hechizo de duelo
WORLD_BOTS_PVP_DUEL_MAX_TRIES=20         # intentos de acercar al retado
WORLD_BOTS_PVP_ANNOUNCE=true             # "La Horda marcha sobre Costasur" a los de la zona
WORLD_BOTS_PVP_AUTO_ENABLE_HIGH_HOTSPOTS=true  # reactivar los puntos de 50-60 cuando haya poblacion de ese nivel
WORLD_BOTS_PVP_CAPTURE_OBJECTIVE=true    # el bando que aguanta cerca del punto captura y gana antes de tiempo
WORLD_BOTS_PVP_CAPTURE_RADIUS=40         # yardas del punto que cuentan para el control
WORLD_BOTS_PVP_CAPTURE_GOAL=10           # ticks de control (uno cada ~15 s) para ganar
WORLD_BOTS_PVP_GEAR_MODE=1               # equipo de los bots de la guerra a la fase del jugador (0 = no tocar)
WORLD_BOTS_PVP_GEAR_MARGIN=6
WORLD_BOTS_PVP_GEAR_TOLERANCE=8
WORLD_BOTS_PVP_GEAR_MIN_ILVL=0

# ── mod-quest-mates (módulo propio) ──────────────────────────────────────────
# Cuántos bots cogen cada misión contigo (al azar entre los dos), de qué tramo
# de nivel respecto al tuyo, qué porcentaje de misiones arrastran compañeros y
# cuántos minutos un bot sigue siendo "tu compañero" (es el primero al que se
# le dan tus siguientes misiones mientras siga en la zona).
QUEST_MATES_MIN=2
QUEST_MATES_MAX=3
QUEST_MATES_LEVEL_BELOW=5
QUEST_MATES_LEVEL_ABOVE=3
QUEST_MATES_CHANCE=100
QUEST_MATES_REMEMBER_MINUTES=30
QUEST_MATES_ANNOUNCE=false
QUEST_MATES_MAX_MATES_TRACKED=6       # tope de companeros retenidos por jugador
QUEST_MATES_CLEANUP_INTERVAL_MS=3000
QUEST_MATES_DEBUG=false               # true eleva a INFO los logs de diagnostico
QUEST_MATES_STUCK_MINUTES=0           # soltar reserva si una mision inyectada no avanza en N min (0 = no)
QUEST_MATES_ABANDON_STUCK=false       # ...y ademas quitarla del diario del bot
QUEST_MATES_FOLLOW_ABANDON=true       # si el jugador abandona una mision, sus companeros tambien la sueltan
QUEST_MATES_PREFER_HOME_GUILD=true    # los bots de tu hermandad van primero al elegir companeros
QUEST_MATES_JOINT_TURN_IN=true        # empujar a los companeros a entregar cuando el jugador entrega
QUEST_MATES_TRANSITION_GRACE_SECONDS=60 # espera a un jugador o companero en pantalla de carga antes de soltarlo

# ── Equipo de los bots que entran en tu grupo (mod-queue-bots) ───────────────
# individual-progression te tiene en Núcleo de Magma y los bots de nivel 60
# vienen con épicos de Naxxramas. Al entrar en tu banda (tablón), en tu
# mazmorra (buscador) o en cualquier grupo tuyo al pisar una instancia, se les
# reequipa al nivel de objeto objetivo:
#   modo 1: media de tu equipo + margen, sin pasar del tope de tu fase
#   modo 2: sólo el tope de la fase   ·   modo 0: no tocar
# Los topes por fase son los que documenta playerbots (MC 78, BWL 83, AQ40 88,
# Naxx40 92, Kara 125, SSC/TK 141, Hyjal/BT 156, Sunwell 164, Naxx 224,
# Ulduar 245, ToC 258, ICC 290). Un bot se reequipa sólo si se sale de
# objetivo ± tolerancia, y de uno en uno por tick.
QUEUE_BOTS_GEAR_MODE=1
QUEUE_BOTS_GEAR_MARGIN=6
QUEUE_BOTS_GEAR_TOLERANCE=8
QUEUE_BOTS_GEAR_MIN_ILVL=0
# Canjear los tokens de los bots (mod-token-turnin) en tu nombre N segundos
# después de matar un jefe de mazmorra o de banda.
QUEUE_BOTS_TOKEN_TURNIN=true
QUEUE_BOTS_TOKEN_TURNIN_DELAY=90

# ── mod-party-here (módulo propio) ───────────────────────────────────────────
# Tramo de nivel de los bots del grupo respecto al tuyo (hasta 3 por debajo,
# ninguno por encima: en un grupo de cinco un bot más alto te roba la XP).
PARTY_HERE_LEVEL_BELOW=3
PARTY_HERE_LEVEL_ABOVE=0
PARTY_HERE_MAX_RAID_BOTS=39
# Misiones de grupo: invitar solos hasta N bots al aceptar una misión con
# "jugadores sugeridos"; se van pasados LINGER segundos desde que ya no hacen
# falta (misión entregada o abandonada, cambio de zona).
PARTY_HERE_AUTO_GROUP_QUESTS=true
PARTY_HERE_AUTO_MAX_BOTS=2
PARTY_HERE_AUTO_LINGER_SECONDS=120
# SP05: mientras un bot sea tu companero, darle tambien tus misiones activas
# que pueda coger (incluidas mazmorra/banda: el ya esta dentro contigo), para
# que aproveche las copias de botin de mod-quest-loot-party (SP04). false =
# comportamiento anterior a SP05 (el grupo no comparte mision).
PARTY_HERE_SYNC_QUESTS_TO_GROUP=true
# Echar a los companeros automaticos al cambiar de zona AUNQUE la mision de
# grupo que los trajo siga activa. Por defecto NO: muchas misiones "(Grupo)" se
# aceptan en el pueblo y se hacen o entregan en otra zona.
PARTY_HERE_DISMISS_AUTO_ON_ZONE_CHANGE=false
PARTY_HERE_SUMMON_DELAY=3          # segundos hasta traer al bot a tu lado (0 = andando)
PARTY_HERE_SUMMON_RETRY_SECONDS=3
PARTY_HERE_SUMMON_GIVE_UP_SECONDS=60
PARTY_HERE_SUMMON_DISTANCE=40      # a partir de estas yardas "ya esta cerca"
PARTY_HERE_SUMMON_PLACE_RADIUS=4
PARTY_HERE_RESURRECT_ON_SUMMON=true
PARTY_HERE_REPLENISH=true                 # reponer companheros que se van de un grupo manual
PARTY_HERE_REPLENISH_THROTTLE_SECONDS=15
PARTY_HERE_PERSIST_MINUTES=10             # recomponer el grupo manual (>5) tras un relogin; 0 = no
PARTY_HERE_PENDING_TIMEOUT_SECONDS=180      # peticion de companheros sin completar: se abandona tras esto
PARTY_HERE_PENDING_RETRY_SECONDS=5
PARTY_HERE_PENDING_WAKE_SECONDS=45
PARTY_HERE_ROLE_WAIT_SECONDS=45           # grupo manual: esperar tanque/sanador antes de cubrir con otro rol; 0 = no
PARTY_HERE_ROLE_RESPEC=true               # pasada la espera, un bot de clase capaz cambia de talentos al rol que falta (M26)
PARTY_HERE_ROLE_LEVEL_ABOVE=5             # pasada la espera, admite tanque/sanador hasta N niveles por encima del tramo (UPD-I); 0 = no
PARTY_HERE_DISMISS_EXCLUDE_MINUTES=10     # un bot echado o cambiado no vuelve en este tiempo
PARTY_HERE_SCAN_INTERVAL_MS=3000
PARTY_HERE_MAX_GROUP_BOTS=0        # tope de ".grupo N"; 0 = MAX_RAID_BOTS
PARTY_HERE_TANKS=0                 # composicion fija; 0 = segun el tamano
PARTY_HERE_HEALERS=0
PARTY_HERE_AUTO_QUEST_MIN_SUGGESTED=0
PARTY_HERE_ANNOUNCE_ERRORS=true
PARTY_HERE_WAKE_THROTTLE_SECONDS=15
PARTY_HERE_WAKE=true
PARTY_HERE_WAKE_MAX=20
PARTY_HERE_MIN_WORLD_SECONDS=60       # espera tras conectar antes de traerlo
PARTY_HERE_ANNOUNCE=true
# Mismo criterio de equipo que QUEUE_BOTS_GEAR_*, para los bots que entran por aquí.
PARTY_HERE_GEAR_MODE=1
PARTY_HERE_GEAR_MARGIN=6
PARTY_HERE_GEAR_TOLERANCE=8
PARTY_HERE_GEAR_MIN_ILVL=0

# ── mod-home-guild (módulo propio) ───────────────────────────────────────────
HOME_GUILD_LEGACY_NAME="Companeros de {name}"   # firma de la versión automática antigua
HOME_GUILD_LEGACY_MOTD="Bienvenido a casa. Escribe .grupo para salir de mazmorra con nosotros."
HOME_GUILD_CLEANUP_LEGACY=true           # disolver una vez las guilds automáticas antiguas identificadas con seguridad
HOME_GUILD_MEMBERS=15                    # bots en la hermandad (30 para bandas de 25)
HOME_GUILD_LEVEL_BELOW=3                 # tramo de nivel de los reclutas
HOME_GUILD_LEVEL_ABOVE=2
HOME_GUILD_KEEP_ONLINE=true              # conectarlos contigo y mantenerlos conectados
HOME_GUILD_RELEVEL=true                  # subirles el nivel cuando se queden atrás
HOME_GUILD_RELEVEL_BEHIND=4              # ...más de N niveles por debajo de ti
HOME_GUILD_ANNOUNCE=true
HOME_GUILD_ANNOUNCE_WHEN_GUILDLESS=true  # aviso "monta una hermandad" al entrar sin guild
HOME_GUILD_CARE_INTERVAL_SECONDS=30
HOME_GUILD_RECRUIT_BACKOFF_SECONDS=300   # espera si la hermandad ya esta llena
HOME_GUILD_KEEP_ONLINE_INTERVAL_SECONDS=15
HOME_GUILD_KEEP_ONLINE_BATCH=5
HOME_GUILD_MAX_ONLINE_BOTS=0             # tope propio; 0 = Playerbots.MaxRandomBots
HOME_GUILD_RELEVEL_PER_PASS=1
HOME_GUILD_RELEVEL_TARGET_JITTER=0       # 0 = usar LEVEL_BELOW
HOME_GUILD_RELEVEL_MIN_WORLD_SECONDS=60   # segundos conectado antes de renivelar a un bot
HOME_GUILD_RECRUIT_FROM_OFFLINE_POOL=true
HOME_GUILD_ALLIANCE_RACES="1,3,4,7,11"
HOME_GUILD_HORDE_RACES="2,5,6,8,10"
HOME_GUILD_LEGACY_NUMBER_MAX=100
# Roster con roles equilibrados: objetivo de tanques/sanadores (0 = por tamano).
HOME_GUILD_TANKS=0
HOME_GUILD_HEALERS=0
# Equipo de los bots de casa conectados a la fase del owner (mismas claves que QueueBots.Gear*).
HOME_GUILD_GEAR_MODE=1
HOME_GUILD_GEAR_MARGIN=6
HOME_GUILD_GEAR_TOLERANCE=8
HOME_GUILD_GEAR_MIN_ILVL=0
HOME_GUILD_GEAR_INTERVAL_SECONDS=120

# ── mod-update-notice (módulo propio) ────────────────────────────────────────
UPDATE_NOTICE_MIN_SECURITY=2             # 1 moderador, 2 GM, 3 administrador
UPDATE_NOTICE_DELAY_SECONDS=8
UPDATE_NOTICE_MAX_LINES=15
UPDATE_NOTICE_MAX_DAYS_STALE=10          # avisar de informe viejo pasados N dias
UPDATE_NOTICE_SEVERITY=true              # ordenar/colorear por [seguridad]/[incompat]/[funcional]/[info]
UPDATE_NOTICE_ONCE_PER_SESSION=false     # no repetir el aviso por relog en el mismo arranque
UPDATE_NOTICE_COMMAND_ONLY=false         # sin popup de login; solo .actualizaciones
UPDATE_NOTICE_SAY_IF_NONE_ON_LOGIN=false # decir "todo al dia" tambien al entrar

# ── mod-arac-trainer-audit (módulo propio) ───────────────────────────────────
ARAC_TRAINER_AUDIT_LOG_PURCHASES=true      # log de cada hechizo comprado en un entrenador
ARAC_TRAINER_AUDIT_GUARD_CLASS_RACE_FIT=true # vetar con aviso una compra que no encaje raza/clase
ARAC_TRAINER_AUDIT_REFRESH_DRUID_TRAINER_LIST=false # mitigacion Feral descartada por prueba en juego
ARAC_TRAINER_AUDIT_TRACE_ACCOUNT_ID=0 # traza RX/TX de entrenador; cerro E1h el 22/09/2026, apagada

# ── mod-server-help (módulo propio) ──────────────────────────────────────────
SERVER_HELP_MAX_SEARCH_RESULTS=60        # resultados máximos de ".ayuda buscar"
SERVER_HELP_CACHE_SECONDS=300            # vida de la instantánea por cuenta (se rehace antes si cambia el nivel)
SERVER_HELP_INDEX_COOLDOWN=2             # segundos entre dos índices completos de la misma cuenta
SERVER_HELP_LOG_REQUESTS=false           # apuntar cada petición del addon en Server.log (diagnóstico)
SERVER_HELP_SNAPSHOT_MAX_AGE=3600        # segundos que se guarda una instantánea sin uso
SERVER_HELP_SEARCH_QUERY_MAX_BYTES=64
SERVER_HELP_COMMAND_QUERY_MAX_BYTES=128
SERVER_HELP_RATE_WINDOW_SECONDS=20       # limite por cuenta de subcomandos .ayuda
SERVER_HELP_RATE_MAX_PER_WINDOW=20       # 0 = sin limite
SERVER_HELP_EXPORT=true                  # ".ayuda export" vuelca el arbol descubierto al panel web

# ── mod-adaptive-ai (módulo propio) ──────────────────────────────────────────
ADAPTIVE_ENABLE=true                     # el decisor (false: playerbots de serie; las arenas siguen)
ADAPTIVE_LEARN=true                      # aprender de los combates
ADAPTIVE_LEARN_ONLY_ARENA=false          # true: los combates reales no tocan la tabla
ADAPTIVE_REAL_ENABLE=true                # decidir también en combates reales (con la tabla validada)
ADAPTIVE_ARENA_ENABLE=true               # arena de entrenamiento en segundo plano
ADAPTIVE_ARENA_SIMULTANEOUS=120   # combates a la vez. 120 desde el 04/09/2026 13:20 (con 90 se llenaban 87 y el limitador volvia a ser el aforo, no la poblacion). 90 desde el 04/09/2026 (bolsa A): con 30 entrenaban 60 bots de los 243 de nivel 80 conectados y los otros ~183 estaban parados. Es un techo, no un objetivo: si no hay bots libres, LaunchArena falla y el tick lo reintenta
ADAPTIVE_ARENA_TEAM_SIMULTANEOUS=1   # arenas de equipo (2c2, 3c3, 5c5) a la vez, rotando; el grueso va a 1c1 (03/09/2026, decisión del usuario)
ADAPTIVE_ARENA_BOTS_MAX=200   # bots a la vez en arenas (deja bots para campos y jugadores). 200 desde el 04/09/2026: es el tope que mordía primero, 30 arenas ya eran 60 bots
ADAPTIVE_ARENA_WITH_PLAYER="1c1:21"      # con un jugador conectado: partidas a la vez por tamaño (vacío = no bajar). 03/09/2026: todo a 1c1, donde más se aprende: 21 partidas = 42 bots, los mismos que una de cada tamaño más un campo
ADAPTIVE_BG_WITH_PLAYER=0                # con un jugador conectado: campos automáticos a la vez
# Franjas de nivel de playerbots según haya alguien jugando o no (03/09/2026).
# Con un jugador dentro manda el reparto automático de playerbots, que acerca la
# población a tu nivel; con el servidor entrenando solo manda el fijo
# (BOTS_LEVEL80_PCT), porque sin nadie a quien seguir el automático reparte a
# partes iguales y le deja al entrenamiento 28 bots de nivel 80 en vez de 200.
# Ver BOTS_LEVEL_BRACKETS_DYNAMIC, que es el valor de partida (el de sin nadie).
ADAPTIVE_LEVEL_BRACKETS_WITH_PLAYER=true
ADAPTIVE_ARENA_PAUSE_SECONDS=1   # segundos entre dos lanzamientos (con 90 arenas de ~60 s hacen falta 1,5 por segundo; cuantas van en cada tick lo decide el modulo: max(2, aforo/30))
ADAPTIVE_CLASSES=""                      # clases que deciden y entrenan; vacío = todas (warrior,mage,rogue,...)
ADAPTIVE_ARENA_TYPES="1c1,2c2,3c3,5c5"   # tamaños que entrena el automático (03/09/2026 11:00: abiertos todos con el tope de bots en arenas)
ADAPTIVE_BOTS_LEVEL80="warrior:30,paladin:30,hunter:30,rogue:30,priest:30,deathknight:30,shaman:30,mage:30,warlock:30,druid:30"   # bots de nivel 80 conectados por clase (300 en total). 30 desde el 04/09/2026 13:20 (120 arenas de 1c1 piden ~24 por clase a la vez); 26 desde el 04/09/2026: con 90 arenas de 1c1 hacen falta ~18 por clase a la vez y había clases con 21
ADAPTIVE_ARENA_PAIRS="warrior:paladin,warrior:hunter,warrior:rogue,warrior:priest,warrior:deathknight,warrior:shaman,warrior:mage,warrior:warlock,warrior:druid,paladin:hunter,paladin:rogue,paladin:priest,paladin:deathknight,paladin:shaman,paladin:mage,paladin:warlock,paladin:druid,hunter:rogue,hunter:priest,hunter:deathknight,hunter:shaman,hunter:mage,hunter:warlock,hunter:druid,rogue:priest,rogue:deathknight,rogue:shaman,rogue:mage,rogue:warlock,rogue:druid,priest:deathknight,priest:shaman,priest:mage,priest:warlock,priest:druid,deathknight:shaman,deathknight:mage,deathknight:warlock,deathknight:druid,shaman:mage,shaman:warlock,shaman:druid,mage:warlock,mage:druid,warlock:druid,*+*:*+*,*+*+*:*+*+*,*+*+*+*+*:*+*+*+*+*"   # todas las parejas de clases en 1c1 (45) y equipos al azar de 2, 3 y 5 (03/09/2026 11:15)
ADAPTIVE_BG_ENABLE=true                  # campos de batalla de entrenamiento automáticos (03/09/2026 11:00: uno cada 30 min; a mano siempre: .adaptive bg lanzar)
ADAPTIVE_BG_MAPS="WS"                    # de momento solo Garganta (03/09/2026); WS, AB, EY, AV, SA, IC
ADAPTIVE_BG_EVERY_MINUTES=30             # uno cada N minutos
ADAPTIVE_BG_PLAYERS=0                    # bots por bando; 0 = el mínimo del campo (WS 10, AB 15...)
ADAPTIVE_IMPORTAR_ENTRENADO=false        # importar el entrenamiento guardado en el repositorio (fase 5; pregunta si es interactivo).
                                         # A false desde el 04/09/2026: el entrenamiento anterior se hizo con un premio viciado y
                                         # esta guardado como .old. Volver a true cuando haya uno nuevo.
ADAPTIVE_ARENA_MODE=contraste                # entrenar | contraste (contra playerbots de serie) | mixto
ADAPTIVE_ARENA_YIELD=true                # no lanzar mientras haya un jugador en cola PvP
ADAPTIVE_ARENA_MAP=559                   # 559 Nagrand, 562 Filospada, 572 Lordaeron, 617 Dalaran, 618 Valor, 0 azar
ADAPTIVE_ARENA_PREP_SECONDS=15           # cuenta atrás antes de abrir las puertas
ADAPTIVE_ARENA_LEVEL=80                  # nivel mínimo de los bots
ADAPTIVE_ARENA_GEAR_SCORE=264            # nivel de objeto al que se iguala el equipo (264 = Gladiador Colérico; 0 = no tocar)
ADAPTIVE_ARENA_SPECS="warrior:arms pvp, mage:frost pvp, rogue:subtlety pvp, deathknight:unholy pvp, warlock:affli pvp, hunter:mm pvp, druid:cat pvp, paladin:ret pvp, priest:shadow pvp, shaman:ele pvp"   # spec premade de playerbots por clase en arena (nombres de Playerbots.PremadeSpecName)
ADAPTIVE_OBJECTIVES="mage:warrior=70, rogue:mage=60, rogue:warrior=55, deathknight:warrior=60, warlock:warrior=65, hunter:warrior=60, druid:warrior=65, paladin:warrior=50, priest:warrior=55, shaman:warrior=55, hunter:deathknight=65, deathknight:rogue=55, rogue:warlock=60, druid:rogue=60, warlock:mage=50, hunter:mage=60, druid:mage=55, mage:deathknight=60, mage:paladin=55, mage:priest=55, mage:shaman=60, deathknight:warlock=55, deathknight:shaman=50, deathknight:priest=55, deathknight:druid=45, warlock:paladin=55, warlock:priest=55, warlock:shaman=55, hunter:warlock=55, hunter:druid=45, hunter:paladin=50, hunter:priest=50, hunter:shaman=55, druid:deathknight=55, druid:paladin=55, druid:priest=50, druid:shaman=55, paladin:rogue=55, paladin:deathknight=55, paladin:priest=50, paladin:shaman=55, priest:rogue=45, priest:paladin=50, priest:shaman=55, shaman:rogue=40, rogue:hunter=55, rogue:paladin=45, rogue:priest=55"   # % que se espera que a gane a b (PvP Matchup Reference.md); vacío = sin objetivos
ADAPTIVE_OBJECTIVES_STOP=true            # dejar de lanzar un 1c1 en el automático cuando alcanza su objetivo en las dos orientaciones
ADAPTIVE_LOADOUT_ENABLE=true             # doble spec (PvE + PvP) y equipo por propósito en todos los bots de nivel 40+
ADAPTIVE_LOADOUT_PVP_ILVL="0:232,1600:251,1800:264,2200:270"   # equipo PvP por rating Elo del bot (Furioso, Implacable, Colérico)
ADAPTIVE_LOADOUT_PVE_ILVL="normal:187,heroica:200,banda10:219,banda25:232,mundo:0"   # equipo PvE por contenido cuando va sin jugador
ADAPTIVE_LOADOUT_CAP_LEVELS="60,70,80"   # niveles tope de etapa: solo ahí es normal ir con equipo PvP por el mundo; por debajo, un bot con resiliencia por el mundo se reequipa PvE por nivel (03/09/2026)
ADAPTIVE_CALIBRATE_MINUTES=75            # minutos de ENTRENAMIENTO de cada ciclo. 75 desde el 04/09/2026 14:00: con MinutosMaximos a 45 el periodo sigue siendo de 2 h y alineado al reloj (examenes a las 01:15, 03:15, 05:15...), y el entrenamiento gana 15 min por ciclo
ADAPTIVE_CALIBRATE_MATCHES=5000          # tope de combates del examen; en la practica manda el tiempo (MAX_MINUTES). 5000 desde el 04/09/2026 14:00: con PorPareja=3 el tope de 2500 cortaba el examen a los ~23 min
ADAPTIVE_CALIBRATE_MARGIN=0.60           # tasa de victoria mínima para validar la candidata
ADAPTIVE_CALIBRATE_PER_CLASS=true        # aprobado por clase: la clase que gana su calibración pasa a la validada aunque el global no llegue (03/09/2026)
ADAPTIVE_CALIBRATE_PER_CLASS_MATCHES=100 # partidas por clase y lado para decidir el aprobado. 100 desde el 04/09/2026 14:00: con 120 arenas un examen de 45 min deja 250-300 por lado, asi que el aprobado descansa sobre mas partidas
ADAPTIVE_CALIBRATE_TYPES="1c1"           # tamaños que entran en el examen (03/09/2026, decisión del usuario): solo duelos, porque el aprobado va por clase y en un 5c5 el mérito no se puede atribuir. El equipo se sigue midiendo con las partidas de contraste del automático
ADAPTIVE_CALIBRATE_MAX_MINUTES=45        # el examen dura 45 min y concluye con lo que haya medido (0 = hasta completar MATCHES). 45 desde el 04/09/2026 14:00, decision del usuario: con 120 arenas sobra tiempo y esos 15 min se los queda el entrenamiento
ADAPTIVE_CALIBRATE_EXCLUSIVE=true        # durante el examen el automático no lanza: todas las arenas miden. Una hora entrenando, una hora midiendo
ADAPTIVE_CALIBRATE_CLOCK=true            # el examen va por el reloj del sistema (04/09/2026): con CadaMinutos y MinutosMaximos a 60, de 01:00 a 02:00, de 03:00 a 04:00... hora local, reinicios aparte. false = temporizador desde el arranque
ADAPTIVE_CALIBRATE_CLASS_GAIN=5          # puntos que la clase tiene que ganar con la candidata por encima de lo que gana con la validada (o 90 % y no empeorar: saturada). Con 150-200 partidas por lado, cinco puntos ya se sostienen
ADAPTIVE_CALIBRATE_MAX_CYCLES=6          # exámenes JUZGADOS sin aprobar tras los que, si no mejora, la clase vuelve a lo anterior (0 = nunca). Estuvo a 0 el 04/09/2026 por la mañana (con 3, el examen sesgado borró cinco clases a las 02:00) y volvió a 6 esa misma tarde. Desde el 05/09 solo cuentan los exámenes con partidas suficientes, y la guarda no revierte a una clase cuya validada esté vacía
ADAPTIVE_ARENA_GENERATIONS=15            # % de partidas automáticas contra una generación anterior (versiones que fueron validadas): variedad, que no se estanque
ADAPTIVE_CALIBRATE_PER_PAIR=4            # partidas a la vez por pareja durante el examen. 2 desde el 04/09/2026 20:00: con 3 y 45 parejas el examen pedia 135 arenas y el aforo real son ~100 (ADAPTIVE_ARENA_BOTS_MAX / 2), asi que 11 parejas no arrancaban ninguna vez en los 45 min (el paladin jugo 40 lados y el CdM 397, y sin sus 100 por lado no se le pudo juzgar ni cortar el examen). 4 desde las 22:00 del mismo dia: SaltarSaturadas deja fuera las parejas donde la serie gana mas del 95 %, y el 04/09 quedaron 25 de 45, o sea 25 x 2 = 50 huecos de los ~100 que caben: el examen usaba menos de la mitad de la capacidad y el cazador, con solo 3 rivales con senal de sus 9, no llegaba a las 100 partidas por lado en los 45 min. 25 x 4 = 100 llena la capacidad. Subirlo ya es seguro porque el reparto por turnos del planificador impide que ninguna pareja se quede sin turno aunque el producto pase de la capacidad
ADAPTIVE_CALIBRATE_ROUND_MAX_EXAMS=6     # examenes tras los que la ronda se cierra aunque no aprueben todas. Mientras no cierra, las clases aprobadas NO vuelven a aprender en 1c1 (son sparring), asi que una clase atascada las congela a todas: el 04/09 el brujo tenia paradas a paladin, sacerdote, CdM y mago. 0 = esperar a todas
ADAPTIVE_CALIBRATE_SKIP_SATURATED=5      # % por debajo del cual (o por encima de 100 menos eso) una pareja no tiene senal y no entra en el examen. 04/09/2026: el CdM gana el 97-100 % a ocho clases EN REFERENCIA (serie contra serie, y con el ilvl medio mas bajo), asi que sus parejas no dicen nada de lo aprendido y se llevaban un tercio del examen. 0 = examinarlas todas
# Acciones que no se ofrecen a una clase aunque el bot las tenga (clase:accion,
# separadas por comas). No se borran del catalogo: los indices no se mueven y no
# se pierde nada de lo aprendido. El druida trae 51 acciones -el doble que el
# guerrero- y con spec de arena "cat pvp" el kit de oso, el de lechuza y la forma
# de viaje solo dispersan: todas salian con valor medio negativo y miles de
# visitas (04/09/2026). El "warlock:kitear" queda estudiado y NO puesto: primero
# se prueba si clavar antes de kitear lo arregla.
# El experimento N3 del 05/09/2026 16:00, que
# quitaba al brujo y al chamán toda la rotación ofensiva, se REVIRTIÓ a las
# 19:03 del mismo día: su premisa era que la rotación sobraba, y la causa real
# de que no avanzaran era que el módulo cortaba el casteo en curso (arreglado a
# las 18:49, AdaptiveAI.Decision.RespetarCasteo). Con la lista recortada no se
# podía medir a esas dos clases en igualdad con el resto. En principio ninguna
# clase lleva restricciones: lo del druida se queda porque no es un recorte del
# "qué" sino de lo que su spec de arena no usa (y RespetarForma ya hace lo mismo
# con el daño de lanzador).
ADAPTIVE_ACTIONS_EXCLUDE="druid:travel form, druid:bear form, druid:dire bear form, druid:mangle (bear), druid:maul, druid:lacerate, druid:frenzied regeneration, druid:feral charge - bear, druid:moonkin form, druid:caster form"
ADAPTIVE_CALIBRATE_WINDOW=2              # exámenes que cuentan para el aprobado por clase; antes se sumaba sin límite y una clase con cientos de partidas acumuladas no podía mover su media
ADAPTIVE_CALIBRATE_SAME_RIVAL=true       # el examen juega un tercer brazo (validada contra validada) y la nota "con la validada" de cada clase sale SOLO de ahí, contra el mismo rival que la nota "con la candidata". Con dos brazos el aprobado medía "mi mejora más la de mis rivales" (05/09/2026). Cuesta un 50 % más de partidas por pareja
ADAPTIVE_CALIBRATE_Z=1.64                # el aprobado exige además Z veces el error típico de la diferencia (con 200-300 por lado, 4-4,5 puntos): con el umbral fijo de 5 se colaba un falso aprobado por clase cada ocho exámenes (05/09/2026, M5). 0 = solo ADAPTIVE_CALIBRATE_CLASS_GAIN
# La versión estable del 05/09/2026:
ADAPTIVE_CALIBRATE_LADDER_RULE=false     # la serie como única vara del aprobado: el peldaño de la candidata sin explorar contra el mejor peldaño actual. false = solo se traza en el log ("Veredicto por escalera (sombra)") al lado del veredicto de hoy; se pone a true cuando dos exámenes hayan enseñado los dos
ADAPTIVE_ARENA_PROBE=10                  # % de sondas sin explorar; 10 desde el 05/09 para medir también las clases con pocas muestras
ADAPTIVE_DECISION_MIN_VISITS=5           # sin aprender (validada, generación, mundo) solo se eligen acciones con estas visitas al menos; si ninguna llega, none. Antes la "mejor" acción tenía una sola visita en el 52-58 % de los estados, y con la tabla sin filas decidía la personalidad del bot (N1, N4)
ADAPTIVE_DECISION_REJECT_LEARNS=false    # si la acción que playerbots rechaza aprende "mejor Q - 1" (lo de antes): dejaba acciones nunca ejecutadas como segundas mejores del estado (N4)
ADAPTIVE_ARENA_APPROVED_LEARN=true       # las aprobadas siguen aprendiendo en 1c1 durante la ronda (antes: de serie y sin aprender hasta cerrar la ronda, N5)
ADAPTIVE_ARENA_APPROVED_MODEL=50         # % de partidas de contraste en que la aprobada del lado no adaptativo lleva su validada en vez de jugar de serie
ADAPTIVE_CALIBRATE_ALL_PLAY=true         # en el examen, las aprobadas y las que ya llegaron al tope siguen jugando como las demás (al sacarlas, las que quedaban jugaban menos contra ellas; petición del usuario, 05/09/2026)
ADAPTIVE_ARENA_LADDER=15                 # % de partidas automáticas que miden un peldaño (validada o generación) contra playerbots de serie: es lo que coloca la escalera por clase. Con 15 y dos peldaños, la escalera se llena en ~3 h; se puede bajar a 10 cuando esté hecha
ADAPTIVE_LADDER_MIN_MATCHES=30           # partidas mínimas de un peldaño en una clase para usarlo en el mundo (hasta que las tiene, esa clase juega de serie)
ADAPTIVE_LADDER_SINCE=1788629327         # 05/09/2026 19:28:47 Madrid: tras arreglar casteo y limpiar Q parcial. Solo reinicia la medida, nunca lo aprendido. Actualizar tras cambios de comportamiento; 0 = historial.
ADAPTIVE_REAL_MODE=espejo                # qué modelo sale al mundo: validada | mejor (el peldaño más alto medido, que puede ser la serie) | espejo (el más cercano al rating del jugador)
ADAPTIVE_MIRROR_SPREAD=1                 # escalones arriba o abajo del centro, al azar por bot: variedad de rivales (unos mejores que el jugador, otros peores)
ADAPTIVE_MIRROR_HOURS=6                  # cada cuántas horas se resortea el desvío de un bot
ADAPTIVE_GENERATIONS_KEEP=12             # generaciones que se guardan (son los peldaños de la escalera: podarlas la deja sin escalones)
ADAPTIVE_GENERALIZE=true                 # fila "contra cualquier rival" como punto de partida de lo no probado contra un rival concreto (aprende de las 9 parejas a la vez)
ADAPTIVE_EPSILON=0.05                    # exploración al azar (la dirigida es AdaptiveAI.Exploracion.Bonus en el .conf)
ADAPTIVE_ARENA_REFERENCE=20              # % de partidas serie contra serie (línea base del contraste). 20 desde el 04/09/2026: con 10 salían diez partidas por pareja y ninguna comparación se sostenía
ADAPTIVE_DIFFICULTY_DEFAULT=3            # 1 Novato .. 6 Elite (solo en combates reales)
ADAPTIVE_LOG_DECISIONS=false             # guardar cada decisión en adaptive_experience (crece rápido)
ADAPTIVE_AUDIT_BOT=0                     # GUID de un bot para auditoría selectiva en Server.log; 0 apagado, tope 4000 eventos/sesión
ADAPTIVE_AUDIT_CLASSES=""                 # captura temporal de sesiones activas; vacío apaga. Cuota por clase y proceso
ADAPTIVE_AUDIT_SESSIONS=3                # máximo por clase (1-20); no depende de un GUID conectado
ADAPTIVE_LOG_AURAS=false                 # diagnóstico: cada control/snare cobrado, con hechizo y objetivo (ruidoso)
ADAPTIVE_CALIBRATE_CUT_WHEN_JUDGED=true  # el examen se corta cuando todas las clases que se juzgan ya tienen partidas de sobra
ADAPTIVE_CALIBRATE_CUT_MATCHES=0         # partidas por lado para ese corte (0 = las mismas que ADAPTIVE_CALIBRATE_PER_CLASS_MATCHES)
ADAPTIVE_WARLOCK_PVP_PET="felhunter"     # mascota del brujo en PvP: felhunter (manáfago), succubus, felguard, voidwalker, imp
ADAPTIVE_LOG_MATCH_DAYS=30               # borrar partidas de más de N días (0 = nunca); lo aprendido no se toca

# ── mod-world-buff-bots ──────────────────────────────────────────────────────
# Cada buff salta cada BASE ± VARIANZA minutos (90 ± 60 = entre 30 y 150).
WORLD_BUFF_BASE_MINUTES=90
WORLD_BUFF_VARIANCE_MINUTES=60
WORLD_BUFF_WARCHIEF=true                 # Bendición del Jefe de Guerra (Orgrimmar y Cruce)
WORLD_BUFF_DRAGONSLAYER=true             # Grito de guerra del Matadragones (Ventormenta)
WORLD_BUFF_ZANDALAR=true                 # Espíritu de Zandalar (Stranglethorn)
WORLD_BUFF_WARCHIEF_TEXT="Rend Puno Negro ha caido. Thrall concede la Bendicion del Jefe de Guerra en honor de {player}."
WORLD_BUFF_DRAGONSLAYER_TEXT="{player} ha traido la cabeza de Onyxia. El Grito de guerra del Matadragones resuena en Ventormenta."
WORLD_BUFF_ZANDALAR_TEXT="{player} ha devuelto el Corazon de Hakkar. El Espiritu de Zandalar llena Stranglethorn."

# ── mod-token-turnin ─────────────────────────────────────────────────────────
TOKEN_TURNIN_INCLUDE_SELF=false          # también tus propios tokens (no: eso es cosa tuya)


# ═══════════════════════════════════════════════════════════════════════════════
#  NPC DE SERVICIO — COLOCACIÓN AUTOMÁTICA
# ═══════════════════════════════════════════════════════════════════════════════

# Colocar automáticamente los NPC de los módulos en Ventormenta y Orgrimmar.
# Antes había que ponerlos a mano dentro del juego con ".npc add <entrada>".
#
# Las posiciones NO son coordenadas fijas: se calculan a partir de un NPC que ya
# existe en cada ciudad (el posadero), así que los NPC quedan a ras de suelo y no
# flotando ni dentro de una pared.
#
# ⚠️  Si lo pones en true, cada './install.sh --only 5' BORRA las apariciones
#     previas de esos NPC y las vuelve a crear. Si prefieres colocarlos tú a mano
#     donde quieras, ponlo en false.
SPAWN_SERVICE_NPCS=true


# ═══════════════════════════════════════════════════════════════════════════════
#  CUENTA DE ADMINISTRADOR
#  Se crea sola en cada instalación desde cero, sin personaje. La contraseña se
#  guarda como verificador SRP6, igual que si la hubieras creado con el comando
#  "account create" en la consola del servidor.
# ═══════════════════════════════════════════════════════════════════════════════

CREATE_ADMIN_ACCOUNT=true
ADMIN_ACCOUNT_NAME="admin"
ADMIN_ACCOUNT_PASS="admin"

# Nivel de GM: 0=jugador  1=moderador  2=game master  3=administrador
ADMIN_ACCOUNT_GMLEVEL=3


# ═══════════════════════════════════════════════════════════════════════════════
#  IDIOMA
# ═══════════════════════════════════════════════════════════════════════════════

# El juego base YA viene traducido al español: el volcado de la base de datos del
# core trae las filas esES de misiones, objetos, criaturas y diálogos. Lo único
# que queda en inglés es lo que añaden los módulos.
#
# En true se aplican las traducciones propias del instalador (patches/locales-es/):
# textos del NPC de transmog y nombres de los NPC de servicio.
LOCALE_ES=true

# ════════════════════════════════════════════════════════
#  CONFIGURACIÓN LOCAL (no versionada)
# ════════════════════════════════════════════════════════

# Valores propios de esta instalación (IP, nombre del reino, contraseñas...) en
# config.local.sh, junto a este fichero. Es un script de Bash que sólo contiene
# asignaciones, p. ej.:
#     REALM_IP="192.168.1.100"
#     ADMIN_ACCOUNT_PASS="una-clave-propia"
# Lo que ponga ahí sustituye a lo de arriba y sobrevive a las actualizaciones de
# config.sh. Está en .gitignore: no se sube ni se publica. El asistente lo crea
# con permisos 600. Se carga aquí (no al final) para que lo derivado de AC_DIR
# en el bloque siguiente use el valor definitivo. AC_CONFIG_LOCAL permite
# apuntar a otro fichero.
_ac_cfg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_CONFIG_LOCAL="${AC_CONFIG_LOCAL:-$_ac_cfg_dir/config.local.sh}"
unset _ac_cfg_dir
if [ -f "$AC_CONFIG_LOCAL" ]; then
    # shellcheck disable=SC1090
    source "$AC_CONFIG_LOCAL"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  AVANZADO — No tocar salvo que sepas lo que haces
# ═══════════════════════════════════════════════════════════════════════════════

# Usuario del sistema (se detecta automáticamente)
AC_SYSTEM_USER="$(whoami)"

# Nombre de la sesión screen del worldserver
WS_SCREEN="worldserver"

# Directorio de scripts de automatización
AC_SCRIPTS_DIR="$AC_DIR/scripts"

# Directorio de logs
AC_LOGS_DIR="$AC_DIR/logs"

# Cores de compilación (por defecto: todos menos 1)
BUILD_CORES=$(nproc | awk '{print ($1 > 1 ? $1 - 1 : 1)}')

# Repositorio del core (se elige automáticamente según INSTALL_MOD_PLAYERBOTS)
if [ "$INSTALL_MOD_PLAYERBOTS" = true ]; then
    AC_CORE_REPO="https://github.com/mod-playerbots/azerothcore-wotlk.git"
    AC_CORE_BRANCH="Playerbot"
else
    AC_CORE_REPO="https://github.com/azerothcore/azerothcore-wotlk.git"
    AC_CORE_BRANCH="master"
fi
