#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../v2rayN/v2rayN.Desktop/bin/Debug/net10.0"
APP_USER="${SUDO_USER:-$(id -un)}"
START_NOW=1

usage() {
  cat <<EOF
Usage: ./service/install.sh [options]

Start the v2rayN desktop app automatically after desktop login.
Switches off the previous v2rayn-proxy service to release the proxy ports.
Can also be run with sudo; the desktop app runs as your normal user.

Options:
  --app-dir DIR   Built v2rayN directory. Default: Debug/net10.0 in this checkout.
  --user USER     Desktop user. Default: current user or sudo's invoking user.
  --no-start      Configure startup without opening the app now.
  --proxy        Install the background Xray service instead (requires sudo).
  -h, --help      Show this help.
EOF
}

die() { printf '[service] ERROR: %s\n' "$*" >&2; exit 1; }

PROXY_MODE=0
PROXY_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-dir|--user)
      [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
      PROXY_ARGS+=("$1" "$2")
      if [[ "$1" == --app-dir ]]; then APP_DIR="$2"; else APP_USER="$2"; fi
      shift 2
      ;;
    --no-start) START_NOW=0; PROXY_ARGS+=("$1"); shift ;;
    --proxy) PROXY_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
if [[ "$PROXY_MODE" -eq 1 ]]; then
  exec "$SCRIPT_DIR/install-proxy.sh" "${PROXY_ARGS[@]}"
fi

[[ "$(uname -s)" == Linux ]] || die "This script requires a Linux desktop"
id "$APP_USER" >/dev/null 2>&1 || die "User does not exist: $APP_USER"
APP_UID="$(id -u "$APP_USER")"
APP_GID="$(id -g "$APP_USER")"
[[ "$APP_UID" != 0 ]] || die "Use --user to select your normal desktop user"
[[ "$EUID" -eq 0 || "$EUID" -eq "$APP_UID" ]] || die "Use sudo to install for another user"
APP_HOME="$(getent passwd "$APP_UID" | cut -d: -f6)"
[[ -n "$APP_HOME" && -d "$APP_HOME" ]] || die "User home directory not found"
[[ -d "$APP_DIR" ]] || die "App directory not found. Run ./setup.sh --build"
APP_DIR="$(cd -- "$APP_DIR" && pwd -P)"
[[ -x "$APP_DIR/v2rayN" ]] || die "Desktop app not found. Run ./setup.sh --build"
[[ "$APP_DIR" != *$'\n'* && "$APP_DIR" != *$'\r'* ]] || die "Paths must not contain newlines"

CONFIG_DIR="$APP_HOME/.config"
DATA_DIR="$APP_HOME/.local/share"
if [[ "$EUID" -eq "$APP_UID" ]]; then
  CONFIG_DIR="${XDG_CONFIG_HOME:-$CONFIG_DIR}"
  DATA_DIR="${XDG_DATA_HOME:-$DATA_DIR}"
fi
AUTOSTART="$CONFIG_DIR/autostart/v2rayN.desktop"
MENU_ENTRY="$DATA_DIR/applications/v2rayN.desktop"
LAUNCHER="$DATA_DIR/v2rayN/start.sh"

# Desktop entry string escaping applies before Exec argument unquoting.
desktop_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}
desktop_exec() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  value="${value//%/%%}"
  desktop_value "\"$value\""
}

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n'
  if [[ -x "$APP_HOME/.dotnet/dotnet" ]]; then
    printf 'export DOTNET_ROOT=%q\n' "$APP_HOME/.dotnet"
  fi
  printf 'cd -- %q\nexec %q "$@"\n' "$APP_DIR" "$APP_DIR/v2rayN"
} > "$TEMP_DIR/start.sh"
cat > "$TEMP_DIR/v2rayN.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=v2rayN
Comment=v2rayN desktop proxy client
Exec=$(desktop_exec "$LAUNCHER")
Icon=$(desktop_value "$APP_DIR/v2rayN.png")
Terminal=false
Categories=Network;
X-GNOME-Autostart-enabled=true
EOF

bash -n "$TEMP_DIR/start.sh"
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$TEMP_DIR/v2rayN.desktop"
fi
if [[ "$EUID" -eq 0 ]]; then
  install -d -o "$APP_UID" -g "$APP_GID" "$CONFIG_DIR/autostart" "$DATA_DIR/applications" "$DATA_DIR/v2rayN"
  install -o "$APP_UID" -g "$APP_GID" -m 0755 "$TEMP_DIR/start.sh" "$LAUNCHER"
  install -o "$APP_UID" -g "$APP_GID" -m 0644 "$TEMP_DIR/v2rayN.desktop" "$AUTOSTART"
  install -o "$APP_UID" -g "$APP_GID" -m 0644 "$TEMP_DIR/v2rayN.desktop" "$MENU_ENTRY"
else
  install -d "$CONFIG_DIR/autostart" "$DATA_DIR/applications" "$DATA_DIR/v2rayN"
  install -m 0755 "$TEMP_DIR/start.sh" "$LAUNCHER"
  install -m 0644 "$TEMP_DIR/v2rayN.desktop" "$AUTOSTART"
  install -m 0644 "$TEMP_DIR/v2rayN.desktop" "$MENU_ENTRY"
fi

# The desktop app manages its own core; release the old service's ports first.
if [[ -f /etc/systemd/system/v2rayn-proxy.service ]]; then
  if [[ "$EUID" -eq 0 ]]; then
    systemctl disable --now v2rayn-proxy.service
  else
    sudo systemctl disable --now v2rayn-proxy.service || die "Desktop startup is configured. Run sudo ./service/install.sh in your terminal to stop the old proxy service and open the app"
  fi
fi
printf '[service] Desktop startup enabled: %s\n' "$AUTOSTART"
printf '[service] You can also open v2rayN from your applications menu.\n'

if [[ "$START_NOW" -eq 1 ]]; then
  if pgrep -u "$APP_UID" -x v2rayN >/dev/null; then
    printf '[service] v2rayN is already running. Open its window from the tray icon.\n'
  elif [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    printf '[service] Log into your desktop to open v2rayN automatically.\n'
  elif [[ "$EUID" -eq 0 ]]; then
    nohup runuser -u "$APP_USER" -- env \
      XDG_RUNTIME_DIR="/run/user/$APP_UID" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$APP_UID/bus" \
      "$LAUNCHER" > /dev/null 2>&1 < /dev/null &
    printf '[service] Opening v2rayN as %s.\n' "$APP_USER"
  else
    nohup "$LAUNCHER" > /dev/null 2>&1 < /dev/null &
    printf '[service] Opening v2rayN.\n'
  fi
fi
