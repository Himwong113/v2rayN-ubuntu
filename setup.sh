#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOLUTION="$SCRIPT_DIR/v2rayN/v2rayN.sln"
DESKTOP_PROJECT="$SCRIPT_DIR/v2rayN/v2rayN.Desktop/v2rayN.Desktop.csproj"
TEST_PROJECT="$SCRIPT_DIR/v2rayN/ServiceLib.Tests/ServiceLib.Tests.csproj"

DOTNET_CHANNEL="${DOTNET_CHANNEL:-10.0.1xx}"
DOTNET_INSTALL_DIR="${DOTNET_INSTALL_DIR:-$HOME/.dotnet}"

INSTALL_DOTNET=1
INSTALL_SYSTEM_DEPS=0
RUN_RESTORE=1
RUN_BUILD=0
RUN_TESTS=0
RUN_APP=0

usage() {
  cat <<EOF
Usage: ./setup.sh [options]

Sets up this v2rayN checkout for local development.

Options:
  --install-system-deps      Install common Linux GUI/build dependencies with apt-get.
  --no-dotnet-install        Do not install .NET if SDK 10.x is missing.
  --no-restore               Skip dotnet restore.
  --build                    Build the Avalonia desktop project after restore.
  --test                     Run ServiceLib tests after restore.
  --run                      Run the Avalonia desktop app after setup.
  --dotnet-channel VALUE     dotnet-install channel to use. Default: $DOTNET_CHANNEL
  --dotnet-install-dir DIR   User-local .NET install dir. Default: $DOTNET_INSTALL_DIR
  -h, --help                 Show this help.

Examples:
  ./setup.sh
  ./setup.sh --build
  ./setup.sh --install-system-deps --build --test
  ./setup.sh --run
EOF
}

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] ERROR: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-system-deps) INSTALL_SYSTEM_DEPS=1; shift ;;
      --no-dotnet-install) INSTALL_DOTNET=0; shift ;;
      --no-restore) RUN_RESTORE=0; shift ;;
      --build) RUN_BUILD=1; shift ;;
      --test) RUN_TESTS=1; shift ;;
      --run) RUN_APP=1; shift ;;
      --dotnet-channel)
        [[ $# -ge 2 ]] || die "--dotnet-channel requires a value"
        DOTNET_CHANNEL="$2"
        shift 2
        ;;
      --dotnet-install-dir)
        [[ $# -ge 2 ]] || die "--dotnet-install-dir requires a value"
        DOTNET_INSTALL_DIR="$2"
        shift 2
        ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
}

ensure_system_deps() {
  [[ "$INSTALL_SYSTEM_DEPS" -eq 1 ]] || return 0

  if ! command_exists apt-get; then
    die "--install-system-deps currently supports apt-get based systems only"
  fi

  log "Installing common system dependencies with apt-get"
  sudo apt-get update
  sudo apt-get -y install \
    ca-certificates curl git libfontconfig1 libfreetype6 \
    desktop-file-utils xdg-utils
}

ensure_submodules() {
  if [[ ! -f "$SCRIPT_DIR/.gitmodules" ]]; then
    return 0
  fi

  log "Initializing git submodules"
  git -C "$SCRIPT_DIR" submodule sync --recursive
  git -C "$SCRIPT_DIR" submodule update --init --recursive
}

has_dotnet_10_sdk() {
  command_exists dotnet || return 1
  dotnet --list-sdks 2>/dev/null | awk '{print $1}' | grep -Eq '^10\.'
}

ensure_dotnet() {
  export DOTNET_ROOT="$DOTNET_INSTALL_DIR"
  export PATH="$DOTNET_INSTALL_DIR:$PATH"

  if has_dotnet_10_sdk; then
    log "Found .NET SDK 10.x"
    dotnet --version
    return 0
  fi

  [[ "$INSTALL_DOTNET" -eq 1 ]] || die ".NET SDK 10.x is required but was not found"

  if ! command_exists curl && ! command_exists wget; then
    die "curl or wget is required to download dotnet-install.sh"
  fi

  local tmp_dir=""
  tmp_dir="$(mktemp -d)"

  log "Installing .NET SDK from channel $DOTNET_CHANNEL into $DOTNET_INSTALL_DIR"
  if command_exists curl; then
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$tmp_dir/dotnet-install.sh"
  else
    wget -q https://dot.net/v1/dotnet-install.sh -O "$tmp_dir/dotnet-install.sh"
  fi

  chmod +x "$tmp_dir/dotnet-install.sh"
  "$tmp_dir/dotnet-install.sh" --channel "$DOTNET_CHANNEL" --install-dir "$DOTNET_INSTALL_DIR"
  rm -rf "$tmp_dir"

  has_dotnet_10_sdk || die "Installed .NET, but SDK 10.x is still not available"
  dotnet --version
}

restore_solution() {
  [[ "$RUN_RESTORE" -eq 1 ]] || return 0

  # Restore Desktop project only: full solution contains Windows-only WPF
  # project, which fails on Linux with NETSDK1100.
  [[ -f "$DESKTOP_PROJECT" ]] || die "Desktop project not found: $DESKTOP_PROJECT"
  log "Restoring Avalonia desktop project"
  dotnet restore "$DESKTOP_PROJECT"
}

build_desktop() {
  [[ "$RUN_BUILD" -eq 1 ]] || return 0

  [[ -f "$DESKTOP_PROJECT" ]] || die "Desktop project not found: $DESKTOP_PROJECT"
  log "Building Avalonia desktop project"
  dotnet build "$DESKTOP_PROJECT" -c Debug --no-restore
}

test_service_lib() {
  [[ "$RUN_TESTS" -eq 1 ]] || return 0

  [[ -f "$TEST_PROJECT" ]] || die "Test project not found: $TEST_PROJECT"
  log "Running ServiceLib tests"
  dotnet test "$TEST_PROJECT" --no-restore
}

run_app() {
  [[ "$RUN_APP" -eq 1 ]] || return 0

  [[ -f "$DESKTOP_PROJECT" ]] || die "Desktop project not found: $DESKTOP_PROJECT"
  log "Running Avalonia desktop app"
  dotnet run --project "$DESKTOP_PROJECT"
}

main() {
  parse_args "$@"
  ensure_system_deps
  ensure_submodules
  ensure_dotnet
  restore_solution
  build_desktop
  test_service_lib
  run_app

  log "Setup complete"
  log "For this shell, DOTNET_ROOT=$DOTNET_INSTALL_DIR"
  log "Run the app with: dotnet run --project v2rayN/v2rayN.Desktop/v2rayN.Desktop.csproj"
}

main "$@"
