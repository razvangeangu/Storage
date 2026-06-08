#!/usr/bin/env bash
# Mirror of Storage.app scan targets — run from Terminal.
#
# Usage:
#   ./Scripts/scan-storage.sh                    # overview scan
#   ./Scripts/scan-storage.sh --safe             # skip TCC-sensitive Library folders
#   ./Scripts/scan-storage.sh --top 30             # show more rows in overview
#   ./Scripts/scan-storage.sh --path ~/Developer --level 2
#                                                # expand a path down to N folder levels
#
# Terminal only sees protected folders if Terminal.app (or iTerm, etc.) has
# Full Disk Access in System Settings → Privacy & Security.

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
HOME_DIR="${HOME:?}"
INCLUDE_APP_DATA=true
TOP_N=20
EXPAND_PATH=""
EXPAND_LEVEL=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) INCLUDE_APP_DATA=false; shift ;;
    --include-app-data) INCLUDE_APP_DATA=true; shift ;;
    --top) TOP_N="${2:?}"; shift 2 ;;
    --path) EXPAND_PATH="${2:?}"; shift 2 ;;
    --level) EXPAND_LEVEL="${2:?}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scan-storage.sh                         Overview scan (category breakdown + top items)
  scan-storage.sh --safe                  Skip Containers / Application Support / Mail / Messages
  scan-storage.sh --top N                 Show N largest items in overview (default: 20)
  scan-storage.sh --path PATH --level N   Expand PATH down N folder levels (default level: 1)

Examples:
  scan-storage.sh --top 30
  scan-storage.sh --path "$HOME/Developer/others" --level 1
  scan-storage.sh --path "$HOME/.npm/_cacache" --level 3

Expand mode lists every folder/file found from 1 to N levels below PATH, sized with du.
Parent folder sizes include nested content. Pick a path from the overview "Top" list,
then re-run with --path to drill in deeper (--level 2, 3, …).
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$EXPAND_PATH" ]]; then
  EXPAND_PATH="${EXPAND_PATH/#\~/$HOME_DIR}"
  if [[ -e "$EXPAND_PATH" && -d "$(dirname "$EXPAND_PATH")" ]]; then
    EXPAND_PATH="$(cd "$(dirname "$EXPAND_PATH")" && pwd)/$(basename "$EXPAND_PATH")"
  fi
  EXPAND_PATH="${EXPAND_PATH%/}"
fi

if [[ -n "$EXPAND_LEVEL" && ! "$EXPAND_LEVEL" =~ ^[0-9]+$ ]]; then
  echo "Error: --level must be a positive integer" >&2
  exit 1
fi
(( EXPAND_LEVEL >= 1 )) || { echo "Error: --level must be >= 1" >&2; exit 1; }

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

relative_depth() {
  local root="$1" target="$2"
  local root_norm="${root%/}/"
  local target_norm="${target%/}/"
  if [[ "$target_norm" == "$root_norm" ]]; then
    echo 0
    return
  fi
  if [[ "$target_norm" != "$root_norm"* ]]; then
    echo -1
    return
  fi
  local rest="${target_norm#$root_norm}"
  awk -v s="$rest" 'BEGIN { gsub(/\/$/, "", s); n = split(s, a, "/"); print n }'
}

collect_expand_entries() {
  local root="$1"
  local max_level="$2"
  local entry

  if [[ ! -d "$root" ]]; then
    append_unique "$root"
    return
  fi

  while IFS= read -r -d '' entry; do
    append_unique "$entry"
  done < <(find "$root" -mindepth 1 -maxdepth "$max_level" ! -name '.*' -print0 2>/dev/null)
}

collect_overview_entries() {
  local app_root doc_root dev_root lib_root
  local kids=() include_hidden=false
  local d base skip=false s child

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

  local DEV_ROOTS=(
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

  local LIB_ROOTS=(
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

  local SKIP_HOME=(Library Documents Desktop Downloads Developer Movies Music Pictures Applications)
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
}

print_top_items() {
  local sized_file="$1"
  local top_n="$2"
  local bytes path cat_id cat_name depth_marker

  echo "Top ${top_n} items:"
  sort -t $'\t' -k1 -nr "$sized_file" | head -n "$top_n" | while IFS=$'\t' read -r bytes path; do
    cat_id=$(awk -v home="$HOME_DIR" -v path="$path" '
      BEGIN {
        if (path ~ /\.app$/) { print "applications"; exit }
        norm = path; sub(/\/$/, "", norm); norm = norm "/"
        if (norm ~ "^" home "/Documents/" || norm ~ "^" home "/Desktop/" || norm ~ "^" home "/Downloads/") { print "documents"; exit }
        if (index(path, home "/Developer/") || index(path, home "/.npm/") || index(path, home "/.gradle/")) { print "developer"; exit }
        if (norm ~ "^" home "/Library/Caches/") { print "caches"; exit }
        print "other"
      }
    ')
    case "$cat_id" in
      applications) cat_name="Applications" ;;
      documents) cat_name="Documents" ;;
      developer) cat_name="Developer" ;;
      caches) cat_name="Caches" ;;
      logs) cat_name="Logs" ;;
      trash) cat_name="Trash" ;;
      *) cat_name="Other" ;;
    esac
    printf '  %10s  %-14s  %s\n' "$(human_size "$bytes")" "$cat_name" "$path"
    if [[ -z "$EXPAND_PATH" && -d "$path" ]]; then
      printf '             expand: %s --path %q --level 1\n' "$SCRIPT_PATH" "$path"
    fi
  done
}

# --- Main ---

SIZED_FILE=$(mktemp)
trap 'rm -f "$SIZED_FILE"' EXIT

if [[ -n "$EXPAND_PATH" ]]; then
  if [[ ! -e "$EXPAND_PATH" ]]; then
    echo "Error: path does not exist: $EXPAND_PATH" >&2
    exit 1
  fi
  if ! readable "$EXPAND_PATH"; then
    echo "Error: cannot read path: $EXPAND_PATH" >&2
    exit 1
  fi

  collect_expand_entries "$EXPAND_PATH" "$EXPAND_LEVEL"

  if ((${#ALL_ENTRIES[@]} == 0)); then
    append_unique "$EXPAND_PATH"
  fi

  for path in "${ALL_ENTRIES[@]}"; do
    bytes=$(du_bytes "$path" || echo 0)
    (( bytes > 0 )) || continue
    depth=$(relative_depth "$EXPAND_PATH" "$path")
    printf '%s\t%s\t%s\n' "$bytes" "$depth" "$path" >> "$SIZED_FILE"
  done

  root_bytes=$(du_bytes "$EXPAND_PATH" || echo 0)
  echo "Storage expand"
  echo "Path:   $EXPAND_PATH"
  echo "Level:  $EXPAND_LEVEL (folder levels below path)"
  echo "Total:  $(human_size "$root_bytes")"
  echo "Showing top $TOP_N by size (use --top N to change)"
  echo
  printf '%-6s %12s  %s\n' "Depth" "Size" "Path"
  printf '%-6s %12s  %s\n' "-----" "----" "----"

  sort -t $'\t' -k1 -nr "$SIZED_FILE" | head -n "$TOP_N" | while IFS=$'\t' read -r bytes depth path; do
    name=$(basename "$path")
    if [[ -d "$path" ]]; then
      printf '  L%-4s %10s  %s/\n' "$depth" "$(human_size "$bytes")" "$path"
      printf '             expand: %s --path %q --level 1\n' "$SCRIPT_PATH" "$path"
      if (( EXPAND_LEVEL > 1 && depth < EXPAND_LEVEL )); then
        printf '             or:     %s --path %q --level %d\n' "$SCRIPT_PATH" "$EXPAND_PATH" "$((EXPAND_LEVEL + 1))"
      fi
    else
      printf '  L%-4s %10s  %s\n' "$depth" "$(human_size "$bytes")" "$path"
    fi
  done
  exit 0
fi

collect_overview_entries

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

export HOME_DIR SIZED_FILE hidden disk_total
awk -f - "$SIZED_FILE" <<'AWK'
BEGIN {
  home = ENVIRON["HOME_DIR"]
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

function human(b) {
  if (b < 1024) return sprintf("%d B", b)
  if (b < 1048576) return sprintf("%.0f KB", b/1024)
  if (b < 1073741824) return sprintf("%.1f MB", b/1048576)
  return sprintf("%.2f GB", b/1073741824)
}

function classify(path,    norm, n, p, dev, i) {
  if (path ~ /\.app$/) return "applications"
  norm = path; sub(/\/$/, "", norm); norm = norm "/"
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
  n = split("Developer/,Library/Developer/,.npm/,.gradle/", dev, ",")
  for (i = 1; i <= n; i++) {
    p = home "/" dev[i]
    if (norm ~ ("^" p)) return "developer"
  }
  if (index(path, home) == 1) return "other"
  return "other"
}

{ bytes = $1 + 0; path = substr($0, index($0, "\t") + 1); cat_bytes[classify(path)] += bytes }

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

echo
print_top_items "$SIZED_FILE" "$TOP_N"
