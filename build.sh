#!/bin/bash

# 1. FAIL SAFE: Stop immediately if any command returns an error
set -e

# Configuration
AC_DIR="$HOME/azerothcore-wotlk"
BUILD_DIR="$AC_DIR/build"
BACKUP_ROOT="$HOME/ac_backups"
MAX_BACKUPS=5

# Parse Args
FORCE=false
CLEAN=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --clean) CLEAN=true ;;
    esac
done

echo "Using AzerothCore directory: $AC_DIR"

# Initialize UPDATED flag based on arguments
if [ "$CLEAN" = true ]; then
    echo "⚠️  Force build enabled (Clean)."
    echo "🧹 Clean build enabled: Wiping build directory."
    rm -rf "$BUILD_DIR"
    UPDATED=true
elif [ "$FORCE" = true ]; then
    echo "⚠️  Force build enabled."
    UPDATED=true
else
    UPDATED=false
fi

# ---------------------------------------
# UPDATE CORE
# ---------------------------------------
echo "🔵 Updating Core..."
cd "$AC_DIR"

BEFORE_CORE=$(git rev-parse HEAD)
git pull
AFTER_CORE=$(git rev-parse HEAD)

if [ "$BEFORE_CORE" != "$AFTER_CORE" ]; then
    echo "   -> Core updated."
    UPDATED=true
fi

# ---------------------------------------
# UPDATE MODULES (Dynamic Loop)
# ---------------------------------------
echo "🔵 Checking Modules..."
# Use nullglob to handle case where no modules match
shopt -s nullglob
for d in modules/*/; do
    if [ -d "$d/.git" ]; then
        cd "$d"
        MOD_NAME=$(basename "$d")
        echo "   -> Checking $MOD_NAME..."
        
        BEFORE_MOD=$(git rev-parse HEAD)
        git pull --quiet
        AFTER_MOD=$(git rev-parse HEAD)

        if [ "$BEFORE_MOD" != "$AFTER_MOD" ]; then
            echo "      [!] Updated!"
            UPDATED=true
        fi
        cd "$AC_DIR"
    fi
done
shopt -u nullglob

if [ "$UPDATED" = false ]; then
    echo "✅ Everything is already up to date. Skipping build and restart."
    exit 0
fi

# ---------------------------------------
# BACKUP (Pre-Build)
# ---------------------------------------
# Only runs if we didn't exit above (meaning UPDATED=true)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_BACKUP="$BACKUP_ROOT/$TIMESTAMP"

echo "💾 Updates detected! Starting Backup to $CURRENT_BACKUP..."
mkdir -p "$CURRENT_BACKUP"

# Database Backup
if command -v mysqldump &> /dev/null; then
    echo "   -> Dumping databases..."
    mysqldump --no-tablespaces -h127.0.0.1 -uacore -pacore acore_auth > "$CURRENT_BACKUP/acore_auth.sql"
    mysqldump --no-tablespaces -h127.0.0.1 -uacore -pacore acore_world > "$CURRENT_BACKUP/acore_world.sql"
    mysqldump --no-tablespaces -h127.0.0.1 -uacore -pacore acore_characters > "$CURRENT_BACKUP/acore_characters.sql"
else
    echo "⚠️  mysqldump not found! Skipping DB backup."
fi

# Configuration Backup
if [ -d "$AC_DIR/env/dist/etc" ]; then
    echo "   -> Backing up configs..."
    mkdir -p "$CURRENT_BACKUP/etc"
    cp -r "$AC_DIR/env/dist/etc/"* "$CURRENT_BACKUP/etc/"
fi

# Cleanup old backups
echo "🧹 Rotating backups (keeping last $MAX_BACKUPS)..."
# List directories by time (newest first), skip the first N, and remove the rest
ls -1dt "$BACKUP_ROOT"/*/ | tail -n +$(($MAX_BACKUPS + 1)) | xargs -r rm -rf

echo "✅ Backup Complete."

# ---------------------------------------
# CALCULATE CORES
# ---------------------------------------
# Calculate available cores safely.
# If you have 8 cores, input '5' leaves 3 cores for the OS.
# If result is < 1, defaults to 1 to prevent crashing.
TOTAL_CORES=$(nproc)
TARGET_CORES=$(($TOTAL_CORES - 5))

if [ "$TARGET_CORES" -lt 1 ]; then
    TARGET_CORES=1
fi
echo "🔵 Building with $TARGET_CORES threads (leaving 5 free)..."

# ---------------------------------------
# BUILD & INSTALL
# ---------------------------------------
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Check if we need to run cmake (Clean run or missing Makefile)
# Note: set -e is on, so if cmake fails script stops.
if [ "$CLEAN" = true ] || [ ! -f "Makefile" ]; then
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX="$AC_DIR/env/dist/" \
        -DCMAKE_C_COMPILER=/usr/bin/clang \
        -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
        -DWITH_WARNINGS=1 \
        -DTOOLS_BUILD=all \
        -DSCRIPTS=static \
        -DMODULES=static
fi

make -j"$TARGET_CORES"
make install

# ---------------------------------------
# RESTART SERVICES
# ---------------------------------------
echo "🔵 Restarting Services..."
sudo systemctl restart ac-authserver.service
sudo systemctl restart ac-worldserver.service

echo "✅ Build and Restart Complete!"
