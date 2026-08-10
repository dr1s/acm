# AzerothCore Container Manager

Container-based AzerothCore WoW server with module support. Uses Podman or Docker.

This project provides a single `acm` command that manages the full lifecycle of an AzerothCore server stack: setup, start/stop, backups, restores, module management, and Paragon Anniversary support.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Configuration](#configuration)
- [Backups & Retention](#backups--retention)
  - [What gets backed up](#what-gets-backed-up)
  - [Backup commands](#backup-commands)
  - [Backup cleanup / retention policy](#backup-cleanup--retention-policy)
  - [Changing the backup location](#changing-the-backup-location)
- [Restore](#restore)
- [Creating an Account](#creating-an-account)
- [Modules](#modules)
  - [Module URL syntax](#module-url-syntax)
  - [How `acm setup` handles modules](#how-acm-setup-handles-modules)
  - [Example setup with modules](#example-setup-with-modules)
- [Examples](#examples)
- [Shell Completion](#shell-completion)
- [Development & Testing](#development--testing)

## Features

- One-command setup, start, stop, backup, and restore
- Podman-based container stack with Podman Compose overrides
- Per-config project isolation via `NAME` (containers, networks, volumes, and backups are separated)
- Automated MySQL database and config backups with gzip compression
- Built-in backup retention / cleanup policy (keeps all backups from today, one per day for 7 days, one per week for 4 weeks, one per month for 12 months)
- Module support: clone/update modules from Git and remove stale modules automatically
- Optional game launch after the server is healthy
- Paragon Anniversary install/uninstall helpers
- Worldserver console attachment and account creation via `expect`

## Requirements

- [Podman](https://podman.io/) and `podman-compose` (or Docker with Compose v2, via the `CONTAINER_CMD` config setting)
- Bash 4.2+
- `expect` (for `acm create-account`)
- `git`, `tar`, `gzip`
- `envsubst` (from `gettext`; used by `acm setup` to generate the Compose override)
- `rsync` (used by `acm setup` and `acm bundle paragon install` to sync module/Lua files)
- `patch` (used by `acm setup` to remove the client-data-init dependency)

## Quick Start

### 1. Setup

```bash
./acm setup
```

Clones the main AzerothCore repository, installs module dependencies, and rebuilds the full container stack.

### 2. Start the Server

```bash
./acm start
```

Starts the server and waits for the authserver to be ready.

### 3. Restore a Backup

```bash
./acm restore ./backups/db_backup_playerbots_YYYYMMDD_HHMMSS.sql.gz
```

Stops the full stack, removes the database container and volume, restores from a compressed backup, then shuts down. Use `./acm start` to start the full stack afterward.

## Commands

All commands accept an optional config file path (defaults to `./conf/wowserver.conf`).

| Command | Purpose |
|---|---|
| `acm setup` | Clone/update repos, rebuild all container images. Flags: `--clean` (remove old images), `--no-cache` (skip build cache), `--skip-update` (skip git pull), `--skip-build` (skip compose build), `--prune` (clean dangling and external images), `--skip-stale` (skip stale module removal). |
| `acm start` | Ensure old containers are stopped, start server, wait for authserver to be ready. |
| `acm run` | Start stack, optionally launch game, wait for game exit, wait for keypress, backup, cleanup old backups, shutdown. `--skip-game` to skip game launch. |
| `acm stop` | Stop the running stack. |
| `acm backup` | Backup databases and configs, stopping worldserver/authserver first. `--skip-stop` to leave them running. |
| `acm restore` | Restore a database backup, then shut down. |
| `acm bundle arac-updated install` | Install All races all classes dbc files. |
| `acm bundle arac-updated uninstall` | Remove All races all classes dbc files. |
| `acm bundle paragon install` | Install Paragon Anniversary SQL schema and sync lua scripts. `--skip-git` to skip clone, `--database` to set custom DB name. |
| `acm bundle paragon uninstall` | Drop Paragon databases and remove synced lua scripts. `--database` to set custom DB name. |
| `acm create-account` | Create a new WoW account with GM level 3 on the running worldserver (requires `expect`). |
| `acm console` | Attach to the running worldserver console (Ctrl+P then Ctrl+Q to detach). |

Run `./acm <command> --help` for command-specific help.

## Configuration

Edit `conf/wowserver.conf` to set:

| Setting | Description |
|---|---|
| `NAME` | Container image tag and Compose project name (e.g. `playerbots`). |
| `CONTAINER_CMD` | The container command to use. Default: `podman`; set to `docker` for Docker with Compose v2. |
| `BACKUP_DIR` | Directory where backups are stored. Default: `./backups` (relative to the project root). |
| `MAIN_REPO` | Base AzerothCore fork to clone. Append `@branch` for a specific branch. |
| `MODULE_REPO` | One module Git URL per line. Use `@branch` for branches and `#path` for subfolders. |
| `LAUNCH_GAME` | Command to run 5 seconds after the worldserver is healthy (backgrounded, output discarded). |

Multiple configs can be used to run separate server instances. For example, `conf/wowserver-solo.conf` uses `NAME=solo` so containers, volumes, and backups are kept separate from the main config.

## Backups & Retention

### What gets backed up

Two files are created on every backup:

```
./backups/db_backup_<CONFIG_NAME>_YYYYMMDD_HHMMSS.sql.gz      # MySQL dump of all databases
./backups/config_backup_<CONFIG_NAME>_YYYYMMDD_HHMMSS.tar.gz # env/dist/etc/ and lua_scripts/
```

- The database backup uses `mysqldump --all-databases --single-transaction --routines --events --triggers` and compresses with `gzip -9`.
- The config backup archives the server config files and any custom Lua scripts.
- Backups are **scoped by `CONFIG_NAME`**. Multiple server configs sharing the same backup directory will not delete each other's files.

### Backup commands

- **`acm backup`** — Stops the worldserver and authserver, dumps and compresses all databases, archives configs, applies the retention policy, then restarts the services. Use `--skip-stop` to avoid the stop/restart cycle (useful for quick online backups).
- **`acm run`** — Starts the full stack, optionally launches the game, waits for a keypress, then performs the same backup and cleanup sequence before shutting everything down.

### Backup cleanup / retention policy

After every backup, old files are automatically pruned according to the following policy:

| Window | Kept backups |
|---|---|
| Today | **All** backups created today are kept. |
| Last 7 days | The **latest** backup from each day is kept. |
| Next 4 weeks | The **latest** backup from each week is kept. |
| Next 12 months | The **latest** backup from each month is kept. |

Anything not selected by the rules above is deleted. Both database and config backups are cleaned up independently using the same retention rules. Each deletion is logged, and a summary count is printed at the end of cleanup.

For example, if today is August 10th and you have multiple backups per day, the policy will keep:

- Every backup made on August 10th
- The newest backup from August 9th, 8th, 7th, 6th, 5th, 4th, and 3rd
- The newest backup from each of the four previous weeks (July 13th, July 6th, June 29th, June 22nd, etc.)
- The newest backup from each of the previous 12 months (July 2026, June 2026, May 2026, ...)

**Important:** only backups matching the naming pattern `db_backup_<CONFIG_NAME>_*.sql.gz` and `config_backup_<CONFIG_NAME>_*.tar.gz` in the configured backup directory are evaluated. Backups with non-matching names or in other directories are ignored and never deleted.

### Configuring retention

You can customize the retention policy or disable cleanup entirely by adding any of the following settings to your config file:

```bash
# Keep every backup forever (disables the retention policy)
KEEP_ALL_BACKUPS=true

# Number of days' worth of daily backups to retain, including today (default: 7)
BACKUP_RETAIN_DAILY=7

# Number of weekly backups to retain (default: 4)
BACKUP_RETAIN_WEEKLY=4

# Number of monthly backups to retain (default: 12)
BACKUP_RETAIN_MONTHLY=12
```

Set `KEEP_ALL_BACKUPS=true` to keep every backup. When it is enabled, the `BACKUP_RETAIN_*` values are ignored.

### Changing the backup location

The default backup directory is `./backups` (relative to the project root). You can change it by setting `BACKUP_DIR` in your config file:

```bash
BACKUP_DIR=/mnt/backups/wow
```

Relative paths are resolved relative to the project root.

## Restore

Restore a compressed database backup into a fresh database volume:

```bash
./acm restore ./backups/db_backup_playerbots_YYYYMMDD_HHMMSS.sql.gz
```

What happens during restore:

1. The full stack is stopped and the database container is removed.
2. The existing database volume is deleted so the restore is clean.
3. Only the `ac-database` container is started and waited for.
4. The backup is decompressed to a temporary file and restored via `mysql`.
5. The database container is shut down.

After restore completes, start the full stack with:

```bash
./acm start
```

To restore a backup for a different config, pass the config file first:

```bash
./acm restore ./conf/wowserver-solo.conf ./backups/db_backup_solo_YYYYMMDD_HHMMSS.sql.gz
```

## Creating an Account

Make sure the server is running, then:

```bash
./acm create-account testuser mypassword
```

To open the worldserver console manually:

```bash
./acm console
```

Press **Ctrl+P** then **Ctrl+Q** to detach. Do not press **Ctrl+C** — that stops the server.

## Modules

Modules are configured by adding one `MODULE_REPO=<url>` line per module in your config file. For example, in `conf/wowserver.conf`:

```bash
MODULE_REPO=https://github.com/azerothcore/mod-playerbots.git
MODULE_REPO=https://github.com/azerothcore/mod-autobalance.git@master
MODULE_REPO=https://github.com/dr1s/lua-paragon-anniversary.git@main#serverside/mod-paragon-loot
```

### Module URL syntax

| Format | Purpose |
|---|---|
| `https://github.com/user/repo.git` | Clone the default branch. |
| `https://github.com/user/repo.git@branch` | Clone a specific branch or tag. |
| `https://github.com/user/repo.git@branch#path/to/subfolder` | Clone a specific branch and use only a subfolder as the module. |

### How `acm setup` handles modules

- **Clone or update**: Each `MODULE_REPO` is cloned into `./server/<CONFIG_NAME>/modules/<repo-name>/`. If it already exists, `git pull` updates it to the configured branch.
- **Stale module cleanup**: Any directory in `./server/<CONFIG_NAME>/modules/` that is a git repo but is **not** listed in the config is removed automatically. To protect a directory, create a `.stale-keep` file inside it.
- **Skip stale cleanup**: Use `--skip-stale` to keep modules that are not in the config.
- **Module config initialization**: After images are built, `acm setup` copies each module's `*.conf.dist` files from `./modules/<name>/conf/` to `./env/dist/etc/modules/` with the `.dist` suffix removed.

### Example setup with modules

```bash
# Add MODULE_REPO lines to conf/wowserver.conf, then:
./acm setup
```

## Examples

### Start the server with a custom config

```bash
./acm start ./conf/wowserver-solo.conf
```

### Run a play session and back up on shutdown

```bash
./acm run
```

### Skip the game launch and still back up on shutdown

```bash
./acm run --skip-game
```

### Quick backup without stopping the server

```bash
./acm backup --skip-stop
```

### Clean rebuild everything

```bash
./acm setup --clean --no-cache --prune
```

### Update only the source repos and skip the container build

```bash
./acm setup --skip-build
```

### Restore and start

```bash
./acm restore ./backups/db_backup_playerbots_20260810_120000.sql.gz
./acm start
```

## Shell Completion

A shell completion script is included at `completions/acm`. It dynamically completes commands, flags, bundles, subcommands, config files, and backup files.

### Bash

```bash
source /path/to/repo/completions/acm
```

For a system-wide install, copy it to your distribution's completion directory:

```bash
sudo cp /path/to/repo/completions/acm /etc/bash_completion.d/
# or, on some distributions:
sudo cp /path/to/repo/completions/acm /usr/share/bash-completion/completions/acm
```

### Zsh

A zsh completion wrapper is included at `completions/_acm`. Add the `completions` directory to your `fpath` and initialize the completion system:

```zsh
fpath+=(/path/to/repo/completions)
autoload -Uz compinit && compinit
```

Alternatively, you can load the bash completion directly with `bashcompinit`:

```zsh
autoload -Uz bashcompinit && bashcompinit
source /path/to/repo/completions/acm
```

### autoenv / direnv

A `.env` file is included for [autoenv](https://github.com/hyperupcall/autoenv) users, and `.envrc` is a symlink to `.env` for [direnv](https://direnv.net) users. zsh users should use autoenv or load the completion manually.

## Development & Testing

Run the shell syntax checker:

```bash
./tests/check.sh
```

Run the unit tests:

```bash
./tests/run-tests.sh
```
