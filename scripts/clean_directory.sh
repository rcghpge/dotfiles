#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${PWD}"
DRY_RUN=1
DELETE_LARGE=0
LARGE_SIZE_MB=500

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

Runs cleanup inside the CURRENT DIRECTORY only.

Options:
  --apply               Delete files (default is dry-run)
  --delete-large        Delete files larger than --large-mb
  --large-mb N          Large file threshold in MB (default: 500)
  --help                Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --apply
  $(basename "$0") --apply --delete-large --large-mb 250
EOF
}

human_size() {
  numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

print_header() {
  echo "============================================================"
  echo "🧹 Project/OneDrive cleanup"
  echo "============================================================"
  echo "📍 Root directory : $ROOT_DIR"
  echo "🧪 Mode           : $([ "$DRY_RUN" -eq 1 ] && echo "DRY-RUN" || echo "APPLY")"
  echo "📦 Large files    : $([ "$DELETE_LARGE" -eq 1 ] && echo "DELETE > ${LARGE_SIZE_MB}MB" || echo "REPORT ONLY")"
  echo "============================================================"
  echo ""
}

require_safe_root() {
  if [ -z "${ROOT_DIR:-}" ] || [ "$ROOT_DIR" = "/" ]; then
    echo "❌ Refusing to run on root filesystem."
    exit 1
  fi
}

show_disk_usage() {
  echo "📊 Top directories under $ROOT_DIR"
  echo "------------------------------------------------------------"
  du -h --max-depth=1 "$ROOT_DIR" 2>/dev/null | sort -hr | head -n 20
  echo ""
}

delete_path() {
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: would delete $path"
  else
    rm -rf -- "$path"
    echo "Deleted: $path"
  fi
}

delete_file() {
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: would delete file $path"
  else
    rm -f -- "$path"
    echo "Deleted file: $path"
  fi
}

clean_pixi() {
  echo "🧹 Cleaning .pixi directories..."
  mapfile -d '' -t pixi_dirs < <(find "$ROOT_DIR" -maxdepth 6 -type d -name ".pixi" -print0 2>/dev/null)

  if [ "${#pixi_dirs[@]}" -eq 0 ]; then
    echo "No .pixi directories found."
    echo ""
    return
  fi

  for pixi_dir in "${pixi_dirs[@]}"; do
    echo "📂 Found: $pixi_dir"

    if [ -d "$pixi_dir/envs" ]; then
      while IFS= read -r -d '' path; do
        delete_path "$path"
      done < <(find "$pixi_dir/envs" -mindepth 4 -print0 2>/dev/null)
    fi

    if [ -d "$pixi_dir/activation-env-v0" ]; then
      while IFS= read -r -d '' path; do
        delete_path "$path"
      done < <(find "$pixi_dir/activation-env-v0" -mindepth 1 -print0 2>/dev/null)
    fi
  done
  echo ""
}

clean_conda() {
  echo "🧹 Cleaning Conda cache..."
  if [ -d "$ROOT_DIR/anaconda3" ] && command -v conda >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY-RUN: would run conda clean --all --yes"
    else
      conda clean --all --yes
    fi
  else
    echo "No local anaconda3 under root, or conda not installed. Skipping."
  fi
  echo ""
}

clean_local_caches() {
  echo "🧹 Cleaning local cache directories under root..."
  local cache_dirs=(
    "$ROOT_DIR/.cache/huggingface"
    "$ROOT_DIR/.cache/rattler"
    "$ROOT_DIR/.cache/kagglehub"
    "$ROOT_DIR/.cache/pip"
  )

  for dir in "${cache_dirs[@]}"; do
    [ -d "$dir" ] && delete_path "$dir"
  done

  if [ -d "$ROOT_DIR/.cache" ]; then
    echo "🧹 Cleaning remaining contents inside $ROOT_DIR/.cache ..."
    while IFS= read -r -d '' path; do
      delete_path "$path"
    done < <(find "$ROOT_DIR/.cache" -mindepth 1 -print0 2>/dev/null)
  fi
  echo ""
}

clean_python_junk() {
  echo "🧹 Cleaning Python/Jupyter residual builds..."

  while IFS= read -r -d '' path; do
    delete_path "$path"
  done < <(find "$ROOT_DIR" -type d -name "__pycache__" -print0 2>/dev/null)

  while IFS= read -r -d '' path; do
    delete_file "$path"
  done < <(find "$ROOT_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -print0 2>/dev/null)

  while IFS= read -r -d '' path; do
    delete_path "$path"
  done < <(find "$ROOT_DIR" -type d -name ".ipynb_checkpoints" -print0 2>/dev/null)

  echo ""
}

report_large_files() {
  echo "📦 Largest files under $ROOT_DIR"
  echo "------------------------------------------------------------"
  find "$ROOT_DIR" -type f -printf '%s\t%p\n' 2>/dev/null | sort -nr | head -n 30 | \
  awk '{
    size=$1; $1=""; sub(/^\t/,"");
    print size "\t" $0
  }'
  echo ""
}

delete_large_files() {
  echo "🧹 Handling files larger than ${LARGE_SIZE_MB}MB..."
  while IFS=$'\t' read -r size path; do
    [ -n "${path:-}" ] || continue
    echo "Large file: $(human_size "$size")  $path"
    delete_file "$path"
  done < <(find "$ROOT_DIR" -type f -size +"${LARGE_SIZE_MB}"M -printf '%s\t%p\n' 2>/dev/null)

  echo ""
}

report_large_dirs() {
  echo "📁 Largest directories under $ROOT_DIR"
  echo "------------------------------------------------------------"
  du -B1 -d 4 "$ROOT_DIR" 2>/dev/null | sort -nr | head -n 25 | \
  awk '{
    size=$1; $1=""; sub(/^\t/,"");
    cmd="numfmt --to=iec-i --suffix=B " size " 2>/dev/null";
    cmd | getline hs;
    close(cmd);
    if (hs == "") hs=size "B";
    print hs "\t" $0
  }'
  echo ""
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --apply)
        DRY_RUN=0
        ;;
      --delete-large)
        DELETE_LARGE=1
        ;;
      --large-mb)
        shift
        LARGE_SIZE_MB="${1:-}"
        if ! [[ "$LARGE_SIZE_MB" =~ ^[0-9]+$ ]]; then
          echo "❌ --large-mb must be an integer"
          exit 1
        fi
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "❌ Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  require_safe_root
  print_header
  show_disk_usage
  report_large_dirs
  report_large_files

  clean_pixi
  clean_conda
  clean_local_caches
  clean_python_junk

  if [ "$DELETE_LARGE" -eq 1 ]; then
    delete_large_files
  else
    echo "ℹ️ Large files were reported only. Use --delete-large with --apply to remove them."
    echo ""
  fi

  echo "✅ Final disk usage"
  echo "------------------------------------------------------------"
  du -h --max-depth=1 "$ROOT_DIR" 2>/dev/null | sort -hr | head -n 20
  echo ""

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Done. No files were deleted because this was a dry-run."
  else
    echo "Done. Cleanup applied."
  fi
}

main "$@"
