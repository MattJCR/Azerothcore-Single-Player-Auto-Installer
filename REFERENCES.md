# Referencias

Todo lo que se consulta pero no se ejecuta: **cómo funciona hoy** cada cosa que
este servidor añade por su cuenta, los datos estáticos con los que se mide o se
revisa, y las tablas de consulta rápida.

- Qué es el proyecto y su estado: `README.md`
- Instalar, configurar y operar: `INSTALL_ES.md`
- Lo que se hizo, con fecha: `CHANGELOG.md`

Lo verificado aquí lo está contra el código de las versiones fijadas en
`versions.lock`. Lo que no está verificado, no está.

---

## Índice

**Lo propio, y por qué está hecho así**

1. [La regla de oro](#la-regla-de-oro) · [Rangos de identificadores propios](#rangos-de-identificadores-propios)
2. [Resumen de todo lo propio](#resumen-de-todo-lo-propio)
3. Módulos propios: [queue-bots](#mod-queue-bots) · [world-bots](#mod-world-bots) · [quest-mates](#mod-quest-mates) · [cabeceras compartidas](#las-cabeceras-compartidas-botclaimsh-y-botgearh) · [party-here](#mod-party-here) · [home-guild](#mod-home-guild) · [update-notice](#mod-update-notice-y-toolsrevisar-actualizacionessh) · [server-help](#mod-server-help-y-el-addon-serverhelp) · [adaptive-ai](#mod-adaptive-ai-bots-que-aprenden) · [standby](#mod-standby-modo-en-espera)
4. [La carpeta `cliente/`](#la-carpeta-cliente) · [Bots en español](#bots-en-español) · [NPC de servicio](#los-npc-de-servicio) · [ARAC](#razas-y-clases-arac) · [Textos en español](#textos-en-español) · [Recompensas por nivel](#recompensas-por-nivel)
5. Parches sobre terceros: [dungeon-master](#mod-dungeon-master-la-columna-id1) · [challenge-modes](#mod-challenge-modes-el-hook-que-cambió-de-firma) · [congrats-on-level](#mod-congrats-on-level-recompensas-en-cualquier-nivel) · [random-enchants](#mod-random-enchants-encantamientos-a-tu-nivel)
6. [Aviso de claves no declaradas](#aviso-de-claves-no-declaradas) · [Espejos](#espejos-con-versionslock) · [Herramientas](#herramientas-de-operación) · [Parche de cliente ARAC](#parche-de-cliente-arac) · [Comprobar que todo está aplicado](#cómo-comprobar-que-todo-está-aplicado)

**Datos de consulta**

7. [Comandos](#comandos)
8. [Ubicaciones de los NPC de servicio](#ubicaciones-de-los-npc-de-servicio)
9. [Emparejamientos PvP de referencia](#emparejamientos-pvp-de-referencia)
10. [La ayuda en juego por dentro](#la-ayuda-en-juego-por-dentro)
11. [Ficheros de configuración y logs](#ficheros-de-configuración-y-logs)

**Guías de trabajo y componentes**

12. [Escribir un módulo propio](#escribir-un-módulo-propio-reglas) · [Escribir un parche](#escribir-un-parche-sobre-código-de-terceros) · [Crear un objeto propio](#crear-un-objeto-que-no-existe-en-335a) · [Parches de addons](#parches-de-addons-de-cliente-patches-cliente)
13. [Profesiones (SP01)](#experiencia-por-profesiones-sp01) · [Sede de hermandad (SP02)](#sede-de-hermandad-sp02) · [mod-treasure (SP03)](#mod-treasure-tesoros-itinerantes-sp03) · [Botín de misión en grupo (SP04)](#botín-blanco-de-misión-en-grupo-sp04) · [mod-arac-trainer-audit](#mod-arac-trainer-audit-auditoría-de-entrenadores)
14. [El verificador sintético](#el-verificador-sintético-toolscliente-sintetico) · [Edición pública: snapshots, addons y recursos del cliente](#edición-pública-snapshots-addons-y-recursos-del-cliente-pub04-y-pub04-i) · [Procedencia de mapas e iconos](#procedencia-de-mapas-e-iconos) · [Cliente web del navegador](#cliente-web-del-navegador-web-client)

---

## Rangos de identificadores propios

Para no chocar nunca con el core ni con los módulos:

| Qué | Rango | Dónde |
|---|---|---|
| GUID de los NPC de servicio | `MAX(guid)+1000` en adelante, calculado en cada instalación | `lib/utils.sh` → `spawn_service_npcs` |
| GUID de los personajes del bot de subastas | desde `AH_BOT_GUID_BASE` (9000001) | `config.sh` |
| Objetos propios en `item_template` | desde **600000** (el `MAX(entry)` del core es 57576) | `patches/custom-items/` (un `.sql` por objeto) — hoy sólo `600000` (ganzúa). Guía: «Crear un objeto que no existe en 3.3.5a» (REFERENCES.md) |
| Textos traducidos | los identificadores que ya usa cada módulo, sólo con `locale` añadido | `patches/locales-es/` |

---

## La regla de oro

Antes de escribir nada propio se intenta, por este orden:

1. **¿Lo resuelve una opción del `.conf` del módulo?** Entonces va a `config.sh`
   y se acabó.
2. **¿Se resuelve metiendo filas en la base de datos?** Entonces es un `.sql` en
   `patches/`, siempre idempotente (borra sus filas antes de insertarlas).
3. **¿Hay que cambiar código ajeno?** Entonces es un `.patch` en `patches/`, que
   es lo más frágil: cuando el upstream toca esas líneas, deja de aplicar.
4. **¿Es una funcionalidad nueva?** Entonces es un **módulo propio** en
   `modules/`, que no toca código ajeno y por tanto ninguna actualización puede
   romperlo.

Por eso lo de abajo está ordenado de menos a más frágil.

## Resumen de todo lo propio

| Qué | Tipo | Dónde | Se aplica en | Fragilidad |
|---|---|---|---|---|
| [mod-queue-bots](#mod-queue-bots) | Módulo propio | `modules/mod-queue-bots/` | Fase 3 (se copia) y 4 (se compila) | Baja |
| [mod-world-bots](#mod-world-bots) | Módulo propio | `modules/mod-world-bots/` | Fase 3 (se copia) y 4 (se compila) | Baja |
| [mod-quest-mates](#mod-quest-mates) | Módulo propio | `modules/mod-quest-mates/` | Fase 3 (se copia) y 4 (se compila) | Baja |
| [Cabeceras compartidas](#las-cabeceras-compartidas-botclaimsh-y-botgearh) | Cabeceras `.h` | `modules/shared/` | Fase 3 (se copian a cada módulo propio) | Baja |
| [mod-party-here](#mod-party-here) | Módulo propio | `modules/mod-party-here/` | Fase 3 (se copia) y 4 (se compila) | Baja |
| [mod-home-guild](#mod-home-guild) | Módulo propio | `modules/mod-home-guild/` | Fase 3 (se copia) y 4 (se compila) | Baja |
| [mod-update-notice](#mod-update-notice-y-toolsrevisar-actualizacionessh) | Módulo propio + script | `modules/mod-update-notice/`, `tools/` | Fases 3 y 4; el script, a mano y la tarea semanal | Baja |
| [mod-server-help y el addon ServerHelp](#mod-server-help-y-el-addon-serverhelp) | Módulo propio + addon | `modules/mod-server-help/`, `cliente/Interface/AddOns/ServerHelp/` | Fases 3, 4 y 5; el addon, en cada PC | Baja |
| [mod-adaptive-ai](#mod-adaptive-ai-bots-que-aprenden) | Módulo propio archivado | `modules/mod-adaptive-ai/` | No se aplica (`INSTALL_MOD_ADAPTIVE_AI=false`) | Baja |
| [mod-standby](#mod-standby-modo-en-espera) | Módulo propio + unidades systemd | `modules/mod-standby/`, fases 6-7 | Fase 3 y 4; systemd en 6-7 (sólo con `WORLDSERVER_STANDBY`) | Baja |
| [Carpeta `cliente/`](#la-carpeta-cliente) | Ficheros del jugador | `cliente/` | A mano o `instalar-cliente.ps1`, en cada PC | Baja |
| [Bots en español](#bots-en-español) | SQL | `patches/locales-es-playerbots/` | Fases 5 y 8 | Baja |
| [NPC de servicio](#los-npc-de-servicio) | Lógica del instalador | `lib/utils.sh` | Fases 5 y 8 | Baja |
| [Razas y clases (ARAC)](#razas-y-clases-arac) | SQL | `patches/arac/` | Fases 5 y 8 | Baja |
| [Textos en español](#textos-en-español) | SQL | `patches/locales-es/` | Fases 5 y 8 | Baja |
| [Recompensas por nivel](#recompensas-por-nivel) | SQL | `congrats_on_level_rewards.sql` | Fase 5 (y 8) | Baja |
| [Aviso de claves no declaradas](#aviso-de-claves-no-declaradas) | Lógica del instalador | `lib/utils.sh` → `set_conf_value` | Fase 5 | Baja |
| [Espejos con `versions.lock`](#espejos-con-versionslock) | Lógica del instalador | `lib/mirrors.sh` | `--mirror` y fase 3 | Baja |
| [Herramientas de operación](#herramientas-de-operación) | Scripts | `tools/` | A mano | Baja |
| [Parche de cliente ARAC](#parche-de-cliente-arac) | MPQ | `cliente/Data/<idioma>/patch-<idioma>-4.MPQ` | A mano o `instalar-cliente.ps1`, en cada PC | Baja |
| [mod-dungeon-master: `id1`](#mod-dungeon-master-la-columna-id1) | Parche por `sed` | `lib/utils.sh` | Fase 3 y tras cada actualización | Media |
| [mod-challenge-modes: hook](#mod-challenge-modes-el-hook-que-cambió-de-firma) | `.patch` | `patches/mod-challenge-modes/` | Fase 3 y tras cada actualización | **Alta** |
| [mod-congrats-on-level](#mod-congrats-on-level-recompensas-en-cualquier-nivel) | `.patch` | `patches/mod-congrats-on-level/` | Fase 3 y tras cada actualización | **Alta** |
| [mod-random-enchants](#mod-random-enchants-encantamientos-a-tu-nivel) | `.patch` | `patches/mod-random-enchants/` | Fase 3 y tras cada actualización | **Alta** |

---

## mod-queue-bots

**Carpeta:** `modules/mod-queue-bots/` · **Se activa con:** `INSTALL_MOD_QUEUE_BOTS`

### El problema

Jugando solo, **ninguna cola del juego llega a saltar**. Ni un campo de batalla,
ni una arena, ni el buscador de mazmorras. Te apuntas y no pasa nada nunca.

Uno pensaría que para eso están los bots, y el servidor tiene 1500. Pero el
sistema que trae `mod-playerbots` para apuntarlos va a ciegas: intenta llenar
**una batalla por cada tramo de nivel de cada campo de batalla** —veinticuatro a
la vez— repartiendo entre todas ellas los bots que hay conectados. Con 250 bots
no llena ninguna. Y sobre todo: **no sabe en qué cola estás tú**.

### Qué hace

Mira en qué cola te has puesto y mete en **esa** los bots que le faltan:

| Cola | Qué hace | Cómo llegas a la partida |
|---|---|---|
| Refriega 1c1 | Un rival | La arena te teletransporta |
| Campo de batalla | Rellena **los dos bandos** hasta el mínimo que pida | El CdG te teletransporta |
| Arena | Tantos contrincantes como pida el tipo | La arena te teletransporta |
| Mazmorra (5) | Sólo **los roles que falten**: tanque, sanador o daño | El buscador teletransporta a todos |
| Banda | Te forma el grupo metiendo bots hasta el tamaño del raid | **Andando**: el tablón de bandas no teletransporta a nadie |

Tres detalles que importan:

- **Los bots salen del tramo de nivel de tu cola, no del nivel 80.** Para
  mazmorras y bandas el tramo lo da la propia ficha de la mazmorra; para campos
  de batalla, el tramo del mapa. Un personaje nuevo puede jugar contenido de
  grupo a cualquier nivel.
- **La banda del buscador prefiere tu nivel exacto, pero puede bajar hasta
  `QueueBots.RaidLevelBelow` niveles si hace falta** (5 por defecto; M48,
  25/09/2026). `mod-world-bots` reparte la población entre muchos niveles, y
  una banda en un nivel poco poblado se quedaba en 0-2 compañeros para
  siempre: `CollectBots` sólo miraba tu nivel exacto y `WakeBots` sólo
  despertaba dormidos cuando esa pasada no encontraba NINGUNO. Ahora, si
  faltan bots tras agotar los ya conectados de tu nivel exacto, se amplía la
  búsqueda hacia abajo (nunca por encima de ti) y se despierta lo que falte en
  **cada** pasada corta, no sólo con la banda a cero. Además, el núcleo limpia
  `LFG_STATE_RAIDBROWSER` en cuanto tienes grupo (no distingue "sigo
  buscando" de "ya tengo compañeros y quiero más"): sin un atajo aparte que seguía
  rellenando mientras hubiera una banda en marcha, esto cortaba `FillRaid`
  para siempre en cuanto entraban los dos o tres primeros bots. Verificado en
  vivo: banda de 10 completa (2 tanques, 3 sanadores) en Zul'Gurub (nivel 56).
- **El rol se deduce de la especialización del bot** (la rama de talentos donde
  tiene más puntos), así que a la mazmorra va un tanque de verdad.
- **Cada participante ocupa una sola plaza** (M15, 24/09/2026:
  `QueueBotsPolicy::PlanDungeonRoles`). El jugador y sus compañeros cuentan
  con los roles marcados en el buscador (un bot de party-here sin roles, con su
  especialidad) y los bots ya encolados con el rol con el que entraron. Si el
  jugador marca varios roles, se le asigna el que mejor cubren los bots libres
  (a igualdad, tanque y luego sanador): con tanque+daño y bots de sobra se
  buscan cuatro, no tres. Un bot encolado que ya no tiene plaza (el jugador
  cambió de roles) sale del buscador en vez de contarse como daño. Si los
  roles del propio grupo no caben (dos que sólo tanquean), no se encola a
  nadie y se avisa una vez.
- **Si la IA del bot ignora la invitación**, tras 40 segundos el módulo le manda
  el mismo "entrar en la batalla" que mandaría su cliente, y al entrar le
  reconstruye las estrategias para que pelee. Los 40 segundos son para darle
  antes su oportunidad: la invitación dura 60.
- **Los bots de la banda se traen a tu lado** (desde 02/09/2026). Visto en el
  juego: a veces no venían solos —otro continente, o su IA no arrancaba el
  "seguir"—. Ahora, 8 segundos después de unirse (más 0-3 de azar, para que no
  lleguen en bloque) el bot se teletransporta junto a ti, con las mismas
  precauciones que el `summon` de playerbots: sitio con línea de visión, nunca
  con tú o él en combate, revivido si estaba muerto, la mascota detrás. Si ya
  está a menos de 40 yardas no se le toca; si en un minuto no se ha podido, se
  deja donde está y lo dice el log. Se hace desde `OnUpdate` del mundo, no
  desde el hook del bot (hilos de mapas: «Escribir un módulo propio: reglas» (REFERENCES.md), regla 5).
  `QUEUE_BOTS_RAID_SUMMON_DELAY`, 0 para apagarlo.
- **Activa `mod-dungeon-clear` solo** (desde 02/09/2026). Ese módulo sólo
  arranca con `.dc on` desde dentro y borra el estado al salir, así que no hay
  forma de dejarlo "siempre activo" desde su config. Cuando todo el grupo del
  buscador está en la misma instancia, hay un tanque bot y tú no eres el
  tanque, `mod-queue-bots` manda `.dc on` por tu sesión, tres intentos cada
  15 s (es lo que hace la propia batería de pruebas del módulo). Si tú eres el
  tanque, lo dice en el log y no lo intenta. `QUEUE_BOTS_DUNGEON_CLEAR_AUTO`.
- **Apagado de verdad** (M06, 24/09/2026). Con `QueueBots.Enable = 0` (también
  en caliente con `.reload config`) el módulo vacía rellenos y convocatorias,
  descarta los canjes de jefe pendientes y retira de la cola de `BotGear` los
  reequipados que pidió él; no vuelve a mandar `.dc on`, `.tokenturnin redeem`
  ni a traer bots. Sigue atendiendo la cola **compartida** de reequipado (son
  trabajos de otros módulos, con su propio contexto) y las acciones del panel
  dirigidas a él vuelven como fallidas («queue-bots está desactivado»).

### Por qué es un módulo y no un parche

No toca ni una línea de `mod-1v1-arena` ni de `mod-playerbots`. Del primero copia
dos constantes (las que ese módulo registra en el núcleo al arrancar).

Del segundo usa **tres llamadas**, y todas entre guardas de compilación:

| Llamada | Para qué | Por qué no hay alternativa |
|---|---|---|
| `ResetStrategies()` | Que el bot pelee al entrar a la partida | playerbots configura el combate al *aceptar* la invitación, cuando el bot aún no está dentro; la comprobación que lo arregla luego vive en una estrategia que ese bot no tiene |
| `AddPlayerBot()` | Encender un bot dormido | No hay forma desde el núcleo de meter un bot en el mundo |
| `LogoutPlayerBot()` | Hacer sitio mandando a dormir a uno ocioso | Ídem |

Si playerbots no está, esas tres no se compilan y el resto funciona igual. Si
cambian, **falla la compilación con un error claro** en vez de dejar bots
plantados sin avisar.

> Se intentó primero por la vía sin código: el comando `.bot add`. No sirve, por
> dos motivos que sólo se ven leyendo el módulo — sólo acepta bots
> **desconectados** (`PlayerbotMgr.cpp:687`), y un jugador **no puede tomar el
> mando de un bot aleatorio** salvo que sea de su cuenta o de su hermandad
> (`PlayerbotMgr.cpp:113`).

### Despertar bots dormidos

El servidor tiene unos 1500 personajes de bot pero mantiene **despiertos** muchos
menos, y sube ese número muy despacio (cambia su objetivo cada 30-120 minutos).
Así que puede haber cincuenta bots de tu nivel… dormidos, mientras tu cola se
queda a medias.

Por eso el módulo los enciende él: cuando faltan bots para tu cola, busca en la
tabla de personajes los que estén **desconectados, de tu tramo de nivel y de la
facción que hace falta**, y los mete en el mundo. Si el mundo ya está en su tope,
antes manda a dormir a otros tantos que estén ociosos y fuera de tu tramo —
nunca a uno que esté en el grupo de alguien, en una partida o en una mazmorra.

Tardan unos segundos en aparecer, así que hay un margen de 15 segundos entre
tandas para no pedir de más mientras entran. Se apaga con `QueueBots.WakeBots`.

### Lo que queda pendiente

Dos cosas, detalladas en `CHANGELOG.md` (sección 9.7): **la arena 2c2/3c3 no
se ha probado todavía** (hay que encolarse en grupo), y **las bandas de 40 tardan
en llenarse** porque piden 5 tanques y 12 sanadores de nivel 80 exacto y el pozo
de nivel máximo aún es pequeño.

### Lo que hay que saber si algo no funciona

- Necesita que **existan** bots de tu nivel y facción, aunque estén dormidos. Los
  bots reciben su nivel la primera vez que se despiertan, así que el pozo de un
  nivel concreto crece según van rotando. Ver la sección de población.
- Escribe una línea en el log del worldserver por cada bot que mete, con el
  tramo de nivel y cuántos faltan. Se lee sin adjuntarse a la consola:
  `screen -S worldserver -X hardcopy -h /tmp/ws.txt && grep queue-bots /tmp/ws.txt`
- Cada cola se puede apagar por separado en `mod_queue_bots.conf`.

### La población de bots, que va de la mano

Tres valores de `config.sh` que sin esto no dan una cola llena:

| Ajuste | Valor | Por qué |
|---|---|---|
| `BOTS_MAX` | 250 | No es sólo consumo: es cuántos bots **llegan a existir**. El módulo despierta hasta este tope y les tira el dado del nivel la primera vez que entran; el resto se queda en la reserva a nivel 1 |
| `BOTS_MAX_LEVEL_CHANCE` | 0.2 | El nivel máximo es el único tramo de **un solo nivel**: con reparto uniforme le tocaban 8 bots de 653 (había 3, ninguno de la Horda) y a nivel 80 no salía nada |
| `BOTS_AUTO_JOIN_BG` | false | El auto-apuntado a ciegas de playerbots, que ahora estorba |

Y `BOTS_SYNC_LEVEL_WITH_PLAYERS=false`, que además evita un desastre: ese ajuste
usa "el nivel del jugador más alto conectado", y **sin nadie conectado vale 1**,
así que cualquier re-aleatorizado con el servidor vacío dejaría a todos los bots
a nivel 1.

---

## mod-world-bots

**Carpeta:** `modules/mod-world-bots/` · **Se activa con:** `INSTALL_MOD_WORLD_BOTS`
· **Escrito el 02/09/2026, pendiente de verificar en el juego.**

### El problema

Las colas ya se llenan, pero **el mundo por el que andas está vacío**. Con 250
bots repartidos entre 80 niveles y unas 90 combinaciones de zona y facción, a
cada zona le tocan uno o dos, y no necesariamente de tu nivel.

Se miró en el código de playerbots qué hace con la posición del jugador, y la
respuesta es: casi nada. `SelectRandomGrindPos` mueve a cada bot **dentro de su
propia zona**; `RandomTeleportForLevel` lo cambia de zona **al azar** cada 1-5
horas; y `BotActiveAloneForceWhenInZone` despierta a los que ya estaban en tu
zona, pero no trae a ninguno. LevelBrackets arregla la mitad "nivel" —hay bots
de tu nivel en el mundo— pero no la mitad "zona": están en otra parte.

### Qué hace

Al entrar en una zona cuenta los bots de tu tramo de nivel ([nivel−5, nivel+3])
que hay en ella y, si faltan hasta el objetivo (15-30 al azar para la zona completa; en las capitales
30-50), los trae:

1. **Primero bots libres de otras zonas**, teletransportados a puntos de caza de
   tu zona a más de 250 yardas de ti. Nunca los ves aparecer.
2. **Si no hay bastantes despiertos, enciende dormidos** de la reserva, del tramo
   y la facción que toca, y la pasada siguiente los recoloca.

De cinco en cinco cada 15 segundos, para que no sea una oleada. Mientras sigues
en la zona repone cada minuto lo que se haya ido o muerto. Al salir no hace
nada: se quedan.

Detalles que importan:

- **Los puntos de caza** son celdas de 50 yardas con al menos dos bichos normales
  con botín, sin diálogo, de reaparición corta y fuera de las facciones de
  ciudad — el mismo filtro con el que playerbots construye su propia caché de
  destinos. Se indexan por zona **una vez al arrancar** (línea `[world-bots] N
  puntos de caza en M zonas` en `Server.log`). Si hay puntos del nivel del
  jugador se prefieren esos.
- **La facción la decide la zona** (`AreaTable.team`: 2 Alianza, 4 Horda, 0/6
  ambas). En Elwynn todos son humanos aunque seas de la Horda; en una zona
  contestada, un 35 % de la facción contraria.
- **Nunca se toca** a un bot en grupo, en combate, en mazmorra, en cola, volando,
  muerto, a medio teletransporte, ni en la zona de otro jugador. Si alguien lo
  está viendo, tampoco (la misma comprobación de 150 yardas que hace playerbots).
- **Toda salida sin rellenar deja el motivo en el log**: zona sin puntos de
  caza, puntos demasiado cerca, sin bots libres del tramo.

### Dónde se hace el trabajo, y por qué ahí

`OnPlayerUpdateZone` corre en el **hilo del mapa** del jugador. Teletransportar
desde ahí a un bot que está siendo actualizado por otro de los cuatro hilos de
mapas sería una carrera. Así que ese hook sólo apunta "este jugador ha cambiado
de zona" (con su candado), y el trabajo lo hace `WorldScript::OnUpdate`, que
corre en el hilo principal cuando ningún mapa se está actualizando. Está como
regla en «Escribir un módulo propio: reglas» (REFERENCES.md).

### Por qué es un módulo y no un parche

No toca ni una línea de `mod-playerbots`. De él usa cinco cosas, todas entre
guardas de compilación:

| Llamada | Para qué |
|---|---|
| `IsRandomBot()` | No mover nunca un bot que no sea aleatorio (el alt de alguien) |
| `AddPlayerBot()` / `LogoutPlayerBot()` | Encender dormidos y hacer sitio, como en queue-bots |
| `Reset(true)` y `HasPlayerNearby()` | Las dos llamadas con las que playerbots teletransporta a un bot |

La función de teletransporte de playerbots (`RandomTeleport`) **es privada**,
así que el módulo repite su secuencia: comprobar agua y altura, limpiar el
movimiento, reiniciar la IA, quitar las auras que se pierden al viajar, y
`TeleportTo`. Si cambia algo de eso en playerbots, falla la compilación.

### Lo que va con él en `config.sh`

| Ajuste | Antes → ahora | Por qué |
|---|---|---|
| `BOTS_MIN` / `BOTS_MAX` | 200/250 → **400/500** | Que haya de dónde sacar bots de tu tramo sin vaciar el resto del mundo |
| `BOT_ACTIVE_ALONE` | (dist) → expuesto, 10 | Sólo el 10 % simula lejos de ti: contiene el coste de 500 bots |
| `VISIBILITY_DISTANCE_CONTINENTS` | (dist, 100) → **160** | Verlos antes de llegar a ellos |

Y dos decisiones tomadas el 01/09: **respawn dinámico no** (se quiere respawn
vanilla; si molesta la competencia por los bichos, `Respawn.DynamicRateCreature`)
y **saludos de bots apagados**.

### Lo que hay que saber si algo no funciona

- `grep -a 'world-bots' ~/azerothcore/env/dist/bin/Server.log | tail`: cada
  pasada que trae bots deja una línea con cuántos, a qué zona y qué tramo; cada
  pasada que no puede, el motivo.
- Con 500 bots, **vigilar la memoria** del worldserver tras el primer reinicio
  (`ps -o rss -C worldserver`). Con 153 eran 3,7 GB.
- Si los bots llegan pero no se mueven, es cosa de playerbots, no de esto:
  comprobar `BotActiveAloneForceWhenInZone = 1` y los mmaps (0 errores en el log).

### Las capitales (02/09/2026)

Las ciudades no tienen puntos de caza, así que al principio no se poblaban. Se
les hizo su propio índice: delante de cada NPC de servicio (posadero, banquero,
subastador, vendedor, entrenador, maestro de vuelo) de las diez ciudades
(`WorldBots.CityZones`), un paso por delante y mirando hacia él, como hace
playerbots con sus posaderos. En la ciudad se quieren 30-50 bots **de cualquier
nivel** y la distancia mínima baja a 150, porque las ciudades son pequeñas.

Y un detalle que salió al escribirlo: un bot teletransportado seguía con el
estado de rol que traía —"ir a cazar a tal sitio"— y se marchaba. Ahora al
llegar se le cambia el estado (`rpgInfo`, miembro público de `PlayerbotAI`):
en el campo, "cazar alrededor de donde llego"; en la ciudad, "decidir de nuevo",
que en una ciudad es pasear entre los NPC. Es lo que hace el comando `rpg
status` de playerbots.

---

### La guerra de mundo (02/09/2026, noche)

**Fichero:** `src/mod_world_bots_pvp.cpp` · **Tabla:** `world_bots_pvp_hotspot` en `acore_world`
(`data/sql/db-world/base/`, fase 5) · **Claves:** `WorldBots.Pvp.*` · **GM:** `.wpvp`

Es un fork propio de `mod-playerbot-world-pvp` (TopHatMan, commit `ed7962cc`,
agosto de 2026). Se conserva lo que valía: los 23 puntos calientes con sus
coordenadas (Costasur, Molino Tarren, El Cruce, Astranaar, Punta del Refugio,
Caemartillo… y dos de duelos a las puertas de Ventormenta y Orgrimmar), el
ciclo del evento (reunión, avance, fin, vuelta a casa), las estrategias de
playerbots que activa (`+pvp,+boost,+dps debuff,-passive,-stay`) y los duelos
con el hechizo 7266. Se tiró lo que lo hacía peligroso aquí:

| El original | Aquí |
|---|---|
| Elegía bots mirando sólo la cuenta: sacaba a tu tanque de la mazmorra, o a un bot de tu banda o de una cola | Sólo bots **libres** con el criterio de world-bots, ni reservados por otro módulo, ni de tu hermandad |
| No restauraba las estrategias al acabar: el bot seguía en modo JcJ | `ResetStrategies` y vuelta a donde estaba (esperando a que acabe su combate, un minuto como mucho) |
| "Respuesta reactiva": 40 bots enemigos de nivel 60 contra cualquier banda de 20 con marca JcJ, que en un reino JcJ es cualquier banda del buscador al aire libre | No existe |
| Eventos en cualquier sitio, los vea alguien o no | Por defecto sólo en zonas con un jugador (`OnlyWithPlayerInZone`), y con aviso: "La Horda marcha sobre Costasur" |
| Puntos de aparición fijos | Nunca a menos de 160 yardas de un humano: el punto se aleja de él hasta las 200 |
| Cinco comandos de gestión en inglés y un fichero de log aparte | `.wpvp estado / lista / iniciar <nombre> / parar [id] / recargar`, y las líneas `[world-bots] Guerra #N` en `Server.log` |

Cómo va: cada minuto se tira el dado (1,5 %); si sale, se elige por peso un
punto caliente sin enfriar de una zona con jugador. Los atacantes van al punto
de reunión y los defensores al objetivo, con la marca JcJ y las estrategias
de guerra; a los 15 segundos los atacantes avanzan andando y la estrategia
`pvp` de playerbots hace el resto en cuanto ve enemigos a menos de 100 yardas.
Entre 5 y 18 minutos después, cada bot recupera sus estrategias y vuelve a su
sitio. Los puntos de duelo (misma facción) forman parejas y uno reta al otro.

Los puntos se afinan en la tabla: `enabled`, `weight` y `label` se conservan
al reaplicar el SQL; el resto vuelve a la semilla. Los de nivel 45+ vienen
apagados hasta que haya población.

---

### Presencia viva, llegadas pendientes y coste por pasada (25/09/2026)

`FillZone` ya no compara el objetivo de una zona contra la población total:
separa **población** (todo bot de tu mapa/zona/tramo, cualquier estado — para
el registro), **presencia viva en fase compatible** (`IsAlive()` y
`InSamePhase(jugador)`: un bot muerto o en otra fase no cuenta como "hay
gente") y **llegadas pendientes** (`g_pendingArrivals`: un bot que acaba de
recibir un salto entre mapas cuenta como "en camino" hasta
`WorldBots.ArrivalGraceSeconds`, porque `HandleTeleportAck` lo remata un tick
después de `TeleportTo`, no en el acto). El objetivo se compara contra
viva+pendiente. Además, una vez alcanzado el objetivo de una visita, un hueco
no dispara una reposición al primer recuento: se espera
`WorldBots.DeficitGraceSeconds` (20 s) por si el propio playerbots resucita
solo, para no sobrepoblar la zona cuando vuelva (`.wbots aqui` sigue forzando
el relleno sin esperar nada).

`TeleportBot` ya no copia y baraja el vector de puntos de caza en cada
llamada: `FillZone` baraja una permutación de índices una sola vez por pasada
y cada bot prueba como mucho `WorldBots.TeleportMaxAttempts` (12) puntos
empezando en un desplazamiento distinto de un cursor persistente por zona
(diversidad sin rebarajar); lo que no cabe en el presupuesto de una pasada lo
recoge la siguiente en vez de perderse o de recorrer siempre todos los
puntos.

**El modo "buen samaritano"** (`WorldBots.Samaritan`, experimental, apagado
por defecto) tenía un fallo que le impedía enviar ayuda nunca: adquiría la
reserva del bot y la revalidaba con la misma función que rechaza cualquier
reserva, incluida la propia. Arreglado separando "elegible" (sin mirar
reservas) de "libre" (elegible y sin reservar); de paso, el candidato tiene
que ser de tu facción y compartir fase contigo, y `.wbots samaritano off` (o
apagar el modo en caliente) retira a los ayudantes activos al momento en vez
de esperar a que acabe su combate.

---

## mod-quest-mates

**Carpeta:** `modules/mod-quest-mates/` · **Se activa con:** `INSTALL_MOD_QUEST_MATES`
· **Escrito el 02/09/2026, pendiente de verificar en el juego.**

### El problema

Con mod-world-bots tu zona tiene gente, pero cada uno va a lo suyo. En un
servidor de verdad, cuando aceptas "mata diez jabalíes" hay otros tres matando
los mismos jabalíes, y eso es lo que hace que una zona parezca habitada y no
decorada.

### Qué hace

Al aceptar una misión, elige dos o tres bots aleatorios libres de tu zona, de tu
facción y de tu tramo de nivel que **puedan cogerla** —lo decide el núcleo con
los mismos criterios que a ti: nivel, raza, clase, requisitos previos, hueco en
el diario—, se la mete en el diario y le dice a su estrategia de rol que se
ponga con ella. A partir de ahí su IA va a los objetivos, mata, recoge y
entrega por su cuenta (`AutoDoQuests`). Los mismos bots repiten contigo durante
media hora mientras sigan en la zona: son tus compañeros, no desconocidos.

**Recuerdo y vínculo son cosas distintas** (M01, 24/09/2026). El recuerdo
(«este bot ya fue compañero tuyo») dura `RememberMinutes`; la reserva en
`BotClaims` la sostiene sólo el **vínculo activo**, mientras el bot lleve
misiones inyectadas. `BotClaims` sólo sabe que el bot es de «quest-mates», no
de qué jugador, así que el módulo guarda aparte `bot → (jugador, generación)`:
únicamente el dueño vigente de ese vínculo suelta la reserva, abandona
misiones en el diario del bot o lo reutiliza. Un recuerdo pasivo no puede
liberar ni reutilizar un bot que otro jugador haya reclutado después.

**Pantallas de carga** (M18). Durante un portal o un cambio de continente el
jugador (o el bot) sigue conectado pero fuera del mundo: `FindPlayer` devuelve
nulo y antes eso soltaba todo. Ahora se distinguen tres estados: sin sesión,
saliendo o con **otra** sesión → se suelta; sesión viva fuera del mundo → se
espera `TransitionGraceSeconds` (60) sin tocar a nadie; de vuelta → sigue. El
login de un humano también limpia lo de su sesión anterior, aunque el logout
no se hubiera visto.

Fuera quedan las misiones de mazmorra, banda, escolta, JcJ, heroicas, diarias,
repetibles, de evento y las automáticas.

### Por qué es un módulo y no un parche

Del núcleo: `OnPlayerQuestAccept` (que sólo apunta la petición: hilo de mapa),
`CanTakeQuest`/`CanAddQuest`/`AddQuestAndCheckCompletion` con dador nulo (el
núcleo lo admite). De playerbots, entre guardas: `IsRandomBot` y
`rpgInfo.ChangeToDoQuest`, que es exactamente lo que hace su comando `rpg
status do quest <id>`.

### Si algo no funciona

`grep -a 'quest-mates' Server.log`: cada misión aceptada deja quién la coge o
por qué nadie pudo (nadie de tu nivel en la zona, o nadie cumple los requisitos
de la misión).

---

## Las cabeceras compartidas: `BotClaims.h` y `BotGear.h`

**Dónde:** `modules/shared/` · **Se copian a** `src/` de cada módulo propio en la fase 3
· **Escritas el 02/09/2026 (noche)**

Hay cinco módulos propios moviendo bots. Casi todo lo que hace "ocupado" a un
bot se ve en el núcleo (grupo, cola, mazmorra, combate), pero hay huecos: un
bot elegido para un grupo que todavía no está dentro, uno al que se está
trayendo, o los de tu hermandad, que nadie debe mandar a dormir. `BotClaims.h`
es un mapa guid → módulo, en funciones *inline* con estáticas locales: el
enlazador funde todas las copias en una sola instancia para todo el
worldserver, sin que ningún módulo dependa de otro. Por eso cada módulo lleva
**su copia** en `src/` (los módulos no comparten *include path*) y las copias
tienen que ser byte a byte idénticas: hay una sola fuente en
`modules/shared/` y `install_own_modules()` las monta en un directorio
temporal antes de comparar y copiar. **Nunca se editan las copias.**

`BotGear.h` es el tope de equipo. individual-progression te tiene en Núcleo de
Magma y los bots de nivel 60 llegaban con épicos de Naxxramas: el sorteo de
equipo de playerbots mira nivel y calidad, no fase. Al entrar un bot en tu
grupo se calcula un nivel de objeto objetivo (tu media + 6, sin pasar del tope
de tu fase: MC 78, BWL 83, AQ40 88, Naxx40 92, Kara 125, SSC/TK 141, Hyjal/BT
156, Sunwell 164, Naxx 224, Ulduar 245, ToC 258, ICC 290, la tabla que
documenta el propio `playerbots.conf.dist`) y, si el bot se sale de ±8, se le
vacía y se le reequipa a ese nivel con `PlayerbotFactory::DestroyEquippedGear`
y `AutoGear`, que es lo que hace su comando `autogear reset N`. Uno por tick:
reequipar cuesta decenas de milisegundos. La fase se lee sin cabeceras de IP:
la guarda como misiones ocultas recompensadas (66001-66018).

**Cada trabajo lleva su contexto** (M02, 24/09/2026). Un reequipado puede
esperar (combate, muerte, cola) y mientras la relación que lo pidió puede
acabar. Quien encola pasa una prioridad y un revalidador que `ProcessOne`
consulta **al consumir**: `Apply` con el objetivo recalculado en ese momento,
`Defer` (el amo está en una pantalla de carga: vuelve al final de la cola) o
`Cancel` (el bot ya no está en ese grupo, esa party o esa guerra; el dueño se
ha ido; `GearMode = 0` tras una recarga). `BotGear::InGroupOf(humano,
&cfg.gear)` es el revalidador estándar de grupo; party-here le añade «sigue
siendo compañero de esta party», world-bots «la guerra sigue y el bot en ella»
y home-guild «sigue en la hermandad, sin reservar y sin grupo». Sustitución:
un trabajo pendiente del mismo bot lo reemplaza uno nuevo de prioridad igual
o mayor (fondo < grupo < evento), así que el repaso de la hermandad no pisa a
un grupo y una petición nueva nunca se pierde por deduplicación.

**Presupuesto, fallos y recuperación** (M12, 24/09/2026). El «uno cada
200 ms» se gasta al **intentar**, no al terminar bien: si la fábrica falla,
el siguiente módulo que llama a `ProcessOne` en el mismo tick no lanza otro
reequipado detrás. Un trabajo aplazado (bot en combate, muerto o viajando;
amo cargando) vuelve a la cola con un segundo de margen y caduca a los
5 minutos. Si la fábrica lanza una excepción **después** de vaciar el equipo,
el trabajo pasa a *recuperación*: se reintenta hasta tres veces (a los 30 y a
los 60 s), no lo cancela el fin de la relación (se repone al último objetivo),
sobrevive a que su módulo se apague y a que otro trabajo del mismo bot lo
sustituya, y espera hasta 30 minutos si el bot sigue ocupado. Agotado, queda
un `LOG_ERROR` («puede haberse quedado sin equipo»). `.bots estado` muestra la
línea `[bots] Reequipado:` con la cola, los que están en recuperación y los
contadores desde el arranque (hechos, sin cambios, cancelados, aplazados,
caducados, fallos, recuperados, abandonados, sin sitio).

Lo que hay que saber: `LimitGearExpansion` ya viene a 1 en el dist (ni TBC
antes de 61 ni WotLK antes de 71), así que esto sólo corrige dentro de cada
expansión. Y el equipo dura hasta que playerbots re-aleatorice al bot (cada
una o dos semanas): entonces se vuelve a topar al siguiente grupo.

---

## mod-party-here

**Carpeta:** `modules/mod-party-here/` · **Se activa con:** `INSTALL_MOD_PARTY_HERE`
· **Escrito el 02/09/2026 (noche), propiedad corregida el 08/09/2026,
pendiente de verificar en el juego.**

### El problema

`mod-queue-bots` rellena **colas**. Una misión de grupo ("Hogger", cualquier
"(Grupo)" del diario) o una mazmorra a la que quieres entrar andando con la
misión en el diario no tienen cola: te quedas solo delante de la puerta.
`mod-quest-mates` da compañeros que hacen tu misión en paralelo, sin agruparse.

### Qué hace

| Comando | Qué |
|---|---|
| `.grupo` / `.grupo mazmorra` | Grupo de cinco: tanque, sanador y daño, menos lo que tú seas |
| `.grupo 2` | Dos bots |
| `.grupo banda [10\|25\|40]` | Una banda; sin número, según tu dificultad de banda. Composición 2/3, 3/6 o 5/12 tanques/sanadores, como queue-bots |
| `.grupo fuera` | Los bots que dio el módulo se van y se cancela todo lo que los traería de vuelta (petición pendiente, reposición, recomposición tras relogin) |
| `.grupo fuera <nombre>` | Se va ése y el grupo pasa a ser uno más pequeño: no se repone ni vuelve ese bot (`PartyHere.DismissExcludeMinutes`, 10) |
| `.grupo cambia <nombre>` | Se va ése y se busca otro para su plaza, sin bajar el tamaño |
| `.grupo estado` | Quién está y por qué vino, quién se va al terminar el combate y la petición pendiente |

Y en automático: al aceptar una misión con "jugadores sugeridos" invita a los
que falten (tope 2), que se van solos pasados 120 s desde que ya no hacen
falta: misión entregada o abandonada, o cambio de zona fuera de instancias.

Los bots son de tu facción y de tu tramo (hasta 3 por debajo, ninguno por
encima: en un grupo de cinco uno más alto te roba la experiencia), los de tu
hermandad primero, sin repetir clase mientras haya. Se teletransportan a tu
lado a los 3 s con la secuencia del `summon` de playerbots, y se les topa el
equipo (`BotGear.h`). En cuanto pisáis una instancia el grupo queda a cargo de
queue-bots: dungeon-clear si hay tanque bot, tokens tras cada jefe.

El hueco donde se coloca al compañero se busca con línea de visión alrededor
tuyo, probando dos radios (el de `PartyHere.SummonPlaceRadius` y uno más
cercano) con el doble de puntos que antes; si ninguno vale, se usa tu
posición EXACTA en vez de seguir esperando (M49, 25/09/2026: en terreno
recortado —esquinas, interiores, cornisas— podía fallar toda la ventana de
`SummonGiveUpSeconds` antes de rendirse, y el rearme por cambio de mapa/
distancia repetía el ciclo dos o tres veces, más de 90 s en total).

`PartyHere.PersistMinutes` recompone **cualquier** grupo manual tras un
relogin (`wantedSize > 1`), no sólo los de más de 5 (M50, 25/09/2026): antes
`.grupo`/`.grupo mazmorra` (el tamaño más habitual, 5) nunca sobrevivía a una
desconexión mientras que uno de 6 sí, sin ninguna razón aparte de cómo
estaba escrito. `.grupo fuera` sigue cancelando el recuerdo de verdad.

### Por qué es un módulo y no un parche

Grupo con la API del núcleo (`Group::Create`, `AddMember`, `RemoveMember`),
igual que hace queue-bots con las bandas del tablón. De playerbots, entre
guardas: `IsTank`/`IsHeal` por especialización, `IsRandomBot`,
`AddPlayerBot`/`LogoutPlayerBot` (despertar dormidos) y, al meter al bot, lo
que hace su propia `AcceptInvitationAction` al aceptar una invitación:
`SetMaster`, `ResetStrategies`, `ChangeStrategy("+follow,-lfg,-bg")` y
`Reset`. Sin eso el bot está en el grupo pero su IA no sabe que tiene amo.

Al desconectarte, los companions salen del `Group` y se les quita el amo
antes de soltar la reserva (playerbots no disuelve el grupo del amo por su
cuenta: se quedarían atrapados con `GetGroup() != nullptr` para siempre).
Un cambio de mapa largo (mazmorra, piedra de hogar, vuelo entre continentes)
no deshace la party: hay una ventana de gracia `PartyHere.LoadGraceSeconds`
(defecto 30) mientras la sesión sigue viva pero el jugador no está "en el
mundo".

### Peticiones pendientes y despedidas (M16 y M17, 24/09/2026)

Pedir compañeros (`.grupo`, `.grupo banda`, una misión de grupo, la
recomposición tras un relogin o `.grupo cambia`) abre una **petición** por
jugador (`g_demands`): tamaño, motivo, misiones que la sostienen, sesión con
la que se pidió y caducidad. Si no hay bots bastantes, se reintenta cada
`PendingRetrySeconds` (5) —despertando dormidos como mucho cada
`PendingWakeSeconds` (45)— hasta completarse o cumplir
`PendingTimeoutSeconds` (180). Cada intento revalida antes de actuar: la
sesión (otra sesión o un logout la cancelan), la pantalla de carga (espera),
el grupo (estar en el de otro, o haber dejado el que ya había, la cancelan),
colas y campos de batalla, y en las automáticas que la misión siga en el
diario. El jugador ve un único «Preparando compañeros…», los «Se unen a tu
grupo» de cada llegada y «Tu grupo está completo»; la cancelación siempre dice
por qué.

En un grupo manual las plazas de tanque y sanador sin candidato se guardan
`RoleWaitSeconds` (45) esperando a que llegue ese rol; mientras tanto sólo se
despiertan clases capaces de él (`BotWake` con filtro de clase). Pasada la
espera, con `RoleRespec`, un bot libre del tramo de una clase capaz cambia su
rama de talentos a la del rol con la plantilla de playerbots
(`InitTalentsBySpecNo`, lo que hace `talents spec`; se prefiere uno de daño).
Si ni así hay nadie, se cubren con quien haya. Al terminar la petición
(completa, o caducada con compañeros dentro) se mira la composición REAL del
grupo y, si falta tanque o sanador, el jugador recibe un aviso explícito
(«No hay tanque libre de nivel X-Y: tu grupo se completa sin él…», M26); no se
avisa por cada intento, porque un rol puede llegar después. El druida no
cuenta como tanque: `IsTank` sólo lo reconoce en forma de oso. Los
automáticos no esperan ni cambian talentos.

`RoleLevelAbove` (5 en el perfil, 0 de fábrica): pasada la espera de rol, si
dentro del tramo no hay tanque o sanador libre se admite uno de hasta ese
número de niveles por encima (primero uno de verdad, luego el cambio de
especialización), y los dormidos que se despiertan buscando ese rol se
buscan en el mismo tramo ampliado. Sólo afecta a tanque y sanador de grupos
manuales; el resto sigue con «ninguno por encima». Motivo: en un tramo de
cuatro niveles suele haber uno o ningún guerrero o paladín (UPD-I).

Límite de población (visto en la VM el 24/09/2026): `IsRandomBot(guid)` de
playerbots sólo es cierto para los bots de su conjunto activo
(`playerbots_random_bots`, evento `add`; 300 en la VM y todos conectados con
un jugador dentro). El resto de personajes de las cuentas de bots no los puede
despertar ningún módulo. Con la VM recién reinstalada, en Alianza 22-25 había
tres o cuatro bots activos: el grupo sale con los que haya y el aviso lo dice. La reposición de `Tick` no actúa
mientras hay una petición en curso.

Echar a un compañero es una decisión del jugador y se distingue de las bajas
involuntarias: `.grupo fuera <nombre>` baja `wantedSize` (y la petición
pendiente) en uno, `.grupo fuera` los pone a cero y borra el recuerdo para el
relogin. Un bot en combate, viajando o en pantalla de carga queda con la
**despedida pendiente** (`Companion::dismissPending`): no se le trae ni se le
reequipa, `.grupo estado` lo muestra y `Tick` lo saca en cuanto termina.
Repetir la orden no vuelve a bajar el tamaño.

### Si algo no funciona

`grep -a 'party-here' Server.log`: cada bot que entra o sale deja una línea
con el motivo; si no hay bots libres lo dice y despierta dormidos. Los bots
en tu grupo no se ven afectados por world-bots ni quest-mates (excluyen a los
agrupados). Si los bots entran pero no te siguen, es la IA: `.grupo fuera` y
`.grupo` otra vez los reinicia.

---

## mod-home-guild

**Carpeta:** `modules/mod-home-guild/` · **Se activa con:** `INSTALL_MOD_HOME_GUILD`
· **Escrito el 02/09/2026 (noche), pendiente de verificar en el juego.**

### El problema

Cada grupo es de desconocidos. En un servidor de verdad tienes una hermandad
y con ella haces las bandas semana tras semana. Las hermandades de bots de
playerbots te invitan, pero no son tuyas ni se usan para nada.

### Qué hace

El módulo **no crea ni adopta hermandades**. Cuando fundas una mediante el flujo
normal del juego, `GuildScript::OnCreate` la marca en `mod_home_guild` con tu
personaje y cuenta (sólo si `HomeGuild.AutoAdopt = 1`, el defecto; con 0 se marca
a mano con `.hermandad activar`). Sólo tú, mientras sigas siendo su líder,
activas el cuidado. Una guild que ya existía, una donde sólo eres miembro o una
cuyo liderazgo cambió no se toca.

**Comandos** (`SEC_PLAYER`, sólo en el juego): `.hermandad estado` (roster y
conectados), `.hermandad activar` (marca tu hermandad como de casa),
`.hermandad desactivar` (expulsa a los bots sin disolver la hermandad).

**Reclamación por inactividad** (`HomeGuild.InactiveOwnerReclaimDays`, defecto
30): si el fundador lleva ese tiempo sin entrar y no está conectado, se expulsa
a sus bots de la hermandad y vuelven al pool. Corre en `OnStartup` y cada 6 h.
Sin esto, cada owner que abandona el servidor congelaba ~15 bots en una guild
difunta y el pool de bots libres se erosionaba.

La hermandad marcada se rellena con 15 bots de tu facción y tu tramo de nivel
(de 3 por debajo a 2 por encima), primero los que estén conectados y libres,
luego de la tabla de personajes. A partir de ahí:

- **Se conectan contigo**: cada 15 s se enciende a los que estén
  desconectados, de cinco en cinco, haciendo sitio con bots que no sean de
  ninguna hermandad de casa. Primero se descartan los que no pueden entrar
  (login ya reservado por otro módulo, nivel por encima de la etapa activa);
  los fijados van delante y el resto por turnos desde donde se quedó la pasada
  anterior; el lote cuenta logins aceptados, no candidatos mirados, y si no
  queda ninguno admisible no se desconecta a nadie (M11).
- **Nadie los manda a dormir**: queue-bots, world-bots y party-here lo
  consultan en `BotClaims.h`.
- **Van primero** cuando queue-bots o party-here forman un grupo.
- **Siguen tu nivel**: al que se queda más de 4 niveles por debajo se le sube
  con la fábrica de playerbots (nivel, talentos y equipo nuevos, como `rndbot
  init`), uno por pasada. Sólo si está libre según `BotEligibility` (sin
  combate, vuelo, teletransporte, grupo, cola de BG ni LFG), **nadie lo tiene
  reservado** en `BotClaims` (un bot de casa prestado a quest-mates o a una
  guerra no se toca) y lleva `ReLevelMinWorldSeconds` (60) conectado. El
  objetivo queda entre `nivel del dueño − ReLevelBehind` y el menor de tu
  nivel, la etapa de world-bots y el máximo del servidor: nunca baja (M04). La
  fábrica corre con una reserva `home-guild` puesta y se cronometra
  (`Tick lento: ReLevel (fabrica)` en `Server.log`).
- **Comentan en el chat de hermandad** (`GuildFeedback = 1` de playerbots).

### Por qué es un módulo y no un parche

`GuildScript::OnCreate` y `Guild::AddMember` son API del núcleo, y `AddMember`
funciona con el bot desconectado. La tabla `mod_home_guild` hace que la
propiedad sobreviva a reinicios sin deducirla del nombre ni del líder.
Playerbots colabora sin tocarlo: respeta la
hermandad de un bot que ya tiene una (`PlayerbotFactory::InitGuild`) y
`LevelBrackets.IgnoreGuildBotsWithRealPlayers = 1` (dist) deja en paz el nivel
de los bots de una hermandad liderada por un humano. Lo único que hace el
gestor es desconectarlos cuando caduca su turno, y aquí se vuelven a conectar.
El módulo no cambia `Playerbots.RandomBotInvitePlayer`.

Al primer arranque de la versión del 08/09, `CleanupLegacyAutoGuilds` disuelve
una sola vez las guilds automáticas antiguas que coincidan en nombre generado,
uno de los dos MOTD históricos y composición (bots y, como humanos, sólo la cuenta del líder). Usa
`Guild::Disband`, para limpiar correctamente miembros, banco y tablas del core.
Si sólo coincide una parte de la firma, no borra nada y deja un aviso en el log.

### Si algo no funciona

`grep -a 'home-guild' Server.log`. Si al fundarla no queda vinculada, comprueba
que existen las tablas `mod_home_guild*` en `acore_characters`. Si los bots no
se conectan, mira `HomeGuild.KeepOnline` y el tope de
`Playerbots.MaxRandomBots`. Para deshacerlo, disuelve la guild normalmente; el
hook borra su marca y no se creará otra por sí sola.

---

## mod-update-notice y `tools/revisar-actualizaciones.sh`

**Carpeta:** `modules/mod-update-notice/` · **Se activa con:** `INSTALL_MOD_UPDATE_NOTICE`
· **Escrito el 02/09/2026 (noche).**

La tarea semanal comprobaba si había versiones nuevas y mandaba un correo
dentro del juego, que hay que ir a leer al buzón. Ahora:

- `tools/revisar-actualizaciones.sh` enseña una tabla, repositorio a
  repositorio: commits nuevos, fecha de lo fijado, fecha de lo último. Con
  `--log nombre`, los commits y los ficheros tocados (para saber si un parche
  propio peligra). Sólo hace `git fetch`. Y escribe
  `env/dist/bin/updates-pending.txt`. Desde Windows,
  `tools/revisar-actualizaciones.ps1` (05/09/2026) sube el script a la VM y lo
  ejecuta por plink, con `-SoloNovedades`, `-SinFichero` y `-Log <repo>`.
- `lib/check-updates.sh` (la tarea semanal) escribe el mismo fichero.
- `mod-update-notice` lo lee cuando entra una cuenta con nivel de GM y se lo
  enseña como mensajes del sistema 8 s después de aparecer en el mundo, y con
  `.actualizaciones`. No habla con la red.

---

## mod-server-help y el addon ServerHelp

**Carpeta:** `modules/mod-server-help/` y `cliente/Interface/AddOns/ServerHelp/`
· **Se activa con:** `INSTALL_MOD_SERVER_HELP` · **Escrito el 02/09/2026.**
· **Investigación previa:** ["La ayuda en juego por dentro"](#la-ayuda-en-juego-por-dentro).

### El problema

El botón `?` de la barra abre "Solicitud de ayuda", cuya página inicial es
"Ayuda básica" (`KnowledgeBaseFrame`). En un servidor privado siempre dice "no
disponible", porque el cliente 3.3.5a la pide **por HTTP a los servidores de
soporte de Blizzard** (`support.wow-europe.com/kb/`, cadenas de `Wow.exe`); no
existe ningún opcode de juego para ella. Y el jugador no tiene forma de saber
qué comandos hay ni cuáles puede usar: `.grupo`, `.dc`, `.tokenturnin`,
`.transmog claim`, `.wpvp`...

### Qué hace

Convierte esa pestaña en la base de conocimiento del servidor: **todos los
comandos que tu cuenta puede usar** (del core y de cualquier módulo,
descubiertos solos en el árbol real de comandos), con su uso, descripción,
permiso, ejemplos y categoría, más artículos sobre cómo funciona el servidor.
Buscador, categoría y subcategoría, lista paginada, ficha con scroll y Volver,
mensajes de carga, sin resultados y error. Todo con los frames originales de
Blizzard: mismo aspecto, y los seis botones de ticket siguen donde estaban.

**Filtro de permisos en el servidor.** El módulo recorre el árbol con la
sesión real del jugador usando la API pública del core
(`GetAutoCompletionsFor` devuelve sólo los hijos visibles para esa sesión;
`SendCommandHelpFor`, capturado con un `ChatHandler` derivado, da la ayuda y
si el comando es ejecutable o sólo contenedor). El nivel exacto de cada
comando lo apunta el hook `OnBeforeIsInvokerVisible`, que el core llama con el
nombre completo y el `RequiredLevel`. Un jugador no recibe ni los nombres de
los comandos de GM; si le subes el nivel y vuelve a entrar, aparecen solos.
El módulo no ejecuta comandos en nombre de nadie ni reimplementa reglas: al
ejecutar, el core vuelve a comprobar el permiso como siempre.

**Transporte.** El addon manda `SendAddonMessage("AzerothCore",
"i<contador>ayuda ...", "WHISPER", yo)`. El core ya procesa ese prefijo
(`AddonChannelCommandHandler`, `Chat.cpp`): ejecuta el comando con la sesión
real y devuelve cada línea de la respuesta como susurro de addon (`a` ack,
`m` línea, `o` ok, `f` fallo). El módulo sólo registra un comando `.ayuda`,
que además funciona tecleado en el chat con salida legible. Cada mensaje va
limitado a 255 bytes por el core, así que el índice se manda ligero (rutas,
títulos, categorías, nivel: ~40 bytes por entrada) y la ficha bajo demanda.
Revisado que ni playerbots (ignora `LANG_ADDON` en sus susurros) ni
dungeon-clear (sólo prefijo `DC`, evaluado después) se cruzan con él.

**Comandos:** `.ayuda` · `.ayuda buscar <texto>` · `.ayuda comando <ruta>` ·
`.ayuda articulo <id>` · `.ayuda indice` · `.ayuda recargar` (administrador;
también funcionan desde la consola del worldserver, con la visibilidad de
consola). En el cliente, `/ayudaservidor` abre la pestaña.

### Las tablas (`acore_world`, `data/sql/db-world/base/server_help.sql`)

| Tabla | Qué | Al reaplicar el SQL se conserva |
|---|---|---|
| `server_help_category` | Categorías (id, padre, nombre, `name_en`, `sort`, `min_security`, `enabled`). Semilla: las 15 pedidas; VIP viene desactivada | `sort`, `enabled` |
| `server_help_article` | Artículos libres o ligados a un comando (`command_path`: sólo se ven si se puede usar ese comando). `min_security`, `is_hot` | `sort`, `enabled` (ids 1-99 de semilla; los tuyos desde 100) |
| `server_help_command` | Ficha en español de un comando por ruta: título, descripción, sintaxis, ejemplos, keywords, categoría temática y `min_security` propio (`NULL` = heredar el de la categoría en consumidores externos) | `enabled` |
| `server_help_rule` | Prefijo de ruta → categoría, para los comandos sin ficha (`teleport` → Teletransportes; el prefijo más largo gana) | las de id ≥ 1000 (las de semilla se sustituyen) |

**Cómo añadir documentación:**

- **Un artículo**: `INSERT INTO server_help_article (id, category_id, title, body, keywords, min_security) VALUES (100, 6, 'Título', 'Texto con \n para saltos', 'palabras clave', 0);` y `.ayuda recargar` (o reinicio). Con `command_path = 'grupo banda'` sólo lo ve quien pueda usar `.grupo banda`.
- **La ficha de un comando** (propio o de cualquier módulo): fila en `server_help_command` con `command_path` sin punto (`'dc on'`). Lo que dejes vacío (`syntax`, `description`) se rellena con la ayuda del core (tabla `command`). `min_security` permite que el panel filtre el nivel real sin convertir la categoría temática en control de acceso; déjalo a `NULL` en una ficha antigua o personalizada si debe heredar el mínimo de su categoría.
- **Una categoría**: fila en `server_help_category` (padre 0 = raíz; con `parent_id` es subcategoría). Sólo se envían al cliente las que tienen algo visible.
- **Cambiar la categoría de una familia de comandos**: fila en `server_help_rule` con id ≥ 1000.

Cómo decide la categoría de un comando: ficha → regla de prefijo → categoría
por defecto de su nivel (`ServerHelp.DefaultCategory.*`). Si la categoría
elegida no es visible para el jugador (`min_security`), pasa al siguiente
paso: un jugador nunca ve el nombre de una categoría de GM por un comando suyo.

### Lo que hay que saber si algo no funciona

- La pestaña dice "El servidor no responde": el módulo no está compilado o
  `ServerHelp.Enable = 0`; con el GM, `.ayuda version` en el chat lo confirma.
- Sale un comando en una categoría rara: es la regla de prefijo o la ausencia
  de ficha; `SERVER_HELP_LOG_REQUESTS=true` apunta cada petición en `Server.log`.
- `Server.log` al arrancar: `[server-help] N categorias, M articulos, K fichas
  de comando, R reglas de categoria.`
- Los textos de la ayuda del core (`command.help`) están en inglés; las fichas
  de `server_help_command` los sustituyen en español comando a comando.
- Cada petición desde una cuenta con nivel de GM queda en el log de comandos
  del core (`LogCommandUsage`), como cualquier comando: ruido, no problema.

---

## La carpeta `cliente/`

**Dónde:** `cliente/` · **Detalle:** «El cliente» (INSTALL_ES.md, parte 5) · **Desde el 02/09/2026**

Todo lo que va en el PC del jugador, con la estructura de la carpeta del juego:
`Data/<idioma>/patch-<idioma>-4.MPQ` (objetos propios del servidor + razas y
clases ARAC), `Interface/AddOns/ServerHelp` (la ayuda del servidor) e
`Interface/AddOns/MultiBot` (el panel de mando de los bots que ya estaba en
el cliente de referencia, sin sus 27 MB de capturas),
más `manifest.tsv` (origen, destino, tipo, nota de cada elemento) e
`instalar-cliente.ps1`, que lo copia todo en Windows y escribe el realmlist.
El manifiesto es lo que leería un lanzador que descargase estos ficheros del
servidor al conectarse: le basta con servir la carpeta por HTTP.

---

## mod-adaptive-ai: bots que aprenden

**Carpeta:** `modules/mod-adaptive-ai/` · **Se activa con:** `INSTALL_MOD_ADAPTIVE_AI`
· **Diseño completo:** `CHANGELOG.md` anexo A1

**Estado:** archivado y desactivado desde el 06/09/2026. Esta sección conserva
la referencia técnica de un módulo que no se compila ni carga; no hay trabajo
previsto sobre él. Las tareas retiradas están en `CHANGELOG.md`.

### El problema

El PvP de los bots de playerbots es flojo y siempre igual: la misma rotación
de triggers y acciones, sin memoria de lo que funcionó. Un guerrero bot no
aprende a guardar el interrupt para el sheep ni un mago a echar la nova
cuando el guerrero llega.

### La solución

Una capa de decisión encima de la IA de playerbots que aprende. En cada
**punto de decisión** de un combate PvP (el enemigo empieza a castear, la
vida cruza un umbral, se libera un cooldown, cambia la distancia) el módulo
elige QUÉ debería hacer el bot (interrumpir, cargar, control, defensiva,
huir, o nada) y playerbots decide CÓMO (qué hechizo, rango, visión, cooldown,
GCD). Lo que pasa después puntúa la decisión: daño hecho y recibido,
interrupción lograda o desperdiciada, control hecho o sufrido, muerte, kill,
y al final victoria o derrota. Una tabla Q por (clase propia, clase enemiga,
estado, acción) va aprendiendo (Q-learning tabular, 864 estados; desde la
fase 1b: exploración dirigida con optimismo, paso decreciente, retorno de la
partida repartido a todas sus decisiones; ver abajo).

**Entrenamiento**: los bots luchan entre ellos en arenas instanciadas en
segundo plano (hasta 20 a la vez): el jugador ni las ve ni le afectan, y el
módulo cede los bots si hay un jugador en cola PvP. Modos: *entrenar* (los
dos aprenden), *contraste* (uno aprende, el otro es playerbots de serie: la
medida de si el sistema mejora), *mixto* (alterna) y *referencia* (los dos
de serie: la línea base viva, un 10 % de las partidas automáticas). Además
aprende de los combates reales de los bots contra jugadores o entre ellos.

**Candidata y validada**: se aprende siempre en la tabla *candidata*; los
bots que se cruzan con el jugador deciden con la última *validada* (o con el
peldaño que diga la escalera, ver abajo). El **examen** va por el reloj: cada
dos horas (01:15, 03:15, ...) las arenas dejan de entrenar y durante 45 minutos
(o hasta que las diez clases se puedan juzgar) juegan candidata contra validada
sin aprender, por parejas de clases. **El aprobado es por clase** y desde el
05/09/2026 con tres brazos por pareja: candidata-validada, validada-candidata y
validada-validada. La nota "con la candidata" de una clase sale de los dos
primeros y la nota "con la validada" sólo del tercero, así que las dos se miden
contra el mismo rival. Aprueba la clase cuya mejora supera
`max(MejoraPorClase, Z × error típico)` con al menos `PartidasPorClase` por lado
en los últimos `VentanaCiclos` exámenes, o que ya gana el 90 % sin empeorar; sus
filas pasan a una validada nueva (un mosaico de las clases aprobadas) y la
candidata sigue entrenando. Tras `CiclosMaximos` exámenes juzgados sin aprobar,
si no mejora, la clase recupera las filas de la validada, salvo que la validada
no tenga ninguna (entonces se queda con lo suyo). `.adaptive modelo usar N`
vuelve a una anterior. El detalle y el porqué de cada regla: `CHANGELOG.md`
05/09/2026 y anexo A1 §16.19-16.23.

**Por bot**: rating Elo (K 32, desde 1500) y bracket (Novato a Elite),
dificultad 1-6 (probabilidad de no reaccionar y de escoger la segunda mejor
acción: errores coherentes, solo en combates reales) y personalidad
(agresividad, riesgo, defensa, prioridad, movilidad) que sesga la elección.

### Fase 1b (03/09/2026): lo que enseñó la primera noche

Con 2460 partidas el adaptativo no era mejor que el de serie (guerrero
adaptativo 81 % contra referencia 81-87 %, mago adaptativo 20 % contra 13-19 %).
La causa estaba en la tabla: `none` (dejar hacer a playerbots) se llevaba el
85-92 % de las decisiones, porque siempre está disponible, ganaba los empates
y cobra todo lo que playerbots hace en su ventana; el resto de acciones apenas
se visitaba y la victoria o la derrota solo llegaba a la última decisión. El
detalle, con los números, en `CHANGELOG.md` anexo A1 §16.14. Lo que se cambió:

- **Exploración dirigida** (`AdaptiveAI.Exploracion.Bonus`): lo no probado en
  un estado vale el mejor Q del estado más el bonus; lo poco probado suma
  bonus/√visitas; los empates se deshacen al azar. Epsilon queda en 0,05.
- **Paso decreciente** (`AdaptiveAI.Alpha.Decreciente`): max(Alpha, 1/(visitas+1)).
- **Retorno de la partida** (`AdaptiveAI.Retorno.Peso`): al acabar, el retorno
  descontado de la partida entera se reparte a todas sus decisiones.
- **Interrupciones solo con el enemigo casteando** (anoche: 750 contrahechizos
  al aire por 6 buenos).
- **Recompensa de posición** (`AdaptiveAI.Recompensa.Distancia`): lanzadores
  lejos, cuerpo a cuerpo pegados.
- **Acción propia `kitear`** del mago: Nova de Escarcha si está pegado y
  alejarse hasta 20 yardas durante 3 s (el módulo mueve al bot con el
  `MotionMaster` del core; no se registra nada en playerbots). Al final del
  catálogo para no mover los índices ya aprendidos.
- **Medida por clase**: `.adaptive` enseña el contraste por clase del lado
  adaptativo y la referencia serie contra serie; la calibración anota el
  detalle por clase en la nota del modelo.

### Fases 2 a 6, primer corte (03/09/2026)

- **Las diez clases** tienen catálogo (`AdaptiveAI.Clases` limita cuáles
  deciden y entrenan; vacío = todas).
- **Arenas de equipo** 2c2, 3c3 y 5c5 con la misma mecánica que 1c1:
  composiciones en `AdaptiveAI.Arena.Pares` (`warrior+priest:mage+rogue`,
  `*+*+*:*+*+*`), tamaños automáticos en `AdaptiveAI.Arena.Tipos`, grupo del
  core por lado, contexto de equipo en el estado (aliado bajo, me enfocan,
  sanador enemigo), acciones `asistir`, `foco sanador` y `proteger`,
  recompensas de kill de equipo y muerte de aliado, Elo por equipos.
- **Campos de batalla** (`.adaptive bg lanzar WS 10`, o automáticos con
  `AdaptiveAI.Bg.*`): Alianza contra Horda en una instancia propia; los
  objetivos los juega playerbots, el módulo decide el combate y cobra
  banderas, bases y torres desde la puntuación del campo.
- **Exportar e importar**: `.adaptive exportar|importar`,
  `tools/exportar-adaptive.sh`, y la fase 5 importa el fichero del
  repositorio (pregunta, sí por defecto; `ADAPTIVE_IMPORTAR_ENTRENADO`).
- Detalle y diferencias con el diseño en `CHANGELOG.md` anexo A1 §16.15.

### Loadout: doble spec y equipo por propósito (03/09/2026)

Todos los bots aleatorios de nivel 40 o más llevan dos specs, como un jugador
con doble especialización: la 0 es su build PvE (la premade que playerbots le
dio, completa) y la 1 la PvP de la clase (`AdaptiveAI.Arena.Specs`). Al entrar
en arena, campo de batalla o duelo el módulo activa la PvP y regenera el
equipo con resiliencia según el rating del bot (Furioso, Implacable,
Colérico); al entrar en una mazmorra o banda sin jugador, la PvE con el
equipo del contenido; con un jugador en el grupo, la spec PvE y el equipo lo
topa mod-queue-bots a la fase de ese jugador. Claves `AdaptiveAI.Loadout.*`;
detalle en `CHANGELOG.md` anexo A1 §16.17.

### La escalera de peldaños: qué modelo sale al mundo (04/09/2026)

Un **peldaño** es un modelo concreto midiéndose, por clase, contra playerbots
de serie. La serie es el peldaño 0 y el ancla: **rating 1500 por definición**.
Como las parejas son de clases distintas, el % bruto de un peldaño contra la
serie es la fuerza de la clase en 1c1 (el CdM gana el 90 % a casi todo, el
sacerdote el 20 %), así que desde el 05/09/2026 el rating es **relativo a lo
que saca la serie de esa misma clase contra la misma mezcla de rivales**:
`1500 + 400·(log10(w/(1-w)) − log10(r/(1-r)))`, con `w` el % del peldaño y `r`
el de la referencia serie contra serie por pareja (últimos 7 días). Una tabla
vacía vale 1500 por construcción. Nunca se pierde ni se sobrescribe: es el
patrón de medida y el suelo cuando no hay datos.

La escalera **no se ordena por número de versión y no es única**: la v4 puede
ser peor que la v3 (le pasó al mago), y como la validada es un mosaico de las
clases que fueron aprobando, una versión no tiene una fuerza sino una por clase.
Hay diez escaleras, una por clase, y en las clases donde la serie gana, la serie
queda arriba.

**Cómo se mide.** El 15 % de las partidas automáticas (`AdaptiveAI.Arena.Escalera`)
va en modo `escalera`: un peldaño concreto —la validada o una generación, en
rueda— contra playerbots de serie, sin aprender (medir y aprender a la vez
cambiaría lo que se mide). Cada partida guarda `version_a` y `version_b`, la
versión con la que decidió cada lado (0 = serie). Cada diez minutos
`RefreshLadder()` hace una consulta por peldaño, agrupa por clase y rival sus
últimas partidas contra la serie, las compara con la referencia de esa pareja y
rehace la tabla; hacen falta `Escalera.PartidasMinimas` (30) para que un peldaño
entre. Los peldaños son las generaciones guardadas, así que
`Generaciones.Guardar` está en 12: podarlas deja la escalera sin escalones.

**Cómo se usa** (`AdaptiveAI.Real.Modo`, en la VM `espejo`):

- `validada`: la validada para todos, sin comprobar nada. Es lo que había antes.
- `mejor`: por clase, el peldaño con más rating medido. Si el más alto es la
  serie, el bot juega de serie y el módulo no se mete.
- `espejo`: el peldaño más cercano al rating del jugador, que vive en
  `adaptive_jugador` y se mueve en `OnPlayerPVPKill` con la misma fórmula de Elo
  que los bots (K = 32), tomando como fuerza del rival el peldaño con el que
  jugaba el bot.

**La variedad** la da `Real.Espejo.Dispersion` (1): cada bot se queda un escalón
por encima o por debajo del centro, **sorteado por bot y no por combate** (un bot
que cambia de nivel entre peleas se lee como que la IA falla), guardado en
`adaptive_bot.desvio` y resorteado cada `Real.Espejo.Horas` (6). Así el mundo
tiene rivales por encima y por debajo del jugador a la vez.

**La dificultad 1-6 es el dial fino entre un peldaño y la serie**: cuando el bot
"no reacciona" (la probabilidad *miss* de `AdaptiveAI.Dificultad.N`) quien actúa
es playerbots, así que `miss = 0` es el peldaño puro y `miss = 1` la serie
exacta. En espejo se deriva del hueco que queda (`3 + (rating del jugador −
rating del peldaño)/100`, acotada a 1-6); en los otros modos manda la del perfil
del bot.

Se ve con `.adaptive escalera` dentro del juego y en la sección *LA ESCALERA*
del informe `tools/progreso-adaptive.ps1`.

### Cómo se engancha a playerbots (fase 0, verificado en la VM)

Las estrategias de playerbots se registran en listas estáticas privadas, así
que un módulo no puede añadir una `Strategy` ni un `Multiplier` sin tocar su
código. Lo público y estable es `PlayerbotAI::DoSpecificAction(nombre)`, que
ejecuta una acción por su nombre pasando por el motor (comprobaciones y
listeners), y `PlayerbotAI::CanCastSpell(nombre, objetivo)`. El cerebro corre
desde `OnPlayerUpdate` del core (mismo hilo de mapa que la IA del bot) y las
recompensas salen de hooks del core (`OnDamage`, `OnAuraApply`,
`OnUnitDeath`, `OnPlayerSpellCast`, `OnPlayerPVPKill`,
`OnBattlegroundEnd`). Las arenas se crean con la API pública del gestor de
campos de batalla, sin cola (la secuencia está en la cabecera de
`mod_adaptive_ai_arena.cpp`). Ni una línea de playerbots ni del core. Sin
playerbots, el módulo compila y no hace nada.

### Ficheros

| Fichero | Qué |
|---|---|
| `src/AdaptiveAI.h` | Cabecera interna: configuración, estado, tabla Q, perfiles, cerebro, partidas |
| `src/mod_adaptive_ai.cpp` | Núcleo: catálogo de acciones de las diez clases, estado, Q, modelos, escalera, perfiles, cerebro, hooks de recompensa, loadout y fábrica de 80 |
| `src/mod_adaptive_ai_arena.cpp` | Planificador, creación de arenas, ciclo de vida, series, calibración |
| `src/mod_adaptive_ai_commands.cpp` | `.adaptive ...` |
| `conf/mod_adaptive_ai.conf.dist` | Claves `AdaptiveAI.*` |
| `data/sql/db-playerbots/base/adaptive_ai.sql` | Tablas `adaptive_*` en `acore_playerbots` (`adaptive_match_bot`: cada bot de cada partida) |
| `data/entrenado/adaptive_entrenado.sql.gz.old` | Lo aprendido hasta el 04/09 con el premio viciado, guardado como histórico. La fase 5 sólo importa `.sql` o `.sql.gz`, y `ADAPTIVE_IMPORTAR_ENTRENADO=false`: **no se importa**. Para volver a llevar el entrenamiento en el repositorio: `tools/exportar-adaptive.sh` (o `.adaptive exportar`, que desde el 05/09 exporta lo mismo) y quitar el `.old` |

### Comandos

```
.adaptive                         estado: decisor, modelos, arenas, contraste
.adaptive on | off                el decisor (las arenas siguen: linea base)
.adaptive aprender on | off
.adaptive arena lanzar <equipoA> <equipoB> [cantidad] [simultaneas] [modo]
                                  equipos: warrior, warrior+priest, *+*+*
.adaptive arena parar | auto on|off | estado
.adaptive bg lanzar <WS|AB|EY|AV|SA|IC> [bots por equipo] [modo]
.adaptive exportar | importar [fichero]   (administrador; importar recarga tambien aprobados y escalera)
.adaptive calibrar                examen ahora, fuera del reloj
.adaptive modelo lista | usar <version>   (usar: administrador)
.adaptive escalera                los peldanos medidos por clase y el modo del mundo
.adaptive revertir <clase> [forzar]       la clase recupera las filas de la validada (forzar: vaciarla aunque la validada no tenga)
.adaptive bot <nombre> [dificultad <1-6>]
.adaptive explicar <nombre>       ultimas decisiones con estado, valores y motivo
.adaptive guardar
.adaptive trazas on | off         trazas del entrenamiento a los GM con .gm on
.adaptive estado                  lo mismo que .adaptive a secas
```

### Trazas en el juego

Con `.gm on`, las trazas del entrenamiento (partida lanzada, bots llegados,
puertas abiertas, resultado con decisiones e interrupciones, calibración) te
llegan como mensajes de sistema `[adaptive]`. `AdaptiveAI.Trazas.GM` en la
conf y `.adaptive trazas on|off` en caliente.

### Ojo: sin jugador no hay bots

Con `BOTS_DISABLED_WITHOUT_PLAYER=true` (el valor por defecto; en este servidor
está en `false` desde el 02/09/2026 para entrenar de noche) playerbots
no conecta ningún bot mientras no haya una sesión real, y los desconecta a
todos cinco minutos después de que se vaya el jugador. La arena de fondo
entrena por tanto **mientras alguien juega**. Para entrenar las 24 horas:
`BOTS_DISABLED_WITHOUT_PLAYER=false` (más CPU y RAM: 400-500 bots siempre).
Y con 468 bots conectados hay unos 9 guerreros y 10 magos de nivel 80: ese es
el tope real de combates a la vez.

### Cómo comprobarlo

- `Server.log` al arrancar: `[adaptive-ai] Modelo validado v1 (...), candidata v2 (...)`
  y `[adaptive-ai] Activo: decisor si, aprendizaje si, arena si (20 simultaneas, pares: warrior:mage)`.
- Cada partida: `[adaptive-ai] Partida #N (auto): warrior X (candidata) contra mage Y (ninguna)...`
  y al acabar `Partida #N terminada: gana ... N decisiones, recompensa ...`.
- `.adaptive` desde la consola: partidas en curso, `Contraste (ultimas 200 por
  clase): warrior adaptativo X % (...), mage adaptativo Y % (...); global Z %` y
  `Referencia (serie contra serie, ultimas 200): warrior gana W % a mage`. La
  medida es cada clase contra su referencia, no el global.
- Batería histórica: pruebas 1.33 a 1.37 de la batería retirada el 10/09/2026
  (`CHANGELOG.md`).

---

## mod-standby: modo en espera

**Carpeta:** `modules/mod-standby/` · **Se activa con:** `INSTALL_MOD_STANDBY`
(sigue a `WORLDSERVER_STANDBY` en `config.sh`)

### El problema

El servidor es de una sola persona. Con 200-400 bots dentro consume ~6 GB y
~270 % de CPU las 24 h aunque nadie juegue. La VM no se puede apagar (authserver,
MySQL, panel y reino tienen que seguir en pie), pero el worldserver —que es el
que se lleva casi todo— sí.

### Qué hace

Tres piezas, todas detrás de `WORLDSERVER_STANDBY`:

1. **`ac-worldserver.socket`** (fase 6) posee el puerto 8085 desde el arranque
   de la VM y nunca se para. A la primera conexión de un cliente, systemd
   arranca `ac-worldserver.service` y le entrega el socket por herencia de
   descriptor. `worldserver.conf` → `Network.UseSocketActivation = 1`: el core
   usa ese socket y **no** marca el reino como desconectado al cerrarse.
2. **`ac-worldserver.service`** ejecuta el binario directamente (sin `screen`
   ni `simple-restarter`): la activación de socket exige que el proceso que
   hereda el descriptor sea hijo directo de systemd (`LISTEN_PID == getpid()`,
   `src/common/Utilities/Systemd.cpp` del core). `Restart=on-failure` +
   `StartLimitBurst=6/120s`: un crash (código 1) o un `.server restart`
   (código 2) se relanzan; el apagado por inactividad (código 0) se queda
   dormido. `Console.Enable = 0`; las operaciones de consola van por SOAP.
3. **El módulo** (`WorldScript::OnUpdate`, hilo del mundo) cuenta las sesiones
   con `WorldSession::IsHeadless() == false` (desde el 05/10/2026; antes `IsBot()`) —
   playerbots crea todas sus sesiones sin socket, así que el filtro es fiable, e incluye al humano en la
   pantalla de personajes. Sin ninguna durante `Standby.IdleMinutes` pide
   `sWorld->ShutdownServ(Standby.WarnSeconds, 0, SHUTDOWN_EXIT_CODE,
   "inactividad")`. Guardas: no actúa en los primeros `Standby.MinUptimeMinutes`
   tras arrancar; sólo si el proceso lo lanzó systemd por activación de socket
   (`Standby.RequireSocketActivation`, mira `getenv("LISTEN_FDS")`). El
   recuento de humanos para el comando `.standby estado` sale de un atómico que
   rellena `OnUpdate`.
4. **De quién es el apagado en curso** (M03, 24/09/2026). `g_own` vale
   *ninguno/ajeno*, *inactividad* o *manual*. Lo fijan los hooks
   `OnShutdownInitiate`/`OnShutdownCancel`, que el core llama en cada
   `ShutdownServ`/`ShutdownCancel`: el módulo marca sus propias peticiones y
   cualquier otra (`.server restart`, `systemctl restart`, consola) deja la
   marca en *ajeno*, aunque sustituya a la suya.

   | Situación | Qué hace |
   |---|---|
   | Entra un humano | Cancela sólo el de *inactividad* |
   | `.standby ahora` sin apagado | Pide uno *manual* (código 0) |
   | `.standby ahora` con el de *inactividad* en curso | Lo convierte en *manual* (mismo apagado) |
   | `.standby ahora` con uno *ajeno* | No lo toca y lo dice |
   | Se cumple la inactividad con un apagado en curso | No pide nada (no pisa uno ajeno) |
   | `.standby mantener` | Cancela el suyo (*inactividad* o *manual*), nunca uno *ajeno* |
   | `Standby.Enable = 0` en caliente | Cancela el de *inactividad*, respeta el *manual* y pone a cero el contador de vacío |
   | Cancelación externa | La marca vuelve a *ninguno*; el módulo puede rearmar después |

   `.standby estado` dice de quién es el apagado en curso.

### Por qué es un módulo y no un parche

No toca código ajeno: usa `WorldScript::OnUpdate`, `OnShutdownInitiate`,
`OnShutdownCancel`, `WorldSessionMgr::GetAllSessions()` y
`World::ShutdownServ/ShutdownCancel`, todo API pública del core. La parte
systemd vive en las fases 6 y 7 del instalador.

### Lo que va con él

- `config.sh`: `WORLDSERVER_STANDBY`, `STANDBY_IDLE_MINUTES` (15),
  `STANDBY_WARN_SECONDS` (60), `STANDBY_MIN_UPTIME_MINUTES` (10),
  `STANDBY_CHECK_SECONDS` (30).
- `scripts/ws-console.sh` (fase 6): manda un comando al worldserver por SOAP
  (curl, credenciales de `/etc/azerothcore-panel.env`). Lo usan `safe-stop.sh`
  y `notify-restart.sh` cuando no hay `screen`.
- `daily-restart.sh` / `weekly-update.sh` / `apply-panel-config.sh` no despiertan
  el worldserver si está dormido.
- Panel web: categoría "mod-standby" en configuración; `GET /api/server/status`
  y badge de cabecera ("En vivo" / "En espera" / "Caído").

### Si algo no funciona

- **El servidor no se duerme:** `.standby estado` en consola. Si dice
  "Activacion de socket heredada: no", el proceso no lo lanzó el `.socket`
  (¿arranque a mano? ¿modo clásico?). Si `Standby.Enable` está en 0, el módulo
  está apagado. Mira `[standby]` en `Server.log`.
- **El primer jugador ve la lista de reinos:** el arranque en frío no cupo en
  el timeout del cliente. Al reseleccionar ya está arrancado. Medir con
  `tools/medir-etapas.sh` y, si hace falta, subir `Standby.IdleMinutes` no
  ayuda — el problema es el tiempo de carga, no la ventana.
- **`.standby ahora` no cierra:** ¿ya había un apagado en curso? El comando lo
  dice. Si era uno ajeno (p. ej. un `.server restart`), el módulo no lo
  sustituye: se cumple ése, con su código de salida.
- Batería histórica: pruebas del modo en espera de la batería retirada el
  10/09/2026 (`CHANGELOG.md`).

---

## Bots en español

**Dónde:** `patches/locales-es-playerbots/01-ai-playerbot-texts-es.sql` · **Base:** `acore_playerbots`

Los bots hablan por el chat con frases de `ai_playerbot_texts` (botín, misiones,
subir de nivel, pullas, respuestas, "¿alguien ha visto Thunderfury?"). El
módulo elige la columna del idioma del cliente (`text_loc6` para esES). De 1908
frases, 1062 ya venían en español en la versión fijada; **las 846 restantes se
tradujeron el 02/09/2026** conservando los marcadores que el módulo sustituye
(`%item_link`, `%quest_link`, `%zone_name`…), en tono de jugador de chat.

Idempotente (fija la columna por id), sin variables de usuario en las
comparaciones (`CHANGELOG.md` anexo A9 §7.3), aplicado desde la fase 5 con `LOCALE_ES=true`.
Si una actualización de playerbots trae frases nuevas en inglés, el `SELECT`
para sacarlas es el mismo: `WHERE text_loc6 = ''`.

---

## Los NPC de servicio

**Dónde:** `spawn_service_npcs()` en `lib/utils.sh` · **Detalle:** ["Ubicaciones de los NPC de servicio"](#ubicaciones-de-los-npc-de-servicio)

Los módulos de transmogrificación, banco de materiales, cambio de rasgo racial y
arena 1c1 traen cada uno su NPC, pero **ninguno lo coloca en el mundo**. Esta
función los reparte por las once capitales, alrededor del NPC del Dungeon Master,
dos a cada lado y a menos de cinco yardas.

Lo que parece trivial y no lo es:

- **La altura no se hereda.** Mover un NPC en horizontal manteniendo su altura lo
  entierra en cuanto el suelo tiene pendiente. SQL no sabe consultar la altura
  del terreno, así que a cada NPC se le copia la altura del **NPC real más
  cercano** dentro de 25 yardas, más 20 cm.
- **Hay capitales con excepciones**: dos donde el NPC del módulo mira a la pared,
  dos donde está sobre un agujero y te caes al vacío, y una donde a un lado hay
  una pared y unas cajas. Están como listas al principio de la función.
- Es idempotente: borra las apariciones anteriores antes de crear las nuevas.

---

## Razas y clases (ARAC)

**Dónde:** `patches/arac/` · Cuatro ficheros SQL

`mod-arac` permite cualquier combinación de raza y clase. Su repositorio tiene
**dos correcciones importantes sin mergear**, así que las aplicamos nosotros:

| Fichero | Qué arregla |
|---|---|
| `01-fix-starting-gear-and-skills.sql` | Las combinaciones nuevas nacían **sin equipo ni habilidades**. Es el PR #42 del upstream, abierto desde 2025 |
| `02-fix-racial-spells.sql` | Blizzard ató cuatro hechizos de paladín y chamán a razas concretas; con razas nuevas no los aprendían. Es el PR #46 |
| `03-remove-invalid-races.sql` | Filas con razas que no existen en WotLK, que hacían al servidor escupir `Wrong race NN in playercreateinfo` en cada arranque |
| `04-generic-class-trainers.sql` | Instructores genéricos de clase: saca del evento "Arena Tournament" (sin eso no aparecen nunca) sólo los de las clases que no tienen instructor propio en cada sitio, y añade los dos que faltaban (brujo en Meseta Nube Roja y en Darnassus). Ver abajo |

**Los instructores de las combinaciones nuevas** (02/09/2026). AzerothCore
trae de serie nueve instructores genéricos, uno por clase (entradas
26324-26332, "Instructor de druidas", "Instructora de chamanes", ...), en 24
sitios: las 8 zonas de inicio, los 8 primeros pueblos y las 8 capitales. Tienen
facción 35 (amistosa con las dos facciones), la misma lista de hechizos que los
instructores normales y el menú por defecto (entrenar, olvidar talentos, doble
especialización). El core sólo comprueba la **clase** del jugador, nunca la
raza (`Trainer::IsTrainerValidForPlayer`, `Creature::CanResetTalents`), así que
un tauren paladín o un humano chamán aprenden en ellos sin más.

**Pero no aparecían**: sus 213 spawns están ligados en `game_event_creature`
al evento 31, "Arena Tournament" (los reinos de torneo de Blizzard tenían a
todos los instructores en las zonas de inicio), y ese evento no está activo. Se
vio en el juego: en Ammen Vale no había nadie.

**Qué hace el parche 04.** Saca del evento **sólo los genéricos de las clases
que no tienen instructor propio en ese sitio**: en Northshire ya hay
instructores humanos de seis clases, así que sólo se muestran cazador, chamán
y druida; en Ventormenta están las nueve y no se muestra ninguno; en Forjaz y
Orgrimmar sólo falta el druida. Los demás (148 de 215) se quedan en el evento,
que es su estado original: sin duplicados ni NPC que no responden a nadie. El
cálculo se hizo sobre la BD real (instructores de tipo clase por sitio, sin
contar los genéricos). Además añade los dos spawns que faltaban, brujo en
Meseta Nube Roja y en Darnassus, en el hueco de la fila de sus vecinos (guids
8000101 y 8000102). El resto del evento 31 (vendedores y pedestales del
torneo) no se toca. La lista de qué queda visible en cada sitio está comentada
en el propio SQL y, con teletransporte, en la prueba histórica 1.16 de
la batería retirada el 10/09/2026 (`CHANGELOG.md`).

Al probarlos: sólo tienen el flag de **instructor**, no el de conversación.
Con un personaje de **otra clase** el clic no hace nada, ni siquiera abre
ventana: el core lo ignora en silencio (`SendTrainerList` →
`IsTrainerValidForPlayer`). Hay que ir con un personaje de la clase del
instructor. Para llegar a la fila de Ammen Vale: `.go creature 96371`.

---

## Textos en español

**Dónde:** `patches/locales-es/` · Dos ficheros SQL

El cliente pide los textos en su idioma y el servidor los saca de las tablas
`*_locale`. Las criaturas del juego base ya vienen traducidas; **las que añaden
los módulos, no**: se ven en inglés aunque juegues con el cliente en español.

- `01-mod-transmog-es.sql` — sólo **las dos cadenas** que el módulo no trae. Las
  otras 43 ya vienen traducidas por sus autores y retraducirlas sería trabajo
  duplicado y peor.
- `02-npc-servicio-es.sql` — los nombres de los NPC que añaden los módulos.

---

## Recompensas por nivel

**Dónde:** `congrats_on_level_rewards.sql` (raíz) + `patches/custom-items/600000-ganzua-de-recompensa.sql`
· Lo aplica la fase 5 (idempotente) · **Capa 1 (v3) del 02/09/2026 · capa 2 del 10/09/2026**

La tabla de recompensas (oro, hechizos, objetos) que entrega
`mod-congrats-on-level` al subir de nivel. Va acompañada de los tres parches de
código de más abajo: sin el 01 sólo funcionan los múltiplos de 10, y sin el 03
un objeto que no cabe en la bolsa se pierde.

Son **dos capas con criterios distintos**:

- **Capa 1 — QoL permanente** (niveles 10,20…70, 77, 80). El criterio de
  abajo. Sin cambios desde la v3.
- **Capa 2 — premio de sabor** (impares 11–79, sin el 77). Un contenedor
  abrible por nivel, `money = 0`, rotando **Equipo → Gemas → Materiales**. El
  botín se ajusta al tramo y no da XP, así que en un servidor de una persona
  con bots no toca el equilibrio. Equipo = cajón de pícaro del tramo
  (Battered…Reinforced Junkbox) + **ganzúa de recompensa**, objeto propio
  **600000** (`patches/custom-items/600000-ganzua-de-recompensa.sql`): copia de
  la Titanium Skeleton Key sin el requisito de Herrería —que un no-herrero no
  puede saltarse—, ligada al recoger y de un uso. Las tablas de contenedores por
  tramo están comentadas en el propio SQL (el diseño ya está implantado). El nombre y la
  descripción los manda el servidor; el **icono** y la línea verde *"Uso: …"*
  necesitan el parche de cliente `cliente/Data/{esES,enUS}/patch-<idioma>-4.MPQ`
  (`Item.dbc` + `Spell.dbc`, que el cliente sólo conoce hasta el `entry`
  ~56806). Lo genera `tools/construir-parche-cliente-items.py` y lo instalan
  `cliente/instalar-cliente.ps1` y el panel web (`addons/patches.json`, con
  `targetDir`). Cómo crear otro objeto propio: «Crear un objeto que no existe en 3.3.5a» (REFERENCES.md).

**El criterio de la capa 1** (revisión del 02/09/2026): cosas permanentes que
quitan fricción jugando solo —espacio, desplazamiento, cambio de rol— y oro
para lo que ese nivel obliga a pagar, no más. Fuera juguetes, consumibles de un
uso, telas sueltas y reliquias. Lo que hay, por nivel:

| Nivel | Oro | Hechizo | Objetos |
|---|---|---|---|
| 10 | 1 | — | 4 bolsas de 10 (blancas); brujo: bolsa de almas de 12 |
| 20 | 5 | Equitación aprendiz | — |
| 30 | 10 | — | brujo: bolsa de almas de 16 |
| 40 | 25 | Equitación oficial + **doble especialización** (los dos hechizos del entrenador, 63680 y 63624) | 4 bolsas de 14 (la última blanca que existe) |
| 50 | 25 | — | brujo: bolsa de almas de 20 |
| 60 | 75 | Vuelo normal | 4 bolsas de 16; brujo: 24 |
| 70 | 150 | Vuelo épico | — |
| 77 | 0 | **Vuelo en clima frío** (faltaba: sin él no se vuela en Rasganorte) | — |
| 80 | 50 | — | 4 bolsas de 20; brujo: 32 |

Total 341 oro (la v2 daba 392, con 45 a nivel 20). Cada decisión, lo que se
descartó y por qué, los IDs verificados y los dos avisos sobre los modos de
desafío (Sólo Fabricado no puede equipar ninguna bolsa regalada; Sólo Normal e
Iron Man sólo las blancas) están **comentados en el propio SQL**, que es donde
hay que mirar antes de tocar la tabla.

Cosas de la tabla que no son obvias: admite varias filas por nivel (así se dan
cuatro bolsas), `race` y `class` filtran la fila entera, `money` va en **oro**,
un hechizo con `learn=0` se lanza y con `learn=1` se aprende, y no es
retroactiva (un personaje que ya pasó el nivel no recibe nada; a mano: `.send
items`, `.learn`). Lanzarlo a mano es inofensivo; la fase 5 lo aplica y la
fase 8 lo reintenta si la base aún no existía.

---

## Parche de cliente ARAC

**Dónde:** `cliente/Data/<idioma>/patch-<idioma>-4.MPQ` (fundido junto con los
objetos propios del servidor, «Crear un objeto que no existe en 3.3.5a» (REFERENCES.md)) · Se copia a
`WoW\Data\<idioma>\` en cada PC que juegue (`cliente/instalar-cliente.ps1` lo
hace solo). Lo genera `tools/construir-parche-cliente-items.py`.

Lleva fundidos tres ficheros de datos del cliente (`CharBaseInfo.dbc`,
`CharStartOutfit.dbc`, `SkillRaceClassInfo.dbc`, copia sin modificar de
`patch-contents/DBFilesContent/` del mod-arac fijado en `versions.lock`) que
son los que hacen que la pantalla de creación de personaje ofrezca las
combinaciones nuevas, y que el libro de hechizos de esos personajes pinte sus
pestañas de árbol correctamente. **El servidor no puede hacer esto por ti**:
sin estos DBC en el cliente, las combinaciones raza/clase nuevas no aparecen
al crear personaje, y los personajes ya creados con una combinación exclusiva
de ARAC muestran todos sus hechizos bajo "General".

**Hasta el 21/09/2026** estos tres DBC iban en un fichero aparte,
`Data/Patch-Arac.MPQ` (byte a byte el mismo `Patch-A.MPQ` del repositorio de
mod-arac, MD5 `864c5d27…`; antes `Patch-C.MPQ`), plano en `Data/`. Se creía
válido porque el cliente carga de `Data/` cualquier `patch-<lo que sea>.MPQ` y
ninguno de los otros parches del cliente de referencia (`patch-V`, `-W`, `-Z`,
`-Zava-*`) trae esos tres DBC. **Esa premisa era incorrecta**: desensamblando
el `Wow.exe` real se comprobó que el cargador de parches sueltos de `Data/`
exige un único carácter tras `"patch-"` (`patch-?.MPQ`); `"Arac"` no encaja y
el fichero nunca se cargaba, aunque estuviera presente y con el SHA-256
correcto. Diagnóstico completo, con las direcciones del binario y la
correlación con los personajes afectados, en `CHANGELOG.md`, tarea
E1g. `patch-<idioma>-4.MPQ` sí lo carga el Wow.exe (comprobado en juego), así que
ahí es donde van ahora, duplicados en `esES` y `enUS` porque los DBC no
dependen del idioma. `cliente/instalar-cliente.ps1` limpia el
`Data/Patch-Arac.MPQ` suelto (y los nombres antiguos `Patch-X/C/A.MPQ`) de
instalaciones previas, comprobando el MD5 antes de borrar.

---

## mod-dungeon-master: la columna `id1`

**Dónde:** `patch_dungeon_master_id1_bug()` en `lib/utils.sh` · Fragilidad media

El módulo consulta la tabla de criaturas usando `id1`, un nombre de columna que
AzerothCore **ya no usa**. Eso rompe la importación de su SQL y provoca un
segfault en marcha. El parche sustituye `id1` por `id` en su SQL y en dos
ficheros de C++.

Es un `sed` en vez de un `.patch` porque el cambio es una sustitución literal que
no depende del contexto: sobrevive a que el upstream reescriba las líneas de
alrededor. Es idempotente y se reaplica tras cada actualización del módulo.

---

## mod-challenge-modes: el hook que cambió de firma

**Dónde:** `patches/mod-challenge-modes/01-hook-onplayerresurrect.patch` · Fragilidad **alta**

El núcleo cambió el tercer parámetro de `OnPlayerResurrect` de `bool` a `bool&`.
El módulo todavía lo declara con el tipo viejo, así que su método no sobrescribe
nada y **la compilación entera falla**. El parche corrige la firma.

Sin este parche el servidor no compila con `mod-challenge-modes` activo.

---

## mod-congrats-on-level: recompensas en cualquier nivel

**Dónde:** `patches/mod-congrats-on-level/01-reward-any-level.patch` · Fragilidad **alta**

El módulo entregaba las recompensas dentro de un `switch` con los niveles 10, 20,
30… escritos a mano. Cualquier fila que metieras para el nivel 5, 15, 25… **se
ignoraba siempre y sin aviso**: ni el `.conf` ni la base de datos podían
cambiarlo.

El `switch` sobraba: la función que entrega el premio ya consulta la tabla
filtrando por el nivel exacto y no devuelve nada si no hay fila. El parche lo
sustituye por esa comprobación.

### Parche 02: el mensaje de la recompensa se puede apagar (02/09/2026)

Con el premio en todos los niveles, el módulo mandaba en cada subida un anuncio
a todo el servidor y un aviso de banda ("Se le ha concedido N cobre y unos
cuantos tesoros"), y no había forma de apagarlos: el código decía "Always send
message on reward level up". `02-reward-message-toggle.patch` añade la clave
`Congrats.RewardMessage` (declarada en el `.conf.dist`, para que
`set_conf_value` no avise) y la fase 5 la deja **apagada** por decisión del
usuario (`CONGRATS_REWARD_MESSAGE=false`). Junto con ella se expone el aviso
del módulo al conectar (`CONGRATS_LOGIN_ANNOUNCE`, apagado) y el anuncio de
nivel (`CONGRATS_LEVEL_MESSAGE`, encendido).

Y una segunda cosa que salió al probarlo: apagado el mensaje de recompensa,
**seguía apareciendo** el anuncio de nivel. Eran los bots: pasan por el mismo
hook, y con cientos subiendo de nivel cada uno recibía su premio (oro y objetos
regalados) y se anunciaba a todo el servidor. El mismo parche añade
`Congrats.IgnoreBots` (`CONGRATS_IGNORE_BOTS=true`): a los bots, ni premio ni
anuncio. Escrito contra `fed4752e` con el parche 01 ya puesto; si el upstream
toca ese bloque, la fase 3 avisa.

### Parche 03: por correo si no cabe, y hechizos disparados (02/09/2026)

`03-mail-when-bags-full.patch`. Dos cosas que salieron al rehacer la tabla:

- Los objetos se daban con `AddItem`, y con la bolsa llena **se perdían** (lo
  dice el README del módulo). Con cuatro bolsas en un mismo nivel era cuestión
  de tiempo. Ahora, si `CanStoreNewItem` dice que no cabe, se crea el objeto y
  se manda por correo con `MailDraft`, igual que hace `.send items` (remitente
  el propio jugador, papelería de GM, asunto en español para esES/esMX). Si el
  `itemId` no existe, línea de error en el log en vez de silencio.
- Los hechizos con `learn=0` se lanzaban sin `triggered`. Así un hechizo con
  coste de maná falla en una clase sin maná, y los de doble especialización no
  son lanzables por un jugador: el entrenador los lanza con `triggered=true`
  (`PlayerGossip.cpp` del core). Ahora se hace igual.

No añade claves. Escrito contra `fed4752e` con 01 y 02 puestos; sólo toca
`giveAward()`.

---

## mod-random-enchants: encantamientos a tu nivel

**Dónde:** `patches/mod-random-enchants/01-level-scaled-tiers.patch` · Fragilidad **alta**

Los encantamientos aleatorios se sorteaban sin mirar el nivel del personaje, así
que a nivel 10 podía tocarte uno de nivel 80 (y al revés). El parche pasa el
jugador a la función que sortea, para escalar el resultado a su nivel, y
arregla la consulta SQL original (`= NULL` y un `AND`/`OR` sin paréntesis que
anulaban el filtro de tier).

Desde el 01/09/2026 el parche también toca `conf/random_enchants.conf.dist` para
**declarar** las cinco claves que añade (`RandomEnchants.ScaleWithLevel` y
`Tier2..5MinLevel`). Sin eso, la fase 5 las marcaba como no declaradas, con
razón. Consecuencia práctica: para reaplicarlo sobre un módulo que ya tenga los
hunks de `src/` hay que devolverlo a limpio antes (`git checkout -- .`), porque
`apply_module_patches` no sabe aplicar "la parte que falta": desde el
05/09/2026 lo detecta ("cambios que no corresponden a sus parches") y no toca
nada. Se regeneró contra
el mirror del commit fijado (`mirrors/mod-random-enchants@02a2e0d83b3c.tar.gz`).

---

## Aviso de claves no declaradas

**Dónde:** `set_conf_value()` y `report_unknown_conf_keys()` en `lib/utils.sh` · Fragilidad baja

`set_conf_value` escribe una clave en un `.conf`. Si la clave ya está, la
sustituye; si no está, la añade al final. Y ahí estaba el agujero: los `.conf` se
copian de su `.conf.dist`, que declara **todas** las claves reales del programa,
así que "no estaba" significa casi siempre "no existe con ese nombre". Hasta el
01/09/2026 eso se anunciaba con un `info` perdido entre cientos de líneas, y así
se colaron, sin que nadie se enterase:

| Clave fantasma | Consecuencia |
|---|---|
| `Playerbots.RandomBotMaxGearQuality` | Bots de nivel 80 vestidos de azul |
| `Playerbots.LevelBrackets.*` (versión sin el sistema) | Sin bots de nivel 80 |
| `MapUpdateThreadCount` | **Un solo hilo de mapas** con 250 bots, un núcleo al 93 % |
| `AllowTwoSide.Interaction.{Trade,Mail}`, `WhoList`, `AddFriend` | Nada (no existen); y faltaba `.Interaction.Chat` |
| `AutoBalance.enable`, `rate.global.*`, `Raids` | Escalado con los valores de fábrica |
| `Transmogrification.Enabled` | Nada (funcionaba porque el dist ya trae `Enable = 1`) |

Ahora, cuando añade una clave no declarada, **avisa en rojo** y la apunta; al
final de la fase 5 `report_unknown_conf_keys` las repite todas juntas. Hay una
lista blanca de dos claves que sí son adiciones legítimas
(`PlayerbotsDatabaseInfo`, `Playerbots.Updates.EnableDatabases`: playerbots las
exige en `worldserver.conf` y el dist del core no las declara).

Un detalle del propio arreglo: `VALUE_ESC` (el valor escapado para el
reemplazo de `sed`) **no** vale para el `printf` que añade la línea; ahí va el
valor sin escapar.

---

## Espejos con `versions.lock`

**Dónde:** `mirror_all_repos()` y `restore_from_mirror()` en `lib/mirrors.sh` · Fragilidad baja

Dos cambios del 01/09/2026 para que `mirrors/` sea un respaldo de verdad:

- `--mirror` copia `versions.lock` dentro de `mirrors/`. Sin él, la carpeta es
  un montón de tarballs sin saber qué rama y qué fecha era la buena.
- Al restaurar, se busca el tarball **del commit que fija el lock**
  (`nombre@<commit>.tar.gz`). Antes se cogía el primero que hubiera (`head -1`):
  una copia vieja olvidada se habría restaurado en silencio y el servidor
  acabaría con código distinto del que dice el lock. Si sólo hay otra versión,
  se usa, pero avisando.

---

## Herramientas de operación

**Dónde:** `tools/` · Scripts sueltos, se lanzan a mano

| Script | Qué hace | Lo que sabe que no es obvio |
|---|---|---|
| `backup-servidor.sh` | Parada segura, volcado de las 4 bases, `.conf`, `versions.lock`, `Server.log`, crontab | Usa `sudo -n` para los servicios (sin contraseña) |
| `primer-arranque.sh` | Primer arranque desatendido | Habla con el worldserver por una tubería con nombre para responder `yes`; espera **el puerto 8085**, porque "World initialized" ya no se imprime; no confunde "Unknown database" con un error |
| `verificar-instalacion.sh` | Commits vs lock, claves que estuvieron rotas, claves fantasma, LevelBrackets, parches, servicios | — |
| `comprobar-modelos-cliente.py` | Por qué un objeto se ve como un cubo | Lee los MPQ del cliente |

---

## Cómo comprobar que todo está aplicado

```bash
cd ~/azerothcore-installer

# Reaplica los parches de código sobre los módulos (lo hace solo tras cada
# actualización semanal, pero se puede lanzar a mano)
bash lib/reapply-patches.sh

# Reaplica el SQL propio, los .conf y vuelve a colocar los NPC de servicio
./install.sh --only 5

# Recompila si se ha tocado código o se ha añadido un módulo propio
./install.sh --only 4
```

Cuando un `.patch` deja de aplicar, la fase 3 lo dice claramente y sigue
adelante: el módulo se queda con su comportamiento original. En
«Escribir un parche sobre código de terceros» (REFERENCES.md) está el procedimiento para regenerarlo contra el código
nuevo.

---

## Comandos

```
account create <usuario> <contraseña>     account set gmlevel <usuario> <n> -1
.account password <vieja> <nueva> <nueva>
.go creature id <entry> [n]    .tele <lugar>     .npc add <entry>   .npc delete
.additem <id> [n]   .lookup item <nombre>   .lookup creature <nombre>
.instance unbind all   .reload config   .server info   .announce <mensaje>
.server shutdown <s>   .server restart <s>
```

Módulos:

```
.bot add <nombre>               .playerbot rndbot stats
.ip get|set <nombre>            .ab mapstat   .ab creaturestat
.ahbot update|reload|empty      .transmog claim [all]   .dm reload
```

> `server announce` **no existe**: es `announce`. El core ignora los comandos
> desconocidos sin decir nada, y así se pasaron meses sin que los jugadores
> vieran los avisos de apagado.

---

### De los módulos propios (para cualquier jugador)

| Comando | Qué |
|---|---|
| `.grupo`, `.grupo N`, `.grupo mazmorra` | Grupo de bots donde estás (mod-party-here) |
| `.grupo banda [10\|25\|40]` | Una banda, sin cola |
| `.grupo fuera` / `.grupo estado` | Los bots se van / quién está |
| `.hermandad estado` / `activar` / `desactivar` | Tu hermandad de casa: roster, adoptarla, vaciarla de bots (mod-home-guild) |
| `.tokenturnin check` / `redeem` | Ver o canjear los tokens de los bots del grupo (mod-token-turnin) |
| `.actualizaciones` | Volver a ver el aviso de versiones nuevas (GM) |
| `.dc on` / `off` / `status` | mod-dungeon-clear, que queue-bots activa solo |
| `.wpvp estado` / `lista` / `iniciar <nombre>` / `parar [id]` / `recargar` | Guerra de mundo de world-bots (GM) |
| `.ayuda` / `.ayuda buscar <texto>` / `.ayuda comando <ruta>` / `.ayuda articulo <id>` / `.ayuda indice` | La ayuda del servidor desde el chat (mod-server-help); `.ayuda recargar` (admin) relee las tablas |
| `.standby estado` (GM) / `.standby ahora` / `.standby mantener <min>` / `.standby reanudar` (admin) | Modo en espera (mod-standby): ver cuánto falta para dormir, dormir ya, suspenderlo para una sesión larga |

Y sin teclear nada: el botón `?` de la barra ("Solicitud de ayuda") enseña
todos los comandos que tu cuenta puede usar, con el addon `ServerHelp`.


---

## Ubicaciones de los NPC de servicio

Estado a 01/09/2026, tras la verificación en el juego de las once capitales. Los
datos salen de la base de datos del servidor y del SQL del módulo, no de memoria.

Los cuatro NPC de servicio se colocan alrededor del NPC del **Dungeon Master**
(entrada `500000`), que su módulo reparte por once capitales. La lógica está en
`spawn_service_npcs()`, en `lib/utils.sh`.

### Las once ubicaciones

La numeración es la del comando `.go creature id 500000 <n>`, tal y como salió al
probarlo en el juego el 01/09/2026. **No coincide con el orden de los guid** (que
va de `8000001` en Ventormenta a `8000011` en Bahía del Botín), así que si el
comando cambiara de criterio hay que fiarse del guid y de las coordenadas, no del
número.

| # | guid | Capital | Facción | Mapa | x | y | z | orientación | Estado |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 8000006 | Cima del Trueno | Horda | 1 | -1277,6 | 73 | 128,75 | 5,96 | ✅ verificado |
| 2 | 8000011 | Bahía del Botín | Neutral | 0 | -14406 | 420 | 23,70 | **0,8584** | 🔄 girado 180° |
| 3 | 8000010 | Dalaran (Plaza del Tejerrunas) | Neutral | 571 | 5807 | 506,2 | 657,58 | 5,54 | 🔄 los cuatro a la derecha |
| 4 | 8000009 | Bancal de Luz (Shattrath) | Neutral | 530 | **-1839,42** | **5446,63** | -12,10 | **0,7876** | 🔄 movido y girado 90° |
| 5 | 8000008 | Lunargenta (Lonja Real) | Horda | 530 | 9738 | -7454 | 13,56 | **3,6416** | 🔄 girado 180° |
| 6 | 8000007 | Entrañas (canales) | Horda | 0 | 1637,2 | 240,1 | -43,10 | 3,14 | ✅ verificado |
| 7 | 8000005 | Orgrimmar | Horda | 1 | 1676 | -4316 | 61,80 | 5,70 | ✅ verificado |
| 8 | 8000004 | Exodar | Alianza | 530 | -3965,7 | -11653,6 | -138,84 | 0,85 | ✅ verificado (reubicado) |
| 9 | 8000003 | Darnassus (Jardines del Templo) | Alianza | 1 | 9869 | 2494 | 1316,20 | 3,10 | 🔄 vuelto a simétrico |
| 10 | 8000002 | Forjaz | Alianza | 0 | -4918 | -957 | 501,53 | 2,26 | ✅ verificado |
| 11 | 8000001 | Ventormenta (Distrito del Comercio) | Alianza | 0 | -8842 | 626 | 94,30 | 0,44 | ✅ verificado |

En negrita, los valores que ya no son los que trae el módulo.

> Los cinco cambios están **aplicados en el servidor** (01/09/2026): se copió
> `lib/utils.sh` a la VM, se ejecutó `spawn_service_npcs` y se reinició el
> worldserver. Falta la comprobación visual dentro del juego.

### Comandos para llegar

```
.go creature id 500000 <número de la tabla>
```

Por coordenadas, si hace falta: `.go xyz <x> <y> <z> <mapa>`.
Ejemplos: `.go xyz -8842 626 94.3 0` (Ventormenta), `.go xyz 1676 -4316 61.8 1` (Orgrimmar).

> ⚠️ **Ojo al comprobar la orientación con este comando:** te deja en la posición
> del NPC y mirando hacia donde mira él, así que le ves la espalda sea cual sea
> su orientación. Para juzgarlo hay que dar dos pasos atrás y darse la vuelta.

### Cómo se colocan

Alrededor del Dungeon Master, en el vector perpendicular a su orientación: a su
izquierda es `(-sin o, cos o)` y a la derecha el mismo con signo cambiado.

| NPC | Entrada | Lado | Distancia |
|---|---|---|---|
| Warpweaver (transmogrificación) | 190010 | izquierda | 2,5 yardas |
| Ling (banco de materiales) | 290011 | izquierda | 5 yardas |
| Swirl (cambio de rasgo racial) | 98888 | derecha | 2,5 yardas |
| Arena Battlemaster 1v1 | 999991 | derecha | 5 yardas |

```
   [Ling]  [Warpweaver]  →[ DUNGEON MASTER ]←  [Swirl]  [Battlemaster]
     5 yd     2,5 yd                            2,5 yd      5 yd
```

Dos a cada lado y nunca más allá de 5 yardas. Antes iban los cuatro en fila al
mismo lado hasta 8 yardas, y así es como acababan dentro de paredes y cajas.

**La altura no se hereda del ancla.** Desplazarlos en X/Y manteniendo su Z los
entierra en cuanto el suelo tiene pendiente (en Ventormenta el terreno sube más
de un metro en diez yardas). SQL no sabe consultar la altura del terreno, así que
a cada NPC se le copia la Z del **NPC real más cercano** dentro de 25 yardas, más
20 cm para que no se hundan los pies.

### Excepciones por capital

Están como listas al principio de `spawn_service_npcs()`, en `lib/utils.sh`:

| Lista | Capital | Qué hace | Por qué |
|---|---|---|---|
| `ROTATE` | Bahía del Botín, Lunargenta | Fija la orientación del ancla en un valor absoluto (el del módulo + π) | Los cinco NPC, el Dungeon Master incluido, salían de espaldas |
| `RELOCATE` | Exodar, Shattrath | Mueve el grupo entero a otras coordenadas | En los dos el ancla del módulo no está sobre suelo válido y al llegar te caes al vacío |
| `ALL_RIGHT` | Dalaran | Pone los cuatro escalonados a la derecha (2,5 / 5 / 7,5 / 10) | El lado izquierdo da contra una pared y unas cajas |

La orientación se fija en **absoluto**, nunca sumando 180°: sumar no es
idempotente y a la segunda pasada los deja como estaban.

#### Los dos giros de 180°

| Capital | Orientación del módulo | Fijada |
|---|---|---|
| Bahía del Botín | 4,00 | 0,8584 (4,00 + π − 2π) |
| Lunargenta | 0,50 | 3,6416 (0,50 + π) |

#### El caso de Shattrath

El ancla del módulo (`-1850`, `5436`) queda sobre un hueco de la Terraza de la
Luz: al teletransportarse allí se cae al vacío. Se le mueve **15 yardas a su
izquierda**, que es el vector `(-sin 5,50 ; cos 5,50) = (+0,7055 ; +0,7087)`:

```
x = -1850 + 15 × 0,7055 = -1839,42
y =  5436 + 15 × 0,7087 =  5446,63
```

La altura no cambia (`-12,10`): ahí el suelo de la terraza es plano. Y se le gira
**90° a la izquierda**, `5,50 + π/2 = 0,7876`, para que deje de mirar al hueco.
Los cuatro servicios se reparten simétricamente a su alrededor, como en el resto.

> Del giro sólo se dijo "90°", sin lado. Si al comprobarlo mira mal, el giro
> contrario es **3,9292** (`5,50 − π/2`).

### Cerrado: la orientación de Forjaz y Orgrimmar

Estuvo abierto varias sesiones. Se probaron los dos valores opuestos y los dos se
reportaron como "de espaldas", lo que no podía ser cierto a la vez: la causa era
el propio `.go creature id`, que te deja mirando hacia donde mira el NPC.

**Verificado en el juego el 01/09/2026: la orientación que trae el módulo es la
correcta** (Forjaz 2,26 y Orgrimmar 5,70). Las dos capitales se han sacado de la
lista `ROTATE`, que ahora sólo tiene Bahía del Botín y Lunargenta.

Como referencia, la orientación en AzerothCore va en radianes de 0 a 2π,
midiendo en sentido antihorario:

| Mira hacia | Radianes |
|---|---|
| Norte (+x) | 0 |
| Oeste (+y) | 1,571 (π/2) |
| Sur | 3,142 (π) |
| Este | 4,712 (3π/2) |

### Alturas actuales, por si algo vuelve a hundirse

| # | Capital | z del ancla | z de los NPC |
|---|---|---|---|
| 1 | Cima del Trueno | 128,75 | 128,65 · 128,95 |
| 2 | Bahía del Botín | 23,70 | 22,61 · 22,77 |
| 3 | Dalaran | 657,58 | 657,41 · 657,78 |
| 4 | Shattrath | -12,10 | -11,90 (los cuatro) |
| 5 | Lunargenta | 13,56 | 13,76 |
| 6 | Entrañas | -43,10 | -42,90 · -42,82 |
| 7 | Orgrimmar | 61,80 | 62,00 · 62,09 · 62,13 |
| 8 | Exodar | -138,84 | -138,64 |
| 9 | Darnassus | 1316,20 | 1316,08 · 1316,40 · **1317,32** |
| 10 | Forjaz | 501,53 | 501,73 |
| 11 | Ventormenta | 94,30 | 94,50 · 95,31 |

⚠️ En Darnassus el transmogrificador se ha quedado en **1317,32**, más de una
yarda por encima del ancla y 1,2 por encima del banco de materiales, que está a
2,5 yardas de él. El vecino del que copió la Z estaba más alto de la cuenta; si
al mirarlo se ve flotando, se arregla con un `UPDATE` a 1316,40 como los otros.

En Bahía del Botín los NPC quedan **por debajo** del ancla (22,6-22,8 frente a
23,7): es correcto, ahí el ancla del módulo está algo elevada y ellos siguen el
suelo real de los alrededores.

### Cómo reaplicar tras un cambio

```bash
cd ~/azerothcore-installer
git pull                                # si el cambio viene del repositorio
source ./config.sh; source ./lib/utils.sh
spawn_service_npcs
sudo systemctl restart ac-worldserver   # los spawns solo se leen al arrancar
```

Es idempotente: borra las apariciones anteriores de esas cuatro entradas antes de
crear las nuevas, y las orientaciones y traslados se fijan en valores absolutos,
así que se puede repetir sin duplicar nada ni acumular giros.

---

## Emparejamientos PvP de referencia
### Heuristic Matrix for AzerothCore Bot Training

Version: WotLK 3.3.5a (ICC / Wrathful)
Target: AzerothCore Single Player
Purpose: Initial PvP behaviour weights for AI bots.

> **Important**
>
> This document is **not based on official Blizzard winrate statistics**.
> Blizzard never published class-vs-class win percentages for Wrath 3.3.5.
>
> The values below are heuristic estimates reconstructed from:
>
> - ArenaJunkies archived discussions.
> - Elitist Jerks PvP guides.
> - Wrath tournament gameplay.
> - Long-running competitive 3.3.5 private servers.
>
> These numbers should be interpreted as **AI tuning weights**, not historical facts.

---

### Rating Scale

| Winrate | Interpretation |
|---------|---------------|
| 70 | Very favorable |
| 65 | Favorable |
| 60 | Slight advantage |
| 55 | Small advantage |
| 50 | Even |
| 45 | Small disadvantage |
| 40 | Disadvantage |
| 35 | Hard matchup |
| 30 | Very difficult |

---

### Primary PvP Specializations

| Class | Spec |
|--------|------|
| Rogue | Subtlety |
| Mage | Frost |
| Warrior | Arms |
| Death Knight | Unholy |
| Warlock | Affliction |
| Hunter | Marksmanship |
| Druid | Feral |
| Paladin | Retribution |
| Priest | Discipline |
| Priest | Shadow |
| Shaman | Elemental |
| Paladin | Holy |

Holy Paladin is listed separately because it functions primarily as a healer rather than a duel DPS.

---

### Overall Duel Strength (Estimated)

| Spec | Average Matchup Score |
|------|-----------------------|
| Holy Paladin | 72 |
| Sub Rogue | 66 |
| Frost Mage | 64 |
| Unholy DK | 63 |
| Feral | 61 |
| Affliction | 60 |
| MM Hunter | 56 |
| Arms Warrior | 55 |
| Disc Priest | 54 |
| Retribution | 53 |
| Shadow | 51 |
| Elemental | 49 |

---

### Matchup Matrix

Each value represents the estimated chance that the **row** defeats the **column**.

| Attacker | Rogue | Mage | Warrior | UH DK | Lock | Hunter | Feral | Ret | Disc | Shadow | Ele |
|----------|------:|------:|---------:|------:|------:|--------:|-------:|-----:|------:|--------:|-----:|
| Rogue | 50 | 65 | 55 | 45 | 60 | 55 | 40 | 45 | 55 | 55 | 60 |
| Mage | 35 | 50 | 70 | 60 | 45 | 40 | 45 | 55 | 50 | 55 | 60 |
| Warrior | 45 | 30 | 50 | 40 | 35 | 55 | 35 | 50 | 40 | 45 | 45 |
| UH DK | 55 | 40 | 60 | 50 | 55 | 35 | 45 | 45 | 35 | 55 | 50 |
| Lock | 40 | 55 | 65 | 45 | 50 | 45 | 50 | 55 | 45 | 55 | 55 |
| Hunter | 45 | 60 | 45 | 65 | 55 | 50 | 45 | 50 | 45 | 50 | 55 |
| Feral | 60 | 55 | 65 | 55 | 50 | 55 | 50 | 55 | 45 | 50 | 55 |
| Ret | 55 | 45 | 50 | 55 | 45 | 50 | 45 | 50 | 40 | 50 | 55 |
| Disc | 45 | 50 | 60 | 65 | 55 | 55 | 55 | 60 | 50 | 55 | 60 |
| Shadow | 45 | 45 | 55 | 45 | 45 | 50 | 50 | 50 | 45 | 50 | 55 |
| Elemental | 40 | 40 | 55 | 50 | 45 | 45 | 45 | 45 | 40 | 45 | 50 |

---

### Strongest Counters

#### Rogue vs Frost Mage (~65)

Expected AI behaviour:

- Force Blink.
- Save Shadowstep for re-engage.
- Chain Cheap Shot → Kidney Shot.
- Use Blind to reset.
- Avoid Ice Block bait.

Priority weight:

```
Aggression: High
Reset priority: Very High
Kick priority: Frostbolt
```

---

#### Frost Mage vs Arms Warrior (~70)

Expected AI behaviour:

- Never stand still.
- Rotate Nova and Pet Nova.
- Blink only after Charge.
- Deep Freeze during burst windows.

Priority weight:

```
Kiting: Maximum
Blink reserve: Charge response
Root chaining: High
```

---

#### MM Hunter vs Unholy DK (~65)

Expected AI behaviour:

- Maintain maximum range.
- Concussive Shot permanently.
- Scatter into trap whenever possible.
- Disengage after Death Grip.

Priority weight:

```
Distance: Maximum
Trap usage: High
Pet survival: Medium
```

---

#### Feral vs Rogue (~60)

Expected AI behaviour:

- Shift aggressively.
- Bear Form during stun chains.
- Frenzied Regeneration under burst.
- Prevent rogue resets.

Priority weight:

```
Defensive shifting: High
Bleed uptime: Maximum
```

---

#### Discipline Priest vs Unholy DK (~65)

Expected AI behaviour:

- Pre-shield before Gargoyle.
- Fear after offensive cooldowns.
- Keep Penance available.
- Mana efficiency over burst.

Priority weight:

```
Shield priority: Maximum
Fear timing: Reactive
```

---

### AI Behaviour Profiles

#### Sub Rogue

Strengths

- Opener.
- Crowd control.
- Target switching.

Weaknesses

- Sustained pressure.
- Armor-heavy targets.

Bot priorities

1. Open from stealth.
2. Force trinket.
3. Reset if cooldowns are lost.

---

#### Frost Mage

Strengths

- Kiting.
- Control.
- Burst.

Bot priorities

1. Stay above 25 yards.
2. Chain roots.
3. Avoid overlapping CC.

---

#### Arms Warrior

Strengths

- Constant pressure.
- Mortal Strike.

Bot priorities

1. Stay on target.
2. Preserve Charge.
3. Use Intercept reactively.

---

#### Unholy DK

Strengths

- Disease pressure.
- Gargoyle burst.

Bot priorities

1. Keep diseases active.
2. Grip only when valuable.
3. Gargoyle after CC.

---

#### Affliction Warlock

Strengths

- DoT pressure.
- Fear.

Bot priorities

1. Multi-dot.
2. Keep Haunt.
3. Fear during burst.

---

#### MM Hunter

Strengths

- Range control.
- Traps.

Bot priorities

1. Maintain spacing.
2. Trap after Scatter.
3. Save Disengage.

---

#### Feral

Strengths

- Mobility.
- Bleeds.

Bot priorities

1. Keep Rip active.
2. Shift intelligently.
3. Bear during danger.

---

#### Retribution

Strengths

- Burst windows.

Bot priorities

1. Wings timing.
2. Hammer of Justice before burst.
3. Defensive Divine Protection.

---

#### Discipline Priest

Strengths

- Survivability.
- Utility.

Bot priorities

1. Shield.
2. Penance.
3. Fear defensively.

---

#### Shadow Priest

Strengths

- Sustained pressure.

Bot priorities

1. Keep DoTs.
2. Silence healers.
3. Dispersion under burst.

---

#### Elemental Shaman

Strengths

- Burst.

Bot priorities

1. Flame Shock.
2. Lava Burst.
3. Thunderstorm for spacing.

---

### Suggested AzerothCore Weight Mapping

Example conversion.

| Matchup | Aggression | Defensive | CC |
|----------|-----------:|-----------:|---:|
| 70 | 1.00 | 0.30 | 0.90 |
| 65 | 0.90 | 0.40 | 0.85 |
| 60 | 0.80 | 0.50 | 0.80 |
| 55 | 0.70 | 0.60 | 0.70 |
| 50 | 0.50 | 0.50 | 0.50 |
| 45 | 0.40 | 0.70 | 0.60 |
| 40 | 0.30 | 0.80 | 0.70 |
| 35 | 0.20 | 0.90 | 0.80 |
| 30 | 0.10 | 1.00 | 0.90 |

These values can be mapped directly into:

- Target selection weights
- Spell priority multipliers
- Cooldown preservation logic
- Retreat thresholds
- Reset behaviour
- Kiting intensity
- CC chain confidence

---

### Confidence Assessment

| Matchup | Confidence |
|----------|------------|
| Mage vs Warrior | High |
| Hunter vs UH DK | High |
| Rogue vs Mage | High |
| Disc vs UH DK | Medium |
| Feral vs Rogue | Medium |
| Ret vs Rogue | Medium |
| Shadow vs Lock | Low |
| Elemental vs Feral | Low |

High-confidence matchups appear consistently across multiple historical community sources.
Lower-confidence matchups depend more heavily on player skill, engineering usage and duel conditions.
---

## La ayuda en juego por dentro

### HelpFrame (la ventana "Solicitud de ayuda")

`HelpFrame` es un panel de 640×532 (`HelpFrame.xml:99`) registrado en
`UIPanelWindows` como `center`, `whileDead = 1` (`UIParent.lua:39`). Lo abre
`ToggleHelpFrame()` (`UIParent.lua:431`), que muestra la página
`HELPFRAME_START_PAGE = "KBase"` (`HelpFrame.lua:6`). Dentro funciona como una
**pila de páginas** (`HelpFrame_ShowFrame(key)`, `HelpFrame_PopFrame()`,
`HelpFrame.lua:212-268`) con estas páginas (`HelpFrame.lua:12-22`):

| Clave | Frame | Qué es |
|---|---|---|
| `KBase` | `KnowledgeBaseFrame` | **La página inicial**: la base de conocimiento |
| `GMTalk` | `HelpFrameGMTalk` | "Hablar con un MJ" → abre consulta con respuesta |
| `ReportIssue` | `HelpFrameReportIssue` | "Informar de problema" → consulta sin respuesta |
| `Stuck` | `HelpFrameStuck` | "Personaje atascado" (botón de desatascar + consulta) |
| `Lag` | `HelpFrameLag` | "Informar de lag" (seis botones → `GMReportLag`) |
| `OpenTicket` | `HelpFrameOpenTicket` | El cuadro de texto de la consulta (crear / editar) |
| `GMResponse` | `HelpFrameViewResponse` | Respuesta del MJ (resolver / necesito más ayuda) |
| `Welcome` | `HelpFrameWelcome` | Página antigua, ya no se usa como inicio |

El estado de los tickets lo lleva `HelpFrame_OnEvent` (`HelpFrame.lua:74-210`)
con los eventos `UPDATE_GM_STATUS`, `UPDATE_TICKET`, `GMSURVEY_DISPLAY` y
`GMRESPONSE_RECEIVED`. Importante para nosotros: **los botones de ticket viven
dentro de `KnowledgeBaseFrame`** (`KnowledgeBaseFrameGMTalk`, `…ReportIssue`,
`…Stuck`, `…Lag`, `…EditTicket`, `…AbandonTicket`, `KnowledgeBaseFrame.xml`
al final) y `HelpFrame_OnEvent` los muestra u oculta según haya ticket abierto
(`HelpFrame.lua:155-159`, `169-173`, `204-208`). Cualquier cambio que hagamos
en la página KBase tiene que dejar esos seis botones donde están.

### KnowledgeBaseFrame (la base de conocimiento)

Es un frame hijo de `HelpFrame` con `setAllPoints` (`KnowledgeBaseFrame.xml`).
Contiene, de arriba abajo:

- Cabecera "Ayuda básica" (`KNOWLEDGEBASE_FRAME_TITLE`), líneas "MDD:" y
  "Alerta:" (`KBSystem_GetMOTD`, `KBSystem_GetServerNotice`; en un servidor
  privado devuelven `nil` y se ocultan).
- Botón "Más leídos" (`KBASE_TOP_ISSUES`) arriba a la derecha y el botón
  "Abrir registro de chat con MJ" (desactivado).
- **Buscador**: `KnowledgeBaseFrameEditBox` (128 bytes máx.), dos desplegables
  `KnowledgeBaseFrameCategoryDropDown` / `…SubCategoryDropDown`
  (`UIDropDownMenuTemplate`, 120 px) y botón "Buscar".
- **Lista de resultados**: `KnowledgeBaseArticleListFrame` con 20 botones
  `KnowledgeBaseArticleListItem1..20` (número, icono "candente", icono
  "actualizado", título), contador "%d - %d de %d artículos" y botones
  Anterior / Sig. de paginación.
- **Artículo**: `KnowledgeBaseArticleScrollFrame` (546×334,
  `UIPanelScrollFrameTemplate`) con título, texto, "ID de artículo: %d" y un
  botón **Volver** que llama a `KnowledgeBaseFrame_ShowSearchFrame()`.
- **Error**: `KnowledgeBaseErrorFrame` con `KnowledgeBaseErrorFrameText`.
- Los seis botones de ticket del HelpFrame y el botón Cancelar.

Es decir, **la interfaz que pides ya existe**: buscador, categorías, lista,
detalle, volver, scroll y mensaje de error. Sólo hay que cambiar de dónde
salen los datos.

Los datos salen hoy de funciones **implementadas en C dentro del ejecutable**
(`KnowledgeBaseFrame.lua`): `KBSetup_BeginLoading`, `KBSetup_GetCategoryCount`,
`KBSetup_GetCategoryData`, `KBSetup_GetSubCategoryCount/Data`,
`KBSetup_GetArticleHeaderCount/Data`, `KBQuery_BeginLoading(texto, categoría,
subcategoría, porPágina, página)`, `KBQuery_Get*`, `KBArticle_BeginLoading(id,
tipo)`, `KBArticle_GetData()` → `id, subject, subjectAlt, text, keywords,
languageId, isHot`. La respuesta llega como eventos
`KNOWLEDGE_BASE_SETUP_LOAD_SUCCESS/FAILURE`, `…QUERY_LOAD_…`,
`…ARTICLE_LOAD_…`, `…SYSTEM_MOTD_UPDATE`, `…SERVER_MESSAGE`.

Detalle que condiciona el diseño del addon: `OnLoad`, `OnShow` y `OnEvent`
del frame están enganchados con `<OnShow function="..."/>` (resueltos al
cargar el XML), mientras que los `OnClick` de botones e ítems llaman a las
funciones globales por nombre en el momento del clic. Por tanto el addon
sustituye los tres primeros con `SetScript` y redefine el resto de globales.

### Qué paquetes existen para la Knowledge Base

**Ninguno.** Y se demuestra por los dos lados:

- En `Wow.exe` (cadenas literales): `http://support.wow-europe.com/kb/`,
  `http://support.worldofwarcraft.com/kb/`, `http://support.worldofwarcraft.co.kr/kb/`,
  `http://support.wowtaiwan.com.tw/kb/`, `http://cn.kbase.blizzard.com/kb/wow/`,
  el nombre de fichero fuente `KnowledgeBase.cpp` y los nombres de los eventos
  `KNOWLEDGE_BASE_*`. El cliente elige la URL por región y hace la consulta
  **por HTTP**, fuera del socket del mundo.
- En `Opcodes.h` del core no hay ningún opcode con `KNOWLEDGE` ni `KB`. Lo que
  hay del sistema de ayuda son los de tickets (ver "Tickets: qué hay y qué no se toca") y `CMSG_GM_REPORT_LAG`.

Consecuencia: **no hay nada del protocolo de Blizzard que AzerothCore pueda
implementar** para la KB. Hoy, en tu servidor, la pestaña muestra
`KBASE_ERROR_LOAD_FAILURE` ("La ayuda básica no está actualmente disponible…")
porque la petición HTTP a `support.wow-europe.com` falla. No hay que
"implementar los paquetes que faltan": hay que sustituir la fuente de datos.

### Tickets: qué hay y qué no se toca

Opcodes implementados (`Opcodes.cpp:648-670`, `939-941`, `1393-1398`, `1413`):
`CMSG/SMSG_GMTICKET_CREATE`, `_UPDATETEXT`, `_GETTICKET`, `_DELETETICKET`,
`_SYSTEMSTATUS`, `SMSG_GM_TICKET_STATUS_UPDATE`, `CMSG_GMSURVEY_SUBMIT`,
`SMSG_GMRESPONSE_RECEIVED`, `CMSG_GMRESPONSE_RESOLVE`,
`SMSG_GMRESPONSE_STATUS_UPDATE`, `CMSG_GM_REPORT_LAG`, `CMSG_COMPLAIN`. Los
handlers están en `Handlers/TicketHandler.cpp` (300 líneas) y el estado en
`Tickets/TicketMgr`. Nada de eso pasa por la KB, y el diseño de abajo no
modifica ningún handler ni ningún frame de ticket: sólo la lógica Lua de la
página `KBase`, conservando sus botones de ticket.

### Cómo se registran los comandos

- Cada `CommandScript` (del core en `src/server/scripts/Commands/cs_*.cpp`, o
  de un módulo, por ejemplo `mod_party_here.cpp:981-991`) devuelve una
  `ChatCommandTable` = `std::vector<ChatCommandBuilder>`. Un builder es
  `{ "nombre", handler, SEC_x, Console::Yes/No }` o `{ "nombre", subTabla }`
  (`ChatCommand.h:218-247`).
- `ChatCommandNode::LoadCommandMap()` (`ChatCommand.cpp:82-133`) recoge
  **todas** con `sScriptMgr->GetChatCommands()`, monta un árbol por tokens
  (`"account set gmlevel"` → `account` → `set` → `gmlevel`; mapa
  case-insensitive) y después lee la tabla `command` (`SELECT name, security,
  help FROM command`, `WorldDatabase.cpp:81`): si la fila existe, **su
  `security` sobreescribe el del código** (con aviso) y su `help` pasa a ser el
  texto de ayuda. Filas para comandos inexistentes se ignoran con error.
- `ResolveNames` (`ChatCommand.cpp:135-150`) deja en cada nodo `_name` con la
  ruta completa. Un comando sin ayuda genera el aviso `Table 'command' is
  missing help text for command 'x'` que ya ves en el arranque para los
  comandos de módulos.
- El mapa se construye la primera vez que alguien lo necesita
  (`GetTopLevelMap`, `ChatCommand.cpp:69-75`) y `.reload command` lo
  invalida.

**Los comandos de módulos son indistinguibles de los del core**: mismo árbol,
mismo filtro. Cualquier módulo que registre un `CommandScript` aparece solo.

### Cómo se determina el permiso de cada comando

- Niveles: `SEC_PLAYER = 0`, `SEC_MODERATOR = 1`, `SEC_GAMEMASTER = 2`,
  `SEC_ADMINISTRATOR = 3`, `SEC_CONSOLE = 4` (`src/common/Common.h:55-62`). El
  nivel de la cuenta está en `WorldSession::GetSecurity()` (`WorldSession.h:486`)
  y sale de `account_access` (es lo que cambia `.account set gmlevel`).
- Cada nodo guarda `CommandPermissions { RequiredLevel, AllowConsole }`
  (`ChatCommand.h:160-166`).
- La decisión es `ChatCommandNode::IsInvokerVisible(who)` (`ChatCommand.cpp:453-471`),
  en este orden: sin invocador → no; hook `OnBeforeIsInvokerVisible` (si un
  módulo devuelve `false`, el comando pasa a ser visible); consola;
  `RequiredLevel >= 200` → permiso **RBAC** de la cuenta
  (`WorldSession::HasPermission`, `WorldSession.cpp:1709`); si no,
  `who.IsAvailable(RequiredLevel)` = `GetSecurity() >= RequiredLevel`
  (`Chat.cpp:52-56`).
- Un nodo "se ve" si es invocable **o** tiene algún hijo visible
  (`IsVisible`, `ChatCommand.h:197`): por eso `.account` aparece a un jugador
  aunque `.account set gmlevel` no.
- **La ejecución vuelve a comprobarlo**: `TryExecuteCommand` sólo invoca si
  `cmd->IsInvokerVisible(handler)` (`ChatCommand.cpp:301`). Saber que un
  comando existe no da permiso para usarlo; la KB no puede convertirse en una
  vía de escalada porque no toca este camino.
- Tu `worldserver.conf` tiene `AllowPlayerCommands = 1` (valor del dist):
  con `0`, `_ParseCommands` (`Chat.cpp:236-248`) sigue ejecutando los comandos
  `SEC_PLAYER`; sólo oculta el mensaje "comando desconocido".

### Cómo recorrer el árbol desde un módulo (sin parchear)

Todo lo interno es privado: `GetTopLevelMap()` es `private static`, los
miembros de `ChatCommandNode` son privados y `ChatCommandBuilder` sólo tiene
como `friend` a `ChatCommandNode` (`ChatCommand.h:170-208`, `218-247`). No hay
forma legítima de iterar el mapa directamente. Pero la API pública
(`ChatCommand.h:250-256`) basta:

| Función pública | Qué da | Cómo la usamos |
|---|---|---|
| `GetAutoCompletionsFor(ChatHandler const&, "ruta")` (`ChatCommand.cpp:378-451`) | Los **hijos visibles para ese handler** de la ruta dada, ya con el filtro de permisos del core (`FilteredCommandListIterator`, que descarta lo no visible). Con `""` da los comandos de primer nivel; con `"account"` da `account 2fa`, `account addon`, …; con un comando hoja da lista vacía | Recorrido en anchura desde `""` con el `ChatHandler` **de la sesión del jugador** → árbol completo de lo que ese jugador puede ver, filtrado por el propio core |
| `SendCommandHelpFor(ChatHandler&, "ruta")` (`ChatCommand.cpp:308-373`) | Envía la ayuda por `SendSysMessage`: el texto de `command.help` (o el `AcoreStrings` del código) si el nodo es invocable para ese handler, y la lista de subcomandos visibles | Un `ChatHandler` derivado que **capture** `SendSysMessage` y `GetAcoreString` (los dos son `virtual`, `Chat.h:129-130`; `CliHandler` ya lo hace) recoge el texto sin que llegue al chat, y distingue "invocable con ayuda", "invocable sin ayuda" (`LANG_CMD_HELP_GENERIC` + `LANG_CMD_NO_HELP_AVAILABLE`, ids 195/196) y "sólo contenedor" (`LANG_CMD_HELP_GENERIC` + `LANG_SUBCMDS_LIST`, id 8) |
| Hook `AllCommandScript::OnBeforeIsInvokerVisible(std::string name, CommandPermissions permissions, ChatHandler const& who)` (`AllCommandScript.h`, `ChatCommand.cpp:458`) | **Recibe el nombre completo y el `RequiredLevel` de cada nodo cada vez que el core evalúa su visibilidad**, es decir, durante el recorrido anterior | Un `AllCommandScript` del módulo que apunta `nombre → nivel` (y devuelve `true` para no alterar nada) da el permiso exacto de cada comando, incluidos los RBAC (≥ 200), sin acceder a nada privado |

Lo que **no** se puede hacer y por qué no hace falta: `IsAvailable` y
`HasPermission` de `ChatHandler` no son virtuales (`Chat.h:283-284`), así que
no se puede simular "¿qué vería un GM?" desde la sesión de un jugador. No hace
falta: cada jugador recibe su propio recorrido con su propia sesión, y la
etiqueta "Permiso: Jugador / Moderador / GM / Administrador" sale del hook.

### Cómo hablan cliente y servidor sin opcodes nuevos

El cliente 3.3.5a no admite opcodes nuevos sin parchear `Wow.exe`, y **tu
ejecutable no está parcheado** (comprobado: de los siete patrones que cambia el
`patch-004-allow_interface_edit.bat` que viene con el cliente ChromieCraft, los
siete están en su forma original). Descartado.

Lo que sí existe es el canal de addon, y en este core viene con un protocolo de
comandos ya hecho:

1. El addon envía `SendAddonMessage("AzerothCore", cuerpo, "WHISPER", miNombre)`.
   Llega como `CMSG_MESSAGECHAT` tipo `WHISPER`, idioma `LANG_ADDON`.
2. `HandleMessagechatOpcode` (`Handlers/ChatHandler.cpp`): admite `LANG_ADDON`
   sólo en `PARTY/RAID/GUILD/BATTLEGROUND/WHISPER` y si `AddonChannel = 1`
   (líneas 186-210; tu dist lo trae a 1, `worldserver.conf.dist:4293`);
   rechaza mensajes de más de **255 bytes** (línea 292); los mensajes de addon
   **no pasan por el antiflood** (`UpdateSpeakTime` sólo en la rama no-addon,
   línea 249) ni por el filtro de caracteres (línea 320).
3. Línea 300-304: si es `LANG_ADDON`, antes de cualquier otra cosa se llama a
   `AddonChannelCommandHandler(this).ParseCommands(msg)`. Ese handler
   (`Chat.cpp:1063-1163`) reconoce el cuerpo `"AzerothCore\t" + opcode +
   contador(4) + comando`:
   - `p` ping → responde `a` (ack);
   - `i` (o `h`, "legible") → ejecuta el comando con `_ParseCommands`, es
     decir **el mismo camino que el chat**, con la sesión y permisos reales;
   - cada `SendSysMessage` del comando se reenvía como susurro `LANG_ADDON` a
     uno mismo con cuerpo `"AzerothCore\tm" + contador + línea` (una por `\n`,
     `Chat.cpp:1143-1162`), y al terminar `o` (ok) o `f` (falló).
   El cliente recibe cada uno como evento `CHAT_MSG_ADDON` con prefijo
   `"AzerothCore"`, cuerpo, canal `"WHISPER"` y tu propio nombre.
4. Como el handler devuelve antes del `switch` de tipos, la rama de susurros
   (nivel mínimo, facción, whitelist, `Player::Whisper`, hooks de playerbots)
   **no se ejecuta**.

Conflictos revisados con lo instalado: `mod-playerbots` ignora los mensajes
`LANG_ADDON` en su hook de susurros ("Other addon messages should not command
bots"); `mod-dungeon-clear` intercepta sólo el prefijo `"DC\t"` y lo hace en
`OnPlayerBeforeSendChatMessage`, que se evalúa **después** (línea 367) del
handler de addon; ningún otro módulo (transmog, ah-bot-plus,
individual-progression, 1v1, autobalance, los seis propios) toca `LANG_ADDON`
ni `OnBeforeIsInvokerVisible`.

Dos consecuencias prácticas: el módulo no necesita ningún hook de chat, sólo
registrar un comando normal (`.ayuda …`), que además funciona tecleado en el
chat; y cada línea de respuesta cabe en unos 235 bytes útiles
(255 − 17 de cabecera − margen), así que el servidor trocea.

### Qué se puede modificar en el cliente

| Vía | Requiere | Estado |
|---|---|---|
| Sustituir `KnowledgeBaseFrame.lua/.xml` en un MPQ propio | `Wow.exe` parcheado (`patch-004`); en cada PC | Descartada: tu exe no lo está y no hace falta |
| **AddOn** en `Interface\AddOns\` | Nada. Se carga después de todo `FrameXML` (`FrameXML.toc:115-116` carga `HelpFrame.xml` y `KnowledgeBaseFrame.xml`), puede hacer `SetScript` sobre `KnowledgeBaseFrame` y redefinir sus funciones globales; ninguna de ellas es protegida | **Elegida**. Igual que `unbot-addon` y el addon de dungeon-clear que ya usas |

El addon **no crea una ventana nueva**: usa el `KnowledgeBaseFrame` de
Blizzard tal cual (texturas `Interface\HelpFrame\*`, `GameFontNormal`,
`UIPanelScrollFrameTemplate`, `UIDropDownMenuTemplate`, `GameMenuButtonTemplate`),
así que la apariencia es exactamente la del cliente original. Lo que cambia:
los desplegables pasan a ser "Categoría / Subcategoría" de tu servidor, "Más
leídos" pasa a "Categorías" (o "Inicio"), la lista muestra artículos y
comandos, y el artículo muestra la ficha del comando.

---

## Ficheros de configuración y logs

| Fichero | Qué configura |
|---|---|
| `etc/worldserver.conf` | Core: BD, reino, tasas, facciones, rendimiento, logs |
| `etc/authserver.conf` | BD de autenticación |
| `etc/modules/playerbots.conf` | Bots |
| `etc/modules/mod_queue_bots.conf` | Colas con bots (módulo propio) |
| `etc/modules/mod_server_help.conf` | La ayuda del servidor en el cliente (módulo propio; los textos van en la BD) |
| `etc/modules/mod_standby.conf` | Modo en espera (módulo propio; sólo con `WORLDSERVER_STANDBY`) |
| `etc/modules/mod_treasure.conf` | SP03: estancia de 3600 s, reposición individual, validación automática y bengala al aparecer |
| `etc/modules/AutoBalance.conf` | Escalado de instancias |
| `etc/modules/individualProgression.conf` | Progresión |
| `etc/modules/mod_ahbot.conf` | Casa de subastas |
| `etc/modules/transmog.conf` | Transmogrificación |
| `etc/modules/random_enchants.conf` | Encantamientos aleatorios |
| `etc/modules/mod_congratsonlevel.conf` | Recompensas por nivel (los premios van en la BD) |
| `etc/modules/mod_dungeon_master.conf` | Mazmorras procedurales |
| `etc/modules/challenge_modes.conf` | Desafíos |
| `etc/modules/mod-instanced-worldbosses.conf` | Jefes de mundo |
| `etc/modules/mod_aq_war_effort.conf` | Esfuerzo de guerra |
| `etc/modules/{RacialTraitSwap,reagent_bank,mod_aoe_loot,instance-reset,1v1arena}.conf` | Servicios |

Los logs del servidor están en `~/azerothcore/env/dist/bin/`: `Server.log`,
`Playerbots.log` y `Errors.log`, con hora y nivel en cada línea.

### Tesoros itinerantes (SP03)

El módulo propio `mod-treasure` usa `sp_treasure_zone` (cuotas y habilitación),
`sp_treasure_point` (candidatos y resultado de ruta) y `sp_treasure_slot`
(destino, anterior, plazo y reposición) en `acore_world`. Las entradas de cofre
son `700000 + zone_id * 3 + calidad`; sólo tienen botín propio de su zona.
Un GM puede consultar `.tesoro estado`, validar cerca de sí con `.tesoro validar`
y habilitar o retirar cofres con `.tesoro activar/desactivar`.
Las 57 zonas están activas; el primer humano cercano activa la validación
acotada de candidatos antes de que se asigne un cofre. Detalle operativo en
«mod-treasure: tesoros itinerantes (SP03)» (REFERENCES.md).

---

## Escribir un módulo propio: reglas

Módulos de C++ escritos para este servidor. No se clonan de GitHub: viven aquí y
la fase 3 los copia a `~/azerothcore/modules/` con `install_own_modules()`, en
`lib/utils.sh`, para que CMake los compile como uno más.

**Por qué aquí y no en `patches/`:** un parche modifica código de terceros y hay
que regenerarlo cada vez que el upstream toca esas líneas. Un módulo propio no
toca nada ajeno, así que ninguna actualización puede romperlo ni borrarlo. Si un
comportamiento se puede conseguir con un módulo aparte, va aquí; sólo cuando hay
que cambiar código ajeno se escribe un `.patch`.

### Qué hay

| Módulo | Qué hace | Se activa con |
|---|---|---|
| `mod-queue-bots/` | Rellena con bots la cola en la que te pones: 1c1, campo de batalla, arena, mazmorra y banda. `.queuebots` muestra el estado, fuerza una pasada o saca los bots | `INSTALL_MOD_QUEUE_BOTS` |
| `mod-world-bots/` | Que tu zona no esté vacía: trae bots de tu tramo de nivel a puntos de caza lejos de ti (y a las capitales, delante de sus NPC), y repone mientras sigues allí. `.wbots estado`/`aqui` para verlo o forzarlo; modo "buen samaritano" opcional (`.wbots samaritano off` para rechazarlo). Incluye la guerra de mundo y el diagnóstico transversal `.bots estado` | `INSTALL_MOD_WORLD_BOTS` |
| `mod-quest-mates/` | Compañeros de misión: al aceptar una misión, dos o tres bots de tu zona la cogen también | `INSTALL_MOD_QUEST_MATES` |
| `mod-party-here/` | Grupo donde estás, sin cola: `.grupo`, `.grupo banda`, y misiones de grupo en automático. Sincroniza tus misiones a tus compañeros mientras lo sean (SP05) | `INSTALL_MOD_PARTY_HERE` |
| `mod-home-guild/` | Tu hermandad creada manualmente: bots que se conectan contigo, siguen tu nivel y van primero en las colas; nunca crea ni adopta guilds por su cuenta | `INSTALL_MOD_HOME_GUILD` |
| `mod-update-notice/` | Aviso de versiones nuevas a los GM al entrar; `.actualizaciones` |
| `mod-standby/` | Modo en espera: apaga el worldserver (salida limpia, código 0) cuando lleva `Standby.IdleMinutes` sin sesiones humanas, para que la VM no gaste CPU ni RAM con los bots mientras nadie juega. Sólo actúa si el proceso lo lanzó systemd por activación de socket. `.standby` | `INSTALL_MOD_STANDBY` (sigue a `WORLDSERVER_STANDBY`) | `INSTALL_MOD_UPDATE_NOTICE` |
| `mod-server-help/` | La pestaña de ayuda del cliente con los comandos que la cuenta puede usar (core y módulos, descubiertos solos), fichas y artículos en español; `.ayuda`. Va con el addon `cliente/Interface/AddOns/ServerHelp` | `INSTALL_MOD_SERVER_HELP` |
| `mod-progression-skip/` | NPC neutral "Cronista de las Eras": deja **avanzar** de forma irreversible en `mod-individual-progression` (saltar Vanilla → etapa 8, Terrallende → 13, todo → 18) sin recompensas ni logros. Depende de `mod-individual-progression` con guarda `__has_include`. Aparece en Gadgetzan, Bahía del Botín, Shattrath y Dalaran | `INSTALL_MOD_PROGRESSION_SKIP` (+ `INSTALL_MOD_INDIVIDUAL_PROGRESSION`) |
| `mod-treasure/` | Cofres por zona que rotan tras saquearse o vencer su ubicación; catálogo de destinos filtrado por suelo, visión y ruta de mmaps. Zonas activables sólo tras validar puntos suficientes; `.tesoro` | `INSTALL_MOD_TREASURE` |
| `mod-arac-trainer-audit/` | Log de compras y veto de raza/clase mediante hooks del core. Refresco opcional tras comprar en el instructor genérico de druida (26324), como mitigación del bloqueo Feral pendiente de validar en juego. No añade hechizos ni toca `trainer_spell`. Ver «mod-arac-trainer-audit: auditoría de entrenadores» | `INSTALL_MOD_ARAC_TRAINER_AUDIT` |
| `mod-bot-operations/` | Puente entre `BotOperations.h` y MySQL (`acore_world`) para el panel web: publica una instantánea de colas/mundo-etapa/grupos/hermandades/compañeros de misión/reservas cada 10 s (`bot_operations_snapshot`) y procesa una cola de acciones seguras y limitadas (`bot_operations_action`) — adelantar una pasada normal, parar un evento PvP de mundo atascado, refrescar la instantánea. No ofrece ningún comando de juego ni interpreta texto de SOAP | `INSTALL_MOD_BOT_OPERATIONS` |
| `mod-adaptive-ai/` | **Archivado/desactivado** desde 06/09/2026: la fase 3 lo mueve a `modules-disabled/`, por lo que no se compila ni carga. El último entrenamiento exportado queda en `data/entrenado/`; las lecciones y motivo de la pausa están en `CHANGELOG.md` | `INSTALL_MOD_ADAPTIVE_AI=false` |
| `shared/` | Cabeceras compartidas (`BotClaims.h`, `BotGear.h`, `BotWake.h`, `BotWorldAge.h`, `BotPopulationCoordinator.h`, `TimeMs.h`): el instalador las copia a `src/` de cada módulo | — |

### Reglas

1. **API del núcleo por defecto.** Incluir cabeceras de otro módulo convierte el
   nuestro en un parche encubierto, con la misma fragilidad. Si hace falta un
   dato de otro módulo, se copia la constante y se documenta de dónde sale (ver
   la cabecera de `mod-queue-bots/src/mod_queue_bots.cpp`).

   **Cuando no queda otra**, la excepción se escribe así, y sólo así:

   ```cpp
   #if defined(__has_include)
   #  if __has_include("PlayerbotAI.h")
   #    include "PlayerbotAI.h"
   #    define QUEUE_BOTS_WITH_PLAYERBOTS 1
   #  endif
   #endif
   ```

   Con la guarda, si el módulo ajeno no está el nuestro sigue compilando y sólo
   pierde esa función. Y si cambian la firma, **falla la compilación con un error
   claro**, que es infinitamente mejor que dejar de funcionar en silencio. Cada
   excepción lleva encima un comentario explicando por qué no había alternativa.
   Las que hay: `ResetStrategies()`, `AddPlayerBot()`, `LogoutPlayerBot()` y
   —para adoptar al amo de la banda del buscador, igual que `mod-party-here`—
   `SetMaster()`, `ChangeStrategy()` y `Reset()` en `mod-queue-bots`; en
   `mod-world-bots`, además, `IsRandomBot()`, `Reset()` y
   `HasPlayerNearby()` — las dos últimas porque la función de teletransporte de
   playerbots es privada y hay que repetir su secuencia — y `rpgInfo.ChangeTo*()`
   (miembro público de `PlayerbotAI`) para que el bot no se vuelva a donde iba;
   en `mod-quest-mates`, `IsRandomBot()` y `rpgInfo.ChangeToDoQuest()`, que es
   lo que hace su comando `rpg status do quest`; en `mod-party-here`,
   `PlayerbotFactory::InitTalentsBySpecNo()`, `InitGlyphs()` y las plantillas
   `premadeSpecName`/`parsedSpecLinkOrder` de `PlayerbotAIConfig` para poner a
   un bot en el rol que falta (M26), que es lo que hace su comando
   `talents spec <nombre>`.

2. **Estructura estándar de AzerothCore:** `src/` con un `*_loader.cpp` que
   define `Add<nombre_del_modulo>Scripts()` (los guiones del nombre de la carpeta
   pasan a ser guiones bajos), y `conf/` con su `.conf.dist`.

3. **Toda opción va al `.conf.dist`** y se fija desde la fase 5 con
   `set_conf_value`, como con cualquier módulo de terceros.

4. **La cabecera del `.cpp` explica el problema**, no sólo la solución: por qué
   existe el módulo, qué pasaba sin él y qué comparte con quién.

5. **El trabajo que toca a bots de otros mapas se hace en `WorldScript::OnUpdate`**,
   no en un hook de `PlayerScript`. Los hooks de jugador corren en el hilo del
   mapa de ese jugador, y con cuatro hilos de mapas tocar desde ahí a un bot de
   otro mapa es una carrera. `OnUpdate` del mundo corre cuando ningún mapa se
   está actualizando. Si un hook de jugador tiene que provocar algo, que apunte
   la petición (con su candado) y la atienda `OnUpdate`: así lo hace
   `mod-world-bots`. `mod-queue-bots` aplica la misma regla: `OnPlayerUpdate`
   sólo publica el GUID y el tipo de evento; el hilo del mundo resuelve el
   jugador y hace todo el trabajo.

   **Comandos y `.reload config` corren en el hilo del mundo, con los mapas
   parados** (comprobado en el core fijado, M05, 24/09/2026). `CMSG_MESSAGECHAT`
   es `PROCESS_THREADUNSAFE` (`Opcodes.cpp`): `MapSessionFilter` lo rechaza y
   sólo lo procesa `World::UpdateSessions`. La consola y SOAP pasan por
   `World::ProcessCliCommands`. Los dos van en `World::Update` fuera de
   `sMapMgr->Update`, que termina con `m_updater.wait()`. Por tanto
   `OnAfterConfigLoad`, los `CommandScript` y `WorldScript::OnUpdate` nunca se
   solapan entre sí ni con un hook de mapa: `cfg` puede ser un POD normal y las
   transiciones de un `.reload config` (vaciar colecciones, soltar reservas)
   pueden hacerse dentro del propio `OnAfterConfigLoad`. Lo que sí corre en
   paralelo son los hooks de **mapas distintos** entre sí (y la actualización
   de LFG que el core lanza en el mismo lote que los mapas). La premisa
   contraria de T7 (CHANGELOG) era falsa; sus espejos atómicos se quedan porque
   no cuestan nada. Si una actualización del core cambia el `ProcessingPlace`
   de `CMSG_MESSAGECHAT` o el orden de `World::Update`, hay que revisar esto.

6. **Cabeceras compartidas en `modules/shared/`.**
   - `BotClaims.h` — registro "este bot es de tal módulo" y los bots de tu
     hermandad. Lectores/escritores con `std::shared_mutex`.
   - `BotEligibility.h` — el núcleo de `IsFreeBot` que comparten
     `mod-queue-bots`, `mod-party-here` y `mod-world-bots` (los dos ficheros):
     en el mundo, sesión de bot ya cargada, vivo, sin combate/vuelo/teletransporte
     en curso, sin banda/cola/grupo/LFG y fuera de mazmorra o campo de
     batalla/arena. Nace de que estas comprobaciones habían divergido con el
     tiempo entre módulos (P1, 13/09/2026): `mod-queue-bots` no
     comprobaba `PlayerLoading()` ni `IsBeingTeleported()`. Lo que sigue siendo
     propio de cada módulo (criterio de propiedad de `BotClaims`, antigüedad
     mínima, exclusión de la hermandad, `IsRandomBot`) se queda en cada
     `IsFreeBot`, justo después de llamar a ésta. También trae `IsHuman`
     (sesión que no es de bot, en el mundo): antes de esta cabecera era una
     copia byte a byte idéntica en `mod-home-guild`, `mod-party-here`,
     `mod-quest-mates` y los dos ficheros de `mod-world-bots` (P2, misma fecha).
   - `BotGear.h` — tope de equipo de los bots que entran en tu grupo, con cola
     acotada y presupuesto global por tick.
   - `BotWake.h` — selección indexada de bots dormidos (evita `ORDER BY RAND()`);
     admite filtro de clase para despertar candidatos a un rol (M26).
   - `BotWorldAge.h` — guarda de asentamiento tras login (no mover un bot con
     < N s en el mundo). Antigüedad (`firstSeen`) y última consulta
     (`lastSeen`, sólo para podar) van separadas, y `Forget()` desde
     `OnPlayerLogout` (party-here, home-guild, world-bots) reinicia la espera
     aunque la sesión nueva reutilice la dirección de la anterior (M08).
   - `BotPopulationCoordinator.h` — recuento de online, reservas de login y
     presupuestos por facción/tramo.
   - `BotOperations.h` — buzón de dos direcciones entre `mod-queue-bots`,
     `mod-world-bots`, `mod-party-here`, `mod-quest-mates`, `mod-home-guild` y
     `mod-bot-operations`: cada productor publica su struct de estadísticas
     (`Publish*`) desde su propio `OnUpdate`, y `mod-bot-operations` la lee
     con `GetSnapshot()` y la escribe en `acore_world` para el panel. Las
     acciones van al revés: `mod-bot-operations` encola con
     `EnqueueRequest()` contra el `Target` que corresponde, el módulo destino
     la recoge con `TakeRequests()` -swap+drain, como ya hacían por su cuenta-
     y publica el resultado con `ReportOutcome()`. `std::mutex`. Desde M07
     (24/09/2026) el buzón está acotado (`kMaxInbox`, 32 por destino), cada
     solicitud caduca con su fila, `TakeRequests(target, now)` renueva el
     latido del destino y un destino apagado llama a `SetTargetOffline` en su
     rama de apagado (y publica una última estadística con `enabled=false`):
     `EnqueueRequest` devuelve `Full`/`Unavailable` en vez de encolar sin
     límite, y el puente retira con `CancelRequest` lo que da por caducado.
     Un módulo que se apaga retira sus reequipados con
     `BotGear::CancelOwnedBy(OWNER)` (M06).
   - `TimeMs.h` — reloj de 64 bits (`NowMs()` para plazos, `SteadyNowMs()` para
     perfilar dentro del tick). Puro, sin estado: no hay ODR que cuidar.
   - `SharedAbi.h` — la versión ABI, ÚNICA para toda la carpeta (antes
     `BotClaims.h` y `BotOperations.h` llevaban cada uno la suya, y un cambio
     en cualquier otra cabecera de `shared/` no subía ninguna de las dos; P2,
     13/09/2026).
   - `SlowTick.h` — `WarnIfSlow(modulo, paso, startMs)`: mismo umbral que el
     core para su "Update time diff" (100 ms), como mucho un aviso por
     (módulo, paso) y minuto. La usan `mod-bot-operations` y el `OnUpdate`
     principal de `mod-queue-bots`, `mod-party-here`, `mod-world-bots` (los
     dos ficheros), `mod-home-guild` y `mod-quest-mates`, además de
     `mod-adaptive-ai` (única copia hasta el P2, 13/09/2026, que
     la centralizó aquí). `WarnIfDeep(modulo, cola, size)` (P2 M52,
     26/09/2026) es la misma idea sobre la PROFUNDIDAD de una cola en vez de
     una duración (umbral 20, mismo "una vez por minuto"): la usan los
     `g_pending` de `mod-quest-mates`, `mod-party-here` y `mod-home-guild` al
     vaciarlos en cada `OnUpdate`.

   Los módulos no comparten *include path*, así que cada uno lleva **su copia**
   en `src/`: la pone `install_own_modules()` en la fase 3 desde
   `modules/shared/`, y las copias tienen que ser byte a byte idénticas (son
   funciones *inline* con estáticas locales: el enlazador las funde en una sola
   instancia para todo el worldserver, regla ODR). **Se edita sólo
   `modules/shared/`, nunca las copias**, que además no están en el repositorio.
   Un cambio en `shared/` obliga a recompilar **todos** los módulos que la
   incluyen. `SharedAbi::kSharedAbiVersion` se sube al tocar CUALQUIER cabecera
   de `shared/` y cada `*_loader.cpp` lo escribe en `Server.log` al cargar: si
   un despliegue parcial deja dos módulos con copias distintas, la deriva se ve
   ahí.

   Todo módulo que elija bots consulta `BotClaims::IsClaimed` (o
   `IsClaimedByOther`) en su `IsFreeBot`, adquiere un `BotClaims::Lease`,
   revalida el candidato y sólo conserva la reserva con `Keep()` después de
   actuar; el destructor cubre todos los caminos de error. A los
   `IsHomeGuildBot` no se les manda a dormir y se les prefiere al formar grupos.

### Añadir uno nuevo

1. Crear `modules/mod-loquesea/` con `src/` y `conf/`.
2. Añadir `INSTALL_MOD_LOQUESEA` a `config.sh`.
3. Añadirlo a la lista `OWN_MODULES` de `install_own_modules()` en `lib/utils.sh`.
4. Si tiene `.conf`, instalarlo en la fase 5 con `install_module_conf`.
5. Si elige bots, usar `BotClaims.h` (regla 6); si los mete en tu grupo, `BotGear.h`.
6. Recompilar: `./install.sh --from 3`.

## Escribir un parche sobre código de terceros

Todo lo que este servidor añade o corrige por encima de los módulos vive aquí,
**fuera** de `~/azerothcore/modules/`. Así una actualización de un módulo nunca
se lleva por delante nuestros cambios: la fase 5 los vuelve a aplicar y la fase 3
(y `lib/reapply-patches.sh`) vuelven a poner los parches de código.

### Qué hay

| Carpeta | Tipo | Cuándo se aplica | Fragilidad |
|---|---|---|---|
| `core/` | `.patch` de código (observadores de pesca) | Fase 3 y tras cada actualización | **Alta** |
| `mod-profession-experience/` | `.patch` de código y configuración | Fase 3 y tras cada actualización | **Alta** |
| `mod-guildhouse/` | `.patch` de código y SQL para SP02 (01) y SP07 (02, banquero de materiales) | Fase 3 y tras cada actualización | **Alta** |
| `mod-reagent-bank/` | `.patch` de código: menú y mensajes de Ling en español y paginación (SP07) | Fase 3 y tras cada actualización | **Alta** |
| `arac/` | SQL | Fase 5 y fase 8, tras el SQL de mod-arac | Baja |
| `locales-es/` | SQL | Fase 5 y fase 8 | Baja |
| `mod-random-enchants/` | `.patch` de código | Fase 3 y tras cada actualización | **Alta** |
| `mod-congrats-on-level/` | `.patch` de código | Fase 3 y tras cada actualización | **Alta** |
| `mod-challenge-modes/` | `.patch` de código | Fase 3 y tras cada actualización | **Alta** |
| `mod-playerbots/` | `.patch` de código | Fase 3 y tras cada actualización | **Alta** |
| `mod-aoe-loot/` | `.patch` de SQL (collation MySQL 8.4) y código (copias individuales de misión en área, SP04) | Fase 3 y tras cada actualización | **Alta** |
| `mod-quest-loot-party/` | `.patch` de código y SQL (solo grupo, textos esES/esMX, SP04) | Fase 3 y tras cada actualización | **Alta** |
| `mod-war-effort/` | `.patch` de SQL (instalación idempotente) | Fase 3 y tras cada actualización | Baja |

`apply_all_source_patches()` recorre las carpetas de módulos instalados y
`core/`. Esta última se aplica sobre `$AC_DIR` y sólo admite modificaciones
de ficheros versionados: ignora extras operativos sin seguimiento (logs,
scripts locales). El resto son colecciones de SQL aplicadas con `apply_sql_dir`.

`core/01-pesca-ejecutar-todos-los-hooks.patch` conserva los vetos a subir
habilidad, pero ejecuta todos los observadores de pesca para que la basura
también conceda la XP profesional configurada.

### Reglas

1. **Config antes que SQL, y SQL antes que parche de código.** Si el módulo
   expone la opción en su `.conf`, se pone en `config.sh` y se acabó. Sólo se
   escribe un `.patch` cuando no hay ninguna otra vía.
2. **Todo el SQL es idempotente**: borra sus propias filas antes de insertarlas.
   Relanzar la fase 5 no puede duplicar nada.
3. **Cada `.patch` lleva una cabecera** explicando el problema, la solución y
   **contra qué commit se escribió**. `git apply` ignora ese texto.
4. Los ficheros se aplican en orden alfabético: por eso van numerados `01-`,
   `02-`, ...

### Cuando un parche deja de aplicar

Pasa cuando el upstream toca las mismas líneas. La fase 3 lo dice claramente y
sigue adelante; el módulo se queda con su comportamiento original.

Para regenerarlo:

```bash
MOD=mod-congrats-on-level          # el que sea
cd ~/azerothcore/modules/$MOD

# 1. Ver qué cambió arriba
git log --oneline <commit_viejo>..HEAD -- <fichero_del_parche>

# 2. Aplicar el mismo cambio a mano sobre el código NUEVO
#    (la cabecera del .patch explica qué hay que conseguir)
nano src/...

# 3. Regenerar el parche y devolver el módulo a su estado limpio
git diff > ~/azerothcore-installer/patches/$MOD/01-<nombre>.patch
git checkout -- .

# 4. Comprobar que aplica y que se detecta como "ya aplicado"
git apply --check  ~/azerothcore-installer/patches/$MOD/01-<nombre>.patch
```

Después hay que **actualizar la cabecera del parche** con el commit nuevo, y
recompilar (`./install.sh --only 4`).

> Al regenerar con `git diff`, acuérdate de volver a pegar la cabecera
> explicativa encima del diff: `git diff` sólo escribe el diff.

Dos cosas más, aprendidas el 01/09/2026:

- **Si el parche añade claves de configuración, que las declare también en el
  `.conf.dist` del módulo** (hunk en `conf/`). Si no, la fase 5 las marcará como
  "no declaradas", y con razón. El de `mod-random-enchants` ya lo hace.
- Un parche que toca `conf/` además de `src/` **no se reaplica** sobre un módulo
  que ya tenga los hunks de `src/`: `apply_module_patches` (`lib/utils.sh`)
  sólo sabe "aplica entero" o "ya está entero", aunque desde el 05/09/2026
  entiende la pila del módulo (01, 01+02, ...) y avisa de "cambios que no
  corresponden a sus parches" sin tocar nada. Hay que devolver el módulo a limpio primero
  (`git -C ~/azerothcore/modules/<mod> checkout -- .`) y luego
  `bash lib/reapply-patches.sh`.
- Para regenerar un parche sin tocar la VM vale el mirror del commit fijado:
  `tar --force-local -xzf mirrors/<mod>@<commit>.tar.gz`, `git init`, commit,
  aplicar, editar, `git diff`. Así se hizo el de random-enchants.

### Rangos de identificadores propios

Para no chocar nunca con el core ni con los módulos:

| Qué | Rango | Dónde |
|---|---|---|
| GUID de los NPC de servicio | `MAX(guid)+1000` en adelante, calculado en cada instalación | `lib/utils.sh` → `spawn_service_npcs` |
| GUID de los personajes del bot de subastas | desde `AH_BOT_GUID_BASE` (9000001) | `config.sh` |
| GUID de criaturas colocadas por SQL fijo (no por `spawn_service_npcs`) | `8000101`–`8000199` — ARAC: `8000101`–`8000102`; Cronista de las Eras: `8000110`–`8000113` | `patches/arac/04-*.sql`, `modules/mod-progression-skip/data/sql/` |
| `creature_template.entry` / `npc_text.ID` propios | `≥ 600000` — objetos: `patches/custom-items/`; NPC Cronista de las Eras: `600200` (plantilla) y `600200`–`600202` (npc_text) | `modules/mod-progression-skip/data/sql/` |
| Textos traducidos | los identificadores que ya usa cada módulo, sólo con `locale` añadido | `patches/locales-es/` |

## Crear un objeto que no existe en 3.3.5a

Un `.sql` por objeto propio de `item_template` (`entry >= 600000`; ver
«Escribir un parche sobre código de terceros» (REFERENCES.md) → "Rangos de identificadores propios"). El instalador aplica
**todos** los `.sql` de este directorio en la fase 5 (y la 8 si la base aún no
existía), en orden alfabético y **antes** de `congrats_on_level_rewards.sql`.
Cada fichero es idempotente (borra su fila antes de insertarla).

| Fichero | Objeto |
|---|---|
| `600000-ganzua-de-recompensa.sql` | Ganzúa de recompensa: abre los cajones de pícaro de la capa de premios de niveles impares sin ser pícaro ni herrero. |
| `600001-piedra-de-la-sede.sql` | Piedra de la sede: acceso independiente de la piedra de hogar a la sede de la hermandad. |

### Cómo añadir un objeto propio

Un objeto propio toca **tres sitios**: la base de datos del servidor, dos
ficheros de datos del cliente y el catálogo del panel web. Esto explica qué
hace falta y en qué orden.

#### 1. El reparto: qué pone cada lado

| Cosa | De dónde sale | Dónde se define |
|---|---|---|
| Que el objeto **exista**, sus stats, `bonding`, hechizos, precio | Servidor (`item_template`) | `patches/custom-items/NNNNNN-*.sql` |
| **Nombre** y **descripción amarilla** (la de comillas) | Servidor (`item_template` + `item_template_locale`) | el mismo `.sql` |
| **Icono** en la bolsa y el tooltip | Cliente (`Item.dbc`) | `cliente/Data/{esES,enUS}/patch-<idioma>-4.MPQ` |
| **Línea verde "Uso: …"** (texto del hechizo del objeto) | Cliente (`Spell.dbc`) | el mismo MPQ |
| Que llegue al PC del jugador | `cliente/instalar-cliente.ps1` y el panel web | `cliente/manifest.tsv` + `web-panel/addons/patches.json` |

**Por qué el cliente:** el `Item.dbc` de un cliente 3.3.5a sólo llega al `entry`
~56806. Un objeto con `entry >= 600000` sale con una **"?" roja** de icono y, si
usa un hechizo prestado, con el texto de ese hechizo. Todo lo demás (nombre,
descripción, mecánica) lo manda el servidor y no necesita parche.

#### 2. Rango de identificadores

**Objetos propios: `entry >= 600000`.** El `MAX(entry)` del core es 57576 y no
hay nada por encima de 100000. Ver «Escribir un parche sobre código de terceros» (REFERENCES.md) → "Rangos de
identificadores propios" para el resto de rangos del proyecto (NPC, GUID,
textos). Elige el siguiente `entry` libre (600000, 600001, …).

#### 3. Paso a paso

##### 3.1. Servidor — `patches/custom-items/NNNNNN-nombre.sql`

Un fichero por objeto, **idempotente** (borra su fila antes de insertarla). Lo
más limpio es **clonar** un objeto parecido del core con una tabla temporal y
sobrescribir sólo lo que cambia — así un cambio de esquema del core aguas arriba
no lo rompe:

```sql
DELETE FROM `item_template` WHERE `entry` = 600001;

DROP TEMPORARY TABLE IF EXISTS `_tmp600001`;
CREATE TEMPORARY TABLE `_tmp600001` SELECT * FROM `item_template` WHERE `entry` = <ORIGEN>;
UPDATE `_tmp600001` SET
    `entry`     = 600001,
    `name`      = 'Nombre base en inglés',
    `Quality`   = 1,
    -- … lo que cambie …
    `VerifiedBuild` = 0;
INSERT INTO `item_template` SELECT * FROM `_tmp600001`;
DROP TEMPORARY TABLE `_tmp600001`;

DELETE FROM `item_template_locale` WHERE `ID` = 600001;
INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`, `VerifiedBuild`) VALUES
    (600001, 'esES', 'Nombre en español', 'Descripción amarilla.', 0),
    (600001, 'esMX', 'Nombre en español', 'Descripción amarilla.', 0);
```

Trampas conocidas:

- **`RequiredSkill` bloquea el USO, no sólo equipar.** `Player::CanUseItem`
  (`src/server/game/Entities/Player/PlayerStorage.cpp`) rechaza con
  `EQUIP_ERR_NO_REQUIRED_PROFICIENCY` a quien no tenga esa habilidad. Por eso
  las *Skeleton Key* de herrería no las puede usar un no-herrero: hay que clonar
  con `RequiredSkill = 0` y `RequiredSkillRank = 0`.
- **`bonding = 1`** (ligado al recoger) impide intercambio, correo a terceros y
  subasta. Es lo normal para un premio del servidor.
- **`item_template` no se recarga en caliente.** Después de aplicar el SQL hay
  que **reiniciar el worldserver** (`sudo systemctl restart ac-worldserver`).
- Añade una fila a la tabla de arriba.

Se aplica solo en cada `./install.sh --only 5` y `--only 7` (fase 8):
`apply_sql_dir` recorre todo `patches/custom-items/`. A mano:

```bash
mysql -u acore -pacore acore_world < patches/custom-items/NNNNNN-nombre.sql
```

##### 3.2. Cliente — regenerar los MPQ

1. Edita `tools/construir-parche-cliente-items.py`:
   - `ITEMS`: una fila `entry: (class, subclass, sound_override(-1), material, displayid, inv_type, sheathe)`.
     El `displayid` es el de un objeto del core que tenga el icono que quieres
     (búscalo con `SELECT displayid FROM item_template WHERE entry = …`, o por
     el nombre en `item_template_locale`).
   - `SPELL_DESC` (sólo si el objeto usa un hechizo con texto molesto): `spellid: {0: 'texto enUS', 6: 'texto esES'}`.

2. Regenera (necesita `pip install mpyq`):

   ```bash
   python tools/construir-parche-cliente-items.py --cliente "<cliente>"
   ```

   Escribe `cliente/Data/esES/patch-esES-4.MPQ` y `cliente/Data/enUS/patch-enUS-4.MPQ`.
   Con `--instalar` los copia también a la carpeta del cliente (cierra el WoW
   primero: si está abierto, bloquea el fichero).

   > El script lee los DBC **pristinos** del cliente (`patch-<idioma>-3.MPQ`) y
   > vuelve a meter todo lo propio en cada ejecución — es acumulativo por
   > diseño. **Si ChromieCraft actualiza sus DBC hay que regenerar**: si no, se
   > pierde lo que trajera ese parche.

3. **Actualiza el `sha256` de los dos MPQ** en `web-panel/addons/patches.json`
   (si no, el panel no arranca — `patches.js` valida el hash al cargar):

   ```bash
   sha256sum cliente/Data/esES/patch-esES-4.MPQ cliente/Data/enUS/patch-enUS-4.MPQ
   ```

   El catálogo lo quiere en MAYÚSCULAS.

Por qué `Data/<idioma>/` y ese nombre: esos DBC los trae también
`patch-<idioma>-3.MPQ` del cliente, así que sólo un `patch-<idioma>-4.MPQ` en la
carpeta del idioma los pisa (el Wow.exe carga `patch-%s-4.MPQ`, comprobado en el
binario). Un `Data/patch-4.MPQ` genérico NO vale: los parches de idioma mandan
sobre los genéricos.

Este mismo `patch-<idioma>-4.MPQ` también lleva desde el 21/09/2026 los tres
DBC de ARAC (`CharBaseInfo.dbc`, `CharStartOutfit.dbc`,
`SkillRaceClassInfo.dbc`). Antes iban en `Data/Patch-Arac.MPQ`, plano en
`Data/`: se creía válido porque ningún otro parche del cliente trae esos tres
ficheros, pero **el nombre nunca lo cargó el Wow.exe** — el cargador de
`Data/` exige un único carácter tras `"patch-"` (`patch-?.MPQ`), y `"Arac"`
no encaja; sin colisión de contenido no basta si el nombre no encaja con el
patrón. Ver «El cliente» (INSTALL_ES.md, parte 5) y `CHANGELOG.md` (tarea E1g) para
el diagnóstico completo por desensamblado. `tools/construir-parche-cliente-
items.py` los funde ahora en `patch-<idioma>-4.MPQ` igual que el resto de
este apartado.

##### 3.3. Distribución del cliente — ya está enganchado

- `cliente/manifest.tsv` ya tiene las dos entradas: `cliente/instalar-cliente.ps1`
  las copia a `Data/esES/` y `Data/enUS/`.
- `web-panel/addons/patches.json` ya tiene las dos entradas (con `targetDir`):
  el botón "Instalar parches" del panel las deja en su subcarpeta.

Un objeto nuevo **no** añade ficheros aquí: reaprovecha los dos mismos MPQ. Sólo
hay que regenerarlos (3.2) y actualizar sus `sha256` en el catálogo del panel.

#### 4. Desplegar en la VM

```bash
# Servidor (el SQL)
pscp patches/custom-items/*.sql  acore@IP:/home/acore/azerothcore-installer/patches/custom-items/
plink acore@IP "mysql -uacore -pacore acore_world < /home/acore/azerothcore-installer/patches/custom-items/NNNNNN-nombre.sql"
plink acore@IP "sudo systemctl restart ac-worldserver"     # item_template no se recarga en caliente

# Panel (el catálogo y los MPQ)
pscp -r web-panel/  acore@IP:/home/acore/azerothcore-installer/web-panel/
pscp -r cliente/Data/ acore@IP:/home/acore/azerothcore-installer/cliente/Data/
plink acore@IP "cd /home/acore/azerothcore-installer && sudo bash web-panel/deploy/install.sh"
```

`web-panel/deploy/install.sh` hace `rsync` de `cliente/Data/` a
`/opt/azerothcore-panel/addons/data/` (recursivo: se lleva las subcarpetas de
idioma) y reinicia `azerothcore-panel`.

En el PC del jugador: volver a pasar por el panel ("Instalar parches") o por
`instalar-cliente.ps1` — los dos **borran solos `Cache/`** después de copiar el
MPQ (si no, el cliente sigue enseñando datos cacheados) — y reiniciar el WoW.
Si el WoW estaba abierto, `Cache/` no se puede borrar: ciérralo y repite.

#### 5. Verificar

| Qué | Cómo |
|---|---|
| El objeto existe en el servidor | `SELECT entry,name,displayid FROM item_template WHERE entry=NNNNNN;` |
| Se puede usar | `.additem NNNNNN` sobre un personaje de prueba y usarlo |
| El MPQ lleva la fila | `python -c "..."` con `mpyq`, o mirar el log del script |
| El panel acepta el catálogo | `cd web-panel && node --test test/addons.test.js` |
| En el juego | icono correcto, nombre y descripción en español, línea "Uso:" con el texto propio |

#### 6. Anota el cambio

`CHANGELOG.md` (arriba, con fecha de la VM), y si el objeto es una mecánica
nueva y no sólo un premio, su diseño en `REFERENCES.md`.

## Parches de addons de cliente (`patches-cliente/`)

Igual que `patches/` (ver «Escribir un parche sobre código de terceros») guarda los cambios propios sobre
módulos de servidor, esta carpeta guarda los cambios propios sobre **addons de
cliente** (WoW Lua) de terceros que vivimos vendorizados en
`cliente/Interface/AddOns/<Nombre>/`. La diferencia importante: **nada de aquí
se aplica solo**. `install.sh` no la toca — es solo referencia y ayuda de
memoria para cuando toque fusionar una actualización con un agente de IA.

### Qué hay

| Carpeta | Addon | Qué guarda |
|---|---|---|
| `PlayerBotManager/` | `Lichborne-AC/PlayerbotManager` | Traducción al español de la interfaz siempre visible (pestañas, títulos, cabeceras, botones principales) |
| `recompensas-nivel/` | — (`patch-esES-4.MPQ`) | MPQ con `Item.dbc` (fila del `entry >= 600000` → icono) y `Spell.dbc` (texto del hechizo 59403 sin "llave esqueleto"). Se genera con `tools/construir-parche-cliente-items.py`; va en `<WoW>/Data/esES/`. |

El repo y el commit exacto sobre el que se generó cada `.patch` están en
`addons.lock` (raíz del proyecto) — mismo formato que `versions.lock`, pero
para addons de cliente en vez de módulos de servidor.

### Cómo se usa al actualizar un addon

1. `tools/revisar-actualizaciones-addons.sh` avisa cuando el commit fijado en
   `addons.lock` se queda atrás del `HEAD` remoto (sólo `git ls-remote`, no
   toca nada). `--log <nombre>` enseña el log de commits nuevos: **léelo
   entero**, no solo para ver si toca reaplicar traducción — un addon de
   terceros también trae arreglos/fixes de verdad entre medias (ejemplo real,
   13/09/2026: QuestRadar trajo "Carry three Minimap.lua fixes into the
   server-module variant", nada que ver con texto).
2. Clonar el addon en una carpeta temporal en el commit nuevo.
3. Mirar el `.patch` de esta carpeta (documenta exactamente qué líneas se
   tradujeron la vez anterior) y reaplicar esos mismos cambios sobre el
   código nuevo — a mano, o pidiéndole a un agente de IA que lo haga
   comparando el diff de upstream contra el `.patch` guardado.
4. Sobrescribir `cliente/Interface/AddOns/<Nombre>/` con el resultado ya
   traducido, regenerar el `.patch` (`diff -ru` del clon limpio contra la
   carpeta traducida) y actualizar el commit en `addons.lock`.
5. Desplegar: copiar a `/opt/azerothcore-panel/addons/client/<Nombre>/` (ver
   `panel-addons-ruta-real-opt` en memoria) y a la copia del instalador, y
   reiniciar `azerothcore-panel`.

## Experiencia por profesiones (SP01)

Base: `Tereneckla/mod-profession-experience`, rama `main`, commit
`d1bd97085d27bb8de11d13af097d02460556b0f3` (23/07/2026).

La fase 3 clona/fija y aplica `01-tope-habilidad-curva-y-config-es.patch`.
La fase 5 instala `mod-profession-experience.conf` y fija todas sus opciones.
El módulo no necesita SQL, objetos, NPC ni modificaciones del cliente.
La ayuda española forma parte del artículo de profesiones de `mod-server-help`.

### Configuración acordada

Las 17 actividades configurables tienen base `0.01`. Multiplicadores naranja
`1`, amarillo `0.5`, verde `0.25`, gris `0`; rangos `1`; curva `0` (desactivada).
Esto da 1 %, 0,5 %, 0,25 % y 0 % de la XP total del nivel actual, respectivamente,
antes de modificadores externos y redondeos enteros. No se usa la XP restante.
Con dificultad constante equivaldría a 100/200/400 actividades por nivel; en
la práctica la habilidad sube, cambia el color y hay que entrenar los rangos.

`PROFESSION_XP_BASE`, `PROFESSION_XP_ORANGE/YELLOW/GREEN/GRAY`,
`PROFESSION_XP_CURVE` y `PROFESSION_XP_BLOCK_AT_SKILL_CAP` viven en `config.sh`.
`INSTALL_MOD_PROFESSION_EXPERIENCE=false` aparta el módulo en fase 3; requiere
fase 4 y reinicio para retirar sus hooks del binario. Base cero apaga todas las
recompensas por configuración. La fase 5 fija los multiplicadores de rango a 1.
El `.conf` conserva las 17 opciones independientes del original; la fase 5 las
restablece a la base común elegida en `config.sh`.

### Cambios de código y límites deliberados

- `ProfessionExperience.BlockAtSkillCap=1`: no premia cuando la habilidad base
  alcanza el máximo aprendido. Se aplica a fabricación, recolección y pesca,
  incluido 450/450. La actividad que lleva de 74 a 75 aún puede dar XP: el hook
  se ejecuta antes de la subida. Equipo y encantamientos no falsean este tope.
- Curva corregida a `minSkill / 450.0f`, aunque permanece desactivada. La división
  entera original no aumentaba la XP gradualmente y saltaba a ×5 en requisito 450.
- Fuente XP `42` conservada y nombrada: Guild Levels no contribuye ni bonifica
  esta fuente. `03-bloquear-xp-profesiones-solo-misiones.patch`, en Challenge Modes,
  impide que la ausencia de víctima eluda el desafío «sólo misiones». No cambia
  el tratamiento de otras fuentes de XP de ese módulo.
- No se excluyen bots. Su multiplicador general `Playerbots.RandomBotXPRate`
  sigue aplicándose según las reglas de Playerbots; en esta instalación vale 1.
- Individual Progression conserva sus vetos de 60/70; XP bloqueada y nivel máximo
  los resuelve `Player::GiveXP`. AutoBalance no escala esta XP sin víctima.
- Basura de pesca y actividades sin subida de habilidad pueden dar XP. No hay
  penalización adicional por nivel alto ni protección contra abandonar/reaprender.
  Tampoco se distingue si los materiales vienen de recolección, vendedor o subasta.
- El parche `core/01-pesca-ejecutar-todos-los-hooks.patch` evita que el veto de
  Individual Progression a subir habilidad pescando basura interrumpa el hook
  de XP. Ejecuta todos los observadores y conserva el veto de habilidad. Sin
  este parche, el orden de carga podía dejar la basura sin XP.
- Prospección y molienda llegan al hook de recolección con las líneas de joyería
  e inscripción, que el `switch` original no remunera. Se conserva sin ampliarlo.
  Fabricar con esas dos profesiones sí dispone de ruta y parámetro propios.

Las pruebas C++ con el fuente real están en `tests/profession-experience`;
las pruebas del servidor son casos del catálogo `profesiones-*`. Sus límites se
declaran en `verificar.py describir`. SP01 no se cierra al terminar
la implementación: requiere la tarea posterior de revisión independiente SP01-V.

### Prueba aislada de la lógica de profesiones (`tests/profession-experience/`)

Compila `ProfessionExp.cpp` real, después de aplicar el parche SP01, contra
dobles mínimos de la API. No simula el protocolo ni los otros módulos.

```sh
c++ -std=c++17 -I tests/profession-experience/stubs \
    -I /ruta/mod-profession-experience/src \
    tests/profession-experience/test.cpp -o /tmp/test-profession-experience
/tmp/test-profession-experience
rm /tmp/test-profession-experience
```

Cubre las 17 rutas configurables, colores, tope puro (incluido 450), entrenamiento
del siguiente rango, ausencia de subida, basura, fuente 42, curva fraccionaria y
apagado por parámetros. Prospección y molienda conservan la exclusión upstream.
La integración real se verifica con los casos `profesiones-*` del cliente
sintético; los dobles no certifican Guild Levels, Challenge Modes ni IP.

`python3 tests/profession-experience/fishing-dispatch.py /ruta/core` compila
el dispatcher de pesca y sus macros reales. Verifica que todos los observadores
se ejecutan una vez aunque un hook anterior vete la subida, y que se conserva
el resultado agregado del veto; también prueba la lista vacía.

## Sede de hermandad (SP02)

Origen: `azerothcore/mod-guildhouse`, commit
`0b3cc14e947a859f8a7751a10676107d6316275b` en `versions.lock`.
`01-integracion-sp02.patch` se aplica en la fase 3 y tras las actualizaciones.
La fase 5 instala su configuración y SQL; la fase 8 reaplica el SQL.

### Uso

- El líder de hermandad compra la sede de la Isla de los MJ al vendedor por
  1.000 oro. Precios y rangos de compra/venta de mejoras: valores del módulo.
- Los miembros entran por el vendedor, `.gh teleport` o la Piedra de la sede.
  Las tres vías lanzan el hechizo 600001: 10 segundos, 30 minutos de
  reutilización, sin compartir enfriamiento con la piedra de hogar (8690).
- La piedra se entrega gratis al comprador y a cada jugador humano de la
  hermandad al conectarse. Si falta o no había hueco en la bolsa, el vendedor
  permite pedir otra gratuitamente. No se entregan copias a los bots.
- Al comprar la sede aparece un portal inicial a Ventormenta u Orgrimmar según
  facción del comprador. Los portales adicionales se compran al mayordomo.
  No hay retorno al punto de procedencia.
- Los portales de Shattrath y Dalaran comprueban la etapa del **viajero** de
  Individual Progression (8 y 13, respectivamente). Los portales de facción
  no admiten jugadores de la otra facción.

### Integración y datos

El parche asigna una sola máscara de fase por sede, en los bits 16 a 30. Esto
permite 15 sedes simultáneas y evita que máscaras calculadas como `guildId+10`
se solapen. Si no queda un bit libre, la compra se rechaza. El SQL crea
`mod_guildhouse_owned_spawn`: registra los GUID de NPC y objetos que crea el
módulo para retirarlos al vender o disolver, sin borrar contenido ajeno.

La Piedra de la sede es el objeto 600001 de `patches/custom-items/`. Su hechizo
600001 se crea a partir del hechizo 8690 de **cada DBC existente** con
`tools/piedra_sede_dbc.py`; los efectos originales se sustituyen por un efecto
ficticio atendido por `spell_guildhouse_stone`. El servidor recibe la fila en
`env/dist/bin/dbc/Spell.dbc` en las fases 5 y 8. El cliente la recibe en los
MPQ generados por `tools/construir-parche-cliente-items.py`; el catálogo del
panel guarda su SHA-256. El script DBC es idempotente y rechaza formatos
distintos a los 234 campos de 3.3.5a.

Las entradas 500030–500032 y 500000–500009 son del módulo de terceros. Sus
nombres esES/esMX propios están en `patches/locales-es/04-mod-guildhouse-es.sql`.
El vendedor 500030 se coloca mediante `spawn_service_npcs`: 2,5 yardas a la derecha del Maestro de
hermandad de cada capital que lo tiene (9 de 11; Bahía del Botín y Shattrath no tienen y lo dejan junto al
Dungeon Master). La recompra de piedra no tiene coste.

### Verificación

La implementación está desplegada y cerrada, con revisión independiente
(SP02-V, 30/09/2026, detalle en `CHANGELOG.md`). Los casos `guildhouse-acceso`,
`guildhouse-aislamiento`, `guildhouse-invitado`, `guildhouse-etapas`,
`guildhouse-persistencia` y `guildhouse-horda` pasaron en el cliente sintético,
reejecutados de cero en la revisión independiente tras los cambios de SP03 y
SP04. Cubren compra, rangos, piedra y enfriamiento independiente, dos
hermandades, invitado sin hermandad, portales por etapa, instructor ARAC,
venta, disolución, reinicio y limpieza. El diagnóstico pasó 6/6 antes y
después, y las tablas de sedes, entidades registradas y personajes de prueba
quedaron vacías.

Límites conocidos, de bajo riesgo, sin cubrir todavía: muestra de portales
más allá de Shattrath/Dalaran/Ventormenta/Orgrimmar, servicios distintos de
la posadera, cambio de hermandad a mitad de sesión, reconexión tras disolver
la sede y coste aislado del módulo con la población habitual.

### SP07 — centro de profesiones

Inventario de lo que la sede ya ofrecía al mayordomo (precios del módulo, `GuildHouseBuyRank`
decide quién compra): los 11 instructores de profesión primaria y 3 secundaria (50 oro cada
uno), forja y yunque (50 oro), correo, subastadores, banco personal (100 oro), bóveda de
hermandad, vendedores de suministros y componentes, instructores de clase y portales.
Faltaba un sitio donde **guardar los materiales**.

`02-banquero-de-materiales-sp07.patch` añade a **Ling** (`mod-reagent-bank`, entrada 290011) como
mejora del mayordomo. No se crea ningún NPC nuevo: se reutiliza la plantilla y el script del
módulo, así que las capitales y la sede comparten código, menú y datos.

- **Precio**: `GuildHouseReagentBank`, 1.000.000 de cobre (100 oro, como el banco). `-1` la oculta
  (apagado por configuración, recargable con `.reload config`). Sin `mod-reagent-bank` activo el
  mayordomo tampoco la ofrece: exige la plantilla 290011 **con su script** `npc_reagent_banker`, porque al
  desactivar el módulo la fase 3 sólo vacía el `ScriptName` y borra las apariciones, no la plantilla.
- **Permisos**: los de cualquier mejora (rango de compra, estar en la sede). Quien comprueba el
  permiso es el mayordomo; Ling la puede usar cualquiera que vea la fase, igual que el resto de
  servicios.
- **Propiedad del contenido**: el banco es **de cada personaje**, no de la hermandad
  (`custom_reagent_bank.character_id`). Un invitado en el grupo del dueño ve a Ling con su propio
  banco; ningún stock se ve entre personajes; vender o disolver la sede retira a Ling (queda
  registrada en `mod_guildhouse_owned_spawn`) y **conserva el stock**, que sigue accesible en la Ling
  de cualquier capital.
- **Sitio**: fila 56 de `guild_house_spawns`, junto al banquero y a la bóveda.
- **Textos**: `mod-reagent-bank` mostraba su menú en inglés. `patches/mod-reagent-bank/01-textos-es.patch`
  lo traduce, corrige la paginación (con exactamente 23 entradas aparecía «Página siguiente» hacia una
  página vacía) y archiva en «Otras mercancías» los objetos de subclase 0, que se depositaban sin que
  ningún menú permitiera retirarlos. Las filas 415/416 de `mod_guildhouse_locale` llevan la oferta (enUS en el parche,
  esES/esMX en `patches/locales-es/04`).

#### Cobertura de instructores (medida con `sede-profesiones-instructores`, 01/10/2026)

Son los instructores originales del juego, no maestros de todos los rangos. Recetas con requisito de
habilidad más alto que enseña cada uno; lo que falta se entrena en Shattrath/Dalaran, a los que la
sede tiene portal (con sus etapas del viajero).

| Profesión | Instructor | Receta máxima | Profesión | Instructor | Receta máxima |
|---|---|---|---|---|---|
| Alquimia | Lorokeem | 325 | Herboristería | Flora Silverwind | 200 |
| Herrería | Brikk Keencraft | 300 | Minería | Pikkle | 250 |
| Ingeniería | Buzzek Bracketswing | 250 | Desuello | Seymour | 275 |
| Sastrería | Grarnik Goodstitch | 150 | Primeros auxilios | Mildred Fletcher | 150 |
| Peletería | Darmari | 350 (oculta hasta la etapa 12) | Pesca | Myizz Luckycatch | 50 |
| Encantamiento | Johan Barnes / Felannia | 350 | Cocina | Jack Trapper | 200 |
| Joyería | Tatiana / Kalaen | 365 | Inscripción | Michael Schwan / Neferatti | 350 |

Darmari es del grupo `npc_ipp_tbc_t3` de Individual Progression: sólo lo ven los personajes que han
pasado TBC tier 2 (y los GM), también dentro de la sede. Es comportamiento esperado.

#### Verificación (01/10/2026)

Casos `sede-profesiones` (ambos bandos y apagado), `-grupo` (Party Here con la hermandad de casa
activa, ambos bandos), `-invitado`, `-paginas`, `-instructores`, `-recorrido` (cofre de SP06 → banco →
fundición en la forja de la sede) y `-persistencia` (reinicio del worldserver). Detalle y resultado
observado en `CHANGELOG.md`. Límites: la retirada de Ling al vender se comprueba por SQL; el apagado
por ausencia de `mod-reagent-bank` sólo por lectura del código. Los casos que depositan vacían las 15
categorías al terminar; tras un corte del proceso pueden quedar filas huérfanas en
`custom_reagent_bank` (el borrado de personaje del core no las toca): control manual,
`SELECT * FROM custom_reagent_bank WHERE character_id NOT IN (SELECT guid FROM characters)`.

#### Defectos de `mod-reagent-bank` corregidos (SP07-R)

La revisión independiente de SP07 los detectó en el módulo original y `01-textos-es.patch` los corrige:

- **Caída del worldserver con clic + logout:** las consultas asíncronas de cada categoría capturaban
  `Player*` y `Creature*`. Un `/logout` instantáneo (ciudad, posada, sede) en el mismo tick del clic usaba
  memoria liberada. **Reproducido** con la versión anterior (`SIGSEGV` en la primera carrera del caso
  `sede-profesiones-robustez`). Ahora la callback guarda `WorldSession*` y GUID y revalida al llegar el
  resultado.
- **Pérdida o pisado de materiales en el depósito:** se destruían los objetos antes de confirmar la
  escritura, el aviso de éxito salía al instante, y la suma partía de una lectura asíncrona que un depósito
  anterior podía dejar vieja. Ahora todo ocurre en un solo tick: se reúnen los objetos, se suma en la BD con
  `INSERT … ON DUPLICATE KEY UPDATE amount = amount + …`, se confirma con commit directo, se relee el banco
  y sólo entonces se destruyen los objetos. Si la lectura posterior no cuadra, las bolsas no se tocan y se
  avisa; sin materiales que depositar también avisa. La retirada actualiza el banco en el acto
  (`DirectExecute`).
- Las mercancías genéricas (clase 7, subclase 0) y una plantilla de objeto ausente (filas viejas) ya no
  rompen el menú ni el servidor.

Coste: el depósito hace dos lecturas y una escritura **síncronas** (unos milisegundos) en el hilo del
mundo, en vez de una consulta asíncrona; con un solo jugador es irrelevante. Límite que sigue: una caída
del proceso en el mismo tick, entre confirmar el banco y guardar el personaje, aún podría duplicar un
depósito (el banco ya sumado y los objetos sin borrar del guardado anterior); la ventana es de
microsegundos.

## mod-treasure: tesoros itinerantes (SP03)

Módulo propio de AzerothCore. No instala el módulo de BeardBear33: sus cofres
son fijos, sus tres botines se comparten entre zonas y su actualizador requiere
una base de datos adicional. Los cofres de este módulo tienen entradas y botín
por zona, estado persistente y selección propia de destinos.

### Instalación

`INSTALL_MOD_TREASURE=true` en `config.sh` → fases 3, 4 y 5. La fase 5 instala
`mod_treasure.conf` y ejecuta `data/sql/db-world/base/01-tesoros.sql`. Las 57
zonas del catálogo arrancan activas. La fase 8 repite el SQL de forma idempotente.

La primera carga toma **candidatos** de nodos de recolección ya existentes,
desplazados 3,5 metros en cuatro direcciones para no tapar el nodo. Un nodo existente no certifica
que un cofre quepa a su lado. `sp_treasure_point.validated` sólo pasa a 1 tras
comprobar altura y zona, agua, suelo para acercarse por varios lados, línea de
visión y una ruta completa por mmaps desde un jugador humano presente. Al entrar
un humano en una zona, el controlador valida automáticamente hasta ocho
candidatos cercanos cada diez segundos si faltan alternativas, antes de crear
ningún cofre; cada fallo se registra y se retrasa cinco minutos para no repetir
la misma ruta continuamente. No hace cálculos de ruta por bots.
Los cofres naturales activos se separan al menos 100 metros entre sí, también
entre zonas vecinas del mismo mapa. Al arrancar se retiran las asignaciones
anteriores que incumplan esa distancia. Los cofres temporales de prueba pueden
agruparse delante del jugador para comparar sus modelos y botines.

### Comandos GM

- `.tesoro estado`: cuotas, puntos aprobados y estado de cada plaza en la zona.
  Muestra también el GUID del último cofre cuyo uso o saqueo se vetó a un bot,
  para comprobar el veto real sin depender de mensajes de su IA.
- `.tesoro validar`: fuerza una revisión adicional de candidatos cercanos.
- `.tesoro activar`: vuelve a habilitar una zona desactivada manualmente cuando
  hay al menos dos puntos aprobados por plaza. `.tesoro desactivar` la
  deshabilita y retira sus cofres; la siguiente fase 5/8 la reactivará.
- `.tesoro prueba crear <personaje> <calidad> [zona]`: crea delante del personaje
  conectado un cofre temporal con botín de cualquier zona configurada; calidad
  1 básica, 2 rara o 3 épica. La zona por defecto es la actual; solo se
  admiten calidades existentes en la zona elegida. Funciona también por consola
  o SOAP, de modo que el jugador no necesita permisos GM.
- `.tesoro prueba retirar <personaje>`: borra al instante sus cofres de prueba
  visibles. También desaparecen automáticamente tras `SPTreasure.TestSeconds`
  (90 s por defecto). El efecto de aparición usa `SPTreasure.SpawnSpell`.
  Estos cofres nunca se guardan en la base de datos ni ocupan plazas normales.
- `.tesoro prueba equipo <personaje> <tramo> <variante>`: muestra una pieza de
  equipo garantizada en un cofre temporal con el modelo y la bengala de SP03.
  Tramo 1 (Vanilla intermedio): variantes 1 pantalones azules de pellejo de
  basilisco (1718) y 2 daga azul Hacedora de viudas (4091). Tramo 2 (Vanilla
  final): variantes 1 daga azul Hoja glacial (19099) y 2 daga épica Diente de
  can del Núcleo (18805). Los cuatro duran diez minutos; se retiran también
  con `.tesoro prueba retirar`. Su botín es fijo y no altera las 57 zonas.

La activación se guarda en `sp_treasure_zone`. Sólo un humano puede saquear los
cofres: el veto se aplica también al hechizo normal de apertura, que evita el
gancho de interacción del objeto. Los bots no generan ni validan destinos. El controlador revisa plazos
en el hilo del mundo y sólo materializa los objetos de una zona con un humano
cerca. Al cerrar un cofre abierto y descargar su grid, el estado `opened`
impide crear de nuevo botín en ese punto. La apertura se anota cuando el servidor
envía botín, no sólo cuando el cliente intenta usar el objeto. Si vence la
ubicación después de abrirlo, se aplica la reposición para no duplicar premios.

`SPTreasure.LocationSeconds` limita cuánto permanece cada cofre en un punto,
aunque nadie lo recoja. Los tres `*RespawnSeconds` gobiernan la espera tras
saquearlo. El efecto `SPTreasure.SpawnSpell` se dispara al materializarlo; 0 lo
desactiva. El efecto puntual sólo puede verlo quien esté cerca en ese momento.

Cada pasada de `SPTreasure.ScanMs` está medida con `modules/shared/SlowTick.h`
(mismo mecanismo que mod-world-bots y el resto de módulos que reparten bots):
si supera 100 ms sale un aviso `[treasure] Tick lento` en `Server.log`, como
mucho uno por minuto con el peor caso visto. Con 300 bots y el catálogo de
las 57 zonas cargado no se ha visto ninguno.

### Botín inicial por etapa

Cada zona tiene un objeto fijo para cada calidad disponible. Un básico entrega
1–3 telas; un raro, una gema; un cofre épico, una gema de tramo superior. La
calidad del cofre expresa frecuencia y cuota, no garantiza equipo morado.

### SP06 — botín ponderado y abalorio raro

El contenido de `gameobject_loot_template` (no la cuota ni el punto del
cofre) admite variantes ponderadas mediante `GroupId`: los objetos de un
mismo grupo con `Chance` explícita se reparten esa probabilidad y **sólo
sale uno** de ellos; las filas sin grupo (`GroupId`=0) son bonos
independientes que se suman sin robarle probabilidad al material
garantizado. `02-botin-variado.sql` usa ambos mecanismos, sin
tocar `sp_treasure_zone` ni las entradas de `gameobject_template`:

- **Básico**: antes un material único garantizado; ahora un grupo de 4
  variantes (tela/cuero/mineral/hierba del mismo tramo) al 25% cada una.
  Sigue entregando 1–3 unidades de un solo material por cofre, sólo cambia
  cuál — no aumenta el total de materiales por apertura.
- **Raro**: grupo gema (85%) + polvo de encantamiento del mismo tramo (15%),
  siempre exactamente una de esas dos variantes de material. Además, una fila
  de bono independiente (~5%) ofrece una pieza de equipo azul poco frecuente
  y ligada al equipar, sin afectar a la garantía de arriba.
- **Épico**: la gema épica sigue garantizada sin cambios. Se añaden dos
  bonos independientes: equipo poco frecuente de calidad alta (~4%) y un
  **abalorio "top"** — un trinket icónico (las Cartas del Feriante:
  Heroísmo/Cruzada/Grandeza, y Diente de can del Núcleo como alternativa a
  Grandeza en Rasganorte) con una probabilidad muy baja (0,1–0,4%) pensada
  para dar un momento de suerte sin convertirlo en una fuente fiable.
- **Condición por etapa de Individual Progression**: los bonos épicos de
  Terrallende y Rasganorte exigen la misión de progresión
  correspondiente (`conditions`, `SourceTypeOrReferenceId`=4
  `CONDITION_SOURCE_TYPE_GAMEOBJECT_LOOT_TEMPLATE`, tipo 8
  `CONDITION_QUESTREWARDED` sobre la misión `66000+N`; ver
  `IndividualProgression::GetPlayerProgressionFromQuests`). Terrallende pide
  la misión 66008 (fin de la Vanilla original) y Rasganorte la 66013 (mismo
  umbral que `IP_DK_UNLOCK_PROGRESSION`). El tramo Vanilla alta (139/618/1377)
  no lleva condición: es el primer cofre épico del catálogo.
- **Cobertura**: las 57 zonas del catálogo. El tramo de cada zona se deduce de sus
  objetos en `sp_treasure_zone`; `02-botin-variado.sql` está generado por tramo.
  Verificación: barrido de las 57 y frecuencia en una zona representativa por
  tramo (Elwynn, Los Baldíos, Bosque del Ocaso, Tierras Inhóspitas, Peste del
  Este, Tormenta Abisal, Corona de Hielo).
- **Vanilla inicial no tiene tramo raro**: las ocho zonas de ese tramo del
  catálogo de SP03 (incluida Bosque de Elwynn) tienen `rare_slots`=0 —
  nunca hubo cofre raro ahí, sólo básico. `tesoros-botin-variado` lo detectó
  al intentar crear un cofre raro de prueba en Elwynn; no se añaden filas de
  botín para esa combinación porque la entrada de `gameobject_template`
  nunca existe.

| Etapa de la zona | Básico | Raro | Épico en zonas finales |
|---|---|---|---|
| Vanilla inicial | Lino | Ojo de tigre | — |
| Vanilla baja | Lana | Gema de las Sombras | — |
| Vanilla media | Seda | Piedra lunar inferior | — |
| Vanilla media alta | Paño de tejido mágico | Aguamarina | — |
| Vanilla alta | Paño rúnico | Zafiro azul | Cristal Arcano |
| Terrallende | Tejido abisal | Draenita de sombras | Estrella de Elune |
| Rasganorte | Tejido de Escarcha | Piedra de sangre | Topacio monarca |

Las zonas iniciales de elfos de sangre y draenei usan los tramos de Vanilla;
las otras zonas de Terrallende usan tejido abisal. Los cofres raros y épicos
sólo existen donde la cuota correspondiente es mayor que cero. Los valores
concretos por zona están en `sp_treasure_zone` del SQL.

### Tablas

- `sp_treasure_zone`: cuotas, premio por calidad y habilitación por zona.
- `sp_treasure_point`: coordenadas candidatas y validación.
- `sp_treasure_slot`: punto actual/anterior, vencimiento, reposición y apertura.
- `gameobject_template` y `gameobject_loot_template`: entradas
  `700000 + zone_id*3 + calidad`; no se modifican pools ni cofres ajenos.

## Botín blanco de misión en grupo (SP04)

`mod-quest-loot-party` se fija en `versions.lock` al commit
`6f073c1bef1bba1aa73787d1e30db7429f2b1c7b`. La fase 3 aplica
`01-solo-y-textos.patch`; `patches/mod-aoe-loot/02-quest-copies.patch` adapta
el módulo de saqueo en área fijado en `57279b660a278e9b3a1afa425e7c7a5edc72b7bb`.

### Regla de juego

- Sólo se convierten en `freeforall` los objetos de calidad blanca que el core
  pone en `Loot::quest_items` para un jugador **en grupo**. Cuenta mundo y
  mazmorras. La probabilidad y cantidad de caída no cambian.
- El core crea las listas individuales para miembros presentes, cercanos y
  elegibles al morir la criatura. Llegar o unirse después no crea una copia.
  Requisitos de misión, facción y condiciones siguen pasando por
  `AllowedForPlayer`. Los materiales de `Loot::items` y las otras calidades
  mantienen sus reglas. En solitario manda el core sin este cambio.
- Cada jugador recoge su copia. AoE Loot puede meter en su bolsa la copia de
  cadáveres vecinos. La fila común y las copias ajenas quedan disponibles;
  `unlootedCount` baja una vez por copia recogida. Si la pila completa no cabe,
  no se consume. Las filas bloqueadas por reglas especiales permanecen en el
  cadáver de origen.
- `QuestParty.Message=0` por defecto. El texto opcional en esES/esMX describe
  la regla sin prometer entrega automática. La ayuda en el juego está en
  `modules/mod-server-help/data/sql/db-world/base/server_help.sql`.

### Configurar e instalar

`INSTALL_MOD_QUEST_LOOT_PARTY`, `QUEST_LOOT_PARTY_ENABLE` y
`QUEST_LOOT_PARTY_MESSAGE` viven en `config.sh`. Desplegar sus ficheros al
instalador de la VM por `pscp`, ejecutar fases 3, 4 y 5 y arrancar/reiniciar
`ac-worldserver.service`. La fase 8 reaplica el SQL. El mirror del commit y su
hash están en `mirrors/`.

### Comprobación

`python tools/cliente-sintetico/verificar.py ejecutar diagnostico` antes de
probar. `botin-mision-grupo` observa el objeto 750 en dos jugadores reales que
saquean en distinto orden; `botin-mision-bolsas` comprueba la conservación de
la copia al llenar la mochila; `botin-mision-elegibilidad` comprueba misión
ausente, aceptación tardía, abandono y solitario. `botin-mision-completa`,
`botin-mision-bot`, `botin-mision-mazmorra`, `botin-mision-equipo`,
`botin-mision-selfbot`, `botin-mision-ordinario`, `botin-mision-material` y
`botin-mision-llegada` amplían el recorrido. Cada caso crea y borra sus NPC y
personajes temporales; los once casos pasaron en vivo. Las condiciones raras
y los objetos de misión épicos/legendarios se auditaron en el código y la BD
fijados, sin forzar jefes de banda. La revisión independiente SP04-V consta en `CHANGELOG.md`.

## mod-arac-trainer-audit: auditoría de entrenadores

`LogTrainerPurchases` registra compras; `GuardClassRaceFit` veta aprendizajes
incompatibles. `RefreshDruidTrainerList` reenvía la lista del instructor 26324
tras cada compra correcta mediante `WorldSession::SendTrainerList`, después
de la respuesta de éxito del core. Conserva su validación, idioma, precios y
filtro de era. No genera otra compra. No depende de activar los logs.

Configuración: `ARAC_TRAINER_AUDIT_REFRESH_DRUID_TRAINER_LIST` en `config.sh`
(por defecto `false`: no resolvió el fallo real), instalada por la fase 5 como
`AracTrainerAudit.RefreshDruidTrainerList`. `Enable=0` apaga todo el módulo.

Desde el core del 20/09/2026 (#27707) `OnPlayerCanLearnSpell` también recibe
la **entrada** del instructor que se lanza para enseñar otros hechizos
(monturas de clase, rangos de profesión), antes de lanzarla, y no sólo cada
hechizo enseñado. Si `GuardClassRaceFit` la vetara, el core se salta la
compra entera (ya cobrada). No debería pasar (esas entradas no tienen fila de
raza/clase en `SkillLineAbility`), pero queda como prueba pendiente:
buscar `bloqueado` en `Server.log` tras comprar una montura de clase y un
rango de profesión.

### Alcance y evidencia

Caso comunicado: druida gnomo nivel 60, instructor 26324, una compra Feral
por apertura; Equilibrio/Restauración permiten compras consecutivas. Reabrir
la ventana permite otra compra. El refresco reproduce la recepción de una
lista nueva sin exigir esa operación manual. **El usuario confirmó que no
resuelve el fallo; queda desactivada.**

**Causa determinada el 22/09/2026 con esta misma traza** (líneas 1032-1048 de
`Server.log`): RX BUY 3029 → TX SUCCEEDED, y RX BUY 99 → TX FAILED `reason=2`
seis veces. `reason=2` es `Trainer::FailReason::NotEnoughSkill`: el cliente sí
manda el paquete y lo rechaza el core, porque `spell_required` exige Forma de
oso (5487) y el personaje no la tiene — ni puede tenerla, porque nadie la
vende ni la concede en esta base de datos. Como `spell_required` no viaja en
`SMSG_TRAINER_LIST`, el cliente recalcula la fila con los campos que sí
recibe (todos a 0 salvo ReqLevel) y la pinta en verde; y el motivo 2 no tiene
texto en la interfaz de 3.3.5a, de ahí el silencio. Lo de "una compra por
apertura" era casualidad de qué fila se pulsaba después, no un candado.
Arreglo: `patches/arac/08-druid-bear-form-y-requisitos-visibles.sql`. Detalle
y auditoría de alcance en `CHANGELOG.md` (22/09/2026, 18:00).

### Traza temporal de entrenador

`ARAC_TRAINER_AUDIT_TRACE_ACCOUNT_ID` fija `AracTrainerAudit.TraceAccountId`
en fase 5. El conf.dist usa 0 (apagada); el perfil de diagnóstico usa 1
(cuenta del personaje afectado), que debe volver a 0 al cerrar E1h.
`Enable=0` también apaga la traza. La configuración se almacena en un atómico.

`mod_arac_trainer_trace.cpp` usa los hooks `CanPacketReceive`/`CanPacketSend`
y devuelve siempre true. No accede a Player desde el hook de envío, no lee
otros paquetes y no mueve el cursor del paquete. Verifica longitud antes de
leer GUID, SpellID o motivo. Registra únicamente:

- RX OPEN: CMSG_TRAINER_LIST / CMSG_GOSSIP_HELLO.
- RX BUY: CMSG_TRAINER_BUY_SPELL, antes del handler.
- TX LIST, SUCCEEDED y FAILED: respuestas del servidor a esa cuenta.

Si aparece RX BUY sin éxito, distinguir FAILED con motivo de retorno previo
sin respuesta. Si no aparece RX BUY, no se ejecutó el handler de compra:
habrá que observar llamada Lua/estado interno del cliente (la traza por sí
sola no es una captura del socket ni prueba todos los filtros anteriores).
Para el segundo intento que falla, anotar el nombre del hechizo y no cerrar
la ventana hasta haberlo intentado. No hacen falta compras masivas.

Lectura del core `025ede00fe78` y del código instalado en la VM:

- No descontar oro no demuestra que el segundo paquete nunca llegó:
  existen rechazos anteriores a `ModifyMoney`. Los hooks del módulo no
  registran todos los intentos ni todos los rechazos.
- `TeachSpell` envía `SMSG_TRAINER_BUY_SUCCEEDED` antes del hook utilizado.
- `SendTrainerList` valida el instructor y llama a `Trainer::SendSpells`.
  No invoca el hook de compra, por lo que no hay recursión.

Inspección estática, sin modificar ni ejecutar `Wow.exe`, del cliente local
`<cliente>`:

- `BuyTrainerService` (0x595e60) acaba en 0x594da0; comprueba índice y estado
  de fila (`+0x30 == 0`) antes de construir `CMSG_TRAINER_BUY_SPELL` (0x1b2).
  Ese recorrido no contiene un candado global de compra pendiente.
- La rutina en torno a 0x596b00 recalcula estados de las filas mediante
  datos de hechizo, conocidos, habilidades, requisitos y nivel. Esto permite
  una discrepancia entre la disponibilidad enviada al abrir y la calculada
  localmente; **no prueba que ocurriera en el segundo clic del usuario**.
- Los MPQ del repo y del cliente incluyen las filas nativas examinadas de
  SkillLineAbility y la fila ARAC Feral 134 para todas las razas/clase druida.
  No hay fundamento para volver a sustituir DBC o quitar requisitos a ciegas.

### Validación y despliegue

`python3 tests/test_arac_trainer_refresh.py` compila el módulo real contra
dobles mínimos y comprueba el ámbito, múltiples llamadas, logs desactivados,
recarga de opciones, interruptor general, punteros nulos y veto raza/clase.
Requiere `g++` o `CXX`. No simula el protocolo ni la interfaz de WoW.

Además se compiló el `.cpp` contra las cabeceras reales de la VM con la orden
de su `compile_commands.json`, generando sólo un objeto temporal. No se
enlazó, instaló ni reinició el worldserver en esa primera comprobación.

Para desplegar, subir código/configuración/fase 5 por `pscp`, aplicar fases
3/4/5 y reiniciar conforme a `INSTALL_ES.md` (consultar antes `server info`).
No hace falta cambiar SQL ni MPQ.

Desplegado con autorización del usuario el 22/09/2026: copia del módulo,
fase 4 y sólo su bloque de fase 5. Worldserver activo desde las 14:43:13 CEST,
opción habilitada y SOAP comprobado. Copia de retorno en
`/home/acore/backups/trainer-refresh-20260922/`. Detalle en `CHANGELOG.md`.

Prueba pendiente: con el mismo druida y NPC, comprar tres habilidades Feral
que ya estuvieran disponibles al abrir sin cerrar la ventana; verificar
aprendizaje y un único cobro por habilidad. Comprobar también Equilibrio,
Restauración y que nivel/rango insuficiente sigan impidiendo comprar.
La nueva lista puede recolocar selección/desplazamiento; revisar ese efecto.
Si persiste el fallo, registrar simultáneamente llamada Lua/estado de fila
y recepción/rechazo del opcode del servidor antes de atribuir una causa.

## El verificador sintético (`tools/cliente-sintetico/`)

Un cliente de WoW 3.3.5a (build 12340) sin interfaz, en Python. Habla el mismo
protocolo que `Wow.exe`: entra por el authserver, se conecta al mundo, crea
personajes temporales, da comandos GM, habla con NPC, compra a instructores,
forma grupo con bots, entra en mazmorras y, con `.playerbots bot self`, deja
que la IA de playerbots juegue **con su propio personaje** mientras mide lo que
pasa. Sirve para comprobar lo que antes sólo se podía comprobar jugando.

Cada formato de paquete está contrastado con el código exacto del core fijado
(`mirrors/core@f19a18799a35.tar.gz`) y de los módulos fijados; el fichero y la
función de referencia van en el comentario de cada módulo.


### Requisitos

| Qué | Versión / valor |
|---|---|
| Python | 3.9 o posterior (probado con 3.12 en Windows) |
| Dependencias | sólo biblioteca estándar para la red; `mpyq` (`pip install mpyq`) para los DBC del cliente |
| Cliente real | `<cliente>` (sólo se leen sus MPQ; nunca se escribe) |
| Red | authserver `3724/tcp` y worldserver `8085/tcp` de la VM (192.168.1.100) |
| Cuenta | una cuenta **exclusiva** de pruebas con GM 3 y expansión 2 (`VERIFICADOR`) |

Las pruebas de dos jugadores usan además `VERIFICADOR2`, también exclusiva de
pruebas, con GM 3 y expansión 2.

Los casos marcados con `dbc` (arac, mazmorra, buscador) necesitan `mpyq` y la
carpeta del cliente: sin ellos salen **BLOQUEADO**, nunca OK.

### Perfil del entorno (sin secretos en Git)

El host, la cuenta y la clave **no** tienen valores por defecto en el código.
Copia `entorno.ejemplo.json` a `entorno.local.json` (excluido de Git) y
rellénalo, o usa `--entorno <fichero>` / `VERIFICADOR_ENTORNO`. Las variables
`VERIFICADOR_HOST`, `VERIFICADOR_CUENTA` y `VERIFICADOR_CLAVE` pisan al
fichero. La clave nunca se imprime ni llega al informe.

| Campo | Para qué |
|---|---|
| `reino_esperado` | si el authserver anuncia otro reino, **nada se ejecuta** (BLOQUEADO) |
| `permitir_escrituras` | `false` = sólo `conectar` y `leer` (el caso `diagnostico`) |
| `acciones_admitidas` | lista blanca: `personaje`, `gm`, `comprar`, `selfbot`, `grupo`, `cola`, `mazmorra` |
| `prefijo` | prefijo de los personajes temporales (`Vs`) |
| `timeout_conexion` | segundos para la primera respuesta: con el modo en espera, conectar despierta al worldserver (~15 s) |
| `cuentas_adicionales.secundaria` | objeto opcional con `cuenta` y `clave` de otra cuenta de pruebas; `dos-cuentas` y los casos M43-M45 la necesitan |

Cada caso declara sus acciones; si el perfil no las admite, el caso sale
BLOQUEADO con el motivo, sin conectar.

#### La cuenta VERIFICADOR

Creada el 24/09/2026 por SOAP. Tras una reinstalación limpia hay que recrearla
(consola del worldserver por SOAP, ver `INSTALL_ES.md`):

```text
account create VERIFICADOR <clave>
account set gmlevel VERIFICADOR 3 -1
account set addon VERIFICADOR 2
```

La segunda cuenta se recrea del mismo modo con el nombre `VERIFICADOR2` y
la clave guardada en `entorno.local.json`; la contraseña de WoW 3.3.5a admite
como máximo 16 caracteres.

Ningún caso toca otras cuentas ni personajes que no sean los suyos.

Para las pruebas con dos jugadores, añade al perfil local, junto a la cuenta
principal, `"cuentas_adicionales": {"secundaria": {"cuenta": "VERIFICADOR2",
"clave": "<clave privada>"}}`. El perfil público y los informes muestran sólo
el alias; la contraseña de la segunda cuenta tampoco se serializa. `limpiar`
actúa sobre la principal por defecto; `limpiar --cuenta secundaria` se limita
a los temporales registrados de la segunda cuenta.

### Uso

Desde la raíz del repositorio (Windows o la VM):

```bash
python tools/cliente-sintetico/verificar.py listar                     # catálogo
python tools/cliente-sintetico/verificar.py describir mazmorra          # un caso y sus parámetros
python tools/cliente-sintetico/verificar.py ejecutar diagnostico        # sólo lectura: primero siempre
python tools/cliente-sintetico/verificar.py ejecutar @rapido            # por etiqueta
python tools/cliente-sintetico/verificar.py ejecutar todo --dry-run     # qué haría, sin conectar
python tools/cliente-sintetico/verificar.py ejecutar mazmorra -p mazmorra=bfd -p duracion=5400
python tools/cliente-sintetico/verificar.py ejecutar buscador -p recorrido=si
python tools/cliente-sintetico/verificar.py limpiar                     # huérfanos tras un corte
```

`todo` recorre los casos marcados `en_todo` (los largos —`mazmorra`,
`buscador`— hay que pedirlos por su nombre). El atajo antiguo
`verificar.py arac|progresion|bots|todo [--espera N]` sigue funcionando.

**Tiempos:** `diagnostico` ~20 s; `modulos` y `selfbot` ~1 min; `arac` ~4 min;
`progresion` ~1 min; `bots` 3-4 min; `companeros` 2-4 min; `hermandad` 3-6 min; `mazmorra` de 30 a
90 min (tope `duracion`); `buscador` 2-5 min sin recorrido. Cada caso tiene un
tiempo máximo (`duracion_max`) tras el que falla por plazo; la limpieza del
personaje temporal no se corta por ese plazo.

#### Resultado e informe

Cada comprobación sale `OK`, `AVISO` o `FALLO`; cada caso, además, puede salir
`OMITIDO` (`--dry-run` o sin comprobaciones), `BLOQUEADO` (precondición) o
`ERROR` (infraestructura). Los FALLO llevan su **origen**: `desarrollo` (lo
probado no hace lo que debe), `cliente` (el cliente sintético no supo leer o
responder) o `entorno`.

| Código de salida | Significado |
|---|---|
| 0 | todo OK o AVISO |
| 1 | algún FALLO |
| 2 | algún BLOQUEADO u OMITIDO (sin fallos) |
| 3 | ERROR de infraestructura |
| 4 | uso incorrecto |

El informe JSON (esquema `cliente-sintetico/2`) va a `--json <fichero>` o a
`.estado/ejecuciones/<fecha>/informe.json`: herramienta y versiones fijadas
(`mirrors/MANIFEST.tsv`), perfil sin secretos, revisión del core que responde
`.server info`, origen de cada DBC y, por caso, parámetros, pasos,
comprobaciones (esperado/observado), errores, artefactos y datos en bruto. Los
casos con grupo dejan además una línea de tiempo JSONL (`<caso>-linea-de-tiempo.jsonl`).

#### Personajes temporales y limpieza

Los casos crean personajes `Vs…` y los borran al terminar, también si algo
falla. Antes de entrar con ellos los apuntan en `.estado/personajes.json`. Si
el proceso se corta, `verificar.py limpiar` borra sólo los que cumplen las tres
condiciones: cuenta del perfil, prefijo y GUID registrado. Los que tienen el
prefijo pero no están registrados sólo se listan (`--forzar <nombre>` para
borrarlos a sabiendas). El caso `diagnostico` avisa de ambos.

### Casos

| Caso | Qué prueba | Control |
|---|---|---|
| `diagnostico` | login, reino esperado, worldserver (lo despierta), personajes de la cuenta. Sólo lectura | lectura |
| `modulos` | cada módulo propio responde a su consulta (`.standby estado`, `.queuebots estado`, `.ayuda`, …) | directo |
| `selfbot` | `.playerbots bot self` enciende y apaga la IA sobre el propio personaje, sin otra sesión | delegado |
| `arac` | combinaciones ARAC frente a su control nativo (AR01) | directo |
| `arac-clases` | una combinación no nativa por cada una de las nueve clases ampliadas por ARAC: entrada, DBC, hechizos, habilidades e instructor | directo |
| `progresion` | Individual Progression y Cronista de las Eras | directo |
| `bots` | bots con jugador dentro: personajes en el mundo − jugadores conectados | directo |
| `companeros` | party-here: `.grupo mazmorra`, tramo de nivel, `.grupo estado`, tanque y sanador o aviso explícito (M26), `.grupo fuera` | directo |
| `hermandad` | home-guild: adopción de la hermandad fundada con `.guild create`, reclutamiento, bots conectados (M11) y preferencia de party-here por ellos (M21); la desactiva y la borra al terminar | directo |
| `misiones` | quest-mates (aceptar en el NPC y abandonar) y misiones de grupo automáticas de party-here | directo |
| `buscador` | buscador + queue-bots: cola, propuesta aceptada, teletransporte, grupo LFG, dc automático; con `recorrido=si`, la mazmorra entera | directo |
| `mazmorra` | **CS01**: mazmorra entera con el jugador en selfbot y cuatro compañeros | delegado |

#### `mazmorra` en detalle

1. Personaje temporal (mago humano por defecto; para mazmorras de la Horda como
   Sima Ígnea, `entrada=directa`) al nivel de la mazmorra;
   `.gm off`; `.playerbots bot initself=rare` lo equipa y le da talentos
   (preparación GM, queda anotada en `datos.preparacion`).
2. `.grupo mazmorra` (party-here) → cuatro compañeros: tanque, sanador, daño.
3. Entrada **por el portal**: `.tele` al exterior y el personaje se coloca en
   el area trigger de entrada; el cliente manda `CMSG_AREATRIGGER` como
   `Wow.exe`. Si falla, `.go` dentro (anotado).
4. Espera a que los cuatro estén en la zona de la mazmorra (queue-bots trae a
   los rezagados).
5. `.playerbots bot self`: la IA toma **este mismo personaje**. Desde aquí el
   agente no da órdenes de movimiento ni combate.
6. queue-bots debe mandar `.dc on` solo; si no llega en 75 s, el caso falla y
   para (con `intervenir=si`, el agente lo pide y lo anota).
7. Recorrido: el cliente cumple el protocolo (teletransportes, area triggers,
   TIME_SYNC) y observa: estado de dungeon-clear y jefes (mensajes de addon
   `DC`), estadísticas del grupo, trayectorias del servidor, temporizadores de
   respiración/fatiga, daño ambiental (ahogo, caída), teletransportes y `.gps`
   de los cinco cada `intervalo_gps` s (mapa, instancia, suelo, líquido).
8. Fin: todos los jefes muertos/saltados, dungeon-clear apagado con jefes
   pendientes, wipe sin recuperación o `duracion`. Después apaga selfbot,
   `.grupo fuera`, logout y borrado.

Anomalías que detecta (`telemetria.py`): `sin_progreso`, `dc_atasco`,
`dc_recuperando`, `dc_puerta`, `dc_apagado`, `jefe_saltado`,
`jefe_desaparecido`, `muerte`, `wipe`, `respiracion`, `fatiga`,
`dano_ahogamiento`/`dano_caída`…, `bajo_el_suelo`, `sin_suelo`, `caida`,
`bajo_el_agua` (info), `fuera_del_mapa`, `salida_de_instancia`,
`teletransporte`, `salto_posicion`, `separado`, `combate_largo`,
`desconexion`, `grupo_disuelto`, `protocolo`, `quieto_bajo_el_agua`. Las
graves son FALLO; las de aviso, AVISO.

**Parar y avisar:** por defecto (`parar_en_grave=si`) el recorrido se corta en
la **primera anomalía grave** y el caso termina con su evidencia: no se sigue
esperando ni se mitiga para llegar al final. Del mismo modo, si party-here no
trae tanque y sanador, el caso lo anota como FALLO y para. Las mitigaciones
existen sólo para diagnosticar a propósito y quedan anotadas como
intervenciones (el caso nunca sale OK con ellas): `intervenir=si` (reactivar
dungeon-clear, `.dc skip` tras `max_atasco` s), `completar_roles=si` (cambiar un
DPS por un bot `addclass` con la especialización que falta) y
`respiracion_acuatica=si` (aura 11789 a los cinco). Para parar a mano un
recorrido en curso: crear el fichero `tools/cliente-sintetico/.estado/ejecuciones/PARAR` (o `PARAR` dentro de la carpeta de esa pasada)
(el caso limpia igual: selfbot, grupo y personaje).

Contraste: `.dc test` / `.dc test watch` de dungeon-clear (cinco bots sin
cliente) es un control complementario para separar fallos de dungeon-clear de
fallos del cliente/selfbot; no sustituye a este caso.

### Qué no comprueba

- **Lo que sólo pinta Wow.exe:** libro de hechizos, textos, addons y errores
  Lua. Se comprueba a mano con el cliente gráfico (AR01).
- **ACK de velocidad, raíz y empujón:** el cliente no los manda a propósito:
  llevan una posición y el core recolocaría al selfbot en la estimación del
  cliente, pisando el spline del servidor. Se cuentan (`forzados_sin_ack`).
- **Atravesar paredes:** no se infiere de dos muestras; se usan mapa,
  instancia, suelo y líquido del servidor (`.gps`).
- **Warden:** el login se identifica como Mac (`OSX`, con la prueba de versión
  de `build_info.macHash`), así que el core no arranca Warden para esta sesión.
  Warden sigue activo para los clientes Windows reales.

### Estructura

```
verificar.py                    línea de órdenes (listar, describir, ejecutar, limpiar)
entorno.ejemplo.json            plantilla del perfil (entorno.local.json no va a Git)
wowsintetico/entorno.py         perfil, acciones admitidas, secretos fuera del informe
wowsintetico/catalogo.py        @caso, parámetros tipados, selección por id/@etiqueta/todo
wowsintetico/ejecutor.py        precondiciones, plazos, aislamiento, limpieza de huérfanos
wowsintetico/informe.py         estados, orígenes, JSON cliente-sintetico/2, códigos de salida
wowsintetico/registro.py        registro local de personajes temporales
wowsintetico/binario.py         lector/escritor little-endian, GUID empaquetado
wowsintetico/cripto.py          SRP6 del cliente, ARC4-drop1024, claves de cabecera
wowsintetico/auth.py            login al authserver y lista de reinos
wowsintetico/mundo.py           sesión de mundo: personajes, chat/addon, GM, NPC, grupo, buscador, eventos
wowsintetico/actualizaciones.py SMSG_(COMPRESSED_)UPDATE_OBJECT
wowsintetico/movimiento.py      SMSG_MONSTER_MOVE y posición estimada por spline
wowsintetico/areatriggers.py    detección de area triggers como Wow.exe
wowsintetico/grupo.py           SMSG_GROUP_LIST, PARTY_MEMBER_STATS, paquetes LFG
wowsintetico/telemetria.py      línea de tiempo JSONL y detectores de anomalías
wowsintetico/dbc.py             DBC efectivos del cliente real (MPQ por prioridad)
wowsintetico/escenarios/        un módulo por familia de casos
```

Las pruebas sin conexión (criptografía contra una réplica de `SRP6.cpp`,
recepción partida a mitad de paquete, GUID, actualizaciones, chat,
MONSTER_MOVE con puntos empaquetados y paquetes truncados, grupo y buscador,
area triggers, `.gps` en inglés y español, informe y códigos de salida,
catálogo y precondiciones, registro de huérfanos, detectores de telemetría)
corren con el resto:

```bash
python -m unittest discover -s tests -p "test_*.py"
```

### Añadir un caso

En corto: un módulo en `escenarios/` con
`@caso(...)` y `def ejecutar(ctx)`, `PersonajeTemporal` para cualquier
personaje, `ctx.inf.comprobar(...)` con `esperado`/`observado` y `origen`.

## Edición pública: snapshots, addons y recursos del cliente (PUB04 y PUB04-I)

**Dónde:** `lib/mirrors.sh` (`hydrate_snapshot`, `hydrate_mirrors`, `extract_arac_inputs`),
`web-panel/tools/build-addons.mjs`, `web-panel/src/resources.js`, `web-panel/src/routes/resources.js`,
`web-panel/public/mpq.js`, `web-panel/public/client-resources.js`, `web-panel/public/views/addons.js`,
`scripts/preparar-recursos.sh` y `.github/workflows/` · **Desde el 05/10/2026**

La edición pública no lleva lo que pesa, lo que no tiene licencia de redistribución ni lo que es arte de
Blizzard. Cada pieza se reconstruye por una vía con hash, y lo que no se puede reconstruir se queda
**pendiente a la vista**, nunca sustituido por una versión reducida.

| Pieza | Vía en la edición pública | Comprobación |
|---|---|---|
| Snapshots de `mirrors/` | `./install.sh --hidratar`: asset opcional o `git fetch --depth 1 <commit>` del upstream y `git archive \| gzip -9` | SHA-256 de `MANIFEST.tsv` |
| Core y módulos al instalar | clonado y `versions.lock`, como siempre | commit exacto |
| 309 addons de cliente | `node web-panel/tools/build-addons.mjs build` | `arbol.tsv` (hash por carpeta) |
| 3 mapas de 4 | `web-panel/tools/fetch-maps.mjs` (UA fijo y URL con sufijo de versión) | SHA-256 de `addons/mapas.json` |
| Iconos de la armería | el panel, con lo que lee el navegador del administrador del cliente | huella de insumos + receta |
| `patch-<idioma>-4.MPQ` | ídem, más los tres DBC de ARAC verificados | ídem |

### Hidratación de snapshots

`hydrate_snapshot NOMBRE COMMIT` busca la entrada en `MANIFEST.tsv` y deja `mirrors/<fichero>` por la primera vía
que dé un fichero con ese SHA-256: el que ya estaba, `MIRROR_ASSET_BASE_URL/<fichero>` (https, opcional) o el
upstream. El `git archive` se hace con `core.autocrlf=false` y `core.eol=lf`: con la configuración de Git para
Windows los bytes cambiaban. Los 27 snapshots salen idénticos desde Ubuntu y desde Windows; dos (`mod-guild-levels`
y `mod-playerbots-wintergrasp`) estaban hechos con fines de línea CRLF y se regeneraron con los de su commit
(`tools/verificar-parches.sh` sigue aplicando sus parches limpios). Un fichero alterado, una entrada ausente o un
hash incorrecto hacen fallar la verificación; `tests/hidratar-mirrors.sh` lo comprueba con un upstream local.

**Datos del cliente (`Data.zip`).** La fase 5 los instala con `install_client_data` (`lib/utils.sh`): versión fijada
v20.0 de wowgaming/client-data y su SHA-256 (`AC_DATA_URL` y `AC_DATA_SHA256`, siempre juntos, para otra versión).
Una descarga cortada deja `data.zip.part` y se reanuda (`wget -c`); un `data.zip` entero y verificado se reutiliza; un
hash que no cuadra o un ZIP inválido se borran sin extraer nada; una extracción interrumpida deja `.data-extracting` en
`env/dist/bin` y la fase la repite entera. `tests/datos-cliente.sh` lo prueba con `wget` y `7z` sustituidos.

### Reconstrucción de addons

`web-panel/addons/fuentes.json` guarda, por cada uno de los 117 paquetes de NoM0Re, el commit (dos: el fijado
`235b9e4` y su padre, que aún tenía los 25 paquetes que el fijado retiró), el SHA-256 del archivo y las carpetas que
aporta; los addons de repositorio (GuildLevels, QuestRadar, PlayerBotManager) salen del commit de `addons.lock` y
todos admiten parches en `patches-cliente/<Addon>/` (ACP, Chatter, GuildLevels, QuestRadar, PlayerBotManager).
`arbol.tsv` fija el hash de contenido de las 309 carpetas, insensible a CRLF y a mayúsculas de ruta. La
construcción reproduce **exactamente** el árbol que tenía el repositorio de trabajo (309 de 309). Descartado: dar
por buenos `addons.lock` o `catalog.json` como fuente (no basta para rehacer cada fichero) y reconstruir todo
desde el último commit de NoM0Re (borraría los 25 paquetes conservados).

### Almacén de recursos del panel

Carpeta de datos del servicio (`RESOURCES_DIRECTORY`, en la VM `/var/lib/azerothcore-panel/recursos`):
`iconos/` (WebP y `map.json`), `parches/<idioma>/patch-<idioma>-4.MPQ`, `mapas/<id>.jpg`, `trabajos/` y
`estado.json`, que por recurso anota origen (`generado` o `preparado`), receta (`RECIPE` de `resources.js`),
huella de los insumos del cliente, hash de los DBC de ARAC y fecha. Un recurso `generado` deja de valer si cambia
la receta, el cliente (otra huella) o los DBC de ARAC; uno `preparado` (el repositorio de trabajo trae iconos y MPQ
y se incorporan una vez desde `RESOURCES_SEED_DIRECTORY`) vale hasta que el administrador pida regenerarlo.

| Ruta | Qué hace |
|---|---|
| `GET /api/recursos` | estado de cada recurso y último trabajo |
| `POST /api/recursos/trabajos` | `{idiomas, entradas, regenerar}`: devuelve el plan (qué hace falta y por qué) y abre el trabajo; sin nada que hacer, no lo abre. Una recepción interrumpida con las mismas huellas se **reanuda** (lista los ficheros ya recibidos); con otro cliente se sustituye |
| `PUT /api/recursos/trabajos/:id/lote` | ZIP (`application/zip`, hasta 64 MiB) con `dbc/…`, `iconos/<n>.blp` e `iconos/indice.json` |
| `POST /api/recursos/trabajos/:id/iniciar` | lanza los generadores (Python) y actualiza el progreso |
| `GET`/`DELETE /api/recursos/trabajos/:id` | estado y cancelación |

Todas son de administrador (GM 3) y las que escriben exigen `X-Panel-Request`. El lote se valida entero antes de
escribir nada: sólo nombres de una lista cerrada (`dbc/ItemDisplayInfo.dbc`, `dbc/<esES|enUS>/Item|Spell.dbc`,
`iconos/<1-6 dígitos>.blp`, `iconos/indice.json`), tamaño declarado y real, número de ficheros, cabecera (`WDBC`,
`BLP`) e identificadores del índice. Los nombres de icono del cliente (con espacios o símbolos) no llegan nunca al
sistema de ficheros del servidor: viajan como número y un índice. Los insumos del jugador no se conservan tras la
generación. Un fallo del generador deja el recurso anterior intacto y guarda las últimas líneas de su salida;
un trabajo a medias al reiniciar el panel pasa a `error`. Los iconos y los mapas se publican con un intercambio de
carpetas; mientras faltan, `/assets/item-icons/*` y `/assets/maps/*` responden con un SVG neutro propio (no con una
imagen rota) y los parches sin generar se listan `available: false` y devuelven 409 al descargarlos.

### Lectura del cliente en el navegador (`mpq.js`, `client-resources.js`)

El servidor no puede leer una ruta de Windows, así que el navegador lee los MPQ con la File System Access API y
sólo extrae lo necesario: `ItemDisplayInfo.dbc`, los iconos que referencia y, por idioma, `Item.dbc` y
`Spell.dbc` (unos 100 MB frente a varios GB de cliente). `mpq.js` es un lector MPQ v1-v4 sin dependencias: tablas
de hash y de bloques cifradas, ficheros por sectores o de una pieza, CRC de sector, cifrado y las compresiones
zlib (`DecompressionStream`), PKWARE y bzip2; los parches delta y otras compresiones fallan con un mensaje claro.
Resuelve cada fichero con la misma prioridad que `tools/construir-parche-cliente-items.py` (excluye los propios
`patch-<idioma>-4.MPQ`). Se comprobó contra el cliente real con `mpyq` (hash idéntico en DBC y BLP, un MPQ de
2,8 GB se abre en menos de un segundo) y contra MPQ sintéticos en `test/mpq.test.js`.

La sesión de generación: el navegador lee, calcula la huella de insumos de cada recurso y pregunta al servidor
qué hace falta; sólo envía eso, en lotes ZIP de hasta 24 MiB, y espera el progreso. Un administrador que elige su
carpeta de WoW en **Addons** dispara la preparación si falta algo; «Instalar parches» también la hace antes de
copiar; una segunda pasada con el mismo cliente responde «ya estaba al día» sin enviar nada.

Resultado con el cliente de pruebas (esES y enUS) de punta a punta, contra los datos preparados del repositorio de
trabajo: los dos MPQ salen **idénticos byte a byte**; 4.682 iconos WebP, 4.680 idénticos y 2 con otro nombre porque
en este cliente un `patch-<letra>.mpq` de mayor prioridad sustituye su arte (el extractor antiguo sólo miraba una
lista fija de archivos y el nuevo sigue la prioridad real del cliente: 3 de 68.743 apariencias apuntan a otro
icono); 48 referencias sin arte con el icono genérico, como antes.

### Mapas

Los mapas del panel salen de Warcraft Wiki y la proyección del mapa está calibrada con esas imágenes. Se probó
generarlos desde las teselas del cliente y no sirve (en el cliente de pruebas el encuadre y el arte son otros, la
correlación con el mapa actual va de 0,32 a 0,99). `addons/mapas.json` fija origen, UA y SHA-256. La CDN de la
wiki entrega a veces una variante recomprimida (otros bytes, mismo aspecto: Rasganorte pasa de 2,86 a 2,7 MB, y con
ciertos parámetros de caché Kalimdor y Terrallende salen más grandes) que depende de la URL de caché y del momento, y
no es la misma en dos máquinas. `fetch-maps.mjs` prueba la URL tal cual y después `?v=1`…`?v=6` (`variantes` del
JSON), en tres pasadas con pausas (la variante servida cambia incluso entre pasadas de unos segundos: una vez, las siete
variantes de Kalimdor dieron otros bytes durante una instalación y minutos después cuadraban), y sólo acepta el fichero
con el SHA-256 fijado. Si ninguna lo da, el mapa queda pendiente (el panel usa un fondo neutro) y no se instala otra versión.

### CI en GitHub

`.github/workflows/ci.yml` (push a `main`, PR y manual; permisos de lectura, acciones fijadas a SHA completo, sin
secretos): estructura del paquete y revisión de secretos con gitleaks fijado por versión y SHA-256 (`.gitleaks.toml`
sólo con excepciones justificadas), sintaxis, pruebas del instalador y del asistente, hidratación y parches contra el
commit fijado, construcción de los 309 addons y pruebas del panel con los generadores. `compilacion.yml` (manual y
una vez al mes) ejecuta las fases 1 a 4 del instalador en Ubuntu 24.04; no corre en cada cambio por tiempo y espacio,
y la compilación incremental con caché queda por medir. Las pruebas con el cliente sintético no corren en CI
pública. Se comprobaron los mismos pasos sobre el árbol exportado, en una Ubuntu 24.04 limpia (los pasos de la
CI y, aparte, la instalación completa desde cero); los flujos de GitHub en sí no se han podido ejecutar sin remoto.

---

## Procedencia de mapas e iconos

### Mapas de continente (`web-panel/public/assets/maps/`)

Mapas de continente de la interfaz de World of Warcraft publicados en
[Warcraft Wiki](https://warcraft.wiki.gg/), todos con proporción 3:2 y resolución
3840 × 2560. Se usan las versiones anteriores a Cataclysm compatibles visualmente
con AzerothCore/WotLK 3.3.5a. Los nombres locales corresponden al identificador de
mapa usado por AzerothCore.

| Archivo | Continente | Fuente | SHA-256 |
|---|---|---|---|
| `0.jpg` | Reinos del Este | [`WorldMap-EasternKingdoms-old.jpg`](https://warcraft.wiki.gg/wiki/File:WorldMap-EasternKingdoms-old.jpg) | `4cdc5d05de82ae8637382ed7756ea032138dd7989a1517ab91793dadf8d69b0a` |
| `1.jpg` | Kalimdor | [`WorldMap-Kalimdor.jpg`](https://warcraft.wiki.gg/wiki/File:WorldMap-Kalimdor.jpg) | `2238f18cf232a1f024c06d7afd2d173d869870f7f8e8be07ca400b04d7042394` |
| `530.jpg` | Terrallende | [`WorldMap-Outland Updated.jpg`](https://warcraft.wiki.gg/wiki/File:WorldMap-Outland_Updated.jpg) | `93767f30d825051becb0c41e43f04bc0a2b944f57bd9aec0e5219e8874a8851d` |
| `571.jpg` | Rasganorte | [`WorldMap-Northrend.jpg`](https://warcraft.wiki.gg/wiki/File:WorldMap-Northrend.jpg) | `b67278ef031bde9769bf000aa69f7dcab02508b365c89040ad1504c11991c891` |

World of Warcraft y sus recursos gráficos pertenecen a Blizzard Entertainment.

### Iconos de objetos (`web-panel/public/assets/item-icons/`)

Los genera `web-panel/tools/extract-item-icons.py` a partir del cliente del jugador (desde el panel, con los
ficheros que lee el navegador, o a mano con `--client`/`--insumos`); no son datos de la edición pública ni se
editan a mano. El extractor escribe, junto a los
iconos, un resumen de la última generación con este contenido:

Recursos generados; no deben editarse a mano.

- DBC: `patch-G.mpq` (`sha256:c56346bfd726906e4b5f2b01cfbb370e581d7cf418d7671f0da257d340fcede5`)
- MPQ de arte consultados: patch-I.mpq, patch-3.MPQ, patch-2.MPQ, patch.MPQ, lichking.MPQ, expansion.MPQ, common-2.MPQ, common.MPQ
- Apariencias: 57986
- Iconos WebP: 4682
- Referencias de icono sin arte: 48
- Apariencias con fallback: 15413

Para regenerarlos, desde `web-panel/`:

```bash
pip install -r tools/requirements-icons.txt
python tools/extract-item-icons.py --client "/ruta/al/cliente"
```

Las referencias de icono sin arte en el cliente (48 en la última generación) usan el
recurso genérico del panel. Los hashes de los DBC y la lista de MPQ consultados
identifican el cliente con el que se generó.

## Cliente web del navegador (`web-client/`)

Uso y opciones: `INSTALL_ES.md`, «Cliente web del navegador (fase 10, opcional)». Aquí, cómo
está montado y qué hay que saber si algo falla.

**Piezas y dónde viven** (la fase las instala con `./install.sh --webclient`):

| Qué | Dónde | Notas |
|---|---|---|
| Build desplegado | `/var/lib/azerothcore-play/releases/<id>/`, enlace `current` | `id` = `build.json` o hash; se guardan 3; revertir = repuntar `current` |
| Ficheros del juego | `/var/lib/azerothcore-play/datos/` | sólo enlaces a `.MPQ` + `manifiesto.tsv` (`generar-manifiesto.py`) |
| Cliente base (WEB-PANEL) | `WEB_CLIENT_DATA_DIR` (por defecto `/var/lib/azerothcore-play/base`) | lo sube un administrador desde el panel (menú «Cliente web», paso 0); el servicio del panel escribe en él, en `datos/` y en `WEB_CLIENT_ROOT` por el grupo del usuario de AzerothCore (`ReadWritePaths=` de su unidad, carpetas 2775) |
| Puente | `azerothcore-web-bridge.service`, `/opt/azerothcore-web-bridge/puente-ws.py` | 127.0.0.1:8765; sin privilegios; `IPAddressAllow=localhost` |
| nginx | `/etc/azerothcore-panel/play.d/play.conf` | lo incluye el servidor HTTPS del panel; sin el `include` (panel anterior) la fase se niega a seguir |
| Página de entrada | `releases/<id>/index.html` (de `web-client/play/index.html`) | comprueba HTTPS, `crossOriginIsolated`, WebGPU+BC, manifiesto, puente y `build.json` |

**Rutas de `/play/`:** `/play/` y `/play/<fichero>` salen del build; `/play/datos/<mpq>` de los
enlaces (con `Range`); `/play/datos/manifiesto.tsv` sin caché;
`/play/ws?port=<N>` es el WebSocket del puente (sólo 3724 y 8085 por defecto); `/play/estado` es
el contador del puente. El cliente usa rutas **relativas** a la página (`datos/`, `wgsl/`,
`ws?port=`), por eso el mismo build funciona colgado de cualquier carpeta; `?bridge=host:puerto`
sustituye el puente (pruebas) y `?perfil=<id>` elige un perfil de contenido (sin parámetro, el único de hoy, «base»: la `Data` del servidor tal cual).

**Cliente base desde el panel (WEB-PANEL).** `web-panel/src/clienteWeb.js` y `routes/clienteWeb.js`; cliente
en `web-panel/public/subida-cliente.js` y `views/clientWeb.js`. API: `GET /api/cliente-web/estado` (cualquier cuenta: `disponible`,
`configurado`, `activo`; el administrador además `base`, `interruptor`, `subida`, `libre`); sólo administradores y con
`X-Panel-Request`: `POST /api/cliente-web/subida` (lista `[ruta, tamaño]`; reanuda si es la misma lista, 409 si es otra y
`reiniciar` no es true, 507 si no hay sitio salvo `borrarAntes`), `PUT .../subida/archivo?ruta=&desde=` (trozo ≤ 16 MiB con
`X-Chunk-Sha256`; 409 con `recibido` si la posición no coincide, 422 si la huella no cuadra), `POST .../subida/confirmar`,
`DELETE .../subida`, `POST /api/cliente-web/activo`. Reglas: sólo `*.MPQ` de `Data` y de `esES/`/`enUS/`; los nombres del reino
(`RESERVED`, los mismos que `generar-manifiesto.py`) se ignoran; deben estar `common`, `expansion`, `lichking`, `patch` y un
`locale-<idioma>.MPQ`; los trozos van a `WEB_CLIENT_DATA_DIR/.subida/<ruta>.parte` y sólo al confirmar (todo recibido y con
cabecera MPQ) se mueven a su sitio, se borra el cliente base anterior (menos lo reservado) y se ejecuta
`generar-manifiesto.py --permitir-vacio`. «Configurado» se deduce de los ficheros, no de un registro, así que una instalación
anterior al panel ya consta. **Activo** = no existe `WEB_CLIENT_ROOT/desactivado`: `nginx-play.conf` responde 503 en `/play/`,
`/play/datos/` y `/play/ws` (no en el manifiesto, que el panel usa para comprobar la carpeta local). nginx del panel: la ruta
`/api/cliente-web/subida/archivo` admite 18 MiB y no almacena el cuerpo; el resto del panel sigue en 16k. Un cliente web instalado
con una versión anterior necesita repetir `./install.sh --panel` y `--webclient` (permisos, variables y la marca de nginx).

**Cosas que han dado guerra:**

- Los hilos de WebAssembly exigen **contexto seguro y aislamiento de origen cruzado**: HTTPS (con la
  CA del panel instalada en el dispositivo) y las tres cabeceras COOP/COEP/CORP en cada respuesta
  bajo `/play/`, incluidas las de `datos/` y `ws`. Un `add_header` dentro de un `location` anula los
  del nivel superior, así que cada `location` de `nginx-play.conf` repite las suyas.
- `systemctl reload nginx` y el reinicio del puente son asíncronos: `deploy.sh` reintenta durante
  10 s antes de dar por fallida una comprobación.
- El puente ve todas las conexiones llegando desde 127.0.0.1; con `--confiar-proxy` (que pone la
  unidad) usa `X-Real-IP` sólo cuando la conexión viene de 127.0.0.1. Sin ello el límite por IP
  sería global.
- Con el worldserver en espera (`WORLDSERVER_STANDBY`), el puente despierta la unidad al abrir el
  túnel de autenticación (`--wake-state`, `--wake-port`, `--wake-espera`): sólo conecta un instante
  con el puerto 8085 (activación por socket) y lee `/run/azerothcore/worldserver.state` (el que
  escribe la unidad y lee el panel); no usa `sudo` ni `systemctl`, que falla dentro del sandbox de
  `DynamicUser` («Transport endpoint is not connected»).
- **Perfiles de contenido (30/10/2026):** hoy hay uno solo, «base», y es la `Data` del servidor tal cual:
  un cliente 3.3.5a **limpio** (los MPQ de `common` a `patch-3` de ChromieCraft sin ningún paquete HD ni
  parche de terceros) con las carpetas `esES/` y `enUS/`, más lo propio (`custom.MPQ`, que el cliente web
  necesita para los `DetailDoodad`, y `esES/patch-esES-4.MPQ` / `enUS/patch-enUS-4.MPQ` de `cliente/Data/`,
  regenerados contra esa base con `tools/construir-parche-cliente-items.py`). El cliente web fuerza
  `locale esES`; `enUS` está en el servidor para un futuro selector de idioma. La página muestra una tarjeta
  por perfil y envía `?perfil=<id>` salvo en «base». El cliente conserva el mecanismo de
  `?perfil=base` con lista de ocultas (`perfil-base.tsv`, ya no se genera ni se sirve) por si vuelve un perfil
  con paquetes extra; para ofrecer otro basta una tarjeta nueva en `web-client/play/index.html` y sus MPQ.
- El navegador guarda, por origen, **dos cosas**: la configuración del juego (IndexedDB `wow-web`: atajos, posiciones, resolución de Vídeo) y una **caché en dos niveles de los bloques de la `Data` ya descargados**: en disco (OPFS, carpeta `wow-bloques`: segmentos `seg2-*.bin` con su índice `idx-*.bin`, que se leen a demanda en ~1 ms sin copiarse a la memoria al arrancar) y una reserva pequeña en memoria (384 MB, 768 MB o 1,5 GB según `navigator.deviceMemory`; el heap de wasm32 no pasa de 4 GB). El presupuesto de disco es de hasta 24 GB y como mucho la mitad de la cuota del navegador (se borran los segmentos más viejos que no quepan). La caché HTTP del navegador no sirve para las peticiones `Range`; por eso la propia. Si cambia la `Data` del servidor (`manifiesto.tsv`), se descarta sola; `?cache=0` la desactiva (sólo red y memoria) y borrar los datos del sitio empieza de cero. El enlace manda: a ~11 MB/s, la primera visita tarda ~25–35 s en entrar al mundo (pantalla de carga) y dentro del mundo en frío el juego no se para: lo que falta se baja en segundo plano y la precarga cede la red al juego. «Preparar el juego» baja las listas de precarga de todas las zonas grabadas (desde el 04/11/2026: 37 listas, unos 2,4 GB, varios minutos; antes 127 MB con tres listas) y es la única precarga: «Preparar todo el juego» (toda la `Data`, ~18 GB) se retiró el 04/11/2026 para no saturar de peticiones al servidor. En juego, la precarga en segundo plano elige las listas por la zona del personaje (`precarga/zonas.tsv`: id de zona → lista propia y vecinas); con las zonas preparadas, la pantalla de acceso tarda ~3 s y la entrada al mundo ~4 s.
- **Consola del navegador y opciones del juego (31/10/2026).** En la versión final la consola de F12 va en silencio (no sale ningún registro del juego ni del dispositivo gráfico); con `?debug=1` en la dirección se activan, para diagnosticar. Las opciones de Vídeo son las del cliente original: la `Data` del servidor lleva un `custom.MPQ` para la web sin `Interface\FrameXML\VideoOptionsAdvanced.lua` (la página «Avanzado» del cliente mejorado, con niebla volumétrica, nubes, sombras de sol…), y la configuración (`Config.wtf`) fuerza a 0 los 23 extras de ese cliente en cada arranque porque el dispositivo WebGPU no los tiene. Si en el futuro se ofrece alguno, va como perfil con su página de opciones, no como interruptores sueltos.
- **Cliente local (04/11/2026).** Es un origen de datos más, por usuario: la carpeta `Data` (o la de `Wow.exe`) se
  elige con el selector de carpetas del navegador y su *handle* se guarda en IndexedDB (`azeroth-cliente-local`, mismo
  origen que `/play/`); nunca llega al servidor. `manifiesto.tsv` lleva una columna `servidor` que marca los MPQ propios
  del reino: esos se leen siempre del servidor y van los últimos en la cadena de carga; el resto se toma de la carpeta
  local **si existe, sin comparar tamaño ni contenido** (el cliente del usuario es otro y es normal que difiera) y sólo lo que
  falta lo pone el servidor. Los MPQ propios del usuario se usan salvo que su nombre coincida con uno del manifiesto o de la
  lista de reservados (entonces se tratan como ese fichero). El panel (menú «Cliente local» → «Cliente web») resume qué sale
  del equipo y qué del servidor y activa o no la tarjeta de `/play/`, que sólo se ofrece si está configurado y activado.
  Brave informa siempre de una cuota de 2 GiB (anti-huella) aunque deja escribir más: una cuota de exactamente 2 GiB no
  recorta el presupuesto de disco (tope de 8 GB).
- **Mejoras gráficas y ecualizador.** Todas las opciones son CVars que registra el motor y se guardan en `Config.wtf`
  (IndexedDB) como cualquier otra: `mg*` para la imagen (`mgRenderScale`, `mgUpscaler`, `mgSharpen`, `mgAntiAlias`,
  `mgMSAA`, `mgExposure`… `mgAO`, `mgWater`) y `eqEnabled` + `eq<Canal><1-5>` para el sonido (canales `Sfx`, `Music`,
  `Ambience`, `Cinematic` y `Master`; ganancia en dB, −12 a 12; por defecto todo a 0 y apagado). Las páginas de opciones
  son Lua del `custom.MPQ` web (el mismo archivo sirve a Vídeo y a Sonido). **Ecualizador:** cada sonido del juego suma en
  el canal de su grupo (`MUSIC` y `SCRIPTMUSIC` → música, `AMBIENCE` → ambiente, `CINEMATIC` y `RACIALCINEMATIC` → cine y todo
  lo demás, incluidos diálogos y pasos que el motor original mete en `SFX`, → efectos y voces); con `eqEnabled` cada canal y
  después el conjunto pasan por cinco filtros biquad (estante de graves a 100 Hz, campanas de Q = 1 a 350 Hz, 1,2 kHz y
  4 kHz, estante de agudos a 10 kHz) y un limitador suave que sólo actúa por encima de 0,8 (subir bandas puede saturar la
  suma). Las ganancias se acercan a su objetivo a 1,5 dB por bloque de mezcla (~11 ms) para que arrastrar un control no
  chasquee; con el ecualizador apagado la mezcla es la de siempre. `Module.sonidoEstado()` (consola con `?debug=1`) incluye
  `busVoces` y `busPico` (voces activas y pico tras el ecualizador de cada canal), útiles para comprobar a qué canal va
  un sonido. **Cómo se verificó:** el DSP con una prueba de barrido de senos en el PC (ganancia por banda, suavizado,
  limitador y estabilidad a ±12 dB) y el conjunto en el navegador comparando el pico de cada canal con el ecualizador apagado
  y con sólo ese canal a −12 dB (−10 a −13 dB en el canal tocado, sin cambio en los demás). La lista «Multimuestreo» original
  de Resolución (en realidad una lista de formatos, con una sola fila) se oculta desde ese mismo Lua; el MSAA real es
  `mgMSAA` en Mejoras gráficas.
- Para pruebas con certificado propio: un navegador lanzado con `ignoreHTTPSErrors` sirve; el
  navegador de Playwright MCP no, porque no confía en la CA del panel.

**Pruebas:** `python3 web-client/test_puente.py` (puente con servidor de eco: reenvío, puerto y
origen no permitidos, límites por IP y `X-Real-IP`) y `./install.sh --doctor` (`web-client`).
