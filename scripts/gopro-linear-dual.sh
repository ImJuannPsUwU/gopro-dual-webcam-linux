#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Community extension for dual GoPro webcam outputs on Linux.
# This file adds/contains custom dual-V4L2, automatic reconnect, and/or
# per-output processing compared with the upstream single-output approach.
# See ATTRIBUTION.md and LICENSE.

set -euo pipefail

# GoPro HERO12 Black -> dos cámaras virtuales con reconexión robusta.
# /dev/video42 = GoPro OBS
# /dev/video43 = GoPro Discord
#
# Instalar/actualizar:
#   sudo bash gopro-dual-webcam-autostart-v3.sh
#
# Desinstalar:
#   sudo bash gopro-dual-webcam-autostart-v3.sh uninstall

ACTION="${1:-install}"
MODPROBE_CONF="/etc/modprobe.d/gopro-webcam-dual.conf"
MODULES_CONF="/etc/modules-load.d/gopro-webcam-dual.conf"
MONITOR="/usr/local/bin/gopro-webcam-monitor"
SERVICE="/etc/systemd/system/gopro-webcam-monitor.service"

die() { echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "Ejecuta este archivo con sudo."

if [[ "$ACTION" == "uninstall" ]]; then
  systemctl disable --now gopro-webcam-monitor.service 2>/dev/null || true
  rm -f "$MONITOR" "$SERVICE" "$MODPROBE_CONF" "$MODULES_CONF"
  systemctl daemon-reload
  echo "Automatización eliminada."
  exit 0
fi

[[ "$ACTION" == "install" ]] || die "Uso: $0 [install|uninstall]"

for cmd in systemctl udevadm modprobe ip curl ffmpeg awk grep; do
  command -v "$cmd" >/dev/null 2>&1 || die "Falta '$cmd'."
done

cat > "$MODPROBE_CONF" <<'EOF'
options v4l2loopback devices=2 video_nr=42,43 card_label="GoPro OBS","GoPro Discord" exclusive_caps=1,1
EOF

cat > "$MODULES_CONF" <<'EOF'
v4l2loopback
EOF

cat > "$MONITOR" <<'EOF'
#!/usr/bin/env bash
set -u

PORT=8554
RES=1080
FOV=4
OUT_OBS="/dev/video42"
OUT_DISCORD="/dev/video43"
FFPID=""

log() { echo "[GoPro] $*"; }

find_gopro_iface() {
  local path iface
  for path in /sys/class/net/*; do
    [[ -e "$path" ]] || continue
    iface="${path##*/}"
    if udevadm info --attribute-walk --path="$path" 2>/dev/null \
       | grep -q 'ATTRS{idVendor}=="2672"'; then
      printf '%s\n' "$iface"
      return 0
    fi
  done
  return 1
}

wait_for_ipv4() {
  local iface="$1" addr=""
  for _ in $(seq 1 30); do
    [[ -e "/sys/class/net/$iface" ]] || return 1
    addr="$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null \
      | awk 'NR==1 {print $4}' | cut -d/ -f1 || true)"
    if [[ -n "$addr" ]]; then
      printf '%s\n' "$addr"
      return 0
    fi
    sleep 1
  done
  return 1
}

start_camera_api() {
  local camera_ip="$1" response=""
  for _ in $(seq 1 20); do
    response="$(curl -fsS --max-time 2 \
      "http://${camera_ip}/gp/gpWebcam/START?res=${RES}&port=${PORT}" 2>/dev/null || true)"
    if [[ -n "$response" ]]; then
      log "Modo webcam activado."
      curl -fsS --max-time 2 \
        "http://${camera_ip}/gp/gpWebcam/SETTINGS?fov=${FOV}" >/dev/null 2>&1 || true
      log "FOV Linear aplicado."
      return 0
    fi
    sleep 1
  done
  return 1
}

stop_ffmpeg_hard() {
  [[ -n "$FFPID" ]] || return 0
  kill -0 "$FFPID" 2>/dev/null || { FFPID=""; return 0; }

  log "Deteniendo FFmpeg..."
  kill -TERM "$FFPID" 2>/dev/null || true

  # No usar 'wait' indefinidamente: algunos sinks V4L2 pueden dejar
  # a ffmpeg bloqueado cuando desaparece la fuente.
  for _ in $(seq 1 20); do
    if ! kill -0 "$FFPID" 2>/dev/null; then
      wait "$FFPID" 2>/dev/null || true
      FFPID=""
      return 0
    fi
    sleep 0.1
  done

  log "FFmpeg no terminó; enviando SIGKILL."
  kill -KILL "$FFPID" 2>/dev/null || true
  wait "$FFPID" 2>/dev/null || true
  FFPID=""
}

cleanup() {
  stop_ffmpeg_hard
}
trap cleanup EXIT TERM INT

log "Servicio iniciado. Esperando HERO12..."

while true; do
  if [[ ! -e "$OUT_OBS" || ! -e "$OUT_DISCORD" ]]; then
    log "Esperando /dev/video42 y /dev/video43..."
    sleep 2
    continue
  fi

  iface="$(find_gopro_iface 2>/dev/null || true)"
  if [[ -z "$iface" ]]; then
    sleep 2
    continue
  fi

  log "HERO12 detectada en interfaz $iface."

  host_ip="$(wait_for_ipv4 "$iface" 2>/dev/null || true)"
  if [[ -z "$host_ip" ]]; then
    log "La interfaz no obtuvo IPv4. Reintentando..."
    sleep 2
    continue
  fi

  camera_ip="${host_ip%.*}.51"
  log "Interfaz USB: $host_ip; cámara: $camera_ip"

  if ! start_camera_api "$camera_ip"; then
    log "La API de la GoPro aún no respondió. Reintentando..."
    sleep 2
    continue
  fi

  log "Transmitiendo a $OUT_OBS y $OUT_DISCORD."

  ffmpeg \
    -hide_banner \
    -loglevel warning \
    -nostdin \
    -threads 1 \
    -i "udp://@0.0.0.0:${PORT}?overrun_nonfatal=1&fifo_size=50000000" \
    -fflags nobuffer \
    -filter_complex "[0:v]format=yuv420p,split=2[vobs][vdiscord]" \
    -map "[vobs]" -f v4l2 "$OUT_OBS" \
    -map "[vdiscord]" -f v4l2 "$OUT_DISCORD" &
  FFPID=$!

  while kill -0 "$FFPID" 2>/dev/null; do
    if [[ ! -e "/sys/class/net/$iface" ]]; then
      log "GoPro desconectada. Reiniciando el servicio desde cero..."
      stop_ffmpeg_hard
      # Salir intencionalmente. systemd tiene Restart=always,
      # así que crea un proceso limpio que vuelve a esperar la GoPro.
      exit 0
    fi
    sleep 1
  done

  wait "$FFPID" 2>/dev/null || true
  FFPID=""
  log "FFmpeg terminó inesperadamente. Reiniciando el servicio..."
  exit 1
done
EOF

chmod 0755 "$MONITOR"

cat > "$SERVICE" <<'EOF'
[Unit]
Description=GoPro HERO12 dual webcam monitor
After=systemd-modules-load.service NetworkManager.service
Wants=NetworkManager.service
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/local/bin/gopro-webcam-monitor
Restart=always
RestartSec=2
User=root
Group=root
KillMode=control-group
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "$SERVICE"

systemctl daemon-reload
systemctl enable gopro-webcam-monitor.service >/dev/null

# Si los dos dispositivos ya existen, no tocar el módulo: así la actualización
# puede hacerse sin molestar OBS/Discord innecesariamente.
if [[ ! -e /dev/video42 || ! -e /dev/video43 ]]; then
  systemctl stop gopro-webcam-monitor.service 2>/dev/null || true
  if lsmod | grep -q '^v4l2loopback'; then
    if ! modprobe -r v4l2loopback; then
      echo "Cierra OBS, Discord y cualquier proceso que use v4l2loopback y vuelve a ejecutar."
      exit 2
    fi
  fi
  modprobe v4l2loopback devices=2 video_nr=42,43 \
    'card_label=GoPro OBS,GoPro Discord' exclusive_caps=1,1
fi

systemctl restart gopro-webcam-monitor.service

echo
echo "GoPro auto-webcam v3 instalada/actualizada."
echo "Ahora, al desconectar la GoPro, el proceso termina y systemd"
echo "lo vuelve a iniciar desde cero en ~2 segundos."
echo
echo "Log:"
echo "  journalctl -u gopro-webcam-monitor.service -f"
echo
echo "Estado:"
echo "  systemctl status gopro-webcam-monitor.service"
