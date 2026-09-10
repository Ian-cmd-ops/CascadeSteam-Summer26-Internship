#!/usr/bin/env bash
#
# backup-now.sh — run the laptop backup on demand.
#
# Uses the SAME repo and credentials as the scheduled systemd job, so the
# manual run and the daily run can never drift apart. Prints each step so it
# can be shown live. Run with sudo (credentials live under /root).
#
#   sudo ./backup-now.sh            # back up now
#   sudo ./backup-now.sh --check    # back up, then verify repo integrity
#   sudo ./backup-now.sh --dry-run  # show what WOULD change, transfer nothing
#
set -euo pipefail

REPO_FILE="/root/.restic/repo"
PASS_FILE="/root/.restic/pass"
PATHS=(/home /etc /root)
EXCLUDES=(--exclude-caches
          --exclude /home/ian/.cache
          --exclude /home/ian/.local/share/Trash)
MESH_TARGET="<MESH-IP>"   # N100 over Netbird

# --- pretty output ---------------------------------------------------------
b(){ printf '\n\033[1m== %s ==\033[0m\n' "$1"; }   # bold section header
ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
die(){ printf '  \033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

CHECK=0; DRY=0
for a in "$@"; do
  case "$a" in
    --check)   CHECK=1 ;;
    --dry-run) DRY=1 ;;
    *) die "unknown flag: $a" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "run with sudo — credentials are under /root"

b "Preflight"
[ -f "$REPO_FILE" ] || die "missing $REPO_FILE"
[ -f "$PASS_FILE" ] || die "missing $PASS_FILE"
ok "repo:  $(cat "$REPO_FILE")"
ok "paths: ${PATHS[*]}"

b "Reaching the backup target"
if ping -c1 -W3 "$MESH_TARGET" >/dev/null 2>&1; then
  ok "N100 reachable over the mesh ($MESH_TARGET)"
else
  die "N100 not reachable — check 'netbird status' (mesh down or peer asleep)"
fi

RESTIC=(restic --repository-file "$REPO_FILE" --password-file "$PASS_FILE")

b "Repository"
if "${RESTIC[@]}" cat config >/dev/null 2>&1; then
  ok "repo opened and unlocked"
else
  die "cannot open repo — wrong passphrase, or SSH to the target failed"
fi

if [ "$DRY" -eq 1 ]; then
  b "Dry run (nothing is written)"
  "${RESTIC[@]}" backup "${PATHS[@]}" "${EXCLUDES[@]}" --dry-run --verbose
  ok "dry run complete — no data transferred"
  exit 0
fi

b "Backing up"
START=$(date +%s)
"${RESTIC[@]}" backup "${PATHS[@]}" "${EXCLUDES[@]}" --verbose
ELAPSED=$(( $(date +%s) - START ))
ok "backup finished in ${ELAPSED}s"

b "Latest snapshot"
"${RESTIC[@]}" snapshots --latest 1

if [ "$CHECK" -eq 1 ]; then
  b "Verifying repository integrity"
  "${RESTIC[@]}" check
  ok "integrity check passed"
fi

b "Done"
ok "manual backup complete"
