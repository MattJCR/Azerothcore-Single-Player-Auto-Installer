# Azeroth Single Player — AzerothCore WotLK 3.3.5a

[Español](README_ES.md) · **English**

> **Your own World of Warcraft: Wrath of the Lich King, on your own server, to
> play alone or with a few friends, in Spanish or English, and with a world full
> of life.** An installer that sets up, with a single command, a complete
> WotLK 3.3.5a server where hundreds of bots stand in for "other players": they
> fill your queues, join you on quests, populate your guild, wage their own war
> in the contested zones and trade at the auction house.

## What it is

**Azeroth Single Player** is a project that turns
[AzerothCore](https://www.azerothcore.org/) —the free World of Warcraft 3.3.5a
emulator— into a **personal-use** server: to play on your own, or with a small
group of friends, without depending on a public server existing or on anyone
being online at your hour.

It is not just another server with a few modules switched on. It is a
**complete, reproducible product**, made up of:

- **an installer** that leaves the server running and configured from scratch;
- **the server**: AzerothCore, its bot-enabled fork
  ([mod-playerbots](https://github.com/mod-playerbots/mod-playerbots)) and some
  thirty modules, third-party and our own, with the patches needed to make them
  work together;
- **a web panel** to administer the realm and distribute addons;
- **what goes on the player's PC**: client addons and patches, with their
  installer;
- **the documentation and tests** that let you trust all of the above.

The goal is not to pile up options, but to make **playing alone feel as much as
possible like playing on a realm full of people**.

## The problem it solves

World of Warcraft is, above all, a game **about people**. Almost everything that
makes it memorable needs other players: dungeon queues, raids, battlegrounds and
arenas, the auction house, bustling capital cities, the guild you raid with every
week, the group killing the same boars as you.

On a server of your own, **all of that is empty**. You queue for a battleground
and the queue never pops. You look for a group for a dungeon and nobody answers.
You arrive in Stormwind and there is no one there. The auction house has no
offers. The bots that already exist for AzerothCore help, but by default they are
blind: they don't know which queue you are in, they don't come near your zone,
they don't form a useful group, and with hundreds of them logged in the server
burns memory and CPU 24 hours a day even when nobody is playing.

This project exists to close that gap.

## What you get

### A living world around you

- **Your zone is not empty.** When you enter a zone, the server checks how many
  bots of your level are in it and brings in the missing ones to hunting spots
  far from you, so you never see them appear. If you stay, it tops up whatever
  leaves.
- **Quest companions.** When you accept "kill ten boars", two or three bots from
  your zone accept it too and go after it on their own, as other players would.
  They stay the same for a while: companions, not strangers.
- **Capitals with people in them, an auction house with sellers from both
  factions**, and a world war with skirmishes and duels between factions at 23
  hotspots.
- **Treasure chests** spread over 57 zones, which move around and fire a flare
  when they appear.

### Group content whenever you want it

- **Queues pop.** You queue for a battleground, an arena, a dungeon or a raid and
  the server puts into *that* queue the bots that are missing: the tank and the
  healer if what's missing are roles, both sides if it is a battleground. No
  waiting.
- **Groups without a queue.** `.grupo` (the "party" command) instantly forms a
  group of bots of your level with a tank and a healer, for group quests or for a
  dungeon you want to walk into. And the bot tank can lead the dungeon from start
  to finish.
- **Your guild.** You found it, and as long as you lead it, it fills up with up
  to 15 bots of your faction and level that level up with you and come first in
  your groups. There is also a guild house with services and a professions
  center.

### Progression and variety, your way

- **Vanilla → Burning Crusade → Wrath of the Lich King, per character.** The
  content of each era opens in order, by playing it, not all at once.
- **Instances scaled** to the number of players, world bosses just for your
  group, and the Ahn'Qiraj War Effort that can be completed solo.
- **Rules you choose per character:** Hardcore, Iron Man, crafted-only, slow
  XP… and any race with any class.
- **Familiar comforts:** transmogrification, random enchantments scaled to your
  level, rewards on leveling up, world buffs, a reagent bank.

### In Spanish and in English

The project works with the WoW client **in Spanish (`esES`) or in English
(`enUS`)**: the client patches and the resources generated from your own
installation are prepared for both languages, and each player sees the game in
the language of their client. The base game already comes translated; the
project additionally translates what the modules add (service NPCs, menus, bot
phrases).

**The project is developed mainly in Spanish**: the documentation, the code
comments, the installer messages and commands and the project's own texts are
in that language. English is covered by this README
([`README_ES.md`](README_ES.md) is the Spanish original) and by support for the
`enUS` client.

### A server that looks after itself

- **Standby mode.** If nobody plays for a while, the world server shuts down and
  the next connection wakes it up: with bots inside it consumes a lot; on standby,
  nothing.
- **Daily restart with notice, safe shutdown** (it saves everyone before
  closing), **automatic health checks** and in-game notice of new versions.
- **Pinned versions and offline copies** of every dependency, so a reinstall a
  year from now gives the same result as today.

## How it is built

There are four pieces, and all four come from the same repository:

1. **The installer** (`install.sh`). It turns a clean machine into the complete
   server in nine independent, resumable phases: it prepares the system, installs
   the database, downloads the code **at pinned versions**, compiles, configures,
   and creates the services and the panel. With `bash install.sh --guiado` you
   only have to answer a few questions. Nothing is edited by hand on the server:
   you change `config.sh` (or your `config.local.sh`) and reapply.
2. **The server.** Third-party modules are switched on or off one by one. The
   **own modules** (`modules/`) do what none of the others did: bot-filled
   queues, world population, quest companions, chests, instant groups, a home
   guild, in-game help, standby mode. The **patches** (`patches/`) fix or adapt
   other people's modules without forking them. One simple rule applies: before
   writing our own code we try to solve it with a configuration option, then with
   data in the database and, only if there is no other way, with a patch.
3. **The web panel.** You log in with your game account. It shows who is online,
   a real-time map of the realm, the character armory, command help and health
   status; it lets you create accounts by invitation, moderate and check for
   updates, and it distributes a catalog of client-compatible addons.
4. **The client.** The game runs on your PC. The project **does not include or
   distribute anything from Blizzard**: the language patches and the armory icons
   are generated from your own client, through the panel, and the project's own
   addons and patches are installed with a script.

**What is verified is really tested.** The project ships a synthetic client —a
WoW 3.3.5a client with no interface— that connects to the server, forms groups,
queues up and enters dungeons to check that every feature does what it says
before it is accepted.

## Who it is for, and who it is not for

**It is for you if** you want to play WotLK (or go through the classic
progression) at your own pace, alone or with a few friends, on a server you set
up and control yourself, and you want it to feel inhabited. Each player has their
own account, characters and progression, and the bots fill in whatever is
missing.

**It is not if** you are looking to open a realm to the public, or to run a
commercial server: it is designed for one person or a group of friends, and it
is neither designed nor tested to be exposed to the internet. Nor does it
maintain its own fork of the AzerothCore core —it uses the mod-playerbots one
and relies on modules and patches— nor does it **include World of Warcraft**:
you need your own 3.3.5a client.

## What you need

- A server of your own, physical or virtual machine, with at least **16 GB of RAM
  and 60 GiB of free disk** (the exact requirements are in
  [Install](#install)). It has been tested on a Proxmox VM with 8 cores, 16 GB
  and 120 GB; those are test figures, not requirements.
- A **WoW 3.3.5a client**, in Spanish or English, on each PC that will play.
- About 35 minutes of installation, mostly compiling.

The data of each installation —the IP, the realm name (`Azeroth SP` in the
tests), the passwords— are your own and are kept in `config.local.sh`, which is
not versioned.

**To get started:** [Install](#install) (below) · details of each piece in
[`INSTALL_EN.md`](INSTALL_EN.md) and [`REFERENCES.md`](REFERENCES.md).

---

## Documentation

There are five main documents, the same in every copy of the project:

| File | What for |
|---|---|
| **`README.md`** | Language selector with a short summary; **`README_EN.md`** (this one) and `README_ES.md` are the full document: what it is, its state, what it contains |
| `INSTALL_EN.md` (and `INSTALL_ES.md`, in Spanish) | Installing, **configuring** (every `config.sh` option), what each phase does inside, how to operate the server, the player's PC (client) and the web panel |
| `CONTRIBUTING.md` (selector), `CONTRIBUTING_EN.md` and `CONTRIBUTING_ES.md` | How to contribute: what is accepted, the project's rules, how every pull request is reviewed and why the synthetic client is not modified |
| `REFERENCES.md` | How each of our own pieces works today, static reference data (commands, NPCs, PvP pairings, identifier ranges), the rules for writing a module or a patch, creating an item that doesn't exist in 3.3.5a, the synthetic verifier and the provenance of resources |
| `CHANGELOG.md` | Everything done, dated and in detail, latest first. At the end, the annex with the full designs and analyses |

`INSTALL_EN.md` is the English translation of `INSTALL_ES.md` (same structure; if they
disagree, the Spanish one prevails). `REFERENCES.md` and `CHANGELOG.md` are currently
written in Spanish only.

---

## Current state

**Up to date as of 2026-09-07.** What was running on the test server:

| | |
|---|---|
| Core | Playerbot fork `413bea61` (04/09) · playerbots `b949b50b` (04/09) · 21 repositories pinned in `versions.lock`, updated on 05/09 |
| Client data | v20.0 (mmaps v20, 0 errors) |
| Bots | 150 accounts, 1500 characters, 400-500 online, LevelBrackets active |
| Consumption | 5.8 GB and ~274 % CPU with 221 level-80 bots inside (on the test machine) |
| Time | The VM runs in `Europe/Madrid` since 04/09 (before that, UTC) |
| Restart | Daily at 00:00, with prior notice |
| Web panel | `http://<server-IP>` · SRP6 login · online players · local addon catalog · real-time GM map |

`mod-adaptive-ai` has been **archived and disabled** since 2026-09-06. It is not
compiled or loaded, and its tables were emptied after the training was exported.
No work is planned on the module. Its status and the conditions for a possible
reactivation are in `CHANGELOG.md`.

The history of implementations, tests and fixes is recorded in `CHANGELOG.md`.

---

## What it installs

**AzerothCore** (mod-playerbots fork, `Playerbot` branch), **MySQL 8.4 LTS** and
these modules, each one switchable in `config.sh`:

| Module | What it adds |
|---|---|
| `mod-individual-progression` | Vanilla → TBC → WotLK progression per character |
| `mod-playerbots` | AI bots that populate the world, do quests, instances and battlegrounds |
| `mod-queue-bots` (**own**) | Fills with bots the queue you join: 1v1, battleground, arena, dungeon, raid |
| `mod-world-bots` (**own**) | Keeps your zone from being empty: brings bots of your level to hunting spots far from you, populates the capitals, and tops up while you stay. And the world war: skirmishes between factions and duels at 23 hotspots |
| `mod-treasure` (**own**, SP03) | Chests in 57 active zones. When a human enters, ground, line of sight and route are checked automatically before destinations are assigned; they move after an hour uncollected, are individually replenished when emptied, and fire a flare when they appear |
| `mod-quest-mates` (**own**) | Quest companions: when you accept a quest, two or three bots from your zone take it too |
| `mod-quest-loot-party` (SP04) | Every present, eligible group member can loot their own copy of white quest loot; AoE Loot picks up each copy without consuming the others'. It doesn't change solo loot or drop chances |
| `mod-autobalance` | Scales instances to the number of players |
| `mod-transmog` | Transmogrification, with NPCs in the eleven capitals |
| `mod-ah-bot-plus` | A living auction house, with sellers from both factions |
| `mod-random-enchants` | Random enchantments on loot, scaled to your level |
| `mod-congrats-on-level` | Rewards on leveling up, at any level |
| `mod-challenge-modes` | Hardcore, Iron Man, Crafted Only, slow XP… per character |
| `mod-profession-experience` | Profession XP: orange 1 %, yellow 0.5 %, green 0.25 %, grey 0; capped at the maximum of the learned rank, bots included and no guild XP. Details in `REFERENCES.md` |
| `mod-guildhouse` | Guild house on GM Island, with services and the original exit portal. Own free stone with a 10 s/30 min cooldown; purchase for 1,000 gold. Professions center (SP07): trainers, forge, anvil and Ling, the materials banker, as butler upgrades. See `REFERENCES.md` |
| `mod-instanced-worldbosses` | World bosses just for your group |
| `mod-war-effort` | Ahn'Qiraj War Effort, completable solo |
| `mod-dungeon-master` ⚠️ | Procedural dungeons and Roguelike mode (*early development*) |
| `mod-dungeon-clear` | The bot tank leads the dungeon from start to finish; it switches on by itself when you enter with the dungeon-finder group |
| `mod-party-here` (**own**) | A group where you stand, no queue: `.grupo` forms a group of bots of your level with a tank and a healer; group quests automatic |
| `mod-home-guild` (**own**) | Your guild: you found it (the module neither creates nor adopts any), and as long as you lead it, it fills up with up to 15 bots of your faction and level that log in with you, level up with you and come first in queues |
| `mod-update-notice` (**own**) | Notice to GMs on login if there are new upstream versions; `.actualizaciones` |
| `mod-server-help` (**own**) | The "Help request" tab of the client shows the commands and articles your account can use, filtered by the server; `.ayuda`. Needs the `ServerHelp` addon (`cliente/`) |
| `mod-standby` (**own**) | Standby mode (on by default): shuts down the worldserver after 15 min without human players and the next connection wakes it up (systemd socket activation). The VM spends no CPU or RAM on the bots while nobody plays. `WORLDSERVER_STANDBY=false` to disable it; `.standby` |
| `mod-adaptive-ai` (**own, archived**) | Disabled since 2026-09-06; not compiled or loaded. Its design and history are in `CHANGELOG.md` |
| `mod-world-buff-bots` | World buffs (Onyxia, Warchief, Zandalar) delivered by "players" every 30-150 minutes |
| `mod-token-turnin` | The tier tokens bots win are exchanged for their piece; queue-bots does it by itself after each boss |
| `mod-racial-trait-swap`, `mod-reagent-bank`, `mod-aoe-loot`, `mod-instance-reset`, `mod-1v1-arena` | Services |
| `mod-arac` | Any race with any class (client patch + SQL + DBC) |

`mod-pvp-titles` remains supported but disabled: it duplicates the titles of
individual-progression with lower thresholds.

Also: safe shutdown on stop (warns players, `saveall`, orderly close), daily
restart, **standby mode** (by default: shuts the worldserver down when nobody is
there and the first connection wakes it up; `WORLDSERVER_STANDBY=false` to
disable it), weekly in-game mail notice of new versions, pinned versions
(`versions.lock`) and offline copies of each repository (`mirrors/`), automatic
health check (`doctor`, see `INSTALL_EN.md`) visible in the panel under **My
account**, and CI for syntax, `mirrors/` integrity, our own patches and the web
panel.

---

## Install

Requirements: Ubuntu Server 24.04 already installed, a user with `sudo`,
internet, 16 GB of RAM and 60 GiB of free disk (what the wizard checks; more
cores shorten the build). Hardware it has been tested on: `INSTALL_EN.md`.

**Get the project**: clone it on the server (or download a version's ZIP and check its `SHA256SUMS`, see `INSTALL_EN.md`):

```bash
git clone https://github.com/MattJCR/Azerothcore-Single-Player-Auto-Installer.git azerothcore-installer
cd azerothcore-installer
```

**Guided installation**, without editing files: open a terminal in the project
folder and run:

```bash
bash install.sh --guiado
```

It checks the machine, proposes the server IP and asks for the realm name and
your account. It shows a summary, saves your data in `config.local.sh` (without
touching `config.sh`) and runs the full installation, including the panel if
enabled. It keeps the current modules, rates, bots and advanced settings. Keep
the terminal open.

When it finishes, the server and the panel are running; **one step with your WoW
client is still missing**: in the panel (Addons → choose the WoW folder) an
administrator generates, without installing anything, the armory icons and the
language patches from their own client. The installation is not complete until
that is done (the installer and `doctor` warn about it). Details in
**[INSTALL_EN.md — Resources that come from your client](INSTALL_EN.md#resources-that-come-from-your-client-icons-and-language-patches)**.

If it is interrupted: `bash install.sh --reanudar` (resume). Step-by-step guide
from Ubuntu and the check options: **[INSTALL_EN.md — Install with the
wizard](INSTALL_EN.md#install-with-the-wizard)**.

**Advanced installation**, with manual control of the configuration:

```bash
cd azerothcore-installer      # the cloned folder (or the unzipped ZIP)
nano config.local.sh                                 # your REALM_IP and passwords (see config.sh); modules in config.sh
chmod +x scripts/instalar-todo.sh && ./scripts/instalar-todo.sh   # ~35 min, asks for sudo once
```

Phase by phase, modes, what to do afterwards and everything about the player's
PC: **`INSTALL_EN.md`**.

After that, `./install.sh --only 5` is enough to reapply any change to
`config.sh` or `config.local.sh`; you only need to recompile if code is touched
or a new module comes in.

---

## Structure

```
install.sh                  ← the ONLY script in the root: --guiado, --reanudar, phases, --post, --panel...
config.sh                   ← the base configuration (options and neutral values)
config.local.sh             ← your values (IP, passwords...); created by the wizard; not versioned
versions.lock               ← exact commit of each repository
scripts/                    ← installer implementation (advanced use; install.sh calls it itself)
  instalar-todo.sh            ← full unattended installation, web panel included
  apply-safe-stop.sh          ← safe shutdown for old installations
  phases/01..09_*.sh          ← the phases (8-9 = --post; 9 = --panel)
lib/                        ← utils, versions, mirrors, notices, patches, srp6
modules/                    ← own modules (queue-bots, world-bots, quest-mates,
                              party-here, home-guild, update-notice, server-help,
                              adaptive-ai) and shared/
patches/                    ← patches and SQL on top of third-party modules
cliente/                    ← what goes on the player's PC: ServerHelp and MultiBot addons,
                              manifest and installer (the patch-<language>-4.MPQ files and the
                              rest of the addons are generated or rebuilt during installation)
tools/                      ← guided wizard, backup, first start, verification,
                              training reports, update check
web-panel/                  ← web panel, local addon catalog, tests and Nginx/systemd installer
mirrors/                    ← manifest and hashes of the pinned repositories; the snapshots
                              are rebuilt with `./install.sh --hidratar` (see INSTALL_EN.md)
```

Each phase is an independent script (`install.sh --only N`). Nothing is edited by
hand on the server: you change `config.sh` or `config.local.sh` and reapply.

---

## Warnings

- **mod-playerbots requires its fork of the core.** To add or remove it you have
  to reinstall from phase 3.
- **mod-dungeon-master is experimental.** If you see odd things in instances, set
  `INSTALL_MOD_DUNGEON_MASTER=false` and recompile; phase 3 sets it aside without
  deleting it.
- The `admin`/`admin` account is trivial on purpose (local network). Change it
  with `.account password`.
- A running installation is **not** a clone of this repository: changes are
  uploaded with `pscp`/`scp` (`INSTALL_EN.md`, part 4 §8).

---

## License

The project's own code (own modules, installer, web panel and tools) is
distributed under the **GNU Affero General Public License v3.0 or later**
(`LICENSE`). Patches that modify someone else's project keep that project's
license. The core and third-party modules keep their own (GPL-2.0 or later,
AGPL-3.0, MIT as the case may be), as does each client addon. `NOTICE`
summarizes the copyright, `LICENSES/` carries the texts and
`THIRD-PARTY-NOTICES.txt` links each third-party component to its license and
origin. World of Warcraft and its resources belong to Blizzard Entertainment and
are not covered by this license.

---

## Resources

- [AzerothCore](https://www.azerothcore.org/wiki/installation) · [Discord](https://discord.gg/gkt4y2x) · [Module catalogue](https://www.azerothcore.org/catalogue.html)
- [mod-playerbots](https://github.com/mod-playerbots/mod-playerbots/wiki) · [mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression/wiki)
- Client data: [wowgaming/client-data](https://github.com/wowgaming/client-data/releases) (v20.0 for this core)
