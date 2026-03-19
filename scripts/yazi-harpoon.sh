#!/usr/bin/env bash
set -euo pipefail

STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
STATE_DIR="$STATE_HOME/yazi-harpoon"
MARKS_FILE="$STATE_DIR/marks"
CURSOR_FILE="$STATE_DIR/cursor"

usage() {
  cat <<'EOF'
Usage:
  yazi-harpoon.sh add [path]         Add a file/dir mark (defaults to hovered path if passed by keymap)
  yazi-harpoon.sh list               List marks with indexes
  yazi-harpoon.sh jump <index> [--emit]
                                     Print mark path, or emit a Yazi jump when --emit is used
  yazi-harpoon.sh menu [--emit]      Pick a mark via fzf (or first mark), print or emit jump
  yazi-harpoon.sh next [--emit]      Cycle to next mark
  yazi-harpoon.sh prev [--emit]      Cycle to previous mark
  yazi-harpoon.sh remove <index|path>
                                     Remove a mark by index or exact path
  yazi-harpoon.sh clear              Clear all marks

Examples:
  yazi-harpoon.sh add ~/Workspace/project
  yazi-harpoon.sh jump 2
  yazi-harpoon.sh menu --emit
EOF
}

ensure_state() {
  mkdir -p "$STATE_DIR"
  [ -f "$MARKS_FILE" ] || : > "$MARKS_FILE"
  [ -f "$CURSOR_FILE" ] || echo "1" > "$CURSOR_FILE"
}

abs_path() {
  p=${1:-"$PWD"}
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$p"
  else
    case "$p" in
      /*) printf '%s\n' "$p" ;;
      *) printf '%s/%s\n' "$PWD" "$p" ;;
    esac
  fi
}

is_int() {
  case ${1:-} in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

count_marks() {
  awk 'END { print NR }' "$MARKS_FILE"
}

mark_at() {
  idx=$1
  sed -n "${idx}p" "$MARKS_FILE"
}

emit_jump() {
  target=$1
  if ! command -v ya >/dev/null 2>&1; then
    echo "'ya' command not found. Cannot emit jump to Yazi." >&2
    return 1
  fi

  if [ -d "$target" ]; then
    ya emit cd "$target"
  else
    ya emit reveal "$target"
  fi
}

cmd_add() {
  target=$(abs_path "${1:-$PWD}")

  if ! grep -Fx -- "$target" "$MARKS_FILE" >/dev/null 2>&1; then
    printf '%s\n' "$target" >> "$MARKS_FILE"
    echo "Added: $target"
  else
    echo "Already marked: $target"
  fi
}

cmd_list() {
  if [ ! -s "$MARKS_FILE" ]; then
    echo "No marks yet."
    return 0
  fi
  nl -w2 -s'  ' "$MARKS_FILE"
}

cmd_jump_like() {
  idx=$1
  emit_mode=${2:-}
  target=$(mark_at "$idx")

  if [ -z "$target" ]; then
    echo "No mark at index $idx" >&2
    exit 1
  fi

  if [ "$emit_mode" = "--emit" ]; then
    emit_jump "$target"
  else
    printf '%s\n' "$target"
  fi

  echo "$idx" > "$CURSOR_FILE"
}

cmd_menu() {
  emit_mode=${1:-}

  if [ ! -s "$MARKS_FILE" ]; then
    echo "No marks yet."
    exit 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    choice=$(nl -w2 -s'  ' "$MARKS_FILE" | fzf --prompt='harpoon> ' --height=40% --border)
    idx=$(printf '%s' "$choice" | awk '{print $1}')
  else
    idx=1
  fi

  if [ -z "${idx:-}" ]; then
    exit 1
  fi

  cmd_jump_like "$idx" "$emit_mode"
}

cmd_cycle() {
  dir=$1
  emit_mode=${2:-}

  total=$(count_marks)
  if [ "$total" -le 0 ]; then
    echo "No marks yet."
    exit 1
  fi

  current=$(cat "$CURSOR_FILE" 2>/dev/null || echo "1")
  if ! is_int "$current" || [ "$current" -lt 1 ] || [ "$current" -gt "$total" ]; then
    current=1
  fi

  if [ "$dir" = "next" ]; then
    next=$((current + 1))
    [ "$next" -gt "$total" ] && next=1
  else
    next=$((current - 1))
    [ "$next" -lt 1 ] && next=$total
  fi

  cmd_jump_like "$next" "$emit_mode"
}

cmd_remove() {
  arg=${1:-}
  if [ -z "$arg" ]; then
    echo "remove requires index or path" >&2
    exit 1
  fi

  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT

  if is_int "$arg"; then
    awk -v n="$arg" 'NR != n' "$MARKS_FILE" > "$tmp"
  else
    target=$(abs_path "$arg")
    awk -v p="$target" '$0 != p' "$MARKS_FILE" > "$tmp"
  fi

  mv "$tmp" "$MARKS_FILE"
  trap - EXIT
  echo "Removed: $arg"
}

cmd_clear() {
  : > "$MARKS_FILE"
  echo "1" > "$CURSOR_FILE"
  echo "Cleared all marks."
}

ensure_state

cmd=${1:-}
shift || true

case "$cmd" in
  add) cmd_add "${1:-}" ;;
  list) cmd_list ;;
  jump)
    [ $# -ge 1 ] || { echo "jump requires an index" >&2; exit 1; }
    cmd_jump_like "$1" "${2:-}"
    ;;
  menu) cmd_menu "${1:-}" ;;
  next) cmd_cycle next "${1:-}" ;;
  prev) cmd_cycle prev "${1:-}" ;;
  remove) cmd_remove "${1:-}" ;;
  clear) cmd_clear ;;
  -h|--help|help|'') usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
