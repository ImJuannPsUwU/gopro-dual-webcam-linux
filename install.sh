#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh linear
  ./install.sh narrow
  ./install.sh zoom
  ./install.sh uninstall

Presets:
  linear  Linear FOV -> OBS + Discord
  narrow  Narrow FOV -> OBS + Discord
  zoom    Narrow FOV -> OBS normal + Discord ~1.39x zoom
EOF
}

action="${1:-}"
case "$action" in
  linear)
    script="$ROOT/scripts/gopro-linear-dual.sh"
    ;;
  narrow)
    script="$ROOT/scripts/gopro-narrow-dual.sh"
    ;;
  zoom)
    script="$ROOT/scripts/gopro-narrow-zoom-dual.sh"
    ;;
  uninstall)
    script="$ROOT/scripts/gopro-narrow-zoom-dual.sh"
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ $EUID -eq 0 ]]; then
  if [[ "$action" == "uninstall" ]]; then
    exec bash "$script" uninstall
  else
    exec bash "$script"
  fi
else
  if [[ "$action" == "uninstall" ]]; then
    exec sudo bash "$script" uninstall
  else
    exec sudo bash "$script"
  fi
fi
