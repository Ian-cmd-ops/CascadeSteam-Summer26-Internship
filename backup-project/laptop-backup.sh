#!/usr/bin/env bash
# laptop-backup.sh — pull /home from the laptop into hardlink snapshots.
# Runs every 15 min from laptop-backup.timer. Snapshots only when something changed.
set -uo pipefail

# ---- config ---------------------------------------------------------------
LAN="${LAN:-ian@10.0.10.X}"
MESH="${MESH:-lubtop}"                            # ssh alias for the mesh peer
SRC="${SRC:-/}"                                   # rrsync on the laptop scopes this to /home/ian
DEST="${DEST:-/mnt/backups/laptop}"
EXCLUDES="${EXCLUDES:-/home/ian/.rsync-excludes}"
LOG="${LOG:-/home/ian/rsync-snapshot/logs/laptop-backup.log}"
NTFY="${NTFY:-http://10.0.25.X/laptop-backup}"
KEEP_DAYS="${KEEP_DAYS:-14}"                      # one snapshot per day beyond 24h, up to this many days
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15)
# ---------------------------------------------------------------------------

log()    { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
notify() { curl -s -m 10 -H "Title: $1" -H "Priority: $2" -d "$3" "$NTFY" >/dev/null 2>&1 || true; }
probe()  { ssh "${SSH_OPTS[@]}" "$1" true 2>/dev/null; }   # overridable in tests

mkdir -p "$DEST" "$(dirname "$LOG")"
exec 9>"$DEST/.lock"
flock -n 9 || exit 0                              # previous run still going

# pick a target; silent exit if the laptop is not around
target=""
for h in "$LAN" "$MESH"; do probe "$h" && { target="$h"; break; }; done
[ -n "$target" ] || { echo "unreachable $(date +%s)" > "$DEST/.last-check"; exit 0; }

# clean any orphaned partial from a killed run (safe: we hold the lock)
find "$DEST" -maxdepth 1 -type d -name '.incomplete-*' -exec rm -rf {} +

stamp=$(date +%Y-%m-%dT%H-%M-%S)
work="$DEST/.incomplete-$stamp"
trap 'rm -rf "$work"' EXIT

linkdest=()
[ -d "$DEST/latest" ] && linkdest=(--link-dest="$DEST/latest")

rsync -aAX --numeric-ids --delete --exclude-from="$EXCLUDES" "${linkdest[@]}" \
      -e "ssh ${SSH_OPTS[*]}" "$target:$SRC" "$work/" >/dev/null 2>"$DEST/.rsync-err"
rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 23 ] && [ "$rc" -ne 24 ]; then
  log "FAIL rsync exit $rc via $target: $(tail -1 "$DEST/.rsync-err")"
  notify "Laptop backup FAILED" high "rsync exit $rc via $target"
  exit "$rc"
fi
skipped=""; [ "$rc" -ne 0 ] && skipped=" (rsync exit $rc, some files skipped; see .rsync-err and excludes)"

# change gate: a transferred file has link count 1; a deletion changes the count
if [ -d "$DEST/latest" ]; then
  changed=$(find "$work" -type f -links 1 -print -quit | wc -l)
  [ "$changed" -eq 0 ] && [ "$(find "$work" -type f | wc -l)" -eq "$(find "$DEST/latest/" -type f | wc -l)" ] \
    && { echo "nochange $(date +%s)" > "$DEST/.last-check"; exit 0; }
fi

# promote atomically
mv "$work" "$DEST/$stamp" || { log "FAIL promote $stamp"; notify "Laptop backup FAILED" high "promote failed for $stamp"; exit 1; }
trap - EXIT
ln -sfn "$stamp" "$DEST/.latest.tmp" && mv -T "$DEST/.latest.tmp" "$DEST/latest"

# prune: keep all <24h, one per day up to KEEP_DAYS, nothing older
now=$(date +%s); seen=""
for d in $(find "$DEST" -maxdepth 1 -type d -name '20*' | sort -r); do
  s=$(basename "$d"); day=${s%%T*}; t=${s#*T}; t=${t//-/:}
  ts=$(date -d "$day $t" +%s 2>/dev/null) || continue
  age=$((now - ts))
  if   [ "$age" -lt 86400 ]; then :
  elif [ "$age" -gt $((KEEP_DAYS*86400)) ] || [ "$day" = "$seen" ]; then rm -rf "$d"
  else seen="$day"; fi
done

today=$(date +%F)
first_today=1; [ "$(cat "$DEST/.last-success" 2>/dev/null)" = "$today" ] && first_today=0
echo "$today" > "$DEST/.last-success"
echo "snapshot $(date +%s)" > "$DEST/.last-check"
log "snapshot $stamp via $target$skipped"
[ "$first_today" -eq 1 ] && notify "Laptop backed up" default "First snapshot today: $stamp via $target"
exit 0
