# Azeroth Single Player — AzerothCore WotLK 3.3.5a

**Español** · [English](README_EN.md)

> **Tu propio World of Warcraft: Wrath of the Lich King, en tu servidor, para
> jugarlo solo o con unos amigos, en español o en inglés y con el mundo lleno
> de vida.** Un instalador que monta, con un solo comando, un servidor completo
> de WotLK 3.3.5a donde cientos de bots hacen de «otros jugadores»: te llenan las
> colas, te acompañan en las misiones, forman tu hermandad, libran su propia
> guerra en las zonas disputadas y comercian en la casa de subastas.

## Qué es

**Azeroth Single Player** es un proyecto que convierte
[AzerothCore](https://www.azerothcore.org/) —el emulador libre de World of
Warcraft 3.3.5a— en un servidor de **uso personal**: para jugar uno solo, o
con un grupo reducido de amigos, sin depender de que exista un servidor
público ni de que haya alguien conectado a tu hora.

No es un servidor más con unos cuantos módulos activados. Es un **producto
completo y reproducible**, formado por:

- **un instalador** que deja el servidor funcionando y configurado desde cero;
- **el servidor**: AzerothCore, su fork con bots
  ([mod-playerbots](https://github.com/mod-playerbots/mod-playerbots)) y una
  treintena de módulos, de terceros y propios, con los parches que hacen falta
  para que convivan;
- **un panel web** para administrar el reino y repartir los addons;
- **lo que va en el PC del jugador**: addons y parches de cliente, con su
  instalador;
- **la documentación y las pruebas** que permiten fiarse de todo lo anterior.

El objetivo no es acumular opciones, sino que **la experiencia de jugar solo
se parezca lo más posible a la de jugar en un reino lleno de gente**.

## El problema que resuelve

World of Warcraft es, sobre todo, un juego **de gente**. Casi todo lo que lo
hace memorable necesita a otros jugadores: las colas de mazmorra, las bandas,
los campos de batalla y las arenas, la casa de subastas, las capitales
bulliciosas, la hermandad con la que se hace la banda cada semana, el grupo que
mata los mismos jabalíes que tú.

En un servidor propio, **todo eso está vacío**. Te apuntas a un campo de
batalla y la cola no salta nunca. Buscas grupo para una mazmorra y nadie
responde. Llegas a Ventormenta y no hay nadie. La subasta no tiene ofertas. Los
bots que ya existen para AzerothCore ayudan, pero por defecto van a ciegas: no
saben en qué cola estás, no se acercan a tu zona, no forman un grupo útil, y con
cientos de ellos dentro el servidor gasta memoria y CPU las 24 horas aunque no
juegue nadie.

Este proyecto existe para cerrar ese hueco.

## Qué se consigue

### Un mundo vivo a tu alrededor

- **Tu zona no está vacía.** Al entrar en una zona, el servidor comprueba
  cuántos bots de tu nivel hay y trae los que falten a puntos de caza lejos de
  ti, para que nunca los veas aparecer. Si te quedas, repone lo que se vaya.
- **Compañeros de misión.** Al aceptar «mata diez jabalíes», dos o tres bots de
  tu zona la aceptan también y van a por ella por su cuenta, como harían otros
  jugadores. Son los mismos durante un rato: compañeros, no desconocidos.
- **Capitales con gente, subasta con vendedores de las dos facciones**, y una
  guerra de mundo con escaramuzas y duelos entre facciones en 23 puntos
  calientes.
- **Cofres del tesoro** repartidos por 57 zonas, que cambian de sitio y avisan
  con una bengala al aparecer.

### Contenido de grupo cuando tú quieras

- **Las colas saltan.** Te pones en cola para un campo de batalla, una arena, una
  mazmorra o una banda y el servidor mete en *esa* cola los bots que falten: el
  tanque y el sanador si lo que falta son roles, los dos bandos si es un campo
  de batalla. Sin esperar.
- **Grupo sin cola.** `.grupo` forma al instante un grupo de bots de tu nivel con
  tanque y sanador, para las misiones de grupo o para una mazmorra a la que
  quieres entrar andando. Y el tanque bot puede llevar la mazmorra de punta a
  punta.
- **Tu hermandad.** La fundas tú, y mientras la lideres se rellena con hasta 15
  bots de tu facción y tu nivel que suben contigo y van primero en tus grupos.
  Hay además una sede de hermandad con servicios y un centro de profesiones.

### Progresión y variedad a tu medida

- **Vanilla → Burning Crusade → Wrath of the Lich King, por personaje.** El
  contenido de cada era se abre en orden, jugándolo, no de golpe.
- **Instancias escaladas** al número de jugadores, jefes de mundo solo para tu
  grupo y el Esfuerzo de Guerra de Ahn'Qiraj completable en solitario.
- **Reglas que eliges por personaje:** Hardcore, Iron Man, solo fabricado, XP
  lenta… y cualquier raza con cualquier clase.
- **Comodidades que ya son costumbre:** transfiguración, encantamientos
  aleatorios escalados a tu nivel, recompensas al subir de nivel, buffs de
  mundo, banco de componentes.

### En español y en inglés

El proyecto funciona con el cliente de WoW **en español (`esES`) o en inglés
(`enUS`)**: los parches de cliente y los recursos que se generan desde tu
instalación se preparan para los dos idiomas, y cada jugador ve el juego en el
de su cliente. El juego base ya viene traducido; el proyecto traduce además lo
que añaden los módulos (NPC de servicio, menús, frases de los bots).

**El proyecto está desarrollado principalmente en español**: la documentación,
los comentarios del código, los mensajes y comandos del instalador y los textos
propios están en ese idioma. El inglés se cubre con este README
([`README_EN.md`](README_EN.md)) y con el soporte del cliente `enUS`.

### Un servidor que se cuida solo

- **Modo en espera.** Si nadie juega durante un rato, el servidor del mundo se
  apaga y la siguiente conexión lo despierta: con bots dentro consume mucho; en
  espera, nada.
- **Reinicio diario con aviso, parada segura** (guarda a todos antes de cerrar),
  **comprobación de salud automática** y aviso de versiones nuevas dentro del
  juego.
- **Versiones fijadas y copias offline** de cada dependencia, para que una
  reinstalación dentro de un año dé lo mismo que hoy.

## Cómo está construido

Hay cuatro piezas, y las cuatro salen del mismo repositorio:

1. **El instalador** (`install.sh`). Convierte una máquina limpia en el
   servidor completo en nueve fases independientes y reanudables: prepara el
   sistema, instala la base de datos, descarga el código **de versiones
   fijadas**, compila, configura, crea los servicios y el panel. Con
   `bash install.sh --guiado` basta con responder a unas pocas preguntas. Nada se
   edita a mano en el servidor: se cambia `config.sh` (o tu `config.local.sh`) y
   se reaplica.
2. **El servidor.** Los módulos de terceros se activan o se apagan uno a uno.
   Los **módulos propios** (`modules/`) hacen lo que ninguno de los anteriores
   hacía: colas con bots, población del mundo, compañeros de misión, cofres,
   grupo instantáneo, hermandad de casa, ayuda en juego, modo en espera. Los
   **parches** (`patches/`) corrigen o adaptan módulos ajenos sin forkearlos.
   Se sigue una regla simple: antes de escribir código propio se intenta
   resolver con una opción de configuración, luego con datos en la base de
   datos y, sólo si no hay más remedio, con un parche.
3. **El panel web.** Entras con tu cuenta del juego. Muestra quién está
   conectado, un mapa del reino en tiempo real, la armería de personajes, la
   ayuda de comandos y el estado de salud; permite crear cuentas con
   invitación, moderar y comprobar actualizaciones, y reparte un catálogo de
   addons compatibles con el cliente.
4. **El cliente.** El juego se ejecuta en tu PC. El proyecto **no incluye ni
   distribuye nada de Blizzard**: los parches de idioma y los iconos de la
   armería se generan desde tu propio cliente, a través del panel, y los
   addons y parches propios se instalan con un script.

**Lo verificado se prueba de verdad.** El proyecto lleva un cliente sintético
—un cliente de WoW 3.3.5a sin interfaz— que entra al servidor, forma grupos, se
pone en cola y entra en mazmorras para comprobar que cada funcionalidad hace lo
que dice antes de darla por buena.

## Para quién es, y para quién no

**Es para ti si** quieres jugar WotLK (o recorrer la progresión clásica) a tu
ritmo, solo o con unos amigos, con un servidor que montas y controlas tú, y
quieres que se sienta habitado. Cada jugador tiene su cuenta, sus personajes y
su progresión, y los bots rellenan lo que falte.

**No lo es si** buscas abrir un reino al público, ni un servidor comercial: está
pensado para una persona o un grupo de amigos, y no está pensado ni probado para
exponerlo a internet. Tampoco mantiene un fork propio del núcleo de AzerothCore
—usa el de mod-playerbots y se apoya en módulos y parches— ni **incluye World of
Warcraft**: necesitas tu propio cliente 3.3.5a.

## Qué necesitas

- Un servidor propio, físico o máquina virtual, con **16 GB de RAM y 60 GiB de
  disco** libres como mínimo (los requisitos exactos están en
  [Instalar](#instalar)). Se ha probado en una VM de Proxmox con 8 cores,
  16 GB y 120 GB; son datos de prueba, no requisitos.
- Un **cliente de WoW 3.3.5a**, en español o en inglés, en cada PC que vaya a
  jugar.
- Unos 35 minutos de instalación, casi todos de compilación.

Los datos de cada instalación —la IP, el nombre del reino (`Azeroth SP` en las
pruebas), las contraseñas— son propios y se guardan en `config.local.sh`, que no
se versiona.

**Para empezar:** [Instalar](#instalar) (más abajo) · detalle de cada pieza en
[`INSTALL_ES.md`](INSTALL_ES.md) y [`REFERENCES.md`](REFERENCES.md).

---

## La documentación

Hay cinco documentos principales, los mismos en todas las copias del proyecto:

| Fichero | Para qué |
|---|---|
| **`README.md`** | Selector de idioma con un resumen breve; **`README_ES.md`** (este) y `README_EN.md` son el documento completo: qué es, cómo está, qué lleva dentro |
| `INSTALL_ES.md` (y `INSTALL_EN.md`, su traducción al inglés) | Instalar, **configurar** (todas las opciones de `config.sh`), qué hace cada fase por dentro, cómo operar el servidor, el PC del jugador (cliente) y el panel web |
| `CONTRIBUTING.md` (selector), `CONTRIBUTING_ES.md` y `CONTRIBUTING_EN.md` | Cómo contribuir: qué se acepta, las reglas del proyecto, cómo se revisa cada *pull request* y por qué el cliente sintético no se modifica |
| `REFERENCES.md` | Cómo funciona hoy cada pieza propia, los datos estáticos de consulta (comandos, NPC, emparejamientos PvP, rangos de identificadores), las reglas para escribir un módulo o un parche, crear un objeto que no existe en 3.3.5a, el verificador sintético y la procedencia de los recursos |
| `CHANGELOG.md` | Todo lo hecho, con fecha y al detalle, lo último arriba. Al final, el anexo con los diseños y análisis completos |

---

## Cómo está ahora mismo

**Al día 07/09/2026.** Lo que había corriendo en el servidor de pruebas:

| | |
|---|---|
| Core | fork Playerbot `413bea61` (04/09) · playerbots `b949b50b` (04/09) · 21 repositorios fijados en `versions.lock`, actualizados el 05/09 |
| Datos del cliente | v20.0 (mmaps v20, 0 errores) |
| Bots | 150 cuentas, 1500 personajes, 400-500 conectados, LevelBrackets activo |
| Consumo | 5,8 GB y ~274 % de CPU con 221 bots de nivel 80 dentro (en el equipo de pruebas) |
| Hora | La VM va en `Europe/Madrid` desde el 04/09 (antes, UTC) |
| Reinicio | Diario a las 00:00, con aviso previo |
| Panel web | `http://<IP-del-servidor>` · login SRP6 · jugadores online · catálogo local de addons · mapa GM en tiempo real |

`mod-adaptive-ai` está **archivado y desactivado** desde el 06/09/2026. No se
compila ni carga, y sus tablas se vaciaron después de exportar el entrenamiento.
No hay trabajo previsto sobre el módulo. Su estado y las condiciones para una
eventual reactivación están en `CHANGELOG.md`.

El historial de implementaciones, pruebas y correcciones se registra en
`CHANGELOG.md`.

---

## Qué instala

**AzerothCore** (fork de mod-playerbots, rama `Playerbot`), **MySQL 8.4 LTS** y
estos módulos, cada uno activable en `config.sh`:

| Módulo | Qué aporta |
|---|---|
| `mod-individual-progression` | Progresión Vanilla → TBC → WotLK por personaje |
| `mod-playerbots` | Bots con IA que pueblan el mundo, hacen misiones, instancias y campos de batalla |
| `mod-queue-bots` (**propio**) | Rellena con bots la cola en la que te pones: 1c1, campo de batalla, arena, mazmorra, banda |
| `mod-world-bots` (**propio**) | Que tu zona no esté vacía: trae bots de tu nivel a puntos de caza lejos de ti, puebla las capitales, y repone mientras sigues allí. Y la guerra de mundo: escaramuzas entre facciones y duelos en 23 puntos calientes |
| `mod-treasure` (**propio**, SP03) | Cofres en 57 zonas activas. Al entrar un humano se comprueban automáticamente suelo, visión y ruta antes de asignar destinos; cambian de punto tras una hora sin recogerse, tienen reposición individual al agotarse y lanzan una bengala al aparecer |
| `mod-quest-mates` (**propio**) | Compañeros de misión: al aceptar una misión, dos o tres bots de tu zona la cogen también |
| `mod-quest-loot-party` (SP04) | Cada miembro presente y elegible del grupo puede recoger su copia del botín blanco de misión; AoE Loot recoge cada copia sin consumir las de los demás. No cambia el botín en solitario ni la probabilidad de caída |
| `mod-autobalance` | Escala las instancias al número de jugadores |
| `mod-transmog` | Transfiguración, con NPC en las once capitales |
| `mod-ah-bot-plus` | Casa de subastas viva, con vendedores de las dos facciones |
| `mod-random-enchants` | Encantamientos aleatorios al lootear, escalados a tu nivel |
| `mod-congrats-on-level` | Recompensas al subir de nivel, en cualquier nivel |
| `mod-challenge-modes` | Hardcore, Iron Man, Sólo Fabricado, XP lenta… por personaje |
| `mod-profession-experience` | XP por profesiones: naranja 1 %, amarillo 0,5 %, verde 0,25 %, gris 0; tope al máximo del rango aprendido, bots incluidos y sin XP de hermandad. Detalle en `REFERENCES.md` |
| `mod-guildhouse` | Sede de hermandad en la Isla de los MJ, con servicios y portal de salida original. Piedra propia gratuita de 10 s/30 min; compra por 1.000 oro. Centro de profesiones (SP07): instructores, fragua, yunque y Ling, el banquero de materiales, como mejoras del mayordomo. Ver `REFERENCES.md` |
| `mod-instanced-worldbosses` | Jefes de mundo sólo para tu grupo |
| `mod-war-effort` | Esfuerzo de Guerra de Ahn'Qiraj, completable en solitario |
| `mod-dungeon-master` ⚠️ | Mazmorras procedurales y modo Roguelike (*early development*) |
| `mod-dungeon-clear` | El tanque bot lleva la mazmorra de punta a punta; se activa solo al entrar con el grupo del buscador |
| `mod-party-here` (**propio**) | Grupo donde estás, sin cola: `.grupo` forma un grupo de bots de tu nivel con tanque y sanador; misiones de grupo en automático |
| `mod-home-guild` (**propio**) | Tu hermandad: fúndala tú (el módulo no crea ni adopta ninguna), y mientras la lideres se rellena con hasta 15 bots de tu facción y tu nivel que se conectan contigo, suben de nivel contigo y van primero en las colas |
| `mod-update-notice` (**propio**) | Aviso a los GM al entrar si hay versiones nuevas río arriba; `.actualizaciones` |
| `mod-server-help` (**propio**) | La pestaña "Solicitud de ayuda" del cliente enseña los comandos y artículos que tu cuenta puede usar, filtrados por el servidor; `.ayuda`. Necesita el addon `ServerHelp` (`cliente/`) |
| `mod-standby` (**propio**) | Modo en espera (activado por defecto): apaga el worldserver cuando lleva 15 min sin jugadores humanos y lo despierta la siguiente conexión (activación de socket de systemd). La VM no gasta CPU ni RAM con los bots mientras nadie juega. `WORLDSERVER_STANDBY=false` para desactivarlo; `.standby` |
| `mod-adaptive-ai` (**propio, archivado**) | Desactivado desde el 06/09/2026; no se compila ni carga. Su diseño e historial están en `CHANGELOG.md` |
| `mod-world-buff-bots` | Buffs de mundo (Onyxia, Jefe de Guerra, Zandalar) entregados por "jugadores" cada 30-150 minutos |
| `mod-token-turnin` | Los tokens de tier que ganan los bots se cambian por su pieza; queue-bots lo hace solo tras cada jefe |
| `mod-racial-trait-swap`, `mod-reagent-bank`, `mod-aoe-loot`, `mod-instance-reset`, `mod-1v1-arena` | Servicios |
| `mod-arac` | Cualquier raza con cualquier clase (parche de cliente + SQL + DBC) |

`mod-pvp-titles` sigue soportado pero desactivado: duplica los títulos de
individual-progression con umbrales más bajos.

Además: parada segura al apagar (avisa a los jugadores, `saveall`, cierre
ordenado), reinicio diario, **modo en espera** (por defecto: apaga el
worldserver cuando no hay nadie y lo despierta la primera conexión;
`WORLDSERVER_STANDBY=false` para desactivarlo), aviso semanal de versiones
nuevas por correo dentro del juego, versiones fijadas (`versions.lock`) y copias
offline de cada repositorio (`mirrors/`), comprobación de salud automática
(`doctor`, ver `INSTALL_ES.md`) visible en el panel bajo **Mi cuenta**, y CI
para sintaxis, integridad de `mirrors/`, parches propios y el panel web.

---

## Instalar

Requisitos: Ubuntu Server 24.04 ya instalado, un usuario con `sudo`, internet,
16 GB de RAM y 60 GiB de disco libres (lo que comprueba el asistente; más cores
acortan la compilación). Hardware con el que se ha probado: `INSTALL_ES.md`.

**Obtener el proyecto**: clónalo en el servidor (o descarga el ZIP de una versión y comprueba su `SHA256SUMS`, ver `INSTALL_ES.md`):

```bash
git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer
cd azerothcore-installer
```

**Instalación guiada**, sin editar archivos: abre una terminal en la carpeta
del proyecto y ejecuta:

```bash
bash install.sh --guiado
```

Comprueba el equipo, propone la IP del servidor y pide el nombre del reino y
tu cuenta. Muestra un resumen, guarda tus datos en `config.local.sh` (sin tocar
`config.sh`) y ejecuta la instalación completa, incluido el panel si está
activado. Conserva los módulos, tasas, bots y ajustes avanzados actuales.
Mantén la terminal abierta.

Al terminar, el servidor y el panel quedan funcionando; **falta un paso con tu
cliente de WoW**: en el panel (Addons → elegir la carpeta de WoW) un administrador
genera, sin instalar nada, los iconos de la armería y los parches de idioma desde
su propio cliente. La instalación no está completa hasta hacerlo (el instalador y
`doctor` lo avisan). Detalle en **[INSTALL_ES.md — Recursos que salen de tu cliente](INSTALL_ES.md)**.

Si se interrumpe: `bash install.sh --reanudar`. Guía con los pasos desde
Ubuntu y las opciones de comprobación: **[INSTALL_ES.md — Instalar con el asistente](INSTALL_ES.md#instalar-con-el-asistente)**.

**Instalación avanzada**, con control manual de la configuración:

```bash
cd azerothcore-installer      # la carpeta clonada (o el ZIP descomprimido)
nano config.local.sh                                 # tus REALM_IP y contraseñas (ver config.sh); módulos en config.sh
chmod +x scripts/instalar-todo.sh && ./scripts/instalar-todo.sh   # ~35 min, pide sudo una vez
```

Fase a fase, modos, qué hacer después y todo lo del PC del jugador:
**`INSTALL_ES.md`**.

Después basta con `./install.sh --only 5` para reaplicar cualquier cambio de
`config.sh` o `config.local.sh`; sólo hay que recompilar si se toca código o
entra un módulo nuevo.

---

## Estructura

```
install.sh                  ← ÚNICO script en la raíz: --guiado, --reanudar, fases, --post, --panel...
config.sh                   ← la configuración base (opciones y valores neutros)
config.local.sh             ← tus valores (IP, contraseñas...); lo crea el asistente; no se versiona
versions.lock               ← commit exacto de cada repositorio
scripts/                    ← implementación del instalador (uso avanzado; install.sh la invoca sola)
  instalar-todo.sh            ← instalación completa desatendida, panel web incluido
  apply-safe-stop.sh          ← parada segura para instalaciones antiguas
  phases/01..09_*.sh          ← las fases (8-9 = --post; 9 = --panel)
lib/                        ← utils, versiones, espejos, avisos, parches, srp6
modules/                    ← módulos propios (queue-bots, world-bots, quest-mates,
                              party-here, home-guild, update-notice, server-help,
                              adaptive-ai) y shared/
patches/                    ← parches y SQL sobre módulos de terceros
cliente/                    ← lo que va en el PC del jugador: addons ServerHelp y MultiBot,
                              manifiesto e instalador (los patch-<idioma>-4.MPQ y el resto de
                              addons se generan o reconstruyen en la instalación)
tools/                      ← asistente guiado, backup, primer arranque, verificación,
                              informes de entrenamiento, revisar actualizaciones
web-panel/                  ← panel web, catálogo local de addons, pruebas e instalador Nginx/systemd
mirrors/                    ← manifiesto y hashes de los repositorios fijados; los snapshots
                              se reconstruyen con `./install.sh --hidratar` (ver INSTALL_ES.md)
```

Cada fase es un script independiente (`install.sh --only N`). Nada se edita a
mano en el servidor: se cambia en `config.sh` o `config.local.sh` y se reaplica.

---

## Avisos

- **mod-playerbots exige su fork del core.** Para añadirlo o quitarlo hay que
  reinstalar desde la fase 3.
- **mod-dungeon-master es experimental.** Si ves cosas raras en instancias,
  `INSTALL_MOD_DUNGEON_MASTER=false` y recompila; la fase 3 lo aparta sin borrarlo.
- La cuenta `admin`/`admin` es trivial a propósito (red local). Cámbiala con
  `.account password`.
- Una instalación en marcha **no** es un clon de este repositorio: los cambios
  se suben con `pscp`/`scp` (`INSTALL_ES.md`, parte 4 §8).

---

## Licencia

El código propio del proyecto (módulos propios, instalador, panel web y
herramientas) se distribuye bajo la **GNU Affero General Public License v3.0 o
posterior** (`LICENSE`). Los parches que modifican un proyecto ajeno conservan
la licencia de ese proyecto. El core y los módulos de terceros mantienen la suya
(GPL-2.0 o posterior, AGPL-3.0, MIT según el caso), igual que cada addon de
cliente. `NOTICE` resume el copyright, `LICENSES/` trae los textos y
`THIRD-PARTY-NOTICES.txt` relaciona cada componente de terceros con su licencia y su
origen. World of Warcraft y sus recursos pertenecen a Blizzard Entertainment y
no están cubiertos por esta licencia.

---

## Recursos

- [AzerothCore](https://www.azerothcore.org/wiki/installation) · [Discord](https://discord.gg/gkt4y2x) · [Catálogo de módulos](https://www.azerothcore.org/catalogue.html)
- [mod-playerbots](https://github.com/mod-playerbots/mod-playerbots/wiki) · [mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression/wiki)
- Datos del cliente: [wowgaming/client-data](https://github.com/wowgaming/client-data/releases) (v20.0 para este core)
