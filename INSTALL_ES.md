# Instalación, configuración y operación

**Español** · [English](INSTALL_EN.md)

Todo lo que hay que saber para montar este servidor, ajustarlo y mantenerlo en
marcha. En este orden: **lo automatizado** primero, porque es lo que se usa;
luego **cada opción** de `config.sh` y qué hace de verdad; luego **qué hace cada
fase por dentro** y por qué está hecha así; y al final **cómo se opera** el
servidor ya instalado.

Qué es el proyecto: `README.md` · Cómo funciona cada pieza propia:
`REFERENCES.md` · Qué cambió y cuándo: `CHANGELOG.md`

> **Instalar con un agente de IA, o a mano.** Se recomienda hacer la instalación con
> ayuda de un agente de IA con acceso a una terminal (por ejemplo Claude Code o Codex):
> puede leer este documento, ejecutar los pasos de la [parte 1](#parte-1--instalar),
> interpretar los errores y reanudar la instalación si se interrumpe. No es necesario:
> todo se puede hacer a mano, con el asistente (`bash install.sh --guiado`) o fase a fase,
> siguiendo los pasos tal como están escritos. Si usas un agente, revisa lo que propone
> ejecutar y escribe tú las contraseñas en la terminal (el asistente las pide sin mostrarlas):
> no se las pegues en la conversación.

> Lo verificado aquí lo está contra el código de las versiones fijadas en
> `versions.lock`. **Sólo se editan `config.sh` y `config.local.sh`**: nada se toca a mano en el
> servidor, porque la siguiente reinstalación se lo lleva por delante.

---

### Índice

**[Parte 1 — Instalar](#parte-1--instalar)**
[Requisitos](#requisitos) · [Asistente](#instalar-con-el-asistente) · [De una tacada](#de-una-tacada) · [Paso a paso](#paso-a-paso-installsh) · [Modos de `install.sh`](#modos-de-installsh) · [Después de instalar](#después-de-instalar) · [En el PC del jugador](#en-el-pc-del-jugador)

**[Parte 2 — Configurar](#parte-2--configurar)**
[Cómo funciona](#1-cómo-funciona-de-configsh-al-conf) · [Servidor](#2-servidor-reino-tasas-facciones-rendimiento) · [Bots](#3-bots-mod-playerbots-mod-queue-bots-y-mod-world-bots) · [Instancias](#4-instancias) · [Progresión](#5-progresión) · [Economía y servicios](#6-economía-y-servicios) · [ARAC](#7-razas-y-clases-arac) · [Administración y español](#8-cuenta-de-administrador-npc-de-servicio-y-español) · [Versiones y avisos](#9-versiones-copias-offline-y-avisos)

**[Parte 3 — Qué hace cada fase, y por qué](#parte-3--qué-hace-cada-fase-y-por-qué)**
[La VM](#la-vm-y-el-sistema-fase-1) · [MySQL](#mysql-fase-2) · [El código](#el-código-y-los-módulos-fase-3) · [Compilar](#compilar-fase-4) · [Configurar](#configurar-fase-5) · [Servicios](#los-servicios-systemd-fase-6) · [Automatización](#automatización-fase-7) · [Post-instalación](#post-instalación-fase-8) · [Panel web](#panel-web-fase-9) · [Riesgos conocidos](#riesgos-conocidos)

**[Parte 4 — Operar](#parte-4--operar)**
[Día a día](#1-día-a-día) · [Copias](#2-copia-de-seguridad-y-restauración) · [Actualizar](#3-actualizar-el-core-y-los-módulos) · [Instalación limpia](#4-instalación-limpia) · [Primer arranque](#5-primer-arranque) · [Diagnóstico](#6-diagnóstico-dónde-mirar-cuando-algo-falla) · [Pruebas](#7-batería-de-pruebas) · [Desde Windows](#8-operar-desde-windows)

**[Parte 5 — El PC del jugador y el panel web](#parte-5--el-pc-del-jugador-y-el-panel-web)**
[El cliente](#el-cliente-cliente) · [El panel web](#el-panel-web-web-panel) · [Catálogo de addons](#el-catálogo-de-addons-del-panel-web-paneladdons)

---

## Parte 1 — Instalar

### Requisitos

Un servidor (físico o VM) con **Ubuntu Server 24.04 LTS**, acceso SSH con `sudo` e
internet. Lo que exige el asistente antes de empezar:

| | |
|---|---|
| RAM | 16 GB (se detiene por debajo de 14 GiB) |
| Disco | 60 GiB libres como mínimo |
| CPU | No se exige; 8 cores es lo cómodo, con menos la compilación tarda más |

**Dónde se ha probado.** Todas las pruebas del proyecto se han hecho en este equipo y
no son requisitos: un GMKtec M5 Ultra (Ryzen 7 7730U, 8C/16T, 32 GB DDR4, NVMe) con una
VM de Proxmox de 8 cores tipo `host`, 16 GB de RAM (sin ballooning) y 120 GB de disco.
Ahí la instalación completa tardó ~35 minutos, de los que ~22 son compilar con 7 cores.
Tus tiempos y el consumo dependerán de tu hardware. Por qué esos valores en la VM de
pruebas: [parte 3](#la-vm-y-el-sistema-fase-1).

Para una instalación nueva sin editar archivos, ejecuta **`bash install.sh --guiado`**.
La [guía del asistente](#instalar-con-el-asistente) explica los pasos y la reanudación
automática (`--reanudar`). El asistente conserva las opciones avanzadas actuales.

En modo manual se edita **`config.sh`** (los módulos y todas las opciones, con valores
neutros) y se crea **`config.local.sh`** con los valores propios de la instalación
(`REALM_IP`, contraseñas...). `config.sh` lo carga solo; `config.local.sh` no se
versiona y sobrevive a las actualizaciones de `config.sh`.

### Instalar con el asistente

Necesitas un servidor con **Ubuntu Server 24.04 ya instalado**, conexión a
internet y un usuario con permisos de administrador (`sudo`). El asistente exige
los requisitos de arriba (16 GB de RAM y al menos 60 GiB libres) antes de comenzar. El juego se ejecuta en el PC del jugador.

#### Pasos

1. Clona el proyecto en el servidor, con `git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer`, o
   descarga y descomprime un ZIP de versión. Conserva
   todas sus carpetas, incluidos `modules/`, `patches/`, `cliente/` y `web-panel/`.
   Cada versión publica el árbol como ZIP y `.tar.gz` junto a un `SHA256SUMS`;
   comprueba la descarga con `sha256sum -c SHA256SUMS --ignore-missing` antes de
   descomprimirla (ver «Paquetes de cada versión» en la
   [parte 2 §9](#9-versiones-copias-offline-y-avisos)).
2. Abre una terminal dentro de la carpeta del proyecto. Si estás usando SSH,
   entra en esa carpeta con `cd`.
3. Ejecuta, con tu usuario normal, **sin anteponer `sudo`**:

   ```bash
   bash install.sh --guiado
   ```

4. El asistente comprueba Ubuntu, memoria, espacio y servicios del sistema.
   Acepta o corrige la IP propuesta, escribe el nombre del reino y elige tu
   cuenta administradora y su contraseña. La contraseña no aparece al escribir.
5. Revisa el resumen y responde `s`. Tus datos se guardan en `config.local.sh`
   (`config.sh` no se modifica) y se inicia la instalación. Cuando se solicite, escribe la contraseña de tu
   usuario de Ubuntu; puede ser distinta de la del juego.
6. Mantén la terminal abierta hasta terminar. La compilación y las descargas
   tardan decenas de minutos, dependiendo del equipo y de la conexión.

Si falta Python: ejecuta `sudo apt install python3` y abre de nuevo el asistente.
La IP propuesta corresponde a la ruta de red del servidor: comprueba que sea
la dirección que puede alcanzar tu PC, especialmente si usas VPN o varias tarjetas.

#### Qué se conserva

`config.sh` sigue siendo la configuración base y el asistente no lo modifica: escribe
sus cambios en `config.local.sh`, que `config.sh` carga después de sus propios valores.
Cambia la IP, el nombre del reino y los datos de la cuenta administradora, y activa su
creación.
Si la contraseña de base de datos sigue siendo el ejemplo `acore`, genera una
nueva. Respeta una contraseña de base de datos personalizada y todos los demás
ajustes: módulos, bots, tasas, progresión, horarios, directorios y panel web.

Se conserva también la política actual de automatización y servicios del
proyecto, incluidos los reinicios programados del equipo. Usa una VM o servidor
dedicado como describe [la parte 3](#la-vm-y-el-sistema-fase-1).

Si ya existía un `config.local.sh`, antes de escribir se guarda su versión anterior en
`.instalacion/copias/`. Las copias, el estado de instalación y `config.local.sh` quedan
fuera de Git y contienen credenciales: consérvalos en el servidor.
Cancelar en el resumen no cambia archivos ni inicia servicios.

Los modos avanzados siguen disponibles:

```bash
bash install.sh --only 5   # reaplicar ajustes del servidor
bash install.sh --only 4   # recompilar
bash install.sh --post     # post-instalación y panel
```

No se modifica automáticamente una instalación ya existente: el asistente
indica cómo continuar con los modos avanzados. Para personalizar una instalación
nueva antes de ejecutarla, puedes seguir editando `config.sh` directamente.

#### Si se interrumpe

Desde la misma carpeta y con el mismo usuario:

```bash
bash install.sh --reanudar
```

Reintenta el paso pendiente; conserva los completados. Un fallo durante el
primer arranque lo deja pendiente; un fallo en el panel reintenta el bloque de
post-instalación. La comprobación final debe pasar antes de marcar el proceso
como terminado. Si ya terminó, reanudar sólo informa de ello.

Los registros están en `~/instalacion-completa.log` y, para el primer arranque,
`~/primer-arranque.log`. Para ver el progreso desde otra terminal:

```bash
tail -f ~/instalacion-completa.log
```

Si cambias `config.sh`, `versions.lock` o el destino entre intentos, la
reanudación automática se detiene para evitar saltarse pasos que necesitan
reaplicarse. Conserva los archivos anteriores o elige el punto de partida con
`bash scripts/instalar-todo.sh --desde N` (1–7), siguiendo [el modo manual](#de-una-tacada).
Ese modo manual permite también retomar instalaciones anteriores al asistente.

#### Comprobar o configurar sin instalar

```bash
bash install.sh --guiado --comprobar   # sólo comprobar el equipo
bash install.sh --guiado --configurar  # guardar datos y copia, sin instalar
```

Después de `--configurar`, inicia la instalación con `bash scripts/instalar-todo.sh`.

#### Conectar el juego

Cuando la instalación termine, configura tu cliente WoW 3.3.5a y los parches
del proyecto siguiendo «El cliente» (INSTALL_ES.md, parte 5). El asistente no
instala el cliente en el PC ni crea la máquina virtual.

El resumen muestra la dirección del reino. Si el panel está activado, abre
`http://IP_DEL_SERVIDOR` (añade `:PUERTO` si has cambiado el puerto 80).
Accede al juego y al panel con la cuenta elegida durante el asistente.

### De una tacada

Instalación completa y desatendida — fases 1-7, primer arranque,
post-instalación, panel web, servicios y verificación — pidiendo la contraseña
de `sudo` una sola vez:

```bash
git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer && cd azerothcore-installer   # o descomprime el ZIP de una versión
nano config.sh
chmod +x scripts/instalar-todo.sh && ./scripts/instalar-todo.sh
```

Al terminar, el servidor está arrancado, con la cuenta `admin`/`admin` (GM 3),
los NPC de servicio colocados, el realmlist apuntando a `REALM_IP` y el panel
disponible en `http://REALM_IP`.

Mantén abierta la terminal. Si se interrumpe, `bash install.sh --reanudar`
(o `bash scripts/instalar-todo.sh --reanudar`) continúa desde el paso pendiente,
siempre que no hayan cambiado la configuración, las versiones fijadas o el
destino. `--desde N` (1–7) mantiene el control manual para elegir qué fases
repetir. El estado se guarda en `.instalacion/estado`.

### Paso a paso (`install.sh`)

Si se prefiere ver cada fase, o retomar una instalación a medias:

```bash
chmod +x install.sh && ./install.sh      # fases 1-7, con resumen y confirmación
```

| Fase | Qué hace | Tiempo |
|---|---|---|
| 1 | Dependencias del sistema, zona horaria | 2 min |
| 2 | MySQL 8.4, usuario y bases de datos | 2 min |
| 3 | Clona el core y los módulos según `versions.lock`, copia los propios, aplica los parches | 4 min |
| 4 | Compila e instala | ~22 min |
| 5 | Escribe todos los `.conf` a partir de `config.sh` y aplica el SQL propio | 1 min |
| 6 | Unidades systemd, parada segura, espera a MySQL | 1 min |
| 7 | Reinicio diario, revisión semanal de versiones, copias, logrotate | 1 min |
| 8 | Post-instalación: realmlist, cuenta admin, NPC de servicio, SQL que necesita la BD poblada | 1 min |
| 9 | Panel web: usuario MySQL acotado, base propia, cuenta SOAP, Node.js, systemd y publicación por Nginx | 1 min |

Las fases 8 y 9 no van en la tanda 1-7 porque necesitan las bases de datos ya
creadas por el primer arranque. `--post` ejecuta ambas en ese orden.

### Modos de `install.sh`

```bash
./install.sh --guiado      # primera vez, sin editar nada: ver "Instalar con el asistente"
./install.sh --reanudar    # retomar una instalación completa interrumpida
./install.sh --from 3      # retomar desde una fase
./install.sh --only 5      # sólo una fase: lo normal tras tocar config.sh
./install.sh --fix         # reintenta lo que falló
./install.sh --post        # fases 8 y 9
./install.sh --panel       # instala o actualiza sólo el panel (fase 9)
./install.sh --freeze      # fija en versions.lock los commits que hay instalados
./install.sh --mirror      # copias offline de los repositorios en mirrors/
./install.sh --verify-mirrors  # solo comprueba que versions.lock y mirrors/ coinciden
./install.sh --doctor      # pasada de comprobaciones de salud (ver más abajo)
./install.sh --help
```

**`--only 5` es el modo que más se usa**: cambiar una opción en `config.sh`,
reaplicarla y reiniciar. Sólo hace falta recompilar (`--only 4`) si se ha
tocado código o se ha añadido un módulo.

**`doctor` (`lib/doctor.sh`)** es una pasada de comprobaciones de solo
lectura: `mirrors/` contra `versions.lock`, versiones instaladas contra las
fijadas, las claves con historial de incidente (`MapUpdate.Threads`,
`AllowTwoSide.Interaction.*`), claves añadidas sin declarar en su
`.conf.dist`, carpeta y `.conf` de cada módulo propio activo, servicios
systemd, espacio en disco y avisos de "Tick lento" en `Server.log`. Se
ejecuta sola al final de cualquier `install.sh` (instalación, actualización o
compilación) y tras cada arranque/reinicio del worldserver
(`ExecStartPost` de `ac-worldserver.service`, fase 6); `./install.sh --doctor`
la lanza a mano. El resultado se guarda en `acore_world.doctor_status` (el
más reciente) y `doctor_history` (las últimas 50 pasadas), que el panel
enseña bajo **Mi cuenta → Estado del servidor** a cualquier cuenta con
sesión. Devuelve distinto de cero si alguna comprobación es un fallo real
(un aviso no cuenta).

### Después de instalar

Si se ha usado `--guiado` o `scripts/instalar-todo.sh`, esto ya está hecho. A mano son tres pasos:

**1. Primer arranque**, que crea y puebla las bases de datos:

```bash
bash tools/primer-arranque.sh
```

Responde `yes` por ti a cada pregunta, espera a que el mundo escuche en el
puerto **8085** y apaga limpio. A mano: `cd ~/azerothcore/env/dist/bin &&
./worldserver`, `yes` a todo y `server shutdown 1` cuando escuche. **No esperes
a "World initialized"**: este core ya no lo imprime. Si se queda parado en
"Waiting for 150 accounts…", ciérralo y vuelve a arrancarlo — es un cuelgue
conocido del primer arranque y a la segunda pasa ([parte 4 §5](#5-primer-arranque)).

**2. Post-instalación**: realmlist, cuenta `admin`/`admin` (GM 3, sin
personajes), NPC de servicio, SQL pendiente y panel web accesible por la IP:

```bash
./install.sh --post
```

Para actualizar posteriormente sólo el panel, incluidos sus mapas y recursos
estáticos, se usa `./install.sh --panel`; conserva los secretos generados y
reinicia `azerothcore-panel.service`.

**3. Arrancar como servicio.** A partir de aquí arranca solo con la máquina:

```bash
sudo systemctl start ac-authserver ac-worldserver
bash tools/verificar-instalacion.sh
```

Y, desde el PC de Windows, la prueba «jugando» con el cliente sintético (crea
y borra sus propios personajes en la cuenta `VERIFICADOR`, que hay que crear
tras una instalación limpia, y lee su perfil de
`tools/cliente-sintetico/entorno.local.json`, que no va a Git: ver
«El verificador sintético» (REFERENCES.md)):

```bash
python tools/cliente-sintetico/verificar.py ejecutar diagnostico   # sólo lectura
python tools/cliente-sintetico/verificar.py ejecutar todo
```

### En el PC del jugador

Todo lo que va en el cliente está en la carpeta `cliente/` del repositorio
(«El cliente» (INSTALL_ES.md, parte 5)):

| | |
|---|---|
| `Data/esES/patch-esES-4.MPQ`, `Data/enUS/patch-enUS-4.MPQ` | Objetos propios del servidor + cualquier raza con cualquier clase (ARAC) |
| `Interface/AddOns/ServerHelp` | La pestaña de ayuda con los comandos del servidor |
| `Interface/AddOns/MultiBot` | Mando de los bots |

En Windows lo copia todo:

```powershell
cliente\instalar-cliente.ps1 -Cliente "<cliente>" -Realm 192.168.1.100
```

A mano: copiar las dos carpetas sobre la del WoW y poner `set realmlist
<IP>` en `Data/<idioma>/realmlist.wtf`. Opcional: `patch-V.mpq` de
individual-progression (costes de maná de Vanilla/TBC). Arranca con `Wow.exe`,
no con el Launcher, y nunca uses `localhost`: siempre la IP numérica.

La subasta tarda horas en llenarse: `.ahbot update` varias veces con el GM.

---

## Parte 2 — Configurar

Todas las opciones de `config.sh`: qué clave real escribe cada una, qué hace
de verdad y por qué vale lo que vale.

### 1. Cómo funciona: de `config.sh` al `.conf`

**Sólo se editan `config.sh` y `config.local.sh`.** La fase 5 del instalador
(`./install.sh --only 5`) copia cada `.conf.dist` del core y de los módulos a su
`.conf` y escribe encima las claves que gobiernan esos dos ficheros. Nunca se edita un
`.conf` a mano: el siguiente `--only 5` lo pisaría.

```
config.sh + config.local.sh  ──fase 5──▶  etc/worldserver.conf
                                          etc/modules/<módulo>.conf
```

**`config.sh` y `config.local.sh`.** `config.sh` es la base común: todas las opciones,
con valores neutros (`REALM_IP="127.0.0.1"`, contraseñas de ejemplo). `config.local.sh`
es opcional, vive junto a él y sólo contiene asignaciones de Bash con lo propio de tu
instalación, por ejemplo:

```bash
REALM_IP="192.168.1.100"
ADMIN_ACCOUNT_PASS="una-clave-propia"
```

`config.sh` lo carga justo antes de calcular lo derivado de `AC_DIR`, así que cualquier
opción puede sobrescribirse ahí. Está en `.gitignore`, así que ni se sube ni se publica;
el asistente lo crea con permisos `600`. Cambiar `config.local.sh` o `config.sh` invalida
la reanudación de una instalación a medias, igual que cambiar `versions.lock`
(`--desde N` para elegir qué reaplicar). `AC_CONFIG_LOCAL=/ruta/otro.sh` apunta a otro
fichero.

**El `.conf.dist` es la referencia.** Cada programa declara *todas* sus claves,
con su valor por defecto y su comentario, en su `.conf.dist`:

| Qué | Dónde |
|---|---|
| Core | `~/azerothcore/env/dist/etc/worldserver.conf.dist` |
| Cada módulo | `~/azerothcore/modules/<módulo>/conf/*.conf.dist` |

Si una opción no está en `config.sh`, se lee ahí. Y si quieres gobernarla desde
`config.sh`, se añade una variable y una línea `set_conf_value` en
`05_configure_server.sh`.

#### El aviso de claves no declaradas

Desde el 01/09/2026, si la fase 5 intenta escribir una clave que **no existe**
en el `.conf`, avisa en rojo y la repite en un resumen al final:

```
[!!]  Clave 'MapUpdateThreadCount' NO declarada en worldserver.conf: se añade
      al final, pero comprueba que el programa la lea de verdad.
```

Ese aviso existe porque el instalador llevaba meses escribiendo claves que
ningún programa leía, sin que nadie se enterase: `MapUpdateThreadCount` (el
servidor corría con **un** hilo de mapas con 250 bots), `AllowTwoSide.Interaction.Trade`,
`AutoBalance.Raids`, `Playerbots.RandomBotMaxGearQuality`, `Transmogrification.Enabled`…
Como los `.conf` se copian de su `.dist`, que declara todas las claves reales,
"no estaba" significa casi siempre "no existe". **Si ves ese aviso, comprueba el
nombre contra el `.conf.dist` o el código.** Las dos únicas excepciones legítimas
(claves que mod-playerbots exige en `worldserver.conf` y que el dist del core no
declara) están en una lista blanca en `lib/utils.sh` y no avisan.

#### Aplicar un cambio

```bash
nano config.sh
./install.sh --only 5                 # reescribe los .conf y reaplica el SQL propio
sudo systemctl restart ac-worldserver # avisa 60 s a los jugadores, saveall y reinicia
```

Muchas opciones del core se recargan en caliente con `.reload config` desde el
juego, pero los módulos no suelen soportarlo: reiniciar es lo seguro.

---

### 2. Servidor: reino, tasas, facciones, rendimiento

Fichero destino: `etc/worldserver.conf`.

#### Reino

| `config.sh` | Clave | Notas |
|---|---|---|
| `REALM_NAME` | (tabla `realmlist`) | La escribe la fase 8, no el `.conf` |
| `REALM_IP` | (tabla `realmlist`) | `127.0.0.1` si juegas en la misma máquina |
| `REALM_TYPE` | `GameType` | 0 Normal · 1 PvP · 6 RP · 8 RP-PvP |
| `MAX_PLAYERS` | `PlayerLimit` | |
| `TIMEZONE` | (sistema, `timedatectl`) | Zona horaria de la máquina, `Europe/Madrid` (04/09/2026). La aplica la fase 1. Hasta entonces la VM iba en UTC: las fechas anteriores a las 08:40 del 04/09 en `adaptive_*` se convirtieron sumando dos horas; las de los logs antiguos y los documentos hasta esa hora están en UTC |

#### Tasas

| `config.sh` | Clave | Valor |
|---|---|---|
| `RATE_XP_KILL` | `Rate.XP.Kill` | 1.5 |
| `RATE_XP_QUEST` | `Rate.XP.Quest` | 1 |
| `RATE_XP_EXPLORE` | `Rate.XP.Explore` | 1 |
| `RATE_DROP_MONEY` | `Rate.Drop.Money` | 1 |
| `RATE_DROP_UNCOMMON` / `RARE` / `EPIC` | `Rate.Drop.Item.Uncommon` / `.Rare` / `.Epic` | 1 / 1 / 1 |
| `RATE_HONOR` | `Rate.Honor` | 2 |
| `RATE_REPUTATION` | `Rate.Reputation.Gain` | 3 |

#### Facciones (cross-faction)

Lo que el core **puede** hacer entre Alianza y Horda, con los nombres reales de
`WorldConfig.cpp`:

| `config.sh` | Clave | Qué permite |
|---|---|---|
| `ALLOW_TWO_SIDE_GROUPS` | `AllowTwoSide.Interaction.Group` | Grupos y bandas mixtos |
| `ALLOW_TWO_SIDE_GUILDS` | `AllowTwoSide.Interaction.Guild` | Hermandades mixtas |
| `ALLOW_TWO_SIDE_CHAT` | `AllowTwoSide.Interaction.Chat` **y** `.Channel` | Say/yell entre facciones, y los canales globales |
| `ALLOW_TWO_SIDE_TRADE` | `AllowTwoSide.Interaction.Auction` | La casa de subastas de la otra facción |

> ⚠️ **Lo que NO existe en el core**, por mucho que lo digan guías antiguas:
> correo entre facciones, `/quién` entre facciones, amigos entre facciones y el
> intercambio directo (`Trade`). Las variables `ALLOW_TWO_SIDE_MAIL` y
> `ALLOW_TWO_SIDE_WHO` siguen en `config.sh` por compatibilidad pero **no
> escriben nada**. Hasta el 01/09/2026 el instalador escribía cuatro claves
> inexistentes con ellas, y además olvidaba `.Interaction.Chat`: el chat cruzado
> que prometía estaba apagado.

El perfil SP usa `GameType = 0` (Normal): Alianza y Horda pueden seguir
enfrentándose por decisión propia y en los sistemas PvP, pero el mundo abierto
no fuerza el combate. Las otras claves del bloque (`.Arena`, `.Calendar`,
`AllowTwoSide.Accounts`) se quedan con el valor del dist.

**Correo** (desde el 23/09/2026): `MAIL_PUSH_INBOX_ON_DELIVERY=true` escribe
`Mail.PushInboxOnDelivery = 1`. El cliente guarda el buzón un minuto y no lo
vuelve a pedir; con esto, un correo que llega con el jugador conectado (el
aviso de `mod-update-notice`, la recompensa de congrats-on-level con las
bolsas llenas) aparece al abrir el buzón sin esperar ni hacer `/reload`.

#### Rendimiento

| `config.sh` | Clave / fichero | Valor | Notas |
|---|---|---|---|
| `MAP_UPDATE_THREADS` | `MapUpdate.Threads` | 4 | Hilos que actualizan los mapas. **Hasta el 01/09/2026 se escribía `MapUpdateThreadCount`, que no existe**: el servidor corría con 1 hilo y un núcleo al 93 %. Con 4, el worldserver pasa de 12 a 15 hilos |
| `VISIBILITY_DISTANCE_CONTINENTS` | `Visibility.Distance.Continents` | 160 | Yardas hasta las que un jugador ve en los continentes. El core trae 100; mod-world-bots suelta bots a 250, así que con 160 te cruzas con ellos antes. Más = más objetos que actualizar por jugador; no pasar de 180 |
| `MYSQL_BUFFER_POOL_GB` | `innodb_buffer_pool_size` en `mysqld.cnf` | 4 | Lo escribe la fase 1 |
| `BUILD_CORES` | (compilación) | `nproc - 1` | |

Otras opciones de rendimiento del core que **no** gobierna `config.sh` y se
dejan en su valor del dist: `PlayerSaveInterval` y `Respawn.DynamicRateCreature`
(1 = desactivado; con cualquier otro valor los respawns se aceleran cuando hay
más de ese número de jugadores —bots incluidos— en la zona). El respawn
dinámico se descartó a propósito el 01/09/2026: se quiere respawn vanilla.

#### Modo en espera (apagar el worldserver cuando no hay nadie)

| `config.sh` | Valor | Notas |
|---|---|---|
| `WORLDSERVER_STANDBY` | `true` | Interruptor maestro (por defecto **activado**). En `false` vuelve a la instalación clásica: screen + `Restart=always`, worldserver siempre encendido |
| `STANDBY_IDLE_MINUTES` | `15` | Minutos sin ninguna sesión humana antes de apagar el worldserver. Con `BOTS_NO_PLAYER_LOGOUT_DELAY=600` los bots ya han salido solos a los 10 |
| `STANDBY_WARN_SECONDS` | `60` | Cuenta atrás con aviso antes de cerrar. 0 = inmediato |
| `STANDBY_MIN_UPTIME_MINUTES` | `10` | El módulo no apaga el servidor durante estos minutos tras arrancar (cubre el cuelgue del primer arranque y da margen al jugador que lo despertó) |
| `STANDBY_CHECK_SECONDS` | `30` | Cada cuánto se cuenta la población humana |

Con `WORLDSERVER_STANDBY=true` (por defecto):

- `worldserver.conf` → `Network.UseSocketActivation = 1`, `Console.Enable = 0`.
- Una unidad **`ac-worldserver.socket`** posee el puerto 8085 desde el arranque
  de la VM y nunca se para. `ac-worldserver.service` ejecuta el binario
  directamente (sin `screen`), con `Restart=on-failure`; a la primera conexión
  de un cliente systemd lo arranca y le pasa el socket. Con la activación de
  socket el core **no** marca el reino como desconectado al cerrarse: el
  cliente lo sigue viendo seleccionable.
- El módulo propio **`mod-standby`** (se instala solo, sigue a
  `WORLDSERVER_STANDBY`) apaga el worldserver con salida limpia (código 0 →
  systemd no lo revive) cuando lleva `STANDBY_IDLE_MINUTES` sin jugadores
  humanos. `authserver`, MySQL, el panel y la VM siguen en pie.
- **Coste:** la PRIMERA conexión tras dormir tarda lo que tarde un arranque en
  frío (~1-2 min). Si el cliente 3.3.5a se cansa antes, vuelve a la lista de
  reinos y al reseleccionar el reino ya está arrancado. Las siguientes son
  instantáneas.
- El aviso de parada y el `saveall` van por SOAP (`scripts/ws-console.sh`), no
  por `screen`. Requiere el panel web instalado (activa SOAP).

Comando en el juego / consola: `.standby` (estado), `.standby ahora` (dormir
ya), `.standby mantener <min>` (suspenderlo para una sesión larga),
`.standby reanudar`.

---

### Experiencia por profesiones

La experiencia por profesiones se activa con `INSTALL_MOD_PROFESSION_EXPERIENCE`.
Las opciones `PROFESSION_XP_*` de `config.sh` fijan base, dificultad, curva y
bloqueo al tope profesional. Se instala con fases 3/4/5 y reinicio. Para ajustes
de valores basta fase 5 y `.reload config`; para retirar el módulo del binario,
poner el interruptor a `false`, ejecutar 3/4/5 y reiniciar. Configuración,
limitaciones e interacción con otros módulos:
«Experiencia por profesiones (SP01)» (REFERENCES.md).

### Sede de hermandad (SP02)

`INSTALL_MOD_GUILDHOUSE=true` instala el módulo fijado en `versions.lock`.
Las fases 3/4/5 clonan, parchean, compilan y configuran la sede; la fase 8
reaplica el SQL. El vendedor aparece junto a los NPC de servicio de las
capitales cuando `SPAWN_SERVICE_NPCS=true`. El líder compra la sede por 1.000
oros; los miembros entran mediante el vendedor, `.gh teleport` o la **Piedra
de la sede** (gratuita y reponible en el vendedor). Las tres vías usan un
lanzamiento de 10 segundos y una reutilización común de 30 minutos, separada
de la piedra de hogar normal. Se sale por el portal inicial a Ventormenta u
Orgrimmar, o por otros portales comprados; no se guarda el lugar de entrada.

El instalador añade el hechizo 600001 al `Spell.dbc` del servidor y el objeto
600001 a `acore_world`; el icono y el texto del cliente están en
`cliente/Data/{esES,enUS}/patch-<idioma>-4.MPQ`. Hay que cerrar completamente
`Wow.exe`, instalar el parche de cliente y volver a abrirlo para ver la piedra
correctamente.

**Centro de profesiones (SP07).** Con `INSTALL_MOD_REAGENT_BANK=true` el mayordomo vende además a Ling,
el banquero de materiales, por `GuildHouseReagentBank` (cobre; 1000000 = 100 oro, `-1` la oculta; se
aplica con `.reload config`, fijada en la fase 5). Su banco es de cada personaje y es el mismo que el de
las capitales. Con el módulo desactivado el mayordomo no la ofrece. Detalles técnicos y límites:
«Sede de hermandad (SP02)» (REFERENCES.md).

### 3. Bots: mod-playerbots, mod-queue-bots y mod-world-bots

#### 3.1 Población

Fichero: `etc/modules/playerbots.conf`. Todas las claves verificadas contra la
versión fijada (b949b50b, 04/09/2026; el `.conf.dist` no cambió desde 2f7d9f77): las 32 que escribe el instalador existen.

| `config.sh` | Clave | Valor | Por qué |
|---|---|---|---|
| `BOTS_MIN` / `BOTS_MAX` | `Playerbots.MinRandomBots` / `MaxRandomBots` | **500 / 600** (desde 03/09/2026; antes 400/500 y 200/250) | El módulo elige un objetivo entre los dos y lo cambia cada 30-120 min. **Es cuántos bots llegan a existir de verdad**: se despierta hasta ese tope y a cada bot se le tira el dado del nivel la primera vez; el resto se queda en la reserva a nivel 1. Se subió para que mod-world-bots tenga de dónde sacar bots de tu tramo sin vaciar el resto del mundo. El dist trae 500/500. **Pendiente de vigilar la memoria**: con 153 bots el worldserver ocupaba 3,7 GB |
| `BOT_ACTIVE_ALONE` | `BotActiveAlone` | 10 | Porcentaje de bots que simula de verdad lejos de cualquier jugador. Los de tu zona se despiertan siempre (`BotActiveAloneForceWhenInZone = 1`, del dist). Es lo que contiene el coste de 400-500 bots |
| `BOTS_PERIODIC_ONLINE_OFFLINE` / `BOTS_PERIODIC_RATIO` | `EnablePeriodicOnlineOffline` / `PeriodicOnlineOfflineRatio` | **true** / 2.0 (desde 02/09/2026) | Los bots entran y salen por turnos, como gente real: de un conjunto de 2 × `BOTS_MAX` (1000 de los 1500) hay `BOTS_MAX` conectados y van rotando. Con el tiempo se estrenan más bots y la población cambia de un día a otro |
| `BOTS_ACCOUNT_COUNT` | `Playerbots.RandomBotAccountCount` | 150 | 10 personajes por cuenta → 1500 bots en la reserva |
| `BOTS_LEVEL_MIN` / `MAX` | `RandomBotMinLevel` / `MaxLevel` | 1 / 80 | |
| `BOTS_DISABLED_WITHOUT_PLAYER` | `DisabledWithoutRealPlayer` | **true** | Los bots aleatorios solo aparecen con un jugador real. Al salir el último, se desconectan tras 10 minutos (`BOTS_NO_PLAYER_LOGOUT_DELAY=600`). |
| `BOTS_MAX_PER_PLAYER` | `MaxAddedBots` | 40 | Tope de bots propios en tu banda. Con 4 no se podía formar una banda, y con individual-progression la progresión **es** la banda |
| `BOTS_SELFBOT_LEVEL` | `SelfBotLevel` | 2 | Cualquiera puede usar sus alts como bots |
| `BOTS_GUILD_INVITE_PLAYER` | `RandomBotInvitePlayer` | true | Las hermandades de bots te invitan |
| `BOTS_LIMIT_TALENTS_EXPANSION` | `LimitTalentsExpansion` | true | Talentos acordes a la fase de progresión |

#### 3.2 Niveles

| `config.sh` | Clave | Valor | Por qué |
|---|---|---|---|
| `BOTS_MIN_LEVEL_CHANCE` | `RandomBotMinLevelChance` | 0.0 | Porcentaje clavado en el nivel mínimo. A 0 se reparten uniformemente |
| `BOTS_MAX_LEVEL_CHANCE` | `RandomBotMaxLevelChance` | 0.35 | El nivel máximo es el único tramo de **un solo nivel**: con reparto uniforme le tocaban 8 bots de 653, y a nivel 80 no salía ni un campo de batalla. Con 0.35 hay ~90 |
| `BOTS_SYNC_LEVEL_WITH_PLAYERS` | `SyncLevelWithPlayers` | **false** | Pega el nivel máximo de los bots al jugador más alto conectado. **Sin nadie conectado vale 1**: un re-aleatorizado con el servidor vacío dejaría a todos los bots a nivel 1. No activar |
| `BOTS_LEVEL_BRACKETS` | `LevelBrackets.Enabled` | **true** (desde 01/09/2026) | Reparte la población por franjas de 10 niveles y la sesga hacia la franja donde estás tú. Integrado en playerbots el 07/08/2026 (PR #2558); la versión anterior **no lo tenía** y la fase 5 lo comprueba con un `grep` antes de escribirlo |
| `BOTS_LEVEL_BRACKETS_DYNAMIC` | `LevelBrackets.Dynamic.UseDynamicDistribution` | **true** | El reparto dinámico pisa los porcentajes fijos y permite que la población siga al jugador real. Sin humanos conserva las nueve franjas uniformes |
| `BOTS_LEVEL_BRACKETS_HIGHEST_ONLY` | `LevelBrackets.Dynamic.HighestPlayerOnly` | **true** | Parche local: 100 % de ambas facciones en el bracket del humano conectado de mayor nivel. Tiene precedencia sobre la ponderación ordinaria |
| `BOTS_LEVEL_BRACKETS_SYNC_FACTIONS` | `LevelBrackets.Dynamic.SyncFactions` | **true** | Alianza y Horda siguen el mismo bracket |
| `BOTS_LEVEL_BRACKETS_PLAYER_WEIGHT` | `LevelBrackets.Dynamic.RealPlayerWeight` | 1000.0 | Respaldo si el parche faltase; con `HighestPlayerOnly` activo no decide el reparto |
| `BOTS_LEVEL80_PCT` | porcentajes `LevelBrackets.<facción>.Range*.Pct` | 0 | No impone ninguna cuota fija de nivel 80. `mod-adaptive-ai` está archivado |
| `BOTS_WORLD_TIME_MIN` / `_MAX` | `Playerbots.MinRandomBotInWorldTime` / `Max...` | 7200 / 28800 | Segundos que un bot se queda en el mundo antes de que se le pueda rotar |

> ⚠️ Para mover un bot de franja, LevelBrackets lo **re-rula entero** con
> `PlayerbotFactory::Randomize()`: nivel, equipo, talentos y misiones. Es el
> efecto de `rndbot init`, pero por goteo. A tu personaje no le afecta. Si los
> bots cambian demasiado, `BOTS_LEVEL_BRACKETS=false` y `--only 5`, sin recompilar.

#### 3.3 Equipo

| `config.sh` | Clave | Valor |
|---|---|---|
| `BOTS_MAX_GEAR_QUALITY` | `RandomGearQualityLimit` y `AutoGearQualityLimit` | 4 (épico) |
| `BOTS_GEAR_TWO_ROUNDS` | `TwoRoundsGearInit` | true |

Con 3 (azul) los bots de nivel 80 salían con 672 piezas azules de 738 y no
servían ni para Naxxramas ni para un campo de batalla. `RandomBotMaxGearQuality`,
que escribía el instalador antes, **no existe**.

#### 3.4 Colas: por qué está apagado el auto-apuntado

| `config.sh` | Clave | Valor |
|---|---|---|
| `BOTS_AUTO_JOIN_BG` | `RandomBotAutoJoinBG` | **false** |
| `BOTS_JOIN_LFG` | `RandomBotJoinLfg` | true |
| `BOTS_BG_ALL_BRACKETS` / `BOTS_BG_PER_BRACKET` | `RandomBotAutoJoin*Brackets` / `*Count` | true / 1 (sólo cuentan si el auto-apuntado está activo) |
| `BOTS_ARENA_RATED_2V2` / `3V3` / `5V5` | `RandomBotAutoJoinBGRatedArena*Count` | 2 / 2 / 1 |

El auto-apuntado de playerbots intenta llenar **una batalla por cada tramo de
cada campo de batalla** —24 a la vez— con los bots conectados: no llena ninguna,
y de la cola en la que estás tú no sabe nada. Lo sustituye **mod-queue-bots**
(módulo propio, `modules/mod-queue-bots/`): mira en qué cola te has puesto y
mete en *esa* los bots que faltan, del tramo de nivel que corresponda.

| `config.sh` | Clave (`mod_queue_bots.conf`) | Valor |
|---|---|---|
| `INSTALL_MOD_QUEUE_BOTS` | — | true |
| `QUEUE_BOTS_DELAY` | `QueueBots.DelaySeconds` | 0 |
| `QUEUE_BOTS_MAX_RAID` | `QueueBots.MaxRaidBots` | 39 |
| `QUEUE_BOTS_RAID_SIZE` | `QueueBots.RaidSize` | 0 (según la dificultad) |
| `QUEUE_BOTS_RAID_TANKS` / `HEALERS` | `QueueBots.RaidTanks` / `RaidHealers` | 0 (según el tamaño) |
| `QUEUE_BOTS_RAID_SUMMON_DELAY` | `QueueBots.RaidSummonDelay` | 8 s: el bot que entra en tu banda se teletransporta a tu lado pasados esos segundos (más 0-3 de azar), nunca en combate. 0 = nunca |
| `QUEUE_BOTS_DUNGEON_CLEAR_AUTO` / `DELAY` | `QueueBots.DungeonClearAuto` / `DungeonClearDelay` | true / 10 s: con el grupo del buscador dentro de la mazmorra, manda `.dc on` en tu nombre (§4.5). Nunca si tú eres el tanque |
| `QUEUE_BOTS_WAKE` / `WAKE_MAX` | `QueueBots.WakeBots` / `WakeMax` | true / 40 |
| `QUEUE_BOTS_FORCE_ACCEPT_AFTER` | `QueueBots.ForceAcceptAfter` | 40 s |

Cómo funciona por dentro, y lo que costó que funcionara: `REFERENCES.md`.

#### 3.5 Lo que se queda con el valor del dist

Merece la pena conocerlas aunque `config.sh` no las toque:

- `Playerbots.BotActiveAloneForceWhenInZone = 1`: los bots de tu zona simulan
  siempre al 100 %, estén donde estén dentro de ella. Es lo que hace que los
  que trae mod-world-bots se muevan de verdad. (`BotActiveAlone`, el porcentaje
  para los que están lejos, ya lo gobierna `BOT_ACTIVE_ALONE`: §3.1.)
- `Playerbots.EnableGreet = 0`, `RandomBotEmote = 0`, `RandomBotSayWithoutMaster = 0`:
  los bots no saludan ni gesticulan. Decidido así el 01/09/2026.
- `Playerbots.MinRandomBotTeleportInterval = 3600` / `Max = 18000`: un bot cambia
  de zona cada 1-5 horas.
- Los textos que dicen los bots (`ai_playerbot_texts`, 1908 filas) **están en
  español desde el 02/09/2026**: 1062 ya venían traducidos en la versión fijada
  y las 846 restantes están en `patches/locales-es-playerbots/`, que la fase 5
  aplica a `acore_playerbots` con `LOCALE_ES=true`. Los bots hablan en el
  idioma del cliente (`DBC.Locale`), así que con cliente esES se ven en español.

#### 3.6 Tu zona no está vacía: mod-world-bots

Con 400 bots entre 80 niveles y ~90 combinaciones de zona y facción, a cada
zona le tocan dos o tres. playerbots mueve a cada bot **dentro de su zona** y
lo cambia de zona al azar cada 1-5 horas; de dónde estás tú sólo sabe para
despertar a los que ya estaban allí. LevelBrackets arregla el nivel, no la
zona. **mod-world-bots** (módulo propio, `modules/mod-world-bots/`) cuenta al
entrar en una zona los bots de tu tramo que hay en ella y trae los que falten
a puntos de caza a más de 250 yardas de ti.

| `config.sh` | Clave (`mod_world_bots.conf`) | Valor | Notas |
|---|---|---|---|
| `INSTALL_MOD_WORLD_BOTS` | — | true | Requiere playerbots. Recompilar al cambiarlo |
| `WORLD_BOTS_MIN` / `MAX` | `WorldBots.MinBots` / `MaxBots` | 15 / 30 (el dist del módulo trae 12/25) | Objetivo para la zona completa, al azar entre ambos valores cada vez que entras; no es una cuota por radio. Sólo cuentan bots de tu tramo |
| `WORLD_BOTS_LEVEL_BELOW` / `ABOVE` | `WorldBots.LevelBelow` / `LevelAbove` | 5 / 3 | Tramo: [nivel−5, nivel+3] |
| `WORLD_BOTS_MIN_DISTANCE` | `WorldBots.MinDistance` | 250 | Yardas entre tú y donde se suelta a un bot. Mínimo admitido 150 (por debajo lo verías aparecer); si la zona no tiene ningún punto tan lejos, se usa 150 |
| `WORLD_BOTS_OPPOSITE_SHARE` | `WorldBots.OppositeFactionShare` | 0.35 | En zonas contestadas, parte del objetivo de la facción contraria. En zonas de una facción, todos de ella (sea la tuya o no) |
| `WORLD_BOTS_MAX_PER_PASS` | `WorldBots.MaxPerPass` | 5 | Teletransportes por pasada, cada 15 s hasta el objetivo: sin oleadas |
| `WORLD_BOTS_TOPUP_SECONDS` | `WorldBots.TopUpSeconds` | 60 | Con la zona llena, cada cuánto se repone |
| `WORLD_BOTS_WAKE` / `WAKE_MAX` | `WorldBots.WakeBots` / `WakeMax` | true / 20 | Encender dormidos si no hay bastantes libres de tu tramo |
| `WORLD_BOTS_ANNOUNCE` | `WorldBots.Announce` | false | Avisar por chat de cuántos han llegado |
| `WORLD_BOTS_CITY_MIN` / `MAX` | `WorldBots.CityMinBots` / `CityMaxBots` | 30 / 50 | **Capitales** (desde 02/09/2026): no tienen puntos de caza, así que los bots se sueltan delante de sus NPC de servicio (posaderos, banco, subastas, vendedores, entrenadores, maestros de vuelo), de cualquier nivel |
| `WORLD_BOTS_CITY_MIN_DISTANCE` | `WorldBots.CityMinDistance` | 150 | Las ciudades son pequeñas; 150 es el mínimo admitido |
| `WORLD_BOTS_STAGE` | `WorldBots.Stage.Enable` | true | Con un jugador, los bots aleatorios respetan el tope y mapas de la etapa más alta conectada; sin jugadores, sin restricción. Todos los que superan el tope se re-aleatorizan: no existe reserva de entrenamiento en Dalaran. `.wbots etapa` lo enseña |
| `WORLD_BOTS_STAGE_TBC_FROM` / `_WOTLK_FROM` | `WorldBots.Stage.TbcFrom` / `.WotlkFrom` | 8 / 13 | Nivel de progresión desde el que la etapa es TBC (PRE_TBC) y WotLK (TBC_TIER_5) |
| `WORLD_BOTS_STAGE_VANILLA_CAP` / `_MAPS`, `_TBC_CAP` / `_MAPS` | `WorldBots.Stage.VanillaCap` ... | 60 / 0,1 / 70 / 0,1,530 | Tope y mapas de cada etapa inferior |
| `WORLD_BOTS_STAGE_PER_PASS` | `WorldBots.Stage.PerPass` | 3 | Bots recolocados o re-aleatorizados por pasada de 5 s |
| — | `WorldBots.CityZones` | las 8 capitales + Shattrath y Dalaran | Ids de zona que se tratan como ciudad. Sólo en el `.conf.dist` |
| `VISIBILITY_DISTANCE_CONTINENTS` | `Visibility.Distance.Continents` (worldserver) | 160 | El core trae 100. Con bots a 250 yardas, verlos antes de llegar. Va en §2 pero es por esto |

Los puntos de caza son celdas de 50 yardas con al menos dos bichos normales con
botín (el criterio de la propia caché de destinos de playerbots), indexados
por zona una vez al arrancar: la línea `[world-bots] N puntos de caza en M
zonas` del `Server.log`. Ciudades y zonas sin bichos no se pueblan (lo dice el
log la primera vez). Cómo funciona por dentro: `REFERENCES.md`.

Al llegar, a cada bot se le cambia el estado de su estrategia de rol: en el
campo, "cazar alrededor de donde llego"; en la ciudad, "decidir de nuevo"
(pasea entre los NPC). Sin eso, su estrategia se lo llevaba de vuelta a donde
iba antes.


**Guerra de mundo** (`WorldBots.Pvp.*`, desde 02/09/2026, noche):

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `WORLD_BOTS_PVP` | `WorldBots.Pvp.Enable` | true | Escaramuzas y duelos en puntos calientes |
| `WORLD_BOTS_PVP_TICK_SECONDS` / `_CHANCE` | `TickSeconds` / `EventChancePerTick` | 60 / 1.5 | 1,5 % por minuto; admite decimales |
| `WORLD_BOTS_PVP_MAX_ACTIVE` | `MaxActiveEvents` | 1 | Con un jugador, uno |
| `WORLD_BOTS_PVP_ONLY_WITH_PLAYER` | `OnlyWithPlayerInZone` | true | Una guerra que nadie ve es CPU |
| `WORLD_BOTS_PVP_MIN_LEVEL` / `_MAX_PER_SIDE` | `MinLevel` / `MaxBotsPerSide` | 20 / 8 | Nivel mínimo global y tope por bando |
| `WORLD_BOTS_PVP_MOVE_DELAY` | `MoveDelaySeconds` | 15 | Reunión antes de avanzar |
| `WORLD_BOTS_PVP_DUELS` / `_DUEL_PAIRS` | `Duels` / `DuelPairs` | true / 4 | Duelos a las puertas de las capitales |
| `WORLD_BOTS_PVP_ANNOUNCE` | `Announce` | true | "La Horda marcha sobre Costasur" a los de la zona |

Los puntos calientes viven en `acore_world.world_bots_pvp_hotspot` (23 filas,
`REFERENCES.md`); `.wpvp recargar` los vuelve a leer sin reiniciar.

#### 3.7 Compañeros de misión: mod-quest-mates

Al aceptar una misión, dos o tres bots de tu zona, de tu facción y de tu tramo
de nivel la cogen también (si el núcleo dice que pueden: nivel, raza, clase,
requisitos previos, hueco en el diario) y su estrategia de rol se pone con
ella. Los mismos bots repiten contigo mientras sigan en la zona. Fuera quedan
las de mazmorra, banda, escolta, JcJ, heroicas, diarias, repetibles y de evento.

| `config.sh` | Clave (`mod_quest_mates.conf`) | Valor |
|---|---|---|
| `INSTALL_MOD_QUEST_MATES` | — | true |
| `QUEST_MATES_MIN` / `MAX` | `QuestMates.MinMates` / `MaxMates` | 2 / 3 |
| `QUEST_MATES_LEVEL_BELOW` / `ABOVE` | `QuestMates.LevelBelow` / `LevelAbove` | 5 / 3 |
| `QUEST_MATES_CHANCE` | `QuestMates.Chance` | 100 % |
| `QUEST_MATES_REMEMBER_MINUTES` | `QuestMates.RememberMinutes` | 30 |
| `QUEST_MATES_ANNOUNCE` | `QuestMates.Announce` | false |

En el log: `[quest-mates] X, Y cogen 'misión' con Jugador`, o quién no pudo y
por qué.

---

#### 3.8 Equipo de los bots de tu grupo (desde 02/09/2026)

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `QUEUE_BOTS_GEAR_MODE` | `QueueBots.GearMode` | 1 | 0 no tocar; 1 tu media + margen sin pasar del tope de tu fase; 2 sólo el tope de la fase |
| `QUEUE_BOTS_GEAR_MARGIN` | `QueueBots.GearMargin` | 6 | Niveles de objeto por encima de tu media |
| `QUEUE_BOTS_GEAR_TOLERANCE` | `QueueBots.GearTolerance` | 8 | Sólo se reequipa fuera de ±tolerancia |
| `QUEUE_BOTS_GEAR_MIN_ILVL` | `QueueBots.GearMinItemLevel` | 0 | Suelo, por si vas en verdes a 80 |
| `QUEUE_BOTS_TOKEN_TURNIN` | `QueueBots.TokenTurnIn` | true | `.tokenturnin redeem` en tu nombre tras cada jefe (necesita mod-token-turnin) |
| `QUEUE_BOTS_TOKEN_TURNIN_DELAY` | `QueueBots.TokenTurnInDelay` | 90 | Segundos para que acaben las tiradas |

Se aplica a la banda del tablón al unirse cada bot y a cualquier grupo tuyo al
entrar en una instancia (mazmorra o banda, vengan del buscador o de
`mod-party-here`). Las mismas cuatro claves existen con el prefijo
`PartyHere.` para los grupos de ese módulo. Los topes por fase están en
`REFERENCES.md` (cabeceras compartidas).

#### 3.9 Grupo donde estás: mod-party-here

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `PARTY_HERE_LEVEL_BELOW` / `_ABOVE` | `PartyHere.LevelBelow` / `LevelAbove` | 3 / 0 | Ninguno por encima: te robaría la experiencia |
| `PARTY_HERE_MAX_RAID_BOTS` | `PartyHere.MaxRaidBots` | 39 | Tope de `.grupo banda`; nunca por encima de `MaxAddedBots` |
| `PARTY_HERE_AUTO_GROUP_QUESTS` | `PartyHere.AutoGroupQuests` | true | Misiones con jugadores sugeridos |
| `PARTY_HERE_AUTO_MAX_BOTS` | `PartyHere.AutoMaxBots` | 2 | Tope de bots automáticos |
| `PARTY_HERE_AUTO_LINGER_SECONDS` | `PartyHere.AutoLingerSeconds` | 120 | Cuánto se quedan cuando ya no hacen falta |
| `PARTY_HERE_SUMMON_DELAY` | `PartyHere.SummonDelay` | 3 | Segundos hasta traerlos a tu lado (0 = andando) |
| `PARTY_HERE_WAKE` / `_WAKE_MAX` | `PartyHere.WakeBots` / `WakeMax` | true / 20 | Despertar dormidos si faltan |
| `PARTY_HERE_ANNOUNCE` | `PartyHere.Announce` | true | Quién entra y quién se va, por chat |

#### 3.10 Tu hermandad: mod-home-guild

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `HOME_GUILD_LEGACY_NAME` | `HomeGuild.LegacyName` | "Companeros de {name}" | Firma de nombre usada sólo para reconocer la versión automática antigua |
| `HOME_GUILD_LEGACY_MOTD` | `HomeGuild.LegacyMotd` | (texto) | Segunda parte de la firma antigua; no cambia el MOTD de una guild nueva |
| `HOME_GUILD_CLEANUP_LEGACY` | `HomeGuild.CleanupLegacyAutoGuilds` | true | Disolver una vez las guilds automáticas antiguas identificadas con la firma completa |
| `HOME_GUILD_MEMBERS` | `HomeGuild.Members` | 15 | 30 si vas a hacer bandas de 25 con la hermandad |
| `HOME_GUILD_LEVEL_BELOW` / `_ABOVE` | `HomeGuild.LevelBelow` / `LevelAbove` | 3 / 2 | Tramo de los reclutas |
| `HOME_GUILD_KEEP_ONLINE` | `HomeGuild.KeepOnline` | true | Conectarlos contigo, de cinco en cinco cada 15 s |
| `HOME_GUILD_RELEVEL` / `_RELEVEL_BEHIND` | `HomeGuild.ReLevel` / `ReLevelBehind` | true / 4 | Subirles el nivel cuando se queden atrás |
| `HOME_GUILD_ANNOUNCE` | `HomeGuild.Announce` | true | El resumen al entrar |

El módulo no crea ni adopta guilds y tampoco cambia
`Playerbots.RandomBotInvitePlayer`: el jugador conserva ambas decisiones.

**Fundar la hermandad de partida.** Blizzard exige 9 firmas en la carta (10
personajes en total con el fundador) para fundar una guild — en single
player nunca hay 9 jugadores de tu facción disponibles para firmar, y los
bots aleatorios rechazan la firma si no calzan con tu facción en ese
instante, así que la fundación nunca se completaba. `GUILD_MIN_PETITION_SIGNS`
(config.sh, sección "HERMANDADES") escribe `MinPetitionSigns` — una clave del
core, no de este módulo — a 0, para que el jugador funde solo. `mod-home-guild`
no interviene en la fundación en sí: solo empieza a reclutar y cuidar la
hermandad después de que ya exista.

### 4. Instancias

#### 4.1 mod-autobalance

Fichero: `etc/modules/AutoBalance.conf`. Nombres verificados contra
`src/` del módulo (01/09/2026): las claves `AutoBalance.enable` (minúscula),
`AutoBalance.rate.global.*` y `AutoBalance.rate.health/damage` están en la
sección **deprecated** del dist y el módulo sólo las lee para avisar de que ya
no sirven; `AutoBalance.Raids` no ha existido nunca. Hasta el 01/09/2026 el
instalador escribía justo esas, y el escalado corría con los valores de fábrica.

| `config.sh` | Claves reales | Valor |
|---|---|---|
| `AUTOBALANCE_ENABLED` | `AutoBalance.Enable.Global` | true |
| `AUTOBALANCE_RAIDS` | `AutoBalance.Enable.10M` `.15M` `.20M` `.25M` `.40M` `.10MHeroic` `.25MHeroic` | true |
| `AUTOBALANCE_INFLECTION` | `AutoBalance.InflectionPoint` | 0.5 |
| `AUTOBALANCE_RATE_HEALTH` | `AutoBalance.StatModifier.Health`, `StatModifierHeroic.Health`, `StatModifierRaid.Health`, `StatModifierRaidHeroic.Health` | 1.0 |
| `AUTOBALANCE_RATE_DAMAGE` | Ídem con `.Damage` | 1.0 |

Las de 5 jugadores (`Enable.5M`, `.5MHeroic`, `.OtherNormal`, `.OtherHeroic`)
las gobierna sólo el interruptor global. Los modificadores por tamaño concreto
(`StatModifierRaid10M.*`…) se dejan en blanco y heredan de su familia.

Comandos: `.ab mapstat` (estado del mapa), `.ab creaturestat` (del bicho
seleccionado).

#### 4.2 mod-dungeon-master (⚠️ early development)

Fichero: `etc/modules/mod_dungeon_master.conf`. Todas sus claves llevan el
prefijo `DungeonMaster.`; sin él se ignoran en silencio. Se gobierna entero desde
`config.sh` con las variables `DM_*` (escalado en solitario y por jugador,
multiplicadores de jefe y élite, modo Roguelike y recompensas). Ver la sección
correspondiente de `config.sh`, que las explica una a una.

Su NPC aparece en las once capitales y es el **ancla** de los NPC de servicio
(§8). Si lo desactivas (`INSTALL_MOD_DUNGEON_MASTER=false`) la fase 3 lo aparta a
`modules-disabled/` y limpia sus rastros de la base de datos; los NPC de
servicio pasan a colocarse junto a los posaderos de Ventormenta y Orgrimmar.

El módulo consulta la columna `id1`, que AzerothCore ya no usa: el instalador
lo corrige con un `sed` (`patch_dungeon_master_id1_bug` en `lib/utils.sh`).

#### 4.3 mod-instanced-worldbosses

| `config.sh` | Clave | Valor |
|---|---|---|
| `IWB_RESET_TIMER_SECS` | reset del jefe | 25920 (3 días) |
| `IWB_RESPAWN_TIMER_SECS` | reaparición tras morir | 3600 |
| `IWB_PHASE_BOSSES` | saca de fase al grupo | true — **el que importa con bots**: el jefe es sólo vuestro |

#### 4.4 mod-instance-reset

De fábrica es gratis (`TransactionType = 0`), lo que permite granjear la misma
banda en bucle. Se cobra a propósito: `INSTANCE_RESET_PAYMENT=2` (oro),
`INSTANCE_RESET_MONEY=2500000` (250 oro). Variables `INSTANCE_RESET_*`.

#### 4.5 mod-dungeon-clear (desde 02/09/2026)

El tanque bot lleva la mazmorra de punta a punta: ruta entre jefes, pulls,
eventos con guion, botín, descanso, resurrección. Revisado su código antes de
instalarlo (`CHANGELOG.md` (anexo A5)): **espera al jugador humano** (a más de 25 yardas,
sin vida o maná, muerto) sin límite de tiempo en el modo por defecto. Tú no
puedes ser el tanque. Comandos: `.dc on/off/pause/skip/status/bosses/go/wing/spectate` (`.dc on|wing <ala>` elige
el ala en Roca Negra: `lbrs`/`ubrs`, `brd-db`/`brd-uc`).

| `config.sh` | Clave (`mod_dungeon_clear.conf`) | Valor | Por qué |
|---|---|---|---|
| `INSTALL_MOD_DUNGEON_CLEAR` | `DungeonClear.Enable` | true / 1 | Fijado en `versions.lock` (`07f8e33`, 12/10/2026). Es el módulo más frágil ante actualizaciones de playerbots. Su llenado de la cola del buscador (`DungeonClear.DungeonQueueFill.*`, desde 03/09) y el de campos de batalla (`DungeonClear.BgQueueFill.*`, desde 01/10/2026) se quedan apagados: eso lo hace mod-queue-bots |
| `DUNGEON_CLEAR_WAIT_AT_BOSS` | `DungeonClear.WaitAtBoss` | false | Con true, pausa antes de cada jefe hasta que digas `.dc pause` |
| `DUNGEON_CLEAR_SMART_REST` | `DungeonClear.SmartRest` | **false** | El descanso inteligente sigue adelante a los 3 minutos aunque estés AFK; el clásico espera a que tengas vida y maná, sin límite |
| `DUNGEON_CLEAR_REZ_TIMEOUT` | `DungeonClear.PostCombatRezTimeoutSecs` | 180 | Segundos fuera de combate para la recuperación por resurrección antes de rendirse (el dist trae 90) |

Se activa solo: `mod-queue-bots` manda `.dc on` en tu nombre cuando el grupo
del buscador está dentro (§3.4). Todo lo demás (pulls, rutas, botín, más de
cien claves) queda con los valores del `.conf.dist`; admiten sufijo `.Heroic`.

---

### 5. Progresión

#### 5.1 mod-individual-progression

Fichero: `etc/modules/individualProgression.conf`. Requiere en
`worldserver.conf` `EnablePlayerSettings = 1`, `Updates.EnableDatabases = 7` y
**`DBC.EnforceItemAttributes = 0`** — sin esta última, la restauración de
estadísticas vanilla de los objetos no se aplica y no avisa nadie. Las tres las
escribe la fase 5.

Las variables `IP_*` de `config.sh` fijan el ritmo: empezar en Vanilla sin tope
(`IP_STARTING_PROGRESSION=0`, `IP_PROGRESSION_LIMIT=0`), sin separar por fase a
los que juegan juntos (`IP_ENFORCE_GROUP_RULES=false`), buscador de mazmorras
activo (`IP_DISABLE_RDF=false`), jefes de Naxx40 superables en grupo pequeño
(`IP_DOABLE_NAXX40_*`), ajustes de poder y sanación de cada expansión, runas de
Núcleo de Magma, requisitos de ZG/ZA, desbloqueo de razas TBC y Caballero de la
Muerte, y el divisor de rangos PvP (`IP_PVP_RANK_DIVISOR=4`: rango 1 con 25
muertes, rango 14 con 6000).

**SQL opcional del módulo** (`IP_OPTIONAL_SQL`): `small_group_adjustments`
(escrito para bandas de 40 con grupo pequeño y bots), `vanilla_models`,
`restore_rogue_poisons`, `vanilla_crafting_requirements`. Los 22 disponibles
están en `optional/sql/world/` del módulo.

**DBC opcionales** (`IP_OPTIONAL_DBC=true`): hechizos, recetas y reactivos de
Vanilla/TBC. `SkillRaceClassInfo.dbc` **no se copia si ARAC está activo**: los
dos módulos traen ese fichero y manda el de ARAC. Se copian al final de la
fase 5, después de los datos del cliente (originales en `dbc/backup-pre-ip/`),
y la fase 8 lo repite como red de seguridad; el doctor (`server-dbc`) avisa si
faltan. Paso de cliente opcional: `patch-V.mpq` en `Data/`.

Comandos: `.ip get <nombre>`, `.ip set <nombre> <fase>` (también `.ip tele`, `.ip attune`, `.ip pvp`).

#### 5.2 mod-war-effort

Esfuerzo de Guerra de Ahn'Qiraj: 5 materiales × 5 fases × 2 facciones = 50
claves que la fase 5 escribe en bucle desde `WAR_EFFORT_GOALS=(5 10 15 20 25)`
y `WAR_EFFORT_GOAL_SCALE=1`. Con la escala a 1 lo completa un solo jugador.

#### 5.3 mod-challenge-modes

Desafíos por personaje (Hardcore, Semi-Hardcore, Sólo Fabricado, Calidad de
objeto, XP lenta y muy lenta, Sólo XP de misiones, Iron Man) que se activan a
nivel 1 en el *Santuario del Desafío* junto al cementerio de las 9 zonas
iniciales. `CM_<DESAFÍO>` activa cada uno, `CM_TALENTS_<DESAFÍO>` da la
recompensa en puntos de talento y `CM_XP_MULT_<DESAFÍO>` el multiplicador de XP.

Necesita `patches/mod-challenge-modes/01-hook-onplayerresurrect.patch` para
compilar contra este core (el hook `OnPlayerResurrect` es `bool&`; verificado
que sigue así en el core del 04/09/2026). Sus textos van incrustados en el
código, algunos en chino: no se traduce a propósito.

#### 5.4 mod-pvp-titles (desactivado)

`INSTALL_MOD_PVP_TITLES=false`. Duplica el sistema de títulos vanilla de
individual-progression con umbrales mucho más bajos y anula su diseño por
fases.

---

### 6. Economía y servicios

#### 6.1 mod-ah-bot-plus

Fichero: `etc/modules/mod_ahbot.conf` (**no** `mod_ahbotplus.conf`; es el mismo
nombre que usaría el bot nativo y un "conf mínimo" para silenciarlo machacaba los
72 KB de configuración real).

El instalador crea la cuenta de servicio (`AH_BOT_ACCOUNT`, con verificador
aleatorio: nadie puede entrar con ella) y dos vendedores (`AH_BOT_CHAR_ALLIANCE`,
`AH_BOT_CHAR_HORDE`, GUID desde `AH_BOT_GUID_BASE=9000001`) y escribe sus GUID en
`AuctionHouseBot.GUIDs`. Resto: `AH_ITEMS_PER_CYCLE` (`ItemsPerCycle`, 75),
`AH_BUYER_ENABLED` (`Buyer.Enabled`), `AH_BUYER_CANDIDATES_PER_CYCLE`,
`AH_BUYER_PRICE_MODIFIER`, `AH_BUYER_BID_AGAINST_PLAYERS`, `AH_SELL_EPICS` (pone
a 0 las proporciones épicas de armas y armaduras; no existe una clave "épicos
sí/no").

La subasta tarda horas en llenarse: `.ahbot update` 5-10 veces con el GM la
llena al momento. `.ahbot reload` recarga el conf, `.ahbot empty` la vacía.

#### 6.2 mod-transmog

Fichero: `etc/modules/transmog.conf`. La clave de activación es
`Transmogrification.Enable` (**sin** "d"; hasta el 01/09/2026 se escribía
`Enabled`, que no existe — el módulo funcionaba porque el dist ya la trae a 1).

| `config.sh` | Clave |
|---|---|
| `TRANSMOG_MIXED_WEAPONS` | `Transmogrification.AllowMixedWeaponTypes` |
| `TRANSMOG_ALLOW_HIDDEN` | `Transmogrification.AllowHiddenTransmog` |
| `TRANSMOG_COST` | `Transmogrification.CopperCost` |

El NPC (entrada 190010) se coloca solo en las once capitales (§8). Desde la
versión del 26/07/2026 existe `.transmog claim` para coleccionar apariencias
desde las bolsas, con sus textos ya en español.

#### 6.3 mod-random-enchants

Fichero: `etc/modules/random_enchants.conf`. `RANDOM_ENCHANTS_ANNOUNCE` gobierna
el aviso al entrar. El resto (`OnLoot`, `OnCreate`, `OnQuestReward`,
`OnGroupRoll`, `EnchantChance1..3`) se queda con el dist.

**Escalado por nivel** (`RANDOM_ENCHANTS_SCALE_WITH_LEVEL=true`,
`RANDOM_ENCHANTS_TIER{2..5}_MIN_LEVEL` = 20/40/60/71): lo añade
`patches/mod-random-enchants/01-level-scaled-tiers.patch`. El módulo original
sorteaba el tier sin mirar el nivel, y además su consulta tenía un `= NULL` y
un `AND`/`OR` sin paréntesis que anulaban el filtro de tier. Desde el 01/09/2026
el parche también declara las cinco claves en el `.conf.dist`, para que la fase 5
no las marque como no declaradas.

#### 6.4 mod-congrats-on-level

Tres mensajes distintos, cada uno con su interruptor (desde 02/09/2026):

| `config.sh` | Clave (`mod_congratsonlevel.conf`) | Valor | Qué apaga |
|---|---|---|---|
| `CONGRATS_LOGIN_ANNOUNCE` | `Congrats.Announce` | **false** | El aviso del módulo al conectar |
| `CONGRATS_LEVEL_MESSAGE` | `CongratsPerLevel.Enable` | true | "[FELICITACIONES!] X ha alcanzado el nivel N" a todo el servidor, en cada nivel |
| `CONGRATS_REWARD_MESSAGE` | `Congrats.RewardMessage` | **false** | El mensaje de la recompensa (el mismo anuncio otra vez, más el aviso de banda "Se le ha concedido N cobre..."). El módulo lo tenía fijo en el código; lo aporta `patches/mod-congrats-on-level/02-reward-message-toggle.patch` |
| `CONGRATS_IGNORE_BOTS` | `Congrats.IgnoreBots` | **true** | Los bots pasan por el mismo hook: cada bot que subía de nivel recibía premio y se anunciaba a todo el servidor. Era lo que "seguía apareciendo" tras apagar lo anterior. Mismo parche |

Recompensas al subir de nivel. Las recompensas **no** están en el `.conf` sino
en la tabla `mod_congrats_on_level_items` de `acore_world`, que la fase 5 carga
desde `congrats_on_level_rewards.sql` (columnas `level`, `money` en **oro**,
`spell`, `learn`, `itemId1`, `itemId2`, `race`, `class`). El parche
`patches/mod-congrats-on-level/01-reward-any-level.patch` quita el `switch` que
sólo premiaba en múltiplos de 10, y `03-mail-when-bags-full.patch` manda por
correo lo que no cabe en la bolsa. Qué da cada nivel y por qué: comentado en el
propio SQL y resumido en `REFERENCES.md` (tabla v3 del 02/09/2026:
bolsas, equitación, doble especialización a 40, vuelo en clima frío a 77).

#### 6.5 Servicios

| Módulo | Conf | `config.sh` | NPC |
|---|---|---|---|
| mod-racial-trait-swap | `RacialTraitSwap.conf` | `RACIAL_SWAP_GOLD` | 98888 |
| mod-reagent-bank | `reagent_bank.conf` | — | 290011 |
| mod-aoe-loot | `mod_aoe_loot.conf` | `AOE_LOOT_RANGE`, `AOE_LOOT_GROUP` | — |
| mod-quest-loot-party | `mod-quest-loot-party.conf` | `QUEST_LOOT_PARTY_ENABLE`, `QUEST_LOOT_PARTY_MESSAGE` | — |
| mod-1v1-arena | `1v1arena.conf` | `ARENA_1V1_*` (nivel 80) | 999991 |

---

#### 6.6 mod-world-buff-bots y mod-token-turnin (desde 02/09/2026)

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `WORLD_BUFF_BASE_MINUTES` / `_VARIANCE_MINUTES` | `WorldBuffBots.BaseMinutes` / `VarianceMinutes` | 90 / 60 | Cada buff salta cada 30-150 min, independiente |
| `WORLD_BUFF_WARCHIEF` / `_DRAGONSLAYER` / `_ZANDALAR` | `WorldBuffBots.<X>.Enable` | true | Orgrimmar (y el Cruce), Ventormenta, Stranglethorn |
| `WORLD_BUFF_*_TEXT` | `WorldBuffBots.<X>.Announcement` | español | `{player}` es el nombre inventado del anunciante |
| `TOKEN_TURNIN_INCLUDE_SELF` | `TokenTurnIn.IncludeSelf` | false | Tus tokens son cosa tuya; el módulo es para los bots |

`TokenTurnIn.IncludeRealPlayers` queda siempre a 0. El comando es
`.tokenturnin check` (mirar) y `.tokenturnin redeem` (canjear); lo manda
queue-bots solo tras cada jefe (§3.8). Su tabla `mod_token_turnin_tokens`
(121 filas, T3 a T8 más ZG/AQ20) va en `acore_world` y la aplica la fase 5.

#### 6.7 Tesoros itinerantes (SP03)

`INSTALL_MOD_TREASURE=true` incorpora el módulo propio en la fase 3, lo compila
en la 4 y aplica configuración, catálogo y botín en la 5. La fase 8 reaplica el
SQL idempotente. Los 57 catálogos de zona empiezan activos. Al entrar un humano,
el módulo comprueba suelo, agua, visión y ruta de candidatos próximos antes de
asignar un cofre; examina como máximo ocho cada diez segundos y guarda cada
resultado. `.tesoro estado` muestra puntos y plazos; un GM puede forzar más
comprobaciones con `.tesoro validar` o retirar cofres con `.tesoro desactivar`.
La siguiente fase 5/8 reactiva las zonas desactivadas manualmente.

`TREASURE_LOCATION_SECONDS=3600` limita la estancia sin recogida. Los valores
`TREASURE_BASIC_RESPAWN_SECONDS=1800`, `TREASURE_RARE_RESPAWN_SECONDS=5400` y
`TREASURE_EPIC_RESPAWN_SECONDS=14400` rigen la reposición tras apertura o
saqueo. `TREASURE_CANDIDATE_RADIUS=250` y `TREASURE_SCAN_MS=5000` limitan el
trabajo del controlador; `TREASURE_SPAWN_SPELL=30262` lanza la bengala blanca
al aparecer. `TREASURE_ENABLE=true` permite al módulo cargar sus zonas.
Detalles del validador, límites y tablas en «mod-treasure: tesoros itinerantes (SP03)» (REFERENCES.md).

### 7. Razas y clases (ARAC)

`INSTALL_MOD_ARAC=true`. No es un módulo de compilación: vive en
`~/azerothcore/extras/mod-arac/`. El instalador aplica su SQL, copia sus DBC al
servidor al final de la fase 5, cuando ya existen los datos del cliente (con
copia de seguridad en `dbc/backup-pre-arac/`; la fase 8 lo repite y el doctor
compara byte a byte en `server-dbc`), y encima aplica
tres correcciones que el upstream tiene **sin mergear** (`patches/arac/`): equipo
y habilidades de inicio (PR #42), hechizos raciales de paladín y chamán
(PR #46) y limpieza de razas que no existen en WotLK.

Lo único manual: cada jugador copia `cliente/Data/<idioma>/patch-<idioma>-4.MPQ`
(que lleva fundidos, entre otras cosas, los mismos DBC de creación de
personaje que `extras/mod-arac/patch-contents/DBFilesContent/`) a la carpeta
`Data/<idioma>/` de su cliente; `cliente/instalar-cliente.ps1` lo hace solo
junto con los addons. Hasta el 21/09/2026 esos DBC iban en un
`Data/Patch-Arac.MPQ` suelto que el Wow.exe nunca llegó a cargar (ver
«El cliente» (INSTALL_ES.md, parte 5) y `CHANGELOG.md`, tarea E1g).

---

### 8. Cuenta de administrador, NPC de servicio y español

**Cuenta admin** (`CREATE_ADMIN_ACCOUNT`, `ADMIN_ACCOUNT_NAME=admin`,
`ADMIN_ACCOUNT_PASS=admin`, `ADMIN_ACCOUNT_GMLEVEL=3`): la crea la fase 8 sin
personajes, calculando el verificador SRP6 con `lib/srp6.py` para no depender
del worldserver. Si ya existe no se le toca la contraseña. Cambiarla:
`.account password <actual> <nueva> <nueva>`.

**NPC de servicio** (`SPAWN_SERVICE_NPCS=true`): transmog, banco de materiales,
cambio de racial y battlemaster 1c1 en las **once capitales**, dos a cada lado
del NPC del Dungeon Master y a menos de 5 yardas, con la altura copiada del NPC
real más cercano. Idempotente: relanzar la fase 5 los recoloca. Coordenadas,
excepciones por capital y la historia de cada una en `REFERENCES.md`.

**Español** (`LOCALE_ES=true`): el juego base ya viene traducido en la base de
datos; lo que añaden los módulos lo traduce `patches/locales-es/` (las dos
cadenas de transmog que faltaban y los nombres de los NPC de servicio). Cómo
traducir un módulo nuevo: mirar si guarda textos en `module_string_locale`, en
`acore_string` (columna `locale_esES`) o incrustados en el `.cpp` (caso malo,
como challenge-modes); en los dos primeros casos es un `.sql` más en esa carpeta.

---

### 9. Versiones, copias offline y avisos

```bash
PIN_VERSIONS=true               # clavar cada repo al commit de versions.lock
WEEKLY_UPDATE_MODE="check"      # domingos 03:00: mirar y avisar, sin tocar nada
NOTIFY_GM_ON_UPDATE=true        # correo dentro del juego a las cuentas GM
GM_NOTIFY_MIN_LEVEL=3
MIRROR_REPOS=true               # copias offline en mirrors/
MIRROR_INCLUDE_CORE=true        # 209 MB; este repo vive en un Gitea sin límite de 100 MB
MIRROR_ASSET_BASE_URL="https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer/releases/download/snapshots"  # asset (https://) del que ./install.sh --hidratar descarga antes de reconstruir
```

**`versions.lock`** fija el commit exacto de cada uno de los 20 repositorios (19 hasta el 02/09/2026, cuando entró
`mod-dungeon-clear`). Se
regenera con `./install.sh --freeze` cuando una combinación está probada.

**`mirrors/`** guarda un `.tar.gz` de cada repositorio en su commit fijado (269
MB), con sha256 en `MANIFEST.tsv` y **una copia del `versions.lock`** al lado
(desde el 01/09/2026), para que el respaldo se explique solo. La fase 3 tira de
ahí si el clonado falla, **buscando el tarball del commit fijado** y avisando a
gritos si sólo hay otra versión. Se regeneran con `./install.sh --mirror`.

**Edición pública (sin los `.tar.gz`).** GitHub rechaza ficheros de más de 100 MiB y siete de los módulos no
declaran licencia, así que la edición pública lleva `MANIFEST.tsv` (nombre, commit, tamaño, nombre de fichero,
SHA-256 y URL del upstream) y no los tarballs. `./install.sh --hidratar [repositorio...]` deja en `mirrors/` los
snapshots de `versions.lock`, por la primera vía que dé un fichero **con ese SHA-256 exacto**: el que ya esté, el
asset de `MIRROR_ASSET_BASE_URL` (si está definida) o el upstream, pidiendo sólo el commit fijado
(`git fetch --depth 1 <sha>`) y repitiendo el `git archive | gzip -9` de `--mirror`, que es reproducible. Un
fichero cuyo hash no cuadra no se instala venga de donde venga; sin red ni asset y con el upstream movido, el
paso falla en vez de usar otra versión. `./install.sh --verify-mirrors` acepta snapshots ausentes (los cuenta
como «sin hidratar»); con `--hidratados` los exige. `tools/verificar-parches.sh` hidrata lo que necesita y
comprueba que cada parche propio aplica sobre el commit fijado, sin repositorio Git y sin `mirrors/` previos.

**Paquetes de cada versión.** Cada versión adjunta, con su `SHA256SUMS`, `MANIFIESTO.tsv` y `NOTAS-DE-VERSION.txt`:
`azerothcore-single-player-<versión>.zip` y `.tar.gz` (el árbol público sin historial Git, con los permisos de ejecución
y los fines de línea de Linux), `azerothcore-single-player-<versión>-con-snapshots.tar` (el mismo árbol más los
snapshots en `mirrors/`, para no descargar el core ni los módulos) y un asset por snapshot
(`<módulo>@<commit>.tar.gz`; su dirección de descarga es lo que se pone en `MIRROR_ASSET_BASE_URL`). Los assets
son copia de respaldo de todos los snapshots, también los de módulos sin fichero de licencia en su origen; si el
autor de alguno lo reclama, se retira de la versión y el instalador vuelve a pedirlo a su repositorio. Los paquetes se
generan de forma reproducible desde un único commit y se comprueban antes de adjuntarse: mismas rutas y bytes que la
exportación pública, sin `.git`, sin más Markdown que los documentos comunes y sin secretos. **No son una
instalación offline**: no incluyen los addons de terceros, `Data.zip` v20.0 ni las dependencias npm, y no llevan nada de Blizzard (los parches de
cliente, iconos y mapas se generan desde el cliente del jugador). El ZIP que GitHub ofrece de forma automática para una
etiqueta es sólo el árbol: el instalador completa el resto con comprobación de SHA-256 y, si un hash no cuadra o falta
un insumo, detiene el paso en vez de seguir.

**Licencias.** El código propio es AGPL-3.0-or-later (`LICENSE`, `NOTICE`, `LICENSES/`); cada fichero de código lleva
su cabecera SPDX y `REUSE.toml` declara copyright y licencia por ruta para el resto. `THIRD-PARTY-NOTICES.txt`
relaciona cada componente de terceros con su licencia y su origen. Los parches (`.patch`) conservan la licencia del
proyecto que modifican y la indican en su primera línea. `tests/estructura-publica.sh` falla si falta una cabecera, un
texto de licencia o un módulo en el aviso de terceros, y la CI ejecuta `reuse lint` (el árbol cumple REUSE 3.3).

El procedimiento completo para actualizar está en la [parte 4 §3](#3-actualizar-el-core-y-los-módulos).

---

#### Aviso de actualizaciones dentro del juego (desde 02/09/2026)

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `UPDATE_NOTICE_MIN_SECURITY` | `UpdateNotice.MinSecurity` | 2 | 1 moderador, 2 GM, 3 administrador |
| `UPDATE_NOTICE_DELAY_SECONDS` | `UpdateNotice.DelaySeconds` | 8 | Que no se pierda entre los mensajes de entrada |
| `UPDATE_NOTICE_MAX_LINES` | `UpdateNotice.MaxLines` | 15 | Líneas del informe que se enseñan |

El módulo lee `env/dist/bin/updates-pending.txt`, que escriben
`tools/revisar-actualizaciones.sh` y la tarea semanal. Sin fichero o vacío,
no dice nada. `.actualizaciones` lo vuelve a enseñar.

#### La ayuda del servidor en el cliente: mod-server-help (desde 02/09/2026)

Fichero: `etc/modules/mod_server_help.conf`. Necesita el addon `ServerHelp`
en el cliente (`cliente/`).

| `config.sh` | Clave real | Valor | Por qué |
|---|---|---|---|
| `INSTALL_MOD_SERVER_HELP` | `ServerHelp.Enable` | true / 1 | Recompilar al cambiarlo |
| `SERVER_HELP_MAX_SEARCH_RESULTS` | `ServerHelp.MaxSearchResults` | 60 | El cliente pagina de 20 en 20 |
| `SERVER_HELP_CACHE_SECONDS` | `ServerHelp.CacheSeconds` | 300 | Vida de la instantánea (comandos y artículos visibles) de cada cuenta; se rehace antes si cambia el nivel o se recargan los datos |
| `SERVER_HELP_INDEX_COOLDOWN` | `ServerHelp.IndexCooldownSeconds` | 2 | Entre dos índices completos de la misma cuenta (el de un administrador son ~200 mensajes) |
| `SERVER_HELP_LOG_REQUESTS` | `ServerHelp.LogRequests` | false | Apuntar cada petición del addon en `Server.log` |
| — | `ServerHelp.LineBytes` | 230 | Bytes por línea al addon; el core limita el mensaje a 255 y la cabecera ocupa 17 |
| — | `ServerHelp.DefaultCategory.{Player,Moderator,GameMaster,Administrator}` | 2, 14, 13, 15 | Categoría de un comando sin ficha ni regla, por nivel |

Las categorías, artículos, fichas y reglas viven en las tablas `server_help_*`
de `acore_world` (semilla en `modules/mod-server-help/data/sql/db-world/base/`,
aplicada por la fase 5 y por el actualizador del core). `.ayuda recargar` las
vuelve a leer. Cómo añadir documentación: `REFERENCES.md`.


#### Bots que aprenden: mod-adaptive-ai (archivado el 06/09/2026)

Módulo propio archivado. `INSTALL_MOD_ADAPTIVE_AI=false` hace que la fase 3 lo
aparte a `modules-disabled/`: no se compila, no se carga ni se instala su
configuración. Se exportó el último estado a
`modules/mod-adaptive-ai/data/entrenado/adaptive_entrenado.sql.gz` antes de
vaciar todas sus tablas. La calibración no fue suficientemente fiable para
mantenerlo activo; el estado conocido y los requisitos de una reactivación
están en `CHANGELOG.md`. El detalle histórico de las claves queda solo como
referencia de archivo en
`conf/mod_adaptive_ai.conf.dist`.

| Clave de `config.sh` | Clave del `.conf` | Por defecto | Notas |
|---|---|---|---|
| `INSTALL_MOD_ADAPTIVE_AI` | — | true | Recompilar al cambiarlo. Con `BOTS_DISABLED_WITHOUT_PLAYER=true` la arena de fondo solo entrena mientras alguien juega |
| `ADAPTIVE_ENABLE` | `AdaptiveAI.Enable` | true | El decisor. Con false los bots son playerbots de serie pero las arenas siguen (línea base) |
| `ADAPTIVE_LEARN` | `AdaptiveAI.Learn` | true | Aprender de los combates |
| `ADAPTIVE_LEARN_ONLY_ARENA` | `AdaptiveAI.Learn.SoloEnArena` | false | true: los combates reales no tocan la tabla |
| `ADAPTIVE_REAL_ENABLE` | `AdaptiveAI.Real.Enable` | true | Decidir también en combates reales, con la tabla validada |
| `ADAPTIVE_ARENA_ENABLE` | `AdaptiveAI.Arena.Enable` | true | Arena de entrenamiento en segundo plano |
| `ADAPTIVE_ARENA_SIMULTANEOUS` | `AdaptiveAI.Arena.Simultaneas` | 20 (aquí 120) | Combates a la vez. El aforo real de 1c1 es `ADAPTIVE_ARENA_BOTS_MAX / 2` |
| `ADAPTIVE_ARENA_TEAM_SIMULTANEOUS` | `AdaptiveAI.Arena.EquipoSimultaneas` | 1 | Arenas de equipo (2c2, 3c3, 5c5) a la vez en el automático, rotando entre tamaños; el resto de huecos van a 1c1 (03/09/2026, decisión del usuario). El campo automático sigue aparte (uno cada 30 min) |
| `ADAPTIVE_ARENA_WITH_PLAYER` | `AdaptiveAI.Arena.ConJugador` | 1c1:21 | Con un jugador conectado el automático se limita a estas partidas a la vez por tamaño; sin jugadores, todo. Desde la tarde del 03/09/2026 todo va a 1c1 (21 partidas = 42 bots, los mismos que antes repartía entre una de cada tamaño y un campo): es donde más deprisa se aprende. No toca el PvE |
| `ADAPTIVE_BG_WITH_PLAYER` | `AdaptiveAI.Bg.ConJugador` | 0 | Campos automáticos a la vez con un jugador conectado |
| `ADAPTIVE_LEVEL_BRACKETS_WITH_PLAYER` | `AdaptiveAI.FranjasConJugador` | **true** | Conmuta el reparto por franjas de nivel de playerbots: **automático** mientras haya un jugador conectado (acerca la población a tu nivel) y **fijo** cuando el servidor entrena solo, que es cuando el automático no tiene a quién seguir y le deja al entrenamiento 28 bots de nivel 80 en vez de 200. El módulo lo mira cada 30 s y el gestor de franjas relee la bandera en cada pasada. `false` = no tocar nada y mandar lo que diga `playerbots.conf`. El valor de partida es `BOTS_LEVEL_BRACKETS_DYNAMIC` |
| `ADAPTIVE_ARENA_BOTS_MAX` | `AdaptiveAI.Arena.BotsMax` | 40 (aquí 200) | Bots a la vez en arenas, sumando tamaños: deja bots de nivel 80 para los campos y los jugadores (desde 03/09/2026) |
| `ADAPTIVE_ARENA_PAUSE_SECONDS` | `AdaptiveAI.Arena.PausaEntreCombates` | 5 | Segundos entre dos lanzamientos |
| `ADAPTIVE_CLASSES` | `AdaptiveAI.Clases` | (vacío = todas) | Clases que deciden y entrenan; las demás juegan de serie (desde 03/09/2026) |
| `ADAPTIVE_ARENA_TYPES` | `AdaptiveAI.Arena.Tipos` | 1c1,2c2,3c3,5c5 (aquí los cuatro; el grueso va a 1c1 por `ADAPTIVE_ARENA_TEAM_SIMULTANEOUS`) | Tamaños que entrena el automático; a mano vale cualquiera |
| `ADAPTIVE_BOTS_LEVEL80` | `AdaptiveAI.Bots.Nivel80` | (vacío; aquí 30 por clase) | Bots de nivel 80 conectados que se mantienen por clase: si faltan, sube uno libre cada 10 s (hasta tres si faltan 40 o más: la oleada de desconexiones tras un reinicio) con la fábrica de playerbots, empezando por la clase a la que más le faltan (playerbots rota fuera a los subidos: sin reposición rápida se quedaban en 3-10 por clase). Es el tope real de arenas 1c1 |
| `ADAPTIVE_ARENA_PAIRS` | `AdaptiveAI.Arena.Pares` | warrior:mage,... (en este servidor: las 45 parejas de clases y equipos al azar de 2, 3 y 5) | Composiciones: equipos con `+`, `*` = cualquier clase habilitada; `warrior.arms:mage.frost` |
| `ADAPTIVE_BG_ENABLE` | `AdaptiveAI.Bg.Enable` | false | Campos de batalla de entrenamiento automáticos; a mano siempre (`.adaptive bg lanzar`) |
| `ADAPTIVE_BG_MAPS` | `AdaptiveAI.Bg.Mapas` | WS,AB,EY (aquí solo `WS` de momento) | WS, AB, EY, AV, SA, IC, en rueda |
| `ADAPTIVE_BG_EVERY_MINUTES` | `AdaptiveAI.Bg.CadaMinutos` | 30 | |
| `ADAPTIVE_BG_PLAYERS` | `AdaptiveAI.Bg.PorEquipo` | 0 | Bots por bando; 0 = el mínimo del campo (WS 10, AB 15, EY 15, AV 40, SA 15, IC 20) |
| `ADAPTIVE_IMPORTAR_ENTRENADO` | — | true (aquí **false**) | Fase 5: importar `data/entrenado/adaptive_entrenado.sql` o `.sql.gz` (pregunta si hay terminal). No pisa una base con más entrenamiento. En este repositorio el fichero está como `.sql.gz.old` (entrenado con el premio viciado del 04/09) y no se importa |
| `ADAPTIVE_ARENA_MODE` | `AdaptiveAI.Arena.Modo` | mixto | entrenar, contraste, mixto (en este servidor: contraste) |
| `ADAPTIVE_ARENA_REFERENCE` | `AdaptiveAI.Arena.Referencia` | 20 | % de partidas automáticas serie contra serie: la línea base con la que `.adaptive` y el informe comparan el contraste. Con 10 salían diez partidas por pareja (04/09/2026) |
| `ADAPTIVE_ARENA_YIELD` | `AdaptiveAI.Arena.CederAJugadores` | true | No lanzar mientras haya un jugador en cola PvP |
| `ADAPTIVE_ARENA_MAP` | `AdaptiveAI.Arena.Mapa` | 559 | 559 Nagrand, 562 Filospada, 572 Lordaeron, 617 Dalaran, 618 Valor, 0 azar |
| `ADAPTIVE_ARENA_PREP_SECONDS` | `AdaptiveAI.Arena.PreparacionSegundos` | 15 | Cuenta atrás de la arena |
| `ADAPTIVE_ARENA_LEVEL` | `AdaptiveAI.Arena.Nivel` | 80 | Nivel mínimo de los bots |
| `ADAPTIVE_ARENA_GEAR_SCORE` | `AdaptiveAI.Arena.NivelObjeto` | 264 | Se iguala el equipo a ese nivel de objeto (264 = Gladiador Colérico; con spec PvP la fábrica elige resiliencia; 0 = no tocar) |
| `ADAPTIVE_ARENA_SPECS` | `AdaptiveAI.Arena.Specs` | (vacío; aquí arms/frost/subtlety/unholy/affli/mm/cat/ret/shadow/ele pvp) | Spec premade de playerbots por clase al entrar en arena o subir a 80 (desde 03/09/2026) |
| `ADAPTIVE_OBJECTIVES` | `AdaptiveAI.Objetivos` | (vacío; aquí la matriz de `REFERENCES.md` corregida) | `a:b=%`: lo que se espera que a gane a b. Se enseña junto al contraste |
| `ADAPTIVE_LOADOUT_ENABLE` | `AdaptiveAI.Loadout.Enable` | true | Doble spec (0 PvE, 1 PvP) en todos los bots de nivel 40+ y equipo regenerado por propósito (desde 03/09/2026, `CHANGELOG.md` anexo A1 §16.17) |
| `ADAPTIVE_LOADOUT_PVP_ILVL` | `AdaptiveAI.Loadout.EquipoPvP` | 0:232,1600:251,1800:264,2200:270 | Equipo PvP por rating Elo del bot |
| `ADAPTIVE_LOADOUT_CAP_LEVELS` | `AdaptiveAI.Loadout.NivelesTope` | 60,70,80 | Niveles tope de etapa (03/09/2026): por el mundo lo normal es equipo PvE y solo a estos niveles es normal ver PvP. Un bot por debajo del tope que aparece por el mundo con resiliencia (sale de un campo o de un duelo, o conecta así) se reequipa PvE por nivel, para que el que levea no se cruce con un bot con ventaja de PvP |
| `ADAPTIVE_LOADOUT_PVE_ILVL` | `AdaptiveAI.Loadout.EquipoPvE` | normal:187,heroica:200,banda10:219,banda25:232,mundo:0 | Equipo PvE por contenido cuando el bot va sin jugador (con jugador manda mod-queue-bots) |
| `ADAPTIVE_OBJECTIVES_STOP` | `AdaptiveAI.Objetivos.Parar` | true | El automático deja de lanzar un 1c1 cuando alcanza su objetivo (menos `.Margen`, 5) en las dos orientaciones con `.PartidasMinimas` (200) cada una |
| `ADAPTIVE_CALIBRATE_MINUTES` | `AdaptiveAI.Calibrar.CadaMinutos` | 60 | 0 = solo con `.adaptive calibrar` |
| `ADAPTIVE_CALIBRATE_MATCHES` | `AdaptiveAI.Calibrar.Combates` | 100 | |
| `ADAPTIVE_CALIBRATE_MARGIN` | `AdaptiveAI.Calibrar.MargenMinimo` | 0.55 | Tasa de victoria para validar la candidata |
| `ADAPTIVE_CALIBRATE_PER_CLASS` | `AdaptiveAI.Calibrar.PorClase` | true | Aprobado por clase (03/09/2026): cada clase se compara consigo misma (lo que gana con la candidata contra lo que gana con la validada en las mismas parejas) y aprueba si mejora `MejoraPorClase` puntos o ya gana el 90 % sin empeorar (saturada); pasa ella sola a la validada aunque la media global no llegue; una clase aprobada deja sus arenas a las suspensas (en un 1c1 con una de cada, aprende la suspensa; en el examen los lados alternan igual que siempre, porque si no la suspensa se medía como candidata contra las aprobadas y como validada solo contra suspensas, 04/09/2026); cuando aprueban todas, ronda nueva |
| `ADAPTIVE_CALIBRATE_PER_CLASS_MATCHES` | `AdaptiveAI.Calibrar.PartidasPorClase` | 60 | Partidas por clase y lado para decidir el aprobado. Una hora de examen deja 150-200 |
| `ADAPTIVE_CALIBRATE_TYPES` | `AdaptiveAI.Calibrar.Tipos` | 1c1 | Tamaños que entran en el examen (03/09/2026, decisión del usuario). Solo duelos: el aprobado va por clase y en un 5c5 el resultado no se puede atribuir a nadie. El equipo se sigue midiendo con las partidas de contraste del automático, que salen en el informe |
| `ADAPTIVE_CALIBRATE_MAX_MINUTES` | `AdaptiveAI.Calibrar.MinutosMaximos` | 60 | Lo que dura un examen; al cumplirse concluye con lo que haya medido. Con `CadaMinutos` a 60 el ciclo es una hora entrenando y una midiendo |
| `ADAPTIVE_CALIBRATE_EXCLUSIVE` | `AdaptiveAI.Calibrar.Exclusiva` | true | Durante el examen el automático no lanza entrenamiento ni campos: todas las arenas miden. Una hora así deja 150-200 partidas por clase y lado, frente a las 18 de compartir arenas |
| `ADAPTIVE_CALIBRATE_CLOCK` | `AdaptiveAI.Calibrar.Reloj` | true | El examen va por el reloj del sistema (04/09/2026): el día se parte en periodos de `CadaMinutos` + `MinutosMaximos` desde la medianoche local y los últimos `MinutosMaximos` de cada uno son de examen (con 60 y 60: de 01:00 a 02:00, de 03:00 a 04:00...). Un reinicio en mitad de una ventana retoma el examen si queda al menos un tercio; al apagar, un examen con media ventana hecha concluye con lo que tiene. Antes el temporizador arrancaba de cero con cada reinicio y un día con siete reinicios se quedó sin examen. false = temporizador desde el arranque |
| `ADAPTIVE_CALIBRATE_CLASS_GAIN` | `AdaptiveAI.Calibrar.MejoraPorClase` | 5 | Puntos que la clase tiene que ganar con la candidata por encima de lo que gana con la validada |
| `ADAPTIVE_CALIBRATE_MAX_CYCLES` | `AdaptiveAI.Calibrar.CiclosMaximos` | 6 | Exámenes **juzgados** seguidos sin aprobar tras los que una clase que no mejora vuelve a lo anterior (sus filas de la candidata pasan a ser las de la validada); si mejoraba sin llegar al margen, sigue; si la validada no tiene filas suyas, se queda con lo suyo. 0 = nunca. Estuvo a 0 la mañana del 04/09/2026 (con 3 y el examen sesgado se borraron cinco clases) y volvió a 6 esa tarde con la guarda |
| `ADAPTIVE_CALIBRATE_SAME_RIVAL` | `AdaptiveAI.Calibrar.MismoRival` | true | El examen juega un tercer brazo (validada contra validada) y la nota "con la validada" de cada clase sale sólo de ahí, contra el mismo rival que la nota "con la candidata" (05/09/2026). Cuesta un 50 % más de partidas por pareja |
| `ADAPTIVE_CALIBRATE_Z` | `AdaptiveAI.Calibrar.Z` | 1.64 | El aprobado exige además Z veces el error típico de la diferencia de los dos porcentajes (05/09/2026). 0 = sólo `ADAPTIVE_CALIBRATE_CLASS_GAIN` |
| `ADAPTIVE_CALIBRATE_LADDER_RULE` | `AdaptiveAI.Calibrar.VaraSerie` | false | La serie como única vara: aprueba la clase cuyo peldaño de candidata sin explorar supera al mejor peldaño actual con margen Z. false = sólo se traza en el log al lado del veredicto de hoy (05/09/2026, versión estable) |
| `ADAPTIVE_ARENA_PROBE` | `AdaptiveAI.Arena.EscaleraCandidata` | 10 | % de partidas automáticas "sonda": la candidata sin explorar contra playerbots de serie, su peldaño en la escalera |
| `ADAPTIVE_LADDER_SINCE` | `AdaptiveAI.Escalera.DesdeUnix` | 1788629327 | Corte de medida: 05/09/2026 19:28:47 Madrid. Excluye resultados anteriores y fotos heredadas; conserva Q y partidas. Actualizar tras cambiar comportamiento o limpiar Q; 0 = historial. Requiere reinicio al cambiarlo para invalidar inmediatamente la foto en memoria |
| `ADAPTIVE_AUDIT_CLASSES` | `AdaptiveAI.Log.AuditarClases` | vacío | Captura las primeras sesiones activas de candidata 1c1 que aprende, por clase (p. ej. `warlock,druid`). Vacío apaga nuevas capturas |
| `ADAPTIVE_AUDIT_SESSIONS` | `AdaptiveAI.Log.AuditarSesiones` | 3 | Cuota por clase, de 1 a 20. Vive en memoria: apagar después de recoger la muestra y antes de otro reinicio. Cada sesión tiene además un límite de 4000 eventos |
| `ADAPTIVE_DECISION_MIN_VISITS` | `AdaptiveAI.Decision.VisitasMinimas` | 5 | Sin aprender sólo se eligen acciones con estas visitas al menos; si ninguna llega, `none`. Y con la tabla sin filas de la clase, el bot juega de serie en vez de con su personalidad (05/09/2026, N1 y N4) |
| `ADAPTIVE_DECISION_REJECT_LEARNS` | `AdaptiveAI.Decision.RechazoAprende` | false | Si la acción que playerbots rechaza aprende "mejor Q − 1" (lo de antes del 05/09/2026) |
| `ADAPTIVE_ARENA_APPROVED_LEARN` | `AdaptiveAI.Arena.AprobadasEntrenan` | true | Las aprobadas siguen aprendiendo en 1c1 durante la ronda (antes jugaban de serie hasta cerrarla) |
| `ADAPTIVE_ARENA_APPROVED_MODEL` | `AdaptiveAI.Arena.AprobadaConModelo` | 50 | % de partidas de contraste en que la aprobada del lado no adaptativo lleva su validada en vez de jugar de serie |
| `ADAPTIVE_CALIBRATE_ALL_PLAY` | `AdaptiveAI.Calibrar.TodasJuegan` | true | En el examen, las aprobadas y las que ya llegaron al tope siguen jugando como las demás; ninguna pareja deja de lanzar (05/09/2026) |
| `ADAPTIVE_ARENA_GENERATIONS` | `AdaptiveAI.Arena.Generaciones` | 15 | % de partidas automáticas contra una generación anterior (versión que fue validada, al azar) en vez de contra playerbots: variedad, que no se estanque |
| `ADAPTIVE_GENERATIONS_KEEP` | `AdaptiveAI.Generaciones.Guardar` | 5 | Generaciones que se guardan (las más recientes) |
| `ADAPTIVE_GENERALIZE` | `AdaptiveAI.Generalizar` | true | Fila "contra cualquier rival" (clase enemiga 0) que se aprende a la vez y sirve de punto de partida a lo no probado contra un rival concreto: cada clase aprende de sus nueve parejas a la vez |
| `ADAPTIVE_EPSILON` | `AdaptiveAI.Epsilon` | 0.05 | Exploración al azar. La que importa es la dirigida, `AdaptiveAI.Exploracion.Bonus` (solo en el `.conf`) |
| `ADAPTIVE_DIFFICULTY_DEFAULT` | `AdaptiveAI.Dificultad.PorDefecto` | 3 | 1 Novato .. 6 Elite; solo en combates reales |
| `ADAPTIVE_LOG_DECISIONS` | `AdaptiveAI.Log.Decisiones` | false | Cada decisión en `adaptive_experience` (crece rápido) |
| `ADAPTIVE_CALIBRATE_CUT_WHEN_JUDGED` | `AdaptiveAI.Calibrar.CortarAlJuzgar` | true | El examen se corta en cuanto todas las clases que se juzgan tienen ya `PartidasPorClase` partidas por lado, y el resto de la ventana vuelve al entrenamiento |
| `ADAPTIVE_CALIBRATE_CUT_MATCHES` | `AdaptiveAI.Calibrar.PartidasCorte` | 0 | Partidas por lado para ese corte (0 = las mismas que `PartidasPorClase`). Subirlo hace el veredicto menos ruidoso a cambio de menos entrenamiento |
| `ADAPTIVE_WARLOCK_PVP_PET` | `AdaptiveAI.Brujo.MascotaPvP` | felhunter | Mascota que el módulo garantiza al brujo en PvP. Mientras dura el combate le apaga las cinco estrategias de mascota de playerbots, que eran las que le hacían reinvocar el demonio sin parar |
| `ADAPTIVE_LOG_AURAS` | `AdaptiveAI.Log.Auras` | false | Diagnóstico: escribe en el log cada control o snare que se **cobra**, con el hechizo y si cae sobre un jugador o no. Sirve para cazar cobros que no caen sobre el rival. Ruidoso: se enciende y se apaga con `reload config`, sin reiniciar |
| `ADAPTIVE_LOG_MATCH_DAYS` | `AdaptiveAI.Log.PartidasDias` | 30 | Borra partidas de más de N días al arrancar y una vez al día (0 = nunca). Lo aprendido no se toca |

Solo en el `.conf`: `AdaptiveAI.Trazas.GM` (trazas a los GM con `.gm on`, por defecto 1);
los del aprendizaje de la fase 1b (03/09/2026, `CHANGELOG.md` anexo A1 §16.14):
`AdaptiveAI.Exploracion.Bonus` (3.0, optimismo: lo no probado vale el mejor Q
del estado más el bonus; lo poco probado, bonus/√visitas), `.Alpha` (0.10, paso
mínimo), `.Alpha.Decreciente` (1: paso max(Alpha, 1/(visitas+1))), `.Gamma`
(0.90), `.Retorno.Peso` (0.5: retorno Monte Carlo de la partida a todas sus
decisiones), `.Interrupcion.SoloCasteando` (1), `.Kitear.Distancia` (20) y
`.Kitear.Ms` (3000), `.Recompensa.Distancia` (0.3 por decisión: lanzadores a
distancia, cuerpo a cuerpo pegados), `.Recompensa.KillEquipo` (10),
`.MuerteAliado` (-10), `.Objetivo` (15), `.ObjetivoEquipo` (5), `.Bg.Simultaneos`,
`.Bg.Nivel`, `.Bg.DuracionMaxMinutos`, `.Bg.EsperaSegundos`, `.Bg.Modo`,
`.Exportar.Fichero`; y `.Decision.*`, `.Dificultad.1..6`,
`.Brackets`, `.Personalidad.Peso`, `.Recompensa.*`, `.Arena.EsperaSegundos`,
`.Arena.DuracionMaxSegundos`, `.Log.Partidas`.


---

## Parte 3 — Qué hace cada fase, y por qué

Los scripts `scripts/phases/01_dependencies.sh` … `08_post_install.sh` son la fuente de verdad:
lo que sigue explica **qué consigue cada uno y por qué está hecho así**, con las
trampas que costaron tiempo. Para hacerlo a mano basta con leer el script de la
fase; para entender una decisión, esta parte.

### La VM y el sistema (fase 1)

Estos son los valores de la VM de pruebas (Proxmox, Ubuntu Server 24.04 LTS, OpenSSH
activado). No son requisitos: en otro hipervisor o en una máquina física sirven los
equivalentes.

| Parámetro | Valor | Por qué |
|---|---|---|
| CPU | 8 cores, tipo **`host`** | Sin `host` el invitado no ve las instrucciones nativas de la CPU y la compilación se alarga mucho |
| RAM | 16 GB, **sin ballooning** | Con 500 bots el worldserver ronda los 5-6 GB; el ballooning le quita memoria justo cuando la necesita |
| Disco | 120 GB, `raw`, en `local-lvm` | |
| Red | VirtIO, bridge `vmbr0` | |

La fase instala el compilador (clang), CMake, Boost, OpenSSL, readline,
ncurses, `screen` y `unzip`, y fija la **zona horaria** (`TIMEZONE` en
`config.sh`; hoy `Europe/Madrid`). La zona horaria importa más de lo que
parece: las tablas de `mod-adaptive-ai` guardan `DATETIME` locales y los
informes filtran por fecha, así que cambiarla a posteriori obliga a corregir
las filas ya escritas.

También desactiva las actualizaciones automáticas de paquetes
(`/etc/apt/apt.conf.d/20auto-upgrades`): un `unattended-upgrade` de MySQL con
el servidor en marcha lo tira.

### MySQL (fase 2)

MySQL **8.4 LTS** desde el repositorio oficial (`mysql-apt-config`), no el
`mysql-server` de Ubuntu.

Usuario `acore` en `localhost` **y** en `127.0.0.1` — el core conecta por TCP y
MySQL trata las dos como cuentas distintas — con permisos acotados a `acore\_%`
y `GRANT PROCESS`. La receta que circula por internet es `GRANT ALL ON *.*
WITH GRANT OPTION`: eso le da al usuario del juego acceso de escritura a
`mysql.user`, así que quien saque la contraseña de un `.conf` se lleva el
servidor MySQL entero y no sólo el del juego.

Ajustes de `mysqld.cnf` que la fase escribe, imprescindibles con muchos bots:

```ini
skip-log-bin                       # sin replicación, el binlog sólo escribe disco (-75/90 %)
innodb_buffer_pool_size = 4G       # ~50 % de la RAM de la VM
innodb_io_capacity      = 500
innodb_io_capacity_max  = 2500
transaction_isolation   = READ-COMMITTED
```

Bases de datos: `acore_auth`, `acore_world`, `acore_characters` y
`acore_playerbots` (ésta la usa mod-playerbots para sus propias tablas; las de
`mod-adaptive-ai` viven ahí también).

### El código y los módulos (fase 3)

**El core es el fork de mod-playerbots**, rama `Playerbot`, no el AzerothCore
oficial: playerbots necesita cambios en el núcleo que no caben en un módulo.
Esto es irreversible sin reinstalar: añadir o quitar playerbots obliga a
repetir desde la fase 3.

La fase clona el core y los 19 módulos de terceros **al commit exacto** que
diga `versions.lock`, o desde `mirrors/` si están las copias offline; copia los
módulos propios de `modules/` dentro de `modules/` del core junto con las
cabeceras compartidas de `modules/shared/`; y aplica los parches de `patches/`.
Un módulo con su `INSTALL_MOD_*` en `false` se aparta a `modules-disabled/`, sin
borrarlo: volver a activarlo es cambiar la clave y recompilar.

Cuando un parche deja de aplicar, la fase avisa y sigue: el módulo se queda con
su comportamiento original. Qué hacer entonces, en «Escribir un parche sobre código de terceros» (REFERENCES.md).

### Compilar (fase 4)

```
cmake -DCMAKE_INSTALL_PREFIX=env/dist -DCMAKE_C_COMPILER=clang
      -DCMAKE_CXX_COMPILER=clang++ -DWITH_WARNINGS=1 -DTOOLS_BUILD=all
      -DSCRIPTS=static -DMODULES=static
make -j$(nproc - 1) && make install
```

Un core menos que los disponibles, para que la VM siga respondiendo. CMake
detecta solo todo lo que haya en `modules/`; en su salida aparece la lista
`Modules configuration (static)`, que es la forma rápida de comprobar que un
módulo nuevo ha entrado. ~22 minutos con 7 cores en el equipo de pruebas; la recompilación incremental
tras tocar un módulo propio, unos 2 minutos.

### Configurar (fase 5)

La fase copia cada `.conf.dist` a su `.conf` y **escribe encima los valores de
`config.sh`**, con `set_conf_value`. Por eso nada se edita a mano en el
servidor. También aplica el SQL propio de `patches/`, siempre idempotente.

Dos cosas que se descubrieron por las malas y que el instalador ya vigila:

- **Claves fantasma.** Escribir una clave que el módulo no lee no da ningún
  error: simplemente no pasa nada. `set_conf_value` avisa de toda clave que no
  esté declarada en el `.dist` correspondiente. Así aparecieron
  `MapUpdateThreadCount` (la buena es `MapUpdate.Threads`, y el servidor corrió
  meses con un solo hilo), `Transmogrification.Enabled` (es `Enable`) y
  `AutoBalance.enable`, que el dist ya sólo lee para avisar de que está obsoleta.
- **Los datos del cliente tienen versión.** `Data.zip` (con mayúscula) de
  [wowgaming/client-data](https://github.com/wowgaming/client-data/releases),
  **v20.0** para este core. El instalador descarga exactamente esa versión, la
  reanuda si la descarga se corta y comprueba su SHA-256 antes de extraer (una
  extracción interrumpida se repite entera). Para otra versión hay que dar a la
  vez `AC_DATA_URL` y `AC_DATA_SHA256`. Con unos mmaps viejos los bots no saben
  andar y el log lo dice: `mmtile was built with generator v19, expected v20`.

### Los servicios systemd (fase 6)

Dos unidades, `ac-authserver` y `ac-worldserver`, que arrancan con la máquina.
Lo que hay dentro y no es evidente:

- **`ExecStartPre=wait-for-mysql.sh`.** `After=mysql.service` sólo garantiza que
  la *unidad* de MySQL arrancó, no que esté aceptando conexiones. Sin esa
  espera, al reiniciar la VM el worldserver llega antes y entra en bucle de
  reinicios.
- **`ExecStop=safe-stop.sh`** con `TimeoutStopSec=150`: avisa a los jugadores,
  hace `saveall` y cierra ordenadamente. Por eso `systemctl restart
  ac-worldserver` es seguro aunque haya alguien dentro: avisa 60 segundos.
- **`KillMode=mixed`, nunca `none`.** Con `none`, si el `ExecStop` falla systemd
  no mata nada y quedan worldserver huérfanos ocupando el puerto en el siguiente
  arranque. Además `none` está obsoleto desde systemd 250 y lo avisa en cada
  arranque.
- **`Before=`/`Conflicts=shutdown.target` no se declaran.** systemd ya se los
  añade a todo servicio normal; ponerlos a mano obliga a `DefaultDependencies=no`
  y eso elimina las dependencias implícitas con `sysinit.target`, con lo que la
  unidad puede intentar arrancar antes de que el sistema base esté listo.
- El worldserver corre dentro de **`screen`**, así que se le pueden mandar
  comandos con el jugador desconectado: `screen -S worldserver -X stuff
  "server info$(printf '\r')"`. RA sigue apagado a propósito; SOAP se activa
  sólo en `127.0.0.1:7878` cuando `INSTALL_WEB_PANEL=true` (fase 5), porque el
  panel de moderación lo necesita para expulsar/banear/silenciar a un jugador
  ya conectado — ver «El panel web» (INSTALL_ES.md, parte 5).
- Regla `sudoers` **acotada**: `NOPASSWD` sólo para arrancar y parar las dos
  unidades (y `reboot`), no para `sudo` entero.
- **Con `WORLDSERVER_STANDBY=true`** ([parte 2 §2 · Modo en espera](#modo-en-espera-apagar-el-worldserver-cuando-no-hay-nadie))
  cambia el servicio del worldserver: `ac-worldserver.socket` posee el 8085 y
  arranca `ac-worldserver.service` (binario directo, sin `screen`,
  `Restart=on-failure`) a la primera conexión. Sin `screen`, `safe-stop.sh` y
  `notify-restart.sh` mandan los comandos por SOAP (`scripts/ws-console.sh`).
  `sudoers` añade las tres líneas de `ac-worldserver.socket`.

### Automatización (fase 7)

| Cuándo | Qué |
|---|---|
| Diario 00:00 | Reinicio del servidor, con aviso previo a los jugadores (con modo en espera: **sólo si estaba despierto**; si dormía, no hace nada) |
| Domingo 03:00 | **Revisión** de versiones nuevas río arriba (`WEEKLY_UPDATE_MODE="check"`) |
| Diario | Copia de seguridad de las bases de datos |
| Semanal | `logrotate` de los logs de automatización |

La revisión semanal **sólo avisa**: deja el resultado para `.actualizaciones` y
para el correo de los GM. Actualizar de verdad es un acto manual
([parte 4 §3](#3-actualizar-el-core-y-los-módulos)), porque con parches propios
sobre código de terceros un `git pull` a ciegas rompe el servidor mientras
duermes. Guías antiguas describen un `weekly-update.sh` que recompilaba solo:
eso ya no es lo que hace este instalador.

El arranque tras un reinicio lo resuelven las unidades systemd habilitadas, no
un `@reboot` del crontab: la espera a MySQL vive en `ExecStartPre`, que es su
sitio.

### Post-instalación (fase 8)

Lo que necesita las bases de datos ya pobladas: realmlist apuntando a
`REALM_IP`, cuenta `admin`/`admin` con GM 3 (creada con SRP6 desde
`lib/srp6.py`, sin pasar por la consola), NPC de servicio en las once capitales
y el SQL propio que depende de tablas del core.

### Panel web (fase 9)

Instala una aplicación Node.js en `/opt/azerothcore-panel`, crea un usuario
MySQL acotado por tabla (y por columna en `account`: sólo puede crear cuentas
y cambiar contraseñas, nunca tocar `gmlevel` ni `locked`), una base propia
`acore_panel` para invitaciones y auditoría, y una cuenta de juego dedicada
(gmlevel 3) con la que el panel habla con la consola SOAP del worldserver para
moderar. Guarda todas las credenciales y el secreto de sesión en
`/etc/azerothcore-panel.env` con modo `0600`, y publica el servicio por Nginx en
`http://REALM_IP`. El login valida el verifier SRP6 de las cuentas del juego;
la lista online y el catálogo local de 118 addons son privados, y el mapa y la
moderación comprueban el rango GM también en backend. Las descargas se generan
desde la copia canónica `cliente/Interface/AddOns`, no desde el repositorio de
origen.

La fase se puede repetir con `./install.sh --panel`: sincroniza todos los
cambios de `web-panel/`, conserva los secretos y reinicia el servicio. Los
mapas de continente son recursos locales a 3840 × 2560, se encuadran completos
y sólo permiten zoom hasta su resolución nativa. Detalle operativo y de
seguridad: «El panel web» (INSTALL_ES.md, parte 5).

Desde la sección **Addons**, Chrome o Edge pueden instalar la selección en la
carpeta que contiene `Wow.exe` después de que el jugador conceda permiso. La
escritura directa requiere publicar el panel por HTTPS (o abrirlo desde
localhost); al acceder por la IP con HTTP se usa la descarga ZIP individual.

### Riesgos conocidos

| Riesgo | Mitigación |
|---|---|
| Un módulo nuevo no compila contra el fork de playerbots | La fase 4 falla mostrando el error del módulo. Se pone su `INSTALL_MOD_*` en `false`: la fase 3 lo aparta a `modules-disabled/` sin borrarlo, y se sigue |
| Un parche propio deja de aplicar tras actualizar | La fase 3 avisa y continúa; el módulo se queda con su comportamiento original. Rehacerlo: «Escribir un parche sobre código de terceros» (REFERENCES.md) |
| `mod-instance-reset` acelera demasiado el ritmo de botín | Coste alto por defecto; `INSTALL_MOD_INSTANCE_RESET=false` lo quita |
| 40 bots en banda consumen CPU | Es un tope, no una reserva: sólo pesa cuando se invocan |
| Los DBC de individual-progression pisan a ARAC | Resuelto: `SkillRaceClassInfo.dbc` se excluye cuando ARAC está activo |
| La cuenta `admin` con contraseña `admin` es trivial | Aceptado a propósito: red local. Cambiarla es `.account password` dentro del juego |
| `mod-dungeon-master` es *early development* | Si hay rarezas en instancias, `INSTALL_MOD_DUNGEON_MASTER=false` y recompilar |


---

## Parte 4 — Operar

El manual de operación del servidor ya instalado. Todo lo de aquí se ha
ejecutado de verdad en la VM de referencia (usuario `acore`); las fechas
dicen cuándo.

### 1. Día a día

```bash
systemctl is-active mysql ac-authserver ac-worldserver
sudo systemctl restart ac-worldserver     # avisa 60 s a los jugadores, saveall, reinicia
sudo systemctl stop ac-worldserver        # lo mismo, sin arrancar (tarda ~1 min con gente dentro)
sudo systemctl start ac-authserver ac-worldserver
```

`start`, `stop` y `restart` de los dos servicios, `reboot` y `shutdown` no piden
contraseña; cualquier otro `sudo` sí.

Logs, en `~/azerothcore/env/dist/bin/`, con hora y nivel en cada línea:

| Fichero | Qué |
|---|---|
| `Server.log` | Todo lo del core (se trunca en cada arranque) |
| `Playerbots.log` | El módulo de bots |
| `Errors.log` | Sólo errores |
| `~/azerothcore/logs/` | Los scripts de automatización (reinicio diario, parada segura, arranque) |

Consola del worldserver (corre dentro de `screen`):

```bash
screen -S worldserver -X stuff 'announce Hola a todos
'                                                   # mandar un comando
screen -S worldserver -X hardcopy -h /tmp/ws.txt    # volcar la pantalla a fichero
```

El crontab reinicia los servicios a las 00:00 (aviso a las 23:55), revisa si hay
versiones nuevas los domingos a las 03:00 (sólo avisa, por correo dentro del
juego) y reinicia la VM los domingos a las 05:00. Al arrancar la máquina, systemd
espera a que MySQL acepte conexiones y arranca los dos servicios.

**Modo en espera** (`WORLDSERVER_STANDBY=true`): el worldserver se apaga solo
tras `STANDBY_IDLE_MINUTES` sin jugadores y lo arranca la siguiente conexión.

```bash
systemctl is-active ac-worldserver            # 'active' despierto, 'inactive' dormido
systemctl status ac-worldserver.socket        # el socket del 8085 (siempre activo)
cat /run/azerothcore/worldserver.state         # running | standby | down
sudo systemctl start ac-worldserver           # despertarlo a mano
```

Comandos en el juego / consola: `.standby` (estado), `.standby ahora`,
`.standby mantener <min>`, `.standby reanudar`. El reinicio diario no hace nada
si el worldserver está dormido. En la cabecera del panel web: "En vivo" /
"En espera" / "Caído".

¿Hay versiones nuevas río arriba? Sin tocar nada:

```bash
bash tools/revisar-actualizaciones.sh              # tabla por repositorio, y escribe el aviso de mod-update-notice
bash tools/revisar-actualizaciones.sh --log mod-transmog   # los commits nuevos de ese repo
```

Y desde Windows, sin entrar en la VM (sube el script y lo ejecuta por plink):

```powershell
& "<proyecto>\tools\revisar-actualizaciones.ps1"                  # la tabla
& "<proyecto>\tools\revisar-actualizaciones.ps1" -SoloNovedades   # sólo los que tienen commits nuevos
& "<proyecto>\tools\revisar-actualizaciones.ps1" -Log mod-transmog
```

Los GM lo ven también al entrar en el juego (`mod-update-notice`) y con
`.actualizaciones`.

---

### 2. Copia de seguridad y restauración

Antes de cualquier operación que toque las bases de datos:

```bash
bash ~/azerothcore-installer/tools/backup-servidor.sh
```

Para los servicios con parada segura, vuelca las cuatro bases (`acore_auth`,
`acore_characters`, `acore_world`, `acore_playerbots`) comprimidas, y copia los
`.conf`, el `versions.lock`, el `Server.log` y el crontab a
`~/backup-<fecha>/`. Unos 115 MB. Luego tráetelo a otra máquina (§8).

Restaurar una base:

```bash
sudo systemctl stop ac-worldserver ac-authserver
zcat ~/backup-<fecha>/acore_characters.sql.gz | mysql -u acore -pacore acore_characters
sudo systemctl start ac-authserver ac-worldserver
```

Última copia completa: **01/09/2026, antes de la reinstalación**, en
`<copias>\backup-pre-reinstalacion-20260901-1841`. Contiene a
`Lightcore` (paladín 80, fase 13) y los 1500 bots anteriores.

---

### 3. Actualizar el core y los módulos

Procedimiento seguido el 01/09/2026, pensado para ejecutarlo con un agente sin
pasos manuales. El principio: **todo el riesgo se mira antes de tocar la VM**.

**Esto mismo aplica a los addons de cliente** (añadido 13/09/2026): antes de
empezar, revisar también `addons.lock` con `tools/revisar-actualizaciones-addons.sh`
(§3.1), no sólo `versions.lock`. Son dos inventarios independientes y los dos
pueden traer novedades el mismo día. Actualizar un addon de verdad sigue
«Parches de addons de cliente» (REFERENCES.md) (hay traducción propia que reaplicar), no el
`install.sh --only N` de más abajo, que es sólo para core/módulos de servidor.
**Ojo**: los commits nuevos de un addon no son solo ida y vuelta de cadenas de
texto — también traen arreglos/fixes de verdad (ejemplo real, 13/09/2026:
QuestRadar trajo "Carry three Minimap.lua fixes into the server-module
variant"). El punto 4 de más abajo ("revisar el código nuevo en sí") aplica
igual a un addon que a un módulo de servidor: no basta con reaplicar la
traducción y dar por hecho que el resto es cosmético.

**Orden fijo** (añadido 11/09/2026, tras revisar core + mod-playerbots +
mod-dungeon-clear el mismo día; ampliado el mismo día con el punto 3b tras un
aviso del usuario: la primera pasada solo miró si algo se rompía, no si algo
nuevo servía):

1. Revisar los cambios nuevos (§3.1: `tools/revisar-actualizaciones.sh`).
2. Comprobar si afectan a los módulos, parches y scripts propios (§3.2).
3. Si afectan, medir el alcance y si es seguro aplicar correcciones e
   integraciones (parches que dejan de aplicar, símbolos que cambian de
   firma, claves de config que desaparecen: no es "sí/no actualizar", es
   "qué hay que tocar para que siga cuadrando").
3b. **Oportunidad, no solo riesgo.** "No rompe nada" no es la pregunta
    completa. Por cada commit/feature con peso real (no un `chore(DB)` o un
    typo) preguntar: ¿esto ya hace, de fábrica, algo que resolvimos a mano
    con un parche o un módulo propio? Una feature nueva opt-in y sin
    conflicto de compilación **no es "sin repercusión"** solo porque viene
    apagada por defecto: si pisa terreno de `patches/` o de `modules/`
    propios hay que leerla entera (no solo el título del commit) y decidir
    activamente si simplifica, sustituye o complementa lo que ya existe —
    y dejar la decisión (y el motivo) por escrito en el CHANGELOG, aunque
    sea "se deja como está porque...". Ejemplo real: mod-playerbots trajo
    `Playerbots.RandomBotConcentrateInPlayerZone`, que concentra bots por
    zona alrededor del jugador — mismo espíritu que nuestro
    `01-highest-player-bracket.patch` (que concentra por nivel), ejes
    distintos y sin conflicto de código, pero exactamente el tipo de
    novedad que merece revisión propia y no solo un "compila, no rompe
    nada, seguimos".
3c. **Todo candidato/propuesta va al plan de trabajo del proyecto, no solo al
    CHANGELOG.** Lo que sale del punto 3b como "vale la pena probarlo más
    adelante" (no se aplica ya, pero no se descarta) se registra ahí mismo,
    en la misma pasada de revisión — no queda solo mencionado de pasada en
    la conversación o enterrado en un commit viejo del CHANGELOG. El
    CHANGELOG cuenta lo que se hizo; el plan de trabajo cuenta lo
    que queda por decidir o probar.
3d. **Comandos nuevos → `modules/mod-server-help` y el panel.** Si alguno de
    los repos actualizados trae un comando de chat nuevo (`.algo`), aunque
    sea de administrador: el módulo descubre el comando solo (lee el árbol
    real del core), pero la ficha en español (`server_help_command`: título,
    descripción, sintaxis, ejemplos) no aparece sola — hay que darla de alta
    a mano en `modules/mod-server-help/data/sql/db-world/base/server_help.sql`
    (o el SQL propio correspondiente). Y si el panel web documenta comandos
    (`web-panel/`), también ahí. Comprobar esto es parte de la revisión del
    punto 2, no un paso aparte que se pueda saltar.
4. Revisar el código nuevo en sí (qué trae de verdad cada commit, no solo el
   `diff --stat`).
5. Desplegar (§3.3) y comprobar que todo va bien (`verificar-instalacion.sh`,
   y en juego lo que toque según lo que haya cambiado).
6. Commit y push del `versions.lock` actualizado y de lo que haya hecho
   falta tocar en `patches/`/`modules/` propios (y en el plan de trabajo, `mod-server-help` y el panel, si el punto 3c o 3d aplicó).

#### 3.1 Inventario: qué ha cambiado de verdad

Desde cualquier máquina con git, sin tocar el servidor:

```bash
grep -v '^#' versions.lock | while IFS=$'\t' read -r name branch commit date url; do
  head=$(git ls-remote --heads "$url" "$branch" | cut -f1)
  [ "$head" = "$commit" ] && echo "$name  al día" || echo "$name  NUEVO  ${commit:0:10} -> ${head:0:10}"
done
```

Es lo que hacen, sin tocar nada, `tools/revisar-actualizaciones.sh` (módulos de
servidor, contra `versions.lock`) y `tools/revisar-actualizaciones-addons.sh`
(addons de cliente de terceros, contra `addons.lock`). **Los dos `.lock`
cuentan**: un addon con novedades se actualiza según «Parches de addons de cliente» (REFERENCES.md)
(hay traducción propia que reaplicar).

El 01/09/2026 sólo 4 de 19 tenían cambios. No des por hecho que "actualizar"
significa 20 repositorios (son 20 desde el 02/09/2026, con `mod-dungeon-clear`;
ése es el más frágil ante una actualización de playerbots, porque accede a
interioridades privadas suyas: si deja de compilar, `INSTALL_MOD_DUNGEON_CLEAR=false`).

#### 3.2 Revisión previa, en local

Clona los repos que cambian (`git clone --filter=blob:none`) y comprueba, en
este orden:

1. **Parches** (`patches/*/*.patch`): si el módulo parcheado no ha cambiado, el
   parche aplica igual. Si ha cambiado, `git apply --check` sobre el árbol nuevo.
   El de `mod-challenge-modes` depende del **core**: mirar que
   `OnPlayerResurrect` siga con `bool&` en `PlayerScript.h`.
2. **Claves de configuración**: cada `Playerbots.*` / clave de módulo que
   escribe `05_configure_server.sh` tiene que existir en el `.conf.dist` **y en
   el código** nuevos. `git diff <viejo>..<nuevo> -- conf/*.conf.dist | grep '^-'`
   enseña las eliminadas.
3. **Módulos propios** (`modules/`): los símbolos de playerbots que usan
   (`IsTank`, `IsHeal`, `ResetStrategies`, `AddPlayerBot`, `LogoutPlayerBot`,
   `IsRandomBot`) con la misma firma en la versión nueva.
4. **SQL propio**: ids que usan los SQL nuevos del módulo contra los de
   `patches/locales-es/` (transmog usa 81-88; los nuestros son 18 y 19).
5. **Datos del cliente**: `grep -c 'expected v' Server.log` tras arrancar. Si el
   core exige una versión nueva de mmaps, buscar release en
   `wowgaming/client-data` (§6.3).

#### 3.3 Aplicar

En el repo del instalador se apunta `versions.lock` a los commits nuevos y se
sube a la VM con `pscp` (la VM no es un clon git; `md5sum` a los dos lados). Y
en la VM, en este orden:

```bash
bash tools/backup-servidor.sh
sudo systemctl stop ac-worldserver          # una unidad por orden: el
sudo systemctl stop ac-worldserver.socket   # sudoers NOPASSWD es por unidad,
sudo systemctl stop ac-authserver           # dos a la vez piden contraseña
./install.sh --only 3          # clona/fija versiones y reaplica parches
./install.sh --only 4          # recompila el target modules entero
./install.sh --only 5          # confs + SQL propio; MIRA el resumen de claves no declaradas
sudo systemctl start ac-authserver
sudo systemctl start ac-worldserver.socket
sudo systemctl start ac-worldserver
bash tools/verificar-instalacion.sh
```

Detalles que cuestan un intento fallido si no se saben:

- **Por SSH sin terminal** (`plink`/`ssh ... "..."`): `install.sh` usa `tput`,
  así que hace falta `export TERM=xterm-256color` antes, y responde al prompt de
  confirmación con `echo s | ./install.sh --only N`.
- **Con `WORLDSERVER_STANDBY=true`** (lo normal): si nadie juega, el worldserver
  ya está parado. Hay que parar además `ac-worldserver.socket`, o una conexión
  de cliente arrancaría el binario viejo a mitad de compilación; y volver a
  arrancarlo después. El aviso de 60 s y el `saveall` van por SOAP
  (`~/azerothcore/scripts/ws-console.sh`), no por `screen`.
- **`--only 4`** recompila el target `modules` completo tanto al añadir un
  módulo como al actualizar uno existente (mod-playerbots incluido). Con ccache
  y un solo módulo tocado son ~3 min; sin caché, ~25.
- **`--only 5`**: las tres advertencias de `HomeGuild.*` "NO declarada" son
  conocidas (claves propias de `mod-home-guild`, §3.10) y no cuentan.
- **Tras el primer arranque con un módulo actualizado**: si el SQL del módulo se reejecuta puede borrar
  filas de `patches/locales-es/` que la fase 5 aplicó antes (pasó con `mod-transmog` el 12/10/2026).
  `./install.sh --doctor` lo avisa (`traducciones-es`); se arregla con
  `bash scripts/reaplicar-traducciones.sh` (idempotente, no toca nada más).

Si todo va bien: `./install.sh --mirror` y traer `mirrors/` al repo (§8).

**Volver atrás**: recuperar el `versions.lock` anterior del historial de git y
repetir fases 3 a 5. Las migraciones de base de datos **no** se deshacen: por
eso la copia de seguridad va primero.

#### 3.4 Cuándo hacer instalación limpia en vez de actualizar

Cuando hay dudas de que el estado acumulado (DBC parcheados encima de otros,
claves pegadas al final de los `.conf`, tablas de bots de tres versiones) sea
el que produce un problema. El 01/09/2026 se optó por limpia precisamente para
probar que el instalador funciona de punta a punta. Cuesta ~45 minutos más que
actualizar y se lleva los personajes por delante: copia de seguridad antes.

---

### 4. Instalación limpia

> **Atajo**: `bash install.sh --guiado` (o `bash scripts/instalar-todo.sh` en modo
> manual) hace todo lo de esta sección y la siguiente (fases 1-7, primer arranque,
> `--post`, servicios, verificación) sin preguntar nada más que la contraseña de
> sudo una vez. Lo de abajo es el detalle.

Con copia de seguridad hecha:

```bash
sudo systemctl stop ac-worldserver ac-authserver
for db in acore_auth acore_characters acore_world acore_playerbots; do
    sudo mysql -e "DROP DATABASE IF EXISTS \`$db\`"; done
rm -rf ~/azerothcore
```

Las fases 1, 2, 6 y 7 usan `sudo` para apt, MySQL y systemd. Para que el
instalador corra desatendido hace falta un fichero temporal en
`/etc/sudoers.d/`, **escrito así y sólo así**:

```bash
echo "$PASS" | sudo -S bash -c "printf '%s\n' 'acore ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-temporal && chmod 440 /etc/sudoers.d/99-temporal"
sudo visudo -c -f /etc/sudoers.d/99-temporal        # tiene que decir "parsed OK"
```

> ⚠️ `echo "$PASS" | sudo -S tee /etc/sudoers.d/f` **no vale**: `tee` recibe por
> stdin la contraseña, no el contenido, y el fichero queda vacío. Funcionó unos
> minutos por la caché de credenciales de sudo y luego tumbó la fase 1.

Lanzar desatendido (el instalador usa `tput`: sin `TERM` aborta en la primera
línea):

```bash
cd ~/azerothcore-installer
export TERM=xterm-256color
setsid bash -c "echo s | ./install.sh > ~/instalacion.log 2>&1" < /dev/null &
```

Fases y tiempos del 01/09/2026 en el equipo de pruebas (Ryzen 7 7730U, 7 cores): clonado ~5 min,
compilación ~22 min, datos del cliente 1,2 GB a 11 MB/s ~2 min; **34m 34s** en
total. Al terminar, **quitar el sudoers temporal**:

```bash
sudo rm /etc/sudoers.d/99-temporal
```

Luego el primer arranque (§5) y `./install.sh --post`.

---

### 5. Primer arranque

Crea las bases de datos. El actualizador pregunta `Do you want to create it?`
por cada una, y hay que responder `yes`. `tools/primer-arranque.sh` lo hace
solo: arranca el worldserver con una tubería con nombre como stdin, le manda
seis `yes`, espera a que escuche en el puerto 8085 y lo apaga limpio.

Dos cosas que hay que saber, las dos aprendidas el 01/09/2026:

**"World initialized" ya no aparece en el log.** En este core sólo existe como
evento de métricas (`World.cpp`, `METRIC_EVENT`). Cualquier espera con `grep
'World initialized'` no salta nunca. La señal fiable es
`ss -ltn | grep ':8085 '`.

**Puede colgarse creando las cuentas de bots.** Síntoma: `Playerbots.log`
termina en `Waiting for 150 accounts loading into database (303 queries)...`,
el proceso al 1-2 % de CPU, todas las conexiones MySQL en `Sleep`, y
`SELECT COUNT(*) FROM acore_auth.account` = 0 durante minutos. El módulo espera
a que la cola asíncrona del pool de `acore_auth` se vacíe
(`RandomPlayerbotFactory.cpp`, `while (LoginDatabase.QueueSize())`) y la cola no
se mueve. Coincidió con avisos de InnoDB (`unable to reserve space in redo log`)
durante la importación de 447 MB del mundo. **No es determinista**: `pkill -TERM
worldserver` y volver a arrancar creó las 150 cuentas y los 1500 personajes en
24 segundos.

Tras el primer arranque, el `--post` crea la cuenta `admin`, escribe el
realmlist, coloca los NPC y aplica el SQL que la fase 5 no pudo aplicar porque
las bases no existían.

---

### 6. Diagnóstico: dónde mirar cuando algo falla

#### 6.1 Una opción de `config.sh` no hace nada

Primero el resumen de la fase 5: si dice `Clave 'X' NO declarada`, casi seguro
que `X` no existe con ese nombre. Comprobar contra el `.conf.dist` **y** contra
el código:

```bash
grep -rn '"NombreDeLaClave"' ~/azerothcore/src/server/game/World/WorldConfig.cpp   # core
grep -rn '"NombreDeLaClave"' ~/azerothcore/modules/<módulo>/src/                    # módulo
```

Si el código no la lee, no la lee. La sección *deprecated* del `.conf.dist` de
autobalance es una trampa: las claves están declaradas pero sólo para avisar.

Y en el servidor en marcha, las claves pegadas al final del `.conf` (después
del último bloque del dist) son las sospechosas:

```bash
tail -5 ~/azerothcore/env/dist/etc/worldserver.conf
```

#### 6.2 El servidor arranca pero va lento

`ps -o nlwp,pcpu -C worldserver`: con `MapUpdate.Threads = 4` son 15 hilos.
Si son 12 y la CPU está al 90-100 %, sólo hay un hilo de mapas. Ver §6.1.

#### 6.3 Los bots no se mueven / errores de mmaps

```bash
grep -c 'expected v' ~/azerothcore/env/dist/bin/Server.log
```

Si hay líneas `mmtile was built with generator vN, expected vM`, los datos del
cliente son viejos para este core. Releases en
`https://api.github.com/repos/wowgaming/client-data/releases` (el asset se
llama `Data.zip`, con mayúscula). Borrar `maps vmaps mmaps dbc cameras` y
`data-version` de `env/dist/bin/`, y `./install.sh --only 5` los vuelve a bajar.
Maps y vmaps no protestan; sólo los mmaps, y sólo en `Server.log`.

#### 6.4 Un parche deja de aplicar

La fase 3 lo dice y sigue: el módulo se queda sin el cambio. Regenerarlo según
«Escribir un parche sobre código de terceros» (REFERENCES.md). Si el parche toca también un `.conf.dist` (random-enchants),
el módulo hay que devolverlo a limpio antes de reaplicar: `git -C
~/azerothcore/modules/<módulo> checkout -- . && bash lib/reapply-patches.sh`.

#### 6.5 Un módulo no compila contra el core

Poner su `INSTALL_MOD_*` en `false`: la fase 3 lo aparta a `modules-disabled/` y
se sigue. Si el error es una firma de hook (`non-virtual member function marked
'override' hides virtual member function`), es un parche de dos líneas: ver el
de `mod-challenge-modes` en `patches/`.

#### 6.6 `.learn` no funciona

Pendiente de diagnosticar. Desde el 01/09/2026 los logs llevan hora: lanzar el
`.learn` que falle y `grep -a "$(date +%Y-%m-%d)" Errors.log | tail`.

---

### 7. Batería de pruebas

#### 7.1 Desde el servidor (automática)

```bash
bash ~/azerothcore-installer/tools/verificar-instalacion.sh
```

Comprueba los 20 commits contra `versions.lock`, las claves que estuvieron
rotas (`MapUpdate.Threads`, `AllowTwoSide.Interaction.Chat/Channel/Auction`),
que no quede ninguna clave fantasma, `LevelBrackets`, los módulos propios
(carpeta, `.conf` y última línea de log de cada uno), los avisos de claves no
declaradas del último `--only 5`, los módulos compilados, los parches y los
servicios. **Pasada el 01/09/2026** tras la instalación limpia, y de nuevo el
**23/09/2026** tras la reinstalación desde cero (purga completa + `instalar-todo.sh`).

Además, con el servidor arrancado: 0 errores de mmaps en `Server.log`, 150
cuentas y 1500 personajes de bot, `admin` con GM 3, realmlist en
`192.168.1.100:8085`, 15 hilos en el worldserver.

#### 7.2 Dentro del juego

Necesitan el cliente y las hace el jugador. La batería histórica —qué hacer,
qué ver y qué línea del log lo confirma para cada prueba— se conserva en
`CHANGELOG.md` (batería retirada el 10/09/2026). No hay pruebas pendientes
programadas; cualquier verificación nueva debe registrarse antes en el plan de trabajo.

---

### 8. Operar desde Windows

La VM **no** es un clon del repositorio: los cambios del instalador se suben
con `pscp` y se ejecutan con `plink` (PuTTY). Lo que ha funcionado bien:

```powershell
# subir un fichero (ruta absoluta en el destino: pscp no expande ~)
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw <pass> config.sh acore@192.168.1.100:/home/acore/azerothcore-installer/config.sh

# ejecutar un script (subirlo antes; las comillas dentro de un -c se pierden)
& "C:\Program Files\PuTTY\plink.exe" -batch -ssh acore@192.168.1.100 -pw <pass> "bash /home/acore/script.sh"

# traer una carpeta (copia de seguridad, mirrors)
& "C:\Program Files\PuTTY\pscp.exe" -batch -r -pw <pass> acore@192.168.1.100:/home/acore/backup-2026... "<copias>\"
```

Verificar siempre con `md5sum` a los dos lados después de subir, y subir en
LF (`bash` no traga CRLF).

Herramientas del repo pensadas para esto, en `tools/`:

| Script | Qué hace |
|---|---|
| `backup-servidor.sh` | Parada segura + volcado de las 4 bases + confs + logs |
| `primer-arranque.sh` | Primer arranque desatendido (responde `yes`, espera el 8085, apaga) |
| `verificar-instalacion.sh` | La batería automática de §7.1 |
| `cliente-sintetico/verificar.py` | Cliente de WoW sin interfaz que entra al juego y comprueba lo que antes exigía jugar: catálogo de casos (`listar`, `describir`, `ejecutar`, `limpiar`) con ARAC, IP + Cronista, bots, módulos propios, party-here, buscador con queue-bots y una mazmorra entera con el jugador en selfbot y telemetría de anomalías. Cuenta `VERIFICADOR`; ver «El verificador sintético» (REFERENCES.md) |
| `comprobar-modelos-cliente.py` | Por qué un objeto se ve como un cubo (falta arte en el cliente) |
| `revisar-actualizaciones.ps1` / `.sh` | ¿Hay commits nuevos río arriba? Tabla por repositorio contra `versions.lock` (sólo `git fetch`) y el aviso de mod-update-notice. El `.ps1` lo sube a la VM y lo ejecuta desde Windows: `-SoloNovedades`, `-SinFichero`, `-Log <repo>` |

---

## Parte 5 — El PC del jugador y el panel web

Lo que no se instala en el servidor: los ficheros del cliente de WoW que hay que
copiar en cada PC que juegue, y el panel web, que corre en el servidor pero se
usa desde el navegador.

### El cliente (`cliente/`)

El servidor no puede meter nada en el cliente por sí solo: el WoW 3.3.5a no
descarga parches ni addons de un servidor privado. Esta carpeta reúne **todo lo
que hay que copiar en cada PC que juegue**, con la misma estructura que la
carpeta del juego, para que instalarlo sea copiar dos carpetas encima (o
ejecutar el script) y para poder automatizarlo algún día desde un lanzador.

```
cliente/
├── Data/
│   ├── esES/patch-esES-4.MPQ          ← objetos propios del servidor + razas y clases (ARAC)
│   └── enUS/patch-enUS-4.MPQ          ← lo mismo para el cliente en inglés
├── Interface/AddOns/
│   ├── ServerHelp/                    ← la pestaña "Solicitud de ayuda" con los comandos del servidor
│   ├── MultiBot/                      ← panel de mando propio/mejorado (no se reemplaza)
│   └── …                              ← colección local de addons 3.3.5a servida por el panel
├── manifest.tsv                       ← qué es cada cosa y dónde va (para automatizar)
└── instalar-cliente.ps1               ← lo copia todo en Windows
```

**En la edición pública `cliente/` sólo trae `ServerHelp`, `MultiBot`, `manifest.tsv` y el script:** los `.MPQ`
de `Data/` (que llevan DBC completos de Blizzard) y el resto de addons no viajan en el Git. Los parches se generan
desde tu cliente en el panel y los addons se reconstruyen con hash (ver «Recursos que salen de tu cliente»); desde
el propio panel se instalan en el PC. `instalar-cliente.ps1` sirve con un repositorio de trabajo que traiga todo
y avisa de lo que falte.

#### Instalar

**Windows (recomendado)**, desde PowerShell, indicando la carpeta donde está `Wow.exe`:

```powershell
powershell -ExecutionPolicy Bypass -File .\cliente\instalar-cliente.ps1 -Cliente "<cliente>" -Realm 192.168.1.100
```

Copia `Data/` y `Interface/` encima de la carpeta del juego (los addons se
sincronizan enteros: lo que sobre en `AddOns/ServerHelp` o `AddOns/MultiBot` se
borra, el resto de addons no se toca; los `.MPQ` de idioma van a
`Data/esES/` y `Data/enUS/`), quita las copias sueltas de la antigua ARAC
(`Data/Patch-Arac.MPQ` y los nombres que se probaron antes, `Patch-X.MPQ`,
`Patch-C.MPQ`, `Patch-A.MPQ`) **sólo si su MD5 coincide con el de esa ARAC
vieja conocida** (para no tocar un archivo de otro origen que se llame
igual — el propio cliente de referencia trae `patch-A.mpq`/`patch-C.mpq`
legítimos, sin relación con ARAC), **borra `Cache/`** si instaló algún MPQ
(los DBC han cambiado; si no, el cliente enseña datos viejos), y con `-Realm`
escribe `set realmlist ...` en el `realmlist.wtf` de cada idioma. Se puede
repetir: es idempotente. Con el WoW abierto no puede borrar `Cache/` —
ciérralo y repite.

**A mano**: copiar el contenido de `cliente/Data/` a `WoW/Data/`
(con sus subcarpetas `esES/` y `enUS/`) y el de `cliente/Interface/AddOns/` a
`WoW/Interface/AddOns/`, y borrar `WoW/Cache/`. Si te queda de una instalación
antigua un `Data/Patch-Arac.MPQ`, `Patch-X.MPQ` o `Patch-C.MPQ` suelto, puedes
borrarlo: nunca se cargó (ver más abajo) y sus DBC ya van dentro de
`patch-<idioma>-4.MPQ`.

Al entrar en el juego, en la pantalla de personajes, botón **AddOns** (abajo a
la izquierda): tienen que aparecer `ServerHelp` y `MultiBot` marcados. Si sale
"desactualizado", marcar "Cargar addons desactualizados" (no lo están: el
cliente 3.3.5a es la interfaz 30300, que es la declarada).

La colección opcional de NoM0Re también se conserva extraída en
`Interface/AddOns`. El panel web permite instalar sólo lo elegido; al copiar
esta carpeta completa a mano se copiará toda la colección. Su catálogo,
descripciones en español y procedencia están en `web-panel/addons/`. El proceso
de actualización bloquea expresamente `MultiBot` y `ServerHelp`, por lo que una
versión externa nunca puede sobrescribir nuestras versiones.

#### Qué es cada cosa

##### `Data/esES/patch-esES-4.MPQ` y `Data/enUS/patch-enUS-4.MPQ`

Dos ficheros de datos del cliente que llevan dos cosas distintas fundidas en
el mismo MPQ:

| Fichero dentro del MPQ | Qué lleva |
|---|---|
| `Item.dbc` | El cliente saca el **icono** de aquí y sólo conoce hasta el `entry` ~56806. Se le añade la fila `600000 → displayid 22071` (`INV_Misc_Key_11`, la **Ganzúa de recompensa**; ver `REFERENCES.md`). |
| `Spell.dbc` | La línea verde *"Uso: …"* la saca de aquí. La ganzúa usa el hechizo 59403 (el de la *Titanium Skeleton Key*), cuyo texto dice "llave esqueleto". Se le reescribe la Descripción a *"Abre cualquier cajón o caja cerrada. Se consume al usarla."* |
| `CharBaseInfo.dbc`, `CharStartOutfit.dbc`, `SkillRaceClassInfo.dbc` | Los tres DBC de **ARAC**: hacen que la pantalla de creación de personaje ofrezca cualquier raza con cualquier clase. Copia sin modificar de `patch-contents/DBFilesContent/` del repositorio de mod-arac (mismo commit fijado en `versions.lock` que usa el servidor). |

El **nombre** y la **descripción amarilla** de los objetos propios vienen del
servidor y no están aquí; este parche no cambia nada mecánico, sólo textos y
DBC de cliente. Sin `CharBaseInfo.dbc`/`CharStartOutfit.dbc`/
`SkillRaceClassInfo.dbc` las combinaciones ARAC no aparecen al crear
personaje **aunque el servidor sí las acepte** (su SQL y sus DBC los aplica
el instalador); tampoco cargan hechizos correctamente en el libro de
hechizos de esos personajes (ver más abajo).

Estos DBC **sí** los traen otros parches del cliente (`patch-esES-3.MPQ`,
`patch-enUS-3.MPQ`), así que el nombre y el sitio NO son libres: van en
`Data/<idioma>/` con el nombre `patch-<idioma>-4.MPQ`. El Wow.exe carga
`patch-<idioma>-4.MPQ` y, por ser parche de idioma con sufijo -4, manda sobre
el `-3`. Se hace en `esES` y `enUS` porque el WoW carga la cadena del idioma
con el que arranca.

Lo genera **`tools/construir-parche-cliente-items.py`** (lee los DBC del cliente,
mete lo propio, empaqueta el MPQ). Hay que **regenerarlo** si ChromieCraft
actualiza sus DBC: si no, se pierde lo que trajera ese parche.

###### Por qué ARAC ya no va en `Data/Patch-Arac.MPQ` suelto (21/09/2026)

Hasta el 21/09/2026 los tres DBC de ARAC iban en un fichero aparte,
`Data/Patch-Arac.MPQ` (byte a byte el `Patch-A.MPQ` del repositorio de
mod-arac; antes `Patch-C.MPQ`). Ese fichero **nunca lo cargaba el Wow.exe**:
el cargador que enumera parches sueltos de `Data/` (desensamblado real del
ejecutable, no sólo FrameXML) exige un **único carácter** tras `"patch-"`
(`patch-?.MPQ`); `"Arac"` no encaja y el archivo se quedaba en el disco sin
efecto. El síntoma en juego era muy concreto: cualquier personaje con una
combinación de raza/clase que sólo existe por ARAC (p. ej. Paladín elfo
nocturno) mostraba **todos** sus hechizos bajo "General" en el libro de
hechizos, sin pestañas de árbol — el cliente resuelve la pestaña mirando el
índice de `CharBaseInfo.dbc` por raza/clase, y si la combinación no está ahí
(porque el DBC efectivo seguía siendo el original, sin las filas de ARAC)
devuelve nulo y todo cae en General, aunque los hechizos tengan su fila de
`SkillLineAbility` correcta. No tiene relación con la caché del cliente.
Detalle completo del diagnóstico y la evidencia en
`CHANGELOG.md`, tarea E1g.

La solución fue meter esos mismos tres DBC dentro de
`patch-<idioma>-4.MPQ` en vez de en un fichero aparte: ese nombre sí lo carga
el Wow.exe (es el mismo mecanismo que ya arregló de verdad el libro de
hechizos de Chamán y Brujo). `cliente/instalar-cliente.ps1` borra
`Data/Patch-Arac.MPQ` y las copias con otro nombre de instalaciones
anteriores (`Patch-X.MPQ`, `Patch-C.MPQ`, `Patch-A.MPQ`) sólo si su MD5
coincide con el de esa ARAC vieja conocida, para no tocar por error un
`patch-A.mpq`/`patch-C.mpq` legítimo de otro origen (el propio cliente de
referencia trae parches con esos nombres, sin relación con ARAC).

##### `Interface/AddOns/ServerHelp`

Addon propio (02/09/2026). Sustituye la lógica de la pestaña "Ayuda básica"
de "Solicitud de ayuda" (el botón `?` de la barra) para que, en vez de
consultar por HTTP los servidores de Blizzard (que es lo que hace el cliente
original, y por eso siempre salía "no disponible"), pregunte al servidor por
el canal de addon y enseñe **todos los comandos que tu cuenta puede usar**, con
su uso, descripción, permiso, ejemplos y categoría, más artículos sobre cómo
funciona el servidor. El filtro lo hace el servidor con tu sesión real: un
jugador no recibe ni los nombres de los comandos de GM; si te suben a GM y
vuelves a entrar, aparecen solos.

- Buscador, categoría y subcategoría, lista paginada de 20, ficha con scroll y
  botón Volver, mensaje de "cargando", de "sin resultados" y de error. Todo
  con los frames originales de Blizzard: mismo aspecto.
- Los botones de ticket ("Hablar con un MJ", "Informar de problema",
  "Personaje atascado", "Informar de lag", editar y abandonar consulta) siguen
  donde estaban y funcionan igual.
- `/ayudaservidor` abre la pestaña directamente.
- Necesita `mod-server-help` en el servidor. Sin él, la pestaña muestra un
  aviso y el resto de la ventana sigue funcionando.
- Habla por el canal de addon que el core ya procesa (prefijo `AzerothCore`,
  comando `.ayuda ...`). No usa ningún paquete nuevo ni requiere tocar `Wow.exe`.
  Detalle técnico en `REFERENCES.md` y en la cabecera de
  `ServerHelp.lua`.

##### `Interface/AddOns/MultiBot`

Panel de mando de los bots de playerbots (Nico Löbbert, v2.0.0, octubre de
2024): botones para las órdenes de grupo, estrategias, botín, equipo, hechizos
por clase... Es el addon que ya estaba instalado en el cliente de referencia
(`<cliente>`), copiado de ahí el 02/09/2026 **sin su
carpeta `Screenshots/`** (27 MB de capturas para su documentación, que el addon
no usa). Es un addon distinto de
[unbot-addon](https://github.com/liyunfan1223/unbot-addon), que hace lo mismo
con otra interfaz; sirve cualquiera de los dos.

#### `manifest.tsv`: para automatizar la instalación

Una línea por elemento, con tabuladores: `origen` (relativo a `cliente/`),
`destino` (relativo a la carpeta del WoW), `tipo` (`mpq` o `addon`) y `nota`.
Es lo que lee `instalar-cliente.ps1`, y lo que leería un lanzador que
descargase estos ficheros del servidor al conectarse: le basta con servir esta
carpeta por HTTP y aplicar el manifiesto. Cuando se añada algo al cliente,
se añade aquí.

#### Cómo añadir algo

1. Ponerlo en `cliente/` con la misma ruta que tendría dentro del WoW.
2. Añadir su línea a `manifest.tsv`.
3. Explicarlo en este README (qué es, de dónde sale, por qué hace falta).
4. Si es un `.MPQ` genérico suelto en `Data/` (no de idioma): el Wow.exe sólo
   carga `patch-<UN carácter>.MPQ` (`patch-A.MPQ` … `patch-Z.MPQ`,
   `patch-0.MPQ` … `patch-9.MPQ`; comprobado por desensamblado, ver E1g de
   `CHANGELOG.md`) — un nombre más largo se queda sin cargar y sin
   avisar. Si necesitas más de un carácter para el nombre, mételo dentro de
   `patch-<idioma>-4.MPQ` (como ARAC, arriba) en vez de como fichero suelto.
   Si sí usas una sola letra/dígito, comprueba primero con
   `tools/comprobar-modelos-cliente.py` o `mpyq` que no pisa ficheros de otro
   parche del cliente que ya use esa letra (si los pisa, el orden alfabético
   decide).

### El panel web (`web-panel/`)

Aplicación de la Fase 1 para AzerothCore 3.3.5a. Autentica contra el `salt` y
`verifier` SRP6 de `acore_auth.account`, muestra jugadores conectados, ofrece
un **mapa** para cada jugador con su círculo social (grupo, banda, hermandad y
amigos conectados) y otro de posiciones de todo el reino protegido para cuentas
GM, distribuye un catálogo local
de addons compatibles con el cliente 3.3.5a, y añade una armería de personajes
y un lector de comandos del servidor (ver más abajo). También permite
registrar cuentas nuevas con invitación, cambiar la contraseña, y moderar el
reino (expulsar, banear, silenciar, anunciar, enviar objetos y oro) desde
cuentas GM (ver «Cuentas» y «Moderación» más abajo).

#### Idioma (español / inglés)

El panel se ve en español o en inglés. Al abrirlo usa el idioma del navegador
(cualquiera que no sea español abre en inglés); el selector de la cabecera, junto
al indicador de estado, y el de las pantallas de entrada y registro lo cambian: se
recuerda en el navegador y la página se recarga. La API contesta en el mismo
idioma: el navegador manda el suyo en la cabecera `X-Panel-Lang` (sin ella, español)
y se traducen los mensajes de error, los avisos de los trabajos de recursos y los
nombres de objeto de la armería (en inglés salen de `item_template`, el original;
en español, de `item_template_locale`).

También se traducen los catálogos. El inglés de **Comandos** vive en las columnas
`title_en`, `description_en` y `body_en` de `server_help_*` (las rellena
`server_help.sql`, así que un cliente de juego en inglés también lo ve; si una está
vacía, cae al español); las descripciones de **Configuración** están en
`src/locales/config-*-en.js` (por clave del `.conf`), las de los addons en
`addons/descriptions-en.json` (por id) y los textos de `doctor.sh` se traducen con
plantillas en `src/locales/en.js`. No se traduce lo que escribe alguien en la
partida (nombres de personajes y hermandades, motivos de sanción), lo que devuelve
la consola del worldserver al ejecutar una acción de moderación, ni las palabras
clave, la sintaxis y los ejemplos de las fichas de **Comandos** (son los comandos
reales, en español).

Para añadir o cambiar un texto: la clave es el propio texto en español. En
`public/` se escribe `t('Texto con {marcador}', { marcador })` y su traducción va en
`public/locales/en.js`; en `src/`, el mensaje de error en español y su traducción en
`src/locales/en.js` (una plantilla `{x}` cubre los mensajes con valores). El HTML
estático se traduce solo (nodos de texto y atributos `placeholder`, `title`,
`aria-label` y `alt`); un fragmento con etiquetas dentro lleva `data-i18n-html` y su
HTML interno es la clave. `test/i18n.test.js` y `test/server-i18n.test.js` fallan si
falta una traducción, sobra una clave o no coinciden los marcadores.

#### Actualizaciones

La sección **Actualizaciones**, situada debajo de **Configuración**, sólo es
visible para administradores (gmlevel 3). Al pulsar **Comprobar ahora** compara
los commits fijados de `versions.lock` (core y módulos) y `addons.lock`
(addons de cliente) con la cabeza de sus ramas en GitHub, como los scripts
`tools/revisar-actualizaciones.sh` y
`tools/revisar-actualizaciones-addons.sh`. Muestra cada repositorio por
separado y enlaza la comparación de commits cuando hay novedades.

La operación usa únicamente `git ls-remote`: no instala nada, no modifica los
clones y no reinicia el servidor. El despliegue guarda ambos locks en la zona
aislada del panel y `./install.sh --freeze` refresca automáticamente allí la
copia de `versions.lock`.

#### Comandos y ayuda del servidor

La sección **Comandos** lee las mismas tablas que usa el addon `ServerHelp`
dentro del juego (`server_help_category`, `server_help_article` y
`server_help_command` en `acore_world`). El catálogo incluido documenta 232
rutas del core y de los módulos instalados (incluye `.hermandad` de
mod-home-guild). A diferencia del addon, el panel
sólo muestra las rutas con ficha propia: el árbol completo lo conoce el
worldserver en memoria y se sigue consultando dentro del juego con `.commands`
o `.help`.

Cada ficha tiene su propio `min_security` (0 jugador, 1 moderador, 2 GM,
3 administrador); la categoría es sólo temática y no concede visibilidad. Si
una categoría temática todavía no es visible para una cuenta que sí puede usar
el comando, éste cae en la categoría general de su rango, igual que en
`mod-server-help`. Las fichas antiguas con `min_security = NULL` conservan la
compatibilidad heredando el mínimo de su categoría. Los artículos ligados por
`command_path` tampoco se envían si su comando no es visible. La interfaz
muestra el rango requerido, distingue fichas de familia y busca también en uso
y ejemplos.

#### Armería

Desde **Jugadores** o desde la búsqueda de **Armería** se puede abrir
cualquier personaje, esté o no conectado, y ver su equipo puesto con el icono
real de cada objeto, su nombre coloreado por calidad y sus estadísticas
principales. Los iconos se extraen del cliente 3.3.5a, se convierten a WebP y
se sirven localmente: la armería no consulta servicios externos. Si el personaje es
tuyo (misma cuenta que ha iniciado sesión), además aparecen las pestañas
**Bolsas**, **Banco** y **Hermandad** con el contenido real de bolsas, banco y
banco de hermandad. El banco de hermandad respeta los permisos de tu rango
(`guild_bank_right`); el líder (rango 0) ve todas las pestañas, igual que en
el juego.

Los iconos y el mapa `displayid` → icono **no** van en la edición pública (son
arte de Blizzard): el panel los genera desde tu cliente, en el paso «Recursos
que salen de tu cliente» (más abajo), y los sirve desde su carpeta de datos
(`/var/lib/azerothcore-panel/recursos/iconos`). Mientras no existan, el panel
arranca igual y la armería muestra un icono genérico propio. El generador sigue
pudiendo usarse a mano contra una carpeta de cliente:

```bash
python tools/extract-item-icons.py --client "/ruta/al/cliente"          # a public/assets/item-icons
python tools/extract-item-icons.py --insumos <carpeta> --salida <destino>  # con ficheros ya extraídos
```

El proceso escribe primero en una carpeta temporal, conserva un icono genérico
para las referencias sin arte y deja la procedencia exacta en
«Procedencia de mapas e iconos» (REFERENCES.md).

Cortesía de estas dos secciones: hacen falta permisos `SELECT` adicionales
para el usuario `acore_panel` (equipo/bolsas/banco, hermandad y las tablas de
`server_help_*` de `acore_world`). El instalador (`deploy/install.sh`) ya los
concede; basta con volver a ejecutar `./install.sh --panel` para aplicarlos a
una instalación existente.

#### Cuentas: registro y contraseña

Desde la pantalla de acceso, «¿No tienes cuenta?» abre un formulario de
registro que exige una **clave de invitación de un solo uso**. Un
administrador (gmlevel 3) la genera desde **Moderación → Administración**; la
base sólo guarda el hash SHA-256 de la clave, así que ni siquiera leyendo la
tabla se obtiene una invitación utilizable, y el texto en claro sólo se enseña
una vez, en el momento de crearla. Consumir la invitación y crear la cuenta
son atómicos (una transacción sobre `acore_auth`): un fallo a mitad no deja ni
la invitación gastada ni una cuenta a medias. Un administrador puede además
crear una cuenta directamente, sin invitación.

Cualquier cuenta puede cambiar su contraseña desde **Mi cuenta**, pidiendo la
actual. El verifier SRP6 se recalcula igual que en el registro
(`src/srp6.js`); si tienes una sesión de juego abierta, sigue activa hasta que
vuelvas a conectarte (el core no invalida `session_key` al cambiar la
contraseña). La contraseña, igual que en el cliente 3.3.5a, tiene que tener
entre 8 y 16 caracteres.

#### Moderación

Visible sólo para cuentas GM, con las mismas categorías 1-3 que ya usa
«Comandos» (moderador, game master, administrador). Cada acción se manda por
**SOAP** a la consola del worldserver (`127.0.0.1:7878`, apagada por defecto en
AzerothCore y activada por este mismo instalador cuando el panel está
habilitado): es la única vía que expulsa o silencia a alguien que ya está
conectado y que confirma que el comando se aplicó, a diferencia de escribir
directamente en `account_banned`/`character_banned` (que sólo surtiría efecto
en el siguiente inicio de sesión). El panel se identifica ante SOAP con una
cuenta de servicio dedicada (`panel_soap`, gmlevel 3) que el instalador crea
aparte de la tuya.

| Nivel | Acciones |
|---|---|
| Moderador (1) | Expulsar, silenciar, quitar silencio |
| Game master (2) | Banear/desbanear cuenta o personaje, anunciar a todo el servidor |
| Administrador (3) | Enviar objetos y oro por correo, generar invitaciones, crear cuentas |

Nunca se puede actuar sobre una cuenta con rango igual o superior al de quien
ejecuta la acción, aunque técnicamente la cuenta de servicio SOAP tenga
gmlevel 3: el backend comprueba el gmlevel del objetivo antes de mandar el
comando. Ningún texto escrito en un formulario llega tal cual a la consola:
`src/commands.js` es una lista blanca de plantillas con su propio validador
(nombres, duraciones de una lista cerrada, motivos sin comillas ni saltos de
línea) — si algo no encaja, el comando ni se construye. Toda acción de
moderación, con su resultado, queda en `acore_panel.panel_audit`.

#### Addons para jugadores

La sección **Addons** sólo aparece después de iniciar sesión. Incluye 118
paquetes de la colección de NoM0Re y los addons obligatorios `MultiBot`,
`ServerHelp`, `GuildLevels`, `BugSack` (con `!BugGrabber`, necesario para que
funcione) y `Addon Control Panel`; se marcan con ★ y no se pueden desmarcar ni
desinstalar desde el panel. Nuestra copia de ACP protege por defecto a esos
tres últimos (`ACP.lua` los añade a `ProtectedAddons`): ACP los reactiva solo
si alguien los desactiva y no los toca al "Desactivar todos". Se puede buscar
y filtrar, consultar la explicación y procedencia, seleccionar paquetes o
descargar cada ZIP. Los archivos se leen siempre de la copia canónica
`cliente/Interface/AddOns`; el servidor genera el ZIP al vuelo y GitHub no
interviene en las descargas de los jugadores. Todo el catálogo está en español
de España (incluidas las notas dentro del propio `.toc` que se ven en la
pantalla de Addons del juego) e incluye un filtro de recomendaciones por clase.

Chrome y Edge permiten elegir la carpeta que contiene `Wow.exe`, instalar la
selección directamente en `Interface/AddOns` y copiar los parches del servidor
en `Data`. El panel compara el contenido real de cada addon/parche instalado
con un hash del que sirve ahora mismo: si coincide lo marca **Instalado** y no
lo vuelve a copiar al pulsar instalar (para no pisar `SavedVariables` ni
configuración guardada); si no coincide, **Actualización disponible**. Los
addons y parches no obligatorios llevan un botón **Desinstalar** que borra su
carpeta o archivo. Se publican `patch-esES-4.MPQ` / `patch-enUS-4.MPQ`
(objetos propios del servidor —icono y textos— y las combinaciones de raza y
clase de ARAC, fundidos en el mismo MPQ; van en `Data/esES/` y `Data/enUS/`
porque sus DBC los trae también `patch-<idioma>-3.MPQ` del cliente). El campo
`targetDir` del catálogo (`addons/patches.json`) indica la subcarpeta. Tras copiar parches nuevos o cambiados, "Instalar parches" **borra
`Cache/`** del cliente (los DBC han cambiado): el jugador sólo reinicia el WoW;
si ya estaban todos al día, no toca nada. El panel verifica el ejecutable, pide
permiso de escritura mediante el selector nativo y rechaza rutas inseguras o
archivos sin `.toc`. Esta API del navegador exige un contexto seguro: en una IP
servida sólo por HTTP queda disponible la descarga ZIP, pero la instalación
directa requiere publicar el panel por HTTPS (o usarlo desde `localhost`).

La procedencia, el commit fijado y el procedimiento de actualización están en
«El catálogo de addons del panel» (INSTALL_ES.md, parte 5). Las cinco fuentes RAR se importan igual
que los ZIP y las descargas generadas son instalables desde el navegador.

#### Despliegue junto al servidor

El instalador global lo ejecuta automáticamente después del primer arranque.
Para instalar o actualizar únicamente el panel:

```bash
cd /ruta/al/instalador
./install.sh --panel
```

El panel quedará en `https://IP_DEL_SERVIDOR`. El instalador:

- publica Nginx por HTTPS en el puerto 443, redirige el puerto 80 y abre ambos
  si UFW está activo;
- mantiene Node y MySQL ligados a `127.0.0.1`;
- crea la base propia `acore_panel` (invitaciones y auditoría) y
  `acore_panel@127.0.0.1` con `SELECT` en las tablas de lectura del core
  (jugadores, equipo/bolsas/banco, hermandad, baneos y la base de conocimiento
  de `acore_world`), `INSERT`/`UPDATE` acotados **por columna** en
  `acore_auth.account` (sólo `username, salt, verifier, expansion` al crear y
  `salt, verifier` al cambiar contraseña — nunca `gmlevel` ni `locked`),
  `INSERT` en `realmcharacters`, y lectura/escritura completas sobre su propia
  base `acore_panel`;
- crea la cuenta de servicio `panel_soap` (gmlevel 3) con la que el panel
  habla con la consola SOAP del worldserver para moderar (§ Moderación);
  activa SOAP en `worldserver.conf`, sólo en `127.0.0.1:7878`, es cosa de la
  fase 5 del instalador global (`./install.sh --only 5` + reinicio del
  worldserver), no de este script;
- genera credenciales, secreto de sesión y contraseña SOAP aleatorios en
  `/etc/azerothcore-panel.env` (modo `0600`);
- instala y activa `azerothcore-panel.service`.

La instalación es idempotente. Cada ejecución vuelve a sincronizar el código y
los recursos estáticos desde `web-panel/`, conserva los secretos existentes de
`/etc/azerothcore-panel.env`, instala sólo las dependencias de producción y
reinicia el servicio. Por tanto, después de modificar el panel basta con volver
a ejecutar `./install.sh --panel`.

En una red local, el instalador crea una autoridad certificadora persistente y
un certificado con la IP y el nombre del servidor. Antes del primer acceso,
descarga `http://IP_DEL_SERVIDOR/azerothcore-panel-ca.crt` e instálalo en el
almacén **Entidades de certificación raíz de confianza** del equipo. Después,
abre `https://IP_DEL_SERVIDOR`; Chrome/Edge reconocerá el origen como seguro y
habilitará el selector de carpetas. La clave privada de la CA nunca se publica.

Si ya dispones de un certificado confiable, indica sus rutas al desplegar:

```bash
sudo env PANEL_TLS_CERTIFICATE=/ruta/fullchain.pem PANEL_TLS_KEY=/ruta/privkey.pem bash web-panel/deploy/install.sh
```

Si los puertos 80 o 443 están ocupados, elige otros antes de ejecutarlo:

```bash
sudo env PANEL_HTTP_PORT=8080 PANEL_HTTPS_PORT=8443 bash web-panel/deploy/install.sh
```

Las opciones `INSTALL_WEB_PANEL`, `PANEL_HTTP_PORT`, `PANEL_HTTPS_PORT`,
`PANEL_TLS_CERTIFICATE`, `PANEL_TLS_KEY`, `PANEL_REALM_ID`,
`PANEL_AUTH_DATABASE`, `PANEL_CHARACTERS_DATABASE`, `PANEL_WORLD_DATABASE`,
`PANEL_PANEL_DATABASE`, `PANEL_DB_USER` y `PANEL_SOAP_ACCOUNT` viven en
`config.sh`. Las cookies de sesión se marcan siempre como `Secure` en el
despliegue de producción.

#### Desarrollo

```bash
cp .env.example .env
npm install
set -a; source .env; set +a
npm run dev
```

En PowerShell, carga las variables de `.env` manualmente antes de ejecutar
`npm run dev`. Las pruebas no necesitan una base de datos:

```bash
npm test
npm run check
```

#### Decisiones de seguridad

- La contraseña nunca se guarda: se recalcula el verifier SRP6 y se compara en
  tiempo constante, tanto para entrar como para registrarse o cambiarla.
- La sesión es una cookie firmada `HttpOnly` y `SameSite=Strict`, con caducidad
  de 8 horas.
- El backend vuelve a consultar `account_access` en cada petición del mapa y de
  moderación. Una retirada de rango tiene efecto sin esperar a un nuevo login.
- Los endpoints no cachean datos personales y el login/registro limitan
  intentos por IP.
- El catálogo y todos los paquetes requieren sesión; los nombres de archivo se
  resuelven desde el manifiesto validado y nunca desde una ruta aportada por el
  usuario.
- La interfaz oculta el mapa y la moderación a quien no tiene rango, pero la
  protección efectiva está siempre en el backend (`/api/map/players`,
  `/api/moderation/*`).
- El panel **sí** escribe en el core, pero de forma acotada y explícita: crea
  cuentas y cambia contraseñas (permiso de columna, nunca `gmlevel`/`locked`) y
  manda comandos de moderación por SOAP con una cuenta de servicio dedicada,
  nunca SQL directo sobre `account_banned`/`character_banned`. Ningún texto de
  un formulario llega tal cual a un comando: `src/commands.js` es una lista
  blanca con validador propio por campo. Toda acción de escritura queda en
  `acore_panel.panel_audit`, y no se puede actuar sobre una cuenta de rango
  igual o superior al de quien la ejecuta.

El rol se infiere usando talentos característicos del grupo activo. En WotLK
algunas configuraciones híbridas (por ejemplo, druida feral o DK) no codifican
un rol inequívoco en la base de datos; si no hay una señal defensiva o de
sanación fiable, el panel muestra DPS.

#### Mapa del jugador (círculo social)

Bajo **Jugadores**, la sección **Mapa** la ve cualquier cuenta y muestra, sobre
los mismos mapas de continente, las posiciones de los miembros **conectados** de
tu grupo, tu banda, tu hermandad y tu lista de amigos —igual que las chinchetas
de grupo/banda dentro del juego, ampliado a hermandad y amigos—. El punto lleva
el color de la clase y el aro exterior el de la relación: **grupo azul, banda
naranja, hermandad verde, amigos dorado**; tú apareces con el aro blanco.

**No es en directo.** Tanto este mapa como el GM leen `characters.position_x/y`,
que el worldserver sólo escribe cada `PlayerSaveInterval` (15 min por defecto) y
en ciertos eventos: cambio de continente, entrada/salida de instancia,
desconexión, piedra de hogar, subir de nivel. Entre guardados la posición puede
estar desfasada; la hora que muestra el panel es la de su última consulta. Un
aviso fijo bajo la cabecera de ambos mapas lo deja claro. Para afinarlo habría
que bajar `PlayerSaveInterval` (más escrituras a MySQL, con la población de bots
conectados).

El círculo social es por personaje. Un selector elige de qué personaje tuyo se
muestra; por defecto, el que tengas conectado. Si ninguno lo está, eliges uno y
se enseñan los miembros conectados de su hermandad y sus amigos (el grupo sólo
existe mientras juegas). Cuando alguien encaja en varias categorías gana la más
cercana: grupo/banda › amigo › hermandad.

`GET /api/social/map` sólo devuelve posiciones de personajes con un vínculo
social con **uno de tus propios personajes** (tabla `group_member`/`groups`,
`guild_member` y `character_social` de `acore_characters`), y sólo si están
conectados. No expone el resto del reino: eso sigue siendo exclusivo del mapa
GM. El instalador (`deploy/install.sh`) concede el `SELECT` necesario sobre
`group_member`, `groups` y `character_social`; en una instalación existente,
`./install.sh --panel` lo reaplica.

#### Cartografía

Los cuatro continentes usan mapas limpios de la interfaz del juego a 3840 ×
2560, publicados en Warcraft Wiki: Reinos del Este anterior a Cataclysm,
Kalimdor, Terrallende y Rasganorte. Las fuentes y los SHA-256 concretos están en
«Procedencia de mapas e iconos» (REFERENCES.md). Se sirven
localmente; el navegador no consulta servicios externos.

El visor mantiene siempre la proporción 3:2 y encuadra el mapa completo al
abrirlo. La rueda, los botones y el doble clic permiten ampliar, y se puede
arrastrar para desplazarlo. El zoom máximo se calcula con la resolución nativa,
por lo que la imagen nunca se amplía por encima de 3840 × 2560. Los marcadores
viven en una capa independiente: cambian de posición con el mapa, pero no de
tamaño ni de resolución. Las coordenadas del servidor se proyectan con los
límites de `WorldMapArea.dbc` de cada continente. `WorldMapTransforms.dbc`
traslada además las zonas de elfos de sangre y draenei, cuyo mapa físico es
530, a Reinos del Este y Kalimdor respectivamente. Las posiciones que no tienen
una proyección continental válida se muestran en la lista de instancias y
nunca se fuerzan contra el borde del dibujo.

### El catálogo de addons del panel (`web-panel/addons/`)

`cliente/Interface/AddOns` es la única copia canónica que sirve el panel web;
ninguna descarga de un jugador depende de GitHub. `catalog.json` relaciona cada
paquete con sus carpetas, descripción en español, categoría, clases recomendadas,
tamaño y fuente. La instantánea externa procede del commit
`235b9e4cd5b429b94f4cb33ba9308d3c78f6bcad` de
<https://github.com/NoM0Re/WoW-3.3.5a-Addons>.

Los 118 paquetes de NoM0Re se extrajeron en la ruta del cliente. Los ZIP de descarga se
generan al vuelo desde esas mismas carpetas, evitando mantener una segunda copia.
Los cinco originales RAR también se importan durante la sincronización.

**Sincronización parcial (01/10/2026).** El commit fijado es `235b9e4`, pero sólo se trajeron de él, a mano, DrDamage
(actualizado), RatingBuster (sustituye al paquete mal escrito «RaitingBuster»), SavedInstances y RaidSlackCheck. Ese commit
eliminó 25 paquetes del catálogo (ElvUI, Skada, Grid2, Details, TidyPlates, TellMeWhen, SharedMedia…) que aquí se conservan
adrede: un `npm run sync:addons` completo los borraría, así que no se usa mientras esa decisión siga vigente.

`MultiBot` y `ServerHelp` están marcados como obligatorios y el sincronizador
nunca los reemplaza: siempre se usan las versiones propias del proyecto.

`GuildLevels` (interfaz de mod-guild-levels) también es obligatorio, igual que
`BugSack` (que incluye `!BugGrabber`, necesario para que funcione) y `Addon
Control Panel`. A diferencia de MultiBot/ServerHelp, BugSack y ACP sí vienen
del mirror de NoM0Re como cualquier otro addon (con su propio `archive`/
`sha256` en `.addon-sync/catalog.json`): el campo que distingue "léelo tal
cual del cliente, una sola carpeta" en `extract-client-addons.mjs` es
pertenecer a `protectedAddons` (sólo multibot/serverhelp), no `required` —
si se añade un addon obligatorio nuevo que venga del mirror, debe seguir la
rama normal de extracción de ZIP, no la de "addon propio".

Nuestra copia de `ACP/ACP.lua` protege por defecto (`ProtectedAddons`) a
`ACP`, `BugSack` y `!BugGrabber`: ACP los vuelve a activar solos si alguien
los desactiva y no los incluye en su "Desactivar todos". Es una modificación
local sobre el ACP de CurseForge, no algo que aporte el upstream; sólo aplica
la primera vez que un jugador genera su `ACP_Data` (no toca el de quien ya
tuviera uno).

##### Recursos que salen de tu cliente (iconos y parches de idioma)

La instalación rápida (`./install.sh --guiado`) deja listo el servidor y el panel; **dos recursos salen del
cliente de WoW del jugador y se generan desde el propio panel**, sin ejecutar nada en tu PC: los iconos de la
armería y los parches `patch-esES-4.MPQ` / `patch-enUS-4.MPQ` (objetos propios y razas/clases de ARAC). Hasta
hacerlo, el servidor funciona, el panel arranca con iconos genéricos y los parches se listan como pendientes. El
instalador lo dice al terminar («FALTA EL PASO DEL CLIENTE; la instalación NO está completa hasta hacerlo») y el
`doctor` lo avisa (`recursos-cliente`).

Para completarlo, en tu PC con Chrome o Edge:

1. Abre el panel (`https://<IP del servidor>`) y entra con la cuenta de administrador (la primera vez, instala el
   certificado que ofrece la página).
2. **Addons → Elegir carpeta de WoW** (la que tiene `Wow.exe`). El navegador comprueba que parece un cliente
   3.3.5a, lee de sus MPQ sólo lo necesario (`ItemDisplayInfo.dbc`, los iconos que referencia y, por idioma,
   `Item.dbc` y `Spell.dbc`; unos 100 MB aunque el cliente pese varios GB) y lo envía al servidor, que genera y
   verifica. Verás el progreso; se puede cancelar.
3. **Instalar parches** y, en el paso 3, **Instalar** los addons obligatorios.

Es idempotente y reanudable: si el cliente es el mismo y la receta no ha cambiado, la segunda vez responde «ya
estaba al día» sin enviar nada; si se corta el envío, al repetirlo se reutilizan los ficheros ya recibidos;
**Regenerar todo** lo rehace aunque esté al día. Un fallo no destruye lo anterior: el recurso previo sigue
sirviéndose. Sólo los administradores (GM 3) pueden prepararlos; un jugador ve los parches pendientes.

Con el repositorio de trabajo (que trae iconos y MPQ ya preparados) esos datos se incorporan al arrancar el panel
como «preparados» y valen hasta que pidas regenerarlos. Todo lo demás de la fase 9 (`scripts/preparar-recursos.sh`)
es automático: dependencias (Node, `bsdtar`, Pillow), los 309 addons reconstruidos y comprobados, los mapas con
hash y los tres DBC de ARAC verificados. Si algo de eso falla, la instalación se detiene (no se da por completa).
Los mapas de continente (los cuatro, Rasganorte incluido) salen de Warcraft Wiki con el hash fijado; la CDN de la
wiki sirve a veces una variante recomprimida, así que se prueban varias URL de caché y sólo se acepta el fichero con
ese hash, en tres pasadas con pausas. Si ninguna lo da, el mapa queda pendiente y el panel muestra un fondo neutro en
vez de usar otra versión; `./install.sh --panel` repite la descarga.

Comprobación:

```bash
./install.sh --doctor        # addons (309/309), client-data (v20 completo), recursos-cliente (pendiente o listo), mirrors, servicios…
```

##### Instalado, actualización y desinstalar

El panel decide "instalado / hay actualización / no instalado" comparando el
contenido real de `Interface/AddOns` con un hash de contenido por addon
(`contentVersion`, calculado en `src/addons.js` al arrancar el panel — mismo
esquema: carpeta + ruta relativa + contenido, recorrido en el navegador con la
File System Access API). No hay un manifiesto propio que se pueda desincronizar:
si el hash coincide, el addon **no se vuelve a copiar** al pulsar instalar (así
no se pisan SavedVariables ni configuración dentro de esa misma carpeta); si no
coincide, se reinstala entero. Los parches (`patches.json`) ya traían su propio
`sha256`, así que se comparan igual pero sobre un solo archivo. Los addons y
parches no obligatorios se pueden desinstalar desde su propia tarjeta/fila
(borra la carpeta o el archivo); los obligatorios no muestran esa opción.

Para saber si hay novedades en el repositorio de origen sin clonarlo (sólo
`git ls-remote` + la API pública de GitHub):

```bash
bash tools/revisar-actualizaciones-addons.sh              # tabla, incluye esta fila
bash tools/revisar-actualizaciones-addons.sh --log-catalog # qué archivos de src/Addons/ cambiaron
```

**Reconstrucción reproducible (PUB04).** La edición pública no lleva los 307 addons de terceros: se
reconstruyen con `web-panel/tools/build-addons.mjs` a partir de `web-panel/addons/fuentes.json`
(cada paquete de NoM0Re con su commit y SHA-256, los tres addons de repositorio según `addons.lock`
y los parches de `patches-cliente/`) y se comprueban contra `web-panel/addons/arbol.tsv` (hash de
contenido de cada una de las 309 carpetas, insensible a CRLF y a mayúsculas de ruta). `MultiBot` y
`ServerHelp` van en el árbol. El paso lo ejecuta la fase 9 (`scripts/preparar-recursos.sh`); a mano:

```bash
cd web-panel && npm ci --omit=dev
node tools/build-addons.mjs verificar                 # ¿coincide lo que hay con arbol.tsv?
node tools/build-addons.mjs build                     # reconstruye (descarga con SHA-256; necesita bsdtar para los RAR)
node tools/build-addons.mjs arbol > addons/arbol.tsv  # tras un cambio deliberado de fuentes o parches
```

`build` trabaja en una carpeta temporal dentro del destino, comprueba cada carpeta contra `arbol.tsv`
y sólo entonces las sustituye una a una: un fallo de descarga, de hash o de parche no deja el destino
a medias. Un repositorio de trabajo que ya trae `cliente/Interface/AddOns` entero no descarga nada.

Para actualizar la instantánea se necesita una copia local del repositorio de
origen y una implementación de `bsdtar` capaz de leer RAR y crear ZIP (es el
flujo antiguo, que sustituye el árbol completo; después hay que registrar los
nuevos commits y hashes en `fuentes.json` y regenerar `arbol.tsv`):

```bash
cd web-panel
npm run sync:addons -- /ruta/WoW-3.3.5a-Addons
npm test
```

El script extrae la colección en `cliente/Interface/AddOns`, conserva los dos
addons propios y recalcula el catálogo completo. Las traducciones revisables
viven en `descriptions-es.json`; si aparece un addon nuevo, la sincronización se
detiene hasta que tenga texto en español. Antes de publicar una actualización
hay que revisar los cambios de procedencia, licencias y compatibilidad del
repositorio externo. GuildLevels, QuestRadar y el `required` de PlayerBotManager
no pasan por este script (vienen de sus propios repositorios): tras una
sincronización completa hay que reponerlos a mano en `catalog.json` como ya se
hizo la primera vez.

##### Localización de los `.toc` en español

`tools/localize-addon-tocs.mjs` añade `## Notes-esES:` a los `.toc` del
cliente que no tengan ninguna localización en español, reutilizando el mismo
texto de `descriptions-es.json` (o `catalog.json` para GuildLevels/QuestRadar/
PlayerBotManager, que no están en `descriptions-es.json`). No toca ningún
`.toc` que ya declare `Notes-esES`: revisar una traducción existente que se
vea mal es cosa de una persona. Es idempotente (se puede volver a ejecutar
tras sincronizar addons nuevos) y admite `--dry-run` para ver el recuento sin
escribir nada:

```bash
node tools/localize-addon-tocs.mjs --dry-run
node tools/localize-addon-tocs.mjs
```

