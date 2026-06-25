#!/usr/bin/env bash
set -Eeuo pipefail

BIN_NAME="cc-switch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_TAURI_DIR="${SCRIPT_DIR}/src-tauri"
INSTALL_DIR="${CC_SWITCH_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="${INSTALL_DIR}/${BIN_NAME}"
TARGET_DIR="${CC_SWITCH_TARGET_DIR:-${INSTALL_DIR}}"
TARGET_NAME="${CC_SWITCH_TARGET_NAME:-${BIN_NAME}}"
BUILD_TARGET_DIR="${CC_SWITCH_BUILD_TARGET_DIR:-${SRC_TAURI_DIR}/target}"
FORCE_OVERWRITE="${CC_SWITCH_FORCE:-0}"

info()  { printf '  \033[1;32minfo\033[0m: %s\n' "$*"; }
warn()  { printf '  \033[1;33mwarn\033[0m: %s\n' "$*" >&2; }
err()   { printf '  \033[1;31merror\033[0m: %s\n' "$*" >&2; }

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 1
  fi
}

installed_version() {
  local candidate="${1:-}"
  if [[ -z "${candidate}" || ! -x "${candidate}" ]]; then
    return 0
  fi
  "${candidate}" --version 2>/dev/null | head -n 1 || true
}

confirm_overwrite_if_needed() {
  local target_version reply

  if [[ ! -e "${TARGET}" ]]; then
    return 0
  fi

  target_version="$(installed_version "${TARGET}")"

  if [[ "${FORCE_OVERWRITE}" == "1" ]]; then
    warn "Existing installation detected at ${TARGET}${target_version:+ (${target_version})}; continuing because CC_SWITCH_FORCE=1"
    return 0
  fi

  if ! exec 3<> /dev/tty 2>/dev/null; then
    err "Existing installation detected at ${TARGET}${target_version:+ (${target_version})}."
    err "Nothing was overwritten. Re-run interactively to confirm the update, or set CC_SWITCH_FORCE=1 to allow overwrite."
    exit 1
  fi

  printf '  Existing installation detected at %s' "${TARGET}" >&3
  if [[ -n "${target_version}" ]]; then
    printf ' (%s)' "${target_version}" >&3
  fi
  printf '.\n\n  [U]pdate or [C]ancel? [U/c] ' >&3
  IFS= read -r reply <&3
  exec 3>&-

  case "${reply:-u}" in
    u|U|update|UPDATE|"") return 0 ;;
    c|C|cancel|CANCEL)
      info "Installation canceled."
      exit 0
      ;;
    *)
      err "Unrecognized choice: ${reply}"
      err "Nothing was overwritten. Re-run and choose Update, or set CC_SWITCH_FORCE=1 to allow overwrite."
      exit 1
      ;;
  esac
}

build_release() {
  local built_binary

  need_cmd cargo

  if [[ ! -f "${SRC_TAURI_DIR}/Cargo.toml" ]]; then
    err "Source tree not found at ${SRC_TAURI_DIR}"
    exit 1
  fi

  info "Building from source in ${SRC_TAURI_DIR}"
  cargo build --release --manifest-path "${SRC_TAURI_DIR}/Cargo.toml" --target-dir "${BUILD_TARGET_DIR}"

  built_binary="${BUILD_TARGET_DIR}/release/${BIN_NAME}"
  if [[ ! -f "${built_binary}" ]]; then
    err "Built binary not found: ${built_binary}"
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"
  cp "${built_binary}" "${TARGET}.new"
  chmod 755 "${TARGET}.new"
  mv -f "${TARGET}.new" "${TARGET}"
  chmod 755 "${TARGET}"
}

main() {
  need_cmd mktemp
  confirm_overwrite_if_needed
  build_release
  info "Installed ${BIN_NAME} to ${TARGET}"
  info "Run ${BIN_NAME} --version to verify."
}

main "$@"
