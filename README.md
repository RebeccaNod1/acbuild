# AzerothCore Build & Maintenance Script

A custom Bash script for managing [AzerothCore](https://www.azerothcore.org/) server updates, builds, and backups.

## Features

- **Automated Backups**: Automatically dumps `auth`, `world`, and `characters` databases + `etc` configs before every update.
- **Smart Updates**: Checks git revision for Core and all Modules. Skips rebuild if no changes (unless forced).
- **Core Resource Management**: Calculates available CPU cores to maximize build speed without freezing the OS.
- **Service Management**: Automatically restarts `ac-authserver` and `ac-worldserver` systemd services after install.

## Usage

```bash
./build.sh [options]
```

### Options

| Option    | Description |
|-----------|-------------|
| `--force` | Force a full rebuild and update, ignoring git status. |
| `--clean` | Wipe the `build` directory and start fresh (CMake + Make). |

## Backup Location

Backups are stored in:
`~/ac_backups/YYYYMMDD_HHMMSS/`

Contains:
- `acore_auth.sql` (`--no-tablespaces` for privilege safety)
- `acore_world.sql`
- `acore_characters.sql`
- `etc/` (Configuration files)

## Requirements

- `mysqldump` (for database backups)
- `git`
- `cmake`, `clang`, `make`
- User must have `sudo` privileges for systemd restarts.

## Configuration

**Note:** The script defaults to the standard AzerothCore credentials (`User: acore`, `Password: acore`).
If you have changed your database password, you **must** edit the `mysqldump` commands in `build.sh` to match your setup.

## Installation

```bash
git clone https://github.com/RebeccaNod1/acbuild.git ~/acbuild
chmod +x ~/acbuild/build.sh
```
