# AzerothCore Build & Maintenance Script

A custom Bash script for managing [AzerothCore](https://www.azerothcore.org/) server updates, builds, and backups.

## Features

- **Automated Backups**: Automatically dumps databases and configs **only** when an update is detected or forced.
- **Backup Rotation**: Automatically keeps a configurable number of backups (default: 5) and prunes old ones.
- **Smart Updates**: Checks git revision for Core and all Modules. Skips rebuild if no changes (unless forced).
- **Core Resource Management**: Calculates available CPU cores to maximize build speed without freezing the OS.
- **Service Management**: Automatically restarts `ac-authserver` and `ac-worldserver` systemd services after install.
- **Changelog Generation**: Generates a `changelog.txt` artifact summarizing core and module updates.
- **Jenkins Integration**: Natively supports Jenkins `Source Code Management` to populate the `Changes` tab while still correctly identifying and pulling updates for modules.

## Usage

```bash
./build.sh [options]
```

### Options

| Option    | Description |
|-----------|-------------|
| `--force` | Perform a full rebuild and update. Still attempts to `git pull` but proceeds even if no updates are found. |
| `--clean` | Wipe the `build` directory and start fresh (CMake + Make). |

## Backup Location

Backups are stored in `~/ac_backups/YYYYMMDD_HHMMSS/`. The script automatically prunes oldest backups to keep the count within the `MAX_BACKUPS` limit defined in `build.sh`.

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

## Jenkins Integration

This script is fully optimized to run via Jenkins and provides two major quality-of-life features:
1. **Changelog Artifacts**: The script generates a `changelog.txt` file and automatically copies it to your Jenkins `$WORKSPACE` if run via a job. You can view this by adding **Archive the artifacts** in your Post-build Actions and targeting `changelog.txt`. This changelog includes updates from *both* the core and installed modules.
2. **Native "Changes" Tab Support**: The script is "Jenkins Aware". It detects when Jenkins has natively pulled an update via the `GIT_PREVIOUS_COMMIT` and `GIT_COMMIT` variables.

### Jenkins Setup Guide
To get the most out of the Jenkins integration:
1. Create a **Freestyle Project**.
2. Under **Source Code Management**, select **Git**.
3. Set the Repository URL to: `https://github.com/azerothcore/azerothcore-wotlk.git`
4. Under **Additional Behaviors**, click Add -> **Check out to a sub-directory**. Set Local subdirectory to: `azerothcore-wotlk`. (Note: Ignore the Jenkins warning about using this in a pipeline, it is safe for Freestyle projects).
5. **CRITICAL**: Under **Additional Behaviors**, click Add -> **Advanced clone behaviours**. Change the **Timeout (in minutes)** to `60` to ensure the initial massive checkout does not time out.
6. Under **Build Steps**, add an **Execute shell** step and call the script (e.g., `/home/richard/acbuild/build.sh`).
7. Under **Post-build Actions**, add **Archive the artifacts** and specify `changelog.txt`.

## Installation

```bash
git clone https://github.com/RebeccaNod1/acbuild.git ~/acbuild
chmod +x ~/acbuild/build.sh
```

## Disclaimer

This script was created with the assistance of AI. Always review code before running it on your production server.
