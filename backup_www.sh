#!/bin/bash
# =============================================================================
#  Linux Web Backup Script – Remote (Google Drive via rclone)
# -----------------------------------------------------------------------------
#  GitHub:  https://github.com/yamiru/linux-web-backup-remote
#  Author:  Yamiru <https://yamiru.com/>
#  License: MIT
# -----------------------------------------------------------------------------
#  Description:
#    Compressed tar.gz backups of website directories.
#    Two modes:
#      - SPLIT_BY_SUBDIR=true   -> each subdirectory of SOURCES is backed up
#                                  into its own .tar.gz (like MySQL per-database)
#      - SPLIT_BY_SUBDIR=false  -> each path in SOURCES is backed up as one
#                                  full .tar.gz archive
#    Backups and logs are stored in separate, configurable folders.
#    Each backup is uploaded to Google Drive (or any rclone remote).
#    Local, Drive, and log retention are rotated by count.
#
#  Requirements:
#    - bash, tar, gzip, find  (standard on any Linux)
#    - rclone                 (https://rclone.org/)
#    - configured rclone remote (run `rclone config` once before first use)
#
#  Local-only sibling project (no cloud upload):
#    https://github.com/yamiru/linux-web-backup
# =============================================================================

# === Storage paths (can point to different folders / different disks) ===
BACKUP_DIR="/opt/linux-web-backup/backups"   # where .tar.gz archives go
LOG_DIR="/opt/linux-web-backup/logs"         # where log files go

# === Rotation settings ===
RETENTION_COUNT=5   # number of backup folders to keep
LOG_RETENTION=5     # number of log files to keep

# === Backup mode ===
# false = back up each path in SOURCES as one archive (DEFAULT)
#         (e.g. /var/www -> www.tar.gz)
# true  = scan each path in SOURCES, back up its subdirectories separately
#         (e.g. /var/www -> web1.tar.gz, web2.tar.gz, ...)
SPLIT_BY_SUBDIR=false

# === Directories to back up ===
# In SPLIT mode  -> parent directories (each subdir becomes its own archive)
# In FULL mode   -> exact directories you want archived
# One path per line. Lines starting with # are comments, empty lines are ignored.
SOURCES=$(cat <<'EOF'
/var/www
# /etc/nginx/sites-available
EOF
)

# === Excluded subdirectory names (only used when SPLIT_BY_SUBDIR=true) ===
# Subdirectories with these names will be skipped during split-mode scanning.
# Analogous to skipping mysql/sys/information_schema in MySQL backups.
EXCLUDE_SUBDIRS=$(cat <<'EOF'
html
.well-known
_letsencrypt
EOF
)

# === Google Drive upload (rclone) ===
# Requires `rclone` installed and a configured remote.
# Quick setup:
#   1) sudo apt install rclone   (or curl https://rclone.org/install.sh | sudo bash)
#   2) rclone config             (create a remote, e.g. name it "gdrive")
#   3) rclone lsd gdrive:        (test that it works)
RCLONE_ENABLE=true                # set to false to disable Drive upload
RCLONE_REMOTE="gdrive"            # name of the remote you created with `rclone config`
RCLONE_PATH="linux-web-backup"    # folder inside the remote where backups go
RCLONE_RETENTION=5                # number of backup folders to keep on Drive

# =============================================================================
#  Below this line you normally don't need to change anything.
# =============================================================================

DATE=$(date +"%F_%H%M%S")
TODAYS_BACKUP_DIR="$BACKUP_DIR/$DATE"
LOG_FILE="$LOG_DIR/backup_${DATE}.log"

# pipefail so tar | gzip reports failure correctly
set -o pipefail

# Ensure storage directories exist before first log() call
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Logging helper – writes to both stdout and the log file
log() { echo "[$(date +'%F %T')] $*" | tee -a "$LOG_FILE"; }

mkdir -p "$TODAYS_BACKUP_DIR"
log "--- WWW Backup started (mode: $([ "$SPLIT_BY_SUBDIR" = "true" ] && echo SPLIT || echo FULL)) ---"

# Check tar
if ! command -v tar >/dev/null 2>&1; then
    log "ERROR: tar command not found!"
    exit 1
fi

# Check gzip
if ! command -v gzip >/dev/null 2>&1; then
    log "ERROR: gzip command not found!"
    exit 1
fi

FAILED=0
SUCCEEDED=0
SKIPPED=0

# -----------------------------------------------------------------------------
# Helper: archive a single path -> <name>.tar.gz inside TODAYS_BACKUP_DIR
# Args:  $1 = source path, $2 = archive base name (without extension)
# -----------------------------------------------------------------------------
archive_path() {
    local SRC="$1"
    local NAME="$2"
    local BACKUP_FILE="$TODAYS_BACKUP_DIR/${NAME}.tar.gz"

    # handle name collisions
    if [ -e "$BACKUP_FILE" ]; then
        local SUFFIX=1
        while [ -e "$TODAYS_BACKUP_DIR/${NAME}_${SUFFIX}.tar.gz" ]; do
            SUFFIX=$((SUFFIX+1))
        done
        BACKUP_FILE="$TODAYS_BACKUP_DIR/${NAME}_${SUFFIX}.tar.gz"
    fi

    log "Backing up $SRC -> $(basename "$BACKUP_FILE")..."

    local PARENT TARGET
    PARENT=$(dirname "$SRC")
    TARGET=$(basename "$SRC")

    if tar --warning=no-file-changed --warning=no-file-removed \
            -C "$PARENT" -cf - "$TARGET" 2>>"$LOG_FILE" | gzip -9 > "$BACKUP_FILE"; then
        if [ -s "$BACKUP_FILE" ]; then
            log "OK: $SRC saved ($(du -h "$BACKUP_FILE" | cut -f1))"
            SUCCEEDED=$((SUCCEEDED+1))
        else
            log "ERROR: $SRC – output file is empty"
            rm -f "$BACKUP_FILE"
            FAILED=$((FAILED+1))
        fi
    else
        local RC=${PIPESTATUS[0]}
        if [ "$RC" = "1" ] && [ -s "$BACKUP_FILE" ]; then
            log "OK (with warnings): $SRC saved ($(du -h "$BACKUP_FILE" | cut -f1))"
            SUCCEEDED=$((SUCCEEDED+1))
        else
            log "ERROR: Failed to backup $SRC (tar rc=$RC)"
            rm -f "$BACKUP_FILE"
            FAILED=$((FAILED+1))
        fi
    fi
}

# -----------------------------------------------------------------------------
# Helper: check whether subdir name is in EXCLUDE_SUBDIRS list
# -----------------------------------------------------------------------------
is_excluded() {
    local NAME="$1"
    while IFS= read -r EX; do
        EX="${EX%%#*}"
        EX="$(echo "$EX" | xargs)"
        [ -z "$EX" ] && continue
        if [ "$EX" = "$NAME" ]; then
            return 0
        fi
    done <<< "$EXCLUDE_SUBDIRS"
    return 1
}

# -----------------------------------------------------------------------------
# Main loop over SOURCES
# -----------------------------------------------------------------------------
while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%%#*}"
    LINE="$(echo "$LINE" | xargs)"
    [ -z "$LINE" ] && continue

    SRC="$LINE"

    if [ ! -e "$SRC" ]; then
        log "WARNING: Source does not exist, skipping: $SRC"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    if [ "$SPLIT_BY_SUBDIR" = "true" ] && [ -d "$SRC" ]; then
        # Auto-detect subdirectories and back each up separately
        log "Scanning subdirectories in $SRC..."

        FOUND=0
        while IFS= read -r -d '' SUB; do
            SUBNAME=$(basename "$SUB")

            if is_excluded "$SUBNAME"; then
                log "Skipping excluded subdir: $SUB"
                SKIPPED=$((SKIPPED+1))
                continue
            fi

            FOUND=$((FOUND+1))
            archive_path "$SUB" "$SUBNAME"
        done < <(find "$SRC" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

        if [ "$FOUND" -eq 0 ]; then
            log "WARNING: No subdirectories found in $SRC – nothing to back up here."
        fi
    else
        # FULL mode – archive the path as a single tar.gz
        NAME=$(basename "$SRC")
        [ -z "$NAME" ] || [ "$NAME" = "/" ] && NAME="root"
        archive_path "$SRC" "$NAME"
    fi
done <<< "$SOURCES"

# If today's folder is empty, remove it
if [ -z "$(ls -A "$TODAYS_BACKUP_DIR" 2>/dev/null)" ]; then
    rmdir "$TODAYS_BACKUP_DIR" 2>/dev/null
fi

# -----------------------------------------------------------------------------
# Google Drive upload (rclone)
# -----------------------------------------------------------------------------
if [ "$RCLONE_ENABLE" = "true" ] && [ "$SUCCEEDED" -gt 0 ]; then
    if ! command -v rclone >/dev/null 2>&1; then
        log "WARNING: rclone not installed – skipping Google Drive upload."
        log "         Install with: curl https://rclone.org/install.sh | sudo bash"
    elif ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:$"; then
        log "WARNING: rclone remote '${RCLONE_REMOTE}:' not configured – skipping upload."
        log "         Run: rclone config   to create it."
    else
        REMOTE_TARGET="${RCLONE_REMOTE}:${RCLONE_PATH}/${DATE}"
        log "Uploading to Google Drive: ${REMOTE_TARGET}..."

        if rclone copy "$TODAYS_BACKUP_DIR" "$REMOTE_TARGET" \
                --transfers=2 --checkers=4 \
                --log-file="$LOG_FILE" --log-level INFO 2>>"$LOG_FILE"; then
            log "OK: Drive upload finished."

            # Drive rotation: keep last RCLONE_RETENTION folders
            log "Drive rotation: keeping last $RCLONE_RETENTION backups..."
            REMOTE_DIRS=$(rclone lsd "${RCLONE_REMOTE}:${RCLONE_PATH}" 2>>"$LOG_FILE" \
                | awk '{print $NF}' | sort -r)

            DRIVE_INDEX=0
            while IFS= read -r RDIR; do
                [ -z "$RDIR" ] && continue
                DRIVE_INDEX=$((DRIVE_INDEX+1))
                if [ "$DRIVE_INDEX" -gt "$RCLONE_RETENTION" ]; then
                    log "Removing old Drive backup: ${RCLONE_PATH}/${RDIR}"
                    rclone purge "${RCLONE_REMOTE}:${RCLONE_PATH}/${RDIR}" 2>>"$LOG_FILE" \
                        && log "  -> removed" \
                        || log "  -> WARNING: failed to remove ${RDIR}"
                fi
            done <<< "$REMOTE_DIRS"
        else
            log "ERROR: Drive upload FAILED. Local backup is fine, but Drive copy did not finish."
            log "       Check log above for rclone error details."
        fi
    fi
elif [ "$RCLONE_ENABLE" = "true" ] && [ "$SUCCEEDED" -eq 0 ]; then
    log "Skipping Drive upload (no successful local backup)."
fi

# Backup rotation
if [ "$SUCCEEDED" -gt 0 ]; then
    log "Rotation: keeping last $RETENTION_COUNT backups..."
    BACKUP_DIRS=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
        -printf '%T@ %p\n' | sort -rn | awk '{print $2}')

    INDEX=0
    while IFS= read -r DIR; do
        [ -z "$DIR" ] && continue
        INDEX=$((INDEX+1))
        if [ "$INDEX" -gt "$RETENTION_COUNT" ]; then
            log "Removing old backup: $DIR"
            rm -rf "$DIR"
        fi
    done <<< "$BACKUP_DIRS"
else
    log "WARNING: no successful backup – skipping rotation."
fi

# Log rotation – always
LOG_FILES=$(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type f -name 'backup_*.log' \
    -printf '%T@ %p\n' | sort -rn | awk '{print $2}')

LOG_INDEX=0
while IFS= read -r LF; do
    [ -z "$LF" ] && continue
    LOG_INDEX=$((LOG_INDEX+1))
    if [ "$LOG_INDEX" -gt "$LOG_RETENTION" ]; then
        log "Removing old log: $LF"
        rm -f "$LF"
    fi
done <<< "$LOG_FILES"

if [ "$FAILED" -gt 0 ]; then
    log "Backup finished WITH ERRORS. OK: $SUCCEEDED, FAIL: $FAILED, SKIP: $SKIPPED. Saved in $TODAYS_BACKUP_DIR"
    exit 1
fi

log "Backup finished. Saved in $TODAYS_BACKUP_DIR (sources: $SUCCEEDED, skipped: $SKIPPED)"
exit 0
