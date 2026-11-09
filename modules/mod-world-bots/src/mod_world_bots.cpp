// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
/*
 * mod-world-bots — que la zona en la que estás no esté vacía.
 *
 * EL PROBLEMA
 * Con 250 bots repartidos entre 80 niveles y unas 90 combinaciones de zona y
 * facción, a cada zona le tocan uno o dos. mod-playerbots mueve a cada bot
 * dentro de SU zona (SelectRandomGrindPos) y lo cambia de zona cada 1-5 horas
 * al azar (RandomTeleportForLevel); lo único que sabe de tu posición es
 * BotActiveAloneForceWhenInZone, que despierta a los que ya estaban en tu zona
 * pero no trae a ninguno. LevelBrackets arregla la mitad "nivel" —hay bots de
 * tu nivel en el mundo— pero no la mitad "zona": están en otra parte.
 *
 * LA SOLUCIÓN
 * Cuando entras en una zona se cuentan los bots que hay en ella de tu tramo de
 * nivel, y si faltan hasta un objetivo configurable por zona se traen:
 *
 *   1. primero bots libres de otras zonas, teletransportados a puntos de caza
 *      de tu zona a más de 250 yardas de ti (nunca los ves aparecer);
 *   2. si no hay bastantes despiertos, se encienden dormidos de la reserva, del
 *      tramo y la facción que toca, y la pasada siguiente los recoloca.
 *
 * Los puntos de caza son celdas de 50 yardas donde hay al menos dos bichos
 * normales con botín —el mismo criterio con el que playerbots construye su
 * propia caché de destinos—, indexados por zona una sola vez al arrancar. La
 * facción la decide la zona (AreaTable.team: 2 Alianza, 4 Horda, 0/6 ambas).
 * Nunca se toca a un bot en grupo, en combate, en mazmorra, en cola, volando ni
 * en la zona de otro jugador. Mientras sigues en la zona se repone cada minuto
 * lo que se haya ido o muerto; al salir no se hace nada, que se queden. Toda
 * salida sin rellenar deja el motivo en el log, como en mod-queue-bots.
 *
 * DÓNDE SE HACE EL TRABAJO, Y POR QUÉ AHÍ
 * OnPlayerUpdateZone se ejecuta en el hilo del mapa del jugador. Teletransportar
 * desde ahí a un bot que está siendo actualizado por OTRO hilo de mapas (hay
 * cuatro) sería una carrera. Así que ese hook sólo apunta "este jugador ha
 * cambiado de zona", y el trabajo se hace en OnUpdate del mundo, que corre en
 * el hilo principal cuando ningún mapa se está actualizando.
 *
 * POR QUÉ ES UN MÓDULO APARTE Y NO UN PARCHE
 * No toca ni una línea de mod-playerbots. De él usa, entre guardas de
 * compilación, cinco cosas: saber si un bot es aleatorio, encender uno dormido,
 * mandar a dormir a uno ocioso, y las dos llamadas con las que su propio código
 * teletransporta a un bot (Reset de la IA y HasPlayerNearby). Su función de
 * teletransporte no se puede llamar —es privada—, así que aquí se hace la misma
 * secuencia que hace ella (RandomPlayerbotMgr.cpp, RandomTeleport). Si
 * playerbots no está, nada de esto se compila y el módulo no hace nada; si
 * cambia alguna firma, falla la compilación con un error claro.
 */

#include "BotClaims.h"
#include "BotEligibility.h"
#include "BotGear.h"
#include "BotOperations.h"
#include "BotPopulationCoordinator.h"
#include "BotWorldAge.h"
#include "BotWake.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "CommandScript.h"
#include "Config.h"
#include "Containers.h"
#include "Optional.h"
#include "CreatureData.h"
#include "DBCStores.h"
#include "DBCStructure.h"
#include "DatabaseEnv.h"
#include "LFGMgr.h"
#include "Log.h"
#include "Map.h"
#include "MapMgr.h"
#include "ModLocale.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Pet.h"
#include "Player.h"
#include "Position.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SlowTick.h"
#include "SpellDefines.h"
#include "StringFormat.h"
#include "StringConvert.h"
#include "TimeMs.h"
#include "Timer.h"
#include "Tokenize.h"
#include "World.h"
#include "WorldBotsPolicy.h"
#include "world_bots_locale.h"
#include "WorldSession.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <map>
#include <mutex>
#include <numeric>
#include <set>
#include <string>
#include <tuple>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

// La dependencia con mod-playerbots, entre guardas: sin el módulo esto no se
// compila y el resto sigue compilando (y no hace nada, porque sin playerbots
// no hay bots que mover).
#if defined(__has_include)
#  if __has_include("Playerbots.h") && __has_include("PlayerbotAI.h")
#    include "PlayerbotAI.h"
#    include "PlayerbotAIConfig.h"
#    include "Playerbots.h"
#    include "RandomPlayerbotMgr.h"
#    define WORLD_BOTS_WITH_PLAYERBOTS 1
#  endif
#endif

namespace
{
    struct Config
    {
        bool   enabled        = true;
        uint32 minBots        = 12;     // objetivo por zona: se elige al azar entre los dos
        uint32 maxBots        = 25;
        uint32 levelBelow     = 5;      // tramo de nivel: [nivel - 5, nivel + 3]
        uint32 levelAbove     = 3;
        float  minDistance    = 250.0f; // nunca se suelta un bot más cerca de ti
        uint64 scanMs         = 5000;   // cada cuánto se mira dónde está cada jugador
        uint32 topUpSecs      = 60;     // cada cuánto se repone la zona en la que sigues
        uint32 maxPerPass     = 5;      // teletransportes por pasada: sin oleadas
        uint32 maxTeleportsPerPass = 10; // presupuesto compartido entre humanos
        float  oppositeShare  = 0.35f;  // en zonas contestadas, parte de la otra facción
        bool   wakeBots       = true;
        uint32 wakeMax        = 20;
        bool   announce       = false;
        bool   verbose        = false;    // actividad normal a INFO en vez de DEBUG
        uint32 botMinWorldSecs = 60;     // no mover una sesion recien conectada
        float  nearbyRadius   = 150.0f;  // radio de HasPlayerNearby: no reubicar si alguien lo ve
        uint32 wakeBatchSecs  = 15;      // margen entre tandas de WakeBots
        uint32 zoneSettleSecs = 2;       // espera a que la zona se asiente antes de contar/rellenar
        uint32 retrySecs      = 15;      // reintento cuando faltan bots o no cabe el teletransporte
        uint32 deficitGraceSecs = 20;    // margen tras alcanzar el objetivo antes de reponer un hueco
        uint32 arrivalGraceSecs = 30;    // cuánto cuenta como "en camino" un salto entre mapas pendiente
        uint32 teleportMaxAttempts = 12; // puntos que se prueban como máximo por bot en una llamada
        std::vector<uint32> maps;       // los mapas donde viven los bots aleatorios

        // Capitales: no tienen puntos de caza, tienen posaderos, banqueros,
        // subastadores, vendedores y entrenadores. Ahí se quieren más bots, de
        // cualquier nivel, y más cerca (las ciudades son pequeñas).
        std::vector<uint32> cityZones;
        uint32 cityMinBots     = 30;
        uint32 cityMaxBots     = 50;
        float  cityMinDistance = 150.0f;

        // Etapas (mod-individual-progression): con un jugador conectado el
        // mundo se puebla solo hasta el nivel tope de su etapa y en sus mapas.
        // La etapa activa es la MÁS ALTA de los conectados (no se toca la
        // experiencia del avanzado). Todo bot que supere el tope de etapa se
        // re-aleatoriza; no se reserva población para módulos desactivados.
        bool   stageEnable     = true;
        uint32 stageTbcFrom    = 8;     // nivel de progresión desde el que la etapa es TBC (PRE_TBC)
        uint32 stageWotlkFrom  = 13;    // ... y WotLK (TBC_TIER_5 = Naxx de WotLK)
        uint32 stageVanillaCap = 60;
        uint32 stageTbcCap     = 70;
        std::vector<uint32> stageVanillaMaps = { 0, 1 };
        std::vector<uint32> stageTbcMaps     = { 0, 1, 530 };
        uint32 stagePerPass    = 3;     // tope de CADA barrido (nivel, mapa) por pasada (5 s): hasta 2x por pasada
        uint32 stageSyncSecs   = 60;    // reconciliar si otro reload pisa playerbots

        // Escalado de poblacion por jugador conectado: servidor de una sola
        // persona, asi que el min/max fijo de playerbots (500/600) gasta RAM
        // las 24h que hay alguien dentro aunque sea uno solo. Con esto activo,
        // Playerbots.MinRandomBots/MaxRandomBots dejan de leerse del .conf en
        // caliente: los pisa PlayerScalePerPlayer * humanos conectados (tope
        // PlayerScaleCeiling). Sin jugadores no se toca nada: DisabledWithoutRealPlayer
        // ya vacia el mundo por su cuenta.
        bool   playerScaleEnable    = false;
        uint32 playerScalePerPlayer = 150;
        uint32 playerScaleCeiling   = 600;
        uint32 playerScaleSyncSecs  = 60;

        // Densidad adaptativa (CS-4.3): con varios humanos en una zona el
        // objetivo de bots crece; con uno solo es el de siempre. Arranca en 0
        // (comportamiento clásico: urand(minBots, maxBots) al entrar en la zona).
        bool   adaptiveDensity   = false;
        uint32 adaptivePerHuman  = 4;   // bots extra por cada humano adicional en la zona
        uint32 adaptiveMax       = 0;   // tope duro; 0 = 2x maxBots (o cityMaxBots)

        // Modo "buen samaritano" (CS-4.4): un bot libre cercano acude a la pelea
        // de un humano en apuros y vuelve a lo suyo. EXPERIMENTAL, arranca en 0.
        // No se agrupa con el humano ni le quita botín: se pone a "cazar" en su
        // sitio (rpgInfo.ChangeToGoGrind), así ayuda a limpiar los enemigos.
        bool   samaritan         = false;
        uint32 samaritanHpPct    = 35;  // el humano pide ayuda por debajo de este % de vida
        float  samaritanRadius   = 45.0f;
        uint32 samaritanMaxHelpers = 2;
        uint32 samaritanCooldownSecs = 120; // por humano, entre tandas de ayuda
        uint32 samaritanDurationSecs = 45;  // cuánto se queda el bot ayudando
        uint32 samaritanLevelBelow = 3;
        uint32 samaritanLevelAbove = 8;
    };

    Config cfg;

#define WORLD_BOTS_ACTIVITY_LOG(...) \
    do { if (cfg.verbose) LOG_INFO("module", __VA_ARGS__); else LOG_DEBUG("module", __VA_ARGS__); } while (false)

    char const* PopulationFactionName(BotPopulationCoordinator::Faction faction)
    {
        return faction == BotPopulationCoordinator::Faction::Alliance ? "Alianza" : "Horda";
    }

    uint64 SecondsAgo(uint64 now, uint64 then)
    {
        return now >= then ? (now - then) / 1000 : 0;
    }

    // Un punto de caza: una celda de 50 yardas con al menos dos bichos, y el
    // nivel medio de esos bichos.
    struct Spot
    {
        WorldLocation loc;
        uint8         level = 0;
    };

    std::unordered_map<uint32, std::vector<Spot>> g_spots;      // zona -> puntos de caza
    std::unordered_map<uint32, std::vector<Spot>> g_citySpots;  // capital -> delante de sus NPC de servicio
    std::unordered_set<uint32>                    g_warnedZones; // zonas sin puntos ya avisadas

    // cursor persistente por zona sobre el orden barajado de
    // sus puntos de caza. Cada llamada a TeleportBot sólo prueba un tramo
    // acotado (cfg.teleportMaxAttempts); avanzar el cursor aquí, entre bots y
    // entre pasadas, hace que los intentos fallidos de una pasada los recoja
    // la siguiente en vez de reintentar siempre desde el principio.
    std::unordered_map<uint32, uint32> g_zoneSpotCursor;

    uint32 NextSpotCursor(uint32 zoneId, uint32 orderSize, uint32 attempts)
    {
        if (!orderSize)
            return 0;
        uint32& cursor = g_zoneSpotCursor[zoneId];
        uint32 const start = cursor % orderSize;
        cursor += attempts;
        return start;
    }

    bool IsCity(uint32 zoneId)
    {
        return std::find(cfg.cityZones.begin(), cfg.cityZones.end(), zoneId) != cfg.cityZones.end();
    }

    // Lo que se le ha prometido a cada jugador en la zona donde está.
    // everCovered/deficitSinceMs son la histéresis: una vez
    // alcanzado el objetivo, un hueco (una muerte, alguien que se aleja) no
    // dispara una reposición al primer recuento — se espera DeficitGraceSeconds
    // por si el propio playerbots resucita o recompone solo, para no acabar
    // sobrepoblando la zona cuando vuelvan. El primer relleno de una visita
    // (everCovered todavía false) no espera nada: se puebla lo antes posible.
    struct Visit
    {
        uint32 zone           = 0;
        uint32 target         = 0;
        uint64 nextFillMs     = 0;
        bool   everCovered    = false;
        uint64 deficitSinceMs = 0;
    };

    std::unordered_map<ObjectGuid, Visit> g_visits;

    // ─── Llegadas pendientes ───────────────────────────────
    // Un bot recién enviado a una zona por un salto entre mapas no aparece de
    // inmediato en el recuento de la zona destino: TeleportBot deja el salto
    // pendiente (comentario de TeleportBot, más abajo) y sólo lo remata
    // HandleTeleportAck un tick después, cuando playerbots atiende sus
    // sesiones. Sin este registro, una pasada que cuenta justo en ese hueco
    // ve la zona todavía corta y pide más bots de los que hacen falta.
    struct PendingArrival
    {
        uint32 mapId    = 0;
        uint32 zoneId   = 0;
        uint32 level    = 0;
        TeamId team     = TEAM_NEUTRAL;
        uint64 expireMs = 0;
    };
    std::unordered_map<ObjectGuid, PendingArrival> g_pendingArrivals;

    void RecordPendingArrival(ObjectGuid guid, uint32 mapId, uint32 zoneId, uint32 level, TeamId team, uint64 now)
    {
        g_pendingArrivals[guid] = PendingArrival{ mapId, zoneId, level, team, now + TimeMs::SecsToMs(cfg.arrivalGraceSecs) };
    }

    // Cuenta y a la vez limpia: expirados (el salto no llegó a completarse, o
    // tardó más de la cuenta) y ya llegados (su zona real ya es la destino:
    // el recuento de bots vivos de esta misma pasada ya los ve, contarlos
    // aquí también los duplicaría).
    uint32 CountPendingArrivals(uint32 zoneId, uint32 mapId, uint32 minLevel, uint32 maxLevel, TeamId team, uint64 now)
    {
        uint32 count = 0;
        for (auto it = g_pendingArrivals.begin(); it != g_pendingArrivals.end();)
        {
            if (now >= it->second.expireMs)
            {
                it = g_pendingArrivals.erase(it);
                continue;
            }
            if (it->second.zoneId != zoneId || it->second.mapId != mapId)
            {
                ++it;
                continue;
            }
            Player* bot = ObjectAccessor::FindPlayer(it->first);
            if (bot && bot->IsInWorld() && bot->GetZoneId() == zoneId && bot->GetMapId() == mapId)
            {
                it = g_pendingArrivals.erase(it);
                continue;
            }
            if (it->second.team == team && it->second.level >= minLevel && it->second.level <= maxLevel)
                ++count;
            ++it;
        }
        return count;
    }

    // Una sola lectura de ObjectAccessor por pasada. Los punteros son seguros
    // mientras se atiende OnUpdate; MakeRoom retira del vector cada victima
    // antes de que LogoutPlayerBot destruya el objeto.
    struct PlayerSnapshot
    {
        std::vector<Player*> humans;
        std::vector<Player*> bots;
        std::set<uint32> humanZones;
        std::unordered_map<uint32, uint32> humanZoneCount;   // zona -> humanos (densidad adaptativa)
    };

    // Objetivo de bots de una zona. Sin densidad adaptativa es lo de siempre
    // (urand del rango, elegido al entrar). Con ella, un punto medio estable más
    // adicionales por cada humano de más en la zona, topado.
    uint32 ZoneTarget(uint32 zoneId, bool city, PlayerSnapshot const& snapshot)
    {
        uint32 const lo = city ? cfg.cityMinBots : cfg.minBots;
        uint32 const hi = city ? cfg.cityMaxBots : cfg.maxBots;

        if (!cfg.adaptiveDensity)
            return urand(lo, hi);

        // Aritmética pura en WorldBotsPolicy.h.
        auto const cnt = snapshot.humanZoneCount.find(zoneId);
        uint32 const humans = cnt == snapshot.humanZoneCount.end() ? 1 : cnt->second;
        return WorldBotsPolicy::AdaptiveZoneTarget(lo, hi, humans, cfg.adaptivePerHuman, cfg.adaptiveMax);
    }

    // Jugadores que han cambiado de zona, apuntados desde el hilo del mapa.
    std::mutex                     g_pendingLock;
    std::unordered_set<ObjectGuid> g_pending;

    uint64 g_nextScan = 0;
    uint64 g_nextWake = 0;

    // Contadores desde el arranque para ".wbots estado". Sólo los toca el hilo
    // del mundo (FillZone y el drenado de comandos, ambos en OnUpdate).
    uint64 g_statPasses     = 0;
    uint64 g_statFills      = 0;
    uint64 g_statBotsMoved  = 0;
    uint64 g_statBotsWoken  = 0;

    // Comandos ".wbots aqui"/"estado": el handler encola y OnUpdate responde,
    // porque tocar g_visits o forzar una pasada desde el hilo de despacho sería
    // una carrera (igual que ".wpvp"). ".wbots etapa" sí es síncrono: sólo lee
    // StageStatus(), que no cruza estructuras vivas.
    enum WbCmdKind : uint8 { WB_CMD_STATUS = 0, WB_CMD_HERE, WB_CMD_SAMARITAN_ON, WB_CMD_SAMARITAN_OFF };
    struct WbCmd { ObjectGuid gm; uint8 kind; };
    std::mutex          g_wbCmdLock;
    std::vector<WbCmd>  g_wbCmd;

    // Modo "buen samaritano" (CS-4.4). Todo lo toca sólo el hilo del mundo.
    char const* const SAMARITAN_OWNER = "world-bots-help";
    struct Helper
    {
        ObjectGuid    human;
        WorldLocation origin;
        uint64        untilMs = 0;
    };
    std::unordered_map<ObjectGuid, Helper> g_helpers;          // bot   -> a quién ayuda
    std::unordered_map<ObjectGuid, uint64> g_samaritanCooldown; // humano -> ms hasta la próxima ayuda
    std::unordered_set<ObjectGuid>         g_samaritanOptOut;   // humanos que no quieren ayuda (hasta el reinicio)
    uint64 g_statSamaritan = 0;

    void PushWbCmd(ObjectGuid gm, uint8 kind)
    {
        std::lock_guard<std::mutex> lock(g_wbCmdLock);
        if (g_wbCmd.size() < 64)
            g_wbCmd.push_back({ gm, kind });
    }

    using BotEligibility::IsHuman;

    bool IsRandomBot(Player* bot)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        return sRandomPlayerbotMgr.IsRandomBot(bot);
#else
        (void)bot;
        return false;
#endif
    }

    // Un bot vale para moverlo si no está haciendo nada de lo que sacarlo sería
    // una grosería: ni en grupo (es el bot de alguien), ni en mazmorra, ni en
    // combate, ni volando, ni muerto, ni en una cola, ni a medio teletransporte.
    // Criterio base centralizado en BotEligibility.h; aquí se añade lo propio
    // de world-bots: antigüedad mínima en el mundo. Deliberadamente NO mira
    // reservas (BotClaims): eso es de IsFreeBot, más abajo. Un llamador que ya
    // ha adquirido su propio BotClaims::Lease sobre el bot debe usar ESTA
    // función para revalidar tras la reserva: IsFreeBot
    // rechazaría su propia reserva recién adquirida, porque BotClaims::IsClaimed
    // no distingue "reservado por mí" de "reservado por otro".
    bool IsFreeBotIgnoringClaim(Player* bot)
    {
        if (!BotEligibility::IsAvailable(bot))
            return false;

        if (!BotWorldAge::IsMature(bot->GetGUID().GetCounter(), bot->GetSession(),
                                   TimeMs::NowMs(), cfg.botMinWorldSecs))
            return false;

        return IsRandomBot(bot);
    }

    bool IsFreeBot(Player* bot)
    {
        if (!IsFreeBotIgnoringClaim(bot))
            return false;

        // Reservado por otro módulo (queue-bots lo está trayendo, party-here lo
        // ha elegido para un grupo...): ni tocarlo.
        if (BotClaims::IsClaimed(bot->GetGUID().GetCounter()))
            return false;

        return true;
    }

    // ─── El índice de puntos de caza ────────────────────────────────────────
    // Se construye una vez, al arrancar, con el mismo criterio que usa
    // playerbots para su caché de destinos (TravelMgr::PrepareDestinationCache):
    // bichos normales, sin diálogo, con botín, de reaparición corta, fuera de
    // las facciones de ciudad. Cada celda de 50 yardas con al menos dos de ellos
    // es un sitio razonable donde soltar a un bot para que cace.
    bool IsHuntable(CreatureTemplate const* tpl, CreatureData const& data)
    {
        if (tpl->npcflag != 0 || tpl->lootid == 0 || tpl->rank != 0)
            return false;

        if (tpl->maxlevel - tpl->minlevel >= 3)          // nivel indefinido: jefes, eventos
            return false;

        if (data.spawntimesecs >= 1000)                   // reaparición larga: raro o de misión
            return false;

        switch (tpl->faction)                             // las guardias y civiles de ciudad
        {
            case 11: case 71: case 79: case 85: case 188: case 1575:
                return false;
        }

        if ((tpl->unit_flags & UNIT_FLAG_IMMUNE_TO_PC) || (tpl->unit_flags & UNIT_FLAG_PVP))
            return false;

        return true;
    }

    // Un NPC de servicio de ciudad: donde un jugador de verdad se para un rato.
    // Es el mismo criterio con el que playerbots elige sus "hubs" (posaderos,
    // banqueros) para su estrategia de rol en ciudades.
    constexpr uint32 CITY_NPC_FLAGS = UNIT_NPC_FLAG_INNKEEPER | UNIT_NPC_FLAG_BANKER | UNIT_NPC_FLAG_AUCTIONEER
                                    | UNIT_NPC_FLAG_VENDOR | UNIT_NPC_FLAG_TRAINER | UNIT_NPC_FLAG_FLIGHTMASTER;

    void BuildSpotIndex()
    {
        g_spots.clear();
        g_citySpots.clear();

        struct Cell
        {
            double sumX = 0, sumY = 0, sumZ = 0;
            uint32 count = 0;
            uint32 levelSum = 0;
        };

        std::map<std::tuple<uint32, uint32, int32, int32, int32>, Cell> cells;      // (mapa, zona, x, y, z) de 50 yardas
        std::map<std::tuple<uint32, uint32, int32, int32, int32>, Cell> cityCells;  // ídem, de 15 yardas, en capitales
        uint32 considered = 0;
        uint32 cityNpcs = 0;

        for (auto const& [guid, data] : sObjectMgr->GetAllCreatureData())
        {
            if (std::find(cfg.maps.begin(), cfg.maps.end(), data.mapid) == cfg.maps.end())
                continue;

            CreatureTemplate const* tpl = sObjectMgr->GetCreatureTemplate(data.id);
            if (!tpl)
                continue;

            bool const huntable = IsHuntable(tpl, data);
            bool const service  = (tpl->npcflag & CITY_NPC_FLAGS) != 0 && tpl->faction != 35 /* neutral hostil */;
            if (!huntable && !service)
                continue;

            Map* map = sMapMgr->CreateBaseMap(data.mapid);
            if (!map)
                continue;

            uint32 const zoneId = map->GetZoneId(PHASEMASK_NORMAL, data.posX, data.posY, data.posZ);
            if (!zoneId)
                continue;

            if (service && IsCity(zoneId))
            {
                // Un paso por delante del NPC, mirando hacia él, como hace
                // playerbots con sus posaderos.
                float const x = data.posX + std::cos(data.orientation) * 4.0f;
                float const y = data.posY + std::sin(data.orientation) * 4.0f;
                float const z = data.posZ + 0.5f;
                auto key = std::make_tuple(uint32(data.mapid), zoneId,
                                           static_cast<int32>(std::lround(x / 15.0f)),
                                           static_cast<int32>(std::lround(y / 15.0f)),
                                           static_cast<int32>(std::lround(z / 15.0f)));
                Cell& cell = cityCells[key];
                cell.sumX += x;
                cell.sumY += y;
                cell.sumZ += z;
                cell.count += 1;
                ++cityNpcs;
                continue;
            }

            if (!huntable)
                continue;

            ++considered;

            auto key = std::make_tuple(uint32(data.mapid), zoneId,
                                       static_cast<int32>(std::lround(data.posX / 50.0f)),
                                       static_cast<int32>(std::lround(data.posY / 50.0f)),
                                       static_cast<int32>(std::lround(data.posZ / 50.0f)));
            Cell& cell = cells[key];
            cell.sumX += data.posX;
            cell.sumY += data.posY;
            cell.sumZ += data.posZ;
            cell.count += 1;
            cell.levelSum += (tpl->minlevel + tpl->maxlevel + 1) / 2;
        }

        uint32 spots = 0;
        for (auto const& [key, cell] : cells)
        {
            if (cell.count < 2)
                continue;

            Spot spot;
            spot.loc = WorldLocation(std::get<0>(key),
                                     static_cast<float>(cell.sumX / cell.count),
                                     static_cast<float>(cell.sumY / cell.count),
                                     static_cast<float>(cell.sumZ / cell.count));
            spot.level = static_cast<uint8>(cell.levelSum / cell.count);
            g_spots[std::get<1>(key)].push_back(spot);
            ++spots;
        }

        uint32 citySpots = 0;
        for (auto const& [key, cell] : cityCells)
        {
            Spot spot;
            spot.loc = WorldLocation(std::get<0>(key),
                                     static_cast<float>(cell.sumX / cell.count),
                                     static_cast<float>(cell.sumY / cell.count),
                                     static_cast<float>(cell.sumZ / cell.count));
            spot.level = 0;     // en una capital vale cualquier nivel
            g_citySpots[std::get<1>(key)].push_back(spot);
            ++citySpots;
        }

        LOG_INFO("module", "[world-bots] {} puntos de caza en {} zonas, a partir de {} bichos; "
                           "{} puntos de ciudad en {} capitales, a partir de {} NPC de servicio.",
                 spots, g_spots.size(), considered, citySpots, g_citySpots.size(), cityNpcs);
    }

    // ─── Despertar bots de la reserva ───────────────────────────────────────
    // Igual que en mod-queue-bots: el servidor tiene ~1500 personajes de bot pero
    // mantiene despiertos muchos menos. Si en el mundo no hay bastantes libres
    // de tu tramo, se encienden de la tabla de personajes; si el mundo está en
    // su tope, antes se manda a dormir a otros tantos ociosos y fuera del tramo.
    uint32 MakeRoom(uint32 wanted, uint32 keepMin, uint32 keepMax, PlayerSnapshot& snapshot)
    {
        uint32 freed = 0;

#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        // LogoutPlayerBot es SINCRONO (LogoutPlayer -> RemoveFromWorld ->
        // ObjectAccessor::RemoveObject): llamarlo dentro del range-for sobre
        // GetPlayers() muta el contenedor en plena iteracion -> UB en ++it.
        // Se recogen los GUID y se desconectan tras cerrar el bucle.
        std::vector<ObjectGuid> victims;
        for (Player* bot : snapshot.bots)
        {
            if (victims.size() >= wanted)
                break;

            if (!IsFreeBot(bot))
                continue;

            if (bot->GetLevel() >= keepMin && bot->GetLevel() <= keepMax)
                continue;               // este nos sirve, no lo tocamos

            if (snapshot.humanZones.count(bot->GetZoneId()))
                continue;               // está acompañando a alguien

            if (BotClaims::IsHomeGuildBot(bot->GetGUID().GetCounter()))
                continue;               // los de tu hermandad no se mandan a dormir

            victims.push_back(bot->GetGUID());
        }

        for (ObjectGuid const& guid : victims)
        {
            snapshot.bots.erase(std::remove_if(snapshot.bots.begin(), snapshot.bots.end(),
                [&guid](Player* bot) { return bot && bot->GetGUID() == guid; }), snapshot.bots.end());
            sRandomPlayerbotMgr.LogoutPlayerBot(guid);
            ++freed;
        }
#else
        (void)wanted; (void)keepMin; (void)keepMax; (void)snapshot;
#endif

        return freed;
    }

    uint32 WakeBots(uint32 wanted, uint32 minLevel, uint32 maxLevel, TeamId team,
                    PlayerSnapshot& snapshot, uint32& teleportsLeft)
    {
        if (!wanted || !cfg.wakeBots || !teleportsLeft)
            return 0;

#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        // Tardan unos segundos en entrar al mundo: sin este freno se pedirían
        // otros tantos en la pasada siguiente.
        uint64_t const now = TimeMs::NowMs();
        if (now < g_nextWake)
            return 0;
        g_nextWake = now + TimeMs::SecsToMs(cfg.wakeBatchSecs);

        // Un login pesa tanto como un teletransporte: sale del mismo presupuesto.
        wanted = std::min({ wanted, cfg.wakeMax, teleportsLeft });

        uint32 const cap = sConfigMgr->GetOption<uint32>("Playerbots.MaxRandomBots", 200);
        // Solo bots aleatorios: contar los alt-bots de jugadores contra
        // MaxRandomBots inflaba el recuento y MakeRoom mandaba a dormir bots
        // aleatorios que no sobraban (§3.2 BAJO).
        uint32 online = 0;
        for (Player* bot : snapshot.bots)
            if (bot && IsRandomBot(bot))
                ++online;
        if (online + wanted > cap)
            MakeRoom(online + wanted - cap, minLevel, maxLevel, snapshot);

        // medir el coste real de BotWake (hasta dos consultas
        // síncronas por selección) antes de decidir si hace falta precargar
        // candidatos de forma asíncrona.
        uint32 const tWake0 = getMSTime();
        auto const wakeCandidates = BotWake::SelectOfflineCandidates(
            wanted, minLevel, maxLevel, team == TEAM_ALLIANCE);
        SlowTick::WarnIfSlow("world-bots", "BotWake::SelectOfflineCandidates", tWake0);

        uint32 woken = 0;
        for (uint32 const lowGuid : wakeCandidates)
        {
            if (!sRandomPlayerbotMgr.IsRandomBot(lowGuid))
                continue;               // no es un bot: ni tocarlo

            BotPopulationCoordinator::Reservation reservation = BotPopulationCoordinator::Reserve(
                lowGuid, "world-bots",
                team == TEAM_ALLIANCE ? BotPopulationCoordinator::Faction::Alliance
                                      : BotPopulationCoordinator::Faction::Horde,
                minLevel, maxLevel);
            if (!reservation)
                continue;

            sRandomPlayerbotMgr.AddPlayerBot(ObjectGuid::Create<HighGuid::Player>(lowGuid), 0);
            --teleportsLeft;
            if (++woken >= wanted)
                break;
        }

        if (woken)
            LOG_INFO("module", "[world-bots] Despertando {} bots dormidos de nivel {}-{} ({}).",
                     woken, minLevel, maxLevel, team == TEAM_ALLIANCE ? "Alianza" : "Horda");

        return woken;
#else
        (void)minLevel; (void)maxLevel; (void)team; (void)snapshot; (void)teleportsLeft;
        return 0;
#endif
    }

    // ─── Teletransportar un bot a un punto de caza ──────────────────────────
    // La misma secuencia que hace playerbots en RandomTeleport (que es privada):
    // comprobar agua y altura, limpiar el movimiento, reiniciar la IA, quitar las
    // auras que se pierden al teletransportarse, y TeleportTo. Y su misma
    // precaución: si hay un jugador viendo al bot, no desaparece delante de él.
    //
    // Salto entre mapas != salto dentro del mismo mapa. El segundo lo resuelve
    // TeleportTo ahí mismo, síncrono. El primero lo deja pendiente ("far
    // teleport") y sólo lo remata PlayerbotAI::HandleTeleportAck en un tick
    // posterior (PlayerbotHolder::UpdateSessions, cada pasada de playerbots) —
    // y ese remate es quien hace su propio Reset(true) cuando corresponde.
    // Tocar aquí mismo el movimiento/mascota/objetivo de rol de un bot que
    // AÚN no ha llegado (su mapa real sigue siendo el de antes) deja el salto
    // a medio completar para siempre: confirmado en la VM el 11/09/2026 con
    // bots de nivel bajo que StagePass decía haber recolocado y seguían en el
    // mapa bloqueado varios minutos después. Con salto entre mapas, sólo se
    // limpian aura y movimiento antes de TeleportTo; el resto lo hace
    // playerbots cuando el bot esté de verdad en el mapa nuevo.
    //
    // antes se copiaba Y barajaba el vector de puntos entero
    // en cada llamada, aunque el primero fuera válido, y si ninguno lo era se
    // recorrían todos — con B bots y S puntos, trabajo proporcional a B×S.
    // Ahora 'order' es una permutación de índices sobre 'spots' que el
    // llamador baraja UNA SOLA VEZ por pasada (no por bot) y esta función se
    // limita a probar como mucho 'attempts' puntos empezando en 'start',
    // rotando con módulo: cada bot de la misma pasada arranca en un punto
    // distinto del mismo orden compartido (diversidad sin rebarajar), y el
    // presupuesto de intentos acota el coste aunque la zona tenga muchos
    // puntos y todos fallen. Si 'attempts' no basta, el llamador avanza el
    // cursor para la síguiente pasada (WorldBotsPolicy no interviene aquí:
    // es aritmética de índices, no de población). outFarTeleport, si no es
    // nulo, se marca cuando el salto ha sido entre mapas (para que el
    // llamador registre la llegada como pendiente, M23).
    bool TeleportBot(Player* bot, std::vector<Spot> const& spots, std::vector<uint32> const& order,
                     uint32 start, uint32 attempts, bool city, bool* outFarTeleport = nullptr)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        PlayerbotAI* botAI = GET_PLAYERBOT_AI(bot);
        if (!botAI)
            return false;

        if (botAI->HasPlayerNearby(cfg.nearbyRadius))
            return false;

        uint32 const mapBefore = bot->GetMapId();
        uint32 const n = static_cast<uint32>(order.size());
        uint32 const tries = std::min(attempts, n);

        for (uint32 k = 0; k < tries; ++k)
        {
            Spot const& spot = spots[order[(start + k) % n]];

            Map* map = sMapMgr->FindMap(spot.loc.GetMapId(), 0);
            if (!map)
                continue;

            float const x = spot.loc.GetPositionX();
            float const y = spot.loc.GetPositionY();
            float z = spot.loc.GetPositionZ();

            if (map->IsInWater(bot->GetPhaseMask(), x, y, z, bot->GetCollisionHeight()))
                continue;

            float const ground = map->GetHeight(bot->GetPhaseMask(), x, y, z + 0.5f);
            if (ground <= INVALID_HEIGHT)
                continue;
            z = 0.05f + ground;

            bool const farTeleport = spot.loc.GetMapId() != mapBefore;

            // Destino válido: los efectos secundarios van AQUÍ, tras validar
            // el punto, y si TeleportTo falla no se reintenta con otro spot
            // — así no se repite el Reset una y otra vez (§3.2 BAJO).
            bot->GetMotionMaster()->Clear();
            if (!farTeleport)
                botAI->Reset(true);
            bot->RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_TELEPORTED | AURA_INTERRUPT_FLAG_CHANGE_MAP);
            if (!bot->TeleportTo(spot.loc.GetMapId(), x, y, z, 0))
                return false;

            if (farTeleport)
            {
                if (outFarTeleport)
                    *outFarTeleport = true;
                return true;   // el resto lo remata HandleTeleportAck cuando el bot llegue de verdad
            }

            bot->SendMovementFlagUpdate();

            // La mascota de un cazador o brujo reubicado no se queda atrás: la
            // versión PvP ya la movía, la de poblado no (§3.2 BAJO).
            if (Pet* pet = bot->GetPet())
                pet->NearTeleportTo(x, y, z, 0);

            // Que su estrategia de rol no se lo lleve de vuelta a donde iba:
            // en la ciudad, que decida de nuevo desde cero (paseará entre los
            // NPC); en el campo, que cace alrededor del punto al que llega.
            // Es lo mismo que hace el comando "rpg status" de playerbots.
            if (city)
                botAI->rpgInfo.ChangeToIdle();
            else
                botAI->rpgInfo.ChangeToGoGrind(WorldPosition(spot.loc.GetMapId(), x, y, z, 0.0f));
            return true;
        }
#else
        (void)bot; (void)spots; (void)order; (void)start; (void)attempts; (void)city; (void)outFarTeleport;
#endif
        return false;
    }

    // Recoge hasta 'wanted' bots libres del tramo y la facción pedidos que estén
    // fuera de esta zona y no acompañando a ningún otro jugador. Barajados.
    std::vector<Player*> CollectBots(uint32 wanted, uint32 minLevel, uint32 maxLevel, TeamId team,
                                     uint32 zoneId, PlayerSnapshot const& snapshot)
    {
        std::vector<Player*> candidates;
        if (!wanted)
            return candidates;

        for (Player* bot : snapshot.bots)
        {
            if (!IsFreeBot(bot))
                continue;

            if (bot->GetLevel() < minLevel || bot->GetLevel() > maxLevel)
                continue;

            if (team != TEAM_NEUTRAL && bot->GetTeamId() != team)
                continue;

            uint32 const botZone = bot->GetZoneId();
            if (botZone == zoneId || snapshot.humanZones.count(botZone))
                continue;

            candidates.push_back(bot);
            if (candidates.size() >= wanted * 4 + 8)
                break;
        }

        if (candidates.size() > wanted)
        {
            Acore::Containers::RandomShuffle(candidates);
            candidates.resize(wanted);
        }

        return candidates;
    }

    char const* TeamName(TeamId team)
    {
        return team == TEAM_ALLIANCE ? "Alianza" : "Horda";
    }

    // ─── Etapas ─────────────────────────────────────────────────────────────
    // 0 Vanilla, 1 TBC, 2 WotLK (sin restricción). La progresión de un jugador
    // la guarda mod-individual-progression como misiones ocultas recompensadas
    // (66000 + nivel de progresión): se lee igual que lo hace el módulo, sin
    // depender de su cabecera.
    uint8  g_stage = 2;
    bool   g_stageApplied = false;
    uint32 g_stageSavedMaxLevel = 0;
    std::vector<uint32> g_stageSavedMaps;
    uint64 g_nextStagePass = 0;
    uint64 g_nextStageSync = 0;
    std::string g_stageBy;
    uint32 g_stageRelocated = 0, g_stageRerolled = 0;

    // ─── Escalado de poblacion por jugador ─────────────────────────────────
    bool   g_playerScaleApplied  = false;
    uint32 g_playerScaleSavedMin = 0;
    uint32 g_playerScaleSavedMax = 0;
    uint64 g_nextPlayerScaleSync = 0;

    // Cuándo un intento de recolocar (StagePassMap, vía TeleportBot y el
    // índice propio de puntos de caza) no encontró ningún punto válido -agua,
    // altura, mapa sin cargar-: cuarentena de 60 s para no reintentar al
    // mismo bot en todas las pasadas siguientes a costa de los demás.
    std::unordered_map<uint32, uint64> g_stageMapBackoff;

    // Centralizado en BotGear.h (M22): mismo cálculo que usa party-here para
    // el tope de equipo, sin duplicar la lectura de 66000+i.
    uint8 ProgressionOf(Player* player)
    {
        return BotGear::PlayerPhase(player);
    }

    uint8 StageOfProgression(uint8 progression)
    {
        if (progression >= cfg.stageWotlkFrom) return 2;
        if (progression >= cfg.stageTbcFrom)   return 1;
        return 0;
    }

    char const* StageName(uint8 stage)
    {
        return stage == 0 ? "Vanilla" : (stage == 1 ? "TBC" : "WotLK");
    }

    uint32 MaxPlayerLevel()
    {
        return sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL);
    }

    // Nivel tope de la etapa activa (el máximo del reino si no hay restricción)
    uint32 StageCap()
    {
        if (!cfg.stageEnable || g_stage >= 2)
            return MaxPlayerLevel();
        return std::min(MaxPlayerLevel(), g_stage == 0 ? cfg.stageVanillaCap : cfg.stageTbcCap);
    }

    std::vector<uint32> const& StageMaps()
    {
        return g_stage == 0 ? cfg.stageVanillaMaps : cfg.stageTbcMaps;
    }

    bool StageAllowsMap(uint32 mapId)
    {
        if (!cfg.stageEnable || g_stage >= 2)
            return true;
        std::vector<uint32> const& maps = StageMaps();
        return std::find(maps.begin(), maps.end(), mapId) != maps.end();
    }

    // Puntos de caza (g_spots, el mismo índice que usa FillZone) que caen en
    // los mapas de la etapa activa, cerca del nivel del bot. playerbots
    // (RandomTeleportForLevel) construye su propia caché de destinos una
    // sola vez al arrancar el mundo, antes de que ninguna etapa la haya
    // restringido, y para algunos niveles el resultado es "sin destino": la
    // llamada no falla con ningún aviso, el bot simplemente no se mueve. Con
    // el índice propio, ya filtrado por mapa, se evita ese problema del todo.
    // Si no hay ningún punto de ese nivel en los mapas de la etapa (no
    // debería pasar: Vanilla y TBC siempre incluyen los mapas 0 y 1, con
    // huecos de nivel de sobra), se ensancha a cualquier punto de esos mapas.
    std::vector<Spot> CollectStageSpots(uint32 botLevel)
    {
        std::vector<uint32> const& maps = StageMaps();
        std::vector<Spot> inBand, anyLevel;
        for (auto const& [zoneId, spots] : g_spots)
        {
            (void)zoneId;
            for (Spot const& spot : spots)
            {
                if (std::find(maps.begin(), maps.end(), spot.loc.GetMapId()) == maps.end())
                    continue;
                anyLevel.push_back(spot);
                if (spot.level + 10 >= botLevel && spot.level <= botLevel + 10)
                    inBand.push_back(spot);
            }
        }
        return inBand.empty() ? anyLevel : inBand;
    }

    std::string JoinMaps(std::vector<uint32> const& maps)
    {
        std::string out;
        for (uint32 m : maps)
            out += (out.empty() ? "" : ",") + std::to_string(m);
        return out;
    }

    // Aplica la etapa a playerbots en caliente: nivel máximo de los bots
    // aleatorios y mapas donde los teletransporta. Son campos públicos de su
    // configuración que se leen en cada uso (RandomizeFirst, RandomTeleport).
    void ApplyStage(uint8 stage, std::string const& by)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        if (!g_stageApplied)
        {
            g_stageSavedMaxLevel = sPlayerbotAIConfig.RandomBotMaxLevel;
            g_stageSavedMaps = sPlayerbotAIConfig.RandomBotMaps;
        }
        g_stage = stage;
        g_stageBy = by;

        // BotPopulationCoordinator es el único punto por el que pasan también
        // mod-queue-bots, mod-party-here y mod-home-guild al despertar bots de
        // la reserva: sin esto podían traer uno por encima del tope sin que
        // StagePass llegara nunca a corregirlo (los reclamados no son "libres").
        BotPopulationCoordinator::SetStageCap(StageCap());

        if (stage >= 2)
        {
            if (g_stageApplied)
            {
                sPlayerbotAIConfig.RandomBotMaxLevel = g_stageSavedMaxLevel;
                sPlayerbotAIConfig.RandomBotMaps = g_stageSavedMaps;
            }
            g_stageApplied = false;
            LOG_INFO("module", "[world-bots] Etapa activa: WotLK, sin restriccion ({}): bots aleatorios hasta {} en los mapas {}.",
                     by, sPlayerbotAIConfig.RandomBotMaxLevel, JoinMaps(sPlayerbotAIConfig.RandomBotMaps));
            return;
        }
        sPlayerbotAIConfig.RandomBotMaxLevel = StageCap();
        sPlayerbotAIConfig.RandomBotMaps = StageMaps();
        g_stageApplied = true;
        LOG_INFO("module", "[world-bots] Etapa activa: {} ({}): bots aleatorios hasta el nivel {} en los mapas {}.",
                 StageName(stage), by, StageCap(), JoinMaps(StageMaps()));
#else
        (void)stage; (void)by;
#endif
    }

    char const* const STAGE_NO_IP_REASON = "individual-progression no disponible en este perfil";

    // La etapa más alta de los humanos conectados (sin humanos, sin restricción)
    void UpdateStage(std::vector<Player*> const& humans)
    {
        if (!cfg.stageEnable)
            return;

        // Sin individual-progression en este perfil (M22), ProgressionOf()
        // siempre da 0 para cualquier humano: nadie puede marcar una fase
        // posterior, y el mundo se quedaría en Vanilla para siempre. Eso es
        // degradar un perfil que no usa IP, no "respetar su fase inicial";
        // sin fases que inferir, no hay restricción que aplicar.
        //
        // El motivo mostrado en ".wbots etapa" debe reflejar esto aunque la
        // etapa numérica no cambie: g_stage arranca en 2 (sin restricción) y
        // g_stageApplied vale false para toda etapa >=2, así que comparar solo
        // esos dos campos deja "sin jugadores" congelado para siempre en el
        // caso más común (0 jugadores conectados) en vez de actualizarse al
        // (des)activar IP. Comparar también el motivo evita ese diagnóstico
        // obsoleto sin tocar el tope real, que ya era correcto.
        if (!BotGear::Available())
        {
            if (g_stage != 2 || g_stageApplied || g_stageBy != STAGE_NO_IP_REASON)
                ApplyStage(2, STAGE_NO_IP_REASON);
            return;
        }

        uint8 best = humans.empty() ? 2 : 0;
        std::string by = humans.empty() ? "sin jugadores" : "";
        for (Player* human : humans)
        {
            uint8 prog = ProgressionOf(human);
            uint8 stage = StageOfProgression(prog);
            if (stage >= best && (stage > best || by.empty()))
            {
                best = stage;
                by = Acore::StringFormat("{} con progresion {}", human->GetName(), prog);
            }
        }
        if (best != g_stage || (best < 2 && !g_stageApplied) || by != g_stageBy)
            ApplyStage(best, by);
    }

    void SyncStage(uint64_t now)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        if (!cfg.stageEnable || !g_stageApplied || !cfg.stageSyncSecs || now < g_nextStageSync)
            return;
        g_nextStageSync = now + TimeMs::SecsToMs(cfg.stageSyncSecs);

        if (sPlayerbotAIConfig.RandomBotMaxLevel != StageCap()
            || sPlayerbotAIConfig.RandomBotMaps != StageMaps())
            ApplyStage(g_stage, "resincronizacion periodica");
#else
        (void)now;
#endif
    }

    // Objetivo de poblacion para un numero dado de humanos conectados: nunca
    // por debajo de 1 humano (si esto se llama es porque hay al menos uno; con
    // cero, DisabledWithoutRealPlayer ya se encarga por su cuenta), nunca por
    // encima del tope duro.
    uint32 PlayerScaleTarget(uint32 humanCount)
    {
        // Aritmética pura en WorldBotsPolicy.h.
        return WorldBotsPolicy::PlayerScaleTarget(humanCount, cfg.playerScalePerPlayer, cfg.playerScaleCeiling);
    }

    // Pisa Playerbots.MinRandomBots/MaxRandomBots en caliente (campos publicos
    // que RandomPlayerbotMgr::UpdateAIInternal relee en cada tick, igual que
    // ApplyStage pisa randomBotMaxLevel). Con min == max, el objetivo aleatorio
    // interno del modulo (bot_count) sale exacto y se recalcula solo, en el
    // siguiente tick, en cuanto quede fuera del rango nuevo (RandomPlayerbotMgr.cpp,
    // UpdateAIInternal). Bajar el objetivo no expulsa a nadie
    // de golpe: playerbots retira los sobrantes poco a poco y solo los libres
    // (RemoveRandomBots, desde #2774; antes drenaba la rotacion periodica).
    void ApplyPlayerScale(uint32 humanCount)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        if (!g_playerScaleApplied)
        {
            g_playerScaleSavedMin = sPlayerbotAIConfig.MinRandomBots;
            g_playerScaleSavedMax = sPlayerbotAIConfig.MaxRandomBots;
        }
        uint32 const target = PlayerScaleTarget(humanCount);
        sPlayerbotAIConfig.MinRandomBots = target;
        sPlayerbotAIConfig.MaxRandomBots = target;
        g_playerScaleApplied = true;
        LOG_INFO("module", "[world-bots] Poblacion objetivo ajustada a {} ({} jugador(es) x {}, tope {}).",
                 target, humanCount, cfg.playerScalePerPlayer, cfg.playerScaleCeiling);
#else
        (void)humanCount;
#endif
    }

    void SyncPlayerScale(uint64_t now, uint32 humanCount)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        if (!cfg.playerScaleEnable || !humanCount || !cfg.playerScaleSyncSecs || now < g_nextPlayerScaleSync)
            return;
        g_nextPlayerScaleSync = now + TimeMs::SecsToMs(cfg.playerScaleSyncSecs);

        uint32 const target = PlayerScaleTarget(humanCount);
        if (sPlayerbotAIConfig.MinRandomBots != target || sPlayerbotAIConfig.MaxRandomBots != target)
            ApplyPlayerScale(humanCount);
#else
        (void)now; (void)humanCount;
#endif
    }

    // Pasada de recolocación (cada 5 s, unos pocos bots): en una etapa inferior,
    // los que pasan del tope se re-aleatorizan por debajo (playerbots elige
    // nivel y zona nuevos), y los que están en un mapa bloqueado se
    // teletransportan a uno de la etapa. Nunca delante de un jugador
    // (HasPlayerNearby), nunca a un bot reclamado por otro módulo ni ocupado.
    //
    // Dos barridos separados, no uno: si el de nivel y el de mapa comparten un
    // único contador, un bot de mapa bloqueado que no se puede recolocar (ver
    // g_stageMapBackoff) sale primero en snapshot.bots en TODAS las pasadas y
    // agota el presupuesto antes de llegar a nadie por encima del tope de
    // nivel, que es lo que de verdad importa.
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
    void StagePassLevel(PlayerSnapshot const& snapshot, uint32 cap, uint32& teleportsLeft)
    {
        uint32 done = 0;
        for (Player* bot : snapshot.bots)
        {
            if (done >= cfg.stagePerPass || !teleportsLeft)
                break;
            if (!IsFreeBot(bot) || !IsRandomBot(bot) || BotClaims::IsClaimed(bot->GetGUID().GetCounter()))
                continue;
            if (bot->GetLevel() <= cap)
                continue;
            PlayerbotAI* botAI = GET_PLAYERBOT_AI(bot);
            if (!botAI || botAI->HasPlayerNearby(cfg.nearbyRadius))
                continue;

            uint32 const level = bot->GetLevel();
            sRandomPlayerbotMgr.RandomizeFirst(bot);
            ++done;
            --teleportsLeft;
            ++g_stageRerolled;
            LOG_INFO("module", "[world-bots] Etapa {}: {} pasaba del tope ({} > {}): re-aleatorizado a nivel {}.",
                     StageName(g_stage), bot->GetName(), level, cap, bot->GetLevel());
        }
    }

    // Recoloca con el índice propio de puntos de caza (CollectStageSpots +
    // TeleportBot), no con RandomTeleportForLevel de playerbots: su caché de
    // destinos se construye una sola vez al arrancar el mundo, antes de que
    // ninguna etapa la restrinja, y para algunos niveles no tiene ningún
    // destino dentro de los mapas de la etapa -sin avisar del fallo-. El
    // índice propio ya está filtrado por mapa y se recorre en cada intento,
    // así que no puede quedarse desfasado.
    void StagePassMap(uint64_t now, PlayerSnapshot const& snapshot, uint32& teleportsLeft)
    {
        uint32 done = 0;
        for (Player* bot : snapshot.bots)
        {
            if (done >= cfg.stagePerPass || !teleportsLeft)
                break;
            if (!IsFreeBot(bot) || !IsRandomBot(bot) || BotClaims::IsClaimed(bot->GetGUID().GetCounter()))
                continue;
            if (StageAllowsMap(bot->GetMapId()))
                continue;
            uint32 const guidLow = bot->GetGUID().GetCounter();

            if (auto it = g_stageMapBackoff.find(guidLow); it != g_stageMapBackoff.end())
            {
                if (now < it->second)
                    continue;
                g_stageMapBackoff.erase(it);
            }

            // Gratis, sin gastar presupuesto: puede que ya no haya nadie
            // cerca en la siguiente pasada (TeleportBot repite esta misma
            // comprobación, pero hacerla antes evita meter en cuarentena a
            // un bot que solo tenía la mala suerte de que alguien pasara
            // cerca en este instante).
            PlayerbotAI* botAI = GET_PLAYERBOT_AI(bot);
            if (!botAI || botAI->HasPlayerNearby(cfg.nearbyRadius))
                continue;

            uint32 const level = bot->GetLevel();
            uint32 const mapBefore = bot->GetMapId();
            ++done;
            --teleportsLeft;

            // un bot suelto, no una pasada de FillZone; igualmente se
            // acota a cfg.teleportMaxAttempts en vez de recorrer todos los
            // puntos de la etapa si el primero falla.
            std::vector<Spot> const spots = CollectStageSpots(level);
            std::vector<uint32> order(spots.size());
            std::iota(order.begin(), order.end(), 0u);
            Acore::Containers::RandomShuffle(order);
            uint32 const attempts = std::min<uint32>(static_cast<uint32>(order.size()), cfg.teleportMaxAttempts);
            if (!TeleportBot(bot, spots, order, 0, attempts, false))
            {
                // Agua o altura invalida en todos los puntos candidatos: no
                // insistir en el mismo bot en todas las pasadas siguientes.
                g_stageMapBackoff[guidLow] = now + 60000;
                continue;
            }
            ++g_stageRelocated;
            LOG_INFO("module", "[world-bots] Etapa {}: {} (nivel {}) estaba en el mapa {} (bloqueado): a una zona de su nivel.",
                     StageName(g_stage), bot->GetName(), level, mapBefore);
        }
    }
#endif

    void StagePass(uint64_t now, PlayerSnapshot const& snapshot, uint32& teleportsLeft)
    {
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        if (!cfg.stageEnable || g_stage >= 2 || snapshot.humans.empty()
            || now < g_nextStagePass || !teleportsLeft)
            return;
        g_nextStagePass = now + 5000;
        uint32 const cap = StageCap();
        StagePassLevel(snapshot, cap, teleportsLeft);
        if (teleportsLeft)
            StagePassMap(now, snapshot, teleportsLeft);
#else
        (void)now; (void)snapshot; (void)teleportsLeft;
#endif
    }

    // `ctx` (ChatHandler o Player) sólo decide el idioma del texto.
    template <typename Ctx>
    std::string StageStatus(Ctx const& ctx)
    {
        if (!cfg.stageEnable)
            return ModLocale::L(ctx, "etapas: apagado (WorldBots.Stage.Enable)");
        return Acore::StringFormat(ModLocale::L(ctx, "etapa activa {} ({}): tope {}, mapas {}; desde el arranque {} re-aleatorizados, {} sacados de mapas bloqueados"),
                                   StageName(g_stage), g_stageBy.empty() ? ModLocale::L(ctx, "sin jugadores") : g_stageBy, StageCap(),
                                   g_stage >= 2 ? ModLocale::L(ctx, "todos") : JoinMaps(StageMaps()), g_stageRerolled, g_stageRelocated);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Configuración e índice
// ─────────────────────────────────────────────────────────────────────────────
class mod_world_bots_world : public WorldScript
{
public:
    mod_world_bots_world() : WorldScript("mod_world_bots_world",
                                         { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_UPDATE }) { }

    void OnAfterConfigLoad(bool reload) override
    {
        bool const samaritanWasOn = cfg.samaritan;   // detectar el apagado en caliente
        cfg.enabled       = sConfigMgr->GetOption<bool>("WorldBots.Enable", true);
        cfg.minBots       = sConfigMgr->GetOption<uint32>("WorldBots.MinBots", 12);
        cfg.maxBots       = sConfigMgr->GetOption<uint32>("WorldBots.MaxBots", 25);
        cfg.levelBelow    = sConfigMgr->GetOption<uint32>("WorldBots.LevelBelow", 5);
        cfg.levelAbove    = sConfigMgr->GetOption<uint32>("WorldBots.LevelAbove", 3);
        cfg.minDistance   = sConfigMgr->GetOption<float>("WorldBots.MinDistance", 250.0f);
        cfg.scanMs        = TimeMs::SecsToMs(sConfigMgr->GetOption<uint32>("WorldBots.ScanSeconds", 5));
        cfg.topUpSecs     = sConfigMgr->GetOption<uint32>("WorldBots.TopUpSeconds", 60);
        cfg.maxPerPass    = sConfigMgr->GetOption<uint32>("WorldBots.MaxPerPass", 5);
        cfg.maxTeleportsPerPass = sConfigMgr->GetOption<uint32>("WorldBots.MaxTeleportsPerPass", 10);
        cfg.oppositeShare = sConfigMgr->GetOption<float>("WorldBots.OppositeFactionShare", 0.35f);
        cfg.wakeBots      = sConfigMgr->GetOption<bool>("WorldBots.WakeBots", true);
        cfg.wakeMax       = sConfigMgr->GetOption<uint32>("WorldBots.WakeMax", 20);
        cfg.announce      = sConfigMgr->GetOption<bool>("WorldBots.Announce", false);
        cfg.verbose       = sConfigMgr->GetOption<bool>("WorldBots.Verbose", false);
        cfg.botMinWorldSecs = sConfigMgr->GetOption<uint32>("WorldBots.BotMinWorldSeconds", 60);
        cfg.nearbyRadius  = std::max(sConfigMgr->GetOption<float>("WorldBots.NearbyPlayerRadius", 150.0f), 50.0f);
        cfg.wakeBatchSecs = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.WakeBatchSeconds", 15), 1);
        cfg.zoneSettleSecs = sConfigMgr->GetOption<uint32>("WorldBots.ZoneSettleSeconds", 2);
        cfg.retrySecs     = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.RetrySeconds", 15), 1);
        cfg.deficitGraceSecs = sConfigMgr->GetOption<uint32>("WorldBots.DeficitGraceSeconds", 20);
        cfg.arrivalGraceSecs = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.ArrivalGraceSeconds", 30), 1);
        cfg.teleportMaxAttempts = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.TeleportMaxAttempts", 12), 1);
        cfg.adaptiveDensity  = sConfigMgr->GetOption<bool>("WorldBots.AdaptiveDensity", false);
        cfg.adaptivePerHuman = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.AdaptiveDensityPerHuman", 4), 1);
        cfg.adaptiveMax      = sConfigMgr->GetOption<uint32>("WorldBots.AdaptiveDensityMax", 0);
        cfg.samaritan        = sConfigMgr->GetOption<bool>("WorldBots.Samaritan", false);
        cfg.samaritanHpPct   = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.SamaritanHpPercent", 35), 1, 99);
        cfg.samaritanRadius  = std::max(sConfigMgr->GetOption<float>("WorldBots.SamaritanRadius", 45.0f), 5.0f);
        cfg.samaritanMaxHelpers = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.SamaritanMaxHelpers", 2), 1);
        cfg.samaritanCooldownSecs = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.SamaritanCooldownSeconds", 120), 10);
        cfg.samaritanDurationSecs = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.SamaritanDurationSeconds", 45), 10);
        cfg.samaritanLevelBelow = sConfigMgr->GetOption<uint32>("WorldBots.SamaritanLevelBelow", 3);
        cfg.samaritanLevelAbove = sConfigMgr->GetOption<uint32>("WorldBots.SamaritanLevelAbove", 8);
        if (samaritanWasOn && !cfg.samaritan)   // apagado por config, no sólo por comando
            RecallHelpersIf([](Helper const&) { return true; }, "modo samaritano desactivado");
        BotPopulationCoordinator::LoadSettings();
        BotPopulationCoordinator::RefreshOnline(TimeMs::NowMs(), true);
        cfg.cityMinBots     = sConfigMgr->GetOption<uint32>("WorldBots.CityMinBots", 30);
        cfg.cityMaxBots     = sConfigMgr->GetOption<uint32>("WorldBots.CityMaxBots", 50);
        cfg.cityMinDistance = sConfigMgr->GetOption<float>("WorldBots.CityMinDistance", 150.0f);

        // Las once capitales (y las dos ciudades santuario), por id de zona.
        cfg.cityZones.clear();
        std::string const cities = sConfigMgr->GetOption<std::string>(
            "WorldBots.CityZones", "1519,1537,1657,3557,1637,1638,1497,3487,3703,4395");
        for (std::string_view token : Acore::Tokenize(cities, ',', false))
            if (Optional<uint32> zoneId = Acore::StringTo<uint32>(token))
                cfg.cityZones.push_back(*zoneId);

        if (cfg.maxBots < cfg.minBots)
            cfg.maxBots = cfg.minBots;
        if (cfg.cityMaxBots < cfg.cityMinBots)
            cfg.cityMaxBots = cfg.cityMinBots;
        if (cfg.minDistance < cfg.nearbyRadius)
            cfg.minDistance = cfg.nearbyRadius;   // por debajo, el jugador vería aparecer al bot
        if (cfg.cityMinDistance < cfg.nearbyRadius)
            cfg.cityMinDistance = cfg.nearbyRadius;
        if (!cfg.maxPerPass)
            cfg.maxPerPass = 1;
        cfg.oppositeShare = std::clamp(cfg.oppositeShare, 0.0f, 1.0f);

        cfg.stageEnable     = sConfigMgr->GetOption<bool>("WorldBots.Stage.Enable", true);
        cfg.stageTbcFrom    = sConfigMgr->GetOption<uint32>("WorldBots.Stage.TbcFrom", 8);
        cfg.stageWotlkFrom  = sConfigMgr->GetOption<uint32>("WorldBots.Stage.WotlkFrom", 13);
        cfg.stageVanillaCap = sConfigMgr->GetOption<uint32>("WorldBots.Stage.VanillaCap", 60);
        cfg.stageTbcCap     = sConfigMgr->GetOption<uint32>("WorldBots.Stage.TbcCap", 70);
        cfg.stagePerPass    = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.Stage.PerPass", 3), 1, 20);
        cfg.stageSyncSecs   = sConfigMgr->GetOption<uint32>("WorldBots.Stage.SyncSeconds", 60);
        auto readMaps = [](char const* key, char const* def, std::vector<uint32>& out)
        {
            out.clear();
            std::string const text = sConfigMgr->GetOption<std::string>(key, def);
            for (std::string_view token : Acore::Tokenize(text, ',', false))
                if (Optional<uint32> mapId = Acore::StringTo<uint32>(token))
                    out.push_back(*mapId);
        };
        readMaps("WorldBots.Stage.VanillaMaps", "0,1", cfg.stageVanillaMaps);
        readMaps("WorldBots.Stage.TbcMaps", "0,1,530", cfg.stageTbcMaps);

        cfg.playerScaleEnable    = sConfigMgr->GetOption<bool>("WorldBots.PlayerScale.Enable", false);
        cfg.playerScalePerPlayer = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.PlayerScale.PerPlayer", 150), 1);
        cfg.playerScaleCeiling   = std::max<uint32>(sConfigMgr->GetOption<uint32>("WorldBots.PlayerScale.Ceiling", 600), cfg.playerScalePerPlayer);
        cfg.playerScaleSyncSecs  = sConfigMgr->GetOption<uint32>("WorldBots.PlayerScale.SyncSeconds", 60);
        g_nextPlayerScaleSync = 0;   // recalcula ya en el siguiente tick tras arranque/reload

        // Los mapas son los de playerbots: fuera de ellos no vive ningún bot
        // aleatorio, así que no tendría sentido soltarlos ahí.
        cfg.maps.clear();
        std::string const maps = sConfigMgr->GetOption<std::string>("Playerbots.RandomBotMaps", "0,1,530,571");
        for (std::string_view token : Acore::Tokenize(maps, ',', false))
            if (Optional<uint32> mapId = Acore::StringTo<uint32>(token))
                cfg.maps.push_back(*mapId);

#ifndef WORLD_BOTS_WITH_PLAYERBOTS
        if (cfg.enabled)
        {
            LOG_INFO("module", "[world-bots] Compilado sin mod-playerbots: no hay bots que mover, el modulo no hace nada.");
            cfg.enabled = false;
        }
#endif

        // cityZones y maps se acaban de repoblar arriba, pero el índice de
        // puntos de caza/ciudad (IsCity, g_spots/g_citySpots) sólo se
        // construía en OnStartup: tras un ".reload config" quedaba con las
        // claves viejas -una zona añadida a CityZones no tenía entrada en
        // g_citySpots, una quitada dejaba basura en él-, y si el módulo se
        // habilitaba en caliente (estaba apagado al arrancar) el índice
        // quedaba vacío para siempre (OnUpdate exige g_spots no vacío).
        if (reload && cfg.enabled)
        {
            BuildSpotIndex();
            g_warnedZones.clear();
        }

#ifdef WORLD_BOTS_WITH_PLAYERBOTS
        // WorldBots.Stage muta en caliente sPlayerbotAIConfig.RandomBotMaxLevel
        // y randomBotMaps. Tras un ".reload config" hay que reconciliar:
        //  - si el modulo o la etapa se han apagado y habia restriccion puesta,
        //    restaurar los valores originales de playerbots (antes quedaban
        //    mutados hasta el reinicio);
        //  - si siguen activos, reaplicar: un ".reload config" de playerbots
        //    devuelve esos campos a su valor de fichero y UpdateStage no lo
        //    detecta (best == g_stage). El "original" guardado es best-effort
        //    tras ese reload, pero solo se usa al restaurar.
        if (reload && g_stageApplied && (!cfg.enabled || !cfg.stageEnable))
        {
            sPlayerbotAIConfig.RandomBotMaxLevel = g_stageSavedMaxLevel;
            sPlayerbotAIConfig.RandomBotMaps     = g_stageSavedMaps;
            g_stageApplied = false;
            g_stage = 2;
            BotPopulationCoordinator::SetStageCap(MaxPlayerLevel());
            LOG_INFO("module", "[world-bots] Etapa restaurada ({} desactivado): "
                     "playerbots vuelve a nivel {} en los mapas {}.",
                     cfg.enabled ? "WorldBots.Stage.Enable" : "WorldBots.Enable",
                     sPlayerbotAIConfig.RandomBotMaxLevel, JoinMaps(sPlayerbotAIConfig.RandomBotMaps));
        }
        else if (reload && cfg.enabled && cfg.stageEnable && g_stageApplied)
        {
            ApplyStage(g_stage, "reload config");
        }

        // Mismo razonamiento para el escalado por jugador: si se apaga en
        // caliente (el modulo entero o solo PlayerScale.Enable), devolver a
        // playerbots el min/max que tenia antes de que este modulo lo tocara.
        // Si sigue activo, no hace falta reaplicar aqui: g_nextPlayerScaleSync
        // ya se puso a 0 arriba y la siguiente pasada de DoUpdate recalcula.
        if (reload && g_playerScaleApplied && (!cfg.enabled || !cfg.playerScaleEnable))
        {
            sPlayerbotAIConfig.MinRandomBots = g_playerScaleSavedMin;
            sPlayerbotAIConfig.MaxRandomBots = g_playerScaleSavedMax;
            g_playerScaleApplied = false;
            LOG_INFO("module", "[world-bots] Escalado por jugador restaurado ({} desactivado): "
                     "playerbots vuelve a min/max {}/{}.",
                     cfg.enabled ? "WorldBots.PlayerScale.Enable" : "WorldBots.Enable",
                     sPlayerbotAIConfig.MinRandomBots, sPlayerbotAIConfig.MaxRandomBots);
        }
#endif
    }

    void OnStartup() override
    {
        if (!cfg.enabled)
            return;

        BuildSpotIndex();
    }

    void OnUpdate(uint32 /*diff*/) override
    {
        uint32 const t0 = getMSTime();
        DoUpdate();
        SlowTick::WarnIfSlow("world-bots", "OnUpdate", t0);
    }

private:
    // ya se publicó la estadística con enabled=false de este apagado.
    bool _offPublished = false;

    void DoUpdate()
    {
        // Aunque el módulo esté apagado hay que devolver a sus ayudantes
        // samaritanos: se quedarían reservados para siempre si no.
        if ((!cfg.enabled || g_spots.empty()) && !g_helpers.empty())
        {
            for (auto const& pair : g_helpers)
                RestoreHelper(pair.first, pair.second, "modulo apagado");
            g_helpers.clear();
            g_samaritanCooldown.clear();
        }

        if (!cfg.enabled || g_spots.empty())
        {
            // última estadística con enabled=false y buzón cerrado. Sin
            // puntos cargados tampoco hay pasada que adelantar.
            if (!_offPublished)
            {
                _offPublished = true;
                BotOperations::WorldStageStats stats;
                stats.stage = g_stage;
                stats.stageName = StageName(g_stage);
                stats.updatedAtMs = TimeMs::NowMs();
                BotOperations::PublishWorldStageStats(std::move(stats));
            }
            BotOperations::SetTargetOffline(BotOperations::Target::WorldBotsStage, TimeMs::NowMs(),
                cfg.enabled ? "world-bots no tiene puntos de poblacion cargados." : "world-bots esta desactivado.");
            return;
        }
        _offPublished = false;

        uint64_t const now = TimeMs::NowMs();

        std::unordered_set<ObjectGuid> changed;
        {
            std::lock_guard<std::mutex> lock(g_pendingLock);
            changed.swap(g_pending);
        }

        // Comandos ".wbots" encolados: se atienden antes del throttle, y
        // ".wbots aqui" pone g_nextScan a `now` para que esta misma pasada no se
        // salte el rellenado.
        {
            std::vector<WbCmd> cmds;
            {
                std::lock_guard<std::mutex> lock(g_wbCmdLock);
                cmds.swap(g_wbCmd);
            }
            for (WbCmd const& cmd : cmds)
                HandleWbCommand(cmd, now);
        }

        // Acciones del panel (mod-bot-operations, via BotOperations.h):
        // "adelanta la proxima pasada" resetea el mismo throttle global que
        // ".wbots aqui" resetea para una sola zona (WB_CMD_HERE, mas arriba);
        // el resto del relleno sigue con sus propios limites de siempre.
        for (BotOperations::ActionRequest const& request : BotOperations::TakeRequests(BotOperations::Target::WorldBotsStage, now))
        {
            if (request.type == BotOperations::ActionType::WorldBotsPass)
            {
                g_nextScan = now;
                BotOperations::ReportOutcome(request.id, true, "Proxima pasada de poblacion/etapa adelantada.", now);
            }
            else
                BotOperations::ReportOutcome(request.id, false, "Accion no reconocida por world-bots.", now);
        }

        if (changed.empty() && now < g_nextScan)
            return;
        g_nextScan = now + cfg.scanMs;
        ++g_statPasses;

        // Quién está dónde. Las zonas con jugador se respetan: de ellas no se
        // saca a ningún bot para llevarlo a otra.
        PlayerSnapshot snapshot;
        for (auto const& pair : ObjectAccessor::GetPlayers())
        {
            Player* player = pair.second;
            WorldSession* session = player ? player->GetSession() : nullptr;
            if (!session || !player->IsInWorld())
                continue;
            if (session->IsHeadless())
                snapshot.bots.push_back(player);
            else
            {
                snapshot.humans.push_back(player);
                snapshot.humanZones.insert(player->GetZoneId());
                ++snapshot.humanZoneCount[player->GetZoneId()];
            }
        }

        // El coordinador reutiliza esta misma foto: ni Reserve() ni
        // `.bots estado` vuelven a escanear ObjectAccessor esta pasada.
        BotPopulationCoordinator::RefreshOnlineFrom(snapshot.bots, now);

        // Etapa activa (la más alta de los conectados) y recolocación
        UpdateStage(snapshot.humans);
        SyncStage(now);
        SyncPlayerScale(now, static_cast<uint32>(snapshot.humans.size()));
        uint32 teleportsLeft = cfg.maxTeleportsPerPass;
        StagePass(now, snapshot, teleportsLeft);

        // Estadisticas para el panel (pestaña "Mundo y etapa"): solo este
        // OnUpdate es dueño de g_stage/g_stageBy/g_stageRelocated/g_stageRerolled,
        // asi que publica el aqui, tras la pasada de etapa de este tick.
        {
            BotOperations::WorldStageStats stats;
            stats.enabled = cfg.enabled;
            stats.stage = g_stage;
            stats.stageName = StageName(g_stage);
            stats.decidedBy = g_stageBy;
            stats.levelCap = StageCap();
            stats.maps.assign(StageMaps().begin(), StageMaps().end());
            stats.zonesPopulated = static_cast<uint32_t>(snapshot.humanZones.size());
            stats.relocatedTotal = g_stageRelocated;
            stats.rerolledTotal = g_stageRerolled;
            stats.updatedAtMs = now;
            BotOperations::PublishWorldStageStats(std::move(stats));
        }

        // Olvidar a los que se han ido.
        for (auto it = g_visits.begin(); it != g_visits.end();)
        {
            bool present = false;
            for (Player* human : snapshot.humans)
                if (human->GetGUID() == it->first)
                {
                    present = true;
                    break;
                }
            it = present ? std::next(it) : g_visits.erase(it);
        }

        for (Player* player : snapshot.humans)
        {
            ObjectGuid const guid = player->GetGUID();

            // En instancias, campos de batalla y arenas no hay zona que poblar.
            Map* map = player->GetMap();
            if (!map || map->IsDungeon() || map->IsBattlegroundOrArena() || player->IsBeingTeleported())
            {
                g_visits.erase(guid);
                continue;
            }

            uint32 const zoneId = player->GetZoneId();
            Visit& visit = g_visits[guid];

            // Zona nueva: objetivo nuevo. Si el núcleo avisa de "cambio de zona"
            // pero es la misma (al entrar, al aterrizar de un vuelo, al volver
            // de una instancia), se conserva el objetivo y sólo se adelanta la
            // pasada: re-sortearlo hacía que el log dijera "0 de 23" y luego
            // "0 de 13" para el mismo sitio.
            if (visit.zone != zoneId)
            {
                visit.zone = zoneId;
                visit.target = ZoneTarget(zoneId, IsCity(zoneId), snapshot);
                visit.nextFillMs = now + TimeMs::SecsToMs(cfg.zoneSettleSecs);   // que la zona se asiente antes de contar
                visit.everCovered = false;      // zona nueva, sin histéresis heredada de la anterior
                visit.deficitSinceMs = 0;
                continue;
            }
            // Con densidad adaptativa el objetivo se recalcula cada pasada según
            // los humanos que haya ahora en la zona (sin adaptativa es estable).
            if (cfg.adaptiveDensity)
                visit.target = ZoneTarget(zoneId, IsCity(zoneId), snapshot);
            if (changed.count(guid))
                visit.nextFillMs = std::min(visit.nextFillMs, now + TimeMs::SecsToMs(cfg.zoneSettleSecs));

            if (now < visit.nextFillMs)
                continue;

            // cronometrar cada pasada de FillZone por separado
            // del resto de OnUpdate. FillZone recorre snapshot.bots por
            // visita humana (varias veces: have/haveTheirs, CollectBots por
            // bando) y snapshot.humans dentro de pickSpots por punto de caza;
            // con dos humanos en la misma zona o en zonas distintas y
            // 300-600 bots esto puede pesar más que el resto de la pasada.
            uint32 const tFillZone0 = getMSTime();
            FillZone(player, visit, snapshot, teleportsLeft, now);
            SlowTick::WarnIfSlow("world-bots", "FillZone", tFillZone0);
        }

        SamaritanPass(snapshot, now);
    }

private:
    // ─── Modo "buen samaritano" (CS-4.4, experimental) ──────────────────────
    void RestoreHelper(ObjectGuid botGuid, Helper const& h, char const* why)
    {
        if (Player* bot = ObjectAccessor::FindPlayer(botGuid))
        {
            if (bot->IsInCombat())
                bot->CombatStop(true);
            if (bot->isDead())
            {
                bot->ResurrectPlayer(1.0f, false);
                bot->SpawnCorpseBones();
            }
            bot->GetMotionMaster()->Clear();
#ifdef WORLD_BOTS_WITH_PLAYERBOTS
            if (PlayerbotAI* botAI = GET_PLAYERBOT_AI(bot))
            {
                botAI->Reset(true);
                bot->RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_TELEPORTED | AURA_INTERRUPT_FLAG_CHANGE_MAP);
                if (bot->TeleportTo(h.origin.GetMapId(), h.origin.GetPositionX(), h.origin.GetPositionY(),
                                    h.origin.GetPositionZ(), h.origin.GetOrientation()))
                {
                    if (Pet* pet = bot->GetPet())
                        pet->NearTeleportTo(h.origin.GetPositionX(), h.origin.GetPositionY(), h.origin.GetPositionZ(), 0);
                    botAI->rpgInfo.ChangeToGoGrind(WorldPosition(h.origin.GetMapId(), h.origin.GetPositionX(),
                                                                h.origin.GetPositionY(), h.origin.GetPositionZ(), 0.0f));
                }
            }
#endif
            LOG_DEBUG("module", "[world-bots] {} deja de ayudar ({}).", bot->GetName(), why);
        }
        BotClaims::Release(botGuid.GetCounter(), SAMARITAN_OWNER);
    }

    // Retira al momento a todo ayudante que cumpla 'match':
    // la revocación por ".wbots samaritano off" o por WorldBots.Samaritan=0
    // en caliente (".reload config") no debe esperar a que SamaritanPass
    // vuelva a pasar (hasta WorldBots.ScanSeconds de retardo) ni al fin
    // natural del combate o el plazo, que es lo único que hacía antes.
    template <typename Predicate>
    void RecallHelpersIf(Predicate match, char const* why)
    {
        for (auto it = g_helpers.begin(); it != g_helpers.end();)
        {
            if (match(it->second))
            {
                RestoreHelper(it->first, it->second, why);
                it = g_helpers.erase(it);
            }
            else
                ++it;
        }
    }

    void SamaritanPass(PlayerSnapshot const& snapshot, uint64_t now)
    {
        // 1. Retirar a los ayudantes: se acabó el tiempo, el humano se fue, ya
        //    no está en peligro, ha rechazado la ayuda (".wbots samaritano
        //    off") o el modo se ha desactivado por configuración. Estas dos
        //    últimas ya se atienden al momento en HandleWbCommand y
        //    OnAfterConfigLoad; esta pasada es la red de seguridad para
        //    cualquier hueco entre una y la otra.
        for (auto it = g_helpers.begin(); it != g_helpers.end();)
        {
            Player* human = ObjectAccessor::FindPlayer(it->second.human);
            bool done = now >= it->second.untilMs || !human || !human->IsInWorld()
                     || !cfg.samaritan || g_samaritanOptOut.count(it->second.human);
            if (!done && !human->IsInCombat())
                done = true;
            if (done)
            {
                RestoreHelper(it->first, it->second, "fin");
                if (human)
                    g_samaritanCooldown[it->second.human] = now + TimeMs::SecsToMs(cfg.samaritanCooldownSecs);
                it = g_helpers.erase(it);
            }
            else
                ++it;
        }

        if (!cfg.samaritan)
            return;

        // 2. Buscar humanos en apuros y mandarles un ayudante.
        for (Player* human : snapshot.humans)
        {
            ObjectGuid const hguid = human->GetGUID();
            if (g_samaritanOptOut.count(hguid) || !human->IsInCombat() || !human->IsAlive())
                continue;
            if (human->GetMaxHealth() == 0
                || human->GetHealth() * 100 / human->GetMaxHealth() > cfg.samaritanHpPct)
                continue;
            if (auto cd = g_samaritanCooldown.find(hguid); cd != g_samaritanCooldown.end() && now < cd->second)
                continue;

            Map* map = human->GetMap();
            if (!map || map->IsDungeon() || map->IsBattlegroundOrArena())
                continue;

            uint32 current = 0;
            for (auto const& pair : g_helpers)
                if (pair.second.human == hguid)
                    ++current;
            if (current >= cfg.samaritanMaxHelpers)
                continue;

            uint32 const level = human->GetLevel();
            uint32 const minLevel = level > cfg.samaritanLevelBelow ? level - cfg.samaritanLevelBelow : 1;
            uint32 const maxLevel = level + cfg.samaritanLevelAbove;
            float const radiusSq = cfg.samaritanRadius * cfg.samaritanRadius;

            uint32 sent = 0;
            for (Player* bot : snapshot.bots)
            {
                if (sent + current >= cfg.samaritanMaxHelpers)
                    break;
                // Candidato hostil o invisible para el humano: distinta
                // facción (no es un aliado suyo) o distinta fase (no puede ni
                // verlo). Ninguno de los dos se presenta como ayuda (M25).
                if (!IsFreeBot(bot) || bot->GetMapId() != human->GetMapId())
                    continue;
                if (bot->GetTeamId() != human->GetTeamId() || !bot->InSamePhase(human))
                    continue;
                if (bot->GetLevel() < minLevel || bot->GetLevel() > maxLevel)
                    continue;
                if (bot->GetExactDist2dSq(human->GetPositionX(), human->GetPositionY()) > radiusSq)
                    continue;

                // Adquirir la reserva ANTES de decidir si se envía, y
                // revalidar sin volver a mirar reservas (IsFreeBotIgnoringClaim,
                // no IsFreeBot): esta última rechazaría la propia reserva que
                // se acaba de adquirir, porque BotClaims::IsClaimed no
                // distingue "reservado por mí" de "reservado por otro" (antes esto tiraba SIEMPRE el intento, así que el
                // samaritano no llegaba a enviar a nadie). Un `Busy` aquí es
                // otro módulo (o esta misma pasada, otro humano) que se ha
                // adelantado con el mismo bot: se respeta su reserva.
                BotClaims::Lease claim(bot->GetGUID().GetCounter(), SAMARITAN_OWNER);
                if (!claim || !claim.IsNew() || !IsFreeBotIgnoringClaim(bot))
                    continue;

#ifdef WORLD_BOTS_WITH_PLAYERBOTS
                PlayerbotAI* botAI = GET_PLAYERBOT_AI(bot);
                if (!botAI)
                    continue;

                Helper helper;
                helper.human   = hguid;
                helper.origin  = WorldLocation(bot->GetMapId(), bot->GetPositionX(), bot->GetPositionY(),
                                               bot->GetPositionZ(), bot->GetOrientation());
                helper.untilMs = now + TimeMs::SecsToMs(cfg.samaritanDurationSecs);

                // A un lado del humano, y a "cazar" ahí: limpia lo que le rodea
                // sin agruparse ni tocarle el botín.
                float const angle = frand(0.0f, 2.0f * static_cast<float>(M_PI));
                float const x = human->GetPositionX() + std::cos(angle) * 3.0f;
                float const y = human->GetPositionY() + std::sin(angle) * 3.0f;
                float z = human->GetPositionZ();
                float const ground = map->GetHeight(human->GetPhaseMask(), x, y, z + 2.0f);
                if (ground > INVALID_HEIGHT && std::fabs(ground - z) < 5.0f)
                    z = ground + 0.05f;

                bot->GetMotionMaster()->Clear();
                botAI->Reset(true);
                bot->RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_TELEPORTED | AURA_INTERRUPT_FLAG_CHANGE_MAP);
                if (!bot->TeleportTo(human->GetMapId(), x, y, z, human->GetOrientation()))
                    continue;
                if (Pet* pet = bot->GetPet())
                    pet->NearTeleportTo(x, y, z, 0);
                botAI->rpgInfo.ChangeToGoGrind(WorldPosition(human->GetMapId(), human->GetPositionX(),
                                                            human->GetPositionY(), human->GetPositionZ(), 0.0f));

                claim.Keep();
                g_helpers[bot->GetGUID()] = helper;
                ++sent;
                ++g_statSamaritan;
                if (cfg.announce)
                    ChatHandler(human->GetSession()).PSendSysMessage(ModLocale::L(human, "Un aventurero acude a ayudarte."));
                WORLD_BOTS_ACTIVITY_LOG("[world-bots] {} acude a ayudar a {} (vida {}%).",
                         bot->GetName(), human->GetName(),
                         human->GetHealth() * 100 / std::max<uint64>(human->GetMaxHealth(), 1));
#endif
            }
        }
    }

    // ─── Comandos ".wbots aqui" / ".wbots estado" (encolados) ───────────────
    void HandleWbCommand(WbCmd const& cmd, uint64_t now)
    {
        Player* gm = ObjectAccessor::FindPlayer(cmd.gm);
        if (!gm || !gm->GetSession())
            return;
        ChatHandler handler(gm->GetSession());

        if (cmd.kind == WB_CMD_SAMARITAN_ON || cmd.kind == WB_CMD_SAMARITAN_OFF)
        {
            if (cmd.kind == WB_CMD_SAMARITAN_OFF)
            {
                g_samaritanOptOut.insert(cmd.gm);
                RecallHelpersIf([&](Helper const& h) { return h.human == cmd.gm; }, "rechazado");
                handler.SendSysMessage(ModLocale::L(handler, "[world-bots] No recibiras ayuda de bots samaritanos (hasta el reinicio)."));
            }
            else
            {
                g_samaritanOptOut.erase(cmd.gm);
                handler.SendSysMessage(cfg.samaritan
                    ? ModLocale::L(handler, "[world-bots] Volveras a recibir ayuda de bots samaritanos cuando estes en apuros.")
                    : ModLocale::L(handler, "[world-bots] El modo samaritano esta desactivado en el servidor (WorldBots.Samaritan = 0)."));
            }
            return;
        }

        if (cmd.kind == WB_CMD_HERE)
        {
            if (!gm->IsInWorld())
            {
                handler.SendSysMessage(ModLocale::L(handler, "[world-bots] No estas en el mundo ahora mismo."));
                return;
            }
            uint32 const zoneId = gm->GetZoneId();
            AreaTableEntry const* zone = sAreaTableStore.LookupEntry(zoneId);
            Visit& visit = g_visits[cmd.gm];
            visit.zone = zoneId;
            visit.target = IsCity(zoneId) ? urand(cfg.cityMinBots, cfg.cityMaxBots)
                                          : urand(cfg.minBots, cfg.maxBots);
            visit.nextFillMs = 0;
            visit.everCovered = false;      // relleno forzado, sin esperar a la histéresis
            visit.deficitSinceMs = 0;
            g_nextScan = now;   // que el throttle no se salte la pasada de este tick
            handler.PSendSysMessage(ModLocale::L(handler, "[world-bots] Relleno forzado de {}: objetivo {} bots."),
                                    zone ? zone->area_name[handler.GetSessionDbcLocale()] : ModLocale::L(handler, "tu zona"), visit.target);
            return;
        }

        // WB_CMD_STATUS
        handler.PSendSysMessage(ModLocale::L(handler, "[world-bots] {}."), StageStatus(handler));
        handler.PSendSysMessage(ModLocale::L(handler, "[world-bots] Desde el arranque: {} pasadas, {} rellenados de zona, "
                                "{} bots reubicados, {} despertados, {} ayudas samaritanas."),
                                g_statPasses, g_statFills, g_statBotsMoved, g_statBotsWoken, g_statSamaritan);
        if (cfg.samaritan)
            handler.PSendSysMessage(ModLocale::L(handler, "[world-bots] Samaritano: activo, {} ayudante(s) ahora mismo."),
                                    static_cast<uint32>(g_helpers.size()));
        if (g_visits.empty())
        {
            handler.SendSysMessage(ModLocale::L(handler, "[world-bots] Ninguna zona con jugador en seguimiento."));
            return;
        }
        for (auto const& pair : g_visits)
        {
            Player* human = ObjectAccessor::FindPlayer(pair.first);
            Visit const& visit = pair.second;
            AreaTableEntry const* zone = sAreaTableStore.LookupEntry(visit.zone);
            std::string const zoneName = zone
                ? std::string(zone->area_name[handler.GetSessionDbcLocale()])
                : (std::string(ModLocale::L(handler, "zona ")) + std::to_string(visit.zone));
            handler.PSendSysMessage(ModLocale::L(handler, "  {} en {}: objetivo {} bots{}{}."),
                                    human ? human->GetName() : "?", zoneName, visit.target,
                                    IsCity(visit.zone) ? ModLocale::L(handler, ", capital") : "",
                                    now >= visit.nextFillMs ? ModLocale::L(handler, ", repone ya") : "");
        }
    }

    void FillZone(Player* player, Visit& visit, PlayerSnapshot& snapshot,
                  uint32& teleportsLeft, uint64_t now)
    {
        uint32 const zoneId = visit.zone;

        AreaTableEntry const* zone = sAreaTableStore.LookupEntry(zoneId);
        if (!zone)
        {
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.topUpSecs);
            return;
        }

        bool const city = IsCity(zoneId);
        auto& index = city ? g_citySpots : g_spots;
        auto spotsIt = index.find(zoneId);
        if (spotsIt == index.end() || spotsIt->second.empty())
        {
            if (g_warnedZones.insert(zoneId).second)
                LOG_INFO("module", "[world-bots] La zona {} ({}) no tiene puntos de {}: no se puebla.",
                         zoneId, zone->area_name[sWorld->GetDefaultDbcLocale()], city ? "ciudad" : "caza");
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.topUpSecs);
            return;
        }

        // En una capital vale cualquier nivel: lo que se quiere es gente.
        // Aritmética pura en WorldBotsPolicy.h.
        uint32 const level = player->GetLevel();
        uint32 const maxLevel = StageCap();   // en una etapa inferior, ni la capital lleva bots por encima del tope
        auto const [minLevel, topLevel] = WorldBotsPolicy::ResolveZoneLevelRange(level, cfg.levelBelow, cfg.levelAbove, maxLevel, city);

        // Facción que admite la zona: 2 sólo Alianza, 4 sólo Horda, el resto ambas.
        TeamId const mine   = player->GetTeamId();
        TeamId const theirs = mine == TEAM_ALLIANCE ? TEAM_HORDE : TEAM_ALLIANCE;
        bool const contested = zone->team != 2 && zone->team != 4;
        TeamId const zoneTeam = zone->team == 2 ? TEAM_ALLIANCE : (zone->team == 4 ? TEAM_HORDE : TEAM_NEUTRAL);

        // Cuántos hay ya en la zona, de cada facción. se separan
        // tres medidas: población total (haveMine/haveTheirs, cualquier
        // estado — un bot ocupado también hace bulto, no hace falta que esté
        // libre), presencia viva en fase compatible con el jugador
        // (aliveMine/aliveTheirs: sin esto, un bot muerto o en otra fase
        // contaba como "zona llena" sin que el jugador viera a nadie) y
        // llegadas pendientes (bots ya enviados cuyo salto entre mapas
        // playerbots todavía no ha rematado).
        uint32 haveMine = 0, haveTheirs = 0;
        uint32 aliveMine = 0, aliveTheirs = 0;
        for (Player* bot : snapshot.bots)
        {
            WorldSession* session = bot ? bot->GetSession() : nullptr;
            if (!session || !session->IsHeadless() || !bot->IsInWorld())
                continue;

            if (bot->GetMapId() != player->GetMapId() || bot->GetZoneId() != zoneId)
                continue;

            if (bot->GetLevel() < minLevel || bot->GetLevel() > topLevel)
                continue;

            bool const mineTeam = bot->GetTeamId() == mine;
            (mineTeam ? haveMine : haveTheirs) += 1;
            if (bot->IsAlive() && bot->InSamePhase(player))
                (mineTeam ? aliveMine : aliveTheirs) += 1;
        }

        uint32 const have = haveMine + haveTheirs;   // población total: sólo para el registro
        uint32 const pendingMine = CountPendingArrivals(zoneId, player->GetMapId(), minLevel, topLevel, mine, now);
        uint32 const pendingTheirs = CountPendingArrivals(zoneId, player->GetMapId(), minLevel, topLevel, theirs, now);
        uint32 const coveredMine = aliveMine + pendingMine;
        uint32 const coveredTheirs = aliveTheirs + pendingTheirs;
        uint32 const covered = coveredMine + coveredTheirs;   // lo que de verdad cuenta para el objetivo

        if (covered >= visit.target)
        {
            visit.everCovered = true;
            visit.deficitSinceMs = 0;
            // A INFO a propósito: es la única forma de ver desde fuera cuántos
            // hay de verdad (¿Quién? sólo enseña a los de tu facción).
            WORLD_BOTS_ACTIVITY_LOG("[world-bots] {} ({}) llena para {}: {} bots de nivel {}-{} ({} {}, {} {}), objetivo {}.",
                     zone->area_name[sWorld->GetDefaultDbcLocale()], zoneId, player->GetName(), have, minLevel, topLevel,
                     haveMine, TeamName(mine), haveTheirs, TeamName(theirs), visit.target);
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.topUpSecs);
            return;
        }

        // Histéresis (M23): el objetivo ya se alcanzó alguna vez en esta
        // visita y ahora hay un hueco (una baja, alguien que se ha alejado de
        // fase) — se espera DeficitGraceSeconds por si se recompone solo,
        // para no acabar sobrepoblando cuando vuelva. El primer relleno de la
        // visita (todavía no hay nada que "recomponerse") no espera nada.
        if (visit.everCovered)
        {
            if (!visit.deficitSinceMs)
                visit.deficitSinceMs = now;
            if (now - visit.deficitSinceMs < TimeMs::SecsToMs(cfg.deficitGraceSecs))
            {
                visit.nextFillMs = now + TimeMs::SecsToMs(cfg.retrySecs);
                return;
            }
        }

        if (!teleportsLeft)
        {
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.retrySecs);
            return;
        }

        // Aritmética pura en WorldBotsPolicy.h.
        // std::lround no es constexpr: el redondeo se queda aquí, la cabecera
        // sólo recibe el resultado ya redondeado.
        uint32 const missing = WorldBotsPolicy::MissingZoneBots(visit.target, covered, cfg.maxPerPass, teleportsLeft);
        uint32 const desiredTheirs = static_cast<uint32>(std::lround(visit.target * cfg.oppositeShare));
        auto const [wantMine, wantTheirs] = WorldBotsPolicy::ResolveZoneFactionSplit(
            zoneTeam == mine, zoneTeam == theirs, contested, missing, desiredTheirs, coveredTheirs);

        // Puntos de caza a más de MinDistance del jugador. Si la zona es tan
        // pequeña que no hay ninguno, vale el mínimo que impone playerbots (150).
        auto pickSpots = [&](float minDist)
        {
            std::vector<Spot> out;
            float const minDistSq = minDist * minDist;
            for (Spot const& spot : spotsIt->second)
            {
                if (spot.loc.GetMapId() != player->GetMapId())
                    continue;
                bool nearHuman = false;
                for (Player* human : snapshot.humans)
                    if (human->GetMapId() == spot.loc.GetMapId()
                        && human->GetExactDist2dSq(spot.loc.GetPositionX(), spot.loc.GetPositionY()) < minDistSq)
                    {
                        nearHuman = true;
                        break;
                    }
                if (!nearHuman)
                    out.push_back(spot);
            }
            return out;
        };

        std::vector<Spot> spots = pickSpots(city ? cfg.cityMinDistance : cfg.minDistance);
        if (spots.empty())
            spots = pickSpots(cfg.nearbyRadius);
        if (spots.empty())
        {
            WORLD_BOTS_ACTIVITY_LOG("[world-bots] Todos los puntos de caza de {} ({}) estan a menos de 150 yardas de {}: "
                                    "no se suelta a nadie.",
                     zone->area_name[sWorld->GetDefaultDbcLocale()], zoneId, player->GetName());
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.topUpSecs);
            return;
        }

        // Si hay puntos del nivel del jugador, mejor esos: un bot de nivel 30
        // soltado entre bichos de nivel 10 se aburre. (En ciudad no aplica.)
        if (!city)
        {
            std::vector<Spot> levelled;
            for (Spot const& spot : spots)
                if (static_cast<uint32>(spot.level) + 2 >= minLevel && spot.level <= topLevel + 2)
                    levelled.push_back(spot);
            if (!levelled.empty())
                spots.swap(levelled);
        }

        uint32 moved = 0;
        uint32 woken = 0;

        // el orden de los puntos se baraja UNA VEZ para toda la pasada
        // (las dos llamadas a bring, no una por bot); cada bot arranca en un
        // tramo distinto vía el cursor persistente de la zona.
        std::vector<uint32> order(spots.size());
        std::iota(order.begin(), order.end(), 0u);
        Acore::Containers::RandomShuffle(order);
        uint32 const attempts = std::min<uint32>(static_cast<uint32>(order.size()), cfg.teleportMaxAttempts);

        auto bring = [&](TeamId team, uint32 wanted)
        {
            if (!wanted)
                return;

            wanted = std::min(wanted, teleportsLeft);
            std::vector<Player*> chosen = CollectBots(wanted, minLevel, topLevel, team, zoneId, snapshot);
            uint32 movedHere = 0;
            for (Player* bot : chosen)
            {
                uint32 const start = NextSpotCursor(zoneId, static_cast<uint32>(order.size()), attempts);
                bool farTeleport = false;
                if (!TeleportBot(bot, spots, order, start, attempts, city, &farTeleport))
                {
                    LOG_DEBUG("module", "[world-bots] {} no se ha podido teletransportar (alguien lo ve, o sin suelo).",
                              bot->GetName());
                    continue;
                }

                ++movedHere;
                --teleportsLeft;
                // un salto entre mapas no se ve en el recuento de la
                // zona destino hasta que playerbots lo remata; se cuenta como
                // "en camino" mientras tanto para no pedir de más.
                if (farTeleport)
                    RecordPendingArrival(bot->GetGUID(), player->GetMapId(), zoneId, bot->GetLevel(), team, now);
                LOG_DEBUG("module", "[world-bots] {} ({}, {}) viaja a {} para acompanar a {}.",
                          bot->GetName(), TeamName(team), bot->GetLevel(),
                          zone->area_name[sWorld->GetDefaultDbcLocale()], player->GetName());
            }
            moved += movedHere;

            if (movedHere < wanted)
                woken += WakeBots(wanted - movedHere, minLevel, topLevel, team, snapshot, teleportsLeft);
        };

        bring(mine, wantMine);
        bring(theirs, wantTheirs);

        if (!moved && !woken)
        {
            WORLD_BOTS_ACTIVITY_LOG("[world-bots] Sin bots libres de nivel {}-{} para {} ({}): tiene {} de {} (vivos en tu fase) y nadie que traer.",
                     minLevel, topLevel, zone->area_name[sWorld->GetDefaultDbcLocale()], zoneId, covered, visit.target);
            visit.nextFillMs = now + TimeMs::SecsToMs(cfg.retrySecs);
            return;
        }

        WORLD_BOTS_ACTIVITY_LOG("[world-bots] {} bots a {} ({}{}) con {}: {}/{} de nivel {}-{} (poblacion total {} {} y {} {}){}.",
                 moved, zone->area_name[sWorld->GetDefaultDbcLocale()], zoneId, city ? ", ciudad" : "", player->GetName(),
                 covered + moved, visit.target, minLevel, topLevel,
                 haveMine, TeamName(mine), haveTheirs, TeamName(theirs),
                 woken ? ", y " + std::to_string(woken) + " despertados" : std::string());

        ++g_statFills;
        g_statBotsMoved += moved;
        g_statBotsWoken += woken;

        if (cfg.announce && moved)
            ChatHandler(player->GetSession()).PSendSysMessage(ModLocale::L(player, "Han llegado {} aventureros a la zona."), moved);

        // Mientras falte gente se insiste pronto (los despertados tardan unos
        // segundos en entrar); con la zona llena, se repone cada minuto.
        visit.nextFillMs = now + ((covered + moved < visit.target) ? TimeMs::SecsToMs(cfg.retrySecs) : TimeMs::SecsToMs(cfg.topUpSecs));
    }
};

// ─────────────────────────────────────────────────────────────────────────────
//  El aviso de cambio de zona (hilo del mapa: sólo apunta, no toca nada)
// ─────────────────────────────────────────────────────────────────────────────
class mod_world_bots_player : public PlayerScript
{
public:
    mod_world_bots_player() : PlayerScript("mod_world_bots_player", { PLAYERHOOK_ON_UPDATE_ZONE, PLAYERHOOK_ON_LOGOUT }) { }

    // Cierra la antigüedad de la sesión (M08): la siguiente de este GUID
    // espera BotMinWorldSeconds aunque reutilice la dirección de memoria.
    void OnPlayerLogout(Player* player) override
    {
        if (player)
            BotWorldAge::Forget(player->GetGUID().GetCounter());
    }

    void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/, uint32 /*newArea*/) override
    {
        if (!cfg.enabled || !IsHuman(player))
            return;

        std::lock_guard<std::mutex> lock(g_pendingLock);
        g_pending.insert(player->GetGUID());
    }
};

// ─────────────────────────────────────────────────────────────────────────────
//  .wbots (GM):
//    etapa  — etapa activa, tope de nivel y mapas (síncrono)
//    estado — etapa + contadores desde el arranque + objetivo por zona (encolado)
//    aqui   — fuerza el relleno de la zona del GM ahora (encolado)
//  .bots estado — diagnóstico transversal del coordinador de población
// ─────────────────────────────────────────────────────────────────────────────
class mod_world_bots_command : public CommandScript
{
public:
    mod_world_bots_command() : CommandScript("mod_world_bots_command") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        static Acore::ChatCommands::ChatCommandTable wbotsTable =
        {
            { "etapa",      HandleStage,     SEC_GAMEMASTER, Acore::ChatCommands::Console::Yes },
            { "estado",     HandleStatus,    SEC_GAMEMASTER, Acore::ChatCommands::Console::Yes },
            { "aqui",       HandleHere,      SEC_GAMEMASTER, Acore::ChatCommands::Console::No  },
            { "samaritano", HandleSamaritan, SEC_PLAYER,     Acore::ChatCommands::Console::No  },
            { "",           HandleStatus,    SEC_GAMEMASTER, Acore::ChatCommands::Console::Yes },
        };
        static Acore::ChatCommands::ChatCommandTable botsTable =
        {
            { "estado", HandlePopulationStatus, SEC_GAMEMASTER, Acore::ChatCommands::Console::Yes },
        };
        static Acore::ChatCommands::ChatCommandTable commandTable =
        {
            { "wbots", wbotsTable },
            { "bots",  botsTable },
        };
        return commandTable;
    }

    static bool HandleStage(ChatHandler* handler)
    {
        handler->PSendSysMessage(ModLocale::L(handler, "[world-bots] {}."), StageStatus(handler));
        return true;
    }

    static bool HandleStatus(ChatHandler* handler)
    {
        Player* gm = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!gm)
        {
            // Desde la consola no hay sesión a la que responder por el hilo del
            // mundo: se da al menos la etapa, que es síncrona y segura.
            handler->PSendSysMessage(ModLocale::L(handler, "[world-bots] {}."), StageStatus(handler));
            handler->SendSysMessage(ModLocale::L(handler, "[world-bots] El detalle por zona necesita un personaje en el juego."));
            return true;
        }
        PushWbCmd(gm->GetGUID(), WB_CMD_STATUS);
        return true;
    }

    static bool HandleHere(ChatHandler* handler)
    {
        Player* gm = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!gm)
        {
            handler->SendSysMessage(ModLocale::L(handler, "Este comando necesita un personaje en el juego."));
            return true;
        }
        if (!cfg.enabled)
        {
            handler->SendSysMessage(ModLocale::L(handler, "mod-world-bots esta desactivado."));
            return true;
        }
        PushWbCmd(gm->GetGUID(), WB_CMD_HERE);
        return true;
    }

    static bool HandleSamaritan(ChatHandler* handler, Optional<std::string> arg)
    {
        Player* p = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!p)
        {
            handler->SendSysMessage(ModLocale::L(handler, "Este comando necesita un personaje en el juego."));
            return true;
        }
        std::string v = arg ? *arg : std::string();
        for (char& ch : v)
            ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
        if (v == "off" || v == "no")
            PushWbCmd(p->GetGUID(), WB_CMD_SAMARITAN_OFF);
        else if (v.empty() || v == "on" || v == "si")
            PushWbCmd(p->GetGUID(), WB_CMD_SAMARITAN_ON);
        else
            handler->SendSysMessage(ModLocale::L(handler, "Uso: .wbots samaritano on|off"));
        return true;
    }

    static bool HandlePopulationStatus(ChatHandler* handler)
    {
        uint64 const now = TimeMs::NowMs();
        BotPopulationCoordinator::Diagnostics const population =
            BotPopulationCoordinator::GetDiagnostics(now);
        BotClaims::Diagnostics const claims = BotClaims::GetDiagnostics();
        uint32 const pendingTotal = static_cast<uint32>(population.pending.size());
        uint32 const globalAvailable = population.settings.globalCap > population.onlineTotal + pendingTotal
            ? population.settings.globalCap - population.onlineTotal - pendingTotal : 0;
        uint32 const pendingAvailable = !population.settings.maxPendingTotal
            ? globalAvailable
            : (population.settings.maxPendingTotal > pendingTotal
                ? population.settings.maxPendingTotal - pendingTotal : 0);

        handler->PSendSysMessage(
            ModLocale::L(handler, "[bots] Global: {} online + {} pendientes / {} max; capacidad global ahora: {} (foto de hace {} s)."),
            population.onlineTotal, pendingTotal, population.settings.globalCap,
            std::min(globalAvailable, pendingAvailable), population.dataAgeMs / 1000);
        handler->PSendSysMessage(
            ModLocale::L(handler, "[bots] Presupuesto pendiente: {}/{} total, Alianza {}/{}, Horda {}/{} (0 = sin limite intermedio)."),
            pendingTotal, population.settings.maxPendingTotal,
            population.pendingByFaction[0], population.settings.maxPendingPerFaction,
            population.pendingByFaction[1], population.settings.maxPendingPerFaction);

        handler->SendSysMessage(ModLocale::L(handler, "[bots] Online por faccion y tramo:"));
        handler->PSendSysMessage(ModLocale::L(handler, "  Alianza: {}; Horda: {}."),
            population.onlineByFaction[0], population.onlineByFaction[1]);
        if (population.onlineByRange.empty())
            handler->SendSysMessage(ModLocale::L(handler, "  Tramos: ninguno."));
        else
            for (auto const& [range, count] : population.onlineByRange)
                handler->PSendSysMessage(ModLocale::L(handler, "  Nivel {}-{}: {} online."), range.first, range.second, count);

        handler->SendSysMessage(ModLocale::L(handler, "[bots] Pendientes por modulo:"));
        if (population.pendingByModule.empty())
            handler->SendSysMessage(ModLocale::L(handler, "  Ninguno."));
        else
            for (auto const& [module, count] : population.pendingByModule)
                handler->PSendSysMessage(ModLocale::L(handler, "  {}: {}."), module, count);

        handler->PSendSysMessage(ModLocale::L(handler, "[bots] Pendientes por faccion/tramo (limite por tramo: {}):"),
            population.settings.maxPendingPerRange);
        if (population.pending.empty())
            handler->SendSysMessage(ModLocale::L(handler, "  Ninguno."));
        else
            for (auto const& [range, count] : population.pendingByRange)
            {
                uint32 alliance = 0;
                uint32 horde = 0;
                for (BotPopulationCoordinator::Pending const& pending : population.pending)
                {
                    if (pending.minLevel != range.first || pending.maxLevel != range.second)
                        continue;
                    if (pending.faction == BotPopulationCoordinator::Faction::Alliance)
                        ++alliance;
                    else
                        ++horde;
                }
                handler->PSendSysMessage(ModLocale::L(handler, "  Nivel {}-{}: Alianza {}/{}, Horda {}/{} ({} total)."),
                    range.first, range.second,
                    alliance, population.settings.maxPendingPerRange,
                    horde, population.settings.maxPendingPerRange, count);
            }

        handler->PSendSysMessage(ModLocale::L(handler, "[bots] Claims: {} totales; {} bots de hermandad preferentes."),
            claims.totalClaims, claims.homeGuildBots);
        if (claims.claimsByOwner.empty())
            handler->SendSysMessage(ModLocale::L(handler, "  Claims por modulo: ninguno."));
        else
            for (auto const& [owner, count] : claims.claimsByOwner)
                handler->PSendSysMessage(ModLocale::L(handler, "  Claim {}: {}."), owner, count);

        // Cola compartida de reequipado (M12): estado de cada trabajo.
        BotGear::Stats const gear = BotGear::GetStats();
        handler->PSendSysMessage(ModLocale::L(handler, "[bots] Reequipado: {} en cola ({} en recuperacion); hechos {}, sin cambios {}, "
            "cancelados {}, aplazados {}, caducados {}, fallos {}, recuperados {}, abandonados {}, sin sitio {}."),
            gear.queued, gear.recovering, gear.completed, gear.skipped, gear.cancelled, gear.deferred,
            gear.expired, gear.failed, gear.recovered, gear.abandoned, gear.dropped);

        handler->SendSysMessage(ModLocale::L(handler, "[bots] Ultimos rechazos (mas reciente primero):"));
        if (population.recentRejections.empty())
            handler->SendSysMessage(ModLocale::L(handler, "  Ninguno."));
        else
        {
            uint32 shown = 0;
            for (auto it = population.recentRejections.rbegin();
                 it != population.recentRejections.rend() && shown < 5; ++it, ++shown)
            {
                handler->PSendSysMessage(ModLocale::L(handler, "  hace {} s: {} / {} / {} / nivel {}-{}."),
                    SecondsAgo(now, it->atMs), it->module,
                    ModLocale::L(handler, BotPopulationCoordinator::ReasonName(it->reason)), ModLocale::L(handler, PopulationFactionName(it->faction)),
                    it->minLevel, it->maxLevel);
            }
        }
        return true;
    }
};

void AddSC_mod_world_bots()
{
    ModLocale::Register(WorldBotsLocale::kEntries);
    new mod_world_bots_world();
    new mod_world_bots_player();
    new mod_world_bots_command();
}
