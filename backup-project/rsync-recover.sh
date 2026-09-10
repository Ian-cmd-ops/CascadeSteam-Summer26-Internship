#!/usr/bin/env bash
# LotL recovery: pull a snapshot from the N100 and restore it.
# Run this ON THE RESTORE MACHINE (e.g. VM 201), not the laptop.
#
# Safe by default: with no --run it only previews (dry run). It never
# uses --delete, so a restore adds and overwrites but does not remove
# files already in the destination.

set -uo pipefail

# ---------------- config ----------------
SRC_HOST="10.0.20.X"                # N100 LAN IP. Use the mesh IP off-network.
SRC_USER="ian"                          # login user on the N100
REPO_ROOT="/mnt/backups/mirror-laptop"  # snapshot root on the N100
DEST="/home/ian/"                       # restore target (trailing slash matters)
# ----------------------------------------

SNAPSHOT="latest"
DO_RUN=0
AS_ROOT=0
ASSUME_YES=0
LIST=0
KEYFILE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  --list              list snapshots on the N100, then exit
  --snapshot NAME     snapshot to restore (default: latest)
  --dest PATH         restore target dir (default: $DEST)
  --host IP           N100 address (default: $SRC_HOST; use mesh IP off-network)
  --run               actually restore (default is a dry-run preview)
  --yes               skip the confirmation prompt on --run
  --as-root KEYFILE   pull as root with KEYFILE, keep original owners
  -h, --help          show this help

Examples:
  $(basename "$0") --list
  $(basename "$0")                       # dry run of 'latest' -> $DEST
  $(basename "$0") --run                 # real restore of 'latest'
  $(basename "$0") --snapshot 2026-08-13T09-00-00 --run
EOF
}

# ---- parse args ----
while [ $# -gt 0 ]; do
  case "$1" in
    --list)     LIST=1; shift ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --dest)     DEST="$2"; shift 2 ;;
    --host)     SRC_HOST="$2"; shift 2 ;;
    --run)      DO_RUN=1; shift ;;
    --yes)      ASSUME_YES=1; shift ;;
    --as-root)  AS_ROOT=1; KEYFILE="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# ---- build access model ----
SSH_OPTS=(-o ConnectTimeout=15)
RSYNC_SUDO=()
NUMID=()
if [ "$AS_ROOT" -eq 1 ]; then
  [ -r "$KEYFILE" ] || { echo "ERROR: keyfile not readable: $KEYFILE" >&2; exit 1; }
  REMOTE="root@$SRC_HOST"
  SSH_OPTS+=(-i "$KEYFILE")
  RSYNC_SUDO=(sudo)      # local sudo, to write arbitrary owners
  NUMID=(--numeric-ids)  # keep original UIDs/GIDs
else
  REMOTE="$SRC_USER@$SRC_HOST"
fi

# ---- reachability gate (fail fast, no hang) ----
if ! ssh "${SSH_OPTS[@]}" "$REMOTE" true 2>/dev/null; then
  echo "ERROR: cannot reach $REMOTE." >&2
  echo "Check the network/VLAN and that your key or password works." >&2
  exit 1
fi

# ---- list mode ----
if [ "$LIST" -eq 1 ]; then
  echo "Snapshots on $REMOTE:$REPO_ROOT"
  ssh "${SSH_OPTS[@]}" "$REMOTE" "ls -1 '$REPO_ROOT'"
  exit 0
fi

# ---- verify the chosen snapshot exists ----
if ! ssh "${SSH_OPTS[@]}" "$REMOTE" "test -e '$REPO_ROOT/$SNAPSHOT'"; then
  echo "ERROR: snapshot '$SNAPSHOT' not found under $REPO_ROOT" >&2
  echo "Run with --list to see what is available." >&2
  exit 1
fi

SRC_PATH="$REPO_ROOT/$SNAPSHOT/"
RSH="ssh ${SSH_OPTS[*]}"

# ---- confirm before a real, destructive restore ----
if [ "$DO_RUN" -eq 1 ] && [ "$ASSUME_YES" -ne 1 ]; then
  echo "WARNING: this overwrites files under $DEST with snapshot '$SNAPSHOT'."
  echo "It does not delete extra files already in $DEST."
  printf "Type YES to proceed: "
  read -r ans
  [ "$ans" = "YES" ] || { echo "aborted."; exit 1; }
fi

# ---- run ----
if [ "$DO_RUN" -eq 1 ]; then
  echo ">> RESTORING '$SNAPSHOT' -> $DEST"
  "${RSYNC_SUDO[@]}" rsync -aAX "${NUMID[@]}" --info=stats1 \
    -e "$RSH" "$REMOTE:$SRC_PATH" "$DEST"
  rc=$?
else
  echo ">> DRY RUN. No changes made. Add --run to restore for real."
  echo ">> Would restore '$SNAPSHOT' -> $DEST"
  "${RSYNC_SUDO[@]}" rsync -aAXn "${NUMID[@]}" --info=stats1 \
    -e "$RSH" "$REMOTE:$SRC_PATH" "$DEST"
  rc=$?
fi

# 0 = ok, 24 = files vanished on the source mid-run (benign)
if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
  echo "rsync failed (exit $rc)" >&2
  exit "$rc"
fi

# ---- post-restore hints ----
if [ "$DO_RUN" -eq 1 ]; then
  echo ">> restore complete (rsync exit $rc)"
  for f in apps-apt.txt apps-dpkg.txt apps-flatpak.txt; do
    if [ -f "${DEST%/}/$f" ]; then
      echo ">> found $f in the restore. See the playbook to reinstall apps."
    fi
  done
else
  echo ">> dry run complete. Re-run with --run when the preview looks right."
fi
