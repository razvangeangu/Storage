#!/usr/bin/env bash
# Mirror of Storage.app scan targets — run from Terminal.
#
# Usage:
#   ./Scripts/scan-storage.sh              # full scan (includes app containers)
#   ./Scripts/scan-storage.sh --safe         # skip TCC-sensitive Library folders (app default)
#   ./Scripts/scan-storage.sh --top 30       # show more rows per category
#
# Terminal only sees protected folders if Terminal.app (or iTerm, etc.) has
# Full Disk Access in System Settings → Privacy & Security. If it does, this
# script can read Containers / Application Support without Storage's per-app prompts.

set -euo pipefail

HOME_DIR="${HOME:?}"
INCLUDE_APP_DATA=true
TOP_N=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) INCLUDE_APP_DATA=false; shift ;;
    --include-app-data) INCLUDE_APP_DATA=true; shift ;;
    --top) TOP_N="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

human_size() {
  awk -v b="$1" 'BEGIN {
    if (b < 1024) printf "%d B", b
    else if (b < 1048576) printf "%.0f KB", b/1024
    else if (b < 1073741824) printf "%.1f MB", b/1048576
    else printf "%.2f GB", b/1073741824
  }'
}

readable() {
  local path="$1"
  [[ -e "$path" ]] || return 1
  if [[ -d "$path" ]]; then
    ls "$path" &>/dev/null
  else
    [[ -r "$path" ]]
  fi
}

planned_entries() {
  local dir="$1"
  local include_hidden="${2:-false}"
  [[ -e "$dir" ]] || return 0

  if [[ ! -d "$dir" ]]; then
    printf '%s\n' "$dir"
    return 0
  fi

  local -a children=()
  if [[ "$include_hidden" == true ]]; then
    while IFS= read -r -d '' child; do children+=("$child"); done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  else
    while IFS= read -r -d '' child; do children+=("$child"); done < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 2>/dev/null)
  fi

  if ((${#children[@]} > 0)); then
    printf '%s\n' "${children[@]}"
  else
    printf '%s\n' "$dir"
  fi
}

# Globals: SEEN_PATHS (newline-separated), ALL_ENTRIES array
SEEN_PATHS=$'\n'
ALL_ENTRIES=()

seen() {
  case "$SEEN_PATHS" in
    *$'\n'"$1"$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}

append_unique() {
  local path
  for path in "$@"; do
    [[ -n "$path" ]] || continue
    if ! seen "$path"; then
      SEEN_PATHS+="$path"$'\n'
      ALL_ENTRIES+=("$path")
    fi
  done
}

drop_nested_paths() {
  local -a sorted=() kept=()
  local path other
  while IFS= read -r path; do
    [[ -n "$path" ]] && sorted+=("$path")
  done < <(printf '%s\n' "${ALL_ENTRIES[@]}" | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2-)
  for path in "${sorted[@]}"; do
    local nested=false
    for other in ${kept[@]+"${kept[@]}"}; do
      if [[ "$path" != "$other" && "$path" == "$other/"* ]]; then
        nested=true
        break
      fi
    done
    [[ "$nested" == false ]] && kept+=("$path")
  done
  ALL_ENTRIES=("${kept[@]}")
}

du_bytes() {
  local path="$1"
  local kb
  kb=$(/usr/bin/du -sk "$path" 2>/dev/null | awk '{print $1}') || return 1
  [[ -n "$kb" && "$kb" =~ ^[0-9]+$ ]] || return 1
  echo $(( kb * 1024 ))
}

# --- Collect scan targets (StorageScanner.buildScanPlan) ---

for app_root in /Applications /System/Applications "$HOME_DIR/Applications"; do
  readable "$app_root" || continue
  while IFS= read -r -d '' app; do
    append_unique "$app"
  done < <(find "$app_root" -name '*.app' -prune -print0 2>/dev/null)
done

for doc_root in \
  "$HOME_DIR/Documents" \
  "$HOME_DIR/Desktop" \
  "$HOME_DIR/Downloads" \
  "$HOME_DIR/Library/Mobile Documents"
do
  readable "$doc_root" || continue
  kids=()
  while IFS= read -r line; do [[ -n "$line" ]] && kids+=("$line"); done < <(planned_entries "$doc_root" false)
  append_unique "${kids[@]}"
done

DEV_ROOTS=(
  "$HOME_DIR/Developer"
  "$HOME_DIR/Library/Developer"
  "$HOME_DIR/Library/Caches/com.apple.dt.Xcode"
  "$HOME_DIR/.android"
  "$HOME_DIR/Library/Android"
  "$HOME_DIR/.gradle"
  "$HOME_DIR/.npm"
  "$HOME_DIR/Library/pnpm"
  "$HOME_DIR/.pnpm-store"
  "$HOME_DIR/.yarn"
  "$HOME_DIR/Library/Caches/Yarn"
  "$HOME_DIR/.bun"
  "$HOME_DIR/.expo"
  "$HOME_DIR/.react-native"
  "$HOME_DIR/.nvm"
  "$HOME_DIR/.fnm"
  "$HOME_DIR/.pub-cache"
  "$HOME_DIR/.cocoapods"
  "$HOME_DIR/.m2"
  "$HOME_DIR/Library/Caches/watchman"
  "$HOME_DIR/.cache/node-gyp"
)
if readable "$HOME_DIR/Library/Application Support/Google"; then
  for d in "$HOME_DIR/Library/Application Support/Google"/AndroidStudio*; do
    [[ -e "$d" ]] && DEV_ROOTS+=("$d")
  done
fi
if readable "$HOME_DIR/Library/Caches/Google"; then
  for d in "$HOME_DIR/Library/Caches/Google"/AndroidStudio*; do
    [[ -e "$d" ]] && DEV_ROOTS+=("$d")
  done
fi
for dev_root in "${DEV_ROOTS[@]}"; do
  readable "$dev_root" || continue
  include_hidden=false
  [[ "$dev_root" == "$HOME_DIR/Developer" ]] && include_hidden=true
  kids=()
  while IFS= read -r line; do [[ -n "$line" ]] && kids+=("$line"); done < <(planned_entries "$dev_root" "$include_hidden")
  append_unique "${kids[@]}"
done

LIB_ROOTS=(
  "$HOME_DIR/Library/Caches"
  "$HOME_DIR/Library/Logs"
  "$HOME_DIR/Movies"
  "$HOME_DIR/Music"
  "$HOME_DIR/Pictures"
  "$HOME_DIR/.Trash"
  /Library/Caches
  /Library/Logs
)
if [[ "$INCLUDE_APP_DATA" == true ]]; then
  LIB_ROOTS=(
    "$HOME_DIR/Library/Application Support"
    "$HOME_DIR/Library/Containers"
    "$HOME_DIR/Library/Group Containers"
    "$HOME_DIR/Library/Mail"
    "$HOME_DIR/Library/Messages"
    "${LIB_ROOTS[@]}"
  )
fi
for lib_root in "${LIB_ROOTS[@]}"; do
  readable "$lib_root" || continue
  kids=()
  while IFS= read -r line; do [[ -n "$line" ]] && kids+=("$line"); done < <(planned_entries "$lib_root" false)
  append_unique "${kids[@]}"
done

SKIP_HOME=(Library Documents Desktop Downloads Developer Movies Music Pictures Applications)
if readable "$HOME_DIR"; then
  while IFS= read -r -d '' child; do
    base=$(basename "$child")
    skip=false
    for s in "${SKIP_HOME[@]}"; do [[ "$base" == "$s" ]] && skip=true; done
    [[ "$skip" == true ]] && continue
    readable "$child" && append_unique "$child"
  done < <(find "$HOME_DIR" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 2>/dev/null)
fi

drop_nested_paths

# --- Size entries → TSV: bytes, path ---
SIZED_FILE=$(mktemp)
trap 'rm -f "$SIZED_FILE"' EXIT
total_accounted=0

for path in "${ALL_ENTRIES[@]}"; do
  bytes=$(du_bytes "$path" || echo 0)
  (( bytes > 0 )) || continue
  printf '%s\t%s\n' "$bytes" "$path" >> "$SIZED_FILE"
  total_accounted=$(( total_accounted + bytes ))
done

read -r disk_total disk_avail disk_used_pct < <(df -k / | awk 'NR==2 { print $2*1024, $4*1024, $5 }')
disk_used=$(( disk_total - disk_avail ))
hidden=$(( disk_used - total_accounted ))
(( hidden < 0 )) && hidden=0
vol_name=$(diskutil info / 2>/dev/null | awk -F': ' '/Volume Name/ { print $2; exit }')
[[ -z "$vol_name" ]] && vol_name="Macintosh HD"

echo "Storage scan (terminal)"
echo "Volume: ${vol_name:-Macintosh HD}"
echo "Total:  $(human_size "$disk_total")  Used: $(human_size "$disk_used")  Free: $(human_size "$disk_avail")  (${disk_used_pct} used)"
if [[ "$INCLUDE_APP_DATA" == false ]]; then
  echo "Mode:   safe (app containers skipped — matches Storage.app default)"
else
  echo "Mode:   full (includes Application Support, Containers, Mail, Messages)"
fi
echo

export HOME_DIR SIZED_FILE TOP_N hidden disk_total
awk -f - "$SIZED_FILE" <<'AWK'
BEGIN {
  home = ENVIRON["HOME_DIR"]
  top_n = ENVIRON["TOP_N"] + 0
  hidden = ENVIRON["hidden"] + 0
  disk_total = ENVIRON["disk_total"] + 0

  order[1]="applications"; names["applications"]="Applications"
  order[2]="documents";    names["documents"]="Documents"
  order[3]="photos";       names["photos"]="Photos"
  order[4]="developer";    names["developer"]="Developer"
  order[5]="ios_backups";  names["ios_backups"]="iOS Backups"
  order[6]="mail";         names["mail"]="Mail"
  order[7]="messages";     names["messages"]="Messages"
  order[8]="system_data";  names["system_data"]="System Data"
  order[9]="containers";   names["containers"]="Containers"
  order[10]="caches";      names["caches"]="Caches"
  order[11]="logs";        names["logs"]="Logs"
  order[12]="snapshots";   names["snapshots"]="Time Machine Snapshots"
  order[13]="trash";       names["trash"]="Trash"
  order[14]="other";       names["other"]="Other"
  order_count = 14
}

function human(b,    s) {
  if (b < 1024) return sprintf("%d B", b)
  if (b < 1048576) return sprintf("%.0f KB", b/1024)
  if (b < 1073741824) return sprintf("%.1f MB", b/1048576)
  return sprintf("%.2f GB", b/1073741824)
}

function classify(path,    norm, n, p, dev, i) {
  if (path ~ /\.app$/) return "applications"
  if (path ~ /\.app\//) return "applications"
  norm = path
  sub(/\/$/, "", norm)
  norm = norm "/"

  if (norm ~ /^\/Applications\// || norm ~ "^" home "/Applications/") return "applications"
  if (norm ~ "^" home "/Documents/" || norm ~ "^" home "/Desktop/" || norm ~ "^" home "/Downloads/" || norm ~ "^" home "/Library/Mobile Documents/") return "documents"
  if (norm ~ "^" home "/Pictures/") return "photos"
  if (norm ~ "^" home "/Library/Application Support/MobileSync/") return "ios_backups"
  if (norm ~ "^" home "/Library/Application Support/") return "applications"
  if (norm ~ "^" home "/Library/Mail/") return "mail"
  if (norm ~ "^" home "/Library/Messages/") return "messages"
  if (norm ~ "^" home "/.Trash/") return "trash"
  if (norm ~ "^" home "/Library/Caches/" || norm ~ /^\/Library\/Caches\//) return "caches"
  if (norm ~ "^" home "/Library/Logs/" || norm ~ /^\/Library\/Logs\//) return "logs"
  if (norm ~ "^" home "/Library/Containers/" || norm ~ "^" home "/Library/Group Containers/") return "containers"
  if (norm ~ /^\/private\/var\/folders\//) return "system_data"
  if (norm ~ /^\/\.MobileBackups\// || norm ~ /^\/\.MobileBackups\.trash\//) return "snapshots"

  n = split("Developer/,Library/Developer/,Library/Caches/com.apple.dt.Xcode/,Library/Caches/Yarn/,Library/Caches/watchman/,Library/pnpm/,Library/Android/,Library/Application Support/Google/AndroidStudio,Library/Caches/Google/AndroidStudio,Library/Application Support/expo/,.npm/,.pnpm-store/,.local/share/pnpm/,.yarn/,.bun/,.expo/,.android/,.gradle/,.nvm/,.fnm/,.local/share/fnm/,.pub-cache/,.cocoapods/,.m2/,.react-native/,.metro/,.cache/node-gyp/,.cache/typescript/,.cache/pnpm/", dev, ",")
  for (i = 1; i <= n; i++) {
    p = home "/" dev[i]
    if (norm ~ ("^" p) || path == substr(p, 1, length(p)-1)) return "developer"
  }
  if (index(path, home) == 1) return "other"
  return "other"
}

{
  bytes = $1 + 0
  path = substr($0, index($0, "\t") + 1)
  cat = classify(path)
  cat_bytes[cat] += bytes
}

END {
  printf "%-22s %12s  %5s\n", "Category", "Size", "% disk"
  printf "%-22s %12s  %5s\n", "--------", "----", "------"
  for (i = 1; i <= order_count; i++) {
    id = order[i]
    if (cat_bytes[id] > 0) {
      pct = (disk_total > 0) ? (100 * cat_bytes[id] / disk_total) : 0
      printf "%-22s %12s  %4.1f%%\n", names[id], human(cat_bytes[id]), pct
    }
  }
  if (hidden > 0) {
    pct = (disk_total > 0) ? (100 * hidden / disk_total) : 0
    printf "%-22s %12s  %4.1f%%\n", "Other & system", human(hidden), pct
  }
}
AWK

echo "Top ${TOP_N} items:"
sort -t $'\t' -k1 -nr "$SIZED_FILE" | head -n "$TOP_N" | while IFS=$'\t' read -r bytes path; do
  cat_id=$(awk -v home="$HOME_DIR" -v path="$path" '
    function classify(p,    norm, n, dev, i, pref) {
      if (p ~ /\.app$/) { print "applications"; exit }
      norm = p; sub(/\/$/, "", norm); norm = norm "/"
      if (norm ~ /^\/Applications\// || norm ~ "^" home "/Applications/") { print "applications"; exit }
      if (norm ~ "^" home "/Documents/" || norm ~ "^" home "/Desktop/" || norm ~ "^" home "/Downloads/" || norm ~ "^" home "/Library/Mobile Documents/") { print "documents"; exit }
      if (norm ~ "^" home "/Pictures/") { print "photos"; exit }
      if (norm ~ "^" home "/Library/Application Support/") { print "applications"; exit }
      if (norm ~ "^" home "/Library/Caches/" || norm ~ /^\/Library\/Caches\//) { print "caches"; exit }
      if (norm ~ "^" home "/Library/Logs/" || norm ~ /^\/Library\/Logs\//) { print "logs"; exit }
      if (norm ~ "^" home "/.Trash/") { print "trash"; exit }
      if (index(p, home "/Developer/") || index(p, home "/.npm/") || index(p, home "/.gradle/")) { print "developer"; exit }
      print "other"
    }
    BEGIN { classify(path) }
  ')
  case "$cat_id" in
    applications) cat_name="Applications" ;;
    documents) cat_name="Documents" ;;
    photos) cat_name="Photos" ;;
    developer) cat_name="Developer" ;;
    caches) cat_name="Caches" ;;
    logs) cat_name="Logs" ;;
    trash) cat_name="Trash" ;;
    *) cat_name="Other" ;;
  esac
  printf '  %10s  %-14s  %s\n' "$(human_size "$bytes")" "$cat_name" "$path"
done
