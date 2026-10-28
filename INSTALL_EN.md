# Installation, configuration and operation

[Español](INSTALL_ES.md) · **English**

> English translation of [`INSTALL_ES.md`](INSTALL_ES.md), with the same structure. The
> project is developed mainly in Spanish, so commands, option names, panel
> labels and in-game texts appear exactly as they are in the product (in
> Spanish), followed by a translation in parentheses when it helps. If the two
> versions ever disagree, the Spanish `INSTALL_ES.md` prevails.

Everything you need to know to set this server up, tune it and keep it running.
In this order: **what is automated** first, because it is what you will use;
then **each option** of `config.sh` and what it really does; then **what each
phase does inside** and why it is built that way; and finally **how to operate**
the installed server.

What the project is: `README_EN.md` · How each of our own pieces works:
`REFERENCES.md` · What changed and when: `CHANGELOG.md`

> **Install with an AI agent, or by hand.** It is recommended to do the
> installation with the help of an AI agent with access to a terminal (for
> example Claude Code or Codex): it can read this document, run the steps of
> [part 1](#part-1--install), interpret errors and resume the installation if it
> is interrupted. It is not necessary: everything can be done by hand, with the
> wizard (`bash install.sh --guiado`) or phase by phase, following the steps as
> written. If you use an agent, review what it proposes to run and type the
> passwords yourself in the terminal (the wizard asks for them without showing
> them): do not paste them into the conversation.

> What is verified here is verified against the code of the versions pinned in
> `versions.lock`. **Only `config.sh` and `config.local.sh` are edited**: nothing
> is touched by hand on the server, because the next reinstall would wipe it out.

---

### Index

**[Part 1 — Install](#part-1--install)**
[Requirements](#requirements) · [Wizard](#install-with-the-wizard) · [In one go](#in-one-go) · [Step by step](#step-by-step-installsh) · [`install.sh` modes](#installsh-modes) · [After installing](#after-installing) · [On the player's PC](#on-the-players-pc)

**[Part 2 — Configure](#part-2--configure)**
[How it works](#1-how-it-works-from-configsh-to-the-conf) · [Server](#2-server-realm-rates-factions-performance) · [Bots](#3-bots-mod-playerbots-mod-queue-bots-and-mod-world-bots) · [Instances](#4-instances) · [Progression](#5-progression) · [Economy and services](#6-economy-and-services) · [ARAC](#7-races-and-classes-arac) · [Administration and Spanish](#8-administrator-account-service-npcs-and-spanish) · [Versions and notices](#9-versions-offline-copies-and-notices)

**[Part 3 — What each phase does, and why](#part-3--what-each-phase-does-and-why)**
[The VM](#the-vm-and-the-system-phase-1) · [MySQL](#mysql-phase-2) · [The code](#the-code-and-the-modules-phase-3) · [Compile](#compile-phase-4) · [Configure](#configure-phase-5) · [Services](#the-systemd-services-phase-6) · [Automation](#automation-phase-7) · [Post-install](#post-installation-phase-8) · [Web panel](#web-panel-phase-9) · [Known risks](#known-risks)

**[Part 4 — Operate](#part-4--operate)**
[Day to day](#1-day-to-day) · [Backups](#2-backup-and-restore) · [Update](#3-updating-the-core-and-the-modules) · [Clean install](#4-clean-install) · [First start](#5-first-start) · [Diagnostics](#6-diagnostics-where-to-look-when-something-fails) · [Tests](#7-test-suite) · [From Windows](#8-operating-from-windows)

**[Part 5 — The player's PC and the web panel](#part-5--the-players-pc-and-the-web-panel)**
[The client](#the-client-cliente) · [The web panel](#the-web-panel-web-panel) · [Addon catalog](#the-panels-addon-catalog-web-paneladdons)

---

## Part 1 — Install

### Requirements

A server (physical or VM) with **Ubuntu Server 24.04 LTS**, SSH access with `sudo`
and internet. What the wizard requires before starting:

| | |
|---|---|
| RAM | 16 GB (it stops below 14 GiB) |
| Disk | 60 GiB free at minimum |
| CPU | Not required; 8 cores is comfortable, with fewer the build takes longer |

**Where it has been tested.** All of the project's tests were done on this
machine and they are not requirements: a GMKtec M5 Ultra (Ryzen 7 7730U, 8C/16T,
32 GB DDR4, NVMe) with a Proxmox VM of 8 cores of type `host`, 16 GB of RAM (no
ballooning) and 120 GB of disk. There, the full installation took ~35 minutes, of
which ~22 are compiling with 7 cores. Your times and consumption will depend on
your hardware. Why those values in the test VM: [part 3](#the-vm-and-the-system-phase-1).

For a new installation without editing files, run **`bash install.sh --guiado`**
(guided). The [wizard guide](#install-with-the-wizard) explains the steps and the
automatic resume (`--reanudar`). The wizard keeps the current advanced options.

In manual mode you edit **`config.sh`** (the modules and all the options, with
neutral values) and create **`config.local.sh`** with the installation's own
values (`REALM_IP`, passwords...). `config.sh` loads it by itself;
`config.local.sh` is not versioned and survives updates of `config.sh`.

### Install with the wizard

You need a server with **Ubuntu Server 24.04 already installed**, an internet
connection and a user with administrator permissions (`sudo`). The wizard
requires the requirements above (16 GB of RAM and at least 60 GiB free) before it
begins. The game runs on the player's PC.

#### Steps

1. Clone the project on the server with `git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer`,
   or download and unzip a version's ZIP. Keep all its
   folders, including `modules/`, `patches/`, `cliente/` and `web-panel/`. Each
   version publishes the tree as a ZIP and a `.tar.gz` next to a `SHA256SUMS`;
   check the download with `sha256sum -c SHA256SUMS --ignore-missing` before
   unzipping it (see "Packages of each version" in
   [part 2 §9](#9-versions-offline-copies-and-notices)).
2. Open a terminal inside the project folder. If you are using SSH, enter that
   folder with `cd`.
3. Run, with your normal user, **without prefixing `sudo`**:

   ```bash
   bash install.sh --guiado
   ```

4. The wizard checks Ubuntu, memory, space and system services. Accept or correct
   the proposed IP, type the realm name and choose your administrator account and
   its password. The password is not shown as you type.
5. Review the summary and answer `s` (for *sí*, yes). Your data is saved in
   `config.local.sh` (`config.sh` is not modified) and the installation starts.
   When asked, type the password of your Ubuntu user; it can be different from
   the game's.
6. Keep the terminal open until it finishes. The build and the downloads take
   tens of minutes, depending on the machine and the connection.

If Python is missing: run `sudo apt install python3` and open the wizard again.
The proposed IP corresponds to the server's network route: check that it is the
address your PC can reach, especially if you use a VPN or several network cards.

#### What is kept

`config.sh` remains the base configuration and the wizard does not modify it: it
writes its changes to `config.local.sh`, which `config.sh` loads after its own
values. It changes the IP, the realm name and the administrator account data, and
turns on its creation.
If the database password is still the example `acore`, it generates a new one. It
respects a custom database password and all the other settings: modules, bots,
rates, progression, schedules, directories and web panel.

The project's current automation and services policy is also kept, including the
scheduled machine restarts. Use a VM or dedicated server as described in
[part 3](#the-vm-and-the-system-phase-1).

If a `config.local.sh` already existed, its previous version is saved in
`.instalacion/copias/` before writing. The copies, the installation state and
`config.local.sh` stay out of Git and contain credentials: keep them on the
server. Cancelling at the summary changes no files and starts no services.

The advanced modes are still available:

```bash
bash install.sh --only 5   # reapply server settings
bash install.sh --only 4   # recompile
bash install.sh --post     # post-install and panel
```

An already existing installation is not modified automatically: the wizard says
how to continue with the advanced modes. To customize a new installation before
running it, you can keep editing `config.sh` directly.

#### If it is interrupted

From the same folder and with the same user:

```bash
bash install.sh --reanudar
```

It retries the pending step and keeps the completed ones. A failure during the
first start leaves it pending; a failure in the panel retries the post-install
block. The final check must pass before the process is marked as finished. If it
already finished, resuming only reports that.

The logs are in `~/instalacion-completa.log` and, for the first start,
`~/primer-arranque.log`. To follow progress from another terminal:

```bash
tail -f ~/instalacion-completa.log
```

If you change `config.sh`, `versions.lock` or the destination between attempts,
automatic resume stops to avoid skipping steps that need to be reapplied. Keep
the previous files or choose the starting point with
`bash scripts/instalar-todo.sh --desde N` (1–7), following [the manual mode](#in-one-go).
That manual mode also lets you resume installations that predate the wizard.

#### Check or configure without installing

```bash
bash install.sh --guiado --comprobar   # only check the machine
bash install.sh --guiado --configurar  # save data and a copy, without installing
```

After `--configurar`, start the installation with `bash scripts/instalar-todo.sh`.

#### Connect the game

When the installation finishes, set up your WoW 3.3.5a client and the project's
patches by following "The client" (INSTALL_EN.md, part 5). The wizard does not
install the client on the PC or create the virtual machine.

The summary shows the realm address. If the panel is enabled, open
`http://SERVER_IP` (add `:PORT` if you changed port 80). Log in to the game and
to the panel with the account chosen during the wizard.

### In one go

Complete, unattended installation — phases 1-7, first start, post-install, web
panel, services and verification — asking for the `sudo` password only once:

```bash
git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer && cd azerothcore-installer   # or unzip a version's ZIP
nano config.sh
chmod +x scripts/instalar-todo.sh && ./scripts/instalar-todo.sh
```

When it finishes, the server is running, with the `admin`/`admin` account (GM 3),
the service NPCs in place, the realmlist pointing at `REALM_IP` and the panel
available at `http://REALM_IP`.

Keep the terminal open. If it is interrupted, `bash install.sh --reanudar`
(or `bash scripts/instalar-todo.sh --reanudar`) continues from the pending step,
as long as the configuration, the pinned versions or the destination have not
changed. `--desde N` (1–7) keeps manual control to choose which phases to
repeat. The state is saved in `.instalacion/estado`.

### Step by step (`install.sh`)

If you prefer to see each phase, or to resume a half-done installation:

```bash
chmod +x install.sh && ./install.sh      # phases 1-7, with summary and confirmation
```

| Phase | What it does | Time |
|---|---|---|
| 1 | System dependencies, time zone | 2 min |
| 2 | MySQL 8.4, user and databases | 2 min |
| 3 | Clones the core and the modules according to `versions.lock`, copies our own, applies the patches | 4 min |
| 4 | Compiles and installs | ~22 min |
| 5 | Writes all the `.conf` files from `config.sh` and applies our own SQL | 1 min |
| 6 | systemd units, safe shutdown, wait for MySQL | 1 min |
| 7 | Daily restart, weekly version check, backups, logrotate | 1 min |
| 8 | Post-install: realmlist, admin account, service NPCs, SQL that needs the populated DB | 1 min |
| 9 | Web panel: restricted MySQL user, own database, SOAP account, Node.js, systemd and publication through Nginx | 1 min |

Phases 8 and 9 are not in the 1-7 batch because they need the databases already
created by the first start. `--post` runs both in that order.

### `install.sh` modes

```bash
./install.sh --guiado      # first time, without editing anything: see "Install with the wizard"
./install.sh --reanudar    # resume an interrupted complete installation
./install.sh --from 3      # resume from a phase
./install.sh --only 5      # just one phase: the usual one after touching config.sh
./install.sh --fix         # retries what failed
./install.sh --post        # phases 8 and 9
./install.sh --panel       # installs or updates only the panel (phase 9)
./install.sh --freeze      # pins in versions.lock the commits that are installed
./install.sh --mirror      # offline copies of the repositories in mirrors/
./install.sh --verify-mirrors  # only checks that versions.lock and mirrors/ match
./install.sh --doctor      # a pass of health checks (see below)
./install.sh --help
```

**`--only 5` is the mode used the most**: change an option in `config.sh`,
reapply it and restart. You only need to recompile (`--only 4`) if code was
touched or a module was added.

**`doctor` (`lib/doctor.sh`)** is a read-only pass of checks: `mirrors/` against
`versions.lock`, installed versions against pinned ones, the keys with an
incident history (`MapUpdate.Threads`, `AllowTwoSide.Interaction.*`), keys added
without being declared in their `.conf.dist`, the folder and `.conf` of each
active own module, systemd services, disk space and "Tick lento" (slow tick)
warnings in `Server.log`. It runs by itself at the end of any `install.sh`
(install, update or build) and after every start/restart of the worldserver
(`ExecStartPost` of `ac-worldserver.service`, phase 6); `./install.sh --doctor`
launches it by hand. The result is saved in `acore_world.doctor_status` (the most
recent) and `doctor_history` (the last 50 passes), which the panel shows under
**Mi cuenta → Estado del servidor** (My account → Server status) to any logged-in
account. It returns non-zero if any check is a real failure (a warning does not
count).

### After installing

If you used `--guiado` or `scripts/instalar-todo.sh`, this is already done. By
hand it is three steps:

**1. First start**, which creates and populates the databases:

```bash
bash tools/primer-arranque.sh
```

It answers `yes` to every question for you, waits for the world to listen on port
**8085** and shuts down cleanly. By hand: `cd ~/azerothcore/env/dist/bin &&
./worldserver`, `yes` to everything and `server shutdown 1` when it listens.
**Do not wait for "World initialized"**: this core no longer prints it. If it
gets stuck at "Waiting for 150 accounts…", close it and start it again — it is a
known first-start hang and the second time it works ([part 4 §5](#5-first-start)).

**2. Post-install**: realmlist, `admin`/`admin` account (GM 3, no characters),
service NPCs, pending SQL and the web panel reachable by IP:

```bash
./install.sh --post
```

To update only the panel afterwards, including its maps and static resources, use
`./install.sh --panel`; it keeps the generated secrets and restarts
`azerothcore-panel.service`.

**3. Start as a service.** From here on it starts with the machine:

```bash
sudo systemctl start ac-authserver ac-worldserver
bash tools/verificar-instalacion.sh
```

And, from the Windows PC, the "by playing" test with the synthetic client (it
creates and deletes its own characters on the `VERIFICADOR` account, which has to
be created after a clean install, and it reads its profile from
`tools/cliente-sintetico/entorno.local.json`, which does not go to Git: see
"The synthetic verifier" (REFERENCES.md)):

```bash
python tools/cliente-sintetico/verificar.py ejecutar diagnostico   # read-only
python tools/cliente-sintetico/verificar.py ejecutar todo
```

### On the player's PC

Everything that goes on the client is in the repository's `cliente/` folder
("The client" (INSTALL_EN.md, part 5)):

| | |
|---|---|
| `Data/esES/patch-esES-4.MPQ`, `Data/enUS/patch-enUS-4.MPQ` | The server's own items + any race with any class (ARAC) |
| `Interface/AddOns/ServerHelp` | The help tab with the server's commands |
| `Interface/AddOns/MultiBot` | Bot controller |

On Windows it copies everything:

```powershell
cliente\instalar-cliente.ps1 -Cliente "<client>" -Realm 192.168.1.100
```

By hand: copy the two folders over the WoW one and put `set realmlist <IP>` in
`Data/<language>/realmlist.wtf`. Optional: individual-progression's `patch-V.mpq`
(Vanilla/TBC mana costs). Start with `Wow.exe`, not with the Launcher, and never
use `localhost`: always the numeric IP.

The auction house takes hours to fill: `.ahbot update` several times with the GM.

---

## Part 2 — Configure

Every option of `config.sh`: which real key each one writes, what it really does
and why it has the value it has.

### 1. How it works: from `config.sh` to the `.conf`

**Only `config.sh` and `config.local.sh` are edited.** Phase 5 of the installer
(`./install.sh --only 5`) copies each `.conf.dist` of the core and the modules to
its `.conf` and writes on top of it the keys governed by those two files. A
`.conf` is never edited by hand: the next `--only 5` would overwrite it.

```
config.sh + config.local.sh  ──phase 5──▶  etc/worldserver.conf
                                           etc/modules/<module>.conf
```

**`config.sh` and `config.local.sh`.** `config.sh` is the common base: all the
options, with neutral values (`REALM_IP="127.0.0.1"`, example passwords).
`config.local.sh` is optional, lives next to it and contains only Bash
assignments with whatever is specific to your installation, for example:

```bash
REALM_IP="192.168.1.100"
ADMIN_ACCOUNT_PASS="your-own-password"
```

`config.sh` loads it right before computing what derives from `AC_DIR`, so any
option can be overridden there. It is in `.gitignore`, so it is neither uploaded
nor published; the wizard creates it with `600` permissions. Changing
`config.local.sh` or `config.sh` invalidates the resume of a half-done
installation, just like changing `versions.lock` (`--desde N` to choose what to
reapply). `AC_CONFIG_LOCAL=/path/other.sh` points to another file.

**The `.conf.dist` is the reference.** Each program declares *all* its keys, with
their default value and their comment, in its `.conf.dist`:

| What | Where |
|---|---|
| Core | `~/azerothcore/env/dist/etc/worldserver.conf.dist` |
| Each module | `~/azerothcore/modules/<module>/conf/*.conf.dist` |

If an option is not in `config.sh`, it is read from there. And if you want to
govern it from `config.sh`, add a variable and a `set_conf_value` line in
`05_configure_server.sh`.

#### The warning about undeclared keys

Since 2026-09-01, if phase 5 tries to write a key that **does not exist** in the
`.conf`, it warns in red and repeats it in a summary at the end:

```
[!!]  Key 'MapUpdateThreadCount' NOT declared in worldserver.conf: it is added
      at the end, but check that the program really reads it.
```

That warning exists because the installer had been writing, for months, keys that
no program read, without anyone noticing: `MapUpdateThreadCount` (the server ran
with **one** map thread with 250 bots), `AllowTwoSide.Interaction.Trade`,
`AutoBalance.Raids`, `Playerbots.RandomBotMaxGearQuality`,
`Transmogrification.Enabled`… Since the `.conf` files are copied from their
`.dist`, which declares all the real keys, "it wasn't there" almost always means
"it doesn't exist". **If you see that warning, check the name against the
`.conf.dist` or the code.** The only two legitimate exceptions (keys that
mod-playerbots requires in `worldserver.conf` and that the core's dist does not
declare) are on a whitelist in `lib/utils.sh` and do not warn.

#### Applying a change

```bash
nano config.sh
./install.sh --only 5                 # rewrites the .conf files and reapplies our own SQL
sudo systemctl restart ac-worldserver # warns players for 60 s, saveall and restarts
```

Many core options reload live with `.reload config` from the game, but the
modules usually do not support it: restarting is the safe way.

---

### 2. Server: realm, rates, factions, performance

Target file: `etc/worldserver.conf`.

#### Realm

| `config.sh` | Key | Notes |
|---|---|---|
| `REALM_NAME` | (`realmlist` table) | Written by phase 8, not the `.conf` |
| `REALM_IP` | (`realmlist` table) | `127.0.0.1` if you play on the same machine |
| `REALM_TYPE` | `GameType` | 0 Normal · 1 PvP · 6 RP · 8 RP-PvP |
| `MAX_PLAYERS` | `PlayerLimit` | |
| `TIMEZONE` | (system, `timedatectl`) | The machine's time zone, `Europe/Madrid` (2026-09-04). Applied by phase 1. Until then the VM ran in UTC: dates in `adaptive_*` earlier than 08:40 on 04/09 were converted by adding two hours; those in old logs and documents up to that time are in UTC |

#### Rates

| `config.sh` | Key | Value |
|---|---|---|
| `RATE_XP_KILL` | `Rate.XP.Kill` | 1.5 |
| `RATE_XP_QUEST` | `Rate.XP.Quest` | 1 |
| `RATE_XP_EXPLORE` | `Rate.XP.Explore` | 1 |
| `RATE_DROP_MONEY` | `Rate.Drop.Money` | 1 |
| `RATE_DROP_UNCOMMON` / `RARE` / `EPIC` | `Rate.Drop.Item.Uncommon` / `.Rare` / `.Epic` | 1 / 1 / 1 |
| `RATE_HONOR` | `Rate.Honor` | 2 |
| `RATE_REPUTATION` | `Rate.Reputation.Gain` | 3 |

#### Factions (cross-faction)

What the core **can** do between Alliance and Horde, with the real names from
`WorldConfig.cpp`:

| `config.sh` | Key | What it allows |
|---|---|---|
| `ALLOW_TWO_SIDE_GROUPS` | `AllowTwoSide.Interaction.Group` | Mixed groups and raids |
| `ALLOW_TWO_SIDE_GUILDS` | `AllowTwoSide.Interaction.Guild` | Mixed guilds |
| `ALLOW_TWO_SIDE_CHAT` | `AllowTwoSide.Interaction.Chat` **and** `.Channel` | Say/yell between factions, and the global channels |
| `ALLOW_TWO_SIDE_TRADE` | `AllowTwoSide.Interaction.Auction` | The other faction's auction house |

> ⚠️ **What does NOT exist in the core**, however much old guides say so:
> mail between factions, `/who` between factions, friends between factions and
> direct trade (`Trade`). The variables `ALLOW_TWO_SIDE_MAIL` and
> `ALLOW_TWO_SIDE_WHO` remain in `config.sh` for compatibility but **write
> nothing**. Until 2026-09-01 the installer wrote four non-existent keys with
> them, and also forgot `.Interaction.Chat`: the cross-faction chat it promised
> was off.

The SP profile uses `GameType = 0` (Normal): Alliance and Horde can still fight
each other by their own decision and in the PvP systems, but the open world does
not force combat. The other keys of the block (`.Arena`, `.Calendar`,
`AllowTwoSide.Accounts`) keep the dist's value.

**Mail** (since 2026-09-23): `MAIL_PUSH_INBOX_ON_DELIVERY=true` writes
`Mail.PushInboxOnDelivery = 1`. The client caches the mailbox for a minute and
does not request it again; with this, a mail that arrives while the player is
connected (the `mod-update-notice` notice, the congrats-on-level reward with full
bags) shows up when opening the mailbox without waiting or doing `/reload`.

#### Performance

| `config.sh` | Key / file | Value | Notes |
|---|---|---|---|
| `MAP_UPDATE_THREADS` | `MapUpdate.Threads` | 4 | Threads that update the maps. **Until 2026-09-01 it wrote `MapUpdateThreadCount`, which does not exist**: the server ran with 1 thread and one core at 93 %. With 4, the worldserver goes from 12 to 15 threads |
| `VISIBILITY_DISTANCE_CONTINENTS` | `Visibility.Distance.Continents` | 160 | Yards up to which a player sees on the continents. The core brings 100; mod-world-bots drops bots at 250, so with 160 you run into them sooner. More = more objects to update per player; do not exceed 180 |
| `MYSQL_BUFFER_POOL_GB` | `innodb_buffer_pool_size` in `mysqld.cnf` | 4 | Written by phase 1 |
| `BUILD_CORES` | (compilation) | `nproc - 1` | |

Other core performance options that `config.sh` does **not** govern and are left
at their dist value: `PlayerSaveInterval` and `Respawn.DynamicRateCreature`
(1 = disabled; with any other value respawns speed up when there are more than
that number of players —bots included— in the zone). Dynamic respawn was
deliberately ruled out on 2026-09-01: vanilla respawn is wanted.

#### Standby mode (shut down the worldserver when nobody is there)

| `config.sh` | Value | Notes |
|---|---|---|
| `WORLDSERVER_STANDBY` | `true` | Master switch (**on** by default). At `false` it goes back to the classic installation: screen + `Restart=always`, worldserver always on |
| `STANDBY_IDLE_MINUTES` | `15` | Minutes without any human session before shutting the worldserver down. With `BOTS_NO_PLAYER_LOGOUT_DELAY=600` the bots have already left by themselves at 10 |
| `STANDBY_WARN_SECONDS` | `60` | Countdown with notice before closing. 0 = immediate |
| `STANDBY_MIN_UPTIME_MINUTES` | `10` | The module does not shut the server down during these minutes after starting (covers the first-start hang and gives the player who woke it some margin) |
| `STANDBY_CHECK_SECONDS` | `30` | How often the human population is counted |

With `WORLDSERVER_STANDBY=true` (the default):

- `worldserver.conf` → `Network.UseSocketActivation = 1`, `Console.Enable = 0`.
- A **`ac-worldserver.socket`** unit owns port 8085 from the VM's boot and never
  stops. `ac-worldserver.service` runs the binary directly (no `screen`), with
  `Restart=on-failure`; on the first connection from a client systemd starts it
  and hands it the socket. With socket activation the core does **not** mark the
  realm as offline when it closes: the client still sees it as selectable.
- Our own module **`mod-standby`** (installed by itself, it follows
  `WORLDSERVER_STANDBY`) shuts the worldserver down with a clean exit (code 0 →
  systemd does not revive it) when it has gone `STANDBY_IDLE_MINUTES` without
  human players. `authserver`, MySQL, the panel and the VM stay up.
- **Cost:** the FIRST connection after sleeping takes as long as a cold start
  (~1-2 min). If the 3.3.5a client gives up sooner, it goes back to the realm
  list and when you reselect the realm it is already started. The following ones
  are instant.
- The shutdown notice and the `saveall` go through SOAP (`scripts/ws-console.sh`),
  not through `screen`. It requires the web panel to be installed (it enables
  SOAP).

In-game / console command: `.standby` (status), `.standby ahora` (sleep now),
`.standby mantener <min>` (suspend it for a long session), `.standby reanudar`
(resume).

---

### Profession experience

Profession experience is enabled with `INSTALL_MOD_PROFESSION_EXPERIENCE`. The
`PROFESSION_XP_*` options of `config.sh` set the base, difficulty, curve and the
lock at the profession cap. It is installed with phases 3/4/5 and a restart. To
adjust values, phase 5 and `.reload config` are enough; to remove the module from
the binary, set the switch to `false`, run 3/4/5 and restart. Configuration,
limitations and interaction with other modules: "Profession experience (SP01)"
(REFERENCES.md).

### Guild house (SP02)

`INSTALL_MOD_GUILDHOUSE=true` installs the module pinned in `versions.lock`.
Phases 3/4/5 clone, patch, compile and configure the guild house; phase 8
reapplies the SQL. The vendor appears next to the capitals' service NPCs when
`SPAWN_SERVICE_NPCS=true`. The leader buys the guild house for 1,000 gold; the
members enter through the vendor, `.gh teleport` or the **Guild house stone**
(free and replaceable at the vendor). All three ways use a 10-second cast and a
shared 30-minute cooldown, separate from the normal hearthstone. You leave
through the initial portal to Stormwind or Orgrimmar, or through other purchased
portals; the entry location is not saved.

The installer adds spell 600001 to the server's `Spell.dbc` and item 600001 to
`acore_world`; the icon and the client text are in
`cliente/Data/{esES,enUS}/patch-<language>-4.MPQ`. You have to close `Wow.exe`
completely, install the client patch and open it again to see the stone
correctly.

**Professions center (SP07).** With `INSTALL_MOD_REAGENT_BANK=true` the butler
also sells Ling, the materials banker, for `GuildHouseReagentBank` (copper;
1000000 = 100 gold, `-1` hides it; applied with `.reload config`, set in phase
5). Its bank belongs to each character and is the same one as in the capitals.
With the module disabled the butler does not offer it. Technical details and
limits: "Guild house (SP02)" (REFERENCES.md).

### 3. Bots: mod-playerbots, mod-queue-bots and mod-world-bots

#### 3.1 Population

File: `etc/modules/playerbots.conf`. All keys verified against the pinned version
(b949b50b, 2026-09-04; the `.conf.dist` has not changed since 2f7d9f77): the 32
that the installer writes exist.

| `config.sh` | Key | Value | Why |
|---|---|---|---|
| `BOTS_MIN` / `BOTS_MAX` | `Playerbots.MinRandomBots` / `MaxRandomBots` | **500 / 600** (since 2026-09-03; before 400/500 and 200/250) | The module picks a target between the two and changes it every 30-120 min. **It is how many bots actually come to exist**: it wakes up to that cap and each bot gets its level roll the first time; the rest stay in the reserve at level 1. It was raised so that mod-world-bots has somewhere to take bots of your bracket from without emptying the rest of the world. The dist brings 500/500. **Memory still to be watched**: with 153 bots the worldserver took 3.7 GB |
| `BOT_ACTIVE_ALONE` | `BotActiveAlone` | 10 | Percentage of bots that really simulate far from any player. Those in your zone are always woken up (`BotActiveAloneForceWhenInZone = 1`, from the dist). It is what contains the cost of 400-500 bots |
| `BOTS_PERIODIC_ONLINE_OFFLINE` / `BOTS_PERIODIC_RATIO` | `EnablePeriodicOnlineOffline` / `PeriodicOnlineOfflineRatio` | **true** / 2.0 (since 2026-09-02) | Bots come and go in turns, like real people: from a set of 2 × `BOTS_MAX` (1000 of the 1500) there are `BOTS_MAX` connected and they keep rotating. Over time more bots are debuted and the population changes from one day to the next |
| `BOTS_ACCOUNT_COUNT` | `Playerbots.RandomBotAccountCount` | 150 | 10 characters per account → 1500 bots in the reserve |
| `BOTS_LEVEL_MIN` / `MAX` | `RandomBotMinLevel` / `MaxLevel` | 1 / 80 | |
| `BOTS_DISABLED_WITHOUT_PLAYER` | `DisabledWithoutRealPlayer` | **true** | Random bots only appear with a real player. When the last one leaves, they disconnect after 10 minutes (`BOTS_NO_PLAYER_LOGOUT_DELAY=600`). |
| `BOTS_MAX_PER_PLAYER` | `MaxAddedBots` | 40 | Cap of own bots in your raid. With 4 a raid could not be formed, and with individual-progression progression **is** the raid |
| `BOTS_SELFBOT_LEVEL` | `SelfBotLevel` | 2 | Anyone can use their alts as bots |
| `BOTS_GUILD_INVITE_PLAYER` | `RandomBotInvitePlayer` | true | The bots' guilds invite you |
| `BOTS_LIMIT_TALENTS_EXPANSION` | `LimitTalentsExpansion` | true | Talents in line with the progression phase |

#### 3.2 Levels

| `config.sh` | Key | Value | Why |
|---|---|---|---|
| `BOTS_MIN_LEVEL_CHANCE` | `RandomBotMinLevelChance` | 0.0 | Percentage pinned at the minimum level. At 0 they are spread uniformly |
| `BOTS_MAX_LEVEL_CHANCE` | `RandomBotMaxLevelChance` | 0.35 | The maximum level is the only bracket of **a single level**: with a uniform spread it got 8 bots out of 653, and at level 80 not even one battleground ran. With 0.35 there are ~90 |
| `BOTS_SYNC_LEVEL_WITH_PLAYERS` | `SyncLevelWithPlayers` | **false** | Ties the bots' maximum level to the highest connected player. **With nobody connected it is 1**: a re-randomization with the server empty would leave all the bots at level 1. Do not enable |
| `BOTS_LEVEL_BRACKETS` | `LevelBrackets.Enabled` | **true** (since 2026-09-01) | Spreads the population in brackets of 10 levels and skews it towards the bracket where you are. Integrated into playerbots on 2026-08-07 (PR #2558); the previous version **did not have it** and phase 5 checks it with a `grep` before writing it |
| `BOTS_LEVEL_BRACKETS_DYNAMIC` | `LevelBrackets.Dynamic.UseDynamicDistribution` | **true** | The dynamic spread overrides the fixed percentages and lets the population follow the real player. Without humans it keeps the nine uniform brackets |
| `BOTS_LEVEL_BRACKETS_HIGHEST_ONLY` | `LevelBrackets.Dynamic.HighestPlayerOnly` | **true** | Local patch: 100 % of both factions in the bracket of the highest-level connected human. It takes precedence over the ordinary weighting |
| `BOTS_LEVEL_BRACKETS_SYNC_FACTIONS` | `LevelBrackets.Dynamic.SyncFactions` | **true** | Alliance and Horde follow the same bracket |
| `BOTS_LEVEL_BRACKETS_PLAYER_WEIGHT` | `LevelBrackets.Dynamic.RealPlayerWeight` | 1000.0 | Fallback in case the patch is missing; with `HighestPlayerOnly` active it does not decide the spread |
| `BOTS_LEVEL80_PCT` | percentages `LevelBrackets.<faction>.Range*.Pct` | 0 | It imposes no fixed quota of level 80. `mod-adaptive-ai` is archived |
| `BOTS_WORLD_TIME_MIN` / `_MAX` | `Playerbots.MinRandomBotInWorldTime` / `Max...` | 7200 / 28800 | Seconds a bot stays in the world before it can be rotated |

> ⚠️ To move a bot to another bracket, LevelBrackets **re-rolls it entirely** with
> `PlayerbotFactory::Randomize()`: level, gear, talents and quests. It is the
> effect of `rndbot init`, but trickled. It does not affect your character. If the
> bots change too much, `BOTS_LEVEL_BRACKETS=false` and `--only 5`, no
> recompiling.

#### 3.3 Gear

| `config.sh` | Key | Value |
|---|---|---|
| `BOTS_MAX_GEAR_QUALITY` | `RandomGearQualityLimit` and `AutoGearQualityLimit` | 4 (epic) |
| `BOTS_GEAR_TWO_ROUNDS` | `TwoRoundsGearInit` | true |

With 3 (blue) the level 80 bots came out with 672 blue pieces out of 738 and were
good for neither Naxxramas nor a battleground. `RandomBotMaxGearQuality`, which
the installer used to write, **does not exist**.

#### 3.4 Queues: why auto-joining is off

| `config.sh` | Key | Value |
|---|---|---|
| `BOTS_AUTO_JOIN_BG` | `RandomBotAutoJoinBG` | **false** |
| `BOTS_JOIN_LFG` | `RandomBotJoinLfg` | true |
| `BOTS_BG_ALL_BRACKETS` / `BOTS_BG_PER_BRACKET` | `RandomBotAutoJoin*Brackets` / `*Count` | true / 1 (they only count if auto-joining is on) |
| `BOTS_ARENA_RATED_2V2` / `3V3` / `5V5` | `RandomBotAutoJoinBGRatedArena*Count` | 2 / 2 / 1 |

playerbots' auto-joining tries to fill **one battle per bracket of each
battleground** —24 at once— with the connected bots: it fills none, and it knows
nothing about the queue you are in. It is replaced by **mod-queue-bots** (our own
module, `modules/mod-queue-bots/`): it looks at which queue you joined and puts
into *that* one the missing bots, from the corresponding level bracket.

| `config.sh` | Key (`mod_queue_bots.conf`) | Value |
|---|---|---|
| `INSTALL_MOD_QUEUE_BOTS` | — | true |
| `QUEUE_BOTS_DELAY` | `QueueBots.DelaySeconds` | 0 |
| `QUEUE_BOTS_MAX_RAID` | `QueueBots.MaxRaidBots` | 39 |
| `QUEUE_BOTS_RAID_SIZE` | `QueueBots.RaidSize` | 0 (according to difficulty) |
| `QUEUE_BOTS_RAID_TANKS` / `HEALERS` | `QueueBots.RaidTanks` / `RaidHealers` | 0 (according to size) |
| `QUEUE_BOTS_RAID_SUMMON_DELAY` | `QueueBots.RaidSummonDelay` | 8 s: the bot that joins your raid teleports next to you after those seconds (plus 0-3 at random), never in combat. 0 = never |
| `QUEUE_BOTS_DUNGEON_CLEAR_AUTO` / `DELAY` | `QueueBots.DungeonClearAuto` / `DungeonClearDelay` | true / 10 s: with the finder group inside the dungeon, it sends `.dc on` on your behalf (§4.5). Never if you are the tank |
| `QUEUE_BOTS_WAKE` / `WAKE_MAX` | `QueueBots.WakeBots` / `WakeMax` | true / 40 |
| `QUEUE_BOTS_FORCE_ACCEPT_AFTER` | `QueueBots.ForceAcceptAfter` | 40 s |

How it works inside, and what it took to make it work: `REFERENCES.md`.

#### 3.5 What keeps the dist value

They are worth knowing even if `config.sh` does not touch them:

- `Playerbots.BotActiveAloneForceWhenInZone = 1`: the bots in your zone always
  simulate at 100 %, wherever they are within it. It is what makes the ones
  brought by mod-world-bots really move. (`BotActiveAlone`, the percentage for
  those far away, is already governed by `BOT_ACTIVE_ALONE`: §3.1.)
- `Playerbots.EnableGreet = 0`, `RandomBotEmote = 0`, `RandomBotSayWithoutMaster = 0`:
  the bots neither greet nor gesticulate. Decided so on 2026-09-01.
- `Playerbots.MinRandomBotTeleportInterval = 3600` / `Max = 18000`: a bot
  changes zone every 1-5 hours.
- The texts the bots say (`ai_playerbot_texts`, 1908 rows) **have been in Spanish
  since 2026-09-02**: 1062 already came translated in the pinned version and the
  remaining 846 are in `patches/locales-es-playerbots/`, which phase 5 applies to
  `acore_playerbots` with `LOCALE_ES=true`. Bots speak in the client's language
  (`DBC.Locale`), so with an esES client they are seen in Spanish.

#### 3.6 Your zone is not empty: mod-world-bots

With 400 bots among 80 levels and ~90 combinations of zone and faction, each zone
gets two or three. playerbots moves each bot **within its zone** and changes its
zone at random every 1-5 hours; it only knows where you are in order to wake up
those that were already there. LevelBrackets fixes the level, not the zone.
**mod-world-bots** (our own module, `modules/mod-world-bots/`) counts, on
entering a zone, the bots of your bracket that are in it and brings the missing
ones to hunting spots more than 250 yards from you.

| `config.sh` | Key (`mod_world_bots.conf`) | Value | Notes |
|---|---|---|---|
| `INSTALL_MOD_WORLD_BOTS` | — | true | Requires playerbots. Recompile when changing it |
| `WORLD_BOTS_MIN` / `MAX` | `WorldBots.MinBots` / `MaxBots` | 15 / 30 (the module's dist brings 12/25) | Target for the whole zone, random between both values each time you enter; it is not a per-radius quota. Only bots of your bracket count |
| `WORLD_BOTS_LEVEL_BELOW` / `ABOVE` | `WorldBots.LevelBelow` / `LevelAbove` | 5 / 3 | Bracket: [level−5, level+3] |
| `WORLD_BOTS_MIN_DISTANCE` | `WorldBots.MinDistance` | 250 | Yards between you and where a bot is dropped. Minimum accepted 150 (below that you would see it appear); if the zone has no point that far, 150 is used |
| `WORLD_BOTS_OPPOSITE_SHARE` | `WorldBots.OppositeFactionShare` | 0.35 | In contested zones, share of the target for the opposing faction. In single-faction zones, all of that faction (whether it is yours or not) |
| `WORLD_BOTS_MAX_PER_PASS` | `WorldBots.MaxPerPass` | 5 | Teleports per pass, every 15 s up to the target: no waves |
| `WORLD_BOTS_TOPUP_SECONDS` | `WorldBots.TopUpSeconds` | 60 | With the zone full, how often it is topped up |
| `WORLD_BOTS_WAKE` / `WAKE_MAX` | `WorldBots.WakeBots` / `WakeMax` | true / 20 | Switch on sleeping bots if there are not enough free ones of your bracket |
| `WORLD_BOTS_ANNOUNCE` | `WorldBots.Announce` | false | Announce in chat how many have arrived |
| `WORLD_BOTS_CITY_MIN` / `MAX` | `WorldBots.CityMinBots` / `CityMaxBots` | 30 / 50 | **Capitals** (since 2026-09-02): they have no hunting spots, so the bots are dropped in front of their service NPCs (innkeepers, bank, auctions, vendors, trainers, flight masters), of any level |
| `WORLD_BOTS_CITY_MIN_DISTANCE` | `WorldBots.CityMinDistance` | 150 | Cities are small; 150 is the minimum accepted |
| `WORLD_BOTS_STAGE` | `WorldBots.Stage.Enable` | true | With one player, random bots respect the cap and maps of the highest connected stage; without players, no restriction. All those above the cap are re-randomized: there is no training reserve in Dalaran. `.wbots etapa` shows it |
| `WORLD_BOTS_STAGE_TBC_FROM` / `_WOTLK_FROM` | `WorldBots.Stage.TbcFrom` / `.WotlkFrom` | 8 / 13 | Progression level from which the stage is TBC (PRE_TBC) and WotLK (TBC_TIER_5) |
| `WORLD_BOTS_STAGE_VANILLA_CAP` / `_MAPS`, `_TBC_CAP` / `_MAPS` | `WorldBots.Stage.VanillaCap` ... | 60 / 0,1 / 70 / 0,1,530 | Cap and maps of each lower stage |
| `WORLD_BOTS_STAGE_PER_PASS` | `WorldBots.Stage.PerPass` | 3 | Bots relocated or re-randomized per 5 s pass |
| — | `WorldBots.CityZones` | the 8 capitals + Shattrath and Dalaran | Zone ids treated as a city. Only in the `.conf.dist` |
| `VISIBILITY_DISTANCE_CONTINENTS` | `Visibility.Distance.Continents` (worldserver) | 160 | The core brings 100. With bots at 250 yards, to see them before they arrive. It goes in §2 but it is for this |

Hunting spots are 50-yard cells with at least two normal mobs with loot (the
criterion of playerbots' own destination cache), indexed by zone once at start-up:
the `[world-bots] N puntos de caza en M zonas` line (N hunting spots in M zones)
of `Server.log`. Cities and zones without mobs are not populated (the log says so
the first time). How it works inside: `REFERENCES.md`.

On arrival, each bot has the state of its role strategy changed: in the field,
"hunt around where I arrive"; in the city, "decide again" (it strolls among the
NPCs). Without that, its strategy took it back to where it was going before.


**World war** (`WorldBots.Pvp.*`, since 2026-09-02, night):

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `WORLD_BOTS_PVP` | `WorldBots.Pvp.Enable` | true | Skirmishes and duels at hotspots |
| `WORLD_BOTS_PVP_TICK_SECONDS` / `_CHANCE` | `TickSeconds` / `EventChancePerTick` | 60 / 1.5 | 1.5 % per minute; accepts decimals |
| `WORLD_BOTS_PVP_MAX_ACTIVE` | `MaxActiveEvents` | 1 | With one player, one |
| `WORLD_BOTS_PVP_ONLY_WITH_PLAYER` | `OnlyWithPlayerInZone` | true | A war nobody sees is CPU |
| `WORLD_BOTS_PVP_MIN_LEVEL` / `_MAX_PER_SIDE` | `MinLevel` / `MaxBotsPerSide` | 20 / 8 | Global minimum level and cap per side |
| `WORLD_BOTS_PVP_MOVE_DELAY` | `MoveDelaySeconds` | 15 | Gathering before advancing |
| `WORLD_BOTS_PVP_DUELS` / `_DUEL_PAIRS` | `Duels` / `DuelPairs` | true / 4 | Duels at the gates of the capitals |
| `WORLD_BOTS_PVP_ANNOUNCE` | `Announce` | true | "The Horde marches on Southshore" to those in the zone |

The hotspots live in `acore_world.world_bots_pvp_hotspot` (23 rows,
`REFERENCES.md`); `.wpvp recargar` (reload) reads them again without restarting.

#### 3.7 Quest companions: mod-quest-mates

When you accept a quest, two or three bots from your zone, of your faction and
your level bracket take it too (if the core says they can: level, race, class,
prerequisites, room in the log) and their role strategy sets about it. The same
bots repeat with you while they remain in the zone. Left out are dungeon, raid,
escort, PvP, heroic, daily, repeatable and event quests.

| `config.sh` | Key (`mod_quest_mates.conf`) | Value |
|---|---|---|
| `INSTALL_MOD_QUEST_MATES` | — | true |
| `QUEST_MATES_MIN` / `MAX` | `QuestMates.MinMates` / `MaxMates` | 2 / 3 |
| `QUEST_MATES_LEVEL_BELOW` / `ABOVE` | `QuestMates.LevelBelow` / `LevelAbove` | 5 / 3 |
| `QUEST_MATES_CHANCE` | `QuestMates.Chance` | 100 % |
| `QUEST_MATES_REMEMBER_MINUTES` | `QuestMates.RememberMinutes` | 30 |
| `QUEST_MATES_ANNOUNCE` | `QuestMates.Announce` | false |

In the log: `[quest-mates] X, Y cogen 'quest' con Player` (X, Y take 'quest' with
Player), or who could not and why.

---

#### 3.8 Gear of your group's bots (since 2026-09-02)

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `QUEUE_BOTS_GEAR_MODE` | `QueueBots.GearMode` | 1 | 0 do not touch; 1 your average + margin without exceeding your phase's cap; 2 only the phase's cap |
| `QUEUE_BOTS_GEAR_MARGIN` | `QueueBots.GearMargin` | 6 | Item levels above your average |
| `QUEUE_BOTS_GEAR_TOLERANCE` | `QueueBots.GearTolerance` | 8 | Regear only outside ±tolerance |
| `QUEUE_BOTS_GEAR_MIN_ILVL` | `QueueBots.GearMinItemLevel` | 0 | Floor, in case you go in greens at 80 |
| `QUEUE_BOTS_TOKEN_TURNIN` | `QueueBots.TokenTurnIn` | true | `.tokenturnin redeem` on your behalf after each boss (needs mod-token-turnin) |
| `QUEUE_BOTS_TOKEN_TURNIN_DELAY` | `QueueBots.TokenTurnInDelay` | 90 | Seconds for the rolls to finish |

It applies to the finder-board raid when each bot joins and to any group of yours
on entering an instance (dungeon or raid, whether they come from the finder or
from `mod-party-here`). The same four keys exist with the `PartyHere.` prefix for
that module's groups. The caps per phase are in `REFERENCES.md` (shared headers).

#### 3.9 A group where you stand: mod-party-here

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `PARTY_HERE_LEVEL_BELOW` / `_ABOVE` | `PartyHere.LevelBelow` / `LevelAbove` | 3 / 0 | None above: it would steal your experience |
| `PARTY_HERE_MAX_RAID_BOTS` | `PartyHere.MaxRaidBots` | 39 | Cap of `.grupo banda` (raid group); never above `MaxAddedBots` |
| `PARTY_HERE_AUTO_GROUP_QUESTS` | `PartyHere.AutoGroupQuests` | true | Quests with suggested players |
| `PARTY_HERE_AUTO_MAX_BOTS` | `PartyHere.AutoMaxBots` | 2 | Cap of automatic bots |
| `PARTY_HERE_AUTO_LINGER_SECONDS` | `PartyHere.AutoLingerSeconds` | 120 | How long they stay once they are no longer needed |
| `PARTY_HERE_SUMMON_DELAY` | `PartyHere.SummonDelay` | 3 | Seconds until they are brought next to you (0 = on foot) |
| `PARTY_HERE_WAKE` / `_WAKE_MAX` | `PartyHere.WakeBots` / `WakeMax` | true / 20 | Wake sleeping ones if they are missing |
| `PARTY_HERE_ANNOUNCE` | `PartyHere.Announce` | true | Who joins and who leaves, in chat |

#### 3.10 Your guild: mod-home-guild

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `HOME_GUILD_LEGACY_NAME` | `HomeGuild.LegacyName` | "Companeros de {name}" | Name signature used only to recognize the old automatic version |
| `HOME_GUILD_LEGACY_MOTD` | `HomeGuild.LegacyMotd` | (text) | Second part of the old signature; it does not change the MOTD of a new guild |
| `HOME_GUILD_CLEANUP_LEGACY` | `HomeGuild.CleanupLegacyAutoGuilds` | true | Disband once the old automatic guilds identified with the full signature |
| `HOME_GUILD_MEMBERS` | `HomeGuild.Members` | 15 | 30 if you are going to do 25-man raids with the guild |
| `HOME_GUILD_LEVEL_BELOW` / `_ABOVE` | `HomeGuild.LevelBelow` / `LevelAbove` | 3 / 2 | Recruits' bracket |
| `HOME_GUILD_KEEP_ONLINE` | `HomeGuild.KeepOnline` | true | Connect them with you, five at a time every 15 s |
| `HOME_GUILD_RELEVEL` / `_RELEVEL_BEHIND` | `HomeGuild.ReLevel` / `ReLevelBehind` | true / 4 | Raise their level when they fall behind |
| `HOME_GUILD_ANNOUNCE` | `HomeGuild.Announce` | true | The summary on login |

The module neither creates nor adopts guilds and does not change
`Playerbots.RandomBotInvitePlayer` either: the player keeps both decisions.

**Founding the starting guild.** Blizzard requires 9 signatures on the charter
(10 characters in total with the founder) to found a guild — in single player
there are never 9 players of your faction available to sign, and the random bots
refuse the signature if they do not match your faction at that instant, so the
founding was never completed. `GUILD_MIN_PETITION_SIGNS` (config.sh, "HERMANDADES"
section) writes `MinPetitionSigns` — a core key, not this module's — to 0, so the
player can found it alone. `mod-home-guild` does not take part in the founding
itself: it only starts recruiting and looking after the guild after it already
exists.

### 4. Instances

#### 4.1 mod-autobalance

File: `etc/modules/AutoBalance.conf`. Names verified against the module's `src/`
(2026-09-01): the keys `AutoBalance.enable` (lowercase),
`AutoBalance.rate.global.*` and `AutoBalance.rate.health/damage` are in the dist's
**deprecated** section and the module only reads them to warn that they no longer
work; `AutoBalance.Raids` has never existed. Until 2026-09-01 the installer wrote
exactly those, and the scaling ran on factory values.

| `config.sh` | Real keys | Value |
|---|---|---|
| `AUTOBALANCE_ENABLED` | `AutoBalance.Enable.Global` | true |
| `AUTOBALANCE_RAIDS` | `AutoBalance.Enable.10M` `.15M` `.20M` `.25M` `.40M` `.10MHeroic` `.25MHeroic` | true |
| `AUTOBALANCE_INFLECTION` | `AutoBalance.InflectionPoint` | 0.5 |
| `AUTOBALANCE_RATE_HEALTH` | `AutoBalance.StatModifier.Health`, `StatModifierHeroic.Health`, `StatModifierRaid.Health`, `StatModifierRaidHeroic.Health` | 1.0 |
| `AUTOBALANCE_RATE_DAMAGE` | Same with `.Damage` | 1.0 |

The 5-player ones (`Enable.5M`, `.5MHeroic`, `.OtherNormal`, `.OtherHeroic`) are
governed only by the global switch. The modifiers for a specific size
(`StatModifierRaid10M.*`…) are left blank and inherit from their family.

Commands: `.ab mapstat` (map status), `.ab creaturestat` (of the selected
creature).

#### 4.2 mod-dungeon-master (⚠️ early development)

File: `etc/modules/mod_dungeon_master.conf`. All its keys carry the
`DungeonMaster.` prefix; without it they are silently ignored. It is governed
entirely from `config.sh` with the `DM_*` variables (solo and per-player scaling,
boss and elite multipliers, Roguelike mode and rewards). See the corresponding
section of `config.sh`, which explains them one by one.

Its NPC appears in the eleven capitals and is the **anchor** of the service NPCs
(§8). If you disable it (`INSTALL_MOD_DUNGEON_MASTER=false`) phase 3 sets it aside
into `modules-disabled/` and cleans its traces from the database; the service NPCs
are then placed next to the innkeepers of Stormwind and Orgrimmar.

The module queries the `id1` column, which AzerothCore no longer uses: the
installer fixes it with a `sed` (`patch_dungeon_master_id1_bug` in
`lib/utils.sh`).

#### 4.3 mod-instanced-worldbosses

| `config.sh` | Key | Value |
|---|---|---|
| `IWB_RESET_TIMER_SECS` | boss reset | 25920 (3 days) |
| `IWB_RESPAWN_TIMER_SECS` | respawn after dying | 3600 |
| `IWB_PHASE_BOSSES` | phases the group out | true — **the one that matters with bots**: the boss is only yours |

#### 4.4 mod-instance-reset

Out of the box it is free (`TransactionType = 0`), which allows farming the same
raid in a loop. It is charged on purpose: `INSTANCE_RESET_PAYMENT=2` (gold),
`INSTANCE_RESET_MONEY=2500000` (250 gold). `INSTANCE_RESET_*` variables.

#### 4.5 mod-dungeon-clear (since 2026-09-02)

The bot tank leads the dungeon from start to finish: route between bosses, pulls,
scripted events, loot, rest, resurrection. Its code was reviewed before installing
it (`CHANGELOG.md` (annex A5)): it **waits for the human player** (more than 25
yards away, without health or mana, dead) with no time limit in the default mode.
You cannot be the tank. Commands: `.dc on/off/pause/skip/status/bosses/go/wing/spectate`
(`.dc on|wing <wing>` chooses the wing in Blackrock: `lbrs`/`ubrs`,
`brd-db`/`brd-uc`).

| `config.sh` | Key (`mod_dungeon_clear.conf`) | Value | Why |
|---|---|---|---|
| `INSTALL_MOD_DUNGEON_CLEAR` | `DungeonClear.Enable` | true / 1 | Pinned in `versions.lock` (`07f8e33`, 2026-10-12). It is the module most fragile to playerbots updates. Its dungeon-finder queue fill (`DungeonClear.DungeonQueueFill.*`, since 03/09) and its battleground one (`DungeonClear.BgQueueFill.*`, since 2026-10-01) stay off: mod-queue-bots does that |
| `DUNGEON_CLEAR_WAIT_AT_BOSS` | `DungeonClear.WaitAtBoss` | false | With true, it pauses before each boss until you say `.dc pause` |
| `DUNGEON_CLEAR_SMART_REST` | `DungeonClear.SmartRest` | **false** | The smart rest moves on at 3 minutes even if you are AFK; the classic one waits until you have health and mana, with no limit |
| `DUNGEON_CLEAR_REZ_TIMEOUT` | `DungeonClear.PostCombatRezTimeoutSecs` | 180 | Seconds out of combat for the resurrection recovery before giving up (the dist brings 90) |

It switches on by itself: `mod-queue-bots` sends `.dc on` on your behalf when the
finder group is inside (§3.4). Everything else (pulls, routes, loot, over a
hundred keys) stays with the `.conf.dist` values; they accept a `.Heroic` suffix.

---

### 5. Progression

#### 5.1 mod-individual-progression

File: `etc/modules/individualProgression.conf`. It requires in `worldserver.conf`
`EnablePlayerSettings = 1`, `Updates.EnableDatabases = 7` and
**`DBC.EnforceItemAttributes = 0`** — without the last one, the restoration of the
items' vanilla stats is not applied and nobody warns you. All three are written
by phase 5.

The `IP_*` variables of `config.sh` set the pace: start in Vanilla with no cap
(`IP_STARTING_PROGRESSION=0`, `IP_PROGRESSION_LIMIT=0`), without separating by
phase those who play together (`IP_ENFORCE_GROUP_RULES=false`), dungeon finder
active (`IP_DISABLE_RDF=false`), Naxx40 bosses beatable with a small group
(`IP_DOABLE_NAXX40_*`), power and healing adjustments for each expansion, Molten
Core runes, ZG/ZA requirements, unlocking of the TBC races and Death Knight, and
the PvP rank divisor (`IP_PVP_RANK_DIVISOR=4`: rank 1 with 25 kills, rank 14 with
6000).

**The module's optional SQL** (`IP_OPTIONAL_SQL`): `small_group_adjustments`
(written for 40-man raids with a small group and bots), `vanilla_models`,
`restore_rogue_poisons`, `vanilla_crafting_requirements`. The 22 available ones
are in the module's `optional/sql/world/`.

**Optional DBCs** (`IP_OPTIONAL_DBC=true`): Vanilla/TBC spells, recipes and
reagents. `SkillRaceClassInfo.dbc` **is not copied if ARAC is active**: both
modules bring that file and ARAC's wins. They are copied at the end of phase 5,
after the client data (originals in `dbc/backup-pre-ip/`), and phase 8 repeats it
as a safety net; the doctor (`server-dbc`) warns if they are missing. Optional
client step: `patch-V.mpq` in `Data/`.

Commands: `.ip get <name>`, `.ip set <name> <phase>` (also `.ip tele`, `.ip attune`, `.ip pvp`).

#### 5.2 mod-war-effort

Ahn'Qiraj War Effort: 5 materials × 5 phases × 2 factions = 50 keys that phase 5
writes in a loop from `WAR_EFFORT_GOALS=(5 10 15 20 25)` and
`WAR_EFFORT_GOAL_SCALE=1`. With the scale at 1 a single player completes it.

#### 5.3 mod-challenge-modes

Per-character challenges (Hardcore, Semi-Hardcore, Crafted Only, Item quality,
slow and very slow XP, Quest-XP only, Iron Man) that are activated at level 1 in
the *Challenge Sanctuary* (Santuario del Desafío) next to the graveyard of the 9
starting zones. `CM_<CHALLENGE>` activates each one, `CM_TALENTS_<CHALLENGE>`
gives the talent-point reward and `CM_XP_MULT_<CHALLENGE>` the XP multiplier.

It needs `patches/mod-challenge-modes/01-hook-onplayerresurrect.patch` to compile
against this core (the `OnPlayerResurrect` hook is `bool&`; verified that it is
still so in the 2026-09-04 core). Its texts are embedded in the code, some in
Chinese: it is deliberately not translated.

#### 5.4 mod-pvp-titles (disabled)

`INSTALL_MOD_PVP_TITLES=false`. It duplicates individual-progression's vanilla
title system with much lower thresholds and overrides its phased design.

---

### 6. Economy and services

#### 6.1 mod-ah-bot-plus

File: `etc/modules/mod_ahbot.conf` (**not** `mod_ahbotplus.conf`; it is the same
name the native bot would use and a "minimal conf" to silence it was overwriting
the 72 KB of real configuration).

The installer creates the service account (`AH_BOT_ACCOUNT`, with a random
verifier: nobody can log in with it) and two sellers (`AH_BOT_CHAR_ALLIANCE`,
`AH_BOT_CHAR_HORDE`, GUID from `AH_BOT_GUID_BASE=9000001`) and writes their GUIDs
into `AuctionHouseBot.GUIDs`. The rest: `AH_ITEMS_PER_CYCLE` (`ItemsPerCycle`, 75),
`AH_BUYER_ENABLED` (`Buyer.Enabled`), `AH_BUYER_CANDIDATES_PER_CYCLE`,
`AH_BUYER_PRICE_MODIFIER`, `AH_BUYER_BID_AGAINST_PLAYERS`, `AH_SELL_EPICS` (sets to
0 the epic proportions of weapons and armor; there is no "epics yes/no" key).

The auction house takes hours to fill: `.ahbot update` 5-10 times with the GM
fills it at once. `.ahbot reload` reloads the conf, `.ahbot empty` empties it.

#### 6.2 mod-transmog

File: `etc/modules/transmog.conf`. The activation key is
`Transmogrification.Enable` (**without** a "d"; until 2026-09-01 `Enabled` was
written, which does not exist — the module worked because the dist already brings
it at 1).

| `config.sh` | Key |
|---|---|
| `TRANSMOG_MIXED_WEAPONS` | `Transmogrification.AllowMixedWeaponTypes` |
| `TRANSMOG_ALLOW_HIDDEN` | `Transmogrification.AllowHiddenTransmog` |
| `TRANSMOG_COST` | `Transmogrification.CopperCost` |

The NPC (entry 190010) is placed by itself in the eleven capitals (§8). Since the
2026-07-26 version there is `.transmog claim` to collect appearances from the
bags, with its texts already in Spanish.

#### 6.3 mod-random-enchants

File: `etc/modules/random_enchants.conf`. `RANDOM_ENCHANTS_ANNOUNCE` governs the
notice on login. The rest (`OnLoot`, `OnCreate`, `OnQuestReward`, `OnGroupRoll`,
`EnchantChance1..3`) stays with the dist.

**Scaling by level** (`RANDOM_ENCHANTS_SCALE_WITH_LEVEL=true`,
`RANDOM_ENCHANTS_TIER{2..5}_MIN_LEVEL` = 20/40/60/71): added by
`patches/mod-random-enchants/01-level-scaled-tiers.patch`. The original module
rolled the tier without looking at the level, and its query also had an `= NULL`
and an `AND`/`OR` without parentheses that nullified the tier filter. Since
2026-09-01 the patch also declares the five keys in the `.conf.dist`, so that
phase 5 does not flag them as undeclared.

#### 6.4 mod-congrats-on-level

Three different messages, each with its own switch (since 2026-09-02):

| `config.sh` | Key (`mod_congratsonlevel.conf`) | Value | What it turns off |
|---|---|---|---|
| `CONGRATS_LOGIN_ANNOUNCE` | `Congrats.Announce` | **false** | The module's notice on login |
| `CONGRATS_LEVEL_MESSAGE` | `CongratsPerLevel.Enable` | true | "[FELICITACIONES!] X has reached level N" (congratulations) to the whole server, at every level |
| `CONGRATS_REWARD_MESSAGE` | `Congrats.RewardMessage` | **false** | The reward message (the same announcement again, plus the raid notice "N copper has been awarded to you..."). The module had it fixed in the code; it is provided by `patches/mod-congrats-on-level/02-reward-message-toggle.patch` |
| `CONGRATS_IGNORE_BOTS` | `Congrats.IgnoreBots` | **true** | Bots go through the same hook: every bot that leveled up got a prize and was announced to the whole server. It was what "kept appearing" after turning the previous ones off. Same patch |

Rewards on leveling up. The rewards are **not** in the `.conf` but in the
`mod_congrats_on_level_items` table of `acore_world`, which phase 5 loads from
`congrats_on_level_rewards.sql` (columns `level`, `money` in **gold**, `spell`,
`learn`, `itemId1`, `itemId2`, `race`, `class`). The patch
`patches/mod-congrats-on-level/01-reward-any-level.patch` removes the `switch` that
only rewarded at multiples of 10, and `03-mail-when-bags-full.patch` sends by mail
what does not fit in the bag. What each level gives and why: commented in the SQL
itself and summarized in `REFERENCES.md` (v3 table of 2026-09-02: bags, riding,
dual specialization at 40, Cold Weather Flying at 77).

#### 6.5 Services

| Module | Conf | `config.sh` | NPC |
|---|---|---|---|
| mod-racial-trait-swap | `RacialTraitSwap.conf` | `RACIAL_SWAP_GOLD` | 98888 |
| mod-reagent-bank | `reagent_bank.conf` | — | 290011 |
| mod-aoe-loot | `mod_aoe_loot.conf` | `AOE_LOOT_RANGE`, `AOE_LOOT_GROUP` | — |
| mod-quest-loot-party | `mod-quest-loot-party.conf` | `QUEST_LOOT_PARTY_ENABLE`, `QUEST_LOOT_PARTY_MESSAGE` | — |
| mod-1v1-arena | `1v1arena.conf` | `ARENA_1V1_*` (level 80) | 999991 |

---

#### 6.6 mod-world-buff-bots and mod-token-turnin (since 2026-09-02)

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `WORLD_BUFF_BASE_MINUTES` / `_VARIANCE_MINUTES` | `WorldBuffBots.BaseMinutes` / `VarianceMinutes` | 90 / 60 | Each buff fires every 30-150 min, independently |
| `WORLD_BUFF_WARCHIEF` / `_DRAGONSLAYER` / `_ZANDALAR` | `WorldBuffBots.<X>.Enable` | true | Orgrimmar (and the Crossroads), Stormwind, Stranglethorn |
| `WORLD_BUFF_*_TEXT` | `WorldBuffBots.<X>.Announcement` | Spanish | `{player}` is the announcer's made-up name |
| `TOKEN_TURNIN_INCLUDE_SELF` | `TokenTurnIn.IncludeSelf` | false | Your tokens are your own business; the module is for the bots |

`TokenTurnIn.IncludeRealPlayers` is always left at 0. The command is
`.tokenturnin check` (look) and `.tokenturnin redeem` (exchange); queue-bots sends
it by itself after each boss (§3.8). Its table `mod_token_turnin_tokens` (121
rows, T3 to T8 plus ZG/AQ20) goes in `acore_world` and is applied by phase 5.

#### 6.7 Roaming treasures (SP03)

`INSTALL_MOD_TREASURE=true` brings in our own module in phase 3, compiles it in 4
and applies configuration, catalog and loot in 5. Phase 8 reapplies the idempotent
SQL. The 57 zone catalogs start active. When a human enters, the module checks
ground, water, line of sight and route of nearby candidates before assigning a
chest; it examines at most eight every ten seconds and saves each result.
`.tesoro estado` (status) shows points and deadlines; a GM can force more checks
with `.tesoro validar` or remove chests with `.tesoro desactivar`. The next phase
5/8 reactivates the manually deactivated zones.

`TREASURE_LOCATION_SECONDS=3600` limits the stay without pickup. The values
`TREASURE_BASIC_RESPAWN_SECONDS=1800`, `TREASURE_RARE_RESPAWN_SECONDS=5400` and
`TREASURE_EPIC_RESPAWN_SECONDS=14400` govern replenishment after opening or
looting. `TREASURE_CANDIDATE_RADIUS=250` and `TREASURE_SCAN_MS=5000` limit the
controller's work; `TREASURE_SPAWN_SPELL=30262` fires the white flare on
appearing. `TREASURE_ENABLE=true` lets the module load its zones. Details of the
validator, limits and tables in "mod-treasure: roaming treasures (SP03)"
(REFERENCES.md).

### 7. Races and classes (ARAC)

`INSTALL_MOD_ARAC=true`. It is not a compiled module: it lives in
`~/azerothcore/extras/mod-arac/`. The installer applies its SQL, copies its DBCs
to the server at the end of phase 5, once the client data exists (with a backup
in `dbc/backup-pre-arac/`; phase 8 repeats it and the doctor compares byte by
byte in `server-dbc`), and on top of that applies three fixes that upstream has
**unmerged** (`patches/arac/`): starting gear and skills (PR #42), paladin and
shaman racial spells (PR #46) and cleanup of races that do not exist in WotLK.

The only manual part: each player copies
`cliente/Data/<language>/patch-<language>-4.MPQ` (which carries fused in, among
other things, the same character-creation DBCs as
`extras/mod-arac/patch-contents/DBFilesContent/`) into the `Data/<language>/`
folder of their client; `cliente/instalar-cliente.ps1` does it by itself together
with the addons. Until 2026-09-21 those DBCs went in a loose `Data/Patch-Arac.MPQ`
that Wow.exe never actually loaded (see "The client" (INSTALL_EN.md, part 5) and
`CHANGELOG.md`, task E1g).

---

### 8. Administrator account, service NPCs and Spanish

**Admin account** (`CREATE_ADMIN_ACCOUNT`, `ADMIN_ACCOUNT_NAME=admin`,
`ADMIN_ACCOUNT_PASS=admin`, `ADMIN_ACCOUNT_GMLEVEL=3`): created by phase 8 with no
characters, computing the SRP6 verifier with `lib/srp6.py` so as not to depend on
the worldserver. If it already exists its password is not touched. To change it:
`.account password <current> <new> <new>`.

**Service NPCs** (`SPAWN_SERVICE_NPCS=true`): transmog, reagent bank, racial swap
and 1v1 battlemaster in the **eleven capitals**, two on each side of the Dungeon
Master NPC and within 5 yards, with the height copied from the nearest real NPC.
Idempotent: rerunning phase 5 relocates them. Coordinates, exceptions per capital
and the history of each one in `REFERENCES.md`.

**Spanish** (`LOCALE_ES=true`): the base game already comes translated in the
database; what the modules add is translated by `patches/locales-es/` (the two
transmog strings that were missing and the names of the service NPCs). How to
translate a new module: see whether it keeps texts in `module_string_locale`, in
`acore_string` (column `locale_esES`) or embedded in the `.cpp` (the bad case, as
with challenge-modes); in the first two cases it is one more `.sql` in that
folder.

---

### 9. Versions, offline copies and notices

```bash
PIN_VERSIONS=true               # pin each repo to the commit in versions.lock
WEEKLY_UPDATE_MODE="check"      # Sundays 03:00: look and warn, touching nothing
NOTIFY_GM_ON_UPDATE=true        # in-game mail to the GM accounts
GM_NOTIFY_MIN_LEVEL=3
MIRROR_REPOS=true               # offline copies in mirrors/
MIRROR_INCLUDE_CORE=true        # 209 MB; this repo lives on a Gitea with no 100 MB limit
MIRROR_ASSET_BASE_URL="https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer/releases/download/snapshots"  # release asset (https://) that ./install.sh --hidratar downloads from before rebuilding
```

**`versions.lock`** pins the exact commit of each of the 20 repositories (19 until
2026-09-02, when `mod-dungeon-clear` came in). It is regenerated with
`./install.sh --freeze` when a combination is tested.

**`mirrors/`** keeps a `.tar.gz` of each repository at its pinned commit (269 MB),
with sha256 in `MANIFEST.tsv` and **a copy of `versions.lock`** next to it (since
2026-09-01), so that the backup explains itself. Phase 3 draws from there if
cloning fails, **looking for the tarball of the pinned commit** and warning loudly
if there is only another version. They are regenerated with `./install.sh --mirror`.

**Public edition (without the `.tar.gz`).** GitHub rejects files over 100 MiB and
seven of the modules do not declare a license, so the public edition carries
`MANIFEST.tsv` (name, commit, size, file name, SHA-256 and upstream URL) and not
the tarballs. `./install.sh --hidratar [repository...]` ("hydrate") leaves in
`mirrors/` the snapshots of `versions.lock`, by the first route that gives a file
**with that exact SHA-256**: the one already there, the asset of
`MIRROR_ASSET_BASE_URL` (if defined) or upstream, asking only for the pinned commit
(`git fetch --depth 1 <sha>`) and repeating the `git archive | gzip -9` of
`--mirror`, which is reproducible. A file whose hash does not match is not
installed no matter where it comes from; with no network or asset and with
upstream moved, the step fails instead of using another version.
`./install.sh --verify-mirrors` accepts missing snapshots (it counts them as
"not hydrated"); with `--hidratados` it requires them.
`tools/verificar-parches.sh` hydrates what it needs and checks that each of our
patches applies on the pinned commit, with no Git repository and no prior
`mirrors/`.

**Packages of each version.** Each version attaches, with its `SHA256SUMS`,
`MANIFIESTO.tsv` and `NOTAS-DE-VERSION.txt` (release notes):
`azerothcore-single-player-<version>.zip` and `.tar.gz` (the public tree without
Git history, with the execute permissions and the Linux line endings),
`azerothcore-single-player-<version>-con-snapshots.tar` (the same tree plus the
snapshots in `mirrors/`, to avoid downloading the core and the modules) and one
asset per snapshot (`<module>@<commit>.tar.gz`; its download address is what goes
in `MIRROR_ASSET_BASE_URL`). The assets are a backup copy of every snapshot,
including those of modules whose origin has no license file; if an author asks
for one to be removed, it is withdrawn from the release and the installer goes
back to requesting it from its repository. The packages are generated
reproducibly from a single commit and checked before being attached: same paths
and bytes as the public export, no `.git`, no Markdown other than the common
documents and no secrets. **They are not an offline installation**: they do not
include the third-party addons, `Data.zip` v20.0 or the
npm dependencies, and they carry nothing from Blizzard (client patches, icons and
maps are generated from the player's client). The ZIP that GitHub offers
automatically for a tag is only the tree: the installer completes the rest with
SHA-256 verification and, if a hash does not match or an input is missing, it
stops the step instead of carrying on.

**Licenses.** Our own code is AGPL-3.0-or-later (`LICENSE`, `NOTICE`, `LICENSES/`);
each code file carries its SPDX header and `REUSE.toml` declares copyright and
license by path for the rest. `THIRD-PARTY-NOTICES.txt` links each third-party
component to its license and origin. The patches (`.patch`) keep the license of
the project they modify and state it on their first line.
`tests/estructura-publica.sh` fails if a header, a license text or a module in the
third-party notice is missing, and CI runs `reuse lint` (the tree complies with
REUSE 3.3).

The complete procedure for updating is in [part 4 §3](#3-updating-the-core-and-the-modules).

---

#### In-game update notice (since 2026-09-02)

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `UPDATE_NOTICE_MIN_SECURITY` | `UpdateNotice.MinSecurity` | 2 | 1 moderator, 2 GM, 3 administrator |
| `UPDATE_NOTICE_DELAY_SECONDS` | `UpdateNotice.DelaySeconds` | 8 | So it is not lost among the login messages |
| `UPDATE_NOTICE_MAX_LINES` | `UpdateNotice.MaxLines` | 15 | Lines of the report that are shown |

The module reads `env/dist/bin/updates-pending.txt`, which is written by
`tools/revisar-actualizaciones.sh` and the weekly task. With no file or an empty
one, it says nothing. `.actualizaciones` (updates) shows it again.

#### The server's help in the client: mod-server-help (since 2026-09-02)

File: `etc/modules/mod_server_help.conf`. It needs the `ServerHelp` addon on the
client (`cliente/`).

| `config.sh` | Real key | Value | Why |
|---|---|---|---|
| `INSTALL_MOD_SERVER_HELP` | `ServerHelp.Enable` | true / 1 | Recompile when changing it |
| `SERVER_HELP_MAX_SEARCH_RESULTS` | `ServerHelp.MaxSearchResults` | 60 | The client paginates in 20s |
| `SERVER_HELP_CACHE_SECONDS` | `ServerHelp.CacheSeconds` | 300 | Lifetime of each account's snapshot (visible commands and articles); it is rebuilt sooner if the level changes or the data is reloaded |
| `SERVER_HELP_INDEX_COOLDOWN` | `ServerHelp.IndexCooldownSeconds` | 2 | Between two complete indexes of the same account (an administrator's is ~200 messages) |
| `SERVER_HELP_LOG_REQUESTS` | `ServerHelp.LogRequests` | false | Log each addon request in `Server.log` |
| — | `ServerHelp.LineBytes` | 230 | Bytes per line to the addon; the core limits the message to 255 and the header takes 17 |
| — | `ServerHelp.DefaultCategory.{Player,Moderator,GameMaster,Administrator}` | 2, 14, 13, 15 | Category of a command with no entry or rule, by level |

The categories, articles, entries and rules live in the `server_help_*` tables of
`acore_world` (seed in `modules/mod-server-help/data/sql/db-world/base/`, applied
by phase 5 and by the core updater). `.ayuda recargar` (help reload) reads them
again. How to add documentation: `REFERENCES.md`.


#### Bots that learn: mod-adaptive-ai (archived on 2026-09-06)

Archived own module. `INSTALL_MOD_ADAPTIVE_AI=false` makes phase 3 set it aside
into `modules-disabled/`: it is not compiled, loaded or its configuration
installed. Its last state was exported to
`modules/mod-adaptive-ai/data/entrenado/adaptive_entrenado.sql.gz` before emptying
all its tables. The calibration was not reliable enough to keep it active; the
known state and the requirements for a reactivation are in `CHANGELOG.md`. The
historical detail of the keys remains only as an archive reference in
`conf/mod_adaptive_ai.conf.dist`.

| `config.sh` key | `.conf` key | Default | Notes |
|---|---|---|---|
| `INSTALL_MOD_ADAPTIVE_AI` | — | true | Recompile when changing it. With `BOTS_DISABLED_WITHOUT_PLAYER=true` the background arena only trains while someone is playing |
| `ADAPTIVE_ENABLE` | `AdaptiveAI.Enable` | true | The decider. With false the bots are stock playerbots but the arenas continue (baseline) |
| `ADAPTIVE_LEARN` | `AdaptiveAI.Learn` | true | Learn from combats |
| `ADAPTIVE_LEARN_ONLY_ARENA` | `AdaptiveAI.Learn.SoloEnArena` | false | true: real combats do not touch the table |
| `ADAPTIVE_REAL_ENABLE` | `AdaptiveAI.Real.Enable` | true | Decide also in real combats, with the validated table |
| `ADAPTIVE_ARENA_ENABLE` | `AdaptiveAI.Arena.Enable` | true | Background training arena |
| `ADAPTIVE_ARENA_SIMULTANEOUS` | `AdaptiveAI.Arena.Simultaneas` | 20 (here 120) | Simultaneous combats. The real 1v1 capacity is `ADAPTIVE_ARENA_BOTS_MAX / 2` |
| `ADAPTIVE_ARENA_TEAM_SIMULTANEOUS` | `AdaptiveAI.Arena.EquipoSimultaneas` | 1 | Team arenas (2v2, 3v3, 5v5) at once in the automatic mode, rotating between sizes; the remaining slots go to 1v1 (2026-09-03, user's decision). The automatic battleground stays separate (one every 30 min) |
| `ADAPTIVE_ARENA_WITH_PLAYER` | `AdaptiveAI.Arena.ConJugador` | 1c1:21 | With a player connected the automatic mode limits itself to these simultaneous matches per size; without players, everything. Since the afternoon of 2026-09-03 everything goes to 1v1 (21 matches = 42 bots, the same as before when it split them between one of each size and a battleground): it is where learning is fastest. It does not touch PvE |
| `ADAPTIVE_BG_WITH_PLAYER` | `AdaptiveAI.Bg.ConJugador` | 0 | Automatic battlegrounds at once with a player connected |
| `ADAPTIVE_LEVEL_BRACKETS_WITH_PLAYER` | `AdaptiveAI.FranjasConJugador` | **true** | Switches playerbots' level-bracket distribution: **automatic** while a player is connected (brings the population closer to your level) and **fixed** when the server trains alone, which is when the automatic mode has nobody to follow and leaves training 28 level-80 bots instead of 200. The module checks it every 30 s and the bracket manager rereads the flag on every pass. `false` = touch nothing and obey whatever `playerbots.conf` says. The starting value is `BOTS_LEVEL_BRACKETS_DYNAMIC` |
| `ADAPTIVE_ARENA_BOTS_MAX` | `AdaptiveAI.Arena.BotsMax` | 40 (here 200) | Simultaneous bots in arenas, adding up sizes: leaves level-80 bots for the battlegrounds and the players (since 2026-09-03) |
| `ADAPTIVE_ARENA_PAUSE_SECONDS` | `AdaptiveAI.Arena.PausaEntreCombates` | 5 | Seconds between two launches |
| `ADAPTIVE_CLASSES` | `AdaptiveAI.Clases` | (empty = all) | Classes that decide and train; the others play stock (since 2026-09-03) |
| `ADAPTIVE_ARENA_TYPES` | `AdaptiveAI.Arena.Tipos` | 1c1,2c2,3c3,5c5 (here all four; the bulk goes to 1v1 via `ADAPTIVE_ARENA_TEAM_SIMULTANEOUS`) | Sizes the automatic mode trains; by hand any is valid |
| `ADAPTIVE_BOTS_LEVEL80` | `AdaptiveAI.Bots.Nivel80` | (empty; here 30 per class) | Connected level-80 bots kept per class: if missing, one free bot is leveled every 10 s (up to three if 40 or more are missing: the wave of disconnections after a restart) with playerbots' factory, starting with the class that lacks the most (playerbots rotates the leveled ones out: without quick replenishment they stayed at 3-10 per class). It is the real cap of 1v1 arenas |
| `ADAPTIVE_ARENA_PAIRS` | `AdaptiveAI.Arena.Pares` | warrior:mage,... (on this server: the 45 class pairings and random teams of 2, 3 and 5) | Compositions: teams with `+`, `*` = any enabled class; `warrior.arms:mage.frost` |
| `ADAPTIVE_BG_ENABLE` | `AdaptiveAI.Bg.Enable` | false | Automatic training battlegrounds; by hand always (`.adaptive bg lanzar`) |
| `ADAPTIVE_BG_MAPS` | `AdaptiveAI.Bg.Mapas` | WS,AB,EY (here only `WS` for now) | WS, AB, EY, AV, SA, IC, in rotation |
| `ADAPTIVE_BG_EVERY_MINUTES` | `AdaptiveAI.Bg.CadaMinutos` | 30 | |
| `ADAPTIVE_BG_PLAYERS` | `AdaptiveAI.Bg.PorEquipo` | 0 | Bots per side; 0 = the battleground's minimum (WS 10, AB 15, EY 15, AV 40, SA 15, IC 20) |
| `ADAPTIVE_IMPORTAR_ENTRENADO` | — | true (here **false**) | Phase 5: import `data/entrenado/adaptive_entrenado.sql` or `.sql.gz` (asks if there is a terminal). It does not overwrite a database with more training. In this repository the file is named `.sql.gz.old` (trained with the skewed reward of 04/09) and is not imported |
| `ADAPTIVE_ARENA_MODE` | `AdaptiveAI.Arena.Modo` | mixed | train, contrast, mixed (on this server: contrast) |
| `ADAPTIVE_ARENA_REFERENCE` | `AdaptiveAI.Arena.Referencia` | 20 | % of automatic matches stock against stock: the baseline with which `.adaptive` and the report compare the contrast. With 10 it gave ten matches per pairing (2026-09-04) |
| `ADAPTIVE_ARENA_YIELD` | `AdaptiveAI.Arena.CederAJugadores` | true | Do not launch while a player is in a PvP queue |
| `ADAPTIVE_ARENA_MAP` | `AdaptiveAI.Arena.Mapa` | 559 | 559 Nagrand, 562 Blade's Edge, 572 Ruins of Lordaeron, 617 Dalaran, 618 Ring of Valor, 0 random |
| `ADAPTIVE_ARENA_PREP_SECONDS` | `AdaptiveAI.Arena.PreparacionSegundos` | 15 | Arena countdown |
| `ADAPTIVE_ARENA_LEVEL` | `AdaptiveAI.Arena.Nivel` | 80 | Bots' minimum level |
| `ADAPTIVE_ARENA_GEAR_SCORE` | `AdaptiveAI.Arena.NivelObjeto` | 264 | Gear is equalized to that item level (264 = Wrathful Gladiator; with a PvP spec the factory picks resilience; 0 = do not touch) |
| `ADAPTIVE_ARENA_SPECS` | `AdaptiveAI.Arena.Specs` | (empty; here arms/frost/subtlety/unholy/affli/mm/cat/ret/shadow/ele pvp) | playerbots premade spec per class when entering arena or reaching 80 (since 2026-09-03) |
| `ADAPTIVE_OBJECTIVES` | `AdaptiveAI.Objetivos` | (empty; here the corrected matrix from `REFERENCES.md`) | `a:b=%`: what a is expected to win against b. It is shown next to the contrast |
| `ADAPTIVE_LOADOUT_ENABLE` | `AdaptiveAI.Loadout.Enable` | true | Dual spec (0 PvE, 1 PvP) on all level 40+ bots and gear regenerated by purpose (since 2026-09-03, `CHANGELOG.md` annex A1 §16.17) |
| `ADAPTIVE_LOADOUT_PVP_ILVL` | `AdaptiveAI.Loadout.EquipoPvP` | 0:232,1600:251,1800:264,2200:270 | PvP gear by the bot's Elo rating |
| `ADAPTIVE_LOADOUT_CAP_LEVELS` | `AdaptiveAI.Loadout.NivelesTope` | 60,70,80 | Stage cap levels (2026-09-03): in the world PvE gear is normal and only at these levels is it normal to see PvP. A bot below the cap that shows up in the world with resilience (it leaves a battleground or a duel, or logs in like that) is regeared PvE for its level, so that whoever is leveling does not run into a bot with a PvP advantage |
| `ADAPTIVE_LOADOUT_PVE_ILVL` | `AdaptiveAI.Loadout.EquipoPvE` | normal:187,heroica:200,banda10:219,banda25:232,mundo:0 | PvE gear by content when the bot goes without a player (with a player, mod-queue-bots rules) |
| `ADAPTIVE_OBJECTIVES_STOP` | `AdaptiveAI.Objetivos.Parar` | true | The automatic mode stops launching a 1v1 when it reaches its target (minus `.Margen`, 5) in both orientations with `.PartidasMinimas` (200) each |
| `ADAPTIVE_CALIBRATE_MINUTES` | `AdaptiveAI.Calibrar.CadaMinutos` | 60 | 0 = only with `.adaptive calibrar` |
| `ADAPTIVE_CALIBRATE_MATCHES` | `AdaptiveAI.Calibrar.Combates` | 100 | |
| `ADAPTIVE_CALIBRATE_MARGIN` | `AdaptiveAI.Calibrar.MargenMinimo` | 0.55 | Win rate to validate the candidate |
| `ADAPTIVE_CALIBRATE_PER_CLASS` | `AdaptiveAI.Calibrar.PorClase` | true | Pass per class (2026-09-03): each class is compared with itself (what it wins with the candidate against what it wins with the validated one in the same pairings) and passes if it improves by `MejoraPorClase` points or already wins 90 % without worsening (saturated); it moves to the validated one by itself even if the global average does not reach it; a passed class leaves its arenas to the failed ones (in a 1v1 with one of each, the failed one learns; in the exam the sides alternate as always, because otherwise the failed one was measured as a candidate against the passed ones and as validated only against failed ones, 2026-09-04); when all pass, a new round |
| `ADAPTIVE_CALIBRATE_PER_CLASS_MATCHES` | `AdaptiveAI.Calibrar.PartidasPorClase` | 60 | Matches per class and side to decide the pass. An hour of exam leaves 150-200 |
| `ADAPTIVE_CALIBRATE_TYPES` | `AdaptiveAI.Calibrar.Tipos` | 1c1 | Sizes that enter the exam (2026-09-03, user's decision). Duels only: the pass is per class and in a 5v5 the result cannot be attributed to anyone. The team is still measured with the automatic mode's contrast matches, which appear in the report |
| `ADAPTIVE_CALIBRATE_MAX_MINUTES` | `AdaptiveAI.Calibrar.MinutosMaximos` | 60 | How long an exam lasts; when reached it concludes with what it has measured. With `CadaMinutos` at 60 the cycle is an hour training and an hour measuring |
| `ADAPTIVE_CALIBRATE_EXCLUSIVE` | `AdaptiveAI.Calibrar.Exclusiva` | true | During the exam the automatic mode launches no training or battlegrounds: all arenas measure. An hour like that leaves 150-200 matches per class and side, against the 18 of sharing arenas |
| `ADAPTIVE_CALIBRATE_CLOCK` | `AdaptiveAI.Calibrar.Reloj` | true | The exam follows the system clock (2026-09-04): the day is split into periods of `CadaMinutos` + `MinutosMaximos` from local midnight and the last `MinutosMaximos` of each are exam (with 60 and 60: 01:00 to 02:00, 03:00 to 04:00...). A restart in the middle of a window resumes the exam if at least a third remains; on shutdown, an exam with half a window done concludes with what it has. Before, the timer started from zero with every restart and a day with seven restarts was left without an exam. false = timer from start-up |
| `ADAPTIVE_CALIBRATE_CLASS_GAIN` | `AdaptiveAI.Calibrar.MejoraPorClase` | 5 | Points the class has to win with the candidate above what it wins with the validated one |
| `ADAPTIVE_CALIBRATE_MAX_CYCLES` | `AdaptiveAI.Calibrar.CiclosMaximos` | 6 | **Judged** exams in a row without passing after which a class that does not improve goes back to the previous one (its candidate rows become those of the validated one); if it was improving without reaching the margin, it continues; if the validated one has no rows of its own, it keeps its own. 0 = never. It was at 0 on the morning of 2026-09-04 (with 3 and the biased exam five classes were wiped) and went back to 6 that afternoon with the guard |
| `ADAPTIVE_CALIBRATE_SAME_RIVAL` | `AdaptiveAI.Calibrar.MismoRival` | true | The exam plays a third arm (validated against validated) and each class's "with the validated" score comes only from there, against the same rival as the "with the candidate" score (2026-09-05). It costs 50 % more matches per pairing |
| `ADAPTIVE_CALIBRATE_Z` | `AdaptiveAI.Calibrar.Z` | 1.64 | The pass also demands Z times the standard error of the difference of the two percentages (2026-09-05). 0 = only `ADAPTIVE_CALIBRATE_CLASS_GAIN` |
| `ADAPTIVE_CALIBRATE_LADDER_RULE` | `AdaptiveAI.Calibrar.VaraSerie` | false | The series as the sole yardstick: the class whose unexplored candidate rung exceeds the current best rung with margin Z passes. false = it is only traced in the log next to today's verdict (2026-09-05, stable version) |
| `ADAPTIVE_ARENA_PROBE` | `AdaptiveAI.Arena.EscaleraCandidata` | 10 | % of automatic "probe" matches: the unexplored candidate against stock playerbots, its rung on the ladder |
| `ADAPTIVE_LADDER_SINCE` | `AdaptiveAI.Escalera.DesdeUnix` | 1788629327 | Measurement cut-off: 2026-09-05 19:28:47 Madrid. It excludes earlier results and inherited snapshots; it keeps Q and matches. Update after changing behavior or cleaning Q; 0 = history. It requires a restart when changed to immediately invalidate the in-memory snapshot |
| `ADAPTIVE_AUDIT_CLASSES` | `AdaptiveAI.Log.AuditarClases` | empty | Captures the first active sessions of a candidate 1v1 that learns, per class (e.g. `warlock,druid`). Empty turns off new captures |
| `ADAPTIVE_AUDIT_SESSIONS` | `AdaptiveAI.Log.AuditarSesiones` | 3 | Quota per class, from 1 to 20. It lives in memory: turn off after collecting the sample and before another restart. Each session also has a limit of 4000 events |
| `ADAPTIVE_DECISION_MIN_VISITS` | `AdaptiveAI.Decision.VisitasMinimas` | 5 | Without learning, only actions with at least these visits are chosen; if none reaches it, `none`. And with the class's table empty, the bot plays stock instead of with its personality (2026-09-05, N1 and N4) |
| `ADAPTIVE_DECISION_REJECT_LEARNS` | `AdaptiveAI.Decision.RechazoAprende` | false | Whether the action that playerbots rejects learns "best Q − 1" (the pre-2026-09-05 behavior) |
| `ADAPTIVE_ARENA_APPROVED_LEARN` | `AdaptiveAI.Arena.AprobadasEntrenan` | true | Passed classes keep learning in 1v1 during the round (before, they played stock until it closed) |
| `ADAPTIVE_ARENA_APPROVED_MODEL` | `AdaptiveAI.Arena.AprobadaConModelo` | 50 | % of contrast matches in which the passed class on the non-adaptive side carries its validated model instead of playing stock |
| `ADAPTIVE_CALIBRATE_ALL_PLAY` | `AdaptiveAI.Calibrar.TodasJuegan` | true | In the exam, the passed ones and those that already reached the cap keep playing like the rest; no pairing stops launching (2026-09-05) |
| `ADAPTIVE_ARENA_GENERATIONS` | `AdaptiveAI.Arena.Generaciones` | 15 | % of automatic matches against a previous generation (a version that was validated, at random) instead of against playerbots: variety, so it does not stagnate |
| `ADAPTIVE_GENERATIONS_KEEP` | `AdaptiveAI.Generaciones.Guardar` | 5 | Generations that are kept (the most recent) |
| `ADAPTIVE_GENERALIZE` | `AdaptiveAI.Generalizar` | true | "Against any rival" row (enemy class 0) learned at the same time that serves as the starting point for what has not been tried against a specific rival: each class learns from its nine pairings at once |
| `ADAPTIVE_EPSILON` | `AdaptiveAI.Epsilon` | 0.05 | Random exploration. The one that matters is the directed one, `AdaptiveAI.Exploracion.Bonus` (only in the `.conf`) |
| `ADAPTIVE_DIFFICULTY_DEFAULT` | `AdaptiveAI.Dificultad.PorDefecto` | 3 | 1 Novice .. 6 Elite; only in real combats |
| `ADAPTIVE_LOG_DECISIONS` | `AdaptiveAI.Log.Decisiones` | false | Every decision in `adaptive_experience` (it grows fast) |
| `ADAPTIVE_CALIBRATE_CUT_WHEN_JUDGED` | `AdaptiveAI.Calibrar.CortarAlJuzgar` | true | The exam is cut as soon as all the classes being judged already have `PartidasPorClase` matches per side, and the rest of the window goes back to training |
| `ADAPTIVE_CALIBRATE_CUT_MATCHES` | `AdaptiveAI.Calibrar.PartidasCorte` | 0 | Matches per side for that cut (0 = the same as `PartidasPorClase`). Raising it makes the verdict less noisy at the cost of less training |
| `ADAPTIVE_WARLOCK_PVP_PET` | `AdaptiveAI.Brujo.MascotaPvP` | felhunter | Pet the module guarantees the warlock in PvP. While combat lasts it turns off playerbots' five pet strategies, which were what made it resummon the demon non-stop |
| `ADAPTIVE_LOG_AURAS` | `AdaptiveAI.Log.Auras` | false | Diagnostics: writes to the log every control or snare that is **collected**, with the spell and whether it lands on a player or not. Useful to catch collections that do not land on the rival. Noisy: switched on and off with `reload config`, without restarting |
| `ADAPTIVE_LOG_MATCH_DAYS` | `AdaptiveAI.Log.PartidasDias` | 30 | Deletes matches older than N days at start-up and once a day (0 = never). What was learned is not touched |

Only in the `.conf`: `AdaptiveAI.Trazas.GM` (traces to GMs with `.gm on`, default
1); those of the phase 1b learning (2026-09-03, `CHANGELOG.md` annex A1 §16.14):
`AdaptiveAI.Exploracion.Bonus` (3.0, optimism: what has not been tried is worth the
state's best Q plus the bonus; what has been little tried, bonus/√visits), `.Alpha`
(0.10, minimum step), `.Alpha.Decreciente` (1: step max(Alpha, 1/(visits+1))),
`.Gamma` (0.90), `.Retorno.Peso` (0.5: Monte Carlo return of the match to all its
decisions), `.Interrupcion.SoloCasteando` (1), `.Kitear.Distancia` (20) and
`.Kitear.Ms` (3000), `.Recompensa.Distancia` (0.3 per decision: ranged casters at
a distance, melee stuck close), `.Recompensa.KillEquipo` (10), `.MuerteAliado`
(-10), `.Objetivo` (15), `.ObjetivoEquipo` (5), `.Bg.Simultaneos`, `.Bg.Nivel`,
`.Bg.DuracionMaxMinutos`, `.Bg.EsperaSegundos`, `.Bg.Modo`, `.Exportar.Fichero`;
and `.Decision.*`, `.Dificultad.1..6`, `.Brackets`, `.Personalidad.Peso`,
`.Recompensa.*`, `.Arena.EsperaSegundos`, `.Arena.DuracionMaxSegundos`,
`.Log.Partidas`.


---

## Part 3 — What each phase does, and why

The scripts `scripts/phases/01_dependencies.sh` … `08_post_install.sh` are the
source of truth: what follows explains **what each one achieves and why it is built
that way**, with the traps that cost time. To do it by hand it is enough to read the
phase's script; to understand a decision, this part.

### The VM and the system (phase 1)

These are the values of the test VM (Proxmox, Ubuntu Server 24.04 LTS, OpenSSH
enabled). They are not requirements: on another hypervisor or on a physical machine
the equivalents work.

| Parameter | Value | Why |
|---|---|---|
| CPU | 8 cores, type **`host`** | Without `host` the guest does not see the CPU's native instructions and the build takes much longer |
| RAM | 16 GB, **no ballooning** | With 500 bots the worldserver hovers around 5-6 GB; ballooning takes memory away exactly when it needs it |
| Disk | 120 GB, `raw`, on `local-lvm` | |
| Network | VirtIO, bridge `vmbr0` | |

The phase installs the compiler (clang), CMake, Boost, OpenSSL, readline, ncurses,
`screen` and `unzip`, and sets the **time zone** (`TIMEZONE` in `config.sh`; today
`Europe/Madrid`). The time zone matters more than it seems: the `mod-adaptive-ai`
tables store local `DATETIME`s and the reports filter by date, so changing it
afterwards forces you to correct the rows already written.

It also disables automatic package updates
(`/etc/apt/apt.conf.d/20auto-upgrades`): an `unattended-upgrade` of MySQL with the
server running takes it down.

### MySQL (phase 2)

MySQL **8.4 LTS** from the official repository (`mysql-apt-config`), not Ubuntu's
`mysql-server`.

User `acore` on `localhost` **and** on `127.0.0.1` — the core connects over TCP and
MySQL treats the two as different accounts — with permissions restricted to
`acore\_%` and `GRANT PROCESS`. The recipe that circulates on the internet is
`GRANT ALL ON *.* WITH GRANT OPTION`: that gives the game's user write access to
`mysql.user`, so whoever extracts the password from a `.conf` takes the entire MySQL
server and not just the game's.

`mysqld.cnf` settings that the phase writes, essential with many bots:

```ini
skip-log-bin                       # without replication, the binlog only writes disk (-75/90 %)
innodb_buffer_pool_size = 4G       # ~50 % of the VM's RAM
innodb_io_capacity      = 500
innodb_io_capacity_max  = 2500
transaction_isolation   = READ-COMMITTED
```

Databases: `acore_auth`, `acore_world`, `acore_characters` and `acore_playerbots`
(the latter is used by mod-playerbots for its own tables; those of `mod-adaptive-ai`
live there too).

### The code and the modules (phase 3)

**The core is the mod-playerbots fork**, `Playerbot` branch, not the official
AzerothCore: playerbots needs changes in the core that do not fit in a module. This
is irreversible without reinstalling: adding or removing playerbots forces you to
repeat from phase 3.

The phase clones the core and the 19 third-party modules **at the exact commit**
that `versions.lock` says, or from `mirrors/` if the offline copies are there; copies
our own modules from `modules/` into the core's `modules/` together with the shared
headers of `modules/shared/`; and applies the patches from `patches/`. A module with
its `INSTALL_MOD_*` at `false` is set aside into `modules-disabled/`, without deleting
it: turning it back on is changing the key and recompiling.

When a patch stops applying, the phase warns and continues: the module keeps its
original behavior. What to do then, in "Writing a patch on third-party code"
(REFERENCES.md).

### Compile (phase 4)

```
cmake -DCMAKE_INSTALL_PREFIX=env/dist -DCMAKE_C_COMPILER=clang
      -DCMAKE_CXX_COMPILER=clang++ -DWITH_WARNINGS=1 -DTOOLS_BUILD=all
      -DSCRIPTS=static -DMODULES=static
make -j$(nproc - 1) && make install
```

One core fewer than available, so the VM keeps responding. CMake detects by itself
everything in `modules/`; its output shows the `Modules configuration (static)` list,
which is the quick way to check that a new module came in. ~22 minutes with 7 cores
on the test machine; the incremental recompilation after touching one of our own
modules, about 2 minutes.

### Configure (phase 5)

The phase copies each `.conf.dist` to its `.conf` and **writes the values of
`config.sh` on top**, with `set_conf_value`. That is why nothing is edited by hand on
the server. It also applies our own SQL from `patches/`, always idempotent.

Two things discovered the hard way that the installer already watches for:

- **Ghost keys.** Writing a key that the module does not read gives no error: simply
  nothing happens. `set_conf_value` warns about any key that is not declared in the
  corresponding `.dist`. That is how `MapUpdateThreadCount` appeared (the right one is
  `MapUpdate.Threads`, and the server ran for months with a single thread),
  `Transmogrification.Enabled` (it is `Enable`) and `AutoBalance.enable`, which the
  dist now only reads to warn that it is obsolete.
- **Client data has a version.** `Data.zip` (with a capital letter) from
  [wowgaming/client-data](https://github.com/wowgaming/client-data/releases),
  **v20.0** for this core. The installer downloads exactly that version, resumes it if
  the download is cut and checks its SHA-256 before extracting (an interrupted
  extraction is repeated in full). For another version you have to give both
  `AC_DATA_URL` and `AC_DATA_SHA256`. With old mmaps the bots cannot walk and the log
  says so: `mmtile was built with generator v19, expected v20`.

### The systemd services (phase 6)

Two units, `ac-authserver` and `ac-worldserver`, that start with the machine. What is
inside and is not obvious:

- **`ExecStartPre=wait-for-mysql.sh`.** `After=mysql.service` only guarantees that
  MySQL's *unit* started, not that it is accepting connections. Without that wait,
  when the VM restarts the worldserver arrives first and enters a restart loop.
- **`ExecStop=safe-stop.sh`** with `TimeoutStopSec=150`: it warns the players, does
  `saveall` and closes in an orderly way. That is why `systemctl restart
  ac-worldserver` is safe even with someone inside: it warns for 60 seconds.
- **`KillMode=mixed`, never `none`.** With `none`, if the `ExecStop` fails systemd
  kills nothing and orphaned worldservers are left occupying the port on the next
  start. Besides, `none` has been deprecated since systemd 250 and warns about it at
  every start.
- **`Before=`/`Conflicts=shutdown.target` are not declared.** systemd already adds
  them to every normal service; putting them by hand forces `DefaultDependencies=no`
  and that removes the implicit dependencies on `sysinit.target`, so the unit may try
  to start before the base system is ready.
- The worldserver runs inside **`screen`**, so commands can be sent to it with the
  player disconnected: `screen -S worldserver -X stuff "server info$(printf '\r')"`.
  RA stays off on purpose; SOAP is enabled only on `127.0.0.1:7878` when
  `INSTALL_WEB_PANEL=true` (phase 5), because the moderation panel needs it to
  kick/ban/mute an already connected player — see "The web panel" (INSTALL_EN.md,
  part 5).
- A **restricted** `sudoers` rule: `NOPASSWD` only to start and stop the two units
  (and `reboot`), not for all of `sudo`.
- **With `WORLDSERVER_STANDBY=true`** ([part 2 §2 · Standby mode](#standby-mode-shut-down-the-worldserver-when-nobody-is-there))
  the worldserver's service changes: `ac-worldserver.socket` owns 8085 and starts
  `ac-worldserver.service` (direct binary, no `screen`, `Restart=on-failure`) on the
  first connection. Without `screen`, `safe-stop.sh` and `notify-restart.sh` send the
  commands over SOAP (`scripts/ws-console.sh`). `sudoers` adds the three lines for
  `ac-worldserver.socket`.

### Automation (phase 7)

| When | What |
|---|---|
| Daily 00:00 | Server restart, with prior notice to the players (with standby mode: **only if it was awake**; if it was sleeping, it does nothing) |
| Sunday 03:00 | **Check** for new upstream versions (`WEEKLY_UPDATE_MODE="check"`) |
| Daily | Database backup |
| Weekly | `logrotate` of the automation logs |

The weekly check **only warns**: it leaves the result for `.actualizaciones` and for
the GMs' mail. Actually updating is a manual act
([part 4 §3](#3-updating-the-core-and-the-modules)), because with our own patches on
third-party code a blind `git pull` breaks the server while you sleep. Old guides
describe a `weekly-update.sh` that recompiled by itself: that is no longer what this
installer does.

The start after a restart is handled by the enabled systemd units, not by a crontab
`@reboot`: the wait for MySQL lives in `ExecStartPre`, which is its place.

### Post-installation (phase 8)

What needs the databases already populated: realmlist pointing at `REALM_IP`,
`admin`/`admin` account with GM 3 (created with SRP6 from `lib/srp6.py`, without going
through the console), service NPCs in the eleven capitals and our own SQL that depends
on core tables.

### Web panel (phase 9)

It installs a Node.js application in `/opt/azerothcore-panel`, creates a MySQL user
restricted per table (and per column in `account`: it can only create accounts and
change passwords, never touch `gmlevel` or `locked`), a dedicated `acore_panel` database
for invitations and auditing, and a dedicated game account (gmlevel 3) with which the
panel talks to the worldserver's SOAP console to moderate. It stores all the credentials
and the session secret in `/etc/azerothcore-panel.env` with mode `0600`, and publishes
the service through Nginx at `http://REALM_IP`. The login validates the SRP6 verifier of
the game accounts; the online list and the local catalog of 118 addons are private, and
the map and moderation check the GM rank in the backend too. Downloads are generated from
the canonical copy `cliente/Interface/AddOns`, not from the origin repository.

The phase can be repeated with `./install.sh --panel`: it syncs all the changes of
`web-panel/`, keeps the secrets and restarts the service. The continent maps are local
resources at 3840 × 2560, are framed whole and only allow zoom up to their native
resolution. Operational and security detail: "The web panel" (INSTALL_EN.md, part 5).

From the **Addons** section, Chrome or Edge can install the selection into the folder
that contains `Wow.exe` after the player grants permission. Direct writing requires
publishing the panel over HTTPS (or opening it from localhost); when accessing by IP
over HTTP the individual ZIP download is used.

### Known risks

| Risk | Mitigation |
|---|---|
| A new module does not compile against the playerbots fork | Phase 4 fails showing the module's error. Set its `INSTALL_MOD_*` to `false`: phase 3 sets it aside into `modules-disabled/` without deleting it, and you carry on |
| One of our patches stops applying after updating | Phase 3 warns and continues; the module keeps its original behavior. Redoing it: "Writing a patch on third-party code" (REFERENCES.md) |
| `mod-instance-reset` speeds up the loot pace too much | High cost by default; `INSTALL_MOD_INSTANCE_RESET=false` removes it |
| 40 bots in a raid consume CPU | It is a cap, not a reserve: it only weighs when they are summoned |
| individual-progression's DBCs overwrite ARAC's | Solved: `SkillRaceClassInfo.dbc` is excluded when ARAC is active |
| The `admin` account with password `admin` is trivial | Accepted on purpose: local network. Changing it is `.account password` inside the game |
| `mod-dungeon-master` is *early development* | If there are oddities in instances, `INSTALL_MOD_DUNGEON_MASTER=false` and recompile |


---

## Part 4 — Operate

The operations manual for the installed server. Everything here has actually been run
on the reference VM (user `acore`); the dates say when.

### 1. Day to day

```bash
systemctl is-active mysql ac-authserver ac-worldserver
sudo systemctl restart ac-worldserver     # warns players for 60 s, saveall, restarts
sudo systemctl stop ac-worldserver        # same, without starting (takes ~1 min with people inside)
sudo systemctl start ac-authserver ac-worldserver
```

`start`, `stop` and `restart` of the two services, `reboot` and `shutdown` do not
ask for a password; any other `sudo` does.

Logs, in `~/azerothcore/env/dist/bin/`, with time and level on each line:

| File | What |
|---|---|
| `Server.log` | Everything from the core (truncated at every start) |
| `Playerbots.log` | The bots module |
| `Errors.log` | Errors only |
| `~/azerothcore/logs/` | The automation scripts (daily restart, safe shutdown, start) |

The worldserver console (it runs inside `screen`):

```bash
screen -S worldserver -X stuff 'announce Hello everyone
'                                                   # send a command
screen -S worldserver -X hardcopy -h /tmp/ws.txt    # dump the screen to a file
```

The crontab restarts the services at 00:00 (notice at 23:55), checks for new versions
on Sundays at 03:00 (it only warns, by in-game mail) and reboots the VM on Sundays at
05:00. When the machine starts, systemd waits for MySQL to accept connections and
starts the two services.

**Standby mode** (`WORLDSERVER_STANDBY=true`): the worldserver shuts down by itself
after `STANDBY_IDLE_MINUTES` without players and the next connection starts it.

```bash
systemctl is-active ac-worldserver            # 'active' awake, 'inactive' asleep
systemctl status ac-worldserver.socket        # the 8085 socket (always active)
cat /run/azerothcore/worldserver.state         # running | standby | down
sudo systemctl start ac-worldserver           # wake it up by hand
```

In-game / console commands: `.standby` (status), `.standby ahora` (now),
`.standby mantener <min>` (keep), `.standby reanudar` (resume). The daily restart does
nothing if the worldserver is asleep. In the web panel's header: "En vivo" (Live) /
"En espera" (Standby) / "Caído" (Down).

Are there new upstream versions? Without touching anything:

```bash
bash tools/revisar-actualizaciones.sh              # table per repository, and writes the mod-update-notice notice
bash tools/revisar-actualizaciones.sh --log mod-transmog   # the new commits of that repo
```

And from Windows, without entering the VM (it uploads the script and runs it via plink):

```powershell
& "<project>\tools\revisar-actualizaciones.ps1"                  # the table
& "<project>\tools\revisar-actualizaciones.ps1" -SoloNovedades   # only those with new commits
& "<project>\tools\revisar-actualizaciones.ps1" -Log mod-transmog
```

GMs also see it on logging into the game (`mod-update-notice`) and with
`.actualizaciones`.

---

### 2. Backup and restore

Before any operation that touches the databases:

```bash
bash ~/azerothcore-installer/tools/backup-servidor.sh
```

It stops the services with a safe shutdown, dumps the four databases (`acore_auth`,
`acore_characters`, `acore_world`, `acore_playerbots`) compressed, and copies the
`.conf` files, `versions.lock`, `Server.log` and the crontab to `~/backup-<date>/`.
About 115 MB. Then bring it to another machine (§8).

Restoring a database:

```bash
sudo systemctl stop ac-worldserver ac-authserver
zcat ~/backup-<date>/acore_characters.sql.gz | mysql -u acore -pacore acore_characters
sudo systemctl start ac-authserver ac-worldserver
```

Last full copy: **2026-09-01, before the reinstall**, in
`<backups>\backup-pre-reinstalacion-20260901-1841`. It contains `Lightcore` (level 80
paladin, phase 13) and the 1500 previous bots.

---

### 3. Updating the core and the modules

Procedure followed on 2026-09-01, designed to be run by an agent with no manual steps.
The principle: **all the risk is looked at before touching the VM**.

**This same thing applies to the client addons** (added 2026-09-13): before starting,
also review `addons.lock` with `tools/revisar-actualizaciones-addons.sh` (§3.1), not
just `versions.lock`. They are two independent inventories and both can bring news on
the same day. Actually updating an addon follows "Client addon patches" (REFERENCES.md)
(there is a translation of our own to reapply), not the `install.sh --only N` below,
which is only for the server's core/modules. **Careful**: the new commits of an addon
are not just back-and-forth of text strings — they also bring real fixes (real example,
2026-09-13: QuestRadar brought "Carry three Minimap.lua fixes into the server-module
variant"). Point 4 below ("review the new code itself") applies equally to an addon and
to a server module: it is not enough to reapply the translation and assume the rest is
cosmetic.

**Fixed order** (added 2026-09-11, after reviewing core + mod-playerbots +
mod-dungeon-clear the same day; extended the same day with point 3b after a warning from
the user: the first pass only looked at whether something broke, not at whether something
new was useful):

1. Review the new changes (§3.1: `tools/revisar-actualizaciones.sh`).
2. Check whether they affect our own modules, patches and scripts (§3.2).
3. If they do, measure the scope and whether it is safe to apply fixes and integrations
   (patches that stop applying, symbols whose signature changes, config keys that
   disappear: it is not "yes/no update", it is "what has to be touched for it to keep
   lining up").
3b. **Opportunity, not just risk.** "It breaks nothing" is not the whole question. For
    each commit/feature with real weight (not a `chore(DB)` or a typo) ask: does this
    already do, out of the box, something we solved by hand with a patch or a module of
    our own? A new opt-in feature with no compile conflict **is not "no impact"** just
    because it comes off by default: if it treads on the ground of our `patches/` or
    `modules/` you have to read it whole (not just the commit title) and actively decide
    whether it simplifies, replaces or complements what already exists — and leave the
    decision (and the reason) in writing in the CHANGELOG, even if it is "left as is
    because...". Real example: mod-playerbots brought
    `Playerbots.RandomBotConcentrateInPlayerZone`, which concentrates bots by zone around
    the player — same spirit as our `01-highest-player-bracket.patch` (which concentrates
    by level), different axes and no code conflict, but exactly the kind of novelty that
    deserves its own review and not just a "compiles, breaks nothing, carry on".
3c. **Every candidate/proposal goes into the project's work plan, not just the
    CHANGELOG.** What comes out of point 3b as "worth trying later" (not applied now, but
    not discarded) is recorded right there, in the same review pass — not left merely
    mentioned in passing in the conversation or buried in an old CHANGELOG commit. The
    CHANGELOG tells what was done; the work plan tells what remains to be decided or tried.
3d. **New commands → `modules/mod-server-help` and the panel.** If any of the updated
    repos brings a new chat command (`.something`), even an administrator one: the module
    discovers the command by itself (it reads the core's real tree), but the Spanish entry
    (`server_help_command`: title, description, syntax, examples) does not appear by
    itself — it has to be registered by hand in
    `modules/mod-server-help/data/sql/db-world/base/server_help.sql` (or the corresponding
    own SQL). And if the web panel documents commands (`web-panel/`), there too. Checking
    this is part of the review in point 2, not a separate step that can be skipped.
4. Review the new code itself (what each commit really brings, not just the
   `diff --stat`).
5. Deploy (§3.3) and check that all is well (`verificar-instalacion.sh`, and in game
   whatever applies according to what changed).
6. Commit and push the updated `versions.lock` and whatever had to be touched in our
   `patches/`/`modules/` (and in the work plan, `mod-server-help` and the panel, if point
   3c or 3d applied).

#### 3.1 Inventory: what has really changed

From any machine with git, without touching the server:

```bash
grep -v '^#' versions.lock | while IFS=$'\t' read -r name branch commit date url; do
  head=$(git ls-remote --heads "$url" "$branch" | cut -f1)
  [ "$head" = "$commit" ] && echo "$name  up to date" || echo "$name  NEW  ${commit:0:10} -> ${head:0:10}"
done
```

It is what `tools/revisar-actualizaciones.sh` (server modules, against `versions.lock`)
and `tools/revisar-actualizaciones-addons.sh` (third-party client addons, against
`addons.lock`) do, touching nothing. **Both `.lock` files count**: an addon with news is
updated according to "Client addon patches" (REFERENCES.md) (there is a translation of
our own to reapply).

On 2026-09-01 only 4 of 19 had changes. Do not assume that "updating" means 20
repositories (they are 20 since 2026-09-02, with `mod-dungeon-clear`; that is the most
fragile in the face of a playerbots update, because it accesses private internals of it:
if it stops compiling, `INSTALL_MOD_DUNGEON_CLEAR=false`).

#### 3.2 Prior review, locally

Clone the repos that change (`git clone --filter=blob:none`) and check, in this order:

1. **Patches** (`patches/*/*.patch`): if the patched module has not changed, the patch
   applies just the same. If it has changed, `git apply --check` on the new tree. The one
   for `mod-challenge-modes` depends on the **core**: check that `OnPlayerResurrect` still
   takes `bool&` in `PlayerScript.h`.
2. **Configuration keys**: every `Playerbots.*` / module key that `05_configure_server.sh`
   writes has to exist in the new `.conf.dist` **and in the code**.
   `git diff <old>..<new> -- conf/*.conf.dist | grep '^-'` shows the removed ones.
3. **Own modules** (`modules/`): the playerbots symbols they use (`IsTank`, `IsHeal`,
   `ResetStrategies`, `AddPlayerBot`, `LogoutPlayerBot`, `IsRandomBot`) with the same
   signature in the new version.
4. **Own SQL**: ids used by the module's new SQL against those of `patches/locales-es/`
   (transmog uses 81-88; ours are 18 and 19).
5. **Client data**: `grep -c 'expected v' Server.log` after starting. If the core demands
   a new version of mmaps, look for a release in `wowgaming/client-data` (§6.3).

#### 3.3 Apply

In the installer repo, point `versions.lock` at the new commits and upload it to the VM
with `pscp` (the VM is not a git clone; `md5sum` on both sides). And on the VM, in this
order:

```bash
bash tools/backup-servidor.sh
sudo systemctl stop ac-worldserver          # one unit per command: the
sudo systemctl stop ac-worldserver.socket   # NOPASSWD sudoers is per unit,
sudo systemctl stop ac-authserver           # two at once ask for a password
./install.sh --only 3          # clones/pins versions and reapplies patches
./install.sh --only 4          # recompiles the whole modules target
./install.sh --only 5          # confs + own SQL; LOOK at the summary of undeclared keys
sudo systemctl start ac-authserver
sudo systemctl start ac-worldserver.socket
sudo systemctl start ac-worldserver
bash tools/verificar-instalacion.sh
```

Details that cost a failed attempt if you do not know them:

- **Over SSH without a terminal** (`plink`/`ssh ... "..."`): `install.sh` uses `tput`, so
  you need `export TERM=xterm-256color` first, and answer the confirmation prompt with
  `echo s | ./install.sh --only N`.
- **With `WORLDSERVER_STANDBY=true`** (the normal case): if nobody is playing, the
  worldserver is already stopped. You also have to stop `ac-worldserver.socket`, or a
  client connection would start the old binary in the middle of a build; and start it
  again afterwards. The 60 s notice and the `saveall` go over SOAP
  (`~/azerothcore/scripts/ws-console.sh`), not through `screen`.
- **`--only 4`** recompiles the whole `modules` target both when adding a module and when
  updating an existing one (mod-playerbots included). With ccache and a single module
  touched it is ~3 min; without cache, ~25.
- **`--only 5`**: the three "NOT declared" warnings for `HomeGuild.*` are known (own keys
  of `mod-home-guild`, §3.10) and do not count.
- **After the first start with an updated module**: if the module's SQL re-runs it can delete rows from
  `patches/locales-es/` that phase 5 applied earlier (it happened with `mod-transmog` on 2026-10-12).
  `./install.sh --doctor` reports it (`traducciones-es`); fix it with
  `bash scripts/reaplicar-traducciones.sh` (idempotent, touches nothing else).

If all goes well: `./install.sh --mirror` and bring `mirrors/` to the repo (§8).

**Going back**: recover the previous `versions.lock` from git history and repeat phases 3
to 5. Database migrations are **not** undone: that is why the backup comes first.

#### 3.4 When to do a clean install instead of updating

When there are doubts that the accumulated state (DBCs patched on top of others, keys
stuck at the end of the `.conf` files, bot tables from three versions) is what produces a
problem. On 2026-09-01 a clean install was chosen precisely to prove that the installer
works end to end. It costs ~45 minutes more than updating and takes the characters with
it: backup first.

---
### 4. Clean install

> **Shortcut**: `bash install.sh --guiado` (or `bash scripts/instalar-todo.sh` in
> manual mode) does everything in this section and the next (phases 1-7, first start,
> `--post`, services, verification) without asking anything but the sudo password once.
> What follows is the detail.

With the backup done:

```bash
sudo systemctl stop ac-worldserver ac-authserver
for db in acore_auth acore_characters acore_world acore_playerbots; do
    sudo mysql -e "DROP DATABASE IF EXISTS \`$db\`"; done
rm -rf ~/azerothcore
```

Phases 1, 2, 6 and 7 use `sudo` for apt, MySQL and systemd. For the installer to run
unattended a temporary file is needed in `/etc/sudoers.d/`, **written like this and only
like this**:

```bash
echo "$PASS" | sudo -S bash -c "printf '%s\n' 'acore ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-temporal && chmod 440 /etc/sudoers.d/99-temporal"
sudo visudo -c -f /etc/sudoers.d/99-temporal        # it has to say "parsed OK"
```

> ⚠️ `echo "$PASS" | sudo -S tee /etc/sudoers.d/f` is **not valid**: `tee` receives the
> password on stdin, not the content, and the file ends up empty. It worked for a few
> minutes thanks to sudo's credential cache and then took down phase 1.

Launch unattended (the installer uses `tput`: without `TERM` it aborts on the first line):

```bash
cd ~/azerothcore-installer
export TERM=xterm-256color
setsid bash -c "echo s | ./install.sh > ~/instalacion.log 2>&1" < /dev/null &
```

Phases and times of 2026-09-01 on the test machine (Ryzen 7 7730U, 7 cores): cloning ~5
min, compilation ~22 min, client data 1.2 GB at 11 MB/s ~2 min; **34m 34s** in total.
When it finishes, **remove the temporary sudoers**:

```bash
sudo rm /etc/sudoers.d/99-temporal
```

Then the first start (§5) and `./install.sh --post`.

---

### 5. First start

It creates the databases. The updater asks `Do you want to create it?` for each one,
and you have to answer `yes`. `tools/primer-arranque.sh` does it by itself: it starts the
worldserver with a named pipe as stdin, sends it six `yes`, waits for it to listen on port
8085 and shuts it down cleanly.

Two things you need to know, both learned on 2026-09-01:

**"World initialized" no longer appears in the log.** In this core it only exists as a
metrics event (`World.cpp`, `METRIC_EVENT`). Any wait with `grep 'World initialized'`
never fires. The reliable signal is `ss -ltn | grep ':8085 '`.

**It can hang while creating the bot accounts.** Symptom: `Playerbots.log` ends at
`Waiting for 150 accounts loading into database (303 queries)...`, the process at 1-2 %
CPU, all MySQL connections in `Sleep`, and `SELECT COUNT(*) FROM acore_auth.account` = 0
for minutes. The module waits for the `acore_auth` pool's asynchronous queue to drain
(`RandomPlayerbotFactory.cpp`, `while (LoginDatabase.QueueSize())`) and the queue does
not move. It coincided with InnoDB warnings (`unable to reserve space in redo log`) during
the import of the 447 MB of the world. **It is not deterministic**: `pkill -TERM
worldserver` and starting again created the 150 accounts and the 1500 characters in 24
seconds.

After the first start, `--post` creates the `admin` account, writes the realmlist, places
the NPCs and applies the SQL that phase 5 could not apply because the databases did not
exist.

---

### 6. Diagnostics: where to look when something fails

#### 6.1 A `config.sh` option does nothing

First the phase 5 summary: if it says `Key 'X' NOT declared`, almost certainly `X` does not
exist with that name. Check against the `.conf.dist` **and** against the code:

```bash
grep -rn '"KeyName"' ~/azerothcore/src/server/game/World/WorldConfig.cpp   # core
grep -rn '"KeyName"' ~/azerothcore/modules/<module>/src/                    # module
```

If the code does not read it, it does not read it. The *deprecated* section of
autobalance's `.conf.dist` is a trap: the keys are declared but only to warn.

And on the running server, keys stuck at the end of the `.conf` (after the dist's last
block) are the suspects:

```bash
tail -5 ~/azerothcore/env/dist/etc/worldserver.conf
```

#### 6.2 The server starts but runs slowly

`ps -o nlwp,pcpu -C worldserver`: with `MapUpdate.Threads = 4` there are 15 threads. If
there are 12 and the CPU is at 90-100 %, there is only one map thread. See §6.1.

#### 6.3 Bots do not move / mmaps errors

```bash
grep -c 'expected v' ~/azerothcore/env/dist/bin/Server.log
```

If there are `mmtile was built with generator vN, expected vM` lines, the client data is
old for this core. Releases at
`https://api.github.com/repos/wowgaming/client-data/releases` (the asset is called
`Data.zip`, with a capital letter). Delete `maps vmaps mmaps dbc cameras` and
`data-version` from `env/dist/bin/`, and `./install.sh --only 5` downloads them again.
Maps and vmaps do not complain; only the mmaps do, and only in `Server.log`.

#### 6.4 A patch stops applying

Phase 3 says so and carries on: the module is left without the change. Regenerate it
following "Writing a patch on third-party code" (REFERENCES.md). If the patch also touches
a `.conf.dist` (random-enchants), the module has to be returned to clean before reapplying:
`git -C ~/azerothcore/modules/<module> checkout -- . && bash lib/reapply-patches.sh`.

#### 6.5 A module does not compile against the core

Set its `INSTALL_MOD_*` to `false`: phase 3 sets it aside into `modules-disabled/` and you
carry on. If the error is a hook signature (`non-virtual member function marked 'override'
hides virtual member function`), it is a two-line patch: see the one for `mod-challenge-modes`
in `patches/`.

#### 6.6 `.learn` does not work

Pending diagnosis. Since 2026-09-01 the logs carry a time: run the `.learn` that fails and
`grep -a "$(date +%Y-%m-%d)" Errors.log | tail`.

---

### 7. Test suite

#### 7.1 From the server (automatic)

```bash
bash ~/azerothcore-installer/tools/verificar-instalacion.sh
```

It checks the 20 commits against `versions.lock`, the keys that were broken
(`MapUpdate.Threads`, `AllowTwoSide.Interaction.Chat/Channel/Auction`), that no ghost key
remains, `LevelBrackets`, the own modules (folder, `.conf` and last log line of each), the
undeclared-key warnings of the last `--only 5`, the compiled modules, the patches and the
services. **Passed on 2026-09-01** after the clean install, and again on **2026-09-23**
after the reinstall from scratch (full purge + `instalar-todo.sh`).

In addition, with the server started: 0 mmaps errors in `Server.log`, 150 accounts and 1500
bot characters, `admin` with GM 3, realmlist at `192.168.1.100:8085`, 15 threads in the
worldserver.

#### 7.2 Inside the game

They need the client and are done by the player. The historical battery —what to do, what
to see and which log line confirms it for each test— is kept in `CHANGELOG.md` (battery
retired on 2026-09-10). There are no scheduled pending tests; any new verification must be
recorded beforehand in the work plan.

---

### 8. Operating from Windows

The VM is **not** a clone of the repository: the installer's changes are uploaded with
`pscp` and run with `plink` (PuTTY). What has worked well:

```powershell
# upload a file (absolute path at the destination: pscp does not expand ~)
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw <pass> config.sh acore@192.168.1.100:/home/acore/azerothcore-installer/config.sh

# run a script (upload it first; quotes inside a -c are lost)
& "C:\Program Files\PuTTY\plink.exe" -batch -ssh acore@192.168.1.100 -pw <pass> "bash /home/acore/script.sh"

# fetch a folder (backup, mirrors)
& "C:\Program Files\PuTTY\pscp.exe" -batch -r -pw <pass> acore@192.168.1.100:/home/acore/backup-2026... "<backups>\"
```

Always verify with `md5sum` on both sides after uploading, and upload in LF (`bash` does
not swallow CRLF).

Repo tools designed for this, in `tools/`:

| Script | What it does |
|---|---|
| `backup-servidor.sh` | Safe shutdown + dump of the 4 databases + confs + logs |
| `primer-arranque.sh` | Unattended first start (answers `yes`, waits for 8085, shuts down) |
| `verificar-instalacion.sh` | The automatic battery of §7.1 |
| `cliente-sintetico/verificar.py` | Interface-less WoW client that enters the game and checks what used to require playing: a catalog of cases (`listar`, `describir`, `ejecutar`, `limpiar`) with ARAC, IP + Chronicler, bots, own modules, party-here, finder with queue-bots and a whole dungeon with the player as selfbot and anomaly telemetry. `VERIFICADOR` account; see "The synthetic verifier" (REFERENCES.md) |
| `comprobar-modelos-cliente.py` | Why an item looks like a cube (art missing in the client) |
| `revisar-actualizaciones.ps1` / `.sh` | Are there new upstream commits? Table per repository against `versions.lock` (`git fetch` only) and the mod-update-notice notice. The `.ps1` uploads it to the VM and runs it from Windows: `-SoloNovedades`, `-SinFichero`, `-Log <repo>` |

---

## Part 5 — The player's PC and the web panel

What is not installed on the server: the WoW client files that have to be copied onto every
PC that plays, and the web panel, which runs on the server but is used from the browser.

### The client (`cliente/`)

The server cannot put anything into the client by itself: WoW 3.3.5a does not download
patches or addons from a private server. This folder gathers **everything that has to be
copied onto every PC that plays**, with the same structure as the game folder, so that
installing it is copying two folders on top (or running the script) and so that it can
one day be automated from a launcher.

```
cliente/
├── Data/
│   ├── esES/patch-esES-4.MPQ          ← the server's own items + races and classes (ARAC)
│   └── enUS/patch-enUS-4.MPQ          ← the same for the English client
├── Interface/AddOns/
│   ├── ServerHelp/                    ← the "Help request" tab with the server's commands
│   ├── MultiBot/                      ← own/improved command panel (not replaced)
│   └── …                              ← local collection of 3.3.5a addons served by the panel
├── manifest.tsv                       ← what each thing is and where it goes (for automation)
└── instalar-cliente.ps1               ← copies everything on Windows
```

**In the public edition `cliente/` only carries `ServerHelp`, `MultiBot`, `manifest.tsv` and
the script:** the `.MPQ` files of `Data/` (which carry complete Blizzard DBCs) and the rest
of the addons do not travel in Git. The patches are generated from your client in the panel
and the addons are rebuilt with a hash (see "Resources that come from your client"); from
the panel itself they are installed on the PC. `instalar-cliente.ps1` works with a working
repository that brings everything and warns about whatever is missing.

#### Install

**Windows (recommended)**, from PowerShell, indicating the folder where `Wow.exe` is:

```powershell
powershell -ExecutionPolicy Bypass -File .\cliente\instalar-cliente.ps1 -Cliente "<client>" -Realm 192.168.1.100
```

It copies `Data/` and `Interface/` on top of the game folder (addons are synchronized
whole: whatever is left over in `AddOns/ServerHelp` or `AddOns/MultiBot` is deleted, the
rest of the addons are not touched; the language `.MPQ` files go to `Data/esES/` and
`Data/enUS/`), removes the loose copies of the old ARAC (`Data/Patch-Arac.MPQ` and the
names that were tried earlier, `Patch-X.MPQ`, `Patch-C.MPQ`, `Patch-A.MPQ`) **only if their
MD5 matches that of that known old ARAC** (so as not to touch a file from another origin
that happens to have the same name — the reference client itself brings legitimate
`patch-A.mpq`/`patch-C.mpq`, unrelated to ARAC), **deletes `Cache/`** if it installed any
MPQ (the DBCs have changed; otherwise the client shows old data), and with `-Realm` writes
`set realmlist ...` into the `realmlist.wtf` of each language. It can be repeated: it is
idempotent. With WoW open it cannot delete `Cache/` — close it and repeat.

**By hand**: copy the contents of `cliente/Data/` into `WoW/Data/` (with its `esES/` and
`enUS/` subfolders) and that of `cliente/Interface/AddOns/` into `WoW/Interface/AddOns/`,
and delete `WoW/Cache/`. If an old installation left you a loose `Data/Patch-Arac.MPQ`,
`Patch-X.MPQ` or `Patch-C.MPQ`, you can delete it: it was never loaded (see below) and its
DBCs now go inside `patch-<language>-4.MPQ`.

When you enter the game, on the character screen, the **AddOns** button (bottom left):
`ServerHelp` and `MultiBot` must appear checked. If it says "out of date", check "Load out
of date AddOns" (they are not: the 3.3.5a client is interface 30300, which is the declared
one).

NoM0Re's optional collection is also kept extracted in `Interface/AddOns`. The web panel
lets you install only what you choose; copying this whole folder by hand copies the whole
collection. Its catalog, Spanish descriptions and provenance are in `web-panel/addons/`. The
update process expressly blocks `MultiBot` and `ServerHelp`, so an external version can never
overwrite ours.

#### What each thing is

##### `Data/esES/patch-esES-4.MPQ` and `Data/enUS/patch-enUS-4.MPQ`

Two client data files that carry two different things fused into the same MPQ:

| File inside the MPQ | What it carries |
|---|---|
| `Item.dbc` | The client gets the **icon** from here and only knows up to `entry` ~56806. The row `600000 → displayid 22071` is added to it (`INV_Misc_Key_11`, the **Reward Lockpick**; see `REFERENCES.md`). |
| `Spell.dbc` | The green *"Use: …"* line comes from here. The lockpick uses spell 59403 (the *Titanium Skeleton Key*'s), whose text says "skeleton key". Its Description is rewritten to *"Opens any locked drawer or box. It is consumed on use."* |
| `CharBaseInfo.dbc`, `CharStartOutfit.dbc`, `SkillRaceClassInfo.dbc` | The three **ARAC** DBCs: they make the character-creation screen offer any race with any class. Unmodified copy of `patch-contents/DBFilesContent/` from the mod-arac repository (same commit pinned in `versions.lock` that the server uses). |

The **name** and the **yellow description** of the own items come from the server and are not
here; this patch changes nothing mechanical, only texts and client DBCs. Without
`CharBaseInfo.dbc`/`CharStartOutfit.dbc`/`SkillRaceClassInfo.dbc` the ARAC combinations do not
appear when creating a character **even though the server does accept them** (its SQL and its
DBCs are applied by the installer); nor do they load spells correctly in the spellbook of those
characters (see below).

These DBCs **are** carried by other client patches (`patch-esES-3.MPQ`, `patch-enUS-3.MPQ`), so
the name and the place are NOT free: they go in `Data/<language>/` with the name
`patch-<language>-4.MPQ`. Wow.exe loads `patch-<language>-4.MPQ` and, being a language patch
with the -4 suffix, it takes precedence over the `-3`. It is done in `esES` and `enUS` because
WoW loads the chain of the language it starts with.

It is generated by **`tools/construir-parche-cliente-items.py`** (it reads the client's DBCs,
inserts our own, packs the MPQ). It has to be **regenerated** if ChromieCraft updates its DBCs:
otherwise what that patch brought is lost.

###### Why ARAC no longer goes in a loose `Data/Patch-Arac.MPQ` (2026-09-21)

Until 2026-09-21 the three ARAC DBCs went in a separate file, `Data/Patch-Arac.MPQ` (byte for
byte the `Patch-A.MPQ` of the mod-arac repository; earlier `Patch-C.MPQ`). That file was
**never loaded by Wow.exe**: the loader that enumerates loose patches in `Data/` (real
disassembly of the executable, not just FrameXML) demands a **single character** after
`"patch-"` (`patch-?.MPQ`); `"Arac"` does not fit and the file stayed on disk with no effect.
The in-game symptom was very specific: any character with a race/class combination that only
exists through ARAC (e.g. a Night Elf Paladin) showed **all** its spells under "General" in the
spellbook, with no tree tabs — the client resolves the tab by looking at the `CharBaseInfo.dbc`
index by race/class, and if the combination is not there (because the effective DBC was still
the original, without the ARAC rows) it returns null and everything falls into General, even
though the spells have their correct `SkillLineAbility` row. It has nothing to do with the
client cache. Full detail of the diagnosis and the evidence in `CHANGELOG.md`, task E1g.

The solution was to put those same three DBCs inside `patch-<language>-4.MPQ` instead of in a
separate file: that name is loaded by Wow.exe (it is the same mechanism that actually fixed the
Shaman and Warlock spellbook). `cliente/instalar-cliente.ps1` deletes `Data/Patch-Arac.MPQ` and
the copies with another name from earlier installations (`Patch-X.MPQ`, `Patch-C.MPQ`,
`Patch-A.MPQ`) only if their MD5 matches that of that known old ARAC, so as not to mistakenly
touch a legitimate `patch-A.mpq`/`patch-C.mpq` from another origin (the reference client itself
brings patches with those names, unrelated to ARAC).

##### `Interface/AddOns/ServerHelp`

Own addon (2026-09-02). It replaces the logic of the "Basic help" tab of "Help request" (the `?`
button on the bar) so that, instead of querying Blizzard's servers over HTTP (which is what the
original client does, and why it always said "not available"), it asks the server over the addon
channel and shows **all the commands your account can use**, with their usage, description,
permission, examples and category, plus articles about how the server works. The filtering is
done by the server with your real session: a player does not receive even the names of GM
commands; if you are promoted to GM and log in again, they appear by themselves.

- Search box, category and subcategory, a paginated list of 20, an entry with scroll and a Back
  button, a "loading" message, a "no results" message and an error one. All with Blizzard's
  original frames: same look.
- The ticket buttons ("Talk to a GM", "Report a problem", "Stuck character", "Report lag", edit
  and abandon inquiry) stay where they were and work the same.
- `/ayudaservidor` ("server help") opens the tab directly.
- It needs `mod-server-help` on the server. Without it, the tab shows a notice and the rest of
  the window keeps working.
- It talks over the addon channel that the core already processes (prefix `AzerothCore`,
  command `.ayuda ...`). It uses no new packet and requires no change to `Wow.exe`. Technical
  detail in `REFERENCES.md` and in the header of `ServerHelp.lua`.

##### `Interface/AddOns/MultiBot`

Command panel for playerbots' bots (Nico Löbbert, v2.0.0, October 2024): buttons for group
orders, strategies, loot, gear, spells per class... It is the addon that was already installed
in the reference client (`<client>`), copied from there on 2026-09-02 **without its
`Screenshots/` folder** (27 MB of screenshots for its documentation, which the addon does not
use). It is a different addon from [unbot-addon](https://github.com/liyunfan1223/unbot-addon),
which does the same with another interface; either one will do.

#### `manifest.tsv`: to automate the installation

One line per element, with tabs: `origen` (source, relative to `cliente/`), `destino`
(destination, relative to the WoW folder), `tipo` (type: `mpq` or `addon`) and `nota` (note).
It is what `instalar-cliente.ps1` reads, and what a launcher that downloaded these files from
the server on connecting would read: it only has to serve this folder over HTTP and apply the
manifest. When something is added to the client, it is added here.

#### How to add something

1. Put it in `cliente/` with the same path it would have inside WoW.
2. Add its line to `manifest.tsv`.
3. Explain it in this README (what it is, where it comes from, why it is needed).
4. If it is a loose generic `.MPQ` in `Data/` (not a language one): Wow.exe only loads
   `patch-<ONE character>.MPQ` (`patch-A.MPQ` … `patch-Z.MPQ`, `patch-0.MPQ` … `patch-9.MPQ`;
   checked by disassembly, see E1g in `CHANGELOG.md`) — a longer name is left unloaded without
   warning. If you need more than one character for the name, put it inside
   `patch-<language>-4.MPQ` (like ARAC, above) instead of as a loose file. If you do use a single
   letter/digit, first check with `tools/comprobar-modelos-cliente.py` or `mpyq` that it does not
   overwrite files from another client patch that already uses that letter (if it does, the
   alphabetical order decides).

### The web panel (`web-panel/`)

Phase 1 application for AzerothCore 3.3.5a. It authenticates against the SRP6 `salt` and
`verifier` of `acore_auth.account`, shows connected players, offers a **map** for each player
with their social circle (group, raid, guild and connected friends) and another of the positions
of the whole realm protected for GM accounts, distributes a local catalog of addons compatible
with the 3.3.5a client, and adds a character armory and a server-command reader (see below). It
also allows registering new accounts by invitation, changing the password, and moderating the
realm (kick, ban, mute, announce, send items and gold) from GM accounts (see "Accounts" and
"Moderation" below).

#### Language (Spanish / English)

The panel is available in Spanish or English. When opened it uses the browser's language
(any language other than Spanish opens in English); the selector in the header, next to the
status indicator, and the one on the login and sign-up screens change it: the choice is
remembered in the browser and the page reloads. The API answers in the same language: the
browser sends its own in the `X-Panel-Lang` header (Spanish without it) and the error messages,
the resource-job notices and the item names in the armory are translated (in English they come
from `item_template`, the original; in Spanish, from `item_template_locale`). Where this
document gives a label in Spanish with its English meaning in parentheses, that is the label
the panel shows when it is in Spanish.

The catalogs are translated too. The English of **Commands** lives in the `title_en`,
`description_en` and `body_en` columns of `server_help_*` (filled in by `server_help.sql`, so an
English game client sees it as well; if one is empty it falls back to Spanish); the descriptions
of **Configuration** are in `src/locales/config-*-en.js` (by `.conf` key), those of the addons in
`addons/descriptions-en.json` (by id), and the texts of `doctor.sh` are translated with templates
in `src/locales/en.js`. What is not translated is whatever someone writes in the game
(character and guild names, sanction reasons), what the worldserver console returns when a
moderation action runs, and the keywords, syntax and examples of the **Commands** entries (they
are the real commands, in Spanish).

To add or change a text: the key is the Spanish text itself. In `public/` you write
`t('Texto con {marcador}', { marcador })` (the argument is the Spanish text) and its English
translation goes in `public/locales/en.js`; in `src/`, the error message in Spanish and its
translation in `src/locales/en.js` (one `{x}` template covers the messages with values). Static
HTML is translated on its own (text nodes and the `placeholder`, `title`, `aria-label` and `alt`
attributes); a fragment with tags inside carries `data-i18n-html` and its inner HTML is the key.
`test/i18n.test.js` and `test/server-i18n.test.js` fail if a translation is missing, a key is
left over or the placeholders do not match.

#### Updates

The **Actualizaciones** (Updates) section, located below **Configuración** (Settings), is
only visible to administrators (gmlevel 3). Pressing **Comprobar ahora** (Check now) compares
the pinned commits of `versions.lock` (core and modules) and `addons.lock` (client addons)
with the head of their branches on GitHub, like the scripts `tools/revisar-actualizaciones.sh`
and `tools/revisar-actualizaciones-addons.sh`. It shows each repository separately and links
the commit comparison when there is news.

The operation uses only `git ls-remote`: it installs nothing, does not modify the clones and
does not restart the server. The deployment stores both locks in the panel's isolated area and
`./install.sh --freeze` automatically refreshes the copy of `versions.lock` there.

#### Server commands and help

The **Comandos** (Commands) section reads the same tables that the `ServerHelp` addon uses
inside the game (`server_help_category`, `server_help_article` and `server_help_command` in
`acore_world`). The included catalog documents 232 routes of the core and the installed modules
(it includes `.hermandad` of mod-home-guild). Unlike the addon, the panel only shows the routes
with their own entry: the complete tree is known by the worldserver in memory and is still
queried inside the game with `.commands` or `.help`.

Each entry has its own `min_security` (0 player, 1 moderator, 2 GM, 3 administrator); the
category is only thematic and grants no visibility. If a thematic category is not yet visible
to an account that can use the command, the command falls into the general category of its
rank, just as in `mod-server-help`. Old entries with `min_security = NULL` keep compatibility
by inheriting their category's minimum. Articles linked by `command_path` are not sent either if
their command is not visible. The interface shows the required rank, distinguishes family
entries and also searches in usage and examples.

#### Armory

From **Jugadores** (Players) or from the **Armería** (Armory) search you can open any character,
connected or not, and see their equipped gear with each item's real icon, its name colored by
quality and its main stats. The icons are extracted from the 3.3.5a client, converted to WebP and
served locally: the armory queries no external services. If the character is yours (same account
that has logged in), the tabs **Bolsas** (Bags), **Banco** (Bank) and **Hermandad** (Guild) also
appear, with the real contents of the bags, bank and guild bank. The guild bank respects the
permissions of your rank (`guild_bank_right`); the leader (rank 0) sees all the tabs, just as in
the game.

The icons and the `displayid` → icon map are **not** in the public edition (they are Blizzard
art): the panel generates them from your client, in the "Resources that come from your client"
step (below), and serves them from its data folder (`/var/lib/azerothcore-panel/recursos/iconos`).
While they do not exist, the panel starts all the same and the armory shows its own generic icon.
The generator can still be used by hand against a client folder:

```bash
python tools/extract-item-icons.py --client "/path/to/client"          # to public/assets/item-icons
python tools/extract-item-icons.py --insumos <folder> --salida <destination>  # with files already extracted
```

The process writes first to a temporary folder, keeps a generic icon for the references without
art and leaves the exact provenance in "Provenance of maps and icons" (REFERENCES.md).

Courtesy of these two sections: additional `SELECT` permissions are needed for the `acore_panel`
user (gear/bags/bank, guild and the `server_help_*` tables of `acore_world`). The installer
(`deploy/install.sh`) already grants them; running `./install.sh --panel` again is enough to apply
them to an existing installation.

#### Accounts: registration and password

From the login screen, "¿No tienes cuenta?" (Don't have an account?) opens a registration form
that requires a **one-use invitation key**. An administrator (gmlevel 3) generates it from
**Moderación → Administración** (Moderation → Administration); the database only stores the
SHA-256 hash of the key, so even reading the table does not yield a usable invitation, and the
plain text is shown only once, at the moment it is created. Consuming the invitation and creating
the account are atomic (one transaction on `acore_auth`): a failure halfway leaves neither the
invitation spent nor a half-made account. An administrator can also create an account directly,
without an invitation.

Any account can change its password from **Mi cuenta** (My account), asking for the current one.
The SRP6 verifier is recomputed just as in registration (`src/srp6.js`); if you have a game
session open, it stays active until you connect again (the core does not invalidate `session_key`
when the password changes). The password, as in the 3.3.5a client, has to be between 8 and 16
characters.

#### Moderation

Visible only to GM accounts, with the same categories 1-3 that "Comandos" already uses
(moderator, game master, administrator). Each action is sent over **SOAP** to the worldserver's
console (`127.0.0.1:7878`, off by default in AzerothCore and enabled by this same installer when
the panel is enabled): it is the only way to kick or mute someone who is already connected and to
confirm that the command was applied, unlike writing directly into
`account_banned`/`character_banned` (which would only take effect at the next login). The panel
identifies itself to SOAP with a dedicated service account (`panel_soap`, gmlevel 3) that the
installer creates apart from yours.

| Level | Actions |
|---|---|
| Moderator (1) | Kick, mute, unmute |
| Game master (2) | Ban/unban account or character, announce to the whole server |
| Administrator (3) | Send items and gold by mail, generate invitations, create accounts |

You can never act on an account with a rank equal to or higher than that of whoever performs the
action, even though technically the SOAP service account has gmlevel 3: the backend checks the
target's gmlevel before sending the command. No text typed in a form reaches the console as is:
`src/commands.js` is a whitelist of templates with its own validator (names, durations from a
closed list, reasons without quotes or line breaks) — if something does not fit, the command is not
even built. Every moderation action, with its result, is recorded in `acore_panel.panel_audit`.

#### Addons for players

The **Addons** section only appears after logging in. It includes 118 packages from NoM0Re's
collection and the mandatory addons `MultiBot`, `ServerHelp`, `GuildLevels`, `BugSack` (with
`!BugGrabber`, needed for it to work) and `Addon Control Panel`; they are marked with ★ and cannot
be unchecked or uninstalled from the panel. Our copy of ACP protects by default those last three
(`ACP.lua` adds them to `ProtectedAddons`): ACP re-enables them by itself if someone disables them
and does not touch them on "Disable all". You can search and filter, consult the explanation and
provenance, select packages or download each ZIP. The files are always read from the canonical copy
`cliente/Interface/AddOns`; the server generates the ZIP on the fly and GitHub takes no part in the
players' downloads. The whole catalog is in Spanish from Spain (including the notes inside the
`.toc` itself that show on the game's Addons screen) and includes a filter of recommendations by
class.

Chrome and Edge let you choose the folder that contains `Wow.exe`, install the selection directly
into `Interface/AddOns` and copy the server's patches into `Data`. The panel compares the real
content of each installed addon/patch with a hash of the one it serves right now: if it matches it
marks it **Instalado** (Installed) and does not copy it again when pressing install (so as not to
overwrite `SavedVariables` or saved configuration); if it does not match, **Actualización
disponible** (Update available). Non-mandatory addons and patches carry an **Desinstalar**
(Uninstall) button that deletes their folder or file. `patch-esES-4.MPQ` / `patch-enUS-4.MPQ` are
published (the server's own items —icon and texts— and ARAC's race and class combinations, fused
into the same MPQ; they go in `Data/esES/` and `Data/enUS/` because their DBCs are also carried by
the client's `patch-<language>-3.MPQ`). The catalog's `targetDir` field (`addons/patches.json`)
indicates the subfolder. After copying new or changed patches, "Instalar parches" (Install patches)
**deletes the client's `Cache/`** (the DBCs have changed): the player only has to restart WoW; if
all were already up to date, it touches nothing. The panel verifies the executable, asks for write
permission through the native picker and rejects unsafe paths or files without a `.toc`. This
browser API requires a secure context: on an IP served only over HTTP the ZIP download is available,
but direct installation requires publishing the panel over HTTPS (or using it from `localhost`).

The provenance, the pinned commit and the update procedure are in "The panel's addon catalog"
(INSTALL_EN.md, part 5). The five RAR sources are imported just like the ZIPs and the generated
downloads are installable from the browser.

#### Deployment next to the server

The global installer runs it automatically after the first start. To install or update only the
panel:

```bash
cd /path/to/installer
./install.sh --panel
```

The panel will be at `https://SERVER_IP`. The installer:

- publishes Nginx over HTTPS on port 443, redirects port 80 and opens both if UFW is active;
- keeps Node and MySQL bound to `127.0.0.1`;
- creates the own database `acore_panel` (invitations and auditing) and `acore_panel@127.0.0.1`
  with `SELECT` on the core's read tables (players, gear/bags/bank, guild, bans and the knowledge
  base of `acore_world`), `INSERT`/`UPDATE` restricted **per column** on `acore_auth.account` (only
  `username, salt, verifier, expansion` when creating and `salt, verifier` when changing the
  password — never `gmlevel` or `locked`), `INSERT` on `realmcharacters`, and full read/write on its
  own `acore_panel` database;
- creates the `panel_soap` service account (gmlevel 3) with which the panel talks to the
  worldserver's SOAP console to moderate (§ Moderation); enabling SOAP in `worldserver.conf`, only on
  `127.0.0.1:7878`, is a matter for phase 5 of the global installer (`./install.sh --only 5` +
  worldserver restart), not of this script;
- generates random credentials, session secret and SOAP password in `/etc/azerothcore-panel.env`
  (mode `0600`);
- installs and enables `azerothcore-panel.service`.

The installation is idempotent. Each run synchronizes the code and the static resources again from
`web-panel/`, keeps the existing secrets of `/etc/azerothcore-panel.env`, installs only the
production dependencies and restarts the service. Therefore, after modifying the panel it is enough
to run `./install.sh --panel` again.

On a local network, the installer creates a persistent certificate authority and a certificate with
the server's IP and name. Before the first access, download
`http://SERVER_IP/azerothcore-panel-ca.crt` and install it in the computer's **Trusted Root
Certification Authorities** store. Then open `https://SERVER_IP`; Chrome/Edge will recognize the
origin as secure and enable the folder picker. The CA's private key is never published.

If you already have a trusted certificate, give its paths when deploying:

```bash
sudo env PANEL_TLS_CERTIFICATE=/path/fullchain.pem PANEL_TLS_KEY=/path/privkey.pem bash web-panel/deploy/install.sh
```

If ports 80 or 443 are in use, choose others before running it:

```bash
sudo env PANEL_HTTP_PORT=8080 PANEL_HTTPS_PORT=8443 bash web-panel/deploy/install.sh
```

The options `INSTALL_WEB_PANEL`, `PANEL_HTTP_PORT`, `PANEL_HTTPS_PORT`, `PANEL_TLS_CERTIFICATE`,
`PANEL_TLS_KEY`, `PANEL_REALM_ID`, `PANEL_AUTH_DATABASE`, `PANEL_CHARACTERS_DATABASE`,
`PANEL_WORLD_DATABASE`, `PANEL_PANEL_DATABASE`, `PANEL_DB_USER` and `PANEL_SOAP_ACCOUNT` live in
`config.sh`. Session cookies are always marked `Secure` in the production deployment.

#### Development

```bash
cp .env.example .env
npm install
set -a; source .env; set +a
npm run dev
```

In PowerShell, load the `.env` variables manually before running `npm run dev`. The tests do not
need a database:

```bash
npm test
npm run check
```

#### Security decisions

- The password is never stored: the SRP6 verifier is recomputed and compared in constant time,
  both for logging in and for registering or changing it.
- The session is a signed `HttpOnly` and `SameSite=Strict` cookie, expiring after 8 hours.
- The backend queries `account_access` again on every map and moderation request. A rank
  withdrawal takes effect without waiting for a new login.
- The endpoints do not cache personal data and login/registration limit attempts per IP.
- The catalog and all the packages require a session; file names are resolved from the
  validated manifest and never from a path supplied by the user.
- The interface hides the map and moderation from whoever has no rank, but the effective
  protection is always in the backend (`/api/map/players`, `/api/moderation/*`).
- The panel **does** write to the core, but in a restricted and explicit way: it creates
  accounts and changes passwords (column permission, never `gmlevel`/`locked`) and sends
  moderation commands over SOAP with a dedicated service account, never direct SQL on
  `account_banned`/`character_banned`. No text from a form reaches a command as is:
  `src/commands.js` is a whitelist with its own validator per field. Every write action is
  recorded in `acore_panel.panel_audit`, and you cannot act on an account of equal or higher
  rank than whoever executes it.

The role is inferred using characteristic talents of the active spec. In WotLK some hybrid
configurations (for example, feral druid or DK) do not encode an unambiguous role in the
database; if there is no reliable defensive or healing signal, the panel shows DPS.

#### Player map (social circle)

Under **Jugadores** (Players), the **Mapa** (Map) section can be seen by any account and shows,
over the same continent maps, the positions of the **connected** members of your group, your
raid, your guild and your friends list —like the group/raid pins inside the game, extended to
guild and friends—. The dot carries the class color and the outer ring that of the relationship:
**group blue, raid orange, guild green, friends gold**; you appear with a white ring.

**It is not live.** Both this map and the GM one read `characters.position_x/y`, which the
worldserver only writes every `PlayerSaveInterval` (15 min by default) and on certain events:
continent change, instance entry/exit, disconnection, hearthstone, leveling up. Between saves the
position may be out of date; the time the panel shows is that of its last query. A fixed notice
under the header of both maps makes this clear. To refine it, `PlayerSaveInterval` would have to
be lowered (more writes to MySQL, with the bot population connected).

The social circle is per character. A selector chooses which of your characters is shown; by
default, the one you have connected. If none is, you choose one and the connected members of its
guild and its friends are shown (the group only exists while you play). When someone fits several
categories the closest wins: group/raid › friend › guild.

`GET /api/social/map` only returns positions of characters with a social link to **one of your own
characters** (tables `group_member`/`groups`, `guild_member` and `character_social` of
`acore_characters`), and only if they are connected. It does not expose the rest of the realm:
that remains exclusive to the GM map. The installer (`deploy/install.sh`) grants the necessary
`SELECT` on `group_member`, `groups` and `character_social`; on an existing installation,
`./install.sh --panel` reapplies it.

#### Cartography

The four continents use clean maps from the game's interface at 3840 × 2560, published on Warcraft
Wiki: pre-Cataclysm Eastern Kingdoms, Kalimdor, Outland and Northrend. The sources and the concrete
SHA-256 hashes are in "Provenance of maps and icons" (REFERENCES.md). They are served locally; the
browser queries no external services.

The viewer always keeps the 3:2 ratio and frames the whole map when opened. The wheel, the buttons
and double click allow zooming in, and you can drag to move it. The maximum zoom is computed from
the native resolution, so the image is never enlarged above 3840 × 2560. The markers live in an
independent layer: they change position with the map, but not size or resolution. The server's
coordinates are projected with the bounds of each continent's `WorldMapArea.dbc`.
`WorldMapTransforms.dbc` also translates the blood elf and draenei zones, whose physical map is 530,
to Eastern Kingdoms and Kalimdor respectively. Positions that have no valid continental projection
are shown in the instance list and are never forced against the edge of the drawing.

### The panel's addon catalog (`web-panel/addons/`)

`cliente/Interface/AddOns` is the only canonical copy served by the web panel; no player download
depends on GitHub. `catalog.json` relates each package to its folders, Spanish description, category,
recommended classes, size and source. The external snapshot comes from commit
`235b9e4cd5b429b94f4cb33ba9308d3c78f6bcad` of
<https://github.com/NoM0Re/WoW-3.3.5a-Addons>.

The 118 NoM0Re packages were extracted into the client path. The download ZIPs are generated on the
fly from those same folders, avoiding maintaining a second copy. The five original RARs are also
imported during synchronization.

**Partial synchronization (2026-10-01).** The pinned commit is `235b9e4`, but only DrDamage (updated),
RatingBuster (replaces the misspelled package "RaitingBuster"), SavedInstances and RaidSlackCheck were
brought from it, by hand. That commit removed 25 packages from the catalog (ElvUI, Skada, Grid2, Details,
TidyPlates, TellMeWhen, SharedMedia…) which are deliberately kept here: a full `npm run sync:addons`
would delete them, so it is not used while that decision stands.

`MultiBot` and `ServerHelp` are marked as mandatory and the synchronizer never replaces them: the
project's own versions are always used.

`GuildLevels` (mod-guild-levels' interface) is also mandatory, as are `BugSack` (which includes
`!BugGrabber`, needed for it to work) and `Addon Control Panel`. Unlike MultiBot/ServerHelp, BugSack and
ACP do come from the NoM0Re mirror like any other addon (with their own `archive`/`sha256` in
`.addon-sync/catalog.json`): the field that distinguishes "read it as is from the client, a single
folder" in `extract-client-addons.mjs` is belonging to `protectedAddons` (only multibot/serverhelp), not
`required` — if a new mandatory addon that comes from the mirror is added, it must follow the normal ZIP
extraction branch, not the "own addon" one.

Our copy of `ACP/ACP.lua` protects by default (`ProtectedAddons`) `ACP`, `BugSack` and `!BugGrabber`: ACP
re-enables them by itself if someone disables them and does not include them in its "Disable all". It is
a local modification on top of the CurseForge ACP, not something provided by upstream; it only applies the
first time a player generates their `ACP_Data` (it does not touch that of anyone who already had one).

##### Resources that come from your client (icons and language patches)

The quick installation (`./install.sh --guiado`) leaves the server and the panel ready; **two resources
come from the player's WoW client and are generated from the panel itself**, without running anything on
your PC: the armory icons and the `patch-esES-4.MPQ` / `patch-enUS-4.MPQ` patches (own items and ARAC
races/classes). Until it is done, the server works, the panel starts with generic icons and the patches
are listed as pending. The installer says so when it finishes ("FALTA EL PASO DEL CLIENTE; la instalación
NO está completa hasta hacerlo" — THE CLIENT STEP IS MISSING; the installation is NOT complete until it is
done) and the `doctor` warns about it (`recursos-cliente`).

To complete it, on your PC with Chrome or Edge:

1. Open the panel (`https://<server IP>`) and log in with the administrator account (the first time,
   install the certificate the page offers).
2. **Addons → Elegir carpeta de WoW** (Choose WoW folder) (the one with `Wow.exe`). The browser checks that
   it looks like a 3.3.5a client, reads from its MPQs only what is needed (`ItemDisplayInfo.dbc`, the icons
   it references and, per language, `Item.dbc` and `Spell.dbc`; about 100 MB even if the client weighs
   several GB) and sends it to the server, which generates and verifies. You will see the progress; it can
   be cancelled.
3. **Instalar parches** (Install patches) and, in step 3, **Instalar** (Install) the mandatory addons.

It is idempotent and resumable: if the client is the same and the recipe has not changed, the second time
it answers "ya estaba al día" (it was already up to date) without sending anything; if the upload is cut,
repeating it reuses the files already received; **Regenerar todo** (Regenerate everything) redoes it even
if it is up to date. A failure does not destroy the previous one: the earlier resource keeps being served.
Only administrators (GM 3) can prepare them; a player sees the pending patches.

With the working repository (which brings icons and MPQs already prepared) that data is incorporated when
the panel starts as "prepared" and is valid until you ask to regenerate it. Everything else in phase 9
(`scripts/preparar-recursos.sh`) is automatic: dependencies (Node, `bsdtar`, Pillow), the 309 rebuilt and
checked addons, the maps with hash and the three ARAC DBCs verified. If any of that fails, the installation
stops (it is not considered complete). The continent maps (all four, Northrend included) come from Warcraft
Wiki with the pinned hash; the wiki's CDN sometimes serves a recompressed variant, so several cache URLs are
tried and only the file with that hash is accepted, in three passes with pauses. If none gives it, the map
stays pending and the panel shows a neutral background instead of using another version;
`./install.sh --panel` repeats the download.

Check:

```bash
./install.sh --doctor        # addons (309/309), client-data (complete v20), recursos-cliente (pending or ready), mirrors, services…
```

##### Installed, update and uninstall

The panel decides "installed / there is an update / not installed" by comparing the real contents of
`Interface/AddOns` with a content hash per addon (`contentVersion`, computed in `src/addons.js` when the
panel starts — same scheme: folder + relative path + content, traversed in the browser with the File System
Access API). There is no manifest of its own that can get out of sync: if the hash matches, the addon is
**not copied again** when pressing install (so SavedVariables and configuration inside that same folder are
not overwritten); if it does not match, it is reinstalled whole. The patches (`patches.json`) already
brought their own `sha256`, so they are compared the same way but over a single file. Non-mandatory addons
and patches can be uninstalled from their own card/row (it deletes the folder or file); the mandatory ones
do not show that option.

To find out whether there is news in the source repository without cloning it (only `git ls-remote` + the
public GitHub API):

```bash
bash tools/revisar-actualizaciones-addons.sh              # table, includes this row
bash tools/revisar-actualizaciones-addons.sh --log-catalog # which files in src/Addons/ changed
```

**Reproducible rebuild (PUB04).** The public edition does not carry the 307 third-party addons: they are
rebuilt with `web-panel/tools/build-addons.mjs` from `web-panel/addons/fuentes.json` (each NoM0Re package
with its commit and SHA-256, the three repository addons according to `addons.lock` and the patches in
`patches-cliente/`) and checked against `web-panel/addons/arbol.tsv` (content hash of each of the 309
folders, insensitive to CRLF and to path case). `MultiBot` and `ServerHelp` go in the tree. The step is run
by phase 9 (`scripts/preparar-recursos.sh`); by hand:

```bash
cd web-panel && npm ci --omit=dev
node tools/build-addons.mjs verificar                 # does what is there match arbol.tsv?
node tools/build-addons.mjs build                     # rebuilds (downloads with SHA-256; needs bsdtar for the RARs)
node tools/build-addons.mjs arbol > addons/arbol.tsv  # after a deliberate change of sources or patches
```

`build` works in a temporary folder inside the destination, checks each folder against `arbol.tsv` and only
then replaces them one by one: a download, hash or patch failure does not leave the destination half done.
A working repository that already brings the whole `cliente/Interface/AddOns` downloads nothing.

To update the snapshot you need a local copy of the source repository and a `bsdtar` implementation able to
read RAR and create ZIP (it is the old flow, which replaces the whole tree; afterwards the new commits and
hashes must be recorded in `fuentes.json` and `arbol.tsv` regenerated):

```bash
cd web-panel
npm run sync:addons -- /path/WoW-3.3.5a-Addons
npm test
```

The script extracts the collection into `cliente/Interface/AddOns`, keeps the two own addons and
recomputes the whole catalog. The reviewable translations live in `descriptions-es.json`; if a new addon
appears, the synchronization stops until it has Spanish text. Before publishing an update, the changes of
provenance, licenses and compatibility of the external repository must be reviewed. GuildLevels, QuestRadar
and PlayerBotManager's `required` do not go through this script (they come from their own repositories):
after a full synchronization they have to be restored by hand in `catalog.json` as was done the first time.

##### Localization of the `.toc` files into Spanish

`tools/localize-addon-tocs.mjs` adds `## Notes-esES:` to the client's `.toc` files that have no Spanish
localization, reusing the same text from `descriptions-es.json` (or `catalog.json` for
GuildLevels/QuestRadar/PlayerBotManager, which are not in `descriptions-es.json`). It touches no `.toc` that
already declares `Notes-esES`: reviewing an existing translation that looks bad is a human's job. It is
idempotent (it can be run again after synchronizing new addons) and accepts `--dry-run` to see the count
without writing anything:

```bash
node tools/localize-addon-tocs.mjs --dry-run
node tools/localize-addon-tocs.mjs
```
